const screen = document.querySelector('#screen');
const display = document.querySelector('#display');
const context = screen.getContext('2d', { alpha: false });
const WIDTH = 640;
const HEIGHT = 480;
const FRAME_OFFSET = 2 + 3 * 256;
const FRAME_BYTES = WIDTH * HEIGHT;
const painted = context.createImageData(WIDTH, HEIGHT);
const pixels32 = new Uint32Array(painted.data.buffer);
const palette = new Uint32Array(256);
const screenStart = document.querySelector('#startup');
const startupText = document.querySelector('#startup-message');
const status = document.querySelector('#status');
const rate = document.querySelector('#rate');
const diskName = document.querySelector('#disk-name');
const diskButton = document.querySelector('#disk-button');
const diskMenu = document.querySelector('#disk-menu');
const inputFile = document.querySelector('#open-file');
const touchInput = document.querySelector('#touch-input');
const screenButton = document.querySelector('#screen-button');
const keyboardButton = document.querySelector('#keyboard-button');
const audioButton = document.querySelector('#audio-button');
const originalDiskName = diskName.textContent;
const pressed = new Map();
const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
let ready = false;
let firstFrame = false;
let bootTime = performance.now();
let keepsDisk = false;
let heldButtons = 0;
let pointerX = 320;
let pointerY = 240;
let audioContext;
let psg;

function draw(bytes) {
  for (let i = 0, j = 2; i < 256; i++, j += 3) {
    palette[i] = 0xff000000 | bytes[j + 2] << 16 | bytes[j + 1] << 8 | bytes[j];
  }
  if (bytes[0]) {
    pixels32.fill(0xff000000, 0, WIDTH * 24);
    for (let y = 24; y < HEIGHT; y++) {
      const src = FRAME_OFFSET + Math.min(479, Math.floor(((y - 24) + .5) * 480 / 456)) * WIDTH;
      for (let x = 0; x < WIDTH; x++) pixels32[y * WIDTH + x] = palette[bytes[src + x]];
    }
  } else {
    for (let i = 0; i < FRAME_BYTES; i++) pixels32[i] = palette[bytes[FRAME_OFFSET + i]];
  }
  const info = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let offset = FRAME_OFFSET + FRAME_BYTES;
  for (let i = 0; i < bytes[1]; i++) {
    const left = info.getInt16(offset, true);
    const top = info.getInt16(offset + 2, true);
    const w = info.getUint16(offset + 4, true);
    const h = info.getUint16(offset + 6, true);
    offset += 8;
    for (let y = Math.max(0, top); y < Math.min(HEIGHT, top + h); y++) {
      for (let x = Math.max(0, left); x < Math.min(WIDTH, left + w); x++) {
        const src = offset + ((y - top) * w + x - left) * 4;
        if (bytes[src + 3]) pixels32[y * WIDTH + x] = 0xff000000 | bytes[src + 2] << 16 | bytes[src + 1] << 8 | bytes[src];
      }
    }
    offset += w * h * 4;
  }
  context.putImageData(painted, 0, 0);
}

function fatal(message) {
  ready = false;
  screenStart.hidden = false;
  screenStart.classList.add('error');
  startupText.textContent = message;
  document.querySelector('#retry').hidden = false;
  status.textContent = 'Computer stopped';
  diskButton.disabled = keyboardButton.disabled = audioButton.disabled = true;
}

worker.addEventListener('error', event => fatal(event.message || 'The browser could not start the computer.'));
worker.addEventListener('message', ({ data }) => {
  switch (data.type) {
    case 'status':
      if (!firstFrame) startupText.textContent = data.message;
      status.textContent = data.message;
      break;
    case 'ready':
      diskName.textContent = data.name || `Build ${data.build}`;
      keepsDisk = data.storage;
      ready = true;
      diskButton.disabled = keyboardButton.disabled = audioButton.disabled = false;
      break;
    case 'frame':
      draw(data.pixels);
      screen.dataset.role = data.role;
      if (!firstFrame) {
        firstFrame = true;
        screen.dataset.bootMs = String(Math.round(performance.now() - bootTime));
        screenStart.hidden = true;
        status.textContent = keepsDisk ? 'Disk saves in this browser' : 'Download the disk to keep your changes';
      }
      break;
    case 'stats':
      rate.textContent = `${Math.round(data.hz)} fps`;
      rate.dataset.frameMs = data.ms.toFixed(2);
      rate.dataset.hz = data.hz.toFixed(2);
      break;
    case 'sound':
      if (psg && audioContext.state === 'running') {
        psg.port.postMessage({ payload: data.payload, clear: data.clear });
        if (data.payload?.length) audioButton.dataset.guestSound = 'played';
      }
      break;
    case 'saved':
      if (firstFrame) status.textContent = 'Disk saved in this browser';
      break;
    case 'storage-error':
    case 'media-error':
      status.textContent = data.message;
      break;
    case 'media':
      diskName.textContent = data.name;
      firstFrame = false;
      bootTime = performance.now();
      delete screen.dataset.role;
      startupText.textContent = 'Starting Finder…';
      screenStart.hidden = false;
      break;
    case 'disk-image': {
      const url = URL.createObjectURL(new Blob([data.bytes], { type: 'application/octet-stream' }));
      const link = document.createElement('a');
      link.href = url;
      link.download = 'jmr-js-card.img';
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 30_000);
      break;
    }
    case 'fatal':
      fatal(data.message);
      break;
  }
});

