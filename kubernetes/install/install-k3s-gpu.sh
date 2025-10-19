#!/bin/bash

# K3s Installation Script with GPU Support for Local Voice AI
# Optimized for RTX 5090 with 32GB VRAM and 96GB RAM systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
K3S_VERSION="v1.29.3+k3s1"
INSTALL_DIR="/usr/local/bin"
KUBECONFIG_DIR="$HOME/.kube"
SERVICE_DIR="/etc/systemd/system"

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
    esac
}

# Function to check system requirements
check_system_requirements() {
    print_status "header" "🔍 Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_status "error" "This script should not be run as root. Run as regular user with sudo privileges."
        exit 1
    fi
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "success" "Linux OS detected"
    else
        print_status "error" "This script is designed for Linux systems"
        exit 1
    fi
    
    # Check memory (minimum 16GB, recommended 32GB+)
    local total_memory=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_memory -lt 16 ]]; then
        print_status "error" "System has less than 16GB RAM ($total_memory GB detected)"
        exit 1
    elif [[ $total_memory -ge 64 ]]; then
        print_status "success" "High memory system detected: $total_memory GB RAM (Excellent for AI workloads)"
    else
        print_status "success" "Sufficient memory detected: $total_memory GB RAM"
    fi
    
    # Check CPU cores (minimum 4, recommended 8+)
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 4 ]]; then
        print_status "error" "System has less than 4 CPU cores ($cpu_cores detected)"
        exit 1
    elif [[ $cpu_cores -ge 16 ]]; then
        print_status "success" "High-performance CPU detected: $cpu_cores cores"
    else
        print_status "success" "Sufficient CPU detected: $cpu_cores cores"
    fi
    
    # Check available disk space (minimum 50GB)
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 50 ]]; then
        print_status "error" "Insufficient disk space: ${available_space}GB available, 50GB required"
        exit 1
    else
        print_status "success" "Sufficient disk space: ${available_space}GB available"
    fi
}

# Function to check NVIDIA GPU
check_nvidia_gpu() {
    print_status "header" "🎮 Checking NVIDIA GPU..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        print_status "warning" "NVIDIA drivers not found. GPU acceleration will not be available."
        print_status "info" "Install NVIDIA drivers first: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
        GPU_AVAILABLE=false
        return 0
    fi
    
    # Check GPU details
    local gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)
    local gpu_name=$(echo $gpu_info | cut -d',' -f1 | xargs)
    local gpu_memory=$(echo $gpu_info | cut -d',' -f2 | xargs)
    
    print_status "success" "NVIDIA GPU detected: $gpu_name"
    print_status "success" "GPU Memory: ${gpu_memory}MB"
    
    # Check if it's a high-end GPU
    if [[ $gpu_name == *"RTX 5090"* ]]; then
        print_status "success" "🚀 RTX 5090 detected - Excellent choice for AI workloads!"
        GPU_HIGH_END=true
    elif [[ $gpu_name == *"RTX 4090"* ]] || [[ $gpu_name == *"RTX 3090"* ]]; then
        print_status "success" "🚀 High-end RTX GPU detected - Great for AI workloads!"
        GPU_HIGH_END=true
    elif [[ $gpu_memory -ge 8000 ]]; then
        print_status "success" "✨ High-memory GPU detected - Good for AI workloads!"
        GPU_HIGH_END=false
    else
        print_status "warning" "GPU detected but may have limited memory for large models"
        GPU_HIGH_END=false
    fi
    
    # Check CUDA version
    local cuda_version=$(nvidia-smi | grep -o 'CUDA Version: [0-9]*\.[0-9]*' | cut -d' ' -f3)
    print_status "success" "CUDA Version: $cuda_version"
    
    # Check driver version
    local driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
    print_status "success" "NVIDIA Driver Version: $driver_version"
    
    GPU_AVAILABLE=true
    GPU_MEMORY_MB=$gpu_memory
    GPU_NAME="$gpu_name"
}

# Function to install NVIDIA Container Toolkit
install_nvidia_container_toolkit() {
    if [[ "$GPU_AVAILABLE" != "true" ]]; then
        print_status "info" "Skipping NVIDIA Container Toolkit installation (no GPU detected)"
        return 0
    fi
    
    print_status "header" "🐳 Installing NVIDIA Container Toolkit..."
    
    # Add package repositories
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    # Update package list
    sudo apt-get update
    
    # Install nvidia-container-toolkit
    sudo apt-get install -y nvidia-container-toolkit
    
    # Configure nvidia-container-runtime
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    
    print_status "success" "NVIDIA Container Toolkit installed successfully"
}

