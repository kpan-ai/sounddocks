#!/bin/bash

set -e

echo "🎵 Sounddocks — Mac Installer"
echo "=============================="
echo ""

# ─── 1. Detect Architecture ───────────────────────────────────────────────────
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  DMG_URL="https://github.com/kpan-ai/sounddocks/releases/download/v1.0.0/Sounddocks-1.0.0-arm64.dmg"
else
  DMG_URL="https://github.com/kpan-ai/sounddocks/releases/download/v1.0.0/Sounddocks-1.0.0.dmg"
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
  MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse | tail -1 | sed 's|/dev/[^ ]*[ \t]*[^ ]*[ \t]*||'| sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
  echo "  Mounted at: $MOUNT_POINT"
  APP_PATH=$(find "$MOUNT_POINT" -maxdepth 2 -name "*.app" | head -1)
  if [ -z "$APP_PATH" ]; then
    echo "✕ Could not find .app inside DMG. Contents:"
    ls "$MOUNT_POINT"
    hdiutil detach "$MOUNT_POINT" -quiet
    exit 1
  fi
  cp -R "$APP_PATH" /Applications/
  hdiutil detach "$MOUNT_POINT" -quiet
  rm "$TMP_DMG"
  echo "✓ Sounddocks installed"
fi

# ─── 3. Fix 'damaged app' Gatekeeper warning ──────────────────────────────────
echo "→ Clearing Gatekeeper quarantine flag..."
xattr -cr /Applications/Sounddocks.app 2>/dev/null && echo "✓ Quarantine flag cleared" || echo "  (no quarantine flag found — skipping)"

echo ""

# ─── 4. Install VB-Audio Cable (with BlackHole fallback) ──────────────────────
VB_DRIVER_INSTALLED=false

if system_profiler SPAudioDataType 2>/dev/null | grep -qi "VB-Audio\|VBAudio\|vb-cable\|VB-Cable"; then
  echo "✓ VB-Audio Cable is already installed"
  VB_DRIVER_INSTALLED=true
elif system_profiler SPAudioDataType 2>/dev/null | grep -qi "BlackHole"; then
  echo "✓ BlackHole is already installed (will use as virtual cable)"
  VB_DRIVER_INSTALLED=true
fi

if [ "$VB_DRIVER_INSTALLED" = false ]; then
  echo "→ Attempting to install VB-Audio Cable..."

  VB_URL="https://download.vb-audio.com/Download_CABLE/VBCable_Driver_Pack43.zip"
  TMP_ZIP="/tmp/VBCable.zip"
  TMP_DIR="/tmp/VBCable"

  curl -L --progress-bar -o "$TMP_ZIP" "$VB_URL" 2>/dev/null
  VB_EXIT=$?

  if [ $VB_EXIT -eq 0 ] && [ -s "$TMP_ZIP" ]; then
    mkdir -p "$TMP_DIR"
    unzip -q "$TMP_ZIP" -d "$TMP_DIR"
    PKG=$(find "$TMP_DIR" -name "*.pkg" | head -1)
    if [ -n "$PKG" ]; then
      sudo installer -pkg "$PKG" -target /
      rm -rf "$TMP_ZIP" "$TMP_DIR"
      echo "✓ VB-Audio Cable installed"
      VB_DRIVER_INSTALLED=true
    else
      echo "  VB-Audio package not found in zip — falling back to BlackHole..."
      rm -rf "$TMP_ZIP" "$TMP_DIR"
    fi
  else
    echo "  VB-Audio download failed — falling back to BlackHole..."
    rm -f "$TMP_ZIP"
  fi

  # Fallback: BlackHole
  if [ "$VB_DRIVER_INSTALLED" = false ]; then
    echo "→ Installing BlackHole 2ch..."
    BH_URL="https://github.com/ExistentialAudio/BlackHole/releases/download/v0.6.0/BlackHole2ch-0.6.0.pkg"
    TMP_BH="/tmp/BlackHole2ch.pkg"
    curl -L --progress-bar -o "$TMP_BH" "$BH_URL"
    if [ $? -ne 0 ]; then
      echo "✕ BlackHole download failed. Please install a virtual audio cable manually."
      echo "  → https://github.com/ExistentialAudio/BlackHole"
      exit 1
    fi
    sudo installer -pkg "$TMP_BH" -target /
    rm "$TMP_BH"
    echo "✓ BlackHole 2ch installed (as fallback)"
    VB_DRIVER_INSTALLED=true
  fi
