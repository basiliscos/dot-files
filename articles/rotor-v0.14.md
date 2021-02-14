## Overview of recent changes in rotor (v0.10 .. v0.14)

[rotor](https://github.com/basiliscos/cpp-rotor) is a [non-intrusive](https://basiliscos.github.io/cpp-rotor-docs/md__home_b_development_cpp_cpp-rotor_docs_Rationale.html) event loop friendly C++ actor micro framework with hierarchical supervising, similar to its elder brothers like [caf](https://actor-framework.org/) and [sobjectizer](https://github.com/Stiffstream/sobjectizer). There are bulk of important changes since the last release announcement [v0.09](https://habr.com/en/company/crazypanda/blog/522588/)

### Generic timers interface (v0.10)

Timers are ubiquitous generally in all actor frameworks, since they make programs more reliable. Until `v0.10` there was no way to spawn timer, and it required to access to the underlying event loop and use it's API. This was a inconvenient and breaking abstractions: in actor it must be accessed to supervisor, than cast it to event-loop specific type, then obtain event-loop and spawn timer. Upon timer triggering the [rotor](https://github.com/basiliscos/cpp-rotor)-specific mechanics have to be launched, to let all messaging work. The timer cancellation is also event-loop specific and also required additional efforts, which "pollute" pure actor logic code.

Since [rotor](https://github.com/basiliscos/cpp-rotor) `v0.10` it possible to have something like

~~~cpp
namespace r = rotor;

struct some_actor_t: r::actor_base_t {
    void on_start() noexcept {
        timer_request = start_timer(timeout, *this, &some_actor_t::on_timer);
    }

    void on_timer(r::request_id_t, bool cancelled) noexcept {
        ...;
    }

    void some_method() noexcept {
        ...
        cancel_timer(timer_id);
    }

    r::request_id_t timer_id;
};
~~~

It should be noted, that on shutdown finish moment all timers have to be canceled, otherwise it will be undefined behavior.

### Request cancellation support (v0.10)

To my opinion all messages in [caf](https://actor-framework.org/) have request-response semantics, while in [sobjectizer](https://github.com/Stiffstream/sobjectizer) it has "fire-and-forget" messaging. [rotor](https://github.com/basiliscos/cpp-rotor) has the both kinds of messaging, "fire-and-forget" is by default, the request-response is done on top of regular messaging.

Both [caf](https://actor-framework.org/) and [sobjectizer](https://github.com/Stiffstream/sobjectizer) have **managed messages queue**, which means *the framework* does not deliver a message to actor until the previous message processing has been complete. Contrary, [rotor](https://github.com/basiliscos/cpp-rotor) has no managed queue, which means that the user actor has to create own queue and actor overload protection, if needed. For immediately processed messages, like ping-pong, it does not matter, but for "heavy" requests which trigger I/O, it does. For example, if an actor polls the remote side via HTTP requests, usually, it is undesirable to start a new request, when the previous one has not been finished. Again, the next message is not delivered, until the previous message is processed, does not matter, which message it is.

This also means, that with managed messages queues, the cancellation is, in general, impossible, because the cancel message is still located in queue and it has no chance to be processed until the previous message is done.

In [rotor](https://github.com/basiliscos/cpp-rotor) you have to develop your own queue and store messages, and if cancel message arrives, your actor should search the request in queue, and then reply to it with canceled status. It should be noted, that only request-messages can be canceled, as they are referable.

~~~cpp
namespace r = rotor;

namespace payload {
struct pong_t {};
struct ping_t {
    using response_t = pong_t;
};
} // namespace payload

namespace message {
using ping_request_t = r::request_traits_t<payload::ping_t>::request::message_t;
using ping_response_t = r::request_traits_t<payload::ping_t>::response::message_t;
using ping_cancel_t = r::request_traits_t<payload::ping_t>::cancel::message_t;
} // namespace message


struct some_actor_t: r::actor_base_t {
    using ping_ptr_t = r::intrusive_ptr_t<message::ping_request_t>;

    void on_ping(ping_request_t& req) noexcept {
        // just store request for further processing
        ping_req.reset(&req);
    }

    void on_cancel(ping_cancel_t&) noexcept {
        if (req) {
            // make_error is v0.14 feature
            make_response(*req, make_error(r::make_error_code(r::error_code_t::cancelled)));
            req.reset();
        }
    }

    ping_ptr_t ping_req;
};
~~~

It should be mentioned, that requests cancellation *can be done* [sobjectizer](https://github.com/Stiffstream/sobjectizer), but, first, you have to roll your own request/response mechanism, and, second, your own queue in addition of sobjectizer's queue, i.e. unneeded performance penalties.

### std::thread backend/supervisor (v0.12)

This is long-awaited feature, which makes [rotor](https://github.com/basiliscos/cpp-rotor) to be [sobjectizer](https://github.com/Stiffstream/sobjectizer)-like: in the case, when an actor have to perform *blocking operations* and it does not need any event loop. For example, in message handler there is a need to do CPU-intensive computation.

Obviously, during blocking operations there is no way to let timers trigger or other messages to be delivered. In other words, during blocking operations actor looses its reactivity, as it cannot react to incoming messages. To cope with that blocking operation should split into smaller iterative chunks, and when an actor done proessing current chuck, it should send self a message, with the index of the next chunk etc., until all chunks are done. That will give an execution thread some breath and let [rotor](https://github.com/basiliscos/cpp-rotor) deliver other messages, execute timed out code etc. For example, instead of computing sha512 for the whole 1TB file, it can be split into computation of chunks for 1MB each, and make the thread reasonably well reactive. This is universal technique and can be applied to any actor framework.

Of course, the whole hierarchy of actors can be spawn on the `std::thread` backend, not just a single actor. Another moment, which should be emphasized, is that [rotor](https://github.com/basiliscos/cpp-rotor) have to be hinted, which message handlers are heavy/blocking, to allow [rotor](https://github.com/basiliscos/cpp-rotor) update timers after them. This should be done during subscription phase, i.e.

~~~cpp
struct sha_actor_t : public r::actor_base_t {
    ...
    void configure(r::plugin::plugin_base_t &plugin) noexcept override {
        r::actor_base_t::configure(plugin);
        plugin.with_casted<r::plugin::starter_plugin_t>([&](auto &p) {
            p.subscribe_actor(&sha_actor_t::on_process)->tag_io(); // important
        });
    }
~~~

The full source code of `sha512` reactive actor, which reacts to `CTRL+C`, is available via the [link](https://github.com/basiliscos/cpp-rotor/blob/master/examples/thread/sha512.cpp).

### Actor Identity (v0.14)

The canonical way to identify an actor is to check its main address (in [rotor](https://github.com/basiliscos/cpp-rotor) it is possible to let actor have multiple addresses, similarly in [sobjectizer](https://github.com/Stiffstream/sobjectizer) it is possible to subscribe to multiple `mboxes`). However, sometimes, it is desirable just to log something like actor name in supervisor, when the actor dies, i.e.


~~~cpp
struct my_supervisor_t : public r::supervisor_t {
    void on_child_shutdown(actor_base_t *actor) noexcept override {
        std::cout << "actor " << (void*) actor->get_address().get() << " died \n";
    }
}
~~~

Actor address is dynamic, and it changes on every program launch, so this information is almost useless. To make it sense, actor should
print its address somewhere, i.e. via overriding `on_start()` method. (If you are new to actor model, you might wonder, why don't use the actor memory address itself as identity. The answer is that `some_actor*` is available only in its supervisor or in actor itself, while actor address, `rotor::address_ptr_t`, is available from all other actors, which have some relation to the original actor)


However, the solution was rather inconvenient. That's why I decided to introduce `std::string identity` property into `actor_base_t` class. The actor identity can be set from constructor, or when `address_maker_plugin_t` is configured, i.e.:

~~~cpp
struct some_actor_t : public t::actor_baset_t {
    void configure(r::plugin::plugin_base_t &plugin) noexcept override {
        plugin.with_casted<r::plugin::address_maker_plugin_t>([&](auto &p) {
            p.set_identity("my-actor-name", false);
        });
        ...
    }
};
~~~

Now it is possible to output actor identity in it's supervisor:

~~~cpp
struct my_supervisor_t : public r::supervisor_t {
    void on_child_shutdown(actor_base_t *actor) noexcept override {
        std::cout << actor->get_identity() << " died \n";
    }
}
~~~

Sometimes, actors are unique within program and sometimes there are more then one instance of the same actor type. To distinguish between them, the address can be appended to the actor identity. That is what the second `bool` parameter does in `set_identity(name, append_addr)` method above.

By default actor identity is something like `actor 0x7fd918016d70` or `supervisor 0x7fd218016d70`. The identity feature is available in since [rotor](https://github.com/basiliscos/cpp-rotor) `v0.14`.


### Extended Error instead ff std::error_code, shutdown reason (v0.14)

When something bad happen, and proper response cannot be generated, then until `v0.14` response contained `std::error_code`. It serves quite well, but due to hierarchical nature of [rotor](https://github.com/basiliscos/cpp-rotor) it was not enough. Consider the case: a supervisor launches two child actors, and one of them fails to initialized. That will cascade supervisor and the second child-actor to do shutdown. However, from the context of the second actor and its supervisor it is not clear, why the second child was requested to shutdown, because `std::error_code` just does not contains enough information.

That's why `rotor::extended_error_t` was introduced. It contains `std::error_code`, `std::string` context (which is usually actor identity), and the smart pointer to the next extended error, which caused the current one. Now, to the fail of hierarchy of actors can be represented by chain of errors, where shutdown of each actor can be retraced:

~~~cpp
struct my_supervisor_t : public r::supervisor_t {
    void on_child_shutdown(actor_base_t *actor) noexcept override {
        std::cout << actor->get_identity() << " died, reason :: " << actor->get_shutdown_reason()->message();
    }
}
~~~

will output something like:

~~~
actor-2 due to supervisor shutdown has been requested by supervisor <- actor-1 due initialization failed
~~~

Together with actor identity, this feature brings more diagnostic tools to developers, who use [rotor](https://github.com/basiliscos/cpp-rotor).
