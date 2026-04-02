#!/bin/bash

set -e

echo "🎵 Sounddocks — Mac Installer One"
echo "=============================="
echo ""

# ─── 1. Detect Architecture ───────────────────────────────────────────────────
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  DMG_URL="https://github.com/kpan-ai/sounddocks/releases/latest/download/Sounddocks-1.0.0-arm64.dmg"
else
  DMG_URL="https://github.com/kpan-ai/sounddocks/releases/latest/download/Sounddocks-1.0.0.dmg"
fi

# ─── 2. Install Sounddocks.app ────────────────────────────────────────────────
if [ -d "/Applications/Sounddocks.app" ]; then
  echo "✓ Sounddocks is already installed"
else
  echo "→ Downloading Sounddocks ($ARCH)..."
  TMP_DMG="/tmp/Sounddocks.dmg"
  curl -L --progress-bar -o "$TMP_DMG" "$DMG_URL"
  if [ $? -ne 0 ]; then
    echo "✕ Download failed. Check your internet connection."
    exit 1
  fi
  echo "→ Installing Sounddocks.app..."
  MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse -plist | plutil -extract system-entities xml1 - -o - | grep -A1 'mount-point' | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | head -1)
  APP_PATH=$(find "$MOUNT_POINT" -maxdepth 2 -name "*.app" | head -1)
  if [ -z "$APP_PATH" ]; then
    echo "✕ Could not find .app inside DMG."
    hdiutil detach "$MOUNT_POINT" -quiet
    exit 1
  fi
  cp -R "$APP_PATH" /Applications/
  hdiutil detach "$MOUNT_POINT" -quiet
  rm "$TMP_DMG"
  echo "✓ Sounddocks installed"
fi

# ─── 3. Fix Gatekeeper ────────────────────────────────────────────────────────
echo "→ Clearing Gatekeeper quarantine flag..."
xattr -cr /Applications/Sounddocks.app 2>/dev/null && echo "✓ Quarantine flag cleared" || echo "  (skipped)"
echo ""

# ─── 4. Install BlackHole ─────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "→ Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

echo "→ Installing BlackHole 2ch..."
brew install --cask blackhole-2ch 2>&1 | tail -3
echo "✓ BlackHole 2ch ready"
echo ""

# ─── 5. Create Aggregate Device ───────────────────────────────────────────────
echo "→ Creating Aggregate Device..."

# Use SwitchAudioSource / AudioDeviceCmdLine if available, otherwise Swift
# Detect BlackHole UID using ioreg which is more reliable than system_profiler
BLACKHOLE_UID=$(ioreg -l | grep -i blackhole | grep -i uid | awk -F'"' '{print $4}' | head -1)

# Fallback: use hardcoded known UID pattern for BlackHole 2ch
if [ -z "$BLACKHOLE_UID" ]; then
  # BlackHole 2ch always uses this UID format
  BLACKHOLE_UID="BlackHole2ch_UID"
  echo "  Using default BlackHole UID"
else
  echo "  BlackHole UID: $BLACKHOLE_UID"
fi

# Get default input device UID
MIC_UID=$(python3 -c "
import subprocess
result = subprocess.run(['system_profiler', 'SPAudioDataType'], capture_output=True, text=True)
lines = result.stdout.split('\n')
for i, line in enumerate(lines):
    if 'Default Input Device: Yes' in line:
        for j in range(i-10, i):
            if j >= 0 and 'Unique ID:' in lines[j]:
                print(lines[j].split('Unique ID:')[1].strip())
                break
" 2>/dev/null)

if [ -n "$MIC_UID" ]; then
  echo "  Mic UID: $MIC_UID"
else
  echo "  Could not detect mic UID, will use BlackHole only"
fi

# Write and run Swift to create the aggregate device
SWIFT_FILE="/tmp/create_aggregate.swift"

cat > "$SWIFT_FILE" << SWIFTEOF
import CoreAudio
import Foundation

let aggregateUID = "SounddocksAggregateDevice"
let blackholeUID = "${BLACKHOLE_UID}"
let micUID = "${MIC_UID}"

var subDevices: [[String: Any]] = [
    [kAudioSubDeviceUIDKey: blackholeUID]
]

if !micUID.isEmpty {
    subDevices.append([kAudioSubDeviceUIDKey: micUID])
}

let description: [String: Any] = [
    kAudioAggregateDeviceUIDKey: aggregateUID,
    kAudioAggregateDeviceNameKey: "Sounddocks Cable",
    kAudioAggregateDeviceIsPrivateKey: false,
    kAudioAggregateDeviceSubDeviceListKey: subDevices
]

var deviceID: AudioDeviceID = 0
let err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)

switch err {
case noErr:
    print("✓ Created 'Sounddocks Cable' aggregate device (id=\(deviceID))")
case -66748:
    print("✓ Aggregate device already exists")
default:
    print("⚠️  Could not create aggregate device (err=\(err))")
    print("   You can create it manually in Audio MIDI Setup")
}
SWIFTEOF

swift "$SWIFT_FILE" 2>/dev/null || echo "  ⚠️  Swift failed — create the Aggregate Device manually in Audio MIDI Setup"
rm -f "$SWIFT_FILE"

echo ""
echo "✅  Setup complete!"
echo ""
echo "  Next steps:"
echo ""
echo "  1. In System Settings → Sound:"
echo "     • Output → your headphones or speakers"
echo ""
echo "  2. In Discord:"
echo "     • Settings → Voice & Video"
echo "     • Input Device → Sounddocks Cable"
echo ""
echo "  3. Open Sounddocks — BlackHole will be auto-detected."
echo ""
echo "  If 'Sounddocks Cable' doesn't appear in Discord:"
echo "  → Open Audio MIDI Setup, click + → Create Aggregate Device"
echo "    and check BlackHole 2ch + your microphone."
echo ""
echo "  Enjoy! 🎧"
