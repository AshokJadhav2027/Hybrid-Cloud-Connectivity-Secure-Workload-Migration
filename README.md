# Hybrid Cloud Connectivity & Secure Exposure Architecture

[![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=fff)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![AWS](https://custom-icon-badges.demolab.com/badge/AWS-%23FF9900.svg?logo=aws&logoColor=white)](https://aws.amazon.com/)
[![WireGuard](https://img.shields.io/badge/WireGuard-88171A)](https://www.wireguard.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](https://opensource.org/licenses/MIT)

**[Leggi la versione italiana](README_IT.md)**

## ✨ Introduction

### Objective

The goal is to design and implement an **automated, cost-optimized Hybrid Cloud architecture** that securely extends an on-premise network to the AWS public cloud. This project demonstrates strict adherence to **Infrastructure as Code (IaC)** principles, **Security Hardening** best practices, and **FinOps** budget constraints.

### The Challenge
The need to securely expose on-premise services (hosted on a local Raspberry Pi) to the public internet without using direct port forwarding or exposing the local network to public threats. The solution required low latency, full automation, and strict compliance with **AWS Free Tier** limits.

### The Solution
An automated pipeline that provisions an **AWS EC2 instance (t3.micro)** acting as a **Secure Gateway**. A **Site-to-Site WireGuard Tunnel** connects the on-premise device to the cloud, while an **Nginx reverse proxy** handles inbound traffic orchestration.

### Key Features
*   **Infrastructure as Code (IaC)**: Full provisioning managed via **Terraform**.
*   **Configuration Management**: Idempotent state management using **Ansible** playbooks.
*   **Zero-Trust Networking**: Strict Security Groups allowing management access (SSH/UDP) only from a specific static IP (Whitelisting).
*   **Automated Provisioning**: "Zero-touch" deployment from an empty state to a fully functional VPN tunnel.
*   **Cost Optimization**: Architecture designed specifically for **AWS Free Tier** compliance (T3.micro, GP3 storage, dynamic routing via inventory to avoid Elastic IP costs).

---

## 🏗️ Architecture

### Architectural Decisions & Trade-offs

This project implements a **Hybrid Cloud Site-to-Site VPN** solution. Below are the key engineering decisions driving the architecture:

### 1. WireGuard vs. OpenVPN/IPsec
*   **Performance & Efficiency:** WireGuard was chosen for its high throughput and low latency, crucial for running on resource-constrained edge devices (like the Raspberry Pi). Its implementation in **kernel-space** avoids the context-switching overhead typical of userspace solutions like OpenVPN.
*   **Security Posture:** With a codebase of ~4,000 lines (compared to ~100k+ of competitors), WireGuard drastically reduces the **attack surface**. The use of **ChaCha20-Poly1305** ensures state-of-the-art modern cryptography.

### 2. Infrastructure as Code (IaC) Strategy
*   **Terraform:** Used for **immutable provisioning** of AWS infrastructure. It manages the lifecycle of VPCs, Subnets, and Security Groups, ensuring the cloud environment is reproducible and free of untracked configurations (**drift-free**).
*   **Ansible:** Employed for **Configuration Management** and software provisioning. Ansible guarantees idempotency on both the ephemeral server (EC2) and the persistent client (Edge Device), automating the generic key exchange process without manual intervention.

### 3. Cost-Optimization (FinOps) & Dynamic IP Handling
*   **Design Choices:** To strictly adhere to **AWS Free Tier** limits, an Elastic IP (EIP) was intentionally omitted to avoid costs associated with non-utilization or over-provisioning.
*   **Automation Implications:** This constraint necessitated a robust approach based on **Dynamic Inventory**. Terraform outputs the ephemeral Public IP to a local inventory file, and Ansible dynamically reconfigures the client endpoint at each deployment. This demonstrates the capability to manage volatile cloud environments where static IPs are not guaranteed.

---

## 🛠️ Tech Stack

| Component | Technology | Role |
|-----------|------------|------|
| **Provisioning** | **Terraform** | VPC, Subnets, EC2, Security Groups, IAM |
| **Configuration** | **Ansible** | Package installation, WireGuard config, Nginx setup |
| **Secure Tunneling** | **WireGuard** | UDP-based high-performance VPN Service |
| **Edge Proxy** | **Nginx** | Reverse Proxy, SSL Termination (Planned), Traffic Routing |
| **OS** | **Ubuntu 24.04 LTS** | Canonical supported OS |

---

## 🚀 Deployment

### Prerequisites & Local Setup

#### 1. Install Required Tools

Install the main tools on your Control Node (Linux/macOS):

- **Terraform**: [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads)
- **Ansible**: `pip install ansible` or via package manager
- **AWS CLI**: [AWS CLI Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Git**: Via package manager

**Verify installations:**
```bash
terraform --version
ansible --version
aws --version
```

#### 2. AWS Credentials Configuration

Terraform uses AWS credentials to provision cloud resources. You have two options:

**Option A: AWS CLI Configuration (Recommended)**
```bash
aws configure
```
You will be prompted for:
- **AWS Access Key ID**: Your IAM access key
- **AWS Secret Access Key**: Your IAM secret key
- **Default region**: `eu-central-1` (or your preferred region)
- **Default output format**: `json`

**Option B: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="eu-central-1"
```

> The IAM user needs permissions for: `EC2`, `VPC`, `Budgets`. For testing, the `AdministratorAccess` policy works, but for production, create a scoped IAM policy following the principle of least privilege.

#### 3. Target Device Preparation (Raspberry Pi / Local Server)

Before Ansible can configure your local server, you must have SSH access from your Control Node.

**Generate an SSH Key Pair (if you don't have one)**
```bash
# Check if you already have a key
ls -la ~/.ssh/id_rsa.pub

# If it doesn't exist, generate one (press Enter for default values). Replace the email.
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

**Copy the Public Key to the Raspberry Pi**
```bash
# Replace 'ubuntu' with your username and '192.168.0.99' with your RPi's IP
ssh-copy-id ubuntu@192.168.0.99
```
> This command adds your public key to `~/.ssh/authorized_keys` on the Raspberry Pi, enabling passwordless SSH authentication.

**Test SSH Connection**
```bash
ssh ubuntu@192.168.0.99
# You should connect without being asked for a password
```

> If this step fails, Ansible **will not work**. Common issues:
> - Wrong username (check with `whoami` on the RPi)
> - SSH service not started (`sudo systemctl start ssh`)
> - Firewall blocking port 22

#### 4. Clone and Configure the Repository

```bash
git clone https://github.com/davidefalconi69/aws-hybrid-cloud-connectivity.git
cd aws-hybrid-cloud-connectivity
```

**Create your variables file:**
```bash
cp terraform.tfvars.example terraform.tfvars
```

**Edit `terraform.tfvars` with your values:**
```hcl
my_home_ip         = "YOUR_PUBLIC_IP/32"
notification_email = "your@email.com"
rpi_ip             = "192.168.0.99"
```

### Provisioning Workflow

After completing the prerequisites, run these commands:

**1. Infrastructure Provisioning (Terraform)**
```bash
terraform init
terraform apply
```
*This creates the VPC, Security Groups, EC2 instance, generates SSH keys, and creates the dynamic Ansible Inventory.*

**2. Configuration Management (Ansible)**
```bash
cd ansible
ansible-playbook site.yml
```
*Executes idempotent playbooks to install WireGuard, generate keypairs, configure the tunnel, and set up the Nginx Reverse Proxy.*

> The file `ansible.cfg` automatically configures `inventory.ini` as the default inventory

---

## 🔒 Security

*   **Network Isolation**: Uses custom VPCs, avoiding generic default settings.
*   **Least Privilege Access**: Security Groups allow SSH (Port 22) and WireGuard (Port 51820) traffic **EXCLUSIVELY** from the specific administrative IP (Whitelisting).
*   **Key Management**: SSH keys are generated for each deployment by Terraform. WireGuard keys are generated "on-the-fly" by Ansible and never stored in the repository.

---

**Author**: Davide Falconi
