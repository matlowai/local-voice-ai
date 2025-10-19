# Development Workflow

This document provides comprehensive guidelines for developing, testing, and maintaining the Local Voice AI project. It includes procedures for both human developers and coding agents.

## 🚀 Quick Start

### Prerequisites
- Docker + Docker Compose installed
- 12GB+ RAM available
- Modern web browser with WebRTC support
- Git for version control

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/ShayneP/local-voice-ai.git
cd local-voice-ai

# Start all services
./test.sh

# Access the application
open http://localhost:3000
```

## 🔄 Development Workflow

### 1. Daily Development Process

#### For Human Developers
```bash
# 1. Pull latest changes
git pull origin main

# 2. Start development environment
docker-compose up --build

# 3. Make changes to code
# 4. Test changes
# 5. Commit and push
git add .
git commit -m "Describe changes"
git push origin main
```

#### For Coding Agents
```bash
# 1. Read current documentation
cat docs/index.md
cat docs/coding-standards.md

# 2. Understand the task requirements
# 3. Review relevant service documentation
# 4. Implement changes following coding standards
# 5. Update documentation as required
# 6. Test implementation
# 7. Commit changes with proper documentation
```

### 2. Service Development

#### Adding New Features
1. **Understand the Architecture**: Read [architecture.md](architecture.md)
2. **Identify Affected Services**: Determine which components need changes
3. **Review Service Documentation**: Read relevant service docs in [services/](services/index.md)
4. **Implement Changes**: Follow [coding standards](coding-standards.md)
5. **Update Documentation**: Update all affected documentation files
6. **Test Thoroughly**: Verify functionality across all affected services

#### Modifying Existing Services
1. **Read Service Documentation**: Understand current implementation
2. **Identify Dependencies**: Check for inter-service dependencies
3. **Plan Changes**: Consider impact on other services
4. **Implement Incrementally**: Make small, testable changes
5. **Update Documentation**: Keep docs in sync with code
6. **Regression Testing**: Ensure existing functionality still works

### 3. Testing Procedures

#### Local Testing
```bash
# Clean restart
docker-compose down -v --remove-orphans
docker-compose up --build

# Test with different browsers
# - Chrome/Chromium
# - Firefox
# - Safari (if available)

# Test audio functionality
# 1. Grant microphone permissions
# 2. Speak to the assistant
# 3. Verify transcription appears
# 4. Verify audio response plays
```

#### Service-Specific Testing
```bash
# Test individual services
docker-compose up agent      # Test agent service
docker-compose up whisper    # Test STT service
docker-compose up ollama     # Test LLM service
docker-compose up kokoro     # Test TTS service
docker-compose up livekit    # Test signaling server
docker-compose up frontend   # Test frontend
```

#### Integration Testing
```bash
# Test service communication
curl http://localhost:11434/api/tags          # Test Ollama
curl http://localhost:8880/v1/models          # Test Kokoro
curl http://localhost:11435/health            # Test Whisper
curl http://localhost:7880/health             # Test LiveKit
```

## 🛠️ Development Tools

### Docker Commands
```bash
# View logs for specific service
docker-compose logs -f agent
docker-compose logs -f whisper
docker-compose logs -f ollama
docker-compose logs -f kokoro
docker-compose logs -f livekit
docker-compose logs -f frontend

# Execute commands in containers
docker-compose exec agent bash
docker-compose exec ollama bash
docker-compose exec frontend bash

# Monitor resource usage
docker stats
```

### Debugging Tools
```bash
# Check service health
docker-compose ps

# Inspect network configuration
docker network ls
docker network inspect local-voice-ai_agent_network

# View container details
docker inspect local-voice-ai_agent_1
```

## 📝 Documentation Maintenance

### For Coding Agents

#### Required Documentation Updates
After making any code changes, you MUST update the following:

1. **Code Documentation**: Update docstrings following [coding standards](coding-standards.md)
2. **Service Documentation**: Update relevant service files in [services/](services/index.md)
3. **Architecture Documentation**: Update [architecture.md](architecture.md) if system design changes
4. **API Documentation**: Update endpoint documentation if APIs change

#### Documentation Update Process
```bash
# 1. Identify affected documentation
grep -r "function_name" docs/  # Find references

