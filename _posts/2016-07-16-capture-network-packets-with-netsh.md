---
date: 2016-07-16 09:20:07+00:00
layout: post
title: Capture network packets with netsh
summary: Troubleshoot a broken Certification Authority with netsh.
tags:
- netsh
---

Another day, another "interesting" issue at a customer. After deploying our product we were left with a partially working web application. The product has been developed over many years and is a mix of ASP Classic, Web Forms, MVC and Web API. In this case ASP Classic pages were broken and would throw an error.

## Ensuring ASP Classic is configured properly

The first step is to ensure that IIS has been configured to execute ASP Classic and this is done easily by adding a dummy ASP page to the web application. After deploying this page I was able to confirm that it was working as expected.

{% gist 5eb3198119bead02649c0fe11d733055 %}

![dummy-asp]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/dummy-asp.png" | prepend: site.baseurl }})<!--more-->

## Enabling failed request tracing

The features written in ASP Classic have been written many years ago and the developers didn't consider logging as a key part of the development process. The end result being that when something goes wrong no logs get written by the application or to the event viewer.

The second step is to turn on the "**Failed Request Tracing Rules**" and reload the failing page. Internet has a lot of tutorials around this but they're all missing key steps, I'll focus on those as you can find everything else easily.

"Failed Request Tracing Rules" will not be available in the IIS Manager if you didn't turn on the **Tracing** feature in Windows Features:

![tracing]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/tracing.png" | prepend: site.baseurl }})

Another thing is that multiple sites could be writing traces at the same time. Each site will be writing to a different sub folder suffixed with the site ID:

![site-id]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/site-id.gif" | prepend: site.baseurl }})

Finally you can copy the log files back to your machine, don't forget to copy the freb.xsl file too, you'll then be able to open the XML files in Internet Explorer and look at a human readable representation of the log.

![invalid-authority]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/invalid-authority.png" | prepend: site.baseurl }})

All ASP Classic pages are calling an API endpoint in order to get a token (long story short: don't ask - the user is signing-in in an AngularJS app backed by Web API and is then able to use seamlessly the pages hosted on MVC, Web Forms and Classic ASP). What is strange in this situation is that Internet Explorer is marking the TLS certificate as valid, so does Chrome. Even worse: the same ASP Classic page hosted on my machine calling the token endpoint on the remote server is successful! The Windows Certificate Manager is displaying the same message for the root CA, intermediate CA and certificate: "This certificate is OK.".

I then suspected the certificate might be using unsupported ciphers but it turned out that it wasn't the case. I quickly wrote a C# Console application calling the same token endpoint - the HttpClient class is throwing meaningful errors - but to my dismay the C# code was able to call the endpoint successfully!

Armed with the ErrorCode "80072f0d" and the Description "The certificate authority is invalid or incorrect" I scoured Internet for some potential solutions. Everything I could find was related to invalid and self-signed certificates.

## Capturing packets on a Windows Server

When people think "packet capture" they always assume they need to install [Wireshark][wireshark] (or another similar tool) whereas Windows Server is shipping with the ability to capture network packets with [netsh][netsh] since Windows Server 2008 R2. The advantage of this solution is that you don't need to install anything on the machine. To see if it's available, all you need to do is open a command prompt and type:

{% highlight posh %}
netsh trace
{% endhighlight %}

![netsh-trace]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/netsh-trace.gif" | prepend: site.baseurl }})

Now that we know that **trace** is available we need to start capturing the packets and reproduce the problem. Launch an **elevated** command prompt and type:

{% highlight posh %}
netsh trace start tracefile="C:\tmp\traces\classic.etl" scenario=internetclient capture=yes maxsize=200 filemode=circular overwrite=yes
{% endhighlight %}

**Note**: the path needs to exist beforehand.

![start-stop]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/start-stop.gif" | prepend: site.baseurl }})

Starting and stopping the trace is actually slower that what is demonstrated above but I didn't want lo lose your attention! And of course you would need to reproduce the issue before issuing:

{% highlight posh %}
netsh stop
{% endhighlight %}

## Microsoft Message Analyzer

We now need to analyze this trace and this is done with the [Microsoft Message][microsoft-message-analyzer-one] [Analyzer][microsoft-message-analyzer-two] (can be downloaded [here][download-message-analyzer]). The Analyzer takes a long time to open the smallest trace but once the trace is loaded you can search quickly.

We'll first look for an HTTP CONNECT, use this filter:

```
(HTTP.Method == "CONNECT") And
(HTTP.Uri.Host == "domain.name") And
(HTTP.Uri.Port == "port")
```

![connect.png]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/connect.png" | prepend: site.baseurl }})

As we can see the CONNECT was successful. Let's investigate the TLS handshake now, this is handled by the TLS module so all we need to do is filter on this module only:

> TLS

This is what was captured when the C# application connected to the token endpoint:

![c-sharp-tls]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/c-sharp-tls.png" | prepend: site.baseurl }})

This is matching closely what is described in the [RFC 5246][rfc-5246] (TLS 1.2).

![full-handshake]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/full-handshake.png" | prepend: site.baseurl }})

Let's now capture the traffic when the VB code is trying to call the token endpoint.

![vb-tls.png]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/vb-tls.png" | prepend: site.baseurl }})

Great Scott! The server is sending `ServerHello` as expected but the client doesn't reply with `ClientKeyExchange`. I then removed the filter and started to look at the messages below. My reasoning was that I should be finding some kind of error message soon after and here it was:

![browsing-messages]({{ "/assets/2016-07-16-capture-network-packets-with-netsh/browsing-messages.png" | prepend: site.baseurl }})

The error message was:

> A certificate chain processed, but terminated in a root certificate which is not trusted by the trust provider. (0x800B0109)

As it turned out someone had messed up with the certificate store and removed the intermediate CA from the "Intermediate Certification Authorities". As the root CA was still present in the "Trusted Root Certification Authorities" it was good enough for Internet Explorer and C# but it wasn't for VB! I added the intermediate CA to the store and things started to work again.

[wireshark]: https://www.wireshark.org/
[netsh]: https://technet.microsoft.com/en-us/library/dd878517(v=ws.10).aspx
[microsoft-message-analyzer-one]: https://technet.microsoft.com/en-us/library/jj649776.aspx
[microsoft-message-analyzer-two]: https://blogs.technet.microsoft.com/messageanalyzer/
[download-message-analyzer]: https://www.microsoft.com/en-au/download/details.aspx?id=44226
[rfc-5246]: https://tools.ietf.org/html/rfc5246#page-36
