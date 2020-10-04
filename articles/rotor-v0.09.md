## What's new in rotor v0.09

![actor system](https://habrastorage.org/webt/a8/sa/xw/a8saxwtazuvhttv9eeoutsst7z8.png)

[rotor](https://github.com/basiliscos/cpp-rotor) is a [non-intrusive](https://basiliscos.github.io/cpp-rotor-docs/md__home_b_development_cpp_cpp-rotor_docs_Rationale.html) event loop friendly C++ actor micro framework, similar to its elder brothers like [caf](https://actor-framework.org/) and [sobjectizer](https://github.com/Stiffstream/sobjectizer). The new release came out under the flag of **pluginization**, which affects the entire lifetime of an actor.

## Actor Linking

The actor system is all about interactions between actors, i.e. sending messages to each other (and producing side effects for the outer world or listen it to produce messages). However, to let a message be delivered to the final actor the actor should **be alive** (1); in other words, if actor `A` is going to send message `M`  to actor `B`, `A` should some how be  be sure, that actor `B` is online and will not go offline while `M` is routing.

Before [rotor](https://github.com/basiliscos/cpp-rotor) `v0.09`, that kind of warranty was only available due to child-parent relations, i.e. between supervisor and its child-actor. In this case an actor was guaranteed that a message would be delivered to its supervisor, because the supervisor *owned* the actor and said supervisor's lifetime covered the respective actor's lifetime. Now, with the release of `v0.09`, it  is possible to link actor `A` with actor `B`, that are not parent- or child-related to one another and to make sure, that all messages will be delivered after successful linking .

So, linking actors is performed somewhat along these lines:

~~~{.cpp}
namespace r = rotor;

void some_actor_t::on_start() noexcept override {
    request<payload::link_request_t>(b_address).send(timeout);
}

void some_actor_t::on_link_response(r::message::link_response_t &response) noexcept {
    auto& ec = message.payload.ec;
    if (!ec) {
        // successful linking
    }
}
~~~

However, code like this should not be used directly as is... because it is inconvenient. It becomes more obvious if you try link actor `A` with 2 or more actors (`B1`, `B2`, etc.), since `some_actor_t` should keep an internal count of how many target actors are waiting for (successful) link responses. And here the pluginization system, which featured in the `v0.09` release, comes to the rescue:

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

Now, is much more convenient, since `link_client_plugin_t` is included out of the box with the `rotor::actor_base_t`. Nevertheless, it's still not enough, because it does not answer a few important questions, such as: 1. When is actor linking performed (and "by-question": when is actor **unlinking** performed)? 2. What happens if the target actor (aka "server") does not exist or rejects linking? 3. What happens if the target actor decides to self-shutdown, when there are "clients" still linked to it?

To provide answers to these questions, the concept of actors lifetime should be revisited.

## Async Actor Initialization And Shutdown

Represented in a simplified manner is: here is how an actor’s state usually changes: `new` (constructor) -> `initializing` -> `initialized` -> `operational` -> `shutting down` -> `shut down`

The main job is performed in the `operational` state, and it is up to the user to define what an actor is to do on up-and-running mode.

In the **I-phase** (i.e. `initializing` -> `initialized`), the actor should prepare itself for further functioning: locate and link with other actors, establish connection to the database, acquire whichever resources it needs to be operational. The key point of [rotor](https://github.com/basiliscos/cpp-rotor) is that I-phase is **asynchronous**, so an actor should notify its supervisor when it is ready (2).

The **S-phase** (i.e. `shutting down` -> `shut down`) is complementary to the **I-phase**, i.e. the actor is being asked to shut down, and, when it is done, it should notify its supervisor.

While it sounds easy, the tricky bit lies in the **composability** of actors, when they form Erlang-like hierarchies of responsibilities (see my article [trees of Supervisors](https://basiliscos.github.io/blog/2019/08/19/cpp-supervisors/)). In other words, any actor can fail during its `I-phase` or `S-phase`, and that can lead to
the asynchronous collapse of the entire hierarchy, regardless of the failed actor's location within it. Essentially, the entire hierarchy of actors becomes `operational`, or, if something happens the entire hierarchy becomes `shut down`.

[rotor](https://github.com/basiliscos/cpp-rotor) seems unique with its init/shutdown approach. There is nothing similar in [caf](https://actor-framework.org/);
in [sobjectizer](https://github.com/Stiffstream/sobjectizer), there is a [shutdown helper](https://sourceforge.net/p/sobjectizer/wiki/so5extra%201.0%20Shutdowner/), which
carries a function similar to `S-phase` above; however it is limited to one actor only and offers no `I-phase` because [sobjectizer](https://github.com/Stiffstream/sobjectizer) has no concept of hierarchies.

While using [rotor](https://github.com/basiliscos/cpp-rotor) usage it was discovered, that the progress of `I-phase` (`S-phase`) may potentially require *many* resources to be acquired (or released) asynchronously, which means that no single component, or actor, is able, by its own will, to answer the question, if it has completed the current phase. Instead, the answer comes as the result of collaborative efforts, handled in the right order. And this is where **plugins** come into play; they are like pieces, each one
is responsible for a particular job of initialization/shutdown.

So, here are the promised answers, related to `link_client_plugin_t`:

- Q: When is the actor linking or unlinking performed? A: When actor the state is `initializing` or `shutting down` respectively.

- Q: What happens if the target actor (aka "server") does not exist or rejects linking? A: Since this happens when the actor state is `initializing`, the plugin will detect the fail condition and will trigger client-actor shutdown. That may trigger a cascade effect, i.e. its supervisor will be trigger to shutdown too.

- Q: What happens if the target actor decides to self-shutdown when there are "clients" still linked to it? A: The "server-actor" will ask its clients to unlink, and once all "clients" have confirmed unlinking, the "server-actor" will continue shutdown procedure (3).

## A Simplified Example

Let's assume that there is a database driver with async-interface with one of available event-loops for `rotor`, and there will be TCP-clients connecting to our service. The database
will be served by `db_actor_t` and the service for serving clients will be named `acceptor_t`. The database actor is going to look like this:

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
        plugin.with_casted<r::plugin::resources_plugin_t>([this](auto &) {
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

The inner namespace `resource` is used to identify the database connection as a resource. It is good practice, better than of hard-coding magic numbers like `0`. During the actor
configuration stage (which is the part of initialization), when `registry_plugin_t` is ready, it will asynchronously register the actor address a under symbolic name `service::database` in the `registry` (will be shown further down below). Then, with the `resources_plugin_t`, it acquires database connection resource, blocking any further initialization and launching connection to the database. When connection is established, the resource is released, and the `db_actor_t` becomes `operational`. The `S-phase` is symmetrical, i.e. it blocks shutdown until all data is flushed to DB and connection is closed; once this step is complete, the actor will continue shutdown (4).

The client acceptor code should look like this:

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

The key point here is the `configure` method. When `registry_plugin_t` is ready, it is configured to discover the name `service::database` and, when found, store it in the `db_addr` field; it then links the actor to the `db_actor_t`. If `service::database` is not found, the acceptor shuts down (i.e. `on_start` is not invoked); if the linking is not confirmed, the acceptor will shuts down, too. When everything is fine, the acceptor starts accepting new clients.

The operational part itself is missing in the sake of brevity, because it wasn't changed in the new `rotor` version: there is a need of define payload, message (including request and response types), define methods which will accept the messages, and finally subscribe to them.

Let's bundle everything together in a `main.cpp`. Let's assume that the `boost::asio` even loop is used.

~~~{.cpp}
namespace asio = boost::asio;
namespace r = rotor;

...
asio::io_context io_context;
auto system_context = rotor::asio::system_context_asio_t(io_context);
auto strand = std::make_shared<asio::io_context::strand>(io_context);
auto timeout = r::pt::milliseconds(100);
auto sup = system_context->create_supervisor<r::asio::supervisor_asio_t>()
               .timeout(timeout)
               .strand(strand)
               .create_registry()
               .finish();

sup->create_actor<db_actor_t>().timeout(timeout).finish();
sup->create_actor<acceptor_actor_t>().timeout(timeout).finish();

sup->start();
io_context.run();
~~~

The `builder` pattern is actively used in the `v0.09` [rotor](https://github.com/basiliscos/cpp-rotor). Here, the root supervisor `sup` was created with 3 actors instantiated on it: the user defined `db_actor_t` and `acceptor_actor_t` and implicitly created a registry actor. As typical for the actor system, all actors are decoupled from each other, only sharing message types (skipped here).

All actors are simply created here and supervisor knows not about the relations between them, because actors are loosely coupled and became more automonous since `v0.09`.

The runtime configuration can be completely different: actors can be created on different threads, different supervisors, and even using different event loops, but the actor implementation remains the same (5). In that cases, there will be more than one root supervisor; however, to enable them to find each other, the `registry` actor address should be shared between them. This is also supported via the `get_registry_address()` method of `supervisor_t`.

## Summary

The most important feature of [rotor](https://github.com/basiliscos/cpp-rotor) `v0.09` is the pluginization of its core. Among other [plugins](https://basiliscos.github.io/cpp-rotor-docs/index.html), the most important are: the `link_client_plugin_t` plugin, which maintains kind of "virtual connection" between actors; the `registry_plugin_t`, which allows registing and discovering actor addresses by their symbolic names; and the `resources_plugin_t`, which suspends actor init/shutdown until external asynchronous events occur.

There are a few less prominent changes in the release, such as the new non-public properties [access](https://basiliscos.github.io/blog/2020/07/23/permission-model/) and builder pattern for actors construction.

Any feedback on [rotor](https://github.com/basiliscos/cpp-rotor) is welcome!

PS. I'd like to say thanks to [crazypanda.ru](https://crazypanda.ru) for supporting me in my actor model research.

### Notes

(1) Currently, it will lead to segfault upon attempt to deliver a message to an actor, whose supervisor is already destroyed.

(2) If it does not notify, init-request timeout will occur, and the actor will be asked by its supervisor to shut down, i.e. bypass the `operational` state.

(3) You might ask: what happens if a client-actor does not confirm unlinking on time? Well, this is somewhat of a violation of contract, and the `system_context_t::on_error(const std::error_code&)` method will be invoked, which, by default, will print error to `std::cerr` and invoke `std::terminate()`. To avoid contract violation, shutdown timeouts should be tuned to allow client-actors to unlink on time.

(4) During shutdown the `registry_plugin_t` will unregister all registered names in the `registry`. (5) With the exception of when, different event loops are used. When actors use event the loop API directly, they will, obviously, change following the event loop change, but that's beyond [rotor](https://github.com/basiliscos/cpp-rotor).
