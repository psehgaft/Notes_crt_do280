# Readme_non-HTTP-SNI_Applications.md

> **Title:** Exposing non‑HTTP/SNI Applications on Kubernetes & Red Hat OpenShift  
> **Author:** psehgaft  
> **Audience:** CKA/CKAD/DO280 practitioners, Platform & NetOps engineers  
> **Duration:** ~2–3 hours (self‑paced)  
> **Runs on:** Any Kubernetes ≥1.24 or OpenShift ≥4.12 (bare‑metal, vSphere, on‑prem, or cloud)

---

## Abstract

Kubernetes Ingresses and OpenShift Routes are HTTP/SNI‑aware and therefore great for web traffic. Many enterprise workloads, however, speak **non‑HTTP protocols** (RTSP, TCP/UDP daemons, databases, MQTT, AMQP, Redis, etc.). This lab shows **two production‑grade patterns** to expose those services **without** relying on an ingress controller:

1. **LoadBalancer Services** (cloud LB or MetalLB on-prem)  
2. **Multus secondary networks** (attach Pods to additional L2/L3 networks)

You’ll install minimal sample apps, expose them safely, test connectivity, and learn hardening tips and operational gotchas.

---

## Goals

- Expose applications externally **without** an ingress controller.  
- Use **Service `type: LoadBalancer`** to expose non‑HTTP services.  
- Configure a **secondary network** with **Multus** and attach Pods to it.  
- Validate connectivity end‑to‑end with `nc`, `curl`, and `psql`.  
- Prefer vendor‑agnostic YAML and variables so it runs **anywhere**.

---

## Pre‑requisites

- Cluster access with `kubectl` or `oc` and permissions to create namespaces, Deployments, Services, and (for Multus) `NetworkAttachmentDefinition`.
- One of:
  - **Cloud LB available** (AKS/EKS/GKE/ROSA/ARO/OpenShift on cloud), **or**
  - **On‑prem LB** via **MetalLB** (Operator or Helm) with a free pool of IPs.
- For Multus exercise, cluster must already have **Multus** (default on OpenShift) and at least **one node NIC** or bridge usable for a secondary network.
- Local tools for testing: `nc` (nmap‑ncat), `curl`, `psql` (for PostgreSQL exercise).

> **Tip (OpenShift):** Use `oc` commands; on vanilla Kubernetes use `kubectl`. All manifests are vendor‑neutral unless noted.

---

## Environment Variables (adjust to your setup)

```bash
# Common
export NS_LB="non-http-lb"
export NS_MULTUS="non-http-multus"
export NS_LAB="non-http-review"

# LoadBalancer / MetalLB
export APP_PORT="8554"                # Non-HTTP sample port (RTSP-like)
export LB_SVC_NAME="virtual-rtsp-lb"

# Multus
export NAD_NAME="custom"
export MULTUS_IFACE_DEVICE="ens4"     # Change to a valid device (e.g., ens4, eth1)
export MULTUS_STATIC_CIDR="192.168.51.10/24"  # Change to your isolated subnet
export MULTUS_APP_PORT="8080"

# PostgreSQL sample
export PG_USER="user"
export PG_DB="sample"
export PG_PASSWORD="password"
```

---

## Section A — LoadBalancer Services

### A.1 Concept

- Use a Service of type **LoadBalancer** to expose a non‑HTTP port from your Pods.  
- On cloud: the controller allocates an external IP via the provider’s LB.  
- On bare‑metal: use **MetalLB** with an IP pool (Layer2 or BGP) to assign an address.

> **Prefer Routes/Ingress for HTTP/S**; use LB/NodePort for **TCP/UDP non‑HTTP** protocols.

### A.2 Minimal RTSP‑like Deployment (TCP on `${APP_PORT}`)

