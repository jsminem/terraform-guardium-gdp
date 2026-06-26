locals {
  udc_name        = var.udc_name
  udc_csv         = var.udc_csv_parsed
  use_sftp        = var.gdp_ssh_username != "" && var.gdp_ssh_privatekeypath != ""
  # For GDP 12.2.1+: provider uploads via API from local file
  # For older GDP: SFTP uploads to remote path
  csv_path        = local.use_sftp ? format("%s/%s.csv", var.profile_api_directory, var.udc_name) : local_file.csv_temp.filename
}

resource "local_file" "csv_temp" {
  content  = local.udc_csv
  filename = "${path.module}/.terraform/${var.udc_name}.csv"
}

resource "terraform_data" "copy_csv" {
  count      = local.use_sftp ? 1 : 0
  depends_on = [local_file.csv_temp]
  
  input = {
    local_file_path           = local_file.csv_temp.filename
    remote_file_path          = format("%s/%s.csv", var.profile_upload_directory, var.udc_name)
    profile_upload_directory  = var.profile_upload_directory
    profile_api_directory     = var.profile_api_directory
    gdp_server                = var.gdp_server
    gdp_ssh_username          = var.gdp_ssh_username
    gdp_ssh_privatekeypath    = var.gdp_ssh_privatekeypath
  }

  provisioner "local-exec" {
    command = <<-EOT
      sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${self.input.gdp_ssh_privatekeypath} ${self.input.gdp_ssh_username}@${self.input.gdp_server} <<EOF
put ${self.input.local_file_path} ${self.input.remote_file_path}
bye
EOF
    EOT
  }
}

data "guardium-data-protection_authentication" "access_token" {
  client_secret = var.client_secret
  username = var.gdp_username
  password = var.gdp_password
  client_id = var.client_id
}

output "test" {
  value = data.guardium-data-protection_authentication.access_token.access_token
}

resource "guardium-data-protection_import_profiles" "import_profiles" {
  depends_on       = [local_file.csv_temp, terraform_data.copy_csv]
  access_token     = data.guardium-data-protection_authentication.access_token.access_token
  path_to_file     = local.csv_path
  update_mode      = true
  test_connections = var.test_connections
}

resource "guardium-data-protection_install_connector" "install_connector" {
  depends_on = [guardium-data-protection_import_profiles.import_profiles]
  access_token = data.guardium-data-protection_authentication.access_token.access_token
  udc_name     = local.udc_name
  gdp_mu_host  = var.gdp_mu_host
}

output "profile_csv" {
  value = local.udc_csv
}