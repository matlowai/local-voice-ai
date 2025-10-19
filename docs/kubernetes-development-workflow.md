# Kubernetes Development Workflow for Local Voice AI

## Overview

This document describes the development workflow for Local Voice AI when using Kubernetes deployment with GPU acceleration. It covers everything from initial setup to daily development tasks, testing, and deployment.

## Prerequisites

### Development Environment

- **Hardware**: NVIDIA RTX 5090 (32GB VRAM) or similar, 96GB RAM
- **OS**: Linux (Ubuntu 20.04+ recommended)
- **Kubernetes**: K3s with GPU support
- **Tools**: kubectl, helm, docker, git

### Initial Setup

1. **Install Development Tools**:
   ```bash
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   
   # Install Helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **Clone Repository**:
   ```bash
   git clone https://github.com/matlowai/local-voice-ai.git
   cd local-voice-ai
   ```

3. **Set Up Kubernetes Cluster**:
   ```bash
   # Install K3s with GPU support
   ./kubernetes/install/install-k3s-gpu.sh
   
   # Verify installation
   kubectl cluster-info
   ```

## Development Workflow

### 1. Local Development Setup

#### Hardware Detection
```bash
# Detect hardware and generate configuration
./kubernetes/install/detect-hardware.sh
```

#### Deploy Development Environment
```bash
# Deploy services for development
./kubernetes/scripts/deploy-gpu.sh
```

#### Verify Deployment
```bash
# Verify all services are running
./kubernetes/scripts/verify-deployment.sh
```

### 2. Daily Development Tasks

#### Starting the Development Environment
```bash
# Start the cluster if stopped
sudo systemctl start k3s

# Check pod status
kubectl get pods -n voice-ai

# Access services
# Frontend: http://localhost:30080
# Grafana: http://localhost:30030
```

#### Monitoring GPU Usage
```bash
# Check GPU utilization
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi

# Monitor GPU metrics in Grafana
# Navigate to http://localhost:30030
```

#### Viewing Logs
```bash
# View logs for specific services
kubectl logs -f deployment/ollama -n voice-ai
kubectl logs -f deployment/whisper -n voice-ai
kubectl logs -f deployment/agent -n voice-ai

# View logs for all services
stern -n voice-ai .
```

#### Debugging Services
```bash
# Port-forward to access services locally
kubectl port-forward svc/ollama 11434:11434 -n voice-ai
kubectl port-forward svc/whisper 11435:80 -n voice-ai

# Exec into a pod for debugging
kubectl exec -it deployment/ollama -n voice-ai -- bash

# Check pod events
kubectl describe pod <pod-name> -n voice-ai
```

### 3. Code Development

#### Service Development Workflow

1. **Make Code Changes**:
   ```bash
   # Edit source code in your preferred IDE
   # For example, modify the agent service
   cd agent
   # Make changes to myagent.py
   ```

2. **Build and Deploy**:
   ```bash
   # Build Docker image
   docker build -t local-voice-ai/agent:dev -f agent/Dockerfile .
   
   # Deploy updated service
   kubectl set image deployment/agent agent=local-voice-ai/agent:dev -n voice-ai
   
   # Wait for rollout
   kubectl rollout status deployment/agent -n voice-ai
   ```

3. **Test Changes**:
   ```bash
   # Test the updated service
   curl http://localhost/api/agent/health
   
   # Check logs for issues
   kubectl logs -f deployment/agent -n voice-ai
   ```

#### Hot Reload Development

For faster development, you can use hot reload:

```bash
# Enable hot reload for frontend
kubectl set env deployment/frontend NODE_ENV=development -n voice-ai
kubectl rollout restart deployment/frontend -n voice-ai

# Mount local directory for development
kubectl patch deployment/agent -p '{"spec":{"template":{"spec":{"volumes":[{"name":"code","hostPath":{"path":"/path/to/local/code"}}],"containers":[{"name":"agent","volumeMounts":[{"name":"code","mountPath":"/app"}]}]}}}}' -n voice-ai
```

### 4. Testing

#### Unit Testing

```bash
# Run unit tests for agent
cd agent
python -m pytest tests/

