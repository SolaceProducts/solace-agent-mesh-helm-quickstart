---
sidebar_position: 4
title: Standalone Agent Deployment
---

# Standalone Agent Deployment Guide

This guide explains how to deploy Solace Agent Mesh agents directly, without using the agent-deployer microservice.

## Overview

There are two ways to deploy SAM agents:

1. **Via Agent Deployer** (Default): The SAM platform includes an agent-deployer microservice that dynamically deploys agents via the UI/API
2. **Standalone Deployment** (This Guide): Deploy agents directly using `helm install` commands

## When to Use Standalone Deployment

Use standalone deployment when you:
- Want to deploy agents independently of the main SAM platform
- Need direct control over agent deployment and lifecycle
- Want to manage agents using GitOps workflows
- Are deploying agents in different clusters/namespaces

## Prerequisites

Before deploying a standalone agent, you need:

1. **Kubernetes cluster** with kubectl access
2. **Helm 3.19.0+** installed
3. **PostgreSQL database** (17+) - agent needs a database for state management
4. **S3-compatible storage** - agent needs object storage for file handling
5. **Solace Event Broker** - connection URL and credentials
6. **LLM Service** - API endpoint and credentials (e.g., OpenAI)
7. **Agent configuration file** - YAML file defining which agents/services to enable

## Deployment Steps

### Step 1: Prepare Agent Configuration File

Create an agent configuration file (e.g., `my-agent-config.yaml`) that defines which agents and services to enable. Refer to the Solace Agent Mesh documentation for the configuration format.

Example structure (format may vary - consult SAM docs):
```yaml
agents:
  - name: web_request
    enabled: true
  - name: global
    enabled: true
# ... additional configuration
```

### Step 2: Prepare Values File

Download the sample values file:
```bash
curl -O https://raw.githubusercontent.com/SolaceProducts/solace-agent-mesh-helm-quickstart/main/samples/agent/agent-standalone-values.yaml
```

Edit `agent-standalone-values.yaml` and configure:

**Required Configuration:**
- `agentId`: Unique identifier for this agent instance
- `solaceBroker`: Broker connection details
- `llmService`: LLM service configuration
- `persistence`: Database and S3 credentials

**Persistence Options:**

**Option 1: Use Existing Secrets (Recommended)**
```yaml
persistence:
  existingSecrets:
    database: "my-database-secret"  # Secret must contain DATABASE_URL
    s3: "my-s3-secret"              # Secret must contain S3_ENDPOINT_URL, S3_BUCKET_NAME, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
```

**Option 2: Provide Credentials Directly**
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

### Step 3: Create Service Account (If Not Exists)

The agent needs a Kubernetes service account with permissions to access secrets:

```bash
kubectl create serviceaccount solace-agent-mesh-sa -n your-namespace
```

### Step 4: Install the Agent Chart

```bash
helm install my-agent solace-agent-mesh/sam-agent \
  -f agent-standalone-values.yaml \
  --set-file config.agentYaml=./my-agent-config.yaml \
  -n your-namespace
```

**Important Parameters:**
- `my-agent`: Helm release name (choose a unique name per agent)
- `-f agent-standalone-values.yaml`: Your customized values file
- `--set-file config.agentYaml=...`: Path to your agent configuration file
- `-n your-namespace`: Kubernetes namespace to deploy into

### Step 5: Verify Deployment

Check the agent pod is running:
```bash
kubectl get pods -n your-namespace -l app.kubernetes.io/name=sam-agent
```

Check agent logs:
```bash
kubectl logs -n your-namespace -l app.kubernetes.io/name=sam-agent --tail=100 -f
```

## Configuration Reference

### Required Values

| Parameter | Description | Example |
|-----------|-------------|---------|
| `deploymentMode` | Deployment mode (must be "standalone") | `standalone` |
| `agentId` | Unique agent identifier | `my-custom-agent` |
| `solaceBroker.url` | Solace broker connection URL | `wss://broker.solace.cloud:443` |
| `solaceBroker.username` | Broker username | `solace-user` |
| `solaceBroker.password` | Broker password | `password123` |
| `solaceBroker.vpn` | Broker VPN name | `default` |
| `llmService.generalModelName` | LLM model name | `gpt-4o` |
| `llmService.endpoint` | LLM API endpoint | `https://api.openai.com/v1` |
| `llmService.apiKey` | LLM API key | `sk-...` |
| `persistence.database.url` | Database connection URL | `postgresql+psycopg2://...` |
| `persistence.s3.endpointUrl` | S3 endpoint | `https://s3.amazonaws.com` |
| `persistence.s3.bucketName` | S3 bucket name | `my-bucket` |
| `config.agentYaml` | Agent configuration (via --set-file) | (file path) |

