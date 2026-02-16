#!/bin/bash
set -e

# When running inside the official openwrt/sdk container,
# the SDK is at /builder and may need setup.sh to be run first.

cd /builder

# 1. Setup SDK (run setup.sh if SDK is not yet extracted)
if [ ! -d "./scripts" ]; then
    echo "Running SDK setup..."
    bash ./setup.sh
fi

# Configure git and feeds
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

if [ -f "feeds.conf.default" ]; then
    sed -i 's|git.openwrt.org/feed/|github.com/openwrt/|g' feeds.conf.default
    sed -i 's|git.openwrt.org/project/|github.com/openwrt/|g' feeds.conf.default
fi

# Determine script directory (handles both CI and local Docker builds)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "/builder/build-scripts" ]; then
    SCRIPT_DIR="/builder/build-scripts"
fi

# 2. Update Feeds
bash "$SCRIPT_DIR/update_feeds.sh"

# 3. Upgrade Golang
bash "$SCRIPT_DIR/update_golang.sh"

# 4. Update Versions
bash "$SCRIPT_DIR/update_versions.sh"

# 5. Compile
bash "$SCRIPT_DIR/compile.sh"

# 6. Collect Artifacts
echo "Collecting artifacts..."
mkdir -p /output
for ext in ipk apk; do
    find bin/packages -name "docker*.$ext" -exec cp {} /output/ \;
    find bin/packages -name "dockerd*.$ext" -exec cp {} /output/ \;
    find bin/packages -name "containerd*.$ext" -exec cp {} /output/ \;
    find bin/packages -name "runc*.$ext" -exec cp {} /output/ \;
    find bin/packages -name "docker-compose*.$ext" -exec cp {} /output/ \;
    find bin/packages -name "luci-lib-docker*.$ext" -exec cp {} /output/ \;
done

echo "Build complete! Artifacts are in /output/"
