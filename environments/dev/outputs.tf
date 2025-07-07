output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.network.vpc_id
}

output "backend_instance_public_dns" {
  description = "The public DNS of the backend instance"
  value       = module.backend.backend_instance_public_dns
}
