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
two important questions: 1) **When** actors linking is performed (and it's co-question -- when actors
**unlinking** is performed)? 2) **What** will happen if the target actor (aka "server") does not
exist or rejects linking?

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

### Notes

(1) Currently it will lead to segfault upon attempt to deliver a message to an actor, which supervisor
is already destroyed.

(2) If it will not notify, init-request timeout will occur, and the actor will be asked by supervisor
to shutdown, i.e. bypass the `operational` state.