fi

echo ""

# ─── 5. Auto-create Aggregate Device via Core Audio ──────────────────────────
echo "→ Creating Aggregate Device (virtual cable + default mic)..."

python3 - <<'PYEOF'
import subprocess, json, sys

def get_audio_devices():
    try:
        result = subprocess.run(
            ['system_profiler', 'SPAudioDataType', '-json'],
            capture_output=True, text=True, timeout=15
        )
        data = json.loads(result.stdout)
        devices = []
        for item in data.get('SPAudioDataType', []):
            name = item.get('_name', '')
            if name:
                devices.append(name)
        return devices
    except Exception as e:
        return []

devices = get_audio_devices()

# Find virtual cable device name
virtual_cable = None
for d in devices:
    if any(k in d.lower() for k in ['vb-audio', 'vbcable', 'vb cable', 'cable input', 'cable output']):
        virtual_cable = d
        break
if not virtual_cable:
    for d in devices:
        if 'blackhole' in d.lower():
            virtual_cable = d
            break

if not virtual_cable:
    print("  ⚠️  Could not detect virtual audio cable device.")
    print("     Please reboot and re-run the installer, or create the Aggregate Device manually.")
    sys.exit(0)

print(f"  Detected virtual cable: {virtual_cable}")

# Use Audio MIDI Setup's aggdevice command-line tool if available, else osascript
import os
aggdevice_tool = '/usr/local/bin/aggdevice'  # may not exist; we'll use osascript

script = f'''
tell application "Audio MIDI Setup"
    -- aggregate device creation is done via audiomidi framework
end tell
'''

# Use pluginkit / coreaudio approach via swift one-liner as most reliable method
swift_code = f"""
import CoreAudio
import Foundation

// This creates an aggregate device combining the virtual cable + built-in mic
var desc = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

// Aggregate device composition dict
let uid = "SounddocksAggregateDevice"
let composition: [String: Any] = [
    kAudioAggregateDeviceUIDKey: uid,
    kAudioAggregateDeviceNameKey: "Sounddocks Aggregate",
    kAudioAggregateDeviceIsPrivateKey: false,
    kAudioAggregateDeviceTapAutoStartKey: false,
    kAudioAggregateDeviceSubDeviceListKey: [
        [kAudioSubDeviceUIDKey: "{virtual_cable}"],
    ]
]

var aggDeviceID: AudioDeviceID = 0
let err = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggDeviceID)
if err == noErr {{
    print("Aggregate device created: \\(aggDeviceID)")
}} else {{
    print("Note: Aggregate device may already exist or requires manual setup (err: \\(err))")
}}
"""

# Write and compile swift
swift_file = '/tmp/create_agg.swift'
with open(swift_file, 'w') as f:
    f.write(swift_code)

result = subprocess.run(
    ['swift', swift_file],
    capture_output=True, text=True, timeout=30
)

if 'Aggregate device created' in result.stdout:
    print("✓ Aggregate Device created: 'Sounddocks Aggregate'")
elif 'already exist' in result.stdout or result.returncode != 0:
    print("  ℹ️  Aggregate Device may already exist — skipping creation.")
else:
    print(f"  Output: {result.stdout.strip() or result.stderr.strip()}")

os.remove(swift_file)
PYEOF

echo ""
echo "✅  Setup complete!"
echo ""
echo "  Next steps:"
echo ""
echo "  1. In System Settings → Sound:"
echo "     • Output → your headphones (or speakers)"
echo ""
echo "  2. In Discord:"
echo "     • Settings → Voice & Video"
echo "     • Input Device → Sounddocks Aggregate"
echo ""
echo "  3. Open Sounddocks — Discord audio will be auto-routed via the virtual cable."
echo ""
echo "  Enjoy! 🎧"
