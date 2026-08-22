# Hybrid Cloud Connectivity & Secure Exposure Architecture

[![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=fff)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![AWS](https://custom-icon-badges.demolab.com/badge/AWS-%23FF9900.svg?logo=aws&logoColor=white)](https://aws.amazon.com/)
[![WireGuard](https://img.shields.io/badge/WireGuard-88171A)](https://www.wireguard.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](https://opensource.org/licenses/MIT)

**[Read the English Version](README.md)**

## ✨ Introduzione

### Obiettivo

Lo scopo è la progettazione e l'implementazione di un'architettura **Hybrid Cloud automatizzata e cost-optimized** che estende in modo sicuro una rete on-premise verso il cloud pubblico AWS. Il progetto dimostra una rigorosa aderenza ai principi di **Infrastructure as Code (IaC)**, best practices di **Security Hardening** e vincoli di budget **FinOps**.

### Il problema
La necessità di esporre servizi on-premise (ospitati su un Raspberry Pi locale) verso internet pubblico in modo sicuro, senza utilizzare port forwarding diretti o esporre la rete locale a minacce pubbliche. La soluzione doveva garantire bassa latenza, automazione completa e rientrare rigorosamente nei limiti del piano **AWS Free Tier**.

### La soluzione
Una pipeline automatizzata che esegue il provisioning di un'istanza **AWS EC2 (t3.micro)** che agisce come **Secure Gateway**. Un **Site-to-Site WireGuard Tunnel** connette il dispositivo on-premise al cloud, mentre un **reverse proxy Nginx** gestisce l'orchestrazione del traffico in ingresso.

### Caratteristiche chiave
*   **Infrastructure as Code (IaC)**: Provisioning completo gestito tramite **Terraform**.
*   **Configuration Management**: Gestione dello stato idempotente utilizzando playbook **Ansible**.
*   **Zero-Trust Networking**: Security Group rigorosi che permettono l'accesso di management (SSH/UDP) solo da uno specifico IP statico (Whitelisting).
*   **Automated Provisioning**: Deployment "Zero-touch" da stato vuoto a tunnel VPN completamente funzionante.
*   **Cost Optimization**: Architettura progettata specificamente per la compliance **AWS Free Tier** (T3.micro, GP3 storage, routing dinamico tramite inventory per evitare costi di Elastic IP).

---

## 🏗️ Architettura

### Decisioni architetturali e trade-offs

Questo progetto implementa una soluzione **Hybrid Cloud Site-to-Site VPN**. Di seguito le decisioni ingegneristiche chiave che guidano l'architettura:

### 1. WireGuard vs. OpenVPN/IPsec
*   **Performance & Efficiency:** WireGuard è stato scelto per il suo throughput elevato e la bassa latenza, cruciali per l'esecuzione su dispositivi edge con risorse limitate (come il Raspberry Pi). La sua implementazione in **kernel-space** evita l'overhead di context-switching tipico delle soluzioni userspace come OpenVPN.
*   **Security Posture:** Con una codebase di ~4.000 righe (contro le ~100k+ dei competitor), WireGuard riduce drasticamente la **attack surface**. L'utilizzo di **ChaCha20-Poly1305** garantisce una crittografia moderna allo stato dell'arte.

### 2. Infrastructure as Code (IaC) Strategy
*   **Terraform:** Utilizzato per l'**immutable provisioning** dell'infrastruttura AWS. Gestisce il ciclo di vita di VPC, Subnet e Security Group, assicurando che l'ambiente cloud sia riproducibile e privo di configurazioni non tracciate (**drift-free**).
*   **Ansible:** Impiegato per il **Configuration Management** e il provisioning software. Ansible garantisce l'idempotenza sia sul server effimero (EC2) che sul client persistente (Edge Device), automatizzando il complesso processo di scambio chiavi senza intervento manuale.

### 3. Cost-Optimization (FinOps) & Dynamic IP Handling
*   **Scelte progettuali:** Per aderire rigorosamente ai limiti del **AWS Free Tier**, è stato intenzionalmente omesso un Elastic IP (EIP) per evitare costi di inutilizzo.
*   **Implicazioni sull'automazione:** Questo vincolo ha reso necessario un approccio robusto basato su **Dynamic Inventory**. Terraform effettua l'output dell'IP Pubblico effimero su un file di inventory locale, e Ansible riconfigura dinamicamente l'endpoint client ad ogni deployment. Questo dimostra la capacità di gestire ambienti cloud volatili dove gli IP statici non sono garantiti.

---

## 🛠️ Tech Stack

| Componente | Tecnologia | Ruolo |
|-----------|------------|------|
| **Provisioning** | **Terraform** | VPC, Subnets, EC2, Security Groups, IAM |
| **Configuration** | **Ansible** | Package installation, WireGuard config, Nginx setup |
| **Secure Tunneling** | **WireGuard** | UDP-based high-performance VPN Service |
| **Edge Proxy** | **Nginx** | Reverse Proxy, SSL Termination (Planned), Traffic Routing |
| **OS** | **Ubuntu 24.04 LTS** | Canonical supported OS |

---

## 🚀 Deployment

### Prerequisiti & Setup Locale

#### 1. Installazione Strumenti Richiesti

Installa i tool principali sul tuo Control Node (Linux/macOS):

- **Terraform**: [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads)
- **Ansible**: `pip install ansible` o via package manager
- **AWS CLI**: [Guida Installazione AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Git**: Via package manager

**Verifica le installazioni:**
```bash
terraform --version
ansible --version
aws --version
```

#### 2. Configurazione Credenziali AWS

Terraform utilizza le credenziali AWS per effettuare il provisioning delle risorse cloud. Hai due opzioni:

**Opzione A: Configurazione AWS CLI (Consigliata)**
```bash
aws configure
```
Ti verranno richiesti:
- **AWS Access Key ID**: La tua access key IAM
- **AWS Secret Access Key**: La tua secret key IAM
- **Default region**: `eu-central-1` (o la tua regione preferita)
- **Default output format**: `json`

**Opzione B: Variabili d'Ambiente**
```bash
export AWS_ACCESS_KEY_ID="la-tua-access-key-id"
export AWS_SECRET_ACCESS_KEY="la-tua-secret-access-key"
export AWS_DEFAULT_REGION="eu-central-1"
```

> L'utente IAM necessita di permessi per: `EC2`, `VPC`, `Budgets`. Per testing, la policy `AdministratorAccess` funziona, ma per produzione crea una policy IAM con scope limitato seguendo il principio del least privilege.

#### 3. Preparazione del Target Device (Raspberry Pi / Server Locale)

Prima che Ansible possa configurare il tuo server locale, devi avere accesso SSH dal Control Node.

**Genera una Coppia di Chiavi SSH (se non ne hai una)**
```bash
# Controlla se hai già una chiave
ls -la ~/.ssh/id_rsa.pub

# Se non esiste, generane una (premi Invio per i valori di default). Sostituisci l'email
ssh-keygen -t rsa -b 4096 -C "la_tua_email@esempio.com"
```

**Copia la Chiave Pubblica sul Raspberry Pi**
```bash
# Sostituisci 'ubuntu' con il tuo username e '192.168.0.99' con l'IP del tuo RPi
ssh-copy-id ubuntu@192.168.0.99
```
> Questo comando aggiunge la tua chiave pubblica a `~/.ssh/authorized_keys` sul Raspberry Pi, abilitando l'autenticazione SSH senza password.

**Testa la Connessione SSH**
```bash
ssh ubuntu@192.168.0.99
# Dovresti connetterti senza che ti venga richiesta la password
```

> Se questo step fallisce, Ansible **non funzionerà**. Problemi comuni:
> - Username sbagliato (controlla con `whoami` sul RPi)
> - Servizio SSH non avviato (`sudo systemctl start ssh`)
> - Firewall che blocca la porta 22

#### 4. Clone e Configurazione del Repository

```bash
git clone https://github.com/davidefalconi69/aws-hybrid-cloud-connectivity.git
cd aws-hybrid-cloud-connectivity
```

**Crea il tuo file di variabili:**
```bash
cp terraform.tfvars.example terraform.tfvars
```

**Modifica `terraform.tfvars` con i tuoi valori:**
```hcl
my_home_ip         = "IL_TUO_IP_PUBBLICO/32"
notification_email = "tua@email.com"
rpi_ip             = "192.168.0.99"
```

### Workflow di Provisioning

Dopo aver completato i prerequisiti, esegui questi comandi:

**1. Infrastructure Provisioning (Terraform)**
```bash
terraform init
terraform apply
```
*Questo crea la VPC, i Security Group, l'istanza EC2, genera le chiavi SSH e crea l'Ansible Inventory dinamico.*

**2. Configuration Management (Ansible)**
```bash
cd ansible
ansible-playbook site.yml
```
*Esegue i playbook idempotenti per installare WireGuard, generare le keypair, configurare il tunnel e impostare il Reverse Proxy Nginx.*

> Il file `ansible.cfg` configura automaticamente `inventory.ini` come inventory di default

---

## 🔒 Sicurezza

*   **Network Isolation**: Utilizzo di VPC custom evitando impostazioni di default generiche.
*   **Least Privilege Access**: I Security Group permettono traffico SSH (Porta 22) e WireGuard (Porta 51820) **ESCLUSIVAMENTE** dallo specifico IP di amministrazione.
*   **Key Management**: Le chiavi SSH vengono generate per ogni deployment da Terraform. Le chiavi WireGuard sono generate "on-the-fly" da Ansible e mai salvate nel repository.

---

**Author**: Davide Falconi
