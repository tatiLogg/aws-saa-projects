# Project 2 — Private EC2 Access via SSM Session Manager

**Series:** AWS Solutions Architect Associate (SAA-C03) Hands-On Projects  
**Author:** Selina Loggins · [LinkedIn](https://www.linkedin.com/in/sloggins) · [Medium](https://medium.com/@sloggins)  
**Tools:** Terraform · AWS Systems Manager · GitHub Actions (coming)  
**Depends on:** [Project 1 — Three-Tier VPC](../project-1-vpc/)

---

## What This Project Builds

A private EC2 instance deployed into the app subnet of the Project 1 VPC, accessible exclusively via AWS Systems Manager (SSM) Session Manager. Zero open ports. No SSH keys. No bastion host. No public IP.

This is the access pattern used in production environments where direct SSH access is a security risk.

```
Your Terminal
    │
    │  aws ssm start-session --target i-xxxxxxxxxx
    ▼
┌──────────────────────────────────────────┐
│           AWS Systems Manager             │
│         (control plane, public)           │
└──────────────────┬───────────────────────┘
                   │ HTTPS (port 443)
                   ▼
┌──────────────────────────────────────────┐
│      SSM VPC Interface Endpoints          │  ← From Project 1
│  ssm · ec2messages · ssmmessages          │
└──────────────────┬───────────────────────┘
                   │ Private — stays inside VPC
                   ▼
┌──────────────────────────────────────────┐
│         App Subnet (Private)              │
│    ┌─────────────────────────────┐        │
│    │   EC2 Instance              │        │
│    │   No public IP              │        │
│    │   No SSH key pair           │        │
│    │   IAM instance profile      │        │
│    │   IMDSv2 enforced           │        │
│    └─────────────────────────────┘        │
└──────────────────────────────────────────┘
```

---

## AWS Services Used

| Service | Purpose |
|---|---|
| EC2 | Private app server — Amazon Linux 2023, t3.micro |
| IAM Role | Identity for the EC2 instance |
| IAM Instance Profile | Attaches the IAM role to the EC2 instance |
| AmazonSSMManagedInstanceCore | AWS managed policy — minimum SSM permissions |
| Security Group | Zero inbound rules · HTTPS outbound to VPC only |
| SSM Session Manager | Browser or CLI shell access — no port 22 needed |
| VPC Endpoints (from Project 1) | SSM traffic stays private — never leaves AWS network |

---

## Terraform Structure

```
project-2-ec2/
├── data.tf        # Looks up Project 1 VPC, subnets, SSM SG, and latest AMI
├── main.tf        # IAM role, instance profile, security group, EC2 instance
├── variables.tf   # Input variables with defaults
└── outputs.tf     # Instance ID, private IP, SSM connect command
```

---

## Security Decisions — The Why

**No SSH key pair**  
There is no key pair on this instance. Even if someone gained network access to the subnet, there is no key to brute-force or steal. This removes an entire class of credential-based attacks.

**Zero inbound security group rules**  
The EC2 security group has no inbound rules at all — not even SSH. The only traffic allowed is outbound HTTPS (port 443) to the VPC CIDR so the SSM agent can reach the interface endpoints from Project 1.

**IAM controls access — not the network**  
Who can connect to this instance is controlled entirely by IAM permissions on `ssm:StartSession`. This means access is centrally managed, auditable in CloudTrail, and revocable instantly by changing a policy — no key rotation needed.

**IMDSv2 enforced**  
`http_tokens = "required"` means the instance metadata service requires a session token. This prevents SSRF attacks from reading instance credentials via the metadata endpoint (`169.254.169.254`).

**Encrypted root volume**  
`encrypted = true` on the gp3 root volume. Data at rest is encrypted via AWS KMS at no additional key management cost.

**Least privilege IAM**  
The instance role has exactly one policy attached: `AmazonSSMManagedInstanceCore`. This gives SSM what it needs and nothing more. No S3, no EC2 describe, no CloudWatch — nothing that isn't required.

---

## Prerequisites

- Project 1 VPC must be deployed and running in the same region
- AWS CLI installed with the `personal` profile configured
- Terraform >= 1.0 installed
- SSM Plugin installed for `aws ssm start-session` command:
  ```bash
  # Mac
  brew install --cask session-manager-plugin
  ```

---

## Deployment Steps

```bash
# 1. Navigate to the project folder
cd aws-saa-projects/project-2-ec2

# 2. Initialise Terraform
terraform init

# 3. Review — confirm it finds the Project 1 VPC correctly
terraform plan

# 4. Deploy
terraform apply
# Type 'yes' when prompted
```

After apply, Terraform prints the outputs including your ready-to-use SSM connect command.

---

## Validation — Connecting via SSM

**Option 1 — AWS CLI (recommended)**
```bash
# Terraform outputs this command for you — just copy-paste it
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx --region us-east-1 --profile personal
```

You'll get a shell prompt directly on the instance:
```
Starting session with SessionId: selina-xxxxxxxx
sh-5.2$
```

**Option 2 — AWS Console**
1. EC2 → Instances → select `selina-p2-app-server`
2. Click **Connect** → **Session Manager** tab → **Connect**

**Verification commands to run inside the session:**
```bash
# Confirm you are on the instance
hostname
whoami   # should return ssm-user

# Confirm no public IP
curl -s http://checkip.amazonaws.com   # should time out or fail

# Confirm private IP matches Terraform output
ip addr show

# Confirm S3 endpoint works (from Project 1)
aws s3 ls --region us-east-1   # should return without error
```

---

## What Good Output Looks Like

```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

ami_used             = "ami-0xxxxxxxxxxxxxxxxx"
instance_id          = "i-0xxxxxxxxxxxxxxxxx"
instance_name        = "selina-p2-app-server"
instance_private_ip  = "10.0.10.x"
ssm_connect_command  = "aws ssm start-session --target i-0xxx... --region us-east-1 --profile personal"
```

---

## Lessons Learned

- SSM requires all three interface endpoints (`ssm`, `ec2messages`, `ssmmessages`) — missing one causes silent connection failures
- The IAM instance profile is separate from the IAM role — the profile is the container that attaches the role to the instance
- `associate_public_ip_address = false` is the explicit declaration; leaving it out on a private subnet works but being explicit is better practice
- Terraform data sources are the right way to reference shared infrastructure — hard-coding VPC IDs breaks portability and creates hidden dependencies

---

## Cleanup

```bash
# Destroy Project 2 first
cd project-2-ec2
terraform destroy

# Then destroy Project 1 if no longer needed
cd ../project-1-vpc
terraform destroy
```

Always destroy Project 2 before Project 1 — the EC2 instance depends on the VPC.

---

## Previous in the Series

**[← Project 1](../project-1-vpc/)** Three-tier VPC with NAT Gateway, route tables, and SSM interface endpoints.

---

*Part of the AWS SAA-C03 hands-on project series by Selina Loggins.*  
*Building in public — one project at a time.*
