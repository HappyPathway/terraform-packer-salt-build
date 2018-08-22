data "vault_generic_secret" "azure" {
    path = "${var.vault_azure_credentials_path}"
}

data "terraform_remote_state" "network" {
  backend = "atlas"

  config {
    name = "${var.organization}/${var.network_ws}"
  }
}

locals {
    packer_location = "${join("_", data.terraform_remote_state.network.location)}"
}

data "template_file" "packer_config" {
  vars = {
      ARM_CLIENT_ID = "${data.vault_generic_secret.azure.data["client_id"]}"
      ARM_CLIENT_SECRET = "${data.vault_generic_secret.azure.data["client_secret"]}"
      ARM_SUBSCRIPTION_ID = "${data.vault_generic_secret.azure.data["subscription_id"]}"
      ARM_TENANT_ID = "${data.vault_generic_secret.azure.data["tenant_id"]}"
      SERVICE_NAME = "${var.service_name}"
      SERVICE_VERSION = "${var.service_version}"
      LOCATION = "${local.packer_location}"
      LOCAL_SALT_TREE = "${path.module}/salt"
  }
  template = "${file("${path.module}/templates/packer.json.tpl")}"
}

resource "null_resource" "packer_build" {
  triggers = {
      template_file   =  "${data.template_file.packer_config.rendered}"
  }

  provisioner "local-exec" {
      command = "curl -o ${path.root}/packer.zip https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip"
  }
  provisioner "local-exec" {
      command = "unzip -d ${path.root} ${path.root}/packer.zip"
  }
  provisioner "local-exec" {
    command =  "echo '${data.template_file.packer_config.rendered}' > ${path.root}/${var.service_name}-packer.json",
  }

  provisioner "local-exec" {
      command = "${path.root}/packer build -force ${path.root}/${var.service_name}-packer.json"
  }

  provisioner "local-exec" {
      command = "rm ${path.root}/${var.service_name}-packer.json"
  }

  provisioner "local-exec" {
      command = "rm ${path.root}/packer; rm ${path.root}/packer.zip"
  }
}



data "azurerm_image" "image" {
  name                = "${var.service_name}-${var.service_version}"
  resource_group_name = "PackerConfigs"
  depends_on = [
      "null_resource.packer_build"
  ]
}
