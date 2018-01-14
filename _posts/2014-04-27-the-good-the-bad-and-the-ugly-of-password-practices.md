---
date: 2014-04-27 09:17:31+00:00
layout: post
title: The Good, the Bad and the Ugly of password practices
categories:
- Security
tags:
- password
---

Internet has taken a preponderant place in our lives and most of us regularly purchase goods on Internet or use Internet banking. The access to the services we use is protected by a password and humans are not good at managing passwords:

- Most of us will reuse the same password on many services (combine this with the fact that people also use the same email address to log in into said services and you get an explosive mix when security is breached on one [service][gawker-breach]).
- Most of us will use weak passwords, basically as weak as the service will allow. Not only our passwords are weak they're also extremely [predictable][predictable-password].

To address those issues you need to use **strong unique** passwords. By **strong** I mean that your passwords should be:

- long (let's say at least 25 characters)
- a mix of lower / upper case letters, digits and symbols
- randomly generated (by a random generator not by you typing random keys on your keyboard)

By **unique** I mean that you should _never_ reuse a password. You should set a different password on each service. As we tend to use many services and tend to log in from multiple devices (home and work computers, smartphones, tablets..) it makes it impossible to remember all those strong passwords.

Google has [recommended][google-strong-password] the use of sentence and substitution, something even stronger has been advocated by [xkcd][xkcd-strong-password]. But this doesn't work. I use over a hundred different services, how could I remember a hundred different sentences? Common substitutions (the one you will use) are also well documented and will be attempted by the attackers to guess your password. Other experts have advised to [get rid of passwords][no-password] altogether, but this opinion is unconventional to say the least.

Want it or not we're stuck with passwords for the  predictable future. Luckily there is a solution: it's called a password manager. With a password manager you'll only need to remember one password (the master password), all the other ones will be entered automatically for you in the login forms. I use [1Password][one-password], but there are other products on the market: [LastPass][last-pass], [KeePass][kee-pass], [RoboForm][robo-form]... Most of those products are not free but I'm sure you'll prefer to drop a few dozens dollars every few years instead of seeing your online (and sometimes offline) life ruined.

Now that I've addressed password best practices on the users' side it's time to mention the other side. The services that you use should do everything they can in order to protect your password. There is a [lot][owasp-web] to say in this area but I decided to address the features that are easily observable:

- passwords requirements: services shouldn't restrict the length of our passwords (at least not smaller than a few dozens characters) or the characters' set that we can use (this would reduce the entropy)
- [proper use of HTTPS][proper-tls]
- [reset password feature][reset-password]

Due to the [Heartbleed][heartbleed] vulnerability I decided to change some of my passwords recently. To my surprise many well known services impose some strong restrictions on the passwords users can set. Shall we get started? The offenders are ordered from worst ones to the most benign ones.

## The ugly

> Use at your own risk. Most of those services do not use HTTPS properly or force you to choose passwords that are easily guessable.

- [Air France][air-france]

Not only Air France is loading the login form over HTTP, the password policy they enforce is a 4 digits PIN!

- [Caisse d'Epargne][caisse-epargne]

One of the biggest French bank, forcing its users to use a 5 digits PIN as a password (and the login is the account number which is a semi-public information).

- [Weibo][weibo]

The service logs users in over HTTP and limiting the password length to 16 characters.

- [Doodle][doodle]

The service logs users in over HTTP! According to [them][doodle-heartbleed], they updated their system to patch the vulnerability. Of course as they don't use HTTPS they were never vulnerable to this specific vulnerability in the first place.

## The bad

> Use with caution. Those services are not getting security, they're exposing your passwords in clear via email.

- [UberStrike][uber-strike]

The service is currently using an expired certificate. When changing your password you'll receive an email containing your new password in clear (and stating "We've reset your UberStrike password" [_sic_]).

[![uberstrike-change-password]({{ "/assets/2014-04-27-the-good-the-bad-and-the-ugly-of-password-practices/uberstrike-change-password.png" | prepend: site.baseurl }})]({{ "/assets/2014-04-27-the-good-the-bad-and-the-ugly-of-password-practices/uberstrike-change-password.png" | prepend: site.baseurl }})

- [IELTS][ielts]

The service does not allow you to change your password. This password is in fact your reference number that you need to use in every communication with IELTS' staff.

- [Astrill][astrill]

Astrill provide VPN services and allow (among other things) to access blocked websites from Mainland China. A VPN also prevents attackers from listening to your traffic. This service is mainly about security and so you would expect them to have pretty good practices in terms of passwords. It turns out that if you're not currently a paying customer you can't change your password. Even worse the support staff does not have the ability to delete your account and will instead send you a new password in clear via email (you can read the full conversation [here]({{ "/assets/2014-04-27-the-good-the-bad-and-the-ugly-of-password-practices/astrill-change-password.png" | prepend: site.baseurl }}))!

[![astrill-reset-password]({{ "/assets/2014-04-27-the-good-the-bad-and-the-ugly-of-password-practices/astrill-reset-password1.png" | prepend: site.baseurl }})]({{ "/assets/2014-04-27-the-good-the-bad-and-the-ugly-of-password-practices/astrill-reset-password1.png" | prepend: site.baseurl }})

- [INPI][inpi]

This is the French department in charge of registering patents and trademarks. When creating an account they're kind enough to send you your password via email in clear. At least they're deleting inactive accounts after three months.

[![inpi-create-account]({{ "/assets/2014-04-27-the-good-the-bad-and-the-ugly-of-password-practices/inpi-create-account.png" | prepend: site.baseurl }})]({{ "/assets/2014-04-27-the-good-the-bad-and-the-ugly-of-password-practices/inpi-create-account.png" | prepend: site.baseurl }})

## The (almost) good

> In this category you'll find the offenders that almost got it right. But their policies are not good enough to get them off the hook. It's all related to the maximal length of passwords and the allowed symbols.

- [Battle.net][battle-net]

> Your password must be between 8–16 characters in length. Your password may only contain alphabetic characters (A–Z), numeric characters (0–9), and punctuation.

Blizzard has been battling accounts hijacking for years. A better password policy would certainly help protect the accounts of their users.

- [Free][free]

> Your password can't be longer than 16 characters. Characters are restricted to a-z, A-Z, 0-9, #$,;.:*@\[\]()?+=-_%

- [Myki][myki]

> Your password can't be longer than 15 characters.

- [Optus][optus]

> Your password can't be longer than 15 characters.

- [Commonwealth Bank][commonwealth-bank]

> 8 and 16 characters long. can contain most characters except <>^`{}~=

The 16 characters limit is completely unacceptable coming from a bank!

- [Microsoft][microsoft]

> Your password can't be longer than 16 characters.

This is the biggest company present in this list and it's quite disappointing coming from an enterprise software company. Microsoft accounts are also used by businesses to access Azure, MSDN...

- [Origin][origin]

The energy company in Australia (not the gaming service operated by EA).

Not only you can't use symbols but also the password length is limited to 20 characters. Origin only allows you to change your password once per 24 hours, I've no idea why this is the case on how it can make the service more secure.

- [SNCF][sncf]

> Password must only contain numbers and/or letters. The length should not be bigger than 25 characters.

- [RenRen][ren-ren]

RenRen is limiting the password length to 20 characters.

- [Viadeo][viadeo]

> Your password can't be longer than 20 characters.

- [BTGuard][bt-guard]

The service prevents you from using symbols altogether:

> Password must only contain numbers and/or letters.

- [myGov][my-gov]

This website allows Australians to manage their social benefits (medicare, Centrelink, child support...). The service has a pretty good policy but restricts you from using certain symbols:

> You can strengthen your password by including a mixture of upper and lower case letters, numbers, and the following special characters: !, @, #, $, %, ^, &, *.

- [WordPress][word-press]

> ERROR: Passwords may not contain the character "\\".

This is a minor violation as WordPress is only preventing us from using a single symbol and this is why the service sits at the last position of this list.

[gawker-breach]: http://www.geekosystem.com/gawker-hack-acai-spam-twitter/
[predictable-password]: https://www.duosecurity.com/blog/brief-analysis-of-the-gawker-password-dump
[no-password]: https://medium.com/cyber-security/9ed56d483eb
[google-strong-password]: https://www.youtube.com/watch?v=0RCsHJfHL_4
[xkcd-strong-password]: http://xkcd.com/936/
[one-password]: https://agilebits.com/onepassword
[last-pass]: https://lastpass.com/
[kee-pass]: http://keepass.info/
[robo-form]: http://www.roboform.com/
[owasp-web]: http://www.troyhunt.com/2011/06/owasp-top-10-for-net-developers-part-7.html
[proper-tls]: http://www.troyhunt.com/2013/05/your-login-form-posts-to-https-but-you.html
[reset-password]: http://www.troyhunt.com/2012/05/everything-you-ever-wanted-to-know.html
[heartbleed]: http://heartbleed.com/
[air-france]: http://www.airfrance.fr/cgi-bin/AF/FR/en/common/home/home/HomePageAction.do
[caisse-epargne]: https://www.caisse-epargne.fr/particuliers/ile-de-france/accueil.aspx
[weibo]: http://weibo.com/
[doodle]: http://doodle.com/en/
[doodle-heartbleed]: http://en.blog.doodle.com/2014/04/10/important-security-news-from-doodle/
[uber-strike]: https://uberstrike.com/
[ielts]: https://ielts.britishcouncil.org/CandidateLogin.aspx
[astrill]: https://www.astrill.com/
[inpi]: https://depot-marque.inpi.fr/index.html
[battle-net]: http://us.battle.net/en/
[free]: http://www.free.fr/adsl/index.html
[myki]: https://www.mymyki.com.au/NTSWebPortal/Common/getmyki/GetMykiOption.aspx?menu=Get%20myki
[optus]: http://www.optus.com.au/
[commonwealth-bank]: https://www.commbank.com.au/
[microsoft]: http://www.microsoft.com/en-au/default.aspx
[origin]: http://www.originenergy.com.au/
[sncf]: http://en.voyages-sncf.com/en/
[ren-ren]: http://www.renren.com/
[viadeo]: http://www.viadeo.com/
[bt-guard]: https://btguard.com/
[my-gov]: https://my.gov.au/
[word-press]: http://wordpress.com/
