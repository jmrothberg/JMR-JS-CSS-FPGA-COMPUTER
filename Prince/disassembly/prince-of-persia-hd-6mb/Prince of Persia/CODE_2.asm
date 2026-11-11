; prince-of-persia-hd-6mb: Prince of Persia/Prince of Persia, CODE resource 2 (23902 bytes)
; 68000 disassembly (linear sweep). Code starts after the 4-byte segment header.
; Words $Axxx are Mac Toolbox/OS traps; known ones are annotated. Globals are (a5)-relative.

  000004:  4e ba 01 6a            jsr $170(pc)
  000008:  4a 2d 96 1e            tst.b -$69e2(a5)
  00000c:  66 04                  bne.b $12
  00000e:  4e ba 01 c8            jsr $1d8(pc)
  000012:  4a 2d 96 1e            tst.b -$69e2(a5)
  000016:  66 04                  bne.b $1c
  000018:  4e ba 02 72            jsr $28c(pc)
  00001c:  4a 2d 96 1e            tst.b -$69e2(a5)
  000020:  66 04                  bne.b $26
  000022:  4e ba 03 00            jsr $324(pc)
  000026:  4a 2d 96 1e            tst.b -$69e2(a5)
  00002a:  66 04                  bne.b $30
  00002c:  4e ba 04 5c            jsr $48a(pc)
  000030:  4a 2d 96 1e            tst.b -$69e2(a5)
  000034:  66 04                  bne.b $3a
  000036:  4e ba 1d 48            jsr $1d80(pc)
  00003a:  42 a7                  clr.l -(a7)
  00003c:  a9 75                  dc.w $a975   ; _TickCount
  00003e:  2b 5f a5 5e            move.l (a7)+, -$5aa2(a5)
  000042:  42 ad 96 4c            clr.l -$69b4(a5)
  000046:  42 ad 96 50            clr.l -$69b0(a5)
  00004a:  60 00 00 fe            bra.w $14a
  00004e:  4a 2d 96 1a            tst.b -$69e6(a5)
  000052:  67 14                  beq.b $68
  000054:  42 27                  clr.b -(a7)
  000056:  3f 3c ff ff            move.w #$ffff, -(a7)
  00005a:  48 6d a1 e8            pea.l -$5e18(a5)
  00005e:  42 a7                  clr.l -(a7)
  000060:  42 a7                  clr.l -(a7)
  000062:  a8 60                  dc.w $a860   ; _WaitNextEvent
  000064:  54 8f                  addq.l #$2, a7
  000066:  60 10                  bra.b $78
  000068:  a9 b4                  dc.w $a9b4
  00006a:  42 27                  clr.b -(a7)
  00006c:  3f 3c ff ff            move.w #$ffff, -(a7)
  000070:  48 6d a1 e8            pea.l -$5e18(a5)
  000074:  a9 70                  dc.w $a970   ; _GetNextEvent
  000076:  54 8f                  addq.l #$2, a7
  000078:  4e ba 0c b6            jsr $d30(pc)
  00007c:  4a 2d 96 1b            tst.b -$69e5(a5)
  000080:  67 00 00 c8            beq.w $14a
  000084:  4e ba 2b 88            jsr $2c0e(pc)
  000088:  4a 2d 96 2c            tst.b -$69d4(a5)
  00008c:  67 56                  beq.b $e4
  00008e:  30 2d 96 48            move.w -$69b8(a5), d0
  000092:  0c 40 00 0b            cmpi.w #$b, d0
  000096:  62 4c                  bhi.b $e4
  000098:  43 fa 00 be            lea.l $158(pc), a1
  00009c:  d0 40                  add.w d0, d0
  00009e:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0000a2:  4e d1                  jmp (a1)
  0000a4:  4e ba 1d 5a            jsr $1e00(pc)
  0000a8:  60 3a                  bra.b $e4
  0000aa:  4e ba 1d 88            jsr $1e34(pc)
  0000ae:  60 34                  bra.b $e4
  0000b0:  4e ba 1d e6            jsr $1e98(pc)
  0000b4:  60 2e                  bra.b $e4
  0000b6:  4e ba 1e 5a            jsr $1f12(pc)
  0000ba:  60 28                  bra.b $e4
  0000bc:  4e ba 1e 90            jsr $1f4e(pc)
  0000c0:  60 22                  bra.b $e4
  0000c2:  4e ba 1e f6            jsr $1fba(pc)
  0000c6:  60 1c                  bra.b $e4
  0000c8:  4e ba 1f 10            jsr $1fda(pc)
  0000cc:  60 16                  bra.b $e4
  0000ce:  4e ba 1f 4e            jsr $201e(pc)
  0000d2:  60 10                  bra.b $e4
  0000d4:  4e ba 1f 94            jsr $206a(pc)
  0000d8:  60 0a                  bra.b $e4
  0000da:  4e ba 20 84            jsr $2160(pc)
  0000de:  60 04                  bra.b $e4
  0000e0:  4e ba 20 fe            jsr $21e0(pc)
  0000e4:  4a 2d 96 2f            tst.b -$69d1(a5)
  0000e8:  67 08                  beq.b $f2
  0000ea:  42 2d 96 2c            clr.b -$69d4(a5)
  0000ee:  42 2d 96 2f            clr.b -$69d1(a5)
  0000f2:  42 a7                  clr.l -(a7)
  0000f4:  a9 75                  dc.w $a975   ; _TickCount
  0000f6:  2b 5f a5 62            move.l (a7)+, -$5a9e(a5)
  0000fa:  4e ba 2b 12            jsr $2c0e(pc)
  0000fe:  20 2d a5 62            move.l -$5a9e(a5), d0
  000102:  90 ad a5 5e            sub.l -$5aa2(a5), d0
  000106:  b0 ad 96 4c            cmp.l -$69b4(a5), d0
  00010a:  6f e6                  ble.b $f2
  00010c:  2b 6d a5 62 a5 5e      move.l -$5a9e(a5), -$5aa2(a5)
  000112:  4e ba 1a 4a            jsr $1b5e(pc)
  000116:  42 27                  clr.b -(a7)
  000118:  3f 3c 00 40            move.w #$40, -(a7)
  00011c:  48 6d a1 e8            pea.l -$5e18(a5)
  000120:  a9 71                  dc.w $a971   ; _WaitMouseUp
  000122:  4a 1f                  tst.b (a7)+
  000124:  67 0a                  beq.b $130
  000126:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  00012a:  4e ba 0e 3a            jsr $f66(pc)
  00012e:  58 8f                  addq.l #$4, a7
  000130:  4e ba 2a dc            jsr $2c0e(pc)
  000134:  4a 6d f2 2a            tst.w -$dd6(a5)
  000138:  67 04                  beq.b $13e
  00013a:  4e ba 1b 38            jsr $1c74(pc)
  00013e:  4e ba 2a ce            jsr $2c0e(pc)
  000142:  4e ba 1b 9e            jsr $1ce2(pc)
  000146:  52 ad 96 50            addq.l #$1, -$69b0(a5)
  00014a:  4a 2d 96 1e            tst.b -$69e2(a5)
  00014e:  67 00 fe fe            beq.w $4e
  000152:  4e ba 0b 8e            jsr $ce2(pc)
  000156:  4e 75                  rts 
  000158:  ff 8c                  dc.w $ff8c
  00015a:  ff 4c                  dc.w $ff4c
  00015c:  ff 52                  dc.w $ff52
  00015e:  ff 58                  dc.w $ff58
  000160:  ff 5e                  dc.w $ff5e
  000162:  ff 64                  dc.w $ff64
  000164:  ff 6a                  dc.w $ff6a
  000166:  ff 70                  dc.w $ff70
  000168:  ff 76                  dc.w $ff76
  00016a:  ff 7c                  dc.w $ff7c
  00016c:  ff 82                  dc.w $ff82
  00016e:  ff 88                  dc.w $ff88
  000170:  a0 63                  dc.w $a063
  000172:  48 6d a6 ce            pea.l -$5932(a5)
  000176:  a8 6e                  dc.w $a86e   ; _InitGraf
  000178:  a8 fe                  dc.w $a8fe
  00017a:  a9 12                  dc.w $a912
  00017c:  a9 30                  dc.w $a930
  00017e:  a9 cc                  dc.w $a9cc
  000180:  42 a7                  clr.l -(a7)
  000182:  a9 7b                  dc.w $a97b
  000184:  a8 50                  dc.w $a850   ; _InitCursor
  000186:  a0 1c                  dc.w $a01c
  000188:  a0 40                  dc.w $a040
  00018a:  a0 36                  dc.w $a036
  00018c:  a0 36                  dc.w $a036
  00018e:  a0 36                  dc.w $a036
  000190:  a0 36                  dc.w $a036
  000192:  a0 36                  dc.w $a036
  000194:  a0 36                  dc.w $a036
  000196:  3b 78 01 44 a0 a2      move.w $144.w, -$5f5e(a5)
  00019c:  70 df                  moveq #$df, d0
  00019e:  31 c0 01 44            move.w d0, $144.w
  0001a2:  2f 3c 00 00 ff ff      move.l #$ffff, -(a7)
  0001a8:  20 1f                  move.l (a7)+, d0
  0001aa:  a0 32                  dc.w $a032
  0001ac:  42 27                  clr.b -(a7)
  0001ae:  3f 3c ff ff            move.w #$ffff, -(a7)
  0001b2:  48 6d a1 e8            pea.l -$5e18(a5)
  0001b6:  a9 70                  dc.w $a970   ; _GetNextEvent
  0001b8:  08 2d 00 04 a1 f6      btst.b #$4, -$5e0a(a5)
  0001be:  54 8f                  addq.l #$2, a7
  0001c0:  67 06                  beq.b $1c8
  0001c2:  1b 7c 00 01 96 2b      move.b #$1, -$69d5(a5)
  0001c8:  08 2d 00 03 a1 f6      btst.b #$3, -$5e0a(a5)
  0001ce:  67 06                  beq.b $1d6
  0001d0:  1b 7c 00 01 96 2a      move.b #$1, -$69d6(a5)
  0001d6:  4e 75                  rts 
  0001d8:  4e 56 ff fc            link.w a6, #$fffc
  0001dc:  42 67                  clr.w -(a7)
  0001de:  3f 3c 00 01            move.w #$1, -(a7)
  0001e2:  48 6d a0 90            pea.l -$5f70(a5)
  0001e6:  4e ba 3e 4c            jsr $4034(pc)
  0001ea:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0001ee:  4a 6d a1 6c            tst.w -$5e94(a5)
  0001f2:  66 00 00 82            bne.w $276
  0001f6:  0c 6d 06 00 a0 94      cmpi.w #$600, -$5f6c(a5)
  0001fc:  6d 0e                  blt.b $20c
  0001fe:  0c 6d 00 03 a0 96      cmpi.w #$3, -$5f6a(a5)
  000204:  6d 06                  blt.b $20c
  000206:  1b 7c 00 01 96 18      move.b #$1, -$69e8(a5)
  00020c:  4a 2d a0 99            tst.b -$5f67(a5)
  000210:  67 2a                  beq.b $23c
  000212:  42 a7                  clr.l -(a7)
  000214:  2f 3c 01 00 ab 03      move.l #$100ab03, -(a7)
  00021a:  4e ba 3f 90            jsr $41ac(pc)
  00021e:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  000222:  42 a7                  clr.l -(a7)
  000224:  2f 3c 01 00 a8 9f      move.l #$100a89f, -(a7)
  00022a:  4e ba 3f 80            jsr $41ac(pc)
  00022e:  20 2e ff fc            move.l -$4(a6), d0
  000232:  b0 9f                  cmp.l (a7)+, d0
  000234:  67 06                  beq.b $23c
  000236:  1b 7c 00 01 96 19      move.b #$1, -$69e7(a5)
  00023c:  4a 6d a0 92            tst.w -$5f6e(a5)
  000240:  6f 46                  ble.b $288
  000242:  0c 6d 06 00 a0 94      cmpi.w #$600, -$5f6c(a5)
  000248:  6c 24                  bge.b $26e
  00024a:  42 a7                  clr.l -(a7)
  00024c:  2f 3c 01 00 a8 60      move.l #$100a860, -(a7)
  000252:  4e ba 3f 58            jsr $41ac(pc)
  000256:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  00025a:  42 a7                  clr.l -(a7)
  00025c:  2f 3c 01 00 a8 9f      move.l #$100a89f, -(a7)
  000262:  4e ba 3f 48            jsr $41ac(pc)
  000266:  20 2e ff fc            move.l -$4(a6), d0
  00026a:  b0 9f                  cmp.l (a7)+, d0
  00026c:  67 1a                  beq.b $288
  00026e:  1b 7c 00 01 96 1a      move.b #$1, -$69e6(a5)
  000274:  60 12                  bra.b $288
  000276:  42 67                  clr.w -(a7)
  000278:  3f 3c 03 e8            move.w #$3e8, -(a7)
  00027c:  42 a7                  clr.l -(a7)
  00027e:  a9 85                  dc.w $a985
  000280:  1b 7c 00 01 96 1e      move.b #$1, -$69e2(a5)
  000286:  54 8f                  addq.l #$2, a7
  000288:  4e 5e                  unlk a6
  00028a:  4e 75                  rts 
  00028c:  42 a7                  clr.l -(a7)
  00028e:  3f 3c 03 e8            move.w #$3e8, -(a7)
  000292:  a9 bf                  dc.w $a9bf
  000294:  2b 5f a1 d0            move.l (a7)+, -$5e30(a5)
  000298:  2f 2d a1 d0            move.l -$5e30(a5), -(a7)
  00029c:  4e ba 25 80            jsr $281e(pc)
  0002a0:  4a 00                  tst.b d0
  0002a2:  58 8f                  addq.l #$4, a7
  0002a4:  66 7c                  bne.b $322
  0002a6:  2f 2d a1 d0            move.l -$5e30(a5), -(a7)
  0002aa:  2f 3c 44 52 56 52      move.l #$44525652, -(a7)
  0002b0:  a9 4d                  dc.w $a94d
  0002b2:  2f 2d a1 d0            move.l -$5e30(a5), -(a7)
  0002b6:  42 67                  clr.w -(a7)
  0002b8:  a9 35                  dc.w $a935
  0002ba:  42 a7                  clr.l -(a7)
  0002bc:  3f 3c 03 e9            move.w #$3e9, -(a7)
  0002c0:  a9 bf                  dc.w $a9bf
  0002c2:  2b 5f a1 d4            move.l (a7)+, -$5e2c(a5)
  0002c6:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0002ca:  4e ba 25 52            jsr $281e(pc)
  0002ce:  4a 00                  tst.b d0
  0002d0:  58 8f                  addq.l #$4, a7
  0002d2:  66 4e                  bne.b $322
  0002d4:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0002d8:  42 67                  clr.w -(a7)
  0002da:  a9 35                  dc.w $a935
  0002dc:  42 a7                  clr.l -(a7)
  0002de:  3f 3c 03 ea            move.w #$3ea, -(a7)
  0002e2:  a9 bf                  dc.w $a9bf
  0002e4:  2b 5f a1 d8            move.l (a7)+, -$5e28(a5)
  0002e8:  2f 2d a1 d8            move.l -$5e28(a5), -(a7)
  0002ec:  4e ba 25 30            jsr $281e(pc)
  0002f0:  4a 00                  tst.b d0
  0002f2:  58 8f                  addq.l #$4, a7
  0002f4:  66 2c                  bne.b $322
  0002f6:  2f 2d a1 d8            move.l -$5e28(a5), -(a7)
  0002fa:  42 67                  clr.w -(a7)
  0002fc:  a9 35                  dc.w $a935
  0002fe:  42 a7                  clr.l -(a7)
  000300:  3f 3c 03 eb            move.w #$3eb, -(a7)
  000304:  a9 bf                  dc.w $a9bf
  000306:  2b 5f a1 dc            move.l (a7)+, -$5e24(a5)
  00030a:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00030e:  4e ba 25 0e            jsr $281e(pc)
  000312:  4a 00                  tst.b d0
  000314:  58 8f                  addq.l #$4, a7
  000316:  66 0a                  bne.b $322
  000318:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00031c:  42 67                  clr.w -(a7)
  00031e:  a9 35                  dc.w $a935
  000320:  a9 37                  dc.w $a937
  000322:  4e 75                  rts 
  000324:  4e 56 fe f0            link.w a6, #$fef0
  000328:  48 e7 01 08            movem.l d7/a4, -(a7)
  00032c:  41 ed 00 ba            lea.l $ba(a5), a0
  000330:  a0 4b                  dc.w $a04b
  000332:  2b 78 09 ee a0 a4      move.l $9ee.w, -$5f5c(a5)
  000338:  42 a7                  clr.l -(a7)
  00033a:  a8 d8                  dc.w $a8d8
  00033c:  2b 5f a0 a8            move.l (a7)+, -$5f58(a5)
  000340:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  000344:  48 6d a6 5a            pea.l -$59a6(a5)
  000348:  a8 df                  dc.w $a8df
  00034a:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  00034e:  2f 38 09 ee            move.l $9ee.w, -(a7)
  000352:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  000356:  a8 e6                  dc.w $a8e6
  000358:  42 a7                  clr.l -(a7)
  00035a:  a8 d8                  dc.w $a8d8
  00035c:  2b 5f a0 ac            move.l (a7)+, -$5f54(a5)
  000360:  2f 2d a0 ac            move.l -$5f54(a5), -(a7)
  000364:  48 6d a6 5a            pea.l -$59a6(a5)
  000368:  a8 df                  dc.w $a8df
  00036a:  2f 2d a0 ac            move.l -$5f54(a5), -(a7)
  00036e:  2f 38 09 ee            move.l $9ee.w, -(a7)
  000372:  2f 2d a0 ac            move.l -$5f54(a5), -(a7)
  000376:  a8 e5                  dc.w $a8e5
  000378:  3b 78 0b aa a0 b0      move.w $baa.w, -$5f50(a5)
  00037e:  42 a7                  clr.l -(a7)
  000380:  3f 3c 00 04            move.w #$4, -(a7)
  000384:  a9 b9                  dc.w $a9b9
  000386:  2b 5f a1 cc            move.l (a7)+, -$5e34(a5)
  00038a:  42 67                  clr.w -(a7)
  00038c:  48 6d a0 c0            pea.l -$5f40(a5)
  000390:  48 6d a0 be            pea.l -$5f42(a5)
  000394:  4e ba 3f 3e            jsr $42d4(pc)
  000398:  48 6d a0 e2            pea.l -$5f1e(a5)
  00039c:  48 6d a0 e0            pea.l -$5f20(a5)
  0003a0:  48 6e ff fc            pea.l -$4(a6)
  0003a4:  a9 f5                  dc.w $a9f5
  0003a6:  48 6e ff fa            pea.l -$6(a6)
  0003aa:  48 6e ff f8            pea.l -$8(a6)
  0003ae:  4e ba 40 14            jsr $43c4(pc)
  0003b2:  4a 6e ff fa            tst.w -$6(a6)
  0003b6:  54 8f                  addq.l #$2, a7
  0003b8:  66 38                  bne.b $3f2
  0003ba:  0c 6e 00 01 ff f8      cmpi.w #$1, -$8(a6)
  0003c0:  66 30                  bne.b $3f2
  0003c2:  3f 3c 00 01            move.w #$1, -(a7)
  0003c6:  48 6e fe f0            pea.l -$110(a6)
  0003ca:  4e ba 40 1c            jsr $43e8(pc)
  0003ce:  0c ae 50 50 73 67 fe f2 cmpi.l #$50507367, -$10e(a6)
  0003d6:  66 1a                  bne.b $3f2
  0003d8:  3b 6e fe f0 a1 22      move.w -$110(a6), -$5ede(a5)
  0003de:  41 ee fe f8            lea.l -$108(a6), a0
  0003e2:  43 ed a1 24            lea.l -$5edc(a5), a1
  0003e6:  70 00                  moveq #$0, d0
  0003e8:  10 2e fe f8            move.b -$108(a6), d0
  0003ec:  52 40                  addq.w #$1, d0
  0003ee:  48 c0                  ext.l d0
  0003f0:  a0 2e                  dc.w $a02e
  0003f2:  7e 01                  moveq #$1, d7
  0003f4:  60 08                  bra.b $3fe
  0003f6:  3f 07                  move.w d7, -(a7)
  0003f8:  4e ba 40 34            jsr $442e(pc)
  0003fc:  52 47                  addq.w #$1, d7
  0003fe:  be 6e ff f8            cmp.w -$8(a6), d7
  000402:  6f f2                  ble.b $3f6
  000404:  42 a7                  clr.l -(a7)
  000406:  2f 3c 4f 50 54 53      move.l #$4f505453, -(a7)
  00040c:  42 67                  clr.w -(a7)
  00040e:  a9 a0                  dc.w $a9a0
  000410:  2b 5f a5 50            move.l (a7)+, -$5ab0(a5)
  000414:  4a ad a5 50            tst.l -$5ab0(a5)
  000418:  67 10                  beq.b $42a
  00041a:  20 6d a5 50            movea.l -$5ab0(a5), a0
  00041e:  28 50                  movea.l (a0), a4
  000420:  1b 54 96 5a            move.b (a4), -$69a6(a5)
  000424:  1b 6c 00 01 96 5c      move.b $1(a4), -$69a4(a5)
  00042a:  4e ba 14 7c            jsr $18a8(pc)
  00042e:  42 a7                  clr.l -(a7)
  000430:  2f 3c 48 49 47 48      move.l #$48494748, -(a7)
  000436:  42 67                  clr.w -(a7)
  000438:  a9 a0                  dc.w $a9a0
  00043a:  2b 5f a5 54            move.l (a7)+, -$5aac(a5)
  00043e:  4a ad a5 54            tst.l -$5aac(a5)
  000442:  66 1a                  bne.b $45e
  000444:  20 3c 00 00 01 40      move.l #$140, d0
  00044a:  a3 22                  dc.w $a322
  00044c:  2b 48 a5 54            move.l a0, -$5aac(a5)
  000450:  2f 08                  move.l a0, -(a7)
  000452:  2f 3c 48 49 47 48      move.l #$48494748, -(a7)
  000458:  42 67                  clr.w -(a7)
  00045a:  42 a7                  clr.l -(a7)
  00045c:  a9 ab                  dc.w $a9ab
  00045e:  42 6d a5 58            clr.w -$5aa8(a5)
  000462:  99 cc                  suba.l a4, a4
  000464:  60 14                  bra.b $47a
  000466:  20 6d a5 54            movea.l -$5aac(a5), a0
  00046a:  22 4c                  movea.l a4, a1
  00046c:  d3 d0                  adda.l (a0), a1
  00046e:  4a 11                  tst.b (a1)
  000470:  67 10                  beq.b $482
  000472:  52 6d a5 58            addq.w #$1, -$5aa8(a5)
  000476:  49 ec 00 20            lea.l $20(a4), a4
  00047a:  0c 6d 00 0a a5 58      cmpi.w #$a, -$5aa8(a5)
  000480:  6d e4                  blt.b $466
  000482:  4c df 10 80            movem.l (a7)+, d7/a4
  000486:  4e 5e                  unlk a6
  000488:  4e 75                  rts 
  00048a:  4e ba 00 4e            jsr $4da(pc)
  00048e:  3b 40 a1 6c            move.w d0, -$5e94(a5)
  000492:  4a 40                  tst.w d0
  000494:  66 42                  bne.b $4d8
  000496:  4e ba 02 ac            jsr $744(pc)
  00049a:  42 67                  clr.w -(a7)
  00049c:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  0004a0:  3f 2d a0 be            move.w -$5f42(a5), -(a7)
  0004a4:  42 27                  clr.b -(a7)
  0004a6:  a9 c4                  dc.w $a9c4
  0004a8:  3b 5f a1 64            move.w (a7)+, -$5e9c(a5)
  0004ac:  3f 2d a1 64            move.w -$5e9c(a5), -(a7)
  0004b0:  4e ba 22 f8            jsr $27aa(pc)
  0004b4:  4a 00                  tst.b d0
  0004b6:  54 8f                  addq.l #$2, a7
  0004b8:  66 1e                  bne.b $4d8
  0004ba:  4e ba 03 0c            jsr $7c8(pc)
  0004be:  4e ba 01 d2            jsr $692(pc)
  0004c2:  4e ba 04 48            jsr $90c(pc)
  0004c6:  3b 40 a1 6c            move.w d0, -$5e94(a5)
  0004ca:  4a 40                  tst.w d0
  0004cc:  66 0a                  bne.b $4d8
  0004ce:  4e ba 05 7e            jsr $a4e(pc)
  0004d2:  3b 40 a1 6c            move.w d0, -$5e94(a5)
  0004d6:  4a 40                  tst.w d0
  0004d8:  4e 75                  rts 
  0004da:  48 e7 01 18            movem.l d7/a3-a4, -(a7)
  0004de:  4a 2d a0 99            tst.b -$5f67(a5)
  0004e2:  67 00 01 68            beq.w $64c
  0004e6:  4a 2d 96 19            tst.b -$69e7(a5)
  0004ea:  67 00 01 60            beq.w $64c
  0004ee:  42 a7                  clr.l -(a7)
  0004f0:  aa 2a                  dc.w $aa2a
  0004f2:  28 5f                  movea.l (a7)+, a4
  0004f4:  42 a7                  clr.l -(a7)
  0004f6:  aa 29                  dc.w $aa29
  0004f8:  26 5f                  movea.l (a7)+, a3
  0004fa:  b9 cb                  cmpa.l a3, a4
  0004fc:  66 08                  bne.b $506
  0004fe:  42 a7                  clr.l -(a7)
  000500:  2f 0b                  move.l a3, -(a7)
  000502:  aa 2b                  dc.w $aa2b
  000504:  26 5f                  movea.l (a7)+, a3
  000506:  4a 2d 96 2b            tst.b -$69d5(a5)
  00050a:  67 04                  beq.b $510
  00050c:  20 0b                  move.l a3, d0
  00050e:  66 0c                  bne.b $51c
  000510:  1b 7c 00 01 a2 08      move.b #$1, -$5df8(a5)
  000516:  2b 4c a1 bc            move.l a4, -$5e44(a5)
  00051a:  60 08                  bra.b $524
  00051c:  42 2d a2 08            clr.b -$5df8(a5)
  000520:  2b 4b a1 bc            move.l a3, -$5e44(a5)
  000524:  1b 7c 00 01 a2 09      move.b #$1, -$5df7(a5)
  00052a:  20 6d a1 bc            movea.l -$5e44(a5), a0
  00052e:  20 50                  movea.l (a0), a0
  000530:  2b 68 00 16 a1 c0      move.l $16(a0), -$5e40(a5)
  000536:  20 6d a1 c0            movea.l -$5e40(a5), a0
  00053a:  28 50                  movea.l (a0), a4
  00053c:  2b 6c 00 2a a1 c4      move.l $2a(a4), -$5e3c(a5)
  000542:  22 6d a1 c4            movea.l -$5e3c(a5), a1
  000546:  22 51                  movea.l (a1), a1
  000548:  2b 51 a1 c8            move.l (a1), -$5e38(a5)
  00054c:  42 6d a1 ae            clr.w -$5e52(a5)
  000550:  4a 6c 00 1e            tst.w $1e(a4)
  000554:  66 0c                  bne.b $562
  000556:  30 2c 00 22            move.w $22(a4), d0
  00055a:  c1 ec 00 24            muls.w $24(a4), d0
  00055e:  3b 40 a1 ae            move.w d0, -$5e52(a5)
  000562:  0c 6d 00 01 a1 ae      cmpi.w #$1, -$5e52(a5)
  000568:  67 30                  beq.b $59a
  00056a:  0c 6d 00 02 a1 ae      cmpi.w #$2, -$5e52(a5)
  000570:  67 28                  beq.b $59a
  000572:  0c 6d 00 04 a1 ae      cmpi.w #$4, -$5e52(a5)
  000578:  67 20                  beq.b $59a
  00057a:  0c 6d 00 08 a1 ae      cmpi.w #$8, -$5e52(a5)
  000580:  67 18                  beq.b $59a
  000582:  42 67                  clr.w -(a7)
  000584:  3f 3c 03 ed            move.w #$3ed, -(a7)
  000588:  42 a7                  clr.l -(a7)
  00058a:  a9 85                  dc.w $a985
  00058c:  1b 7c 00 01 96 1e      move.b #$1, -$69e2(a5)
  000592:  70 ff                  moveq #$ff, d0
  000594:  54 8f                  addq.l #$2, a7
  000596:  60 00 00 e2            bra.w $67a
  00059a:  30 2d a1 ae            move.w -$5e52(a5), d0
  00059e:  0c 40 00 08            cmpi.w #$8, d0
  0005a2:  62 42                  bhi.b $5e6
  0005a4:  43 fa 00 da            lea.l $680(pc), a1
  0005a8:  d0 40                  add.w d0, d0
  0005aa:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0005ae:  4e d1                  jmp (a1)
  0005b0:  3b 7c ff f0 a1 b0      move.w #$fff0, -$5e50(a5)
  0005b6:  3b 7c 00 0f a1 b2      move.w #$f, -$5e4e(a5)
  0005bc:  60 28                  bra.b $5e6
  0005be:  3b 7c ff f8 a1 b0      move.w #$fff8, -$5e50(a5)
  0005c4:  3b 7c 00 07 a1 b2      move.w #$7, -$5e4e(a5)
  0005ca:  60 1a                  bra.b $5e6
  0005cc:  3b 7c ff fc a1 b0      move.w #$fffc, -$5e50(a5)
  0005d2:  3b 7c 00 03 a1 b2      move.w #$3, -$5e4e(a5)
  0005d8:  60 0c                  bra.b $5e6
  0005da:  3b 7c ff fe a1 b0      move.w #$fffe, -$5e50(a5)
  0005e0:  3b 7c 00 01 a1 b2      move.w #$1, -$5e4e(a5)
  0005e6:  20 6d a1 c0            movea.l -$5e40(a5), a0
  0005ea:  20 50                  movea.l (a0), a0
  0005ec:  2b 68 00 06 a1 b4      move.l $6(a0), -$5e4c(a5)
  0005f2:  2b 68 00 0a a1 b8      move.l $a(a0), -$5e48(a5)
  0005f8:  30 2d a1 b8            move.w -$5e48(a5), d0
  0005fc:  90 6d a1 b4            sub.w -$5e4c(a5), d0
  000600:  0c 40 01 90            cmpi.w #$190, d0
  000604:  6d 12                  blt.b $618
  000606:  30 2d a1 ba            move.w -$5e46(a5), d0
  00060a:  90 6d a1 b6            sub.w -$5e4a(a5), d0
  00060e:  0c 40 02 80            cmpi.w #$280, d0
  000612:  6d 04                  blt.b $618
  000614:  7e 01                  moveq #$1, d7
  000616:  60 02                  bra.b $61a
  000618:  7e 00                  moveq #$0, d7
  00061a:  4a 2d 96 2a            tst.b -$69d6(a5)
  00061e:  66 04                  bne.b $624
  000620:  4a 07                  tst.b d7
  000622:  66 0a                  bne.b $62e
  000624:  4a 2d 96 2a            tst.b -$69d6(a5)
  000628:  67 0c                  beq.b $636
  00062a:  4a 07                  tst.b d7
  00062c:  66 08                  bne.b $636
  00062e:  1b 7c 00 01 a2 0a      move.b #$1, -$5df6(a5)
  000634:  60 04                  bra.b $63a
  000636:  42 2d a2 0a            clr.b -$5df6(a5)
  00063a:  0c 6d 00 04 a1 ae      cmpi.w #$4, -$5e52(a5)
  000640:  6c 36                  bge.b $678
  000642:  42 2d a2 09            clr.b -$5df7(a5)
  000646:  42 2d a2 0a            clr.b -$5df6(a5)
  00064a:  60 2c                  bra.b $678
  00064c:  1b 7c 00 01 a2 08      move.b #$1, -$5df8(a5)
  000652:  42 2d a2 09            clr.b -$5df7(a5)
  000656:  42 2d a2 0a            clr.b -$5df6(a5)
  00065a:  3b 7c 00 01 a1 ae      move.w #$1, -$5e52(a5)
  000660:  3b 7c ff f0 a1 b0      move.w #$fff0, -$5e50(a5)
  000666:  3b 7c 00 0f a1 b2      move.w #$f, -$5e4e(a5)
  00066c:  2b 6d a6 5a a1 b4      move.l -$59a6(a5), -$5e4c(a5)
  000672:  2b 6d a6 5e a1 b8      move.l -$59a2(a5), -$5e48(a5)
  000678:  70 00                  moveq #$0, d0
  00067a:  4c df 18 80            movem.l (a7)+, d7/a3-a4
  00067e:  4e 75                  rts 
  000680:  ff 66                  dc.w $ff66
  000682:  ff 30                  dc.w $ff30
  000684:  ff 3e                  dc.w $ff3e
  000686:  ff 66                  dc.w $ff66
  000688:  ff 4c                  dc.w $ff4c
  00068a:  ff 66                  dc.w $ff66
  00068c:  ff 66                  dc.w $ff66
  00068e:  ff 66                  dc.w $ff66
  000690:  ff 5a                  dc.w $ff5a
  000692:  4a 2d a2 09            tst.b -$5df7(a5)
  000696:  67 10                  beq.b $6a8
  000698:  0c 6d 00 08 a1 ae      cmpi.w #$8, -$5e52(a5)
  00069e:  66 08                  bne.b $6a8
  0006a0:  3b 7c 00 08 a2 5c      move.w #$8, -$5da4(a5)
  0006a6:  60 1c                  bra.b $6c4
  0006a8:  4a 2d a2 09            tst.b -$5df7(a5)
  0006ac:  67 10                  beq.b $6be
  0006ae:  0c 6d 00 04 a1 ae      cmpi.w #$4, -$5e52(a5)
  0006b4:  66 08                  bne.b $6be
  0006b6:  3b 7c 00 04 a2 5c      move.w #$4, -$5da4(a5)
  0006bc:  60 06                  bra.b $6c4
  0006be:  3b 7c 00 01 a2 5c      move.w #$1, -$5da4(a5)
  0006c4:  30 2d a2 5c            move.w -$5da4(a5), d0
  0006c8:  67 78                  beq.b $742
  0006ca:  6b 76                  bmi.b $742
  0006cc:  59 40                  subq.w #$4, d0
  0006ce:  67 30                  beq.b $700
  0006d0:  6a 06                  bpl.b $6d8
  0006d2:  54 40                  addq.w #$2, d0
  0006d4:  6a 6c                  bpl.b $742
  0006d6:  60 4a                  bra.b $722
  0006d8:  59 40                  subq.w #$4, d0
  0006da:  67 02                  beq.b $6de
  0006dc:  60 64                  bra.b $742
  0006de:  41 ed 01 62            lea.l $162(a5), a0
  0006e2:  2b 48 a3 de            move.l a0, -$5c22(a5)
  0006e6:  43 ed 01 6a            lea.l $16a(a5), a1
  0006ea:  2b 49 a3 e2            move.l a1, -$5c1e(a5)
  0006ee:  41 ed 01 72            lea.l $172(a5), a0
  0006f2:  2b 48 a3 e6            move.l a0, -$5c1a(a5)
  0006f6:  41 ed 01 7a            lea.l $17a(a5), a0
  0006fa:  2b 48 a3 ea            move.l a0, -$5c16(a5)
  0006fe:  60 42                  bra.b $742
  000700:  41 ed 01 42            lea.l $142(a5), a0
  000704:  2b 48 a3 de            move.l a0, -$5c22(a5)
  000708:  43 ed 01 4a            lea.l $14a(a5), a1
  00070c:  2b 49 a3 e2            move.l a1, -$5c1e(a5)
  000710:  41 ed 01 52            lea.l $152(a5), a0
  000714:  2b 48 a3 e6            move.l a0, -$5c1a(a5)
  000718:  41 ed 01 5a            lea.l $15a(a5), a0
  00071c:  2b 48 a3 ea            move.l a0, -$5c16(a5)
  000720:  60 20                  bra.b $742
  000722:  41 ed 01 22            lea.l $122(a5), a0
  000726:  2b 48 a3 de            move.l a0, -$5c22(a5)
  00072a:  43 ed 01 2a            lea.l $12a(a5), a1
  00072e:  2b 49 a3 e2            move.l a1, -$5c1e(a5)
  000732:  41 ed 01 32            lea.l $132(a5), a0
  000736:  2b 48 a3 e6            move.l a0, -$5c1a(a5)
  00073a:  41 ed 01 3a            lea.l $13a(a5), a0
  00073e:  2b 48 a3 ea            move.l a0, -$5c16(a5)
  000742:  4e 75                  rts 
  000744:  4e 56 ff f0            link.w a6, #$fff0
  000748:  4a 2d a2 09            tst.b -$5df7(a5)
  00074c:  67 10                  beq.b $75e
  00074e:  4a 2d a2 0a            tst.b -$5df6(a5)
  000752:  67 0a                  beq.b $75e
  000754:  41 ed 96 5e            lea.l -$69a2(a5), a0
  000758:  2b 48 a1 68            move.l a0, -$5e98(a5)
  00075c:  60 18                  bra.b $776
  00075e:  4a 2d a2 09            tst.b -$5df7(a5)
  000762:  67 0a                  beq.b $76e
  000764:  41 ed 96 6c            lea.l -$6994(a5), a0
  000768:  2b 48 a1 68            move.l a0, -$5e98(a5)
  00076c:  60 08                  bra.b $776
  00076e:  41 ed 96 78            lea.l -$6988(a5), a0
  000772:  2b 48 a1 68            move.l a0, -$5e98(a5)
  000776:  42 67                  clr.w -(a7)
  000778:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  00077c:  3f 2d a0 be            move.w -$5f42(a5), -(a7)
  000780:  48 6e ff f0            pea.l -$10(a6)
  000784:  4e ba 3b 18            jsr $429e(pc)
  000788:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  00078c:  4a 6d a1 6c            tst.w -$5e94(a5)
  000790:  66 14                  bne.b $7a6
  000792:  0c ae 50 50 67 66 ff f0 cmpi.l #$50506766, -$10(a6)
  00079a:  66 0a                  bne.b $7a6
  00079c:  0c ae 50 6f c4 50 ff f4 cmpi.l #$506fc450, -$c(a6)
  0007a4:  67 1e                  beq.b $7c4
  0007a6:  4a 2d a2 09            tst.b -$5df7(a5)
  0007aa:  67 0c                  beq.b $7b8
  0007ac:  4a 2d a2 0a            tst.b -$5df6(a5)
  0007b0:  67 06                  beq.b $7b8
  0007b2:  42 2d a2 0a            clr.b -$5df6(a5)
  0007b6:  60 90                  bra.b $748
  0007b8:  4a 2d a2 09            tst.b -$5df7(a5)
  0007bc:  67 06                  beq.b $7c4
  0007be:  42 2d a2 09            clr.b -$5df7(a5)
  0007c2:  60 84                  bra.b $748
  0007c4:  4e 5e                  unlk a6
  0007c6:  4e 75                  rts 
  0007c8:  4e 56 ff fc            link.w a6, #$fffc
  0007cc:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  0007d0:  4a 2d a2 0a            tst.b -$5df6(a5)
  0007d4:  67 30                  beq.b $806
  0007d6:  7e 80                  moveq #$80, d7
  0007d8:  49 ed 97 66            lea.l -$689a(a5), a4
  0007dc:  60 0a                  bra.b $7e8
  0007de:  30 07                  move.w d7, d0
  0007e0:  d0 40                  add.w d0, d0
  0007e2:  38 80                  move.w d0, (a4)
  0007e4:  52 47                  addq.w #$1, d7
  0007e6:  54 8c                  addq.l #$2, a4
  0007e8:  0c 47 01 c0            cmpi.w #$1c0, d7
  0007ec:  6d f0                  blt.b $7de
  0007ee:  7e c1                  moveq #$c1, d7
  0007f0:  49 ed 9b e6            lea.l -$641a(a5), a4
  0007f4:  60 0a                  bra.b $800
  0007f6:  30 07                  move.w d7, d0
  0007f8:  d0 40                  add.w d0, d0
  0007fa:  38 80                  move.w d0, (a4)
  0007fc:  52 47                  addq.w #$1, d7
  0007fe:  54 8c                  addq.l #$2, a4
  000800:  0c 47 00 ff            cmpi.w #$ff, d7
  000804:  6d f0                  blt.b $7f6
  000806:  4a 2d a2 0a            tst.b -$5df6(a5)
  00080a:  66 1c                  bne.b $828
  00080c:  53 2d b3 7d            subq.b #$1, -$4c83(a5)
  000810:  59 2d b3 89            subq.b #$4, -$4c77(a5)
  000814:  57 2d b3 91            subq.b #$3, -$4c6f(a5)
  000818:  57 2d b3 95            subq.b #$3, -$4c6b(a5)
  00081c:  55 2d b3 99            subq.b #$2, -$4c67(a5)
  000820:  53 2d b3 9d            subq.b #$1, -$4c63(a5)
  000824:  52 2d b3 b9            addq.b #$1, -$4c47(a5)
  000828:  4a 2d a2 0a            tst.b -$5df6(a5)
  00082c:  67 1e                  beq.b $84c
  00082e:  3b 7c 02 80 a5 c0      move.w #$280, -$5a40(a5)
  000834:  3b 7c 01 90 a5 c2      move.w #$190, -$5a3e(a5)
  00083a:  3c 3c 02 80            move.w #$280, d6
  00083e:  3a 3c 01 80            move.w #$180, d5
  000842:  38 3c 01 2c            move.w #$12c, d4
  000846:  36 3c 01 5e            move.w #$15e, d3
  00084a:  60 1c                  bra.b $868
  00084c:  3b 7c 02 00 a5 c0      move.w #$200, -$5a40(a5)
  000852:  3b 7c 01 4e a5 c2      move.w #$14e, -$5a3e(a5)
  000858:  3c 3c 01 fe            move.w #$1fe, d6
  00085c:  3a 3c 01 3e            move.w #$13e, d5
  000860:  38 3c 00 f0            move.w #$f0, d4
  000864:  36 3c 01 5e            move.w #$15e, d3
  000868:  3e 06                  move.w d6, d7
  00086a:  e2 47                  asr.w #$1, d7
  00086c:  e2 44                  asr.w #$1, d4
  00086e:  e2 43                  asr.w #$1, d3
  000870:  48 6d a5 c4            pea.l -$5a3c(a5)
  000874:  42 a7                  clr.l -(a7)
  000876:  3f 2d a5 c0            move.w -$5a40(a5), -(a7)
  00087a:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  00087e:  a8 a7                  dc.w $a8a7
  000880:  48 6d a5 cc            pea.l -$5a34(a5)
  000884:  42 a7                  clr.l -(a7)
  000886:  3f 06                  move.w d6, -(a7)
  000888:  3f 05                  move.w d5, -(a7)
  00088a:  a8 a7                  dc.w $a8a7
  00088c:  48 6d a5 d4            pea.l -$5a2c(a5)
  000890:  42 67                  clr.w -(a7)
  000892:  3f 05                  move.w d5, -(a7)
  000894:  3f 06                  move.w d6, -(a7)
  000896:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  00089a:  a8 a7                  dc.w $a8a7
  00089c:  30 07                  move.w d7, d0
  00089e:  90 44                  sub.w d4, d0
  0008a0:  3d 40 ff fe            move.w d0, -$2(a6)
  0008a4:  48 6d a5 dc            pea.l -$5a24(a5)
  0008a8:  42 67                  clr.w -(a7)
  0008aa:  3f 05                  move.w d5, -(a7)
  0008ac:  3f 00                  move.w d0, -(a7)
  0008ae:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  0008b2:  a8 a7                  dc.w $a8a7
  0008b4:  30 07                  move.w d7, d0
  0008b6:  d0 44                  add.w d4, d0
  0008b8:  3d 40 ff fc            move.w d0, -$4(a6)
  0008bc:  48 6d a5 e4            pea.l -$5a1c(a5)
  0008c0:  3f 2e ff fe            move.w -$2(a6), -(a7)
  0008c4:  3f 05                  move.w d5, -(a7)
  0008c6:  3f 00                  move.w d0, -(a7)
  0008c8:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  0008cc:  a8 a7                  dc.w $a8a7
  0008ce:  48 6d a5 ec            pea.l -$5a14(a5)
  0008d2:  3f 2e ff fc            move.w -$4(a6), -(a7)
  0008d6:  3f 05                  move.w d5, -(a7)
  0008d8:  3f 06                  move.w d6, -(a7)
  0008da:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  0008de:  a8 a7                  dc.w $a8a7
  0008e0:  48 6d a5 fc            pea.l -$5a04(a5)
  0008e4:  30 07                  move.w d7, d0
  0008e6:  90 43                  sub.w d3, d0
  0008e8:  3f 00                  move.w d0, -(a7)
  0008ea:  42 67                  clr.w -(a7)
  0008ec:  30 07                  move.w d7, d0
  0008ee:  d0 43                  add.w d3, d0
  0008f0:  3f 00                  move.w d0, -(a7)
  0008f2:  3f 3c 00 14            move.w #$14, -(a7)
  0008f6:  a8 a7                  dc.w $a8a7
  0008f8:  48 6d a5 fc            pea.l -$5a04(a5)
  0008fc:  42 67                  clr.w -(a7)
  0008fe:  3f 2d 9d 0e            move.w -$62f2(a5), -(a7)
  000902:  a8 a8                  dc.w $a8a8
  000904:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  000908:  4e 5e                  unlk a6
  00090a:  4e 75                  rts 
  00090c:  48 6d a0 b6            pea.l -$5f4a(a5)
  000910:  a8 74                  dc.w $a874
  000912:  4a 2d a2 09            tst.b -$5df7(a5)
  000916:  67 3c                  beq.b $954
  000918:  42 a7                  clr.l -(a7)
  00091a:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  000920:  3f 3c 07 d0            move.w #$7d0, -(a7)
  000924:  a9 a0                  dc.w $a9a0
  000926:  2b 5f a2 f4            move.l (a7)+, -$5d0c(a5)
  00092a:  2f 2d a2 f4            move.l -$5d0c(a5), -(a7)
  00092e:  4e ba 1e ee            jsr $281e(pc)
  000932:  4a 00                  tst.b d0
  000934:  58 8f                  addq.l #$4, a7
  000936:  67 06                  beq.b $93e
  000938:  70 ff                  moveq #$ff, d0
  00093a:  60 00 01 10            bra.w $a4c
  00093e:  2f 2d a2 f4            move.l -$5d0c(a5), -(a7)
  000942:  a9 92                  dc.w $a992
  000944:  20 6d a2 f4            movea.l -$5d0c(a5), a0
  000948:  20 50                  movea.l (a0), a0
  00094a:  70 01                  moveq #$1, d0
  00094c:  d0 68 00 06            add.w $6(a0), d0
  000950:  3b 40 a2 f8            move.w d0, -$5d08(a5)
  000954:  30 2d a2 5c            move.w -$5da4(a5), d0
  000958:  c1 ed a5 c0            muls.w -$5a40(a5), d0
  00095c:  06 40 00 0f            addi.w #$f, d0
  000960:  e8 40                  asr.w #$4, d0
  000962:  d0 40                  add.w d0, d0
  000964:  3b 40 a2 da            move.w d0, -$5d26(a5)
  000968:  c1 ed a5 c2            muls.w -$5a3e(a5), d0
  00096c:  2b 40 a2 d6            move.l d0, -$5d2a(a5)
  000970:  a1 1e                  dc.w $a11e
  000972:  2b 48 a2 d2            move.l a0, -$5d2e(a5)
  000976:  2f 08                  move.l a0, -(a7)
  000978:  4e ba 1e e6            jsr $2860(pc)
  00097c:  4a 00                  tst.b d0
  00097e:  58 8f                  addq.l #$4, a7
  000980:  67 06                  beq.b $988
  000982:  70 ff                  moveq #$ff, d0
  000984:  60 00 00 c6            bra.w $a4c
  000988:  2b 6d a5 c4 a2 dc      move.l -$5a3c(a5), -$5d24(a5)
  00098e:  2b 6d a5 c8 a2 e0      move.l -$5a38(a5), -$5d20(a5)
  000994:  2b 6d a2 dc a2 e4      move.l -$5d24(a5), -$5d1c(a5)
  00099a:  2b 6d a2 e0 a2 e8      move.l -$5d20(a5), -$5d18(a5)
  0009a0:  4a 2d a2 09            tst.b -$5df7(a5)
  0009a4:  67 50                  beq.b $9f6
  0009a6:  42 a7                  clr.l -(a7)
  0009a8:  aa 32                  dc.w $aa32
  0009aa:  2b 5f a0 ba            move.l (a7)+, -$5f46(a5)
  0009ae:  2f 2d a1 bc            move.l -$5e44(a5), -(a7)
  0009b2:  aa 31                  dc.w $aa31
  0009b4:  48 6d a2 5e            pea.l -$5da2(a5)
  0009b8:  aa 00                  dc.w $aa00
  0009ba:  2b 6d a2 60 a2 ca      move.l -$5da0(a5), -$5d36(a5)
  0009c0:  20 6d a2 ca            movea.l -$5d36(a5), a0
  0009c4:  20 50                  movea.l (a0), a0
  0009c6:  20 ad a2 d2            move.l -$5d2e(a5), (a0)
  0009ca:  30 2d a2 da            move.w -$5d26(a5), d0
  0009ce:  00 40 80 00            ori.w #$8000, d0
  0009d2:  20 6d a2 ca            movea.l -$5d36(a5), a0
  0009d6:  20 50                  movea.l (a0), a0
  0009d8:  31 40 00 04            move.w d0, $4(a0)
  0009dc:  20 6d a2 ca            movea.l -$5d36(a5), a0
  0009e0:  20 50                  movea.l (a0), a0
  0009e2:  21 6d a2 dc 00 06      move.l -$5d24(a5), $6(a0)
  0009e8:  21 6d a2 e0 00 0a      move.l -$5d20(a5), $a(a0)
  0009ee:  2f 2d a0 ba            move.l -$5f46(a5), -(a7)
  0009f2:  aa 31                  dc.w $aa31
  0009f4:  60 2c                  bra.b $a22
  0009f6:  48 6d a2 5e            pea.l -$5da2(a5)
  0009fa:  a8 6f                  dc.w $a86f
  0009fc:  41 ed a2 60            lea.l -$5da0(a5), a0
  000a00:  2b 48 a2 ce            move.l a0, -$5d32(a5)
  000a04:  20 ad a2 d2            move.l -$5d2e(a5), (a0)
  000a08:  20 6d a2 ce            movea.l -$5d32(a5), a0
  000a0c:  31 6d a2 da 00 04      move.w -$5d26(a5), $4(a0)
  000a12:  20 6d a2 ce            movea.l -$5d32(a5), a0
  000a16:  21 6d a2 dc 00 06      move.l -$5d24(a5), $6(a0)
  000a1c:  21 6d a2 e0 00 0a      move.l -$5d20(a5), $a(a0)
  000a22:  48 6d a2 dc            pea.l -$5d24(a5)
  000a26:  a8 7b                  dc.w $a87b
  000a28:  48 6d a2 dc            pea.l -$5d24(a5)
  000a2c:  a8 a2                  dc.w $a8a2
  000a2e:  3f 3c 00 c8            move.w #$c8, -(a7)
  000a32:  a8 87                  dc.w $a887
  000a34:  3f 3c 00 10            move.w #$10, -(a7)
  000a38:  a8 8a                  dc.w $a88a
  000a3a:  42 67                  clr.w -(a7)
  000a3c:  a8 88                  dc.w $a888
  000a3e:  3f 3c 00 03            move.w #$3, -(a7)
  000a42:  a8 89                  dc.w $a889
  000a44:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  000a48:  a8 73                  dc.w $a873
  000a4a:  70 00                  moveq #$0, d0
  000a4c:  4e 75                  rts 
  000a4e:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  000a52:  4a 2d a2 09            tst.b -$5df7(a5)
  000a56:  67 20                  beq.b $a78
  000a58:  42 a7                  clr.l -(a7)
  000a5a:  42 a7                  clr.l -(a7)
  000a5c:  48 6d a1 b4            pea.l -$5e4c(a5)
  000a60:  42 a7                  clr.l -(a7)
  000a62:  2f 3c 00 02 01 00      move.l #$20100, -(a7)
  000a68:  48 78 ff ff            pea.l $ffff.w
  000a6c:  42 27                  clr.b -(a7)
  000a6e:  42 a7                  clr.l -(a7)
  000a70:  aa 45                  dc.w $aa45
  000a72:  2b 5f a2 12            move.l (a7)+, -$5dee(a5)
  000a76:  60 1e                  bra.b $a96
  000a78:  42 a7                  clr.l -(a7)
  000a7a:  42 a7                  clr.l -(a7)
  000a7c:  48 6d a1 b4            pea.l -$5e4c(a5)
  000a80:  42 a7                  clr.l -(a7)
  000a82:  2f 3c 00 02 01 00      move.l #$20100, -(a7)
  000a88:  48 78 ff ff            pea.l $ffff.w
  000a8c:  42 27                  clr.b -(a7)
  000a8e:  42 a7                  clr.l -(a7)
  000a90:  a9 13                  dc.w $a913
  000a92:  2b 5f a2 12            move.l (a7)+, -$5dee(a5)
  000a96:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000a9a:  4e ba 1d c4            jsr $2860(pc)
  000a9e:  4a 00                  tst.b d0
  000aa0:  58 8f                  addq.l #$4, a7
  000aa2:  67 06                  beq.b $aaa
  000aa4:  70 ff                  moveq #$ff, d0
  000aa6:  60 00 02 34            bra.w $cdc
  000aaa:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000aae:  a8 73                  dc.w $a873
  000ab0:  3e 2d a1 ba            move.w -$5e46(a5), d7
  000ab4:  de 6d a1 b6            add.w -$5e4a(a5), d7
  000ab8:  9e 6d a5 c0            sub.w -$5a40(a5), d7
  000abc:  48 c7                  ext.l d7
  000abe:  8f fc 00 02            divs.w #$2, d7
  000ac2:  ce 6d a1 b0            and.w -$5e50(a5), d7
  000ac6:  3c 2d a1 b8            move.w -$5e48(a5), d6
  000aca:  dc 6d a1 b4            add.w -$5e4c(a5), d6
  000ace:  9c 6d a5 c2            sub.w -$5a3e(a5), d6
  000ad2:  48 c6                  ext.l d6
  000ad4:  8d fc 00 02            divs.w #$2, d6
  000ad8:  30 2d a1 b6            move.w -$5e4a(a5), d0
  000adc:  90 47                  sub.w d7, d0
  000ade:  3f 00                  move.w d0, -(a7)
  000ae0:  30 2d a1 b4            move.w -$5e4c(a5), d0
  000ae4:  90 46                  sub.w d6, d0
  000ae6:  3f 00                  move.w d0, -(a7)
  000ae8:  a8 78                  dc.w $a878
  000aea:  4a 2d a2 09            tst.b -$5df7(a5)
  000aee:  67 18                  beq.b $b08
  000af0:  20 6d a2 12            movea.l -$5dee(a5), a0
  000af4:  2b 68 00 02 a2 16      move.l $2(a0), -$5dea(a5)
  000afa:  2b 68 00 10 a2 1e      move.l $10(a0), -$5de2(a5)
  000b00:  2b 68 00 14 a2 22      move.l $14(a0), -$5dde(a5)
  000b06:  60 1a                  bra.b $b22
  000b08:  70 02                  moveq #$2, d0
  000b0a:  d0 ad a2 12            add.l -$5dee(a5), d0
  000b0e:  2b 40 a2 1a            move.l d0, -$5de6(a5)
  000b12:  20 6d a2 12            movea.l -$5dee(a5), a0
  000b16:  2b 68 00 10 a2 1e      move.l $10(a0), -$5de2(a5)
  000b1c:  2b 68 00 14 a2 22      move.l $14(a0), -$5dde(a5)
  000b22:  48 78 00 1e            pea.l $1e.w
  000b26:  a8 63                  dc.w $a863
  000b28:  48 78 00 21            pea.l $21.w
  000b2c:  a8 62                  dc.w $a862
  000b2e:  48 6d a2 1e            pea.l -$5de2(a5)
  000b32:  a8 a2                  dc.w $a8a2
  000b34:  42 a7                  clr.l -(a7)
  000b36:  a8 d8                  dc.w $a8d8
  000b38:  2b 5f a2 2a            move.l (a7)+, -$5dd6(a5)
  000b3c:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000b40:  48 6d a2 1e            pea.l -$5de2(a5)
  000b44:  a8 df                  dc.w $a8df
  000b46:  42 a7                  clr.l -(a7)
  000b48:  a8 d8                  dc.w $a8d8
  000b4a:  28 5f                  movea.l (a7)+, a4
  000b4c:  2f 0c                  move.l a4, -(a7)
  000b4e:  48 6d a5 c4            pea.l -$5a3c(a5)
  000b52:  a8 df                  dc.w $a8df
  000b54:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000b58:  2f 0c                  move.l a4, -(a7)
  000b5a:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000b5e:  a8 e6                  dc.w $a8e6
  000b60:  2f 0c                  move.l a4, -(a7)
  000b62:  a8 d9                  dc.w $a8d9
  000b64:  4a 2d a2 09            tst.b -$5df7(a5)
  000b68:  67 00 00 e6            beq.w $c50
  000b6c:  0c 6d 00 08 a2 5c      cmpi.w #$8, -$5da4(a5)
  000b72:  6c 06                  bge.b $b7a
  000b74:  3e 3c 0f a0            move.w #$fa0, d7
  000b78:  60 04                  bra.b $b7e
  000b7a:  3e 3c 07 d0            move.w #$7d0, d7
  000b7e:  42 a7                  clr.l -(a7)
  000b80:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  000b86:  3f 07                  move.w d7, -(a7)
  000b88:  a9 a0                  dc.w $a9a0
  000b8a:  2b 5f a2 32            move.l (a7)+, -$5dce(a5)
  000b8e:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  000b92:  4e ba 1c 8a            jsr $281e(pc)
  000b96:  4a 00                  tst.b d0
  000b98:  58 8f                  addq.l #$4, a7
  000b9a:  67 06                  beq.b $ba2
  000b9c:  70 ff                  moveq #$ff, d0
  000b9e:  60 00 01 3c            bra.w $cdc
  000ba2:  0c 6d 00 08 a2 5c      cmpi.w #$8, -$5da4(a5)
  000ba8:  6c 0e                  bge.b $bb8
  000baa:  2f 2d a2 f4            move.l -$5d0c(a5), -(a7)
  000bae:  3f 3c 00 04            move.w #$4, -(a7)
  000bb2:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  000bb6:  aa 37                  dc.w $aa37
  000bb8:  20 6d a2 32            movea.l -$5dce(a5), a0
  000bbc:  20 50                  movea.l (a0), a0
  000bbe:  70 01                  moveq #$1, d0
  000bc0:  d0 68 00 06            add.w $6(a0), d0
  000bc4:  3b 40 a2 36            move.w d0, -$5dca(a5)
  000bc8:  42 a7                  clr.l -(a7)
  000bca:  3f 00                  move.w d0, -(a7)
  000bcc:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  000bd0:  48 78 00 04            pea.l $4.w
  000bd4:  aa 91                  dc.w $aa91
  000bd6:  2b 5f a2 2e            move.l (a7)+, -$5dd2(a5)
  000bda:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000bde:  4e ba 1c 3e            jsr $281e(pc)
  000be2:  4a 00                  tst.b d0
  000be4:  58 8f                  addq.l #$4, a7
  000be6:  67 06                  beq.b $bee
  000be8:  70 ff                  moveq #$ff, d0
  000bea:  60 00 00 f0            bra.w $cdc
  000bee:  7e 00                  moveq #$0, d7
  000bf0:  99 cc                  suba.l a4, a4
  000bf2:  97 cb                  suba.l a3, a3
  000bf4:  60 20                  bra.b $c16
  000bf6:  20 6d a2 32            movea.l -$5dce(a5), a0
  000bfa:  20 10                  move.l (a0), d0
  000bfc:  22 6d a2 2e            movea.l -$5dd2(a5), a1
  000c00:  22 11                  move.l (a1), d1
  000c02:  41 f3 18 10            lea.l $10(a3, d1.l), a0
  000c06:  20 f4 08 0a            move.l $a(a4, d0.l), (a0)+
  000c0a:  30 f4 08 0e            move.w $e(a4, d0.l), (a0)+
  000c0e:  52 47                  addq.w #$1, d7
  000c10:  50 8c                  addq.l #$8, a4
  000c12:  47 eb 00 10            lea.l $10(a3), a3
  000c16:  be 6d a2 36            cmp.w -$5dca(a5), d7
  000c1a:  6d da                  blt.b $bf6
  000c1c:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000c20:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  000c26:  42 67                  clr.w -(a7)
  000c28:  aa 9e                  dc.w $aa9e
  000c2a:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000c2e:  2f 3c 00 02 00 01      move.l #$20001, -(a7)
  000c34:  42 67                  clr.w -(a7)
  000c36:  aa 9e                  dc.w $aa9e
  000c38:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000c3c:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000c40:  1f 3c 00 01            move.b #$1, -(a7)
  000c44:  aa 95                  dc.w $aa95
  000c46:  3b 7c 01 00 96 54      move.w #$100, -$69ac(a5)
  000c4c:  4e ba 0d 74            jsr $19c2(pc)
  000c50:  1b 7c 00 01 a2 0c      move.b #$1, -$5df4(a5)
  000c56:  0c 6d 00 04 a2 5c      cmpi.w #$4, -$5da4(a5)
  000c5c:  66 08                  bne.b $c66
  000c5e:  1b 7c 00 01 a2 0d      move.b #$1, -$5df3(a5)
  000c64:  60 74                  bra.b $cda
  000c66:  0c 6d 00 08 a2 5c      cmpi.w #$8, -$5da4(a5)
  000c6c:  66 6c                  bne.b $cda
  000c6e:  1b 7c 00 01 a2 0d      move.b #$1, -$5df3(a5)
  000c74:  7e 00                  moveq #$0, d7
  000c76:  49 ed a2 38            lea.l -$5dc8(a5), a4
  000c7a:  60 28                  bra.b $ca4
  000c7c:  42 a7                  clr.l -(a7)
  000c7e:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  000c84:  30 07                  move.w d7, d0
  000c86:  06 40 0b b8            addi.w #$bb8, d0
  000c8a:  3f 00                  move.w d0, -(a7)
  000c8c:  a9 a0                  dc.w $a9a0
  000c8e:  28 9f                  move.l (a7)+, (a4)
  000c90:  2f 14                  move.l (a4), -(a7)
  000c92:  4e ba 1b 8a            jsr $281e(pc)
  000c96:  4a 00                  tst.b d0
  000c98:  58 8f                  addq.l #$4, a7
  000c9a:  67 04                  beq.b $ca0
  000c9c:  70 ff                  moveq #$ff, d0
  000c9e:  60 3c                  bra.b $cdc
  000ca0:  52 47                  addq.w #$1, d7
  000ca2:  58 8c                  addq.l #$4, a4
  000ca4:  0c 47 00 07            cmpi.w #$7, d7
  000ca8:  6f d2                  ble.b $c7c
  000caa:  1b 7c 00 01 a2 0e      move.b #$1, -$5df2(a5)
  000cb0:  42 a7                  clr.l -(a7)
  000cb2:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  000cb8:  3f 3c 0d ac            move.w #$dac, -(a7)
  000cbc:  a9 a0                  dc.w $a9a0
  000cbe:  2b 5f a2 58            move.l (a7)+, -$5da8(a5)
  000cc2:  2f 2d a2 58            move.l -$5da8(a5), -(a7)
  000cc6:  4e ba 1b 56            jsr $281e(pc)
  000cca:  4a 00                  tst.b d0
  000ccc:  58 8f                  addq.l #$4, a7
  000cce:  67 04                  beq.b $cd4
  000cd0:  70 ff                  moveq #$ff, d0
  000cd2:  60 08                  bra.b $cdc
  000cd4:  1b 7c 00 01 a2 0f      move.b #$1, -$5df1(a5)
  000cda:  70 00                  moveq #$0, d0
  000cdc:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  000ce0:  4e 75                  rts 
  000ce2:  48 6d a0 b6            pea.l -$5f4a(a5)
  000ce6:  a8 74                  dc.w $a874
  000ce8:  4a ad a2 12            tst.l -$5dee(a5)
  000cec:  67 0c                  beq.b $cfa
  000cee:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000cf2:  a8 73                  dc.w $a873
  000cf4:  48 6d a2 1e            pea.l -$5de2(a5)
  000cf8:  a8 a2                  dc.w $a8a2
  000cfa:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  000cfe:  a8 73                  dc.w $a873
  000d00:  4a ad a2 2e            tst.l -$5dd2(a5)
  000d04:  67 06                  beq.b $d0c
  000d06:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000d0a:  aa 93                  dc.w $aa93
  000d0c:  4a ad a2 12            tst.l -$5dee(a5)
  000d10:  67 06                  beq.b $d18
  000d12:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000d16:  a9 14                  dc.w $a914
  000d18:  4e ba 18 f8            jsr $2612(pc)
  000d1c:  30 2d a0 a2            move.w -$5f5e(a5), d0
  000d20:  31 c0 01 44            move.w d0, $144.w
  000d24:  2f 3c 00 00 ff ff      move.l #$ffff, -(a7)
  000d2a:  20 1f                  move.l (a7)+, d0
  000d2c:  a0 32                  dc.w $a032
  000d2e:  4e 75                  rts 
  000d30:  4e 56 ff fc            link.w a6, #$fffc
  000d34:  30 2d a1 e8            move.w -$5e18(a5), d0
  000d38:  0c 40 00 0f            cmpi.w #$f, d0
  000d3c:  62 00 01 46            bhi.w $e84
  000d40:  43 fa 01 54            lea.l $e96(pc), a1
  000d44:  d0 40                  add.w d0, d0
  000d46:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000d4a:  4e d1                  jmp (a1)
  000d4c:  4a 2d 96 1d            tst.b -$69e3(a5)
  000d50:  67 00 01 32            beq.w $e84
  000d54:  42 27                  clr.b -(a7)
  000d56:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000d5a:  48 6d a1 b4            pea.l -$5e4c(a5)
  000d5e:  a8 ad                  dc.w $a8ad
  000d60:  4a 1f                  tst.b (a7)+
  000d62:  67 08                  beq.b $d6c
  000d64:  4e ba 19 0a            jsr $2670(pc)
  000d68:  60 00 01 1a            bra.w $e84
  000d6c:  4e ba 19 18            jsr $2686(pc)
  000d70:  60 00 01 12            bra.w $e84
  000d74:  42 67                  clr.w -(a7)
  000d76:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000d7a:  48 6e ff fc            pea.l -$4(a6)
  000d7e:  a9 2c                  dc.w $a92c
  000d80:  30 1f                  move.w (a7)+, d0
  000d82:  0c 40 00 06            cmpi.w #$6, d0
  000d86:  62 00 00 fc            bhi.w $e84
  000d8a:  43 fa 00 fc            lea.l $e88(pc), a1
  000d8e:  d0 40                  add.w d0, d0
  000d90:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000d94:  4e d1                  jmp (a1)
  000d96:  4e ba 1e ae            jsr $2c46(pc)
  000d9a:  42 a7                  clr.l -(a7)
  000d9c:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000da0:  a9 3d                  dc.w $a93d
  000da2:  4e ba 02 d6            jsr $107a(pc)
  000da6:  4e ba 1e cc            jsr $2c74(pc)
  000daa:  58 8f                  addq.l #$4, a7
  000dac:  60 00 00 d6            bra.w $e84
  000db0:  48 6d a1 e8            pea.l -$5e18(a5)
  000db4:  2f 2e ff fc            move.l -$4(a6), -(a7)
  000db8:  a9 b3                  dc.w $a9b3
  000dba:  60 00 00 c8            bra.w $e84
  000dbe:  20 2e ff fc            move.l -$4(a6), d0
  000dc2:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000dc6:  66 00 00 bc            bne.w $e84
  000dca:  4e ba 18 46            jsr $2612(pc)
  000dce:  48 6d a5 c4            pea.l -$5a3c(a5)
  000dd2:  a9 28                  dc.w $a928
  000dd4:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000dd8:  4e ba 02 2c            jsr $1006(pc)
  000ddc:  58 8f                  addq.l #$4, a7
  000dde:  60 00 00 a4            bra.w $e84
  000de2:  08 2d 00 00 a1 f6      btst.b #$0, -$5e0a(a5)
  000de8:  67 20                  beq.b $e0a
  000dea:  4e ba 1e 5a            jsr $2c46(pc)
  000dee:  42 a7                  clr.l -(a7)
  000df0:  70 ff                  moveq #$ff, d0
  000df2:  c0 2d a1 ed            and.b -$5e13(a5), d0
  000df6:  72 00                  moveq #$0, d1
  000df8:  12 00                  move.b d0, d1
  000dfa:  3f 01                  move.w d1, -(a7)
  000dfc:  a9 3e                  dc.w $a93e
  000dfe:  4e ba 02 7a            jsr $107a(pc)
  000e02:  4e ba 1e 70            jsr $2c74(pc)
  000e06:  58 8f                  addq.l #$4, a7
  000e08:  60 7a                  bra.b $e84
  000e0a:  3f 2d a1 f6            move.w -$5e0a(a5), -(a7)
  000e0e:  70 ff                  moveq #$ff, d0
  000e10:  c0 2d a1 ed            and.b -$5e13(a5), d0
  000e14:  1f 00                  move.b d0, -(a7)
  000e16:  20 2d a1 ea            move.l -$5e16(a5), d0
  000e1a:  02 80 00 00 ff 00      andi.l #$ff00, d0
  000e20:  e0 80                  asr.l #$8, d0
  000e22:  1f 00                  move.b d0, -(a7)
  000e24:  4e ba 01 e8            jsr $100e(pc)
  000e28:  5c 8f                  addq.l #$6, a7
  000e2a:  60 58                  bra.b $e84
  000e2c:  4a 2d 96 1b            tst.b -$69e5(a5)
  000e30:  66 52                  bne.b $e84
  000e32:  2f 2d a1 ea            move.l -$5e16(a5), -(a7)
  000e36:  4e ba 01 a6            jsr $fde(pc)
  000e3a:  58 8f                  addq.l #$4, a7
  000e3c:  60 46                  bra.b $e84
  000e3e:  08 2d 00 00 a1 f7      btst.b #$0, -$5e09(a5)
  000e44:  67 0c                  beq.b $e52
  000e46:  2f 2d a1 ea            move.l -$5e16(a5), -(a7)
  000e4a:  4e ba 00 6a            jsr $eb6(pc)
  000e4e:  58 8f                  addq.l #$4, a7
  000e50:  60 32                  bra.b $e84
  000e52:  2f 2d a1 ea            move.l -$5e16(a5), -(a7)
  000e56:  4e ba 00 ac            jsr $f04(pc)
  000e5a:  58 8f                  addq.l #$4, a7
  000e5c:  60 26                  bra.b $e84
  000e5e:  0c 2d 00 01 a1 ea      cmpi.b #$1, -$5e16(a5)
  000e64:  66 1e                  bne.b $e84
  000e66:  08 2d 00 00 a1 ed      btst.b #$0, -$5e13(a5)
  000e6c:  67 0c                  beq.b $e7a
  000e6e:  42 a7                  clr.l -(a7)
  000e70:  a9 24                  dc.w $a924
  000e72:  4e ba 00 42            jsr $eb6(pc)
  000e76:  58 8f                  addq.l #$4, a7
  000e78:  60 0a                  bra.b $e84
  000e7a:  42 a7                  clr.l -(a7)
  000e7c:  a9 24                  dc.w $a924
  000e7e:  4e ba 00 84            jsr $f04(pc)
  000e82:  58 8f                  addq.l #$4, a7
  000e84:  4e 5e                  unlk a6
  000e86:  4e 75                  rts 
  000e88:  ff fc                  dc.w $fffc
  000e8a:  ff 0e                  dc.w $ff0e
  000e8c:  ff 28                  dc.w $ff28
  000e8e:  ff 36                  dc.w $ff36
  000e90:  ff fc                  dc.w $fffc
  000e92:  ff fc                  dc.w $fffc
  000e94:  ff fc                  dc.w $fffc
  000e96:  fe b6                  dc.w $feb6
  000e98:  fe de                  dc.w $fede
  000e9a:  ff ee                  dc.w $ffee
  000e9c:  ff 4c                  dc.w $ff4c
  000e9e:  ff ee                  dc.w $ffee
  000ea0:  ff ee                  dc.w $ffee
  000ea2:  ff 96                  dc.w $ff96
  000ea4:  ff ee                  dc.w $ffee
  000ea6:  ff a8                  dc.w $ffa8
  000ea8:  ff ee                  dc.w $ffee
  000eaa:  ff ee                  dc.w $ffee
  000eac:  ff ee                  dc.w $ffee
  000eae:  ff ee                  dc.w $ffee
  000eb0:  ff ee                  dc.w $ffee
  000eb2:  ff ee                  dc.w $ffee
  000eb4:  ff c8                  dc.w $ffc8
  000eb6:  4e 56 00 00            link.w a6, #$0
  000eba:  20 2e 00 08            move.l $8(a6), d0
  000ebe:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000ec2:  66 3c                  bne.b $f00
  000ec4:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  000ec8:  42 67                  clr.w -(a7)
  000eca:  a9 39                  dc.w $a939
  000ecc:  2f 2d a1 d8            move.l -$5e28(a5), -(a7)
  000ed0:  42 67                  clr.w -(a7)
  000ed2:  a9 3a                  dc.w $a93a
  000ed4:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  000ed8:  42 67                  clr.w -(a7)
  000eda:  a9 39                  dc.w $a939
  000edc:  a9 37                  dc.w $a937
  000ede:  4e ba 16 b8            jsr $2598(pc)
  000ee2:  2f 2e 00 08            move.l $8(a6), -(a7)
  000ee6:  a8 73                  dc.w $a873
  000ee8:  4a 2d a2 09            tst.b -$5df7(a5)
  000eec:  67 08                  beq.b $ef6
  000eee:  4e ba 0b c6            jsr $1ab6(pc)
  000ef2:  4e ba 0a ce            jsr $19c2(pc)
  000ef6:  4e ba 1d 7c            jsr $2c74(pc)
  000efa:  1b 7c 00 01 96 1b      move.b #$1, -$69e5(a5)
  000f00:  4e 5e                  unlk a6
  000f02:  4e 75                  rts 
  000f04:  4e 56 00 00            link.w a6, #$0
  000f08:  20 2e 00 08            move.l $8(a6), d0
  000f0c:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000f10:  66 50                  bne.b $f62
  000f12:  0c 6d 00 07 96 48      cmpi.w #$7, -$69b8(a5)
  000f18:  66 18                  bne.b $f32
  000f1a:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  000f20:  67 10                  beq.b $f32
  000f22:  48 6d 96 84            pea.l -$697c(a5)
  000f26:  4e ad 05 42            jsr $542(a5)
  000f2a:  3b 7c 00 02 ba 86      move.w #$2, -$457a(a5)
  000f30:  58 8f                  addq.l #$4, a7
  000f32:  4a 2d a2 09            tst.b -$5df7(a5)
  000f36:  67 04                  beq.b $f3c
  000f38:  4e ba 0b ec            jsr $1b26(pc)
  000f3c:  4e ba 1d 08            jsr $2c46(pc)
  000f40:  42 2d 96 1b            clr.b -$69e5(a5)
  000f44:  4e ba 16 cc            jsr $2612(pc)
  000f48:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  000f4c:  42 67                  clr.w -(a7)
  000f4e:  a9 3a                  dc.w $a93a
  000f50:  2f 2d a1 d8            move.l -$5e28(a5), -(a7)
  000f54:  42 67                  clr.w -(a7)
  000f56:  a9 39                  dc.w $a939
  000f58:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  000f5c:  42 67                  clr.w -(a7)
  000f5e:  a9 3a                  dc.w $a93a
  000f60:  a9 37                  dc.w $a937
  000f62:  4e 5e                  unlk a6
  000f64:  4e 75                  rts 
  000f66:  4e 56 00 00            link.w a6, #$0
  000f6a:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  000f6e:  26 6e 00 08            movea.l $8(a6), a3
  000f72:  4a 2d a2 09            tst.b -$5df7(a5)
  000f76:  67 46                  beq.b $fbe
  000f78:  20 6d a1 c4            movea.l -$5e3c(a5), a0
  000f7c:  20 50                  movea.l (a0), a0
  000f7e:  2e 10                  move.l (a0), d7
  000f80:  be ad a1 c8            cmp.l -$5e38(a5), d7
  000f84:  67 38                  beq.b $fbe
  000f86:  7c ff                  moveq #$ff, d6
  000f88:  20 6d a1 c0            movea.l -$5e40(a5), a0
  000f8c:  28 50                  movea.l (a0), a4
  000f8e:  3a 2c 00 1e            move.w $1e(a4), d5
  000f92:  4a 45                  tst.w d5
  000f94:  67 06                  beq.b $f9c
  000f96:  0c 45 00 10            cmpi.w #$10, d5
  000f9a:  66 08                  bne.b $fa4
  000f9c:  3c 2c 00 24            move.w $24(a4), d6
  000fa0:  cd ec 00 22            muls.w $22(a4), d6
  000fa4:  bc 6d a1 ae            cmp.w -$5e52(a5), d6
  000fa8:  67 0c                  beq.b $fb6
  000faa:  42 67                  clr.w -(a7)
  000fac:  3f 3c 03 ec            move.w #$3ec, -(a7)
  000fb0:  42 a7                  clr.l -(a7)
  000fb2:  a9 85                  dc.w $a985
  000fb4:  54 8f                  addq.l #$2, a7
  000fb6:  4e ba 0a 0a            jsr $19c2(pc)
  000fba:  2b 47 a1 c8            move.l d7, -$5e38(a5)
  000fbe:  2f 0b                  move.l a3, -(a7)
  000fc0:  a9 22                  dc.w $a922
  000fc2:  b7 ed a2 12            cmpa.l -$5dee(a5), a3
  000fc6:  66 0a                  bne.b $fd2
  000fc8:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000fcc:  a8 d3                  dc.w $a8d3
  000fce:  4e ba 0c 5a            jsr $1c2a(pc)
  000fd2:  2f 0b                  move.l a3, -(a7)
  000fd4:  a9 23                  dc.w $a923
  000fd6:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  000fda:  4e 5e                  unlk a6
  000fdc:  4e 75                  rts 
  000fde:  4e 56 ff fc            link.w a6, #$fffc
  000fe2:  2f 2e 00 08            move.l $8(a6), -(a7)
  000fe6:  a9 22                  dc.w $a922
  000fe8:  20 2e 00 08            move.l $8(a6), d0
  000fec:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000ff0:  66 0a                  bne.b $ffc
  000ff2:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000ff6:  a8 d3                  dc.w $a8d3
  000ff8:  4e ba 0c 30            jsr $1c2a(pc)
  000ffc:  2f 2e 00 08            move.l $8(a6), -(a7)
  001000:  a9 23                  dc.w $a923
  001002:  4e 5e                  unlk a6
  001004:  4e 75                  rts 
  001006:  4e 56 00 00            link.w a6, #$0
  00100a:  4e 5e                  unlk a6
  00100c:  4e 75                  rts 
  00100e:  4e 56 00 00            link.w a6, #$0
  001012:  10 2e 00 0a            move.b $a(a6), d0
  001016:  6b 5e                  bmi.b $1076
  001018:  04 00 00 1b            subi.b #$1b, d0
  00101c:  67 20                  beq.b $103e
  00101e:  6a 0e                  bpl.b $102e
  001020:  04 00 00 ee            subi.b #$ee, d0
  001024:  67 24                  beq.b $104a
  001026:  6a 4e                  bpl.b $1076
  001028:  52 00                  addq.b #$1, d0
  00102a:  6a 3a                  bpl.b $1066
  00102c:  60 48                  bra.b $1076
  00102e:  04 00 00 45            subi.b #$45, d0
  001032:  67 0a                  beq.b $103e
  001034:  6a 40                  bpl.b $1076
  001036:  04 00 00 c0            subi.b #$c0, d0
  00103a:  67 08                  beq.b $1044
  00103c:  60 38                  bra.b $1076
  00103e:  4e ba 06 c6            jsr $1706(pc)
  001042:  60 32                  bra.b $1076
  001044:  4e ba 07 cc            jsr $1812(pc)
  001048:  60 2c                  bra.b $1076
  00104a:  4e ba 1b fa            jsr $2c46(pc)
  00104e:  1b 7c 00 01 96 58      move.b #$1, -$69a8(a5)
  001054:  4e ba 08 52            jsr $18a8(pc)
  001058:  1b 7c 00 01 96 2f      move.b #$1, -$69d1(a5)
  00105e:  1b 7c 00 01 96 2c      move.b #$1, -$69d4(a5)
  001064:  60 10                  bra.b $1076
  001066:  4a 2d 96 1d            tst.b -$69e3(a5)
  00106a:  66 06                  bne.b $1072
  00106c:  4e ba 15 2a            jsr $2598(pc)
  001070:  60 04                  bra.b $1076
  001072:  4e ba 15 9e            jsr $2612(pc)
  001076:  4e 5e                  unlk a6
  001078:  4e 75                  rts 
  00107a:  4e 56 ff 00            link.w a6, #$ff00
  00107e:  2f 07                  move.l d7, -(a7)
  001080:  4e ba 16 04            jsr $2686(pc)
  001084:  42 67                  clr.w -(a7)
  001086:  2f 2e 00 08            move.l $8(a6), -(a7)
  00108a:  a8 6b                  dc.w $a86b
  00108c:  3e 1f                  move.w (a7)+, d7
  00108e:  42 67                  clr.w -(a7)
  001090:  2f 2e 00 08            move.l $8(a6), -(a7)
  001094:  a8 6a                  dc.w $a86a
  001096:  30 1f                  move.w (a7)+, d0
  001098:  6b 00 00 ca            bmi.w $1164
  00109c:  04 40 03 ea            subi.w #$3ea, d0
  0010a0:  67 78                  beq.b $111a
  0010a2:  6a 0a                  bpl.b $10ae
  0010a4:  54 40                  addq.w #$2, d0
  0010a6:  67 0e                  beq.b $10b6
  0010a8:  6a 38                  bpl.b $10e2
  0010aa:  60 00 00 b8            bra.w $1164
  0010ae:  55 40                  subq.w #$2, d0
  0010b0:  6a 00 00 b2            bpl.w $1164
  0010b4:  60 78                  bra.b $112e
  0010b6:  30 07                  move.w d7, d0
  0010b8:  67 0e                  beq.b $10c8
  0010ba:  6b 0c                  bmi.b $10c8
  0010bc:  55 40                  subq.w #$2, d0
  0010be:  6a 08                  bpl.b $10c8
  0010c0:  4e ba 00 d8            jsr $119a(pc)
  0010c4:  60 00 00 9e            bra.w $1164
  0010c8:  2f 2d a1 d0            move.l -$5e30(a5), -(a7)
  0010cc:  3f 07                  move.w d7, -(a7)
  0010ce:  48 6e ff 00            pea.l -$100(a6)
  0010d2:  a9 46                  dc.w $a946
  0010d4:  42 67                  clr.w -(a7)
  0010d6:  48 6e ff 00            pea.l -$100(a6)
  0010da:  a9 b6                  dc.w $a9b6
  0010dc:  54 8f                  addq.l #$2, a7
  0010de:  60 00 00 84            bra.w $1164
  0010e2:  30 07                  move.w d7, d0
  0010e4:  0c 40 00 08            cmpi.w #$8, d0
  0010e8:  62 7a                  bhi.b $1164
  0010ea:  43 fa 00 9c            lea.l $1188(pc), a1
  0010ee:  d0 40                  add.w d0, d0
  0010f0:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0010f4:  4e d1                  jmp (a1)
  0010f6:  4e ba 00 f6            jsr $11ee(pc)
  0010fa:  60 68                  bra.b $1164
  0010fc:  4e ba 01 24            jsr $1222(pc)
  001100:  60 62                  bra.b $1164
  001102:  4e ba 01 48            jsr $124c(pc)
  001106:  60 5c                  bra.b $1164
  001108:  4e ba 01 84            jsr $128e(pc)
  00110c:  60 56                  bra.b $1164
  00110e:  4e ba 01 bc            jsr $12cc(pc)
  001112:  60 50                  bra.b $1164
  001114:  4e ba 01 ee            jsr $1304(pc)
  001118:  60 4a                  bra.b $1164
  00111a:  4a 2d 96 1b            tst.b -$69e5(a5)
  00111e:  66 44                  bne.b $1164
  001120:  42 27                  clr.b -(a7)
  001122:  70 ff                  moveq #$ff, d0
  001124:  d0 47                  add.w d7, d0
  001126:  3f 00                  move.w d0, -(a7)
  001128:  a9 c2                  dc.w $a9c2
  00112a:  54 8f                  addq.l #$2, a7
  00112c:  60 36                  bra.b $1164
  00112e:  30 07                  move.w d7, d0
  001130:  0c 40 00 07            cmpi.w #$7, d0
  001134:  62 2e                  bhi.b $1164
  001136:  43 fa 00 40            lea.l $1178(pc), a1
  00113a:  d0 40                  add.w d0, d0
  00113c:  d2 f1 00 00            adda.w (a1, d0.w), a1
  001140:  4e d1                  jmp (a1)
  001142:  4e ba 05 c2            jsr $1706(pc)
  001146:  60 1c                  bra.b $1164
  001148:  4e ba 06 18            jsr $1762(pc)
  00114c:  60 16                  bra.b $1164
  00114e:  4e ba 06 5c            jsr $17ac(pc)
  001152:  60 10                  bra.b $1164
  001154:  4e ba 06 a2            jsr $17f8(pc)
  001158:  60 0a                  bra.b $1164
  00115a:  4e ba 06 b6            jsr $1812(pc)
  00115e:  60 04                  bra.b $1164
  001160:  4e ba 06 c8            jsr $182a(pc)
  001164:  42 67                  clr.w -(a7)
  001166:  a9 38                  dc.w $a938
  001168:  4a 2d 96 1b            tst.b -$69e5(a5)
  00116c:  67 04                  beq.b $1172
  00116e:  4e ba 14 28            jsr $2598(pc)
  001172:  2e 1f                  move.l (a7)+, d7
  001174:  4e 5e                  unlk a6
  001176:  4e 75                  rts 
  001178:  ff ec                  dc.w $ffec
  00117a:  ff ca                  dc.w $ffca
  00117c:  ff d0                  dc.w $ffd0
  00117e:  ff d6                  dc.w $ffd6
  001180:  ff ec                  dc.w $ffec
  001182:  ff dc                  dc.w $ffdc
  001184:  ff e2                  dc.w $ffe2
  001186:  ff e8                  dc.w $ffe8
  001188:  ff dc                  dc.w $ffdc
  00118a:  ff 6e                  dc.w $ff6e
  00118c:  ff 74                  dc.w $ff74
  00118e:  ff dc                  dc.w $ffdc
  001190:  ff 7a                  dc.w $ff7a
  001192:  ff 80                  dc.w $ff80
  001194:  ff 86                  dc.w $ff86
  001196:  ff dc                  dc.w $ffdc
  001198:  ff 8c                  dc.w $ff8c
  00119a:  4e 56 ff fe            link.w a6, #$fffe
  00119e:  48 e7 00 18            movem.l a3-a4, -(a7)
  0011a2:  42 a7                  clr.l -(a7)
  0011a4:  2f 3c 50 6f c4 50      move.l #$506fc450, -(a7)
  0011aa:  42 67                  clr.w -(a7)
  0011ac:  a9 a0                  dc.w $a9a0
  0011ae:  28 5f                  movea.l (a7)+, a4
  0011b0:  4e ba 14 e2            jsr $2694(pc)
  0011b4:  2f 14                  move.l (a4), -(a7)
  0011b6:  42 a7                  clr.l -(a7)
  0011b8:  42 a7                  clr.l -(a7)
  0011ba:  42 a7                  clr.l -(a7)
  0011bc:  a9 8b                  dc.w $a98b
  0011be:  42 a7                  clr.l -(a7)
  0011c0:  3f 3c 03 e8            move.w #$3e8, -(a7)
  0011c4:  42 a7                  clr.l -(a7)
  0011c6:  48 78 ff ff            pea.l $ffff.w
  0011ca:  a9 7c                  dc.w $a97c
  0011cc:  26 5f                  movea.l (a7)+, a3
  0011ce:  20 0b                  move.l a3, d0
  0011d0:  67 0c                  beq.b $11de
  0011d2:  42 a7                  clr.l -(a7)
  0011d4:  48 6e ff fe            pea.l -$2(a6)
  0011d8:  a9 91                  dc.w $a991
  0011da:  2f 0b                  move.l a3, -(a7)
  0011dc:  a9 83                  dc.w $a983
  0011de:  4e ba 14 be            jsr $269e(pc)
  0011e2:  2f 0c                  move.l a4, -(a7)
  0011e4:  a9 a3                  dc.w $a9a3
  0011e6:  4c df 18 00            movem.l (a7)+, a3-a4
  0011ea:  4e 5e                  unlk a6
  0011ec:  4e 75                  rts 
  0011ee:  4e ba 02 c2            jsr $14b2(pc)
  0011f2:  3b 7c 00 01 ba 64      move.w #$1, -$459c(a5)
  0011f8:  42 2d a1 24            clr.b -$5edc(a5)
  0011fc:  70 00                  moveq #$0, d0
  0011fe:  48 80                  ext.w d0
  001200:  3b 40 a1 22            move.w d0, -$5ede(a5)
  001204:  3b 40 b9 3e            move.w d0, -$46c2(a5)
  001208:  42 2d 96 1f            clr.b -$69e1(a5)
  00120c:  3b 7c 00 04 96 48      move.w #$4, -$69b8(a5)
  001212:  3f 3c 00 03            move.w #$3, -(a7)
  001216:  4e ba 0f da            jsr $21f2(pc)
  00121a:  4e ba 05 2c            jsr $1748(pc)
  00121e:  54 8f                  addq.l #$2, a7
  001220:  4e 75                  rts 
  001222:  4a 2d 96 2d            tst.b -$69d3(a5)
  001226:  67 22                  beq.b $124a
  001228:  4e ba 02 88            jsr $14b2(pc)
  00122c:  42 2d a1 24            clr.b -$5edc(a5)
  001230:  70 00                  moveq #$0, d0
  001232:  48 80                  ext.w d0
  001234:  3b 40 a1 22            move.w d0, -$5ede(a5)
  001238:  3b 40 b9 3e            move.w d0, -$46c2(a5)
  00123c:  42 2d 96 1f            clr.b -$69e1(a5)
  001240:  3b 7c 00 0a 96 48      move.w #$a, -$69b8(a5)
  001246:  4e ba 05 00            jsr $1748(pc)
  00124a:  4e 75                  rts 
  00124c:  4e ba 02 64            jsr $14b2(pc)
  001250:  4e ba 00 c6            jsr $1318(pc)
  001254:  4a 00                  tst.b d0
  001256:  67 34                  beq.b $128c
  001258:  4e ba 02 9c            jsr $14f6(pc)
  00125c:  4a 00                  tst.b d0
  00125e:  67 2c                  beq.b $128c
  001260:  4a 6d ba 62            tst.w -$459e(a5)
  001264:  6d 06                  blt.b $126c
  001266:  3b 6d ba 64 ba 62      move.w -$459c(a5), -$459e(a5)
  00126c:  1b 7c 00 01 96 1f      move.b #$1, -$69e1(a5)
  001272:  3b 7c 00 01 b9 3e      move.w #$1, -$46c2(a5)
  001278:  3b 7c 00 04 96 48      move.w #$4, -$69b8(a5)
  00127e:  3f 3c 00 03            move.w #$3, -(a7)
  001282:  4e ba 0f 6e            jsr $21f2(pc)
  001286:  4e ba 04 c0            jsr $1748(pc)
  00128a:  54 8f                  addq.l #$2, a7
  00128c:  4e 75                  rts 
  00128e:  4a 2d 96 2d            tst.b -$69d3(a5)
  001292:  67 36                  beq.b $12ca
  001294:  4a 2d 96 2e            tst.b -$69d2(a5)
  001298:  67 30                  beq.b $12ca
  00129a:  4a 6d a1 22            tst.w -$5ede(a5)
  00129e:  66 08                  bne.b $12a8
  0012a0:  4e ba 00 de            jsr $1380(pc)
  0012a4:  4a 00                  tst.b d0
  0012a6:  67 22                  beq.b $12ca
  0012a8:  4e ba 03 46            jsr $15f0(pc)
  0012ac:  4a 00                  tst.b d0
  0012ae:  67 1a                  beq.b $12ca
  0012b0:  1b 7c 00 01 96 1f      move.b #$1, -$69e1(a5)
  0012b6:  48 6d 97 06            pea.l -$68fa(a5)
  0012ba:  4e ad 05 42            jsr $542(a5)
  0012be:  3b 7c 00 0f ba 86      move.w #$f, -$457a(a5)
  0012c4:  4e ba 04 82            jsr $1748(pc)
  0012c8:  58 8f                  addq.l #$4, a7
  0012ca:  4e 75                  rts 
  0012cc:  4a 2d 96 2d            tst.b -$69d3(a5)
  0012d0:  67 30                  beq.b $1302
  0012d2:  4a 2d 96 2e            tst.b -$69d2(a5)
  0012d6:  67 2a                  beq.b $1302
  0012d8:  4e ba 00 a6            jsr $1380(pc)
  0012dc:  4a 00                  tst.b d0
  0012de:  67 22                  beq.b $1302
  0012e0:  4e ba 03 0e            jsr $15f0(pc)
  0012e4:  4a 00                  tst.b d0
  0012e6:  67 1a                  beq.b $1302
  0012e8:  1b 7c 00 01 96 1f      move.b #$1, -$69e1(a5)
  0012ee:  48 6d 97 06            pea.l -$68fa(a5)
  0012f2:  4e ad 05 42            jsr $542(a5)
  0012f6:  3b 7c 00 0f ba 86      move.w #$f, -$457a(a5)
  0012fc:  4e ba 04 4a            jsr $1748(pc)
  001300:  58 8f                  addq.l #$4, a7
  001302:  4e 75                  rts 
  001304:  4e ba 01 ac            jsr $14b2(pc)
  001308:  4e ba 17 40            jsr $2a4a(pc)
  00130c:  42 2d 96 2c            clr.b -$69d4(a5)
  001310:  1b 7c 00 01 96 1e      move.b #$1, -$69e2(a5)
  001316:  4e 75                  rts 
  001318:  4e 56 ff a2            link.w a6, #$ffa2
  00131c:  4e ba 13 76            jsr $2694(pc)
  001320:  2d 7c 50 50 73 67 ff f0 move.l #$50507367, -$10(a6)
  001328:  3d 7c 00 3c ff ec      move.w #$3c, -$14(a6)
  00132e:  3d 7c 00 50 ff ee      move.w #$50, -$12(a6)
  001334:  2f 2e ff ec            move.l -$14(a6), -(a7)
  001338:  48 6d 97 12            pea.l -$68ee(a5)
  00133c:  42 a7                  clr.l -(a7)
  00133e:  3f 3c 00 01            move.w #$1, -(a7)
  001342:  48 6e ff f0            pea.l -$10(a6)
  001346:  42 a7                  clr.l -(a7)
  001348:  48 6e ff a2            pea.l -$5e(a6)
  00134c:  3f 3c 00 02            move.w #$2, -(a7)
  001350:  a9 ea                  dc.w $a9ea
  001352:  4e ba 13 4a            jsr $269e(pc)
  001356:  4a 2e ff a2            tst.b -$5e(a6)
  00135a:  67 1e                  beq.b $137a
  00135c:  3b 6e ff a8 a1 22      move.w -$58(a6), -$5ede(a5)
  001362:  41 ee ff ac            lea.l -$54(a6), a0
  001366:  43 ed a1 24            lea.l -$5edc(a5), a1
  00136a:  70 00                  moveq #$0, d0
  00136c:  10 2e ff ac            move.b -$54(a6), d0
  001370:  52 40                  addq.w #$1, d0
  001372:  48 c0                  ext.l d0
  001374:  a0 2e                  dc.w $a02e
  001376:  70 01                  moveq #$1, d0
  001378:  60 02                  bra.b $137c
  00137a:  70 00                  moveq #$0, d0
  00137c:  4e 5e                  unlk a6
  00137e:  4e 75                  rts 
  001380:  4e 56 ff 9c            link.w a6, #$ff9c
  001384:  2f 0c                  move.l a4, -(a7)
  001386:  4a 2d a1 24            tst.b -$5edc(a5)
  00138a:  67 06                  beq.b $1392
  00138c:  49 ed a1 24            lea.l -$5edc(a5), a4
  001390:  60 04                  bra.b $1396
  001392:  49 ed 97 2c            lea.l -$68d4(a5), a4
  001396:  4e ba 12 fc            jsr $2694(pc)
  00139a:  3d 7c 00 3c ff fc      move.w #$3c, -$4(a6)
  0013a0:  3d 7c 00 50 ff fe      move.w #$50, -$2(a6)
  0013a6:  2f 2e ff fc            move.l -$4(a6), -(a7)
  0013aa:  48 6d 97 1e            pea.l -$68e2(a5)
  0013ae:  2f 0c                  move.l a4, -(a7)
  0013b0:  42 a7                  clr.l -(a7)
  0013b2:  48 6e ff b2            pea.l -$4e(a6)
  0013b6:  3f 3c 00 01            move.w #$1, -(a7)
  0013ba:  a9 ea                  dc.w $a9ea
  0013bc:  4e ba 12 e0            jsr $269e(pc)
  0013c0:  4a 2e ff b2            tst.b -$4e(a6)
  0013c4:  67 00 00 e0            beq.w $14a6
  0013c8:  42 67                  clr.w -(a7)
  0013ca:  48 6e ff bc            pea.l -$44(a6)
  0013ce:  3f 2e ff b8            move.w -$48(a6), -(a7)
  0013d2:  48 6e ff a2            pea.l -$5e(a6)
  0013d6:  4e ba 2e c6            jsr $429e(pc)
  0013da:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0013de:  4a 6d a1 6c            tst.w -$5e94(a5)
  0013e2:  66 1c                  bne.b $1400
  0013e4:  0c ae 50 6f c4 50 ff a6 cmpi.l #$506fc450, -$5a(a6)
  0013ec:  66 00 00 bc            bne.w $14aa
  0013f0:  0c ae 50 50 73 67 ff a2 cmpi.l #$50507367, -$5e(a6)
  0013f8:  66 00 00 b0            bne.w $14aa
  0013fc:  60 00 00 8a            bra.w $1488
  001400:  0c 6d ff d5 a1 6c      cmpi.w #$ffd5, -$5e94(a5)
  001406:  66 00 00 a2            bne.w $14aa
  00140a:  42 67                  clr.w -(a7)
  00140c:  48 6e ff bc            pea.l -$44(a6)
  001410:  3f 2e ff b8            move.w -$48(a6), -(a7)
  001414:  2f 3c 50 6f c4 50      move.l #$506fc450, -(a7)
  00141a:  2f 3c 50 50 73 67      move.l #$50507367, -(a7)
  001420:  4e ba 2e f4            jsr $4316(pc)
  001424:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001428:  4a 6d a1 6c            tst.w -$5e94(a5)
  00142c:  66 7c                  bne.b $14aa
  00142e:  42 67                  clr.w -(a7)
  001430:  48 6e ff bc            pea.l -$44(a6)
  001434:  3f 2e ff b8            move.w -$48(a6), -(a7)
  001438:  48 6e ff a0            pea.l -$60(a6)
  00143c:  4e ba 2d be            jsr $41fc(pc)
  001440:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001444:  4a 6d a1 6c            tst.w -$5e94(a5)
  001448:  66 60                  bne.b $14aa
  00144a:  70 10                  moveq #$10, d0
  00144c:  2d 40 ff 9c            move.l d0, -$64(a6)
  001450:  42 67                  clr.w -(a7)
  001452:  3f 2e ff a0            move.w -$60(a6), -(a7)
  001456:  48 6e ff 9c            pea.l -$64(a6)
  00145a:  4e ba 2f 1c            jsr $4378(pc)
  00145e:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001462:  42 67                  clr.w -(a7)
  001464:  3f 2e ff a0            move.w -$60(a6), -(a7)
  001468:  4e ba 2d d2            jsr $423c(pc)
  00146c:  4a 6d a1 6c            tst.w -$5e94(a5)
  001470:  54 8f                  addq.l #$2, a7
  001472:  67 14                  beq.b $1488
  001474:  42 67                  clr.w -(a7)
  001476:  48 6e ff bc            pea.l -$44(a6)
  00147a:  3f 2e ff b8            move.w -$48(a6), -(a7)
  00147e:  4e ba 2e d4            jsr $4354(pc)
  001482:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001486:  60 22                  bra.b $14aa
  001488:  3b 6e ff b8 a1 22      move.w -$48(a6), -$5ede(a5)
  00148e:  41 ee ff bc            lea.l -$44(a6), a0
  001492:  43 ed a1 24            lea.l -$5edc(a5), a1
  001496:  70 00                  moveq #$0, d0
  001498:  10 2e ff bc            move.b -$44(a6), d0
  00149c:  52 40                  addq.w #$1, d0
  00149e:  48 c0                  ext.l d0
  0014a0:  a0 2e                  dc.w $a02e
  0014a2:  70 01                  moveq #$1, d0
  0014a4:  60 06                  bra.b $14ac
  0014a6:  70 00                  moveq #$0, d0
  0014a8:  60 02                  bra.b $14ac
  0014aa:  70 00                  moveq #$0, d0
  0014ac:  28 5f                  movea.l (a7)+, a4
  0014ae:  4e 5e                  unlk a6
  0014b0:  4e 75                  rts 
  0014b2:  2f 07                  move.l d7, -(a7)
  0014b4:  7e 00                  moveq #$0, d7
  0014b6:  4a 2d 96 2d            tst.b -$69d3(a5)
  0014ba:  67 34                  beq.b $14f0
  0014bc:  4a 2d 96 1f            tst.b -$69e1(a5)
  0014c0:  66 2e                  bne.b $14f0
  0014c2:  0c 6d 00 01 ba 64      cmpi.w #$1, -$459c(a5)
  0014c8:  67 26                  beq.b $14f0
  0014ca:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  0014d0:  67 1e                  beq.b $14f0
  0014d2:  4e ba 11 c0            jsr $2694(pc)
  0014d6:  42 67                  clr.w -(a7)
  0014d8:  3f 3c 03 ef            move.w #$3ef, -(a7)
  0014dc:  42 a7                  clr.l -(a7)
  0014de:  a9 85                  dc.w $a985
  0014e0:  0c 5f 00 01            cmpi.w #$1, (a7)+
  0014e4:  66 06                  bne.b $14ec
  0014e6:  4e ba fd a6            jsr $128e(pc)
  0014ea:  7e 01                  moveq #$1, d7
  0014ec:  4e ba 11 b0            jsr $269e(pc)
  0014f0:  10 07                  move.b d7, d0
  0014f2:  2e 1f                  move.l (a7)+, d7
  0014f4:  4e 75                  rts 
  0014f6:  4e 56 ff ea            link.w a6, #$ffea
  0014fa:  2f 07                  move.l d7, -(a7)
  0014fc:  42 67                  clr.w -(a7)
  0014fe:  48 6d a1 24            pea.l -$5edc(a5)
  001502:  3f 2d a1 22            move.w -$5ede(a5), -(a7)
  001506:  48 6e ff ee            pea.l -$12(a6)
  00150a:  4e ba 2c f0            jsr $41fc(pc)
  00150e:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001512:  4a 6d a1 6c            tst.w -$5e94(a5)
  001516:  66 00 00 c4            bne.w $15dc
  00151a:  42 67                  clr.w -(a7)
  00151c:  3f 2e ff ee            move.w -$12(a6), -(a7)
  001520:  3f 3c 00 01            move.w #$1, -(a7)
  001524:  42 a7                  clr.l -(a7)
  001526:  4e ba 2e 76            jsr $439e(pc)
  00152a:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  00152e:  4a 6d a1 6c            tst.w -$5e94(a5)
  001532:  66 00 00 a8            bne.w $15dc
  001536:  70 10                  moveq #$10, d0
  001538:  2d 40 ff ea            move.l d0, -$16(a6)
  00153c:  42 67                  clr.w -(a7)
  00153e:  3f 2e ff ee            move.w -$12(a6), -(a7)
  001542:  48 6e ff ea            pea.l -$16(a6)
  001546:  48 6e ff f0            pea.l -$10(a6)
  00154a:  4e ba 2d 0a            jsr $4256(pc)
  00154e:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001552:  4a 6d a1 6c            tst.w -$5e94(a5)
  001556:  66 00 00 84            bne.w $15dc
  00155a:  42 67                  clr.w -(a7)
  00155c:  3f 2e ff ee            move.w -$12(a6), -(a7)
  001560:  4e ba 2c da            jsr $423c(pc)
  001564:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001568:  4a 6d a1 6c            tst.w -$5e94(a5)
  00156c:  66 6e                  bne.b $15dc
  00156e:  3e 2e ff fe            move.w -$2(a6), d7
  001572:  70 0d                  moveq #$d, d0
  001574:  c1 ee ff fc            muls.w -$4(a6), d0
  001578:  de 40                  add.w d0, d7
  00157a:  70 17                  moveq #$17, d0
  00157c:  c1 ee ff fa            muls.w -$6(a6), d0
  001580:  de 40                  add.w d0, d7
  001582:  30 3c 00 c1            move.w #$c1, d0
  001586:  c1 ee ff f8            muls.w -$8(a6), d0
  00158a:  de 40                  add.w d0, d7
  00158c:  70 25                  moveq #$25, d0
  00158e:  c1 ee ff f6            muls.w -$a(a6), d0
  001592:  de 40                  add.w d0, d7
  001594:  70 11                  moveq #$11, d0
  001596:  c1 ee ff f4            muls.w -$c(a6), d0
  00159a:  de 40                  add.w d0, d7
  00159c:  de 6e ff f2            add.w -$e(a6), d7
  0015a0:  70 0b                  moveq #$b, d0
  0015a2:  c1 ee ff f0            muls.w -$10(a6), d0
  0015a6:  de 40                  add.w d0, d7
  0015a8:  be 6d 96 20            cmp.w -$69e0(a5), d7
  0015ac:  66 3a                  bne.b $15e8
  0015ae:  3b 6e ff f0 ba 8c      move.w -$10(a6), -$4574(a5)
  0015b4:  3b 6e ff f2 ba 80      move.w -$e(a6), -$4580(a5)
  0015ba:  3b 6e ff f4 ba 64      move.w -$c(a6), -$459c(a5)
  0015c0:  3b 6e ff f6 ba 46      move.w -$a(a6), -$45ba(a5)
  0015c6:  3b 6e ff f8 ba 40      move.w -$8(a6), -$45c0(a5)
  0015cc:  3b 6e ff fa 96 34      move.w -$6(a6), -$69cc(a5)
  0015d2:  3b 6e ff fc 96 36      move.w -$4(a6), -$69ca(a5)
  0015d8:  70 01                  moveq #$1, d0
  0015da:  60 0e                  bra.b $15ea
  0015dc:  42 67                  clr.w -(a7)
  0015de:  3f 2e ff ee            move.w -$12(a6), -(a7)
  0015e2:  4e ba 2c 58            jsr $423c(pc)
  0015e6:  54 8f                  addq.l #$2, a7
  0015e8:  70 00                  moveq #$0, d0
  0015ea:  2e 1f                  move.l (a7)+, d7
  0015ec:  4e 5e                  unlk a6
  0015ee:  4e 75                  rts 
  0015f0:  4e 56 ff ea            link.w a6, #$ffea
  0015f4:  2f 07                  move.l d7, -(a7)
  0015f6:  3d 6d ba 8c ff f0      move.w -$4574(a5), -$10(a6)
  0015fc:  3d 6d ba 80 ff f2      move.w -$4580(a5), -$e(a6)
  001602:  3d 6d ba 64 ff f4      move.w -$459c(a5), -$c(a6)
  001608:  3d 6d ba 46 ff f6      move.w -$45ba(a5), -$a(a6)
  00160e:  3d 6d ba 40 ff f8      move.w -$45c0(a5), -$8(a6)
  001614:  3d 6d 96 34 ff fa      move.w -$69cc(a5), -$6(a6)
  00161a:  3d 6d 96 36 ff fc      move.w -$69ca(a5), -$4(a6)
  001620:  3e 2d 96 20            move.w -$69e0(a5), d7
  001624:  70 0b                  moveq #$b, d0
  001626:  c1 ee ff f0            muls.w -$10(a6), d0
  00162a:  9e 40                  sub.w d0, d7
  00162c:  9e 6e ff f2            sub.w -$e(a6), d7
  001630:  70 11                  moveq #$11, d0
  001632:  c1 ee ff f4            muls.w -$c(a6), d0
  001636:  9e 40                  sub.w d0, d7
  001638:  70 25                  moveq #$25, d0
  00163a:  c1 ee ff f6            muls.w -$a(a6), d0
  00163e:  9e 40                  sub.w d0, d7
  001640:  30 3c 00 c1            move.w #$c1, d0
  001644:  c1 ee ff f8            muls.w -$8(a6), d0
  001648:  9e 40                  sub.w d0, d7
  00164a:  70 17                  moveq #$17, d0
  00164c:  c1 ee ff fa            muls.w -$6(a6), d0
  001650:  9e 40                  sub.w d0, d7
  001652:  70 0d                  moveq #$d, d0
  001654:  c1 ee ff fc            muls.w -$4(a6), d0
  001658:  9e 40                  sub.w d0, d7
  00165a:  3d 47 ff fe            move.w d7, -$2(a6)
  00165e:  42 6e ff ee            clr.w -$12(a6)
  001662:  42 67                  clr.w -(a7)
  001664:  48 6d a1 24            pea.l -$5edc(a5)
  001668:  3f 2d a1 22            move.w -$5ede(a5), -(a7)
  00166c:  48 6e ff ee            pea.l -$12(a6)
  001670:  4e ba 2b 8a            jsr $41fc(pc)
  001674:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001678:  4a 6d a1 6c            tst.w -$5e94(a5)
  00167c:  66 6e                  bne.b $16ec
  00167e:  42 67                  clr.w -(a7)
  001680:  3f 2e ff ee            move.w -$12(a6), -(a7)
  001684:  3f 3c 00 01            move.w #$1, -(a7)
  001688:  42 a7                  clr.l -(a7)
  00168a:  4e ba 2d 12            jsr $439e(pc)
  00168e:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001692:  4a 6d a1 6c            tst.w -$5e94(a5)
  001696:  66 54                  bne.b $16ec
  001698:  70 10                  moveq #$10, d0
  00169a:  2d 40 ff ea            move.l d0, -$16(a6)
  00169e:  42 67                  clr.w -(a7)
  0016a0:  3f 2e ff ee            move.w -$12(a6), -(a7)
  0016a4:  48 6e ff ea            pea.l -$16(a6)
  0016a8:  48 6e ff f0            pea.l -$10(a6)
  0016ac:  4e ba 2b ac            jsr $425a(pc)
  0016b0:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0016b4:  4a 6d a1 6c            tst.w -$5e94(a5)
  0016b8:  66 32                  bne.b $16ec
  0016ba:  42 67                  clr.w -(a7)
  0016bc:  3f 2e ff ee            move.w -$12(a6), -(a7)
  0016c0:  4e ba 2b 7a            jsr $423c(pc)
  0016c4:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0016c8:  4a 6d a1 6c            tst.w -$5e94(a5)
  0016cc:  66 1e                  bne.b $16ec
  0016ce:  42 6e ff ee            clr.w -$12(a6)
  0016d2:  42 67                  clr.w -(a7)
  0016d4:  42 a7                  clr.l -(a7)
  0016d6:  3f 2d a1 22            move.w -$5ede(a5), -(a7)
  0016da:  4e ba 2c 1a            jsr $42f6(pc)
  0016de:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0016e2:  4a 6d a1 6c            tst.w -$5e94(a5)
  0016e6:  66 04                  bne.b $16ec
  0016e8:  70 01                  moveq #$1, d0
  0016ea:  60 14                  bra.b $1700
  0016ec:  4a 6e ff ee            tst.w -$12(a6)
  0016f0:  67 0c                  beq.b $16fe
  0016f2:  42 67                  clr.w -(a7)
  0016f4:  3f 2e ff ee            move.w -$12(a6), -(a7)
  0016f8:  4e ba 2b 42            jsr $423c(pc)
  0016fc:  54 8f                  addq.l #$2, a7
  0016fe:  70 00                  moveq #$0, d0
  001700:  2e 1f                  move.l (a7)+, d7
  001702:  4e 5e                  unlk a6
  001704:  4e 75                  rts 
  001706:  4a 2d 96 58            tst.b -$69a8(a5)
  00170a:  67 10                  beq.b $171c
  00170c:  4e ba 15 66            jsr $2c74(pc)
  001710:  42 2d 96 58            clr.b -$69a8(a5)
  001714:  1b 7c 00 01 96 2c      move.b #$1, -$69d4(a5)
  00171a:  60 26                  bra.b $1742
  00171c:  4e ba 15 28            jsr $2c46(pc)
  001720:  0c 6d 00 07 96 48      cmpi.w #$7, -$69b8(a5)
  001726:  66 10                  bne.b $1738
  001728:  48 6d 96 96            pea.l -$696a(a5)
  00172c:  4e ad 05 42            jsr $542(a5)
  001730:  3b 7c 00 02 ba 86      move.w #$2, -$457a(a5)
  001736:  58 8f                  addq.l #$4, a7
  001738:  1b 7c 00 01 96 58      move.b #$1, -$69a8(a5)
  00173e:  42 2d 96 2c            clr.b -$69d4(a5)
  001742:  4e ba 01 64            jsr $18a8(pc)
  001746:  4e 75                  rts 
  001748:  4a 2d 96 58            tst.b -$69a8(a5)
  00174c:  67 12                  beq.b $1760
  00174e:  4e ba 15 24            jsr $2c74(pc)
  001752:  42 2d 96 58            clr.b -$69a8(a5)
  001756:  1b 7c 00 01 96 2c      move.b #$1, -$69d4(a5)
  00175c:  4e ba 01 4a            jsr $18a8(pc)
  001760:  4e 75                  rts 
  001762:  4a 2d 96 59            tst.b -$69a7(a5)
  001766:  66 42                  bne.b $17aa
  001768:  4a 2d 96 5a            tst.b -$69a6(a5)
  00176c:  67 14                  beq.b $1782
  00176e:  4a 2d 96 3c            tst.b -$69c4(a5)
  001772:  67 08                  beq.b $177c
  001774:  4e ba 13 aa            jsr $2b20(pc)
  001778:  4e ba 15 82            jsr $2cfc(pc)
  00177c:  42 2d 96 5a            clr.b -$69a6(a5)
  001780:  60 10                  bra.b $1792
  001782:  4a 2d 96 3c            tst.b -$69c4(a5)
  001786:  67 04                  beq.b $178c
  001788:  4e ba 15 14            jsr $2c9e(pc)
  00178c:  1b 7c 00 01 96 5a      move.b #$1, -$69a6(a5)
  001792:  4e ba 01 14            jsr $18a8(pc)
  001796:  4a ad a5 50            tst.l -$5ab0(a5)
  00179a:  67 0e                  beq.b $17aa
  00179c:  20 6d a5 50            movea.l -$5ab0(a5), a0
  0017a0:  20 50                  movea.l (a0), a0
  0017a2:  10 ad 96 5a            move.b -$69a6(a5), (a0)
  0017a6:  4e ba 00 9a            jsr $1842(pc)
  0017aa:  4e 75                  rts 
  0017ac:  4a 2d 96 5b            tst.b -$69a5(a5)
  0017b0:  66 44                  bne.b $17f6
  0017b2:  4a 2d 96 5c            tst.b -$69a4(a5)
  0017b6:  67 14                  beq.b $17cc
  0017b8:  4a 2d 96 3c            tst.b -$69c4(a5)
  0017bc:  67 08                  beq.b $17c6
  0017be:  4e ba 13 60            jsr $2b20(pc)
  0017c2:  4e ba 16 9a            jsr $2e5e(pc)
  0017c6:  42 2d 96 5c            clr.b -$69a4(a5)
  0017ca:  60 10                  bra.b $17dc
  0017cc:  4a 2d 96 3c            tst.b -$69c4(a5)
  0017d0:  67 04                  beq.b $17d6
  0017d2:  4e ba 15 c4            jsr $2d98(pc)
  0017d6:  1b 7c 00 01 96 5c      move.b #$1, -$69a4(a5)
  0017dc:  4e ba 00 ca            jsr $18a8(pc)
  0017e0:  4a ad a5 50            tst.l -$5ab0(a5)
  0017e4:  67 10                  beq.b $17f6
  0017e6:  20 6d a5 50            movea.l -$5ab0(a5), a0
  0017ea:  20 50                  movea.l (a0), a0
  0017ec:  11 6d 96 5c 00 01      move.b -$69a4(a5), $1(a0)
  0017f2:  4e ba 00 4e            jsr $1842(pc)
  0017f6:  4e 75                  rts 
  0017f8:  4a 2d 96 2d            tst.b -$69d3(a5)
  0017fc:  67 12                  beq.b $1810
  0017fe:  4a 2d 96 2e            tst.b -$69d2(a5)
  001802:  67 0c                  beq.b $1810
  001804:  4e ad 05 3a            jsr $53a(a5)
  001808:  42 6d ba 42            clr.w -$45be(a5)
  00180c:  4e ba ff 3a            jsr $1748(pc)
  001810:  4e 75                  rts 
  001812:  4a 2d 96 2d            tst.b -$69d3(a5)
  001816:  67 10                  beq.b $1828
  001818:  4a 2d 96 2e            tst.b -$69d2(a5)
  00181c:  67 0a                  beq.b $1828
  00181e:  3b 7c 00 01 ba 42      move.w #$1, -$45be(a5)
  001824:  4e ba ff 22            jsr $1748(pc)
  001828:  4e 75                  rts 
  00182a:  4a 2d 96 2d            tst.b -$69d3(a5)
  00182e:  67 10                  beq.b $1840
  001830:  4a 2d 96 2e            tst.b -$69d2(a5)
  001834:  67 0a                  beq.b $1840
  001836:  3b 7c 00 05 96 48      move.w #$5, -$69b8(a5)
  00183c:  4e ba ff 0a            jsr $1748(pc)
  001840:  4e 75                  rts 
  001842:  4a ad a5 50            tst.l -$5ab0(a5)
  001846:  67 1a                  beq.b $1862
  001848:  2f 2d a5 50            move.l -$5ab0(a5), -(a7)
  00184c:  a9 aa                  dc.w $a9aa
  00184e:  42 67                  clr.w -(a7)
  001850:  a9 af                  dc.w $a9af
  001852:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  001856:  4a 6d a1 6c            tst.w -$5e94(a5)
  00185a:  66 06                  bne.b $1862
  00185c:  2f 2d a5 50            move.l -$5ab0(a5), -(a7)
  001860:  a9 b0                  dc.w $a9b0
  001862:  4e 75                  rts 
  001864:  4e 56 ff fe            link.w a6, #$fffe
  001868:  2f 0c                  move.l a4, -(a7)
  00186a:  4e ba 0e 28            jsr $2694(pc)
  00186e:  48 6d 97 42            pea.l -$68be(a5)
  001872:  48 6d 97 3e            pea.l -$68c2(a5)
  001876:  48 6d 97 3a            pea.l -$68c6(a5)
  00187a:  42 a7                  clr.l -(a7)
  00187c:  a9 8b                  dc.w $a98b
  00187e:  42 a7                  clr.l -(a7)
  001880:  3f 3c 03 e9            move.w #$3e9, -(a7)
  001884:  42 a7                  clr.l -(a7)
  001886:  48 78 ff ff            pea.l $ffff.w
  00188a:  a9 7c                  dc.w $a97c
  00188c:  28 5f                  movea.l (a7)+, a4
  00188e:  20 0c                  move.l a4, d0
  001890:  67 0c                  beq.b $189e
  001892:  42 a7                  clr.l -(a7)
  001894:  48 6e ff fe            pea.l -$2(a6)
  001898:  a9 91                  dc.w $a991
  00189a:  2f 0c                  move.l a4, -(a7)
  00189c:  a9 83                  dc.w $a983
  00189e:  4e ba 0d fe            jsr $269e(pc)
  0018a2:  28 5f                  movea.l (a7)+, a4
  0018a4:  4e 5e                  unlk a6
  0018a6:  4e 75                  rts 
  0018a8:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0018ac:  3f 3c 00 01            move.w #$1, -(a7)
  0018b0:  a9 3a                  dc.w $a93a
  0018b2:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0018b6:  3f 3c 00 02            move.w #$2, -(a7)
  0018ba:  a9 3a                  dc.w $a93a
  0018bc:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0018c0:  3f 3c 00 04            move.w #$4, -(a7)
  0018c4:  a9 3a                  dc.w $a93a
  0018c6:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0018ca:  3f 3c 00 05            move.w #$5, -(a7)
  0018ce:  a9 3a                  dc.w $a93a
  0018d0:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0018d4:  3f 3c 00 06            move.w #$6, -(a7)
  0018d8:  a9 3a                  dc.w $a93a
  0018da:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0018de:  42 67                  clr.w -(a7)
  0018e0:  a9 3a                  dc.w $a93a
  0018e2:  4a 2d 96 59            tst.b -$69a7(a5)
  0018e6:  67 0a                  beq.b $18f2
  0018e8:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0018ec:  3f 3c 00 02            move.w #$2, -(a7)
  0018f0:  a9 3a                  dc.w $a93a
  0018f2:  4a 2d 96 5b            tst.b -$69a5(a5)
  0018f6:  67 0a                  beq.b $1902
  0018f8:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0018fc:  3f 3c 00 03            move.w #$3, -(a7)
  001900:  a9 3a                  dc.w $a93a
  001902:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001906:  3f 3c 00 05            move.w #$5, -(a7)
  00190a:  a9 3a                  dc.w $a93a
  00190c:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001910:  3f 3c 00 06            move.w #$6, -(a7)
  001914:  a9 3a                  dc.w $a93a
  001916:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00191a:  3f 3c 00 07            move.w #$7, -(a7)
  00191e:  a9 3a                  dc.w $a93a
  001920:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  001926:  67 00 00 96            beq.w $19be
  00192a:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  00192e:  3f 3c 00 01            move.w #$1, -(a7)
  001932:  a9 39                  dc.w $a939
  001934:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  001938:  3f 3c 00 04            move.w #$4, -(a7)
  00193c:  a9 39                  dc.w $a939
  00193e:  4a 2d 96 2d            tst.b -$69d3(a5)
  001942:  67 24                  beq.b $1968
  001944:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  001948:  3f 3c 00 02            move.w #$2, -(a7)
  00194c:  a9 39                  dc.w $a939
  00194e:  4a 2d 96 2e            tst.b -$69d2(a5)
  001952:  67 14                  beq.b $1968
  001954:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  001958:  3f 3c 00 05            move.w #$5, -(a7)
  00195c:  a9 39                  dc.w $a939
  00195e:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  001962:  3f 3c 00 06            move.w #$6, -(a7)
  001966:  a9 39                  dc.w $a939
  001968:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00196c:  42 67                  clr.w -(a7)
  00196e:  a9 39                  dc.w $a939
  001970:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001974:  3f 3c 00 01            move.w #$1, -(a7)
  001978:  1f 2d 96 58            move.b -$69a8(a5), -(a7)
  00197c:  a9 45                  dc.w $a945
  00197e:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001982:  3f 3c 00 02            move.w #$2, -(a7)
  001986:  1f 2d 96 5a            move.b -$69a6(a5), -(a7)
  00198a:  a9 45                  dc.w $a945
  00198c:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001990:  3f 3c 00 03            move.w #$3, -(a7)
  001994:  1f 2d 96 5c            move.b -$69a4(a5), -(a7)
  001998:  a9 45                  dc.w $a945
  00199a:  4a 2d 96 2d            tst.b -$69d3(a5)
  00199e:  67 1e                  beq.b $19be
  0019a0:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0019a4:  3f 3c 00 05            move.w #$5, -(a7)
  0019a8:  a9 39                  dc.w $a939
  0019aa:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0019ae:  3f 3c 00 06            move.w #$6, -(a7)
  0019b2:  a9 39                  dc.w $a939
  0019b4:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0019b8:  3f 3c 00 07            move.w #$7, -(a7)
  0019bc:  a9 39                  dc.w $a939
  0019be:  a9 37                  dc.w $a937
  0019c0:  4e 75                  rts 
  0019c2:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  0019c6:  42 a7                  clr.l -(a7)
  0019c8:  aa 32                  dc.w $aa32
  0019ca:  28 5f                  movea.l (a7)+, a4
  0019cc:  2f 2d a1 bc            move.l -$5e44(a5), -(a7)
  0019d0:  aa 31                  dc.w $aa31
  0019d2:  7e 00                  moveq #$0, d7
  0019d4:  97 cb                  suba.l a3, a3
  0019d6:  60 22                  bra.b $19fa
  0019d8:  20 6d a2 f4            movea.l -$5d0c(a5), a0
  0019dc:  20 10                  move.l (a0), d0
  0019de:  3c 33 08 08            move.w $8(a3, d0.l), d6
  0019e2:  3f 06                  move.w d6, -(a7)
  0019e4:  aa 97                  dc.w $aa97
  0019e6:  20 6d a2 12            movea.l -$5dee(a5), a0
  0019ea:  2c 28 00 50            move.l $50(a0), d6
  0019ee:  22 4d                  movea.l a5, a1
  0019f0:  d2 c7                  adda.w d7, a1
  0019f2:  13 46 a2 fa            move.b d6, -$5d06(a1)
  0019f6:  52 47                  addq.w #$1, d7
  0019f8:  50 8b                  addq.l #$8, a3
  0019fa:  be 6d a2 f8            cmp.w -$5d08(a5), d7
  0019fe:  6d d8                  blt.b $19d8
  001a00:  3f 3c 00 01            move.w #$1, -(a7)
  001a04:  aa 97                  dc.w $aa97
  001a06:  20 6d a1 c4            movea.l -$5e3c(a5), a0
  001a0a:  20 50                  movea.l (a0), a0
  001a0c:  2b 50 a1 c8            move.l (a0), -$5e38(a5)
  001a10:  2f 0c                  move.l a4, -(a7)
  001a12:  aa 31                  dc.w $aa31
  001a14:  1b 6d a3 54 a3 d0      move.b -$5cac(a5), -$5c30(a5)
  001a1a:  1b 6d a3 55 a3 d1      move.b -$5cab(a5), -$5c2f(a5)
  001a20:  1b 6d a3 56 a3 d2      move.b -$5caa(a5), -$5c2e(a5)
  001a26:  1b 6d a3 57 a3 d3      move.b -$5ca9(a5), -$5c2d(a5)
  001a2c:  1b 6d a3 58 a3 d4      move.b -$5ca8(a5), -$5c2c(a5)
  001a32:  1b 6d a3 59 a3 d5      move.b -$5ca7(a5), -$5c2b(a5)
  001a38:  1b 6d a3 5a a3 d6      move.b -$5ca6(a5), -$5c2a(a5)
  001a3e:  1b 6d a3 5b a3 d7      move.b -$5ca5(a5), -$5c29(a5)
  001a44:  1b 6d a3 5c a3 d8      move.b -$5ca4(a5), -$5c28(a5)
  001a4a:  1b 6d a3 5d a3 d9      move.b -$5ca3(a5), -$5c27(a5)
  001a50:  1b 6d a3 5e a3 da      move.b -$5ca2(a5), -$5c26(a5)
  001a56:  1b 6d a3 5f a3 db      move.b -$5ca1(a5), -$5c25(a5)
  001a5c:  1b 6d a3 60 a3 dc      move.b -$5ca0(a5), -$5c24(a5)
  001a62:  1b 6d a2 ff a3 c3      move.b -$5d01(a5), -$5c3d(a5)
  001a68:  1b 6d a3 00 a3 c4      move.b -$5d00(a5), -$5c3c(a5)
  001a6e:  1b 6d a3 01 a3 c5      move.b -$5cff(a5), -$5c3b(a5)
  001a74:  1b 6d a3 11 a3 c6      move.b -$5cef(a5), -$5c3a(a5)
  001a7a:  1b 6d a3 12 a3 c7      move.b -$5cee(a5), -$5c39(a5)
  001a80:  1b 6d a3 13 a3 c8      move.b -$5ced(a5), -$5c38(a5)
  001a86:  1b 6d a3 0a a3 c9      move.b -$5cf6(a5), -$5c37(a5)
  001a8c:  1b 6d a3 0b a3 ca      move.b -$5cf5(a5), -$5c36(a5)
  001a92:  1b 6d a2 fd a3 cb      move.b -$5d03(a5), -$5c35(a5)
  001a98:  1b 6d a2 fe a3 cc      move.b -$5d02(a5), -$5c34(a5)
  001a9e:  1b 6d a2 ff a3 cd      move.b -$5d01(a5), -$5c33(a5)
  001aa4:  1b 6d a3 0c a3 ce      move.b -$5cf4(a5), -$5c32(a5)
  001aaa:  1b 6d a3 0d a3 cf      move.b -$5cf3(a5), -$5c31(a5)
  001ab0:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  001ab4:  4e 75                  rts 
  001ab6:  2f 07                  move.l d7, -(a7)
  001ab8:  7e 00                  moveq #$0, d7
  001aba:  60 0e                  bra.b $1aca
  001abc:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  001ac0:  3f 07                  move.w d7, -(a7)
  001ac2:  48 78 00 04            pea.l $4.w
  001ac6:  aa 9e                  dc.w $aa9e
  001ac8:  52 47                  addq.w #$1, d7
  001aca:  be 6d a2 36            cmp.w -$5dca(a5), d7
  001ace:  6d ec                  blt.b $1abc
  001ad0:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  001ad4:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  001ada:  42 67                  clr.w -(a7)
  001adc:  aa 9e                  dc.w $aa9e
  001ade:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  001ae2:  2f 3c 00 02 00 01      move.l #$20001, -(a7)
  001ae8:  42 67                  clr.w -(a7)
  001aea:  aa 9e                  dc.w $aa9e
  001aec:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  001af0:  aa 94                  dc.w $aa94
  001af2:  20 6d a1 bc            movea.l -$5e44(a5), a0
  001af6:  20 50                  movea.l (a0), a0
  001af8:  20 68 00 16            movea.l $16(a0), a0
  001afc:  20 50                  movea.l (a0), a0
  001afe:  22 6d a2 ca            movea.l -$5d36(a5), a1
  001b02:  22 51                  movea.l (a1), a1
  001b04:  23 68 00 2a 00 2a      move.l $2a(a0), $2a(a1)
  001b0a:  20 6d a1 bc            movea.l -$5e44(a5), a0
  001b0e:  20 50                  movea.l (a0), a0
  001b10:  20 68 00 16            movea.l $16(a0), a0
  001b14:  20 50                  movea.l (a0), a0
  001b16:  22 6d a2 ca            movea.l -$5d36(a5), a1
  001b1a:  22 51                  movea.l (a1), a1
  001b1c:  33 68 00 0e 00 0e      move.w $e(a0), $e(a1)
  001b22:  2e 1f                  move.l (a7)+, d7
  001b24:  4e 75                  rts 
  001b26:  2f 07                  move.l d7, -(a7)
  001b28:  7e 00                  moveq #$0, d7
  001b2a:  60 0c                  bra.b $1b38
  001b2c:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  001b30:  3f 07                  move.w d7, -(a7)
  001b32:  42 a7                  clr.l -(a7)
  001b34:  aa 9e                  dc.w $aa9e
  001b36:  52 47                  addq.w #$1, d7
  001b38:  be 6d a2 36            cmp.w -$5dca(a5), d7
  001b3c:  6d ee                  blt.b $1b2c
  001b3e:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  001b42:  aa 94                  dc.w $aa94
  001b44:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001b48:  20 50                  movea.l (a0), a0
  001b4a:  21 6d a2 f4 00 2a      move.l -$5d0c(a5), $2a(a0)
  001b50:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001b54:  20 50                  movea.l (a0), a0
  001b56:  42 68 00 0e            clr.w $e(a0)
  001b5a:  2e 1f                  move.l (a7)+, d7
  001b5c:  4e 75                  rts 
  001b5e:  30 2d a5 5c            move.w -$5aa4(a5), d0
  001b62:  0c 40 00 0a            cmpi.w #$a, d0
  001b66:  62 00 00 aa            bhi.w $1c12
  001b6a:  43 fa 00 a8            lea.l $1c14(pc), a1
  001b6e:  d0 40                  add.w d0, d0
  001b70:  d2 f1 00 00            adda.w (a1, d0.w), a1
  001b74:  4e d1                  jmp (a1)
  001b76:  4a 6d ba 1a            tst.w -$45e6(a5)
  001b7a:  67 00 00 96            beq.w $1c12
  001b7e:  3f 3c 00 01            move.w #$1, -(a7)
  001b82:  3f 2d ba 18            move.w -$45e8(a5), -(a7)
  001b86:  3f 3c 00 02            move.w #$2, -(a7)
  001b8a:  4e ba 08 e2            jsr $246e(pc)
  001b8e:  3b 7c 00 01 96 4a      move.w #$1, -$69b6(a5)
  001b94:  5c 8f                  addq.l #$6, a7
  001b96:  60 7a                  bra.b $1c12
  001b98:  2f 3c 00 20 ff f8      move.l #$20fff8, -(a7)
  001b9e:  4e ba 08 24            jsr $23c4(pc)
  001ba2:  58 8f                  addq.l #$4, a7
  001ba4:  60 6c                  bra.b $1c12
  001ba6:  2f 3c 00 08 ff e0      move.l #$8ffe0, -(a7)
  001bac:  4e ba 08 16            jsr $23c4(pc)
  001bb0:  58 8f                  addq.l #$4, a7
  001bb2:  60 5e                  bra.b $1c12
  001bb4:  2f 3c 00 05 ff e0      move.l #$5ffe0, -(a7)
  001bba:  4e ba 08 08            jsr $23c4(pc)
  001bbe:  58 8f                  addq.l #$4, a7
  001bc0:  60 50                  bra.b $1c12
  001bc2:  2f 3c 00 08 ff e0      move.l #$8ffe0, -(a7)
  001bc8:  4e ba 07 fa            jsr $23c4(pc)
  001bcc:  58 8f                  addq.l #$4, a7
  001bce:  60 42                  bra.b $1c12
  001bd0:  2f 3c 00 01 ff 00      move.l #$1ff00, -(a7)
  001bd6:  4e ba 07 ec            jsr $23c4(pc)
  001bda:  58 8f                  addq.l #$4, a7
  001bdc:  60 34                  bra.b $1c12
  001bde:  2f 3c 00 08 00 00      move.l #$80000, -(a7)
  001be4:  4e ba 06 ee            jsr $22d4(pc)
  001be8:  58 8f                  addq.l #$4, a7
  001bea:  60 26                  bra.b $1c12
  001bec:  2f 3c ff f8 00 00      move.l #$fff80000, -(a7)
  001bf2:  4e ba 06 e0            jsr $22d4(pc)
  001bf6:  58 8f                  addq.l #$4, a7
  001bf8:  60 18                  bra.b $1c12
  001bfa:  48 78 00 04            pea.l $4.w
  001bfe:  4e ba 06 d4            jsr $22d4(pc)
  001c02:  58 8f                  addq.l #$4, a7
  001c04:  60 0c                  bra.b $1c12
  001c06:  2f 3c 00 00 ff fc      move.l #$fffc, -(a7)
  001c0c:  4e ba 06 c6            jsr $22d4(pc)
  001c10:  58 8f                  addq.l #$4, a7
  001c12:  4e 75                  rts 
  001c14:  ff 62                  dc.w $ff62
  001c16:  ff fe                  dc.w $fffe
  001c18:  ff 84                  dc.w $ff84
  001c1a:  ff 92                  dc.w $ff92
  001c1c:  ff a0                  dc.w $ffa0
  001c1e:  ff ae                  dc.w $ffae
  001c20:  ff bc                  dc.w $ffbc
  001c22:  ff ca                  dc.w $ffca
  001c24:  ff d8                  dc.w $ffd8
  001c26:  ff e6                  dc.w $ffe6
  001c28:  ff f2                  dc.w $fff2
  001c2a:  2f 07                  move.l d7, -(a7)
  001c2c:  4a 2d a2 09            tst.b -$5df7(a5)
  001c30:  67 1c                  beq.b $1c4e
  001c32:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001c36:  2f 10                  move.l (a0), -(a7)
  001c38:  22 6d a2 16            movea.l -$5dea(a5), a1
  001c3c:  2f 11                  move.l (a1), -(a7)
  001c3e:  48 6d a2 dc            pea.l -$5d24(a5)
  001c42:  48 6d a5 c4            pea.l -$5a3c(a5)
  001c46:  42 67                  clr.w -(a7)
  001c48:  42 a7                  clr.l -(a7)
  001c4a:  a8 ec                  dc.w $a8ec
  001c4c:  60 22                  bra.b $1c70
  001c4e:  4a 6d 96 4a            tst.w -$69b6(a5)
  001c52:  66 04                  bne.b $1c58
  001c54:  7e 00                  moveq #$0, d7
  001c56:  60 02                  bra.b $1c5a
  001c58:  7e 04                  moveq #$4, d7
  001c5a:  2f 2d a2 ce            move.l -$5d32(a5), -(a7)
  001c5e:  2f 2d a2 1a            move.l -$5de6(a5), -(a7)
  001c62:  48 6d a2 dc            pea.l -$5d24(a5)
  001c66:  48 6d a5 c4            pea.l -$5a3c(a5)
  001c6a:  3f 07                  move.w d7, -(a7)
  001c6c:  42 a7                  clr.l -(a7)
  001c6e:  a8 ec                  dc.w $a8ec
  001c70:  2e 1f                  move.l (a7)+, d7
  001c72:  4e 75                  rts 
  001c74:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  001c78:  4a 2d a2 09            tst.b -$5df7(a5)
  001c7c:  67 2a                  beq.b $1ca8
  001c7e:  7e 00                  moveq #$0, d7
  001c80:  49 ed f2 2c            lea.l -$dd4(a5), a4
  001c84:  60 1a                  bra.b $1ca0
  001c86:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001c8a:  2f 10                  move.l (a0), -(a7)
  001c8c:  22 6d a2 16            movea.l -$5dea(a5), a1
  001c90:  2f 11                  move.l (a1), -(a7)
  001c92:  2f 0c                  move.l a4, -(a7)
  001c94:  2f 0c                  move.l a4, -(a7)
  001c96:  42 67                  clr.w -(a7)
  001c98:  42 a7                  clr.l -(a7)
  001c9a:  a8 ec                  dc.w $a8ec
  001c9c:  52 47                  addq.w #$1, d7
  001c9e:  50 8c                  addq.l #$8, a4
  001ca0:  be 6d f2 2a            cmp.w -$dd6(a5), d7
  001ca4:  6d e0                  blt.b $1c86
  001ca6:  60 30                  bra.b $1cd8
  001ca8:  4a 6d 96 4a            tst.w -$69b6(a5)
  001cac:  66 04                  bne.b $1cb2
  001cae:  7c 00                  moveq #$0, d6
  001cb0:  60 02                  bra.b $1cb4
  001cb2:  7c 04                  moveq #$4, d6
  001cb4:  7e 00                  moveq #$0, d7
  001cb6:  49 ed f2 2c            lea.l -$dd4(a5), a4
  001cba:  60 16                  bra.b $1cd2
  001cbc:  2f 2d a2 ce            move.l -$5d32(a5), -(a7)
  001cc0:  2f 2d a2 1a            move.l -$5de6(a5), -(a7)
  001cc4:  2f 0c                  move.l a4, -(a7)
  001cc6:  2f 0c                  move.l a4, -(a7)
  001cc8:  3f 06                  move.w d6, -(a7)
  001cca:  42 a7                  clr.l -(a7)
  001ccc:  a8 ec                  dc.w $a8ec
  001cce:  52 47                  addq.w #$1, d7
  001cd0:  50 8c                  addq.l #$8, a4
  001cd2:  be 6d f2 2a            cmp.w -$dd6(a5), d7
  001cd6:  6d e4                  blt.b $1cbc
  001cd8:  42 6d f2 2a            clr.w -$dd6(a5)
  001cdc:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  001ce0:  4e 75                  rts 
  001ce2:  30 2d a5 5c            move.w -$5aa4(a5), d0
  001ce6:  0c 40 00 06            cmpi.w #$6, d0
  001cea:  62 00 00 80            bhi.w $1d6c
  001cee:  43 fa 00 82            lea.l $1d72(pc), a1
  001cf2:  d0 40                  add.w d0, d0
  001cf4:  d2 f1 00 00            adda.w (a1, d0.w), a1
  001cf8:  4e d1                  jmp (a1)
  001cfa:  4a 6d ba 1a            tst.w -$45e6(a5)
  001cfe:  67 6c                  beq.b $1d6c
  001d00:  53 6d ba 1a            subq.w #$1, -$45e6(a5)
  001d04:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  001d0a:  3f 3c 00 02            move.w #$2, -(a7)
  001d0e:  4e ba 07 5e            jsr $246e(pc)
  001d12:  42 6d 96 4a            clr.w -$69b6(a5)
  001d16:  5c 8f                  addq.l #$6, a7
  001d18:  60 52                  bra.b $1d6c
  001d1a:  2f 3c 00 01 01 00      move.l #$10100, -(a7)
  001d20:  4e ba 06 a2            jsr $23c4(pc)
  001d24:  58 8f                  addq.l #$4, a7
  001d26:  60 44                  bra.b $1d6c
  001d28:  2f 3c 00 20 00 08      move.l #$200008, -(a7)
  001d2e:  4e ba 06 94            jsr $23c4(pc)
  001d32:  58 8f                  addq.l #$4, a7
  001d34:  60 36                  bra.b $1d6c
  001d36:  2f 3c 00 08 00 20      move.l #$80020, -(a7)
  001d3c:  4e ba 06 86            jsr $23c4(pc)
  001d40:  58 8f                  addq.l #$4, a7
  001d42:  60 28                  bra.b $1d6c
  001d44:  2f 3c 00 05 00 20      move.l #$50020, -(a7)
  001d4a:  4e ba 06 78            jsr $23c4(pc)
  001d4e:  58 8f                  addq.l #$4, a7
  001d50:  60 1a                  bra.b $1d6c
  001d52:  2f 3c 00 01 01 00      move.l #$10100, -(a7)
  001d58:  4e ba 06 6a            jsr $23c4(pc)
  001d5c:  58 8f                  addq.l #$4, a7
  001d5e:  60 0c                  bra.b $1d6c
  001d60:  2f 3c 00 08 00 20      move.l #$80020, -(a7)
  001d66:  4e ba 06 5c            jsr $23c4(pc)
  001d6a:  58 8f                  addq.l #$4, a7
  001d6c:  42 6d a5 5c            clr.w -$5aa4(a5)
  001d70:  4e 75                  rts 
  001d72:  ff 88                  dc.w $ff88
  001d74:  ff a8                  dc.w $ffa8
  001d76:  ff b6                  dc.w $ffb6
  001d78:  ff c4                  dc.w $ffc4
  001d7a:  ff d2                  dc.w $ffd2
  001d7c:  ff e0                  dc.w $ffe0
  001d7e:  ff ee                  dc.w $ffee
  001d80:  2f 07                  move.l d7, -(a7)
  001d82:  1b 7c 00 01 96 2c      move.b #$1, -$69d4(a5)
  001d88:  42 2d 96 2d            clr.b -$69d3(a5)
  001d8c:  42 2d 96 2e            clr.b -$69d2(a5)
  001d90:  42 6d a5 ba            clr.w -$5a46(a5)
  001d94:  3b 7c 00 01 a5 bc      move.w #$1, -$5a44(a5)
  001d9a:  42 2d 96 58            clr.b -$69a8(a5)
  001d9e:  42 a7                  clr.l -(a7)
  001da0:  a9 75                  dc.w $a975   ; _TickCount
  001da2:  2e 1f                  move.l (a7)+, d7
  001da4:  02 47 0f ff            andi.w #$fff, d7
  001da8:  06 47 00 c8            addi.w #$c8, d7
  001dac:  60 0a                  bra.b $1db8
  001dae:  3f 3c 00 01            move.w #$1, -(a7)
  001db2:  4e ba 04 8a            jsr $223e(pc)
  001db6:  54 8f                  addq.l #$2, a7
  001db8:  30 07                  move.w d7, d0
  001dba:  53 47                  subq.w #$1, d7
  001dbc:  4a 40                  tst.w d0
  001dbe:  66 ee                  bne.b $1dae
  001dc0:  4e ad 03 b2            jsr $3b2(a5)
  001dc4:  4e ad 03 ba            jsr $3ba(a5)
  001dc8:  4a 6d a1 22            tst.w -$5ede(a5)
  001dcc:  67 22                  beq.b $1df0
  001dce:  4e ba f7 26            jsr $14f6(pc)
  001dd2:  4a 00                  tst.b d0
  001dd4:  67 26                  beq.b $1dfc
  001dd6:  3b 6d ba 64 ba 62      move.w -$459c(a5), -$459e(a5)
  001ddc:  3b 7c 00 01 b9 3e      move.w #$1, -$46c2(a5)
  001de2:  1b 7c 00 01 96 1f      move.b #$1, -$69e1(a5)
  001de8:  3b 7c 00 04 96 48      move.w #$4, -$69b8(a5)
  001dee:  60 0c                  bra.b $1dfc
  001df0:  3b 7c 00 02 ba 62      move.w #$2, -$459e(a5)
  001df6:  3b 7c 00 01 96 48      move.w #$1, -$69b8(a5)
  001dfc:  2e 1f                  move.l (a7)+, d7
  001dfe:  4e 75                  rts 
  001e00:  42 2d 96 1f            clr.b -$69e1(a5)
  001e04:  42 2d 96 2d            clr.b -$69d3(a5)
  001e08:  42 2d 96 2e            clr.b -$69d2(a5)
  001e0c:  4e ba fa 9a            jsr $18a8(pc)
  001e10:  42 6d ba 64            clr.w -$459c(a5)
  001e14:  42 6d 96 32            clr.w -$69ce(a5)
  001e18:  42 6d b9 3e            clr.w -$46c2(a5)
  001e1c:  42 6d a5 66            clr.w -$5a9a(a5)
  001e20:  42 6d a5 68            clr.w -$5a98(a5)
  001e24:  42 2d a5 6a            clr.b -$5a96(a5)
  001e28:  42 ad a5 6c            clr.l -$5a94(a5)
  001e2c:  3b 7c 00 02 96 48      move.w #$2, -$69b8(a5)
  001e32:  4e 75                  rts 
  001e34:  4a 6d a5 68            tst.w -$5a98(a5)
  001e38:  66 3c                  bne.b $1e76
  001e3a:  4a 2d a5 6a            tst.b -$5a96(a5)
  001e3e:  67 0c                  beq.b $1e4c
  001e40:  4e ba 0d 0e            jsr $2b50(pc)
  001e44:  4a 00                  tst.b d0
  001e46:  66 04                  bne.b $1e4c
  001e48:  42 2d a5 6a            clr.b -$5a96(a5)
  001e4c:  4a ad a5 6c            tst.l -$5a94(a5)
  001e50:  6f 12                  ble.b $1e64
  001e52:  2f 2d a5 6c            move.l -$5a94(a5), -(a7)
  001e56:  4e ba 0d 76            jsr $2bce(pc)
  001e5a:  4a 00                  tst.b d0
  001e5c:  58 8f                  addq.l #$4, a7
  001e5e:  67 04                  beq.b $1e64
  001e60:  42 ad a5 6c            clr.l -$5a94(a5)
  001e64:  4a 2d a5 6a            tst.b -$5a96(a5)
  001e68:  66 10                  bne.b $1e7a
  001e6a:  4a ad a5 6c            tst.l -$5a94(a5)
  001e6e:  66 0a                  bne.b $1e7a
  001e70:  4e ad 03 d2            jsr $3d2(a5)
  001e74:  60 04                  bra.b $1e7a
  001e76:  53 6d a5 68            subq.w #$1, -$5a98(a5)
  001e7a:  70 05                  moveq #$5, d0
  001e7c:  2b 40 96 4c            move.l d0, -$69b4(a5)
  001e80:  4a 6d a5 66            tst.w -$5a9a(a5)
  001e84:  66 10                  bne.b $1e96
  001e86:  3f 3c 00 05            move.w #$5, -(a7)
  001e8a:  4e ba 03 66            jsr $21f2(pc)
  001e8e:  3b 7c 00 04 96 48      move.w #$4, -$69b8(a5)
  001e94:  54 8f                  addq.l #$2, a7
  001e96:  4e 75                  rts 
  001e98:  4a 6d a5 72            tst.w -$5a8e(a5)
  001e9c:  66 3e                  bne.b $1edc
  001e9e:  4a 2d a5 6a            tst.b -$5a96(a5)
  001ea2:  67 0c                  beq.b $1eb0
  001ea4:  4e ba 0c aa            jsr $2b50(pc)
  001ea8:  4a 00                  tst.b d0
  001eaa:  66 04                  bne.b $1eb0
  001eac:  42 2d a5 6a            clr.b -$5a96(a5)
  001eb0:  4a ad a5 6c            tst.l -$5a94(a5)
  001eb4:  6f 12                  ble.b $1ec8
  001eb6:  2f 2d a5 6c            move.l -$5a94(a5), -(a7)
  001eba:  4e ba 0d 12            jsr $2bce(pc)
  001ebe:  4a 00                  tst.b d0
  001ec0:  58 8f                  addq.l #$4, a7
  001ec2:  67 04                  beq.b $1ec8
  001ec4:  42 ad a5 6c            clr.l -$5a94(a5)
  001ec8:  4a 2d a5 6a            tst.b -$5a96(a5)
  001ecc:  66 12                  bne.b $1ee0
  001ece:  4a ad a5 6c            tst.l -$5a94(a5)
  001ed2:  66 0c                  bne.b $1ee0
  001ed4:  20 6d a5 74            movea.l -$5a8c(a5), a0
  001ed8:  4e 90                  jsr (a0)
  001eda:  60 04                  bra.b $1ee0
  001edc:  53 6d a5 72            subq.w #$1, -$5a8e(a5)
  001ee0:  70 05                  moveq #$5, d0
  001ee2:  2b 40 96 4c            move.l d0, -$69b4(a5)
  001ee6:  4e ad 02 02            jsr $202(a5)
  001eea:  4a 2d 96 2d            tst.b -$69d3(a5)
  001eee:  67 0a                  beq.b $1efa
  001ef0:  4a 2d a5 be            tst.b -$5a42(a5)
  001ef4:  67 04                  beq.b $1efa
  001ef6:  42 6d a5 70            clr.w -$5a90(a5)
  001efa:  4a 6d a5 70            tst.w -$5a90(a5)
  001efe:  66 10                  bne.b $1f10
  001f00:  3f 3c 00 05            move.w #$5, -(a7)
  001f04:  4e ba 02 ec            jsr $21f2(pc)
  001f08:  3b 6d a5 78 96 48      move.w -$5a88(a5), -$69b8(a5)
  001f0e:  54 8f                  addq.l #$2, a7
  001f10:  4e 75                  rts 
  001f12:  3f 3c 00 07            move.w #$7, -(a7)
  001f16:  4e ba 02 da            jsr $21f2(pc)
  001f1a:  42 6d a5 66            clr.w -$5a9a(a5)
  001f1e:  42 6d a5 68            clr.w -$5a98(a5)
  001f22:  70 05                  moveq #$5, d0
  001f24:  2b 40 96 4c            move.l d0, -$69b4(a5)
  001f28:  3e ad ba 64            move.w -$459c(a5), (a7)
  001f2c:  4e ad 01 ca            jsr $1ca(a5)
  001f30:  4a 6d ba 64            tst.w -$459c(a5)
  001f34:  54 8f                  addq.l #$2, a7
  001f36:  6f 06                  ble.b $1f3e
  001f38:  1b 7c 00 01 96 2d      move.b #$1, -$69d3(a5)
  001f3e:  4e ba f9 68            jsr $18a8(pc)
  001f42:  42 6d 96 30            clr.w -$69d0(a5)
  001f46:  3b 7c 00 05 96 48      move.w #$5, -$69b8(a5)
  001f4c:  4e 75                  rts 
  001f4e:  42 2d 96 2e            clr.b -$69d2(a5)
  001f52:  3f 3c 00 0b            move.w #$b, -(a7)
  001f56:  4e ba 02 9a            jsr $21f2(pc)
  001f5a:  3e bc 00 0d            move.w #$d, (a7)
  001f5e:  4e ba 02 de            jsr $223e(pc)
  001f62:  3b 40 b9 42            move.w d0, -$46be(a5)
  001f66:  32 2d ba 64            move.w -$459c(a5), d1
  001f6a:  b2 6d ba 62            cmp.w -$459e(a5), d1
  001f6e:  54 8f                  addq.l #$2, a7
  001f70:  66 0a                  bne.b $1f7c
  001f72:  3b 7c 00 0f ba 64      move.w #$f, -$459c(a5)
  001f78:  4e ad 01 fa            jsr $1fa(a5)
  001f7c:  3f 2d ba 64            move.w -$459c(a5), -(a7)
  001f80:  4e ad 01 d2            jsr $1d2(a5)
  001f84:  4a 6d ba 64            tst.w -$459c(a5)
  001f88:  54 8f                  addq.l #$2, a7
  001f8a:  66 08                  bne.b $1f94
  001f8c:  3b 7c 00 06 96 48      move.w #$6, -$69b8(a5)
  001f92:  60 1c                  bra.b $1fb0
  001f94:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  001f9a:  67 0e                  beq.b $1faa
  001f9c:  1b 7c 00 01 96 2e      move.b #$1, -$69d2(a5)
  001fa2:  3b 7c 00 07 96 48      move.w #$7, -$69b8(a5)
  001fa8:  60 06                  bra.b $1fb0
  001faa:  3b 7c 00 08 96 48      move.w #$8, -$69b8(a5)
  001fb0:  4e ba f8 f6            jsr $18a8(pc)
  001fb4:  4e ba 0a 66            jsr $2a1c(pc)
  001fb8:  4e 75                  rts 
  001fba:  2f 07                  move.l d7, -(a7)
  001fbc:  4e ad 01 da            jsr $1da(a5)
  001fc0:  3e 00                  move.w d0, d7
  001fc2:  4a 47                  tst.w d7
  001fc4:  67 10                  beq.b $1fd6
  001fc6:  3f 3c 00 0f            move.w #$f, -(a7)
  001fca:  4e ba 02 26            jsr $21f2(pc)
  001fce:  3b 7c 00 0b 96 48      move.w #$b, -$69b8(a5)
  001fd4:  54 8f                  addq.l #$2, a7
  001fd6:  2e 1f                  move.l (a7)+, d7
  001fd8:  4e 75                  rts 
  001fda:  2f 07                  move.l d7, -(a7)
  001fdc:  4e ad 01 da            jsr $1da(a5)
  001fe0:  3e 00                  move.w d0, d7
  001fe2:  4a 47                  tst.w d7
  001fe4:  67 34                  beq.b $201a
  001fe6:  3f 3c 00 09            move.w #$9, -(a7)
  001fea:  4e ba 02 06            jsr $21f2(pc)
  001fee:  30 07                  move.w d7, d0
  001ff0:  54 8f                  addq.l #$2, a7
  001ff2:  67 26                  beq.b $201a
  001ff4:  6b 24                  bmi.b $201a
  001ff6:  57 40                  subq.w #$3, d0
  001ff8:  67 16                  beq.b $2010
  001ffa:  6a 1e                  bpl.b $201a
  001ffc:  52 40                  addq.w #$1, d0
  001ffe:  6a 08                  bpl.b $2008
  002000:  3b 7c 00 05 96 48      move.w #$5, -$69b8(a5)
  002006:  60 12                  bra.b $201a
  002008:  3b 7c 00 09 96 48      move.w #$9, -$69b8(a5)
  00200e:  60 0a                  bra.b $201a
  002010:  4e ba fd ee            jsr $1e00(pc)
  002014:  3b 7c 00 0a 96 48      move.w #$a, -$69b8(a5)
  00201a:  2e 1f                  move.l (a7)+, d7
  00201c:  4e 75                  rts 
  00201e:  2f 07                  move.l d7, -(a7)
  002020:  4e ad 01 da            jsr $1da(a5)
  002024:  3e 00                  move.w d0, d7
  002026:  4a 47                  tst.w d7
  002028:  67 24                  beq.b $204e
  00202a:  3f 3c 00 09            move.w #$9, -(a7)
  00202e:  4e ba 01 c2            jsr $21f2(pc)
  002032:  0c 47 00 02            cmpi.w #$2, d7
  002036:  54 8f                  addq.l #$2, a7
  002038:  66 08                  bne.b $2042
  00203a:  3b 7c 00 09 96 48      move.w #$9, -$69b8(a5)
  002040:  60 24                  bra.b $2066
  002042:  4e ba fd bc            jsr $1e00(pc)
  002046:  3b 7c 00 0a 96 48      move.w #$a, -$69b8(a5)
  00204c:  60 18                  bra.b $2066
  00204e:  0c 6d 00 01 ba 3a      cmpi.w #$1, -$45c6(a5)
  002054:  66 10                  bne.b $2066
  002056:  4e ba 0a f8            jsr $2b50(pc)
  00205a:  4a 00                  tst.b d0
  00205c:  66 08                  bne.b $2066
  00205e:  4e ba f8 04            jsr $1864(pc)
  002062:  52 6d ba 3a            addq.w #$1, -$45c6(a5)
  002066:  2e 1f                  move.l (a7)+, d7
  002068:  4e 75                  rts 
  00206a:  42 2d 96 2e            clr.b -$69d2(a5)
  00206e:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  002074:  67 04                  beq.b $207a
  002076:  42 2d 96 1f            clr.b -$69e1(a5)
  00207a:  3f 3c 00 05            move.w #$5, -(a7)
  00207e:  4e ba 01 72            jsr $21f2(pc)
  002082:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  002088:  54 8f                  addq.l #$2, a7
  00208a:  66 0c                  bne.b $2098
  00208c:  3b 6d ba 62 ba 38      move.w -$459e(a5), -$45c8(a5)
  002092:  3b 7c ff ff ba 62      move.w #$ffff, -$459e(a5)
  002098:  3b 6d ba 38 ba 64      move.w -$45c8(a5), -$459c(a5)
  00209e:  30 2d ba 38            move.w -$45c8(a5), d0
  0020a2:  b0 6d ba 62            cmp.w -$459e(a5), d0
  0020a6:  66 06                  bne.b $20ae
  0020a8:  3b 7c 00 0f ba 38      move.w #$f, -$45c8(a5)
  0020ae:  4e ba f7 f8            jsr $18a8(pc)
  0020b2:  3b 7c 00 05 96 48      move.w #$5, -$69b8(a5)
  0020b8:  30 2d ba 38            move.w -$45c8(a5), d0
  0020bc:  0c 40 00 0c            cmpi.w #$c, d0
  0020c0:  62 00 00 82            bhi.w $2144
  0020c4:  43 fa 00 80            lea.l $2146(pc), a1
  0020c8:  d0 40                  add.w d0, d0
  0020ca:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0020ce:  4e d1                  jmp (a1)
  0020d0:  48 6d 02 3a            pea.l $23a(a5)
  0020d4:  42 67                  clr.w -(a7)
  0020d6:  4e ad 02 5a            jsr $25a(a5)
  0020da:  5c 8f                  addq.l #$6, a7
  0020dc:  60 66                  bra.b $2144
  0020de:  48 6d 02 32            pea.l $232(a5)
  0020e2:  3f 3c 00 01            move.w #$1, -(a7)
  0020e6:  4e ad 02 5a            jsr $25a(a5)
  0020ea:  5c 8f                  addq.l #$6, a7
  0020ec:  60 56                  bra.b $2144
  0020ee:  48 6d 02 3a            pea.l $23a(a5)
  0020f2:  3f 3c 00 01            move.w #$1, -(a7)
  0020f6:  4e ad 02 5a            jsr $25a(a5)
  0020fa:  5c 8f                  addq.l #$6, a7
  0020fc:  60 46                  bra.b $2144
  0020fe:  48 6d 02 0a            pea.l $20a(a5)
  002102:  3f 3c 00 01            move.w #$1, -(a7)
  002106:  4e ad 02 5a            jsr $25a(a5)
  00210a:  5c 8f                  addq.l #$6, a7
  00210c:  60 36                  bra.b $2144
  00210e:  48 6d 02 12            pea.l $212(a5)
  002112:  3f 3c 00 01            move.w #$1, -(a7)
  002116:  4e ad 02 5a            jsr $25a(a5)
  00211a:  5c 8f                  addq.l #$6, a7
  00211c:  60 26                  bra.b $2144
  00211e:  0c 6d 00 05 ba 8c      cmpi.w #$5, -$4574(a5)
  002124:  6e 10                  bgt.b $2136
  002126:  48 6d 02 2a            pea.l $22a(a5)
  00212a:  3f 3c 00 01            move.w #$1, -(a7)
  00212e:  4e ad 02 5a            jsr $25a(a5)
  002132:  5c 8f                  addq.l #$6, a7
  002134:  60 0e                  bra.b $2144
  002136:  48 6d 02 3a            pea.l $23a(a5)
  00213a:  3f 3c 00 01            move.w #$1, -(a7)
  00213e:  4e ad 02 5a            jsr $25a(a5)
  002142:  5c 8f                  addq.l #$6, a7
  002144:  4e 75                  rts 
  002146:  ff fe                  dc.w $fffe
  002148:  ff fe                  dc.w $fffe
  00214a:  ff 8a                  dc.w $ff8a
  00214c:  ff fe                  dc.w $fffe
  00214e:  ff 98                  dc.w $ff98
  002150:  ff fe                  dc.w $fffe
  002152:  ff a8                  dc.w $ffa8
  002154:  ff fe                  dc.w $fffe
  002156:  ff b8                  dc.w $ffb8
  002158:  ff c8                  dc.w $ffc8
  00215a:  ff fe                  dc.w $fffe
  00215c:  ff fe                  dc.w $fffe
  00215e:  ff d8                  dc.w $ffd8
  002160:  42 2d 96 2e            clr.b -$69d2(a5)
  002164:  4a 6d a5 68            tst.w -$5a98(a5)
  002168:  66 50                  bne.b $21ba
  00216a:  4a 2d a5 6a            tst.b -$5a96(a5)
  00216e:  67 0c                  beq.b $217c
  002170:  4e ba 09 de            jsr $2b50(pc)
  002174:  4a 00                  tst.b d0
  002176:  66 04                  bne.b $217c
  002178:  42 2d a5 6a            clr.b -$5a96(a5)
  00217c:  4a ad a5 6c            tst.l -$5a94(a5)
  002180:  6f 12                  ble.b $2194
  002182:  2f 2d a5 6c            move.l -$5a94(a5), -(a7)
  002186:  4e ba 0a 46            jsr $2bce(pc)
  00218a:  4a 00                  tst.b d0
  00218c:  58 8f                  addq.l #$4, a7
  00218e:  67 04                  beq.b $2194
  002190:  42 ad a5 6c            clr.l -$5a94(a5)
  002194:  4a 2d a5 6a            tst.b -$5a96(a5)
  002198:  66 24                  bne.b $21be
  00219a:  4a ad a5 6c            tst.l -$5a94(a5)
  00219e:  66 1e                  bne.b $21be
  0021a0:  30 2d 96 30            move.w -$69d0(a5), d0
  0021a4:  67 18                  beq.b $21be
  0021a6:  6b 16                  bmi.b $21be
  0021a8:  55 40                  subq.w #$2, d0
  0021aa:  67 08                  beq.b $21b4
  0021ac:  6a 10                  bpl.b $21be
  0021ae:  4e ad 02 4a            jsr $24a(a5)
  0021b2:  60 0a                  bra.b $21be
  0021b4:  4e ad 02 52            jsr $252(a5)
  0021b8:  60 04                  bra.b $21be
  0021ba:  53 6d a5 68            subq.w #$1, -$5a98(a5)
  0021be:  70 05                  moveq #$5, d0
  0021c0:  2b 40 96 4c            move.l d0, -$69b4(a5)
  0021c4:  4a 6d a5 66            tst.w -$5a9a(a5)
  0021c8:  66 14                  bne.b $21de
  0021ca:  3f 3c 00 0f            move.w #$f, -(a7)
  0021ce:  4e ba 00 22            jsr $21f2(pc)
  0021d2:  4e ad 03 ba            jsr $3ba(a5)
  0021d6:  3b 7c 00 0b 96 48      move.w #$b, -$69b8(a5)
  0021dc:  54 8f                  addq.l #$2, a7
  0021de:  4e 75                  rts 
  0021e0:  3f 3c 00 07            move.w #$7, -(a7)
  0021e4:  4e ba 00 0c            jsr $21f2(pc)
  0021e8:  3b 7c 00 01 96 48      move.w #$1, -$69b8(a5)
  0021ee:  54 8f                  addq.l #$2, a7
  0021f0:  4e 75                  rts 
  0021f2:  4e 56 00 00            link.w a6, #$0
  0021f6:  2f 07                  move.l d7, -(a7)
  0021f8:  3e 2e 00 08            move.w $8(a6), d7
  0021fc:  08 07 00 03            btst.b #$3, d7
  002200:  67 04                  beq.b $2206
  002202:  4e ba 08 46            jsr $2a4a(pc)
  002206:  08 07 00 02            btst.b #$2, d7
  00220a:  67 04                  beq.b $2210
  00220c:  4e ad 03 da            jsr $3da(a5)
  002210:  08 07 00 01            btst.b #$1, d7
  002214:  67 06                  beq.b $221c
  002216:  48 6d a5 c4            pea.l -$5a3c(a5)
  00221a:  a8 a2                  dc.w $a8a2
  00221c:  08 07 00 00            btst.b #$0, d7
  002220:  67 16                  beq.b $2238
  002222:  1f 3c 00 01            move.b #$1, -(a7)
  002226:  48 6d a5 c4            pea.l -$5a3c(a5)
  00222a:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  00222e:  4e 90                  jsr (a0)
  002230:  48 6d a5 c4            pea.l -$5a3c(a5)
  002234:  a9 28                  dc.w $a928
  002236:  5c 8f                  addq.l #$6, a7
  002238:  2e 1f                  move.l (a7)+, d7
  00223a:  4e 5e                  unlk a6
  00223c:  4e 75                  rts 
  00223e:  4e 56 00 00            link.w a6, #$0
  002242:  20 2d 96 22            move.l -$69de(a5), d0
  002246:  22 00                  move.l d0, d1
  002248:  0a 40 56 9a            eori.w #$569a, d0
  00224c:  48 41                  swap d1
  00224e:  d0 41                  add.w d1, d0
  002250:  c0 fc 6a 59            mulu.w #$6a59, d0
  002254:  2b 40 96 22            move.l d0, -$69de(a5)
  002258:  48 41                  swap d1
  00225a:  d0 41                  add.w d1, d0
  00225c:  32 2e 00 08            move.w $8(a6), d1
  002260:  52 41                  addq.w #$1, d1
  002262:  c0 c1                  mulu.w d1, d0
  002264:  42 40                  clr.w d0
  002266:  48 40                  swap d0
  002268:  4e 5e                  unlk a6
  00226a:  4e 75                  rts 
  00226c:  4e 56 00 00            link.w a6, #$0
  002270:  2f 07                  move.l d7, -(a7)
  002272:  3e 2e 00 08            move.w $8(a6), d7
  002276:  48 c7                  ext.l d7
  002278:  8f fc 00 64            divs.w #$64, d7
  00227c:  48 47                  swap d7
  00227e:  48 c7                  ext.l d7
  002280:  8f fc 00 0a            divs.w #$a, d7
  002284:  4a 47                  tst.w d7
  002286:  66 04                  bne.b $228c
  002288:  70 20                  moveq #$20, d0
  00228a:  60 04                  bra.b $2290
  00228c:  70 30                  moveq #$30, d0
  00228e:  d0 07                  add.b d7, d0
  002290:  2e 1f                  move.l (a7)+, d7
  002292:  4e 5e                  unlk a6
  002294:  4e 75                  rts 
  002296:  4e 56 00 00            link.w a6, #$0
  00229a:  2f 07                  move.l d7, -(a7)
  00229c:  3e 2e 00 08            move.w $8(a6), d7
  0022a0:  48 c7                  ext.l d7
  0022a2:  8f fc 00 64            divs.w #$64, d7
  0022a6:  48 47                  swap d7
  0022a8:  48 c7                  ext.l d7
  0022aa:  8f fc 00 0a            divs.w #$a, d7
  0022ae:  70 30                  moveq #$30, d0
  0022b0:  d0 07                  add.b d7, d0
  0022b2:  2e 1f                  move.l (a7)+, d7
  0022b4:  4e 5e                  unlk a6
  0022b6:  4e 75                  rts 
  0022b8:  4e 56 00 00            link.w a6, #$0
  0022bc:  2f 07                  move.l d7, -(a7)
  0022be:  3e 2e 00 08            move.w $8(a6), d7
  0022c2:  48 c7                  ext.l d7
  0022c4:  8f fc 00 0a            divs.w #$a, d7
  0022c8:  48 47                  swap d7
  0022ca:  70 30                  moveq #$30, d0
  0022cc:  d0 07                  add.b d7, d0
  0022ce:  2e 1f                  move.l (a7)+, d7
  0022d0:  4e 5e                  unlk a6
  0022d2:  4e 75                  rts 
  0022d4:  4e 56 ff f8            link.w a6, #$fff8
  0022d8:  48 e7 0f 00            movem.l d4-d7, -(a7)
  0022dc:  3e 2e 00 08            move.w $8(a6), d7
  0022e0:  3a 2e 00 0a            move.w $a(a6), d5
  0022e4:  4a 2d a2 0c            tst.b -$5df4(a5)
  0022e8:  67 00 00 d2            beq.w $23bc
  0022ec:  2d 6d a5 c4 ff f8      move.l -$5a3c(a5), -$8(a6)
  0022f2:  2d 6d a5 c8 ff fc      move.l -$5a38(a5), -$4(a6)
  0022f8:  4a 47                  tst.w d7
  0022fa:  6f 18                  ble.b $2314
  0022fc:  3c 2e ff fe            move.w -$2(a6), d6
  002300:  9c 6e ff fa            sub.w -$6(a6), d6
  002304:  48 c6                  ext.l d6
  002306:  8d c7                  divs.w d7, d6
  002308:  30 2e ff fa            move.w -$6(a6), d0
  00230c:  d0 47                  add.w d7, d0
  00230e:  3d 40 ff fe            move.w d0, -$2(a6)
  002312:  60 1a                  bra.b $232e
  002314:  4a 47                  tst.w d7
  002316:  6c 16                  bge.b $232e
  002318:  3c 2e ff fa            move.w -$6(a6), d6
  00231c:  9c 6e ff fe            sub.w -$2(a6), d6
  002320:  48 c6                  ext.l d6
  002322:  8d c7                  divs.w d7, d6
  002324:  30 2e ff fe            move.w -$2(a6), d0
  002328:  d0 47                  add.w d7, d0
  00232a:  3d 40 ff fa            move.w d0, -$6(a6)
  00232e:  4a 45                  tst.w d5
  002330:  6f 18                  ble.b $234a
  002332:  3c 2e ff fc            move.w -$4(a6), d6
  002336:  9c 6e ff f8            sub.w -$8(a6), d6
  00233a:  48 c6                  ext.l d6
  00233c:  8d c5                  divs.w d5, d6
  00233e:  30 2e ff f8            move.w -$8(a6), d0
  002342:  d0 45                  add.w d5, d0
  002344:  3d 40 ff fc            move.w d0, -$4(a6)
  002348:  60 6e                  bra.b $23b8
  00234a:  4a 45                  tst.w d5
  00234c:  6c 6a                  bge.b $23b8
  00234e:  3c 2e ff f8            move.w -$8(a6), d6
  002352:  9c 6e ff fc            sub.w -$4(a6), d6
  002356:  48 c6                  ext.l d6
  002358:  8d c5                  divs.w d5, d6
  00235a:  30 2e ff fc            move.w -$4(a6), d0
  00235e:  d0 45                  add.w d5, d0
  002360:  3d 40 ff f8            move.w d0, -$8(a6)
  002364:  60 52                  bra.b $23b8
  002366:  42 a7                  clr.l -(a7)
  002368:  a9 75                  dc.w $a975   ; _TickCount
  00236a:  28 1f                  move.l (a7)+, d4
  00236c:  4a 2d a2 09            tst.b -$5df7(a5)
  002370:  67 1c                  beq.b $238e
  002372:  20 6d a2 ca            movea.l -$5d36(a5), a0
  002376:  2f 10                  move.l (a0), -(a7)
  002378:  22 6d a2 16            movea.l -$5dea(a5), a1
  00237c:  2f 11                  move.l (a1), -(a7)
  00237e:  48 6e ff f8            pea.l -$8(a6)
  002382:  48 6e ff f8            pea.l -$8(a6)
  002386:  42 67                  clr.w -(a7)
  002388:  42 a7                  clr.l -(a7)
  00238a:  a8 ec                  dc.w $a8ec
  00238c:  60 16                  bra.b $23a4
  00238e:  2f 2d a2 ce            move.l -$5d32(a5), -(a7)
  002392:  2f 2d a2 1a            move.l -$5de6(a5), -(a7)
  002396:  48 6e ff f8            pea.l -$8(a6)
  00239a:  48 6e ff f8            pea.l -$8(a6)
  00239e:  42 67                  clr.w -(a7)
  0023a0:  42 a7                  clr.l -(a7)
  0023a2:  a8 ec                  dc.w $a8ec
  0023a4:  42 a7                  clr.l -(a7)
  0023a6:  a9 75                  dc.w $a975   ; _TickCount
  0023a8:  b8 9f                  cmp.l (a7)+, d4
  0023aa:  67 f8                  beq.b $23a4
  0023ac:  48 6e ff f8            pea.l -$8(a6)
  0023b0:  3f 07                  move.w d7, -(a7)
  0023b2:  3f 05                  move.w d5, -(a7)
  0023b4:  a8 a8                  dc.w $a8a8
  0023b6:  53 46                  subq.w #$1, d6
  0023b8:  4a 46                  tst.w d6
  0023ba:  66 aa                  bne.b $2366
  0023bc:  4c df 00 f0            movem.l (a7)+, d4-d7
  0023c0:  4e 5e                  unlk a6
  0023c2:  4e 75                  rts 
  0023c4:  4e 56 00 00            link.w a6, #$0
  0023c8:  48 e7 01 08            movem.l d7/a4, -(a7)
  0023cc:  4a 2d a2 0d            tst.b -$5df3(a5)
  0023d0:  67 54                  beq.b $2426
  0023d2:  42 a7                  clr.l -(a7)
  0023d4:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  0023d8:  4e ba 1d c4            jsr $419e(pc)
  0023dc:  20 1f                  move.l (a7)+, d0
  0023de:  a1 22                  dc.w $a122
  0023e0:  28 48                  movea.l a0, a4
  0023e2:  20 0c                  move.l a4, d0
  0023e4:  67 40                  beq.b $2426
  0023e6:  60 34                  bra.b $241c
  0023e8:  30 2e 00 0a            move.w $a(a6), d0
  0023ec:  d1 6d 96 54            add.w d0, -$69ac(a5)
  0023f0:  42 a7                  clr.l -(a7)
  0023f2:  a9 75                  dc.w $a975   ; _TickCount
  0023f4:  2e 1f                  move.l (a7)+, d7
  0023f6:  3f 2d 96 54            move.w -$69ac(a5), -(a7)
  0023fa:  2f 0c                  move.l a4, -(a7)
  0023fc:  4e ba 00 30            jsr $242e(pc)
  002400:  5c 8f                  addq.l #$6, a7
  002402:  42 a7                  clr.l -(a7)
  002404:  a9 75                  dc.w $a975   ; _TickCount
  002406:  be 9f                  cmp.l (a7)+, d7
  002408:  67 f8                  beq.b $2402
  00240a:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  00240e:  2f 0c                  move.l a4, -(a7)
  002410:  42 a7                  clr.l -(a7)
  002412:  3f 2d a2 36            move.w -$5dca(a5), -(a7)
  002416:  aa 9a                  dc.w $aa9a
  002418:  53 6e 00 08            subq.w #$1, $8(a6)
  00241c:  4a 6e 00 08            tst.w $8(a6)
  002420:  66 c6                  bne.b $23e8
  002422:  2f 0c                  move.l a4, -(a7)
  002424:  aa 24                  dc.w $aa24
  002426:  4c df 10 80            movem.l (a7)+, d7/a4
  00242a:  4e 5e                  unlk a6
  00242c:  4e 75                  rts 
  00242e:  4e 56 00 00            link.w a6, #$0
  002432:  22 6d a2 32            movea.l -$5dce(a5), a1
  002436:  22 51                  movea.l (a1), a1
  002438:  32 2d a2 36            move.w -$5dca(a5), d1
  00243c:  20 6e 00 08            movea.l $8(a6), a0
  002440:  20 50                  movea.l (a0), a0
  002442:  34 2e 00 0c            move.w $c(a6), d2
  002446:  20 d9                  move.l (a1)+, (a0)+
  002448:  20 d9                  move.l (a1)+, (a0)+
  00244a:  60 1a                  bra.b $2466
  00244c:  30 d9                  move.w (a1)+, (a0)+
  00244e:  30 19                  move.w (a1)+, d0
  002450:  c0 c2                  mulu.w d2, d0
  002452:  e0 88                  lsr.l #$8, d0
  002454:  30 c0                  move.w d0, (a0)+
  002456:  30 19                  move.w (a1)+, d0
  002458:  c0 c2                  mulu.w d2, d0
  00245a:  e0 88                  lsr.l #$8, d0
  00245c:  30 c0                  move.w d0, (a0)+
  00245e:  30 19                  move.w (a1)+, d0
  002460:  c0 c2                  mulu.w d2, d0
  002462:  e0 88                  lsr.l #$8, d0
  002464:  30 c0                  move.w d0, (a0)+
  002466:  51 c9 ff e4            dbra d1, $244c
  00246a:  4e 5e                  unlk a6
  00246c:  4e 75                  rts 
  00246e:  4e 56 00 00            link.w a6, #$0
  002472:  2f 07                  move.l d7, -(a7)
  002474:  42 a7                  clr.l -(a7)
  002476:  a9 75                  dc.w $a975   ; _TickCount
  002478:  2e 1f                  move.l (a7)+, d7
  00247a:  4a 2d a2 0d            tst.b -$5df3(a5)
  00247e:  67 1e                  beq.b $249e
  002480:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  002484:  3f 2e 00 08            move.w $8(a6), -(a7)
  002488:  20 6d a2 f4            movea.l -$5d0c(a5), a0
  00248c:  30 2e 00 0a            move.w $a(a6), d0
  002490:  48 c0                  ext.l d0
  002492:  e7 88                  lsl.l #$3, d0
  002494:  20 50                  movea.l (a0), a0
  002496:  48 70 08 0a            pea.l $a(a0, d0.l)
  00249a:  aa 99                  dc.w $aa99
  00249c:  60 1a                  bra.b $24b8
  00249e:  48 6d a5 c4            pea.l -$5a3c(a5)
  0024a2:  a8 a4                  dc.w $a8a4
  0024a4:  60 12                  bra.b $24b8
  0024a6:  42 a7                  clr.l -(a7)
  0024a8:  a9 75                  dc.w $a975   ; _TickCount
  0024aa:  be 9f                  cmp.l (a7)+, d7
  0024ac:  67 f8                  beq.b $24a6
  0024ae:  42 a7                  clr.l -(a7)
  0024b0:  a9 75                  dc.w $a975   ; _TickCount
  0024b2:  2e 1f                  move.l (a7)+, d7
  0024b4:  53 6e 00 0c            subq.w #$1, $c(a6)
  0024b8:  4a 6e 00 0c            tst.w $c(a6)
  0024bc:  66 e8                  bne.b $24a6
  0024be:  2e 1f                  move.l (a7)+, d7
  0024c0:  4e 5e                  unlk a6
  0024c2:  4e 75                  rts 
  0024c4:  4e 56 00 00            link.w a6, #$0
  0024c8:  48 e7 07 08            movem.l d5-d7/a4, -(a7)
  0024cc:  3e 2e 00 08            move.w $8(a6), d7
  0024d0:  3a 2e 00 0a            move.w $a(a6), d5
  0024d4:  4a 2d a2 0e            tst.b -$5df2(a5)
  0024d8:  67 58                  beq.b $2532
  0024da:  0c 47 00 07            cmpi.w #$7, d7
  0024de:  6c 52                  bge.b $2532
  0024e0:  7c 00                  moveq #$0, d6
  0024e2:  99 cc                  suba.l a4, a4
  0024e4:  60 2e                  bra.b $2514
  0024e6:  20 4d                  movea.l a5, a0
  0024e8:  20 07                  move.l d7, d0
  0024ea:  48 c0                  ext.l d0
  0024ec:  e5 88                  lsl.l #$2, d0
  0024ee:  d1 c0                  adda.l d0, a0
  0024f0:  20 68 a2 38            movea.l -$5dc8(a0), a0
  0024f4:  20 10                  move.l (a0), d0
  0024f6:  20 6d a2 32            movea.l -$5dce(a5), a0
  0024fa:  22 06                  move.l d6, d1
  0024fc:  48 c1                  ext.l d1
  0024fe:  e7 89                  lsl.l #$3, d1
  002500:  d2 90                  add.l (a0), d1
  002502:  22 41                  movea.l d1, a1
  002504:  23 74 08 0a 03 52      move.l $a(a4, d0.l), $352(a1)
  00250a:  33 74 08 0e 03 56      move.w $e(a4, d0.l), $356(a1)
  002510:  52 46                  addq.w #$1, d6
  002512:  50 8c                  addq.l #$8, a4
  002514:  0c 46 00 0d            cmpi.w #$d, d6
  002518:  6d cc                  blt.b $24e6
  00251a:  4a 45                  tst.w d5
  00251c:  67 14                  beq.b $2532
  00251e:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  002522:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  002526:  2f 3c 00 69 00 69      move.l #$690069, -(a7)
  00252c:  3f 3c 00 0d            move.w #$d, -(a7)
  002530:  aa 9a                  dc.w $aa9a
  002532:  4c df 10 e0            movem.l (a7)+, d5-d7/a4
  002536:  4e 5e                  unlk a6
  002538:  4e 75                  rts 
  00253a:  4e 56 00 00            link.w a6, #$0
  00253e:  48 e7 38 20            movem.l d2-d4/a2, -(a7)
  002542:  24 6e 00 08            movea.l $8(a6), a2
  002546:  28 2e 00 0c            move.l $c(a6), d4
  00254a:  22 6e 00 10            movea.l $10(a6), a1
  00254e:  53 84                  subq.l #$1, d4
  002550:  6b 3e                  bmi.b $2590
  002552:  14 1a                  move.b (a2)+, d2
  002554:  76 07                  moveq #$7, d3
  002556:  e2 0a                  lsr.b #$1, d2
  002558:  65 0c                  bcs.b $2566
  00255a:  53 84                  subq.l #$1, d4
  00255c:  6b 32                  bmi.b $2590
  00255e:  12 da                  move.b (a2)+, (a1)+
  002560:  51 cb ff f4            dbra d3, $2556
  002564:  60 e8                  bra.b $254e
  002566:  55 84                  subq.l #$2, d4
  002568:  6b 26                  bmi.b $2590
  00256a:  10 1a                  move.b (a2)+, d0
  00256c:  e1 48                  lsl.w #$8, d0
  00256e:  10 1a                  move.b (a2)+, d0
  002570:  32 00                  move.w d0, d1
  002572:  20 49                  movea.l a1, a0
  002574:  02 40 0f ff            andi.w #$fff, d0
  002578:  52 40                  addq.w #$1, d0
  00257a:  90 c0                  suba.w d0, a0
  00257c:  e9 59                  rol.w #$4, d1
  00257e:  02 41 00 0f            andi.w #$f, d1
  002582:  54 41                  addq.w #$2, d1
  002584:  12 d8                  move.b (a0)+, (a1)+
  002586:  51 c9 ff fc            dbra d1, $2584
  00258a:  51 cb ff ca            dbra d3, $2556
  00258e:  60 be                  bra.b $254e
  002590:  4c df 04 1c            movem.l (a7)+, d2-d4/a2
  002594:  4e 5e                  unlk a6
  002596:  4e 75                  rts 
  002598:  4e 56 ff f8            link.w a6, #$fff8
  00259c:  2f 0c                  move.l a4, -(a7)
  00259e:  4a 2d 96 1d            tst.b -$69e3(a5)
  0025a2:  66 64                  bne.b $2608
  0025a4:  4a 2d a2 08            tst.b -$5df8(a5)
  0025a8:  67 5e                  beq.b $2608
  0025aa:  42 78 0b aa            clr.w $baa.w
  0025ae:  21 ed a0 ac 09 ee      move.l -$5f54(a5), $9ee.w
  0025b4:  48 6d a0 b6            pea.l -$5f4a(a5)
  0025b8:  a8 74                  dc.w $a874
  0025ba:  48 6e ff fc            pea.l -$4(a6)
  0025be:  a9 10                  dc.w $a910
  0025c0:  2f 2e ff fc            move.l -$4(a6), -(a7)
  0025c4:  a8 73                  dc.w $a873
  0025c6:  2f 38 09 ee            move.l $9ee.w, -(a7)
  0025ca:  a8 79                  dc.w $a879
  0025cc:  42 a7                  clr.l -(a7)
  0025ce:  2f 2d a0 ac            move.l -$5f54(a5), -(a7)
  0025d2:  a9 0c                  dc.w $a90c
  0025d4:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  0025d8:  a8 d3                  dc.w $a8d3
  0025da:  42 a7                  clr.l -(a7)
  0025dc:  a9 24                  dc.w $a924
  0025de:  28 5f                  movea.l (a7)+, a4
  0025e0:  2f 0c                  move.l a4, -(a7)
  0025e2:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  0025e6:  a9 0c                  dc.w $a90c
  0025e8:  2f 0c                  move.l a4, -(a7)
  0025ea:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  0025ee:  a9 0d                  dc.w $a90d
  0025f0:  2f 0c                  move.l a4, -(a7)
  0025f2:  a9 09                  dc.w $a909
  0025f4:  2f 0c                  move.l a4, -(a7)
  0025f6:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  0025fa:  a9 0a                  dc.w $a90a
  0025fc:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  002600:  a8 73                  dc.w $a873
  002602:  1b 7c 00 01 96 1d      move.b #$1, -$69e3(a5)
  002608:  4e ba 00 66            jsr $2670(pc)
  00260c:  28 5f                  movea.l (a7)+, a4
  00260e:  4e 5e                  unlk a6
  002610:  4e 75                  rts 
  002612:  4e 56 ff fc            link.w a6, #$fffc
  002616:  2f 0c                  move.l a4, -(a7)
  002618:  4a 2d 96 1d            tst.b -$69e3(a5)
  00261c:  67 48                  beq.b $2666
  00261e:  31 ed a0 b0 0b aa      move.w -$5f50(a5), $baa.w
  002624:  21 ed a0 a4 09 ee      move.l -$5f5c(a5), $9ee.w
  00262a:  48 6d a0 b6            pea.l -$5f4a(a5)
  00262e:  a8 74                  dc.w $a874
  002630:  48 6e ff fc            pea.l -$4(a6)
  002634:  a9 10                  dc.w $a910
  002636:  2f 2e ff fc            move.l -$4(a6), -(a7)
  00263a:  a8 73                  dc.w $a873
  00263c:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  002640:  a8 d3                  dc.w $a8d3
  002642:  42 a7                  clr.l -(a7)
  002644:  a9 24                  dc.w $a924
  002646:  28 5f                  movea.l (a7)+, a4
  002648:  2f 0c                  move.l a4, -(a7)
  00264a:  a9 09                  dc.w $a909
  00264c:  2f 0c                  move.l a4, -(a7)
  00264e:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  002652:  a9 0a                  dc.w $a90a
  002654:  a9 37                  dc.w $a937
  002656:  2f 38 09 ee            move.l $9ee.w, -(a7)
  00265a:  a8 79                  dc.w $a879
  00265c:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  002660:  a8 73                  dc.w $a873
  002662:  42 2d 96 1d            clr.b -$69e3(a5)
  002666:  4e ba 00 1e            jsr $2686(pc)
  00266a:  28 5f                  movea.l (a7)+, a4
  00266c:  4e 5e                  unlk a6
  00266e:  4e 75                  rts 
  002670:  4a 2d 96 1c            tst.b -$69e4(a5)
  002674:  66 0e                  bne.b $2684
  002676:  4a 2d a2 08            tst.b -$5df8(a5)
  00267a:  67 08                  beq.b $2684
  00267c:  a8 52                  dc.w $a852
  00267e:  1b 7c 00 01 96 1c      move.b #$1, -$69e4(a5)
  002684:  4e 75                  rts 
  002686:  4a 2d 96 1c            tst.b -$69e4(a5)
  00268a:  67 06                  beq.b $2692
  00268c:  a8 53                  dc.w $a853
  00268e:  42 2d 96 1c            clr.b -$69e4(a5)
  002692:  4e 75                  rts 
  002694:  4e ba 05 b0            jsr $2c46(pc)
  002698:  4e ba ff ec            jsr $2686(pc)
  00269c:  4e 75                  rts 
  00269e:  4e ba 05 d4            jsr $2c74(pc)
  0026a2:  4e ba ff cc            jsr $2670(pc)
  0026a6:  4e 75                  rts 
  0026a8:  4e 56 00 00            link.w a6, #$0
  0026ac:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  0026b0:  28 6e 00 0c            movea.l $c(a6), a4
  0026b4:  4e ba 05 58            jsr $2c0e(pc)
  0026b8:  30 14                  move.w (a4), d0
  0026ba:  6b 58                  bmi.b $2714
  0026bc:  57 40                  subq.w #$3, d0
  0026be:  67 02                  beq.b $26c2
  0026c0:  60 52                  bra.b $2714
  0026c2:  2e 2c 00 02            move.l $2(a4), d7
  0026c6:  2c 07                  move.l d7, d6
  0026c8:  02 86 00 00 ff 00      andi.l #$ff00, d6
  0026ce:  e0 86                  asr.l #$8, d6
  0026d0:  7c ff                  moveq #$ff, d6
  0026d2:  cc 07                  and.b d7, d6
  0026d4:  3e 2c 00 0e            move.w $e(a4), d7
  0026d8:  10 06                  move.b d6, d0
  0026da:  6b 38                  bmi.b $2714
  0026dc:  04 00 00 0d            subi.b #$d, d0
  0026e0:  67 12                  beq.b $26f4
  0026e2:  6a 08                  bpl.b $26ec
  0026e4:  04 00 00 f6            subi.b #$f6, d0
  0026e8:  67 0a                  beq.b $26f4
  0026ea:  60 28                  bra.b $2714
  0026ec:  04 00 00 0e            subi.b #$e, d0
  0026f0:  67 12                  beq.b $2704
  0026f2:  60 20                  bra.b $2714
  0026f4:  20 6e 00 08            movea.l $8(a6), a0
  0026f8:  30 bc 00 01            move.w #$1, (a0)
  0026fc:  1d 7c 00 01 00 14      move.b #$1, $14(a6)
  002702:  60 14                  bra.b $2718
  002704:  20 6e 00 08            movea.l $8(a6), a0
  002708:  30 bc 00 02            move.w #$2, (a0)
  00270c:  1d 7c 00 01 00 14      move.b #$1, $14(a6)
  002712:  60 04                  bra.b $2718
  002714:  42 2e 00 14            clr.b $14(a6)
  002718:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  00271c:  4e 5e                  unlk a6
  00271e:  20 5f                  movea.l (a7)+, a0
  002720:  4f ef 00 0c            lea.l $c(a7), a7
  002724:  4e d0                  jmp (a0)
  002726:  4e 56 00 00            link.w a6, #$0
  00272a:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  00272e:  28 78 03 28            movea.l $328.w, a4
  002732:  20 0c                  move.l a4, d0
  002734:  67 0a                  beq.b $2740
  002736:  20 4c                  movea.l a4, a0
  002738:  a0 69                  dc.w $a069
  00273a:  1e 00                  move.b d0, d7
  00273c:  20 4c                  movea.l a4, a0
  00273e:  a0 29                  dc.w $a029
  002740:  7c 00                  moveq #$0, d6
  002742:  4a 2d 96 1e            tst.b -$69e2(a5)
  002746:  66 4a                  bne.b $2792
  002748:  4a 2d 96 5b            tst.b -$69a5(a5)
  00274c:  67 06                  beq.b $2754
  00274e:  4a 2d 96 59            tst.b -$69a7(a5)
  002752:  66 26                  bne.b $277a
  002754:  1b 7c 00 01 96 5b      move.b #$1, -$69a5(a5)
  00275a:  1b 7c 00 01 96 59      move.b #$1, -$69a7(a5)
  002760:  4e ba 02 e8            jsr $2a4a(pc)
  002764:  4e ba ff 20            jsr $2686(pc)
  002768:  a8 50                  dc.w $a850   ; _InitCursor
  00276a:  42 67                  clr.w -(a7)
  00276c:  3f 3c 03 f0            move.w #$3f0, -(a7)
  002770:  42 a7                  clr.l -(a7)
  002772:  a9 85                  dc.w $a985
  002774:  7c 01                  moveq #$1, d6
  002776:  54 8f                  addq.l #$2, a7
  002778:  60 18                  bra.b $2792
  00277a:  1b 7c 00 01 96 1e      move.b #$1, -$69e2(a5)
  002780:  4e ba ff 04            jsr $2686(pc)
  002784:  a8 50                  dc.w $a850   ; _InitCursor
  002786:  42 67                  clr.w -(a7)
  002788:  3f 3c 03 ea            move.w #$3ea, -(a7)
  00278c:  42 a7                  clr.l -(a7)
  00278e:  a9 85                  dc.w $a985
  002790:  54 8f                  addq.l #$2, a7
  002792:  20 0c                  move.l a4, d0
  002794:  67 06                  beq.b $279c
  002796:  10 07                  move.b d7, d0
  002798:  20 4c                  movea.l a4, a0
  00279a:  a0 6a                  dc.w $a06a
  00279c:  2d 46 00 0c            move.l d6, $c(a6)
  0027a0:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  0027a4:  4e 5e                  unlk a6
  0027a6:  2e 9f                  move.l (a7)+, (a7)
  0027a8:  4e 75                  rts 
  0027aa:  4e 56 ff fe            link.w a6, #$fffe
  0027ae:  4a 2d 96 1e            tst.b -$69e2(a5)
  0027b2:  66 62                  bne.b $2816
  0027b4:  4a 6e 00 08            tst.w $8(a6)
  0027b8:  6c 1a                  bge.b $27d4
  0027ba:  0c 6e ff ff 00 08      cmpi.w #$ffff, $8(a6)
  0027c0:  66 0a                  bne.b $27cc
  0027c2:  42 67                  clr.w -(a7)
  0027c4:  a9 af                  dc.w $a9af
  0027c6:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0027ca:  60 0c                  bra.b $27d8
  0027cc:  3b 6e 00 08 a1 6c      move.w $8(a6), -$5e94(a5)
  0027d2:  60 04                  bra.b $27d8
  0027d4:  42 6d a1 6c            clr.w -$5e94(a5)
  0027d8:  4a 6d a1 6c            tst.w -$5e94(a5)
  0027dc:  67 38                  beq.b $2816
  0027de:  4e ba 03 40            jsr $2b20(pc)
  0027e2:  4e ba fe a2            jsr $2686(pc)
  0027e6:  a8 50                  dc.w $a850   ; _InitCursor
  0027e8:  30 6d a1 6c            movea.w -$5e94(a5), a0
  0027ec:  2f 08                  move.l a0, -(a7)
  0027ee:  48 6d a1 6e            pea.l -$5e92(a5)
  0027f2:  4e ba 1c 72            jsr $4466(pc)
  0027f6:  48 6d a1 6e            pea.l -$5e92(a5)
  0027fa:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  0027fe:  42 a7                  clr.l -(a7)
  002800:  42 a7                  clr.l -(a7)
  002802:  a9 8b                  dc.w $a98b
  002804:  42 67                  clr.w -(a7)
  002806:  3f 3c 03 ee            move.w #$3ee, -(a7)
  00280a:  42 a7                  clr.l -(a7)
  00280c:  a9 85                  dc.w $a985
  00280e:  1b 7c 00 01 96 1e      move.b #$1, -$69e2(a5)
  002814:  54 8f                  addq.l #$2, a7
  002816:  10 2d 96 1e            move.b -$69e2(a5), d0
  00281a:  4e 5e                  unlk a6
  00281c:  4e 75                  rts 
  00281e:  4e 56 00 00            link.w a6, #$0
  002822:  4a 2d 96 1e            tst.b -$69e2(a5)
  002826:  66 30                  bne.b $2858
  002828:  42 67                  clr.w -(a7)
  00282a:  a9 af                  dc.w $a9af
  00282c:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  002830:  4a ae 00 08            tst.l $8(a6)
  002834:  67 06                  beq.b $283c
  002836:  4a 6d a1 6c            tst.w -$5e94(a5)
  00283a:  67 1c                  beq.b $2858
  00283c:  4e ba 02 e2            jsr $2b20(pc)
  002840:  4e ba fe 44            jsr $2686(pc)
  002844:  a8 50                  dc.w $a850   ; _InitCursor
  002846:  42 67                  clr.w -(a7)
  002848:  3f 3c 03 e9            move.w #$3e9, -(a7)
  00284c:  42 a7                  clr.l -(a7)
  00284e:  a9 85                  dc.w $a985
  002850:  1b 7c 00 01 96 1e      move.b #$1, -$69e2(a5)
  002856:  54 8f                  addq.l #$2, a7
  002858:  10 2d 96 1e            move.b -$69e2(a5), d0
  00285c:  4e 5e                  unlk a6
  00285e:  4e 75                  rts 
  002860:  4e 56 00 00            link.w a6, #$0
  002864:  4a 2d 96 1e            tst.b -$69e2(a5)
  002868:  66 2e                  bne.b $2898
  00286a:  3b 78 02 20 a1 6c      move.w $220.w, -$5e94(a5)
  002870:  4a ae 00 08            tst.l $8(a6)
  002874:  67 06                  beq.b $287c
  002876:  4a 6d a1 6c            tst.w -$5e94(a5)
  00287a:  67 1c                  beq.b $2898
  00287c:  4e ba 02 a2            jsr $2b20(pc)
  002880:  4e ba fe 04            jsr $2686(pc)
  002884:  a8 50                  dc.w $a850   ; _InitCursor
  002886:  42 67                  clr.w -(a7)
  002888:  3f 3c 03 ea            move.w #$3ea, -(a7)
  00288c:  42 a7                  clr.l -(a7)
  00288e:  a9 85                  dc.w $a985
  002890:  1b 7c 00 01 96 1e      move.b #$1, -$69e2(a5)
  002896:  54 8f                  addq.l #$2, a7
  002898:  10 2d 96 1e            move.b -$69e2(a5), d0
  00289c:  4e 5e                  unlk a6
  00289e:  4e 75                  rts 
  0028a0:  4e 56 00 00            link.w a6, #$0
  0028a4:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  0028a8:  3a 2e 00 08            move.w $8(a6), d5
  0028ac:  7e 00                  moveq #$0, d7
  0028ae:  7c 00                  moveq #$0, d6
  0028b0:  3f 05                  move.w d5, -(a7)
  0028b2:  4e ba 02 e0            jsr $2b94(pc)
  0028b6:  4a 00                  tst.b d0
  0028b8:  54 8f                  addq.l #$2, a7
  0028ba:  67 62                  beq.b $291e
  0028bc:  38 05                  move.w d5, d4
  0028be:  06 44 03 e8            addi.w #$3e8, d4
  0028c2:  36 05                  move.w d5, d3
  0028c4:  06 43 07 d0            addi.w #$7d0, d3
  0028c8:  49 ed a4 64            lea.l -$5b9c(a5), a4
  0028cc:  d8 c6                  adda.w d6, a4
  0028ce:  d8 c6                  adda.w d6, a4
  0028d0:  60 0c                  bra.b $28de
  0028d2:  b8 54                  cmp.w (a4), d4
  0028d4:  66 04                  bne.b $28da
  0028d6:  7e 01                  moveq #$1, d7
  0028d8:  60 0a                  bra.b $28e4
  0028da:  52 46                  addq.w #$1, d6
  0028dc:  54 8c                  addq.l #$2, a4
  0028de:  bc 6d 96 46            cmp.w -$69ba(a5), d6
  0028e2:  6d ee                  blt.b $28d2
  0028e4:  4a 07                  tst.b d7
  0028e6:  66 1a                  bne.b $2902
  0028e8:  38 6d 96 46            movea.w -$69ba(a5), a4
  0028ec:  d9 cc                  adda.l a4, a4
  0028ee:  41 ed a4 64            lea.l -$5b9c(a5), a0
  0028f2:  d1 cc                  adda.l a4, a0
  0028f4:  30 84                  move.w d4, (a0)
  0028f6:  41 ed a4 da            lea.l -$5b26(a5), a0
  0028fa:  d1 cc                  adda.l a4, a0
  0028fc:  30 83                  move.w d3, (a0)
  0028fe:  52 6d 96 46            addq.w #$1, -$69ba(a5)
  002902:  38 6d 96 46            movea.w -$69ba(a5), a4
  002906:  d9 cc                  adda.l a4, a4
  002908:  41 ed a4 64            lea.l -$5b9c(a5), a0
  00290c:  d1 cc                  adda.l a4, a0
  00290e:  30 bc ff ff            move.w #$ffff, (a0)
  002912:  41 ed a4 da            lea.l -$5b26(a5), a0
  002916:  d1 cc                  adda.l a4, a0
  002918:  30 bc ff ff            move.w #$ffff, (a0)
  00291c:  60 48                  bra.b $2966
  00291e:  38 05                  move.w d5, d4
  002920:  06 44 13 88            addi.w #$1388, d4
  002924:  49 ed a3 ee            lea.l -$5c12(a5), a4
  002928:  d8 c6                  adda.w d6, a4
  00292a:  d8 c6                  adda.w d6, a4
  00292c:  60 0c                  bra.b $293a
  00292e:  b8 54                  cmp.w (a4), d4
  002930:  66 04                  bne.b $2936
  002932:  7e 01                  moveq #$1, d7
  002934:  60 0a                  bra.b $2940
  002936:  52 46                  addq.w #$1, d6
  002938:  54 8c                  addq.l #$2, a4
  00293a:  bc 6d 96 40            cmp.w -$69c0(a5), d6
  00293e:  6d ee                  blt.b $292e
  002940:  4a 07                  tst.b d7
  002942:  66 12                  bne.b $2956
  002944:  30 2d 96 40            move.w -$69c0(a5), d0
  002948:  20 4d                  movea.l a5, a0
  00294a:  d0 c0                  adda.w d0, a0
  00294c:  d0 c0                  adda.w d0, a0
  00294e:  31 44 a3 ee            move.w d4, -$5c12(a0)
  002952:  52 6d 96 40            addq.w #$1, -$69c0(a5)
  002956:  30 2d 96 40            move.w -$69c0(a5), d0
  00295a:  20 4d                  movea.l a5, a0
  00295c:  d0 c0                  adda.w d0, a0
  00295e:  d0 c0                  adda.w d0, a0
  002960:  31 7c ff ff a3 ee      move.w #$ffff, -$5c12(a0)
  002966:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  00296a:  4e 5e                  unlk a6
  00296c:  4e 75                  rts 
  00296e:  4e 56 00 00            link.w a6, #$0
  002972:  48 e7 1f 38            movem.l d3-d7/a2-a4, -(a7)
  002976:  3a 2e 00 08            move.w $8(a6), d5
  00297a:  7e 00                  moveq #$0, d7
  00297c:  7c 00                  moveq #$0, d6
  00297e:  3f 05                  move.w d5, -(a7)
  002980:  4e ba 02 12            jsr $2b94(pc)
  002984:  4a 00                  tst.b d0
  002986:  54 8f                  addq.l #$2, a7
  002988:  67 54                  beq.b $29de
  00298a:  38 05                  move.w d5, d4
  00298c:  06 44 03 e8            addi.w #$3e8, d4
  002990:  36 05                  move.w d5, d3
  002992:  06 43 07 d0            addi.w #$7d0, d3
  002996:  38 46                  movea.w d6, a4
  002998:  d9 cc                  adda.l a4, a4
  00299a:  47 ed a4 da            lea.l -$5b26(a5), a3
  00299e:  d7 cc                  adda.l a4, a3
  0029a0:  45 ed a4 64            lea.l -$5b9c(a5), a2
  0029a4:  d5 cc                  adda.l a4, a2
  0029a6:  60 26                  bra.b $29ce
  0029a8:  b8 52                  cmp.w (a2), d4
  0029aa:  66 02                  bne.b $29ae
  0029ac:  7e 01                  moveq #$1, d7
  0029ae:  4a 07                  tst.b d7
  0029b0:  67 16                  beq.b $29c8
  0029b2:  38 46                  movea.w d6, a4
  0029b4:  49 f4 60 02            lea.l $2(a4, d6.w), a4
  0029b8:  41 ed a4 64            lea.l -$5b9c(a5), a0
  0029bc:  d1 cc                  adda.l a4, a0
  0029be:  34 90                  move.w (a0), (a2)
  0029c0:  41 ed a4 da            lea.l -$5b26(a5), a0
  0029c4:  d1 cc                  adda.l a4, a0
  0029c6:  36 90                  move.w (a0), (a3)
  0029c8:  52 46                  addq.w #$1, d6
  0029ca:  54 8b                  addq.l #$2, a3
  0029cc:  54 8a                  addq.l #$2, a2
  0029ce:  bc 6d 96 46            cmp.w -$69ba(a5), d6
  0029d2:  6d d4                  blt.b $29a8
  0029d4:  4a 07                  tst.b d7
  0029d6:  67 3c                  beq.b $2a14
  0029d8:  53 6d 96 46            subq.w #$1, -$69ba(a5)
  0029dc:  60 36                  bra.b $2a14
  0029de:  38 05                  move.w d5, d4
  0029e0:  06 44 13 88            addi.w #$1388, d4
  0029e4:  49 ed a3 ee            lea.l -$5c12(a5), a4
  0029e8:  d8 c6                  adda.w d6, a4
  0029ea:  d8 c6                  adda.w d6, a4
  0029ec:  60 18                  bra.b $2a06
  0029ee:  b8 54                  cmp.w (a4), d4
  0029f0:  66 02                  bne.b $29f4
  0029f2:  7e 01                  moveq #$1, d7
  0029f4:  4a 07                  tst.b d7
  0029f6:  67 0a                  beq.b $2a02
  0029f8:  20 4d                  movea.l a5, a0
  0029fa:  d0 c6                  adda.w d6, a0
  0029fc:  d0 c6                  adda.w d6, a0
  0029fe:  38 a8 a3 f0            move.w -$5c10(a0), (a4)
  002a02:  52 46                  addq.w #$1, d6
  002a04:  54 8c                  addq.l #$2, a4
  002a06:  bc 6d 96 40            cmp.w -$69c0(a5), d6
  002a0a:  6d e2                  blt.b $29ee
  002a0c:  4a 07                  tst.b d7
  002a0e:  67 04                  beq.b $2a14
  002a10:  53 6d 96 40            subq.w #$1, -$69c0(a5)
  002a14:  4c df 1c f8            movem.l (a7)+, d3-d7/a2-a4
  002a18:  4e 5e                  unlk a6
  002a1a:  4e 75                  rts 
  002a1c:  4a 2d 96 3c            tst.b -$69c4(a5)
  002a20:  66 20                  bne.b $2a42
  002a22:  4a 2d 96 5b            tst.b -$69a5(a5)
  002a26:  66 0a                  bne.b $2a32
  002a28:  4a 2d 96 5c            tst.b -$69a4(a5)
  002a2c:  67 04                  beq.b $2a32
  002a2e:  4e ba 03 68            jsr $2d98(pc)
  002a32:  4a 2d 96 59            tst.b -$69a7(a5)
  002a36:  66 0a                  bne.b $2a42
  002a38:  4a 2d 96 5a            tst.b -$69a6(a5)
  002a3c:  67 04                  beq.b $2a42
  002a3e:  4e ba 02 5e            jsr $2c9e(pc)
  002a42:  1b 7c 00 01 96 3c      move.b #$1, -$69c4(a5)
  002a48:  4e 75                  rts 
  002a4a:  4a 2d 96 3c            tst.b -$69c4(a5)
  002a4e:  67 08                  beq.b $2a58
  002a50:  4e ba 02 aa            jsr $2cfc(pc)
  002a54:  4e ba 04 08            jsr $2e5e(pc)
  002a58:  42 2d 96 3c            clr.b -$69c4(a5)
  002a5c:  4e 75                  rts 
  002a5e:  4e 56 00 00            link.w a6, #$0
  002a62:  2f 07                  move.l d7, -(a7)
  002a64:  3e 2e 00 08            move.w $8(a6), d7
  002a68:  3f 07                  move.w d7, -(a7)
  002a6a:  4e ba 01 28            jsr $2b94(pc)
  002a6e:  4a 00                  tst.b d0
  002a70:  54 8f                  addq.l #$2, a7
  002a72:  67 48                  beq.b $2abc
  002a74:  4a 2d 96 5c            tst.b -$69a4(a5)
  002a78:  67 00 00 a0            beq.w $2b1a
  002a7c:  4a 2d 96 42            tst.b -$69be(a5)
  002a80:  67 00 00 98            beq.w $2b1a
  002a84:  4a 2d 96 3d            tst.b -$69c3(a5)
  002a88:  67 0a                  beq.b $2a94
  002a8a:  4a 2d 96 3e            tst.b -$69c2(a5)
  002a8e:  67 04                  beq.b $2a94
  002a90:  4e ba 02 cc            jsr $2d5e(pc)
  002a94:  4a 2d 96 43            tst.b -$69bd(a5)
  002a98:  66 04                  bne.b $2a9e
  002a9a:  4e ba 04 84            jsr $2f20(pc)
  002a9e:  4a 2d 96 45            tst.b -$69bb(a5)
  002aa2:  67 06                  beq.b $2aaa
  002aa4:  06 47 07 d0            addi.w #$7d0, d7
  002aa8:  60 04                  bra.b $2aae
  002aaa:  06 47 03 e8            addi.w #$3e8, d7
  002aae:  3f 07                  move.w d7, -(a7)
  002ab0:  3f 3c 00 02            move.w #$2, -(a7)
  002ab4:  4e ba 1b ae            jsr $4664(pc)
  002ab8:  58 8f                  addq.l #$4, a7
  002aba:  60 5e                  bra.b $2b1a
  002abc:  4a 2d 96 5a            tst.b -$69a6(a5)
  002ac0:  67 58                  beq.b $2b1a
  002ac2:  4a 2d 96 3d            tst.b -$69c3(a5)
  002ac6:  67 52                  beq.b $2b1a
  002ac8:  4a 2d 96 42            tst.b -$69be(a5)
  002acc:  67 1a                  beq.b $2ae8
  002ace:  4a 2d 96 43            tst.b -$69bd(a5)
  002ad2:  67 14                  beq.b $2ae8
  002ad4:  2f 3c 00 07 00 00      move.l #$70000, -(a7)
  002ada:  4e ba 1b 88            jsr $4664(pc)
  002ade:  4a 80                  tst.l d0
  002ae0:  58 8f                  addq.l #$4, a7
  002ae2:  67 36                  beq.b $2b1a
  002ae4:  4e ba 04 18            jsr $2efe(pc)
  002ae8:  4a 2d 96 3e            tst.b -$69c2(a5)
  002aec:  66 04                  bne.b $2af2
  002aee:  4e ba 02 8c            jsr $2d7c(pc)
  002af2:  06 47 13 88            addi.w #$1388, d7
  002af6:  4a 6d 96 56            tst.w -$69aa(a5)
  002afa:  67 14                  beq.b $2b10
  002afc:  3f 2d 96 56            move.w -$69aa(a5), -(a7)
  002b00:  42 67                  clr.w -(a7)
  002b02:  3f 07                  move.w d7, -(a7)
  002b04:  4e ba 2f 76            jsr $5a7c(pc)
  002b08:  42 6d 96 56            clr.w -$69aa(a5)
  002b0c:  5c 8f                  addq.l #$6, a7
  002b0e:  60 0a                  bra.b $2b1a
  002b10:  42 67                  clr.w -(a7)
  002b12:  3f 07                  move.w d7, -(a7)
  002b14:  4e ba 2d 32            jsr $5848(pc)
  002b18:  58 8f                  addq.l #$4, a7
  002b1a:  2e 1f                  move.l (a7)+, d7
  002b1c:  4e 5e                  unlk a6
  002b1e:  4e 75                  rts 
  002b20:  4a 2d 96 3d            tst.b -$69c3(a5)
  002b24:  67 0a                  beq.b $2b30
  002b26:  4a 2d 96 3e            tst.b -$69c2(a5)
  002b2a:  67 04                  beq.b $2b30
  002b2c:  4e ba 30 e0            jsr $5c0e(pc)
  002b30:  4a 2d 96 42            tst.b -$69be(a5)
  002b34:  67 12                  beq.b $2b48
  002b36:  4a 2d 96 43            tst.b -$69bd(a5)
  002b3a:  67 0c                  beq.b $2b48
  002b3c:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  002b42:  4e ba 1b 20            jsr $4664(pc)
  002b46:  58 8f                  addq.l #$4, a7
  002b48:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  002b4e:  4e 75                  rts 
  002b50:  4a 2d 96 3d            tst.b -$69c3(a5)
  002b54:  67 16                  beq.b $2b6c
  002b56:  4a 2d 96 3e            tst.b -$69c2(a5)
  002b5a:  67 10                  beq.b $2b6c
  002b5c:  4e ba 31 18            jsr $5c76(pc)
  002b60:  4a 00                  tst.b d0
  002b62:  67 04                  beq.b $2b68
  002b64:  70 00                  moveq #$0, d0
  002b66:  60 2a                  bra.b $2b92
  002b68:  70 01                  moveq #$1, d0
  002b6a:  60 26                  bra.b $2b92
  002b6c:  4a 2d 96 42            tst.b -$69be(a5)
  002b70:  67 1e                  beq.b $2b90
  002b72:  4a 2d 96 43            tst.b -$69bd(a5)
  002b76:  67 18                  beq.b $2b90
  002b78:  2f 3c 00 07 00 00      move.l #$70000, -(a7)
  002b7e:  4e ba 1a e4            jsr $4664(pc)
  002b82:  4a 80                  tst.l d0
  002b84:  58 8f                  addq.l #$4, a7
  002b86:  67 04                  beq.b $2b8c
  002b88:  70 00                  moveq #$0, d0
  002b8a:  60 06                  bra.b $2b92
  002b8c:  70 01                  moveq #$1, d0
  002b8e:  60 02                  bra.b $2b92
  002b90:  70 00                  moveq #$0, d0
  002b92:  4e 75                  rts 
  002b94:  4e 56 00 00            link.w a6, #$0
  002b98:  2f 07                  move.l d7, -(a7)
  002b9a:  3e 2e 00 08            move.w $8(a6), d7
  002b9e:  0c 47 00 18            cmpi.w #$18, d7
  002ba2:  6d 0c                  blt.b $2bb0
  002ba4:  0c 47 00 26            cmpi.w #$26, d7
  002ba8:  67 06                  beq.b $2bb0
  002baa:  0c 47 00 2c            cmpi.w #$2c, d7
  002bae:  6d 12                  blt.b $2bc2
  002bb0:  0c 47 00 32            cmpi.w #$32, d7
  002bb4:  6d 10                  blt.b $2bc6
  002bb6:  0c 47 00 33            cmpi.w #$33, d7
  002bba:  67 0a                  beq.b $2bc6
  002bbc:  0c 47 00 3a            cmpi.w #$3a, d7
  002bc0:  6c 04                  bge.b $2bc6
  002bc2:  70 01                  moveq #$1, d0
  002bc4:  60 02                  bra.b $2bc8
  002bc6:  70 00                  moveq #$0, d0
  002bc8:  2e 1f                  move.l (a7)+, d7
  002bca:  4e 5e                  unlk a6
  002bcc:  4e 75                  rts 
  002bce:  4e 56 00 00            link.w a6, #$0
  002bd2:  48 e7 03 00            movem.l d6-d7, -(a7)
  002bd6:  2c 2e 00 08            move.l $8(a6), d6
  002bda:  4a 2d 96 42            tst.b -$69be(a5)
  002bde:  67 24                  beq.b $2c04
  002be0:  4a 2d 96 43            tst.b -$69bd(a5)
  002be4:  67 1e                  beq.b $2c04
  002be6:  2f 3c 00 08 00 00      move.l #$80000, -(a7)
  002bec:  4e ba 1a 76            jsr $4664(pc)
  002bf0:  2e 00                  move.l d0, d7
  002bf2:  4a 87                  tst.l d7
  002bf4:  58 8f                  addq.l #$4, a7
  002bf6:  6f 08                  ble.b $2c00
  002bf8:  bc 87                  cmp.l d7, d6
  002bfa:  6f 04                  ble.b $2c00
  002bfc:  70 00                  moveq #$0, d0
  002bfe:  60 06                  bra.b $2c06
  002c00:  70 01                  moveq #$1, d0
  002c02:  60 02                  bra.b $2c06
  002c04:  70 01                  moveq #$1, d0
  002c06:  4c df 00 c0            movem.l (a7)+, d6-d7
  002c0a:  4e 5e                  unlk a6
  002c0c:  4e 75                  rts 
  002c0e:  4a 2d 96 42            tst.b -$69be(a5)
  002c12:  67 30                  beq.b $2c44
  002c14:  4a 2d 96 43            tst.b -$69bd(a5)
  002c18:  67 2a                  beq.b $2c44
  002c1a:  2f 3c 00 09 00 00      move.l #$90000, -(a7)
  002c20:  4e ba 1a 42            jsr $4664(pc)
  002c24:  2e bc 00 07 00 00      move.l #$70000, (a7)
  002c2a:  4e ba 1a 38            jsr $4664(pc)
  002c2e:  4a 80                  tst.l d0
  002c30:  58 8f                  addq.l #$4, a7
  002c32:  67 0a                  beq.b $2c3e
  002c34:  4e ba 02 c8            jsr $2efe(pc)
  002c38:  4e ba 01 42            jsr $2d7c(pc)
  002c3c:  60 06                  bra.b $2c44
  002c3e:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  002c44:  4e 75                  rts 
  002c46:  4a 2d 96 3d            tst.b -$69c3(a5)
  002c4a:  67 10                  beq.b $2c5c
  002c4c:  4a 2d 96 3e            tst.b -$69c2(a5)
  002c50:  67 0a                  beq.b $2c5c
  002c52:  4e ba 01 0a            jsr $2d5e(pc)
  002c56:  1b 7c 00 01 96 3f      move.b #$1, -$69c1(a5)
  002c5c:  4a 2d 96 42            tst.b -$69be(a5)
  002c60:  67 10                  beq.b $2c72
  002c62:  4a 2d 96 43            tst.b -$69bd(a5)
  002c66:  67 0a                  beq.b $2c72
  002c68:  4e ba 02 94            jsr $2efe(pc)
  002c6c:  1b 7c 00 01 96 44      move.b #$1, -$69bc(a5)
  002c72:  4e 75                  rts 
  002c74:  4a 2d 96 3d            tst.b -$69c3(a5)
  002c78:  67 0e                  beq.b $2c88
  002c7a:  4a 2d 96 3f            tst.b -$69c1(a5)
  002c7e:  67 08                  beq.b $2c88
  002c80:  4e ba 00 fa            jsr $2d7c(pc)
  002c84:  42 2d 96 3f            clr.b -$69c1(a5)
  002c88:  4a 2d 96 42            tst.b -$69be(a5)
  002c8c:  67 0e                  beq.b $2c9c
  002c8e:  4a 2d 96 44            tst.b -$69bc(a5)
  002c92:  67 08                  beq.b $2c9c
  002c94:  4e ba 02 8a            jsr $2f20(pc)
  002c98:  42 2d 96 44            clr.b -$69bc(a5)
  002c9c:  4e 75                  rts 
  002c9e:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  002ca2:  4a 2d 96 3d            tst.b -$69c3(a5)
  002ca6:  66 4e                  bne.b $2cf6
  002ca8:  4e ba 02 54            jsr $2efe(pc)
  002cac:  7e 00                  moveq #$0, d7
  002cae:  47 ed a3 ee            lea.l -$5c12(a5), a3
  002cb2:  60 20                  bra.b $2cd4
  002cb4:  3c 13                  move.w (a3), d6
  002cb6:  42 a7                  clr.l -(a7)
  002cb8:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  002cbe:  3f 06                  move.w d6, -(a7)
  002cc0:  a9 a0                  dc.w $a9a0
  002cc2:  28 5f                  movea.l (a7)+, a4
  002cc4:  20 0c                  move.l a4, d0
  002cc6:  67 08                  beq.b $2cd0
  002cc8:  20 4c                  movea.l a4, a0
  002cca:  a0 64                  dc.w $a064
  002ccc:  20 4c                  movea.l a4, a0
  002cce:  a0 29                  dc.w $a029
  002cd0:  52 47                  addq.w #$1, d7
  002cd2:  54 8b                  addq.l #$2, a3
  002cd4:  be 6d 96 40            cmp.w -$69c0(a5), d7
  002cd8:  6d da                  blt.b $2cb4
  002cda:  42 27                  clr.b -(a7)
  002cdc:  48 6d a3 ee            pea.l -$5c12(a5)
  002ce0:  4e ba 27 d2            jsr $54b4(pc)
  002ce4:  1b 7c 00 01 96 3d      move.b #$1, -$69c3(a5)
  002cea:  1b 7c 00 01 96 3e      move.b #$1, -$69c2(a5)
  002cf0:  a0 1c                  dc.w $a01c
  002cf2:  a0 4c                  dc.w $a04c
  002cf4:  5c 8f                  addq.l #$6, a7
  002cf6:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  002cfa:  4e 75                  rts 
  002cfc:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  002d00:  4a 2d 96 3d            tst.b -$69c3(a5)
  002d04:  67 52                  beq.b $2d58
  002d06:  4e ba 01 f6            jsr $2efe(pc)
  002d0a:  4e ba 00 70            jsr $2d7c(pc)
  002d0e:  4e ba 2f 66            jsr $5c76(pc)
  002d12:  4a 00                  tst.b d0
  002d14:  67 f8                  beq.b $2d0e
  002d16:  4e ba 28 7c            jsr $5594(pc)
  002d1a:  42 2d 96 3d            clr.b -$69c3(a5)
  002d1e:  42 2d 96 3e            clr.b -$69c2(a5)
  002d22:  7e 00                  moveq #$0, d7
  002d24:  47 ed a3 ee            lea.l -$5c12(a5), a3
  002d28:  60 20                  bra.b $2d4a
  002d2a:  3c 13                  move.w (a3), d6
  002d2c:  42 a7                  clr.l -(a7)
  002d2e:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  002d34:  3f 06                  move.w d6, -(a7)
  002d36:  a9 a0                  dc.w $a9a0
  002d38:  28 5f                  movea.l (a7)+, a4
  002d3a:  20 0c                  move.l a4, d0
  002d3c:  67 08                  beq.b $2d46
  002d3e:  20 4c                  movea.l a4, a0
  002d40:  a0 2a                  dc.w $a02a
  002d42:  20 4c                  movea.l a4, a0
  002d44:  a0 49                  dc.w $a049
  002d46:  52 47                  addq.w #$1, d7
  002d48:  54 8b                  addq.l #$2, a3
  002d4a:  be 6d 96 40            cmp.w -$69c0(a5), d7
  002d4e:  6d da                  blt.b $2d2a
  002d50:  a0 1c                  dc.w $a01c
  002d52:  a0 4c                  dc.w $a04c
  002d54:  4e ba 01 ca            jsr $2f20(pc)
  002d58:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  002d5c:  4e 75                  rts 
  002d5e:  4a 2d 96 3d            tst.b -$69c3(a5)
  002d62:  67 16                  beq.b $2d7a
  002d64:  4a 2d 96 3e            tst.b -$69c2(a5)
  002d68:  67 10                  beq.b $2d7a
  002d6a:  4e ba 2e a2            jsr $5c0e(pc)
  002d6e:  4e ba 28 48            jsr $55b8(pc)
  002d72:  42 2d 96 3e            clr.b -$69c2(a5)
  002d76:  a0 1c                  dc.w $a01c
  002d78:  a0 4c                  dc.w $a04c
  002d7a:  4e 75                  rts 
  002d7c:  4a 2d 96 3d            tst.b -$69c3(a5)
  002d80:  67 14                  beq.b $2d96
  002d82:  4a 2d 96 3e            tst.b -$69c2(a5)
  002d86:  66 0e                  bne.b $2d96
  002d88:  4e ba 28 56            jsr $55e0(pc)
  002d8c:  1b 7c 00 01 96 3e      move.b #$1, -$69c2(a5)
  002d92:  a0 1c                  dc.w $a01c
  002d94:  a0 4c                  dc.w $a04c
  002d96:  4e 75                  rts 
  002d98:  48 e7 03 38            movem.l d6-d7/a2-a4, -(a7)
  002d9c:  4a 2d 96 42            tst.b -$69be(a5)
  002da0:  66 00 00 b6            bne.w $2e58
  002da4:  4e ba ff b8            jsr $2d5e(pc)
  002da8:  4a 2d 96 45            tst.b -$69bb(a5)
  002dac:  67 0a                  beq.b $2db8
  002dae:  4a 2d 96 18            tst.b -$69e8(a5)
  002db2:  67 04                  beq.b $2db8
  002db4:  7e 00                  moveq #$0, d7
  002db6:  60 06                  bra.b $2dbe
  002db8:  7e 01                  moveq #$1, d7
  002dba:  42 2d 96 45            clr.b -$69bb(a5)
  002dbe:  3f 07                  move.w d7, -(a7)
  002dc0:  42 67                  clr.w -(a7)
  002dc2:  4e ba 18 a0            jsr $4664(pc)
  002dc6:  4a 80                  tst.l d0
  002dc8:  58 8f                  addq.l #$4, a7
  002dca:  66 00 00 8c            bne.w $2e58
  002dce:  2f 3c 00 0d 00 01      move.l #$d0001, -(a7)
  002dd4:  4e ba 18 8e            jsr $4664(pc)
  002dd8:  2e bc 00 0c 00 01      move.l #$c0001, (a7)
  002dde:  4e ba 18 84            jsr $4664(pc)
  002de2:  1b 7c 00 01 96 42      move.b #$1, -$69be(a5)
  002de8:  1b 7c 00 01 96 43      move.b #$1, -$69bd(a5)
  002dee:  7e 00                  moveq #$0, d7
  002df0:  45 ed a4 64            lea.l -$5b9c(a5), a2
  002df4:  47 ed a4 da            lea.l -$5b26(a5), a3
  002df8:  58 8f                  addq.l #$4, a7
  002dfa:  60 4a                  bra.b $2e46
  002dfc:  4a 2d 96 45            tst.b -$69bb(a5)
  002e00:  67 04                  beq.b $2e06
  002e02:  3c 13                  move.w (a3), d6
  002e04:  60 02                  bra.b $2e08
  002e06:  3c 12                  move.w (a2), d6
  002e08:  42 a7                  clr.l -(a7)
  002e0a:  2f 3c 53 4f 4e 47      move.l #$534f4e47, -(a7)
  002e10:  3f 06                  move.w d6, -(a7)
  002e12:  a9 a0                  dc.w $a9a0
  002e14:  28 5f                  movea.l (a7)+, a4
  002e16:  20 0c                  move.l a4, d0
  002e18:  67 26                  beq.b $2e40
  002e1a:  20 4c                  movea.l a4, a0
  002e1c:  a0 64                  dc.w $a064
  002e1e:  20 4c                  movea.l a4, a0
  002e20:  a0 29                  dc.w $a029
  002e22:  20 54                  movea.l (a4), a0
  002e24:  3c 10                  move.w (a0), d6
  002e26:  42 a7                  clr.l -(a7)
  002e28:  2f 3c 4d 49 44 49      move.l #$4d494449, -(a7)
  002e2e:  3f 06                  move.w d6, -(a7)
  002e30:  a9 a0                  dc.w $a9a0
  002e32:  28 5f                  movea.l (a7)+, a4
  002e34:  20 0c                  move.l a4, d0
  002e36:  67 08                  beq.b $2e40
  002e38:  20 4c                  movea.l a4, a0
  002e3a:  a0 64                  dc.w $a064
  002e3c:  20 4c                  movea.l a4, a0
  002e3e:  a0 29                  dc.w $a029
  002e40:  52 47                  addq.w #$1, d7
  002e42:  54 8a                  addq.l #$2, a2
  002e44:  54 8b                  addq.l #$2, a3
  002e46:  be 6d 96 46            cmp.w -$69ba(a5), d7
  002e4a:  6d b0                  blt.b $2dfc
  002e4c:  a0 1c                  dc.w $a01c
  002e4e:  a0 4c                  dc.w $a04c
  002e50:  4e ba 00 ac            jsr $2efe(pc)
  002e54:  4e ba ff 26            jsr $2d7c(pc)
  002e58:  4c df 1c c0            movem.l (a7)+, d6-d7/a2-a4
  002e5c:  4e 75                  rts 
  002e5e:  48 e7 07 38            movem.l d5-d7/a2-a4, -(a7)
  002e62:  4a 2d 96 42            tst.b -$69be(a5)
  002e66:  67 00 00 90            beq.w $2ef8
  002e6a:  4e ba fe f2            jsr $2d5e(pc)
  002e6e:  4e ba 00 b0            jsr $2f20(pc)
  002e72:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  002e78:  4e ba 17 ea            jsr $4664(pc)
  002e7c:  42 2d 96 42            clr.b -$69be(a5)
  002e80:  42 2d 96 43            clr.b -$69bd(a5)
  002e84:  42 17                  clr.b (a7)
  002e86:  a9 9b                  dc.w $a99b
  002e88:  7c 00                  moveq #$0, d6
  002e8a:  45 ed a4 64            lea.l -$5b9c(a5), a2
  002e8e:  47 ed a4 da            lea.l -$5b26(a5), a3
  002e92:  54 8f                  addq.l #$2, a7
  002e94:  60 4a                  bra.b $2ee0
  002e96:  4a 2d 96 45            tst.b -$69bb(a5)
  002e9a:  67 04                  beq.b $2ea0
  002e9c:  3a 13                  move.w (a3), d5
  002e9e:  60 02                  bra.b $2ea2
  002ea0:  3a 12                  move.w (a2), d5
  002ea2:  42 a7                  clr.l -(a7)
  002ea4:  2f 3c 53 4f 4e 47      move.l #$534f4e47, -(a7)
  002eaa:  3f 05                  move.w d5, -(a7)
  002eac:  a9 a0                  dc.w $a9a0
  002eae:  28 5f                  movea.l (a7)+, a4
  002eb0:  20 0c                  move.l a4, d0
  002eb2:  67 26                  beq.b $2eda
  002eb4:  20 4c                  movea.l a4, a0
  002eb6:  a0 2a                  dc.w $a02a
  002eb8:  20 4c                  movea.l a4, a0
  002eba:  a0 49                  dc.w $a049
  002ebc:  20 54                  movea.l (a4), a0
  002ebe:  3a 10                  move.w (a0), d5
  002ec0:  42 a7                  clr.l -(a7)
  002ec2:  2f 3c 4d 49 44 49      move.l #$4d494449, -(a7)
  002ec8:  3f 05                  move.w d5, -(a7)
  002eca:  a9 a0                  dc.w $a9a0
  002ecc:  28 5f                  movea.l (a7)+, a4
  002ece:  20 0c                  move.l a4, d0
  002ed0:  67 08                  beq.b $2eda
  002ed2:  20 4c                  movea.l a4, a0
  002ed4:  a0 2a                  dc.w $a02a
  002ed6:  20 4c                  movea.l a4, a0
  002ed8:  a0 49                  dc.w $a049
  002eda:  52 46                  addq.w #$1, d6
  002edc:  54 8a                  addq.l #$2, a2
  002ede:  54 8b                  addq.l #$2, a3
  002ee0:  bc 6d 96 46            cmp.w -$69ba(a5), d6
  002ee4:  6d b0                  blt.b $2e96
  002ee6:  1f 3c 00 01            move.b #$1, -(a7)
  002eea:  a9 9b                  dc.w $a99b
  002eec:  42 2d 96 45            clr.b -$69bb(a5)
  002ef0:  a0 1c                  dc.w $a01c
  002ef2:  a0 4c                  dc.w $a04c
  002ef4:  4e ba fe 86            jsr $2d7c(pc)
  002ef8:  4c df 1c e0            movem.l (a7)+, d5-d7/a2-a4
  002efc:  4e 75                  rts 
  002efe:  4a 2d 96 42            tst.b -$69be(a5)
  002f02:  67 1a                  beq.b $2f1e
  002f04:  4a 2d 96 43            tst.b -$69bd(a5)
  002f08:  67 14                  beq.b $2f1e
  002f0a:  2f 3c 00 05 00 00      move.l #$50000, -(a7)
  002f10:  4e ba 17 52            jsr $4664(pc)
  002f14:  42 2d 96 43            clr.b -$69bd(a5)
  002f18:  a0 1c                  dc.w $a01c
  002f1a:  a0 4c                  dc.w $a04c
  002f1c:  58 8f                  addq.l #$4, a7
  002f1e:  4e 75                  rts 
  002f20:  4a 2d 96 42            tst.b -$69be(a5)
  002f24:  67 1c                  beq.b $2f42
  002f26:  4a 2d 96 43            tst.b -$69bd(a5)
  002f2a:  66 16                  bne.b $2f42
  002f2c:  2f 3c 00 06 00 00      move.l #$60000, -(a7)
  002f32:  4e ba 17 30            jsr $4664(pc)
  002f36:  1b 7c 00 01 96 43      move.b #$1, -$69bd(a5)
  002f3c:  a0 1c                  dc.w $a01c
  002f3e:  a0 4c                  dc.w $a04c
  002f40:  58 8f                  addq.l #$4, a7
  002f42:  4e 75                  rts 
  002f44:  4e 56 00 00            link.w a6, #$0
  002f48:  48 e7 3f 00            movem.l d2-d7, -(a7)
  002f4c:  30 2e 00 0c            move.w $c(a6), d0
  002f50:  32 2e 00 0e            move.w $e(a6), d1
  002f54:  4a 6d ba 32            tst.w -$45ce(a5)
  002f58:  67 06                  beq.b $2f60
  002f5a:  44 41                  neg.w d1
  002f5c:  d2 6d a5 d0            add.w -$5a30(a5), d1
  002f60:  38 01                  move.w d1, d4
  002f62:  3a 00                  move.w d0, d5
  002f64:  3c 01                  move.w d1, d6
  002f66:  3e 00                  move.w d0, d7
  002f68:  32 2e 00 08            move.w $8(a6), d1
  002f6c:  e5 41                  asl.w #$2, d1
  002f6e:  41 ed a5 7a            lea.l -$5a86(a5), a0
  002f72:  20 70 10 00            movea.l (a0, d1.w), a0
  002f76:  20 08                  move.l a0, d0
  002f78:  67 50                  beq.b $2fca
  002f7a:  20 50                  movea.l (a0), a0
  002f7c:  43 ed a5 9a            lea.l -$5a66(a5), a1
  002f80:  22 71 10 00            movea.l (a1, d1.w), a1
  002f84:  20 09                  move.l a1, d0
  002f86:  67 42                  beq.b $2fca
  002f88:  22 51                  movea.l (a1), a1
  002f8a:  32 2e 00 0a            move.w $a(a6), d1
  002f8e:  e5 41                  asl.w #$2, d1
  002f90:  20 30 10 00            move.l (a0, d1.w), d0
  002f94:  6b 34                  bmi.b $2fca
  002f96:  41 f1 08 00            lea.l (a1, d0.l), a0
  002f9a:  30 18                  move.w (a0)+, d0
  002f9c:  32 18                  move.w (a0)+, d1
  002f9e:  34 18                  move.w (a0)+, d2
  002fa0:  36 18                  move.w (a0)+, d3
  002fa2:  4a 6e 00 10            tst.w $10(a6)
  002fa6:  6a 08                  bpl.b $2fb0
  002fa8:  da 42                  add.w d2, d5
  002faa:  de 42                  add.w d2, d7
  002fac:  9a 40                  sub.w d0, d5
  002fae:  60 06                  bra.b $2fb6
  002fb0:  9a 42                  sub.w d2, d5
  002fb2:  9e 42                  sub.w d2, d7
  002fb4:  de 40                  add.w d0, d7
  002fb6:  4a 6d ba 32            tst.w -$45ce(a5)
  002fba:  67 08                  beq.b $2fc4
  002fbc:  d8 43                  add.w d3, d4
  002fbe:  dc 43                  add.w d3, d6
  002fc0:  98 41                  sub.w d1, d4
  002fc2:  60 06                  bra.b $2fca
  002fc4:  98 43                  sub.w d3, d4
  002fc6:  9c 43                  sub.w d3, d6
  002fc8:  dc 41                  add.w d1, d6
  002fca:  3b 44 a5 f4            move.w d4, -$5a0c(a5)
  002fce:  3b 45 a5 f6            move.w d5, -$5a0a(a5)
  002fd2:  3b 46 a5 f8            move.w d6, -$5a08(a5)
  002fd6:  3b 47 a5 fa            move.w d7, -$5a06(a5)
  002fda:  4c df 00 fc            movem.l (a7)+, d2-d7
  002fde:  4e 5e                  unlk a6
  002fe0:  4e 75                  rts 
  002fe2:  4e 56 ff f8            link.w a6, #$fff8
  002fe6:  48 e7 3f 38            movem.l d2-d7/a2-a4, -(a7)
  002fea:  32 2e 00 08            move.w $8(a6), d1
  002fee:  e5 41                  asl.w #$2, d1
  002ff0:  41 ed a5 7a            lea.l -$5a86(a5), a0
  002ff4:  20 70 10 00            movea.l (a0, d1.w), a0
  002ff8:  20 08                  move.l a0, d0
  002ffa:  67 00 07 a2            beq.w $379e
  002ffe:  20 50                  movea.l (a0), a0
  003000:  43 ed a5 9a            lea.l -$5a66(a5), a1
  003004:  22 71 10 00            movea.l (a1, d1.w), a1
  003008:  20 09                  move.l a1, d0
  00300a:  67 00 07 92            beq.w $379e
  00300e:  22 51                  movea.l (a1), a1
  003010:  32 2e 00 0a            move.w $a(a6), d1
  003014:  e5 41                  asl.w #$2, d1
  003016:  20 30 10 00            move.l (a0, d1.w), d0
  00301a:  6b 00 07 82            bmi.w $379e
  00301e:  49 f1 08 00            lea.l (a1, d0.l), a4
  003022:  34 1c                  move.w (a4)+, d2
  003024:  36 1c                  move.w (a4)+, d3
  003026:  38 1c                  move.w (a4)+, d4
  003028:  3a 1c                  move.w (a4)+, d5
  00302a:  3c 2e 00 0c            move.w $c(a6), d6
  00302e:  32 02                  move.w d2, d1
  003030:  53 41                  subq.w #$1, d1
  003032:  4a 6e 00 10            tst.w $10(a6)
  003036:  6a 06                  bpl.b $303e
  003038:  53 44                  subq.w #$1, d4
  00303a:  44 44                  neg.w d4
  00303c:  44 41                  neg.w d1
  00303e:  9c 44                  sub.w d4, d6
  003040:  d2 46                  add.w d6, d1
  003042:  3e 2e 00 0e            move.w $e(a6), d7
  003046:  4a 6d ba 32            tst.w -$45ce(a5)
  00304a:  67 0c                  beq.b $3058
  00304c:  3e 2d a5 d0            move.w -$5a30(a5), d7
  003050:  53 47                  subq.w #$1, d7
  003052:  9e 6e 00 0e            sub.w $e(a6), d7
  003056:  44 45                  neg.w d5
  003058:  9e 45                  sub.w d5, d7
  00305a:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  00305e:  30 2d a2 da            move.w -$5d26(a5), d0
  003062:  c1 c7                  muls.w d7, d0
  003064:  d7 c0                  adda.l d0, a3
  003066:  30 06                  move.w d6, d0
  003068:  e8 40                  asr.w #$4, d0
  00306a:  d0 40                  add.w d0, d0
  00306c:  d6 c0                  adda.w d0, a3
  00306e:  30 2d a2 e4            move.w -$5d1c(a5), d0
  003072:  3a 2d a2 e8            move.w -$5d18(a5), d5
  003076:  9e 40                  sub.w d0, d7
  003078:  9a 40                  sub.w d0, d5
  00307a:  30 2d a2 e6            move.w -$5d1a(a5), d0
  00307e:  38 2d a2 ea            move.w -$5d16(a5), d4
  003082:  bc 40                  cmp.w d0, d6
  003084:  6d 16                  blt.b $309c
  003086:  bc 44                  cmp.w d4, d6
  003088:  6c 12                  bge.b $309c
  00308a:  b2 40                  cmp.w d0, d1
  00308c:  6d 0e                  blt.b $309c
  00308e:  b2 44                  cmp.w d4, d1
  003090:  6c 0a                  bge.b $309c
  003092:  4a 6e 00 10            tst.w $10(a6)
  003096:  6a 10                  bpl.b $30a8
  003098:  60 00 01 2e            bra.w $31c8
  00309c:  4a 6e 00 10            tst.w $10(a6)
  0030a0:  6a 00 02 92            bpl.w $3334
  0030a4:  6b 00 04 a2            bmi.w $3548
  0030a8:  53 43                  subq.w #$1, d3
  0030aa:  53 42                  subq.w #$1, d2
  0030ac:  38 02                  move.w d2, d4
  0030ae:  e8 44                  asr.w #$4, d4
  0030b0:  70 0f                  moveq #$f, d0
  0030b2:  c0 46                  and.w d6, d0
  0030b4:  d0 40                  add.w d0, d0
  0030b6:  48 43                  swap d3
  0030b8:  48 46                  swap d6
  0030ba:  48 47                  swap d7
  0030bc:  41 ed 9f 10            lea.l -$60f0(a5), a0
  0030c0:  36 30 00 00            move.w (a0, d0.w), d3
  0030c4:  41 ed 9f 50            lea.l -$60b0(a5), a0
  0030c8:  3c 30 00 00            move.w (a0, d0.w), d6
  0030cc:  3e 06                  move.w d6, d7
  0030ce:  46 47                  not.w d7
  0030d0:  48 47                  swap d7
  0030d2:  48 46                  swap d6
  0030d4:  48 43                  swap d3
  0030d6:  3c 2d a2 da            move.w -$5d26(a5), d6
  0030da:  0c 40 00 10            cmpi.w #$10, d0
  0030de:  6d 10                  blt.b $30f0
  0030e0:  6c 00 00 80            bge.w $3162
  0030e4:  30 02                  move.w d2, d0
  0030e6:  52 40                  addq.w #$1, d0
  0030e8:  d0 40                  add.w d0, d0
  0030ea:  d0 40                  add.w d0, d0
  0030ec:  d8 c0                  adda.w d0, a4
  0030ee:  60 48                  bra.b $3138
  0030f0:  20 4b                  movea.l a3, a0
  0030f2:  34 04                  move.w d4, d2
  0030f4:  be 45                  cmp.w d5, d7
  0030f6:  64 ec                  bcc.b $30e4
  0030f8:  48 43                  swap d3
  0030fa:  48 44                  swap d4
  0030fc:  48 45                  swap d5
  0030fe:  48 46                  swap d6
  003100:  48 47                  swap d7
  003102:  42 44                  clr.w d4
  003104:  46 44                  not.w d4
  003106:  42 45                  clr.w d5
  003108:  22 1c                  move.l (a4)+, d1
  00310a:  e6 b9                  ror.l d3, d1
  00310c:  30 10                  move.w (a0), d0
  00310e:  80 45                  or.w d5, d0
  003110:  c0 44                  and.w d4, d0
  003112:  38 01                  move.w d1, d4
  003114:  88 46                  or.w d6, d4
  003116:  c2 46                  and.w d6, d1
  003118:  80 41                  or.w d1, d0
  00311a:  48 41                  swap d1
  00311c:  3a 01                  move.w d1, d5
  00311e:  ca 47                  and.w d7, d5
  003120:  82 47                  or.w d7, d1
  003122:  c0 41                  and.w d1, d0
  003124:  30 c0                  move.w d0, (a0)+
  003126:  51 ca ff e0            dbra d2, $3108
  00312a:  8b 50                  or.w d5, (a0)
  00312c:  c9 50                  and.w d4, (a0)
  00312e:  48 47                  swap d7
  003130:  48 46                  swap d6
  003132:  48 45                  swap d5
  003134:  48 44                  swap d4
  003136:  48 43                  swap d3
  003138:  4a 6d ba 32            tst.w -$45ce(a5)
  00313c:  66 0c                  bne.b $314a
  00313e:  52 47                  addq.w #$1, d7
  003140:  d6 c6                  adda.w d6, a3
  003142:  51 cb ff ac            dbra d3, $30f0
  003146:  60 00 06 56            bra.w $379e
  00314a:  53 47                  subq.w #$1, d7
  00314c:  96 c6                  suba.w d6, a3
  00314e:  51 cb ff a0            dbra d3, $30f0
  003152:  60 00 06 4a            bra.w $379e
  003156:  30 02                  move.w d2, d0
  003158:  52 40                  addq.w #$1, d0
  00315a:  d0 40                  add.w d0, d0
  00315c:  d0 40                  add.w d0, d0
  00315e:  d8 c0                  adda.w d0, a4
  003160:  60 48                  bra.b $31aa
  003162:  20 4b                  movea.l a3, a0
  003164:  34 04                  move.w d4, d2
  003166:  be 45                  cmp.w d5, d7
  003168:  64 ec                  bcc.b $3156
  00316a:  48 43                  swap d3
  00316c:  48 44                  swap d4
  00316e:  48 45                  swap d5
  003170:  48 46                  swap d6
  003172:  48 47                  swap d7
  003174:  42 44                  clr.w d4
  003176:  46 44                  not.w d4
  003178:  42 45                  clr.w d5
  00317a:  22 1c                  move.l (a4)+, d1
  00317c:  e7 b9                  rol.l d3, d1
  00317e:  30 10                  move.w (a0), d0
  003180:  c0 44                  and.w d4, d0
  003182:  80 45                  or.w d5, d0
  003184:  3a 01                  move.w d1, d5
  003186:  ca 47                  and.w d7, d5
  003188:  82 47                  or.w d7, d1
  00318a:  c0 41                  and.w d1, d0
  00318c:  48 41                  swap d1
  00318e:  38 01                  move.w d1, d4
  003190:  88 46                  or.w d6, d4
  003192:  c2 46                  and.w d6, d1
  003194:  80 41                  or.w d1, d0
  003196:  30 c0                  move.w d0, (a0)+
  003198:  51 ca ff e0            dbra d2, $317a
  00319c:  c9 50                  and.w d4, (a0)
  00319e:  8b 50                  or.w d5, (a0)
  0031a0:  48 47                  swap d7
  0031a2:  48 46                  swap d6
  0031a4:  48 45                  swap d5
  0031a6:  48 44                  swap d4
  0031a8:  48 43                  swap d3
  0031aa:  4a 6d ba 32            tst.w -$45ce(a5)
  0031ae:  66 0c                  bne.b $31bc
  0031b0:  52 47                  addq.w #$1, d7
  0031b2:  d6 c6                  adda.w d6, a3
  0031b4:  51 cb ff ac            dbra d3, $3162
  0031b8:  60 00 05 e4            bra.w $379e
  0031bc:  53 47                  subq.w #$1, d7
  0031be:  96 c6                  suba.w d6, a3
  0031c0:  51 cb ff a0            dbra d3, $3162
  0031c4:  60 00 05 d8            bra.w $379e
  0031c8:  53 43                  subq.w #$1, d3
  0031ca:  53 42                  subq.w #$1, d2
  0031cc:  38 02                  move.w d2, d4
  0031ce:  e8 44                  asr.w #$4, d4
  0031d0:  70 0f                  moveq #$f, d0
  0031d2:  c0 46                  and.w d6, d0
  0031d4:  d0 40                  add.w d0, d0
  0031d6:  48 43                  swap d3
  0031d8:  48 46                  swap d6
  0031da:  48 47                  swap d7
  0031dc:  41 ed 9f 30            lea.l -$60d0(a5), a0
  0031e0:  36 30 00 00            move.w (a0, d0.w), d3
  0031e4:  41 ed 9f 70            lea.l -$6090(a5), a0
  0031e8:  3c 30 00 00            move.w (a0, d0.w), d6
  0031ec:  3e 06                  move.w d6, d7
  0031ee:  46 47                  not.w d7
  0031f0:  48 47                  swap d7
  0031f2:  48 46                  swap d6
  0031f4:  48 43                  swap d3
  0031f6:  45 ed 9f 90            lea.l -$6070(a5), a2
  0031fa:  3c 2d a2 da            move.w -$5d26(a5), d6
  0031fe:  0c 40 00 10            cmpi.w #$10, d0
  003202:  6d 10                  blt.b $3214
  003204:  6c 00 00 a4            bge.w $32aa
  003208:  30 02                  move.w d2, d0
  00320a:  52 40                  addq.w #$1, d0
  00320c:  d0 40                  add.w d0, d0
  00320e:  d0 40                  add.w d0, d0
  003210:  d8 c0                  adda.w d0, a4
  003212:  60 6c                  bra.b $3280
  003214:  20 4b                  movea.l a3, a0
  003216:  34 04                  move.w d4, d2
  003218:  be 45                  cmp.w d5, d7
  00321a:  64 ec                  bcc.b $3208
  00321c:  48 43                  swap d3
  00321e:  48 44                  swap d4
  003220:  48 45                  swap d5
  003222:  48 46                  swap d6
  003224:  48 47                  swap d7
  003226:  42 44                  clr.w d4
  003228:  46 44                  not.w d4
  00322a:  42 45                  clr.w d5
  00322c:  70 00                  moveq #$0, d0
  00322e:  22 1c                  move.l (a4)+, d1
  003230:  10 01                  move.b d1, d0
  003232:  12 32 00 00            move.b (a2, d0.w), d1
  003236:  e1 59                  rol.w #$8, d1
  003238:  10 01                  move.b d1, d0
  00323a:  12 32 00 00            move.b (a2, d0.w), d1
  00323e:  48 41                  swap d1
  003240:  10 01                  move.b d1, d0
  003242:  12 32 00 00            move.b (a2, d0.w), d1
  003246:  e1 59                  rol.w #$8, d1
  003248:  10 01                  move.b d1, d0
  00324a:  12 32 00 00            move.b (a2, d0.w), d1
  00324e:  48 41                  swap d1
  003250:  e6 b9                  ror.l d3, d1
  003252:  30 10                  move.w (a0), d0
  003254:  c0 44                  and.w d4, d0
  003256:  80 45                  or.w d5, d0
  003258:  3a 01                  move.w d1, d5
  00325a:  ca 47                  and.w d7, d5
  00325c:  82 47                  or.w d7, d1
  00325e:  c0 41                  and.w d1, d0
  003260:  48 41                  swap d1
  003262:  38 01                  move.w d1, d4
  003264:  88 46                  or.w d6, d4
  003266:  c2 46                  and.w d6, d1
  003268:  80 41                  or.w d1, d0
  00326a:  30 80                  move.w d0, (a0)
  00326c:  55 88                  subq.l #$2, a0
  00326e:  51 ca ff bc            dbra d2, $322c
  003272:  c9 50                  and.w d4, (a0)
  003274:  8b 50                  or.w d5, (a0)
  003276:  48 47                  swap d7
  003278:  48 46                  swap d6
  00327a:  48 45                  swap d5
  00327c:  48 44                  swap d4
  00327e:  48 43                  swap d3
  003280:  4a 6d ba 32            tst.w -$45ce(a5)
  003284:  66 0c                  bne.b $3292
  003286:  52 47                  addq.w #$1, d7
  003288:  d6 c6                  adda.w d6, a3
  00328a:  51 cb ff 88            dbra d3, $3214
  00328e:  60 00 05 0e            bra.w $379e
  003292:  53 47                  subq.w #$1, d7
  003294:  96 c6                  suba.w d6, a3
  003296:  51 cb ff 7c            dbra d3, $3214
  00329a:  60 00 05 02            bra.w $379e
  00329e:  30 02                  move.w d2, d0
  0032a0:  52 40                  addq.w #$1, d0
  0032a2:  d0 40                  add.w d0, d0
  0032a4:  d0 40                  add.w d0, d0
  0032a6:  d8 c0                  adda.w d0, a4
  0032a8:  60 6c                  bra.b $3316
  0032aa:  20 4b                  movea.l a3, a0
  0032ac:  34 04                  move.w d4, d2
  0032ae:  be 45                  cmp.w d5, d7
  0032b0:  64 ec                  bcc.b $329e
  0032b2:  48 43                  swap d3
  0032b4:  48 44                  swap d4
  0032b6:  48 45                  swap d5
  0032b8:  48 46                  swap d6
  0032ba:  48 47                  swap d7
  0032bc:  42 44                  clr.w d4
  0032be:  46 44                  not.w d4
  0032c0:  42 45                  clr.w d5
  0032c2:  70 00                  moveq #$0, d0
  0032c4:  22 1c                  move.l (a4)+, d1
  0032c6:  10 01                  move.b d1, d0
  0032c8:  12 32 00 00            move.b (a2, d0.w), d1
  0032cc:  e1 59                  rol.w #$8, d1
  0032ce:  10 01                  move.b d1, d0
  0032d0:  12 32 00 00            move.b (a2, d0.w), d1
  0032d4:  48 41                  swap d1
  0032d6:  10 01                  move.b d1, d0
  0032d8:  12 32 00 00            move.b (a2, d0.w), d1
  0032dc:  e1 59                  rol.w #$8, d1
  0032de:  10 01                  move.b d1, d0
  0032e0:  12 32 00 00            move.b (a2, d0.w), d1
  0032e4:  48 41                  swap d1
  0032e6:  e7 b9                  rol.l d3, d1
  0032e8:  30 10                  move.w (a0), d0
  0032ea:  80 45                  or.w d5, d0
  0032ec:  c0 44                  and.w d4, d0
  0032ee:  38 01                  move.w d1, d4
  0032f0:  88 46                  or.w d6, d4
  0032f2:  c2 46                  and.w d6, d1
  0032f4:  80 41                  or.w d1, d0
  0032f6:  48 41                  swap d1
  0032f8:  3a 01                  move.w d1, d5
  0032fa:  ca 47                  and.w d7, d5
  0032fc:  82 47                  or.w d7, d1
  0032fe:  c0 41                  and.w d1, d0
  003300:  30 80                  move.w d0, (a0)
  003302:  55 88                  subq.l #$2, a0
  003304:  51 ca ff bc            dbra d2, $32c2
  003308:  8b 50                  or.w d5, (a0)
  00330a:  c9 50                  and.w d4, (a0)
  00330c:  48 47                  swap d7
  00330e:  48 46                  swap d6
  003310:  48 45                  swap d5
  003312:  48 44                  swap d4
  003314:  48 43                  swap d3
  003316:  4a 6d ba 32            tst.w -$45ce(a5)
  00331a:  66 0c                  bne.b $3328
  00331c:  52 47                  addq.w #$1, d7
  00331e:  d6 c6                  adda.w d6, a3
  003320:  51 cb ff 88            dbra d3, $32aa
  003324:  60 00 04 78            bra.w $379e
  003328:  53 47                  subq.w #$1, d7
  00332a:  96 c6                  suba.w d6, a3
  00332c:  51 cb ff 7c            dbra d3, $32aa
  003330:  60 00 04 6c            bra.w $379e
  003334:  53 43                  subq.w #$1, d3
  003336:  53 42                  subq.w #$1, d2
  003338:  38 02                  move.w d2, d4
  00333a:  e8 44                  asr.w #$4, d4
  00333c:  34 06                  move.w d6, d2
  00333e:  e8 42                  asr.w #$4, d2
  003340:  d4 44                  add.w d4, d2
  003342:  32 2d a2 e6            move.w -$5d1a(a5), d1
  003346:  70 0f                  moveq #$f, d0
  003348:  c0 41                  and.w d1, d0
  00334a:  e8 41                  asr.w #$4, d1
  00334c:  3d 42 ff fe            move.w d2, -$2(a6)
  003350:  93 6e ff fe            sub.w d1, -$2(a6)
  003354:  d0 40                  add.w d0, d0
  003356:  41 ed 9f 50            lea.l -$60b0(a5), a0
  00335a:  3d 70 00 00 ff fc      move.w (a0, d0.w), -$4(a6)
  003360:  32 2d a2 ea            move.w -$5d16(a5), d1
  003364:  53 41                  subq.w #$1, d1
  003366:  70 0f                  moveq #$f, d0
  003368:  c0 41                  and.w d1, d0
  00336a:  e8 41                  asr.w #$4, d1
  00336c:  3d 42 ff fa            move.w d2, -$6(a6)
  003370:  93 6e ff fa            sub.w d1, -$6(a6)
  003374:  d0 40                  add.w d0, d0
  003376:  41 ed 9f 70            lea.l -$6090(a5), a0
  00337a:  3d 70 00 00 ff f8      move.w (a0, d0.w), -$8(a6)
  003380:  70 0f                  moveq #$f, d0
  003382:  c0 46                  and.w d6, d0
  003384:  d0 40                  add.w d0, d0
  003386:  48 43                  swap d3
  003388:  48 46                  swap d6
  00338a:  48 47                  swap d7
  00338c:  41 ed 9f 10            lea.l -$60f0(a5), a0
  003390:  36 30 00 00            move.w (a0, d0.w), d3
  003394:  41 ed 9f 50            lea.l -$60b0(a5), a0
  003398:  3c 30 00 00            move.w (a0, d0.w), d6
  00339c:  3e 06                  move.w d6, d7
  00339e:  46 47                  not.w d7
  0033a0:  48 47                  swap d7
  0033a2:  48 46                  swap d6
  0033a4:  48 43                  swap d3
  0033a6:  3c 2d a2 da            move.w -$5d26(a5), d6
  0033aa:  0c 40 00 10            cmpi.w #$10, d0
  0033ae:  6d 12                  blt.b $33c2
  0033b0:  6c 00 00 da            bge.w $348c
  0033b4:  30 02                  move.w d2, d0
  0033b6:  52 40                  addq.w #$1, d0
  0033b8:  d0 40                  add.w d0, d0
  0033ba:  d0 40                  add.w d0, d0
  0033bc:  d8 c0                  adda.w d0, a4
  0033be:  60 00 00 a0            bra.w $3460
  0033c2:  20 4b                  movea.l a3, a0
  0033c4:  34 04                  move.w d4, d2
  0033c6:  be 45                  cmp.w d5, d7
  0033c8:  64 ea                  bcc.b $33b4
  0033ca:  48 43                  swap d3
  0033cc:  48 44                  swap d4
  0033ce:  48 45                  swap d5
  0033d0:  48 46                  swap d6
  0033d2:  48 47                  swap d7
  0033d4:  42 44                  clr.w d4
  0033d6:  46 44                  not.w d4
  0033d8:  42 45                  clr.w d5
  0033da:  22 1c                  move.l (a4)+, d1
  0033dc:  e6 b9                  ror.l d3, d1
  0033de:  30 10                  move.w (a0), d0
  0033e0:  80 45                  or.w d5, d0
  0033e2:  c0 44                  and.w d4, d0
  0033e4:  38 01                  move.w d1, d4
  0033e6:  88 46                  or.w d6, d4
  0033e8:  c2 46                  and.w d6, d1
  0033ea:  80 41                  or.w d1, d0
  0033ec:  48 41                  swap d1
  0033ee:  3a 01                  move.w d1, d5
  0033f0:  ca 47                  and.w d7, d5
  0033f2:  82 47                  or.w d7, d1
  0033f4:  c0 41                  and.w d1, d0
  0033f6:  b4 6e ff fe            cmp.w -$2(a6), d2
  0033fa:  6d 0e                  blt.b $340a
  0033fc:  6e 22                  bgt.b $3420
  0033fe:  32 2e ff fc            move.w -$4(a6), d1
  003402:  c0 41                  and.w d1, d0
  003404:  46 41                  not.w d1
  003406:  c2 50                  and.w (a0), d1
  003408:  80 41                  or.w d1, d0
  00340a:  b4 6e ff fa            cmp.w -$6(a6), d2
  00340e:  6e 0e                  bgt.b $341e
  003410:  6d 0e                  blt.b $3420
  003412:  32 2e ff f8            move.w -$8(a6), d1
  003416:  c0 41                  and.w d1, d0
  003418:  46 41                  not.w d1
  00341a:  c2 50                  and.w (a0), d1
  00341c:  80 41                  or.w d1, d0
  00341e:  30 80                  move.w d0, (a0)
  003420:  54 88                  addq.l #$2, a0
  003422:  51 ca ff b6            dbra d2, $33da
  003426:  30 10                  move.w (a0), d0
  003428:  80 45                  or.w d5, d0
  00342a:  c0 44                  and.w d4, d0
  00342c:  b4 6e ff fe            cmp.w -$2(a6), d2
  003430:  6d 0e                  blt.b $3440
  003432:  6e 22                  bgt.b $3456
  003434:  32 2e ff fc            move.w -$4(a6), d1
  003438:  c0 41                  and.w d1, d0
  00343a:  46 41                  not.w d1
  00343c:  c2 50                  and.w (a0), d1
  00343e:  80 41                  or.w d1, d0
  003440:  b4 6e ff fa            cmp.w -$6(a6), d2
  003444:  6e 0e                  bgt.b $3454
  003446:  6d 0e                  blt.b $3456
  003448:  32 2e ff f8            move.w -$8(a6), d1
  00344c:  c0 41                  and.w d1, d0
  00344e:  46 41                  not.w d1
  003450:  c2 50                  and.w (a0), d1
  003452:  80 41                  or.w d1, d0
  003454:  30 80                  move.w d0, (a0)
  003456:  48 47                  swap d7
  003458:  48 46                  swap d6
  00345a:  48 45                  swap d5
  00345c:  48 44                  swap d4
  00345e:  48 43                  swap d3
  003460:  4a 6d ba 32            tst.w -$45ce(a5)
  003464:  66 0c                  bne.b $3472
  003466:  52 47                  addq.w #$1, d7
  003468:  d6 c6                  adda.w d6, a3
  00346a:  51 cb ff 56            dbra d3, $33c2
  00346e:  60 00 03 2e            bra.w $379e
  003472:  53 47                  subq.w #$1, d7
  003474:  96 c6                  suba.w d6, a3
  003476:  51 cb ff 4a            dbra d3, $33c2
  00347a:  60 00 03 22            bra.w $379e
  00347e:  30 02                  move.w d2, d0
  003480:  52 40                  addq.w #$1, d0
  003482:  d0 40                  add.w d0, d0
  003484:  d0 40                  add.w d0, d0
  003486:  d8 c0                  adda.w d0, a4
  003488:  60 00 00 a0            bra.w $352a
  00348c:  20 4b                  movea.l a3, a0
  00348e:  34 04                  move.w d4, d2
  003490:  be 45                  cmp.w d5, d7
  003492:  64 ea                  bcc.b $347e
  003494:  48 43                  swap d3
  003496:  48 44                  swap d4
  003498:  48 45                  swap d5
  00349a:  48 46                  swap d6
  00349c:  48 47                  swap d7
  00349e:  42 44                  clr.w d4
  0034a0:  46 44                  not.w d4
  0034a2:  42 45                  clr.w d5
  0034a4:  22 1c                  move.l (a4)+, d1
  0034a6:  e7 b9                  rol.l d3, d1
  0034a8:  30 10                  move.w (a0), d0
  0034aa:  c0 44                  and.w d4, d0
  0034ac:  80 45                  or.w d5, d0
  0034ae:  3a 01                  move.w d1, d5
  0034b0:  ca 47                  and.w d7, d5
  0034b2:  82 47                  or.w d7, d1
  0034b4:  c0 41                  and.w d1, d0
  0034b6:  48 41                  swap d1
  0034b8:  38 01                  move.w d1, d4
  0034ba:  88 46                  or.w d6, d4
  0034bc:  c2 46                  and.w d6, d1
  0034be:  80 41                  or.w d1, d0
  0034c0:  b4 6e ff fe            cmp.w -$2(a6), d2
  0034c4:  6d 0e                  blt.b $34d4
  0034c6:  6e 22                  bgt.b $34ea
  0034c8:  32 2e ff fc            move.w -$4(a6), d1
  0034cc:  c0 41                  and.w d1, d0
  0034ce:  46 41                  not.w d1
  0034d0:  c2 50                  and.w (a0), d1
  0034d2:  80 41                  or.w d1, d0
  0034d4:  b4 6e ff fa            cmp.w -$6(a6), d2
  0034d8:  6e 0e                  bgt.b $34e8
  0034da:  6d 0e                  blt.b $34ea
  0034dc:  32 2e ff f8            move.w -$8(a6), d1
  0034e0:  c0 41                  and.w d1, d0
  0034e2:  46 41                  not.w d1
  0034e4:  c2 50                  and.w (a0), d1
  0034e6:  80 41                  or.w d1, d0
  0034e8:  30 80                  move.w d0, (a0)
  0034ea:  54 88                  addq.l #$2, a0
  0034ec:  51 ca ff b6            dbra d2, $34a4
  0034f0:  30 10                  move.w (a0), d0
  0034f2:  c0 44                  and.w d4, d0
  0034f4:  80 45                  or.w d5, d0
  0034f6:  b4 6e ff fe            cmp.w -$2(a6), d2
  0034fa:  6d 0e                  blt.b $350a
  0034fc:  6e 22                  bgt.b $3520
  0034fe:  32 2e ff fc            move.w -$4(a6), d1
  003502:  c0 41                  and.w d1, d0
  003504:  46 41                  not.w d1
  003506:  c2 50                  and.w (a0), d1
  003508:  80 41                  or.w d1, d0
  00350a:  b4 6e ff fa            cmp.w -$6(a6), d2
  00350e:  6e 0e                  bgt.b $351e
  003510:  6d 0e                  blt.b $3520
  003512:  32 2e ff f8            move.w -$8(a6), d1
  003516:  c0 41                  and.w d1, d0
  003518:  46 41                  not.w d1
  00351a:  c2 50                  and.w (a0), d1
  00351c:  80 41                  or.w d1, d0
  00351e:  30 80                  move.w d0, (a0)
  003520:  48 47                  swap d7
  003522:  48 46                  swap d6
  003524:  48 45                  swap d5
  003526:  48 44                  swap d4
  003528:  48 43                  swap d3
  00352a:  4a 6d ba 32            tst.w -$45ce(a5)
  00352e:  66 0c                  bne.b $353c
  003530:  52 47                  addq.w #$1, d7
  003532:  d6 c6                  adda.w d6, a3
  003534:  51 cb ff 56            dbra d3, $348c
  003538:  60 00 02 64            bra.w $379e
  00353c:  53 47                  subq.w #$1, d7
  00353e:  96 c6                  suba.w d6, a3
  003540:  51 cb ff 4a            dbra d3, $348c
  003544:  60 00 02 58            bra.w $379e
  003548:  53 43                  subq.w #$1, d3
  00354a:  53 42                  subq.w #$1, d2
  00354c:  38 02                  move.w d2, d4
  00354e:  e8 44                  asr.w #$4, d4
  003550:  34 06                  move.w d6, d2
  003552:  e8 42                  asr.w #$4, d2
  003554:  94 44                  sub.w d4, d2
  003556:  32 2d a2 e6            move.w -$5d1a(a5), d1
  00355a:  70 0f                  moveq #$f, d0
  00355c:  c0 41                  and.w d1, d0
  00355e:  e8 41                  asr.w #$4, d1
  003560:  3d 41 ff fe            move.w d1, -$2(a6)
  003564:  95 6e ff fe            sub.w d2, -$2(a6)
  003568:  d0 40                  add.w d0, d0
  00356a:  41 ed 9f 50            lea.l -$60b0(a5), a0
  00356e:  3d 70 00 00 ff fc      move.w (a0, d0.w), -$4(a6)
  003574:  32 2d a2 ea            move.w -$5d16(a5), d1
  003578:  53 41                  subq.w #$1, d1
  00357a:  70 0f                  moveq #$f, d0
  00357c:  c0 41                  and.w d1, d0
  00357e:  e8 41                  asr.w #$4, d1
  003580:  3d 41 ff fa            move.w d1, -$6(a6)
  003584:  95 6e ff fa            sub.w d2, -$6(a6)
  003588:  d0 40                  add.w d0, d0
  00358a:  41 ed 9f 70            lea.l -$6090(a5), a0
  00358e:  3d 70 00 00 ff f8      move.w (a0, d0.w), -$8(a6)
  003594:  70 0f                  moveq #$f, d0
  003596:  c0 46                  and.w d6, d0
  003598:  d0 40                  add.w d0, d0
  00359a:  48 43                  swap d3
  00359c:  48 46                  swap d6
  00359e:  48 47                  swap d7
  0035a0:  41 ed 9f 30            lea.l -$60d0(a5), a0
  0035a4:  36 30 00 00            move.w (a0, d0.w), d3
  0035a8:  41 ed 9f 70            lea.l -$6090(a5), a0
  0035ac:  3c 30 00 00            move.w (a0, d0.w), d6
  0035b0:  3e 06                  move.w d6, d7
  0035b2:  46 47                  not.w d7
  0035b4:  48 47                  swap d7
  0035b6:  48 46                  swap d6
  0035b8:  48 43                  swap d3
  0035ba:  45 ed 9f 90            lea.l -$6070(a5), a2
  0035be:  3c 2d a2 da            move.w -$5d26(a5), d6
  0035c2:  0c 40 00 10            cmpi.w #$10, d0
  0035c6:  6d 12                  blt.b $35da
  0035c8:  6c 00 00 fc            bge.w $36c6
  0035cc:  30 02                  move.w d2, d0
  0035ce:  52 40                  addq.w #$1, d0
  0035d0:  d0 40                  add.w d0, d0
  0035d2:  d0 40                  add.w d0, d0
  0035d4:  d8 c0                  adda.w d0, a4
  0035d6:  60 00 00 c2            bra.w $369a
  0035da:  20 4b                  movea.l a3, a0
  0035dc:  34 04                  move.w d4, d2
  0035de:  be 45                  cmp.w d5, d7
  0035e0:  64 ea                  bcc.b $35cc
  0035e2:  48 43                  swap d3
  0035e4:  48 44                  swap d4
  0035e6:  48 45                  swap d5
  0035e8:  48 46                  swap d6
  0035ea:  48 47                  swap d7
  0035ec:  42 44                  clr.w d4
  0035ee:  46 44                  not.w d4
  0035f0:  42 45                  clr.w d5
  0035f2:  70 00                  moveq #$0, d0
  0035f4:  22 1c                  move.l (a4)+, d1
  0035f6:  10 01                  move.b d1, d0
  0035f8:  12 32 00 00            move.b (a2, d0.w), d1
  0035fc:  e1 59                  rol.w #$8, d1
  0035fe:  10 01                  move.b d1, d0
  003600:  12 32 00 00            move.b (a2, d0.w), d1
  003604:  48 41                  swap d1
  003606:  10 01                  move.b d1, d0
  003608:  12 32 00 00            move.b (a2, d0.w), d1
  00360c:  e1 59                  rol.w #$8, d1
  00360e:  10 01                  move.b d1, d0
  003610:  12 32 00 00            move.b (a2, d0.w), d1
  003614:  48 41                  swap d1
  003616:  e6 b9                  ror.l d3, d1
  003618:  30 10                  move.w (a0), d0
  00361a:  c0 44                  and.w d4, d0
  00361c:  80 45                  or.w d5, d0
  00361e:  3a 01                  move.w d1, d5
  003620:  ca 47                  and.w d7, d5
  003622:  82 47                  or.w d7, d1
  003624:  c0 41                  and.w d1, d0
  003626:  48 41                  swap d1
  003628:  38 01                  move.w d1, d4
  00362a:  88 46                  or.w d6, d4
  00362c:  c2 46                  and.w d6, d1
  00362e:  80 41                  or.w d1, d0
  003630:  b4 6e ff fa            cmp.w -$6(a6), d2
  003634:  6d 0e                  blt.b $3644
  003636:  6e 22                  bgt.b $365a
  003638:  32 2e ff f8            move.w -$8(a6), d1
  00363c:  c0 41                  and.w d1, d0
  00363e:  46 41                  not.w d1
  003640:  c2 50                  and.w (a0), d1
  003642:  80 41                  or.w d1, d0
  003644:  b4 6e ff fe            cmp.w -$2(a6), d2
  003648:  6e 0e                  bgt.b $3658
  00364a:  6d 0e                  blt.b $365a
  00364c:  32 2e ff fc            move.w -$4(a6), d1
  003650:  c0 41                  and.w d1, d0
  003652:  46 41                  not.w d1
  003654:  c2 50                  and.w (a0), d1
  003656:  80 41                  or.w d1, d0
  003658:  30 80                  move.w d0, (a0)
  00365a:  55 88                  subq.l #$2, a0
  00365c:  51 ca ff 94            dbra d2, $35f2
  003660:  30 10                  move.w (a0), d0
  003662:  c0 44                  and.w d4, d0
  003664:  80 45                  or.w d5, d0
  003666:  b4 6e ff fa            cmp.w -$6(a6), d2
  00366a:  6d 0e                  blt.b $367a
  00366c:  6e 22                  bgt.b $3690
  00366e:  32 2e ff f8            move.w -$8(a6), d1
  003672:  c0 41                  and.w d1, d0
  003674:  46 41                  not.w d1
  003676:  c2 50                  and.w (a0), d1
  003678:  80 41                  or.w d1, d0
  00367a:  b4 6e ff fe            cmp.w -$2(a6), d2
  00367e:  6e 0e                  bgt.b $368e
  003680:  6d 0e                  blt.b $3690
  003682:  32 2e ff fc            move.w -$4(a6), d1
  003686:  c0 41                  and.w d1, d0
  003688:  46 41                  not.w d1
  00368a:  c2 50                  and.w (a0), d1
  00368c:  80 41                  or.w d1, d0
  00368e:  30 80                  move.w d0, (a0)
  003690:  48 47                  swap d7
  003692:  48 46                  swap d6
  003694:  48 45                  swap d5
  003696:  48 44                  swap d4
  003698:  48 43                  swap d3
  00369a:  4a 6d ba 32            tst.w -$45ce(a5)
  00369e:  66 0c                  bne.b $36ac
  0036a0:  52 47                  addq.w #$1, d7
  0036a2:  d6 c6                  adda.w d6, a3
  0036a4:  51 cb ff 34            dbra d3, $35da
  0036a8:  60 00 00 f4            bra.w $379e
  0036ac:  53 47                  subq.w #$1, d7
  0036ae:  96 c6                  suba.w d6, a3
  0036b0:  51 cb ff 28            dbra d3, $35da
  0036b4:  60 00 00 e8            bra.w $379e
  0036b8:  30 02                  move.w d2, d0
  0036ba:  52 40                  addq.w #$1, d0
  0036bc:  d0 40                  add.w d0, d0
  0036be:  d0 40                  add.w d0, d0
  0036c0:  d8 c0                  adda.w d0, a4
  0036c2:  60 00 00 c2            bra.w $3786
  0036c6:  20 4b                  movea.l a3, a0
  0036c8:  34 04                  move.w d4, d2
  0036ca:  be 45                  cmp.w d5, d7
  0036cc:  64 ea                  bcc.b $36b8
  0036ce:  48 43                  swap d3
  0036d0:  48 44                  swap d4
  0036d2:  48 45                  swap d5
  0036d4:  48 46                  swap d6
  0036d6:  48 47                  swap d7
  0036d8:  42 44                  clr.w d4
  0036da:  46 44                  not.w d4
  0036dc:  42 45                  clr.w d5
  0036de:  70 00                  moveq #$0, d0
  0036e0:  22 1c                  move.l (a4)+, d1
  0036e2:  10 01                  move.b d1, d0
  0036e4:  12 32 00 00            move.b (a2, d0.w), d1
  0036e8:  e1 59                  rol.w #$8, d1
  0036ea:  10 01                  move.b d1, d0
  0036ec:  12 32 00 00            move.b (a2, d0.w), d1
  0036f0:  48 41                  swap d1
  0036f2:  10 01                  move.b d1, d0
  0036f4:  12 32 00 00            move.b (a2, d0.w), d1
  0036f8:  e1 59                  rol.w #$8, d1
  0036fa:  10 01                  move.b d1, d0
  0036fc:  12 32 00 00            move.b (a2, d0.w), d1
  003700:  48 41                  swap d1
  003702:  e7 b9                  rol.l d3, d1
  003704:  30 10                  move.w (a0), d0
  003706:  80 45                  or.w d5, d0
  003708:  c0 44                  and.w d4, d0
  00370a:  38 01                  move.w d1, d4
  00370c:  88 46                  or.w d6, d4
  00370e:  c2 46                  and.w d6, d1
  003710:  80 41                  or.w d1, d0
  003712:  48 41                  swap d1
  003714:  3a 01                  move.w d1, d5
  003716:  ca 47                  and.w d7, d5
  003718:  82 47                  or.w d7, d1
  00371a:  c0 41                  and.w d1, d0
  00371c:  b4 6e ff fa            cmp.w -$6(a6), d2
  003720:  6d 0e                  blt.b $3730
  003722:  6e 22                  bgt.b $3746
  003724:  32 2e ff f8            move.w -$8(a6), d1
  003728:  c0 41                  and.w d1, d0
  00372a:  46 41                  not.w d1
  00372c:  c2 50                  and.w (a0), d1
  00372e:  80 41                  or.w d1, d0
  003730:  b4 6e ff fe            cmp.w -$2(a6), d2
  003734:  6e 0e                  bgt.b $3744
  003736:  6d 0e                  blt.b $3746
  003738:  32 2e ff fc            move.w -$4(a6), d1
  00373c:  c0 41                  and.w d1, d0
  00373e:  46 41                  not.w d1
  003740:  c2 50                  and.w (a0), d1
  003742:  80 41                  or.w d1, d0
  003744:  30 80                  move.w d0, (a0)
  003746:  55 88                  subq.l #$2, a0
  003748:  51 ca ff 94            dbra d2, $36de
  00374c:  30 10                  move.w (a0), d0
  00374e:  80 45                  or.w d5, d0
  003750:  c0 44                  and.w d4, d0
  003752:  b4 6e ff fa            cmp.w -$6(a6), d2
  003756:  6d 0e                  blt.b $3766
  003758:  6e 22                  bgt.b $377c
  00375a:  32 2e ff f8            move.w -$8(a6), d1
  00375e:  c0 41                  and.w d1, d0
  003760:  46 41                  not.w d1
  003762:  c2 50                  and.w (a0), d1
  003764:  80 41                  or.w d1, d0
  003766:  b4 6e ff fe            cmp.w -$2(a6), d2
  00376a:  6e 0e                  bgt.b $377a
  00376c:  6d 0e                  blt.b $377c
  00376e:  32 2e ff fc            move.w -$4(a6), d1
  003772:  c0 41                  and.w d1, d0
  003774:  46 41                  not.w d1
  003776:  c2 50                  and.w (a0), d1
  003778:  80 41                  or.w d1, d0
  00377a:  30 80                  move.w d0, (a0)
  00377c:  48 47                  swap d7
  00377e:  48 46                  swap d6
  003780:  48 45                  swap d5
  003782:  48 44                  swap d4
  003784:  48 43                  swap d3
  003786:  4a 6d ba 32            tst.w -$45ce(a5)
  00378a:  66 0a                  bne.b $3796
  00378c:  52 47                  addq.w #$1, d7
  00378e:  d6 c6                  adda.w d6, a3
  003790:  51 cb ff 34            dbra d3, $36c6
  003794:  60 08                  bra.b $379e
  003796:  53 47                  subq.w #$1, d7
  003798:  96 c6                  suba.w d6, a3
  00379a:  51 cb ff 2a            dbra d3, $36c6
  00379e:  4c df 1c fc            movem.l (a7)+, d2-d7/a2-a4
  0037a2:  4e 5e                  unlk a6
  0037a4:  4e 75                  rts 
  0037a6:  4e 56 00 00            link.w a6, #$0
  0037aa:  48 e7 3f 10            movem.l d2-d7/a3, -(a7)
  0037ae:  20 6e 00 08            movea.l $8(a6), a0
  0037b2:  38 18                  move.w (a0)+, d4
  0037b4:  3a 18                  move.w (a0)+, d5
  0037b6:  3c 18                  move.w (a0)+, d6
  0037b8:  3e 18                  move.w (a0)+, d7
  0037ba:  34 06                  move.w d6, d2
  0037bc:  94 44                  sub.w d4, d2
  0037be:  30 04                  move.w d4, d0
  0037c0:  72 07                  moveq #$7, d1
  0037c2:  38 05                  move.w d5, d4
  0037c4:  e6 44                  asr.w #$3, d4
  0037c6:  ca 41                  and.w d1, d5
  0037c8:  53 47                  subq.w #$1, d7
  0037ca:  3c 07                  move.w d7, d6
  0037cc:  e6 46                  asr.w #$3, d6
  0037ce:  ce 41                  and.w d1, d7
  0037d0:  9c 44                  sub.w d4, d6
  0037d2:  53 46                  subq.w #$1, d6
  0037d4:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0037d8:  36 2d a2 da            move.w -$5d26(a5), d3
  0037dc:  c1 c3                  muls.w d3, d0
  0037de:  d7 c0                  adda.l d0, a3
  0037e0:  d6 c4                  adda.w d4, a3
  0037e2:  70 00                  moveq #$0, d0
  0037e4:  10 2e 00 0c            move.b $c(a6), d0
  0037e8:  67 3a                  beq.b $3824
  0037ea:  1a 3b 50 28            move.b $3814(pc, d5.w), d5
  0037ee:  1e 3b 70 2c            move.b $381c(pc, d7.w), d7
  0037f2:  60 1a                  bra.b $380e
  0037f4:  12 05                  move.b d5, d1
  0037f6:  20 4b                  movea.l a3, a0
  0037f8:  30 06                  move.w d6, d0
  0037fa:  6b 0c                  bmi.b $3808
  0037fc:  83 18                  or.b d1, (a0)+
  0037fe:  72 ff                  moveq #$ff, d1
  003800:  60 02                  bra.b $3804
  003802:  10 c1                  move.b d1, (a0)+
  003804:  51 c8 ff fc            dbra d0, $3802
  003808:  c2 07                  and.b d7, d1
  00380a:  83 18                  or.b d1, (a0)+
  00380c:  d6 c3                  adda.w d3, a3
  00380e:  51 ca ff e4            dbra d2, $37f4
  003812:  60 4a                  bra.b $385e
  003814:  ff 7f                  dc.w $ff7f
  003816:  3f 1f                  move.w (a7)+, -(a7)
  003818:  0f 07                  btst.l d7, d7
  00381a:  03 01                  btst.l d1, d1
  00381c:  80 c0                  divu.w d0, d0
  00381e:  e0 f0 f8 fc            asr.w -$4(a0, a7.l)
  003822:  fe ff                  dc.w $feff
  003824:  1a 3b 50 28            move.b $384e(pc, d5.w), d5
  003828:  1e 3b 70 2c            move.b $3856(pc, d7.w), d7
  00382c:  60 1a                  bra.b $3848
  00382e:  12 05                  move.b d5, d1
  003830:  20 4b                  movea.l a3, a0
  003832:  30 06                  move.w d6, d0
  003834:  6b 0c                  bmi.b $3842
  003836:  c3 18                  and.b d1, (a0)+
  003838:  72 00                  moveq #$0, d1
  00383a:  60 02                  bra.b $383e
  00383c:  10 c1                  move.b d1, (a0)+
  00383e:  51 c8 ff fc            dbra d0, $383c
  003842:  82 07                  or.b d7, d1
  003844:  c3 18                  and.b d1, (a0)+
  003846:  d6 c3                  adda.w d3, a3
  003848:  51 ca ff e4            dbra d2, $382e
  00384c:  60 10                  bra.b $385e
  00384e:  00 80 c0 e0 f0 f8      ori.l #$c0e0f0f8, d0
  003854:  fc fe                  dc.w $fcfe
  003856:  7f 3f                  dc.w $7f3f
  003858:  1f 0f                  dc.w $1f0f
  00385a:  07 03                  btst.l d3, d3
  00385c:  01 00                  btst.l d0, d0
  00385e:  4c df 08 fc            movem.l (a7)+, d2-d7/a3
  003862:  4e 5e                  unlk a6
  003864:  4e 75                  rts 
  003866:  4e 56 00 00            link.w a6, #$0
  00386a:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  00386e:  99 cc                  suba.l a4, a4
  003870:  20 6e 00 08            movea.l $8(a6), a0
  003874:  38 18                  move.w (a0)+, d4
  003876:  3a 18                  move.w (a0)+, d5
  003878:  3c 18                  move.w (a0)+, d6
  00387a:  3e 18                  move.w (a0)+, d7
  00387c:  9c 44                  sub.w d4, d6
  00387e:  63 00 00 c2            bls.w $3942
  003882:  e8 45                  asr.w #$4, d5
  003884:  06 47 00 0f            addi.w #$f, d7
  003888:  e8 47                  asr.w #$4, d7
  00388a:  9e 45                  sub.w d5, d7
  00388c:  63 00 00 b4            bls.w $3942
  003890:  30 06                  move.w d6, d0
  003892:  c0 c7                  mulu.w d7, d0
  003894:  d0 80                  add.l d0, d0
  003896:  a1 22                  dc.w $a122
  003898:  4a 40                  tst.w d0
  00389a:  66 00 00 a6            bne.w $3942
  00389e:  28 48                  movea.l a0, a4
  0038a0:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0038a4:  36 2d a2 da            move.w -$5d26(a5), d3
  0038a8:  c9 c3                  muls.w d3, d4
  0038aa:  d7 c4                  adda.l d4, a3
  0038ac:  da 45                  add.w d5, d5
  0038ae:  d6 c5                  adda.w d5, a3
  0038b0:  20 54                  movea.l (a4), a0
  0038b2:  53 46                  subq.w #$1, d6
  0038b4:  53 47                  subq.w #$1, d7
  0038b6:  70 07                  moveq #$7, d0
  0038b8:  c0 47                  and.w d7, d0
  0038ba:  d0 40                  add.w d0, d0
  0038bc:  4e fb 00 02            jmp $38c0(pc, d0.w)
  0038c0:  60 0e                  bra.b $38d0
  0038c2:  60 16                  bra.b $38da
  0038c4:  60 1e                  bra.b $38e4
  0038c6:  60 2a                  bra.b $38f2
  0038c8:  60 36                  bra.b $3900
  0038ca:  60 44                  bra.b $3910
  0038cc:  60 52                  bra.b $3920
  0038ce:  60 62                  bra.b $3932
  0038d0:  30 d3                  move.w (a3), (a0)+
  0038d2:  d6 c3                  adda.w d3, a3
  0038d4:  51 ce ff fa            dbra d6, $38d0
  0038d8:  60 68                  bra.b $3942
  0038da:  20 d3                  move.l (a3), (a0)+
  0038dc:  d6 c3                  adda.w d3, a3
  0038de:  51 ce ff fa            dbra d6, $38da
  0038e2:  60 5e                  bra.b $3942
  0038e4:  22 4b                  movea.l a3, a1
  0038e6:  20 d9                  move.l (a1)+, (a0)+
  0038e8:  30 d9                  move.w (a1)+, (a0)+
  0038ea:  d6 c3                  adda.w d3, a3
  0038ec:  51 ce ff f6            dbra d6, $38e4
  0038f0:  60 50                  bra.b $3942
  0038f2:  22 4b                  movea.l a3, a1
  0038f4:  20 d9                  move.l (a1)+, (a0)+
  0038f6:  20 d9                  move.l (a1)+, (a0)+
  0038f8:  d6 c3                  adda.w d3, a3
  0038fa:  51 ce ff f6            dbra d6, $38f2
  0038fe:  60 42                  bra.b $3942
  003900:  22 4b                  movea.l a3, a1
  003902:  20 d9                  move.l (a1)+, (a0)+
  003904:  20 d9                  move.l (a1)+, (a0)+
  003906:  30 d9                  move.w (a1)+, (a0)+
  003908:  d6 c3                  adda.w d3, a3
  00390a:  51 ce ff f4            dbra d6, $3900
  00390e:  60 32                  bra.b $3942
  003910:  22 4b                  movea.l a3, a1
  003912:  20 d9                  move.l (a1)+, (a0)+
  003914:  20 d9                  move.l (a1)+, (a0)+
  003916:  20 d9                  move.l (a1)+, (a0)+
  003918:  d6 c3                  adda.w d3, a3
  00391a:  51 ce ff f4            dbra d6, $3910
  00391e:  60 22                  bra.b $3942
  003920:  22 4b                  movea.l a3, a1
  003922:  20 d9                  move.l (a1)+, (a0)+
  003924:  20 d9                  move.l (a1)+, (a0)+
  003926:  20 d9                  move.l (a1)+, (a0)+
  003928:  30 d9                  move.w (a1)+, (a0)+
  00392a:  d6 c3                  adda.w d3, a3
  00392c:  51 ce ff f2            dbra d6, $3920
  003930:  60 10                  bra.b $3942
  003932:  22 4b                  movea.l a3, a1
  003934:  20 d9                  move.l (a1)+, (a0)+
  003936:  20 d9                  move.l (a1)+, (a0)+
  003938:  20 d9                  move.l (a1)+, (a0)+
  00393a:  20 d9                  move.l (a1)+, (a0)+
  00393c:  d6 c3                  adda.w d3, a3
  00393e:  51 ce ff f2            dbra d6, $3932
  003942:  20 0c                  move.l a4, d0
  003944:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003948:  4e 5e                  unlk a6
  00394a:  4e 75                  rts 
  00394c:  4e 56 00 00            link.w a6, #$0
  003950:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003954:  20 6e 00 08            movea.l $8(a6), a0
  003958:  38 18                  move.w (a0)+, d4
  00395a:  3a 18                  move.w (a0)+, d5
  00395c:  3c 18                  move.w (a0)+, d6
  00395e:  3e 18                  move.w (a0)+, d7
  003960:  9c 44                  sub.w d4, d6
  003962:  63 00 00 bc            bls.w $3a20
  003966:  e8 45                  asr.w #$4, d5
  003968:  06 47 00 0f            addi.w #$f, d7
  00396c:  e8 47                  asr.w #$4, d7
  00396e:  9e 45                  sub.w d5, d7
  003970:  63 00 00 ae            bls.w $3a20
  003974:  28 6e 00 0c            movea.l $c(a6), a4
  003978:  20 0c                  move.l a4, d0
  00397a:  67 00 00 a4            beq.w $3a20
  00397e:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003982:  36 2d a2 da            move.w -$5d26(a5), d3
  003986:  c9 c3                  muls.w d3, d4
  003988:  d7 c4                  adda.l d4, a3
  00398a:  da 45                  add.w d5, d5
  00398c:  d6 c5                  adda.w d5, a3
  00398e:  20 54                  movea.l (a4), a0
  003990:  53 46                  subq.w #$1, d6
  003992:  53 47                  subq.w #$1, d7
  003994:  70 07                  moveq #$7, d0
  003996:  c0 47                  and.w d7, d0
  003998:  d0 40                  add.w d0, d0
  00399a:  4e fb 00 02            jmp $399e(pc, d0.w)
  00399e:  60 0e                  bra.b $39ae
  0039a0:  60 16                  bra.b $39b8
  0039a2:  60 1e                  bra.b $39c2
  0039a4:  60 2a                  bra.b $39d0
  0039a6:  60 36                  bra.b $39de
  0039a8:  60 44                  bra.b $39ee
  0039aa:  60 52                  bra.b $39fe
  0039ac:  60 62                  bra.b $3a10
  0039ae:  36 98                  move.w (a0)+, (a3)
  0039b0:  d6 c3                  adda.w d3, a3
  0039b2:  51 ce ff fa            dbra d6, $39ae
  0039b6:  60 68                  bra.b $3a20
  0039b8:  26 98                  move.l (a0)+, (a3)
  0039ba:  d6 c3                  adda.w d3, a3
  0039bc:  51 ce ff fa            dbra d6, $39b8
  0039c0:  60 5e                  bra.b $3a20
  0039c2:  22 4b                  movea.l a3, a1
  0039c4:  22 d8                  move.l (a0)+, (a1)+
  0039c6:  32 d8                  move.w (a0)+, (a1)+
  0039c8:  d6 c3                  adda.w d3, a3
  0039ca:  51 ce ff f6            dbra d6, $39c2
  0039ce:  60 50                  bra.b $3a20
  0039d0:  22 4b                  movea.l a3, a1
  0039d2:  22 d8                  move.l (a0)+, (a1)+
  0039d4:  22 d8                  move.l (a0)+, (a1)+
  0039d6:  d6 c3                  adda.w d3, a3
  0039d8:  51 ce ff f6            dbra d6, $39d0
  0039dc:  60 42                  bra.b $3a20
  0039de:  22 4b                  movea.l a3, a1
  0039e0:  22 d8                  move.l (a0)+, (a1)+
  0039e2:  22 d8                  move.l (a0)+, (a1)+
  0039e4:  32 d8                  move.w (a0)+, (a1)+
  0039e6:  d6 c3                  adda.w d3, a3
  0039e8:  51 ce ff f4            dbra d6, $39de
  0039ec:  60 32                  bra.b $3a20
  0039ee:  22 4b                  movea.l a3, a1
  0039f0:  22 d8                  move.l (a0)+, (a1)+
  0039f2:  22 d8                  move.l (a0)+, (a1)+
  0039f4:  22 d8                  move.l (a0)+, (a1)+
  0039f6:  d6 c3                  adda.w d3, a3
  0039f8:  51 ce ff f4            dbra d6, $39ee
  0039fc:  60 22                  bra.b $3a20
  0039fe:  22 4b                  movea.l a3, a1
  003a00:  22 d8                  move.l (a0)+, (a1)+
  003a02:  22 d8                  move.l (a0)+, (a1)+
  003a04:  22 d8                  move.l (a0)+, (a1)+
  003a06:  32 d8                  move.w (a0)+, (a1)+
  003a08:  d6 c3                  adda.w d3, a3
  003a0a:  51 ce ff f2            dbra d6, $39fe
  003a0e:  60 10                  bra.b $3a20
  003a10:  22 4b                  movea.l a3, a1
  003a12:  22 d8                  move.l (a0)+, (a1)+
  003a14:  22 d8                  move.l (a0)+, (a1)+
  003a16:  22 d8                  move.l (a0)+, (a1)+
  003a18:  22 d8                  move.l (a0)+, (a1)+
  003a1a:  d6 c3                  adda.w d3, a3
  003a1c:  51 ce ff f2            dbra d6, $3a10
  003a20:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003a24:  4e 5e                  unlk a6
  003a26:  4e 75                  rts 
  003a28:  4e 56 00 00            link.w a6, #$0
  003a2c:  48 e7 3f 38            movem.l d2-d7/a2-a4, -(a7)
  003a30:  32 2e 00 08            move.w $8(a6), d1
  003a34:  41 ed a5 7a            lea.l -$5a86(a5), a0
  003a38:  20 70 14 00            movea.l (a0, d1.w * 4), a0
  003a3c:  20 08                  move.l a0, d0
  003a3e:  67 00 02 42            beq.w $3c82
  003a42:  20 50                  movea.l (a0), a0
  003a44:  43 ed a5 9a            lea.l -$5a66(a5), a1
  003a48:  22 71 14 00            movea.l (a1, d1.w * 4), a1
  003a4c:  20 09                  move.l a1, d0
  003a4e:  67 00 02 32            beq.w $3c82
  003a52:  22 51                  movea.l (a1), a1
  003a54:  32 2e 00 0a            move.w $a(a6), d1
  003a58:  20 30 14 00            move.l (a0, d1.w * 4), d0
  003a5c:  6b 00 02 24            bmi.w $3c82
  003a60:  49 f1 08 00            lea.l (a1, d0.l), a4
  003a64:  30 1c                  move.w (a4)+, d0
  003a66:  32 1c                  move.w (a4)+, d1
  003a68:  38 1c                  move.w (a4)+, d4
  003a6a:  3a 1c                  move.w (a4)+, d5
  003a6c:  3c 2e 00 0c            move.w $c(a6), d6
  003a70:  9c 44                  sub.w d4, d6
  003a72:  4a 6e 00 10            tst.w $10(a6)
  003a76:  6a 08                  bpl.b $3a80
  003a78:  3c 2e 00 0c            move.w $c(a6), d6
  003a7c:  dc 44                  add.w d4, d6
  003a7e:  53 46                  subq.w #$1, d6
  003a80:  3e 2e 00 0e            move.w $e(a6), d7
  003a84:  9e 45                  sub.w d5, d7
  003a86:  4a 6d ba 32            tst.w -$45ce(a5)
  003a8a:  67 0c                  beq.b $3a98
  003a8c:  3e 2d a5 d0            move.w -$5a30(a5), d7
  003a90:  9e 6e 00 0e            sub.w $e(a6), d7
  003a94:  de 45                  add.w d5, d7
  003a96:  53 47                  subq.w #$1, d7
  003a98:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003a9c:  30 2d a2 da            move.w -$5d26(a5), d0
  003aa0:  c1 c7                  muls.w d7, d0
  003aa2:  d7 c0                  adda.l d0, a3
  003aa4:  30 06                  move.w d6, d0
  003aa6:  e2 40                  asr.w #$1, d0
  003aa8:  d6 c0                  adda.w d0, a3
  003aaa:  30 2d a2 e6            move.w -$5d1a(a5), d0
  003aae:  02 40 ff fe            andi.w #$fffe, d0
  003ab2:  9c 40                  sub.w d0, d6
  003ab4:  38 2d a2 ea            move.w -$5d16(a5), d4
  003ab8:  02 44 ff fe            andi.w #$fffe, d4
  003abc:  98 40                  sub.w d0, d4
  003abe:  30 2d a2 e4            move.w -$5d1c(a5), d0
  003ac2:  9e 40                  sub.w d0, d7
  003ac4:  3a 2d a2 e8            move.w -$5d18(a5), d5
  003ac8:  9a 40                  sub.w d0, d5
  003aca:  45 ed a2 fa            lea.l -$5d06(a5), a2
  003ace:  22 4f                  movea.l a7, a1
  003ad0:  20 4b                  movea.l a3, a0
  003ad2:  36 06                  move.w d6, d3
  003ad4:  74 00                  moveq #$0, d2
  003ad6:  70 00                  moveq #$0, d0
  003ad8:  10 1c                  move.b (a4)+, d0
  003ada:  6a 18                  bpl.b $3af4
  003adc:  4a 6d ba 32            tst.w -$45ce(a5)
  003ae0:  67 08                  beq.b $3aea
  003ae2:  53 47                  subq.w #$1, d7
  003ae4:  96 ed a2 da            suba.w -$5d26(a5), a3
  003ae8:  60 06                  bra.b $3af0
  003aea:  52 47                  addq.w #$1, d7
  003aec:  d6 ed a2 da            adda.w -$5d26(a5), a3
  003af0:  20 4b                  movea.l a3, a0
  003af2:  3c 03                  move.w d3, d6
  003af4:  72 1f                  moveq #$1f, d1
  003af6:  c2 00                  and.b d0, d1
  003af8:  0c 01 00 1f            cmpi.b #$1f, d1
  003afc:  66 06                  bne.b $3b04
  003afe:  12 1c                  move.b (a4)+, d1
  003b00:  06 41 00 1f            addi.w #$1f, d1
  003b04:  52 41                  addq.w #$1, d1
  003b06:  d0 00                  add.b d0, d0
  003b08:  d0 00                  add.b d0, d0
  003b0a:  65 00 01 12            bcs.w $3c1e
  003b0e:  6b 7c                  bmi.b $3b8c
  003b10:  53 41                  subq.w #$1, d1
  003b12:  67 00 01 6c            beq.w $3c80
  003b16:  be 45                  cmp.w d5, d7
  003b18:  64 6c                  bcc.b $3b86
  003b1a:  10 1c                  move.b (a4)+, d0
  003b1c:  10 32 08 00            move.b (a2, d0.l), d0
  003b20:  14 00                  move.b d0, d2
  003b22:  e9 08                  lsl.b #$4, d0
  003b24:  4a 6e 00 10            tst.w $10(a6)
  003b28:  6b 2c                  bmi.b $3b56
  003b2a:  08 06 00 00            btst.b #$0, d6
  003b2e:  66 12                  bne.b $3b42
  003b30:  bc 44                  cmp.w d4, d6
  003b32:  64 06                  bcc.b $3b3a
  003b34:  02 10 00 0f            andi.b #$f, (a0)
  003b38:  81 10                  or.b d0, (a0)
  003b3a:  52 46                  addq.w #$1, d6
  003b3c:  51 c9 00 04            dbra d1, $3b42
  003b40:  60 96                  bra.b $3ad8
  003b42:  bc 44                  cmp.w d4, d6
  003b44:  64 06                  bcc.b $3b4c
  003b46:  02 10 00 f0            andi.b #$f0, (a0)
  003b4a:  85 10                  or.b d2, (a0)
  003b4c:  52 48                  addq.w #$1, a0
  003b4e:  52 46                  addq.w #$1, d6
  003b50:  51 c9 ff de            dbra d1, $3b30
  003b54:  60 82                  bra.b $3ad8
  003b56:  08 06 00 00            btst.b #$0, d6
  003b5a:  66 16                  bne.b $3b72
  003b5c:  bc 44                  cmp.w d4, d6
  003b5e:  64 06                  bcc.b $3b66
  003b60:  02 10 00 0f            andi.b #$f, (a0)
  003b64:  81 10                  or.b d0, (a0)
  003b66:  53 48                  subq.w #$1, a0
  003b68:  53 46                  subq.w #$1, d6
  003b6a:  51 c9 00 06            dbra d1, $3b72
  003b6e:  60 00 ff 68            bra.w $3ad8
  003b72:  bc 44                  cmp.w d4, d6
  003b74:  64 06                  bcc.b $3b7c
  003b76:  02 10 00 f0            andi.b #$f0, (a0)
  003b7a:  85 10                  or.b d2, (a0)
  003b7c:  53 46                  subq.w #$1, d6
  003b7e:  51 c9 ff dc            dbra d1, $3b5c
  003b82:  60 00 ff 54            bra.w $3ad8
  003b86:  52 8c                  addq.l #$1, a4
  003b88:  60 00 ff 4e            bra.w $3ad8
  003b8c:  53 41                  subq.w #$1, d1
  003b8e:  be 45                  cmp.w d5, d7
  003b90:  64 00 00 84            bcc.w $3c16
  003b94:  4a 6e 00 10            tst.w $10(a6)
  003b98:  6b 3e                  bmi.b $3bd8
  003b9a:  08 06 00 00            btst.b #$0, d6
  003b9e:  66 1c                  bne.b $3bbc
  003ba0:  14 1c                  move.b (a4)+, d2
  003ba2:  10 32 28 00            move.b (a2, d2.l), d0
  003ba6:  e9 08                  lsl.b #$4, d0
  003ba8:  bc 44                  cmp.w d4, d6
  003baa:  64 06                  bcc.b $3bb2
  003bac:  02 10 00 0f            andi.b #$f, (a0)
  003bb0:  81 10                  or.b d0, (a0)
  003bb2:  52 46                  addq.w #$1, d6
  003bb4:  51 c9 00 06            dbra d1, $3bbc
  003bb8:  60 00 ff 1e            bra.w $3ad8
  003bbc:  14 1c                  move.b (a4)+, d2
  003bbe:  10 32 28 00            move.b (a2, d2.l), d0
  003bc2:  bc 44                  cmp.w d4, d6
  003bc4:  64 06                  bcc.b $3bcc
  003bc6:  02 10 00 f0            andi.b #$f0, (a0)
  003bca:  81 10                  or.b d0, (a0)
  003bcc:  52 48                  addq.w #$1, a0
  003bce:  52 46                  addq.w #$1, d6
  003bd0:  51 c9 ff ce            dbra d1, $3ba0
  003bd4:  60 00 ff 02            bra.w $3ad8
  003bd8:  08 06 00 00            btst.b #$0, d6
  003bdc:  66 1e                  bne.b $3bfc
  003bde:  14 1c                  move.b (a4)+, d2
  003be0:  10 32 28 00            move.b (a2, d2.l), d0
  003be4:  e9 08                  lsl.b #$4, d0
  003be6:  bc 44                  cmp.w d4, d6
  003be8:  64 06                  bcc.b $3bf0
  003bea:  02 10 00 0f            andi.b #$f, (a0)
  003bee:  81 10                  or.b d0, (a0)
  003bf0:  53 48                  subq.w #$1, a0
  003bf2:  53 46                  subq.w #$1, d6
  003bf4:  51 c9 00 06            dbra d1, $3bfc
  003bf8:  60 00 fe de            bra.w $3ad8
  003bfc:  14 1c                  move.b (a4)+, d2
  003bfe:  10 32 28 00            move.b (a2, d2.l), d0
  003c02:  bc 44                  cmp.w d4, d6
  003c04:  64 06                  bcc.b $3c0c
  003c06:  02 10 00 f0            andi.b #$f0, (a0)
  003c0a:  81 10                  or.b d0, (a0)
  003c0c:  53 46                  subq.w #$1, d6
  003c0e:  51 c9 ff ce            dbra d1, $3bde
  003c12:  60 00 fe c4            bra.w $3ad8
  003c16:  52 41                  addq.w #$1, d1
  003c18:  d8 c1                  adda.w d1, a4
  003c1a:  60 00 fe bc            bra.w $3ad8
  003c1e:  6b 3e                  bmi.b $3c5e
  003c20:  4a 6e 00 10            tst.w $10(a6)
  003c24:  6b 1c                  bmi.b $3c42
  003c26:  08 06 00 00            btst.b #$0, d6
  003c2a:  66 0a                  bne.b $3c36
  003c2c:  dc 41                  add.w d1, d6
  003c2e:  e2 41                  asr.w #$1, d1
  003c30:  d0 c1                  adda.w d1, a0
  003c32:  60 00 fe a4            bra.w $3ad8
  003c36:  dc 41                  add.w d1, d6
  003c38:  52 41                  addq.w #$1, d1
  003c3a:  e2 41                  asr.w #$1, d1
  003c3c:  d0 c1                  adda.w d1, a0
  003c3e:  60 00 fe 98            bra.w $3ad8
  003c42:  08 06 00 00            btst.b #$0, d6
  003c46:  66 0c                  bne.b $3c54
  003c48:  9c 41                  sub.w d1, d6
  003c4a:  52 41                  addq.w #$1, d1
  003c4c:  e2 41                  asr.w #$1, d1
  003c4e:  90 c1                  suba.w d1, a0
  003c50:  60 00 fe 86            bra.w $3ad8
  003c54:  9c 41                  sub.w d1, d6
  003c56:  e2 41                  asr.w #$1, d1
  003c58:  90 c1                  suba.w d1, a0
  003c5a:  60 00 fe 7c            bra.w $3ad8
  003c5e:  53 41                  subq.w #$1, d1
  003c60:  66 16                  bne.b $3c78
  003c62:  bf c9                  cmpa.l a1, a7
  003c64:  64 1a                  bcc.b $3c80
  003c66:  53 57                  subq.w #$1, (a7)
  003c68:  6b 08                  bmi.b $3c72
  003c6a:  28 6f 00 02            movea.l $2(a7), a4
  003c6e:  60 00 fe 68            bra.w $3ad8
  003c72:  5c 8f                  addq.l #$6, a7
  003c74:  60 00 fe 62            bra.w $3ad8
  003c78:  2f 0c                  move.l a4, -(a7)
  003c7a:  3f 01                  move.w d1, -(a7)
  003c7c:  60 00 fe 5a            bra.w $3ad8
  003c80:  2e 49                  movea.l a1, a7
  003c82:  4c df 1c fc            movem.l (a7)+, d2-d7/a2-a4
  003c86:  4e 5e                  unlk a6
  003c88:  4e 75                  rts 
  003c8a:  4e 56 00 00            link.w a6, #$0
  003c8e:  48 e7 1f 10            movem.l d3-d7/a3, -(a7)
  003c92:  20 6e 00 08            movea.l $8(a6), a0
  003c96:  38 18                  move.w (a0)+, d4
  003c98:  3a 18                  move.w (a0)+, d5
  003c9a:  3c 18                  move.w (a0)+, d6
  003c9c:  3e 18                  move.w (a0)+, d7
  003c9e:  9c 44                  sub.w d4, d6
  003ca0:  9e 45                  sub.w d5, d7
  003ca2:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003ca6:  36 2d a2 da            move.w -$5d26(a5), d3
  003caa:  30 03                  move.w d3, d0
  003cac:  c1 c4                  muls.w d4, d0
  003cae:  d7 c0                  adda.l d0, a3
  003cb0:  30 05                  move.w d5, d0
  003cb2:  e2 40                  asr.w #$1, d0
  003cb4:  d6 c0                  adda.w d0, a3
  003cb6:  70 00                  moveq #$0, d0
  003cb8:  10 2e 00 0c            move.b $c(a6), d0
  003cbc:  41 ed a2 fa            lea.l -$5d06(a5), a0
  003cc0:  18 30 08 00            move.b (a0, d0.l), d4
  003cc4:  e9 0c                  lsl.b #$4, d4
  003cc6:  88 30 08 00            or.b (a0, d0.l), d4
  003cca:  70 01                  moveq #$1, d0
  003ccc:  ca 40                  and.w d0, d5
  003cce:  60 32                  bra.b $3d02
  003cd0:  20 4b                  movea.l a3, a0
  003cd2:  32 07                  move.w d7, d1
  003cd4:  4a 45                  tst.w d5
  003cd6:  67 0c                  beq.b $3ce4
  003cd8:  70 f0                  moveq #$f0, d0
  003cda:  c1 10                  and.b d0, (a0)
  003cdc:  46 00                  not.b d0
  003cde:  c0 04                  and.b d4, d0
  003ce0:  81 18                  or.b d0, (a0)+
  003ce2:  53 41                  subq.w #$1, d1
  003ce4:  e2 41                  asr.w #$1, d1
  003ce6:  60 02                  bra.b $3cea
  003ce8:  10 c4                  move.b d4, (a0)+
  003cea:  51 c9 ff fc            dbra d1, $3ce8
  003cee:  70 01                  moveq #$1, d0
  003cf0:  c0 47                  and.w d7, d0
  003cf2:  bb 40                  eor.w d5, d0
  003cf4:  67 0a                  beq.b $3d00
  003cf6:  70 0f                  moveq #$f, d0
  003cf8:  c1 10                  and.b d0, (a0)
  003cfa:  46 00                  not.b d0
  003cfc:  c0 04                  and.b d4, d0
  003cfe:  81 18                  or.b d0, (a0)+
  003d00:  d6 c3                  adda.w d3, a3
  003d02:  51 ce ff cc            dbra d6, $3cd0
  003d06:  4c df 08 f8            movem.l (a7)+, d3-d7/a3
  003d0a:  4e 5e                  unlk a6
  003d0c:  4e 75                  rts 
  003d0e:  4e 56 00 00            link.w a6, #$0
  003d12:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003d16:  99 cc                  suba.l a4, a4
  003d18:  20 6e 00 08            movea.l $8(a6), a0
  003d1c:  38 18                  move.w (a0)+, d4
  003d1e:  3a 18                  move.w (a0)+, d5
  003d20:  3c 18                  move.w (a0)+, d6
  003d22:  3e 18                  move.w (a0)+, d7
  003d24:  9c 44                  sub.w d4, d6
  003d26:  e4 45                  asr.w #$2, d5
  003d28:  56 47                  addq.w #$3, d7
  003d2a:  e4 47                  asr.w #$2, d7
  003d2c:  9e 45                  sub.w d5, d7
  003d2e:  30 06                  move.w d6, d0
  003d30:  c0 c7                  mulu.w d7, d0
  003d32:  d0 80                  add.l d0, d0
  003d34:  a1 22                  dc.w $a122
  003d36:  4a 40                  tst.w d0
  003d38:  66 2c                  bne.b $3d66
  003d3a:  28 48                  movea.l a0, a4
  003d3c:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003d40:  36 2d a2 da            move.w -$5d26(a5), d3
  003d44:  30 03                  move.w d3, d0
  003d46:  c1 c4                  muls.w d4, d0
  003d48:  d7 c0                  adda.l d0, a3
  003d4a:  30 05                  move.w d5, d0
  003d4c:  d0 40                  add.w d0, d0
  003d4e:  d6 c0                  adda.w d0, a3
  003d50:  20 54                  movea.l (a4), a0
  003d52:  60 0e                  bra.b $3d62
  003d54:  22 4b                  movea.l a3, a1
  003d56:  32 07                  move.w d7, d1
  003d58:  60 02                  bra.b $3d5c
  003d5a:  30 d9                  move.w (a1)+, (a0)+
  003d5c:  51 c9 ff fc            dbra d1, $3d5a
  003d60:  d6 c3                  adda.w d3, a3
  003d62:  51 ce ff f0            dbra d6, $3d54
  003d66:  20 0c                  move.l a4, d0
  003d68:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003d6c:  4e 5e                  unlk a6
  003d6e:  4e 75                  rts 
  003d70:  4e 56 00 00            link.w a6, #$0
  003d74:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003d78:  20 6e 00 08            movea.l $8(a6), a0
  003d7c:  38 18                  move.w (a0)+, d4
  003d7e:  3a 18                  move.w (a0)+, d5
  003d80:  3c 18                  move.w (a0)+, d6
  003d82:  3e 18                  move.w (a0)+, d7
  003d84:  9c 44                  sub.w d4, d6
  003d86:  e4 45                  asr.w #$2, d5
  003d88:  56 47                  addq.w #$3, d7
  003d8a:  e4 47                  asr.w #$2, d7
  003d8c:  9e 45                  sub.w d5, d7
  003d8e:  28 6e 00 0c            movea.l $c(a6), a4
  003d92:  20 0c                  move.l a4, d0
  003d94:  67 2a                  beq.b $3dc0
  003d96:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003d9a:  36 2d a2 da            move.w -$5d26(a5), d3
  003d9e:  30 03                  move.w d3, d0
  003da0:  c1 c4                  muls.w d4, d0
  003da2:  d7 c0                  adda.l d0, a3
  003da4:  30 05                  move.w d5, d0
  003da6:  d0 40                  add.w d0, d0
  003da8:  d6 c0                  adda.w d0, a3
  003daa:  20 54                  movea.l (a4), a0
  003dac:  60 0e                  bra.b $3dbc
  003dae:  22 4b                  movea.l a3, a1
  003db0:  32 07                  move.w d7, d1
  003db2:  60 02                  bra.b $3db6
  003db4:  32 d8                  move.w (a0)+, (a1)+
  003db6:  51 c9 ff fc            dbra d1, $3db4
  003dba:  d6 c3                  adda.w d3, a3
  003dbc:  51 ce ff f0            dbra d6, $3dae
  003dc0:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003dc4:  4e 5e                  unlk a6
  003dc6:  4e 75                  rts 
  003dc8:  4e 56 00 00            link.w a6, #$0
  003dcc:  48 e7 3f 38            movem.l d2-d7/a2-a4, -(a7)
  003dd0:  32 2e 00 08            move.w $8(a6), d1
  003dd4:  41 ed a5 7a            lea.l -$5a86(a5), a0
  003dd8:  20 70 14 00            movea.l (a0, d1.w * 4), a0
  003ddc:  20 08                  move.l a0, d0
  003dde:  67 00 01 40            beq.w $3f20
  003de2:  20 50                  movea.l (a0), a0
  003de4:  43 ed a5 9a            lea.l -$5a66(a5), a1
  003de8:  22 71 14 00            movea.l (a1, d1.w * 4), a1
  003dec:  20 09                  move.l a1, d0
  003dee:  67 00 01 30            beq.w $3f20
  003df2:  22 51                  movea.l (a1), a1
  003df4:  32 2e 00 0a            move.w $a(a6), d1
  003df8:  20 30 14 00            move.l (a0, d1.w * 4), d0
  003dfc:  6b 00 01 22            bmi.w $3f20
  003e00:  49 f1 08 00            lea.l (a1, d0.l), a4
  003e04:  30 1c                  move.w (a4)+, d0
  003e06:  32 1c                  move.w (a4)+, d1
  003e08:  38 1c                  move.w (a4)+, d4
  003e0a:  3a 1c                  move.w (a4)+, d5
  003e0c:  3c 2e 00 0c            move.w $c(a6), d6
  003e10:  9c 44                  sub.w d4, d6
  003e12:  4a 6e 00 10            tst.w $10(a6)
  003e16:  6a 08                  bpl.b $3e20
  003e18:  3c 2e 00 0c            move.w $c(a6), d6
  003e1c:  dc 44                  add.w d4, d6
  003e1e:  53 46                  subq.w #$1, d6
  003e20:  3e 2e 00 0e            move.w $e(a6), d7
  003e24:  9e 45                  sub.w d5, d7
  003e26:  4a 6d ba 32            tst.w -$45ce(a5)
  003e2a:  67 0c                  beq.b $3e38
  003e2c:  3e 2d a5 d0            move.w -$5a30(a5), d7
  003e30:  9e 6e 00 0e            sub.w $e(a6), d7
  003e34:  de 45                  add.w d5, d7
  003e36:  53 47                  subq.w #$1, d7
  003e38:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003e3c:  30 2d a2 da            move.w -$5d26(a5), d0
  003e40:  c1 c7                  muls.w d7, d0
  003e42:  d7 c0                  adda.l d0, a3
  003e44:  d6 c6                  adda.w d6, a3
  003e46:  30 2d a2 e6            move.w -$5d1a(a5), d0
  003e4a:  9c 40                  sub.w d0, d6
  003e4c:  38 2d a2 ea            move.w -$5d16(a5), d4
  003e50:  98 40                  sub.w d0, d4
  003e52:  30 2d a2 e4            move.w -$5d1c(a5), d0
  003e56:  9e 40                  sub.w d0, d7
  003e58:  3a 2d a2 e8            move.w -$5d18(a5), d5
  003e5c:  9a 40                  sub.w d0, d5
  003e5e:  45 ed a2 fa            lea.l -$5d06(a5), a2
  003e62:  22 4f                  movea.l a7, a1
  003e64:  20 4b                  movea.l a3, a0
  003e66:  36 06                  move.w d6, d3
  003e68:  34 2e 00 10            move.w $10(a6), d2
  003e6c:  70 00                  moveq #$0, d0
  003e6e:  10 1c                  move.b (a4)+, d0
  003e70:  6a 18                  bpl.b $3e8a
  003e72:  4a 6d ba 32            tst.w -$45ce(a5)
  003e76:  67 08                  beq.b $3e80
  003e78:  53 47                  subq.w #$1, d7
  003e7a:  96 ed a2 da            suba.w -$5d26(a5), a3
  003e7e:  60 06                  bra.b $3e86
  003e80:  52 47                  addq.w #$1, d7
  003e82:  d6 ed a2 da            adda.w -$5d26(a5), a3
  003e86:  20 4b                  movea.l a3, a0
  003e88:  3c 03                  move.w d3, d6
  003e8a:  72 1f                  moveq #$1f, d1
  003e8c:  c2 00                  and.b d0, d1
  003e8e:  0c 01 00 1f            cmpi.b #$1f, d1
  003e92:  66 06                  bne.b $3e9a
  003e94:  12 1c                  move.b (a4)+, d1
  003e96:  06 41 00 1f            addi.w #$1f, d1
  003e9a:  52 41                  addq.w #$1, d1
  003e9c:  d0 00                  add.b d0, d0
  003e9e:  d0 00                  add.b d0, d0
  003ea0:  65 44                  bcs.b $3ee6
  003ea2:  6b 22                  bmi.b $3ec6
  003ea4:  53 41                  subq.w #$1, d1
  003ea6:  67 76                  beq.b $3f1e
  003ea8:  be 45                  cmp.w d5, d7
  003eaa:  64 16                  bcc.b $3ec2
  003eac:  10 1c                  move.b (a4)+, d0
  003eae:  10 32 08 00            move.b (a2, d0.l), d0
  003eb2:  bc 44                  cmp.w d4, d6
  003eb4:  64 02                  bcc.b $3eb8
  003eb6:  10 80                  move.b d0, (a0)
  003eb8:  d0 c2                  adda.w d2, a0
  003eba:  dc 42                  add.w d2, d6
  003ebc:  51 c9 ff f4            dbra d1, $3eb2
  003ec0:  60 ac                  bra.b $3e6e
  003ec2:  52 4c                  addq.w #$1, a4
  003ec4:  60 a8                  bra.b $3e6e
  003ec6:  53 41                  subq.w #$1, d1
  003ec8:  be 45                  cmp.w d5, d7
  003eca:  64 14                  bcc.b $3ee0
  003ecc:  10 1c                  move.b (a4)+, d0
  003ece:  bc 44                  cmp.w d4, d6
  003ed0:  64 04                  bcc.b $3ed6
  003ed2:  10 b2 08 00            move.b (a2, d0.l), (a0)
  003ed6:  d0 c2                  adda.w d2, a0
  003ed8:  dc 42                  add.w d2, d6
  003eda:  51 c9 ff f0            dbra d1, $3ecc
  003ede:  60 8e                  bra.b $3e6e
  003ee0:  d8 c1                  adda.w d1, a4
  003ee2:  52 4c                  addq.w #$1, a4
  003ee4:  60 88                  bra.b $3e6e
  003ee6:  6b 14                  bmi.b $3efc
  003ee8:  4a 42                  tst.w d2
  003eea:  6b 08                  bmi.b $3ef4
  003eec:  dc 41                  add.w d1, d6
  003eee:  d0 c1                  adda.w d1, a0
  003ef0:  60 00 ff 7c            bra.w $3e6e
  003ef4:  9c 41                  sub.w d1, d6
  003ef6:  90 c1                  suba.w d1, a0
  003ef8:  60 00 ff 74            bra.w $3e6e
  003efc:  53 41                  subq.w #$1, d1
  003efe:  66 16                  bne.b $3f16
  003f00:  bf c9                  cmpa.l a1, a7
  003f02:  64 1a                  bcc.b $3f1e
  003f04:  53 57                  subq.w #$1, (a7)
  003f06:  6b 08                  bmi.b $3f10
  003f08:  28 6f 00 02            movea.l $2(a7), a4
  003f0c:  60 00 ff 60            bra.w $3e6e
  003f10:  5c 8f                  addq.l #$6, a7
  003f12:  60 00 ff 5a            bra.w $3e6e
  003f16:  2f 0c                  move.l a4, -(a7)
  003f18:  3f 01                  move.w d1, -(a7)
  003f1a:  60 00 ff 52            bra.w $3e6e
  003f1e:  2e 49                  movea.l a1, a7
  003f20:  4c df 1c fc            movem.l (a7)+, d2-d7/a2-a4
  003f24:  4e 5e                  unlk a6
  003f26:  4e 75                  rts 
  003f28:  4e 56 00 00            link.w a6, #$0
  003f2c:  48 e7 1f 10            movem.l d3-d7/a3, -(a7)
  003f30:  20 6e 00 08            movea.l $8(a6), a0
  003f34:  38 18                  move.w (a0)+, d4
  003f36:  3a 18                  move.w (a0)+, d5
  003f38:  3c 18                  move.w (a0)+, d6
  003f3a:  3e 18                  move.w (a0)+, d7
  003f3c:  9c 44                  sub.w d4, d6
  003f3e:  9e 45                  sub.w d5, d7
  003f40:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003f44:  36 2d a2 da            move.w -$5d26(a5), d3
  003f48:  30 03                  move.w d3, d0
  003f4a:  c1 c4                  muls.w d4, d0
  003f4c:  d7 c0                  adda.l d0, a3
  003f4e:  d6 c5                  adda.w d5, a3
  003f50:  70 00                  moveq #$0, d0
  003f52:  10 2e 00 0c            move.b $c(a6), d0
  003f56:  41 ed a2 fa            lea.l -$5d06(a5), a0
  003f5a:  18 30 08 00            move.b (a0, d0.l), d4
  003f5e:  60 0e                  bra.b $3f6e
  003f60:  20 4b                  movea.l a3, a0
  003f62:  30 07                  move.w d7, d0
  003f64:  60 02                  bra.b $3f68
  003f66:  10 c4                  move.b d4, (a0)+
  003f68:  51 c8 ff fc            dbra d0, $3f66
  003f6c:  d6 c3                  adda.w d3, a3
  003f6e:  51 ce ff f0            dbra d6, $3f60
  003f72:  4c df 08 f8            movem.l (a7)+, d3-d7/a3
  003f76:  4e 5e                  unlk a6
  003f78:  4e 75                  rts 
  003f7a:  4e 56 00 00            link.w a6, #$0
  003f7e:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003f82:  99 cc                  suba.l a4, a4
  003f84:  20 6e 00 08            movea.l $8(a6), a0
  003f88:  38 18                  move.w (a0)+, d4
  003f8a:  3a 18                  move.w (a0)+, d5
  003f8c:  3c 18                  move.w (a0)+, d6
  003f8e:  3e 18                  move.w (a0)+, d7
  003f90:  9c 44                  sub.w d4, d6
  003f92:  e2 45                  asr.w #$1, d5
  003f94:  52 47                  addq.w #$1, d7
  003f96:  e2 47                  asr.w #$1, d7
  003f98:  9e 45                  sub.w d5, d7
  003f9a:  30 06                  move.w d6, d0
  003f9c:  c0 c7                  mulu.w d7, d0
  003f9e:  d0 80                  add.l d0, d0
  003fa0:  a1 22                  dc.w $a122
  003fa2:  4a 40                  tst.w d0
  003fa4:  66 2c                  bne.b $3fd2
  003fa6:  28 48                  movea.l a0, a4
  003fa8:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003fac:  36 2d a2 da            move.w -$5d26(a5), d3
  003fb0:  30 03                  move.w d3, d0
  003fb2:  c1 c4                  muls.w d4, d0
  003fb4:  d7 c0                  adda.l d0, a3
  003fb6:  30 05                  move.w d5, d0
  003fb8:  d0 40                  add.w d0, d0
  003fba:  d6 c0                  adda.w d0, a3
  003fbc:  20 54                  movea.l (a4), a0
  003fbe:  60 0e                  bra.b $3fce
  003fc0:  22 4b                  movea.l a3, a1
  003fc2:  32 07                  move.w d7, d1
  003fc4:  60 02                  bra.b $3fc8
  003fc6:  30 d9                  move.w (a1)+, (a0)+
  003fc8:  51 c9 ff fc            dbra d1, $3fc6
  003fcc:  d6 c3                  adda.w d3, a3
  003fce:  51 ce ff f0            dbra d6, $3fc0
  003fd2:  20 0c                  move.l a4, d0
  003fd4:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003fd8:  4e 5e                  unlk a6
  003fda:  4e 75                  rts 
  003fdc:  4e 56 00 00            link.w a6, #$0
  003fe0:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003fe4:  20 6e 00 08            movea.l $8(a6), a0
  003fe8:  38 18                  move.w (a0)+, d4
  003fea:  3a 18                  move.w (a0)+, d5
  003fec:  3c 18                  move.w (a0)+, d6
  003fee:  3e 18                  move.w (a0)+, d7
  003ff0:  9c 44                  sub.w d4, d6
  003ff2:  e2 45                  asr.w #$1, d5
  003ff4:  52 47                  addq.w #$1, d7
  003ff6:  e2 47                  asr.w #$1, d7
  003ff8:  9e 45                  sub.w d5, d7
  003ffa:  28 6e 00 0c            movea.l $c(a6), a4
  003ffe:  20 0c                  move.l a4, d0
  004000:  67 2a                  beq.b $402c
  004002:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  004006:  36 2d a2 da            move.w -$5d26(a5), d3
  00400a:  30 03                  move.w d3, d0
  00400c:  c1 c4                  muls.w d4, d0
  00400e:  d7 c0                  adda.l d0, a3
  004010:  30 05                  move.w d5, d0
  004012:  d0 40                  add.w d0, d0
  004014:  d6 c0                  adda.w d0, a3
  004016:  20 54                  movea.l (a4), a0
  004018:  60 0e                  bra.b $4028
  00401a:  22 4b                  movea.l a3, a1
  00401c:  32 07                  move.w d7, d1
  00401e:  60 02                  bra.b $4022
  004020:  32 d8                  move.w (a0)+, (a1)+
  004022:  51 c9 ff fc            dbra d1, $4020
  004026:  d6 c3                  adda.w d3, a3
  004028:  51 ce ff f0            dbra d6, $401a
  00402c:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  004030:  4e 5e                  unlk a6
  004032:  4e 75                  rts 
  004034:  4a 78 02 8e            tst.w $28e.w
  004038:  6b 22                  bmi.b $405c
  00403a:  30 3c 00 90            move.w #$90, d0
  00403e:  a3 46                  dc.w $a346
  004040:  22 48                  movea.l a0, a1
  004042:  30 3c 00 9f            move.w #$9f, d0
  004046:  a7 46                  dc.w $a746
  004048:  b3 c8                  cmpa.l a0, a1
  00404a:  67 10                  beq.b $405c
  00404c:  22 5f                  movea.l (a7)+, a1
  00404e:  20 5f                  movea.l (a7)+, a0
  004050:  30 1f                  move.w (a7)+, d0
  004052:  2f 09                  move.l a1, -(a7)
  004054:  a0 90                  dc.w $a090
  004056:  3f 40 00 04            move.w d0, $4(a7)
  00405a:  4e 75                  rts 
  00405c:  20 6f 00 04            movea.l $4(a7), a0
  004060:  30 3c 00 01            move.w #$1, d0
  004064:  22 48                  movea.l a0, a1
  004066:  60 06                  bra.b $406e
  004068:  03 13                  btst.l d1, (a3)
  00406a:  0b 02                  btst.l d5, d2
  00406c:  01 00                  btst.l d0, d0
  00406e:  30 3c 00 10            move.w #$10, d0
  004072:  e2 40                  asr.w #$1, d0
  004074:  53 40                  subq.w #$1, d0
  004076:  42 58                  clr.w (a0)+
  004078:  51 c8 ff fc            dbra d0, $4076
  00407c:  32 bc 00 01            move.w #$1, (a1)
  004080:  20 78 02 ae            movea.l $2ae.w, a0
  004084:  33 7c ff fe 00 02      move.w #$fffe, $2(a1)
  00408a:  0c 28 00 ff 00 09      cmpi.b #$ff, $9(a0)
  004090:  67 42                  beq.b $40d4
  004092:  4a 28 00 08            tst.b $8(a0)
  004096:  6e 20                  bgt.b $40b8
  004098:  33 7c ff ff 00 02      move.w #$ffff, $2(a1)
  00409e:  4a 78 02 8e            tst.w $28e.w
  0040a2:  6b 30                  bmi.b $40d4
  0040a4:  33 7c 00 01 00 02      move.w #$1, $2(a1)
  0040aa:  4a 78 0b 22            tst.w $b22.w
  0040ae:  6a 24                  bpl.b $40d4
  0040b0:  33 7c 00 02 00 02      move.w #$2, $2(a1)
  0040b6:  60 1c                  bra.b $40d4
  0040b8:  42 69 00 02            clr.w $2(a1)
  0040bc:  0c 28 00 02 00 08      cmpi.b #$2, $8(a0)
  0040c2:  6e 10                  bgt.b $40d4
  0040c4:  67 08                  beq.b $40ce
  0040c6:  33 7c 00 04 00 02      move.w #$4, $2(a1)
  0040cc:  60 06                  bra.b $40d4
  0040ce:  33 7c 00 03 00 02      move.w #$3, $2(a1)
  0040d4:  42 69 00 04            clr.w $4(a1)
  0040d8:  0c 38 00 02 01 2f      cmpi.b #$2, $12f.w
  0040de:  6e 0a                  bgt.b $40ea
  0040e0:  10 38 01 2f            move.b $12f.w, d0
  0040e4:  52 40                  addq.w #$1, d0
  0040e6:  13 40 00 07            move.b d0, $7(a1)
  0040ea:  4a 78 02 8e            tst.w $28e.w
  0040ee:  6b 0e                  bmi.b $40fe
  0040f0:  08 38 00 04 0b 22      btst.b #$4, $b22.w
  0040f6:  67 06                  beq.b $40fe
  0040f8:  13 7c 00 01 00 08      move.b #$1, $8(a1)
  0040fe:  0c 78 3f ff 02 8e      cmpi.w #$3fff, $28e.w
  004104:  62 06                  bhi.b $410c
  004106:  13 7c 00 01 00 09      move.b #$1, $9(a1)
  00410c:  10 38 02 1e            move.b $21e.w, d0
  004110:  41 fa ff 5b            lea.l $406d(pc), a0
  004114:  32 3c 00 04            move.w #$4, d1
  004118:  b0 20                  cmp.b -(a0), d0
  00411a:  57 c9 ff fc            dbeq d1, $4118
  00411e:  52 41                  addq.w #$1, d1
  004120:  33 41 00 0a            move.w d1, $a(a1)
  004124:  4a 38 02 91            tst.b $291.w
  004128:  6b 18                  bmi.b $4142
  00412a:  12 38 01 fb            move.b $1fb.w, d1
  00412e:  02 01 00 0f            andi.b #$f, d1
  004132:  0c 01 00 01            cmpi.b #$1, d1
  004136:  66 0a                  bne.b $4142
  004138:  20 78 02 dc            movea.l $2dc.w, a0
  00413c:  13 68 00 07 00 0d      move.b $7(a0), $d(a1)
  004142:  33 78 02 10 00 0e      move.w $210.w, $e(a1)
  004148:  4a 78 03 f6            tst.w $3f6.w
  00414c:  6d 44                  blt.b $4192
  00414e:  42 69 00 0e            clr.w $e(a1)
  004152:  32 3c 00 3c            move.w #$3c, d1
  004156:  42 67                  clr.w -(a7)
  004158:  51 c9 ff fc            dbra d1, $4156
  00415c:  20 4f                  movea.l a7, a0
  00415e:  31 78 0a 58 00 18      move.w $a58.w, $18(a0)
  004164:  70 08                  moveq #$8, d0
  004166:  a2 60                  dc.w $a260
  004168:  66 24                  bne.b $418e
  00416a:  31 68 00 34 00 16      move.w $34(a0), $16(a0)
  004170:  a2 07                  dc.w $a207
  004172:  66 1a                  bne.b $418e
  004174:  21 68 00 5a 00 30      move.l $5a(a0), $30(a0)
  00417a:  21 7c 45 52 49 4b 00 1c move.l #$4552494b, $1c(a0)
  004182:  70 01                  moveq #$1, d0
  004184:  a2 60                  dc.w $a260
  004186:  66 06                  bne.b $418e
  004188:  33 68 00 16 00 0e      move.w $16(a0), $e(a1)
  00418e:  4f ef 00 7a            lea.l $7a(a7), a7
  004192:  20 49                  movea.l a1, a0
  004194:  22 5f                  movea.l (a7)+, a1
  004196:  5c 4f                  addq.w #$6, a7
  004198:  3e bc ea 84            move.w #$ea84, (a7)
  00419c:  4e d1                  jmp (a1)
  00419e:  22 5f                  movea.l (a7)+, a1
  0041a0:  20 5f                  movea.l (a7)+, a0
  0041a2:  a0 25                  dc.w $a025
  0041a4:  2e 80                  move.l d0, (a7)
  0041a6:  6a 02                  bpl.b $41aa
  0041a8:  42 97                  clr.l (a7)
  0041aa:  4e d1                  jmp (a1)
  0041ac:  22 5f                  movea.l (a7)+, a1
  0041ae:  12 1f                  move.b (a7)+, d1
  0041b0:  30 1f                  move.w (a7)+, d0
  0041b2:  4a 01                  tst.b d1
  0041b4:  67 04                  beq.b $41ba
  0041b6:  a7 46                  dc.w $a746
  0041b8:  60 02                  bra.b $41bc
  0041ba:  a3 46                  dc.w $a346
  0041bc:  2e 88                  move.l a0, (a7)
  0041be:  4e d1                  jmp (a1)
  0041c0:  22 5f                  movea.l (a7)+, a1
  0041c2:  12 1f                  move.b (a7)+, d1
  0041c4:  20 5f                  movea.l (a7)+, a0
  0041c6:  70 00                  moveq #$0, d0
  0041c8:  10 18                  move.b (a0)+, d0
  0041ca:  2f 09                  move.l a1, -(a7)
  0041cc:  4a 01                  tst.b d1
  0041ce:  67 04                  beq.b $41d4
  0041d0:  a0 54                  dc.w $a054
  0041d2:  60 02                  bra.b $41d6
  0041d4:  a2 54                  dc.w $a254
  0041d6:  4e 75                  rts 
  0041d8:  22 5f                  movea.l (a7)+, a1
  0041da:  10 1f                  move.b (a7)+, d0
  0041dc:  20 5f                  movea.l (a7)+, a0
  0041de:  66 04                  bne.b $41e4
  0041e0:  a0 03                  dc.w $a003
  0041e2:  60 02                  bra.b $41e6
  0041e4:  a4 03                  dc.w $a403
  0041e6:  3e 80                  move.w d0, (a7)
  0041e8:  4e d1                  jmp (a1)
  0041ea:  22 5f                  movea.l (a7)+, a1
  0041ec:  10 1f                  move.b (a7)+, d0
  0041ee:  20 5f                  movea.l (a7)+, a0
  0041f0:  66 04                  bne.b $41f6
  0041f2:  a0 06                  dc.w $a006
  0041f4:  60 02                  bra.b $41f8
  0041f6:  a4 06                  dc.w $a406
  0041f8:  3e 80                  move.w d0, (a7)
  0041fa:  4e d1                  jmp (a1)
  0041fc:  4e 56 ff ce            link.w a6, #$ffce
  004200:  20 4f                  movea.l a7, a0
  004202:  21 6e 00 0e 00 12      move.l $e(a6), $12(a0)
  004208:  31 6e 00 0c 00 16      move.w $c(a6), $16(a0)
  00420e:  42 28 00 1a            clr.b $1a(a0)
  004212:  42 28 00 1b            clr.b $1b(a0)
  004216:  42 a8 00 1c            clr.l $1c(a0)
  00421a:  70 1a                  moveq #$1a, d0
  00421c:  a0 60                  dc.w $a060
  00421e:  0c 40 ff ce            cmpi.w #$ffce, d0
  004222:  66 02                  bne.b $4226
  004224:  a0 00                  dc.w $a000
  004226:  22 6e 00 08            movea.l $8(a6), a1
  00422a:  32 a8 00 18            move.w $18(a0), (a1)
  00422e:  3d 40 00 12            move.w d0, $12(a6)
  004232:  4e 5e                  unlk a6
  004234:  20 5f                  movea.l (a7)+, a0
  004236:  4f ef 00 0a            lea.l $a(a7), a7
  00423a:  4e d0                  jmp (a0)
  00423c:  4e 56 ff ce            link.w a6, #$ffce
  004240:  20 4f                  movea.l a7, a0
  004242:  31 6e 00 08 00 18      move.w $8(a6), $18(a0)
  004248:  a0 01                  dc.w $a001
  00424a:  3d 40 00 0a            move.w d0, $a(a6)
  00424e:  4e 5e                  unlk a6
  004250:  20 5f                  movea.l (a7)+, a0
  004252:  54 8f                  addq.l #$2, a7
  004254:  4e d0                  jmp (a0)
  004256:  51 c1                  sf.b d1
  004258:  60 02                  bra.b $425c
  00425a:  50 c1                  st.b d1
  00425c:  4e 56 ff ce            link.w a6, #$ffce
  004260:  20 4f                  movea.l a7, a0
  004262:  21 6e 00 08 00 20      move.l $8(a6), $20(a0)
  004268:  31 6e 00 10 00 18      move.w $10(a6), $18(a0)
  00426e:  22 6e 00 0c            movea.l $c(a6), a1
  004272:  21 51 00 24            move.l (a1), $24(a0)
  004276:  42 68 00 2c            clr.w $2c(a0)
  00427a:  42 a8 00 2e            clr.l $2e(a0)
  00427e:  4a 01                  tst.b d1
  004280:  66 04                  bne.b $4286
  004282:  a0 02                  dc.w $a002
  004284:  60 02                  bra.b $4288
  004286:  a0 03                  dc.w $a003
  004288:  3d 40 00 12            move.w d0, $12(a6)
  00428c:  22 6e 00 0c            movea.l $c(a6), a1
  004290:  22 a8 00 28            move.l $28(a0), (a1)
  004294:  4e 5e                  unlk a6
  004296:  22 5f                  movea.l (a7)+, a1
  004298:  4f ef 00 0a            lea.l $a(a7), a7
  00429c:  4e d1                  jmp (a1)
  00429e:  4e 56 ff b0            link.w a6, #$ffb0
  0042a2:  20 4f                  movea.l a7, a0
  0042a4:  21 6e 00 0e 00 12      move.l $e(a6), $12(a0)
  0042aa:  31 6e 00 0c 00 16      move.w $c(a6), $16(a0)
  0042b0:  42 28 00 1a            clr.b $1a(a0)
  0042b4:  42 68 00 1c            clr.w $1c(a0)
  0042b8:  a0 0c                  dc.w $a00c
  0042ba:  3d 40 00 12            move.w d0, $12(a6)
  0042be:  41 e8 00 20            lea.l $20(a0), a0
  0042c2:  22 6e 00 08            movea.l $8(a6), a1
  0042c6:  70 10                  moveq #$10, d0
  0042c8:  a0 2e                  dc.w $a02e
  0042ca:  4e 5e                  unlk a6
  0042cc:  22 5f                  movea.l (a7)+, a1
  0042ce:  4f ef 00 0a            lea.l $a(a7), a7
  0042d2:  4e d1                  jmp (a1)
  0042d4:  4e 56 ff c0            link.w a6, #$ffc0
  0042d8:  20 4f                  movea.l a7, a0
  0042da:  21 6e 00 0c 00 12      move.l $c(a6), $12(a0)
  0042e0:  a0 14                  dc.w $a014
  0042e2:  3d 40 00 10            move.w d0, $10(a6)
  0042e6:  22 6e 00 08            movea.l $8(a6), a1
  0042ea:  32 a8 00 16            move.w $16(a0), (a1)
  0042ee:  4e 5e                  unlk a6
  0042f0:  22 5f                  movea.l (a7)+, a1
  0042f2:  50 8f                  addq.l #$8, a7
  0042f4:  4e d1                  jmp (a1)
  0042f6:  4e 56 ff c0            link.w a6, #$ffc0
  0042fa:  20 4f                  movea.l a7, a0
  0042fc:  31 6e 00 08 00 16      move.w $8(a6), $16(a0)
  004302:  21 6e 00 0a 00 12      move.l $a(a6), $12(a0)
  004308:  a0 13                  dc.w $a013
  00430a:  3d 40 00 0e            move.w d0, $e(a6)
  00430e:  4e 5e                  unlk a6
  004310:  22 5f                  movea.l (a7)+, a1
  004312:  5c 8f                  addq.l #$6, a7
  004314:  4e d1                  jmp (a1)
  004316:  4e 56 ff b0            link.w a6, #$ffb0
  00431a:  20 4f                  movea.l a7, a0
  00431c:  21 6e 00 12 00 12      move.l $12(a6), $12(a0)
  004322:  31 6e 00 10 00 16      move.w $10(a6), $16(a0)
  004328:  42 28 00 1a            clr.b $1a(a0)
  00432c:  a0 08                  dc.w $a008
  00432e:  66 16                  bne.b $4346
  004330:  42 68 00 1c            clr.w $1c(a0)
  004334:  a0 0c                  dc.w $a00c
  004336:  66 0e                  bne.b $4346
  004338:  43 e8 00 20            lea.l $20(a0), a1
  00433c:  22 ee 00 08            move.l $8(a6), (a1)+
  004340:  22 ae 00 0c            move.l $c(a6), (a1)
  004344:  a0 0d                  dc.w $a00d
  004346:  3d 40 00 16            move.w d0, $16(a6)
  00434a:  4e 5e                  unlk a6
  00434c:  22 5f                  movea.l (a7)+, a1
  00434e:  4f ef 00 0e            lea.l $e(a7), a7
  004352:  4e d1                  jmp (a1)
  004354:  4e 56 ff ce            link.w a6, #$ffce
  004358:  20 4f                  movea.l a7, a0
  00435a:  21 6e 00 0a 00 12      move.l $a(a6), $12(a0)
  004360:  31 6e 00 08 00 16      move.w $8(a6), $16(a0)
  004366:  42 28 00 1a            clr.b $1a(a0)
  00436a:  a0 09                  dc.w $a009
  00436c:  3d 40 00 0e            move.w d0, $e(a6)
  004370:  4e 5e                  unlk a6
  004372:  22 5f                  movea.l (a7)+, a1
  004374:  5c 8f                  addq.l #$6, a7
  004376:  4e d1                  jmp (a1)
  004378:  4e 56 ff ce            link.w a6, #$ffce
  00437c:  20 4f                  movea.l a7, a0
  00437e:  22 6e 00 08            movea.l $8(a6), a1
  004382:  21 51 00 24            move.l (a1), $24(a0)
  004386:  31 6e 00 0c 00 18      move.w $c(a6), $18(a0)
  00438c:  a0 10                  dc.w $a010
  00438e:  3d 40 00 0e            move.w d0, $e(a6)
  004392:  22 a8 00 28            move.l $28(a0), (a1)
  004396:  4e 5e                  unlk a6
  004398:  22 5f                  movea.l (a7)+, a1
  00439a:  5c 8f                  addq.l #$6, a7
  00439c:  4e d1                  jmp (a1)
  00439e:  4e 56 ff ce            link.w a6, #$ffce
  0043a2:  20 4f                  movea.l a7, a0
  0043a4:  31 6e 00 0e 00 18      move.w $e(a6), $18(a0)
  0043aa:  31 6e 00 0c 00 2c      move.w $c(a6), $2c(a0)
  0043b0:  21 6e 00 08 00 2e      move.l $8(a6), $2e(a0)
  0043b6:  a0 44                  dc.w $a044
  0043b8:  3d 40 00 10            move.w d0, $10(a6)
  0043bc:  4e 5e                  unlk a6
  0043be:  22 5f                  movea.l (a7)+, a1
  0043c0:  50 8f                  addq.l #$8, a7
  0043c2:  4e d1                  jmp (a1)
  0043c4:  22 6f 00 04            movea.l $4(a7), a1
  0043c8:  42 51                  clr.w (a1)
  0043ca:  20 78 0a ec            movea.l $aec.w, a0
  0043ce:  a0 25                  dc.w $a025
  0043d0:  4a 80                  tst.l d0
  0043d2:  6f 0e                  ble.b $43e2
  0043d4:  20 50                  movea.l (a0), a0
  0043d6:  22 6f 00 08            movea.l $8(a7), a1
  0043da:  32 98                  move.w (a0)+, (a1)
  0043dc:  22 6f 00 04            movea.l $4(a7), a1
  0043e0:  32 90                  move.w (a0), (a1)
  0043e2:  20 5f                  movea.l (a7)+, a0
  0043e4:  50 4f                  addq.w #$8, a7
  0043e6:  4e d0                  jmp (a0)
  0043e8:  48 e7 00 30            movem.l a2-a3, -(a7)
  0043ec:  22 6f 00 0c            movea.l $c(a7), a1
  0043f0:  42 a9 00 02            clr.l $2(a1)
  0043f4:  20 78 0a ec            movea.l $aec.w, a0
  0043f8:  a0 25                  dc.w $a025
  0043fa:  4a 80                  tst.l d0
  0043fc:  6f 26                  ble.b $4424
  0043fe:  24 50                  movea.l (a0), a2
  004400:  54 4a                  addq.w #$2, a2
  004402:  32 2f 00 10            move.w $10(a7), d1
  004406:  b2 5a                  cmp.w (a2)+, d1
  004408:  6e 1a                  bgt.b $4424
  00440a:  53 41                  subq.w #$1, d1
  00440c:  6d 16                  blt.b $4424
  00440e:  20 4a                  movea.l a2, a0
  004410:  70 02                  moveq #$2, d0
  004412:  d0 28 00 08            add.b $8(a0), d0
  004416:  02 40 ff fe            andi.w #$fffe, d0
  00441a:  50 40                  addq.w #$8, d0
  00441c:  d4 c0                  adda.w d0, a2
  00441e:  a0 2e                  dc.w $a02e
  004420:  53 41                  subq.w #$1, d1
  004422:  60 e8                  bra.b $440c
  004424:  4c df 0c 00            movem.l (a7)+, a2-a3
  004428:  20 5f                  movea.l (a7)+, a0
  00442a:  5c 4f                  addq.w #$6, a7
  00442c:  4e d0                  jmp (a0)
  00442e:  20 78 0a ec            movea.l $aec.w, a0
  004432:  a0 25                  dc.w $a025
  004434:  4a 80                  tst.l d0
  004436:  6f 28                  ble.b $4460
  004438:  20 50                  movea.l (a0), a0
  00443a:  54 48                  addq.w #$2, a0
  00443c:  32 2f 00 04            move.w $4(a7), d1
  004440:  b2 58                  cmp.w (a0)+, d1
  004442:  6e 1c                  bgt.b $4460
  004444:  53 41                  subq.w #$1, d1
  004446:  6d 18                  blt.b $4460
  004448:  67 12                  beq.b $445c
  00444a:  70 02                  moveq #$2, d0
  00444c:  d0 28 00 08            add.b $8(a0), d0
  004450:  02 40 ff fe            andi.w #$fffe, d0
  004454:  50 40                  addq.w #$8, d0
  004456:  d0 c0                  adda.w d0, a0
  004458:  53 41                  subq.w #$1, d1
  00445a:  60 ea                  bra.b $4446
  00445c:  42 a8 00 02            clr.l $2(a0)
  004460:  20 5f                  movea.l (a7)+, a0
  004462:  54 4f                  addq.w #$2, a7
  004464:  4e d0                  jmp (a0)
  004466:  20 6f 00 04            movea.l $4(a7), a0
  00446a:  20 2f 00 08            move.l $8(a7), d0
  00446e:  42 67                  clr.w -(a7)
  004470:  a9 ee                  dc.w $a9ee
  004472:  20 5f                  movea.l (a7)+, a0
  004474:  50 4f                  addq.w #$8, a7
  004476:  4e d0                  jmp (a0)
  004478:  22 5f                  movea.l (a7)+, a1
  00447a:  20 1f                  move.l (a7)+, d0
  00447c:  08 38 00 06 02 8e      btst.b #$6, $28e.w
  004482:  66 06                  bne.b $448a
  004484:  a0 55                  dc.w $a055
  004486:  2e 80                  move.l d0, (a7)
  004488:  4e d1                  jmp (a1)
  00448a:  c0 b8 03 1a            and.l $31a.w, d0
  00448e:  2e 80                  move.l d0, (a7)
  004490:  4e d1                  jmp (a1)
  004492:  4e 56 ff f0            link.w a6, #$fff0
  004496:  2f 07                  move.l d7, -(a7)
  004498:  42 2d a7 7e            clr.b -$5882(a5)
  00449c:  7e 01                  moveq #$1, d7
  00449e:  42 67                  clr.w -(a7)
  0044a0:  3f 3c 00 01            move.w #$1, -(a7)
  0044a4:  48 6e ff f0            pea.l -$10(a6)
  0044a8:  4e ba fb 8a            jsr $4034(pc)
  0044ac:  4a 5f                  tst.w (a7)+
  0044ae:  66 04                  bne.b $44b4
  0044b0:  3e 2e ff f4            move.w -$c(a6), d7
  0044b4:  0c 47 06 00            cmpi.w #$600, d7
  0044b8:  65 3a                  bcs.b $44f4
  0044ba:  1b 7c 00 01 a7 7e      move.b #$1, -$5882(a5)
  0044c0:  7e 00                  moveq #$0, d7
  0044c2:  60 2a                  bra.b $44ee
  0044c4:  70 00                  moveq #$0, d0
  0044c6:  30 07                  move.w d7, d0
  0044c8:  20 4d                  movea.l a5, a0
  0044ca:  d1 c0                  adda.l d0, a0
  0044cc:  d1 c0                  adda.l d0, a0
  0044ce:  30 2e ff f2            move.w -$e(a6), d0
  0044d2:  b0 68 a7 5c            cmp.w -$58a4(a0), d0
  0044d6:  66 14                  bne.b $44ec
  0044d8:  0c 6e 00 03 ff f6      cmpi.w #$3, -$a(a6)
  0044de:  6e 0c                  bgt.b $44ec
  0044e0:  4a 6e ff f6            tst.w -$a(a6)
  0044e4:  67 06                  beq.b $44ec
  0044e6:  42 2d a7 7e            clr.b -$5882(a5)
  0044ea:  60 08                  bra.b $44f4
  0044ec:  52 47                  addq.w #$1, d7
  0044ee:  0c 47 00 0a            cmpi.w #$a, d7
  0044f2:  65 d0                  bcs.b $44c4
  0044f4:  10 2d a7 7e            move.b -$5882(a5), d0
  0044f8:  2e 1f                  move.l (a7)+, d7
  0044fa:  4e 5e                  unlk a6
  0044fc:  4e 75                  rts 
  0044fe:  4e 56 00 00            link.w a6, #$0
  004502:  48 e7 03 00            movem.l d6-d7, -(a7)
  004506:  1c 2e 00 08            move.b $8(a6), d6
  00450a:  30 2d a7 7c            move.w -$5884(a5), d0
  00450e:  e0 48                  lsr.w #$8, d0
  004510:  bd 00                  eor.b d6, d0
  004512:  1e 00                  move.b d0, d7
  004514:  70 00                  moveq #$0, d0
  004516:  10 06                  move.b d6, d0
  004518:  d0 6d a7 7c            add.w -$5884(a5), d0
  00451c:  c0 fc ce 6d            mulu.w #$ce6d, d0
  004520:  06 40 58 bf            addi.w #$58bf, d0
  004524:  3b 40 a7 7c            move.w d0, -$5884(a5)
  004528:  10 07                  move.b d7, d0
  00452a:  4c df 00 c0            movem.l (a7)+, d6-d7
  00452e:  4e 5e                  unlk a6
  004530:  4e 75                  rts 
  004532:  4e 56 00 00            link.w a6, #$0
  004536:  48 e7 01 38            movem.l d7/a2-a4, -(a7)
  00453a:  24 6e 00 08            movea.l $8(a6), a2
  00453e:  20 0a                  move.l a2, d0
  004540:  67 30                  beq.b $4572
  004542:  3b 7c dc e5 a7 7c      move.w #$dce5, -$5884(a5)
  004548:  20 4a                  movea.l a2, a0
  00454a:  a0 29                  dc.w $a029
  00454c:  28 52                  movea.l (a2), a4
  00454e:  42 a7                  clr.l -(a7)
  004550:  2f 0a                  move.l a2, -(a7)
  004552:  4e ba fc 4a            jsr $419e(pc)
  004556:  26 4c                  movea.l a4, a3
  004558:  d7 df                  adda.l (a7)+, a3
  00455a:  5e 8c                  addq.l #$7, a4
  00455c:  60 0c                  bra.b $456a
  00455e:  1f 14                  move.b (a4), -(a7)
  004560:  4e ba ff 9c            jsr $44fe(pc)
  004564:  18 80                  move.b d0, (a4)
  004566:  52 8c                  addq.l #$1, a4
  004568:  54 8f                  addq.l #$2, a7
  00456a:  b7 cc                  cmpa.l a4, a3
  00456c:  62 f0                  bhi.b $455e
  00456e:  20 4a                  movea.l a2, a0
  004570:  a0 2a                  dc.w $a02a
  004572:  4c df 1c 80            movem.l (a7)+, d7/a2-a4
  004576:  4e 5e                  unlk a6
  004578:  4e 75                  rts 
  00457a:  4e 56 ff fe            link.w a6, #$fffe
  00457e:  2f 0c                  move.l a4, -(a7)
  004580:  42 a7                  clr.l -(a7)
  004582:  2f 3c 53 4f 4e 47      move.l #$534f4e47, -(a7)
  004588:  3f 2e 00 08            move.w $8(a6), -(a7)
  00458c:  a9 a0                  dc.w $a9a0
  00458e:  28 5f                  movea.l (a7)+, a4
  004590:  20 0c                  move.l a4, d0
  004592:  67 5a                  beq.b $45ee
  004594:  20 54                  movea.l (a4), a0
  004596:  3d 50 00 08            move.w (a0), $8(a6)
  00459a:  4a 2d a7 7b            tst.b -$5885(a5)
  00459e:  67 06                  beq.b $45a6
  0045a0:  20 4c                  movea.l a4, a0
  0045a2:  a0 29                  dc.w $a029
  0045a4:  60 04                  bra.b $45aa
  0045a6:  20 4c                  movea.l a4, a0
  0045a8:  a0 2a                  dc.w $a02a
  0045aa:  4a 2d a7 7a            tst.b -$5886(a5)
  0045ae:  67 06                  beq.b $45b6
  0045b0:  20 4c                  movea.l a4, a0
  0045b2:  a0 49                  dc.w $a049
  0045b4:  60 04                  bra.b $45ba
  0045b6:  20 4c                  movea.l a4, a0
  0045b8:  a0 4a                  dc.w $a04a
  0045ba:  42 a7                  clr.l -(a7)
  0045bc:  2f 3c 4d 49 44 49      move.l #$4d494449, -(a7)
  0045c2:  3f 2e 00 08            move.w $8(a6), -(a7)
  0045c6:  a9 a0                  dc.w $a9a0
  0045c8:  28 5f                  movea.l (a7)+, a4
  0045ca:  20 0c                  move.l a4, d0
  0045cc:  67 20                  beq.b $45ee
  0045ce:  4a 2d a7 7b            tst.b -$5885(a5)
  0045d2:  67 06                  beq.b $45da
  0045d4:  20 4c                  movea.l a4, a0
  0045d6:  a0 29                  dc.w $a029
  0045d8:  60 04                  bra.b $45de
  0045da:  20 4c                  movea.l a4, a0
  0045dc:  a0 2a                  dc.w $a02a
  0045de:  4a 2d a7 7a            tst.b -$5886(a5)
  0045e2:  67 06                  beq.b $45ea
  0045e4:  20 4c                  movea.l a4, a0
  0045e6:  a0 49                  dc.w $a049
  0045e8:  60 04                  bra.b $45ee
  0045ea:  20 4c                  movea.l a4, a0
  0045ec:  a0 4a                  dc.w $a04a
  0045ee:  28 5f                  movea.l (a7)+, a4
  0045f0:  4e 5e                  unlk a6
  0045f2:  4e 75                  rts 
  0045f4:  4e 56 ff fc            link.w a6, #$fffc
  0045f8:  2f 0b                  move.l a3, -(a7)
  0045fa:  20 6e 00 0a            movea.l $a(a6), a0
  0045fe:  42 50                  clr.w (a0)
  004600:  42 a7                  clr.l -(a7)
  004602:  2f 3c 4a 6e 74 68      move.l #$4a6e7468, -(a7)
  004608:  3f 2e 00 08            move.w $8(a6), -(a7)
  00460c:  a9 a0                  dc.w $a9a0
  00460e:  26 5f                  movea.l (a7)+, a3
  004610:  4a ad a7 66            tst.l -$589a(a5)
  004614:  67 08                  beq.b $461e
  004616:  2f 2d a7 66            move.l -$589a(a5), -(a7)
  00461a:  a9 92                  dc.w $a992
  00461c:  60 3e                  bra.b $465c
  00461e:  42 a7                  clr.l -(a7)
  004620:  2f 3c 4d 44 52 56      move.l #$4d445256, -(a7)
  004626:  3f 2e 00 08            move.w $8(a6), -(a7)
  00462a:  a9 a0                  dc.w $a9a0
  00462c:  26 5f                  movea.l (a7)+, a3
  00462e:  20 0b                  move.l a3, d0
  004630:  67 22                  beq.b $4654
  004632:  2f 0b                  move.l a3, -(a7)
  004634:  a9 92                  dc.w $a992
  004636:  2f 0b                  move.l a3, -(a7)
  004638:  4e ba fe f8            jsr $4532(pc)
  00463c:  2e 8b                  move.l a3, (a7)
  00463e:  4e ba 07 9e            jsr $4dde(pc)
  004642:  26 40                  movea.l d0, a3
  004644:  20 0b                  move.l a3, d0
  004646:  58 8f                  addq.l #$4, a7
  004648:  66 12                  bne.b $465c
  00464a:  20 6e 00 0a            movea.l $a(a6), a0
  00464e:  30 bc ff 94            move.w #$ff94, (a0)
  004652:  60 08                  bra.b $465c
  004654:  20 6e 00 0a            movea.l $a(a6), a0
  004658:  30 bc ff 34            move.w #$ff34, (a0)
  00465c:  20 0b                  move.l a3, d0
  00465e:  26 5f                  movea.l (a7)+, a3
  004660:  4e 5e                  unlk a6
  004662:  4e 75                  rts 
  004664:  4e 56 fe e4            link.w a6, #$fee4
  004668:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  00466c:  3e 2e 00 0a            move.w $a(a6), d7
  004670:  7c 00                  moveq #$0, d6
  004672:  30 2e 00 08            move.w $8(a6), d0
  004676:  0c 40 00 0e            cmpi.w #$e, d0
  00467a:  62 00 03 fa            bhi.w $4a76
  00467e:  43 fa 04 00            lea.l $4a80(pc), a1
  004682:  d0 40                  add.w d0, d0
  004684:  d2 f1 00 00            adda.w (a1, d0.w), a1
  004688:  4e d1                  jmp (a1)
  00468a:  1b 47 a7 7b            move.b d7, -$5885(a5)
  00468e:  60 00 03 e6            bra.w $4a76
  004692:  1b 47 a7 7a            move.b d7, -$5886(a5)
  004696:  60 00 03 de            bra.w $4a76
  00469a:  42 67                  clr.w -(a7)
  00469c:  3f 3c 00 01            move.w #$1, -(a7)
  0046a0:  48 6e fe e4            pea.l -$11c(a6)
  0046a4:  4e ba f9 8e            jsr $4034(pc)
  0046a8:  3c 1f                  move.w (a7)+, d6
  0046aa:  48 c6                  ext.l d6
  0046ac:  4a 86                  tst.l d6
  0046ae:  67 0a                  beq.b $46ba
  0046b0:  0c 6e 06 00 fe e8      cmpi.w #$600, -$118(a6)
  0046b6:  6c 02                  bge.b $46ba
  0046b8:  7c 66                  moveq #$66, d6
  0046ba:  4a 86                  tst.l d6
  0046bc:  66 00 03 b8            bne.w $4a76
  0046c0:  4e ba fd d0            jsr $4492(pc)
  0046c4:  1b 40 a7 7e            move.b d0, -$5882(a5)
  0046c8:  32 07                  move.w d7, d1
  0046ca:  67 08                  beq.b $46d4
  0046cc:  6b 32                  bmi.b $4700
  0046ce:  55 41                  subq.w #$2, d1
  0046d0:  6a 2e                  bpl.b $4700
  0046d2:  60 16                  bra.b $46ea
  0046d4:  4a 2d a7 7e            tst.b -$5882(a5)
  0046d8:  67 08                  beq.b $46e2
  0046da:  3d 7c 00 16 ff fe      move.w #$16, -$2(a6)
  0046e0:  60 24                  bra.b $4706
  0046e2:  3d 7c 00 0b ff fe      move.w #$b, -$2(a6)
  0046e8:  60 1c                  bra.b $4706
  0046ea:  4a 2d a7 7e            tst.b -$5882(a5)
  0046ee:  67 08                  beq.b $46f8
  0046f0:  3d 7c 00 0b ff fe      move.w #$b, -$2(a6)
  0046f6:  60 0e                  bra.b $4706
  0046f8:  3d 7c 00 0c ff fe      move.w #$c, -$2(a6)
  0046fe:  60 06                  bra.b $4706
  004700:  3d 7c ff ff ff fe      move.w #$ffff, -$2(a6)
  004706:  0c 6e ff ff ff fe      cmpi.w #$ffff, -$2(a6)
  00470c:  66 06                  bne.b $4714
  00470e:  7c ce                  moveq #$ce, d6
  004710:  60 00 03 64            bra.w $4a76
  004714:  48 6e ff fc            pea.l -$4(a6)
  004718:  3f 2e ff fe            move.w -$2(a6), -(a7)
  00471c:  4e ba fe d6            jsr $45f4(pc)
  004720:  2b 40 a7 66            move.l d0, -$589a(a5)
  004724:  4a 80                  tst.l d0
  004726:  5c 8f                  addq.l #$6, a7
  004728:  66 1a                  bne.b $4744
  00472a:  0c 6e 00 0c ff fe      cmpi.w #$c, -$2(a6)
  004730:  66 12                  bne.b $4744
  004732:  48 6e ff fc            pea.l -$4(a6)
  004736:  3f 3c 00 0b            move.w #$b, -(a7)
  00473a:  4e ba fe b8            jsr $45f4(pc)
  00473e:  2b 40 a7 66            move.l d0, -$589a(a5)
  004742:  5c 8f                  addq.l #$6, a7
  004744:  3c 2e ff fc            move.w -$4(a6), d6
  004748:  48 c6                  ext.l d6
  00474a:  4a ad a7 66            tst.l -$589a(a5)
  00474e:  67 00 03 26            beq.w $4a76
  004752:  20 6d a7 66            movea.l -$589a(a5), a0
  004756:  a0 64                  dc.w $a064
  004758:  20 6d a7 66            movea.l -$589a(a5), a0
  00475c:  a0 4a                  dc.w $a04a
  00475e:  20 6d a7 66            movea.l -$589a(a5), a0
  004762:  a0 29                  dc.w $a029
  004764:  20 6d a7 66            movea.l -$589a(a5), a0
  004768:  2b 50 a7 6a            move.l (a0), -$5896(a5)
  00476c:  3b 7c ff ff a7 6e      move.w #$ffff, -$5892(a5)
  004772:  42 ad a7 72            clr.l -$588e(a5)
  004776:  42 2d a7 70            clr.b -$5890(a5)
  00477a:  42 2d a7 71            clr.b -$588f(a5)
  00477e:  70 00                  moveq #$0, d0
  004780:  10 2d a7 7e            move.b -$5882(a5), d0
  004784:  3f 00                  move.w d0, -(a7)
  004786:  3f 3c 00 10            move.w #$10, -(a7)
  00478a:  22 6d a7 6a            movea.l -$5896(a5), a1
  00478e:  4e 91                  jsr (a1)
  004790:  42 97                  clr.l (a7)
  004792:  20 6d a7 6a            movea.l -$5896(a5), a0
  004796:  4e 90                  jsr (a0)
  004798:  3e bc 00 07            move.w #$7, (a7)
  00479c:  20 6d a7 6a            movea.l -$5896(a5), a0
  0047a0:  4e 90                  jsr (a0)
  0047a2:  1b 7c 00 01 a7 7a      move.b #$1, -$5886(a5)
  0047a8:  42 2d a7 7b            clr.b -$5885(a5)
  0047ac:  42 57                  clr.w (a7)
  0047ae:  4e ba fd ca            jsr $457a(pc)
  0047b2:  58 8f                  addq.l #$4, a7
  0047b4:  60 00 02 c0            bra.w $4a76
  0047b8:  42 2d a7 70            clr.b -$5890(a5)
  0047bc:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  0047c2:  4e ba fe a0            jsr $4664(pc)
  0047c6:  3e bc 00 08            move.w #$8, (a7)
  0047ca:  20 6d a7 6a            movea.l -$5896(a5), a0
  0047ce:  4e 90                  jsr (a0)
  0047d0:  20 6d a7 66            movea.l -$589a(a5), a0
  0047d4:  a0 2a                  dc.w $a02a
  0047d6:  20 6d a7 66            movea.l -$589a(a5), a0
  0047da:  a0 23                  dc.w $a023
  0047dc:  42 ad a7 66            clr.l -$589a(a5)
  0047e0:  99 cc                  suba.l a4, a4
  0047e2:  3d 7c 00 01 ff fc      move.w #$1, -$4(a6)
  0047e8:  58 8f                  addq.l #$4, a7
  0047ea:  42 a7                  clr.l -(a7)
  0047ec:  2f 3c 53 4d 4f 44      move.l #$534d4f44, -(a7)
  0047f2:  3f 2e ff fc            move.w -$4(a6), -(a7)
  0047f6:  a9 9d                  dc.w $a99d
  0047f8:  28 5f                  movea.l (a7)+, a4
  0047fa:  20 0c                  move.l a4, d0
  0047fc:  67 1c                  beq.b $481a
  0047fe:  2f 0c                  move.l a4, -(a7)
  004800:  48 6e ff fe            pea.l -$2(a6)
  004804:  48 6e ff f8            pea.l -$8(a6)
  004808:  48 6e fe f4            pea.l -$10c(a6)
  00480c:  a9 a8                  dc.w $a9a8
  00480e:  20 4c                  movea.l a4, a0
  004810:  a0 2a                  dc.w $a02a
  004812:  20 4c                  movea.l a4, a0
  004814:  a0 49                  dc.w $a049
  004816:  2f 0c                  move.l a4, -(a7)
  004818:  a9 a3                  dc.w $a9a3
  00481a:  52 6e ff fc            addq.w #$1, -$4(a6)
  00481e:  20 0c                  move.l a4, d0
  004820:  66 c8                  bne.b $47ea
  004822:  20 3c 00 80 00 00      move.l #$800000, d0
  004828:  a0 4d                  dc.w $a04d
  00482a:  20 3c 00 80 00 00      move.l #$800000, d0
  004830:  a0 4c                  dc.w $a04c
  004832:  60 00 02 42            bra.w $4a76
  004836:  4a 2d a7 70            tst.b -$5890(a5)
  00483a:  66 00 02 3a            bne.w $4a76
  00483e:  3f 3c 00 0a            move.w #$a, -(a7)
  004842:  20 6d a7 6a            movea.l -$5896(a5), a0
  004846:  4e 90                  jsr (a0)
  004848:  1b 7c 00 01 a7 70      move.b #$1, -$5890(a5)
  00484e:  2b 78 01 6a a7 76      move.l $16a.w, -$588a(a5)
  004854:  54 8f                  addq.l #$2, a7
  004856:  60 00 02 1e            bra.w $4a76
  00485a:  4a 2d a7 70            tst.b -$5890(a5)
  00485e:  67 00 02 16            beq.w $4a76
  004862:  3f 3c 00 0b            move.w #$b, -(a7)
  004866:  20 6d a7 6a            movea.l -$5896(a5), a0
  00486a:  4e 90                  jsr (a0)
  00486c:  42 2d a7 70            clr.b -$5890(a5)
  004870:  20 38 01 6a            move.l $16a.w, d0
  004874:  90 ad a7 76            sub.l -$588a(a5), d0
  004878:  d1 ad a7 72            add.l d0, -$588e(a5)
  00487c:  2f 3c 00 09 00 00      move.l #$90000, -(a7)
  004882:  4e ba fd e0            jsr $4664(pc)
  004886:  5c 8f                  addq.l #$6, a7
  004888:  60 00 01 ec            bra.w $4a76
  00488c:  4a 2d a7 70            tst.b -$5890(a5)
  004890:  66 00 01 e4            bne.w $4a76
  004894:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  00489a:  67 0c                  beq.b $48a8
  00489c:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  0048a2:  4e ba fd c0            jsr $4664(pc)
  0048a6:  58 8f                  addq.l #$4, a7
  0048a8:  2f 3c 00 0d 00 01      move.l #$d0001, -(a7)
  0048ae:  20 6d a7 6a            movea.l -$5896(a5), a0
  0048b2:  4e 90                  jsr (a0)
  0048b4:  58 8f                  addq.l #$4, a7
  0048b6:  60 2a                  bra.b $48e2
  0048b8:  4a 2d a7 70            tst.b -$5890(a5)
  0048bc:  66 00 01 b8            bne.w $4a76
  0048c0:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  0048c6:  67 0c                  beq.b $48d4
  0048c8:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  0048ce:  4e ba fd 94            jsr $4664(pc)
  0048d2:  58 8f                  addq.l #$4, a7
  0048d4:  2f 3c 00 0d 00 00      move.l #$d0000, -(a7)
  0048da:  20 6d a7 6a            movea.l -$5896(a5), a0
  0048de:  4e 90                  jsr (a0)
  0048e0:  58 8f                  addq.l #$4, a7
  0048e2:  3f 07                  move.w d7, -(a7)
  0048e4:  42 67                  clr.w -(a7)
  0048e6:  20 6d a7 6a            movea.l -$5896(a5), a0
  0048ea:  4e 90                  jsr (a0)
  0048ec:  3e bc 00 01            move.w #$1, (a7)
  0048f0:  20 6d a7 6a            movea.l -$5896(a5), a0
  0048f4:  4e 90                  jsr (a0)
  0048f6:  3e bc 00 02            move.w #$2, (a7)
  0048fa:  20 6d a7 6a            movea.l -$5896(a5), a0
  0048fe:  4e 90                  jsr (a0)
  004900:  3b 47 a7 6e            move.w d7, -$5892(a5)
  004904:  2b 78 01 6a a7 72      move.l $16a.w, -$588e(a5)
  00490a:  58 8f                  addq.l #$4, a7
  00490c:  60 00 01 68            bra.w $4a76
  004910:  4a 2d a7 70            tst.b -$5890(a5)
  004914:  66 00 01 60            bne.w $4a76
  004918:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  00491e:  67 00 01 56            beq.w $4a76
  004922:  3f 3c 00 05            move.w #$5, -(a7)
  004926:  20 6d a7 6a            movea.l -$5896(a5), a0
  00492a:  4e 90                  jsr (a0)
  00492c:  3e bc 00 09            move.w #$9, (a7)
  004930:  20 6d a7 6a            movea.l -$5896(a5), a0
  004934:  4e 90                  jsr (a0)
  004936:  3e bc 00 06            move.w #$6, (a7)
  00493a:  20 6d a7 6a            movea.l -$5896(a5), a0
  00493e:  4e 90                  jsr (a0)
  004940:  3e bc 00 07            move.w #$7, (a7)
  004944:  20 6d a7 6a            movea.l -$5896(a5), a0
  004948:  4e 90                  jsr (a0)
  00494a:  3e ad a7 6e            move.w -$5892(a5), (a7)
  00494e:  4e ba fc 2a            jsr $457a(pc)
  004952:  3b 7c ff ff a7 6e      move.w #$ffff, -$5892(a5)
  004958:  42 ad a7 72            clr.l -$588e(a5)
  00495c:  54 8f                  addq.l #$2, a7
  00495e:  60 00 01 16            bra.w $4a76
  004962:  4a 2d a7 70            tst.b -$5890(a5)
  004966:  66 00 01 0e            bne.w $4a76
  00496a:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  004970:  67 00 01 04            beq.w $4a76
  004974:  4a 2d a7 71            tst.b -$588f(a5)
  004978:  66 00 00 fc            bne.w $4a76
  00497c:  1b 7c 00 01 a7 71      move.b #$1, -$588f(a5)
  004982:  3f 3c 00 03            move.w #$3, -(a7)
  004986:  20 6d a7 6a            movea.l -$5896(a5), a0
  00498a:  4e 90                  jsr (a0)
  00498c:  42 2d a7 71            clr.b -$588f(a5)
  004990:  3e bc 00 04            move.w #$4, (a7)
  004994:  20 6d a7 6a            movea.l -$5896(a5), a0
  004998:  4e 90                  jsr (a0)
  00499a:  4a 40                  tst.w d0
  00499c:  54 8f                  addq.l #$2, a7
  00499e:  67 04                  beq.b $49a4
  0049a0:  70 00                  moveq #$0, d0
  0049a2:  60 02                  bra.b $49a6
  0049a4:  70 01                  moveq #$1, d0
  0049a6:  48 c0                  ext.l d0
  0049a8:  2c 00                  move.l d0, d6
  0049aa:  4a 86                  tst.l d6
  0049ac:  67 00 00 c8            beq.w $4a76
  0049b0:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  0049b6:  4e ba fc ac            jsr $4664(pc)
  0049ba:  58 8f                  addq.l #$4, a7
  0049bc:  60 00 00 b8            bra.w $4a76
  0049c0:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  0049c6:  67 04                  beq.b $49cc
  0049c8:  70 00                  moveq #$0, d0
  0049ca:  60 02                  bra.b $49ce
  0049cc:  70 01                  moveq #$1, d0
  0049ce:  48 c0                  ext.l d0
  0049d0:  2c 00                  move.l d0, d6
  0049d2:  4a 2d a7 70            tst.b -$5890(a5)
  0049d6:  66 00 00 9e            bne.w $4a76
  0049da:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  0049e0:  67 00 00 94            beq.w $4a76
  0049e4:  3f 3c 00 04            move.w #$4, -(a7)
  0049e8:  20 6d a7 6a            movea.l -$5896(a5), a0
  0049ec:  4e 90                  jsr (a0)
  0049ee:  4a 40                  tst.w d0
  0049f0:  54 8f                  addq.l #$2, a7
  0049f2:  67 04                  beq.b $49f8
  0049f4:  70 00                  moveq #$0, d0
  0049f6:  60 02                  bra.b $49fa
  0049f8:  70 01                  moveq #$1, d0
  0049fa:  48 c0                  ext.l d0
  0049fc:  2c 00                  move.l d0, d6
  0049fe:  60 76                  bra.b $4a76
  004a00:  7c 00                  moveq #$0, d6
  004a02:  42 67                  clr.w -(a7)
  004a04:  3f 3c 00 01            move.w #$1, -(a7)
  004a08:  48 6e fe e4            pea.l -$11c(a6)
  004a0c:  4e ba f6 26            jsr $4034(pc)
  004a10:  4a 5f                  tst.w (a7)+
  004a12:  66 62                  bne.b $4a76
  004a14:  30 2e fe ea            move.w -$116(a6), d0
  004a18:  6b 10                  bmi.b $4a2a
  004a1a:  59 40                  subq.w #$4, d0
  004a1c:  67 14                  beq.b $4a32
  004a1e:  6a 06                  bpl.b $4a26
  004a20:  52 40                  addq.w #$1, d0
  004a22:  6a 0a                  bpl.b $4a2e
  004a24:  60 04                  bra.b $4a2a
  004a26:  55 40                  subq.w #$2, d0
  004a28:  6b 0c                  bmi.b $4a36
  004a2a:  7c 3c                  moveq #$3c, d6
  004a2c:  60 48                  bra.b $4a76
  004a2e:  7c 25                  moveq #$25, d6
  004a30:  60 44                  bra.b $4a76
  004a32:  7c 11                  moveq #$11, d6
  004a34:  60 40                  bra.b $4a76
  004a36:  7c 00                  moveq #$0, d6
  004a38:  60 3c                  bra.b $4a76
  004a3a:  7c 00                  moveq #$0, d6
  004a3c:  4a 2d a7 70            tst.b -$5890(a5)
  004a40:  66 34                  bne.b $4a76
  004a42:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  004a48:  67 2c                  beq.b $4a76
  004a4a:  2c 38 01 6a            move.l $16a.w, d6
  004a4e:  9c ad a7 72            sub.l -$588e(a5), d6
  004a52:  4a 86                  tst.l d6
  004a54:  6c 20                  bge.b $4a76
  004a56:  7c 00                  moveq #$0, d6
  004a58:  60 1c                  bra.b $4a76
  004a5a:  4a 2d a7 70            tst.b -$5890(a5)
  004a5e:  66 16                  bne.b $4a76
  004a60:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  004a66:  67 0e                  beq.b $4a76
  004a68:  3f 07                  move.w d7, -(a7)
  004a6a:  3f 3c 00 0c            move.w #$c, -(a7)
  004a6e:  20 6d a7 6a            movea.l -$5896(a5), a0
  004a72:  4e 90                  jsr (a0)
  004a74:  58 8f                  addq.l #$4, a7
  004a76:  20 06                  move.l d6, d0
  004a78:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  004a7c:  4e 5e                  unlk a6
  004a7e:  4e 75                  rts 
  004a80:  fc 1a                  dc.w $fc1a
  004a82:  fd 38                  dc.w $fd38
  004a84:  fe 38                  dc.w $fe38
  004a86:  fe 0c                  dc.w $fe0c
  004a88:  fe 90                  dc.w $fe90
  004a8a:  fd b6                  dc.w $fdb6
  004a8c:  fd da                  dc.w $fdda
  004a8e:  ff 40                  dc.w $ff40
  004a90:  ff ba                  dc.w $ffba
  004a92:  fe e2                  dc.w $fee2
  004a94:  ff 80                  dc.w $ff80
  004a96:  ff da                  dc.w $ffda
  004a98:  fc 12                  dc.w $fc12
  004a9a:  fc 0a                  dc.w $fc0a
  004a9c:  ff f6                  dc.w $fff6
  004a9e:  4e 56 00 00            link.w a6, #$0
  004aa2:  2f 2e 00 10            move.l $10(a6), -(a7)
  004aa6:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004aaa:  2f 2e 00 08            move.l $8(a6), -(a7)
  004aae:  4e ba 01 26            jsr $4bd6(pc)
  004ab2:  20 6e 00 14            movea.l $14(a6), a0
  004ab6:  20 80                  move.l d0, (a0)
  004ab8:  4e 5e                  unlk a6
  004aba:  4e 75                  rts 
  004abc:  4e 56 00 00            link.w a6, #$0
  004ac0:  20 6e 00 14            movea.l $14(a6), a0
  004ac4:  2f 10                  move.l (a0), -(a7)
  004ac6:  2f 2e 00 10            move.l $10(a6), -(a7)
  004aca:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004ace:  2f 2e 00 08            move.l $8(a6), -(a7)
  004ad2:  4e ba 01 c4            jsr $4c98(pc)
  004ad6:  4e 5e                  unlk a6
  004ad8:  4e 75                  rts 
  004ada:  4e 56 ff f8            link.w a6, #$fff8
  004ade:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004ae2:  2f 2e 00 08            move.l $8(a6), -(a7)
  004ae6:  4e ba 02 1c            jsr $4d04(pc)
  004aea:  2e ae 00 10            move.l $10(a6), (a7)
  004aee:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004af2:  2f 2e 00 08            move.l $8(a6), -(a7)
  004af6:  4e ba 00 de            jsr $4bd6(pc)
  004afa:  20 6e 00 14            movea.l $14(a6), a0
  004afe:  20 80                  move.l d0, (a0)
  004b00:  2e ae 00 0c            move.l $c(a6), (a7)
  004b04:  2f 2e 00 08            move.l $8(a6), -(a7)
  004b08:  4e ba 02 18            jsr $4d22(pc)
  004b0c:  4e 5e                  unlk a6
  004b0e:  4e 75                  rts 
  004b10:  4e 56 00 00            link.w a6, #$0
  004b14:  20 6e 00 14            movea.l $14(a6), a0
  004b18:  2f 10                  move.l (a0), -(a7)
  004b1a:  2f 2e 00 10            move.l $10(a6), -(a7)
  004b1e:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004b22:  2f 2e 00 08            move.l $8(a6), -(a7)
  004b26:  4e ba 01 70            jsr $4c98(pc)
  004b2a:  20 6e 00 14            movea.l $14(a6), a0
  004b2e:  2e 90                  move.l (a0), (a7)
  004b30:  2f 2e 00 10            move.l $10(a6), -(a7)
  004b34:  4e ba 01 ec            jsr $4d22(pc)
  004b38:  4e 5e                  unlk a6
  004b3a:  4e 75                  rts 
  004b3c:  4e 56 00 00            link.w a6, #$0
  004b40:  48 e7 3e 30            movem.l d2-d6/a2-a3, -(a7)
  004b44:  78 00                  moveq #$0, d4
  004b46:  20 3c 00 00 10 00      move.l #$1000, d0
  004b4c:  22 2e 00 10            move.l $10(a6), d1
  004b50:  b2 80                  cmp.l d0, d1
  004b52:  6c 04                  bge.b $4b58
  004b54:  24 01                  move.l d1, d2
  004b56:  60 02                  bra.b $4b5a
  004b58:  24 00                  move.l d0, d2
  004b5a:  76 12                  moveq #$12, d3
  004b5c:  20 2e 00 0c            move.l $c(a6), d0
  004b60:  90 81                  sub.l d1, d0
  004b62:  b0 82                  cmp.l d2, d0
  004b64:  6d 02                  blt.b $4b68
  004b66:  20 02                  move.l d2, d0
  004b68:  b0 83                  cmp.l d3, d0
  004b6a:  6c 02                  bge.b $4b6e
  004b6c:  26 00                  move.l d0, d3
  004b6e:  20 6e 00 08            movea.l $8(a6), a0
  004b72:  26 48                  movea.l a0, a3
  004b74:  d7 c1                  adda.l d1, a3
  004b76:  24 4b                  movea.l a3, a2
  004b78:  95 c2                  suba.l d2, a2
  004b7a:  7c 00                  moveq #$0, d6
  004b7c:  1c 13                  move.b (a3), d6
  004b7e:  4a 42                  tst.w d2
  004b80:  6f 28                  ble.b $4baa
  004b82:  bc 1a                  cmp.b (a2)+, d6
  004b84:  67 04                  beq.b $4b8a
  004b86:  53 42                  subq.w #$1, d2
  004b88:  60 f4                  bra.b $4b7e
  004b8a:  70 01                  moveq #$1, d0
  004b8c:  43 eb 00 01            lea.l $1(a3), a1
  004b90:  b0 43                  cmp.w d3, d0
  004b92:  6c 08                  bge.b $4b9c
  004b94:  b3 0a                  cmpm.b (a2)+, (a1)+
  004b96:  66 04                  bne.b $4b9c
  004b98:  52 40                  addq.w #$1, d0
  004b9a:  60 f4                  bra.b $4b90
  004b9c:  b0 44                  cmp.w d4, d0
  004b9e:  6f 04                  ble.b $4ba4
  004ba0:  3a 02                  move.w d2, d5
  004ba2:  38 00                  move.w d0, d4
  004ba4:  53 4a                  subq.w #$1, a2
  004ba6:  94 40                  sub.w d0, d2
  004ba8:  60 d4                  bra.b $4b7e
  004baa:  0c 44 00 03            cmpi.w #$3, d4
  004bae:  6d 1c                  blt.b $4bcc
  004bb0:  20 3c 00 00 10 00      move.l #$1000, d0
  004bb6:  90 45                  sub.w d5, d0
  004bb8:  32 04                  move.w d4, d1
  004bba:  57 41                  subq.w #$3, d1
  004bbc:  e1 49                  lsl.w #$8, d1
  004bbe:  e9 49                  lsl.w #$4, d1
  004bc0:  80 41                  or.w d1, d0
  004bc2:  20 6e 00 14            movea.l $14(a6), a0
  004bc6:  30 80                  move.w d0, (a0)
  004bc8:  30 04                  move.w d4, d0
  004bca:  60 02                  bra.b $4bce
  004bcc:  70 00                  moveq #$0, d0
  004bce:  4c df 0c 7c            movem.l (a7)+, d2-d6/a2-a3
  004bd2:  4e 5e                  unlk a6
  004bd4:  4e 75                  rts 
  004bd6:  4e 56 ff e8            link.w a6, #$ffe8
  004bda:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  004bde:  28 6e 00 08            movea.l $8(a6), a4
  004be2:  7e 00                  moveq #$0, d7
  004be4:  26 6e 00 10            movea.l $10(a6), a3
  004be8:  7c 00                  moveq #$0, d6
  004bea:  60 00 00 90            bra.w $4c7c
  004bee:  7a 00                  moveq #$0, d5
  004bf0:  78 00                  moveq #$0, d4
  004bf2:  76 00                  moveq #$0, d3
  004bf4:  60 5c                  bra.b $4c52
  004bf6:  48 6e ff fe            pea.l -$2(a6)
  004bfa:  2f 07                  move.l d7, -(a7)
  004bfc:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004c00:  2f 2e 00 08            move.l $8(a6), -(a7)
  004c04:  4e ba ff 36            jsr $4b3c(pc)
  004c08:  3d 40 ff e8            move.w d0, -$18(a6)
  004c0c:  4a 40                  tst.w d0
  004c0e:  4f ef 00 10            lea.l $10(a7), a7
  004c12:  67 24                  beq.b $4c38
  004c14:  30 2e ff fe            move.w -$2(a6), d0
  004c18:  e0 40                  asr.w #$8, d0
  004c1a:  32 04                  move.w d4, d1
  004c1c:  52 44                  addq.w #$1, d4
  004c1e:  1d 80 10 ee            move.b d0, -$12(a6, d1.w)
  004c22:  70 ff                  moveq #$ff, d0
  004c24:  c0 2e ff ff            and.b -$1(a6), d0
  004c28:  32 04                  move.w d4, d1
  004c2a:  52 44                  addq.w #$1, d4
  004c2c:  1d 80 10 ee            move.b d0, -$12(a6, d1.w)
  004c30:  30 6e ff e8            movea.w -$18(a6), a0
  004c34:  de 88                  add.l a0, d7
  004c36:  60 12                  bra.b $4c4a
  004c38:  30 04                  move.w d4, d0
  004c3a:  52 44                  addq.w #$1, d4
  004c3c:  1d b4 78 00 00 ee      move.b (a4, d7.l), -$12(a6, d0.w)
  004c42:  70 01                  moveq #$1, d0
  004c44:  e7 28                  lsl.b d3, d0
  004c46:  8a 00                  or.b d0, d5
  004c48:  52 87                  addq.l #$1, d7
  004c4a:  be ae 00 0c            cmp.l $c(a6), d7
  004c4e:  6c 08                  bge.b $4c58
  004c50:  52 43                  addq.w #$1, d3
  004c52:  0c 43 00 08            cmpi.w #$8, d3
  004c56:  6d 9e                  blt.b $4bf6
  004c58:  bc ae 00 0c            cmp.l $c(a6), d6
  004c5c:  6c 04                  bge.b $4c62
  004c5e:  17 85 68 00            move.b d5, (a3, d6.l)
  004c62:  52 86                  addq.l #$1, d6
  004c64:  76 00                  moveq #$0, d3
  004c66:  60 10                  bra.b $4c78
  004c68:  bc ae 00 0c            cmp.l $c(a6), d6
  004c6c:  6c 06                  bge.b $4c74
  004c6e:  17 b6 30 ee 68 00      move.b -$12(a6, d3.w), (a3, d6.l)
  004c74:  52 86                  addq.l #$1, d6
  004c76:  52 43                  addq.w #$1, d3
  004c78:  b8 43                  cmp.w d3, d4
  004c7a:  6e ec                  bgt.b $4c68
  004c7c:  be ae 00 0c            cmp.l $c(a6), d7
  004c80:  6d 00 ff 6c            blt.w $4bee
  004c84:  bc ae 00 0c            cmp.l $c(a6), d6
  004c88:  6d 04                  blt.b $4c8e
  004c8a:  70 ff                  moveq #$ff, d0
  004c8c:  60 02                  bra.b $4c90
  004c8e:  20 06                  move.l d6, d0
  004c90:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  004c94:  4e 5e                  unlk a6
  004c96:  4e 75                  rts 
  004c98:  4e 56 00 00            link.w a6, #$0
  004c9c:  48 e7 3f 30            movem.l d2-d7/a2-a3, -(a7)
  004ca0:  24 6e 00 08            movea.l $8(a6), a2
  004ca4:  2c 2e 00 0c            move.l $c(a6), d6
  004ca8:  26 6e 00 10            movea.l $10(a6), a3
  004cac:  2e 2e 00 14            move.l $14(a6), d7
  004cb0:  53 86                  subq.l #$1, d6
  004cb2:  6b 48                  bmi.b $4cfc
  004cb4:  16 1a                  move.b (a2)+, d3
  004cb6:  74 07                  moveq #$7, d2
  004cb8:  e2 0b                  lsr.b #$1, d3
  004cba:  64 10                  bcc.b $4ccc
  004cbc:  53 86                  subq.l #$1, d6
  004cbe:  6b 3c                  bmi.b $4cfc
  004cc0:  53 87                  subq.l #$1, d7
  004cc2:  6b 38                  bmi.b $4cfc
  004cc4:  16 da                  move.b (a2)+, (a3)+
  004cc6:  51 ca ff f0            dbra d2, $4cb8
  004cca:  60 e4                  bra.b $4cb0
  004ccc:  55 86                  subq.l #$2, d6
  004cce:  6b 2c                  bmi.b $4cfc
  004cd0:  10 1a                  move.b (a2)+, d0
  004cd2:  e1 48                  lsl.w #$8, d0
  004cd4:  10 1a                  move.b (a2)+, d0
  004cd6:  3a 00                  move.w d0, d5
  004cd8:  02 45 0f ff            andi.w #$fff, d5
  004cdc:  78 0f                  moveq #$f, d4
  004cde:  e9 58                  rol.w #$4, d0
  004ce0:  c8 40                  and.w d0, d4
  004ce2:  54 44                  addq.w #$2, d4
  004ce4:  20 4b                  movea.l a3, a0
  004ce6:  90 fc 10 00            suba.w #$1000, a0
  004cea:  d0 c5                  adda.w d5, a0
  004cec:  53 87                  subq.l #$1, d7
  004cee:  6b 0c                  bmi.b $4cfc
  004cf0:  16 d8                  move.b (a0)+, (a3)+
  004cf2:  51 cc ff f8            dbra d4, $4cec
  004cf6:  51 ca ff c0            dbra d2, $4cb8
  004cfa:  60 b4                  bra.b $4cb0
  004cfc:  4c df 0c fc            movem.l (a7)+, d2-d7/a2-a3
  004d00:  4e 5e                  unlk a6
  004d02:  4e 75                  rts 
  004d04:  4e 56 00 00            link.w a6, #$0
  004d08:  20 6e 00 08            movea.l $8(a6), a0
  004d0c:  20 2e 00 0c            move.l $c(a6), d0
  004d10:  12 18                  move.b (a0)+, d1
  004d12:  60 06                  bra.b $4d1a
  004d14:  14 10                  move.b (a0), d2
  004d16:  93 18                  sub.b d1, (a0)+
  004d18:  12 02                  move.b d2, d1
  004d1a:  53 80                  subq.l #$1, d0
  004d1c:  66 f6                  bne.b $4d14
  004d1e:  4e 5e                  unlk a6
  004d20:  4e 75                  rts 
  004d22:  4e 56 00 00            link.w a6, #$0
  004d26:  20 6e 00 08            movea.l $8(a6), a0
  004d2a:  20 2e 00 0c            move.l $c(a6), d0
  004d2e:  12 18                  move.b (a0)+, d1
  004d30:  60 04                  bra.b $4d36
  004d32:  d2 10                  add.b (a0), d1
  004d34:  10 c1                  move.b d1, (a0)+
  004d36:  53 80                  subq.l #$1, d0
  004d38:  66 f8                  bne.b $4d32
  004d3a:  4e 5e                  unlk a6
  004d3c:  4e 75                  rts 
  004d3e:  4e 56 ff f8            link.w a6, #$fff8
  004d42:  48 e7 00 38            movem.l a2-a4, -(a7)
  004d46:  28 6e 00 08            movea.l $8(a6), a4
  004d4a:  20 0c                  move.l a4, d0
  004d4c:  67 00 00 86            beq.w $4dd4
  004d50:  42 a7                  clr.l -(a7)
  004d52:  2f 0c                  move.l a4, -(a7)
  004d54:  4e ba f4 48            jsr $419e(pc)
  004d58:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  004d5c:  70 04                  moveq #$4, d0
  004d5e:  d0 ae ff fc            add.l -$4(a6), d0
  004d62:  a1 22                  dc.w $a122
  004d64:  26 48                  movea.l a0, a3
  004d66:  20 0b                  move.l a3, d0
  004d68:  67 6a                  beq.b $4dd4
  004d6a:  20 4b                  movea.l a3, a0
  004d6c:  a0 29                  dc.w $a029
  004d6e:  20 4c                  movea.l a4, a0
  004d70:  a0 29                  dc.w $a029
  004d72:  24 53                  movea.l (a3), a2
  004d74:  58 8a                  addq.l #$4, a2
  004d76:  48 6e ff f8            pea.l -$8(a6)
  004d7a:  2f 0a                  move.l a2, -(a7)
  004d7c:  2f 2e ff fc            move.l -$4(a6), -(a7)
  004d80:  2f 14                  move.l (a4), -(a7)
  004d82:  4e ba fd 1a            jsr $4a9e(pc)
  004d86:  41 ee ff fc            lea.l -$4(a6), a0
  004d8a:  70 04                  moveq #$4, d0
  004d8c:  22 53                  movea.l (a3), a1
  004d8e:  a0 2e                  dc.w $a02e
  004d90:  20 4c                  movea.l a4, a0
  004d92:  a0 2a                  dc.w $a02a
  004d94:  20 4c                  movea.l a4, a0
  004d96:  a0 23                  dc.w $a023
  004d98:  99 cc                  suba.l a4, a4
  004d9a:  70 01                  moveq #$1, d0
  004d9c:  b0 ae ff f8            cmp.l -$8(a6), d0
  004da0:  4f ef 00 10            lea.l $10(a7), a7
  004da4:  6c 2e                  bge.b $4dd4
  004da6:  58 ae ff f8            addq.l #$4, -$8(a6)
  004daa:  20 2e ff f8            move.l -$8(a6), d0
  004dae:  a1 22                  dc.w $a122
  004db0:  28 48                  movea.l a0, a4
  004db2:  20 0c                  move.l a4, d0
  004db4:  67 1a                  beq.b $4dd0
  004db6:  20 4c                  movea.l a4, a0
  004db8:  a0 29                  dc.w $a029
  004dba:  20 4b                  movea.l a3, a0
  004dbc:  a0 29                  dc.w $a029
  004dbe:  20 2e ff f8            move.l -$8(a6), d0
  004dc2:  22 54                  movea.l (a4), a1
  004dc4:  20 53                  movea.l (a3), a0
  004dc6:  a0 2e                  dc.w $a02e
  004dc8:  20 4b                  movea.l a3, a0
  004dca:  a0 2a                  dc.w $a02a
  004dcc:  20 4c                  movea.l a4, a0
  004dce:  a0 2a                  dc.w $a02a
  004dd0:  20 4b                  movea.l a3, a0
  004dd2:  a0 23                  dc.w $a023
  004dd4:  20 0c                  move.l a4, d0
  004dd6:  4c df 1c 00            movem.l (a7)+, a2-a4
  004dda:  4e 5e                  unlk a6
  004ddc:  4e 75                  rts 
  004dde:  4e 56 ff fc            link.w a6, #$fffc
  004de2:  48 e7 00 18            movem.l a3-a4, -(a7)
  004de6:  28 6e 00 08            movea.l $8(a6), a4
  004dea:  20 4c                  movea.l a4, a0
  004dec:  a0 29                  dc.w $a029
  004dee:  43 ee ff fc            lea.l -$4(a6), a1
  004df2:  70 04                  moveq #$4, d0
  004df4:  20 54                  movea.l (a4), a0
  004df6:  a0 2e                  dc.w $a02e
  004df8:  20 4c                  movea.l a4, a0
  004dfa:  a0 2a                  dc.w $a02a
  004dfc:  20 6e ff fc            movea.l -$4(a6), a0
  004e00:  41 e8 01 00            lea.l $100(a0), a0
  004e04:  20 08                  move.l a0, d0
  004e06:  a1 22                  dc.w $a122
  004e08:  26 48                  movea.l a0, a3
  004e0a:  20 0b                  move.l a3, d0
  004e0c:  67 36                  beq.b $4e44
  004e0e:  20 4c                  movea.l a4, a0
  004e10:  a0 29                  dc.w $a029
  004e12:  20 4b                  movea.l a3, a0
  004e14:  a0 29                  dc.w $a029
  004e16:  48 6e ff fc            pea.l -$4(a6)
  004e1a:  2f 13                  move.l (a3), -(a7)
  004e1c:  42 a7                  clr.l -(a7)
  004e1e:  2f 0c                  move.l a4, -(a7)
  004e20:  4e ba f3 7c            jsr $419e(pc)
  004e24:  20 5f                  movea.l (a7)+, a0
  004e26:  48 68 ff fc            pea.l -$4(a0)
  004e2a:  20 54                  movea.l (a4), a0
  004e2c:  48 68 00 04            pea.l $4(a0)
  004e30:  4e ba fc 8a            jsr $4abc(pc)
  004e34:  20 4b                  movea.l a3, a0
  004e36:  a0 2a                  dc.w $a02a
  004e38:  20 4c                  movea.l a4, a0
  004e3a:  a0 2a                  dc.w $a02a
  004e3c:  20 4c                  movea.l a4, a0
  004e3e:  a0 23                  dc.w $a023
  004e40:  4f ef 00 10            lea.l $10(a7), a7
  004e44:  20 0b                  move.l a3, d0
  004e46:  4c df 18 00            movem.l (a7)+, a3-a4
  004e4a:  4e 5e                  unlk a6
  004e4c:  4e 75                  rts 
  004e4e:  53 6f 75 6e            subq.w #$1, $756e(a7)
  004e52:  64 53                  bcc.b $4ea7
  004e54:  79 73                  dc.w $7973
  004e56:  20 26                  move.l -(a6), d0
  004e58:  20 4d                  movea.l a5, a0
  004e5a:  75 73                  dc.w $7573
  004e5c:  69 63                  bvs.b $4ec1
  004e5e:  53 79 73 20 a9 20      subq.w #$1, $7320a920.l
  004e64:  43 6f                  dc.w $436f
  004e66:  70 79                  moveq #$79, d0
  004e68:  72 69                  moveq #$69, d1
  004e6a:  67 68                  beq.b $4ed4
  004e6c:  74 20                  moveq #$20, d2
  004e6e:  31 39 38 39 2d 31      move.w $38392d31.l, -(a0)
  004e74:  39 39 32 20 53 74      move.w $32205374.l, -(a4)
  004e7a:  65 76                  bcs.b $4ef2
  004e7c:  65 20                  bcs.b $4e9e
  004e7e:  48 61                  dc.w $4861
  004e80:  6c 65                  bge.b $4ee7
  004e82:  73 20                  dc.w $7320
  004e84:  26 20                  move.l -(a0), d3
  004e86:  4a 69 6d 20            tst.w $6d20(a1)
  004e8a:  4e 69                  move usp, a1
  004e8c:  74 63                  moveq #$63, d2
  004e8e:  68 61                  bvc.b $4ef1
  004e90:  6c 73                  bge.b $4f05
  004e92:  2c 20                  move.l -(a0), d6
  004e94:  41 6c                  dc.w $416c
  004e96:  6c 20                  bge.b $4eb8
  004e98:  52 69 67 68            addq.w #$1, $6768(a1)
  004e9c:  74 73                  moveq #$73, d2
  004e9e:  20 52                  movea.l (a2), a0
  004ea0:  65 73                  bcs.b $4f15
  004ea2:  65 72                  bcs.b $4f16
  004ea4:  76 65                  moveq #$65, d3
  004ea6:  64 2e                  bcc.b $4ed6
  004ea8:  4c 69                  dc.w $4c69
  004eaa:  63 65                  bls.b $4f11
  004eac:  6e 73                  bgt.b $4f21
  004eae:  65 64                  bcs.b $4f14
  004eb0:  20 74 6f 20 50 72      movea.l $5072(a4, d6.l * 8), a0
  004eb6:  65 73                  bcs.b $4f2b
  004eb8:  61 67                  bsr.b $4f21
  004eba:  65 20                  bcs.b $4edc
  004ebc:  53 6f 66 74            subq.w #$1, $6674(a7)
  004ec0:  77 61                  dc.w $7761
  004ec2:  72 65                  moveq #$65, d1
  004ec4:  20 44                  movea.l d4, a0
  004ec6:  65 76                  bcs.b $4f3e
  004ec8:  65 6c                  bcs.b $4f36
  004eca:  6f 70                  ble.b $4f3c
  004ecc:  65 6d                  bcs.b $4f3b
  004ece:  65 6e                  bcs.b $4f3e
  004ed0:  74 2c                  moveq #$2c, d2
  004ed2:  20 49                  movea.l a1, a0
  004ed4:  6e 63                  bgt.b $4f39
  004ed6:  4e 75                  rts 
  004ed8:  4e 56 00 00            link.w a6, #$0
  004edc:  48 e7 03 38            movem.l d6-d7/a2-a4, -(a7)
  004ee0:  3c 2e 00 08            move.w $8(a6), d6
  004ee4:  99 cc                  suba.l a4, a4
  004ee6:  7e 00                  moveq #$0, d7
  004ee8:  97 cb                  suba.l a3, a3
  004eea:  60 34                  bra.b $4f20
  004eec:  24 4b                  movea.l a3, a2
  004eee:  d5 ed a7 82            adda.l -$587e(a5), a2
  004ef2:  bc 6a 00 1a            cmp.w $1a(a2), d6
  004ef6:  66 22                  bne.b $4f1a
  004ef8:  4a aa 00 02            tst.l $2(a2)
  004efc:  67 04                  beq.b $4f02
  004efe:  28 4a                  movea.l a2, a4
  004f00:  60 24                  bra.b $4f26
  004f02:  42 27                  clr.b -(a7)
  004f04:  2f 0a                  move.l a2, -(a7)
  004f06:  3f 06                  move.w d6, -(a7)
  004f08:  4e ba 02 9e            jsr $51a8(pc)
  004f0c:  4a 00                  tst.b d0
  004f0e:  50 8f                  addq.l #$8, a7
  004f10:  67 08                  beq.b $4f1a
  004f12:  28 4b                  movea.l a3, a4
  004f14:  d9 ed a7 82            adda.l -$587e(a5), a4
  004f18:  60 0c                  bra.b $4f26
  004f1a:  52 47                  addq.w #$1, d7
  004f1c:  47 eb 00 22            lea.l $22(a3), a3
  004f20:  be 6d a7 80            cmp.w -$5880(a5), d7
  004f24:  6d c6                  blt.b $4eec
  004f26:  20 0c                  move.l a4, d0
  004f28:  4c df 1c c0            movem.l (a7)+, d6-d7/a2-a4
  004f2c:  4e 5e                  unlk a6
  004f2e:  4e 75                  rts 
  004f30:  4e 56 00 00            link.w a6, #$0
  004f34:  30 6e 00 08            movea.w $8(a6), a0
  004f38:  2f 08                  move.l a0, -(a7)
  004f3a:  48 78 00 3c            pea.l $3c.w
  004f3e:  2f 2e 00 0a            move.l $a(a6), -(a7)
  004f42:  4e ad 00 42            jsr $42(a5)
  004f46:  2f 00                  move.l d0, -(a7)
  004f48:  4e ad 00 5a            jsr $5a(a5)
  004f4c:  4e 5e                  unlk a6
  004f4e:  4e 75                  rts 
  004f50:  48 e7 1f 38            movem.l d3-d7/a2-a4, -(a7)
  004f54:  20 0d                  move.l a5, d0
  004f56:  2a 78 09 04            movea.l $904.w, a5
  004f5a:  26 00                  move.l d0, d3
  004f5c:  3b 7c 00 01 a7 d6      move.w #$1, -$582a(a5)
  004f62:  4a 2d a7 da            tst.b -$5826(a5)
  004f66:  66 00 01 50            bne.w $50b8
  004f6a:  1b 7c 00 01 a7 da      move.b #$1, -$5826(a5)
  004f70:  4a 6d a7 dc            tst.w -$5824(a5)
  004f74:  6f 04                  ble.b $4f7a
  004f76:  53 6d a7 dc            subq.w #$1, -$5824(a5)
  004f7a:  4a 6d a7 88            tst.w -$5878(a5)
  004f7e:  6f 04                  ble.b $4f84
  004f80:  53 6d a7 88            subq.w #$1, -$5878(a5)
  004f84:  4a ad a8 04            tst.l -$57fc(a5)
  004f88:  67 06                  beq.b $4f90
  004f8a:  20 6d a8 04            movea.l -$57fc(a5), a0
  004f8e:  4e 90                  jsr (a0)
  004f90:  4a 2d a7 e6            tst.b -$581a(a5)
  004f94:  67 00 00 b2            beq.w $5048
  004f98:  20 2d a7 fe            move.l -$5802(a5), d0
  004f9c:  90 ad a7 de            sub.l -$5822(a5), d0
  004fa0:  b0 ad a7 ec            cmp.l -$5814(a5), d0
  004fa4:  6f 00 00 a2            ble.w $5048
  004fa8:  0c 6d ff ff a7 f8      cmpi.w #$ffff, -$5808(a5)
  004fae:  67 28                  beq.b $4fd8
  004fb0:  53 6d a7 f8            subq.w #$1, -$5808(a5)
  004fb4:  4a 6d a7 f8            tst.w -$5808(a5)
  004fb8:  6c 4c                  bge.b $5006
  004fba:  48 78 ff ff            pea.l $ffff.w
  004fbe:  2f 2d a7 f4            move.l -$580c(a5), -(a7)
  004fc2:  3f 2d a7 e4            move.w -$581c(a5), -(a7)
  004fc6:  3f 2d a7 e2            move.w -$581e(a5), -(a7)
  004fca:  4e ba 09 50            jsr $591c(pc)
  004fce:  42 2d a7 e6            clr.b -$581a(a5)
  004fd2:  4f ef 00 0c            lea.l $c(a7), a7
  004fd6:  60 70                  bra.b $5048
  004fd8:  4a ad a7 fa            tst.l -$5806(a5)
  004fdc:  67 28                  beq.b $5006
  004fde:  20 6d a7 fa            movea.l -$5806(a5), a0
  004fe2:  4e 90                  jsr (a0)
  004fe4:  4a 00                  tst.b d0
  004fe6:  67 1e                  beq.b $5006
  004fe8:  48 78 ff ff            pea.l $ffff.w
  004fec:  2f 2d a7 f4            move.l -$580c(a5), -(a7)
  004ff0:  3f 2d a7 e4            move.w -$581c(a5), -(a7)
  004ff4:  3f 2d a7 e2            move.w -$581e(a5), -(a7)
  004ff8:  4e ba 09 22            jsr $591c(pc)
  004ffc:  42 2d a7 e6            clr.b -$581a(a5)
  005000:  4f ef 00 0c            lea.l $c(a7), a7
  005004:  60 42                  bra.b $5048
  005006:  3e 2d a7 f8            move.w -$5808(a5), d7
  00500a:  48 c7                  ext.l d7
  00500c:  24 6d a7 fa            movea.l -$5806(a5), a2
  005010:  1c 2d a7 e6            move.b -$581a(a5), d6
  005014:  2a 2d a7 f0            move.l -$5810(a5), d5
  005018:  28 2d a7 f4            move.l -$580c(a5), d4
  00501c:  2f 2d a7 f4            move.l -$580c(a5), -(a7)
  005020:  2f 2d a7 f0            move.l -$5810(a5), -(a7)
  005024:  3f 2d a7 e4            move.w -$581c(a5), -(a7)
  005028:  3f 2d a7 e2            move.w -$581e(a5), -(a7)
  00502c:  4e ba 09 74            jsr $59a2(pc)
  005030:  2b 44 a7 f4            move.l d4, -$580c(a5)
  005034:  2b 45 a7 f0            move.l d5, -$5810(a5)
  005038:  1b 46 a7 e6            move.b d6, -$581a(a5)
  00503c:  2b 4a a7 fa            move.l a2, -$5806(a5)
  005040:  3b 47 a7 f8            move.w d7, -$5808(a5)
  005044:  4f ef 00 0c            lea.l $c(a7), a7
  005048:  4a ad a7 c2            tst.l -$583e(a5)
  00504c:  67 62                  beq.b $50b0
  00504e:  4a 6d a7 ca            tst.w -$5836(a5)
  005052:  6c 58                  bge.b $50ac
  005054:  30 2d a7 c6            move.w -$583a(a5), d0
  005058:  b0 6d a7 c8            cmp.w -$5838(a5), d0
  00505c:  6c 48                  bge.b $50a6
  00505e:  70 06                  moveq #$6, d0
  005060:  c1 ed a7 c6            muls.w -$583a(a5), d0
  005064:  d0 ad a7 c2            add.l -$583e(a5), d0
  005068:  28 40                  movea.l d0, a4
  00506a:  26 6d a7 c2            movea.l -$583e(a5), a3
  00506e:  0c 54 ff ff            cmpi.w #$ffff, (a4)
  005072:  66 06                  bne.b $507a
  005074:  4e ba 0b 98            jsr $5c0e(pc)
  005078:  60 0c                  bra.b $5086
  00507a:  3f 2c 00 02            move.w $2(a4), -(a7)
  00507e:  3f 14                  move.w (a4), -(a7)
  005080:  4e ba 07 c6            jsr $5848(pc)
  005084:  58 8f                  addq.l #$4, a7
  005086:  0c 6c ff fe 00 04      cmpi.w #$fffe, $4(a4)
  00508c:  66 08                  bne.b $5096
  00508e:  3b 6d a7 dc a7 ca      move.w -$5824(a5), -$5836(a5)
  005094:  60 06                  bra.b $509c
  005096:  3b 6c 00 04 a7 ca      move.w $4(a4), -$5836(a5)
  00509c:  52 6d a7 c6            addq.w #$1, -$583a(a5)
  0050a0:  2b 4b a7 c2            move.l a3, -$583e(a5)
  0050a4:  60 0a                  bra.b $50b0
  0050a6:  42 ad a7 c2            clr.l -$583e(a5)
  0050aa:  60 04                  bra.b $50b0
  0050ac:  53 6d a7 ca            subq.w #$1, -$5836(a5)
  0050b0:  52 ad a7 fe            addq.l #$1, -$5802(a5)
  0050b4:  42 2d a7 da            clr.b -$5826(a5)
  0050b8:  20 03                  move.l d3, d0
  0050ba:  c1 8d                  exg.l d0, a5
  0050bc:  4c df 1c f8            movem.l (a7)+, d3-d7/a2-a4
  0050c0:  4e 75                  rts 
  0050c2:  4e 56 00 00            link.w a6, #$0
  0050c6:  2b 6e 00 08 a8 04      move.l $8(a6), -$57fc(a5)
  0050cc:  4e 5e                  unlk a6
  0050ce:  4e 75                  rts 
  0050d0:  4e 56 00 00            link.w a6, #$0
  0050d4:  4e 5e                  unlk a6
  0050d6:  4e 75                  rts 
  0050d8:  4e 56 00 00            link.w a6, #$0
  0050dc:  2f 07                  move.l d7, -(a7)
  0050de:  20 0d                  move.l a5, d0
  0050e0:  2a 78 09 04            movea.l $904.w, a5
  0050e4:  2e 00                  move.l d0, d7
  0050e6:  4a ad a8 08            tst.l -$57f8(a5)
  0050ea:  67 06                  beq.b $50f2
  0050ec:  20 6d a8 08            movea.l -$57f8(a5), a0
  0050f0:  4e 90                  jsr (a0)
  0050f2:  20 07                  move.l d7, d0
  0050f4:  c1 8d                  exg.l d0, a5
  0050f6:  42 6e 00 0e            clr.w $e(a6)
  0050fa:  2e 1f                  move.l (a7)+, d7
  0050fc:  4e 5e                  unlk a6
  0050fe:  20 5f                  movea.l (a7)+, a0
  005100:  5c 8f                  addq.l #$6, a7
  005102:  4e d0                  jmp (a0)
  005104:  4e 56 ff fc            link.w a6, #$fffc
  005108:  2f 07                  move.l d7, -(a7)
  00510a:  a9 ff                  dc.w $a9ff
  00510c:  20 6e 00 08            movea.l $8(a6), a0
  005110:  3e 28 00 02            move.w $2(a0), d7
  005114:  0c 47 73 6d            cmpi.w #$736d, d7
  005118:  66 24                  bne.b $513e
  00511a:  20 6e 00 08            movea.l $8(a6), a0
  00511e:  20 28 00 04            move.l $4(a0), d0
  005122:  c1 8d                  exg.l d0, a5
  005124:  2e 00                  move.l d0, d7
  005126:  4a ad a8 08            tst.l -$57f8(a5)
  00512a:  67 06                  beq.b $5132
  00512c:  20 6d a8 08            movea.l -$57f8(a5), a0
  005130:  4e 90                  jsr (a0)
  005132:  20 6e 00 08            movea.l $8(a6), a0
  005136:  20 28 00 04            move.l $4(a0), d0
  00513a:  c1 8d                  exg.l d0, a5
  00513c:  2e 00                  move.l d0, d7
  00513e:  2e 1f                  move.l (a7)+, d7
  005140:  4e 5e                  unlk a6
  005142:  20 5f                  movea.l (a7)+, a0
  005144:  50 8f                  addq.l #$8, a7
  005146:  4e d0                  jmp (a0)
  005148:  4e 75                  rts 
  00514a:  4e 56 ff fc            link.w a6, #$fffc
  00514e:  48 e7 00 18            movem.l a3-a4, -(a7)
  005152:  28 6e 00 08            movea.l $8(a6), a4
  005156:  20 4c                  movea.l a4, a0
  005158:  a0 29                  dc.w $a029
  00515a:  43 ee ff fc            lea.l -$4(a6), a1
  00515e:  70 04                  moveq #$4, d0
  005160:  20 54                  movea.l (a4), a0
  005162:  a0 2e                  dc.w $a02e
  005164:  20 2e ff fc            move.l -$4(a6), d0
  005168:  a1 22                  dc.w $a122
  00516a:  26 48                  movea.l a0, a3
  00516c:  20 0b                  move.l a3, d0
  00516e:  67 2a                  beq.b $519a
  005170:  20 4b                  movea.l a3, a0
  005172:  a0 29                  dc.w $a029
  005174:  48 6e ff fc            pea.l -$4(a6)
  005178:  2f 13                  move.l (a3), -(a7)
  00517a:  42 a7                  clr.l -(a7)
  00517c:  2f 0c                  move.l a4, -(a7)
  00517e:  4e ba f0 1e            jsr $419e(pc)
  005182:  20 5f                  movea.l (a7)+, a0
  005184:  48 68 ff fc            pea.l -$4(a0)
  005188:  20 54                  movea.l (a4), a0
  00518a:  48 68 00 04            pea.l $4(a0)
  00518e:  4e ba f9 80            jsr $4b10(pc)
  005192:  20 4b                  movea.l a3, a0
  005194:  a0 2a                  dc.w $a02a
  005196:  4f ef 00 10            lea.l $10(a7), a7
  00519a:  20 4c                  movea.l a4, a0
  00519c:  a0 2a                  dc.w $a02a
  00519e:  20 0b                  move.l a3, d0
  0051a0:  4c df 18 00            movem.l (a7)+, a3-a4
  0051a4:  4e 5e                  unlk a6
  0051a6:  4e 75                  rts 
  0051a8:  4e 56 ff f2            link.w a6, #$fff2
  0051ac:  48 e7 1f 38            movem.l d3-d7/a2-a4, -(a7)
  0051b0:  3e 2e 00 08            move.w $8(a6), d7
  0051b4:  28 6e 00 0a            movea.l $a(a6), a4
  0051b8:  42 2e ff f3            clr.b -$d(a6)
  0051bc:  4a 2e 00 0e            tst.b $e(a6)
  0051c0:  66 00 01 3e            bne.w $5300
  0051c4:  08 94 00 07            bclr.b #$7, (a4)
  0051c8:  42 a7                  clr.l -(a7)
  0051ca:  2f 3c 63 73 6e 64      move.l #$63736e64, -(a7)
  0051d0:  3f 07                  move.w d7, -(a7)
  0051d2:  a9 a0                  dc.w $a9a0
  0051d4:  26 1f                  move.l (a7)+, d3
  0051d6:  4a 83                  tst.l d3
  0051d8:  67 1c                  beq.b $51f6
  0051da:  08 94 00 06            bclr.b #$6, (a4)
  0051de:  2f 03                  move.l d3, -(a7)
  0051e0:  4e ba ff 68            jsr $514a(pc)
  0051e4:  2d 40 ff f4            move.l d0, -$c(a6)
  0051e8:  20 43                  movea.l d3, a0
  0051ea:  a0 49                  dc.w $a049
  0051ec:  2e 83                  move.l d3, (a7)
  0051ee:  a9 a3                  dc.w $a9a3
  0051f0:  26 2e ff f4            move.l -$c(a6), d3
  0051f4:  60 16                  bra.b $520c
  0051f6:  08 d4 00 05            bset.b #$5, (a4)
  0051fa:  08 d4 00 06            bset.b #$6, (a4)
  0051fe:  42 a7                  clr.l -(a7)
  005200:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  005206:  3f 07                  move.w d7, -(a7)
  005208:  a9 a0                  dc.w $a9a0
  00520a:  26 1f                  move.l (a7)+, d3
  00520c:  4a 83                  tst.l d3
  00520e:  67 00 00 f2            beq.w $5302
  005212:  20 43                  movea.l d3, a0
  005214:  a0 69                  dc.w $a069
  005216:  19 40 00 01            move.b d0, $1(a4)
  00521a:  4a 2c 00 01            tst.b $1(a4)
  00521e:  67 06                  beq.b $5226
  005220:  08 94 00 05            bclr.b #$5, (a4)
  005224:  60 04                  bra.b $522a
  005226:  20 43                  movea.l d3, a0
  005228:  a0 64                  dc.w $a064
  00522a:  4a 78 02 20            tst.w $220.w
  00522e:  66 00 00 bc            bne.w $52ec
  005232:  20 43                  movea.l d3, a0
  005234:  a0 29                  dc.w $a029
  005236:  20 43                  movea.l d3, a0
  005238:  24 50                  movea.l (a0), a2
  00523a:  3d 52 ff f8            move.w (a2), -$8(a6)
  00523e:  30 2e ff f8            move.w -$8(a6), d0
  005242:  67 22                  beq.b $5266
  005244:  6b 20                  bmi.b $5266
  005246:  55 40                  subq.w #$2, d0
  005248:  67 12                  beq.b $525c
  00524a:  6a 1a                  bpl.b $5266
  00524c:  38 2a 00 02            move.w $2(a2), d4
  005250:  70 06                  moveq #$6, d0
  005252:  c1 c4                  muls.w d4, d0
  005254:  3d 72 00 04 ff fa      move.w $4(a2, d0.w), -$6(a6)
  00525a:  60 10                  bra.b $526c
  00525c:  78 00                  moveq #$0, d4
  00525e:  3d 6a 00 04 ff fa      move.w $4(a2), -$6(a6)
  005264:  60 06                  bra.b $526c
  005266:  3d 7c ff ff ff f8      move.w #$ffff, -$8(a6)
  00526c:  0c 6e ff ff ff f8      cmpi.w #$ffff, -$8(a6)
  005272:  67 74                  beq.b $52e8
  005274:  70 06                  moveq #$6, d0
  005276:  c1 c4                  muls.w d4, d0
  005278:  30 40                  movea.w d0, a0
  00527a:  30 2e ff fa            move.w -$6(a6), d0
  00527e:  e7 48                  lsl.w #$3, d0
  005280:  5c 40                  addq.w #$6, d0
  005282:  d0 c0                  adda.w d0, a0
  005284:  2d 48 ff fc            move.l a0, -$4(a6)
  005288:  42 a7                  clr.l -(a7)
  00528a:  22 43                  movea.l d3, a1
  00528c:  2f 11                  move.l (a1), -(a7)
  00528e:  4e ba f1 e8            jsr $4478(pc)
  005292:  26 6e ff fc            movea.l -$4(a6), a3
  005296:  d7 df                  adda.l (a7)+, a3
  005298:  29 4b 00 06            move.l a3, $6(a4)
  00529c:  41 eb 00 16            lea.l $16(a3), a0
  0052a0:  29 48 00 0a            move.l a0, $a(a4)
  0052a4:  29 6b 00 04 00 0e      move.l $4(a3), $e(a4)
  0052aa:  29 6b 00 0c 00 12      move.l $c(a3), $12(a4)
  0052b0:  29 6b 00 10 00 16      move.l $10(a3), $16(a4)
  0052b6:  2a 2b 00 08            move.l $8(a3), d5
  0052ba:  70 10                  moveq #$10, d0
  0052bc:  e0 a5                  asr.l d0, d5
  0052be:  39 45 00 1c            move.w d5, $1c(a4)
  0052c2:  4a 2d a8 02            tst.b -$57fe(a5)
  0052c6:  66 18                  bne.b $52e0
  0052c8:  2c 2c 00 0a            move.l $a(a4), d6
  0052cc:  5d 86                  subq.l #$6, d6
  0052ce:  29 46 00 1e            move.l d6, $1e(a4)
  0052d2:  20 46                  movea.l d6, a0
  0052d4:  42 50                  clr.w (a0)
  0052d6:  30 6c 00 1c            movea.w $1c(a4), a0
  0052da:  22 46                  movea.l d6, a1
  0052dc:  23 48 00 02            move.l a0, $2(a1)
  0052e0:  1d 7c 00 01 ff f3      move.b #$1, -$d(a6)
  0052e6:  60 1a                  bra.b $5302
  0052e8:  20 43                  movea.l d3, a0
  0052ea:  a0 2a                  dc.w $a02a
  0052ec:  08 14 00 06            btst.b #$6, (a4)
  0052f0:  67 06                  beq.b $52f8
  0052f2:  2f 03                  move.l d3, -(a7)
  0052f4:  a9 a3                  dc.w $a9a3
  0052f6:  60 04                  bra.b $52fc
  0052f8:  20 43                  movea.l d3, a0
  0052fa:  a0 23                  dc.w $a023
  0052fc:  76 00                  moveq #$0, d3
  0052fe:  60 02                  bra.b $5302
  005300:  76 00                  moveq #$0, d3
  005302:  39 47 00 1a            move.w d7, $1a(a4)
  005306:  29 43 00 02            move.l d3, $2(a4)
  00530a:  10 2e ff f3            move.b -$d(a6), d0
  00530e:  4c df 1c f8            movem.l (a7)+, d3-d7/a2-a4
  005312:  4e 5e                  unlk a6
  005314:  4e 75                  rts 
  005316:  4e 56 00 00            link.w a6, #$0
  00531a:  48 e7 00 38            movem.l a2-a4, -(a7)
  00531e:  28 6e 00 08            movea.l $8(a6), a4
  005322:  4a 6d a7 dc            tst.w -$5824(a5)
  005326:  66 3e                  bne.b $5366
  005328:  4a ad a7 c2            tst.l -$583e(a5)
  00532c:  66 38                  bne.b $5366
  00532e:  45 ec 00 02            lea.l $2(a4), a2
  005332:  26 52                  movea.l (a2), a3
  005334:  20 0b                  move.l a3, d0
  005336:  67 2e                  beq.b $5366
  005338:  08 14 00 06            btst.b #$6, (a4)
  00533c:  67 1a                  beq.b $5358
  00533e:  08 14 00 05            btst.b #$5, (a4)
  005342:  67 0a                  beq.b $534e
  005344:  20 4b                  movea.l a3, a0
  005346:  a0 2a                  dc.w $a02a
  005348:  2f 0b                  move.l a3, -(a7)
  00534a:  a9 a3                  dc.w $a9a3
  00534c:  60 12                  bra.b $5360
  00534e:  10 2c 00 01            move.b $1(a4), d0
  005352:  20 4b                  movea.l a3, a0
  005354:  a0 6a                  dc.w $a06a
  005356:  60 08                  bra.b $5360
  005358:  20 4b                  movea.l a3, a0
  00535a:  a0 2a                  dc.w $a02a
  00535c:  20 4b                  movea.l a3, a0
  00535e:  a0 23                  dc.w $a023
  005360:  42 92                  clr.l (a2)
  005362:  08 94 00 07            bclr.b #$7, (a4)
  005366:  4c df 1c 00            movem.l (a7)+, a2-a4
  00536a:  4e 5e                  unlk a6
  00536c:  4e 75                  rts 
  00536e:  4e 56 00 00            link.w a6, #$0
  005372:  48 e7 07 38            movem.l d5-d7/a2-a4, -(a7)
  005376:  26 6e 00 08            movea.l $8(a6), a3
  00537a:  7a 00                  moveq #$0, d5
  00537c:  28 4b                  movea.l a3, a4
  00537e:  7e 00                  moveq #$0, d7
  005380:  60 02                  bra.b $5384
  005382:  52 47                  addq.w #$1, d7
  005384:  0c 5c ff ff            cmpi.w #$ffff, (a4)+
  005388:  66 f8                  bne.b $5382
  00538a:  4a 47                  tst.w d7
  00538c:  6f 56                  ble.b $53e4
  00538e:  70 22                  moveq #$22, d0
  005390:  c1 c7                  muls.w d7, d0
  005392:  a1 1e                  dc.w $a11e
  005394:  2b 48 a7 82            move.l a0, -$587e(a5)
  005398:  20 08                  move.l a0, d0
  00539a:  67 46                  beq.b $53e2
  00539c:  28 6d a7 82            movea.l -$587e(a5), a4
  0053a0:  7c 22                  moveq #$22, d6
  0053a2:  cc c7                  mulu.w d7, d6
  0053a4:  60 02                  bra.b $53a8
  0053a6:  42 1c                  clr.b (a4)+
  0053a8:  30 06                  move.w d6, d0
  0053aa:  53 46                  subq.w #$1, d6
  0053ac:  4a 40                  tst.w d0
  0053ae:  6e f6                  bgt.b $53a6
  0053b0:  3b 47 a7 80            move.w d7, -$5880(a5)
  0053b4:  7c 00                  moveq #$0, d6
  0053b6:  99 cc                  suba.l a4, a4
  0053b8:  95 ca                  suba.l a2, a2
  0053ba:  60 20                  bra.b $53dc
  0053bc:  1f 2e 00 0c            move.b $c(a6), -(a7)
  0053c0:  20 4a                  movea.l a2, a0
  0053c2:  d1 ed a7 82            adda.l -$587e(a5), a0
  0053c6:  2f 08                  move.l a0, -(a7)
  0053c8:  20 4b                  movea.l a3, a0
  0053ca:  d1 cc                  adda.l a4, a0
  0053cc:  3f 10                  move.w (a0), -(a7)
  0053ce:  4e ba fd d8            jsr $51a8(pc)
  0053d2:  50 8f                  addq.l #$8, a7
  0053d4:  52 46                  addq.w #$1, d6
  0053d6:  54 8c                  addq.l #$2, a4
  0053d8:  45 ea 00 22            lea.l $22(a2), a2
  0053dc:  be 46                  cmp.w d6, d7
  0053de:  6e dc                  bgt.b $53bc
  0053e0:  60 02                  bra.b $53e4
  0053e2:  7a 94                  moveq #$94, d5
  0053e4:  30 05                  move.w d5, d0
  0053e6:  4c df 1c e0            movem.l (a7)+, d5-d7/a2-a4
  0053ea:  4e 5e                  unlk a6
  0053ec:  4e 75                  rts 
  0053ee:  48 e7 01 18            movem.l d7/a3-a4, -(a7)
  0053f2:  4a ad a7 82            tst.l -$587e(a5)
  0053f6:  67 26                  beq.b $541e
  0053f8:  7e 00                  moveq #$0, d7
  0053fa:  97 cb                  suba.l a3, a3
  0053fc:  60 14                  bra.b $5412
  0053fe:  20 4b                  movea.l a3, a0
  005400:  d1 ed a7 82            adda.l -$587e(a5), a0
  005404:  2f 08                  move.l a0, -(a7)
  005406:  4e ba ff 0e            jsr $5316(pc)
  00540a:  58 8f                  addq.l #$4, a7
  00540c:  52 47                  addq.w #$1, d7
  00540e:  47 eb 00 22            lea.l $22(a3), a3
  005412:  be 6d a7 80            cmp.w -$5880(a5), d7
  005416:  6d e6                  blt.b $53fe
  005418:  20 6d a7 82            movea.l -$587e(a5), a0
  00541c:  a0 1f                  dc.w $a01f
  00541e:  4c df 18 80            movem.l (a7)+, d7/a3-a4
  005422:  4e 75                  rts 
  005424:  4e 56 00 00            link.w a6, #$0
  005428:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  00542c:  26 6e 00 08            movea.l $8(a6), a3
  005430:  28 4b                  movea.l a3, a4
  005432:  d9 ee 00 0c            adda.l $c(a6), a4
  005436:  60 0a                  bra.b $5442
  005438:  1e 13                  move.b (a3), d7
  00543a:  1c 14                  move.b (a4), d6
  00543c:  18 87                  move.b d7, (a4)
  00543e:  16 c6                  move.b d6, (a3)+
  005440:  53 8c                  subq.l #$1, a4
  005442:  b9 cb                  cmpa.l a3, a4
  005444:  62 f2                  bhi.b $5438
  005446:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  00544a:  4e 5e                  unlk a6
  00544c:  4e 75                  rts 
  00544e:  2f 07                  move.l d7, -(a7)
  005450:  7e 01                  moveq #$1, d7
  005452:  42 ad a8 0c            clr.l -$57f4(a5)
  005456:  42 ad a8 28            clr.l -$57d8(a5)
  00545a:  42 ad a8 24            clr.l -$57dc(a5)
  00545e:  1b 7c 00 3c a8 2d      move.b #$3c, -$57d3(a5)
  005464:  42 2d a8 2c            clr.b -$57d4(a5)
  005468:  42 67                  clr.w -(a7)
  00546a:  48 6d a8 0c            pea.l -$57f4(a5)
  00546e:  3f 3c 00 05            move.w #$5, -(a7)
  005472:  48 78 00 8c            pea.l $8c.w
  005476:  48 6d 01 aa            pea.l $1aa(a5)
  00547a:  a8 07                  dc.w $a807
  00547c:  4a 5f                  tst.w (a7)+
  00547e:  67 08                  beq.b $5488
  005480:  7e 00                  moveq #$0, d7
  005482:  42 ad a8 0c            clr.l -$57f4(a5)
  005486:  60 0c                  bra.b $5494
  005488:  41 ed 01 aa            lea.l $1aa(a5), a0
  00548c:  22 6d a8 0c            movea.l -$57f4(a5), a1
  005490:  23 48 00 08            move.l a0, $8(a1)
  005494:  10 07                  move.b d7, d0
  005496:  2e 1f                  move.l (a7)+, d7
  005498:  4e 75                  rts 
  00549a:  4a ad a8 0c            tst.l -$57f4(a5)
  00549e:  67 12                  beq.b $54b2
  0054a0:  42 67                  clr.w -(a7)
  0054a2:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  0054a6:  1f 3c 00 01            move.b #$1, -(a7)
  0054aa:  a8 01                  dc.w $a801
  0054ac:  42 ad a8 0c            clr.l -$57f4(a5)
  0054b0:  54 8f                  addq.l #$2, a7
  0054b2:  4e 75                  rts 
  0054b4:  4e 56 ff f0            link.w a6, #$fff0
  0054b8:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  0054bc:  28 6e 00 08            movea.l $8(a6), a4
  0054c0:  42 2d a8 02            clr.b -$57fe(a5)
  0054c4:  7c 01                  moveq #$1, d6
  0054c6:  42 67                  clr.w -(a7)
  0054c8:  3f 3c 00 01            move.w #$1, -(a7)
  0054cc:  48 6e ff f0            pea.l -$10(a6)
  0054d0:  4e ba eb 62            jsr $4034(pc)
  0054d4:  4a 5f                  tst.w (a7)+
  0054d6:  66 04                  bne.b $54dc
  0054d8:  3c 2e ff f4            move.w -$c(a6), d6
  0054dc:  0c 46 06 00            cmpi.w #$600, d6
  0054e0:  65 06                  bcs.b $54e8
  0054e2:  1b 7c 00 01 a8 02      move.b #$1, -$57fe(a5)
  0054e8:  3b 7c 00 03 a7 86      move.w #$3, -$587a(a5)
  0054ee:  42 6d a7 88            clr.w -$5878(a5)
  0054f2:  42 6d a7 dc            clr.w -$5824(a5)
  0054f6:  42 ad a7 c2            clr.l -$583e(a5)
  0054fa:  42 2d a7 8a            clr.b -$5876(a5)
  0054fe:  42 2d a7 db            clr.b -$5825(a5)
  005502:  1f 2e 00 0c            move.b $c(a6), -(a7)
  005506:  2f 0c                  move.l a4, -(a7)
  005508:  4e ba fe 64            jsr $536e(pc)
  00550c:  4a 40                  tst.w d0
  00550e:  5c 8f                  addq.l #$6, a7
  005510:  66 7a                  bne.b $558c
  005512:  4a 2d a8 02            tst.b -$57fe(a5)
  005516:  67 10                  beq.b $5528
  005518:  4e ba ff 34            jsr $544e(pc)
  00551c:  72 00                  moveq #$0, d1
  00551e:  12 00                  move.b d0, d1
  005520:  4a 41                  tst.w d1
  005522:  66 3a                  bne.b $555e
  005524:  42 2d a8 02            clr.b -$57fe(a5)
  005528:  70 07                  moveq #$7, d0
  00552a:  a1 1e                  dc.w $a11e
  00552c:  26 48                  movea.l a0, a3
  00552e:  20 0b                  move.l a3, d0
  005530:  67 2c                  beq.b $555e
  005532:  42 53                  clr.w (a3)
  005534:  42 ab 00 02            clr.l $2(a3)
  005538:  42 ad a7 9c            clr.l -$5864(a5)
  00553c:  3b 7c ff fc a7 a8      move.w #$fffc, -$5858(a5)
  005542:  2b 4b a7 b0            move.l a3, -$5850(a5)
  005546:  42 ad a7 b4            clr.l -$584c(a5)
  00554a:  42 67                  clr.w -(a7)
  00554c:  48 6d a7 90            pea.l -$5870(a5)
  005550:  1f 3c 00 01            move.b #$1, -(a7)
  005554:  4e ba ec 82            jsr $41d8(pc)
  005558:  20 4b                  movea.l a3, a0
  00555a:  a0 1f                  dc.w $a01f
  00555c:  54 8f                  addq.l #$2, a7
  00555e:  42 ad a8 04            clr.l -$57fc(a5)
  005562:  42 ad a8 08            clr.l -$57f8(a5)
  005566:  41 ed 01 b2            lea.l $1b2(a5), a0
  00556a:  2b 48 a7 d2            move.l a0, -$582e(a5)
  00556e:  3b 7c 00 01 a7 d6      move.w #$1, -$582a(a5)
  005574:  3b 7c 00 01 a7 d0      move.w #$1, -$5830(a5)
  00557a:  42 ad a7 cc            clr.l -$5834(a5)
  00557e:  42 6d a7 d8            clr.w -$5828(a5)
  005582:  42 2d a7 da            clr.b -$5826(a5)
  005586:  41 ed a7 cc            lea.l -$5834(a5), a0
  00558a:  a0 33                  dc.w $a033
  00558c:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  005590:  4e 5e                  unlk a6
  005592:  4e 75                  rts 
  005594:  4a 2d a7 8a            tst.b -$5876(a5)
  005598:  66 0a                  bne.b $55a4
  00559a:  4e ba 06 72            jsr $5c0e(pc)
  00559e:  41 ed a7 cc            lea.l -$5834(a5), a0
  0055a2:  a0 34                  dc.w $a034
  0055a4:  42 2d a7 8a            clr.b -$5876(a5)
  0055a8:  4a 2d a8 02            tst.b -$57fe(a5)
  0055ac:  67 04                  beq.b $55b2
  0055ae:  4e ba fe ea            jsr $549a(pc)
  0055b2:  4e ba fe 3a            jsr $53ee(pc)
  0055b6:  4e 75                  rts 
  0055b8:  4a 2d a7 8a            tst.b -$5876(a5)
  0055bc:  66 20                  bne.b $55de
  0055be:  2b 6d a7 c2 a7 8c      move.l -$583e(a5), -$5874(a5)
  0055c4:  4e ba 06 48            jsr $5c0e(pc)
  0055c8:  41 ed a7 cc            lea.l -$5834(a5), a0
  0055cc:  a0 34                  dc.w $a034
  0055ce:  1b 7c 00 01 a7 8a      move.b #$1, -$5876(a5)
  0055d4:  4a 2d a8 02            tst.b -$57fe(a5)
  0055d8:  67 04                  beq.b $55de
  0055da:  4e ba fe be            jsr $549a(pc)
  0055de:  4e 75                  rts 
  0055e0:  4a 2d a7 8a            tst.b -$5876(a5)
  0055e4:  67 22                  beq.b $5608
  0055e6:  42 2d a7 8a            clr.b -$5876(a5)
  0055ea:  2b 6d a7 8c a7 c2      move.l -$5874(a5), -$583e(a5)
  0055f0:  4a 2d a8 02            tst.b -$57fe(a5)
  0055f4:  67 08                  beq.b $55fe
  0055f6:  4e ba fe 56            jsr $544e(pc)
  0055fa:  1b 40 a8 02            move.b d0, -$57fe(a5)
  0055fe:  42 2d a7 da            clr.b -$5826(a5)
  005602:  41 ed a7 cc            lea.l -$5834(a5), a0
  005606:  a0 33                  dc.w $a033
  005608:  4e 75                  rts 
  00560a:  4e 56 ff fc            link.w a6, #$fffc
  00560e:  48 e7 07 38            movem.l d5-d7/a2-a4, -(a7)
  005612:  24 6e 00 08            movea.l $8(a6), a2
  005616:  28 4a                  movea.l a2, a4
  005618:  7e 00                  moveq #$0, d7
  00561a:  60 02                  bra.b $561e
  00561c:  52 47                  addq.w #$1, d7
  00561e:  0c 5c ff ff            cmpi.w #$ffff, (a4)+
  005622:  66 f8                  bne.b $561c
  005624:  7a 22                  moveq #$22, d5
  005626:  cb c7                  muls.w d7, d5
  005628:  4a 47                  tst.w d7
  00562a:  6f 74                  ble.b $56a0
  00562c:  7c 00                  moveq #$0, d6
  00562e:  99 cc                  suba.l a4, a4
  005630:  60 64                  bra.b $5696
  005632:  1f 3c 00 01            move.b #$1, -(a7)
  005636:  a9 9b                  dc.w $a99b
  005638:  42 a7                  clr.l -(a7)
  00563a:  2f 3c 63 73 6e 64      move.l #$63736e64, -(a7)
  005640:  20 4a                  movea.l a2, a0
  005642:  d1 cc                  adda.l a4, a0
  005644:  3f 10                  move.w (a0), -(a7)
  005646:  a9 a0                  dc.w $a9a0
  005648:  26 5f                  movea.l (a7)+, a3
  00564a:  20 0b                  move.l a3, d0
  00564c:  66 26                  bne.b $5674
  00564e:  42 27                  clr.b -(a7)
  005650:  a9 9b                  dc.w $a99b
  005652:  42 a7                  clr.l -(a7)
  005654:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  00565a:  20 4a                  movea.l a2, a0
  00565c:  d1 cc                  adda.l a4, a0
  00565e:  3f 10                  move.w (a0), -(a7)
  005660:  a9 a0                  dc.w $a9a0
  005662:  26 5f                  movea.l (a7)+, a3
  005664:  20 0b                  move.l a3, d0
  005666:  67 22                  beq.b $568a
  005668:  42 a7                  clr.l -(a7)
  00566a:  2f 0b                  move.l a3, -(a7)
  00566c:  a9 a5                  dc.w $a9a5
  00566e:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  005672:  60 16                  bra.b $568a
  005674:  20 4b                  movea.l a3, a0
  005676:  a0 29                  dc.w $a029
  005678:  43 ee ff fc            lea.l -$4(a6), a1
  00567c:  70 04                  moveq #$4, d0
  00567e:  20 53                  movea.l (a3), a0
  005680:  a0 2e                  dc.w $a02e
  005682:  20 4b                  movea.l a3, a0
  005684:  a0 2a                  dc.w $a02a
  005686:  2f 0b                  move.l a3, -(a7)
  005688:  a9 a3                  dc.w $a9a3
  00568a:  20 0b                  move.l a3, d0
  00568c:  67 04                  beq.b $5692
  00568e:  da ae ff fc            add.l -$4(a6), d5
  005692:  52 46                  addq.w #$1, d6
  005694:  54 8c                  addq.l #$2, a4
  005696:  be 46                  cmp.w d6, d7
  005698:  6e 98                  bgt.b $5632
  00569a:  1f 3c 00 01            move.b #$1, -(a7)
  00569e:  a9 9b                  dc.w $a99b
  0056a0:  20 05                  move.l d5, d0
  0056a2:  4c df 1c e0            movem.l (a7)+, d5-d7/a2-a4
  0056a6:  4e 5e                  unlk a6
  0056a8:  4e 75                  rts 
  0056aa:  4e 56 00 00            link.w a6, #$0
  0056ae:  48 e7 00 18            movem.l a3-a4, -(a7)
  0056b2:  99 cc                  suba.l a4, a4
  0056b4:  3f 2e 00 08            move.w $8(a6), -(a7)
  0056b8:  4e ba f8 1e            jsr $4ed8(pc)
  0056bc:  26 40                  movea.l d0, a3
  0056be:  20 0b                  move.l a3, d0
  0056c0:  54 8f                  addq.l #$2, a7
  0056c2:  67 10                  beq.b $56d4
  0056c4:  4a 2d a8 02            tst.b -$57fe(a5)
  0056c8:  67 06                  beq.b $56d0
  0056ca:  28 6b 00 0a            movea.l $a(a3), a4
  0056ce:  60 04                  bra.b $56d4
  0056d0:  28 6b 00 1e            movea.l $1e(a3), a4
  0056d4:  20 0c                  move.l a4, d0
  0056d6:  4c df 18 00            movem.l (a7)+, a3-a4
  0056da:  4e 5e                  unlk a6
  0056dc:  4e 75                  rts 
  0056de:  4e 56 00 00            link.w a6, #$0
  0056e2:  48 e7 01 08            movem.l d7/a4, -(a7)
  0056e6:  7e 00                  moveq #$0, d7
  0056e8:  3f 2e 00 08            move.w $8(a6), -(a7)
  0056ec:  4e ba f7 ea            jsr $4ed8(pc)
  0056f0:  28 40                  movea.l d0, a4
  0056f2:  20 0c                  move.l a4, d0
  0056f4:  54 8f                  addq.l #$2, a7
  0056f6:  67 04                  beq.b $56fc
  0056f8:  2e 2c 00 0e            move.l $e(a4), d7
  0056fc:  20 07                  move.l d7, d0
  0056fe:  4c df 10 80            movem.l (a7)+, d7/a4
  005702:  4e 5e                  unlk a6
  005704:  4e 75                  rts 
  005706:  4e 56 00 00            link.w a6, #$0
  00570a:  3f 2e 00 08            move.w $8(a6), -(a7)
  00570e:  4e ba ff ce            jsr $56de(pc)
  005712:  2f 00                  move.l d0, -(a7)
  005714:  3f 2e 00 0a            move.w $a(a6), -(a7)
  005718:  4e ba f8 16            jsr $4f30(pc)
  00571c:  4e 5e                  unlk a6
  00571e:  4e 75                  rts 
  005720:  4e 56 00 00            link.w a6, #$0
  005724:  48 e7 01 08            movem.l d7/a4, -(a7)
  005728:  7e 00                  moveq #$0, d7
  00572a:  3f 2e 00 08            move.w $8(a6), -(a7)
  00572e:  4e ba f7 a8            jsr $4ed8(pc)
  005732:  28 40                  movea.l d0, a4
  005734:  20 0c                  move.l a4, d0
  005736:  54 8f                  addq.l #$2, a7
  005738:  67 04                  beq.b $573e
  00573a:  3e 2c 00 1c            move.w $1c(a4), d7
  00573e:  30 07                  move.w d7, d0
  005740:  4c df 10 80            movem.l (a7)+, d7/a4
  005744:  4e 5e                  unlk a6
  005746:  4e 75                  rts 
  005748:  4e 56 00 00            link.w a6, #$0
  00574c:  3b 6e 00 08 a7 86      move.w $8(a6), -$587a(a5)
  005752:  4e 5e                  unlk a6
  005754:  4e 75                  rts 
  005756:  4e 56 00 00            link.w a6, #$0
  00575a:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  00575e:  28 6e 00 08            movea.l $8(a6), a4
  005762:  2c 2e 00 0c            move.l $c(a6), d6
  005766:  3a 2e 00 10            move.w $10(a6), d5
  00576a:  20 0c                  move.l a4, d0
  00576c:  67 00 00 d2            beq.w $5840
  005770:  4a 2d a7 8a            tst.b -$5876(a5)
  005774:  66 00 00 ca            bne.w $5840
  005778:  4a 6d a7 88            tst.w -$5878(a5)
  00577c:  6f 08                  ble.b $5786
  00577e:  4a ad a7 c2            tst.l -$583e(a5)
  005782:  67 00 00 bc            beq.w $5840
  005786:  3b 6d a7 86 a7 88      move.w -$587a(a5), -$5878(a5)
  00578c:  2f 06                  move.l d6, -(a7)
  00578e:  3f 05                  move.w d5, -(a7)
  005790:  4e ba f7 9e            jsr $4f30(pc)
  005794:  48 c0                  ext.l d0
  005796:  2e 00                  move.l d0, d7
  005798:  4a 2d a7 db            tst.b -$5825(a5)
  00579c:  5c 8f                  addq.l #$6, a7
  00579e:  66 12                  bne.b $57b2
  0057a0:  18 2d a7 e6            move.b -$581a(a5), d4
  0057a4:  4e ba 04 68            jsr $5c0e(pc)
  0057a8:  1b 44 a7 e6            move.b d4, -$581a(a5)
  0057ac:  3b 47 a7 dc            move.w d7, -$5824(a5)
  0057b0:  60 04                  bra.b $57b6
  0057b2:  df 6d a7 dc            add.w d7, -$5824(a5)
  0057b6:  2b 6d a7 fe a7 de      move.l -$5802(a5), -$5822(a5)
  0057bc:  4a 2d a8 02            tst.b -$57fe(a5)
  0057c0:  67 44                  beq.b $5806
  0057c2:  41 ec 00 06            lea.l $6(a4), a0
  0057c6:  2b 48 a8 18            move.l a0, -$57e8(a5)
  0057ca:  2b 46 a8 1c            move.l d6, -$57e4(a5)
  0057ce:  42 ad a8 24            clr.l -$57dc(a5)
  0057d2:  42 ad a8 28            clr.l -$57d8(a5)
  0057d6:  20 05                  move.l d5, d0
  0057d8:  48 c0                  ext.l d0
  0057da:  72 10                  moveq #$10, d1
  0057dc:  e3 a8                  lsl.l d1, d0
  0057de:  2b 40 a8 20            move.l d0, -$57e0(a5)
  0057e2:  42 6d a8 12            clr.w -$57ee(a5)
  0057e6:  41 ed a8 18            lea.l -$57e8(a5), a0
  0057ea:  2b 48 a8 14            move.l a0, -$57ec(a5)
  0057ee:  3b 7c 00 51 a8 10      move.w #$51, -$57f0(a5)
  0057f4:  42 67                  clr.w -(a7)
  0057f6:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  0057fa:  48 6d a8 10            pea.l -$57f0(a5)
  0057fe:  42 27                  clr.b -(a7)
  005800:  a8 03                  dc.w $a803
  005802:  54 8f                  addq.l #$2, a7
  005804:  60 3a                  bra.b $5840
  005806:  42 54                  clr.w (a4)
  005808:  42 a7                  clr.l -(a7)
  00580a:  30 45                  movea.w d5, a0
  00580c:  2f 08                  move.l a0, -(a7)
  00580e:  2f 3c 00 02 f9 b8      move.l #$2f9b8, -(a7)
  005814:  a8 68                  dc.w $a868
  005816:  29 5f 00 02            move.l (a7)+, $2(a4)
  00581a:  41 ed 01 ba            lea.l $1ba(a5), a0
  00581e:  2b 48 a7 9c            move.l a0, -$5864(a5)
  005822:  3b 7c ff fc a7 a8      move.w #$fffc, -$5858(a5)
  005828:  2b 4c a7 b0            move.l a4, -$5850(a5)
  00582c:  2b 46 a7 b4            move.l d6, -$584c(a5)
  005830:  42 67                  clr.w -(a7)
  005832:  48 6d a7 90            pea.l -$5870(a5)
  005836:  1f 3c 00 01            move.b #$1, -(a7)
  00583a:  4e ba e9 9c            jsr $41d8(pc)
  00583e:  54 8f                  addq.l #$2, a7
  005840:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  005844:  4e 5e                  unlk a6
  005846:  4e 75                  rts 
  005848:  4e 56 00 00            link.w a6, #$0
  00584c:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  005850:  3c 2e 00 0a            move.w $a(a6), d6
  005854:  4a 2d a7 8a            tst.b -$5876(a5)
  005858:  66 50                  bne.b $58aa
  00585a:  42 2d a7 db            clr.b -$5825(a5)
  00585e:  3f 2e 00 08            move.w $8(a6), -(a7)
  005862:  4e ba f6 74            jsr $4ed8(pc)
  005866:  28 40                  movea.l d0, a4
  005868:  20 0c                  move.l a4, d0
  00586a:  54 8f                  addq.l #$2, a7
  00586c:  67 3c                  beq.b $58aa
  00586e:  4a 14                  tst.b (a4)
  005870:  6a 12                  bpl.b $5884
  005872:  2f 2c 00 0e            move.l $e(a4), -(a7)
  005876:  2f 2c 00 0a            move.l $a(a4), -(a7)
  00587a:  4e ba fb a8            jsr $5424(pc)
  00587e:  08 94 00 07            bclr.b #$7, (a4)
  005882:  50 8f                  addq.l #$8, a7
  005884:  4a 46                  tst.w d6
  005886:  66 04                  bne.b $588c
  005888:  3c 2c 00 1c            move.w $1c(a4), d6
  00588c:  2e 2c 00 0e            move.l $e(a4), d7
  005890:  70 fa                  moveq #$fa, d0
  005892:  d0 ac 00 0a            add.l $a(a4), d0
  005896:  26 40                  movea.l d0, a3
  005898:  42 2d a7 e6            clr.b -$581a(a5)
  00589c:  3f 06                  move.w d6, -(a7)
  00589e:  2f 07                  move.l d7, -(a7)
  0058a0:  2f 0b                  move.l a3, -(a7)
  0058a2:  4e ba fe b2            jsr $5756(pc)
  0058a6:  4f ef 00 0a            lea.l $a(a7), a7
  0058aa:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  0058ae:  4e 5e                  unlk a6
  0058b0:  4e 75                  rts 
  0058b2:  4e 56 00 00            link.w a6, #$0
  0058b6:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  0058ba:  3c 2e 00 0a            move.w $a(a6), d6
  0058be:  4a 2d a7 8a            tst.b -$5876(a5)
  0058c2:  66 50                  bne.b $5914
  0058c4:  42 2d a7 db            clr.b -$5825(a5)
  0058c8:  3f 2e 00 08            move.w $8(a6), -(a7)
  0058cc:  4e ba f6 0a            jsr $4ed8(pc)
  0058d0:  28 40                  movea.l d0, a4
  0058d2:  20 0c                  move.l a4, d0
  0058d4:  54 8f                  addq.l #$2, a7
  0058d6:  67 3c                  beq.b $5914
  0058d8:  4a 14                  tst.b (a4)
  0058da:  6b 12                  bmi.b $58ee
  0058dc:  2f 2c 00 0e            move.l $e(a4), -(a7)
  0058e0:  2f 2c 00 0a            move.l $a(a4), -(a7)
  0058e4:  4e ba fb 3e            jsr $5424(pc)
  0058e8:  08 d4 00 07            bset.b #$7, (a4)
  0058ec:  50 8f                  addq.l #$8, a7
  0058ee:  4a 46                  tst.w d6
  0058f0:  66 04                  bne.b $58f6
  0058f2:  3c 2c 00 1c            move.w $1c(a4), d6
  0058f6:  2e 2c 00 0e            move.l $e(a4), d7
  0058fa:  70 fa                  moveq #$fa, d0
  0058fc:  d0 ac 00 0a            add.l $a(a4), d0
  005900:  26 40                  movea.l d0, a3
  005902:  42 2d a7 e6            clr.b -$581a(a5)
  005906:  3f 06                  move.w d6, -(a7)
  005908:  2f 07                  move.l d7, -(a7)
  00590a:  2f 0b                  move.l a3, -(a7)
  00590c:  4e ba fe 48            jsr $5756(pc)
  005910:  4f ef 00 0a            lea.l $a(a7), a7
  005914:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  005918:  4e 5e                  unlk a6
  00591a:  4e 75                  rts 
  00591c:  4e 56 00 00            link.w a6, #$0
  005920:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  005924:  3c 2e 00 0a            move.w $a(a6), d6
  005928:  2a 2e 00 10            move.l $10(a6), d5
  00592c:  4a 2d a7 8a            tst.b -$5876(a5)
  005930:  66 68                  bne.b $599a
  005932:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  005938:  3f 2e 00 08            move.w $8(a6), -(a7)
  00593c:  4e ba f5 9a            jsr $4ed8(pc)
  005940:  28 40                  movea.l d0, a4
  005942:  20 0c                  move.l a4, d0
  005944:  54 8f                  addq.l #$2, a7
  005946:  67 52                  beq.b $599a
  005948:  4a 14                  tst.b (a4)
  00594a:  6a 12                  bpl.b $595e
  00594c:  2f 2c 00 0e            move.l $e(a4), -(a7)
  005950:  2f 2c 00 0a            move.l $a(a4), -(a7)
  005954:  4e ba fa ce            jsr $5424(pc)
  005958:  08 94 00 07            bclr.b #$7, (a4)
  00595c:  50 8f                  addq.l #$8, a7
  00595e:  4a 46                  tst.w d6
  005960:  66 04                  bne.b $5966
  005962:  3c 2c 00 1c            move.w $1c(a4), d6
  005966:  70 ff                  moveq #$ff, d0
  005968:  b0 85                  cmp.l d5, d0
  00596a:  67 06                  beq.b $5972
  00596c:  ba ac 00 0e            cmp.l $e(a4), d5
  005970:  6f 04                  ble.b $5976
  005972:  2a 2c 00 0e            move.l $e(a4), d5
  005976:  2e 05                  move.l d5, d7
  005978:  9e ae 00 0c            sub.l $c(a6), d7
  00597c:  70 fa                  moveq #$fa, d0
  00597e:  d0 ae 00 0c            add.l $c(a6), d0
  005982:  d0 ac 00 0a            add.l $a(a4), d0
  005986:  26 40                  movea.l d0, a3
  005988:  42 2d a7 e6            clr.b -$581a(a5)
  00598c:  3f 06                  move.w d6, -(a7)
  00598e:  2f 07                  move.l d7, -(a7)
  005990:  2f 0b                  move.l a3, -(a7)
  005992:  4e ba fd c2            jsr $5756(pc)
  005996:  4f ef 00 0a            lea.l $a(a7), a7
  00599a:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  00599e:  4e 5e                  unlk a6
  0059a0:  4e 75                  rts 
  0059a2:  4e 56 00 00            link.w a6, #$0
  0059a6:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  0059aa:  3e 2e 00 0a            move.w $a(a6), d7
  0059ae:  26 2e 00 0c            move.l $c(a6), d3
  0059b2:  28 2e 00 10            move.l $10(a6), d4
  0059b6:  4a 2d a7 8a            tst.b -$5876(a5)
  0059ba:  66 00 00 b8            bne.w $5a74
  0059be:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  0059c4:  3f 2e 00 08            move.w $8(a6), -(a7)
  0059c8:  4e ba f5 0e            jsr $4ed8(pc)
  0059cc:  28 40                  movea.l d0, a4
  0059ce:  20 0c                  move.l a4, d0
  0059d0:  54 8f                  addq.l #$2, a7
  0059d2:  67 00 00 a0            beq.w $5a74
  0059d6:  4a 14                  tst.b (a4)
  0059d8:  6a 12                  bpl.b $59ec
  0059da:  2f 2c 00 0e            move.l $e(a4), -(a7)
  0059de:  2f 2c 00 0a            move.l $a(a4), -(a7)
  0059e2:  4e ba fa 40            jsr $5424(pc)
  0059e6:  08 94 00 07            bclr.b #$7, (a4)
  0059ea:  50 8f                  addq.l #$8, a7
  0059ec:  4a 47                  tst.w d7
  0059ee:  66 04                  bne.b $59f4
  0059f0:  3e 2c 00 1c            move.w $1c(a4), d7
  0059f4:  2a 2c 00 0e            move.l $e(a4), d5
  0059f8:  2c 05                  move.l d5, d6
  0059fa:  70 fa                  moveq #$fa, d0
  0059fc:  d0 ac 00 0a            add.l $a(a4), d0
  005a00:  26 40                  movea.l d0, a3
  005a02:  ba 84                  cmp.l d4, d5
  005a04:  6c 02                  bge.b $5a08
  005a06:  28 05                  move.l d5, d4
  005a08:  1b 7c 00 01 a7 e6      move.b #$1, -$581a(a5)
  005a0e:  2b 43 a7 f0            move.l d3, -$5810(a5)
  005a12:  2b 44 a7 f4            move.l d4, -$580c(a5)
  005a16:  3b 47 a7 e4            move.w d7, -$581c(a5)
  005a1a:  2f 03                  move.l d3, -(a7)
  005a1c:  3f 07                  move.w d7, -(a7)
  005a1e:  4e ba f5 10            jsr $4f30(pc)
  005a22:  30 40                  movea.w d0, a0
  005a24:  2b 48 a7 e8            move.l a0, -$5818(a5)
  005a28:  2e 84                  move.l d4, (a7)
  005a2a:  3f 07                  move.w d7, -(a7)
  005a2c:  4e ba f5 02            jsr $4f30(pc)
  005a30:  30 40                  movea.w d0, a0
  005a32:  91 ed a7 e8            suba.l -$5818(a5), a0
  005a36:  2b 48 a7 ec            move.l a0, -$5814(a5)
  005a3a:  4a 2d a8 02            tst.b -$57fe(a5)
  005a3e:  50 8f                  addq.l #$8, a7
  005a40:  67 08                  beq.b $5a4a
  005a42:  5b ad a7 e8            subq.l #$5, -$5818(a5)
  005a46:  5b ad a7 ec            subq.l #$5, -$5814(a5)
  005a4a:  3b 6e 00 08 a7 e2      move.w $8(a6), -$581e(a5)
  005a50:  3b 7c ff ff a7 f8      move.w #$ffff, -$5808(a5)
  005a56:  42 ad a7 fa            clr.l -$5806(a5)
  005a5a:  2c 04                  move.l d4, d6
  005a5c:  9c 83                  sub.l d3, d6
  005a5e:  26 6c 00 0a            movea.l $a(a4), a3
  005a62:  47 f3 38 fa            lea.l -$6(a3, d3.l), a3
  005a66:  3f 07                  move.w d7, -(a7)
  005a68:  2f 06                  move.l d6, -(a7)
  005a6a:  2f 0b                  move.l a3, -(a7)
  005a6c:  4e ba fc e8            jsr $5756(pc)
  005a70:  4f ef 00 0a            lea.l $a(a7), a7
  005a74:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  005a78:  4e 5e                  unlk a6
  005a7a:  4e 75                  rts 
  005a7c:  4e 56 00 00            link.w a6, #$0
  005a80:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  005a84:  3e 2e 00 0a            move.w $a(a6), d7
  005a88:  4a 2d a7 8a            tst.b -$5876(a5)
  005a8c:  66 00 00 a6            bne.w $5b34
  005a90:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  005a96:  3f 2e 00 08            move.w $8(a6), -(a7)
  005a9a:  4e ba f4 3c            jsr $4ed8(pc)
  005a9e:  28 40                  movea.l d0, a4
  005aa0:  20 0c                  move.l a4, d0
  005aa2:  54 8f                  addq.l #$2, a7
  005aa4:  67 00 00 8e            beq.w $5b34
  005aa8:  4a 14                  tst.b (a4)
  005aaa:  6a 12                  bpl.b $5abe
  005aac:  2f 2c 00 0e            move.l $e(a4), -(a7)
  005ab0:  2f 2c 00 0a            move.l $a(a4), -(a7)
  005ab4:  4e ba f9 6e            jsr $5424(pc)
  005ab8:  08 94 00 07            bclr.b #$7, (a4)
  005abc:  50 8f                  addq.l #$8, a7
  005abe:  4a 47                  tst.w d7
  005ac0:  66 04                  bne.b $5ac6
  005ac2:  3e 2c 00 1c            move.w $1c(a4), d7
  005ac6:  42 2d a7 e6            clr.b -$581a(a5)
  005aca:  2b 6c 00 12 a7 f0      move.l $12(a4), -$5810(a5)
  005ad0:  2b 6c 00 16 a7 f4      move.l $16(a4), -$580c(a5)
  005ad6:  3a 2d a7 86            move.w -$587a(a5), d5
  005ada:  42 6d a7 86            clr.w -$587a(a5)
  005ade:  42 6d a7 88            clr.w -$5878(a5)
  005ae2:  2c 2d a7 f4            move.l -$580c(a5), d6
  005ae6:  70 fa                  moveq #$fa, d0
  005ae8:  d0 ac 00 0a            add.l $a(a4), d0
  005aec:  26 40                  movea.l d0, a3
  005aee:  3f 07                  move.w d7, -(a7)
  005af0:  2f 06                  move.l d6, -(a7)
  005af2:  2f 0b                  move.l a3, -(a7)
  005af4:  4e ba fc 60            jsr $5756(pc)
  005af8:  70 fa                  moveq #$fa, d0
  005afa:  d0 ad a7 f0            add.l -$5810(a5), d0
  005afe:  d0 ac 00 0a            add.l $a(a4), d0
  005b02:  26 40                  movea.l d0, a3
  005b04:  2c 2d a7 f4            move.l -$580c(a5), d6
  005b08:  9c ad a7 f0            sub.l -$5810(a5), d6
  005b0c:  4f ef 00 0a            lea.l $a(a7), a7
  005b10:  60 0e                  bra.b $5b20
  005b12:  3f 07                  move.w d7, -(a7)
  005b14:  2f 06                  move.l d6, -(a7)
  005b16:  2f 0b                  move.l a3, -(a7)
  005b18:  4e ba fc 3c            jsr $5756(pc)
  005b1c:  4f ef 00 0a            lea.l $a(a7), a7
  005b20:  30 2e 00 0c            move.w $c(a6), d0
  005b24:  53 6e 00 0c            subq.w #$1, $c(a6)
  005b28:  4a 40                  tst.w d0
  005b2a:  66 e6                  bne.b $5b12
  005b2c:  3b 45 a7 86            move.w d5, -$587a(a5)
  005b30:  42 2d a7 db            clr.b -$5825(a5)
  005b34:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  005b38:  4e 5e                  unlk a6
  005b3a:  4e 75                  rts 
  005b3c:  4e 56 00 00            link.w a6, #$0
  005b40:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  005b44:  3e 2e 00 0a            move.w $a(a6), d7
  005b48:  7a ff                  moveq #$ff, d5
  005b4a:  2b 6e 00 0c a7 fa      move.l $c(a6), -$5806(a5)
  005b50:  4a 2d a7 8a            tst.b -$5876(a5)
  005b54:  66 00 00 b0            bne.w $5c06
  005b58:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  005b5e:  3f 2e 00 08            move.w $8(a6), -(a7)
  005b62:  4e ba f3 74            jsr $4ed8(pc)
  005b66:  28 40                  movea.l d0, a4
  005b68:  20 0c                  move.l a4, d0
  005b6a:  54 8f                  addq.l #$2, a7
  005b6c:  67 00 00 98            beq.w $5c06
  005b70:  4a 14                  tst.b (a4)
  005b72:  6a 12                  bpl.b $5b86
  005b74:  2f 2c 00 0e            move.l $e(a4), -(a7)
  005b78:  2f 2c 00 0a            move.l $a(a4), -(a7)
  005b7c:  4e ba f8 a6            jsr $5424(pc)
  005b80:  08 94 00 07            bclr.b #$7, (a4)
  005b84:  50 8f                  addq.l #$8, a7
  005b86:  4a 47                  tst.w d7
  005b88:  66 04                  bne.b $5b8e
  005b8a:  3e 2c 00 1c            move.w $1c(a4), d7
  005b8e:  1b 7c 00 01 a7 e6      move.b #$1, -$581a(a5)
  005b94:  2b 6c 00 12 a7 f0      move.l $12(a4), -$5810(a5)
  005b9a:  2b 6c 00 16 a7 f4      move.l $16(a4), -$580c(a5)
  005ba0:  2c 2d a7 f4            move.l -$580c(a5), d6
  005ba4:  70 fa                  moveq #$fa, d0
  005ba6:  d0 ac 00 0a            add.l $a(a4), d0
  005baa:  26 40                  movea.l d0, a3
  005bac:  3b 47 a7 e4            move.w d7, -$581c(a5)
  005bb0:  2f 2d a7 f0            move.l -$5810(a5), -(a7)
  005bb4:  3f 07                  move.w d7, -(a7)
  005bb6:  4e ba f3 78            jsr $4f30(pc)
  005bba:  30 40                  movea.w d0, a0
  005bbc:  2b 48 a7 e8            move.l a0, -$5818(a5)
  005bc0:  2e ad a7 f4            move.l -$580c(a5), (a7)
  005bc4:  3f 07                  move.w d7, -(a7)
  005bc6:  4e ba f3 68            jsr $4f30(pc)
  005bca:  30 40                  movea.w d0, a0
  005bcc:  2b 48 a7 ec            move.l a0, -$5814(a5)
  005bd0:  4a 2d a8 02            tst.b -$57fe(a5)
  005bd4:  50 8f                  addq.l #$8, a7
  005bd6:  67 08                  beq.b $5be0
  005bd8:  5b ad a7 e8            subq.l #$5, -$5818(a5)
  005bdc:  5b ad a7 ec            subq.l #$5, -$5814(a5)
  005be0:  3b 6e 00 08 a7 e2      move.w $8(a6), -$581e(a5)
  005be6:  3b 45 a7 f8            move.w d5, -$5808(a5)
  005bea:  0c 45 ff ff            cmpi.w #$ffff, d5
  005bee:  67 08                  beq.b $5bf8
  005bf0:  42 ad a7 fa            clr.l -$5806(a5)
  005bf4:  53 6d a7 f8            subq.w #$1, -$5808(a5)
  005bf8:  3f 07                  move.w d7, -(a7)
  005bfa:  2f 06                  move.l d6, -(a7)
  005bfc:  2f 0b                  move.l a3, -(a7)
  005bfe:  4e ba fb 56            jsr $5756(pc)
  005c02:  4f ef 00 0a            lea.l $a(a7), a7
  005c06:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  005c0a:  4e 5e                  unlk a6
  005c0c:  4e 75                  rts 
  005c0e:  4a 2d a7 8a            tst.b -$5876(a5)
  005c12:  66 60                  bne.b $5c74
  005c14:  42 2d a7 db            clr.b -$5825(a5)
  005c18:  42 ad a7 c2            clr.l -$583e(a5)
  005c1c:  42 6d a7 dc            clr.w -$5824(a5)
  005c20:  42 2d a7 e6            clr.b -$581a(a5)
  005c24:  4a 2d a8 02            tst.b -$57fe(a5)
  005c28:  67 28                  beq.b $5c52
  005c2a:  3b 7c 00 04 a8 10      move.w #$4, -$57f0(a5)
  005c30:  42 67                  clr.w -(a7)
  005c32:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  005c36:  48 6d a8 10            pea.l -$57f0(a5)
  005c3a:  a8 04                  dc.w $a804
  005c3c:  3b 7c 00 03 a8 10      move.w #$3, -$57f0(a5)
  005c42:  42 57                  clr.w (a7)
  005c44:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  005c48:  48 6d a8 10            pea.l -$57f0(a5)
  005c4c:  a8 04                  dc.w $a804
  005c4e:  54 8f                  addq.l #$2, a7
  005c50:  60 22                  bra.b $5c74
  005c52:  42 ad a7 9c            clr.l -$5864(a5)
  005c56:  3b 7c ff fc a7 a8      move.w #$fffc, -$5858(a5)
  005c5c:  42 ad a7 b0            clr.l -$5850(a5)
  005c60:  42 ad a7 b4            clr.l -$584c(a5)
  005c64:  42 67                  clr.w -(a7)
  005c66:  48 6d a7 90            pea.l -$5870(a5)
  005c6a:  1f 3c 00 01            move.b #$1, -(a7)
  005c6e:  4e ba e5 7a            jsr $41ea(pc)
  005c72:  54 8f                  addq.l #$2, a7
  005c74:  4e 75                  rts 
  005c76:  4a 6d a7 dc            tst.w -$5824(a5)
  005c7a:  6f 04                  ble.b $5c80
  005c7c:  70 00                  moveq #$0, d0
  005c7e:  60 02                  bra.b $5c82
  005c80:  70 01                  moveq #$1, d0
  005c82:  4e 75                  rts 
  005c84:  4e 56 00 00            link.w a6, #$0
  005c88:  48 e7 03 38            movem.l d6-d7/a2-a4, -(a7)
  005c8c:  26 6e 00 08            movea.l $8(a6), a3
  005c90:  3c 2e 00 0c            move.w $c(a6), d6
  005c94:  4a 2d a7 8a            tst.b -$5876(a5)
  005c98:  66 30                  bne.b $5cca
  005c9a:  4e ba ff 72            jsr $5c0e(pc)
  005c9e:  7e 00                  moveq #$0, d7
  005ca0:  95 ca                  suba.l a2, a2
  005ca2:  60 12                  bra.b $5cb6
  005ca4:  20 4b                  movea.l a3, a0
  005ca6:  d1 ca                  adda.l a2, a0
  005ca8:  3f 10                  move.w (a0), -(a7)
  005caa:  4e ba f2 2c            jsr $4ed8(pc)
  005cae:  28 40                  movea.l d0, a4
  005cb0:  54 8f                  addq.l #$2, a7
  005cb2:  52 47                  addq.w #$1, d7
  005cb4:  5c 8a                  addq.l #$6, a2
  005cb6:  bc 47                  cmp.w d7, d6
  005cb8:  6e ea                  bgt.b $5ca4
  005cba:  42 6d a7 c6            clr.w -$583a(a5)
  005cbe:  42 6d a7 ca            clr.w -$5836(a5)
  005cc2:  3b 46 a7 c8            move.w d6, -$5838(a5)
  005cc6:  2b 4b a7 c2            move.l a3, -$583e(a5)
  005cca:  4c df 1c c0            movem.l (a7)+, d6-d7/a2-a4
  005cce:  4e 5e                  unlk a6
  005cd0:  4e 75                  rts 
  005cd2:  2f 07                  move.l d7, -(a7)
  005cd4:  7e 00                  moveq #$0, d7
  005cd6:  4a 2d a7 8a            tst.b -$5876(a5)
  005cda:  66 08                  bne.b $5ce4
  005cdc:  4a ad a7 c2            tst.l -$583e(a5)
  005ce0:  66 02                  bne.b $5ce4
  005ce2:  7e 01                  moveq #$1, d7
  005ce4:  10 07                  move.b d7, d0
  005ce6:  2e 1f                  move.l (a7)+, d7
  005ce8:  4e 75                  rts 
  005cea:  4e 56 00 00            link.w a6, #$0
  005cee:  48 e7 01 08            movem.l d7/a4, -(a7)
  005cf2:  7e 00                  moveq #$0, d7
  005cf4:  99 cc                  suba.l a4, a4
  005cf6:  60 1c                  bra.b $5d14
  005cf8:  a0 1c                  dc.w $a01c
  005cfa:  b0 ae 00 08            cmp.l $8(a6), d0
  005cfe:  64 0e                  bcc.b $5d0e
  005d00:  20 4c                  movea.l a4, a0
  005d02:  d1 ed a7 82            adda.l -$587e(a5), a0
  005d06:  2f 08                  move.l a0, -(a7)
  005d08:  4e ba f6 0c            jsr $5316(pc)
  005d0c:  58 8f                  addq.l #$4, a7
  005d0e:  52 47                  addq.w #$1, d7
  005d10:  49 ec 00 22            lea.l $22(a4), a4
  005d14:  be 6d a7 80            cmp.w -$5880(a5), d7
  005d18:  6d de                  blt.b $5cf8
  005d1a:  4c df 10 80            movem.l (a7)+, d7/a4
  005d1e:  4e 5e                  unlk a6
  005d20:  4e 75                  rts 
  005d22:  4e 56 00 00            link.w a6, #$0
  005d26:  20 2e 00 08            move.l $8(a6), d0
  005d2a:  4e 5e                  unlk a6
  005d2c:  4e 75                  rts 
  005d2e:  4e 56 00 00            link.w a6, #$0
  005d32:  2f 0c                  move.l a4, -(a7)
  005d34:  3f 2e 00 08            move.w $8(a6), -(a7)
  005d38:  4e ba f1 9e            jsr $4ed8(pc)
  005d3c:  28 40                  movea.l d0, a4
  005d3e:  20 0c                  move.l a4, d0
  005d40:  54 8f                  addq.l #$2, a7
  005d42:  67 14                  beq.b $5d58
  005d44:  4a 2e 00 0a            tst.b $a(a6)
  005d48:  57 c0                  seq.b d0
  005d4a:  44 00                  neg.b d0
  005d4c:  02 14 00 df            andi.b #$df, (a4)
  005d50:  eb 08                  lsl.b #$5, d0
  005d52:  02 00 00 20            andi.b #$20, d0
  005d56:  81 14                  or.b d0, (a4)
  005d58:  28 5f                  movea.l (a7)+, a4
  005d5a:  4e 5e                  unlk a6
  005d5c:  4e 75                  rts 