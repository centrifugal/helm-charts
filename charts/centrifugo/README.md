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

Chart splits Centrifugo instance into 2 different services:

* one for client connections from the outside of your cluster
* internal service for API, metrics, admin web interface, health checks (so these endpoints not available from outside when using ingress)

## Configuration

Chart follows usual practices when working with Helm. All Centrifugo configuration options can be set. You can set them using custom `values.yaml`:

```yaml
config:
    admin: false
    namespaces:
        - name: "chat"
```

And deploy with:

```
helm install [RELEASE_NAME] -f values.yaml centrifugal/centrifugo
```

Or you can override options using `--set` flag, for example:

```
helm install [RELEASE_NAME] centrifugal/centrifugo --set config.namespaces[0].name=chat --set config.namespaces[0].publish=true
```

This chart also defines several secrets. For example here is an example that configures HTTP API key and token HMAC secret key.

```
helm install [RELEASE_NAME] centrifugal/centrifugo --set secrets.apiKey=<YOUR_SECRET_API_KEY> --set secrets.tokenHmacSecretKey=<YOUR_SECRET_TOKEN_SECRET_KEY> 
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
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_url=redis://redis-master:6379 --set replicaCount=3
```

Now example with Redis Sentinel (again using chart from bitnami):

```
helm install redis bitnami/redis --set usePassword=false --set cluster.enabled=true --set sentinel.enabled=true
```

Then point Centrifugo to Sentinel:

```
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_master_name=mymaster --set config.redis_sentinels=redis:26379 --set replicaCount=3
```

Example with Redis Cluster (using `bitnami/redis-cluster` chart, but again the way you run Redis is up to you actually):

```
helm install redis bitnami/redis-cluster --set usePassword=false
```

Then point Centrifugo to Redis Cluster:

```
helm install centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_cluster_addrs=redis-redis-cluster-0:6379 --set replicaCount=3
```

## With Nats broker

```
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats --set cluster.enabled=true
```

Then start Centrifugo pointing to Nats broker:

```
helm install centrifugo -f values.yaml ./centrifugo --set config.broker=nats --set config.nats_url=nats://nats:4222 --set replicaCount=3
```
