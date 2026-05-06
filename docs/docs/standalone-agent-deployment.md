---
sidebar_position: 4
title: Agent and Workflow Deployment
---

# Agent and Workflow Deployment Guide

This guide explains how to deploy Solace Agent Mesh agents and workflows directly, without using the `agent-deployer` microservice.

:::note
Workflows and agents are deployed in the same way. A workflow usually involves multiple agents, which can be loaded either into a single pod or across multiple pods. As with agents, you must properly configure any supporting services such as artifacts, persistent storage, LLMs, event brokers, and namespaces.
:::

## Overview

There are two ways to deploy SAM agents and workflows:

1. **Via Agent Deployer** (Default): The SAM platform includes an agent-deployer microservice that dynamically deploys agents via the UI/API (only available for agents)
2. **Standalone Deployment** (This Guide): Deploy agents and workflows directly using `helm install` commands

Standalone deployment itself supports two modes:

| Mode | Best for | Persistence config |
|------|----------|-------------------|
| **Deployer** | Quickstart environments where a SAM platform is already running | Auto-discovered from existing quickstart secrets via Kubernetes labels |
| **Standalone** | Isolated deployments, separate databases, or GitOps pipelines | Explicitly provided in the values file |

## When to Use Standalone Deployment

Use standalone deployment when you want to deploy agents or workflows independently of the main SAM platform, need direct control over agent or workflow deployment and lifecycle, want to manage agents or workflows using GitOps workflows, or are deploying agents or workflows in different clusters or namespaces.

## Prerequisites

Before deploying a standalone agent or workflow, you need a Kubernetes cluster with kubectl access, Helm 3.19.0+ installed, a Solace Event Broker with connection URL and credentials, and an LLM service API endpoint and credentials (e.g., OpenAI). You also need a PostgreSQL database (version 17+) for state management and object storage (S3, Azure Blob, or GCS) for file handling---though in deployer mode these are auto-discovered from the existing quickstart installation.

## Deployer Mode

Deployer mode is the simplest way to deploy a standalone agent or workflow alongside an existing SAM quickstart installation. The chart auto-discovers the quickstart's PostgreSQL and object storage secrets via Kubernetes labels, so you do not need to configure persistence manually.

### Step 1: Prepare Agent or Workflow Configuration File

Create a configuration file that defines your agent or workflow. This file is passed to Helm via `--set-file config.yaml=`. All `${...}` variables are resolved at runtime from environment variables that the chart injects.

Example agent configuration:

```yaml
log:
  stdout_log_level: INFO
  log_file_level: DEBUG
  log_file: my-agent.log

shared_config:
  - broker_connection: &broker_connection
      dev_mode: ${SOLACE_DEV_MODE, false}
      broker_url: ${SOLACE_BROKER_URL, ws://localhost:8080}
      broker_username: ${SOLACE_BROKER_USERNAME, default}
      broker_password: ${SOLACE_BROKER_PASSWORD, default}
      broker_vpn: ${SOLACE_BROKER_VPN, default}
      temporary_queue: ${USE_TEMPORARY_QUEUES, true}

  - models:
    general: &general_model
      model: ${LLM_SERVICE_GENERAL_MODEL_NAME}
      api_base: ${LLM_SERVICE_ENDPOINT}
      api_key: ${LLM_SERVICE_API_KEY}

  - services:
    session_service: &default_session_service
      type: "memory"
      default_behavior: "PERSISTENT"

    artifact_service: &default_artifact_service
      type: "memory"

apps:
  - name: my-agent-app
    app_base_path: .
    app_module: solace_agent_mesh.agent.sac.app
    broker:
      <<: *broker_connection

    app_config:
      namespace: ${NAMESPACE}
      supports_streaming: true
      agent_name: "MyAgent"
      display_name: "My Agent"
      model: *general_model
      model_provider:
        - "general"

      instruction: |
        You are a helpful agent.

      tools:
        - tool_type: python
          component_module: my_agent.tools
          function_name: my_tool

      session_service: *default_session_service
      artifact_service: *default_artifact_service

      agent_card:
        description: "My custom agent"
        defaultInputModes: ["text"]
        defaultOutputModes: ["text"]
        skills:
          - id: "my_tool"
            name: "My Tool"
            description: "Does something useful"

      agent_card_publishing: { interval_seconds: 10 }
      agent_discovery: { enabled: false }
      inter_agent_communication:
        allow_list: []
        request_timeout_seconds: 30
```