# Run unit tests for frontend
cd voice-assistant-frontend
npm test
```

#### Integration Testing

```bash
# Test service integration
./kubernetes/scripts/test-integration.sh

# Test GPU functionality
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi
kubectl exec -n voice-ai deployment/whisper -- python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

#### End-to-End Testing

```bash
# Run E2E tests
./kubernetes/scripts/test-e2e.sh

# Test voice workflow
# 1. Record audio
# 2. Send to Whisper for transcription
# 3. Send to Ollama for response
# 4. Send to Kokoro for TTS
# 5. Verify response
```

#### Performance Testing

```bash
# Benchmark GPU performance
kubectl exec -n voice-ai deployment/ollama -- /scripts/benchmark.sh

# Test concurrent users
./kubernetes/scripts/test-load.sh
```

### 5. Configuration Management

#### Environment-Specific Configurations

```bash
# Create development configuration
kubectl create configmap dev-config --from-env-file=.env.dev -n voice-ai

# Apply configuration
kubectl patch deployment/agent -p '{"spec":{"template":{"spec":{"containers":[{"name":"agent","envFrom":[{"configMapRef":{"name":"dev-config"}}]}]}}}}' -n voice-ai
```

#### Secret Management

```bash
# Create development secrets
kubectl create secret generic dev-secrets --from-env-file=.secrets.dev -n voice-ai

# Apply secrets
kubectl patch deployment/ollama -p '{"spec":{"template":{"spec":{"containers":[{"name":"ollama","envFrom":[{"secretRef":{"name":"dev-secrets"}}]}]}}}}' -n voice-ai
```

#### Model Management

```bash
# List available models
kubectl exec -n voice-ai deployment/ollama -- ollama list

# Pull new model
kubectl exec -n voice-ai deployment/ollama -- ollama pull llama3:8b

# Update configuration to use new model
kubectl patch configmap ollama-config -p '{"data":{"OLLAMA_MODEL":"llama3:8b"}}' -n voice-ai
kubectl rollout restart deployment/ollama -n voice-ai
```

### 6. GPU Development

#### GPU Optimization

```bash
# Check GPU memory usage
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi --query-gpu=memory.used,memory.total --format=csv

# Optimize GPU memory allocation
kubectl edit configmap gpu-config -n voice-ai

# Restart service to apply changes
kubectl rollout restart deployment/ollama -n voice-ai
```

#### GPU Debugging

```bash
# Check GPU device plugin
kubectl get pods -n gpu-operator

# Check GPU allocation
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

# Debug GPU issues
kubectl logs -n gpu-operator deployment/gpu-operator
```

#### GPU Performance Tuning

```bash
# Monitor GPU metrics
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi dmon -s u

# Optimize batch sizes
kubectl edit deployment/ollama -n voice-ai

# Test performance improvements
./kubernetes/scripts/benchmark-gpu.sh
```

### 7. CPU Fallback Development

#### Testing CPU Fallback

```bash
# Switch to CPU mode
./kubernetes/scripts/switch-to-cpu.sh switch-cpu

# Test CPU performance
./kubernetes/scripts/benchmark-cpu.sh

# Switch back to GPU
./kubernetes/scripts/switch-to-cpu.sh switch-gpu
```

#### CPU Optimization

```bash
# Optimize CPU settings
kubectl edit configmap cpu-config -n voice-ai

# Monitor CPU usage
kubectl top pods -n voice-ai

# Adjust resource limits
kubectl edit deployment/agent-cpu -n voice-ai
```

### 8. CI/CD Integration

#### Git Workflow

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
git add .
git commit -m "Add new feature"

# Push to remote
git push origin feature/new-feature

# Create pull request
```

#### Automated Testing

```bash
# Run pre-commit hooks
./scripts/pre-commit.sh

# Run automated tests
./scripts/run-tests.sh

# Run linting
./scripts/lint.sh
```

#### Automated Deployment

```bash
# Deploy to staging
./scripts/deploy-staging.sh

# Run integration tests
./scripts/test-staging.sh

# Deploy to production
./scripts/deploy-production.sh
```

### 9. Troubleshooting

#### Common Issues

##### GPU Not Available

```bash
# Check NVIDIA drivers
nvidia-smi

