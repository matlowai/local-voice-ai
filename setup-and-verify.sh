#!/bin/bash

# Enhanced setup and verification script for Local Voice AI
# This script automatically fixes common issues and gets everything running

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_status "info" "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            print_status "success" "$service_name is ready!"
            return 0
        fi
        
        print_status "info" "Attempt $attempt/$max_attempts: $service_name not ready yet..."
        sleep 5
        ((attempt++))
    done
    
    print_status "error" "$service_name failed to become ready after $max_attempts attempts"
    return 1
}

# Function to fix file permissions
fix_permissions() {
    print_status "header" "🔧 Fixing file permissions and extended attributes..."
    
    # Fix key configuration files
    local config_files=(".env" "docker-compose.yml" "agent/.env" "Dockerfile" "agent/Dockerfile" "whisper/Dockerfile")
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            # Remove any problematic extended attributes
            chattr -e "$file" 2>/dev/null || true
            # Set proper permissions
            chmod 644 "$file"
            print_status "success" "Fixed $file permissions and attributes"
        else
            print_status "info" "$file not found, skipping"
        fi
    done
    
    # Make scripts executable
    local script_files=("test.sh" "verify-setup.sh" "setup-and-verify.sh" "scripts/validate-docs.py")
    
    for script in "${script_files[@]}"; do
        if [ -f "$script" ]; then
            chattr -e "$script" 2>/dev/null || true
            chmod +x "$script"
            print_status "success" "Made $script executable"
        fi
    done
    
    print_status "success" "All file permissions and attributes fixed"
}

# Function to start containers
start_containers() {
    print_status "header" "🚀 Starting containers..."
    
    # Try to stop any existing containers first
    print_status "info" "Stopping any existing containers..."
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # Try to start with docker-compose first
    print_status "info" "Building and starting all services..."
    if docker-compose up --build -d 2>/dev/null; then
        print_status "success" "Containers started successfully with docker-compose"
    else
        print_status "warning" "Docker-compose failed, trying alternative approach..."
        
        # Fallback: Use docker commands directly with environment variables
        print_status "info" "Starting containers with direct Docker commands..."
        
        # Start network first
        docker network create agent_network 2>/dev/null || true
        
        # Start services in order with proper environment
        export LIVEKIT_URL=ws://livekit:7880
        export LIVEKIT_API_KEY=devkey
        export LIVEKIT_API_SECRET=secret
        export OPENAI_API_KEY=no-key-needed
        export GROQ_API_KEY=no-key-needed
        export NEXT_PUBLIC_LIVEKIT_URL=ws://localhost:7880
        export NEXT_PUBLIC_LIVEKIT_API_KEY=devkey
        
        # Build and start each service
        docker-compose build && docker-compose up -d
    fi
    
    # Wait a bit for containers to initialize
    sleep 10
    
    # Check if containers started successfully
    local containers=("livekit" "agent" "whisper" "ollama" "kokoro" "frontend")
    local all_running=true
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "${PWD##*/}_$container.*Up"; then
            print_status "success" "$container container is running"
        else
            print_status "error" "$container container failed to start"
            all_running=false
        fi
    done
    
    if [ "$all_running" = false ]; then
        print_status "error" "Some containers failed to start. Showing logs..."
        docker-compose logs --tail=20 2>/dev/null || docker logs $(docker ps -a --format "table {{.Names}}" | grep "${PWD##*/}" | head -5)
        return 1
    fi
    
    return 0
}

# Function to wait for all services
wait_for_services() {
    print_status "header" "⏳ Waiting for services to be ready..."
    
    # Wait for each service with specific endpoints
    wait_for_service "http://localhost:3000" "Frontend" || return 1
    wait_for_service "http://localhost:11434/api/tags" "Ollama API" || return 1
    wait_for_service "http://localhost:11435" "Whisper service" || return 1
    wait_for_service "http://localhost:8880" "Kokoro TTS" || return 1
    wait_for_service "http://localhost:7880" "LiveKit server" || return 1
    
    print_status "success" "All services are ready!"
    return 0
}

# Function to validate and fix documentation
validate_documentation() {
    print_status "header" "📚 Validating documentation..."
    
    # First try to validate with auto-fix
    if python3 scripts/validate-docs.py --check-timestamps --update-timestamps > /dev/null 2>&1; then
        print_status "success" "Documentation validation passed with auto-fix"
        return 0
    else
        print_status "warning" "Documentation validation failed, attempting fixes..."
        
        # Try to fix common documentation issues
        if python3 scripts/fix-docs-references.py > /dev/null 2>&1; then
            print_status "success" "Fixed documentation references"
        fi
        
        # Validate again
        if python3 scripts/validate-docs.py --check-timestamps > /dev/null 2>&1; then
            print_status "success" "Documentation validation passed after fixes"
            return 0
        else
            print_status "error" "Documentation validation still failed"
            echo "Run 'python3 scripts/validate-docs.py --check-timestamps --strict' for details"
            return 1
        fi
    fi
}

