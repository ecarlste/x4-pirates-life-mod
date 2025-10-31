#!/bin/bash

# X4 Foundations Mod Deployment Script
# This script copies the mod files to the X4 extensions directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if deploy.config exists
if [ ! -f "deploy.config" ]; then
    echo -e "${RED}Error: deploy.config not found${NC}"
    echo "Run 'make setup' first to create it from deploy.config.example"
    exit 1
fi

# Source the configuration
source deploy.config

# Validate that X4_EXTENSIONS_PATH is set
if [ -z "$X4_EXTENSIONS_PATH" ]; then
    echo -e "${RED}Error: X4_EXTENSIONS_PATH not set in deploy.config${NC}"
    exit 1
fi

# Create target directory if it doesn't exist
if [ ! -d "$X4_EXTENSIONS_PATH" ]; then
    echo -e "${YELLOW}Creating directory: $X4_EXTENSIONS_PATH${NC}"
    mkdir -p "$X4_EXTENSIONS_PATH"
fi

# Copy mod files
echo -e "${GREEN}Deploying mod to: $X4_EXTENSIONS_PATH${NC}"

# Copy content.xml
if [ -f "content.xml" ]; then
    cp content.xml "$X4_EXTENSIONS_PATH/"
    echo "  ✓ Copied content.xml"
else
    echo -e "${RED}  ✗ content.xml not found${NC}"
    exit 1
fi

# Copy libraries directory
if [ -d "libraries" ]; then
    cp -r libraries "$X4_EXTENSIONS_PATH/"
    echo "  ✓ Copied libraries/"
else
    echo -e "${RED}  ✗ libraries/ directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment successful!${NC}"
echo "Mod 'A Pirate's Life' has been deployed to X4 Foundations"