function codeFor(event) {
  const codes = { Backspace: 8, Tab: 9, Enter: 13, Shift: 16, Control: 17, Alt: 18,
    Escape: 27, ' ': 32, End: 35, Home: 36, ArrowLeft: 37, ArrowUp: 38,
    ArrowRight: 39, ArrowDown: 40, Delete: 46, Meta: 91 };
  const punctuation = { Semicolon: 186, Equal: 187, Comma: 188, Minus: 189,
    Period: 190, Slash: 191, Backquote: 192, BracketLeft: 219, Backslash: 220,
    BracketRight: 221, Quote: 222, NumpadDecimal: 190 };
  if (codes[event.key]) return codes[event.key];
  if (punctuation[event.code]) return punctuation[event.code];
  if (/^F(?:[1-9]|1[0-2])$/.test(event.key)) return 111 + Number(event.key.slice(1));
  if (/^Key[A-Z]$/.test(event.code)) return event.code.charCodeAt(3);
  if (/^Digit[0-9]$/.test(event.code)) return event.code.charCodeAt(5);
  if (event.key.length === 1 && event.key.charCodeAt(0) < 128) return event.key.toUpperCase().charCodeAt(0);
  return 0;
}

function sendKey(code, key, down) {
  worker.postMessage({ type: 'key', code, key, down });
}

function tap(code, key) {
  sendKey(code, key, true);
  sendKey(code, key, false);
}

screen.addEventListener('keydown', event => {
  if (!ready || event.key === 'Tab' && ![1, 5].includes(Number(screen.dataset.role))) return;
  const code = codeFor(event);
  if (!code) return;
  const shortcuts = { a: 142, c: 139, x: 138, z: 137 };
  if (event.ctrlKey || event.metaKey) {
    const edit = Number(screen.dataset.role) === 1;
    const shortcut = shortcuts[event.key.toLowerCase()];
    if (edit && shortcut) {
      event.preventDefault();
      if (!event.repeat) tap(shortcut, '');
      return;
    }
    if (event.key.length === 1) return;
  }
  event.preventDefault();
  if (event.key === 'Escape' && event.repeat) return;
  const id = event.code || event.key;
  pressed.set(id, { code, key: event.key });
  sendKey(code, event.key, true);
});

screen.addEventListener('keyup', event => {
  const id = event.code || event.key;
  const key = pressed.get(id);
  if (!key) return;
  event.preventDefault();
  pressed.delete(id);
  sendKey(key.code, key.key, false);
});

function typeText(text, useEditorPaste = true) {
  const chars = text.replace(/\r\n?/g, '\n').replaceAll('\t', '  ').slice(0, 65536);
  const editor = useEditorPaste && [1, 5].includes(Number(screen.dataset.role));
  const keys = [];
  if (editor) keys.push([117, '']); // Guest Editor paste begin (F6).
  for (const char of chars) {
    if (char === '\n') keys.push([13, 'Enter']);
    else if (char >= ' ' && char <= '~') {
      keys.push([editor ? char.charCodeAt(0) : char === '.' ? 190 : char.toUpperCase().charCodeAt(0), char]);
    }
  }
  if (editor) keys.push([118, '']); // Guest Editor paste end (F7).
  worker.postMessage({ type: 'paste', keys });
}

screen.addEventListener('paste', event => {
  if (!ready) return;
  event.preventDefault();
  typeText(event.clipboardData.getData('text/plain'));
});

