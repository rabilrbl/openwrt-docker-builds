# OpenWrt Docker Builds

This repository provides automated builds of up-to-date Docker packages (docker, dockerd, containerd, runc) for OpenWrt routers using GitHub Actions and the [official OpenWrt SDK Docker image](https://hub.docker.com/r/openwrt/sdk).

## 🎯 Purpose

The official OpenWrt Docker packages are often outdated and lag behind the latest Docker releases. This repository automatically:

- ✅ Uses the **official OpenWrt SDK Docker image** (`openwrt/sdk`) for reproducible builds
- ✅ Fetches the **latest Docker, Dockerd, and Containerd versions** from their respective GitHub repositories
- ✅ Builds packages for your specific OpenWrt architecture
- ✅ Publishes pre-compiled packages as GitHub releases
- ✅ Runs weekly to ensure you always have access to the newest versions

## 🚀 How to Use This Repository

### Option 1: Download Pre-built Packages

**Note:** This repository only builds packages for **Raspberry Pi 5** (`bcm27xx/bcm2712`) by default. If you need packages for a different architecture, skip to **Option 2** below.

1. Visit the [Releases page](https://github.com/rabilrbl/openwrt-docker-builds/releases)
2. Download the package files for Raspberry Pi 5:
   - For **OpenWrt 25.12+ (snapshots)**: Download `.apk` files (uses APK package manager)
   - For **OpenWrt 24.10 and earlier**: Download `.ipk` files (uses OPKG package manager)
3. Transfer them to your OpenWrt router
4. Install using the appropriate package manager:
   - APK: `apk add <package>.apk`
   - OPKG: `opkg install <package>.ipk`

### Option 2: Fork and Build Your Own

This is useful if you need packages for a different architecture or want to customize the build.

#### Step 1: Fork the Repository

1. Click the **Fork** button at the top of this repository
2. This creates your own copy where you can trigger builds

#### Step 2: Enable GitHub Actions

1. Go to your forked repository
2. Click on the **Actions** tab
3. Click **"I understand my workflows, enable them"** if prompted

#### Step 3: Trigger a Build

You can trigger builds in two ways:

**Manual Trigger:**

1. Go to **Actions** → **Build Latest Docker for OpenWrt**
2. Click **Run workflow**
3. Configure your build:
   - **OpenWrt Version**: Enter `snapshot` or a specific version like `24.10.0`
   - **Target Architecture**: Enter your router's target (e.g., `bcm27xx/bcm2712`, `x86/64`, `ramips/mt7621`)
4. Click **Run workflow**

**Automatic Weekly Builds:**

The workflow automatically runs every Friday at midnight (UTC) with default settings:
- OpenWrt Version: `snapshot`
- Target: `bcm27xx/bcm2712` (Raspberry Pi 5)

You can edit `.github/workflows/build.yml` to change the default architecture or schedule.

#### Step 4: Download Your Built Packages

1. Wait for the workflow to complete (typically 20-40 minutes)
2. Go to **Releases** in your forked repository
3. Download the `.ipk` files from the latest release

## 📦 Supported Architectures

This repository can build Docker packages for **any architecture supported by OpenWrt**. Common targets include:

| Router/Device | Target Architecture | Example |
|---------------|---------------------|---------|
| Raspberry Pi 5 | `bcm27xx/bcm2712` | Default |
| Raspberry Pi 4 | `bcm27xx/bcm2711` | |
| Raspberry Pi 3 | `bcm27xx/bcm2710` | |
| x86/64 (VMs) | `x86/64` | VMware, VirtualBox |
| MediaTek MT7621 | `ramips/mt7621` | Many routers |
| Qualcomm IPQ40xx | `ipq40xx/generic` | |
| Qualcomm IPQ806x | `ipq806x/generic` | |

### How to Find Your Architecture

1. SSH into your OpenWrt router
2. Run: `cat /etc/openwrt_release | grep TARGET`
3. The output shows your target architecture, for example:
   ```
   DISTRIB_TARGET='bcm27xx/bcm2712'
   ```
4. Use this value when triggering a manual build

## 🌐 OpenWrt Versions

You can build packages for:

- **`snapshot`**: The latest development version (25.12+, uses APK package manager)
- **Stable releases**: e.g., `24.10.0`, `23.05.3`, `23.05.2`, etc. (use OPKG package manager)

**Important:** OpenWrt 25.12 and newer snapshots use the **APK** (Alpine Package Keeper) package manager instead of OPKG. This repository automatically detects and builds the appropriate package format (`.apk` or `.ipk`) based on the version you select.

To find available versions:
- Visit https://downloads.openwrt.org/releases/
- Use the version number (e.g., `24.10.0`) when triggering builds

## 📥 Installation on OpenWrt

### For OpenWrt 24.10 and earlier (OPKG/.ipk packages):

1. **Transfer packages to your router:**
   ```bash
   scp *.ipk root@192.168.1.1:/tmp/
   ```

2. **SSH into your router:**
   ```bash
   ssh root@192.168.1.1
   ```

3. **Install the packages:**
   ```bash
   cd /tmp
   opkg update
   opkg install containerd*.ipk
   opkg install runc*.ipk
   opkg install dockerd*.ipk
   opkg install docker*.ipk
   ```

4. **Start Docker:**
   ```bash
   /etc/init.d/dockerd start
   /etc/init.d/dockerd enable
   ```

5. **Verify installation:**
   ```bash
   docker version
   docker run hello-world
   ```

### For OpenWrt 25.12+ snapshots (APK/.apk packages):

1. **Transfer packages to your router:**
   ```bash
   scp *.apk root@192.168.1.1:/tmp/
   ```

2. **SSH into your router:**
   ```bash
   ssh root@192.168.1.1
   ```

3. **Install the packages:**
   ```bash
   cd /tmp
   apk add containerd*.apk
   apk add runc*.apk
   apk add dockerd*.apk
   apk add docker*.apk
   ```

4. **Start Docker:**
   ```bash
   /etc/init.d/dockerd start
   /etc/init.d/dockerd enable
   ```

5. **Verify installation:**
   ```bash
   docker version
   docker run hello-world
   ```

## 🔧 What Gets Built

The workflow builds the following packages:

- **docker** - Docker CLI client
- **dockerd** - Docker daemon (engine)
- **containerd** - Container runtime
- **runc** - Low-level container runtime

All versions are automatically fetched from the latest GitHub releases of:
- [moby/moby](https://github.com/moby/moby) (Docker engine)
- [docker/cli](https://github.com/docker/cli) (Docker CLI)
- [containerd/containerd](https://github.com/containerd/containerd) (Containerd)

## 🛠️ How It Works

This repository uses the [official OpenWrt SDK Docker image](https://github.com/openwrt/docker) (`openwrt/sdk`) following the standard SDK workflow:

```bash
docker run --rm -v "$(pwd)"/bin/:/builder/bin openwrt/sdk
# inside the Docker container
[ ! -d ./scripts ] && ./setup.sh
./scripts/feeds update packages
make defconfig
./scripts/feeds install <package>
make package/<package>/{clean,compile} -j$(nproc)
```

The only addition is `scripts/update_versions.sh` which fetches the latest Docker, Containerd, and Runc versions from GitHub and patches the OpenWrt package Makefiles before compilation.

## ⚠️ Troubleshooting

### Build Fails

- Verify your architecture is correct by checking `/etc/openwrt_release` on your router
- Some older OpenWrt versions may not be compatible with the latest Docker versions
- Check the Actions logs for specific error messages

### Installation Issues

- Ensure you have enough storage space (Docker requires significant space)
- Some architectures may have missing dependencies - install them with `opkg install`
- Check that your OpenWrt version matches the packages you downloaded

## 📝 License

This repository contains build automation scripts. The actual Docker, Dockerd, and Containerd packages are governed by their respective licenses.

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report issues with specific architectures or versions
- Suggest improvements to the build workflow
- Submit pull requests

## 🔗 Related Links

- [OpenWrt Official Site](https://openwrt.org/)
- [OpenWrt Docker Documentation](https://openwrt.org/docs/guide-user/virtualization/docker_host)
- [Docker Official Documentation](https://docs.docker.com/)
