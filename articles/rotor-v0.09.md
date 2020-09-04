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

However, this should not be....

## Async actor initialization and shutdown

### Notes

(1) Currently it will lead to segfault upon attempt to deliver a message to an actor, which supervisor
is already destroyed.

