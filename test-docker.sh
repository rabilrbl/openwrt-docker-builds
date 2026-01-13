#!/bin/bash
set -e

OPENWRT_VERSION="${1:-snapshot}"
TARGET="${2:-bcm27xx/bcm2712}"

IMAGE_NAME="openwrt-docker-builder"

echo "Building Docker image..."
docker build -t $IMAGE_NAME -f Dockerfile.test .

echo "Running build container..."
echo "  OpenWrt Version: $OPENWRT_VERSION"
echo "  Target: $TARGET"

mkdir -p output

# Run the container
# We mount the output directory to get the artifacts out
# We DO NOT mount the SDK directory by default to ensure a clean build every time,
# but for repeated testing it might be useful.
# For this "test framework", clean state is safer.

docker run --rm \
    -v $(pwd)/output:/home/builder/output \
    $IMAGE_NAME \
    "$OPENWRT_VERSION" "$TARGET"

echo "Done. Check output/ directory for .ipk files."
