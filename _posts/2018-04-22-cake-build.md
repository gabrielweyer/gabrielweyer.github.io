---
date: 2018-04-22 09:57:02+10:00
layout: post
title: Cake build
summary: Demonstrates a basic build of a .NET NuGet package using https://cakebuild.net/.
categories:
- CI/CD
tags:
- AppVeyor
- CircleCI
- Azure DevOps
---

**25th of Sep 2021**: I decided to remove Travis CI from this post. Travis CI recently [poorly handled a security vulnerability][travis-ci-exposed-secrets] and security is of paramount importance when it comes to build systems.

**5th of Jan 2019**: a lot has been happening since I initially wrote this post. `Azure DevOps` released a free tier for open source projects, the `Cake` and `GitVersion` contributors have been hard at work to take advantage of the latest features of `.NET Core`. So many things have changed that I decided to update this post to reflect the current state of affairs (inclusion of `Azure DevOps`, upgrade to `.NET Core 2.2`, utilisation of `.NET Core global tools` and removing the `Mono` requirement on `Unix` platforms).

As a developer I'm amazed by the number of free tools and services available. I wanted to create an end-to-end demo of a `CI/CD` pipeline that would include:

- [Trigger a build on commit][trigger-build-commit]
- [Use semantic versioning][use-semantic-versioning]
- [Run tests][run-tests]
- [Publish test results][publish-test-results]
- [Create NuGet packages][create-nuget-packages]
- [Publish the NuGet packages][publish-nuget-packages]
- [Create a GitHub release][create-github-release]

For my purpose I wanted anonymous users to have access to a read-only view. I initially selected [AppVeyor][app-veyor] as it seems to be the most popular choice for `.NET` open-source projects. But while browsing around I discovered that projects were often using more than one platform. [CircleCI][circle-ci] seemed to be the other prevailing option. Since the initial version of this post, [Azure DevOps][azure-devops] has released a ~~free and unlimited plan for open source projects~~ ([this is not the case any more][change-in-azure-pipelines-grant-for-public-projects]). I decided to leverage the three platforms so that I could highlight their pros and cons.<!--more-->

## Configuration

The code is hosted on the `GitHub` repository [Cake build][cake-build]. It's named [Cake][cake] after my favourite build automation system and the project is using `Cake` as its build system.

`AppVeyor`, `Azure DevOps` and `CircleCI` all use [YAML][yaml] configuration files. This means that your build steps are living in the same space than your code and this presents several benefits:

- Any developer can modify the build
- The project is self-contained
  - Developers don't have to search where the build is located
  - It doesn't matter if something terrible happens to the build server
- Ability to run the build locally on some platforms

I'm sure you'll be as surprised as I was when I realised how simple the `YAML` files are:

- `AppVeyor`: [appveyor.yml][app-veyor-config]
- `Azure DevOps`: [azure-pipelines.yml][azure-devops-config]
- `CircleCI`: [.circleci/config.yml][circle-ci-config]

## The code

The project is useless. What is important is that it describes a real-life scenario:

- The solution contains two projects which will be packed as `NuGet` packages
  - The `Logic` project references a `NuGet` package from [nuget.org][nuget-org] via a `PackageReference`, `dotnet pack` will turn this into a package reference.
  - The `SuperLogic` project depends on `Logic` and when packing, this project reference will be turned into a `NuGet` package reference (handled out of the box by `dotnet pack`)
- The projects target both `nestandard2.0` and `net461` so they can also be used with the `.NET Framework` (`net461` and above)
  - The resulting `NuGet` packages should contain `DLL`s for both frameworks
