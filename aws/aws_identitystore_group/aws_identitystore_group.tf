resource "aws_identitystore_group" "this" {
  description       = var.description
  display_name      = var.display_name
  identity_store_id = var.identity_store_id

}
