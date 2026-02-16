#!/bin/bash
set -e

# This script is no longer the primary SDK setup mechanism.
# The build now uses the official openwrt/sdk Docker image which provides
# the SDK environment. This script is kept for backward compatibility
# and can be used to resolve SDK image tags.

# Usage: ./scripts/setup_sdk.sh [mode]
# mode:
#   resolve - Output the SDK Docker image tag

MODE="${1:-resolve}"

OPENWRT_VERSION="${OPENWRT_VERSION:-snapshot}"
TARGET="${TARGET:-bcm27xx/bcm2712}"

# Compute SDK Docker image tag
SDK_TAG="${TARGET//\//-}"
if [ "$OPENWRT_VERSION" != "snapshot" ]; then
    SDK_TAG="${SDK_TAG}-v${OPENWRT_VERSION}"
fi

SDK_IMAGE="openwrt/sdk:${SDK_TAG}"

echo "SDK Docker image: $SDK_IMAGE" >&2

if [ "$MODE" == "resolve" ]; then
  if [ -n "$GITHUB_OUTPUT" ]; then
    echo "tag=${SDK_TAG}" >> "$GITHUB_OUTPUT"
    echo "image=${SDK_IMAGE}" >> "$GITHUB_OUTPUT"
  else
    echo "export SDK_TAG='${SDK_TAG}'"
    echo "export SDK_IMAGE='${SDK_IMAGE}'"
  fi
  exit 0
fi

echo "Note: SDK setup is handled by the official openwrt/sdk Docker image." >&2
echo "Run 'docker run openwrt/sdk:${SDK_TAG}' to use the SDK." >&2
