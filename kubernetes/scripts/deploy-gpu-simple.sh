#!/bin/bash

# Simple GPU Deployment Script - No executable permissions required
# Usage: bash kubernetes/scripts/deploy-gpu-simple.sh

echo "🚀 Local Voice AI - Simple GPU Deployment"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Fix permissions first
print_status "info" "Fixing script permissions..."
chmod +x kubernetes/scripts/*.sh kubernetes/install/*.sh 2>/dev/null || true
print_status "success" "Permissions fixed"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_status "error" "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_status "error" "Cannot connect to Kubernetes cluster. Please ensure K3s is installed and running."
    exit 1
fi

print_status "success" "Cluster connectivity verified"

# Function to apply kubectl resources with retry logic
kubectl_apply_with_retry() {
    local resource_file=$1
    local resource_name=$(basename "$resource_file")
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl apply -f "$resource_file"; then
            print_status "success" "$resource_name applied successfully"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "error" "Failed to apply $resource_name after $max_attempts attempts"
            return 1
        fi
        
        print_status "warning" "Failed to apply $resource_name, retrying... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
}

# Function to install snapshot CRDs if needed
install_snapshot_crds() {
    print_status "info" "Checking for VolumeSnapshot CRDs..."
    
    # Check if VolumeSnapshot CRD exists
    if ! kubectl get crd volumesnapshots.snapshot.storage.k8s.io &> /dev/null; then
        print_status "info" "Installing VolumeSnapshot CRDs..."
        
        # Install snapshot CRDs
        kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml || \
            print_status "warning" "Failed to install VolumeSnapshotClass CRD"
        
        kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml || \
            print_status "warning" "Failed to install VolumeSnapshot CRD"
        
        kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml || \
            print_status "warning" "Failed to install VolumeSnapshotContent CRD"
        
        print_status "success" "VolumeSnapshot CRDs installed"
    else
        print_status "info" "VolumeSnapshot CRDs already exist"
    fi
}

# Function to deploy GPU operator
deploy_gpu_operator() {
    # Check if GPU is available
    if ! kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
        print_status "info" "No GPU detected, skipping GPU operator deployment"
        return 0
    fi
    
    print_status "info" "GPU detected, deploying GPU operator..."
    
    # Check if GPU operator is already installed
    if kubectl get namespace gpu-operator &> /dev/null && \
       kubectl get deployment gpu-operator -n gpu-operator &> /dev/null; then
        print_status "info" "GPU Operator already installed"
        return 0
    fi
    
    # Add NVIDIA Helm repository
    print_status "info" "Adding NVIDIA Helm repository..."
    helm repo add nvidia https://nvidia.github.io/gpu-operator || \
        print_status "warning" "Failed to add NVIDIA repo, trying to continue..."
    
    helm repo update || \
        print_status "warning" "Failed to update Helm repos, trying to continue..."
    
    # Install GPU Operator
    print_status "info" "Installing GPU Operator..."
    if helm install gpu-operator nvidia/gpu-operator \
        --namespace gpu-operator \
        --create-namespace \
        --set driver.enabled=false \
        --set toolkit.enabled=true \
        --set devicePlugin.enabled=true \
        --set migManager.enabled=false \
        --set gfd.enabled=true \
        --set migStrategy=single \
        --set runtimeClassName=nvidia; then
        print_status "success" "GPU Operator installed"
    else
        print_status "warning" "Failed to install GPU Operator, continuing without GPU acceleration"
    fi
}

# Install snapshot CRDs first
install_snapshot_crds

# Deploy GPU operator if GPU is available
deploy_gpu_operator

# Create namespace
print_status "info" "Creating namespace..."
kubectl_apply_with_retry kubernetes/base/00-namespace.yaml

# Apply base configurations
print_status "info" "Applying base configurations..."
kubectl_apply_with_retry kubernetes/base/01-configmaps.yaml
kubectl_apply_with_retry kubernetes/base/02-secrets.yaml

# Apply storage with error handling (StorageClass conflicts are expected)
print_status "info" "Applying storage configuration..."
if kubectl apply -f kubernetes/base/03-storage.yaml; then
    print_status "success" "Storage configuration applied"
else
    print_status "warning" "Some storage resources failed to create (this is expected for existing StorageClasses)"
    print_status "info" "Continuing with deployment..."
fi

kubectl_apply_with_retry kubernetes/base/04-network-policies.yaml

# Deploy GPU services
print_status "info" "Deploying GPU services..."
kubectl_apply_with_retry kubernetes/services/ollama/deployment-gpu.yaml
kubectl_apply_with_retry kubernetes/services/ollama/service.yaml
kubectl_apply_with_retry kubernetes/services/whisper/deployment-gpu.yaml

# Check if service.yaml exists for whisper
if [[ -f "kubernetes/services/whisper/service.yaml" ]]; then
    kubectl_apply_with_retry kubernetes/services/whisper/service.yaml
fi

kubectl_apply_with_retry kubernetes/services/agent/deployment-gpu.yaml

# Check if service.yaml exists for agent
if [[ -f "kubernetes/services/agent/service.yaml" ]]; then
    kubectl_apply_with_retry kubernetes/services/agent/service.yaml
fi

# Deploy ingress
print_status "info" "Deploying ingress..."
kubectl_apply_with_retry kubernetes/ingress/ingress-routes.yaml

print_status "success" "Deployment completed!"
echo ""
echo "Next steps:"
echo "1. Check pod status: kubectl get pods -n voice-ai"
echo "2. Check services: kubectl get svc -n voice-ai"
echo "3. Access frontend: http://localhost:30080"
echo ""
print_status "info" "For detailed deployment, run: bash kubernetes/scripts/deploy-gpu.sh"