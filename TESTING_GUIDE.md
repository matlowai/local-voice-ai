# Comprehensive Testing Guide for Local Voice AI

This guide provides step-by-step instructions to test your complete Local Voice AI setup, including the Python 3.12.9 updates, fork configuration, documentation system, and validation scripts.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Documentation System Testing](#documentation-system-testing)
3. [Local Development Testing](#local-development-testing)
4. [Git Workflow Testing](#git-workflow-testing)
5. [End-to-End Voice Assistant Testing](#end-to-end-voice-assistant-testing)
6. [Performance Testing](#performance-testing)
7. [Troubleshooting](#troubleshooting)
8. [Testing Checklist](#testing-checklist)

## Prerequisites

Before starting, ensure you have:

- Docker and Docker Compose installed
- Python 3.12.9 (for local testing)
- Git configured with your fork
- At least 12GB of RAM available
- VS Code (optional, for Git workflow testing)

## Documentation System Testing

The documentation validation script ensures all documentation is consistent, up-to-date, and properly referenced.

### Basic Validation

```bash
# Run basic documentation validation
python3 scripts/validate-docs.py
```

**Expected Output:**
```
🔍 Validating Local Voice AI documentation...
==================================================

📁 Checking required files...
  ✅ index.md
  ✅ architecture.md
  ✅ development-workflow.md
  ✅ coding-standards.md
  ✅ lessons-learned.md
  ✅ services/agent.md
  ✅ services/whisper.md
  ✅ services/ollama.md
  ✅ services/kokoro.md
  ✅ services/livekit.md
  ✅ services/frontend.md

🔗 Validating cross-references...
📝 Validating markdown links...
🐍 Validating docstring standards...

==================================================
📊 VALIDATION RESULTS
==================================================

✅ All checks passed! Documentation is valid.

📈 Summary: 0 errors, 0 warnings
```

### Timestamp Validation

```bash
# Check if documentation is newer than source code
python3 scripts/validate-docs.py --check-timestamps
```

**Expected Output:**
```
⏰ Validating documentation timestamps...
ℹ️  INFO (5):
  • Documentation current: services/agent.md is up to date with agent/myagent.py
  • Documentation current: services/whisper.md is up to date with whisper/Dockerfile
  • Documentation current: services/ollama.md is up to date with ollama/Dockerfile
  • Documentation current: architecture.md is up to date with docker-compose.yml
  • Documentation current: index.md is up to date with README.md
```

### Strict Timestamp Validation

```bash
# Strict timestamp checking (treat outdated docs as errors)
python3 scripts/validate-docs.py --check-timestamps --strict
```

**Expected Output:**
```
⏰ Validating documentation timestamps...

==================================================
📊 VALIDATION RESULTS
==================================================

✅ No errors found. 0 warnings to review.

📈 Summary: 0 errors, 0 warnings
```

### Updating Timestamps

If documentation is outdated, you can update timestamps:

```bash
# Update documentation timestamps after validation
python3 scripts/validate-docs.py --check-timestamps --update-timestamps
```

**Expected Output:**
```
⏰ Validating documentation timestamps...
📝 Updating 2 documentation file timestamps...
ℹ️  INFO (2):
  • Updated timestamp for services/agent.md
  • Updated timestamp for services/whisper.md
```

## Local Development Testing

### Full Stack Testing

```bash
# Test the complete application stack
./test.sh
```

**Expected Output:**
```
🧹 Cleaning up any existing containers...
[+] Running 0/0
✔ Container local-voice-ai-whisper-1  Removed
...

📦 Building and starting all services...
[+] Building 0/0
[+] Building agent (0.1s)
[+] Building frontend (0.1s)
...
[+] Running 6/6
✔ Container local-voice-ai-livekit-1    Started
✔ Container local-voice-ai-kokoro-1     Started
✔ Container local-voice-ai-whisper-1    Started
✔ Container local-voice-ai-ollama-1     Started
✔ Container local-voice-ai-agent-1      Started
✔ Container local-voice-ai-frontend-1   Started
```

After running `test.sh`, you should see all containers running without errors. Press `Ctrl+C` to stop the containers.

### Individual Component Testing

```bash
# Clean up any existing containers
docker-compose down -v --remove-orphans

# Build and start services individually
docker-compose up --build
```

**Expected Container Status:**
- `kokoro`: Running on port 8880
- `livekit`: Running on ports 7880, 7881
- `whisper`: Running on port 11435
- `ollama`: Running on port 11434
- `agent`: Connected to all services
- `frontend`: Running on port 3000

### Container Health Checks

```bash
# Check container status
docker-compose ps

# Check container logs for errors
docker-compose logs agent
docker-compose logs ollama
docker-compose logs whisper
docker-compose logs kokoro
docker-compose logs livekit
docker-compose logs frontend
```

**Expected Output for `docker-compose ps`:**
```
NAME                          COMMAND                  SERVICE             STATUS              PORTS
local-voice-ai-agent-1        "python myagent.py"      agent               running (healthy)   
local-voice-ai-frontend-1     "docker-entrypoint.s…"   frontend            running (healthy)   0.0.0.0:3000->3000/tcp
local-voice-ai-kokoro-1       "uvicorn main:app --…"   kokoro              running (healthy)   0.0.0.0:8880->8880/tcp
local-voice-ai-livekit-1      "/livekit-server --d…"   livekit             running (healthy)   0.0.0.0:7880->7880/tcp, 0.0.0.0:7881->7881/tcp
local-voice-ai-ollama-1       "./entrypoint.sh"        ollama              running (healthy)   0.0.0.0:11434->11434/tcp
local-voice-ai-whisper-1       "python -m vox_box"     whisper             running (healthy)   0.0.0.0:11435->80/tcp
```

## Git Workflow Testing

### Verify Fork Configuration

```bash
# Check your remote configuration
git remote -v
```

**Expected Output:**
```
origin	https://github.com/matlowai/local-voice-ai.git (fetch)
origin	https://github.com/matlowai/local-voice-ai.git (push)
upstream	https://github.com/ShayneP/local-voice-ai.git (fetch)
upstream	https://github.com/ShayneP/local-voice-ai.git (push)
```

### Check Branch Tracking

```bash
# Verify branch tracking
git branch -vv
```

**Expected Output:**
```
* main abc1234f [origin/main] Your latest commit message
```

### Test Sync with Upstream

```bash
# Fetch latest changes from upstream
git fetch upstream

# Check for new changes
git log --oneline --graph --all --decorate
```

### Test Pushing to Fork

```bash
# Create a test branch
git checkout -b test/sync-validation

# Make a small change
echo "# Test Change" >> TEST_SYNC.md

# Commit and push to your fork
git add TEST_SYNC.md
git commit -m "Test: Verify sync to fork works"
git push origin test/sync-validation

# Clean up (optional)
git checkout main
git branch -D test/sync-validation
```

**Expected Output:**
```
Enumerating objects: 4, done.
Counting objects: 100% (4/4), done.
Delta compression using up to 8 threads
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 282 bytes | 282.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0
To https://github.com/matlowai/local-voice-ai.git
 * [new branch]      test/sync-validation -> test/sync-validation
```

### VS Code Integration Test

1. Open VS Code
2. Make a small change to any file
3. Use the Source Control view to commit the change
4. Click the "Sync Changes" button
5. Verify the change appears in your fork on GitHub

## End-to-End Voice Assistant Testing

### 1. Verify Frontend Access

Open your browser and navigate to: [http://localhost:3000](http://localhost:3000)

**Expected:**
- The voice assistant interface loads
- No error messages in the browser console
- Microphone permission request appears when you click the microphone button

### 2. Test Service Connectivity

Check that all services are communicating:

```bash
# Test LiveKit connection
curl http://localhost:7880

# Test Ollama connection
curl http://localhost:11434/api/tags

# Test Whisper connection
curl http://localhost:11435/health

# Test Kokoro connection
curl http://localhost:8880/health
```

**Expected Output for Ollama:**
```json
{
  "models": [
    {
      "name": "gemma2:9b",
      "modified_at": "2024-01-01T00:00:00.000000Z",
      "size": 1234567890,
      "digest": "sha256:...",
      "details": {
        "format": "gguf",
        "family": "gemma",
        "families": null,
        "parameter_size": "9b",
        "quantization_level": "q4_0"
      }
    }
  ]
}
```

### 3. Test Voice Input/Output Pipeline

1. **Grant Microphone Permission**
   - Click the microphone button in the UI
   - Allow browser access to your microphone

2. **Test Speech-to-Text**
   - Speak clearly into the microphone
   - Verify your speech appears as text in the interface

3. **Test LLM Processing**
   - After speaking, wait for the agent to process
   - Check the agent logs: `docker-compose logs -f agent`

4. **Test Text-to-Speech**
   - Verify the agent responds with voice
   - Check that the audio plays through your speakers

### 4. Test RAG Functionality

The agent should use documents in the `agent/docs/` directory for enhanced responses:

```bash
# Check what documents are loaded
docker-compose exec agent ls -la /app/docs/
```

**Expected Output:**
```
total 24
drwxr-xr-x 1 root root 4096 Jan  1 00:00 .
drwxr-xr-x 1 root root 4096 Jan  1 00:00 ..
-rw-r--r-- 1 root root 1234 Jan  1 00:00 doc.txt
-rw-r--r-- 1 root root 5678 Jan  1 00:00 llm.txt
-rw-r--r-- 1 root root 9012 Jan  1 00:00 search.txt
-rw-r--r-- 1 root root 3456 Jan  1 00:00 stt.txt
-rw-r--r-- 1 root root 7890 Jan  1 00:00 tts.txt
```

## Performance Testing

### Memory Usage Check

```bash
# Check memory usage of all containers
docker stats --no-stream
```

**Expected Output:**
```
CONTAINER ID   NAME                  CPU %     MEM USAGE / LIMIT     MEM %
abc123def456   local-voice-ai-agent-1    5.2%     512MiB / 12GiB       4.2%
def456ghi789   local-voice-ai-ollama-1   10.5%    6GiB / 12GiB         50.0%
ghi789jkl012   local-voice-ai-whisper-1  8.3%     1GiB / 12GiB         8.3%
...
```

### Response Time Testing

1. **Cold Start Test**
   - Stop all containers: `docker-compose down`
   - Restart with: `./test.sh`
   - Time how long it takes for all services to be ready (should be < 2 minutes)

2. **Voice Response Latency**
   - Speak a simple question
   - Measure time from end of speech to start of agent response
   - Should be < 10 seconds for simple queries

## Troubleshooting

### Common Issues and Solutions

#### 1. Documentation Validation Errors

**Issue:** "Invalid reference in file.md"
**Solution:**
```bash
# Fix broken references
python3 scripts/fix-docs-references.py

# Re-run validation
python3 scripts/validate-docs.py
```

#### 2. Container Build Failures

**Issue:** Docker build fails for a service
**Solution:**
```bash
# Check build logs
docker-compose build --no-cache agent

# Rebuild specific service
docker-compose up --build --force-recreate agent
```

#### 3. Port Conflicts

**Issue:** "Port already in use" errors
**Solution:**
```bash
# Find what's using the port
sudo lsof -i :3000  # Replace with conflicting port

# Kill the process
sudo kill -9 <PID>

# Or change ports in docker-compose.yml
```

#### 4. Ollama Model Not Loading

**Issue:** Ollama can't find the model
**Solution:**
```bash
# Check available models
docker-compose exec ollama ollama list

# Pull required model
docker-compose exec ollama ollama pull gemma2:9b
```

#### 5. Microphone Not Working

**Issue:** Voice input not detected
**Solution:**
1. Check browser microphone permissions
2. Verify microphone works with other apps
3. Check browser console for errors
4. Try a different browser (Chrome/Edge recommended)

#### 6. Agent Not Responding

**Issue:** Agent processes but doesn't respond
**Solution:**
```bash
# Check agent logs
docker-compose logs agent

# Check if agent is connected to LiveKit
docker-compose exec agent curl http://livekit:7880
```

### Debug Mode

For detailed debugging, enable verbose logging:

```bash
# Set environment variables for debug mode
export DEBUG=true
export LOG_LEVEL=debug

# Restart with debug logging
docker-compose down
docker-compose up --build
```

## Testing Checklist

Use this checklist to verify your complete setup is working:

- [ ] **Documentation Validation**
  - [ ] Basic validation passes: `python3 scripts/validate-docs.py`
  - [ ] Timestamp validation passes: `python3 scripts/validate-docs.py --check-timestamps`
  - [ ] Strict validation passes: `python3 scripts/validate-docs.py --check-timestamps --strict`
  - [ ] All required documentation files exist
  - [ ] All cross-references are valid

- [ ] **Container Infrastructure**
  - [ ] All containers build successfully: `./test.sh`
  - [ ] All services start without errors
  - [ ] Container health checks pass
  - [ ] Memory usage is within limits
  - [ ] No port conflicts

- [ ] **Service Connectivity**
  - [ ] LiveKit server responds on port 7880
  - [ ] Ollama API responds on port 11434
  - [ ] Whisper service responds on port 11435
  - [ ] Kokoro TTS responds on port 8880
  - [ ] Frontend loads on port 3000

- [ ] **Voice Assistant Pipeline**
  - [ ] Frontend loads correctly in browser
  - [ ] Microphone permission works
  - [ ] Speech-to-text converts voice to text
  - [ ] LLM processes queries correctly
  - [ ] Text-to-speech generates audio responses
  - [ ] RAG functionality uses documents

- [ ] **Git Workflow**
  - [ ] Fork remote points to correct repository
  - [ ] Upstream remote points to original repository
  - [ ] Main branch tracks origin/main
  - [ ] Can push changes to fork
  - [ ] Can pull changes from upstream
  - [ ] VS Code sync button works

- [ ] **Performance**
  - [ ] Cold start time < 2 minutes
  - [ ] Voice response latency < 10 seconds
  - [ ] Memory usage stays within limits
  - [ ] No significant CPU spikes during normal operation

## Final Verification

After completing all tests, run this final verification script:

```bash
#!/bin/bash
echo "🧪 Running final verification tests..."

# 1. Documentation validation
echo "1. Testing documentation validation..."
python3 scripts/validate-docs.py --check-timestamps --strict
if [ $? -ne 0 ]; then
    echo "❌ Documentation validation failed"
    exit 1
fi

# 2. Container health
echo "2. Checking container health..."
docker-compose ps | grep -q "Up (healthy)"
if [ $? -ne 0 ]; then
    echo "❌ Some containers are not healthy"
    docker-compose ps
    exit 1
fi

# 3. Service connectivity
echo "3. Testing service connectivity..."
curl -s http://localhost:3000 > /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Frontend not accessible"
    exit 1
fi

curl -s http://localhost:11434/api/tags > /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Ollama not accessible"
    exit 1
fi

# 4. Git configuration
echo "4. Verifying Git configuration..."
git remote -v | grep -q "origin.*matlowai"
if [ $? -ne 0 ]; then
    echo "❌ Origin remote not configured correctly"
    exit 1
fi

git remote -v | grep -q "upstream.*ShayneP"
if [ $? -ne 0 ]; then
    echo "❌ Upstream remote not configured correctly"
    exit 1
fi

echo "✅ All verification tests passed!"
echo "🎉 Your Local Voice AI setup is ready to use!"
```

Save this as `verify-setup.sh` and run it to confirm everything is working:

```bash
chmod +x verify-setup.sh
./verify-setup.sh
```

If all tests pass, your Local Voice AI setup is fully functional and ready for use!