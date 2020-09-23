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
centrifugo:
  config:
      admin: false
      namespaces:
          - name: "chat"
            publish: true
```

And deploy with:

```
helm install [RELEASE_NAME] -f values.yaml centrifugal/centrifugo
```

Or you can override options using `--set` flag, for example:

```
helm install [RELEASE_NAME] centrifugal/centrifugo --set centrifugo.config.namespaces[0].name=chat --set centrifugo.config.namespaces[0].publish=true
```

This chart also defines several secrets. For example here is an example that configures HTTP API key and token HMAC secret key.

```
helm install [RELEASE_NAME] centrifugal/centrifugo --set centrifugo.secrets.apiKey=<YOUR_SECRET_API_KEY> --set centrifugo.secrets.tokenHmacSecretKey=<YOUR_SECRET_TOKEN_SECRET_KEY> 
```

See full list of supported secrets inside chart [values.yaml](https://github.com/centrifugal/helm-charts/blob/master/charts/centrifugo/values.yaml).

## Scale with Redis engine

Run Redis (here we are using Redis chart from bitnami, but you can use any other Redis deployment):

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis --set usePassword=false
```

Then start Centrifugo with `redis` engine and pointing it to Redis:

```
helm install centrifugo -f values.yaml ./centrifugo --set centrifugo.config.engine=redis --set centrifugo.config.redis_url=redis://redis-master:6379 --set replicaCount=3
```

Now example with Redis Sentinel (again using chart from bitnami):

```
helm install redis bitnami/redis --set usePassword=false --set cluster.enabled=true --set sentinel.enabled=true
```

Then point Centrifugo to Sentinel:

```
helm install centrifugo -f values.yaml ./centrifugo --set centrifugo.config.engine=redis --set centrifugo.config.redis_master_name=mymaster --set centrifugo.config.redis_sentinels=redis:26379 --set replicaCount=3
```

Example with Redis Cluster (using `bitnami/redis-cluster` chart, but again the way you run Redis is up to you actually):

```
helm install redis bitnami/redis-cluster --set usePassword=false
```

Then point Centrifugo to Redis Cluster:

```
helm install centrifugo -f values.yaml ./centrifugo --set centrifugo.config.engine=redis --set centrifugo.config.redis_cluster_addrs=redis-redis-cluster-0:6379 --set replicaCount=3
```

Note: it's possible to set Redis URL and Redis/Sentinel passwords over secrets if needed.

## With Nats broker

```
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats --set cluster.enabled=true
```

Then start Centrifugo pointing to Nats broker:

```
helm install centrifugo -f values.yaml ./centrifugo --set centrifugo.config.broker=nats --set centrifugo.config.nats_url=nats://nats:4222 --set replicaCount=3
```

Note: it's possible to set Nats URL over secrets if needed.
