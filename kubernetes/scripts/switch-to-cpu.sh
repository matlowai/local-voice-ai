#!/bin/bash

# GPU to CPU Fallback Switch Script
# Automatically switches from GPU to CPU deployments when GPU fails

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
LOG_FILE="$SCRIPT_DIR/gpu-cpu-switch.log"

# Services to switch
SERVICES=("ollama" "whisper" "kokoro" "agent")
GPU_DEPLOYMENT_SUFFIX="gpu"
CPU_DEPLOYMENT_SUFFIX="cpu"

# Function to print colored status
print_status() {
    local status=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] $status: $message" >> "$LOG_FILE"
    
    # Print to console with colors
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

# Function to check GPU availability
check_gpu_availability() {
    print_status "info" "Checking GPU availability..."
    
    # Check if GPU nodes are available
    local gpu_nodes=$($KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -v "<none>" | grep -v "GPU" | wc -l)
    
    if [[ $gpu_nodes -eq 0 ]]; then
        print_status "warning" "No GPU nodes available in cluster"
        return 1
    fi
    
    # Check if GPU device plugin is running
    if ! $KUBECTL get pods -n gpu-operator -l app.kubernetes.io/component=nvidia-device-plugin-daemonset | grep -q "Running"; then
        print_status "warning" "NVIDIA device plugin not running"
        return 1
    fi
    
    # Check GPU health by testing a simple GPU operation
    if $KUBECTL exec -n $NAMESPACE deployment/ollama -- nvidia-smi &> /dev/null; then
        print_status "success" "GPU is available and healthy"
        return 0
    else
        print_status "warning" "GPU is not responding"
        return 1
    fi
}

# Function to check GPU service health
check_gpu_service_health() {
    local service=$1
    print_status "info" "Checking GPU service health for $service..."
    
    # Check if GPU deployment exists and is running
    local gpu_deployment="${service}-${GPU_DEPLOYMENT_SUFFIX}"
    if ! $KUBECTL get deployment $gpu_deployment -n $NAMESPACE &> /dev/null; then
        print_status "info" "GPU deployment $gpu_deployment not found"
        return 1
    fi
    
    # Check if pods are running
    local running_pods=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=gpu-optimized --field-selector=status.phase=Running --no-headers | wc -l)
    if [[ $running_pods -eq 0 ]]; then
        print_status "warning" "No running GPU pods for $service"
        return 1
    fi
    
    # Check service health endpoint
    local pod_name=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=gpu-optimized --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
    
    case $service in
        "ollama")
            if $KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:11434/api/tags &> /dev/null; then
                print_status "success" "$service GPU service is healthy"
                return 0
            fi
            ;;
        "whisper")
            if $KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:80/health &> /dev/null; then
                print_status "success" "$service GPU service is healthy"
                return 0
            fi
            ;;
        "kokoro")
            if $KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:8880/health &> /dev/null; then
                print_status "success" "$service GPU service is healthy"
                return 0
            fi
            ;;
        "agent")
            if $KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:8080/health &> /dev/null; then
                print_status "success" "$service GPU service is healthy"
                return 0
            fi
            ;;
    esac
    
    print_status "warning" "$service GPU service health check failed"
    return 1
}

