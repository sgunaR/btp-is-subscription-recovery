#!/usr/bin/env bash
# Source repo-root .env into the current shell (safe KEY=VALUE lines only).
# Usage:  source "$(dirname "$0")/load_env.sh"
# Or:     . scripts/load_env.sh

_ENV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_ENV_FILE="${ENV_FILE:-$_ENV_ROOT/.env}"

if [[ ! -f "$_ENV_FILE" ]]; then
  echo "No .env at $_ENV_FILE — copy .env.example to .env and fill it in." >&2
  return 1 2>/dev/null || exit 1
fi

set -a
# shellcheck disable=SC1090
source "$_ENV_FILE"
set +a

# Export aliases Terraform / provider expect
if [[ -n "${BTP_USERNAME:-}" ]]; then export BTP_USERNAME; fi
if [[ -n "${BTP_PASSWORD:-}" ]]; then export BTP_PASSWORD; fi
if [[ -n "${USE_BTPCLI_SESSION:-}" ]]; then export USE_BTPCLI_SESSION; fi

echo "Loaded $_ENV_FILE"
