#!/usr/bin/env bash
# Run AFTER terraform apply has enabled Cloud Foundry on the recovery subaccount.
# Creates a named space and assigns all standard space roles to the admin user.
#
# Prerequisites:
#   - cf login -a <API from Cockpit> --sso
#   - target the NEW org created for the recovery subaccount
#   - terraform.tfvars present (for defaults) or pass env vars
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TFVARS="$ROOT/terraform/terraform.tfvars"

space_from_tfvars() {
  local key="$1"
  [[ -f "$TFVARS" ]] || return 0
  grep -E "^[[:space:]]*${key}[[:space:]]*=" "$TFVARS" | head -1 | sed -E 's/.*=[[:space:]]*"([^"]*)".*/\1/'
}

DEFAULT_SPACE="$(space_from_tfvars cf_space_name)"
DEFAULT_EMAIL="$(space_from_tfvars admin_user_email)"
DEFAULT_SPACE="${DEFAULT_SPACE:-DEV}"

echo "=== Create CF space + assign roles ==="
echo "Current CF target:"
cf target
echo

read -r -p "Space name [${DEFAULT_SPACE}]: " SPACE
SPACE="${SPACE:-$DEFAULT_SPACE}"

read -r -p "User email for space roles [${DEFAULT_EMAIL}]: " EMAIL
EMAIL="${EMAIL:-$DEFAULT_EMAIL}"
if [[ -z "$EMAIL" ]]; then
  echo "Email is required."
  exit 1
fi

ORG="$(cf target | awk -F: '/org:/ {gsub(/^ +| +$/,"",$2); print $2}')"
if [[ -z "$ORG" ]]; then
  echo "Could not detect org from cf target. Run: cf target -o <recovery-org>"
  exit 1
fi

echo
echo "Creating space '${SPACE}' in org '${ORG}'..."
cf create-space "$SPACE" -o "$ORG" || true
cf target -o "$ORG" -s "$SPACE"

echo "Assigning space roles to ${EMAIL}..."
for ROLE in SpaceDeveloper SpaceManager SpaceAuditor SpaceSupporter; do
  echo "  → $ROLE"
  # SpaceSupporter may not exist on all landscapes; don't fail the script
  cf set-space-role "$EMAIL" "$ORG" "$SPACE" "$ROLE" || {
    echo "    (skipped or failed: $ROLE — check if this role exists on your landscape)"
  }
done

echo
echo "Done. Active target:"
cf target
echo
echo "Verify: cf space-users \"$ORG\" \"$SPACE\""
