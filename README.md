# Cloud-1

Automated deployment of a WordPress stack (nginx, WordPress/php-fpm, MariaDB, phpMyAdmin)
on one or more remote Ubuntu 22.04 / 24.04 servers with Ansible and Docker Compose.

## Architecture

```
                    Internet
                       │  only 22 (SSH, rate-limited), 80, 443 open (ufw)
┌──────────────────────┼───────────────────────────────────────────────┐
│ Server (Ubuntu)      │                                               │
│                      ▼                                               │
│   ┌─────────────────────────────┐                                    │
│   │ nginx            :80 :443   │  only container publishing ports   │
│   │ TLS, routing by domain      │                                    │
│   └───────┬──────────────┬──────┘                                    │
│           │ FastCGI :9000│              network "frontend"           │
│ ┌─────────▼──────┐ ┌─────▼──────────┐                                │
│ │ wordpress      │ │ phpmyadmin     │                                │
│ │ php-fpm 8.4    │ │ php-fpm 8.3    │                                │
│ └─────────┬──────┘ └─────┬──────────┘                                │
│           │ MySQL :3306  │              network "backend" (internal: │
│        ┌──▼──────────────▼──┐                  no internet access)   │
│        │ mariadb            │                                        │
│        └────────────────────┘                                        │
└──────────────────────────────────────────────────────────────────────┘
```

### Containers

One process per container, each built from its own Dockerfile (Alpine base,
layers ordered from least to most frequently changed for the build cache).

| Container | Process | Networks | Published ports |
|---|---|---|---|
| nginx | nginx | frontend | 80, 443 |
| wordpress | php-fpm (WordPress 7.1, wp-cli) | frontend, backend | none |
| phpmyadmin | php-fpm (phpMyAdmin 5.2) | frontend, backend | none |
| mariadb | mariadbd | backend | none |
| certbot | one-shot tool, run on demand (`docker compose run`) | frontend | none |

Each entrypoint does its one-time setup only when needed (database
initialisation, WordPress install, self-signed certificate), then `exec`s the
main process so it runs as PID 1 and receives stop signals directly.

### Routing

| Request | Goes to |
|---|---|
| `http://…` | 301 → `https://…` (except `/.well-known/acme-challenge/` for Let's Encrypt) |
| `https://<domain>` | WordPress |
| `https://pma.<domain>` | phpMyAdmin |
| bare IP / unknown name | 301 → `https://<domain>` |

`<domain>` is the host's `domain=` inventory variable, or `<ip>.nip.io` when
none is set, so routing works on any server without DNS setup.

### TLS

1. nginx always starts with a self-signed certificate, so HTTPS works from the first second.
2. If a real `domain` is set, Ansible runs certbot (HTTP-01 challenge served by nginx),
   then restarts nginx on the Let's Encrypt certificate. A failure is reported but not
   fatal: the site stays on the self-signed certificate.
3. A daily cron job renews the certificate and reloads nginx.

HSTS is only sent with a real certificate.

### Data and volumes

Everything that must survive a reboot or a container re-creation lives in named
volumes (`docker volume ls`):

| Volume | Content |
|---|---|
| `cloud1_db_data` | MariaDB data |
| `cloud1_wp_data` | WordPress files, uploads, plugins (read-only in nginx) |
| `cloud1_pma_app` | phpMyAdmin code, refreshed at each start (read-only in nginx) |
| `cloud1_letsencrypt`, `cloud1_acme_webroot` | Let's Encrypt certificates and challenges |
| `cloud1_tls_selfsigned` | fallback certificate |

Containers use `restart: unless-stopped` and Docker is enabled at boot, so the
site comes back on its own after a reboot.

### Secrets

- Stored in `group_vars/all/vault.yml`, encrypted with ansible-vault and not committed.
- Written on the server to `/opt/cloud-1/secrets/` (root only, mode 600), then mounted
  into containers as Docker secrets (`/run/secrets/…`). They never appear in environment
  variables, `docker inspect` or Ansible output (`no_log`).
- The phpMyAdmin cookie key is generated on the server on the first run.

### On the server

```
/opt/cloud-1/
├── docker-compose.yml      # includes each service's compose.yml
├── secrets/                # root only
├── mariadb/   {compose.yml, build/}
├── wordpress/ {compose.yml, build/}
├── phpmyadmin/{compose.yml, build/}
└── nginx/     {compose.yml, build/, conf/cloud1.conf}
```

```sh
cd /opt/cloud-1
sudo docker compose ps                  # status of all services
sudo docker compose up -d               # start everything
sudo docker compose restart wordpress   # restart one service
sudo docker compose logs -f nginx
```

### Deployment flow (`site.yml`)

1. **Prepare host**: `common` (OS check, packages) → `security` (SSH key, ufw,
   SSH hardening, fail2ban) → `docker` (engine, networks, main compose file).
2. **Deploy services**, in dependency order: `mariadb` → `wordpress` →
   `phpmyadmin` → `nginx`. Each role copies its build files, writes its secrets
   and compose file, then starts its container and waits until it is healthy.

Image tags are a hash of their build files: an image is only rebuilt when its
Dockerfile, config or entrypoint changes. A second run reports `changed=0`.

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

<!-- TODO: write once the project is reimplemented. The subject requires
     clearly identifying what was generated by AI tools. -->
TODO