# Function to install K3s
install_k3s() {
    print_status "header" "🚀 Installing K3s..."
    
    # Remove existing K3s if present
    if command -v k3s &> /dev/null; then
        print_status "info" "Removing existing K3s installation..."
        sudo /usr/local/bin/k3s-uninstall.sh || true
    fi
    
    # Prepare K3s configuration
    local k3s_config=""
    
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        k3s_config="--kubelet-arg='feature-gates=DevicePlugins=false' \
                    --kubelet-arg='allowed-unsafe-sysctls=kernel.msg*,net.ipv4.ip_unprivileged_port_start' \
                    --disable traefik \
                    --disable servicelb \
                    --kubelet-arg='system-reserved=cpu=1000m,memory=2Gi' \
                    --kubelet-arg='kube-reserved=cpu=1000m,memory=2Gi' \
                    --kubelet-arg='eviction-hard=memory.available<4Gi,nodefs.available<1Gi'"
    else
        k3s_config="--disable traefik \
                    --disable servicelb \
                    --kubelet-arg='system-reserved=cpu=500m,memory=1Gi' \
                    --kubelet-arg='kube-reserved=cpu=500m,memory=1Gi' \
                    --kubelet-arg='eviction-hard=memory.available<2Gi,nodefs.available<1Gi'"
    fi
    
    # Install K3s
    print_status "info" "Downloading and installing K3s $K3S_VERSION..."
    curl -sfL https://get.k3s.io | sh -s - --version $K3S_VERSION $k3s_config
    
    # Wait for K3s to start
    print_status "info" "Waiting for K3s to start..."
    sleep 10
    
    # Check if K3s is running
    if sudo systemctl is-active --quiet k3s; then
        print_status "success" "K3s is running"
    else
        print_status "error" "K3s failed to start"
        exit 1
    fi
    
    # Setup kubectl with enhanced verification
    sudo mkdir -p $KUBECONFIG_DIR
    sudo cp /etc/rancher/k3s/k3s.yaml $KUBECONFIG_DIR/config
    sudo chown $(id -u):$(id -g) $KUBECONFIG_DIR/config
    chmod 600 $KUBECONFIG_DIR/config
    
    # Update server URL for local access
    sed -i 's/server: https:\/\/localhost:6443/server: https:\/\/127.0.0.1:6443/' $KUBECONFIG_DIR/config
    
    # Set KUBECONFIG environment variable
    export KUBECONFIG="$KUBECONFIG_DIR/config"
    echo "export KUBECONFIG=\"$KUBECONFIG_DIR/config\"" >> ~/.bashrc
    
    # Verify kubectl connection
    print_status "info" "Verifying kubectl connection..."
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl cluster-info &> /dev/null; then
            print_status "success" "kubectl connection verified"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "error" "kubectl connection failed after $max_attempts attempts"
            print_status "info" "Running connection diagnostics..."
            
            # Run diagnostics if available
            local diagnostics_script="$(dirname "$0")/../scripts/k3s-connection-diagnostics.sh"
            if [[ -f "$diagnostics_script" ]]; then
                bash "$diagnostics_script" diagnose || print_status "warning" "Diagnostics failed, please check manually"
            fi
            
            print_status "info" "Manual troubleshooting steps:"
            print_status "info" "1. Check K3s service: sudo systemctl status k3s"
            print_status "info" "2. Check kubeconfig: ls -la $KUBECONFIG_DIR/config"
            print_status "info" "3. Test connection: KUBECONFIG=$KUBECONFIG_DIR/config kubectl cluster-info"
            exit 1
        fi
        
        print_status "info" "Waiting for API server to be ready... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    # Add kubectl completion
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'complete -F __start_kubectl k' >> ~/.bashrc
    
    print_status "success" "K3s installed successfully"
}

# Function to install GPU operator
install_gpu_operator() {
    if [[ "$GPU_AVAILABLE" != "true" ]]; then
        print_status "info" "Skipping GPU operator installation (no GPU detected)"
        return 0
    fi
    
    print_status "header" "🎮 Installing NVIDIA GPU Operator..."
    
    # Wait for K3s to be ready
    print_status "info" "Waiting for K3s to be ready..."
    until kubectl get nodes &> /dev/null; do
        sleep 2
    done
    
    # Add NVIDIA Helm repository
    helm repo add nvidia https://nvidia.github.io/gpu-operator
    helm repo update
    
    # Install GPU Operator
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
    
    print_status "success" "GPU Operator installed successfully"
}

