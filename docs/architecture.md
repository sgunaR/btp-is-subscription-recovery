# Architecture

## Actors

```text
┌─────────────────────┐     Terraform SAP/btp      ┌──────────────────────┐
│  Global Account     │◄──────────────────────────►│  Operator / CI        │
│  (entitlement pool) │     BTP credentials         │  (+ optional CF CLI)  │
└─────────┬───────────┘                            └──────────────────────┘
          │
          ├── Subaccount A (stuck) — Integration Suite decommissioning / subscribe fails
          │
          └── Subaccount B (recovery) — created; quota moved here
                    CF org/space → Integration Suite → capabilities
```

## Why CF login is not enough

Cloud Foundry CLI authenticates to a **CF API endpoint / org / space**. Subaccount creation and entitlement assignment live in the **BTP accounts** plane (Global Account). The Terraform provider talks to that plane — it cannot reuse `cf login` tokens.

Use **`btp login --url https://cli.btp.cloud.sap --sso --subdomain "<GA-subdomain>"`** + `USE_BTPCLI_SESSION=true`, or `BTP_USERNAME` / `BTP_PASSWORD`. Copy the exact login line from Cockpit **CLI Setup**.

Typical sequence after Terraform:

1. `terraform apply` creates the recovery subaccount, moves entitlements, and enables CF  
2. In Cockpit (or with CF CLI), create a space and assign space roles  
3. Subscribe / open Integration Suite, assign remaining role collections, activate capabilities  

## Failure modes

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| Entitlement assign fails: insufficient quota | Source still holds IS or MEMORY | Run `./scripts/free_source_entitlements.sh` (btp `--amount 0`); Terraform cannot set amount 0 |
| `amount value must be between 1 and …` | Old Terraform used `amount = 0` | Use `free_source_entitlements.sh` instead |
| `Integration_Provisioner` assign fails | Role collection not provisioned yet | Subscribe first, then re-apply role assignments |
| CF environment plan error (`standard` vs `trial`) | Landscape-specific plan name | Adjust `plan_name` in `main.tf` using Cockpit values |

## Manual steps ↔ Terraform resources

| Manual step | Terraform resource |
|-------------|--------------------|
| Create new subaccount | `btp_subaccount.recovery` |
| Decrease IS quota on old / set 1 on new | `source_integration_suite_zero` → `integration_suite` |
| Move CF Runtime MEMORY units | `source_cf_runtime_zero` → `cf_runtime_memory` |
| Add PIR `api` + `integration-flow` | `pir_api`, `pir_integration_flow` |
| Enable Cloud Foundry | `btp_subaccount_environment_instance.cloudfoundry` |
| Assign admin / provisioner | `btp_subaccount_role_collection_assignment.*` |
| Create space + space roles | `scripts/create_cf_space.sh` (CF CLI; prompted space name) |
| Discover stuck subaccount | Cockpit Overview GUID, or `available_subaccounts` output / `configure.sh` |
| Delete unfinished IS on source | `scripts/delete_source_integration_suite.sh` (import + destroy) |
| Add Capabilities | Manual (Integration Suite UI) |
