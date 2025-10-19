#!/bin/bash

# Hardware Detection Script for Local Voice AI
# Detects GPU, CPU, memory, and recommends optimal deployment profile

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
GPU_AVAILABLE=false
GPU_NAME=""
GPU_MEMORY_MB=0
GPU_HIGH_END=false
CPU_CORES=0
MEMORY_GB=0
DEPLOYMENT_PROFILE="cpu"
PERFORMANCE_TIER="basic"

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

# Function to detect NVIDIA GPU
detect_gpu() {
    print_status "header" "🎮 Detecting GPU Hardware..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        print_status "warning" "NVIDIA drivers not found"
        print_status "info" "GPU acceleration will not be available"
        print_status "info" "Install NVIDIA drivers: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
        return 0
    fi
    
    # Get GPU information
    local gpu_info=$(nvidia-smi --query-gpu=name,memory.total,driver_version,cuda_version --format=csv,noheader,nounits | head -1)
    GPU_NAME=$(echo $gpu_info | cut -d',' -f1 | xargs)
    GPU_MEMORY_MB=$(echo $gpu_info | cut -d',' -f2 | xargs)
    local driver_version=$(echo $gpu_info | cut -d',' -f3 | xargs)
    local cuda_version=$(echo $gpu_info | cut -d',' -f4 | xargs)
    
    GPU_AVAILABLE=true
    
    print_status "success" "NVIDIA GPU detected: $GPU_NAME"
    print_status "success" "GPU Memory: ${GPU_MEMORY_MB}MB"
    print_status "success" "Driver Version: $driver_version"
    print_status "success" "CUDA Version: $cuda_version"
    
    # Classify GPU performance
    if [[ $GPU_NAME == *"RTX 5090"* ]]; then
        print_status "highlight" "🚀 RTX 5090 detected - Ultimate AI performance!"
        GPU_HIGH_END=true
        PERFORMANCE_TIER="ultimate"
    elif [[ $GPU_NAME == *"RTX 4090"* ]]; then
        print_status "highlight" "🚀 RTX 4090 detected - Exceptional AI performance!"
        GPU_HIGH_END=true
        PERFORMANCE_TIER="exceptional"
    elif [[ $GPU_NAME == *"RTX 3090"* ]] || [[ $GPU_NAME == *"RTX 4080"* ]]; then
        print_status "highlight" "🚀 High-end RTX GPU detected - Excellent AI performance!"
        GPU_HIGH_END=true
        PERFORMANCE_TIER="excellent"
    elif [[ $GPU_NAME == *"RTX 4070"* ]] || [[ $GPU_NAME == *"RTX 3080"* ]] || [[ $GPU_NAME == *"RTX A5000"* ]]; then
        print_status "success" "✨ Performance RTX GPU detected - Great AI performance!"
        GPU_HIGH_END=false
        PERFORMANCE_TIER="great"
    elif [[ $GPU_MEMORY_MB -ge 8000 ]]; then
        print_status "success" "✨ High-memory GPU detected - Good AI performance!"
        GPU_HIGH_END=false
        PERFORMANCE_TIER="good"
    elif [[ $GPU_MEMORY_MB -ge 4000 ]]; then
        print_status "info" "📊 Mid-range GPU detected - Moderate AI performance"
        GPU_HIGH_END=false
        PERFORMANCE_TIER="moderate"
    else
        print_status "warning" "⚠️  Low-memory GPU detected - Limited AI performance"
        GPU_HIGH_END=false
        PERFORMANCE_TIER="limited"
    fi
    
    # Check GPU temperature and utilization
    local gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1)
    local gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
    
    print_status "info" "Current GPU Temperature: ${gpu_temp}°C"
    print_status "info" "Current GPU Utilization: ${gpu_util}%"
}

