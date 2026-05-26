variable "aws_region" {
  description = "AWS region — must match the region Project 1 was deployed into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_project_name" {
  description = "The project_name used in Project 1 — used to look up VPC resources by tag"
  type        = string
  default     = "selina"
}

variable "project_name" {
  description = "Prefix applied to all Project 2 resource names"
  type        = string
  default     = "selina-p2"
}

variable "instance_type" {
  description = "EC2 instance type — t3.micro is free-tier eligible on newer accounts"
  type        = string
  default     = "t3.micro"
}
