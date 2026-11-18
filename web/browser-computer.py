"""Browser I/O for the shared Python machine and the real FAT32 card."""
import os
import struct
from pathlib import Path

from functional_model.machine import Machine
from functional_model.memory import Memory
from functional_model.storage_engine import StorageEngine
from functional_model.toolbox_rom import unpack_rom
from functional_model.jsb_format import ProgramImage, FLAG_TOOLBOX
from hardware_model.fat32 import Fat32Volume
from hardware_model.sd_spi import SECTOR_SIZE
from runtime.backend import PythonBackend


class MemoryCard:
    """The FAT32 engine uses sectors directly in the browser."""

    initialised = True

    def __init__(self, image):
        if not 16 * 1024 * 1024 <= len(image) <= 128 * 1024 * 1024 or len(image) % SECTOR_SIZE:
            raise ValueError('Choose a 16–128 MiB JMR FAT32 card image.')
        self.image = image
        self.original_sectors = {}

    @property
    def sector_count(self):
        return len(self.image) // SECTOR_SIZE

    def read_block(self, lba):
        if not 0 <= lba < self.sector_count:
            raise OSError('Card sector out of bounds')
        offset = lba * SECTOR_SIZE
        return bytes(self.image[offset:offset + SECTOR_SIZE])

    def write_block(self, lba, data):
        if len(data) != SECTOR_SIZE:
            raise ValueError('Expected one card sector')
        previous = self.read_block(lba)
        if previous != data:
            self.original_sectors.setdefault(lba, previous)
            offset = lba * SECTOR_SIZE
            self.image[offset:offset + SECTOR_SIZE] = data

    def apply_saved_sectors(self, patches):
        record_size = 4 + SECTOR_SIZE
        if len(patches) % record_size:
            raise ValueError('Incomplete saved disk sector')
        for offset in range(0, len(patches), record_size):
            lba, = struct.unpack_from('<I', patches, offset)
            self.write_block(lba, patches[offset + 4:offset + record_size])
        self.original_sectors.clear()


class BrowserStorage(StorageEngine):
    def __init__(self, image, patches, presence_path):
        self.card_img = Path(presence_path)
        self.card = MemoryCard(image)
        self.card.apply_saved_sectors(patches)
        self.dirty = set()
        self._open_volume()

    def _open_volume(self):
        memory = Memory()
        self.volume = Fat32Volume(memory, self.card)
        self.volume.mount()

    def _mount(self):
        return self.volume

    def _persist_card(self, volume):
        self.dirty.update(self.card.original_sectors)
        self.card.original_sectors.clear()

    def _write(self, operation, *args):
        try:
            operation(*args)
        except Exception:
            for lba, data in self.card.original_sectors.items():
                start = lba * SECTOR_SIZE
                self.card.image[start:start + SECTOR_SIZE] = data
            self.card.original_sectors.clear()
            self._open_volume()
            raise

    def save_text(self, name, text):
        self._write(super().save_text, name, text)

    def save_bytes(self, name, data):
        self._write(super().save_bytes, name, data)

    def append_bytes(self, name, data):
        self._write(super().append_bytes, name, data)

    def delete(self, name):
        self._write(super().delete, name)

    def take_changes(self):
        result = bytearray()
        for lba in sorted(self.dirty):
            result.extend(struct.pack('<I', lba))
            result.extend(self.card.read_block(lba))
        self.dirty.clear()
        return result


class BrowserComputer:
    def __init__(self, card_path='/card.img', patch_path='/patches.bin', presence_path=None):
        os.environ['JMR_FINDER'] = 'program'
        os.environ.pop('JMR_HTML_DUKPY', None)
        # Read into the mutable image without retaining a second Python copy.
        file = Path(card_path)
        image = bytearray(file.stat().st_size)
        with file.open('rb') as stream:
            if stream.readinto(image) != len(image):
                raise OSError('Short read while opening card')
        patches = Path(patch_path)
        self.storage = BrowserStorage(image, patches.read_bytes() if patches.is_file() else b'', presence_path or file)
        rom = unpack_rom(self.storage.load_bytes('TOOLBOX.ROM'))
        finder = ProgramImage(self.storage.load_bytes('FINDER.JSH'))
        self.storage.load_bytes('SYSTEM.SYS')
        if not finder.flags & FLAG_TOOLBOX:
            raise ValueError('The card is missing the resident Finder program.')
        from tools.toolbox_linker import prefix_bytes
        if prefix_bytes(finder) != rom:
            raise ValueError('FINDER.JSH and TOOLBOX.ROM are from different builds.')
        self.machine = Machine()
        self.machine.storage = self.storage
        self.machine.sound_output = self.sound_poke
        self.sounds = {}
        self.backend = PythonBackend(self.machine)
        self.last_frame = None

    def tick(self):
        self.backend.frame_tick()

    def mouse(self, x, y, buttons):
        self.backend.set_mouse(x, y, buttons)

    def key(self, code, label, pressed):
        if code == 27:
            if pressed:
                self.backend.push_key('\x1b')
                self.backend.hard_break()
        else:
            self.backend.key_event(code, label, pressed)

    def role(self):
        return self.machine.system_window[0]

    def pending_file_work(self):
        return self.machine.system_compiling or (self.machine._edit_active and self.machine._cmp_done)

    def sound_poke(self, channel, frequency, volume, frames, slide):
        self.sounds[channel] = struct.pack('<BHBBb', channel, frequency, volume, frames, slide)

    def take_sound(self):
        events = bytearray().join(self.sounds.values())
        self.sounds.clear()
        return events

    def take_frame(self):
        canvas = self.backend.framebuffer()
        overlays = getattr(canvas, 'display_overlays', ())
        frame = bytearray((bool(getattr(canvas, 'display_game_viewport', False)), len(overlays)))
        frame.extend(channel for rgb in canvas.palette for channel in rgb)
        frame.extend(canvas.front)
        for x, y, width, height, pixels in overlays:
            frame.extend(struct.pack('<hhHH', x, y, width, height))
            frame.extend(pixels)
        if frame == self.last_frame:
            return None
        self.last_frame = frame
        return frame

    def take_changes(self):
        return self.storage.take_changes()

    def disk_image(self):
        return self.storage.card.image

    def close(self):
        self.machine.trace.close()
