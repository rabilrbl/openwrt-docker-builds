#!/bin/bash
set -e

OPENWRT_VERSION="${1:-stable}"
TARGET="${2:-bcm27xx/bcm2712}"

# Resolve "stable" to the latest stable version
if [ "$OPENWRT_VERSION" = "stable" ]; then
    echo "Resolving latest stable OpenWrt version..."
    OPENWRT_VERSION=$(curl -s https://downloads.openwrt.org/releases/ | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/)' | sort -V | tail -1)
    if [ -z "$OPENWRT_VERSION" ]; then
        echo "Error: Could not resolve latest stable version"
        exit 1
    fi
    echo "Resolved to: $OPENWRT_VERSION"
fi

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
    -f Dockerfile .

echo "Running build container..."
echo "  OpenWrt Version: $OPENWRT_VERSION"
echo "  Target: $TARGET"
echo "  SDK Image: openwrt/sdk:${SDK_TAG}"

mkdir -p output
chmod 777 output

docker run --rm \
    -v "$(pwd)/output":/output \
    -e GIT_SSL_NO_VERIFY=1 \
    ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
    "$IMAGE_NAME"

echo "Done. Check output/ directory for built packages."
