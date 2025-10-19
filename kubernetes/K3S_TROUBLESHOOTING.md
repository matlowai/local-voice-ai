# K3s Connection Troubleshooting Guide

This guide helps you diagnose and fix common K3s connection issues with the Local Voice AI deployment.

## Quick Diagnosis

### 1. Run Quick Check
```bash
./kubernetes/scripts/quick-k3s-check.sh
```

This provides a fast overview of your K3s connection status.

### 2. Run Comprehensive Diagnostics
```bash
./kubernetes/scripts/k3s-connection-diagnostics.sh diagnose
```

This performs detailed analysis and attempts automatic fixes.

## Common Issues and Solutions

### Issue 1: K3s Service Not Running

**Symptoms:**
- ❌ K3s service is not running
- Cannot connect to cluster

**Solutions:**
```bash
# Check service status
sudo systemctl status k3s

# Start the service
sudo systemctl start k3s

# Enable service to start on boot
sudo systemctl enable k3s

# Check logs for errors
sudo journalctl -u k3s -f --lines=50
```

### Issue 2: Kubeconfig Problems

**Symptoms:**
- kubeconfig file not found
- Permission denied errors
- Connection refused despite K3s running

**Solutions:**
```bash
# Run automatic kubeconfig fix
./kubernetes/scripts/k3s-connection-diagnostics.sh fix-kubeconfig

# Manual fix
sudo mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Set environment variable
export KUBECONFIG="$HOME/.kube/config"
echo "export KUBECONFIG=\"$HOME/.kube/config\"" >> ~/.bashrc
```

### Issue 3: Network/Port Issues

**Symptoms:**
- K3s service running but ports not listening
- Connection timeout errors

**Solutions:**
```bash
# Check if ports are listening
sudo netstat -tlnp | grep -E ":(6443|10250)"

# Check firewall
sudo ufw status
sudo iptables -L | grep 6443

# Restart K3s to rebind ports
sudo systemctl restart k3s

# Check K3s configuration
sudo cat /etc/systemd/system/k3s.service
```

### Issue 4: Permission Issues

**Symptoms:**
- Permission denied accessing kubeconfig
- Cannot run kubectl commands

**Solutions:**
```bash
# Fix kubeconfig permissions
chmod 600 $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Check user group membership
groups $USER

# Add user to docker group if needed
sudo usermod -aG docker $USER
# Then logout and login again
```

### Issue 5: API Server Not Ready

**Symptoms:**
- K3s service running but API server not responding
- Connection refused errors

**Solutions:**
```bash
# Wait for API server to be ready
watch -n 5 "kubectl get --raw='/healthz'"

# Check K3s process status
ps aux | grep k3s

# Restart K3s if needed
sudo systemctl restart k3s

# Check system resources
free -h
df -h
```

## Advanced Troubleshooting

### Check K3s Logs
```bash
# Real-time logs
sudo journalctl -u k3s -f

# Recent logs
sudo journalctl -u k3s --since "10 minutes ago"

# Error logs only
sudo journalctl -u k3s -p err
```

### Verify K3s Configuration
```bash
# Check K3s service file
sudo cat /etc/systemd/system/k3s.service

# Check K3s configuration
sudo cat /etc/rancher/k3s/config.yaml

# Check K3s data directory
sudo ls -la /var/lib/rancher/k3s/
```

### Network Diagnostics
```bash
# Test API server directly
curl -k https://127.0.0.1:6443/healthz

# Check DNS resolution
nslookup kubernetes.default.svc.cluster.local

# Check network interfaces
ip addr show

# Check routing
ip route show
```

### Reset K3s Installation
If all else fails, you can reset K3s:

```bash
# WARNING: This will delete all Kubernetes data
sudo /usr/local/bin/k3s-uninstall.sh

# Clean up remaining files
sudo rm -rf /etc/rancher/k3s/
sudo rm -rf /var/lib/rancher/k3s/

# Reinstall K3s
./kubernetes/install/install-k3s-gpu.sh
```

## Manual Verification Steps

### 1. Verify Service Status
```bash
sudo systemctl is-active k3s
sudo systemctl is-enabled k3s
```

### 2. Verify Process Running
```bash
ps aux | grep "k3s server"
```

### 3. Verify Ports Listening
```bash
sudo netstat -tlnp | grep -E ":(6443|10250)"
```

### 4. Verify Kubeconfig
```bash
ls -la $HOME/.kube/config
cat $HOME/.kube/config
```

### 5. Verify kubectl Connection
```bash
export KUBECONFIG="$HOME/.kube/config"
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

## Getting Help

If you're still experiencing issues:

1. **Run diagnostics and save output:**
   ```bash
   ./kubernetes/scripts/k3s-connection-diagnostics.sh diagnose > k3s-diagnostics.log 2>&1
   ```

2. **Collect system information:**
   ```bash
   systemctl status k3s > k3s-status.log
   journalctl -u k3s --since "1 hour ago" > k3s-logs.log
   kubectl version > k8s-version.log
   ```

3. **Check the GitHub issues** for similar problems
4. **Provide the logs** when asking for help

## Prevention Tips

1. **Always run the quick check before deployment:**
   ```bash
   ./kubernetes/scripts/quick-k3s-check.sh
   ```

2. **Keep your system updated:**
   ```bash
   sudo apt update && sudo apt upgrade
   ```

3. **Monitor K3s service health:**
   ```bash
   sudo systemctl status k3s --no-pager
   ```

4. **Regular backups of kubeconfig:**
   ```bash
   cp $HOME/.kube/config $HOME/.kube/config.backup
   ```

## Scripts Reference

- `quick-k3s-check.sh` - Fast connection verification
- `k3s-connection-diagnostics.sh` - Comprehensive diagnostics and auto-fix
- `install-k3s-gpu.sh` - K3s installation with GPU support
- `deploy-gpu.sh` - Main deployment script with integrated checks

## Environment Variables

Key environment variables to be aware of:

```bash
# Kubeconfig location
export KUBECONFIG="$HOME/.kube/config"

# Kubernetes namespace
export NAMESPACE="voice-ai"

# Kubectl timeout (useful for slow systems)
export KUBECTL_TIMEOUT=30s