# Centrifugo Helm Chart v13 - Installation Tutorial

This tutorial provides step-by-step instructions for deploying Centrifugo v13 to production Kubernetes clusters on Google Kubernetes Engine (GKE) and Amazon Elastic Kubernetes Service (EKS).

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation on Google Kubernetes Engine (GKE)](#installation-on-google-kubernetes-engine-gke)
  - [1. Create GKE Cluster](#1-create-gke-cluster)
  - [2. Configure kubectl](#2-configure-kubectl)
  - [3. Install Helm](#3-install-helm)
  - [4. Prepare Secrets](#4-prepare-secrets-gke)
  - [5. Install Redis for Scaling](#5-install-redis-for-scaling-gke)
  - [6. Deploy Centrifugo](#6-deploy-centrifugo-gke)
  - [7. Configure GKE Ingress](#7-configure-gke-ingress)
  - [8. Verify Installation](#8-verify-installation-gke)
  - [9. Monitoring Setup](#9-monitoring-setup-gke)
- [Installation on Amazon EKS](#installation-on-amazon-eks)
  - [1. Create EKS Cluster](#1-create-eks-cluster)
  - [2. Configure kubectl](#2-configure-kubectl-eks)
  - [3. Install Helm](#3-install-helm-eks)
  - [4. Prepare Secrets](#4-prepare-secrets-eks)
  - [5. Install Redis for Scaling](#5-install-redis-for-scaling-eks)
  - [6. Install AWS Load Balancer Controller](#6-install-aws-load-balancer-controller)
  - [7. Deploy Centrifugo](#7-deploy-centrifugo-eks)
  - [8. Configure ALB Ingress](#8-configure-alb-ingress)
  - [9. Verify Installation](#9-verify-installation-eks)
  - [10. Monitoring Setup](#10-monitoring-setup-eks)
- [Production Considerations](#production-considerations)
- [Troubleshooting](#troubleshooting)

## Overview

This tutorial covers deploying Centrifugo in a production-ready configuration with:

- **High Availability**: Multiple replicas with proper pod distribution
- **Scalability**: Redis engine for horizontal scaling
- **Security**: Externally managed secrets
- **Monitoring**: Prometheus metrics integration
- **Load Balancing**: Cloud-native ingress controllers
- **TLS Termination**: HTTPS for client connections

## Prerequisites

Before starting, ensure you have:

- An active cloud account (Google Cloud Platform or AWS)
- Command-line tools installed:
  - `kubectl` (Kubernetes CLI)
  - Cloud provider CLI (`gcloud` for GKE or `aws` CLI + `eksctl` for EKS)
  - `helm` (v3+)
- Basic knowledge of Kubernetes concepts
- A domain name for accessing Centrifugo (optional but recommended for production)

---

## Installation on Google Kubernetes Engine (GKE)

### 1. Create GKE Cluster

Create a GKE cluster with appropriate settings for production workloads.

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
export CLUSTER_NAME="centrifugo-cluster"
export REGION="us-central1"

# Set the project
gcloud config set project $PROJECT_ID

# Create GKE cluster
gcloud container clusters create $CLUSTER_NAME \
  --region=$REGION \
  --num-nodes=3 \
  --machine-type=n1-standard-2 \
  --enable-autoscaling \
  --min-nodes=3 \
  --max-nodes=10 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-ip-alias \
  --network="default" \
  --subnetwork="default" \
  --release-channel=stable \
  --workload-pool=$PROJECT_ID.svc.id.goog
```

**Parameters explained:**
- `--num-nodes=3`: Start with 3 nodes for high availability
- `--machine-type=n1-standard-2`: 2 vCPUs, 7.5 GB memory per node
- `--enable-autoscaling`: Automatically adjust cluster size based on load
- `--workload-pool`: Enable Workload Identity for secure GCP API access

### 2. Configure kubectl

```bash
# Get cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# Verify connection
kubectl cluster-info
kubectl get nodes
```

You should see 3 nodes in `Ready` state.

### 3. Install Helm

If Helm is not already installed:

```bash
# Install Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

Add the Centrifugo Helm repository:

```bash
helm repo add centrifugal https://centrifugal.github.io/helm-charts
helm repo update
```

### 4. Prepare Secrets (GKE)

Create a Kubernetes Secret containing sensitive Centrifugo configuration. Never commit secrets to version control or pass them via `--set` flags.

```bash
# Generate secure random secrets
export TOKEN_SECRET=$(openssl rand -hex 32)
export ADMIN_PASSWORD=$(openssl rand -hex 16)
export ADMIN_SECRET=$(openssl rand -hex 32)
export API_KEY=$(openssl rand -hex 32)

# Create the secret
kubectl create secret generic centrifugo-secrets \
  --from-literal=CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY="$TOKEN_SECRET" \
  --from-literal=CENTRIFUGO_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  --from-literal=CENTRIFUGO_ADMIN_SECRET="$ADMIN_SECRET" \
  --from-literal=CENTRIFUGO_HTTP_API_KEY="$API_KEY"

# Verify secret creation
kubectl get secret centrifugo-secrets
```

**Save these values securely** - you'll need `ADMIN_PASSWORD` to access the admin UI.

### 5. Install Redis for Scaling (GKE)

For production deployments with multiple Centrifugo replicas, you need Redis as the engine.

```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Redis with persistence
helm install redis bitnami/redis \
  --set auth.enabled=true \
  --set auth.password="$(openssl rand -hex 16)" \
  --set master.persistence.enabled=true \
  --set master.persistence.size=8Gi \
  --set replica.replicaCount=2 \
  --set replica.persistence.enabled=true \
  --set replica.persistence.size=8Gi

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis --timeout=300s
```

Get the Redis password:

```bash
export REDIS_PASSWORD=$(kubectl get secret redis -o jsonpath="{.data.redis-password}" | base64 -d)
echo "Redis password: $REDIS_PASSWORD"
```

Add Redis password to Centrifugo secrets:

```bash
kubectl create secret generic redis-credentials \
  --from-literal=CENTRIFUGO_ENGINE_REDIS_PASSWORD="$REDIS_PASSWORD"
```

### 6. Deploy Centrifugo (GKE)

Create a `values-gke.yaml` file with your configuration:

```yaml
# values-gke.yaml

# Number of replicas for high availability
replicaCount: 3

# Reference to existing secrets
existingSecret: "centrifugo-secrets"

# Additional secret for Redis password
envSecret:
  - name: CENTRIFUGO_ENGINE_REDIS_PASSWORD
    secretKeyRef:
      name: redis-credentials
      key: CENTRIFUGO_ENGINE_REDIS_PASSWORD

# Centrifugo configuration
config:
  # Use Redis engine for multi-replica deployment
  engine:
    type: redis
    redis:
      # Redis master service address
      address: redis://redis-master:6379

  # Enable admin UI
  admin:
    enabled: true

  # Configure allowed origins for CORS
  client:
    allowed_origins:
      - "https://yourdomain.com"
      - "https://www.yourdomain.com"

  # Optional: Configure namespaces
  channel:
    namespaces:
      - name: "chat"
        presence: true
        join_leave: true
        history_size: 100
        history_ttl: "300s"

# Resource allocation
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    memory: 512Mi

# Spread pods across nodes for high availability
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: centrifugo

# Pod disruption budget for safe updates
podDisruptionBudget:
  enabled: true
  minAvailable: 2

# Service configuration
service:
  type: ClusterIP
  port: 8000

serviceInternal:
  port: 9000

# Prometheus metrics
metrics:
  serviceMonitor:
    enabled: false  # Set to true if using Prometheus Operator

# Security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

Install Centrifugo:

```bash
helm install centrifugo centrifugal/centrifugo \
  -f values-gke.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=centrifugo --timeout=300s

# Check pod status
kubectl get pods -l app.kubernetes.io/name=centrifugo
```

You should see 3 Centrifugo pods running.

### 7. Configure GKE Ingress

GKE uses Google Cloud Load Balancer for Ingress. First, create a static IP address:

```bash
# Reserve a global static IP
gcloud compute addresses create centrifugo-ip --global

# Get the IP address
gcloud compute addresses describe centrifugo-ip --global --format="value(address)"
```

Update your DNS records to point your domain to this IP address.

Create a `BackendConfig` for WebSocket timeout configuration:

```yaml
# backend-config.yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: centrifugo-backend-config
spec:
  # WebSocket timeout (max 86400 seconds = 24 hours)
  timeoutSec: 86400
  connectionDraining:
    drainingTimeoutSec: 30
  # Enable HTTP/2 for better performance
  http2:
    enabled: true
```

Apply the BackendConfig:

```bash
kubectl apply -f backend-config.yaml
```

Update your `values-gke.yaml` to add service annotations:

```yaml
# Add to values-gke.yaml under 'service:'
service:
  type: ClusterIP
  port: 8000
  annotations:
    cloud.google.com/backend-config: '{"default": "centrifugo-backend-config"}'
    cloud.google.com/neg: '{"ingress": true}'
```

Upgrade the Centrifugo release:

```bash
helm upgrade centrifugo centrifugal/centrifugo -f values-gke.yaml
```

Create an SSL certificate (using Google-managed certificate):

```yaml
# managed-cert.yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: centrifugo-cert
spec:
  domains:
    - centrifugo.yourdomain.com
```

```bash
kubectl apply -f managed-cert.yaml
```

Now configure the Ingress. Add to `values-gke.yaml`:

```yaml
# Add to values-gke.yaml
ingress:
  enabled: true
  ingressClassName: gce
  pathType: Prefix
  annotations:
    kubernetes.io/ingress.global-static-ip-name: centrifugo-ip
    networking.gke.io/managed-certificates: centrifugo-cert
    kubernetes.io/ingress.allow-http: "false"
  hosts:
    - host: centrifugo.yourdomain.com
      paths:
        - /connection
        - /emulation
```

Upgrade Centrifugo again:

```bash
helm upgrade centrifugo centrifugal/centrifugo -f values-gke.yaml
```

Wait for the Ingress to provision (this can take 10-15 minutes):

```bash
kubectl get ingress centrifugo -w
```

Once the Ingress has an IP address, verify the certificate status:

```bash
kubectl describe managedcertificate centrifugo-cert
```

Wait until the certificate status shows `Active`.

### 8. Verify Installation (GKE)

Test the deployment:

```bash
# Port-forward to test locally first
kubectl port-forward svc/centrifugo 9000:9000

# In another terminal, check health
curl http://localhost:9000/health

# Access admin UI
# Open http://localhost:9000 in your browser
# Password is the value of ADMIN_PASSWORD from step 4
```

Test via Ingress (after DNS propagates and certificate is active):

```bash
# Test health endpoint (use internal service)
kubectl port-forward svc/centrifugo-internal 9000:9000
curl http://localhost:9000/health

# Test WebSocket connection via Ingress
# Install wscat if not already installed
npm install -g wscat

# Connect via your domain
wscat -c wss://centrifugo.yourdomain.com/connection/websocket
```

### 9. Monitoring Setup (GKE)

If you're using Prometheus Operator, enable ServiceMonitor:

```bash
# Install Prometheus Operator (if not already installed)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

Update `values-gke.yaml` to enable metrics:

```yaml
# Add to values-gke.yaml
metrics:
  serviceMonitor:
    enabled: true
    interval: 30s
    additionalLabels:
      release: prometheus
```

Upgrade Centrifugo:

```bash
helm upgrade centrifugo centrifugal/centrifugo -f values-gke.yaml
```

Access Grafana to view metrics:

```bash
# Get Grafana password
kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Port-forward Grafana
kubectl port-forward svc/prometheus-grafana 3000:80
```

Open http://localhost:3000 (username: `admin`, password from above).

---

## Installation on Amazon EKS

### 1. Create EKS Cluster

Create an EKS cluster using `eksctl`:

```bash
# Set variables
export CLUSTER_NAME="centrifugo-cluster"
export REGION="us-west-2"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create cluster configuration file
cat > cluster-config.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
  version: "1.31"

iam:
  withOIDC: true

managedNodeGroups:
  - name: centrifugo-nodes
    instanceType: t3.medium
    desiredCapacity: 3
    minSize: 3
    maxSize: 10
    volumeSize: 20
    ssh:
      allow: false
    labels:
      role: centrifugo
    tags:
      nodegroup-role: centrifugo
    iam:
      withAddonPolicies:
        autoScaler: true
        albIngress: true
        cloudWatch: true

addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy
EOF

# Create the cluster
eksctl create cluster -f cluster-config.yaml
```

This will take 15-20 minutes to complete.

### 2. Configure kubectl (EKS)

```bash
# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify connection
kubectl cluster-info
kubectl get nodes
```

You should see 3 nodes in `Ready` state.

### 3. Install Helm (EKS)

If Helm is not already installed:

```bash
# Install Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

Add the Centrifugo Helm repository:

```bash
helm repo add centrifugal https://centrifugal.github.io/helm-charts
helm repo update
```

### 4. Prepare Secrets (EKS)

Create a Kubernetes Secret containing sensitive Centrifugo configuration.

```bash
# Generate secure random secrets
export TOKEN_SECRET=$(openssl rand -hex 32)
export ADMIN_PASSWORD=$(openssl rand -hex 16)
export ADMIN_SECRET=$(openssl rand -hex 32)
export API_KEY=$(openssl rand -hex 32)

# Create the secret
kubectl create secret generic centrifugo-secrets \
  --from-literal=CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY="$TOKEN_SECRET" \
  --from-literal=CENTRIFUGO_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  --from-literal=CENTRIFUGO_ADMIN_SECRET="$ADMIN_SECRET" \
  --from-literal=CENTRIFUGO_HTTP_API_KEY="$API_KEY"

# Verify secret creation
kubectl get secret centrifugo-secrets
```

**Save these values securely** - you'll need `ADMIN_PASSWORD` to access the admin UI.

### 5. Install Redis for Scaling (EKS)

For production deployments with multiple Centrifugo replicas, you need Redis as the engine.

```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Redis with persistence
helm install redis bitnami/redis \
  --set auth.enabled=true \
  --set auth.password="$(openssl rand -hex 16)" \
  --set master.persistence.enabled=true \
  --set master.persistence.size=8Gi \
  --set replica.replicaCount=2 \
  --set replica.persistence.enabled=true \
  --set replica.persistence.size=8Gi

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis --timeout=300s
```

Get the Redis password:

```bash
export REDIS_PASSWORD=$(kubectl get secret redis -o jsonpath="{.data.redis-password}" | base64 -d)
echo "Redis password: $REDIS_PASSWORD"
```

Add Redis password to Centrifugo secrets:

```bash
kubectl create secret generic redis-credentials \
  --from-literal=CENTRIFUGO_ENGINE_REDIS_PASSWORD="$REDIS_PASSWORD"
```

### 6. Install AWS Load Balancer Controller

The AWS Load Balancer Controller is required for ALB Ingress.

```bash
# Create IAM policy for the controller
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.10.1/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json

# Create IAM service account
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install the controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 7. Deploy Centrifugo (EKS)

Create a `values-eks.yaml` file with your configuration:

```yaml
# values-eks.yaml

# Number of replicas for high availability
replicaCount: 3

# Reference to existing secrets
existingSecret: "centrifugo-secrets"

# Additional secret for Redis password
envSecret:
  - name: CENTRIFUGO_ENGINE_REDIS_PASSWORD
    secretKeyRef:
      name: redis-credentials
      key: CENTRIFUGO_ENGINE_REDIS_PASSWORD

# Centrifugo configuration
config:
  # Use Redis engine for multi-replica deployment
  engine:
    type: redis
    redis:
      # Redis master service address
      address: redis://redis-master:6379

  # Enable admin UI
  admin:
    enabled: true

  # Configure allowed origins for CORS
  client:
    allowed_origins:
      - "https://yourdomain.com"
      - "https://www.yourdomain.com"

  # Optional: Configure namespaces
  channel:
    namespaces:
      - name: "chat"
        presence: true
        join_leave: true
        history_size: 100
        history_ttl: "300s"

# Resource allocation
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    memory: 512Mi

# Spread pods across availability zones
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: centrifugo
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: centrifugo

# Pod disruption budget for safe updates
podDisruptionBudget:
  enabled: true
  minAvailable: 2

# Service configuration
service:
  type: ClusterIP
  port: 8000

serviceInternal:
  port: 9000

# Prometheus metrics
metrics:
  serviceMonitor:
    enabled: false  # Set to true if using Prometheus Operator

# Security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

Install Centrifugo:

```bash
helm install centrifugo centrifugal/centrifugo \
  -f values-eks.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=centrifugo --timeout=300s

# Check pod status
kubectl get pods -l app.kubernetes.io/name=centrifugo
```

You should see 3 Centrifugo pods running.

### 8. Configure ALB Ingress

First, create an ACM certificate for your domain:

```bash
# Request a certificate (replace with your domain)
aws acm request-certificate \
  --domain-name centrifugo.yourdomain.com \
  --validation-method DNS \
  --region $REGION

# Get the certificate ARN
export CERTIFICATE_ARN=$(aws acm list-certificates \
  --region $REGION \
  --query 'CertificateSummaryList[?DomainName==`centrifugo.yourdomain.com`].CertificateArn' \
  --output text)

echo "Certificate ARN: $CERTIFICATE_ARN"
```

Follow the DNS validation instructions in the AWS Console to validate your certificate.

Update your `values-eks.yaml` to configure the Ingress:

```yaml
# Add to values-eks.yaml
ingress:
  enabled: true
  ingressClassName: alb
  pathType: Prefix
  annotations:
    # ALB configuration
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-name: centrifugo-alb

    # WebSocket idle timeout (max 4000 seconds for ALB)
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=3600

    # Health check configuration
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-port: "9000"
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"

    # TLS configuration
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: YOUR_CERTIFICATE_ARN_HERE
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01

    # Tags
    alb.ingress.kubernetes.io/tags: Environment=production,Application=centrifugo
  hosts:
    - host: centrifugo.yourdomain.com
      paths:
        - /connection
        - /emulation
```

Replace `YOUR_CERTIFICATE_ARN_HERE` with your actual certificate ARN, or use the environment variable:

```bash
# Update the certificate ARN in the values file
sed -i "s|YOUR_CERTIFICATE_ARN_HERE|$CERTIFICATE_ARN|g" values-eks.yaml
```

Upgrade Centrifugo:

```bash
helm upgrade centrifugo centrifugal/centrifugo -f values-eks.yaml
```

Wait for the ALB to be provisioned (this can take 3-5 minutes):

```bash
kubectl get ingress centrifugo -w
```

Get the ALB DNS name:

```bash
export ALB_DNS=$(kubectl get ingress centrifugo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"
```

Update your DNS records to create a CNAME pointing `centrifugo.yourdomain.com` to the ALB DNS name.

### 9. Verify Installation (EKS)

Test the deployment:

```bash
# Port-forward to test locally first
kubectl port-forward svc/centrifugo 9000:9000

# In another terminal, check health
curl http://localhost:9000/health

# Access admin UI
# Open http://localhost:9000 in your browser
# Password is the value of ADMIN_PASSWORD from step 4
```

Test via ALB (after DNS propagates):

```bash
# Test WebSocket connection via ALB
npm install -g wscat

# Connect via your domain
wscat -c wss://centrifugo.yourdomain.com/connection/websocket
```

### 10. Monitoring Setup (EKS)

If you're using Prometheus Operator, enable ServiceMonitor:

```bash
# Install Prometheus Operator (if not already installed)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

Update `values-eks.yaml` to enable metrics:

```yaml
# Add to values-eks.yaml
metrics:
  serviceMonitor:
    enabled: true
    interval: 30s
    additionalLabels:
      release: prometheus
```

Upgrade Centrifugo:

```bash
helm upgrade centrifugo centrifugal/centrifugo -f values-eks.yaml
```

Access Grafana to view metrics:

```bash
# Get Grafana password
kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Port-forward Grafana
kubectl port-forward svc/prometheus-grafana 3000:80
```

Open http://localhost:3000 (username: `admin`, password from above).

---

## Production Considerations

### Scaling

The configurations above start with 3 replicas. To scale:

```bash
# Manually scale
kubectl scale deployment centrifugo --replicas=5

# Or update values.yaml
# replicaCount: 5
helm upgrade centrifugo centrifugal/centrifugo -f values.yaml
```

For automatic scaling based on metrics, enable HPA:

```yaml
# Add to values.yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  cpu:
    enabled: true
    targetCPUUtilizationPercentage: 70
  memory:
    enabled: true
    targetMemoryUtilizationPercentage: 80
```

### Security Best Practices

1. **Use External Secrets Operator** for managing secrets from AWS Secrets Manager or GCP Secret Manager
2. **Enable Network Policies** to restrict pod-to-pod communication
3. **Use Pod Security Standards** (restricted profile)
4. **Regularly rotate secrets** (API keys, passwords)
5. **Limit CORS origins** to only your domains
6. **Enable TLS** for all external communications

### High Availability

1. **Multi-zone deployment**: Ensure pods are spread across availability zones
2. **Pod Disruption Budget**: Maintain minimum availability during updates
3. **Redis High Availability**: Use Redis Sentinel or Redis Cluster
4. **Health checks**: Properly configured liveness and readiness probes
5. **Graceful shutdown**: Allow time for client reconnections

### Monitoring and Alerting

Key metrics to monitor:

- `centrifugo_node_num_clients`: Current connection count
- `centrifugo_node_num_channels`: Active channels
- `centrifugo_messages_sent_total`: Message throughput
- Memory and CPU usage
- Redis connection pool metrics

Set up alerts for:

- Pod restarts
- High memory usage (> 80%)
- Connection drops
- Redis connectivity issues
- Ingress 5xx errors

### Backup and Disaster Recovery

1. **Redis backups**: Enable persistence and regular snapshots
2. **Configuration backup**: Store Helm values in version control
3. **Disaster recovery plan**: Document recovery procedures
4. **Regular testing**: Test backup restoration process

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=centrifugo

# View pod events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

Common issues:
- **ImagePullBackOff**: Check image name and registry access
- **CrashLoopBackOff**: Check logs for configuration errors
- **Pending**: Check resource availability and node capacity

### Connection Issues

```bash
# Test internal connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://centrifugo:9000/health

# Check service endpoints
kubectl get endpoints centrifugo
```

### Redis Connection Issues

```bash
# Test Redis connectivity
kubectl run -it --rm redis-test --image=redis:7 --restart=Never -- \
  redis-cli -h redis-master ping

# Check Redis logs
kubectl logs -l app.kubernetes.io/name=redis
```

### Ingress Not Working

**For GKE:**

```bash
# Check Ingress status
kubectl describe ingress centrifugo

# Check ManagedCertificate status
kubectl describe managedcertificate centrifugo-cert

# Check BackendConfig
kubectl describe backendconfig centrifugo-backend-config
```

**For EKS:**

```bash
# Check Ingress status
kubectl describe ingress centrifugo

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify target groups in AWS Console
aws elbv2 describe-target-groups --region $REGION
```
