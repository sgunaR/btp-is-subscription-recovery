# BTP Integration Suite — Subscription Failure Recovery

## The error

You try to subscribe to SAP Integration Suite on BTP and Cockpit returns:

> *You can't subscribe to the service as decommissioning is in progress. Please try again after decommissioning is completed.*

This usually happens after Integration Suite was deleted, expired, or removed (common on trial). SAP often needs **24–48 hours** to finish decommissioning before a re-subscribe on the **same** subaccount works. Waiting is the supported path.

## The idea

Instead of waiting on the stuck subaccount, recover by:

1. Removing any unfinished Integration Suite subscription on the stuck (source) subaccount  
2. Freeing entitlements there (IS → 0, CF MEMORY → 0)  
3. Creating a **new** subaccount  
4. Moving entitlements to the new subaccount  
5. Enabling Cloud Foundry, assigning roles, and subscribing Integration Suite again  

This repo automates that with **Terraform** ([`SAP/btp`](https://registry.terraform.io/providers/SAP/btp/latest)) and small shell helpers.

Your Global Account subdomain, stuck Subaccount GUID, and recovery names are **different for every person / landscape**. Nothing landscape-specific is hard-coded in the repo. Each user keeps their values in a local **`.env`** (gitignored).

## Install dependencies

| Tool | Why |
|------|-----|
| **CF CLI v8** | Create spaces after CF is enabled |
| **BTP CLI** | Global Account SSO for Terraform (`btp login --sso`) |
| **Terraform ≥ 1.5** | Downloads `SAP/btp` on first `terraform init` |
| **Global Account admin** | Entitlement moves and new subaccounts |

**`cf login` cannot authenticate Terraform.** CF is orgs/spaces only. Subaccount create and entitlement moves use the BTP accounts API via BTP CLI SSO (or username/password).

### 1. Cloud Foundry CLI (v8)

Guide: [CF CLI v8 installation](https://github.com/cloudfoundry/cli/wiki/V8-CLI-Installation-Guide) · [Releases](https://github.com/cloudfoundry/cli/releases)

**macOS**

```bash
brew install cloudfoundry/tap/cf-cli@8
cf version
```

**Windows (Chocolatey)**

```powershell
choco install cloudfoundry-cli
cf version
```

**Linux (Debian / Ubuntu)**

```bash
curl -fsSL https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/cloudfoundry-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/cloudfoundry-keyring.gpg] https://packages.cloudfoundry.org/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/cloudfoundry.list

sudo apt-get update
sudo apt-get install -y cf8-cli
cf version
```

**Linux (RHEL / Fedora / CentOS)**

```bash
sudo wget -O /etc/yum.repos.d/cloudfoundry-cli.repo \
  https://packages.cloudfoundry.org/fedora/cloudfoundry-cli.repo
sudo yum install -y cf8-cli
cf version
```

### 2. BTP CLI (Terraform auth)

Docs: [SAP BTP CLI](https://help.sap.com/docs/btp/sap-business-technology-platform/download-and-build-btp-cli-client) · Downloads: [tools.hana.ondemand.com](https://tools.hana.ondemand.com/#cloud-cpcli)

**macOS**

```bash
brew install --cask btp
btp --version
```

**Windows:** `winget install --id SAP.btp -e`, or download from the tools page.  
**Linux:** Homebrew cask, or download `linux-amd64` / `linux-arm64` from the tools page.

### 3. Terraform

Guide: [Install Terraform](https://developer.hashicorp.com/terraform/install)

**macOS**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

**Windows:** `choco install terraform`  
**Linux:** follow HashiCorp’s install page, then `terraform version`.

## Step by step

### Quick path (after tools are installed)

Use **bash** for these commands (`bash` if your default shell is fish). Helper scripts load `.env` themselves.

```bash
cp .env.example .env          # once — put YOUR Cockpit values in .env (see Step 3)
./scripts/configure.sh --from-env
./scripts/btp_login.sh        # browser SSO; do not paste other commands into prompts
export USE_BTPCLI_SESSION=true
./scripts/delete_source_integration_suite.sh
./scripts/free_source_entitlements.sh   # IS + CF MEMORY → 0 on source (btp CLI; Terraform cannot amount=0)
cd terraform && terraform init && terraform plan && terraform apply
cd .. && ./scripts/create_cf_space.sh   # after CF is enabled on the NEW subaccount
```

Notes:

- Copy Global Account subdomain from Cockpit **CLI Setup** (often `…trial-ga`, not `…trialtrial-ga`).  
- Subscription app name is often `it-cpitrial06-prov`; entitlement service is often `integrationsuite-trial`.  
- You do **not** re-edit `.env` every day. Re-run `./scripts/btp_login.sh` when the session expires.  
- In **fish**: do not `source ./scripts/load_env.sh` — use `set -x USE_BTPCLI_SESSION true` or switch to `bash`.

---

### Step 1 — Collect your landscape values

From **your** BTP Cockpit (values differ per trial / Global Account):

| What | Where in Cockpit |
|------|------------------|
| `GLOBALACCOUNT_SUBDOMAIN` | Subaccount → **CLI Setup** / **Terraform Setup** (often `…trial-ga`, not the CF org alone) |
| `SOURCE_SUBACCOUNT_ID` | Stuck subaccount → **Overview** → **Subaccount ID** (GUID) |
| `CLI_SERVER_URL` | Usually `https://cli.btp.cloud.sap` (same tabs) |
| CF API endpoint | Stuck subaccount → Overview / Cloud Foundry |
| Recovery names | You choose (subdomain must be globally unique) |

### Step 2 — CF SSO on the stuck landscape (optional prefills)

```bash
cf login -a https://api.cf.<your-region>.hana.ondemand.com/ --sso
cf target
# or: ./scripts/check_cf_context.sh
```

Use **your** API endpoint from Cockpit. CF helps prefills in interactive configure; it does **not** replace BTP CLI login.

### Step 3 — Create `.env` and generate `terraform.tfvars`

The repo ships placeholders only:

```bash
cp .env.example .env   # only once on a fresh clone — do not re-run if .env already filled
```

Edit `.env` with **your** values (full template: [`.env.example`](.env.example)):

```bash
GLOBALACCOUNT_SUBDOMAIN=<your-id>trial-ga          # Cockpit CLI Setup — not CF org alone
SOURCE_SUBACCOUNT_ID=<stuck-subaccount-guid>
RECOVERY_SUBACCOUNT_NAME=is-recovery
RECOVERY_SUBACCOUNT_SUBDOMAIN=<globally-unique-name>  # never reuse a CREATION_FAILED name
ADMIN_USER_EMAIL=you@example.com
REGION=us10
INTEGRATION_SUITE_ENTITLEMENT_SERVICE_NAME=integrationsuite-trial
INTEGRATION_SUITE_SUBSCRIPTION_APP_NAME=it-cpitrial06-prov   # confirm via btp list
INTEGRATION_SUITE_PLAN_NAME=trial
CF_ENVIRONMENT_PLAN_NAME=trial
USE_BTPCLI_SESSION=true
```

Do not copy another person’s subdomain or GUID.

Write Terraform vars (no prompts):

```bash
./scripts/configure.sh --from-env
```

Or interactive (uses `.env` + CF as defaults):

```bash
./scripts/configure.sh
```

**Never commit** `.env` or `terraform/terraform.tfvars`.

### Step 4 — Log in to the Global Account (BTP CLI SSO)

```bash
./scripts/btp_login.sh
export USE_BTPCLI_SESSION=true
```

`btp_login.sh` runs the same shape as Cockpit **CLI Setup**:

```bash
btp login --url https://cli.btp.cloud.sap --sso --subdomain "<YOUR-globalaccount-subdomain>"
```

- Always use **`--sso`** (otherwise the CLI asks for User/Password).  
- Finish the **browser** flow — do **not** paste other commands into prompts.  
- Keep `USE_BTPCLI_SESSION=true` in the same shell (scripts also read `.env`).

Password fallback: set `BTP_USERNAME` / `BTP_PASSWORD` in `.env` and `USE_BTPCLI_SESSION=false`.

### Step 5 — Delete unfinished Integration Suite on the source

Requires configure + working BTP auth first:

```bash
./scripts/delete_source_integration_suite.sh
```

The script discovers the real subscription **app name** with `btp list accounts/subscription` (on trial this is often `it-cpitrial06-prov`, **not** `integrationsuite`), then unsubscribes via BTP CLI (Terraform import/destroy as fallback).

If delete still fails, check:

```bash
btp list accounts/subscription --subaccount <SOURCE_SUBACCOUNT_ID>
btp list accounts/entitlement --subaccount <SOURCE_SUBACCOUNT_ID>
```

Put the **app name** column into `INTEGRATION_SUITE_SUBSCRIPTION_APP_NAME` and the entitlement service into `INTEGRATION_SUITE_ENTITLEMENT_SERVICE_NAME` in `.env`, then re-run configure + delete.

### Step 6 — Free source entitlements (quota)

Terraform **cannot** set entitlement `amount = 0` (provider requires 1…N). Use BTP CLI:

```bash
./scripts/free_source_entitlements.sh
```

That runs `btp assign accounts/entitlement … --amount 0` for Integration Suite and CF MEMORY on the source subaccount.

### Step 7 — Plan and apply recovery

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Optional: list subaccounts via Terraform with `enable_subaccount_discovery = true` in `terraform.tfvars` (can 404 on some trials). Prefer `btp list accounts/subaccount` instead.

Default apply order (after source quota is freed):

1. Create recovery subaccount  
2. Recovery: IS = 1, MEMORY = 4, PIR `api` + `integration-flow`  
3. Enable Cloud Foundry  
4. Assign role collections  
5. Subscribe Integration Suite on the recovery subaccount  

Use `available_subaccounts` from plan if you need to confirm the stuck GUID, then put it in `.env` and re-run `./scripts/configure.sh --from-env`.

### Step 8 — CF space on the new subaccount

Terraform enables the CF **environment / org**, not a space.

1. Cockpit → **new** recovery subaccount → copy **API Endpoint**  
2. `cf login -a <new-api-endpoint> --sso` (select the **new** org)  
3. From repo root:

```bash
./scripts/create_cf_space.sh
```

### Step 9 — Finish in Cockpit

Confirm the Integration Suite subscription on the recovery subaccount, then activate capabilities as usual.

### If recovery shows **Creation Failed**

Cockpit may show a red **Creation Failed** card (e.g. `trial2`). That subaccount is unusable; Terraform often still tracks it as `CREATION_FAILED`.

```bash
./scripts/btp_login.sh
export USE_BTPCLI_SESSION=true
./scripts/cleanup_failed_recovery.sh
```

Then set a **new** unique `RECOVERY_SUBACCOUNT_SUBDOMAIN` in `.env` (do not reuse the failed subdomain), run `./scripts/configure.sh --from-env`, and `terraform apply` again. Delete the failed card in Cockpit if it remains.

## What each tool covers

| Layer | Can do | Cannot do |
|-------|--------|-----------|
| **Terraform `SAP/btp`** | Subaccount, entitlements, CF environment, role collections, subscription | CF spaces / apps |
| **BTP CLI** | Global Account login session for Terraform | Replace CF space creation |
| **CF CLI** | Spaces, apps, instances in an existing org | Global Account entitlements or new BTP subaccounts |
| **BTP Cockpit** | Same operations manually; shows your CLI / Terraform snippets | — |

## Repository layout

```
├── README.md
├── LICENSE
├── .env.example          # placeholders — copy to .env (gitignored)
├── .gitignore
├── docs/architecture.md
├── terraform/            # recovery resources + discovery outputs
└── scripts/
    ├── load_env.sh                         # source .env
    ├── btp_login.sh                        # SSO using your GLOBALACCOUNT_SUBDOMAIN
    ├── check_cf_context.sh
    ├── configure.sh                        # → terraform.tfvars (--from-env)
    ├── delete_source_integration_suite.sh  # unfinished IS on source
    ├── free_source_entitlements.sh         # amount 0 via btp CLI
    ├── cleanup_failed_recovery.sh          # CREATION_FAILED subaccount
    └── create_cf_space.sh                  # after apply
```

More detail: [docs/architecture.md](docs/architecture.md).

## Disclaimer

Community automation, not official SAP support. Service/plan technical names can differ by landscape — validate in Cockpit before apply. Use at your own risk.
