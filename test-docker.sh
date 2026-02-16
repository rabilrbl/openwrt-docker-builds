#!/bin/bash
set -e

OPENWRT_VERSION="${1:-snapshot}"
TARGET="${2:-bcm27xx/bcm2712}"

# Compute the SDK Docker image tag from target and version
SDK_TAG="${TARGET//\//-}"
if [ "$OPENWRT_VERSION" != "snapshot" ]; then
    SDK_TAG="${SDK_TAG}-v${OPENWRT_VERSION}"
fi

IMAGE_NAME="openwrt-docker-builder"

echo "Building Docker image using openwrt/sdk:${SDK_TAG} as base..."
docker build \
    --build-arg SDK_TAG="${SDK_TAG}" \
    -t "$IMAGE_NAME" \
    -f Dockerfile.test .

echo "Running build container..."
echo "  OpenWrt Version: $OPENWRT_VERSION"
echo "  Target: $TARGET"
echo "  SDK Tag: $SDK_TAG"

mkdir -p output

# Run the container with output mount
docker run --rm \
    -v "$(pwd)/output":/output \
    "$IMAGE_NAME"

echo "Done. Check output/ directory for built packages."
