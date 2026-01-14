#!/bin/bash
set -e

# Usage: ./scripts/setup_sdk.sh [mode]
# mode:
#   resolve - Only resolve URL/Filename and output to GITHUB_OUTPUT (if present) or stdout
#   setup   - (Default) Download and extract SDK

MODE="${1:-setup}"

OPENWRT_VERSION="${OPENWRT_VERSION:-snapshot}"
TARGET="${TARGET:-bcm27xx/bcm2712}"

# --- Resolve SDK URL ---
if [ "$OPENWRT_VERSION" == "snapshot" ]; then
  BASE_URL="https://downloads.openwrt.org/snapshots/targets/${TARGET}/"
else
  BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/"
fi

echo "Resolving SDK from $BASE_URL..." >&2
SDK_FILE=$(curl -sL --retry 3 "$BASE_URL" | grep -o 'href="openwrt-sdk-[^"]*Linux-x86_64.tar\.[a-z]*"' | cut -d'"' -f2 | head -n 1 || true)

if [ -z "$SDK_FILE" ]; then
  echo "Error: Could not find SDK file at $BASE_URL" >&2
  exit 1
fi

SDK_URL="${BASE_URL}${SDK_FILE}"
echo "Found SDK: $SDK_FILE" >&2

if [ "$MODE" == "resolve" ]; then
  # If running in GitHub Actions, write to output
  if [ -n "$GITHUB_OUTPUT" ]; then
    echo "url=${SDK_URL}" >> "$GITHUB_OUTPUT"
    echo "filename=${SDK_FILE}" >> "$GITHUB_OUTPUT"
  else
    # Otherwise just print variables for sourcing
    echo "export SDK_URL='${SDK_URL}'"
    echo "export SDK_FILE='${SDK_FILE}'"
  fi
  exit 0
fi

# --- Setup SDK ---
# Check if SDK is already populated (e.g. from cache)
# We check for a key file like 'rules.mk'
if [ ! -f "sdk/rules.mk" ]; then
    echo "Downloading SDK..."
    
    # Clean up potentially empty directory from mount, but PRESERVE dl and feeds if they exist
    # If sdk dir exists, clean it carefully
    if [ -d "sdk" ]; then
        find sdk -mindepth 1 -maxdepth 1 -not -name 'dl' -not -name 'feeds' -exec rm -rf {} +
    else
        mkdir -p sdk
    fi
    
    wget -q --show-progress -O sdk.archive "$SDK_URL"
    echo "Extracting SDK..."
    tar -I zstd -xf sdk.archive -C sdk --strip-components=1
    rm sdk.archive
else
    echo "SDK found (cached), skipping download."
fi

cd sdk

# Configure feeds
if [ -f "feeds.conf.default" ]; then
    if ! grep -q "# option check_signature" feeds.conf.default; then
        sed -i 's/option check_signature/# option check_signature/' feeds.conf.default
    fi
    # Use GitHub mirrors
    sed -i 's|git.openwrt.org/feed/|github.com/openwrt/|g' feeds.conf.default
    sed -i 's|git.openwrt.org/project/|github.com/openwrt/|g' feeds.conf.default
fi

# Git config for large repos (often needed for feeds)
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999
