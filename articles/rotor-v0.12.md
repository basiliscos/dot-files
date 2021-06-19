Messaging difference in C++ actor frameworks.

caf: synchronous & non-reactive



=====================
## Why there is no message priorities in rotor


[rotor](https://github.com/basiliscos/cpp-rotor) is a [non-intrusive](https://basiliscos.github.io/cpp-rotor-docs/md__home_b_development_cpp_cpp-rotor_docs_Rationale.html) event loop friendly C++ actor micro framework, similar to its elder brothers like [caf](https://actor-framework.org/) and [sobjectizer](https://github.com/Stiffstream/sobjectizer).

The message priorities are **available** out of the box in [caf](https://actor-framework.readthedocs.io/en/latest/MessagePassing.html#message-priorities); priorities are available *for actors* in [sobjectizer](https://github.com/Stiffstream/sobjectizer/wiki/SO-5.7-InDepth-Agent-Priorities) and are **possible** for [messages](https://habr.com/ru/post/531566/)[ru], and there are **no priorities** in any form in [rotor](https://github.com/basiliscos/cpp-rotor).

Why so? Let's study a few examples.

## Problem setting

### Example 1.

Let's consider there is a worker-actor, and we are sending it two messages: one for performing some "heavy task" (i.e. to compute matrices multiplication, or to read a few gigabytes of data from storage), and another one is "finish your job".

The intention is clear - no need of processing heavy task, if there is a "finish your job" message.

### Example 2.

There is a request processor actor. The kind of requests does not matter, it is enough to say that they are taking considerable amount of time for processing. And there are two kind of request producers: important (i.e. online-clients) and unimportant ones (e.g. cron-like scheduler).

### Properties

When we analyze both examples, we'll see, that that 1st one has **cancellation semantics**, as the high-priority message should cancel the previous message, that's why it should arrive first, as if telling "please, ignore the next heavy task with id = nnn".

The second example has no cancellation semantics, as all requests eventually have to be processed.

### Priorities solution

The message generation side assigns for each message corresponding priority and just sends messages to the destination actor as usual. It is framework responsibililty to deliver high-priority messages first, and only then, all other messages.




Hidden costs:
Plus:




1. Compute "large matrices multiplication"
2. Compute

Let's consider there is a client, which connected to our system and it periodically receives large chunks of data

### Example 1

(It is taken from recent [article](https://habr.com/ru/post/531566/) from [sobjectizer](https://github.com/Stiffstream/sobjectizer) author).

There is a stream of progress update messages and sometimes a final result message; all of them *are queued*.



article: why there are no priorities for messaging in rotor.
- asyn ops: can be cancelled
- sync ops: should be multilexed, unavoidable
cases:
1. queued -> can be cancelled
2. processing
 - async/non-blocking? cancelleble
    - than cancel, no need of priority
    - non-cancellable, "race"
 - sync/blocking:
    - started,

## Actor Linking
