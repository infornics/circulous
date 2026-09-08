#!/usr/bin/env bash
# ==============================================================================
# Circulous ISO Builder Script
# ==============================================================================
# Builds a customized, bootable Ubuntu-based Linux distribution named Circulous.
# Usage: sudo ./build.sh [--clean | --bootstrap | --chroot | --squashfs | --iso | --all]
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/build.conf"

if [ -f "${CONFIG_FILE}" ]; then
    source "${CONFIG_FILE}"
else
    echo "Error: Configuration file ${CONFIG_FILE} not found!"
    exit 1
fi

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[Circulous Build] INFO:${NC} $1"; }
success() { echo -e "${GREEN}[Circulous Build] SUCCESS:${NC} $1"; }
warn()  { echo -e "${YELLOW}[Circulous Build] WARNING:${NC} $1"; }
error() { echo -e "${RED}[Circulous Build] ERROR:${NC} $1"; exit 1; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Building Circulous ISO requires root privileges. Please run with: sudo ./build.sh"
    fi
}

check_dependencies() {
    info "Checking required build utilities..."
    local deps=("debootstrap" "mksquashfs" "xorriso" "grub-mkrescue")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            error "Missing dependency: $dep. Please install it using 'sudo apt install $dep'."
        fi
    done
    success "All build dependencies are installed."
}

clean_build() {
    info "Cleaning build artifacts..."
    
    # Safe unmount of bind mounts if left over
    for mount_pt in "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/dev/pts" "${ROOTFS_DIR}/dev"; do
        if mountpoint -q "$mount_pt"; then
            warn "Unmounting $mount_pt..."
            umount -lf "$mount_pt" || true
        fi
    done

    rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
    mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${WORK_DIR}" "${ROOTFS_DIR}" "${ISO_DIR}"
    success "Build directory cleaned."
}

stage_bootstrap() {
    info "Phase 1: Bootstrapping base ${UBUNTU_RELEASE} system into ${ROOTFS_DIR}..."
    if [ -f "${ROOTFS_DIR}/bin/bash" ]; then
        warn "Rootfs already exists at ${ROOTFS_DIR}. Skipping bootstrap. Use --clean to rebuild from scratch."
        return
    fi
    debootstrap --arch="${ARCH}" "${UBUNTU_RELEASE}" "${ROOTFS_DIR}" "${MIRROR_URL}"
    success "Phase 1: Debootstrap completed."
}

stage_chroot() {
    info "Phase 2: Customizing rootfs inside chroot..."

    # Copy package list and chroot script
    cp "${PROJECT_DIR}/config/packages.list" "${ROOTFS_DIR}/tmp/packages.list"
    cp "${PROJECT_DIR}/scripts/chroot_customize.sh" "${ROOTFS_DIR}/tmp/chroot_customize.sh"
    chmod +x "${ROOTFS_DIR}/tmp/chroot_customize.sh"

    # Bind mounts for chroot
    info "Binding system pseudofs (/proc, /sys, /dev)..."
    mount --bind /proc "${ROOTFS_DIR}/proc"
    mount --bind /sys "${ROOTFS_DIR}/sys"
    mount --bind /dev "${ROOTFS_DIR}/dev"
    mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"

    # Run chroot script
    info "Executing customization script inside chroot..."
    chroot "${ROOTFS_DIR}" /bin/bash /tmp/chroot_customize.sh

    # Apply filesystem overlay AFTER package installation so custom configs are preserved
    if [ -d "${PROJECT_DIR}/overlay" ]; then
        info "Applying filesystem overlay (overriding package defaults)..."
        cp -a "${PROJECT_DIR}/overlay/." "${ROOTFS_DIR}/"
    fi

    # Sync live user home directory with skel
    if [ -d "${ROOTFS_DIR}/etc/skel" ] && [ -d "${ROOTFS_DIR}/home/circulous" ]; then
        cp -a "${ROOTFS_DIR}/etc/skel/." "${ROOTFS_DIR}/home/circulous/"
        chroot "${ROOTFS_DIR}" chown -R circulous:circulous /home/circulous/
    fi

    # Unmount bind mounts
    info "Unmounting pseudofs..."
    umount -lf "${ROOTFS_DIR}/proc" || true
    umount -lf "${ROOTFS_DIR}/sys" || true
    umount -lf "${ROOTFS_DIR}/dev/pts" || true
    umount -lf "${ROOTFS_DIR}/dev" || true

    # Clean temporary files from rootfs
    rm -f "${ROOTFS_DIR}/tmp/packages.list" "${ROOTFS_DIR}/tmp/chroot_customize.sh"

    success "Phase 2: Chroot customization completed."
}

