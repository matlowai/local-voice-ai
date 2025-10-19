# Lessons Learned and Best Practices

This document captures important lessons learned, best practices, and troubleshooting insights from developing and maintaining the Local Voice AI project. It serves as a knowledge base for both human developers and coding agents.

## 🎯 Key Lessons Learned

### 1. System Architecture Lessons

#### Microservices Communication
**Lesson**: Direct service-to-service communication works well for small-scale deployments but requires careful error handling.

**Best Practice**:
```python
# Always wrap external service calls in try-catch blocks
async def call_whisper_service(audio_data):
    try:
        response = await http_client.post("http://whisper:80/v1/transcribe", data=audio_data)
        return response.json()
    except ConnectionError:
        logger.error("Whisper service unavailable")
        return {"text": "", "error": "Service unavailable"}
    except TimeoutError:
        logger.error("Whisper service timeout")
        return {"text": "", "error": "Service timeout"}
```

**See Also**: [docs/architecture.md](architecture.md#service-communication)

#### Docker Network Configuration
**Lesson**: Container names must be resolvable within the Docker network for service communication.

**Common Issue**:
```yaml
# Incorrect - using localhost
agent:
  environment:
    - WHISPER_URL=http://localhost:11435  # Won't work!

# Correct - using container name
agent:
  environment:
    - WHISPER_URL=http://whisper:80       # Works!
```

### 2. Audio Processing Lessons

#### Real-time Audio Handling
**Lesson**: Buffer management is critical for smooth real-time audio processing.

**Best Practice**:
```python
class AudioBuffer:
    """Manages audio buffer with size limits to prevent memory issues."""
    
    def __init__(self, max_size: int = 1024 * 1024):  # 1MB limit
        self.buffer = bytearray()
        self.max_size = max_size
    
    def add_data(self, data: bytes):
        """Add data to buffer, removing old data if necessary."""
        if len(self.buffer) + len(data) > self.max_size:
            # Remove oldest data to make room
            overflow = len(self.buffer) + len(data) - self.max_size
            self.buffer = self.buffer[overflow:]
        self.buffer.extend(data)
```

#### Audio Format Compatibility
**Lesson**: Different AI services expect different audio formats and sample rates.

**Solution**: Implement audio format conversion
```python
def convert_audio_format(input_audio: bytes, target_sample_rate: int = 16000) -> bytes:
    """
    Convert audio to format expected by Whisper service.
    
    Whisper expects: 16kHz, mono, 16-bit PCM
    """
    # Implementation using audio processing library
    pass
```

### 3. Performance Optimization Lessons

#### Model Loading Strategies
**Lesson**: Loading models on startup vs. on-demand has trade-offs.

**Approach**: Load models at startup with warm-up
```python
class ModelManager:
    """Manages AI model loading and caching."""
    
    def __init__(self):
        self.models = {}
        self._load_models_on_startup()
    
    def _load_models_on_startup(self):
        """Pre-load models to avoid first-request latency."""
        logger.info("Loading models...")
        self.models["whisper"] = load_whisper_model()
        self.models["embedding"] = load_embedding_model()
        logger.info("Models loaded successfully")
```

#### Memory Management
**Lesson**: AI models consume significant memory; proper resource allocation is essential.

**Docker Configuration**:
```yaml
ollama:
  deploy:
    resources:
      limits:
        memory: 8G
      reservations:
        memory: 6G  # Ensure minimum memory available
```

### 4. Error Handling Lessons

#### Graceful Degradation
**Lesson**: Services should function even when some components are unavailable.

**Implementation**:
```python
class AgentService:
    async def process_audio(self, audio_data):
        """Process audio with fallback behavior."""
        try:
            # Try STT
            transcription = await self.stt_service.transcribe(audio_data)
        except Exception as e:
            logger.error(f"STT failed: {e}")
            transcription = "[Audio transcription failed]"
        
        try:
            # Try LLM
            response = await self.llm_service.generate(transcription)
        except Exception as e:
            logger.error(f"LLM failed: {e}")
            response = "I'm having trouble processing your request right now."
        
        try:
            # Try TTS
            audio_response = await self.tts_service.synthesize(response)
        except Exception as e:
            logger.error(f"TTS failed: {e}")
            audio_response = None
        
        return audio_response
```

## 🚨 Common Pitfalls and Solutions

### 1. Docker-related Issues

#### Port Conflicts
**Problem**: Services fail to start due to port conflicts.
**Solution**:
```bash
# Check what's using the port
netstat -tulpn | grep :3000

# Kill conflicting process
sudo kill -9 <PID>

# Or change port in docker-compose.yml
```

#### Volume Permission Issues
**Problem**: Containers can't write to mounted volumes.
**Solution**:
```dockerfile
# Create user with proper permissions
ARG UID=10001
RUN adduser --disabled-password --gecos "" --uid "${UID}" appuser
USER appuser
```

### 2. Audio Hardware Issues

#### Microphone Access
**Problem**: Browser can't access microphone.
**Solution**:
1. Check browser permissions: `chrome://settings/content/microphone`
2. Use HTTPS in production
3. Test with different browsers

#### Audio Quality
**Problem**: Poor transcription quality.
**Solution**:
```python
# Add audio preprocessing
def preprocess_audio(audio_data):
    """Apply noise reduction and normalization."""
    # Noise reduction
    # Volume normalization
    # Format conversion
    return processed_audio
```

### 3. AI Service Issues

#### Model Download Failures
**Problem**: Models fail to download on first startup.
**Solution**:
```bash
# Pre-download models manually
docker-compose exec ollama ollama pull gemma3:4b

# Or add to entrypoint script
ollama pull gemma3:4b
```

#### Service Timeouts
**Problem**: Services timeout during heavy load.
**Solution**:
```python
# Configure appropriate timeouts
HTTP_TIMEOUT = 30  # seconds

async def call_with_timeout(url, data):
    try:
        async with asyncio.timeout(HTTP_TIMEOUT):
            return await http_client.post(url, data=data)
    except TimeoutError:
        logger.error(f"Timeout calling {url}")
        raise
```

## 🔧 Best Practices

### 1. Development Best Practices

#### Environment Management
**Practice**: Use environment-specific configurations.
```python
# config.py
import os
from dataclasses import dataclass

@dataclass
class Config:
    """Configuration management with environment fallbacks."""
    
    whisper_url: str = os.getenv("WHISPER_URL", "http://whisper:80")
    ollama_url: str = os.getenv("OLLAMA_URL", "http://ollama:11434")
    debug_mode: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    def validate(self):
        """Validate configuration on startup."""
        if not self.whisper_url:
            raise ValueError("WHISPER_URL is required")
```

#### Logging Strategy
**Practice**: Structured logging with appropriate levels.
```python
import logging
import json

class JSONFormatter(logging.Formatter):
    """JSON formatter for structured logging."""
    
    def format(self, record):
        log_entry = {
            "timestamp": record.created,
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno
        }
        
        if hasattr(record, 'extra_data'):
            log_entry.update(record.extra_data)
        
        return json.dumps(log_entry)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    handlers=[logging.StreamHandler()],
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
```

### 2. Testing Best Practices

#### Service Mocking
**Practice**: Mock external services for unit testing.
```python
import pytest
from unittest.mock import AsyncMock

@pytest.fixture
def mock_whisper_service():
    """Mock Whisper service for testing."""
    service = AsyncMock()
    service.transcribe.return_value = {"text": "test transcription"}
    return service

@pytest.mark.asyncio
async def test_agent_with_mock(mock_whisper_service):
    """Test agent logic without actual service calls."""
    agent = AgentService(whisper_service=mock_whisper_service)
    result = await agent.process_audio(b"fake_audio")
    assert result is not None
```

#### Integration Testing
**Practice**: Test service interactions in Docker environment.
```python
@pytest.mark.integration
async def test_full_pipeline():
    """Test complete audio processing pipeline."""
    # Start required services
    # Send test audio
    # Verify end-to-end functionality
    pass
```

### 3. Documentation Best Practices

#### Living Documentation
**Practice**: Keep documentation in sync with code.
```python
def example_function():
    """
    This function implements the process described in:
    docs/architecture.md#data-flow-sequence
    
    If you modify this function, please update:
    - docs/services/agent.md#api-endpoints
    - docs/architecture.md#component-interactions
    """
```

#### Versioned Documentation
**Practice**: Document changes with version information.
```markdown
## Version 1.2.0 - 2025-10-19

### Added
- RAG system for document retrieval
- Enhanced error handling

### Changed
- Updated Whisper model to faster-whisper-small
- Improved audio buffer management

### Deprecated
- Old transcription format (will be removed in 2.0.0)
```

## 🎯 Performance Optimization Tips

### 1. Memory Optimization
```python
# Use generators for large datasets
def process_large_audio_file(file_path):
    """Process audio file in chunks to save memory."""
    with open(file_path, 'rb') as f:
        while chunk := f.read(1024):  # 1KB chunks
            yield process_chunk(chunk)

# Clear memory after processing
import gc
def cleanup_after_processing():
    """Force garbage collection to free memory."""
    gc.collect()
```

### 2. Latency Optimization
```python
# Parallel processing where possible
async def process_multiple_services(audio_data):
    """Call multiple services concurrently."""
    stt_task = asyncio.create_task(whisper.transcribe(audio_data))
    embedding_task = asyncio.create_task(embedder.embed(audio_data))
    
    stt_result, embedding_result = await asyncio.gather(
        stt_task, embedding_task
    )
    
    return combine_results(stt_result, embedding_result)
```

### 3. Caching Strategies
```python
from functools import lru_cache
import time

@lru_cache(maxsize=100)
def get_cached_embedding(text: str):
    """Cache embeddings to avoid recomputation."""
    return embed_model.encode([text])[0]

# Time-based cache invalidation
class TimedCache:
    def __init__(self, ttl_seconds: int = 3600):
        self.cache = {}
        self.ttl = ttl_seconds
    
    def get(self, key):
        if key in self.cache:
            value, timestamp = self.cache[key]
            if time.time() - timestamp < self.ttl:
                return value
        return None
```

## 🔍 Debugging Techniques

### 1. Service Health Monitoring
```python
async def check_service_health(service_url: str) -> bool:
    """Check if service is responding."""
    try:
        async with http_client.get(f"{service_url}/health", timeout=5) as response:
            return response.status == 200
    except Exception:
        return False

# Health check endpoint
@app.get("/health")
async def health_check():
    """Return service health status."""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "version": "1.0.0"
    }
```

### 2. Performance Profiling
```python
import time
from functools import wraps

def timing_decorator(func):
    """Decorator to measure function execution time."""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        result = await func(*args, **kwargs)
        end_time = time.time()
        
        logger.info(f"{func.__name__} took {end_time - start_time:.2f} seconds")
        return result
    return wrapper

@timing_decorator
async def slow_function():
    """Function whose performance we want to monitor."""
    await asyncio.sleep(1)
    return "done"
```

### 3. Debug Logging
```python
# Enable debug logging selectively
if os.getenv("DEBUG_MODE") == "true":
    logging.getLogger().setLevel(logging.DEBUG)
    
    # Add debug endpoints
    @app.get("/debug/info")
    async def debug_info():
        """Return debug information."""
        return {
            "environment": os.environ,
            "memory_usage": psutil.virtual_memory()._asdict(),
            "active_connections": len(active_connections)
        }
```

## 📚 Recommended Resources

### Documentation
- [LiveKit Agents Documentation](https://docs.livekit.io/agents/)
- [Ollama Documentation](https://ollama.com/documentation)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Tools
- **Docker Compose**: For multi-container orchestration
- **pytest-asyncio**: For async testing
- **black**: For code formatting
- **mypy**: For type checking

### Monitoring
- **Prometheus**: For metrics collection
- **Grafana**: For visualization
- **ELK Stack**: For log aggregation

---

*This document is continuously updated as new lessons are learned. Please contribute your insights and experiences to help future developers.*