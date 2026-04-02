const { ipcRenderer } = require('electron')
const path = require('path')
const os = require('os')

// Hide custom titlebar buttons on Mac — Mac uses native traffic lights
if (os.platform() === 'darwin') {
  document.addEventListener('DOMContentLoaded', () => {
    const controls = document.getElementById('titlebar-controls')
    if (controls) controls.style.display = 'none'
    // Add padding so content clears the native traffic lights
    const titlebar = document.getElementById('titlebar')
    if (titlebar) titlebar.style.paddingLeft = '80px'
  })
}

// ── State ─────────────────────────────────────────────────────────
let sounds = []
let discordOutputId = ''
let monitorOutputId = ''
let masterVolume = 80
let activeSounds = new Map()
let searchQuery = ''
let pendingHotkey = null
let pendingRenameId = null
let contextMenuEl = null

const EMOJIS = ['🔊','💥','😂','🔔','👏','🚨','🐸','🥁','💀','🎵','🎤','🎸','🦆','🐱','👾','🎮','💣','🔥','⚡','🎉','🤖','🎯','🎲','🌀']

// ── Boot ──────────────────────────────────────────────────────────
async function init() {
  wireButtons()

  const config = await ipcRenderer.invoke('load-config')
  sounds = (config.sounds || []).map(s => ({ emoji: '🔊', ...s }))
  masterVolume = config.volume ?? 80
  discordOutputId = config.discordOutputId || ''
  monitorOutputId = config.monitorOutputId || ''

  document.getElementById('master-volume').value = masterVolume
  document.getElementById('vol-display').textContent = masterVolume + '%'

  await loadAudioDevices()

  if (discordOutputId) document.getElementById('discord-out').value = discordOutputId
  if (monitorOutputId) document.getElementById('monitor-out').value = monitorOutputId

  ipcRenderer.send('reload-hotkeys', sounds)
  render()
}

function saveState() {
  ipcRenderer.send('save-config', { sounds, discordOutputId, monitorOutputId, volume: masterVolume })
}



// ── Audio Devices ─────────────────────────────────────────────────
function isCableInput(label) {
  const l = label.toLowerCase()
  return l.includes('cable input') || l.includes('vb-audio virtual cable')
}

function isCableOrVirtual(label) {
  const l = label.toLowerCase()
  return l.includes('cable') || l.includes('voicemeeter') || l.includes('vb-audio')
}

async function loadAudioDevices() {
  const discordSel = document.getElementById('discord-out')
  const monitorSel = document.getElementById('monitor-out')

  discordSel.innerHTML = '<option value="">Loading...</option>'
  monitorSel.innerHTML = '<option value="">None</option>'

  try { await navigator.mediaDevices.getUserMedia({ audio: true }) } catch (e) {}

  let outputs = []
  try {
    const devices = await navigator.mediaDevices.enumerateDevices()
    outputs = devices.filter(d => d.kind === 'audiooutput')
  } catch (e) {
    discordSel.innerHTML = '<option value="">Could not load devices</option>'
    return
  }

  const cableDevice = outputs.find(d => isCableInput(d.label || ''))

  discordSel.innerHTML = ''
  if (cableDevice) {
    discordSel.appendChild(new Option('CABLE Input (VB-Audio) ✓', cableDevice.deviceId))
    if (!discordOutputId) {
      discordOutputId = cableDevice.deviceId
      saveState()
    }
  } else {
    discordSel.appendChild(new Option('— Install VB-Cable first —', ''))
    outputs.forEach(d => {
      discordSel.appendChild(new Option(d.label || 'Unknown device', d.deviceId))
    })
  }

  // Monitor: only real output devices, no virtual cables
  monitorSel.innerHTML = '<option value="">None</option>'
  outputs
    .filter(d => !isCableOrVirtual(d.label || ''))
    .forEach(d => {
      monitorSel.appendChild(new Option(d.label || 'Unknown device', d.deviceId))
    })

  const hint = document.getElementById('vm-hint')
  if (hint) hint.style.display = cableDevice ? 'block' : 'none'
}

