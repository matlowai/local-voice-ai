#!/bin/bash

# Comprehensive Testing Script for Kubernetes Deployment
# Tests all aspects of the Local Voice AI Kubernetes deployment

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
TEST_LOG="$TEST_RESULTS_DIR/test-$TIMESTAMP.log"

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

# Function to test cluster connectivity
test_cluster_connectivity() {
    print_status "header" "🔍 Testing Cluster Connectivity"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test kubectl connectivity
    run_test "kubectl connectivity" "$KUBECTL cluster-info" || all_passed=false
    
    # Test namespace existence
    run_test "namespace existence" "$KUBECTL get namespace $NAMESPACE" || all_passed=false
    
    # Test node readiness
    run_test "node readiness" "$KUBECTL get nodes --field-selector=status.conditions[?(@.type=='Ready')].status=True" || all_passed=false
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Cluster connectivity tests passed"
        return 0
    else
        print_status "error" "Some cluster connectivity tests failed"
        return 1
    fi
}

# Function to test GPU availability
test_gpu_availability() {
    print_status "header" "🎮 Testing GPU Availability"
    echo "=========================================================="
    
    local all_passed=true
    
    # Check if GPU nodes are available
    run_test "GPU node availability" "$KUBECTL get nodes '-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu' | grep -v '<none>' | grep -v 'GPU' | wc -l | grep -q '^ *[1-9]'" || all_passed=false
    
    # Check GPU device plugin
    run_test "GPU device plugin" "$KUBECTL get pods -n gpu-operator -l app.kubernetes.io/component=nvidia-device-plugin-daemonset | grep -q 'Running'" || all_passed=false
    
    # Test GPU functionality in pods
    if $KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running | grep -q "ollama"; then
        local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
        run_test "GPU functionality" "$KUBECTL exec -n $NAMESPACE $ollama_pod -- nvidia-smi" || all_passed=false
    else
        print_status "warning" "No running Ollama pod found for GPU test"
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "GPU availability tests passed"
        return 0
    else
        print_status "error" "Some GPU availability tests failed"
        return 1
    fi
}

# Function to test service deployment
test_service_deployment() {
    print_status "header" "🚀 Testing Service Deployment"
    echo "=========================================================="
    
    local all_passed=true
    local services=("ollama" "whisper" "kokoro" "agent" "livekit" "frontend")
    
    for service in "${services[@]}"; do
        # Test pod deployment
        run_test "$service pod deployment" "$KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running | grep -q '$service'" || all_passed=false
        
        # Test service creation
        run_test "$service service creation" "$KUBECTL get svc -n $NAMESPACE -l app.kubernetes.io/name=$service | grep -q '$service'" || all_passed=false
        
        # Test pod readiness
        local pod_count=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --no-headers | wc -l)
        local ready_count=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service --field-selector=status.phase=Running --no-headers | wc -l)
        
        if [[ $ready_count -eq $pod_count && $pod_count -gt 0 ]]; then
            print_status "success" "$service: $ready_count/$pod_count pods ready"
        else
            print_status "error" "$service: $ready_count/$pod_count pods ready"
            all_passed=false
        fi
    done
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Service deployment tests passed"
        return 0
    else
        print_status "error" "Some service deployment tests failed"
        return 1
    fi
}

# Function to test service connectivity
test_service_connectivity() {
    print_status "header" "🌐 Testing Service Connectivity"
    echo "=========================================================="
    
    local all_passed=true
    local services=("ollama:11434" "whisper:80" "kokoro:8880" "agent:8080" "livekit:7880" "frontend:3000")
    
    for service_info in "${services[@]}"; do
        local service_name=$(echo $service_info | cut -d':' -f1)
        local service_port=$(echo $service_info | cut -d':' -f2)
        
        # Get a running pod for the service
        local pod_name=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$service_name --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [[ -n "$pod_name" ]]; then
            # Test internal connectivity
            run_test "$service_name internal connectivity" "$KUBECTL exec -n $NAMESPACE $pod_name -- curl -s --connect-timeout 5 http://localhost:$service_port" || all_passed=false
        else
            print_status "error" "$service_name: No running pod found"
            all_passed=false
        fi
    done
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Service connectivity tests passed"
        return 0
    else
        print_status "error" "Some service connectivity tests failed"
        return 1
    fi
}

