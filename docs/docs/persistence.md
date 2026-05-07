---
sidebar_position: 3
title: Persistence Configuration
---

# Persistence Configuration

SAM requires persistent storage for session data and artifacts. This page covers all persistence-related configuration options.

## Overview

SAM uses two types of persistent storage:

- **PostgreSQL Database**: Stores session metadata, user data, and application state
- **Object Storage (S3, Azure Blob, or GCS)**: Stores artifacts, files, and other binary data in two separate locations:
  - **Artifacts bucket/container**: Stores workflow artifacts and temporary files (fully private)
  - **Connector specs bucket/container**: Stores OpenAPI connector specification files (public read access, authenticated write only)

### Object Storage Type

The `dataStores.objectStorage.type` value selects which storage backend SAM uses. This determines which `dataStores.*` configuration block is read for credentials and settings:

| Type | Backend | Configuration Block |
|------|---------|-------------------|
| `s3` (default) | Amazon S3 or S3-compatible | `dataStores.s3` |
| `azure` | Azure Blob Storage | `dataStores.azure` |
| `gcs` | Google Cloud Storage | `dataStores.gcs` |

When bundled persistence is enabled (`global.persistence.enabled: true`), the type is always `s3` (SeaweedFS provides an S3-compatible API).

### Storage Location Details

SAM requires **two separate buckets (S3/GCS) or containers (Azure)** with different access requirements:

| Location Type | Purpose | Access Requirements | Features Enabled |
|---------------|---------|---------------------|------------------|
| **Artifacts** | Workflow artifacts, temporary files | Fully private (authenticated read/write only) | Core workflow functionality |
| **Connector Specs** | OpenAPI specification files | Public read, authenticated write | OpenAPI Connector feature for automatic REST API integrations |

**Why two locations?**
- Different lifecycle and access patterns: artifacts are temporary workflow data, while connector specs are long-lived infrastructure files
- Security isolation: agents must download connector specs at startup without authentication, but workflow artifacts must remain private
- Critical infrastructure: agents cannot start without access to connector specification files

You can choose between two persistence strategies:

| Strategy | Use Case | Components |
|----------|----------|------------|
| **Bundled Persistence** | Development, demos, POC | In-cluster PostgreSQL + SeaweedFS |
| **External Persistence** | Production deployments | Managed PostgreSQL + Object Storage (S3, Azure Blob, or GCS) |

## Option 1: Bundled Persistence (Dev/POC Only)

**Not recommended for production.** The chart can deploy single-instance PostgreSQL and SeaweedFS for quick start, demos, and proof-of-concept deployments.

The bundled SeaweedFS is automatically configured with both required buckets and appropriate security:

**Artifacts Bucket** (`{namespaceId}`):
- Fully private - authenticated read/write only
- No anonymous access
- Stores temporary workflow artifacts

**Connector Specs Bucket** (`{namespaceId}-connector-specs`):
- Authenticated write access (SAM service only)
- Anonymous/public read access (required for agents to download OpenAPI specifications)
- Stores critical infrastructure files needed for agent startup

### Basic Configuration

```yaml
global:
  persistence:
    enabled: true
    namespaceId: "my-sam-instance"  # Must be unique per SAM installation
```

