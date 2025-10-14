# Solace Agent Mesh Helm Chart

A Helm chart for deploying Solace Agent Mesh with integrated persistence layer in Kubernetes environments, specifically designed for Solace Cloud deployments.

## Overview

Solace Agent Mesh is an orchestration platform that enables AI agents to communicate and collaborate through event-driven messaging. This Helm chart simplifies the deployment and configuration of Solace Agent Mesh in Kubernetes, including automatic setup of PostgreSQL database and SeaweedFS S3-compatible object storage.

## Architecture

The deployment consists of:
- **SAM Container**: Main Solace Agent Mesh application with Web UI and orchestrator
- **Agent Deployer Container**: Sidecar container for managing agent deployments
- **Persistence Layer** (subchart):
  - PostgreSQL database for Web UI and Orchestrator sessions
  - SeaweedFS for S3-compatible object storage
- **Init Containers**: Automatic initialization of databases and S3 buckets

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Access to Solace Agent Mesh and Agent Deployer container images
- Sufficient cluster resources for persistence layer

## Installation

### Prerequisites Checklist

Before installing, ensure you have:

1. **Required Images**:
   - Solace Agent Mesh container image
   - Agent Deployer container image (for enterprise edition)
   - Access credentials if using private registries

2. **Solace Broker**:
   - Solace PubSub+ broker URL (cloud or on-premises)
   - Valid credentials (username, password, VPN name)

3. **LLM Service**:
   - LLM service endpoint URL
   - API key for authentication

4. **Kubernetes Cluster**:
   - Sufficient resources for SAM and optional persistence layer
   - StorageClass configured if using persistence layer

### Basic Installation (Community Edition)

Install SAM without persistence layer and enterprise features:

```bash
helm install solace-agent-mesh ./charts/solace-agent-mesh \
  --set persistence-layer.enabled=false \
  --set image.repository=your-registry/solace-agent-mesh \
  --set image.tag=v1.0.0 \
  --set agentDeployer.image.repository=your-registry/agent-deployer \
  --set agentDeployer.image.tag=v1.0.0 \
  --set sam.hostname=sam.example.com \
  --set solaceBroker.url=wss://your-broker.solace.cloud:443 \
  --set solaceBroker.vpn=your-vpn \
  --set solaceBroker.username=your-username \
  --set solaceBroker.password=your-password \
  --set llm.llmServiceEndpoint=https://api.openai.com/v1 \
  --set llm.llmServiceApiKey=sk-your-api-key
```

### Installation with Persistence Layer

Install SAM with integrated PostgreSQL and SeaweedFS for SQL-based sessions and S3 storage:

```bash
helm install solace-agent-mesh ./charts/solace-agent-mesh \
  --set global.persistence.namespaceId=my-namespace \
  --set image.repository=your-registry/solace-agent-mesh \
  --set image.tag=v1.0.0 \
  --set agentDeployer.image.repository=your-registry/agent-deployer \
  --set agentDeployer.image.tag=v1.0.0 \
  --set sam.hostname=sam.example.com \
  --set solaceBroker.url=wss://your-broker.solace.cloud:443 \
  --set solaceBroker.vpn=your-vpn \
  --set solaceBroker.username=your-username \
  --set solaceBroker.password=your-password \
  --set llm.llmServiceEndpoint=https://api.openai.com/v1 \
  --set llm.llmServiceApiKey=sk-your-api-key \
  --set persistence-layer.postgresql.password=secure-postgres-password
```

### Installation with Enterprise Edition

Install SAM with enterprise features (OAuth2 server, agent deployer):

```bash
helm install solace-agent-mesh ./charts/solace-agent-mesh \
  --set global.persistence.namespaceId=my-namespace \
  --set image.repository=your-registry/solace-agent-mesh \
  --set image.tag=v1.0.0 \
  --set agentDeployer.image.repository=your-registry/agent-deployer \
  --set agentDeployer.image.tag=v1.0.0 \
  --set sam.enterprise=true \
  --set sam.hostname=sam.example.com \
  --set solaceBroker.url=wss://your-broker.solace.cloud:443 \
  --set solaceBroker.vpn=your-vpn \
  --set solaceBroker.username=your-username \
  --set solaceBroker.password=your-password \
  --set llm.llmServiceEndpoint=https://api.openai.com/v1 \
  --set llm.llmServiceApiKey=sk-your-api-key \
  --set persistence-layer.postgresql.password=secure-postgres-password
```

