# 🎵 Sounddocks

A clean soundboard app for PC and Mac that integrates with Discord. Play sounds in voice calls with hotkeys, import directly from MyInstants, and manage your library with a simple dark UI.

---

## Windows setup

### What you need
- **VB-Cable** (free) — [download here](https://vb-audio.com/Cable/)

### 1. Install VB-Cable
Download and install VB-Cable, then **restart your PC**.

### 2. Set CABLE Output as your default mic
1. Right-click the speaker icon → Sound settings
2. Scroll to Input → set default to **CABLE Output (VB-Audio Virtual Cable)**

### 3. Route your real mic into the cable
1. Sound settings → More sound settings → Recording tab
2. Right-click your real mic → Properties → Listen tab
3. Check **Listen to this device**
4. Set playback to **CABLE Input (VB-Audio Virtual Cable)**
5. Click OK

### 4. Set Discord input
Discord → Settings → Voice & Video → Input Device → **CABLE Output**

### 5. Install Sounddocks
Run **Sounddocks Setup.exe**. The app auto-detects CABLE Input.

> Windows may show a SmartScreen warning — click **More info → Run anyway**.

---

## Mac setup

### 1. Install Sounddocks 
Run this in Terminal:
```
bash <(curl -s https://raw.githubusercontent.com/kpan-ai/sounddocks/refs/heads/main/install-mac.sh)
```

### 2. Restart your Mac
- once the installation is fininalized an option for restarting is shown. click (y/n)
- after restarting go back to terminal and run the same cmd. It will create the Sounddocks Cable device

### 3. Setup Sounddocks
Sounddocks → Input Device → **Sounddocks Cable**o → Output Device → **Select your speakers**

### 4. Set Discord input
Discord → Settings → Voice & Video → Input Device → **Sounddocks Cable**

---

## Using the app

### First launch
- **Discord output** — auto-detected (CABLE Input on Windows, Sounddocks Cable on Mac)
- **Monitor** — set to your headphones so you hear sounds too

### Adding sounds
- Click **+ Add sounds** to import MP3, WAV, OGG, or FLAC files
- Click **⬇ MyInstants** to import from [myinstants.com](https://myinstants.com) — paste the URL and hit import

### Playing sounds
- Click a sound card to play, click again to stop
- Click **■ Stop all** to stop everything

### Hotkeys
- Right-click a sound → **Set hotkey** to bind a key combo
- Works globally even when the app is minimized

### Other
- Right-click any sound card to rename or change emoji

---

## Troubleshooting

**Discord can't hear sounds (Windows)**
- Make sure Discord Input Device is **CABLE Output**
- Make sure the app Discord output shows **CABLE Input ✓**

**Discord can't hear sounds (Mac)**
- Make sure Discord Input Device is **Aggregate Device**
- Make sure A1 is lit on the BlackHole strip in Audio MIDI Setup

**Mic not coming through (Windows)**
- Check Listen to this device is enabled on your real mic

**Mic not coming through (Mac)**
- Make sure your real mic is checked in the Aggregate Device

**I can't hear sounds myself**
- Set Monitor dropdown in Sounddocks to your headphones

**Hotkeys not working**
- Windows: right-click Sounddocks shortcut → Run as administrator
- Mac: System Preferences → Security & Privacy → Accessibility → enable Sounddocks
