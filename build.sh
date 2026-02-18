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

# Check if buildx is available for caching support
if docker buildx version >/dev/null 2>&1; then
    echo "Using Docker buildx with cache support..."
    docker buildx build \
        --build-arg SDK_TAG="${SDK_TAG}" \
        --cache-from=type=local,src=/tmp/.buildx-cache \
        --cache-to=type=local,dest=/tmp/.buildx-cache-new,mode=max \
        --load \
        -t "$IMAGE_NAME" \
        -f Dockerfile .

    # Move cache to avoid growing cache size indefinitely
    if [ -d /tmp/.buildx-cache-new ]; then
        rm -rf /tmp/.buildx-cache
        mv /tmp/.buildx-cache-new /tmp/.buildx-cache
    fi
else
    echo "Docker buildx not available, using standard build..."
    docker build \
        --build-arg SDK_TAG="${SDK_TAG}" \
        -t "$IMAGE_NAME" \
        -f Dockerfile .
fi

echo "Running build container..."
echo "  OpenWrt Version: $OPENWRT_VERSION"
echo "  Target: $TARGET"
echo "  SDK Image: openwrt/sdk:${SDK_TAG}"

mkdir -p output
chmod 777 output

# Prepare SDK cache directories
mkdir -p sdk-cache/dl sdk-cache/staging_dir sdk-cache/build_dir
chmod -R 777 sdk-cache

docker run --rm \
    -v "$(pwd)/output":/output \
    -v "$(pwd)/sdk-cache/dl":/builder/dl \
    -v "$(pwd)/sdk-cache/staging_dir":/builder/staging_dir \
    -v "$(pwd)/sdk-cache/build_dir":/builder/build_dir \
    -e GIT_SSL_NO_VERIFY=1 \
    ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
    "$IMAGE_NAME"

echo "Done. Check output/ directory for built packages."
