#!/usr/bin/env bash
# Run Semgrep with --autofix on Python files after agent edits (Cursor afterFileEdit).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$ROOT/semgrep/autofix-demo.yml"

INPUT="$(cat)"
FILE_PATH="$(printf '%s' "$INPUT" | python3 -c "
import json, os, sys
data = json.load(sys.stdin)
path = data.get('file_path') or ''
roots = data.get('workspace_roots') or []
if path and not os.path.isabs(path) and roots:
    path = os.path.normpath(os.path.join(roots[0], path))
print(path)
")"

[[ -n "$FILE_PATH" ]] || exit 0
[[ "$FILE_PATH" == *.py ]] || exit 0
[[ -f "$CONFIG" ]] || exit 0
command -v semgrep >/dev/null 2>&1 || exit 0

# Only this repo (avoid running on random paths if Cursor sends something odd)
case "$FILE_PATH" in
  "$ROOT"/*) ;;
  *) exit 0 ;;
esac

cd "$ROOT"
# Do not use --error: findings would make the hook exit non-zero after autofix in some versions.
semgrep --config "$CONFIG" --autofix --quiet "$FILE_PATH" 2>/dev/null || true
exit 0
