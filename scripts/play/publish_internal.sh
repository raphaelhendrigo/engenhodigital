#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TRACK="${1:-internal}"
RELEASE_STATUS="${2:-completed}"
RELEASE_NAME="${3:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh nao encontrado. Instale o GitHub CLI (https://cli.github.com/) e tente novamente." >&2
  exit 1
fi

# Prefer an explicit GH_TOKEN, but fall back to git-credential if available.
if [ -z "${GH_TOKEN:-}" ] && command -v git >/dev/null 2>&1; then
  token="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p' | head -n1 || true)"
  if [ -n "$token" ]; then
    export GH_TOKEN="$token"
  fi
fi

cd "$REPO_ROOT"

if ! gh secret list | grep -q "^PLAY_SERVICE_ACCOUNT_JSON\\b"; then
  echo "Secret PLAY_SERVICE_ACCOUNT_JSON nao esta configurado no repo." >&2
  echo "Rode: ./scripts/play/set_play_service_account_secret.sh" >&2
  exit 1
fi

prev_run_id="$(gh run list -w android-build.yml -b main -e workflow_dispatch -L 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
if [ -z "$prev_run_id" ]; then
  prev_run_id="null"
fi

echo "Disparando workflow Android AAB (Buildozer) com publish=true (track=$TRACK, status=$RELEASE_STATUS)..."

args=(android-build.yml --ref main -f "publish=true" -f "track=$TRACK" -f "release_status=$RELEASE_STATUS")
if [ -n "$RELEASE_NAME" ]; then
  args+=(-f "release_name=$RELEASE_NAME")
fi

gh workflow run "${args[@]}"

echo "Aguardando o run aparecer na lista..."
run_id=""
for _ in $(seq 1 30); do
  run_id="$(gh run list -w android-build.yml -b main -e workflow_dispatch -L 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
  if [ -n "$run_id" ] && [ "$run_id" != "null" ] && [ "$run_id" != "$prev_run_id" ]; then
    break
  fi
  sleep 2
done

if [ -z "$run_id" ] || [ "$run_id" = "null" ]; then
  echo "Nao consegui localizar o run automaticamente. Veja em: GitHub Actions -> Android AAB (Buildozer)" >&2
  exit 1
fi

echo "Acompanhando run: $run_id"
gh run watch "$run_id" --exit-status
gh run view "$run_id"
