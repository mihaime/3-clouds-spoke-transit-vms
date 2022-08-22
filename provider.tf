provider "aviatrix" {
  controller_ip = var.controller_ip
  username      = var.username
  password      = var.password
  #version 	= "2.21.2"
  skip_version_validation = true
}

provider "aws" {
  region = "eu-central-1"
}

provider "google" {
  credentials = "gcp.json"
  project     = "freyviatrix-2020"
  region      = var.gcp_region
}

provider "azurerm" {
  features {}
}