### Installation from Values File

Create a custom values file (`my-values.yaml`) and install:

```bash
helm install solace-agent-mesh ./charts/solace-agent-mesh -f my-values.yaml
```

### Installing with TLS Certificates

To enable TLS with custom certificates:

```bash
# Encode your certificate and key
CERT_B64=$(cat tls.crt | base64)
KEY_B64=$(cat tls.key | base64)

helm install solace-agent-mesh ./charts/solace-agent-mesh \
  -f my-values.yaml \
  --set tls.enabled=true \
  --set tls.cert="$CERT_B64" \
  --set tls.key="$KEY_B64"
```

Or in your values file:

```yaml
tls:
  enabled: true
  cert: |
    LS0tLS1CRUdJTi... (base64 encoded)
  key: |
    LS0tLS1CRUdJTi... (base64 encoded)
```

## Upgrading

### Basic Upgrade

Update your deployment with new values:

```bash
helm upgrade solace-agent-mesh ./charts/solace-agent-mesh \
  -f my-values.yaml
```

### Upgrade with New Image Version

```bash
helm upgrade solace-agent-mesh ./charts/solace-agent-mesh \
  --reuse-values \
  --set image.tag=v1.1.0 \
  --set agentDeployer.image.tag=v1.1.0
```

### Upgrade to Enterprise Edition

To upgrade from community to enterprise edition:

```bash
helm upgrade solace-agent-mesh ./charts/solace-agent-mesh \
  -f my-values.yaml \
  --set sam.enterprise=true
```

### Upgrade with Persistence Layer

To add persistence layer to an existing deployment:

```bash
helm upgrade solace-agent-mesh ./charts/solace-agent-mesh \
  -f my-values.yaml \
  --set persistence-layer.enabled=true \
  --set global.persistence.namespaceId=my-namespace \
  --set persistence-layer.postgresql.password=secure-password
```

**Note**: Adding persistence layer requires a restart and will cause brief downtime.

### Verify Upgrade

```bash
# Check deployment status
kubectl rollout status deployment/solace-agent-mesh

# View running pods
kubectl get pods -l app.kubernetes.io/name=solace-agent-mesh

# Check logs
kubectl logs -l app.kubernetes.io/name=solace-agent-mesh -c sam --tail=50
```

## Uninstallation

### Standard Uninstall

```bash
helm uninstall solace-agent-mesh
```

### Uninstall with Persistence Cleanup

If you want to also remove persistent data:

```bash
# Uninstall the chart
helm uninstall solace-agent-mesh

# Remove PVCs (if persistence layer was enabled)
kubectl delete pvc -l app.kubernetes.io/instance=solace-agent-mesh
```

## Configuration

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.persistence.namespaceId` | Namespace ID for persistence layer (used for S3 bucket and database names) | `""` (required) |
| `global.imageRegistry` | Global image registry prefix for all images | `""` |

**Note**: `global.persistence.namespaceId` is required and used to generate consistent S3 bucket names, access keys, and database credentials.

### Core Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas to deploy | `1` |
| `image.repository` | Container image repository | `solace/solace-agent-mesh` |
| `image.tag` | Container image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `image.imagePullSecrets` | Image pull secrets | `[]` |

### Agent Deployer Configuration

The agent deployer runs as a sidecar container to manage agent deployments:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `agentDeployer.image.repository` | Agent deployer image repository | `""` (required) |
| `agentDeployer.image.tag` | Agent deployer image tag | `""` (required) |
| `agentDeployer.image.pullPolicy` | Image pull policy | `Always` |

### Agent and Service Configuration

Configure built-in agents and services through the `config` section:

```yaml
config:
  agents:
    - name: web_request
      enabled: true
    - name: global
      enabled: true
    - name: image_processing
      enabled: false
    - name: slack
      enabled: false

  services:
    - name: embedding
      enabled: false
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.agents` | List of built-in agents and their enabled state | See values.yaml |
| `config.services` | List of built-in services and their enabled state | See values.yaml |

### Directory Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.configDirectory` | Configuration directory path | `configs` |
| `config.modulesDirectory` | Modules directory path | `modules` |
| `config.overwriteDirectory` | Overwrite directory path | `overwrite` |
| `config.envFile` | Environment file name | `.env` |

