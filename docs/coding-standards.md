# Coding Standards and Documentation Practices

This document defines the coding standards, docstring requirements, and documentation practices for the Local Voice AI project. It is **essential reading for all coding agents** working on this project.

## 🤖 Instructions for Coding Agents

### BEFORE MAKING ANY CHANGES
1. **Read this entire document** - Understand all requirements
2. **Read [Development Workflow](development-workflow.md)** - Understand the process
3. **Read relevant service documentation** - Understand the specific service
4. **Review existing code** - Understand current patterns and style

### AFTER MAKING CHANGES
1. **Update all docstrings** - Follow the templates below
2. **Update service documentation** - Keep docs in sync with code
3. **Update cross-references** - Ensure all links work
4. **Validate documentation** - Test all examples and links

## 📝 Docstring Standards

### Python Docstring Format

All Python functions, classes, and methods MUST use the following docstring format:

```python
def function_name(param1: str, param2: int, param3: Optional[dict] = None) -> bool:
    """
    Brief description of the function's purpose.
    
    Detailed description explaining the function's behavior, algorithms,
    and any important implementation details. Include context about
    how this function fits into the larger system.
    
    Args:
        param1: Description of parameter 1. Include type info and valid ranges.
        param2: Description of parameter 2. Explain constraints and default behavior.
        param3: Optional description of parameter 3. Explain when None is used.
    
    Returns:
        Description of return value. Include type information and possible values.
        Explain error conditions and exceptions.
    
    Raises:
        ValueError: When param1 is invalid or out of expected range.
        ConnectionError: When external service is unavailable.
    
    Example:
        >>> result = function_name("test", 42)
        >>> print(result)
        True
    
    Note:
        Additional implementation notes, performance considerations,
        or usage patterns. Include references to related functions
        or documentation.
    
    See Also:
        related_function: Function that complements this one
        docs/services/agent.md: Service-specific documentation
    
    References:
        docs/architecture.md: System architecture overview
        https://example.com/api: External API documentation
    """
    # Implementation here
    pass
```

### Class Docstring Format

```python
class ClassName:
    """
    Brief description of the class's purpose and role in the system.
    
    Detailed description of the class's responsibilities, design patterns,
    and how it interacts with other components. Include information about
    the class's lifecycle and state management.
    
    This class is part of the Agent service and handles communication
    with external AI services. It manages connections, processes requests,
    and handles error conditions gracefully.
    
    Attributes:
        attr1: Description of attribute 1 and its purpose.
        attr2: Description of attribute 2 and default values.
        _private_attr: Description of private attribute.
    
    Example:
        >>> instance = ClassName(param1="value")
        >>> result = instance.method()
        >>> print(result)
        "expected_output"
    
    Note:
        Include usage patterns, initialization requirements,
        and important considerations for developers.
    
    See Also:
        RelatedClass: Class that works with this one
        docs/services/agent.md: Agent service documentation
    """
    
    def __init__(self, param1: str):
        """
        Initialize the ClassName instance.
        
        Args:
            param1: Description of initialization parameter.
        """
        self.attr1 = param1
```

### Async Function Docstring Format

```python
async def async_function(param1: str) -> dict:
    """
    Asynchronous function description.
    
    Detailed description of the async operation, including what
    operations are performed concurrently and how the function
    handles cancellation or timeouts.
    
    Args:
        param1: Description of parameter.
    
    Returns:
        Dictionary containing the operation results.
        Structure: {"status": str, "data": any, "error": Optional[str]}
    
    Raises:
        asyncio.TimeoutError: When operation exceeds timeout limit.
        ConnectionError: When external service is unavailable.
    
    Example:
        >>> result = await async_function("test")
        >>> print(result["status"])
        "success"
    
    Note:
        This function is non-blocking and should be awaited.
        Consider using asyncio.gather() for multiple concurrent calls.
    """
    # Async implementation here
    pass
```

## 🔗 Cross-Reference Standards

