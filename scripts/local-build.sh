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
find bin/packages -name "docker*.ipk" -exec cp {} ../output/ \;
find bin/packages -name "dockerd*.ipk" -exec cp {} ../output/ \;
find bin/packages -name "containerd*.ipk" -exec cp {} ../output/ \;
find bin/packages -name "runc*.ipk" -exec cp {} ../output/ \;
find bin/packages -name "docker-compose*.ipk" -exec cp {} ../output/ \;
find bin/packages -name "luci-lib-docker*.ipk" -exec cp {} ../output/ \;

echo "Build complete! Artifacts are in output/"
