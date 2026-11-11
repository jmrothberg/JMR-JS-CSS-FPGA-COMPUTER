; prince-of-persia-demo: Prince of Persia Demo, CODE resource 2 (22226 bytes)
; 68000 disassembly (linear sweep). Code starts after the 4-byte segment header.
; Words $Axxx are Mac Toolbox/OS traps; known ones are annotated. Globals are (a5)-relative.

  000004:  4e ba 01 6a            jsr $170(pc)
  000008:  4a 2d 96 be            tst.b -$6942(a5)
  00000c:  66 04                  bne.b $12
  00000e:  4e ba 01 c8            jsr $1d8(pc)
  000012:  4a 2d 96 be            tst.b -$6942(a5)
  000016:  66 04                  bne.b $1c
  000018:  4e ba 02 72            jsr $28c(pc)
  00001c:  4a 2d 96 be            tst.b -$6942(a5)
  000020:  66 04                  bne.b $26
  000022:  4e ba 03 00            jsr $324(pc)
  000026:  4a 2d 96 be            tst.b -$6942(a5)
  00002a:  66 04                  bne.b $30
  00002c:  4e ba 04 08            jsr $436(pc)
  000030:  4a 2d 96 be            tst.b -$6942(a5)
  000034:  66 04                  bne.b $3a
  000036:  4e ba 18 24            jsr $185c(pc)
  00003a:  42 a7                  clr.l -(a7)
  00003c:  a9 75                  dc.w $a975   ; _TickCount
  00003e:  2b 5f a5 5e            move.l (a7)+, -$5aa2(a5)
  000042:  42 ad 96 ec            clr.l -$6914(a5)
  000046:  42 ad 96 f0            clr.l -$6910(a5)
  00004a:  60 00 00 fe            bra.w $14a
  00004e:  4a 2d 96 ba            tst.b -$6946(a5)
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
  000078:  4e ba 0c 80            jsr $cfa(pc)
  00007c:  4a 2d 96 bb            tst.b -$6945(a5)
  000080:  67 00 00 c8            beq.w $14a
  000084:  4e ba 25 a4            jsr $262a(pc)
  000088:  4a 2d 96 cc            tst.b -$6934(a5)
  00008c:  67 56                  beq.b $e4
  00008e:  30 2d 96 e8            move.w -$6918(a5), d0
  000092:  0c 40 00 0b            cmpi.w #$b, d0
  000096:  62 4c                  bhi.b $e4
  000098:  43 fa 00 be            lea.l $158(pc), a1
  00009c:  d0 40                  add.w d0, d0
  00009e:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0000a2:  4e d1                  jmp (a1)
  0000a4:  4e ba 18 36            jsr $18dc(pc)
  0000a8:  60 3a                  bra.b $e4
  0000aa:  4e ba 18 64            jsr $1910(pc)
  0000ae:  60 34                  bra.b $e4
  0000b0:  4e ba 18 c2            jsr $1974(pc)
  0000b4:  60 2e                  bra.b $e4
  0000b6:  4e ba 19 36            jsr $19ee(pc)
  0000ba:  60 28                  bra.b $e4
  0000bc:  4e ba 19 6c            jsr $1a2a(pc)
  0000c0:  60 22                  bra.b $e4
  0000c2:  4e ba 19 b0            jsr $1a74(pc)
  0000c6:  60 1c                  bra.b $e4
  0000c8:  4e ba 19 ca            jsr $1a94(pc)
  0000cc:  60 16                  bra.b $e4
  0000ce:  4e ba 1a 08            jsr $1ad8(pc)
  0000d2:  60 10                  bra.b $e4
  0000d4:  4e ba 1a 04            jsr $1ada(pc)
  0000d8:  60 0a                  bra.b $e4
  0000da:  4e ba 1a 4e            jsr $1b2a(pc)
  0000de:  60 04                  bra.b $e4
  0000e0:  4e ba 1a c8            jsr $1baa(pc)
  0000e4:  4a 2d 96 cf            tst.b -$6931(a5)
  0000e8:  67 08                  beq.b $f2
  0000ea:  42 2d 96 cc            clr.b -$6934(a5)
  0000ee:  42 2d 96 cf            clr.b -$6931(a5)
  0000f2:  42 a7                  clr.l -(a7)
  0000f4:  a9 75                  dc.w $a975   ; _TickCount
  0000f6:  2b 5f a5 62            move.l (a7)+, -$5a9e(a5)
  0000fa:  4e ba 25 2e            jsr $262a(pc)
  0000fe:  20 2d a5 62            move.l -$5a9e(a5), d0
  000102:  90 ad a5 5e            sub.l -$5aa2(a5), d0
  000106:  b0 ad 96 ec            cmp.l -$6914(a5), d0
  00010a:  6f e6                  ble.b $f2
  00010c:  2b 6d a5 62 a5 5e      move.l -$5a9e(a5), -$5aa2(a5)
  000112:  4e ba 15 26            jsr $163a(pc)
  000116:  42 27                  clr.b -(a7)
  000118:  3f 3c 00 40            move.w #$40, -(a7)
  00011c:  48 6d a1 e8            pea.l -$5e18(a5)
  000120:  a9 71                  dc.w $a971   ; _WaitMouseUp
  000122:  4a 1f                  tst.b (a7)+
  000124:  67 0a                  beq.b $130
  000126:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  00012a:  4e ba 0e 04            jsr $f30(pc)
  00012e:  58 8f                  addq.l #$4, a7
  000130:  4e ba 24 f8            jsr $262a(pc)
  000134:  4a 6d f2 2a            tst.w -$dd6(a5)
  000138:  67 04                  beq.b $13e
  00013a:  4e ba 16 14            jsr $1750(pc)
  00013e:  4e ba 24 ea            jsr $262a(pc)
  000142:  4e ba 16 7a            jsr $17be(pc)
  000146:  52 ad 96 f0            addq.l #$1, -$6910(a5)
  00014a:  4a 2d 96 be            tst.b -$6942(a5)
  00014e:  67 00 fe fe            beq.w $4e
  000152:  4e ba 0b 58            jsr $cac(pc)
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
  0001c2:  1b 7c 00 01 96 cb      move.b #$1, -$6935(a5)
  0001c8:  08 2d 00 03 a1 f6      btst.b #$3, -$5e0a(a5)
  0001ce:  67 06                  beq.b $1d6
  0001d0:  1b 7c 00 01 96 ca      move.b #$1, -$6936(a5)
  0001d6:  4e 75                  rts 
  0001d8:  4e 56 ff fc            link.w a6, #$fffc
  0001dc:  42 67                  clr.w -(a7)
  0001de:  3f 3c 00 01            move.w #$1, -(a7)
  0001e2:  48 6d a0 90            pea.l -$5f70(a5)
  0001e6:  4e ba 38 68            jsr $3a50(pc)
  0001ea:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0001ee:  4a 6d a1 6c            tst.w -$5e94(a5)
  0001f2:  66 00 00 82            bne.w $276
  0001f6:  0c 6d 06 00 a0 94      cmpi.w #$600, -$5f6c(a5)
  0001fc:  6d 0e                  blt.b $20c
  0001fe:  0c 6d 00 03 a0 96      cmpi.w #$3, -$5f6a(a5)
  000204:  6d 06                  blt.b $20c
  000206:  1b 7c 00 01 96 b8      move.b #$1, -$6948(a5)
  00020c:  4a 2d a0 99            tst.b -$5f67(a5)
  000210:  67 2a                  beq.b $23c
  000212:  42 a7                  clr.l -(a7)
  000214:  2f 3c 01 00 ab 03      move.l #$100ab03, -(a7)
  00021a:  4e ba 39 ac            jsr $3bc8(pc)
  00021e:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  000222:  42 a7                  clr.l -(a7)
  000224:  2f 3c 01 00 a8 9f      move.l #$100a89f, -(a7)
  00022a:  4e ba 39 9c            jsr $3bc8(pc)
  00022e:  20 2e ff fc            move.l -$4(a6), d0
  000232:  b0 9f                  cmp.l (a7)+, d0
  000234:  67 06                  beq.b $23c
  000236:  1b 7c 00 01 96 b9      move.b #$1, -$6947(a5)
  00023c:  4a 6d a0 92            tst.w -$5f6e(a5)
  000240:  6f 46                  ble.b $288
  000242:  0c 6d 06 00 a0 94      cmpi.w #$600, -$5f6c(a5)
  000248:  6c 24                  bge.b $26e
  00024a:  42 a7                  clr.l -(a7)
  00024c:  2f 3c 01 00 a8 60      move.l #$100a860, -(a7)
  000252:  4e ba 39 74            jsr $3bc8(pc)
  000256:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  00025a:  42 a7                  clr.l -(a7)
  00025c:  2f 3c 01 00 a8 9f      move.l #$100a89f, -(a7)
  000262:  4e ba 39 64            jsr $3bc8(pc)
  000266:  20 2e ff fc            move.l -$4(a6), d0
  00026a:  b0 9f                  cmp.l (a7)+, d0
  00026c:  67 1a                  beq.b $288
  00026e:  1b 7c 00 01 96 ba      move.b #$1, -$6946(a5)
  000274:  60 12                  bra.b $288
  000276:  42 67                  clr.w -(a7)
  000278:  3f 3c 03 e8            move.w #$3e8, -(a7)
  00027c:  42 a7                  clr.l -(a7)
  00027e:  a9 85                  dc.w $a985
  000280:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  000286:  54 8f                  addq.l #$2, a7
  000288:  4e 5e                  unlk a6
  00028a:  4e 75                  rts 
  00028c:  42 a7                  clr.l -(a7)
  00028e:  3f 3c 03 e8            move.w #$3e8, -(a7)
  000292:  a9 bf                  dc.w $a9bf
  000294:  2b 5f a1 d0            move.l (a7)+, -$5e30(a5)
  000298:  2f 2d a1 d0            move.l -$5e30(a5), -(a7)
  00029c:  4e ba 1f 9c            jsr $223a(pc)
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
  0002ca:  4e ba 1f 6e            jsr $223a(pc)
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
  0002ec:  4e ba 1f 4c            jsr $223a(pc)
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
  00030e:  4e ba 1f 2a            jsr $223a(pc)
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
  00032c:  41 ed 00 b2            lea.l $b2(a5), a0
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
  000394:  4e ba 39 5a            jsr $3cf0(pc)
  000398:  48 6d a0 e2            pea.l -$5f1e(a5)
  00039c:  48 6d a0 e0            pea.l -$5f20(a5)
  0003a0:  48 6e ff fc            pea.l -$4(a6)
  0003a4:  a9 f5                  dc.w $a9f5
  0003a6:  48 6e ff fa            pea.l -$6(a6)
  0003aa:  48 6e ff f8            pea.l -$8(a6)
  0003ae:  4e ba 39 88            jsr $3d38(pc)
  0003b2:  4a 6e ff fa            tst.w -$6(a6)
  0003b6:  54 8f                  addq.l #$2, a7
  0003b8:  66 38                  bne.b $3f2
  0003ba:  0c 6e 00 01 ff f8      cmpi.w #$1, -$8(a6)
  0003c0:  66 30                  bne.b $3f2
  0003c2:  3f 3c 00 01            move.w #$1, -(a7)
  0003c6:  48 6e fe f0            pea.l -$110(a6)
  0003ca:  4e ba 39 90            jsr $3d5c(pc)
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
  0003f8:  4e ba 39 a8            jsr $3da2(pc)
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
  000420:  1b 54 96 fa            move.b (a4), -$6906(a5)
  000424:  1b 6c 00 01 96 fc      move.b $1(a4), -$6904(a5)
  00042a:  4e ba 0f 7e            jsr $13aa(pc)
  00042e:  4c df 10 80            movem.l (a7)+, d7/a4
  000432:  4e 5e                  unlk a6
  000434:  4e 75                  rts 
  000436:  4e ba 00 6c            jsr $4a4(pc)
  00043a:  3b 40 a1 6c            move.w d0, -$5e94(a5)
  00043e:  4a 40                  tst.w d0
  000440:  66 60                  bne.b $4a2
  000442:  42 2d a2 0a            clr.b -$5df6(a5)
  000446:  4a 2d a2 09            tst.b -$5df7(a5)
  00044a:  66 14                  bne.b $460
  00044c:  42 67                  clr.w -(a7)
  00044e:  3f 3c 03 ed            move.w #$3ed, -(a7)
  000452:  42 a7                  clr.l -(a7)
  000454:  a9 85                  dc.w $a985
  000456:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  00045c:  54 8f                  addq.l #$2, a7
  00045e:  60 42                  bra.b $4a2
  000460:  4e ba 02 ac            jsr $70e(pc)
  000464:  42 67                  clr.w -(a7)
  000466:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  00046a:  3f 2d a0 be            move.w -$5f42(a5), -(a7)
  00046e:  42 27                  clr.b -(a7)
  000470:  a9 c4                  dc.w $a9c4
  000472:  3b 5f a1 64            move.w (a7)+, -$5e9c(a5)
  000476:  3f 2d a1 64            move.w -$5e9c(a5), -(a7)
  00047a:  4e ba 1d 4a            jsr $21c6(pc)
  00047e:  4a 00                  tst.b d0
  000480:  54 8f                  addq.l #$2, a7
  000482:  66 1e                  bne.b $4a2
  000484:  4e ba 03 0c            jsr $792(pc)
  000488:  4e ba 01 d2            jsr $65c(pc)
  00048c:  4e ba 04 48            jsr $8d6(pc)
  000490:  3b 40 a1 6c            move.w d0, -$5e94(a5)
  000494:  4a 40                  tst.w d0
  000496:  66 0a                  bne.b $4a2
  000498:  4e ba 05 7e            jsr $a18(pc)
  00049c:  3b 40 a1 6c            move.w d0, -$5e94(a5)
  0004a0:  4a 40                  tst.w d0
  0004a2:  4e 75                  rts 
  0004a4:  48 e7 01 18            movem.l d7/a3-a4, -(a7)
  0004a8:  4a 2d a0 99            tst.b -$5f67(a5)
  0004ac:  67 00 01 68            beq.w $616
  0004b0:  4a 2d 96 b9            tst.b -$6947(a5)
  0004b4:  67 00 01 60            beq.w $616
  0004b8:  42 a7                  clr.l -(a7)
  0004ba:  aa 2a                  dc.w $aa2a
  0004bc:  28 5f                  movea.l (a7)+, a4
  0004be:  42 a7                  clr.l -(a7)
  0004c0:  aa 29                  dc.w $aa29
  0004c2:  26 5f                  movea.l (a7)+, a3
  0004c4:  b9 cb                  cmpa.l a3, a4
  0004c6:  66 08                  bne.b $4d0
  0004c8:  42 a7                  clr.l -(a7)
  0004ca:  2f 0b                  move.l a3, -(a7)
  0004cc:  aa 2b                  dc.w $aa2b
  0004ce:  26 5f                  movea.l (a7)+, a3
  0004d0:  4a 2d 96 cb            tst.b -$6935(a5)
  0004d4:  67 04                  beq.b $4da
  0004d6:  20 0b                  move.l a3, d0
  0004d8:  66 0c                  bne.b $4e6
  0004da:  1b 7c 00 01 a2 08      move.b #$1, -$5df8(a5)
  0004e0:  2b 4c a1 bc            move.l a4, -$5e44(a5)
  0004e4:  60 08                  bra.b $4ee
  0004e6:  42 2d a2 08            clr.b -$5df8(a5)
  0004ea:  2b 4b a1 bc            move.l a3, -$5e44(a5)
  0004ee:  1b 7c 00 01 a2 09      move.b #$1, -$5df7(a5)
  0004f4:  20 6d a1 bc            movea.l -$5e44(a5), a0
  0004f8:  20 50                  movea.l (a0), a0
  0004fa:  2b 68 00 16 a1 c0      move.l $16(a0), -$5e40(a5)
  000500:  20 6d a1 c0            movea.l -$5e40(a5), a0
  000504:  28 50                  movea.l (a0), a4
  000506:  2b 6c 00 2a a1 c4      move.l $2a(a4), -$5e3c(a5)
  00050c:  22 6d a1 c4            movea.l -$5e3c(a5), a1
  000510:  22 51                  movea.l (a1), a1
  000512:  2b 51 a1 c8            move.l (a1), -$5e38(a5)
  000516:  42 6d a1 ae            clr.w -$5e52(a5)
  00051a:  4a 6c 00 1e            tst.w $1e(a4)
  00051e:  66 0c                  bne.b $52c
  000520:  30 2c 00 22            move.w $22(a4), d0
  000524:  c1 ec 00 24            muls.w $24(a4), d0
  000528:  3b 40 a1 ae            move.w d0, -$5e52(a5)
  00052c:  0c 6d 00 01 a1 ae      cmpi.w #$1, -$5e52(a5)
  000532:  67 30                  beq.b $564
  000534:  0c 6d 00 02 a1 ae      cmpi.w #$2, -$5e52(a5)
  00053a:  67 28                  beq.b $564
  00053c:  0c 6d 00 04 a1 ae      cmpi.w #$4, -$5e52(a5)
  000542:  67 20                  beq.b $564
  000544:  0c 6d 00 08 a1 ae      cmpi.w #$8, -$5e52(a5)
  00054a:  67 18                  beq.b $564
  00054c:  42 67                  clr.w -(a7)
  00054e:  3f 3c 03 ed            move.w #$3ed, -(a7)
  000552:  42 a7                  clr.l -(a7)
  000554:  a9 85                  dc.w $a985
  000556:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  00055c:  70 ff                  moveq #$ff, d0
  00055e:  54 8f                  addq.l #$2, a7
  000560:  60 00 00 e2            bra.w $644
  000564:  30 2d a1 ae            move.w -$5e52(a5), d0
  000568:  0c 40 00 08            cmpi.w #$8, d0
  00056c:  62 42                  bhi.b $5b0
  00056e:  43 fa 00 da            lea.l $64a(pc), a1
  000572:  d0 40                  add.w d0, d0
  000574:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000578:  4e d1                  jmp (a1)
  00057a:  3b 7c ff f0 a1 b0      move.w #$fff0, -$5e50(a5)
  000580:  3b 7c 00 0f a1 b2      move.w #$f, -$5e4e(a5)
  000586:  60 28                  bra.b $5b0
  000588:  3b 7c ff f8 a1 b0      move.w #$fff8, -$5e50(a5)
  00058e:  3b 7c 00 07 a1 b2      move.w #$7, -$5e4e(a5)
  000594:  60 1a                  bra.b $5b0
  000596:  3b 7c ff fc a1 b0      move.w #$fffc, -$5e50(a5)
  00059c:  3b 7c 00 03 a1 b2      move.w #$3, -$5e4e(a5)
  0005a2:  60 0c                  bra.b $5b0
  0005a4:  3b 7c ff fe a1 b0      move.w #$fffe, -$5e50(a5)
  0005aa:  3b 7c 00 01 a1 b2      move.w #$1, -$5e4e(a5)
  0005b0:  20 6d a1 c0            movea.l -$5e40(a5), a0
  0005b4:  20 50                  movea.l (a0), a0
  0005b6:  2b 68 00 06 a1 b4      move.l $6(a0), -$5e4c(a5)
  0005bc:  2b 68 00 0a a1 b8      move.l $a(a0), -$5e48(a5)
  0005c2:  30 2d a1 b8            move.w -$5e48(a5), d0
  0005c6:  90 6d a1 b4            sub.w -$5e4c(a5), d0
  0005ca:  0c 40 01 90            cmpi.w #$190, d0
  0005ce:  6d 12                  blt.b $5e2
  0005d0:  30 2d a1 ba            move.w -$5e46(a5), d0
  0005d4:  90 6d a1 b6            sub.w -$5e4a(a5), d0
  0005d8:  0c 40 02 80            cmpi.w #$280, d0
  0005dc:  6d 04                  blt.b $5e2
  0005de:  7e 01                  moveq #$1, d7
  0005e0:  60 02                  bra.b $5e4
  0005e2:  7e 00                  moveq #$0, d7
  0005e4:  4a 2d 96 ca            tst.b -$6936(a5)
  0005e8:  66 04                  bne.b $5ee
  0005ea:  4a 07                  tst.b d7
  0005ec:  66 0a                  bne.b $5f8
  0005ee:  4a 2d 96 ca            tst.b -$6936(a5)
  0005f2:  67 0c                  beq.b $600
  0005f4:  4a 07                  tst.b d7
  0005f6:  66 08                  bne.b $600
  0005f8:  1b 7c 00 01 a2 0a      move.b #$1, -$5df6(a5)
  0005fe:  60 04                  bra.b $604
  000600:  42 2d a2 0a            clr.b -$5df6(a5)
  000604:  0c 6d 00 04 a1 ae      cmpi.w #$4, -$5e52(a5)
  00060a:  6c 36                  bge.b $642
  00060c:  42 2d a2 09            clr.b -$5df7(a5)
  000610:  42 2d a2 0a            clr.b -$5df6(a5)
  000614:  60 2c                  bra.b $642
  000616:  1b 7c 00 01 a2 08      move.b #$1, -$5df8(a5)
  00061c:  42 2d a2 09            clr.b -$5df7(a5)
  000620:  42 2d a2 0a            clr.b -$5df6(a5)
  000624:  3b 7c 00 01 a1 ae      move.w #$1, -$5e52(a5)
  00062a:  3b 7c ff f0 a1 b0      move.w #$fff0, -$5e50(a5)
  000630:  3b 7c 00 0f a1 b2      move.w #$f, -$5e4e(a5)
  000636:  2b 6d a6 5a a1 b4      move.l -$59a6(a5), -$5e4c(a5)
  00063c:  2b 6d a6 5e a1 b8      move.l -$59a2(a5), -$5e48(a5)
  000642:  70 00                  moveq #$0, d0
  000644:  4c df 18 80            movem.l (a7)+, d7/a3-a4
  000648:  4e 75                  rts 
  00064a:  ff 66                  dc.w $ff66
  00064c:  ff 30                  dc.w $ff30
  00064e:  ff 3e                  dc.w $ff3e
  000650:  ff 66                  dc.w $ff66
  000652:  ff 4c                  dc.w $ff4c
  000654:  ff 66                  dc.w $ff66
  000656:  ff 66                  dc.w $ff66
  000658:  ff 66                  dc.w $ff66
  00065a:  ff 5a                  dc.w $ff5a
  00065c:  4a 2d a2 09            tst.b -$5df7(a5)
  000660:  67 10                  beq.b $672
  000662:  0c 6d 00 08 a1 ae      cmpi.w #$8, -$5e52(a5)
  000668:  66 08                  bne.b $672
  00066a:  3b 7c 00 08 a2 5c      move.w #$8, -$5da4(a5)
  000670:  60 1c                  bra.b $68e
  000672:  4a 2d a2 09            tst.b -$5df7(a5)
  000676:  67 10                  beq.b $688
  000678:  0c 6d 00 04 a1 ae      cmpi.w #$4, -$5e52(a5)
  00067e:  66 08                  bne.b $688
  000680:  3b 7c 00 04 a2 5c      move.w #$4, -$5da4(a5)
  000686:  60 06                  bra.b $68e
  000688:  3b 7c 00 01 a2 5c      move.w #$1, -$5da4(a5)
  00068e:  30 2d a2 5c            move.w -$5da4(a5), d0
  000692:  67 78                  beq.b $70c
  000694:  6b 76                  bmi.b $70c
  000696:  59 40                  subq.w #$4, d0
  000698:  67 30                  beq.b $6ca
  00069a:  6a 06                  bpl.b $6a2
  00069c:  54 40                  addq.w #$2, d0
  00069e:  6a 6c                  bpl.b $70c
  0006a0:  60 4a                  bra.b $6ec
  0006a2:  59 40                  subq.w #$4, d0
  0006a4:  67 02                  beq.b $6a8
  0006a6:  60 64                  bra.b $70c
  0006a8:  41 ed 01 5a            lea.l $15a(a5), a0
  0006ac:  2b 48 a3 de            move.l a0, -$5c22(a5)
  0006b0:  43 ed 01 62            lea.l $162(a5), a1
  0006b4:  2b 49 a3 e2            move.l a1, -$5c1e(a5)
  0006b8:  41 ed 01 6a            lea.l $16a(a5), a0
  0006bc:  2b 48 a3 e6            move.l a0, -$5c1a(a5)
  0006c0:  41 ed 01 72            lea.l $172(a5), a0
  0006c4:  2b 48 a3 ea            move.l a0, -$5c16(a5)
  0006c8:  60 42                  bra.b $70c
  0006ca:  41 ed 01 3a            lea.l $13a(a5), a0
  0006ce:  2b 48 a3 de            move.l a0, -$5c22(a5)
  0006d2:  43 ed 01 42            lea.l $142(a5), a1
  0006d6:  2b 49 a3 e2            move.l a1, -$5c1e(a5)
  0006da:  41 ed 01 4a            lea.l $14a(a5), a0
  0006de:  2b 48 a3 e6            move.l a0, -$5c1a(a5)
  0006e2:  41 ed 01 52            lea.l $152(a5), a0
  0006e6:  2b 48 a3 ea            move.l a0, -$5c16(a5)
  0006ea:  60 20                  bra.b $70c
  0006ec:  41 ed 01 1a            lea.l $11a(a5), a0
  0006f0:  2b 48 a3 de            move.l a0, -$5c22(a5)
  0006f4:  43 ed 01 22            lea.l $122(a5), a1
  0006f8:  2b 49 a3 e2            move.l a1, -$5c1e(a5)
  0006fc:  41 ed 01 2a            lea.l $12a(a5), a0
  000700:  2b 48 a3 e6            move.l a0, -$5c1a(a5)
  000704:  41 ed 01 32            lea.l $132(a5), a0
  000708:  2b 48 a3 ea            move.l a0, -$5c16(a5)
  00070c:  4e 75                  rts 
  00070e:  4e 56 ff f0            link.w a6, #$fff0
  000712:  4a 2d a2 09            tst.b -$5df7(a5)
  000716:  67 10                  beq.b $728
  000718:  4a 2d a2 0a            tst.b -$5df6(a5)
  00071c:  67 0a                  beq.b $728
  00071e:  41 ed 96 fe            lea.l -$6902(a5), a0
  000722:  2b 48 a1 68            move.l a0, -$5e98(a5)
  000726:  60 18                  bra.b $740
  000728:  4a 2d a2 09            tst.b -$5df7(a5)
  00072c:  67 0a                  beq.b $738
  00072e:  41 ed 97 12            lea.l -$68ee(a5), a0
  000732:  2b 48 a1 68            move.l a0, -$5e98(a5)
  000736:  60 08                  bra.b $740
  000738:  41 ed 97 22            lea.l -$68de(a5), a0
  00073c:  2b 48 a1 68            move.l a0, -$5e98(a5)
  000740:  42 67                  clr.w -(a7)
  000742:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  000746:  3f 2d a0 be            move.w -$5f42(a5), -(a7)
  00074a:  48 6e ff f0            pea.l -$10(a6)
  00074e:  4e ba 35 6a            jsr $3cba(pc)
  000752:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  000756:  4a 6d a1 6c            tst.w -$5e94(a5)
  00075a:  66 14                  bne.b $770
  00075c:  0c ae 50 50 67 66 ff f0 cmpi.l #$50506766, -$10(a6)
  000764:  66 0a                  bne.b $770
  000766:  0c ae 50 6f c4 50 ff f4 cmpi.l #$506fc450, -$c(a6)
  00076e:  67 1e                  beq.b $78e
  000770:  4a 2d a2 09            tst.b -$5df7(a5)
  000774:  67 0c                  beq.b $782
  000776:  4a 2d a2 0a            tst.b -$5df6(a5)
  00077a:  67 06                  beq.b $782
  00077c:  42 2d a2 0a            clr.b -$5df6(a5)
  000780:  60 90                  bra.b $712
  000782:  4a 2d a2 09            tst.b -$5df7(a5)
  000786:  67 06                  beq.b $78e
  000788:  42 2d a2 09            clr.b -$5df7(a5)
  00078c:  60 84                  bra.b $712
  00078e:  4e 5e                  unlk a6
  000790:  4e 75                  rts 
  000792:  4e 56 ff fc            link.w a6, #$fffc
  000796:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  00079a:  4a 2d a2 0a            tst.b -$5df6(a5)
  00079e:  67 30                  beq.b $7d0
  0007a0:  7e 80                  moveq #$80, d7
  0007a2:  49 ed 98 14            lea.l -$67ec(a5), a4
  0007a6:  60 0a                  bra.b $7b2
  0007a8:  30 07                  move.w d7, d0
  0007aa:  d0 40                  add.w d0, d0
  0007ac:  38 80                  move.w d0, (a4)
  0007ae:  52 47                  addq.w #$1, d7
  0007b0:  54 8c                  addq.l #$2, a4
  0007b2:  0c 47 01 c0            cmpi.w #$1c0, d7
  0007b6:  6d f0                  blt.b $7a8
  0007b8:  7e c1                  moveq #$c1, d7
  0007ba:  49 ed 9c 94            lea.l -$636c(a5), a4
  0007be:  60 0a                  bra.b $7ca
  0007c0:  30 07                  move.w d7, d0
  0007c2:  d0 40                  add.w d0, d0
  0007c4:  38 80                  move.w d0, (a4)
  0007c6:  52 47                  addq.w #$1, d7
  0007c8:  54 8c                  addq.l #$2, a4
  0007ca:  0c 47 00 ff            cmpi.w #$ff, d7
  0007ce:  6d f0                  blt.b $7c0
  0007d0:  4a 2d a2 0a            tst.b -$5df6(a5)
  0007d4:  66 1c                  bne.b $7f2
  0007d6:  53 2d b3 7d            subq.b #$1, -$4c83(a5)
  0007da:  59 2d b3 89            subq.b #$4, -$4c77(a5)
  0007de:  57 2d b3 91            subq.b #$3, -$4c6f(a5)
  0007e2:  57 2d b3 95            subq.b #$3, -$4c6b(a5)
  0007e6:  55 2d b3 99            subq.b #$2, -$4c67(a5)
  0007ea:  53 2d b3 9d            subq.b #$1, -$4c63(a5)
  0007ee:  52 2d b3 b9            addq.b #$1, -$4c47(a5)
  0007f2:  4a 2d a2 0a            tst.b -$5df6(a5)
  0007f6:  67 1e                  beq.b $816
  0007f8:  3b 7c 02 80 a5 c0      move.w #$280, -$5a40(a5)
  0007fe:  3b 7c 01 90 a5 c2      move.w #$190, -$5a3e(a5)
  000804:  3c 3c 02 80            move.w #$280, d6
  000808:  3a 3c 01 80            move.w #$180, d5
  00080c:  38 3c 01 2c            move.w #$12c, d4
  000810:  36 3c 01 5e            move.w #$15e, d3
  000814:  60 1c                  bra.b $832
  000816:  3b 7c 02 00 a5 c0      move.w #$200, -$5a40(a5)
  00081c:  3b 7c 01 4e a5 c2      move.w #$14e, -$5a3e(a5)
  000822:  3c 3c 01 fe            move.w #$1fe, d6
  000826:  3a 3c 01 3e            move.w #$13e, d5
  00082a:  38 3c 00 f0            move.w #$f0, d4
  00082e:  36 3c 01 5e            move.w #$15e, d3
  000832:  3e 06                  move.w d6, d7
  000834:  e2 47                  asr.w #$1, d7
  000836:  e2 44                  asr.w #$1, d4
  000838:  e2 43                  asr.w #$1, d3
  00083a:  48 6d a5 c4            pea.l -$5a3c(a5)
  00083e:  42 a7                  clr.l -(a7)
  000840:  3f 2d a5 c0            move.w -$5a40(a5), -(a7)
  000844:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  000848:  a8 a7                  dc.w $a8a7
  00084a:  48 6d a5 cc            pea.l -$5a34(a5)
  00084e:  42 a7                  clr.l -(a7)
  000850:  3f 06                  move.w d6, -(a7)
  000852:  3f 05                  move.w d5, -(a7)
  000854:  a8 a7                  dc.w $a8a7
  000856:  48 6d a5 d4            pea.l -$5a2c(a5)
  00085a:  42 67                  clr.w -(a7)
  00085c:  3f 05                  move.w d5, -(a7)
  00085e:  3f 06                  move.w d6, -(a7)
  000860:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  000864:  a8 a7                  dc.w $a8a7
  000866:  30 07                  move.w d7, d0
  000868:  90 44                  sub.w d4, d0
  00086a:  3d 40 ff fe            move.w d0, -$2(a6)
  00086e:  48 6d a5 dc            pea.l -$5a24(a5)
  000872:  42 67                  clr.w -(a7)
  000874:  3f 05                  move.w d5, -(a7)
  000876:  3f 00                  move.w d0, -(a7)
  000878:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  00087c:  a8 a7                  dc.w $a8a7
  00087e:  30 07                  move.w d7, d0
  000880:  d0 44                  add.w d4, d0
  000882:  3d 40 ff fc            move.w d0, -$4(a6)
  000886:  48 6d a5 e4            pea.l -$5a1c(a5)
  00088a:  3f 2e ff fe            move.w -$2(a6), -(a7)
  00088e:  3f 05                  move.w d5, -(a7)
  000890:  3f 00                  move.w d0, -(a7)
  000892:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  000896:  a8 a7                  dc.w $a8a7
  000898:  48 6d a5 ec            pea.l -$5a14(a5)
  00089c:  3f 2e ff fc            move.w -$4(a6), -(a7)
  0008a0:  3f 05                  move.w d5, -(a7)
  0008a2:  3f 06                  move.w d6, -(a7)
  0008a4:  3f 2d a5 c2            move.w -$5a3e(a5), -(a7)
  0008a8:  a8 a7                  dc.w $a8a7
  0008aa:  48 6d a5 fc            pea.l -$5a04(a5)
  0008ae:  30 07                  move.w d7, d0
  0008b0:  90 43                  sub.w d3, d0
  0008b2:  3f 00                  move.w d0, -(a7)
  0008b4:  42 67                  clr.w -(a7)
  0008b6:  30 07                  move.w d7, d0
  0008b8:  d0 43                  add.w d3, d0
  0008ba:  3f 00                  move.w d0, -(a7)
  0008bc:  3f 3c 00 14            move.w #$14, -(a7)
  0008c0:  a8 a7                  dc.w $a8a7
  0008c2:  48 6d a5 fc            pea.l -$5a04(a5)
  0008c6:  42 67                  clr.w -(a7)
  0008c8:  3f 2d 9d bc            move.w -$6244(a5), -(a7)
  0008cc:  a8 a8                  dc.w $a8a8
  0008ce:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  0008d2:  4e 5e                  unlk a6
  0008d4:  4e 75                  rts 
  0008d6:  48 6d a0 b6            pea.l -$5f4a(a5)
  0008da:  a8 74                  dc.w $a874
  0008dc:  4a 2d a2 09            tst.b -$5df7(a5)
  0008e0:  67 3c                  beq.b $91e
  0008e2:  42 a7                  clr.l -(a7)
  0008e4:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  0008ea:  3f 3c 07 d0            move.w #$7d0, -(a7)
  0008ee:  a9 a0                  dc.w $a9a0
  0008f0:  2b 5f a2 f4            move.l (a7)+, -$5d0c(a5)
  0008f4:  2f 2d a2 f4            move.l -$5d0c(a5), -(a7)
  0008f8:  4e ba 19 40            jsr $223a(pc)
  0008fc:  4a 00                  tst.b d0
  0008fe:  58 8f                  addq.l #$4, a7
  000900:  67 06                  beq.b $908
  000902:  70 ff                  moveq #$ff, d0
  000904:  60 00 01 10            bra.w $a16
  000908:  2f 2d a2 f4            move.l -$5d0c(a5), -(a7)
  00090c:  a9 92                  dc.w $a992
  00090e:  20 6d a2 f4            movea.l -$5d0c(a5), a0
  000912:  20 50                  movea.l (a0), a0
  000914:  70 01                  moveq #$1, d0
  000916:  d0 68 00 06            add.w $6(a0), d0
  00091a:  3b 40 a2 f8            move.w d0, -$5d08(a5)
  00091e:  30 2d a2 5c            move.w -$5da4(a5), d0
  000922:  c1 ed a5 c0            muls.w -$5a40(a5), d0
  000926:  06 40 00 0f            addi.w #$f, d0
  00092a:  e8 40                  asr.w #$4, d0
  00092c:  d0 40                  add.w d0, d0
  00092e:  3b 40 a2 da            move.w d0, -$5d26(a5)
  000932:  c1 ed a5 c2            muls.w -$5a3e(a5), d0
  000936:  2b 40 a2 d6            move.l d0, -$5d2a(a5)
  00093a:  a1 1e                  dc.w $a11e
  00093c:  2b 48 a2 d2            move.l a0, -$5d2e(a5)
  000940:  2f 08                  move.l a0, -(a7)
  000942:  4e ba 19 38            jsr $227c(pc)
  000946:  4a 00                  tst.b d0
  000948:  58 8f                  addq.l #$4, a7
  00094a:  67 06                  beq.b $952
  00094c:  70 ff                  moveq #$ff, d0
  00094e:  60 00 00 c6            bra.w $a16
  000952:  2b 6d a5 c4 a2 dc      move.l -$5a3c(a5), -$5d24(a5)
  000958:  2b 6d a5 c8 a2 e0      move.l -$5a38(a5), -$5d20(a5)
  00095e:  2b 6d a2 dc a2 e4      move.l -$5d24(a5), -$5d1c(a5)
  000964:  2b 6d a2 e0 a2 e8      move.l -$5d20(a5), -$5d18(a5)
  00096a:  4a 2d a2 09            tst.b -$5df7(a5)
  00096e:  67 50                  beq.b $9c0
  000970:  42 a7                  clr.l -(a7)
  000972:  aa 32                  dc.w $aa32
  000974:  2b 5f a0 ba            move.l (a7)+, -$5f46(a5)
  000978:  2f 2d a1 bc            move.l -$5e44(a5), -(a7)
  00097c:  aa 31                  dc.w $aa31
  00097e:  48 6d a2 5e            pea.l -$5da2(a5)
  000982:  aa 00                  dc.w $aa00
  000984:  2b 6d a2 60 a2 ca      move.l -$5da0(a5), -$5d36(a5)
  00098a:  20 6d a2 ca            movea.l -$5d36(a5), a0
  00098e:  20 50                  movea.l (a0), a0
  000990:  20 ad a2 d2            move.l -$5d2e(a5), (a0)
  000994:  30 2d a2 da            move.w -$5d26(a5), d0
  000998:  00 40 80 00            ori.w #$8000, d0
  00099c:  20 6d a2 ca            movea.l -$5d36(a5), a0
  0009a0:  20 50                  movea.l (a0), a0
  0009a2:  31 40 00 04            move.w d0, $4(a0)
  0009a6:  20 6d a2 ca            movea.l -$5d36(a5), a0
  0009aa:  20 50                  movea.l (a0), a0
  0009ac:  21 6d a2 dc 00 06      move.l -$5d24(a5), $6(a0)
  0009b2:  21 6d a2 e0 00 0a      move.l -$5d20(a5), $a(a0)
  0009b8:  2f 2d a0 ba            move.l -$5f46(a5), -(a7)
  0009bc:  aa 31                  dc.w $aa31
  0009be:  60 2c                  bra.b $9ec
  0009c0:  48 6d a2 5e            pea.l -$5da2(a5)
  0009c4:  a8 6f                  dc.w $a86f
  0009c6:  41 ed a2 60            lea.l -$5da0(a5), a0
  0009ca:  2b 48 a2 ce            move.l a0, -$5d32(a5)
  0009ce:  20 ad a2 d2            move.l -$5d2e(a5), (a0)
  0009d2:  20 6d a2 ce            movea.l -$5d32(a5), a0
  0009d6:  31 6d a2 da 00 04      move.w -$5d26(a5), $4(a0)
  0009dc:  20 6d a2 ce            movea.l -$5d32(a5), a0
  0009e0:  21 6d a2 dc 00 06      move.l -$5d24(a5), $6(a0)
  0009e6:  21 6d a2 e0 00 0a      move.l -$5d20(a5), $a(a0)
  0009ec:  48 6d a2 dc            pea.l -$5d24(a5)
  0009f0:  a8 7b                  dc.w $a87b
  0009f2:  48 6d a2 dc            pea.l -$5d24(a5)
  0009f6:  a8 a2                  dc.w $a8a2
  0009f8:  3f 3c 00 c8            move.w #$c8, -(a7)
  0009fc:  a8 87                  dc.w $a887
  0009fe:  3f 3c 00 10            move.w #$10, -(a7)
  000a02:  a8 8a                  dc.w $a88a
  000a04:  42 67                  clr.w -(a7)
  000a06:  a8 88                  dc.w $a888
  000a08:  3f 3c 00 03            move.w #$3, -(a7)
  000a0c:  a8 89                  dc.w $a889
  000a0e:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  000a12:  a8 73                  dc.w $a873
  000a14:  70 00                  moveq #$0, d0
  000a16:  4e 75                  rts 
  000a18:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  000a1c:  4a 2d a2 09            tst.b -$5df7(a5)
  000a20:  67 20                  beq.b $a42
  000a22:  42 a7                  clr.l -(a7)
  000a24:  42 a7                  clr.l -(a7)
  000a26:  48 6d a1 b4            pea.l -$5e4c(a5)
  000a2a:  42 a7                  clr.l -(a7)
  000a2c:  2f 3c 00 02 01 00      move.l #$20100, -(a7)
  000a32:  48 78 ff ff            pea.l $ffff.w
  000a36:  42 27                  clr.b -(a7)
  000a38:  42 a7                  clr.l -(a7)
  000a3a:  aa 45                  dc.w $aa45
  000a3c:  2b 5f a2 12            move.l (a7)+, -$5dee(a5)
  000a40:  60 1e                  bra.b $a60
  000a42:  42 a7                  clr.l -(a7)
  000a44:  42 a7                  clr.l -(a7)
  000a46:  48 6d a1 b4            pea.l -$5e4c(a5)
  000a4a:  42 a7                  clr.l -(a7)
  000a4c:  2f 3c 00 02 01 00      move.l #$20100, -(a7)
  000a52:  48 78 ff ff            pea.l $ffff.w
  000a56:  42 27                  clr.b -(a7)
  000a58:  42 a7                  clr.l -(a7)
  000a5a:  a9 13                  dc.w $a913
  000a5c:  2b 5f a2 12            move.l (a7)+, -$5dee(a5)
  000a60:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000a64:  4e ba 18 16            jsr $227c(pc)
  000a68:  4a 00                  tst.b d0
  000a6a:  58 8f                  addq.l #$4, a7
  000a6c:  67 06                  beq.b $a74
  000a6e:  70 ff                  moveq #$ff, d0
  000a70:  60 00 02 34            bra.w $ca6
  000a74:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000a78:  a8 73                  dc.w $a873
  000a7a:  3e 2d a1 ba            move.w -$5e46(a5), d7
  000a7e:  de 6d a1 b6            add.w -$5e4a(a5), d7
  000a82:  9e 6d a5 c0            sub.w -$5a40(a5), d7
  000a86:  48 c7                  ext.l d7
  000a88:  8f fc 00 02            divs.w #$2, d7
  000a8c:  ce 6d a1 b0            and.w -$5e50(a5), d7
  000a90:  3c 2d a1 b8            move.w -$5e48(a5), d6
  000a94:  dc 6d a1 b4            add.w -$5e4c(a5), d6
  000a98:  9c 6d a5 c2            sub.w -$5a3e(a5), d6
  000a9c:  48 c6                  ext.l d6
  000a9e:  8d fc 00 02            divs.w #$2, d6
  000aa2:  30 2d a1 b6            move.w -$5e4a(a5), d0
  000aa6:  90 47                  sub.w d7, d0
  000aa8:  3f 00                  move.w d0, -(a7)
  000aaa:  30 2d a1 b4            move.w -$5e4c(a5), d0
  000aae:  90 46                  sub.w d6, d0
  000ab0:  3f 00                  move.w d0, -(a7)
  000ab2:  a8 78                  dc.w $a878
  000ab4:  4a 2d a2 09            tst.b -$5df7(a5)
  000ab8:  67 18                  beq.b $ad2
  000aba:  20 6d a2 12            movea.l -$5dee(a5), a0
  000abe:  2b 68 00 02 a2 16      move.l $2(a0), -$5dea(a5)
  000ac4:  2b 68 00 10 a2 1e      move.l $10(a0), -$5de2(a5)
  000aca:  2b 68 00 14 a2 22      move.l $14(a0), -$5dde(a5)
  000ad0:  60 1a                  bra.b $aec
  000ad2:  70 02                  moveq #$2, d0
  000ad4:  d0 ad a2 12            add.l -$5dee(a5), d0
  000ad8:  2b 40 a2 1a            move.l d0, -$5de6(a5)
  000adc:  20 6d a2 12            movea.l -$5dee(a5), a0
  000ae0:  2b 68 00 10 a2 1e      move.l $10(a0), -$5de2(a5)
  000ae6:  2b 68 00 14 a2 22      move.l $14(a0), -$5dde(a5)
  000aec:  48 78 00 1e            pea.l $1e.w
  000af0:  a8 63                  dc.w $a863
  000af2:  48 78 00 21            pea.l $21.w
  000af6:  a8 62                  dc.w $a862
  000af8:  48 6d a2 1e            pea.l -$5de2(a5)
  000afc:  a8 a2                  dc.w $a8a2
  000afe:  42 a7                  clr.l -(a7)
  000b00:  a8 d8                  dc.w $a8d8
  000b02:  2b 5f a2 2a            move.l (a7)+, -$5dd6(a5)
  000b06:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000b0a:  48 6d a2 1e            pea.l -$5de2(a5)
  000b0e:  a8 df                  dc.w $a8df
  000b10:  42 a7                  clr.l -(a7)
  000b12:  a8 d8                  dc.w $a8d8
  000b14:  28 5f                  movea.l (a7)+, a4
  000b16:  2f 0c                  move.l a4, -(a7)
  000b18:  48 6d a5 c4            pea.l -$5a3c(a5)
  000b1c:  a8 df                  dc.w $a8df
  000b1e:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000b22:  2f 0c                  move.l a4, -(a7)
  000b24:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000b28:  a8 e6                  dc.w $a8e6
  000b2a:  2f 0c                  move.l a4, -(a7)
  000b2c:  a8 d9                  dc.w $a8d9
  000b2e:  4a 2d a2 09            tst.b -$5df7(a5)
  000b32:  67 00 00 e6            beq.w $c1a
  000b36:  0c 6d 00 08 a2 5c      cmpi.w #$8, -$5da4(a5)
  000b3c:  6c 06                  bge.b $b44
  000b3e:  3e 3c 0f a0            move.w #$fa0, d7
  000b42:  60 04                  bra.b $b48
  000b44:  3e 3c 07 d0            move.w #$7d0, d7
  000b48:  42 a7                  clr.l -(a7)
  000b4a:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  000b50:  3f 07                  move.w d7, -(a7)
  000b52:  a9 a0                  dc.w $a9a0
  000b54:  2b 5f a2 32            move.l (a7)+, -$5dce(a5)
  000b58:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  000b5c:  4e ba 16 dc            jsr $223a(pc)
  000b60:  4a 00                  tst.b d0
  000b62:  58 8f                  addq.l #$4, a7
  000b64:  67 06                  beq.b $b6c
  000b66:  70 ff                  moveq #$ff, d0
  000b68:  60 00 01 3c            bra.w $ca6
  000b6c:  0c 6d 00 08 a2 5c      cmpi.w #$8, -$5da4(a5)
  000b72:  6c 0e                  bge.b $b82
  000b74:  2f 2d a2 f4            move.l -$5d0c(a5), -(a7)
  000b78:  3f 3c 00 04            move.w #$4, -(a7)
  000b7c:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  000b80:  aa 37                  dc.w $aa37
  000b82:  20 6d a2 32            movea.l -$5dce(a5), a0
  000b86:  20 50                  movea.l (a0), a0
  000b88:  70 01                  moveq #$1, d0
  000b8a:  d0 68 00 06            add.w $6(a0), d0
  000b8e:  3b 40 a2 36            move.w d0, -$5dca(a5)
  000b92:  42 a7                  clr.l -(a7)
  000b94:  3f 00                  move.w d0, -(a7)
  000b96:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  000b9a:  48 78 00 04            pea.l $4.w
  000b9e:  aa 91                  dc.w $aa91
  000ba0:  2b 5f a2 2e            move.l (a7)+, -$5dd2(a5)
  000ba4:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000ba8:  4e ba 16 90            jsr $223a(pc)
  000bac:  4a 00                  tst.b d0
  000bae:  58 8f                  addq.l #$4, a7
  000bb0:  67 06                  beq.b $bb8
  000bb2:  70 ff                  moveq #$ff, d0
  000bb4:  60 00 00 f0            bra.w $ca6
  000bb8:  7e 00                  moveq #$0, d7
  000bba:  99 cc                  suba.l a4, a4
  000bbc:  97 cb                  suba.l a3, a3
  000bbe:  60 20                  bra.b $be0
  000bc0:  20 6d a2 32            movea.l -$5dce(a5), a0
  000bc4:  20 10                  move.l (a0), d0
  000bc6:  22 6d a2 2e            movea.l -$5dd2(a5), a1
  000bca:  22 11                  move.l (a1), d1
  000bcc:  41 f3 18 10            lea.l $10(a3, d1.l), a0
  000bd0:  20 f4 08 0a            move.l $a(a4, d0.l), (a0)+
  000bd4:  30 f4 08 0e            move.w $e(a4, d0.l), (a0)+
  000bd8:  52 47                  addq.w #$1, d7
  000bda:  50 8c                  addq.l #$8, a4
  000bdc:  47 eb 00 10            lea.l $10(a3), a3
  000be0:  be 6d a2 36            cmp.w -$5dca(a5), d7
  000be4:  6d da                  blt.b $bc0
  000be6:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000bea:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  000bf0:  42 67                  clr.w -(a7)
  000bf2:  aa 9e                  dc.w $aa9e
  000bf4:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000bf8:  2f 3c 00 02 00 01      move.l #$20001, -(a7)
  000bfe:  42 67                  clr.w -(a7)
  000c00:  aa 9e                  dc.w $aa9e
  000c02:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000c06:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000c0a:  1f 3c 00 01            move.b #$1, -(a7)
  000c0e:  aa 95                  dc.w $aa95
  000c10:  3b 7c 01 00 96 f4      move.w #$100, -$690c(a5)
  000c16:  4e ba 08 86            jsr $149e(pc)
  000c1a:  1b 7c 00 01 a2 0c      move.b #$1, -$5df4(a5)
  000c20:  0c 6d 00 04 a2 5c      cmpi.w #$4, -$5da4(a5)
  000c26:  66 08                  bne.b $c30
  000c28:  1b 7c 00 01 a2 0d      move.b #$1, -$5df3(a5)
  000c2e:  60 74                  bra.b $ca4
  000c30:  0c 6d 00 08 a2 5c      cmpi.w #$8, -$5da4(a5)
  000c36:  66 6c                  bne.b $ca4
  000c38:  1b 7c 00 01 a2 0d      move.b #$1, -$5df3(a5)
  000c3e:  7e 00                  moveq #$0, d7
  000c40:  49 ed a2 38            lea.l -$5dc8(a5), a4
  000c44:  60 28                  bra.b $c6e
  000c46:  42 a7                  clr.l -(a7)
  000c48:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  000c4e:  30 07                  move.w d7, d0
  000c50:  06 40 0b b8            addi.w #$bb8, d0
  000c54:  3f 00                  move.w d0, -(a7)
  000c56:  a9 a0                  dc.w $a9a0
  000c58:  28 9f                  move.l (a7)+, (a4)
  000c5a:  2f 14                  move.l (a4), -(a7)
  000c5c:  4e ba 15 dc            jsr $223a(pc)
  000c60:  4a 00                  tst.b d0
  000c62:  58 8f                  addq.l #$4, a7
  000c64:  67 04                  beq.b $c6a
  000c66:  70 ff                  moveq #$ff, d0
  000c68:  60 3c                  bra.b $ca6
  000c6a:  52 47                  addq.w #$1, d7
  000c6c:  58 8c                  addq.l #$4, a4
  000c6e:  0c 47 00 07            cmpi.w #$7, d7
  000c72:  6f d2                  ble.b $c46
  000c74:  1b 7c 00 01 a2 0e      move.b #$1, -$5df2(a5)
  000c7a:  42 a7                  clr.l -(a7)
  000c7c:  2f 3c 63 6c 75 74      move.l #$636c7574, -(a7)
  000c82:  3f 3c 0d ac            move.w #$dac, -(a7)
  000c86:  a9 a0                  dc.w $a9a0
  000c88:  2b 5f a2 58            move.l (a7)+, -$5da8(a5)
  000c8c:  2f 2d a2 58            move.l -$5da8(a5), -(a7)
  000c90:  4e ba 15 a8            jsr $223a(pc)
  000c94:  4a 00                  tst.b d0
  000c96:  58 8f                  addq.l #$4, a7
  000c98:  67 04                  beq.b $c9e
  000c9a:  70 ff                  moveq #$ff, d0
  000c9c:  60 08                  bra.b $ca6
  000c9e:  1b 7c 00 01 a2 0f      move.b #$1, -$5df1(a5)
  000ca4:  70 00                  moveq #$0, d0
  000ca6:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  000caa:  4e 75                  rts 
  000cac:  48 6d a0 b6            pea.l -$5f4a(a5)
  000cb0:  a8 74                  dc.w $a874
  000cb2:  4a ad a2 12            tst.l -$5dee(a5)
  000cb6:  67 0c                  beq.b $cc4
  000cb8:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000cbc:  a8 73                  dc.w $a873
  000cbe:  48 6d a2 1e            pea.l -$5de2(a5)
  000cc2:  a8 a2                  dc.w $a8a2
  000cc4:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  000cc8:  a8 73                  dc.w $a873
  000cca:  4a ad a2 2e            tst.l -$5dd2(a5)
  000cce:  67 06                  beq.b $cd6
  000cd0:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  000cd4:  aa 93                  dc.w $aa93
  000cd6:  4a ad a2 12            tst.l -$5dee(a5)
  000cda:  67 06                  beq.b $ce2
  000cdc:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  000ce0:  a9 14                  dc.w $a914
  000ce2:  4e ba 13 4a            jsr $202e(pc)
  000ce6:  30 2d a0 a2            move.w -$5f5e(a5), d0
  000cea:  31 c0 01 44            move.w d0, $144.w
  000cee:  2f 3c 00 00 ff ff      move.l #$ffff, -(a7)
  000cf4:  20 1f                  move.l (a7)+, d0
  000cf6:  a0 32                  dc.w $a032
  000cf8:  4e 75                  rts 
  000cfa:  4e 56 ff fc            link.w a6, #$fffc
  000cfe:  30 2d a1 e8            move.w -$5e18(a5), d0
  000d02:  0c 40 00 0f            cmpi.w #$f, d0
  000d06:  62 00 01 46            bhi.w $e4e
  000d0a:  43 fa 01 54            lea.l $e60(pc), a1
  000d0e:  d0 40                  add.w d0, d0
  000d10:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000d14:  4e d1                  jmp (a1)
  000d16:  4a 2d 96 bd            tst.b -$6943(a5)
  000d1a:  67 00 01 32            beq.w $e4e
  000d1e:  42 27                  clr.b -(a7)
  000d20:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000d24:  48 6d a1 b4            pea.l -$5e4c(a5)
  000d28:  a8 ad                  dc.w $a8ad
  000d2a:  4a 1f                  tst.b (a7)+
  000d2c:  67 08                  beq.b $d36
  000d2e:  4e ba 13 5c            jsr $208c(pc)
  000d32:  60 00 01 1a            bra.w $e4e
  000d36:  4e ba 13 6a            jsr $20a2(pc)
  000d3a:  60 00 01 12            bra.w $e4e
  000d3e:  42 67                  clr.w -(a7)
  000d40:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000d44:  48 6e ff fc            pea.l -$4(a6)
  000d48:  a9 2c                  dc.w $a92c
  000d4a:  30 1f                  move.w (a7)+, d0
  000d4c:  0c 40 00 06            cmpi.w #$6, d0
  000d50:  62 00 00 fc            bhi.w $e4e
  000d54:  43 fa 00 fc            lea.l $e52(pc), a1
  000d58:  d0 40                  add.w d0, d0
  000d5a:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000d5e:  4e d1                  jmp (a1)
  000d60:  4e ba 19 00            jsr $2662(pc)
  000d64:  42 a7                  clr.l -(a7)
  000d66:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000d6a:  a9 3d                  dc.w $a93d
  000d6c:  4e ba 02 d6            jsr $1044(pc)
  000d70:  4e ba 19 1e            jsr $2690(pc)
  000d74:  58 8f                  addq.l #$4, a7
  000d76:  60 00 00 d6            bra.w $e4e
  000d7a:  48 6d a1 e8            pea.l -$5e18(a5)
  000d7e:  2f 2e ff fc            move.l -$4(a6), -(a7)
  000d82:  a9 b3                  dc.w $a9b3
  000d84:  60 00 00 c8            bra.w $e4e
  000d88:  20 2e ff fc            move.l -$4(a6), d0
  000d8c:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000d90:  66 00 00 bc            bne.w $e4e
  000d94:  4e ba 12 98            jsr $202e(pc)
  000d98:  48 6d a5 c4            pea.l -$5a3c(a5)
  000d9c:  a9 28                  dc.w $a928
  000d9e:  2f 2d a1 f2            move.l -$5e0e(a5), -(a7)
  000da2:  4e ba 02 2c            jsr $fd0(pc)
  000da6:  58 8f                  addq.l #$4, a7
  000da8:  60 00 00 a4            bra.w $e4e
  000dac:  08 2d 00 00 a1 f6      btst.b #$0, -$5e0a(a5)
  000db2:  67 20                  beq.b $dd4
  000db4:  4e ba 18 ac            jsr $2662(pc)
  000db8:  42 a7                  clr.l -(a7)
  000dba:  70 ff                  moveq #$ff, d0
  000dbc:  c0 2d a1 ed            and.b -$5e13(a5), d0
  000dc0:  72 00                  moveq #$0, d1
  000dc2:  12 00                  move.b d0, d1
  000dc4:  3f 01                  move.w d1, -(a7)
  000dc6:  a9 3e                  dc.w $a93e
  000dc8:  4e ba 02 7a            jsr $1044(pc)
  000dcc:  4e ba 18 c2            jsr $2690(pc)
  000dd0:  58 8f                  addq.l #$4, a7
  000dd2:  60 7a                  bra.b $e4e
  000dd4:  3f 2d a1 f6            move.w -$5e0a(a5), -(a7)
  000dd8:  70 ff                  moveq #$ff, d0
  000dda:  c0 2d a1 ed            and.b -$5e13(a5), d0
  000dde:  1f 00                  move.b d0, -(a7)
  000de0:  20 2d a1 ea            move.l -$5e16(a5), d0
  000de4:  02 80 00 00 ff 00      andi.l #$ff00, d0
  000dea:  e0 80                  asr.l #$8, d0
  000dec:  1f 00                  move.b d0, -(a7)
  000dee:  4e ba 01 e8            jsr $fd8(pc)
  000df2:  5c 8f                  addq.l #$6, a7
  000df4:  60 58                  bra.b $e4e
  000df6:  4a 2d 96 bb            tst.b -$6945(a5)
  000dfa:  66 52                  bne.b $e4e
  000dfc:  2f 2d a1 ea            move.l -$5e16(a5), -(a7)
  000e00:  4e ba 01 a6            jsr $fa8(pc)
  000e04:  58 8f                  addq.l #$4, a7
  000e06:  60 46                  bra.b $e4e
  000e08:  08 2d 00 00 a1 f7      btst.b #$0, -$5e09(a5)
  000e0e:  67 0c                  beq.b $e1c
  000e10:  2f 2d a1 ea            move.l -$5e16(a5), -(a7)
  000e14:  4e ba 00 6a            jsr $e80(pc)
  000e18:  58 8f                  addq.l #$4, a7
  000e1a:  60 32                  bra.b $e4e
  000e1c:  2f 2d a1 ea            move.l -$5e16(a5), -(a7)
  000e20:  4e ba 00 ac            jsr $ece(pc)
  000e24:  58 8f                  addq.l #$4, a7
  000e26:  60 26                  bra.b $e4e
  000e28:  0c 2d 00 01 a1 ea      cmpi.b #$1, -$5e16(a5)
  000e2e:  66 1e                  bne.b $e4e
  000e30:  08 2d 00 00 a1 ed      btst.b #$0, -$5e13(a5)
  000e36:  67 0c                  beq.b $e44
  000e38:  42 a7                  clr.l -(a7)
  000e3a:  a9 24                  dc.w $a924
  000e3c:  4e ba 00 42            jsr $e80(pc)
  000e40:  58 8f                  addq.l #$4, a7
  000e42:  60 0a                  bra.b $e4e
  000e44:  42 a7                  clr.l -(a7)
  000e46:  a9 24                  dc.w $a924
  000e48:  4e ba 00 84            jsr $ece(pc)
  000e4c:  58 8f                  addq.l #$4, a7
  000e4e:  4e 5e                  unlk a6
  000e50:  4e 75                  rts 
  000e52:  ff fc                  dc.w $fffc
  000e54:  ff 0e                  dc.w $ff0e
  000e56:  ff 28                  dc.w $ff28
  000e58:  ff 36                  dc.w $ff36
  000e5a:  ff fc                  dc.w $fffc
  000e5c:  ff fc                  dc.w $fffc
  000e5e:  ff fc                  dc.w $fffc
  000e60:  fe b6                  dc.w $feb6
  000e62:  fe de                  dc.w $fede
  000e64:  ff ee                  dc.w $ffee
  000e66:  ff 4c                  dc.w $ff4c
  000e68:  ff ee                  dc.w $ffee
  000e6a:  ff ee                  dc.w $ffee
  000e6c:  ff 96                  dc.w $ff96
  000e6e:  ff ee                  dc.w $ffee
  000e70:  ff a8                  dc.w $ffa8
  000e72:  ff ee                  dc.w $ffee
  000e74:  ff ee                  dc.w $ffee
  000e76:  ff ee                  dc.w $ffee
  000e78:  ff ee                  dc.w $ffee
  000e7a:  ff ee                  dc.w $ffee
  000e7c:  ff ee                  dc.w $ffee
  000e7e:  ff c8                  dc.w $ffc8
  000e80:  4e 56 00 00            link.w a6, #$0
  000e84:  20 2e 00 08            move.l $8(a6), d0
  000e88:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000e8c:  66 3c                  bne.b $eca
  000e8e:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  000e92:  42 67                  clr.w -(a7)
  000e94:  a9 39                  dc.w $a939
  000e96:  2f 2d a1 d8            move.l -$5e28(a5), -(a7)
  000e9a:  42 67                  clr.w -(a7)
  000e9c:  a9 3a                  dc.w $a93a
  000e9e:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  000ea2:  42 67                  clr.w -(a7)
  000ea4:  a9 39                  dc.w $a939
  000ea6:  a9 37                  dc.w $a937
  000ea8:  4e ba 11 0a            jsr $1fb4(pc)
  000eac:  2f 2e 00 08            move.l $8(a6), -(a7)
  000eb0:  a8 73                  dc.w $a873
  000eb2:  4a 2d a2 09            tst.b -$5df7(a5)
  000eb6:  67 08                  beq.b $ec0
  000eb8:  4e ba 06 d8            jsr $1592(pc)
  000ebc:  4e ba 05 e0            jsr $149e(pc)
  000ec0:  4e ba 17 ce            jsr $2690(pc)
  000ec4:  1b 7c 00 01 96 bb      move.b #$1, -$6945(a5)
  000eca:  4e 5e                  unlk a6
  000ecc:  4e 75                  rts 
  000ece:  4e 56 00 00            link.w a6, #$0
  000ed2:  20 2e 00 08            move.l $8(a6), d0
  000ed6:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000eda:  66 50                  bne.b $f2c
  000edc:  0c 6d 00 07 96 e8      cmpi.w #$7, -$6918(a5)
  000ee2:  66 18                  bne.b $efc
  000ee4:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  000eea:  67 10                  beq.b $efc
  000eec:  48 6d 97 32            pea.l -$68ce(a5)
  000ef0:  4e ad 05 12            jsr $512(a5)
  000ef4:  3b 7c 00 02 ba 86      move.w #$2, -$457a(a5)
  000efa:  58 8f                  addq.l #$4, a7
  000efc:  4a 2d a2 09            tst.b -$5df7(a5)
  000f00:  67 04                  beq.b $f06
  000f02:  4e ba 06 fe            jsr $1602(pc)
  000f06:  4e ba 17 5a            jsr $2662(pc)
  000f0a:  42 2d 96 bb            clr.b -$6945(a5)
  000f0e:  4e ba 11 1e            jsr $202e(pc)
  000f12:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  000f16:  42 67                  clr.w -(a7)
  000f18:  a9 3a                  dc.w $a93a
  000f1a:  2f 2d a1 d8            move.l -$5e28(a5), -(a7)
  000f1e:  42 67                  clr.w -(a7)
  000f20:  a9 39                  dc.w $a939
  000f22:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  000f26:  42 67                  clr.w -(a7)
  000f28:  a9 3a                  dc.w $a93a
  000f2a:  a9 37                  dc.w $a937
  000f2c:  4e 5e                  unlk a6
  000f2e:  4e 75                  rts 
  000f30:  4e 56 00 00            link.w a6, #$0
  000f34:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  000f38:  26 6e 00 08            movea.l $8(a6), a3
  000f3c:  4a 2d a2 09            tst.b -$5df7(a5)
  000f40:  67 46                  beq.b $f88
  000f42:  20 6d a1 c4            movea.l -$5e3c(a5), a0
  000f46:  20 50                  movea.l (a0), a0
  000f48:  2e 10                  move.l (a0), d7
  000f4a:  be ad a1 c8            cmp.l -$5e38(a5), d7
  000f4e:  67 38                  beq.b $f88
  000f50:  7c ff                  moveq #$ff, d6
  000f52:  20 6d a1 c0            movea.l -$5e40(a5), a0
  000f56:  28 50                  movea.l (a0), a4
  000f58:  3a 2c 00 1e            move.w $1e(a4), d5
  000f5c:  4a 45                  tst.w d5
  000f5e:  67 06                  beq.b $f66
  000f60:  0c 45 00 10            cmpi.w #$10, d5
  000f64:  66 08                  bne.b $f6e
  000f66:  3c 2c 00 24            move.w $24(a4), d6
  000f6a:  cd ec 00 22            muls.w $22(a4), d6
  000f6e:  bc 6d a1 ae            cmp.w -$5e52(a5), d6
  000f72:  67 0c                  beq.b $f80
  000f74:  42 67                  clr.w -(a7)
  000f76:  3f 3c 03 ec            move.w #$3ec, -(a7)
  000f7a:  42 a7                  clr.l -(a7)
  000f7c:  a9 85                  dc.w $a985
  000f7e:  54 8f                  addq.l #$2, a7
  000f80:  4e ba 05 1c            jsr $149e(pc)
  000f84:  2b 47 a1 c8            move.l d7, -$5e38(a5)
  000f88:  2f 0b                  move.l a3, -(a7)
  000f8a:  a9 22                  dc.w $a922
  000f8c:  b7 ed a2 12            cmpa.l -$5dee(a5), a3
  000f90:  66 0a                  bne.b $f9c
  000f92:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000f96:  a8 d3                  dc.w $a8d3
  000f98:  4e ba 07 6c            jsr $1706(pc)
  000f9c:  2f 0b                  move.l a3, -(a7)
  000f9e:  a9 23                  dc.w $a923
  000fa0:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  000fa4:  4e 5e                  unlk a6
  000fa6:  4e 75                  rts 
  000fa8:  4e 56 ff fc            link.w a6, #$fffc
  000fac:  2f 2e 00 08            move.l $8(a6), -(a7)
  000fb0:  a9 22                  dc.w $a922
  000fb2:  20 2e 00 08            move.l $8(a6), d0
  000fb6:  b0 ad a2 12            cmp.l -$5dee(a5), d0
  000fba:  66 0a                  bne.b $fc6
  000fbc:  2f 2d a2 2a            move.l -$5dd6(a5), -(a7)
  000fc0:  a8 d3                  dc.w $a8d3
  000fc2:  4e ba 07 42            jsr $1706(pc)
  000fc6:  2f 2e 00 08            move.l $8(a6), -(a7)
  000fca:  a9 23                  dc.w $a923
  000fcc:  4e 5e                  unlk a6
  000fce:  4e 75                  rts 
  000fd0:  4e 56 00 00            link.w a6, #$0
  000fd4:  4e 5e                  unlk a6
  000fd6:  4e 75                  rts 
  000fd8:  4e 56 00 00            link.w a6, #$0
  000fdc:  10 2e 00 0a            move.b $a(a6), d0
  000fe0:  6b 5e                  bmi.b $1040
  000fe2:  04 00 00 1b            subi.b #$1b, d0
  000fe6:  67 20                  beq.b $1008
  000fe8:  6a 0e                  bpl.b $ff8
  000fea:  04 00 00 ee            subi.b #$ee, d0
  000fee:  67 24                  beq.b $1014
  000ff0:  6a 4e                  bpl.b $1040
  000ff2:  52 00                  addq.b #$1, d0
  000ff4:  6a 3a                  bpl.b $1030
  000ff6:  60 48                  bra.b $1040
  000ff8:  04 00 00 45            subi.b #$45, d0
  000ffc:  67 0a                  beq.b $1008
  000ffe:  6a 40                  bpl.b $1040
  001000:  04 00 00 c0            subi.b #$c0, d0
  001004:  67 08                  beq.b $100e
  001006:  60 38                  bra.b $1040
  001008:  4e ba 02 40            jsr $124a(pc)
  00100c:  60 32                  bra.b $1040
  00100e:  4e ba 03 46            jsr $1356(pc)
  001012:  60 2c                  bra.b $1040
  001014:  4e ba 16 4c            jsr $2662(pc)
  001018:  1b 7c 00 01 96 f8      move.b #$1, -$6908(a5)
  00101e:  4e ba 03 8a            jsr $13aa(pc)
  001022:  1b 7c 00 01 96 cf      move.b #$1, -$6931(a5)
  001028:  1b 7c 00 01 96 cc      move.b #$1, -$6934(a5)
  00102e:  60 10                  bra.b $1040
  001030:  4a 2d 96 bd            tst.b -$6943(a5)
  001034:  66 06                  bne.b $103c
  001036:  4e ba 0f 7c            jsr $1fb4(pc)
  00103a:  60 04                  bra.b $1040
  00103c:  4e ba 0f f0            jsr $202e(pc)
  001040:  4e 5e                  unlk a6
  001042:  4e 75                  rts 
  001044:  4e 56 ff 00            link.w a6, #$ff00
  001048:  2f 07                  move.l d7, -(a7)
  00104a:  4e ba 10 56            jsr $20a2(pc)
  00104e:  42 67                  clr.w -(a7)
  001050:  2f 2e 00 08            move.l $8(a6), -(a7)
  001054:  a8 6b                  dc.w $a86b
  001056:  3e 1f                  move.w (a7)+, d7
  001058:  42 67                  clr.w -(a7)
  00105a:  2f 2e 00 08            move.l $8(a6), -(a7)
  00105e:  a8 6a                  dc.w $a86a
  001060:  30 1f                  move.w (a7)+, d0
  001062:  6b 00 00 ca            bmi.w $112e
  001066:  04 40 03 ea            subi.w #$3ea, d0
  00106a:  67 78                  beq.b $10e4
  00106c:  6a 0a                  bpl.b $1078
  00106e:  54 40                  addq.w #$2, d0
  001070:  67 0e                  beq.b $1080
  001072:  6a 38                  bpl.b $10ac
  001074:  60 00 00 b8            bra.w $112e
  001078:  55 40                  subq.w #$2, d0
  00107a:  6a 00 00 b2            bpl.w $112e
  00107e:  60 78                  bra.b $10f8
  001080:  30 07                  move.w d7, d0
  001082:  67 0e                  beq.b $1092
  001084:  6b 0c                  bmi.b $1092
  001086:  55 40                  subq.w #$2, d0
  001088:  6a 08                  bpl.b $1092
  00108a:  4e ba 00 d8            jsr $1164(pc)
  00108e:  60 00 00 9e            bra.w $112e
  001092:  2f 2d a1 d0            move.l -$5e30(a5), -(a7)
  001096:  3f 07                  move.w d7, -(a7)
  001098:  48 6e ff 00            pea.l -$100(a6)
  00109c:  a9 46                  dc.w $a946
  00109e:  42 67                  clr.w -(a7)
  0010a0:  48 6e ff 00            pea.l -$100(a6)
  0010a4:  a9 b6                  dc.w $a9b6
  0010a6:  54 8f                  addq.l #$2, a7
  0010a8:  60 00 00 84            bra.w $112e
  0010ac:  30 07                  move.w d7, d0
  0010ae:  0c 40 00 08            cmpi.w #$8, d0
  0010b2:  62 7a                  bhi.b $112e
  0010b4:  43 fa 00 9c            lea.l $1152(pc), a1
  0010b8:  d0 40                  add.w d0, d0
  0010ba:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0010be:  4e d1                  jmp (a1)
  0010c0:  4e ba 00 f6            jsr $11b8(pc)
  0010c4:  60 68                  bra.b $112e
  0010c6:  4e ba 01 24            jsr $11ec(pc)
  0010ca:  60 62                  bra.b $112e
  0010cc:  4e ba 01 48            jsr $1216(pc)
  0010d0:  60 5c                  bra.b $112e
  0010d2:  4e ba 01 44            jsr $1218(pc)
  0010d6:  60 56                  bra.b $112e
  0010d8:  4e ba 01 40            jsr $121a(pc)
  0010dc:  60 50                  bra.b $112e
  0010de:  4e ba 01 3c            jsr $121c(pc)
  0010e2:  60 4a                  bra.b $112e
  0010e4:  4a 2d 96 bb            tst.b -$6945(a5)
  0010e8:  66 44                  bne.b $112e
  0010ea:  42 27                  clr.b -(a7)
  0010ec:  70 ff                  moveq #$ff, d0
  0010ee:  d0 47                  add.w d7, d0
  0010f0:  3f 00                  move.w d0, -(a7)
  0010f2:  a9 c2                  dc.w $a9c2
  0010f4:  54 8f                  addq.l #$2, a7
  0010f6:  60 36                  bra.b $112e
  0010f8:  30 07                  move.w d7, d0
  0010fa:  0c 40 00 07            cmpi.w #$7, d0
  0010fe:  62 2e                  bhi.b $112e
  001100:  43 fa 00 40            lea.l $1142(pc), a1
  001104:  d0 40                  add.w d0, d0
  001106:  d2 f1 00 00            adda.w (a1, d0.w), a1
  00110a:  4e d1                  jmp (a1)
  00110c:  4e ba 01 3c            jsr $124a(pc)
  001110:  60 1c                  bra.b $112e
  001112:  4e ba 01 92            jsr $12a6(pc)
  001116:  60 16                  bra.b $112e
  001118:  4e ba 01 d6            jsr $12f0(pc)
  00111c:  60 10                  bra.b $112e
  00111e:  4e ba 02 1c            jsr $133c(pc)
  001122:  60 0a                  bra.b $112e
  001124:  4e ba 02 30            jsr $1356(pc)
  001128:  60 04                  bra.b $112e
  00112a:  4e ba 02 42            jsr $136e(pc)
  00112e:  42 67                  clr.w -(a7)
  001130:  a9 38                  dc.w $a938
  001132:  4a 2d 96 bb            tst.b -$6945(a5)
  001136:  67 04                  beq.b $113c
  001138:  4e ba 0e 7a            jsr $1fb4(pc)
  00113c:  2e 1f                  move.l (a7)+, d7
  00113e:  4e 5e                  unlk a6
  001140:  4e 75                  rts 
  001142:  ff ec                  dc.w $ffec
  001144:  ff ca                  dc.w $ffca
  001146:  ff d0                  dc.w $ffd0
  001148:  ff d6                  dc.w $ffd6
  00114a:  ff ec                  dc.w $ffec
  00114c:  ff dc                  dc.w $ffdc
  00114e:  ff e2                  dc.w $ffe2
  001150:  ff e8                  dc.w $ffe8
  001152:  ff dc                  dc.w $ffdc
  001154:  ff 6e                  dc.w $ff6e
  001156:  ff 74                  dc.w $ff74
  001158:  ff dc                  dc.w $ffdc
  00115a:  ff 7a                  dc.w $ff7a
  00115c:  ff 80                  dc.w $ff80
  00115e:  ff 86                  dc.w $ff86
  001160:  ff dc                  dc.w $ffdc
  001162:  ff 8c                  dc.w $ff8c
  001164:  4e 56 ff fe            link.w a6, #$fffe
  001168:  48 e7 00 18            movem.l a3-a4, -(a7)
  00116c:  42 a7                  clr.l -(a7)
  00116e:  2f 3c 50 6f c4 50      move.l #$506fc450, -(a7)
  001174:  42 67                  clr.w -(a7)
  001176:  a9 a0                  dc.w $a9a0
  001178:  28 5f                  movea.l (a7)+, a4
  00117a:  4e ba 0f 34            jsr $20b0(pc)
  00117e:  2f 14                  move.l (a4), -(a7)
  001180:  42 a7                  clr.l -(a7)
  001182:  42 a7                  clr.l -(a7)
  001184:  42 a7                  clr.l -(a7)
  001186:  a9 8b                  dc.w $a98b
  001188:  42 a7                  clr.l -(a7)
  00118a:  3f 3c 03 e8            move.w #$3e8, -(a7)
  00118e:  42 a7                  clr.l -(a7)
  001190:  48 78 ff ff            pea.l $ffff.w
  001194:  a9 7c                  dc.w $a97c
  001196:  26 5f                  movea.l (a7)+, a3
  001198:  20 0b                  move.l a3, d0
  00119a:  67 0c                  beq.b $11a8
  00119c:  42 a7                  clr.l -(a7)
  00119e:  48 6e ff fe            pea.l -$2(a6)
  0011a2:  a9 91                  dc.w $a991
  0011a4:  2f 0b                  move.l a3, -(a7)
  0011a6:  a9 83                  dc.w $a983
  0011a8:  4e ba 0f 10            jsr $20ba(pc)
  0011ac:  2f 0c                  move.l a4, -(a7)
  0011ae:  a9 a3                  dc.w $a9a3
  0011b0:  4c df 18 00            movem.l (a7)+, a3-a4
  0011b4:  4e 5e                  unlk a6
  0011b6:  4e 75                  rts 
  0011b8:  4e ba 00 7e            jsr $1238(pc)
  0011bc:  3b 7c 00 01 ba 64      move.w #$1, -$459c(a5)
  0011c2:  42 2d a1 24            clr.b -$5edc(a5)
  0011c6:  70 00                  moveq #$0, d0
  0011c8:  48 80                  ext.w d0
  0011ca:  3b 40 a1 22            move.w d0, -$5ede(a5)
  0011ce:  3b 40 b9 3e            move.w d0, -$46c2(a5)
  0011d2:  42 2d 96 bf            clr.b -$6941(a5)
  0011d6:  3b 7c 00 04 96 e8      move.w #$4, -$6918(a5)
  0011dc:  3f 3c 00 03            move.w #$3, -(a7)
  0011e0:  4e ba 0a 2c            jsr $1c0e(pc)
  0011e4:  4e ba 00 a6            jsr $128c(pc)
  0011e8:  54 8f                  addq.l #$2, a7
  0011ea:  4e 75                  rts 
  0011ec:  4a 2d 96 cd            tst.b -$6933(a5)
  0011f0:  67 22                  beq.b $1214
  0011f2:  4e ba 00 44            jsr $1238(pc)
  0011f6:  42 2d a1 24            clr.b -$5edc(a5)
  0011fa:  70 00                  moveq #$0, d0
  0011fc:  48 80                  ext.w d0
  0011fe:  3b 40 a1 22            move.w d0, -$5ede(a5)
  001202:  3b 40 b9 3e            move.w d0, -$46c2(a5)
  001206:  42 2d 96 bf            clr.b -$6941(a5)
  00120a:  3b 7c 00 0a 96 e8      move.w #$a, -$6918(a5)
  001210:  4e ba 00 7a            jsr $128c(pc)
  001214:  4e 75                  rts 
  001216:  4e 75                  rts 
  001218:  4e 75                  rts 
  00121a:  4e 75                  rts 
  00121c:  4e ba 00 1a            jsr $1238(pc)
  001220:  4e ba 12 44            jsr $2466(pc)
  001224:  42 2d 96 cc            clr.b -$6934(a5)
  001228:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  00122e:  4e 75                  rts 
  001230:  70 00                  moveq #$0, d0
  001232:  4e 75                  rts 
  001234:  70 00                  moveq #$0, d0
  001236:  4e 75                  rts 
  001238:  2f 07                  move.l d7, -(a7)
  00123a:  7e 00                  moveq #$0, d7
  00123c:  10 07                  move.b d7, d0
  00123e:  2e 1f                  move.l (a7)+, d7
  001240:  4e 75                  rts 
  001242:  70 00                  moveq #$0, d0
  001244:  4e 75                  rts 
  001246:  70 00                  moveq #$0, d0
  001248:  4e 75                  rts 
  00124a:  4a 2d 96 f8            tst.b -$6908(a5)
  00124e:  67 10                  beq.b $1260
  001250:  4e ba 14 3e            jsr $2690(pc)
  001254:  42 2d 96 f8            clr.b -$6908(a5)
  001258:  1b 7c 00 01 96 cc      move.b #$1, -$6934(a5)
  00125e:  60 26                  bra.b $1286
  001260:  4e ba 14 00            jsr $2662(pc)
  001264:  0c 6d 00 07 96 e8      cmpi.w #$7, -$6918(a5)
  00126a:  66 10                  bne.b $127c
  00126c:  48 6d 97 44            pea.l -$68bc(a5)
  001270:  4e ad 05 12            jsr $512(a5)
  001274:  3b 7c 00 02 ba 86      move.w #$2, -$457a(a5)
  00127a:  58 8f                  addq.l #$4, a7
  00127c:  1b 7c 00 01 96 f8      move.b #$1, -$6908(a5)
  001282:  42 2d 96 cc            clr.b -$6934(a5)
  001286:  4e ba 01 22            jsr $13aa(pc)
  00128a:  4e 75                  rts 
  00128c:  4a 2d 96 f8            tst.b -$6908(a5)
  001290:  67 12                  beq.b $12a4
  001292:  4e ba 13 fc            jsr $2690(pc)
  001296:  42 2d 96 f8            clr.b -$6908(a5)
  00129a:  1b 7c 00 01 96 cc      move.b #$1, -$6934(a5)
  0012a0:  4e ba 01 08            jsr $13aa(pc)
  0012a4:  4e 75                  rts 
  0012a6:  4a 2d 96 f9            tst.b -$6907(a5)
  0012aa:  66 42                  bne.b $12ee
  0012ac:  4a 2d 96 fa            tst.b -$6906(a5)
  0012b0:  67 14                  beq.b $12c6
  0012b2:  4a 2d 96 dc            tst.b -$6924(a5)
  0012b6:  67 08                  beq.b $12c0
  0012b8:  4e ba 12 82            jsr $253c(pc)
  0012bc:  4e ba 14 5a            jsr $2718(pc)
  0012c0:  42 2d 96 fa            clr.b -$6906(a5)
  0012c4:  60 10                  bra.b $12d6
  0012c6:  4a 2d 96 dc            tst.b -$6924(a5)
  0012ca:  67 04                  beq.b $12d0
  0012cc:  4e ba 13 ec            jsr $26ba(pc)
  0012d0:  1b 7c 00 01 96 fa      move.b #$1, -$6906(a5)
  0012d6:  4e ba 00 d2            jsr $13aa(pc)
  0012da:  4a ad a5 50            tst.l -$5ab0(a5)
  0012de:  67 0e                  beq.b $12ee
  0012e0:  20 6d a5 50            movea.l -$5ab0(a5), a0
  0012e4:  20 50                  movea.l (a0), a0
  0012e6:  10 ad 96 fa            move.b -$6906(a5), (a0)
  0012ea:  4e ba 00 9a            jsr $1386(pc)
  0012ee:  4e 75                  rts 
  0012f0:  4a 2d 96 fb            tst.b -$6905(a5)
  0012f4:  66 44                  bne.b $133a
  0012f6:  4a 2d 96 fc            tst.b -$6904(a5)
  0012fa:  67 14                  beq.b $1310
  0012fc:  4a 2d 96 dc            tst.b -$6924(a5)
  001300:  67 08                  beq.b $130a
  001302:  4e ba 12 38            jsr $253c(pc)
  001306:  4e ba 15 72            jsr $287a(pc)
  00130a:  42 2d 96 fc            clr.b -$6904(a5)
  00130e:  60 10                  bra.b $1320
  001310:  4a 2d 96 dc            tst.b -$6924(a5)
  001314:  67 04                  beq.b $131a
  001316:  4e ba 14 9c            jsr $27b4(pc)
  00131a:  1b 7c 00 01 96 fc      move.b #$1, -$6904(a5)
  001320:  4e ba 00 88            jsr $13aa(pc)
  001324:  4a ad a5 50            tst.l -$5ab0(a5)
  001328:  67 10                  beq.b $133a
  00132a:  20 6d a5 50            movea.l -$5ab0(a5), a0
  00132e:  20 50                  movea.l (a0), a0
  001330:  11 6d 96 fc 00 01      move.b -$6904(a5), $1(a0)
  001336:  4e ba 00 4e            jsr $1386(pc)
  00133a:  4e 75                  rts 
  00133c:  4a 2d 96 cd            tst.b -$6933(a5)
  001340:  67 12                  beq.b $1354
  001342:  4a 2d 96 ce            tst.b -$6932(a5)
  001346:  67 0c                  beq.b $1354
  001348:  4e ad 05 0a            jsr $50a(a5)
  00134c:  42 6d ba 42            clr.w -$45be(a5)
  001350:  4e ba ff 3a            jsr $128c(pc)
  001354:  4e 75                  rts 
  001356:  4a 2d 96 cd            tst.b -$6933(a5)
  00135a:  67 10                  beq.b $136c
  00135c:  4a 2d 96 ce            tst.b -$6932(a5)
  001360:  67 0a                  beq.b $136c
  001362:  3b 7c 00 01 ba 42      move.w #$1, -$45be(a5)
  001368:  4e ba ff 22            jsr $128c(pc)
  00136c:  4e 75                  rts 
  00136e:  4a 2d 96 cd            tst.b -$6933(a5)
  001372:  67 10                  beq.b $1384
  001374:  4a 2d 96 ce            tst.b -$6932(a5)
  001378:  67 0a                  beq.b $1384
  00137a:  3b 7c 00 05 96 e8      move.w #$5, -$6918(a5)
  001380:  4e ba ff 0a            jsr $128c(pc)
  001384:  4e 75                  rts 
  001386:  4a ad a5 50            tst.l -$5ab0(a5)
  00138a:  67 1a                  beq.b $13a6
  00138c:  2f 2d a5 50            move.l -$5ab0(a5), -(a7)
  001390:  a9 aa                  dc.w $a9aa
  001392:  42 67                  clr.w -(a7)
  001394:  a9 af                  dc.w $a9af
  001396:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  00139a:  4a 6d a1 6c            tst.w -$5e94(a5)
  00139e:  66 06                  bne.b $13a6
  0013a0:  2f 2d a5 50            move.l -$5ab0(a5), -(a7)
  0013a4:  a9 b0                  dc.w $a9b0
  0013a6:  4e 75                  rts 
  0013a8:  4e 75                  rts 
  0013aa:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0013ae:  3f 3c 00 01            move.w #$1, -(a7)
  0013b2:  a9 3a                  dc.w $a93a
  0013b4:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0013b8:  3f 3c 00 02            move.w #$2, -(a7)
  0013bc:  a9 3a                  dc.w $a93a
  0013be:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0013c2:  3f 3c 00 04            move.w #$4, -(a7)
  0013c6:  a9 3a                  dc.w $a93a
  0013c8:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0013cc:  3f 3c 00 05            move.w #$5, -(a7)
  0013d0:  a9 3a                  dc.w $a93a
  0013d2:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  0013d6:  3f 3c 00 06            move.w #$6, -(a7)
  0013da:  a9 3a                  dc.w $a93a
  0013dc:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0013e0:  42 67                  clr.w -(a7)
  0013e2:  a9 3a                  dc.w $a93a
  0013e4:  4a 2d 96 f9            tst.b -$6907(a5)
  0013e8:  67 0a                  beq.b $13f4
  0013ea:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0013ee:  3f 3c 00 02            move.w #$2, -(a7)
  0013f2:  a9 3a                  dc.w $a93a
  0013f4:  4a 2d 96 fb            tst.b -$6905(a5)
  0013f8:  67 0a                  beq.b $1404
  0013fa:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  0013fe:  3f 3c 00 03            move.w #$3, -(a7)
  001402:  a9 3a                  dc.w $a93a
  001404:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001408:  3f 3c 00 05            move.w #$5, -(a7)
  00140c:  a9 3a                  dc.w $a93a
  00140e:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001412:  3f 3c 00 06            move.w #$6, -(a7)
  001416:  a9 3a                  dc.w $a93a
  001418:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00141c:  3f 3c 00 07            move.w #$7, -(a7)
  001420:  a9 3a                  dc.w $a93a
  001422:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  001428:  67 70                  beq.b $149a
  00142a:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  00142e:  3f 3c 00 01            move.w #$1, -(a7)
  001432:  a9 39                  dc.w $a939
  001434:  4a 2d 96 cd            tst.b -$6933(a5)
  001438:  67 0a                  beq.b $1444
  00143a:  2f 2d a1 d4            move.l -$5e2c(a5), -(a7)
  00143e:  3f 3c 00 02            move.w #$2, -(a7)
  001442:  a9 39                  dc.w $a939
  001444:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001448:  42 67                  clr.w -(a7)
  00144a:  a9 39                  dc.w $a939
  00144c:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001450:  3f 3c 00 01            move.w #$1, -(a7)
  001454:  1f 2d 96 f8            move.b -$6908(a5), -(a7)
  001458:  a9 45                  dc.w $a945
  00145a:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00145e:  3f 3c 00 02            move.w #$2, -(a7)
  001462:  1f 2d 96 fa            move.b -$6906(a5), -(a7)
  001466:  a9 45                  dc.w $a945
  001468:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00146c:  3f 3c 00 03            move.w #$3, -(a7)
  001470:  1f 2d 96 fc            move.b -$6904(a5), -(a7)
  001474:  a9 45                  dc.w $a945
  001476:  4a 2d 96 cd            tst.b -$6933(a5)
  00147a:  67 1e                  beq.b $149a
  00147c:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001480:  3f 3c 00 05            move.w #$5, -(a7)
  001484:  a9 39                  dc.w $a939
  001486:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  00148a:  3f 3c 00 06            move.w #$6, -(a7)
  00148e:  a9 39                  dc.w $a939
  001490:  2f 2d a1 dc            move.l -$5e24(a5), -(a7)
  001494:  3f 3c 00 07            move.w #$7, -(a7)
  001498:  a9 39                  dc.w $a939
  00149a:  a9 37                  dc.w $a937
  00149c:  4e 75                  rts 
  00149e:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  0014a2:  42 a7                  clr.l -(a7)
  0014a4:  aa 32                  dc.w $aa32
  0014a6:  28 5f                  movea.l (a7)+, a4
  0014a8:  2f 2d a1 bc            move.l -$5e44(a5), -(a7)
  0014ac:  aa 31                  dc.w $aa31
  0014ae:  7e 00                  moveq #$0, d7
  0014b0:  97 cb                  suba.l a3, a3
  0014b2:  60 22                  bra.b $14d6
  0014b4:  20 6d a2 f4            movea.l -$5d0c(a5), a0
  0014b8:  20 10                  move.l (a0), d0
  0014ba:  3c 33 08 08            move.w $8(a3, d0.l), d6
  0014be:  3f 06                  move.w d6, -(a7)
  0014c0:  aa 97                  dc.w $aa97
  0014c2:  20 6d a2 12            movea.l -$5dee(a5), a0
  0014c6:  2c 28 00 50            move.l $50(a0), d6
  0014ca:  22 4d                  movea.l a5, a1
  0014cc:  d2 c7                  adda.w d7, a1
  0014ce:  13 46 a2 fa            move.b d6, -$5d06(a1)
  0014d2:  52 47                  addq.w #$1, d7
  0014d4:  50 8b                  addq.l #$8, a3
  0014d6:  be 6d a2 f8            cmp.w -$5d08(a5), d7
  0014da:  6d d8                  blt.b $14b4
  0014dc:  3f 3c 00 01            move.w #$1, -(a7)
  0014e0:  aa 97                  dc.w $aa97
  0014e2:  20 6d a1 c4            movea.l -$5e3c(a5), a0
  0014e6:  20 50                  movea.l (a0), a0
  0014e8:  2b 50 a1 c8            move.l (a0), -$5e38(a5)
  0014ec:  2f 0c                  move.l a4, -(a7)
  0014ee:  aa 31                  dc.w $aa31
  0014f0:  1b 6d a3 54 a3 d0      move.b -$5cac(a5), -$5c30(a5)
  0014f6:  1b 6d a3 55 a3 d1      move.b -$5cab(a5), -$5c2f(a5)
  0014fc:  1b 6d a3 56 a3 d2      move.b -$5caa(a5), -$5c2e(a5)
  001502:  1b 6d a3 57 a3 d3      move.b -$5ca9(a5), -$5c2d(a5)
  001508:  1b 6d a3 58 a3 d4      move.b -$5ca8(a5), -$5c2c(a5)
  00150e:  1b 6d a3 59 a3 d5      move.b -$5ca7(a5), -$5c2b(a5)
  001514:  1b 6d a3 5a a3 d6      move.b -$5ca6(a5), -$5c2a(a5)
  00151a:  1b 6d a3 5b a3 d7      move.b -$5ca5(a5), -$5c29(a5)
  001520:  1b 6d a3 5c a3 d8      move.b -$5ca4(a5), -$5c28(a5)
  001526:  1b 6d a3 5d a3 d9      move.b -$5ca3(a5), -$5c27(a5)
  00152c:  1b 6d a3 5e a3 da      move.b -$5ca2(a5), -$5c26(a5)
  001532:  1b 6d a3 5f a3 db      move.b -$5ca1(a5), -$5c25(a5)
  001538:  1b 6d a3 60 a3 dc      move.b -$5ca0(a5), -$5c24(a5)
  00153e:  1b 6d a2 ff a3 c3      move.b -$5d01(a5), -$5c3d(a5)
  001544:  1b 6d a3 00 a3 c4      move.b -$5d00(a5), -$5c3c(a5)
  00154a:  1b 6d a3 01 a3 c5      move.b -$5cff(a5), -$5c3b(a5)
  001550:  1b 6d a3 11 a3 c6      move.b -$5cef(a5), -$5c3a(a5)
  001556:  1b 6d a3 12 a3 c7      move.b -$5cee(a5), -$5c39(a5)
  00155c:  1b 6d a3 13 a3 c8      move.b -$5ced(a5), -$5c38(a5)
  001562:  1b 6d a3 0a a3 c9      move.b -$5cf6(a5), -$5c37(a5)
  001568:  1b 6d a3 0b a3 ca      move.b -$5cf5(a5), -$5c36(a5)
  00156e:  1b 6d a2 fd a3 cb      move.b -$5d03(a5), -$5c35(a5)
  001574:  1b 6d a2 fe a3 cc      move.b -$5d02(a5), -$5c34(a5)
  00157a:  1b 6d a2 ff a3 cd      move.b -$5d01(a5), -$5c33(a5)
  001580:  1b 6d a3 0c a3 ce      move.b -$5cf4(a5), -$5c32(a5)
  001586:  1b 6d a3 0d a3 cf      move.b -$5cf3(a5), -$5c31(a5)
  00158c:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  001590:  4e 75                  rts 
  001592:  2f 07                  move.l d7, -(a7)
  001594:  7e 00                  moveq #$0, d7
  001596:  60 0e                  bra.b $15a6
  001598:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  00159c:  3f 07                  move.w d7, -(a7)
  00159e:  48 78 00 04            pea.l $4.w
  0015a2:  aa 9e                  dc.w $aa9e
  0015a4:  52 47                  addq.w #$1, d7
  0015a6:  be 6d a2 36            cmp.w -$5dca(a5), d7
  0015aa:  6d ec                  blt.b $1598
  0015ac:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  0015b0:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  0015b6:  42 67                  clr.w -(a7)
  0015b8:  aa 9e                  dc.w $aa9e
  0015ba:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  0015be:  2f 3c 00 02 00 01      move.l #$20001, -(a7)
  0015c4:  42 67                  clr.w -(a7)
  0015c6:  aa 9e                  dc.w $aa9e
  0015c8:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  0015cc:  aa 94                  dc.w $aa94
  0015ce:  20 6d a1 bc            movea.l -$5e44(a5), a0
  0015d2:  20 50                  movea.l (a0), a0
  0015d4:  20 68 00 16            movea.l $16(a0), a0
  0015d8:  20 50                  movea.l (a0), a0
  0015da:  22 6d a2 ca            movea.l -$5d36(a5), a1
  0015de:  22 51                  movea.l (a1), a1
  0015e0:  23 68 00 2a 00 2a      move.l $2a(a0), $2a(a1)
  0015e6:  20 6d a1 bc            movea.l -$5e44(a5), a0
  0015ea:  20 50                  movea.l (a0), a0
  0015ec:  20 68 00 16            movea.l $16(a0), a0
  0015f0:  20 50                  movea.l (a0), a0
  0015f2:  22 6d a2 ca            movea.l -$5d36(a5), a1
  0015f6:  22 51                  movea.l (a1), a1
  0015f8:  33 68 00 0e 00 0e      move.w $e(a0), $e(a1)
  0015fe:  2e 1f                  move.l (a7)+, d7
  001600:  4e 75                  rts 
  001602:  2f 07                  move.l d7, -(a7)
  001604:  7e 00                  moveq #$0, d7
  001606:  60 0c                  bra.b $1614
  001608:  2f 2d a2 2e            move.l -$5dd2(a5), -(a7)
  00160c:  3f 07                  move.w d7, -(a7)
  00160e:  42 a7                  clr.l -(a7)
  001610:  aa 9e                  dc.w $aa9e
  001612:  52 47                  addq.w #$1, d7
  001614:  be 6d a2 36            cmp.w -$5dca(a5), d7
  001618:  6d ee                  blt.b $1608
  00161a:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  00161e:  aa 94                  dc.w $aa94
  001620:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001624:  20 50                  movea.l (a0), a0
  001626:  21 6d a2 f4 00 2a      move.l -$5d0c(a5), $2a(a0)
  00162c:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001630:  20 50                  movea.l (a0), a0
  001632:  42 68 00 0e            clr.w $e(a0)
  001636:  2e 1f                  move.l (a7)+, d7
  001638:  4e 75                  rts 
  00163a:  30 2d a5 5c            move.w -$5aa4(a5), d0
  00163e:  0c 40 00 0a            cmpi.w #$a, d0
  001642:  62 00 00 aa            bhi.w $16ee
  001646:  43 fa 00 a8            lea.l $16f0(pc), a1
  00164a:  d0 40                  add.w d0, d0
  00164c:  d2 f1 00 00            adda.w (a1, d0.w), a1
  001650:  4e d1                  jmp (a1)
  001652:  4a 6d ba 1a            tst.w -$45e6(a5)
  001656:  67 00 00 96            beq.w $16ee
  00165a:  3f 3c 00 01            move.w #$1, -(a7)
  00165e:  3f 2d ba 18            move.w -$45e8(a5), -(a7)
  001662:  3f 3c 00 02            move.w #$2, -(a7)
  001666:  4e ba 08 22            jsr $1e8a(pc)
  00166a:  3b 7c 00 01 96 ea      move.w #$1, -$6916(a5)
  001670:  5c 8f                  addq.l #$6, a7
  001672:  60 7a                  bra.b $16ee
  001674:  2f 3c 00 20 ff f8      move.l #$20fff8, -(a7)
  00167a:  4e ba 07 64            jsr $1de0(pc)
  00167e:  58 8f                  addq.l #$4, a7
  001680:  60 6c                  bra.b $16ee
  001682:  2f 3c 00 08 ff e0      move.l #$8ffe0, -(a7)
  001688:  4e ba 07 56            jsr $1de0(pc)
  00168c:  58 8f                  addq.l #$4, a7
  00168e:  60 5e                  bra.b $16ee
  001690:  2f 3c 00 05 ff e0      move.l #$5ffe0, -(a7)
  001696:  4e ba 07 48            jsr $1de0(pc)
  00169a:  58 8f                  addq.l #$4, a7
  00169c:  60 50                  bra.b $16ee
  00169e:  2f 3c 00 08 ff e0      move.l #$8ffe0, -(a7)
  0016a4:  4e ba 07 3a            jsr $1de0(pc)
  0016a8:  58 8f                  addq.l #$4, a7
  0016aa:  60 42                  bra.b $16ee
  0016ac:  2f 3c 00 01 ff 00      move.l #$1ff00, -(a7)
  0016b2:  4e ba 07 2c            jsr $1de0(pc)
  0016b6:  58 8f                  addq.l #$4, a7
  0016b8:  60 34                  bra.b $16ee
  0016ba:  2f 3c 00 08 00 00      move.l #$80000, -(a7)
  0016c0:  4e ba 06 2e            jsr $1cf0(pc)
  0016c4:  58 8f                  addq.l #$4, a7
  0016c6:  60 26                  bra.b $16ee
  0016c8:  2f 3c ff f8 00 00      move.l #$fff80000, -(a7)
  0016ce:  4e ba 06 20            jsr $1cf0(pc)
  0016d2:  58 8f                  addq.l #$4, a7
  0016d4:  60 18                  bra.b $16ee
  0016d6:  48 78 00 04            pea.l $4.w
  0016da:  4e ba 06 14            jsr $1cf0(pc)
  0016de:  58 8f                  addq.l #$4, a7
  0016e0:  60 0c                  bra.b $16ee
  0016e2:  2f 3c 00 00 ff fc      move.l #$fffc, -(a7)
  0016e8:  4e ba 06 06            jsr $1cf0(pc)
  0016ec:  58 8f                  addq.l #$4, a7
  0016ee:  4e 75                  rts 
  0016f0:  ff 62                  dc.w $ff62
  0016f2:  ff fe                  dc.w $fffe
  0016f4:  ff 84                  dc.w $ff84
  0016f6:  ff 92                  dc.w $ff92
  0016f8:  ff a0                  dc.w $ffa0
  0016fa:  ff ae                  dc.w $ffae
  0016fc:  ff bc                  dc.w $ffbc
  0016fe:  ff ca                  dc.w $ffca
  001700:  ff d8                  dc.w $ffd8
  001702:  ff e6                  dc.w $ffe6
  001704:  ff f2                  dc.w $fff2
  001706:  2f 07                  move.l d7, -(a7)
  001708:  4a 2d a2 09            tst.b -$5df7(a5)
  00170c:  67 1c                  beq.b $172a
  00170e:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001712:  2f 10                  move.l (a0), -(a7)
  001714:  22 6d a2 16            movea.l -$5dea(a5), a1
  001718:  2f 11                  move.l (a1), -(a7)
  00171a:  48 6d a2 dc            pea.l -$5d24(a5)
  00171e:  48 6d a5 c4            pea.l -$5a3c(a5)
  001722:  42 67                  clr.w -(a7)
  001724:  42 a7                  clr.l -(a7)
  001726:  a8 ec                  dc.w $a8ec
  001728:  60 22                  bra.b $174c
  00172a:  4a 6d 96 ea            tst.w -$6916(a5)
  00172e:  66 04                  bne.b $1734
  001730:  7e 00                  moveq #$0, d7
  001732:  60 02                  bra.b $1736
  001734:  7e 04                  moveq #$4, d7
  001736:  2f 2d a2 ce            move.l -$5d32(a5), -(a7)
  00173a:  2f 2d a2 1a            move.l -$5de6(a5), -(a7)
  00173e:  48 6d a2 dc            pea.l -$5d24(a5)
  001742:  48 6d a5 c4            pea.l -$5a3c(a5)
  001746:  3f 07                  move.w d7, -(a7)
  001748:  42 a7                  clr.l -(a7)
  00174a:  a8 ec                  dc.w $a8ec
  00174c:  2e 1f                  move.l (a7)+, d7
  00174e:  4e 75                  rts 
  001750:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  001754:  4a 2d a2 09            tst.b -$5df7(a5)
  001758:  67 2a                  beq.b $1784
  00175a:  7e 00                  moveq #$0, d7
  00175c:  49 ed f2 2c            lea.l -$dd4(a5), a4
  001760:  60 1a                  bra.b $177c
  001762:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001766:  2f 10                  move.l (a0), -(a7)
  001768:  22 6d a2 16            movea.l -$5dea(a5), a1
  00176c:  2f 11                  move.l (a1), -(a7)
  00176e:  2f 0c                  move.l a4, -(a7)
  001770:  2f 0c                  move.l a4, -(a7)
  001772:  42 67                  clr.w -(a7)
  001774:  42 a7                  clr.l -(a7)
  001776:  a8 ec                  dc.w $a8ec
  001778:  52 47                  addq.w #$1, d7
  00177a:  50 8c                  addq.l #$8, a4
  00177c:  be 6d f2 2a            cmp.w -$dd6(a5), d7
  001780:  6d e0                  blt.b $1762
  001782:  60 30                  bra.b $17b4
  001784:  4a 6d 96 ea            tst.w -$6916(a5)
  001788:  66 04                  bne.b $178e
  00178a:  7c 00                  moveq #$0, d6
  00178c:  60 02                  bra.b $1790
  00178e:  7c 04                  moveq #$4, d6
  001790:  7e 00                  moveq #$0, d7
  001792:  49 ed f2 2c            lea.l -$dd4(a5), a4
  001796:  60 16                  bra.b $17ae
  001798:  2f 2d a2 ce            move.l -$5d32(a5), -(a7)
  00179c:  2f 2d a2 1a            move.l -$5de6(a5), -(a7)
  0017a0:  2f 0c                  move.l a4, -(a7)
  0017a2:  2f 0c                  move.l a4, -(a7)
  0017a4:  3f 06                  move.w d6, -(a7)
  0017a6:  42 a7                  clr.l -(a7)
  0017a8:  a8 ec                  dc.w $a8ec
  0017aa:  52 47                  addq.w #$1, d7
  0017ac:  50 8c                  addq.l #$8, a4
  0017ae:  be 6d f2 2a            cmp.w -$dd6(a5), d7
  0017b2:  6d e4                  blt.b $1798
  0017b4:  42 6d f2 2a            clr.w -$dd6(a5)
  0017b8:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  0017bc:  4e 75                  rts 
  0017be:  30 2d a5 5c            move.w -$5aa4(a5), d0
  0017c2:  0c 40 00 06            cmpi.w #$6, d0
  0017c6:  62 00 00 80            bhi.w $1848
  0017ca:  43 fa 00 82            lea.l $184e(pc), a1
  0017ce:  d0 40                  add.w d0, d0
  0017d0:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0017d4:  4e d1                  jmp (a1)
  0017d6:  4a 6d ba 1a            tst.w -$45e6(a5)
  0017da:  67 6c                  beq.b $1848
  0017dc:  53 6d ba 1a            subq.w #$1, -$45e6(a5)
  0017e0:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  0017e6:  3f 3c 00 02            move.w #$2, -(a7)
  0017ea:  4e ba 06 9e            jsr $1e8a(pc)
  0017ee:  42 6d 96 ea            clr.w -$6916(a5)
  0017f2:  5c 8f                  addq.l #$6, a7
  0017f4:  60 52                  bra.b $1848
  0017f6:  2f 3c 00 01 01 00      move.l #$10100, -(a7)
  0017fc:  4e ba 05 e2            jsr $1de0(pc)
  001800:  58 8f                  addq.l #$4, a7
  001802:  60 44                  bra.b $1848
  001804:  2f 3c 00 20 00 08      move.l #$200008, -(a7)
  00180a:  4e ba 05 d4            jsr $1de0(pc)
  00180e:  58 8f                  addq.l #$4, a7
  001810:  60 36                  bra.b $1848
  001812:  2f 3c 00 08 00 20      move.l #$80020, -(a7)
  001818:  4e ba 05 c6            jsr $1de0(pc)
  00181c:  58 8f                  addq.l #$4, a7
  00181e:  60 28                  bra.b $1848
  001820:  2f 3c 00 05 00 20      move.l #$50020, -(a7)
  001826:  4e ba 05 b8            jsr $1de0(pc)
  00182a:  58 8f                  addq.l #$4, a7
  00182c:  60 1a                  bra.b $1848
  00182e:  2f 3c 00 01 01 00      move.l #$10100, -(a7)
  001834:  4e ba 05 aa            jsr $1de0(pc)
  001838:  58 8f                  addq.l #$4, a7
  00183a:  60 0c                  bra.b $1848
  00183c:  2f 3c 00 08 00 20      move.l #$80020, -(a7)
  001842:  4e ba 05 9c            jsr $1de0(pc)
  001846:  58 8f                  addq.l #$4, a7
  001848:  42 6d a5 5c            clr.w -$5aa4(a5)
  00184c:  4e 75                  rts 
  00184e:  ff 88                  dc.w $ff88
  001850:  ff a8                  dc.w $ffa8
  001852:  ff b6                  dc.w $ffb6
  001854:  ff c4                  dc.w $ffc4
  001856:  ff d2                  dc.w $ffd2
  001858:  ff e0                  dc.w $ffe0
  00185a:  ff ee                  dc.w $ffee
  00185c:  2f 07                  move.l d7, -(a7)
  00185e:  1b 7c 00 01 96 cc      move.b #$1, -$6934(a5)
  001864:  42 2d 96 cd            clr.b -$6933(a5)
  001868:  42 2d 96 ce            clr.b -$6932(a5)
  00186c:  42 6d a5 ba            clr.w -$5a46(a5)
  001870:  3b 7c 00 01 a5 bc      move.w #$1, -$5a44(a5)
  001876:  42 2d 96 f8            clr.b -$6908(a5)
  00187a:  42 a7                  clr.l -(a7)
  00187c:  a9 75                  dc.w $a975   ; _TickCount
  00187e:  2e 1f                  move.l (a7)+, d7
  001880:  02 47 0f ff            andi.w #$fff, d7
  001884:  06 47 00 c8            addi.w #$c8, d7
  001888:  60 0a                  bra.b $1894
  00188a:  3f 3c 00 01            move.w #$1, -(a7)
  00188e:  4e ba 03 ca            jsr $1c5a(pc)
  001892:  54 8f                  addq.l #$2, a7
  001894:  30 07                  move.w d7, d0
  001896:  53 47                  subq.w #$1, d7
  001898:  4a 40                  tst.w d0
  00189a:  66 ee                  bne.b $188a
  00189c:  4e ad 03 7a            jsr $37a(a5)
  0018a0:  4e ad 03 82            jsr $382(a5)
  0018a4:  4a 6d a1 22            tst.w -$5ede(a5)
  0018a8:  67 22                  beq.b $18cc
  0018aa:  4e ba f9 96            jsr $1242(pc)
  0018ae:  4a 00                  tst.b d0
  0018b0:  67 26                  beq.b $18d8
  0018b2:  3b 6d ba 64 ba 62      move.w -$459c(a5), -$459e(a5)
  0018b8:  3b 7c 00 01 b9 3e      move.w #$1, -$46c2(a5)
  0018be:  1b 7c 00 01 96 bf      move.b #$1, -$6941(a5)
  0018c4:  3b 7c 00 04 96 e8      move.w #$4, -$6918(a5)
  0018ca:  60 0c                  bra.b $18d8
  0018cc:  3b 7c 00 02 ba 62      move.w #$2, -$459e(a5)
  0018d2:  3b 7c 00 01 96 e8      move.w #$1, -$6918(a5)
  0018d8:  2e 1f                  move.l (a7)+, d7
  0018da:  4e 75                  rts 
  0018dc:  42 2d 96 bf            clr.b -$6941(a5)
  0018e0:  42 2d 96 cd            clr.b -$6933(a5)
  0018e4:  42 2d 96 ce            clr.b -$6932(a5)
  0018e8:  4e ba fa c0            jsr $13aa(pc)
  0018ec:  42 6d ba 64            clr.w -$459c(a5)
  0018f0:  42 6d 96 d2            clr.w -$692e(a5)
  0018f4:  42 6d b9 3e            clr.w -$46c2(a5)
  0018f8:  42 6d a5 66            clr.w -$5a9a(a5)
  0018fc:  42 6d a5 68            clr.w -$5a98(a5)
  001900:  42 2d a5 6a            clr.b -$5a96(a5)
  001904:  42 ad a5 6c            clr.l -$5a94(a5)
  001908:  3b 7c 00 02 96 e8      move.w #$2, -$6918(a5)
  00190e:  4e 75                  rts 
  001910:  4a 6d a5 68            tst.w -$5a98(a5)
  001914:  66 3c                  bne.b $1952
  001916:  4a 2d a5 6a            tst.b -$5a96(a5)
  00191a:  67 0c                  beq.b $1928
  00191c:  4e ba 0c 4e            jsr $256c(pc)
  001920:  4a 00                  tst.b d0
  001922:  66 04                  bne.b $1928
  001924:  42 2d a5 6a            clr.b -$5a96(a5)
  001928:  4a ad a5 6c            tst.l -$5a94(a5)
  00192c:  6f 12                  ble.b $1940
  00192e:  2f 2d a5 6c            move.l -$5a94(a5), -(a7)
  001932:  4e ba 0c b6            jsr $25ea(pc)
  001936:  4a 00                  tst.b d0
  001938:  58 8f                  addq.l #$4, a7
  00193a:  67 04                  beq.b $1940
  00193c:  42 ad a5 6c            clr.l -$5a94(a5)
  001940:  4a 2d a5 6a            tst.b -$5a96(a5)
  001944:  66 10                  bne.b $1956
  001946:  4a ad a5 6c            tst.l -$5a94(a5)
  00194a:  66 0a                  bne.b $1956
  00194c:  4e ad 03 9a            jsr $39a(a5)
  001950:  60 04                  bra.b $1956
  001952:  53 6d a5 68            subq.w #$1, -$5a98(a5)
  001956:  70 05                  moveq #$5, d0
  001958:  2b 40 96 ec            move.l d0, -$6914(a5)
  00195c:  4a 6d a5 66            tst.w -$5a9a(a5)
  001960:  66 10                  bne.b $1972
  001962:  3f 3c 00 05            move.w #$5, -(a7)
  001966:  4e ba 02 a6            jsr $1c0e(pc)
  00196a:  3b 7c 00 04 96 e8      move.w #$4, -$6918(a5)
  001970:  54 8f                  addq.l #$2, a7
  001972:  4e 75                  rts 
  001974:  4a 6d a5 72            tst.w -$5a8e(a5)
  001978:  66 3e                  bne.b $19b8
  00197a:  4a 2d a5 6a            tst.b -$5a96(a5)
  00197e:  67 0c                  beq.b $198c
  001980:  4e ba 0b ea            jsr $256c(pc)
  001984:  4a 00                  tst.b d0
  001986:  66 04                  bne.b $198c
  001988:  42 2d a5 6a            clr.b -$5a96(a5)
  00198c:  4a ad a5 6c            tst.l -$5a94(a5)
  001990:  6f 12                  ble.b $19a4
  001992:  2f 2d a5 6c            move.l -$5a94(a5), -(a7)
  001996:  4e ba 0c 52            jsr $25ea(pc)
  00199a:  4a 00                  tst.b d0
  00199c:  58 8f                  addq.l #$4, a7
  00199e:  67 04                  beq.b $19a4
  0019a0:  42 ad a5 6c            clr.l -$5a94(a5)
  0019a4:  4a 2d a5 6a            tst.b -$5a96(a5)
  0019a8:  66 12                  bne.b $19bc
  0019aa:  4a ad a5 6c            tst.l -$5a94(a5)
  0019ae:  66 0c                  bne.b $19bc
  0019b0:  20 6d a5 74            movea.l -$5a8c(a5), a0
  0019b4:  4e 90                  jsr (a0)
  0019b6:  60 04                  bra.b $19bc
  0019b8:  53 6d a5 72            subq.w #$1, -$5a8e(a5)
  0019bc:  70 05                  moveq #$5, d0
  0019be:  2b 40 96 ec            move.l d0, -$6914(a5)
  0019c2:  4e ad 01 f2            jsr $1f2(a5)
  0019c6:  4a 2d 96 cd            tst.b -$6933(a5)
  0019ca:  67 0a                  beq.b $19d6
  0019cc:  4a 2d a5 be            tst.b -$5a42(a5)
  0019d0:  67 04                  beq.b $19d6
  0019d2:  42 6d a5 70            clr.w -$5a90(a5)
  0019d6:  4a 6d a5 70            tst.w -$5a90(a5)
  0019da:  66 10                  bne.b $19ec
  0019dc:  3f 3c 00 05            move.w #$5, -(a7)
  0019e0:  4e ba 02 2c            jsr $1c0e(pc)
  0019e4:  3b 6d a5 78 96 e8      move.w -$5a88(a5), -$6918(a5)
  0019ea:  54 8f                  addq.l #$2, a7
  0019ec:  4e 75                  rts 
  0019ee:  3f 3c 00 07            move.w #$7, -(a7)
  0019f2:  4e ba 02 1a            jsr $1c0e(pc)
  0019f6:  42 6d a5 66            clr.w -$5a9a(a5)
  0019fa:  42 6d a5 68            clr.w -$5a98(a5)
  0019fe:  70 05                  moveq #$5, d0
  001a00:  2b 40 96 ec            move.l d0, -$6914(a5)
  001a04:  3e ad ba 64            move.w -$459c(a5), (a7)
  001a08:  4e ad 01 c2            jsr $1c2(a5)
  001a0c:  4a 6d ba 64            tst.w -$459c(a5)
  001a10:  54 8f                  addq.l #$2, a7
  001a12:  6f 06                  ble.b $1a1a
  001a14:  1b 7c 00 01 96 cd      move.b #$1, -$6933(a5)
  001a1a:  4e ba f9 8e            jsr $13aa(pc)
  001a1e:  42 6d 96 d0            clr.w -$6930(a5)
  001a22:  3b 7c 00 05 96 e8      move.w #$5, -$6918(a5)
  001a28:  4e 75                  rts 
  001a2a:  42 2d 96 ce            clr.b -$6932(a5)
  001a2e:  3f 3c 00 0b            move.w #$b, -(a7)
  001a32:  4e ba 01 da            jsr $1c0e(pc)
  001a36:  3e ad ba 64            move.w -$459c(a5), (a7)
  001a3a:  4e ad 01 ca            jsr $1ca(a5)
  001a3e:  4a 6d ba 64            tst.w -$459c(a5)
  001a42:  54 8f                  addq.l #$2, a7
  001a44:  66 08                  bne.b $1a4e
  001a46:  3b 7c 00 06 96 e8      move.w #$6, -$6918(a5)
  001a4c:  60 1c                  bra.b $1a6a
  001a4e:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  001a54:  67 0e                  beq.b $1a64
  001a56:  1b 7c 00 01 96 ce      move.b #$1, -$6932(a5)
  001a5c:  3b 7c 00 07 96 e8      move.w #$7, -$6918(a5)
  001a62:  60 06                  bra.b $1a6a
  001a64:  3b 7c 00 08 96 e8      move.w #$8, -$6918(a5)
  001a6a:  4e ba f9 3e            jsr $13aa(pc)
  001a6e:  4e ba 09 c8            jsr $2438(pc)
  001a72:  4e 75                  rts 
  001a74:  2f 07                  move.l d7, -(a7)
  001a76:  4e ad 01 d2            jsr $1d2(a5)
  001a7a:  3e 00                  move.w d0, d7
  001a7c:  4a 47                  tst.w d7
  001a7e:  67 10                  beq.b $1a90
  001a80:  3f 3c 00 0f            move.w #$f, -(a7)
  001a84:  4e ba 01 88            jsr $1c0e(pc)
  001a88:  3b 7c 00 0b 96 e8      move.w #$b, -$6918(a5)
  001a8e:  54 8f                  addq.l #$2, a7
  001a90:  2e 1f                  move.l (a7)+, d7
  001a92:  4e 75                  rts 
  001a94:  2f 07                  move.l d7, -(a7)
  001a96:  4e ad 01 d2            jsr $1d2(a5)
  001a9a:  3e 00                  move.w d0, d7
  001a9c:  4a 47                  tst.w d7
  001a9e:  67 34                  beq.b $1ad4
  001aa0:  3f 3c 00 09            move.w #$9, -(a7)
  001aa4:  4e ba 01 68            jsr $1c0e(pc)
  001aa8:  30 07                  move.w d7, d0
  001aaa:  54 8f                  addq.l #$2, a7
  001aac:  67 26                  beq.b $1ad4
  001aae:  6b 24                  bmi.b $1ad4
  001ab0:  57 40                  subq.w #$3, d0
  001ab2:  67 16                  beq.b $1aca
  001ab4:  6a 1e                  bpl.b $1ad4
  001ab6:  52 40                  addq.w #$1, d0
  001ab8:  6a 08                  bpl.b $1ac2
  001aba:  3b 7c 00 05 96 e8      move.w #$5, -$6918(a5)
  001ac0:  60 12                  bra.b $1ad4
  001ac2:  3b 7c 00 09 96 e8      move.w #$9, -$6918(a5)
  001ac8:  60 0a                  bra.b $1ad4
  001aca:  4e ba fe 10            jsr $18dc(pc)
  001ace:  3b 7c 00 0a 96 e8      move.w #$a, -$6918(a5)
  001ad4:  2e 1f                  move.l (a7)+, d7
  001ad6:  4e 75                  rts 
  001ad8:  4e 75                  rts 
  001ada:  42 2d 96 ce            clr.b -$6932(a5)
  001ade:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  001ae4:  67 04                  beq.b $1aea
  001ae6:  42 2d 96 bf            clr.b -$6941(a5)
  001aea:  3f 3c 00 05            move.w #$5, -(a7)
  001aee:  4e ba 01 1e            jsr $1c0e(pc)
  001af2:  3b 6d ba 38 ba 64      move.w -$45c8(a5), -$459c(a5)
  001af8:  4e ba f8 b0            jsr $13aa(pc)
  001afc:  3b 7c 00 05 96 e8      move.w #$5, -$6918(a5)
  001b02:  30 2d ba 38            move.w -$45c8(a5), d0
  001b06:  54 8f                  addq.l #$2, a7
  001b08:  6b 1e                  bmi.b $1b28
  001b0a:  57 40                  subq.w #$3, d0
  001b0c:  67 14                  beq.b $1b22
  001b0e:  6a 18                  bpl.b $1b28
  001b10:  52 40                  addq.w #$1, d0
  001b12:  6b 14                  bmi.b $1b28
  001b14:  48 6d 02 02            pea.l $202(a5)
  001b18:  42 67                  clr.w -(a7)
  001b1a:  4e ad 02 22            jsr $222(a5)
  001b1e:  5c 8f                  addq.l #$6, a7
  001b20:  60 06                  bra.b $1b28
  001b22:  3b 7c 00 0a 96 e8      move.w #$a, -$6918(a5)
  001b28:  4e 75                  rts 
  001b2a:  42 2d 96 ce            clr.b -$6932(a5)
  001b2e:  4a 6d a5 68            tst.w -$5a98(a5)
  001b32:  66 50                  bne.b $1b84
  001b34:  4a 2d a5 6a            tst.b -$5a96(a5)
  001b38:  67 0c                  beq.b $1b46
  001b3a:  4e ba 0a 30            jsr $256c(pc)
  001b3e:  4a 00                  tst.b d0
  001b40:  66 04                  bne.b $1b46
  001b42:  42 2d a5 6a            clr.b -$5a96(a5)
  001b46:  4a ad a5 6c            tst.l -$5a94(a5)
  001b4a:  6f 12                  ble.b $1b5e
  001b4c:  2f 2d a5 6c            move.l -$5a94(a5), -(a7)
  001b50:  4e ba 0a 98            jsr $25ea(pc)
  001b54:  4a 00                  tst.b d0
  001b56:  58 8f                  addq.l #$4, a7
  001b58:  67 04                  beq.b $1b5e
  001b5a:  42 ad a5 6c            clr.l -$5a94(a5)
  001b5e:  4a 2d a5 6a            tst.b -$5a96(a5)
  001b62:  66 24                  bne.b $1b88
  001b64:  4a ad a5 6c            tst.l -$5a94(a5)
  001b68:  66 1e                  bne.b $1b88
  001b6a:  30 2d 96 d0            move.w -$6930(a5), d0
  001b6e:  67 18                  beq.b $1b88
  001b70:  6b 16                  bmi.b $1b88
  001b72:  55 40                  subq.w #$2, d0
  001b74:  67 08                  beq.b $1b7e
  001b76:  6a 10                  bpl.b $1b88
  001b78:  4e ad 02 12            jsr $212(a5)
  001b7c:  60 0a                  bra.b $1b88
  001b7e:  4e ad 02 1a            jsr $21a(a5)
  001b82:  60 04                  bra.b $1b88
  001b84:  53 6d a5 68            subq.w #$1, -$5a98(a5)
  001b88:  70 05                  moveq #$5, d0
  001b8a:  2b 40 96 ec            move.l d0, -$6914(a5)
  001b8e:  4a 6d a5 66            tst.w -$5a9a(a5)
  001b92:  66 14                  bne.b $1ba8
  001b94:  3f 3c 00 0f            move.w #$f, -(a7)
  001b98:  4e ba 00 74            jsr $1c0e(pc)
  001b9c:  4e ad 03 82            jsr $382(a5)
  001ba0:  3b 7c 00 0b 96 e8      move.w #$b, -$6918(a5)
  001ba6:  54 8f                  addq.l #$2, a7
  001ba8:  4e 75                  rts 
  001baa:  4a 6d a5 68            tst.w -$5a98(a5)
  001bae:  66 3c                  bne.b $1bec
  001bb0:  4a 2d a5 6a            tst.b -$5a96(a5)
  001bb4:  67 0c                  beq.b $1bc2
  001bb6:  4e ba 09 b4            jsr $256c(pc)
  001bba:  4a 00                  tst.b d0
  001bbc:  66 04                  bne.b $1bc2
  001bbe:  42 2d a5 6a            clr.b -$5a96(a5)
  001bc2:  4a ad a5 6c            tst.l -$5a94(a5)
  001bc6:  6f 12                  ble.b $1bda
  001bc8:  2f 2d a5 6c            move.l -$5a94(a5), -(a7)
  001bcc:  4e ba 0a 1c            jsr $25ea(pc)
  001bd0:  4a 00                  tst.b d0
  001bd2:  58 8f                  addq.l #$4, a7
  001bd4:  67 04                  beq.b $1bda
  001bd6:  42 ad a5 6c            clr.l -$5a94(a5)
  001bda:  4a 2d a5 6a            tst.b -$5a96(a5)
  001bde:  66 10                  bne.b $1bf0
  001be0:  4a ad a5 6c            tst.l -$5a94(a5)
  001be4:  66 0a                  bne.b $1bf0
  001be6:  4e ad 03 a2            jsr $3a2(a5)
  001bea:  60 04                  bra.b $1bf0
  001bec:  53 6d a5 68            subq.w #$1, -$5a98(a5)
  001bf0:  70 05                  moveq #$5, d0
  001bf2:  2b 40 96 ec            move.l d0, -$6914(a5)
  001bf6:  4a 6d a5 66            tst.w -$5a9a(a5)
  001bfa:  66 10                  bne.b $1c0c
  001bfc:  3f 3c 00 07            move.w #$7, -(a7)
  001c00:  4e ba 00 0c            jsr $1c0e(pc)
  001c04:  3b 7c 00 01 96 e8      move.w #$1, -$6918(a5)
  001c0a:  54 8f                  addq.l #$2, a7
  001c0c:  4e 75                  rts 
  001c0e:  4e 56 00 00            link.w a6, #$0
  001c12:  2f 07                  move.l d7, -(a7)
  001c14:  3e 2e 00 08            move.w $8(a6), d7
  001c18:  08 07 00 03            btst.b #$3, d7
  001c1c:  67 04                  beq.b $1c22
  001c1e:  4e ba 08 46            jsr $2466(pc)
  001c22:  08 07 00 02            btst.b #$2, d7
  001c26:  67 04                  beq.b $1c2c
  001c28:  4e ad 03 aa            jsr $3aa(a5)
  001c2c:  08 07 00 01            btst.b #$1, d7
  001c30:  67 06                  beq.b $1c38
  001c32:  48 6d a5 c4            pea.l -$5a3c(a5)
  001c36:  a8 a2                  dc.w $a8a2
  001c38:  08 07 00 00            btst.b #$0, d7
  001c3c:  67 16                  beq.b $1c54
  001c3e:  1f 3c 00 01            move.b #$1, -(a7)
  001c42:  48 6d a5 c4            pea.l -$5a3c(a5)
  001c46:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  001c4a:  4e 90                  jsr (a0)
  001c4c:  48 6d a5 c4            pea.l -$5a3c(a5)
  001c50:  a9 28                  dc.w $a928
  001c52:  5c 8f                  addq.l #$6, a7
  001c54:  2e 1f                  move.l (a7)+, d7
  001c56:  4e 5e                  unlk a6
  001c58:  4e 75                  rts 
  001c5a:  4e 56 00 00            link.w a6, #$0
  001c5e:  20 2d 96 c2            move.l -$693e(a5), d0
  001c62:  22 00                  move.l d0, d1
  001c64:  0a 40 56 9a            eori.w #$569a, d0
  001c68:  48 41                  swap d1
  001c6a:  d0 41                  add.w d1, d0
  001c6c:  c0 fc 6a 59            mulu.w #$6a59, d0
  001c70:  2b 40 96 c2            move.l d0, -$693e(a5)
  001c74:  48 41                  swap d1
  001c76:  d0 41                  add.w d1, d0
  001c78:  32 2e 00 08            move.w $8(a6), d1
  001c7c:  52 41                  addq.w #$1, d1
  001c7e:  c0 c1                  mulu.w d1, d0
  001c80:  42 40                  clr.w d0
  001c82:  48 40                  swap d0
  001c84:  4e 5e                  unlk a6
  001c86:  4e 75                  rts 
  001c88:  4e 56 00 00            link.w a6, #$0
  001c8c:  2f 07                  move.l d7, -(a7)
  001c8e:  3e 2e 00 08            move.w $8(a6), d7
  001c92:  48 c7                  ext.l d7
  001c94:  8f fc 00 64            divs.w #$64, d7
  001c98:  48 47                  swap d7
  001c9a:  48 c7                  ext.l d7
  001c9c:  8f fc 00 0a            divs.w #$a, d7
  001ca0:  4a 47                  tst.w d7
  001ca2:  66 04                  bne.b $1ca8
  001ca4:  70 20                  moveq #$20, d0
  001ca6:  60 04                  bra.b $1cac
  001ca8:  70 30                  moveq #$30, d0
  001caa:  d0 07                  add.b d7, d0
  001cac:  2e 1f                  move.l (a7)+, d7
  001cae:  4e 5e                  unlk a6
  001cb0:  4e 75                  rts 
  001cb2:  4e 56 00 00            link.w a6, #$0
  001cb6:  2f 07                  move.l d7, -(a7)
  001cb8:  3e 2e 00 08            move.w $8(a6), d7
  001cbc:  48 c7                  ext.l d7
  001cbe:  8f fc 00 64            divs.w #$64, d7
  001cc2:  48 47                  swap d7
  001cc4:  48 c7                  ext.l d7
  001cc6:  8f fc 00 0a            divs.w #$a, d7
  001cca:  70 30                  moveq #$30, d0
  001ccc:  d0 07                  add.b d7, d0
  001cce:  2e 1f                  move.l (a7)+, d7
  001cd0:  4e 5e                  unlk a6
  001cd2:  4e 75                  rts 
  001cd4:  4e 56 00 00            link.w a6, #$0
  001cd8:  2f 07                  move.l d7, -(a7)
  001cda:  3e 2e 00 08            move.w $8(a6), d7
  001cde:  48 c7                  ext.l d7
  001ce0:  8f fc 00 0a            divs.w #$a, d7
  001ce4:  48 47                  swap d7
  001ce6:  70 30                  moveq #$30, d0
  001ce8:  d0 07                  add.b d7, d0
  001cea:  2e 1f                  move.l (a7)+, d7
  001cec:  4e 5e                  unlk a6
  001cee:  4e 75                  rts 
  001cf0:  4e 56 ff f8            link.w a6, #$fff8
  001cf4:  48 e7 0f 00            movem.l d4-d7, -(a7)
  001cf8:  3e 2e 00 08            move.w $8(a6), d7
  001cfc:  3a 2e 00 0a            move.w $a(a6), d5
  001d00:  4a 2d a2 0c            tst.b -$5df4(a5)
  001d04:  67 00 00 d2            beq.w $1dd8
  001d08:  2d 6d a5 c4 ff f8      move.l -$5a3c(a5), -$8(a6)
  001d0e:  2d 6d a5 c8 ff fc      move.l -$5a38(a5), -$4(a6)
  001d14:  4a 47                  tst.w d7
  001d16:  6f 18                  ble.b $1d30
  001d18:  3c 2e ff fe            move.w -$2(a6), d6
  001d1c:  9c 6e ff fa            sub.w -$6(a6), d6
  001d20:  48 c6                  ext.l d6
  001d22:  8d c7                  divs.w d7, d6
  001d24:  30 2e ff fa            move.w -$6(a6), d0
  001d28:  d0 47                  add.w d7, d0
  001d2a:  3d 40 ff fe            move.w d0, -$2(a6)
  001d2e:  60 1a                  bra.b $1d4a
  001d30:  4a 47                  tst.w d7
  001d32:  6c 16                  bge.b $1d4a
  001d34:  3c 2e ff fa            move.w -$6(a6), d6
  001d38:  9c 6e ff fe            sub.w -$2(a6), d6
  001d3c:  48 c6                  ext.l d6
  001d3e:  8d c7                  divs.w d7, d6
  001d40:  30 2e ff fe            move.w -$2(a6), d0
  001d44:  d0 47                  add.w d7, d0
  001d46:  3d 40 ff fa            move.w d0, -$6(a6)
  001d4a:  4a 45                  tst.w d5
  001d4c:  6f 18                  ble.b $1d66
  001d4e:  3c 2e ff fc            move.w -$4(a6), d6
  001d52:  9c 6e ff f8            sub.w -$8(a6), d6
  001d56:  48 c6                  ext.l d6
  001d58:  8d c5                  divs.w d5, d6
  001d5a:  30 2e ff f8            move.w -$8(a6), d0
  001d5e:  d0 45                  add.w d5, d0
  001d60:  3d 40 ff fc            move.w d0, -$4(a6)
  001d64:  60 6e                  bra.b $1dd4
  001d66:  4a 45                  tst.w d5
  001d68:  6c 6a                  bge.b $1dd4
  001d6a:  3c 2e ff f8            move.w -$8(a6), d6
  001d6e:  9c 6e ff fc            sub.w -$4(a6), d6
  001d72:  48 c6                  ext.l d6
  001d74:  8d c5                  divs.w d5, d6
  001d76:  30 2e ff fc            move.w -$4(a6), d0
  001d7a:  d0 45                  add.w d5, d0
  001d7c:  3d 40 ff f8            move.w d0, -$8(a6)
  001d80:  60 52                  bra.b $1dd4
  001d82:  42 a7                  clr.l -(a7)
  001d84:  a9 75                  dc.w $a975   ; _TickCount
  001d86:  28 1f                  move.l (a7)+, d4
  001d88:  4a 2d a2 09            tst.b -$5df7(a5)
  001d8c:  67 1c                  beq.b $1daa
  001d8e:  20 6d a2 ca            movea.l -$5d36(a5), a0
  001d92:  2f 10                  move.l (a0), -(a7)
  001d94:  22 6d a2 16            movea.l -$5dea(a5), a1
  001d98:  2f 11                  move.l (a1), -(a7)
  001d9a:  48 6e ff f8            pea.l -$8(a6)
  001d9e:  48 6e ff f8            pea.l -$8(a6)
  001da2:  42 67                  clr.w -(a7)
  001da4:  42 a7                  clr.l -(a7)
  001da6:  a8 ec                  dc.w $a8ec
  001da8:  60 16                  bra.b $1dc0
  001daa:  2f 2d a2 ce            move.l -$5d32(a5), -(a7)
  001dae:  2f 2d a2 1a            move.l -$5de6(a5), -(a7)
  001db2:  48 6e ff f8            pea.l -$8(a6)
  001db6:  48 6e ff f8            pea.l -$8(a6)
  001dba:  42 67                  clr.w -(a7)
  001dbc:  42 a7                  clr.l -(a7)
  001dbe:  a8 ec                  dc.w $a8ec
  001dc0:  42 a7                  clr.l -(a7)
  001dc2:  a9 75                  dc.w $a975   ; _TickCount
  001dc4:  b8 9f                  cmp.l (a7)+, d4
  001dc6:  67 f8                  beq.b $1dc0
  001dc8:  48 6e ff f8            pea.l -$8(a6)
  001dcc:  3f 07                  move.w d7, -(a7)
  001dce:  3f 05                  move.w d5, -(a7)
  001dd0:  a8 a8                  dc.w $a8a8
  001dd2:  53 46                  subq.w #$1, d6
  001dd4:  4a 46                  tst.w d6
  001dd6:  66 aa                  bne.b $1d82
  001dd8:  4c df 00 f0            movem.l (a7)+, d4-d7
  001ddc:  4e 5e                  unlk a6
  001dde:  4e 75                  rts 
  001de0:  4e 56 00 00            link.w a6, #$0
  001de4:  48 e7 01 08            movem.l d7/a4, -(a7)
  001de8:  4a 2d a2 0d            tst.b -$5df3(a5)
  001dec:  67 54                  beq.b $1e42
  001dee:  42 a7                  clr.l -(a7)
  001df0:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  001df4:  4e ba 1d c4            jsr $3bba(pc)
  001df8:  20 1f                  move.l (a7)+, d0
  001dfa:  a1 22                  dc.w $a122
  001dfc:  28 48                  movea.l a0, a4
  001dfe:  20 0c                  move.l a4, d0
  001e00:  67 40                  beq.b $1e42
  001e02:  60 34                  bra.b $1e38
  001e04:  30 2e 00 0a            move.w $a(a6), d0
  001e08:  d1 6d 96 f4            add.w d0, -$690c(a5)
  001e0c:  42 a7                  clr.l -(a7)
  001e0e:  a9 75                  dc.w $a975   ; _TickCount
  001e10:  2e 1f                  move.l (a7)+, d7
  001e12:  3f 2d 96 f4            move.w -$690c(a5), -(a7)
  001e16:  2f 0c                  move.l a4, -(a7)
  001e18:  4e ba 00 30            jsr $1e4a(pc)
  001e1c:  5c 8f                  addq.l #$6, a7
  001e1e:  42 a7                  clr.l -(a7)
  001e20:  a9 75                  dc.w $a975   ; _TickCount
  001e22:  be 9f                  cmp.l (a7)+, d7
  001e24:  67 f8                  beq.b $1e1e
  001e26:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  001e2a:  2f 0c                  move.l a4, -(a7)
  001e2c:  42 a7                  clr.l -(a7)
  001e2e:  3f 2d a2 36            move.w -$5dca(a5), -(a7)
  001e32:  aa 9a                  dc.w $aa9a
  001e34:  53 6e 00 08            subq.w #$1, $8(a6)
  001e38:  4a 6e 00 08            tst.w $8(a6)
  001e3c:  66 c6                  bne.b $1e04
  001e3e:  2f 0c                  move.l a4, -(a7)
  001e40:  aa 24                  dc.w $aa24
  001e42:  4c df 10 80            movem.l (a7)+, d7/a4
  001e46:  4e 5e                  unlk a6
  001e48:  4e 75                  rts 
  001e4a:  4e 56 00 00            link.w a6, #$0
  001e4e:  22 6d a2 32            movea.l -$5dce(a5), a1
  001e52:  22 51                  movea.l (a1), a1
  001e54:  32 2d a2 36            move.w -$5dca(a5), d1
  001e58:  20 6e 00 08            movea.l $8(a6), a0
  001e5c:  20 50                  movea.l (a0), a0
  001e5e:  34 2e 00 0c            move.w $c(a6), d2
  001e62:  20 d9                  move.l (a1)+, (a0)+
  001e64:  20 d9                  move.l (a1)+, (a0)+
  001e66:  60 1a                  bra.b $1e82
  001e68:  30 d9                  move.w (a1)+, (a0)+
  001e6a:  30 19                  move.w (a1)+, d0
  001e6c:  c0 c2                  mulu.w d2, d0
  001e6e:  e0 88                  lsr.l #$8, d0
  001e70:  30 c0                  move.w d0, (a0)+
  001e72:  30 19                  move.w (a1)+, d0
  001e74:  c0 c2                  mulu.w d2, d0
  001e76:  e0 88                  lsr.l #$8, d0
  001e78:  30 c0                  move.w d0, (a0)+
  001e7a:  30 19                  move.w (a1)+, d0
  001e7c:  c0 c2                  mulu.w d2, d0
  001e7e:  e0 88                  lsr.l #$8, d0
  001e80:  30 c0                  move.w d0, (a0)+
  001e82:  51 c9 ff e4            dbra d1, $1e68
  001e86:  4e 5e                  unlk a6
  001e88:  4e 75                  rts 
  001e8a:  4e 56 00 00            link.w a6, #$0
  001e8e:  2f 07                  move.l d7, -(a7)
  001e90:  42 a7                  clr.l -(a7)
  001e92:  a9 75                  dc.w $a975   ; _TickCount
  001e94:  2e 1f                  move.l (a7)+, d7
  001e96:  4a 2d a2 0d            tst.b -$5df3(a5)
  001e9a:  67 1e                  beq.b $1eba
  001e9c:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  001ea0:  3f 2e 00 08            move.w $8(a6), -(a7)
  001ea4:  20 6d a2 f4            movea.l -$5d0c(a5), a0
  001ea8:  30 2e 00 0a            move.w $a(a6), d0
  001eac:  48 c0                  ext.l d0
  001eae:  e7 88                  lsl.l #$3, d0
  001eb0:  20 50                  movea.l (a0), a0
  001eb2:  48 70 08 0a            pea.l $a(a0, d0.l)
  001eb6:  aa 99                  dc.w $aa99
  001eb8:  60 1a                  bra.b $1ed4
  001eba:  48 6d a5 c4            pea.l -$5a3c(a5)
  001ebe:  a8 a4                  dc.w $a8a4
  001ec0:  60 12                  bra.b $1ed4
  001ec2:  42 a7                  clr.l -(a7)
  001ec4:  a9 75                  dc.w $a975   ; _TickCount
  001ec6:  be 9f                  cmp.l (a7)+, d7
  001ec8:  67 f8                  beq.b $1ec2
  001eca:  42 a7                  clr.l -(a7)
  001ecc:  a9 75                  dc.w $a975   ; _TickCount
  001ece:  2e 1f                  move.l (a7)+, d7
  001ed0:  53 6e 00 0c            subq.w #$1, $c(a6)
  001ed4:  4a 6e 00 0c            tst.w $c(a6)
  001ed8:  66 e8                  bne.b $1ec2
  001eda:  2e 1f                  move.l (a7)+, d7
  001edc:  4e 5e                  unlk a6
  001ede:  4e 75                  rts 
  001ee0:  4e 56 00 00            link.w a6, #$0
  001ee4:  48 e7 07 08            movem.l d5-d7/a4, -(a7)
  001ee8:  3e 2e 00 08            move.w $8(a6), d7
  001eec:  3a 2e 00 0a            move.w $a(a6), d5
  001ef0:  4a 2d a2 0e            tst.b -$5df2(a5)
  001ef4:  67 58                  beq.b $1f4e
  001ef6:  0c 47 00 07            cmpi.w #$7, d7
  001efa:  6c 52                  bge.b $1f4e
  001efc:  7c 00                  moveq #$0, d6
  001efe:  99 cc                  suba.l a4, a4
  001f00:  60 2e                  bra.b $1f30
  001f02:  20 4d                  movea.l a5, a0
  001f04:  20 07                  move.l d7, d0
  001f06:  48 c0                  ext.l d0
  001f08:  e5 88                  lsl.l #$2, d0
  001f0a:  d1 c0                  adda.l d0, a0
  001f0c:  20 68 a2 38            movea.l -$5dc8(a0), a0
  001f10:  20 10                  move.l (a0), d0
  001f12:  20 6d a2 32            movea.l -$5dce(a5), a0
  001f16:  22 06                  move.l d6, d1
  001f18:  48 c1                  ext.l d1
  001f1a:  e7 89                  lsl.l #$3, d1
  001f1c:  d2 90                  add.l (a0), d1
  001f1e:  22 41                  movea.l d1, a1
  001f20:  23 74 08 0a 03 52      move.l $a(a4, d0.l), $352(a1)
  001f26:  33 74 08 0e 03 56      move.w $e(a4, d0.l), $356(a1)
  001f2c:  52 46                  addq.w #$1, d6
  001f2e:  50 8c                  addq.l #$8, a4
  001f30:  0c 46 00 0d            cmpi.w #$d, d6
  001f34:  6d cc                  blt.b $1f02
  001f36:  4a 45                  tst.w d5
  001f38:  67 14                  beq.b $1f4e
  001f3a:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  001f3e:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  001f42:  2f 3c 00 69 00 69      move.l #$690069, -(a7)
  001f48:  3f 3c 00 0d            move.w #$d, -(a7)
  001f4c:  aa 9a                  dc.w $aa9a
  001f4e:  4c df 10 e0            movem.l (a7)+, d5-d7/a4
  001f52:  4e 5e                  unlk a6
  001f54:  4e 75                  rts 
  001f56:  4e 56 00 00            link.w a6, #$0
  001f5a:  48 e7 38 20            movem.l d2-d4/a2, -(a7)
  001f5e:  24 6e 00 08            movea.l $8(a6), a2
  001f62:  28 2e 00 0c            move.l $c(a6), d4
  001f66:  22 6e 00 10            movea.l $10(a6), a1
  001f6a:  53 84                  subq.l #$1, d4
  001f6c:  6b 3e                  bmi.b $1fac
  001f6e:  14 1a                  move.b (a2)+, d2
  001f70:  76 07                  moveq #$7, d3
  001f72:  e2 0a                  lsr.b #$1, d2
  001f74:  65 0c                  bcs.b $1f82
  001f76:  53 84                  subq.l #$1, d4
  001f78:  6b 32                  bmi.b $1fac
  001f7a:  12 da                  move.b (a2)+, (a1)+
  001f7c:  51 cb ff f4            dbra d3, $1f72
  001f80:  60 e8                  bra.b $1f6a
  001f82:  55 84                  subq.l #$2, d4
  001f84:  6b 26                  bmi.b $1fac
  001f86:  10 1a                  move.b (a2)+, d0
  001f88:  e1 48                  lsl.w #$8, d0
  001f8a:  10 1a                  move.b (a2)+, d0
  001f8c:  32 00                  move.w d0, d1
  001f8e:  20 49                  movea.l a1, a0
  001f90:  02 40 0f ff            andi.w #$fff, d0
  001f94:  52 40                  addq.w #$1, d0
  001f96:  90 c0                  suba.w d0, a0
  001f98:  e9 59                  rol.w #$4, d1
  001f9a:  02 41 00 0f            andi.w #$f, d1
  001f9e:  54 41                  addq.w #$2, d1
  001fa0:  12 d8                  move.b (a0)+, (a1)+
  001fa2:  51 c9 ff fc            dbra d1, $1fa0
  001fa6:  51 cb ff ca            dbra d3, $1f72
  001faa:  60 be                  bra.b $1f6a
  001fac:  4c df 04 1c            movem.l (a7)+, d2-d4/a2
  001fb0:  4e 5e                  unlk a6
  001fb2:  4e 75                  rts 
  001fb4:  4e 56 ff f8            link.w a6, #$fff8
  001fb8:  2f 0c                  move.l a4, -(a7)
  001fba:  4a 2d 96 bd            tst.b -$6943(a5)
  001fbe:  66 64                  bne.b $2024
  001fc0:  4a 2d a2 08            tst.b -$5df8(a5)
  001fc4:  67 5e                  beq.b $2024
  001fc6:  42 78 0b aa            clr.w $baa.w
  001fca:  21 ed a0 ac 09 ee      move.l -$5f54(a5), $9ee.w
  001fd0:  48 6d a0 b6            pea.l -$5f4a(a5)
  001fd4:  a8 74                  dc.w $a874
  001fd6:  48 6e ff fc            pea.l -$4(a6)
  001fda:  a9 10                  dc.w $a910
  001fdc:  2f 2e ff fc            move.l -$4(a6), -(a7)
  001fe0:  a8 73                  dc.w $a873
  001fe2:  2f 38 09 ee            move.l $9ee.w, -(a7)
  001fe6:  a8 79                  dc.w $a879
  001fe8:  42 a7                  clr.l -(a7)
  001fea:  2f 2d a0 ac            move.l -$5f54(a5), -(a7)
  001fee:  a9 0c                  dc.w $a90c
  001ff0:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  001ff4:  a8 d3                  dc.w $a8d3
  001ff6:  42 a7                  clr.l -(a7)
  001ff8:  a9 24                  dc.w $a924
  001ffa:  28 5f                  movea.l (a7)+, a4
  001ffc:  2f 0c                  move.l a4, -(a7)
  001ffe:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  002002:  a9 0c                  dc.w $a90c
  002004:  2f 0c                  move.l a4, -(a7)
  002006:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  00200a:  a9 0d                  dc.w $a90d
  00200c:  2f 0c                  move.l a4, -(a7)
  00200e:  a9 09                  dc.w $a909
  002010:  2f 0c                  move.l a4, -(a7)
  002012:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  002016:  a9 0a                  dc.w $a90a
  002018:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  00201c:  a8 73                  dc.w $a873
  00201e:  1b 7c 00 01 96 bd      move.b #$1, -$6943(a5)
  002024:  4e ba 00 66            jsr $208c(pc)
  002028:  28 5f                  movea.l (a7)+, a4
  00202a:  4e 5e                  unlk a6
  00202c:  4e 75                  rts 
  00202e:  4e 56 ff fc            link.w a6, #$fffc
  002032:  2f 0c                  move.l a4, -(a7)
  002034:  4a 2d 96 bd            tst.b -$6943(a5)
  002038:  67 48                  beq.b $2082
  00203a:  31 ed a0 b0 0b aa      move.w -$5f50(a5), $baa.w
  002040:  21 ed a0 a4 09 ee      move.l -$5f5c(a5), $9ee.w
  002046:  48 6d a0 b6            pea.l -$5f4a(a5)
  00204a:  a8 74                  dc.w $a874
  00204c:  48 6e ff fc            pea.l -$4(a6)
  002050:  a9 10                  dc.w $a910
  002052:  2f 2e ff fc            move.l -$4(a6), -(a7)
  002056:  a8 73                  dc.w $a873
  002058:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  00205c:  a8 d3                  dc.w $a8d3
  00205e:  42 a7                  clr.l -(a7)
  002060:  a9 24                  dc.w $a924
  002062:  28 5f                  movea.l (a7)+, a4
  002064:  2f 0c                  move.l a4, -(a7)
  002066:  a9 09                  dc.w $a909
  002068:  2f 0c                  move.l a4, -(a7)
  00206a:  2f 2d a0 a8            move.l -$5f58(a5), -(a7)
  00206e:  a9 0a                  dc.w $a90a
  002070:  a9 37                  dc.w $a937
  002072:  2f 38 09 ee            move.l $9ee.w, -(a7)
  002076:  a8 79                  dc.w $a879
  002078:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  00207c:  a8 73                  dc.w $a873
  00207e:  42 2d 96 bd            clr.b -$6943(a5)
  002082:  4e ba 00 1e            jsr $20a2(pc)
  002086:  28 5f                  movea.l (a7)+, a4
  002088:  4e 5e                  unlk a6
  00208a:  4e 75                  rts 
  00208c:  4a 2d 96 bc            tst.b -$6944(a5)
  002090:  66 0e                  bne.b $20a0
  002092:  4a 2d a2 08            tst.b -$5df8(a5)
  002096:  67 08                  beq.b $20a0
  002098:  a8 52                  dc.w $a852
  00209a:  1b 7c 00 01 96 bc      move.b #$1, -$6944(a5)
  0020a0:  4e 75                  rts 
  0020a2:  4a 2d 96 bc            tst.b -$6944(a5)
  0020a6:  67 06                  beq.b $20ae
  0020a8:  a8 53                  dc.w $a853
  0020aa:  42 2d 96 bc            clr.b -$6944(a5)
  0020ae:  4e 75                  rts 
  0020b0:  4e ba 05 b0            jsr $2662(pc)
  0020b4:  4e ba ff ec            jsr $20a2(pc)
  0020b8:  4e 75                  rts 
  0020ba:  4e ba 05 d4            jsr $2690(pc)
  0020be:  4e ba ff cc            jsr $208c(pc)
  0020c2:  4e 75                  rts 
  0020c4:  4e 56 00 00            link.w a6, #$0
  0020c8:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  0020cc:  28 6e 00 0c            movea.l $c(a6), a4
  0020d0:  4e ba 05 58            jsr $262a(pc)
  0020d4:  30 14                  move.w (a4), d0
  0020d6:  6b 58                  bmi.b $2130
  0020d8:  57 40                  subq.w #$3, d0
  0020da:  67 02                  beq.b $20de
  0020dc:  60 52                  bra.b $2130
  0020de:  2e 2c 00 02            move.l $2(a4), d7
  0020e2:  2c 07                  move.l d7, d6
  0020e4:  02 86 00 00 ff 00      andi.l #$ff00, d6
  0020ea:  e0 86                  asr.l #$8, d6
  0020ec:  7c ff                  moveq #$ff, d6
  0020ee:  cc 07                  and.b d7, d6
  0020f0:  3e 2c 00 0e            move.w $e(a4), d7
  0020f4:  10 06                  move.b d6, d0
  0020f6:  6b 38                  bmi.b $2130
  0020f8:  04 00 00 0d            subi.b #$d, d0
  0020fc:  67 12                  beq.b $2110
  0020fe:  6a 08                  bpl.b $2108
  002100:  04 00 00 f6            subi.b #$f6, d0
  002104:  67 0a                  beq.b $2110
  002106:  60 28                  bra.b $2130
  002108:  04 00 00 0e            subi.b #$e, d0
  00210c:  67 12                  beq.b $2120
  00210e:  60 20                  bra.b $2130
  002110:  20 6e 00 08            movea.l $8(a6), a0
  002114:  30 bc 00 01            move.w #$1, (a0)
  002118:  1d 7c 00 01 00 14      move.b #$1, $14(a6)
  00211e:  60 14                  bra.b $2134
  002120:  20 6e 00 08            movea.l $8(a6), a0
  002124:  30 bc 00 02            move.w #$2, (a0)
  002128:  1d 7c 00 01 00 14      move.b #$1, $14(a6)
  00212e:  60 04                  bra.b $2134
  002130:  42 2e 00 14            clr.b $14(a6)
  002134:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  002138:  4e 5e                  unlk a6
  00213a:  20 5f                  movea.l (a7)+, a0
  00213c:  4f ef 00 0c            lea.l $c(a7), a7
  002140:  4e d0                  jmp (a0)
  002142:  4e 56 00 00            link.w a6, #$0
  002146:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  00214a:  28 78 03 28            movea.l $328.w, a4
  00214e:  20 0c                  move.l a4, d0
  002150:  67 0a                  beq.b $215c
  002152:  20 4c                  movea.l a4, a0
  002154:  a0 69                  dc.w $a069
  002156:  1e 00                  move.b d0, d7
  002158:  20 4c                  movea.l a4, a0
  00215a:  a0 29                  dc.w $a029
  00215c:  7c 00                  moveq #$0, d6
  00215e:  4a 2d 96 be            tst.b -$6942(a5)
  002162:  66 4a                  bne.b $21ae
  002164:  4a 2d 96 fb            tst.b -$6905(a5)
  002168:  67 06                  beq.b $2170
  00216a:  4a 2d 96 f9            tst.b -$6907(a5)
  00216e:  66 26                  bne.b $2196
  002170:  1b 7c 00 01 96 fb      move.b #$1, -$6905(a5)
  002176:  1b 7c 00 01 96 f9      move.b #$1, -$6907(a5)
  00217c:  4e ba 02 e8            jsr $2466(pc)
  002180:  4e ba ff 20            jsr $20a2(pc)
  002184:  a8 50                  dc.w $a850   ; _InitCursor
  002186:  42 67                  clr.w -(a7)
  002188:  3f 3c 03 f0            move.w #$3f0, -(a7)
  00218c:  42 a7                  clr.l -(a7)
  00218e:  a9 85                  dc.w $a985
  002190:  7c 01                  moveq #$1, d6
  002192:  54 8f                  addq.l #$2, a7
  002194:  60 18                  bra.b $21ae
  002196:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  00219c:  4e ba ff 04            jsr $20a2(pc)
  0021a0:  a8 50                  dc.w $a850   ; _InitCursor
  0021a2:  42 67                  clr.w -(a7)
  0021a4:  3f 3c 03 ea            move.w #$3ea, -(a7)
  0021a8:  42 a7                  clr.l -(a7)
  0021aa:  a9 85                  dc.w $a985
  0021ac:  54 8f                  addq.l #$2, a7
  0021ae:  20 0c                  move.l a4, d0
  0021b0:  67 06                  beq.b $21b8
  0021b2:  10 07                  move.b d7, d0
  0021b4:  20 4c                  movea.l a4, a0
  0021b6:  a0 6a                  dc.w $a06a
  0021b8:  2d 46 00 0c            move.l d6, $c(a6)
  0021bc:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  0021c0:  4e 5e                  unlk a6
  0021c2:  2e 9f                  move.l (a7)+, (a7)
  0021c4:  4e 75                  rts 
  0021c6:  4e 56 ff fe            link.w a6, #$fffe
  0021ca:  4a 2d 96 be            tst.b -$6942(a5)
  0021ce:  66 62                  bne.b $2232
  0021d0:  4a 6e 00 08            tst.w $8(a6)
  0021d4:  6c 1a                  bge.b $21f0
  0021d6:  0c 6e ff ff 00 08      cmpi.w #$ffff, $8(a6)
  0021dc:  66 0a                  bne.b $21e8
  0021de:  42 67                  clr.w -(a7)
  0021e0:  a9 af                  dc.w $a9af
  0021e2:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  0021e6:  60 0c                  bra.b $21f4
  0021e8:  3b 6e 00 08 a1 6c      move.w $8(a6), -$5e94(a5)
  0021ee:  60 04                  bra.b $21f4
  0021f0:  42 6d a1 6c            clr.w -$5e94(a5)
  0021f4:  4a 6d a1 6c            tst.w -$5e94(a5)
  0021f8:  67 38                  beq.b $2232
  0021fa:  4e ba 03 40            jsr $253c(pc)
  0021fe:  4e ba fe a2            jsr $20a2(pc)
  002202:  a8 50                  dc.w $a850   ; _InitCursor
  002204:  30 6d a1 6c            movea.w -$5e94(a5), a0
  002208:  2f 08                  move.l a0, -(a7)
  00220a:  48 6d a1 6e            pea.l -$5e92(a5)
  00220e:  4e ba 1b ca            jsr $3dda(pc)
  002212:  48 6d a1 6e            pea.l -$5e92(a5)
  002216:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  00221a:  42 a7                  clr.l -(a7)
  00221c:  42 a7                  clr.l -(a7)
  00221e:  a9 8b                  dc.w $a98b
  002220:  42 67                  clr.w -(a7)
  002222:  3f 3c 03 ee            move.w #$3ee, -(a7)
  002226:  42 a7                  clr.l -(a7)
  002228:  a9 85                  dc.w $a985
  00222a:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  002230:  54 8f                  addq.l #$2, a7
  002232:  10 2d 96 be            move.b -$6942(a5), d0
  002236:  4e 5e                  unlk a6
  002238:  4e 75                  rts 
  00223a:  4e 56 00 00            link.w a6, #$0
  00223e:  4a 2d 96 be            tst.b -$6942(a5)
  002242:  66 30                  bne.b $2274
  002244:  42 67                  clr.w -(a7)
  002246:  a9 af                  dc.w $a9af
  002248:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  00224c:  4a ae 00 08            tst.l $8(a6)
  002250:  67 06                  beq.b $2258
  002252:  4a 6d a1 6c            tst.w -$5e94(a5)
  002256:  67 1c                  beq.b $2274
  002258:  4e ba 02 e2            jsr $253c(pc)
  00225c:  4e ba fe 44            jsr $20a2(pc)
  002260:  a8 50                  dc.w $a850   ; _InitCursor
  002262:  42 67                  clr.w -(a7)
  002264:  3f 3c 03 e9            move.w #$3e9, -(a7)
  002268:  42 a7                  clr.l -(a7)
  00226a:  a9 85                  dc.w $a985
  00226c:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  002272:  54 8f                  addq.l #$2, a7
  002274:  10 2d 96 be            move.b -$6942(a5), d0
  002278:  4e 5e                  unlk a6
  00227a:  4e 75                  rts 
  00227c:  4e 56 00 00            link.w a6, #$0
  002280:  4a 2d 96 be            tst.b -$6942(a5)
  002284:  66 2e                  bne.b $22b4
  002286:  3b 78 02 20 a1 6c      move.w $220.w, -$5e94(a5)
  00228c:  4a ae 00 08            tst.l $8(a6)
  002290:  67 06                  beq.b $2298
  002292:  4a 6d a1 6c            tst.w -$5e94(a5)
  002296:  67 1c                  beq.b $22b4
  002298:  4e ba 02 a2            jsr $253c(pc)
  00229c:  4e ba fe 04            jsr $20a2(pc)
  0022a0:  a8 50                  dc.w $a850   ; _InitCursor
  0022a2:  42 67                  clr.w -(a7)
  0022a4:  3f 3c 03 ea            move.w #$3ea, -(a7)
  0022a8:  42 a7                  clr.l -(a7)
  0022aa:  a9 85                  dc.w $a985
  0022ac:  1b 7c 00 01 96 be      move.b #$1, -$6942(a5)
  0022b2:  54 8f                  addq.l #$2, a7
  0022b4:  10 2d 96 be            move.b -$6942(a5), d0
  0022b8:  4e 5e                  unlk a6
  0022ba:  4e 75                  rts 
  0022bc:  4e 56 00 00            link.w a6, #$0
  0022c0:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  0022c4:  3a 2e 00 08            move.w $8(a6), d5
  0022c8:  7e 00                  moveq #$0, d7
  0022ca:  7c 00                  moveq #$0, d6
  0022cc:  3f 05                  move.w d5, -(a7)
  0022ce:  4e ba 02 e0            jsr $25b0(pc)
  0022d2:  4a 00                  tst.b d0
  0022d4:  54 8f                  addq.l #$2, a7
  0022d6:  67 62                  beq.b $233a
  0022d8:  38 05                  move.w d5, d4
  0022da:  06 44 03 e8            addi.w #$3e8, d4
  0022de:  36 05                  move.w d5, d3
  0022e0:  06 43 07 d0            addi.w #$7d0, d3
  0022e4:  49 ed a4 64            lea.l -$5b9c(a5), a4
  0022e8:  d8 c6                  adda.w d6, a4
  0022ea:  d8 c6                  adda.w d6, a4
  0022ec:  60 0c                  bra.b $22fa
  0022ee:  b8 54                  cmp.w (a4), d4
  0022f0:  66 04                  bne.b $22f6
  0022f2:  7e 01                  moveq #$1, d7
  0022f4:  60 0a                  bra.b $2300
  0022f6:  52 46                  addq.w #$1, d6
  0022f8:  54 8c                  addq.l #$2, a4
  0022fa:  bc 6d 96 e6            cmp.w -$691a(a5), d6
  0022fe:  6d ee                  blt.b $22ee
  002300:  4a 07                  tst.b d7
  002302:  66 1a                  bne.b $231e
  002304:  38 6d 96 e6            movea.w -$691a(a5), a4
  002308:  d9 cc                  adda.l a4, a4
  00230a:  41 ed a4 64            lea.l -$5b9c(a5), a0
  00230e:  d1 cc                  adda.l a4, a0
  002310:  30 84                  move.w d4, (a0)
  002312:  41 ed a4 da            lea.l -$5b26(a5), a0
  002316:  d1 cc                  adda.l a4, a0
  002318:  30 83                  move.w d3, (a0)
  00231a:  52 6d 96 e6            addq.w #$1, -$691a(a5)
  00231e:  38 6d 96 e6            movea.w -$691a(a5), a4
  002322:  d9 cc                  adda.l a4, a4
  002324:  41 ed a4 64            lea.l -$5b9c(a5), a0
  002328:  d1 cc                  adda.l a4, a0
  00232a:  30 bc ff ff            move.w #$ffff, (a0)
  00232e:  41 ed a4 da            lea.l -$5b26(a5), a0
  002332:  d1 cc                  adda.l a4, a0
  002334:  30 bc ff ff            move.w #$ffff, (a0)
  002338:  60 48                  bra.b $2382
  00233a:  38 05                  move.w d5, d4
  00233c:  06 44 13 88            addi.w #$1388, d4
  002340:  49 ed a3 ee            lea.l -$5c12(a5), a4
  002344:  d8 c6                  adda.w d6, a4
  002346:  d8 c6                  adda.w d6, a4
  002348:  60 0c                  bra.b $2356
  00234a:  b8 54                  cmp.w (a4), d4
  00234c:  66 04                  bne.b $2352
  00234e:  7e 01                  moveq #$1, d7
  002350:  60 0a                  bra.b $235c
  002352:  52 46                  addq.w #$1, d6
  002354:  54 8c                  addq.l #$2, a4
  002356:  bc 6d 96 e0            cmp.w -$6920(a5), d6
  00235a:  6d ee                  blt.b $234a
  00235c:  4a 07                  tst.b d7
  00235e:  66 12                  bne.b $2372
  002360:  30 2d 96 e0            move.w -$6920(a5), d0
  002364:  20 4d                  movea.l a5, a0
  002366:  d0 c0                  adda.w d0, a0
  002368:  d0 c0                  adda.w d0, a0
  00236a:  31 44 a3 ee            move.w d4, -$5c12(a0)
  00236e:  52 6d 96 e0            addq.w #$1, -$6920(a5)
  002372:  30 2d 96 e0            move.w -$6920(a5), d0
  002376:  20 4d                  movea.l a5, a0
  002378:  d0 c0                  adda.w d0, a0
  00237a:  d0 c0                  adda.w d0, a0
  00237c:  31 7c ff ff a3 ee      move.w #$ffff, -$5c12(a0)
  002382:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  002386:  4e 5e                  unlk a6
  002388:  4e 75                  rts 
  00238a:  4e 56 00 00            link.w a6, #$0
  00238e:  48 e7 1f 38            movem.l d3-d7/a2-a4, -(a7)
  002392:  3a 2e 00 08            move.w $8(a6), d5
  002396:  7e 00                  moveq #$0, d7
  002398:  7c 00                  moveq #$0, d6
  00239a:  3f 05                  move.w d5, -(a7)
  00239c:  4e ba 02 12            jsr $25b0(pc)
  0023a0:  4a 00                  tst.b d0
  0023a2:  54 8f                  addq.l #$2, a7
  0023a4:  67 54                  beq.b $23fa
  0023a6:  38 05                  move.w d5, d4
  0023a8:  06 44 03 e8            addi.w #$3e8, d4
  0023ac:  36 05                  move.w d5, d3
  0023ae:  06 43 07 d0            addi.w #$7d0, d3
  0023b2:  38 46                  movea.w d6, a4
  0023b4:  d9 cc                  adda.l a4, a4
  0023b6:  47 ed a4 da            lea.l -$5b26(a5), a3
  0023ba:  d7 cc                  adda.l a4, a3
  0023bc:  45 ed a4 64            lea.l -$5b9c(a5), a2
  0023c0:  d5 cc                  adda.l a4, a2
  0023c2:  60 26                  bra.b $23ea
  0023c4:  b8 52                  cmp.w (a2), d4
  0023c6:  66 02                  bne.b $23ca
  0023c8:  7e 01                  moveq #$1, d7
  0023ca:  4a 07                  tst.b d7
  0023cc:  67 16                  beq.b $23e4
  0023ce:  38 46                  movea.w d6, a4
  0023d0:  49 f4 60 02            lea.l $2(a4, d6.w), a4
  0023d4:  41 ed a4 64            lea.l -$5b9c(a5), a0
  0023d8:  d1 cc                  adda.l a4, a0
  0023da:  34 90                  move.w (a0), (a2)
  0023dc:  41 ed a4 da            lea.l -$5b26(a5), a0
  0023e0:  d1 cc                  adda.l a4, a0
  0023e2:  36 90                  move.w (a0), (a3)
  0023e4:  52 46                  addq.w #$1, d6
  0023e6:  54 8b                  addq.l #$2, a3
  0023e8:  54 8a                  addq.l #$2, a2
  0023ea:  bc 6d 96 e6            cmp.w -$691a(a5), d6
  0023ee:  6d d4                  blt.b $23c4
  0023f0:  4a 07                  tst.b d7
  0023f2:  67 3c                  beq.b $2430
  0023f4:  53 6d 96 e6            subq.w #$1, -$691a(a5)
  0023f8:  60 36                  bra.b $2430
  0023fa:  38 05                  move.w d5, d4
  0023fc:  06 44 13 88            addi.w #$1388, d4
  002400:  49 ed a3 ee            lea.l -$5c12(a5), a4
  002404:  d8 c6                  adda.w d6, a4
  002406:  d8 c6                  adda.w d6, a4
  002408:  60 18                  bra.b $2422
  00240a:  b8 54                  cmp.w (a4), d4
  00240c:  66 02                  bne.b $2410
  00240e:  7e 01                  moveq #$1, d7
  002410:  4a 07                  tst.b d7
  002412:  67 0a                  beq.b $241e
  002414:  20 4d                  movea.l a5, a0
  002416:  d0 c6                  adda.w d6, a0
  002418:  d0 c6                  adda.w d6, a0
  00241a:  38 a8 a3 f0            move.w -$5c10(a0), (a4)
  00241e:  52 46                  addq.w #$1, d6
  002420:  54 8c                  addq.l #$2, a4
  002422:  bc 6d 96 e0            cmp.w -$6920(a5), d6
  002426:  6d e2                  blt.b $240a
  002428:  4a 07                  tst.b d7
  00242a:  67 04                  beq.b $2430
  00242c:  53 6d 96 e0            subq.w #$1, -$6920(a5)
  002430:  4c df 1c f8            movem.l (a7)+, d3-d7/a2-a4
  002434:  4e 5e                  unlk a6
  002436:  4e 75                  rts 
  002438:  4a 2d 96 dc            tst.b -$6924(a5)
  00243c:  66 20                  bne.b $245e
  00243e:  4a 2d 96 fb            tst.b -$6905(a5)
  002442:  66 0a                  bne.b $244e
  002444:  4a 2d 96 fc            tst.b -$6904(a5)
  002448:  67 04                  beq.b $244e
  00244a:  4e ba 03 68            jsr $27b4(pc)
  00244e:  4a 2d 96 f9            tst.b -$6907(a5)
  002452:  66 0a                  bne.b $245e
  002454:  4a 2d 96 fa            tst.b -$6906(a5)
  002458:  67 04                  beq.b $245e
  00245a:  4e ba 02 5e            jsr $26ba(pc)
  00245e:  1b 7c 00 01 96 dc      move.b #$1, -$6924(a5)
  002464:  4e 75                  rts 
  002466:  4a 2d 96 dc            tst.b -$6924(a5)
  00246a:  67 08                  beq.b $2474
  00246c:  4e ba 02 aa            jsr $2718(pc)
  002470:  4e ba 04 08            jsr $287a(pc)
  002474:  42 2d 96 dc            clr.b -$6924(a5)
  002478:  4e 75                  rts 
  00247a:  4e 56 00 00            link.w a6, #$0
  00247e:  2f 07                  move.l d7, -(a7)
  002480:  3e 2e 00 08            move.w $8(a6), d7
  002484:  3f 07                  move.w d7, -(a7)
  002486:  4e ba 01 28            jsr $25b0(pc)
  00248a:  4a 00                  tst.b d0
  00248c:  54 8f                  addq.l #$2, a7
  00248e:  67 48                  beq.b $24d8
  002490:  4a 2d 96 fc            tst.b -$6904(a5)
  002494:  67 00 00 a0            beq.w $2536
  002498:  4a 2d 96 e2            tst.b -$691e(a5)
  00249c:  67 00 00 98            beq.w $2536
  0024a0:  4a 2d 96 dd            tst.b -$6923(a5)
  0024a4:  67 0a                  beq.b $24b0
  0024a6:  4a 2d 96 de            tst.b -$6922(a5)
  0024aa:  67 04                  beq.b $24b0
  0024ac:  4e ba 02 cc            jsr $277a(pc)
  0024b0:  4a 2d 96 e3            tst.b -$691d(a5)
  0024b4:  66 04                  bne.b $24ba
  0024b6:  4e ba 04 84            jsr $293c(pc)
  0024ba:  4a 2d 96 e5            tst.b -$691b(a5)
  0024be:  67 06                  beq.b $24c6
  0024c0:  06 47 07 d0            addi.w #$7d0, d7
  0024c4:  60 04                  bra.b $24ca
  0024c6:  06 47 03 e8            addi.w #$3e8, d7
  0024ca:  3f 07                  move.w d7, -(a7)
  0024cc:  3f 3c 00 02            move.w #$2, -(a7)
  0024d0:  4e ba 1b 06            jsr $3fd8(pc)
  0024d4:  58 8f                  addq.l #$4, a7
  0024d6:  60 5e                  bra.b $2536
  0024d8:  4a 2d 96 fa            tst.b -$6906(a5)
  0024dc:  67 58                  beq.b $2536
  0024de:  4a 2d 96 dd            tst.b -$6923(a5)
  0024e2:  67 52                  beq.b $2536
  0024e4:  4a 2d 96 e2            tst.b -$691e(a5)
  0024e8:  67 1a                  beq.b $2504
  0024ea:  4a 2d 96 e3            tst.b -$691d(a5)
  0024ee:  67 14                  beq.b $2504
  0024f0:  2f 3c 00 07 00 00      move.l #$70000, -(a7)
  0024f6:  4e ba 1a e0            jsr $3fd8(pc)
  0024fa:  4a 80                  tst.l d0
  0024fc:  58 8f                  addq.l #$4, a7
  0024fe:  67 36                  beq.b $2536
  002500:  4e ba 04 18            jsr $291a(pc)
  002504:  4a 2d 96 de            tst.b -$6922(a5)
  002508:  66 04                  bne.b $250e
  00250a:  4e ba 02 8c            jsr $2798(pc)
  00250e:  06 47 13 88            addi.w #$1388, d7
  002512:  4a 6d 96 f6            tst.w -$690a(a5)
  002516:  67 14                  beq.b $252c
  002518:  3f 2d 96 f6            move.w -$690a(a5), -(a7)
  00251c:  42 67                  clr.w -(a7)
  00251e:  3f 07                  move.w d7, -(a7)
  002520:  4e ba 2e ce            jsr $53f0(pc)
  002524:  42 6d 96 f6            clr.w -$690a(a5)
  002528:  5c 8f                  addq.l #$6, a7
  00252a:  60 0a                  bra.b $2536
  00252c:  42 67                  clr.w -(a7)
  00252e:  3f 07                  move.w d7, -(a7)
  002530:  4e ba 2c 8a            jsr $51bc(pc)
  002534:  58 8f                  addq.l #$4, a7
  002536:  2e 1f                  move.l (a7)+, d7
  002538:  4e 5e                  unlk a6
  00253a:  4e 75                  rts 
  00253c:  4a 2d 96 dd            tst.b -$6923(a5)
  002540:  67 0a                  beq.b $254c
  002542:  4a 2d 96 de            tst.b -$6922(a5)
  002546:  67 04                  beq.b $254c
  002548:  4e ba 30 38            jsr $5582(pc)
  00254c:  4a 2d 96 e2            tst.b -$691e(a5)
  002550:  67 12                  beq.b $2564
  002552:  4a 2d 96 e3            tst.b -$691d(a5)
  002556:  67 0c                  beq.b $2564
  002558:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  00255e:  4e ba 1a 78            jsr $3fd8(pc)
  002562:  58 8f                  addq.l #$4, a7
  002564:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  00256a:  4e 75                  rts 
  00256c:  4a 2d 96 dd            tst.b -$6923(a5)
  002570:  67 16                  beq.b $2588
  002572:  4a 2d 96 de            tst.b -$6922(a5)
  002576:  67 10                  beq.b $2588
  002578:  4e ba 30 70            jsr $55ea(pc)
  00257c:  4a 00                  tst.b d0
  00257e:  67 04                  beq.b $2584
  002580:  70 00                  moveq #$0, d0
  002582:  60 2a                  bra.b $25ae
  002584:  70 01                  moveq #$1, d0
  002586:  60 26                  bra.b $25ae
  002588:  4a 2d 96 e2            tst.b -$691e(a5)
  00258c:  67 1e                  beq.b $25ac
  00258e:  4a 2d 96 e3            tst.b -$691d(a5)
  002592:  67 18                  beq.b $25ac
  002594:  2f 3c 00 07 00 00      move.l #$70000, -(a7)
  00259a:  4e ba 1a 3c            jsr $3fd8(pc)
  00259e:  4a 80                  tst.l d0
  0025a0:  58 8f                  addq.l #$4, a7
  0025a2:  67 04                  beq.b $25a8
  0025a4:  70 00                  moveq #$0, d0
  0025a6:  60 06                  bra.b $25ae
  0025a8:  70 01                  moveq #$1, d0
  0025aa:  60 02                  bra.b $25ae
  0025ac:  70 00                  moveq #$0, d0
  0025ae:  4e 75                  rts 
  0025b0:  4e 56 00 00            link.w a6, #$0
  0025b4:  2f 07                  move.l d7, -(a7)
  0025b6:  3e 2e 00 08            move.w $8(a6), d7
  0025ba:  0c 47 00 18            cmpi.w #$18, d7
  0025be:  6d 0c                  blt.b $25cc
  0025c0:  0c 47 00 26            cmpi.w #$26, d7
  0025c4:  67 06                  beq.b $25cc
  0025c6:  0c 47 00 2c            cmpi.w #$2c, d7
  0025ca:  6d 12                  blt.b $25de
  0025cc:  0c 47 00 32            cmpi.w #$32, d7
  0025d0:  6d 10                  blt.b $25e2
  0025d2:  0c 47 00 33            cmpi.w #$33, d7
  0025d6:  67 0a                  beq.b $25e2
  0025d8:  0c 47 00 3a            cmpi.w #$3a, d7
  0025dc:  6c 04                  bge.b $25e2
  0025de:  70 01                  moveq #$1, d0
  0025e0:  60 02                  bra.b $25e4
  0025e2:  70 00                  moveq #$0, d0
  0025e4:  2e 1f                  move.l (a7)+, d7
  0025e6:  4e 5e                  unlk a6
  0025e8:  4e 75                  rts 
  0025ea:  4e 56 00 00            link.w a6, #$0
  0025ee:  48 e7 03 00            movem.l d6-d7, -(a7)
  0025f2:  2c 2e 00 08            move.l $8(a6), d6
  0025f6:  4a 2d 96 e2            tst.b -$691e(a5)
  0025fa:  67 24                  beq.b $2620
  0025fc:  4a 2d 96 e3            tst.b -$691d(a5)
  002600:  67 1e                  beq.b $2620
  002602:  2f 3c 00 08 00 00      move.l #$80000, -(a7)
  002608:  4e ba 19 ce            jsr $3fd8(pc)
  00260c:  2e 00                  move.l d0, d7
  00260e:  4a 87                  tst.l d7
  002610:  58 8f                  addq.l #$4, a7
  002612:  6f 08                  ble.b $261c
  002614:  bc 87                  cmp.l d7, d6
  002616:  6f 04                  ble.b $261c
  002618:  70 00                  moveq #$0, d0
  00261a:  60 06                  bra.b $2622
  00261c:  70 01                  moveq #$1, d0
  00261e:  60 02                  bra.b $2622
  002620:  70 01                  moveq #$1, d0
  002622:  4c df 00 c0            movem.l (a7)+, d6-d7
  002626:  4e 5e                  unlk a6
  002628:  4e 75                  rts 
  00262a:  4a 2d 96 e2            tst.b -$691e(a5)
  00262e:  67 30                  beq.b $2660
  002630:  4a 2d 96 e3            tst.b -$691d(a5)
  002634:  67 2a                  beq.b $2660
  002636:  2f 3c 00 09 00 00      move.l #$90000, -(a7)
  00263c:  4e ba 19 9a            jsr $3fd8(pc)
  002640:  2e bc 00 07 00 00      move.l #$70000, (a7)
  002646:  4e ba 19 90            jsr $3fd8(pc)
  00264a:  4a 80                  tst.l d0
  00264c:  58 8f                  addq.l #$4, a7
  00264e:  67 0a                  beq.b $265a
  002650:  4e ba 02 c8            jsr $291a(pc)
  002654:  4e ba 01 42            jsr $2798(pc)
  002658:  60 06                  bra.b $2660
  00265a:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  002660:  4e 75                  rts 
  002662:  4a 2d 96 dd            tst.b -$6923(a5)
  002666:  67 10                  beq.b $2678
  002668:  4a 2d 96 de            tst.b -$6922(a5)
  00266c:  67 0a                  beq.b $2678
  00266e:  4e ba 01 0a            jsr $277a(pc)
  002672:  1b 7c 00 01 96 df      move.b #$1, -$6921(a5)
  002678:  4a 2d 96 e2            tst.b -$691e(a5)
  00267c:  67 10                  beq.b $268e
  00267e:  4a 2d 96 e3            tst.b -$691d(a5)
  002682:  67 0a                  beq.b $268e
  002684:  4e ba 02 94            jsr $291a(pc)
  002688:  1b 7c 00 01 96 e4      move.b #$1, -$691c(a5)
  00268e:  4e 75                  rts 
  002690:  4a 2d 96 dd            tst.b -$6923(a5)
  002694:  67 0e                  beq.b $26a4
  002696:  4a 2d 96 df            tst.b -$6921(a5)
  00269a:  67 08                  beq.b $26a4
  00269c:  4e ba 00 fa            jsr $2798(pc)
  0026a0:  42 2d 96 df            clr.b -$6921(a5)
  0026a4:  4a 2d 96 e2            tst.b -$691e(a5)
  0026a8:  67 0e                  beq.b $26b8
  0026aa:  4a 2d 96 e4            tst.b -$691c(a5)
  0026ae:  67 08                  beq.b $26b8
  0026b0:  4e ba 02 8a            jsr $293c(pc)
  0026b4:  42 2d 96 e4            clr.b -$691c(a5)
  0026b8:  4e 75                  rts 
  0026ba:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  0026be:  4a 2d 96 dd            tst.b -$6923(a5)
  0026c2:  66 4e                  bne.b $2712
  0026c4:  4e ba 02 54            jsr $291a(pc)
  0026c8:  7e 00                  moveq #$0, d7
  0026ca:  47 ed a3 ee            lea.l -$5c12(a5), a3
  0026ce:  60 20                  bra.b $26f0
  0026d0:  3c 13                  move.w (a3), d6
  0026d2:  42 a7                  clr.l -(a7)
  0026d4:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  0026da:  3f 06                  move.w d6, -(a7)
  0026dc:  a9 a0                  dc.w $a9a0
  0026de:  28 5f                  movea.l (a7)+, a4
  0026e0:  20 0c                  move.l a4, d0
  0026e2:  67 08                  beq.b $26ec
  0026e4:  20 4c                  movea.l a4, a0
  0026e6:  a0 64                  dc.w $a064
  0026e8:  20 4c                  movea.l a4, a0
  0026ea:  a0 29                  dc.w $a029
  0026ec:  52 47                  addq.w #$1, d7
  0026ee:  54 8b                  addq.l #$2, a3
  0026f0:  be 6d 96 e0            cmp.w -$6920(a5), d7
  0026f4:  6d da                  blt.b $26d0
  0026f6:  42 27                  clr.b -(a7)
  0026f8:  48 6d a3 ee            pea.l -$5c12(a5)
  0026fc:  4e ba 27 2a            jsr $4e28(pc)
  002700:  1b 7c 00 01 96 dd      move.b #$1, -$6923(a5)
  002706:  1b 7c 00 01 96 de      move.b #$1, -$6922(a5)
  00270c:  a0 1c                  dc.w $a01c
  00270e:  a0 4c                  dc.w $a04c
  002710:  5c 8f                  addq.l #$6, a7
  002712:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  002716:  4e 75                  rts 
  002718:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  00271c:  4a 2d 96 dd            tst.b -$6923(a5)
  002720:  67 52                  beq.b $2774
  002722:  4e ba 01 f6            jsr $291a(pc)
  002726:  4e ba 00 70            jsr $2798(pc)
  00272a:  4e ba 2e be            jsr $55ea(pc)
  00272e:  4a 00                  tst.b d0
  002730:  67 f8                  beq.b $272a
  002732:  4e ba 27 d4            jsr $4f08(pc)
  002736:  42 2d 96 dd            clr.b -$6923(a5)
  00273a:  42 2d 96 de            clr.b -$6922(a5)
  00273e:  7e 00                  moveq #$0, d7
  002740:  47 ed a3 ee            lea.l -$5c12(a5), a3
  002744:  60 20                  bra.b $2766
  002746:  3c 13                  move.w (a3), d6
  002748:  42 a7                  clr.l -(a7)
  00274a:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  002750:  3f 06                  move.w d6, -(a7)
  002752:  a9 a0                  dc.w $a9a0
  002754:  28 5f                  movea.l (a7)+, a4
  002756:  20 0c                  move.l a4, d0
  002758:  67 08                  beq.b $2762
  00275a:  20 4c                  movea.l a4, a0
  00275c:  a0 2a                  dc.w $a02a
  00275e:  20 4c                  movea.l a4, a0
  002760:  a0 49                  dc.w $a049
  002762:  52 47                  addq.w #$1, d7
  002764:  54 8b                  addq.l #$2, a3
  002766:  be 6d 96 e0            cmp.w -$6920(a5), d7
  00276a:  6d da                  blt.b $2746
  00276c:  a0 1c                  dc.w $a01c
  00276e:  a0 4c                  dc.w $a04c
  002770:  4e ba 01 ca            jsr $293c(pc)
  002774:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  002778:  4e 75                  rts 
  00277a:  4a 2d 96 dd            tst.b -$6923(a5)
  00277e:  67 16                  beq.b $2796
  002780:  4a 2d 96 de            tst.b -$6922(a5)
  002784:  67 10                  beq.b $2796
  002786:  4e ba 2d fa            jsr $5582(pc)
  00278a:  4e ba 27 a0            jsr $4f2c(pc)
  00278e:  42 2d 96 de            clr.b -$6922(a5)
  002792:  a0 1c                  dc.w $a01c
  002794:  a0 4c                  dc.w $a04c
  002796:  4e 75                  rts 
  002798:  4a 2d 96 dd            tst.b -$6923(a5)
  00279c:  67 14                  beq.b $27b2
  00279e:  4a 2d 96 de            tst.b -$6922(a5)
  0027a2:  66 0e                  bne.b $27b2
  0027a4:  4e ba 27 ae            jsr $4f54(pc)
  0027a8:  1b 7c 00 01 96 de      move.b #$1, -$6922(a5)
  0027ae:  a0 1c                  dc.w $a01c
  0027b0:  a0 4c                  dc.w $a04c
  0027b2:  4e 75                  rts 
  0027b4:  48 e7 03 38            movem.l d6-d7/a2-a4, -(a7)
  0027b8:  4a 2d 96 e2            tst.b -$691e(a5)
  0027bc:  66 00 00 b6            bne.w $2874
  0027c0:  4e ba ff b8            jsr $277a(pc)
  0027c4:  4a 2d 96 e5            tst.b -$691b(a5)
  0027c8:  67 0a                  beq.b $27d4
  0027ca:  4a 2d 96 b8            tst.b -$6948(a5)
  0027ce:  67 04                  beq.b $27d4
  0027d0:  7e 00                  moveq #$0, d7
  0027d2:  60 06                  bra.b $27da
  0027d4:  7e 01                  moveq #$1, d7
  0027d6:  42 2d 96 e5            clr.b -$691b(a5)
  0027da:  3f 07                  move.w d7, -(a7)
  0027dc:  42 67                  clr.w -(a7)
  0027de:  4e ba 17 f8            jsr $3fd8(pc)
  0027e2:  4a 80                  tst.l d0
  0027e4:  58 8f                  addq.l #$4, a7
  0027e6:  66 00 00 8c            bne.w $2874
  0027ea:  2f 3c 00 0d 00 01      move.l #$d0001, -(a7)
  0027f0:  4e ba 17 e6            jsr $3fd8(pc)
  0027f4:  2e bc 00 0c 00 01      move.l #$c0001, (a7)
  0027fa:  4e ba 17 dc            jsr $3fd8(pc)
  0027fe:  1b 7c 00 01 96 e2      move.b #$1, -$691e(a5)
  002804:  1b 7c 00 01 96 e3      move.b #$1, -$691d(a5)
  00280a:  7e 00                  moveq #$0, d7
  00280c:  45 ed a4 64            lea.l -$5b9c(a5), a2
  002810:  47 ed a4 da            lea.l -$5b26(a5), a3
  002814:  58 8f                  addq.l #$4, a7
  002816:  60 4a                  bra.b $2862
  002818:  4a 2d 96 e5            tst.b -$691b(a5)
  00281c:  67 04                  beq.b $2822
  00281e:  3c 13                  move.w (a3), d6
  002820:  60 02                  bra.b $2824
  002822:  3c 12                  move.w (a2), d6
  002824:  42 a7                  clr.l -(a7)
  002826:  2f 3c 53 4f 4e 47      move.l #$534f4e47, -(a7)
  00282c:  3f 06                  move.w d6, -(a7)
  00282e:  a9 a0                  dc.w $a9a0
  002830:  28 5f                  movea.l (a7)+, a4
  002832:  20 0c                  move.l a4, d0
  002834:  67 26                  beq.b $285c
  002836:  20 4c                  movea.l a4, a0
  002838:  a0 64                  dc.w $a064
  00283a:  20 4c                  movea.l a4, a0
  00283c:  a0 29                  dc.w $a029
  00283e:  20 54                  movea.l (a4), a0
  002840:  3c 10                  move.w (a0), d6
  002842:  42 a7                  clr.l -(a7)
  002844:  2f 3c 4d 49 44 49      move.l #$4d494449, -(a7)
  00284a:  3f 06                  move.w d6, -(a7)
  00284c:  a9 a0                  dc.w $a9a0
  00284e:  28 5f                  movea.l (a7)+, a4
  002850:  20 0c                  move.l a4, d0
  002852:  67 08                  beq.b $285c
  002854:  20 4c                  movea.l a4, a0
  002856:  a0 64                  dc.w $a064
  002858:  20 4c                  movea.l a4, a0
  00285a:  a0 29                  dc.w $a029
  00285c:  52 47                  addq.w #$1, d7
  00285e:  54 8a                  addq.l #$2, a2
  002860:  54 8b                  addq.l #$2, a3
  002862:  be 6d 96 e6            cmp.w -$691a(a5), d7
  002866:  6d b0                  blt.b $2818
  002868:  a0 1c                  dc.w $a01c
  00286a:  a0 4c                  dc.w $a04c
  00286c:  4e ba 00 ac            jsr $291a(pc)
  002870:  4e ba ff 26            jsr $2798(pc)
  002874:  4c df 1c c0            movem.l (a7)+, d6-d7/a2-a4
  002878:  4e 75                  rts 
  00287a:  48 e7 07 38            movem.l d5-d7/a2-a4, -(a7)
  00287e:  4a 2d 96 e2            tst.b -$691e(a5)
  002882:  67 00 00 90            beq.w $2914
  002886:  4e ba fe f2            jsr $277a(pc)
  00288a:  4e ba 00 b0            jsr $293c(pc)
  00288e:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  002894:  4e ba 17 42            jsr $3fd8(pc)
  002898:  42 2d 96 e2            clr.b -$691e(a5)
  00289c:  42 2d 96 e3            clr.b -$691d(a5)
  0028a0:  42 17                  clr.b (a7)
  0028a2:  a9 9b                  dc.w $a99b
  0028a4:  7c 00                  moveq #$0, d6
  0028a6:  45 ed a4 64            lea.l -$5b9c(a5), a2
  0028aa:  47 ed a4 da            lea.l -$5b26(a5), a3
  0028ae:  54 8f                  addq.l #$2, a7
  0028b0:  60 4a                  bra.b $28fc
  0028b2:  4a 2d 96 e5            tst.b -$691b(a5)
  0028b6:  67 04                  beq.b $28bc
  0028b8:  3a 13                  move.w (a3), d5
  0028ba:  60 02                  bra.b $28be
  0028bc:  3a 12                  move.w (a2), d5
  0028be:  42 a7                  clr.l -(a7)
  0028c0:  2f 3c 53 4f 4e 47      move.l #$534f4e47, -(a7)
  0028c6:  3f 05                  move.w d5, -(a7)
  0028c8:  a9 a0                  dc.w $a9a0
  0028ca:  28 5f                  movea.l (a7)+, a4
  0028cc:  20 0c                  move.l a4, d0
  0028ce:  67 26                  beq.b $28f6
  0028d0:  20 4c                  movea.l a4, a0
  0028d2:  a0 2a                  dc.w $a02a
  0028d4:  20 4c                  movea.l a4, a0
  0028d6:  a0 49                  dc.w $a049
  0028d8:  20 54                  movea.l (a4), a0
  0028da:  3a 10                  move.w (a0), d5
  0028dc:  42 a7                  clr.l -(a7)
  0028de:  2f 3c 4d 49 44 49      move.l #$4d494449, -(a7)
  0028e4:  3f 05                  move.w d5, -(a7)
  0028e6:  a9 a0                  dc.w $a9a0
  0028e8:  28 5f                  movea.l (a7)+, a4
  0028ea:  20 0c                  move.l a4, d0
  0028ec:  67 08                  beq.b $28f6
  0028ee:  20 4c                  movea.l a4, a0
  0028f0:  a0 2a                  dc.w $a02a
  0028f2:  20 4c                  movea.l a4, a0
  0028f4:  a0 49                  dc.w $a049
  0028f6:  52 46                  addq.w #$1, d6
  0028f8:  54 8a                  addq.l #$2, a2
  0028fa:  54 8b                  addq.l #$2, a3
  0028fc:  bc 6d 96 e6            cmp.w -$691a(a5), d6
  002900:  6d b0                  blt.b $28b2
  002902:  1f 3c 00 01            move.b #$1, -(a7)
  002906:  a9 9b                  dc.w $a99b
  002908:  42 2d 96 e5            clr.b -$691b(a5)
  00290c:  a0 1c                  dc.w $a01c
  00290e:  a0 4c                  dc.w $a04c
  002910:  4e ba fe 86            jsr $2798(pc)
  002914:  4c df 1c e0            movem.l (a7)+, d5-d7/a2-a4
  002918:  4e 75                  rts 
  00291a:  4a 2d 96 e2            tst.b -$691e(a5)
  00291e:  67 1a                  beq.b $293a
  002920:  4a 2d 96 e3            tst.b -$691d(a5)
  002924:  67 14                  beq.b $293a
  002926:  2f 3c 00 05 00 00      move.l #$50000, -(a7)
  00292c:  4e ba 16 aa            jsr $3fd8(pc)
  002930:  42 2d 96 e3            clr.b -$691d(a5)
  002934:  a0 1c                  dc.w $a01c
  002936:  a0 4c                  dc.w $a04c
  002938:  58 8f                  addq.l #$4, a7
  00293a:  4e 75                  rts 
  00293c:  4a 2d 96 e2            tst.b -$691e(a5)
  002940:  67 1c                  beq.b $295e
  002942:  4a 2d 96 e3            tst.b -$691d(a5)
  002946:  66 16                  bne.b $295e
  002948:  2f 3c 00 06 00 00      move.l #$60000, -(a7)
  00294e:  4e ba 16 88            jsr $3fd8(pc)
  002952:  1b 7c 00 01 96 e3      move.b #$1, -$691d(a5)
  002958:  a0 1c                  dc.w $a01c
  00295a:  a0 4c                  dc.w $a04c
  00295c:  58 8f                  addq.l #$4, a7
  00295e:  4e 75                  rts 
  002960:  4e 56 00 00            link.w a6, #$0
  002964:  48 e7 3f 00            movem.l d2-d7, -(a7)
  002968:  30 2e 00 0c            move.w $c(a6), d0
  00296c:  32 2e 00 0e            move.w $e(a6), d1
  002970:  4a 6d ba 32            tst.w -$45ce(a5)
  002974:  67 06                  beq.b $297c
  002976:  44 41                  neg.w d1
  002978:  d2 6d a5 d0            add.w -$5a30(a5), d1
  00297c:  38 01                  move.w d1, d4
  00297e:  3a 00                  move.w d0, d5
  002980:  3c 01                  move.w d1, d6
  002982:  3e 00                  move.w d0, d7
  002984:  32 2e 00 08            move.w $8(a6), d1
  002988:  e5 41                  asl.w #$2, d1
  00298a:  41 ed a5 7a            lea.l -$5a86(a5), a0
  00298e:  20 70 10 00            movea.l (a0, d1.w), a0
  002992:  20 08                  move.l a0, d0
  002994:  67 50                  beq.b $29e6
  002996:  20 50                  movea.l (a0), a0
  002998:  43 ed a5 9a            lea.l -$5a66(a5), a1
  00299c:  22 71 10 00            movea.l (a1, d1.w), a1
  0029a0:  20 09                  move.l a1, d0
  0029a2:  67 42                  beq.b $29e6
  0029a4:  22 51                  movea.l (a1), a1
  0029a6:  32 2e 00 0a            move.w $a(a6), d1
  0029aa:  e5 41                  asl.w #$2, d1
  0029ac:  20 30 10 00            move.l (a0, d1.w), d0
  0029b0:  6b 34                  bmi.b $29e6
  0029b2:  41 f1 08 00            lea.l (a1, d0.l), a0
  0029b6:  30 18                  move.w (a0)+, d0
  0029b8:  32 18                  move.w (a0)+, d1
  0029ba:  34 18                  move.w (a0)+, d2
  0029bc:  36 18                  move.w (a0)+, d3
  0029be:  4a 6e 00 10            tst.w $10(a6)
  0029c2:  6a 08                  bpl.b $29cc
  0029c4:  da 42                  add.w d2, d5
  0029c6:  de 42                  add.w d2, d7
  0029c8:  9a 40                  sub.w d0, d5
  0029ca:  60 06                  bra.b $29d2
  0029cc:  9a 42                  sub.w d2, d5
  0029ce:  9e 42                  sub.w d2, d7
  0029d0:  de 40                  add.w d0, d7
  0029d2:  4a 6d ba 32            tst.w -$45ce(a5)
  0029d6:  67 08                  beq.b $29e0
  0029d8:  d8 43                  add.w d3, d4
  0029da:  dc 43                  add.w d3, d6
  0029dc:  98 41                  sub.w d1, d4
  0029de:  60 06                  bra.b $29e6
  0029e0:  98 43                  sub.w d3, d4
  0029e2:  9c 43                  sub.w d3, d6
  0029e4:  dc 41                  add.w d1, d6
  0029e6:  3b 44 a5 f4            move.w d4, -$5a0c(a5)
  0029ea:  3b 45 a5 f6            move.w d5, -$5a0a(a5)
  0029ee:  3b 46 a5 f8            move.w d6, -$5a08(a5)
  0029f2:  3b 47 a5 fa            move.w d7, -$5a06(a5)
  0029f6:  4c df 00 fc            movem.l (a7)+, d2-d7
  0029fa:  4e 5e                  unlk a6
  0029fc:  4e 75                  rts 
  0029fe:  4e 56 ff f8            link.w a6, #$fff8
  002a02:  48 e7 3f 38            movem.l d2-d7/a2-a4, -(a7)
  002a06:  32 2e 00 08            move.w $8(a6), d1
  002a0a:  e5 41                  asl.w #$2, d1
  002a0c:  41 ed a5 7a            lea.l -$5a86(a5), a0
  002a10:  20 70 10 00            movea.l (a0, d1.w), a0
  002a14:  20 08                  move.l a0, d0
  002a16:  67 00 07 a2            beq.w $31ba
  002a1a:  20 50                  movea.l (a0), a0
  002a1c:  43 ed a5 9a            lea.l -$5a66(a5), a1
  002a20:  22 71 10 00            movea.l (a1, d1.w), a1
  002a24:  20 09                  move.l a1, d0
  002a26:  67 00 07 92            beq.w $31ba
  002a2a:  22 51                  movea.l (a1), a1
  002a2c:  32 2e 00 0a            move.w $a(a6), d1
  002a30:  e5 41                  asl.w #$2, d1
  002a32:  20 30 10 00            move.l (a0, d1.w), d0
  002a36:  6b 00 07 82            bmi.w $31ba
  002a3a:  49 f1 08 00            lea.l (a1, d0.l), a4
  002a3e:  34 1c                  move.w (a4)+, d2
  002a40:  36 1c                  move.w (a4)+, d3
  002a42:  38 1c                  move.w (a4)+, d4
  002a44:  3a 1c                  move.w (a4)+, d5
  002a46:  3c 2e 00 0c            move.w $c(a6), d6
  002a4a:  32 02                  move.w d2, d1
  002a4c:  53 41                  subq.w #$1, d1
  002a4e:  4a 6e 00 10            tst.w $10(a6)
  002a52:  6a 06                  bpl.b $2a5a
  002a54:  53 44                  subq.w #$1, d4
  002a56:  44 44                  neg.w d4
  002a58:  44 41                  neg.w d1
  002a5a:  9c 44                  sub.w d4, d6
  002a5c:  d2 46                  add.w d6, d1
  002a5e:  3e 2e 00 0e            move.w $e(a6), d7
  002a62:  4a 6d ba 32            tst.w -$45ce(a5)
  002a66:  67 0c                  beq.b $2a74
  002a68:  3e 2d a5 d0            move.w -$5a30(a5), d7
  002a6c:  53 47                  subq.w #$1, d7
  002a6e:  9e 6e 00 0e            sub.w $e(a6), d7
  002a72:  44 45                  neg.w d5
  002a74:  9e 45                  sub.w d5, d7
  002a76:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  002a7a:  30 2d a2 da            move.w -$5d26(a5), d0
  002a7e:  c1 c7                  muls.w d7, d0
  002a80:  d7 c0                  adda.l d0, a3
  002a82:  30 06                  move.w d6, d0
  002a84:  e8 40                  asr.w #$4, d0
  002a86:  d0 40                  add.w d0, d0
  002a88:  d6 c0                  adda.w d0, a3
  002a8a:  30 2d a2 e4            move.w -$5d1c(a5), d0
  002a8e:  3a 2d a2 e8            move.w -$5d18(a5), d5
  002a92:  9e 40                  sub.w d0, d7
  002a94:  9a 40                  sub.w d0, d5
  002a96:  30 2d a2 e6            move.w -$5d1a(a5), d0
  002a9a:  38 2d a2 ea            move.w -$5d16(a5), d4
  002a9e:  bc 40                  cmp.w d0, d6
  002aa0:  6d 16                  blt.b $2ab8
  002aa2:  bc 44                  cmp.w d4, d6
  002aa4:  6c 12                  bge.b $2ab8
  002aa6:  b2 40                  cmp.w d0, d1
  002aa8:  6d 0e                  blt.b $2ab8
  002aaa:  b2 44                  cmp.w d4, d1
  002aac:  6c 0a                  bge.b $2ab8
  002aae:  4a 6e 00 10            tst.w $10(a6)
  002ab2:  6a 10                  bpl.b $2ac4
  002ab4:  60 00 01 2e            bra.w $2be4
  002ab8:  4a 6e 00 10            tst.w $10(a6)
  002abc:  6a 00 02 92            bpl.w $2d50
  002ac0:  6b 00 04 a2            bmi.w $2f64
  002ac4:  53 43                  subq.w #$1, d3
  002ac6:  53 42                  subq.w #$1, d2
  002ac8:  38 02                  move.w d2, d4
  002aca:  e8 44                  asr.w #$4, d4
  002acc:  70 0f                  moveq #$f, d0
  002ace:  c0 46                  and.w d6, d0
  002ad0:  d0 40                  add.w d0, d0
  002ad2:  48 43                  swap d3
  002ad4:  48 46                  swap d6
  002ad6:  48 47                  swap d7
  002ad8:  41 ed 9f 10            lea.l -$60f0(a5), a0
  002adc:  36 30 00 00            move.w (a0, d0.w), d3
  002ae0:  41 ed 9f 50            lea.l -$60b0(a5), a0
  002ae4:  3c 30 00 00            move.w (a0, d0.w), d6
  002ae8:  3e 06                  move.w d6, d7
  002aea:  46 47                  not.w d7
  002aec:  48 47                  swap d7
  002aee:  48 46                  swap d6
  002af0:  48 43                  swap d3
  002af2:  3c 2d a2 da            move.w -$5d26(a5), d6
  002af6:  0c 40 00 10            cmpi.w #$10, d0
  002afa:  6d 10                  blt.b $2b0c
  002afc:  6c 00 00 80            bge.w $2b7e
  002b00:  30 02                  move.w d2, d0
  002b02:  52 40                  addq.w #$1, d0
  002b04:  d0 40                  add.w d0, d0
  002b06:  d0 40                  add.w d0, d0
  002b08:  d8 c0                  adda.w d0, a4
  002b0a:  60 48                  bra.b $2b54
  002b0c:  20 4b                  movea.l a3, a0
  002b0e:  34 04                  move.w d4, d2
  002b10:  be 45                  cmp.w d5, d7
  002b12:  64 ec                  bcc.b $2b00
  002b14:  48 43                  swap d3
  002b16:  48 44                  swap d4
  002b18:  48 45                  swap d5
  002b1a:  48 46                  swap d6
  002b1c:  48 47                  swap d7
  002b1e:  42 44                  clr.w d4
  002b20:  46 44                  not.w d4
  002b22:  42 45                  clr.w d5
  002b24:  22 1c                  move.l (a4)+, d1
  002b26:  e6 b9                  ror.l d3, d1
  002b28:  30 10                  move.w (a0), d0
  002b2a:  80 45                  or.w d5, d0
  002b2c:  c0 44                  and.w d4, d0
  002b2e:  38 01                  move.w d1, d4
  002b30:  88 46                  or.w d6, d4
  002b32:  c2 46                  and.w d6, d1
  002b34:  80 41                  or.w d1, d0
  002b36:  48 41                  swap d1
  002b38:  3a 01                  move.w d1, d5
  002b3a:  ca 47                  and.w d7, d5
  002b3c:  82 47                  or.w d7, d1
  002b3e:  c0 41                  and.w d1, d0
  002b40:  30 c0                  move.w d0, (a0)+
  002b42:  51 ca ff e0            dbra d2, $2b24
  002b46:  8b 50                  or.w d5, (a0)
  002b48:  c9 50                  and.w d4, (a0)
  002b4a:  48 47                  swap d7
  002b4c:  48 46                  swap d6
  002b4e:  48 45                  swap d5
  002b50:  48 44                  swap d4
  002b52:  48 43                  swap d3
  002b54:  4a 6d ba 32            tst.w -$45ce(a5)
  002b58:  66 0c                  bne.b $2b66
  002b5a:  52 47                  addq.w #$1, d7
  002b5c:  d6 c6                  adda.w d6, a3
  002b5e:  51 cb ff ac            dbra d3, $2b0c
  002b62:  60 00 06 56            bra.w $31ba
  002b66:  53 47                  subq.w #$1, d7
  002b68:  96 c6                  suba.w d6, a3
  002b6a:  51 cb ff a0            dbra d3, $2b0c
  002b6e:  60 00 06 4a            bra.w $31ba
  002b72:  30 02                  move.w d2, d0
  002b74:  52 40                  addq.w #$1, d0
  002b76:  d0 40                  add.w d0, d0
  002b78:  d0 40                  add.w d0, d0
  002b7a:  d8 c0                  adda.w d0, a4
  002b7c:  60 48                  bra.b $2bc6
  002b7e:  20 4b                  movea.l a3, a0
  002b80:  34 04                  move.w d4, d2
  002b82:  be 45                  cmp.w d5, d7
  002b84:  64 ec                  bcc.b $2b72
  002b86:  48 43                  swap d3
  002b88:  48 44                  swap d4
  002b8a:  48 45                  swap d5
  002b8c:  48 46                  swap d6
  002b8e:  48 47                  swap d7
  002b90:  42 44                  clr.w d4
  002b92:  46 44                  not.w d4
  002b94:  42 45                  clr.w d5
  002b96:  22 1c                  move.l (a4)+, d1
  002b98:  e7 b9                  rol.l d3, d1
  002b9a:  30 10                  move.w (a0), d0
  002b9c:  c0 44                  and.w d4, d0
  002b9e:  80 45                  or.w d5, d0
  002ba0:  3a 01                  move.w d1, d5
  002ba2:  ca 47                  and.w d7, d5
  002ba4:  82 47                  or.w d7, d1
  002ba6:  c0 41                  and.w d1, d0
  002ba8:  48 41                  swap d1
  002baa:  38 01                  move.w d1, d4
  002bac:  88 46                  or.w d6, d4
  002bae:  c2 46                  and.w d6, d1
  002bb0:  80 41                  or.w d1, d0
  002bb2:  30 c0                  move.w d0, (a0)+
  002bb4:  51 ca ff e0            dbra d2, $2b96
  002bb8:  c9 50                  and.w d4, (a0)
  002bba:  8b 50                  or.w d5, (a0)
  002bbc:  48 47                  swap d7
  002bbe:  48 46                  swap d6
  002bc0:  48 45                  swap d5
  002bc2:  48 44                  swap d4
  002bc4:  48 43                  swap d3
  002bc6:  4a 6d ba 32            tst.w -$45ce(a5)
  002bca:  66 0c                  bne.b $2bd8
  002bcc:  52 47                  addq.w #$1, d7
  002bce:  d6 c6                  adda.w d6, a3
  002bd0:  51 cb ff ac            dbra d3, $2b7e
  002bd4:  60 00 05 e4            bra.w $31ba
  002bd8:  53 47                  subq.w #$1, d7
  002bda:  96 c6                  suba.w d6, a3
  002bdc:  51 cb ff a0            dbra d3, $2b7e
  002be0:  60 00 05 d8            bra.w $31ba
  002be4:  53 43                  subq.w #$1, d3
  002be6:  53 42                  subq.w #$1, d2
  002be8:  38 02                  move.w d2, d4
  002bea:  e8 44                  asr.w #$4, d4
  002bec:  70 0f                  moveq #$f, d0
  002bee:  c0 46                  and.w d6, d0
  002bf0:  d0 40                  add.w d0, d0
  002bf2:  48 43                  swap d3
  002bf4:  48 46                  swap d6
  002bf6:  48 47                  swap d7
  002bf8:  41 ed 9f 30            lea.l -$60d0(a5), a0
  002bfc:  36 30 00 00            move.w (a0, d0.w), d3
  002c00:  41 ed 9f 70            lea.l -$6090(a5), a0
  002c04:  3c 30 00 00            move.w (a0, d0.w), d6
  002c08:  3e 06                  move.w d6, d7
  002c0a:  46 47                  not.w d7
  002c0c:  48 47                  swap d7
  002c0e:  48 46                  swap d6
  002c10:  48 43                  swap d3
  002c12:  45 ed 9f 90            lea.l -$6070(a5), a2
  002c16:  3c 2d a2 da            move.w -$5d26(a5), d6
  002c1a:  0c 40 00 10            cmpi.w #$10, d0
  002c1e:  6d 10                  blt.b $2c30
  002c20:  6c 00 00 a4            bge.w $2cc6
  002c24:  30 02                  move.w d2, d0
  002c26:  52 40                  addq.w #$1, d0
  002c28:  d0 40                  add.w d0, d0
  002c2a:  d0 40                  add.w d0, d0
  002c2c:  d8 c0                  adda.w d0, a4
  002c2e:  60 6c                  bra.b $2c9c
  002c30:  20 4b                  movea.l a3, a0
  002c32:  34 04                  move.w d4, d2
  002c34:  be 45                  cmp.w d5, d7
  002c36:  64 ec                  bcc.b $2c24
  002c38:  48 43                  swap d3
  002c3a:  48 44                  swap d4
  002c3c:  48 45                  swap d5
  002c3e:  48 46                  swap d6
  002c40:  48 47                  swap d7
  002c42:  42 44                  clr.w d4
  002c44:  46 44                  not.w d4
  002c46:  42 45                  clr.w d5
  002c48:  70 00                  moveq #$0, d0
  002c4a:  22 1c                  move.l (a4)+, d1
  002c4c:  10 01                  move.b d1, d0
  002c4e:  12 32 00 00            move.b (a2, d0.w), d1
  002c52:  e1 59                  rol.w #$8, d1
  002c54:  10 01                  move.b d1, d0
  002c56:  12 32 00 00            move.b (a2, d0.w), d1
  002c5a:  48 41                  swap d1
  002c5c:  10 01                  move.b d1, d0
  002c5e:  12 32 00 00            move.b (a2, d0.w), d1
  002c62:  e1 59                  rol.w #$8, d1
  002c64:  10 01                  move.b d1, d0
  002c66:  12 32 00 00            move.b (a2, d0.w), d1
  002c6a:  48 41                  swap d1
  002c6c:  e6 b9                  ror.l d3, d1
  002c6e:  30 10                  move.w (a0), d0
  002c70:  c0 44                  and.w d4, d0
  002c72:  80 45                  or.w d5, d0
  002c74:  3a 01                  move.w d1, d5
  002c76:  ca 47                  and.w d7, d5
  002c78:  82 47                  or.w d7, d1
  002c7a:  c0 41                  and.w d1, d0
  002c7c:  48 41                  swap d1
  002c7e:  38 01                  move.w d1, d4
  002c80:  88 46                  or.w d6, d4
  002c82:  c2 46                  and.w d6, d1
  002c84:  80 41                  or.w d1, d0
  002c86:  30 80                  move.w d0, (a0)
  002c88:  55 88                  subq.l #$2, a0
  002c8a:  51 ca ff bc            dbra d2, $2c48
  002c8e:  c9 50                  and.w d4, (a0)
  002c90:  8b 50                  or.w d5, (a0)
  002c92:  48 47                  swap d7
  002c94:  48 46                  swap d6
  002c96:  48 45                  swap d5
  002c98:  48 44                  swap d4
  002c9a:  48 43                  swap d3
  002c9c:  4a 6d ba 32            tst.w -$45ce(a5)
  002ca0:  66 0c                  bne.b $2cae
  002ca2:  52 47                  addq.w #$1, d7
  002ca4:  d6 c6                  adda.w d6, a3
  002ca6:  51 cb ff 88            dbra d3, $2c30
  002caa:  60 00 05 0e            bra.w $31ba
  002cae:  53 47                  subq.w #$1, d7
  002cb0:  96 c6                  suba.w d6, a3
  002cb2:  51 cb ff 7c            dbra d3, $2c30
  002cb6:  60 00 05 02            bra.w $31ba
  002cba:  30 02                  move.w d2, d0
  002cbc:  52 40                  addq.w #$1, d0
  002cbe:  d0 40                  add.w d0, d0
  002cc0:  d0 40                  add.w d0, d0
  002cc2:  d8 c0                  adda.w d0, a4
  002cc4:  60 6c                  bra.b $2d32
  002cc6:  20 4b                  movea.l a3, a0
  002cc8:  34 04                  move.w d4, d2
  002cca:  be 45                  cmp.w d5, d7
  002ccc:  64 ec                  bcc.b $2cba
  002cce:  48 43                  swap d3
  002cd0:  48 44                  swap d4
  002cd2:  48 45                  swap d5
  002cd4:  48 46                  swap d6
  002cd6:  48 47                  swap d7
  002cd8:  42 44                  clr.w d4
  002cda:  46 44                  not.w d4
  002cdc:  42 45                  clr.w d5
  002cde:  70 00                  moveq #$0, d0
  002ce0:  22 1c                  move.l (a4)+, d1
  002ce2:  10 01                  move.b d1, d0
  002ce4:  12 32 00 00            move.b (a2, d0.w), d1
  002ce8:  e1 59                  rol.w #$8, d1
  002cea:  10 01                  move.b d1, d0
  002cec:  12 32 00 00            move.b (a2, d0.w), d1
  002cf0:  48 41                  swap d1
  002cf2:  10 01                  move.b d1, d0
  002cf4:  12 32 00 00            move.b (a2, d0.w), d1
  002cf8:  e1 59                  rol.w #$8, d1
  002cfa:  10 01                  move.b d1, d0
  002cfc:  12 32 00 00            move.b (a2, d0.w), d1
  002d00:  48 41                  swap d1
  002d02:  e7 b9                  rol.l d3, d1
  002d04:  30 10                  move.w (a0), d0
  002d06:  80 45                  or.w d5, d0
  002d08:  c0 44                  and.w d4, d0
  002d0a:  38 01                  move.w d1, d4
  002d0c:  88 46                  or.w d6, d4
  002d0e:  c2 46                  and.w d6, d1
  002d10:  80 41                  or.w d1, d0
  002d12:  48 41                  swap d1
  002d14:  3a 01                  move.w d1, d5
  002d16:  ca 47                  and.w d7, d5
  002d18:  82 47                  or.w d7, d1
  002d1a:  c0 41                  and.w d1, d0
  002d1c:  30 80                  move.w d0, (a0)
  002d1e:  55 88                  subq.l #$2, a0
  002d20:  51 ca ff bc            dbra d2, $2cde
  002d24:  8b 50                  or.w d5, (a0)
  002d26:  c9 50                  and.w d4, (a0)
  002d28:  48 47                  swap d7
  002d2a:  48 46                  swap d6
  002d2c:  48 45                  swap d5
  002d2e:  48 44                  swap d4
  002d30:  48 43                  swap d3
  002d32:  4a 6d ba 32            tst.w -$45ce(a5)
  002d36:  66 0c                  bne.b $2d44
  002d38:  52 47                  addq.w #$1, d7
  002d3a:  d6 c6                  adda.w d6, a3
  002d3c:  51 cb ff 88            dbra d3, $2cc6
  002d40:  60 00 04 78            bra.w $31ba
  002d44:  53 47                  subq.w #$1, d7
  002d46:  96 c6                  suba.w d6, a3
  002d48:  51 cb ff 7c            dbra d3, $2cc6
  002d4c:  60 00 04 6c            bra.w $31ba
  002d50:  53 43                  subq.w #$1, d3
  002d52:  53 42                  subq.w #$1, d2
  002d54:  38 02                  move.w d2, d4
  002d56:  e8 44                  asr.w #$4, d4
  002d58:  34 06                  move.w d6, d2
  002d5a:  e8 42                  asr.w #$4, d2
  002d5c:  d4 44                  add.w d4, d2
  002d5e:  32 2d a2 e6            move.w -$5d1a(a5), d1
  002d62:  70 0f                  moveq #$f, d0
  002d64:  c0 41                  and.w d1, d0
  002d66:  e8 41                  asr.w #$4, d1
  002d68:  3d 42 ff fe            move.w d2, -$2(a6)
  002d6c:  93 6e ff fe            sub.w d1, -$2(a6)
  002d70:  d0 40                  add.w d0, d0
  002d72:  41 ed 9f 50            lea.l -$60b0(a5), a0
  002d76:  3d 70 00 00 ff fc      move.w (a0, d0.w), -$4(a6)
  002d7c:  32 2d a2 ea            move.w -$5d16(a5), d1
  002d80:  53 41                  subq.w #$1, d1
  002d82:  70 0f                  moveq #$f, d0
  002d84:  c0 41                  and.w d1, d0
  002d86:  e8 41                  asr.w #$4, d1
  002d88:  3d 42 ff fa            move.w d2, -$6(a6)
  002d8c:  93 6e ff fa            sub.w d1, -$6(a6)
  002d90:  d0 40                  add.w d0, d0
  002d92:  41 ed 9f 70            lea.l -$6090(a5), a0
  002d96:  3d 70 00 00 ff f8      move.w (a0, d0.w), -$8(a6)
  002d9c:  70 0f                  moveq #$f, d0
  002d9e:  c0 46                  and.w d6, d0
  002da0:  d0 40                  add.w d0, d0
  002da2:  48 43                  swap d3
  002da4:  48 46                  swap d6
  002da6:  48 47                  swap d7
  002da8:  41 ed 9f 10            lea.l -$60f0(a5), a0
  002dac:  36 30 00 00            move.w (a0, d0.w), d3
  002db0:  41 ed 9f 50            lea.l -$60b0(a5), a0
  002db4:  3c 30 00 00            move.w (a0, d0.w), d6
  002db8:  3e 06                  move.w d6, d7
  002dba:  46 47                  not.w d7
  002dbc:  48 47                  swap d7
  002dbe:  48 46                  swap d6
  002dc0:  48 43                  swap d3
  002dc2:  3c 2d a2 da            move.w -$5d26(a5), d6
  002dc6:  0c 40 00 10            cmpi.w #$10, d0
  002dca:  6d 12                  blt.b $2dde
  002dcc:  6c 00 00 da            bge.w $2ea8
  002dd0:  30 02                  move.w d2, d0
  002dd2:  52 40                  addq.w #$1, d0
  002dd4:  d0 40                  add.w d0, d0
  002dd6:  d0 40                  add.w d0, d0
  002dd8:  d8 c0                  adda.w d0, a4
  002dda:  60 00 00 a0            bra.w $2e7c
  002dde:  20 4b                  movea.l a3, a0
  002de0:  34 04                  move.w d4, d2
  002de2:  be 45                  cmp.w d5, d7
  002de4:  64 ea                  bcc.b $2dd0
  002de6:  48 43                  swap d3
  002de8:  48 44                  swap d4
  002dea:  48 45                  swap d5
  002dec:  48 46                  swap d6
  002dee:  48 47                  swap d7
  002df0:  42 44                  clr.w d4
  002df2:  46 44                  not.w d4
  002df4:  42 45                  clr.w d5
  002df6:  22 1c                  move.l (a4)+, d1
  002df8:  e6 b9                  ror.l d3, d1
  002dfa:  30 10                  move.w (a0), d0
  002dfc:  80 45                  or.w d5, d0
  002dfe:  c0 44                  and.w d4, d0
  002e00:  38 01                  move.w d1, d4
  002e02:  88 46                  or.w d6, d4
  002e04:  c2 46                  and.w d6, d1
  002e06:  80 41                  or.w d1, d0
  002e08:  48 41                  swap d1
  002e0a:  3a 01                  move.w d1, d5
  002e0c:  ca 47                  and.w d7, d5
  002e0e:  82 47                  or.w d7, d1
  002e10:  c0 41                  and.w d1, d0
  002e12:  b4 6e ff fe            cmp.w -$2(a6), d2
  002e16:  6d 0e                  blt.b $2e26
  002e18:  6e 22                  bgt.b $2e3c
  002e1a:  32 2e ff fc            move.w -$4(a6), d1
  002e1e:  c0 41                  and.w d1, d0
  002e20:  46 41                  not.w d1
  002e22:  c2 50                  and.w (a0), d1
  002e24:  80 41                  or.w d1, d0
  002e26:  b4 6e ff fa            cmp.w -$6(a6), d2
  002e2a:  6e 0e                  bgt.b $2e3a
  002e2c:  6d 0e                  blt.b $2e3c
  002e2e:  32 2e ff f8            move.w -$8(a6), d1
  002e32:  c0 41                  and.w d1, d0
  002e34:  46 41                  not.w d1
  002e36:  c2 50                  and.w (a0), d1
  002e38:  80 41                  or.w d1, d0
  002e3a:  30 80                  move.w d0, (a0)
  002e3c:  54 88                  addq.l #$2, a0
  002e3e:  51 ca ff b6            dbra d2, $2df6
  002e42:  30 10                  move.w (a0), d0
  002e44:  80 45                  or.w d5, d0
  002e46:  c0 44                  and.w d4, d0
  002e48:  b4 6e ff fe            cmp.w -$2(a6), d2
  002e4c:  6d 0e                  blt.b $2e5c
  002e4e:  6e 22                  bgt.b $2e72
  002e50:  32 2e ff fc            move.w -$4(a6), d1
  002e54:  c0 41                  and.w d1, d0
  002e56:  46 41                  not.w d1
  002e58:  c2 50                  and.w (a0), d1
  002e5a:  80 41                  or.w d1, d0
  002e5c:  b4 6e ff fa            cmp.w -$6(a6), d2
  002e60:  6e 0e                  bgt.b $2e70
  002e62:  6d 0e                  blt.b $2e72
  002e64:  32 2e ff f8            move.w -$8(a6), d1
  002e68:  c0 41                  and.w d1, d0
  002e6a:  46 41                  not.w d1
  002e6c:  c2 50                  and.w (a0), d1
  002e6e:  80 41                  or.w d1, d0
  002e70:  30 80                  move.w d0, (a0)
  002e72:  48 47                  swap d7
  002e74:  48 46                  swap d6
  002e76:  48 45                  swap d5
  002e78:  48 44                  swap d4
  002e7a:  48 43                  swap d3
  002e7c:  4a 6d ba 32            tst.w -$45ce(a5)
  002e80:  66 0c                  bne.b $2e8e
  002e82:  52 47                  addq.w #$1, d7
  002e84:  d6 c6                  adda.w d6, a3
  002e86:  51 cb ff 56            dbra d3, $2dde
  002e8a:  60 00 03 2e            bra.w $31ba
  002e8e:  53 47                  subq.w #$1, d7
  002e90:  96 c6                  suba.w d6, a3
  002e92:  51 cb ff 4a            dbra d3, $2dde
  002e96:  60 00 03 22            bra.w $31ba
  002e9a:  30 02                  move.w d2, d0
  002e9c:  52 40                  addq.w #$1, d0
  002e9e:  d0 40                  add.w d0, d0
  002ea0:  d0 40                  add.w d0, d0
  002ea2:  d8 c0                  adda.w d0, a4
  002ea4:  60 00 00 a0            bra.w $2f46
  002ea8:  20 4b                  movea.l a3, a0
  002eaa:  34 04                  move.w d4, d2
  002eac:  be 45                  cmp.w d5, d7
  002eae:  64 ea                  bcc.b $2e9a
  002eb0:  48 43                  swap d3
  002eb2:  48 44                  swap d4
  002eb4:  48 45                  swap d5
  002eb6:  48 46                  swap d6
  002eb8:  48 47                  swap d7
  002eba:  42 44                  clr.w d4
  002ebc:  46 44                  not.w d4
  002ebe:  42 45                  clr.w d5
  002ec0:  22 1c                  move.l (a4)+, d1
  002ec2:  e7 b9                  rol.l d3, d1
  002ec4:  30 10                  move.w (a0), d0
  002ec6:  c0 44                  and.w d4, d0
  002ec8:  80 45                  or.w d5, d0
  002eca:  3a 01                  move.w d1, d5
  002ecc:  ca 47                  and.w d7, d5
  002ece:  82 47                  or.w d7, d1
  002ed0:  c0 41                  and.w d1, d0
  002ed2:  48 41                  swap d1
  002ed4:  38 01                  move.w d1, d4
  002ed6:  88 46                  or.w d6, d4
  002ed8:  c2 46                  and.w d6, d1
  002eda:  80 41                  or.w d1, d0
  002edc:  b4 6e ff fe            cmp.w -$2(a6), d2
  002ee0:  6d 0e                  blt.b $2ef0
  002ee2:  6e 22                  bgt.b $2f06
  002ee4:  32 2e ff fc            move.w -$4(a6), d1
  002ee8:  c0 41                  and.w d1, d0
  002eea:  46 41                  not.w d1
  002eec:  c2 50                  and.w (a0), d1
  002eee:  80 41                  or.w d1, d0
  002ef0:  b4 6e ff fa            cmp.w -$6(a6), d2
  002ef4:  6e 0e                  bgt.b $2f04
  002ef6:  6d 0e                  blt.b $2f06
  002ef8:  32 2e ff f8            move.w -$8(a6), d1
  002efc:  c0 41                  and.w d1, d0
  002efe:  46 41                  not.w d1
  002f00:  c2 50                  and.w (a0), d1
  002f02:  80 41                  or.w d1, d0
  002f04:  30 80                  move.w d0, (a0)
  002f06:  54 88                  addq.l #$2, a0
  002f08:  51 ca ff b6            dbra d2, $2ec0
  002f0c:  30 10                  move.w (a0), d0
  002f0e:  c0 44                  and.w d4, d0
  002f10:  80 45                  or.w d5, d0
  002f12:  b4 6e ff fe            cmp.w -$2(a6), d2
  002f16:  6d 0e                  blt.b $2f26
  002f18:  6e 22                  bgt.b $2f3c
  002f1a:  32 2e ff fc            move.w -$4(a6), d1
  002f1e:  c0 41                  and.w d1, d0
  002f20:  46 41                  not.w d1
  002f22:  c2 50                  and.w (a0), d1
  002f24:  80 41                  or.w d1, d0
  002f26:  b4 6e ff fa            cmp.w -$6(a6), d2
  002f2a:  6e 0e                  bgt.b $2f3a
  002f2c:  6d 0e                  blt.b $2f3c
  002f2e:  32 2e ff f8            move.w -$8(a6), d1
  002f32:  c0 41                  and.w d1, d0
  002f34:  46 41                  not.w d1
  002f36:  c2 50                  and.w (a0), d1
  002f38:  80 41                  or.w d1, d0
  002f3a:  30 80                  move.w d0, (a0)
  002f3c:  48 47                  swap d7
  002f3e:  48 46                  swap d6
  002f40:  48 45                  swap d5
  002f42:  48 44                  swap d4
  002f44:  48 43                  swap d3
  002f46:  4a 6d ba 32            tst.w -$45ce(a5)
  002f4a:  66 0c                  bne.b $2f58
  002f4c:  52 47                  addq.w #$1, d7
  002f4e:  d6 c6                  adda.w d6, a3
  002f50:  51 cb ff 56            dbra d3, $2ea8
  002f54:  60 00 02 64            bra.w $31ba
  002f58:  53 47                  subq.w #$1, d7
  002f5a:  96 c6                  suba.w d6, a3
  002f5c:  51 cb ff 4a            dbra d3, $2ea8
  002f60:  60 00 02 58            bra.w $31ba
  002f64:  53 43                  subq.w #$1, d3
  002f66:  53 42                  subq.w #$1, d2
  002f68:  38 02                  move.w d2, d4
  002f6a:  e8 44                  asr.w #$4, d4
  002f6c:  34 06                  move.w d6, d2
  002f6e:  e8 42                  asr.w #$4, d2
  002f70:  94 44                  sub.w d4, d2
  002f72:  32 2d a2 e6            move.w -$5d1a(a5), d1
  002f76:  70 0f                  moveq #$f, d0
  002f78:  c0 41                  and.w d1, d0
  002f7a:  e8 41                  asr.w #$4, d1
  002f7c:  3d 41 ff fe            move.w d1, -$2(a6)
  002f80:  95 6e ff fe            sub.w d2, -$2(a6)
  002f84:  d0 40                  add.w d0, d0
  002f86:  41 ed 9f 50            lea.l -$60b0(a5), a0
  002f8a:  3d 70 00 00 ff fc      move.w (a0, d0.w), -$4(a6)
  002f90:  32 2d a2 ea            move.w -$5d16(a5), d1
  002f94:  53 41                  subq.w #$1, d1
  002f96:  70 0f                  moveq #$f, d0
  002f98:  c0 41                  and.w d1, d0
  002f9a:  e8 41                  asr.w #$4, d1
  002f9c:  3d 41 ff fa            move.w d1, -$6(a6)
  002fa0:  95 6e ff fa            sub.w d2, -$6(a6)
  002fa4:  d0 40                  add.w d0, d0
  002fa6:  41 ed 9f 70            lea.l -$6090(a5), a0
  002faa:  3d 70 00 00 ff f8      move.w (a0, d0.w), -$8(a6)
  002fb0:  70 0f                  moveq #$f, d0
  002fb2:  c0 46                  and.w d6, d0
  002fb4:  d0 40                  add.w d0, d0
  002fb6:  48 43                  swap d3
  002fb8:  48 46                  swap d6
  002fba:  48 47                  swap d7
  002fbc:  41 ed 9f 30            lea.l -$60d0(a5), a0
  002fc0:  36 30 00 00            move.w (a0, d0.w), d3
  002fc4:  41 ed 9f 70            lea.l -$6090(a5), a0
  002fc8:  3c 30 00 00            move.w (a0, d0.w), d6
  002fcc:  3e 06                  move.w d6, d7
  002fce:  46 47                  not.w d7
  002fd0:  48 47                  swap d7
  002fd2:  48 46                  swap d6
  002fd4:  48 43                  swap d3
  002fd6:  45 ed 9f 90            lea.l -$6070(a5), a2
  002fda:  3c 2d a2 da            move.w -$5d26(a5), d6
  002fde:  0c 40 00 10            cmpi.w #$10, d0
  002fe2:  6d 12                  blt.b $2ff6
  002fe4:  6c 00 00 fc            bge.w $30e2
  002fe8:  30 02                  move.w d2, d0
  002fea:  52 40                  addq.w #$1, d0
  002fec:  d0 40                  add.w d0, d0
  002fee:  d0 40                  add.w d0, d0
  002ff0:  d8 c0                  adda.w d0, a4
  002ff2:  60 00 00 c2            bra.w $30b6
  002ff6:  20 4b                  movea.l a3, a0
  002ff8:  34 04                  move.w d4, d2
  002ffa:  be 45                  cmp.w d5, d7
  002ffc:  64 ea                  bcc.b $2fe8
  002ffe:  48 43                  swap d3
  003000:  48 44                  swap d4
  003002:  48 45                  swap d5
  003004:  48 46                  swap d6
  003006:  48 47                  swap d7
  003008:  42 44                  clr.w d4
  00300a:  46 44                  not.w d4
  00300c:  42 45                  clr.w d5
  00300e:  70 00                  moveq #$0, d0
  003010:  22 1c                  move.l (a4)+, d1
  003012:  10 01                  move.b d1, d0
  003014:  12 32 00 00            move.b (a2, d0.w), d1
  003018:  e1 59                  rol.w #$8, d1
  00301a:  10 01                  move.b d1, d0
  00301c:  12 32 00 00            move.b (a2, d0.w), d1
  003020:  48 41                  swap d1
  003022:  10 01                  move.b d1, d0
  003024:  12 32 00 00            move.b (a2, d0.w), d1
  003028:  e1 59                  rol.w #$8, d1
  00302a:  10 01                  move.b d1, d0
  00302c:  12 32 00 00            move.b (a2, d0.w), d1
  003030:  48 41                  swap d1
  003032:  e6 b9                  ror.l d3, d1
  003034:  30 10                  move.w (a0), d0
  003036:  c0 44                  and.w d4, d0
  003038:  80 45                  or.w d5, d0
  00303a:  3a 01                  move.w d1, d5
  00303c:  ca 47                  and.w d7, d5
  00303e:  82 47                  or.w d7, d1
  003040:  c0 41                  and.w d1, d0
  003042:  48 41                  swap d1
  003044:  38 01                  move.w d1, d4
  003046:  88 46                  or.w d6, d4
  003048:  c2 46                  and.w d6, d1
  00304a:  80 41                  or.w d1, d0
  00304c:  b4 6e ff fa            cmp.w -$6(a6), d2
  003050:  6d 0e                  blt.b $3060
  003052:  6e 22                  bgt.b $3076
  003054:  32 2e ff f8            move.w -$8(a6), d1
  003058:  c0 41                  and.w d1, d0
  00305a:  46 41                  not.w d1
  00305c:  c2 50                  and.w (a0), d1
  00305e:  80 41                  or.w d1, d0
  003060:  b4 6e ff fe            cmp.w -$2(a6), d2
  003064:  6e 0e                  bgt.b $3074
  003066:  6d 0e                  blt.b $3076
  003068:  32 2e ff fc            move.w -$4(a6), d1
  00306c:  c0 41                  and.w d1, d0
  00306e:  46 41                  not.w d1
  003070:  c2 50                  and.w (a0), d1
  003072:  80 41                  or.w d1, d0
  003074:  30 80                  move.w d0, (a0)
  003076:  55 88                  subq.l #$2, a0
  003078:  51 ca ff 94            dbra d2, $300e
  00307c:  30 10                  move.w (a0), d0
  00307e:  c0 44                  and.w d4, d0
  003080:  80 45                  or.w d5, d0
  003082:  b4 6e ff fa            cmp.w -$6(a6), d2
  003086:  6d 0e                  blt.b $3096
  003088:  6e 22                  bgt.b $30ac
  00308a:  32 2e ff f8            move.w -$8(a6), d1
  00308e:  c0 41                  and.w d1, d0
  003090:  46 41                  not.w d1
  003092:  c2 50                  and.w (a0), d1
  003094:  80 41                  or.w d1, d0
  003096:  b4 6e ff fe            cmp.w -$2(a6), d2
  00309a:  6e 0e                  bgt.b $30aa
  00309c:  6d 0e                  blt.b $30ac
  00309e:  32 2e ff fc            move.w -$4(a6), d1
  0030a2:  c0 41                  and.w d1, d0
  0030a4:  46 41                  not.w d1
  0030a6:  c2 50                  and.w (a0), d1
  0030a8:  80 41                  or.w d1, d0
  0030aa:  30 80                  move.w d0, (a0)
  0030ac:  48 47                  swap d7
  0030ae:  48 46                  swap d6
  0030b0:  48 45                  swap d5
  0030b2:  48 44                  swap d4
  0030b4:  48 43                  swap d3
  0030b6:  4a 6d ba 32            tst.w -$45ce(a5)
  0030ba:  66 0c                  bne.b $30c8
  0030bc:  52 47                  addq.w #$1, d7
  0030be:  d6 c6                  adda.w d6, a3
  0030c0:  51 cb ff 34            dbra d3, $2ff6
  0030c4:  60 00 00 f4            bra.w $31ba
  0030c8:  53 47                  subq.w #$1, d7
  0030ca:  96 c6                  suba.w d6, a3
  0030cc:  51 cb ff 28            dbra d3, $2ff6
  0030d0:  60 00 00 e8            bra.w $31ba
  0030d4:  30 02                  move.w d2, d0
  0030d6:  52 40                  addq.w #$1, d0
  0030d8:  d0 40                  add.w d0, d0
  0030da:  d0 40                  add.w d0, d0
  0030dc:  d8 c0                  adda.w d0, a4
  0030de:  60 00 00 c2            bra.w $31a2
  0030e2:  20 4b                  movea.l a3, a0
  0030e4:  34 04                  move.w d4, d2
  0030e6:  be 45                  cmp.w d5, d7
  0030e8:  64 ea                  bcc.b $30d4
  0030ea:  48 43                  swap d3
  0030ec:  48 44                  swap d4
  0030ee:  48 45                  swap d5
  0030f0:  48 46                  swap d6
  0030f2:  48 47                  swap d7
  0030f4:  42 44                  clr.w d4
  0030f6:  46 44                  not.w d4
  0030f8:  42 45                  clr.w d5
  0030fa:  70 00                  moveq #$0, d0
  0030fc:  22 1c                  move.l (a4)+, d1
  0030fe:  10 01                  move.b d1, d0
  003100:  12 32 00 00            move.b (a2, d0.w), d1
  003104:  e1 59                  rol.w #$8, d1
  003106:  10 01                  move.b d1, d0
  003108:  12 32 00 00            move.b (a2, d0.w), d1
  00310c:  48 41                  swap d1
  00310e:  10 01                  move.b d1, d0
  003110:  12 32 00 00            move.b (a2, d0.w), d1
  003114:  e1 59                  rol.w #$8, d1
  003116:  10 01                  move.b d1, d0
  003118:  12 32 00 00            move.b (a2, d0.w), d1
  00311c:  48 41                  swap d1
  00311e:  e7 b9                  rol.l d3, d1
  003120:  30 10                  move.w (a0), d0
  003122:  80 45                  or.w d5, d0
  003124:  c0 44                  and.w d4, d0
  003126:  38 01                  move.w d1, d4
  003128:  88 46                  or.w d6, d4
  00312a:  c2 46                  and.w d6, d1
  00312c:  80 41                  or.w d1, d0
  00312e:  48 41                  swap d1
  003130:  3a 01                  move.w d1, d5
  003132:  ca 47                  and.w d7, d5
  003134:  82 47                  or.w d7, d1
  003136:  c0 41                  and.w d1, d0
  003138:  b4 6e ff fa            cmp.w -$6(a6), d2
  00313c:  6d 0e                  blt.b $314c
  00313e:  6e 22                  bgt.b $3162
  003140:  32 2e ff f8            move.w -$8(a6), d1
  003144:  c0 41                  and.w d1, d0
  003146:  46 41                  not.w d1
  003148:  c2 50                  and.w (a0), d1
  00314a:  80 41                  or.w d1, d0
  00314c:  b4 6e ff fe            cmp.w -$2(a6), d2
  003150:  6e 0e                  bgt.b $3160
  003152:  6d 0e                  blt.b $3162
  003154:  32 2e ff fc            move.w -$4(a6), d1
  003158:  c0 41                  and.w d1, d0
  00315a:  46 41                  not.w d1
  00315c:  c2 50                  and.w (a0), d1
  00315e:  80 41                  or.w d1, d0
  003160:  30 80                  move.w d0, (a0)
  003162:  55 88                  subq.l #$2, a0
  003164:  51 ca ff 94            dbra d2, $30fa
  003168:  30 10                  move.w (a0), d0
  00316a:  80 45                  or.w d5, d0
  00316c:  c0 44                  and.w d4, d0
  00316e:  b4 6e ff fa            cmp.w -$6(a6), d2
  003172:  6d 0e                  blt.b $3182
  003174:  6e 22                  bgt.b $3198
  003176:  32 2e ff f8            move.w -$8(a6), d1
  00317a:  c0 41                  and.w d1, d0
  00317c:  46 41                  not.w d1
  00317e:  c2 50                  and.w (a0), d1
  003180:  80 41                  or.w d1, d0
  003182:  b4 6e ff fe            cmp.w -$2(a6), d2
  003186:  6e 0e                  bgt.b $3196
  003188:  6d 0e                  blt.b $3198
  00318a:  32 2e ff fc            move.w -$4(a6), d1
  00318e:  c0 41                  and.w d1, d0
  003190:  46 41                  not.w d1
  003192:  c2 50                  and.w (a0), d1
  003194:  80 41                  or.w d1, d0
  003196:  30 80                  move.w d0, (a0)
  003198:  48 47                  swap d7
  00319a:  48 46                  swap d6
  00319c:  48 45                  swap d5
  00319e:  48 44                  swap d4
  0031a0:  48 43                  swap d3
  0031a2:  4a 6d ba 32            tst.w -$45ce(a5)
  0031a6:  66 0a                  bne.b $31b2
  0031a8:  52 47                  addq.w #$1, d7
  0031aa:  d6 c6                  adda.w d6, a3
  0031ac:  51 cb ff 34            dbra d3, $30e2
  0031b0:  60 08                  bra.b $31ba
  0031b2:  53 47                  subq.w #$1, d7
  0031b4:  96 c6                  suba.w d6, a3
  0031b6:  51 cb ff 2a            dbra d3, $30e2
  0031ba:  4c df 1c fc            movem.l (a7)+, d2-d7/a2-a4
  0031be:  4e 5e                  unlk a6
  0031c0:  4e 75                  rts 
  0031c2:  4e 56 00 00            link.w a6, #$0
  0031c6:  48 e7 3f 10            movem.l d2-d7/a3, -(a7)
  0031ca:  20 6e 00 08            movea.l $8(a6), a0
  0031ce:  38 18                  move.w (a0)+, d4
  0031d0:  3a 18                  move.w (a0)+, d5
  0031d2:  3c 18                  move.w (a0)+, d6
  0031d4:  3e 18                  move.w (a0)+, d7
  0031d6:  34 06                  move.w d6, d2
  0031d8:  94 44                  sub.w d4, d2
  0031da:  30 04                  move.w d4, d0
  0031dc:  72 07                  moveq #$7, d1
  0031de:  38 05                  move.w d5, d4
  0031e0:  e6 44                  asr.w #$3, d4
  0031e2:  ca 41                  and.w d1, d5
  0031e4:  53 47                  subq.w #$1, d7
  0031e6:  3c 07                  move.w d7, d6
  0031e8:  e6 46                  asr.w #$3, d6
  0031ea:  ce 41                  and.w d1, d7
  0031ec:  9c 44                  sub.w d4, d6
  0031ee:  53 46                  subq.w #$1, d6
  0031f0:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0031f4:  36 2d a2 da            move.w -$5d26(a5), d3
  0031f8:  c1 c3                  muls.w d3, d0
  0031fa:  d7 c0                  adda.l d0, a3
  0031fc:  d6 c4                  adda.w d4, a3
  0031fe:  70 00                  moveq #$0, d0
  003200:  10 2e 00 0c            move.b $c(a6), d0
  003204:  67 3a                  beq.b $3240
  003206:  1a 3b 50 28            move.b $3230(pc, d5.w), d5
  00320a:  1e 3b 70 2c            move.b $3238(pc, d7.w), d7
  00320e:  60 1a                  bra.b $322a
  003210:  12 05                  move.b d5, d1
  003212:  20 4b                  movea.l a3, a0
  003214:  30 06                  move.w d6, d0
  003216:  6b 0c                  bmi.b $3224
  003218:  83 18                  or.b d1, (a0)+
  00321a:  72 ff                  moveq #$ff, d1
  00321c:  60 02                  bra.b $3220
  00321e:  10 c1                  move.b d1, (a0)+
  003220:  51 c8 ff fc            dbra d0, $321e
  003224:  c2 07                  and.b d7, d1
  003226:  83 18                  or.b d1, (a0)+
  003228:  d6 c3                  adda.w d3, a3
  00322a:  51 ca ff e4            dbra d2, $3210
  00322e:  60 4a                  bra.b $327a
  003230:  ff 7f                  dc.w $ff7f
  003232:  3f 1f                  move.w (a7)+, -(a7)
  003234:  0f 07                  btst.l d7, d7
  003236:  03 01                  btst.l d1, d1
  003238:  80 c0                  divu.w d0, d0
  00323a:  e0 f0 f8 fc            asr.w -$4(a0, a7.l)
  00323e:  fe ff                  dc.w $feff
  003240:  1a 3b 50 28            move.b $326a(pc, d5.w), d5
  003244:  1e 3b 70 2c            move.b $3272(pc, d7.w), d7
  003248:  60 1a                  bra.b $3264
  00324a:  12 05                  move.b d5, d1
  00324c:  20 4b                  movea.l a3, a0
  00324e:  30 06                  move.w d6, d0
  003250:  6b 0c                  bmi.b $325e
  003252:  c3 18                  and.b d1, (a0)+
  003254:  72 00                  moveq #$0, d1
  003256:  60 02                  bra.b $325a
  003258:  10 c1                  move.b d1, (a0)+
  00325a:  51 c8 ff fc            dbra d0, $3258
  00325e:  82 07                  or.b d7, d1
  003260:  c3 18                  and.b d1, (a0)+
  003262:  d6 c3                  adda.w d3, a3
  003264:  51 ca ff e4            dbra d2, $324a
  003268:  60 10                  bra.b $327a
  00326a:  00 80 c0 e0 f0 f8      ori.l #$c0e0f0f8, d0
  003270:  fc fe                  dc.w $fcfe
  003272:  7f 3f                  dc.w $7f3f
  003274:  1f 0f                  dc.w $1f0f
  003276:  07 03                  btst.l d3, d3
  003278:  01 00                  btst.l d0, d0
  00327a:  4c df 08 fc            movem.l (a7)+, d2-d7/a3
  00327e:  4e 5e                  unlk a6
  003280:  4e 75                  rts 
  003282:  4e 56 00 00            link.w a6, #$0
  003286:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  00328a:  99 cc                  suba.l a4, a4
  00328c:  20 6e 00 08            movea.l $8(a6), a0
  003290:  38 18                  move.w (a0)+, d4
  003292:  3a 18                  move.w (a0)+, d5
  003294:  3c 18                  move.w (a0)+, d6
  003296:  3e 18                  move.w (a0)+, d7
  003298:  9c 44                  sub.w d4, d6
  00329a:  63 00 00 c2            bls.w $335e
  00329e:  e8 45                  asr.w #$4, d5
  0032a0:  06 47 00 0f            addi.w #$f, d7
  0032a4:  e8 47                  asr.w #$4, d7
  0032a6:  9e 45                  sub.w d5, d7
  0032a8:  63 00 00 b4            bls.w $335e
  0032ac:  30 06                  move.w d6, d0
  0032ae:  c0 c7                  mulu.w d7, d0
  0032b0:  d0 80                  add.l d0, d0
  0032b2:  a1 22                  dc.w $a122
  0032b4:  4a 40                  tst.w d0
  0032b6:  66 00 00 a6            bne.w $335e
  0032ba:  28 48                  movea.l a0, a4
  0032bc:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0032c0:  36 2d a2 da            move.w -$5d26(a5), d3
  0032c4:  c9 c3                  muls.w d3, d4
  0032c6:  d7 c4                  adda.l d4, a3
  0032c8:  da 45                  add.w d5, d5
  0032ca:  d6 c5                  adda.w d5, a3
  0032cc:  20 54                  movea.l (a4), a0
  0032ce:  53 46                  subq.w #$1, d6
  0032d0:  53 47                  subq.w #$1, d7
  0032d2:  70 07                  moveq #$7, d0
  0032d4:  c0 47                  and.w d7, d0
  0032d6:  d0 40                  add.w d0, d0
  0032d8:  4e fb 00 02            jmp $32dc(pc, d0.w)
  0032dc:  60 0e                  bra.b $32ec
  0032de:  60 16                  bra.b $32f6
  0032e0:  60 1e                  bra.b $3300
  0032e2:  60 2a                  bra.b $330e
  0032e4:  60 36                  bra.b $331c
  0032e6:  60 44                  bra.b $332c
  0032e8:  60 52                  bra.b $333c
  0032ea:  60 62                  bra.b $334e
  0032ec:  30 d3                  move.w (a3), (a0)+
  0032ee:  d6 c3                  adda.w d3, a3
  0032f0:  51 ce ff fa            dbra d6, $32ec
  0032f4:  60 68                  bra.b $335e
  0032f6:  20 d3                  move.l (a3), (a0)+
  0032f8:  d6 c3                  adda.w d3, a3
  0032fa:  51 ce ff fa            dbra d6, $32f6
  0032fe:  60 5e                  bra.b $335e
  003300:  22 4b                  movea.l a3, a1
  003302:  20 d9                  move.l (a1)+, (a0)+
  003304:  30 d9                  move.w (a1)+, (a0)+
  003306:  d6 c3                  adda.w d3, a3
  003308:  51 ce ff f6            dbra d6, $3300
  00330c:  60 50                  bra.b $335e
  00330e:  22 4b                  movea.l a3, a1
  003310:  20 d9                  move.l (a1)+, (a0)+
  003312:  20 d9                  move.l (a1)+, (a0)+
  003314:  d6 c3                  adda.w d3, a3
  003316:  51 ce ff f6            dbra d6, $330e
  00331a:  60 42                  bra.b $335e
  00331c:  22 4b                  movea.l a3, a1
  00331e:  20 d9                  move.l (a1)+, (a0)+
  003320:  20 d9                  move.l (a1)+, (a0)+
  003322:  30 d9                  move.w (a1)+, (a0)+
  003324:  d6 c3                  adda.w d3, a3
  003326:  51 ce ff f4            dbra d6, $331c
  00332a:  60 32                  bra.b $335e
  00332c:  22 4b                  movea.l a3, a1
  00332e:  20 d9                  move.l (a1)+, (a0)+
  003330:  20 d9                  move.l (a1)+, (a0)+
  003332:  20 d9                  move.l (a1)+, (a0)+
  003334:  d6 c3                  adda.w d3, a3
  003336:  51 ce ff f4            dbra d6, $332c
  00333a:  60 22                  bra.b $335e
  00333c:  22 4b                  movea.l a3, a1
  00333e:  20 d9                  move.l (a1)+, (a0)+
  003340:  20 d9                  move.l (a1)+, (a0)+
  003342:  20 d9                  move.l (a1)+, (a0)+
  003344:  30 d9                  move.w (a1)+, (a0)+
  003346:  d6 c3                  adda.w d3, a3
  003348:  51 ce ff f2            dbra d6, $333c
  00334c:  60 10                  bra.b $335e
  00334e:  22 4b                  movea.l a3, a1
  003350:  20 d9                  move.l (a1)+, (a0)+
  003352:  20 d9                  move.l (a1)+, (a0)+
  003354:  20 d9                  move.l (a1)+, (a0)+
  003356:  20 d9                  move.l (a1)+, (a0)+
  003358:  d6 c3                  adda.w d3, a3
  00335a:  51 ce ff f2            dbra d6, $334e
  00335e:  20 0c                  move.l a4, d0
  003360:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003364:  4e 5e                  unlk a6
  003366:  4e 75                  rts 
  003368:  4e 56 00 00            link.w a6, #$0
  00336c:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003370:  20 6e 00 08            movea.l $8(a6), a0
  003374:  38 18                  move.w (a0)+, d4
  003376:  3a 18                  move.w (a0)+, d5
  003378:  3c 18                  move.w (a0)+, d6
  00337a:  3e 18                  move.w (a0)+, d7
  00337c:  9c 44                  sub.w d4, d6
  00337e:  63 00 00 bc            bls.w $343c
  003382:  e8 45                  asr.w #$4, d5
  003384:  06 47 00 0f            addi.w #$f, d7
  003388:  e8 47                  asr.w #$4, d7
  00338a:  9e 45                  sub.w d5, d7
  00338c:  63 00 00 ae            bls.w $343c
  003390:  28 6e 00 0c            movea.l $c(a6), a4
  003394:  20 0c                  move.l a4, d0
  003396:  67 00 00 a4            beq.w $343c
  00339a:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  00339e:  36 2d a2 da            move.w -$5d26(a5), d3
  0033a2:  c9 c3                  muls.w d3, d4
  0033a4:  d7 c4                  adda.l d4, a3
  0033a6:  da 45                  add.w d5, d5
  0033a8:  d6 c5                  adda.w d5, a3
  0033aa:  20 54                  movea.l (a4), a0
  0033ac:  53 46                  subq.w #$1, d6
  0033ae:  53 47                  subq.w #$1, d7
  0033b0:  70 07                  moveq #$7, d0
  0033b2:  c0 47                  and.w d7, d0
  0033b4:  d0 40                  add.w d0, d0
  0033b6:  4e fb 00 02            jmp $33ba(pc, d0.w)
  0033ba:  60 0e                  bra.b $33ca
  0033bc:  60 16                  bra.b $33d4
  0033be:  60 1e                  bra.b $33de
  0033c0:  60 2a                  bra.b $33ec
  0033c2:  60 36                  bra.b $33fa
  0033c4:  60 44                  bra.b $340a
  0033c6:  60 52                  bra.b $341a
  0033c8:  60 62                  bra.b $342c
  0033ca:  36 98                  move.w (a0)+, (a3)
  0033cc:  d6 c3                  adda.w d3, a3
  0033ce:  51 ce ff fa            dbra d6, $33ca
  0033d2:  60 68                  bra.b $343c
  0033d4:  26 98                  move.l (a0)+, (a3)
  0033d6:  d6 c3                  adda.w d3, a3
  0033d8:  51 ce ff fa            dbra d6, $33d4
  0033dc:  60 5e                  bra.b $343c
  0033de:  22 4b                  movea.l a3, a1
  0033e0:  22 d8                  move.l (a0)+, (a1)+
  0033e2:  32 d8                  move.w (a0)+, (a1)+
  0033e4:  d6 c3                  adda.w d3, a3
  0033e6:  51 ce ff f6            dbra d6, $33de
  0033ea:  60 50                  bra.b $343c
  0033ec:  22 4b                  movea.l a3, a1
  0033ee:  22 d8                  move.l (a0)+, (a1)+
  0033f0:  22 d8                  move.l (a0)+, (a1)+
  0033f2:  d6 c3                  adda.w d3, a3
  0033f4:  51 ce ff f6            dbra d6, $33ec
  0033f8:  60 42                  bra.b $343c
  0033fa:  22 4b                  movea.l a3, a1
  0033fc:  22 d8                  move.l (a0)+, (a1)+
  0033fe:  22 d8                  move.l (a0)+, (a1)+
  003400:  32 d8                  move.w (a0)+, (a1)+
  003402:  d6 c3                  adda.w d3, a3
  003404:  51 ce ff f4            dbra d6, $33fa
  003408:  60 32                  bra.b $343c
  00340a:  22 4b                  movea.l a3, a1
  00340c:  22 d8                  move.l (a0)+, (a1)+
  00340e:  22 d8                  move.l (a0)+, (a1)+
  003410:  22 d8                  move.l (a0)+, (a1)+
  003412:  d6 c3                  adda.w d3, a3
  003414:  51 ce ff f4            dbra d6, $340a
  003418:  60 22                  bra.b $343c
  00341a:  22 4b                  movea.l a3, a1
  00341c:  22 d8                  move.l (a0)+, (a1)+
  00341e:  22 d8                  move.l (a0)+, (a1)+
  003420:  22 d8                  move.l (a0)+, (a1)+
  003422:  32 d8                  move.w (a0)+, (a1)+
  003424:  d6 c3                  adda.w d3, a3
  003426:  51 ce ff f2            dbra d6, $341a
  00342a:  60 10                  bra.b $343c
  00342c:  22 4b                  movea.l a3, a1
  00342e:  22 d8                  move.l (a0)+, (a1)+
  003430:  22 d8                  move.l (a0)+, (a1)+
  003432:  22 d8                  move.l (a0)+, (a1)+
  003434:  22 d8                  move.l (a0)+, (a1)+
  003436:  d6 c3                  adda.w d3, a3
  003438:  51 ce ff f2            dbra d6, $342c
  00343c:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003440:  4e 5e                  unlk a6
  003442:  4e 75                  rts 
  003444:  4e 56 00 00            link.w a6, #$0
  003448:  48 e7 3f 38            movem.l d2-d7/a2-a4, -(a7)
  00344c:  32 2e 00 08            move.w $8(a6), d1
  003450:  41 ed a5 7a            lea.l -$5a86(a5), a0
  003454:  20 70 14 00            movea.l (a0, d1.w * 4), a0
  003458:  20 08                  move.l a0, d0
  00345a:  67 00 02 42            beq.w $369e
  00345e:  20 50                  movea.l (a0), a0
  003460:  43 ed a5 9a            lea.l -$5a66(a5), a1
  003464:  22 71 14 00            movea.l (a1, d1.w * 4), a1
  003468:  20 09                  move.l a1, d0
  00346a:  67 00 02 32            beq.w $369e
  00346e:  22 51                  movea.l (a1), a1
  003470:  32 2e 00 0a            move.w $a(a6), d1
  003474:  20 30 14 00            move.l (a0, d1.w * 4), d0
  003478:  6b 00 02 24            bmi.w $369e
  00347c:  49 f1 08 00            lea.l (a1, d0.l), a4
  003480:  30 1c                  move.w (a4)+, d0
  003482:  32 1c                  move.w (a4)+, d1
  003484:  38 1c                  move.w (a4)+, d4
  003486:  3a 1c                  move.w (a4)+, d5
  003488:  3c 2e 00 0c            move.w $c(a6), d6
  00348c:  9c 44                  sub.w d4, d6
  00348e:  4a 6e 00 10            tst.w $10(a6)
  003492:  6a 08                  bpl.b $349c
  003494:  3c 2e 00 0c            move.w $c(a6), d6
  003498:  dc 44                  add.w d4, d6
  00349a:  53 46                  subq.w #$1, d6
  00349c:  3e 2e 00 0e            move.w $e(a6), d7
  0034a0:  9e 45                  sub.w d5, d7
  0034a2:  4a 6d ba 32            tst.w -$45ce(a5)
  0034a6:  67 0c                  beq.b $34b4
  0034a8:  3e 2d a5 d0            move.w -$5a30(a5), d7
  0034ac:  9e 6e 00 0e            sub.w $e(a6), d7
  0034b0:  de 45                  add.w d5, d7
  0034b2:  53 47                  subq.w #$1, d7
  0034b4:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0034b8:  30 2d a2 da            move.w -$5d26(a5), d0
  0034bc:  c1 c7                  muls.w d7, d0
  0034be:  d7 c0                  adda.l d0, a3
  0034c0:  30 06                  move.w d6, d0
  0034c2:  e2 40                  asr.w #$1, d0
  0034c4:  d6 c0                  adda.w d0, a3
  0034c6:  30 2d a2 e6            move.w -$5d1a(a5), d0
  0034ca:  02 40 ff fe            andi.w #$fffe, d0
  0034ce:  9c 40                  sub.w d0, d6
  0034d0:  38 2d a2 ea            move.w -$5d16(a5), d4
  0034d4:  02 44 ff fe            andi.w #$fffe, d4
  0034d8:  98 40                  sub.w d0, d4
  0034da:  30 2d a2 e4            move.w -$5d1c(a5), d0
  0034de:  9e 40                  sub.w d0, d7
  0034e0:  3a 2d a2 e8            move.w -$5d18(a5), d5
  0034e4:  9a 40                  sub.w d0, d5
  0034e6:  45 ed a2 fa            lea.l -$5d06(a5), a2
  0034ea:  22 4f                  movea.l a7, a1
  0034ec:  20 4b                  movea.l a3, a0
  0034ee:  36 06                  move.w d6, d3
  0034f0:  74 00                  moveq #$0, d2
  0034f2:  70 00                  moveq #$0, d0
  0034f4:  10 1c                  move.b (a4)+, d0
  0034f6:  6a 18                  bpl.b $3510
  0034f8:  4a 6d ba 32            tst.w -$45ce(a5)
  0034fc:  67 08                  beq.b $3506
  0034fe:  53 47                  subq.w #$1, d7
  003500:  96 ed a2 da            suba.w -$5d26(a5), a3
  003504:  60 06                  bra.b $350c
  003506:  52 47                  addq.w #$1, d7
  003508:  d6 ed a2 da            adda.w -$5d26(a5), a3
  00350c:  20 4b                  movea.l a3, a0
  00350e:  3c 03                  move.w d3, d6
  003510:  72 1f                  moveq #$1f, d1
  003512:  c2 00                  and.b d0, d1
  003514:  0c 01 00 1f            cmpi.b #$1f, d1
  003518:  66 06                  bne.b $3520
  00351a:  12 1c                  move.b (a4)+, d1
  00351c:  06 41 00 1f            addi.w #$1f, d1
  003520:  52 41                  addq.w #$1, d1
  003522:  d0 00                  add.b d0, d0
  003524:  d0 00                  add.b d0, d0
  003526:  65 00 01 12            bcs.w $363a
  00352a:  6b 7c                  bmi.b $35a8
  00352c:  53 41                  subq.w #$1, d1
  00352e:  67 00 01 6c            beq.w $369c
  003532:  be 45                  cmp.w d5, d7
  003534:  64 6c                  bcc.b $35a2
  003536:  10 1c                  move.b (a4)+, d0
  003538:  10 32 08 00            move.b (a2, d0.l), d0
  00353c:  14 00                  move.b d0, d2
  00353e:  e9 08                  lsl.b #$4, d0
  003540:  4a 6e 00 10            tst.w $10(a6)
  003544:  6b 2c                  bmi.b $3572
  003546:  08 06 00 00            btst.b #$0, d6
  00354a:  66 12                  bne.b $355e
  00354c:  bc 44                  cmp.w d4, d6
  00354e:  64 06                  bcc.b $3556
  003550:  02 10 00 0f            andi.b #$f, (a0)
  003554:  81 10                  or.b d0, (a0)
  003556:  52 46                  addq.w #$1, d6
  003558:  51 c9 00 04            dbra d1, $355e
  00355c:  60 96                  bra.b $34f4
  00355e:  bc 44                  cmp.w d4, d6
  003560:  64 06                  bcc.b $3568
  003562:  02 10 00 f0            andi.b #$f0, (a0)
  003566:  85 10                  or.b d2, (a0)
  003568:  52 48                  addq.w #$1, a0
  00356a:  52 46                  addq.w #$1, d6
  00356c:  51 c9 ff de            dbra d1, $354c
  003570:  60 82                  bra.b $34f4
  003572:  08 06 00 00            btst.b #$0, d6
  003576:  66 16                  bne.b $358e
  003578:  bc 44                  cmp.w d4, d6
  00357a:  64 06                  bcc.b $3582
  00357c:  02 10 00 0f            andi.b #$f, (a0)
  003580:  81 10                  or.b d0, (a0)
  003582:  53 48                  subq.w #$1, a0
  003584:  53 46                  subq.w #$1, d6
  003586:  51 c9 00 06            dbra d1, $358e
  00358a:  60 00 ff 68            bra.w $34f4
  00358e:  bc 44                  cmp.w d4, d6
  003590:  64 06                  bcc.b $3598
  003592:  02 10 00 f0            andi.b #$f0, (a0)
  003596:  85 10                  or.b d2, (a0)
  003598:  53 46                  subq.w #$1, d6
  00359a:  51 c9 ff dc            dbra d1, $3578
  00359e:  60 00 ff 54            bra.w $34f4
  0035a2:  52 8c                  addq.l #$1, a4
  0035a4:  60 00 ff 4e            bra.w $34f4
  0035a8:  53 41                  subq.w #$1, d1
  0035aa:  be 45                  cmp.w d5, d7
  0035ac:  64 00 00 84            bcc.w $3632
  0035b0:  4a 6e 00 10            tst.w $10(a6)
  0035b4:  6b 3e                  bmi.b $35f4
  0035b6:  08 06 00 00            btst.b #$0, d6
  0035ba:  66 1c                  bne.b $35d8
  0035bc:  14 1c                  move.b (a4)+, d2
  0035be:  10 32 28 00            move.b (a2, d2.l), d0
  0035c2:  e9 08                  lsl.b #$4, d0
  0035c4:  bc 44                  cmp.w d4, d6
  0035c6:  64 06                  bcc.b $35ce
  0035c8:  02 10 00 0f            andi.b #$f, (a0)
  0035cc:  81 10                  or.b d0, (a0)
  0035ce:  52 46                  addq.w #$1, d6
  0035d0:  51 c9 00 06            dbra d1, $35d8
  0035d4:  60 00 ff 1e            bra.w $34f4
  0035d8:  14 1c                  move.b (a4)+, d2
  0035da:  10 32 28 00            move.b (a2, d2.l), d0
  0035de:  bc 44                  cmp.w d4, d6
  0035e0:  64 06                  bcc.b $35e8
  0035e2:  02 10 00 f0            andi.b #$f0, (a0)
  0035e6:  81 10                  or.b d0, (a0)
  0035e8:  52 48                  addq.w #$1, a0
  0035ea:  52 46                  addq.w #$1, d6
  0035ec:  51 c9 ff ce            dbra d1, $35bc
  0035f0:  60 00 ff 02            bra.w $34f4
  0035f4:  08 06 00 00            btst.b #$0, d6
  0035f8:  66 1e                  bne.b $3618
  0035fa:  14 1c                  move.b (a4)+, d2
  0035fc:  10 32 28 00            move.b (a2, d2.l), d0
  003600:  e9 08                  lsl.b #$4, d0
  003602:  bc 44                  cmp.w d4, d6
  003604:  64 06                  bcc.b $360c
  003606:  02 10 00 0f            andi.b #$f, (a0)
  00360a:  81 10                  or.b d0, (a0)
  00360c:  53 48                  subq.w #$1, a0
  00360e:  53 46                  subq.w #$1, d6
  003610:  51 c9 00 06            dbra d1, $3618
  003614:  60 00 fe de            bra.w $34f4
  003618:  14 1c                  move.b (a4)+, d2
  00361a:  10 32 28 00            move.b (a2, d2.l), d0
  00361e:  bc 44                  cmp.w d4, d6
  003620:  64 06                  bcc.b $3628
  003622:  02 10 00 f0            andi.b #$f0, (a0)
  003626:  81 10                  or.b d0, (a0)
  003628:  53 46                  subq.w #$1, d6
  00362a:  51 c9 ff ce            dbra d1, $35fa
  00362e:  60 00 fe c4            bra.w $34f4
  003632:  52 41                  addq.w #$1, d1
  003634:  d8 c1                  adda.w d1, a4
  003636:  60 00 fe bc            bra.w $34f4
  00363a:  6b 3e                  bmi.b $367a
  00363c:  4a 6e 00 10            tst.w $10(a6)
  003640:  6b 1c                  bmi.b $365e
  003642:  08 06 00 00            btst.b #$0, d6
  003646:  66 0a                  bne.b $3652
  003648:  dc 41                  add.w d1, d6
  00364a:  e2 41                  asr.w #$1, d1
  00364c:  d0 c1                  adda.w d1, a0
  00364e:  60 00 fe a4            bra.w $34f4
  003652:  dc 41                  add.w d1, d6
  003654:  52 41                  addq.w #$1, d1
  003656:  e2 41                  asr.w #$1, d1
  003658:  d0 c1                  adda.w d1, a0
  00365a:  60 00 fe 98            bra.w $34f4
  00365e:  08 06 00 00            btst.b #$0, d6
  003662:  66 0c                  bne.b $3670
  003664:  9c 41                  sub.w d1, d6
  003666:  52 41                  addq.w #$1, d1
  003668:  e2 41                  asr.w #$1, d1
  00366a:  90 c1                  suba.w d1, a0
  00366c:  60 00 fe 86            bra.w $34f4
  003670:  9c 41                  sub.w d1, d6
  003672:  e2 41                  asr.w #$1, d1
  003674:  90 c1                  suba.w d1, a0
  003676:  60 00 fe 7c            bra.w $34f4
  00367a:  53 41                  subq.w #$1, d1
  00367c:  66 16                  bne.b $3694
  00367e:  bf c9                  cmpa.l a1, a7
  003680:  64 1a                  bcc.b $369c
  003682:  53 57                  subq.w #$1, (a7)
  003684:  6b 08                  bmi.b $368e
  003686:  28 6f 00 02            movea.l $2(a7), a4
  00368a:  60 00 fe 68            bra.w $34f4
  00368e:  5c 8f                  addq.l #$6, a7
  003690:  60 00 fe 62            bra.w $34f4
  003694:  2f 0c                  move.l a4, -(a7)
  003696:  3f 01                  move.w d1, -(a7)
  003698:  60 00 fe 5a            bra.w $34f4
  00369c:  2e 49                  movea.l a1, a7
  00369e:  4c df 1c fc            movem.l (a7)+, d2-d7/a2-a4
  0036a2:  4e 5e                  unlk a6
  0036a4:  4e 75                  rts 
  0036a6:  4e 56 00 00            link.w a6, #$0
  0036aa:  48 e7 1f 10            movem.l d3-d7/a3, -(a7)
  0036ae:  20 6e 00 08            movea.l $8(a6), a0
  0036b2:  38 18                  move.w (a0)+, d4
  0036b4:  3a 18                  move.w (a0)+, d5
  0036b6:  3c 18                  move.w (a0)+, d6
  0036b8:  3e 18                  move.w (a0)+, d7
  0036ba:  9c 44                  sub.w d4, d6
  0036bc:  9e 45                  sub.w d5, d7
  0036be:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0036c2:  36 2d a2 da            move.w -$5d26(a5), d3
  0036c6:  30 03                  move.w d3, d0
  0036c8:  c1 c4                  muls.w d4, d0
  0036ca:  d7 c0                  adda.l d0, a3
  0036cc:  30 05                  move.w d5, d0
  0036ce:  e2 40                  asr.w #$1, d0
  0036d0:  d6 c0                  adda.w d0, a3
  0036d2:  70 00                  moveq #$0, d0
  0036d4:  10 2e 00 0c            move.b $c(a6), d0
  0036d8:  41 ed a2 fa            lea.l -$5d06(a5), a0
  0036dc:  18 30 08 00            move.b (a0, d0.l), d4
  0036e0:  e9 0c                  lsl.b #$4, d4
  0036e2:  88 30 08 00            or.b (a0, d0.l), d4
  0036e6:  70 01                  moveq #$1, d0
  0036e8:  ca 40                  and.w d0, d5
  0036ea:  60 32                  bra.b $371e
  0036ec:  20 4b                  movea.l a3, a0
  0036ee:  32 07                  move.w d7, d1
  0036f0:  4a 45                  tst.w d5
  0036f2:  67 0c                  beq.b $3700
  0036f4:  70 f0                  moveq #$f0, d0
  0036f6:  c1 10                  and.b d0, (a0)
  0036f8:  46 00                  not.b d0
  0036fa:  c0 04                  and.b d4, d0
  0036fc:  81 18                  or.b d0, (a0)+
  0036fe:  53 41                  subq.w #$1, d1
  003700:  e2 41                  asr.w #$1, d1
  003702:  60 02                  bra.b $3706
  003704:  10 c4                  move.b d4, (a0)+
  003706:  51 c9 ff fc            dbra d1, $3704
  00370a:  70 01                  moveq #$1, d0
  00370c:  c0 47                  and.w d7, d0
  00370e:  bb 40                  eor.w d5, d0
  003710:  67 0a                  beq.b $371c
  003712:  70 0f                  moveq #$f, d0
  003714:  c1 10                  and.b d0, (a0)
  003716:  46 00                  not.b d0
  003718:  c0 04                  and.b d4, d0
  00371a:  81 18                  or.b d0, (a0)+
  00371c:  d6 c3                  adda.w d3, a3
  00371e:  51 ce ff cc            dbra d6, $36ec
  003722:  4c df 08 f8            movem.l (a7)+, d3-d7/a3
  003726:  4e 5e                  unlk a6
  003728:  4e 75                  rts 
  00372a:  4e 56 00 00            link.w a6, #$0
  00372e:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003732:  99 cc                  suba.l a4, a4
  003734:  20 6e 00 08            movea.l $8(a6), a0
  003738:  38 18                  move.w (a0)+, d4
  00373a:  3a 18                  move.w (a0)+, d5
  00373c:  3c 18                  move.w (a0)+, d6
  00373e:  3e 18                  move.w (a0)+, d7
  003740:  9c 44                  sub.w d4, d6
  003742:  e4 45                  asr.w #$2, d5
  003744:  56 47                  addq.w #$3, d7
  003746:  e4 47                  asr.w #$2, d7
  003748:  9e 45                  sub.w d5, d7
  00374a:  30 06                  move.w d6, d0
  00374c:  c0 c7                  mulu.w d7, d0
  00374e:  d0 80                  add.l d0, d0
  003750:  a1 22                  dc.w $a122
  003752:  4a 40                  tst.w d0
  003754:  66 2c                  bne.b $3782
  003756:  28 48                  movea.l a0, a4
  003758:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  00375c:  36 2d a2 da            move.w -$5d26(a5), d3
  003760:  30 03                  move.w d3, d0
  003762:  c1 c4                  muls.w d4, d0
  003764:  d7 c0                  adda.l d0, a3
  003766:  30 05                  move.w d5, d0
  003768:  d0 40                  add.w d0, d0
  00376a:  d6 c0                  adda.w d0, a3
  00376c:  20 54                  movea.l (a4), a0
  00376e:  60 0e                  bra.b $377e
  003770:  22 4b                  movea.l a3, a1
  003772:  32 07                  move.w d7, d1
  003774:  60 02                  bra.b $3778
  003776:  30 d9                  move.w (a1)+, (a0)+
  003778:  51 c9 ff fc            dbra d1, $3776
  00377c:  d6 c3                  adda.w d3, a3
  00377e:  51 ce ff f0            dbra d6, $3770
  003782:  20 0c                  move.l a4, d0
  003784:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003788:  4e 5e                  unlk a6
  00378a:  4e 75                  rts 
  00378c:  4e 56 00 00            link.w a6, #$0
  003790:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003794:  20 6e 00 08            movea.l $8(a6), a0
  003798:  38 18                  move.w (a0)+, d4
  00379a:  3a 18                  move.w (a0)+, d5
  00379c:  3c 18                  move.w (a0)+, d6
  00379e:  3e 18                  move.w (a0)+, d7
  0037a0:  9c 44                  sub.w d4, d6
  0037a2:  e4 45                  asr.w #$2, d5
  0037a4:  56 47                  addq.w #$3, d7
  0037a6:  e4 47                  asr.w #$2, d7
  0037a8:  9e 45                  sub.w d5, d7
  0037aa:  28 6e 00 0c            movea.l $c(a6), a4
  0037ae:  20 0c                  move.l a4, d0
  0037b0:  67 2a                  beq.b $37dc
  0037b2:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0037b6:  36 2d a2 da            move.w -$5d26(a5), d3
  0037ba:  30 03                  move.w d3, d0
  0037bc:  c1 c4                  muls.w d4, d0
  0037be:  d7 c0                  adda.l d0, a3
  0037c0:  30 05                  move.w d5, d0
  0037c2:  d0 40                  add.w d0, d0
  0037c4:  d6 c0                  adda.w d0, a3
  0037c6:  20 54                  movea.l (a4), a0
  0037c8:  60 0e                  bra.b $37d8
  0037ca:  22 4b                  movea.l a3, a1
  0037cc:  32 07                  move.w d7, d1
  0037ce:  60 02                  bra.b $37d2
  0037d0:  32 d8                  move.w (a0)+, (a1)+
  0037d2:  51 c9 ff fc            dbra d1, $37d0
  0037d6:  d6 c3                  adda.w d3, a3
  0037d8:  51 ce ff f0            dbra d6, $37ca
  0037dc:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  0037e0:  4e 5e                  unlk a6
  0037e2:  4e 75                  rts 
  0037e4:  4e 56 00 00            link.w a6, #$0
  0037e8:  48 e7 3f 38            movem.l d2-d7/a2-a4, -(a7)
  0037ec:  32 2e 00 08            move.w $8(a6), d1
  0037f0:  41 ed a5 7a            lea.l -$5a86(a5), a0
  0037f4:  20 70 14 00            movea.l (a0, d1.w * 4), a0
  0037f8:  20 08                  move.l a0, d0
  0037fa:  67 00 01 40            beq.w $393c
  0037fe:  20 50                  movea.l (a0), a0
  003800:  43 ed a5 9a            lea.l -$5a66(a5), a1
  003804:  22 71 14 00            movea.l (a1, d1.w * 4), a1
  003808:  20 09                  move.l a1, d0
  00380a:  67 00 01 30            beq.w $393c
  00380e:  22 51                  movea.l (a1), a1
  003810:  32 2e 00 0a            move.w $a(a6), d1
  003814:  20 30 14 00            move.l (a0, d1.w * 4), d0
  003818:  6b 00 01 22            bmi.w $393c
  00381c:  49 f1 08 00            lea.l (a1, d0.l), a4
  003820:  30 1c                  move.w (a4)+, d0
  003822:  32 1c                  move.w (a4)+, d1
  003824:  38 1c                  move.w (a4)+, d4
  003826:  3a 1c                  move.w (a4)+, d5
  003828:  3c 2e 00 0c            move.w $c(a6), d6
  00382c:  9c 44                  sub.w d4, d6
  00382e:  4a 6e 00 10            tst.w $10(a6)
  003832:  6a 08                  bpl.b $383c
  003834:  3c 2e 00 0c            move.w $c(a6), d6
  003838:  dc 44                  add.w d4, d6
  00383a:  53 46                  subq.w #$1, d6
  00383c:  3e 2e 00 0e            move.w $e(a6), d7
  003840:  9e 45                  sub.w d5, d7
  003842:  4a 6d ba 32            tst.w -$45ce(a5)
  003846:  67 0c                  beq.b $3854
  003848:  3e 2d a5 d0            move.w -$5a30(a5), d7
  00384c:  9e 6e 00 0e            sub.w $e(a6), d7
  003850:  de 45                  add.w d5, d7
  003852:  53 47                  subq.w #$1, d7
  003854:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003858:  30 2d a2 da            move.w -$5d26(a5), d0
  00385c:  c1 c7                  muls.w d7, d0
  00385e:  d7 c0                  adda.l d0, a3
  003860:  d6 c6                  adda.w d6, a3
  003862:  30 2d a2 e6            move.w -$5d1a(a5), d0
  003866:  9c 40                  sub.w d0, d6
  003868:  38 2d a2 ea            move.w -$5d16(a5), d4
  00386c:  98 40                  sub.w d0, d4
  00386e:  30 2d a2 e4            move.w -$5d1c(a5), d0
  003872:  9e 40                  sub.w d0, d7
  003874:  3a 2d a2 e8            move.w -$5d18(a5), d5
  003878:  9a 40                  sub.w d0, d5
  00387a:  45 ed a2 fa            lea.l -$5d06(a5), a2
  00387e:  22 4f                  movea.l a7, a1
  003880:  20 4b                  movea.l a3, a0
  003882:  36 06                  move.w d6, d3
  003884:  34 2e 00 10            move.w $10(a6), d2
  003888:  70 00                  moveq #$0, d0
  00388a:  10 1c                  move.b (a4)+, d0
  00388c:  6a 18                  bpl.b $38a6
  00388e:  4a 6d ba 32            tst.w -$45ce(a5)
  003892:  67 08                  beq.b $389c
  003894:  53 47                  subq.w #$1, d7
  003896:  96 ed a2 da            suba.w -$5d26(a5), a3
  00389a:  60 06                  bra.b $38a2
  00389c:  52 47                  addq.w #$1, d7
  00389e:  d6 ed a2 da            adda.w -$5d26(a5), a3
  0038a2:  20 4b                  movea.l a3, a0
  0038a4:  3c 03                  move.w d3, d6
  0038a6:  72 1f                  moveq #$1f, d1
  0038a8:  c2 00                  and.b d0, d1
  0038aa:  0c 01 00 1f            cmpi.b #$1f, d1
  0038ae:  66 06                  bne.b $38b6
  0038b0:  12 1c                  move.b (a4)+, d1
  0038b2:  06 41 00 1f            addi.w #$1f, d1
  0038b6:  52 41                  addq.w #$1, d1
  0038b8:  d0 00                  add.b d0, d0
  0038ba:  d0 00                  add.b d0, d0
  0038bc:  65 44                  bcs.b $3902
  0038be:  6b 22                  bmi.b $38e2
  0038c0:  53 41                  subq.w #$1, d1
  0038c2:  67 76                  beq.b $393a
  0038c4:  be 45                  cmp.w d5, d7
  0038c6:  64 16                  bcc.b $38de
  0038c8:  10 1c                  move.b (a4)+, d0
  0038ca:  10 32 08 00            move.b (a2, d0.l), d0
  0038ce:  bc 44                  cmp.w d4, d6
  0038d0:  64 02                  bcc.b $38d4
  0038d2:  10 80                  move.b d0, (a0)
  0038d4:  d0 c2                  adda.w d2, a0
  0038d6:  dc 42                  add.w d2, d6
  0038d8:  51 c9 ff f4            dbra d1, $38ce
  0038dc:  60 ac                  bra.b $388a
  0038de:  52 4c                  addq.w #$1, a4
  0038e0:  60 a8                  bra.b $388a
  0038e2:  53 41                  subq.w #$1, d1
  0038e4:  be 45                  cmp.w d5, d7
  0038e6:  64 14                  bcc.b $38fc
  0038e8:  10 1c                  move.b (a4)+, d0
  0038ea:  bc 44                  cmp.w d4, d6
  0038ec:  64 04                  bcc.b $38f2
  0038ee:  10 b2 08 00            move.b (a2, d0.l), (a0)
  0038f2:  d0 c2                  adda.w d2, a0
  0038f4:  dc 42                  add.w d2, d6
  0038f6:  51 c9 ff f0            dbra d1, $38e8
  0038fa:  60 8e                  bra.b $388a
  0038fc:  d8 c1                  adda.w d1, a4
  0038fe:  52 4c                  addq.w #$1, a4
  003900:  60 88                  bra.b $388a
  003902:  6b 14                  bmi.b $3918
  003904:  4a 42                  tst.w d2
  003906:  6b 08                  bmi.b $3910
  003908:  dc 41                  add.w d1, d6
  00390a:  d0 c1                  adda.w d1, a0
  00390c:  60 00 ff 7c            bra.w $388a
  003910:  9c 41                  sub.w d1, d6
  003912:  90 c1                  suba.w d1, a0
  003914:  60 00 ff 74            bra.w $388a
  003918:  53 41                  subq.w #$1, d1
  00391a:  66 16                  bne.b $3932
  00391c:  bf c9                  cmpa.l a1, a7
  00391e:  64 1a                  bcc.b $393a
  003920:  53 57                  subq.w #$1, (a7)
  003922:  6b 08                  bmi.b $392c
  003924:  28 6f 00 02            movea.l $2(a7), a4
  003928:  60 00 ff 60            bra.w $388a
  00392c:  5c 8f                  addq.l #$6, a7
  00392e:  60 00 ff 5a            bra.w $388a
  003932:  2f 0c                  move.l a4, -(a7)
  003934:  3f 01                  move.w d1, -(a7)
  003936:  60 00 ff 52            bra.w $388a
  00393a:  2e 49                  movea.l a1, a7
  00393c:  4c df 1c fc            movem.l (a7)+, d2-d7/a2-a4
  003940:  4e 5e                  unlk a6
  003942:  4e 75                  rts 
  003944:  4e 56 00 00            link.w a6, #$0
  003948:  48 e7 1f 10            movem.l d3-d7/a3, -(a7)
  00394c:  20 6e 00 08            movea.l $8(a6), a0
  003950:  38 18                  move.w (a0)+, d4
  003952:  3a 18                  move.w (a0)+, d5
  003954:  3c 18                  move.w (a0)+, d6
  003956:  3e 18                  move.w (a0)+, d7
  003958:  9c 44                  sub.w d4, d6
  00395a:  9e 45                  sub.w d5, d7
  00395c:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003960:  36 2d a2 da            move.w -$5d26(a5), d3
  003964:  30 03                  move.w d3, d0
  003966:  c1 c4                  muls.w d4, d0
  003968:  d7 c0                  adda.l d0, a3
  00396a:  d6 c5                  adda.w d5, a3
  00396c:  70 00                  moveq #$0, d0
  00396e:  10 2e 00 0c            move.b $c(a6), d0
  003972:  41 ed a2 fa            lea.l -$5d06(a5), a0
  003976:  18 30 08 00            move.b (a0, d0.l), d4
  00397a:  60 0e                  bra.b $398a
  00397c:  20 4b                  movea.l a3, a0
  00397e:  30 07                  move.w d7, d0
  003980:  60 02                  bra.b $3984
  003982:  10 c4                  move.b d4, (a0)+
  003984:  51 c8 ff fc            dbra d0, $3982
  003988:  d6 c3                  adda.w d3, a3
  00398a:  51 ce ff f0            dbra d6, $397c
  00398e:  4c df 08 f8            movem.l (a7)+, d3-d7/a3
  003992:  4e 5e                  unlk a6
  003994:  4e 75                  rts 
  003996:  4e 56 00 00            link.w a6, #$0
  00399a:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  00399e:  99 cc                  suba.l a4, a4
  0039a0:  20 6e 00 08            movea.l $8(a6), a0
  0039a4:  38 18                  move.w (a0)+, d4
  0039a6:  3a 18                  move.w (a0)+, d5
  0039a8:  3c 18                  move.w (a0)+, d6
  0039aa:  3e 18                  move.w (a0)+, d7
  0039ac:  9c 44                  sub.w d4, d6
  0039ae:  e2 45                  asr.w #$1, d5
  0039b0:  52 47                  addq.w #$1, d7
  0039b2:  e2 47                  asr.w #$1, d7
  0039b4:  9e 45                  sub.w d5, d7
  0039b6:  30 06                  move.w d6, d0
  0039b8:  c0 c7                  mulu.w d7, d0
  0039ba:  d0 80                  add.l d0, d0
  0039bc:  a1 22                  dc.w $a122
  0039be:  4a 40                  tst.w d0
  0039c0:  66 2c                  bne.b $39ee
  0039c2:  28 48                  movea.l a0, a4
  0039c4:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  0039c8:  36 2d a2 da            move.w -$5d26(a5), d3
  0039cc:  30 03                  move.w d3, d0
  0039ce:  c1 c4                  muls.w d4, d0
  0039d0:  d7 c0                  adda.l d0, a3
  0039d2:  30 05                  move.w d5, d0
  0039d4:  d0 40                  add.w d0, d0
  0039d6:  d6 c0                  adda.w d0, a3
  0039d8:  20 54                  movea.l (a4), a0
  0039da:  60 0e                  bra.b $39ea
  0039dc:  22 4b                  movea.l a3, a1
  0039de:  32 07                  move.w d7, d1
  0039e0:  60 02                  bra.b $39e4
  0039e2:  30 d9                  move.w (a1)+, (a0)+
  0039e4:  51 c9 ff fc            dbra d1, $39e2
  0039e8:  d6 c3                  adda.w d3, a3
  0039ea:  51 ce ff f0            dbra d6, $39dc
  0039ee:  20 0c                  move.l a4, d0
  0039f0:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  0039f4:  4e 5e                  unlk a6
  0039f6:  4e 75                  rts 
  0039f8:  4e 56 00 00            link.w a6, #$0
  0039fc:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  003a00:  20 6e 00 08            movea.l $8(a6), a0
  003a04:  38 18                  move.w (a0)+, d4
  003a06:  3a 18                  move.w (a0)+, d5
  003a08:  3c 18                  move.w (a0)+, d6
  003a0a:  3e 18                  move.w (a0)+, d7
  003a0c:  9c 44                  sub.w d4, d6
  003a0e:  e2 45                  asr.w #$1, d5
  003a10:  52 47                  addq.w #$1, d7
  003a12:  e2 47                  asr.w #$1, d7
  003a14:  9e 45                  sub.w d5, d7
  003a16:  28 6e 00 0c            movea.l $c(a6), a4
  003a1a:  20 0c                  move.l a4, d0
  003a1c:  67 2a                  beq.b $3a48
  003a1e:  26 6d a2 d2            movea.l -$5d2e(a5), a3
  003a22:  36 2d a2 da            move.w -$5d26(a5), d3
  003a26:  30 03                  move.w d3, d0
  003a28:  c1 c4                  muls.w d4, d0
  003a2a:  d7 c0                  adda.l d0, a3
  003a2c:  30 05                  move.w d5, d0
  003a2e:  d0 40                  add.w d0, d0
  003a30:  d6 c0                  adda.w d0, a3
  003a32:  20 54                  movea.l (a4), a0
  003a34:  60 0e                  bra.b $3a44
  003a36:  22 4b                  movea.l a3, a1
  003a38:  32 07                  move.w d7, d1
  003a3a:  60 02                  bra.b $3a3e
  003a3c:  32 d8                  move.w (a0)+, (a1)+
  003a3e:  51 c9 ff fc            dbra d1, $3a3c
  003a42:  d6 c3                  adda.w d3, a3
  003a44:  51 ce ff f0            dbra d6, $3a36
  003a48:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  003a4c:  4e 5e                  unlk a6
  003a4e:  4e 75                  rts 
  003a50:  4a 78 02 8e            tst.w $28e.w
  003a54:  6b 22                  bmi.b $3a78
  003a56:  30 3c 00 90            move.w #$90, d0
  003a5a:  a3 46                  dc.w $a346
  003a5c:  22 48                  movea.l a0, a1
  003a5e:  30 3c 00 9f            move.w #$9f, d0
  003a62:  a7 46                  dc.w $a746
  003a64:  b3 c8                  cmpa.l a0, a1
  003a66:  67 10                  beq.b $3a78
  003a68:  22 5f                  movea.l (a7)+, a1
  003a6a:  20 5f                  movea.l (a7)+, a0
  003a6c:  30 1f                  move.w (a7)+, d0
  003a6e:  2f 09                  move.l a1, -(a7)
  003a70:  a0 90                  dc.w $a090
  003a72:  3f 40 00 04            move.w d0, $4(a7)
  003a76:  4e 75                  rts 
  003a78:  20 6f 00 04            movea.l $4(a7), a0
  003a7c:  30 3c 00 01            move.w #$1, d0
  003a80:  22 48                  movea.l a0, a1
  003a82:  60 06                  bra.b $3a8a
  003a84:  03 13                  btst.l d1, (a3)
  003a86:  0b 02                  btst.l d5, d2
  003a88:  01 00                  btst.l d0, d0
  003a8a:  30 3c 00 10            move.w #$10, d0
  003a8e:  e2 40                  asr.w #$1, d0
  003a90:  53 40                  subq.w #$1, d0
  003a92:  42 58                  clr.w (a0)+
  003a94:  51 c8 ff fc            dbra d0, $3a92
  003a98:  32 bc 00 01            move.w #$1, (a1)
  003a9c:  20 78 02 ae            movea.l $2ae.w, a0
  003aa0:  33 7c ff fe 00 02      move.w #$fffe, $2(a1)
  003aa6:  0c 28 00 ff 00 09      cmpi.b #$ff, $9(a0)
  003aac:  67 42                  beq.b $3af0
  003aae:  4a 28 00 08            tst.b $8(a0)
  003ab2:  6e 20                  bgt.b $3ad4
  003ab4:  33 7c ff ff 00 02      move.w #$ffff, $2(a1)
  003aba:  4a 78 02 8e            tst.w $28e.w
  003abe:  6b 30                  bmi.b $3af0
  003ac0:  33 7c 00 01 00 02      move.w #$1, $2(a1)
  003ac6:  4a 78 0b 22            tst.w $b22.w
  003aca:  6a 24                  bpl.b $3af0
  003acc:  33 7c 00 02 00 02      move.w #$2, $2(a1)
  003ad2:  60 1c                  bra.b $3af0
  003ad4:  42 69 00 02            clr.w $2(a1)
  003ad8:  0c 28 00 02 00 08      cmpi.b #$2, $8(a0)
  003ade:  6e 10                  bgt.b $3af0
  003ae0:  67 08                  beq.b $3aea
  003ae2:  33 7c 00 04 00 02      move.w #$4, $2(a1)
  003ae8:  60 06                  bra.b $3af0
  003aea:  33 7c 00 03 00 02      move.w #$3, $2(a1)
  003af0:  42 69 00 04            clr.w $4(a1)
  003af4:  0c 38 00 02 01 2f      cmpi.b #$2, $12f.w
  003afa:  6e 0a                  bgt.b $3b06
  003afc:  10 38 01 2f            move.b $12f.w, d0
  003b00:  52 40                  addq.w #$1, d0
  003b02:  13 40 00 07            move.b d0, $7(a1)
  003b06:  4a 78 02 8e            tst.w $28e.w
  003b0a:  6b 0e                  bmi.b $3b1a
  003b0c:  08 38 00 04 0b 22      btst.b #$4, $b22.w
  003b12:  67 06                  beq.b $3b1a
  003b14:  13 7c 00 01 00 08      move.b #$1, $8(a1)
  003b1a:  0c 78 3f ff 02 8e      cmpi.w #$3fff, $28e.w
  003b20:  62 06                  bhi.b $3b28
  003b22:  13 7c 00 01 00 09      move.b #$1, $9(a1)
  003b28:  10 38 02 1e            move.b $21e.w, d0
  003b2c:  41 fa ff 5b            lea.l $3a89(pc), a0
  003b30:  32 3c 00 04            move.w #$4, d1
  003b34:  b0 20                  cmp.b -(a0), d0
  003b36:  57 c9 ff fc            dbeq d1, $3b34
  003b3a:  52 41                  addq.w #$1, d1
  003b3c:  33 41 00 0a            move.w d1, $a(a1)
  003b40:  4a 38 02 91            tst.b $291.w
  003b44:  6b 18                  bmi.b $3b5e
  003b46:  12 38 01 fb            move.b $1fb.w, d1
  003b4a:  02 01 00 0f            andi.b #$f, d1
  003b4e:  0c 01 00 01            cmpi.b #$1, d1
  003b52:  66 0a                  bne.b $3b5e
  003b54:  20 78 02 dc            movea.l $2dc.w, a0
  003b58:  13 68 00 07 00 0d      move.b $7(a0), $d(a1)
  003b5e:  33 78 02 10 00 0e      move.w $210.w, $e(a1)
  003b64:  4a 78 03 f6            tst.w $3f6.w
  003b68:  6d 44                  blt.b $3bae
  003b6a:  42 69 00 0e            clr.w $e(a1)
  003b6e:  32 3c 00 3c            move.w #$3c, d1
  003b72:  42 67                  clr.w -(a7)
  003b74:  51 c9 ff fc            dbra d1, $3b72
  003b78:  20 4f                  movea.l a7, a0
  003b7a:  31 78 0a 58 00 18      move.w $a58.w, $18(a0)
  003b80:  70 08                  moveq #$8, d0
  003b82:  a2 60                  dc.w $a260
  003b84:  66 24                  bne.b $3baa
  003b86:  31 68 00 34 00 16      move.w $34(a0), $16(a0)
  003b8c:  a2 07                  dc.w $a207
  003b8e:  66 1a                  bne.b $3baa
  003b90:  21 68 00 5a 00 30      move.l $5a(a0), $30(a0)
  003b96:  21 7c 45 52 49 4b 00 1c move.l #$4552494b, $1c(a0)
  003b9e:  70 01                  moveq #$1, d0
  003ba0:  a2 60                  dc.w $a260
  003ba2:  66 06                  bne.b $3baa
  003ba4:  33 68 00 16 00 0e      move.w $16(a0), $e(a1)
  003baa:  4f ef 00 7a            lea.l $7a(a7), a7
  003bae:  20 49                  movea.l a1, a0
  003bb0:  22 5f                  movea.l (a7)+, a1
  003bb2:  5c 4f                  addq.w #$6, a7
  003bb4:  3e bc ea 84            move.w #$ea84, (a7)
  003bb8:  4e d1                  jmp (a1)
  003bba:  22 5f                  movea.l (a7)+, a1
  003bbc:  20 5f                  movea.l (a7)+, a0
  003bbe:  a0 25                  dc.w $a025
  003bc0:  2e 80                  move.l d0, (a7)
  003bc2:  6a 02                  bpl.b $3bc6
  003bc4:  42 97                  clr.l (a7)
  003bc6:  4e d1                  jmp (a1)
  003bc8:  22 5f                  movea.l (a7)+, a1
  003bca:  12 1f                  move.b (a7)+, d1
  003bcc:  30 1f                  move.w (a7)+, d0
  003bce:  4a 01                  tst.b d1
  003bd0:  67 04                  beq.b $3bd6
  003bd2:  a7 46                  dc.w $a746
  003bd4:  60 02                  bra.b $3bd8
  003bd6:  a3 46                  dc.w $a346
  003bd8:  2e 88                  move.l a0, (a7)
  003bda:  4e d1                  jmp (a1)
  003bdc:  22 5f                  movea.l (a7)+, a1
  003bde:  12 1f                  move.b (a7)+, d1
  003be0:  20 5f                  movea.l (a7)+, a0
  003be2:  70 00                  moveq #$0, d0
  003be4:  10 18                  move.b (a0)+, d0
  003be6:  2f 09                  move.l a1, -(a7)
  003be8:  4a 01                  tst.b d1
  003bea:  67 04                  beq.b $3bf0
  003bec:  a0 54                  dc.w $a054
  003bee:  60 02                  bra.b $3bf2
  003bf0:  a2 54                  dc.w $a254
  003bf2:  4e 75                  rts 
  003bf4:  22 5f                  movea.l (a7)+, a1
  003bf6:  10 1f                  move.b (a7)+, d0
  003bf8:  20 5f                  movea.l (a7)+, a0
  003bfa:  66 04                  bne.b $3c00
  003bfc:  a0 03                  dc.w $a003
  003bfe:  60 02                  bra.b $3c02
  003c00:  a4 03                  dc.w $a403
  003c02:  3e 80                  move.w d0, (a7)
  003c04:  4e d1                  jmp (a1)
  003c06:  22 5f                  movea.l (a7)+, a1
  003c08:  10 1f                  move.b (a7)+, d0
  003c0a:  20 5f                  movea.l (a7)+, a0
  003c0c:  66 04                  bne.b $3c12
  003c0e:  a0 06                  dc.w $a006
  003c10:  60 02                  bra.b $3c14
  003c12:  a4 06                  dc.w $a406
  003c14:  3e 80                  move.w d0, (a7)
  003c16:  4e d1                  jmp (a1)
  003c18:  4e 56 ff ce            link.w a6, #$ffce
  003c1c:  20 4f                  movea.l a7, a0
  003c1e:  21 6e 00 0e 00 12      move.l $e(a6), $12(a0)
  003c24:  31 6e 00 0c 00 16      move.w $c(a6), $16(a0)
  003c2a:  42 28 00 1a            clr.b $1a(a0)
  003c2e:  42 28 00 1b            clr.b $1b(a0)
  003c32:  42 a8 00 1c            clr.l $1c(a0)
  003c36:  70 1a                  moveq #$1a, d0
  003c38:  a0 60                  dc.w $a060
  003c3a:  0c 40 ff ce            cmpi.w #$ffce, d0
  003c3e:  66 02                  bne.b $3c42
  003c40:  a0 00                  dc.w $a000
  003c42:  22 6e 00 08            movea.l $8(a6), a1
  003c46:  32 a8 00 18            move.w $18(a0), (a1)
  003c4a:  3d 40 00 12            move.w d0, $12(a6)
  003c4e:  4e 5e                  unlk a6
  003c50:  20 5f                  movea.l (a7)+, a0
  003c52:  4f ef 00 0a            lea.l $a(a7), a7
  003c56:  4e d0                  jmp (a0)
  003c58:  4e 56 ff ce            link.w a6, #$ffce
  003c5c:  20 4f                  movea.l a7, a0
  003c5e:  31 6e 00 08 00 18      move.w $8(a6), $18(a0)
  003c64:  a0 01                  dc.w $a001
  003c66:  3d 40 00 0a            move.w d0, $a(a6)
  003c6a:  4e 5e                  unlk a6
  003c6c:  20 5f                  movea.l (a7)+, a0
  003c6e:  54 8f                  addq.l #$2, a7
  003c70:  4e d0                  jmp (a0)
  003c72:  51 c1                  sf.b d1
  003c74:  60 02                  bra.b $3c78
  003c76:  50 c1                  st.b d1
  003c78:  4e 56 ff ce            link.w a6, #$ffce
  003c7c:  20 4f                  movea.l a7, a0
  003c7e:  21 6e 00 08 00 20      move.l $8(a6), $20(a0)
  003c84:  31 6e 00 10 00 18      move.w $10(a6), $18(a0)
  003c8a:  22 6e 00 0c            movea.l $c(a6), a1
  003c8e:  21 51 00 24            move.l (a1), $24(a0)
  003c92:  42 68 00 2c            clr.w $2c(a0)
  003c96:  42 a8 00 2e            clr.l $2e(a0)
  003c9a:  4a 01                  tst.b d1
  003c9c:  66 04                  bne.b $3ca2
  003c9e:  a0 02                  dc.w $a002
  003ca0:  60 02                  bra.b $3ca4
  003ca2:  a0 03                  dc.w $a003
  003ca4:  3d 40 00 12            move.w d0, $12(a6)
  003ca8:  22 6e 00 0c            movea.l $c(a6), a1
  003cac:  22 a8 00 28            move.l $28(a0), (a1)
  003cb0:  4e 5e                  unlk a6
  003cb2:  22 5f                  movea.l (a7)+, a1
  003cb4:  4f ef 00 0a            lea.l $a(a7), a7
  003cb8:  4e d1                  jmp (a1)
  003cba:  4e 56 ff b0            link.w a6, #$ffb0
  003cbe:  20 4f                  movea.l a7, a0
  003cc0:  21 6e 00 0e 00 12      move.l $e(a6), $12(a0)
  003cc6:  31 6e 00 0c 00 16      move.w $c(a6), $16(a0)
  003ccc:  42 28 00 1a            clr.b $1a(a0)
  003cd0:  42 68 00 1c            clr.w $1c(a0)
  003cd4:  a0 0c                  dc.w $a00c
  003cd6:  3d 40 00 12            move.w d0, $12(a6)
  003cda:  41 e8 00 20            lea.l $20(a0), a0
  003cde:  22 6e 00 08            movea.l $8(a6), a1
  003ce2:  70 10                  moveq #$10, d0
  003ce4:  a0 2e                  dc.w $a02e
  003ce6:  4e 5e                  unlk a6
  003ce8:  22 5f                  movea.l (a7)+, a1
  003cea:  4f ef 00 0a            lea.l $a(a7), a7
  003cee:  4e d1                  jmp (a1)
  003cf0:  4e 56 ff c0            link.w a6, #$ffc0
  003cf4:  20 4f                  movea.l a7, a0
  003cf6:  21 6e 00 0c 00 12      move.l $c(a6), $12(a0)
  003cfc:  a0 14                  dc.w $a014
  003cfe:  3d 40 00 10            move.w d0, $10(a6)
  003d02:  22 6e 00 08            movea.l $8(a6), a1
  003d06:  32 a8 00 16            move.w $16(a0), (a1)
  003d0a:  4e 5e                  unlk a6
  003d0c:  22 5f                  movea.l (a7)+, a1
  003d0e:  50 8f                  addq.l #$8, a7
  003d10:  4e d1                  jmp (a1)
  003d12:  4e 56 ff ce            link.w a6, #$ffce
  003d16:  20 4f                  movea.l a7, a0
  003d18:  31 6e 00 0e 00 18      move.w $e(a6), $18(a0)
  003d1e:  31 6e 00 0c 00 2c      move.w $c(a6), $2c(a0)
  003d24:  21 6e 00 08 00 2e      move.l $8(a6), $2e(a0)
  003d2a:  a0 44                  dc.w $a044
  003d2c:  3d 40 00 10            move.w d0, $10(a6)
  003d30:  4e 5e                  unlk a6
  003d32:  22 5f                  movea.l (a7)+, a1
  003d34:  50 8f                  addq.l #$8, a7
  003d36:  4e d1                  jmp (a1)
  003d38:  22 6f 00 04            movea.l $4(a7), a1
  003d3c:  42 51                  clr.w (a1)
  003d3e:  20 78 0a ec            movea.l $aec.w, a0
  003d42:  a0 25                  dc.w $a025
  003d44:  4a 80                  tst.l d0
  003d46:  6f 0e                  ble.b $3d56
  003d48:  20 50                  movea.l (a0), a0
  003d4a:  22 6f 00 08            movea.l $8(a7), a1
  003d4e:  32 98                  move.w (a0)+, (a1)
  003d50:  22 6f 00 04            movea.l $4(a7), a1
  003d54:  32 90                  move.w (a0), (a1)
  003d56:  20 5f                  movea.l (a7)+, a0
  003d58:  50 4f                  addq.w #$8, a7
  003d5a:  4e d0                  jmp (a0)
  003d5c:  48 e7 00 30            movem.l a2-a3, -(a7)
  003d60:  22 6f 00 0c            movea.l $c(a7), a1
  003d64:  42 a9 00 02            clr.l $2(a1)
  003d68:  20 78 0a ec            movea.l $aec.w, a0
  003d6c:  a0 25                  dc.w $a025
  003d6e:  4a 80                  tst.l d0
  003d70:  6f 26                  ble.b $3d98
  003d72:  24 50                  movea.l (a0), a2
  003d74:  54 4a                  addq.w #$2, a2
  003d76:  32 2f 00 10            move.w $10(a7), d1
  003d7a:  b2 5a                  cmp.w (a2)+, d1
  003d7c:  6e 1a                  bgt.b $3d98
  003d7e:  53 41                  subq.w #$1, d1
  003d80:  6d 16                  blt.b $3d98
  003d82:  20 4a                  movea.l a2, a0
  003d84:  70 02                  moveq #$2, d0
  003d86:  d0 28 00 08            add.b $8(a0), d0
  003d8a:  02 40 ff fe            andi.w #$fffe, d0
  003d8e:  50 40                  addq.w #$8, d0
  003d90:  d4 c0                  adda.w d0, a2
  003d92:  a0 2e                  dc.w $a02e
  003d94:  53 41                  subq.w #$1, d1
  003d96:  60 e8                  bra.b $3d80
  003d98:  4c df 0c 00            movem.l (a7)+, a2-a3
  003d9c:  20 5f                  movea.l (a7)+, a0
  003d9e:  5c 4f                  addq.w #$6, a7
  003da0:  4e d0                  jmp (a0)
  003da2:  20 78 0a ec            movea.l $aec.w, a0
  003da6:  a0 25                  dc.w $a025
  003da8:  4a 80                  tst.l d0
  003daa:  6f 28                  ble.b $3dd4
  003dac:  20 50                  movea.l (a0), a0
  003dae:  54 48                  addq.w #$2, a0
  003db0:  32 2f 00 04            move.w $4(a7), d1
  003db4:  b2 58                  cmp.w (a0)+, d1
  003db6:  6e 1c                  bgt.b $3dd4
  003db8:  53 41                  subq.w #$1, d1
  003dba:  6d 18                  blt.b $3dd4
  003dbc:  67 12                  beq.b $3dd0
  003dbe:  70 02                  moveq #$2, d0
  003dc0:  d0 28 00 08            add.b $8(a0), d0
  003dc4:  02 40 ff fe            andi.w #$fffe, d0
  003dc8:  50 40                  addq.w #$8, d0
  003dca:  d0 c0                  adda.w d0, a0
  003dcc:  53 41                  subq.w #$1, d1
  003dce:  60 ea                  bra.b $3dba
  003dd0:  42 a8 00 02            clr.l $2(a0)
  003dd4:  20 5f                  movea.l (a7)+, a0
  003dd6:  54 4f                  addq.w #$2, a7
  003dd8:  4e d0                  jmp (a0)
  003dda:  20 6f 00 04            movea.l $4(a7), a0
  003dde:  20 2f 00 08            move.l $8(a7), d0
  003de2:  42 67                  clr.w -(a7)
  003de4:  a9 ee                  dc.w $a9ee
  003de6:  20 5f                  movea.l (a7)+, a0
  003de8:  50 4f                  addq.w #$8, a7
  003dea:  4e d0                  jmp (a0)
  003dec:  22 5f                  movea.l (a7)+, a1
  003dee:  20 1f                  move.l (a7)+, d0
  003df0:  08 38 00 06 02 8e      btst.b #$6, $28e.w
  003df6:  66 06                  bne.b $3dfe
  003df8:  a0 55                  dc.w $a055
  003dfa:  2e 80                  move.l d0, (a7)
  003dfc:  4e d1                  jmp (a1)
  003dfe:  c0 b8 03 1a            and.l $31a.w, d0
  003e02:  2e 80                  move.l d0, (a7)
  003e04:  4e d1                  jmp (a1)
  003e06:  4e 56 ff f0            link.w a6, #$fff0
  003e0a:  2f 07                  move.l d7, -(a7)
  003e0c:  42 2d a7 7e            clr.b -$5882(a5)
  003e10:  7e 01                  moveq #$1, d7
  003e12:  42 67                  clr.w -(a7)
  003e14:  3f 3c 00 01            move.w #$1, -(a7)
  003e18:  48 6e ff f0            pea.l -$10(a6)
  003e1c:  4e ba fc 32            jsr $3a50(pc)
  003e20:  4a 5f                  tst.w (a7)+
  003e22:  66 04                  bne.b $3e28
  003e24:  3e 2e ff f4            move.w -$c(a6), d7
  003e28:  0c 47 06 00            cmpi.w #$600, d7
  003e2c:  65 3a                  bcs.b $3e68
  003e2e:  1b 7c 00 01 a7 7e      move.b #$1, -$5882(a5)
  003e34:  7e 00                  moveq #$0, d7
  003e36:  60 2a                  bra.b $3e62
  003e38:  70 00                  moveq #$0, d0
  003e3a:  30 07                  move.w d7, d0
  003e3c:  20 4d                  movea.l a5, a0
  003e3e:  d1 c0                  adda.l d0, a0
  003e40:  d1 c0                  adda.l d0, a0
  003e42:  30 2e ff f2            move.w -$e(a6), d0
  003e46:  b0 68 a7 5c            cmp.w -$58a4(a0), d0
  003e4a:  66 14                  bne.b $3e60
  003e4c:  0c 6e 00 03 ff f6      cmpi.w #$3, -$a(a6)
  003e52:  6e 0c                  bgt.b $3e60
  003e54:  4a 6e ff f6            tst.w -$a(a6)
  003e58:  67 06                  beq.b $3e60
  003e5a:  42 2d a7 7e            clr.b -$5882(a5)
  003e5e:  60 08                  bra.b $3e68
  003e60:  52 47                  addq.w #$1, d7
  003e62:  0c 47 00 0a            cmpi.w #$a, d7
  003e66:  65 d0                  bcs.b $3e38
  003e68:  10 2d a7 7e            move.b -$5882(a5), d0
  003e6c:  2e 1f                  move.l (a7)+, d7
  003e6e:  4e 5e                  unlk a6
  003e70:  4e 75                  rts 
  003e72:  4e 56 00 00            link.w a6, #$0
  003e76:  48 e7 03 00            movem.l d6-d7, -(a7)
  003e7a:  1c 2e 00 08            move.b $8(a6), d6
  003e7e:  30 2d a7 7c            move.w -$5884(a5), d0
  003e82:  e0 48                  lsr.w #$8, d0
  003e84:  bd 00                  eor.b d6, d0
  003e86:  1e 00                  move.b d0, d7
  003e88:  70 00                  moveq #$0, d0
  003e8a:  10 06                  move.b d6, d0
  003e8c:  d0 6d a7 7c            add.w -$5884(a5), d0
  003e90:  c0 fc ce 6d            mulu.w #$ce6d, d0
  003e94:  06 40 58 bf            addi.w #$58bf, d0
  003e98:  3b 40 a7 7c            move.w d0, -$5884(a5)
  003e9c:  10 07                  move.b d7, d0
  003e9e:  4c df 00 c0            movem.l (a7)+, d6-d7
  003ea2:  4e 5e                  unlk a6
  003ea4:  4e 75                  rts 
  003ea6:  4e 56 00 00            link.w a6, #$0
  003eaa:  48 e7 01 38            movem.l d7/a2-a4, -(a7)
  003eae:  24 6e 00 08            movea.l $8(a6), a2
  003eb2:  20 0a                  move.l a2, d0
  003eb4:  67 30                  beq.b $3ee6
  003eb6:  3b 7c dc e5 a7 7c      move.w #$dce5, -$5884(a5)
  003ebc:  20 4a                  movea.l a2, a0
  003ebe:  a0 29                  dc.w $a029
  003ec0:  28 52                  movea.l (a2), a4
  003ec2:  42 a7                  clr.l -(a7)
  003ec4:  2f 0a                  move.l a2, -(a7)
  003ec6:  4e ba fc f2            jsr $3bba(pc)
  003eca:  26 4c                  movea.l a4, a3
  003ecc:  d7 df                  adda.l (a7)+, a3
  003ece:  5e 8c                  addq.l #$7, a4
  003ed0:  60 0c                  bra.b $3ede
  003ed2:  1f 14                  move.b (a4), -(a7)
  003ed4:  4e ba ff 9c            jsr $3e72(pc)
  003ed8:  18 80                  move.b d0, (a4)
  003eda:  52 8c                  addq.l #$1, a4
  003edc:  54 8f                  addq.l #$2, a7
  003ede:  b7 cc                  cmpa.l a4, a3
  003ee0:  62 f0                  bhi.b $3ed2
  003ee2:  20 4a                  movea.l a2, a0
  003ee4:  a0 2a                  dc.w $a02a
  003ee6:  4c df 1c 80            movem.l (a7)+, d7/a2-a4
  003eea:  4e 5e                  unlk a6
  003eec:  4e 75                  rts 
  003eee:  4e 56 ff fe            link.w a6, #$fffe
  003ef2:  2f 0c                  move.l a4, -(a7)
  003ef4:  42 a7                  clr.l -(a7)
  003ef6:  2f 3c 53 4f 4e 47      move.l #$534f4e47, -(a7)
  003efc:  3f 2e 00 08            move.w $8(a6), -(a7)
  003f00:  a9 a0                  dc.w $a9a0
  003f02:  28 5f                  movea.l (a7)+, a4
  003f04:  20 0c                  move.l a4, d0
  003f06:  67 5a                  beq.b $3f62
  003f08:  20 54                  movea.l (a4), a0
  003f0a:  3d 50 00 08            move.w (a0), $8(a6)
  003f0e:  4a 2d a7 7b            tst.b -$5885(a5)
  003f12:  67 06                  beq.b $3f1a
  003f14:  20 4c                  movea.l a4, a0
  003f16:  a0 29                  dc.w $a029
  003f18:  60 04                  bra.b $3f1e
  003f1a:  20 4c                  movea.l a4, a0
  003f1c:  a0 2a                  dc.w $a02a
  003f1e:  4a 2d a7 7a            tst.b -$5886(a5)
  003f22:  67 06                  beq.b $3f2a
  003f24:  20 4c                  movea.l a4, a0
  003f26:  a0 49                  dc.w $a049
  003f28:  60 04                  bra.b $3f2e
  003f2a:  20 4c                  movea.l a4, a0
  003f2c:  a0 4a                  dc.w $a04a
  003f2e:  42 a7                  clr.l -(a7)
  003f30:  2f 3c 4d 49 44 49      move.l #$4d494449, -(a7)
  003f36:  3f 2e 00 08            move.w $8(a6), -(a7)
  003f3a:  a9 a0                  dc.w $a9a0
  003f3c:  28 5f                  movea.l (a7)+, a4
  003f3e:  20 0c                  move.l a4, d0
  003f40:  67 20                  beq.b $3f62
  003f42:  4a 2d a7 7b            tst.b -$5885(a5)
  003f46:  67 06                  beq.b $3f4e
  003f48:  20 4c                  movea.l a4, a0
  003f4a:  a0 29                  dc.w $a029
  003f4c:  60 04                  bra.b $3f52
  003f4e:  20 4c                  movea.l a4, a0
  003f50:  a0 2a                  dc.w $a02a
  003f52:  4a 2d a7 7a            tst.b -$5886(a5)
  003f56:  67 06                  beq.b $3f5e
  003f58:  20 4c                  movea.l a4, a0
  003f5a:  a0 49                  dc.w $a049
  003f5c:  60 04                  bra.b $3f62
  003f5e:  20 4c                  movea.l a4, a0
  003f60:  a0 4a                  dc.w $a04a
  003f62:  28 5f                  movea.l (a7)+, a4
  003f64:  4e 5e                  unlk a6
  003f66:  4e 75                  rts 
  003f68:  4e 56 ff fc            link.w a6, #$fffc
  003f6c:  2f 0b                  move.l a3, -(a7)
  003f6e:  20 6e 00 0a            movea.l $a(a6), a0
  003f72:  42 50                  clr.w (a0)
  003f74:  42 a7                  clr.l -(a7)
  003f76:  2f 3c 4a 6e 74 68      move.l #$4a6e7468, -(a7)
  003f7c:  3f 2e 00 08            move.w $8(a6), -(a7)
  003f80:  a9 a0                  dc.w $a9a0
  003f82:  26 5f                  movea.l (a7)+, a3
  003f84:  4a ad a7 66            tst.l -$589a(a5)
  003f88:  67 08                  beq.b $3f92
  003f8a:  2f 2d a7 66            move.l -$589a(a5), -(a7)
  003f8e:  a9 92                  dc.w $a992
  003f90:  60 3e                  bra.b $3fd0
  003f92:  42 a7                  clr.l -(a7)
  003f94:  2f 3c 4d 44 52 56      move.l #$4d445256, -(a7)
  003f9a:  3f 2e 00 08            move.w $8(a6), -(a7)
  003f9e:  a9 a0                  dc.w $a9a0
  003fa0:  26 5f                  movea.l (a7)+, a3
  003fa2:  20 0b                  move.l a3, d0
  003fa4:  67 22                  beq.b $3fc8
  003fa6:  2f 0b                  move.l a3, -(a7)
  003fa8:  a9 92                  dc.w $a992
  003faa:  2f 0b                  move.l a3, -(a7)
  003fac:  4e ba fe f8            jsr $3ea6(pc)
  003fb0:  2e 8b                  move.l a3, (a7)
  003fb2:  4e ba 07 9e            jsr $4752(pc)
  003fb6:  26 40                  movea.l d0, a3
  003fb8:  20 0b                  move.l a3, d0
  003fba:  58 8f                  addq.l #$4, a7
  003fbc:  66 12                  bne.b $3fd0
  003fbe:  20 6e 00 0a            movea.l $a(a6), a0
  003fc2:  30 bc ff 94            move.w #$ff94, (a0)
  003fc6:  60 08                  bra.b $3fd0
  003fc8:  20 6e 00 0a            movea.l $a(a6), a0
  003fcc:  30 bc ff 34            move.w #$ff34, (a0)
  003fd0:  20 0b                  move.l a3, d0
  003fd2:  26 5f                  movea.l (a7)+, a3
  003fd4:  4e 5e                  unlk a6
  003fd6:  4e 75                  rts 
  003fd8:  4e 56 fe e4            link.w a6, #$fee4
  003fdc:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  003fe0:  3e 2e 00 0a            move.w $a(a6), d7
  003fe4:  7c 00                  moveq #$0, d6
  003fe6:  30 2e 00 08            move.w $8(a6), d0
  003fea:  0c 40 00 0e            cmpi.w #$e, d0
  003fee:  62 00 03 fa            bhi.w $43ea
  003ff2:  43 fa 04 00            lea.l $43f4(pc), a1
  003ff6:  d0 40                  add.w d0, d0
  003ff8:  d2 f1 00 00            adda.w (a1, d0.w), a1
  003ffc:  4e d1                  jmp (a1)
  003ffe:  1b 47 a7 7b            move.b d7, -$5885(a5)
  004002:  60 00 03 e6            bra.w $43ea
  004006:  1b 47 a7 7a            move.b d7, -$5886(a5)
  00400a:  60 00 03 de            bra.w $43ea
  00400e:  42 67                  clr.w -(a7)
  004010:  3f 3c 00 01            move.w #$1, -(a7)
  004014:  48 6e fe e4            pea.l -$11c(a6)
  004018:  4e ba fa 36            jsr $3a50(pc)
  00401c:  3c 1f                  move.w (a7)+, d6
  00401e:  48 c6                  ext.l d6
  004020:  4a 86                  tst.l d6
  004022:  67 0a                  beq.b $402e
  004024:  0c 6e 06 00 fe e8      cmpi.w #$600, -$118(a6)
  00402a:  6c 02                  bge.b $402e
  00402c:  7c 66                  moveq #$66, d6
  00402e:  4a 86                  tst.l d6
  004030:  66 00 03 b8            bne.w $43ea
  004034:  4e ba fd d0            jsr $3e06(pc)
  004038:  1b 40 a7 7e            move.b d0, -$5882(a5)
  00403c:  32 07                  move.w d7, d1
  00403e:  67 08                  beq.b $4048
  004040:  6b 32                  bmi.b $4074
  004042:  55 41                  subq.w #$2, d1
  004044:  6a 2e                  bpl.b $4074
  004046:  60 16                  bra.b $405e
  004048:  4a 2d a7 7e            tst.b -$5882(a5)
  00404c:  67 08                  beq.b $4056
  00404e:  3d 7c 00 16 ff fe      move.w #$16, -$2(a6)
  004054:  60 24                  bra.b $407a
  004056:  3d 7c 00 0b ff fe      move.w #$b, -$2(a6)
  00405c:  60 1c                  bra.b $407a
  00405e:  4a 2d a7 7e            tst.b -$5882(a5)
  004062:  67 08                  beq.b $406c
  004064:  3d 7c 00 0b ff fe      move.w #$b, -$2(a6)
  00406a:  60 0e                  bra.b $407a
  00406c:  3d 7c 00 0c ff fe      move.w #$c, -$2(a6)
  004072:  60 06                  bra.b $407a
  004074:  3d 7c ff ff ff fe      move.w #$ffff, -$2(a6)
  00407a:  0c 6e ff ff ff fe      cmpi.w #$ffff, -$2(a6)
  004080:  66 06                  bne.b $4088
  004082:  7c ce                  moveq #$ce, d6
  004084:  60 00 03 64            bra.w $43ea
  004088:  48 6e ff fc            pea.l -$4(a6)
  00408c:  3f 2e ff fe            move.w -$2(a6), -(a7)
  004090:  4e ba fe d6            jsr $3f68(pc)
  004094:  2b 40 a7 66            move.l d0, -$589a(a5)
  004098:  4a 80                  tst.l d0
  00409a:  5c 8f                  addq.l #$6, a7
  00409c:  66 1a                  bne.b $40b8
  00409e:  0c 6e 00 0c ff fe      cmpi.w #$c, -$2(a6)
  0040a4:  66 12                  bne.b $40b8
  0040a6:  48 6e ff fc            pea.l -$4(a6)
  0040aa:  3f 3c 00 0b            move.w #$b, -(a7)
  0040ae:  4e ba fe b8            jsr $3f68(pc)
  0040b2:  2b 40 a7 66            move.l d0, -$589a(a5)
  0040b6:  5c 8f                  addq.l #$6, a7
  0040b8:  3c 2e ff fc            move.w -$4(a6), d6
  0040bc:  48 c6                  ext.l d6
  0040be:  4a ad a7 66            tst.l -$589a(a5)
  0040c2:  67 00 03 26            beq.w $43ea
  0040c6:  20 6d a7 66            movea.l -$589a(a5), a0
  0040ca:  a0 64                  dc.w $a064
  0040cc:  20 6d a7 66            movea.l -$589a(a5), a0
  0040d0:  a0 4a                  dc.w $a04a
  0040d2:  20 6d a7 66            movea.l -$589a(a5), a0
  0040d6:  a0 29                  dc.w $a029
  0040d8:  20 6d a7 66            movea.l -$589a(a5), a0
  0040dc:  2b 50 a7 6a            move.l (a0), -$5896(a5)
  0040e0:  3b 7c ff ff a7 6e      move.w #$ffff, -$5892(a5)
  0040e6:  42 ad a7 72            clr.l -$588e(a5)
  0040ea:  42 2d a7 70            clr.b -$5890(a5)
  0040ee:  42 2d a7 71            clr.b -$588f(a5)
  0040f2:  70 00                  moveq #$0, d0
  0040f4:  10 2d a7 7e            move.b -$5882(a5), d0
  0040f8:  3f 00                  move.w d0, -(a7)
  0040fa:  3f 3c 00 10            move.w #$10, -(a7)
  0040fe:  22 6d a7 6a            movea.l -$5896(a5), a1
  004102:  4e 91                  jsr (a1)
  004104:  42 97                  clr.l (a7)
  004106:  20 6d a7 6a            movea.l -$5896(a5), a0
  00410a:  4e 90                  jsr (a0)
  00410c:  3e bc 00 07            move.w #$7, (a7)
  004110:  20 6d a7 6a            movea.l -$5896(a5), a0
  004114:  4e 90                  jsr (a0)
  004116:  1b 7c 00 01 a7 7a      move.b #$1, -$5886(a5)
  00411c:  42 2d a7 7b            clr.b -$5885(a5)
  004120:  42 57                  clr.w (a7)
  004122:  4e ba fd ca            jsr $3eee(pc)
  004126:  58 8f                  addq.l #$4, a7
  004128:  60 00 02 c0            bra.w $43ea
  00412c:  42 2d a7 70            clr.b -$5890(a5)
  004130:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  004136:  4e ba fe a0            jsr $3fd8(pc)
  00413a:  3e bc 00 08            move.w #$8, (a7)
  00413e:  20 6d a7 6a            movea.l -$5896(a5), a0
  004142:  4e 90                  jsr (a0)
  004144:  20 6d a7 66            movea.l -$589a(a5), a0
  004148:  a0 2a                  dc.w $a02a
  00414a:  20 6d a7 66            movea.l -$589a(a5), a0
  00414e:  a0 23                  dc.w $a023
  004150:  42 ad a7 66            clr.l -$589a(a5)
  004154:  99 cc                  suba.l a4, a4
  004156:  3d 7c 00 01 ff fc      move.w #$1, -$4(a6)
  00415c:  58 8f                  addq.l #$4, a7
  00415e:  42 a7                  clr.l -(a7)
  004160:  2f 3c 53 4d 4f 44      move.l #$534d4f44, -(a7)
  004166:  3f 2e ff fc            move.w -$4(a6), -(a7)
  00416a:  a9 9d                  dc.w $a99d
  00416c:  28 5f                  movea.l (a7)+, a4
  00416e:  20 0c                  move.l a4, d0
  004170:  67 1c                  beq.b $418e
  004172:  2f 0c                  move.l a4, -(a7)
  004174:  48 6e ff fe            pea.l -$2(a6)
  004178:  48 6e ff f8            pea.l -$8(a6)
  00417c:  48 6e fe f4            pea.l -$10c(a6)
  004180:  a9 a8                  dc.w $a9a8
  004182:  20 4c                  movea.l a4, a0
  004184:  a0 2a                  dc.w $a02a
  004186:  20 4c                  movea.l a4, a0
  004188:  a0 49                  dc.w $a049
  00418a:  2f 0c                  move.l a4, -(a7)
  00418c:  a9 a3                  dc.w $a9a3
  00418e:  52 6e ff fc            addq.w #$1, -$4(a6)
  004192:  20 0c                  move.l a4, d0
  004194:  66 c8                  bne.b $415e
  004196:  20 3c 00 80 00 00      move.l #$800000, d0
  00419c:  a0 4d                  dc.w $a04d
  00419e:  20 3c 00 80 00 00      move.l #$800000, d0
  0041a4:  a0 4c                  dc.w $a04c
  0041a6:  60 00 02 42            bra.w $43ea
  0041aa:  4a 2d a7 70            tst.b -$5890(a5)
  0041ae:  66 00 02 3a            bne.w $43ea
  0041b2:  3f 3c 00 0a            move.w #$a, -(a7)
  0041b6:  20 6d a7 6a            movea.l -$5896(a5), a0
  0041ba:  4e 90                  jsr (a0)
  0041bc:  1b 7c 00 01 a7 70      move.b #$1, -$5890(a5)
  0041c2:  2b 78 01 6a a7 76      move.l $16a.w, -$588a(a5)
  0041c8:  54 8f                  addq.l #$2, a7
  0041ca:  60 00 02 1e            bra.w $43ea
  0041ce:  4a 2d a7 70            tst.b -$5890(a5)
  0041d2:  67 00 02 16            beq.w $43ea
  0041d6:  3f 3c 00 0b            move.w #$b, -(a7)
  0041da:  20 6d a7 6a            movea.l -$5896(a5), a0
  0041de:  4e 90                  jsr (a0)
  0041e0:  42 2d a7 70            clr.b -$5890(a5)
  0041e4:  20 38 01 6a            move.l $16a.w, d0
  0041e8:  90 ad a7 76            sub.l -$588a(a5), d0
  0041ec:  d1 ad a7 72            add.l d0, -$588e(a5)
  0041f0:  2f 3c 00 09 00 00      move.l #$90000, -(a7)
  0041f6:  4e ba fd e0            jsr $3fd8(pc)
  0041fa:  5c 8f                  addq.l #$6, a7
  0041fc:  60 00 01 ec            bra.w $43ea
  004200:  4a 2d a7 70            tst.b -$5890(a5)
  004204:  66 00 01 e4            bne.w $43ea
  004208:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  00420e:  67 0c                  beq.b $421c
  004210:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  004216:  4e ba fd c0            jsr $3fd8(pc)
  00421a:  58 8f                  addq.l #$4, a7
  00421c:  2f 3c 00 0d 00 01      move.l #$d0001, -(a7)
  004222:  20 6d a7 6a            movea.l -$5896(a5), a0
  004226:  4e 90                  jsr (a0)
  004228:  58 8f                  addq.l #$4, a7
  00422a:  60 2a                  bra.b $4256
  00422c:  4a 2d a7 70            tst.b -$5890(a5)
  004230:  66 00 01 b8            bne.w $43ea
  004234:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  00423a:  67 0c                  beq.b $4248
  00423c:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  004242:  4e ba fd 94            jsr $3fd8(pc)
  004246:  58 8f                  addq.l #$4, a7
  004248:  2f 3c 00 0d 00 00      move.l #$d0000, -(a7)
  00424e:  20 6d a7 6a            movea.l -$5896(a5), a0
  004252:  4e 90                  jsr (a0)
  004254:  58 8f                  addq.l #$4, a7
  004256:  3f 07                  move.w d7, -(a7)
  004258:  42 67                  clr.w -(a7)
  00425a:  20 6d a7 6a            movea.l -$5896(a5), a0
  00425e:  4e 90                  jsr (a0)
  004260:  3e bc 00 01            move.w #$1, (a7)
  004264:  20 6d a7 6a            movea.l -$5896(a5), a0
  004268:  4e 90                  jsr (a0)
  00426a:  3e bc 00 02            move.w #$2, (a7)
  00426e:  20 6d a7 6a            movea.l -$5896(a5), a0
  004272:  4e 90                  jsr (a0)
  004274:  3b 47 a7 6e            move.w d7, -$5892(a5)
  004278:  2b 78 01 6a a7 72      move.l $16a.w, -$588e(a5)
  00427e:  58 8f                  addq.l #$4, a7
  004280:  60 00 01 68            bra.w $43ea
  004284:  4a 2d a7 70            tst.b -$5890(a5)
  004288:  66 00 01 60            bne.w $43ea
  00428c:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  004292:  67 00 01 56            beq.w $43ea
  004296:  3f 3c 00 05            move.w #$5, -(a7)
  00429a:  20 6d a7 6a            movea.l -$5896(a5), a0
  00429e:  4e 90                  jsr (a0)
  0042a0:  3e bc 00 09            move.w #$9, (a7)
  0042a4:  20 6d a7 6a            movea.l -$5896(a5), a0
  0042a8:  4e 90                  jsr (a0)
  0042aa:  3e bc 00 06            move.w #$6, (a7)
  0042ae:  20 6d a7 6a            movea.l -$5896(a5), a0
  0042b2:  4e 90                  jsr (a0)
  0042b4:  3e bc 00 07            move.w #$7, (a7)
  0042b8:  20 6d a7 6a            movea.l -$5896(a5), a0
  0042bc:  4e 90                  jsr (a0)
  0042be:  3e ad a7 6e            move.w -$5892(a5), (a7)
  0042c2:  4e ba fc 2a            jsr $3eee(pc)
  0042c6:  3b 7c ff ff a7 6e      move.w #$ffff, -$5892(a5)
  0042cc:  42 ad a7 72            clr.l -$588e(a5)
  0042d0:  54 8f                  addq.l #$2, a7
  0042d2:  60 00 01 16            bra.w $43ea
  0042d6:  4a 2d a7 70            tst.b -$5890(a5)
  0042da:  66 00 01 0e            bne.w $43ea
  0042de:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  0042e4:  67 00 01 04            beq.w $43ea
  0042e8:  4a 2d a7 71            tst.b -$588f(a5)
  0042ec:  66 00 00 fc            bne.w $43ea
  0042f0:  1b 7c 00 01 a7 71      move.b #$1, -$588f(a5)
  0042f6:  3f 3c 00 03            move.w #$3, -(a7)
  0042fa:  20 6d a7 6a            movea.l -$5896(a5), a0
  0042fe:  4e 90                  jsr (a0)
  004300:  42 2d a7 71            clr.b -$588f(a5)
  004304:  3e bc 00 04            move.w #$4, (a7)
  004308:  20 6d a7 6a            movea.l -$5896(a5), a0
  00430c:  4e 90                  jsr (a0)
  00430e:  4a 40                  tst.w d0
  004310:  54 8f                  addq.l #$2, a7
  004312:  67 04                  beq.b $4318
  004314:  70 00                  moveq #$0, d0
  004316:  60 02                  bra.b $431a
  004318:  70 01                  moveq #$1, d0
  00431a:  48 c0                  ext.l d0
  00431c:  2c 00                  move.l d0, d6
  00431e:  4a 86                  tst.l d6
  004320:  67 00 00 c8            beq.w $43ea
  004324:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  00432a:  4e ba fc ac            jsr $3fd8(pc)
  00432e:  58 8f                  addq.l #$4, a7
  004330:  60 00 00 b8            bra.w $43ea
  004334:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  00433a:  67 04                  beq.b $4340
  00433c:  70 00                  moveq #$0, d0
  00433e:  60 02                  bra.b $4342
  004340:  70 01                  moveq #$1, d0
  004342:  48 c0                  ext.l d0
  004344:  2c 00                  move.l d0, d6
  004346:  4a 2d a7 70            tst.b -$5890(a5)
  00434a:  66 00 00 9e            bne.w $43ea
  00434e:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  004354:  67 00 00 94            beq.w $43ea
  004358:  3f 3c 00 04            move.w #$4, -(a7)
  00435c:  20 6d a7 6a            movea.l -$5896(a5), a0
  004360:  4e 90                  jsr (a0)
  004362:  4a 40                  tst.w d0
  004364:  54 8f                  addq.l #$2, a7
  004366:  67 04                  beq.b $436c
  004368:  70 00                  moveq #$0, d0
  00436a:  60 02                  bra.b $436e
  00436c:  70 01                  moveq #$1, d0
  00436e:  48 c0                  ext.l d0
  004370:  2c 00                  move.l d0, d6
  004372:  60 76                  bra.b $43ea
  004374:  7c 00                  moveq #$0, d6
  004376:  42 67                  clr.w -(a7)
  004378:  3f 3c 00 01            move.w #$1, -(a7)
  00437c:  48 6e fe e4            pea.l -$11c(a6)
  004380:  4e ba f6 ce            jsr $3a50(pc)
  004384:  4a 5f                  tst.w (a7)+
  004386:  66 62                  bne.b $43ea
  004388:  30 2e fe ea            move.w -$116(a6), d0
  00438c:  6b 10                  bmi.b $439e
  00438e:  59 40                  subq.w #$4, d0
  004390:  67 14                  beq.b $43a6
  004392:  6a 06                  bpl.b $439a
  004394:  52 40                  addq.w #$1, d0
  004396:  6a 0a                  bpl.b $43a2
  004398:  60 04                  bra.b $439e
  00439a:  55 40                  subq.w #$2, d0
  00439c:  6b 0c                  bmi.b $43aa
  00439e:  7c 3c                  moveq #$3c, d6
  0043a0:  60 48                  bra.b $43ea
  0043a2:  7c 25                  moveq #$25, d6
  0043a4:  60 44                  bra.b $43ea
  0043a6:  7c 11                  moveq #$11, d6
  0043a8:  60 40                  bra.b $43ea
  0043aa:  7c 00                  moveq #$0, d6
  0043ac:  60 3c                  bra.b $43ea
  0043ae:  7c 00                  moveq #$0, d6
  0043b0:  4a 2d a7 70            tst.b -$5890(a5)
  0043b4:  66 34                  bne.b $43ea
  0043b6:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  0043bc:  67 2c                  beq.b $43ea
  0043be:  2c 38 01 6a            move.l $16a.w, d6
  0043c2:  9c ad a7 72            sub.l -$588e(a5), d6
  0043c6:  4a 86                  tst.l d6
  0043c8:  6c 20                  bge.b $43ea
  0043ca:  7c 00                  moveq #$0, d6
  0043cc:  60 1c                  bra.b $43ea
  0043ce:  4a 2d a7 70            tst.b -$5890(a5)
  0043d2:  66 16                  bne.b $43ea
  0043d4:  0c 6d ff ff a7 6e      cmpi.w #$ffff, -$5892(a5)
  0043da:  67 0e                  beq.b $43ea
  0043dc:  3f 07                  move.w d7, -(a7)
  0043de:  3f 3c 00 0c            move.w #$c, -(a7)
  0043e2:  20 6d a7 6a            movea.l -$5896(a5), a0
  0043e6:  4e 90                  jsr (a0)
  0043e8:  58 8f                  addq.l #$4, a7
  0043ea:  20 06                  move.l d6, d0
  0043ec:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  0043f0:  4e 5e                  unlk a6
  0043f2:  4e 75                  rts 
  0043f4:  fc 1a                  dc.w $fc1a
  0043f6:  fd 38                  dc.w $fd38
  0043f8:  fe 38                  dc.w $fe38
  0043fa:  fe 0c                  dc.w $fe0c
  0043fc:  fe 90                  dc.w $fe90
  0043fe:  fd b6                  dc.w $fdb6
  004400:  fd da                  dc.w $fdda
  004402:  ff 40                  dc.w $ff40
  004404:  ff ba                  dc.w $ffba
  004406:  fe e2                  dc.w $fee2
  004408:  ff 80                  dc.w $ff80
  00440a:  ff da                  dc.w $ffda
  00440c:  fc 12                  dc.w $fc12
  00440e:  fc 0a                  dc.w $fc0a
  004410:  ff f6                  dc.w $fff6
  004412:  4e 56 00 00            link.w a6, #$0
  004416:  2f 2e 00 10            move.l $10(a6), -(a7)
  00441a:  2f 2e 00 0c            move.l $c(a6), -(a7)
  00441e:  2f 2e 00 08            move.l $8(a6), -(a7)
  004422:  4e ba 01 26            jsr $454a(pc)
  004426:  20 6e 00 14            movea.l $14(a6), a0
  00442a:  20 80                  move.l d0, (a0)
  00442c:  4e 5e                  unlk a6
  00442e:  4e 75                  rts 
  004430:  4e 56 00 00            link.w a6, #$0
  004434:  20 6e 00 14            movea.l $14(a6), a0
  004438:  2f 10                  move.l (a0), -(a7)
  00443a:  2f 2e 00 10            move.l $10(a6), -(a7)
  00443e:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004442:  2f 2e 00 08            move.l $8(a6), -(a7)
  004446:  4e ba 01 c4            jsr $460c(pc)
  00444a:  4e 5e                  unlk a6
  00444c:  4e 75                  rts 
  00444e:  4e 56 ff f8            link.w a6, #$fff8
  004452:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004456:  2f 2e 00 08            move.l $8(a6), -(a7)
  00445a:  4e ba 02 1c            jsr $4678(pc)
  00445e:  2e ae 00 10            move.l $10(a6), (a7)
  004462:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004466:  2f 2e 00 08            move.l $8(a6), -(a7)
  00446a:  4e ba 00 de            jsr $454a(pc)
  00446e:  20 6e 00 14            movea.l $14(a6), a0
  004472:  20 80                  move.l d0, (a0)
  004474:  2e ae 00 0c            move.l $c(a6), (a7)
  004478:  2f 2e 00 08            move.l $8(a6), -(a7)
  00447c:  4e ba 02 18            jsr $4696(pc)
  004480:  4e 5e                  unlk a6
  004482:  4e 75                  rts 
  004484:  4e 56 00 00            link.w a6, #$0
  004488:  20 6e 00 14            movea.l $14(a6), a0
  00448c:  2f 10                  move.l (a0), -(a7)
  00448e:  2f 2e 00 10            move.l $10(a6), -(a7)
  004492:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004496:  2f 2e 00 08            move.l $8(a6), -(a7)
  00449a:  4e ba 01 70            jsr $460c(pc)
  00449e:  20 6e 00 14            movea.l $14(a6), a0
  0044a2:  2e 90                  move.l (a0), (a7)
  0044a4:  2f 2e 00 10            move.l $10(a6), -(a7)
  0044a8:  4e ba 01 ec            jsr $4696(pc)
  0044ac:  4e 5e                  unlk a6
  0044ae:  4e 75                  rts 
  0044b0:  4e 56 00 00            link.w a6, #$0
  0044b4:  48 e7 3e 30            movem.l d2-d6/a2-a3, -(a7)
  0044b8:  78 00                  moveq #$0, d4
  0044ba:  20 3c 00 00 10 00      move.l #$1000, d0
  0044c0:  22 2e 00 10            move.l $10(a6), d1
  0044c4:  b2 80                  cmp.l d0, d1
  0044c6:  6c 04                  bge.b $44cc
  0044c8:  24 01                  move.l d1, d2
  0044ca:  60 02                  bra.b $44ce
  0044cc:  24 00                  move.l d0, d2
  0044ce:  76 12                  moveq #$12, d3
  0044d0:  20 2e 00 0c            move.l $c(a6), d0
  0044d4:  90 81                  sub.l d1, d0
  0044d6:  b0 82                  cmp.l d2, d0
  0044d8:  6d 02                  blt.b $44dc
  0044da:  20 02                  move.l d2, d0
  0044dc:  b0 83                  cmp.l d3, d0
  0044de:  6c 02                  bge.b $44e2
  0044e0:  26 00                  move.l d0, d3
  0044e2:  20 6e 00 08            movea.l $8(a6), a0
  0044e6:  26 48                  movea.l a0, a3
  0044e8:  d7 c1                  adda.l d1, a3
  0044ea:  24 4b                  movea.l a3, a2
  0044ec:  95 c2                  suba.l d2, a2
  0044ee:  7c 00                  moveq #$0, d6
  0044f0:  1c 13                  move.b (a3), d6
  0044f2:  4a 42                  tst.w d2
  0044f4:  6f 28                  ble.b $451e
  0044f6:  bc 1a                  cmp.b (a2)+, d6
  0044f8:  67 04                  beq.b $44fe
  0044fa:  53 42                  subq.w #$1, d2
  0044fc:  60 f4                  bra.b $44f2
  0044fe:  70 01                  moveq #$1, d0
  004500:  43 eb 00 01            lea.l $1(a3), a1
  004504:  b0 43                  cmp.w d3, d0
  004506:  6c 08                  bge.b $4510
  004508:  b3 0a                  cmpm.b (a2)+, (a1)+
  00450a:  66 04                  bne.b $4510
  00450c:  52 40                  addq.w #$1, d0
  00450e:  60 f4                  bra.b $4504
  004510:  b0 44                  cmp.w d4, d0
  004512:  6f 04                  ble.b $4518
  004514:  3a 02                  move.w d2, d5
  004516:  38 00                  move.w d0, d4
  004518:  53 4a                  subq.w #$1, a2
  00451a:  94 40                  sub.w d0, d2
  00451c:  60 d4                  bra.b $44f2
  00451e:  0c 44 00 03            cmpi.w #$3, d4
  004522:  6d 1c                  blt.b $4540
  004524:  20 3c 00 00 10 00      move.l #$1000, d0
  00452a:  90 45                  sub.w d5, d0
  00452c:  32 04                  move.w d4, d1
  00452e:  57 41                  subq.w #$3, d1
  004530:  e1 49                  lsl.w #$8, d1
  004532:  e9 49                  lsl.w #$4, d1
  004534:  80 41                  or.w d1, d0
  004536:  20 6e 00 14            movea.l $14(a6), a0
  00453a:  30 80                  move.w d0, (a0)
  00453c:  30 04                  move.w d4, d0
  00453e:  60 02                  bra.b $4542
  004540:  70 00                  moveq #$0, d0
  004542:  4c df 0c 7c            movem.l (a7)+, d2-d6/a2-a3
  004546:  4e 5e                  unlk a6
  004548:  4e 75                  rts 
  00454a:  4e 56 ff e8            link.w a6, #$ffe8
  00454e:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  004552:  28 6e 00 08            movea.l $8(a6), a4
  004556:  7e 00                  moveq #$0, d7
  004558:  26 6e 00 10            movea.l $10(a6), a3
  00455c:  7c 00                  moveq #$0, d6
  00455e:  60 00 00 90            bra.w $45f0
  004562:  7a 00                  moveq #$0, d5
  004564:  78 00                  moveq #$0, d4
  004566:  76 00                  moveq #$0, d3
  004568:  60 5c                  bra.b $45c6
  00456a:  48 6e ff fe            pea.l -$2(a6)
  00456e:  2f 07                  move.l d7, -(a7)
  004570:  2f 2e 00 0c            move.l $c(a6), -(a7)
  004574:  2f 2e 00 08            move.l $8(a6), -(a7)
  004578:  4e ba ff 36            jsr $44b0(pc)
  00457c:  3d 40 ff e8            move.w d0, -$18(a6)
  004580:  4a 40                  tst.w d0
  004582:  4f ef 00 10            lea.l $10(a7), a7
  004586:  67 24                  beq.b $45ac
  004588:  30 2e ff fe            move.w -$2(a6), d0
  00458c:  e0 40                  asr.w #$8, d0
  00458e:  32 04                  move.w d4, d1
  004590:  52 44                  addq.w #$1, d4
  004592:  1d 80 10 ee            move.b d0, -$12(a6, d1.w)
  004596:  70 ff                  moveq #$ff, d0
  004598:  c0 2e ff ff            and.b -$1(a6), d0
  00459c:  32 04                  move.w d4, d1
  00459e:  52 44                  addq.w #$1, d4
  0045a0:  1d 80 10 ee            move.b d0, -$12(a6, d1.w)
  0045a4:  30 6e ff e8            movea.w -$18(a6), a0
  0045a8:  de 88                  add.l a0, d7
  0045aa:  60 12                  bra.b $45be
  0045ac:  30 04                  move.w d4, d0
  0045ae:  52 44                  addq.w #$1, d4
  0045b0:  1d b4 78 00 00 ee      move.b (a4, d7.l), -$12(a6, d0.w)
  0045b6:  70 01                  moveq #$1, d0
  0045b8:  e7 28                  lsl.b d3, d0
  0045ba:  8a 00                  or.b d0, d5
  0045bc:  52 87                  addq.l #$1, d7
  0045be:  be ae 00 0c            cmp.l $c(a6), d7
  0045c2:  6c 08                  bge.b $45cc
  0045c4:  52 43                  addq.w #$1, d3
  0045c6:  0c 43 00 08            cmpi.w #$8, d3
  0045ca:  6d 9e                  blt.b $456a
  0045cc:  bc ae 00 0c            cmp.l $c(a6), d6
  0045d0:  6c 04                  bge.b $45d6
  0045d2:  17 85 68 00            move.b d5, (a3, d6.l)
  0045d6:  52 86                  addq.l #$1, d6
  0045d8:  76 00                  moveq #$0, d3
  0045da:  60 10                  bra.b $45ec
  0045dc:  bc ae 00 0c            cmp.l $c(a6), d6
  0045e0:  6c 06                  bge.b $45e8
  0045e2:  17 b6 30 ee 68 00      move.b -$12(a6, d3.w), (a3, d6.l)
  0045e8:  52 86                  addq.l #$1, d6
  0045ea:  52 43                  addq.w #$1, d3
  0045ec:  b8 43                  cmp.w d3, d4
  0045ee:  6e ec                  bgt.b $45dc
  0045f0:  be ae 00 0c            cmp.l $c(a6), d7
  0045f4:  6d 00 ff 6c            blt.w $4562
  0045f8:  bc ae 00 0c            cmp.l $c(a6), d6
  0045fc:  6d 04                  blt.b $4602
  0045fe:  70 ff                  moveq #$ff, d0
  004600:  60 02                  bra.b $4604
  004602:  20 06                  move.l d6, d0
  004604:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  004608:  4e 5e                  unlk a6
  00460a:  4e 75                  rts 
  00460c:  4e 56 00 00            link.w a6, #$0
  004610:  48 e7 3f 30            movem.l d2-d7/a2-a3, -(a7)
  004614:  24 6e 00 08            movea.l $8(a6), a2
  004618:  2c 2e 00 0c            move.l $c(a6), d6
  00461c:  26 6e 00 10            movea.l $10(a6), a3
  004620:  2e 2e 00 14            move.l $14(a6), d7
  004624:  53 86                  subq.l #$1, d6
  004626:  6b 48                  bmi.b $4670
  004628:  16 1a                  move.b (a2)+, d3
  00462a:  74 07                  moveq #$7, d2
  00462c:  e2 0b                  lsr.b #$1, d3
  00462e:  64 10                  bcc.b $4640
  004630:  53 86                  subq.l #$1, d6
  004632:  6b 3c                  bmi.b $4670
  004634:  53 87                  subq.l #$1, d7
  004636:  6b 38                  bmi.b $4670
  004638:  16 da                  move.b (a2)+, (a3)+
  00463a:  51 ca ff f0            dbra d2, $462c
  00463e:  60 e4                  bra.b $4624
  004640:  55 86                  subq.l #$2, d6
  004642:  6b 2c                  bmi.b $4670
  004644:  10 1a                  move.b (a2)+, d0
  004646:  e1 48                  lsl.w #$8, d0
  004648:  10 1a                  move.b (a2)+, d0
  00464a:  3a 00                  move.w d0, d5
  00464c:  02 45 0f ff            andi.w #$fff, d5
  004650:  78 0f                  moveq #$f, d4
  004652:  e9 58                  rol.w #$4, d0
  004654:  c8 40                  and.w d0, d4
  004656:  54 44                  addq.w #$2, d4
  004658:  20 4b                  movea.l a3, a0
  00465a:  90 fc 10 00            suba.w #$1000, a0
  00465e:  d0 c5                  adda.w d5, a0
  004660:  53 87                  subq.l #$1, d7
  004662:  6b 0c                  bmi.b $4670
  004664:  16 d8                  move.b (a0)+, (a3)+
  004666:  51 cc ff f8            dbra d4, $4660
  00466a:  51 ca ff c0            dbra d2, $462c
  00466e:  60 b4                  bra.b $4624
  004670:  4c df 0c fc            movem.l (a7)+, d2-d7/a2-a3
  004674:  4e 5e                  unlk a6
  004676:  4e 75                  rts 
  004678:  4e 56 00 00            link.w a6, #$0
  00467c:  20 6e 00 08            movea.l $8(a6), a0
  004680:  20 2e 00 0c            move.l $c(a6), d0
  004684:  12 18                  move.b (a0)+, d1
  004686:  60 06                  bra.b $468e
  004688:  14 10                  move.b (a0), d2
  00468a:  93 18                  sub.b d1, (a0)+
  00468c:  12 02                  move.b d2, d1
  00468e:  53 80                  subq.l #$1, d0
  004690:  66 f6                  bne.b $4688
  004692:  4e 5e                  unlk a6
  004694:  4e 75                  rts 
  004696:  4e 56 00 00            link.w a6, #$0
  00469a:  20 6e 00 08            movea.l $8(a6), a0
  00469e:  20 2e 00 0c            move.l $c(a6), d0
  0046a2:  12 18                  move.b (a0)+, d1
  0046a4:  60 04                  bra.b $46aa
  0046a6:  d2 10                  add.b (a0), d1
  0046a8:  10 c1                  move.b d1, (a0)+
  0046aa:  53 80                  subq.l #$1, d0
  0046ac:  66 f8                  bne.b $46a6
  0046ae:  4e 5e                  unlk a6
  0046b0:  4e 75                  rts 
  0046b2:  4e 56 ff f8            link.w a6, #$fff8
  0046b6:  48 e7 00 38            movem.l a2-a4, -(a7)
  0046ba:  28 6e 00 08            movea.l $8(a6), a4
  0046be:  20 0c                  move.l a4, d0
  0046c0:  67 00 00 86            beq.w $4748
  0046c4:  42 a7                  clr.l -(a7)
  0046c6:  2f 0c                  move.l a4, -(a7)
  0046c8:  4e ba f4 f0            jsr $3bba(pc)
  0046cc:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  0046d0:  70 04                  moveq #$4, d0
  0046d2:  d0 ae ff fc            add.l -$4(a6), d0
  0046d6:  a1 22                  dc.w $a122
  0046d8:  26 48                  movea.l a0, a3
  0046da:  20 0b                  move.l a3, d0
  0046dc:  67 6a                  beq.b $4748
  0046de:  20 4b                  movea.l a3, a0
  0046e0:  a0 29                  dc.w $a029
  0046e2:  20 4c                  movea.l a4, a0
  0046e4:  a0 29                  dc.w $a029
  0046e6:  24 53                  movea.l (a3), a2
  0046e8:  58 8a                  addq.l #$4, a2
  0046ea:  48 6e ff f8            pea.l -$8(a6)
  0046ee:  2f 0a                  move.l a2, -(a7)
  0046f0:  2f 2e ff fc            move.l -$4(a6), -(a7)
  0046f4:  2f 14                  move.l (a4), -(a7)
  0046f6:  4e ba fd 1a            jsr $4412(pc)
  0046fa:  41 ee ff fc            lea.l -$4(a6), a0
  0046fe:  70 04                  moveq #$4, d0
  004700:  22 53                  movea.l (a3), a1
  004702:  a0 2e                  dc.w $a02e
  004704:  20 4c                  movea.l a4, a0
  004706:  a0 2a                  dc.w $a02a
  004708:  20 4c                  movea.l a4, a0
  00470a:  a0 23                  dc.w $a023
  00470c:  99 cc                  suba.l a4, a4
  00470e:  70 01                  moveq #$1, d0
  004710:  b0 ae ff f8            cmp.l -$8(a6), d0
  004714:  4f ef 00 10            lea.l $10(a7), a7
  004718:  6c 2e                  bge.b $4748
  00471a:  58 ae ff f8            addq.l #$4, -$8(a6)
  00471e:  20 2e ff f8            move.l -$8(a6), d0
  004722:  a1 22                  dc.w $a122
  004724:  28 48                  movea.l a0, a4
  004726:  20 0c                  move.l a4, d0
  004728:  67 1a                  beq.b $4744
  00472a:  20 4c                  movea.l a4, a0
  00472c:  a0 29                  dc.w $a029
  00472e:  20 4b                  movea.l a3, a0
  004730:  a0 29                  dc.w $a029
  004732:  20 2e ff f8            move.l -$8(a6), d0
  004736:  22 54                  movea.l (a4), a1
  004738:  20 53                  movea.l (a3), a0
  00473a:  a0 2e                  dc.w $a02e
  00473c:  20 4b                  movea.l a3, a0
  00473e:  a0 2a                  dc.w $a02a
  004740:  20 4c                  movea.l a4, a0
  004742:  a0 2a                  dc.w $a02a
  004744:  20 4b                  movea.l a3, a0
  004746:  a0 23                  dc.w $a023
  004748:  20 0c                  move.l a4, d0
  00474a:  4c df 1c 00            movem.l (a7)+, a2-a4
  00474e:  4e 5e                  unlk a6
  004750:  4e 75                  rts 
  004752:  4e 56 ff fc            link.w a6, #$fffc
  004756:  48 e7 00 18            movem.l a3-a4, -(a7)
  00475a:  28 6e 00 08            movea.l $8(a6), a4
  00475e:  20 4c                  movea.l a4, a0
  004760:  a0 29                  dc.w $a029
  004762:  43 ee ff fc            lea.l -$4(a6), a1
  004766:  70 04                  moveq #$4, d0
  004768:  20 54                  movea.l (a4), a0
  00476a:  a0 2e                  dc.w $a02e
  00476c:  20 4c                  movea.l a4, a0
  00476e:  a0 2a                  dc.w $a02a
  004770:  20 6e ff fc            movea.l -$4(a6), a0
  004774:  41 e8 01 00            lea.l $100(a0), a0
  004778:  20 08                  move.l a0, d0
  00477a:  a1 22                  dc.w $a122
  00477c:  26 48                  movea.l a0, a3
  00477e:  20 0b                  move.l a3, d0
  004780:  67 36                  beq.b $47b8
  004782:  20 4c                  movea.l a4, a0
  004784:  a0 29                  dc.w $a029
  004786:  20 4b                  movea.l a3, a0
  004788:  a0 29                  dc.w $a029
  00478a:  48 6e ff fc            pea.l -$4(a6)
  00478e:  2f 13                  move.l (a3), -(a7)
  004790:  42 a7                  clr.l -(a7)
  004792:  2f 0c                  move.l a4, -(a7)
  004794:  4e ba f4 24            jsr $3bba(pc)
  004798:  20 5f                  movea.l (a7)+, a0
  00479a:  48 68 ff fc            pea.l -$4(a0)
  00479e:  20 54                  movea.l (a4), a0
  0047a0:  48 68 00 04            pea.l $4(a0)
  0047a4:  4e ba fc 8a            jsr $4430(pc)
  0047a8:  20 4b                  movea.l a3, a0
  0047aa:  a0 2a                  dc.w $a02a
  0047ac:  20 4c                  movea.l a4, a0
  0047ae:  a0 2a                  dc.w $a02a
  0047b0:  20 4c                  movea.l a4, a0
  0047b2:  a0 23                  dc.w $a023
  0047b4:  4f ef 00 10            lea.l $10(a7), a7
  0047b8:  20 0b                  move.l a3, d0
  0047ba:  4c df 18 00            movem.l (a7)+, a3-a4
  0047be:  4e 5e                  unlk a6
  0047c0:  4e 75                  rts 
  0047c2:  53 6f 75 6e            subq.w #$1, $756e(a7)
  0047c6:  64 53                  bcc.b $481b
  0047c8:  79 73                  dc.w $7973
  0047ca:  20 26                  move.l -(a6), d0
  0047cc:  20 4d                  movea.l a5, a0
  0047ce:  75 73                  dc.w $7573
  0047d0:  69 63                  bvs.b $4835
  0047d2:  53 79 73 20 a9 20      subq.w #$1, $7320a920.l
  0047d8:  43 6f                  dc.w $436f
  0047da:  70 79                  moveq #$79, d0
  0047dc:  72 69                  moveq #$69, d1
  0047de:  67 68                  beq.b $4848
  0047e0:  74 20                  moveq #$20, d2
  0047e2:  31 39 38 39 2d 31      move.w $38392d31.l, -(a0)
  0047e8:  39 39 32 20 53 74      move.w $32205374.l, -(a4)
  0047ee:  65 76                  bcs.b $4866
  0047f0:  65 20                  bcs.b $4812
  0047f2:  48 61                  dc.w $4861
  0047f4:  6c 65                  bge.b $485b
  0047f6:  73 20                  dc.w $7320
  0047f8:  26 20                  move.l -(a0), d3
  0047fa:  4a 69 6d 20            tst.w $6d20(a1)
  0047fe:  4e 69                  move usp, a1
  004800:  74 63                  moveq #$63, d2
  004802:  68 61                  bvc.b $4865
  004804:  6c 73                  bge.b $4879
  004806:  2c 20                  move.l -(a0), d6
  004808:  41 6c                  dc.w $416c
  00480a:  6c 20                  bge.b $482c
  00480c:  52 69 67 68            addq.w #$1, $6768(a1)
  004810:  74 73                  moveq #$73, d2
  004812:  20 52                  movea.l (a2), a0
  004814:  65 73                  bcs.b $4889
  004816:  65 72                  bcs.b $488a
  004818:  76 65                  moveq #$65, d3
  00481a:  64 2e                  bcc.b $484a
  00481c:  4c 69                  dc.w $4c69
  00481e:  63 65                  bls.b $4885
  004820:  6e 73                  bgt.b $4895
  004822:  65 64                  bcs.b $4888
  004824:  20 74 6f 20 50 72      movea.l $5072(a4, d6.l * 8), a0
  00482a:  65 73                  bcs.b $489f
  00482c:  61 67                  bsr.b $4895
  00482e:  65 20                  bcs.b $4850
  004830:  53 6f 66 74            subq.w #$1, $6674(a7)
  004834:  77 61                  dc.w $7761
  004836:  72 65                  moveq #$65, d1
  004838:  20 44                  movea.l d4, a0
  00483a:  65 76                  bcs.b $48b2
  00483c:  65 6c                  bcs.b $48aa
  00483e:  6f 70                  ble.b $48b0
  004840:  65 6d                  bcs.b $48af
  004842:  65 6e                  bcs.b $48b2
  004844:  74 2c                  moveq #$2c, d2
  004846:  20 49                  movea.l a1, a0
  004848:  6e 63                  bgt.b $48ad
  00484a:  4e 75                  rts 
  00484c:  4e 56 00 00            link.w a6, #$0
  004850:  48 e7 03 38            movem.l d6-d7/a2-a4, -(a7)
  004854:  3c 2e 00 08            move.w $8(a6), d6
  004858:  99 cc                  suba.l a4, a4
  00485a:  7e 00                  moveq #$0, d7
  00485c:  97 cb                  suba.l a3, a3
  00485e:  60 34                  bra.b $4894
  004860:  24 4b                  movea.l a3, a2
  004862:  d5 ed a7 82            adda.l -$587e(a5), a2
  004866:  bc 6a 00 1a            cmp.w $1a(a2), d6
  00486a:  66 22                  bne.b $488e
  00486c:  4a aa 00 02            tst.l $2(a2)
  004870:  67 04                  beq.b $4876
  004872:  28 4a                  movea.l a2, a4
  004874:  60 24                  bra.b $489a
  004876:  42 27                  clr.b -(a7)
  004878:  2f 0a                  move.l a2, -(a7)
  00487a:  3f 06                  move.w d6, -(a7)
  00487c:  4e ba 02 9e            jsr $4b1c(pc)
  004880:  4a 00                  tst.b d0
  004882:  50 8f                  addq.l #$8, a7
  004884:  67 08                  beq.b $488e
  004886:  28 4b                  movea.l a3, a4
  004888:  d9 ed a7 82            adda.l -$587e(a5), a4
  00488c:  60 0c                  bra.b $489a
  00488e:  52 47                  addq.w #$1, d7
  004890:  47 eb 00 22            lea.l $22(a3), a3
  004894:  be 6d a7 80            cmp.w -$5880(a5), d7
  004898:  6d c6                  blt.b $4860
  00489a:  20 0c                  move.l a4, d0
  00489c:  4c df 1c c0            movem.l (a7)+, d6-d7/a2-a4
  0048a0:  4e 5e                  unlk a6
  0048a2:  4e 75                  rts 
  0048a4:  4e 56 00 00            link.w a6, #$0
  0048a8:  30 6e 00 08            movea.w $8(a6), a0
  0048ac:  2f 08                  move.l a0, -(a7)
  0048ae:  48 78 00 3c            pea.l $3c.w
  0048b2:  2f 2e 00 0a            move.l $a(a6), -(a7)
  0048b6:  4e ad 00 42            jsr $42(a5)
  0048ba:  2f 00                  move.l d0, -(a7)
  0048bc:  4e ad 00 5a            jsr $5a(a5)
  0048c0:  4e 5e                  unlk a6
  0048c2:  4e 75                  rts 
  0048c4:  48 e7 1f 38            movem.l d3-d7/a2-a4, -(a7)
  0048c8:  20 0d                  move.l a5, d0
  0048ca:  2a 78 09 04            movea.l $904.w, a5
  0048ce:  26 00                  move.l d0, d3
  0048d0:  3b 7c 00 01 a7 d6      move.w #$1, -$582a(a5)
  0048d6:  4a 2d a7 da            tst.b -$5826(a5)
  0048da:  66 00 01 50            bne.w $4a2c
  0048de:  1b 7c 00 01 a7 da      move.b #$1, -$5826(a5)
  0048e4:  4a 6d a7 dc            tst.w -$5824(a5)
  0048e8:  6f 04                  ble.b $48ee
  0048ea:  53 6d a7 dc            subq.w #$1, -$5824(a5)
  0048ee:  4a 6d a7 88            tst.w -$5878(a5)
  0048f2:  6f 04                  ble.b $48f8
  0048f4:  53 6d a7 88            subq.w #$1, -$5878(a5)
  0048f8:  4a ad a8 04            tst.l -$57fc(a5)
  0048fc:  67 06                  beq.b $4904
  0048fe:  20 6d a8 04            movea.l -$57fc(a5), a0
  004902:  4e 90                  jsr (a0)
  004904:  4a 2d a7 e6            tst.b -$581a(a5)
  004908:  67 00 00 b2            beq.w $49bc
  00490c:  20 2d a7 fe            move.l -$5802(a5), d0
  004910:  90 ad a7 de            sub.l -$5822(a5), d0
  004914:  b0 ad a7 ec            cmp.l -$5814(a5), d0
  004918:  6f 00 00 a2            ble.w $49bc
  00491c:  0c 6d ff ff a7 f8      cmpi.w #$ffff, -$5808(a5)
  004922:  67 28                  beq.b $494c
  004924:  53 6d a7 f8            subq.w #$1, -$5808(a5)
  004928:  4a 6d a7 f8            tst.w -$5808(a5)
  00492c:  6c 4c                  bge.b $497a
  00492e:  48 78 ff ff            pea.l $ffff.w
  004932:  2f 2d a7 f4            move.l -$580c(a5), -(a7)
  004936:  3f 2d a7 e4            move.w -$581c(a5), -(a7)
  00493a:  3f 2d a7 e2            move.w -$581e(a5), -(a7)
  00493e:  4e ba 09 50            jsr $5290(pc)
  004942:  42 2d a7 e6            clr.b -$581a(a5)
  004946:  4f ef 00 0c            lea.l $c(a7), a7
  00494a:  60 70                  bra.b $49bc
  00494c:  4a ad a7 fa            tst.l -$5806(a5)
  004950:  67 28                  beq.b $497a
  004952:  20 6d a7 fa            movea.l -$5806(a5), a0
  004956:  4e 90                  jsr (a0)
  004958:  4a 00                  tst.b d0
  00495a:  67 1e                  beq.b $497a
  00495c:  48 78 ff ff            pea.l $ffff.w
  004960:  2f 2d a7 f4            move.l -$580c(a5), -(a7)
  004964:  3f 2d a7 e4            move.w -$581c(a5), -(a7)
  004968:  3f 2d a7 e2            move.w -$581e(a5), -(a7)
  00496c:  4e ba 09 22            jsr $5290(pc)
  004970:  42 2d a7 e6            clr.b -$581a(a5)
  004974:  4f ef 00 0c            lea.l $c(a7), a7
  004978:  60 42                  bra.b $49bc
  00497a:  3e 2d a7 f8            move.w -$5808(a5), d7
  00497e:  48 c7                  ext.l d7
  004980:  24 6d a7 fa            movea.l -$5806(a5), a2
  004984:  1c 2d a7 e6            move.b -$581a(a5), d6
  004988:  2a 2d a7 f0            move.l -$5810(a5), d5
  00498c:  28 2d a7 f4            move.l -$580c(a5), d4
  004990:  2f 2d a7 f4            move.l -$580c(a5), -(a7)
  004994:  2f 2d a7 f0            move.l -$5810(a5), -(a7)
  004998:  3f 2d a7 e4            move.w -$581c(a5), -(a7)
  00499c:  3f 2d a7 e2            move.w -$581e(a5), -(a7)
  0049a0:  4e ba 09 74            jsr $5316(pc)
  0049a4:  2b 44 a7 f4            move.l d4, -$580c(a5)
  0049a8:  2b 45 a7 f0            move.l d5, -$5810(a5)
  0049ac:  1b 46 a7 e6            move.b d6, -$581a(a5)
  0049b0:  2b 4a a7 fa            move.l a2, -$5806(a5)
  0049b4:  3b 47 a7 f8            move.w d7, -$5808(a5)
  0049b8:  4f ef 00 0c            lea.l $c(a7), a7
  0049bc:  4a ad a7 c2            tst.l -$583e(a5)
  0049c0:  67 62                  beq.b $4a24
  0049c2:  4a 6d a7 ca            tst.w -$5836(a5)
  0049c6:  6c 58                  bge.b $4a20
  0049c8:  30 2d a7 c6            move.w -$583a(a5), d0
  0049cc:  b0 6d a7 c8            cmp.w -$5838(a5), d0
  0049d0:  6c 48                  bge.b $4a1a
  0049d2:  70 06                  moveq #$6, d0
  0049d4:  c1 ed a7 c6            muls.w -$583a(a5), d0
  0049d8:  d0 ad a7 c2            add.l -$583e(a5), d0
  0049dc:  28 40                  movea.l d0, a4
  0049de:  26 6d a7 c2            movea.l -$583e(a5), a3
  0049e2:  0c 54 ff ff            cmpi.w #$ffff, (a4)
  0049e6:  66 06                  bne.b $49ee
  0049e8:  4e ba 0b 98            jsr $5582(pc)
  0049ec:  60 0c                  bra.b $49fa
  0049ee:  3f 2c 00 02            move.w $2(a4), -(a7)
  0049f2:  3f 14                  move.w (a4), -(a7)
  0049f4:  4e ba 07 c6            jsr $51bc(pc)
  0049f8:  58 8f                  addq.l #$4, a7
  0049fa:  0c 6c ff fe 00 04      cmpi.w #$fffe, $4(a4)
  004a00:  66 08                  bne.b $4a0a
  004a02:  3b 6d a7 dc a7 ca      move.w -$5824(a5), -$5836(a5)
  004a08:  60 06                  bra.b $4a10
  004a0a:  3b 6c 00 04 a7 ca      move.w $4(a4), -$5836(a5)
  004a10:  52 6d a7 c6            addq.w #$1, -$583a(a5)
  004a14:  2b 4b a7 c2            move.l a3, -$583e(a5)
  004a18:  60 0a                  bra.b $4a24
  004a1a:  42 ad a7 c2            clr.l -$583e(a5)
  004a1e:  60 04                  bra.b $4a24
  004a20:  53 6d a7 ca            subq.w #$1, -$5836(a5)
  004a24:  52 ad a7 fe            addq.l #$1, -$5802(a5)
  004a28:  42 2d a7 da            clr.b -$5826(a5)
  004a2c:  20 03                  move.l d3, d0
  004a2e:  c1 8d                  exg.l d0, a5
  004a30:  4c df 1c f8            movem.l (a7)+, d3-d7/a2-a4
  004a34:  4e 75                  rts 
  004a36:  4e 56 00 00            link.w a6, #$0
  004a3a:  2b 6e 00 08 a8 04      move.l $8(a6), -$57fc(a5)
  004a40:  4e 5e                  unlk a6
  004a42:  4e 75                  rts 
  004a44:  4e 56 00 00            link.w a6, #$0
  004a48:  4e 5e                  unlk a6
  004a4a:  4e 75                  rts 
  004a4c:  4e 56 00 00            link.w a6, #$0
  004a50:  2f 07                  move.l d7, -(a7)
  004a52:  20 0d                  move.l a5, d0
  004a54:  2a 78 09 04            movea.l $904.w, a5
  004a58:  2e 00                  move.l d0, d7
  004a5a:  4a ad a8 08            tst.l -$57f8(a5)
  004a5e:  67 06                  beq.b $4a66
  004a60:  20 6d a8 08            movea.l -$57f8(a5), a0
  004a64:  4e 90                  jsr (a0)
  004a66:  20 07                  move.l d7, d0
  004a68:  c1 8d                  exg.l d0, a5
  004a6a:  42 6e 00 0e            clr.w $e(a6)
  004a6e:  2e 1f                  move.l (a7)+, d7
  004a70:  4e 5e                  unlk a6
  004a72:  20 5f                  movea.l (a7)+, a0
  004a74:  5c 8f                  addq.l #$6, a7
  004a76:  4e d0                  jmp (a0)
  004a78:  4e 56 ff fc            link.w a6, #$fffc
  004a7c:  2f 07                  move.l d7, -(a7)
  004a7e:  a9 ff                  dc.w $a9ff
  004a80:  20 6e 00 08            movea.l $8(a6), a0
  004a84:  3e 28 00 02            move.w $2(a0), d7
  004a88:  0c 47 73 6d            cmpi.w #$736d, d7
  004a8c:  66 24                  bne.b $4ab2
  004a8e:  20 6e 00 08            movea.l $8(a6), a0
  004a92:  20 28 00 04            move.l $4(a0), d0
  004a96:  c1 8d                  exg.l d0, a5
  004a98:  2e 00                  move.l d0, d7
  004a9a:  4a ad a8 08            tst.l -$57f8(a5)
  004a9e:  67 06                  beq.b $4aa6
  004aa0:  20 6d a8 08            movea.l -$57f8(a5), a0
  004aa4:  4e 90                  jsr (a0)
  004aa6:  20 6e 00 08            movea.l $8(a6), a0
  004aaa:  20 28 00 04            move.l $4(a0), d0
  004aae:  c1 8d                  exg.l d0, a5
  004ab0:  2e 00                  move.l d0, d7
  004ab2:  2e 1f                  move.l (a7)+, d7
  004ab4:  4e 5e                  unlk a6
  004ab6:  20 5f                  movea.l (a7)+, a0
  004ab8:  50 8f                  addq.l #$8, a7
  004aba:  4e d0                  jmp (a0)
  004abc:  4e 75                  rts 
  004abe:  4e 56 ff fc            link.w a6, #$fffc
  004ac2:  48 e7 00 18            movem.l a3-a4, -(a7)
  004ac6:  28 6e 00 08            movea.l $8(a6), a4
  004aca:  20 4c                  movea.l a4, a0
  004acc:  a0 29                  dc.w $a029
  004ace:  43 ee ff fc            lea.l -$4(a6), a1
  004ad2:  70 04                  moveq #$4, d0
  004ad4:  20 54                  movea.l (a4), a0
  004ad6:  a0 2e                  dc.w $a02e
  004ad8:  20 2e ff fc            move.l -$4(a6), d0
  004adc:  a1 22                  dc.w $a122
  004ade:  26 48                  movea.l a0, a3
  004ae0:  20 0b                  move.l a3, d0
  004ae2:  67 2a                  beq.b $4b0e
  004ae4:  20 4b                  movea.l a3, a0
  004ae6:  a0 29                  dc.w $a029
  004ae8:  48 6e ff fc            pea.l -$4(a6)
  004aec:  2f 13                  move.l (a3), -(a7)
  004aee:  42 a7                  clr.l -(a7)
  004af0:  2f 0c                  move.l a4, -(a7)
  004af2:  4e ba f0 c6            jsr $3bba(pc)
  004af6:  20 5f                  movea.l (a7)+, a0
  004af8:  48 68 ff fc            pea.l -$4(a0)
  004afc:  20 54                  movea.l (a4), a0
  004afe:  48 68 00 04            pea.l $4(a0)
  004b02:  4e ba f9 80            jsr $4484(pc)
  004b06:  20 4b                  movea.l a3, a0
  004b08:  a0 2a                  dc.w $a02a
  004b0a:  4f ef 00 10            lea.l $10(a7), a7
  004b0e:  20 4c                  movea.l a4, a0
  004b10:  a0 2a                  dc.w $a02a
  004b12:  20 0b                  move.l a3, d0
  004b14:  4c df 18 00            movem.l (a7)+, a3-a4
  004b18:  4e 5e                  unlk a6
  004b1a:  4e 75                  rts 
  004b1c:  4e 56 ff f2            link.w a6, #$fff2
  004b20:  48 e7 1f 38            movem.l d3-d7/a2-a4, -(a7)
  004b24:  3e 2e 00 08            move.w $8(a6), d7
  004b28:  28 6e 00 0a            movea.l $a(a6), a4
  004b2c:  42 2e ff f3            clr.b -$d(a6)
  004b30:  4a 2e 00 0e            tst.b $e(a6)
  004b34:  66 00 01 3e            bne.w $4c74
  004b38:  08 94 00 07            bclr.b #$7, (a4)
  004b3c:  42 a7                  clr.l -(a7)
  004b3e:  2f 3c 63 73 6e 64      move.l #$63736e64, -(a7)
  004b44:  3f 07                  move.w d7, -(a7)
  004b46:  a9 a0                  dc.w $a9a0
  004b48:  26 1f                  move.l (a7)+, d3
  004b4a:  4a 83                  tst.l d3
  004b4c:  67 1c                  beq.b $4b6a
  004b4e:  08 94 00 06            bclr.b #$6, (a4)
  004b52:  2f 03                  move.l d3, -(a7)
  004b54:  4e ba ff 68            jsr $4abe(pc)
  004b58:  2d 40 ff f4            move.l d0, -$c(a6)
  004b5c:  20 43                  movea.l d3, a0
  004b5e:  a0 49                  dc.w $a049
  004b60:  2e 83                  move.l d3, (a7)
  004b62:  a9 a3                  dc.w $a9a3
  004b64:  26 2e ff f4            move.l -$c(a6), d3
  004b68:  60 16                  bra.b $4b80
  004b6a:  08 d4 00 05            bset.b #$5, (a4)
  004b6e:  08 d4 00 06            bset.b #$6, (a4)
  004b72:  42 a7                  clr.l -(a7)
  004b74:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  004b7a:  3f 07                  move.w d7, -(a7)
  004b7c:  a9 a0                  dc.w $a9a0
  004b7e:  26 1f                  move.l (a7)+, d3
  004b80:  4a 83                  tst.l d3
  004b82:  67 00 00 f2            beq.w $4c76
  004b86:  20 43                  movea.l d3, a0
  004b88:  a0 69                  dc.w $a069
  004b8a:  19 40 00 01            move.b d0, $1(a4)
  004b8e:  4a 2c 00 01            tst.b $1(a4)
  004b92:  67 06                  beq.b $4b9a
  004b94:  08 94 00 05            bclr.b #$5, (a4)
  004b98:  60 04                  bra.b $4b9e
  004b9a:  20 43                  movea.l d3, a0
  004b9c:  a0 64                  dc.w $a064
  004b9e:  4a 78 02 20            tst.w $220.w
  004ba2:  66 00 00 bc            bne.w $4c60
  004ba6:  20 43                  movea.l d3, a0
  004ba8:  a0 29                  dc.w $a029
  004baa:  20 43                  movea.l d3, a0
  004bac:  24 50                  movea.l (a0), a2
  004bae:  3d 52 ff f8            move.w (a2), -$8(a6)
  004bb2:  30 2e ff f8            move.w -$8(a6), d0
  004bb6:  67 22                  beq.b $4bda
  004bb8:  6b 20                  bmi.b $4bda
  004bba:  55 40                  subq.w #$2, d0
  004bbc:  67 12                  beq.b $4bd0
  004bbe:  6a 1a                  bpl.b $4bda
  004bc0:  38 2a 00 02            move.w $2(a2), d4
  004bc4:  70 06                  moveq #$6, d0
  004bc6:  c1 c4                  muls.w d4, d0
  004bc8:  3d 72 00 04 ff fa      move.w $4(a2, d0.w), -$6(a6)
  004bce:  60 10                  bra.b $4be0
  004bd0:  78 00                  moveq #$0, d4
  004bd2:  3d 6a 00 04 ff fa      move.w $4(a2), -$6(a6)
  004bd8:  60 06                  bra.b $4be0
  004bda:  3d 7c ff ff ff f8      move.w #$ffff, -$8(a6)
  004be0:  0c 6e ff ff ff f8      cmpi.w #$ffff, -$8(a6)
  004be6:  67 74                  beq.b $4c5c
  004be8:  70 06                  moveq #$6, d0
  004bea:  c1 c4                  muls.w d4, d0
  004bec:  30 40                  movea.w d0, a0
  004bee:  30 2e ff fa            move.w -$6(a6), d0
  004bf2:  e7 48                  lsl.w #$3, d0
  004bf4:  5c 40                  addq.w #$6, d0
  004bf6:  d0 c0                  adda.w d0, a0
  004bf8:  2d 48 ff fc            move.l a0, -$4(a6)
  004bfc:  42 a7                  clr.l -(a7)
  004bfe:  22 43                  movea.l d3, a1
  004c00:  2f 11                  move.l (a1), -(a7)
  004c02:  4e ba f1 e8            jsr $3dec(pc)
  004c06:  26 6e ff fc            movea.l -$4(a6), a3
  004c0a:  d7 df                  adda.l (a7)+, a3
  004c0c:  29 4b 00 06            move.l a3, $6(a4)
  004c10:  41 eb 00 16            lea.l $16(a3), a0
  004c14:  29 48 00 0a            move.l a0, $a(a4)
  004c18:  29 6b 00 04 00 0e      move.l $4(a3), $e(a4)
  004c1e:  29 6b 00 0c 00 12      move.l $c(a3), $12(a4)
  004c24:  29 6b 00 10 00 16      move.l $10(a3), $16(a4)
  004c2a:  2a 2b 00 08            move.l $8(a3), d5
  004c2e:  70 10                  moveq #$10, d0
  004c30:  e0 a5                  asr.l d0, d5
  004c32:  39 45 00 1c            move.w d5, $1c(a4)
  004c36:  4a 2d a8 02            tst.b -$57fe(a5)
  004c3a:  66 18                  bne.b $4c54
  004c3c:  2c 2c 00 0a            move.l $a(a4), d6
  004c40:  5d 86                  subq.l #$6, d6
  004c42:  29 46 00 1e            move.l d6, $1e(a4)
  004c46:  20 46                  movea.l d6, a0
  004c48:  42 50                  clr.w (a0)
  004c4a:  30 6c 00 1c            movea.w $1c(a4), a0
  004c4e:  22 46                  movea.l d6, a1
  004c50:  23 48 00 02            move.l a0, $2(a1)
  004c54:  1d 7c 00 01 ff f3      move.b #$1, -$d(a6)
  004c5a:  60 1a                  bra.b $4c76
  004c5c:  20 43                  movea.l d3, a0
  004c5e:  a0 2a                  dc.w $a02a
  004c60:  08 14 00 06            btst.b #$6, (a4)
  004c64:  67 06                  beq.b $4c6c
  004c66:  2f 03                  move.l d3, -(a7)
  004c68:  a9 a3                  dc.w $a9a3
  004c6a:  60 04                  bra.b $4c70
  004c6c:  20 43                  movea.l d3, a0
  004c6e:  a0 23                  dc.w $a023
  004c70:  76 00                  moveq #$0, d3
  004c72:  60 02                  bra.b $4c76
  004c74:  76 00                  moveq #$0, d3
  004c76:  39 47 00 1a            move.w d7, $1a(a4)
  004c7a:  29 43 00 02            move.l d3, $2(a4)
  004c7e:  10 2e ff f3            move.b -$d(a6), d0
  004c82:  4c df 1c f8            movem.l (a7)+, d3-d7/a2-a4
  004c86:  4e 5e                  unlk a6
  004c88:  4e 75                  rts 
  004c8a:  4e 56 00 00            link.w a6, #$0
  004c8e:  48 e7 00 38            movem.l a2-a4, -(a7)
  004c92:  28 6e 00 08            movea.l $8(a6), a4
  004c96:  4a 6d a7 dc            tst.w -$5824(a5)
  004c9a:  66 3e                  bne.b $4cda
  004c9c:  4a ad a7 c2            tst.l -$583e(a5)
  004ca0:  66 38                  bne.b $4cda
  004ca2:  45 ec 00 02            lea.l $2(a4), a2
  004ca6:  26 52                  movea.l (a2), a3
  004ca8:  20 0b                  move.l a3, d0
  004caa:  67 2e                  beq.b $4cda
  004cac:  08 14 00 06            btst.b #$6, (a4)
  004cb0:  67 1a                  beq.b $4ccc
  004cb2:  08 14 00 05            btst.b #$5, (a4)
  004cb6:  67 0a                  beq.b $4cc2
  004cb8:  20 4b                  movea.l a3, a0
  004cba:  a0 2a                  dc.w $a02a
  004cbc:  2f 0b                  move.l a3, -(a7)
  004cbe:  a9 a3                  dc.w $a9a3
  004cc0:  60 12                  bra.b $4cd4
  004cc2:  10 2c 00 01            move.b $1(a4), d0
  004cc6:  20 4b                  movea.l a3, a0
  004cc8:  a0 6a                  dc.w $a06a
  004cca:  60 08                  bra.b $4cd4
  004ccc:  20 4b                  movea.l a3, a0
  004cce:  a0 2a                  dc.w $a02a
  004cd0:  20 4b                  movea.l a3, a0
  004cd2:  a0 23                  dc.w $a023
  004cd4:  42 92                  clr.l (a2)
  004cd6:  08 94 00 07            bclr.b #$7, (a4)
  004cda:  4c df 1c 00            movem.l (a7)+, a2-a4
  004cde:  4e 5e                  unlk a6
  004ce0:  4e 75                  rts 
  004ce2:  4e 56 00 00            link.w a6, #$0
  004ce6:  48 e7 07 38            movem.l d5-d7/a2-a4, -(a7)
  004cea:  26 6e 00 08            movea.l $8(a6), a3
  004cee:  7a 00                  moveq #$0, d5
  004cf0:  28 4b                  movea.l a3, a4
  004cf2:  7e 00                  moveq #$0, d7
  004cf4:  60 02                  bra.b $4cf8
  004cf6:  52 47                  addq.w #$1, d7
  004cf8:  0c 5c ff ff            cmpi.w #$ffff, (a4)+
  004cfc:  66 f8                  bne.b $4cf6
  004cfe:  4a 47                  tst.w d7
  004d00:  6f 56                  ble.b $4d58
  004d02:  70 22                  moveq #$22, d0
  004d04:  c1 c7                  muls.w d7, d0
  004d06:  a1 1e                  dc.w $a11e
  004d08:  2b 48 a7 82            move.l a0, -$587e(a5)
  004d0c:  20 08                  move.l a0, d0
  004d0e:  67 46                  beq.b $4d56
  004d10:  28 6d a7 82            movea.l -$587e(a5), a4
  004d14:  7c 22                  moveq #$22, d6
  004d16:  cc c7                  mulu.w d7, d6
  004d18:  60 02                  bra.b $4d1c
  004d1a:  42 1c                  clr.b (a4)+
  004d1c:  30 06                  move.w d6, d0
  004d1e:  53 46                  subq.w #$1, d6
  004d20:  4a 40                  tst.w d0
  004d22:  6e f6                  bgt.b $4d1a
  004d24:  3b 47 a7 80            move.w d7, -$5880(a5)
  004d28:  7c 00                  moveq #$0, d6
  004d2a:  99 cc                  suba.l a4, a4
  004d2c:  95 ca                  suba.l a2, a2
  004d2e:  60 20                  bra.b $4d50
  004d30:  1f 2e 00 0c            move.b $c(a6), -(a7)
  004d34:  20 4a                  movea.l a2, a0
  004d36:  d1 ed a7 82            adda.l -$587e(a5), a0
  004d3a:  2f 08                  move.l a0, -(a7)
  004d3c:  20 4b                  movea.l a3, a0
  004d3e:  d1 cc                  adda.l a4, a0
  004d40:  3f 10                  move.w (a0), -(a7)
  004d42:  4e ba fd d8            jsr $4b1c(pc)
  004d46:  50 8f                  addq.l #$8, a7
  004d48:  52 46                  addq.w #$1, d6
  004d4a:  54 8c                  addq.l #$2, a4
  004d4c:  45 ea 00 22            lea.l $22(a2), a2
  004d50:  be 46                  cmp.w d6, d7
  004d52:  6e dc                  bgt.b $4d30
  004d54:  60 02                  bra.b $4d58
  004d56:  7a 94                  moveq #$94, d5
  004d58:  30 05                  move.w d5, d0
  004d5a:  4c df 1c e0            movem.l (a7)+, d5-d7/a2-a4
  004d5e:  4e 5e                  unlk a6
  004d60:  4e 75                  rts 
  004d62:  48 e7 01 18            movem.l d7/a3-a4, -(a7)
  004d66:  4a ad a7 82            tst.l -$587e(a5)
  004d6a:  67 26                  beq.b $4d92
  004d6c:  7e 00                  moveq #$0, d7
  004d6e:  97 cb                  suba.l a3, a3
  004d70:  60 14                  bra.b $4d86
  004d72:  20 4b                  movea.l a3, a0
  004d74:  d1 ed a7 82            adda.l -$587e(a5), a0
  004d78:  2f 08                  move.l a0, -(a7)
  004d7a:  4e ba ff 0e            jsr $4c8a(pc)
  004d7e:  58 8f                  addq.l #$4, a7
  004d80:  52 47                  addq.w #$1, d7
  004d82:  47 eb 00 22            lea.l $22(a3), a3
  004d86:  be 6d a7 80            cmp.w -$5880(a5), d7
  004d8a:  6d e6                  blt.b $4d72
  004d8c:  20 6d a7 82            movea.l -$587e(a5), a0
  004d90:  a0 1f                  dc.w $a01f
  004d92:  4c df 18 80            movem.l (a7)+, d7/a3-a4
  004d96:  4e 75                  rts 
  004d98:  4e 56 00 00            link.w a6, #$0
  004d9c:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  004da0:  26 6e 00 08            movea.l $8(a6), a3
  004da4:  28 4b                  movea.l a3, a4
  004da6:  d9 ee 00 0c            adda.l $c(a6), a4
  004daa:  60 0a                  bra.b $4db6
  004dac:  1e 13                  move.b (a3), d7
  004dae:  1c 14                  move.b (a4), d6
  004db0:  18 87                  move.b d7, (a4)
  004db2:  16 c6                  move.b d6, (a3)+
  004db4:  53 8c                  subq.l #$1, a4
  004db6:  b9 cb                  cmpa.l a3, a4
  004db8:  62 f2                  bhi.b $4dac
  004dba:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  004dbe:  4e 5e                  unlk a6
  004dc0:  4e 75                  rts 
  004dc2:  2f 07                  move.l d7, -(a7)
  004dc4:  7e 01                  moveq #$1, d7
  004dc6:  42 ad a8 0c            clr.l -$57f4(a5)
  004dca:  42 ad a8 28            clr.l -$57d8(a5)
  004dce:  42 ad a8 24            clr.l -$57dc(a5)
  004dd2:  1b 7c 00 3c a8 2d      move.b #$3c, -$57d3(a5)
  004dd8:  42 2d a8 2c            clr.b -$57d4(a5)
  004ddc:  42 67                  clr.w -(a7)
  004dde:  48 6d a8 0c            pea.l -$57f4(a5)
  004de2:  3f 3c 00 05            move.w #$5, -(a7)
  004de6:  48 78 00 8c            pea.l $8c.w
  004dea:  48 6d 01 a2            pea.l $1a2(a5)
  004dee:  a8 07                  dc.w $a807
  004df0:  4a 5f                  tst.w (a7)+
  004df2:  67 08                  beq.b $4dfc
  004df4:  7e 00                  moveq #$0, d7
  004df6:  42 ad a8 0c            clr.l -$57f4(a5)
  004dfa:  60 0c                  bra.b $4e08
  004dfc:  41 ed 01 a2            lea.l $1a2(a5), a0
  004e00:  22 6d a8 0c            movea.l -$57f4(a5), a1
  004e04:  23 48 00 08            move.l a0, $8(a1)
  004e08:  10 07                  move.b d7, d0
  004e0a:  2e 1f                  move.l (a7)+, d7
  004e0c:  4e 75                  rts 
  004e0e:  4a ad a8 0c            tst.l -$57f4(a5)
  004e12:  67 12                  beq.b $4e26
  004e14:  42 67                  clr.w -(a7)
  004e16:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  004e1a:  1f 3c 00 01            move.b #$1, -(a7)
  004e1e:  a8 01                  dc.w $a801
  004e20:  42 ad a8 0c            clr.l -$57f4(a5)
  004e24:  54 8f                  addq.l #$2, a7
  004e26:  4e 75                  rts 
  004e28:  4e 56 ff f0            link.w a6, #$fff0
  004e2c:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  004e30:  28 6e 00 08            movea.l $8(a6), a4
  004e34:  42 2d a8 02            clr.b -$57fe(a5)
  004e38:  7c 01                  moveq #$1, d6
  004e3a:  42 67                  clr.w -(a7)
  004e3c:  3f 3c 00 01            move.w #$1, -(a7)
  004e40:  48 6e ff f0            pea.l -$10(a6)
  004e44:  4e ba ec 0a            jsr $3a50(pc)
  004e48:  4a 5f                  tst.w (a7)+
  004e4a:  66 04                  bne.b $4e50
  004e4c:  3c 2e ff f4            move.w -$c(a6), d6
  004e50:  0c 46 06 00            cmpi.w #$600, d6
  004e54:  65 06                  bcs.b $4e5c
  004e56:  1b 7c 00 01 a8 02      move.b #$1, -$57fe(a5)
  004e5c:  3b 7c 00 03 a7 86      move.w #$3, -$587a(a5)
  004e62:  42 6d a7 88            clr.w -$5878(a5)
  004e66:  42 6d a7 dc            clr.w -$5824(a5)
  004e6a:  42 ad a7 c2            clr.l -$583e(a5)
  004e6e:  42 2d a7 8a            clr.b -$5876(a5)
  004e72:  42 2d a7 db            clr.b -$5825(a5)
  004e76:  1f 2e 00 0c            move.b $c(a6), -(a7)
  004e7a:  2f 0c                  move.l a4, -(a7)
  004e7c:  4e ba fe 64            jsr $4ce2(pc)
  004e80:  4a 40                  tst.w d0
  004e82:  5c 8f                  addq.l #$6, a7
  004e84:  66 7a                  bne.b $4f00
  004e86:  4a 2d a8 02            tst.b -$57fe(a5)
  004e8a:  67 10                  beq.b $4e9c
  004e8c:  4e ba ff 34            jsr $4dc2(pc)
  004e90:  72 00                  moveq #$0, d1
  004e92:  12 00                  move.b d0, d1
  004e94:  4a 41                  tst.w d1
  004e96:  66 3a                  bne.b $4ed2
  004e98:  42 2d a8 02            clr.b -$57fe(a5)
  004e9c:  70 07                  moveq #$7, d0
  004e9e:  a1 1e                  dc.w $a11e
  004ea0:  26 48                  movea.l a0, a3
  004ea2:  20 0b                  move.l a3, d0
  004ea4:  67 2c                  beq.b $4ed2
  004ea6:  42 53                  clr.w (a3)
  004ea8:  42 ab 00 02            clr.l $2(a3)
  004eac:  42 ad a7 9c            clr.l -$5864(a5)
  004eb0:  3b 7c ff fc a7 a8      move.w #$fffc, -$5858(a5)
  004eb6:  2b 4b a7 b0            move.l a3, -$5850(a5)
  004eba:  42 ad a7 b4            clr.l -$584c(a5)
  004ebe:  42 67                  clr.w -(a7)
  004ec0:  48 6d a7 90            pea.l -$5870(a5)
  004ec4:  1f 3c 00 01            move.b #$1, -(a7)
  004ec8:  4e ba ed 2a            jsr $3bf4(pc)
  004ecc:  20 4b                  movea.l a3, a0
  004ece:  a0 1f                  dc.w $a01f
  004ed0:  54 8f                  addq.l #$2, a7
  004ed2:  42 ad a8 04            clr.l -$57fc(a5)
  004ed6:  42 ad a8 08            clr.l -$57f8(a5)
  004eda:  41 ed 01 aa            lea.l $1aa(a5), a0
  004ede:  2b 48 a7 d2            move.l a0, -$582e(a5)
  004ee2:  3b 7c 00 01 a7 d6      move.w #$1, -$582a(a5)
  004ee8:  3b 7c 00 01 a7 d0      move.w #$1, -$5830(a5)
  004eee:  42 ad a7 cc            clr.l -$5834(a5)
  004ef2:  42 6d a7 d8            clr.w -$5828(a5)
  004ef6:  42 2d a7 da            clr.b -$5826(a5)
  004efa:  41 ed a7 cc            lea.l -$5834(a5), a0
  004efe:  a0 33                  dc.w $a033
  004f00:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  004f04:  4e 5e                  unlk a6
  004f06:  4e 75                  rts 
  004f08:  4a 2d a7 8a            tst.b -$5876(a5)
  004f0c:  66 0a                  bne.b $4f18
  004f0e:  4e ba 06 72            jsr $5582(pc)
  004f12:  41 ed a7 cc            lea.l -$5834(a5), a0
  004f16:  a0 34                  dc.w $a034
  004f18:  42 2d a7 8a            clr.b -$5876(a5)
  004f1c:  4a 2d a8 02            tst.b -$57fe(a5)
  004f20:  67 04                  beq.b $4f26
  004f22:  4e ba fe ea            jsr $4e0e(pc)
  004f26:  4e ba fe 3a            jsr $4d62(pc)
  004f2a:  4e 75                  rts 
  004f2c:  4a 2d a7 8a            tst.b -$5876(a5)
  004f30:  66 20                  bne.b $4f52
  004f32:  2b 6d a7 c2 a7 8c      move.l -$583e(a5), -$5874(a5)
  004f38:  4e ba 06 48            jsr $5582(pc)
  004f3c:  41 ed a7 cc            lea.l -$5834(a5), a0
  004f40:  a0 34                  dc.w $a034
  004f42:  1b 7c 00 01 a7 8a      move.b #$1, -$5876(a5)
  004f48:  4a 2d a8 02            tst.b -$57fe(a5)
  004f4c:  67 04                  beq.b $4f52
  004f4e:  4e ba fe be            jsr $4e0e(pc)
  004f52:  4e 75                  rts 
  004f54:  4a 2d a7 8a            tst.b -$5876(a5)
  004f58:  67 22                  beq.b $4f7c
  004f5a:  42 2d a7 8a            clr.b -$5876(a5)
  004f5e:  2b 6d a7 8c a7 c2      move.l -$5874(a5), -$583e(a5)
  004f64:  4a 2d a8 02            tst.b -$57fe(a5)
  004f68:  67 08                  beq.b $4f72
  004f6a:  4e ba fe 56            jsr $4dc2(pc)
  004f6e:  1b 40 a8 02            move.b d0, -$57fe(a5)
  004f72:  42 2d a7 da            clr.b -$5826(a5)
  004f76:  41 ed a7 cc            lea.l -$5834(a5), a0
  004f7a:  a0 33                  dc.w $a033
  004f7c:  4e 75                  rts 
  004f7e:  4e 56 ff fc            link.w a6, #$fffc
  004f82:  48 e7 07 38            movem.l d5-d7/a2-a4, -(a7)
  004f86:  24 6e 00 08            movea.l $8(a6), a2
  004f8a:  28 4a                  movea.l a2, a4
  004f8c:  7e 00                  moveq #$0, d7
  004f8e:  60 02                  bra.b $4f92
  004f90:  52 47                  addq.w #$1, d7
  004f92:  0c 5c ff ff            cmpi.w #$ffff, (a4)+
  004f96:  66 f8                  bne.b $4f90
  004f98:  7a 22                  moveq #$22, d5
  004f9a:  cb c7                  muls.w d7, d5
  004f9c:  4a 47                  tst.w d7
  004f9e:  6f 74                  ble.b $5014
  004fa0:  7c 00                  moveq #$0, d6
  004fa2:  99 cc                  suba.l a4, a4
  004fa4:  60 64                  bra.b $500a
  004fa6:  1f 3c 00 01            move.b #$1, -(a7)
  004faa:  a9 9b                  dc.w $a99b
  004fac:  42 a7                  clr.l -(a7)
  004fae:  2f 3c 63 73 6e 64      move.l #$63736e64, -(a7)
  004fb4:  20 4a                  movea.l a2, a0
  004fb6:  d1 cc                  adda.l a4, a0
  004fb8:  3f 10                  move.w (a0), -(a7)
  004fba:  a9 a0                  dc.w $a9a0
  004fbc:  26 5f                  movea.l (a7)+, a3
  004fbe:  20 0b                  move.l a3, d0
  004fc0:  66 26                  bne.b $4fe8
  004fc2:  42 27                  clr.b -(a7)
  004fc4:  a9 9b                  dc.w $a99b
  004fc6:  42 a7                  clr.l -(a7)
  004fc8:  2f 3c 73 6e 64 20      move.l #$736e6420, -(a7)
  004fce:  20 4a                  movea.l a2, a0
  004fd0:  d1 cc                  adda.l a4, a0
  004fd2:  3f 10                  move.w (a0), -(a7)
  004fd4:  a9 a0                  dc.w $a9a0
  004fd6:  26 5f                  movea.l (a7)+, a3
  004fd8:  20 0b                  move.l a3, d0
  004fda:  67 22                  beq.b $4ffe
  004fdc:  42 a7                  clr.l -(a7)
  004fde:  2f 0b                  move.l a3, -(a7)
  004fe0:  a9 a5                  dc.w $a9a5
  004fe2:  2d 5f ff fc            move.l (a7)+, -$4(a6)
  004fe6:  60 16                  bra.b $4ffe
  004fe8:  20 4b                  movea.l a3, a0
  004fea:  a0 29                  dc.w $a029
  004fec:  43 ee ff fc            lea.l -$4(a6), a1
  004ff0:  70 04                  moveq #$4, d0
  004ff2:  20 53                  movea.l (a3), a0
  004ff4:  a0 2e                  dc.w $a02e
  004ff6:  20 4b                  movea.l a3, a0
  004ff8:  a0 2a                  dc.w $a02a
  004ffa:  2f 0b                  move.l a3, -(a7)
  004ffc:  a9 a3                  dc.w $a9a3
  004ffe:  20 0b                  move.l a3, d0
  005000:  67 04                  beq.b $5006
  005002:  da ae ff fc            add.l -$4(a6), d5
  005006:  52 46                  addq.w #$1, d6
  005008:  54 8c                  addq.l #$2, a4
  00500a:  be 46                  cmp.w d6, d7
  00500c:  6e 98                  bgt.b $4fa6
  00500e:  1f 3c 00 01            move.b #$1, -(a7)
  005012:  a9 9b                  dc.w $a99b
  005014:  20 05                  move.l d5, d0
  005016:  4c df 1c e0            movem.l (a7)+, d5-d7/a2-a4
  00501a:  4e 5e                  unlk a6
  00501c:  4e 75                  rts 
  00501e:  4e 56 00 00            link.w a6, #$0
  005022:  48 e7 00 18            movem.l a3-a4, -(a7)
  005026:  99 cc                  suba.l a4, a4
  005028:  3f 2e 00 08            move.w $8(a6), -(a7)
  00502c:  4e ba f8 1e            jsr $484c(pc)
  005030:  26 40                  movea.l d0, a3
  005032:  20 0b                  move.l a3, d0
  005034:  54 8f                  addq.l #$2, a7
  005036:  67 10                  beq.b $5048
  005038:  4a 2d a8 02            tst.b -$57fe(a5)
  00503c:  67 06                  beq.b $5044
  00503e:  28 6b 00 0a            movea.l $a(a3), a4
  005042:  60 04                  bra.b $5048
  005044:  28 6b 00 1e            movea.l $1e(a3), a4
  005048:  20 0c                  move.l a4, d0
  00504a:  4c df 18 00            movem.l (a7)+, a3-a4
  00504e:  4e 5e                  unlk a6
  005050:  4e 75                  rts 
  005052:  4e 56 00 00            link.w a6, #$0
  005056:  48 e7 01 08            movem.l d7/a4, -(a7)
  00505a:  7e 00                  moveq #$0, d7
  00505c:  3f 2e 00 08            move.w $8(a6), -(a7)
  005060:  4e ba f7 ea            jsr $484c(pc)
  005064:  28 40                  movea.l d0, a4
  005066:  20 0c                  move.l a4, d0
  005068:  54 8f                  addq.l #$2, a7
  00506a:  67 04                  beq.b $5070
  00506c:  2e 2c 00 0e            move.l $e(a4), d7
  005070:  20 07                  move.l d7, d0
  005072:  4c df 10 80            movem.l (a7)+, d7/a4
  005076:  4e 5e                  unlk a6
  005078:  4e 75                  rts 
  00507a:  4e 56 00 00            link.w a6, #$0
  00507e:  3f 2e 00 08            move.w $8(a6), -(a7)
  005082:  4e ba ff ce            jsr $5052(pc)
  005086:  2f 00                  move.l d0, -(a7)
  005088:  3f 2e 00 0a            move.w $a(a6), -(a7)
  00508c:  4e ba f8 16            jsr $48a4(pc)
  005090:  4e 5e                  unlk a6
  005092:  4e 75                  rts 
  005094:  4e 56 00 00            link.w a6, #$0
  005098:  48 e7 01 08            movem.l d7/a4, -(a7)
  00509c:  7e 00                  moveq #$0, d7
  00509e:  3f 2e 00 08            move.w $8(a6), -(a7)
  0050a2:  4e ba f7 a8            jsr $484c(pc)
  0050a6:  28 40                  movea.l d0, a4
  0050a8:  20 0c                  move.l a4, d0
  0050aa:  54 8f                  addq.l #$2, a7
  0050ac:  67 04                  beq.b $50b2
  0050ae:  3e 2c 00 1c            move.w $1c(a4), d7
  0050b2:  30 07                  move.w d7, d0
  0050b4:  4c df 10 80            movem.l (a7)+, d7/a4
  0050b8:  4e 5e                  unlk a6
  0050ba:  4e 75                  rts 
  0050bc:  4e 56 00 00            link.w a6, #$0
  0050c0:  3b 6e 00 08 a7 86      move.w $8(a6), -$587a(a5)
  0050c6:  4e 5e                  unlk a6
  0050c8:  4e 75                  rts 
  0050ca:  4e 56 00 00            link.w a6, #$0
  0050ce:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  0050d2:  28 6e 00 08            movea.l $8(a6), a4
  0050d6:  2c 2e 00 0c            move.l $c(a6), d6
  0050da:  3a 2e 00 10            move.w $10(a6), d5
  0050de:  20 0c                  move.l a4, d0
  0050e0:  67 00 00 d2            beq.w $51b4
  0050e4:  4a 2d a7 8a            tst.b -$5876(a5)
  0050e8:  66 00 00 ca            bne.w $51b4
  0050ec:  4a 6d a7 88            tst.w -$5878(a5)
  0050f0:  6f 08                  ble.b $50fa
  0050f2:  4a ad a7 c2            tst.l -$583e(a5)
  0050f6:  67 00 00 bc            beq.w $51b4
  0050fa:  3b 6d a7 86 a7 88      move.w -$587a(a5), -$5878(a5)
  005100:  2f 06                  move.l d6, -(a7)
  005102:  3f 05                  move.w d5, -(a7)
  005104:  4e ba f7 9e            jsr $48a4(pc)
  005108:  48 c0                  ext.l d0
  00510a:  2e 00                  move.l d0, d7
  00510c:  4a 2d a7 db            tst.b -$5825(a5)
  005110:  5c 8f                  addq.l #$6, a7
  005112:  66 12                  bne.b $5126
  005114:  18 2d a7 e6            move.b -$581a(a5), d4
  005118:  4e ba 04 68            jsr $5582(pc)
  00511c:  1b 44 a7 e6            move.b d4, -$581a(a5)
  005120:  3b 47 a7 dc            move.w d7, -$5824(a5)
  005124:  60 04                  bra.b $512a
  005126:  df 6d a7 dc            add.w d7, -$5824(a5)
  00512a:  2b 6d a7 fe a7 de      move.l -$5802(a5), -$5822(a5)
  005130:  4a 2d a8 02            tst.b -$57fe(a5)
  005134:  67 44                  beq.b $517a
  005136:  41 ec 00 06            lea.l $6(a4), a0
  00513a:  2b 48 a8 18            move.l a0, -$57e8(a5)
  00513e:  2b 46 a8 1c            move.l d6, -$57e4(a5)
  005142:  42 ad a8 24            clr.l -$57dc(a5)
  005146:  42 ad a8 28            clr.l -$57d8(a5)
  00514a:  20 05                  move.l d5, d0
  00514c:  48 c0                  ext.l d0
  00514e:  72 10                  moveq #$10, d1
  005150:  e3 a8                  lsl.l d1, d0
  005152:  2b 40 a8 20            move.l d0, -$57e0(a5)
  005156:  42 6d a8 12            clr.w -$57ee(a5)
  00515a:  41 ed a8 18            lea.l -$57e8(a5), a0
  00515e:  2b 48 a8 14            move.l a0, -$57ec(a5)
  005162:  3b 7c 00 51 a8 10      move.w #$51, -$57f0(a5)
  005168:  42 67                  clr.w -(a7)
  00516a:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  00516e:  48 6d a8 10            pea.l -$57f0(a5)
  005172:  42 27                  clr.b -(a7)
  005174:  a8 03                  dc.w $a803
  005176:  54 8f                  addq.l #$2, a7
  005178:  60 3a                  bra.b $51b4
  00517a:  42 54                  clr.w (a4)
  00517c:  42 a7                  clr.l -(a7)
  00517e:  30 45                  movea.w d5, a0
  005180:  2f 08                  move.l a0, -(a7)
  005182:  2f 3c 00 02 f9 b8      move.l #$2f9b8, -(a7)
  005188:  a8 68                  dc.w $a868
  00518a:  29 5f 00 02            move.l (a7)+, $2(a4)
  00518e:  41 ed 01 b2            lea.l $1b2(a5), a0
  005192:  2b 48 a7 9c            move.l a0, -$5864(a5)
  005196:  3b 7c ff fc a7 a8      move.w #$fffc, -$5858(a5)
  00519c:  2b 4c a7 b0            move.l a4, -$5850(a5)
  0051a0:  2b 46 a7 b4            move.l d6, -$584c(a5)
  0051a4:  42 67                  clr.w -(a7)
  0051a6:  48 6d a7 90            pea.l -$5870(a5)
  0051aa:  1f 3c 00 01            move.b #$1, -(a7)
  0051ae:  4e ba ea 44            jsr $3bf4(pc)
  0051b2:  54 8f                  addq.l #$2, a7
  0051b4:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  0051b8:  4e 5e                  unlk a6
  0051ba:  4e 75                  rts 
  0051bc:  4e 56 00 00            link.w a6, #$0
  0051c0:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  0051c4:  3c 2e 00 0a            move.w $a(a6), d6
  0051c8:  4a 2d a7 8a            tst.b -$5876(a5)
  0051cc:  66 50                  bne.b $521e
  0051ce:  42 2d a7 db            clr.b -$5825(a5)
  0051d2:  3f 2e 00 08            move.w $8(a6), -(a7)
  0051d6:  4e ba f6 74            jsr $484c(pc)
  0051da:  28 40                  movea.l d0, a4
  0051dc:  20 0c                  move.l a4, d0
  0051de:  54 8f                  addq.l #$2, a7
  0051e0:  67 3c                  beq.b $521e
  0051e2:  4a 14                  tst.b (a4)
  0051e4:  6a 12                  bpl.b $51f8
  0051e6:  2f 2c 00 0e            move.l $e(a4), -(a7)
  0051ea:  2f 2c 00 0a            move.l $a(a4), -(a7)
  0051ee:  4e ba fb a8            jsr $4d98(pc)
  0051f2:  08 94 00 07            bclr.b #$7, (a4)
  0051f6:  50 8f                  addq.l #$8, a7
  0051f8:  4a 46                  tst.w d6
  0051fa:  66 04                  bne.b $5200
  0051fc:  3c 2c 00 1c            move.w $1c(a4), d6
  005200:  2e 2c 00 0e            move.l $e(a4), d7
  005204:  70 fa                  moveq #$fa, d0
  005206:  d0 ac 00 0a            add.l $a(a4), d0
  00520a:  26 40                  movea.l d0, a3
  00520c:  42 2d a7 e6            clr.b -$581a(a5)
  005210:  3f 06                  move.w d6, -(a7)
  005212:  2f 07                  move.l d7, -(a7)
  005214:  2f 0b                  move.l a3, -(a7)
  005216:  4e ba fe b2            jsr $50ca(pc)
  00521a:  4f ef 00 0a            lea.l $a(a7), a7
  00521e:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  005222:  4e 5e                  unlk a6
  005224:  4e 75                  rts 
  005226:  4e 56 00 00            link.w a6, #$0
  00522a:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  00522e:  3c 2e 00 0a            move.w $a(a6), d6
  005232:  4a 2d a7 8a            tst.b -$5876(a5)
  005236:  66 50                  bne.b $5288
  005238:  42 2d a7 db            clr.b -$5825(a5)
  00523c:  3f 2e 00 08            move.w $8(a6), -(a7)
  005240:  4e ba f6 0a            jsr $484c(pc)
  005244:  28 40                  movea.l d0, a4
  005246:  20 0c                  move.l a4, d0
  005248:  54 8f                  addq.l #$2, a7
  00524a:  67 3c                  beq.b $5288
  00524c:  4a 14                  tst.b (a4)
  00524e:  6b 12                  bmi.b $5262
  005250:  2f 2c 00 0e            move.l $e(a4), -(a7)
  005254:  2f 2c 00 0a            move.l $a(a4), -(a7)
  005258:  4e ba fb 3e            jsr $4d98(pc)
  00525c:  08 d4 00 07            bset.b #$7, (a4)
  005260:  50 8f                  addq.l #$8, a7
  005262:  4a 46                  tst.w d6
  005264:  66 04                  bne.b $526a
  005266:  3c 2c 00 1c            move.w $1c(a4), d6
  00526a:  2e 2c 00 0e            move.l $e(a4), d7
  00526e:  70 fa                  moveq #$fa, d0
  005270:  d0 ac 00 0a            add.l $a(a4), d0
  005274:  26 40                  movea.l d0, a3
  005276:  42 2d a7 e6            clr.b -$581a(a5)
  00527a:  3f 06                  move.w d6, -(a7)
  00527c:  2f 07                  move.l d7, -(a7)
  00527e:  2f 0b                  move.l a3, -(a7)
  005280:  4e ba fe 48            jsr $50ca(pc)
  005284:  4f ef 00 0a            lea.l $a(a7), a7
  005288:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  00528c:  4e 5e                  unlk a6
  00528e:  4e 75                  rts 
  005290:  4e 56 00 00            link.w a6, #$0
  005294:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  005298:  3c 2e 00 0a            move.w $a(a6), d6
  00529c:  2a 2e 00 10            move.l $10(a6), d5
  0052a0:  4a 2d a7 8a            tst.b -$5876(a5)
  0052a4:  66 68                  bne.b $530e
  0052a6:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  0052ac:  3f 2e 00 08            move.w $8(a6), -(a7)
  0052b0:  4e ba f5 9a            jsr $484c(pc)
  0052b4:  28 40                  movea.l d0, a4
  0052b6:  20 0c                  move.l a4, d0
  0052b8:  54 8f                  addq.l #$2, a7
  0052ba:  67 52                  beq.b $530e
  0052bc:  4a 14                  tst.b (a4)
  0052be:  6a 12                  bpl.b $52d2
  0052c0:  2f 2c 00 0e            move.l $e(a4), -(a7)
  0052c4:  2f 2c 00 0a            move.l $a(a4), -(a7)
  0052c8:  4e ba fa ce            jsr $4d98(pc)
  0052cc:  08 94 00 07            bclr.b #$7, (a4)
  0052d0:  50 8f                  addq.l #$8, a7
  0052d2:  4a 46                  tst.w d6
  0052d4:  66 04                  bne.b $52da
  0052d6:  3c 2c 00 1c            move.w $1c(a4), d6
  0052da:  70 ff                  moveq #$ff, d0
  0052dc:  b0 85                  cmp.l d5, d0
  0052de:  67 06                  beq.b $52e6
  0052e0:  ba ac 00 0e            cmp.l $e(a4), d5
  0052e4:  6f 04                  ble.b $52ea
  0052e6:  2a 2c 00 0e            move.l $e(a4), d5
  0052ea:  2e 05                  move.l d5, d7
  0052ec:  9e ae 00 0c            sub.l $c(a6), d7
  0052f0:  70 fa                  moveq #$fa, d0
  0052f2:  d0 ae 00 0c            add.l $c(a6), d0
  0052f6:  d0 ac 00 0a            add.l $a(a4), d0
  0052fa:  26 40                  movea.l d0, a3
  0052fc:  42 2d a7 e6            clr.b -$581a(a5)
  005300:  3f 06                  move.w d6, -(a7)
  005302:  2f 07                  move.l d7, -(a7)
  005304:  2f 0b                  move.l a3, -(a7)
  005306:  4e ba fd c2            jsr $50ca(pc)
  00530a:  4f ef 00 0a            lea.l $a(a7), a7
  00530e:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  005312:  4e 5e                  unlk a6
  005314:  4e 75                  rts 
  005316:  4e 56 00 00            link.w a6, #$0
  00531a:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  00531e:  3e 2e 00 0a            move.w $a(a6), d7
  005322:  26 2e 00 0c            move.l $c(a6), d3
  005326:  28 2e 00 10            move.l $10(a6), d4
  00532a:  4a 2d a7 8a            tst.b -$5876(a5)
  00532e:  66 00 00 b8            bne.w $53e8
  005332:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  005338:  3f 2e 00 08            move.w $8(a6), -(a7)
  00533c:  4e ba f5 0e            jsr $484c(pc)
  005340:  28 40                  movea.l d0, a4
  005342:  20 0c                  move.l a4, d0
  005344:  54 8f                  addq.l #$2, a7
  005346:  67 00 00 a0            beq.w $53e8
  00534a:  4a 14                  tst.b (a4)
  00534c:  6a 12                  bpl.b $5360
  00534e:  2f 2c 00 0e            move.l $e(a4), -(a7)
  005352:  2f 2c 00 0a            move.l $a(a4), -(a7)
  005356:  4e ba fa 40            jsr $4d98(pc)
  00535a:  08 94 00 07            bclr.b #$7, (a4)
  00535e:  50 8f                  addq.l #$8, a7
  005360:  4a 47                  tst.w d7
  005362:  66 04                  bne.b $5368
  005364:  3e 2c 00 1c            move.w $1c(a4), d7
  005368:  2a 2c 00 0e            move.l $e(a4), d5
  00536c:  2c 05                  move.l d5, d6
  00536e:  70 fa                  moveq #$fa, d0
  005370:  d0 ac 00 0a            add.l $a(a4), d0
  005374:  26 40                  movea.l d0, a3
  005376:  ba 84                  cmp.l d4, d5
  005378:  6c 02                  bge.b $537c
  00537a:  28 05                  move.l d5, d4
  00537c:  1b 7c 00 01 a7 e6      move.b #$1, -$581a(a5)
  005382:  2b 43 a7 f0            move.l d3, -$5810(a5)
  005386:  2b 44 a7 f4            move.l d4, -$580c(a5)
  00538a:  3b 47 a7 e4            move.w d7, -$581c(a5)
  00538e:  2f 03                  move.l d3, -(a7)
  005390:  3f 07                  move.w d7, -(a7)
  005392:  4e ba f5 10            jsr $48a4(pc)
  005396:  30 40                  movea.w d0, a0
  005398:  2b 48 a7 e8            move.l a0, -$5818(a5)
  00539c:  2e 84                  move.l d4, (a7)
  00539e:  3f 07                  move.w d7, -(a7)
  0053a0:  4e ba f5 02            jsr $48a4(pc)
  0053a4:  30 40                  movea.w d0, a0
  0053a6:  91 ed a7 e8            suba.l -$5818(a5), a0
  0053aa:  2b 48 a7 ec            move.l a0, -$5814(a5)
  0053ae:  4a 2d a8 02            tst.b -$57fe(a5)
  0053b2:  50 8f                  addq.l #$8, a7
  0053b4:  67 08                  beq.b $53be
  0053b6:  5b ad a7 e8            subq.l #$5, -$5818(a5)
  0053ba:  5b ad a7 ec            subq.l #$5, -$5814(a5)
  0053be:  3b 6e 00 08 a7 e2      move.w $8(a6), -$581e(a5)
  0053c4:  3b 7c ff ff a7 f8      move.w #$ffff, -$5808(a5)
  0053ca:  42 ad a7 fa            clr.l -$5806(a5)
  0053ce:  2c 04                  move.l d4, d6
  0053d0:  9c 83                  sub.l d3, d6
  0053d2:  26 6c 00 0a            movea.l $a(a4), a3
  0053d6:  47 f3 38 fa            lea.l -$6(a3, d3.l), a3
  0053da:  3f 07                  move.w d7, -(a7)
  0053dc:  2f 06                  move.l d6, -(a7)
  0053de:  2f 0b                  move.l a3, -(a7)
  0053e0:  4e ba fc e8            jsr $50ca(pc)
  0053e4:  4f ef 00 0a            lea.l $a(a7), a7
  0053e8:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  0053ec:  4e 5e                  unlk a6
  0053ee:  4e 75                  rts 
  0053f0:  4e 56 00 00            link.w a6, #$0
  0053f4:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  0053f8:  3e 2e 00 0a            move.w $a(a6), d7
  0053fc:  4a 2d a7 8a            tst.b -$5876(a5)
  005400:  66 00 00 a6            bne.w $54a8
  005404:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  00540a:  3f 2e 00 08            move.w $8(a6), -(a7)
  00540e:  4e ba f4 3c            jsr $484c(pc)
  005412:  28 40                  movea.l d0, a4
  005414:  20 0c                  move.l a4, d0
  005416:  54 8f                  addq.l #$2, a7
  005418:  67 00 00 8e            beq.w $54a8
  00541c:  4a 14                  tst.b (a4)
  00541e:  6a 12                  bpl.b $5432
  005420:  2f 2c 00 0e            move.l $e(a4), -(a7)
  005424:  2f 2c 00 0a            move.l $a(a4), -(a7)
  005428:  4e ba f9 6e            jsr $4d98(pc)
  00542c:  08 94 00 07            bclr.b #$7, (a4)
  005430:  50 8f                  addq.l #$8, a7
  005432:  4a 47                  tst.w d7
  005434:  66 04                  bne.b $543a
  005436:  3e 2c 00 1c            move.w $1c(a4), d7
  00543a:  42 2d a7 e6            clr.b -$581a(a5)
  00543e:  2b 6c 00 12 a7 f0      move.l $12(a4), -$5810(a5)
  005444:  2b 6c 00 16 a7 f4      move.l $16(a4), -$580c(a5)
  00544a:  3a 2d a7 86            move.w -$587a(a5), d5
  00544e:  42 6d a7 86            clr.w -$587a(a5)
  005452:  42 6d a7 88            clr.w -$5878(a5)
  005456:  2c 2d a7 f4            move.l -$580c(a5), d6
  00545a:  70 fa                  moveq #$fa, d0
  00545c:  d0 ac 00 0a            add.l $a(a4), d0
  005460:  26 40                  movea.l d0, a3
  005462:  3f 07                  move.w d7, -(a7)
  005464:  2f 06                  move.l d6, -(a7)
  005466:  2f 0b                  move.l a3, -(a7)
  005468:  4e ba fc 60            jsr $50ca(pc)
  00546c:  70 fa                  moveq #$fa, d0
  00546e:  d0 ad a7 f0            add.l -$5810(a5), d0
  005472:  d0 ac 00 0a            add.l $a(a4), d0
  005476:  26 40                  movea.l d0, a3
  005478:  2c 2d a7 f4            move.l -$580c(a5), d6
  00547c:  9c ad a7 f0            sub.l -$5810(a5), d6
  005480:  4f ef 00 0a            lea.l $a(a7), a7
  005484:  60 0e                  bra.b $5494
  005486:  3f 07                  move.w d7, -(a7)
  005488:  2f 06                  move.l d6, -(a7)
  00548a:  2f 0b                  move.l a3, -(a7)
  00548c:  4e ba fc 3c            jsr $50ca(pc)
  005490:  4f ef 00 0a            lea.l $a(a7), a7
  005494:  30 2e 00 0c            move.w $c(a6), d0
  005498:  53 6e 00 0c            subq.w #$1, $c(a6)
  00549c:  4a 40                  tst.w d0
  00549e:  66 e6                  bne.b $5486
  0054a0:  3b 45 a7 86            move.w d5, -$587a(a5)
  0054a4:  42 2d a7 db            clr.b -$5825(a5)
  0054a8:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  0054ac:  4e 5e                  unlk a6
  0054ae:  4e 75                  rts 
  0054b0:  4e 56 00 00            link.w a6, #$0
  0054b4:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  0054b8:  3e 2e 00 0a            move.w $a(a6), d7
  0054bc:  7a ff                  moveq #$ff, d5
  0054be:  2b 6e 00 0c a7 fa      move.l $c(a6), -$5806(a5)
  0054c4:  4a 2d a7 8a            tst.b -$5876(a5)
  0054c8:  66 00 00 b0            bne.w $557a
  0054cc:  1b 7c 00 01 a7 db      move.b #$1, -$5825(a5)
  0054d2:  3f 2e 00 08            move.w $8(a6), -(a7)
  0054d6:  4e ba f3 74            jsr $484c(pc)
  0054da:  28 40                  movea.l d0, a4
  0054dc:  20 0c                  move.l a4, d0
  0054de:  54 8f                  addq.l #$2, a7
  0054e0:  67 00 00 98            beq.w $557a
  0054e4:  4a 14                  tst.b (a4)
  0054e6:  6a 12                  bpl.b $54fa
  0054e8:  2f 2c 00 0e            move.l $e(a4), -(a7)
  0054ec:  2f 2c 00 0a            move.l $a(a4), -(a7)
  0054f0:  4e ba f8 a6            jsr $4d98(pc)
  0054f4:  08 94 00 07            bclr.b #$7, (a4)
  0054f8:  50 8f                  addq.l #$8, a7
  0054fa:  4a 47                  tst.w d7
  0054fc:  66 04                  bne.b $5502
  0054fe:  3e 2c 00 1c            move.w $1c(a4), d7
  005502:  1b 7c 00 01 a7 e6      move.b #$1, -$581a(a5)
  005508:  2b 6c 00 12 a7 f0      move.l $12(a4), -$5810(a5)
  00550e:  2b 6c 00 16 a7 f4      move.l $16(a4), -$580c(a5)
  005514:  2c 2d a7 f4            move.l -$580c(a5), d6
  005518:  70 fa                  moveq #$fa, d0
  00551a:  d0 ac 00 0a            add.l $a(a4), d0
  00551e:  26 40                  movea.l d0, a3
  005520:  3b 47 a7 e4            move.w d7, -$581c(a5)
  005524:  2f 2d a7 f0            move.l -$5810(a5), -(a7)
  005528:  3f 07                  move.w d7, -(a7)
  00552a:  4e ba f3 78            jsr $48a4(pc)
  00552e:  30 40                  movea.w d0, a0
  005530:  2b 48 a7 e8            move.l a0, -$5818(a5)
  005534:  2e ad a7 f4            move.l -$580c(a5), (a7)
  005538:  3f 07                  move.w d7, -(a7)
  00553a:  4e ba f3 68            jsr $48a4(pc)
  00553e:  30 40                  movea.w d0, a0
  005540:  2b 48 a7 ec            move.l a0, -$5814(a5)
  005544:  4a 2d a8 02            tst.b -$57fe(a5)
  005548:  50 8f                  addq.l #$8, a7
  00554a:  67 08                  beq.b $5554
  00554c:  5b ad a7 e8            subq.l #$5, -$5818(a5)
  005550:  5b ad a7 ec            subq.l #$5, -$5814(a5)
  005554:  3b 6e 00 08 a7 e2      move.w $8(a6), -$581e(a5)
  00555a:  3b 45 a7 f8            move.w d5, -$5808(a5)
  00555e:  0c 45 ff ff            cmpi.w #$ffff, d5
  005562:  67 08                  beq.b $556c
  005564:  42 ad a7 fa            clr.l -$5806(a5)
  005568:  53 6d a7 f8            subq.w #$1, -$5808(a5)
  00556c:  3f 07                  move.w d7, -(a7)
  00556e:  2f 06                  move.l d6, -(a7)
  005570:  2f 0b                  move.l a3, -(a7)
  005572:  4e ba fb 56            jsr $50ca(pc)
  005576:  4f ef 00 0a            lea.l $a(a7), a7
  00557a:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  00557e:  4e 5e                  unlk a6
  005580:  4e 75                  rts 
  005582:  4a 2d a7 8a            tst.b -$5876(a5)
  005586:  66 60                  bne.b $55e8
  005588:  42 2d a7 db            clr.b -$5825(a5)
  00558c:  42 ad a7 c2            clr.l -$583e(a5)
  005590:  42 6d a7 dc            clr.w -$5824(a5)
  005594:  42 2d a7 e6            clr.b -$581a(a5)
  005598:  4a 2d a8 02            tst.b -$57fe(a5)
  00559c:  67 28                  beq.b $55c6
  00559e:  3b 7c 00 04 a8 10      move.w #$4, -$57f0(a5)
  0055a4:  42 67                  clr.w -(a7)
  0055a6:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  0055aa:  48 6d a8 10            pea.l -$57f0(a5)
  0055ae:  a8 04                  dc.w $a804
  0055b0:  3b 7c 00 03 a8 10      move.w #$3, -$57f0(a5)
  0055b6:  42 57                  clr.w (a7)
  0055b8:  2f 2d a8 0c            move.l -$57f4(a5), -(a7)
  0055bc:  48 6d a8 10            pea.l -$57f0(a5)
  0055c0:  a8 04                  dc.w $a804
  0055c2:  54 8f                  addq.l #$2, a7
  0055c4:  60 22                  bra.b $55e8
  0055c6:  42 ad a7 9c            clr.l -$5864(a5)
  0055ca:  3b 7c ff fc a7 a8      move.w #$fffc, -$5858(a5)
  0055d0:  42 ad a7 b0            clr.l -$5850(a5)
  0055d4:  42 ad a7 b4            clr.l -$584c(a5)
  0055d8:  42 67                  clr.w -(a7)
  0055da:  48 6d a7 90            pea.l -$5870(a5)
  0055de:  1f 3c 00 01            move.b #$1, -(a7)
  0055e2:  4e ba e6 22            jsr $3c06(pc)
  0055e6:  54 8f                  addq.l #$2, a7
  0055e8:  4e 75                  rts 
  0055ea:  4a 6d a7 dc            tst.w -$5824(a5)
  0055ee:  6f 04                  ble.b $55f4
  0055f0:  70 00                  moveq #$0, d0
  0055f2:  60 02                  bra.b $55f6
  0055f4:  70 01                  moveq #$1, d0
  0055f6:  4e 75                  rts 
  0055f8:  4e 56 00 00            link.w a6, #$0
  0055fc:  48 e7 03 38            movem.l d6-d7/a2-a4, -(a7)
  005600:  26 6e 00 08            movea.l $8(a6), a3
  005604:  3c 2e 00 0c            move.w $c(a6), d6
  005608:  4a 2d a7 8a            tst.b -$5876(a5)
  00560c:  66 30                  bne.b $563e
  00560e:  4e ba ff 72            jsr $5582(pc)
  005612:  7e 00                  moveq #$0, d7
  005614:  95 ca                  suba.l a2, a2
  005616:  60 12                  bra.b $562a
  005618:  20 4b                  movea.l a3, a0
  00561a:  d1 ca                  adda.l a2, a0
  00561c:  3f 10                  move.w (a0), -(a7)
  00561e:  4e ba f2 2c            jsr $484c(pc)
  005622:  28 40                  movea.l d0, a4
  005624:  54 8f                  addq.l #$2, a7
  005626:  52 47                  addq.w #$1, d7
  005628:  5c 8a                  addq.l #$6, a2
  00562a:  bc 47                  cmp.w d7, d6
  00562c:  6e ea                  bgt.b $5618
  00562e:  42 6d a7 c6            clr.w -$583a(a5)
  005632:  42 6d a7 ca            clr.w -$5836(a5)
  005636:  3b 46 a7 c8            move.w d6, -$5838(a5)
  00563a:  2b 4b a7 c2            move.l a3, -$583e(a5)
  00563e:  4c df 1c c0            movem.l (a7)+, d6-d7/a2-a4
  005642:  4e 5e                  unlk a6
  005644:  4e 75                  rts 
  005646:  2f 07                  move.l d7, -(a7)
  005648:  7e 00                  moveq #$0, d7
  00564a:  4a 2d a7 8a            tst.b -$5876(a5)
  00564e:  66 08                  bne.b $5658
  005650:  4a ad a7 c2            tst.l -$583e(a5)
  005654:  66 02                  bne.b $5658
  005656:  7e 01                  moveq #$1, d7
  005658:  10 07                  move.b d7, d0
  00565a:  2e 1f                  move.l (a7)+, d7
  00565c:  4e 75                  rts 
  00565e:  4e 56 00 00            link.w a6, #$0
  005662:  48 e7 01 08            movem.l d7/a4, -(a7)
  005666:  7e 00                  moveq #$0, d7
  005668:  99 cc                  suba.l a4, a4
  00566a:  60 1c                  bra.b $5688
  00566c:  a0 1c                  dc.w $a01c
  00566e:  b0 ae 00 08            cmp.l $8(a6), d0
  005672:  64 0e                  bcc.b $5682
  005674:  20 4c                  movea.l a4, a0
  005676:  d1 ed a7 82            adda.l -$587e(a5), a0
  00567a:  2f 08                  move.l a0, -(a7)
  00567c:  4e ba f6 0c            jsr $4c8a(pc)
  005680:  58 8f                  addq.l #$4, a7
  005682:  52 47                  addq.w #$1, d7
  005684:  49 ec 00 22            lea.l $22(a4), a4
  005688:  be 6d a7 80            cmp.w -$5880(a5), d7
  00568c:  6d de                  blt.b $566c
  00568e:  4c df 10 80            movem.l (a7)+, d7/a4
  005692:  4e 5e                  unlk a6
  005694:  4e 75                  rts 
  005696:  4e 56 00 00            link.w a6, #$0
  00569a:  20 2e 00 08            move.l $8(a6), d0
  00569e:  4e 5e                  unlk a6
  0056a0:  4e 75                  rts 
  0056a2:  4e 56 00 00            link.w a6, #$0
  0056a6:  2f 0c                  move.l a4, -(a7)
  0056a8:  3f 2e 00 08            move.w $8(a6), -(a7)
  0056ac:  4e ba f1 9e            jsr $484c(pc)
  0056b0:  28 40                  movea.l d0, a4
  0056b2:  20 0c                  move.l a4, d0
  0056b4:  54 8f                  addq.l #$2, a7
  0056b6:  67 14                  beq.b $56cc
  0056b8:  4a 2e 00 0a            tst.b $a(a6)
  0056bc:  57 c0                  seq.b d0
  0056be:  44 00                  neg.b d0
  0056c0:  02 14 00 df            andi.b #$df, (a4)
  0056c4:  eb 08                  lsl.b #$5, d0
  0056c6:  02 00 00 20            andi.b #$20, d0
  0056ca:  81 14                  or.b d0, (a4)
  0056cc:  28 5f                  movea.l (a7)+, a4
  0056ce:  4e 5e                  unlk a6
  0056d0:  4e 75                  rts 