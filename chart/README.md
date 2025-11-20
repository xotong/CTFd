# CTFd Helm Chart

This Helm chart deploys [CTFd](https://ctfd.io/) - a Capture The Flag framework - on Kubernetes and OpenShift Container Platform (OCP).

## Prerequisites

- Kubernetes 1.19+ or OpenShift 4.x+
- Helm 3.x
- PV provisioner support in the underlying infrastructure (for persistent storage)
- (Optional) Ingress controller or OpenShift Routes for external access

## Architecture

This chart deploys the following components:

- **CTFd Application**: Python Flask application running on Gunicorn
- **MariaDB**: Relational database for CTFd data (optional, can use external database)
- **Redis**: In-memory cache for sessions and caching (optional, can use external Redis)
- **Nginx**: Reverse proxy (optional, disabled by default on OpenShift)

## Installing the Chart

### Quick Install (Using Helper Script)

The easiest way to install CTFd is using the provided installation script:

```bash
# Make the script executable
chmod +x chart/install.sh

# Install with defaults
./chart/install.sh -c

# Install with custom values
./chart/install.sh -f chart/examples/production-openshift.yaml -c

# Install in a custom namespace
./chart/install.sh -n my-ctfd -c

# See all options
./chart/install.sh --help
```

### Manual Installation

#### On OpenShift

```bash
# Install with default values (uses OpenShift Routes)
helm install ctfd ./chart --namespace ctfd --create-namespace

# Install with custom values
helm install ctfd ./chart -f custom-values.yaml --namespace ctfd --create-namespace

# Install with production example
helm install ctfd ./chart -f chart/examples/production-openshift.yaml --namespace ctfd --create-namespace
```

#### On Kubernetes

```bash
# Install with Nginx enabled (if not using ingress controller)
helm install ctfd ./chart --set nginx.enabled=true --set global.openshift.enabled=false --namespace ctfd --create-namespace

# Install with custom ingress
helm install ctfd ./chart --set global.openshift.enabled=false -f ingress-values.yaml --namespace ctfd --create-namespace
```

## Configuration

The following table lists the configurable parameters and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.openshift.enabled` | Enable OpenShift-specific features | `true` |
| `global.openshift.route.enabled` | Create OpenShift Route | `true` |
| `global.openshift.route.host` | Route hostname (auto-generated if empty) | `""` |
| `global.openshift.route.tls.enabled` | Enable TLS on route | `true` |
| `global.openshift.route.tls.termination` | TLS termination type | `edge` |

### CTFd Application Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ctfd.replicaCount` | Number of CTFd replicas | `1` |
| `ctfd.image.repository` | CTFd image repository | `ctfd/ctfd` |
| `ctfd.image.tag` | CTFd image tag | Chart appVersion |
| `ctfd.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `ctfd.env.workers` | Number of Gunicorn workers | `1` |
| `ctfd.env.workerClass` | Gunicorn worker class | `gevent` |
| `ctfd.env.secretKey` | Flask secret key (auto-generated if empty) | `""` |
| `ctfd.env.databaseUrl` | External database URL | `""` |
| `ctfd.env.redisUrl` | External Redis URL | `""` |
| `ctfd.service.type` | Service type | `ClusterIP` |
| `ctfd.service.port` | Service port | `8000` |
| `ctfd.persistence.uploads.enabled` | Enable uploads persistence | `true` |
| `ctfd.persistence.uploads.size` | Uploads PVC size | `5Gi` |
| `ctfd.persistence.logs.enabled` | Enable logs persistence | `true` |
| `ctfd.persistence.logs.size` | Logs PVC size | `1Gi` |
| `ctfd.resources.limits.cpu` | CPU limit | `1000m` |
| `ctfd.resources.limits.memory` | Memory limit | `1Gi` |
| `ctfd.resources.requests.cpu` | CPU request | `500m` |
| `ctfd.resources.requests.memory` | Memory request | `512Mi` |

### MariaDB Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mariadb.enabled` | Deploy MariaDB | `true` |
| `mariadb.image.repository` | MariaDB image repository | `mariadb` |
| `mariadb.image.tag` | MariaDB image tag | `10.11` |
| `mariadb.auth.database` | Database name | `ctfd` |
| `mariadb.auth.username` | Database username | `ctfd` |
| `mariadb.auth.password` | Database password | `ctfd` |
| `mariadb.auth.rootPassword` | Root password | `ctfd` |
| `mariadb.primary.persistence.enabled` | Enable persistence | `true` |
| `mariadb.primary.persistence.size` | PVC size | `5Gi` |
| `mariadb.primary.resources.limits.cpu` | CPU limit | `500m` |
| `mariadb.primary.resources.limits.memory` | Memory limit | `512Mi` |

### Redis Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Deploy Redis | `true` |
| `redis.image.repository` | Redis image repository | `redis` |
| `redis.image.tag` | Redis image tag | `4` |
| `redis.master.persistence.enabled` | Enable persistence | `true` |
| `redis.master.persistence.size` | PVC size | `1Gi` |
| `redis.master.resources.limits.cpu` | CPU limit | `250m` |
| `redis.master.resources.limits.memory` | Memory limit | `256Mi` |

### Nginx Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nginx.enabled` | Deploy Nginx reverse proxy | `false` |
| `nginx.image.repository` | Nginx image repository | `nginx` |
| `nginx.image.tag` | Nginx image tag | `stable` |

## Examples

### Using External Database

```yaml
# external-db-values.yaml
mariadb:
  enabled: false

ctfd:
  env:
    databaseUrl: "mysql+pymysql://user:password@external-db-host:3306/ctfd"
```

```bash
helm install ctfd ./chart -f external-db-values.yaml
```

### Using External Redis

```yaml
# external-redis-values.yaml
redis:
  enabled: false

ctfd:
  env:
    redisUrl: "redis://external-redis-host:6379"
```

```bash
helm install ctfd ./chart -f external-redis-values.yaml
```

### High Availability Setup

```yaml
# ha-values.yaml
ctfd:
  replicaCount: 3
  env:
    workers: 2
    secretKey: "your-persistent-secret-key-here"  # Must be set for multiple replicas
  
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

  persistence:
    uploads:
      size: 20Gi
      storageClass: "fast-storage"

mariadb:
  primary:
    persistence:
      size: 20Gi
      storageClass: "fast-storage"
    resources:
      requests:
        cpu: 1000m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

redis:
  master:
    persistence:
      size: 5Gi
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi
```

```bash
helm install ctfd ./chart -f ha-values.yaml
```

### Production Setup on OpenShift

```yaml
# production-ocp-values.yaml
global:
  openshift:
    enabled: true
    route:
      enabled: true
      host: "ctfd.apps.your-cluster.example.com"
      tls:
        enabled: true
        termination: edge

ctfd:
  replicaCount: 2
  env:
    workers: 4
    secretKey: "use-a-strong-random-secret-here"
  
  persistence:
    uploads:
      size: 50Gi
      storageClass: "gp3-csi"  # AWS example
    logs:
      size: 10Gi
      storageClass: "gp3-csi"

mariadb:
  auth:
    rootPassword: "change-this-strong-password"
    password: "change-this-strong-password"
  primary:
    persistence:
      size: 50Gi
      storageClass: "gp3-csi"

redis:
  master:
    persistence:
      size: 5Gi
      storageClass: "gp3-csi"
```

```bash
helm install ctfd ./chart -f production-ocp-values.yaml --namespace ctfd --create-namespace
```

## Accessing CTFd

### On OpenShift

After installation, get the route URL:

```bash
oc get route ctfd -o jsonpath='{.spec.host}'
```

Access CTFd at: `https://<route-host>`

### On Kubernetes

Using port-forward:

```bash
kubectl port-forward svc/ctfd 8000:8000
```

Access CTFd at: `http://localhost:8000`

## Upgrading

```bash
# Upgrade with new values
helm upgrade ctfd ./chart -f updated-values.yaml

# Upgrade to a new chart version
helm upgrade ctfd ./chart --version <new-version>
```

## Uninstalling

### Quick Uninstall (Using Helper Script)

The easiest way to uninstall CTFd is using the provided uninstallation script:

```bash
# Make the script executable
chmod +x chart/uninstall.sh

# Uninstall (keeps PVCs and namespace)
./chart/uninstall.sh

# Uninstall and delete PVCs (WARNING: deletes all data!)
./chart/uninstall.sh --delete-pvc -y

# Complete cleanup including namespace
./chart/uninstall.sh --delete-pvc --delete-namespace -y

# See all options
./chart/uninstall.sh --help
```

### Manual Uninstall

```bash
# Uninstall the release
helm uninstall ctfd --namespace ctfd

# Optionally delete PVCs (THIS WILL DELETE ALL DATA!)
kubectl delete pvc -l app.kubernetes.io/instance=ctfd --namespace ctfd

# Or on OpenShift
oc delete pvc -l app.kubernetes.io/instance=ctfd -n ctfd
```

## Persistence

The chart creates PersistentVolumeClaims for:

- CTFd uploads (`ctfd-uploads`)
- CTFd logs (`ctfd-logs`)
- MariaDB data (`data-ctfd-mariadb-0`)
- Redis data (`data-ctfd-redis-0`)

Ensure your cluster has a default StorageClass or specify one in values.

## Security Considerations

1. **Change default passwords**: Always change the default database passwords in production
2. **Set SECRET_KEY**: For multiple replicas, you must set a persistent secret key
3. **Use TLS**: Enable TLS on routes/ingress for production deployments
4. **Resource limits**: Set appropriate resource limits based on your workload
5. **Network policies**: Consider enabling network policies for additional security
6. **Security contexts**: The chart uses non-root users and drops all capabilities by default

## Troubleshooting

### Pod fails to start

Check pod logs:
```bash
kubectl logs -f deployment/ctfd
```

### Database connection issues

Verify database is running:
```bash
kubectl get pods -l app.kubernetes.io/name=ctfd-mariadb
kubectl logs statefulset/ctfd-mariadb
```

### Route not accessible on OpenShift

Check route status:
```bash
oc get route ctfd
oc describe route ctfd
```

### Storage issues

Check PVC status:
```bash
kubectl get pvc
kubectl describe pvc ctfd-uploads
```

## Support

- [CTFd Documentation](https://docs.ctfd.io/)
- [CTFd GitHub](https://github.com/CTFd/CTFd)
- [CTFd Community](https://community.majorleaguecyber.org/)

## License

This Helm chart follows the same license as CTFd: Apache License 2.0