### Build Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.build.buildDirectory` | Build output directory | `build` |
| `config.build.extractEnvVars` | Extract environment variables | `true` |
| `config.build.logLevelOverride` | Override log level | `INFO` |
| `config.build.orchestratorInstanceCount` | Number of orchestrator instances | `5` |

### Runtime Configuration

#### File Service Configuration

The file service handles temporary file storage with multiple backend options:

```yaml
config:
  runtime:
    fileService:
      type: volume  # Options: volume, bucket, customModule
      maxTimeToLive: 86400  # 24 hours in seconds
      expirationCheckInterval: 600  # 10 minutes in seconds
```

**Volume Storage (Default):**
```yaml
      volume:
        directory: /tmp/solace-agent-mesh
```

**S3/Cloud Storage:**
```yaml
      type: bucket
      bucket:
        bucketName: "my-bucket"
        endpointUrl: "https://s3.amazonaws.com"
        boto3Config:
          regionName: "us-east-1"
          awsAccessKeyId: "your-access-key"
          awsSecretAccessKey: "your-secret-key"
```

**Custom Module:**
```yaml
      type: customModule
      customModule:
        modulePath: "path.to.module"
        config: {}
```

### SAM (Solace Agent Mesh) Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sam.enterprise` | Enable enterprise features (includes OAuth2 server) | `false` |
| `sam.hostname` | Hostname for the SAM instance | `""` |
| `sam.webUiPort` | Web UI port | `""` |
| `sam.callbackUrl` | Callback URL for webhooks | `""` |
| `sam.idpUrl` | Identity provider URL | `""` |
| `sam.tlsCertPath` | Path to TLS certificate | `""` |
| `sam.tlsKeyPath` | Path to TLS private key | `""` |
| `sam.tlsPassphrase` | TLS passphrase (if encrypted) | `""` |

**Note**: This chart automatically configures SQL-based session storage using the integrated persistence layer. Sessions are stored in PostgreSQL databases that are automatically created by init containers.

### LLM Configuration

Configure the Language Model settings:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `llm.planningModel` | Model to use for planning | `openai/claude-3-7-sonnet` |
| `llm.embeddingModel` | Model to use for embeddings | `openai/claude-3-7-sonnet` |
| `llm.llmServiceEndpoint` | LLM service endpoint URL | `https://llm.endpoint.com` |
| `llm.llmServiceApiKey` | API key for LLM service | `llm-service-api-key` |

### Solace Broker Configuration

Configure connection to Solace PubSub+ broker:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `solaceBroker.url` | WebSocket Secure URL for Solace broker | `wss://localhost:8443` |
| `solaceBroker.vpn` | Message VPN name | `default` |
| `solaceBroker.username` | Broker username | `admin` |
| `solaceBroker.password` | Broker password | `admin` |

Example for Solace Cloud:
```yaml
solaceBroker:
  url: wss://your-broker.messaging.solace.cloud:443
  vpn: your-vpn-name
  username: your-username
  password: your-password
```

### TLS Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tls.enabled` | Enable TLS for the Web UI | `true` |
| `tls.cert` | TLS certificate content (base64 encoded) | `""` |
| `tls.key` | TLS private key content (base64 encoded) | `""` |

To provide your own TLS certificate:
```yaml
tls:
  enabled: true
  cert: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
```

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `service.port` | Service port | `5001` |
| `service.annotations` | Service annotations | `{}` |
| `service.dns.enabled` | Enable DNS configuration | `false` |
| `service.dns.hostname` | DNS hostname | `""` |
| `service.dns.ttl` | DNS TTL | `"300"` |

### Resource Configuration

Configure CPU and memory resources:

```yaml
resources:
  sam:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 200m
      memory: 768Mi
```

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.name` | Name of the service account | `solace-agent-mesh-sa` |
| `podSecurityContext.fsGroup` | FSGroup for pod | `10002` |
| `podSecurityContext.runAsUser` | User ID to run container | `10001` |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |

### Deployment Strategy

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rollout.strategy` | Deployment strategy | `Recreate` (options: `Recreate`, `RollingUpdate`) |
| `rollout.rollingUpdate` | Rolling update configuration | `{}` |

