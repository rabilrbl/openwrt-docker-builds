# Testing OpenWrt Docker Builds Locally

This repository includes a test framework to simulate the GitHub Actions build process in a local Docker container. This ensures that your changes will work in the CI environment.

## Prerequisites

- Docker installed on your machine.

## How to Run

Use the `test-docker.sh` script to trigger a build.

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

1. **Image Build**: A Docker image (`openwrt-docker-builder`) is built using `Dockerfile.test`. This image mimics the Ubuntu environment used in GitHub Actions and installs all necessary dependencies.
2. **Container Run**: The container starts and executes `scripts/local-build.sh`.
3. **Build Process**:
    - Downloads the OpenWrt SDK for the specified target.
    - Updates feeds.
    - Upgrades Golang (if needed).
    - Fetches the latest Docker/Containerd versions from GitHub.
    - Compiles the packages.
4. **Artifacts**: The compiled `.ipk` files are copied to the `output/` directory on your host machine.

## Troubleshooting

- **Build Failures**: Check the console output. It mirrors the logs you would see in GitHub Actions.
- **SDK Errors**: If the SDK download fails, check if the `OPENWRT_VERSION` and `TARGET` combination is valid on [downloads.openwrt.org](https://downloads.openwrt.org).