:::tip Upgrading from ≤1.1.0?
If you have an existing bundled persistence deployment from chart version ≤1.1.0, a one-time migration is required. See [Bundled Persistence VCT Labels](/#bundled-persistence-vct-labels-upgrading-from-110) in the Upgrading guide.
:::

### Image Registry Configuration

By default, the bundled persistence components pull images from Docker Hub:
- PostgreSQL: `postgres:18.0`
- SeaweedFS: `chrislusf/seaweedfs:3.97`

#### Using Solace's Private GCR Registry

To avoid Docker Hub rate limits or when deploying in air-gapped environments, you can use Solace's private GCR registry. When using any of Solace's GCR registries, you must specify GCR-specific image tags:

```yaml
global:
  imageRegistry: gcr.io/gcp-maas-prod
  persistence:
    enabled: true
    namespaceId: "my-sam-instance"

samDeployment:
  imagePullSecret: "your-image-pull-secret"  # Required - see Step 2 in Getting Started

persistence-layer:
  postgresql:
    image:
      tag: "18.0-trixie"  # Required for GCR (Docker Hub default: "18.0")
  seaweedfs:
    image:
      tag: "3.97-compliant"  # Required for GCR (Docker Hub default: "3.97")
```

> **Note**: The image pull secret is required for accessing Solace's private GCR registry. See [Configure Image Pull Secret](/#step-2-configure-image-pull-secret) in the Getting Started guide.

| Component  | Docker Hub Tag | GCR Tag         |
|------------|----------------|-----------------|
| PostgreSQL | `18.0`         | `18.0-trixie`   |
| SeaweedFS  | `3.97`         | `3.97-compliant`|

#### Custom or Self-Managed Images

For advanced use cases where you need to use custom images (e.g., self-hosted registries, modified images, or air-gapped environments), you can override the full image configuration:

```yaml
persistence-layer:
  postgresql:
    image:
      registry: "my-registry.example.com"  # Custom registry (overrides global.imageRegistry)
      repository: "my-org/custom-postgres" # Custom image name (default: "postgres")
      tag: "18.0-custom"                   # Custom tag (default: "18.0")
  seaweedfs:
    image:
      registry: "my-registry.example.com"
      repository: "my-org/custom-seaweedfs" # Default: "chrislusf/seaweedfs"
      tag: "3.97-custom"                    # Default: "3.97"
```

**Image Configuration Precedence:**
1. `persistence-layer.[postgresql|seaweedfs].image.registry` (if set) takes precedence over `global.imageRegistry`
2. If neither registry is set, images pull from Docker Hub by default
3. `repository` and `tag` are always component-specific and can be overridden independently

### Storage Class Configuration

By default, the bundled persistence uses the cluster's default storage class. To specify a custom storage class:

```yaml
persistence-layer:
  postgresql:
    persistence:
      storageClassName: "gp3"  # e.g., gp3 for AWS EBS
      size: "10Gi"  # Default: 10Gi
  seaweedfs:
    persistence:
      storageClassName: "gp3"
      size: "20Gi"  # Default: 20Gi
```

### Important Caveats

1. **PVCs persist after uninstall**: When you run `helm uninstall`, the PersistentVolumeClaims (PVCs) are not automatically deleted. This is by design to prevent accidental data loss. To fully clean up:
   ```bash
   kubectl delete pvc -l app.kubernetes.io/instance=<release-name>
   ```

2. **Single instance only**: The bundled persistence deploys single-instance databases with no high availability or automatic failover.

3. **No automatic backups**: You are responsible for implementing backup strategies for the bundled databases.

4. **Docker Hub rate limits**: If not using a private registry, you may encounter Docker Hub rate limits during image pulls.

## Option 2: External Persistence (Production Recommended)

For production deployments, use managed PostgreSQL and cloud object storage services for better scalability, reliability, and separation of concerns.

When using external persistence, the bundled persistence layer is disabled by default (`global.persistence.enabled: false`).

### Database Requirements

- PostgreSQL version 17 or higher
- Admin credentials with `SUPERUSER` privileges (recommended) or at minimum `CREATEROLE` and `CREATEDB`
- SAM's init container uses admin credentials to automatically create users and databases for the application and any deployed agents

### Basic External Configuration

The example below shows the default S3 configuration. Set `dataStores.objectStorage.type` to `azure` or `gcs` to use a different backend (see [Azure](#azure-blob-storage) and [GCS](#google-cloud-storage) examples below).

```yaml
global:
  persistence:
    enabled: false  # Default, can be omitted
    namespaceId: "my-sam-instance"

dataStores:
  objectStorage:
    type: "s3"  # "s3" (default), "azure", or "gcs"
  database:
    protocol: "postgresql+psycopg2"
    host: "your-postgres-host"
    port: "5432"
    adminUsername: "your-db-admin-user"
    adminPassword: "your-db-admin-password"
    applicationPassword: "your-secure-app-password"  # REQUIRED: Password for all app database users
  s3:
    endpointUrl: "your-s3-endpoint-url"
    bucketName: "your-bucket-name"
    connectorSpecBucketName: "your-connector-specs-bucket-name"
    accessKey: "your-s3-access-key"
    secretKey: "your-s3-secret-key"
```

**Important**: The `applicationPassword` field is **required** when using external persistence. This single password will be used for all database users created by SAM (webui, orchestrator, platform, and all agents).

**Password Rotation Limitation**: Once database users are created for a given `namespaceId`, the `applicationPassword` cannot be changed. If you need to change the password, you must either use a new `namespaceId` (which creates new databases and users), or manually update the passwords directly in the database.

### Provider-Specific Examples

#### Supabase with Connection Pooler

If using Supabase with the connection pooler (required for IPv4 networks):

```yaml
dataStores:
  database:
    protocol: "postgresql+psycopg2"
    host: "aws-1-us-east-1.pooler.supabase.com"
    port: "5432"
    adminUsername: "postgres"
    adminPassword: "your-supabase-postgres-password"
    applicationPassword: "your-secure-app-password"
    supabaseTenantId: "your-project-id"  # Extract from connection string
  s3:
    endpointUrl: "https://your-project-id.storage.supabase.co/storage/v1/s3"
    bucketName: "your-bucket-name"
    connectorSpecBucketName: "your-connector-specs-bucket-name"
    accessKey: "your-supabase-s3-access-key"
    secretKey: "your-supabase-s3-secret-key"
```

**Note**: If using Supabase's Direct Connection with IPv4 addon, omit the `supabaseTenantId` field.

#### AWS RDS + S3

```yaml
dataStores:
  database:
    protocol: "postgresql+psycopg2"
    host: "mydb.abc123.us-east-1.rds.amazonaws.com"
    port: "5432"
    adminUsername: "postgres"
    adminPassword: "your-rds-password"
    applicationPassword: "your-secure-app-password"
  s3:
    endpointUrl: "https://s3.us-east-1.amazonaws.com"
    bucketName: "my-sam-artifacts"
    connectorSpecBucketName: "my-sam-connector-specs"
    accessKey: "AKIAIOSFODNN7EXAMPLE"
    secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

#### NeonDB

```yaml
dataStores:
  database:
    protocol: "postgresql+psycopg2"
    host: "ep-cool-name-123456.us-east-2.aws.neon.tech"
    port: "5432"
    adminUsername: "neondb_owner"
    adminPassword: "your-neon-password"
    applicationPassword: "your-secure-app-password"
  s3:
    # Configure your preferred S3-compatible storage
    endpointUrl: "https://s3.amazonaws.com"
    bucketName: "my-sam-artifacts"
    connectorSpecBucketName: "my-sam-connector-specs"
    accessKey: "your-access-key"
    secretKey: "your-secret-key"
```

#### Azure Blob Storage

```yaml
dataStores:
  objectStorage:
    type: "azure"
  database:
    protocol: "postgresql+psycopg2"
    host: "your-postgres-host"
    port: "5432"
    adminUsername: "postgres"
    adminPassword: "your-db-password"
    applicationPassword: "your-secure-app-password"
  azure:
    accountName: "mystorageaccount"
    accountKey: "your-azure-storage-account-key"
    containerName: "my-sam-artifacts"
    connectorSpecContainerName: "my-sam-connector-specs"
```

You can alternatively use a connection string instead of account name/key:

```yaml
  azure:
    connectionString: "DefaultEndpointsProtocol=https;AccountName=mystorageaccount;AccountKey=...;EndpointSuffix=core.windows.net"
    containerName: "my-sam-artifacts"
    connectorSpecContainerName: "my-sam-connector-specs"
```

#### Google Cloud Storage

```yaml
dataStores:
  objectStorage:
    type: "gcs"
  database:
    protocol: "postgresql+psycopg2"
    host: "your-postgres-host"
    port: "5432"
    adminUsername: "postgres"
    adminPassword: "your-db-password"
    applicationPassword: "your-secure-app-password"
  gcs:
    project: "my-gcp-project"
    credentialsJson: '{"type":"service_account","project_id":"my-gcp-project",...}'
    bucketName: "my-sam-artifacts"
    connectorSpecBucketName: "my-sam-connector-specs"
```

### Object Storage Setup by Provider

#### AWS S3 Bucket Setup and Policy Requirements

When using external AWS S3 (`objectStorage.type: "s3"`), you must create **both buckets** before deploying SAM.

**Create the buckets:**

```bash
# Create artifacts bucket (private)
aws s3 mb s3://your-bucket-name --region us-east-1

# Create connector specs bucket (will configure public read next)
aws s3 mb s3://your-connector-specs-bucket-name --region us-east-1
```

#### Connector Specs Bucket: Public Read Policy

The connector specs bucket **requires public read access** so agents can download OpenAPI specification files during startup without authentication. This is a critical security requirement that enables the OpenAPI Connector feature.

**Why public read access?**
- Agents need to download connector specification files immediately at startup
- Authentication credentials are not available to agents until after startup completes
- These files contain API schemas and endpoints but no sensitive data (credentials, keys, etc.)
- Write access remains restricted to the SAM service only (using S3 access keys)

**Security considerations:**
- **Safe to make public**: Connector specification files contain only API schemas, endpoints, and data models
- **No credentials**: Never store API keys, passwords, or secrets in connector specifications
- **Write protection**: Only the SAM service (with S3 credentials) can upload/modify files
- **Review specs before upload**: Ensure connector specs don't contain internal URLs or sensitive metadata you don't want public

**Apply public read policy:**

Save this policy as `connector-specs-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadGetObject",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::your-connector-specs-bucket-name/*"
  }]
}
```

Apply the policy:

```bash
aws s3api put-bucket-policy \
  --bucket your-connector-specs-bucket-name \
  --policy file://connector-specs-policy.json
