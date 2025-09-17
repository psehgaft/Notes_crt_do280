# Deploy Packaged Applications on OpenShift

> **Audience:** Developers / Platform Engineers with basic `oc` and Kubernetes skills  
> **Duration:** ~2 hours (100–110 min hands‑on + 10–20 min Q&A)  
> **Cluster DNS:** `*.apps.psehgaft.training` | API: `https://api.psehgaft.training:6443`  
> **Repo to store files:** `https://github.com/psehgaft/Notes_crt_do280/tree/main/DeployPackagedApplications`

This workshop is **fully self-contained** and designed so that **each lab builds on the previous one** with **no hidden dependencies**. You will deploy and update applications using:
1) raw YAML, 2) **Kustomize**, 3) **OpenShift Templates**, and 4) **Helm** — all with working Routes on the `psehgaft.training` domain.

---

## Pre‑work

Make sure the following are ready **before** starting. These steps make the labs reproducible in any OpenShift 4.12+ cluster.

### 1) Tools on your workstation
- `oc` (OpenShift CLI) v4.12+
- `kubectl` (optional)
- `helm` v3.12+
- `kustomize` v5+ (or use `kubectl kustomize`)
- `jq` (nice to have)

### 2) Cluster requirements
- OpenShift 4.12+ reachable at `https://api.psehgaft.training:6443`
- A wildcard Apps domain: `*.apps.psehgaft.training`
- A `developer` user with the `developer` password for the labs (or use your user of choice)
- **Cluster-wide pull access to public images from `quay.io`** (no Red Hat registry creds needed)

### 3) Namespaces (created on demand by the labs)
We will create the following projects as we go:
- `packaged-yaml`
- `packaged-kustomize`
- `packaged-templates`
- `packaged-charts-development`
- `packaged-charts-production`
- `packaged-review`
- `packaged-review-prod`

### 4) Where to save the lab files
Clone your notes repo and work inside the folder below. (You can also copy/paste directly in your editor and commit later.)

```bash
git clone https://github.com/psehgaft/Notes_crt_do280.git
cd Notes_crt_do280/DeployPackagedApplications
```

> If the folder doesn’t exist yet, create it and commit the lab assets as you go.

---

## Agenda & Timeboxes (approx.)

1. **Login + Project hygiene**  
2. **Lab 1 – Plain YAML**: Deploy & update from raw manifests 
3. **Lab 2 – Kustomize**: Overlays for dev/prod, image/replicas customizations  
4. **Lab 3 – OpenShift Templates**: Parameterized app + DB via template  
5. **Lab 4 – Helm Charts**: Local chart install, upgrade, prod scale-out 
6. **Wrap-up + Q&A**

> Total ~110–120 min hands-on including short verifications between labs.

---

## Common setup (used by all labs)

```bash
# Login (adjust user/pass if needed)
oc login -u developer -p developer https://api.psehgaft.training:6443

# Confirm cluster version and domain
oc version
oc get ingresses.config/cluster -o jsonpath='{.spec.domain}'; echo
# Should print something like: apps.psehgaft.training
```

We’ll use **public images from Quay** to avoid private-registry prerequisites.

- App: `quay.io/etherpad/etherpad:1.9.2` (simple web app for Helm labs)
- DB: `quay.io/bitnami/mysql:8.0` (MySQL for template lab)
- Utility client (for DB test): `quay.io/bitnami/mysql:8.0` (same image provides `mysql` client)

> You can replace images later with enterprise-approved mirrors if needed.

---

# Lab 1 — Deploy & Update from Raw YAML (15 min)

**Goal:** Deploy a simple stateless web app from YAML and update it.

### 1. Create project and manifests
```bash
oc new-project packaged-yaml
mkdir -p apps/yaml && cd apps/yaml
```

Create `deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-web
  labels:
    app: hello-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-web
  template:
    metadata:
      labels:
        app: hello-web
    spec:
      containers:
        - name: hello-web
          image: quay.io/openshift/origin-nodejs-sample:latest
          ports:
            - containerPort: 8080
          env:
            - name: RESPONSE
              value: "Hello from raw YAML v1"
---
apiVersion: v1
kind: Service
metadata:
  name: hello-web
spec:
  selector:
    app: hello-web
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: hello-web
spec:
  to:
    kind: Service
    name: hello-web
  port:
    targetPort: 80
```

Apply and verify:
```bash
oc apply -f deployment.yaml
oc rollout status deploy/hello-web
oc get route hello-web -o jsonpath='{.spec.host}'; echo
# Open: http://<printed-host>
```

