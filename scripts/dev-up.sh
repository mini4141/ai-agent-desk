#!/usr/bin/env bash
# Starts the whole local stack: Docker services (Rails web + Sidekiq, Postgres/pgvector, Redis, mock company
# backend, Jaeger, OTel collector, Prometheus, Grafana) plus the Vite/Next.js dev servers on the host.
source "$(dirname "$0")/_common.sh"

mkdir -p .local/logs .local/pids
docker compose up -d --build
echo "waiting for Rails /up ..."
for _ in $(seq 1 90); do curl -fs localhost:3000/up >/dev/null && break; sleep 2; done

"$ROOT/scripts/seed.sh"
node scripts/warmup.mjs http://localhost:3000 pk_demo_mirai || true

(cd web && pnpm install --frozen-lockfile 2>/dev/null || pnpm install)
pnpm --dir web build:widget

start() { # name, dir, command...
  local name=$1 dir=$2; shift 2
  if [ -f ".local/pids/$name.pid" ] && kill -0 "$(cat ".local/pids/$name.pid")" 2>/dev/null; then echo "$name already running"; return; fi
  (cd "$dir" && nohup "$@" > "$ROOT/.local/logs/$name.log" 2>&1 < /dev/null & echo $! > "$ROOT/.local/pids/$name.pid")
  echo "started $name"
}
start console web/console pnpm dev
start phone-sim web/phone-sim pnpm dev
export API_URL=http://localhost:3000 NEXT_PUBLIC_API_URL=http://localhost:3000 NEXT_PUBLIC_OTLP_URL=http://localhost:4318/v1/traces
start help-center web/help-center pnpm dev

cat <<'EOF'

Ready:
  Console       http://localhost:5173   (owner@mirai.example / sato@mirai.example, password: agentdesk-demo)
  Help center   http://localhost:3001/mirai/help
  Phone sim     http://localhost:5175
  Rails API     http://localhost:3000   Jaeger http://localhost:16686   Grafana http://localhost:3030
EOF