Example workflow structure:

```yaml
apps:
  - name: my_workflow
    app_module: solace_agent_mesh.workflow.app
    broker:
      # ... broker configuration

    app_config:
      namespace: ${NAMESPACE}
      agent_name: "MyWorkflow"

      workflow:
        description: "Process incoming orders"
        version: "1.0.0"

        input_schema:
          type: object
          properties:
            order_id:
              type: string
          required: [order_id]

        nodes:
          - id: validate_order
            type: agent
            agent_name: "OrderValidator"
            input:
              order_id: "{{workflow.input.order_id}}"

          - id: process_payment
            type: agent
            agent_name: "PaymentProcessor"
            depends_on: [validate_order]
            input:
              order_data: "{{validate_order.output}}"

        output_mapping:
          status: "{{process_payment.output.status}}"
          confirmation: "{{process_payment.output.confirmation_number}}"
```

### Step 2: Extract Config from Quickstart

Dump the environment variables from your existing quickstart secret to retrieve the broker and LLM configuration:

```bash
kubectl get secret <quickstart-release>-environment -n <namespace> -o json | \
  python3 -c "import sys,json,base64; d=json.load(sys.stdin)['data']; [print(f'{k}: {base64.b64decode(v).decode()}') for k,v in sorted(d.items())]"
```

You need these values: `NAMESPACE`, `SOLACE_BROKER_URL`, `SOLACE_BROKER_USERNAME`, `SOLACE_BROKER_PASSWORD`, `SOLACE_BROKER_VPN`, `LLM_SERVICE_GENERAL_MODEL_NAME`, `LLM_SERVICE_ENDPOINT`, and `LLM_SERVICE_API_KEY`.

### Step 3: Prepare Values File

Create a values file with deployer mode enabled. The chart will auto-discover the quickstart's PostgreSQL and object storage secrets:

```yaml
deploymentMode: deployer
component: agent
id: "my-agent"

image:
  repository: <your-registry>/solace-agent-mesh-enterprise
  tag: "<your-version>"
  pullPolicy: Always

global:
  persistence:
    namespaceId: "<your-namespace-id>"
    imageRegistry: "<your-registry>"

solaceBroker:
  url: "<your-broker-url>"
  username: "<your-broker-username>"
  password: "<your-broker-password>"
  vpn: "<your-broker-vpn>"
  useTemporaryQueues: false

llmService:
  generalModelName: "<your-model>"
  endpoint: "<your-llm-endpoint>"
  apiKey: "<your-llm-api-key>"

environmentVariables:
  NAMESPACE: "<your-namespace-id>"

resources:
  sam:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

:::warning
The `NAMESPACE` environment variable is the SAM logical namespace (e.g., `solace-agentmesh`), not the Kubernetes namespace. It must match what the core and orchestrator use. Verify with: `kubectl exec <core-pod> -c sam-core -- env | grep "^NAMESPACE="`
:::

### Step 4: Install the Chart

:::warning
The `--set-file` key must be exactly `config.yaml`. Using `config.agentYaml` will cause the agent to fail with `ValueError: No apps or flows defined in configuration file`.
:::

```bash
helm install my-agent solace-agent-mesh/sam-agent \
  -f my-agent-values.yaml \
  --set-file config.yaml=./my-agent-config.yaml \
  -n <same-namespace-as-quickstart>
```

For a workflow, the command is the same---just change the release name and point `--set-file` to your workflow configuration file:

```bash
helm install my-workflow solace-agent-mesh/sam-agent \
  -f my-workflow-values.yaml \
  --set-file config.yaml=./my-workflow-config.yaml \
  -n <same-namespace-as-quickstart>
```

### Step 5: Verify Deployment

Check the pod is running:

```bash
kubectl get pods -l app.kubernetes.io/instance=my-agent -n <namespace>
```

Check the agent logs for successful startup:

```bash
kubectl logs -l app.kubernetes.io/instance=my-agent -c sam -n <namespace>
```

Look for these success indicators:

```
Successfully connected to broker at <your-broker-url>
Scheduling agent card publishing every 10 seconds
```

Once the agent card is publishing, the agent should appear in the SAM UI within approximately 10 seconds.

## Using Custom Images

You can deploy a custom-built image---for example, one that packages your own Python tools---by overriding the `image.repository` and `image.tag` values. This works with both deployer mode and standalone mode.

```yaml
image:
  repository: <your-registry>/custom-echo-agent
  tag: "1.0.0"
  pullPolicy: Always
