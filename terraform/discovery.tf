############################################################
# Optional discovery — list Global Account subaccounts
# Off by default: some landscapes return 404 on this API and
# that would block terraform plan/apply. Enable when needed:
#   enable_subaccount_discovery = true
# Or: btp list accounts/subaccount
############################################################

variable "enable_subaccount_discovery" {
  type        = bool
  description = "If true, query all subaccounts (can 404 on some trials and fail plan)"
  default     = false
}

data "btp_subaccounts" "all" {
  count = var.enable_subaccount_discovery ? 1 : 0
}

output "available_subaccounts" {
  description = "All subaccounts when enable_subaccount_discovery=true — else empty"
  value = var.enable_subaccount_discovery ? [
    for s in data.btp_subaccounts.all[0].values : {
      id        = s.id
      name      = s.name
      subdomain = s.subdomain
      region    = s.region
      state     = s.state
    }
  ] : []
}
