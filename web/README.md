# Browser build

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