stage_squashfs() {
    info "Phase 3: Creating live filesystem squashfs..."
    mkdir -p "${ISO_DIR}/casper"

    # Remove existing squashfs image to ensure fresh non-appended filesystem
    rm -f "${ISO_DIR}/casper/filesystem.squashfs"

    # Extract kernel and initrd from rootfs for ISO bootloader
    local kernel_file=$(ls -1 "${ROOTFS_DIR}/boot/vmlinuz-"* 2>/dev/null | tail -n 1 || true)
    local initrd_file=$(ls -1 "${ROOTFS_DIR}/boot/initrd.img-"* 2>/dev/null | tail -n 1 || true)

    if [ -n "$kernel_file" ] && [ -n "$initrd_file" ]; then
        cp "$kernel_file" "${ISO_DIR}/casper/vmlinuz"
        cp "$initrd_file" "${ISO_DIR}/casper/initrd"
        info "Copied vmlinuz and initrd to ISO boot directory."
    else
        warn "vmlinuz/initrd not found in rootfs /boot. Ensuring kernel package in packages.list."
    fi

    # Compress rootfs into fresh squashfs
    info "Running mksquashfs with -noappend..."
    mksquashfs "${ROOTFS_DIR}" "${ISO_DIR}/casper/filesystem.squashfs" \
        -noappend -e boot -wildcards

    success "Phase 3: Squashfs creation completed."
}

stage_iso() {
    info "Phase 4: Packaging bootable Circulous ISO using grub-mkrescue..."
    
    mkdir -p "${ISO_DIR}/boot/grub" "${OUTPUT_DIR}"

    # Create GRUB configuration for Circulous Live ISO
    cat << 'GRUB_CFG' > "${ISO_DIR}/boot/grub/grub.cfg"
set default=0
set timeout=5

insmod gzio
insmod part_msdos
insmod ext2

menuentry "Boot Circulous 1.0 (Live)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "Boot Circulous 1.0 (Safe Graphics)" {
    linux /casper/vmlinuz boot=casper nomodeset ---
    initrd /casper/initrd
}
GRUB_CFG

    # Generate bootable hybrid BIOS/UEFI ISO using grub-mkrescue
    local target_iso="${OUTPUT_DIR}/${ISO_NAME}"
    info "Generating bootable hybrid ISO image at ${target_iso}..."

    grub-mkrescue -o "${target_iso}" "${ISO_DIR}" -- -volid "${VOLUME_LABEL}"

    success "Phase 4: Circulous ISO built successfully!"
    info "Output location: ${target_iso}"
}

usage() {
    echo "Circulous Distribution ISO Builder"
    echo "Usage: sudo $0 [OPTION...]"
    echo ""
    echo "Options:"
    echo "  --clean       Clean previous build artifacts"
    echo "  --bootstrap   Run debootstrap base system fetch"
    echo "  --chroot      Customize rootfs inside chroot"
    echo "  --squashfs    Compress rootfs into filesystem.squashfs"
    echo "  --iso         Package final bootable ISO"
    echo "  --all         Execute full end-to-end build (default)"
    echo "  --help        Display this help message"
}

main() {
    if [ "$#" -eq 0 ]; then
        set -- "--all"
    fi

    for arg in "$@"; do
        case "$arg" in
            --clean)
                check_root
                clean_build
                ;;
            --bootstrap)
                check_root
                check_dependencies
                mkdir -p "${BUILD_DIR}" "${ROOTFS_DIR}"
                stage_bootstrap
                ;;
            --chroot)
                check_root
                stage_chroot
                ;;
            --squashfs)
                check_root
                check_dependencies
                stage_squashfs
                ;;
            --iso)
                check_root
                check_dependencies
                stage_iso
                ;;
            --all)
                check_root
                check_dependencies
                clean_build
                stage_bootstrap
                stage_chroot
                stage_squashfs
                stage_iso
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $arg. Use --help for available options."
                ;;
        esac
    done
}

main "$@"
