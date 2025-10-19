#!/bin/bash

# Complete Kubernetes Deployment Test Script
# Comprehensive validation of the entire Local Voice AI Kubernetes deployment

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
TEST_RESULTS_DIR="$SCRIPT_DIR/test-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_LOG="$TEST_RESULTS_DIR/complete-test-$TIMESTAMP.log"

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

# Function to print colored status
print_status() {
    local status=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] $status: $message" >> "$TEST_LOG"
    
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

# Function to run a test and capture results
run_test() {
    local test_name=$1
    local test_command=$2
    local expected_result=${3:-0}
    
    print_status "info" "Running test: $test_name"
    
    # Run the test and capture output
    if eval "$test_command" >> "$TEST_LOG" 2>&1; then
        local actual_result=0
    else
        local actual_result=1
    fi
    
    # Check result
    if [[ $actual_result -eq $expected_result ]]; then
        print_status "success" "$test_name: PASSED"
        echo "PASSED: $test_name" >> "$TEST_RESULTS_DIR/results.txt"
        return 0
    else
        print_status "error" "$test_name: FAILED"
        echo "FAILED: $test_name" >> "$TEST_RESULTS_DIR/results.txt"
        return 1
    fi
}

# Function to test prerequisites
test_prerequisites() {
    print_status "header" "🔍 Testing Prerequisites"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test kubectl availability
    run_test "kubectl availability" "command -v kubectl" || all_passed=false
    
    # Test cluster connectivity
    run_test "cluster connectivity" "$KUBECTL cluster-info" || all_passed=false
    
    # Test namespace existence
    run_test "namespace existence" "$KUBECTL get namespace $NAMESPACE" || all_passed=false
    
    # Test GPU availability
    if $KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
        print_status "success" "GPU resources available"
    else
        print_status "warning" "GPU resources not available - will test CPU fallback"
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Prerequisites tests passed"
        return 0
    else
        print_status "error" "Some prerequisites tests failed"
        return 1
    fi
}

# Function to test infrastructure components
test_infrastructure() {
    print_status "header" "🏗️  Testing Infrastructure Components"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test namespaces
    run_test "voice-ai namespace" "$KUBECTL get namespace $NAMESPACE" || all_passed=false
    run_test "monitoring namespace" "$KUBECTL get namespace $MONITORING_NAMESPACE" || all_passed=false
    run_test "gpu-operator namespace" "$KUBECTL get namespace gpu-operator" || all_passed=false
    
    # Test storage classes
    run_test "local-path storage class" "$KUBECTL get storageclass local-path" || all_passed=false
    run_test "local-path-ssd storage class" "$KUBECTL get storageclass local-path-ssd" || all_passed=false
    
    # Test PVCs
    local pvcs=("ollama-storage" "whisper-storage" "kokoro-storage" "agent-storage" "temp-storage")
    for pvc in "${pvcs[@]}"; do
        run_test "$pvc PVC" "$KUBECTL get pvc $pvc -n $NAMESPACE" || all_passed=false
    done
    
    # Test network policies
    run_test "network policies" "$KUBECTL get networkpolicy -n $NAMESPACE | grep -q 'default-deny-all'" || all_passed=false
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Infrastructure tests passed"
        return 0
    else
        print_status "error" "Some infrastructure tests failed"
        return 1
    fi
}

# Function to test AI services
test_ai_services() {
    print_status "header" "🧠 Testing AI Services"
    echo "=========================================================="
    
    local all_passed=true
    local services=("ollama" "whisper" "kokoro" "agent")
    
    for service in "${services[@]}"; do
        # Test pod deployment
        run_test "$service pod deployment" "$KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running | grep -q '$service'" || all_passed=false
        
        # Test service creation
        run_test "$service service creation" "$KUBECTL get svc -n $NAMESPACE -l app.kubernetes.io/name=$service | grep -q '$service'" || all_passed=false
        
        # Get a running pod for testing
        local pod_name=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [[ -n "$pod_name" ]]; then
            # Test service health
            case $service in
                "ollama")
                    run_test "$service health check" "$KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:11434/api/tags" || all_passed=false
                    ;;
                "whisper")
                    run_test "$service health check" "$KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:80/health" || all_passed=false
                    ;;
                "kokoro")
                    run_test "$service health check" "$KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:8880/health" || all_passed=false
                    ;;
                "agent")
                    run_test "$service health check" "$KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:8080/health" || all_passed=false
                    ;;
            esac
        else
            print_status "error" "$service: No running pod found"
            all_passed=false
        fi
    done
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "AI services tests passed"
        return 0
    else
        print_status "error" "Some AI services tests failed"
        return 1
    fi
}

