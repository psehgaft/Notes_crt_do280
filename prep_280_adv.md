# Notes_crt_do280

## Users Authentications

Add users and httpasswd identity

```sh
dnf isntall -y httpd-tools

htpasswd -b -B -c htpassd.users user password

htpasswd -b -B htpassd.users user password
```

## Remove taint from OpenShift Container Platform - Node

```sh
oc adm taint nodes node key=vvalue:NoSchedule
```

```sh
oc adm taint nodes node1 key1:NoSchedule-
```

Add a toleration to a dc by editing the Pod spec to include a tolerations stanza:

```sh
spec:
  tolerations:
  - key: "key1"
    operator: "Equal"
    value: "value1"
    effect: "NoSchedule"
  - key: "key1"
    operator: "Equal"
    value: "value1"
    effect: "NoExecute"
```

## Secrets

Add secret to dc

```sh
name: test
namespace: ""
runtime: go
...
envs:
- name: EXAMPLE
  value: '{{ secret:mysecret:key }}'
```

## Service account

```sh
oc create sa managers

oc policy add-role-to-group edit system:serviceaccounts:managers -n my-project

oc policy add-role-to-group default system:serviceaccounts:managers -n my-project

```

## Controlling Pod Scheduling

### Labeling Nodes

```oc
oc label node node1.us-west-1.compute.internal env=dev
```

Excercice

- Login 

```oc
oc login -u [user] -t [tocken] https://[URL]:6443 [https://console-openshift-console.apps.fiserv.openshift.training]

```

# Upgrade Cluster to a newer Channel #

Downgrading is not supported! So be very careful if you decide to do this!

Test your changes first

`oc patch clusterversion/version --type merge --patch '{"spec":{"channel":"stable-4.7"}}' --dry-run=client -o json | jq .spec.channel`

```
oc patch clusterversion version --type="merge" -p '{"spec":{"channel":"stable-4.6"}}'

oc adm upgrade

oc adm upgrade --to-latest=true
```
