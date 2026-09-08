# Circulous

**Circulous** is a modern, lightweight Ubuntu-based Linux distribution built from the ground up using custom bootstrap, chroot customization, live squashfs compression, and dual EFI/BIOS bootloader generation.

---

## 💡 How Distro Building Works (Architecture Overview)

Building an Ubuntu-based Linux distribution does **not** involve cloning Ubuntu's source code repositories. Instead, Linux distributions consist of thousands of modular software packages (`.deb`) hosted on APT mirrors.

### The 4-Step Circulous Build Pipeline

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ 1. Debootstrap  │ ────> │ 2. Custom Chroot│ ────> │  3. SquashFS    │ ────> │ 4. Bootable ISO │
│ Base Rootfs     │       │ Package/Theme   │       │ Compression     │       │ Generation      │
└─────────────────┘       └─────────────────┘       └─────────────────┘       └─────────────────┘
```

1. **Bootstrap (`debootstrap`)**: Fetches a clean, minimal Ubuntu base root filesystem (core system libraries, bash, systemd, apt) directly from Ubuntu mirrors.
2. **Chroot Customization (`chroot`)**: Enters the isolated rootfs environment to install chosen desktop components (LXQt, Calamares installer, system drivers) and apply custom configurations (`/etc/os-release`, branding, themes).
3. **Squashfs Compression (`mksquashfs`)**: Compresses the entire customized root filesystem into a single read-only `filesystem.squashfs` file.
4. **ISO Packaging (`xorriso` & GRUB)**: Bundles the Linux kernel (`vmlinuz`), initial RAM disk (`initrd`), GRUB bootloaders, and `filesystem.squashfs` into a bootable ISO image.

---

## 📁 Repository Structure

```
.
├── build.sh                 # Master ISO build runner script
├── run-qemu.sh              # ISO testing script with QEMU/KVM acceleration
├── config/
│   ├── build.conf           # System metadata, release codename & paths
│   └── packages.list        # Base package manifest for live system
├── overlay/                 # Filesystem overlay copied directly into rootfs
│   └── etc/
│       ├── os-release       # Distribution identity file (NAME="Circulous")
│       ├── issue            # Login terminal banner
│       ├── hostname         # Default live session hostname
│       ├── hosts            # Local domain mappings
│       └── skel/            # Default user profile templates (.bashrc, etc.)
├── scripts/
│   └── chroot_customize.sh  # Post-bootstrap setup script executed inside chroot
├── .gitignore               # Ignores build artifacts and generated ISOs
└── README.md                # Project documentation
```

---

## 🛠️ System Prerequisites

Ensure your host system has the necessary build dependencies installed:

```bash
sudo apt update
sudo apt install -y debootstrap xorriso squashfs-tools qemu-system-x86 qemu-kvm
```

Verify KVM hardware acceleration support:

```bash
kvm-ok
```

---

## 🚀 Building the Circulous ISO

To run the complete end-to-end build pipeline:

```bash
sudo ./build.sh
```

### Build Options

You can also run specific phases of the build:

```bash
sudo ./build.sh --clean       # Clean previous build directories
sudo ./build.sh --bootstrap   # Fetch base Ubuntu system
sudo ./build.sh --chroot      # Apply overlay and run customization script
sudo ./build.sh --squashfs    # Compress rootfs into squashfs
sudo ./build.sh --iso         # Generate final ISO package
```

The compiled ISO will be saved at:
`out/Circulous-1.0-alpha-amd64.iso`

---

## 🖥️ Testing in QEMU/KVM

Once built, launch and test Circulous instantly using the provided QEMU test harness:

```bash
./run-qemu.sh
```

### QEMU Options

```bash
./run-qemu.sh --ram 4G --cpu 4    # Custom RAM and CPU thread allocation
./run-qemu.sh path/to/custom.iso # Test a specific ISO image
```

---

## 🎨 Customizing Circulous

- **Packages**: Edit `config/packages.list` to add or remove software packages.
- **Branding & Identity**: Modify `overlay/etc/os-release` and `config/build.conf`.
- **User Environment**: Customize default desktop files, wallpapers, or terminal prompts in `overlay/etc/skel/`.
- **System Services**: Add initialization logic in `scripts/chroot_customize.sh`.

---

## 📤 Git Repository Integration

To commit your starter template and push to your remote repository:

```bash
git add .
git commit -m "Initial commit: Circulous distribution starter template and build pipeline"
git push -u origin main
```

---

## 📄 License

Circulous Distribution Project. Distributed under open-source software terms.