**File:** `virtual-rtsp.yaml` (namespace‑agnostic)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: virtual-rtsp
spec:
  replicas: 1
  selector:
    matchLabels: { app: virtual-rtsp }
  template:
    metadata:
      labels: { app: virtual-rtsp }
    spec:
      containers:
      - name: rtsp
        # Very small TCP server that keeps port open; replace with your image if needed.
        image: ghcr.io/psehgaft/tcp-echo:alpine
        # If the above image is unavailable in your env, fall back to busybox + nc listener:
        # image: busybox:1.36
        # command: ["/bin/sh","-c"]
        # args: ["nc -lk -p ${APP_PORT} -e /bin/cat"]
        ports:
        - containerPort: 8554
          name: rtsp
          protocol: TCP
```

> If your registry policy blocks `ghcr.io`, switch to any in‑house image that listens on TCP 8554.

### A.3 Expose via LoadBalancer

```bash
# Create namespace
kubectl create ns "$NS_LB"

# Deploy
kubectl -n "$NS_LB" apply -f virtual-rtsp.yaml

# Expose
kubectl -n "$NS_LB" expose deployment/virtual-rtsp \
  --type=LoadBalancer --name="${LB_SVC_NAME}" --port="${APP_PORT}" --target-port="${APP_PORT}"

# Watch for external IP
kubectl -n "$NS_LB" get svc "${LB_SVC_NAME}" -w
```

When `EXTERNAL-IP` becomes available, test connectivity (replace the IP obtained):

```bash
export EXT_IP="$(kubectl -n "$NS_LB" get svc ${LB_SVC_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
# Some clouds return hostname:
[ -z "$EXT_IP" ] && export EXT_IP="$(kubectl -n "$NS_LB" get svc ${LB_SVC_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

echo "LB address: $EXT_IP"

# TCP dial test
nc -vz "$EXT_IP" "${APP_PORT}"
```

> **MetalLB note:** ensure you configured an IPAddressPool/Advertisement that includes at least one free IP.

### A.4 Cleanup (Section A)

```bash
kubectl -n "$NS_LB" delete svc,deploy --all
kubectl delete ns "$NS_LB"
```

---

## Section B — Multus Secondary Networks

### B.1 Concept

Attach an additional network interface to Pods via **Multus** using a namespaced `NetworkAttachmentDefinition` (NAD). This pattern is useful when you must place pods into **isolated L2 segments**, DMZs, or specialized NICs (SR‑IOV).

### B.2 Create Namespace and a Simple TCP/Web App

**File:** `nginx.yaml` (uses port 8080; works without Service because we’ll reach it via the extra NIC)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels: { app: nginx }
  template:
    metadata:
      labels: { app: nginx }
    spec:
      containers:
      - name: nginx
        image: docker.io/library/nginx:1.25-alpine
        ports:
        - containerPort: 8080
        args: ["sh","-c","sed -i 's/80/8080/' /etc/nginx/conf.d/default.conf && echo '<h1>Hello, world from nginx!</h1>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
```

### B.3 Define the NAD (host‑device example)

> Adjust `device` and `addresses` to match your environment.

**File:** `network-attachment-definition.yaml`

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: ${NAD_NAME}
spec:
  config: |-
    {
      "cniVersion": "0.3.1",
      "name": "${NAD_NAME}",
      "type": "host-device",
      "device": "${MULTUS_IFACE_DEVICE}",
      "ipam": {
        "type": "static",
        "addresses": [
          { "address": "${MULTUS_STATIC_CIDR}" }
        ]
      }
    }
```

> Alternatives: `macvlan`, `ipvlan`, or `bridge` CNI with DHCP or static IPAM. Choose what your network supports.

### B.4 Deploy and Attach the Secondary Network

```bash
kubectl create ns "$NS_MULTUS"

# Create NAD in the same namespace as the Pods:
envsubst < network-attachment-definition.yaml | kubectl -n "$NS_MULTUS" apply -f -

# Add the Multus annotation to the Pod template:
# Option 1: patch existing Deployment
kubectl -n "$NS_MULTUS" apply -f nginx.yaml

kubectl -n "$NS_MULTUS" patch deploy/nginx --type=json \
  -p='[{"op":"add","path":"/spec/template/metadata/annotations","value":{"k8s.v1.cni.cncf.io/networks":"'${NAD_NAME}'"}}]'

