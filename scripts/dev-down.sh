#!/usr/bin/env bash
# Stops the host dev servers and the Docker stack.
source "$(dirname "$0")/_common.sh"

for pidfile in .local/pids/*.pid; do
  [ -f "$pidfile" ] || continue
  pid=$(cat "$pidfile")
  # taskkill reaches the whole process tree on Windows (Git Bash); kill is the POSIX fallback.
  taskkill //PID "$pid" //T //F >/dev/null 2>&1 || kill "$pid" 2>/dev/null || true
  rm -f "$pidfile"
done
docker compose down
