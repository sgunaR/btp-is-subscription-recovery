############################################################
# Assign entitlements on the recovery subaccount.
#
# Free quota on the *source* first with:
#   ./scripts/free_source_entitlements.sh
# (BTP CLI --amount 0). Terraform cannot set amount = 0 —
# the provider rejects it (must be 1..N); destroy/import of
# pre-existing entitlements is awkward, so CLI is the path.
############################################################

# --- Recovery: Integration Suite trial = 1 ---
resource "btp_subaccount_entitlement" "integration_suite" {
  subaccount_id = btp_subaccount.recovery.id
  service_name  = var.integration_suite_entitlement_service_name
  plan_name     = var.integration_suite_plan_name
  amount        = 1
}

# --- Recovery: CF Runtime MEMORY units ---
resource "btp_subaccount_entitlement" "cf_runtime_memory" {
  subaccount_id = btp_subaccount.recovery.id
  service_name  = "APPLICATION_RUNTIME"
  plan_name     = "MEMORY"
  amount        = var.cf_runtime_amount
}

# --- Recovery: Process Integration Runtime plans (needed for later PIR instances) ---
resource "btp_subaccount_entitlement" "pir_api" {
  subaccount_id = btp_subaccount.recovery.id
  service_name  = "it-rt"
  plan_name     = "api"
}

resource "btp_subaccount_entitlement" "pir_integration_flow" {
  subaccount_id = btp_subaccount.recovery.id
  service_name  = "it-rt"
  plan_name     = "integration-flow"
}
