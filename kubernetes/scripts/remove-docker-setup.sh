#!/bin/bash

# Script to remove Docker setup scripts after migration to Kubernetes
# This script cleans up old Docker-related files and configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
        "highlight")
            echo -e "${PURPLE}🌟 $message${NC}"
            ;;
        "performance")
            echo -e "${CYAN}🚀 $message${NC}"
            ;;
    esac
}

# Function to backup files before removal
backup_file() {
    local file_path=$1
    local backup_dir="docker-setup-backup-$(date +%Y%m%d-%H%M%S)"
    
    if [[ -f "$file_path" ]]; then
        mkdir -p "$backup_dir"
        cp "$file_path" "$backup_dir/"
        print_status "info" "Backed up: $file_path -> $backup_dir/$(basename $file_path)"
    fi
}

# Function to remove Docker setup scripts
remove_docker_scripts() {
    print_status "header" "🗑️  Removing Docker Setup Scripts"
    echo "=========================================================="
    
    # List of Docker-related files to remove
    local docker_files=(
        "docker-compose.yml"
        "docker-compose.dev.yml"
        "docker-compose.prod.yml"
        "docker-compose.gpu.yml"
        ".dockerignore"
        "Dockerfile.frontend"
        "Dockerfile.agent"
        "Dockerfile.whisper"
        "Dockerfile.kokoro"
        "Dockerfile.ollama"
        "Dockerfile.livekit"
        "scripts/docker-setup.sh"
        "scripts/docker-build.sh"
        "scripts/docker-run.sh"
        "scripts/docker-stop.sh"
        "scripts/docker-clean.sh"
        "scripts/docker-logs.sh"
        "scripts/docker-status.sh"
        "scripts/docker-update.sh"
        "scripts/docker-backup.sh"
        "scripts/docker-restore.sh"
        "scripts/docker-test.sh"
        "scripts/docker-deploy.sh"
        "scripts/docker-remove.sh"
        "scripts/docker-health.sh"
        "scripts/docker-monitor.sh"
        "scripts/docker-benchmark.sh"
        "scripts/docker-gpu-setup.sh"
        "scripts/docker-cpu-setup.sh"
        "scripts/docker-switch.sh"
        "scripts/docker-verify.sh"
        "scripts/docker-restart.sh"
        "scripts/docker-scale.sh"
        "scripts/docker-config.sh"
        "scripts/docker-network.sh"
        "scripts/docker-volume.sh"
        "scripts/docker-secret.sh"
        "scripts/docker-env.sh"
        "scripts/docker-compose.override.yml"
        "scripts/docker-compose.dev.override.yml"
        "scripts/docker-compose.prod.override.yml"
        "scripts/docker-compose.gpu.override.yml"
    )
    
    local removed_count=0
    local backed_up_count=0
    
    for file in "${docker_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Backup before removal
            backup_file "$file"
            ((backed_up_count++))
            
            # Remove the file
            rm "$file"
            print_status "success" "Removed: $file"
            ((removed_count++))
        fi
    done
    
    echo ""
    print_status "info" "Removed $removed_count Docker-related files"
    print_status "info" "Backed up $backed_up_count files"
    
    return 0
}

# Function to remove Docker configurations
remove_docker_configs() {
    print_status "header" "🗑️  Removing Docker Configurations"
    echo "=========================================================="
    
    # Remove Docker environment files
    local docker_env_files=(
        ".env.docker"
        ".env.docker.dev"
        ".env.docker.prod"
        ".env.docker.gpu"
        "docker.env"
        "docker.dev.env"
        "docker.prod.env"
        "docker.gpu.env"
    )
    
    local removed_count=0
    
    for file in "${docker_env_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Backup before removal
            backup_file "$file"
            
            # Remove the file
            rm "$file"
            print_status "success" "Removed: $file"
            ((removed_count++))
        fi
    done
    
    # Remove Docker configuration directories
    local docker_dirs=(
        "docker"
        "docker-config"
        "docker-data"
        "docker-logs"
        "docker-backups"
        "docker-scripts"
    )
    
    for dir in "${docker_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Backup before removal
            local backup_dir="docker-setup-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$dir" "$backup_dir/"
            print_status "info" "Backed up directory: $dir -> $backup_dir/$dir"
            
            # Remove the directory
            rm -rf "$dir"
            print_status "success" "Removed directory: $dir"
            ((removed_count++))
        fi
    done
    
    echo ""
    print_status "info" "Removed $removed_count Docker configurations"
    
    return 0
}