# Function to test supporting services
test_supporting_services() {
    print_status "header" "🔧 Testing Supporting Services"
    echo "=========================================================="
    
    local all_passed=true
    local services=("livekit" "frontend")
    
    for service in "${services[@]}"; do
        # Test pod deployment
        run_test "$service pod deployment" "$KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running | grep -q '$service'" || all_passed=false
        
        # Test service creation
        run_test "$service service creation" "$KUBECTL get svc -n $NAMESPACE -l app.kubernetes.io/name=$service | grep -q '$service'" || all_passed=false
        
        # Get a running pod for testing
        local pod_name=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [[ -n "$pod_name" ]]; then
            # Test service health
            case $service in
                "livekit")
                    run_test "$service health check" "$KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:7880/health" || all_passed=false
                    ;;
                "frontend")
                    run_test "$service health check" "$KUBECTL exec -n $NAMESPACE $pod_name -- curl -s http://localhost:3000 | grep -q 'Local Voice AI'" || all_passed=false
                    ;;
            esac
        else
            print_status "error" "$service: No running pod found"
            all_passed=false
        fi
    done
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Supporting services tests passed"
        return 0
    else
        print_status "error" "Some supporting services tests failed"
        return 1
    fi
}

# Function to test GPU functionality
test_gpu_functionality() {
    print_status "header" "🎮 Testing GPU Functionality"
    echo "=========================================================="
    
    local all_passed=true
    
    # Check if GPU is available
    if $KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
        print_status "success" "GPU resources detected"
        
        # Test GPU device plugin
        run_test "GPU device plugin" "$KUBECTL get pods -n gpu-operator -l app.kubernetes.io/component=nvidia-device-plugin-daemonset | grep -q 'Running'" || all_passed=false
        
        # Test GPU functionality in pods
        local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [[ -n "$ollama_pod" ]]; then
            run_test "GPU functionality" "$KUBECTL exec -n $NAMESPACE $ollama_pod -- nvidia-smi" || all_passed=false
            run_test "GPU memory allocation" "$KUBECTL exec -n $NAMESPACE $ollama_pod -- nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | grep -q '[0-9]'" || all_passed=false
        else
            print_status "error" "No running Ollama pod found for GPU test"
            all_passed=false
        fi
    else
        print_status "warning" "GPU resources not detected - skipping GPU tests"
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "GPU functionality tests passed"
        return 0
    else
        print_status "error" "Some GPU functionality tests failed"
        return 1
    fi
}

# Function to test service integration
test_service_integration() {
    print_status "header" "🔗 Testing Service Integration"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test internal service communication
    local agent_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=agent --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$agent_pod" ]]; then
        # Test Agent to Ollama communication
        run_test "Agent to Ollama" "$KUBECTL exec -n $NAMESPACE $agent_pod -- curl -s http://ollama.voice-ai.svc.cluster.local:11434/api/tags" || all_passed=false
        
        # Test Agent to Whisper communication
        run_test "Agent to Whisper" "$KUBECTL exec -n $NAMESPACE $agent_pod -- curl -s http://whisper.voice-ai.svc.cluster.local:11435/health" || all_passed=false
        
        # Test Agent to Kokoro communication
        run_test "Agent to Kokoro" "$KUBECTL exec -n $NAMESPACE $agent_pod -- curl -s http://kokoro.voice-ai.svc.cluster.local:8880/health" || all_passed=false
    else
        print_status "error" "No running Agent pod found for integration test"
        all_passed=false
    fi
    
    # Test service discovery
    run_test "Service discovery" "$KUBECTL get endpoints -n $NAMESPACE | grep -q 'ollama'" || all_passed=false
    
    # Test network policies
    run_test "Network policies" "$KUBECTL get networkpolicy -n $NAMESPACE | grep -q 'allow-dns'" || all_passed=false
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Service integration tests passed"
        return 0
    else
        print_status "error" "Some service integration tests failed"
        return 1
    fi
}

