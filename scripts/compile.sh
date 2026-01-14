#!/bin/bash
set -e

# Must be run from inside the SDK directory
if [ ! -f "scripts/feeds" ]; then
    echo "Error: scripts/feeds not found. Are you in the SDK root?"
    exit 1
fi

echo "Installing targets..."
./scripts/feeds install docker dockerd containerd runc luci-lib-docker
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

echo "Compiling Docker Compose..."
make package/docker-compose/compile V=s

echo "Compiling luci-lib-docker..."
make package/luci-lib-docker/compile V=s

echo ""
echo "Compilation complete. Detecting package format..."

# Detect package manager type (APK vs OPKG) by searching entire bin directory
if [ -d "bin" ]; then
    APK_COUNT=$(find bin -name "*.apk" 2>/dev/null | wc -l)
    IPK_COUNT=$(find bin -name "*.ipk" 2>/dev/null | wc -l)
    
    echo "Found $IPK_COUNT .ipk files and $APK_COUNT .apk files in bin/"
    
    if [ "$APK_COUNT" -gt 0 ]; then
        echo "Detected APK package manager (OpenWrt 25.12+)"
        echo "PKG_EXT=apk" > /tmp/pkg_format.env
    elif [ "$IPK_COUNT" -gt 0 ]; then
        echo "Detected OPKG package manager (OpenWrt 24.10 and earlier)"
        echo "PKG_EXT=ipk" > /tmp/pkg_format.env
    else
        echo "Warning: No packages found in bin/"
        echo ""
        echo "Showing bin directory structure:"
        ls -laR bin/ | head -100 || true
    fi
    
    # Show where packages are located
    if [ "$APK_COUNT" -gt 0 ] || [ "$IPK_COUNT" -gt 0 ]; then
        echo ""
        echo "Package locations:"
        find bin -type f \( -name "*.apk" -o -name "*.ipk" \) | head -20 || true
    fi
else
    echo "Warning: bin/ directory not found"
    ls -la . || true
fi
