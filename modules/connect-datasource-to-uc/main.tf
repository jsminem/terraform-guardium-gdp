# Copyright (c) IBM Corporation
# SPDX-License-Identifier: Apache-2.0

# This module connects a data source to Guardium Universal Connector
# Uses API-based multipart upload for profile deployment

locals {
  udc_name = var.udc_name
  udc_csv  = var.udc_csv_parsed
}

# Create a temporary local CSV file with the profile configuration
# Using path.root to ensure CSV is written to customer's workspace, not cached module directory
resource "local_file" "csv_temp" {
  content  = local.udc_csv
  filename = "${path.root}/.terraform/${var.udc_name}.csv"
}

# Authenticate with Guardium to get OAuth access token
data "guardium-data-protection_authentication" "access_token" {
  client_secret = var.client_secret
  username      = var.gdp_username
  password      = var.gdp_password
  client_id     = var.client_id
}

# Import Universal Connector profiles from CSV file via API multipart upload
resource "guardium-data-protection_import_profiles" "import_profiles" {
  depends_on       = [local_file.csv_temp]
  access_token     = data.guardium-data-protection_authentication.access_token.access_token
  path_to_file     = abspath(local_file.csv_temp.filename)
  update_mode      = true
  test_connections = var.test_connections
}

# Install the Universal Connector on the specified Guardium Managed Unit
resource "guardium-data-protection_install_connector" "install_connector" {
  depends_on   = [guardium-data-protection_import_profiles.import_profiles]
  access_token = data.guardium-data-protection_authentication.access_token.access_token
  udc_name     = local.udc_name
  gdp_mu_host  = var.gdp_mu_host
}

# Output the generated CSV content for debugging
output "profile_csv" {
  value       = local.udc_csv
  description = "The generated Universal Connector profile CSV content"
}

# Output the access token for testing
output "access_token" {
  value       = data.guardium-data-protection_authentication.access_token.access_token
  description = "OAuth access token for Guardium API"
  sensitive   = true
}