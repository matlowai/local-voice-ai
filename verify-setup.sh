#!/bin/bash

# Final verification script for Local Voice AI setup
# This script checks all components to ensure everything is working correctly

set -e

echo "🧪 Running final verification tests for Local Voice AI..."
echo "=========================================================="

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
    else
        echo "❌ $2"
        return 1
    fi
}

# Function to check if containers are running
check_containers() {
    echo "1. Checking if containers are running..."
    
    # Check if any containers are running
    if ! docker-compose ps --format "table {{.Name}}\t{{.Status}}" | grep -q "Up"; then
        echo "❌ No containers are running. Please start with './test.sh'"
        return 1
    fi
    
    # Check each required container
    local containers=("livekit" "agent" "whisper" "ollama" "kokoro" "frontend")
    for container in "${containers[@]}"; do
        if docker-compose ps --format "table {{.Name}}\t{{.Status}}" | grep -q "$container.*Up"; then
            echo "  ✅ $container container is running"
        else
            echo "  ❌ $container container is not running"
            return 1
        fi
    done
    
    return 0
}

# Function to check service connectivity
check_services() {
    echo "2. Testing service connectivity..."
    
    # Check frontend
    if curl -s http://localhost:3000 > /dev/null; then
        echo "  ✅ Frontend accessible on port 3000"
    else
        echo "  ❌ Frontend not accessible on port 3000"
        return 1
    fi
    
    # Check Ollama
    if curl -s http://localhost:11434/api/tags > /dev/null; then
        echo "  ✅ Ollama API accessible on port 11434"
    else
        echo "  ❌ Ollama API not accessible on port 11434"
        return 1
    fi
    
    # Check Whisper
    if curl -s http://localhost:11435 > /dev/null; then
        echo "  ✅ Whisper service accessible on port 11435"
    else
        echo "  ❌ Whisper service not accessible on port 11435"
        return 1
    fi
    
    # Check Kokoro
    if curl -s http://localhost:8880 > /dev/null; then
        echo "  ✅ Kokoro TTS accessible on port 8880"
    else
        echo "  ❌ Kokoro TTS not accessible on port 8880"
        return 1
    fi
    
    # Check LiveKit
    if curl -s http://localhost:7880 > /dev/null; then
        echo "  ✅ LiveKit server accessible on port 7880"
    else
        echo "  ❌ LiveKit server not accessible on port 7880"
        return 1
    fi
    
    return 0
}

# Function to check documentation validation
check_documentation() {
    echo "3. Testing documentation validation..."
    
    if python3 scripts/validate-docs.py --check-timestamps --strict > /dev/null 2>&1; then
        echo "  ✅ Documentation validation passed"
        return 0
    else
        echo "  ❌ Documentation validation failed"
        echo "  Run 'python3 scripts/validate-docs.py --check-timestamps --strict' for details"
        return 1
    fi
}

# Function to check Git configuration
check_git_config() {
    echo "4. Verifying Git configuration..."
    
    # Check if origin remote points to the correct fork
    if git remote -v | grep -q "origin.*https://github.com/matlowai/local-voice-ai.git"; then
        echo "  ✅ Origin remote configured correctly"
    else
        echo "  ❌ Origin remote not configured correctly"
        echo "  Expected: https://github.com/matlowai/local-voice-ai.git"
        return 1
    fi
    
    # Check if upstream remote points to the original repository
    if git remote -v | grep -q "upstream.*https://github.com/ShayneP/local-voice-ai.git"; then
        echo "  ✅ Upstream remote configured correctly"
    else
        echo "  ❌ Upstream remote not configured correctly"
        echo "  Expected: https://github.com/ShayneP/local-voice-ai.git"
        return 1
    fi
    
    # Check if main branch tracks origin/main
    if git branch -vv | grep -q "\* main.*\[origin/main\]"; then
        echo "  ✅ Main branch tracks origin/main"
    else
        echo "  ❌ Main branch does not track origin/main"
        echo "  Run 'git branch --set-upstream-to=origin/main main' to fix"
        return 1
    fi
    
    return 0
}

# Function to check Python version in Dockerfiles
check_python_version() {
    echo "5. Verifying Python 3.12 configuration..."
    
    # Check agent Dockerfile - handle both ARG and direct FROM formats
    if grep -q "python:3.12" agent/Dockerfile || grep -q "PYTHON_VERSION=3.12" agent/Dockerfile; then
        echo "  ✅ Agent Dockerfile uses Python 3.12"
    else
        echo "  ❌ Agent Dockerfile does not use Python 3.12"
        return 1
    fi
    
    # Check whisper Dockerfile
    if grep -q "python:3.12" whisper/Dockerfile; then
        echo "  ✅ Whisper Dockerfile uses Python 3.12"
    else
        echo "  ❌ Whisper Dockerfile does not use Python 3.12"
        return 1
    fi
    
    return 0
}

# Function to check RAG documents
check_rag_documents() {
    echo "6. Checking RAG documents..."
    
    local doc_dir="agent/docs"
    if [ -d "$doc_dir" ]; then
        local doc_count=$(ls -1 "$doc_dir"/*.txt 2>/dev/null | wc -l)
        if [ "$doc_count" -gt 0 ]; then
            echo "  ✅ Found $doc_count RAG documents in $doc_dir"
            return 0
        else
            echo "  ❌ No RAG documents found in $doc_dir"
            return 1
        fi
    else
        echo "  ❌ RAG documents directory not found: $doc_dir"
        return 1
    fi
}

# Function to provide next steps
show_next_steps() {
    echo ""
    echo "🎉 All verification tests passed!"
    echo "=========================================================="
    echo ""
    echo "Your Local Voice AI setup is ready to use!"
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
}

# Main verification flow
main() {
    echo "Starting comprehensive verification..."
    echo ""
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ Please run this script from the Local Voice AI root directory"
        exit 1
    fi
    
    # Run all checks
    local all_passed=true
    
    check_containers || all_passed=false
    echo ""
    
    check_services || all_passed=false
    echo ""
    
    check_documentation || all_passed=false
    echo ""
    
    check_git_config || all_passed=false
    echo ""
    
    check_python_version || all_passed=false
    echo ""
    
    check_rag_documents || all_passed=false
    echo ""
    
    # Final result
    if [ "$all_passed" = true ]; then
        show_next_steps
        exit 0
    else
        echo ""
        echo "❌ Some verification tests failed."
        echo ""
        echo "Please fix the issues above and run this script again."
        echo ""
        echo "For detailed troubleshooting, see TESTING_GUIDE.md"
        exit 1
    fi
}

# Run main function
main "$@"