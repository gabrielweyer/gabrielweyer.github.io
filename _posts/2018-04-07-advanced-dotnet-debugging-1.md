---
date: 2018-04-07 13:17:02+10:00
layout: post
title: 'Advanced .NET Debugging #1'
summary: Finding the entry point of a native image.
categories:
- WinDbg
- Advanced .NET Debugging
---

After eyeing it for a while I finally decided to buy [Advanced .NET Debugging][advanced-dotnet-debugging-book] by Mario Hewardt. I've been studying `WinDbg` for some time and consider myself somewhere between beginner and intermediate level. To my dismay I got stuck on the first excercise! Luckily I didn't give up and finally stumbled on a blog post that unblocked me. This series has for goal to make [Advanced .NET Debugging][advanced-dotnet-debugging-book] more accessible to people - quite like me - that haven't grasped all the concepts yet.

## Prerequisites

- A hex viewer
  - I used the [hexdump for VSCode][hexdump-for-vscode] Visual Studio Code extension
- [WinDbg][get-windbg]
- Windows<!--more-->

## The problem

In the section **Loading Native Images**, Mario explains how Windows is loading a native image using `Notepad.exe` (`%SystemRoot%\notepad.exe`) as an example. As the first step, Mario instructs the reader to:

> go to file offset `0x108` where you will find the `AddressOfEntryPoint` field

The book was written a few years ago and back then Mario was running `Windows Vista` (most likely in `32-bit` too). If you look at the same file offset in `Windows 10 64-bit` you'll be disapointed:

![No AddressOfEntryPoint]({{ "/assets/advanced-dotnet-debugging-1/no-address-of-entry-point.png" | prepend: site.baseurl }})

OK, there are quite a few things to unpack in this screenshot.

### Hexadecimal

Each white cell represents a `byte`. A `byte` has 256 different values (from `0` to `255`). If we want to represent the value `255` in `base 2` (`binary`), we would need 8 characters: `11111111`. The same value in `base 10` (`decimal`) still requires 3 characters: `255`. In `base 16` (`hexadecimal`) we only need 2 characters: `FF`. Hence `hexadecimal` strikes a good balance between brevity and not being too remote from the decimal base we human-beings use. You can use the `Windows 10` calculator in `Programmer` mode to convert between `hexadecimal` and `decimal`:

![Convert between hex and dec]({{ "/assets/advanced-dotnet-debugging-1/win-10-calc.png" | prepend: site.baseurl }})

### File offset

The `byte`s are displayed from left to right and top to bottom. They are accessed via a **file offset**, represented by the blue numbers. The left column represents the 7 most significant digits while the top row represents the least significant digit.

![File offset]({{ "/assets/advanced-dotnet-debugging-1/file-offset.png" | prepend: site.baseurl }})

The cell on the third row (`00000020`) and last column (`0F`) has a **file offset** of `0000002F`. **File offset**s are 4 `byte`s long, so every time we'll be looking for an offset or an address we know it'll be encoded over 4 `byte`s.

### Endianness

Windows is a [little-endian][endianness] system. This means than the least significant `byte`s will appear **before** the most significant ones. So if you were to find the following value: `E0 93 01 00`, the address would be `00 01 93 E0` - only the `byte` order is inverted, not the order within a `byte` - which would commonly be written as `0x193E0` (`0x` denotes a hex notation and the leading `0`s are dropped as they are not significant).

## Figuring out the file offset of `AddressOfEntryPoint`

Now that we know how to read the `hex` dump, we're still left with the same problem: there is no address where it's supposed to be. This is when I started to browse the Internet trying to understand where `AddressOfEntryPoint` was supposed to be located. My quest initially took me to the [PE Format specification][pe-format], after reading it for a while I ended up being more confused than I initially was. The situation was dire and I needed some hope, and hope did appear in the person of Simon Cooper and his brilliant post [Anatomy of a .NET Assembly – PE Headers][anatomy-dotnet-assembly-pe-headers]. This illustration details the required steps to find the value of the `AddressOfEntryPoint`:

![AddressOfEntryPoint]({{ "/assets/advanced-dotnet-debugging-1/address-of-entry-point.png" | prepend: site.baseurl }})