# Function to switch service to CPU
switch_service_to_cpu() {
    local service=$1
    print_status "header" "🔄 Switching $service from GPU to CPU..."
    
    local gpu_deployment="${service}-${GPU_DEPLOYMENT_SUFFIX}"
    local cpu_deployment="${service}-${CPU_DEPLOYMENT_SUFFIX}"
    local service_name="${service}"
    
    # Scale down GPU deployment
    print_status "info" "Scaling down GPU deployment: $gpu_deployment"
    $KUBECTL scale deployment $gpu_deployment --replicas=0 -n $NAMESPACE
    
    # Wait for GPU pods to terminate
    print_status "info" "Waiting for GPU pods to terminate..."
    while [[ $($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=gpu-optimized --no-headers | wc -l) -gt 0 ]]; do
        sleep 5
    done
    
    # Scale up CPU deployment
    print_status "info" "Scaling up CPU deployment: $cpu_deployment"
    $KUBECTL scale deployment $cpu_deployment --replicas=1 -n $NAMESPACE
    
    # Wait for CPU pods to be ready
    print_status "info" "Waiting for CPU pods to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local ready_pods=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=cpu-fallback --field-selector=status.phase=Running --no-headers | wc -l)
        
        if [[ $ready_pods -gt 0 ]]; then
            print_status "success" "$service CPU deployment is ready"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "error" "$service CPU deployment failed to become ready"
            return 1
        fi
        
        print_status "info" "Attempt $attempt/$max_attempts: Waiting for CPU pods..."
        sleep 10
        ((attempt++))
    done
    
    # Update service selector if needed
    print_status "info" "Updating service selector for $service"
    $KUBECTL patch service $service_name -n $NAMESPACE -p '{"spec":{"selector":{"deployment-type":"cpu-fallback"}}}'
    
    print_status "success" "$service successfully switched to CPU"
    return 0
}

# Function to switch all services to CPU
switch_all_to_cpu() {
    print_status "header" "🔄 Switching all services from GPU to CPU..."
    
    local all_switched=true
    
    for service in "${SERVICES[@]}"; do
        if ! switch_service_to_cpu $service; then
            all_switched=false
        fi
        echo ""
    done
    
    if [[ "$all_switched" == "true" ]]; then
        print_status "success" "All services successfully switched to CPU"
        return 0
    else
        print_status "error" "Some services failed to switch to CPU"
        return 1
    fi
}

# Function to create fallback marker
create_fallback_marker() {
    print_status "info" "Creating CPU fallback marker..."
    
    $KUBECTL create configmap cpu-fallback-marker -n $NAMESPACE \
        --from-literal=fallback-time=$(date -Iseconds) \
        --from-literal=fallback-reason="GPU failure detected" \
        --from-literal=auto-switch="true" \
        --dry-run=client -o yaml | $KUBECTL apply -f -
    
    print_status "success" "CPU fallback marker created"
}

# Function to check if already in CPU mode
check_already_cpu_mode() {
    if $KUBECTL get configmap cpu-fallback-marker -n $NAMESPACE &> /dev/null; then
        print_status "info" "Already in CPU fallback mode"
        return 0
    else
        return 1
    fi
}

# Function to monitor GPU health and auto-switch
monitor_and_auto_switch() {
    print_status "header" "🔍 Monitoring GPU health and auto-switching..."
    
    # Check if already in CPU mode
    if check_already_cpu_mode; then
        print_status "info" "System is already in CPU fallback mode"
        return 0
    fi
    
    # Check GPU availability
    if ! check_gpu_availability; then
        print_status "warning" "GPU not available, switching to CPU"
        create_fallback_marker
        switch_all_to_cpu
        return 0
    fi
    
    # Check each GPU service
    local failed_services=()
    
    for service in "${SERVICES[@]}"; do
        if ! check_gpu_service_health $service; then
            failed_services+=($service)
        fi
    done
    
    # If any services failed, switch all to CPU
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        print_status "warning" "Failed GPU services detected: ${failed_services[*]}"
        print_status "info" "Switching all services to CPU for consistency"
        create_fallback_marker
        switch_all_to_cpu
        return 0
    fi
    
    print_status "success" "All GPU services are healthy, no switch needed"
    return 0
}

# Function to show current status
show_current_status() {
    print_status "header" "📊 Current Deployment Status"
    echo "=========================================================="
    echo ""
    
    echo "GPU Availability:"
    echo "----------------------------------------"
    if check_gpu_availability; then
        print_status "success" "GPU is available"
    else
        print_status "error" "GPU is not available"
    fi
    echo ""
    
    echo "Service Status:"
    echo "----------------------------------------"
    for service in "${SERVICES[@]}"; do
        local gpu_pods=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=gpu-optimized --no-headers | wc -l)
        local cpu_pods=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=cpu-fallback --no-headers | wc -l)
        
        if [[ $gpu_pods -gt 0 ]]; then
            print_status "performance" "$service: GPU mode ($gpu_pods pods)"
        elif [[ $cpu_pods -gt 0 ]]; then
            print_status "info" "$service: CPU mode ($cpu_pods pods)"
        else
            print_status "error" "$service: No pods running"
        fi
    done
    echo ""
    
    echo "Fallback Status:"
    echo "----------------------------------------"
    if check_already_cpu_mode; then
        print_status "warning" "System is in CPU fallback mode"
        local fallback_time=$($KUBECTL get configmap cpu-fallback-marker -n $NAMESPACE -o jsonpath='{.data.fallback-time}')
        echo "Fallback since: $fallback_time"
    else
        print_status "success" "System is running in GPU mode"
    fi
    echo ""
    
    echo "=========================================================="
}

