# 🎵 Sounddocks

A clean soundboard app for PC that integrates with Discord. Play sounds in voice calls with hotkeys, import directly from MyInstants, and manage your library with a simple dark UI.

---

## What you need

- **VB-Cable** (free) — [download here](https://vb-audio.com/Cable/)

That's it. No Voicemeeter needed.

---

## Setup

### 1. Install VB-Cable
1. Download and install VB-Cable
2. **Restart your PC** after installing

### 2. Set CABLE Output as your default mic
1. Right-click the speaker icon in your taskbar → **Sound settings**
2. Scroll down to **Input**
3. Set the default input device to **CABLE Output (VB-Audio Virtual Cable)**

### 3. Route your real mic into the cable
This lets Discord hear your real mic through the cable alongside the soundboard.

1. Open **Sound settings** → scroll down and click **More sound settings**
2. Go to the **Recording** tab
3. Right-click your **real microphone** → **Properties**
4. Go to the **Listen** tab
5. Check **Listen to this device**
6. Set **Playback through this device** to **CABLE Input (VB-Audio Virtual Cable)**
7. Click OK

Now your real mic feeds into the cable, so Discord hears both your voice and the soundboard.

### 4. Configure Discord
1. Open Discord → Settings → Voice & Video
2. Set **Input Device** to **CABLE Output (VB-Audio Virtual Cable)**

### 5. Install Sounddocks
Run **Sounddocks Setup.exe** and install it. You'll get a desktop shortcut.

> Windows may show a "Windows protected your PC" warning. Click **More info** then **Run anyway**. This is normal.

---

## Using the app

### First launch
- **Discord output** — automatically set to CABLE Input for you
- **Monitor** — set this to your headphones so you can also hear the sounds yourself

### Adding sounds
- Click **+ Add sounds** to import MP3, WAV, OGG, or FLAC files from your PC
- Click **⬇ MyInstants** to import any sound from [myinstants.com](https://myinstants.com) — paste the page URL and hit import

### Playing sounds
- Click any sound card to play it — click it again to stop
- Click **■ Stop all** to stop everything at once

### Hotkeys
- Right-click a sound → **Set hotkey** to bind a key combination
- Hotkeys work globally even when the app is minimized

### Other options
- Right-click any sound card to rename it or change its emoji

---

## Troubleshooting

**Discord can't hear the sounds**
- Make sure Discord Input Device is set to **CABLE Output**
- Make sure the app's Discord output is set to **CABLE Input ✓**

**My mic isn't coming through**
- Make sure you enabled **Listen to this device** on your real mic and set playback to **CABLE Input**

**I can't hear the sounds myself**
- Set the **Monitor** dropdown in Sounddocks to your headphones

**Hotkeys aren't working**
- Right-click the Sounddocks shortcut → Run as administrator
