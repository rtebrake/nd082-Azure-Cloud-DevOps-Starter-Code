variable "prefix" {
        description = "The prefix used for the resources"
        default = "k45"
}

variable "location" {
        description = "The Azure region in which all resources will be deployed"
        default = "West Europe"
}

variable "vm_count" {
        description = "The number of virtual machines to be created"
        default = "2"
        validation {
                condition = contains(["2","3","4","5"], var.vm_count)
                error_message = "The value for vm_count needs to be 2,3,4 or 5."
        }
}

variable "custom_image_resource_group_name" {
        description = "The name of the Resource Group in which the Custom Image exists."
        default = "k45-image-rg"
}

variable "custom_image_name" {
  description = "The name of the Custom Image to provision this Virtual Machine from."
        default = "UbuntuImage"
}

variable "default_tags" {
  type = map(string)
  default = {
    Environment = "Production",
    Project = "UdacityProject1",
    Buildtool = "Terraform"
  }
}