### Database Requirements

The agent requires a PostgreSQL database (version 17+). The init container will automatically:
1. Create a database user (based on `agentId` and `namespaceId`)
2. Create a database for the agent
3. Grant necessary permissions

**Database URL Format:**
```
postgresql+psycopg2://username:password@hostname:port/database_name
```

**For Supabase Connection Pooler:**
The chart automatically detects and handles Supabase tenant ID qualification if present in the database secret.

### S3 Storage Requirements

The agent requires S3-compatible storage for file handling. Supported providers:
- Amazon S3
- MinIO
- SeaweedFS
- Any S3-compatible object storage

**Required S3 Configuration:**
- Endpoint URL
- Bucket name (must exist)
- Access credentials (key ID and secret key)

## Comparison: Deployer vs Standalone Mode

| Aspect | Agent Deployer Mode | Standalone Mode |
|--------|-------------------|-----------------|
| **Deployment** | Via SAM UI/API | Via `helm install` command |
| **Configuration Discovery** | Auto-discovers persistence secrets | Explicit configuration required |
| **Agent Config** | Provided by deployer | Must provide via `--set-file` |
| **Use Case** | Dynamic agent management | Static/GitOps workflows |
| **Lifecycle** | Managed by SAM platform | Managed by Helm/K8s |

## Troubleshooting

### Agent Pod Not Starting

**Check pod events:**
```bash
kubectl describe pod -n your-namespace -l app.kubernetes.io/name=sam-agent
```

**Common issues:**
- Missing or incorrect database credentials
- Database not accessible from cluster
- S3 credentials invalid
- Missing agent configuration file

### Init Container Fails

The init container creates the database and user. Check logs:
```bash
kubectl logs -n your-namespace -l app.kubernetes.io/name=sam-agent -c db-init
```

**Common issues:**
- Admin credentials in persistence secret are incorrect
- Database server not reachable
- Admin user lacks CREATE DATABASE permissions

### Agent Configuration Errors

If the agent starts but fails to initialize:
```bash
kubectl logs -n your-namespace -l app.kubernetes.io/name=sam-agent -c sam
```

**Common issues:**
- Invalid agent configuration YAML format
- Referenced agents/services don't exist
- Missing required configuration fields

## Upgrading Agents

To upgrade an agent deployment:

```bash
helm upgrade my-agent solace-agent-mesh/sam-agent \
  -f agent-standalone-values.yaml \
  --set-file config.agentYaml=./my-agent-config.yaml \
  -n your-namespace
```

## Uninstalling Agents

To remove an agent:

```bash
helm uninstall my-agent -n your-namespace
```

**Note:** This does NOT delete:
- The agent's database (manual cleanup required)
- Any data in S3 storage
- Any secrets you created manually

## Advanced Configuration

### Using Separate Database and S3 Secrets

For better security, create separate secrets for database and S3:

```bash
# Database secret
kubectl create secret generic my-db-secret \
  --from-literal=DATABASE_URL='postgresql+psycopg2://user:pass@host:5432/db' \
  -n your-namespace

# S3 secret
kubectl create secret generic my-s3-secret \
  --from-literal=S3_ENDPOINT_URL='https://s3.amazonaws.com' \
  --from-literal=S3_BUCKET_NAME='my-bucket' \
  --from-literal=AWS_ACCESS_KEY_ID='AKIAIOSFODNN7EXAMPLE' \
  --from-literal=AWS_SECRET_ACCESS_KEY='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' \
  -n your-namespace
```

Then reference them in values:
```yaml
persistence:
  existingSecrets:
    database: "my-db-secret"
    s3: "my-s3-secret"
```

### Custom Resource Limits

Adjust resource requests/limits based on your workload:

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

- Consult Solace Agent Mesh documentation for agent configuration format
- Set up monitoring and alerting for your agents
- Implement backup strategies for agent databases
- Consider using external-secrets operator for credential management