```

For instructions on building custom agent images, see [Building Custom Agent Images](https://solacelabs.github.io/solace-agent-mesh/documentation/developing/tutorials/building-custom-agent-images).

## Standalone Mode

Standalone mode gives you explicit control over persistence configuration. Use it when you need a separate database, different storage buckets/containers, or when deploying outside a quickstart environment.

### Why Standalone Needs Extra Setup

The chart runs a PostgreSQL init container that creates a dedicated database and user for the agent. This init container needs PostgreSQL admin credentials (`PGHOST`, `PGUSER`, `PGPASSWORD`) to execute `CREATE USER` and `CREATE DATABASE` statements. It also needs `DATABASE_URL` for the main container's connection string. In deployer mode these credentials are auto-discovered from the quickstart's labeled secrets. In standalone mode you must provide them manually.

### Step 1: Prepare Agent or Workflow Configuration File

The configuration file format is the same as in deployer mode. See the deployer mode [Step 1](#step-1-prepare-agent-or-workflow-configuration-file) above for examples.

### Step 2: Create the Database Secret

The secret must contain both the PostgreSQL admin variables (for the init container) and `DATABASE_URL` (for the main container).

The `DATABASE_URL` credentials follow a naming convention based on your configuration: `<namespaceId>_<id>_<component>`. For example, with `namespaceId=solace-agentmesh`, `id=custom-echo-agent`, and `component=agent`, the credentials would be:

- User: `solace-agentmesh_custom-echo-agent_agent`
- Password: `solace-agentmesh_custom-echo-agent_agent`
- Database: `solace-agentmesh_custom-echo-agent_agent`

Extract PostgreSQL admin credentials from the quickstart:

```bash
kubectl get secret <quickstart-release>-postgresql -n <namespace> -o json | \
  python3 -c "import sys,json,base64; d=json.load(sys.stdin)['data']; [print(f'{k}: {base64.b64decode(v).decode()}') for k,v in sorted(d.items())]"
```

Create a combined secret with both admin and connection credentials:

```bash
kubectl create secret generic my-agent-db \
  --from-literal=PGHOST=<quickstart-release>-postgresql \
  --from-literal=PGPORT=5432 \
  --from-literal=PGUSER=<admin-user> \
  --from-literal=PGPASSWORD=<admin-password> \
  --from-literal=DATABASE_URL="postgresql+psycopg2://<nsId>_my-agent_agent:<nsId>_my-agent_agent@<quickstart-release>-postgresql:5432/<nsId>_my-agent_agent" \
  -n <namespace>
```

Replace `<nsId>` with your `global.persistence.namespaceId` value.

### Step 3: Prepare Values File

Download the sample values file:

```bash
curl -O https://raw.githubusercontent.com/SolaceProducts/solace-agent-mesh-helm-quickstart/main/samples/agent/agent-standalone-values.yaml
```

Edit `agent-standalone-values.yaml` and configure:

**Required Configuration:**
- `id`: Unique identifier for this agent or workflow instance
- `solaceBroker`: Broker connection details
- `llmService`: LLM service configuration
- `persistence`: Database and S3 credentials

**Persistence Options:**

**Option 1: Use Existing Secrets (Recommended)**
```yaml
persistence:
  existingSecrets:
    database: "my-database-secret"  # Secret must contain DATABASE_URL, PGHOST, PGUSER, PGPASSWORD
    s3: "my-s3-secret"              # For S3: S3_ENDPOINT_URL, S3_BUCKET_NAME, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    # azure: "my-azure-secret"      # For Azure: AZURE_STORAGE_ACCOUNT_NAME, AZURE_STORAGE_CONTAINER_NAME, etc.
    # gcs: "my-gcs-secret"          # For GCS: GCS_BUCKET_NAME, GCS_PROJECT, GCS_CREDENTIALS_JSON
```

**Option 2: Provide Credentials Directly**

For S3:
```yaml
persistence:
  database:
    url: "postgresql+psycopg2://user:password@hostname:5432/dbname"
  s3:
    endpointUrl: "https://s3.amazonaws.com"
    bucketName: "my-bucket"
    accessKey: "your-access-key"
    secretKey: "your-secret-key"
    region: "us-east-1"
