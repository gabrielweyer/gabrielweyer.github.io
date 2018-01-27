---
date: 2016-06-13 10:46:32+00:00
layout: post
title: beIN SPORTS CONNECT
categories:
- Security
---

I like football, even with the time difference I try to watch at least the World Cup and the European Championship. I watched the last World Cup on [SBS][sbs] but this time around they only managed to secure a handful of games. As they're a public service it makes sense after all that they wouldn't buy the rights for all the games. A quick search on Google indicated that [beIN SPORTS CONNECT][be-in] is the way to go in Australia - I will refer to this service as beIN for the rest of this post.

# Subscribing

As the pricing seems reasonable I decided to go ahead. The page is loaded over HTTPS so we start well but to my surprise the form contains a **password remainder** field. Password remainders are a bad practice as users tend to fill them with their password (when allowed) or with a hint that is an obvious give away.<!--more-->

As I don't know any of my password, a password reminder is useless to me so I always generate a strong unique random password for this field. After trying to submit the form I got the following error:

![password-remainder]({{ "/assets/2016-06-13-bein-sports-connect/password-remainder.png" | prepend: site.baseurl }})

I don't understand the benefits of restricting the characters I can use. On the contrary it seems to indicate this site is potentially vulnerable to [XSS][xss]. I generate another reminder without "special" characters and get presented with another error:

![invalid-format]({{ "/assets/2016-06-13-bein-sports-connect/invalid-format.png" | prepend: site.baseurl }})

So my valid email address is in an "Incorrect format". How convenient should they ever decide to sell my data to a third party without me being able to track it back to them.

I start to have a bad feeling about the password requirements. After all the only one that is stated is that my password should be at least 6 characters. I decide to use "123456" and also use it as the password reminder. **\<clickbait>**You won't believe what happens next!**\</clickbait>**. Actually I'm sure you knew what would happen: the form happily accepted my password and let me reuse it in the reminder field. Well at least I "_can access the site_ **securely**" (emphasis is mine).

![123456]({{ "/assets/2016-06-13-bein-sports-connect/123456.png" | prepend: site.baseurl }})

One last thing before we move on to the dessert. Does it seem normal to be loading so many third party JavaScript files on a registration page? They're even loading ads and we know what malicious ads do to your browser and it's not kind (malware installation, credentials theft...).

![do-you-need-ads-on-signup.png]({{ "/assets/2016-06-13-bein-sports-connect/do-you-need-ads-on-signup.png" | prepend: site.baseurl }})

# Sign-in form loaded over HTTP

Yes you read that right. Even though the form is POSTing to HTTPS by then it is [too late][load-sign-in-http]. An attacker could have already intercepted the initial HTTP response and pointed the form to the URL of his choosing.

Sometimes websites still offer sign-in over HTTPS when you look for it but it doesn't seem to be the case here.  [https://secure.beinsportsconnect.com.au/][secure] redirects to [http://www.beinsportsconnect.com.au/][http-only] and trying to access [https://www.beinsportsconnect.com.au/][invalid-certificate] results in something you should never see:

![bein-loaded-over-https.png]({{ "/assets/2016-06-13-bein-sports-connect/bein-loaded-over-https.png" | prepend: site.baseurl }})

# Conclusion

If you're already using beIN or are planning on starting to use it at least generate a unique password so that when they get compromised attackers will not gain access to your account on other services.

I understand going all HTTPS would require a tremendous amount of work but beIN could first take some other steps that would make a big difference:

- Remove the password reminder altogether
- Provide a dedicated HTTPS only sign-in page
- Stop loading third-party ads on the sign-in page

[sbs]: http://www.sbs.com.au/
[be-in]: http://www.beinsportsconnect.com.au/home
[xss]: https://www.troyhunt.com/understanding-xss-input-sanitisation/
[load-sign-in-http]: https://www.troyhunt.com/your-login-form-posts-to-https-but-you/
[secure]: https://secure.beinsportsconnect.com.au/
[http-only]: http://www.beinsportsconnect.com.au/
[invalid-certificate]: https://www.beinsportsconnect.com.au/
