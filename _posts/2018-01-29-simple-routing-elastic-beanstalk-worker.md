---
date: 2018-01-28 20:24:33+00:00
layout: post
title: Simple Routing for Elastic Beanstalk Worker tier
summary: Allows to route a SQS message to a specific endpoint on the Elastic Beanstalk Worker instead of having a single endpoint handling all the messages.
categories:
- OSS
tags:
- ASP.NET Core
- AWS
- Elastic Beanstalk
- Simple Routing
---

`Elastic Beanstalk` offers both a `Web` tier and a `Worker` tier. This allows developers to build reasonably complex applications without having to maintain moving pieces. Offloading heavy-duty workloads to the worker in order to keep the web tier responsive is as easy as putting a message on a queue.

![HTTP Path]({{ "/assets/simple-routing-elastic-beanstalk-worker/http-path.png" | prepend: site.baseurl }})

One annoyance that I have with `Beanstalk` is that there is no way to direct a message to a specific endpoint, hence leaving a single endpoint the responsibility of distributing the messages to all their handlers and potentially leading to brittle code. But it doesn't have to be that way.<!--more-->

## Implementation

`SQS` messages have [attributes][sqs-attributes], attributes can be set by the sender and are read by the receiver. The idea is to use a known attribute to attach routing metadata to the message.

### Constants

Constants are the base of any decently built `C#` application. I did not want to depart from to this rule and hence added some constants:

{% highlight csharp %}
public static class RoutingConstants
{
    public const string HeaderName = "Task";
    public const string HeaderType = "String";
}
{% endhighlight %}

These constansts will be used to add routing metadata to the `SQS` message.

We can then define our routes via some more constants:

{% highlight csharp %}
public static class WorkerConstants
{
    public const string DoSomeWorkTaskName = "do-some-work";
    public const string DoSomeOtherWorkTaskName = "do-some-other-work";
}
{% endhighlight %}

**Note**: those two `class` will have to be referenced by the sender and the `Worker`.

### Sending the message

The sender will most likely be the `Web` tier but it could be any system being able to send a message to a `SQS` queue.

{% highlight csharp %}
var sendMessageRequest = new SendMessageRequest();
// Abbreviated: set properties on sendMessageRequest, such as the MessageBody and the QueueUrl

// We're using RoutingConstants.HeaderName as the MessageAttribute key
// and WorkerConstants.DoSomeWorkTaskName as the MessageAttribute value
sendMessageRequest.MessageAttributes.Add(
    RoutingConstants.HeaderName,
    new MessageAttributeValue {StringValue = WorkerConstants.DoSomeWorkTaskName, DataType = RoutingConstants.HeaderType});

// Abbreviated: send the message
{% endhighlight %}

### Middleware

In the `Worker`, the routing is implemented via a `Middleware`:

{% highlight csharp %}
public static class HeaderRoutingMiddleware
{
    // Elastic Beanstalk prefixes the SQS messages properties' name with "X-Aws-Sqsd-Attr-"
    private static readonly string TaskHeaderName = $"X-Aws-Sqsd-Attr-{RoutingConstants.HeaderName}";

    public Task Invoke(HttpContext context)
    {
        // We get the value of the routing header
        StringValues task = context.Request.Headers[TaskHeaderName];

        // And set it as the path
        context.Request.Path = $"/{task.Single()}";

        return _next(context);
    }
}
{% endhighlight %}

**Note**: don't forget to add `HeaderRoutingMiddleware` to the `IApplicationBuilder`.

### Controller

The last piece of the puzzle is defining the expected route on the `Controller`:

{% highlight csharp %}
// This is important, we do not want a prefix in front of the action's route
[Route("")]
public class SomeController : Controller
{
  // The route has to match the value given to the MessageAttribute
  [HttpPost(WorkerConstants.DoSomeWorkTaskName)]
  public async Task<IActionResult> SomeMethod(SomeModel model)
  {
      // Abbreviated for clarity
  }
}
{% endhighlight %}