For rolling updates:
```yaml
rollout:
  strategy: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### Additional Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `environmentVariables` | Additional environment variables | `[]` |
| `nodeSelector` | Node selector for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `annotations` | Deployment annotations | `{}` |
| `podAnnotations` | Pod annotations | `{}` |
| `podLabels` | Pod labels | `{}` |

Example environment variables:
```yaml
environmentVariables:
  - name: CUSTOM_VAR
    value: "custom-value"
  - name: ANOTHER_VAR
    value: "another-value"
```

### Datadog Integration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `datadog.tags` | Datadog tags for monitoring | `{}` |

### Persistence Layer Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence-layer.enabled` | Install integrated persistence layer (PostgreSQL + SeaweedFS) | `true` |
| `persistence-layer.postgresql.password` | PostgreSQL admin password | `postgres` |

**⚠️ Use at Your Own Risk**: The integrated persistence layer is provided for convenience and development purposes. For production deployments, we recommend using managed database and storage services for better reliability, scalability, and support.

## Configuration Guides

### Configuring LLM Settings

SAM supports multiple LLM providers. Configure the LLM service by setting the endpoint and API key:

**OpenAI Configuration:**
```yaml
llm:
  planningModel: openai/gpt-4
  embeddingModel: openai/text-embedding-3-small
  llmServiceEndpoint: https://api.openai.com/v1
  llmServiceApiKey: sk-your-openai-api-key
```

**Anthropic Claude Configuration:**
```yaml
llm:
  planningModel: anthropic/claude-3-sonnet
  embeddingModel: openai/text-embedding-3-small  # Use OpenAI for embeddings
  llmServiceEndpoint: https://api.anthropic.com
  llmServiceApiKey: sk-ant-your-anthropic-api-key
```

**Custom LLM Service:**
```yaml
llm:
  planningModel: custom/your-model
  embeddingModel: custom/your-embedding-model
  llmServiceEndpoint: https://your-llm-service.example.com
  llmServiceApiKey: your-api-key
```

### Configuring Solace Broker Connection

SAM requires a Solace PubSub+ broker for event-driven messaging between agents.

**Solace Cloud Configuration:**
```yaml
solaceBroker:
  url: wss://mr-connection-xxxyyyzzz.messaging.solace.cloud:443
  vpn: your-vpn-name
  username: solace-cloud-client
  password: your-secure-password
```

**On-Premises Solace Broker:**
```yaml
solaceBroker:
  url: wss://your-broker.example.com:8443
  vpn: default
  username: admin
  password: admin-password
```

**Multiple Broker Setup (High Availability):**
```yaml
solaceBroker:
  url: wss://broker1.example.com:8443,wss://broker2.example.com:8443
  vpn: ha-vpn
  username: ha-user
  password: ha-password
```

### Enabling Enterprise Edition

Enterprise edition includes OAuth2 server and agent deployer capabilities.

**Step 1: Enable Enterprise Mode**
```yaml
sam:
  enterprise: true
```

**Step 2: Configure Agent Deployer Image**
```yaml
agentDeployer:
  image:
    repository: your-registry/agent-deployer
    tag: v1.0.0
    pullPolicy: IfNotPresent
```

**Step 3: Allocate Resources for Agent Deployer**
```yaml
resources:
  agentDeployer:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

**Complete Enterprise Configuration Example:**
```yaml
sam:
  enterprise: true
  hostname: sam-enterprise.example.com

agentDeployer:
  image:
    repository: your-registry/agent-deployer
    tag: v1.0.0

resources:
  sam:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 4Gi
  agentDeployer:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

### Enabling TLS/HTTPS

TLS is enabled by default. To use custom certificates:

**Option 1: Provide Certificate Files**

```bash
# Create base64 encoded values
CERT_B64=$(cat your-certificate.crt | base64)
KEY_B64=$(cat your-private-key.key | base64)

# Install with TLS
helm install solace-agent-mesh ./charts/solace-agent-mesh \
  -f values.yaml \
  --set tls.enabled=true \
  --set tls.cert="$CERT_B64" \
  --set tls.key="$KEY_B64"
```

**Option 2: Configure in Values File**

```yaml
tls:
  enabled: true
  cert: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKZ... (your certificate)
    -----END CERTIFICATE-----
  key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w... (your private key)
    -----END PRIVATE KEY-----
```

