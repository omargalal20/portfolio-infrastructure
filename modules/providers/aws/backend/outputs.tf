output "backend_instance_public_dns" {
  value = aws_instance.backend_instance.public_dns
}

output "backend_instance_public_ip" {
  value = aws_instance.backend_instance.public_ip
}

output "backend_instance_id" {
  value = aws_instance.backend_instance.id
}
