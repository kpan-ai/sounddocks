# 🎵 Sounddocks

A clean soundboard app for PC that lets you play sounds in Discord voice calls. Supports hotkeys, MyInstants imports, and runs in the background.

---

## What you need

- **Voicemeeter Banana** (free) — [download](https://vb-audio.com/Voicemeeter/banana.htm)
- **Node.js LTS** (free, only needed once to build) — [download](https://nodejs.org)

---

## Setup guide

### 1. Install Voicemeeter Banana
1. Download and install Voicemeeter Banana
2. **Restart your PC** — required, don't skip this

### 2. Set up Voicemeeter Banana
Open Voicemeeter Banana. You'll see strips across the top.

**Set your mic:**
- Under **Stereo Input 1**, click the label at the top of the strip
- Select your microphone from the list

**Set your headphones:**
- In the top right corner, find the **HARDWARE OUT** section
- Click **A1** and select your headphones or speakers

**Route audio correctly — this is the important part:**

On the **Stereo Input 1** strip (your mic):
- Make sure **A1** is lit green → so you hear yourself in your headphones
- Make sure **B1** is lit green → so Discord hears your mic

On the **Voicemeeter Input** strip (the soundboard):
- Make sure **A1** is lit green → so you hear the sounds in your headphones
- Make sure **B1** is lit green → so Discord hears the sounds

> **B1 is what sends audio to Discord.** If B1 is not lit on a strip, Discord won't hear it.

### 3. Set up Discord
1. Open Discord → Settings → Voice & Video
2. Set **Input Device** to **Voicemeeter Output**

Your friends will now hear both your mic and any sounds you play.

### 4. Install Sounddocks
1. Download and extract this repository
2. Open **Command Prompt as Administrator** inside the folder:
   - Click the address bar in File Explorer, type `cmd`, hit Enter
   - Right-click the taskbar icon → Run as administrator
3. Run:
```
npm install
npm run dist
```
4. Open the `dist` folder and run **Sounddocks Setup.exe**

> Windows may show a "Windows protected your PC" warning — click **More info** then **Run anyway**. This is normal.

---

## How to use

### Audio setup (first launch)
- **Discord output** — automatically set to Voicemeeter Input for you
- **Monitor** — set this to your headphones so you can hear sounds too

### Adding sounds
- Click **+ Add sounds** to import files from your PC (MP3, WAV, OGG, FLAC)
- Click **⬇ MyInstants** to import any sound from [myinstants.com](https://myinstants.com) — just paste the page URL

### Playing sounds
- Click a sound card to play it, click again to stop
- Click **■ Stop all** to stop everything instantly

### Hotkeys
- Right-click a sound → **Set hotkey** to bind any key combo
- Hotkeys work globally even when the app is minimized or in the background

### Customising
- Right-click any sound card to rename it or change its emoji

---

## Troubleshooting

**Discord can't hear the sounds**
- Make sure B1 is lit green on the **Voicemeeter Input** strip in Voicemeeter Banana
- Make sure Discord Input Device is set to **Voicemeeter Output**

**My mic isn't coming through**
- Make sure B1 is lit green on the **Stereo Input 1** strip in Voicemeeter Banana
- Check that Stereo Input 1 is set to your actual microphone

**I can't hear the sounds myself**
- Make sure A1 is lit green on the **Voicemeeter Input** strip
- Set the **Monitor** dropdown in Sounddocks to your headphones

**Hotkeys aren't working**
- Right-click the Sounddocks shortcut → Run as administrator
