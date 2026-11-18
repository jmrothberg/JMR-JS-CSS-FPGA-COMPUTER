// Headless acceptance against a locally served or hosted browser build.
const { chromium } = require(process.env.JMR_PLAYWRIGHT_PATH || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const url = process.env.JMR_BROWSER_URL || 'http://127.0.0.1:8783/';
const output = process.env.JMR_BROWSER_TEST_OUTPUT || 'build/browser-acceptance';
const htmlDisk = process.env.JMR_BROWSER_COMPILE_DISK;
const errors = [];

function verifyDisk(file, expected) {
  execFileSync(process.env.JMR_PYTHON || 'python3', ['-c', `
from pathlib import Path
import sys
from tools.make_sd_image import open_volume
from functional_model.jsb_format import ProgramImage
from functional_model.toolbox_rom import unpack_rom
from tools.toolbox_linker import prefix_bytes
volume = open_volume(Path(sys.argv[1]))
if sys.argv[2] == 'save':
    assert volume.read_file('WEBTEST.TXT') == b'Browser save proof'
else:
    assert prefix_bytes(ProgramImage(volume.read_file('WEBBUILD.JSH'))) == unpack_rom(volume.read_file('TOOLBOX.ROM'))
`, path.join(output, file), expected], { stdio: 'inherit' });
}

async function main() {
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.JMR_CHROME || '/usr/bin/google-chrome-stable' });
  const page = await browser.newPage({ viewport: { width: 950, height: 820 }, acceptDownloads: true });
  page.on('pageerror', error => errors.push(String(error)));
  page.on('dialog', dialog => dialog.accept()); // Only disposable test disks are mounted here.
  const screen = page.locator('#screen');
  const keyboard = page.getByRole('group', { name: 'On-screen keyboard' });
  const keyboardKey = name => keyboard.getByRole('button', { name, exact: true });
  const role = (n) => page.locator(`#screen[data-role="${n}"]`).waitFor({ timeout: 90000 });
  const rate = page.locator('#rate');
  const click = async (x, y) => {
    const box = await screen.boundingBox();
    await page.mouse.move(box.x + x * box.width / 640, box.y + y * box.height / 480);
    await page.mouse.down();
    await page.waitForTimeout(65);
    await page.mouse.up();
    await page.waitForTimeout(180);
  };
  const download = async (file) => {
    await page.getByRole('button', { name: 'Disk ▾' }).click();
    const event = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Download current disk' }).click();
    await (await event).saveAs(path.join(output, file));
  };
  const select = async text => {
    await page.keyboard.type(text, { delay: 110 });
    await page.waitForTimeout(300);
  };
  try {
    await page.goto(url);
    await role(9);
    const bootMs = Number(await screen.getAttribute('data-boot-ms'));
    await screen.screenshot({ path: path.join(output, 'finder.png') });
    assert(await keyboard.isVisible(), 'The typing keyboard should be visible by default');
    await click(205, 10); await click(230, 137);
    await role(1);
    await keyboardKey('Shift').click();
    await keyboardKey('B').click();
    await page.keyboard.type('rowser save proof', { delay: 45 });
    await click(60, 10); await click(80, 97);
    await page.waitForTimeout(550);
    for (let i = 0; i < 14; i++) await page.keyboard.press('Backspace', { delay: 45 });
    await page.keyboard.type('WEBTEST.TXT', { delay: 60 });
    await page.getByRole('button', { name: 'Game Enter' }).click();
    await page.waitForFunction(() => document.querySelector('#status').textContent.includes('Disk saved'));
    await download('saved.img');
    verifyDisk('saved.img', 'save');
    await page.getByRole('button', { name: 'Hide keyboard' }).click();
    assert(!await keyboard.isVisible());
    assert(await page.getByRole('button', { name: 'Game Space' }).isVisible());
    await page.reload(); await role(9);
    assert(!await keyboard.isVisible(), 'Reload should remember the hidden keyboard');
    await page.getByRole('button', { name: 'Show keyboard' }).click();
    assert(await keyboard.isVisible());
    await download('reopened.img');
    verifyDisk('reopened.img', 'save');
    console.log('Finder opened, Editor saved, and disk exported after reload.');

    await click(60, 194); await click(60, 194); await role(8);
    await page.keyboard.down('ArrowRight');
    const first = await screen.evaluate(canvas => canvas.toDataURL());
    await page.waitForTimeout(650);
    assert.notEqual(first, await screen.evaluate(canvas => canvas.toDataURL()), 'Game screen never advanced');
    await page.keyboard.up('ArrowRight');
    const rates = [];
    for (let i = 0; i < 3; i++) {
      await page.waitForTimeout(1100);
      rates.push(Number(await rate.getAttribute('data-hz')));
    }
    assert(rates.every(hz => hz > 0));
    console.log(JSON.stringify({ bootMs, boxesFramesPerSecond: rates }));
    await page.keyboard.press('Escape'); await role(9);

    await page.getByRole('button', { name: 'Sound off' }).click();
    await page.getByRole('button', { name: 'Sound on' }).waitFor();
    await select('SNDDEMO');
    await click(60, 10); await click(80, 55); // File → Open selected program.
    await role(8);
    await page.locator('#audio-button[data-guest-sound="played"]').waitFor();
    await page.keyboard.press('Escape'); await role(9);
    console.log('The Sound Demo sent guest commands through the browser PSG.');

    await click(205, 10); await click(230, 121); await role(3);
    await page.keyboard.press('Escape'); await role(9);
    if (htmlDisk) {
      await page.locator('#open-file').setInputFiles(htmlDisk);
      await page.waitForFunction(name => document.querySelector('#disk-name').textContent === name, path.basename(htmlDisk));
      await role(9);
      await screen.focus();
      await select('WEBB');
      await click(205, 10); await click(230, 121);
      await role(3);
      await page.waitForFunction(() => [8, 9].includes(Number(document.querySelector('#screen').dataset.role)), undefined, { timeout: 600000 });
      await download('compiled.img');
      verifyDisk('compiled.img', 'compile');
      console.log('Imported an uncompiled title and exported the disk after Compile.');
    }
    assert.deepEqual(errors, []);
    console.log('BROWSER_SMOKE_PASS');
  } catch (error) {
    console.error(await page.locator('#status').textContent(), await screen.getAttribute('data-role'), errors);
    await page.screenshot({ path: path.join(output, 'failure.png') });
    throw error;
  } finally {
    await browser.close();
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
