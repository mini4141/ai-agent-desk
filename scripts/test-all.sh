#!/usr/bin/env bash
# Runs every local test layer; exits non-zero if any fails. Reports land in proof/phase1-local/tests/.
#   RSpec (JUnit) -> Vitest (JUnit) -> type checks -> Playwright e2e -> k6 latency smoke
# Requires the local stack (scripts/dev-up.sh) for the e2e and k6 layers.
source "$(dirname "$0")/_common.sh"

OUT="${TEST_OUT:-proof/phase1-local/tests}"
mkdir -p "$OUT"
status=0
step() { echo; echo "=== $1"; }
run() { "$@" || status=1; }

step "RSpec (models, requests, channels, jobs)"
docker compose run --rm -T -e RAILS_ENV=test -e DATABASE_URL=postgres://postgres:postgres@db:5432/agent_desk_test \
  -e OTEL_EXPORTER_OTLP_ENDPOINT= web bash -c \
  "bin/rails db:create db:schema:load >/dev/null && bundle exec rspec --format progress --format RspecJunitFormatter --out tmp/rspec-junit.xml" \
  2>&1 | tee "$OUT/rspec.log" || status=1
cp tmp/rspec-junit.xml "$OUT/rspec-junit.xml" 2>/dev/null || true

step "Type checks (tsc)"
run pnpm --dir web -r --if-present lint

step "Vitest + React Testing Library"
(cd web/console && pnpm exec vitest run --reporter=default --reporter=junit --outputFile.junit="$ROOT_WIN/$OUT/vitest-junit.xml") 2>&1 | tee "$OUT/vitest.log" || status=1

if curl -fs localhost:3000/up >/dev/null; then
  step "Playwright e2e"
  (cd web/e2e && PW_REPORT_DIR="$ROOT_WIN/$OUT" pnpm exec playwright test) 2>&1 | tee "$OUT/playwright.log" || status=1

  step "k6 latency smoke (20 VUs x ${K6_DURATION_S:-120}s, time-to-first-token p95 < 400 ms)"
  k6 run -e BASE_URL=http://localhost:3000 -e VUS=20 -e DURATION_S="${K6_DURATION_S:-120}" \
    -e LOAD_TEST_TOKEN="$(grep ^LOAD_TEST_TOKEN .env | cut -d= -f2)" -e SUMMARY_JSON="$ROOT_WIN/$OUT/k6-summary.json" \
    scripts/k6-chat.js 2>&1 | tee "$OUT/k6.log" || status=1
else
  echo "Rails is not up on :3000; skipping e2e and k6 (run scripts/dev-up.sh first)"; status=1
fi

step "Result"
[ "$status" = 0 ] && echo "ALL GREEN" || echo "FAILURES (see logs in $OUT)"
exit "$status"
