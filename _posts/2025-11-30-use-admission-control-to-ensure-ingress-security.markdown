---
layout: post
title:  "Use Admission Control to ensure Ingress security"
date:   2025-11-30 16:02:17 +0800
categories: K8S
---
Using K8S, one got to setup a lot of Ingresses. Some are directly configured by me, some are from existing manifests, some are indirectly from Helm charts. And needless to say, every Ingress should be protected by TLS.

The problem is that, as there are so many ways to got an Ingress in the cluster, the way to setup TLS veries as well. Especially when the manifests are from outside, one has to keep them syncing on the change he made.

So even though my K3S cluster is only accessible from LAN, I still decided to make myself a solution. Also because some tools hard require an HTTPS endpoint.

The first thing came across my mind, is K8S Admission Control webhook. With this facility, I can get all Ingress manifests come through my webhook before they are created or updated. And in the webhook, I can simply deny Ingresses without TLS configuration, or, better suits my need, add necessary TLS setup.

So first of all, code the webhook program. With all K8S data types (directly and indirectly) defined in [kube](https://docs.rs/kube), the work is just take a POSTed `AdmissionReview`, turn into `AdmissionRequest`, extract the `DynamicObject`, **manually** convert to `Ingress` (why there is not a `From`). Then check if it contains `spec.tls`. This is the process of validating.

Further more, if it does not, return a JSON patch adding the TLS info, and (in my case) annotations for Cert Manager.

The returned data is `AdmissionResponse`, and in mutating case, it does not take a new Ingress, but just a patch.

One thing to note, AdmissionControl webhook is required to be TLS securied. And the webhook is used within the cluster (directly via service). Hence I cannot use Ingress + TLS to fulfill the requirement. Since I have Step CA and Cert Manager running in my cluster, I need a way to automatically get cert from Cert Manager and install it to the webhook Pod.

This is where [CSI-driver](https://cert-manager.io/docs/usage/csi-driver) comes to help. After installation, a few things worth noting. The webhook is accessed not by FQDN, so `csi.cert-manager.io/dns-names` should at least include `NAME.NAMESPACE.svc`. By default, Step cert expires in 24 hours, but CSI-driver uses a very long default value. Set `csi.cert-manager.io/duration` accordingly. And csi volume is mounted as root, and user/group read only. If the program is not running as root, Pod `spec.template.spec.volumes.csi.volumeAttributes.csi.cert-manager.io/fs-group` should be set properly.

Then setup the Admission Control. This is where it gets annoying.

First, there are two kinds I could use, `ValidatingWebhookConfiguration` or `MutatingWebhookConfiguration`. If both exist matching the same resource, validate would be run after mutate. But I could not find docs on order of mutiple validatings or mutatings match the same resource. For my case, `MutatingWebhookConfiguration` is enough.

Next thing to note is `webhooks.rules`, to match the resources I want to mutate. I need `CREATE` and `UPDATE` on `networking.k8s.io/v1/ingresses` `Clustered`-wise. Yes, it must be `ingresses`, singlur does not work. And `webhooks.rules.scope` must in the form of `-ed`. English sucks!

Then `webhooks.clientConfig`. This is the part specifying the info of the webhook. `webhooks.clientConfig.caBundle`, in this case, is the Step CA. According to K8S doc, if I omit the field, the verifying would be done against system CA, where apiserver resides. So I did `security.pki.certificates = ["${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" "/etc/ssl/certs/step.crt"];` to install the CA to my NixOS. It seemed working. I could not `nerdctl push` to my private registry (protected by Step CA) and I can now. But K3S still could not verify the webhook. Also is its kubelet that cannot pull from my private registry. Rancher have not give me a hint yet. So I manually put Step CA cert in the field.

After all those, apply a minimal Ingress, and get it to see all the changes the webhook made.
