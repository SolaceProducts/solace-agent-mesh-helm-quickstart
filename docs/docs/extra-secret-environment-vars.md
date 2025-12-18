# Using Extra Secret Environment Variables

## Overview

The `extraSecretEnvironmentVars` feature allows you to inject sensitive environment variables from existing Kubernetes secrets into your SAM (Solace Agent Mesh) deployment containers. This is useful for managing credentials, API keys, and other sensitive configuration data that should not be stored in plain text in your values files.

## How It Works

The `extraSecretEnvironmentVars` configuration references existing Kubernetes secrets and maps specific keys from those secrets to environment variables in your containers. The Helm chart automatically injects these variables into the following containers:

- **SAM Core container** (`sam-core`)
- **Agent Deployer container** (`agent-deployer`)
- **Database initialization container** (`db-init`)
- **S3 initialization container** (`s3-init`)

## Configuration

### Step 1: Create a Kubernetes Secret

First, create a Kubernetes secret containing your sensitive data:

```bash
kubectl create secret generic sam-llm-secret \
  --from-literal=LLM_SERVICE_API_KEY=your-api-key-here \
  --from-literal=SOLACE_BROKER_PASSWORD=your-password-here \
  -n solace-cloud
```

Alternatively, you can create a secret from a file:

```bash
kubectl create secret generic sam-llm-secret \
  --from-file=LLM_SERVICE_API_KEY=./api-key.txt \
  -n solace-cloud
```

Or using a YAML manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sam-llm-secret
  namespace: solace-cloud
type: Opaque
stringData:
  LLM_SERVICE_API_KEY: "your-api-key-here"
  SOLACE_BROKER_PASSWORD: "your-password-here"
```

Apply the secret:

```bash
kubectl apply -f secret.yaml
```

### Step 2: Configure extraSecretEnvironmentVars in values.yaml

Add the `extraSecretEnvironmentVars` configuration to your Helm values file:

```yaml
extraSecretEnvironmentVars:
  - envName: LLM_SERVICE_API_KEY
    secretName: sam-llm-secret
    secretKey: LLM_SERVICE_API_KEY
  - envName: SOLACE_BROKER_PASSWORD
    secretName: sam-llm-secret
    secretKey: SOLACE_BROKER_PASSWORD
```

#### Configuration Parameters

Each entry in `extraSecretEnvironmentVars` requires three fields:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `envName` | The name of the environment variable as it will appear in the container | `LLM_SERVICE_API_KEY` |
| `secretName` | The name of the Kubernetes secret containing the value | `sam-llm-secret` |
| `secretKey` | The key within the secret that contains the value | `LLM_SERVICE_API_KEY` |

### Step 3: Deploy or Upgrade SAM

Deploy or upgrade your SAM installation with the updated values:

```bash
helm upgrade --install agent-mesh ./charts/solace-agent-mesh \
  -f values.yaml \
  -n solace-cloud
```

## Complete Example

Here's a complete example showing how to inject multiple secrets from different sources:

### 1. Create Multiple Secrets

```bash
# Create LLM service secret
kubectl create secret generic sam-llm-secret \
  --from-literal=LLM_SERVICE_API_KEY=sk-1234567890abcdef \
  -n solace-cloud

# Create broker credentials secret
kubectl create secret generic sam-broker-secret \
  --from-literal=BROKER_USERNAME=admin \
  --from-literal=BROKER_PASSWORD=secure-password \
  -n solace-cloud

# Create database credentials secret
kubectl create secret generic sam-db-secret \
  --from-literal=DB_ADMIN_PASSWORD=db-admin-pass \
  -n solace-cloud
```

### 2. Configure values.yaml

```yaml
extraSecretEnvironmentVars:
  # LLM Service API Key
  - envName: LLM_SERVICE_API_KEY
    secretName: sam-llm-secret
    secretKey: LLM_SERVICE_API_KEY
  
  # Broker Credentials
  - envName: SOLACE_BROKER_USERNAME
    secretName: sam-broker-secret
    secretKey: BROKER_USERNAME
  - envName: SOLACE_BROKER_PASSWORD
    secretName: sam-broker-secret
    secretKey: BROKER_PASSWORD
  
  # Database Admin Password
  - envName: DB_ADMIN_PASSWORD
    secretName: sam-db-secret
    secretKey: DB_ADMIN_PASSWORD
```

### 3. Deploy

```bash
helm upgrade --install agent-mesh ./charts/solace-agent-mesh \
  -f values.yaml \
  -n solace-cloud
```

## Verification

To verify that the environment variables are correctly injected:

### 1. Check Pod Environment Variables

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -n solace-cloud -l app.kubernetes.io/component=core -o jsonpath='{.items[0].metadata.name}')

# Check environment variables (this will show the variable names but not the values for security)
kubectl exec -n solace-cloud $POD_NAME -- env | grep LLM_SERVICE_API_KEY
```

### 2. Describe the Pod

```bash
kubectl describe pod -n solace-cloud $POD_NAME
```

Look for the `Environment` section in the container specification. You should see entries like:

