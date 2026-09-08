#!/usr/bin/env bash
# Circulous Chroot Customization Script
set -e

export DEBIAN_FRONTEND=noninteractive
export HOME=/root

echo "==> [Circulous Chroot] Initializing environment..."

# Configure hostname & hosts
echo "circulous" > /etc/hostname

# Update system locale & timezone
echo "==> [Circulous Chroot] Setting up locale and timezone..."
apt-get update
apt-get install -y --no-install-recommends locales tzdata
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Install package manifest
if [ -f /tmp/packages.list ]; then
    echo "==> [Circulous Chroot] Installing packages from manifest..."
    # Filter out empty lines and comments
    PACKAGES=$(grep -v '^#' /tmp/packages.list | grep -v '^$' | tr '\n' ' ')
    apt-get install -y $PACKAGES || true
fi

# Create default live user (circulous) with sudo privileges
echo "==> [Circulous Chroot] Creating live user 'circulous'..."
if ! id "circulous" &>/dev/null; then
    useradd -m -s /bin/bash -g sudo -G audio,video,netdev,plugdev circulous || true
    echo "circulous:circulous" | chpasswd
    echo "circulous ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/circulous
    chmod 0440 /etc/sudoers.d/circulous
fi

# Copy default skel to live user home directory
cp -r /etc/skel/. /home/circulous/
chown -R circulous:circulous /home/circulous/

# Clean apt cache and temp files to reduce ISO size
echo "==> [Circulous Chroot] Cleaning up temporary files..."
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

echo "==> [Circulous Chroot] Customization completed successfully."
