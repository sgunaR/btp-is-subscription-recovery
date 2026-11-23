############################################################
# Discovery — list Global Account subaccounts
# Auth: btp login --url https://cli.btp.cloud.sap --sso --subdomain "<GA-subdomain>"
#    then: USE_BTPCLI_SESSION=true
#    or: BTP_USERNAME + BTP_PASSWORD  (cf login is not reused)
# Then:  terraform init && terraform plan
# Outputs show every subaccount id/name/subdomain so you can
# pick the stuck one for source_subaccount_id (no auto-guess:
# "decommissioning" is not a reliable filter in the API).
############################################################

data "btp_subaccounts" "all" {}

output "available_subaccounts" {
  description = "All subaccounts in the Global Account — use the stuck one's id as source_subaccount_id"
  value = [
    for s in data.btp_subaccounts.all.values : {
      id        = s.id
      name      = s.name
      subdomain = s.subdomain
      region    = s.region
      state     = s.state
    }
  ]
}
