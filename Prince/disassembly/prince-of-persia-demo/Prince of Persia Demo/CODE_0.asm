; prince-of-persia-demo: Prince of Persia Demo, CODE resource 0 (1336 bytes)
; CODE 0 is the segment jump table, NOT normal code.
; A5 world: above-A5 = 1352 bytes (jump table), below-A5 = 26952 bytes (globals/QuickDraw)
; Each entry: word = entry offset, then JMP abs (loaded) or MOVE.W #seg,-(SP)/LoadSeg (unloaded)

  000008:  00 00                  dc.w $0000
  000008+2:  05 28 00 00            btst.l d2, $0(a0)
  000008+6:  00 20 00 04            ori.b #$4, -(a0)

  000010:  00 04                  dc.w $0004
  000010+2:  3f 3c 00 01            move.w #$1, -(a7)
  000010+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000018:  00 92                  dc.w $0092
  000018+2:  3f 3c 00 01            move.w #$1, -(a7)
  000018+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000020:  00 a6                  dc.w $00a6
  000020+2:  3f 3c 00 01            move.w #$1, -(a7)
  000020+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000028:  00 ba                  dc.w $00ba
  000028+2:  3f 3c 00 01            move.w #$1, -(a7)
  000028+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000030:  00 d6                  dc.w $00d6
  000030+2:  3f 3c 00 01            move.w #$1, -(a7)
  000030+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000038:  01 0c                  dc.w $010c
  000038+2:  3f 3c 00 01            move.w #$1, -(a7)
  000038+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000040:  01 2c                  dc.w $012c
  000040+2:  3f 3c 00 01            move.w #$1, -(a7)
  000040+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000048:  01 4e                  dc.w $014e
  000048+2:  3f 3c 00 01            move.w #$1, -(a7)
  000048+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000050:  01 6e                  dc.w $016e
  000050+2:  3f 3c 00 01            move.w #$1, -(a7)
  000050+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000058:  02 28                  dc.w $0228
  000058+2:  3f 3c 00 01            move.w #$1, -(a7)
  000058+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000060:  1c 56                  dc.w $1c56
  000060+2:  3f 3c 00 02            move.w #$2, -(a7)
  000060+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000068:  1c 84                  dc.w $1c84
  000068+2:  3f 3c 00 02            move.w #$2, -(a7)
  000068+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000070:  1c ae                  dc.w $1cae
  000070+2:  3f 3c 00 02            move.w #$2, -(a7)
  000070+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000078:  1c d0                  dc.w $1cd0
  000078+2:  3f 3c 00 02            move.w #$2, -(a7)
  000078+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000080:  1d dc                  dc.w $1ddc
  000080+2:  3f 3c 00 02            move.w #$2, -(a7)
  000080+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000088:  1e dc                  dc.w $1edc
  000088+2:  3f 3c 00 02            move.w #$2, -(a7)
  000088+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000090:  1f 52                  dc.w $1f52
  000090+2:  3f 3c 00 02            move.w #$2, -(a7)
  000090+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000098:  20 9e                  dc.w $209e
  000098+2:  3f 3c 00 02            move.w #$2, -(a7)
  000098+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000a0:  21 3e                  dc.w $213e
  0000a0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000a8:  21 c2                  dc.w $21c2
  0000a8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000b0:  22 36                  dc.w $2236
  0000b0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000b8:  22 78                  dc.w $2278
  0000b8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000c0:  22 b8                  dc.w $22b8
  0000c0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000c8:  23 86                  dc.w $2386
  0000c8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000d0:  24 34                  dc.w $2434
  0000d0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000d8:  24 62                  dc.w $2462
  0000d8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000e0:  24 76                  dc.w $2476
  0000e0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000e8:  25 38                  dc.w $2538
  0000e8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000f0:  25 68                  dc.w $2568
  0000f0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000f8:  26 26                  dc.w $2626
  0000f8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000100:  29 5c                  dc.w $295c
  000100+2:  3f 3c 00 02            move.w #$2, -(a7)
  000100+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000108:  29 fa                  dc.w $29fa
  000108+2:  3f 3c 00 02            move.w #$2, -(a7)
  000108+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000110:  31 be                  dc.w $31be
  000110+2:  3f 3c 00 02            move.w #$2, -(a7)
  000110+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000118:  32 7e                  dc.w $327e
  000118+2:  3f 3c 00 02            move.w #$2, -(a7)
  000118+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000120:  33 64                  dc.w $3364
  000120+2:  3f 3c 00 02            move.w #$2, -(a7)
  000120+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000128:  34 40                  dc.w $3440
  000128+2:  3f 3c 00 02            move.w #$2, -(a7)
  000128+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000130:  36 a2                  dc.w $36a2
  000130+2:  3f 3c 00 02            move.w #$2, -(a7)
  000130+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000138:  37 26                  dc.w $3726
  000138+2:  3f 3c 00 02            move.w #$2, -(a7)
  000138+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000140:  37 88                  dc.w $3788
  000140+2:  3f 3c 00 02            move.w #$2, -(a7)
  000140+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000148:  37 e0                  dc.w $37e0
  000148+2:  3f 3c 00 02            move.w #$2, -(a7)
  000148+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000150:  39 40                  dc.w $3940
  000150+2:  3f 3c 00 02            move.w #$2, -(a7)
  000150+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000158:  39 92                  dc.w $3992
  000158+2:  3f 3c 00 02            move.w #$2, -(a7)
  000158+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000160:  39 f4                  dc.w $39f4
  000160+2:  3f 3c 00 02            move.w #$2, -(a7)
  000160+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000168:  3b d8                  dc.w $3bd8
  000168+2:  3f 3c 00 02            move.w #$2, -(a7)
  000168+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000170:  3c 14                  dc.w $3c14
  000170+2:  3f 3c 00 02            move.w #$2, -(a7)
  000170+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000178:  3c 54                  dc.w $3c54
  000178+2:  3f 3c 00 02            move.w #$2, -(a7)
  000178+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000180:  3c 6e                  dc.w $3c6e
  000180+2:  3f 3c 00 02            move.w #$2, -(a7)
  000180+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000188:  3d 0e                  dc.w $3d0e
  000188+2:  3f 3c 00 02            move.w #$2, -(a7)
  000188+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000190:  4a 74                  dc.w $4a74
  000190+2:  3f 3c 00 02            move.w #$2, -(a7)
  000190+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000198:  48 c0                  dc.w $48c0
  000198+2:  3f 3c 00 02            move.w #$2, -(a7)
  000198+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001a0:  4a 48                  dc.w $4a48
  0001a0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0001a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001a8:  00 00                  dc.w $0000
  0001a8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0001a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001b0:  11 da                  dc.w $11da
  0001b0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001b8:  12 3c                  dc.w $123c
  0001b8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001c0:  15 66                  dc.w $1566
  0001c0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001c8:  15 ee                  dc.w $15ee
  0001c8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001d0:  16 c4                  dc.w $16c4
  0001d0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001d8:  18 1e                  dc.w $181e
  0001d8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001e0:  1a 42                  dc.w $1a42
  0001e0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001e8:  1d 1a                  dc.w $1d1a
  0001e8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001f0:  1d 86                  dc.w $1d86
  0001f0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001f8:  1d e2                  dc.w $1de2
  0001f8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000200:  21 0e                  dc.w $210e
  000200+2:  3f 3c 00 03            move.w #$3, -(a7)
  000200+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000208:  21 10                  dc.w $2110
  000208+2:  3f 3c 00 03            move.w #$3, -(a7)
  000208+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000210:  21 58                  dc.w $2158
  000210+2:  3f 3c 00 03            move.w #$3, -(a7)
  000210+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000218:  30 74                  dc.w $3074
  000218+2:  3f 3c 00 03            move.w #$3, -(a7)
  000218+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000220:  31 4a                  dc.w $314a
  000220+2:  3f 3c 00 03            move.w #$3, -(a7)
  000220+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000228:  31 8e                  dc.w $318e
  000228+2:  3f 3c 00 03            move.w #$3, -(a7)
  000228+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000230:  31 ce                  dc.w $31ce
  000230+2:  3f 3c 00 03            move.w #$3, -(a7)
  000230+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000238:  31 d8                  dc.w $31d8
  000238+2:  3f 3c 00 03            move.w #$3, -(a7)
  000238+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000240:  31 ea                  dc.w $31ea
  000240+2:  3f 3c 00 03            move.w #$3, -(a7)
  000240+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000248:  32 d2                  dc.w $32d2
  000248+2:  3f 3c 00 03            move.w #$3, -(a7)
  000248+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000250:  33 04                  dc.w $3304
  000250+2:  3f 3c 00 03            move.w #$3, -(a7)
  000250+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000258:  33 4c                  dc.w $334c
  000258+2:  3f 3c 00 03            move.w #$3, -(a7)
  000258+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000260:  34 e0                  dc.w $34e0
  000260+2:  3f 3c 00 03            move.w #$3, -(a7)
  000260+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000268:  35 06                  dc.w $3506
  000268+2:  3f 3c 00 03            move.w #$3, -(a7)
  000268+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000270:  35 64                  dc.w $3564
  000270+2:  3f 3c 00 03            move.w #$3, -(a7)
  000270+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000278:  35 82                  dc.w $3582
  000278+2:  3f 3c 00 03            move.w #$3, -(a7)
  000278+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000280:  35 96                  dc.w $3596
  000280+2:  3f 3c 00 03            move.w #$3, -(a7)
  000280+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000288:  35 aa                  dc.w $35aa
  000288+2:  3f 3c 00 03            move.w #$3, -(a7)
  000288+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000290:  36 6a                  dc.w $366a
  000290+2:  3f 3c 00 03            move.w #$3, -(a7)
  000290+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000298:  37 56                  dc.w $3756
  000298+2:  3f 3c 00 03            move.w #$3, -(a7)
  000298+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002a0:  38 08                  dc.w $3808
  0002a0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002a8:  38 64                  dc.w $3864
  0002a8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002b0:  38 84                  dc.w $3884
  0002b0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002b8:  3b 2c                  dc.w $3b2c
  0002b8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002c0:  3b e4                  dc.w $3be4
  0002c0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002c8:  3c 20                  dc.w $3c20
  0002c8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002d0:  3c 8e                  dc.w $3c8e
  0002d0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002d8:  3c c0                  dc.w $3cc0
  0002d8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002e0:  3c ce                  dc.w $3cce
  0002e0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002e8:  3e ba                  dc.w $3eba
  0002e8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002f0:  40 14                  dc.w $4014
  0002f0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002f8:  40 96                  dc.w $4096
  0002f8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000300:  40 dc                  dc.w $40dc
  000300+2:  3f 3c 00 03            move.w #$3, -(a7)
  000300+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000308:  41 02                  dc.w $4102
  000308+2:  3f 3c 00 03            move.w #$3, -(a7)
  000308+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000310:  41 3a                  dc.w $413a
  000310+2:  3f 3c 00 03            move.w #$3, -(a7)
  000310+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000318:  41 72                  dc.w $4172
  000318+2:  3f 3c 00 03            move.w #$3, -(a7)
  000318+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000320:  41 8c                  dc.w $418c
  000320+2:  3f 3c 00 03            move.w #$3, -(a7)
  000320+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000328:  43 24                  dc.w $4324
  000328+2:  3f 3c 00 03            move.w #$3, -(a7)
  000328+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000330:  45 2e                  dc.w $452e
  000330+2:  3f 3c 00 03            move.w #$3, -(a7)
  000330+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000338:  45 40                  dc.w $4540
  000338+2:  3f 3c 00 03            move.w #$3, -(a7)
  000338+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000340:  48 5c                  dc.w $485c
  000340+2:  3f 3c 00 03            move.w #$3, -(a7)
  000340+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000348:  49 04                  dc.w $4904
  000348+2:  3f 3c 00 03            move.w #$3, -(a7)
  000348+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000350:  49 8e                  dc.w $498e
  000350+2:  3f 3c 00 03            move.w #$3, -(a7)
  000350+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000358:  49 ba                  dc.w $49ba
  000358+2:  3f 3c 00 03            move.w #$3, -(a7)
  000358+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000360:  49 fa                  dc.w $49fa
  000360+2:  3f 3c 00 03            move.w #$3, -(a7)
  000360+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000368:  00 00                  dc.w $0000
  000368+2:  3f 3c 00 03            move.w #$3, -(a7)
  000368+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000370:  00 50                  dc.w $0050
  000370+2:  3f 3c 00 03            move.w #$3, -(a7)
  000370+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000378:  06 d8                  dc.w $06d8
  000378+2:  3f 3c 00 03            move.w #$3, -(a7)
  000378+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000380:  07 b0                  dc.w $07b0
  000380+2:  3f 3c 00 03            move.w #$3, -(a7)
  000380+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000388:  0b ee                  dc.w $0bee
  000388+2:  3f 3c 00 03            move.w #$3, -(a7)
  000388+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000390:  0e d0                  dc.w $0ed0
  000390+2:  3f 3c 00 03            move.w #$3, -(a7)
  000390+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000398:  10 5e                  dc.w $105e
  000398+2:  3f 3c 00 03            move.w #$3, -(a7)
  000398+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003a0:  0f 50                  dc.w $0f50
  0003a0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003a8:  12 0c                  dc.w $120c
  0003a8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003b0:  15 de                  dc.w $15de
  0003b0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003b8:  17 10                  dc.w $1710
  0003b8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003c0:  18 04                  dc.w $1804
  0003c0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003c8:  18 94                  dc.w $1894
  0003c8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003d0:  19 5e                  dc.w $195e
  0003d0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003d8:  1a ca                  dc.w $1aca
  0003d8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003e0:  1c 5c                  dc.w $1c5c
  0003e0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003e8:  22 32                  dc.w $2232
  0003e8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003f0:  22 68                  dc.w $2268
  0003f0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003f8:  22 d4                  dc.w $22d4
  0003f8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000400:  23 3e                  dc.w $233e
  000400+2:  3f 3c 00 04            move.w #$4, -(a7)
  000400+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000408:  23 c4                  dc.w $23c4
  000408+2:  3f 3c 00 04            move.w #$4, -(a7)
  000408+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000410:  23 fa                  dc.w $23fa
  000410+2:  3f 3c 00 04            move.w #$4, -(a7)
  000410+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000418:  24 2e                  dc.w $242e
  000418+2:  3f 3c 00 04            move.w #$4, -(a7)
  000418+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000420:  24 a8                  dc.w $24a8
  000420+2:  3f 3c 00 04            move.w #$4, -(a7)
  000420+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000428:  26 9a                  dc.w $269a
  000428+2:  3f 3c 00 04            move.w #$4, -(a7)
  000428+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000430:  27 a2                  dc.w $27a2
  000430+2:  3f 3c 00 04            move.w #$4, -(a7)
  000430+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000438:  28 3c                  dc.w $283c
  000438+2:  3f 3c 00 04            move.w #$4, -(a7)
  000438+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000440:  28 e2                  dc.w $28e2
  000440+2:  3f 3c 00 04            move.w #$4, -(a7)
  000440+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000448:  2a 2a                  dc.w $2a2a
  000448+2:  3f 3c 00 04            move.w #$4, -(a7)
  000448+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000450:  2a 74                  dc.w $2a74
  000450+2:  3f 3c 00 04            move.w #$4, -(a7)
  000450+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000458:  2b 5a                  dc.w $2b5a
  000458+2:  3f 3c 00 04            move.w #$4, -(a7)
  000458+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000460:  2b c0                  dc.w $2bc0
  000460+2:  3f 3c 00 04            move.w #$4, -(a7)
  000460+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000468:  2b e8                  dc.w $2be8
  000468+2:  3f 3c 00 04            move.w #$4, -(a7)
  000468+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000470:  30 aa                  dc.w $30aa
  000470+2:  3f 3c 00 04            move.w #$4, -(a7)
  000470+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000478:  32 24                  dc.w $3224
  000478+2:  3f 3c 00 04            move.w #$4, -(a7)
  000478+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000480:  32 52                  dc.w $3252
  000480+2:  3f 3c 00 04            move.w #$4, -(a7)
  000480+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000488:  43 76                  dc.w $4376
  000488+2:  3f 3c 00 04            move.w #$4, -(a7)
  000488+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000490:  43 d4                  dc.w $43d4
  000490+2:  3f 3c 00 04            move.w #$4, -(a7)
  000490+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000498:  44 76                  dc.w $4476
  000498+2:  3f 3c 00 04            move.w #$4, -(a7)
  000498+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004a0:  49 86                  dc.w $4986
  0004a0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004a8:  4d 16                  dc.w $4d16
  0004a8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004b0:  4e be                  dc.w $4ebe
  0004b0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004b8:  4e e8                  dc.w $4ee8
  0004b8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004c0:  4f ba                  dc.w $4fba
  0004c0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004c8:  50 58                  dc.w $5058
  0004c8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004d0:  51 66                  dc.w $5166
  0004d0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004d8:  57 bc                  dc.w $57bc
  0004d8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004e0:  58 42                  dc.w $5842
  0004e0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004e8:  59 68                  dc.w $5968
  0004e8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004f0:  59 7c                  dc.w $597c
  0004f0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004f8:  5a a4                  dc.w $5aa4
  0004f8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000500:  5b 36                  dc.w $5b36
  000500+2:  3f 3c 00 04            move.w #$4, -(a7)
  000500+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000508:  5b ec                  dc.w $5bec
  000508+2:  3f 3c 00 04            move.w #$4, -(a7)
  000508+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000510:  00 00                  dc.w $0000
  000510+2:  3f 3c 00 04            move.w #$4, -(a7)
  000510+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000518:  00 40                  dc.w $0040
  000518+2:  3f 3c 00 04            move.w #$4, -(a7)
  000518+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000520:  01 da                  dc.w $01da
  000520+2:  3f 3c 00 04            move.w #$4, -(a7)
  000520+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000528:  02 40                  dc.w $0240
  000528+2:  3f 3c 00 04            move.w #$4, -(a7)
  000528+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000530:  0c d4                  dc.w $0cd4
  000530+2:  3f 3c 00 04            move.w #$4, -(a7)
  000530+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg
