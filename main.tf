variable "domain"          { default = "" }
variable "flannel_mtu"     {}
variable "flannel_subnet"  {}
variable "node_name"       {}
variable "organization"    {}
variable "region"          {}
variable "server_count"    { default = 0 }
variable "server_type"     { default = "VC1S" }
variable "token"           {}
variable "architectures" {
  default = {
    C1   = "arm"
    VC1S = "x86_64"
    VC1M = "x86_64"
    VC1L = "x86_64"
    C2S  = "x86_64"
    C2M  = "x86_64"
    C2L  = "x86_64"
  }
}

provider "scaleway" {
  organization = "${var.organization}"
  token        = "${var.token}"
  region       = "${var.region}"
}

data "scaleway_image" "ubuntu" {
  architecture = "${lookup(var.architectures, var.server_type)}"
  name = "Ubuntu Xenial"
}

module "security_group" {
  source = "./modules/security_group"
}

module "kubernetes" {
  source         = "./modules/kubernetes"
  dynamic_ip     = true
  domain         = "${var.domain}"
  flannel_mtu    = "${var.flannel_mtu}"
  flannel_subnet = "${var.flannel_subnet}"
  image          = "${data.scaleway_image.ubuntu.id}"
  node_name      = "${var.node_name}"
  security_group = "${module.security_group.id}"
  server_count   = "${var.server_count}"
  server_type    = "${var.server_type}"
}
