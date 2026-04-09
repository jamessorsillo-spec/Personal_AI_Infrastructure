#!/usr/bin/env bash
set -euo pipefail

# Deploy Email Triage Copilot workers to Cloudflare
#
# Usage:
#   bash deploy.sh [action]
#
# Actions:
#   all         Deploy all workers (default)
#   triage      Deploy a-triage-email only
#   draft       Deploy a-draft-email-reply only
#   secrets     Set secrets for all workers
#   health      Check health of deployed workers

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKERS_DIR="$SCRIPT_DIR/workers"

# Your Cloudflare subdomain — update after first deploy
CF_SUBDOMAIN="${CF_SUBDOMAIN:-YOUR-SUBDOMAIN}"

WORKERS=(
  "a-triage-email"
  "a-draft-email-reply"
)

deploy_worker() {
  local worker="$1"
  echo "Deploying arbol-$worker..."
  cd "$WORKERS_DIR/$worker"
  npx wrangler deploy
  echo "  Deployed: https://arbol-$worker.$CF_SUBDOMAIN.workers.dev"
  cd "$SCRIPT_DIR"
}

set_secrets() {
  for worker in "${WORKERS[@]}"; do
    echo ""
    echo "Setting secrets for arbol-$worker..."
    echo -n "AUTH_TOKEN: "
    read -rs token
    echo ""
    echo "$token" | npx wrangler secret put AUTH_TOKEN --name "arbol-$worker"

    echo -n "ANTHROPIC_API_KEY: "
    read -rs apikey
    echo ""
    echo "$apikey" | npx wrangler secret put ANTHROPIC_API_KEY --name "arbol-$worker"
  done
  echo ""
  echo "Secrets set for all workers."
}

check_health() {
  for worker in "${WORKERS[@]}"; do
    local url="https://arbol-$worker.$CF_SUBDOMAIN.workers.dev/health"
    echo -n "arbol-$worker: "
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null) || true
    if [ "$response" = "200" ]; then
      echo "OK (200)"
    else
      echo "FAIL ($response)"
    fi
  done
}

ACTION="${1:-all}"

case "$ACTION" in
  all)
    for worker in "${WORKERS[@]}"; do
      deploy_worker "$worker"
    done
    echo ""
    echo "All workers deployed."
    ;;
  triage)
    deploy_worker "a-triage-email"
    ;;
  draft)
    deploy_worker "a-draft-email-reply"
    ;;
  secrets)
    set_secrets
    ;;
  health)
    check_health
    ;;
  *)
    echo "Usage: bash deploy.sh [all|triage|draft|secrets|health]"
    exit 1
    ;;
esac
