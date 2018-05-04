---
date: 2018-05-19 11:58:34+10:00
layout: post
title: 'Advanced .NET Debugging #2'
categories:
- Advanced .NET Debugging
---

I'm continuing to read the excellent [Advanced .NET Debugging][advanced-dotnet-debugging-book] by Mario Hewardt. Last time I looked at [finding the entry point of a native image][entry-point-native-image]. This time around I'll be investigating the launch of a **managed** image by `Windows`.

## Prerequisites

- A hex viewer
  - I used the [PE CLR Viewer][pe-clr-viewer] (**disclaimer**: I created this truly ugly looking website)<!--more-->

## The problem

In the section **Loading .NET Assemblies** Mario explains how `Windows` is loading a managed image. He's leveraging [dumpbin.exe][dumpbin-reference] which requires a `Visual Studio` installation **with** the `C++` workload. This has two issues:

- The `C++` workload requires a few `GB` of hard drive
- `dumpbin` presents a high-level view of the different headers, hence it's not a good teaching tool as it abstracts the process of reading the bytes

I decided to try a different approach. I've compiled a **x86** managed image which you can download [here][net461-x86]. You can then visualise it using the [PE CLR Viewer][pe-clr-viewer] and follow me down the rabbit hole.

## Finding the `AddressOfEntryPoint`

I recommend you first read the [previous post][entry-point-native-image] in this series as it explains core concepts such as [endianness][entry-point-native-image-endianness] and [Relative Virtual Address][entry-point-native-image-rva].

Last time I highlighted a formula to compute the `AddressOfEntryPoint` file offset:

> Signature file offset + `0x28` = `AddressOfEntryPoint` file offset

The `signature file offset` is always at file offset `0x3C`. As seen below it has for value `0x80`.

![Signature file offset]({{ "/assets/advanced-dotnet-debugging-2/signature-file-offset.png" | prepend: site.baseurl }})

Now that we have the `signature file offset`, we can compute the `AddressOfEntryPoint` file offset:

> `0x80` + `0x28` = `0xA8`

![AddressOfEntryPoint]({{ "/assets/advanced-dotnet-debugging-2/address-of-entry-point.png" | prepend: site.baseurl }})

As seen above, `AddressOfEntryPoint` has for value `0x2716`. But wait we're not done, the `AddressOfEntryPoint` is a `RVA` which we need to convert to a file offset.

## Converting the entry point `RVA` to a file offset

The entry point is located in the **.text** section (the **.text** section contains executable code), so we'll need to locate the **.text** section first and this is where the **section headers** come into play. The **section headers** is a conversion table between `RVA` and file offset for the different sections:

![.text section header]({{ "/assets/advanced-dotnet-debugging-2/text-section-header.png" | prepend: site.baseurl }})

According to the screenshot above the **.text** section has a base `RVA` of `0x2000` and is located at file offset `0x200`. Those two pieces of information will allow us to convert the entry point `RVA` into an entry point file offset:

> Entry point `RVA` - .text base `RVA` + .text file offset = entry point file offset

Let's replace the placeholders with the values we obtained previously:

> `0x2716` - `0x2000` + `0x200` = `0x916`

The entry point has for file offset `0x916`. But as we'll see in the next section, this is yet another level of indirection.

## Jumping into the Import Address Table

![JMP]({{ "/assets/advanced-dotnet-debugging-2/jump.png" | prepend: site.baseurl }})

Apparently the first part (`FF25`) is the [x86 instruction][jmp] for `JMP` which instruct the computer to jump to an address (the second part):

> `JMP 402000`

`0x402000` is a `VA` (`Virtual Address`) based on the **image base** which has a value of `0x400000` (as seen in the **NT specific fields header** section):

![Image Base]({{ "/assets/advanced-dotnet-debugging-2/image-base.png" | prepend: site.baseurl }})

Armed with this knowledge we can convert the `VA` to a `RVA`:

> `VA` - image base `VA` = `RVA`

Let's replace the placeholders with the values we obtained previously:

> `0x402000` - `0x400000` = `0x2000`

If we look at the **Data directories** section, we can see than the **Import Address Table** is located at `RVA` `0x2000`. The **Import Address Table** is the first section of the **.text** section.

![Import Address Table RVA]({{ "/assets/advanced-dotnet-debugging-2/import-address-table-rva.png" | prepend: site.baseurl }})

## Jumping out of the Import Address Table

![Import Address Table]({{ "/assets/advanced-dotnet-debugging-2/import-address-table.png" | prepend: site.baseurl }})

The `RVA` located at file offset `0x200` is: `0x26F8`. Like a mad rabbit, we continue jumping around. We can reuse the formula to convert a `RVA` to a file offset:

> `0x26F8` - `0x2000` + `0x200` = `0x8F8`

Now I have good news, `0x8F8` is our final destination. Let's inspect it more closely:

![Real entry point]({{ "/assets/advanced-dotnet-debugging-2/real-entry-point.png" | prepend: site.baseurl }})

We skip the leading `NUL` bytes, the other bytes are `ASCII` characters. The first section is the function name `_CorExeMain` and - coming after a `NUL` byte - the second section is the name of the executable: `mscoree.dll`.

As it turns out `mscoree.dll` is located in the `Windows` directory:

![mscoree]({{ "/assets/advanced-dotnet-debugging-2/mscoree.png" | prepend: site.baseurl }})

## Conclusion

I've demonstrated how to find the entry point of a **x86** managed image but in reality `Windows` knows how to execute a managed image just by looking at the **CLI header**. In the case of **x64** managed image the entry point is not even present!

[advanced-dotnet-debugging-book]: https://www.goodreads.com/book/show/7306509-advanced-net-debugging
[pe-clr-viewer]: https://peclrviewer.azurewebsites.net/
[dumpbin-reference]: https://docs.microsoft.com/en-us/cpp/build/reference/dumpbin-reference
[net461-x86]: https://gabrielweyer.blob.core.windows.net/blog-samples/advanced-dotnet-debugging-2/net461-x86.exe
[jmp]: https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/x86-instructions#control_flow
[entry-point-native-image]: {{ site.baseurl }}{% post_url 2018-04-07-advanced-dotnet-debugging-1 %}
[entry-point-native-image-endianness]: {{ site.baseurl }}{% post_url 2018-04-07-advanced-dotnet-debugging-1 %}#endianness
[entry-point-native-image-rva]: {{ site.baseurl }}{% post_url 2018-04-07-advanced-dotnet-debugging-1 %}#relative-virtual-address
