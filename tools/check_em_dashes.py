#!/usr/bin/env python3
"""
Zero em dash enforcement gate for scarp.
Scans all text files in the repository to guarantee that no em dashes
(Unicode U+2014 or literal '—' or '&mdash;') exist in comments, documentation,
or code.
"""

import os
import sys

FORBIDDEN_PATTERNS = [
    ("\u2014", "Unicode em dash (U+2014)"),
    ("&mdash;", "HTML em dash entity (&mdash;)"),
    ("\u2013", "Unicode en dash (U+2013)"),  # enforce plain hyphens/ASCII dashes
]

IGNORED_DIRS = {
    ".git",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    "build",
    "dist",
}

IGNORED_EXTENSIONS = {
    ".pyc",
    ".o",
    ".dylib",
    ".so",
    ".a",
    ".dis",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".ico",
    ".mseed",
}


def scan_file(filepath: str) -> list[tuple[int, str, str]]:
    violations = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line_no, line in enumerate(f, 1):
                for pattern, desc in FORBIDDEN_PATTERNS:
                    if pattern in line:
                        violations.append((line_no, desc, line.strip()))
    except Exception as e:
        print(f"Warning: could not read {filepath}: {e}", file=sys.stderr)
    return violations


def main() -> int:
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    all_violations = {}

    for root, dirs, files in os.walk(repo_root):
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS]
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext in IGNORED_EXTENSIONS:
                continue
            path = os.path.join(root, file)
            # Skip checking this script itself for the pattern strings
            if os.path.abspath(path) == os.path.abspath(__file__):
                continue
            v = scan_file(path)
            if v:
                rel_path = os.path.relpath(path, repo_root)
                all_violations[rel_path] = v

    if all_violations:
        print("FAIL: Forbidden dash characters detected!")
        for filepath, issues in sorted(all_violations.items()):
            for line_no, desc, line_snippet in issues:
                print(f"  {filepath}:{line_no} [{desc}] -> {line_snippet[:80]}")
        return 1

    print("PASS: Zero forbidden dash characters detected across repository.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
