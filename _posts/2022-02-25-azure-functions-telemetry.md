---
date: 2022-02-25 19:33:02+11:00
layout: post
title: Improving Azure Functions Telemetry
summary: Improving Application Insights integration with Azure Functions.
categories:
- Azure
- Azure Functions
- Application Insights
---

A while back I wrote about [Azure Functions and their limitations][azure-functions-limitations]. I highlighted the lack of telemetry processors support and the large volume of telemetry emitted by the runtime as two pain points in the Application Insights integration. I managed to add support for telemetry processors and discard the duplicated telemetry. My implementation was clunky and mostly uncovered by tests but I've been running it for over a year on many Azure Functions and it _seems_ to be working.

I didn't publish my customisation as I was hoping Azure Functions v4 would make it obsolete. I recently played around with In-Process Functions v4 and discovered the same issues are present and the runtime is emitting more telemetry. This motivated me to remove a few rough edges in my implementation and add support for v4.<!--more-->

The code is available on [GitHub][github-azure-functions-telemetry], it has a few sample Azure Functions demonstrating how the customisation behaves. My main goal was to offer an integration aligning closely with the way Applications Insights is configured in ASP.NET Core.

Telemetry processors are added using [AddApplicationInsightsTelemetryProcessor][add-telemetry-processor]. You can add as many processors as you want, they will be called in the expected order and will be executed for all telemetry items.

{% highlight csharp %}
builder.Services
    .AddApplicationInsightsTelemetryProcessor<YourFirstProcessor>()
    .AddApplicationInsightsTelemetryProcessor<YourSecondProcessor>();
{% endhighlight %}

Telemetry initializers are supported out-of-the-box in Azure Functions. [Telemetry initializers are added directly to the Dependency Injection container][add-telemetry-initializer]. You can either provide the `Type` or provide an instance of your initializer depending on your requirements.

{% highlight csharp %}
builder.Services
    .AddSingleton<ITelemetryInitializer, YourInitializer>()
    .AddSingleton<ITelemetryInitializer>(new YourOtherInitializer("NiceValue"));
{% endhighlight %}

The custom integration will get rid of all the duplicate exceptions recorded by Application Insights. It will also discard the "_Executing ..._" and "_Executed ..._" traces emitted by each Function execution.

The integration offers a few additional bells and whistles which are documented in the repository:

- Ability to discard health requests
- Ability to discard Service Bus trigger traces
- Setting status code and request name on Service Bus requests (these are blank in the built-in integration)

I've only focused on the HTTP and Service Bus bindings but hopefully it shouldn't be too hard to improve the integration on other bindings as well.

The library also replaces the custom Functions Console logger by the .NET Console logger. I was frustrated by the lack of exception stack traces on the HTTP binding.

{% highlight csharp %}
builder.Services.AddCustomConsoleLogging();
{% endhighlight %}

The implementation is still moslty uncovered by tests. I haven't (yet) thought of a way to write meaningful tests for the [method][configuration-method] that configures Application Insights. I noticed the Functions team writes end-to-end tests so that might be something to explore.

I've not packaged the customisation into a NuGet package yet, if you're interested please raise an issue on the GitHub repository.

[github-azure-functions-telemetry]: https://github.com/gabrielweyer/azure-functions-telemetry
[add-telemetry-processor]: https://docs.microsoft.com/en-us/azure/azure-monitor/app/api-filtering-sampling#create-a-telemetry-processor-c
[add-telemetry-initializer]: https://docs.microsoft.com/en-us/azure/azure-monitor/app/api-filtering-sampling#addmodify-properties-itelemetryinitializer
[configuration-method]: https://github.com/gabrielweyer/azure-functions-telemetry/blob/e69451c2bb179529a218bbcf7d5a8e13eddd00c9/src/Custom.FunctionsTelemetry/ApplicationInsights/ApplicationInsightsServiceCollectionExtensions.cs#L24-L207
[azure-functions-limitations]: {% post_url 2020-12-20-azure-functions-and-their-limitations %}
