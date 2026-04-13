# agent-playbooks

> Ansible playbooks for provisioning agent servers — including [Hermes Agent](https://hermes-agent.nousresearch.com/), [OpenClaw](https://openclaw.org/), and [Claude Code](https://claude.ai/code) — on Ubuntu Server VMs managed by [lume](https://github.com/trycua/lume) or [OrbStack](https://orbstack.dev).

## Requirements

- [Python 3](https://www.python.org/)
- [Homebrew](https://brew.sh/) (macOS — used to install [lume](https://github.com/trycua/lume) via the bundled `Brewfile`)
- A VM backend — either:
  - **[lume](https://github.com/trycua/lume)** — full VMs from ISO. Requires an Ubuntu Server ISO in the repo root:
    - [Ubuntu Server 24.04 LTS — ARM64](https://ubuntu.com/download/server/arm) (Apple Silicon, Raspberry Pi, etc.)
    - [Ubuntu Server 24.04 LTS — x86_64 / amd64](https://ubuntu.com/download/server)
  - **[OrbStack](https://orbstack.dev)** — lightweight Linux machines, no ISO needed

## Getting Started

### 1. Install Ansible and dependencies

```bash
make install
```

This runs `brew bundle` (installing `lume` from the `Brewfile`), creates a Python virtualenv, and installs the Ansible collections listed in `configuration/requirements.yml`.

### 2. Initialize your configuration

```bash
make init BACKEND=orbstack
# or
make init BACKEND=lume
```

This interactive script prompts for:
- **Remote SSH user** and **SSH key path** (defaults to `~/.orbstack/ssh/id_ed25519` for OrbStack, `~/.ssh/id_ed25519` for lume)
- **Vault password** (encrypts your secrets)
- **AI assistant** — which agent stack to deploy:

| Choice | Stack |
|---|---|
| hermes | base, docker, hermes (Hermes Agent + Honcho) |
| openclaw | base, openclaw |
| claude-code | base, docker, claude (Claude Code) |

- **Host name** and **IP address** of the VM you will create

It renders the Jinja2 templates in `configuration.example/` into a `configuration/` directory (gitignored), containing `ansible.cfg`, `.vault_pass`, `deploy.yml`, `hosts.yml`, `vault.yml`, and `requirements.yml`. If `configuration/` already exists, the script skips setup and prints next steps.

### 3. Edit your vault and encrypt

Open `configuration/vault.yml` and fill in your real secrets (bot tokens, API keys, etc.), then encrypt:

```bash
make encrypt
```

To edit later:

```bash
make decrypt
# edit configuration/vault.yml
make encrypt
```

### 4. Create a VM

**Using OrbStack** (recommended — no ISO needed):

```bash
make setup_orbstack_vm HOST=my-agent
```

**Using lume** (full VM from ISO):

```bash
make setup_lume_vm HOST=my-agent
```

To customize, call the underlying script directly:

```bash
# OrbStack — supports --distro (default: ubuntu) and --amd64 for x86_64 emulation
./scripts/setup.sh "my-agent" --backend orbstack --distro debian:bookworm
./scripts/setup.sh "my-agent" --backend orbstack --amd64

# lume — requires --iso, supports --memory and --disk-size
./scripts/setup.sh "my-agent" --backend lume \
  --iso "./ubuntu-24.04.4-live-server-amd64.iso"
```

The script is idempotent — it skips creation if the VM already exists.

### 5. Deploy

```bash
make deploy HOST=my-agent
```

### 6. Post-deploy setup

On first deploy, the hermes role generates an SSH key and prints the public key. Add it to the appropriate GitHub account under Settings > SSH and GPG keys.

Then SSH in and complete interactive setup:

```bash
make connect_hermes HOST=my-agent
# Inside the tmux session:
hermes setup          # Authenticate with Nous Portal (OAuth)
hermes model          # Select AI model
hermes memory setup   # Configure Honcho memory backend
```

Start the gateway (systemd service is installed during deploy):

```bash
hermes gateway start
```

Tail the gateway logs:

```bash
hermes-logs
```

### 7. Discord bot setup

Each host needs its own Discord bot. For each host:

**a. Create a Discord application and bot**

Go to the [Discord Developer Portal](https://discord.com/developers/applications) and click **New Application**. Navigate to **Bot**, give it a username, then scroll to **Privileged Gateway Intents** and enable **Message Content Intent**.

**b. Generate a bot token**

On the **Bot** page, click **Reset Token** and copy it. Store it in `configuration/vault.yml` as `<host>_bot_token` (e.g., `my_agent_bot_token`), then run `make encrypt`.

**c. Invite the bot to a server**

Navigate to **OAuth2** > **URL Generator**. Select the `bot` scope and enable these permissions:
- View Channels
- Send Messages
- Send Messages in Threads
- Read Message History
- Attach Files
- Add Reactions

Set integration type to **Guild Install**, copy the generated URL, and add the bot to your server.

**d. Deploy and configure**

```bash
make deploy HOST=my-agent
make connect_hermes HOST=my-agent
# Inside the tmux session:
hermes gateway setup   # Configure Discord platform
hermes gateway start
```

## Available Commands

| Command | Purpose |
|---|---|
| `make install` | Install Ansible, ansible-lint, and collections |
| `make init BACKEND=<lume\|orbstack>` | Initialize configuration from backend template |
| `make setup_orbstack_vm HOST=<name>` | Create an OrbStack VM |
| `make setup_lume_vm HOST=<name>` | Create a lume VM (8GB RAM, 110GB disk) |
| `make deploy HOST=<name>` | Deploy to a host |
| `make check HOST=<name>` | Dry-run to preview changes |
| `make lint` | Lint playbooks |
| `make encrypt` | Encrypt the vault file |
| `make decrypt` | Decrypt the vault file |
| `make start HOST=<name> BACKEND=<lume\|orbstack>` | Start a VM |
| `make connect_hermes HOST=<name>` | SSH into a host as hermes user in tmux |
| `make connect_claude HOST=<name>` | SSH into a host as claude user in tmux |
| `make connect_openclaw HOST=<name>` | SSH into a host as openclaw user in tmux |

## Architecture

Your playbook (`configuration/deploy.yml`) provisions hosts with a role chain from the [`tjmaynes.agents`](https://github.com/tjmaynes/ansible-agentic-collection) collection. For the Hermes stack:

1. **`tjmaynes.agents.base`** — base packages (including `gh`), SSH hardening (key-only, no root login), UFW firewall, fail2ban, service user creation, timezone, unattended-upgrades, mise runtimes (Node, Python, Go, direnv, just, Bun), custom DNS (optional), custom CA certs (optional), git config
2. **`tjmaynes.agents.docker`** — rootless Docker running under the service user (no docker group escalation), optional Honcho memory backend via docker-compose
3. **`tjmaynes.agents.hermes`** — scoped sudoers, Hermes Agent install (official curl installer), Playwright browser install, gateway config, systemd service via `hermes gateway install`, environment file (`.env`) with per-host config, `hermes-logs` helper, and SSH-based GitHub access

Hosts are defined flat in `configuration/hosts.yml` with per-host variables. Shared configuration lives in play-level vars in the playbook. Per-host secrets come from the encrypted vault. Deploy one host at a time with `--limit`.

### Optional per-host features

Some features are conditionally enabled based on whether the host defines certain variables:

| Variable | Effect |
|---|---|
| `base_custom_ca_certificate_path` | Installs CA cert to system trust store and Chromium NSS database |
| `base_custom_dns_server` / `base_custom_dns_domain` | Configures split DNS via `systemd-resolved` |
| `agent_github_token` | Adds `GITHUB_TOKEN` and `GH_TOKEN` to hermes `.env` |
| `agent_home_assistant_url` / `agent_home_assistant_token` | Adds `HASS_URL` and `HASS_TOKEN` to hermes `.env` |
| `agent_discord_bot_token` (+ optional `agent_discord_allowed_users` / `agent_discord_home_channel`) | Adds Discord config to hermes `.env` |
| `agent_mattermost_url` / `agent_mattermost_token` (+ optional `agent_mattermost_allowed_users`) | Adds Mattermost config to hermes `.env` |
| `agent_git_user_name` / `agent_git_user_email` | Configures git identity for the service user |
