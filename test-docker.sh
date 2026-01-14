#!/bin/bash
set -e

OPENWRT_VERSION="${1:-snapshot}"
TARGET="${2:-bcm27xx/bcm2712}"

IMAGE_NAME="openwrt-docker-builder"

# Sanitize inputs for directory names
SAFE_VERSION=${OPENWRT_VERSION//\//-}
SAFE_TARGET=${TARGET//\//-}

CACHE_DIR="$(pwd)/cache"
SDK_CACHE_DIR="${CACHE_DIR}/sdk-${SAFE_VERSION}-${SAFE_TARGET}"
DL_CACHE_DIR="${CACHE_DIR}/dl"
FEEDS_CACHE_DIR="${CACHE_DIR}/feeds"
CCACHE_HOST_DIR="${CACHE_DIR}/ccache"

echo "Building Docker image..."
docker build -t $IMAGE_NAME -f Dockerfile.test .

echo "Preparing Cache..."
mkdir -p "$SDK_CACHE_DIR"
mkdir -p "$DL_CACHE_DIR"
mkdir -p "$FEEDS_CACHE_DIR"
mkdir -p "$CCACHE_HOST_DIR"

# Ensure permissions
chmod 777 "$SDK_CACHE_DIR"
chmod 777 "$DL_CACHE_DIR"
chmod 777 "$FEEDS_CACHE_DIR"
chmod 777 "$CCACHE_HOST_DIR"

echo "Running build container..."
echo "  OpenWrt Version: $OPENWRT_VERSION"
echo "  Target: $TARGET"
echo "  Cache: $CACHE_DIR"

mkdir -p output

# Run the container with mounts
docker run --rm \
    -v $(pwd)/output:/home/builder/output \
    -v "$SDK_CACHE_DIR":/home/builder/sdk \
    -v "$DL_CACHE_DIR":/home/builder/sdk/dl \
    -v "$FEEDS_CACHE_DIR":/home/builder/sdk/feeds \
    -v "$CCACHE_HOST_DIR":/home/builder/.ccache \
    -e CCACHE_DIR=/home/builder/.ccache \
    $IMAGE_NAME \
    "$OPENWRT_VERSION" "$TARGET"

echo "Done. Check output/ directory for .ipk files."
