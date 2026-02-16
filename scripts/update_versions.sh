#!/bin/bash
set -e

# Must be run from inside the SDK directory (/builder)
MAKEFILE_DIR="feeds/packages/utils"
GOLANG_DIR="feeds/packages/lang/golang"
if [ ! -d "$MAKEFILE_DIR" ]; then
    echo "Error: $MAKEFILE_DIR not found. Are you in the SDK root?"
    exit 1
fi

# --- Helper Functions ---

gh_curl() {
    if [ -n "$GH_TOKEN" ]; then
        curl -s -H "Authorization: token $GH_TOKEN" "$@"
    else
        curl -s "$@"
    fi
}

get_latest_tag() {
    gh_curl "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

get_tarball_hash() {
    curl -sL "$1" | sha256sum | awk '{print $1}'
}

clean_version() {
    local v=$1
    v=${v#docker-}
    v=${v#v}
    echo "$v"
}

get_commit_sha() {
    gh_curl "https://api.github.com/repos/$1/commits/$2" \
        | grep '"sha"' | head -1 | sed -E 's/.*"sha": *"([^"]+)".*/\1/'
}

# Read the "go X.Y.Z" directive from a repo's go.mod
get_go_version_from_repo() {
    local repo="$1" tag="$2"
    curl -sL "https://raw.githubusercontent.com/$repo/$tag/go.mod" \
        | grep -m1 '^go ' | awk '{print $2}'
}

# Extract major.minor from a version like 1.24.3 → 1.24
go_major_minor() {
    echo "$1" | grep -oE '^[0-9]+\.[0-9]+'
}

# Return 0 if $1 >= $2 using version sort
version_ge() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

update_makefile() {
    local PKG_NAME=$1 NEW_VERSION=$2 NEW_HASH=$3 MAKEFILE=$4 NEW_REF=$5 NEW_COMMIT=$6

    if [ ! -f "$MAKEFILE" ]; then
        echo "Warning: Makefile for $PKG_NAME not found at $MAKEFILE"
        return
    fi

    echo "Updating $PKG_NAME to $NEW_VERSION..."
    echo "  Hash: $NEW_HASH"

    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$NEW_VERSION/" "$MAKEFILE"

    if grep -q "^PKG_HASH:=" "$MAKEFILE"; then
        sed -i "s/^PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/" "$MAKEFILE"
    fi

    if [ -n "$NEW_COMMIT" ]; then
        if grep -q "^PKG_SOURCE_VERSION:=" "$MAKEFILE"; then
            sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$NEW_COMMIT/" "$MAKEFILE"
        fi
    elif grep -q "^PKG_SOURCE_VERSION:=" "$MAKEFILE"; then
        if ! grep -q "^PKG_HASH:=" "$MAKEFILE"; then
            sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$NEW_HASH/" "$MAKEFILE"
        fi
    fi

    sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=1/" "$MAKEFILE"

    if [ -n "$NEW_REF" ]; then
        if grep -q "^PKG_GIT_REF:=" "$MAKEFILE"; then
            sed -i "s|^PKG_GIT_REF:=.*|PKG_GIT_REF:=$NEW_REF|" "$MAKEFILE"
        fi
    fi

    if [ -n "$NEW_COMMIT" ]; then
        if grep -q "^PKG_GIT_SHORT_COMMIT:=" "$MAKEFILE"; then
            local short_sha=${NEW_COMMIT:0:7}
            echo "  Short Commit: $short_sha"
            sed -i "s|^PKG_GIT_SHORT_COMMIT:=.*|PKG_GIT_SHORT_COMMIT:=$short_sha|" "$MAKEFILE"
        fi
    fi
}

# ─── Fetch Moby/Docker version ──────────────────────────────────────────────

echo "Fetching latest versions..."

RAW_MOBY_TAG=$(get_latest_tag "moby/moby")
if [ "$RAW_MOBY_TAG" == "null" ] || [ -z "$RAW_MOBY_TAG" ]; then
    echo "Warning: Could not fetch Moby version (API rate limit?). Using existing versions."
    exit 0
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

# ─── Fetch Containerd version from Moby ──────────────────────────────────────

echo "Fetching Containerd version from Moby ($RAW_MOBY_TAG)..."
# Try legacy path (hack/dockerfile/install/containerd.installer)
CT_INSTALLER_URL="https://raw.githubusercontent.com/moby/moby/$RAW_MOBY_TAG/hack/dockerfile/install/containerd.installer"
CT_VERSION_RAW=$(curl -sL "$CT_INSTALLER_URL" | grep 'CONTAINERD_VERSION:=' | sed -E 's/.*:=([^}]+)\}.*/\1/' || true)
# Fallback: parse ARG CONTAINERD_VERSION from root Dockerfile (moby v29+)
if [ -z "$CT_VERSION_RAW" ]; then
    CT_VERSION_RAW=$(curl -sL "https://raw.githubusercontent.com/moby/moby/$RAW_MOBY_TAG/Dockerfile" \
        | grep -m1 '^ARG CONTAINERD_VERSION=' | sed -E 's/^ARG CONTAINERD_VERSION=(.*)/\1/' || true)
fi
# Final fallback: latest containerd release
if [ -z "$CT_VERSION_RAW" ]; then
    echo "  Could not determine from Moby, fetching latest containerd release..."
    CT_VERSION_RAW=$(get_latest_tag "containerd/containerd")
fi
CT_TAG="$CT_VERSION_RAW"
echo "  Containerd: $CT_TAG"

CT_VERSION=$(clean_version "$CT_TAG")
CT_URL="https://codeload.github.com/containerd/containerd/tar.gz/$CT_TAG"
echo "Calculating hash for $CT_URL"
CT_HASH=$(get_tarball_hash "$CT_URL")
echo "Fetching commit SHA for $CT_TAG"
CT_COMMIT=$(get_commit_sha "containerd/containerd" "$CT_TAG")

# ─── Fetch Runc version from Moby ───────────────────────────────────────────

echo "Fetching Runc version from Moby ($RAW_MOBY_TAG)..."
RUNC_INSTALLER_URL="https://raw.githubusercontent.com/moby/moby/$RAW_MOBY_TAG/hack/dockerfile/install/runc.installer"
RUNC_VERSION_RAW=$(curl -sL "$RUNC_INSTALLER_URL" | grep 'RUNC_VERSION:=' | sed -E 's/.*:=([^}]+)\}.*/\1/' || true)
if [ -z "$RUNC_VERSION_RAW" ]; then
    RUNC_VERSION_RAW=$(curl -sL "https://raw.githubusercontent.com/moby/moby/$RAW_MOBY_TAG/Dockerfile" \
        | grep -m1 '^ARG RUNC_VERSION=' | sed -E 's/^ARG RUNC_VERSION=(.*)/\1/' || true)
fi
if [ -z "$RUNC_VERSION_RAW" ]; then
    echo "  Could not determine from Moby, fetching latest runc release..."
    RUNC_VERSION_RAW=$(get_latest_tag "opencontainers/runc")
fi
RUNC_TAG="$RUNC_VERSION_RAW"
echo "  Runc: $RUNC_TAG"

RUNC_VERSION=$(clean_version "$RUNC_TAG")
RUNC_URL="https://codeload.github.com/opencontainers/runc/tar.gz/$RUNC_TAG"
echo "Calculating hash for $RUNC_URL"
RUNC_HASH=$(get_tarball_hash "$RUNC_URL")
echo "Fetching commit SHA for $RUNC_TAG"
RUNC_COMMIT=$(get_commit_sha "opencontainers/runc" "$RUNC_TAG")

# ─── Fetch Docker Compose version ───────────────────────────────────────────

COMPOSE_TAG=$(get_latest_tag "docker/compose")
COMPOSE_VERSION=""
if [ "$COMPOSE_TAG" != "null" ] && [ -n "$COMPOSE_TAG" ]; then
    COMPOSE_VERSION=$(clean_version "$COMPOSE_TAG")
    COMPOSE_URL="https://codeload.github.com/docker/compose/tar.gz/$COMPOSE_TAG"
    echo "Calculating hash for $COMPOSE_URL"
    COMPOSE_HASH=$(get_tarball_hash "$COMPOSE_URL")
    echo "Fetching commit SHA for $COMPOSE_TAG"
    COMPOSE_COMMIT=$(get_commit_sha "docker/compose" "$COMPOSE_TAG")
    echo "  Docker Compose: $COMPOSE_VERSION"
fi

# ─── Determine required Go version from packages ────────────────────────────

echo ""
echo "Determining required Go version from packages..."

REQUIRED_GO=""
for repo_tag in "moby/moby $RAW_MOBY_TAG" "containerd/containerd $CT_TAG" "opencontainers/runc $RUNC_TAG"; do
    repo=$(echo "$repo_tag" | awk '{print $1}')
    tag=$(echo "$repo_tag" | awk '{print $2}')
    pkg_go=$(get_go_version_from_repo "$repo" "$tag")
    if [ -n "$pkg_go" ]; then
        echo "  $repo@$tag requires Go $pkg_go"
        if [ -z "$REQUIRED_GO" ] || version_ge "$pkg_go" "$REQUIRED_GO"; then
            REQUIRED_GO="$pkg_go"
        fi
    fi
done
if [ -n "$COMPOSE_TAG" ] && [ "$COMPOSE_TAG" != "null" ]; then
    pkg_go=$(get_go_version_from_repo "docker/compose" "$COMPOSE_TAG")
    if [ -n "$pkg_go" ]; then
        echo "  docker/compose@$COMPOSE_TAG requires Go $pkg_go"
        if [ -z "$REQUIRED_GO" ] || version_ge "$pkg_go" "$REQUIRED_GO"; then
            REQUIRED_GO="$pkg_go"
        fi
    fi
fi

REQUIRED_GO_MM=$(go_major_minor "$REQUIRED_GO")
echo "  Highest required Go version: $REQUIRED_GO (major.minor: $REQUIRED_GO_MM)"

# Check SDK's current Go version
SDK_GO_DEFAULT=""
if [ -f "$GOLANG_DIR/golang-values.mk" ]; then
    SDK_GO_DEFAULT=$(grep '^GO_DEFAULT_VERSION:=' "$GOLANG_DIR/golang-values.mk" \
        | sed -E 's/^GO_DEFAULT_VERSION:=(.*)/\1/')
fi
SDK_GO_MM=$(go_major_minor "${SDK_GO_DEFAULT:-0.0}")
echo "  SDK current Go default: ${SDK_GO_DEFAULT:-unknown} (major.minor: $SDK_GO_MM)"

# Upgrade golang feed from openwrt/packages if SDK's Go is too old
upgrade_golang_feed() {
    rm -rf "$GOLANG_DIR"
    git clone --depth 1 --filter=blob:none --sparse \
        https://github.com/openwrt/packages.git /tmp/openwrt-packages
    (cd /tmp/openwrt-packages && git sparse-checkout set lang/golang)
    cp -r /tmp/openwrt-packages/lang/golang "$GOLANG_DIR"
    rm -rf /tmp/openwrt-packages
    ./scripts/feeds install -f golang
    make defconfig

    # Read full Go version from the upgraded feed Makefile
    local go_mm go_patch go_full
    go_mm=$(grep '^GO_VERSION_MAJOR_MINOR:=' "$GOLANG_DIR"/golang*/Makefile 2>/dev/null \
        | head -1 | sed 's/.*:=//')
    if [ -z "$go_mm" ]; then
        echo "  Error: Could not read GO_VERSION_MAJOR_MINOR from feed Makefile"
        return 1
    fi
    go_patch=$(grep '^GO_VERSION_PATCH:=' "$GOLANG_DIR"/golang*/Makefile 2>/dev/null \
        | head -1 | sed 's/.*:=//')
    if [ -n "$go_patch" ] && [ "$go_patch" != "0" ]; then
        go_full="${go_mm}.${go_patch}"
    else
        go_full="${go_mm}.0"
    fi

    # Detect host OS and architecture
    local host_os host_arch
    host_os=$(uname -s | tr '[:upper:]' '[:lower:]')
    host_arch=$(uname -m)
    case "$host_arch" in
        x86_64)  host_arch="amd64" ;;
        aarch64) host_arch="arm64" ;;
        armv*)   host_arch="armv6l" ;;
        *)       echo "  Error: Unsupported architecture: $host_arch"; return 1 ;;
    esac

    echo "  Downloading pre-compiled Go ${go_full} (${host_os}-${host_arch})..."
    local go_url="https://go.dev/dl/go${go_full}.${host_os}-${host_arch}.tar.gz"
    local go_root="staging_dir/hostpkg/lib/go-${go_mm}"

    # Remove old Go installation and install new one
    rm -rf "staging_dir/hostpkg/lib/go-"*
    mkdir -p "$go_root"
    curl -fSL "$go_url" | tar -xz -C "$go_root" --strip-components=1

    # Create symlinks expected by the SDK build system
    mkdir -p staging_dir/hostpkg/bin
    ln -sf "../lib/go-${go_mm}/bin/go" staging_dir/hostpkg/bin/go
    ln -sf "../lib/go-${go_mm}/bin/gofmt" staging_dir/hostpkg/bin/gofmt

    # Mark golang as already compiled so make doesn't try to rebuild it
    mkdir -p staging_dir/hostpkg/stamp
    touch staging_dir/hostpkg/stamp/.golang_installed

    echo "  Go ${go_full} installed from pre-compiled binary."
}

