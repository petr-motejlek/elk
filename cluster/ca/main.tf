resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

variable "ca_common_name" {}
variable "ca_valid_hours" {
  type = number
}
locals {
  ca_common_name = var.ca_common_name
  ca_valid_hours = var.ca_valid_hours
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = tls_private_key.ca.algorithm
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name = local.ca_common_name
  }

  validity_period_hours = local.ca_valid_hours

  is_ca_certificate = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing"
  ]
}

resource "null_resource" "ca" {
  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-xeuo", "pipefail", "-c"]
    command     = <<-EOT
      sudo openssl x509 \
        -out /usr/local/share/ca-certificates/ca.crt \
      <<EOF
${tls_self_signed_cert.ca.cert_pem}
EOF
      sudo update-ca-certificates
      sudo systemctl restart docker
    EOT
  }
}

variable "subjects_common_names" {
  type = set(string)
}
locals {
  subjects_common_names = var.subjects_common_names
}

resource "tls_private_key" "subjects" {
  for_each = local.subjects_common_names

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "subjects" {
  for_each = local.subjects_common_names

  key_algorithm   = tls_private_key.subjects[each.key].algorithm
  private_key_pem = tls_private_key.subjects[each.key].private_key_pem

  subject {
    common_name = each.value
  }

  dns_names = [each.value]
}

variable "subjects_valid_hours" {
  type = number
}
locals {
  subjects_valid_hours = var.subjects_valid_hours
}

resource "tls_locally_signed_cert" "subjects" {
  for_each = local.subjects_common_names

  cert_request_pem   = tls_cert_request.subjects[each.key].cert_request_pem
  ca_key_algorithm   = tls_private_key.ca.algorithm
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = local.subjects_valid_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

output "subjects_tls_key_pems" {
  sensitive = true
  value     = { for idx, cn in local.subjects_common_names : cn => tls_private_key.subjects[idx].private_key_pem }
}

output "subjects_tls_crt_pems" {
  value = { for idx, cn in local.subjects_common_names : cn => tls_locally_signed_cert.subjects[idx].cert_pem }
}

output "public_key_pem" {
  value = tls_self_signed_cert.ca.cert_pem
}