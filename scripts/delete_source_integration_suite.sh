#!/usr/bin/env bash
# Delete Integration Suite subscription on the stuck (source) subaccount, if it exists.
# Discovers the real subscription app_name via btp CLI (often it-cpitrial06-prov, NOT integrationsuite).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT/terraform"
TFVARS="$TF_DIR/terraform.tfvars"

if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$ROOT/.env"
  set +a
fi

cd "$TF_DIR"

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
APP="$(get_var integration_suite_subscription_app_name)"
PLAN="$(get_var integration_suite_plan_name)"
# Fallback for older tfvars
if [[ -z "$APP" ]]; then
  APP="$(get_var integration_suite_app_name)"
fi
APP="${APP:-${INTEGRATION_SUITE_SUBSCRIPTION_APP_NAME:-}}"
PLAN="${PLAN:-${INTEGRATION_SUITE_PLAN_NAME:-trial}}"

if [[ -z "$SOURCE_ID" || "$SOURCE_ID" == "00000000-0000-0000-0000-000000000000" ]]; then
  echo "source_subaccount_id is missing or still a placeholder in terraform.tfvars"
  exit 1
fi

if [[ "${USE_BTPCLI_SESSION:-}" == "true" ]]; then
  if ! command -v btp >/dev/null 2>&1; then
    echo "USE_BTPCLI_SESSION=true but 'btp' is not installed. macOS: brew install --cask btp"
    exit 1
  fi
elif [[ -n "${BTP_USERNAME:-}" && -n "${BTP_PASSWORD:-}" ]]; then
  :
else
  echo "Authenticate first: ./scripts/btp_login.sh && source ./scripts/load_env.sh"
  exit 1
fi

echo "=== Delete source Integration Suite subscription (if present) ==="
echo "  subaccount: $SOURCE_ID"
echo

# Discover real app name — do NOT match unrelated apps whose *type* says "Integration Suite"
# (e.g. content-agent-ui). Real trial row looks like:
#   it-cpitrial06-prov   integrationsuite-trial   trial   ...   SUBSCRIBE_FAILED
CONFIGURED_APP="$APP"
DISCOVERED_APP=""
DISCOVERED_STATUS=""
if command -v btp >/dev/null 2>&1 && [[ "${USE_BTPCLI_SESSION:-}" == "true" ]]; then
  echo "Discovering Integration Suite subscription via btp CLI..."
  SUB_LIST="$(btp list accounts/subscription --subaccount "$SOURCE_ID" 2>/dev/null || true)"
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ [Aa]pp[[:space:]]+name ]] && continue
    [[ "$line" =~ ^Showing ]] && continue
    [[ "$line" =~ ^OK$ ]] && continue
    [[ "$line" =~ ^--- ]] && continue

    app_col="$(echo "$line" | awk '{print $1}')"
    commercial="$(echo "$line" | awk '{print $2}')"
    lower_app="$(echo "$app_col" | tr '[:upper:]' '[:lower:]')"
    lower_comm="$(echo "$commercial" | tr '[:upper:]' '[:lower:]')"

    # Match subscription app or commercial name only — not product-category text
    if [[ "$lower_app" == it-cpi* || "$lower_comm" == integrationsuite* ]]; then
      status="UNKNOWN"
      for s in SUBSCRIBE_FAILED SUBSCRIBED IN_PROCESS SUBSCRIBE_IN_PROGRESS UNSUBSCRIBE_FAILED DECOMMISSIONING NOT_SUBSCRIBED; do
        if [[ "$line" == *"$s"* ]]; then
          status="$s"
          break
        fi
      done
      if [[ "$status" == "NOT_SUBSCRIBED" ]]; then
        continue
      fi
      DISCOVERED_APP="$app_col"
      DISCOVERED_STATUS="$status"
      break
    fi
  done <<< "$SUB_LIST"

  if [[ -n "$DISCOVERED_APP" ]]; then
    echo "  found: app=$DISCOVERED_APP  status=$DISCOVERED_STATUS"
    APP="$DISCOVERED_APP"
  elif [[ -n "$CONFIGURED_APP" ]]; then
    echo "  no matching it-cpi*/integrationsuite* row; using configured: $CONFIGURED_APP"
    APP="$CONFIGURED_APP"
  else
    echo "  no Integration Suite subscription found."
  fi
