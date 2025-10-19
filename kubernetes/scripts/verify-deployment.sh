#!/bin/bash

# Service Verification Script for Local Voice AI
# Comprehensive health check and validation of all services

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
MONITORING_NAMESPACE="monitoring"
KUBECTL="kubectl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        return 1
    fi
    
    print_status "success" "Cluster connectivity verified"
    return 0
}

# Function to check namespace status
check_namespace_status() {
    print_status "header" "📋 Checking namespace status..."
    
    local namespaces=("$NAMESPACE" "$MONITORING_NAMESPACE" "gpu-operator")
    local all_exist=true
    
    for ns in "${namespaces[@]}"; do
        if $KUBECTL get namespace $ns &> /dev/null; then
            print_status "success" "Namespace '$ns' exists"
        else
            print_status "error" "Namespace '$ns' does not exist"
            all_exist=false
        fi
    done
    
    if [[ "$all_exist" == "true" ]]; then
        print_status "success" "All namespaces are present"
        return 0
    else
        return 1
    fi
}

# Function to check pod status
check_pod_status() {
    print_status "header" "🚀 Checking pod status..."
    
    local all_running=true
    local services=("ollama" "whisper" "kokoro" "agent" "livekit" "frontend")
    
    echo ""
    echo "Service Pod Status:"
    echo "----------------------------------------"
    
    for service in "${services[@]}"; do
        local pod_info=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --no-headers 2>/dev/null || echo "")
        
        if [[ -n "$pod_info" ]]; then
            local pod_name=$(echo "$pod_info" | awk '{print $1}')
            local pod_status=$(echo "$pod_info" | awk '{print $3}')
            local pod_ready=$(echo "$pod_info" | awk '{print $2}')
            
            if [[ "$pod_status" == "Running" ]]; then
                print_status "success" "$service: $pod_name ($pod_ready) - $pod_status"
            else
                print_status "error" "$service: $pod_name ($pod_ready) - $pod_status"
                all_running=false
                
                # Show recent events for failed pods
                print_status "info" "Recent events for $service:"
                $KUBECTL describe pod $pod_name -n $NAMESPACE | tail -10
            fi
        else
            print_status "error" "$service: No pods found"
            all_running=false
        fi
    done
    
    echo ""
    
    if [[ "$all_running" == "true" ]]; then
        print_status "success" "All service pods are running"
        return 0
    else
        return 1
    fi
}

# Function to check service connectivity
check_service_connectivity() {
    print_status "header" "🌐 Checking service connectivity..."
    
    local services=("ollama:11434" "whisper:80" "kokoro:8880" "agent:8080" "livekit:7880" "frontend:3000")
    local all_accessible=true
    
    echo ""
    echo "Service Connectivity:"
    echo "----------------------------------------"
    
    for service_info in "${services[@]}"; do
        local service_name=$(echo $service_info | cut -d':' -f1)
        local service_port=$(echo $service_info | cut -d':' -f2)
        
        # Check if service exists
        if $KUBECTL get svc $service_name -n $NAMESPACE &> /dev/null; then
            # Port-forward to test connectivity
            local local_port=$((10000 + RANDOM % 1000))
            
            # Start port-forward in background
            $KUBECTL port-forward -n $NAMESPACE svc/$service_name $local_port:$service_port &
            local pf_pid=$!
            
            # Wait for port-forward to establish
            sleep 3
            
            # Test connectivity
            if curl -s --connect-timeout 5 http://localhost:$local_port &> /dev/null; then
                print_status "success" "$service_name:$service_port - Accessible"
            else
                print_status "error" "$service_name:$service_port - Not accessible"
                all_accessible=false
            fi
            
            # Clean up port-forward
            kill $pf_pid 2>/dev/null || true
            wait $pf_pid 2>/dev/null || true
        else
            print_status "error" "$service_name - Service not found"
            all_accessible=false
        fi
    done
    
    echo ""
    
    if [[ "$all_accessible" == "true" ]]; then
        print_status "success" "All services are accessible"
        return 0
    else
        return 1
    fi
}

