variable "globalaccount_subdomain" {
  type        = string
  description = "Global Account subdomain from Cockpit (CLI Setup / Terraform Setup). Trial often ends with -ga, e.g. xxxxxxxxtrial-ga — not the CF org name alone."
}

variable "cli_server_url" {
  type        = string
  description = "BTP CLI server URL (Cockpit → Terraform Setup)"
  default     = "https://cli.btp.cloud.sap"
}

variable "region" {
  type        = string
  description = "BTP region for the recovery subaccount (must match available trial region), e.g. us10"
  default     = "us10"
}

variable "source_subaccount_id" {
  type        = string
  description = "GUID of the stuck subaccount where Integration Suite subscribe fails (Cockpit → Subaccount → Overview)"
}

variable "recovery_subaccount_name" {
  type        = string
  description = "Display name for the new recovery subaccount"
  default     = "is-recovery"
}

variable "recovery_subaccount_subdomain" {
  type        = string
  description = "Globally unique subdomain for the recovery subaccount (lowercase, no spaces)"
}

variable "cf_org_name" {
  type        = string
  description = "Cloud Foundry org instance name to create inside the recovery subaccount"
  default     = "is-recovery-org"
}

variable "cf_space_name" {
  type        = string
  description = "CF space name to create after apply via scripts/create_cf_space.sh (not created by Terraform BTP provider)"
  default     = "DEV"
}

variable "admin_user_email" {
  type        = string
  description = "User to receive Subaccount Admin + Integration_Provisioner style assignments"
}

variable "free_source_entitlements" {
  type        = bool
  description = "If true, set Integration Suite + CF Runtime amounts to 0 on the source (stuck) subaccount first"
  default     = true
}

variable "create_integration_suite_subscription" {
  type        = bool
  description = "Create the Integration Suite subscription on the recovery subaccount"
  default     = true
}

# Entitlement service_name and subscription app_name are NOT the same on many trials.
# Example: entitlement = integrationsuite-trial, subscription app = it-cpitrial06-prov
# Discover with: btp list accounts/entitlement|subscription --subaccount <guid>

variable "integration_suite_entitlement_service_name" {
  type        = string
  description = "Entitlement service_name for Integration Suite (btp list accounts/entitlement). Trial often integrationsuite-trial."
  default     = "integrationsuite-trial"
}

variable "integration_suite_subscription_app_name" {
  type        = string
  description = "Subscription app_name for Integration Suite (btp list accounts/subscription → app name column). Trial often it-cpitrial06-prov — NOT integrationsuite."
  default     = "it-cpitrial06-prov"
}

variable "integration_suite_plan_name" {
  type        = string
  description = "Plan name for entitlement and subscription (usually trial)"
  default     = "trial"
}

# Deprecated alias — prefer the two variables above. Kept so old tfvars still parse.
variable "integration_suite_app_name" {
  type        = string
  description = "Deprecated: use integration_suite_subscription_app_name / integration_suite_entitlement_service_name"
  default     = ""
}

variable "cf_runtime_amount" {
  type        = number
  description = "MEMORY units for Cloud Foundry Runtime (trial default is often 4)"
  default     = 4
}

variable "cf_environment_plan_name" {
  type        = string
  description = "Cloud Foundry environment plan (trial landscapes usually \"trial\"; some use \"standard\")"
  default     = "trial"
}
