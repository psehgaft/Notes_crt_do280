# Manage Kubernetes Operators — DO280‑Style Hands‑On Workshop

**Duration:** ~2 hours  
**Level:** Intermediate (Cluster Admin)  
**Platform:** Red Hat OpenShift 4.14+  
**Goal:** Install and update add‑on operators managed by the **Operator Lifecycle Manager (OLM)** and understand the **Cluster Version Operator (CVO)** vs add‑on operators lifecycle.

## Learning Objectives
1. Explain the Operator pattern and OLM components (CatalogSource, PackageManifest, OperatorGroup, Subscription, InstallPlan, CSV).
2. Install and update operators using the **Web Console**.
3. Install and update operators using the **CLI (oc)** and OLM APIs.
4. Verify health and basic functionality of installed operators (File Integrity Operator, Compliance Operator).
5. Perform safe uninstall and cleanup.

---

## Pre‑requisites
- Cluster admin access (`cluster-admin`).
- `oc` CLI configured to your cluster.
- Internet access to OperatorHub or mirrored catalogs (for disconnected follow **Appendix A**).

### Environment Variables (suggested)
```bash
export OCP_CONSOLE_URL=$(oc whoami --show-console)
export OCP_API_URL=$(oc whoami --show-server)
echo "Console: $OCP_CONSOLE_URL"; echo "API: $OCP_API_URL"
```

---

## Workshop Flow (Timeline)

| Time | Module |
|------|--------|
| 0:00–0:15 | **Theory:** Operator Pattern, OLM & CVO, catalogs, channels, approval modes |
| 0:15–0:40 | **Exercise 1 (Web):** Install File Integrity Operator via Console |
| 0:40–1:20 | **Exercise 2 (CLI):** Install File Integrity Operator with **Manual** updates |
| 1:20–1:50 | **Lab:** Install **Compliance Operator** (CLI), verify workloads & run a simple scan |
| 1:50–2:00 | **Cleanup, Summary & Q&A** |

---

## Quick Theory (with Quiz)

**Operator Pattern.** Operators extend Kubernetes with **CRDs** and a **controller** that watches CRs and reconciles workloads.  
**CVO vs OLM.** CVO manages **cluster operators** (platform) in lock‑step with cluster upgrades. OLM manages **add‑on operators** (from **OperatorHub** catalogs) independently.

**OLM Key Resources**
- `CatalogSource` → lists available operators.
- `PackageManifest` → metadata for a package (channels/CSVs).
- `OperatorGroup` → target namespaces the operator watches.
- `Subscription` → installs/updates a package from a catalog.
- `InstallPlan` → execution plan for an install/upgrade.
- `ClusterServiceVersion (CSV)` → versioned install recipe & status.

### Mini‑Quiz (single choice)
1) The resource you modify to **approve manual updates** is:  
   a) CSV  b) **InstallPlan**  c) Subscription  d) OperatorGroup  
2) To make an operator available to **all namespaces**, use:  
   a) `targetNamespaces: []` in OperatorGroup  b) **global OperatorGroup** in `openshift-operators`  c) set channel to `stable`  
3) Who updates platform operators like `authentication`?  
   a) OLM  b) Administrator  c) **CVO**

---

## Exercise 1 — Install Operators with the **Web Console** (File Integrity)

**Outcome:** Install & uninstall the File Integrity Operator, identify its OLM artifacts and workloads.

1. Log in as admin and open console:
   ```bash
   oc login -u admin -p '<password>' https://$OCP_API_URL
   echo "$OCP_CONSOLE_URL"
   ```
2. Console → **Operators → OperatorHub**, search **“File Integrity”** → **Install**.
3. Options (use defaults unless your policy differs):
   - **Installation mode:** *All namespaces* (creates `openshift-file-integrity`).
   - **Installed namespace:** `openshift-file-integrity` (or suggested).
   - **Approval:** Automatic (for this exercise).
4. Click **Install** → then **View operator** when ready.
5. Inspect tabs:
   - **Details** & **Conditions** (look for *Succeeded*).
   - **YAML** (CSV spec).
   - **Subscription** (channel & approval; link to **InstallPlan**).
6. (Optional) Test CR flow:
   - Create a CR **FileIntegrity** (form or YAML); set `spec.config.gracePeriod: 60` and observe **FileIntegrityNodeStatus** after some minutes.
7. **Uninstall**: Operators → **Installed Operators** → *File Integrity Operator* → **Actions → Uninstall Operator**.  
   Then delete project **`openshift-file-integrity`** (Home → Projects → select → Delete).

**Validation**
```bash
oc get csv -A | grep file-integrity || echo "Not installed (as expected after uninstall)"
```

---

## Exercise 2 — Install Operators with the **CLI** (Manual approval)

**Outcome:** Install File Integrity Operator with **Manual** approval and verify InstallPlan flow.

> The following files are provided in `archivos.yml` (ready to `oc apply -f`).

