# Ansible Automation for AWS WireGuard VPN

Questo progetto Ansible automatizza la configurazione di una VPN WireGuard Site-to-Site tra una istanza EC2 AWS e un Raspberry Pi locale, configurando inoltre Nginx come Reverse Proxy sulla EC2.

## Prerequisiti
1. Ansible installato (`sudo apt install ansible` o `pip install ansible`).
2. Chiave privata SSH (`terraform-key.pem`) nella root del progetto (generata da Terraform).

## Setup Inventario
L'IP della EC2 è dinamico. Prima di lanciare il playbook, aggiorna `ansible/inventory.ini`.

1. Copia il sample:
   ```bash
   cp ansible/inventory.sample.ini ansible/inventory.ini
   ```
2. Recupera l'IP della EC2 da Terraform:
   ```bash
   terraform output -raw server_public_ip
   ```
3. Modifica `ansible/inventory.ini`:
   - Inserisci l'IP della EC2 sotto `[ec2]`.
   - Inserisci l'IP del tuo Raspberry Pi sotto `[raspberry]`.

## Esecuzione
Lancia il playbook principale:
```bash
cd ansible
ansible-playbook site.yml
```

## Cosa fa questo Playbook
1. **WireGuard**:
   - Installa WireGuard su entrambi i nodi.
   - Genera le chiavi private/pubbliche se mancanti.
   - Scambia le chiavi pubbliche automaticamente (Magic!).
   - Configura l'interfaccia `wg0` e le regole di firewall (iptables) per il NAT sulla EC2.
2. **Nginx (Reverse Proxy)**:
   - Installa Nginx su EC2.
   - Configura il proxy pass verso il Raspberry (tunnel 10.100.0.2:8080).

## Note
- L'interfaccia di rete pubblica su EC2 viene rilevata automaticamente (`ansible_default_ipv4.interface`).
- Assicurati che il Raspberry sia raggiungibile via SSH dalla macchina che esegue Ansible (chiavi SSH o password devono essere configurate).
