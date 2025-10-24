# SAM Network Configuration Guide

This guide explains the different ways to expose SAM (Solace Agent Mesh) to the internet and when to use each approach.

## Table of Contents

- [Overview](#overview)
- [Service Exposure Options](#service-exposure-options)
  - [Option 1: ClusterIP (Default)](#option-1-clusterip-default)
  - [Option 2: NodePort](#option-2-nodeport)
  - [Option 3: LoadBalancer](#option-3-loadbalancer)
  - [Option 4: Ingress (Recommended for Production)](#option-4-ingress-recommended-for-production)
- [Ingress Configuration](#ingress-configuration)
  - [AWS ALB Ingress](#aws-alb-ingress)
  - [NGINX Ingress](#nginx-ingress)
  - [Other Ingress Controllers](#other-ingress-controllers)
- [TLS/SSL Configuration](#tlsssl-configuration)
- [Decision Matrix](#decision-matrix)
- [Examples](#examples)

---

## Overview

SAM requires external access for users to access the Web UI and for OAuth2/OIDC authentication flows. Kubernetes provides multiple methods to expose services externally, each with different trade-offs.

**SAM exposes three ports:**
- **Port 80/443**: Web UI (HTTP/HTTPS)
- **Port 5050**: OAuth2 Authentication Server

All ports are HTTP-based and can be exposed through any of the methods below.

---

## Service Exposure Options

### Option 1: ClusterIP (Default)

**What it is:** Internal-only access within the Kubernetes cluster.

**When to use:**
- Development/testing with `kubectl port-forward`
- When using Ingress for external access
- Maximum security (no external exposure)

**Configuration:**
```yaml
service:
  type: ClusterIP
```

**Access SAM:**
```bash
# Port-forward to local machine
kubectl port-forward -n <namespace> svc/sam 8443:443

# Access at https://localhost:8443
```

**Pros:**
- ✅ Most secure (no external exposure)
- ✅ No cloud costs
- ✅ Works everywhere

**Cons:**
- ❌ Requires port-forward for local access
- ❌ Not suitable for team/production use

---

### Option 2: NodePort

**What it is:** Exposes service on each node's IP at a static port (30000-32767 range).

**When to use:**
- Development environments without Ingress
- Bare-metal clusters
- Testing with team members
- Quick external access

**Configuration:**
```yaml
service:
  type: NodePort
  nodePorts:
    https: 30443  # Optional: specify port (or auto-assign)
    http: 30080
    auth: 30050
```

**Access SAM:**
```bash
# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# Get assigned NodePort
NODE_PORT=$(kubectl get svc sam -o jsonpath='{.spec.ports[?(@.name=="webui-tls")].nodePort}')

# Access at https://$NODE_IP:$NODE_PORT
```

**Pros:**
- ✅ Simple setup
- ✅ No external dependencies
- ✅ Works in any Kubernetes environment

**Cons:**
- ❌ Requires non-standard ports (30000-32767)
- ❌ Must know node IPs
- ❌ Not recommended for production

---

### Option 3: LoadBalancer

**What it is:** Provisions a cloud load balancer with an external IP.

**When to use:**
- Simple cloud deployments (AWS, GCP, Azure)
- Quick production setup
- No Ingress controller available
- Non-HTTP protocols (not applicable to SAM)

**Configuration:**
```yaml
service:
  type: LoadBalancer
  annotations:
    # AWS NLB example
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
```

**Access SAM:**
```bash
# Get external IP
kubectl get svc sam -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Configure DNS to point to this address
# Access at https://sam.example.com
```

**Pros:**
- ✅ Easy to set up
- ✅ Cloud-native
- ✅ Automatic external IP

**Cons:**
- ❌ **Costs money** (one load balancer per service)
- ❌ Only works with cloud providers or MetalLB
- ❌ Less efficient than Ingress for multiple services

**Cost Comparison:**
- 1 LoadBalancer service = 1 cloud load balancer (~$15-30/month)
- 10 services = 10 load balancers ($150-300/month)
- 1 Ingress = 1 load balancer for all services (~$15-30/month total)

---

### Option 4: Ingress (Recommended for Production)

**What it is:** HTTP/HTTPS routing layer that uses a single load balancer for multiple services.

**When to use:**
- **Production deployments** ✅
- Cost optimization
- Advanced routing needs (path-based, host-based)
- TLS management with cert-manager
- Integration with WAF, rate limiting, etc.

**Benefits:**
- ✅ **Cost-effective** (one LB for many services)
- ✅ **Layer 7 routing** (HTTP/HTTPS)
- ✅ **Centralized TLS** management
- ✅ **Advanced features** (URL rewrites, authentication, etc.)
- ✅ **Industry standard** for HTTP applications

**Configuration Overview:**
```yaml
service:
  type: ClusterIP  # Ingress sits in front of ClusterIP service

ingress:
  enabled: true
  className: "nginx"  # or "alb", "traefik", etc.
  hosts:
    - host: sam.example.com
      paths:
        - path: /
          pathType: Prefix
```

See [Ingress Configuration](#ingress-configuration) section below for detailed examples.

---

## Ingress Configuration

### AWS ALB Ingress

**Best for:** AWS EKS clusters

**Prerequisites:**
- AWS Load Balancer Controller installed
- ACM certificate for TLS
- Subnets configured for ALB

**Configuration:**

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # ALB handles TLS termination

ingress:
  enabled: true
  className: "alb"
  annotations:
    # ALB configuration
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'

    # TLS certificate (ACM)
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:REGION:ACCOUNT:certificate/ID

    # SSL redirect
    alb.ingress.kubernetes.io/ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'

    # Health check
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/success-codes: "200"

    # Subnets for ALB
    alb.ingress.kubernetes.io/subnets: subnet-xxx,subnet-yyy

    # External DNS (optional)
    external-dns.alpha.kubernetes.io/hostname: sam.example.com

  hosts:
    - host: ""  # Empty for ALB (accepts all traffic)
      paths:
        # Auth endpoints → port 5050
        - path: /login
          pathType: Prefix
          portName: auth
        - path: /callback
          pathType: Prefix
          portName: auth
        - path: /refresh_token
          pathType: Prefix
          portName: auth
        - path: /user_info
          pathType: Prefix
          portName: auth
        - path: /exchange-code
          pathType: Prefix
          portName: auth
        # Web UI → port 80 (HTTP backend, TLS at ALB)
        - path: /
          pathType: Prefix
          portName: webui
```

**Traffic Flow:**
```
Client (HTTPS)
   ↓
AWS ALB (TLS termination via ACM)
   ↓
HTTP (internal VPC traffic)
   ↓
Kubernetes Service
   ↓
SAM Pods
```

**Key Points:**
- TLS termination at ALB using ACM certificates
- No need for TLS certificates in Kubernetes
- Backend communication via HTTP (secure within VPC)
- External DNS automatically creates Route53 records

---

### GKE Ingress (Google Cloud)

**Best for:** Google Kubernetes Engine (GKE) clusters

**Prerequisites:**
- GKE cluster with Ingress enabled
- Google-managed SSL certificate or cert-manager
- Static IP reserved (optional but recommended)

**Configuration:**

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # GKE Ingress handles TLS termination

ingress:
  enabled: true
  className: "gce"  # Google Cloud Ingress
  annotations:
    # Static IP (optional, recommended for production)
    kubernetes.io/ingress.global-static-ip-name: "sam-static-ip"

    # Google-managed SSL certificate
    networking.gke.io/managed-certificates: "sam-ssl-cert"

    # Or use cert-manager
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"

    # Enable HTTPS redirect
    kubernetes.io/ingress.allow-http: "false"

    # Backend configuration (optional)
    cloud.google.com/backend-config: '{"default": "sam-backend-config"}'

  hosts:
    - host: sam.example.com  # Must specify host for GCE
      paths:
        # Auth endpoints → port 5050
        - path: /login
          pathType: Prefix
          portName: auth
        - path: /callback
          pathType: Prefix
          portName: auth
        - path: /refresh_token
          pathType: Prefix
          portName: auth
        - path: /user_info
          pathType: Prefix
          portName: auth
        - path: /exchange-code
          pathType: Prefix
          portName: auth
        # Web UI → port 80 (HTTP backend, TLS at Ingress)
        - path: /
          pathType: Prefix
          portName: webui

  # If using cert-manager instead of Google-managed certs
  tls: []
    # - secretName: sam-tls
    #   hosts:
    #     - sam.example.com
```

**Setup Steps:**

**1. Create a static IP (recommended):**
```bash
gcloud compute addresses create sam-static-ip --global
```

**2. Create a Google-managed SSL certificate:**
```bash
# Create ManagedCertificate resource
cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: sam-ssl-cert
spec:
  domains:
    - sam.example.com
EOF
```

**3. (Optional) Create BackendConfig for custom settings:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: sam-backend-config
spec:
  healthCheck:
    checkIntervalSec: 15
    port: 80
    type: HTTP
    requestPath: /
  timeoutSec: 30
  connectionDraining:
    drainingTimeoutSec: 60
EOF
```

**4. Install SAM:**
```bash
helm install sam . -f values.yaml
```

**5. Get the Ingress IP:**
```bash
kubectl get ingress sam -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**6. Configure DNS:**
Create an A record pointing `sam.example.com` to the Ingress IP.

**Traffic Flow:**
```
Client (HTTPS)
   ↓
Google Cloud Load Balancer (TLS termination)
   ↓
HTTP (internal GCP network)
   ↓
GKE Service
   ↓
SAM Pods
```

**Key Points:**
- Google-managed certificates auto-renew
- Static IP recommended for production
- SSL certificate provisioning takes 15-30 minutes
- Uses Google Cloud Load Balancer (Global or Regional)

---

### Azure Application Gateway Ingress (AKS)

**Best for:** Azure Kubernetes Service (AKS) clusters

**Prerequisites:**
- AKS cluster with Application Gateway Ingress Controller (AGIC)
- Azure Application Gateway
- SSL certificate in Azure Key Vault or cert-manager
- Virtual Network configured

**Configuration:**

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # Application Gateway handles TLS termination

ingress:
  enabled: true
  className: "azure/application-gateway"
  annotations:
    # Application Gateway configuration
    appgw.ingress.kubernetes.io/backend-protocol: "http"
    appgw.ingress.kubernetes.io/ssl-redirect: "true"

    # Use SSL certificate from Azure Key Vault
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "sam-ssl-cert"

    # Or specify certificate by name
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"

    # Health probe configuration
    appgw.ingress.kubernetes.io/health-probe-path: "/"
    appgw.ingress.kubernetes.io/health-probe-interval: "30"
    appgw.ingress.kubernetes.io/health-probe-timeout: "30"
    appgw.ingress.kubernetes.io/health-probe-unhealthy-threshold: "3"

    # Connection draining
    appgw.ingress.kubernetes.io/connection-draining: "true"
    appgw.ingress.kubernetes.io/connection-draining-timeout: "30"

    # Request timeout
    appgw.ingress.kubernetes.io/request-timeout: "30"

  hosts:
    - host: sam.example.com  # Must specify host
      paths:
        # Auth endpoints → port 5050
        - path: /login
          pathType: Prefix
          portName: auth
        - path: /callback
          pathType: Prefix
          portName: auth
        - path: /refresh_token
          pathType: Prefix
          portName: auth
        - path: /user_info
          pathType: Prefix
          portName: auth
        - path: /exchange-code
          pathType: Prefix
          portName: auth
        # Web UI → port 80 (HTTP backend, TLS at App Gateway)
        - path: /
          pathType: Prefix
          portName: webui

  # If using cert-manager
  tls: []
    # - secretName: sam-tls
    #   hosts:
    #     - sam.example.com
```

**Setup Steps:**

**1. Create Application Gateway (if not exists):**
```bash
az network application-gateway create \
  --name sam-appgw \
  --resource-group myResourceGroup \
  --location eastus \
  --capacity 2 \
  --sku Standard_v2 \
  --vnet-name myVNet \
  --subnet appgw-subnet \
  --public-ip-address sam-public-ip
```

**2. Install AGIC using Helm:**
```bash
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

helm install ingress-azure \
  application-gateway-kubernetes-ingress/ingress-azure \
  --namespace kube-system \
  --set appgw.subscriptionId=<subscription-id> \
  --set appgw.resourceGroup=<resource-group> \
  --set appgw.name=<appgw-name> \
  --set armAuth.type=servicePrincipal \
  --set armAuth.secretJSON=<secret-json>
```

**3. Upload SSL certificate to Azure Key Vault:**
```bash
# Create Key Vault
az keyvault create --name sam-keyvault --resource-group myResourceGroup

# Import certificate
az keyvault certificate import \
  --vault-name sam-keyvault \
  --name sam-ssl-cert \
  --file /path/to/certificate.pfx
```

**4. Configure Application Gateway to access Key Vault:**
```bash
# Enable managed identity on App Gateway
az network application-gateway identity assign \
  --gateway-name sam-appgw \
  --resource-group myResourceGroup \
  --identity sam-appgw-identity

# Grant access to Key Vault
az keyvault set-policy \
  --name sam-keyvault \
  --object-id <appgw-managed-identity-object-id> \
  --secret-permissions get \
  --certificate-permissions get
```

**5. Install SAM:**
```bash
helm install sam . -f values.yaml
```

**6. Get the Ingress IP:**
```bash
kubectl get ingress sam -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**7. Configure DNS:**
Create an A record in Azure DNS or your DNS provider pointing `sam.example.com` to the Application Gateway public IP.

**Traffic Flow:**
```
Client (HTTPS)
   ↓
Azure Application Gateway (TLS termination)
   ↓
HTTP (internal Azure VNet)
   ↓
AKS Service
   ↓
SAM Pods
```

**Key Points:**
- Application Gateway supports WAF (Web Application Firewall)
- SSL certificates managed in Azure Key Vault
- Integrated with Azure Monitor for observability
- Supports path-based and host-based routing
- Can integrate with Azure Front Door for global load balancing

---

### NGINX Ingress

**Best for:** Multi-cloud, on-premises, or when you need more control

**Prerequisites:**
- NGINX Ingress Controller installed
- TLS certificate (cert-manager recommended)

**Configuration:**

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # NGINX handles TLS termination

ingress:
  enabled: true
  className: "nginx"
  annotations:
    # NGINX-specific settings
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

    # Rate limiting (optional)
    nginx.ingress.kubernetes.io/limit-rps: "100"

    # Cert-manager (automatic TLS)
    cert-manager.io/cluster-issuer: "letsencrypt-prod"

  hosts:
    - host: sam.example.com  # Must specify host for NGINX
      paths:
        # Auth endpoints
        - path: /login
          pathType: Prefix
          portName: auth
        - path: /callback
          pathType: Prefix
          portName: auth
        - path: /refresh_token
          pathType: Prefix
          portName: auth
        - path: /user_info
          pathType: Prefix
          portName: auth
        - path: /exchange-code
          pathType: Prefix
          portName: auth
        # Web UI
        - path: /
          pathType: Prefix
          portName: webui

  tls:
    - secretName: sam-tls
      hosts:
        - sam.example.com
```

**With cert-manager (automatic TLS):**

Cert-manager will automatically provision and renew certificates from Let's Encrypt.

**Manual TLS certificate:**

```bash
# Create TLS secret manually
kubectl create secret tls sam-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace=<namespace>
```

---

### Other Ingress Controllers

SAM supports any Ingress controller that implements the Kubernetes Ingress specification:

- **Traefik**: Popular for microservices, automatic service discovery
- **HAProxy**: High performance, low latency
- **Contour** (Envoy): Modern, high performance
- **Kong**: API gateway features built-in
- **GCE Ingress**: Google Cloud native
- **Azure Application Gateway**: Azure native

See the [Kubernetes Ingress Controllers documentation](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) for more options.

---

## TLS/SSL Configuration

### When Using Ingress (Recommended)

**TLS termination happens at the Ingress/ALB level:**

```yaml
service:
  tls:
    enabled: false  # No service-level TLS needed

ingress:
  enabled: true
  # TLS handled by Ingress annotations or tls section
```

**Benefits:**
- No need to manage TLS certificates in Kubernetes (with ALB/ACM)
- Automatic certificate renewal (with cert-manager)
- Centralized TLS policy management
- Better performance (no double encryption)

### When Using LoadBalancer/NodePort

**TLS termination happens at the Service level:**

```yaml
service:
  type: LoadBalancer
  tls:
    enabled: true
    cert: ""  # Provided via --set-file
    key: ""   # Provided via --set-file
    passphrase: ""

ingress:
  enabled: false
```

**Install with certificates:**

```bash
helm install sam ./charts/solace-agent-mesh \
  -f values.yaml \
  --set-file service.tls.cert=/path/to/tls.crt \
  --set-file service.tls.key=/path/to/tls.key
```

**Certificate Requirements:**
- Publicly trusted certificate or signed by trusted CA
- Self-signed certificates are not supported
- Must match the hostname in `sam.dnsName`

---

## Decision Matrix

| Scenario | Service Type | Ingress | Why |
|----------|--------------|---------|-----|
| **Local development** | ClusterIP | No | Use kubectl port-forward |
| **Team development** | NodePort | No | Quick team access without port-forward |
| **Simple cloud prod** | LoadBalancer | No | Quick setup |
| **Production (HTTP apps)** | ClusterIP | **Yes** ✅ | Cost-effective, scalable, feature-rich |
| **Bare-metal cluster** | NodePort or ClusterIP | Yes (with MetalLB) | No cloud provider available |
| **Multiple services** | ClusterIP | **Yes** ✅ | Share one load balancer |

---

## Examples

### Example 1: Development (Local)

```yaml
service:
  type: ClusterIP

ingress:
  enabled: false
```

**Access:**
```bash
kubectl port-forward svc/sam 8443:443
# Visit https://localhost:8443
```

---

### Example 2: Development (Team)

```yaml
service:
  type: NodePort

ingress:
  enabled: false
```

**Access:**
```bash
# Get node IP and port
kubectl get svc sam
# Visit https://<node-ip>:<nodeport>
```

---

### Example 3: Simple Production (AWS)

```yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  tls:
    enabled: true

ingress:
  enabled: false
```

**Install:**
```bash
helm install sam . -f values.yaml \
  --set-file service.tls.cert=tls.crt \
  --set-file service.tls.key=tls.key
```

---

### Example 4: Production with AWS ALB

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # ALB handles TLS

ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
    alb.ingress.kubernetes.io/scheme: internet-facing
    external-dns.alpha.kubernetes.io/hostname: sam.example.com
  hosts:
    - host: ""
      paths:
        - path: /login
          portName: auth
        - path: /callback
          portName: auth
        - path: /
          portName: webui
```

---

### Example 5: Production with GKE Ingress

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # GKE handles TLS

ingress:
  enabled: true
  className: "gce"
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "sam-static-ip"
    networking.gke.io/managed-certificates: "sam-ssl-cert"
  hosts:
    - host: sam.example.com
      paths:
          - path: /login
            pathType: Prefix
            portName: auth
          - path: /callback
            pathType: Prefix
            portName: auth
          - path: /refresh_token
            pathType: Prefix
            portName: auth
          - path: /user_info
            pathType: Prefix
            portName: auth
          - path: /exchange-code
            pathType: Prefix
            portName: auth
          - path: /is_token_valid
            pathType: Prefix
            portName: auth
          # Catch-all for Web UI → port 80 (HTTP, TLS at ALB)
          - path: /
            pathType: Prefix
            portName: webui
```

**Setup:**
```bash
# Create static IP
gcloud compute addresses create sam-static-ip --global

# Create managed certificate
kubectl apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: sam-ssl-cert
spec:
  domains:
    - sam.example.com
EOF

# Install SAM
helm install sam . -f values.yaml
```

---

### Example 6: Production with Azure Application Gateway (AKS)

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # App Gateway handles TLS

ingress:
  enabled: true
  className: "azure/application-gateway"
  annotations:
    appgw.ingress.kubernetes.io/backend-protocol: "http"
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "sam-ssl-cert"
  hosts:
    - host: sam.example.com
      paths:
          - path: /login
            pathType: Prefix
            portName: auth
          - path: /callback
            pathType: Prefix
            portName: auth
          - path: /refresh_token
            pathType: Prefix
            portName: auth
          - path: /user_info
            pathType: Prefix
            portName: auth
          - path: /exchange-code
            pathType: Prefix
            portName: auth
          - path: /is_token_valid
            pathType: Prefix
            portName: auth
          # Catch-all for Web UI → port 80 (HTTP, TLS at ALB)
          - path: /
            pathType: Prefix
            portName: webui
```

**Setup:**
```bash
# Upload certificate to Key Vault
az keyvault certificate import \
  --vault-name sam-keyvault \
  --name sam-ssl-cert \
  --file certificate.pfx

# Install SAM
helm install sam . -f values.yaml
```

---

### Example 7: Production with NGINX + cert-manager

```yaml
service:
  type: ClusterIP
  tls:
    enabled: false  # NGINX handles TLS

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: sam.example.com
      paths:
          - path: /login
            pathType: Prefix
            portName: auth
          - path: /callback
            pathType: Prefix
            portName: auth
          - path: /refresh_token
            pathType: Prefix
            portName: auth
          - path: /user_info
            pathType: Prefix
            portName: auth
          - path: /exchange-code
            pathType: Prefix
            portName: auth
          - path: /is_token_valid
            pathType: Prefix
            portName: auth
          # Catch-all for Web UI → port 80 (HTTP, TLS at ALB)
          - path: /
            pathType: Prefix
            portName: webui
  tls:
    - secretName: sam-tls
      hosts:
        - sam.example.com
```

---

## Additional Resources

- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/)
- [External DNS](https://github.com/kubernetes-sigs/external-dns)

---

## Support

For network configuration questions or issues:
- Email: info@solace.com
- GitHub Issues: https://github.com/SolaceDev/sam-kubernetes/issues
