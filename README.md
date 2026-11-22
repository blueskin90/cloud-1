# Cloud-1

Automated deployment of a WordPress stack (nginx, WordPress/php-fpm, MariaDB, phpMyAdmin)
on one or more remote Ubuntu 22.04 / 24.04 servers with Ansible and Docker Compose.

## Architecture

TODO

## Requirements (control machine)

```sh
pipx install --include-deps ansible
ansible-galaxy collection install -r requirements.yml
```

Target hosts only need: Ubuntu 22.04 or 24.04, SSH access (key-based), Python 3.
Developed on an OVH VPS running Ubuntu 24.04 (default user: `ubuntu`).

## First contact with a fresh server

Skip this if you selected your SSH key when creating the server.

```sh
sudo apt install sshpass                    # lets Ansible log in with a password
ssh ubuntu@<ip>                             # once: check & accept the host fingerprint
                                            # (and change the password if forced to)
ansible-playbook bootstrap.yml --ask-pass   # installs ~/.ssh/id_ed25519.pub
```

Use another key with `-e security_ssh_public_key_file=~/.ssh/other.pub`.

## Deploy

```sh
cp inventory/hosts.ini.example inventory/hosts.ini           # add your server(s)
cp group_vars/all/vault.yml.example group_vars/all/vault.yml # fill in secrets
echo 'your-vault-password' > .vault_pass && chmod 600 .vault_pass
ansible-vault encrypt group_vars/all/vault.yml
ansible-playbook site.yml
```

Deploy a single component: `ansible-playbook site.yml --tags <role>`.

## Roles

| Role | Purpose |
|---|---|
| common | base packages, system setup |
| security | ufw (only 22/80/443), SSH hardening, fail2ban |
| docker | Docker Engine, Compose plugin, shared networks |
| mariadb | database container (internal network only) |
| wordpress | WordPress on php-fpm |
| phpmyadmin | phpMyAdmin on php-fpm |
| nginx | reverse proxy, TLS, routing by domain |

## AI usage

TODO: describe which parts were generated or assisted by AI.
