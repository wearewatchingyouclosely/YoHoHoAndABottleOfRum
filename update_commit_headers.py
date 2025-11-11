# Commit History:
#   2025-10-12 19:14:14 -0400 | mitchell | f034589b | Update commit history in scripts for consistency and tracking
#   2025-10-12 18:57:01 -0400 | mitchell | d0805e20 | 1
#   2025-10-12 18:56:47 -0400 | mitchell | 3e8aa859 | ?
#   2025-10-12 18:56:42 -0400 | mitchell | c9eff979 | Refactor commit header update script for improved functionality and cross-platform compatibility
#   2025-10-12 18:56:19 -0400 | mitchell | eb343aeb | Refactor commit header update script for improved functionality and cross-platform compatibility
#   2025-10-12 18:56:14 -0400 | mitchell | e5a79f0c | Refactor NordVPN status retrieval for improved logic; add script to update commit headers in source files
# ---

#!/usr/bin/env python3
"""
update_commit_headers.py

Appends the latest commit info to a 'Commit History' header in supported source files changed in the last commit.
- Supports: .py, .sh, .js, .md, .ts, .json, .txt
- Appends new commit info, preserves previous entries
- Designed for use as a Git post-commit hook (cross-platform)
"""
import subprocess
import sys
import os
import re
from datetime import datetime

# File types to update
SUPPORTED_EXTS = {'.py', '.sh', '.js', '.md', '.ts', '.json', '.txt'}

HEADER_START = '# Commit History:'
HEADER_LINE = '#   '
HEADER_END = '# ---'

# For Markdown, use <!-- ... -->
MD_HEADER_START = '<!-- Commit History:'
MD_HEADER_LINE = '    '
MD_HEADER_END = '--- -->'

def get_last_commit_files():
    result = subprocess.run(['git', 'diff', '--name-only', 'HEAD~1', 'HEAD'], capture_output=True, text=True)
    files = result.stdout.strip().split('\n')
    return [f for f in files if os.path.splitext(f)[1] in SUPPORTED_EXTS and os.path.isfile(f)]

def get_last_commit_info():
    result = subprocess.run(['git', 'log', '-1', '--pretty=format:%H|%an|%ad|%s', '--date=iso'], capture_output=True, text=True)
    commit = result.stdout.strip()
    if not commit:
        return None
    commit_hash, author, date, message = commit.split('|', 3)
    return commit_hash, author, date, message

def update_file_header(filepath, commit_info):
    ext = os.path.splitext(filepath)[1]
    if ext == '.md':
        header_start, header_line, header_end = MD_HEADER_START, MD_HEADER_LINE, MD_HEADER_END
    else:
        header_start, header_line, header_end = HEADER_START, HEADER_LINE, HEADER_END

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Find existing header
    start_idx = None
    end_idx = None
    for i, line in enumerate(lines[:10]):
        if line.strip().startswith(header_start):
            start_idx = i
        if line.strip().startswith(header_end):
            end_idx = i
            break

    # Format new entry
    commit_hash, author, date, message = commit_info
    new_entry = f"{header_line}{date} | {author} | {commit_hash[:8]} | {message}\n"

    if start_idx is not None and end_idx is not None and end_idx > start_idx:
        # Insert new entry after header_start
        lines.insert(start_idx + 1, new_entry)
    else:
        # No header found, add at top
        header = [
            f"{header_start}\n",
            new_entry,
            f"{header_end}\n"
        ]
        lines = header + ['\n'] + lines

    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)


def main():
    commit_info = get_last_commit_info()
    if not commit_info:
        print('No commit info found.')
        sys.exit(1)
    files = get_last_commit_files()
    if not files:
        print('No supported files changed in last commit.')
        sys.exit(0)
    for f in files:
        update_file_header(f, commit_info)
        print(f'Updated header in: {f}')

if __name__ == '__main__':
    main()
