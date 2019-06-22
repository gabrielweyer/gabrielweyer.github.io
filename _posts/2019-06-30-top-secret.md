---
date: 2019-06-30 14:10:27+10:00
layout: post
title: Top secret
summary: Removing secrets from Git history.
categories:
- Security
tags:
- Git
---

I was recently working on a project that contained secrets in source control. The team was aware of this fact but had never been able to allocate time to get rid of them. The circumstances changed and I was tasked with cleansing the repository. I was still unfamiliar with the code-base so I started to look around for config files. I realised quickly this approach would not work out:

- Some secrets were hard-coded directly in the code
- Some secrets had previously been committed to source control but had since then been removed

I needed a tool that would not only attempt to identify secrets but would also do so over the complete `Git` history.<!--more-->

## Identify secrets in code

While [git-secrets][git-secrets] found `AWS` access keys, it missed out pretty much anything else (private keys, `API` keys for other services...). My next pick was [truffleHog][truffle-hog]. ~~Based on the name only I had a clear winner~~, `truffleHog` uses both entropy and known patterns to attempt to find secrets. This approach results in a high number of false positive, but it is also the only one that discovered credentials I was unaware of.

> For entropy checks, truffleHog will evaluate the shannon entropy for both the base64 char set and hexadecimal char set for every blob of text greater than 20 characters comprised of those character sets in each diff. If at any point a high entropy string >20 characters is detected, it will print to the screen.

**Warning**: no automated approach will uncover all the secrets. There is no way to prevent developers from creating short secrets with a low entropy and use them in production. Your best hope in this case is that those secrets were committed together with stronger secrets and that they will appear in the output of `truffleHog`.

Running `truffleHog` on a repository is an iterative process. The first run will yield an enormous amount of results which will be impossible to thoroughly review manually. The goal of the initial phase should be to discard files which are unlikely to contain secrets. Package managers lock files, `CSS` and `SVG`s are amongst those files.

A good starting point to reduce the volume of the haystack is to use this exclude file:

{% highlight plaintext %}
# PHP Composer
.*composer.lock$

# npm
.*package-lock.json$

# Yarn
.*yarn.lock$

# Helm
.*requirements.lock$

# CSS
.*\.css$

# SVG
.*\.svg$

# A directory containing your collection of random numbers
data/more-data/

# A single file where you've let a GUID generator roam free
data/super-random.lol
{% endhighlight %}

`truffleHog` is written in [Python][monty-python] and distributed using [pip][pip]. If you're like me and have no idea what those words mean, the quickest way to get started is to use `Docker`. Browse to the directory where the `Git` repository is located and run the following container:

{% highlight powershell %}
docker run -it --rm `
    -v "$($pwd):/opt/scan-me" `
    -v "<output-and-settings-directory>:/opt/truffle-hog" `
    python:3.7-stretch /bin/bash
{% endhighlight %}

The directory `<output-and-settings-directory>` should contain the exclude file we created previously.

Running the previous command will give you a `bash` session within a container with `Python` installed. You'll then need to install `truggleHog` and run it:

{% highlight bash %}
pip install truffleHog

trufflehog \
    --regex \
    --exclude_paths /opt/truffle-hog/exclude.txt \
    file:///opt/scan-me/ > /opt/truffle-hog/output.txt
{% endhighlight %}

The switch `--regex` instructs `truffleHog` to look for [known patterns][truffle-hog-known-patterns] (ranging from private keys, passing by `AWS` access keys to `GCP` `API` keys). The switch `--exclude_paths` points to the exclude file we created previously (in this instance I named it `exclude.txt`). `truffleHog` expects to be looking at a remote `Git` repository but you can direct it to your file system by using `file:///`.

Running `truffleHog` takes some time (13 minutes on a repository with many thousands of commits) but by beeing cheeky we'll be able to reduce the number of runs required.

