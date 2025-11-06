---
sidebar_position: 1
slug: /
title: Getting Started
---
# Solace Agent Mesh (SAM) - Helm Chart

This Helm chart deploys Solace Agent Mesh (SAM) in enterprise mode on Kubernetes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Step 1: Add Helm Repository](#step-1-add-helm-repository)
  - [Step 2: Configure Image Pull Secret](#step-2-configure-image-pull-secret)
  - [Step 3: Prepare and update Helm values](#step-3-prepare-and-update-helm-values)
  - [Step 4: Install the Chart](#step-4-install-the-chart)
- [Accessing SAM](#accessing-sam)
  - [Network Configuration](#network-configuration)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Configuration Options](#configuration-options)
  - [Required Configuration](#required-configuration)
  - [Service Configuration](#service-configuration)
  - [Resource Limits](#resource-limits)
  - [Persistence](#persistence)
    - [Option 1: Using Built-in Persistence Layer (Dev/POC Only)](#option-1-using-built-in-persistence-layer-devpoc-only)
    - [Option 2: Using External PostgreSQL and S3 (Recommended for Production)](#option-2-using-external-postgresql-and-s3-recommended-for-production)
  - [Role-Based Access Control (RBAC)](#role-based-access-control-rbac)
    - [Understanding Roles and Permissions](#understanding-roles-and-permissions)
    - [Option 1: Updating ConfigMaps Directly (Quick Changes)](#option-1-updating-configmaps-directly-quick-changes)
    - [Option 2: Updating the Helm Chart (Persistent Changes)](#option-2-updating-the-helm-chart-persistent-changes)
    - [Common Scope Patterns](#common-scope-patterns)
    - [Verifying User Access](#verifying-user-access)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- Kubernetes cluster (1.34+)
- Helm 3.19.0+ (Download Helm from https://helm.sh/docs/intro/install/)
- kubectl configured to communicate with your cluster
- A Solace Event Broker instance
  - [Deploy on Kubernetes using Helm](https://github.com/SolaceProducts/pubsubplus-kubernetes-helm-quickstart/blob/master/docs/PubSubPlusK8SDeployment.md)
  - [Create an event broker on Solace Cloud](https://docs.solace.com/Cloud/ggs_create_first_service.htm)
- LLM service credentials (e.g., OpenAI API key)
- OIDC provider configured (for enterprise mode authentication)
- TLS certificate and key files (only for LoadBalancer/NodePort without Ingress; not needed when using Ingress with ACM/cert-manager)
- PostgreSQL database (version 17+, for production deployments with external persistence)
- S3-compatible storage (e.g., Amazon S3, for production deployments with external persistence)

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

Obtain the image pull secret from Solace Cloud following the instructions at [Download Image Pull Secret](https://docs.solace.com/Cloud/private_regions_tab.htm?Highlight=create%20a%20private%20region#Download).

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
   - OIDC authentication, external PostgreSQL + S3
   - For production deployments with managed database/storage

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
- `samDeployment.imagePullSecret`: **Required** - Name of the image pull secret created in Step 2 (e.g., `solace-image-pull-secret` or `my-registry-secret`)
- `samDeployment.image.repository`: Image repository path (if using your own registry from Step 2, Option 2)
- `samDeployment.image.tag`: SAM application image version (if using specific version)
- `samDeployment.agentDeployer.image.repository`: Agent deployer image repository path (if using your own registry from Step 2, Option 2)
- `samDeployment.agentDeployer.image.tag`: Agent deployer image version (if using specific version)

### Step 4: Install the Chart

Install using Helm with your custom values and TLS certificates:

```bash
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
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key \
  --set service.tls.passphrase="your-passphrase"
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

## Upgrading

Before upgrading, always update your Helm repository to get the latest chart versions:

```bash
helm repo update solace-agent-mesh
```

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

### Upgrading SAM Agents

To upgrade individual agents deployed through SAM, use the agent's release name and update the image tag:

**Important:** If the agent chart name has changed between versions, you may need to delete and recreate the agent deployment instead of upgrading. See [Troubleshooting](#troubleshooting) below.

```bash
# Update Helm repository first
helm repo update solace-agent-mesh

# Upgrade the agent with new image version
helm upgrade -i <agent-release-name> solace-agent-mesh/sam-agent \
  -n <namespace> \
  --reuse-values \
  --set image.tag=<new-version>
```

**Example:**
```bash
helm upgrade -i sam-agent-0a42a319-13a8-4b31-b696-9f750d5c6a20 solace-agent-mesh/sam-agent \
  -n fwanssa \
  --reuse-values \
  --set image.tag=1.14.9
```

**Verify the agent upgrade:**

```bash
kubectl get deployment <agent-release-name> -n <namespace>
kubectl logs deployment/<agent-release-name> -n <namespace> --tail=50
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

SAM requires persistent storage for session data and artifacts. You can choose between two persistence options:

#### Option 1: Using Built-in Persistence Layer (Dev/POC Only)

**⚠️ Not recommended for production.** The chart can deploy PostgreSQL and SeaweedFS for quick start, demos, and proof-of-concept deployments.

To enable built-in persistence:

```yaml
global:
  persistence:
    enabled: true  # This must be explicitly enabled
    namespaceId: "solace-agent-mesh"  # Must be unique per SAM installation
```

#### Option 2: Using External PostgreSQL and S3 (Recommended for Production)

Use your own managed PostgreSQL database and S3-compatible storage for better scalability, reliability, and separation of concerns.

**Note:** Built-in persistence is disabled by default (`global.persistence.enabled: false`), so you only need to configure your external data stores.

**Configure external database and S3 storage**

Configure your external PostgreSQL and S3 storage using the `dataStores` section in your `values.yaml`.

**Important:** The database credentials must have admin privileges (`SUPERUSER` recommended; or at minimum `CREATEROLE` and `CREATEDB`) because SAM's init container uses them to automatically create users and databases for both the main application and any agents deployed through the SAM UI.

```yaml
# Disable built-in persistence layer
global:
  persistence:
    enabled: false  # Optional (this is false by default)
    namespaceId: "solace-agent-mesh"  # Must be unique per SAM installation

# Configure external PostgreSQL and S3 for SAM application
dataStores:
  database:
    protocol: "postgresql+psycopg2"
    host: "your-postgres-host"
    port: "5432"
    adminUsername: "your-db-admin-user"  # Must have CREATEDB and CREATEROLE privileges
    adminPassword: "your-db-admin-password"
  s3:
    endpointUrl: "your-s3-endpoint-url"
    bucketName: "your-bucket-name"
    accessKey: "your-s3-access-key"
    secretKey: "your-s3-secret-key"
```

**Supabase with Connection Pooler**

If you're using Supabase with the connection pooler (required for IPv4 networks or if you haven't purchased the IPv4 addon for the Direct connection option), you'll need to provide your Supabase tenant ID. This is shown in your Supabase connection options as `postgresql://postgres.<SUPABASE_TENANT_ID>:[YOUR-PASSWORD]@...`:

```yaml
dataStores:
  database:
    protocol: "postgresql+psycopg2"
    host: "aws-1-us-east-1.pooler.supabase.com"  # Connection pooler endpoint
    port: "5432"
    adminUsername: "postgres"
    adminPassword: "your-supabase-postgres-password"
    supabaseTenantId: "your-project-id"  # Extract from Supabase connection options
  s3:
    endpointUrl: "https://your-project-id.storage.supabase.co/storage/v1/s3"
    bucketName: "your-bucket-name"
    accessKey: "your-supabase-s3-access-key"
    secretKey: "your-supabase-s3-secret-key"
```

**Note**: If you're using Supabase's Direct Connection with IPv4 addon, you do not need the `supabaseTenantId` field.

### Role-Based Access Control (RBAC)

When SAM is deployed in enterprise mode, it includes a built-in RBAC system to control user access to tools and features. The RBAC configuration is managed through Kubernetes ConfigMaps.

#### Understanding Roles and Permissions

The RBAC system consists of:
1. **Roles**: Named collections of permissions (scopes)
2. **User Assignments**: Mappings of users (by email) to roles

By default, two roles are provided:
- `sam_admin`: Full access to all features (scope: `*`)
- `sam_user`: Basic access to read artifacts and basic tools

#### Option 1: Updating ConfigMaps Directly (Quick Changes)

For quick changes to running deployments, you can edit the ConfigMaps directly:

**⚠️ Warning:** Changes made directly to ConfigMaps will be overwritten on the next Helm upgrade. To persist changes, update the Helm chart (Option 2).

**1. Edit role definitions:**

```bash
kubectl edit configmap <release-name>-role-definitions
# Example: kubectl edit configmap agent-mesh-role-definitions
```

Modify the `role-to-scope-definitions.yaml` data:

```yaml
data:
  role-to-scope-definitions.yaml: |
    roles:
      sam_admin:
        description: "Full access for SAM administrators"
        scopes:
          - "*"

      custom_role:
        description: "Your custom role"
        scopes:
          - "artifact:read"
          - "tool:custom:*"
```

**2. Edit user role assignments:**

```bash
kubectl edit configmap <release-name>-user-roles
# Example: kubectl edit configmap agent-mesh-user-roles
```

**Note:** Email addresses in user-to-role-assignments must all be lowercase. 

Modify the `user-to-role-assignments.yaml` data:

```yaml
data:
  user-to-role-assignments.yaml: |
    users:
      admin@example.com:
        roles: ["sam_admin"]
        description: "SAM Administrator"

      newuser@example.com:
        roles: ["sam_user"]
        description: "New User"
```

**3. Restart the deployment to apply changes:**

```bash
kubectl rollout restart deployment/<release-name>
# Example: kubectl rollout restart deployment/solace-agent-mesh
```

#### Option 2: Updating the Helm Chart (Persistent Changes)

To make permanent changes that survive Helm upgrades:

**1. Edit the chart template** `charts/solace-agent-mesh/templates/configmap_sam_config_files.yaml`:

Find the `sam-role-definitions` ConfigMap section (around line 340) and modify roles:

```yaml
data:
  role-to-scope-definitions.yaml: |
    roles:
      sam_admin:
        description: "Full access for SAM administrators"
        scopes:
          - "*"

      custom_role:
        description: "Your custom role"
        scopes:
          - "artifact:read"
          - "tool:specific:action"
```

Find the `sam-user-roles` ConfigMap section (around line 369) and modify user assignments:

```yaml
data:
  user-to-role-assignments.yaml: |
    users:
      admin@example.com:
        roles: ["sam_admin"]
        description: "SAM Administrator"

      user@company.com:
        roles: ["custom_role"]
        description: "Custom role user"
```

**2. Upgrade the Helm deployment:**

```bash
helm upgrade agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

**3. Verify the changes:**

```bash
kubectl get configmap <release-name>-role-definitions -o yaml
kubectl get configmap <release-name>-user-roles -o yaml
# Example: kubectl get configmap agent-mesh-role-definitions -o yaml
```

#### Common Scope Patterns

- `*` - All permissions (admin access)
- `tool:data:*` - All data-related tools
- `tool:specific:action` - Specific tool and action
- `tool:artifact:list` - List artifacts
- `tool:artifact:load` - Download artifacts
- `sam:agent_builder:create` - Create agent builders
- `sam:agent_builder:read` - Read agent builders
- `sam:agent_builder:update` - Update agent builders
- `sam:agent_builder:delete` - Delete agent builders
- `sam:connectors:create` - Create connectors
- `sam:connectors:read` - Read connectors
- `sam:connectors:update` - Update connectors
- `sam:connectors:delete` - Delete connectors
- `sam:deployments:create` - Create deployments
- `sam:deployments:read` - Read deployments
- `sam:deployments:update` - Update deployments
- `sam:deployments:delete` - Delete deployments

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