```

For Azure Blob Storage:
```yaml
persistence:
  database:
    url: "postgresql+psycopg2://user:password@hostname:5432/dbname"
  azure:
    accountName: "mystorageaccount"
    accountKey: "your-account-key"
    containerName: "my-artifacts"
```

For Google Cloud Storage:
```yaml
persistence:
  database:
    url: "postgresql+psycopg2://user:password@hostname:5432/dbname"
  gcs:
    project: "my-gcp-project"
    bucketName: "my-artifacts"
```

### Step 4: Create Service Account (If Not Exists)

The agent or workflow needs a Kubernetes service account with permissions to access secrets:

```bash
kubectl create serviceaccount solace-agent-mesh-sa -n your-namespace
```

### Step 5: Install the Chart

:::warning
The `--set-file` key must be exactly `config.yaml`. Using `config.agentYaml` will cause the agent to fail with `ValueError: No apps or flows defined in configuration file`.
:::

```bash
helm install my-agent solace-agent-mesh/sam-agent \
  -f agent-standalone-values.yaml \
  --set-file config.yaml=./my-agent-config.yaml \
  -n your-namespace
```

For a workflow:

```bash
helm install my-workflow solace-agent-mesh/sam-agent \
  -f agent-standalone-values.yaml \
  --set-file config.yaml=./my-workflow-config.yaml \
  -n your-namespace
```

### Step 6: Verify Deployment

Check the agent or workflow pod is running:
```bash
kubectl get pods -n your-namespace -l app.kubernetes.io/name=sam-agent
```

Check the agent or workflow logs:
```bash
kubectl logs -n your-namespace -l app.kubernetes.io/name=sam-agent -c sam --tail=100 -f
```

## Configuration Reference

### Required Values

| Parameter | Description | Example |
|-----------|-------------|---------|
| `deploymentMode` | Deployment mode (`deployer` or `standalone`) | `deployer` |
| `id` | Unique agent or workflow identifier | `my-custom-agent` |
| `solaceBroker.url` | Solace broker connection URL | `wss://broker.solace.cloud:443` |
| `solaceBroker.username` | Broker username | `solace-user` |
| `solaceBroker.password` | Broker password | `password123` |
| `solaceBroker.vpn` | Broker VPN name | `default` |
| `llmService.generalModelName` | LLM model name | `gpt-4o` |
| `llmService.endpoint` | LLM API endpoint | `https://api.openai.com/v1` |
| `llmService.apiKey` | LLM API key | `sk-...` |
| `persistence.database.url` | Database connection URL (standalone only) | `postgresql+psycopg2://...` |
| `persistence.s3.endpointUrl` | S3 endpoint (standalone, S3 only) | `https://s3.amazonaws.com` |
| `persistence.s3.bucketName` | S3 bucket name (standalone, S3 only) | `my-bucket` |
| `persistence.azure.accountName` | Azure storage account (standalone, Azure only) | `mystorageaccount` |
| `persistence.azure.containerName` | Azure container name (standalone, Azure only) | `my-artifacts` |
| `persistence.gcs.bucketName` | GCS bucket name (standalone, GCS only) | `my-artifacts` |
| `config.yaml` | Agent configuration (via --set-file) | (file path) |

### Database Requirements

The agent requires a PostgreSQL database (version 17+). The init container will automatically:
1. Create a database user (based on `id` and `namespaceId`)
2. Create a database for the agent
3. Grant necessary permissions

**Database URL Format:**
```
postgresql+psycopg2://username:password@hostname:port/database_name
```

**For Supabase Connection Pooler:**
The chart automatically detects and handles Supabase tenant ID qualification if present in the database secret.

### Object Storage Requirements

The agent requires object storage for file handling. Supported providers:
- **S3**: Amazon S3, MinIO, SeaweedFS, or any S3-compatible storage
- **Azure**: Azure Blob Storage (with account key, connection string, or workload identity)
- **GCS**: Google Cloud Storage (with service account JSON or workload identity)

The storage type is auto-detected from which secrets or configuration values are provided. See the [Persistence Configuration](persistence) documentation for detailed setup instructions per provider.

## Comparison: Deployer vs Standalone Mode

