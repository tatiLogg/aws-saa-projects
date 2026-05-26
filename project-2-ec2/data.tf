# ─────────────────────────────────────────────
# DATA SOURCES — Reference Project 1 VPC
# We look up existing infrastructure by tag
# rather than hard-coding IDs so this works
# regardless of which account it was deployed to.
# ─────────────────────────────────────────────

# Look up the VPC created in Project 1
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_project_name}-vpc"]
  }
}

# Look up the app (private) subnets from Project 1
# We deploy EC2 into app subnet [0] (us-east-1a)
data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.vpc_project_name}-app-*"]
  }
}

# Look up the SSM endpoint security group from Project 1
# EC2 must be in a SG that can reach these endpoints
data "aws_security_group" "endpoints" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_project_name}-sg-endpoints"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

# Always use the latest Amazon Linux 2023 AMI
# Pinning to Amazon-owned AMIs prevents supply chain attacks
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
