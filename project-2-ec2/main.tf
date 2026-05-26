terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "personal"
}

# ─────────────────────────────────────────────
# IAM ROLE — EC2 SSM Access
#
# This role allows the EC2 instance to identify
# itself to AWS Systems Manager. No username,
# no password, no SSH key — the instance assumes
# this role automatically at boot.
# ─────────────────────────────────────────────
resource "aws_iam_role" "ec2_ssm" {
  name        = "${var.project_name}-ec2-ssm-role"
  description = "Allows EC2 to register with SSM Session Manager"

  # Trust policy — only EC2 can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${var.project_name}-ec2-ssm-role" }
}

# ─────────────────────────────────────────────
# IAM POLICY ATTACHMENT
#
# AmazonSSMManagedInstanceCore is the minimum
# AWS-managed policy needed for SSM Session Manager.
# We attach ONLY this — nothing more (least privilege).
# ─────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ─────────────────────────────────────────────
# IAM INSTANCE PROFILE
#
# Instance profiles are the bridge between
# an IAM role and an EC2 instance. You attach
# the profile to the instance — not the role directly.
# ─────────────────────────────────────────────
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name

  tags = { Name = "${var.project_name}-ec2-ssm-profile" }
}

# ─────────────────────────────────────────────
# SECURITY GROUP — EC2 Instance
#
# Zero inbound rules — no SSH (port 22), no HTTP,
# no direct access of any kind. The instance is
# completely unreachable from the network directly.
#
# SSM Session Manager communicates OUTBOUND over
# HTTPS (port 443) to the VPC interface endpoints
# we created in Project 1. No inbound port needed.
# ─────────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg-ec2"
  description = "EC2 instance SG — no inbound, HTTPS outbound to SSM endpoints only"
  vpc_id      = data.aws_vpc.main.id

  # OUTBOUND — HTTPS to VPC CIDR only
  # Reaches SSM interface endpoints at 443 — nothing else leaves
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "HTTPS to SSM VPC interface endpoints"
  }

  tags = { Name = "${var.project_name}-sg-ec2" }
}

# ─────────────────────────────────────────────
# EC2 INSTANCE
#
# Deployed into the app (private) subnet from
# Project 1. No public IP. No key pair.
# Access is exclusively via SSM Session Manager.
# ─────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.app.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  # No public IP — instance lives entirely in private subnet
  associate_public_ip_address = false

  # Attach both SGs:
  # - ec2 SG: controls what this instance can reach
  # - endpoints SG: allows this instance to talk to SSM endpoints
  vpc_security_group_ids = [
    aws_security_group.ec2.id,
    data.aws_security_group.endpoints.id
  ]

  # Root volume — encrypted at rest
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  # IMDSv2 only — prevents SSRF attacks from accessing instance metadata
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 — token required
    http_put_response_hop_limit = 1
  }

  tags = { Name = "${var.project_name}-app-server" }
}
