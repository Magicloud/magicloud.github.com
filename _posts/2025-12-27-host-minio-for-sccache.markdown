---
layout: post
title:  "Host Minio for Sccache"
date:   2025-12-27 13:48:37 +0800
categories:
---
They say using [Sccache](https://github.com/mozilla/sccache) speeds up Rust project building. The tool caches compiling results, surely makes the building next time faster. Although the slowest step, linking, does not benefit from this.

While the tool is server-client style, it does not support starts the server once, running the clients every where. Giving sometimes I build in dev host, sometimes I build in containers, further usage of the tool, storage backend, is in order.

Sccache supports a few storage backends, to me, fake S3, AKA Minio, seems alright. Sccache supports both virtual host and sub path style of Minio bucket accessing. But with sub path, when some configurations are wrong, Sccache won't complaint but won't cache, either. So I chose virtual host style.

## Minio

First of all, setup Minio. I followed its [Github Readme](https://github.com/minio/operator/) to install the operator. Its website, seems messed up due to financial crisis.

Then generate a basic Minio setup by `kubectl kustomize github.com/minio/operator/examples/kustomization/base`. I modified a few things.

- Rewrite all `Secret`s to `SealedSecret`s, obviously.

- `metadata` of `Tenant` object, like names, labels, etc.

- `spec.env` of `Tenant` object.

    Set `MINIO_DOMAIN` to Minio URL about to be used. Per doc, this should be set, but seems not necessary.

- `spec.pools` of `Tenant` object.

    Since this will be run on K3S with single node, I cleared the `affinity` part, and set `servers` to 1. The `volumesPerServer` must be no less than 4.

- A `Ingress`

    My Minio tenant name is `any`. TLS is not necessary. Hostname about `*.minio.magicloud.lan` is not necessary as well, at least with DNSMasq nameserver.

    The first rule is for console WebUI. The second rule is for virtual host bucket accessing. The third rule is for API endpoint.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minio-any-console
  namespace: minio-tenant
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "minio.magicloud.lan,minio-console.magicloud.lan.minio.magicloud.lan"
    cert-manager.io/issuer: step-issuer
    cert-manager.io/issuer-kind: StepClusterIssuer
    cert-manager.io/issuer-group: certmanager.step.sm
spec:
  tls:
    - secretName: minio-tls
      hosts:
        - minio.magicloud.lan
        - minio-console.magicloud.lan
        - "*.minio.magicloud.lan"
  rules:
    - host: minio-console.magicloud.lan
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: any-console
                port:
                  number: 9090
    - host: "*.minio.magicloud.lan"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: any-hl
                port:
                  number: 9000
    - host: "minio.magicloud.lan"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: any-hl
                port:
                  number: 9000
```

With Minio ready, run following Terraform code to create a bucket named `sccache`, a user named `sccache`, with password `sccache123`, and grant full-access to the bucket. Remember to replace minio/minio123 with the credential from the `Secret` when setup the tenant.

```hcl
terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
      version = "3.12.0"
    }
  }
}

provider "minio" {
  minio_server   = "minio.magicloud.lan:443"
  minio_user     = "minio"
  minio_password = "minio123"
  minio_ssl      = true
}

resource "minio_iam_user" "sccache" {
   name = "sccache"
   secret = "sccache123"
}

resource "minio_s3_bucket" "sccache" {
    bucket = "sccache"
}

resource "minio_iam_policy" "read-write-sccache" {
  name = "read-write-sccache"
  policy = data.minio_iam_policy_document.sccache.json
}

resource "minio_iam_user_policy_attachment" "sccache" {
  user_name   = minio_iam_user.sccache.id
  policy_name = minio_iam_policy.read-write-sccache.id
}

data "minio_iam_policy_document" "sccache" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::sccache",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::sccache/*",
    ]
  }
}
```

## Sccache

There are always some DNS issues with Musl, hence the static linked Sccache, which led to a few DNS/hostname setup above that I am not sure is necessary.

And to make this actually work, Sccache **must** be build to GNU target.

Then export following environments, and Sccache is ready to run. Confirm it by seeing data appears in the bucket, and no more data appears in local (`~/.cache/sccache/` by default).

```bash
SCCACHE_BUCKET="sccache"
SCCACHE_REGION="auto"
SCCACHE_ENDPOINT="minio.magicloud.lan:443"
SCCACHE_S3_ENABLE_VIRTUAL_HOST_STYLE="true"
SCCACHE_S3_USE_SSL="true"
SCCACHE_S3_SERVER_SIDE_ENCRYPTION="false"
AWS_ACCESS_KEY_ID="sccache"
AWS_SECRET_ACCESS_KEY="sccache123"
```

## PS

This is generally how it was done. And of course, one may want to use Vault or similiar tools to completely hide the passwords passing around here.