############################################################
# Delete Integration Suite on the stuck (source) subaccount
#
# Normal `terraform apply` keeps manage_source_is_for_delete=false
# so this resource is NOT created.
#
# scripts/delete_source_integration_suite.sh temporarily sets the
# flag, imports the existing subscription (if any), and destroys it.
############################################################

variable "manage_source_is_for_delete" {
  type        = bool
  description = "Internal: set true only by delete_source_integration_suite.sh"
  default     = false
}

variable "delete_source_integration_suite_subscription" {
  type        = bool
  description = "If true, run scripts/delete_source_integration_suite.sh before apply (recommended)"
  default     = true
}

resource "btp_subaccount_subscription" "source_is" {
  count = var.manage_source_is_for_delete ? 1 : 0

  subaccount_id = var.source_subaccount_id
  app_name      = var.integration_suite_subscription_app_name
  plan_name     = var.integration_suite_plan_name

  timeouts = {
    delete = "45m"
  }
}
