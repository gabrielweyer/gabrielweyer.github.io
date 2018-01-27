---
date: 2014-01-07 09:13:53+00:00
layout: post
title: Why You Should Not Use Chrome Extensions
categories:
- Security
tags:
- Chrome Extensions
- Security
---

Google Chrome Extensions have been [launched][wikipedia] officially in January 2010. Their goal is to extend the browser by providing additional features, for example you could add a weather extension and then be able to see the weather's forecast in your city in one click. Extensions have become widely popular and you're now wondering what could be the issue with them.

# Much more power than expected

Google [uses]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/ads-13.png" | prepend: site.baseurl }}) a system of [permissions][permissions] to determine what an extension will be able to do once installed. Those permissions are divided into three alert levels: high, medium and low. So far, so good? Not really, even the low level allows an extension to harvest your browsing history and the content of your clipboard.

Extensions are built using JavaScript and HTML. Those are the exact same technologies used on websites. I'm sure you're aware how modern websites refresh part of their content without reloading the whole page. Extensions can do this too: nothing is preventing a low level alert extension to detect that you're pasting your email and password on Facebook in order to login. Then the extension can send the collected information to a remote server.

In this case the exploit is fairly limited, you need the user to be copying / pasting the email and password for this to work (the extension would also collect everything that the user is copying and pasting). Whats about the medium and high level alert? This is where the real fun start, at this level of trust extensions can do whatever they want!

A medium alert level extension can generate HTML elements on a page. It could perfectly hide a login form, replace it by it's own, harvest your credentials and submit the hidden login form. A high alert level extension can do similar things but on your computer! This means that it could take your picture via your webcam, browse your hard drive looking for interesting files...

You would think that all of this is hypothetical and Google would certainly remove any malicious extension, but in this case you would be wrong.<!--more-->

# Technical breakdown of a malicious extension

**Warning**: this part is somehow technical.

On the 5th of December 2013 I noticed that ads started to appear on top of Google Image Search. I've never seen ads there before. It also had this strange sentence "Ads not from this site". I was intrigued and it didn't take me long to find the culprit: [Awesome Screenshot: Capture & Annotate][extension].

Turns out a new version was published on the 5th of December and this is when it started to display ads. I wasn't the only user to notice:

[![ads-1]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/ads-13.png" | prepend: site.baseurl }})]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/ads-13.png" | prepend: site.baseurl }}) [![ads-2]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/ads-23.png" | prepend: site.baseurl }})]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/ads-23.png" | prepend: site.baseurl }}) [![ads-3]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/ads-32.png" | prepend: site.baseurl }})]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/ads-32.png" | prepend: site.baseurl }})

After a couple of hours everything went back to normal: I enabled the extension again and noticed that it wasn't displaying ads anymore. I decided to dig deeper and downloaded the source code of the extension.

Everything starts here: `\javascripts\content_script.js` [[line:763-781][js-ready]]

{% gist 8248634 %}

This code is commented. I suspect this is because they pushed a second version the same day (this file was the only one modified on the 5th of December). It's very easy to understand what's going on here: if the user is browsing a site owned by Google the code should call `addAD` (the function name in itself is rather explicit). The script will also reload the ads 1.5 seconds after the user has finished typing in the search bar.

The function `addAD` is located in the same file `\javascripts\content_script.js [[line:631-668][js-add-ad]]. The code is a bit too long to past here but it's calling another function [[line:635][js-send-request]]

{% gist 8248711 %}

This function will retrieve the ads and create the markup [[line:644-646][js-create-element]]

{% gist 8248593 %}

The best part is located here: `\javascripts\bg.js` [[line:154-184][js-ip]]

First they're doing a HTTP GET at: [http://api.hostip.info/get_json.php][js-get-json] and getting JSON as a reply

{% gist 8248818 %}

The funny part is that I'm located in Melbourne and I was not using a proxy or a VPN at this time!

Then this line says it all [[line:162][js-add]]

{% gist 8248849 %}

I find it really scary. These guys are obviously not very smart, they could just have replaced Google Ads by their own and keep exactly the same design. This way they could have stayed unnoticed for much longer. This also means (most likely) that there is nothing preventing extensions from harvesting passwords (either directly via JavaScript or by inserting DOM elements in the page). This extension has over a million users, the fact that they were not taken down indicates that Google needs to improve its security practices for extensions.

# Why hasn't this been exploited more?

I suspect it has been used widely already. Recipe: create a popular extension (emulate a paying service for free, launch a football world cup tracker...), push an update that will sometimes be malicious. If the number of reports does not reach a certain threshold Google won't investigate. Rinse and repeat.

In fact this same extension was used again but for a different attack on the 17th of December:

[![data-collection-1]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/data-collection-1.png" | prepend: site.baseurl }})]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/data-collection-1.png" | prepend: site.baseurl }}) [![data-collection-2]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/data-collection-2.png" | prepend: site.baseurl }})]({{ "/assets/2014-01-07-why-you-should-not-use-chrome-extensions/data-collection-2.png" | prepend: site.baseurl }})

There is no accountability: most of the companies publishing extensions are completely unknown. Even if Google was to act they could just create new extensions under another name.

# Take Away

I stopped using Chrome extensions and I think you should too. The risks vastly overshadow the benefits. In fact I think it is safe to use Chrome Extensions in a couple of cases:

- When they come from a reputable source (Google, Evernote, Dropbox...)
- When they're part of a service you're paying for (1Password for example)
- When they're open source

[wikipedia]: http://en.wikipedia.org/wiki/Google_Chrome#Extensions
[permissions]: https://support.google.com/chrome_webstore/answer/186213?hl=en&rd=1
[extension]: https://chrome.google.com/webstore/detail/awesome-screenshot-captur/alelhddbbhepgpmgidjdcjakblofbmce/details
[js-ready]: https://github.com/gabrielweyer/code-sample/blob/master/technical-blog/chrome-ext/src/3.5.7/javascripts/content_script.js#L763-L781
[js-add-ad]: https://github.com/gabrielweyer/code-sample/blob/master/technical-blog/chrome-ext/src/3.5.7/javascripts/content_script.js#L631-L668
[js-send-request]: https://github.com/gabrielweyer/code-sample/blob/master/technical-blog/chrome-ext/src/3.5.7/javascripts/content_script.js#L635
[js-create-element]: https://github.com/gabrielweyer/code-sample/blob/master/technical-blog/chrome-ext/src/3.5.7/javascripts/content_script.js#L644-L646
[js-ip]: https://github.com/gabrielweyer/code-sample/blob/master/technical-blog/chrome-ext/src/3.5.7/javascripts/bg.js#L154-L184
[js-get-json]: http://api.hostip.info/get_json.php
[js-add]: https://github.com/gabrielweyer/code-sample/blob/master/technical-blog/chrome-ext/src/3.5.7/javascripts/bg.js#L162
