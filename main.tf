data "aws_route53_zone" "pub" {
  name         = var.dns_zone
  private_zone = false
}

####  AWS Components

module "aws_transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  cloud                         = "AWS"
  version                       = "2.2.0"
  account                       = var.aws_account_name
  region                        = var.aws_region
  cidr                          = "10.0.0.0/23"
  name                          = "awstransit"
  instance_size                 = "c5n.9xlarge"
  insane_mode                   = true
  local_as_number               = var.avx_asn
  bgp_ecmp                      = true
  enable_s2c_rx_balancing       = true
}

module "spoke1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud   = "AWS"
  version = "1.3.0"

  name          = "fra-spoke1"
  cidr          = "10.0.2.0/24"
  region        = var.aws_region
  account       = var.aws_account_name
  transit_gw    = module.aws_transit.transit_gateway.gw_name
  instance_size = "c5n.9xlarge"
  insane_mode   = true
}

module "gcp_transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  cloud                         = "GCP"
  version                       = "2.2.0"
  account                       = var.gcp_account_name
  region                        = var.gcp_region
  cidr                          = "10.50.0.0/23"
  name                          = "gcptransit"
  instance_size                 = "n1-highcpu-32"
  insane_mode                   = true
}

module "transit-peering" {
  source  = "terraform-aviatrix-modules/mc-transit-peering/aviatrix"
  version = "1.0.6"

  enable_insane_mode_encryption_over_internet = true
  tunnel_count                                = 16
  transit_gateways = [
    module.aws_transit.transit_gateway.gw_name,
    module.gcp_transit.transit_gateway.gw_name,
    module.azure_transit.transit_gateway.gw_name
  ]
}


module "gcp_spoke1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud   = "GCP"
  version = "1.3.0"

  name          = "gcp-spoke1"
  cidr          = "10.50.2.0/24"
  region        = var.gcp_region
  account       = var.gcp_account_name
  transit_gw    = module.gcp_transit.transit_gateway.gw_name
  instance_size = "n1-highcpu-32"
  insane_mode   = true
}

module "gcp1" {
  source = "git::https://github.com/fkhademi/terraform-gcp-instance-module.git"

  name          = "gcp-srv1"
  region        = var.gcp_region
  zone          = "a"
  vpc           = module.gcp_spoke1.vpc.name
  subnet        = module.gcp_spoke1.vpc.subnets[0].name
  ssh_key       = var.ssh_key
  public_ip     = true
  instance_size = "n1-highcpu-8"
  cloud_init_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int3",
      peer1 = "int1",
      peer2 = "int5"
  })
}

# GCP Instances


resource "aws_route53_record" "gcp1" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "gcp1.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp1.vm.network_interface[0].access_config[0].nat_ip]
} 

resource "aws_route53_record" "int3" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int3.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp1.vm.network_interface[0].network_ip]
}

module "gcp2" {
  source = "git::https://github.com/fkhademi/terraform-gcp-instance-module.git"

  name          = "gcp-srv2"
  region        = var.gcp_region
  zone          = "b"
  vpc           = module.gcp_spoke1.vpc.name
  subnet        = module.gcp_spoke1.vpc.subnets[0].name
  ssh_key       = var.ssh_key
  public_ip     = true
  instance_size = "n1-highcpu-8"
  cloud_init_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int4",
      peer1 = "int2",
      peer2 = "int6"
  })
}

resource "aws_route53_record" "gcp2" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "gcp2.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp2.vm.network_interface[0].access_config[0].nat_ip]
} 

resource "aws_route53_record" "int4" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int4.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp2.vm.network_interface[0].network_ip]
}  


# AZURE

module "azure_transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  cloud                         = "Azure"
  version                       = "2.2.0"
  account                       = var.azure_account_name
  region                        = var.azure_region
  cidr                          = "10.100.0.0/23"
  name                          = "azuretransit"
  instance_size                 = "Standard_D5_v2"
  insane_mode                   = true
}

module "azure_spoke1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud   = "Azure"
  version = "1.3.0"

  name          = "azure-spoke1"
  cidr          = "10.100.2.0/24"
  region        = var.azure_region
  account       = var.azure_account_name
  transit_gw    = module.azure_transit.transit_gateway.gw_name
  instance_size = "Standard_D5_v2"
  insane_mode   = true
}

# Azure Instances

module "azure1" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-build-module.git?ref=for-ntttcp"

  name    = "azure-srv1"
  region  = var.azure_region
  rg      = module.azure_spoke1.vpc.resource_group
  vnet    = module.azure_spoke1.vpc.name
  subnet  = module.azure_spoke1.vpc.public_subnets[0].subnet_id
  ssh_key = var.ssh_key
  cloud_init_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int5",
      peer1 = "int1",
      peer2 = "int3"
  })
  public_ip = true
  instance_size = "Standard_D5_v2"
}

resource "aws_route53_record" "azure1" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "azure1.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure1.public_ip.ip_address]
}

resource "aws_route53_record" "int5" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int5.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure1.nic.private_ip_address]
}


module "azure2" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-build-module.git?ref=for-ntttcp"

  name    = "azure-srv2"
  region  = var.azure_region
  rg      = module.azure_spoke1.vpc.resource_group
  vnet    = module.azure_spoke1.vpc.name
  subnet  = module.azure_spoke1.vpc.public_subnets[1].subnet_id
  ssh_key = var.ssh_key
  cloud_init_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int6",
      peer1 = "int2",
      peer2 = "int4"
  })
  public_ip = true
  instance_size = "Standard_D5_v2"
}

resource "aws_route53_record" "azure2" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "azure2.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure2.public_ip.ip_address]
}

resource "aws_route53_record" "int6" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int6.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure2.nic.private_ip_address]
}