# Function to test end-to-end workflow
test_end_to_end_workflow() {
    print_status "header" "🔄 Testing End-to-End Workflow"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test TTS workflow
    print_status "info" "Testing TTS workflow..."
    local kokoro_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=kokoro --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$kokoro_pod" ]]; then
        run_test "TTS generation" "$KUBECTL exec -n $NAMESPACE $kokoro_pod -- curl -s -X POST http://localhost:8880/tts -H 'Content-Type: application/json' -d '{\"text\":\"Hello world\"}' | grep -q 'audio_url'" || all_passed=false
    else
        print_status "error" "No running Kokoro pod found for TTS test"
        all_passed=false
    fi
    
    # Test LLM workflow
    print_status "info" "Testing LLM workflow..."
    local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$ollama_pod" ]]; then
        run_test "LLM generation" "$KUBECTL exec -n $NAMESPACE $ollama_pod -- curl -s -X POST http://localhost:11434/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"gemma3:4b\",\"prompt\":\"Hello\",\"stream\":false}' | grep -q 'response'" || all_passed=false
    else
        print_status "error" "No running Ollama pod found for LLM test"
        all_passed=false
    fi
    
    # Test Agent workflow
    print_status "info" "Testing Agent workflow..."
    local agent_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=agent --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$agent_pod" ]]; then
        run_test "Agent workflow" "$KUBECTL exec -n $NAMESPACE $agent_pod -- curl -s http://localhost:8080/health | grep -q 'ok'" || all_passed=false
    else
        print_status "error" "No running Agent pod found for Agent test"
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "End-to-end workflow tests passed"
        return 0
    else
        print_status "error" "Some end-to-end workflow tests failed"
        return 1
    fi
}

# Function to test ingress and external access
test_ingress_external_access() {
    print_status "header" "🌐 Testing Ingress and External Access"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test ingress controller
    run_test "Ingress controller" "$KUBECTL get pods -n traefik -l app.kubernetes.io/name=traefik | grep -q 'Running'" || all_passed=false
    
    # Test ingress routes
    run_test "Ingress routes" "$KUBECTL get ingress -n $NAMESPACE | grep -q 'voice-ai-ingress'" || all_passed=false
    
    # Test external access to frontend
    local frontend_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=frontend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$frontend_pod" ]]; then
        # Port-forward to test external access
        $KUBECTL port-forward -n $NAMESPACE svc/frontend 30080:3000 &
        local pf_pid=$!
        
        # Wait for port-forward to establish
        sleep 3
        
        # Test external access
        if curl -s http://localhost:30080 | grep -q "Local Voice AI"; then
            print_status "success" "External access to frontend: PASSED"
        else
            print_status "error" "External access to frontend: FAILED"
            all_passed=false
        fi
        
        # Clean up port-forward
        kill $pf_pid 2>/dev/null || true
        wait $pf_pid 2>/dev/null || true
    else
        print_status "error" "No running Frontend pod found for external access test"
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Ingress and external access tests passed"
        return 0
    else
        print_status "error" "Some ingress and external access tests failed"
        return 1
    fi
}

