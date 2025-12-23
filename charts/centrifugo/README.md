# Centrifugo

This chart bootstraps a [Centrifugo](https://centrifugal.dev) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

For Centrifugo configuration options, see the [official documentation](https://centrifugal.dev/docs/server/configuration).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start (Local Testing with Minikube)](#quick-start-local-testing-with-minikube)
- [Installation](#installation)
  - [From Helm Repository](#from-helm-repository)
  - [From OCI Registry](#from-oci-registry)
- [Install Chart](#install-chart)
- [Uninstall Chart](#uninstall-chart)
- [Upgrading Chart](#upgrading-chart)
- [Concepts](#concepts)
  - [Architecture](#architecture)
  - [Service Design](#service-design)
  - [Scaling](#scaling)
  - [Ingress for Public Access](#ingress-for-public-access)
    - [Full NGINX Ingress Example (Minikube)](#full-nginx-ingress-example-minikube)
    - [Full HAProxy Ingress Example (Minikube)](#full-haproxy-ingress-example-minikube)
    - [AWS ALB Ingress (EKS)](#aws-alb-ingress-eks)
    - [GCP GKE Ingress](#gcp-gke-ingress)
- [Production Deployment](#production-deployment)
  - [Resource Considerations](#resource-considerations)
  - [High Availability Example](#high-availability-example)
  - [Monitoring Distributed Deployments](#monitoring-distributed-deployments)
  - [Graceful Shutdown](#graceful-shutdown)
  - [Health Probes](#health-probes)
  - [Troubleshooting](#troubleshooting)
- [Configuration](#configuration)
- [Secret Management](#secret-management)
- [Using with HashiCorp Vault](#using-with-hashicorp-vault)
- [Scale with Redis Engine](#scale-with-redis-engine)
- [With NATS Broker](#with-nats-broker)
- [Using initContainers](#using-initcontainers)
- [Parameters](#parameters)
- [Upgrading](#upgrading)

## Prerequisites

- Kubernetes 1.21+
- Helm 3+

## Quick Start (Local Testing with Minikube)

This section shows how to quickly test Centrifugo locally using Minikube.

### 1. Start Minikube and install Centrifugo

```bash
minikube start
helm repo add centrifugal https://centrifugal.github.io/helm-charts
helm repo update
helm install centrifugo centrifugal/centrifugo \
  --set config.admin.password=admin \
  --set config.admin.secret=secret
```

Or from local chart:

```bash
helm install centrifugo charts/centrifugo \
  --set config.admin.password=admin \
  --set config.admin.secret=secret
```

Note! Do not use this approach to set secrets in production – use [secrets](#secret-management) instead.

### 2. Wait for the pod to be ready

```bash
kubectl get pods -w
```

Wait until the pod status shows `Running` and `1/1` ready.

### 3. Access Centrifugo

Open port-forwards to access Centrifugo services (each in a separate terminal):

```bash
# Terminal 1: Internal port (for admin UI, API, metrics)
kubectl port-forward svc/centrifugo 9000:9000

# Terminal 2: External port (for client WebSocket connections)
kubectl port-forward svc/centrifugo 8000:8000
```

Alternatively, run in background with `&` (use `pkill -f "port-forward svc/centrifugo"` to stop).

### 4. Verify it's working

```bash
# Check health endpoint
curl -s http://localhost:9000/health
# Expected: {}
```

Open admin web interface in browser: <http://localhost:9000> (password: `admin`).

### 5. Test WebSocket connection

You can test WebSocket connectivity using [wscat](https://github.com/websockets/wscat):

```bash
npm install -g wscat
wscat -c ws://localhost:8000/connection/websocket
```

### 6. Cleanup

```bash
helm uninstall centrifugo
minikube stop
```

## Installation

### From Helm Repository

```console
helm repo add centrifugal https://centrifugal.github.io/helm-charts
helm repo update
```

_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._

### From OCI Registry

The chart is also available from GitHub Container Registry:

```console
helm install centrifugo oci://ghcr.io/centrifugal/helm-charts/centrifugo
```

## Install Chart

```console
helm install [RELEASE_NAME] centrifugal/centrifugo
```

_See [configuration](#configuration) below._

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

## Uninstall Chart

```console
helm uninstall [RELEASE_NAME]
```

This removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._

## Upgrading Chart

```console
helm upgrade [RELEASE_NAME] [CHART] --install
```

_See [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) for command documentation._

## Concepts

### Architecture

Centrifugo exposes 3 main ports, each serving different purposes:

```text
                                    ┌─────────────────────────────────────┐
                                    │           Centrifugo Pod            │
                                    │                                     │
┌─────────────┐    Ingress          │  ┌───────────────────────────────┐  │
│   Clients   │───────────────────────▶│  External (8000)              │  │
│ Connections │    WebSocket/       │  │  - Client conns, emulation    │  │
└─────────────┘    SSE/HTTP         │  │  - WebSocket, SSE, HTTP       │  │
                                    │  └───────────────────────────────┘  │
                                    │                                     │
┌─────────────┐    Internal only    │  ┌───────────────────────────────┐  │
│  Backend    │───────────────────────▶│  Internal (9000)              │  │
│  Services   │    (ClusterIP)      │  │  - Server API (publish, etc)  │  │
└─────────────┘                     │  │  - Admin UI, Prometheus       │  │
                                    │  │  - Health checks              │  │
                                    │  └───────────────────────────────┘  │
                                    │                                     │
┌─────────────┐    Internal only    │  ┌───────────────────────────────┐  │
│  Backend    │───────────────────────▶│  GRPC API (10000)             │  │
│  Services   │    (ClusterIP)      │  │  - Server GRPC API            │  │
└─────────────┘                     │  └───────────────────────────────┘  │
                                    │                                     │
                                    └─────────────────────────────────────┘
```

There is also a unidirectional GRPC transport port (11000). It's not commonly used by Centrifugo users, but the chart creates resources for it also.

### Service Design

Centrifugo exposes multiple ports for different purposes:

- **External** (default 8000): Client connections (WebSocket, HTTP streaming, SSE)
- **Internal** (default 9000): Health checks, Prometheus metrics, admin UI
- **GRPC** (default 10000): Server API (publishing, presence, history)
- **Uni-GRPC** (default 11000): Unidirectional GRPC stream

#### Server Ports vs Service Ports

The chart **decouples Centrifugo server ports from Kubernetes service ports**:

```yaml
# Centrifugo servers: What ports Centrifugo listens on inside the container
servers:
  external:
    port: 8000
  internal:
    port: 9000
    scheme: HTTP  # or HTTPS (for probes and metrics)
  grpc:
    port: 10000
  uniGrpc:
    port: 11000

# Kubernetes service ports: External-facing ports that forward to server ports
service:
  port: 443  # Can be different from server port
```

This separation allows you to:
- Expose services on standard ports (443, 80) while Centrifugo runs on different ports internally
- Use the same service port across different Service objects (when using separate services)
- Change external-facing ports without modifying Centrifugo configuration

#### Single Service (Default)

By default, **all ports are exposed via a single Kubernetes Service**. This is simple and works for most cases:

```yaml
# All ports on one service
Service: centrifugo
  - port 8000 → container:8000 (external)
  - port 9000 → container:9000 (internal)
  - port 10000 → container:10000 (grpc)
  - port 11000 → container:11000 (uni-grpc)
```

#### Separate Services (Advanced)

For advanced deployments, you can split ports into **separate Services**:

```yaml
service:
  port: 443  # Main service on 443

serviceInternal:
  useSeparate: true
  port: 443  # Internal service also on 443 (different Service object)

serviceGrpc:
  useSeparate: true
```

**Why separate services?**

| Use Case | Solution |
|----------|----------|
| Use same port (e.g., 443) for all services | Separate services + configure each to use port 443 |
| Different load balancing for GRPC vs HTTP | Separate services with different annotations |
| Restrict internal API access with NetworkPolicy | Separate internal service to target with policy |
| Different service types (LoadBalancer for external, ClusterIP for internal) | Separate services with different types |

### Scaling

This chart by default starts Centrifugo with **Memory engine**. Running multiple pods with the Memory engine results in incorrect behavior.

To scale horizontally, use **Redis engine** or **NATS broker**:

```bash
# With Redis (supports all Centrifugo features)
helm install centrifugo centrifugal/centrifugo \
  --set config.engine.type=redis \
  --set config.engine.redis.address=redis://redis:6379 \
  --set replicaCount=3

# With NATS (at-most-once delivery only, no history/recovery/presence support).
helm install centrifugo centrifugal/centrifugo \
  --set config.broker.enabled=true \
  --set config.broker.type=nats \
  --set config.broker.nats.url=nats://nats:4222 \
  --set replicaCount=3
```

### Ingress for Public Access

To expose Centrifugo to the public internet via Ingress:

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  pathType: Prefix
  hosts:
    - host: centrifugo.example.com
      paths:
        - /connection    # WebSocket, HTTP-streaming, SSE, etc.
        - /emulation     # Emulation endpoint.
  tls:
    - secretName: centrifugo-tls
      hosts:
        - centrifugo.example.com

config:
  client:
    allowed_origins:
      - https://yourdomain.com
```

**Important:** Centrifugo maintains many persistent connections. Your Ingress controller must be tuned for high connection counts:

| Setting | Description | Recommendation |
|---------|-------------|----------------|
| Open file limits | Max connections per process | Increase `ulimit -n` (e.g., 65535+) |
| Ephemeral ports | Outbound connection ports | Expand range: `net.ipv4.ip_local_port_range = 1024 65535` |
| Timeouts | WebSocket idle timeout | Increase read/send timeouts (e.g., 3600s) |

#### NGINX Ingress Controller

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  pathType: Prefix
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  hosts:
    - host: centrifugo.example.com
      paths:
        - /connection
        - /emulation
```

#### HAProxy Ingress Controller

```yaml
ingress:
  enabled: true
  ingressClassName: haproxy
  pathType: Prefix
  annotations:
    haproxy.org/timeout-tunnel: "3600s"
  hosts:
    - host: centrifugo.example.com
      paths:
        - /connection
        - /emulation
```

#### Full NGINX Ingress Example (Minikube)

This example assumes Centrifugo is already running as shown in the [Quick Start](#quick-start-local-testing-with-minikube) section.

##### 1. Enable NGINX Ingress addon in Minikube

```bash
minikube addons enable ingress
```

##### 2. Update Centrifugo with NGINX Ingress

```bash
helm upgrade centrifugo centrifugal/centrifugo \
  --set config.admin.password=admin \
  --set config.admin.secret=secret \
  --set config.client.allowed_origins[0]="*" \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=nginx \
  --set ingress.pathType=Prefix \
  --set ingress.hosts[0].host=centrifugo.local \
  --set ingress.hosts[0].paths[0]=/connection \
  --set ingress.hosts[0].paths[1]=/emulation \
  --set ingress.annotations."nginx\.ingress\.kubernetes\.io/proxy-read-timeout"=3600 \
  --set ingress.annotations."nginx\.ingress\.kubernetes\.io/proxy-send-timeout"=3600
```

##### 3. Add local hostname

Get the Minikube IP and add it to your hosts file:

```bash
echo "$(minikube ip) centrifugo.local" | sudo tee -a /etc/hosts
```

##### 4. Test NGINX Ingress connection

```bash
# Test WebSocket endpoint through Ingress
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  "http://centrifugo.local/connection/websocket"
```

You should see a `101 Switching Protocols` response, confirming WebSocket works through the Ingress.

#### Full HAProxy Ingress Example (Minikube)

This example assumes Centrifugo is already running as shown in the [Quick Start](#quick-start-local-testing-with-minikube) section.

##### 1. Install HAProxy Ingress Controller

```bash
helm repo add haproxytech https://haproxytech.github.io/helm-charts
helm install haproxy-ingress haproxytech/kubernetes-ingress \
  --set controller.service.type=NodePort
```

##### 2. Update Centrifugo with HAProxy Ingress

```bash
helm upgrade centrifugo centrifugal/centrifugo \
  --set config.admin.password=admin \
  --set config.admin.secret=secret \
  --set config.client.allowed_origins[0]="*" \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=haproxy \
  --set ingress.pathType=Prefix \
  --set ingress.hosts[0].host=centrifugo.local \
  --set ingress.hosts[0].paths[0]=/connection \
  --set ingress.hosts[0].paths[1]=/emulation \
  --set ingress.annotations."haproxy\.org/timeout-tunnel"=3600s
```

##### 3. Configure local hostname

Get the Minikube IP and add it to your hosts file:

```bash
echo "$(minikube ip) centrifugo.local" | sudo tee -a /etc/hosts
```

##### 4. Get the HAProxy NodePort

```bash
export INGRESS_PORT=$(kubectl get svc haproxy-ingress-kubernetes-ingress -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
echo "Ingress available at: http://centrifugo.local:$INGRESS_PORT"
```

##### 5. Test HAProxy Ingress connection

```bash
# Test WebSocket endpoint through Ingress
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  "http://centrifugo.local:$INGRESS_PORT/connection/websocket"
```

You should see a `101 Switching Protocols` response, confirming WebSocket works through the Ingress.

#### AWS ALB Ingress (EKS)

When using [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/), TLS terminates at the ALB using ACM certificates. Traffic from ALB to pods is HTTP.

```yaml
ingress:
  enabled: true
  ingressClassName: alb
  pathType: Prefix
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    # WebSocket idle timeout (max 4000 seconds for ALB)
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=3600
    # Health check on internal port
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-port: "9000"
    # TLS with ACM certificate
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/xxx
  hosts:
    - host: centrifugo.example.com
      paths:
        - /connection
        - /emulation
```

For IRSA (IAM Roles for Service Accounts) if Centrifugo needs AWS API access:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/centrifugo-role
```

The ALB health check configuration above assumes that the Centrifugo internal port (default 9000) is exposed on the same Service targeted by the Ingress.

If you enable separate Services (serviceInternal.useSeparate, serviceGrpc.useSeparate, or serviceUniGrpc.useSeparate) or override ports, the ALB health check must be updated to target the Service and port that exposes the internal /health endpoint. Otherwise, targets will remain unhealthy.

#### GCP GKE Ingress

GKE Ingress terminates TLS at the Google Cloud Load Balancer. Traffic to pods is HTTP. A `BackendConfig` is required for WebSocket timeout configuration:

First, create a BackendConfig:

```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: centrifugo-backend-config
spec:
  timeoutSec: 86400
  connectionDraining:
    drainingTimeoutSec: 30
```

Then configure the chart to reference it:

```yaml
service:
  annotations:
    cloud.google.com/backend-config: '{"default": "centrifugo-backend-config"}'
    cloud.google.com/neg: '{"ingress": true}'

ingress:
  enabled: true
  ingressClassName: gce
  pathType: Prefix
  annotations:
    kubernetes.io/ingress.global-static-ip-name: centrifugo-ip
  hosts:
    - host: centrifugo.example.com
      paths:
        - /connection
        - /emulation
  tls:
    - secretName: centrifugo-tls
      hosts:
        - centrifugo.example.com
```

For Workload Identity:

```yaml
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: centrifugo@PROJECT_ID.iam.gserviceaccount.com
```

## Production Deployment

This section provides guidance for deploying Centrifugo in production environments. These are starting points—adjust based on your specific workload, traffic patterns, and infrastructure requirements.

### Resource Considerations

Centrifugo is primarily **memory-bound**. Each client connection consumes memory for connection state, buffers, and channel subscriptions. CPU usage is generally low unless you have high message throughput.

**Starting point for resource allocation:**

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 512Mi
    # Note: CPU limits are often omitted intentionally to avoid throttling
```

Key factors affecting resource needs:
- **Connection count** — primary memory driver
- **Message throughput** — affects CPU
- **Channel subscriptions per connection** — additional memory overhead
- **Message size and history** — if using cache/history features
- **Presence information** - if using online presence feature
- Etc.

Monitor actual usage with Prometheus metrics (`centrifugo_node_num_clients`, memory/CPU metrics) and adjust accordingly. See [Centrifugo observability documentation](https://centrifugal.dev/docs/server/observability) for available metrics.

### High Availability Example

For production deployments requiring high availability, you need:

1. **Multiple replicas** with a distributed engine (Redis or NATS)
2. **Pod distribution** across nodes/zones
3. **Disruption budget** for safe rollouts

```yaml
replicaCount: 3

# Distributed engine for multi-replica deployment
config:
  engine:
    type: redis
    redis:
      address: redis://redis-master:6379

# Spread pods across nodes
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: centrifugo

# Alternative: use affinity for hard anti-affinity requirement
# affinity:
#   podAntiAffinity:
#     requiredDuringSchedulingIgnoredDuringExecution:
#       - labelSelector:
#           matchLabels:
#             app.kubernetes.io/name: centrifugo
#         topologyKey: kubernetes.io/hostname

# Ensure minimum availability during updates
podDisruptionBudget:
  enabled: true
  minAvailable: 2  # or use maxUnavailable: 1

# Resource allocation
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 512Mi
```

### Monitoring Distributed Deployments

When running Centrifugo with multiple replicas, proper monitoring is essential. The chart includes built-in support for Prometheus Operator via ServiceMonitor, which automatically discovers and scrapes **each pod individually**.

#### How It Works

The ServiceMonitor selects pods by labels, not services. When you have multiple replicas:
- Prometheus discovers all pods matching the selector
- Each pod becomes a separate scrape target
- Metrics are collected from `http://<pod-ip>:9000/metrics` on each replica
- You can query metrics per-pod or aggregate across all pods

#### Configuration Example

```yaml
# Deploy multiple replicas
replicaCount: 5

# Enable ServiceMonitor for Prometheus Operator
metrics:
  serviceMonitor:
    enabled: true
    interval: 30s
    # IMPORTANT: Match your Prometheus Operator's selector
    additionalLabels:
      release: prometheus  # For kube-prometheus-stack
```

#### Verifying Scrape Targets

After deployment, verify Prometheus is scraping all pods:

1. Check ServiceMonitor was created:
   ```bash
   kubectl get servicemonitor
   ```

2. In Prometheus UI, go to **Status → Targets**
3. Look for targets matching `centrifugo/centrifugo-*`
4. You should see one target per replica (e.g., 5 targets for 5 replicas)

#### Key Metrics for Distributed Setups

Monitor these metrics across all pods:

- `centrifugo_node_num_clients` — connections per pod (should be balanced)
- `centrifugo_node_num_channels` — active channels per pod
- `centrifugo_node_num_subscriptions` — total subscriptions per pod
- `centrifugo_redis_messages_sent_total` — coordination traffic (if using Redis engine)
- Standard resource metrics: `container_memory_usage_bytes`, `container_cpu_usage_seconds_total`

Example PromQL queries:
```promql
# Total connections across all pods
sum(centrifugo_node_num_clients)

# Connection distribution (check balance)
centrifugo_node_num_clients

# Average connections per pod
avg(centrifugo_node_num_clients)
```

See the [Centrifugo observability documentation](https://centrifugal.dev/docs/server/observability) for the complete metrics reference.

### Graceful Shutdown

When a pod terminates, Kubernetes removes it from Service endpoints while simultaneously sending SIGTERM to the container. These operations happen concurrently, creating a race condition where traffic may still be routed to a terminating pod.

The chart by default uses a `preStop` hook that sleeps before SIGTERM is sent, allowing time for endpoint changes to propagate:

The shutdown sequence becomes:
1. Pod marked for termination
2. `preStop` hook runs (sleep) — endpoints propagate during this time
3. SIGTERM sent to Centrifugo
4. Centrifugo stops accepting new connections
5. Existing connections close gracefully
6. Clients reconnect to other pods

The default `terminationGracePeriodSeconds` (30s) includes time for both the `preStop` sleep and Centrifugo's graceful shutdown. For very high connection counts, consider increasing it:

```yaml
terminationGracePeriodSeconds: 60
```

### Health Probes

The chart configures liveness and readiness probes against the `/health` endpoint on the internal port (9000). Default settings work for most deployments.

For environments with slow container starts (large images, slow networks), you can tune the probes:

```yaml
livenessProbe:
  initialDelaySeconds: 5
  periodSeconds: 10

readinessProbe:
  initialDelaySeconds: 3
  periodSeconds: 5
```

### Troubleshooting

**Connections dropping unexpectedly**
- Check Ingress timeout settings (see [Ingress for Public Access](#ingress-for-public-access))
- Verify load balancer idle timeouts
- Ensure `allowed_origins` is configured correctly

**Pods restarting (OOMKilled)**
- Increase memory limits
- Check connection count vs allocated memory
- Review channel subscription patterns

**Scaling not working (messages not delivered across pods)**
- Ensure Redis or NATS engine is configured
- Verify engine connectivity from pods
- Check engine health

**Clients unable to reconnect after pod restart**
- Verify multiple replicas are running
- Check PodDisruptionBudget configuration
- Ensure clients implement reconnection logic

For detailed troubleshooting, check pod logs and Centrifugo metrics. See more guidance in [Centrifugo documentation](https://centrifugal.dev).

## Configuration

Chart follows usual practices when working with Helm. All Centrifugo configuration options can be set via the `config` section. You can set them using custom `values.yaml`:

```yaml
config:
  client:
    allowed_origins:
      - https://example.com
  channel:
    namespaces:
      - name: "chat"
        presence: true
  admin:
    enabled: false
```

And deploy with:

```console
helm install [RELEASE_NAME] -f values.yaml centrifugal/centrifugo
```

Or you can override options using `--set` flag:

```console
helm install [RELEASE_NAME] centrifugal/centrifugo \
  --set config.channel.namespaces[0].name=chat \
  --set config.channel.namespaces[0].presence=true
```

## Secret Management

This chart follows modern Kubernetes secret management practices. **The chart does not create secrets** - you manage them externally and reference them via `existingSecret`, `envSecret`, or `envFrom`.

### Creating Secrets

First, create a Kubernetes secret with your sensitive configuration. Use Centrifugo's environment variable naming format:

```bash
kubectl create secret generic centrifugo-secrets \
  --from-literal=CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY="your-hmac-secret" \
  --from-literal=CENTRIFUGO_ADMIN_PASSWORD="your-admin-password" \
  --from-literal=CENTRIFUGO_ADMIN_SECRET="your-admin-secret" \
  --from-literal=CENTRIFUGO_HTTP_API_KEY="your-api-key"
```

### Referencing Secrets

#### Option 1: Using `existingSecret` (Recommended for simplicity)

The simplest approach - reference an existing secret by name, and all its keys will be loaded as environment variables:

```yaml
existingSecret: "centrifugo-secrets"
```

This automatically loads all environment variables from the secret. Make sure secret keys use Centrifugo's environment variable format (e.g., `CENTRIFUGO_ADMIN_PASSWORD`).

#### Option 2: Using `envSecret` (For granular control)

Reference individual secret keys in your `values.yaml` using `envSecret`:

```yaml
envSecret:
  - name: CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY
    secretKeyRef:
      name: centrifugo-secrets
      key: client.token.hmac_secret_key
  - name: CENTRIFUGO_ADMIN_PASSWORD
    secretKeyRef:
      name: centrifugo-secrets
      key: admin.password
  - name: CENTRIFUGO_ADMIN_SECRET
    secretKeyRef:
      name: centrifugo-secrets
      key: admin.secret
  - name: CENTRIFUGO_HTTP_API_KEY
    secretKeyRef:
      name: centrifugo-secrets
      key: http_api.key
```

### Environment Variable Naming

Any Centrifugo configuration option can be passed as a secret. Convert the config key to environment variable name by:

1. Replace dots with underscores
2. Convert to uppercase
3. Prefix with `CENTRIFUGO_`

**Examples:**

| Config Key | Environment Variable |
|------------|---------------------|
| `client.token.hmac_secret_key` | `CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY` |
| `admin.password` | `CENTRIFUGO_ADMIN_PASSWORD` |
| `admin.secret` | `CENTRIFUGO_ADMIN_SECRET` |
| `http_api.key` | `CENTRIFUGO_HTTP_API_KEY` |
| `grpc_api.key` | `CENTRIFUGO_GRPC_API_KEY` |
| `engine.redis.password` | `CENTRIFUGO_ENGINE_REDIS_PASSWORD` |
| `license` | `CENTRIFUGO_LICENSE` |

See [Centrifugo configuration documentation](https://centrifugal.dev/docs/server/configuration) for environment variable rules.

## Using with HashiCorp Vault

### External Secrets Operator

If you use [External Secrets Operator](https://external-secrets.io/), you can sync secrets from Vault into Kubernetes Secrets and consume them as environment variables. This approach does **not** require overriding the container command.

There are two supported patterns: **individual secret references** and **bulk import with `envFrom`**.

> **Important:**
> When using Vault KV v2, always reference the **logical path** (for example `secret/centrifugo`).
> Do **not** include `/data` — External Secrets Operator handles KV v2 internally.

#### Option 1: Individual Secret References

Create an `ExternalSecret` that maps Vault keys to Kubernetes secret keys:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: centrifugo-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: centrifugo-secrets
    creationPolicy: Owner
  data:
    - secretKey: client.token.hmac_secret_key
      remoteRef:
        key: secret/centrifugo
        property: tokenHmacSecretKey
    - secretKey: admin.password
      remoteRef:
        key: secret/centrifugo
        property: adminPassword
    - secretKey: admin.secret
      remoteRef:
        key: secret/centrifugo
        property: adminSecret
    - secretKey: http_api.key
      remoteRef:
        key: secret/centrifugo
        property: apiKey
```

Then reference each secret individually in your values:

```yaml
envSecret:
  - name: CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY
    secretKeyRef:
      name: centrifugo-secrets
      key: client.token.hmac_secret_key
  - name: CENTRIFUGO_ADMIN_PASSWORD
    secretKeyRef:
      name: centrifugo-secrets
      key: admin.password
  - name: CENTRIFUGO_ADMIN_SECRET
    secretKeyRef:
      name: centrifugo-secrets
      key: admin.secret
  - name: CENTRIFUGO_HTTP_API_KEY
    secretKeyRef:
      name: centrifugo-secrets
      key: http_api.key
```

#### Option 2: Bulk Import with `existingSecret` or `envFrom`

For simpler configuration, import all environment variables from the secret at once. Store secrets in Vault with the proper Centrifugo environment variable names:

In Vault, structure your secrets like this:
```bash
vault kv put secret/centrifugo \
  CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY="your-secret" \
  CENTRIFUGO_ADMIN_PASSWORD="your-password" \
  CENTRIFUGO_ADMIN_SECRET="your-secret" \
  CENTRIFUGO_HTTP_API_KEY="your-api-key"
```

This requires Vault keys to already be valid environment variable names. All Vault keys must match `[A-Z_][A-Z0-9_]*`.

Then create an `ExternalSecret` that extracts all keys:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: centrifugo-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: centrifugo-secrets
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: secret/centrifugo
```

Then reference the secret in your Helm values. You can use either `existingSecret` (simpler) or `envFrom` (more flexible):

**Using `existingSecret` (recommended):**

```yaml
existingSecret: "centrifugo-secrets"
```

**Or using `envFrom` (if you need to combine multiple sources):**

```yaml
envFrom:
  - secretRef:
      name: centrifugo-secrets
```

This approach is cleaner when you have many secrets - you don't need to list each one individually in your Helm values. The keys in the Kubernetes Secret will match the keys in Vault.

## Scale with Redis Engine

First, deploy Redis. This example uses the Bitnami Redis chart:

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis --set auth.enabled=false
```

Then start Centrifugo with `redis` engine and pointing it to Redis:

```console
helm install centrifugo centrifugal/centrifugo \
  --set config.engine.type=redis \
  --set config.engine.redis.address=redis://redis-master:6379 \
  --set replicaCount=3
```

### With Redis Authentication

Create a secret with Redis password:

```bash
kubectl create secret generic redis-credentials \
  --from-literal=engine.redis.password="your-redis-password"
```

Then reference it:

```yaml
config:
  engine:
    type: redis
    redis:
      address: redis://redis-master:6379

envSecret:
  - name: CENTRIFUGO_ENGINE_REDIS_PASSWORD
    secretKeyRef:
      name: redis-credentials
      key: engine.redis.password
```

### With Redis Sentinel

```console
helm install redis bitnami/redis \
  --set auth.enabled=false \
  --set sentinel.enabled=true
```

Then point Centrifugo to Sentinel:

```console
helm install centrifugo centrifugal/centrifugo \
  --set config.engine.type=redis \
  --set "config.engine.redis.address=redis+sentinel://redis:26379?sentinel_master_name=mymaster" \
  --set replicaCount=3
```

### With Redis Cluster

```console
helm install redis bitnami/redis-cluster --set usePassword=false
```

Then point Centrifugo to Redis Cluster (Centrifugo detects cluster mode automatically):

```console
helm install centrifugo centrifugal/centrifugo \
  --set config.engine.type=redis \
  --set config.engine.redis.address=redis://redis-redis-cluster-0:6379 \
  --set replicaCount=3
```

## With NATS Broker

```console
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats --set config.cluster.enabled=true
```

Then start Centrifugo pointing to NATS broker:

```console
helm install centrifugo centrifugal/centrifugo \
  --set config.broker.enabled=true \
  --set config.broker.type=nats \
  --set config.broker.nats.url=nats://nats:4222 \
  --set replicaCount=3
```

## Using initContainers

You can define `initContainers` in your values.yaml to wait for other resources or to do some init jobs. `initContainers` might be useful to wait for your engine to be ready before starting Centrifugo.

### Wait for Redis

```yaml
initContainers:
  - name: wait-for-redis
    image: ghcr.io/patrickdappollonio/wait-for:latest
    env:
      - name: REDIS_ADDRESS
        value: "redis:6379"
    command:
      - /wait-for
    args:
      - --host="$(REDIS_ADDRESS)"
      - --timeout=240s
      - --verbose
```

### Wait for NATS

```yaml
initContainers:
  - name: wait-for-nats
    image: ghcr.io/patrickdappollonio/wait-for:latest
    env:
      - name: NATS_ADDRESS
        value: "nats:4222"
    command:
      - /wait-for
    args:
      - --host="$(NATS_ADDRESS)"
      - --timeout=240s
      - --verbose
```

## Parameters

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global Docker Image registry | `nil` |
| `global.imagePullSecrets` | Global Docker registry secret names as an array | `[]` |

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | String to partially override centrifugo.fullname | `nil` |
| `fullnameOverride` | String to fully override centrifugo.fullname | `nil` |
| `namespaceOverride` | String to override namespace | `nil` |

### Image Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.registry` | Centrifugo image registry | `docker.io` |
| `image.repository` | Centrifugo image name | `centrifugo/centrifugo` |
| `image.tag` | Centrifugo image tag | Chart `appVersion` |
| `image.pullPolicy` | Centrifugo image pull policy | `IfNotPresent` |

### Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config` | Centrifugo configuration (becomes config.json) | See values.yaml |
| `env` | Additional environment variables (non-sensitive) | `{}` |
| `envSecret` | Secret environment variables (reference external secrets) | `[]` |
| `envFrom` | Populate environment variables from ConfigMaps or Secrets | `[]` |

### Deployment Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of Centrifugo replicas | `1` |
| `revisionHistoryLimit` | Number of old ReplicaSets to retain | `10` |
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |
| `topologySpreadConstraints` | Topology spread constraints | `[]` |
| `podDisruptionBudget.enabled` | Enable PodDisruptionBudget | `false` |
| `podDisruptionBudget.minAvailable` | Minimum available pods | `nil` |
| `podDisruptionBudget.maxUnavailable` | Maximum unavailable pods | `nil` |

### Pod-Level Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hostAliases` | Custom host-to-IP mappings | `[]` |
| `runtimeClassName` | Runtime class name (e.g., gvisor, kata-containers) | `""` |
| `shareProcessNamespace` | Share process namespace between containers | `false` |
| `schedulerName` | Custom scheduler name | `""` |
| `overhead` | Resource overhead for VM-based runtimes | `{}` |

### Container-Level Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `terminationMessagePolicy` | How to populate termination message (File, FallbackToLogsOnError) | `""` |
| `lifecycle` | Container lifecycle hooks (preStop, postStart) | `{preStop: {exec: {command: ["/bin/sh", "-c", "sleep 5"]}}}` |

### Health Probes Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe` | Liveness probe configuration (overrides default httpGet) | `{}` |
| `readinessProbe` | Readiness probe configuration (overrides default httpGet) | `{}` |
| `startupProbe` | Startup probe configuration | `{}` |

### Security Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext` | Pod security context | `runAsNonRoot: true` |
| `securityContext` | Container security context | See values.yaml |
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name | `""` |

### Service Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | External service port | `8000` |
| `serviceInternal.port` | Internal service port | `9000` |
| `serviceGrpc.port` | GRPC API service port | `10000` |
| `serviceUniGrpc.port` | Uni GRPC service port | `11000` |

### Metrics Parameters

Centrifugo exposes Prometheus metrics on the internal port (`9000` by default) at `/metrics`. The metrics endpoint is always enabled.

For **Prometheus Operator** integration, enable the ServiceMonitor:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor for Prometheus Operator | `false` |
| `metrics.serviceMonitor.interval` | Scrape interval | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout | not set |
| `metrics.serviceMonitor.namespace` | Namespace for ServiceMonitor (defaults to chart namespace) | `""` |
| `metrics.serviceMonitor.additionalLabels` | Labels for Prometheus Operator selector (e.g., `release: prometheus`) | `{}` |
| `metrics.serviceMonitor.annotations` | Custom annotations | `{}` |
| `metrics.serviceMonitor.honorLabels` | Honor labels from scraped metrics | `false` |
| `metrics.serviceMonitor.relabellings` | Metric relabeling configuration | not set |

**For distributed deployments with multiple replicas**, the ServiceMonitor automatically scrapes each pod individually. See [Monitoring Distributed Deployments](#monitoring-distributed-deployments) for details.

See [values.yaml](values.yaml) for the full list of parameters.

## Upgrading

### v12 -> v13 (Breaking Changes)

Version 13 introduces a simplified approach to secret management, some layout refactorings, better documentation.

**Removed:**
- `secrets.*` - All predefined secret values (tokenHmacSecretKey, adminPassword, etc.)
- Chart no longer creates a Secret resource
- `autoscalingTemplate` - Renamed to `autoscaling.customMetrics` for clarity
- `service.useSeparateInternalService` - Moved to `serviceInternal.useSeparate`
- `service.useSeparateGrpcService` - Moved to `serviceGrpc.useSeparate`
- `service.useSeparateUniGrpcService` - Moved to `serviceUniGrpc.useSeparate`

**Changed:**
- `existingSecret`, `envSecret`, and `envFrom` are now the ways to reference externally-managed secrets (chart no longer creates secrets)
- Security contexts - Removed duplication of `runAsUser`/`runAsNonRoot` between pod and container contexts
- **GRPC API is now opt-in** - The chart no longer passes `--grpc_api.enabled` flag by default. Users must explicitly enable GRPC API in their Centrifugo configuration if needed
- **Port configuration decoupled** - Centrifugo server ports are now separate from Kubernetes service ports. Service ports
  (`service.port`, `serviceInternal.port`, etc.) can now be configured independently from server ports (defined in new `servers` section).
  This allows using the same service port number across different services (e.g., all services can use port 443) since they map to
  different server ports. See [Service Design](#service-design) for details.
- **Service configuration restructured** - Service sections renamed and reorganized for clarity:
  - `internalService` → `serviceInternal` with `useSeparate` field (previously `service.useSeparateInternalService`)
  - `grpcService` → `serviceGrpc` with `useSeparate` field (previously `service.useSeparateGrpcService`)
  - `uniGrpcService` → `serviceUniGrpc` with `useSeparate` field (previously `service.useSeparateUniGrpcService`)
  - All service-specific configuration (port, type, annotations, labels, etc.) now colocated with the `useSeparate` flag in the same section

**Added:**
- `existingSecret` - Simple reference to an external Kubernetes Secret (all keys loaded as environment variables)
- `servers` section - Explicit configuration for Centrifugo server endpoints (external, internal, grpc, uniGrpc) with extensible properties per server
- `envFrom` parameter to populate environment variables from ConfigMaps or Secrets (useful for bulk importing secrets from External Secrets Operator, Sealed Secrets, etc.)
- Pod-level configuration:
  - `runtimeClassName` - Support for gVisor, Kata Containers, etc.
  - `shareProcessNamespace` - For debugging/profiling with sidecars
  - `schedulerName` - Custom scheduler support
  - `overhead` - Resource overhead for VM-based runtimes
  - `hostAliases` - Custom host-to-IP mappings
- Container-level configuration:
  - `terminationMessagePolicy` - Better error visibility
  - `lifecycle` - Full lifecycle hooks support (preStop, postStart)
- Health probes:
  - Fully configurable `livenessProbe`, `readinessProbe`, `startupProbe`
  - Support for all probe types (httpGet, exec, grpc, tcpSocket)
  - Maintains backward compatibility with default httpGet probes
- Consistent `clusterIP` support for all services (`service`, `serviceInternal`, `serviceGrpc`, `serviceUniGrpc`)
- ServiceMonitor now includes `path: /metrics` and respects `serviceInternal.probeScheme` for HTTPS
- `revisionHistoryLimit` parameter for Deployment cleanup
- `podDisruptionBudget.maxUnavailable` option (alternative to `minAvailable`)
- Default security contexts (`runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, drop all capabilities)
- Common labels (`app.kubernetes.io/part-of`, `app.kubernetes.io/component`)
- Improved post-install notes with internal endpoints and verification commands

**Fixed:**
- Removed unused `metrics.enabled` option (metrics endpoint is always enabled on internal port, use `metrics.serviceMonitor.enabled` to create ServiceMonitor)
- PodDisruptionBudget now uses namespace helper (supports `namespaceOverride`)
- Consistent use of `nindent` across all templates
- Consistent API version detection using `APIVersions.Has` pattern
- Removed deprecated `engine: gotpl` from Chart.yaml
- Chart.yaml upgraded to `apiVersion: v2` with `type`, `keywords`, and `sources`
- `topologySpreadConstraints` and `initContainers` now use proper list type (`[]`) instead of string

**Migration Guide:**

**If you use GRPC API:** You must now explicitly enable it in your configuration:

```yaml
config:
  grpc_api:
    enabled: true
```

Without this configuration, GRPC API will not be available even though the port is still exposed on the service.

**For secrets management:**

1. Create your own Kubernetes secret:

```bash
kubectl create secret generic centrifugo-secrets \
  --from-literal=client.token.hmac_secret_key="your-value" \
  --from-literal=admin.password="your-value" \
  --from-literal=admin.secret="your-value" \
  --from-literal=http_api.key="your-value"
```

2. Update your values.yaml:

**Before (v12):**
```yaml
secrets:
  tokenHmacSecretKey: "your-value"
  adminPassword: "your-value"
  adminSecret: "your-value"
  apiKey: "your-value"
```

**After (v13):**
```yaml
envSecret:
  - name: CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY
    secretKeyRef:
      name: centrifugo-secrets
      key: client.token.hmac_secret_key
  - name: CENTRIFUGO_ADMIN_PASSWORD
    secretKeyRef:
      name: centrifugo-secrets
      key: admin.password
  - name: CENTRIFUGO_ADMIN_SECRET
    secretKeyRef:
      name: centrifugo-secrets
      key: admin.secret
  - name: CENTRIFUGO_HTTP_API_KEY
    secretKeyRef:
      name: centrifugo-secrets
      key: http_api.key
```

**Alternative: Using `existingSecret` (simpler):**

If you prefer a simpler approach, create a secret with environment variable names and use `existingSecret`:

```bash
kubectl create secret generic centrifugo-secrets \
  --from-literal=CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY="your-value" \
  --from-literal=CENTRIFUGO_ADMIN_PASSWORD="your-value" \
  --from-literal=CENTRIFUGO_ADMIN_SECRET="your-value" \
  --from-literal=CENTRIFUGO_HTTP_API_KEY="your-value"
```

```yaml
existingSecret: "centrifugo-secrets"
```

This loads all keys from the secret as environment variables. Note: Secret keys must use Centrifugo's environment variable format (uppercase with `CENTRIFUGO_` prefix).

**For service configuration:**

If you were using separate services, the configuration structure has changed. Service sections were renamed and the `useSeparate*` flags moved into each service section:

**Before (v12):**
```yaml
service:
  useSeparateInternalService: true  # Flag was here
  useSeparateGrpcService: false

internalService:  # Old name
  port: 9000
  type: ClusterIP
  annotations: {}

grpcService:  # Old name
  port: 10000
  type: ClusterIP
```

**After (v13):**
```yaml
service:
  # useSeparate flags removed from here

serviceInternal:  # New name (renamed from internalService)
  useSeparate: true  # Flag moved here
  port: 9000
  type: ClusterIP
  annotations: {}

serviceGrpc:  # New name (renamed from grpcService)
  useSeparate: false  # Flag moved here
  port: 10000
  type: ClusterIP
```

The same pattern applies to `uniGrpcService` → `serviceUniGrpc`.

**For port configuration:**

If you were using default ports, no action is required. The defaults remain the same (8000, 9000, 10000, 11000).

If you customized ports in v12, the configuration structure has changed:

**Before (v12):**
```yaml
service:
  port: 8080  # This set both service AND container port
internalService:
  port: 9090  # This set both service AND container port
```

**After (v13):**
```yaml
# Centrifugo server ports (what Centrifugo listens on inside the container)
servers:
  external:
    port: 8080
  internal:
    port: 9090
    scheme: HTTP
  grpc:
    port: 10000
  uniGrpc:
    port: 11000

# Kubernetes service ports (external-facing ports, can be different from server ports)
service:
  port: 8080  # Or any port, e.g., 443
serviceInternal:
  port: 9090  # Or any port
```

**New capability:** You can now use the same service port across different services:
```yaml
servers:
  external:
    port: 8000  # Server ports must be different
  internal:
    port: 9000

service:
  port: 443  # All services can use the same port

serviceInternal:
  useSeparate: true
  port: 443  # Same as main service port (different Service object)
```

**For probe scheme (HTTP/HTTPS):**

If you were using HTTPS for the internal port:

**Before (v12):**
```yaml
internalService:
  probeScheme: HTTPS
```

**After (v13):**
```yaml
servers:
  internal:
    scheme: HTTPS
```

### v11 -> v12

In v12 we are using Centrifugo v6 as base appVersion. See [Centrifugo v6.0.0 release blog post](https://centrifugal.dev/blog/2025/01/16/centrifugo-v6-released) and [migration guide](https://centrifugal.dev/docs/getting-started/migration_v6) for more details.

You need to update Centrifugo configuration according to new v6 configuration format.

### v10 -> v11

Major bump to 11.0.0 caused by breaking change in horizontal pod autoscaling configuration. CPU scaling should be explicitly enabled now, cpu and memory configuration moved to nested object.

### v9 -> v10

In v10 we are using Centrifugo v5 as base appVersion. See [Centrifugo v5.0.0 release notes](https://github.com/centrifugal/centrifugo/releases/tag/v5.0.0).

### v8 -> v9

In v9 we are using Centrifugo v4 as base appVersion. See [Centrifugo v4.0.0 release notes](https://github.com/centrifugal/centrifugo/releases/tag/v4.0.0).
