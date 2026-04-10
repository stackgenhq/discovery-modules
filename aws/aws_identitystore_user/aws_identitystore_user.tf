resource "aws_identitystore_user" "this" {
  display_name       = var.display_name
  identity_store_id  = var.identity_store_id
  locale             = var.locale
  nickname           = var.nickname
  preferred_language = var.preferred_language
  profile_url        = var.profile_url
  timezone           = var.timezone
  title              = var.title
  user_name          = var.user_name
  user_type          = var.user_type

  dynamic "addresses" {
    for_each = var.addresses != null ? var.addresses : []
    content {
      country        = addresses.value.country
      formatted      = addresses.value.formatted
      locality       = addresses.value.locality
      postal_code    = addresses.value.postal_code
      primary        = addresses.value.primary
      region         = addresses.value.region
      street_address = addresses.value.street_address
      type           = addresses.value.type
    }
  }

  dynamic "emails" {
    for_each = var.emails != null ? var.emails : []
    content {
      primary = emails.value.primary
      type    = emails.value.type
      value   = emails.value.value
    }
  }

  dynamic "name" {
    for_each = var.name
    content {
      family_name      = name.value.family_name
      formatted        = name.value.formatted
      given_name       = name.value.given_name
      honorific_prefix = name.value.honorific_prefix
      honorific_suffix = name.value.honorific_suffix
      middle_name      = name.value.middle_name
    }
  }

  dynamic "phone_numbers" {
    for_each = var.phone_numbers != null ? var.phone_numbers : []
    content {
      primary = phone_numbers.value.primary
      type    = phone_numbers.value.type
      value   = phone_numbers.value.value
    }
  }

}