if [ -n "$REQUIRED_GO_MM" ]; then
    if ! version_ge "$SDK_GO_MM" "$REQUIRED_GO_MM"; then
        echo "  SDK Go $SDK_GO_MM < required $REQUIRED_GO_MM — upgrading golang feed..."
        upgrade_golang_feed
    else
        echo "  SDK Go $SDK_GO_MM >= required $REQUIRED_GO_MM — no upgrade needed."
    fi
fi

# ─── Update package Makefiles ────────────────────────────────────────────────

echo ""
echo "Detected Versions:"
echo "  Docker/Moby: $CLEAN_VERSION ($MOBY_HASH) Commit: $MOBY_COMMIT"
echo "  Docker CLI:  $CLEAN_VERSION ($CLI_HASH) Commit: $CLI_COMMIT"
echo "  Containerd:  $CT_VERSION ($CT_HASH) Commit: $CT_COMMIT"
echo "  Runc:        $RUNC_VERSION ($RUNC_HASH) Commit: $RUNC_COMMIT"
if [ -n "$COMPOSE_VERSION" ]; then
    echo "  Compose:     $COMPOSE_VERSION ($COMPOSE_HASH) Commit: $COMPOSE_COMMIT"
fi

update_makefile "dockerd" "$CLEAN_VERSION" "$MOBY_HASH" "$MAKEFILE_DIR/dockerd/Makefile" "$RAW_MOBY_TAG" "$MOBY_COMMIT"
update_makefile "docker" "$CLEAN_VERSION" "$CLI_HASH" "$MAKEFILE_DIR/docker/Makefile" "$CLI_TAG" "$CLI_COMMIT"
update_makefile "containerd" "$CT_VERSION" "$CT_HASH" "$MAKEFILE_DIR/containerd/Makefile" "$CT_TAG" "$CT_COMMIT"
update_makefile "runc" "$RUNC_VERSION" "$RUNC_HASH" "$MAKEFILE_DIR/runc/Makefile" "$RUNC_TAG" "$RUNC_COMMIT"