# Check GPU device plugin
kubectl get pods -n gpu-operator

# Restart GPU operator
kubectl rollout restart deployment/gpu-operator -n gpu-operator
```

##### Services Not Starting

```bash
# Check pod status
kubectl get pods -n voice-ai

# Describe pod for errors
kubectl describe pod <pod-name> -n voice-ai

# View pod logs
kubectl logs <pod-name> -n voice-ai

# Check resource limits
kubectl describe pod <pod-name> -n voice-ai | grep -A 10 "Limits"
```

##### Performance Issues

```bash
# Check resource usage
kubectl top pods -n voice-ai

# Check GPU utilization
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi

# Check network latency
kubectl exec -n voice-ai deployment/agent -- ping ollama.voice-ai.svc.cluster.local
```

#### Debugging Tools

##### Stern for Log Aggregation

```bash
# Install stern
curl https://get.stern.sh | sh

# View logs for all services
stern -n voice-ai .

# View logs for specific service
stern -n voice-ai ollama
```

##### K9s for Cluster Management

```bash
# Install k9s
curl -sS https://webinstall.dev/k9s | sh

# Launch k9s
k9s -n voice-ai
```

##### Lens for GUI Management

```bash
# Download and install Lens
# https://k8slens.dev/

# Connect to your cluster
# Navigate to voice-ai namespace
```

### 10. Performance Monitoring

#### GPU Metrics

```bash
# Monitor GPU utilization
watch -n 1 'kubectl exec -n voice-ai deployment/ollama -- nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits'

# View GPU metrics in Grafana
# Navigate to http://localhost:30030
# Open "GPU Metrics" dashboard
```

#### Service Metrics

```bash
# View service metrics
kubectl exec -n voice-ai deployment/agent -- curl http://localhost:8080/metrics

# View metrics in Prometheus
# Navigate to http://localhost:30090
# Explore metrics
```

#### Custom Dashboards

```bash
# Import custom dashboards to Grafana
# Navigate to http://localhost:30030
# Import > Upload JSON file
# Select dashboard from kubernetes/monitoring/dashboards/
```

### 11. Maintenance

#### Updates

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

#### Backup

```bash
# Backup configurations
kubectl get all -n voice-ai -o yaml > backup.yaml

# Backup persistent data
kubectl exec -n voice-ai deployment/ollama -- tar czf /tmp/ollama-backup.tar.gz /root/.ollama
kubectl cp voice-ai/ollama-<pod>:/tmp/ollama-backup.tar.gz ./ollama-backup.tar.gz
```

#### Cleanup

```bash
# Remove unused resources
kubectl delete pods -n voice-ai --field-selector=status.phase=Succeeded
kubectl delete pods -n voice-ai --field-selector=status.phase=Failed

# Clean up old images
sudo docker system prune -a

# Clean up old PVCs
kubectl delete pvc <pvc-name> -n voice-ai
```

## Best Practices

### 1. Development Environment

- Use a dedicated development namespace
- Keep development configurations separate from production
- Use resource limits to prevent resource exhaustion
- Regularly update dependencies and base images

### 2. Code Organization

- Follow the established directory structure
- Use meaningful commit messages
- Write comprehensive tests
- Document API changes

### 3. GPU Development

- Monitor GPU usage regularly
- Optimize GPU memory allocation
- Test both GPU and CPU modes
- Handle GPU failures gracefully

### 4. Testing

- Write unit tests for all components
- Perform integration tests regularly
- Test edge cases and error conditions
- Monitor test coverage

### 5. Deployment

- Use GitOps for deployment management
- Test deployments in staging first
- Monitor deployments after release
- Have rollback procedures ready

## Conclusion

This Kubernetes development workflow provides a comprehensive guide for developing Local Voice AI with GPU acceleration. The workflow covers everything from initial setup to daily development tasks, testing, and deployment.

By following this workflow, developers can efficiently work with the GPU-accelerated Kubernetes deployment, making the most of the RTX 5090's capabilities while maintaining a robust and scalable development environment.

The workflow is designed to be flexible and adaptable, allowing developers to customize it based on their specific requirements and preferences. Whether you're working on new features, fixing bugs, or optimizing performance, this workflow provides the tools and processes needed for effective development.