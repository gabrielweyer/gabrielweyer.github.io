---
date: 2014-12-07 06:16:14+00:00
layout: post
title: 'Barnes and Noble: a tale of poor security practices'
summary: Barnes & Noble has a pretty lax approach of security.
categories:
- Security
---

Being the happy owner of a Kindle I usually buy my ebooks on Amazon. They have a very large selection to choose from and normally sell all the latest releases. To my surprise they only had "[Enigma of China][enigma-china]" from Qiu Xialong in paperback and hardcover formats. [Kobo][kobo-enigma-china] didn't have it at all but after searching for a while I found out that Barnes & Noble sold it as a [NOOK Book][barnes-nobles-enigma-china] for $10.

So far, so good or so it seemed. It turned out that Barnes & Noble has such a lax approach of security that at the end I decided not to purchase from them. You'll find below the reasons that motivated my decision.<!--more-->

## I Sign in and registration in a new window

The first issue made itself apparent very quickly: when clicking on the "Sign in" link the browser will open a new window. This new window does not contain a toolbar, which means that users won't be able to use some password managers (such as 1Password, the Chrome extension being accessible through a button in the toolbar).

I know that you can work around it as the [Sign in][sign-in] page is also available directly on the website. You can also use the shortcut "Ctrl + \" within the new window in order to enter your credentials via 1Password but I don't think that everybody is a power user. Basically opening a new window instead of loading a page creates extra-friction when using a password manager.

Of course the registration page is also located in a new window and within this page things got even more interesting!

## II Mixed content warning

As they're loading a dedicated sign in page, you would expect Barnes & Noble to use SSL properly. As it turned out the source code contains a link to an HTTP iframe. Chrome (rightly so) blocks the content and displays a warning:

[![Sign in: mixed content warning]({{ "/assets/2014-12-07-barnes-and-noble-a-tale-of-poor-security-practices/barnes-and-noble-sign-in-mixed-content-warning.png" | prepend: site.baseurl }})]({{ "/assets/2014-12-07-barnes-and-noble-a-tale-of-poor-security-practices/barnes-and-noble-sign-in-mixed-content-warning.png" | prepend: site.baseurl }})

The most interesting part is that the tracking page is also available via [SSL][double-click-tls]. The sign in page being loaded only over SSL, the link could have been hardcoded as SSL too.

## III Weak password policy

So Barnes and Noble decided to limit the number of characters I can use in my password to 15. Not only this but they're also preventing me from using any special characters. I'm not sure what "_numeric symbol_" means, some special characters might be allowed but as a user I've no idea which one I can use.

[![Barnes & noble: password policy]({{ "/assets/2014-12-07-barnes-and-noble-a-tale-of-poor-security-practices/barnes-and-noble-password-policy.png" | prepend: site.baseurl }})]({{ "/assets/2014-12-07-barnes-and-noble-a-tale-of-poor-security-practices/barnes-and-noble-password-policy.png" | prepend: site.baseurl }})

It's quite strange that the security answer is limited to 15 characters, what if my favorite movie is "[The Shawshank Redemption][shawshank-redemption])"? Security questions are a terrible practice anyway as people tend to use easily guessable answers (as you can see in the screenshot I get my password manager to generate one for me).

## IV Mixed content warning on payment page

Even the payment page comes with a shiny warning:

[![Barnes & Noble: payment mixed content warning]({{ "/assets/2014-12-07-barnes-and-noble-a-tale-of-poor-security-practices/barnes-and-noble-payment-mixed-content-warning.png" | prepend: site.baseurl }})]({{ "/assets/2014-12-07-barnes-and-noble-a-tale-of-poor-security-practices/barnes-and-noble-payment-mixed-content-warning.png" | prepend: site.baseurl }})

This is due to the fact that the search form is posting to an [HTTP endpoint][payment-http] even when the page is loaded over SSL.

At this stage I decided to give up, buying this book is not worth taking the risk of exposing my credit card data.

## Special bonus: credit card number used in the DRM

Barnes and Noble decided to protect its content via the highly controversial use of a [DRM][drm] system (Amazon has made the same choice). The goal is to prevent the consumer from sharing it's purchase with any other user. Of course DRM don't work and they're only being a major annoyance to the people actually paying for content.

What is unusual is that Barnes and Noble decided that it would use your **credit card number** in order to sign the DRM. This means that this data is included with your ebooks and could potentially be extracted.

## How could Barnes & Noble address those issues?

Instead of opening a new window for sign in and registration the site should merely link to a new page. As a matter of fact they already have them in place: [sign in][sign-in-https] and [registration][resgitration-https].

They should also link to the SSL URL of the DoubleClick script on their sign in and registration page.

Passwords should not be restricted in terms of character set or length. If you really want to have an upper limit it should be set to something ridiculously high (such as 100 characters). In fact they should instead enforce stronger passwords (combination of letters, numbers and symbols).

The payment should be on a page of its own and not use the same layout (I don't think that users need to be able to look for a book while entering their credit card details).

And please stop encoding my credit card number into the books I'm buying from you. If you're afraid I'll remove your precious DRM and share the book on Internet there is nothing preventing you to use a unique string linked to my account.

Some of those points are extremely easy to address (new page for sign in and registration, SSL URL for the tracking script), others will certainly be more challenging but are nevertheless necessary.

[enigma-china]: (http://us.macmillan.com/enigmaofchina/qiuxiaolong)
[kobo-enigma-china]: http://store.kobobooks.com/en-US/Search/Query?query=Enigma%20of%20China&dontModifyQuery=True
[barnes-nobles-enigma-china]: http://www.barnesandnoble.com/w/enigma-of-china-qiu-xiaolong/1114701902?ean=9781250025814
[sign-in]: https://www.barnesandnoble.com/signin
[double-click-tls]: https://4476037.fls.doubleclick.net/activityi;cat=signi0;ord=1641192771;src=4476037;type=signi0?
[shawshank-redemption]: http://www.imdb.com/title/tt0111161/
[payment-http]: http://www.barnesandnoble.com/s/Enigma-of-China?store=allproducts&keyword=Enigma+of+China
[drm]: http://en.wikipedia.org/wiki/Digital_rights_management
[sign-in-https]: https://www.barnesandnoble.com/signin
[resgitration-https]: https://www.barnesandnoble.com/register
