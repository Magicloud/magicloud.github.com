---
layout: post
title:  "Host own DNS provider for K3S"
date:   2025-10-19 12:25:40 +0800
categories: K3S
---
With a lot more resources being used, for personal dev host, K3S is a better tool to manage various functions and resources, than Docker/Compose. But one thing is a bit troublesome.

Many tools are WebUI tools. Generally, in an formal K8S cluster, they would be exposed via Ingress, sub-path or different hosts. Sub-path is quite hard to configure and not possible for some WebUIs. While different hosts requires a DNS solver, and manually managing those records in a general home router would be a disaster as well.

Only if there is something like those cloud DNS providers that work with ExternalDNS.

Here is [E_D](https://github.com/Magicloud/externaldns-webhook) comes to rescue. **E_D** is a tool to connect ExternalDNS and DnsMasq. With the tool, and ExternalDNS deployed in K3S, all services / ingresses could have their own address just an annotation away, like they are in EKS/AKS.

Clone the repo, build the E_D image with `e_d.Dockerfile`. Update `examples/e_d/dnsmasq/dnsmasq.conf`/`examples/e_d/dnsmasq/dnsmasq.yaml`/`examples/e_d/helm-value.yaml` on local domain name, upstream DNS server and hostPath of the share mount. Build DnsMasq image with `examples/e_d/dnsmasq/Containerfile`, install DnsMasq image with `examples/e_d/dnsmasq/dnsmasq.yaml`. Install ExternalDNS chart with `examples/e_d/helm-value.yaml`. Here E_D and DnsMasq communicates via the conf file in the shared mount. It does not have to be persisted.

Now everything is running. Pointing desktop DNS solver to exposed DnsMasq host#port, try the ExternalDNS annotations as usual and see the records appear in DnsMasq conf file and work.