keyboardButton.addEventListener('click', () => touchInput.focus({ preventScroll: true }));
touchInput.addEventListener('input', () => {
  if (touchInput.value) typeText(touchInput.value, false);
  touchInput.value = '';
});
touchInput.addEventListener('beforeinput', event => {
  if (event.inputType === 'deleteContentBackward') { event.preventDefault(); tap(8, 'Backspace'); }
});

audioButton.addEventListener('click', async () => {
  audioButton.disabled = true;
  try {
    if (!audioContext) audioContext = new AudioContext();
    if (audioContext.state === 'running' && psg) {
      await audioContext.suspend();
      psg.port.postMessage({ clear: true });
    } else {
      await audioContext.resume();
      if (!psg) {
        await audioContext.audioWorklet.addModule(new URL('./psg.js', import.meta.url));
        psg = new AudioWorkletNode(audioContext, 'jmr-psg', { numberOfInputs: 0, outputChannelCount: [1] });
        psg.connect(audioContext.destination);
      }
    }
    const on = audioContext.state === 'running';
    audioButton.textContent = on ? 'Sound on' : 'Sound off';
    audioButton.setAttribute('aria-pressed', String(on));
  } catch {
    status.textContent = 'Audio is unavailable in this browser.';
  } finally {
    audioButton.disabled = false;
    screen.focus({ preventScroll: true });
  }
});

function mouseMessage(edge = true) {
  if (ready) worker.postMessage({ type: 'mouse', x: pointerX, y: pointerY, buttons: heldButtons, edge });
}

function pointer(event, edge) {
  const area = screen.getBoundingClientRect();
  pointerX = Math.max(0, Math.min(639, Math.floor((event.clientX - area.left) * WIDTH / area.width)));
  pointerY = Math.max(0, Math.min(479, Math.floor((event.clientY - area.top) * HEIGHT / area.height)));
  heldButtons = event.buttons & 7;
  mouseMessage(edge);
}

screen.addEventListener('pointermove', event => pointer(event, false));
screen.addEventListener('pointerdown', event => {
  screen.focus({ preventScroll: true });
  screen.setPointerCapture(event.pointerId);
  pointer(event, true);
});
screen.addEventListener('pointerup', event => pointer(event, true));
screen.addEventListener('pointercancel', () => { heldButtons = 0; mouseMessage(); });
screen.addEventListener('contextmenu', event => event.preventDefault());

function releaseInput() {
  for (const { code, key } of pressed.values()) sendKey(code, key, false);
  pressed.clear();
  if (heldButtons) { heldButtons = 0; mouseMessage(); }
}
window.addEventListener('blur', releaseInput);
screen.addEventListener('blur', releaseInput);

function showDiskMenu(open) {
  diskMenu.hidden = !open;
  diskButton.setAttribute('aria-expanded', String(open));
}
diskButton.addEventListener('click', () => showDiskMenu(diskMenu.hidden));
document.addEventListener('click', event => {
  if (!diskMenu.contains(event.target) && event.target !== diskButton) showDiskMenu(false);
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && !diskMenu.hidden) { showDiskMenu(false); diskButton.focus(); }
});

document.querySelector('#open-button').addEventListener('click', () => {
  showDiskMenu(false);
  inputFile.click();
});
inputFile.addEventListener('change', async () => {
  const [file] = inputFile.files;
  inputFile.value = '';
  if (!file) return;
  if (file.size > 128 * 1024 * 1024) { status.textContent = 'Choose a disk image up to 128 MiB.'; return; }
  if (!window.confirm('Open this disk in place of the current one? Download the current disk first if you want to keep its changes.')) return;
  const image = await file.arrayBuffer();
  worker.postMessage({ type: 'open', name: file.name, image }, [image]);
});
document.querySelector('#download-button').addEventListener('click', () => {
  showDiskMenu(false);
  worker.postMessage({ type: 'download' });
});
document.querySelector('#reset-button').addEventListener('click', () => {
  showDiskMenu(false);
  if (window.confirm(`Replace your browser disk with the original ${originalDiskName} disk?`)) worker.postMessage({ type: 'reset' });
});
screenButton.addEventListener('click', async () => {
  try {
    if (document.fullscreenElement) await document.exitFullscreen();
    else await display.requestFullscreen();
    screen.focus({ preventScroll: true });
  } catch { status.textContent = 'Full screen is unavailable in this browser.'; }
});
document.addEventListener('fullscreenchange', () => {
  screenButton.textContent = document.fullscreenElement ? 'Exit full screen' : 'Full screen';
});
document.querySelector('#retry').addEventListener('click', () => location.reload());