```
Environment:
  LLM_SERVICE_API_KEY:  <set to the key 'LLM_SERVICE_API_KEY' in secret 'sam-llm-secret'>
```

## Use Cases

### 1. LLM Service Integration

Inject API keys for LLM services (OpenAI, Anthropic, etc.):

```yaml
extraSecretEnvironmentVars:
  - envName: LLM_SERVICE_API_KEY
    secretName: llm-credentials
    secretKey: api-key
```

### 2. External Database Credentials

Inject credentials for external databases:

```yaml
extraSecretEnvironmentVars:
  - envName: EXTERNAL_DB_PASSWORD
    secretName: external-db-creds
    secretKey: password
  - envName: EXTERNAL_DB_USERNAME
    secretName: external-db-creds
    secretKey: username
```

### 3. Message Broker Credentials

Inject Solace broker credentials:

```yaml
extraSecretEnvironmentVars:
  - envName: SOLACE_BROKER_PASSWORD
    secretName: broker-credentials
    secretKey: password
```

### 4. Third-Party API Keys

Inject API keys for third-party services:

```yaml
extraSecretEnvironmentVars:
  - envName: SLACK_API_TOKEN
    secretName: integration-secrets
    secretKey: slack-token
  - envName: GITHUB_TOKEN
    secretName: integration-secrets
    secretKey: github-token
```

## Best Practices

### 1. Use Separate Secrets for Different Purposes

Organize secrets by their purpose or service:

```yaml
extraSecretEnvironmentVars:
  # LLM secrets
  - envName: LLM_SERVICE_API_KEY
    secretName: sam-llm-secrets
    secretKey: api-key
  
  # Broker secrets
  - envName: BROKER_PASSWORD
    secretName: sam-broker-secrets
    secretKey: password
  
  # Integration secrets
  - envName: SLACK_TOKEN
    secretName: sam-integration-secrets
    secretKey: slack-token
```

### 2. Use Descriptive Names

Use clear, descriptive names for environment variables:

```yaml
# Good
- envName: LLM_SERVICE_API_KEY
  secretName: llm-credentials
  secretKey: openai-api-key

# Avoid
- envName: KEY1
  secretName: secrets
  secretKey: k1
```

### 3. Namespace Isolation

Always create secrets in the same namespace as your SAM deployment:

```bash
kubectl create secret generic my-secret \
  --from-literal=KEY=value \
  -n solace-cloud  # Same namespace as SAM
```

### 4. Secret Management Tools

Consider using secret management tools for production:

- **Sealed Secrets**: Encrypt secrets in Git
- **External Secrets Operator**: Sync secrets from external secret stores (AWS Secrets Manager, HashiCorp Vault, etc.)
- **SOPS**: Encrypt secrets in YAML files

Example with External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: sam-llm-secret
  namespace: solace-cloud
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: sam-llm-secret
  data:
    - secretKey: LLM_SERVICE_API_KEY
      remoteRef:
        key: prod/sam/llm-api-key
```

### 5. Rotation Strategy

Implement a secret rotation strategy:

1. Create a new secret with updated credentials
2. Update the `secretName` in your values file
3. Perform a rolling update of the deployment
4. Delete the old secret after verification

## Troubleshooting

### Secret Not Found

**Error**: `Error: secret "sam-llm-secret" not found`

**Solution**: Ensure the secret exists in the correct namespace:

```bash
kubectl get secrets -n solace-cloud
kubectl describe secret sam-llm-secret -n solace-cloud
```

### Key Not Found in Secret

**Error**: `Error: key "LLM_SERVICE_API_KEY" not found in secret "sam-llm-secret"`

**Solution**: Verify the secret contains the expected key:

```bash
kubectl get secret sam-llm-secret -n solace-cloud -o jsonpath='{.data}'
```

### Environment Variable Not Set

**Issue**: The environment variable is not available in the container

**Solution**: 
1. Verify the `extraSecretEnvironmentVars` configuration in your values file
2. Check that the Helm chart was deployed with the updated values
3. Verify the pod was restarted after the configuration change

```bash
# Force pod restart
kubectl rollout restart deployment/agent-mesh-core -n solace-cloud
```

### Permission Issues

**Error**: `Error: secrets "sam-llm-secret" is forbidden`

**Solution**: Ensure the service account has permission to access secrets:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: solace-cloud
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: solace-cloud
subjects:
  - kind: ServiceAccount
    name: sam-service-account
    namespace: solace-cloud
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

## Security Considerations

1. **Never commit secrets to Git**: Always use `.gitignore` to exclude secret files
2. **Use RBAC**: Limit access to secrets using Kubernetes RBAC
3. **Encrypt at rest**: Enable encryption at rest for etcd in your Kubernetes cluster
4. **Audit access**: Enable audit logging for secret access
5. **Rotate regularly**: Implement a regular secret rotation policy
6. **Least privilege**: Only grant access to secrets that are absolutely necessary

## Related Documentation

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Helm Values Files](https://helm.sh/docs/chart_template_guide/values_files/)
- [External Secrets Operator](https://external-secrets.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
