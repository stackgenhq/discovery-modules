# provider "azurerm" {
#   features {}
# }

mock_provider "azurerm" {}

variables {
  # Required inputs - must be provided by user
  location            = "East US"
  resource_group_name = "example-rg"

  name                              = "disk"
  storage_account_type              = "UltraSSD_LRS"
  create_option                     = "Empty"
  disk_encryption_set_id            = null
  disk_iops_read_write              = 1
  disk_mbps_read_write              = 1
  disk_iops_read_only               = null
  disk_mbps_read_only               = null
  upload_size_bytes                 = null
  disk_size_gb                      = 64
  edge_zone                         = null
  hyper_v_generation                = null
  image_reference_id                = null
  gallery_image_reference_id        = null
  logical_sector_size               = "4096"
  optimized_frequent_attach_enabled = false
  performance_plus_enabled          = false
  os_type                           = null
  source_resource_id                = null
  source_uri                        = null
  storage_account_id                = null
  tier                              = null
  max_shares                        = null
  trusted_launch_enabled            = null
  security_type                     = null
  secure_vm_disk_encryption_set_id  = null
  on_demand_bursting_enabled        = null
  tags                              = null
  zone                              = null
  network_access_policy             = null
  disk_access_id                    = null
  public_network_access_enabled     = false
  encryption_settings               = []
}

run "test" {
  command = plan
  assert {
    condition     = azurerm_managed_disk.this.name == "disk"
    error_message = "azurerm_managed_disk did not create"
  }
}
