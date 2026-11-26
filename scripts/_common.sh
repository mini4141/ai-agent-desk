#!/usr/bin/env bash
# Shared helpers: repo root, MSYS path-conversion off so docker mounts work in Git Bash.
set -euo pipefail
export MSYS_NO_PATHCONV=1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[ -f .env ] || cp .env.example .env
