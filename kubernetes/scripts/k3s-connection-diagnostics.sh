#!/bin/bash

# K3s Connection Diagnostics and Auto-Fix Script
# Comprehensive K3s connection troubleshooting with automatic fixes

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
K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
USER_KUBECONFIG="$HOME/.kube/config"
KUBECONFIG_DIR="$HOME/.kube"
NAMESPACE="voice-ai"

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
        "fix")
            echo -e "${CYAN}🔧 $message${NC}"
            ;;
    esac
}

# Function to check K3s service status
check_k3s_service() {
    print_status "header" "🔍 Checking K3s Service Status"
    echo "=========================================================="
    
    local all_passed=true
    
    # Check if k3s binary exists
    if command -v k3s &> /dev/null; then
        print_status "success" "K3s binary found: $(which k3s)"
    else
        print_status "error" "K3s binary not found in PATH"
        all_passed=false
    fi
    
    # Check if k3s service is running
    if sudo systemctl is-active --quiet k3s; then
        print_status "success" "K3s service is running"
        
        # Get service uptime
        local uptime=$(sudo systemctl show k3s --property=ActiveEnterTimestamp --value)
        print_status "info" "K3s service uptime: Since $uptime"
        
        # Check service status details
        local status=$(sudo systemctl is-active k3s)
        local enabled=$(sudo systemctl is-enabled k3s)
        print_status "info" "Service status: $status (enabled: $enabled)"
        
    else
        print_status "error" "K3s service is not running"
        all_passed=false
        
        # Show service status for debugging
        print_status "info" "Service status details:"
        sudo systemctl status k3s --no-pager -l --lines=5 || true
    fi
    
    # Check k3s process
    if pgrep -f "k3s server" > /dev/null; then
        print_status "success" "K3s server process is running"
        local pid=$(pgrep -f "k3s server")
        print_status "info" "K3s server PID: $pid"
    else
        print_status "error" "K3s server process not found"
        all_passed=false
    fi
    
    # Check critical ports
    local ports=("6443" "10250")
    for port in "${ports[@]}"; do
        if sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            print_status "success" "K3s port $port is listening"
        else
            print_status "error" "K3s port $port is not listening"
            all_passed=false
        fi
    done
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "K3s service checks passed"
        return 0
    else
        print_status "error" "K3s service checks failed"
        return 1
    fi
}

# Function to check and fix kubeconfig
check_and_fix_kubeconfig() {
    print_status "header" "🔧 Checking and Fixing Kubeconfig"
    echo "=========================================================="
    
    local all_passed=true
    local needs_fix=false
    
    # Check source kubeconfig exists
    if [[ -f "$K3S_KUBECONFIG" ]]; then
        print_status "success" "Source kubeconfig exists: $K3S_KUBECONFIG"
    else
        print_status "error" "Source kubeconfig not found: $K3S_KUBECONFIG"
        all_passed=false
        return 1
    fi
    
    # Check user kubeconfig directory
    if [[ -d "$KUBECONFIG_DIR" ]]; then
        print_status "success" "Kubeconfig directory exists: $KUBECONFIG_DIR"
    else
        print_status "warning" "Kubeconfig directory not found, creating..."
        mkdir -p "$KUBECONFIG_DIR"
        needs_fix=true
    fi
    
    # Check user kubeconfig file
    if [[ -f "$USER_KUBECONFIG" ]]; then
        print_status "success" "User kubeconfig exists: $USER_KUBECONFIG"
        
        # Check permissions
        local perms=$(stat -c "%a" "$USER_KUBECONFIG" 2>/dev/null || echo "unknown")
        if [[ "$perms" == "600" ]]; then
            print_status "success" "Kubeconfig permissions are correct (600)"
        else
            print_status "warning" "Kubeconfig permissions are $perms, should be 600"
            needs_fix=true
        fi
        
        # Check ownership
        local owner=$(stat -c "%U:%G" "$USER_KUBECONFIG" 2>/dev/null || echo "unknown")
        local expected_owner="$(id -u):$(id -g)"
        if [[ "$owner" == "$expected_owner" ]]; then
            print_status "success" "Kubeconfig ownership is correct ($owner)"
        else
            print_status "warning" "Kubeconfig ownership is $owner, should be $expected_owner"
            needs_fix=true
        fi
        
    else
        print_status "warning" "User kubeconfig not found, will create"
        needs_fix=true
    fi
    
    # Check if kubeconfig is functional
    if KUBECONFIG="$USER_KUBECONFIG" kubectl cluster-info &> /dev/null; then
        print_status "success" "Kubeconfig is functional"
    else
        print_status "error" "Kubeconfig is not functional"
        needs_fix=true
        all_passed=false
    fi
    
    # Apply fixes if needed
    if [[ "$needs_fix" == "true" ]]; then
        print_status "fix" "Applying kubeconfig fixes..."
        
        # Copy kubeconfig from source
        print_status "info" "Copying kubeconfig from K3s..."
        sudo cp "$K3S_KUBECONFIG" "$USER_KUBECONFIG"
        
        # Fix ownership
        print_status "info" "Setting correct ownership..."
        sudo chown "$(id -u):$(id -g)" "$USER_KUBECONFIG"
        
        # Fix permissions
        print_status "info" "Setting correct permissions..."
        chmod 600 "$USER_KUBECONFIG"
        
        # Update server URL if needed (localhost to 127.0.0.1)
        print_status "info" "Updating server URL for local access..."
        sed -i 's/server: https:\/\/localhost:6443/server: https:\/\/127.0.0.1:6443/' "$USER_KUBECONFIG" || true
        
        # Test the fixed kubeconfig
        if KUBECONFIG="$USER_KUBECONFIG" kubectl cluster-info &> /dev/null; then
            print_status "success" "Kubeconfig fixed and is now functional"
        else
            print_status "error" "Kubeconfig fix failed"
            all_passed=false
        fi
    fi
    
    # Check KUBECONFIG environment variable
    if [[ -n "$KUBECONFIG" ]]; then
        print_status "info" "KUBECONFIG environment variable is set: $KUBECONFIG"
    else
        print_status "warning" "KUBECONFIG environment variable not set"
        print_status "info" "Setting KUBECONFIG to $USER_KUBECONFIG"
        export KUBECONFIG="$USER_KUBECONFIG"
        
        # Add to .bashrc for persistence
        if ! grep -q "export KUBECONFIG=" ~/.bashrc; then
            echo "export KUBECONFIG=\"$USER_KUBECONFIG\"" >> ~/.bashrc
            print_status "info" "Added KUBECONFIG to ~/.bashrc"
        fi
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "Kubeconfig checks passed"
        return 0
    else
        print_status "error" "Kubeconfig checks failed"
        return 1
    fi
}