# Function to detect CPU
detect_cpu() {
    print_status "header" "🖥️  Detecting CPU Hardware..."
    
    # Get CPU information
    CPU_CORES=$(nproc)
    local cpu_model=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
    local cpu_freq=$(lscpu | grep "CPU max MHz" | awk '{print $4}' | cut -d'.' -f1)
    
    print_status "success" "CPU: $cpu_model"
    print_status "success" "CPU Cores: $CPU_CORES"
    print_status "success" "Max Frequency: ${cpu_freq}MHz"
    
    # Classify CPU performance
    if [[ $CPU_CORES -ge 32 ]]; then
        print_status "highlight" "🚀 High-core-count CPU detected - Excellent for parallel workloads!"
    elif [[ $CPU_CORES -ge 16 ]]; then
        print_status "success" "✨ High-performance CPU detected - Great for AI workloads!"
    elif [[ $CPU_CORES -ge 8 ]]; then
        print_status "success" "✨ Good CPU detected - Suitable for AI workloads!"
    elif [[ $CPU_CORES -ge 4 ]]; then
        print_status "info" "📊 Adequate CPU detected - Minimum for AI workloads"
    else
        print_status "warning" "⚠️  Low-core-count CPU detected - May struggle with AI workloads"
    fi
}

# Function to detect memory
detect_memory() {
    print_status "header" "💾 Detecting Memory Configuration..."
    
    # Get memory information
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    local available_gb=$(free -g | awk '/^Mem:/{print $7}')
    local swap_gb=$(free -g | awk '/^Swap:/{print $2}')
    
    print_status "success" "Total Memory: ${MEMORY_GB}GB"
    print_status "success" "Available Memory: ${available_gb}GB"
    print_status "info" "Swap Memory: ${swap_gb}GB"
    
    # Classify memory performance
    if [[ $MEMORY_GB -ge 128 ]]; then
        print_status "highlight" "🚀 Massive memory detected - Ultimate AI workstation!"
    elif [[ $MEMORY_GB -ge 64 ]]; then
        print_status "highlight" "🚀 High memory detected - Excellent AI workstation!"
    elif [[ $MEMORY_GB -ge 32 ]]; then
        print_status "success" "✨ Good memory detected - Great for AI workloads!"
    elif [[ $MEMORY_GB -ge 16 ]]; then
        print_status "success" "✨ Adequate memory detected - Suitable for AI workloads!"
    else
        print_status "warning" "⚠️  Low memory detected - May limit AI model sizes"
    fi
}

