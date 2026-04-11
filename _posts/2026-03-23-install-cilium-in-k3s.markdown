---
layout: post
title:  "Install Cilium in existing K3S"
date:   2026-03-23 20:35:40 +0800
categories: K3S Cilium
---
All started when I wanted to detect pods that connects to out-cluster address unexpectedly. And Cilium is a powerful CNI that could give me such data. Also I am using single-node K3S, I could have Cilium replace KubeProxy, Ingress controller (Traefik), Loadbalancer (Klipper).

First, install Cilium CLI. The installation of Cilium CNI could be done via the CLI or Helm. But CLI also gives some management functions.

Then, one thing to consider is how does the loadbalancer work. Cilium supports 2 ways to expose the loadbalancer type of services.

1. L2 announcements. In this way, along with `CiliumLoadBalancerIPPool` resources, Cilium would assign an IP from the pool to a service and announce the IP to the node host network. Multiple services could use sharing key to use the same IP.

2. Node IPAM only. In this way, the services are directly working on the node IPs.

Those works for general loadbalancer type of services. But for Cilium ingress, it is directly handled in eBPF, and something is different.

1. With L2 announcements, Ingress works in both shared or dedicated mode.

2. With node IPAM only, the Ingress practically cannot be dedicated since there would be equal numbers of loadbalancer type of services that listens on port 80 and 443. When the number is more than the count of nodes, there would be conflict. Shared mode, on the other hand, worked in my clean testing VM, but not the real node. I found [issue](https://github.com/cilium/cilium/issues/44187) seems to be similar.

3. hostNetwork mode. This directly expose the ingress service on node host. Similar with node IPAM only, but since there is not a corresponding service behind the ingress resource, tools like ExternalDNS could not get what IP should the hostname mapping to. Some extra configuations are needed.

Now goes the actual installation.

Adding following commands to K3S service configuration then rebuild NixOS.

```
"--flannel-backend none"
"--disable-network-policy"
"--disable-kube-proxy"
"--disable servicelb"
"--disable traefik"
```

After restarting K3S, the node may or may not be NotReady, and pods may be Running or Unknown.

Run Cilium install command.

```
cilium install \
  # In case Cilium CLI is not the latest version.
  --version=1.19.2 \
  # Just to save the operation restarting Cilium on every change.
  --set=operator.rollOutPods=true \
  --set=rollOutCiliumPods=true \
  # It may wrongly choose wrong device like flannel.1 or such. `kvm0` is the main bridge device on my host.
  --set=devices=kvm0 \
  # I was using Flannel comes with K3S, hence I set those paths in Containerd. This should follows.
  --set=cni.confPath=/var/lib/rancher/k3s/agent/etc/cni/net.d \
  --set=cni.binPath=/var/lib/rancher/k3s/data/cni \
  # Replacing KubeProxy.
  --set=kubeProxyReplacement=true \
  # Cilium runs as DaemonSet, hence it access the K3S API endpoint from outside of the cluster.
  --set=k8sServiceHost=localhost \
  --set=k8sServicePort=6444 \
  # Using Cilium Ingress
  --set=ingressController.enabled=true \
  --set=ingressController.default=true \
  --set=ingressController.loadbalancerMode=shared \
  # Not mentioned in doc, but without this, egress does not work.
  --set=bpf.masquerade=true \
  # Enable to expose services on node host
  --set=nodeIPAM.enabled=true \
  --set=defaultLBServiceIPAM=lbipam
  --set=l2announcements.enabled=true
```

3 new pods in `kube-system` namespace with "cilium" in their names should appear and progress to running.

Sometimes things would work after restarting K3S or even the OS.

In my case, there is one more requirement.

I have a DNSMasq running in K3S, now with L2 announcements, the service is on a "random" IP, which is hard to use. Set `spec.loadBalancerClass` to "io.cilium/node" to have the service loadbalancer on node IPAM mode, which means the service is exposed on the node IP, just like it used to be.
