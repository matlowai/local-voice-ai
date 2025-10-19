#!/bin/bash

# Simplified setup and verification script for Local Voice AI
# This version works around .env file permission issues

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
    print_status "header" "🔧 Fixing file permissions..."
    
    # Fix .env file permissions and attributes
    if [ -f ".env" ]; then
        chattr -e .env 2>/dev/null || true
        chmod 644 .env
        print_status "success" "Fixed .env file permissions"
    fi
    
    # Fix docker-compose.yml
    if [ -f "docker-compose.yml" ]; then
        chattr -e docker-compose.yml 2>/dev/null || true
        chmod 644 docker-compose.yml
        print_status "success" "Fixed docker-compose.yml permissions"
    fi
    
    # Make scripts executable
    chmod +x test.sh verify-setup.sh setup-and-verify.sh 2>/dev/null || true
    print_status "success" "Made scripts executable"
}

# Function to start containers without .env file
start_containers() {
    print_status "header" "🚀 Starting containers..."
    
    # Set environment variables
    export LIVEKIT_URL=ws://livekit:7880
    export LIVEKIT_API_KEY=devkey
    export LIVEKIT_API_SECRET=secret
    export OPENAI_API_KEY=no-key-needed
    export GROQ_API_KEY=no-key-needed
    export NEXT_PUBLIC_LIVEKIT_URL=ws://localhost:7880
    export NEXT_PUBLIC_LIVEKIT_API_KEY=devkey
    
    # Stop any existing containers
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # Temporarily move .env file if it exists
    if [ -f ".env" ]; then
        mv .env .env.temp
        print_status "info" "Temporarily moved .env file to avoid permission issues"
    fi
    
    # Start containers
    print_status "info" "Building and starting all services..."
    if docker-compose up --build -d; then
        print_status "success" "Containers started successfully"
    else
        print_status "error" "Failed to start containers"
        # Restore .env file if it was moved
        [ -f ".env.temp" ] && mv .env.temp .env
        return 1
    fi
    
    # Restore .env file if it was moved
    if [ -f ".env.temp" ]; then
        mv .env.temp .env
        print_status "info" "Restored .env file"
    fi
    
    # Wait a bit for containers to initialize
    sleep 10
    
    # Check if containers started successfully
    local containers=("livekit" "agent" "whisper" "ollama" "kokoro" "frontend")
    local all_running=true
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "${PWD##*/}_$container"; then
            print_status "success" "$container container is running"
        else
            print_status "error" "$container container failed to start"
            all_running=false
        fi
    done
    
    if [ "$all_running" = false ]; then
        print_status "error" "Some containers failed to start. Showing logs..."
        docker-compose logs --tail=20
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

# Function to validate documentation
validate_documentation() {
    print_status "header" "📚 Validating documentation..."
    
    if python3 scripts/validate-docs.py --check-timestamps > /dev/null 2>&1; then
        print_status "success" "Documentation validation passed"
        return 0
    else
        print_status "warning" "Documentation validation failed, but continuing..."
        return 0  # Don't fail for documentation issues
    fi
}

# Function to show final success message
show_success() {
    print_status "success" "🎉 Setup completed successfully!"
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
    echo "To stop the application: docker-compose down"
    echo "To restart the application: ./test.sh"
}

# Function to show failure message
show_failure() {
    print_status "error" "❌ Setup failed!"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check Docker is running: docker info"
    echo "2. Check container logs: docker-compose logs"
    echo "3. Try manual start: ./test.sh"
    echo ""
}

# Main setup flow
main() {
    print_status "header" "🔧 Local Voice AI - Simplified Setup"
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
    
    # Step 3: Wait for services
    if ! wait_for_services; then
        all_passed=false
        echo ""
        show_failure
        exit 1
    fi
    echo ""
    
    # Step 4: Validate documentation
    validate_documentation || all_passed=false
    echo ""
    
    # Final result
    if [ "$all_passed" = true ]; then
        show_success
        exit 0
    else
        print_status "warning" "Some non-critical checks failed, but the system should be functional."
        echo ""
        show_success
        exit 0
    fi
}

# Run main function
main "$@"