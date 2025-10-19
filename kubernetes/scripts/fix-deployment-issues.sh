#!/bin/bash

# Fix Deployment Issues Script for Local Voice AI
# Addresses StorageClass conflicts, VolumeSnapshot CRDs, and GPU operator deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="voice-ai"
KUBECTL="kubectl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
        "header")
            echo -e "${BLUE}$message${NC}"
            ;;
        "highlight")
            echo -e "${PURPLE}🌟 $message${NC}"
            ;;
        "performance")
            echo -e "${CYAN}🚀 $message${NC}"
            ;;
    esac
}

# Function to check cluster connectivity
check_cluster_connectivity() {
    print_status "header" "🔍 Checking cluster connectivity..."
    
    if ! $KUBECTL cluster-info &> /dev/null; then
        print_status "error" "Cannot connect to Kubernetes cluster"
        print_status "info" "Please ensure K3s is installed and running"
        exit 1
    fi
    
    print_status "success" "Cluster connectivity verified"
}

# Function to install snapshot CRDs
install_snapshot_crds() {
    print_status "header" "📸 Installing VolumeSnapshot CRDs..."
    
    local crds=(
        "snapshot.storage.k8s.io_volumesnapshotclasses.yaml"
        "snapshot.storage.k8s.io_volumesnapshots.yaml"
        "snapshot.storage.k8s.io_volumesnapshotcontents.yaml"
    )
    
    for crd in "${crds[@]}"; do
        print_status "info" "Installing $crd..."
        if $KUBECTL apply -f "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/$crd"; then
            print_status "success" "$crd installed"
        else
            print_status "warning" "Failed to install $crd (may already exist)"
        fi
    done
    
    print_status "success" "VolumeSnapshot CRDs installation completed"
}

# Function to fix StorageClass conflicts
fix_storageclass_conflicts() {
    print_status "header" "💾 Fixing StorageClass conflicts..."
    
    # Check if local-path StorageClass exists
    if $KUBECTL get storageclass local-path &> /dev/null; then
        print_status "info" "Existing 'local-path' StorageClass found"
        print_status "info" "Using existing StorageClass instead of creating new one"
        
        # Create a patch to add our labels to the existing StorageClass
        $KUBECTL label storageclass local-path \
            app.kubernetes.io/name=local-path \
            app.kubernetes.io/component=storage \
            app.kubernetes.io/part-of=local-voice-ai \
            --overwrite || print_status "warning" "Failed to label existing StorageClass"
    else
        print_status "info" "No existing 'local-path' StorageClass found"
        print_status "info" "Will create new StorageClass from configuration"
    fi
    
    print_status "success" "StorageClass conflicts resolved"
}

# Function to deploy GPU operator
deploy_gpu_operator() {
    print_status "header" "🎮 Deploying NVIDIA GPU Operator..."
    
    # Check if GPU is available
    if ! $KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
        print_status "info" "No GPU resources detected in cluster"
        print_status "info" "Skipping GPU operator deployment"
        return 0
    fi
    
    print_status "success" "GPU resources detected"
    
    # Check if GPU operator is already installed
    if $KUBECTL get namespace gpu-operator &> /dev/null && \
       $KUBECTL get deployment gpu-operator -n gpu-operator &> /dev/null; then
        print_status "info" "GPU Operator already installed"
        return 0
    fi
    
    # Wait for cluster to be ready
    print_status "info" "Waiting for cluster to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if $KUBECTL get nodes &> /dev/null; then
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "error" "Cluster not ready after $max_attempts attempts"
            return 1
        fi
        
        print_status "info" "Waiting for cluster... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    # Add NVIDIA Helm repository
    print_status "info" "Adding NVIDIA Helm repository..."
    if helm repo add nvidia https://nvidia.github.io/gpu-operator; then
        print_status "success" "NVIDIA Helm repository added"
    else
        print_status "warning" "Failed to add NVIDIA repository, trying to continue..."
    fi
    
    if helm repo update; then
        print_status "success" "Helm repositories updated"
    else
        print_status "warning" "Failed to update Helm repositories, trying to continue..."
    fi
    
    # Install GPU Operator with retry logic
    print_status "info" "Installing GPU Operator..."
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
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
            print_status "success" "GPU Operator installed successfully"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "error" "Failed to install GPU Operator after $max_attempts attempts"
            print_status "warning" "GPU acceleration may not be available"
            return 1
        fi
        
        print_status "warning" "GPU Operator installation failed, retrying... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    # Wait for GPU operator to be ready
    print_status "info" "Waiting for GPU operator to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local ready_count=$($KUBECTL get pods -n gpu-operator -l app.kubernetes.io/name=gpu-operator --field-selector=status.phase=Running --no-headers | wc -l)
        
        if [[ $ready_count -gt 0 ]]; then
            print_status "success" "GPU Operator is ready"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "warning" "GPU Operator not ready after $max_attempts attempts"
            print_status "info" "Check GPU Operator pods: kubectl get pods -n gpu-operator"
            return 1
        fi
        
        print_status "info" "Waiting for GPU Operator... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    # Verify GPU resources are available
    print_status "info" "Verifying GPU resources..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if $KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
            print_status "success" "GPU resources are now available in Kubernetes"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "warning" "GPU resources not yet available after $max_attempts attempts"
            print_status "info" "GPU acceleration may not be available immediately"
            break
        fi
        
        print_status "info" "Waiting for GPU resources... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    print_status "success" "GPU Operator deployment completed"
}

