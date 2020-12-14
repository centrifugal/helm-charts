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
| `image.tag`                                 | Centrifugo image tag                                                                                                    | `{TAG_NAME}`                                                 |
| `image.pullPolicy`                          | Centrifugo image pull policy                                                                                            | `IfNotPresent`                                               |
| `image.pullSecrets`                         | Specify docker-registry secret names as an array                                                                        | `[]` (does not add image pull secrets to deployed pods)      |
| `service.type`                              | service type                                                                                                            | `ClusterIP`                                                  |
| `service.clusterIP`                         | service clusterIP IP                                                                                                    | `nil`                                                        |
| `service.port`                              | service port                                                                                                            | `8000`                                                       |
| `service.nodePort`                          | K8s service node port                                                                                                   | `nil`                                                        |
| `service.useSeparateInternalService`        | Use separate service for internal endpoints. It could be useful for configuring same port number for all services.      | `false`                                                      |
| `service.useSeparateGrpcService`            | Use separate service for GRPC endpoints. It could be useful for configuring same port number for all services.          | `false`                                                      |
| `internalService.type`                      | internal (for API, Prometheus metrics, admin web interface, health checks) port service type                            | `ClusterIP`                                                  |
| `internalService.clusterIP`                 | internal (for API, Prometheus metrics, admin web interface, health checks) service clusterIP IP                         | `nil`                                                        |
| `internalService.port`                      | internal (for API, Prometheus metrics, admin web interface, health checks) service port                                 | `9000`                                                       |
| `internalService.nodePort`                  | internal (for API, Prometheus metrics, admin web interface, health checks) K8s service node port                        | `nil`                                                        |
| `grpcService.type`                          | GRPC API port service type                                                                                              | `ClusterIP`                                                  |
| `grpcService.clusterIP`                     | GRPC API service clusterIP IP                                                                                           | `nil`                                                        |
| `grpcService.port`                          | GRPC API service port                                                                                                   | `10000`                                                      |
| `grpcService.nodePort`                      | GRPC API K8s service node port                                                                                          | `nil`                                                        |
| `env`                                       | Additional environment variables to be passed to Centrifugo container.                                                  | `nil`                                                        |
| `config`                                    | Centrifugo configuration, will be transformed into config.json file                                                     | `{"admin":true,"broker":"","engine":"memory","namespaces":[],"v3_use_offset":true}`                                                        |
| `existingSecret`                            | Name of existing secret to use for secret's parameters. The secret has to contain the keys below                        | `nil`                                                         |
| `secret.tokenHmacSecretKey`                 | Secret key for HMAC tokens.                                                                                             | `nil`                                                         |
| `secret.adminPassword`                      | Admin password used to protect access to web interface.                                                                 | `nil`                                                         |
| `secret.adminSecret`                        | Admin secret used to create auth tokens on user login into admin web interface.                                         | `nil`                                                         |
| `secret.apiKey`                             | Centrifugo api_key for Centrifugo API endpoint authorization.                                                           | `nil`                                                         |
| `secret.grpcApiKey`                         | Centrifugo grpc_api_key for Centrifugo GRPC API authorization.                                                          | `nil`                                                         |
| `secret.redisUrl`                           | Connection string to Redis.                                                                                             | `nil`                                                         |
| `secret.redisPassword`                      | Password for Redis.                                                                                                     | `nil`                                                         |
| `secret.natsUrl`                            | Connection string to Nats.                                                                                              | `nil`                                                         |


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
| `metrics.serviceMonitor.release`            | Used to pass Labels release that sometimes should be custom for Prometheus Operator                                  | `nil`                                                        |


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
        publish: true
```

And deploy with:

```console
helm install [RELEASE_NAME] -f values.yaml centrifugal/centrifugo
```

Or you can override options using `--set` flag, for example:

```console
helm install [RELEASE_NAME] centrifugal/centrifugo --set config.namespaces[0].name=chat --set config.namespaces[0].publish=true
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
helm install redis bitnami/redis --set usePassword=false
```

Then start Centrifugo with `redis` engine and pointing it to Redis:

```console
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_url=redis://redis-master:6379 --set replicaCount=3
```

Now example with Redis Sentinel (again using chart from bitnami):

```console
helm install redis bitnami/redis --set usePassword=false --set cluster.enabled=true --set sentinel.enabled=true
```

Then point Centrifugo to Sentinel:

```console
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_master_name=mymaster --set config.redis_sentinels=redis:26379 --set replicaCount=3
```

Example with Redis Cluster (using `bitnami/redis-cluster` chart, but again the way you run Redis is up to you actually):

```console
helm install redis bitnami/redis-cluster --set usePassword=false
```

Then point Centrifugo to Redis Cluster:

```console
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_cluster_addrs=redis-redis-cluster-0:6379 --set replicaCount=3
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

## Upgrading

### To 6.0.0
- Several parameters were renamed or disappeared in favor of new ones on this major version:
  - Three type of services were move to their own block.
  - To enable separate service use `useSeparateInternalService` and `useSeparateGrpcService` flags.
  - `ServiceMonitor` move to block `metrics` with additional parameters, `labels` renamed to `additionalLabels`  - removed configuration block `centrifugo`, all configuration under that block move to top level.

[On November 13, 2020, Helm v2 support was formally finished](https://github.com/helm/charts#status-of-the-project), this major version is the result of the required changes applied to the Helm Chart to be able to incorporate the different features added in Helm v3 and to be consistent with the Helm project itself regarding the Helm v2 EOL.