#!/bin/bash

# Quick K3s Connection Check Script
# Fast verification of K3s connection status

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIAGNOSTICS_SCRIPT="$SCRIPT_DIR/k3s-connection-diagnostics.sh"

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

# Function to quick check K3s connection
quick_check() {
    print_status "header" "⚡ Quick K3s Connection Check"
    echo "=============================================="
    echo ""
    
    local all_passed=true
    
    # Check K3s service
    print_status "info" "Checking K3s service..."
    if sudo systemctl is-active --quiet k3s; then
        print_status "success" "K3s service is running"
    else
        print_status "error" "K3s service is not running"
        all_passed=false
    fi
    
    # Check kubectl availability
    print_status "info" "Checking kubectl..."
    if command -v kubectl &> /dev/null; then
        print_status "success" "kubectl is available"
    else
        print_status "error" "kubectl is not available"
        all_passed=false
    fi
    
    # Check kubeconfig
    print_status "info" "Checking kubeconfig..."
    export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
    if [[ -f "$KUBECONFIG" ]]; then
        print_status "success" "kubeconfig found at $KUBECONFIG"
    else
        print_status "error" "kubeconfig not found"
        all_passed=false
    fi
    
    # Test cluster connection
    print_status "info" "Testing cluster connection..."
    if kubectl cluster-info &> /dev/null; then
        print_status "success" "Cluster connection is working"
        
        # Get basic info
        local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        local ns_count=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l)
        print_status "info" "Cluster has $node_count node(s) and $ns_count namespace(s)"
    else
        print_status "error" "Cannot connect to cluster"
        all_passed=false
    fi
    
    echo ""
    
    # Show result
    if [[ "$all_passed" == "true" ]]; then
        print_status "success" "🎉 K3s connection is working properly!"
        echo ""
        echo "You can now run your deployment scripts:"
        echo "  ./kubernetes/scripts/deploy-gpu.sh"
        return 0
    else
        print_status "error" "❌ K3s connection has issues"
        echo ""
        print_status "info" "Running comprehensive diagnostics..."
        
        # Run full diagnostics if available
        if [[ -f "$DIAGNOSTICS_SCRIPT" ]]; then
            echo ""
            bash "$DIAGNOSTICS_SCRIPT" diagnose
        else
            print_status "warning" "Diagnostics script not found"
            print_status "info" "Manual troubleshooting:"
            echo "1. Check service: sudo systemctl status k3s"
            echo "2. Check logs: sudo journalctl -u k3s -f"
            echo "3. Check kubeconfig: ls -la ~/.kube/config"
            echo "4. Test connection: kubectl cluster-info"
        fi
        
        return 1
    fi
}

# Main function
main() {
    local action=${1:-"check"}
    
    case $action in
        "check")
            quick_check
            ;;
        *)
            echo "Usage: $0 [check]"
            echo ""
            echo "Quick K3s connection check script"
            echo "Default action: check"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'print_status "warning" "Check interrupted by user"; exit 130' INT

# Run main function
main "$@"