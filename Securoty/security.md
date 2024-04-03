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


