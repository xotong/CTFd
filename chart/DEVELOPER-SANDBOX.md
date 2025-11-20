# Quick Start Guide: OpenShift Developer Sandbox

This guide helps you deploy CTFd on the free [OpenShift Developer Sandbox](https://developers.redhat.com/developer-sandbox).

## What is OpenShift Developer Sandbox?

OpenShift Developer Sandbox is a free OpenShift environment that provides:
- 14-day renewable access (can be extended)
- Pre-configured namespace (typically `<username>-dev`)
- Resource quotas: ~7 cores CPU, ~15Gi RAM
- Persistent storage with quotas
- No credit card required!

## Restrictions to be Aware Of

The Developer Sandbox has some restrictions:
- ✗ **Cannot create namespaces** - Use your provisioned namespace
- ✗ **Cannot create ServiceAccounts** - Must use default SA
- ✗ **Cannot specify route hostnames** - Routes are auto-assigned
- ✗ **Resource limits** - Fits ~5-10 small applications
- ✓ **Can create most other resources** - Deployments, Services, Routes, PVCs, etc.

## Prerequisites

1. Sign up for Developer Sandbox at: https://developers.redhat.com/developer-sandbox
2. Install `oc` CLI: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html
3. Install `helm` CLI: https://helm.sh/docs/intro/install/

## Step-by-Step Installation

### 1. Access Your Developer Sandbox

1. Go to https://developers.redhat.com/developer-sandbox
2. Sign up or log in
3. Click "Start using your sandbox"
4. Click "DevSandbox" from the topology view

### 2. Get Login Command

1. In the OpenShift web console, click your username (top right)
2. Click "Copy login command"
3. Click "Display Token"
4. Copy the full `oc login` command

### 3. Login via CLI

```bash
# Paste the login command you copied
oc login --token=sha256~xxxxx --server=https://api.sandbox-xxxxx.openshiftapps.com:6443
```

### 4. Verify Your Namespace

```bash
# Check your current namespace
oc project

# You should see something like: <your-username>-dev
# Example: jdoe-dev
```

### 5. Clone the CTFd Repository

```bash
git clone https://github.com/CTFd/CTFd.git
cd CTFd
```

### 6. Install CTFd

```bash
# Install using the Developer Sandbox configuration
# IMPORTANT: Do NOT use --create-namespace flag!
helm install ctfd ./chart \
  -f chart/examples/developer-sandbox.yaml \
  --namespace $(oc project -q)
```

### 7. Monitor Installation

```bash
# Watch pods being created
oc get pods -w

# You should see:
# - ctfd-xxxxx (CTFd application)
# - ctfd-mariadb-0 (Database)
# - ctfd-redis-0 (Cache)

# Wait until all pods show "Running" and "1/1" or "2/2" ready
# Press Ctrl+C to exit watch mode
```

### 8. Check Installation Status

```bash
# Check Helm release status
helm status ctfd

# Check all resources
oc get all
```

### 9. Get Your CTFd URL

```bash
# Get the auto-assigned route
ROUTE_URL=$(oc get route ctfd -o jsonpath='{.spec.host}')
echo "Your CTFd URL: https://$ROUTE_URL"
```

### 10. Access CTFd

1. Open your browser to the URL from step 9
2. You should see the CTFd setup wizard
3. Complete the setup:
   - Create admin account
   - Set your CTF event name
   - Configure settings

🎉 **Congratulations!** CTFd is now running on OpenShift Developer Sandbox!

## Resource Usage

The Developer Sandbox configuration uses:

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| CTFd | 250m-500m | 512Mi-768Mi | 2.5Gi |
| MariaDB | 150m-300m | 256Mi-512Mi | 2Gi |
| Redis | 100m-200m | 128Mi-256Mi | 500Mi |
| **Total** | **500m-1000m** | **896Mi-1536Mi** | **5Gi** |

This leaves plenty of room in your quota for other applications or scaling.

## Troubleshooting

### Pods Stuck in "Pending"

```bash
# Check resource quotas
oc get resourcequota

# Check events
oc get events --sort-by='.lastTimestamp'

# Describe the pending pod
oc describe pod <pod-name>
```

**Common causes:**
- Insufficient quota (unlikely with our config)
- PVC not binding (see below)

### PVC Not Binding

```bash
# Check PVC status
oc get pvc

# Describe PVC
oc describe pvc ctfd-uploads
```

**Common causes:**
- No storage available (sandbox provides default storage)
- Quota exceeded (reduce storage sizes if needed)

### Cannot Access Route

```bash
# Check route
oc get route ctfd

# Should show a URL like: ctfd-<namespace>.apps.sandbox-xxxxx.openshiftapps.com

# Check if service has endpoints
oc get endpoints ctfd

# Check pod logs
oc logs -f deployment/ctfd
```

### Database Connection Issues

```bash
# Check if MariaDB is running
oc get pods -l app.kubernetes.io/name=ctfd-mariadb

# Check MariaDB logs
oc logs -f statefulset/ctfd-mariadb

# Check database connectivity from CTFd pod
oc exec deployment/ctfd -- nc -zv ctfd-mariadb 3306
```

## Common Operations

### View Logs

```bash
# CTFd application logs
oc logs -f deployment/ctfd

# Database logs
oc logs -f statefulset/ctfd-mariadb

# Redis logs
oc logs -f statefulset/ctfd-redis
```

### Restart a Component

```bash
# Restart CTFd
oc rollout restart deployment/ctfd

# Restart database (careful - may cause downtime)
oc delete pod ctfd-mariadb-0

# Restart Redis
oc delete pod ctfd-redis-0
```

### Access Database Directly

```bash
# Connect to MariaDB
oc exec -it statefulset/ctfd-mariadb -- mysql -u ctfd -pctfd ctfd

# Or using root
oc exec -it statefulset/ctfd-mariadb -- mysql -u root -pctfd
```

### Scale CTFd (if quota allows)

```bash
# Scale to 2 replicas (requires setting secretKey in values)
helm upgrade ctfd ./chart \
  -f chart/examples/developer-sandbox.yaml \
  --set ctfd.replicaCount=2 \
  --set ctfd.env.secretKey="your-secret-key-here" \
  --namespace $(oc project -q)
```

## Uninstalling

When you're done testing:

```bash
# Uninstall CTFd
helm uninstall ctfd

# Delete PVCs (to free up storage)
oc delete pvc -l app.kubernetes.io/instance=ctfd

# Verify cleanup
oc get all
```

## Upgrading

To upgrade to a newer version:

```bash
# Pull latest chart
cd CTFd
git pull

# Upgrade installation
helm upgrade ctfd ./chart \
  -f chart/examples/developer-sandbox.yaml \
  --namespace $(oc project -q)
```

## Tips for Developer Sandbox

1. **Quota Management**: Your sandbox has limited resources. Monitor usage:
   ```bash
   oc describe quota
   ```

2. **Storage Management**: PVCs persist even after deleting pods. Clean up old PVCs:
   ```bash
   oc get pvc
   oc delete pvc <pvc-name>
   ```

3. **Session Timeout**: Developer Sandbox sessions expire. Keep your token handy to re-login.

4. **Renewal**: Your sandbox access lasts 14 days but can be renewed. Keep an eye on expiration.

5. **Learning Resource**: This is perfect for learning Kubernetes/OpenShift without spending money!

## Next Steps

- Explore the OpenShift web console
- Try creating CTF challenges
- Learn about Kubernetes concepts
- Experiment with different configurations

## Additional Resources

- [OpenShift Developer Sandbox Documentation](https://developers.redhat.com/developer-sandbox)
- [CTFd Documentation](https://docs.ctfd.io/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Helm Documentation](https://helm.sh/docs/)

## Need Help?

- CTFd Community: https://community.majorleaguecyber.org/
- OpenShift Community: https://commons.openshift.org/
- GitHub Issues: https://github.com/CTFd/CTFd/issues

---

**Happy CTF Building! 🚀**
