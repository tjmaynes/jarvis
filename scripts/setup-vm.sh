#!/usr/bin/env bash

set -euo pipefail

check_requirements() {
  local missing=()

  if ! command -v lume &>/dev/null; then
    missing+=("lume (https://github.com/trycua/lume)")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: missing required tools:"
    for tool in "${missing[@]}"; do
      echo "  - $tool"
    done
    exit 1
  fi
}

usage() {
  echo "Usage: $0 <server-name> [--iso <path>] [--cpu <count>] [--memory <size>] [--disk-size <size>]"
  echo ""
  echo "Create and boot an ARM64 Ubuntu Server VM using lume."
  echo "Idempotent — skips creation if the VM already exists."
  echo ""
  echo "Arguments:"
  echo "  server-name          Name for the VM (e.g., helios, athena)"
  echo ""
  echo "Options:"
  echo "  --iso <path>         Path to Ubuntu Server ARM64 ISO (default: ~/Downloads/ubuntu-24.04.4-live-server-arm64.iso)"
  echo "  --cpu <count>        Number of CPU cores (default: 4)"
  echo "  --memory <size>      Memory allocation (default: 8GB)"
  echo "  --disk-size <size>   Disk size (default: 110GB)"
  echo "  -h, --help           Show this help message"
}

main() {
  if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
  fi

  check_requirements

  local server_name="$1"
  shift

  local cpu=4
  local memory="8GB"
  local disk_size="110GB"
  local iso=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
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
      *)
        echo "Error: unknown option '$1'"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$iso" ]]; then
    echo "Error: --iso is required"
    usage
    exit 1
  fi

  if [[ ! -f "$iso" ]]; then
    echo "Error: ISO not found at $iso"
    echo "Download from: https://ubuntu.com/download/server/arm (ARM64) or https://ubuntu.com/download/server (x86_64)"
    exit 1
  fi

  if ! lume get "$server_name" &>/dev/null; then
    echo "Creating VM '$server_name' (cpu=$cpu, memory=$memory, disk=$disk_size)..."
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

main "$@"
