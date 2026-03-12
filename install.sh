#!/usr/bin/env bash

# kfinalizer installer
set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
REPO_URL="https://raw.githubusercontent.com/user/kfinalizer/main/kfinalizer"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Installing kfinalizer...${NC}"

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Download or copy the script
if [ -f "./kfinalizer" ]; then
    echo "Installing from local file..."
    cp ./kfinalizer "$INSTALL_DIR/kfinalizer"
else
    echo "Error: kfinalizer script not found in current directory"
    exit 1
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
