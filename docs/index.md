# Local Voice AI Documentation

<div align="center">
  <img src="../voice-assistant-frontend/.github/assets/app-icon.png" alt="App Icon" width="80" />
  <h1>🧠 Local Voice AI</h1>
  <p>Comprehensive documentation for the Local Voice AI project</p>
</div>

## 📚 Documentation Navigation

This documentation system provides comprehensive guidance for understanding, developing, and maintaining the Local Voice AI project. It's designed to help both human developers and coding agents work effectively with the codebase.

### 🏗️ Core Documentation

| Document | Description | For Coding Agents |
|----------|-------------|-------------------|
| [Architecture](architecture.md) | System architecture, component connections, and data flows | **Required Reading** |
| [Development Workflow](development-workflow.md) | Development guidelines, procedures, and best practices | **Required Reading** |
| [Coding Standards](coding-standards.md) | Docstring standards, documentation practices, and code style | **Required Reading** |
| [Lessons Learned](lessons-learned.md) | Important lessons, best practices, and troubleshooting | **Recommended** |

### 🔧 Service Documentation

| Service | Documentation | Description |
|---------|---------------|-------------|
| [Agent Service](services/agent.md) | [docs/services/agent.md](services/agent.md) | Python voice agent with LiveKit SDK |
| [Whisper STT](services/whisper.md) | [docs/services/whisper.md](services/whisper.md) | Speech-to-text via vox-box |
| [Ollama LLM](services/ollama.md) | [docs/services/ollama.md](services/ollama.md) | Local language model inference |
| [Kokoro TTS](services/kokoro.md) | [docs/services/kokoro.md](services/kokoro.md) | Text-to-speech synthesis |
| [LiveKit](services/livekit.md) | [docs/services/livekit.md](services/livekit.md) | WebRTC signaling server |
| [Frontend](services/frontend.md) | [docs/services/frontend.md](services/frontend.md) | Next.js React client |

## 🚀 Quick Start

1. **For Human Developers**: Start with [Architecture](architecture.md) to understand the system
2. **For Coding Agents**: Start with [Coding Standards](coding-standards.md) for documentation requirements
3. **For Troubleshooting**: Check [Lessons Learned](lessons-learned.md) for common issues

## 🎯 Project Overview

The Local Voice AI project is a Dockerized, real-time AI voice assistant system that enables natural voice conversations with AI. The system processes speech through multiple AI services and provides responses through voice synthesis.

### Key Features

- 🎙️ **Real-time Voice Processing**: Low-latency speech-to-text and text-to-speech
- 🧠 **Local AI Processing**: All AI models run locally (no cloud dependencies)
- 🔍 **RAG Support**: Retrieval-Augmented Generation for knowledge-based responses
- 🐳 **Dockerized**: Fully containerized for easy deployment
- 🌐 **Web-based Interface**: Accessible through any modern browser

### Technology Stack

- **Backend**: Python with LiveKit Agents SDK
- **Frontend**: Next.js, React, Tailwind CSS
- **AI Models**: Whisper (STT), Ollama (LLM), Kokoro (TTS)
- **Communication**: WebRTC via LiveKit
- **Infrastructure**: Docker Compose

## 📋 System Requirements

- Docker + Docker Compose
- 12GB+ RAM recommended
- No GPU required (CPU-based models)
- Modern web browser with WebRTC support

## 🔗 Important Links

- [GitHub Repository](https://github.com/ShayneP/local-voice-ai)
- [LiveKit Documentation](https://docs.livekit.io/)
- [Ollama Documentation](https://ollama.com/documentation)
- [Docker Documentation](https://docs.docker.com/)

## 📝 Documentation Maintenance

This documentation is designed to be maintained alongside the codebase. All coding agents working on this project should:

1. Read the [Coding Standards](coding-standards.md) before making changes
2. Update relevant documentation after implementing features
3. Follow the docstring standards for all new code
4. Validate documentation links and references

## 🤖 For Coding Agents

If you're a coding agent working on this project, please follow these steps:

1. **First**: Read [Coding Standards](coding-standards.md) for documentation requirements
2. **Second**: Read [Development Workflow](development-workflow.md) for procedures
3. **Third**: Review [Architecture](architecture.md) to understand the system
4. **Then**: Proceed to service-specific documentation as needed

---

*This documentation is part of the Local Voice AI project. Last updated: 2025-10-19*