- The projects reference a third project that should be embedded as a `DLL` rather than being referenced as a `NuGet` package
  - This is not yet supported by the new tooling but can be [achieved](#create-nuget-packages).

## Pinning `Cake` version

Pinning the version of `Cake` guarantees you'll be using the same version of `Cake` on your machine and on the build servers. This is achieved by installing Cake as a [.NET local tool][dotnet-local-tool].

## Semantic versioning

As I'm releasing packages I decided to use [semantic versioning][sem-ver].

> Consider a version format of `X.Y.Z` (`Major.Minor.Patch`). Bug fixes not affecting the API increment the **patch** version, backwards compatible API additions/changes increment the **minor** version, and backwards incompatible API changes increment the **major** version.

Semantic versioning allows the consumers of your binaries to assess the effort to upgrade to a newer version. Semantic versioning should not be used blindly for all kinds of projects. It makes a lot of sense for a `NuGet` package but it doesn't for a product or an `API` for example.

### Versioning in `.NET`

In `.NET` we use four properties to handle versioning:

- `AssemblyVersion`, `AssemblyFileVersion` and `AssemblyInformationalVersion` to version assemblies
- `PackageVersion` to version a `NuGet` package

#### Versioning an assembly

[These][dll-versions-1] [two][dll-versions-2] `StackOverflow` answers are great at explaining how to version an assembly.

- `AssemblyVersion`: the only version the `CLR` cares about (if you use [strong named assemblies][strong-named-assemblies])

Curiously enough the [official documentation][assembly-version] is sparse on the [topic][16-bit-build-number] but this what I came up with after doing some reading:

> `AssemblyVersion` can be defined as `<major-version>.<minor-version>.<build-number>.<revision>` where each of the four segment is a `16-bit` unsigned number.

- `AssemblyInformationalVersion`: `string` that attaches additional version information to an assembly for informational purposes only. Corresponds to the product's marketing literature, packaging, or product name

`AssemblyInformationalVersion` is well [documented][assembly-informational-version].

- `AssemblyFileVersion`: intended to uniquely identify a build of the individual assembly

Developers tend to auto-increment this on each build. I prefer it linked to a `commit` / `tag` to be able to reproduce a build. I also use the same `string` for `AssemblyInformationalVersion` and `AssemblyFileVersion` (I'm a bad person I know).

#### Versioning a `NuGet` package

- `PackageVersion`: A specific package is always referred to using its package identifier and an exact version number

`NuGet` package versioning is described [here][nuget-package-versioning].

### `GitVersion`

I've implemented semantic versioning using [GitVersion][git-version]. I recommend using [GitHub Flow][github-flow] when working on a simple package. In my experience [Trunk Based Development][trunk-based-development] tends to lead to lower code quality. Developers push early and often thinking they will fix it later but we all know than in software development later means never.

`GitVersion` produces an output that will allow you to handle even the trickiest situations:

{% highlight json %}
{
  "Major":0,
  "Minor":2,
  "Patch":3,
  "PreReleaseTag":"region-endpoint.2",
  "PreReleaseTagWithDash":"-region-endpoint.2",
  "PreReleaseLabel":"region-endpoint",
  "PreReleaseNumber":2,
  "BuildMetaData":"",
  "BuildMetaDataPadded":"",
  "FullBuildMetaData":"Branch.features/region-endpoint.Sha.1f05a4bb4ebda8b293fbd139063ce3af22b1935a",
  "MajorMinorPatch":"0.2.3",
  "SemVer":"0.2.3-region-endpoint.2",
  "LegacySemVer":"0.2.3-region-endpoint2",
  "LegacySemVerPadded":"0.2.3-region-endpoint0002",
  "AssemblySemVer":"0.2.3.0",
  "FullSemVer":"0.2.3-region-endpoint.2",
  "InformationalVersion":"0.2.3-region-endpoint.2+Branch.features/region-endpoint.Sha.1f05a4bb4ebda8b293fbd139063ce3af22b1935a",
  "BranchName":"features/region-endpoint",
  "Sha":"1f05a4bb4ebda8b293fbd139063ce3af22b1935a",
  "NuGetVersionV2":"0.2.3-region-endpoint0002",
  "NuGetVersion":"0.2.3-region-endpoint0002",
  "CommitsSinceVersionSource":2,
  "CommitsSinceVersionSourcePadded":"0002",
  "CommitDate":"2018-01-31"
}
{% endhighlight %}

In my case I'm using:

- `AssemblySemVer` as the `AssemblyVersion`
- `NuGetVersion` as the `AssemblyInformationalVersion`, `AssemblyFileVersion` and `PackageVersion`

If you want to handle rebasing and `Pull Request`s you'll have to use a more complex versioning strategy (keep in mind that `GitHub` advises against [force-push][github-pr-no-force-push] in `Pull Request`s).

As an aside `Cake` allows you to [set][cake-app-veyor-build] the `AppVeyor` build number.

![AppVeyor version]({{ "/assets/cake-build/app-veyor-version.png" | prepend: site.baseurl }})

## Run the tests

As the `CircleCI` build is running on `Linux` it doesn't support testing against `net461`. Luckily the framework can be specified using an argument: `--framework net6.0`.

## Publish the test results

### CircleCI

`CircleCI` has a few quirks when it comes to testing.

First it only supports the [JUnit format][junit-format] so I had to use the [JunitXml.TestLogger][junit-xml-test-logger] `NuGet` package to be able to publish the test results. Then you must [place your test results within a folder named after the test framework][circle-ci-test-results] you are using if you want `CircleCI` to identify your test framework.

When the tests run successfully `CirceCI` will only display the slowest test (you need to navigate to _Test Insights_ to see it):

![Circle CI slowest test]({{ "/assets/cake-build/circle-ci-test-insights-slowest-test.png" | prepend: site.baseurl }})

I don't understand the use case, I would prefer the list of tests and timing and the ability to sort them client-side.

The output for failed tests is much better when using a `JUnit` logger instead of trying to convert the test results:

![Circle CI failed test]({{ "/assets/cake-build/circle-ci-junit-failed-test.png" | prepend: site.baseurl }})

### AppVeyor

Again, the integration between `Cake` and `AppVeyor` shines in this area as `Cake` will automatically publish the test results for you (I wondered why I had duplicate test results until I [RTFM][rtfm]).

`AppVeyor` displays all the tests but you must hover to see the framework used:

![AppVeyor framework]({{ "/assets/cake-build/app-veyor-test-success.png" | prepend: site.baseurl }})

Failed tests come with a nice formatting and a `StackTrace`:

![AppVeyor failed test]({{ "/assets/cake-build/app-veyor-failed-test.png" | prepend: site.baseurl }})

## Create `NuGet` packages

`.NET` is now leveraging the "new" `*.csproj` system and this means:

- No more `packages.config`
- No more `*.nuspec`
- No more tears

The references (projects and packages) and the package configuration are both contained in the `*.csproj` making it the single source of truth!

### Referencing a project without turning it into a package reference

Sometimes you want to include a `DLL` in a `NuGet` package rather than add it as a package reference.

The `SuperLogic` project depends on the `ExtraLogic` project but we don't want to ship `ExtraLogic` as a package. Instead we want to include `Contoso.Hello.ExtraLogic.dll` in the `SuperLogic` package directly. Currently this is not supported out of the box but the team is [tracking it][pack-issues].

Luckily [this issue][project-reference-dll-issue] provides a workaround. All the modifications will take place in `SuperLogic.csproj`.

- In the `<PropertyGroup>` section add the following line:

{% highlight xml %}
<TargetsForTfmSpecificBuildOutput>$(TargetsForTfmSpecificBuildOutput);IncludeReferencedProjectInPackage</TargetsForTfmSpecificBuildOutput>
{% endhighlight %}

- Prevent the project to be added as a package reference by making [all assets private][private-assets].

{% highlight xml %}
<ProjectReference Include="..\ExtraLogic\ExtraLogic.csproj">
  <PrivateAssets>all</PrivateAssets>
</ProjectReference>
{% endhighlight %}

- Finally add the target responsible of copying the `DLL`:

{% highlight xml %}
<Target Name="IncludeReferencedProjectInPackage">
  <ItemGroup>
    <BuildOutputInPackage Include="$(OutputPath)Contoso.Hello.ExtraLogic.dll" />
  </ItemGroup>
</Target>
{% endhighlight %}

The result is the following `NuGet` package:

![Package version]({{ "/assets/cake-build/package-version.png" | prepend: site.baseurl }})

And the assemblies have been versioned as expected:

{% highlight csharp %}
[assembly: AssemblyFileVersion("1.0.5-fix-typos0003")]
[assembly: AssemblyInformationalVersion("1.0.5-fix-typos0003")]
[assembly: AssemblyVersion("1.0.5.0")]
{% endhighlight %}

**Note**: you can also use the "new" `*.csproj` system for `NuGet` packages targeting older `.NET Framework` versions.

## Publish the `NuGet` packages

On any branches starting with `features/`, the `NuGet` packages will be published to a pre-release feed. If the branch is `main` it'll be published to the production feed. This is handled by `AppVeyor` in this [section][publish-packages] of the configuration.

As this is a demo project both feeds are hosted by `MyGet`. For my other projects I use `MyGet` to host my [pre-release feed][myget-feed] and `NuGet` for my [production feed][nuget-feed].

When publishing the packages, I'm also publishing the associated [symbols][symbols] to allow consumers to debug through my packages.

## Create a GitHub release

`AppVeyor` also creates `GitHub` [releases][appveyor-create-github-release].

## What about Azure DevOps

`Azure DevOps` has the most powerful tests results tab:

![Azure DevOps Tests]({{ "/assets/cake-build/azure-devops-tests.png" | prepend: site.baseurl }})

One thing I've noticed is that builds seem to be slower on the `Hosted Ubuntu 1604` agents than on the `Hosted VS2017` agents.

## Conclusion

This is one possible workflow only. I've glossed over many details and taken some shortcuts (for example there is no support for Pull Request builds).

Those are the key takeaways:

- Do **upfront planning on how you want to handle versioning**. This is the hardest part and the one that will be the hardest to fix later on. Read the [GitVersion documentation][git-version-docs] carefully before making any decision.
- Do what works for your team. If you didn't have any issues with auto-incrementing your builds, keep doing so. There is no point bringing additional complexity to fix a problem you don't have.
- Don't assume you'll be running on `Windows` with `Visual Studio Enterprise` installed. Adding cross-platform or other `IDE` (`Rider`, `Code`...) support from the start will make your life easier down the track.

[sem-ver]: https://semver.org/
[azure-devops]: https://azure.microsoft.com/en-au/services/devops/
[app-veyor]: https://www.appveyor.com/
[circle-ci]: https://circleci.com/
[cake-build]: https://github.com/gabrielweyer/cake-build
[cake]: https://cakebuild.net/
[yaml]: https://yaml.org/
[app-veyor-config]: https://github.com/gabrielweyer/cake-build/blob/main/appveyor.yml
[circle-ci-config]: https://github.com/gabrielweyer/cake-build/blob/main/.circleci/config.yml
[nuget-org]: https://www.nuget.org/
[git-version]: https://github.com/GitTools/GitVersion
[github-flow]: https://docs.github.com/en/get-started/quickstart/github-flow
[trunk-based-development]: https://trunkbaseddevelopment.com/
[nuget-package-versioning]: https://docs.microsoft.com/en-us/nuget/reference/package-versioning
[dll-versions-1]: https://stackoverflow.com/a/65062
[dll-versions-2]: https://stackoverflow.com/a/802038
[assembly-version]: https://docs.microsoft.com/en-us/dotnet/framework/app-domains/assembly-versioning#assembly-version-number
[16-bit-build-number]: https://blogs.msdn.microsoft.com/msbuild/2007/01/03/why-are-build-numbers-limited-to-65535/
[strong-named-assemblies]: https://docs.microsoft.com/en-us/dotnet/framework/app-domains/strong-named-assemblies
[assembly-informational-version]: https://docs.microsoft.com/en-us/dotnet/framework/app-domains/assembly-versioning#assembly-informational-version
[github-pr-no-force-push]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests
[cake-app-veyor-build]: https://cakebuild.net/api/Cake.AppVeyor/AppVeyorBuild/069D8D3F
[junit-format]: https://llg.cubic.org/docs/junit/
[junit-xml-test-logger]: https://www.nuget.org/packages/JUnitXml.TestLogger/
[circle-ci-test-results]: https://circleci.com/docs/2.0/configuration-reference/#storetestresults
[pack-issues]: https://github.com/NuGet/Home/issues/6285
[project-reference-dll-issue]: https://github.com/NuGet/Home/issues/3891
[private-assets]: https://docs.microsoft.com/en-us/dotnet/core/tools/csproj#includeassets-excludeassets-and-privateassets
[publish-packages]: https://github.com/gabrielweyer/cake-build/blob/d7daca61a5add242ba2d6af655e0272251da13f2/appveyor.yml#L44-L65
[nuget-feed]: https://www.nuget.org/profiles/gabrielweyer
[myget-feed]: https://www.myget.org/feed/Packages/gabrielweyer-pre-release
[symbols]: https://docs.microsoft.com/en-us/nuget/create-packages/symbol-packages-snupkg
[appveyor-create-github-release]: https://github.com/gabrielweyer/cake-build/blob/d7daca61a5add242ba2d6af655e0272251da13f2/appveyor.yml#L20-L43
[git-version-docs]: https://gitversion.net/docs/
[azure-devops-config]: https://github.com/gabrielweyer/cake-build/blob/main/azure-pipelines.yml
[rtfm]: https://en.wikipedia.org/wiki/RTFM
[travis-ci-exposed-secrets]: https://www.theregister.com/2021/09/15/travis_ci_leak/
[dotnet-local-tool]: https://docs.microsoft.com/en-us/dotnet/core/tools/local-tools-how-to-use
[change-in-azure-pipelines-grant-for-public-projects]: https://devblogs.microsoft.com/devops/change-in-azure-pipelines-grant-for-public-projects/

[trigger-build-commit]: {% post_url 2018-04-22-cake-build %}#configuration
[use-semantic-versioning]: {% post_url 2018-04-22-cake-build %}#semantic-versioning
[run-tests]: {% post_url 2018-04-22-cake-build %}#run-the-tests
[publish-test-results]: {% post_url 2018-04-22-cake-build %}#publish-the-test-results
[create-nuget-packages]: {% post_url 2018-04-22-cake-build %}#create-nuget-packages
[publish-nuget-packages]: {% post_url 2018-04-22-cake-build %}#publish-the-nuget-packages
[create-github-release]: {% post_url 2018-04-22-cake-build %}#create-a-github-release
