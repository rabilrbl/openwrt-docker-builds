#!/bin/bash
set -e

# Must be run from inside the SDK directory
if [ ! -f "scripts/feeds" ]; then
    echo "Error: scripts/feeds not found. Are you in the SDK root?"
    exit 1
fi

echo "Updating feeds..."
# Clean up potential stale base feed from cache
rm -rf feeds/base feeds/*.index

./scripts/feeds update -a
./scripts/feeds install -a
