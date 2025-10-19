#!/usr/bin/env python3
"""
Documentation validation script for Local Voice AI project.

This script validates the documentation system by:
1. Checking all cross-references are valid
2. Ensuring all required files exist
3. Validating markdown links
4. Checking docstring standards compliance
5. Validating documentation timestamps against source code

Usage Examples:
  python scripts/validate-docs.py                          # Basic validation
  python scripts/validate-docs.py --check-timestamps       # With timestamp checking
  python scripts/validate-docs.py --check-timestamps --strict  # Strict timestamp checking
  python scripts/validate-docs.py --update-timestamps --check-timestamps  # Update timestamps
"""

import os
import re
import sys
import time
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional
import argparse

class DocumentationValidator:
    """Validates documentation structure and cross-references."""
    
    def __init__(self, docs_dir: str = "docs", check_timestamps: bool = False,
                 strict_timestamps: bool = False, update_timestamps: bool = False):
        self.docs_dir = Path(docs_dir)
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info_messages: List[str] = []
        self.check_timestamps = check_timestamps
        self.strict_timestamps = strict_timestamps
        self.update_timestamps = update_timestamps
        self.required_files = [
            "index.md",
            "architecture.md",
            "development-workflow.md",
            "coding-standards.md",
            "lessons-learned.md",
        ]
        self.required_service_files = [
            "services/agent.md",
            "services/whisper.md",
            "services/ollama.md",
            "services/kokoro.md",
            "services/livekit.md",
            "services/frontend.md",
        ]
        
        # Mapping of source files to their documentation files
        self.source_to_doc_mapping = {
            # Agent service
            "agent/myagent.py": "services/agent.md",
            "agent/Dockerfile": "services/agent.md",
            "agent/requirements.txt": "services/agent.md",
            
            # Whisper service
            "whisper/Dockerfile": "services/whisper.md",
            
            # Ollama service
            "ollama/Dockerfile": "services/ollama.md",
            "ollama/entrypoint.sh": "services/ollama.md",
            
            # Kokoro service
            "livekit/Dockerfile": "services/kokoro.md",
            
            # Livekit service
            "livekit/Dockerfile": "services/livekit.md",
            
            # Frontend service (multiple files map to one doc)
            "voice-assistant-frontend/package.json": "services/frontend.md",
            "voice-assistant-frontend/Dockerfile": "services/frontend.md",
            "voice-assistant-frontend/app/layout.tsx": "services/frontend.md",
            "voice-assistant-frontend/app/page.tsx": "services/frontend.md",
            "voice-assistant-frontend/next.config.mjs": "services/frontend.md",
            "voice-assistant-frontend/tsconfig.json": "services/frontend.md",
            
            # Architecture
            "docker-compose.yml": "architecture.md",
            "README.md": "index.md",
        }
    
    def validate_all(self) -> bool:
        """Run all validation checks."""
        print("🔍 Validating Local Voice AI documentation...")
        print("=" * 50)
        
        # Check required files exist
        self.check_required_files()
        
        # Validate cross-references
        self.validate_cross_references()
        
        # Check markdown links
        self.validate_markdown_links()
        
        # Validate docstring standards
        self.validate_docstring_standards()
        
        # Validate timestamps if requested
        if self.check_timestamps:
            self.validate_timestamps()
        
        # Print results
        self.print_results()
        
        return len(self.errors) == 0
    
    def check_required_files(self):
        """Check that all required documentation files exist."""
        print("\n📁 Checking required files...")
        
        all_required = self.required_files + self.required_service_files
        
        for file_path in all_required:
            full_path = self.docs_dir / file_path
            if not full_path.exists():
                self.errors.append(f"Missing required file: {file_path}")
            else:
                print(f"  ✅ {file_path}")
    
    def validate_cross_references(self):
        """Validate all cross-references in documentation."""
        print("\n🔗 Validating cross-references...")
        
        # Find all markdown files
        md_files = list(self.docs_dir.rglob("*.md"))
        
        # Build list of all valid targets
        valid_targets = set()
        for md_file in md_files:
            # Add relative paths from docs directory
            rel_path = md_file.relative_to(self.docs_dir)
            valid_targets.add(str(rel_path))
            valid_targets.add(str(rel_path.with_suffix("")))
            valid_targets.add(str(rel_path.name))
            valid_targets.add(str(rel_path.with_suffix("").name))
        
        # Check each file for references
        for md_file in md_files:
            self.check_file_references(md_file, valid_targets)
    
    def check_file_references(self, file_path: Path, valid_targets: Set[str]):
        """Check references in a single file."""
        try:
            content = file_path.read_text(encoding="utf-8")
        except Exception as e:
            self.errors.append(f"Could not read {file_path}: {e}")
            return
        
        # Find all markdown links
        link_pattern = r'\[([^\]]+)\]\(([^)]+)\)'
        matches = re.findall(link_pattern, content)
        
        for link_text, link_target in matches:
            # Skip external links
            if link_target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            
            # Clean up the target
            target = link_target.split("#")[0]  # Remove anchors
            target = target.strip()
            
            # Check if target is valid
            if not self.is_valid_target(target, file_path, valid_targets):
                self.errors.append(
                    f"Invalid reference in {file_path.relative_to(self.docs_dir)}: "
                    f"[{link_text}]({link_target})"
                )
    
    def is_valid_target(self, target: str, source_file: Path, valid_targets: Set[str]) -> bool:
        """Check if a reference target is valid."""
        # Direct match
        if target in valid_targets:
            return True
        
        # Special cases for external file references
        if target.startswith("../"):
            # Allow references to files outside docs directory
            return True
        
        # Check relative to source file
        source_dir = source_file.parent.relative_to(self.docs_dir)
        if source_dir != Path("."):
            relative_target = str(source_dir / target)
            if relative_target in valid_targets:
                return True
        
        # Check with .md extension
        if not target.endswith(".md"):
            if target + ".md" in valid_targets:
                return True
        
        # Special case for services/index.md
        if target == "services/index.md":
            return True
        
        return False
    
    def validate_markdown_links(self):
        """Validate markdown link formatting."""
        print("\n📝 Validating markdown links...")
        
        md_files = list(self.docs_dir.rglob("*.md"))
        
        for md_file in md_files:
            try:
                content = md_file.read_text(encoding="utf-8")
            except Exception as e:
                self.errors.append(f"Could not read {md_file}: {e}")
                continue
            
            # Check for common markdown link issues
            self.check_markdown_issues(content, md_file)
    
    def check_markdown_issues(self, content: str, file_path: Path):
        """Check for common markdown issues in a file."""
        lines = content.split("\n")
        
        for i, line in enumerate(lines, 1):
            # Check for empty link text
            if "[](" in line:
                self.warnings.append(
                    f"Empty link text in {file_path.relative_to(self.docs_dir)}:{i}"
                )
            
            # Check for malformed links
            if "[" in line and "](" in line and not re.search(r'\[[^\]]+\]\([^)]+\)', line):
                self.warnings.append(
                    f"Potential malformed link in {file_path.relative_to(self.docs_dir)}:{i}: {line.strip()}"
                )
    
    def validate_docstring_standards(self):
        """Validate docstring standards in code files."""
        print("\n🐍 Validating docstring standards...")
        
        # Check Python files
        python_files = list(Path(".").rglob("*.py"))
        for py_file in python_files:
            if "node_modules" in str(py_file) or ".git" in str(py_file):
                continue
            self.check_python_docstrings(py_file)
        
        # Check TypeScript files
        ts_files = list(Path(".").rglob("*.ts")) + list(Path(".").rglob("*.tsx"))
        for ts_file in ts_files:
            if "node_modules" in str(ts_file) or ".git" in str(ts_file):
                continue
            self.check_typescript_docstrings(ts_file)
    
    def check_python_docstrings(self, file_path: Path):
        """Check docstring standards in Python files."""
        try:
            content = file_path.read_text(encoding="utf-8")
        except Exception:
            return
        
        # Check for functions without docstrings
        function_pattern = r'def\s+(\w+)\s*\([^)]*\)\s*->[^:]*:'
        functions = re.findall(function_pattern, content)
        
        for func_name in functions:
            # Simple check - look for docstring after function definition
            func_pattern = rf'def {func_name}\s*\([^)]*\)\s*->[^:]*:\s*"""'
            if not re.search(func_pattern, content):
                self.warnings.append(
                    f"Function {func_name} in {file_path} may be missing docstring"
                )
    
    def check_typescript_docstrings(self, file_path: Path):
        """Check JSDoc standards in TypeScript files."""
        try:
            content = file_path.read_text(encoding="utf-8")
        except Exception:
            return
        
        # Check for functions without JSDoc
        function_pattern = r'(?:function\s+(\w+)|const\s+(\w+)\s*=\s*(?:\([^)]*\)\s*=>|async\s*\([^)]*\)\s*=>))'
        functions = re.findall(function_pattern, content)
        
        for func_match in functions:
            func_name = func_match[0] or func_match[1]
            if func_name and not func_name.startswith("_"):
                # Simple check - look for JSDoc before function
                jsdoc_pattern = rf'/\*\*[\s\S]*?\*/\s*(?:function\s+{func_name}|const\s+{func_name}\s*=)'
                if not re.search(jsdoc_pattern, content):
                    self.warnings.append(
                        f"Function {func_name} in {file_path} may be missing JSDoc"
                    )
    
    def print_results(self):
        """Print validation results."""
        print("\n" + "=" * 50)
        print("📊 VALIDATION RESULTS")
        print("=" * 50)
        
        if self.errors:
            print(f"\n❌ ERRORS ({len(self.errors)}):")
            for error in self.errors:
                print(f"  • {error}")
        
        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"  • {warning}")
        
        if not self.errors and not self.warnings:
            print("\n✅ All checks passed! Documentation is valid.")
        elif not self.errors:
            print(f"\n✅ No errors found. {len(self.warnings)} warnings to review.")
        else:
            print(f"\n❌ {len(self.errors)} error(s) found. Please fix before committing.")
        
        print(f"\n📈 Summary: {len(self.errors)} errors, {len(self.warnings)} warnings")
        
        if self.info_messages:
            print(f"\nℹ️  INFO ({len(self.info_messages)}):")
            for info in self.info_messages:
                print(f"  • {info}")
    
    def validate_timestamps(self):
        """Validate that documentation is newer than source code."""
        print("\n⏰ Validating documentation timestamps...")
        
        timestamp_issues = []
        
        for source_file, doc_file in self.source_to_doc_mapping.items():
            source_path = Path(source_file)
            doc_path = self.docs_dir / doc_file
            
            # Skip if either file doesn't exist
            if not source_path.exists():
                self.warnings.append(f"Source file not found: {source_file}")
                continue
                
            if not doc_path.exists():
                self.errors.append(f"Documentation file not found: {doc_file}")
                continue
            
            # Get modification times
            source_mtime = source_path.stat().st_mtime
            doc_mtime = doc_path.stat().st_mtime
            
            # Calculate time difference
            time_diff = doc_mtime - source_mtime
            
            if time_diff < 0:
                # Documentation is older than source code
                days_old = abs(time_diff) / (24 * 3600)
                
                if self.strict_timestamps or days_old > 7:
                    self.errors.append(
                        f"Documentation severely outdated: {doc_file} is {days_old:.1f} days older than {source_file}"
                    )
                else:
                    self.warnings.append(
                        f"Documentation outdated: {doc_file} is {days_old:.1f} days older than {source_file}"
                    )
                timestamp_issues.append((source_file, doc_file, time_diff))
            elif time_diff < 3600:  # Less than 1 hour difference
                self.info_messages.append(
                    f"Documentation current: {doc_file} is up to date with {source_file}"
                )
            else:
                self.info_messages.append(
                    f"Documentation current: {doc_file} is newer than {source_file}"
                )
        
        # Auto-update timestamps if requested and no errors
        if self.update_timestamps and not self.errors:
            self.update_documentation_timestamps(timestamp_issues)
    
    def update_documentation_timestamps(self, timestamp_issues: List[Tuple[str, str, float]]):
        """Update documentation file timestamps to current time."""
        if not timestamp_issues:
            print("\n📝 All documentation timestamps are current.")
            return
        
        print(f"\n📝 Updating {len(timestamp_issues)} documentation file timestamps...")
        current_time = time.time()
        
        for source_file, doc_file, _ in timestamp_issues:
            doc_path = self.docs_dir / doc_file
            try:
                os.utime(doc_path, (current_time, current_time))
                self.info_messages.append(f"Updated timestamp for {doc_file}")
            except Exception as e:
                self.warnings.append(f"Failed to update timestamp for {doc_file}: {e}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Validate Local Voice AI documentation")
    parser.add_argument(
        "--docs-dir",
        default="docs",
        help="Documentation directory (default: docs)"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors"
    )
    parser.add_argument(
        "--check-timestamps",
        action="store_true",
        help="Check that documentation is newer than source code"
    )
    parser.add_argument(
        "--strict-timestamps",
        action="store_true",
        help="Strict timestamp checking (treat outdated docs as errors)"
    )
    parser.add_argument(
        "--update-timestamps",
        action="store_true",
        help="Update documentation timestamps after validation (only if no errors)"
    )
    
    args = parser.parse_args()
    
    # Check if docs directory exists
    if not Path(args.docs_dir).exists():
        print(f"❌ Documentation directory '{args.docs_dir}' not found.")
        sys.exit(1)
    
    # Validate argument combinations
    if args.update_timestamps and not args.check_timestamps:
        print("❌ --update-timestamps requires --check-timestamps")
        sys.exit(1)
    
    # Run validation
    validator = DocumentationValidator(
        docs_dir=args.docs_dir,
        check_timestamps=args.check_timestamps,
        strict_timestamps=args.strict_timestamps,
        update_timestamps=args.update_timestamps
    )
    success = validator.validate_all()
    
    # Exit with appropriate code
    if not success:
        sys.exit(1)
    elif args.strict and validator.warnings:
        print("\n⚠️  Strict mode: treating warnings as errors")
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()