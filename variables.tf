# variables.tf

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "name" {
  description = "The name of the virtual machine"
  type        = string
}


variable "vnet_subnet_name" {
  description = "The name of the subnet"
  type        = string
}

variable "vnet_name" {
  description = "The name of the virtual network"
  type        = string
}