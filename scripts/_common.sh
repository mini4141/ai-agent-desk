#!/usr/bin/env bash
# Shared helpers: repo root, MSYS path-conversion off so docker mounts work in Git Bash.
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# Native Windows tools (node, k6) need C:/... paths, not /c/... ones.
ROOT_WIN="$(pwd -W 2>/dev/null || pwd)"
[ -f .env ] || cp .env.example .env
