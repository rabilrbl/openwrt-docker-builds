# Testing OpenWrt Docker Builds Locally

This repository uses the [official OpenWrt SDK Docker image](https://hub.docker.com/r/openwrt/sdk) (`openwrt/sdk`) following the standard SDK workflow documented at https://github.com/openwrt/docker.

## Prerequisites

- Docker installed on your machine.

## How to Run

```bash
./build.sh [OPENWRT_VERSION] [TARGET]
```

### Examples

**Build for Raspberry Pi 5 (Default, latest stable):**
```bash
./build.sh
```

**Build for Raspberry Pi 4:**
```bash
./build.sh snapshot bcm27xx/bcm2711
```

**Build for a specific OpenWrt version:**
```bash
./build.sh 23.05.3 x86/64
```

## What Happens

1. Builds a Docker image extending `openwrt/sdk:<target-tag>`.
2. Runs the official SDK setup (`setup.sh`), updates feeds, installs packages, and compiles — following the exact pattern from the [official SDK docs](https://github.com/openwrt/docker#sdk-example).
3. Built packages (`.ipk` or `.apk`) are copied to `output/` on the host.

## SDK Docker Image Tags

The official `openwrt/sdk` image uses tags in the format:
- `<target>-<subtarget>` for snapshots (e.g., `bcm27xx-bcm2712`)
- `<target>-<subtarget>-v<version>` for releases (e.g., `bcm27xx-bcm2712-v24.10.0`)

## Troubleshooting

- **Build Failures**: Check the console output for error messages.
- **Image Pull Errors**: Ensure the target/version combination has a corresponding SDK image on [Docker Hub](https://hub.docker.com/r/openwrt/sdk/tags).
