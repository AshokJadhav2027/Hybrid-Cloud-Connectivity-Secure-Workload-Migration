# ============================================
# OUTPUTS
# ============================================

output "server_public_ip" {
  description = "IP pubblico dell'istanza EC2"
  value       = aws_instance.tf_web_server.public_ip
}

output "ssh_command" {
  description = "Comando SSH per connettersi all'EC2"
  value       = "ssh -i terraform-key.pem ubuntu@${aws_instance.tf_web_server.public_ip}"
}

output "wireguard_endpoint" {
  description = "Endpoint WireGuard per configurare i peer"
  value       = "${aws_instance.tf_web_server.public_ip}:51820"
}

output "ubuntu_ami_id" {
  description = "ID dell'AMI Ubuntu utilizzata"
  value       = data.aws_ami.ubuntu.id
}
