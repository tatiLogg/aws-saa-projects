# ─────────────────────────────────────────────
# OUTPUTS
# ─────────────────────────────────────────────

output "instance_id" {
  description = "EC2 instance ID — use this to start an SSM session"
  value       = aws_instance.app.id
}

output "instance_name" {
  description = "Name tag of the EC2 instance"
  value       = aws_instance.app.tags["Name"]
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance (not reachable from internet)"
  value       = aws_instance.app.private_ip
}

output "ami_used" {
  description = "Amazon Linux 2023 AMI ID that was used"
  value       = data.aws_ami.amazon_linux_2023.id
}

output "ssm_connect_command" {
  description = "Copy-paste this command to open an SSM session"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region} --profile personal"
}