// ── Playback ──────────────────────────────────────────────────────
async function playSound(id) {
  const sound = sounds.find(s => s.id === id)
  if (!sound) return

  stopSound(id)

  const vol = masterVolume / 100
  const active = {}

  async function makeAudio(deviceId) {
    const audio = new Audio()
    audio.src = sound.path
    audio.volume = vol
    if (deviceId) {
      try { await audio.setSinkId(deviceId) } catch (e) {}
    }
    return audio
  }

  if (discordOutputId) {
    const a = await makeAudio(discordOutputId)
    active.discord = a
    a.play().catch(() => {})
  }

  if (monitorOutputId && monitorOutputId !== discordOutputId) {
    const a = await makeAudio(monitorOutputId)
    active.monitor = a
    a.play().catch(() => {})
  }

  if (!discordOutputId && !monitorOutputId) {
    const a = await makeAudio('')
    active.discord = a
    a.play().catch(() => {})
  }

  activeSounds.set(id, active)
  updateCardPlaying(id, true)
  setStatus('Playing: ' + sound.name, 'playing')

  const primary = active.discord || active.monitor
  if (primary) {
    primary.onended = () => {
      activeSounds.delete(id)
      updateCardPlaying(id, false)
      if (activeSounds.size === 0) setStatus('Ready', '')
    }
  }
}

function stopSound(id) {
  const active = activeSounds.get(id)
  if (!active) return
  if (active.discord) { active.discord.pause(); active.discord.currentTime = 0 }
  if (active.monitor) { active.monitor.pause(); active.monitor.currentTime = 0 }
  activeSounds.delete(id)
  updateCardPlaying(id, false)
}

function stopAll() {
  for (const [id] of activeSounds) stopSound(id)
  setStatus('Ready', '')
}

function updateCardPlaying(id, playing) {
  const card = document.querySelector(`.sound-card[data-id="${id}"]`)
  if (card) card.classList.toggle('playing', playing)
}

// ── Render ────────────────────────────────────────────────────────
function render() {
  const grid = document.getElementById('sound-grid')
  const empty = document.getElementById('empty-state')

  const filtered = sounds.filter(s =>
    s.name.toLowerCase().includes(searchQuery.toLowerCase())
  )

  grid.innerHTML = ''

  if (sounds.length === 0) {
    empty.classList.add('visible')
    grid.style.display = 'none'
    return
  }

  empty.classList.remove('visible')
  grid.style.display = 'grid'

  filtered.forEach(sound => {
    const card = document.createElement('div')
    card.className = 'sound-card'
    card.dataset.id = sound.id
    if (activeSounds.has(sound.id)) card.classList.add('playing')

    card.innerHTML = `
      <div class="sound-emoji">${sound.emoji || '🔊'}</div>
      <div class="sound-name" title="${sound.name}">${sound.name}</div>
      <div class="sound-meta">
        <span class="sound-hotkey ${sound.hotkey ? '' : 'none'}">${sound.hotkey || 'no key'}</span>
        <button class="sound-menu-btn" data-id="${sound.id}">···</button>
      </div>
      <div class="playing-bar"></div>
    `

    card.addEventListener('click', e => {
      if (e.target.classList.contains('sound-menu-btn')) return
      if (activeSounds.has(sound.id)) stopSound(sound.id)
      else playSound(sound.id)
    })

    card.querySelector('.sound-menu-btn').addEventListener('click', e => {
      e.stopPropagation()
      showContextMenu(e, sound)
    })

    grid.appendChild(card)
  })
}

// ── Context Menu ──────────────────────────────────────────────────
function showContextMenu(e, sound) {
  removeContextMenu()
  contextMenuEl = document.createElement('div')
  contextMenuEl.className = 'context-menu'
  contextMenuEl.innerHTML = `
    <div class="ctx-item" data-action="rename">✎ &nbsp;Rename</div>
    <div class="ctx-item" data-action="emoji">◈ &nbsp;Change emoji</div>
    <div class="ctx-item" data-action="hotkey">⌨ &nbsp;Set hotkey</div>
    <div class="ctx-sep"></div>
    <div class="ctx-item danger" data-action="remove">✕ &nbsp;Remove</div>
  `
  document.body.appendChild(contextMenuEl)

  let x = e.clientX, y = e.clientY
  const rect = contextMenuEl.getBoundingClientRect()
  if (x + rect.width > window.innerWidth) x = window.innerWidth - rect.width - 6
  if (y + rect.height > window.innerHeight) y = window.innerHeight - rect.height - 6
  contextMenuEl.style.left = x + 'px'
  contextMenuEl.style.top = y + 'px'

  contextMenuEl.addEventListener('click', ev => {
    const action = ev.target.closest('.ctx-item')?.dataset.action
    if (!action) return
    removeContextMenu()
    if (action === 'rename') openRenameModal(sound)
    if (action === 'emoji') cycleEmoji(sound.id)
    if (action === 'hotkey') openHotkeyModal(sound)
    if (action === 'remove') removeSound(sound.id)
  })

  setTimeout(() => document.addEventListener('click', removeContextMenu, { once: true }), 10)
}