# 2. Update code docstrings
# Follow templates in coding-standards.md

# 3. Update service documentation
# Edit relevant files in docs/services/

# 4. Update cross-references
# Check all links and references

# 5. Validate documentation
# Test all links and examples
```

#### Documentation Validation Checklist
- [ ] All new functions have proper docstrings
- [ ] Service documentation reflects current implementation
- [ ] Cross-references are accurate
- [ ] Code examples are tested and working
- [ ] Architecture diagrams are up-to-date
- [ ] Environment variables are documented

### For Human Developers

#### Review Process
1. **Code Review**: Ensure coding standards are followed
2. **Documentation Review**: Verify documentation is complete
3. **Testing Review**: Confirm all tests pass
4. **Integration Review**: Check service interactions

#### Release Process
```bash
# 1. Ensure all tests pass
./test.sh

# 2. Update version numbers
# Update package.json, Dockerfile tags, etc.

# 3. Update changelog
echo "## Version X.Y.Z - $(date)" >> CHANGELOG.md
echo "- Description of changes" >> CHANGELOG.md

# 4. Commit and tag
git add .
git commit -m "Release version X.Y.Z"
git tag -a vX.Y.Z -m "Release version X.Y.Z"
git push origin main --tags
```

## 🔄 Continuous Integration

### Automated Checks
The project should include automated checks for:
- Code formatting and style
- Documentation completeness
- Container build success
- Service health checks
- Integration tests

### Pre-commit Hooks
```bash
# Example pre-commit setup
#!/bin/sh
# .git/hooks/pre-commit

# Check documentation
python scripts/check-docs.py

# Check code formatting
python scripts/check-format.py

# Run tests
./test.sh
```

## 🚨 Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep :3000
netstat -tulpn | grep :7880

# Kill conflicting processes
sudo kill -9 <PID>
```

#### Docker Issues
```bash
# Clean up Docker
docker system prune -a
docker volume prune
docker network prune

# Rebuild containers
docker-compose down -v --remove-orphans
docker-compose up --build
```

#### Audio Issues
```bash
# Check microphone permissions
# In browser: chrome://settings/content/microphone

# Test audio hardware
# Use system audio testing tools
```

#### Service Connection Issues
```bash
# Check network connectivity
docker-compose exec agent ping whisper
docker-compose exec agent ping ollama
docker-compose exec agent ping kokoro

# Check service logs
docker-compose logs -f agent
```

### Debug Mode
```bash
# Enable debug logging
export DEBUG=1
docker-compose up

# Individual service debug
docker-compose run --rm agent python -m pdb myagent.py
```

## 📋 Development Checklist

### Before Committing
- [ ] Code follows [coding standards](coding-standards.md)
- [ ] All functions have proper docstrings
- [ ] Documentation is updated
- [ ] Tests pass locally
- [ ] No sensitive data in code
- [ ] Environment variables are properly configured
- [ ] Docker containers build successfully
- [ ] Services start without errors
- [ ] Audio functionality works end-to-end

### Before Release
- [ ] All tests pass in CI
- [ ] Documentation is complete
- [ ] Version numbers are updated
- [ ] Changelog is updated
- [ ] Release notes are prepared
- [ ] Breaking changes are documented
- [ ] Migration guide is provided (if needed)

## 🎯 Best Practices

### Code Organization
- Keep services loosely coupled
- Use clear, descriptive naming
- Implement proper error handling
- Log important events
- Use environment-specific configurations

### Documentation
- Document as you code
- Keep documentation in sync
- Use examples in documentation
- Include troubleshooting information
- Maintain change logs

### Testing
- Test early and often
- Test service interactions
- Test error conditions
- Test with different browsers
- Test with different audio hardware

---

*For service-specific development guidelines, see the documentation in the [services/](services/index.md) directory.*