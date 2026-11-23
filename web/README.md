# Browser build

## Two browser versions

**Native JavaScript** runs the programs as ordinary JavaScript in Chrome.
**Machine emulator** emulates the real machine: it runs the same compiled
bytecode the board runs.

| | Native JavaScript | Machine emulator |
|---|---|---|
| Page | `web/native.html` | `web/index.html`, built into `build/browser-preview/` |
| Runs | Finder, Toolbox and program **JavaScript source**, directly in Chrome | The compiled **`.JSH` bytecode**, in the Python hardware model (WebAssembly) |
| Speed | Starts in about a second, programs at 60 fps | Starts in about 20 seconds, heavy programs run slower |
| Board limits and faults | Not enforced | Same as the boards |
| Saves | Kept until the page reloads | Saved in the browser; download the disk |
| On-screen arrows and keyboard (iPad, iPhone) | Available; shown by default on touch screens | Available |
| Compile | Not available | Available |
| Build step | None: reads `card.img`, `storage/`, `resources/toolbox/` | `web/build.py` |

Use Native JavaScript to try programs quickly. Use the machine emulator (or
PYTHON, FPGA-SIM and the board) to confirm a program fits the machine.

### Run either one locally

From the project root:

```sh
python3 web/serve.py            # prints both links
python3 web/serve.py --build    # rebuild the machine emulator first
```

- Native JavaScript: <http://127.0.0.1:8790/web/native.html>
- Machine emulator: <http://127.0.0.1:8790/build/browser-preview/>

The server sends every file uncached, so a reload picks up edits to
`storage/*.HTML`, `card.img` or `web/native.js`. Ctrl+C stops it.

### Online

- Machine emulator: [jmr-js-computer.jonathan-rothberg.chatgpt.site](https://jmr-js-computer.jonathan-rothberg.chatgpt.site/)
  (published with the steps below).
- Native JavaScript: [GitHub Pages](https://jmrothberg.github.io/JMR-JS-CSS-FPGA-COMPUTER/web/native.html).
  GitHub Pages serves the repository as it is, so every push to `main`
  updates it. It is turned on once in the repository's **Settings → Pages**
  (Deploy from a branch, `main`, `/ (root)`), with an empty `.nojekyll` file
  in the project root so GitHub publishes the files without processing them.

### How the Native JavaScript version works

`web/native.js` runs each program in its own blank page and supplies the
machine's natives as JavaScript: the arena, the Toolbox bulk operations,
card files, launching, `cdone` handoffs, sound, and the Enterprise system
menu. The screen is the machine's 8-bit indexed 640×480 framebuffer. The
reference code it follows is listed at the top of `native.js`. In DevTools,
`(await import('/web/native.js')).M.request = {name: 'GAUNT.HTM', how: 0}`
starts a program by name.

## Machine emulator

The browser boots the project `card.img` into the same `FINDER.JSH`, Toolbox,
menus, Editor, Compiler, and programs used on the boards. The packaged Python
hardware model runs the guest `.JSH` instructions in a WebAssembly worker.
The page draws its indexed framebuffer and forwards browser input. Disk
access uses the shared FAT32 implementation over in-memory sectors.

Browser saves are FAT32 sector changes stored in IndexedDB. One tab at a
time owns writes to browser storage. Use **Disk → Download current disk**
to get a raw `.img` that can be reopened on the site or written to a microSD.
**Open disk image** accepts a compatible JMR card. **Reset to original disk**
starts a fresh copy of the packaged image after confirmation.
Each starter disk revision has its own browser storage. Export your disk to
carry your changes to a different build or a different browser.

The game keypad sends arrow keys, Space, and Enter to the guest. You can
hold a direction while pressing an action. The typing keyboard starts
visible. **Hide keyboard** puts it away and remembers the choice in that
browser. Both sets of controls are available in full screen.

Sound uses the guest `sound()` command and a browser implementation of the
four FPGA PSG voices. Enable it with the Sound button.

## Build and preview

From the project root, keep `CURRENT_SET.json`, the model, and `card.img`
matched as usual. The browser builder reads those files directly, verifies
them, and creates a compact static bundle with checksums for the uncompressed
disk and model archive. The source disk is read only during packaging.

```sh
.venv/bin/python web/build.py
python3 -m http.server 8783 --bind 127.0.0.1 --directory build/browser-preview
```

Open [localhost port 8783](http://127.0.0.1:8783/). The worker loads a pinned
[Pyodide WebAssembly runtime](https://pyodide.org/en/0.29.4/usage/webworker.html).
The app needs a recent browser and HTTPS or localhost.

## Publish after updating the shared build

Generate a fresh static `dist/` for the existing Site using the public origin
for social metadata. The Site identity is recorded in
[`web/.openai/hosting.json`](.openai/hosting.json). Reuse that identity when
refreshing the published release.

```sh
.venv/bin/python web/build.py --out build/browser-site-source/dist \
  --origin https://jmr-js-computer.jonathan-rothberg.chatgpt.site
```

The hosting checkout contains that `dist/` and the Site manifest. Publish
them together as one version. New machine, Toolbox, or card changes flow
from the main project through this build command. `web/` owns the browser
inputs, display and audio adapters, and hosting assets.

## Verify

`test-browser.cjs` runs with Node and Playwright. It checks the actual browser
boot, Editor save, export after reload, game frames, sound commands, and
Compile. `JMR_BROWSER_URL` can point it at a hosted release. Set
`JMR_BROWSER_COMPILE_DISK` to a disposable build 99 disk containing
`WEBBUILD.HTM` to exercise compiling a new program rather than just opening
the Compiler.

This runtime advances the guest at up to 60 frames per second. Boot and
heavy guest programs depend on the browser and host CPU. It models the guest
machine and FAT32 disk. Use the board-specific tests in the main project for
FPGA pin timing and physical interfaces.
