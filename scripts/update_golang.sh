#!/bin/bash
set -e

# Must be run from inside the SDK directory
if [ ! -d "feeds/packages/lang" ]; then
    echo "Error: feeds/packages/lang not found. Are you in the SDK root with feeds installed?"
    exit 1
fi

echo "Checking Golang version..."
# Logic extracted from build.yml
rm -rf feeds/packages/lang/golang

# Try svn export first (faster), fallback to git sparse-checkout
if command -v svn >/dev/null 2>&1; then
    echo "Using SVN to export golang package..."
    svn export https://github.com/openwrt/packages/trunk/lang/golang feeds/packages/lang/golang
else
    echo "SVN not found. Using git sparse-checkout (slower)..."
    git clone --depth 1 --filter=blob:none --sparse https://github.com/openwrt/packages.git tmp_packages
    cd tmp_packages
    git sparse-checkout set lang/golang
    cd ..
    mv tmp_packages/lang/golang feeds/packages/lang/
    rm -rf tmp_packages
fi

# Re-install golang feed
./scripts/feeds install -f golang
echo "Golang package updated."
