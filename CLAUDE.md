# CLAUDE.md — pcon_server

This file provides persistent context for Claude Code. Read it at the start of every session.

---

## Purpose

This repo documents the configuration and provisioning of the Hetzner VPS that hosts `doc_app`. It contains setup scripts and hardening scripts to allow the server to be fully reprovisioned from scratch.

This is **not** an application repo. Do not put application code here.

---

## Server Specs

| Property | Value |
|----------|-------|
| Provider | Hetzner Cloud |
| Hostname | pcon |
| IP | 89.167.98.167 |
| OS | Ubuntu 24.04 LTS |
| CPU | ARM64 (Ampere), 2 vCPU |
| RAM | 4GB |
| Admin user | richard |
| Domain | pcon.pro |

---

## Directory Layout

```
/home/richard/
  pcon_server/             ← this repo
    setup.sh               ← full provisioning script (run on fresh server)
    harden.sh              ← security hardening (run as sudo once)
    nginx_setup.sh         ← Nginx + SSL setup (run as sudo once per app)
    CLAUDE.md              ← this file
    README.md              ← minimal placeholder

/opt/doc_app/
  app/                     ← doc_app source code (git repo → haymanjoyce/doc_app)

/var/pcon_app/
  projects/
    pcon_doc/              ← user content (docs, evidence, index_store)
      docs/
      evidence/
      index_store/
      members/
  users/
    richard/               ← user profile folder (future auth)
```

---

## Installed Software

| Package | Version |
|---------|---------|
| Ubuntu | 24.04 LTS |
| Node.js | v22.22.0 |
| npm | 11.10.1 |
| Python | 3.12.3 |
| Git | 2.43.0 |
| Claude Code | 2.1.52+ |

---

## Scripts

### setup.sh
Full provisioning script. Run on a fresh Ubuntu 24.04 server as the target user. Installs Node.js, Python, Git, Claude Code. Downloads installers to a temp file, verifies SHA256 checksums before executing.

```bash
bash /home/richard/pcon_server/setup.sh
```

### harden.sh
Security hardening. Run once after provisioning. Requires sudo.

```bash
sudo bash /home/richard/pcon_server/harden.sh
```

Applies:
- SSH: disables password auth, disables root login, limits MaxAuthTries to 3
- fail2ban: bans IPs after 5 failed SSH attempts for 1 hour
- unattended-upgrades: auto-applies security patches, auto-reboots at 03:00 UTC

### nginx_setup.sh
Nginx + SSL setup. Run once per application deployment. Requires sudo.

```bash
sudo bash /home/richard/pcon_server/nginx_setup.sh
```

---

## Security Status

| Control | Setting | Status |
|---------|---------|--------|
| SSH password auth | PasswordAuthentication no | ✅ |
| SSH root login | PermitRootLogin no | ✅ |
| SSH max auth tries | MaxAuthTries 3 | ✅ |
| fail2ban sshd jail | Bans after 5 failures for 1h | ✅ |
| unattended-upgrades | Security patches auto-applied | ✅ |
| Auto-reboot after patches | 03:00 UTC | ✅ |
| .env permissions | 600 richard:richard | ✅ |

---

## tmux

Persistent named session `main` configured. Every SSH login auto-attaches to it.

```bash
Ctrl-B c    # new window
Ctrl-B 1    # switch to window 1
Ctrl-B 2    # switch to window 2
Ctrl-B d    # detach (session keeps running)
```

---

## Firewall (ufw)

```
22/tcp    ← SSH
80/tcp    ← HTTP (redirects to HTTPS)
443/tcp   ← HTTPS
```

Check status:
```bash
sudo ufw status
```

---

## Nginx

Config: `/etc/nginx/sites-available/pcon.pro`

- `/` — serves `/opt/doc_app/app/frontend/dist/` (React static build)
- `/api/` — proxied to `http://127.0.0.1:8000/api/`
- `/api/chat/ws` — WebSocket proxied to FastAPI
- SSL via Let's Encrypt (auto-renews via certbot timer)
- HTTP Basic Auth via `/etc/nginx/.htpasswd`

```bash
sudo nginx -t                  # test config
sudo systemctl reload nginx    # apply changes
sudo certbot renew --dry-run   # test cert renewal
```

---

## doc_app Service

Managed by systemd user service.

```bash
systemctl --user status doc_app
systemctl --user restart doc_app
systemctl --user stop doc_app
journalctl --user -u doc_app -f
```

---

## Hetzner Snapshots

Must be created manually from the Hetzner Cloud Console — cannot be triggered from within the server.

1. Go to console.hetzner.cloud
2. Select server → Snapshots tab
3. Create Snapshot — label with date and context (e.g. `pre-update-2026-03-01`)

Recommended: snapshot before any major change.

### Snapshot History

| Date | Label |
|------|-------|
| 2026-02-25 | Post doc_app deployment — full stack live |
| 2026-02-25 | Post README refactor |
| 2026-03-01 | Post repo rename (doc_app → pcon_app) and /var/pcon_app data migration |
| 2026-03-01 | Post GitHub integration removal and CLAUDE.md cleanup |
| 2026-03-04 | Post app rename (pcon_app → doc_app) |

---

## Reprovisioning from Scratch

On a fresh Ubuntu 24.04 server:

```bash
# 1. From your local machine — copy SSH key
ssh-copy-id richard@<new-server-ip>

# 2. SSH in and clone pcon_server repo
ssh richard@<new-server-ip>
git clone git@github.com:haymanjoyce/pcon_server.git /home/richard/pcon_server

# 3. Run provisioning script
bash /home/richard/pcon_server/setup.sh

# 4. Run security hardening
sudo bash /home/richard/pcon_server/harden.sh

# 5. Deploy doc_app — see /opt/doc_app/app/CLAUDE.md
```

---

## Dependency Management

### System packages (automatic)
- unattended-upgrades handles Ubuntu security patches automatically
- Auto-reboot at 03:00 UTC if required

### Manual updates (run periodically)
- Node.js: check current vs latest at nodejs.org, update via NodeSource if needed
- npm: sudo npm install -g npm@latest
- Claude Code: sudo npm install -g @anthropic-ai/claude-code
- Python: Ubuntu-managed, handled by unattended-upgrades
- Git: Ubuntu-managed, handled by unattended-upgrades

### Before updating anything
- Take a Hetzner snapshot first
- Test the app is healthy after each update

---

## What Claude Code Should Never Do

- Modify application code in `/opt/doc_app/app/` — that belongs to the doc_app repo
- Touch user data in `/var/pcon_app/` — that belongs to the application
- Delete or modify SSH keys in `/home/richard/.ssh/`
- Disable or weaken any security hardening (fail2ban, SSH config, ufw)
- Commit `.env` files or any secrets
- Modify CLAUDE.md without being explicitly asked

---

## Current Status

- [x] Server provisioned on Hetzner
- [x] Security hardening applied
- [x] tmux configured
- [x] Claude Code installed
- [x] Nginx configured with SSL
- [x] doc_app deployed and running
- [x] setup.sh complete and tested
- [x] harden.sh complete and tested
- [x] nginx_setup.sh complete and tested
- [x] pcon_server repo on GitHub (haymanjoyce/pcon_server)