`truffleHog` outputs its results to the terminal. The potential secrets are coloured in bright yellow using [ANSI escape codes][ansi-escape-codes]:

![ANSI escape codes]({{ "/assets/top-secret/ansi-escape-codes.png" | prepend: site.baseurl }})

At times `truffleHog` gets over-enthusiastic and surrounds a potential secret with **many** `ANSI` escape codes:

![Too many ANSI escape codes]({{ "/assets/top-secret/too-many-escape-codes.png" | prepend: site.baseurl }})

False positives litter the output. In the screenshot above, the _secret_ is actually a portion of the path of an `S3` object. I decided to post-process `truffleHog`'s output using `C#`, but you could use any language to do so. In the [LINQPad][linqpad] script below I:

- Replace duplicate `ANSI` escape codes by a single one
- Remove `ANSI` escape codes surrounding false positives and known secrets

{% highlight csharp %}
void Main()
{
    var truffleHogOutputFilePath =
        @"<output-and-settings-directory>\output.txt";

    var lines = File.ReadLines(truffleHogOutputFilePath);
    var output = new StringBuilder();

    foreach (var line in lines)
    {
        var cleansedLine = LineCleanser.CleanseLine(line);
        output.AppendLine(cleansedLine);
    }

    File.WriteAllText(
        truffleHogOutputFilePath + "-cleansed.txt",
        output.ToString());
}

static class LineCleanser
{
    private static Regex startSecretMatcher =
        new Regex(@"(\[93m)\1+");

    private static Regex endSecretMatcher =
        new Regex(@"(\[0m)\1+");

    private static List<string> valuesToDiscard =
        new List<string>
    {
        // S3 buckets
        "3ec1ae061c27325c7ecb543adf91235e22cbc9ed",
        // Static asset hash
        "c6c10016babba0a092e034a0745bd581"
   };

    public static string CleanseLine(string line)
    {
        line = startSecretMatcher.Replace(line, "$1");
        line = endSecretMatcher.Replace(line, "$1");

        foreach (var valueToDiscard in valuesToDiscard)
        {
            line = line.Replace(
                $"[93m{valueToDiscard}[0m",
                valueToDiscard);
        }

        return line;
    }
}
{% endhighlight %}

This script runs in a few seconds and you'll be able to iterate quickly.

1. Open `output.txt` in `Visual Studio Code`
1. Search for `[93m`
1. Add the _secret_ to the values to discard list (if it is an actual secret, write it down)
1. Run the `LINQPad` script
1. Return to step `2`

After some cycles you'll reach a much cleaner output. You might discover files you want to exclude from `truffleHog` (which would require you to run `truffleHog` again) or you could decide to discard those via scripting.

By now you should have a list of secrets and entire files that are secrets (private keys, license files...).

## Purging secrets

[BFG Repo-Cleaner][bfg-repo-cleaner] removes big files and secrets from your `Git` history. It requires `Java 8`, I already had it installed on my machine, but you could run it in `Docker` if you needed to.

The first step is to clone the repository as a [bare repository][bare-repository]:

> A bare repository [...] does not have a locally checked-out copy of any of the files under revision control. That is, all of the Git administrative and control files that would normally be present in the hidden `.git` sub-directory are directly present in the [...] directory instead, and no other files are present and checked out.

You can clone a repository as a bare repository using the following command:

{% highlight bash %}
git clone --mirror https://github.com/rtyley/bfg-repo-cleaner.git project-backup.git
{% endhighlight %}

By convention the directory containing a bare repository should end with the suffix `.git`.