```

#### Important Security Notes

**Artifacts bucket (private):**
- Should remain **fully private** (default AWS S3 behavior)
- No public access policy needed
- Contains workflow artifacts and temporary files
- Only accessible with S3 credentials

**Connector specs bucket (public read):**
- Needs **public read** access (anonymous GetObject)
- **Private write** access (only SAM service with credentials can upload)
- Contains OpenAPI specification files for REST API integrations
- Enables the OpenAPI Connector feature
- Replace `your-connector-specs-bucket-name` in the policy with your actual bucket name

#### Azure Blob Container Setup

When using Azure Blob Storage (`objectStorage.type: "azure"`), you must create **both containers** before deploying SAM.

**Create a storage account and containers:**

```bash
# Create storage account
az storage account create \
  --name mystorageaccount \
  --resource-group mygroup \
  --location eastus \
  --sku Standard_LRS

# Create artifacts container (private by default)
az storage container create \
  --name my-sam-artifacts \
  --account-name mystorageaccount

# Create connector specs container
az storage container create \
  --name my-sam-connector-specs \
  --account-name mystorageaccount
```

**Set public read access on the connector specs container:**

```bash
az storage container set-permission \
  --name my-sam-connector-specs \
  --account-name mystorageaccount \
  --public-access blob
```

**Assign RBAC roles** to your service principal or managed identity:

```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <principal-id> \
  --scope /subscriptions/<sub-id>/resourceGroups/mygroup/providers/Microsoft.Storage/storageAccounts/mystorageaccount
