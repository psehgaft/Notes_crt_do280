
# 📊 Metrics Queries to Validate HPA and Metrics Server in OpenShift

This guide provides Prometheus queries to help diagnose issues with `metrics-server` and validate if HPA (Horizontal Pod Autoscaler) metrics are working properly in an OpenShift cluster.

---

## ✅ 1. Check if `metrics-server` is up

```promql
up{job="metrics-server"}
```

- `1` = metrics-server is up and responding.
- `0` or empty = Not running or unreachable.

---

## ✅ 2. Validate that `metrics-server` is exporting metrics

```promql
rate(container_cpu_usage_seconds_total{pod=~"metrics-server.*"}[5m])
```

If this returns nothing, the metrics-server may not be running or not exporting.

---

## ✅ 3. Check if the metrics API is being accessed

```promql
apiserver_request_total{resource="pods", group="metrics.k8s.io", verb="GET"}
```

If there are `0` requests, it means nothing (including HPA) is accessing the metrics-server API.

---

## ✅ 4. Detect API server errors when calling metrics-server

```promql
apiserver_request_total{group="metrics.k8s.io", code=~"5.."}
```

This shows HTTP 500-level errors indicating server-side issues between the API server and metrics-server.

---

## ✅ 5. Look for active alerts (if using OpenShift Monitoring)

```promql
ALERTS{alertname=~"KubeMetricsServer.*|MetricsAPIServiceAvailabilityCritical"}
```

This captures alerts such as:
- `KubeMetricsServerDown`
- `KubeMetricsServerError`
- `MetricsAPIServiceAvailabilityCritical`

---

## 🔍 Bonus: Check APIService status via CLI

```bash
oc get apiservice v1beta1.metrics.k8s.io -o yaml
```

Look for this block:

```yaml
status:
  conditions:
    - type: Available
      status: False
      reason: MissingEndpoints
```

If `Available` is `False` or `MissingEndpoints` is shown, the metrics-server is likely not available or not working correctly.

---
