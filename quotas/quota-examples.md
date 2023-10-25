# Manage resources

oc scale deployment test --replicas=[number of replicas]

oc get pod,deployment -n [project]

oc adm top node [node]

oc describe node/[node]

oc new-project studygroup

oc create deployment studygroup --image registry.ocp4.example.com:8443/redhattraining/hello-world-nginx

oc set resources deployment studygroup --requests=cpu=1

oc scale deployment studygroup --replicas=1

## Create Quotas

1. Direct creation

oc create quota [quotaa-name] --hard=requests.cpu=2

2. Yaml File

```quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: [quotaa-name]
  namespace: selfservice-quotas
...output omitted...
spec:
  hard:
    requests.cpu: "2"
status:
  hard:
    requests.cpu: "2"
  used:
    requests.cpu: "1"
```

oc scale deployment test --replicas=8


```cluster-quota.yaml
apiVersion: quota.openshift.io/v1
kind: ClusterResourceQuota
metadata:
  name: [name]
spec:
  quota: 1
    hard:
      limits.cpu: 4
  selector: 2
    annotations: {}
    labels:
      matchLabels:
        key: value
```
