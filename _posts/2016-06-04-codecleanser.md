---
date: 2016-06-04 00:41:48+00:00
layout: post
title: CodeCleanser
summary: A tool whose purpose is to transform C# generated from a DLL so that it can then be determined if two DLLs are semantically identical.
categories:
- C#
- OSS
tags:
- Roslyn
---

Recently I came up with an interesting issue at a customer. A governmental agency contacted us and informed us that due to a Windows update we could experience intermittent issue when trying to communicate with them. All I knew at this stage was that the issue would manifest itself when trying to upload a document and that the integration is done via DLLs that are wrapping a few web services.

After [generating PDBs][generating-pdb] via [dotPeek][dotpeek] and adding them to the Visual Studio symbol cache directory I was able to debug through those third party DLLs and confirm that the issue was indeed located in one of them.

Knowing the DLL is redistributed with the product, is in multiple production versions and that the source control's history is pretty patchy, the question then become: **if we were to get a new DLL could we use it for all the versions?**

To answer this question we will have to assess the differences between the DLL in each version.<!--more-->

# First naive attempt: checksum

Windows ships with a few ways to compute a checksum, [CertUtil][cert-util] is one of them, PowerShell has a [Get-FileHash][get-file-hash] cmdlet and this is what I'll use:

{% highlight posh %}
Get-FileHash <filepath> -Algorithm MD5
{% endhighlight %}

For our purpose MD5 is good enough, if you want to ensure that a file hasn't been tampered with you should be using SHA256 at least.

Sadly the three checksums for the three versions were different. But it doesn't mean the DLLs are semantically different. It could have been metadata, different .NET Framework versions...

At this stage I could have used [Ildasm][ildasm] to try to diff the full source code in one file but according to my previous tries the output end up being different. For sake of completeness I tried again before writing this blog post.

{% highlight posh %}
ildasm <dll-filepath> /text /out=<output-filepath>
{% endhighlight %}

This time is no exception, WinMerge indicates 348 differences! Some of them can be explained away:

[![different-dot-net-version]({{ "/assets/2016-06-04-codecleanser/different-dot-net-version.png" | prepend: site.baseurl }})]({{ "/assets/2016-06-04-codecleanser/different-dot-net-version.png" | prepend: site.baseurl }})

The assemblies have been compiled using different version of the .NET Framework, which makes sense as many years separate those two versions.

Next comes an interesting piece of information that explains why two builds of the same source code always result in two different DLLs:

[![mvid-image-base.png]({{ "/assets/2016-06-04-codecleanser/mvid-image-base.png" | prepend: site.baseurl }})]({{ "/assets/2016-06-04-codecleanser/mvid-image-base.png" | prepend: site.baseurl }})

The [MVID][mvid] changes at every single build, for our purpose we can safely ignore this difference, same goes for the Image base. The other differences are more worrying:

[![different-attributes.png]({{ "/assets/2016-06-04-codecleanser/different-attributes.png" | prepend: site.baseurl }})]({{ "/assets/2016-06-04-codecleanser/different-attributes.png" | prepend: site.baseurl }})

It looks like the Attributes are the same but in a different order. There are hundreds of such instances and as IL is harder to read than C# it's time to move on to another strategy.

# Plan B: generate a project via dotPeek

dotPeek can not only decompile IL to C#, it also can [generate a project from a DLL][dotpeek-generate-project]. Let's give it a spin and close this case!

According to WinMerge, every single file is different! Now I'm a sad panda :(, how could the C# differ even more than the IL? This is due to the fact that as a _convenience_, dotPeek kindly outputs the MVID and the assembly location at the top of each file:

[![dotpeek-mvid-assembly-location]({{ "/assets/2016-06-04-codecleanser/dotpeek-mvid-assembly-location.png" | prepend: site.baseurl }})]({{ "/assets/2016-06-04-codecleanser/dotpeek-mvid-assembly-location.png" | prepend: site.baseurl }})

