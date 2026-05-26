# Project 1 — Three-Tier VPC on AWS

**Series:** AWS Solutions Architect Associate (SAA-C03) Hands-On Projects  
**Author:** Selina Loggins · [LinkedIn](https://www.linkedin.com/in/sloggins) · [Medium](https://medium.com/@sloggins)  
**Tools:** Terraform · AWS · GitHub Actions (coming)

---

## What This Project Builds

A production-pattern three-tier VPC on AWS, built entirely with Terraform. The architecture separates public-facing, application, and data resources into isolated network layers — the foundation pattern used in real enterprise cloud deployments.

```
Internet
    │
    ▼
┌─────────────────────────────────────┐
│         Public Subnets (x2 AZs)     │  ← Load balancers, NAT Gateway
│         10.0.1.0/24 │ 10.0.2.0/24  │
└──────────────┬──────────────────────┘
               │ NAT Gateway (outbound only)
               ▼
┌─────────────────────────────────────┐
│         App Subnets (x2 AZs)        │  ← EC2, EKS nodes, Lambda
│        10.0.10.0/24 │ 10.0.11.0/24 │    No public IPs
└──────────────┬──────────────────────┘
               │ Private routing only
               ▼
┌─────────────────────────────────────┐
│         Data Subnets (x2 AZs)       │  ← RDS, ElastiCache
│        10.0.20.0/24 │ 10.0.21.0/24 │    No internet access
└─────────────────────────────────────┘

VPC Endpoints (private AWS service access)
├── S3 Gateway Endpoint     → Free, no internet needed for S3
├── SSM Interface Endpoint  → Session Manager access to private EC2
├── EC2Messages Endpoint    → Required for SSM
└── SSMMessages Endpoint    → Required for SSM
```

---

## AWS Services Used

| Service | Purpose |
|---|---|
| VPC | Isolated network with custom CIDR (10.0.0.0/16) |
| Subnets | 6 subnets across 2 AZs — public, app, data tiers |
| Internet Gateway | Inbound/outbound internet for public subnets |
| NAT Gateway | Outbound-only internet for private subnets |
| Elastic IP | Static IP assigned to NAT Gateway |
| Route Tables | Separate tables for public and private tiers |
| Security Groups | Firewall for SSM interface endpoints |
| VPC Endpoints | Private access to S3 and SSM — no internet path |

---

## Terraform Structure

```
project-1-vpc/
├── main.tf        # All AWS resources
├── variables.tf   # Input variables with defaults
└── outputs.tf     # VPC ID, subnet IDs, endpoint IDs
```

---

## Security Decisions — The Why

**No public IPs on any compute subnet**  
`map_public_ip_on_launch = false` on all subnets. Even the public subnets don't auto-assign public IPs. Public IPs are assigned intentionally only where required — not by default.

**NAT Gateway for controlled outbound**  
Private instances can reach the internet for OS patches and package installs, but no inbound connections are possible. The NAT Gateway is one-directional by design.

**S3 Gateway Endpoint — free and private**  
S3 traffic from private instances stays inside the AWS network entirely. No internet path, no data transfer charges, no NAT Gateway cost for S3 calls. This is always worth enabling.

**Three SSM Interface Endpoints — zero SSH**  
All three endpoints (`ssm`, `ec2messages`, `ssmmessages`) are required for Session Manager to work. This eliminates port 22, SSH keys, and bastion hosts from the architecture entirely. Access is IAM-controlled, logged, and auditable.

**IMDSv2 enforced (foundation for Project 2)**  
Instance Metadata Service v2 requires a session token, preventing Server-Side Request Forgery (SSRF) attacks from reading instance credentials via the metadata endpoint.

---

## Prerequisites

- AWS CLI installed and configured  
- Terraform >= 1.0 installed  
- AWS named profile `personal` configured (`~/.aws/credentials`)  
- Sufficient IAM permissions (VPC, EC2, IAM)

---

## Deployment Steps

```bash
# 1. Clone the repo
git clone https://github.com/tatilogg/aws-saa-projects.git
cd aws-saa-projects/project-1-vpc

# 2. Initialise Terraform (downloads AWS provider)
terraform init

# 3. Review what will be created — read this carefully
terraform plan

# 4. Deploy
terraform apply
# Type 'yes' when prompted
```

---

## Validation Steps

After `terraform apply` completes, verify in the AWS Console:

1. **VPC** → confirm `selina-vpc` exists with CIDR `10.0.0.0/16`
2. **Subnets** → confirm 6 subnets across `us-east-1a` and `us-east-1b`
3. **Route Tables** → public RT has route to IGW · private RT has route to NAT
4. **NAT Gateway** → status `Available`, sitting in a public subnet
5. **VPC Endpoints** → 4 endpoints listed (S3 + 3 SSM), all `Available`
6. **Security Groups** → `selina-sg-endpoints` allows port 443 inbound from `10.0.0.0/16`

---

## ⚠️ NAT Gateway Cost Warning

NAT Gateway is **not free**. It costs approximately:

- **$0.045/hour** just to exist (~$32/month)
- **$0.045/GB** for data processed

**If you are just learning and not using this VPC actively — run `terraform destroy` when done.** Leaving a NAT Gateway running overnight costs real money. This is one of the most common unexpected AWS bills for learners.

---

## Lessons Learned

- Terraform `for_each` on a `toset()` is cleaner than `count` for creating multiple similar resources (used for the 3 SSM endpoints)
- Interface VPC endpoints need **all three** SSM services — missing even one breaks Session Manager silently
- `profile = "personal"` in the provider block is the right way to use named AWS profiles in Terraform — never use access keys directly in code
- Gateway endpoints (S3) use route table entries. Interface endpoints (SSM) use ENIs and security groups. They are fundamentally different under the hood.

---

## Cleanup

```bash
terraform destroy
# Type 'yes' when prompted
```

This removes all resources in reverse dependency order. NAT Gateway, Elastic IP, endpoints, subnets, route tables, and VPC are all deleted cleanly.

---

## Next in the Series

**[Project 2 →](../project-2-ec2/)** Private EC2 instance deployed into the app subnet with SSM-only access. No SSH. No public IP. No bastion host.

---

*Part of the AWS SAA-C03 hands-on project series by Selina Loggins.*  
*Building in public — one project at a time.*
