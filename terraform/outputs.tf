output "recovery_subaccount_id" {
  description = "GUID of the recovery subaccount"
  value       = btp_subaccount.recovery.id
}

output "recovery_subaccount_subdomain" {
  value = btp_subaccount.recovery.subdomain
}

output "cf_environment_id" {
  description = "Cloud Foundry environment instance id"
  value       = btp_subaccount_environment_instance.cloudfoundry.id
}

output "next_steps" {
  value = <<-EOT
    1. Open the recovery subaccount in BTP Cockpit.
    2. Confirm Integration Suite is subscribed; assign remaining IS role collections, then open IS in Incognito and Add Capabilities.
    3. Create the CF space (scripts/create_cf_space.sh) if you have not already: cf login -a <api> -o <new-org>, then run the script.
  EOT
}