```

#### GCS Bucket Setup

When using Google Cloud Storage (`objectStorage.type: "gcs"`), you must create **both buckets** before deploying SAM.

**Create the buckets:**

```bash
# Create artifacts bucket (private by default)
gsutil mb -p my-gcp-project gs://my-sam-artifacts

# Create connector specs bucket
gsutil mb -p my-gcp-project gs://my-sam-connector-specs
```

**Set public read access on the connector specs bucket:**

```bash
gsutil iam ch allUsers:objectViewer gs://my-sam-connector-specs
```

**Grant the service account access to both buckets:**

```bash
gcloud storage buckets add-iam-policy-binding gs://my-sam-artifacts \
  --member="serviceAccount:my-sa@my-gcp-project.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

gcloud storage buckets add-iam-policy-binding gs://my-sam-connector-specs \
  --member="serviceAccount:my-sa@my-gcp-project.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

### Workload Identity

Workload identity allows SAM pods to authenticate with cloud storage using the pod's Kubernetes service account identity, eliminating the need for static credentials (access keys, account keys, or JSON key files).

When workload identity is enabled, credential fields (`accessKey`/`secretKey` for S3, `accountKey`/`connectionString` for Azure, `credentialsJson` for GCS) are omitted from Kubernetes secrets.

#### Enabling Workload Identity

```yaml
dataStores:
  objectStorage:
    type: "s3"  # or "azure" or "gcs"
    workloadIdentity:
      enabled: true
```

You must also annotate the SAM service account so your cloud provider trusts it:

