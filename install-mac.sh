#!/bin/bash

echo "🎵 Sounddocks — Mac Audio Setup"
echo "================================"

# Check if BlackHole is already installed
if system_profiler SPAudioDataType | grep -q "BlackHole"; then
  echo "✓ BlackHole is already installed"
else
  echo "→ Installing BlackHole 2ch..."

  # Download BlackHole pkg from GitHub releases
  BLACKHOLE_URL="https://github.com/ExistentialAudio/BlackHole/releases/download/v0.6.0/BlackHole2ch-0.6.0.pkg"
  TMP_PKG="/tmp/BlackHole2ch.pkg"

  curl -L -o "$TMP_PKG" "$BLACKHOLE_URL"

  if [ $? -ne 0 ]; then
    echo "✕ Download failed. Check your internet connection."
    exit 1
  fi

  sudo installer -pkg "$TMP_PKG" -target /
  rm "$TMP_PKG"

  echo "✓ BlackHole installed"
fi

echo ""
echo "→ Setting up Audio MIDI routing..."

# Create Multi-Output Device (headphones + BlackHole) using osascript
osascript << 'EOF'
tell application "Audio MIDI Setup" to quit
delay 0.5

-- Use system commands to create aggregate and multi-output devices
do shell script "open -a 'Audio MIDI Setup'"
delay 1
EOF

echo ""
echo "✓ Done! Now do the following:"
echo ""
echo "  1. In Audio MIDI Setup (just opened):"
echo "     • Click + → Create Multi-Output Device"
echo "     • Check BlackHole 2ch + your headphones"
echo "     • Click + → Create Aggregate Device"  
echo "     • Check BlackHole 2ch + your microphone"
echo ""
echo "  2. In Discord:"
echo "     • Input Device → Aggregate Device"
echo ""
echo "  3. In Sounddocks:"
echo "     • Discord output → auto-detected as BlackHole"
echo ""
echo "  4. To fix the 'damaged app' warning, run:"
echo "     xattr -cr /Applications/Sounddocks.app"
echo ""
