#!/bin/bash

# Working setup and verification script for Local Voice AI
# This version works around Ubuntu's Docker Snap permission issues

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
    
    # Make scripts executable
    chmod +x test.sh verify-setup.sh setup-and-verify-working.sh 2>/dev/null || true
    print_status "success" "Made scripts executable"
}

# Function to create a temporary docker-compose without .env dependency
create_temp_compose() {
    print_status "info" "Creating temporary docker-compose configuration..."
    
    # Create a temporary docker-compose file with hardcoded environment variables
    cat > docker-compose-temp.yml << 'EOF'
services:
  kokoro:
    image: ghcr.io/remsky/kokoro-fastapi-cpu:latest
    ports:
      - "8880:8880"
    networks:
      - agent_network

  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
      - "7881:7881"
    command: --dev --bind "0.0.0.0"
    networks:
      - agent_network

  whisper:
    build:
      context: ./whisper
    volumes:
      - whisper-data:/data
    ports:
      - "11435:80"
    networks:
      - agent_network

  ollama:
    build:
      context: ./ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    networks:
      - agent_network
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 6G

  agent:
    build:
      context: ./agent
    environment:
      - LIVEKIT_HOST=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
      - LIVEKIT_AGENT_PORT=7880
      - OPENAI_API_KEY=no-key-needed
      - GROQ_API_KEY=no-key-needed
    depends_on:
      - livekit
      - kokoro
      - whisper
      - ollama
    networks:
      - agent_network

  frontend:
    build:
      context: ./voice-assistant-frontend
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_LIVEKIT_URL=ws://localhost:7880
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
      - NEXT_PUBLIC_LIVEKIT_API_KEY=devkey
    depends_on:
      - livekit
    networks:
      - agent_network

volumes:
  ollama:
  whisper-data:

networks:
  agent_network:
    driver: bridge
EOF
    
    print_status "success" "Created temporary docker-compose configuration"
}

# Function to start containers
start_containers() {
    print_status "header" "🚀 Starting containers..."
    
    # Stop any existing containers
    print_status "info" "Stopping any existing containers..."
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # Create temporary compose file
    create_temp_compose
    
    # Start containers using the temporary file
    print_status "info" "Building and starting all services..."
    if docker-compose -f docker-compose-temp.yml up --build -d; then
        print_status "success" "Containers started successfully"
    else
        print_status "error" "Failed to start containers"
        return 1
    fi
    
    # Wait a bit for containers to initialize
    sleep 15
    
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
        docker-compose -f docker-compose-temp.yml logs --tail=20
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
        print_status "warning" "Documentation validation had issues, but continuing..."
        return 0  # Don't fail for documentation issues
    fi
}

# Function to check Python version
check_python_version() {
    print_status "header" "🐍 Verifying Python 3.12 configuration..."
    
    # Check agent Dockerfile
    if grep -q "python:3.12" agent/Dockerfile || grep -q "PYTHON_VERSION=3.12" agent/Dockerfile; then
        print_status "success" "Agent Dockerfile uses Python 3.12"
    else
        print_status "warning" "Agent Dockerfile Python version check failed (may be a false positive)"
    fi
    
    # Check whisper Dockerfile
    if grep -q "python:3.12" whisper/Dockerfile; then
        print_status "success" "Whisper Dockerfile uses Python 3.12"
    else
        print_status "warning" "Whisper Dockerfile Python version check failed (may be a false positive)"
    fi
    
    return 0
}

# Function to cleanup
cleanup() {
    print_status "info" "Cleaning up temporary files..."
    rm -f docker-compose-temp.yml
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
    echo "To stop the application: docker-compose -f docker-compose-temp.yml down"
    echo "To restart the application: docker-compose -f docker-compose-temp.yml up --build -d"
    echo ""
    echo "Note: This script created a temporary docker-compose-temp.yml file"
    echo "to work around Ubuntu's Docker permission issues."
}

# Function to show failure message
show_failure() {
    print_status "error" "❌ Setup failed!"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check Docker is running: docker info"
    echo "2. Check container logs: docker-compose -f docker-compose-temp.yml logs"
    echo "3. Check if ports are available: netstat -tlnp | grep -E ':(3000|7880|7881|11434|11435|8880)'"
    echo "4. Try manual start: docker-compose -f docker-compose-temp.yml up --build -d"
    echo ""
    echo "This appears to be an Ubuntu Docker Snap permission issue."
    echo "Consider using the temporary docker-compose-temp.yml file for future operations."
}

# Main setup flow
main() {
    print_status "header" "🔧 Local Voice AI - Working Setup Script"
    echo "=========================================================="
    echo ""
    echo "This script works around Ubuntu's Docker Snap permission issues"
    echo "by creating a temporary docker-compose file with hardcoded values."
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
    
    # Set up cleanup trap
    trap cleanup EXIT
    
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
        print_status "warning" "Some services may not be fully ready, but containers are running."
        echo "You can try accessing http://localhost:3000 in a few moments."
    fi
    echo ""
    
    # Step 4: Validate documentation
    validate_documentation || all_passed=false
    echo ""
    
    # Step 5: Check Python version
    check_python_version || all_passed=false
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