## Simple routing

I used `Simple Routing` in production over the last few months and am now confident that it does what it's supposed to do. This is why I decided to release it under a `MIT` license to allow others to benefit from my work.

`Simple Routing` is available:

- On `NuGet` as the package [BeanstalkWorker.SimpleRouting][nuget-simple-routing]
- A `GitHub` [release][github-release]
- As [source][github-simple-routing] on `Github`
  - The implementation is so simple that you can just copy the classes into your own solution if that works better for you

### Demo

The `Simple Routing` solution contains a `SampleWeb` app, you can either:

- Send "work" - `Send/Work`
- Send "nothing" - `Send/Nothing`

#### Send messages

{% highlight text %}
GET http://localhost:5000/Send/Work HTTP/1.1
Host: localhost:5000
{% endhighlight %}

![Send Work]({{ "/assets/simple-routing-elastic-beanstalk-worker/web-send-work.png" | prepend: site.baseurl }})

{% highlight text %}
GET http://localhost:5000/Send/Nothing HTTP/1.1
Host: localhost:5000
{% endhighlight %}

![Send Nothing]({{ "/assets/simple-routing-elastic-beanstalk-worker/web-send-nothing.png" | prepend: site.baseurl }})

#### Peek at the messages

Now let's look at the messages in the `SQS` queue:

- The `Work` message

![Work Message Body]({{ "/assets/simple-routing-elastic-beanstalk-worker/message-work-body.png" | prepend: site.baseurl }})

![Work Message Attributes]({{ "/assets/simple-routing-elastic-beanstalk-worker/message-work-attributes.png" | prepend: site.baseurl }})

- The `Nothing` message

![Nothing Message Body]({{ "/assets/simple-routing-elastic-beanstalk-worker/message-nothing-body.png" | prepend: site.baseurl }})

![Nothing Message Attributes]({{ "/assets/simple-routing-elastic-beanstalk-worker/message-nothing-attributes.png" | prepend: site.baseurl }})

#### Handle the messages

Launch the `SampleWorker` app. When running in `ElasticBeanstalk` the [Sqsd daemon][sqsd-daemon] reads `SQS` messages from the `SQS` queue and `POST` the content to your `Worker`. But we're running the `Worker` on our machine and the `Sqsd daemon` is not available. This is why I wrote `Beanstalk Seeder`.

> [Beanstalk Seeder][beanstalk-seeder] emulates the `SQS Daemon` surrounding an `Elastic Beanstalk` `Worker Tier` so that you can replicate the interaction between a `Web Tier` and a `Worker Tier` on your machine.

##### Handling the `Work` message

- `Beanstalk Seeder`

![Work Message Beanstalk Seeder]({{ "/assets/simple-routing-elastic-beanstalk-worker/beanstalk-seeder-work.png" | prepend: site.baseurl }})

- `Worker`

![Work Message Worker]({{ "/assets/simple-routing-elastic-beanstalk-worker/worker-work.png" | prepend: site.baseurl }})

##### Handling the `Nothing` message

- `Beanstalk Seeder`

![Nothing Message Beanstalk Seeder]({{ "/assets/simple-routing-elastic-beanstalk-worker/beanstalk-seeder-nothing.png" | prepend: site.baseurl }})

- `Worker`

![Nothing Message Worker]({{ "/assets/simple-routing-elastic-beanstalk-worker/worker-nothing.png" | prepend: site.baseurl }})

I wrote a detailed guide in the [GitHub repository][github-simple-routing]. Give it a try and let me know if it works for you.

[github-release]: https://github.com/gabrielweyer/simple-routing/releases
[nuget-simple-routing]: https://www.nuget.org/packages/BeanstalkWorker.SimpleRouting/
[github-simple-routing]: https://github.com/gabrielweyer/simple-routing
[sqs-attributes]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-message-attributes.html
[sqsd-daemon]: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/using-features-managing-env-tiers.html
[beanstalk-seeder]: https://github.com/gabrielweyer/beanstalk-seeder
