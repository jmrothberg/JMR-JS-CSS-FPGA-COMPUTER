; prince-of-persia-hd-6mb: Prince of Persia/Prince of Persia, CODE resource 0 (1384 bytes)
; CODE 0 is the segment jump table, NOT normal code.
; A5 world: above-A5 = 1400 bytes (jump table), below-A5 = 27112 bytes (globals/QuickDraw)
; Each entry: word = entry offset, then JMP abs (loaded) or MOVE.W #seg,-(SP)/LoadSeg (unloaded)

  000008:  00 00                  dc.w $0000
  000008+2:  05 58                  bchg.b d2, (a0)+
  000008+4:  00 00 00 20            ori.b #$20, d0

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

  000060:  22 3a                  dc.w $223a
  000060+2:  3f 3c 00 02            move.w #$2, -(a7)
  000060+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000068:  22 68                  dc.w $2268
  000068+2:  3f 3c 00 02            move.w #$2, -(a7)
  000068+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000070:  22 92                  dc.w $2292
  000070+2:  3f 3c 00 02            move.w #$2, -(a7)
  000070+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000078:  22 b4                  dc.w $22b4
  000078+2:  3f 3c 00 02            move.w #$2, -(a7)
  000078+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000080:  23 c0                  dc.w $23c0
  000080+2:  3f 3c 00 02            move.w #$2, -(a7)
  000080+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000088:  24 c0                  dc.w $24c0
  000088+2:  3f 3c 00 02            move.w #$2, -(a7)
  000088+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000090:  25 36                  dc.w $2536
  000090+2:  3f 3c 00 02            move.w #$2, -(a7)
  000090+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000098:  26 82                  dc.w $2682
  000098+2:  3f 3c 00 02            move.w #$2, -(a7)
  000098+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000a0:  26 a4                  dc.w $26a4
  0000a0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000a8:  27 22                  dc.w $2722
  0000a8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000b0:  27 a6                  dc.w $27a6
  0000b0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000b8:  28 1a                  dc.w $281a
  0000b8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000c0:  28 5c                  dc.w $285c
  0000c0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000c8:  28 9c                  dc.w $289c
  0000c8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000d0:  29 6a                  dc.w $296a
  0000d0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000d8:  2a 18                  dc.w $2a18
  0000d8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000e0:  2a 46                  dc.w $2a46
  0000e0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000e8:  2a 5a                  dc.w $2a5a
  0000e8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000f0:  2b 1c                  dc.w $2b1c
  0000f0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0000f8:  2b 4c                  dc.w $2b4c
  0000f8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0000f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000100:  2c 0a                  dc.w $2c0a
  000100+2:  3f 3c 00 02            move.w #$2, -(a7)
  000100+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000108:  2f 40                  dc.w $2f40
  000108+2:  3f 3c 00 02            move.w #$2, -(a7)
  000108+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000110:  2f de                  dc.w $2fde
  000110+2:  3f 3c 00 02            move.w #$2, -(a7)
  000110+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000118:  37 a2                  dc.w $37a2
  000118+2:  3f 3c 00 02            move.w #$2, -(a7)
  000118+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000120:  38 62                  dc.w $3862
  000120+2:  3f 3c 00 02            move.w #$2, -(a7)
  000120+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000128:  39 48                  dc.w $3948
  000128+2:  3f 3c 00 02            move.w #$2, -(a7)
  000128+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000130:  3a 24                  dc.w $3a24
  000130+2:  3f 3c 00 02            move.w #$2, -(a7)
  000130+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000138:  3c 86                  dc.w $3c86
  000138+2:  3f 3c 00 02            move.w #$2, -(a7)
  000138+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000140:  3d 0a                  dc.w $3d0a
  000140+2:  3f 3c 00 02            move.w #$2, -(a7)
  000140+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000148:  3d 6c                  dc.w $3d6c
  000148+2:  3f 3c 00 02            move.w #$2, -(a7)
  000148+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000150:  3d c4                  dc.w $3dc4
  000150+2:  3f 3c 00 02            move.w #$2, -(a7)
  000150+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000158:  3f 24                  dc.w $3f24
  000158+2:  3f 3c 00 02            move.w #$2, -(a7)
  000158+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000160:  3f 76                  dc.w $3f76
  000160+2:  3f 3c 00 02            move.w #$2, -(a7)
  000160+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000168:  3f d8                  dc.w $3fd8
  000168+2:  3f 3c 00 02            move.w #$2, -(a7)
  000168+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000170:  41 bc                  dc.w $41bc
  000170+2:  3f 3c 00 02            move.w #$2, -(a7)
  000170+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000178:  41 f8                  dc.w $41f8
  000178+2:  3f 3c 00 02            move.w #$2, -(a7)
  000178+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000180:  42 38                  dc.w $4238
  000180+2:  3f 3c 00 02            move.w #$2, -(a7)
  000180+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000188:  42 52                  dc.w $4252
  000188+2:  3f 3c 00 02            move.w #$2, -(a7)
  000188+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000190:  43 9a                  dc.w $439a
  000190+2:  3f 3c 00 02            move.w #$2, -(a7)
  000190+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000198:  51 00                  dc.w $5100
  000198+2:  3f 3c 00 02            move.w #$2, -(a7)
  000198+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001a0:  4f 4c                  dc.w $4f4c
  0001a0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0001a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001a8:  50 d4                  dc.w $50d4
  0001a8+2:  3f 3c 00 02            move.w #$2, -(a7)
  0001a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001b0:  00 00                  dc.w $0000
  0001b0+2:  3f 3c 00 02            move.w #$2, -(a7)
  0001b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001b8:  10 ca                  dc.w $10ca
  0001b8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001c0:  11 2c                  dc.w $112c
  0001c0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001c8:  14 56                  dc.w $1456
  0001c8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001d0:  14 de                  dc.w $14de
  0001d0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001d8:  15 b4                  dc.w $15b4
  0001d8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001e0:  17 0e                  dc.w $170e
  0001e0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001e8:  1a 92                  dc.w $1a92
  0001e8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001f0:  1c 66                  dc.w $1c66
  0001f0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0001f8:  1f 38                  dc.w $1f38
  0001f8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0001f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000200:  1f ce                  dc.w $1fce
  000200+2:  3f 3c 00 03            move.w #$3, -(a7)
  000200+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000208:  20 6a                  dc.w $206a
  000208+2:  3f 3c 00 03            move.w #$3, -(a7)
  000208+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000210:  21 38                  dc.w $2138
  000210+2:  3f 3c 00 03            move.w #$3, -(a7)
  000210+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000218:  21 a0                  dc.w $21a0
  000218+2:  3f 3c 00 03            move.w #$3, -(a7)
  000218+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000220:  22 10                  dc.w $2210
  000220+2:  3f 3c 00 03            move.w #$3, -(a7)
  000220+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000228:  22 6c                  dc.w $226c
  000228+2:  3f 3c 00 03            move.w #$3, -(a7)
  000228+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000230:  22 c8                  dc.w $22c8
  000230+2:  3f 3c 00 03            move.w #$3, -(a7)
  000230+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000238:  25 f4                  dc.w $25f4
  000238+2:  3f 3c 00 03            move.w #$3, -(a7)
  000238+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000240:  27 5e                  dc.w $275e
  000240+2:  3f 3c 00 03            move.w #$3, -(a7)
  000240+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000248:  27 a6                  dc.w $27a6
  000248+2:  3f 3c 00 03            move.w #$3, -(a7)
  000248+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000250:  3f 6e                  dc.w $3f6e
  000250+2:  3f 3c 00 03            move.w #$3, -(a7)
  000250+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000258:  40 44                  dc.w $4044
  000258+2:  3f 3c 00 03            move.w #$3, -(a7)
  000258+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000260:  40 88                  dc.w $4088
  000260+2:  3f 3c 00 03            move.w #$3, -(a7)
  000260+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000268:  40 c8                  dc.w $40c8
  000268+2:  3f 3c 00 03            move.w #$3, -(a7)
  000268+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000270:  40 d2                  dc.w $40d2
  000270+2:  3f 3c 00 03            move.w #$3, -(a7)
  000270+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000278:  40 e4                  dc.w $40e4
  000278+2:  3f 3c 00 03            move.w #$3, -(a7)
  000278+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000280:  41 cc                  dc.w $41cc
  000280+2:  3f 3c 00 03            move.w #$3, -(a7)
  000280+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000288:  41 fe                  dc.w $41fe
  000288+2:  3f 3c 00 03            move.w #$3, -(a7)
  000288+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000290:  42 46                  dc.w $4246
  000290+2:  3f 3c 00 03            move.w #$3, -(a7)
  000290+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000298:  43 da                  dc.w $43da
  000298+2:  3f 3c 00 03            move.w #$3, -(a7)
  000298+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002a0:  44 00                  dc.w $4400
  0002a0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002a8:  44 5e                  dc.w $445e
  0002a8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002b0:  44 7c                  dc.w $447c
  0002b0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002b8:  44 90                  dc.w $4490
  0002b8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002c0:  44 a4                  dc.w $44a4
  0002c0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002c8:  45 64                  dc.w $4564
  0002c8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002d0:  46 50                  dc.w $4650
  0002d0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002d8:  47 02                  dc.w $4702
  0002d8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002e0:  47 5e                  dc.w $475e
  0002e0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002e8:  47 7e                  dc.w $477e
  0002e8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002f0:  4a 26                  dc.w $4a26
  0002f0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0002f8:  4a de                  dc.w $4ade
  0002f8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0002f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000300:  4b 1a                  dc.w $4b1a
  000300+2:  3f 3c 00 03            move.w #$3, -(a7)
  000300+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000308:  4b 88                  dc.w $4b88
  000308+2:  3f 3c 00 03            move.w #$3, -(a7)
  000308+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000310:  4b ba                  dc.w $4bba
  000310+2:  3f 3c 00 03            move.w #$3, -(a7)
  000310+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000318:  4b c8                  dc.w $4bc8
  000318+2:  3f 3c 00 03            move.w #$3, -(a7)
  000318+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000320:  4d b4                  dc.w $4db4
  000320+2:  3f 3c 00 03            move.w #$3, -(a7)
  000320+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000328:  4f 0e                  dc.w $4f0e
  000328+2:  3f 3c 00 03            move.w #$3, -(a7)
  000328+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000330:  4f 90                  dc.w $4f90
  000330+2:  3f 3c 00 03            move.w #$3, -(a7)
  000330+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000338:  4f d6                  dc.w $4fd6
  000338+2:  3f 3c 00 03            move.w #$3, -(a7)
  000338+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000340:  4f fc                  dc.w $4ffc
  000340+2:  3f 3c 00 03            move.w #$3, -(a7)
  000340+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000348:  50 34                  dc.w $5034
  000348+2:  3f 3c 00 03            move.w #$3, -(a7)
  000348+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000350:  50 6c                  dc.w $506c
  000350+2:  3f 3c 00 03            move.w #$3, -(a7)
  000350+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000358:  50 86                  dc.w $5086
  000358+2:  3f 3c 00 03            move.w #$3, -(a7)
  000358+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000360:  52 1e                  dc.w $521e
  000360+2:  3f 3c 00 03            move.w #$3, -(a7)
  000360+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000368:  54 28                  dc.w $5428
  000368+2:  3f 3c 00 03            move.w #$3, -(a7)
  000368+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000370:  54 3a                  dc.w $543a
  000370+2:  3f 3c 00 03            move.w #$3, -(a7)
  000370+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000378:  57 56                  dc.w $5756
  000378+2:  3f 3c 00 03            move.w #$3, -(a7)
  000378+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000380:  58 3a                  dc.w $583a
  000380+2:  3f 3c 00 03            move.w #$3, -(a7)
  000380+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000388:  58 c4                  dc.w $58c4
  000388+2:  3f 3c 00 03            move.w #$3, -(a7)
  000388+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000390:  58 f0                  dc.w $58f0
  000390+2:  3f 3c 00 03            move.w #$3, -(a7)
  000390+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000398:  59 30                  dc.w $5930
  000398+2:  3f 3c 00 03            move.w #$3, -(a7)
  000398+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003a0:  00 00                  dc.w $0000
  0003a0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0003a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003a8:  00 50                  dc.w $0050
  0003a8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0003a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003b0:  06 d8                  dc.w $06d8
  0003b0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0003b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003b8:  07 b0                  dc.w $07b0
  0003b8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0003b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003c0:  0b ee                  dc.w $0bee
  0003c0+2:  3f 3c 00 03            move.w #$3, -(a7)
  0003c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003c8:  0f 4e                  dc.w $0f4e
  0003c8+2:  3f 3c 00 03            move.w #$3, -(a7)
  0003c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003d0:  0f 50                  dc.w $0f50
  0003d0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003d8:  12 0c                  dc.w $120c
  0003d8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003e0:  15 de                  dc.w $15de
  0003e0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003e8:  17 10                  dc.w $1710
  0003e8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003f0:  18 04                  dc.w $1804
  0003f0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0003f8:  18 94                  dc.w $1894
  0003f8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0003f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000400:  19 5e                  dc.w $195e
  000400+2:  3f 3c 00 04            move.w #$4, -(a7)
  000400+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000408:  1a ca                  dc.w $1aca
  000408+2:  3f 3c 00 04            move.w #$4, -(a7)
  000408+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000410:  1c 5c                  dc.w $1c5c
  000410+2:  3f 3c 00 04            move.w #$4, -(a7)
  000410+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000418:  22 32                  dc.w $2232
  000418+2:  3f 3c 00 04            move.w #$4, -(a7)
  000418+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000420:  22 68                  dc.w $2268
  000420+2:  3f 3c 00 04            move.w #$4, -(a7)
  000420+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000428:  22 d4                  dc.w $22d4
  000428+2:  3f 3c 00 04            move.w #$4, -(a7)
  000428+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000430:  23 3e                  dc.w $233e
  000430+2:  3f 3c 00 04            move.w #$4, -(a7)
  000430+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000438:  23 c4                  dc.w $23c4
  000438+2:  3f 3c 00 04            move.w #$4, -(a7)
  000438+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000440:  23 fa                  dc.w $23fa
  000440+2:  3f 3c 00 04            move.w #$4, -(a7)
  000440+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000448:  24 2e                  dc.w $242e
  000448+2:  3f 3c 00 04            move.w #$4, -(a7)
  000448+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000450:  24 a8                  dc.w $24a8
  000450+2:  3f 3c 00 04            move.w #$4, -(a7)
  000450+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000458:  26 9a                  dc.w $269a
  000458+2:  3f 3c 00 04            move.w #$4, -(a7)
  000458+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000460:  27 a2                  dc.w $27a2
  000460+2:  3f 3c 00 04            move.w #$4, -(a7)
  000460+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000468:  28 3c                  dc.w $283c
  000468+2:  3f 3c 00 04            move.w #$4, -(a7)
  000468+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000470:  28 e2                  dc.w $28e2
  000470+2:  3f 3c 00 04            move.w #$4, -(a7)
  000470+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000478:  2a 2a                  dc.w $2a2a
  000478+2:  3f 3c 00 04            move.w #$4, -(a7)
  000478+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000480:  2a 74                  dc.w $2a74
  000480+2:  3f 3c 00 04            move.w #$4, -(a7)
  000480+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000488:  2b 5a                  dc.w $2b5a
  000488+2:  3f 3c 00 04            move.w #$4, -(a7)
  000488+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000490:  2b c0                  dc.w $2bc0
  000490+2:  3f 3c 00 04            move.w #$4, -(a7)
  000490+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000498:  2b e8                  dc.w $2be8
  000498+2:  3f 3c 00 04            move.w #$4, -(a7)
  000498+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004a0:  30 aa                  dc.w $30aa
  0004a0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004a0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004a8:  32 24                  dc.w $3224
  0004a8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004a8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004b0:  32 52                  dc.w $3252
  0004b0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004b0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004b8:  43 76                  dc.w $4376
  0004b8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004b8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004c0:  43 d4                  dc.w $43d4
  0004c0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004c0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004c8:  44 76                  dc.w $4476
  0004c8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004c8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004d0:  49 86                  dc.w $4986
  0004d0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004d0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004d8:  4d 16                  dc.w $4d16
  0004d8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004d8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004e0:  4e f6                  dc.w $4ef6
  0004e0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004e0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004e8:  4f 20                  dc.w $4f20
  0004e8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004e8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004f0:  4f f2                  dc.w $4ff2
  0004f0+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004f0+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  0004f8:  50 90                  dc.w $5090
  0004f8+2:  3f 3c 00 04            move.w #$4, -(a7)
  0004f8+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000500:  51 9e                  dc.w $519e
  000500+2:  3f 3c 00 04            move.w #$4, -(a7)
  000500+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000508:  57 f4                  dc.w $57f4
  000508+2:  3f 3c 00 04            move.w #$4, -(a7)
  000508+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000510:  58 7a                  dc.w $587a
  000510+2:  3f 3c 00 04            move.w #$4, -(a7)
  000510+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000518:  59 a0                  dc.w $59a0
  000518+2:  3f 3c 00 04            move.w #$4, -(a7)
  000518+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000520:  59 b4                  dc.w $59b4
  000520+2:  3f 3c 00 04            move.w #$4, -(a7)
  000520+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000528:  5a dc                  dc.w $5adc
  000528+2:  3f 3c 00 04            move.w #$4, -(a7)
  000528+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000530:  5b 6e                  dc.w $5b6e
  000530+2:  3f 3c 00 04            move.w #$4, -(a7)
  000530+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000538:  5c 24                  dc.w $5c24
  000538+2:  3f 3c 00 04            move.w #$4, -(a7)
  000538+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000540:  00 00                  dc.w $0000
  000540+2:  3f 3c 00 04            move.w #$4, -(a7)
  000540+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000548:  00 40                  dc.w $0040
  000548+2:  3f 3c 00 04            move.w #$4, -(a7)
  000548+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000550:  01 da                  dc.w $01da
  000550+2:  3f 3c 00 04            move.w #$4, -(a7)
  000550+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000558:  02 40                  dc.w $0240
  000558+2:  3f 3c 00 04            move.w #$4, -(a7)
  000558+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg

  000560:  0c d4                  dc.w $0cd4
  000560+2:  3f 3c 00 04            move.w #$4, -(a7)
  000560+6:  a9 f0                  dc.w $a9f0   ; _LoadSeg
