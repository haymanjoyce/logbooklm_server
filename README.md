# Server Documentation

**Hostname:** pcon
**Server IP:** 89.167.98.167
**Provider:** Hetzner Cloud
**OS:** Ubuntu 24.04 LTS
**User:** richard

---

## Directory Layout

```
/home/richard/
├── setup.sh                 # Full provisioning script (run on fresh server)
├── harden.sh                # Security hardening (run as sudo once)
├── nginx_setup.sh           # Nginx + SSL setup (run as sudo once per app)
└── README.md                # This file

/opt/pcon_app/
└── app/                     # pcon_app source (git repo → haymanjoyce/pcon_app)

/var/pcon_app/
├── projects/
│   └── pcon_doc/            # Active project data
│       ├── docs/            # Markdown documents
│       ├── evidence/        # Source PDFs and text files
│       ├── index_store/     # Persisted LlamaIndex vector index
│       └── members/         # members.json — project access list
└── users/
    └── richard/             # Per-user data
```

---

## Security Hardening

> **Status: Applied and verified 2026-02-25.** All items below are active.

Run **once** after provisioning (requires sudo password):

```bash
sudo bash "$HOME/harden.sh"
```

The script exits immediately if not run as root. It applies:
1. **SSH** — writes `/etc/ssh/sshd_config.d/hardening.conf` disabling password auth, limiting `MaxAuthTries` to 3, and enforcing key-only login
2. **fail2ban** — installs and configures to ban IPs after 5 failed SSH attempts for 1 hour
3. **unattended-upgrades** — writes `/etc/apt/apt.conf.d/51local-overrides` to enable auto-removal of unused packages and auto-reboot at 03:00 UTC (idempotent drop-in; does not modify the vendor `50unattended-upgrades` file)

### Current verified state

| Control | Setting | Status |
|---------|---------|--------|
| SSH password auth | `PasswordAuthentication no` | ✅ Active |
| SSH root login | `PermitRootLogin no` | ✅ Active |
| SSH max auth tries | `MaxAuthTries 3` | ✅ Active |
| SSH keyboard-interactive | `KbdInteractiveAuthentication no` | ✅ Active |
| fail2ban sshd jail | Bans after 5 failures for 1h | ✅ Active |
| unattended-upgrades | Security patches auto-applied | ✅ Active |
| Auto-reboot after patches | 03:00 UTC, even with users logged in | ✅ Active |
| `.env` permissions | `600 richard:richard` | ✅ Correct |

### Verify SSH is key-only
```bash
sshd -T | grep -E "passwordauthentication|pubkeyauthentication"
# Expected:
#   passwordauthentication no
#   pubkeyauthentication yes
```

### Verify fail2ban
```bash
sudo fail2ban-client status sshd
```

---

## Automatic Security Updates

`unattended-upgrades` is installed and active. Patches from:
- `ubuntu:noble` (base packages)
- `ubuntu:noble-security` (security patches)
- Ubuntu ESM (Extended Security Maintenance, if subscribed)

Auto-reboot is enabled — the server will reboot at **03:00 UTC** if a patch requires it.

