#!/usr/bin/env bash
# Remove a CREATION_FAILED recovery subaccount from BTP + Terraform state,
# so you can re-apply with a new unique subdomain.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT/terraform"
TFVARS="$TF_DIR/terraform.tfvars"
STATE="$TF_DIR/terraform.tfstate"

if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$ROOT/.env"
  set +a
fi

if [[ "${USE_BTPCLI_SESSION:-}" != "true" ]] && [[ -z "${BTP_USERNAME:-}" ]]; then
  echo "Authenticate first: ./scripts/btp_login.sh && source ./scripts/load_env.sh"
  exit 1
fi

if ! command -v btp >/dev/null 2>&1; then
  echo "'btp' not found. macOS: brew install --cask btp"
  exit 1
fi

cd "$TF_DIR"
RECOVERY_ID="$(python3 - <<'PY'
import json
from pathlib import Path
p = Path("terraform.tfstate")
if not p.exists():
  raise SystemExit
s = json.loads(p.read_text())
for r in s.get("resources", []):
  if r.get("type") == "btp_subaccount" and r.get("name") == "recovery":
    for inst in r.get("instances", []):
      a = inst.get("attributes") or {}
      print(a.get("id", ""))
      raise SystemExit
PY
)"

NAME="$(grep -E '^[[:space:]]*recovery_subaccount_name' "$TFVARS" 2>/dev/null | sed -E 's/.*=[[:space:]]*"?([^"=]*)"?.*/\1/' | tr -d ' ' || true)"
SUB="$(grep -E '^[[:space:]]*recovery_subaccount_subdomain' "$TFVARS" 2>/dev/null | sed -E 's/.*=[[:space:]]*"?([^"=]*)"?.*/\1/' | tr -d ' ' || true)"

echo "=== Cleanup failed recovery subaccount ==="
echo "  name/subdomain: ${NAME:-?} / ${SUB:-?}"
echo "  id from state:  ${RECOVERY_ID:-<none>}"
echo

if [[ -n "${RECOVERY_ID:-}" ]]; then
  echo "Deleting subaccount via btp CLI (ok if already gone)..."
  set +e
  btp delete accounts/subaccount "$RECOVERY_ID" --confirm true 2>&1
  set -e
  echo
  echo "Removing from Terraform state..."
  terraform state rm 'btp_subaccount.recovery' 2>/dev/null || true
  # Also drop dependents that may have partial state
  for addr in \
    'btp_subaccount_entitlement.integration_suite' \
    'btp_subaccount_entitlement.cf_runtime_memory' \
    'btp_subaccount_entitlement.pir_api' \
    'btp_subaccount_entitlement.pir_integration_flow' \
    'btp_subaccount_environment_instance.cloudfoundry' \
    'btp_subaccount_subscription.integration_suite[0]' \
    'btp_subaccount_role_collection_assignment.subaccount_admin' \
    'btp_subaccount_role_collection_assignment.integration_provisioner[0]'
  do
    terraform state rm "$addr" 2>/dev/null || true
  done
else
  echo "No recovery subaccount in state."
  echo "If Cockpit still shows a failed card, delete it there (Account Explorer → trial2 → Delete)."
fi

echo
echo "Next:"
echo "  1) Pick a NEW globally unique subdomain in .env (do not reuse a failed one):"
echo "       RECOVERY_SUBACCOUNT_SUBDOMAIN=is-recovery-\$RANDOM"
echo "  2) ./scripts/configure.sh --from-env"
echo "  3) cd terraform && terraform plan && terraform apply"