1. **Create namespace** with labels (monitoring + PSP/Pod Security hints):
   ```bash
   oc apply -f archivos.yml -n default --prune=false      -l workshop=manage-operators,part=namespace-fio
   ```
   Or explicitly:
   ```bash
   oc apply -f - <<'YAML'
   apiVersion: v1
   kind: Namespace
   metadata:
     name: openshift-file-integrity
     labels:
       openshift.io/cluster-monitoring: "true"
       pod-security.kubernetes.io/enforce: privileged
   YAML
   ```

2. **OperatorGroup** targeting only that namespace:
   ```bash
   oc apply -f archivos.yml -n openshift-file-integrity      -l workshop=manage-operators,part=operatorgroup-fio
   ```

3. **Subscription** (Manual approval; channel `stable`):
   ```bash
   oc apply -f archivos.yml -n openshift-file-integrity      -l workshop=manage-operators,part=subscription-fio
   ```

4. **Discover InstallPlan** and **approve**:
   ```bash
   IP=$(oc get installplan -n openshift-file-integrity        -o jsonpath='{.items[0].metadata.name}')
   oc get installplan $IP -n openshift-file-integrity -o jsonpath='{.spec}{"\n"}'
   oc patch installplan $IP -n openshift-file-integrity --type merge -p '{"spec":{"approved":true}}'
   ```

5. **Verify** operator:
   ```bash
   oc -n openshift-file-integrity get csv,deploy,po
   oc describe operator file-integrity-operator -n openshift-file-integrity | egrep -i 'Succeeded|InstallSucceeded|RequiresApproval|InstallPlanPending'
   ```

6. **(Optional) Test CR**
   ```bash
   oc apply -f archivos.yml -n openshift-file-integrity      -l workshop=manage-operators,part=fileintegrity-cr
   oc -n openshift-file-integrity get fileintegrity,fileintegritynodestatuses
   ```

**Cleanup**
```bash
oc -n openshift-file-integrity delete subscription,fileintegrity --all
oc -n openshift-file-integrity delete operatorgroup --all || true
oc delete ns openshift-file-integrity
```

---

## Lab — Manage Kubernetes Operators (Compliance Operator)

**Outcome:** Install **Compliance Operator** (Automatic approval), inspect CSV + deployments, run a basic `ScanSettingBinding` example.

1. **Create namespace & OperatorGroup & Subscription**:
   ```bash
   oc apply -f archivos.yml -n default --prune=false      -l workshop=manage-operators,part=compliance-setup
   ```

2. **Wait** for CSV phase **Succeeded** and deployments ready:
   ```bash
   oc -n openshift-compliance get csv
   oc -n openshift-compliance get deploy
   ```

3. **Create ScanSettingBinding** (nist‑moderate) and watch a suite finish:
   ```bash
   oc apply -f archivos.yml -n openshift-compliance      -l workshop=manage-operators,part=compliance-ssb
   watch -n5 'oc -n openshift-compliance get compliancesuite,pod'
   ```

**Cleanup**
```bash
oc delete ns openshift-compliance
```

---

## Troubleshooting Checklist

- **OLM artifacts:** check `Subscription`, `InstallPlan`, `CSV` conditions.
  ```bash
  oc get subscription -A; oc get installplan -A; oc get csv -A
  ```
- **Logs:** operator pod logs; CSV status `message`; events in namespace.
- **Channels/Approvals:** wrong channel or waiting manual approval.
- **Permissions/Namespaces:** OperatorGroup targets and required labels.
- **Disconnected:** verify mirrored **CatalogSource** (Appendix A).

---

## Appendix A — Disconnected / Custom CatalogSource (template)
A sample is provided in `templates.yml` (resource `CatalogSource`). Point it to your internal index image (e.g., `registry.example.com/olm/catalog:latest`).

---

## References (APA)
- Red Hat. (2024). *Operators*. In **OpenShift Container Platform 4.14 Documentation**. https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html-single/operators/index  
- Red Hat. (2024). *Installing from OperatorHub using the Web Console / CLI*. In **OCP 4.14 Operators**. https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html-single/operators/index#olm-installing-from-operatorhub-using-web-console_olm-adding-operators-to-a-cluster ; https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html-single/operators/index#olm-installing-operator-from-operatorhub-using-cli_olm-adding-operators-to-a-cluster  
- Red Hat. (2024). *File Integrity Operator*. In **Security & Compliance (OCP 4.14)**. https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html-single/security_and_compliance/index#file-integrity-operator-release-notes  
- Red Hat. (2024). *Compliance Operator*. In **Security & Compliance (OCP 4.14)**. https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html-single/security_and_compliance/index#co-overview  
- Operator Framework. (n.d.). *Operator SDK*. https://sdk.operatorframework.io/  
- Java Operator SDK. (n.d.). *Java Operator SDK* (Quarkus extension). https://javaoperatorsdk.io/

---

## License
MIT — Use at your own risk in lab environments.
