#!/usr/bin/env bash
# Print Cloud Foundry target. Useful to confirm you are on the landscape
# that has the Integration Suite subscription failure — but remember:
# entitlement moves require Terraform BTP (Global Account), not CF alone.
set -euo pipefail

echo "== cf version =="
cf version || { echo "CF CLI not found"; exit 1; }

echo
echo "== cf target =="
cf target

echo
echo "== spaces =="
cf spaces || true

echo
echo "Note: To move Integration Suite / CF Runtime entitlements across subaccounts,"
echo "use terraform/ with the SAP BTP provider (Global Account credentials)."
