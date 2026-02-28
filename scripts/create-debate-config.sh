#!/usr/bin/env sh

set -eu

# Ensure zsh behaves like POSIX sh when invoked as `zsh script.sh`.
if [ -n "${ZSH_VERSION:-}" ]; then
  emulate -L sh
  setopt SH_WORD_SPLIT
fi

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CANONICAL_SCRIPT="$PROJECT_ROOT/.cursor/skills/orchestrator/scripts/create-debate-config.sh"

if [ ! -f "$CANONICAL_SCRIPT" ]; then
  printf 'Canonical script not found: %s\n' "$CANONICAL_SCRIPT" >&2
  exit 1
fi

exec sh "$CANONICAL_SCRIPT" "$@"
