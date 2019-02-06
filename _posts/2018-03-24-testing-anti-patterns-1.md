---
date: 2018-03-24 06:36:53+00:00
layout: post
title: 'Testing anti-patterns #1'
summary: List 6 testing anti-patterns.
categories:
- Testing
- Testing anti-patterns
---

I often ask candidates to define a good unit test. This is the starting point of a conversation around testing strategies and delivering value. Over the years I've heard opinions ranging from `the 100% coverage`, passing by `testing is for testers`, all the way to `we don't do automated testing`. If the notion of a *good test* can be subjective, it is easier to identify a **bad** test. Bloggers have written about this topic at length but I thought I would try paraphrasing the same content hoping nobody would notice.

I must admit I have written - quite - a few bad tests myself and that's fine. We all make mistakes, how we handle those mistakes is what help us grow:

- It's important to understand why the mistake happened and put in place measures to prevent the same mistake from happening again
- Equally we should challenge existing practices, they might be there for a good reason but they might instead be there for a **bad** reason

<!--more-->

Here are a few anti-patterns I've noticed over the years:

## Ignored or commented test

Have you ever seen this?

{% highlight csharp %}
[Ignore]
[TestMethod]
public void Test()
{% endhighlight %}

Luckily only `MSTest` allows to ignore a test without providing a message, both `xUnit` and `NUnit` require the developer to provide a message. What's worse is that the message of the commit ignoring the test often reads `"fixed" test YOLO LMAO` and you're left wondering what deep philosophical message lies hidden behind those mundane words.

In the case of a _commented test_ the solution is simple: **delete** it. Regarding _ignored tests_, have a quick read through and run them. If you can't get them to pass, **delete** them too. Ignored / commented tests will only confuse future developers. You should treat your test code the same way you treat your production code: if a piece of code has no use anymore it should go.

**Ask yourself**: why am I ignoring this test, what conditions should be met to enable it again? Then write a **descriptive** ignore message.

## Non-thread-safe

The first thing that is wrong with this test is that it's recording log messages so that they can be asserted at a later stage (see [below](#asserting-log-messages) for the log anti-pattern):

{% highlight csharp %}
logger
    .When(l => l.Info(Arg.Any<string>()))
    .Do(ci => _logs.Add(ci.Arg<string>()));
{% endhighlight %}

But this was not the only issue with this statement. After making an unrelated change this test failed. I ran it again on its own and it passed, so this test was failing intermittently and I was also getting different `Exception` `Type`s! The `NullReferenceException` wasn't meaningful but I also got an `IndexOutOfRangeException` when adding an element to the `List`.

It turned out the code under test was multi-threaded and multiple threads were trying to add to the `List` at the same time. The [.NET API browser][list-thread-safety] makes it clear than `List` is not thread-safe:

> Any instance members are not guaranteed to be thread safe. [...] **To ensure thread safety, lock the collection during a read or write operation**.

In this instance the solution was to lock the `List` when adding to it:

{% highlight csharp %}
logger
    .When(l => l.Info(Arg.Any<string>()))
    .Do(ci =>
    {
        lock (_logs)
        {
            _logs.Add(ci.Arg<string>());
        }
    });
{% endhighlight %}

**Ask yourself**: most of the code we write is not performance critical, do you need to create multiple threads?

## Failure without enough context

There is nothing more frustrating than having a build failing on the build server and be faced by this kind of log:

{% highlight text %}
Assert.True() Failure
Expected: True
Actual:   False
{% endhighlight %}

From there things only get worse, when you look at the actual assert you discover it's asserting multiple things at the same time and you've no idea which one went wrong:

{% highlight csharp %}
Assert.True(a.A == b.A && a.B == b.B && a.C == b.C);
{% endhighlight %}

If you need to compare objects you can use an assertion library such as [Fluent Assertions][fluent-assertions] or [Shouldly][shouldly].

**Ask yourself**: if I make this test break, would I have enough context based on **only** the logs to understand what went wrong?

## Asserting log messages

Please don't do this:

{% highlight csharp %}
logger.Received(1).Info("Super important log");
{% endhighlight %}

Logging is an implementation detail, asserting log messages is over-specifying.

On the other hand, if recording that something happened is critical from a business point of view you don't want to use logging for this purpose as developers should be able to modify logging as they see fit.

Tracking business events can be achieved in different ways:

- Via your `APM` service, both [Application Insights][application-insights-events] and [New Relic][new-relic-event] can track custom events
- Via a service bus. Your code could be instrumented to emit messages and any interested service can subscribe to them

**Ask yourself**: is this the best way of doing this? Read the documentation of the systems you're currently using, you'll quite often discover features you had no idea existed.

## NullReferenceException in constructor

Don't assert than your constructors are throwing a `NullReferenceException` when being passed a `null`. Your `IoC` `container` will throw an `Exception` anyway when trying to resolve the dependencies.

**Ask yourself**: do I need to test third-party libraries?

## Sanity check

Quite often when starting a new project, developers will create a _sanity check_ test. This is a test that **should** pass and if it were to fail it would mean that things are terribly wrong. An example of such a test is this:

{% highlight csharp %}
Assert.True(true);
{% endhighlight %}

I've never seen this kind of test fail. Moreover, this test does not have any value as it doesn't give me any confidence that the code is behaving the way it is supposed to.

**Ask yourself**: Can I break this test by altering the correctness of the production code?

[list-thread-safety]: https://docs.microsoft.com/en-us/dotnet/api/system.collections.generic.list-1?view=netframework-4.7.1#Thread_Safety
[fluent-assertions]: http://fluentassertions.com/
[shouldly]: https://github.com/shouldly/shouldly
[application-insights-events]: https://docs.microsoft.com/en-us/azure/application-insights/app-insights-api-custom-events-metrics#trackevent
[new-relic-event]: https://docs.newrelic.com/docs/insights/insights-data-sources/custom-data/insert-custom-events-new-relic-apm-agents
