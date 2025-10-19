# Documentation Maintenance Guide

This guide explains how to maintain the Local Voice AI documentation system, including validation procedures, update processes, and best practices for keeping documentation current.

## 📋 Overview

The documentation system is designed to be a living resource that evolves with the codebase. It includes automated validation tools to ensure consistency and accuracy.

## 🔧 Validation Procedures

### Running the Validation Script

The documentation validation script ensures all cross-references are valid and documentation standards are maintained.

```bash
# Basic validation
python scripts/validate-docs.py

# Validate with strict mode (treat warnings as errors)
python scripts/validate-docs.py --strict

# Validate custom documentation directory
python scripts/validate-docs.py --docs-dir /path/to/docs
```

### Validation Checks

The script performs the following checks:

1. **Required Files**: Ensures all required documentation files exist
2. **Cross-References**: Validates all internal links and references
3. **Markdown Links**: Checks for malformed markdown links
4. **Docstring Standards**: Validates docstring compliance in code

### Integration with Development Workflow

Add validation to your development process:

#### Pre-commit Hook
```bash
#!/bin/sh
# .git/hooks/pre-commit

# Validate documentation
python scripts/validate-docs.py --strict
if [ $? -ne 0 ]; then
    echo "❌ Documentation validation failed. Please fix issues before committing."
    exit 1
fi

echo "✅ Documentation validation passed"
```

#### CI/CD Integration
```yaml
# .github/workflows/docs-validation.yml
name: Documentation Validation

on: [push, pull_request]

jobs:
  validate-docs:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.12'
    - name: Validate documentation
      run: python scripts/validate-docs.py --strict
```

## 🔄 Update Procedures

### For Coding Agents

When making code changes, follow this documentation update process:

#### 1. Before Making Changes
```bash
# Read relevant documentation
cat docs/coding-standards.md
cat docs/development-workflow.md

# Understand current implementation
# Read service-specific documentation
```

#### 2. During Development
```bash
# Update docstrings as you code
# Follow templates in coding-standards.md

# Add cross-references to related documentation
# See Also: docs/services/service-name.md
```

#### 3. After Making Changes
```bash
# Update service documentation
# Edit relevant files in docs/services/

# Update architecture if system design changed
# Edit docs/architecture.md

# Update cross-references
# Check all links and references

# Validate documentation
python scripts/validate-docs.py

# Fix any validation errors
# Repeat until validation passes
```

#### 4. Before Committing
```bash
# Final validation
python scripts/validate-docs.py --strict

# Test examples in documentation
# Ensure all code examples work

# Check links manually if needed
# Verify external links are accessible
```

### For Human Developers

#### Review Process
1. **Code Review**: Check that coding standards are followed
2. **Documentation Review**: Verify documentation is complete and accurate
3. **Validation Check**: Ensure automated validation passes
4. **Testing**: Test all examples and procedures in documentation

#### Release Process
```bash
# 1. Ensure all tests pass
./test.sh

# 2. Validate documentation
python scripts/validate-docs.py --strict

# 3. Update version numbers
# Update package.json, Dockerfile tags, etc.

# 4. Update changelog
echo "## Version X.Y.Z - $(date)" >> CHANGELOG.md

# 5. Commit and tag
git add .
git commit -m "Release version X.Y.Z with updated documentation"
git tag -a vX.Y.Z -m "Release version X.Y.Z"
git push origin main --tags
```

## 📝 Documentation Standards

### File Organization

```
docs/
├── index.md                    # Main navigation and overview
├── architecture.md             # System architecture
├── development-workflow.md     # Development guidelines
├── coding-standards.md         # Docstring standards
├── lessons-learned.md          # Best practices
├── maintenance-guide.md        # This file
└── services/                   # Service-specific docs
    ├── agent.md               # Agent service
    ├── whisper.md             # STT service
    ├── ollama.md              # LLM service
    ├── kokoro.md              # TTS service
    ├── livekit.md             # WebRTC signaling
    └── frontend.md            # Next.js frontend
```

### Cross-Reference Standards

#### Internal Links
```markdown
# Use relative paths
See [Agent Service](services/agent.md) for details.

# Use anchors for sections
See [API Reference](services/agent.md#api-reference).

# Reference specific sections
See [docs/architecture.md#data-flow-sequence](architecture.md#data-flow-sequence).
```

#### Code References
```markdown
# Reference specific files
See [`agent/myagent.py`](../../agent/myagent.py:1) for implementation.

# Reference specific lines
See [`docker-compose.yml`](../../docker-compose.yml:44-50) for configuration.

# Reference functions
See [`LocalAgent.__init__()`](../../agent/myagent.py:57) for initialization.
```

#### External Links
```markdown
# Use descriptive link text
See [LiveKit Documentation](https://docs.livekit.io/) for more information.

# Include version information when relevant
See [Next.js 14 Documentation](https://nextjs.org/docs) for React framework details.
```

