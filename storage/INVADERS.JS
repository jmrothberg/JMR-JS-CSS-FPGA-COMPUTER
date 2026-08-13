// SPACE INVADERS - JMR JS Canvas test
// Controls: Arrow Left / Arrow Right / Space (fire) / ESC quit
// LOAD INVADERS.JS then RUN in the monitor (GUI recommended).

let inited = 0;
let px = 300;
let bx = 0;
let by = 0;
let bullet = 0;
let cool = 0;
let ax = 40;
let adir = 1;
let step = 0;
let score = 0;
let alive0 = 1;
let alive1 = 1;
let alive2 = 1;
let alive3 = 1;
let alive4 = 1;
let alive5 = 1;
let alive6 = 1;
let alive7 = 1;
let row = 80;
let col = 0;

if (inited == 0) {
    console.log("SPACE INVADERS - arrows + space, ESC quit");
    inited = 1;
}

clear(0);

// player
if (keyLeft()) {
    px = px - 5;
}
if (keyRight()) {
    px = px + 5;
}
if (px < 8) {
    px = 8;
}
if (px > 600) {
    px = 600;
}

// fire
if (cool > 0) {
    cool = cool - 1;
}
if (keyFire()) {
    if (bullet == 0) {
        if (cool == 0) {
            bullet = 1;
            bx = px + 12;
            by = 430;
            cool = 12;
        }
    }
}

if (bullet == 1) {
    by = by - 8;
    if (by < 0) {
        bullet = 0;
    }
}

// aliens march
step = step + 1;
if (step > 20) {
    step = 0;
    ax = ax + adir * 12;
    if (ax > 120) {
        adir = 0 - 1;
        row = row + 12;
    }
    if (ax < 20) {
        adir = 1;
        row = row + 12;
    }
}

// bullet vs aliens (row of 8)
if (bullet == 1) {
    if (by > row) {
        if (by < row + 20) {
            col = 0;
            col = bx - ax;
            if (col >= 0) {
                if (col < 48) {
                    if (alive0 == 1) {
                        alive0 = 0;
                        bullet = 0;
                        score = score + 10;
                    }
                }
                if (col >= 48) {
                    if (col < 96) {
                        if (alive1 == 1) {
                            alive1 = 0;
                            bullet = 0;
                            score = score + 10;
                        }
                    }
                }
                if (col >= 96) {
                    if (col < 144) {
                        if (alive2 == 1) {
                            alive2 = 0;
                            bullet = 0;
                            score = score + 10;
                        }
                    }
                }
                if (col >= 144) {
                    if (col < 192) {
                        if (alive3 == 1) {
                            alive3 = 0;
                            bullet = 0;
                            score = score + 10;
                        }
                    }
                }
                if (col >= 192) {
                    if (col < 240) {
                        if (alive4 == 1) {
                            alive4 = 0;
                            bullet = 0;
                            score = score + 10;
                        }
                    }
                }
                if (col >= 240) {
                    if (col < 288) {
                        if (alive5 == 1) {
                            alive5 = 0;
                            bullet = 0;
                            score = score + 10;
                        }
                    }
                }
                if (col >= 288) {
                    if (col < 336) {
                        if (alive6 == 1) {
                            alive6 = 0;
                            bullet = 0;
                            score = score + 10;
                        }
                    }
                }
                if (col >= 336) {
                    if (col < 384) {
                        if (alive7 == 1) {
                            alive7 = 0;
                            bullet = 0;
                            score = score + 10;
                        }
                    }
                }
            }
        }
    }
}

// draw aliens
if (alive0 == 1) {
    fillRect(ax + 0, row, 36, 16, 3);
}
if (alive1 == 1) {
    fillRect(ax + 48, row, 36, 16, 3);
}
if (alive2 == 1) {
    fillRect(ax + 96, row, 36, 16, 3);
}
if (alive3 == 1) {
    fillRect(ax + 144, row, 36, 16, 3);
}
if (alive4 == 1) {
    fillRect(ax + 192, row, 36, 16, 3);
}
if (alive5 == 1) {
    fillRect(ax + 240, row, 36, 16, 3);
}
if (alive6 == 1) {
    fillRect(ax + 288, row, 36, 16, 3);
}
if (alive7 == 1) {
    fillRect(ax + 336, row, 36, 16, 3);
}

// bullet + player
if (bullet == 1) {
    fillRect(bx, by, 4, 12, 1);
}
fillRect(px, 440, 28, 14, 5);
fillRect(px + 10, 432, 8, 8, 5);

swapBuffers();
startLoop();
