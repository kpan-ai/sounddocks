#!/bin/bash

set -e

echo "🎵 Sounddocks — Mac Installer 1"
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
  MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse -plist | plutil -extract system-entities xml1 - -o - | grep -A1 'mount-point' | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | head -1)
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
# ─── 4. Install BlackHole virtual audio driver ────────────────────────────────
if system_profiler SPAudioDataType 2>/dev/null | grep -qi "BlackHole\|Transport: Virtual"; then
  echo "✓ Virtual audio driver already installed"
else
  echo "→ Installing BlackHole 2ch via Homebrew..."

  # Install Homebrew if not present
  if ! command -v brew &>/dev/null; then
    echo "  Installing Homebrew first..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [ -f "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi

  brew install --cask blackhole-2ch
  if [ $? -ne 0 ]; then
    echo "✕ BlackHole installation failed."
    echo "  Try manually: brew install --cask blackhole-2ch"
    exit 1
  fi
  echo "✓ BlackHole 2ch installed"
fi

echo ""

# ─── 5. Auto-create Aggregate Device via Core Audio ──────────────────────────
echo "→ Restarting audio system to register new driver..."
sudo kill -9 $(pgrep coreaudiod) 2>/dev/null || true
sleep 3
echo "✓ Audio system restarted"
echo ""
echo "→ Creating Aggregate Device (virtual cable + default mic)..."

python3 - <<'PYEOF'
import subprocess, json, sys, os

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

# Get all audio devices with their UIDs via system_profiler
result = run(['system_profiler', 'SPAudioDataType', '-json'])
try:
    data = json.loads(result.stdout)
except:
    print("  ⚠️  Could not read audio devices.")
    sys.exit(0)

devices = data.get('SPAudioDataType', [])
print(f"  Found {len(devices)} audio device(s)")

blackhole_uid = None
mic_uid = None

for d in devices:
    name = d.get('_name', '')
    uid = d.get('coreaudio_device_uid', '')
    print(f"  Device: {name} | UID: {uid}")
    if any(k in name.lower() for k in ['blackhole', 'black hole', 'blackhole 2ch']):
        blackhole_uid = uid if uid else 'BlackHole2ch_UID'

# Fallback for BlackHole
if not blackhole_uid:
    result2 = run(['system_profiler', 'SPAudioDataType'])
    if 'blackhole' in result2.stdout.lower():
        blackhole_uid = 'BlackHole2ch_UID'
        print("  BlackHole detected via fallback, using default UID")

if not blackhole_uid:
    print("  ⚠️  BlackHole not detected. Please reboot and re-run the installer.")
    sys.exit(0)

# Get default input device UID via Swift
mic_swift = """
import CoreAudio
import Foundation

var defaultInputID = AudioDeviceID(0)
var size = UInt32(MemoryLayout<AudioDeviceID>.size)
var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultInputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &defaultInputID)

var uidRef: CFString = "" as CFString
var uidSize = UInt32(MemoryLayout<CFString>.size)
var uidAddr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceUID,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
AudioObjectGetPropertyData(defaultInputID, &uidAddr, 0, nil, &uidSize, &uidRef)
print(uidRef)
"""
mic_file = '/tmp/get_mic_uid.swift'
with open(mic_file, 'w') as f:
    f.write(mic_swift)
mic_result = subprocess.run(['swift', mic_file], capture_output=True, text=True, timeout=15)
mic_uid = mic_result.stdout.strip()
try:
    os.remove(mic_file)
except:
    pass

if mic_uid:
    print(f"  Default mic UID: {mic_uid}")
else:
    print("  Could not detect default mic, using BlackHole only")

print(f"  BlackHole UID: {blackhole_uid}")
print(f"  Mic UID: {mic_uid or 'not found, using BlackHole only'}")

# Build sub-device list
sub_devices = [{"uid": blackhole_uid}]
if mic_uid:
    sub_devices.append({"uid": mic_uid})

# Write Swift to create aggregate device using UIDs
sub_list = "\n".join([f'    [kAudioSubDeviceUIDKey: "{d["uid"]}"],' for d in sub_devices])

swift_code = f"""
import CoreAudio
import Foundation

let uid = "SounddocksAggregateDevice"
let composition: [String: Any] = [
    kAudioAggregateDeviceUIDKey: uid,
    kAudioAggregateDeviceNameKey: "Sounddocks Cable",
    kAudioAggregateDeviceIsPrivateKey: false,
    kAudioAggregateDeviceSubDeviceListKey: [
{sub_list}
    ] as [[String: Any]]
]

var aggDeviceID: AudioDeviceID = 0
let err = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggDeviceID)
if err == noErr {{
    print("✓ Aggregate Device created: Sounddocks Cable (id=\\(aggDeviceID))")
}} else if err == -66748 {{
    print("✓ Aggregate Device already exists")
}} else {{
    print("⚠️  Could not create Aggregate Device (err=\\(err))")
}}
"""

swift_file = '/tmp/create_agg.swift'
with open(swift_file, 'w') as f:
    f.write(swift_code)

result = subprocess.run(['swift', swift_file], capture_output=True, text=True, timeout=30)
print(result.stdout.strip() or result.stderr.strip())

try:
    os.remove(swift_file)
except:
    pass
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
echo "     • Input Device → Sounddocks Cable"
echo ""
echo "  3. Open Sounddocks — Discord audio will be auto-routed via the virtual cable."
echo ""
echo "  Enjoy! 🎧"