# Function to check GPU resources
check_gpu_resources() {
    print_status "header" "🎮 Checking GPU resources..."
    
    # Check if GPU is available in cluster
    local gpu_nodes=$($KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -v "<none>" | grep -v "GPU" | wc -l)
    
    if [[ $gpu_nodes -gt 0 ]]; then
        print_status "success" "GPU resources available in cluster"
        
        # Check GPU utilization in pods
        echo ""
        echo "GPU Pod Utilization:"
        echo "----------------------------------------"
        
        local gpu_pods=$($KUBECTL get pods -n $NAMESPACE -o custom-columns=NAME:.metadata.name,GPU:.spec.containers[*].resources.limits.nvidia\.com/gpu --no-headers | grep -v "<none>" | grep -v "GPU")
        
        if [[ -n "$gpu_pods" ]]; then
            while IFS= read -r pod_info; do
                local pod_name=$(echo "$pod_info" | awk '{print $1}')
                local gpu_count=$(echo "$pod_info" | awk '{print $2}')
                
                if [[ "$gpu_count" != "<none>" && "$gpu_count" != "GPU" ]]; then
                    print_status "success" "$pod_name: $gpu_count GPU(s) allocated"
                    
                    # Check actual GPU usage
                    if $KUBECTL exec -n $NAMESPACE $pod_name -- nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null; then
                        local gpu_usage=$($KUBECTL exec -n $NAMESPACE $pod_name -- nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null)
                        print_status "info" "  GPU Usage: $gpu_usage"
                    fi
                fi
            done <<< "$gpu_pods"
        else
            print_status "warning" "No GPU pods found"
        fi
    else
        print_status "warning" "No GPU resources available in cluster"
        print_status "info" "Services may be running in CPU-only mode"
    fi
    
    echo ""
}

# Function to check storage status
check_storage_status() {
    print_status "header" "💾 Checking storage status..."
    
    local pvcs=("ollama-storage" "whisper-storage" "kokoro-storage" "agent-storage" "temp-storage")
    local all_bound=true
    
    echo ""
    echo "PersistentVolumeClaim Status:"
    echo "----------------------------------------"
    
    for pvc in "${pvcs[@]}"; do
        local pvc_info=$($KUBECTL get pvc $pvc -n $NAMESPACE --no-headers 2>/dev/null || echo "")
        
        if [[ -n "$pvc_info" ]]; then
            local pvc_status=$(echo "$pvc_info" | awk '{print $2}')
            local pvc_capacity=$(echo "$pvc_info" | awk '{print $4}')
            
            if [[ "$pvc_status" == "Bound" ]]; then
                print_status "success" "$pvc: $pvc_capacity - $pvc_status"
            else
                print_status "error" "$pvc: $pvc_capacity - $pvc_status"
                all_bound=false
            fi
        else
            print_status "error" "$pvc: PVC not found"
            all_bound=false
        fi
    done
    
    echo ""
    
    if [[ "$all_bound" == "true" ]]; then
        print_status "success" "All PVCs are bound"
        return 0
    else
        return 1
    fi
}

# Function to check AI service functionality
check_ai_service_functionality() {
    print_status "header" "🧠 Checking AI service functionality..."
    
    echo ""
    echo "AI Service Tests:"
    echo "----------------------------------------"
    
    # Test Ollama
    print_status "info" "Testing Ollama LLM service..."
    if $KUBECTL exec -n $NAMESPACE deployment/ollama -- curl -s http://localhost:11434/api/tags &> /dev/null; then
        print_status "success" "Ollama API is responding"
        
        # Check if models are loaded
        local models=$($KUBECTL exec -n $NAMESPACE deployment/ollama -- curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null || echo "")
        if [[ -n "$models" ]]; then
            print_status "success" "Models loaded: $(echo "$models" | tr '\n' ', ' | sed 's/,$//')"
        else
            print_status "warning" "No models loaded yet"
        fi
    else
        print_status "error" "Ollama API is not responding"
    fi
    
    # Test Whisper
    print_status "info" "Testing Whisper STT service..."
    if $KUBECTL exec -n $NAMESPACE deployment/whisper -- curl -s http://localhost:80/health &> /dev/null; then
        print_status "success" "Whisper health check passed"
    else
        print_status "error" "Whisper health check failed"
    fi
    
    # Test Kokoro
    print_status "info" "Testing Kokoro TTS service..."
    if $KUBECTL exec -n $NAMESPACE deployment/kokoro -- curl -s http://localhost:8880/health &> /dev/null; then
        print_status "success" "Kokoro health check passed"
    else
        print_status "error" "Kokoro health check failed"
    fi
    
    # Test Agent
    print_status "info" "Testing Agent service..."
    if $KUBECTL exec -n $NAMESPACE deployment/agent -- curl -s http://localhost:8080/health &> /dev/null; then
        print_status "success" "Agent health check passed"
    else
        print_status "error" "Agent health check failed"
    fi
    
    echo ""
}