Thanks to Simon's detailed write-up I was able to figure out the file offset of the `AddressOfEntryPoint` (`0x120`), I also found its value: `0x193E0`. You can use the below formula to compute the `AddressOfEntryPoint` file offset based of the signature file offset:

> Signature file offset + `0x28` = `AddressOfEntryPoint` file offset

If we look back at the screenshot above we can see than the signature file offset was `0xF8`. Hence `0xF8` + `0x28` = `0x120`, which is exactly what we found without using the formula.

## Relative virtual address

But we're now faced with another issue, the address entry point (`0x193E0`) resolves to some kind of wasteland:

![That can't be the entry point!]({{ "/assets/advanced-dotnet-debugging-1/wasteland.png" | prepend: site.baseurl }})

The Portable Executable format has the concept of **Relative Virtual Address** (`RVA`) which it defines like this:

> In an image file, the address of an item after it is loaded into memory, with the base address of the image file subtracted from it.

As it turns out the `AddressOfEntryPoint` is **not** a file offset, it is actually a `RVA`.

So we need to *load Notepad in memory* which equates to running it. But we also need to be able to see the `base address` of the image which is not something than the `Task Manager` or any other basic tool will be able to provide us. To see this value we need a debugger. Open `Notepad.exe` (`%SystemRoot%\notepad.exe`) using [WinDbg Preview][windbg-preview]:

![Opening Notepad with WinDbg Preview]({{ "/assets/advanced-dotnet-debugging-1/open-notepad-windbg-preview.gif" | prepend: site.baseurl }})

Type the command [List Loaded Modules][list-loaded-modules]:

{% highlight text %}
0:000> lm
start             end                 module name
00007ff6`f92f0000 00007ff6`f9331000   notepad    (deferred)
00007ffd`09ce0000 00007ffd`09f49000   COMCTL32   (deferred)
00007ffd`0abb0000 00007ffd`0ad7c000   urlmon     (deferred)
// Abbreviated
{% endhighlight %}

The value we're interested in is ``00007ff6`f92f0000``, this is the `start` (i.e. the `base address`) of the `notepad` module.

Armed with this information we'll be able to look at the instructions located at the `RVA` `0x193E0` by using the [Unassemble] command:

{% highlight text %}
0:000> u 00007ff6`f92f0000+0x193E0
notepad!WinMainCRTStartup:
00007ff6`f93093e0 4883ec28        sub     rsp,28h
00007ff6`f93093e4 e8c7070000      call    notepad!_security_init_cookie (00007ff6`f9309bb0)
00007ff6`f93093e9 4883c428        add     rsp,28h
00007ff6`f93093ed e902000000      jmp     notepad!__mainCRTStartup (00007ff6`f93093f4)
00007ff6`f93093f2 cc              int     3
00007ff6`f93093f3 cc              int     3
notepad!__mainCRTStartup:
00007ff6`f93093f4 48895c2408      mov     qword ptr [rsp+8],rbx
00007ff6`f93093f9 48897c2410      mov     qword ptr [rsp+10h],rdi
{% endhighlight %}

Bingo!

## Conclusion

I hope this post clarified how to find the entry point of a native Windows executable.

[advanced-dotnet-debugging-book]: https://www.goodreads.com/book/show/7306509-advanced-net-debugging
[hexdump-for-vscode]: https://marketplace.visualstudio.com/items?itemName=slevesque.vscode-hexdump
[get-windbg]: https://github.com/gabrielweyer/nuggets/blob/master/windbg/README.md#download-and-install-windbg
[endianness]: https://en.wikipedia.org/wiki/Endianness
[pe-format]: https://msdn.microsoft.com/library/windows/desktop/ms680547(v=vs.85).aspx
[anatomy-dotnet-assembly-pe-headers]: https://www.red-gate.com/simple-talk/blogs/anatomy-of-a-net-assembly-pe-headers/
[windbg-preview]: https://github.com/gabrielweyer/nuggets/blob/master/windbg/README.md#store
[list-loaded-modules]: https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/lm--list-loaded-modules-
[Unassemble]: https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/u--unassemble-