# Function to test AI service functionality
test_ai_service_functionality() {
    print_status "header" "🧠 Testing AI Service Functionality"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test Ollama API
    local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$ollama_pod" ]]; then
        run_test "Ollama API health" "$KUBECTL exec -n $NAMESPACE $ollama_pod -- curl -s http://localhost:11434/api/tags" || all_passed=false
        
        # Test model availability
        run_test "Ollama model availability" "$KUBECTL exec -n $NAMESPACE $ollama_pod -- curl -s http://localhost:11434/api/tags | jq -e '.models | length > 0'" || all_passed=false
    else
        print_status "error" "No running Ollama pod found"
        all_passed=false
    fi
    
    # Test Whisper API
    local whisper_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=whisper --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$whisper_pod" ]]; then
        run_test "Whisper API health" "$KUBECTL exec -n $NAMESPACE $whisper_pod -- curl -s http://localhost:80/health" || all_passed=false
    else
        print_status "error" "No running Whisper pod found"
        all_passed=false
    fi
    
    # Test Kokoro API
    local kokoro_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=kokoro --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$kokoro_pod" ]]; then
        run_test "Kokoro API health" "$KUBECTL exec -n $NAMESPACE $kokoro_pod -- curl -s http://localhost:8880/health" || all_passed=false
    else
        print_status "error" "No running Kokoro pod found"
        all_passed=false
    fi
    
    # Test Agent API
    local agent_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=agent --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$agent_pod" ]]; then
        run_test "Agent API health" "$KUBECTL exec -n $NAMESPACE $agent_pod -- curl -s http://localhost:8080/health" || all_passed=false
    else
        print_status "error" "No running Agent pod found"
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "AI service functionality tests passed"
        return 0
    else
        print_status "error" "Some AI service functionality tests failed"
        return 1
    fi
}

