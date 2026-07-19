#!/usr/bin/env bash

# kfinalizer installer
set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
REPO_URL="https://raw.githubusercontent.com/AlienAscension/kfinalizer/main/kfinalizer"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing kfinalizer...${NC}"

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Download or copy the script
if [ -f "./kfinalizer" ]; then
    echo "Installing from local file..."
    cp ./kfinalizer "$INSTALL_DIR/kfinalizer"
else
    echo "Downloading kfinalizer..."
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required for download but is not installed"
        exit 1
    fi
    if ! curl -fsSL "$REPO_URL" -o "$INSTALL_DIR/kfinalizer"; then
        echo "Error: Failed to download kfinalizer from $REPO_URL"
        exit 1
    fi
    if ! head -1 "$INSTALL_DIR/kfinalizer" | grep -q '^#!/usr/bin/env bash'; then
        echo "Error: Downloaded file does not look like the kfinalizer script"
        rm -f "$INSTALL_DIR/kfinalizer"
        exit 1
    fi
fi

# Make it executable
chmod +x "$INSTALL_DIR/kfinalizer"

echo -e "${GREEN}✓${NC} kfinalizer installed to $INSTALL_DIR/kfinalizer"

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo -e "${BLUE}Note:${NC} $INSTALL_DIR is not in your PATH"
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
fi

echo ""
echo "Usage: kfinalizer --help"
echo ""
