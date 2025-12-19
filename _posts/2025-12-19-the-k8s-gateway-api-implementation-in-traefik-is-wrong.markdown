---
layout: post
title:  "The K8S Gateway API implementation in Traefik is wrong"
date:   2025-12-19 15:20:17 +0800
categories: Gateway Traefik
---
Recently I am playing with Ingress and Gateway, to make my tool to restrict exposing content via HTTP.

Since my dev server is K3S, which comes with Traefik. I read its [doc](https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/gateway-api/), which was quite surprising.

From K8S [doc](https://kubernetes.io/docs/concepts/services-networking/gateway/), when I create a Gateway, I am basically telling whatever underneath how I want to expose my service. The protocol, the port, the TLS, etc. "I" am controlling over all those setups.

Hence with Nginx [implementation](https://github.com/nginx/nginx-gateway-fabric), I can specify almost "any" port I'd like for listeners. Then it creates corresponding service to expose Nginx on those ports.

Fully expected, following my understanding of K8S doc.

Well, with Traefik, it is not. Apparently Traefik implementation is just a knockoff of how Ingress works. The ports of listeners can only be the ones specified (along with protocols) in Traefik configuration. And because Pod and Service may listen on different ports, the ports in Gateway may not be the ones end users actually get the service.

More ugly, the ports configuration is not "exposed" in any simple, safe way. One making Gateway has no other ways to write it properly unless asking sys admin what is the values. Giving the ports may be varies among clusters, the Gateway may not be versatile, which seems like a cruel joke to "Gateway is more flexible", and all those charts/kustomizations/manifests online.

Traefik implementation for Gateway has been there for years, I cannot believe they have not realized this.
