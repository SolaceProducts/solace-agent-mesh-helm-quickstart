# Solace Agent Mesh (SAM) - Helm Chart

This Helm chart deploys Solace Agent Mesh (SAM) in enterprise mode on Kubernetes.
> :warning: This Helm chart is **not ready yet** for production use.
> We are actively developing and testing this chart. Expect breaking changes and incomplete functionality.
> Please check back later or follow the repository for updates.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Step 1: Add Helm Repository](#step-1-add-helm-repository)
  - [Step 2: Prepare and update Helm values](#step-2-prepare-and-update-helm-values)
  - [Step 3: Install the Chart](#step-3-install-the-chart)
- [Accessing SAM](#accessing-sam)
  - [Network Configuration](#network-configuration)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Configuration Options](#configuration-options)
  - [Required Configuration](#required-configuration)
  - [Service Configuration](#service-configuration)
  - [Resource Limits](#resource-limits)
  - [Persistence](#persistence)
    - [Option 1: Using Built-in Persistence Layer](#option-1-using-built-in-persistence-layer)
    - [Option 2: Using External PostgreSQL and S3 (Recommended for Production)](#option-2-using-external-postgresql-and-s3-recommended-for-production)
  - [Role-Based Access Control (RBAC)](#role-based-access-control-rbac)
    - [Understanding Roles and Permissions](#understanding-roles-and-permissions)
    - [Option 1: Updating ConfigMaps Directly (Quick Changes)](#option-1-updating-configmaps-directly-quick-changes)
    - [Option 2: Updating the Helm Chart (Persistent Changes)](#option-2-updating-the-helm-chart-persistent-changes)
    - [Common Scope Patterns](#common-scope-patterns)
    - [Verifying User Access](#verifying-user-access)
  - [Disabling Authentication (Development Only)](#disabling-authentication-development-only)
- [Troubleshooting](#troubleshooting)
  - [Check Pod Status](#check-pod-status)
  - [View Pod Logs](#view-pod-logs)
  - [Check ConfigMaps](#check-configmaps)
  - [Check Secrets](#check-secrets)
  - [Verify Service](#verify-service)
  - [Common Issues](#common-issues)
- [Support](#support)
- [Version](#version)
- [Maintainers](#maintainers)

## Prerequisites

- Kubernetes cluster (1.34+)
- Helm 3.0+ (Download Helm from https://helm.sh/docs/intro/install/)
- kubectl configured to communicate with your cluster
- A Solace Event Broker instance
- LLM service credentials (e.g., OpenAI API key)
- OIDC provider configured (for enterprise mode authentication)
- TLS certificate and key files (publicly trusted or signed by trusted CA)
- PostgreSQL database (version 18+, for production deployments with external persistence)
- S3-Compatible Storage Services (Amazon S3)

## Installation

Before installing SAM, review the available [configuration templates](#step-2-choose-a-configuration-template) and customize the values according to your deployment requirements. For detailed configuration options, see the [Configuration Options](#configuration-options) section.

### Step 1: Add Helm Repository

Add the Solace Agent Mesh Helm repository:

```bash
helm repo add solace-agent-mesh https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/
helm repo update
```

### Step 2: Prepare and update Helm values
 
Choose one of the sample values files based on your deployment needs. Before proceeding, review the [Required Configuration](#required-configuration) section to understand what values you need to provide.

Sample values:https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/tree/main/samples/values

1. **`samples/values/sam-tls-oidc-bundled-persistence.yaml`** ⚠️ **Not Recommended for Production**
   - **Use Case**: Quick start or demo deployment with OIDC authentication
   - **Features**: TLS enabled, OIDC authentication, bundled PostgreSQL + SeaweedFS for session and artifact persistence
   - **Best For**: Getting started quickly, proof-of-concept, or demo environments
   - **Note**: While this provides full persistence for sessions and artifacts, the bundled database and storage are not suitable for production workloads

2. **`samples/values/sam-tls-oidc-customer-provided-persistence.yaml`** ⭐ **Recommended for Production**
   - **Use Case**: Production deployment with your own managed database and S3 storage
   - **Features**: TLS enabled, OIDC authentication, external PostgreSQL + S3 for session and artifact persistence
   - **Best For**: Enterprise deployments with existing database/storage infrastructure

3. **`samples/values/sam-tls-bundled-persistence-no-auth.yaml`** ⚠️ **Development Only**
   - **Use Case**: Development/testing environment
   - **Features**: TLS enabled, no authentication, bundled PostgreSQL + SeaweedFS for session and artifact persistence
   - **Best For**: Local development and testing
   - **Note**: Not recommended for production use due to disabled authentication

4. **TLS Configuration** (`service.tls` section):
   - TLS certificate file (e.g., `tls.crt`) - only if using LoadBalancer/NodePort
   - TLS key file (e.g., `tls.key`)
   - Optional passphrase if key is encrypted
   - **Note**: When using Ingress, TLS is managed at the Ingress level (see [Network Configuration Guide](docs/NETWORK_CONFIGURATION.md))
> **Note**: For production deployments, we strongly recommend using `sam-tls-oidc-customer-provided-persistence.yaml` with your own managed PostgreSQL and S3-compatible storage services. This provides better scalability, reliability, and separation of concerns compared to bundled persistence services.

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
- `samDeployment.image.tag`: SAM application image version (if using specific version)
- `samDeployment.agentDeployer.image.tag`: Agent deployer image version (if using specific version)
- `samDeployment.imagePullSecret`: Image pull secret name (if using private registry)

### Step 3: Install the Chart

Install using Helm with your custom values and TLS certificates:

```bash
helm install agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

To install a specific version:

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

**Note**: TLS certificates are only required when using `service.type: LoadBalancer` or `NodePort`. When using Ingress, TLS is managed at the Ingress level. See the [Network Configuration Guide](docs/NETWORK_CONFIGURATION.md) for details.

### Step 3: Verify Deployment

Check the deployment status:

```bash
helm install agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key \
  --set service.tls.passphrase="your-passphrase"
```

## Accessing SAM

SAM can be accessed through different methods depending on your deployment configuration.

### Network Configuration

**For detailed network configuration options, see the [Network Configuration Guide](docs/NETWORK_CONFIGURATION.md).**

**Quick access methods:**

#### Using LoadBalancer (default)
```bash
# Get external IP/hostname
kubectl get svc agent-mesh-solace-agent-mesh -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Configure DNS to point to this address
# Access at: https://<your-hostname>
```

#### Using Ingress (recommended for production)
```bash
# Check ingress status
kubectl get ingress agent-mesh-solace-agent-mesh

# Access at the configured hostname (e.g., https://sam.example.com)
```

#### Using Port-Forward (development)
```bash
# Forward port to local machine
kubectl port-forward svc/agent-mesh-solace-agent-mesh 8443:443

# Access at: https://localhost:8443
```

For production deployments, we recommend using **Ingress with ALB/NGINX** for cost-effective and feature-rich HTTP routing. See the [Network Configuration Guide](docs/NETWORK_CONFIGURATION.md) for complete setup instructions.

## Upgrading

To upgrade the deployment with new values:

```bash
helm upgrade agent-mesh solace-agent-mesh/solace-agent-mesh \
  -f custom-values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

## Uninstalling

To uninstall the chart:

```bash
helm uninstall agent-mesh
```

Note: This will not delete PersistentVolumeClaims. To delete them:

```bash
kubectl delete pvc -l app=solace-agent-mesh
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

4. **TLS Configuration** (`service.tls` section):
   - TLS certificate file (e.g., `tls.crt`)
   - TLS key file (e.g., `tls.key`)
   - Optional passphrase if key is encrypted

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

**For detailed configuration options and examples, see the [Network Configuration Guide](docs/NETWORK_CONFIGURATION.md).**

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

#### Option 1: Using Built-in Persistence Layer

The chart can deploy PostgreSQL and SeaweedFS for persistence. This is suitable for quick start, demos, and proof-of-concept deployments.

**⚠️ Not recommended for production use.** For production deployments, use Option 2 with managed database and storage services.

To enable built-in persistence:

```yaml
global:
  persistence:
    enabled: true
    namespaceId: "solace-agent-mesh" # Must be unique per SAM installation
```

This will automatically deploy PostgreSQL and SeaweedFS as part of the Helm chart installation.

#### Option 2: Using External PostgreSQL and S3 (Recommended for Production)

For production deployments, use your own managed PostgreSQL database and S3-compatible storage. This provides better scalability, reliability, and separation of concerns.

This configuration applies to both the main SAM deployment and any agents deployed through the SAM UI.

**Step 1: Disable the built-in persistence layer**

```yaml
global:
  persistence:
    enabled: false
```

**Step 2: Configure external database and S3 storage**

Configure your external PostgreSQL and S3 storage using the `dataStores` section in your `values.yaml`.

**Important:** The database credentials must have admin privileges (CREATEDB and CREATEROLE) because SAM's init container uses them to automatically create database protocol and users for both the main application and any agents deployed through the SAM UI.

```yaml
# Disable built-in persistence layer
global:
  persistence:
    enabled: false

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

**How Agent Database Creation Works:**

When you deploy an agent through the SAM UI:
1. The agent chart uses service discovery to find secrets labeled with the matching `namespaceId` (see `charts/solace-agent-mesh-agent/templates/_helpers.tpl:75-121`)
2. The agent chart's init container (see `charts/solace-agent-mesh-agent/templates/deployment.yaml:34-51`) automatically:
   - Discovers the PostgreSQL secret and reads admin credentials
   - Connects to PostgreSQL using the admin credentials
   - Creates a new database for the agent (e.g., `<namespaceId>_<agentId>_agent`)
   - Creates a dedicated database user with the same naming pattern
   - Grants appropriate permissions
3. The agent container uses the created database credentials

**Important:** The agent chart relies on Kubernetes secret discovery with specific labels. Ensure:
- Secrets have the correct `app.kubernetes.io/namespace-id` label matching your `global.persistence.namespaceId`
- Secrets have the correct `app.kubernetes.io/service` label (`postgresql` or `seaweedfs`)
- Secrets are in the same namespace where agents will be deployed

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

**Note:** User identifiers can be an email address, username, name. They are **case-sensitive**, so ensure exact matches with your OIDC provider's user identifiers.

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

**Note:** Changes made directly to ConfigMaps will be overwritten on the next Helm upgrade. To persist changes, update the Helm chart (Option 2).

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
kubectl logs -l app.kubernetes.io/name=solace-agent-mesh --tail=50
```

2. **Test user access** by logging in as different users through the SAM web UI

3. **Review ConfigMaps** to confirm changes:
```bash
kubectl describe configmap <release-name>-role-definitions
kubectl describe configmap <release-name>-user-roles
# Example: kubectl describe configmap agent-mesh-role-definitions
```

For more details on RBAC configuration, see the [SAM RBAC Setup Guide](http://solacelabs.github.io/solace-agent-mesh/docs/documentation/enterprise/rbac-setup-guide).

### Disabling Authentication (Development Only)

**⚠️ Warning:** Disabling authentication is only suitable for development and testing environments. Never use this in production.

For development environments, you can disable authentication by setting the `issuer` to an empty string:

```yaml
sam:
  enterprise: true
  dnsName: "sam.example.com"
  sessionSecretKey: "your-secret-key"
  oauthProvider:
    oidc:
      issuer: ""  # Leave empty to disable OIDC authentication
      clientId: ""
      clientSecret: ""
```

When the `issuer` is empty, SAM will run without authentication.

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/name=solace-agent-mesh
```

### View Pod Logs

```bash
kubectl logs -l app.kubernetes.io/name=solace-agent-mesh --tail=100 -f
```

### Check ConfigMaps

```bash
kubectl get configmaps -l app.kubernetes.io/name=solace-agent-mesh
```

### Check Secrets

```bash
kubectl get secrets -l app.kubernetes.io/name=solace-agent-mesh
```

### Verify Service

```bash
kubectl get service -l app.kubernetes.io/name=solace-agent-mesh
```

### Common Issues

**Pod fails to start:**
- Check that the image is accessible
- Verify resource limits are sufficient
- Review pod events: `kubectl describe pod <pod-name>`

**Cannot connect to Solace broker:**
- Verify `solaceBroker.url` is correct and reachable
- Check credentials in `solaceBroker.username` and `solaceBroker.password`
- Ensure the VPN name is correct

**TLS issues:**
- Verify certificate and key are properly formatted
- Check certificate expiration
- Ensure certificate matches the hostname

**Database connection issues:**
- Verify database URLs are correct
- Check database credentials
- Ensure databases exist and are accessible from the cluster

## Support

For issues, questions, or contributions:
- Email: info@solace.com
- Website: https://solace.cloud

## Version

**Chart Version**: 0.0.3

## Maintainers

- Solace PubSub+ Cloud (info@solace.com)
