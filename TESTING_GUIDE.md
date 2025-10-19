# Testing Guide for Local Voice AI

## Overview

This guide covers testing strategies and procedures for Local Voice AI, including both Docker and Kubernetes deployments. It provides comprehensive testing approaches for unit tests, integration tests, end-to-end tests, and performance tests.

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Docker Testing](#docker-testing)
3. [Kubernetes Testing](#kubernetes-testing)
4. [Test Categories](#test-categories)
5. [Test Automation](#test-automation)
6. [Performance Testing](#performance-testing)
7. [GPU Testing](#gpu-testing)
8. [Troubleshooting Tests](#troubleshooting-tests)

## Testing Philosophy

### Principles

1. **Test Early, Test Often**: Integrate testing throughout the development lifecycle
2. **Comprehensive Coverage**: Test all components and their interactions
3. **Automated Testing**: Automate as much as possible for consistency
4. **Real-World Scenarios**: Test with realistic data and usage patterns
5. **Performance Focus**: Monitor and test performance continuously

### Test Pyramid

```
    /\
   /  \  E2E Tests (Few, High Value)
  /____\
 /      \ Integration Tests (Moderate, Medium Value)
/________\
Unit Tests (Many, Low Value)
```

## Docker Testing

### Quick Start

```bash
# Run all tests
./verify-setup.sh

# Run specific test categories
./verify-setup.sh --unit
./verify-setup.sh --integration
./verify-setup.sh --e2e
```

### Unit Testing

#### Frontend Tests

```bash
# Navigate to frontend directory
cd voice-assistant-frontend

# Install dependencies
npm install

# Run unit tests
npm test

# Run tests with coverage
npm test -- --coverage
```

#### Backend Tests

```bash
# Navigate to agent directory
cd agent

# Install dependencies
pip install -r requirements.txt

# Run unit tests
python -m pytest tests/

# Run tests with coverage
python -m pytest tests/ --cov=agent
```

#### Service Tests

```bash
# Test Ollama service
cd ollama
python -m pytest tests/

# Test Whisper service
cd whisper
python -m pytest tests/

# Test Kokoro service
cd kokoro
python -m pytest tests/
```

### Integration Testing

```bash
# Run integration tests
./verify-setup.sh --integration

# Test service interactions
./scripts/test-integration.sh

# Test API endpoints
./scripts/test-api.sh
```

### End-to-End Testing

```bash
# Run E2E tests
./verify-setup.sh --e2e

# Test complete voice workflow
./scripts/test-voice-workflow.sh

# Test with different audio formats
./scripts/test-audio-formats.sh
```

## Kubernetes Testing

### Quick Start

```bash
# Run all Kubernetes tests
./kubernetes/scripts/test-kubernetes.sh

# Run specific test categories
./kubernetes/scripts/test-kubernetes.sh connectivity
./kubernetes/scripts/test-kubernetes.sh gpu
./kubernetes/scripts/test-kubernetes.sh deployment
./kubernetes/scripts/test-kubernetes.sh functionality
./kubernetes/scripts/test-kubernetes.sh e2e
./kubernetes/scripts/test-kubernetes.sh performance
```

### Cluster Connectivity Testing

```bash
# Test cluster connectivity
./kubernetes/scripts/test-kubernetes.sh connectivity

# Verify all pods are running
kubectl get pods -n voice-ai

# Check service endpoints
kubectl get endpoints -n voice-ai
```

### GPU Testing

```bash
# Test GPU availability
./kubernetes/scripts/test-kubernetes.sh gpu

# Check GPU utilization
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi

# Test GPU memory allocation
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi --query-gpu=memory.used,memory.total
```

### Service Deployment Testing

```bash
# Test service deployment
./kubernetes/scripts/test-kubernetes.sh deployment

# Verify all services are running
kubectl get pods -n voice-ai

# Check service health
kubectl get pods -n voice-ai -o wide
```

### Service Connectivity Testing

```bash
# Test service connectivity
./kubernetes/scripts/test-kubernetes.sh connectivity

# Test internal service communication
kubectl exec -n voice-ai deployment/agent -- curl http://ollama.voice-ai.svc.cluster.local:11434/api/tags
```

### AI Service Functionality Testing

```bash
# Test AI service functionality
./kubernetes/scripts/test-kubernetes.sh functionality

# Test Ollama API
kubectl exec -n voice-ai deployment/ollama -- curl -s http://localhost:11434/api/tags

# Test Whisper API
kubectl exec -n voice-ai deployment/whisper -- curl -s http://localhost:80/health

# Test Kokoro API
kubectl exec -n voice-ai deployment/kokoro -- curl -s http://localhost:8880/health

# Test Agent API
kubectl exec -n voice-ai deployment/agent -- curl -s http://localhost:8080/health
```

### End-to-End Workflow Testing

```bash
# Test end-to-end workflow
./kubernetes/scripts/test-kubernetes.sh e2e

# Test complete voice workflow in Kubernetes
./kubernetes/scripts/test-voice-workflow-k8s.sh
```

### Performance Testing

```bash
# Test performance
./kubernetes/scripts/test-kubernetes.sh performance

# Benchmark GPU performance
./kubernetes/scripts/benchmark-gpu.sh

# Test concurrent users
./kubernetes/scripts/test-load.sh
```

### CPU Fallback Testing

```bash
# Test CPU fallback
./kubernetes/scripts/test-kubernetes.sh fallback

# Switch to CPU mode
./kubernetes/scripts/switch-to-cpu.sh switch-cpu

# Test CPU performance
./kubernetes/scripts/benchmark-cpu.sh

# Switch back to GPU
./kubernetes/scripts/switch-to-cpu.sh switch-gpu
```

## Test Categories

### Unit Tests

#### Purpose
- Test individual components in isolation
- Verify specific functionality
- Fast feedback loop

#### Examples
```bash
# Frontend component tests
cd voice-assistant-frontend
npm test -- --testPathPattern=Button

# Backend function tests
cd agent
python -m pytest tests/test_agent_functions.py

# Service model tests
cd ollama
python -m pytest tests/test_models.py
```

### Integration Tests

#### Purpose
- Test component interactions
- Verify API endpoints
- Test data flow between services

#### Examples
```bash
# Test service integration
./scripts/test-service-integration.sh

# Test API integration
./scripts/test-api-integration.sh

# Test database integration
./scripts/test-db-integration.sh
```

### End-to-End Tests

#### Purpose
- Test complete user workflows
- Verify system behavior
- Test real-world scenarios

#### Examples
```bash
# Test voice workflow
./scripts/test-voice-workflow.sh

# Test web interface
./scripts/test-web-interface.sh

# Test mobile compatibility
./scripts/test-mobile-compatibility.sh
```

### Performance Tests

#### Purpose
- Measure response times
- Test system under load
- Identify bottlenecks

#### Examples
```bash
# Benchmark GPU performance
./kubernetes/scripts/benchmark-gpu.sh

# Test concurrent users
./scripts/test-concurrent-users.sh

# Test memory usage
./scripts/test-memory-usage.sh
```

## Test Automation

### CI/CD Integration

#### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: 3.9
    - name: Install dependencies
      run: |
        pip install -r requirements.txt
    - name: Run tests
      run: |
        python -m pytest tests/
```

#### Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit

# Set up pre-commit
pre-commit install

# Run pre-commit
pre-commit run --all-files
```

### Automated Testing Scripts

```bash
#!/bin/bash
# scripts/run-all-tests.sh

echo "Running all tests..."

# Run unit tests
echo "Running unit tests..."
./scripts/run-unit-tests.sh

# Run integration tests
echo "Running integration tests..."
./scripts/run-integration-tests.sh

# Run E2E tests
echo "Running E2E tests..."
./scripts/run-e2e-tests.sh

# Run performance tests
echo "Running performance tests..."
./scripts/run-performance-tests.sh

echo "All tests completed."
```

## Performance Testing

### GPU Performance Testing

```bash
# Benchmark GPU models
./kubernetes/scripts/benchmark-gpu.sh

# Test GPU memory usage
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi --query-gpu=memory.used,memory.total

# Monitor GPU utilization
watch -n 1 'kubectl exec -n voice-ai deployment/ollama -- nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits'
```

### Load Testing

```bash
# Test concurrent users
./scripts/test-concurrent-users.sh

# Test with JMeter
./scripts/test-jmeter.sh

# Test with k6
./scripts/test-k6.sh
```

### Response Time Testing

```bash
# Test API response times
./scripts/test-response-times.sh

# Test WebSocket performance
./scripts/test-websocket-performance.sh

# Test audio processing latency
./scripts/test-audio-latency.sh
```

## GPU Testing

### GPU Availability Testing

```bash
# Check GPU availability
./kubernetes/scripts/test-kubernetes.sh gpu

# Verify GPU device plugin
kubectl get pods -n gpu-operator

# Test GPU allocation
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"
```

### GPU Performance Testing

```bash
# Benchmark GPU models
./kubernetes/scripts/benchmark-gpu.sh

# Test GPU memory allocation
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi --query-gpu=memory.used,memory.total

# Monitor GPU temperature
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi --query-gpu=temperature.gpu
```

### GPU Stress Testing

```bash
# Stress test GPU
./scripts/stress-test-gpu.sh

# Test GPU under load
./scripts/test-gpu-load.sh

# Monitor GPU stability
watch -n 5 'kubectl exec -n voice-ai deployment/ollama -- nvidia-smi'
```

## Troubleshooting Tests

### Common Issues

#### Test Failures

```bash
# Check test logs
./kubernetes/scripts/test-kubernetes.sh 2>&1 | tee test.log

# Check pod status
kubectl get pods -n voice-ai

# Check service logs
kubectl logs -f deployment/ollama -n voice-ai
```

#### GPU Issues

```bash
# Check GPU drivers
nvidia-smi

# Check GPU device plugin
kubectl get pods -n gpu-operator

# Restart GPU services
kubectl rollout restart deployment/gpu-operator -n gpu-operator
```

#### Performance Issues

```bash
# Check resource usage
kubectl top pods -n voice-ai

# Check node resources
kubectl top nodes

# Monitor GPU usage
kubectl exec -n voice-ai deployment/ollama -- nvidia-smi
```

### Debugging Tools

#### Stern for Log Aggregation

```bash
# Install stern
curl https://get.stern.sh | sh

# View logs for all services
stern -n voice-ai .

# View logs for specific service
stern -n voice-ai ollama
```

#### K9s for Cluster Management

```bash
# Install k9s
curl -sS https://webinstall.dev/k9s | sh

# Launch k9s
k9s -n voice-ai
```

#### Lens for GUI Management

```bash
# Download and install Lens
# https://k8slens.dev/

# Connect to your cluster
# Navigate to voice-ai namespace
```

## Best Practices

### Test Organization

1. **Structure Tests**: Organize tests by category and component
2. **Naming Conventions**: Use clear, descriptive test names
3. **Test Documentation**: Document test purpose and expected results
4. **Version Control**: Keep tests under version control

### Test Data Management

1. **Test Data**: Use realistic but anonymized test data
2. **Data Cleanup**: Clean up test data after tests
3. **Data Isolation**: Isolate test data from production data
4. **Data Versioning**: Version test data alongside code

### Test Environment

1. **Consistent Environment**: Keep test environment consistent
2. **Environment Isolation**: Isolate test from production
3. **Environment Monitoring**: Monitor test environment health
4. **Environment Cleanup**: Clean up test environment after tests

### Test Reporting

1. **Test Results**: Report test results clearly
2. **Test Metrics**: Track test metrics over time
3. **Test Trends**: Monitor test trends and patterns
4. **Test Alerts**: Set up alerts for test failures

## Conclusion

This testing guide provides comprehensive testing strategies for Local Voice AI in both Docker and Kubernetes deployments. By following these guidelines, you can ensure the reliability, performance, and quality of your voice AI system.

Regular testing is essential for maintaining system health and identifying issues early. Make testing a regular part of your development workflow to ensure the best possible user experience.

For more specific testing scenarios or troubleshooting help, refer to the other documentation files or create an issue in the repository.