#!/bin/bash

set -e

echo "Code Signing AIFW Daemon"
echo "========================"

# Configuration
BINARY=".build/release/aifw-daemon"
ENTITLEMENTS="daemon/AIFWDaemon.entitlements"
IDENTITY="Developer ID Application"

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Binary not found: $BINARY"
    echo "   Run: swift build -c release"
    exit 1
fi

# Check if entitlements file exists
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "Entitlements file not found: $ENTITLEMENTS"
    exit 1
fi

# Sign the binary
echo "Signing with identity: $IDENTITY"
codesign --force \
         --sign "$IDENTITY" \
         --entitlements "$ENTITLEMENTS" \
         --options runtime \
         "$BINARY"

# Verify signature
echo ""
echo "Verifying signature..."
codesign --verify --verbose "$BINARY"

# Check entitlements
echo ""
echo "Entitlements:"
codesign --display --entitlements - "$BINARY"

echo ""
echo "Code signing complete!"
echo ""
echo "Next steps:"
echo "  1. Run with sudo: sudo $BINARY <target-pid>"
echo "  2. Grant Full Disk Access in System Settings if needed"
