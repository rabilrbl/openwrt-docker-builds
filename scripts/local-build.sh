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

# First, try to detect package format by searching the entire bin directory
echo "Searching for packages in bin..."
APK_COUNT=$(find bin -name "*.apk" 2>/dev/null | wc -l)
IPK_COUNT=$(find bin -name "*.ipk" 2>/dev/null | wc -l)

echo "Found $IPK_COUNT .ipk files and $APK_COUNT .apk files"

# Determine package extension
if [ "$APK_COUNT" -gt 0 ]; then
  echo "Detected APK packages (OpenWrt 25.12+)"
  PKG_EXT="apk"
else
  echo "Detected IPK packages (OpenWrt 24.10 and earlier)"
  PKG_EXT="ipk"
fi

echo "Collecting .$PKG_EXT files from bin..."
# Search in entire bin directory to handle different OpenWrt versions
find bin -name "docker*.$PKG_EXT" -exec cp {} ../output/ \; 2>/dev/null || true
find bin -name "dockerd*.$PKG_EXT" -exec cp {} ../output/ \; 2>/dev/null || true
find bin -name "containerd*.$PKG_EXT" -exec cp {} ../output/ \; 2>/dev/null || true
find bin -name "runc*.$PKG_EXT" -exec cp {} ../output/ \; 2>/dev/null || true
find bin -name "docker-compose*.$PKG_EXT" -exec cp {} ../output/ \; 2>/dev/null || true
find bin -name "luci-lib-docker*.$PKG_EXT" -exec cp {} ../output/ \; 2>/dev/null || true

# List what we found
echo ""
echo "Collected packages:"
ls -lh ../output/ 2>/dev/null || echo "No packages found!"

# Debug: show bin directory structure if no packages found
if [ -z "$(ls -A ../output/ 2>/dev/null)" ]; then
  echo ""
  echo "Warning: No packages collected. Showing bin directory structure:"
  find bin -type f \( -name "*.apk" -o -name "*.ipk" \) 2>/dev/null | head -30 || true
fi

echo "Build complete! Artifacts are in output/"
