# Notes_crt_do280

## Comands


== Login

oc login -u kubeadmin -p ${PASS} https://api.ocp4.training.com:6443

 oc whoami -t
 

== Cluster management

oc get clusterversion
oc describe clusterversion

oc get clusteroperators
oc get co

== logs

oc adm node-logs -u crio my-node-name
oc adm node-logs -u kubelet my-node-name
oc adm node-logs my-node-name

 oc logs my-pod-name
 oc logs my-pod-name -c my-container-name 

 oc get pod --loglevel 6

oc get pod --loglevel 10

== Node management

oc debug node/my-node-name

oc get nodes

oc adm top node

oc describe node my-node-name

== Deployment management

oc debug deployment/my-deployment-name --as-root

== Registry

oc get pod -n openshift-image-registry

== Sotorage

oc set volumes deployment/example-application --add --name example-storage --type pvc --claim-class nfs-storage --claim-mode rwo --claim-size 15Gi --mount-path /var/lib/example-app --claim-name example-storage

oc set volumes deployment/postgresql-persistent --add --name postgresql-storage --type pvc --claim-class nfs-storage --claim-mode rwo --claim-size 10Gi --mount-path /var/lib/pgsql --claim-name postgresql-storage

oc set volumes deployment/postgresql-persistent2 --add --name postgresql-storage --type pvc --claim-name postgresql-storage --mount-path /var/lib/pgsql

== users

 oc delete secret kubeadmin -n kube-system

 oc get oauth cluster -o yaml > oauth.yaml

 oc replace -f oauth.yaml




## Openshift Container Platform Features

Native SO RHCoreOS

- OpenShift runs exclusively the CRI-O container engine.
- Some nodes are control plane nodes that run the REST API, the etcd database, and the platform controllers. 

Openshift requieres CRUI-O container engine

OCP pvides OAuth server autenticates REST API

Nodes:

- Control Plane
- Workers / Nodes / Compute nodes


Node (Control Plane)
-- Kube-apiserver 
---- opeshift-apiserver
------ openshift-0 auth


-- kube-controler-manager
---- opesnhift-controller-manager

-- kube-scheduler
---- coredns

-- etcd
-- kubelet
-- cri-o

## Openshift Architecture

´´´

  . Print the supported API resources
  oc api-resources

  . Print the supported API resources with more information
  oc api-resources -o wide

  . Print the supported API resources sorted by a column
  oc api-resources --sort-by=name

  . Print the supported namespaced resources
  oc api-resources --namespaced=true

  . Print the supported non-namespaced resources
  oc api-resources --namespaced=false

  . Print the supported API resources with a specific APIGroup
  oc api-resources --api-group=extensions

´´´

## Cluster Operators

network

ingress

storage

authentication

console

monitoring

image-registry

cluster-autoscaler

openshift-apiserver

dns

openshift-controller-manager

cloud-credential

- Operator SDK: An open source toolkit for building, testing, and packaging operators.

- Operator Catalog: A repository for discovering and installing operators.

- Custom Resource Definition: An extension of the Kubernetes API that defines the syntax of a custom resource.

- Operator Image: The artifact defined by the Operator Framework that you can publish for consumption by an OLM instance.

- Operator: An application that manages Kubernetes resources.

- Operator Lifecycle Manager (OLM): An application that manages Kubernetes operators.

- OperatorHub: 	Operator Lifecycle Manager (OLM)
A public web service where you can publish operators that are compatible with the OLM.

- Red Hat Marketplace: Platform that allows access to certified software packaged as Kubernetes operators that can be deployed in an OpenShift cluster.


### API Commands

oc status

"1. DO280: Describing the Red Hat OpenShift Container Platform
- OpenShift Container Platform Features
- OpenShift Architecture
- Cluster Operators"

"API [ oc commands ]
Web Console
- Administrator view
- Developer View
- Openshift projects [namespaces]
- Operators"


## Summary
In this chapter, you learned:

Red Hat OpenShift Container Platform is based on Red Hat Enterprise Linux CoreOS, the CRI-O container engine, and Kubernetes.

RHOCP 4 provides services on top of Kubernetes, such as an internal container image registry, storage, networking providers, and centralized logging and monitoring.

Operators package applications that manage Kubernetes resources, and the Operator Lifecycle Manager (OLM) handles installation and management of operators.

OperatorHub.io is an online catalog for discovering operators.



##################################################

# Configuring Authentication and Authorization

Deleting the Virtual User
After you define an identity provider, create a new user, and assign that user the cluster-admin role, you can remove the kubeadmin user credentials to improve cluster security.

```oc
oc delete secret kubeadmin -n kube-system
```

- Configuring Identity Providers

For configure


```oc
oc get oauth cluster -o yaml > Configuring_Identity_Providers/HTPasswd identity_old.yml
```

Modify and then

```oc

oc replace -f Configuring_Identity_Providers/HTPasswd identity.yml

```
Create the htpasswd file.



- Defining and Applying Permissions using RBAC

# Configuring Application Security
- Managing Sensitive Information with Secrets
- Controlling Application Permissions with Security Context Constraints


Excercice

- Login 

```oc
oc login -u [user] -t [tocken] https://[URL]:6443 [https://console-openshift-console.apps.fiserv.openshift.training]

```

- Create the ocp-curriculim-schedule-authorization project

```oc
oc new-project ocp-curriculim-schedule-authorization
```

- Create a secret named ocp-secret.

```oc
oc create secret generic ocp-secret --from-literal user=wpuser --from-literal password=redhat123 --from-literal database=wordpress
```

or

-TODO--


- Create a new application to deploy a *ocp-schedule-mysql* database server.

```oc
oc new-app --name ocp-schedule-mysql --docker-image registry.redhat.io/rhel8/mysql-80:1
```

- The --prefix option ensures that all the variables injected from the secret into the pod start with MYSQL_.

```oc
oc set env dc/ocp-schedule-mysql --prefix MYSQL_ --from secret/ocp-secret
```

- Verify that the ocp-schedule-mysql pod redeploys successfully.

```oc
watch oc get pods
```

- Deploy a *ocp-schedule-wordpress* application.

```oc
oc new-app --name ocp-schedule-wordpress --docker-image quay.io/redhattraining/wordpress:5.7-php7.4-apache -e WORDPRESS_DB_HOST=mysql -e WORDPRESS_DB_NAME=wordpress -e WORDPRESS_TITLE=auth-review -e WORDPRESS_USER=wpuser -e WORDPRESS_PASSWORD=redhat123 -e WORDPRESS_EMAIL=operator@ocpschecule.com -e WORDPRESS_URL=wordpress-review.apps.fiserv.openshift.training/
```

- The --prefix option ensures that the variables injected from the secret into the pod all start with WORDPRESS_DB_.

```oc
oc set env dc/ocp-schedule-wordpress --prefix WORDPRESS_DB_ --from secret/ocp-secret

watch oc get pods -l deployment=ocp-schedule-wordpress
```

- Check whether using a different SCC resolves the permissions problem.

```oc
oc get pod/wordpress-[pod-id] -o yaml | oc adm policy scc-subject-review -f -
```

- Create a service account named wordpress-sa

```oc
oc create serviceaccount wordpress-sa
```

- Grant the anyuid SCC 

```oc
oc adm policy add-scc-to-user anyuid -z wordpress-sa
```

- Configure the wordpress deployment to use the wordpress-sa service account

```oc
oc set sa dc/ocp-schedule-wordpress wordpress-sa
```

- Use the oc expose command to create a route to the wordpress application


```oc
oc expose service/ocp-schedule-wordpress  --hostname wordpress-review.apps.fiserv.openshift.training
```

### References: 
https://docs.openshift.com/container-platform/4.10/cli_reference/openshift_cli/getting-started-cli.html