### Documentation References in Docstrings

All docstrings MUST include relevant documentation references:

```python
def process_audio(audio_data: bytes) -> str:
    """
    Process audio data using the Whisper STT service.
    
    This function sends audio data to the Whisper service for
    speech-to-text conversion. It handles network communication,
    error conditions, and response parsing.
    
    Args:
        audio_data: Raw audio bytes in format supported by Whisper.
    
    Returns:
        Transcribed text string.
    
    See Also:
        docs/services/whisper.md: Whisper service documentation
        docs/services/agent.md: Agent service orchestration
        docs/architecture.md: System data flow
    """
```

### Code-to-Documentation Mapping

Maintain clear mappings between code and documentation:

```python
# This function implements the RAG retrieval process described in:
# docs/architecture.md#rag-retrieval-augmented-generation-flow

async def retrieve_context(query: str) -> str:
    """
    Retrieve relevant context for the query using RAG system.
    
    Implements the retrieval process documented in the architecture.
    See: docs/architecture.md#rag-retrieval-augmented-generation-flow
    """
```

## 📁 File Organization Standards

### Python File Structure

```python
#!/usr/bin/env python3
"""
Module brief description.

Detailed module description explaining its purpose in the system
and how it relates to other modules.

This module is part of the Agent service and handles...
See: docs/services/agent.md

Author: [Author name or "AI Agent"]
Date: [YYYY-MM-DD]
Version: [version number]
"""

# Standard library imports
import asyncio
import logging
from typing import Optional, Dict, List

# Third-party imports
from livekit.agents import JobContext
import faiss

# Local imports
from .utils import helper_function
from .config import SETTINGS

# Module constants
CONSTANT_VALUE = "default"

# Module logger
logger = logging.getLogger(__name__)

class ExampleClass:
    """Class description following docstring standards."""
    
    def __init__(self):
        """Initialize the class."""
        pass

def example_function():
    """Function description following docstring standards."""
    pass
```

### TypeScript/React File Structure

```typescript
/**
 * Component brief description.
 * 
 * Detailed component description explaining its purpose,
 * props, and behavior in the application.
 * 
 * This component is part of the Frontend service and handles...
 * See: docs/services/frontend.md
 * 
 * @author [Author name or "AI Agent"]
 * @date [YYYY-MM-DD]
 * @version [version number]
 */

import React, { useState, useEffect } from 'react';
import { SomeComponent } from '@/components/SomeComponent';
import { useSomeHook } from '@/hooks/useSomeHook';

interface ComponentProps {
  /** Description of prop1 */
  prop1: string;
  /** Description of prop2 with default value */
  prop2?: number;
  /** Description of optional callback function */
  onCallback?: (data: any) => void;
}

/**
 * Component description following JSDoc standards.
 * 
 * This component handles the transcription display and manages
 * the real-time updates from the LiveKit connection.
 * 
 * @param props - Component props as defined in ComponentProps
 * @returns JSX element for the transcription view
 * 
 * @example
 * ```tsx
 * <TranscriptionView 
 *   prop1="example" 
 *   prop2={42}
 *   onCallback={(data) => console.log(data)}
 * />
 * ```
 * 
 * @see docs/services/frontend.md for implementation details
 * @see docs/architecture.md for system context
 */
export default function TranscriptionView(props: ComponentProps) {
  // Component implementation
  return <div>Component JSX</div>;
}
```

## 🎯 Coding Style Guidelines

### Python Style Guide

1. **Follow PEP 8** with 79-character line limit
2. **Use type hints** for all function parameters and return values
3. **Use descriptive variable names** - avoid single letters except for loops
4. **Use underscores** for private methods and attributes
5. **Include logging** for important operations and error conditions

