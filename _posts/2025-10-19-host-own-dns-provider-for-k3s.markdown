---
layout: post
title:  "Host own DNS provider for K3S"
date:   2025-10-19 12:25:40 +0800
categories: K3S
---
With a lot more resources being used, for personal dev host, K3S is a better tool to manage various functions and resources, than Docker/Compose. But one thing is a bit troublesome.

Many tools are WebUI tools. Generally, in an formal K8S cluster, they would be exposed via Ingress, sub-path or different hosts. Sub-path is quite hard to configure and not possible for some WebUIs. While different hosts requires a DNS solver, and manually managing those records in a general home router would be a disaster as well.

Only if there is something like those cloud DNS providers that work with ExternalDNS.

Here is [E_D] comes to rescue. **E_D** is a tool to connect ExternalDNS and DnsMasq. With the tool, and ExternalDNS deployed in K3S, all services / ingresses could have their own address just an annotation away, like they are in EKS/AKS.

[ExternalDns-webhook](https://github.com/Magicloud/externaldns-webhook) project is the ExternalDns out-tree DNS service provider interface in Rust. And its example **E_D** is an implementation for DnsMasq. Thus with some certain setup to connect E_D with the **DnsMasq** of my LAN name server, all K3S exposed host names are solvable within my LAN.

To use E_D with ExternalDns, a few values are needed when installing ExternalDns Helm Chart.

The key part is `provider`.

```yaml
provider:
  name: dnsmasq
  webhook:
    imagePullPolicy: Always
    image:
      repository: ghcr.io/magicloud/e_d
      tag: "latest"
    args:
    - --domain-name
    - magicloud.lan
    - --conf-filename
    - /etc/dnsmasq.d/external.conf
    env:
    - name: RUST_LOG
      value: debug
    extraVolumeMounts:
    - name: conf
      mountPath: /etc/dnsmasq.d/
```

This would create a second container in ExternalDns pod. And ExternalDns would know to contact with it about name changes.

This part also claims that we need a volume for E_D. This is specified in another section.

```yaml
extraVolumes:
- name: conf
  hostPath:
    path: /mnt/data/conf/dnsmasq/
```

Another part worth noting is `policy`. Following is its doc, and I set it to `sync`.

```yaml
# -- How DNS records are synchronized between sources and providers; available values are `create-only`, `sync`, & `upsert-only`.
policy: upsert-only  # @schema enum:[create-only, sync, upsert-only]; type:string; default: "upsert-only"
```

After all these, names in K3S managed via annotation `external-dns.alpha.kubernetes.io/hostname` will be ended up as a DnsMasq conf file in `conf` volume.

To use the conf file, I have a customized DnsMasq image that watches the file and restart DnsMasq when it changed. Yes, sadly DnsMasq does not support hot reloading. The image sit in *examples/e_d/dnsmasq*.

Now everything is running. Pointing desktop DNS solver to exposed DnsMasq host#port, try the ExternalDNS annotations as usual and see the records appear in DnsMasq conf file and work.
