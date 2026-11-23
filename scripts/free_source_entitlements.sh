#!/usr/bin/env bash
# Free Integration Suite + CF MEMORY entitlements on the source subaccount.
# Terraform cannot set amount=0 (provider validation). BTP CLI can:
#   btp assign accounts/entitlement ... --amount 0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TFVARS="$ROOT/terraform/terraform.tfvars"

if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$ROOT/.env"
  set +a
fi

if [[ ! -f "$TFVARS" ]]; then
  echo "Missing terraform/terraform.tfvars — run ./scripts/configure.sh --from-env first."
  exit 1
fi

get_var() {
  local key="$1"
  grep -E "^[[:space:]]*${key}[[:space:]]*=" "$TFVARS" | head -1 \
    | sed -E 's/.*=[[:space:]]*"?([^"=]*)"?[[:space:]]*$/\1/' | tr -d ' '
}

SOURCE_ID="$(get_var source_subaccount_id)"
ENT_SVC="$(get_var integration_suite_entitlement_service_name)"
PLAN="$(get_var integration_suite_plan_name)"
ENT_SVC="${ENT_SVC:-${INTEGRATION_SUITE_ENTITLEMENT_SERVICE_NAME:-integrationsuite-trial}}"
PLAN="${PLAN:-${INTEGRATION_SUITE_PLAN_NAME:-trial}}"

if [[ -z "$SOURCE_ID" || "$SOURCE_ID" == "00000000-0000-0000-0000-000000000000" ]]; then
  echo "source_subaccount_id missing in terraform.tfvars"
  exit 1
fi

if [[ "${USE_BTPCLI_SESSION:-}" != "true" ]] && [[ -z "${BTP_USERNAME:-}" ]]; then
  echo "Authenticate first: ./scripts/btp_login.sh && source ./scripts/load_env.sh"
  exit 1
fi

if ! command -v btp >/dev/null 2>&1; then
  echo "'btp' not found. macOS: brew install --cask btp"
  exit 1
fi

echo "=== Free source entitlements (amount 0 via btp CLI) ==="
echo "  subaccount: $SOURCE_ID"
echo

assign0() {
  local svc="$1" plan="$2"
  echo "→ $svc / $plan → 0"
  set +e
  OUT="$(btp assign accounts/entitlement \
    --to-subaccount "$SOURCE_ID" \
    --for-service "$svc" \
    --plan "$plan" \
    --amount 0 2>&1)"
  RC=$?
  set -e
  echo "$OUT"
  if [[ $RC -ne 0 ]]; then
    if echo "$OUT" | grep -qiE 'already|not assigned|amount.*0|removed|does not exist'; then
      echo "  (ok to continue)"
    else
      echo "Failed to free $svc / $plan"
      exit 1
    fi
  fi
}

assign0 "$ENT_SVC" "$PLAN"
assign0 "APPLICATION_RUNTIME" "MEMORY"

echo
echo "Done. Next: cd terraform && terraform plan && terraform apply"
