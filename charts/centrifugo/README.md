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
- [Production Deployment](#production-deployment)
  - [Resource Considerations](#resource-considerations)
  - [High Availability Example](#high-availability-example)
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

# Open admin web interface in browser
open http://localhost:9000
# Login with password: admin
```

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

Centrifugo exposes 4 ports, each serving different purposes:

```text
                                    ┌─────────────────────────────────────┐
                                    │           Centrifugo Pod            │
                                    │                                     │
┌─────────────┐    Ingress          │  ┌───────────────────────────────┐  │
│   Clients   │───────────────────────▶│  External (8000)              │  │
│  (browser)  │    WebSocket/       │  │  - Client connections         │  │
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
│  Services   │    (ClusterIP)      │  │  - Bidirectional GRPC API     │  │
└─────────────┘                     │  └───────────────────────────────┘  │
                                    │                                     │
┌─────────────┐    Ingress          │  ┌───────────────────────────────┐  │
│   Clients   │───────────────────────▶│  Uni GRPC (11000)             │  │
│  (mobile)   │    gRPC stream      │  │  - Unidirectional GRPC stream │  │
└─────────────┘                     │  └───────────────────────────────┘  │
                                    │                                     │
                                    └─────────────────────────────────────┘
```

### Service Design

By default, **all ports are exposed via a single Kubernetes Service**. This is simple and works for most cases.

For advanced deployments, you can split ports into **separate Services** using:

```yaml
service:
  useSeparateInternalService: true   # Creates centrifugo-internal service
  useSeparateGrpcService: true       # Creates centrifugo-grpc service
  useSeparateUniGrpcService: true    # Creates centrifugo-uni-grpc service
```

**Why separate services?**

| Use Case | Solution |
|----------|----------|
| Use same port (e.g., 443) for all services with different hostnames | Separate services + separate Ingresses |
| Different load balancing for GRPC vs HTTP | Separate services with different annotations |
| Restrict internal API access with NetworkPolicy | Separate internal service to target with policy |
| Different service types (LoadBalancer for external, ClusterIP for internal) | Separate services with different types |

### Scaling

This chart by default starts Centrifugo with **Memory engine** - only one pod can run.

To scale horizontally, use **Redis engine** or **NATS broker**:

```bash
# With Redis
helm install centrifugo centrifugal/centrifugo \
  --set config.engine.type=redis \
  --set config.engine.redis.address=redis://redis:6379 \
  --set replicaCount=3

# With NATS (at-most-once delivery only)
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
  annotations:
    haproxy.org/timeout-tunnel: "3600s"
  hosts:
    - host: centrifugo.example.com
      paths:
        - /connection
        - /emulation
```

Ensure your Ingress Controller deployment has appropriate resource limits and system settings. See [Centrifugo infrastructure tuning guide](https://centrifugal.dev/docs/server/infra_tuning) for details.

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

### Graceful Shutdown

When a pod terminates, Kubernetes removes it from Service endpoints while simultaneously sending SIGTERM to the container. These operations happen concurrently, creating a race condition where traffic may still be routed to a terminating pod.

The chart includes a `preStop` hook that sleeps before SIGTERM is sent, allowing time for endpoint changes to propagate:

```yaml
# Default: 5 seconds (set to 0 to disable)
preStopSleepSeconds: 5
```

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

This chart follows modern Kubernetes secret management practices. **The chart does not create secrets** - you manage them externally and reference them via `envSecret`.

### Creating Secrets

First, create a Kubernetes secret with your sensitive configuration:

```bash
kubectl create secret generic centrifugo-secrets \
  --from-literal=client.token.hmac_secret_key="your-hmac-secret" \
  --from-literal=admin.password="your-admin-password" \
  --from-literal=admin.secret="your-admin-secret" \
  --from-literal=http_api.key="your-api-key"
```

### Referencing Secrets

Reference secrets in your `values.yaml` using `envSecret`:

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

### Vault Agent Injector

If you have the [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector) installed, you can inject secrets directly into pods:

```yaml
podAnnotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "centrifugo"
  vault.hashicorp.com/agent-inject-secret-config: "secret/data/centrifugo"
  vault.hashicorp.com/agent-inject-template-config: |
    {{- with secret "secret/data/centrifugo" -}}
    export CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY="{{ .Data.data.tokenHmacSecretKey }}"
    export CENTRIFUGO_ADMIN_PASSWORD="{{ .Data.data.adminPassword }}"
    export CENTRIFUGO_ADMIN_SECRET="{{ .Data.data.adminSecret }}"
    export CENTRIFUGO_HTTP_API_KEY="{{ .Data.data.apiKey }}"
    {{- end }}
```

### External Secrets Operator

If you use [External Secrets Operator](https://external-secrets.io/), first create an `ExternalSecret`:

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
        key: secret/data/centrifugo
        property: tokenHmacSecretKey
    - secretKey: admin.password
      remoteRef:
        key: secret/data/centrifugo
        property: adminPassword
    - secretKey: admin.secret
      remoteRef:
        key: secret/data/centrifugo
        property: adminSecret
    - secretKey: http_api.key
      remoteRef:
        key: secret/data/centrifugo
        property: apiKey
```

Then reference the created secret in your values:

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
  --set cluster.enabled=true \
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
helm install nats nats/nats --set cluster.enabled=true
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
| `internalService.port` | Internal service port | `9000` |
| `grpcService.port` | GRPC API service port | `10000` |
| `uniGrpcService.port` | Uni GRPC service port | `11000` |

### Metrics Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor for Prometheus Operator | `false` |
| `metrics.serviceMonitor.interval` | Scrape interval | `30s` |

See [values.yaml](values.yaml) for the full list of parameters.

## Upgrading

### v12 -> v13 (Breaking Changes)

Version 13 introduces a simplified, modern approach to secret management:

**Removed:**
- `secrets.*` - All predefined secret values (tokenHmacSecretKey, adminPassword, etc.)
- `existingSecret` - Reference to chart-managed secret
- Chart no longer creates a Secret resource

**Changed:**
- `envSecret` - Now the primary way to reference secrets (structure simplified)

**Added:**
- Consistent `clusterIP` support for all services (`service`, `internalService`, `grpcService`, `uniGrpcService`)
- ServiceMonitor now includes `path: /metrics` and respects `internalService.probeScheme` for HTTPS
- `revisionHistoryLimit` parameter for Deployment cleanup
- `podDisruptionBudget.maxUnavailable` option (alternative to `minAvailable`)
- Default security contexts (`runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, drop all capabilities)
- Common labels (`app.kubernetes.io/part-of`, `app.kubernetes.io/component`)
- Improved post-install notes with internal endpoints and verification commands
- `preStopSleepSeconds` (default: 5) — preStop hook to avoid endpoint propagation race condition during pod termination

**Fixed:**
- Removed unused `metrics.enabled` option (metrics endpoint is always enabled on internal port, use `metrics.serviceMonitor.enabled` to create ServiceMonitor)
- PodDisruptionBudget now uses namespace helper (supports `namespaceOverride`)
- Consistent use of `nindent` across all templates
- Consistent API version detection using `APIVersions.Has` pattern
- Removed deprecated `engine: gotpl` from Chart.yaml
- Chart.yaml upgraded to `apiVersion: v2` with `type`, `keywords`, and `sources`
- `topologySpreadConstraints` and `initContainers` now use proper list type (`[]`) instead of string

**Migration Guide:**

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

If you were using `existingSecret`, you now reference the secret keys directly:

**Before (v12):**
```yaml
existingSecret: my-secret
```

**After (v13):**
```yaml
envSecret:
  - name: CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY
    secretKeyRef:
      name: my-secret
      key: tokenHmacSecretKey  # use whatever key names exist in your secret
  # ... add other keys as needed
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
