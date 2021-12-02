#
# Build a custom template based on Exoscale featured template
#
#

# Use Exoscale custom packer plugin
packer {
  required_plugins {
    exoscale = {
      version = ">= 0.1.1"
      source = "github.com/exoscale/exoscale"
    }
  }
}

# Define some vars
# https://www.packer.io/docs/templates/hcl_templates/variables
# 
# To use ENV vars, such as api_key and api_secret, you need to
# export PKR_VAR_api_key=EXO...
# export PKR_VAR_api_secret=....

variable "api_key" {
  type = string
  description = "Exoscale API Key, like EXO..."
  default = ""
}

variable "api_secret" {
  type = string
  description = "EXO API Secret"
  default = ""
}

variable "exoscale_zone" {
  type = string
  description = "Default zone"
  default = "ch-gva-2"
}

variable "instance_disk_size" {
  type = number
  description = "Disk size, not bigger than 10"
  default = 10
}

variable "image_name" {
  type = string
  description = "Template name"
  default = "webapp-packer-{{isotime `2006-01-02`}}"
}

variable "image_username" {
  type = string
  description = "Default username in image"
  default = "debian"
}


# Configuration for builder plugin 'Exoscale'
source "exoscale" "webapp" {
  api_key = var.api_key
  api_secret = var.api_secret
  instance_disk_size = var.instance_disk_size
  instance_template = "Linux Debian 11 (Bullseye) 64-bit"
  instance_type = "micro"
  instance_security_groups = ["default"]
  template_description = "Demo Webapp"
  template_name = var.image_name
  template_username = var.image_username
  ssh_username = var.image_username
  template_zone = var.exoscale_zone
}

# configuration for a specific combination of builders, provisioners,
# and post-processors used to create a specific image artifact.
build {
  sources = ["source.exoscale.webapp"]

  # execute shell commands before creating the template
  provisioner "shell" {
    execute_command = "chmod +x {{.Path}}; sudo {{.Path}}"
    scripts = ["deploy.sh"]
  }
}