### Docstring Standards

#### Python Docstrings
```python
def example_function(param1: str, param2: int) -> bool:
    """
    Brief description of the function.
    
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
        >>> result = example_function("test", 42)
        >>> print(result)
        True
    
    See Also:
        related_function: Function that complements this one
        docs/services/agent.md: Service documentation
    
    References:
        docs/architecture.md: System architecture
    """
```

#### TypeScript JSDoc
```typescript
/**
 * Component description following JSDoc standards.
 * 
 * @param props - Component props
 * @returns JSX element
 * 
 * @example
 * ```tsx
 * <Component prop1="value" />
 * ```
 * 
 * @see docs/services/frontend.md for implementation details
 */
interface ComponentProps {
  prop1: string;
}
```

## 🚨 Common Issues and Solutions

### Validation Errors

#### Missing Required Files
```
ERROR: Missing required file: services/new-service.md
```
**Solution**: Create the missing file with appropriate content.

#### Invalid Cross-References
```
ERROR: Invalid reference in index.md: [New Service](services/agent.md)
```
**Solution**: 
1. Check if the target file exists
2. Verify the path is correct
3. Update the reference to point to the correct file

#### Malformed Links
```
WARNING: Potential malformed link in services/agent.md:42: [Broken Link
```
**Solution**: Fix the markdown link syntax.

### Documentation Drift

#### Code Changes Without Documentation Updates
**Problem**: Code has been modified but documentation wasn't updated.

**Solution**: 
1. Review recent code changes
2. Update relevant documentation
3. Add cross-references to new functionality
4. Run validation to ensure consistency

#### Outdated Examples
**Problem**: Code examples in documentation no longer work.

**Solution**:
1. Test all code examples
2. Update examples to match current implementation
3. Add version information if needed
4. Consider adding automated tests for examples

### Performance Issues

#### Large Documentation Files
**Problem**: Documentation files are becoming too large and difficult to navigate.

**Solution**:
1. Split large files into smaller, focused documents
2. Use cross-references to link related content
3. Add detailed table of contents
4. Consider using expandable sections for detailed information

#### Slow Validation
**Problem**: Documentation validation is taking too long.

**Solution**:
1. Optimize the validation script
2. Add caching for expensive operations
3. Run validation only on changed files in CI
4. Consider parallel processing for large documentation sets

## 📊 Quality Metrics

### Documentation Coverage

Track documentation coverage across the project:

```bash
# Count documented functions
grep -r "def " . --include="*.py" | wc -l
grep -r '"""' . --include="*.py" | wc -l

# Count documented components
grep -r "function\|const.*=" . --include="*.ts" --include="*.tsx" | wc -l
grep -r "/\*\*" . --include="*.ts" --include="*.tsx" | wc -l
```

### Link Validation

Regularly validate external links:

```bash
# Install link checker
npm install -g markdown-link-check

# Check all markdown files
find docs -name "*.md" -exec markdown-link-check {} \;

# Check specific file
markdown-link-check docs/index.md
```

### Documentation Freshness

Track documentation updates:

```bash
# Find recently updated documentation
find docs -name "*.md" -mtime -7 -ls

# Find documentation that hasn't been updated recently
find docs -name "*.md" -mtime +30 -ls
```

## 🔧 Tools and Resources

### Validation Tools

- **validate-docs.py**: Custom validation script (included)
- **markdown-link-check**: External link validation
- **markdownlint**: Markdown style checking

### Editing Tools

- **Markdown editors**: VS Code with Markdown extensions
- **Diagram tools**: Mermaid for architecture diagrams
- **Link checkers**: Browser extensions for link validation

### Automation

- **Pre-commit hooks**: Automated validation before commits
- **CI/CD integration**: Automated validation in pull requests
- **Scheduled checks**: Regular validation of external links

## 📈 Best Practices

### Writing Style

1. **Be Clear and Concise**: Use simple language and short sentences
2. **Be Consistent**: Use consistent terminology and formatting
3. **Be Complete**: Include all necessary information
4. **Be Accurate**: Ensure all information is correct and up-to-date

### Content Organization

1. **Logical Structure**: Organize content logically with clear headings
2. **Navigation**: Include table of contents for long documents
3. **Cross-References**: Link related content for easy navigation
4. **Examples**: Include practical examples for complex concepts

### Maintenance

1. **Update Regularly**: Keep documentation in sync with code changes
2. **Review Periodically**: Regular review for accuracy and completeness
3. **Validate Automatically**: Use automated validation tools
4. **Get Feedback**: Encourage feedback from users and contributors

---

*For development guidelines, see [docs/development-workflow.md](development-workflow.md). For coding standards, see [docs/coding-standards.md](coding-standards.md).*