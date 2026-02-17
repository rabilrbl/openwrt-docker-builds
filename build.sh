#!/bin/bash
set -e

DEFAULT_OPENWRT_VERSION="stable"
STABLE_FALLBACK_VERSION="24.10.0"
OPENWRT_VERSION_INPUT="${1:-$DEFAULT_OPENWRT_VERSION}"
TARGET="${2:-bcm27xx/bcm2712}"

resolve_latest_stable() {
    curl -fsSL https://downloads.openwrt.org/releases/ \
      | grep -o 'href="[0-9][^"]*"' \
      | sed 's/href="//;s/"//' \
      | sed 's:/$::' \
      | grep -E '^[0-9]+\\.[0-9]+\\.[0-9]+$' \
      | sort -V \
      | tail -n1
}

OPENWRT_VERSION="$OPENWRT_VERSION_INPUT"
if [ "$OPENWRT_VERSION_INPUT" = "stable" ]; then
    LATEST_STABLE="$(resolve_latest_stable || true)"
    if [ -n "$LATEST_STABLE" ]; then
        OPENWRT_VERSION="$LATEST_STABLE"
        echo "Resolved latest stable OpenWrt version: $OPENWRT_VERSION"
    else
        OPENWRT_VERSION="$STABLE_FALLBACK_VERSION"
        echo "Could not resolve latest stable version; falling back to $OPENWRT_VERSION" >&2
    fi
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