Config in `/etc/apt/apt.conf.d/51local-overrides` (drop-in set by `harden.sh`):
```
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

Check status:
```bash
systemctl status unattended-upgrades
sudo unattended-upgrade --dry-run --debug 2>&1 | head -40
```

---

## tmux

A persistent named session `main` is configured. On every SSH login, `.bashrc` automatically attaches to it (or creates it if it doesn't exist).

### Session behaviour
- **SSH in** → lands directly in the `main` tmux session
- **Disconnect** → session keeps running; all windows/panes persist
- **SSH back in** → reattaches to exactly where you left off

### Config: `~/.tmux.conf`
- Mouse support (scroll, pane select, resize)
- 10,000 line scrollback buffer
- Windows and panes numbered from 1
- Date/time in status bar

### Useful commands
```bash
tmux ls
Ctrl-b d   # detach
Ctrl-b c   # new window
Ctrl-b n   # next window
Ctrl-b p   # previous window
Ctrl-b %   # vertical split
Ctrl-b "   # horizontal split
tmux kill-session -t main
```

---

## Hetzner Cloud Snapshots (Manual)

Automatic snapshots cannot be triggered from within the server — they must be created from the **Hetzner Cloud Console** or via the **Hetzner Cloud API**.

### Via Hetzner Cloud Console (GUI)
1. Go to [console.hetzner.cloud](https://console.hetzner.cloud)
2. Select your project → select the server (`pcon`, IP `89.167.98.167`)
3. Click **"Snapshots"** tab
4. Click **"Create Snapshot"** → give it a label (e.g. `pre-update-2026-02-25`) → confirm
5. Snapshots are billed at €0.0119/GB/month

### Via Hetzner Cloud API (scriptable)
```bash
# Get server ID
curl -H "Authorization: Bearer $HETZNER_API_TOKEN" \
     https://api.hetzner.cloud/v1/servers | jq '.servers[] | {id,name}'

# Create snapshot (replace SERVER_ID)
curl -X POST \
     -H "Authorization: Bearer $HETZNER_API_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"description":"pre-update-'"$(date +%F)"'","type":"snapshot"}' \
     "https://api.hetzner.cloud/v1/servers/SERVER_ID/actions/create_image"
```

### Recommended snapshot schedule
- **Before any major change** (OS upgrade, dependency bump, config change)
- **Weekly** via a cron job hitting the Hetzner API from your local machine

### Snapshot history

| Date | Label |
|------|-------|
| 2026-02-25 | Post pcon_app deployment — full stack live |
| 2026-02-25 | Post README refactor — separation of concerns across all three repos |
| 2026-03-01 | Post repo rename (doc_app → pcon_app) and /var/pcon_app data migration |

---

## UptimeRobot Monitoring

UptimeRobot cannot be configured from the server itself — do this from [uptimerobot.com](https://uptimerobot.com).

**Server to monitor:**
```
89.167.98.167
```

### Setup steps
1. Log in to [uptimerobot.com](https://uptimerobot.com)
2. Click **"+ Add New Monitor"**
3. Choose monitor type:
   - **Ping** — monitors raw connectivity (fastest, least overhead)
   - **TCP Port** — monitors SSH (port 22) — confirms server is reachable and SSH is alive
4. Set:
   - **Friendly Name:** `pcon (89.167.98.167)`
   - **IP/Host:** `89.167.98.167`
   - **Monitoring Interval:** 5 minutes (free plan) or 1 minute (paid)
5. Add your email for alerts
6. Save

---

## Installer Checksum Pinning

`setup.sh` downloads the NodeSource and Poetry installers to a temp file, verifies their SHA256 before executing, and deletes the temp file afterwards. If the checksum changes (e.g. after a NodeSource or Poetry release), the script will abort with a mismatch error.

To update the pins after an intentional upgrade, recompute and replace the `EXPECTED_SHA256` values in `setup.sh`:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sha256sum
curl -sSL https://install.python-poetry.org | sha256sum
```

---

## Re-provisioning from Scratch

On a fresh Ubuntu 24.04 server as the target user:

```bash
# 1. Copy your SSH public key first (from your local machine):
#    ssh-copy-id richard@<new-server-ip>

# 2. SSH in and clone this repo or copy setup.sh, then run:
bash "$HOME/setup.sh"

# 3. Apply security hardening:
sudo bash "$HOME/harden.sh"

# 4. Deploy applications — refer to each application's own README:
#    - pcon_app: /opt/pcon_app/app/README.md
```

---

## Installed Software Versions (as of 2026-02-25)

| Package | Version |
|---------|---------|
| Ubuntu | 24.04 LTS |
| Node.js | v22.22.0 |
| npm | (bundled with Node) |
| Python | 3.12.3 |
| pip | 24.0 |
| Git | 2.43.0 |
| Poetry | 2.3.2 |
| Claude Code | 2.1.52 |
