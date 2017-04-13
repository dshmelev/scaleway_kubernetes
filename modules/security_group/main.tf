variable "cluster_ports" {
  default = [22,80,443]
}
variable "internal_ports" {
  default = [2379,2380,6443,10250,10251,10252,10255]
}

resource "scaleway_security_group" "cluster" {
  name        = "cluster"
  description = "kubernetes"
}

resource "scaleway_security_group_rule" "external_access" {
  security_group = "${scaleway_security_group.cluster.id}"
  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol = "TCP"
  port     = "${element(var.cluster_ports, count.index)}"
  count    = "${length(var.cluster_ports)}"
}

resource "scaleway_security_group_rule" "internal_access" {
  security_group = "${scaleway_security_group.cluster.id}"
  action    = "accept"
  direction = "inbound"
  ip_range  = "10.0.0.0/8"
  protocol = "TCP"
  port     = "${element(var.internal_ports, count.index)}"
  count    = "${length(var.internal_ports)}"
}

resource "scaleway_security_group_rule" "drop_all_tcp" {
  security_group = "${scaleway_security_group.cluster.id}"
  action    = "drop"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol = "TCP"
}

output "id" {
  value = "${scaleway_security_group.cluster.id}"
}
