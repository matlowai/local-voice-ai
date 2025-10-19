# Kubernetes Deployment Guide for Local Voice AI

## Overview

This guide provides step-by-step instructions for deploying Local Voice AI on Kubernetes with GPU acceleration. The deployment is optimized for NVIDIA RTX 5090 with 32GB VRAM and 96GB RAM systems.

## Prerequisites

### Hardware Requirements

- **GPU**: NVIDIA RTX 5090 (32GB VRAM) or similar
- **CPU**: 8+ cores (16+ recommended)
- **Memory**: 32GB+ RAM (64GB+ recommended)
- **Storage**: 100GB+ available SSD space

### Software Requirements

- **Operating System**: Linux (Ubuntu 20.04+ recommended)
- **NVIDIA Drivers**: 535+ or latest
- **Docker**: Latest version
- **kubectl**: Kubernetes command-line tool
- **Helm**: Package manager for Kubernetes (v3.0+)

### System Preparation

1. **Install NVIDIA Drivers**:
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install nvidia-driver-535 nvidia-cuda-toolkit
   
   # Verify installation
   nvidia-smi
   ```

2. **Install Docker**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

3. **Install kubectl**:
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

4. **Install Helm**:
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

## Quick Start (One-Command Deployment)

For the fastest deployment experience, use our automated script:

```bash
# Clone the repository
git clone https://github.com/matlowai/local-voice-ai.git
cd local-voice-ai

