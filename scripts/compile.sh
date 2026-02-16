#!/bin/bash
set -e

# Must be run from inside the SDK directory
if [ ! -f "scripts/feeds" ]; then
    echo "Error: scripts/feeds not found. Are you in the SDK root?"
    exit 1
fi

echo "Installing targets..."
./scripts/feeds install docker dockerd containerd runc docker-compose luci-lib-docker
make defconfig

# Enable ccache for faster builds
if [ -z "$NO_CCACHE" ]; then
    echo "Enabling ccache..."
    echo "CONFIG_CCACHE=y" >> .config
    # Set cache dir if provided (e.g. from GitHub Actions or Docker mount)
    if [ -n "$CCACHE_DIR" ]; then
        echo "CONFIG_CCACHE_DIR=\"$CCACHE_DIR\"" >> .config
    fi
fi

# Use all available cores
JOBS=$(nproc)

echo "Compiling Containerd..."
make -j$JOBS package/containerd/compile V=s

echo "Compiling Dockerd..."
make -j$JOBS package/dockerd/compile V=s

echo "Compiling Docker CLI..."
make -j$JOBS package/docker/compile V=s

# Compilation of runc is often implied or needed; ensuring it builds
echo "Compiling Runc..."
make -j$JOBS package/runc/compile V=s

echo "Compiling Docker Compose..."
make -j$JOBS package/docker-compose/compile V=s

echo "Compiling luci-lib-docker..."
make -j$JOBS package/luci-lib-docker/compile V=s