Copy the content of the `project-backup.git` directory into a directory called `project-secrets.git` (this is so that we don't have to clone the repository again at every successive try).

You can then run `BFG Repo-Cleaner` with the following command:

{% highlight powershell %}
java -jar "C:\tools\bfg\bfg.jar" `
    --delete-folders "{ancient-directory,useless-directory}" `
    --delete-files "{pfx-password.txt,my-super-private-key.key,private-key-for-iis.pfx,production-database-backup.sql,*.psd,all.min-626ed116.js.map}" `
    --replace-text "C:\tools\bfg\project-secrets.txt" `
    project-secrets.git
{% endhighlight %}

When running `truffleHog` I identified that two directories (`ancient-directory` and `useless-directory`) have not been in use for quite some time. They contain many files I want to purge from the `Git` history. The `--delete-folders` is used to remove a directory and its content from history. `BFG Repo-Cleaner` **does not support full path for directories and files**, so you'll either only be able to delete objects with a unique name or delete all objects sharing the same name.

With `--delete-files` I'm deleting the backup from our production database amongst other files and all the `PSD` files. Another approach is to use the `--strip-blobs-bigger-than` switch to delete files bigger than a certain size.

The switch `--replace-text` points to the secrets we found when running `truffleHog`. `BFG Repo-Cleaner` will replace them with the string `***REMOVED***`. Each secret should be on its own line:

{% highlight plaintext %}
bc7cbdbde3df4166ae8724cc2acc5ee7
my-top-secret-secret
{% endhighlight %}

`BFG Repo-Cleaner` runs super quickly (a handful of seconds on the repository I was working on) but you need to scrutinise the output with care. If you get a warning about dirty files, this means some secrets are still present in the `HEAD` and by default `BFG Repo-Cleaner` doesn't modify the contents of the latest commit on your `HEAD`. Here is an example of such a warning:

{% highlight plaintext %}
Protected commits
-----------------

These are your protected commits, and so their contents will NOT be altered:

 * commit e31fec6c (protected by 'HEAD') - contains 4 dirty files :
        - some-directory/production-database-backup.sql (98.9 KB)
        - other-directory/pfx-password.txt (99.5 KB)
        - ...

WARNING: The dirty content above may be removed from other commits, but as
the *protected* commits still use it, it will STILL exist in your repository.

Details of protected dirty content have been recorded here :

C:\Code\project-secrets.bfg-report\2019-06-18\16-59-18\protected-dirt\

If you *really* want this content gone, make a manual commit that removes it,
and then run the BFG on a fresh copy of your repo.

Cleaning
--------
{% endhighlight %}

You need to remove those secrets through a commit and then run `BFG Repo-Cleaner` again. **Do not move on to the next step until this warning is gone**. This is the output you should expect when the `HEAD` is clean:

{% highlight plaintext %}
Protected commits
-----------------

These are your protected commits, and so their contents will NOT be altered:

 * commit e31fec6c (protected by 'HEAD')

Cleaning
--------
{% endhighlight %}

Finally let's ensure that `Git` itself doesn't store anything any more about the objects we've just removed from history:

{% highlight bash %}
cd project-secrets.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
{% endhighlight %}

The last step involves pushing back the changes to the `remote`. Quite often the `master` branch will be protected, you will need to lift this restriction before pushing:

{% highlight bash %}
git push
{% endhighlight %}

You also need to keep in mind that **you will lose the links** between your `Pull Requests`, work items, builds... and commits as the `Ids` identifying the commits will change. You should merge as many `Pull Requests` as you can before starting this process and warn your teammates that they will need to clone the repository again after you're done.

[git-secrets]: https://github.com/awslabs/git-secrets
[truffle-hog]: https://github.com/dxa4481/truffleHog
[pip]: https://pypi.org/project/pip/
[monty-python]: https://en.wikipedia.org/wiki/Monty_Python
[truffle-hog-known-patterns]: https://github.com/dxa4481/truffleHogRegexes/blob/master/truffleHogRegexes/regexes.json
[ansi-escape-codes]: https://en.wikipedia.org/wiki/ANSI_escape_code
[linqpad]: https://www.linqpad.net/
[bfg-repo-cleaner]: https://rtyley.github.io/bfg-repo-cleaner/
[bare-repository]: https://git-scm.com/docs/gitglossary.html#def_bare_repository
