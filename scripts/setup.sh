#!/usr/bin/env bash

set -euo pipefail

check_requirements() {
  local backend="$1"

  case "$backend" in
    lume)
      if ! command -v lume &>/dev/null; then
        echo "Error: missing required tool: lume (https://github.com/trycua/lume)"
        exit 1
      fi
      ;;
    orbstack)
      if ! command -v orb &>/dev/null; then
        echo "Error: missing required tool: orb (https://orbstack.dev)"
        exit 1
      fi
      ;;
  esac
}

usage() {
  echo "Usage: $0 <server-name> --backend <lume|orbstack> [options]"
  echo ""
  echo "Create and boot an Ubuntu Server VM. Idempotent — skips creation if the VM already exists."
  echo ""
  echo "Arguments:"
  echo "  server-name              Name for the VM (e.g., rosie, athena)"
  echo ""
  echo "Options:"
  echo "  --backend <backend>      VM backend: lume or orbstack (required)"
  echo "  --distro <distro>        Linux distro (orbstack only, default: ubuntu)"
  echo "                           Options: alma, alpine, arch, centos, debian, devuan,"
  echo "                           fedora, gentoo, kali, nixos, opensuse, oracle, rocky,"
  echo "                           ubuntu, void. Supports version tags (e.g., ubuntu:noble)"
  echo "  --iso <path>             Path to Ubuntu Server ISO (lume only, required for lume)"
  echo "  --cpu <count>            Number of CPU cores (default: 4)"
  echo "  --memory <size>          Memory allocation (default: 8GB)"
  echo "  --disk-size <size>       Disk size (default: 110GB)"
  echo "  --amd64                  Use amd64 architecture (orbstack only, default: native)"
  echo "  -h, --help               Show this help message"
}

setup_lume() {
  local server_name="$1" cpu="$2" memory="$3" disk_size="$4" iso="$5"

  if [[ -z "$iso" ]]; then
    echo "Error: --iso is required for lume backend"
    usage
    exit 1
  fi

  if [[ ! -f "$iso" ]]; then
    echo "Error: ISO not found at $iso"
    echo "Download from: https://ubuntu.com/download/server/arm (ARM64) or https://ubuntu.com/download/server (x86_64)"
    exit 1
  fi

  if ! lume get "$server_name" &>/dev/null; then
    echo "Creating VM '$server_name' via lume (cpu=$cpu, memory=$memory, disk=$disk_size)..."
    lume create "$server_name" --os linux --cpu "$cpu" --memory "$memory" --disk-size "$disk_size"
  fi

  local vm_info
  vm_info=$(lume get "$server_name" 2>/dev/null || true)

  if echo "$vm_info" | grep -q "0.0B"; then
    echo ""
    echo "Booting '$server_name' with installer ISO..."
    echo "Complete the Ubuntu Server installation, then close the VM window."
    lume run "$server_name" --mount "$iso"
  else
    echo "VM '$server_name' already provisioned, skipping creation."
  fi
}

setup_orbstack() {
  local server_name="$1" distro="$2" amd64="$3"

  if orb list | grep -q "^$server_name "; then
    echo "VM '$server_name' already exists, skipping creation."
    return
  fi

  echo "Creating VM '$server_name' via OrbStack (distro=$distro)..."
  if [[ "$amd64" == "true" ]]; then
    orb create --arch amd64 "$distro" "$server_name"
  else
    orb create "$distro" "$server_name"
  fi

  echo ""
  echo "VM '$server_name' created. SSH access: ssh $server_name@orb"
}

main() {
  if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
  fi

  local server_name="$1"
  shift

  local backend=""
  local cpu=4
  local memory="8GB"
  local disk_size="110GB"
  local iso=""
  local distro="ubuntu"
  local amd64="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend)
        backend="$2"
        shift 2
        ;;
      --iso)
        iso="$2"
        shift 2
        ;;
      --cpu)
        cpu="$2"
        shift 2
        ;;
      --memory)
        memory="$2"
        shift 2
        ;;
      --disk-size)
        disk_size="$2"
        shift 2
        ;;
      --distro)
        distro="$2"
        shift 2
        ;;
      --amd64)
        amd64="true"
        shift
        ;;
      *)
        echo "Error: unknown option '$1'"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$backend" ]]; then
    echo "Error: --backend is required"
    usage
    exit 1
  fi

  if [[ "$backend" != "lume" && "$backend" != "orbstack" ]]; then
    echo "Error: unknown backend '$backend'. Use 'lume' or 'orbstack'."
    exit 1
  fi

  check_requirements "$backend"

  case "$backend" in
    lume)
      setup_lume "$server_name" "$cpu" "$memory" "$disk_size" "$iso"
      ;;
    orbstack)
      setup_orbstack "$server_name" "$distro" "$amd64"
      ;;
  esac
}

main "$@"
