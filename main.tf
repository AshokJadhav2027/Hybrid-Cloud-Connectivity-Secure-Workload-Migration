terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# ============================================
# CONFIGURAZIONE VARIABILI
# ============================================
# Definisco le variabili per rendere l'infrastruttura riutilizzabile
# e per non hardcodare valori sensibili o mutevoli.

variable "aws_region" {
  description = "Regione AWS target. Eu-central-1 (Francoforte) è ideale per bassa latenza dall'Italia, potrei usare Milano in futuro."
  type        = string
  default     = "eu-central-1"
}

provider "aws" {
  region = var.aws_region
}

# Limito l'accesso SSH e UDP (WireGuard) solo al mio IP statico di casa
variable "my_home_ip" {
  description = "Il mio IP pubblico statico"
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Email per ricevere alert se supero il budget"
  type        = string
  sensitive   = true
}

variable "rpi_ip" {
  description = "Indirizzo locale del Raspberry Pi"
  type        = string
  default     = "192.168.0.99"
}

# ============================================
# GESTIONE COSTI (FINOPS)
# ============================================
# Imposto un budget per evitare costi inaspettati
resource "aws_budgets_budget" "free-budget-terraform" {
  name              = "terraform-budget"
  budget_type       = "COST"
  limit_amount      = "0.50"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2025-12-30_00:01"
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.notification_email]
  }
}

# ============================================
# NETWORKING E SICUREZZA
# ============================================
# Creo una VPC dedicata per isolare completamente le risorse.
# Non uso la VPC di default per avere controllo totale su routing e security groups.
resource "aws_vpc" "tf_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-vpc"
  }
}

# Subnet pubblica, necessaria perché l'istanza EC2 deve essere raggiungibile direttamente
# da internet per fungere da endpoint VPN e Reverse Proxy.
resource "aws_subnet" "tf_subnet" {
  vpc_id     = aws_vpc.tf_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "Subnet-Terraform"
  }
}

# L'internet gateway
resource "aws_internet_gateway" "tf_igw" {
  vpc_id = aws_vpc.tf_vpc.id
  tags = {
    Name = "Internet-Gateway-Terraform"
  }
}

# Instrado tutto il traffico in uscita (0.0.0.0/0) verso l'internet gateway
resource "aws_route_table" "tf_route_table" {
  vpc_id = aws_vpc.tf_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf_igw.id
  }

  tags = {
    Name = "Routing-Table-Terraform"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.tf_subnet.id
  route_table_id = aws_route_table.tf_route_table.id
}

# Security Group, uso il principio del least privilege
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Policy di sicurezza per istanza VPN"
  vpc_id      = aws_vpc.tf_vpc.id

  # SSH limitato solo all'IP di casa
  ingress {
    description = "Accesso SSH (solo IP di casa)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_home_ip]
  }

  # WireGuard limitato solo all'IP di casa
  ingress {
    description = "Endpoint WireGuard VPN (solo IP di casa)"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = [var.my_home_ip]
  }

  # HTTP/Reverse Proxy, pubblico per servire il traffico web
  ingress {
    description = "Traffico Web Pubblico (Nginx Reverse Proxy)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP, per debugging tramite ping
  ingress {
    description = "Ping ICMP per controllo connessione"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.my_home_ip] # Limito anche il ping per oscuramento
  }

  # Egress aperto per permettere connessioni verso l'esterno
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Gestione chiavi SSH: creo una coppia di chiavi dedicata a questo progetto.
# Evito di riciclare chiavi personali su infrastrutture cloud effimere.
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "kp" {
  key_name   = "my-terraform-key"
  public_key = tls_private_key.pk.public_key_openssh
}

# ============================================
# COMPUTE RESOURCES
# ============================================
# Uso un data source per usare sempre l'AMI Ubuntu LTS più recente
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # ID ufficiale Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "tf_web_server" {
  ami = data.aws_ami.ubuntu.id
  # t3.micro per il free tier
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.tf_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  # Assegna un IP Pubblico, necessario per raggiungere l'istanza da internet
  associate_public_ip_address = true

  key_name = aws_key_pair.kp.key_name

  # Disabilito il source/dest check per permettere all'istanza di agire come router/NAT per la VPN
  source_dest_check = false

  tags = {
    Name = "Server-Terraform-Prova1"
  }
}

# Esporto la chiave privata localmente per connessione via SSH.
# Imposto permessi stretti (0600) perché SSH rifiuterebbe una chiave troppo esposta.
resource "local_file" "ssh_key" {
  filename        = "${path.module}/terraform-key.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0600"
}

# Generazione dinamica dell'inventory di Ansible
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/ansible/inventory.tmpl", {
    ec2_ip = aws_instance.tf_web_server.public_ip,
    rpi_ip = var.rpi_ip
  })
  filename = "${path.module}/ansible/inventory.ini"
}
