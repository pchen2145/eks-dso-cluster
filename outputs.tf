output "private_key" {
  description   = "EC2 keypair private access key"
  value         = tls_private_key.keypair.private_key_pem
}