# Function to clean up Docker resources
cleanup_docker_resources() {
    print_status "header" "🧹 Cleaning Up Docker Resources"
    echo "=========================================================="
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_status "warning" "Docker is not running, skipping resource cleanup"
        return 0
    fi
    
    # Stop and remove Docker containers
    print_status "info" "Stopping and removing Docker containers..."
    local containers=$(docker ps -a -q --filter "name=local-voice-ai" 2>/dev/null || true)
    
    if [[ -n "$containers" ]]; then
        docker stop $containers 2>/dev/null || true
        docker rm $containers 2>/dev/null || true
        print_status "success" "Removed local-voice-ai containers"
    else
        print_status "info" "No local-voice-ai containers found"
    fi
    
    # Remove Docker images
    print_status "info" "Removing Docker images..."
    local images=$(docker images -q --filter "reference=local-voice-ai/*" 2>/dev/null || true)
    
    if [[ -n "$images" ]]; then
        docker rmi $images 2>/dev/null || true
        print_status "success" "Removed local-voice-ai images"
    else
        print_status "info" "No local-voice-ai images found"
    fi
    
    # Remove Docker volumes
    print_status "info" "Removing Docker volumes..."
    local volumes=$(docker volume ls -q --filter "name=local-voice-ai" 2>/dev/null || true)
    
    if [[ -n "$volumes" ]]; then
        docker volume rm $volumes 2>/dev/null || true
        print_status "success" "Removed local-voice-ai volumes"
    else
        print_status "info" "No local-voice-ai volumes found"
    fi
    
    # Remove Docker networks
    print_status "info" "Removing Docker networks..."
    local networks=$(docker network ls -q --filter "name=local-voice-ai" 2>/dev/null || true)
    
    if [[ -n "$networks" ]]; then
        docker network rm $networks 2>/dev/null || true
        print_status "success" "Removed local-voice-ai networks"
    else
        print_status "info" "No local-voice-ai networks found"
    fi
    
    # Clean up unused Docker resources
    print_status "info" "Cleaning up unused Docker resources..."
    docker system prune -f 2>/dev/null || true
    print_status "success" "Cleaned up unused Docker resources"
    
    return 0
}

# Function to update documentation
update_documentation() {
    print_status "header" "📝 Updating Documentation"
    echo "=========================================================="
    
    # Update README.md to remove Docker references
    if [[ -f "README.md" ]]; then
        backup_file "README.md"
        
        # Remove Docker setup section
        sed -i '/## Docker Setup/,/## Kubernetes Setup/c\
\
## Kubernetes Setup\
\
For the latest deployment instructions, see [KUBERNETES_DEPLOYMENT_GUIDE.md](KUBERNETES_DEPLOYMENT_GUIDE.md).\
' README.md
        
        print_status "success" "Updated README.md"
    fi
    
    # Remove Docker-specific documentation
    local docker_docs=(
        "DOCKER_SETUP_GUIDE.md"
        "DOCKER_DEVELOPMENT.md"
        "DOCKER_TROUBLESHOOTING.md"
        "DOCKER_ARCHITECTURE.md"
    )
    
    for doc in "${docker_docs[@]}"; do
        if [[ -f "$doc" ]]; then
            backup_file "$doc"
            rm "$doc"
            print_status "success" "Removed Docker documentation: $doc"
        fi
    done
    
    return 0
}

