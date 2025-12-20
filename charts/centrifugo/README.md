# Centrifugo

This chart bootstraps a [Centrifugo](https://centrifugal.dev) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.21+
- Helm 3+

## Get Repo Info

```console
helm repo add centrifugal https://centrifugal.github.io/helm-charts
helm repo update
```

_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._

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

This chart by default starts Centrifugo with Memory engine. This means that you can only run one Centrifugo instance pod in default setup. If you need to run more pods to scale and load-balance connections between them - run Centrifugo with Redis engine or with Nats broker (for at most once PUB/SUB only). See examples below.

Centrifugo service exposes several ports:

- **External port (8000)**: for client connections from outside your cluster
- **Internal port (9000)**: for API, Prometheus metrics, admin web interface, health checks (not exposed via ingress by default)
- **GRPC API port (10000)**: for GRPC API
- **Uni GRPC port (11000)**: for unidirectional GRPC stream

Ingress proxies on external port only.

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
      - presence: true
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

See [Centrifugo configuration documentation](https://centrifugal.dev/docs/server/configuration) for all available options.

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

Run Redis (here we are using Redis chart from bitnami, but you can use any other Redis deployment):

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

Then point Centrifugo to Redis Cluster:

```console
helm install centrifugo centrifugal/centrifugo \
  --set config.engine.type=redis \
  --set config.engine.redis.address=redis+cluster://redis-redis-cluster-0:6379 \
  --set replicaCount=3
```

## With Nats Broker

```console
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats --set cluster.enabled=true
```

Then start Centrifugo pointing to Nats broker:

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
| `metrics.enabled` | Enable metrics | `false` |
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

**Fixed:**
- Removed unused `metrics.enabled` option (metrics endpoint is always enabled on internal port, use `metrics.serviceMonitor.enabled` to create ServiceMonitor)

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
