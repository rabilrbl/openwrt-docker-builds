#!/bin/bash
set -e

# Must be run from inside the SDK directory
if [ ! -f "scripts/feeds" ]; then
    echo "Error: scripts/feeds not found. Are you in the SDK root?"
    exit 1
fi

echo "Checking Golang version..."

# Remove existing golang feed if present (and we are forcing update)
if [ -d "feeds/packages/lang/golang" ]; then
    echo "Forcing Golang update..."
    rm -rf feeds/packages/lang/golang
fi

echo "Fetching latest Golang package from GitHub..."
# GitHub SVN support is deprecated, using git sparse-checkout
git clone --depth 1 --filter=blob:none --sparse https://github.com/openwrt/packages.git tmp_packages
cd tmp_packages
git sparse-checkout set lang/golang
cd ..
mkdir -p feeds/packages/lang
mv tmp_packages/lang/golang feeds/packages/lang/
rm -rf tmp_packages

# Re-install golang feed
./scripts/feeds install -f golang
echo "Golang package updated."
