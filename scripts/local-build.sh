#!/bin/bash
set -e

# Default env vars if not set
export OPENWRT_VERSION="${1:-snapshot}"
export TARGET="${2:-bcm27xx/bcm2712}"

# 1. Setup SDK (Download/Extract)
# Note: we are currently in /home/builder, and setup_sdk.sh is in scripts/
./scripts/setup_sdk.sh

# Move into SDK to run the rest
cd sdk

# 2. Update Feeds
../scripts/update_feeds.sh

# 3. Upgrade Golang
../scripts/update_golang.sh

# 4. Update Versions
# Note: Local builds might fail strictly if GH_TOKEN is missing or rate limited,
# but the script handles it gracefully (warns and proceeds).
../scripts/update_versions.sh

# 5. Compile
../scripts/compile.sh

# 6. Collect Artifacts
echo "Collecting artifacts..."
mkdir -p ../output

# Detect package format (APK for 25.12+ or IPK for older versions)
if find bin/packages -name "*.apk" 2>/dev/null | grep -q .; then
  echo "Detected APK packages (OpenWrt 25.12+)"
  PKG_EXT="apk"
else
  echo "Detected IPK packages (OpenWrt 24.10 and earlier)"
  PKG_EXT="ipk"
fi

echo "Collecting .$PKG_EXT files..."
find bin/packages -name "docker*.$PKG_EXT" -exec cp {} ../output/ \; || true
find bin/packages -name "dockerd*.$PKG_EXT" -exec cp {} ../output/ \; || true
find bin/packages -name "containerd*.$PKG_EXT" -exec cp {} ../output/ \; || true
find bin/packages -name "runc*.$PKG_EXT" -exec cp {} ../output/ \; || true
find bin/packages -name "docker-compose*.$PKG_EXT" -exec cp {} ../output/ \; || true
find bin/packages -name "luci-lib-docker*.$PKG_EXT" -exec cp {} ../output/ \; || true

# List what we found
echo "Collected packages:"
ls -lh ../output/ || echo "No packages found!"

echo "Build complete! Artifacts are in output/"