# Deploy with GPU acceleration
./kubernetes/scripts/deploy-gpu.sh
```

This script will:
- Detect your hardware and optimize configuration
- Install K3s with GPU support
- Deploy all services with GPU acceleration
- Set up monitoring and ingress
- Verify the deployment

### Alternative Deployment Methods

If you encounter permission issues with the scripts, try these alternatives:

#### Method 1: Simple Deployment (No executable permissions required)
```bash
# Simple deployment that fixes permissions automatically
bash kubernetes/scripts/deploy-gpu-simple.sh
```

#### Method 2: Manual Permission Fix
```bash
# Fix permissions first
chmod +x kubernetes/scripts/*.sh kubernetes/install/*.sh

# Then run the deployment
./kubernetes/scripts/deploy-gpu.sh
```

#### Method 3: Direct Script Execution
```bash
# Run script directly with bash interpreter
bash kubernetes/scripts/deploy-gpu.sh
```

#### Method 4: Step-by-Step Deployment
```bash
# Run each step manually
bash kubernetes/install/install-k3s-gpu.sh
kubectl apply -f kubernetes/base/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/
```

## Detailed Deployment Steps

### Step 1: Hardware Detection and Configuration

```bash
# Detect hardware and get optimized configuration
./kubernetes/install/detect-hardware.sh
```

This will analyze your system and create a hardware-specific configuration file at `kubernetes/config/hardware-config.yaml`.

### Step 2: Install K3s with GPU Support

```bash
# Install K3s with GPU support
./kubernetes/install/install-k3s-gpu.sh
```

This will:
- Install K3s Kubernetes distribution
- Configure NVIDIA GPU support
- Set up GPU device plugins
- Configure resource limits

### Step 3: Deploy Base Infrastructure

```bash
# Create namespaces and base configurations
kubectl apply -f kubernetes/base/00-namespace.yaml
kubectl apply -f kubernetes/base/01-configmaps.yaml
kubectl apply -f kubernetes/base/02-secrets.yaml
kubectl apply -f kubernetes/base/03-storage.yaml
kubectl apply -f kubernetes/base/04-network-policies.yaml
```

### Step 4: Deploy AI Services

```bash
# Deploy Ollama (LLM service)
kubectl apply -f kubernetes/services/ollama/deployment-gpu.yaml
kubectl apply -f kubernetes/services/ollama/service.yaml

# Deploy Whisper (STT service)
kubectl apply -f kubernetes/services/whisper/deployment-gpu.yaml
kubectl apply -f kubernetes/services/whisper/service.yaml

# Deploy Kokoro (TTS service)
kubectl apply -f kubernetes/services/kokoro/deployment-gpu.yaml
kubectl apply -f kubernetes/services/kokoro/service.yaml

# Deploy Agent (orchestration service)
kubectl apply -f kubernetes/services/agent/deployment-gpu.yaml
kubectl apply -f kubernetes/services/agent/service.yaml

# Deploy LiveKit (signaling service)
kubectl apply -f kubernetes/services/livekit/deployment.yaml
kubectl apply -f kubernetes/services/livekit/service.yaml

# Deploy Frontend (web interface)
kubectl apply -f kubernetes/services/frontend/deployment.yaml
kubectl apply -f kubernetes/services/frontend/service.yaml
```

### Step 5: Deploy Ingress and Monitoring

```bash
# Deploy ingress configuration
kubectl apply -f kubernetes/ingress/ingress-routes.yaml

# Deploy monitoring stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.adminPassword=admin123 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30030
```

### Step 6: Verify Deployment

```bash
# Run comprehensive verification
./kubernetes/scripts/verify-deployment.sh
```

## Accessing Your Deployment

### Web Interface

- **Frontend**: http://localhost:30080
- **Grafana Dashboard**: http://localhost:30030 (admin/admin123)
- **Prometheus**: http://localhost:30090

### API Endpoints

- **Ollama API**: http://localhost/api/ollama
- **Whisper API**: http://localhost/api/whisper
- **Kokoro API**: http://localhost/api/kokoro
- **Agent API**: http://localhost/api/agent

### Service URLs

- **LiveKit WebSocket**: ws://localhost/livekit
- **Health Checks**: http://localhost/api/health

## Configuration

### Environment Variables

Key environment variables can be modified in the ConfigMaps:

```bash
# Edit configuration
kubectl edit configmap voice-ai-config -n voice-ai
kubectl edit configmap ollama-config -n voice-ai
kubectl edit configmap whisper-config -n voice-ai
```

### GPU Settings

GPU allocation can be adjusted in the GPU ConfigMap:

```bash
# Edit GPU configuration
kubectl edit configmap gpu-config -n voice-ai
```

### Model Configuration

To change AI models:

```bash
# Edit Ollama models
kubectl edit configmap ollama-config -n voice-ai
# Update OLLAMA_MODELS field

# Restart Ollama to apply changes
kubectl rollout restart deployment/ollama -n voice-ai
```

## Management Commands

### Viewing Services

```bash
# View all pods
kubectl get pods -n voice-ai

# View services
kubectl get svc -n voice-ai

# View PVCs
kubectl get pvc -n voice-ai
```

### Logs

```bash
# View logs for a specific service
kubectl logs -f deployment/ollama -n voice-ai
kubectl logs -f deployment/whisper -n voice-ai
kubectl logs -f deployment/agent -n voice-ai
```

### Scaling

```bash
# Scale a service
kubectl scale deployment/ollama --replicas=2 -n voice-ai

# Check horizontal pod autoscaler status
kubectl get hpa -n voice-ai
```

### Updates

```bash
# Update a service
kubectl set image deployment/ollama ollama=new-image:tag -n voice-ai

# Rollout restart
kubectl rollout restart deployment/ollama -n voice-ai

# Check rollout status
kubectl rollout status deployment/ollama -n voice-ai
```

## GPU Management

### Monitoring GPU Usage

```bash
# Check GPU utilization in pods
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi

# View GPU metrics in Grafana
# Navigate to http://localhost:30030
# Open the "GPU Metrics" dashboard
```

### GPU Troubleshooting

```bash
# Check GPU device plugin
kubectl get pods -n gpu-operator

# Check GPU node status
kubectl describe nodes

# Check GPU allocation
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"
```

## CPU Fallback Mode

If GPU becomes unavailable, the system can automatically switch to CPU mode:

### Manual Switch to CPU

```bash
# Switch all services to CPU mode
./kubernetes/scripts/switch-to-cpu.sh switch-cpu

# Check current status
./kubernetes/scripts/switch-to-cpu.sh status
```

### Automatic GPU Monitoring

```bash
# Monitor GPU health and auto-switch if needed
./kubernetes/scripts/switch-to-cpu.sh monitor
```

### Switch Back to GPU

```bash
# Switch back to GPU mode when available
./kubernetes/scripts/switch-to-cpu.sh switch-gpu
```

## Troubleshooting

### Script Permission Issues

#### Permission Denied Errors

If you encounter "Permission denied" errors when running scripts:

```bash
# Fix all script permissions at once
chmod +x kubernetes/scripts/*.sh kubernetes/install/*.sh

# Verify permissions are fixed
ls -la kubernetes/scripts/*.sh kubernetes/install/*.sh

# Run the script again
./kubernetes/scripts/deploy-gpu.sh
```

#### Alternative Execution Methods

If permission fixes don't work:

```bash
# Method 1: Use bash interpreter directly
bash kubernetes/scripts/deploy-gpu.sh

# Method 2: Use simple deployment script
bash kubernetes/scripts/deploy-gpu-simple.sh

# Method 3: Run with sh (fallback)
sh kubernetes/scripts/deploy-gpu.sh

# Method 4: Source the script
source kubernetes/scripts/deploy-gpu.sh
```

#### Automatic Permission Fixing

The main deployment script includes automatic permission fixing:

```bash
# The deploy-gpu.sh script will automatically fix permissions
# when it detects permission issues
./kubernetes/scripts/deploy-gpu.sh
```

#### Filesystem Permission Issues

If you're on a filesystem that doesn't support executable permissions:

```bash
# Check filesystem type
df -T .

# If using NTFS, FAT32, or similar, use bash interpreter
bash kubernetes/scripts/deploy-gpu.sh

# Copy to a Linux filesystem if possible
cp -r kubernetes /tmp/local-voice-ai-k8s
cd /tmp/local-voice-ai-k8s
chmod +x scripts/*.sh install/*.sh
./scripts/deploy-gpu.sh
```

### Common Issues

#### 1. GPU Not Detected

```bash
# Check NVIDIA drivers
nvidia-smi

# Check GPU device plugin
kubectl get pods -n gpu-operator

# Restart GPU operator
kubectl rollout restart deployment/gpu-operator -n gpu-operator
```

#### 2. Services Not Starting

```bash
# Check pod status
kubectl get pods -n voice-ai

# Describe pod for errors
kubectl describe pod <pod-name> -n voice-ai

# View pod logs
kubectl logs <pod-name> -n voice-ai
```

#### 3. Storage Issues

```bash
# Check PVC status
kubectl get pvc -n voice-ai

# Check storage class
kubectl get storageclass

# Describe PVC for errors
kubectl describe pvc <pvc-name> -n voice-ai
```

#### 4. Network Issues

```bash
# Check service endpoints
kubectl get endpoints -n voice-ai

# Check network policies
kubectl get networkpolicy -n voice-ai

# Test service connectivity
kubectl port-forward svc/ollama 11434:11434 -n voice-ai
curl http://localhost:11434/api/tags
```

### Performance Issues

#### 1. High GPU Memory Usage

```bash
# Check GPU memory allocation
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi

# Reduce GPU memory allocation
kubectl edit configmap gpu-config -n voice-ai

# Restart affected services
kubectl rollout restart deployment/ollama -n voice-ai
```

#### 2. Slow Response Times

```bash
# Check resource usage
kubectl top pods -n voice-ai

# Check pod resource limits
kubectl describe pod <pod-name> -n voice-ai

# Increase resource limits if needed
kubectl edit deployment/<service> -n voice-ai
```

## Maintenance

### Backup and Recovery

```bash
# Backup configurations
kubectl get all -n voice-ai -o yaml > backup.yaml

# Backup persistent data
kubectl exec -n voice-ai deployment/ollama -- tar czf /tmp/ollama-backup.tar.gz /root/.ollama
kubectl cp voice-ai/ollama-pod:/tmp/ollama-backup.tar.gz ./ollama-backup.tar.gz
```

### Updates and Upgrades

```bash
# Update K3s
sudo k3s-check-update
sudo k3s-update

# Update NVIDIA drivers
sudo apt update
sudo apt upgrade nvidia-driver-535

# Update applications
kubectl set image deployment/ollama ollama=ollama/ollama:latest -n voice-ai
```

### Cleanup

```bash
# Remove unused resources
kubectl delete pods -n voice-ai --field-selector=status.phase=Succeeded
kubectl delete pods -n voice-ai --field-selector=status.phase=Failed

# Clean up old images
sudo docker system prune -a
```

## Security

### Network Security

The deployment uses zero-trust networking with default-deny policies. Only necessary communication is allowed between services.

### Pod Security

All containers run as non-root users with minimal privileges and read-only filesystems where possible.

### Secrets Management

Sensitive data is stored in Kubernetes Secrets with proper access controls.

## Production Considerations

### High Availability

- Configure multiple replicas for critical services
- Set up pod disruption budgets
- Configure resource requests and limits
- Implement proper backup strategies

### Monitoring

- Set up comprehensive monitoring with Prometheus and Grafana
- Configure alerts for critical metrics
- Monitor GPU utilization and temperature
- Set up log aggregation

### Scaling

- Configure horizontal pod autoscalers
- Set up cluster autoscaling if needed
- Monitor resource utilization
- Plan capacity based on usage patterns

## Support

### Documentation

- [Architecture Documentation](docs/kubernetes-architecture.md)
- [Development Workflow](docs/development-workflow.md)
- [Testing Guide](docs/testing-guide.md)

### Community

- GitHub Issues: https://github.com/matlowai/local-voice-ai/issues
- Discussions: https://github.com/matlowai/local-voice-ai/discussions

### Troubleshooting

For additional troubleshooting:

1. **Permission Issues**:
   - Try: `bash kubernetes/scripts/deploy-gpu-simple.sh`
   - Fix: `chmod +x kubernetes/scripts/*.sh kubernetes/install/*.sh`
   - Alternative: `bash kubernetes/scripts/deploy-gpu.sh`

2. Check the logs: `./kubernetes/scripts/verify-deployment.sh`
3. Review the architecture documentation
4. Search existing GitHub issues
5. Create a new issue with detailed information

### Quick Reference: Permission Solutions

| Problem | Solution | Command |
|---------|----------|---------|
| Permission denied | Fix permissions | `chmod +x kubernetes/scripts/*.sh kubernetes/install/*.sh` |
| Scripts not executable | Use bash interpreter | `bash kubernetes/scripts/deploy-gpu.sh` |
| Auto-fix needed | Simple deployment script | `bash kubernetes/scripts/deploy-gpu-simple.sh` |
| Filesystem limitations | Copy to Linux filesystem | `cp -r kubernetes /tmp/ && chmod +x /tmp/kubernetes/scripts/*.sh` |

## Conclusion

This Kubernetes deployment provides a robust, scalable, and high-performance solution for Local Voice AI with GPU acceleration. The automated deployment scripts make it easy to get started, while the detailed configuration options allow for customization based on your specific requirements.

The GPU-optimized architecture delivers exceptional performance for AI workloads, while the CPU fallback ensures continuous operation even when GPU resources are unavailable. This makes it an ideal solution for both development and production environments.