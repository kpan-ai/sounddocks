# 🎵 Sounddocks

A clean soundboard app for PC that integrates with Discord. Play sounds in voice calls with hotkeys, import directly from MyInstants, and manage your library with a simple dark UI.

---

## What you need

- **Voicemeeter Banana** (free) — [download here](https://vb-audio.com/Voicemeeter/banana.htm)

That's it. Just install Voicemeeter and then run the Sounddocks setup file.

---

## Setup

### 1. Install Voicemeeter Banana
1. Download and install Voicemeeter Banana
2. **Restart your PC** — this is required, don't skip it

### 2. Configure Voicemeeter Banana
Open Voicemeeter Banana. You'll see a row of strips across the top.

**Set your microphone:**
- Look at the **Stereo Input 1** strip on the far left
- Click the label at the top of that strip
- Select your microphone from the list

**Set your headphones:**
- In the top right corner find the **HARDWARE OUT** section
- Click **A1** and select your headphones or speakers

**Route audio so Discord hears everything:**

On the **Stereo Input 1** strip (your mic):
- Click **A1** so it lights up green → you hear yourself
- Click **B1** so it lights up green → Discord hears your mic

On the **Voicemeeter Input** strip (in the Virtual Inputs section, middle of the screen):
- Click **A1** so it lights up green → you hear the sounds
- Click **B1** so it lights up green → Discord hears the sounds

> B1 is what sends audio to Discord. If B1 is not lit on a strip, Discord won't hear it.

### 3. Configure Discord
1. Open Discord → Settings → Voice & Video
2. Set **Input Device** to **Voicemeeter Output**

Your friends will now hear both your mic and any sounds you play at the same time.

### 4. Install Sounddocks
Run **Sounddocks Setup.exe** and install it. You'll get a desktop shortcut.

> Windows may show a "Windows protected your PC" warning. Click **More info** then **Run anyway**. This is normal for apps without a paid certificate.

---

## Using the app

### First launch
- **Discord output** — automatically set to Voicemeeter Input for you
- **Monitor** — set this to your headphones so you can also hear the sounds

### Adding sounds
- Click **+ Add sounds** to import MP3, WAV, OGG, or FLAC files from your PC
- Click **⬇ MyInstants** to import any sound from [myinstants.com](https://myinstants.com) — just paste the page URL and hit import

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
- Make sure **B1 is lit green** on the Voicemeeter Input strip in Voicemeeter Banana
- Make sure Discord Input Device is set to **Voicemeeter Output**

**My mic isn't coming through**
- Make sure **B1 is lit green** on the Stereo Input 1 strip in Voicemeeter Banana

**I can't hear the sounds myself**
- Make sure **A1 is lit green** on the Voicemeeter Input strip
- Set the **Monitor** dropdown in Sounddocks to your headphones

**Hotkeys aren't working**
- Right-click the Sounddocks shortcut → Run as administrator