**Option 3: Use Cert-Manager**

If using cert-manager for certificate management:

```yaml
tls:
  enabled: true
  # Leave cert and key empty - cert-manager will populate them

annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```

**Disabling TLS (Not Recommended for Production):**

```yaml
tls:
  enabled: false

service:
  port: 8000  # HTTP port
```

### Enabling OIDC Authentication (Enterprise Only)

OIDC authentication is available with enterprise edition.

**Step 1: Enable Enterprise Mode**
```yaml
sam:
  enterprise: true
```

**Step 2: Configure Identity Provider**
```yaml
sam:
  idpUrl: https://your-identity-provider.example.com
  callbackUrl: https://sam.example.com/callback
```

**Step 3: Configure OAuth2 Settings via ConfigMaps**

The chart automatically creates OAuth2 configuration when enterprise mode is enabled. For custom OIDC providers, you may need to create additional configuration:

```yaml
environmentVariables:
  - name: OIDC_CLIENT_ID
    value: your-client-id
  - name: OIDC_CLIENT_SECRET
    value: your-client-secret
  - name: OIDC_ISSUER_URL
    value: https://your-oidc-provider.com
  - name: OIDC_REDIRECT_URI
    value: https://sam.example.com/callback
```

**Example with Okta:**
```yaml
sam:
  enterprise: true
  idpUrl: https://your-domain.okta.com
  callbackUrl: https://sam.example.com/oauth2/callback

environmentVariables:
  - name: OIDC_CLIENT_ID
    value: 0oa1234567890abcdef
  - name: OIDC_CLIENT_SECRET
    value: your-okta-client-secret
  - name: OIDC_ISSUER_URL
    value: https://your-domain.okta.com/oauth2/default
```

**Example with Auth0:**
```yaml
sam:
  enterprise: true
  idpUrl: https://your-tenant.auth0.com
  callbackUrl: https://sam.example.com/callback

environmentVariables:
  - name: OIDC_CLIENT_ID
    value: your-auth0-client-id
  - name: OIDC_CLIENT_SECRET
    value: your-auth0-client-secret
  - name: OIDC_ISSUER_URL
    value: https://your-tenant.auth0.com/
```

### Configuring Persistence Layer

The persistence layer provides PostgreSQL for session storage and SeaweedFS for S3-compatible object storage.

**Enable Persistence Layer (Default):**
```yaml
persistence-layer.enabled: true

global:
  persistence:
    namespaceId: production-namespace  # Used for database/bucket naming

persistence-layer:
  postgresql:
    password: secure-postgres-password
```

**Disable Persistence Layer:**
```yaml
persistence-layer.enabled: false
# SAM will use in-memory sessions (not recommended for production)
```

**Custom Persistence Configuration:**
```yaml
persistence-layer.enabled: true

global:
  persistence:
    namespaceId: my-app

persistence-layer:
  postgresql:
    password: my-secure-password
    # Additional PostgreSQL configuration can be added here
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 2Gi

  seaweedfs:
    # SeaweedFS configuration
    resources:
      master:
        requests:
          cpu: 200m
          memory: 512Mi
      volume:
        requests:
          cpu: 200m
          memory: 512Mi
```

**Important Notes:**
- `global.persistence.namespaceId` is required when persistence layer is enabled
- Init containers automatically create databases and S3 buckets
- Database names format: `{namespaceId}_webui` and `{namespaceId}_orchestrator`
- S3 bucket name: `{namespaceId}`

**⚠️ Production Warning**: For production deployments, consider using managed services:
- Amazon RDS / Azure Database / Google Cloud SQL for PostgreSQL
- Amazon S3 / Azure Blob Storage / Google Cloud Storage instead of SeaweedFS

### Adding and Deploying Custom Agents

SAM supports deploying custom agents alongside built-in agents.

**Step 1: Enable Built-in Agents**
```yaml
config:
  agents:
    - name: web_request
      enabled: true
    - name: global
      enabled: true
    - name: image_processing
      enabled: true
    - name: slack
      enabled: true

  services:
    - name: embedding
      enabled: true
```

**Step 2: Add Custom Agent via Environment Variables**

Custom agents can be deployed by providing additional configuration:

