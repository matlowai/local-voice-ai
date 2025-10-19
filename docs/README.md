# Local Voice AI Documentation System

This directory contains the comprehensive documentation system for the Local Voice AI project.

## 📚 Documentation Structure

```
docs/
├── README.md                    # This file - Documentation system overview
├── index.md                     # Main navigation and project overview
├── architecture.md              # System architecture and component connections
├── development-workflow.md      # Development guidelines and procedures
├── coding-standards.md          # Docstring standards and documentation practices
├── lessons-learned.md           # Important lessons and best practices
├── maintenance-guide.md         # Documentation maintenance procedures
└── services/                    # Service-specific documentation
    ├── agent.md                 # Agent service documentation
    ├── whisper.md               # Whisper STT service
    ├── ollama.md                # Ollama LLM service
    ├── kokoro.md                # Kokoro TTS service
    ├── livekit.md               # LiveKit WebRTC signaling
    └── frontend.md              # Next.js frontend
```

## 🚀 Quick Start

1. **Start Here**: Read [`index.md`](index.md) for project overview
2. **For Developers**: Read [`development-workflow.md`](development-workflow.md)
3. **For Coding Agents**: Read [`coding-standards.md`](coding-standards.md) first
4. **Architecture**: Read [`architecture.md`](architecture.md) to understand the system

## 🔧 Documentation Validation

The project includes automated validation to ensure documentation quality:

```bash
# Run validation
python3 scripts/validate-docs.py

# Run with strict mode (treat warnings as errors)
python3 scripts/validate-docs.py --strict
```

### Validation Checks

- ✅ **Required Files**: Ensures all documentation files exist
- ✅ **Cross-References**: Validates all internal links and references
- ✅ **Markdown Links**: Checks for malformed markdown links
- ⚠️ **Docstring Standards**: Validates docstring compliance (warnings only)

## 📝 For Coding Agents

### Required Reading Order

1. [`coding-standards.md`](coding-standards.md) - **Mandatory**
2. [`development-workflow.md`](development-workflow.md) - **Mandatory**
3. [`architecture.md`](architecture.md) - **Recommended**
4. Service-specific documentation as needed

### Documentation Update Process

After making code changes:

1. **Update docstrings** following templates in [`coding-standards.md`](coding-standards.md)
2. **Update service documentation** in [`services/`](services/index.md) directory
3. **Update cross-references** if system design changed
4. **Run validation**: `python3 scripts/validate-docs.py`
5. **Fix any errors** before committing

### Docstring Template

```python
def function_name(param1: str, param2: int) -> bool:
    """
    Brief description of the function's purpose.
    
    Detailed description explaining the function's behavior,
    algorithms, and important implementation details.
    
    Args:
        param1: Description of parameter 1.
        param2: Description of parameter 2.
    
    Returns:
        Description of return value.
    
    Raises:
        ValueError: When param1 is invalid.
    
    Example:
        >>> result = function_name("test", 42)
        >>> print(result)
        True
    
    See Also:
        related_function: Function that complements this one
        docs/services/service-name.md: Service documentation
    
    References:
        docs/architecture.md: System architecture
    """
```

## 🔗 Cross-Reference Standards

### Internal Links
```markdown
# Use relative paths
See [Agent Service](services/agent.md) for details.

# Use anchors for sections
See [API Reference](services/agent.md#api-reference).

# Reference specific sections
See [docs/architecture.md#data-flow-sequence](architecture.md#data-flow-sequence).
```

### Code References
```markdown
# Reference specific files
See [`agent/myagent.py`](../agent/myagent.py:1) for implementation.

# Reference specific lines
See [`docker-compose.yml`](../docker-compose.yml:44-50) for configuration.

# Reference functions
See [`LocalAgent.__init__()`](../agent/myagent.py:57) for initialization.
```

## 🛠️ Maintenance

### Regular Tasks

- **Weekly**: Run validation to check for issues
- **After Changes**: Update relevant documentation
- **Monthly**: Review and update outdated information

### Tools

- **Validation Script**: [`scripts/validate-docs.py`](../scripts/validate-docs.py)
- **Fix Script**: [`scripts/fix-docs-references.py`](../scripts/fix-docs-references.py)
- **Maintenance Guide**: [`maintenance-guide.md`](maintenance-guide.md)

### Integration

Add to your development workflow:

```bash
# Pre-commit hook
python3 scripts/validate-docs.py --strict

# CI/CD integration
python3 scripts/validate-docs.py --strict
```

## 📊 Documentation Quality

### Metrics

- **Coverage**: All services documented
- **Cross-References**: All links validated
- **Standards**: Docstring templates provided
- **Maintenance**: Automated validation tools

### Goals

- ✅ **Complete**: All aspects of the system documented
- ✅ **Accurate**: Documentation matches implementation
- ✅ **Accessible**: Easy to navigate and understand
- ✅ **Maintainable**: Automated validation and update procedures

## 🤝 Contributing

### Adding New Documentation

1. Create new file in appropriate directory
2. Follow existing structure and style
3. Add cross-references to related content
4. Update [`index.md`](index.md) if needed
5. Run validation to check for issues

### Updating Existing Documentation

1. Make changes following established patterns
2. Update cross-references if needed
3. Test all examples and links
4. Run validation to ensure consistency

## 📞 Support

For questions about the documentation system:

1. Check [`maintenance-guide.md`](maintenance-guide.md) for procedures
2. Review [`coding-standards.md`](coding-standards.md) for formatting
3. Run validation to identify specific issues
4. Check existing documentation for examples

---

*This documentation system is designed to evolve with the project. All contributors, both human and AI, should help maintain its accuracy and completeness.*