# Function to test kubectl connectivity
test_kubectl_connectivity() {
    print_status "header" "🌐 Testing kubectl Connectivity"
    echo "=========================================================="
    
    local all_passed=true
    
    # Ensure KUBECONFIG is set
    export KUBECONFIG="${KUBECONFIG:-$USER_KUBECONFIG}"
    
    # Test basic cluster info
    print_status "info" "Testing cluster connectivity..."
    if kubectl cluster-info &> /dev/null; then
        print_status "success" "kubectl can connect to cluster"
        
        # Show cluster info
        local cluster_info=$(kubectl cluster-info 2>/dev/null | head -3)
        print_status "info" "Cluster info: $cluster_info"
    else
        print_status "error" "kubectl cannot connect to cluster"
        all_passed=false
        
        # Show error details
        local error_output=$(kubectl cluster-info 2>&1 | head -3)
        print_status "error" "Connection error: $error_output"
    fi
    
    # Test node access
    print_status "info" "Testing node access..."
    if kubectl get nodes &> /dev/null; then
        local node_count=$(kubectl get nodes --no-headers | wc -l)
        print_status "success" "Can access $node_count node(s)"
        
        # Check node status
        local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
        if [[ $ready_nodes -eq $node_count ]]; then
            print_status "success" "All nodes are ready"
        else
            print_status "warning" "$ready_nodes/$node_count nodes are ready"
        fi
        
        # Show node details
        local node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$node_name" ]]; then
            print_status "info" "Node name: $node_name"
            
            # Check node conditions
            local node_ready=$(kubectl get node "$node_name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [[ "$node_ready" == "True" ]]; then
                print_status "success" "Node is ready"
            else
                print_status "warning" "Node readiness: $node_ready"
            fi
        fi
    else
        print_status "error" "Cannot access nodes"
        all_passed=false
    fi
    
    # Test API server health
    print_status "info" "Testing API server health..."
    if kubectl get --raw='/healthz' &> /dev/null; then
        print_status "success" "API server is healthy"
    else
        print_status "error" "API server health check failed"
        all_passed=false
    fi
    
    # Test namespace access
    print_status "info" "Testing namespace access..."
    if kubectl get namespaces &> /dev/null; then
        local ns_count=$(kubectl get namespaces --no-headers | wc -l)
        print_status "success" "Can access $ns_count namespace(s)"
    else
        print_status "error" "Cannot access namespaces"
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "kubectl connectivity tests passed"
        return 0
    else
        print_status "error" "kubectl connectivity tests failed"
        return 1
    fi
}

# Function to run comprehensive diagnostics
run_comprehensive_diagnostics() {
    print_status "header" "🔍 Running Comprehensive K3s Diagnostics"
    echo "=========================================================="
    echo ""
    
    local overall_success=true
    
    # Run all diagnostic checks
    check_k3s_service || overall_success=false
    echo ""
    
    check_and_fix_kubeconfig || overall_success=false
    echo ""
    
    test_kubectl_connectivity || overall_success=false
    echo ""
    
    # Show overall result
    if [[ "$overall_success" == "true" ]]; then
        print_status "highlight" "🌟 All diagnostics passed! K3s connection is working properly."
        return 0
    else
        print_status "error" "❌ Some diagnostics failed. See details above for troubleshooting."
        return 1
    fi
}

# Function to show troubleshooting steps
show_troubleshooting_steps() {
    print_status "header" "📋 Troubleshooting Steps"
    echo "=========================================================="
    echo ""
    
    echo "If you're still experiencing connection issues, try these steps:"
    echo ""
    
    echo "1. Restart K3s service:"
    echo "   sudo systemctl restart k3s"
    echo "   sudo systemctl status k3s"
    echo ""
    
    echo "2. Check K3s logs:"
    echo "   sudo journalctl -u k3s -f --lines=50"
    echo ""
    
    echo "3. Verify kubeconfig manually:"
    echo "   export KUBECONFIG=\"$USER_KUBECONFIG\""
    echo "   kubectl cluster-info"
    echo ""
    
    echo "4. Check network connectivity:"
    echo "   curl -k https://127.0.0.1:6443/healthz"
    echo ""
    
    echo "5. Check firewall settings:"
    echo "   sudo ufw status"
    echo "   sudo iptables -L | grep 6443"
    echo ""
    
    echo "6. Reinstall K3s if needed:"
    echo "   sudo /usr/local/bin/k3s-uninstall.sh"
    echo "   curl -sfL https://get.k3s.io | sh -"
    echo ""
    
    echo "7. Check system resources:"
    echo "   free -h"
    echo "   df -h"
    echo "   ps aux | grep k3s"
    echo ""
}

# Function to show connection summary
show_connection_summary() {
    print_status "header" "📊 Connection Summary"
    echo "=========================================================="
    echo ""
    
    export KUBECONFIG="${KUBECONFIG:-$USER_KUBECONFIG}"
    
    echo "K3s Status:"
    echo "----------------------------------------"
    if sudo systemctl is-active --quiet k3s; then
        echo "✅ Service: Running"
        local uptime=$(sudo systemctl show k3s --property=ActiveEnterTimestamp --value)
        echo "📅 Uptime: $uptime"
    else
        echo "❌ Service: Not running"
    fi
    echo ""
    
    echo "Kubeconfig:"
    echo "----------------------------------------"
    echo "📁 Location: $USER_KUBECONFIG"
    echo "🔧 KUBECONFIG: ${KUBECONFIG:-Not set}"
    if [[ -f "$USER_KUBECONFIG" ]]; then
        local perms=$(stat -c "%a" "$USER_KUBECONFIG" 2>/dev/null || echo "unknown")
        local owner=$(stat -c "%U:%G" "$USER_KUBECONFIG" 2>/dev/null || echo "unknown")
        echo "🔒 Permissions: $perms"
        echo "👤 Ownership: $owner"
    fi
    echo ""
    
    echo "Cluster Info:"
    echo "----------------------------------------"
    if kubectl cluster-info &> /dev/null; then
        echo "✅ Connection: Working"
        local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        echo "🖥️  Nodes: $node_count"
        local ns_count=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l)
        echo "📂 Namespaces: $ns_count"
    else
        echo "❌ Connection: Failed"
    fi
    echo ""
}

# Main function
main() {
    local action=${1:-"diagnose"}
    
    case $action in
        "diagnose")
            run_comprehensive_diagnostics
            ;;
        "summary")
            show_connection_summary
            ;;
        "troubleshoot")
            show_troubleshooting_steps
            ;;
        "fix-kubeconfig")
            check_and_fix_kubeconfig
            ;;
        "test-connectivity")
            test_kubectl_connectivity
            ;;
        "check-service")
            check_k3s_service
            ;;
        *)
            echo "Usage: $0 {diagnose|summary|troubleshoot|fix-kubeconfig|test-connectivity|check-service}"
            echo ""
            echo "Actions:"
            echo "  diagnose        - Run comprehensive diagnostics (default)"
            echo "  summary         - Show connection summary"
            echo "  troubleshoot    - Show troubleshooting steps"
            echo "  fix-kubeconfig  - Fix kubeconfig issues"
            echo "  test-connectivity - Test kubectl connectivity"
            echo "  check-service   - Check K3s service status"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'print_status "warning" "Diagnostics interrupted by user"; exit 130' INT

# Run main function
main "$@"