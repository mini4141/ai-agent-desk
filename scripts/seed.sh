#!/usr/bin/env bash
# Loads demo data (2 companies, tools, ingested knowledge, ~400 simulated conversations). Idempotent.
source "$(dirname "$0")/_common.sh"
docker compose exec -T web bin/rails db:seed