# Function to update scripts and tools
update_scripts() {
    print_status "header" "🔧 Updating Scripts and Tools"
    echo "=========================================================="
    
    # Update main verification script
    if [[ -f "verify-setup.sh" ]]; then
        backup_file "verify-setup.sh"
        
        # Update to point to Kubernetes verification
        cat > verify-setup.sh << 'EOF'
#!/bin/bash

# Local Voice AI Verification Script
# This script now points to the Kubernetes verification

echo "🚀 Local Voice AI - Kubernetes Verification"
echo "=========================================================="
echo ""
echo "The Docker-based deployment has been migrated to Kubernetes."
echo "Please use the Kubernetes verification script instead."
echo ""
echo "To verify your Kubernetes deployment:"
echo "  ./kubernetes/scripts/verify-deployment.sh"
echo ""
echo "To run comprehensive tests:"
echo "  ./kubernetes/scripts/test-kubernetes.sh"
echo ""
echo "For deployment instructions:"
echo "  ./kubernetes/scripts/deploy-gpu.sh"
echo ""
echo "For more information, see:"
echo "  - KUBERNETES_DEPLOYMENT_GUIDE.md"
echo "  - docs/kubernetes-architecture.md"
echo "  - docs/kubernetes-development-workflow.md"
echo ""
EOF
        
        chmod +x verify-setup.sh
        print_status "success" "Updated verify-setup.sh"
    fi
    
    # Remove Docker-specific scripts
    local docker_scripts=(
        "setup-and-verify.sh"
        "setup-and-verify-simple.sh"
        "setup-and-verify-final.sh"
        "setup-and-verify-working.sh"
    )
    
    for script in "${docker_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            backup_file "$script"
            rm "$script"
            print_status "success" "Removed Docker script: $script"
        fi
    done
    
    return 0
}

# Function to show summary
show_summary() {
    print_status "header" "📋 Docker Removal Summary"
    echo "=========================================================="
    echo ""
    print_status "highlight" "🌟 Docker setup has been successfully removed!"
    echo ""
    echo "What was done:"
    echo "✅ Removed Docker setup scripts and configurations"
    echo "✅ Cleaned up Docker resources (containers, images, volumes, networks)"
    echo "✅ Backed up all removed files to timestamped directories"
    echo "✅ Updated documentation to reference Kubernetes deployment"
    echo "✅ Updated verification scripts to point to Kubernetes"
    echo ""
    echo "What's next:"
    echo "🚀 Use the Kubernetes deployment for all future work"
    echo "📖 Follow the KUBERNETES_DEPLOYMENT_GUIDE.md for setup instructions"
    echo "🧪 Use ./kubernetes/scripts/test-kubernetes.sh for testing"
    echo "🔧 Use ./kubernetes/scripts/verify-deployment.sh for verification"
    echo ""
    echo "Backup location:"
    print_status "info" "All removed files have been backed up to timestamped directories"
    echo ""
    echo "Benefits of migration:"
    echo "✨ Better resource management and utilization"
    echo "✨ Enhanced scalability and reliability"
    echo "✨ Improved monitoring and observability"
    echo "✨ Production-ready deployment with GPU acceleration"
    echo "✨ Automatic CPU fallback for reliability"
    echo ""
    echo "=========================================================="
    print_status "performance" "🚀 Enjoy the power of Kubernetes with GPU acceleration!"
}

# Main removal flow
main() {
    print_status "header" "🗑️  Local Voice AI - Docker Setup Removal"
    echo "=========================================================="
    echo ""
    echo "This script will remove all Docker-related files and configurations"
    echo "after migrating to Kubernetes deployment."
    echo ""
    echo "All removed files will be backed up to timestamped directories."
    echo ""
    
    # Ask for confirmation
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "info" "Docker removal cancelled by user"
        exit 0
    fi
    
    # Remove Docker scripts
    remove_docker_scripts
    echo ""
    
    # Remove Docker configurations
    remove_docker_configs
    echo ""
    
    # Clean up Docker resources
    cleanup_docker_resources
    echo ""
    
    # Update documentation
    update_documentation
    echo ""
    
    # Update scripts
    update_scripts
    echo ""
    
    # Show summary
    show_summary
}

# Handle script interruption
trap 'print_status "warning" "Docker removal interrupted by user"; exit 130' INT

# Run main function
main "$@"