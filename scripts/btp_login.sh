#!/usr/bin/env bash
# Log in to BTP CLI using values from .env (Cockpit CLI Setup shape).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"

GA="${GLOBALACCOUNT_SUBDOMAIN:-}"
URL="${CLI_SERVER_URL:-https://cli.btp.cloud.sap}"

if [[ -z "$GA" ]]; then
  echo "GLOBALACCOUNT_SUBDOMAIN is empty in .env"
  exit 1
fi

if ! command -v btp >/dev/null 2>&1; then
  echo "'btp' not found. macOS: brew install --cask btp"
  exit 1
fi

echo "Logging in with SSO (do not paste other commands into prompts):"
echo "  btp login --url $URL --sso --subdomain \"$GA\""
echo
btp login --url "$URL" --sso --subdomain "$GA"

echo
echo "Login OK. In this shell (or any new shell that sources .env):"
echo "  export USE_BTPCLI_SESSION=true"
echo "  ./scripts/delete_source_integration_suite.sh"
