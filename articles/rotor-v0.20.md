# supervising in C++: how to make your programs reliable

## supervising in real world

When some extraordinary situation is met it can be handling at the problem level
itself or it's handling can be delegated to some upper level. Usually, when it
is really extraordinary, it is delegated or ... it becomes exception handling.

Suppose, you are in a supermarket, and suddenly appears smoke and fire and for a
reason there is no fire alert signals. What would you do? You can try to
extinguish fire by yourself, or notify a supermarket employee about the problem and
let he handle the situation. An employee most likely has signed instructions to
notify its direct manager or a fire service.

The key point here, that the extraordinary situation is not handled by you, but
by a person, who knows how to deal with it. Of course, you can try to handle it
by your own, but there might be consequences if you are not the person,
responsible for the situation.

## supervising in backend and end-user services

All non-trivial programs have bugs, however most of well-known cloud services run
smoothly and we, as their rarely notice that. This happens, because our programs are
externally supervised by devops programs like `systemd` or `runit`. Simplified, their
job can be described as the following: if a program "hangs" kill it and start again,
if it exited, just restart it. In any case it leads to program *restart*.

There is, probably, the hardware supervising team too, and conceptually its job is
similar: if a router or server rack do not operate properly, turn it off and then
turn it on, i.e. *restart*.

For the regular end user of desktop application the situation is similar: when a
program misbehaves, it is terminated by the user or its operating system, and then,
probably the program will be started again by the user.

Despite of different domains, the universal pattern is the same: give the buggy
application another chance by restarting it.

## why there is no supervising in common C/C++/C#/Java/Perl/... programs

Did you frequently see a desktop program, which works with network, and, when you
suddenly plug off the network cable (or turn off wifi router), it continues to
be operational with some functions disabled, and when you plug the cable back in, the
program becomes fully operational as if there was no emergency at all?

Did you frequently see a backend app, which can easily outlive the loss of
connection to a database or messages queue or other critical resource? My experience
tells me, that level of error handling is very rare, and usually is not even
discussed.

"We are not in the military/healthcare/aerospace/nuclear domain". That is true, in
short. A little bit more verbose and technical answer is: handling all that
exceptional cases requires writing additional **special code**, which is extremely
difficult to test (manually or automatically), it will significantly increase code
development and maintenance costs without any significant benefits...

## actors as an solution