if [ -n "$COMPOSE_VERSION" ]; then
    update_makefile "docker-compose" "$COMPOSE_VERSION" "$COMPOSE_HASH" "$MAKEFILE_DIR/docker-compose/Makefile" "$COMPOSE_TAG" "$COMPOSE_COMMIT"

    # Dynamically fix Go module path if compose major version changed
    COMPOSE_MAJOR=$(echo "$COMPOSE_VERSION" | cut -d. -f1)
    if [ "$COMPOSE_MAJOR" -ge 2 ] 2>/dev/null; then
        CURRENT_MODULE=$(grep -oE 'github\.com/docker/compose/v[0-9]+' "$MAKEFILE_DIR/docker-compose/Makefile" | head -1 || true)
        EXPECTED_MODULE="github.com/docker/compose/v${COMPOSE_MAJOR}"
        if [ -n "$CURRENT_MODULE" ] && [ "$CURRENT_MODULE" != "$EXPECTED_MODULE" ]; then
            echo "  Updating Go module path: $CURRENT_MODULE → $EXPECTED_MODULE"
            sed -i "s|$CURRENT_MODULE|$EXPECTED_MODULE|g" "$MAKEFILE_DIR/docker-compose/Makefile"
        fi
    fi
fi

# ─── Patch Makefiles for compatibility ───────────────────────────────────────

