# Palo Alto VM-Series on AWS — Infrastructure (Layer 1)

**Terraform-automated deployment of Palo Alto Networks VM-Series Next-Generation Firewall on AWS.**

Developed and maintained by [CloudBats LLC](https://github.com/cloudbatsx).

---

## Overview

This repository provisions the complete AWS infrastructure required to run a Palo Alto Networks VM-Series virtual firewall, including VPC networking, compute, bootstrap automation, and IAM. It represents **Layer 1** of a two-layer architecture:

| Layer | Repository | Provider | Scope |
|-------|-----------|----------|-------|
| **Layer 1 (this repo)** | `paloalto-vmseries-aws-terraform` | `hashicorp/aws` | AWS infrastructure — VPC, subnets, ENIs, EC2, S3 bootstrap, IAM |
| **Layer 2** | [`paloalto-panos-terraform`](https://github.com/cloudbatsx/paloalto-panos-terraform) | `paloaltonetworks/panos` | Firewall configuration — zones, security policies, NAT, routing |

Separating infrastructure from firewall configuration into independent Terraform root modules with isolated state files is a deliberate architectural decision. Infrastructure and policy have different lifecycles, change cadences, and approval workflows. This pattern scales cleanly to multi-region and multi-cloud deployments.

---

## Architecture

```
                         ┌──────────────────────────────────┐
                         │          AWS VPC (10.100.0.0/16) │
                         │                                  │
┌─────────┐    ┌─────────┴──────────┐                       │
│ Internet │◄──►│  Internet Gateway   │                       │
└─────────┘    └─────────┬──────────┘                       │
                         │                                  │
          ┌──────────────┼──────────────┐                   │
          │              │              │                   │
  ┌───────▼───────┐ ┌────▼────────┐ ┌───▼──────────┐       │
  │  Management   │ │   Untrust   │ │    Trust      │       │
  │ 10.100.1.0/24 │ │10.100.2.0/24│ │10.100.3.0/24 │       │
  │               │ │             │ │              │       │
  │  ENI (mgmt)   │ │ENI (eth1/1) │ │ENI (eth1/2)  │       │
  │  + EIP        │ │             │ │              │       │
  └───────┬───────┘ └──────┬──────┘ └──────┬───────┘       │
          │                │               │               │
          └────────────────┼───────────────┘               │
                    ┌──────▼──────┐                         │
                    │  VM-Series  │                         │
                    │  m5.xlarge  │                         │
                    │  PAN-OS     │                         │
                    │  12.1.x     │                         │
                    └─────────────┘                         │
                         │                                  │
                         └──────────────────────────────────┘
```

### Network Design

| Subnet | CIDR | Purpose | Routing |
|--------|------|---------|---------|
| **Management** | `10.100.1.0/24` | PAN-OS web UI, SSH, and API access | `0.0.0.0/0` via Internet Gateway |
| **Untrust** | `10.100.2.0/24` | Internet-facing data plane interface | `0.0.0.0/0` via Internet Gateway |
| **Trust** | `10.100.3.0/24` | Internal workloads behind the firewall | `0.0.0.0/0` via VM-Series trust ENI |

The VM-Series instance receives **three Elastic Network Interfaces (ENIs)**, one per subnet. Source/destination checks are disabled on the data-plane interfaces (untrust and trust) to allow the firewall to forward traffic. An Elastic IP is attached to the management ENI for remote access.

---

## Resources Provisioned

This configuration deploys **38 AWS resources**:

### Networking (11)
- VPC with DNS support and DNS hostnames enabled
- 3 subnets (management, untrust, trust) in a single Availability Zone
- Internet Gateway
- 2 route tables (public for mgmt/untrust, private for trust)
- 3 route table associations
- 1 route entry steering trust traffic through the firewall ENI

### Security Groups (5)
- **Management SG** — Inbound HTTPS (443) and SSH (22) restricted to `allowed_mgmt_cidrs`; all outbound
- **Data SG** — Permissive for lab use (restrict in production)

### Network Interfaces & Addressing (5)
- 3 ENIs (management, untrust, trust)
- 1 Elastic IP
- 1 EIP association

### Compute (4)
- VM-Series EC2 instance (m5.xlarge, PAN-OS 12.1.x PAYG AMI)
- TLS private key (RSA 4096-bit, generated in-state)
- EC2 key pair
- Local PEM file output

### S3 Bootstrap (6)
- S3 bucket with AES-256 server-side encryption
- Public access block (all deny)
- `init-cfg.txt` — hostname, DNS, DHCP client mode
- Placeholder directories for `content/`, `license/`, `software/`

### IAM (3)
- IAM role for VM-Series with S3 read access
- IAM policy granting `s3:ListBucket` and `s3:GetObject` on the bootstrap bucket
- Instance profile attached to the EC2 instance

---

## Bootstrap

The VM-Series firewall performs Day-0 bootstrap from an S3 bucket at first boot, eliminating manual GUI configuration:

```
s3://<project>-bootstrap-<id>/
  config/
    init-cfg.txt        # Hostname, DNS, DHCP, op-command-modes
  content/              # Content updates (empty)
  license/              # License files (empty for PAYG)
  software/             # Software updates (empty)
```

The instance references the bootstrap bucket via user-data (`vmseries-bootstrap-aws-s3bucket`), and the IAM instance profile grants read-only access.

---

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with valid credentials
- AWS Marketplace subscription to [VM-Series Next-Gen Virtual Firewall (PAYG)](https://aws.amazon.com/marketplace) — accept terms before applying
- Git + SSH key configured for GitHub

---

## Usage

### 1. Clone and configure

```bash
git clone git@github.com:cloudbatsx/paloalto-vmseries-aws-terraform.git
cd paloalto-vmseries-aws-terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set allowed_mgmt_cidrs to your IP
```

### 2. Deploy

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

Deployment takes approximately 5 minutes for AWS resources. PAN-OS requires an additional **10-15 minutes** to fully boot and initialize.

### 3. Set the admin password

PAN-OS 12.x PAYG images have no default web UI password. You must set it via SSH using the generated key pair:

```bash
ssh -i vmseries-key.pem admin@<management-eip>

# In PAN-OS CLI:
configure
set mgt-config users admin password
commit
exit
```

### 4. Access PAN-OS

Browse to `https://<management-eip>` and log in with `admin` and the password you set.

### 5. Deploy Layer 2

Use the Terraform outputs from this deployment as inputs for the [Layer 2 PAN-OS configuration](https://github.com/cloudbatsx/paloalto-panos-terraform).

### 6. Tear down

```bash
terraform destroy
```

---

## Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | `string` | `us-west-2` | AWS region |
| `project_name` | `string` | `cloudbats-pan` | Prefix for resource naming and tagging |
| `vpc_cidr` | `string` | `10.100.0.0/16` | VPC CIDR block |
| `mgmt_subnet_cidr` | `string` | `10.100.1.0/24` | Management subnet CIDR |
| `untrust_subnet_cidr` | `string` | `10.100.2.0/24` | Untrust (public) subnet CIDR |
| `trust_subnet_cidr` | `string` | `10.100.3.0/24` | Trust (private) subnet CIDR |
| `availability_zone` | `string` | `us-west-2a` | Availability Zone |
| `instance_type` | `string` | `m5.xlarge` | EC2 instance type (m5.xlarge minimum for VM-Series) |
| `allowed_mgmt_cidrs` | `list(string)` | `["0.0.0.0/0"]` | CIDRs allowed to access management interface — **restrict to your IP** |
| `key_name` | `string` | `""` | Optional existing EC2 key pair (if blank, one is generated) |
| `common_tags` | `map(string)` | See `variables.tf` | Tags applied to all resources |

## Outputs

| Output | Description |
|--------|-------------|
| `vmseries_instance_id` | EC2 instance ID |
| `management_eip` | Public IP for PAN-OS management access |
| `management_url` | HTTPS URL to PAN-OS web UI |
| `mgmt_private_ip` | Management ENI private IP |
| `untrust_private_ip` | Untrust ENI private IP (ethernet1/1) |
| `trust_private_ip` | Trust ENI private IP (ethernet1/2) |
| `ami_id` | VM-Series AMI used |
| `bootstrap_bucket` | S3 bootstrap bucket name |
| `ssh_command` | Ready-to-use SSH command |
| `password_setup_instructions` | Step-by-step password setup guide |
| `layer2_connection_info` | Object containing all values needed for the Layer 2 PAN-OS provider |

---

## CI/CD

GitHub Actions runs on every push and pull request to `main`:

| Step | Command | Purpose |
|------|---------|---------|
| Format | `terraform fmt -check -recursive` | Enforce consistent formatting |
| Init | `terraform init` | Initialize providers |
| Validate | `terraform validate` | Syntax and configuration validation |
| Plan | `terraform plan` (PRs only) | Preview infrastructure changes |

AWS credentials are stored as GitHub Actions secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`). Apply is intentionally manual — plan review before any infrastructure change goes live.

---

## AMI Selection

The VM-Series AMI is resolved dynamically at plan time using the AWS Marketplace product code:

| Attribute | Value |
|-----------|-------|
| Product Code | `hd44w1chf26uv4p52cdynb2o` |
| Edition | PAYG with Advanced Security Subscription |
| Architecture | x86_64 |
| Selection | Most recent available |

This ensures deployments always use the latest patched PAN-OS image without manual AMI ID updates.

---

## Security Considerations

- **Management access**: `allowed_mgmt_cidrs` defaults to `0.0.0.0/0` for initial setup. **Restrict this to your IP or VPN CIDR in production.**
- **Data-plane security groups**: Permissive in this configuration for lab use. Apply least-privilege rules in production.
- **IMDSv1**: Enabled (`http_tokens = optional`) because PAN-OS requires IMDSv1 to read the SSH key from instance metadata. Monitor for IMDSv2 support in future PAN-OS releases.
- **S3 bootstrap bucket**: Public access fully blocked. Server-side encryption enabled (AES-256). `force_destroy = true` for clean teardown — disable in production.
- **SSH key**: Generated in Terraform state and written locally as `vmseries-key.pem`. The `.gitignore` excludes `*.pem` and `*.tfvars` files.

---

## Extending to Production

This deployment is a single-AZ reference architecture. To extend for production use:

- **High availability**: Deploy active/passive VM-Series pair across two AZs with HA links
- **Centralized inspection**: Use AWS Transit Gateway + Gateway Load Balancer (GWLB) for hub-and-spoke traffic inspection
- **Panorama integration**: Add Panorama server IP to `init-cfg.txt` for centralized management with device groups and template stacks
- **Multi-region**: Use directory-based Terraform workspaces (`environments/us-west-2/`, `environments/us-east-1/`) calling shared modules
- **Multi-cloud**: Palo Alto publishes official Terraform modules for [AWS](https://github.com/PaloAltoNetworks/terraform-aws-vmseries-modules), [Azure](https://github.com/PaloAltoNetworks/terraform-azurerm-vmseries-modules), and [GCP](https://github.com/PaloAltoNetworks/terraform-google-vmseries-modules). Layer 2 PAN-OS configuration is cloud-agnostic and reusable across all platforms.
- **Remote state**: Migrate to S3 backend with DynamoDB locking for team collaboration

---

## Project Structure

```
.
├── main.tf                          # Provider configuration, AMI data source
├── vpc.tf                           # VPC, subnets, IGW, route tables
├── security-groups.tf               # Management and data-plane security groups
├── vmseries.tf                      # EC2 instance, ENIs, EIP, SSH key pair
├── bootstrap.tf                     # S3 bucket, init-cfg.txt, IAM role
├── variables.tf                     # Input variable definitions
├── outputs.tf                       # Output definitions (19 outputs)
├── terraform.tfvars.example         # Example variable values (copy to terraform.tfvars)
├── .github/
│   └── workflows/
│       └── terraform.yml            # CI/CD: fmt, validate, plan
├── .gitignore                       # Excludes state, tfvars, PEM files
└── LICENSE                          # MIT License
```

---

## Related

- [Layer 2: PAN-OS Configuration](https://github.com/cloudbatsx/paloalto-panos-terraform) — Firewall policy, zones, NAT, and routing as code
- [PAN-OS Terraform Provider](https://registry.terraform.io/providers/PaloAltoNetworks/panos/latest) — Official provider documentation
- [VM-Series Deployment Guide](https://docs.paloaltonetworks.com/vm-series) — Palo Alto Networks documentation
- [VM-Series AWS Reference Modules](https://github.com/PaloAltoNetworks/terraform-aws-vmseries-modules) — Official Palo Alto Terraform modules

---

## Built by CloudBats

<p align="center">
  <strong>CloudBats LLC</strong> — Network Security & Cloud Infrastructure, Automated
</p>

This repository is a working example of how we deliver Palo Alto Networks deployments for our clients. Every engagement follows the same principles: infrastructure as code, automated policy management, CI/CD pipelines, and documentation your team can maintain long after we hand it off.

### What We Deliver

- **Palo Alto VM-Series deployments** on AWS, Azure, and GCP — fully automated with Terraform, from VPC design through firewall policy configuration
- **Firewall policy as code** — security rules, NAT, routing, and address objects managed via the PAN-OS Terraform provider with Git-based change tracking and CI/CD review gates
- **Multi-cloud network security** — consistent firewall policy across cloud providers using a single Terraform codebase with Panorama integration for centralized management
- **Custom Terraform providers** — purpose-built providers for network platforms that lack native Terraform support (UniFi, proprietary APIs, legacy infrastructure)
- **Migration & modernization** — transition from manual firewall management or legacy platforms (OpenBSD, iptables, proprietary appliances) to automated Palo Alto infrastructure

### How We Work

We scope, build, and hand off. You get production-ready Terraform code in your own GitHub organization, CI/CD pipelines configured to your workflow, operational runbooks, and a team that understands your architecture — not a black box you can't maintain.

### Get in Touch

If your team is evaluating Palo Alto Networks for cloud security, planning a firewall automation initiative, or needs Terraform expertise for network infrastructure, we'd welcome the conversation.

**GitHub:** [github.com/cloudbatsx](https://github.com/cloudbatsx)
**Email:** [sales@cloudbats.com](mailto:sales@cloudbats.com)

---

## License

MIT License. See [LICENSE](LICENSE) for details.
