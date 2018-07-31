resource "brightbox_server" "k8s_worker" {
  count      = "${var.worker_count}"
  depends_on = ["brightbox_firewall_policy.k8s"]

  name      = "k8s-worker-${count.index}"
  image     = "${data.brightbox_image.k8s_worker.id}"
  type      = "${var.worker_type}"
  user_data = "${data.template_file.worker-cloud-config.rendered}"

  server_groups = ["${brightbox_server_group.k8s.id}"]

  lifecycle {
    create_before_destroy = true
  }

  connection {
    bastion_host = "${brightbox_cloudip.k8s_master.fqdn}"
  }

  provisioner "file" {
    source      = "${path.root}/checksums.txt"
    destination = "checksums.txt"
  }

  # Just the public key, so it can be hashed on the server
  provisioner "file" {
    content     = "${tls_self_signed_cert.k8s_ca.cert_pem}"
    destination = "ca.crt"
  }

  provisioner "remote-exec" {
    inline = "${data.template_file.install-provisioner-script.rendered}"
  }

  provisioner "remote-exec" {
    inline = "${data.template_file.worker-provisioner-script.rendered}"
  }
}

data "brightbox_image" "k8s_worker" {
  name        = "${var.image_desc}"
  arch        = "x86_64"
  official    = true
  most_recent = true
}

data "template_file" "worker-cloud-config" {
  template = "${file("${local.template_path}/worker-cloud-config.yml")}"
}

data "template_file" "worker-provisioner-script" {
  template = "${file("${local.template_path}/install-worker")}"

  vars {
    boot_token = "${local.boot_token}"
    fqdn       = "${local.fqdn}"
  }
}