# Remove legacy containerd shims (removed in containerd 2.0+)
if [ -f "$MAKEFILE_DIR/containerd/Makefile" ]; then
    CT_MAJOR=$(echo "$CT_VERSION" | cut -d. -f1)
    if [ "$CT_MAJOR" -ge 2 ] 2>/dev/null; then
        echo "Patching containerd Makefile to remove legacy shims (containerd $CT_MAJOR.x)..."
        sed -i 's/containerd-shim,containerd-shim-runc-v1,//' "$MAKEFILE_DIR/containerd/Makefile"
    fi
fi

# Patch docker Makefile to find the correct binary (go build output path varies)
if [ -f "$MAKEFILE_DIR/docker/Makefile" ]; then
    if grep -q '\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/build/docker \$(1)/usr/bin/' "$MAKEFILE_DIR/docker/Makefile"; then
        echo "Patching docker Makefile to fix binary installation path..."
        sed -i 's|\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/build/docker \$(1)/usr/bin/|find $(PKG_BUILD_DIR) -name "docker-linux-*" -type f -exec $(INSTALL_BIN) {} $(1)/usr/bin/docker \\;|' "$MAKEFILE_DIR/docker/Makefile"
    fi
fi

# Patch dockerd Build/Prepare to skip vendored version checks and git-short-commit
# These checks reference hack/dockerfile/install/*.installer files that don't exist
# in Moby v29+ and require network access for git-short-commit.sh
if [ -f "$MAKEFILE_DIR/dockerd/Makefile" ]; then
    echo "Patching dockerd Makefile to skip vendored version checks..."
    # Replace the entire Build/Prepare block with just the default prepare
    sed -i '/^define Build\/Prepare$/,/^endef$/c\define Build/Prepare\n\t\$(Build/Prepare/Default)\nendef' "$MAKEFILE_DIR/dockerd/Makefile"

    # Add kmod-ipt-raw dependency (needed for Docker networking)
    if ! grep -q 'kmod-ipt-raw' "$MAKEFILE_DIR/dockerd/Makefile"; then
        echo "Patching dockerd Makefile to add kmod-ipt-raw dependency..."
        sed -i 's/+kmod-ipt-nat \\/+kmod-ipt-nat \\\n    +kmod-ipt-raw \\/' "$MAKEFILE_DIR/dockerd/Makefile"
    fi
fi
