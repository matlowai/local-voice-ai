# Kubernetes Deployment Fixes

This document describes the fixes applied to resolve Kubernetes deployment issues with Local Voice AI.

## Issues Fixed

### 1. StorageClass Conflicts
**Problem**: The deployment script was trying to create a `local-path` StorageClass that already exists in K3s.

**Solution**: 
- Removed the duplicate `local-path` StorageClass definition from [`kubernetes/base/03-storage.yaml`](kubernetes/base/03-storage.yaml)
- Added logic to use existing K3s StorageClass and apply labels to it
- Created fallback PVC creation logic if the main storage configuration fails

### 2. VolumeSnapshotClass Missing CRDs
**Problem**: VolumeSnapshot resources were being created without the required Custom Resource Definitions (CRDs).

**Solution**:
- Added automatic installation of VolumeSnapshot CRDs from the official Kubernetes CSI repository
- Added proper error handling for CRD installation
- Made VolumeSnapshotClass deployment conditional on CRD availability

### 3. GPU Resources Not Detected
**Problem**: GPU operator wasn't being deployed automatically, causing GPU resources to be unavailable.

**Solution**:
- Added automatic GPU operator deployment to both [`deploy-gpu.sh`](kubernetes/scripts/deploy-gpu.sh) and [`deploy-gpu-simple.sh`](kubernetes/scripts/deploy-gpu-simple.sh)
- Added GPU resource detection and verification
- Added retry logic for GPU operator installation
- Added proper waiting for GPU operator to become ready

### 4. Poor Error Handling
**Problem**: Deployment scripts would fail on the first error without providing context or recovery options.

**Solution**:
- Added comprehensive error handling with retry logic
- Added non-critical error handling (warnings instead of failures for expected issues)
- Added detailed status reporting and troubleshooting information
- Added graceful degradation when non-critical components fail

### 5. Transient Kubernetes API Issues
**Problem**: Deployment would fail on temporary Kubernetes API issues without retrying.

**Solution**:
- Added `kubectl_apply_with_retry()` function with configurable retry attempts
- Added exponential backoff for API calls
- Added proper waiting for cluster readiness before deployment

## New Scripts

### fix-deployment-issues.sh
A standalone script that fixes all known deployment issues before running the main deployment.

```bash
# Run this script first to fix all issues
bash kubernetes/scripts/fix-deployment-issues.sh
```

**Features**:
- Installs VolumeSnapshot CRDs
- Fixes StorageClass conflicts
- Deploys GPU operator (if GPU detected)
- Applies storage configuration with conflict handling
- Verifies all fixes

## Updated Deployment Scripts

### deploy-gpu.sh
Enhanced with:
- GPU operator deployment before service deployment
- Improved error handling with retry logic
- Better storage conflict resolution
- Comprehensive status reporting

### deploy-gpu-simple.sh
Enhanced with:
- Basic GPU operator deployment
- Snapshot CRD installation
- Storage conflict handling
- Retry logic for critical operations

## Deployment Instructions

### Option 1: Full Fix + Deployment (Recommended)
```bash
# 1. Fix all deployment issues
bash kubernetes/scripts/fix-deployment-issues.sh

# 2. Run the full deployment
bash kubernetes/scripts/deploy-gpu.sh
```

### Option 2: Simple Deployment
```bash
# Run the simple deployment with built-in fixes
bash kubernetes/scripts/deploy-gpu-simple.sh
```

### Option 3: Manual Step-by-Step
```bash
# 1. Check cluster connectivity
kubectl cluster-info

# 2. Install snapshot CRDs
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml

# 3. Deploy GPU operator (if GPU available)
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=false \
  --set toolkit.enabled=true \
  --set devicePlugin.enabled=true \
  --set migManager.enabled=false \
  --set gfd.enabled=true \
  --set migStrategy=single \
  --set runtimeClassName=nvidia

# 4. Apply base resources
kubectl apply -f kubernetes/base/00-namespace.yaml
kubectl apply -f kubernetes/base/01-configmaps.yaml
kubectl apply -f kubernetes/base/02-secrets.yaml
kubectl apply -f kubernetes/base/04-network-policies.yaml

# 5. Apply storage (with expected conflicts)
kubectl apply -f kubernetes/base/03-storage.yaml || echo "Storage conflicts expected, continuing..."

# 6. Deploy services
kubectl apply -f kubernetes/services/ollama/deployment-gpu.yaml
kubectl apply -f kubernetes/services/ollama/service.yaml
kubectl apply -f kubernetes/services/whisper/deployment-gpu.yaml
kubectl apply -f kubernetes/services/agent/deployment-gpu.yaml
kubectl apply -f kubernetes/ingress/ingress-routes.yaml
```

## Troubleshooting

### StorageClass Issues
```bash
# Check existing StorageClasses
kubectl get storageclass

# Check PVC status
kubectl get pvc -n voice-ai

# Fix StorageClass labels manually
kubectl label storageclass local-path \
  app.kubernetes.io/name=local-path \
  app.kubernetes.io/component=storage \
  app.kubernetes.io/part-of=local-voice-ai \
  --overwrite
```

### GPU Operator Issues
```bash
# Check GPU operator status
kubectl get pods -n gpu-operator

# Check GPU resources
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

# Restart GPU operator
kubectl rollout restart deployment/gpu-operator -n gpu-operator
```

### VolumeSnapshot Issues
```bash
# Check if CRDs are installed
kubectl get crd | grep snapshot

# Reinstall CRDs if needed
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
```

### General Deployment Issues
```bash
# Check all pod status
kubectl get pods -n voice-ai

# Check pod logs for errors
kubectl logs -f deployment/<service-name> -n voice-ai

# Check events
kubectl get events -n voice-ai --sort-by='.lastTimestamp'

# Restart specific service
kubectl rollout restart deployment/<service-name> -n voice-ai
```

## Expected Behavior After Fixes

1. **StorageClass Conflicts**: No more errors about existing `local-path` StorageClass
2. **VolumeSnapshot**: Proper backup functionality with CRDs installed
3. **GPU Detection**: RTX 5090 should be detected and GPU acceleration enabled
4. **Error Recovery**: Deployment continues despite non-critical failures
5. **Retry Logic**: Transient API issues are automatically retried

## Verification

After deployment, verify everything is working:

```bash
# Check all services are running
kubectl get pods -n voice-ai

# Check GPU resources are available
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

# Check storage is working
kubectl get pvc -n voice-ai

# Check services are accessible
kubectl get svc -n voice-ai

# Access the frontend
curl http://localhost:30080
```

## Performance Expectations

With the fixes applied and GPU acceleration working:
- **Ollama**: 10-50x faster inference with RTX 5090
- **Whisper**: Real-time speech-to-text processing
- **Kokoro**: Fast text-to-speech synthesis
- **Agent**: Efficient orchestration with GPU acceleration

## Support

If you encounter issues after applying these fixes:

1. Run the fix script again: `bash kubernetes/scripts/fix-deployment-issues.sh`
2. Check the troubleshooting section above
3. Review pod logs for specific error messages
4. Check the [K3S_TROUBLESHOOTING.md](kubernetes/K3S_TROUBLESHOOTING.md) guide