# Function to test monitoring
test_monitoring() {
    print_status "header" "📊 Testing Monitoring"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test Prometheus
    run_test "Prometheus deployment" "$KUBECTL get deployment prometheus -n $MONITORING_NAMESPACE" || all_passed=false
    
    # Test Grafana
    run_test "Grafana deployment" "$KUBECTL get deployment grafana -n $MONITORING_NAMESPACE" || all_passed=false
    
    # Test DCGM Exporter
    run_test "DCGM Exporter deployment" "$KUBECTL get daemonset dcgm-exporter -n gpu-operator" || all_passed=false
    
    # Test metrics collection
    local prometheus_pod=$($KUBECTL get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=prometheus --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$prometheus_pod" ]]; then
        run_test "Metrics collection" "$KUBECTL exec -n $MONITORING_NAMESPACE $prometheus_pod -- wget -q http://localhost:9090/metrics -O - | head -10 | grep -q '^# HELP'" || all_passed=false
    else
        print_status "error" "No running Prometheus pod found"
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Monitoring tests passed"
        return 0
    else
        print_status "error" "Some monitoring tests failed"
        return 1
    fi
}

# Function to test CPU fallback
test_cpu_fallback() {
    print_status "header" "🔄 Testing CPU Fallback"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test CPU deployments exist
    run_test "CPU Ollama deployment" "$KUBECTL get deployment ollama-cpu -n $NAMESPACE" || all_passed=false
    run_test "CPU Whisper deployment" "$KUBECTL get deployment whisper-cpu -n $NAMESPACE" || all_passed=false
    run_test "CPU Kokoro deployment" "$KUBECTL get deployment kokoro-cpu -n $NAMESPACE" || all_passed=false
    run_test "CPU Agent deployment" "$KUBECTL get deployment agent-cpu -n $NAMESPACE" || all_passed=false
    
    # Test switch script
    run_test "Switch script availability" "test -f $SCRIPT_DIR/switch-to-cpu.sh" || all_passed=false
    
    # Test switch script functionality
    run_test "Switch script status" "$SCRIPT_DIR/switch-to-cpu.sh status" || all_passed=false
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "CPU fallback tests passed"
        return 0
    else
        print_status "error" "Some CPU fallback tests failed"
        return 1
    fi
}

# Function to test performance
test_performance() {
    print_status "header" "⚡ Testing Performance"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test GPU performance if available
    if $KUBECTL get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -q "1"; then
        local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [[ -n "$ollama_pod" ]]; then
            # Check GPU utilization
            local gpu_util=$($KUBECTL exec -n $NAMESPACE $ollama_pod -- nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "0")
            if [[ $gpu_util -gt 0 ]]; then
                print_status "success" "GPU utilization: ${gpu_util}%"
            else
                print_status "info" "GPU utilization: ${gpu_util}% (GPU may be idle)"
            fi
            
            # Test response time
            local start_time=$(date +%s.%N)
            $KUBECTL exec -n $NAMESPACE $ollama_pod -- curl -s -X POST http://localhost:11434/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"gemma3:4b\",\"prompt\":\"Hello\",\"stream\":false}' > /dev/null
            local end_time=$(date +%s.%N)
            local response_time=$(echo "$end_time - $start_time" | bc)
            local response_time_ms=$(echo "$response_time * 1000" | bc)
            
            if (( $(echo "$response_time_ms < 5000" | bc -l) )); then
                print_status "success" "LLM response time: ${response_time_ms}ms"
            else
                print_status "warning" "LLM response time: ${response_time_ms}ms (slower than expected)"
            fi
        else
            print_status "error" "No running Ollama pod found for performance test"
            all_passed=false
        fi
    else
        print_status "info" "GPU not available - skipping GPU performance tests"
    fi
    
    # Test resource usage
    local total_cpu=$($KUBECTL top pods -n $NAMESPACE --no-headers | awk '{sum+=$2} END {print sum}' 2>/dev/null || echo "0")
    local total_memory=$($KUBECTL top pods -n $NAMESPACE --no-headers | awk '{sum+=$3} END {print sum}' 2>/dev/null || echo "0")
    
    print_status "info" "Total CPU usage: ${total_cpu}m"
    print_status "info" "Total memory usage: ${total_memory}Mi"
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Performance tests passed"
        return 0
    else
        print_status "error" "Some performance tests failed"
        return 1
    fi
}

# Function to generate comprehensive test report
generate_comprehensive_report() {
    print_status "header" "📋 Generating Comprehensive Test Report"
    echo "=========================================================="
    
    local report_file="$TEST_RESULTS_DIR/complete-test-report-$TIMESTAMP.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Local Voice AI - Complete Kubernetes Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .success { color: green; }
        .error { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary { background-color: #e8f4f8; padding: 15px; border-radius: 5px; }
        .performance { background-color: #fff8e1; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Local Voice AI - Complete Kubernetes Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Test Log: $TEST_LOG</p>
        <p>Test Results: $TEST_RESULTS_DIR/results.txt</p>
    </div>
    
    <div class="section">
        <h2>Test Summary</h2>
        <div class="summary">
            <p>Overall Result: <span class="$(grep -q 'FAILED' "$TEST_RESULTS_DIR/results.txt" && echo 'error' || echo 'success')">$(grep -q 'FAILED' "$TEST_RESULTS_DIR/results.txt" && echo 'FAILED' || echo 'PASSED')</span></p>
            <p>Total Tests: $(wc -l < "$TEST_RESULTS_DIR/results.txt")</p>
            <p>Passed: $(grep -c 'PASSED' "$TEST_RESULTS_DIR/results.txt")</p>
            <p>Failed: $(grep -c 'FAILED' "$TEST_RESULTS_DIR/results.txt")</p>
        </div>
    </div>
    
    <div class="section">
        <h2>Performance Metrics</h2>
        <div class="performance">
            <p>GPU Utilization: <span id="gpu-util">N/A</span></p>
            <p>LLM Response Time: <span id="llm-response">N/A</span></p>
            <p>Total CPU Usage: <span id="cpu-usage">N/A</span></p>
            <p>Total Memory Usage: <span id="memory-usage">N/A</span></p>
        </div>
    </div>
    
    <div class="section">
        <h2>Test Results by Category</h2>
        <table>
            <tr>
                <th>Category</th>
                <th>Test Name</th>
                <th>Result</th>
                <th>Details</th>
            </tr>
EOF
    
    # Add test results to report
    local category="Prerequisites"
    while IFS= read -r line; do
        local result=$(echo "$line" | cut -d':' -f1)
        local test_name=$(echo "$line" | cut -d':' -f2-)
        
        # Determine category based on test name
        if [[ "$test_name" == *"kubectl"* ]] || [[ "$test_name" == *"cluster"* ]] || [[ "$test_name" == *"namespace"* ]]; then
            category="Prerequisites"
        elif [[ "$test_name" == *"PVC"* ]] || [[ "$test_name" == *"storage"* ]]; then
            category="Infrastructure"
        elif [[ "$test_name" == *"health"* ]] || [[ "$test_name" == *"deployment"* ]]; then
            category="Services"
        elif [[ "$test_name" == *"GPU"* ]] || [[ "$test_name" == *"gpu"* ]]; then
            category="GPU"
        elif [[ "$test_name" == *"integration"* ]] || [[ "$test_name" == *"communication"* ]]; then
            category="Integration"
        elif [[ "$test_name" == *"workflow"* ]] || [[ "$test_name" == *"generation"* ]]; then
            category="E2E"
        elif [[ "$test_name" == *"Ingress"* ]] || [[ "$test_name" == *"external"* ]]; then
            category="Ingress"
        elif [[ "$test_name" == *"Prometheus"* ]] || [[ "$test_name" == *"Grafana"* ]]; then
            category="Monitoring"
        elif [[ "$test_name" == *"CPU"* ]] || [[ "$test_name" == *"fallback"* ]]; then
            category="CPU Fallback"
        elif [[ "$test_name" == *"response"* ]] || [[ "$test_name" == *"utilization"* ]]; then
            category="Performance"
        fi
        
        echo "            <tr>" >> "$report_file"
        echo "                <td>$category</td>" >> "$report_file"
        echo "                <td>$test_name</td>" >> "$report_file"
        echo "                <td class=\"$result\">$result</td>" >> "$report_file"
        echo "                <td>Details in log file</td>" >> "$report_file"
        echo "            </tr>" >> "$report_file"
    done < "$TEST_RESULTS_DIR/results.txt"
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>System Information</h2>
        <pre>
$(kubectl version --short 2>&1)
$(kubectl get nodes -o wide 2>&1)
$(kubectl get pods -n $NAMESPACE 2>&1)
        </pre>
    </div>
</body>
</html>
EOF
    
    print_status "success" "Comprehensive test report generated: $report_file"
}

# Function to show final results
show_final_results() {
    print_status "header" "🎯 Final Test Results"
    echo "=========================================================="
    
    # Count results
    local total_tests=$(wc -l < "$TEST_RESULTS_DIR/results.txt")
    local passed_tests=$(grep -c 'PASSED' "$TEST_RESULTS_DIR/results.txt")
    local failed_tests=$(grep -c 'FAILED' "$TEST_RESULTS_DIR/results.txt")
    
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo ""
    
    if [[ $failed_tests -eq 0 ]]; then
        print_status "highlight" "🌟 All tests passed!"
        echo ""
        echo "Your Local Voice AI Kubernetes deployment is healthy and ready to use."
        echo ""
        echo "Access URLs:"
        echo "🌐 Frontend: http://localhost:30080"
        echo "📊 Grafana: http://localhost:30030 (admin/admin123)"
        echo "📈 Prometheus: http://localhost:30090"
        echo ""
        print_status "performance" "🚀 Enjoy the power of GPU acceleration!"
        return 0
    else
        print_status "error" "❌ $failed_tests test(s) failed"
        echo ""
        echo "Please check the detailed test results:"
        echo "1. Test log: $TEST_LOG"
        echo "2. Test report: $TEST_RESULTS_DIR/complete-test-report-$TIMESTAMP.html"
        echo "3. Results file: $TEST_RESULTS_DIR/results.txt"
        echo ""
        echo "Common fixes:"
        echo "1. Restart failed services: kubectl rollout restart deployment/<service> -n $NAMESPACE"
        echo "2. Check pod logs: kubectl logs -f deployment/<service> -n $NAMESPACE"
        echo "3. Verify GPU availability: kubectl describe nodes"
        echo "4. Check storage: kubectl get pvc -n $NAMESPACE"
        echo "5. Run comprehensive verification: ./kubernetes/scripts/verify-deployment.sh"
        echo ""
        return 1
    fi
}

# Main test execution
main() {
    print_status "header" "🧪 Local Voice AI - Complete Kubernetes Deployment Test"
    echo "=========================================================="
    echo ""
    echo "This script will perform comprehensive tests on your complete"
    echo "Kubernetes deployment of Local Voice AI with GPU acceleration."
    echo ""
    echo "Test log: $TEST_LOG"
    echo "Test results: $TEST_RESULTS_DIR/results.txt"
    echo ""
    
    # Initialize results file
    echo "# Complete Test Results - $(date)" > "$TEST_RESULTS_DIR/results.txt"
    
    # Track overall success
    local all_passed=true
    
    # Run all test categories
    test_prerequisites || all_passed=false
    echo ""
    
    test_infrastructure || all_passed=false
    echo ""
    
    test_ai_services || all_passed=false
    echo ""
    
    test_supporting_services || all_passed=false
    echo ""
    
    test_gpu_functionality || all_passed=false
    echo ""
    
    test_service_integration || all_passed=false
    echo ""
    
    test_end_to_end_workflow || all_passed=false
    echo ""
    
    test_ingress_external_access || all_passed=false
    echo ""
    
    test_monitoring || all_passed=false
    echo ""
    
    test_cpu_fallback || all_passed=false
    echo ""
    
    test_performance || all_passed=false
    echo ""
    
    # Generate comprehensive report
    generate_comprehensive_report
    
    # Show final results
    if [[ "$all_passed" == "true" ]]; then
        show_final_results
        exit 0
    else
        show_final_results
        exit 1
    fi
}

# Handle script interruption
trap 'print_status "warning" "Testing interrupted by user"; exit 130' INT

# Run main function
main "$@"