# Function to check monitoring stack
check_monitoring_stack() {
    print_status "header" "📊 Checking monitoring stack..."
    
    # Check Prometheus
    if $KUBECTL get deployment prometheus -n $MONITORING_NAMESPACE &> /dev/null; then
        local prometheus_status=$($KUBECTL get deployment prometheus -n $MONITORING_NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [[ "$prometheus_status" == "1" ]]; then
            print_status "success" "Prometheus is running"
        else
            print_status "error" "Prometheus is not ready"
        fi
    else
        print_status "warning" "Prometheus not found"
    fi
    
    # Check Grafana
    if $KUBECTL get deployment grafana -n $MONITORING_NAMESPACE &> /dev/null; then
        local grafana_status=$($KUBECTL get deployment grafana -n $MONITORING_NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [[ "$grafana_status" == "1" ]]; then
            print_status "success" "Grafana is running"
        else
            print_status "error" "Grafana is not ready"
        fi
    else
        print_status "warning" "Grafana not found"
    fi
    
    echo ""
}

# Function to generate verification report
generate_verification_report() {
    print_status "header" "📋 Generating verification report..."
    
    local report_file="$SCRIPT_DIR/verification-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Local Voice AI - Deployment Verification Report"
        echo "Generated: $(date)"
        echo "=============================================="
        echo ""
        
        echo "Cluster Information:"
        echo "-------------------"
        $KUBECTL cluster-info
        echo ""
        
        echo "Node Information:"
        echo "-----------------"
        $KUBECTL get nodes -o wide
        echo ""
        
        echo "Pod Status:"
        echo "-----------"
        $KUBECTL get pods -n $NAMESPACE -o wide
        echo ""
        
        echo "Service Status:"
        echo "---------------"
        $KUBECTL get svc -n $NAMESPACE
        echo ""
        
        echo "Storage Status:"
        echo "---------------"
        $KUBECTL get pvc -n $NAMESPACE
        echo ""
        
        echo "Recent Events:"
        echo "---------------"
        $KUBECTL get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20
        echo ""
        
    } > "$report_file"
    
    print_status "success" "Verification report saved to: $report_file"
}

# Function to show final status
show_final_status() {
    local exit_code=$1
    
    print_status "header" "🎯 Verification Complete"
    echo "=========================================================="
    echo ""
    
    if [[ $exit_code -eq 0 ]]; then
        print_status "highlight" "🌟 All verification checks passed!"
        echo ""
        echo "Your Local Voice AI deployment is healthy and ready to use."
        echo ""
        echo "Access URLs:"
        echo "🌐 Frontend: http://localhost:30080"
        echo "📊 Grafana: http://localhost:30030 (admin/admin123)"
        echo ""
        print_status "performance" "🚀 Enjoy your GPU-accelerated voice assistant!"
    else
        print_status "error" "❌ Some verification checks failed"
        echo ""
        echo "Please check the detailed output above for troubleshooting."
        echo ""
        echo "Common fixes:"
        echo "1. Restart failed services: kubectl rollout restart deployment/<service> -n $NAMESPACE"
        echo "2. Check pod logs: kubectl logs -f deployment/<service> -n $NAMESPACE"
        echo "3. Verify GPU availability: kubectl describe nodes"
        echo "4. Check storage: kubectl get pvc -n $NAMESPACE"
        echo ""
        print_status "info" "For detailed troubleshooting, see the verification report"
    fi
    
    echo "=========================================================="
}

# Main verification flow
main() {
    print_status "header" "🔍 Local Voice AI - Service Verification"
    echo "=========================================================="
    echo ""
    echo "This script will perform comprehensive health checks on all"
    echo "Local Voice AI services and components."
    echo ""
    
    # Track overall success
    local all_passed=true
    
    # Check cluster connectivity
    if ! check_cluster_connectivity; then
        all_passed=false
    fi
    echo ""
    
    # Check namespace status
    if ! check_namespace_status; then
        all_passed=false
    fi
    echo ""
    
    # Check pod status
    if ! check_pod_status; then
        all_passed=false
    fi
    echo ""
    
    # Check service connectivity
    if ! check_service_connectivity; then
        all_passed=false
    fi
    echo ""
    
    # Check GPU resources
    check_gpu_resources
    
    # Check storage status
    if ! check_storage_status; then
        all_passed=false
    fi
    echo ""
    
    # Check AI service functionality
    check_ai_service_functionality
    
    # Check monitoring stack
    check_monitoring_stack
    
    # Generate verification report
    generate_verification_report
    
    # Show final status
    if [[ "$all_passed" == "true" ]]; then
        show_final_status 0
        exit 0
    else
        show_final_status 1
        exit 1
    fi
}

# Handle script interruption
trap 'print_status "warning" "Verification interrupted by user"; exit 130' INT

# Run main function
main "$@"