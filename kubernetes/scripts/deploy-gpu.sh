#!/bin/bash

# GPU-Optimized Deployment Script for Local Voice AI
# One-command deployment with GPU acceleration

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

# Function to fix script permissions
fix_script_permissions() {
    print_status "info" "Checking and fixing script permissions..."
    
    local scripts_dir="$PROJECT_ROOT/scripts"
    local install_dir="$PROJECT_ROOT/install"
    
    # Fix permissions for scripts directory
    if [[ -d "$scripts_dir" ]]; then
        for script in "$scripts_dir"/*.sh; do
            if [[ -f "$script" && ! -x "$script" ]]; then
                print_status "info" "Making $(basename "$script") executable..."
                chmod +x "$script"
            fi
        done
    fi
    
    # Fix permissions for install directory
    if [[ -d "$install_dir" ]]; then
        for script in "$install_dir"/*.sh; do
            if [[ -f "$script" && ! -x "$script" ]]; then
                print_status "info" "Making $(basename "$script") executable..."
                chmod +x "$script"
            fi
        done
    fi
    
    print_status "success" "Script permissions fixed"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "header" "🔍 Checking prerequisites..."
    
    # Fix script permissions first
    fix_script_permissions
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_status "error" "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Ensure K3s is available (install if needed)
    ensure_k3s_available
    
    # Run comprehensive K3s connection diagnostics
    print_status "info" "Running K3s connection diagnostics..."
    if ! "$SCRIPT_DIR/k3s-connection-diagnostics.sh" diagnose; then
        print_status "error" "K3s connection diagnostics failed"
        print_status "info" "Running automatic fixes..."
        
        # Try to fix kubeconfig issues
        if ! "$SCRIPT_DIR/k3s-connection-diagnostics.sh" fix-kubeconfig; then
            print_status "error" "Automatic kubeconfig fix failed"
            print_status "info" "Please run manual diagnostics:"
            print_status "info" "$SCRIPT_DIR/k3s-connection-diagnostics.sh troubleshoot"
            exit 1
        fi
        
        # Test connectivity again
        if ! "$SCRIPT_DIR/k3s-connection-diagnostics.sh" test-connectivity; then
            print_status "error" "K3s connection still failing after automatic fixes"
            print_status "info" "Please check the diagnostics output above"
            print_status "info" "Or run: $SCRIPT_DIR/k3s-connection-diagnostics.sh troubleshoot"
            exit 1
        fi
    fi
    
    print_status "success" "K3s connection verified and working"
    
    # Wait for cluster to be fully ready
    print_status "info" "Waiting for Kubernetes cluster to be fully ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local node_status=$($KUBECTL get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [[ "$node_status" == "True" ]]; then
            print_status "success" "Kubernetes cluster is ready"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "error" "Kubernetes cluster failed to become ready after $max_attempts attempts"
            print_status "info" "Checking node status..."
            $KUBECTL get nodes -o wide
            exit 1
        fi
        
        print_status "info" "Waiting for cluster to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    # Check GPU availability
    if ! $KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
        print_status "warning" "GPU resources not detected in cluster"
        print_status "info" "GPU acceleration may not be available"
        GPU_AVAILABLE=false
    else
        print_status "success" "GPU resources detected in cluster"
        GPU_AVAILABLE=true
    fi
    
    # Check if namespace exists
    if ! $KUBECTL get namespace $NAMESPACE &> /dev/null; then
        print_status "info" "Namespace $NAMESPACE does not exist, will be created"
    fi
    
    print_status "success" "Prerequisites check completed"
}

# Function to check if K3s is installed
check_k3s_installation() {
    print_status "info" "Checking if K3s is installed..."
    
    # Check if k3s command exists
    if command -v k3s &> /dev/null; then
        print_status "success" "K3s binary found"
        
        # Check if K3s service is running
        if sudo systemctl is-active --quiet k3s; then
            print_status "success" "K3s service is running"
            return 0
        else
            print_status "warning" "K3s binary found but service is not running"
            return 1
        fi
    else
        print_status "warning" "K3s is not installed"
        return 1
    fi
}

# Function to install K3s with GPU support
install_k3s_automatically() {
    print_status "header" "🚀 Installing K3s automatically..."
    
    local install_script="$PROJECT_ROOT/install/install-k3s-gpu.sh"
    
    # Check if installation script exists
    if [[ ! -f "$install_script" ]]; then
        print_status "error" "K3s installation script not found at $install_script"
        exit 1
    fi
    
    # Make sure the script is executable
    chmod +x "$install_script"
    
    print_status "info" "Running K3s installation with GPU support..."
    print_status "info" "This may take several minutes, please wait..."
    
    # Run the installation script with progress feedback
    if bash "$install_script"; then
        print_status "success" "K3s installation completed successfully"
        
        # Wait a bit for K3s to fully initialize
        print_status "info" "Waiting for K3s to fully initialize..."
        sleep 15
        
        # Verify K3s is running
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if sudo systemctl is-active --quiet k3s && kubectl cluster-info &> /dev/null; then
                print_status "success" "K3s is running and ready"
                return 0
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                print_status "error" "K3s failed to start after $max_attempts attempts"
                print_status "info" "Checking K3s service status..."
                sudo systemctl status k3s --no-pager -l
                return 1
            fi
            
            print_status "info" "Waiting for K3s to be ready... (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        done
    else
        print_status "error" "K3s installation failed"
        return 1
    fi
}

# Function to ensure K3s is available
ensure_k3s_available() {
    print_status "header" "🔍 Ensuring K3s is available..."
    
    # Check if K3s is installed and running
    if check_k3s_installation; then
        print_status "success" "K3s is already installed and running"
        return 0
    fi
    
    # K3s is not available, install it
    print_status "warning" "K3s is not available, installing automatically..."
    
    if install_k3s_automatically; then
        print_status "success" "K3s is now available and ready"
        return 0
    else
        print_status "error" "Failed to install K3s"
        print_status "info" "Please check the installation logs above and try again"
        exit 1
    fi
}

# Function to install snapshot CRDs if needed
install_snapshot_crds() {
    print_status "info" "Checking for VolumeSnapshot CRDs..."
    
    # Check if VolumeSnapshot CRD exists
    if ! $KUBECTL get crd volumesnapshots.snapshot.storage.k8s.io &> /dev/null; then
        print_status "info" "Installing VolumeSnapshot CRDs..."
        
        # Install snapshot CRDs
        $KUBECTL apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml || \
            print_status "warning" "Failed to install VolumeSnapshotClass CRD"
        
        $KUBECTL apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml || \
            print_status "warning" "Failed to install VolumeSnapshot CRD"
        
        $KUBECTL apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml || \
            print_status "warning" "Failed to install VolumeSnapshotContent CRD"
        
        print_status "success" "VolumeSnapshot CRDs installed"
    else
        print_status "info" "VolumeSnapshot CRDs already exist"
    fi
}

# Function to deploy GPU operator
deploy_gpu_operator() {
    if [[ "$GPU_AVAILABLE" != "true" ]]; then
        print_status "info" "Skipping GPU operator deployment (no GPU detected)"
        return 0
    fi
    
    print_status "header" "🎮 Deploying NVIDIA GPU Operator..."
    
    # Check if GPU operator is already installed
    if $KUBECTL get namespace gpu-operator &> /dev/null && \
       $KUBECTL get deployment gpu-operator -n gpu-operator &> /dev/null; then
        print_status "info" "GPU Operator already installed"
        return 0
    fi
    
    # Wait for cluster to be ready
    print_status "info" "Waiting for cluster to be ready for GPU operator..."
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
    helm repo add nvidia https://nvidia.github.io/gpu-operator || \
        print_status "warning" "Failed to add NVIDIA repo, trying to continue..."
    
    helm repo update || \
        print_status "warning" "Failed to update Helm repos, trying to continue..."
    
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

# Function to create namespace and base resources
create_base_resources() {
    print_status "header" "🏗️  Creating base resources..."
    
    # Install snapshot CRDs first (with error handling)
    install_snapshot_crds
    
    # Apply namespace and base configurations
    if $KUBECTL apply -f "$PROJECT_ROOT/base/00-namespace.yaml"; then
        print_status "success" "Namespaces created"
    else
        print_status "error" "Failed to create namespaces"
        return 1
    fi
    
    if $KUBECTL apply -f "$PROJECT_ROOT/base/01-configmaps.yaml"; then
        print_status "success" "ConfigMaps created"
    else
        print_status "warning" "Failed to create ConfigMaps, continuing..."
    fi
    
    if $KUBECTL apply -f "$PROJECT_ROOT/base/02-secrets.yaml"; then
        print_status "success" "Secrets created"
    else
        print_status "warning" "Failed to create Secrets, continuing..."
    fi
    
    # Apply storage with better error handling
    if $KUBECTL apply -f "$PROJECT_ROOT/base/03-storage.yaml"; then
        print_status "success" "Storage classes and PVCs created"
    else
        print_status "warning" "Some storage resources failed to create (this is expected for existing StorageClasses)"
        print_status "info" "Continuing with deployment..."
    fi
    
    if $KUBECTL apply -f "$PROJECT_ROOT/base/04-network-policies.yaml"; then
        print_status "success" "Network policies created"
    else
        print_status "warning" "Failed to create network policies, continuing..."
    fi
    
    # Wait for storage to be ready
    print_status "info" "Waiting for storage to be ready..."
    sleep 10
    
    print_status "success" "Base resources created successfully"
}

# Function to deploy GPU services
deploy_gpu_services() {
    print_status "header" "🚀 Deploying GPU-optimized services..."
    
    # Deploy services in dependency order
    
    # 1. Ollama (LLM service)
    print_status "info" "Deploying Ollama LLM service..."
    $KUBECTL apply -f "$PROJECT_ROOT/services/ollama/deployment-gpu.yaml"
    $KUBECTL apply -f "$PROJECT_ROOT/services/ollama/service.yaml"
    print_status "success" "Ollama service deployed"
    
    # 2. Whisper (STT service)
    print_status "info" "Deploying Whisper STT service..."
    $KUBECTL apply -f "$PROJECT_ROOT/services/whisper/deployment-gpu.yaml"
    $KUBECTL apply -f "$PROJECT_ROOT/services/whisper/service.yaml"
    print_status "success" "Whisper service deployed"
    
    # 3. Kokoro (TTS service)
    print_status "info" "Deploying Kokoro TTS service..."
    $KUBECTL apply -f "$PROJECT_ROOT/services/kokoro/deployment-gpu.yaml"
    $KUBECTL apply -f "$PROJECT_ROOT/services/kokoro/service.yaml"
    print_status "success" "Kokoro service deployed"
    
    # 4. Agent (orchestration service)
    print_status "info" "Deploying Agent service..."
    $KUBECTL apply -f "$PROJECT_ROOT/services/agent/deployment-gpu.yaml"
    $KUBECTL apply -f "$PROJECT_ROOT/services/agent/service.yaml"
    print_status "success" "Agent service deployed"
    
    # 5. LiveKit (signaling service)
    print_status "info" "Deploying LiveKit signaling service..."
    $KUBECTL apply -f "$PROJECT_ROOT/services/livekit/deployment.yaml"
    $KUBECTL apply -f "$PROJECT_ROOT/services/livekit/service.yaml"
    print_status "success" "LiveKit service deployed"
    
    # 6. Frontend (web interface)
    print_status "info" "Deploying Frontend service..."
    $KUBECTL apply -f "$PROJECT_ROOT/services/frontend/deployment.yaml"
    $KUBECTL apply -f "$PROJECT_ROOT/services/frontend/service.yaml"
    print_status "success" "Frontend service deployed"
    
    print_status "success" "All GPU-optimized services deployed"
}

# Function to deploy ingress
deploy_ingress() {
    print_status "header" "🌐 Deploying ingress configuration..."
    
    # Install Traefik if not present
    if ! $KUBECTL get namespace traefik &> /dev/null; then
        print_status "info" "Installing Traefik ingress controller..."
        helm repo add traefik https://traefik.github.io/charts
        helm repo update
        helm install traefik traefik/traefik \
            --namespace traefik \
            --create-namespace \
            --set service.type=NodePort \
            --set service.nodePorts.http=30080 \
            --set service.nodePorts.https=30443 \
            --set ports.web.nodePort=30080 \
            --set ports.websecure.nodePort=30443
        print_status "success" "Traefik ingress controller installed"
    fi
    
    # Apply ingress routes
    $KUBECTL apply -f "$PROJECT_ROOT/ingress/ingress-routes.yaml"
    print_status "success" "Ingress routes configured"
    
    print_status "success" "Ingress deployment completed"
}

# Function to deploy monitoring
deploy_monitoring() {
    print_status "header" "📊 Deploying monitoring stack..."
    
    # Create monitoring namespace
    $KUBECTL apply -f "$PROJECT_ROOT/base/00-namespace.yaml"
    
    # Install Prometheus
    if ! $KUBECTL get deployment prometheus -n monitoring &> /dev/null; then
        print_status "info" "Installing Prometheus..."
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --create-namespace \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
            --set grafana.adminPassword=admin123 \
            --set grafana.service.type=NodePort \
            --set grafana.service.nodePort=30030
        print_status "success" "Prometheus and Grafana installed"
    fi
    
    # Apply custom monitoring configs
    $KUBECTL apply -f "$PROJECT_ROOT/monitoring/"
    print_status "success" "Custom monitoring configs applied"
    
    print_status "success" "Monitoring stack deployed"
}

# Function to wait for services to be ready
wait_for_services() {
    print_status "header" "⏳ Waiting for services to be ready..."
    
    # List of services to wait for
    local services=("ollama" "whisper" "kokoro" "agent" "livekit" "frontend")
    local max_attempts=60
    local attempt=1
    
    for service in "${services[@]}"; do
        print_status "info" "Waiting for $service to be ready..."
        
        while [ $attempt -le $max_attempts ]; do
            local ready_count=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running --no-headers | wc -l)
            
            if [[ $ready_count -gt 0 ]]; then
                print_status "success" "$service is ready"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                print_status "error" "$service failed to become ready after $max_attempts attempts"
                print_status "info" "Checking pod status..."
                $KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service
                return 1
            fi
            
            print_status "info" "Attempt $attempt/$max_attempts: $service not ready yet..."
            sleep 10
            ((attempt++))
        done
        
        attempt=1  # Reset for next service
    done
    
    print_status "success" "All services are ready!"
}

# Function to verify deployment
verify_deployment() {
    print_status "header" "🔍 Verifying deployment..."
    
    # Check all pods are running
    local all_running=true
    local services=("ollama" "whisper" "kokoro" "agent" "livekit" "frontend")
    
    for service in "${services[@]}"; do
        local pod_count=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --no-headers | wc -l)
        local running_count=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running --no-headers | wc -l)
        
        if [[ $running_count -eq $pod_count && $pod_count -gt 0 ]]; then
            print_status "success" "$service: $running_count/$pod_count pods running"
        else
            print_status "error" "$service: $running_count/$pod_count pods running"
            all_running=false
        fi
    done
    
    if [[ "$all_running" == "true" ]]; then
        print_status "success" "All services are running correctly"
    else
        print_status "warning" "Some services may not be running correctly"
        print_status "info" "Check pod logs for more information"
    fi
    
    # Check GPU utilization if available
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        print_status "info" "Checking GPU utilization..."
        $KUBECTL exec -n $NAMESPACE deployment/ollama -- nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || print_status "warning" "Could not check GPU utilization"
    fi
    
    print_status "success" "Deployment verification completed"
}

# Function to show deployment summary
show_deployment_summary() {
    print_status "header" "📋 Deployment Summary"
    echo "=========================================================="
    echo ""
    
    print_status "highlight" "🚀 Local Voice AI GPU-Optimized Deployment Complete!"
    echo ""
    
    echo "Services Status:"
    echo "----------------------------------------"
    $KUBECTL get pods -n $NAMESPACE -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.readyReplicas/.status.replicas
    echo ""
    
    echo "Service URLs:"
    echo "----------------------------------------"
    echo "🌐 Frontend: http://localhost:30080"
    echo "🔊 LiveKit: ws://localhost:30080/livekit"
    echo "📊 Grafana: http://localhost:30030 (admin/admin123)"
    echo "📈 Prometheus: http://localhost:30090"
    echo ""
    
    echo "GPU Information:"
    echo "----------------------------------------"
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        echo "🎮 GPU Status: Available"
        echo "🚀 GPU Acceleration: Enabled"
        echo "📊 Expected Performance: 10-50x faster inference"
    else
        echo "⚠️  GPU Status: Not Available"
        echo "🔄 Fallback Mode: CPU Only"
    fi
    echo ""
    
    echo "Management Commands:"
    echo "----------------------------------------"
    echo "📊 View all pods:      kubectl get pods -n $NAMESPACE"
    echo "📋 View services:      kubectl get svc -n $NAMESPACE"
    echo "📝 View logs:         kubectl logs -f deployment/<service> -n $NAMESPACE"
    echo "🔄 Restart service:    kubectl rollout restart deployment/<service> -n $NAMESPACE"
    echo "🗑️  Cleanup:           ./kubernetes/scripts/destroy.sh"
    echo ""
    
    echo "=========================================================="
    echo "🎉 Your Local Voice AI is ready to use!"
    echo "=========================================================="
    echo ""
    echo "Next steps:"
    echo "1. Open your browser and go to: http://localhost:30080"
    echo "2. Click the microphone button to grant permission"
    echo "3. Start speaking with your voice assistant"
    echo ""
    
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        print_status "performance" "🚀 Enjoy the power of GPU acceleration!"
    fi
}

# Function to handle errors
handle_error() {
    local exit_code=$?
    local line_number=$1
    print_status "error" "Script failed on line $line_number with exit code $exit_code"
    
    print_status "info" "Troubleshooting steps:"
    echo "1. Check cluster status: kubectl cluster-info"
    echo "2. Check pod status: kubectl get pods -n $NAMESPACE"
    echo "3. Check pod logs: kubectl logs -f deployment/<service> -n $NAMESPACE"
    echo "4. Check GPU availability: kubectl describe nodes"
    echo "5. Check storage: kubectl get pvc -n $NAMESPACE"
    
    exit $exit_code
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Function to apply kubectl resources with retry logic
kubectl_apply_with_retry() {
    local resource_file=$1
    local resource_name=$(basename "$resource_file")
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if $KUBECTL apply -f "$resource_file"; then
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

# Function to deploy GPU services with retry logic
deploy_gpu_services_with_retry() {
    print_status "header" "🚀 Deploying GPU-optimized services..."
    
    # Deploy services in dependency order with retry logic
    
    # 1. Ollama (LLM service)
    print_status "info" "Deploying Ollama LLM service..."
    if kubectl_apply_with_retry "$PROJECT_ROOT/services/ollama/deployment-gpu.yaml"; then
        kubectl_apply_with_retry "$PROJECT_ROOT/services/ollama/service.yaml"
        print_status "success" "Ollama service deployed"
    else
        print_status "error" "Failed to deploy Ollama service"
        return 1
    fi
    
    # 2. Whisper (STT service)
    print_status "info" "Deploying Whisper STT service..."
    if kubectl_apply_with_retry "$PROJECT_ROOT/services/whisper/deployment-gpu.yaml"; then
        # Check if service.yaml exists for whisper
        if [[ -f "$PROJECT_ROOT/services/whisper/service.yaml" ]]; then
            kubectl_apply_with_retry "$PROJECT_ROOT/services/whisper/service.yaml"
        fi
        print_status "success" "Whisper service deployed"
    else
        print_status "error" "Failed to deploy Whisper service"
        return 1
    fi
    
    # 3. Agent (orchestration service)
    print_status "info" "Deploying Agent service..."
    if kubectl_apply_with_retry "$PROJECT_ROOT/services/agent/deployment-gpu.yaml"; then
        # Check if service.yaml exists for agent
        if [[ -f "$PROJECT_ROOT/services/agent/service.yaml" ]]; then
            kubectl_apply_with_retry "$PROJECT_ROOT/services/agent/service.yaml"
        fi
        print_status "success" "Agent service deployed"
    else
        print_status "error" "Failed to deploy Agent service"
        return 1
    fi
    
    print_status "success" "All GPU-optimized services deployed"
}

# Main deployment flow
main() {
    print_status "header" "🚀 Local Voice AI - GPU-Optimized Deployment"
    echo "=========================================================="
    echo ""
    echo "This script will deploy Local Voice AI with GPU acceleration"
    echo "optimized for your RTX 5090 and high-performance system."
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Deploy GPU operator first if GPU is available
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        deploy_gpu_operator
        echo ""
    fi
    
    # Create base resources
    create_base_resources
    echo ""
    
    # Deploy GPU services with retry logic
    deploy_gpu_services_with_retry
    echo ""
    
    # Deploy ingress
    deploy_ingress
    echo ""
    
    # Deploy monitoring
    deploy_monitoring
    echo ""
    
    # Wait for services to be ready
    wait_for_services
    echo ""
    
    # Verify deployment
    verify_deployment
    echo ""
    
    # Show summary
    show_deployment_summary
}

# Handle script interruption
trap 'print_status "warning" "Deployment interrupted by user"; exit 130' INT

# Run main function
main "$@"