fi

if [[ -z "$APP" ]]; then
  echo "Could not determine subscription app_name."
  echo "Run: btp list accounts/subscription --subaccount $SOURCE_ID"
  echo "Set INTEGRATION_SUITE_SUBSCRIPTION_APP_NAME in .env to the app name (e.g. it-cpitrial06-prov)."
  exit 1
fi

echo "  using app/plan: $APP / $PLAN"
echo

# 1) Preferred: btp unsubscribe (works even when Terraform guessed wrong names before)
if command -v btp >/dev/null 2>&1 && [[ "${USE_BTPCLI_SESSION:-}" == "true" ]]; then
  echo "Unsubscribing via btp CLI..."
  set +e
  UNSUB_OUT="$(btp unsubscribe accounts/subaccount --subaccount "$SOURCE_ID" --from-app "$APP" --confirm true 2>&1)"
  UNSUB_RC=$?
  set -e
  echo "$UNSUB_OUT"
  if [[ $UNSUB_RC -eq 0 ]]; then
    echo "Unsubscribe requested/completed via btp CLI."
    echo "Done. Next: ./scripts/cleanup_failed_recovery.sh (if needed), then free entitlements + terraform apply"
    exit 0
  fi
  # 90006 / "not currently subscribed" = already gone — treat as success
  if echo "$UNSUB_OUT" | grep -qiE 'not currently subscribed|is not currently subscribed|90006|NOT_SUBSCRIBED|does not exist|already unsub'; then
    echo "Already unsubscribed (nothing left to delete). Continuing."
    echo "Done. Next: ./scripts/free_source_entitlements.sh && (cleanup failed recovery if needed) && terraform apply"
    exit 0
  fi
  echo "btp unsubscribe failed — trying Terraform import + destroy..."
fi

# 2) Fallback: Terraform import + targeted destroy
terraform init -input=false >/dev/null
IMPORT_ID="${SOURCE_ID},${APP},${PLAN}"
TARGET='btp_subaccount_subscription.source_is[0]'

IMPORT_LOG="$(mktemp)"
set +e
terraform import -input=false \
  -var='manage_source_is_for_delete=true' \
  -var="integration_suite_subscription_app_name=${APP}" \
  -var="integration_suite_plan_name=${PLAN}" \
  "$TARGET" "$IMPORT_ID" >"$IMPORT_LOG" 2>&1
IMPORT_RC=$?
set -e
cat "$IMPORT_LOG"

if [[ $IMPORT_RC -eq 0 ]]; then
  terraform destroy -auto-approve -input=false \
    -var='manage_source_is_for_delete=true' \
    -var="integration_suite_subscription_app_name=${APP}" \
    -var="integration_suite_plan_name=${PLAN}" \
    -target="$TARGET"
  echo "Source Integration Suite subscription deleted via Terraform."
elif grep -qiE 'unableToCreateClient|Unauthorized|authentication|BTP CLI session' "$IMPORT_LOG"; then
  echo "Auth failed — subscription was NOT deleted."
  rm -f "$IMPORT_LOG"
  exit 1
elif grep -qiE 'Could not find application|90017|Missing Resource Identity|not currently subscribed|90006' "$IMPORT_LOG"; then
  echo
  echo "Subscription not readable / already gone (provider/API). Treat as deleted."
  echo "If Cockpit still shows Integration Suite, delete it there once, then continue."
  rm -f "$IMPORT_LOG"
  exit 0
else
  echo "Import inconclusive — if Cockpit still shows Integration Suite, delete it manually."
  rm -f "$IMPORT_LOG"
  exit 0
fi

rm -f "$IMPORT_LOG"
echo "Done. Next: cd terraform && terraform plan && terraform apply"
