# Manage resources

Create App:

oc new-app -name [name] https://github.com/OpenShiftDemos/os-sample-python.git

oc scale deployment [name] --replicas=[number of replicas]

oc get pod,deployment -n [project]

oc adm top node [node]

oc describe node/[node]

oc new-project studygroup

oc create deployment [name] --image registry.ocp4.example.com:8443/redhattraining/hello-world-nginx

oc set resources deployment [name] --requests=cpu=1

oc scale deployment [name] --replicas=1

## Create Quotas

1. Direct creation

oc create resourcequota [quotaa-name] --hard=requests.cpu=2

oc create resourcequota [quotaa-name] --hard=count/pods=2

oc create resourcequota [quotaa-name] --hard=count/deployment=1

oc get resourcequota

2. Yaml File

```quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: workgroup-quota-cpu
  namespace: workgroup-limits
spec:
  hard:
    requests.cpu: "2"
status:
  hard:
    requests.cpu: "2"
  used:
    requests.cpu: "1"
```

```quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: workgroup-quota-cpu
  namespace: workgroup-limits
spec:
  hard: 
    limits.memory: 4Gi
    requests.memory: 2Gi
  scopes: {} 
  scopeSelector: {}
```

oc scale deployment test --replicas=8

# Cluster side

oc create clusterresourcequota example --project-label-selector=group=dev --hard=requests.cpu=10

```cluster-quota.yaml
apiVersion: quota.openshift.io/v1
kind: ClusterResourceQuota
metadata:
  name: [name]
spec:
  quota: 1
    hard:
      limits.cpu: 4
      request.cpu: 10
  selector: 2
    annotations: {}
    labels:
      matchLabels:
        key: value
```


oc get event --sort-by .metadata.creationTimestamp
