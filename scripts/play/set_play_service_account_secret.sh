#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JSON_PATH="${1:-"$REPO_ROOT/play-service-account.json"}"

if [ ! -f "$JSON_PATH" ]; then
  echo "Arquivo nao encontrado: $JSON_PATH" >&2
  echo "Dica: copie $REPO_ROOT/play-service-account.json.example para play-service-account.json e cole o JSON real." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 nao encontrado. Instale Python 3 para validar o JSON." >&2
  exit 1
fi

python3 - "$JSON_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

required = ["type", "client_email", "private_key"]
missing = [k for k in required if k not in data or not data[k]]
if missing:
    raise SystemExit(f"JSON invalido: faltando {', '.join(missing)}")
if data.get("type") != "service_account":
    raise SystemExit("JSON invalido: type != service_account")

print(f"Service account: {data['client_email']}")
PY

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
gh secret set PLAY_SERVICE_ACCOUNT_JSON < "$JSON_PATH"
echo "Secret PLAY_SERVICE_ACCOUNT_JSON configurado no GitHub."

