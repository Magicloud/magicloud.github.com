---
layout: post
title:  "Prevent K3S CoreDNS outage"
date:   2026-06-30 17:40:08 +0800
categories: K3S
---
I have a name solving chain to have different names using different upstreams. And the chain is running inside K3S. Sometimes it stops working and break everything.

The reason is when K3S rolling-updates coreDNS, due to its not-HA setup, the service is stopped before pulling the new image. Due to the solving chain uses coreDNS to find next service in the cluster, it fails to solve the image URL. Hence whole thing gets stuck.

Fixing is easy. Update **/var/lib/rancher/k3s/server/manifests/coredns.yaml**, with something like:
```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
```
