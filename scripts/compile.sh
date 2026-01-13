#!/bin/bash
set -e

# Must be run from inside the SDK directory
if [ ! -f "scripts/feeds" ]; then
    echo "Error: scripts/feeds not found. Are you in the SDK root?"
    exit 1
fi

echo "Installing targets..."
./scripts/feeds install docker dockerd containerd runc
make defconfig

echo "Compiling Containerd..."
make package/containerd/compile V=s

echo "Compiling Dockerd..."
make package/dockerd/compile V=s

echo "Compiling Docker CLI..."
make package/docker/compile V=s

# Compilation of runc is often implied or needed; ensuring it builds
echo "Compiling Runc..."
make package/runc/compile V=s
