resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = tls_private_key.ca.algorithm
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name = "ca"
  }

  validity_period_hours = 48

  is_ca_certificate = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing"
  ]
}

resource "local_file" "ca" {
  content  = tls_self_signed_cert.ca.cert_pem
  filename = abspath("${path.module}/ca.pem")
}

resource "null_resource" "ca" {
  provisioner "local-exec" {
    command = "sudo openssl x509 -in ${local_file.ca.filename} -out /usr/local/share/ca-certificates/ca.crt && sudo update-ca-certificates && sudo systemctl restart docker"
  }
}

output "private_key_pem" {
  value     = tls_private_key.ca.private_key_pem
  sensitive = true
}

output "private_key_algorithm" {
  value = tls_private_key.ca.algorithm
}

output "public_key_pem" {
  value = tls_self_signed_cert.ca.cert_pem
}

output "public_key_hash" {
  value = md5(local_file.ca.content)
}

output "public_key_path" {
  value = local_file.ca.filename
}
