---
date: 2014-01-07 09:13:53+00:00
layout: post
title: Splunk
categories:
- Logging
tags:
- Logging
- Serilog
- Structured Logging
- Splunk
---

One of my customer is using [Splunk][splunk] which is a log management system. I've hard of Splunk before but never used it. This specific Splunk installation suffered from two issues:

- Most of the systems (APIs, workers...) were not logging to it even though they were supposed to.
- The application logging emits structured events thanks to the excellent [Serilog][serilog] logging library but we ended up ingesting plain text in Splunk.

To add some more complexity the Splunk instance was not publicly accessible, hence we relied on a convoluted process:

- Applications logged to the `Trace` sink
- [Azure Diagnostics][azure-diagnostics] writes the traces to blobs
- Splunk polls the container looking for blobs using the [Splunk Add-on for Microsoft Cloud Services][azure-add-on]

After discovering those issues I set myself the mission to fix the logging.

# Running Splunk locally

You'll often get limited access to production systems, this is why I recommend running Splunk locally.

You can run [Splunk Enterprise for free][splunk-enterprise-free] on your development machine. If you prefer you can use a [Docker image][splunk-docker] instead, it comes with a [manual][splunk-docker-manual].

Once installed you can browse Splunk at [http://localhost:8000/](http://localhost:8000/). At first the experience is a bit underwhelming but don't worry we'll soon unleash the power of Splunk.

# Source Types

# Fields

# Splunk Add-on for Microsoft Cloud Services

Our Splunk instance is integrating to Azure via the [Splunk Add-on for Microsoft Cloud Services][azure-add-on]. Another alternative seems to be the [Azure log integration][azure-log-integration].

## Install the add-on

You can install the add-on on your local instance to:

[![Find more apps]({{ "/assets/splunk/find-more-apps.png" | prepend: site.baseurl }})]({{ "/assets/splunk/find-more-apps.png" | prepend: site.baseurl }})

[![Install add-on]({{ "/assets/splunk/install-add-on.png" | prepend: site.baseurl }})]({{ "/assets/splunk/install-add-on.png" | prepend: site.baseurl }})

## Configure the storage account

[![Configure storage account]({{ "/assets/splunk/configure-storage-account.png" | prepend: site.baseurl }})]({{ "/assets/splunk/configure-storage-account.png" | prepend: site.baseurl }})

[![Add storage account]({{ "/assets/splunk/add-storage-account.png" | prepend: site.baseurl }})]({{ "/assets/splunk/add-storage-account.png" | prepend: site.baseurl }})

## Add an input

[splunk]: https://www.splunk.com/
[serilog]: https://serilog.net/
[splunk-enterprise-free]: https://www.splunk.com/en_us/download/splunk-enterprise.html
[splunk-docker]: https://store.docker.com/images/splunk-enterprise-free-for-docker?tab=description
[splunk-docker-manual]: https://hub.docker.com/r/splunk/splunk/
[azure-diagnostics]: https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/azure-diagnostics
[azure-add-on]: https://splunkbase.splunk.com/app/3110/
[azure-log-integration]: https://docs.microsoft.com/en-us/azure/security/security-azure-log-integration-overview
