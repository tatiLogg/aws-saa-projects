output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (Tier 1)"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "App subnet IDs (Tier 2 — Private)"
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Data subnet IDs (Tier 3 — Private)"
  value       = aws_subnet.data[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Elastic IP attached to the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "s3_endpoint_id" {
  description = "S3 Gateway Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "ssm_endpoint_ids" {
  description = "SSM Interface Endpoint IDs"
  value       = { for k, v in aws_vpc_endpoint.ssm : k => v.id }
}