```python
# Good
async def process_transcription_result(
    transcription_data: Dict[str, Any],
    confidence_threshold: float = 0.8
) -> Optional[str]:
    """
    Process transcription result with confidence filtering.
    
    Args:
        transcription_data: Dictionary containing transcription results.
        confidence_threshold: Minimum confidence score to accept result.
    
    Returns:
        Filtered transcription text or None if below threshold.
    """
    if transcription_data.get("confidence", 0) < confidence_threshold:
        logger.warning(f"Low confidence transcription: {transcription_data}")
        return None
    
    return transcription_data.get("text", "")

# Bad
async def proc(data, th=0.8):
    if data["conf"] < th:
        return None
    return data["t"]
```

### TypeScript/React Style Guide

1. **Use TypeScript** for all new code
2. **Use functional components** with hooks
3. **Use descriptive component and prop names**
4. **Include JSDoc comments** for all components and functions
5. **Use proper error boundaries** and loading states

```typescript
// Good
interface TranscriptionSegment {
  id: string;
  text: string;
  timestamp: Date;
  confidence: number;
}

interface TranscriptionViewProps {
  segments: TranscriptionSegment[];
  isLoading: boolean;
  onError: (error: Error) => void;
}

/**
 * Displays real-time transcription segments with confidence indicators.
 */
export default function TranscriptionView({
  segments,
  isLoading,
  onError
}: TranscriptionViewProps) {
  // Implementation
}

// Bad
function TV({ segs, load, err }) {
  // Implementation
}
```

## 📚 Documentation Maintenance

### Required Documentation Updates

After making code changes, update these documentation files:

1. **Service Documentation**: Update relevant files in `docs/services/`
2. **Architecture Documentation**: Update `docs/architecture.md` if system design changes
3. **API Documentation**: Update endpoint documentation if APIs change
4. **Examples**: Update code examples in documentation

### Documentation Validation

Use this checklist before committing:

```bash
# 1. Check all docstrings follow the format
grep -r "def " . --include="*.py" | wc -l  # Count functions
grep -r '"""' . --include="*.py" | wc -l   # Count docstrings
# Numbers should match

# 2. Check documentation references
grep -r "docs/" . --include="*.py"         # Verify references exist

# 3. Test code examples
python -m doctest your_module.py          # Test doctests

# 4. Check links in documentation
# Use markdown link checker or manual verification
```

## 🔄 Context Management for Coding Agents

### Understanding Project Context

Before making changes, coding agents should:

1. **Read the architecture documentation** to understand system design
2. **Review service-specific documentation** for the component being modified
3. **Examine existing code patterns** to maintain consistency
4. **Check for dependencies** between services

### Maintaining Context During Development

1. **Keep documentation open** while coding
2. **Update docstrings immediately** after implementing functions
3. **Add cross-references** to related documentation
4. **Test examples** in documentation to ensure they work

### Context Preservation

```python
# When adding new functionality, always include context:
def new_feature_function():
    """
    Implements the new feature described in the GitHub issue #123.
    
    This function is part of the Agent service and integrates with
    the Whisper STT service for audio processing.
    
    See: docs/services/agent.md#new-feature-section
    See: docs/services/whisper.md#api-endpoints
    """
```

## 📋 Code Review Checklist

### For Coding Agents

Before submitting code, verify:

- [ ] All functions have proper docstrings following the template
- [ ] All docstrings include relevant documentation references
- [ ] Type hints are used for all parameters and return values
- [ ] Code follows the established style guide
- [ ] Error handling is implemented appropriately
- [ ] Logging is included for important operations
- [ ] Documentation is updated to reflect changes
- [ ] Cross-references are accurate and working
- [ ] Code examples in documentation are tested
- [ ] No sensitive data is included in code or comments

### For Human Reviewers

When reviewing code from coding agents:

- [ ] Documentation standards are followed
- [ ] Cross-references are accurate
- [ ] Code examples work as documented
- [ ] System architecture is respected
- [ ] Service interactions are properly documented
- [ ] Error conditions are handled
- [ ] Performance considerations are addressed

---

*These standards ensure consistency and maintainability across the Local Voice AI project. All contributors, both human and AI, must follow these guidelines.*