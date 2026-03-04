#!/usr/bin/env bash
# setup.sh — Full server provisioning script
#
# Provisions a fresh Ubuntu 24.04 LTS server with:
#   - Python 3.12, Git, Poetry
#   - Claude Code (native installer — no Node.js required)
#   - tmux with persistent "main" session and SSH auto-attach
#   - Security hardening (run harden.sh separately as root)
#
# Usage:
#   # As the target user (e.g. richard):
#   bash setup.sh
#
#   # Then run hardening separately:
#   sudo bash "$HOME/harden.sh"
#
set -euo pipefail

LOG_TAG="[setup.sh]"

info()  { echo "$LOG_TAG $*"; }
die()   { echo "$LOG_TAG ERROR: $*" >&2; exit 1; }

info "=== Server Setup Script ==="
info "User: $(whoami)  |  Home: $HOME  |  Date: $(date -u)"
echo ""

# ─── 1. System packages ───────────────────────────────────────────────────────
info "[1/6] Installing system packages..."
sudo apt-get update -y
sudo apt-get install -y \
    git curl wget build-essential \
    python3 python3-pip python3-venv \
    software-properties-common apt-transport-https ca-certificates \
    unattended-upgrades apt-listchanges \
    fail2ban ufw tmux

# ─── 2. Claude Code (native installer) ───────────────────────────────────────
info "[2/5] Installing Claude Code..."
if ! claude --version &>/dev/null; then
    # Native installer — no Node.js or npm required.
    # Supply chain: download to temp file, then execute (no checksum: rolling release).
    CLAUDE_INSTALLER=$(mktemp)
    curl -fsSL https://claude.ai/install.sh -o "$CLAUDE_INSTALLER"
    bash "$CLAUDE_INSTALLER"
    rm -f "$CLAUDE_INSTALLER"
fi
info "    Claude Code: $(claude --version)"

# ─── 3. Poetry (Python dependency manager) ───────────────────────────────────
info "[3/5] Installing Poetry..."
if ! poetry --version &>/dev/null; then
    # Supply chain: download first, verify checksum, then execute.
    # Update EXPECTED_SHA256 when you intentionally upgrade Poetry.
    POETRY_INSTALLER=$(mktemp)
    POETRY_EXPECTED_SHA256="963d56703976ce9cdc6ff460c44a4f8fbad64c110dc447b86eeabb4a47ec2160"
    curl -sSL https://install.python-poetry.org -o "$POETRY_INSTALLER"
    POETRY_ACTUAL_SHA256=$(sha256sum "$POETRY_INSTALLER" | awk '{print $1}')
    if [ "$POETRY_ACTUAL_SHA256" != "$POETRY_EXPECTED_SHA256" ]; then
        rm -f "$POETRY_INSTALLER"
        die "Poetry installer checksum mismatch! Got $POETRY_ACTUAL_SHA256"
    fi
    python3 "$POETRY_INSTALLER"
    rm -f "$POETRY_INSTALLER"
    export PATH="$HOME/.local/bin:$PATH"
fi
info "    Poetry: $(poetry --version)"

# Make poetry available in PATH permanently
if ! grep -q 'poetry' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

# ─── 5. Projects directory ────────────────────────────────────────────────────
info "[4/5] Creating projects directory..."
mkdir -p "$HOME/projects"

# ─── 6. tmux configuration ────────────────────────────────────────────────────
info "[5/5] Configuring tmux..."

cat > "$HOME/.tmux.conf" <<'TMUXEOF'
# Mouse support (scrolling, pane selection, resize)
set -g mouse on

# Increase scrollback buffer
set -g history-limit 10000

# Start windows and panes at 1, not 0
set -g base-index 1
set -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Status bar
set -g status-right '%Y-%m-%d %H:%M'
TMUXEOF

# Add SSH auto-attach to .bashrc if not already present
if ! grep -q 'tmux new-session -A -s main' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'BASHEOF'

# Auto-attach to (or create) the persistent "main" tmux session on SSH login
if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ] && command -v tmux &>/dev/null; then
    exec tmux new-session -A -s main
fi
BASHEOF
fi

info "    tmux configured. SSH logins will auto-attach to the 'main' session."

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
info "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Run:  sudo bash $HOME/harden.sh   (SSH hardening, fail2ban, auto-upgrades)"
echo "  2. Deploy applications — refer to each application's own README"
echo ""
echo "Server IP: $(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
echo ""
