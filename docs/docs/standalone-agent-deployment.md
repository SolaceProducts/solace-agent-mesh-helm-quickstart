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

This guide covers two standalone scenarios:

- **Deploy alongside a SAM Quickstart** — reuse the broker, PostgreSQL, and object storage that the quickstart already created. Quickest path to add a custom agent in an existing quickstart cluster.
- **Deploy with your own infrastructure** — supply your own broker, database, and object storage credentials. Use this for isolated deployments, separate databases, or GitOps pipelines.

## When to Use Standalone Deployment

Use standalone deployment when you want to deploy agents or workflows independently of the main SAM platform, need direct control over agent or workflow deployment and lifecycle, want to manage agents or workflows using GitOps workflows, or are deploying agents or workflows in different clusters or namespaces.

## Prerequisites

Before deploying a standalone agent or workflow, you need a Kubernetes cluster with kubectl access, Helm 3.19.0+ installed, a Solace Event Broker with connection URL and credentials, and an LLM service API endpoint and credentials (e.g., OpenAI). You also need a PostgreSQL database (version 17+) for state management and object storage (S3, Azure Blob, or GCS) for file handling---if you are deploying alongside a SAM Quickstart, these are already provisioned and the Quickstart values sample reuses them by name.

## Deploy Alongside a SAM Quickstart

This is the simplest path when you already have a SAM Quickstart running and want to add a custom agent as a separate Helm release in the same namespace. The agent reuses the broker, database, and storage secrets the quickstart created — no extra cluster setup is needed.

### Step 1: Prepare Agent Configuration File

Create a configuration file that defines your agent. This file is passed to Helm via `--set-file config.yaml=`. All `${...}` variables are resolved at runtime from environment variables that the chart injects (broker creds, LLM, namespace).

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
      agent_identity:
        # The agent persists its identity key to a file; this path must be writable.
        key_persistence: "/tmp/_agent_MyAgent.key"
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

### Step 2: Prepare Values File

Use the [agent-quickstart-values.yaml](https://raw.githubusercontent.com/SolaceProducts/solace-agent-mesh-helm-quickstart/main/samples/agent/agent-quickstart-values.yaml) sample. Download a copy:

```bash
curl -O https://raw.githubusercontent.com/SolaceProducts/solace-agent-mesh-helm-quickstart/main/samples/agent/agent-quickstart-values.yaml
```

The sample is pre-configured for a SAM Quickstart installed with release name `sam`. Required edits:

1. Set `id` to a unique identifier for your agent.
2. Fill in `llmService.generalModelName`, `endpoint`, and `apiKey`.
3. If your Quickstart release name is not `sam`, search-and-replace `sam-` with your release name throughout the file. Default secret names follow the chart's `<release>-postgresql` and `<release>-pull-secret` conventions.

The values file points `persistence.existingSecrets.database` and `persistence.existingSecrets.s3` at the secrets the Quickstart already created (`<release>-postgresql` and `<release>-solace-agent-mesh-storage`), so no additional secret setup is required.

:::warning
The `NAMESPACE` environment variable in the values file is the SAM logical namespace (for example, `solace-agent-mesh`), not the Kubernetes namespace. It must match what the SAM core uses. Verify with: `kubectl exec <core-pod> -c sam-core -- env | grep "^NAMESPACE="`
:::

### Step 3: Install the Chart

Note: Update the namespace to match existing one.

If installing from the helm repo:

```bash
helm install my-agent solace-agent-mesh/sam-agent \
  -n sam \
  -f agent-quickstart-values.yaml \
  --set-file config.yaml=./my-agent-config.yaml
```

:::note
Alternative, if installing from a local chart:
```bash
helm install my-agent ./charts/solace-agent-mesh-agent \
  -n sam \
  -f agent-quickstart-values.yaml \
  --set-file config.yaml=./my-agent-config.yaml
```
:::

### Step 4: Verify Deployment

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

You can deploy a custom-built image---for example, one that packages your own Python tools---by overriding the `image.repository` and `image.tag` values. This works in either deployment scenario.

```yaml
image:
  repository: <your-registry>/custom-echo-agent
  tag: "1.0.0"
  pullPolicy: Always
```

For instructions on building custom agent images, see [Building Custom Agent Images](https://solacelabs.github.io/solace-agent-mesh/documentation/developing/tutorials/building-custom-agent-images).

## Deploy With Your Own Infrastructure

This path gives you explicit control over persistence configuration. Use it when you need a separate database, different storage buckets/containers, or when deploying outside a SAM Quickstart environment.

### Why This Path Needs Extra Setup

The chart runs a PostgreSQL init container that creates a dedicated database and user for the agent. This init container needs PostgreSQL admin credentials (`PGHOST`, `PGUSER`, `PGPASSWORD`) to execute `CREATE USER` and `CREATE DATABASE` statements. It also needs `DATABASE_URL` for the main container's connection string. When deploying alongside a SAM Quickstart you can reuse the existing PostgreSQL secret directly; outside that environment, you must provide these credentials manually.

### Step 1: Prepare Agent or Workflow Configuration File

The configuration file format is the same as in the Quickstart scenario. See [Step 1 above](#step-1-prepare-agent-configuration-file) for an agent example. For a workflow, the structure looks like:

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
| `id` | Unique agent or workflow identifier | `my-custom-agent` |
| `solaceBroker.url` | Solace broker connection URL | `wss://broker.solace.cloud:443` |
| `solaceBroker.username` | Broker username | `solace-user` |
| `solaceBroker.password` | Broker password | `password123` |
| `solaceBroker.vpn` | Broker VPN name | `default` |
| `llmService.generalModelName` | LLM model name | `gpt-4o` |
| `llmService.endpoint` | LLM API endpoint | `https://api.openai.com/v1` |
| `llmService.apiKey` | LLM API key | `sk-...` |
| `persistence.database.url` | Database connection URL (only when `persistence.createSecrets: true`) | `postgresql+psycopg2://...` |
| `persistence.s3.endpointUrl` | S3 endpoint (only when `persistence.createSecrets: true`, S3 variant) | `https://s3.amazonaws.com` |
| `persistence.s3.bucketName` | S3 bucket name (only when `persistence.createSecrets: true`, S3 variant) | `my-bucket` |
| `persistence.azure.accountName` | Azure storage account (only when `persistence.createSecrets: true`, Azure variant) | `mystorageaccount` |
| `persistence.azure.containerName` | Azure container name (only when `persistence.createSecrets: true`, Azure variant) | `my-artifacts` |
| `persistence.gcs.bucketName` | GCS bucket name (only when `persistence.createSecrets: true`, GCS variant) | `my-artifacts` |
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

The init container needs admin credentials (`PGHOST`, `PGUSER`, `PGPASSWORD`) to create a per-agent database, plus `DATABASE_URL` for the main container.

- **When deploying alongside a SAM Quickstart**: confirm the secret named in `persistence.existingSecrets.database` exists in the same namespace. The Quickstart's `<release>-postgresql` secret already contains all four required keys.
- **When deploying with your own infrastructure**: confirm your database secret contains the admin credentials (`PGHOST`, `PGUSER`, `PGPASSWORD`) alongside `DATABASE_URL`. See [Create the Database Secret](#step-2-create-the-database-secret) for the full secret format.

To check what secret keys are present:

```bash
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data}' | jq 'keys'
```

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
