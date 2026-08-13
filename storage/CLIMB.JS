// NEW: keyUp/keyDown smoke for platformers (DONKEY path) — FPGA-SIM bytecode
clear(0);
let y = 100;
if (keyUp()) {
  y = 40;
}
if (keyDown()) {
  y = 160;
}
fillRect(300, y, 40, 40, 3);
swapBuffers();
startLoop();
