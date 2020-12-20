---
date: 2020-12-20 21:24:56+11:00
layout: post
title: Azure Functions and their limitations
summary: Rough edges around the HTTP binding, development experience and Application Insights integration when working with Azure Functions.
categories:
- Azure
- Azure Functions
- Application Insights
---

I've recently started using Azure Functions. What interested me most was to understand why users are picking Functions over "plain" Azure Web Apps to host HTTP APIs. I found the HTTP binding to be limited, the development experience to be clunky and the Application Insights integration to behave differently that on ASP.NET Core.

In this post I'll describe the limitations I faced when working with Azure Functions. In follow-up posts I'll describe the workarounds I'm using to address some of these limitations.<!--more-->

I created a [sample project][github-azure-function-limitation] to demonstrate the behaviours I'm describing in this post.

## HTTP binding

Azure Functions do not support [middleware][asp-net-core-middleware] out of the box. I don't think I've built a single ASP.NET Core API in the past without using middleware. The Framework itself is relying on them: from authentication, health check to header propagation ([list of built-in middleware][built-in-middleware]). This makes implementing cross-cutting concerns problematic. As soon as you have more than one Function in your app, you'll need to decide how to implement authorisation, validation...The Azure Functions team is working on an [out-of-process .NET 5 worker][dotnet-5-support-on-azure-function] that will introduce "_a customizable middleware pipeline_".

There is no [TestServer][asp-net-core-integration-test]. This makes integration tests harder as you can't run the whole pipeline in-memory. You can't easily verify whether you're using `camelCase` or `PascalCase` for serialising properties' name for example. This also means that you're left with asserting the returned _object_ rather than an HTTP response. This can lead developers to test implementation details such as whether the Function returned a `StatusCodeResult` or an `ObjectResult` instead of asserting the returned status code. Finally, developers need to craft an `HttpRequest` when calling a Function in a test.

When running on a consumption plan, you'll experience [cold starts][cold-starts]. Most of the time an Azure Function will "only" take a few seconds to wake-up but sometimes it can take more than 30 seconds. If your APIs are users facing, this results in a poor user experience.

## Development experience

The Azure Functions tooling uses a custom console logging provider. This provider does not display the stack trace when an exception is thrown. If you want to know where an exception originated, you'll have to run with a debugger attached.

![No stack trace in the console]({{ "/assets/azure-functions-limitations/console-stack-trace.png" | prepend: site.baseurl }})

[EasyAuth][easy-auth] is not supported when running locally. This is not a limitation of Azure Functions but of EasyAuth itself.

Running Functions over HTTPS on Windows is clunky.

![Automatic certificate generation is not supported]({{ "/assets/azure-functions-limitations/use-https.png" | prepend: site.baseurl }})

## Application Insights integration

Azure Functions are automatically monitored by Application Insights. All you need is an instrumentation key. For a team that is getting started on the observability journey, this is great. They'll get insights into how fast their Functions are, they'll get dependencies and exceptions tracking. But this integration comes with some downsides as well. With the default configuration, Azure Functions emit a lot of telemetry. This translates to Application Insights costing a hundred times as much as the Functions they're monitoring!

Each Function execution logs two traces: one when it starts executing the Function and one when it has executed the Function:

![Two traces per Function execution]({{ "/assets/azure-functions-limitations/function-execution-log.png" | prepend: site.baseurl }})

Exceptions are logged twice for the HTTP binding:

![The same exception is logged twice for the HTTP binding]({{ "/assets/azure-functions-limitations/http-binding-exception-logged-twice.png" | prepend: site.baseurl }})

Exceptions are logged three times for the Service Bus binding:

![The same exception is logged three times for the Service Bus binding]({{ "/assets/azure-functions-limitations/service-bus-binding-exception-logged-three-times.png" | prepend: site.baseurl }})

In fact, for this execution, the Functions runtime emitted eight telemetry items:

![Service Bus binding: eight telemetry items emitted by the Functions runtime]({{ "/assets/azure-functions-limitations/service-bus-binding-execution-eight-telemetry-items.png" | prepend: site.baseurl }})

Telemetry Processor is not supported out of the box. It is discussed at length in this [GitHub issue][unsupported-telemetry-processor]. This might seem like a minor issue, but it makes it harder to filter out superfluous telemetry items.

Finally trying to retrieve the `TelemetryConfiguration` from the container without having set the `APPINSIGHTS_INSTRUMENTATIONKEY` setting results in an exception:

![TelemetryConfiguration is not registered when APPINSIGHTS_INSTRUMENTATIONKEY is missing]({{ "/assets/azure-functions-limitations/telemetry-configuration-not-registered.png" | prepend: site.baseurl }})

## Azure Deployment

This is not a limitation of Azure Functions but a common issue I see with existing Functions. They lack the `RUN_FROM_PACKAGE` setting. In some rare cases this results in deployments being marked as successful even though the code was not deployed. Run from a package has a [section][run-from-package] dedicated to it in the Functions documentation.

## Conclusion

In this post I listed the inconveniences I experienced while working with Azure Functions. In order of preference here are the issues I'd like to see fixed the most:

1. Lack of telemetry processor support
1. Lack of middleware support
1. Lack of in-memory integration tests support
1. No stack trace in the console
1. Clunky local HTTPS support

In the following posts I'll be describing some workarounds I'm using.

[asp-net-core-middleware]: https://docs.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-5.0
[asp-net-core-integration-test]: https://docs.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-5.0
[cold-starts]: https://mikhail.io/serverless/coldstarts/azure/
[secret-manager]: https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets?view=aspnetcore-5.0&tabs=windows#secret-manager
[easy-auth]: https://docs.microsoft.com/en-us/azure/app-service/overview-authentication-authorization
[built-in-middleware]: https://docs.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-5.0#built-in-middleware
[dotnet-5-support-on-azure-function]: https://techcommunity.microsoft.com/t5/apps-on-azure/net-5-support-on-azure-functions/ba-p/1973055
[unsupported-telemetry-processor]: https://github.com/Azure/azure-functions-host/issues/3741
[run-from-package]: https://docs.microsoft.com/en-us/azure/azure-functions/run-functions-from-deployment-package#enabling-functions-to-run-from-a-package
[github-azure-function-limitation]: https://github.com/gabrielweyer/azure-functions-limitations