In our use case, this is rather inconvenient. Luckily WinMerge has a feature called [LineFilters](http://stackoverflow.com/a/22178182/57369) which allows to ignore lines based on Regular Expressions. Two filters later a lot of files are still different:

[![win-merge.png]({{ "/assets/2016-06-04-codecleanser/win-merge.png" | prepend: site.baseurl }})]({{ "/assets/2016-06-04-codecleanser/win-merge.png" | prepend: site.baseurl }})

It's now confirmed, some attributes are in a different order! dotPeek has an [opened bug][dotpeek-bug] regarding this but it hasn't been updated since October 2015 so we can assume it won't be fixed anytime soon. By then I already spent 30 minutes on this task and being a consultant I can't justify spending more time trying to find a (mostly) automated solution. I might be able to pull it off with a Regex but it might also turn to be a rabbit hole. According to the number of different files and hoping it would only be about attributes ordering it should take me less than an hour to go through the difference. It actually only took me 30 minutes and confirmed the assumption that only the order of the attributes was differing.

# Enter CodeCleanser

Fast forward two days, it's Saturday morning and I'm wondering if I can use [Roslyn][roslyn] to solve this problem.

I had 3 objectives:

1. Get rid of the comments at the top of the file
1. Sort Attributes by alphabetical order
1. Wrap up before training

The source code is available [here][code-cleanser], feel free to use it and adapt it to your own needs.

## Get rid of the comments at the top of the file

Let's start by what seems the easiest: removing the comments at the top of the files. What's very nice with Roslyn is that you don't need an actual file, you can pass a string as an argument which makes unit testing very easy. As I'm only planning on doing cosmetic changes and I only care about comparing the two DLLs I don't need to operate at a project or solution level.

Following the TDD principles I'll first write a [test][remove-header-comment-test]:

{% gist b6aaa2c60ba20f8340d32edd4ff87265 %}

This test ensures that everything before the first using statement is removed. Let's now look at the [implementation][remove-header-comment-implementation]:

{% gist ac0976203a5315f16e1bac81963a6a8b %}

The Roslyn documentation defines a [trivia][trivia-definition] as:

> Syntax trivia represent the parts of the source text that are largely insignificant for normal understanding of the code, such as whitespace, comments, and preprocessor directives.

All the code is doing is replace each leading trivia with an empty trivia. I'm sure there is a better way of doing this but this works well enough for my purpose.

## Sort Attributes by alphabetical order

Again we'll start with a [test][sort-attributes-test]:

{% gist 786db1ecb44c689ce18532cda794f0f7 %}

We'll need to pack a bit more power this time. In my case the issue only happened on class, enum and property declarations, CSharpSyntaxRewriter seems to be a good candidate for what I want to achieve. The implementation can be found [here][sort-attributes-implementation]:

{% gist 2daec819f25eca2679174c08985b599e %}

I had to make sure the blank line preceding the first attribute didn't get moved down and that's why there is some logic around leading trivia (prompted by this [test][blank-line-attribute]). Initially I was storing the AttributeListSyntax in a dictionary using the first attribute name as a key, of course I forgot that you could have the same attribute multiple time on a single declaration. It prompted me to write this [test][multiple-attributes]) and adapt my implementation. It took me a few tries to get it right and rather than having to replace the files after each attempt I created a local Git repository, committed the unmodified files and issued a git reset after each attempt.

After running CodeCleanser on the three DLLs I was able to confirm they were identical.

# Plot twist

I contacted the governmental agency and asked them if they could provide us with the new version of their DLL. To my surprise they told me that they're distributing source code only. Sure enough after a few Git commands I discovered we had the code under source control all along! Funnily enough nobody knew about it and it wouldn't have helped anyway as history only go two years back.

# Takeaways

The main takeaway is that everything is immutable in Roslyn. I kept forgetting that Add and AddRange would return a new AttributeListSyntax instead of performing an in place Add. As those methods have not been marked as Pure, ReSharper would not warm me that I didn't use the return type and I would end up with an empty AttributeListSyntax. After 10 seconds of debugging I would exclaim "I'm an idiot" every single time, never gets old! Roslyn has changed a lot between the different Release Candidates and many code sample from Internet won't compile.

During my research I found [https://roslynquoter.azurewebsites.net/][roslyn-quoter], it takes C# as an input and writes out the Roslyn code that will generate it.

I realize CodeCleanser doesn't do much and the whole comparing process still requires some manual steps but I hope it can help someone else.

[generating-pdb]: https://www.jetbrains.com/help/decompiler/2016.1/Generating_PDB_Files.html
[dotpeek]: https://www.jetbrains.com/decompiler/
[cert-util]: http://superuser.com/a/898377/128002
[get-file-hash]: https://technet.microsoft.com/en-us/library/dn520872.aspx
[ildasm]: https://msdn.microsoft.com/en-us/library/f7dy01k1(v=vs.110).aspx
[mvid]: https://msdn.microsoft.com/en-us/library/system.reflection.module.moduleversionid(v=vs.110).aspx
[dotpeek-generate-project]: https://www.jetbrains.com/help/decompiler/2016.1/Exporting_Assembly_to_Project.html
[dotpeek-bug]: https://youtrack.jetbrains.com/issue/DOTP-7063
[roslyn]: https://github.com/dotnet/roslyn
[code-cleanser]: https://github.com/gabrielweyer/CodeCleanser
[remove-header-comment-test]: https://github.com/gabrielweyer/CodeCleanser/blob/4b7b769bdf104461decc7db0f6ce46a890de4351/Tests/RemoveLeadingTriviaTests.cs#L8-L55
[remove-header-comment-implementation]: https://github.com/gabrielweyer/CodeCleanser/blob/4b7b769bdf104461decc7db0f6ce46a890de4351/Logic/CodeCleaner.cs#L39-L47
[trivia-definition]: https://github.com/dotnet/roslyn/wiki/Roslyn%20Overview#syntax-trivia
[sort-attributes-test]: https://github.com/gabrielweyer/CodeCleanser/blob/4b7b769bdf104461decc7db0f6ce46a890de4351/Tests/SortAttributesAlphabeticallyTests.cs#L8-L51
[sort-attributes-implementation]: https://github.com/gabrielweyer/CodeCleanser/blob/4b7b769bdf104461decc7db0f6ce46a890de4351/Logic/AttributesSorter.cs#L46-L66
[blank-line-attribute]: https://github.com/gabrielweyer/CodeCleanser/blob/4b7b769bdf104461decc7db0f6ce46a890de4351/Tests/SortAttributesAlphabeticallyTests.cs#L180-L219
[multiple-attributes]: https://github.com/gabrielweyer/CodeCleanser/blob/4b7b769bdf104461decc7db0f6ce46a890de4351/Tests/SortAttributesAlphabeticallyTests.cs#L53-L9
[roslyn-quoter]: https://roslynquoter.azurewebsites.net/