kubectl -n "$NS_MULTUS" rollout status deploy/nginx

# Verify network status
POD="$(kubectl -n "$NS_MULTUS" get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "$NS_MULTUS" get pod "$POD" -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}{"\n"}'
```

### B.5 Test Connectivity from a Host that Reaches the Isolated Subnet

From any machine that has L3 reachability to `${MULTUS_STATIC_CIDR%/*}`:

```bash
export MULTUS_IP="${MULTUS_STATIC_CIDR%/*}" # strip /mask if needed manually if your shell doesn't
# If the above doesn't strip, set MULTUS_IP manually to the IP portion, e.g. 192.168.51.10
curl "http://${MULTUS_IP}:8080/"
```

> If the node/host you’re testing from cannot reach that subnet, you’ll see a timeout—by design.

### B.6 Cleanup (Section B)

```bash
kubectl -n "$NS_MULTUS" delete deploy/nginx
kubectl -n "$NS_MULTUS" delete network-attachment-definition ${NAD_NAME}
kubectl delete ns "$NS_MULTUS"
```

---

## Section C — Final Lab: Expose non‑HTTP/SNI Applications (End‑to‑End)

### Outcomes

- Expose a non‑HTTP app with `type: LoadBalancer`  
- Create a NAD for an isolated network and attach a deployment  
- Validate success and reason about failures

### Steps

1. **RTSP‑like app via LoadBalancer**
   ```bash
   kubectl create ns "$NS_LAB"-rtsp
   kubectl -n "$NS_LAB"-rtsp apply -f virtual-rtsp.yaml
   kubectl -n "$NS_LAB"-rtsp expose deploy/virtual-rtsp \
     --type=LoadBalancer --name=virtual-rtsp-loadbalancer --port="${APP_PORT}" --target-port="${APP_PORT}"
   kubectl -n "$NS_LAB"-rtsp get svc virtual-rtsp-loadbalancer -w
   ```
   Test with:
   ```bash
   export RTSP_ADDR="$(kubectl -n "$NS_LAB"-rtsp get svc virtual-rtsp-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
   nc -vz "$RTSP_ADDR" "${APP_PORT}"
   ```

2. **Nginx on a Multus secondary network**
   ```bash
   kubectl create ns "$NS_LAB"-nginx
   envsubst < network-attachment-definition.yaml | kubectl -n "$NS_LAB"-nginx apply -f -
   kubectl -n "$NS_LAB"-nginx apply -f nginx.yaml
   kubectl -n "$NS_LAB"-nginx patch deploy/nginx --type=json \
     -p='[{"op":"add","path":"/spec/template/metadata/annotations","value":{"k8s.v1.cni.cncf.io/networks":"'${NAD_NAME}'"}}]'
   kubectl -n "$NS_LAB"-nginx rollout status deploy/nginx
   ```
   Validate from a reachable host:
   ```bash
   curl "http://${MULTUS_STATIC_CIDR%/*}:8080/"
   ```

3. **(Optional) PostgreSQL on Multus**
   Use this manifest to create a single‑pod PostgreSQL with Recreate strategy and PVC:

   **File:** `postgres.yaml`
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata: { name: database }
   type: Opaque
   stringData:
     POSTGRES_DB: ${PG_DB}
     POSTGRES_USER: ${PG_USER}
     POSTGRES_PASSWORD: ${PG_PASSWORD}
   ---
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata: { name: database }
   spec:
     accessModes: ["ReadWriteOnce"]
     resources:
       requests:
         storage: 1Gi
   ---
   apiVersion: apps/v1
   kind: Deployment
   metadata: { name: database }
   spec:
     replicas: 1
     strategy: { type: Recreate }
     selector: { matchLabels: { app: database } }
     template:
       metadata:
         labels: { app: database }
         annotations:
           k8s.v1.cni.cncf.io/networks: ${NAD_NAME}
       spec:
         containers:
         - name: postgres
           image: docker.io/library/postgres:16-alpine
           envFrom: [{ secretRef: { name: database } }]
           ports: [{ containerPort: 5432, name: pg }]
           volumeMounts: [{ name: data, mountPath: /var/lib/postgresql/data }]
         volumes:
         - name: data
           persistentVolumeClaim: { claimName: database }
   ```

   Deploy & test:
   ```bash
   kubectl -n "$NS_LAB"-nginx apply -f postgres.yaml --dry-run=client -o yaml | envsubst | kubectl -n "$NS_LAB"-nginx apply -f -
   kubectl -n "$NS_LAB"-nginx rollout status deploy/database

   # From a host that reaches the Multus subnet:
   psql -h "${MULTUS_STATIC_CIDR%/*}" -U "${PG_USER}" "${PG_DB}" -c 'SELECT 1;' <<<"${PG_PASSWORD}"
   ```

### Cleanup (Lab)

```bash
kubectl delete ns "$NS_LAB"-rtsp "$NS_LAB"-nginx --ignore-not-found
```

---

## Troubleshooting & Notes

- **EXTERNAL-IP `<pending>`** on Service:
  - Cloud: ensure your cluster has a functional CCM and permissions to allocate LBs.
  - On‑prem: verify MetalLB `IPAddressPool` has free IPs and `L2Advertisement/BGPAdvertisement` is configured.
- **No route to Multus subnet** from your laptop:
  - That’s expected unless the laptop has a route/VPN to that network. Test from a bastion inside the routed domain.
- **SR‑IOV vs host‑device vs macvlan/ipvlan:**
  - Pick based on NIC capabilities, network policy, and MAC limits on your L2 domain.
- **Security:** non‑HTTP services exposed to the Internet must be protected (firewalls/NACLs, authentication, TLS if applicable). Consider `NetworkPolicy` and node‑firewalling.
- **OpenShift Routes:** not for arbitrary TCP/UDP unless using ingress‑controller **`endpointPublishingStrategy: HostNetwork`** and `passthrough` TLS for SNI—still HTTP/S oriented.

---

## Appendix — MetalLB (On‑prem quickstart)

> Use **one** of the official methods (Operator on OpenShift or Helm/kustomize on vanilla K8s). Example with OpenShift Operator:

1. Install **MetalLB Operator** from OperatorHub.  
2. Create an IP pool:
   ```yaml
   apiVersion: metallb.io/v1beta1
   kind: IPAddressPool
   metadata: { name: lb-pool, namespace: metallb-system }
   spec:
     addresses:
       - 192.168.50.20-192.168.50.30   # change to your free range
   ---
   apiVersion: metallb.io/v1beta1
   kind: L2Advertisement
   metadata: { name: l2, namespace: metallb-system }
   spec: {}
   ```

---

## References (APA)

- Kubernetes. (2024). *Service*. Kubernetes Documentation. https://kubernetes.io/docs/concepts/services-networking/service/  
- Kubernetes. (2024). *Network plugins*. Kubernetes Documentation. https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/  
- Multus CNI. (2024). *Quickstart*. https://github.com/k8snetworkplumbingwg/multus-cni  
- Red Hat. (2025). *Configuring additional networks (OpenShift)*. https://docs.openshift.com/container-platform/latest/networking/multiple_networks/understanding-multiple-networks.html  
- Red Hat. (2025). *Working with Services (OpenShift)*. https://docs.openshift.com/container-platform/latest/networking/networking_operators/ingress-operator.html#nw-services_about  
- MetalLB. (2024). *Installation & Configuration*. https://metallb.universe.tf/  
- Red Hat. (2025). *SR‑IOV Network Operator*. https://docs.openshift.com/container-platform/latest/networking/hardware_networks/about-sriov.html  
- Red Hat. (2025). *Kubernetes NMState Operator*. https://docs.openshift.com/container-platform/latest/networking/k8s_nmstate/k8s-nmstate-about-the-k8s-nmstate-operator.html

---

## License

This content by **psehgaft** is provided as-is for educational use.