# Function to switch back to GPU (when GPU is recovered)
switch_back_to_gpu() {
    print_status "header" "🚀 Switching back to GPU mode..."
    
    # Check if GPU is available
    if ! check_gpu_availability; then
        print_status "error" "GPU is not available, cannot switch back"
        return 1
    fi
    
    # Remove fallback marker
    if $KUBECTL get configmap cpu-fallback-marker -n $NAMESPACE &> /dev/null; then
        $KUBECTL delete configmap cpu-fallback-marker -n $NAMESPACE
        print_status "info" "CPU fallback marker removed"
    fi
    
    # Switch each service back to GPU
    local all_switched=true
    
    for service in "${SERVICES[@]}"; do
        local cpu_deployment="${service}-${CPU_DEPLOYMENT_SUFFIX}"
        local gpu_deployment="${service}-${GPU_DEPLOYMENT_SUFFIX}"
        local service_name="${service}"
        
        print_status "info" "Switching $service back to GPU..."
        
        # Scale down CPU deployment
        $KUBECTL scale deployment $cpu_deployment --replicas=0 -n $NAMESPACE
        
        # Wait for CPU pods to terminate
        while [[ $($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=cpu-fallback --no-headers | wc -l) -gt 0 ]]; do
            sleep 5
        done
        
        # Scale up GPU deployment
        $KUBECTL scale deployment $gpu_deployment --replicas=1 -n $NAMESPACE
        
        # Wait for GPU pods to be ready
        local max_attempts=60
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            local ready_pods=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service,deployment-type=gpu-optimized --field-selector=status.phase=Running --no-headers | wc -l)
            
            if [[ $ready_pods -gt 0 ]]; then
                print_status "success" "$service GPU deployment is ready"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                print_status "error" "$service GPU deployment failed to become ready"
                all_switched=false
                break
            fi
            
            sleep 10
            ((attempt++))
        done
        
        # Update service selector
        $KUBECTL patch service $service_name -n $NAMESPACE -p '{"spec":{"selector":{"deployment-type":"gpu-optimized"}}}'
        
        echo ""
    done
    
    if [[ "$all_switched" == "true" ]]; then
        print_status "success" "All services successfully switched back to GPU"
        print_status "performance" "🚀 Enjoy the restored GPU performance!"
    else
        print_status "error" "Some services failed to switch back to GPU"
    fi
}

# Main script flow
main() {
    local action=${1:-"monitor"}
    
    print_status "header" "🔄 GPU/CPU Switch Script for Local Voice AI"
    echo "=========================================================="
    echo ""
    
    case $action in
        "monitor")
            monitor_and_auto_switch
            ;;
        "status")
            show_current_status
            ;;
        "switch-cpu")
            switch_all_to_cpu
            ;;
        "switch-gpu")
            switch_back_to_gpu
            ;;
        "check-gpu")
            check_gpu_availability
            ;;
        *)
            echo "Usage: $0 {monitor|status|switch-cpu|switch-gpu|check-gpu}"
            echo ""
            echo "Commands:"
            echo "  monitor     - Monitor GPU health and auto-switch to CPU if needed"
            echo "  status      - Show current deployment status"
            echo "  switch-cpu  - Manually switch all services to CPU mode"
            echo "  switch-gpu  - Switch back to GPU mode (when available)"
            echo "  check-gpu   - Check GPU availability"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'print_status "warning" "Script interrupted by user"; exit 130' INT

# Run main function
main "$@"