#!/usr/bin/env bash
# Circulous Chroot Customization Script
set -e

export DEBIAN_FRONTEND=noninteractive
export HOME=/root

echo "==> [Circulous Chroot] Initializing environment..."

# Prevent daemons and systemd services from attempting to start inside chroot
echo "==> [Circulous Chroot] Creating /usr/sbin/policy-rc.d (blocking daemon auto-start)..."
cat << 'POLICY' > /usr/sbin/policy-rc.d
#!/bin/sh
exit 101
POLICY
chmod +x /usr/sbin/policy-rc.d

# Configure APT sources to include main, universe, restricted, and multiverse
echo "==> [Circulous Chroot] Configuring APT repositories..."
cat << 'SOURCES' > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu resolute main universe restricted multiverse
deb http://archive.ubuntu.com/ubuntu resolute-updates main universe restricted multiverse
deb http://archive.ubuntu.com/ubuntu resolute-security main universe restricted multiverse
SOURCES

# Configure hostname & hosts
echo "circulous" > /etc/hostname

# Update APT cache
echo "==> [Circulous Chroot] Updating APT package lists..."
apt-get update

# Fix any partially installed packages from prior attempts
echo "==> [Circulous Chroot] Repairing any broken package states..."
dpkg --configure -a || true
apt-get install -y -f || true

# Update system locale & timezone
echo "==> [Circulous Chroot] Setting up locale and timezone..."
apt-get install -y --no-install-recommends locales tzdata
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Install package manifest
if [ -f /tmp/packages.list ]; then
    echo "==> [Circulous Chroot] Installing packages from manifest..."
    PACKAGES=$(grep -v '^#' /tmp/packages.list | grep -v '^$' | tr '\n' ' ')
    apt-get install -y --no-install-recommends $PACKAGES || {
        echo "==> Warning: Initial package install exited with code. Retrying with repair..."
        dpkg --configure -a || true
        apt-get install -y -f
    }
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

# Remove policy-rc.d before finalizing chroot
rm -f /usr/sbin/policy-rc.d

# Clean apt cache and temp files to reduce ISO size
echo "==> [Circulous Chroot] Cleaning up temporary files..."
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

echo "==> [Circulous Chroot] Customization completed successfully."
