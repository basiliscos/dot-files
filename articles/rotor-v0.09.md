# What's new in rotor v0.09

Summary:

- actors linking (aka connection establishment)
- clean **asynchronous** and composeable actor (and supervisor) initialization and shutdown (via pluginization)
- simplified registry actor usage (to lookup actor address by name)
- actor config builder pattern
- new private properties access system

## Actors linking

Actor system is all about interactions between actors, i.e. sending messages to each other (and do side effects
to the outer world or listen it to produce messages). However, to let a message be delivered to a final actor
the actor should **be alive** (1); in other words if actor `A` is going to send message `M`  to actor `B`,
it should be somewhow be sure, that actor `B` is online and will not go offline when during message `M`
routing.

Before `rotor` `v0.09` that kind of warranty was only available due to child-parent relations, i.e. between
supervisor and it child-actor, namely an actor was sure that a message will be delivered to supervisor,
because the supervisor *owns* the actor. Since `v0.09` it is possible to link actor `A` with actor `B`,
to make sure, that after successful linking all messages will be delivered.

So, the actors linking should be performed something like:

~~~{.cpp}
    namespace r = rotor;

    void some_actor_t::on_start() noexcept override {
        request<payload::link_request_t>(b_address).send(timeout);
    }

    void some_actor_t::on_link_response(r::message::link_response_t &response) noexcept {
        auto& ec = message.payload.ec;
        if (!ec) {
            // successfull linking
        }
    }
~~~

However, the code like this should not be used direcly as is... because it is unconvenient. It becomes
more obvious, if you'll try to link actor `A` with 2 or more actors (`B1`, `B2` etc.), because `some_actor_t`
should keep an internal counter how many target actors are waiting (successful) link responses. And here
the pluginization system (appeared with `v0.09` release) comes to help:

~~~{.cpp}
    namespace r = rotor;

    void some_actor_t::configure(r::plugin::plugin_base_t &plugin) noexcept override {
        plugin.with_casted<r::plugin::link_client_plugin_t>(
            [&](auto &p) {
                p.link(B1_address);
                p.link(B2_address);
            }
        );
    }
~~~

That is much more convenient, since `link_client_plugin_t` is included out of the box to the
`rotor::actor_base_t`.  Nevertheless, it's not enough you want to have, because it does not answers
two important questions: 1) When actors linking is performed (and it's co-question -- when actors
**unlinking** is performed)? 2) What will happen if the target actor (aka "server") does not
exist or rejects linking? 3) What will happen if the target actor decides to shut self down,
when there are linked to it clients?

To answer to the questions, the concept of actors lifetime should be refreshed.

## Async actor initialization and shutdown

The simplified picture is: an actor state usually changes as:
`new` (ctor) -> `initializing` -> `initialized` -> `operational` -> `shutting down` -> `shutted down`

The main job is performed in `operational` state, and it is up to a user to define what an actor
will do on up-and-running mode.

