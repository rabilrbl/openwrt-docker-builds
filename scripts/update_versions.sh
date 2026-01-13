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

update_makefile() {
    PKG_NAME=$1
    NEW_VERSION=$2
    NEW_HASH=$3
    MAKEFILE=$4
    NEW_REF=$5
    
    if [ ! -f "$MAKEFILE" ]; then
        echo "Warning: Makefile for $PKG_NAME not found at $MAKEFILE"
        return
    fi

    echo "Updating $PKG_NAME to $NEW_VERSION..."
    echo "  Hash: $NEW_HASH"
    
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$NEW_VERSION/" $MAKEFILE
    
    if grep -q "^PKG_HASH:=" $MAKEFILE; then
        sed -i "s/^PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/" $MAKEFILE
    fi
    
    if grep -q "^PKG_SOURCE_VERSION:=" $MAKEFILE; then
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
}

echo "Fetching latest versions..."

RAW_MOBY_TAG=$(get_latest_tag "moby/moby")
if [ "$RAW_MOBY_TAG" == "null" ] || [ -z "$RAW_MOBY_TAG" ]; then
    echo "Warning: specific version fetch failed. Likely API limit. Using existing versions."
    exit 0
fi

CLEAN_VERSION=$(clean_version "$RAW_MOBY_TAG")
MOBY_URL="https://codeload.github.com/moby/moby/tar.gz/$RAW_MOBY_TAG"
echo "Calculating hash for $MOBY_URL"
MOBY_HASH=$(get_tarball_hash "$MOBY_URL")

CLI_TAG="v$CLEAN_VERSION"
CLI_URL="https://codeload.github.com/docker/cli/tar.gz/$CLI_TAG"
echo "Calculating hash for $CLI_URL"
CLI_HASH=$(get_tarball_hash "$CLI_URL")

CT_VERSION="2.2.0"
CT_TAG="v$CT_VERSION"
CT_URL="https://codeload.github.com/containerd/containerd/tar.gz/$CT_TAG"
echo "Calculating hash for $CT_URL"
CT_HASH=$(get_tarball_hash "$CT_URL")

echo "Detected Versions:"
echo "  Docker/Moby: $CLEAN_VERSION ($MOBY_HASH)"
echo "  Docker CLI:  $CLEAN_VERSION ($CLI_HASH)"
echo "  Containerd:  $CT_VERSION ($CT_HASH)"

update_makefile "dockerd" "$CLEAN_VERSION" "$MOBY_HASH" "$MAKEFILE_DIR/dockerd/Makefile" "$RAW_MOBY_TAG"
update_makefile "docker" "$CLEAN_VERSION" "$CLI_HASH" "$MAKEFILE_DIR/docker/Makefile"
update_makefile "containerd" "$CT_VERSION" "$CT_HASH" "$MAKEFILE_DIR/containerd/Makefile"

# Patch containerd Makefile to remove legacy shims (removed in 2.0)
# This removes "containerd-shim,containerd-shim-runc-v1," from the install list
if [ -f "$MAKEFILE_DIR/containerd/Makefile" ]; then
    echo "Patching containerd Makefile to remove legacy shims..."
    sed -i 's/containerd-shim,containerd-shim-runc-v1,//' "$MAKEFILE_DIR/containerd/Makefile"
fi