function removeContextMenu() {
  if (contextMenuEl) { contextMenuEl.remove(); contextMenuEl = null }
}

// ── Add / Remove ──────────────────────────────────────────────────
async function addSounds() {
  const files = await ipcRenderer.invoke('pick-audio-files')
  for (const filePath of files) {
    const name = path.basename(filePath, path.extname(filePath))
    if (sounds.find(s => s.path === filePath)) continue
    sounds.push({
      id: Date.now() + Math.random().toString(36).slice(2),
      name, path: filePath,
      emoji: EMOJIS[Math.floor(Math.random() * EMOJIS.length)],
      hotkey: null, tags: []
    })
  }
  saveState()
  render()
}

function removeSound(id) {
  stopSound(id)
  const sound = sounds.find(s => s.id === id)
  if (sound?.hotkey) ipcRenderer.send('unregister-hotkey', sound.hotkey)
  sounds = sounds.filter(s => s.id !== id)
  saveState()
  render()
}

function cycleEmoji(id) {
  const sound = sounds.find(s => s.id === id)
  if (!sound) return
  sound.emoji = EMOJIS[(EMOJIS.indexOf(sound.emoji) + 1) % EMOJIS.length]
  saveState()
  render()
}

// ── Rename Modal ──────────────────────────────────────────────────
function openRenameModal(sound) {
  pendingRenameId = sound.id
  document.getElementById('rename-input').value = sound.name
  document.getElementById('rename-modal').style.display = 'flex'
  setTimeout(() => document.getElementById('rename-input').focus(), 50)
}

function closeRenameModal() {
  document.getElementById('rename-modal').style.display = 'none'
  pendingRenameId = null
}

function saveRename() {
  const name = document.getElementById('rename-input').value.trim()
  if (!name || !pendingRenameId) return closeRenameModal()
  const sound = sounds.find(s => s.id === pendingRenameId)
  if (sound) { sound.name = name; saveState(); render() }
  closeRenameModal()
}

// ── Hotkey Modal ──────────────────────────────────────────────────
function openHotkeyModal(sound) {
  pendingHotkey = { id: sound.id, keys: null }
  document.getElementById('modal-sound-name').textContent = sound.name
  document.getElementById('hotkey-display').textContent = sound.hotkey || 'Press a key...'
  document.getElementById('hotkey-modal').style.display = 'flex'
  document.addEventListener('keydown', captureHotkey)
}

function closeHotkeyModal() {
  document.getElementById('hotkey-modal').style.display = 'none'
  document.removeEventListener('keydown', captureHotkey)
  pendingHotkey = null
}

function captureHotkey(e) {
  e.preventDefault()
  e.stopPropagation()
  if (e.key === 'Escape') {
    pendingHotkey.keys = null
    document.getElementById('hotkey-display').textContent = '— cleared —'
    return
  }
  const parts = []
  if (e.ctrlKey) parts.push('CommandOrControl')
  if (e.altKey) parts.push('Alt')
  if (e.shiftKey) parts.push('Shift')
  const ignored = ['Control','Alt','Shift','Meta','CapsLock']
  if (!ignored.includes(e.key)) {
    const keyMap = {
      'F1':'F1','F2':'F2','F3':'F3','F4':'F4','F5':'F5','F6':'F6',
      'F7':'F7','F8':'F8','F9':'F9','F10':'F10','F11':'F11','F12':'F12',
      'ArrowLeft':'Left','ArrowRight':'Right','ArrowUp':'Up','ArrowDown':'Down',
      'Delete':'Delete','Backspace':'Backspace','Enter':'Return','Tab':'Tab',
      'Insert':'Insert','Home':'Home','End':'End','PageUp':'PageUp','PageDown':'PageDown'
    }
    parts.push(e.key.length === 1 ? e.key.toUpperCase() : (keyMap[e.key] || e.key))
  }
  pendingHotkey.keys = parts.join('+')
  document.getElementById('hotkey-display').textContent = pendingHotkey.keys
}

function saveHotkey() {
  if (!pendingHotkey) return closeHotkeyModal()
  const sound = sounds.find(s => s.id === pendingHotkey.id)
  if (!sound) return closeHotkeyModal()
  if (sound.hotkey) ipcRenderer.send('unregister-hotkey', sound.hotkey)
  sound.hotkey = pendingHotkey.keys || null
  if (sound.hotkey) ipcRenderer.send('register-hotkey', { id: sound.id, accelerator: sound.hotkey })
  saveState(); render(); closeHotkeyModal()
}