In the **I-phase** (i.e. `initializing` -> `initialized`), actor should prepare itself for further seving:
locate and link other actors, establish connection to a database, acquire what ever resources it
needs to be operational. The key point of [rotor](https://github.com/basiliscos/cpp-rotor), that I-phase
is **asynchronous**, so it should notify its supervisor when it is ready (2).

The **S-phase** (i.e. `shutting down` -> `shutted down`) is complementary to the **I-phase**, i.e.
actor is being asked for shutdown, and, when it is done, it should notify its supervisor.

While it sounds easy, the complexity lies in the **composability** of actors, while they form
erlang-like hierarchies of responsibilities (see my article
[trees of Supervisors](https://basiliscos.github.io/blog/2019/08/19/cpp-supervisors/)). In other
words, any actor is able to fail during `I-phase` or `S-phase`, and that could lead to
clean asynchronous collapse of whole hierarchy, independently where the failed actor was located
in it. It can be told, that either whole hierary of actors becomes `operational`, or, if something
happesn the whole hierarchy becomes `shutted down`.

[rotor](https://github.com/basiliscos/cpp-rotor) seems unique with its init/shutdown approach.
There is nothing similar in [caf](https://actor-framework.org/);
in [sobjectizer](https://github.com/Stiffstream/sobjectizer) there is a
[shutdown helper](https://sourceforge.net/p/sobjectizer/wiki/so5extra%201.0%20Shutdowner/), which
plays a similar role as `S-phase` above, however it is limited to one actor only and no `I-phase`
because [sobjectizer](https://github.com/Stiffstream/sobjectizer) has no hierarchies concept.

During [rotor](https://github.com/basiliscos/cpp-rotor) usage it was discovered, that in a progress
of `I-phase` (`S-phase`) potentially *many* resources should be acquired (released) asynchronously,
what means that no single component (or actor by it's own will) is able to answer the question,
that it completed the current phase. Instead, the answer is the result of collaborative efforts,
handled in the right order. And here **plugins** come into play; they are a kind of pieces, each one
is responsible for particular job of initialization/shutdown.

So, the promised answers, related to `link_client_plugin_t` are:

- Q: When actors linking (unlinking) is performed? A: When actor state is `initalizing` (`shutting down`).

- Q: What will happen if the target actor (aka "server") does not exist or rejects linking? A: As this happens
when actor state is `initalizing`, the plugin will detect the fail condition and will trigger client-actor
shutdown. That will possibly trigger cascade effect, i.e. its supervisor will trigger to shutdown too.

- Q: What will happen if the target actor decides to shut self down, when there are linked to it clients?
A: The "server-actor" will ask it's clients to unlink, and only when all clients confirmed unlinking,
the "server-actor" will contunue shutdown procedure (3).

### Simplified example

Let's assume that there is a database driver with async-interface with one of available event-loops for `rotor`
and there will be TCP-clients  connecting to our service. The database will be served by `db_actor_t` and
the service for serving clients will be named `acceptor_t`. The database actor will be like this

~~~{.cpp}
    namespace r = rotor;

    struct db_actor_t: r::actor_base_t {

        struct resource {
            static const constexpr r::plugin::resource_id_t db_connection = 0;
        }

        void configure(r::plugin::plugin_base_t &plugin) noexcept override {
            plugin.with_casted<r::plugin::registry_plugin_t>([this](auto &p) {
                p.register_name("service::database", this->get_address())
            });
            plugin.with_casted<r::plugin::registry_plugin_t>([this](auto &) {
                resources->acquire(resource::db_connection);
                // initiate async connection to database
            });
        }

        void on_db_connection_success() {
            resources->release(resource::db_connection);
            ...
        }

        void on_db_disconnected() {
            resources->release(resource::db_connection);
        }

        void shutdown_start() noexcept override {
            r::actor_base_t::shutdown_start();
            resources->acquire(resource::db_connection);
            // initiate async disconnection from database, e.g. flush data
        }
    };
~~~

The inner namespace `resource` is used to identify the database connection as resource.
It is good practice, istead of hard-coding magic numbers like `0`. During the actor
configuration stage (which is the part of initialization), when `registry_plugin_t` is ready,
it will asynchronously register the actor address under symbolic name `service::database`
in the `registry` (will be shown below). Then, with `registry_plugin_t` it acquires
database connection resource, blocking the further initialization and starting connection
to a database. When it is established, the resource will be released, and the `db_actor_t`
will become `operational`. The `S-phase` is symmetrical, i.e. it blocks shutdown until
all data will be flushed to DB and connection will be closed; only after that step,
the actor will continue shutdown (4).

The client acceptor code should be like:

~~~{.cpp}
    namespace r = rotor;
    struct acceptor_actor_t: r::actor_base_t {
        r::address_ptr_t db_addr;

        void configure(r::plugin::plugin_base_t &plugin) noexcept override {
            plugin.with_casted<r::plugin::registry_plugin_t>([](auto &p) {
                p.discover_name("service::database", db_addr, true).link();
            });
        }

        void on_start() noexcept override {
            r::actor_base_t::on_start();
            // start accepting clients, e.g.
            // asio::ip::tcp::acceptor.async_accept(...);
        }

        void on_new_client(client_t& client) {
            // send<message::log_client_t>(db_addr, client)
        }
    };
~~~

The key point here is the `configure` method. When `registry_plugin_t` is ready,
it will be configured to discover name `service::database` and, when found,
store it in the field `db_addr` and then it will link the actor to the `db_actor_t`.
If `service::database` will not be found, the acceptor will shutdown (i.e. `on_start`
will not be invoked); if the linking will not be confirmed, the acceptor will shutdown
too. When everything is fine, the acceptor will start accepting new clients.

The operational part itself is missing in the sake of brevity, because it wasn't
changed in the new `rotor` version: there is a need of define payload, message
(including request and response types), define methods which will accept the messages,
and finally subscribe to them.



### Notes

(1) Currently it will lead to segfault upon attempt to deliver a message to an actor, which supervisor
is already destroyed.

(2) If it will not notify, init-request timeout will occur, and the actor will be asked by supervisor
to shutdown, i.e. bypass the `operational` state.

(3) You might ask: what will happen, if a client-actor will not confirm unlink in time? Well, this is
somewhat a violation of contract, and the method `system_context_t::on_error(const std::error_code&)`
will be invoked, which by default will print error to `std::cerr` and invoke `std::terminate()`. To
avoid contract violation, shutdown timeouts should be tuned to allow client-actors unlink in time.

(4) During shutdown the `registry_plugin_t` will unregister all registered names in the `registry`.
