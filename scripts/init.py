#!/usr/bin/env python3
"""Initialize configuration/ from Jinja2 templates in configuration.example/."""

import argparse
import getpass
import os
import re
import shutil
import stat
import sys
from pathlib import Path

from jinja2 import Environment, FileSystemLoader


def render_template(env, template_name, output_path, variables):
    template = env.get_template(template_name)
    output_path.write_text(template.render(**variables))


def prompt(label, default=None):
    if default:
        value = input(f"{label} [{default}]: ").strip()
        return value or default
    return input(f"{label}: ").strip()


def prompt_password(label):
    return getpass.getpass(f"{label}: ")


def prompt_choice(label, choices, default="1"):
    value = input(f"{label} [{default}]: ").strip() or default
    if value in choices:
        return choices[value]
    raise SystemExit(f"Error: Invalid choice '{value}'.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--backend",
        required=True,
        choices=["lume", "orbstack"],
        help="VM backend (lume or orbstack)",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    config_dir = project_root / "configuration"
    example_dir = project_root / "configuration.example"

    # --- Guards ---
    if not example_dir.exists():
        print("Error: configuration.example/ not found. Is this the project root?")
        sys.exit(1)

    if config_dir.exists():
        print("configuration/ already exists. Skipping setup.")
        print()
        print("Next steps:")
        print("  1. Edit configuration/vault.yml with your real secrets")
        print("  2. make encrypt")
        print(f"  3. make setup_{args.backend}_vm HOST=<name>")
        print("  4. make deploy HOST=<name>")
        print()
        print("To reinitialize: rm -rf configuration/ && make init BACKEND=...")
        sys.exit(0)

    print()
    print(f"Agent Playbooks — Project Setup ({args.backend})")
    print("=" * 46)
    print()

    # --- SSH / Ansible settings ---
    default_user = os.environ.get("USER", "ubuntu")
    if args.backend == "orbstack":
        remote_user = prompt("Remote SSH user (e.g. ubuntu)", default_user)
    else:
        remote_user = prompt("Remote SSH user", default_user)

    if args.backend == "orbstack":
        ssh_key_path = prompt(
            "SSH private key path", "~/.orbstack/ssh/id_ed25519"
        )
    else:
        ssh_key_path = prompt("SSH private key path", "~/.ssh/id_ed25519")

    # --- Vault password ---
    print()
    while True:
        vault_password = prompt_password("Vault password")
        vault_confirm = prompt_password("Confirm vault password")
        if vault_password == vault_confirm:
            break
        print("Passwords do not match. Try again.")
        print()

    # --- AI assistant ---
    print()
    print("Available AI assistants:")
    print("  1) hermes      — Hermes Agent + Honcho memory backend")
    print("  2) openclaw    — OpenClaw deployment")
    print("  3) claude-code — Claude Code deployment")
    assistant = prompt_choice(
        "AI assistant",
        {
            "1": "hermes",
            "hermes": "hermes",
            "2": "openclaw",
            "openclaw": "openclaw",
            "3": "claude-code",
            "claude-code": "claude-code",
        },
    )

    # --- Host settings ---
    print()
    while True:
        host_name = prompt("Host name")
        if re.match(r"^[a-zA-Z0-9_-]+$", host_name):
            break
        print("Invalid name. Use only letters, numbers, hyphens, and underscores.")

    host_ip = prompt("Host IP")

    # --- Scaffold configuration/ ---
    print()
    print("Generating configuration/...")

    config_dir.mkdir(parents=True)

    env = Environment(
        loader=FileSystemLoader(str(example_dir)),
        variable_start_string="<<",
        variable_end_string=">>",
        block_start_string="<%",
        block_end_string="%>",
        keep_trailing_newline=True,
    )

    render_template(
        env,
        "ansible.cfg.j2",
        config_dir / "ansible.cfg",
        {"remote_user": remote_user, "ssh_key_path": ssh_key_path},
    )

    render_template(
        env,
        "hosts.yml.j2",
        config_dir / "hosts.yml",
        {"host_name": host_name},
    )

    render_template(
        env,
        "vault.yml.j2",
        config_dir / "vault.yml",
        {"host_name": host_name, "host_ip": host_ip},
    )

    render_template(
        env,
        "deploy.yml.j2",
        config_dir / "deploy.yml",
        {"host_name": host_name, "assistant": assistant},
    )

    # Copy static files
    shutil.copy2(example_dir / "requirements.yml", config_dir / "requirements.yml")

    # Write vault password
    vault_pass_file = config_dir / ".vault_pass"
    vault_pass_file.write_text(vault_password)
    vault_pass_file.chmod(stat.S_IRUSR | stat.S_IWUSR)

    print()
    print("Created configuration/")
    print(f"  ansible.cfg       — remote_user: {remote_user}")
    print(f"  deploy.yml        — {assistant} stack targeting {host_name}")
    print(f"  hosts.yml         — host: {host_name} ({host_ip})")
    print("  vault.yml         — secrets placeholder (edit before encrypting)")
    print("  requirements.yml  — collection dependencies")
    print("  .vault_pass       — vault password")
    print()
    print("Next steps:")
    print("  1. Edit configuration/vault.yml with your real secrets")
    print("  2. make encrypt")
    print(f"  3. make setup_{args.backend}_vm HOST={host_name}")
    print(f"  4. make deploy HOST={host_name}")
    print()


if __name__ == "__main__":
    main()
