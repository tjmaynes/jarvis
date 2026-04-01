# openclaw-server

> Personal assistant powered by OpenClaw, running on an ARM64 Ubuntu Server VM provisioned via Ansible.

## What is OpenClaw?

[OpenClaw](https://docs.openclaw.ai/) is a self-hosted, open-source gateway that bridges messaging platforms (Telegram, WhatsApp, Discord, iMessage) with AI coding agents. It runs entirely on your own hardware, providing an always-available AI assistant with tool use, memory, sessions, and a web-based Control UI — all without relying on cloud services.

## Requirements

- [Python 3](https://www.python.org/)
- [lume](https://github.com/trycua/lume) (macOS VM manager)
- [Ubuntu Server ARM64 ISO](https://ubuntu.com/download/server/arm)

## Getting Started

### 1. Create the VM with `lume`

```bash
lume create eros --os linux --cpu 4 --memory 8GB --disk-size 110GB
```

First boot — mount the installer ISO:

```bash
lume run eros --mount ~/Downloads/ubuntu-24.04.4-live-server-arm64.iso
```

After installation — run headless:

```bash
make start
```

### 2. Install Ansible and dependencies

```bash
make install
```

### 3. Configure secrets

```bash
make decrypt
# Edit vars/vault.yml with real values:
#   - some_key
make encrypt
```

### 4. Deploy

```bash
make deploy
```

### 5. Post-deploy

On first deploy, the playbook generates an SSH key for the openclaw user and prints the public key. Add it to the [bewoogiebot](https://github.com/bewoogiebot) GitHub account under Settings > SSH and GPG keys.

Verify the gateway is running:

```bash
ssh eros
sudo su - openclaw
systemctl --user status openclaw-gateway
```

## Available Commands

| Command | Purpose |
|---|---|
| `make install` | Install Ansible, ansible-lint, and the openclaw.installer collection |
| `make deploy` | Deploy OpenClaw to server |
| `make check` | Dry-run to preview changes |
| `make lint` | Lint playbook and roles |
| `make encrypt` | Encrypt the vault file |
| `make decrypt` | Decrypt the vault file |
| `make start` | Start Eros VM |

## Architecture

A single playbook (`playbooks/deploy.yml`) runs the following roles:

1. **`openclaw.installer.openclaw`** — official collection handling Node.js, pnpm, Docker, OpenClaw, systemd, UFW, fail2ban, and unattended-upgrades
2. **`tailscale`** — joins the VM to a Tailscale tailnet and locks down access
3. **`openclaw`** — installs additional packages (stow), configures the openclaw daemon, sets up SSH-based GitHub access (bewoogiebot), and manages environment variables

Host-specific variables (e.g. `openclaw_name`) are defined per-host in `inventory/hosts.yml`.