[actor](https://en.wikipedia.org/wiki/Actor_model_theory) is a independent entity with
its own lifetime and state, all the interaction with an actor happens only via
messaging, including actor start and stop signal. Thus, if something bad happens,
e.g., actor enters into inconsistent state, it shut self down and sends appropriate
message to it's supervisor actor.

Lets emphasize the point: all communications with an actor is performed via messaging,
and if something wrong occurs, there will be appropriate message too, i.e. messaging
is universal.

The normal flow looks like the following (consumer point of view): client-actor sends
a request message to service-actor, and when the request processing by the service-actor
is complete, the response message is sent back to the client. The supervisor of the
service-actor does not participate in the communications.

The error flow looks like the following from consumer point of view: client-actor sends
a request message to service-actor, and it receives a response with error from
the service-actor or, if something really terrible has happen, request timeout triggers,
which is conceptually the same as receive message with error. The service-actor,
however, has a few possibilities: if there is a problem with request, it can just
reply with error code; if there is an unrecoverable problem during error processing,
it can reply back with error to the client-actor and shut self down, i.e. send `down`
message to its supervisor.

Thus, the error flow is "doubled": (1) the client receives error and takes its own
decision what to do with error and (2) the supervisor decides how to deal with
an actor shutdown. Supervisor's decision is usually either restart the problematic
actor (which originally triggered the error), or, if (possibly a several) restarts
do not fix the problem (i.e. service-actor still shut self down), **escalate the
problem**, which means, shut the supervisor down, shutdown all child actor, and then
send `down` message to the *upstream supervisor* for further decision making.

This approach is very different from widely used *exception handling*, where there is
context for handle immediate error (1), but there isn't context for supervising (2).
This is not accidental, because *using the service* (client role) is different from
*owning the service* (supervising role).

A few questions might arise.

**How to cope with unexpected or fatal errors?** In theory, it is possible not to
handle this errors manually (with code) at all, just specifying restart policy for
the chosen framework/platform should be enough. It will simply just keep trying with
restarts until some reasonable limit is reached, then escalate the problem, restarting
the hierarchy of actors an do on... until it found, that after all possible attempts
have been tried and further trying has no sense, and the problem should be escalated
*outside* of the program, e.g. to human or to operating system.

**OK, the service-actors are keeping restarting (supervisor side), does it affect
client side?** If is is OK for client side to receive timeout responses when
service-actors are already down and not-yet-started, then the answer is "**no**".
The more technical explanation is, that the message destination endpoint is not
bind to the concrete actor: in [rotor](https://github.com/basiliscos/cpp-rotor)
any actor can subscribe to any address, in
[sobjectizer](https://github.com/Stiffstream/sobjectizer) any agent can subscribe
to any message box.

**Does supervising tolerates developer errors?** It depends on chosen platform. For the
Erlang case, with its [let it crash](https://wiki.c2.com/?LetItCrash) principle,
developer errors lead to an actor crash, and supervisor can make further description.
For the C++ errors like use-after-free or null pointer dereference or memory leaks
cannot be "catch", so they are not recoverable and program crash or memory abuse should
be supervised externally by operating system or launchers like `systemd`.

## The price

Supervising is not free of charge. If you chose [Erlang](https://www.erlang.org/) as
a platform, you receive the maximum flexibility in supervising, including tolerance
upto let-it-crash and possibility to transparently send messages to actors located
on non-local machine. However, the price is quite high, as you have to use rather
specific erlang language, the platform itself is slow comparing to native binaries
you get when you use C++/Go etc., and, if you want to speed up hot code path via
writing native extensions, you immediately loose all the benefits of the platform.
Somewhat specific syntax can be mitigated by using [Elixir](https://elixir-lang.org/)
language.

In any case the messaging have to be used for actor environment, and it is not as
fast as native methods call: the memory for a message have to be allocated, the
message field have to be filled, the message have to be dispatched etc. In summary
a message delivery can be hundred or more times expensive than a native call.

Another indirect costs of using messaging is that a framework have to be used,
because messages sending and especially receiving cannot be performed without a
context. For C++ it can be [rotor](https://github.com/basiliscos/cpp-rotor),
[sobjectizer](https://github.com/Stiffstream/sobjectizer) or
[C++ actor framework](https://actor-framework.org/), while erlang it itself
a platform and a framework.

**So, what is the total cost ownership of supervising?** In theory it is nearly
zero cost in the terms writing special code (it should be done for you), but
you will be bounded to the platform/framework and the usage of messaging also
has its own performance price.

## technical details of supervising in C++

[C++ actor framework](https://actor-framework.org/) (aka CAF) is considered the
most influenced by [Erlang](https://www.erlang.org/), however, the supervising
itself is missing. CAF is capable  to run a cluster of nodes, each one can run
arbitrary number of actors. The strong point of CAF is *transparent messaging*
(actor addressing), i.e. when a message can be send from one actor to another,
independently from their locations, i.e. they can be located on different
machines, on the same machine, or in the same process.

The situation with supervising is slightly better with
[sobjectizer](https://github.com/Stiffstream/sobjectizer), as it provides
entity named `cooperation`, which has elemental supervising capabilities,
such as syncrhonized actors startup (shutdown): either all actors, belonging
to the same `cooperation`, do all start or no actor starts; and, similar,
if an actor from `cooperation` stops, all actors on the same cooperation
stop. It should be noted, that `cooperation` class is completely belongs
to the [sobjectizer](https://github.com/Stiffstream/sobjectizer) framework,
and it is not possible to override something in it or somehow customize.
It is possible to hook actor shutdown event, and send somewhere
shutdown notification message, but that's a bit wrong way of building
supervising as it requires to handle a lot of things in your actors, which
is violation of
[Single Responsibility Principle](https://en.wikipedia.org/wiki/Single-responsibility_principle).
With [sobjectizer](https://github.com/Stiffstream/sobjectizer) you can
construct hierarchical finite state machines, which are tightly coupled
with messaging, or you can use go-like channels for messaging. So,
it is still good framework if you need that features.

Supervising is one of the key features of [rotor](https://github.com/basiliscos/cpp-rotor)
since the beginning. There is the `supervisor_t` class, which manages
its child-actors; it is fully customizable, i.e. child-actor start
and stop events can be hooked etc. However, real erlang-like
[supervising](https://www.erlang.org/doc/design_principles/sup_princ.html)
was not part of the microframework until `v0.20`. In short, since `v0.20`
it is possible to

- declaratively specify failure escalation of each actor upon it's
construction:
```cpp
supervisor->create_actor<actor_type>()
    .timeout(timeout)
    .escalate_failure()        /* will shut down in error case */
    .finish();
```

- declaratively respawn stopped actor, until some condition is
met, and, otherwise escalate failure
```cpp
namespace r = rotor;
auto actor_factory = [&](r::supervisor_t &supervisor, const r::address_ptr_t &spawner) -> r::actor_ptr_t {
    return sup
        .create_actor<actor_type>()
        .timeout(timeout)
        // other actor properties, probably taken from supervisor
        .spawner_address(spawner)
        .finish();
};

supervisor->spawn(actor_factory)
    .max_attempts(15)                               /* don't do that endlessly */
    .restart_period(boost::posix_time::seconds{10})
    .restart_policy(r::restart_policy_t::fail_only) /* respawn only on failure */
    .escalate_failure()                             /* we did our best, shutdown supervisor */
    .spawn();
```

## conclusion