### 2. Update the app
Edit `deployment.yaml` to change `RESPONSE` to `"Hello from raw YAML v2"` and scale to `replicas: 2`. Then:
```bash
oc apply -f deployment.yaml
oc rollout status deploy/hello-web
oc get pods -l app=hello-web -o wide
```

**Outcome:** You deployed and updated an app purely from YAML.

---

# Lab 2 — Deploy & Update with Kustomize (20 min)

**Goal:** Use base + overlays to manage dev/prod differences (image/tag/replicas/Route).

```bash
cd ../../   # back to DeployPackagedApplications
mkdir -p apps/kustomize/base apps/kustomize/overlays/dev apps/kustomize/overlays/prod
```

Create **base** (files under `apps/kustomize/base/`):

`deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kweb
  labels: { app: kweb }
spec:
  replicas: 1
  selector: { matchLabels: { app: kweb } }
  template:
    metadata: { labels: { app: kweb } }
    spec:
      containers:
        - name: kweb
          image: quay.io/etherpad/etherpad:1.9.2
          ports: [ { containerPort: 9001 } ]
```

`service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: kweb
spec:
  selector: { app: kweb }
  ports:
    - port: 80
      targetPort: 9001
```

`route.yaml`:
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: kweb
spec:
  to: { kind: Service, name: kweb }
  port: { targetPort: 80 }
```

`kustomization.yaml`:
```yaml
resources:
  - deployment.yaml
  - service.yaml
  - route.yaml
```

Create **overlays/dev** (`apps/kustomize/overlays/dev/kustomization.yaml`):
```yaml
resources:
  - ../../base
namePrefix: dev-
patches:
  - target:
      kind: Deployment
      name: kweb
    patch: |
      - op: replace
        path: /spec/replicas
        value: 1
      - op: add
        path: /spec/template/spec/containers/0/env
        value:
          - name: TITLE
            value: "Kustomize DEV"
  - target:
      kind: Route
      name: kweb
    patch: |
      - op: add
        path: /spec/host
        value: development-etherpad.apps.psehgaft.training
```

Create **overlays/prod** (`apps/kustomize/overlays/prod/kustomization.yaml`):
```yaml
resources:
  - ../../base
namePrefix: prod-
patches:
  - target:
      kind: Deployment
      name: kweb
    patch: |
      - op: replace
        path: /spec/replicas
        value: 3
      - op: add
        path: /spec/template/spec/containers/0/env
        value:
          - name: TITLE
            value: "Kustomize PROD"
  - target:
      kind: Route
      name: kweb
    patch: |
      - op: add
        path: /spec/host
        value: etherpad.apps.psehgaft.training
```

### Apply dev and prod
```bash
# DEV
oc new-project packaged-kustomize || oc project packaged-kustomize
kubectl apply -k apps/kustomize/overlays/dev
oc rollout status deploy/dev-kweb
oc get route dev-kweb -o jsonpath='{.spec.host}'; echo

# PROD
kubectl apply -k apps/kustomize/overlays/prod
oc rollout status deploy/prod-kweb
oc get route prod-kweb -o jsonpath='{.spec.host}'; echo
```

**Outcome:** You created dev/prod variants from a single base using Kustomize patches.

---

# Lab 3 — OpenShift Templates (25 min)

**Goal:** Deploy a **MySQL** database and an app that can initialize/use it, all via an OpenShift **Template** you control (no external classroom registry).

Create project and files:
```bash
oc new-project packaged-templates || oc project packaged-templates
mkdir -p apps/templates
cd apps/templates
```

## 3.1 MySQL via Deployment (not a template yet)
`mysql.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
stringData:
  MYSQL_USER: user1
  MYSQL_PASSWORD: mypasswd
  MYSQL_DATABASE: sampledb
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1
  selector: { matchLabels: { app: mysql } }
  template:
    metadata: { labels: { app: mysql } }
    spec:
      containers:
        - name: mysql
          image: quay.io/bitnami/mysql:8.0
          env:
            - name: MYSQL_USER
              valueFrom: { secretKeyRef: { name: mysql-secret, key: MYSQL_USER } }
            - name: MYSQL_PASSWORD
              valueFrom: { secretKeyRef: { name: mysql-secret, key: MYSQL_PASSWORD } }
            - name: MYSQL_DATABASE
              valueFrom: { secretKeyRef: { name: mysql-secret, key: MYSQL_DATABASE } }
            - name: MYSQL_ROOT_PASSWORD
              value: "rootpasswd"
          ports: [ { containerPort: 3306 } ]
          readinessProbe:
            exec: { command: ["bash","-lc","mysqladmin ping -uroot -prootpasswd"] }
            initialDelaySeconds: 20
            periodSeconds: 10
          livenessProbe:
            exec: { command: ["bash","-lc","mysqladmin ping -uroot -prootpasswd"] }
            initialDelaySeconds: 30
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  selector: { app: mysql }
  ports: [ { port: 3306, targetPort: 3306 } ]
