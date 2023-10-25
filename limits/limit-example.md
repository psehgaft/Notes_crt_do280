#Limits

```limits.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: [name]
  namespace: [namespace]
spec:
  limits:
  - min:
      memory: 128Mi
    defaultRequest:
      memory: 256Mi
    default:
      memory: 512Mi
    max:
      memory: 1Gi
    type: Container
```

oc get pod -n [name-pod] -o jsonpath='{.items[0].spec.containers[0].resources}'
