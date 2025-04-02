# Authentication and Authorization

## Goal
Configure authentication with the HTPasswd identity provider and assign roles to users and groups.

## Objectives
- Configure the HTPasswd identity provider for OpenShift authentication.
- Define role-based access controls and apply permissions to users.

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
htpasswd -c -B -b /tmp/htpasswd student friends123
```

#### Step 2: Create the HTPasswd Secret
```sh
oc create secret generic htpasswd-secret \  
  --from-file htpasswd=/tmp/htpasswd -n openshift-config
```

#### Step 3: Configure OAuth Custom Resource
Update the OAuth configuration to use the HTPasswd identity provider:
```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: my_htpasswd_provider
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpasswd-secret
```

#### Step 4: Update OAuth Configuration
```sh
oc get oauth cluster -o yaml > oauth.yaml
# Edit oauth.yaml to include identity provider
oc replace -f oauth.yaml
```

#### Step 5: Delete Users and Identities
```sh
htpasswd -D /tmp/htpasswd manager
oc set data secret/htpasswd-secret \  
  --from-file htpasswd=/tmp/htpasswd -n openshift-config
oc delete user manager
oc delete identity my_htpasswd_provider:manager
```

---
## Define and Apply Permissions with RBAC
### Guided Exercise: Assigning Administrative Privileges
#### Step 1: Assign cluster-admin Role
The cluster-admin role grants full cluster access:
```sh
oc adm policy add-cluster-role-to-user cluster-admin student
```
