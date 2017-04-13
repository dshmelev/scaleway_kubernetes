variable "dynamic_ip"         { default = false }
variable "image"              {}
variable "flannel_subnet"     { default = "" }
variable "flannel_mtu"        { default = "" }
variable "security_group"     { default = "cluster" }
variable "bastion_host"       { default = "" }
variable "server_count"       { default = "1" }
variable "server_type"        {}
variable "node_name"          { default = "" }
variable "domain"             {}
variable "config"             { default = "config" }
variable "services"           { default = ["etcd", "flanneld", "k8s-apiserver",
                                           "k8s-controller-manager", "k8s-kubelet",
                                           "k8s-proxy", "k8s-scheduler", "docker"]}

data "template_file" "environment" {
    template = "${file("${path.module}/templates/environment.tf.tmpl")}"
    count = "${var.server_count}"
    vars {
        etcd_cluster_name  = "etcd-cluster"
        flannel_subnet     = "${var.flannel_subnet}"
        flannel_mtu        = "${var.flannel_mtu}"
        domain             = "${var.domain}"
        server_count       = "${var.server_count}"
        node_name          = "${var.node_name}-${count.index + 1}"
    }
}

resource "scaleway_server" "server" {
  count = "${var.server_count}"
  dynamic_ip_required = "${var.dynamic_ip}"
  name  = "${var.node_name}-${count.index + 1}"
  image = "${var.image}"
  type  = "${var.server_type}"
  tags  = ["kubernetes"]
  security_group = "${var.security_group}"

  connection {
      type         = "ssh"
      user         = "root"
      agent        = true
  }

  # SSL GEN
  provisioner "local-exec" {
    command = "echo '{\"CN\":\"${self.name}\",\"hosts\":[\"10.10.10.1\",\"${self.private_ip}\"],\"key\":{\"algo\":\"rsa\",\"size\":2048}}' | cfssl gencert -ca=${var.config}/generated/ca.pem -ca-key=${var.config}/generated/ca-key.pem -config=${var.config}/ca/ca-config.json -profile=peer - | cfssljson -bare ${var.config}/generated/${self.name}"
  }

  # SSL
  provisioner "file" {
    source      = "${var.config}/generated/ca.pem"
    destination = "/etc/ssl/ca.pem"
  }
  provisioner "file" {
    source      = "${var.config}/generated/${self.name}.pem"
    destination = "/etc/ssl/server.pem"
  }
  provisioner "file" {
    source      = "${var.config}/generated/${self.name}-key.pem"
    destination = "/etc/ssl/server-key.pem"
  }

  provisioner "file" {
    content      = "${element(data.template_file.environment.*.rendered, count.index)}"
    destination  = "/etc/environment.tf"
  }

  # post install
  provisioner "file" {
    source = "${path.module}/scripts/install.sh"
    destination = "/tmp/install.sh"
  }
  provisioner "remote-exec" {
    inline = [ "chmod +x /tmp/install.sh; /tmp/install.sh" ]
  }
}

resource "null_resource" "cluster" {
  count = "${var.server_count}"
  triggers { cluster_instance_ids = "${join(",", scaleway_server.server.*.id)}" }
  connection { host = "${element(scaleway_server.server.*.public_ip, count.index)}" }

  provisioner "file" {
    source = "${path.module}/rootfs/"
    destination = "/"
  }

  # Kubernetes ServiceAccount
  provisioner "file" {
    source      = "${var.config}/generated/serviceaccount.key"
    destination = "/etc/kubernetes/serviceaccount.key"
  }


  provisioner "remote-exec" {
    inline = [
      "echo '${join("\n", formatlist("%v %v",scaleway_server.server.*.private_ip, scaleway_server.server.*.name))}' >> /etc/hosts",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo FLANNEL_ETCD_ENDPOINTS='${join(",", formatlist("https://%v:2379",scaleway_server.server.*.private_ip))}' >> /etc/environment.tf",
      "echo ETCD_INITIAL_CLUSTER='${join(",", formatlist("%v=https://%v:2380",scaleway_server.server.*.name,scaleway_server.server.*.private_ip))}' >> /etc/environment.tf",
      "echo K8S_APISERVER_ETCD_SERVERS='${join(",", formatlist("https://%v:2379",scaleway_server.server.*.private_ip))}' >> /etc/environment.tf",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl daemon-reload",
      "systemctl enable ${join(" ", var.services)}",
      "systemctl start ${join(" ", var.services)} --no-block"
    ]
  }

}

output "ip" {
  value = ["${scaleway_server.server.*.ip}"]
}
