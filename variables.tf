variable "controller_ip" {
  type        = string
  description = "Aviatrix Controller IP or FQDN"
}

variable "username" {
  type        = string
  description = "Aviatrix Controller Username"
}

variable "password" {
  type        = string
  description = "Aviatrix Controller Password"
}

variable "dns_zone" {
  type        = string
  description = "Route53 Domain Name to update"
}

variable "aws_account_name" {
  type        = string
  description = "AWS Account Name"
}

variable "azure_account_name" {
  type        = string
  description = "Azure Account Name"
}

variable "gcp_account_name" {
  type        = string
  description = "GCP Account Name"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "azure_region" {
  type        = string
  description = "Azure Region"
}

variable "gcp_region" {
  type        = string
  description = "GCP Region"
}

variable "ssh_key" {
}

variable "avx_asn" {
  default = 65002
}

variable "tgw_asn" {
  default = 64512
}

variable "tgw_cidr" {
  default = "10.119.0.0/16"
}

variable "tunnel_cidr1" {
  default = "169.254.100.0/29"
}

variable "tunnel_cidr2" {
  default = "169.254.200.0/29"
}

variable "tunnel_cidr3" {
  default = "169.254.210.0/29"
}

variable "tunnel_cidr4" {
  default = "169.254.220.0/29"
}
