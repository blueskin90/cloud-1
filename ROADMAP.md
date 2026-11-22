# Cloud-1: reimplementation roadmap

A step-by-step order to rebuild the project yourself. Each step leaves
something that **works and that you can test** before moving on, and each one
adds a single new idea. For every step: what to build, how you know it's done,
and what you should be able to explain afterwards.

---

## Step 0: Set up your tools (no project code yet)

- **New repo**, with `.gitignore` written **first**: `.vault_pass`, `vault.yml`,
  `hosts.ini`, `.env`.
- **Install Ansible** on your machine: `pipx install --include-deps ansible`.
- **A test VM** you can reset (QEMU + Ubuntu cloud image + cloud-init), so you
  don't experiment on the OVH VPS.
- **OVH VPS** (Ubuntu 24.04, your SSH key added at order time) and a
  **DuckDNS** domain pointing to it. You only need them from step 9 on.

✅ **Done when:** `ssh` into the test VM works.

🎓 **Be able to explain:** control node vs. managed node, and why the target
only needs SSH and Python.

## Step 1: Ansible "hello world"

- `ansible.cfg`, `inventory/hosts.ini` with your VM, then `ansible all -m ping`.
- A `site.yml` with **one role, `common`**: OS check, apt cache, a few
  packages, timezone.

✅ **Done when:** the second run shows **`changed=0`**.

🎓 Playbook → play → role → task. Facts. What `ok` vs. `changed` means.
**Idempotency.**

## Step 2: `security` role

- ufw: allow SSH **before** turning on the firewall, then 80/443, default deny.
- Then SSH hardening (no root login, no passwords). Only do this once key
  login works, ideally with a `bootstrap.yml` that installs the key.
- fail2ban.

✅ **Done when:** you can still log in 😅, and `sudo ufw status` shows only
22/80/443.

🎓 Handlers (why sshd restarts only when its config changed). Why the rule
order matters.

⚠️ On 24.04, `/run/sshd` must exist for `sshd -t`. Name your hardening file
`00-…` so cloud-init's file doesn't override it.

## Step 3: `docker` role

- Docker's official apt repo (`deb822_repository`), engine + compose plugin,
  enabled at boot.
- `/opt/<project>`, the `frontend` network, and the `backend` network with
  **`internal: true`**.

✅ **Done when:** `docker run hello-world` works on the VM, `docker network ls`
shows both networks, and the second run is `changed=0`.

🎓 Why Docker **bypasses ufw** for published ports, and what that means for
your design.

## Step 4: MariaDB, first on your own machine, then as a role

1. **Locally**: Dockerfile + entrypoint + a small `compose.yml`. Iterate with
   `docker compose up --build` until the DB starts and persists data across
   `down`/`up`.
2. **Then the vault**, before you write any password anywhere: `vault.yml` +
   `ansible-vault encrypt`, with secrets written to files and mounted as
   **Docker secrets**.
3. **Then the role**: copy build files, write secrets (`no_log: true`),
   template the compose file, `docker_compose_v2`.

✅ **Done when:**

- The DB initialises **only on the first start**.
- Data survives the container being recreated.
- `docker compose ps` shows **no published port**.
- No root account exists **without a password**. Check
  `SELECT User,Host FROM mysql.user`.

🎓 Layer order and the build cache, `exec` / PID 1, volumes vs. bind mounts,
why secrets go in files rather than env vars.

## Step 5: WordPress

- Same pattern: php-fpm + WordPress + wp-cli in the image (pinned versions,
  checksums verified), entrypoint that waits for the DB, then
  `wp config create` / `wp core install` **only if needed**.

✅ **Done when:** the logs show the install once, and on restart it's skipped.
You can't reach the site from a browser yet; that comes with nginx.

🎓 Why php-fpm needs a web server in front of it. What FastCGI is.

⚠️ Test with a password containing `"`.

## Step 6: nginx with a self-signed certificate

- nginx container, the **only** one with `ports: 80, 443`. HTTP → HTTPS
  redirect, self-signed certificate generated at start, FastCGI to
  `wordpress:9000`.
- Use the Docker DNS resolver plus a variable in `fastcgi_pass`, so nginx
  starts even when WordPress is down.

✅ **Done when:** you see the WordPress site in a browser over HTTPS (after
clicking through the certificate warning). 🎉 This is the first big milestone.

🎓 Server blocks, `server_name`, how nginx serves static files from the shared
volume while sending PHP to the PHP container.

## Step 7: phpMyAdmin + routing by domain

- php-fpm 8.3 container (phpMyAdmin 5.2 doesn't support 8.4). Cookie auth,
  `AllowRoot` off, `setup/` removed.
- A second nginx server block for `pma.<domain>`. Use `<ip>.nip.io` until you
  have a real domain.

✅ **Done when:** `https://pma.<domain>` lets you log in with the WordPress DB
user, root is refused, and `/libraries/` returns 403.

🎓 Routing by `Host` header, the default server, least privilege on DB users.

## Step 8: Main `docker-compose.yml` + polish

- A main `docker-compose.yml` that `include`s each role's compose file.
- Healthchecks, `restart: unless-stopped`, image tags based on a hash of the
  build files, `pull: never`.

✅ **Done when:** `docker compose up -d` starts everything,
`docker compose restart wordpress` restarts only WordPress, and a second
`ansible-playbook` run shows `changed=0`.

🎓 How Ansible knows when to rebuild an image, and why that keeps the deploy
idempotent.

## Step 9: The real server + Let's Encrypt

- Deploy to the OVH VPS with `domain=<you>.duckdns.org`.
- certbot in a one-shot container: **use `--staging` first**, then switch to
  production. Add the daily renewal cron job.

✅ **Done when:** the browser shows a **valid padlock** on both domains.

🎓 The HTTP-01 challenge, why the self-signed certificate comes first, why
HSTS only comes with a real certificate.

## Step 10: Run the correction sheet against yourself

| Test | How |
|---|---|
| Fresh machine | reset the VM, `bootstrap.yml` + `site.yml`, nothing else |
| Idempotency | run twice → `changed=0` |
| Several servers | 2 hosts in the inventory, one run, both sites work |
| Reboot | create a post with an image → `sudo reboot` → still there |
| Ports | `nmap -p- <ip>` from outside → only 22/80/443 |
| DB isolated | connecting to 3306 from outside fails |
| Secrets | `git grep -i password` → only references and placeholders |
| Deploy one part | `--tags nginx` works on its own |

## Step 11: README + defense

- Architecture, how to deploy, and **an honest AI usage section**.
- Practice explaining every file. Your best preparation is to explain it to a
  peer, and let them evaluate you with the correction sheet.

---

## General tips

- **Commit after each step that works.** It gives you a clean history and a
  known-good point to go back to.
- **Use this repo only when you're stuck.** Try first, then compare. The
  comments in each file explain why things are done that way.
- **Don't script SSH connections in a tight loop** (e.g. waiting for a reboot):
  ufw's SSH rate limit can lock you out for a few minutes. Wait on the HTTP
  ports instead.
- **Keep the cloud-init data source available on your test VM**, otherwise
  cloud-init treats a reboot as a new instance and regenerates the SSH host
  keys.
