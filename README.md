# Notes_crt_do280

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

```oc
oc new-project ocp-curriculim-schedule

```

### References: 
https://docs.openshift.com/container-platform/4.10/cli_reference/openshift_cli/getting-started-cli.html