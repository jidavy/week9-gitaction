variable "project_vpc" {
  description = "The ID of the VPC where resources will be created"
  type        = string
}

# We are commenting this out because main.tf now uses Data Sources
# variable "project_ami" {
#   type = string
# }

variable "project_instance_type" {
  description = "The EC2 instance type (e.g., t3.micro)"
  type        = string
}

variable "project_subnet" {
  description = "The Subnet ID for the instances"
  type        = string
}

variable "project_keyname" {
  description = "The name of the SSH key pair"
  type        = string
}
