// Joy stick demo — mouse maps to joy() in PYTHON / FPGA-SIM GUI.
clear(0);
let x = 300;
let y = 220;
// One-shot draw; GUI demos can re-RUN. Full game loop needs rAF later.
fillRect(x, y, 40, 40, 3);
console.log("JOY DEMO — move mouse, RUN again to redraw (joy bits in MEM)");
