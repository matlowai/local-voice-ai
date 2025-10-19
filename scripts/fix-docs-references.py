#!/usr/bin/env python3
"""
Script to fix cross-reference issues in documentation.
"""

import os
import re
from pathlib import Path

def fix_references():
    """Fix cross-references in documentation files."""
    docs_dir = Path("docs")
    
    # Fix service files
    service_files = [
        "services/agent.md",
        "services/whisper.md", 
        "services/ollama.md",
        "services/kokoro.md",
        "services/livekit.md",
        "services/frontend.md"
    ]
    
    for service_file in service_files:
        file_path = docs_dir / service_file
        if file_path.exists():
            content = file_path.read_text(encoding="utf-8")
            
            # Fix relative references to parent directory
            content = content.replace('[docs/architecture.md](../architecture.md)', '[docs/architecture.md](../architecture.md)')
            content = content.replace('[docs/coding-standards.md](../coding-standards.md)', '[docs/coding-standards.md](../coding-standards.md)')
            content = content.replace('[docs/development-workflow.md](../development-workflow.md)', '[docs/development-workflow.md](../development-workflow.md)')
            
            file_path.write_text(content, encoding="utf-8")
            print(f"Fixed references in {service_file}")
    
    # Fix maintenance guide
    maintenance_file = docs_dir / "maintenance-guide.md"
    if maintenance_file.exists():
        content = maintenance_file.read_text(encoding="utf-8")
        
        # Fix relative file references
        content = content.replace('[`agent/myagent.py`](../agent/myagent.py:1)', '[`agent/myagent.py`](../../agent/myagent.py:1)')
        content = content.replace('[`docker-compose.yml`](../docker-compose.yml:44-50)', '[`docker-compose.yml`](../../docker-compose.yml:44-50)')
        content = content.replace('[`LocalAgent.__init__()`](../agent/myagent.py:57)', '[`LocalAgent.__init__()`](../../agent/myagent.py:57)')
        content = content.replace('[New Service](services/new-service.md)', '[New Service](services/new-service.md)')
        
        # Remove example references that don't exist
        content = content.replace('[New Service](services/new-service.md)', '[New Service](services/agent.md)')
        
        maintenance_file.write_text(content, encoding="utf-8")
        print("Fixed references in maintenance-guide.md")

if __name__ == "__main__":
    fix_references()
    print("All references fixed!")