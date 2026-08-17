<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Joystick demo — JMR</title></head>
<body style="margin:0;background:#000">
<!-- LOAD "JOYDEMO.HTML" then RUN. Stick / arrows / WASD move; Space fire. -->
<canvas id="gameCanvas" width="640" height="480"></canvas>
<script>
var canvas = document.querySelector("canvas");
var c = canvas.getContext("2d");
c.imageSmoothingEnabled = false;

var W = 640;
var H = 480;
var x = 300;
var y = 220;
var fire = 0;
var leftHeld = 0;
var rightHeld = 0;
var upHeld = 0;
var downHeld = 0;
var fireHeld = 0;

console.log("JOY DEMO");

addEventListener("keydown", function (e) {
  var k = e.key;
  if (k === "ArrowLeft" || k === "a" || k === "A") leftHeld = 1;
  if (k === "ArrowRight" || k === "d" || k === "D") rightHeld = 1;
  if (k === "ArrowUp" || k === "w" || k === "W") upHeld = 1;
  if (k === "ArrowDown" || k === "s" || k === "S") downHeld = 1;
  if (k === " " || k === "Enter") fireHeld = 1;
});
addEventListener("keyup", function (e) {
  var k = e.key;
  if (k === "ArrowLeft" || k === "a" || k === "A") leftHeld = 0;
  if (k === "ArrowRight" || k === "d" || k === "D") rightHeld = 0;
  if (k === "ArrowUp" || k === "w" || k === "W") upHeld = 0;
  if (k === "ArrowDown" || k === "s" || k === "S") downHeld = 0;
  if (k === " " || k === "Enter") fireHeld = 0;
});

function bits() {
  var j = 0;
  try {
    j = joy() | 0;
  } catch (e) {
    j = 0;
  }
  return j;
}

function loop() {
  var j = bits();
  var l = leftHeld || (j & 4);
  var r = rightHeld || (j & 8);
  var u = upHeld || (j & 1);
  var d = downHeld || (j & 2);
  fire = fireHeld || (j & 16);
  if (l) x = x - 4;
  if (r) x = x + 4;
  if (u) y = y - 4;
  if (d) y = y + 4;
  if (x < 8) x = 8;
  if (x > W - 48) x = W - 48;
  if (y < 40) y = 40;
  if (y > H - 48) y = H - 48;

  c.fillStyle = "#000000";
  c.fillRect(0, 0, W, H);
  c.fillStyle = fire ? "#FFFF00" : "#3DFF9A";
  c.fillRect(x, y, 40, 40);
  c.fillStyle = "#FFFFFF";
  c.fillText("JOY DEMO", 8, 16);
  c.fillText("ARROWS / WASD / STICK   SPACE FIRE", 8, 32);
  c.fillText("U" + u + " D" + d + " L" + l + " R" + r + " F" + fire + " JOY " + j, 8, 464);
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);
</script>
</body>
</html>
