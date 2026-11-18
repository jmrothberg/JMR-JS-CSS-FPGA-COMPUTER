import { openDiskStore, readDisk, saveDisk } from './disk-store.js';

const PERIOD = 1000 / 60;
const RECORD_BYTES = 516;
const MAX_IMAGE_BYTES = 128 * 1024 * 1024;
const media = new URL('./', import.meta.url);
let python;
let computer;
let release;
let database;
let diskKey;
let disk;
let saveQueue = Promise.resolve();
let hasWriteLock = false;
let actions = [];
let timer;
let deadline;
let statsFrom;
let frames = 0;
let work = 0;
let initializing = true;
let lastRole = 0;
let firstTick = true;
let downloadPending = false;

function status(message) {
  postMessage({ type: 'status', message });
}

async function get(name) {
  const response = await fetch(new URL(name, media));
  if (!response.ok) throw new Error(`Could not load ${name} (${response.status}).`);
  return response;
}

function copyBytes(proxy) {
  if (proxy == null) return null;
  const buffer = proxy.getBuffer('u8');
  try {
    return buffer.data.slice();
  } finally {
    buffer.release();
    proxy.destroy();
  }
}

async function assertDigest(bytes, expected, label) {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  const hex = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
  if (hex !== expected) throw new Error(`The bundled ${label} checksum did not match.`);
}

async function bundledDisk() {
  const response = await get('card.img.gz');
  const reader = response.body.pipeThrough(new DecompressionStream('gzip')).getReader();
  const bytes = new Uint8Array(release.cardBytes);
  let offset = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes.set(value, offset);
      offset += value.length;
    }
    if (offset !== bytes.length) throw new Error('The bundled disk is incomplete.');
  } finally {
    reader.releaseLock();
  }
  await assertDigest(bytes, release.cardSHA256, 'disk');
  return bytes;
}

function patchImage(sectors) {
  const data = new Uint8Array(sectors.size * RECORD_BYTES);
  const view = new DataView(data.buffer);
  let offset = 0;
  for (const [lba, sector] of sectors) {
    view.setUint32(offset, lba, true);
    data.set(sector, offset + 4);
    offset += RECORD_BYTES;
  }
  return data;
}

function loadComputer(image, patches) {
  if (image.byteLength > MAX_IMAGE_BYTES) throw new Error('The largest supported disk is 128 MiB.');
  python.FS.writeFile('/incoming.img', image);
  python.FS.writeFile('/incoming.bin', patchImage(patches));
  try {
    const next = python.runPython("BrowserComputer('/incoming.img', '/incoming.bin', '/card.img')");
    if (computer) {
      computer.close();
      computer.destroy();
    }
    computer = next;
  } finally {
    python.FS.unlink('/incoming.img');
    python.FS.unlink('/incoming.bin');
  }
}

async function lockDisk() {
  if (!navigator.locks) return false;
  return new Promise(resolve => {
    navigator.locks.request('jmr-js-disk-writer', { ifAvailable: true }, async lock => {
      resolve(Boolean(lock));
      if (lock) await new Promise(() => {});
    }).catch(() => resolve(false));
  });
}

function queueSave() {
  if (!database || !hasWriteLock) return;
  // Snapshot the map now. Writes arriving before this transaction starts
  // belong to a later snapshot, and cannot overtake it.
  const snapshot = { ...disk, sectors: new Map(disk.sectors) };
  saveQueue = saveQueue.then(() => saveDisk(database, diskKey, snapshot)).then(() => {
    postMessage({ type: 'saved' });
  }).catch(() => {
    postMessage({ type: 'storage-error', message: 'Browser storage could not save the disk. Download it to keep your changes.' });
  });
}

function collectChanges() {
  const data = copyBytes(computer.take_changes());
  if (!data?.length) return;
  const view = new DataView(data.buffer);
  for (let offset = 0; offset < data.length; offset += RECORD_BYTES) {
    disk.sectors.set(view.getUint32(offset, true), data.slice(offset + 4, offset + RECORD_BYTES));
  }
  queueSave();
}

function schedule() {
  if (!computer || initializing) return;
  const now = performance.now();
  if (deadline < now - PERIOD) deadline = now;
  timer = setTimeout(tick, Math.max(0, deadline - now));
}