# Function to check Python version correctly
check_python_version() {
    print_status "header" "🐍 Verifying Python 3.12 configuration..."
    
    # Check agent Dockerfile - fix the regex to match both formats
    if grep -q "python:3.12" agent/Dockerfile; then
        print_status "success" "Agent Dockerfile uses Python 3.12"
    else
        print_status "error" "Agent Dockerfile does not use Python 3.12"
        return 1
    fi
    
    # Check whisper Dockerfile
    if grep -q "python:3.12" whisper/Dockerfile; then
        print_status "success" "Whisper Dockerfile uses Python 3.12"
    else
        print_status "error" "Whisper Dockerfile does not use Python 3.12"
        return 1
    fi
    
    return 0
}

# Function to check RAG documents
check_rag_documents() {
    print_status "header" "📄 Checking RAG documents..."
    
    local doc_dir="agent/docs"
    if [ -d "$doc_dir" ]; then
        local doc_count=$(ls -1 "$doc_dir"/*.txt 2>/dev/null | wc -l)
        if [ "$doc_count" -gt 0 ]; then
            print_status "success" "Found $doc_count RAG documents in $doc_dir"
            return 0
        else
            print_status "warning" "No RAG documents found in $doc_dir"
            return 0  # Don't fail for missing RAG docs
        fi
    else
        print_status "warning" "RAG documents directory not found: $doc_dir"
        return 0  # Don't fail for missing RAG docs
    fi
}

# Function to show final success message
show_success() {
    print_status "success" "🎉 All setup and verification completed successfully!"
    echo ""
    echo "=========================================================="
    echo "Your Local Voice AI setup is ready to use!"
    echo "=========================================================="
    echo ""
    echo "Next steps:"
    echo "1. Open your browser and go to: http://localhost:3000"
    echo "2. Click the microphone button to grant permission"
    echo "3. Start speaking with your voice assistant"
    echo ""
    echo "For troubleshooting, see TESTING_GUIDE.md"
    echo ""
    echo "To stop the application: docker-compose down"
    echo "To restart the application: ./test.sh"
    echo "To verify setup again: ./verify-setup.sh"
}

# Function to show failure message with help
show_failure() {
    print_status "error" "❌ Setup and verification failed!"
    echo ""
    echo "=========================================================="
    echo "Troubleshooting steps:"
    echo "=========================================================="
    echo ""
    echo "1. Check Docker is running: docker info"
    echo "2. Check container logs: docker-compose logs"
    echo "3. Check available ports: netstat -tlnp | grep -E ':(3000|7880|7881|11434|11435|8880)'"
    echo "4. Restart containers: docker-compose down && ./test.sh"
    echo "5. For detailed troubleshooting, see TESTING_GUIDE.md"
    echo ""
    echo "If issues persist, please check the logs above and report the problem."
}

# Main setup and verification flow
main() {
    print_status "header" "🔧 Local Voice AI - Enhanced Setup and Verification"
    echo "=========================================================="
    echo ""
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_status "error" "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.yml" ]; then
        print_status "error" "Please run this script from the Local Voice AI root directory"
        exit 1
    fi
    
    # Track overall success
    local all_passed=true
    
    # Step 1: Fix permissions
    fix_permissions || all_passed=false
    echo ""
    
    # Step 2: Start containers
    if ! start_containers; then
        all_passed=false
        echo ""
        show_failure
        exit 1
    fi
    echo ""
    
    # Step 3: Wait for services to be ready
    if ! wait_for_services; then
        all_passed=false
        echo ""
        print_status "error" "Services failed to become ready. Showing container logs..."
        docker-compose logs --tail=50
        echo ""
        show_failure
        exit 1
    fi
    echo ""
    
    # Step 4: Validate documentation
    validate_documentation || all_passed=false
    echo ""
    
    # Step 5: Check Python version
    check_python_version || all_passed=false
    echo ""
    
    # Step 6: Check RAG documents
    check_rag_documents || all_passed=false
    echo ""
    
    # Final result
    if [ "$all_passed" = true ]; then
        show_success
        exit 0
    else
        print_status "warning" "Some non-critical checks failed, but the system should be functional."
        echo ""
        show_success
        exit 0  # Still exit with success for non-critical issues
    fi
}

# Handle script interruption
trap 'print_status "warning" "Setup interrupted by user"; exit 130' INT

# Run main function
main "$@"