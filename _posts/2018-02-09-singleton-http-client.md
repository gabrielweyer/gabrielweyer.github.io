---
date: 2018-02-08 20:34:06+00:00
layout: post
title: Singleton HTTP Client
categories:
- C#
tags:
- HttpClient
---

Even though the `class` `HttpClient` implements `IDisposable` it is supposed to be used as a singleton as stated in the [API reference][http-client-reference]:

> `HttpClient` is intended to be instantiated once and re-used throughout the life of an application. Instantiating an `HttpClient` class for every request will exhaust the number of sockets available under heavy loads. This will result in `SocketException` errors.

The accepted best practice is to have one `HttpClient` per HTTP endpoint you're interacting with. This will not only yield better performance it also allows to encapsulate endpoint specific logic (such as setting headers).

Now the question is: how do you configure your `IoC` container to resolve the expected `HttpClient` instance? This used to require a cumbersome registration but `.NET Core 2.1` will ship with the [HttpClientFactory][http-client-factory] making our life much easier.<!--more-->

## `HttpClientFactory`

[Steve Gordon][steve-gordon-blog] has an excellent [post][http-client-factory-post] explaining what is `HttpClientFactory` and how it works.

`HttpClientFactory` aims to provide the following improvements:

- Alleviate sockets exhaustion by reusing connection when possible
- Alleviate stale `DNS` records (by default `HttpClient` caches `DNS` records for its lifetime)
- Easily resolve an `HttpClient` instance linked to a specific HTTP endpoint

What if you can't use `.NET Core` or can't update? Fear not, we can achieve tomorrow's dream with today's tools (most of it anyway).

## Associate an `HttpClient` instance with the service using it

`HttpClient` instances communicating with a specific HTTP endpoint tend to have dedicated settings such as an `Authorization` header, default request headers (`Accept` for example), maybe a `HMAC`... I tend to encapsulate those settings in a `class` to decouple the settings's source from the consummer.

Let's imagine that we're integrating with a fictitious company called *Contoso*. The integration takes place via an HTTP API and our contact at Contoso gave us a bearer token that needs to be set on the `Authorization` header.

The first step is to create a `POCO` modelizing the settings:

{% highlight csharp %}
public class ContosoSettings
{
    public Uri BaseAddress { get; set; }
    public string BearerToken { get; set; }
}
{% endhighlight %}

`HttpClient` makes writing tests harder. Developers tend to derive from `HttpMessageHandler` and provide an implementation allowing them to assert the requests issued by the `HttpClient`. I prefer to introduce an interface called `IHttpClient` exposing a single method to handle `HTTP` traffic:

{% highlight csharp %}
public interface IHttpClient
{
    Task<HttpResponseMessage> SendAsync(HttpRequestMessage request);
}
{% endhighlight %}

We then implement the `ContosoHttpClient` that will be dedicated to communicating with the `Contoso` API:

{% highlight csharp %}
public class ContosoHttpClient : HttpClient, IHttpClient
{
    public ContosoHttpClient(ContosoSettings settings)
    {
        BaseAddress = settings.BaseAddress;
        DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", settings.BearerToken);
    }
}
{% endhighlight %}

And finally we registers the `Type`s in the `IoC` container:

{% highlight csharp %}
const string contosoHttpClientAutofacKeyName = "ContosoHttpClient";

builder.RegisterType<ContosoHttpClient>()
    .Named(contosoHttpClientAutofacKeyName, typeof(IHttpClient))
    .SingleInstance();

builder.RegisterType<ContosoClient>()
    .WithParameter(new ResolvedParameter(
        (pi, ctx) => pi.ParameterType == typeof(IHttpClient),
        (pi, ctx) => ctx.ResolveNamed<IHttpClient>(ContosoHttpClientAutofacKeyName)))
    .AsImplementedInterfaces().InstancePerRequest();

// Abbreviated: resolve and register ContosoSettings (from Web.config, appsettings.json, CSV, volumen...)
{% endhighlight %}

This snippet is using `Autofac` [named service][autofac-named-service]. Using a `named service` this way has several benefits:

- If someone registered another `IHttpClient` that is supposed to be used everywhere else we will not override the registration for all the other services while still retrieving an instance of `ContosoHttpClient` when resolving `IContosoClient`.
- The `named service` is an implementation details that only the `IoC` container knows about.

## Solve stale DNS records

Let's say you're interacting with an API hosted at `https://api.contoso.com`, `HttpClient` will first have to resolve the domain name to an `IP` thanks to a `DNS` server. But what happens if the `DNS` record is updated and the domain name now resolves to another `IP`? If you are using a transient `HttpClient` you'll be fine but if you're using a singleton instance (as you should) `Exception`s will start to shoot up in your monitoring system. Should we stop calling APIs, or maybe rewrite everything in `Go`?

The [ConnectionLeaseTimeout][connection-lease-timeout] property can solve this situation nicely for us:

> A `Int32` that specifies the number of **milliseconds** that an active `ServicePoint` connection remains open. **The default is `-1`, which allows an active `ServicePoint` connection to stay connected indefinitely**. Set this property to `0` to force `ServicePoint` connections to close after servicing a request.

This is how you set it:

{% highlight csharp %}
var apiUri = new Uri("https://api.contoso.com");
var sp = ServicePointManager.FindServicePoint(apiUri);
sp.ConnectionLeaseTimeout = 60*1000;
{% endhighlight %}

In the previous snippet I'm keeping the connection opened for a minute which seems like a good trade-off.

## Conclusion

I haven't looked at the implementation of `HttpClientFactory` yet but I suspect the end result will be fairly similar to what I demonstrated above. If you still have doubts about using a singleton `HttpClient` I recommend you to perf test it. At a previous customer I developped an API that was calling other HTTP endpoints, I increased the throughput by a factor of `10` by changing a single thing: I made the `HttpClient` a singleton rather than a per-request scope.

[http-client-reference]: https://docs.microsoft.com/en-us/dotnet/api/system.net.http.httpclient?view=netcore-2.0#Remarks
[http-client-factory-post]: https://www.stevejgordon.co.uk/httpclientfactory-named-typed-clients-aspnetcore
[steve-gordon-blog]: https://www.stevejgordon.co.uk/
[connection-lease-timeout]: https://docs.microsoft.com/en-us/dotnet/api/system.net.servicepoint.connectionleasetimeout?view=netframework-4.7.1#System_Net_ServicePoint_ConnectionLeaseTimeout
[autofac-named-service]: http://autofaccn.readthedocs.io/en/latest/advanced/keyed-services.html#named-services
[http-client-factory]: https://github.com/aspnet/HttpClientFactory
