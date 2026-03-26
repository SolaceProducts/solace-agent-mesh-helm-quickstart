---
sidebar_position: 1
slug: /
title: Getting Started
---
# Solace Agent Mesh (SAM) - Helm Chart

This Helm chart deploys Solace Agent Mesh (SAM) Enterprise on Kubernetes.

:::note Enterprise Only
This Helm chart requires the SAM Enterprise image (`solace-agent-mesh-enterprise`). Community images are not supported for Kubernetes deployments.
:::

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Step 1: Add Helm Repository](#step-1-add-helm-repository)
  - [Step 2: Configure Image Pull Secret](#step-2-configure-image-pull-secret)
  - [Step 3: Prepare and update Helm values](#step-3-prepare-and-update-helm-values)
  - [Step 4: Install the Chart](#step-4-install-the-chart)
- [Accessing SAM](#accessing-sam)
  - [Network Configuration](#network-configuration)
- [Standalone Agent and Workflow Deployment](#standalone-agent-deployment)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Configuration Options](#configuration-options)
  - [Required Configuration](#required-configuration)
  - [Service Configuration](#service-configuration)
  - [Resource Limits](#resource-limits)
  - [Persistence](#persistence)
  - [Role-Based Access Control (RBAC)](#role-based-access-control-rbac)
    - [Understanding Roles and Permissions](#understanding-roles-and-permissions)
    - [Configuring User Role Assignment](#configuring-user-role-assignment)
    - [Defining Custom Roles](#defining-custom-roles)
    - [Common Scope Patterns](#common-scope-patterns)
    - [Verifying User Access](#verifying-user-access)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- Kubernetes cluster (1.34+)
- Kubernetes nodes with sufficient disk space (minimum 30 GB recommended; see [Troubleshooting](troubleshooting#insufficient-node-disk-space) if you encounter "no space left on device" errors)
- Helm 3.19.0+ (Download from https://helm.sh/docs/intro/install/)
- kubectl configured to communicate with your cluster
- A Solace Event Broker instance
  - [Deploy on Kubernetes using Helm](https://github.com/SolaceProducts/pubsubplus-kubernetes-helm-quickstart/blob/master/docs/PubSubPlusK8SDeployment.md)
  - [Create an event broker on Solace Cloud](https://docs.solace.com/Cloud/ggs_create_first_service.htm)
- LLM service credentials (e.g., OpenAI API key)
- OIDC provider configured (for authentication)
- TLS certificate and key files (only for LoadBalancer/NodePort without Ingress; not needed when using Ingress with ACM/cert-manager)
- PostgreSQL database (version 17+, for production deployments with external persistence)
- Object storage: S3-compatible (e.g., Amazon S3, SeaweedFS), Azure Blob Storage, or Google Cloud Storage (for production deployments with external persistence)

## Installation

Before installing SAM, review the available [configuration templates](#step-3-prepare-and-update-helm-values) and customize the values according to your deployment requirements. For detailed configuration options, see the [Configuration Options](#configuration-options) section.

### Step 1: Add Helm Repository

Add the Solace Agent Mesh Helm repository:

```bash
helm repo add solace-agent-mesh https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/
helm repo update
```
Helm chart releases are accessible at: https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/tree/gh-pages

### Step 2: Configure Image Pull Secret

SAM requires access to container images. You have two options:

**Option 1: Use Solace Cloud Image Pull Secret (Recommended)**

Obtain the image pull secret from Solace Cloud following the instructions in the [Downloading Registry Credentials](https://docs.solace.com/Cloud/private_regions_tab.htm#Download) section of the Solace Cloud documentation.

Create the secret in your Kubernetes cluster:

```bash
kubectl apply -f <path-to-downloaded-secret-file>.yaml
```

**Option 2: Use Your Own Container Registry**

Download the SAM images from Solace Products, push them to your own container registry, and create an image pull secret for your registry:

```bash
kubectl create secret docker-registry my-registry-secret \
  --docker-server=<your-registry-server> \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-email=<your-email>
```

When using your own registry, you'll also need to update the image repository paths in your values file (Step 3).

### Step 3: Prepare and update Helm values

Choose one of the sample values files based on your deployment needs. Before proceeding, review the [Required Configuration](#required-configuration) section to understand what values you need to provide.

Sample values: [samples/values](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/tree/main/samples/values/)

1. **[`sam-tls-bundled-persistence-no-auth.yaml`](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/blob/main/samples/values/sam-tls-bundled-persistence-no-auth.yaml)** ⚠️ **Development Only**
   - Enterprise features enabled (agent builder), no authentication/RBAC
   - Bundled persistence (PostgreSQL + SeaweedFS)
   - For local development and testing only

2. **[`sam-tls-oidc-bundled-persistence.yaml`](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/blob/main/samples/values/sam-tls-oidc-bundled-persistence.yaml)** - **POC/Demo**
   - OIDC authentication, bundled persistence
   - For quick start, proof-of-concept, or demo environments
   - **Note**: When using bundled persistence in managed cloud providers, configure regional node pools (one per availability zone) and a default StorageClass with `volumeBindingMode: WaitForFirstConsumer` to prevent scheduling failures

3. **[`sam-tls-oidc-customer-provided-persistence.yaml`](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/blob/main/samples/values/sam-tls-oidc-customer-provided-persistence.yaml)** ⭐ **Production**
   - OIDC authentication with static user assignments, external PostgreSQL + object storage
   - For production deployments with managed database/storage

4. **[`sam-tls-oidc-idp-claim-to-role-mappings.yaml`](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/blob/main/samples/values/sam-tls-oidc-idp-claim-to-role-mappings.yaml)** ⭐ **Production with IDP Claims**
   - OIDC authentication with dynamic IDP-based role assignment, external PostgreSQL + object storage
   - For production deployments using identity provider groups/claims for role mapping
   - Recommended for enterprise deployments with centralized identity management

> **Note**: TLS certificates are only required when using `service.type: LoadBalancer` or `NodePort`. When using Ingress, TLS is managed at the Ingress level (see [Network Configuration Guide](network-configuration)).

Copy your chosen template and customize it:

```bash
cp samples/values/sam-tls-oidc-bundled-persistence.yaml custom-values.yaml
# Edit custom-values.yaml with your configuration
```

**Key values to update:**
- `sam.dnsName`: Your DNS hostname
- `sam.sessionSecretKey`: Generate a secure random string
- `sam.oauthProvider.oidc`: Your OIDC provider details
- `sam.authenticationRbac.users`: User email addresses and roles
- `broker.*`: Your Solace broker credentials
- `llmService.*`: Your LLM service credentials
- `samDeployment.imagePullSecret`: **Required** the name of the image pull secret you created in Step 2 (e.g., `solace-image-pull-secret` or `my-registry-secret`)
- `samDeployment.image.repository`: The image repository path (if you are using your own registry from Step 2, Option 2).
- `samDeployment.image.tag`: The version of the SAM application image (if you are using a specific version). 
- `samDeployment.agentDeployer.image.repository`: Agent deployer image repository path (if using your own registry from Step 2, Option 2)
- `samDeployment.agentDeployer.image.tag`: Agent deployer image version (if using specific version)

### Step 4: Install the Chart

Install using Helm with your custom values:

```bash
helm install agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml
```

**For LoadBalancer/NodePort with TLS**, provide certificates using one of these methods:

```bash
# Option 1: Reference an existing TLS secret (recommended)
helm install agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml \
  --set service.tls.existingSecret=my-tls-secret

# Option 2: Provide certificates via --set-file
helm install agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

To install a specific version (see [available releases](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/tree/gh-pages)):

```bash
# List available versions
helm search repo solace-agent-mesh/solace-agent-mesh --versions

# Install specific version
helm install agent-mesh solace-agent-mesh/solace-agent-mesh \
  --version 1.0.0 \
  -f custom-values.yaml
```

**Note**: TLS certificates are only required when using `service.type: LoadBalancer` or `NodePort`. When using Ingress, TLS is managed at the Ingress level. See the [Network Configuration Guide](network-configuration) for details.

### Step 5: Verify Deployment

Check the deployment status:

```bash
# Check Helm release status
helm status agent-mesh

# Check pod status
kubectl get pods -l app.kubernetes.io/instance=agent-mesh
```

## Accessing SAM

SAM can be accessed through LoadBalancer, NodePort, Ingress, or port-forward depending on your service configuration.

For detailed network configuration options, access methods, and production deployment recommendations, see the [Network Configuration Guide](network-configuration).

## Standalone Agent and Workflow Deployment

While SAM includes an agent-deployer microservice that dynamically deploys agents via the UI/API, you can also deploy agents independently using direct Helm commands. This approach is useful for GitOps workflows, multi-cluster deployments, or independent agent management.

For detailed instructions, see the [Standalone Agent and Workflow Deployment](standalone-agent-deployment) section.

## Upgrading

Before upgrading, always update your Helm repository to get the latest chart versions:

```bash
helm repo update solace-agent-mesh
```

### Platform Service Architecture (v1.1.0+)

Starting with v1.1.0, SAM splits platform management APIs into a separate service for improved architecture and scalability:

- **WebUI Service** (port 8000/8443): Web interface and gateway
- **Platform Service** (port 8001/4443): Platform management APIs (agents, deployments, connectors, toolsets)

**The upgrade is seamless** - no manual configuration changes required.

#### For Ingress Users

Simply run `helm upgrade` with your existing values file:

```bash
helm upgrade <release-name> solace-agent-mesh/solace-agent-mesh \
  -f your-existing-values.yaml \
  -n <namespace>
```

**What happens automatically:**
- `autoConfigurePaths: true` is enabled by default
- Platform routes (`/api/v1/platform/*`) are automatically configured
- Auth routes (`/login`, `/callback`, etc.) are automatically configured
- Your existing settings (annotations, className, TLS, etc.) are preserved
- Zero downtime - Kubernetes updates Ingress resource in-place

**Verification:**
```bash
# Check WebUI health
curl -k https://sam.example.com/health

# Check Platform API health
curl -k https://sam.example.com/api/v1/platform/health
```

#### For LoadBalancer Users

Simply run `helm upgrade` with your existing values file:

```bash
helm upgrade <release-name> solace-agent-mesh/solace-agent-mesh \
  -f your-existing-values.yaml \
  -n <namespace>
```

**What happens automatically:**
- Platform service ports (4443 HTTPS, 8080 HTTP) are added to LoadBalancer
- WebUI continues on existing ports (443 HTTPS, 80 HTTP)
- Same external IP - just additional ports exposed
- No DNS changes needed

**Access after upgrade:**

With TLS enabled:
- Web UI: `https://<EXTERNAL-IP>` (unchanged)
- Platform API: `https://<EXTERNAL-IP>:4443` (new)

Without TLS:
- Web UI: `http://<EXTERNAL-IP>` (unchanged)
- Platform API: `http://<EXTERNAL-IP>:8080` (new)

**Verification:**
```bash
# Get external IP
EXTERNAL_IP=$(kubectl get svc <release-name> -n <namespace> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Check WebUI health (port 443 or 80)
curl -k https://$EXTERNAL_IP/health

# Check Platform API health (port 4443 or 8080)
curl -k https://$EXTERNAL_IP:4443/api/v1/platform/health
```

#### For Local Development Users (Port-Forward)

If you're using `kubectl port-forward` for local development:

```bash
kubectl port-forward svc/<release-name> 8000:80 8001:8001
```

**Important:** Use port 8000 specifically - it's pre-configured in CORS allowed origins. Using other ports will cause CORS errors. See [Network Configuration - Local Development](network-configuration#local-development-with-port-forward) for details.

---

### Bundled Persistence VCT Labels (Upgrading from ≤1.1.0)

:::warning Migration Required
This section only applies if you are using **bundled persistence** (`global.persistence.enabled: true`) and upgrading from chart version ≤1.1.0. External persistence users and new installations are **not affected**.
:::

Starting with chart versions after 1.1.0, the bundled persistence layer uses minimal VolumeClaimTemplate (VCT) labels for StatefulSets. This change prevents upgrade failures when labels change over time, but requires a one-time migration for existing deployments.

**Why this matters:** Kubernetes StatefulSet VCT labels are immutable. Without migration, upgrades will fail with:
```
StatefulSet.apps "xxx-postgresql" is invalid: spec: Forbidden: updates to statefulset spec
for fields other than 'replicas', 'ordinals', 'template', 'updateStrategy'... are forbidden
```

#### Migration Procedure

**Step 1:** Delete StatefulSets while preserving data (PVCs are retained):

```bash
kubectl delete sts <release>-postgresql <release>-seaweedfs --cascade=orphan -n <namespace>
```

**Step 2:** Upgrade the Helm release:

```bash
helm upgrade <release> solace-agent-mesh/solace-agent-mesh \
  -f your-values.yaml \
  -n <namespace>
```

**Step 3:** Verify the upgrade succeeded and data is intact:

```bash
# Check pods are running
kubectl get pods -l app.kubernetes.io/instance=<release> -n <namespace>

# Verify PVCs are still bound
kubectl get pvc -l app.kubernetes.io/instance=<release> -n <namespace>
```

The new StatefulSets are created with minimal VCT labels and automatically reattach to the existing PVCs, preserving all your data.

---

### Upgrading SAM Core Deployment

To upgrade your SAM core deployment, you can reuse your existing Helm values and apply updates on top of them.

#### Option 1: Retrieve and Update Existing Values

Get your current deployment values and save them to a file:

```bash
helm get values agent-mesh -n <namespace> > current-values.yaml
```

Review and edit `current-values.yaml` to make your desired changes, then upgrade:

```bash
helm upgrade agent-mesh solace-agent-mesh/solace-agent-mesh \
  -n <namespace> \
  -f current-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

#### Option 2: Reuse Existing Values with Specific Overrides

Reuse all existing values and override specific values:

```bash
# Upgrade while reusing existing values and updating specific settings
helm upgrade agent-mesh solace-agent-mesh/solace-agent-mesh \
  -n <namespace> \
  --reuse-values \
  --set samDeployment.image.tag=new-version \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

#### Option 3: Use Your Original Values File with Updates

If you still have your original `custom-values.yaml` file, update it with any new changes and upgrade:

```bash
helm upgrade agent-mesh solace-agent-mesh/solace-agent-mesh \
  -n <namespace> \
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

**Note:** After upgrading, verify the deployment status:

```bash
kubectl rollout status deployment/agent-mesh-core -n <namespace>
kubectl get pods -n <namespace> -l app.kubernetes.io/instance=agent-mesh
```

### Upgrading SAM Agents and Workflows

To upgrade an individual agent or workflow deployed using SAM, use its release name and update its image tag:

**Important:** If the agent or workflow chart name has changed between versions, you may need to delete and recreate the agent deployment instead of upgrading. See [Troubleshooting](#troubleshooting) below.

```bash
# Update Helm repository first
helm repo update solace-agent-mesh

# Upgrade the agent or workflow with new image version
helm upgrade -i <agent or workflow-release-name> solace-agent-mesh/sam-agent \
  -n <namespace> \
  --reuse-values \
  --set image.tag=<new-version>
```

**Example:**
```bash
helm upgrade -i sam-agent-0a42a319-13a8-4b31-b696-9f750d5c6a20 solace-agent-mesh/sam-agent \
  -n fwanssa \
  --reuse-values \
  --set image.tag=1.83.1
```

**Verify the agent or workflow upgrade:**

```bash
kubectl get deployment <agent or workflow-release-name> -n <namespace>
kubectl logs deployment/<agent or workflow-release-name> -n <namespace> --tail=50
```

## Uninstalling

To uninstall the chart:

```bash
helm uninstall agent-mesh
```

Note: This will not delete PersistentVolumeClaims when using bundled persistence. To delete them:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=agent-mesh
```

## Configuration Options

### Required Configuration

Before deploying SAM, you must configure the following required values in your `values.yaml` or custom values file:

1. **SAM Configuration** (`sam` section):
   - `dnsName`: DNS-resolvable hostname for SAM web UI/API (e.g., `sam.example.com`)
   - `sessionSecretKey`: Secret key for session management

2. **Solace Broker Configuration** (`broker` section):
   - `url`: WebSocket Secure URL to your broker (e.g., `wss://mr2zq0g0f1.messaging.solace.cloud:443`)
   - `clientUsername`: Broker username
   - `password`: Broker password
   - `vpn`: VPN name

3. **LLM Service Configuration** (`llmService` section):
   - `planningModel`, `generalModel`, `reportModel`, `imageModel`, `transcriptionModel`: Model names
   - `llmServiceEndpoint`: LLM service API endpoint (e.g., `https://api.openai.com/v1`)
   - `llmServiceApiKey`: API key for LLM service

### Service Configuration

SAM supports multiple exposure methods. The default is ClusterIP with Ingress for production use:

```yaml
service:
  type: ClusterIP  # or LoadBalancer, NodePort
  annotations: {}
  tls:
    enabled: false  # Set to true for LoadBalancer/NodePort without Ingress
    passphrase: ""

ingress:
  enabled: false  # Set to true for production deployments
  className: "alb"  # or "nginx", "traefik", etc.
```

**For detailed configuration options and examples, see the [Network Configuration Guide](network-configuration).**

### Resource Limits

Adjust resource requests and limits based on your workload:

```yaml
samDeployment:
  resources:
    sam:
      requests:
        cpu: 1000m
        memory: 1024Mi
      limits:
        cpu: 2000m
        memory: 2048Mi
    agentDeployer:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 200m
        memory: 512Mi
```

### Persistence

SAM requires persistent storage for session data and artifacts. You can choose between:

- **Bundled Persistence** (Dev/POC): In-cluster PostgreSQL and SeaweedFS
- **External Persistence** (Production): Managed PostgreSQL and object storage (S3, Azure Blob, or GCS)

For detailed configuration options, image registry settings, and provider-specific examples, see the [Persistence Configuration](persistence) documentation.

**Quick Start (Bundled Persistence):**

```yaml
global:
  persistence:
    enabled: true
    namespaceId: "solace-agent-mesh"  # Must be unique per SAM installation
```

### Role-Based Access Control (RBAC)

SAM includes a built-in RBAC system to control user access to tools and features. The RBAC configuration is managed through Kubernetes ConfigMaps.

#### Understanding Roles and Permissions

The RBAC system consists of:
1. **Roles**: Named collections of permissions (scopes)
2. **User Assignments**: Choose ONE method:
   - **Dynamic assignments**: Automatic role mapping from IDP claims (OIDC groups/roles)
   - **Static assignments**: Direct mapping of users (by email) to roles in Helm values


By default, two roles are provided:
- `sam_admin`: Full access to all features (scope: `*`)
- `sam_user`: Basic access to read artifacts and basic tools

See [Defining Custom Roles](#defining-custom-roles) for information on creating custom roles.

#### Configuring User Role Assignment

You must choose **ONE** of the following methods for assigning roles to users:

##### Method 1: Dynamic Role Assignment (IDP Claims) - Recommended

This method automatically assigns roles based on OIDC claims (groups, roles, etc.) from your identity provider. Users are dynamically assigned roles when they log in based on their IDP group memberships.

**Configure in your values.yaml:**

```yaml
sam:
  oauthProvider:
    oidc:
      issuer: "oidc-issuer-url-here" # e.g., https://accounts.google.com
      clientId: "oidc-client-id-here" # e.g., your-client-id
      clientSecret: "oidc-client-secret-here" # e.g., your-client-secret

  authenticationRbac:
    # Define custom roles (optional)
    customRoles:
      data_engineer:
        description: "Data engineering team with access to data tools"
        scopes:
          - "artifact:*"
          - "tool:data:*"
          - "sam:connectors:read"

    # Static user assignments (leave empty when using idpClaims)
    users: []

    # Dynamic role assignment from IDP claims
    idpClaims:
      enabled: true
      oidcProvider: "oidc"  # e.g., "azure", "google", "okta"
      claimKey: "groups"      # e.g., "groups", "roles", "custom_claim"
      # Map IDP claim values to SAM roles (built-in or custom)
      mappings:
        "admin-group": ["sam_admin"]
        "engineering-team": ["sam_user"]
        "data-analysts": ["data_engineer"]  # Example using custom role

    # Default roles (applies to both static and IDP claims methods)
    # - For IDP claims: assigned when user's claims don't match any mappings
    # - For static assignments: assigned to authenticated users not explicitly listed in 'users'
    defaultRoles:
      - "sam_user"
```

**Key fields:**
- `enabled`: Set to `true` to enable dynamic role assignment
- `oidcProvider`: Name of your OIDC provider (e.g., "azure", "google", "okta")
- `claimKey`: The OIDC claim field containing group/role information (commonly "groups" or "roles")
- `mappings`: Map IDP group names to SAM roles (one group can map to multiple roles)
- `defaultRoles`: (Top-level under `authenticationRbac`) Roles assigned when users don't have explicit role assignments

##### Method 2: Static User Assignment

This method requires manually listing each user and their assigned roles in the Helm values. Use this for small teams or when dynamic assignment is not available.

**Configure in your values.yaml:**

```yaml
sam:
  authenticationRbac:
    # Define custom roles (optional)
    customRoles:
      data_engineer:
        description: "Data engineering team with access to data tools"
        scopes:
          - "artifact:*"
          - "tool:data:*"
          - "sam:connectors:read"

    # Static user assignments
    users:
      - identity: "admin@example.com"
        roles: ["sam_admin"]
        description: "SAM Administrator Account"
      - identity: "user1@example.com"
        roles: ["sam_user"]
        description: "Standard SAM User"
      - identity: "engineer@example.com"
        roles: ["data_engineer"]  # Example using custom role
        description: "Data Engineer"

    # Dynamic role assignment (disabled when using static assignments)
    idpClaims:
      enabled: false

    # Default roles (optional for static assignments)
    # Assigned to authenticated users not explicitly listed in 'users'
    defaultRoles:
      - "data_engineer"
```

**Note:** Email addresses must be lowercase.

#### Defining Custom Roles

SAM comes with two built-in roles (`sam_admin` and `sam_user`), which are sufficient for most deployments. However, if you need custom roles with specific permissions tailored to your organization's needs, you can define them in your Helm values.

**Define custom roles in your values.yaml:**

```yaml
sam:
  authenticationRbac:
    # Define custom roles (in addition to built-in sam_admin and sam_user)
    customRoles:
      data_engineer:
        description: "Data engineering team with access to data tools and connectors"
        scopes:
          - "artifact:read"
          - "artifact:write"
          - "tool:data:*"
          - "sam:connectors:read"
          - "sam:connectors:create"

      viewer:
        description: "Read-only access to deployments and connectors"
        scopes:
          - "artifact:read"
          - "sam:deployments:read"
          - "sam:connectors:read"

      power_user:
        description: "Advanced user with broader tool access"
        scopes:
          - "artifact:*"
          - "tool:*"
          - "sam:agent_builder:read"
          - "sam:connectors:*"
          - "sam:deployments:read"
```

**Use custom roles in user assignments:**

Once you've defined custom roles, you can assign them to users using either static or dynamic assignment:

*Option 1: Static assignment:*
```yaml
sam:
  authenticationRbac:
    customRoles:
      data_engineer:
        description: "Data engineering role"
        scopes:
          - "artifact:*"
          - "tool:data:*"
      viewer:
        description: "Read-only role"
        scopes:
          - "artifact:read"

    users:
      - identity: "admin@example.com"
        roles: ["sam_admin"]
        description: "Administrator"
      - identity: "engineer@example.com"
        roles: ["data_engineer"]
        description: "Data Engineer"
      - identity: "analyst@example.com"
        roles: ["viewer"]
        description: "Read-only analyst"
```

*Option 2: Dynamic IDP assignment:*
```yaml
sam:
  authenticationRbac:
    customRoles:
      data_engineer:
        description: "Data engineering role"
        scopes:
          - "artifact:*"
          - "tool:data:*"
      viewer:
        description: "Read-only role"
        scopes:
          - "artifact:read"

    users: []

    idpClaims:
      enabled: true
      oidcProvider: "azure"
      claimKey: "groups"
      mappings:
        "sam-admins": ["sam_admin"]
        "data-engineering-team": ["data_engineer"]
        "analysts": ["viewer"]

    defaultRoles: ["viewer"]
```

**Apply the changes:**

```bash
helm upgrade agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

**Verify the custom roles:**

```bash
# Check that custom roles are defined
kubectl get configmap <release-name>-role-definitions -o yaml

# Example: kubectl get configmap agent-mesh-role-definitions -o yaml
```

You should see your custom roles listed alongside the built-in `sam_admin` and `sam_user` roles.

#### Common Scope Patterns

SAM uses a scope-based permission system. Here are the common scope patterns and their meanings:

**Built-in Role Scopes:**

The `sam_user` role includes these basic scopes:
- `agent:*:delegate` - Delegate tasks to any agent
- `tool:basic:read` - Read basic tool information
- `tool:basic:search` - Search using basic tools
- `tool:artifact:list` - List artifacts
- `tool:artifact:load` - Download/load artifacts

The `sam_admin` role includes:
- `*` - All permissions (full admin access)

**Tool-Related Scopes:**

- `tool:artifact:*` - All artifact operations
- `tool:artifact:list` - List artifacts
- `tool:artifact:load` - Download artifacts
- `tool:artifact:write` - Create/upload artifacts
- `tool:data:*` - All data analysis tools
- `tool:basic:*` - All basic tools

**Agent Operations:**

- `agent:*:delegate` - Delegate tasks to all agents
- `agent:specific_agent:delegate` - Delegate to a specific agent

**Platform Management Scopes:**

- `sam:agent_builder:create` - Create agent builders
- `sam:agent_builder:read` - Read/view agent builders
- `sam:agent_builder:update` - Update agent builders
- `sam:agent_builder:delete` - Delete agent builders
- `sam:agent_builder:*` - All agent builder operations

**Connector Management:**

- `sam:connectors:create` - Create connectors
- `sam:connectors:read` - Read/view connectors
- `sam:connectors:update` - Update connectors
- `sam:connectors:delete` - Delete connectors
- `sam:connectors:*` - All connector operations

**Deployment Management:**

- `sam:deployments:create` - Create deployments
- `sam:deployments:read` - Read/view deployments
- `sam:deployments:update` - Update deployments
- `sam:deployments:delete` - Delete deployments
- `sam:deployments:*` - All deployment operations

**Wildcard Patterns:**

- `*` - All permissions
- `tool:*` - All tools
- `tool:data:*` - All data tools
- `sam:*` - All SAM platform operations
- `artifact:*` - All artifact operations

#### Verifying User Access

After updating RBAC configuration:

1. **Check pod logs** to verify configuration loaded:
```bash
kubectl logs -l app.kubernetes.io/instance=agent-mesh --tail=50
```

2. **Test user access** by logging in as different users through the SAM web UI

3. **Review ConfigMaps** to confirm changes:
```bash
kubectl describe configmap <release-name>-role-definitions
kubectl describe configmap <release-name>-user-roles
# Example: kubectl describe configmap agent-mesh-role-definitions
```

For more details on RBAC configuration, see the [SAM RBAC Setup Guide](http://solacelabs.github.io/solace-agent-mesh/docs/documentation/enterprise/rbac-setup-guide).

## Troubleshooting

For troubleshooting common issues with SAM deployments, see the [Troubleshooting Guide](troubleshooting).

For issues, questions, or contributions, please open an issue in [GitHub Issues](https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/issues).
