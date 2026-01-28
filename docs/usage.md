# AIFW Usage Guide

## Prerequisites

- macOS 13.0 or later
- Xcode Command Line Tools
- Valid code signing certificate
- Administrator access (sudo)

## Building

```bash
cd daemon
swift build -c release
```

## Code Signing

AIFW requires code signing with Endpoint Security entitlement:

```bash
# Sign the binary
./scripts/sign.sh

# Verify
codesign --verify --verbose .build/release/aifw-daemon
```

## Running

1. **Start target process** (e.g., opencode):
```bash
opencode &
TARGET_PID=$!
```

2. **Run AIFW** with sudo:
```bash
sudo .build/release/aifw-daemon $TARGET_PID
```

3. **Grant permissions** if prompted:
   - System Settings → Privacy & Security → Full Disk Access
   - Add Terminal or your IDE

## Configuration

Edit policy at: `~/.config/aifw/policy.json`

Default policy is created automatically on first run.

## Activity Logs

View logs:
```bash
sqlite3 ~/.config/aifw/activity.db "SELECT * FROM activity ORDER BY id DESC LIMIT 10"
```

## Troubleshooting

**"Operation not permitted"**:
- Ensure binary is code-signed
- Check Full Disk Access permissions
- Run with sudo

**"Failed to create ES client"**:
- Verify entitlements: `codesign --display --entitlements - aifw-daemon`
- Check for other ES clients running
- Reboot and try again

**Dialogs not showing**:
- Grant Accessibility permissions
- Test with: `swift run test-prompt`