```yaml
environmentVariables:
  - name: CUSTOM_AGENT_ENABLED
    value: "true"
  - name: CUSTOM_AGENT_NAME
    value: "my_custom_agent"
  - name: CUSTOM_AGENT_CONFIG
    value: |
      {
        "name": "my_custom_agent",
        "type": "custom",
        "endpoint": "https://my-agent-service:8080"
      }
```

**Step 3: Deploy Agent Containers (Enterprise)**

With enterprise edition, the agent-deployer sidecar manages agent deployments:

```yaml
sam:
  enterprise: true

agentDeployer:
  image:
    repository: your-registry/agent-deployer
    tag: v1.0.0

# Agent deployer will automatically discover and deploy agents
# based on configuration in the orchestrator
```

**Step 4: Configure Agent Resources**

Adjust orchestrator instance count for more agents:

```yaml
config:
  build:
    orchestratorInstanceCount: 10  # Support more concurrent agents
```

**Example: Deploying Slack Agent**
```yaml
config:
  agents:
    - name: slack
      enabled: true

environmentVariables:
  - name: SLACK_BOT_TOKEN
    value: xoxb-your-slack-bot-token
  - name: SLACK_APP_TOKEN
    value: xapp-your-slack-app-token
  - name: SLACK_SIGNING_SECRET
    value: your-signing-secret
```

**Example: Deploying Custom Python Agent**
```yaml
config:
  agents:
    - name: custom_python_agent
      enabled: true

environmentVariables:
  - name: CUSTOM_AGENT_PYTHON_PATH
    value: /app/custom_agents/my_agent.py
  - name: CUSTOM_AGENT_PYTHON_CLASS
    value: MyCustomAgent
```

**Agent Configuration Best Practices:**
- Use environment variables for sensitive data (API keys, tokens)
- Enable only the agents you need to reduce resource usage
- Monitor agent resource consumption and adjust `orchestratorInstanceCount`
- Use enterprise edition with agent-deployer for dynamic agent scaling

## Example Configurations

### Minimal Production Configuration

```yaml
replicaCount: 2

image:
  tag: "v1.0.0"
  pullPolicy: IfNotPresent

sam:
  hostname: agent-mesh.example.com
  namespace: production
  sessionType: sql
  webUIDatabaseUrl: postgresql+psycopg2://user:pass@postgres.example.com:5432/webui
  orchestratorDatabaseUrl: postgresql+psycopg2://user:pass@postgres.example.com:5432/orchestrator

solaceBroker:
  url: wss://prod-broker.messaging.solace.cloud:443
  vpn: production-vpn
  username: prod-user
  password: secure-password

llm:
  planningModel: openai/gpt-4
  embeddingModel: openai/text-embedding-3-small
  llmServiceEndpoint: https://api.openai.com/v1
  llmServiceApiKey: sk-your-api-key

tls:
  enabled: true
  cert: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----

service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb

resources:
  sam:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
```

### Development Configuration

```yaml
replicaCount: 1

sam:
  devMode: true
  hostname: localhost
  sessionType: memory

solaceBroker:
  url: ws://localhost:8008
  vpn: default
  username: admin
  password: admin

tls:
  enabled: false

service:
  type: NodePort

resources:
  sam:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### High Availability Configuration

```yaml
replicaCount: 3

rollout:
  strategy: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0

config:
  build:
    orchestratorInstanceCount: 10

resources:
  sam:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 4Gi

nodeSelector:
  node-role: agent-mesh

tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "agent-mesh"
    effect: "NoSchedule"
```

## Exposed Ports

The deployment exposes the following container ports:

- **8443**: Web UI with TLS (HTTPS)
- **8000**: Web UI without TLS (HTTP)
- **5050**: Authentication service

## Health Checks

The deployment includes readiness and liveness probes:

- **Initial Delay**: 30 seconds
- **Period**: 10 seconds
- **Failure Threshold**: 10 consecutive failures (200 seconds total)
- **Success Threshold**: 1 successful check

Both probes check the root path (`/`) of the Web UI on the appropriate port based on TLS configuration.

## Volumes

The deployment uses the following volumes:

1. **shared-storage**: EmptyDir volume mounted at `/tmp/solace-agent-mesh` for temporary file storage
2. **tls-certs**: Secret volume mounted at `/app/certs` containing TLS certificates
3. **config-volume**: Projected volume mounted at `/app/config` containing ConfigMaps for orchestrator and Web UI

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