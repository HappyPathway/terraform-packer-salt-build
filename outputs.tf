output "image_id" {
    value = "${data.azurerm_image.image.id}"
}

output "location" {
    value = "${data.terraform_remote_state.network.location}"
}