# Function to test end-to-end workflow
test_end_to_end_workflow() {
    print_status "header" "🔄 Testing End-to-End Workflow"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test text-to-speech workflow
    print_status "info" "Testing TTS workflow..."
    local kokoro_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=kokoro --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$kokoro_pod" ]]; then
        # Generate speech
        run_test "TTS generation" "$KUBECTL exec -n $NAMESPACE $kokoro_pod -- curl -s -X POST http://localhost:8880/tts -H 'Content-Type: application/json' -d '{\"text\":\"Hello world\"}' | grep -q 'audio_url'" || all_passed=false
    else
        print_status "error" "No running Kokoro pod found for TTS test"
        all_passed=false
    fi
    
    # Test LLM generation workflow
    print_status "info" "Testing LLM workflow..."
    local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$ollama_pod" ]]; then
        # Generate text
        run_test "LLM generation" "$KUBECTL exec -n $NAMESPACE $ollama_pod -- curl -s -X POST http://localhost:11434/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"gemma3:4b\",\"prompt\":\"Hello\",\"stream\":false}' | grep -q 'response'" || all_passed=false
    else
        print_status "error" "No running Ollama pod found for LLM test"
        all_passed=false
    fi
    
    # Test Agent workflow
    print_status "info" "Testing Agent workflow..."
    local agent_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=agent --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$agent_pod" ]]; then
        # Test agent health
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

# Function to test performance
test_performance() {
    print_status "header" "⚡ Testing Performance"
    echo "=========================================================="
    
    local all_passed=true
    
    # Test GPU performance
    print_status "info" "Testing GPU performance..."
    local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$ollama_pod" ]]; then
        # Check GPU utilization
        local gpu_util=$($KUBECTL exec -n $NAMESPACE $ollama_pod -- nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "0")
        if [[ $gpu_util -gt 0 ]]; then
            print_status "success" "GPU utilization: ${gpu_util}%"
        else
            print_status "warning" "GPU utilization: ${gpu_util}% (GPU may be idle)"
        fi
        
        # Check GPU memory usage
        local gpu_memory=$($KUBECTL exec -n $NAMESPACE $ollama_pod -- nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "0,0")
        local used_memory=$(echo $gpu_memory | cut -d',' -f1)
        local total_memory=$(echo $gpu_memory | cut -d',' -f2)
        if [[ $used_memory -gt 0 && $total_memory -gt 0 ]]; then
            local memory_usage=$((used_memory * 100 / total_memory))
            print_status "success" "GPU memory usage: ${memory_usage}% ($used_memory/$total_memory MB)"
        else
            print_status "warning" "GPU memory usage: Could not determine"
        fi
    else
        print_status "error" "No running Ollama pod found for GPU performance test"
        all_passed=false
    fi
    
    # Test response times
    print_status "info" "Testing response times..."
    local ollama_pod=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$ollama_pod" ]]; then
        # Test LLM response time
        local start_time=$(date +%s.%N)
        $KUBECTL exec -n $NAMESPACE $ollama_pod -- curl -s -X POST http://localhost:11434/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"gemma3:4b\",\"prompt\":\"Hello\",\"stream\":false}' > /dev/null
        local end_time=$(date +%s.%N)
        local response_time=$(echo "$end_time - $start_time" | bc)
        
        # Convert to milliseconds
        local response_time_ms=$(echo "$response_time * 1000" | bc)
        
        if (( $(echo "$response_time_ms < 5000" | bc -l) )); then
            print_status "success" "LLM response time: ${response_time_ms}ms"
        else
            print_status "warning" "LLM response time: ${response_time_ms}ms (slower than expected)"
        fi
    else
        print_status "error" "No running Ollama pod found for response time test"
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Performance tests passed"
        return 0
    else
        print_status "error" "Some performance tests failed"
        return 1
    fi
}

# Function to test storage
test_storage() {
    print_status "header" "💾 Testing Storage"
    echo "=========================================================="
    
    local all_passed=true
    local pvcs=("ollama-storage" "whisper-storage" "kokoro-storage" "agent-storage" "temp-storage")
    
    for pvc in "${pvcs[@]}"; do
        # Test PVC existence
        run_test "$pvc existence" "$KUBECTL get pvc $pvc -n $NAMESPACE" || all_passed=false
        
        # Test PVC status
        local pvc_status=$($KUBECTL get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [[ "$pvc_status" == "Bound" ]]; then
            print_status "success" "$pvc: $pvc_status"
        else
            print_status "error" "$pvc: $pvc_status"
            all_passed=false
        fi
        
        # Test PVC mount in pods
        local pod_name=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=$(echo $pvc | sed 's/-storage//') --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [[ -n "$pod_name" ]]; then
            run_test "$pvc mount in pod" "$KUBECTL exec -n $NAMESPACE $pod_name -- df | grep -q '/data'" || all_passed=false
        else
            print_status "warning" "No running pod found to test $pvc mount"
        fi
    done
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Storage tests passed"
        return 0
    else
        print_status "error" "Some storage tests failed"
        return 1
    fi
}

# Function to test CPU fallback
test_cpu_fallback() {
    print_status "header" "🔄 Testing CPU Fallback"
    echo "=========================================================="
    
    local all_passed=true
    
    # Check if CPU deployments exist
    run_test "CPU Ollama deployment" "$KUBECTL get deployment ollama-cpu -n $NAMESPACE" || all_passed=false
    run_test "CPU Whisper deployment" "$KUBECTL get deployment whisper-cpu -n $NAMESPACE" || all_passed=false
    run_test "CPU Kokoro deployment" "$KUBECTL get deployment kokoro-cpu -n $NAMESPACE" || all_passed=false
    run_test "CPU Agent deployment" "$KUBECTL get deployment agent-cpu -n $NAMESPACE" || all_passed=false
    
    # Test switch script
    run_test "Switch script availability" "test -f $SCRIPT_DIR/switch-to-cpu.sh" || all_passed=false
    
    # Test switch script functionality
    run_test "Switch script functionality" "$SCRIPT_DIR/switch-to-cpu.sh status" || all_passed=false
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "CPU fallback tests passed"
        return 0
    else
        print_status "error" "Some CPU fallback tests failed"
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

# Function to generate test report
generate_test_report() {
    print_status "header" "📋 Generating Test Report"
    echo "=========================================================="
    
    local report_file="$TEST_RESULTS_DIR/test-report-$TIMESTAMP.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Local Voice AI - Kubernetes Test Report</title>
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
    </style>
</head>
<body>
    <div class="header">
        <h1>Local Voice AI - Kubernetes Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Test Log: $TEST_LOG</p>
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
        <h2>Test Results</h2>
        <table>
            <tr>
                <th>Test Name</th>
                <th>Result</th>
                <th>Details</th>
            </tr>
EOF
    
    # Add test results to report
    while IFS= read -r line; do
        local result=$(echo "$line" | cut -d':' -f1)
        local test_name=$(echo "$line" | cut -d':' -f2-)
        
        echo "            <tr>" >> "$report_file"
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
    
    print_status "success" "Test report generated: $report_file"
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
        print_status "performance" "🚀 Enjoy the power of GPU acceleration!"
        return 0
    else
        print_status "error" "❌ $failed_tests test(s) failed"
        echo ""
        echo "Please check the detailed test results:"
        echo "1. Test log: $TEST_LOG"
        echo "2. Test report: $TEST_RESULTS_DIR/test-report-$TIMESTAMP.html"
        echo "3. Results file: $TEST_RESULTS_DIR/results.txt"
        echo ""
        echo "Common fixes:"
        echo "1. Restart failed services: kubectl rollout restart deployment/<service> -n $NAMESPACE"
        echo "2. Check pod logs: kubectl logs -f deployment/<service> -n $NAMESPACE"
        echo "3. Verify GPU availability: kubectl describe nodes"
        echo "4. Check storage: kubectl get pvc -n $NAMESPACE"
        echo ""
        return 1
    fi
}

# Main test execution
main() {
    local test_category=${1:-"all"}
    
    print_status "header" "🧪 Local Voice AI - Kubernetes Test Suite"
    echo "=========================================================="
    echo ""
    echo "This script will perform comprehensive tests on your Kubernetes"
    echo "deployment of Local Voice AI with GPU acceleration."
    echo ""
    echo "Test log: $TEST_LOG"
    echo "Test results: $TEST_RESULTS_DIR/results.txt"
    echo ""
    
    # Initialize results file
    echo "# Test Results - $(date)" > "$TEST_RESULTS_DIR/results.txt"
    
    # Track overall success
    local all_passed=true
    
    # Run tests based on category
    case $test_category in
        "connectivity")
            test_cluster_connectivity || all_passed=false
            ;;
        "gpu")
            test_gpu_availability || all_passed=false
            ;;
        "deployment")
            test_service_deployment || all_passed=false
            ;;
        "connectivity")
            test_service_connectivity || all_passed=false
            ;;
        "functionality")
            test_ai_service_functionality || all_passed=false
            ;;
        "e2e")
            test_end_to_end_workflow || all_passed=false
            ;;
        "performance")
            test_performance || all_passed=false
            ;;
        "storage")
            test_storage || all_passed=false
            ;;
        "fallback")
            test_cpu_fallback || all_passed=false
            ;;
        "monitoring")
            test_monitoring || all_passed=false
            ;;
        "all")
            test_cluster_connectivity || all_passed=false
            echo ""
            test_gpu_availability || all_passed=false
            echo ""
            test_service_deployment || all_passed=false
            echo ""
            test_service_connectivity || all_passed=false
            echo ""
            test_ai_service_functionality || all_passed=false
            echo ""
            test_end_to_end_workflow || all_passed=false
            echo ""
            test_performance || all_passed=false
            echo ""
            test_storage || all_passed=false
            echo ""
            test_cpu_fallback || all_passed=false
            echo ""
            test_monitoring || all_passed=false
            ;;
        *)
            echo "Usage: $0 {all|connectivity|gpu|deployment|connectivity|functionality|e2e|performance|storage|fallback|monitoring}"
            exit 1
            ;;
    esac
    
    # Generate test report
    generate_test_report
    
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