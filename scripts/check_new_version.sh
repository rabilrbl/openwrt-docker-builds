#!/bin/bash
# Check if a new Moby version is available compared to the last build
set -e

# Helper function to make GitHub API calls with optional token
gh_curl() {
    if [ -n "$GH_TOKEN" ]; then
        curl -s -H "Authorization: token $GH_TOKEN" "$@"
    else
        curl -s "$@"
    fi
}

# Get latest Moby version from GitHub
get_latest_moby_version() {
    gh_curl "https://api.github.com/repos/moby/moby/releases/latest" \
        | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' \
        | sed -E 's/^docker-//; s/^v//'
}

# Get the latest release tag from this repository
get_last_built_version() {
    local tag=$(gh_curl "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/latest" \
        | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')

    # Handle both old format (docker-X.Y.Z-NN) and new format (X.Y.Z-target-openwrt_version)
    # Extract version from either format
    echo "$tag" | sed -E 's/^docker-//; s/-[^0-9].*//' | sed -E 's/-[0-9]+$//'
}

# Compare versions (returns 0 if $1 > $2, 1 otherwise)
version_greater() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && [ "$1" != "$2" ]
}

echo "Checking for new Moby version..."

LATEST_VERSION=$(get_latest_moby_version)
if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
    echo "Error: Could not fetch latest Moby version"
    exit 1
fi
echo "Latest Moby version: $LATEST_VERSION"

LAST_BUILT=$(get_last_built_version)
if [ -z "$LAST_BUILT" ] || [ "$LAST_BUILT" = "null" ]; then
    echo "No previous builds found. Will build new version."
    echo "BUILD_NEEDED=true" >> "$GITHUB_OUTPUT"
    echo "MOBY_VERSION=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
    exit 0
fi
echo "Last built version: $LAST_BUILT"

if version_greater "$LATEST_VERSION" "$LAST_BUILT"; then
    echo "New version available! $LATEST_VERSION > $LAST_BUILT"
    echo "BUILD_NEEDED=true" >> "$GITHUB_OUTPUT"
    echo "MOBY_VERSION=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
else
    echo "No new version. $LATEST_VERSION <= $LAST_BUILT"
    echo "BUILD_NEEDED=false" >> "$GITHUB_OUTPUT"
    echo "MOBY_VERSION=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
fi