```

Apply and verify:
```bash
oc apply -f mysql.yaml
oc rollout status deploy/mysql
```

**Quick DB check (ephemeral pod with client):**
```bash
oc run query-db -it --rm --restart=Never \
  --image=quay.io/bitnami/mysql:8.0 -- \
  bash -lc "mysql -uuser1 -pmypasswd -h mysql -P3306 sampledb -e 'SHOW DATABASES;'"
```

## 3.2 App + Route via **OpenShift Template**
Create `roster-template.yaml`:
```yaml
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: roster-template
objects:
  - apiVersion: v1
    kind: Secret
    metadata: { name: mysql }
    type: Opaque
    stringData:
      MYSQL_USER: "${MYSQL_USER}"
      MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
  - apiVersion: apps/v1
    kind: Deployment
    metadata: { name: do280-roster }
    spec:
      replicas: 1
      selector: { matchLabels: { app: do280-roster } }
      template:
        metadata: { labels: { app: do280-roster } }
        spec:
          containers:
            - name: roster
              image: "${IMAGE}"
              imagePullPolicy: IfNotPresent
              env:
                - name: INIT_DB
                  value: "${INIT_DB}"
                - name: DATABASE_SERVICE_NAME
                  value: "${DATABASE_SERVICE_NAME}"
                - name: MYSQL_USER
                  valueFrom: { secretKeyRef: { name: mysql, key: MYSQL_USER } }
                - name: MYSQL_PASSWORD
                  valueFrom: { secretKeyRef: { name: mysql, key: MYSQL_PASSWORD } }
                - name: MYSQL_DATABASE
                  value: "${MYSQL_DATABASE}"
              ports: [ { containerPort: 8080 } ]
  - apiVersion: v1
    kind: Service
    metadata: { name: do280-roster }
    spec:
      selector: { app: do280-roster }
      ports: [ { port: 80, targetPort: 8080 } ]
  - apiVersion: route.openshift.io/v1
    kind: Route
    metadata: { name: do280-roster }
    spec:
      host: "${ROUTE_HOST}"
      to: { kind: Service, name: do280-roster }
      port: { targetPort: 80 }
parameters:
  - name: IMAGE
    description: Application image
    value: quay.io/openshiftlabs/learn-katacoda/nodejs-mysql-app:latest
  - name: APPNAME
    description: App name
    value: do280-roster
  - name: NAMESPACE
    description: Namespace
    value: packaged-templates
  - name: DATABASE_SERVICE_NAME
    description: DB service name
    value: mysql
  - name: MYSQL_USER
    description: DB user
    value: user1
  - name: MYSQL_PASSWORD
    description: DB pass
    value: mypasswd
  - name: MYSQL_DATABASE
    description: DB name
    value: sampledb
  - name: INIT_DB
    description: Initialize DB on first run
    value: "True"
  - name: ROUTE_HOST
    description: Route host (FQDN under *.apps.psehgaft.training)
    value: do280-roster-packaged-templates.apps.psehgaft.training
```

Process & apply v1:
```bash
oc create -f roster-template.yaml
oc process roster-template | oc apply -f -
oc get pods
oc get route do280-roster -o jsonpath='{.spec.host}'; echo
# Open: http://do280-roster-packaged-templates.apps.psehgaft.training
```

**Update to v2 without re-initializing DB:**
Create `roster-parameters.env`:
```
MYSQL_USER=user1
MYSQL_PASSWORD=mypasswd
IMAGE=quay.io/openshiftlabs/learn-katacoda/nodejs-mysql-app:latest
INIT_DB=False
```

Diff & apply:
```bash
oc process roster-template --param-file=roster-parameters.env | oc diff -f - || true
oc process roster-template --param-file=roster-parameters.env | oc apply -f -
watch -n2 'oc get pods'
```

**Outcome:** Template-driven app using an existing DB with a clean update flow.

---

# Lab 4 — Helm Charts (35 min)

**Goal:** Install, upgrade, and scale an app using **Helm**. We’ll keep it self-contained by using a **local chart** (no external Helm repo needed).

Project setup:
```bash
oc new-project packaged-charts-development || oc project packaged-charts-development
mkdir -p charts/etherpad && cd charts/etherpad
helm create etherpad     # scaffold
```

Replace the scaffold with a minimal chart. Overwrite these files:

`Chart.yaml`:
```yaml
apiVersion: v2
name: etherpad
description: Minimal Etherpad chart for OpenShift
type: application
version: 0.0.6
appVersion: "1.9.2"
```

`values.yaml`:
```yaml
replicaCount: 1

