# Centrifugo

This chart bootstraps a [Centrifugo](https://centrifugal.github.io/centrifugo/) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.9+

## Get Repo Info

```console
helm repo add centrifugal https://centrifugal.github.io/helm-charts
helm repo update
```

_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._

## Install Chart

```console
# Helm 3
$ helm install [RELEASE_NAME] centrifugal/centrifugo

# Helm 2
$ helm install --name [RELEASE_NAME] centrifugal/centrifugo
```

_See [configuration](#configuration) below._

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

## Uninstall Chart

```console
# Helm 3
$ helm uninstall [RELEASE_NAME]

# Helm 2
# helm delete --purge [RELEASE_NAME]
```

This removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._

## Upgrading Chart

```console
# Helm 3 or 2
$ helm upgrade [RELEASE_NAME] [CHART] --install
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Parameters

The following table lists the configurable parameters of the Centrifugo chart and their default values.

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `global.imageRegistry`                      | Global Docker Image registry                                                                                         | `nil`                                                        |
| `global.imagePullSecrets`                   | Global Docker registry secret names as an array                                                                      | `[]` (does not add image pull secrets to deployed pods)      |
### Common parameters

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `nameOverride`                              | String to partially override centrifugo.fullname                                                                        | `nil`                                                        |
| `fullnameOverride`                          | String to fully override centrifugo.fullname                                                                            | `nil`                                                        |

### Centrifugo common parameters

| Parameter                                   | Description                                                                                                             | Default                                                      |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `image.registry`                            | Centrifugo image registry                                                                                               | `docker.io`                                                  |
| `image.repository`                          | Centrifugo image name                                                                                                   | `centrifugo/centrifugo`                                            |
| `image.tag`                                 | Centrifugo image tag                                                                                                    | Taken from chart `appVersion`                                                 |
| `image.pullPolicy`                          | Centrifugo image pull policy                                                                                            | `IfNotPresent`                                               |
| `image.pullSecrets`                         | Specify docker-registry secret names as an array                                                                        | `[]` (does not add image pull secrets to deployed pods)      |
| `service.type`                              | service type                                                                                                            | `ClusterIP`                                                  |
| `service.clusterIP`                         | service clusterIP IP                                                                                                    | `nil`                                                        |
| `service.port`                              | service port                                                                                                            | `8000`                                                       |
| `service.nodePort`                          | K8s service node port                                                                                                   | `nil`                                                        |
| `service.appProtocol`                       | Set appProtocol field for port - it could be useful for manually setting protocols for Istio                            | `nil`                                                        |
| `service.useSeparateInternalService`        | Use separate service for internal endpoints. It could be useful for configuring same port number for all services.      | `false`                                                      |
| `service.useSeparateGrpcService`            | Use separate service for GRPC endpoints. It could be useful for configuring same port number for all services.          | `false`                                                      |
| `service.useSeparateUniGrpcService`            | Use separate service for GRPC uni stream. It could be useful for configuring same port number for all services.          | `false`                                                      |
| `internalService.type`                      | internal (for API, Prometheus metrics, admin web interface, health checks) port service type                            | `ClusterIP`                                                  |
| `internalService.clusterIP`                 | internal (for API, Prometheus metrics, admin web interface, health checks) service clusterIP IP                         | `nil`                                                        |
| `internalService.port`                      | internal (for API, Prometheus metrics, admin web interface, health checks) service port                                 | `9000`                                                       |
| `internalService.nodePort`                  | internal (for API, Prometheus metrics, admin web interface, health checks) K8s service node port                        | `nil`                                                        |
| `internalService.appProtocol`               | Set appProtocol field for port                                                                                          | `nil`                                                        |
| `grpcService.type`                          | GRPC API port service type                                                                                              | `ClusterIP`                                                  |
| `grpcService.clusterIP`                     | GRPC API service clusterIP IP                                                                                           | `nil`                                                        |
| `grpcService.port`                          | GRPC API service port                                                                                                   | `10000`                                                      |
| `grpcService.nodePort`                      | GRPC API K8s service node port                                                                                          | `nil`                                                        |
| `grpcService.appProtocol`                   | Set appProtocol field for port                                                                                          | `nil`                                                        |
| `env`                                       | Additional environment variables to be passed to Centrifugo container.                                                  | `nil`                                                        |
| `config`                                    | Centrifugo configuration, will be transformed into config.json file                                                     | `{"admin":true,"engine":"memory","namespaces":[],"v3_use_offset":true}`                                                        |
| `existingSecret`                            | Name of existing secret to use for secret's parameters. The secret has to contain the keys below                        | `nil`                                                         |
| `initContainers`                             | Set initContainers, e.g. wait for other resources                                                                      | `nil`                                                         |
| `secrets.tokenHmacSecretKey`                 | Secret key for HMAC tokens.                                                                                             | `nil`                                                         |
| `secrets.adminPassword`                      | Admin password used to protect access to web interface.                                                                 | `nil`                                                         |
| `secrets.adminSecret`                        | Admin secret used to create auth tokens on user login into admin web interface.                                         | `nil`                                                         |
| `secrets.apiKey`                             | Centrifugo api_key for Centrifugo API endpoint authorization.                                                           | `nil`                                                         |
| `secrets.grpcApiKey`                         | Centrifugo grpc_api_key for Centrifugo GRPC API authorization.                                                          | `nil`                                                         |
| `secrets.redisAddress`                           | Connection string to Redis.                                                                                             | `nil`                                                         |
| `secrets.redisPassword`                      | Password for Redis.                                                                                                     | `nil`                                                         |
| `secrets.redisSentinelPassword`                      | Password for Redis Sentinel.                                                                                                     | `nil`                                                         |
| `secrets.natsUrl`                            | Connection string to Nats.                                                                                              | `nil`                                                         |
| `secrets.license`                            | Centrifugo PRO license                                                                                              | `nil`                                                         |

### Metrics parameters

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `metrics.enabled`                           | Start a side-car prometheus exporter                                                                                 | `false`                                                      |
| `metrics.serviceMonitor.enabled`            | Create ServiceMonitor Resource for scraping metrics using PrometheusOperator                                         | `false`                                                      |
| `metrics.serviceMonitor.namespace`          | Namespace which Prometheus is running in                                                                             | `nil`                                                        |
| `metrics.serviceMonitor.interval`           | Interval at which metrics should be scraped                                                                          | `30s`                                                        |
| `metrics.serviceMonitor.scrapeTimeout`      | Specify the timeout after which the scrape is ended                                                                  | `nil`                                                        |
| `metrics.serviceMonitor.relabellings`       | Specify Metric Relabellings to add to the scrape endpoint                                                            | `nil`                                                        |
| `metrics.serviceMonitor.honorLabels`        | honorLabels chooses the metric's labels on collisions with target labels.                                            | `false`                                                      |
| `metrics.serviceMonitor.additionalLabels`   | Used to pass Labels that are required by the Installed Prometheus Operator                                           | `{}`                                                         |

_See [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) for command documentation._

## Concepts

This chart by default starts Centrifugo with Memory engine. This means that you can only run one Centrifugo instance pod in default setup. If you need to run more pods to scale and load-balance connections between them – run Centrifugo with Redis engine or with Nats broker (for at most once PUB/SUB only). See examples below.

Centrifugo service exposes 3 ports:

* for client connections from the outside of your cluster. This is called external port: 8000 by default.
* internal port for API, Prometheus metrics, admin web interface, health checks. So these endpoints not available from the outside when enabling ingress. This is called internal port: 9000 by default.
* GRPC API port: 10000 by default.

Ingress proxies on external port.

## Configuration

Chart follows usual practices when working with Helm. All Centrifugo configuration options can be set. You can set them using custom `values.yaml`:

```yaml
config:
  admin: false
  namespaces:
      - name: "chat"
      - presence: true
```

And deploy with:

```console
helm install [RELEASE_NAME] -f values.yaml centrifugal/centrifugo
```

Or you can override options using `--set` flag, for example:

```console
helm install [RELEASE_NAME] centrifugal/centrifugo --set config.namespaces[0].name=chat --set config.namespaces[0].presence=true
```

This chart also defines several secrets. For example here is an example that configures HTTP API key and token HMAC secret key.

```console
helm install [RELEASE_NAME] centrifugal/centrifugo --set secrets.apiKey=<YOUR_SECRET_API_KEY> --set secrets.tokenHmacSecretKey=<YOUR_SECRET_TOKEN_SECRET_KEY>
```

See full list of supported secrets inside chart [values.yaml](https://github.com/centrifugal/helm-charts/blob/master/charts/centrifugo/values.yaml).

## Scale with Redis engine

Run Redis (here we are using Redis chart from bitnami, but you can use any other Redis deployment):

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis --set auth.enabled=false
```

Then start Centrifugo with `redis` engine and pointing it to Redis:

```console
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_address=redis://redis-master:6379 --set replicaCount=3
```

Now example with Redis Sentinel (again using chart from bitnami):

```console
helm install redis bitnami/redis --set auth.enabled=false --set cluster.enabled=true --set sentinel.enabled=true
```

Then point Centrifugo to Sentinel:

```console
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_sentinel_master_name=mymaster --set config.redis_sentinel_address=redis:26379 --set replicaCount=3
```

Example with Redis Cluster (using `bitnami/redis-cluster` chart, but again the way you run Redis is up to you actually):

```console
helm install redis bitnami/redis-cluster --set usePassword=false
```

Then point Centrifugo to Redis Cluster:

```console
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_cluster_address=redis-redis-cluster-0:6379 --set replicaCount=3
```

Note: it's possible to set Redis URL and Redis/Sentinel passwords over secrets if needed.

## With Nats broker

```console
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats --set cluster.enabled=true
```

Then start Centrifugo pointing to Nats broker:

```console
helm install centrifugo -f values.yaml ./centrifugo --set config.broker=nats --set config.nats_url=nats://nats:4222 --set replicaCount=3
```

Note: it's possible to set Nats URL over secrets if needed.

## Using initContainers

You can define `initContainers` in your values.yaml to wait for other resources or to do some init jobs. `initContainers` might be useful to wait for your engine to be ready before starting centrifugo.

### Redis

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

### Example Nats

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

## Upgrading

### v8 -> v9

In v9 we are using Centrifugo v4 as base appVersion. See [Centrifugo v4.0.0 release notes](https://github.com/centrifugal/centrifugo/releases/tag/v4.0.0).

### v7 -> v8

In v8 version we are fixing an inconsistency in `existingSecret` option names reported in [#33](https://github.com/centrifugal/helm-charts/issues/33).

So, in `existingSecret`:

* admin_password -> adminPassword
* admin_secret -> adminSecret
* token_hmac_secret_key -> tokenHmacSecretKey
* api_key -> apiKey
* grpc_api_key -> grpcApiKey
* redis_address -> redisAddress
* redis_password -> redisPassword
* redis_sentinel_password -> redisSentinelPassword
* nats_url -> natsUrl

### v5 -> v6

v6 aims to simplify chart configuration and make it a bit more idiomatic. See pull request [#6](https://github.com/centrifugal/helm-charts/pull/6) for all the changes.

- Several parameters were renamed or disappeared in favor of new ones on this major version:
  - Three type of services were moved to their own block.
  - To enable separate services use `useSeparateInternalService` and `useSeparateGrpcService` and `useSeparateUniGrpcService` flags.
  - `ServiceMonitor` move to block `metrics` with additional parameters, `labels` renamed to `additionalLabels`  - removed configuration block `centrifugo`, all configuration under that block moved to top level.

[On November 13, 2020, Helm v2 support was formally finished](https://github.com/helm/charts#status-of-the-project), this major version is the result of the required changes applied to the Helm Chart to be able to incorporate the different features added in Helm v3 and to be consistent with the Helm project itself regarding the Helm v2 EOL.
