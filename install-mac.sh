#!/bin/bash

set -e

echo "🎵 Sounddocks — Mac Installer"
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
echo "→ Restarting audio daemon..."
sudo launchctl kickstart -k system/com.apple.audio.coreaudiod 2>/dev/null || true
sleep 3
echo "✓ Audio daemon restarted"
sleep 3
echo "✓ Audio daemon restarted"
echo ""

# ─── 5. Create Aggregate Device using Swift Core Audio ────────────────────────
echo "→ Creating Aggregate Device..."

SWIFT_FILE="/tmp/create_aggregate.swift"

cat > "$SWIFT_FILE" << 'SWIFTEOF'
import CoreAudio
import Foundation

func getAllDevices() -> [AudioDeviceID] {
    var propAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize)
    let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var devices = [AudioDeviceID](repeating: 0, count: count)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize, &devices)
    return devices
}

func getDeviceName(_ id: AudioDeviceID) -> String {
    var propAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var name: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    AudioObjectGetPropertyData(id, &propAddr, 0, nil, &size, &name)
    return name as String
}

func getDeviceUID(_ id: AudioDeviceID) -> String {
    var propAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var uid: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    AudioObjectGetPropertyData(id, &propAddr, 0, nil, &size, &uid)
    return uid as String
}

func hasInputChannels(_ id: AudioDeviceID) -> Bool {
    var propAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    let err = AudioObjectGetPropertyDataSize(id, &propAddr, 0, nil, &size)
    if err != noErr || size == 0 { return false }
    let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
    defer { bufferList.deallocate() }
    AudioObjectGetPropertyData(id, &propAddr, 0, nil, &size, bufferList)
    return bufferList.pointee.mNumberBuffers > 0
}

func getDefaultInputDevice() -> AudioDeviceID {
    var propAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &size, &deviceID)
    return deviceID
}

let allDevices = getAllDevices()
var blackholeUID: String? = nil
var micUID: String? = nil

print("  Scanning audio devices...")
for id in allDevices {
    let name = getDeviceName(id)
    let uid = getDeviceUID(id)
    print("  · \(name)")
    if name.lowercased().contains("blackhole") {
        blackholeUID = uid
    }
}

let defaultInputID = getDefaultInputDevice()
let defaultName = getDeviceName(defaultInputID)
let defaultUID = getDeviceUID(defaultInputID)

if !defaultName.lowercased().contains("blackhole") && hasInputChannels(defaultInputID) {
    micUID = defaultUID
    print("  · Mic: \(defaultName)")
} else {
    for id in allDevices {
        let name = getDeviceName(id)
        let uid = getDeviceUID(id)
        if !name.lowercased().contains("blackhole") && hasInputChannels(id) {
            micUID = uid
            print("  · Mic: \(name)")
            break
        }
    }
}

guard let bhUID = blackholeUID else {
    print("✕ BlackHole not found in device list. Please reboot and try again.")
    exit(1)
}

print("  BlackHole UID: \(bhUID)")
if let mUID = micUID { print("  Mic UID: \(mUID)") }

var subDevices: [[String: Any]] = [[kAudioSubDeviceUIDKey: bhUID]]
if let mUID = micUID {
    subDevices.append([kAudioSubDeviceUIDKey: mUID])
}

let description: [String: Any] = [
    kAudioAggregateDeviceUIDKey: "SounddocksAggregateDevice",
    kAudioAggregateDeviceNameKey: "Sounddocks Cable",
    kAudioAggregateDeviceIsPrivateKey: false,
    kAudioAggregateDeviceSubDeviceListKey: subDevices
]

var deviceID: AudioDeviceID = 0
let err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)

switch err {
case noErr:
    print("✓ Created 'Sounddocks Cable' (id=\(deviceID))")
case -66748:
    print("✓ 'Sounddocks Cable' already exists")
default:
    print("⚠️  Could not create aggregate device (err=\(err))")
    print("   Open Audio MIDI Setup → + → Create Aggregate Device")
    print("   Check BlackHole 2ch + your microphone")
}
SWIFTEOF

swift "$SWIFT_FILE" 2>/dev/null || {
  echo "  ⚠️  Swift failed — create Aggregate Device manually in Audio MIDI Setup"
  echo "     Click + → Create Aggregate Device → check BlackHole 2ch + your mic"
}
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
echo "  If 'Sounddocks Cable' doesn't appear:"
echo "  → Open Audio MIDI Setup → + → Create Aggregate Device"
echo "    and check BlackHole 2ch + your microphone."
echo ""
echo "  Enjoy! 🎧"
