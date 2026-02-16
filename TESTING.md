# Testing OpenWrt Docker Builds Locally

This repository uses the [official OpenWrt SDK Docker image](https://hub.docker.com/r/openwrt/sdk) (`openwrt/sdk`) to build packages. The test framework wraps this image with build scripts for local testing.

## Prerequisites

- Docker installed on your machine.

## How to Run

Use the `test-docker.sh` script to trigger a build:

```bash
./test-docker.sh [OPENWRT_VERSION] [TARGET]
```

### Examples

**Build for Raspberry Pi 5 (Default):**
```bash
./test-docker.sh
```

**Build for Raspberry Pi 4:**
```bash
./test-docker.sh snapshot bcm27xx/bcm2711
```

**Build for a specific OpenWrt version:**
```bash
./test-docker.sh 23.05.3 x86/64
```

## What Happens

1. **Image Build**: A Docker image (`openwrt-docker-builder`) is built using `Dockerfile.test`, which extends the official `openwrt/sdk` image for the specified target architecture.
2. **Container Run**: The container starts and executes `scripts/local-build.sh`.
3. **Build Process**:
    - Runs the SDK's `setup.sh` to initialize the environment (if needed).
    - Updates feeds and upgrades Golang.
    - Fetches the latest Docker/Containerd versions from GitHub.
    - Compiles the packages.
4. **Artifacts**: The compiled packages (`.ipk` or `.apk` files) are copied to the `output/` directory on your host machine.

## SDK Docker Image Tags

The official `openwrt/sdk` image uses tags in the format:
- `<target>-<subtarget>` for snapshots (e.g., `bcm27xx-bcm2712`)
- `<target>-<subtarget>-v<version>` for releases (e.g., `bcm27xx-bcm2712-v24.10.0`)

## Troubleshooting

- **Build Failures**: Check the console output. It mirrors the logs you would see in GitHub Actions.
- **Image Pull Errors**: Ensure the `OPENWRT_VERSION` and `TARGET` combination has a corresponding SDK image on [Docker Hub](https://hub.docker.com/r/openwrt/sdk/tags).
