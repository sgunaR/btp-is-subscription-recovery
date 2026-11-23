############################################################
# Recovery subaccount + Cloud Foundry environment
############################################################

resource "btp_subaccount" "recovery" {
  name      = var.recovery_subaccount_name
  subdomain = var.recovery_subaccount_subdomain
  region    = var.region
}

# Enable Cloud Foundry on the recovery subaccount
resource "btp_subaccount_environment_instance" "cloudfoundry" {
  subaccount_id    = btp_subaccount.recovery.id
  name             = var.cf_org_name
  environment_type = "cloudfoundry"
  service_name     = "cloudfoundry"
  plan_name        = var.cf_environment_plan_name

  parameters = jsonencode({
    instance_name = var.cf_org_name
  })

  depends_on = [
    btp_subaccount_entitlement.cf_runtime_memory,
  ]
}

# Subscribe Integration Suite on the recovery subaccount.
resource "btp_subaccount_subscription" "integration_suite" {
  count = var.create_integration_suite_subscription ? 1 : 0

  subaccount_id = btp_subaccount.recovery.id
  app_name      = var.integration_suite_subscription_app_name
  plan_name     = var.integration_suite_plan_name

  depends_on = [
    btp_subaccount_entitlement.integration_suite,
    btp_subaccount_environment_instance.cloudfoundry,
  ]
}
