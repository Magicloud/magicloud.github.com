---
layout: post
title:  "Host own CA for K3S"
date:   2025-10-21 22:51:05 +0800
categories: K3S
---
My K3S is not exposed to the Internet. Therefore, I never felt the necesity to use HTTPS for all WebUIs. Also because it is hard to use Let's Encrypt in this case.

However, when I setup Nextcloud to backup my desktop, the client required the transmission to be TLS encrypted. This led to this article, hosting an own CA.

I do not know if there are other options, I use **Step CA** from *smallstep.com*.

1. Install **step-ca**/**step**.

    1. Generate step-ca helm values.

        `step ca init --helm`

        Be careful with those questions. Some are tied to other configurations that are not here or changeable.

        ```text
        ✔ Deployment Type: Standalone
        
        What would you like to name your new PKI?
        ✔ (e.g. Smallstep): Smallstep
        
        What DNS names or IP addresses would you like to add to your new CA?
        # This is the only available value in K8S setup, except the namespace part.
        ✔ (e.g. ca.smallstep.com[,1.1.1.1,etc.]): step-certificates.default.svc.cluster.local
        
        What IP and port will your new CA bind to (it should match service.targetPort)?
        # The service is on 9000 by default. Change the value here does not affect the service.
        ✔ (e.g. :443 or 127.0.0.1:443): :9000
        
        What would you like to name the CA's first provisioner?
        # Unlike said in doc, a pre-configured "admin" provisioner, this is the only one in helm installation.
        ✔ (e.g. you@smallstep.com): me@example.org
        
        Choose a password for your CA keys and first provisioner.
        # If chose "generate", the password is shown until press Enter. Copy it and base64 it for used later.
        ✔ [leave empty and we'll generate one]:
        ```

    2. Install step-ca

    `helm upgrade -i step-certificates smallstep/step-certificates -f step-ca-values.yaml --set inject.secrets.ca_password="${BASE64_PASSWORD_FROM_ABOVE}" --set inject.secrets.provisioner_password="${BASE64_PASSWORD_FROM_ABOVE}"/`

2. Install **step-issuer**.

    1. `helm install step-issuer smallstep/step-issuer`

    2. Setup the issuer.

    ```Shell
    #!/usr/bin/env bash
    set -eu -o pipefail
    
    # Same as the one in answer.
    CA_URL=https://step-certificates.default.svc.cluster.local
    CA_ROOT_B64=$(kubectl get -o jsonpath="{.data['root_ca\.crt']}" configmaps/step-certificates-certs | step base64)
    # Same as the one in answer.
    CA_PROVISIONER_NAME=magicloud@magicloud.lan
    CA_PROVISIONER_KID=$(kubectl get -o jsonpath="{.data['ca\.json']}" configmaps/step-certificates-config | jq -r .authority.provisioners[0].key.kid)
    
    kubectl apply -f - << EOF
    ---
    apiVersion: certmanager.step.sm/v1beta1
    kind: StepClusterIssuer
    metadata:
      name: step-issuer
    spec:
      # The CA URL:
      url: $CA_URL
      # The base64 encoded version of the CA root certificate in PEM format:
      caBundle: $CA_ROOT_B64
      # The provisioner name, kid, and a reference to the provisioner password secret:
      provisioner:
        name: $CA_PROVISIONER_NAME
        kid: $CA_PROVISIONER_KID
        passwordRef:
          name: step-certificates-provisioner-password
          namespace: default
          key: password
    ---
    EOF
    ```

3. Install **cert-manager**.

    `kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.yaml`

4. Use Step CA for Ingress.

    The above steps create a `StepClusterIssuer`. Note that it is not a `ClusterIssuer`, since step-ca is an out of tree issuer. Its usage differs slightly from that of the in tree ones, such as ACME.

    There are three annotations to be used in Ingress for this case. According to the documentation, I think two of them are enough.

    ```YAML
      annotations:
        # `step-issuer` is the name created above.
        cert-manager.io/issuer: step-issuer
        # Either of the following should work.
        cert-manager.io/issuer-group: certmanager.step.sm
        cert-manager.io/issuer-kind: StepClusterIssuer
    ```

5. Expose the Step CA interface outside the cluster.

    The interface itself is protected by a cert signed by the current CA. Its SAN is apparently the service address. However, Traefik does not know about the CA, and Traefik requires the target must be in the SAN while the target is the pod (not the service) with its IP address. Therefore, Traefik refuses to perform ingressing for Step CA.

    The solution is using `IngressRouteTCP` with `spec.tls.passthrough`.

    ```YAML
    apiVersion: traefik.io/v1alpha1
    kind: IngressRouteTCP
    metadata:
      name: step-ca
    spec:
      routes:
      - match: HostSNI(`step-ca.magicloud.lan`)
        services:
        - name: step-certificates
          port: 443
      tls:
        passthrough: true
    ```

    This leads to another issue, ExternalDNS does not know how to monitor this object. Therefore, we need its CRD.

    First, apply [the dnsendpoint CRD](https://raw.githubusercontent.com/kubernetes-sigs/external-dns/master/config/crd/standard/dnsendpoints.externaldns.k8s.io.yaml). Then in the ExternalDNS helm values file, add the following and upgrade. `service` and `ingress` are the default values, we need `crd`.

    ```YAML
    sources:
      - service
      - ingress
      - crd
    ```

    Now create the DNS record.

    ```YAML
    apiVersion: externaldns.k8s.io/v1alpha1
    kind: DNSEndpoint
    metadata:
      name: step-ca
    spec:
      endpoints:
        - dnsName: step-ca.magicloud.lan
          recordType: A
          targets:
            - 192.168.0.102
    ```

6. Install the CA.

    In theory, the CA should be installed everywhere. For other pods in the cluster, the tool is`autocert`. However, existing pods are problematic. Luckily I do not need that. All I need to do is install the CA to my desktop so that it can communicate with the secured services in the cluster.

    After installing the `step` tool on the desktop, run the command `step ca bootstrap --ca-url step-ca.magicloud.lan --fingerprint $FINGER_PRINT` to initialize. `$FINGER_PRINT` could be found in the first few lines of the step-certificates pod log. If you missed viewing the  log, you can also use the command `step certificate fingerprint $(step path)/certs/root_ca.crt` within the step-certificates pod to find it. Then run the command `step certificate install $CRT_PATH_SHOWED_IN_LAST_STEP`.
