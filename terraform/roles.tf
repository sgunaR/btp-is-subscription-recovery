############################################################
# Role collection assignments on the recovery subaccount
#
# Integration_Provisioner only exists AFTER Integration Suite
# is subscribed / roles are provisioned. We assign Subaccount
# Admin immediately; provisioner assignment is best-effort after
# subscription (see note below).
############################################################

resource "btp_subaccount_role_collection_assignment" "subaccount_admin" {
  subaccount_id        = btp_subaccount.recovery.id
  role_collection_name = "Subaccount Administrator"
  user_name            = var.admin_user_email
}

# Assign after subscription when the role collection exists.
resource "btp_subaccount_role_collection_assignment" "integration_provisioner" {
  count = var.create_integration_suite_subscription ? 1 : 0

  subaccount_id        = btp_subaccount.recovery.id
  role_collection_name = "Integration_Provisioner"
  user_name            = var.admin_user_email

  depends_on = [
    btp_subaccount_subscription.integration_suite,
  ]
}