# Function to detect storage
detect_storage() {
    print_status "header" "💽 Detecting Storage Configuration..."
    
    # Get storage information
    local root_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    local home_space=$(df -BG $HOME 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    
    print_status "success" "Root Available Space: ${root_space}GB"
    if [[ $home_space ]]; then
        print_status "success" "Home Available Space: ${home_space}GB"
    fi
    
    # Check storage requirements
    if [[ $root_space -lt 20 ]]; then
        print_status "warning" "⚠️  Low disk space - Recommend at least 50GB for AI models"
    elif [[ $root_space -ge 100 ]]; then
        print_status "success" "✨ Excellent storage space for AI models!"
    else
        print_status "info" "📊 Sufficient storage space for AI workloads"
    fi
}

# Function to analyze system performance
analyze_performance() {
    print_status "header" "📊 Analyzing System Performance..."
    
    local performance_score=0
    local max_score=100
    
    # GPU scoring (40 points)
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        if [[ "$GPU_HIGH_END" == "true" ]]; then
            performance_score=$((performance_score + 40))
            print_status "performance" "GPU Score: 40/40 (High-end GPU)"
        elif [[ $GPU_MEMORY_MB -ge 8000 ]]; then
            performance_score=$((performance_score + 30))
            print_status "performance" "GPU Score: 30/40 (Good GPU)"
        elif [[ $GPU_MEMORY_MB -ge 4000 ]]; then
            performance_score=$((performance_score + 20))
            print_status "performance" "GPU Score: 20/40 (Mid-range GPU)"
        else
            performance_score=$((performance_score + 10))
            print_status "performance" "GPU Score: 10/40 (Low-end GPU)"
        fi
    else
        print_status "info" "GPU Score: 0/40 (No GPU)"
    fi
    
    # CPU scoring (30 points)
    if [[ $CPU_CORES -ge 16 ]]; then
        performance_score=$((performance_score + 30))
        print_status "performance" "CPU Score: 30/30 (High-performance CPU)"
    elif [[ $CPU_CORES -ge 8 ]]; then
        performance_score=$((performance_score + 20))
        print_status "performance" "CPU Score: 20/30 (Good CPU)"
    elif [[ $CPU_CORES -ge 4 ]]; then
        performance_score=$((performance_score + 10))
        print_status "performance" "CPU Score: 10/30 (Adequate CPU)"
    else
        print_status "performance" "CPU Score: 5/30 (Low-end CPU)"
    fi
    
    # Memory scoring (30 points)
    if [[ $MEMORY_GB -ge 64 ]]; then
        performance_score=$((performance_score + 30))
        print_status "performance" "Memory Score: 30/30 (High memory)"
    elif [[ $MEMORY_GB -ge 32 ]]; then
        performance_score=$((performance_score + 20))
        print_status "performance" "Memory Score: 20/30 (Good memory)"
    elif [[ $MEMORY_GB -ge 16 ]]; then
        performance_score=$((performance_score + 10))
        print_status "performance" "Memory Score: 10/30 (Adequate memory)"
    else
        print_status "performance" "Memory Score: 5/30 (Low memory)"
    fi
    
    # Overall performance rating
    local performance_percentage=$((performance_score * 100 / max_score))
    
    echo ""
    print_status "header" "🏆 Overall System Performance: $performance_score/100 ($performance_percentage%)"
    
    if [[ $performance_percentage -ge 90 ]]; then
        print_status "highlight" "🌟 Ultimate AI Workstation - Maximum performance!"
    elif [[ $performance_percentage -ge 75 ]]; then
        print_status "highlight" "🚀 Exceptional AI Workstation - Excellent performance!"
    elif [[ $performance_percentage -ge 60 ]]; then
        print_status "success" "✨ Great AI Setup - Good performance!"
    elif [[ $performance_percentage -ge 40 ]]; then
        print_status "success" "✨ Good AI Setup - Moderate performance!"
    else
        print_status "warning" "⚠️  Basic AI Setup - Limited performance"
    fi
}

# Function to recommend deployment profile
recommend_deployment() {
    print_status "header" "🎯 Recommending Deployment Profile..."
    
    # Determine deployment profile based on hardware
    if [[ "$GPU_AVAILABLE" == "true" && "$GPU_HIGH_END" == "true" && $MEMORY_GB -ge 64 && $CPU_CORES -ge 16 ]]; then
        DEPLOYMENT_PROFILE="gpu-optimized"
        print_status "highlight" "🚀 Recommended: GPU-Optimized Profile"
        print_status "info" "• All services with GPU acceleration"
        print_status "info" "• Maximum resource allocation"
        print_status "info" "• High-performance models (gemma3:7b, llama3:8b)"
        print_status "info" "• Expected: 10-50x faster inference"
    elif [[ "$GPU_AVAILABLE" == "true" && $MEMORY_GB -ge 32 && $CPU_CORES -ge 8 ]]; then
        DEPLOYMENT_PROFILE="gpu-balanced"
        print_status "success" "✨ Recommended: GPU-Balanced Profile"
        print_status "info" "• GPU acceleration for core services"
        print_status "info" "• Balanced resource allocation"
        print_status "info" "• Medium models (gemma3:4b, llama3:7b)"
        print_status "info" "• Expected: 5-20x faster inference"
    elif [[ "$GPU_AVAILABLE" == "true" ]]; then
        DEPLOYMENT_PROFILE="gpu-light"
        print_status "success" "✨ Recommended: GPU-Light Profile"
        print_status "info" "• Selective GPU acceleration"
        print_status "info" "• Conservative resource allocation"
        print_status "info" "• Small models (gemma3:4b, qwen:4b)"
        print_status "info" "• Expected: 3-10x faster inference"
    elif [[ $MEMORY_GB -ge 32 && $CPU_CORES -ge 8 ]]; then
        DEPLOYMENT_PROFILE="cpu-performance"
        print_status "info" "📊 Recommended: CPU-Performance Profile"
        print_status "info" "• CPU-optimized services"
        print_status "info" "• High memory allocation"
        print_status "info" "• Quantized models"
        print_status "info" "• Expected: Baseline CPU performance"
    else
        DEPLOYMENT_PROFILE="cpu-basic"
        print_status "warning" "⚠️  Recommended: CPU-Basic Profile"
        print_status "info" "• Minimal resource allocation"
        print_status "info" "• Small models only"
        print_status "info" "• May have performance limitations"
    fi
}

# Function to generate configuration file
generate_config() {
    print_status "header" "📝 Generating Hardware Configuration..."
    
    local config_file="kubernetes/config/hardware-config.yaml"
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << EOF
# Hardware Configuration for Local Voice AI
# Generated by detect-hardware.sh on $(date)

hardware:
  gpu:
    available: $GPU_AVAILABLE
    name: "$GPU_NAME"
    memory_mb: $GPU_MEMORY_MB
    high_end: $GPU_HIGH_END
    performance_tier: "$PERFORMANCE_TIER"
  
  cpu:
    cores: $CPU_CORES
    model: "$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)"
    
  memory:
    total_gb: $MEMORY_GB
    available_gb: $(free -g | awk '/^Mem:/{print $7}')
    
  performance:
    score: $(calculate_performance_score)
    tier: "$PERFORMANCE_TIER"

deployment:
  recommended_profile: "$DEPLOYMENT_PROFILE"
  auto_fallback: true
  
resource_allocation:
  ollama:
    cpu_request: "$(get_ollama_cpu_request)"
    cpu_limit: "$(get_ollama_cpu_limit)"
    memory_request: "$(get_ollama_memory_request)"
    memory_limit: "$(get_ollama_memory_limit)"
    gpu_memory: "$(get_ollama_gpu_memory)"
    
  whisper:
    cpu_request: "$(get_whisper_cpu_request)"
    cpu_limit: "$(get_whisper_cpu_limit)"
    memory_request: "$(get_whisper_memory_request)"
    memory_limit: "$(get_whisper_memory_limit)"
    gpu_memory: "$(get_whisper_gpu_memory)"
    
  kokoro:
    cpu_request: "$(get_kokoro_cpu_request)"
    cpu_limit: "$(get_kokoro_cpu_limit)"
    memory_request: "$(get_kokoro_memory_request)"
    memory_limit: "$(get_kokoro_memory_limit)"
    gpu_memory: "$(get_kokoro_gpu_memory)"
    
  agent:
    cpu_request: "$(get_agent_cpu_request)"
    cpu_limit: "$(get_agent_cpu_limit)"
    memory_request: "$(get_agent_memory_request)"
    memory_limit: "$(get_agent_memory_limit)"
    gpu_memory: "$(get_agent_gpu_memory)"
EOF
    
    print_status "success" "Hardware configuration saved to $config_file"
}

# Helper functions for resource allocation
calculate_performance_score() {
    local score=0
    
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        if [[ "$GPU_HIGH_END" == "true" ]]; then
            score=$((score + 40))
        elif [[ $GPU_MEMORY_MB -ge 8000 ]]; then
            score=$((score + 30))
        else
            score=$((score + 20))
        fi
    fi
    
    if [[ $CPU_CORES -ge 16 ]]; then
        score=$((score + 30))
    elif [[ $CPU_CORES -ge 8 ]]; then
        score=$((score + 20))
    else
        score=$((score + 10))
    fi
    
    if [[ $MEMORY_GB -ge 64 ]]; then
        score=$((score + 30))
    elif [[ $MEMORY_GB -ge 32 ]]; then
        score=$((score + 20))
    else
        score=$((score + 10))
    fi
    
    echo $score
}

get_ollama_cpu_request() {
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        echo "4000m"
    else
        echo "2000m"
    fi
}

get_ollama_cpu_limit() {
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        echo "8000m"
    else
        echo "4000m"
    fi
}

get_ollama_memory_request() {
    if [[ $MEMORY_GB -ge 64 ]]; then
        echo "16Gi"
    elif [[ $MEMORY_GB -ge 32 ]]; then
        echo "12Gi"
    else
        echo "8Gi"
    fi
}

get_ollama_memory_limit() {
    if [[ $MEMORY_GB -ge 64 ]]; then
        echo "24Gi"
    elif [[ $MEMORY_GB -ge 32 ]]; then
        echo "16Gi"
    else
        echo "12Gi"
    fi
}

get_ollama_gpu_memory() {
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        if [[ "$GPU_HIGH_END" == "true" ]]; then
            echo "12Gi"
        else
            echo "8Gi"
        fi
    else
        echo "0"
    fi
}

get_whisper_cpu_request() { echo "2000m"; }
get_whisper_cpu_limit() { echo "4000m"; }
get_whisper_memory_request() { echo "4Gi"; }
get_whisper_memory_limit() { echo "8Gi"; }
get_whisper_gpu_memory() { echo "$([[ "$GPU_AVAILABLE" == "true" ]] && echo "4Gi" || echo "0")"; }

get_kokoro_cpu_request() { echo "2000m"; }
get_kokoro_cpu_limit() { echo "4000m"; }
get_kokoro_memory_request() { echo "4Gi"; }
get_kokoro_memory_limit() { echo "8Gi"; }
get_kokoro_gpu_memory() { echo "$([[ "$GPU_AVAILABLE" == "true" ]] && echo "3Gi" || echo "0")"; }

get_agent_cpu_request() { echo "2000m"; }
get_agent_cpu_limit() { echo "4000m"; }
get_agent_memory_request() { echo "6Gi"; }
get_agent_memory_limit() { echo "12Gi"; }
get_agent_gpu_memory() { echo "$([[ "$GPU_AVAILABLE" == "true" ]] && echo "3Gi" || echo "0")"; }

# Function to show summary
show_summary() {
    print_status "header" "📋 Hardware Detection Summary"
    echo "=========================================================="
    echo ""
    
    echo "🎮 GPU: $GPU_AVAILABLE"
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        echo "   Model: $GPU_NAME"
        echo "   Memory: ${GPU_MEMORY_MB}MB"
        echo "   Performance: $PERFORMANCE_TIER"
    fi
    echo ""
    
    echo "🖥️  CPU: $CPU_CORES cores"
    echo "💾 Memory: ${MEMORY_GB}GB"
    echo ""
    
    echo "🎯 Recommended Profile: $DEPLOYMENT_PROFILE"
    echo "📊 Performance Score: $(calculate_performance_score)/100"
    echo ""
    
    echo "=========================================================="
    echo "Next Steps:"
    echo "=========================================================="
    echo ""
    echo "1. Install K3s with GPU support:"
    echo "   ./kubernetes/install/install-k3s-gpu.sh"
    echo ""
    echo "2. Deploy services with recommended profile:"
    echo "   ./kubernetes/scripts/deploy-$DEPLOYMENT_PROFILE.sh"
    echo ""
    echo "3. Verify deployment:"
    echo "   ./kubernetes/scripts/verify-deployment.sh"
    echo ""
    
    if [[ "$GPU_AVAILABLE" == "true" ]]; then
        echo "🚀 Your system is ready for high-performance AI workloads!"
    else
        echo "💡 Consider adding a GPU for better AI performance"
    fi
}

# Main detection flow
main() {
    print_status "header" "🔍 Local Voice AI - Hardware Detection"
    echo "=========================================================="
    echo ""
    echo "This script will analyze your system and recommend the optimal"
    echo "deployment configuration for Local Voice AI."
    echo ""
    
    # Detect hardware components
    detect_gpu
    echo ""
    
    detect_cpu
    echo ""
    
    detect_memory
    echo ""
    
    detect_storage
    echo ""
    
    # Analyze performance
    analyze_performance
    echo ""
    
    # Recommend deployment
    recommend_deployment
    echo ""
    
    # Generate configuration
    generate_config
    echo ""
    
    # Show summary
    show_summary
}

# Handle script interruption
trap 'print_status "warning" "Hardware detection interrupted by user"; exit 130' INT

# Run main function
main "$@"