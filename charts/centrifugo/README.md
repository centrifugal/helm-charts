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

## Scale with Redis engine

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install --name=redis bitnami/redis --set usePassword=false
```

Then start Centrifugo:

```
helm install --name centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_url=redis://redis-master:6379 --set replicaCount=3
```

With Redis Sentinel:

```
helm install --name=redis bitnami/redis --set usePassword=false --set cluster.enabled=true --set sentinel.enabled=true
```

Then point Centrifugo to Sentinel:

```
helm install --name centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_master_name=mymaster --set config.redis_sentinels=redis:26379 --set replicaCount=3
```

With Redis Cluster:

```
helm install redis bitnami/redis-cluster --set usePassword=false
```

Then point Centrifugo to Redis Cluster:

```
helm install --name centrifugo -f values.yaml ./centrifugo --set config.engine=redis --set config.redis_cluster_addrs=redis-redis-cluster-0:6379 --set replicaCount=3
```

## With Nats broker

```
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install --name=nats nats/nats --set cluster.enabled=true
```

Then start Centrifugo pointing to Nats broker:

```
helm install --name centrifugo -f values.yaml ./centrifugo --set config.broker=nats --set config.nats_url=nats://nats:4222 --set replicaCount=3
```
