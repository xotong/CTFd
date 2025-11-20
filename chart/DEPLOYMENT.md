# CTFd Deployment Guide for OpenShift

This guide provides step-by-step instructions for deploying CTFd on OpenShift Container Platform using the Helm chart.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Production Deployment](#production-deployment)
4. [Configuration](#configuration)
5. [Accessing CTFd](#accessing-ctfd)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)
7. [Troubleshooting](#troubleshooting)
8. [Upgrading](#upgrading)
9. [Backup and Restore](#backup-and-restore)

## Prerequisites

Before deploying CTFd, ensure you have:

- OpenShift Container Platform 4.x or later
- `oc` CLI installed and configured
- `helm` CLI version 3.x or later installed
- Sufficient cluster resources (see resource requirements below)
- Appropriate RBAC permissions to create resources in your namespace

### Minimum Resource Requirements

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| CTFd      | 500m        | 512Mi          | 5Gi (uploads) + 1Gi (logs) |
| MariaDB   | 250m        | 256Mi          | 5Gi |
| Redis     | 100m        | 128Mi          | 1Gi |
| **Total** | **850m**    | **896Mi**      | **12Gi** |

### Recommended Production Resources

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit | Storage |
|-----------|-------------|----------------|-----------|--------------|---------|
| CTFd (x2) | 1000m       | 1Gi            | 2000m     | 2Gi          | 50Gi + 10Gi |
| MariaDB   | 1000m       | 2Gi            | 2000m     | 4Gi          | 50Gi |
| Redis     | 500m        | 512Mi          | 1000m     | 1Gi          | 5Gi |
| **Total** | **3500m**   | **5Gi**        | **7000m** | **11Gi**     | **115Gi** |

## Quick Start

### 1. Login to OpenShift

```bash
oc login https://api.your-cluster.example.com:6443
```

### 2. Create a Project (Namespace)

```bash
oc new-project ctfd
```

### 3. Install CTFd with Default Values

```bash
helm install ctfd ./chart --namespace ctfd
```

### 4. Get the Route URL

```bash
oc get route ctfd -o jsonpath='{.spec.host}'
```

### 5. Access CTFd

Open your browser and navigate to the URL from step 4:

```
https://<route-host>
```

Complete the CTFd setup wizard to finish installation.

## Production Deployment

For production deployments, follow these steps:

### 1. Create a Custom Values File

Create a file named `production-values.yaml`:

```yaml
global:
  openshift:
    enabled: true
    route:
      enabled: true
      host: "ctfd.apps.your-cluster.example.com"  # Replace with your domain
      tls:
        enabled: true
        termination: edge
        insecureEdgeTerminationPolicy: Redirect

ctfd:
  replicaCount: 2
  
  env:
    workers: 4
    secretKey: ""  # Generate with: openssl rand -base64 48
  
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 1000m
      memory: 1Gi
  
  persistence:
    uploads:
      enabled: true
      size: 50Gi
      # storageClass: "gp3-csi"  # Uncomment and specify your storage class
    logs:
      enabled: true
      size: 10Gi
      # storageClass: "gp3-csi"

mariadb:
  enabled: true
  
  auth:
    rootPassword: ""  # Generate with: openssl rand -base64 32
    database: "ctfd"
    username: "ctfd"
    password: ""  # Generate with: openssl rand -base64 32
  
  primary:
    persistence:
      enabled: true
      size: 50Gi
      # storageClass: "gp3-csi"
    
    resources:
      limits:
        cpu: 2000m
        memory: 4Gi
      requests:
        cpu: 1000m
        memory: 2Gi

redis:
  enabled: true
  
  master:
    persistence:
      enabled: true
      size: 5Gi
      # storageClass: "gp3-csi"
    
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

### 2. Generate Strong Passwords

```bash
# Generate secret key
echo "secretKey: \"$(openssl rand -base64 48)\"" >> secrets.yaml

# Generate database root password
echo "rootPassword: \"$(openssl rand -base64 32)\"" >> secrets.yaml

# Generate database user password
echo "password: \"$(openssl rand -base64 32)\"" >> secrets.yaml
```

**Important**: Store these passwords securely in a password manager!

### 3. Update the Values File

Edit `production-values.yaml` and add the generated passwords.

### 4. Deploy CTFd

```bash
helm install ctfd ./chart \
  --namespace ctfd \
  --values production-values.yaml
```

### 5. Verify Deployment

```bash
# Check all pods are running
oc get pods -n ctfd

# Check the route
oc get route ctfd -n ctfd

# View deployment status
helm status ctfd -n ctfd
```

## Configuration

### Using External Database

If you have an existing database, disable the embedded MariaDB:

```yaml
mariadb:
  enabled: false

ctfd:
  env:
    databaseUrl: "mysql+pymysql://user:password@external-db.example.com:3306/ctfd"
```

### Using External Redis

If you have an existing Redis instance:

```yaml
redis:
  enabled: false

ctfd:
  env:
    redisUrl: "redis://external-redis.example.com:6379"
```

### Custom Storage Classes

Specify storage classes for persistent volumes:

```yaml
ctfd:
  persistence:
    uploads:
      storageClass: "fast-storage"
    logs:
      storageClass: "standard-storage"

mariadb:
  primary:
    persistence:
      storageClass: "fast-storage"

redis:
  master:
    persistence:
      storageClass: "standard-storage"
```

### Scaling

To scale the CTFd application:

```bash
# Using Helm
helm upgrade ctfd ./chart --set ctfd.replicaCount=3 -n ctfd

# Or using OpenShift
oc scale deployment ctfd --replicas=3 -n ctfd
```

**Note**: When running multiple replicas, you MUST set a persistent `secretKey` in the values file.

## Accessing CTFd

### Get the Route URL

```bash
ROUTE_URL=$(oc get route ctfd -n ctfd -o jsonpath='{.spec.host}')
echo "CTFd is available at: https://$ROUTE_URL"
```

### Port Forwarding (for testing)

```bash
oc port-forward svc/ctfd 8000:8000 -n ctfd
# Access at: http://localhost:8000
```

### First-Time Setup

1. Navigate to the CTFd URL
2. Complete the setup wizard:
   - Set admin username and password
   - Configure event details
   - Choose competition mode (individual or team)
   - Configure additional settings

## Monitoring and Maintenance

### View Logs

```bash
# CTFd application logs
oc logs -f deployment/ctfd -n ctfd

# MariaDB logs
oc logs -f statefulset/ctfd-mariadb -n ctfd

# Redis logs
oc logs -f statefulset/ctfd-redis -n ctfd
```

### Check Resource Usage

```bash
# Pod resource usage
oc top pods -n ctfd

# Node resource usage
oc top nodes
```

### Monitor Pod Health

```bash
# Watch pods
oc get pods -n ctfd -w

# Describe a pod
oc describe pod <pod-name> -n ctfd
```

### Database Operations

```bash
# Connect to MariaDB
oc exec -it statefulset/ctfd-mariadb -n ctfd -- mysql -u ctfd -p ctfd

# Backup database
oc exec statefulset/ctfd-mariadb -n ctfd -- \
  mysqldump -u root -p"$ROOT_PASSWORD" ctfd > ctfd-backup-$(date +%Y%m%d).sql

# Restore database
cat ctfd-backup-20231120.sql | \
  oc exec -i statefulset/ctfd-mariadb -n ctfd -- \
  mysql -u root -p"$ROOT_PASSWORD" ctfd
```

## Troubleshooting

### Pods Not Starting

Check pod status and events:

```bash
oc describe pod <pod-name> -n ctfd
oc logs <pod-name> -n ctfd
```

Common issues:
- Insufficient resources: Check resource quotas
- Image pull errors: Verify image repository access
- PVC binding issues: Check storage class availability

### Database Connection Errors

1. Verify MariaDB is running:
   ```bash
   oc get pods -l app.kubernetes.io/name=ctfd-mariadb -n ctfd
   ```

2. Check database credentials in secret:
   ```bash
   oc get secret ctfd -n ctfd -o yaml
   ```

3. Test database connectivity:
   ```bash
   oc exec -it deployment/ctfd -n ctfd -- \
     python ping.py
   ```

### Route Not Accessible

1. Check route status:
   ```bash
   oc get route ctfd -n ctfd
   oc describe route ctfd -n ctfd
   ```

2. Verify service endpoints:
   ```bash
   oc get endpoints ctfd -n ctfd
   ```

3. Check router logs:
   ```bash
   oc logs -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default
   ```

### Storage Issues

1. Check PVC status:
   ```bash
   oc get pvc -n ctfd
   ```

2. Describe PVC:
   ```bash
   oc describe pvc ctfd-uploads -n ctfd
   ```

3. Check storage class:
   ```bash
   oc get storageclass
   ```

## Upgrading

### Upgrade CTFd Version

1. Update the image tag in values file:
   ```yaml
   ctfd:
     image:
       tag: "3.8.0"  # New version
   ```

2. Perform the upgrade:
   ```bash
   helm upgrade ctfd ./chart \
     --namespace ctfd \
     --values production-values.yaml
   ```

3. Monitor the rollout:
   ```bash
   oc rollout status deployment/ctfd -n ctfd
   ```

### Upgrade Helm Chart

```bash
# Upgrade to a new chart version
helm upgrade ctfd ./chart \
  --namespace ctfd \
  --values production-values.yaml

# With dry-run to test
helm upgrade ctfd ./chart \
  --namespace ctfd \
  --values production-values.yaml \
  --dry-run --debug
```

### Rollback

If an upgrade fails:

```bash
# Rollback to previous release
helm rollback ctfd -n ctfd

# Rollback to specific revision
helm rollback ctfd 1 -n ctfd

# View history
helm history ctfd -n ctfd
```

## Backup and Restore

### Backup

#### 1. Database Backup

```bash
# Get database password
DB_PASSWORD=$(oc get secret ctfd -n ctfd -o jsonpath='{.data.mariadb-root-password}' | base64 -d)

# Create backup
oc exec statefulset/ctfd-mariadb -n ctfd -- \
  mysqldump -u root -p"$DB_PASSWORD" ctfd | \
  gzip > ctfd-db-backup-$(date +%Y%m%d-%H%M%S).sql.gz
```

#### 2. Uploads Backup

```bash
# Create a backup pod
oc run backup --image=busybox --rm -it --restart=Never -n ctfd -- /bin/sh

# In the backup pod, tar the uploads
tar czf /tmp/uploads-backup.tar.gz /var/uploads

# Copy from pod to local
oc cp ctfd/<pod-name>:/tmp/uploads-backup.tar.gz ./uploads-backup-$(date +%Y%m%d).tar.gz -n ctfd
```

#### 3. Configuration Backup

```bash
# Export Helm values
helm get values ctfd -n ctfd > ctfd-values-backup.yaml

# Export all resources
oc get all,pvc,route,secret,configmap -n ctfd -o yaml > ctfd-resources-backup.yaml
```

### Restore

#### 1. Database Restore

```bash
# Get database password
DB_PASSWORD=$(oc get secret ctfd -n ctfd -o jsonpath='{.data.mariadb-root-password}' | base64 -d)

# Restore backup
gunzip < ctfd-db-backup-20231120-120000.sql.gz | \
  oc exec -i statefulset/ctfd-mariadb -n ctfd -- \
  mysql -u root -p"$DB_PASSWORD" ctfd
```

#### 2. Uploads Restore

```bash
# Copy backup to pod
oc cp uploads-backup-20231120.tar.gz ctfd/<pod-name>:/tmp/ -n ctfd

# Extract in pod
oc exec <pod-name> -n ctfd -- tar xzf /tmp/uploads-backup.tar.gz -C /
```

### Automated Backup with CronJob

Create a backup CronJob:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ctfd-backup
  namespace: ctfd
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: mariadb:10.11
            command:
            - /bin/bash
            - -c
            - |
              mysqldump -h ctfd-mariadb -u root -p"$DB_PASSWORD" ctfd | \
              gzip > /backup/ctfd-$(date +\%Y\%m\%d-\%H\%M\%S).sql.gz
            env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ctfd
                  key: mariadb-root-password
            volumeMounts:
            - name: backup
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: ctfd-backups
```

## Security Best Practices

1. **Change Default Passwords**: Always use strong, unique passwords
2. **Enable TLS**: Use HTTPS for all external access
3. **Regular Updates**: Keep CTFd and dependencies updated
4. **Resource Limits**: Set appropriate resource limits
5. **Network Policies**: Implement network policies if needed
6. **RBAC**: Use least-privilege service accounts
7. **Secrets Management**: Consider using external secrets management (e.g., Vault)
8. **Regular Backups**: Implement automated backup strategy
9. **Monitoring**: Set up monitoring and alerting
10. **Security Scanning**: Regularly scan images for vulnerabilities

## Additional Resources

- [CTFd Official Documentation](https://docs.ctfd.io/)
- [CTFd GitHub Repository](https://github.com/CTFd/CTFd)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Helm Documentation](https://helm.sh/docs/)
- [CTFd Community Forum](https://community.majorleaguecyber.org/)

## Support

For issues specific to this Helm chart, please open an issue in the repository.
For CTFd-specific questions, refer to the official CTFd resources above.
