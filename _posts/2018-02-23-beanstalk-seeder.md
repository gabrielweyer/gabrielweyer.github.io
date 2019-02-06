---
date: 2018-02-23 23:40:46+00:00
layout: post
title: Beanstalk Seeder
summary: Emulates the SQS Daemon surrounding an Elastic Beanstalk Worker Tier so that you can replicate the interaction between a Web Tier and a Worker Tier on your machine.
categories:
- OSS
tags:
- ASP.NET Core
- AWS
- Elastic Beanstalk
- SQS
- Serilog
---

`Elastic Beanstalk` is a great platform, it offers both a `Web` tier and a `Worker` tier. I recently wrote about [Simple Routing][simple-routing-post] one of my library that allows you to route a `SQS` message to a specific endpoint on the `Worker`.

While `Beanstalk` works great once it's deployed to `AWS` there is no easy way to run it locally. As soon as you want to execute an end-to-end flow involving both the `Web` and the `Worker` you need to manually `POST` requests to the `Worker` using [Postman][postman] which is cumbersome and error-prone.

As it core all the [SQS daemon][sqs-daemon] does is dequeue messages from a `SQS` queue and `POST` it to a specified endpoint. With this goal in mind I wrote [Beanstalk Seeder][beanstalk-seeder].<!--more-->

I had the following objectives:

- Users should be able to get up and running quickly
- Meaningful logging
- Transform the `SQS` [message attributes][sqs-message-attributes] into HTTP headers (in order to support [Simple Routing][simple-routing])

## Get up and running quickly

You can get `Beanstalk Seeder` from [GitHub releases][beanstalk-seeder-releases]. Download the archive and extract it somewhere.

`Beanstalk Seeder`'s [configuration][beanstalk-seeder-configuration] is detailed in the `README`. All you need is a `iAM` user, the `Worker` `URI` and the `SQS` queue `URI.`

## Meaningful logging

When running a third-party tool, it's critical to get meaningful logging as the binary is a black-box for the end user. I use [structured logging][structured-logging] in order to make querying the log events a breeze. My logging framework of choice is [Serilog][serilog-tutorial].

{% highlight csharp %}
var loggerConfiguration = new LoggerConfiguration()
    .Destructure.ByTransforming<MessageAttributeValue>(Destructure)
    .Destructure.ByTransforming<Message>(Destructure)
    .MinimumLevel.Is(serilogLevel)
    .Enrich.WithDemystifiedStackTraces()
    .Enrich.FromLogContext()
    .WriteTo.Console(serilogLevel);
{% endhighlight %}

The previous snippet highlights only a few of the `Serilog` features.

### The structure-capturing operator

`MessageAttributeValue` and `Message` are both defined in the `awssdk.sqs` `NuGet` package. I'm interested in logging only some of their properties, `Serilog` has the ability to capture object via the [structure-capturing operator][capturing-objects].

### Enrichment

> Enrichment is the act of adding additional properties to events, other than the ones originating from the message template.

`Serilog` supports [ambient context][ambient-context]. I'm also using the excellent [Ben.Demystifier][demystifier] for getting nicer stack traces.

### Sinks

By default, `Serilog` does not log anywhere. In order to record events you'll need to configure one or more `Sink`s. In this case I'm writing to the console but they are [many other][provided-sinks] `Sink`s available.

### Result

![HTTP Path]({{ "/assets/beanstalk-seeder/events.png" | prepend: site.baseurl }})

I hope the recorded events are descriptive enough so that an end user know what's happening:

- First I display the settings used, this is important as they could come from the `appsettings.json`, environment variables or even the [user secrets][secret-manager] if the environment is `Development`.
- Then using the `structure-capturing operator` I log the relevant `SQS` message properties.
- Instead of logging the complete HTTP request I log the content of the body and the relevant headers.
- When deleting the message, I log the `ReceiptHandle`, this is the value used to delete a message and the user can correlate it to what was displayed above.
- Finally, rather than not displaying anything when there are no messages in the queue I inform the user that's the case and how long I'll wait before retrying.

## Interestings bits

I'm using a [CancellationTokenSource][cancellation-token-source] so that the user can stop the message pump at any time (relying on [Console.CancelKeyPress][cancel-key-press]).

The [MessagePump][message-pump] `class` is the only `class` with some logic. I wrote some [tests][message-pump-tests] around the cancellation token, the transformation of `SQS` message attributes into HTTP headers and the back-off when no messages are available in the queue.

## Conclusion

I hope you'll find [Beanstalk Seeder][beanstalk-seeder] as useful as I did, combined with [Simple Routing][simple-routing] it simplified and streamlined my `Elastic Beanstalk` development.

I also wanted to point out that `Beanstalk Seeder` is platform agnostic. It doesn't matter if you're developing using `Node.js`, `Go` or any other of the [Elastic Beanstalk supported platforms][elastic-beanstalk-supported-platforms], all you need to do is install the latest [.NET Core runtime][dotnet-runtime] (available on `Windows`, `macOS` and `Linux`).

[simple-routing-post]: {{ site.baseurl }}{% post_url 2018-01-29-simple-routing-elastic-beanstalk-worker %}
[postman]: https://www.getpostman.com/
[sqs-daemon]: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/using-features-managing-env-tiers.html
[beanstalk-seeder]: https://github.com/gabrielweyer/beanstalk-seeder
[beanstalk-seeder-settings]: https://github.com/gabrielweyer/beanstalk-seeder#configuration
[simple-routing]: https://github.com/gabrielweyer/simple-routing
[beanstalk-seeder-releases]: https://github.com/gabrielweyer/beanstalk-seeder/releases
[sqs-message-attributes]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-message-attributes.html
[beanstalk-seeder-configuration]: https://github.com/gabrielweyer/beanstalk-seeder#configuration
[serilog-tutorial]: https://blog.getseq.net/serilog-tutorial/
[structured-logging]: https://nblumhardt.com/2016/06/structured-logging-concepts-in-net-series-1/#what-is-structured-logging
[capturing-objects]: https://nblumhardt.com/2016/08/serialized-data-structured-logging-concepts-in-net-6/#capturing-objects
[enrichment]: https://blog.getseq.net/serilog-tutorial/#5taggingeventsforfilteringandcorrelation
[ambient-context]: https://blog.getseq.net/serilog-tutorial/#enrichingwithambientcontext
[demystifier]: https://github.com/benaadams/Ben.Demystifier
[provided-sinks]: https://github.com/serilog/serilog/wiki/Provided-Sinks
[cancellation-token-source]: https://docs.microsoft.com/en-us/dotnet/api/system.threading.cancellationtokensource?view=netcore-2.0
[cancel-key-press]: https://docs.microsoft.com/en-us/dotnet/api/system.console.cancelkeypress?view=netcore-2.0
[message-pump]: https://github.com/gabrielweyer/beanstalk-seeder/blob/ca47d6f84fe748915a22de63b23a34ef735a88ae/src/BeanstalkSeeder/Services/MessagePump.cs
[message-pump-tests]: https://github.com/gabrielweyer/beanstalk-seeder/blob/ca47d6f84fe748915a22de63b23a34ef735a88ae/tests/BeanstalkSeederTests/MessagePumpTests.cs
[elastic-beanstalk-supported-platforms]: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html
[dotnet-runtime]: https://www.microsoft.com/net/download/windows
[secret-manager]: https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets?tabs=visual-studio#secret-manager
