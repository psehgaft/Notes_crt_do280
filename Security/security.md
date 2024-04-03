# Topics

- Protect External Traffic with TLS
  - Allow and protect network connections to applications inside an OpenShift cluster.

-Configure Network Policies
  - Restrict network traffic between projects and pods.
  
-Protect Internal Traffic with TLS
  - Configure and use automatic service certificates

## Overview

- Kubernetes services SDN  - 172.30.0.0/16 (IP adresses 65,536)
- Kubernetes Pod SDN       - 10.128.0.0/14 (IP adresses 262,144)


## Routes
- Edge

Client -- TLS --> [tls.crt]+[tls.key] -- No TLS --> Container
                     (Openshift)
- Passthrough

Client -- TLS --> [tls.crt]+[tls.key] -- TLS --> Mount Point [TLS certs]
                     (Openshift)                       Container

- Re-encryption

Client -- TLS --> [tls.crt]+[tls.key] -- TLS2 --> [tls2.crt]+[tls2.key] 
                     (Openshift)                       Container

# Network policies

NOTE: Network policies can help you to protect the internal traffic between your applications or between projects.



# Exercise

Deploy an application and create an unencrypted route for it.
Create an OpenShift edge route with encryption.
Create an OpenShift TLS secret and mount it in your application.

```sh
oc login --token=*** --server=https://api.***

# Create project

oc new-project network-workgroup

# Create App

oc new-app -name workgroup openshift/httpd:latest -n network-workgroup

# Valiste service creation

oc status

# Create route

oc expose svc/workgroup

### Fix

oc create route edge workgroup --service workgroup --port 8080 

```

# Create certifiates

```sh

openssl genrsa -out training.key 4096

openssl req -new -key workgroup.key -out workgroup.csr -subj "/C=US/ST=Lab/L=Example/O=Workgroup/  CN=workgoup.apps.cluster-zzqnj.dynamic.redhatworkshops.io"

openssl x509 -req -in workgroup.csr -passin file:passphrase.txt -CA workgroup-CA.pem -CAkey workgroup-CA.key -CAcreateserial -out workgroup.crt -days 60 -sha256 -extfile workgroup.ext

oc create secret tls workgroup --cert certs/workgroup.crt --key certs/workgroup.key

---------------
apiVersion: apps/v1
kind: Deployment
...output omitted...
        volumeMounts:
        - name: tls-certs
          readOnly: true
          mountPath: /usr/local/etc/ssl/certs
...output omitted...
      volumes:
      - name: workgroup-vol
        secret:
          secretName: workgroup
---
apiVersion: v1
kind: Service
...output omitted...
  ports:
  - name: https
    port: 8443
    protocol: TCP
    targetPort: 8443
...output omitted...
---------------

oc set volumes deployment/workgroup

oc create route passthrough workgroup --service workgroup --port 8443 --hostname workgoup.apps.cluster-zzqnj.dynamic.redhatworkshops.io

```

## Network Policies


```np-1.yml

kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: network-1-policy
  namespace: network-workgroup
spec:
  podSelector:  
    matchLabels:
      deployment: product-catalog
  ingress:  
  - from:  
    - namespaceSelector:
        matchLabels:
          network: network-2
      podSelector:
        matchLabels:
          role: test
    ports:  
    - port: 8080
      protocol: TCP

```

```np-2.yml

kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: network-2-policy
  namespace: network-workgroup-2
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network: network-1
```

Deny all 

```den.yml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny
spec:
  podSelector: {}
```

Allow all Openshift

NOTE: Network policies do not block traffic from pods that use host networking to pods in the same node.

```allow.yml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-openshift-ingress
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          policy-group.network.openshift.io/ingress: ""
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-openshift-monitoring
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: monitoring

``` 
