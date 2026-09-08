#!/usr/bin/env bash
# Circulous Chroot Customization Script
set -e

export DEBIAN_FRONTEND=noninteractive
export HOME=/root

echo "==> [Circulous Chroot] Initializing environment..."

# Configure APT sources to include universe, restricted, and multiverse
echo "==> [Circulous Chroot] Configuring APT repositories (main, universe, restricted, multiverse)..."
cat << 'SOURCES' > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu resolute main universe restricted multiverse
deb http://archive.ubuntu.com/ubuntu resolute-updates main universe restricted multiverse
deb http://archive.ubuntu.com/ubuntu resolute-security main universe restricted multiverse
SOURCES

# Configure hostname & hosts
echo "circulous" > /etc/hostname

# Update APT cache with universe repositories
echo "==> [Circulous Chroot] Updating APT package lists..."
apt-get update

# Update system locale & timezone
echo "==> [Circulous Chroot] Setting up locale and timezone..."
apt-get install -y --no-install-recommends locales tzdata
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Install package manifest
if [ -f /tmp/packages.list ]; then
    echo "==> [Circulous Chroot] Installing packages from manifest..."
    # Filter out empty lines and comments
    PACKAGES=$(grep -v '^#' /tmp/packages.list | grep -v '^$' | tr '\n' ' ')
    apt-get install -y $PACKAGES
fi

# Ensure required system groups exist
echo "==> [Circulous Chroot] Creating system groups..."
for grp in sudo audio video netdev plugdev input; do
    getent group "$grp" >/dev/null || groupadd -f "$grp"
done

# Create default live user (circulous) with passwordless sudo
echo "==> [Circulous Chroot] Creating live user 'circulous'..."
if ! id "circulous" &>/dev/null; then
    useradd -m -s /bin/bash circulous
fi

# Add circulous to system groups
usermod -aG sudo,audio,video,netdev,plugdev circulous || true

# Set password for circulous user (password: circulous)
echo "circulous:circulous" | chpasswd || passwd -d circulous

# Grant passwordless sudo privilege
mkdir -p /etc/sudoers.d
echo "circulous ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/circulous
chmod 0440 /etc/sudoers.d/circulous

# Copy default skel to live user home directory
if [ -d /etc/skel ]; then
    cp -a /etc/skel/. /home/circulous/
    chown -R circulous:circulous /home/circulous/
fi

# Clean apt cache and temp files to reduce ISO size
echo "==> [Circulous Chroot] Cleaning up temporary files..."
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

echo "==> [Circulous Chroot] Customization completed successfully."
