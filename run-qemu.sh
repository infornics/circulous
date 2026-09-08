#!/usr/bin/env bash
# ==============================================================================
# Circulous ISO QEMU Runner Script
# ==============================================================================
# Launches the built Circulous ISO image inside a QEMU/KVM virtual machine.
# Usage: ./run-qemu.sh [path/to/circulous.iso] [--ram 4G] [--cpu 4]
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/build.conf"

if [ -f "${CONFIG_FILE}" ]; then
    source "${CONFIG_FILE}"
fi

ISO_PATH="${OUTPUT_DIR}/${ISO_NAME:-Circulous-1.0-alpha-amd64.iso}"
RAM_SIZE="4G"
CPU_CORES="4"
ENABLE_KVM=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ram)
            RAM_SIZE="$2"
            shift 2
            ;;
        --cpu)
            CPU_CORES="$2"
            shift 2
            ;;
        --no-kvm)
            ENABLE_KVM=false
            shift
            ;;
        -h|--help)
            echo "Circulous QEMU ISO Runner"
            echo "Usage: $0 [iso_path] [options]"
            echo ""
            echo "Options:"
            echo "  --ram SIZE     Amount of RAM (default: 4G)"
            echo "  --cpu CORES    Number of CPU cores (default: 4)"
            echo "  --no-kvm       Disable KVM hardware acceleration"
            exit 0
            ;;
        *)
            if [ -f "$1" ]; then
                ISO_PATH="$1"
            else
                echo "Warning: ISO file $1 not found. Searching default location..."
            fi
            shift
            ;;
    esac
done

if [ ! -f "$ISO_PATH" ]; then
    echo -e "\033[0;31mError: Circulous ISO image not found at '${ISO_PATH}'.\033[0m"
    echo "Please build the ISO first by running: sudo ./build.sh"
    exit 1
fi

echo -e "\033[0;36m[Circulous QEMU Launcher] Starting virtual machine...\033[0m"
echo -e "  ISO Target : \033[1;32m${ISO_PATH}\033[0m"
echo -e "  Memory     : ${RAM_SIZE}"
echo -e "  CPU Cores  : ${CPU_CORES}"

KVM_FLAGS=""
if [ "$ENABLE_KVM" = true ] && [ -e /dev/kvm ]; then
    echo -e "  KVM Accel  : \033[0;32mEnabled (/dev/kvm)\033[0m"
    KVM_FLAGS="-enable-kvm -cpu host"
else
    echo -e "  KVM Accel  : \033[0;33mDisabled (Software Emulation)\033[0m"
    KVM_FLAGS="-cpu qemu64"
fi

qemu-system-x86_64 \
    ${KVM_FLAGS} \
    -m "${RAM_SIZE}" \
    -smp "${CPU_CORES}" \
    -cdrom "${ISO_PATH}" \
    -boot d \
    -vga virtio \
    -display gtk,zoom-to-fit=on \
    -usb \
    -device usb-tablet \
    -name "Circulous Live Session"
