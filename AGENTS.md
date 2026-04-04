# Agents

## Project overview

Ansible project that provisions AI agent servers on ARM64 Ubuntu Server VMs managed by [lume](https://github.com/trycua/lume). Currently manages two servers: **helios** (OpenClaw gateway) and **athena** (Claude Code server).

## Structure

```
playbooks/
  deploy-openclaw.yml     # OpenClaw deployment (openclaw_servers)
  deploy-claude.yml       # Claude server deployment (claude_servers)
roles/
  debian/                 # Base packages, SSH, service user creation, unattended-upgrades
  security/               # UFW firewall (SSH allowed first, then deny-by-default), fail2ban
  docker/                 # Docker CE, DOCKER-USER chain (UFW bypass prevention)
  openclaw/               # Daemon setup, Discord integration, env vars
  tailscale/              # Tailnet join, firewall rules, binary permissions
  mise/                   # Runtime installer (Node, Python, Go, bun, etc.)
  claude/                 # Claude Code, Discord plugin, systemd, SSH/GitHub, mise activation
vars/
  common.yml              # Shared variables
  vault.yml               # Encrypted secrets (ansible-vault)
inventory/hosts.yml       # Host definitions with per-host variables
scripts/
  setup-vm.sh             # Idempotent lume VM creation script
```

## Key conventions

- Two playbooks: `deploy-openclaw.yml` for openclaw_servers, `deploy-claude.yml` for claude_servers
- System-level tasks run as root (`become: true` at play level)
- The `openclaw` role is parameterized via `openclaw_user` per-host
- The `claude` role is parameterized via `claude_user` per-host
- The `debian` role is parameterized via `debian_user` per-host — controls service user creation (skips if user already exists via `id` check)
- The `docker` role is parameterized: set `docker_user` per-host (defaults to `claude`) to control which user is added to the docker group
- The `mise` role is parameterized: set `mise_user` per-host (defaults to `openclaw`), set `mise_bun_version` to include bun
- The `security` role allows SSH before setting default-deny to prevent lockouts
- Secrets are stored in `vars/vault.yml` and encrypted with `ansible-vault`
- Host-specific variables (e.g. `mise_user`, `discord_bot_token`) go in `inventory/hosts.yml`, not in roles
- Discord bot tokens are per-host: defined as `helios_bot_token` / `athena_bot_token` in vault, mapped to `discord_bot_token` per-host in inventory
- Git user credentials for athena are stored in vault (`athena_git_user_name`, `athena_git_user_email`)
- Environment variables for service users are managed via `~/.config/environment.d/*.conf` files
- SSH keys for GitHub access are generated on-server (never committed) — managed by the `claude` role
- The systemd service unit for claude-code is a Jinja2 template (`roles/claude/templates/claude-code.service.j2`)
- All tasks must be idempotent — safe to re-run without side effects
- VM creation via `scripts/setup-vm.sh` is idempotent — skips if VM already exists

## Secrets

Sensitive values use `no_log: true` and file mode `0600`. Always run `make encrypt` after editing `vars/vault.yml`.

This repo is public — never commit plaintext secrets. Host IPs, tokens, and auth keys go in the encrypted vault.