image:
  repository: quay.io/etherpad/etherpad
  tag: "1.9.2"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 9001

route:
  enabled: true
  host: null   # override per env

resources: {}
```

`templates/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "etherpad.fullname" . }}
  labels: {{- include "etherpad.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels: {{- include "etherpad.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels: {{- include "etherpad.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: etherpad
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 9001
          env:
            - name: TITLE
              value: "Labs Etherpad"
```

`templates/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "etherpad.fullname" . }}
  labels: {{- include "etherpad.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "etherpad.selectorLabels" . | nindent 4 }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
```

`templates/route.yaml`:
```yaml
{{- if .Values.route.enabled }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: {{ include "etherpad.fullname" . }}
  labels: {{- include "etherpad.labels" . | nindent 4 }}
spec:
  host: {{ .Values.route.host | quote }}
  to:
    kind: Service
    name: {{ include "etherpad.fullname" . }}
  port:
    targetPort: {{ .Values.service.port }}
{{- end }}
```

**Install v0.0.6 to DEV**
Create `values-dev.yaml`:
```yaml
route:
  host: development-etherpad.apps.psehgaft.training
```

```bash
helm install example-app ./ \
  -f values-dev.yaml --version 0.0.6
oc get route
```

**Upgrade to v0.0.7**
Bump `Chart.yaml` to `version: 0.0.7` and update `values.yaml` to use `image.tag: "1.9.3"` (or keep 1.9.2 — version bump is enough to simulate an upgrade). Then:
```bash
helm upgrade example-app ./ -f values-dev.yaml --version 0.0.7
helm list
```

**Second install to PROD and scale**
```bash
oc new-project packaged-charts-production || oc project packaged-charts-production
cp ../values-dev.yaml ../values-prod.yaml
# edit values-prod.yaml to:
# route.host: etherpad.apps.psehgaft.training
sed -i 's/development-etherpad.apps.psehgaft.training/etherpad.apps.psehgaft.training/' ../values-prod.yaml

helm install production ./ -f ../values-prod.yaml --version 0.0.7
oc get route

# Scale to 3 replicas in PROD
cat > ../values-prod.yaml <<EOF
route:
  host: etherpad.apps.psehgaft.training
replicaCount: 3
EOF

helm upgrade production ./ -f ../values-prod.yaml
oc get pods -l app.kubernetes.io/name=etherpad -o wide
```

**Outcome:** Local Helm chart lifecycle: install, upgrade, multi-env rollout, and scaling.

---

## Cleanup (optional, 5 min)

```bash
for ns in packaged-yaml packaged-kustomize packaged-templates \
          packaged-charts-development packaged-charts-production \
          packaged-review packaged-review-prod; do
  oc delete project $ns || true
done
```

---

## Troubleshooting tips

- If Routes don’t resolve, confirm the cluster apps domain:  
  `oc get ingresses.config/cluster -o jsonpath='{.spec.domain}'; echo`
- If images won’t pull, ensure egress to `quay.io` or set up an internal mirror and change `image.repository` accordingly.
- For Helm templating errors, run `helm template ./ -f values-*.yaml | kubeconform -reject` (if you have `kubeconform`).

---

## References (APA)

- Helm. (2024). *Helm documentation*. https://helm.sh/docs/
- Kustomize. (2024). *Kustomize: Template-free customization of Kubernetes YAML configurations*. https://kustomize.io/
- Red Hat. (2024). *OpenShift documentation — Routes*. https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html
- Red Hat. (2024). *OpenShift documentation — Templates*. https://docs.openshift.com/container-platform/latest/applications/working_with_templates/understanding-templates.html
- Red Hat. (2024). *OpenShift documentation — Creating applications from Helm charts*. https://docs.openshift.com/container-platform/latest/applications/helm/installing-applications-with-helm.html
- CNCF. (2023). *Cloud Native definition*. https://github.com/cncf/toc/blob/main/DEFINITION.md

---

## Session checklist
- [ ] Logged in to cluster at `api.psehgaft.training:6443`
- [ ] `oc`, `helm`, `kustomize` available locally
- [ ] DEV and PROD routes reachable under `*.apps.psehgaft.training`
- [ ] All labs executed in order without missing dependencies

> **Where to commit these files:**  
> `Notes_crt_do280/DeployPackagedApplications/` (this README plus the `apps/` and `charts/` folders)