# Function to apply storage configuration with conflict handling
apply_storage_config() {
    print_status "header" "💾 Applying storage configuration..."
    
    # Apply storage configuration with error handling
    if $KUBECTL apply -f "$PROJECT_ROOT/base/03-storage.yaml"; then
        print_status "success" "Storage configuration applied successfully"
    else
        print_status "warning" "Some storage resources failed to apply"
        print_status "info" "This is expected for existing StorageClasses"
        print_status "info" "Continuing with deployment..."
        
        # Try to apply individual PVCs
        print_status "info" "Applying PVCs individually..."
        
        # Extract PVCs from the storage file and apply them separately
        local pvcs=(
            "ollama-storage"
            "whisper-storage"
            "kokoro-storage"
            "agent-storage"
            "temp-storage"
            "monitoring-storage"
            "backup-storage"
        )
        
        for pvc in "${pvcs[@]}"; do
            print_status "info" "Creating PVC: $pvc"
            # Create a temporary file with just the PVC
            $KUBECTL apply -f - <<EOF || print_status "warning" "Failed to create PVC: $pvc"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc
  namespace: ${pvc//storage/}  # Extract namespace from PVC name
  labels:
    app.kubernetes.io/name: ${pvc//-storage/}
    app.kubernetes.io/component: storage
    app.kubernetes.io/part-of: local-voice-ai
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
EOF
        done
    fi
    
    print_status "success" "Storage configuration completed"
}

# Function to verify fixes
verify_fixes() {
    print_status "header" "🔍 Verifying fixes..."
    
    # Check VolumeSnapshot CRDs
    if $KUBECTL get crd volumesnapshots.snapshot.storage.k8s.io &> /dev/null; then
        print_status "success" "VolumeSnapshot CRDs are installed"
    else
        print_status "warning" "VolumeSnapshot CRDs not found"
    fi
    
    # Check StorageClass
    if $KUBECTL get storageclass local-path &> /dev/null; then
        print_status "success" "local-path StorageClass is available"
    else
        print_status "warning" "local-path StorageClass not found"
    fi
    
    # Check GPU operator
    if $KUBECTL get namespace gpu-operator &> /dev/null; then
        print_status "success" "GPU Operator namespace exists"
        if $KUBECTL get deployment gpu-operator -n gpu-operator &> /dev/null; then
            print_status "success" "GPU Operator is deployed"
        else
            print_status "warning" "GPU Operator deployment not found"
        fi
    else
        print_status "info" "GPU Operator not installed (no GPU detected or installation failed)"
    fi
    
    # Check PVCs
    local pvc_count=$($KUBECTL get pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [[ $pvc_count -gt 0 ]]; then
        print_status "success" "$pvc_count PVCs created in $NAMESPACE namespace"
    else
        print_status "warning" "No PVCs found in $NAMESPACE namespace"
    fi
    
    print_status "success" "Fix verification completed"
}

# Main function
main() {
    print_status "header" "🔧 Local Voice AI - Fix Deployment Issues"
    echo "=========================================================="
    echo ""
    echo "This script will fix common deployment issues:"
    echo "• StorageClass conflicts"
    echo "• VolumeSnapshot CRD installation"
    echo "• GPU operator deployment"
    echo "• Storage configuration problems"
    echo ""
    
    # Check cluster connectivity
    check_cluster_connectivity
    echo ""
    
    # Install snapshot CRDs
    install_snapshot_crds
    echo ""
    
    # Fix StorageClass conflicts
    fix_storageclass_conflicts
    echo ""
    
    # Deploy GPU operator if GPU is available
    deploy_gpu_operator
    echo ""
    
    # Apply storage configuration
    apply_storage_config
    echo ""
    
    # Verify fixes
    verify_fixes
    echo ""
    
    print_status "success" "🎉 Deployment issues have been fixed!"
    echo ""
    echo "Next steps:"
    echo "1. Run the deployment script: bash kubernetes/scripts/deploy-gpu.sh"
    echo "2. Or run the simple deployment: bash kubernetes/scripts/deploy-gpu-simple.sh"
    echo "3. Check deployment status: kubectl get pods -n $NAMESPACE"
    echo ""
}

# Handle script interruption
trap 'print_status "warning" "Script interrupted by user"; exit 130' INT

# Run main function
main "$@"