```yaml
samDeployment:
  serviceAccount:
    annotations:
      # Choose the annotation for your cloud provider:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/my-sam-role"                  # AWS IRSA
      azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"  # Azure Workload Identity
      iam.gke.io/gcp-service-account: "my-sa@my-project.iam.gserviceaccount.com"  # GCP Workload Identity
```

#### Per-Provider Setup

**AWS IRSA (IAM Roles for Service Accounts):**

1. Create an IAM role with S3 permissions for both buckets
2. Associate the role with the SAM Kubernetes service account via the `eks.amazonaws.com/role-arn` annotation
3. Set `objectStorage.type: "s3"` and `workloadIdentity.enabled: true`
4. Omit `accessKey` and `secretKey` from `dataStores.s3` — the pod inherits permissions from the IAM role

**Azure Workload Identity:**

1. Create a managed identity with the `Storage Blob Data Contributor` role on the storage account
2. Establish a federated credential linking the Kubernetes service account to the managed identity
3. Annotate the service account with `azure.workload.identity/client-id`
4. Set `objectStorage.type: "azure"` and `workloadIdentity.enabled: true`
5. Provide `accountName`, `containerName`, and `connectorSpecContainerName` in `dataStores.azure` — omit `accountKey` and `connectionString`

**GCP Workload Identity:**

1. Create a GCP service account with `Storage Object Admin` on both buckets
2. Bind the Kubernetes service account to the GCP service account via IAM policy binding
3. Annotate the service account with `iam.gke.io/gcp-service-account`
4. Set `objectStorage.type: "gcs"` and `workloadIdentity.enabled: true`
5. Provide `project`, `bucketName`, and `connectorSpecBucketName` in `dataStores.gcs` — omit `credentialsJson`

#### Full Example: Azure with Workload Identity

```yaml
global:
  persistence:
    enabled: false
    namespaceId: "my-sam-instance"

dataStores:
  objectStorage:
    type: "azure"
    workloadIdentity:
      enabled: true
  database:
    protocol: "postgresql+psycopg2"
    host: "mydb.postgres.database.azure.com"
    port: "5432"
    adminUsername: "postgres"
    adminPassword: "your-db-password"
    applicationPassword: "your-secure-app-password"
  azure:
    accountName: "mystorageaccount"
    containerName: "my-sam-artifacts"
    connectorSpecContainerName: "my-sam-connector-specs"

samDeployment:
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
```

## Troubleshooting

### GCS Credentials JSON Format

**Symptoms**: GCS initialization fails with `GCS_CREDENTIALS_JSON contains invalid JSON`.

**Cause**: The `credentialsJson` value must be a raw JSON string, not base64-encoded. A common mistake is double-encoding when the Helm chart already base64-encodes secrets.

**Solution**: Provide the raw JSON service account key:
```yaml
dataStores:
  gcs:
    credentialsJson: '{"type":"service_account","project_id":"my-project",...}'
```

If using `--set-file`:
```bash
helm install ... --set-file dataStores.gcs.credentialsJson=./service-account-key.json
```

### Init Container Stuck in Pending/CrashLoopBackOff

**Symptoms**: The `agent-mesh-core` pod shows init containers waiting or failing.

**Common causes**:
1. **Image pull failures**: Check if using GCR registry without specifying GCR-specific image tags
2. **Storage class issues**: Verify the storage class exists and can provision volumes
3. **Database connectivity**: For external persistence, verify network connectivity to the database

**Debug commands**:
```bash
# Check pod status and events
kubectl describe pod -l app.kubernetes.io/name=solace-agent-mesh

# Check init container logs
kubectl logs <pod-name> -c init-db-provision

# Verify PVC status
kubectl get pvc
```

### PVC Stuck in Pending

**Symptoms**: PersistentVolumeClaims remain in `Pending` state.

**Common causes**:
1. No default storage class configured
2. Specified storage class doesn't exist
3. Storage provisioner issues

**Solution**: Specify an existing storage class explicitly:
```yaml
persistence-layer:
  postgresql:
    persistence:
      storageClassName: "your-storage-class"
```

### Docker Hub Rate Limit Errors

**Symptoms**: Image pull errors mentioning rate limits.

**Solution**: Use Solace's private GCR registry (see [Image Registry Configuration](#image-registry-configuration)).