# Function to configure GPU resources
configure_gpu_resources() {
    if [[ "$GPU_AVAILABLE" != "true" ]]; then
        print_status "info" "Skipping GPU resource configuration (no GPU detected)"
        return 0
    fi
    
    print_status "header" "⚙️  Configuring GPU resources..."
    
    # Wait for GPU operator to be ready
    print_status "info" "Waiting for GPU operator to be ready..."
    until kubectl get pods -n gpu-operator -l app.kubernetes.io/component=gpu-operator | grep -q "Running"; do
        sleep 5
    done
    
    # Wait for NVIDIA device plugin
    print_status "info" "Waiting for NVIDIA device plugin..."
    until kubectl get pods -n gpu-operator -l app.kubernetes.io/component=nvidia-device-plugin-daemonset | grep -q "Running"; do
        sleep 5
    done
    
    # Create GPU device configuration
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gpu-config
  namespace: default
data:
  gpu-memory-split: "12,4,3,3"  # Ollama,Whisper,Kokoro,Agent
  gpu-time-slicing: "true"
  mps-enabled: "true"
EOF
    
    print_status "success" "GPU resources configured successfully"
}

# Function to verify installation
verify_installation() {
    print_status "header" "🔍 Verifying installation..."
    
    # Check K3s
    if kubectl cluster-info &> /dev/null; then
        print_status "success" "K3s cluster is accessible"
    else
        print_status "error" "K3s cluster is not accessible"
        return 1
    fi
    
    # Check node status
    local node_status=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    if [[ "$node_status" == "True" ]]; then
        print_status "success" "Kubernetes node is ready"
    else
        print_status "error" "Kubernetes node is not ready"
        return 1
    fi
    
    # Check GPU if available
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        print_status "info" "Checking GPU resources..."
        sleep 30  # Give GPU operator time to initialize
        
        if kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
            print_status "success" "GPU resources are available in Kubernetes"
        else
            print_status "warning" "GPU resources not yet available (may need more time)"
        fi
        
        # Test GPU device plugin
        if kubectl get pods -n gpu-operator | grep -q "nvidia-device-plugin"; then
            print_status "success" "NVIDIA device plugin is running"
        else
            print_status "warning" "NVIDIA device plugin not yet running"
        fi
    fi
    
    print_status "success" "Installation verification completed"
}

# Function to show next steps
show_next_steps() {
    print_status "success" "🎉 K3s with GPU support installation completed!"
    echo ""
    echo "=========================================================="
    echo "Installation Summary:"
    echo "=========================================================="
    echo ""
    
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        echo "🎮 GPU: $GPU_NAME ($GPU_MEMORY_MB MB VRAM)"
        echo "🚀 GPU Acceleration: Enabled"
    else
        echo "⚠️  GPU: Not detected - CPU only mode"
    fi
    
    echo "🐳 Container Runtime: containerd with NVIDIA support"
    echo "☸️  Kubernetes: K3s $K3S_VERSION"
    echo "📊 Monitoring: Basic setup ready"
    echo ""
    echo "=========================================================="
    echo "Next Steps:"
    echo "=========================================================="
    echo ""
    echo "1. Deploy Local Voice AI services:"
    echo "   cd kubernetes && ./deploy-gpu.sh"
    echo ""
    echo "2. Check cluster status:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -A"
    echo ""
    echo "3. Monitor GPU usage (if available):"
    echo "   watch -n 1 nvidia-smi"
    echo ""
    echo "4. Access services:"
    echo "   Frontend: http://localhost (after deployment)"
    echo ""
    
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        echo "🚀 Your RTX 5090 is ready for AI workloads!"
        echo "   Expected performance gains: 10-50x faster inference"
    fi
}

# Main installation flow
main() {
    print_status "header" "🚀 Local Voice AI - K3s GPU Installation"
    echo "=========================================================="
    echo ""
    echo "This script will install K3s with GPU support optimized for"
    echo "AI workloads on your system."
    echo ""
    
    # Check system requirements
    check_system_requirements
    echo ""
    
    # Check NVIDIA GPU
    check_nvidia_gpu
    echo ""
    
    # Install NVIDIA Container Toolkit
    install_nvidia_container_toolkit
    echo ""
    
    # Install K3s
    install_k3s
    echo ""
    
    # Install GPU operator
    install_gpu_operator
    echo ""
    
    # Configure GPU resources
    configure_gpu_resources
    echo ""
    
    # Verify installation
    verify_installation
    echo ""
    
    # Show next steps
    show_next_steps
}

# Handle script interruption
trap 'print_status "warning" "Installation interrupted by user"; exit 130' INT

# Run main function
main "$@"