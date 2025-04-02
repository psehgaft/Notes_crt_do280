# Authentication and Authorization

## Goal
Configure authentication with the HTPasswd identity provider and assign roles to users and groups.

## Objectives
- Configure the HTPasswd identity provider for OpenShift authentication.
- Define role-based access controls and apply permissions to users.

## Sections
- Configure Identity Providers (and Guided Exercise)
- Define and Apply Permissions with RBAC (and Guided Exercise)
- Lab: Authentication and Authorization

---

## Configure Identity Providers

### Objectives
Configure the HTPasswd identity provider for OpenShift authentication.

### OpenShift Users and Groups
Several OpenShift resources relate to authentication and authorization:

- **User**: Represents an entity interacting with the API server. Permissions are assigned via roles.
- **Identity**: Stores records of authentication attempts from a specific user and provider.
- **Service Account**: Enables applications to interact with the API independently of user credentials.
- **Group**: A set of users assigned common permissions.
- **Role**: Defines API operations that users can perform on resource types.

### Authenticating API Requests
The authentication layer verifies user identities, while the authorization layer enforces permissions. OpenShift supports:
- **OAuth access tokens**
- **X.509 client certificates**

### The Authentication Operator
The OpenShift OAuth server issues tokens upon successful authentication. Identity providers validate user identities.

### Identity Providers
OpenShift supports multiple identity providers, including:
- **HTPasswd** (local authentication using stored credentials)
- **Keystone** (OpenStack authentication)
- **LDAP** (bind authentication with LDAPv3 servers)
- **GitHub** (OAuth authentication with GitHub)
- **OpenID Connect** (OIDC integration)

### Authenticating as a Cluster Administrator
Administrators can authenticate using:
- **Kubeconfig file** (contains an embedded X.509 certificate)
- **Kubeadmin virtual user** (temporary administrator credentials)

### Guided Exercise: Configuring the HTPasswd Identity Provider

#### Step 1: Create an HTPasswd File
Install `httpd-tools` and use `htpasswd` to manage users:
```sh
htpasswd -c -B -b /tmp/htpasswd student redhat123
