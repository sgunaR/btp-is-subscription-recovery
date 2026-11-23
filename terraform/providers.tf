# Auth (CF login is NOT reused — different API):
#   Preferred (matches Cockpit → CLI Setup):
#     btp login --url https://cli.btp.cloud.sap --sso --subdomain "<globalaccount-subdomain>"
#     export USE_BTPCLI_SESSION=true
#   Alternative: export BTP_USERNAME=... BTP_PASSWORD=...
#
# globalaccount = Global Account subdomain from Cockpit (often ends with -ga on trials),
# NOT the CF org name alone. Cockpit → subaccount → CLI Setup / Terraform Setup shows it.

provider "btp" {
  globalaccount  = var.globalaccount_subdomain
  cli_server_url = var.cli_server_url
}