// ── MyInstants ────────────────────────────────────────────────────
function openMyInstantsModal() {
  document.getElementById('myinstants-url').value = ''
  setMyInstantsStatus('', '')
  document.getElementById('myinstants-modal').style.display = 'flex'
  setTimeout(() => document.getElementById('myinstants-url').focus(), 50)
}

function closeMyInstantsModal() {
  document.getElementById('myinstants-modal').style.display = 'none'
}

function setMyInstantsStatus(msg, type) {
  const el = document.getElementById('myinstants-status')
  if (!msg) { el.style.display = 'none'; return }
  el.style.display = 'block'
  el.textContent = msg
  el.className = 'myinstants-status ' + type
}

async function importFromMyInstants() {
  const url = document.getElementById('myinstants-url').value.trim()
  if (!url) return
  const importBtn = document.getElementById('myinstants-import')
  importBtn.disabled = true
  importBtn.textContent = 'Importing...'
  setMyInstantsStatus('Fetching sound...', 'loading')
  try {
    const result = await ipcRenderer.invoke('download-myinstants', url)
    sounds.push({
      id: Date.now() + Math.random().toString(36).slice(2),
      name: result.name, path: result.path,
      emoji: EMOJIS[Math.floor(Math.random() * EMOJIS.length)],
      hotkey: null, tags: []
    })
    saveState(); render()
    setMyInstantsStatus('✓ Added: ' + result.name, 'success')
    document.getElementById('myinstants-url').value = ''
    setTimeout(closeMyInstantsModal, 1200)
  } catch (err) {
    setMyInstantsStatus('✕ ' + (err.message || 'Import failed'), 'error')
  } finally {
    importBtn.disabled = false
    importBtn.textContent = 'Import'
  }
}

// ── IPC ───────────────────────────────────────────────────────────
ipcRenderer.on('hotkey-triggered', (_e, id) => {
  if (activeSounds.has(id)) stopSound(id)
  else playSound(id)
})

// ── Status ────────────────────────────────────────────────────────
function setStatus(text, type) {
  document.getElementById('status-text').textContent = text
  const dot = document.getElementById('status-dot')
  dot.className = 'status-dot' + (type ? ' ' + type : '')
}

// ── Wire Buttons ──────────────────────────────────────────────────
function wireButtons() {
  document.getElementById('btn-add').addEventListener('click', addSounds)
  document.getElementById('btn-add-empty').addEventListener('click', addSounds)
  document.getElementById('btn-stop-all').addEventListener('click', stopAll)
  document.getElementById('btn-myinstants').addEventListener('click', openMyInstantsModal)

  document.getElementById('master-volume').addEventListener('input', function () {
    masterVolume = parseInt(this.value)
    document.getElementById('vol-display').textContent = masterVolume + '%'
    for (const [, active] of activeSounds) {
      if (active.discord) active.discord.volume = masterVolume / 100
      if (active.monitor) active.monitor.volume = masterVolume / 100
    }
    saveState()
  })

  document.getElementById('discord-out').addEventListener('change', function () {
    discordOutputId = this.value; saveState()
  })

  document.getElementById('monitor-out').addEventListener('change', function () {
    monitorOutputId = this.value; saveState()
  })

  document.getElementById('search').addEventListener('input', function () {
    searchQuery = this.value; render()
  })

  document.getElementById('btn-minimize').addEventListener('click', () => ipcRenderer.send('window-minimize'))
  document.getElementById('btn-maximize').addEventListener('click', () => ipcRenderer.send('window-maximize'))
  document.getElementById('btn-close').addEventListener('click', () => ipcRenderer.send('window-close'))

  document.getElementById('modal-cancel').addEventListener('click', closeHotkeyModal)
  document.getElementById('modal-save').addEventListener('click', saveHotkey)

  document.getElementById('rename-cancel').addEventListener('click', closeRenameModal)
  document.getElementById('rename-save').addEventListener('click', saveRename)
  document.getElementById('rename-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') saveRename()
    if (e.key === 'Escape') closeRenameModal()
  })

  document.getElementById('myinstants-cancel').addEventListener('click', closeMyInstantsModal)
  document.getElementById('myinstants-import').addEventListener('click', importFromMyInstants)
  document.getElementById('myinstants-url').addEventListener('keydown', e => {
    if (e.key === 'Enter') importFromMyInstants()
    if (e.key === 'Escape') closeMyInstantsModal()
  })

  document.addEventListener('contextmenu', e => e.preventDefault())
}

// ── Start ─────────────────────────────────────────────────────────
init()
