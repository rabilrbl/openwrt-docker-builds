#!/bin/bash
set -e

# Must be run from inside the SDK directory
MAKEFILE_DIR="feeds/packages/utils"
if [ ! -d "$MAKEFILE_DIR" ]; then
    echo "Error: $MAKEFILE_DIR not found. Are you in the SDK root?"
    exit 1
fi

# --- Helper Functions ---
get_latest_tag() {
    # Uses GH_TOKEN if available, otherwise unauthenticated
    local auth_header=""
    if [ -n "$GH_TOKEN" ]; then
        auth_header="-H \"Authorization: token $GH_TOKEN\""
    fi
    # Use eval to handle the quoted header string if present
    eval curl -s $auth_header "https://api.github.com/repos/$1/releases/latest" | jq -r .tag_name
}

get_tarball_hash() {
    local url="$1"
    curl -sL "$url" | sha256sum | awk '{print $1}'
}

clean_version() {
    local v=$1
    v=${v#docker-}
    v=${v#v}
    echo "$v"
}

get_commit_sha() {
    local repo="$1"
    local tag="$2"
    local auth_header=""
    if [ -n "$GH_TOKEN" ]; then
        auth_header="-H \"Authorization: token $GH_TOKEN\""
    fi
    eval curl -s $auth_header "https://api.github.com/repos/$repo/commits/$tag" | jq -r .sha
}

update_makefile() {
    PKG_NAME=$1
    NEW_VERSION=$2
    NEW_HASH=$3
    MAKEFILE=$4
    NEW_REF=$5
    NEW_COMMIT=$6
    
    if [ ! -f "$MAKEFILE" ]; then
        echo "Error: Makefile for $PKG_NAME not found at $MAKEFILE"
        return 1
    fi
    
    # Validate hash is a valid SHA256 (64 hex characters)
    if [ -z "$NEW_HASH" ] || [ "$NEW_HASH" = "x" ] || [ "$NEW_HASH" = "skip" ]; then
        echo "Error: Invalid hash for $PKG_NAME: '$NEW_HASH'"
        return 1
    fi
    
    if ! echo "$NEW_HASH" | grep -qE '^[a-f0-9]{64}$'; then
        echo "Error: Hash for $PKG_NAME is not a valid SHA256: '$NEW_HASH'"
        return 1
    fi

    echo "Updating $PKG_NAME to $NEW_VERSION..."
    echo "  Hash: $NEW_HASH"
    
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$NEW_VERSION/" $MAKEFILE
    
    if grep -q "^PKG_HASH:=" $MAKEFILE; then
        sed -i "s/^PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/" $MAKEFILE
    fi
    
    if [ -n "$NEW_COMMIT" ]; then
         if grep -q "^PKG_SOURCE_VERSION:=" $MAKEFILE; then
             sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$NEW_COMMIT/" $MAKEFILE
         fi
    elif grep -q "^PKG_SOURCE_VERSION:=" $MAKEFILE; then
         if ! grep -q "^PKG_HASH:=" $MAKEFILE; then
             sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$NEW_HASH/" $MAKEFILE
         fi
    fi
    
    sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=1/" $MAKEFILE
    
    if [ -n "$NEW_REF" ]; then
        if grep -q "^PKG_GIT_REF:=" $MAKEFILE; then
             sed -i "s|^PKG_GIT_REF:=.*|PKG_GIT_REF:=$NEW_REF|" $MAKEFILE
        fi
    fi

    if [ -n "$NEW_COMMIT" ]; then
        if grep -q "^PKG_GIT_SHORT_COMMIT:=" $MAKEFILE; then
             local short_sha=${NEW_COMMIT:0:7}
             echo "  Short Commit: $short_sha"
             sed -i "s|^PKG_GIT_SHORT_COMMIT:=.*|PKG_GIT_SHORT_COMMIT:=$short_sha|" $MAKEFILE
        fi
    fi
}

echo "Fetching latest versions..."

RAW_MOBY_TAG=$(get_latest_tag "moby/moby")
if [ "$RAW_MOBY_TAG" == "null" ] || [ -z "$RAW_MOBY_TAG" ]; then
    echo "Error: Failed to fetch latest Docker/Moby version from GitHub API."
    echo "This is likely due to GitHub API rate limits."
    echo ""
    echo "The OpenWrt feeds contain placeholder hashes (\"x\") for dockerd that must be updated."
    echo "Without valid version information, the build will fail."
    echo ""
    echo "Solutions:"
    echo "  1. Wait a few minutes and try again (rate limits reset)"
    echo "  2. Provide a GitHub token via GH_TOKEN environment variable"
    echo "  3. Manually update the Makefiles in sdk/feeds/packages/utils/"
    echo ""
    exit 1
fi

CLEAN_VERSION=$(clean_version "$RAW_MOBY_TAG")
MOBY_URL="https://codeload.github.com/moby/moby/tar.gz/$RAW_MOBY_TAG"
echo "Calculating hash for $MOBY_URL"
MOBY_HASH=$(get_tarball_hash "$MOBY_URL")

echo "Fetching commit SHA for $RAW_MOBY_TAG"
MOBY_COMMIT=$(get_commit_sha "moby/moby" "$RAW_MOBY_TAG")

CLI_TAG="v$CLEAN_VERSION"
CLI_URL="https://codeload.github.com/docker/cli/tar.gz/$CLI_TAG"
echo "Calculating hash for $CLI_URL"
CLI_HASH=$(get_tarball_hash "$CLI_URL")

echo "Fetching commit SHA for $CLI_TAG"
CLI_COMMIT=$(get_commit_sha "docker/cli" "$CLI_TAG")

CT_TAG="v2.2.0"
CT_VERSION=$(clean_version "$CT_TAG")
CT_URL="https://codeload.github.com/containerd/containerd/tar.gz/$CT_TAG"
echo "Calculating hash for $CT_URL"
CT_HASH=$(get_tarball_hash "$CT_URL")

echo "Fetching commit SHA for $CT_TAG"
CT_COMMIT=$(get_commit_sha "containerd/containerd" "$CT_TAG")

echo "Detected Versions:"
echo "  Docker/Moby: $CLEAN_VERSION ($MOBY_HASH) Commit: $MOBY_COMMIT"
echo "  Docker CLI:  $CLEAN_VERSION ($CLI_HASH) Commit: $CLI_COMMIT"
echo "  Containerd:  $CT_VERSION ($CT_HASH) Commit: $CT_COMMIT"

# Update Makefiles and check for errors
FAILED=0

update_makefile "dockerd" "$CLEAN_VERSION" "$MOBY_HASH" "$MAKEFILE_DIR/dockerd/Makefile" "$RAW_MOBY_TAG" "$MOBY_COMMIT" || FAILED=1
update_makefile "docker" "$CLEAN_VERSION" "$CLI_HASH" "$MAKEFILE_DIR/docker/Makefile" "$CLI_TAG" "$CLI_COMMIT" || FAILED=1
update_makefile "containerd" "$CT_VERSION" "$CT_HASH" "$MAKEFILE_DIR/containerd/Makefile" "$CT_TAG" "$CT_COMMIT" || FAILED=1

if [ $FAILED -eq 1 ]; then
    echo ""
    echo "Error: Failed to update one or more Makefiles"
    exit 1
fi

# Update runc to latest
RUNC_VERSION="1.3.4"
RUNC_TAG="v$RUNC_VERSION"
RUNC_URL="https://codeload.github.com/opencontainers/runc/tar.gz/$RUNC_TAG"
echo "Calculating hash for $RUNC_URL"
RUNC_HASH=$(get_tarball_hash "$RUNC_URL")
echo "Fetching commit SHA for $RUNC_TAG"
RUNC_COMMIT=$(get_commit_sha "opencontainers/runc" "$RUNC_TAG")
update_makefile "runc" "$RUNC_VERSION" "$RUNC_HASH" "$MAKEFILE_DIR/runc/Makefile" "$RUNC_TAG" "$RUNC_COMMIT" || {
    echo "Error: Failed to update runc Makefile"
    exit 1
}

# Docker Compose
# Only v2 is supported as a Go binary
COMPOSE_TAG=$(get_latest_tag "docker/compose")
if [ "$COMPOSE_TAG" != "null" ] && [ -n "$COMPOSE_TAG" ]; then
    COMPOSE_VERSION=$(clean_version "$COMPOSE_TAG")
    COMPOSE_URL="https://codeload.github.com/docker/compose/tar.gz/$COMPOSE_TAG"
    echo "Calculating hash for $COMPOSE_URL"
    COMPOSE_HASH=$(get_tarball_hash "$COMPOSE_URL")
    echo "Fetching commit SHA for $COMPOSE_TAG"
    COMPOSE_COMMIT=$(get_commit_sha "docker/compose" "$COMPOSE_TAG")
    
    echo "  Docker Compose: $COMPOSE_VERSION ($COMPOSE_HASH) Commit: $COMPOSE_COMMIT"
    update_makefile "docker-compose" "$COMPOSE_VERSION" "$COMPOSE_HASH" "$MAKEFILE_DIR/docker-compose/Makefile" "$COMPOSE_TAG" "$COMPOSE_COMMIT" || {
        echo "Error: Failed to update docker-compose Makefile"
        exit 1
    }

    # Fix Go package path for v5+
    if [[ "$COMPOSE_VERSION" == 5.* ]]; then
        echo "  Updating Go package path to v5..."
        sed -i "s|github.com/docker/compose/v2|github.com/docker/compose/v5|g" "$MAKEFILE_DIR/docker-compose/Makefile"
    fi
fi

# Patch containerd Makefile to remove legacy shims (removed in 2.0)
# This removes "containerd-shim,containerd-shim-runc-v1," from the install list
if [ -f "$MAKEFILE_DIR/containerd/Makefile" ]; then
    echo "Patching containerd Makefile to remove legacy shims..."
    sed -i 's/containerd-shim,containerd-shim-runc-v1,//' "$MAKEFILE_DIR/containerd/Makefile"
fi

# Patch docker Makefile to find the correct binary (go build output path varies)
if [ -f "$MAKEFILE_DIR/docker/Makefile" ]; then
    echo "Patching docker Makefile to fix binary installation path..."
    # Replace the fixed path with a find command to locate the binary (e.g. docker-linux-arm64)
    # The original line looks like: $(INSTALL_BIN) $(PKG_BUILD_DIR)/build/docker $(1)/usr/bin/
    # We replace it with: find $(PKG_BUILD_DIR) -name "docker-linux-*" -type f -exec $(INSTALL_BIN) {} $(1)/usr/bin/docker \;
    # effectively ignoring the specific path structure.
    sed -i 's|\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/build/docker \$(1)/usr/bin/|find $(PKG_BUILD_DIR) -name "docker-linux-*" -type f -exec $(INSTALL_BIN) {} $(1)/usr/bin/docker \\;|' "$MAKEFILE_DIR/docker/Makefile"
fi

# Patch dockerd Makefile to add kmod-ipt-raw dependency (needed for Docker networking)
if [ -f "$MAKEFILE_DIR/dockerd/Makefile" ]; then
    echo "Patching dockerd Makefile to add kmod-ipt-raw dependency..."
    if ! grep -q "kmod-ipt-raw" "$MAKEFILE_DIR/dockerd/Makefile"; then
        sed -i '/+iptables \\/a \    +kmod-ipt-raw \\' "$MAKEFILE_DIR/dockerd/Makefile"
    fi
fi