function tick() {
  try {
    const start = performance.now();
    const inputs = actions.splice(0, 32);
    for (const input of inputs) {
      if (input.type === 'mouse') computer.mouse(input.x, input.y, input.buttons);
      else {
        computer.key(input.code, input.key, input.down);
        if (input.tap) computer.key(input.code, input.key, false);
      }
    }
    computer.tick();
    const pixels = copyBytes(computer.take_frame());
    const role = computer.role();
    if (pixels) postMessage({ type: 'frame', pixels, role }, [pixels.buffer]);
    const sound = copyBytes(computer.take_sound());
    if (sound?.length || lastRole !== role) {
      postMessage({ type: 'sound', payload: sound, clear: lastRole !== role }, [sound.buffer]);
    }
    lastRole = role;
    collectChanges();
    if (downloadPending && !actions.length && !computer.pending_file_work()) {
      downloadPending = false;
      const bytes = copyBytes(computer.disk_image());
      postMessage({ type: 'disk-image', bytes }, [bytes.buffer]);
    }
    const now = performance.now();
    if (firstTick) {
      firstTick = false;
      statsFrom = now;
    } else {
      frames++;
      work += now - start;
      if (now - statsFrom >= 1000) {
        postMessage({ type: 'stats', hz: frames * 1000 / (now - statsFrom), ms: work / frames });
        statsFrom = now;
        frames = work = 0;
      }
    }
    deadline += PERIOD;
    schedule();
  } catch (error) {
    postMessage({ type: 'fatal', message: String(error.message || error) });
  }
}

async function openMedia(action) {
  if (initializing) return;
  initializing = true;
  clearTimeout(timer);
  actions = [];
  downloadPending = false;
  try {
    await saveQueue;
    status('Opening the disk…');
    const image = action.type === 'reset' ? await bundledDisk() : new Uint8Array(action.image);
    loadComputer(image, new Map());
    firstTick = true;
    disk = {
      image: action.type === 'reset' ? null : image.buffer,
      name: action.type === 'reset' ? null : action.name,
      sectors: new Map(),
    };
    queueSave();
    status('Starting Finder…');
    postMessage({ type: 'media', name: disk.name || `Build ${release.build}` });
  } catch (error) {
    postMessage({ type: 'media-error', message: String(error.message || error) });
  } finally {
    initializing = false;
    deadline = statsFrom = performance.now();
    frames = work = 0;
    schedule();
  }
}

self.onmessage = ({ data }) => {
  if (data.type === 'open' || data.type === 'reset') {
    void openMedia(data);
  } else if (data.type === 'download' && computer && !initializing) {
    downloadPending = true;
  } else if (data.type === 'paste' && !initializing) {
    for (const [code, key] of data.keys) actions.push({ type: 'key', code, key, down: true, tap: true });
  } else if ((data.type === 'mouse' || data.type === 'key') && !initializing) {
    const last = actions.at(-1);
    if (data.type === 'mouse' && !data.edge && last?.type === 'mouse' && !last.edge && last.buttons === data.buttons) {
      actions[actions.length - 1] = data;
    } else {
      actions.push(data);
    }
  }
};

async function boot() {
  release = await (await get('release.json')).json();
  diskKey = `card-${release.cardSHA256}`;
  const cdn = `https://cdn.jsdelivr.net/pyodide/v${release.pyodide}/full/`;
  hasWriteLock = await lockDisk();
  try {
    database = await openDiskStore();
    disk = await readDisk(database, diskKey);
  } catch {
    database = null;
  }
  disk ??= { image: null, sectors: new Map() };
  status('Loading the computer and its disk…');
  const [runtime, source, image] = await Promise.all([
    import(`${cdn}pyodide.mjs`).then(({ loadPyodide }) => loadPyodide({ indexURL: cdn })),
    get('computer.zip').then(async response => {
      const bytes = await response.arrayBuffer();
      await assertDigest(bytes, release.modelSHA256, 'computer model');
      return bytes;
    }),
    disk.image ? new Uint8Array(disk.image) : bundledDisk(),
  ]);
  python = runtime;
  python.FS.mkdir('/computer');
  python.unpackArchive(source, 'zip', { extractDir: '/computer' });
  // The shared storage policy checks this path for card presence. The
  // contents are in the mounted in-memory FAT volume after startup.
  python.FS.writeFile('/card.img', new Uint8Array());
  python.runPython("import os, sys\nos.chdir('/computer')\nsys.path.insert(0, '/computer')\nfrom browser_computer import BrowserComputer");
  status('Starting Finder…');
  loadComputer(image, disk.sectors);
  postMessage({ type: 'ready', build: release.build, name: disk.name, storage: Boolean(database && hasWriteLock) });
  initializing = false;
  deadline = statsFrom = performance.now();
  schedule();
}

boot().catch(error => postMessage({ type: 'fatal', message: String(error.message || error) }));