| Aspect | Agent Deployer (UI/API) | Deployer Mode | Standalone Mode |
|--------|------------------------|---------------|-----------------|
| **Deployment** | Via SAM UI/API | Via `helm install` command | Via `helm install` command |
| **Persistence Discovery** | Auto-discovers secrets | Auto-discovers secrets via K8s labels | Explicit configuration required |
| **Agent Config** | Provided by deployer | Must provide via `--set-file` | Must provide via `--set-file` |
| **Custom Images** | Not supported | Supported | Supported |
| **Use Case** | Dynamic agent management | Static agents alongside quickstart | Isolated/GitOps workflows |
| **Lifecycle** | Managed by SAM platform | Managed by Helm/K8s | Managed by Helm/K8s |

## Upgrading Agents or Workflows

To upgrade an agent or workflow deployment:

```bash
helm upgrade my-agent solace-agent-mesh/sam-agent \
  -f my-agent-values.yaml \
  --set-file config.yaml=./my-agent-config.yaml \
  -n your-namespace
```

For a workflow:

```bash
helm upgrade my-workflow solace-agent-mesh/sam-agent \
  -f my-workflow-values.yaml \
  --set-file config.yaml=./my-workflow-config.yaml \
  -n your-namespace
```

## Uninstalling Agents or Workflows

To remove an agent or workflow:

```bash
helm uninstall my-agent -n your-namespace
```

For a workflow:

```bash
helm uninstall my-workflow -n your-namespace
```

:::note
Uninstalling does not delete the agent's database, any data in S3 storage, or any secrets you created manually. Clean these up separately if needed.
:::

## Troubleshooting

### `ValueError: No apps or flows defined in configuration file`

This error means the agent configuration was not passed correctly. Ensure you are using `--set-file config.yaml=` (not `config.agentYaml=`) in your helm command.

### Agent Not Appearing in UI

The most common cause is a `NAMESPACE` mismatch. The SAM logical namespace in your values file must match the namespace used by the core and orchestrator. Verify with:

```bash
kubectl exec <core-pod> -c sam-core -- env | grep "^NAMESPACE="
kubectl exec <agent-pod> -c sam -- env | grep "^NAMESPACE="
```

Both values must be identical.

### Init Container Stuck on `Waiting for postgres...`

In deployer mode, the chart auto-discovers the quickstart's PostgreSQL admin secret via Kubernetes labels. If the labels are missing or the secret does not exist in the same namespace, the init container will wait indefinitely. Verify the secret exists:

```bash
kubectl get secrets -n <namespace> -l app.kubernetes.io/component=postgresql
```

In standalone mode, ensure your database secret contains the required admin credentials (`PGHOST`, `PGUSER`, `PGPASSWORD`) alongside `DATABASE_URL`. The init container needs admin credentials to run `CREATE USER` and `CREATE DATABASE`. See [Create the Database Secret](#step-2-create-the-database-secret) for the full secret format.

### Agent Pod Not Starting

Check pod events:
```bash
kubectl describe pod -n your-namespace -l app.kubernetes.io/name=sam-agent
```

Common causes include missing or incorrect database credentials, an unreachable database server, invalid S3 credentials, or a missing agent configuration file.

### Agent Configuration Errors

If the agent starts but fails to initialize, check the main container logs:
```bash
kubectl logs -n your-namespace -l app.kubernetes.io/name=sam-agent -c sam
```

Common causes include invalid agent configuration YAML format, referenced agents or services that do not exist, or missing required configuration fields.

### Pod Stuck in `Pending`

Reduce the `resources` section in your values file. The default requests may exceed your cluster's available capacity.

## Advanced Configuration

### Custom Resource Limits

Adjust resource requests and limits based on your workload:

```yaml
resources:
  sam:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1024Mi
```

### Additional Environment Variables

Add custom environment variables:

```yaml
environmentVariables:
  MY_CUSTOM_VAR: "value"
  ANOTHER_VAR: "another_value"
```

## Next Steps

- See Solace Agent Mesh documentation for agent or workflow configuration format
- Learn how to build custom agent images in [Building Custom Agent Images](https://solacelabs.github.io/solace-agent-mesh/documentation/developing/tutorials/building-custom-agent-images)
- Set up monitoring and alerting for your agents
- Implement backup strategies for agent databases
- Consider using external-secrets operator for credential management
