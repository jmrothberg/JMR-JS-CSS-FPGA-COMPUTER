; prince-of-persia-demo: Prince of Persia Demo, CODE resource 3 (18948 bytes)
; 68000 disassembly (linear sweep). Code starts after the 4-byte segment header.
; Words $Axxx are Mac Toolbox/OS traps; known ones are annotated. Globals are (a5)-relative.

  000004:  2f 07                  move.l d7, -(a7)
  000006:  41 ed ee be            lea.l -$1142(a5), a0
  00000a:  2b 48 bd 8a            move.l a0, -$4276(a5)
  00000e:  43 ed ef be            lea.l -$1042(a5), a1
  000012:  2b 49 bd 8e            move.l a1, -$4272(a5)
  000016:  3f 3c 00 01            move.w #$1, -(a7)
  00001a:  4e ad 00 72            jsr $72(a5)
  00001e:  48 78 02 bc            pea.l $2bc.w
  000022:  4e ba 08 42            jsr $866(pc)
  000026:  2e bc 00 01 00 96      move.l #$10096, (a7)
  00002c:  4e ba 08 38            jsr $866(pc)
  000030:  2e bc 00 02 01 90      move.l #$20190, (a7)
  000036:  4e ba 08 2e            jsr $866(pc)
  00003a:  7e 00                  moveq #$0, d7
  00003c:  5c 8f                  addq.l #$6, a7
  00003e:  60 0a                  bra.b $4a
  000040:  3f 07                  move.w d7, -(a7)
  000042:  4e ad 00 d2            jsr $d2(a5)
  000046:  54 8f                  addq.l #$2, a7
  000048:  52 47                  addq.w #$1, d7
  00004a:  0c 47 00 2c            cmpi.w #$2c, d7
  00004e:  6d f0                  blt.b $40
  000050:  2e 1f                  move.l (a7)+, d7
  000052:  4e 75                  rts 
  000054:  48 6d a5 c4            pea.l -$5a3c(a5)
  000058:  a8 a2                  dc.w $a8a2
  00005a:  4e ba 10 06            jsr $1062(pc)
  00005e:  4e 75                  rts 
  000060:  4e ad 04 7a            jsr $47a(a5)
  000064:  4e ad 03 ea            jsr $3ea(a5)
  000068:  4e ba 2f 56            jsr $2fc0(pc)
  00006c:  4e ba 18 70            jsr $18de(pc)
  000070:  4e ba 03 76            jsr $3e8(pc)
  000074:  4a 40                  tst.w d0
  000076:  66 00 00 94            bne.w $10c
  00007a:  4e ba 04 0e            jsr $48a(pc)
  00007e:  4e ba 2e 50            jsr $2ed0(pc)
  000082:  4e ba 2e 00            jsr $2e84(pc)
  000086:  4e ba 07 c2            jsr $84a(pc)
  00008a:  4e ba 06 c2            jsr $74e(pc)
  00008e:  4e ba 24 b0            jsr $2540(pc)
  000092:  4e ba 04 66            jsr $4fa(pc)
  000096:  4e ba 23 56            jsr $23ee(pc)
  00009a:  30 2d a9 0c            move.w -$56f4(a5), d0
  00009e:  0c 40 00 0e            cmpi.w #$e, d0
  0000a2:  62 68                  bhi.b $10c
  0000a4:  43 fa 00 86            lea.l $12c(pc), a1
  0000a8:  d0 40                  add.w d0, d0
  0000aa:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0000ae:  4e d1                  jmp (a1)
  0000b0:  0c 2d 00 18 b9 73      cmpi.b #$18, -$468d(a5)
  0000b6:  66 54                  bne.b $10c
  0000b8:  42 6d ba 64            clr.w -$459c(a5)
  0000bc:  4e ba ff 96            jsr $54(pc)
  0000c0:  60 4a                  bra.b $10c
  0000c2:  0c 6d ff fe ba 44      cmpi.w #$fffe, -$45bc(a5)
  0000c8:  66 42                  bne.b $10c
  0000ca:  4e ad 00 fa            jsr $fa(a5)
  0000ce:  1b 7c 00 ff b9 6c      move.b #$ff, -$4694(a5)
  0000d4:  70 01                  moveq #$1, d0
  0000d6:  d0 6d a9 0c            add.w -$56f4(a5), d0
  0000da:  3b 40 ba 38            move.w d0, -$45c8(a5)
  0000de:  60 2c                  bra.b $10c
  0000e0:  0c 2d 00 17 b9 73      cmpi.b #$17, -$468d(a5)
  0000e6:  66 24                  bne.b $10c
  0000e8:  4e ad 00 fa            jsr $fa(a5)
  0000ec:  70 01                  moveq #$1, d0
  0000ee:  d0 6d a9 0c            add.w -$56f4(a5), d0
  0000f2:  3b 40 ba 38            move.w d0, -$45c8(a5)
  0000f6:  3b 7c 00 01 ba 22      move.w #$1, -$45de(a5)
  0000fc:  60 0e                  bra.b $10c
  0000fe:  0c 2d 00 05 b9 73      cmpi.b #$5, -$468d(a5)
  000104:  66 06                  bne.b $10c
  000106:  3b 7c 00 01 96 d0      move.w #$1, -$6930(a5)
  00010c:  4e ad 05 02            jsr $502(a5)
  000110:  4a 6d ba 8c            tst.w -$4574(a5)
  000114:  66 14                  bne.b $12a
  000116:  4a 6d ba 86            tst.w -$457a(a5)
  00011a:  66 0e                  bne.b $12a
  00011c:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  000122:  6c 06                  bge.b $12a
  000124:  3b 7c 00 02 96 d0      move.w #$2, -$6930(a5)
  00012a:  4e 75                  rts 
  00012c:  ff 84                  dc.w $ff84
  00012e:  ff e0                  dc.w $ffe0
  000130:  ff e0                  dc.w $ffe0
  000132:  ff e0                  dc.w $ffe0
  000134:  ff e0                  dc.w $ffe0
  000136:  ff e0                  dc.w $ffe0
  000138:  ff 96                  dc.w $ff96
  00013a:  ff e0                  dc.w $ffe0
  00013c:  ff e0                  dc.w $ffe0
  00013e:  ff e0                  dc.w $ffe0
  000140:  ff e0                  dc.w $ffe0
  000142:  ff e0                  dc.w $ffe0
  000144:  ff b4                  dc.w $ffb4
  000146:  ff e0                  dc.w $ffe0
  000148:  ff d2                  dc.w $ffd2
  00014a:  2f 07                  move.l d7, -(a7)
  00014c:  4a 6d ba 7e            tst.w -$4582(a5)
  000150:  66 06                  bne.b $158
  000152:  4a 6d b9 40            tst.w -$46c0(a5)
  000156:  67 1c                  beq.b $174
  000158:  4a 6d ba 7e            tst.w -$4582(a5)
  00015c:  67 06                  beq.b $164
  00015e:  3b 6d ba 7c ba 6a      move.w -$4584(a5), -$4596(a5)
  000164:  3f 3c 00 01            move.w #$1, -(a7)
  000168:  4e ba 13 5e            jsr $14c8(pc)
  00016c:  42 6d b9 40            clr.w -$46c0(a5)
  000170:  54 8f                  addq.l #$2, a7
  000172:  60 08                  bra.b $17c
  000174:  4e ad 04 c2            jsr $4c2(a5)
  000178:  4e ad 04 d2            jsr $4d2(a5)
  00017c:  4e ba 0f 30            jsr $10ae(pc)
  000180:  4e ba 06 5e            jsr $7e0(pc)
  000184:  4a 6d ba 86            tst.w -$457a(a5)
  000188:  67 70                  beq.b $1fa
  00018a:  53 6d ba 86            subq.w #$1, -$457a(a5)
  00018e:  4a 6d ba 86            tst.w -$457a(a5)
  000192:  67 46                  beq.b $1da
  000194:  0c 6d 01 b0 ba 90      cmpi.w #$1b0, -$4570(a5)
  00019a:  66 5e                  bne.b $1fa
  00019c:  0c 6d 00 78 ba 86      cmpi.w #$78, -$457a(a5)
  0001a2:  6c 56                  bge.b $1fa
  0001a4:  3e 2d ba 86            move.w -$457a(a5), d7
  0001a8:  48 c7                  ext.l d7
  0001aa:  8f fc 00 0c            divs.w #$c, d7
  0001ae:  48 47                  swap d7
  0001b0:  0c 47 00 03            cmpi.w #$3, d7
  0001b4:  6f 0a                  ble.b $1c0
  0001b6:  42 67                  clr.w -(a7)
  0001b8:  4e ad 05 1a            jsr $51a(a5)
  0001bc:  54 8f                  addq.l #$2, a7
  0001be:  60 3a                  bra.b $1fa
  0001c0:  0c 47 00 03            cmpi.w #$3, d7
  0001c4:  66 34                  bne.b $1fa
  0001c6:  48 6d 97 4e            pea.l -$68b2(a5)
  0001ca:  4e ad 05 12            jsr $512(a5)
  0001ce:  3e bc 00 26            move.w #$26, (a7)
  0001d2:  4e ad 00 f2            jsr $f2(a5)
  0001d6:  58 8f                  addq.l #$4, a7
  0001d8:  60 20                  bra.b $1fa
  0001da:  0c 6d 00 24 ba 90      cmpi.w #$24, -$4570(a5)
  0001e0:  67 08                  beq.b $1ea
  0001e2:  0c 6d 01 b0 ba 90      cmpi.w #$1b0, -$4570(a5)
  0001e8:  66 06                  bne.b $1f0
  0001ea:  3b 7c 00 03 96 d0      move.w #$3, -$6930(a5)
  0001f0:  3f 3c 00 01            move.w #$1, -(a7)
  0001f4:  4e ad 05 1a            jsr $51a(a5)
  0001f8:  54 8f                  addq.l #$2, a7
  0001fa:  2e 1f                  move.l (a7)+, d7
  0001fc:  4e 75                  rts 
  0001fe:  2f 07                  move.l d7, -(a7)
  000200:  7e 00                  moveq #$0, d7
  000202:  60 4e                  bra.b $252
  000204:  3f 07                  move.w d7, -(a7)
  000206:  4e ad 04 72            jsr $472(a5)
  00020a:  70 00                  moveq #$0, d0
  00020c:  10 2d ba 94            move.b -$456c(a5), d0
  000210:  04 40 00 0a            subi.w #$a, d0
  000214:  0c 40 00 14            cmpi.w #$14, d0
  000218:  54 8f                  addq.l #$2, a7
  00021a:  62 34                  bhi.b $250
  00021c:  43 fa 00 3e            lea.l $25c(pc), a1
  000220:  d0 40                  add.w d0, d0
  000222:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000226:  4e d1                  jmp (a1)
  000228:  3f 07                  move.w d7, -(a7)
  00022a:  3f 2d ba 6a            move.w -$4596(a5), -(a7)
  00022e:  4e ad 04 1a            jsr $41a(a5)
  000232:  58 8f                  addq.l #$4, a7
  000234:  60 1a                  bra.b $250
  000236:  3f 07                  move.w d7, -(a7)
  000238:  3f 2d ba 6a            move.w -$4596(a5), -(a7)
  00023c:  4e ad 04 22            jsr $422(a5)
  000240:  58 8f                  addq.l #$4, a7
  000242:  60 0c                  bra.b $250
  000244:  3f 07                  move.w d7, -(a7)
  000246:  3f 2d ba 6a            move.w -$4596(a5), -(a7)
  00024a:  4e ad 04 2a            jsr $42a(a5)
  00024e:  58 8f                  addq.l #$4, a7
  000250:  52 47                  addq.w #$1, d7
  000252:  0c 47 00 1e            cmpi.w #$1e, d7
  000256:  6d ac                  blt.b $204
  000258:  2e 1f                  move.l (a7)+, d7
  00025a:  4e 75                  rts 
  00025c:  ff da                  dc.w $ffda
  00025e:  ff f4                  dc.w $fff4
  000260:  ff f4                  dc.w $fff4
  000262:  ff f4                  dc.w $fff4
  000264:  ff f4                  dc.w $fff4
  000266:  ff f4                  dc.w $fff4
  000268:  ff f4                  dc.w $fff4
  00026a:  ff f4                  dc.w $fff4
  00026c:  ff f4                  dc.w $fff4
  00026e:  ff cc                  dc.w $ffcc
  000270:  ff f4                  dc.w $fff4
  000272:  ff f4                  dc.w $fff4
  000274:  ff e8                  dc.w $ffe8
  000276:  ff f4                  dc.w $fff4
  000278:  ff f4                  dc.w $fff4
  00027a:  ff f4                  dc.w $fff4
  00027c:  ff f4                  dc.w $fff4
  00027e:  ff f4                  dc.w $fff4
  000280:  ff f4                  dc.w $fff4
  000282:  ff f4                  dc.w $fff4
  000284:  ff cc                  dc.w $ffcc
  000286:  4e 56 00 00            link.w a6, #$0
  00028a:  48 e7 03 00            movem.l d6-d7, -(a7)
  00028e:  3e 2e 00 08            move.w $8(a6), d7
  000292:  be 6d a9 0c            cmp.w -$56f4(a5), d7
  000296:  67 00 01 00            beq.w $398
  00029a:  4e ba 0e 02            jsr $109e(pc)
  00029e:  20 4d                  movea.l a5, a0
  0002a0:  d0 c7                  adda.w d7, a0
  0002a2:  1b 68 a8 cc b9 44      move.b -$5734(a0), -$46bc(a5)
  0002a8:  4a 2d b9 44            tst.b -$46bc(a5)
  0002ac:  66 06                  bne.b $2b4
  0002ae:  3c 3c 03 e8            move.w #$3e8, d6
  0002b2:  60 04                  bra.b $2b8
  0002b4:  3c 3c 07 d0            move.w #$7d0, d6
  0002b8:  30 06                  move.w d6, d0
  0002ba:  06 40 00 c8            addi.w #$c8, d0
  0002be:  3f 00                  move.w d0, -(a7)
  0002c0:  3f 3c 00 06            move.w #$6, -(a7)
  0002c4:  4e ba 05 a0            jsr $866(pc)
  0002c8:  30 06                  move.w d6, d0
  0002ca:  06 40 01 68            addi.w #$168, d0
  0002ce:  3e 80                  move.w d0, (a7)
  0002d0:  3f 3c 00 07            move.w #$7, -(a7)
  0002d4:  4e ba 05 90            jsr $866(pc)
  0002d8:  20 4d                  movea.l a5, a0
  0002da:  d0 c7                  adda.w d7, a0
  0002dc:  d0 c7                  adda.w d7, a0
  0002de:  30 28 a8 dc            move.w -$5724(a0), d0
  0002e2:  5c 8f                  addq.l #$6, a7
  0002e4:  67 14                  beq.b $2fa
  0002e6:  6b 30                  bmi.b $318
  0002e8:  57 40                  subq.w #$3, d0
  0002ea:  67 26                  beq.b $312
  0002ec:  6a 06                  bpl.b $2f4
  0002ee:  52 40                  addq.w #$1, d0
  0002f0:  6a 0e                  bpl.b $300
  0002f2:  60 12                  bra.b $306
  0002f4:  55 40                  subq.w #$2, d0
  0002f6:  6a 20                  bpl.b $318
  0002f8:  60 12                  bra.b $30c
  0002fa:  3c 3c 03 e8            move.w #$3e8, d6
  0002fe:  60 1a                  bra.b $31a
  000300:  3c 3c 07 d0            move.w #$7d0, d6
  000304:  60 14                  bra.b $31a
  000306:  3c 3c 0b b8            move.w #$bb8, d6
  00030a:  60 0e                  bra.b $31a
  00030c:  3c 3c 0f a0            move.w #$fa0, d6
  000310:  60 08                  bra.b $31a
  000312:  3c 3c 13 88            move.w #$1388, d6
  000316:  60 02                  bra.b $31a
  000318:  7c 00                  moveq #$0, d6
  00031a:  4a 46                  tst.w d6
  00031c:  67 12                  beq.b $330
  00031e:  30 06                  move.w d6, d0
  000320:  06 40 02 ee            addi.w #$2ee, d0
  000324:  3f 00                  move.w d0, -(a7)
  000326:  3f 3c 00 05            move.w #$5, -(a7)
  00032a:  4e ba 05 3a            jsr $866(pc)
  00032e:  58 8f                  addq.l #$4, a7
  000330:  42 6d ba a8            clr.w -$4558(a5)
  000334:  42 6d ba a6            clr.w -$455a(a5)
  000338:  20 4d                  movea.l a5, a0
  00033a:  d0 c7                  adda.w d7, a0
  00033c:  4a 28 a8 5c            tst.b -$57a4(a0)
  000340:  67 0a                  beq.b $34c
  000342:  3f 3c 00 2c            move.w #$2c, -(a7)
  000346:  4e ad 00 d2            jsr $d2(a5)
  00034a:  54 8f                  addq.l #$2, a7
  00034c:  20 4d                  movea.l a5, a0
  00034e:  d0 c7                  adda.w d7, a0
  000350:  4a 28 a8 6c            tst.b -$5794(a0)
  000354:  67 0a                  beq.b $360
  000356:  3f 3c 00 2d            move.w #$2d, -(a7)
  00035a:  4e ad 00 d2            jsr $d2(a5)
  00035e:  54 8f                  addq.l #$2, a7
  000360:  20 4d                  movea.l a5, a0
  000362:  d0 c7                  adda.w d7, a0
  000364:  4a 28 a8 9c            tst.b -$5764(a0)
  000368:  67 12                  beq.b $37c
  00036a:  3f 3c 00 2f            move.w #$2f, -(a7)
  00036e:  4e ad 00 d2            jsr $d2(a5)
  000372:  3e bc 00 2e            move.w #$2e, (a7)
  000376:  4e ad 00 d2            jsr $d2(a5)
  00037a:  54 8f                  addq.l #$2, a7
  00037c:  20 4d                  movea.l a5, a0
  00037e:  d0 c7                  adda.w d7, a0
  000380:  4a 28 a8 ac            tst.b -$5754(a0)
  000384:  67 12                  beq.b $398
  000386:  3f 3c 00 31            move.w #$31, -(a7)
  00038a:  4e ad 00 d2            jsr $d2(a5)
  00038e:  3e bc 00 30            move.w #$30, (a7)
  000392:  4e ad 00 d2            jsr $d2(a5)
  000396:  54 8f                  addq.l #$2, a7
  000398:  3b 47 ba 38            move.w d7, -$45c8(a5)
  00039c:  3b 47 a9 0c            move.w d7, -$56f4(a5)
  0003a0:  4c df 00 c0            movem.l (a7)+, d6-d7
  0003a4:  4e 5e                  unlk a6
  0003a6:  4e 75                  rts 
  0003a8:  2f 0c                  move.l a4, -(a7)
  0003aa:  42 a7                  clr.l -(a7)
  0003ac:  2f 3c 4c 45 56 4c      move.l #$4c45564c, -(a7)
  0003b2:  3f 2d a9 0c            move.w -$56f4(a5), -(a7)
  0003b6:  a9 a0                  dc.w $a9a0
  0003b8:  28 5f                  movea.l (a7)+, a4
  0003ba:  2f 0c                  move.l a4, -(a7)
  0003bc:  4e ad 00 c2            jsr $c2(a5)
  0003c0:  4a 00                  tst.b d0
  0003c2:  58 8f                  addq.l #$4, a7
  0003c4:  66 1e                  bne.b $3e4
  0003c6:  20 4c                  movea.l a4, a0
  0003c8:  a0 29                  dc.w $a029
  0003ca:  43 ed e9 1e            lea.l -$16e2(a5), a1
  0003ce:  20 3c 00 00 09 00      move.l #$900, d0
  0003d4:  20 54                  movea.l (a4), a0
  0003d6:  a0 2e                  dc.w $a02e
  0003d8:  20 4c                  movea.l a4, a0
  0003da:  a0 2a                  dc.w $a02a
  0003dc:  20 4c                  movea.l a4, a0
  0003de:  a0 49                  dc.w $a049
  0003e0:  4e ad 04 ba            jsr $4ba(a5)
  0003e4:  28 5f                  movea.l (a7)+, a4
  0003e6:  4e 75                  rts 
  0003e8:  4e ba 31 ec            jsr $35d6(pc)
  0003ec:  4e ba 2d e4            jsr $31d2(pc)
  0003f0:  4e ba 45 14            jsr $4906(pc)
  0003f4:  4e ba 39 32            jsr $3d28(pc)
  0003f8:  4a 6d ba 32            tst.w -$45ce(a5)
  0003fc:  67 10                  beq.b $40e
  0003fe:  4a 2d b9 53            tst.b -$46ad(a5)
  000402:  6d 0a                  blt.b $40e
  000404:  42 6d ba 32            clr.w -$45ce(a5)
  000408:  3b 7c 00 01 b9 40      move.w #$1, -$46c0(a5)
  00040e:  0c 2d 00 06 b9 77      cmpi.b #$6, -$4689(a5)
  000414:  6f 26                  ble.b $43c
  000416:  4a 2d a5 be            tst.b -$5a42(a5)
  00041a:  67 20                  beq.b $43c
  00041c:  0c 6d 01 a4 ba 86      cmpi.w #$1a4, -$457a(a5)
  000422:  6c 18                  bge.b $43c
  000424:  3f 3c 00 01            move.w #$1, -(a7)
  000428:  4e ad 05 1a            jsr $51a(a5)
  00042c:  4e ad 00 fa            jsr $fa(a5)
  000430:  3b 7c 00 01 ba 66      move.w #$1, -$459a(a5)
  000436:  70 01                  moveq #$1, d0
  000438:  54 8f                  addq.l #$2, a7
  00043a:  60 4c                  bra.b $488
  00043c:  4a 2d b9 4f            tst.b -$46b1(a5)
  000440:  67 40                  beq.b $482
  000442:  4e ba 2f 0c            jsr $3350(pc)
  000446:  4e ba 32 58            jsr $36a0(pc)
  00044a:  4e ba 32 8a            jsr $36d6(pc)
  00044e:  4e ad 04 f2            jsr $4f2(a5)
  000452:  4e ba 2d 7e            jsr $31d2(pc)
  000456:  4e ba 34 30            jsr $3888(pc)
  00045a:  4e ba 13 cc            jsr $1828(pc)
  00045e:  4e ad 03 b2            jsr $3b2(a5)
  000462:  4e ad 03 ba            jsr $3ba(a5)
  000466:  4e ad 03 d2            jsr $3d2(a5)
  00046a:  4e ba 32 92            jsr $36fe(pc)
  00046e:  4e ba 3d 74            jsr $41e4(pc)
  000472:  4e ba 3e 24            jsr $4298(pc)
  000476:  4e ba 33 26            jsr $379e(pc)
  00047a:  4e ad 03 ca            jsr $3ca(a5)
  00047e:  4e ba 13 00            jsr $1780(pc)
  000482:  4e ba 31 16            jsr $359a(pc)
  000486:  70 00                  moveq #$0, d0
  000488:  4e 75                  rts 
  00048a:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  000490:  67 66                  beq.b $4f8
  000492:  4e ba 31 8e            jsr $3622(pc)
  000496:  4e ba 2d 3a            jsr $31d2(pc)
  00049a:  4e ba 44 6a            jsr $4906(pc)
  00049e:  4e ba 39 a0            jsr $3e40(pc)
  0004a2:  10 2d b9 4f            move.b -$46b1(a5), d0
  0004a6:  48 80                  ext.w d0
  0004a8:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  0004ac:  66 46                  bne.b $4f4
  0004ae:  4a 6d ba 2c            tst.w -$45d4(a5)
  0004b2:  67 40                  beq.b $4f4
  0004b4:  4e ba 2e 9a            jsr $3350(pc)
  0004b8:  0c 2d 00 2c b9 47      cmpi.b #$2c, -$46b9(a5)
  0004be:  65 34                  bcs.b $4f4
  0004c0:  0c 2d 00 d3 b9 47      cmpi.b #$d3, -$46b9(a5)
  0004c6:  64 2c                  bcc.b $4f4
  0004c8:  4e ba 31 d6            jsr $36a0(pc)
  0004cc:  4e ba 32 08            jsr $36d6(pc)
  0004d0:  4e ad 04 f2            jsr $4f2(a5)
  0004d4:  4e ba 2c fc            jsr $31d2(pc)
  0004d8:  4e ba 33 ae            jsr $3888(pc)
  0004dc:  4e ad 03 da            jsr $3da(a5)
  0004e0:  4e ba 32 1c            jsr $36fe(pc)
  0004e4:  4e ba 3c fe            jsr $41e4(pc)
  0004e8:  4e ba 3d ae            jsr $4298(pc)
  0004ec:  4e ba 32 b0            jsr $379e(pc)
  0004f0:  4e ad 03 e2            jsr $3e2(a5)
  0004f4:  4e ba 30 cc            jsr $35c2(pc)
  0004f8:  4e 75                  rts 
  0004fa:  4a 6d ba 7c            tst.w -$4584(a5)
  0004fe:  67 2e                  beq.b $52e
  000500:  30 2d ba 7c            move.w -$4584(a5), d0
  000504:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  000508:  67 24                  beq.b $52e
  00050a:  3b 6d ba 7c ba 6a      move.w -$4584(a5), -$4596(a5)
  000510:  4e ad 04 92            jsr $492(a5)
  000514:  3b 7c 00 01 ba 7e      move.w #$1, -$4582(a5)
  00051a:  4e ba 30 6a            jsr $3586(pc)
  00051e:  4e ba fc de            jsr $1fe(pc)
  000522:  4e ad 04 62            jsr $462(a5)
  000526:  4e ba 00 08            jsr $530(pc)
  00052a:  4e ba 1d 30            jsr $225c(pc)
  00052e:  4e 75                  rts 
  000530:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  000536:  66 4e                  bne.b $586
  000538:  0c 6d 00 17 ba 6a      cmpi.w #$17, -$4596(a5)
  00053e:  67 08                  beq.b $548
  000540:  0c 6d 00 10 ba 6a      cmpi.w #$10, -$4596(a5)
  000546:  66 3e                  bne.b $586
  000548:  3b 6d ba 70 ba ea      move.w -$4590(a5), -$4516(a5)
  00054e:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  000552:  4e ad 04 e2            jsr $4e2(a5)
  000556:  1b 7c 00 16 ba e9      move.b #$16, -$4517(a5)
  00055c:  54 8f                  addq.l #$2, a7
  00055e:  60 1e                  bra.b $57e
  000560:  3f 3c 00 ff            move.w #$ff, -(a7)
  000564:  4e ad 00 72            jsr $72(a5)
  000568:  72 00                  moveq #$0, d1
  00056a:  12 00                  move.b d0, d1
  00056c:  02 01 00 0f            andi.b #$f, d1
  000570:  44 01                  neg.b d1
  000572:  1e 81                  move.b d1, (a7)
  000574:  4e ad 04 5a            jsr $45a(a5)
  000578:  54 8f                  addq.l #$2, a7
  00057a:  52 2d ba e9            addq.b #$1, -$4517(a5)
  00057e:  0c 2d 00 1b ba e9      cmpi.b #$1b, -$4517(a5)
  000584:  63 da                  bls.b $560
  000586:  4e 75                  rts 
  000588:  4e 56 ff fe            link.w a6, #$fffe
  00058c:  48 e7 1f 00            movem.l d3-d7, -(a7)
  000590:  2b 6d a5 d4 a2 e4      move.l -$5a2c(a5), -$5d1c(a5)
  000596:  2b 6d a5 d8 a2 e8      move.l -$5a28(a5), -$5d18(a5)
  00059c:  3d 6d ba 32 ff fe      move.w -$45ce(a5), -$2(a6)
  0005a2:  42 6d ba 32            clr.w -$45ce(a5)
  0005a6:  1f 3c 00 01            move.b #$1, -(a7)
  0005aa:  48 6d a5 dc            pea.l -$5a24(a5)
  0005ae:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  0005b2:  4e 90                  jsr (a0)
  0005b4:  3e 2d 99 1c            move.w -$66e4(a5), d7
  0005b8:  3c 2d 99 24            move.w -$66dc(a5), d6
  0005bc:  3a 2d 9e 9e            move.w -$6162(a5), d5
  0005c0:  78 00                  moveq #$0, d4
  0005c2:  5c 8f                  addq.l #$6, a7
  0005c4:  60 2c                  bra.b $5f2
  0005c6:  b8 6e 00 08            cmp.w $8(a6), d4
  0005ca:  6c 06                  bge.b $5d2
  0005cc:  36 3c 00 d9            move.w #$d9, d3
  0005d0:  60 04                  bra.b $5d6
  0005d2:  36 3c 00 da            move.w #$da, d3
  0005d6:  3f 3c 00 01            move.w #$1, -(a7)
  0005da:  3f 05                  move.w d5, -(a7)
  0005dc:  3f 07                  move.w d7, -(a7)
  0005de:  3f 03                  move.w d3, -(a7)
  0005e0:  3f 3c 00 02            move.w #$2, -(a7)
  0005e4:  20 6d a3 de            movea.l -$5c22(a5), a0
  0005e8:  4e 90                  jsr (a0)
  0005ea:  de 46                  add.w d6, d7
  0005ec:  4f ef 00 0a            lea.l $a(a7), a7
  0005f0:  52 44                  addq.w #$1, d4
  0005f2:  b8 6e 00 0a            cmp.w $a(a6), d4
  0005f6:  6d ce                  blt.b $5c6
  0005f8:  48 6d a5 dc            pea.l -$5a24(a5)
  0005fc:  a9 28                  dc.w $a928
  0005fe:  3b 6e ff fe ba 32      move.w -$2(a6), -$45ce(a5)
  000604:  2b 6d a5 cc a2 e4      move.l -$5a34(a5), -$5d1c(a5)
  00060a:  2b 6d a5 d0 a2 e8      move.l -$5a30(a5), -$5d18(a5)
  000610:  4c df 00 f8            movem.l (a7)+, d3-d7
  000614:  4e 5e                  unlk a6
  000616:  4e 75                  rts 
  000618:  4e 56 00 00            link.w a6, #$0
  00061c:  48 e7 1f 00            movem.l d3-d7, -(a7)
  000620:  1e 2d b9 87            move.b -$4679(a5), d7
  000624:  48 87                  ext.w d7
  000626:  0c 47 00 04            cmpi.w #$4, d7
  00062a:  67 00 00 82            beq.w $6ae
  00062e:  0c 47 00 18            cmpi.w #$18, d7
  000632:  67 7a                  beq.b $6ae
  000634:  0c 47 00 01            cmpi.w #$1, d7
  000638:  66 08                  bne.b $642
  00063a:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  000640:  66 6c                  bne.b $6ae
  000642:  2b 6d a5 d4 a2 e4      move.l -$5a2c(a5), -$5d1c(a5)
  000648:  2b 6d a5 d8 a2 e8      move.l -$5a28(a5), -$5d18(a5)
  00064e:  3e 2d ba 32            move.w -$45ce(a5), d7
  000652:  42 6d ba 32            clr.w -$45ce(a5)
  000656:  7c 01                  moveq #$1, d6
  000658:  1f 06                  move.b d6, -(a7)
  00065a:  48 6d a5 ec            pea.l -$5a14(a5)
  00065e:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  000662:  4e 90                  jsr (a0)
  000664:  3c 2d 9b 7c            move.w -$6484(a5), d6
  000668:  3a 2d 99 24            move.w -$66dc(a5), d5
  00066c:  38 2d 9e 9e            move.w -$6162(a5), d4
  000670:  76 00                  moveq #$0, d3
  000672:  5c 8f                  addq.l #$6, a7
  000674:  60 1c                  bra.b $692
  000676:  3f 3c 00 01            move.w #$1, -(a7)
  00067a:  3f 04                  move.w d4, -(a7)
  00067c:  3f 06                  move.w d6, -(a7)
  00067e:  2f 3c 00 05 00 01      move.l #$50001, -(a7)
  000684:  20 6d a3 de            movea.l -$5c22(a5), a0
  000688:  4e 90                  jsr (a0)
  00068a:  9c 45                  sub.w d5, d6
  00068c:  4f ef 00 0a            lea.l $a(a7), a7
  000690:  52 43                  addq.w #$1, d3
  000692:  b6 6e 00 08            cmp.w $8(a6), d3
  000696:  6d de                  blt.b $676
  000698:  48 6d a5 ec            pea.l -$5a14(a5)
  00069c:  a9 28                  dc.w $a928
  00069e:  3b 47 ba 32            move.w d7, -$45ce(a5)
  0006a2:  2b 6d a5 cc a2 e4      move.l -$5a34(a5), -$5d1c(a5)
  0006a8:  2b 6d a5 d0 a2 e8      move.l -$5a30(a5), -$5d18(a5)
  0006ae:  4c df 00 f8            movem.l (a7)+, d3-d7
  0006b2:  4e 5e                  unlk a6
  0006b4:  4e 75                  rts 
  0006b6:  52 6d ba 48            addq.w #$1, -$45b8(a5)
  0006ba:  0c 6d 00 0a ba 48      cmpi.w #$a, -$45b8(a5)
  0006c0:  6f 06                  ble.b $6c8
  0006c2:  3b 7c 00 0a ba 48      move.w #$a, -$45b8(a5)
  0006c8:  4e ba 00 04            jsr $6ce(pc)
  0006cc:  4e 75                  rts 
  0006ce:  30 2d ba 48            move.w -$45b8(a5), d0
  0006d2:  90 6d ba 4a            sub.w -$45b6(a5), d0
  0006d6:  3b 40 ba 50            move.w d0, -$45b0(a5)
  0006da:  4e 75                  rts 
  0006dc:  4a 6d ba 50            tst.w -$45b0(a5)
  0006e0:  67 0e                  beq.b $6f0
  0006e2:  3f 2d ba 48            move.w -$45b8(a5), -(a7)
  0006e6:  3f 2d ba 4a            move.w -$45b6(a5), -(a7)
  0006ea:  4e ba fe 9c            jsr $588(pc)
  0006ee:  58 8f                  addq.l #$4, a7
  0006f0:  0c 6d 00 01 ba 4a      cmpi.w #$1, -$45b6(a5)
  0006f6:  66 20                  bne.b $718
  0006f8:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  0006fe:  67 18                  beq.b $718
  000700:  3f 2d ba 48            move.w -$45b8(a5), -(a7)
  000704:  30 2d ba 80            move.w -$4580(a5), d0
  000708:  48 c0                  ext.l d0
  00070a:  81 fc 00 02            divs.w #$2, d0
  00070e:  48 40                  swap d0
  000710:  3f 00                  move.w d0, -(a7)
  000712:  4e ba fe 74            jsr $588(pc)
  000716:  58 8f                  addq.l #$4, a7
  000718:  4a 6d ba 52            tst.w -$45ae(a5)
  00071c:  67 0e                  beq.b $72c
  00071e:  3f 2d ba 4e            move.w -$45b2(a5), -(a7)
  000722:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  000726:  4e ba fe f0            jsr $618(pc)
  00072a:  58 8f                  addq.l #$4, a7
  00072c:  0c 6d 00 01 ba 4c      cmpi.w #$1, -$45b4(a5)
  000732:  66 18                  bne.b $74c
  000734:  3f 2d ba 4e            move.w -$45b2(a5), -(a7)
  000738:  30 2d ba 80            move.w -$4580(a5), d0
  00073c:  48 c0                  ext.l d0
  00073e:  81 fc 00 02            divs.w #$2, d0
  000742:  48 40                  swap d0
  000744:  3f 00                  move.w d0, -(a7)
  000746:  4e ba fe d0            jsr $618(pc)
  00074a:  58 8f                  addq.l #$4, a7
  00074c:  4e 75                  rts 
  00074e:  0c 2d 00 01 b9 63      cmpi.b #$1, -$469d(a5)
  000754:  66 14                  bne.b $76a
  000756:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  00075c:  66 0c                  bne.b $76a
  00075e:  4a 6d ba 52            tst.w -$45ae(a5)
  000762:  67 06                  beq.b $76a
  000764:  3b 6d ba 52 ba 50      move.w -$45ae(a5), -$45b0(a5)
  00076a:  30 2d ba 50            move.w -$45b0(a5), d0
  00076e:  d1 6d ba 4a            add.w d0, -$45b6(a5)
  000772:  4a 6d ba 4a            tst.w -$45b6(a5)
  000776:  6c 06                  bge.b $77e
  000778:  42 6d ba 4a            clr.w -$45b6(a5)
  00077c:  60 10                  bra.b $78e
  00077e:  30 2d ba 4a            move.w -$45b6(a5), d0
  000782:  b0 6d ba 48            cmp.w -$45b8(a5), d0
  000786:  6f 06                  ble.b $78e
  000788:  3b 6d ba 48 ba 4a      move.w -$45b8(a5), -$45b6(a5)
  00078e:  30 2d ba 52            move.w -$45ae(a5), d0
  000792:  d1 6d ba 4c            add.w d0, -$45b4(a5)
  000796:  4a 6d ba 4c            tst.w -$45b4(a5)
  00079a:  6c 06                  bge.b $7a2
  00079c:  42 6d ba 4c            clr.w -$45b4(a5)
  0007a0:  60 10                  bra.b $7b2
  0007a2:  30 2d ba 4c            move.w -$45b4(a5), d0
  0007a6:  b0 6d ba 4e            cmp.w -$45b2(a5), d0
  0007aa:  6f 06                  ble.b $7b2
  0007ac:  3b 6d ba 4e ba 4c      move.w -$45b2(a5), -$45b4(a5)
  0007b2:  4e 75                  rts 
  0007b4:  4e 56 00 00            link.w a6, #$0
  0007b8:  4a 6d a9 0e            tst.w -$56f2(a5)
  0007bc:  6d 18                  blt.b $7d6
  0007be:  20 4d                  movea.l a5, a0
  0007c0:  d0 ee 00 08            adda.w $8(a6), a0
  0007c4:  30 2d a9 0e            move.w -$56f2(a5), d0
  0007c8:  22 4d                  movea.l a5, a1
  0007ca:  d2 c0                  adda.w d0, a1
  0007cc:  12 28 b8 f2            move.b -$470e(a0), d1
  0007d0:  b2 29 b8 f2            cmp.b -$470e(a1), d1
  0007d4:  62 06                  bhi.b $7dc
  0007d6:  3b 6e 00 08 a9 0e      move.w $8(a6), -$56f2(a5)
  0007dc:  4e 5e                  unlk a6
  0007de:  4e 75                  rts 
  0007e0:  4a 6d a9 0e            tst.w -$56f2(a5)
  0007e4:  6d 62                  blt.b $848
  0007e6:  4e ad 01 02            jsr $102(a5)
  0007ea:  4a 00                  tst.b d0
  0007ec:  67 28                  beq.b $816
  0007ee:  30 2d ba 68            move.w -$4598(a5), d0
  0007f2:  20 4d                  movea.l a5, a0
  0007f4:  d0 c0                  adda.w d0, a0
  0007f6:  4a 28 b8 b8            tst.b -$4748(a0)
  0007fa:  67 4c                  beq.b $848
  0007fc:  30 2d a9 0e            move.w -$56f2(a5), d0
  000800:  20 4d                  movea.l a5, a0
  000802:  d0 c0                  adda.w d0, a0
  000804:  32 2d ba 68            move.w -$4598(a5), d1
  000808:  22 4d                  movea.l a5, a1
  00080a:  d2 c1                  adda.w d1, a1
  00080c:  14 28 b8 f2            move.b -$470e(a0), d2
  000810:  b4 29 b8 f2            cmp.b -$470e(a1), d2
  000814:  62 32                  bhi.b $848
  000816:  0c 6d 00 0f a9 0e      cmpi.w #$f, -$56f2(a5)
  00081c:  66 14                  bne.b $832
  00081e:  30 2d a9 0e            move.w -$56f2(a5), d0
  000822:  20 4d                  movea.l a5, a0
  000824:  d0 c0                  adda.w d0, a0
  000826:  4a 28 b8 b8            tst.b -$4748(a0)
  00082a:  66 06                  bne.b $832
  00082c:  3b 7c 00 0c 96 f6      move.w #$c, -$690a(a5)
  000832:  3f 2d a9 0e            move.w -$56f2(a5), -(a7)
  000836:  4e ad 00 f2            jsr $f2(a5)
  00083a:  3b 6d a9 0e ba 68      move.w -$56f2(a5), -$4598(a5)
  000840:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  000846:  54 8f                  addq.l #$2, a7
  000848:  4e 75                  rts 
  00084a:  0c 2d 00 a7 b9 6a      cmpi.b #$a7, -$4696(a5)
  000850:  67 08                  beq.b $85a
  000852:  0c 2d 00 a7 b9 7c      cmpi.b #$a7, -$4684(a5)
  000858:  66 0a                  bne.b $864
  00085a:  3f 3c 00 0a            move.w #$a, -(a7)
  00085e:  4e ba ff 54            jsr $7b4(pc)
  000862:  54 8f                  addq.l #$2, a7
  000864:  4e 75                  rts 
  000866:  4e 56 ff fc            link.w a6, #$fffc
  00086a:  48 e7 1f 38            movem.l d3-d7/a2-a4, -(a7)
  00086e:  41 ed a5 7a            lea.l -$5a86(a5), a0
  000872:  3c 2e 00 08            move.w $8(a6), d6
  000876:  48 c6                  ext.l d6
  000878:  e5 8e                  lsl.l #$2, d6
  00087a:  dc 88                  add.l a0, d6
  00087c:  20 46                  movea.l d6, a0
  00087e:  26 50                  movea.l (a0), a3
  000880:  41 ed a5 9a            lea.l -$5a66(a5), a0
  000884:  3e 2e 00 08            move.w $8(a6), d7
  000888:  48 c7                  ext.l d7
  00088a:  e5 8f                  lsl.l #$2, d7
  00088c:  de 88                  add.l a0, d7
  00088e:  20 47                  movea.l d7, a0
  000890:  24 50                  movea.l (a0), a2
  000892:  20 0b                  move.l a3, d0
  000894:  67 06                  beq.b $89c
  000896:  20 0a                  move.l a2, d0
  000898:  66 00 01 1a            bne.w $9b4
  00089c:  4e ad 00 aa            jsr $aa(a5)
  0008a0:  20 6d a1 cc            movea.l -$5e34(a5), a0
  0008a4:  2f 10                  move.l (a0), -(a7)
  0008a6:  a8 51                  dc.w $a851
  0008a8:  42 a7                  clr.l -(a7)
  0008aa:  2f 3c 53 48 50 44      move.l #$53485044, -(a7)
  0008b0:  3f 2e 00 0a            move.w $a(a6), -(a7)
  0008b4:  a9 a0                  dc.w $a9a0
  0008b6:  26 5f                  movea.l (a7)+, a3
  0008b8:  2f 0b                  move.l a3, -(a7)
  0008ba:  4e ad 00 c2            jsr $c2(a5)
  0008be:  4a 00                  tst.b d0
  0008c0:  58 8f                  addq.l #$4, a7
  0008c2:  66 00 00 f0            bne.w $9b4
  0008c6:  24 53                  movea.l (a3), a2
  0008c8:  2a 12                  move.l (a2), d5
  0008ca:  2d 6a 00 04 ff fc      move.l $4(a2), -$4(a6)
  0008d0:  26 2a 00 08            move.l $8(a2), d3
  0008d4:  2f 0b                  move.l a3, -(a7)
  0008d6:  a9 a3                  dc.w $a9a3
  0008d8:  42 a7                  clr.l -(a7)
  0008da:  2f 3c 53 48 50 54      move.l #$53485054, -(a7)
  0008e0:  3f 2e 00 0a            move.w $a(a6), -(a7)
  0008e4:  a9 a0                  dc.w $a9a0
  0008e6:  26 5f                  movea.l (a7)+, a3
  0008e8:  2f 0b                  move.l a3, -(a7)
  0008ea:  4e ad 00 c2            jsr $c2(a5)
  0008ee:  4a 00                  tst.b d0
  0008f0:  58 8f                  addq.l #$4, a7
  0008f2:  66 00 00 c0            bne.w $9b4
  0008f6:  2f 0b                  move.l a3, -(a7)
  0008f8:  a9 92                  dc.w $a992
  0008fa:  20 4b                  movea.l a3, a0
  0008fc:  a0 64                  dc.w $a064
  0008fe:  20 2e ff fc            move.l -$4(a6), d0
  000902:  a1 22                  dc.w $a122
  000904:  28 48                  movea.l a0, a4
  000906:  2f 0c                  move.l a4, -(a7)
  000908:  4e ad 00 ca            jsr $ca(a5)
  00090c:  4a 00                  tst.b d0
  00090e:  58 8f                  addq.l #$4, a7
  000910:  66 00 00 a2            bne.w $9b4
  000914:  42 67                  clr.w -(a7)
  000916:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  00091a:  3f 2d a0 be            move.w -$5f42(a5), -(a7)
  00091e:  48 6d a1 66            pea.l -$5e9a(a5)
  000922:  4e ad 01 82            jsr $182(a5)
  000926:  38 1f                  move.w (a7)+, d4
  000928:  3f 04                  move.w d4, -(a7)
  00092a:  4e ad 00 ba            jsr $ba(a5)
  00092e:  4a 00                  tst.b d0
  000930:  54 8f                  addq.l #$2, a7
  000932:  66 00 00 80            bne.w $9b4
  000936:  42 67                  clr.w -(a7)
  000938:  3f 2d a1 66            move.w -$5e9a(a5), -(a7)
  00093c:  3f 3c 00 01            move.w #$1, -(a7)
  000940:  2f 05                  move.l d5, -(a7)
  000942:  4e ad 01 9a            jsr $19a(a5)
  000946:  38 1f                  move.w (a7)+, d4
  000948:  3f 04                  move.w d4, -(a7)
  00094a:  4e ad 00 ba            jsr $ba(a5)
  00094e:  4a 00                  tst.b d0
  000950:  54 8f                  addq.l #$2, a7
  000952:  66 60                  bne.b $9b4
  000954:  20 4c                  movea.l a4, a0
  000956:  a0 29                  dc.w $a029
  000958:  42 67                  clr.w -(a7)
  00095a:  3f 2d a1 66            move.w -$5e9a(a5), -(a7)
  00095e:  48 6e ff fc            pea.l -$4(a6)
  000962:  2f 14                  move.l (a4), -(a7)
  000964:  4e ad 01 92            jsr $192(a5)
  000968:  38 1f                  move.w (a7)+, d4
  00096a:  3f 04                  move.w d4, -(a7)
  00096c:  4e ad 00 ba            jsr $ba(a5)
  000970:  4a 00                  tst.b d0
  000972:  54 8f                  addq.l #$2, a7
  000974:  66 3e                  bne.b $9b4
  000976:  42 67                  clr.w -(a7)
  000978:  3f 2d a1 66            move.w -$5e9a(a5), -(a7)
  00097c:  4e ad 01 8a            jsr $18a(a5)
  000980:  20 4c                  movea.l a4, a0
  000982:  a0 2a                  dc.w $a02a
  000984:  20 03                  move.l d3, d0
  000986:  a1 22                  dc.w $a122
  000988:  24 48                  movea.l a0, a2
  00098a:  2f 0a                  move.l a2, -(a7)
  00098c:  4e ad 00 ca            jsr $ca(a5)
  000990:  4a 00                  tst.b d0
  000992:  5c 8f                  addq.l #$6, a7
  000994:  66 1e                  bne.b $9b4
  000996:  2f 12                  move.l (a2), -(a7)
  000998:  2f 2e ff fc            move.l -$4(a6), -(a7)
  00099c:  2f 14                  move.l (a4), -(a7)
  00099e:  4e ad 00 a2            jsr $a2(a5)
  0009a2:  20 4c                  movea.l a4, a0
  0009a4:  a0 23                  dc.w $a023
  0009a6:  20 4a                  movea.l a2, a0
  0009a8:  a0 64                  dc.w $a064
  0009aa:  20 46                  movea.l d6, a0
  0009ac:  20 8b                  move.l a3, (a0)
  0009ae:  20 47                  movea.l d7, a0
  0009b0:  20 8a                  move.l a2, (a0)
  0009b2:  a8 50                  dc.w $a850   ; _InitCursor
  0009b4:  4c ee 1c f8 ff dc      movem.l -$24(a6), d3-d7/a2-a4
  0009ba:  4e 5e                  unlk a6
  0009bc:  4e 75                  rts 
  0009be:  4e 56 00 00            link.w a6, #$0
  0009c2:  2f 07                  move.l d7, -(a7)
  0009c4:  4e ad 04 da            jsr $4da(a5)
  0009c8:  3e 2e 00 08            move.w $8(a6), d7
  0009cc:  60 0a                  bra.b $9d8
  0009ce:  3f 07                  move.w d7, -(a7)
  0009d0:  4e ba 00 12            jsr $9e4(pc)
  0009d4:  54 8f                  addq.l #$2, a7
  0009d6:  52 47                  addq.w #$1, d7
  0009d8:  0c 47 00 08            cmpi.w #$8, d7
  0009dc:  6d f0                  blt.b $9ce
  0009de:  2e 1f                  move.l (a7)+, d7
  0009e0:  4e 5e                  unlk a6
  0009e2:  4e 75                  rts 
  0009e4:  4e 56 00 00            link.w a6, #$0
  0009e8:  2f 0c                  move.l a4, -(a7)
  0009ea:  49 ed a5 7a            lea.l -$5a86(a5), a4
  0009ee:  30 2e 00 08            move.w $8(a6), d0
  0009f2:  48 c0                  ext.l d0
  0009f4:  e5 88                  lsl.l #$2, d0
  0009f6:  d0 8c                  add.l a4, d0
  0009f8:  28 40                  movea.l d0, a4
  0009fa:  4a 94                  tst.l (a4)
  0009fc:  67 04                  beq.b $a02
  0009fe:  20 54                  movea.l (a4), a0
  000a00:  a0 23                  dc.w $a023
  000a02:  42 94                  clr.l (a4)
  000a04:  49 ed a5 9a            lea.l -$5a66(a5), a4
  000a08:  30 2e 00 08            move.w $8(a6), d0
  000a0c:  48 c0                  ext.l d0
  000a0e:  e5 88                  lsl.l #$2, d0
  000a10:  d0 8c                  add.l a4, d0
  000a12:  28 40                  movea.l d0, a4
  000a14:  4a 94                  tst.l (a4)
  000a16:  67 04                  beq.b $a1c
  000a18:  20 54                  movea.l (a4), a0
  000a1a:  a0 23                  dc.w $a023
  000a1c:  42 94                  clr.l (a4)
  000a1e:  28 5f                  movea.l (a7)+, a4
  000a20:  4e 5e                  unlk a6
  000a22:  4e 75                  rts 
  000a24:  42 6d ba 7c            clr.w -$4584(a5)
  000a28:  4a 6d a5 ba            tst.w -$5a46(a5)
  000a2c:  67 06                  beq.b $a34
  000a2e:  4e ba 00 f6            jsr $b26(pc)
  000a32:  60 04                  bra.b $a38
  000a34:  4e ba 00 04            jsr $a3a(pc)
  000a38:  4e 75                  rts 
  000a3a:  48 e7 0f 00            movem.l d4-d7, -(a7)
  000a3e:  48 6d a1 f8            pea.l -$5e08(a5)
  000a42:  a9 76                  dc.w $a976
  000a44:  2e 2d a1 f8            move.l -$5e08(a5), d7
  000a48:  2c 2d a1 fc            move.l -$5e04(a5), d6
  000a4c:  2a 2d a2 00            move.l -$5e00(a5), d5
  000a50:  28 2d a2 04            move.l -$5dfc(a5), d4
  000a54:  42 2d ba bb            clr.b -$4545(a5)
  000a58:  42 2d ba ba            clr.b -$4546(a5)
  000a5c:  42 2d ba b9            clr.b -$4547(a5)
  000a60:  4a 46                  tst.w d6
  000a62:  6a 06                  bpl.b $a6a
  000a64:  70 00                  moveq #$0, d0
  000a66:  60 00 00 b8            bra.w $b20
  000a6a:  20 07                  move.l d7, d0
  000a6c:  02 80 02 20 00 00      andi.l #$2200000, d0
  000a72:  66 1a                  bne.b $a8e
  000a74:  20 06                  move.l d6, d0
  000a76:  02 80 41 00 00 00      andi.l #$41000000, d0
  000a7c:  66 10                  bne.b $a8e
  000a7e:  20 05                  move.l d5, d0
  000a80:  02 80 00 00 48 02      andi.l #$4802, d0
  000a86:  66 06                  bne.b $a8e
  000a88:  08 04 00 03            btst.b #$3, d4
  000a8c:  67 04                  beq.b $a92
  000a8e:  53 2d ba b9            subq.b #$1, -$4547(a5)
  000a92:  20 07                  move.l d7, d0
  000a94:  02 80 08 80 00 80      andi.l #$8800080, d0
  000a9a:  66 16                  bne.b $ab2
  000a9c:  08 06 00 1d            btst.b #$1d, d6
  000aa0:  66 10                  bne.b $ab2
  000aa2:  20 05                  move.l d5, d0
  000aa4:  02 80 00 00 20 11      andi.l #$2011, d0
  000aaa:  66 06                  bne.b $ab2
  000aac:  08 04 00 04            btst.b #$4, d4
  000ab0:  67 04                  beq.b $ab6
  000ab2:  52 2d ba b9            addq.b #$1, -$4547(a5)
  000ab6:  20 07                  move.l d7, d0
  000ab8:  02 80 00 e0 00 80      andi.l #$e00080, d0
  000abe:  66 16                  bne.b $ad6
  000ac0:  20 06                  move.l d6, d0
  000ac2:  02 80 05 00 00 00      andi.l #$5000000, d0
  000ac8:  66 0c                  bne.b $ad6
  000aca:  70 1a                  moveq #$1a, d0
  000acc:  c0 85                  and.l d5, d0
  000ace:  66 06                  bne.b $ad6
  000ad0:  08 04 00 06            btst.b #$6, d4
  000ad4:  67 04                  beq.b $ada
  000ad6:  53 2d ba ba            subq.b #$1, -$4546(a5)
  000ada:  08 07 00 1a            btst.b #$1a, d7
  000ade:  66 16                  bne.b $af6
  000ae0:  08 06 00 10            btst.b #$10, d6
  000ae4:  66 10                  bne.b $af6
  000ae6:  20 05                  move.l d5, d0
  000ae8:  02 80 00 00 90 00      andi.l #$9000, d0
  000aee:  66 06                  bne.b $af6
  000af0:  08 04 00 05            btst.b #$5, d4
  000af4:  67 04                  beq.b $afa
  000af6:  52 2d ba ba            addq.b #$1, -$4546(a5)
  000afa:  70 0d                  moveq #$d, d0
  000afc:  c0 86                  and.l d6, d0
  000afe:  66 06                  bne.b $b06
  000b00:  08 05 00 0a            btst.b #$a, d5
  000b04:  67 04                  beq.b $b0a
  000b06:  53 2d ba bb            subq.b #$1, -$4545(a5)
  000b0a:  4a 87                  tst.l d7
  000b0c:  66 0c                  bne.b $b1a
  000b0e:  4a 86                  tst.l d6
  000b10:  66 08                  bne.b $b1a
  000b12:  4a 85                  tst.l d5
  000b14:  66 04                  bne.b $b1a
  000b16:  4a 84                  tst.l d4
  000b18:  67 04                  beq.b $b1e
  000b1a:  70 01                  moveq #$1, d0
  000b1c:  60 02                  bra.b $b20
  000b1e:  70 00                  moveq #$0, d0
  000b20:  4c df 00 f0            movem.l (a7)+, d4-d7
  000b24:  4e 75                  rts 
  000b26:  42 2d ba bb            clr.b -$4545(a5)
  000b2a:  42 2d ba ba            clr.b -$4546(a5)
  000b2e:  42 2d ba b9            clr.b -$4547(a5)
  000b32:  70 00                  moveq #$0, d0
  000b34:  4e 75                  rts 
  000b36:  4a 6d ba 32            tst.w -$45ce(a5)
  000b3a:  67 06                  beq.b $b42
  000b3c:  42 6d ba 32            clr.w -$45ce(a5)
  000b40:  60 06                  bra.b $b48
  000b42:  3b 7c 00 01 ba 32      move.w #$1, -$45ce(a5)
  000b48:  3b 7c 00 01 b9 40      move.w #$1, -$46c0(a5)
  000b4e:  4e 75                  rts 
  000b50:  3b 7c 00 c8 ba 30      move.w #$c8, -$45d0(a5)
  000b56:  3b 7c 00 0c ba 18      move.w #$c, -$45e8(a5)
  000b5c:  3b 7c 00 03 ba 1a      move.w #$3, -$45e6(a5)
  000b62:  4e ad 00 fa            jsr $fa(a5)
  000b66:  3f 3c 00 27            move.w #$27, -(a7)
  000b6a:  4e ba fc 48            jsr $7b4(pc)
  000b6e:  54 8f                  addq.l #$2, a7
  000b70:  4e 75                  rts 
  000b72:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  000b76:  2b 6d 96 c2 96 c6      move.l -$693e(a5), -$693a(a5)
  000b7c:  30 6d ba 6a            movea.w -$4596(a5), a0
  000b80:  2b 48 96 c2            move.l a0, -$693e(a5)
  000b84:  3f 3c 00 01            move.w #$1, -(a7)
  000b88:  4e ad 00 72            jsr $72(a5)
  000b8c:  7e 00                  moveq #$0, d7
  000b8e:  49 ed b9 94            lea.l -$466c(a5), a4
  000b92:  54 8f                  addq.l #$2, a7
  000b94:  60 4a                  bra.b $be0
  000b96:  7c 00                  moveq #$0, d6
  000b98:  97 cb                  suba.l a3, a3
  000b9a:  60 38                  bra.b $bd4
  000b9c:  7a ff                  moveq #$ff, d5
  000b9e:  78 00                  moveq #$0, d4
  000ba0:  60 26                  bra.b $bc8
  000ba2:  76 4c                  moveq #$4c, d3
  000ba4:  08 06 00 00            btst.b #$0, d6
  000ba8:  67 02                  beq.b $bac
  000baa:  58 43                  addq.w #$4, d3
  000bac:  3f 3c 00 03            move.w #$3, -(a7)
  000bb0:  4e ad 00 72            jsr $72(a5)
  000bb4:  d6 40                  add.w d0, d3
  000bb6:  54 8f                  addq.l #$2, a7
  000bb8:  ba 43                  cmp.w d3, d5
  000bba:  67 e6                  beq.b $ba2
  000bbc:  20 4c                  movea.l a4, a0
  000bbe:  d1 cb                  adda.l a3, a0
  000bc0:  11 83 40 00            move.b d3, (a0, d4.w)
  000bc4:  3a 03                  move.w d3, d5
  000bc6:  52 44                  addq.w #$1, d4
  000bc8:  0c 44 00 0a            cmpi.w #$a, d4
  000bcc:  6f d4                  ble.b $ba2
  000bce:  52 46                  addq.w #$1, d6
  000bd0:  47 eb 00 0b            lea.l $b(a3), a3
  000bd4:  0c 46 00 04            cmpi.w #$4, d6
  000bd8:  6d c2                  blt.b $b9c
  000bda:  52 47                  addq.w #$1, d7
  000bdc:  49 ec 00 2c            lea.l $2c(a4), a4
  000be0:  0c 47 00 03            cmpi.w #$3, d7
  000be4:  6d b0                  blt.b $b96
  000be6:  2b 6d 96 c6 96 c2      move.l -$693a(a5), -$693e(a5)
  000bec:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  000bf0:  4e 75                  rts 
  000bf2:  30 2d a5 66            move.w -$5a9a(a5), d0
  000bf6:  52 6d a5 66            addq.w #$1, -$5a9a(a5)
  000bfa:  0c 40 00 12            cmpi.w #$12, d0
  000bfe:  62 00 02 a8            bhi.w $ea8
  000c02:  43 fa 02 aa            lea.l $eae(pc), a1
  000c06:  d0 40                  add.w d0, d0
  000c08:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000c0c:  4e d1                  jmp (a1)
  000c0e:  4e ba 04 0c            jsr $101c(pc)
  000c12:  3f 3c 00 36            move.w #$36, -(a7)
  000c16:  4e ad 00 d2            jsr $d2(a5)
  000c1a:  3e bc 00 37            move.w #$37, (a7)
  000c1e:  4e ad 00 d2            jsr $d2(a5)
  000c22:  1b 7c 00 01 96 e5      move.b #$1, -$691b(a5)
  000c28:  4e ad 00 e2            jsr $e2(a5)
  000c2c:  54 8f                  addq.l #$2, a7
  000c2e:  60 00 02 7c            bra.w $eac
  000c32:  3f 3c 00 02            move.w #$2, -(a7)
  000c36:  4e ba 03 ae            jsr $fe6(pc)
  000c3a:  48 78 00 01            pea.l $1.w
  000c3e:  42 a7                  clr.l -(a7)
  000c40:  3f 3c 00 04            move.w #$4, -(a7)
  000c44:  4e ad 04 b2            jsr $4b2(a5)
  000c48:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  000c4e:  4f ef 00 0c            lea.l $c(a7), a7
  000c52:  60 00 02 58            bra.w $eac
  000c56:  3f 3c 00 36            move.w #$36, -(a7)
  000c5a:  4e ad 00 f2            jsr $f2(a5)
  000c5e:  3b 7c 00 05 a5 68      move.w #$5, -$5a98(a5)
  000c64:  2b 7c 00 00 00 f2 a5 6c move.l #$f2, -$5a94(a5)
  000c6c:  54 8f                  addq.l #$2, a7
  000c6e:  60 00 02 3c            bra.w $eac
  000c72:  2f 3c 00 6a 00 01      move.l #$6a0001, -(a7)
  000c78:  2f 3c 00 01 00 5c      move.l #$1005c, -(a7)
  000c7e:  3f 3c 00 04            move.w #$4, -(a7)
  000c82:  4e ad 04 b2            jsr $4b2(a5)
  000c86:  3b 7c 00 11 a5 68      move.w #$11, -$5a98(a5)
  000c8c:  4f ef 00 0a            lea.l $a(a7), a7
  000c90:  60 00 02 1a            bra.w $eac
  000c94:  48 78 00 01            pea.l $1.w
  000c98:  42 a7                  clr.l -(a7)
  000c9a:  3f 3c 00 04            move.w #$4, -(a7)
  000c9e:  4e ad 04 b2            jsr $4b2(a5)
  000ca2:  3b 7c 00 05 a5 68      move.w #$5, -$5a98(a5)
  000ca8:  2b 7c 00 00 01 f3 a5 6c move.l #$1f3, -$5a94(a5)
  000cb0:  4f ef 00 0a            lea.l $a(a7), a7
  000cb4:  60 00 01 f6            bra.w $eac
  000cb8:  2f 3c 00 7a 00 01      move.l #$7a0001, -(a7)
  000cbe:  2f 3c 00 02 00 60      move.l #$20060, -(a7)
  000cc4:  3f 3c 00 04            move.w #$4, -(a7)
  000cc8:  4e ad 04 b2            jsr $4b2(a5)
  000ccc:  3b 7c 00 19 a5 68      move.w #$19, -$5a98(a5)
  000cd2:  4f ef 00 0a            lea.l $a(a7), a7
  000cd6:  60 00 01 d4            bra.w $eac
  000cda:  48 78 00 01            pea.l $1.w
  000cde:  42 a7                  clr.l -(a7)
  000ce0:  3f 3c 00 04            move.w #$4, -(a7)
  000ce4:  4e ad 04 b2            jsr $4b2(a5)
  000ce8:  3b 7c 00 0f a5 68      move.w #$f, -$5a98(a5)
  000cee:  2b 7c 00 00 03 c8 a5 6c move.l #$3c8, -$5a94(a5)
  000cf6:  4f ef 00 0a            lea.l $a(a7), a7
  000cfa:  60 00 01 b0            bra.w $eac
  000cfe:  2f 3c 00 6b 00 01      move.l #$6b0001, -(a7)
  000d04:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  000d0a:  3f 3c 00 04            move.w #$4, -(a7)
  000d0e:  4e ad 04 b2            jsr $4b2(a5)
  000d12:  2e bc 00 b8 00 01      move.l #$b80001, (a7)
  000d18:  2f 3c 00 04 00 28      move.l #$40028, -(a7)
  000d1e:  3f 3c 00 04            move.w #$4, -(a7)
  000d22:  4e ad 04 b2            jsr $4b2(a5)
  000d26:  3b 7c 00 23 a5 68      move.w #$23, -$5a98(a5)
  000d2c:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  000d32:  4f ef 00 10            lea.l $10(a7), a7
  000d36:  60 00 01 74            bra.w $eac
  000d3a:  3f 3c 00 17            move.w #$17, -(a7)
  000d3e:  4e ba 02 a6            jsr $fe6(pc)
  000d42:  2f 3c 00 19 00 01      move.l #$190001, -(a7)
  000d48:  2f 3c 00 01 00 18      move.l #$10018, -(a7)
  000d4e:  3f 3c 00 03            move.w #$3, -(a7)
  000d52:  4e ad 04 b2            jsr $4b2(a5)
  000d56:  3b 7c 00 07 a5 5c      move.w #$7, -$5aa4(a5)
  000d5c:  4f ef 00 0c            lea.l $c(a7), a7
  000d60:  60 00 01 4a            bra.w $eac
  000d64:  3f 3c 00 37            move.w #$37, -(a7)
  000d68:  4e ad 00 f2            jsr $f2(a5)
  000d6c:  3b 7c 00 4b a5 68      move.w #$4b, -$5a98(a5)
  000d72:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  000d78:  54 8f                  addq.l #$2, a7
  000d7a:  60 00 01 30            bra.w $eac
  000d7e:  48 6d 02 0a            pea.l $20a(a5)
  000d82:  42 67                  clr.w -(a7)
  000d84:  4e ba 13 d6            jsr $215c(pc)
  000d88:  5c 8f                  addq.l #$6, a7
  000d8a:  60 00 01 20            bra.w $eac
  000d8e:  4e ba 02 8c            jsr $101c(pc)
  000d92:  3f 3c 00 34            move.w #$34, -(a7)
  000d96:  4e ad 00 d2            jsr $d2(a5)
  000d9a:  1b 7c 00 01 96 e5      move.b #$1, -$691b(a5)
  000da0:  4e ad 00 e2            jsr $e2(a5)
  000da4:  54 8f                  addq.l #$2, a7
  000da6:  60 00 01 04            bra.w $eac
  000daa:  3f 3c 00 17            move.w #$17, -(a7)
  000dae:  4e ba 02 36            jsr $fe6(pc)
  000db2:  2f 3c 00 19 00 01      move.l #$190001, -(a7)
  000db8:  2f 3c 00 02 00 18      move.l #$20018, -(a7)
  000dbe:  3f 3c 00 03            move.w #$3, -(a7)
  000dc2:  4e ad 04 b2            jsr $4b2(a5)
  000dc6:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  000dcc:  4f ef 00 0c            lea.l $c(a7), a7
  000dd0:  60 00 00 da            bra.w $eac
  000dd4:  3f 3c 00 34            move.w #$34, -(a7)
  000dd8:  4e ad 00 f2            jsr $f2(a5)
  000ddc:  3b 7c 00 64 a5 68      move.w #$64, -$5a98(a5)
  000de2:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  000de8:  54 8f                  addq.l #$2, a7
  000dea:  60 00 00 c0            bra.w $eac
  000dee:  48 78 00 01            pea.l $1.w
  000df2:  42 a7                  clr.l -(a7)
  000df4:  3f 3c 00 04            move.w #$4, -(a7)
  000df8:  4e ad 04 b2            jsr $4b2(a5)
  000dfc:  2e bc 00 6b 00 01      move.l #$6b0001, (a7)
  000e02:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  000e08:  3f 3c 00 04            move.w #$4, -(a7)
  000e0c:  4e ad 04 b2            jsr $4b2(a5)
  000e10:  2e bc 00 b8 00 01      move.l #$b80001, (a7)
  000e16:  2f 3c 00 04 00 28      move.l #$40028, -(a7)
  000e1c:  3f 3c 00 04            move.w #$4, -(a7)
  000e20:  4e ad 04 b2            jsr $4b2(a5)
  000e24:  3b 7c 00 02 a5 5c      move.w #$2, -$5aa4(a5)
  000e2a:  3b 7c 00 3c a5 68      move.w #$3c, -$5a98(a5)
  000e30:  4f ef 00 16            lea.l $16(a7), a7
  000e34:  60 76                  bra.b $eac
  000e36:  3f 3c 00 1b            move.w #$1b, -(a7)
  000e3a:  4e ba 01 aa            jsr $fe6(pc)
  000e3e:  2f 3c 00 1a 00 01      move.l #$1a0001, -(a7)
  000e44:  2f 3c 00 04 00 18      move.l #$40018, -(a7)
  000e4a:  3f 3c 00 03            move.w #$3, -(a7)
  000e4e:  4e ad 04 b2            jsr $4b2(a5)
  000e52:  3b 7c 00 09 a5 5c      move.w #$9, -$5aa4(a5)
  000e58:  3b 7c 00 2d a5 68      move.w #$2d, -$5a98(a5)
  000e5e:  4f ef 00 0c            lea.l $c(a7), a7
  000e62:  60 48                  bra.b $eac
  000e64:  4a 6d a5 58            tst.w -$5aa8(a5)
  000e68:  66 42                  bne.b $eac
  000e6a:  52 6d a5 66            addq.w #$1, -$5a9a(a5)
  000e6e:  60 3c                  bra.b $eac
  000e70:  3f 3c 00 1b            move.w #$1b, -(a7)
  000e74:  4e ba 01 70            jsr $fe6(pc)
  000e78:  2f 3c 00 14 00 01      move.l #$140001, -(a7)
  000e7e:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  000e84:  3f 3c 00 04            move.w #$4, -(a7)
  000e88:  4e ad 04 b2            jsr $4b2(a5)
  000e8c:  4e ba 13 b4            jsr $2242(pc)
  000e90:  3b 7c 00 09 a5 5c      move.w #$9, -$5aa4(a5)
  000e96:  3b 7c 00 32 a5 68      move.w #$32, -$5a98(a5)
  000e9c:  4f ef 00 0c            lea.l $c(a7), a7
  000ea0:  60 0a                  bra.b $eac
  000ea2:  4e ba 01 a2            jsr $1046(pc)
  000ea6:  60 04                  bra.b $eac
  000ea8:  42 6d a5 66            clr.w -$5a9a(a5)
  000eac:  4e 75                  rts 
  000eae:  fd 60                  dc.w $fd60
  000eb0:  fd 84                  dc.w $fd84
  000eb2:  fd a8                  dc.w $fda8
  000eb4:  fd c4                  dc.w $fdc4
  000eb6:  fd e6                  dc.w $fde6
  000eb8:  fe 0a                  dc.w $fe0a
  000eba:  fe 2c                  dc.w $fe2c
  000ebc:  fe 50                  dc.w $fe50
  000ebe:  fe 8c                  dc.w $fe8c
  000ec0:  fe b6                  dc.w $feb6
  000ec2:  fe d0                  dc.w $fed0
  000ec4:  fe e0                  dc.w $fee0
  000ec6:  fe fc                  dc.w $fefc
  000ec8:  ff 26                  dc.w $ff26
  000eca:  ff 40                  dc.w $ff40
  000ecc:  ff 88                  dc.w $ff88
  000ece:  ff b6                  dc.w $ffb6
  000ed0:  ff c2                  dc.w $ffc2
  000ed2:  ff f4                  dc.w $fff4
  000ed4:  30 2d a5 66            move.w -$5a9a(a5), d0
  000ed8:  52 6d a5 66            addq.w #$1, -$5a9a(a5)
  000edc:  0c 40 00 06            cmpi.w #$6, d0
  000ee0:  62 00 00 f0            bhi.w $fd2
  000ee4:  43 fa 00 f2            lea.l $fd8(pc), a1
  000ee8:  d0 40                  add.w d0, d0
  000eea:  d2 f1 00 00            adda.w (a1, d0.w), a1
  000eee:  4e d1                  jmp (a1)
  000ef0:  2f 3c 00 03 00 28      move.l #$30028, -(a7)
  000ef6:  4e ba f9 6e            jsr $866(pc)
  000efa:  2e bc 00 04 00 3c      move.l #$4003c, (a7)
  000f00:  4e ba f9 64            jsr $866(pc)
  000f04:  3b 7c 00 01 f2 28      move.w #$1, -$dd8(a5)
  000f0a:  2b 6d a5 c4 a2 e4      move.l -$5a3c(a5), -$5d1c(a5)
  000f10:  2b 6d a5 c8 a2 e8      move.l -$5a38(a5), -$5d18(a5)
  000f16:  58 8f                  addq.l #$4, a7
  000f18:  60 00 00 bc            bra.w $fd6
  000f1c:  3f 3c 00 10            move.w #$10, -(a7)
  000f20:  4e ba 00 c4            jsr $fe6(pc)
  000f24:  48 78 00 01            pea.l $1.w
  000f28:  42 67                  clr.w -(a7)
  000f2a:  3f 2d a5 5a            move.w -$5aa6(a5), -(a7)
  000f2e:  3f 3c 00 04            move.w #$4, -(a7)
  000f32:  4e ad 04 b2            jsr $4b2(a5)
  000f36:  52 6d a5 5a            addq.w #$1, -$5aa6(a5)
  000f3a:  0c 6d 00 04 a5 5a      cmpi.w #$4, -$5aa6(a5)
  000f40:  4f ef 00 0c            lea.l $c(a7), a7
  000f44:  6f 04                  ble.b $f4a
  000f46:  42 6d a5 5a            clr.w -$5aa6(a5)
  000f4a:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  000f50:  60 00 00 84            bra.w $fd6
  000f54:  3b 7c 00 5a a5 68      move.w #$5a, -$5a98(a5)
  000f5a:  60 7a                  bra.b $fd6
  000f5c:  3f 3c 00 10            move.w #$10, -(a7)
  000f60:  4e ba 00 84            jsr $fe6(pc)
  000f64:  3b 7c 00 03 a5 68      move.w #$3, -$5a98(a5)
  000f6a:  54 8f                  addq.l #$2, a7
  000f6c:  60 68                  bra.b $fd6
  000f6e:  48 78 00 01            pea.l $1.w
  000f72:  2f 3c 00 05 00 00      move.l #$50000, -(a7)
  000f78:  3f 3c 00 04            move.w #$4, -(a7)
  000f7c:  4e ad 04 b2            jsr $4b2(a5)
  000f80:  3b 7c 00 4b a5 68      move.w #$4b, -$5a98(a5)
  000f86:  4f ef 00 0a            lea.l $a(a7), a7
  000f8a:  60 4a                  bra.b $fd6
  000f8c:  48 78 00 01            pea.l $1.w
  000f90:  2f 3c 00 06 00 00      move.l #$60000, -(a7)
  000f96:  3f 3c 00 04            move.w #$4, -(a7)
  000f9a:  4e ad 04 b2            jsr $4b2(a5)
  000f9e:  3b 7c 00 46 a5 68      move.w #$46, -$5a98(a5)
  000fa4:  4f ef 00 0a            lea.l $a(a7), a7
  000fa8:  60 2c                  bra.b $fd6
  000faa:  4e ba 00 9a            jsr $1046(pc)
  000fae:  1f 3c 00 02            move.b #$2, -(a7)
  000fb2:  48 6d a5 c4            pea.l -$5a3c(a5)
  000fb6:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  000fba:  4e 90                  jsr (a0)
  000fbc:  48 6d a5 c4            pea.l -$5a3c(a5)
  000fc0:  a9 28                  dc.w $a928
  000fc2:  3b 7c 00 02 a5 5c      move.w #$2, -$5aa4(a5)
  000fc8:  3b 7c 00 0a a5 68      move.w #$a, -$5a98(a5)
  000fce:  5c 8f                  addq.l #$6, a7
  000fd0:  60 04                  bra.b $fd6
  000fd2:  42 6d a5 66            clr.w -$5a9a(a5)
  000fd6:  4e 75                  rts 
  000fd8:  ff 18                  dc.w $ff18
  000fda:  ff 44                  dc.w $ff44
  000fdc:  ff 7c                  dc.w $ff7c
  000fde:  ff 84                  dc.w $ff84
  000fe0:  ff 96                  dc.w $ff96
  000fe2:  ff b4                  dc.w $ffb4
  000fe4:  ff d2                  dc.w $ffd2
  000fe6:  4e 56 00 00            link.w a6, #$0
  000fea:  48 78 00 01            pea.l $1.w
  000fee:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  000ff4:  3f 3c 00 03            move.w #$3, -(a7)
  000ff8:  4e ad 01 12            jsr $112(a5)
  000ffc:  1e ae 00 09            move.b $9(a6), (a7)
  001000:  48 6d a5 f4            pea.l -$5a0c(a5)
  001004:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  001008:  4e 90                  jsr (a0)
  00100a:  70 01                  moveq #$1, d0
  00100c:  2e 80                  move.l d0, (a7)
  00100e:  42 a7                  clr.l -(a7)
  001010:  3f 3c 00 03            move.w #$3, -(a7)
  001014:  4e ad 04 b2            jsr $4b2(a5)
  001018:  4e 5e                  unlk a6
  00101a:  4e 75                  rts 
  00101c:  2f 3c 00 03 00 28      move.l #$30028, -(a7)
  001022:  4e ba f8 42            jsr $866(pc)
  001026:  2e bc 00 04 00 32      move.l #$40032, (a7)
  00102c:  4e ba f8 38            jsr $866(pc)
  001030:  3b 7c 00 01 f2 28      move.w #$1, -$dd8(a5)
  001036:  2b 6d a5 c4 a2 e4      move.l -$5a3c(a5), -$5d1c(a5)
  00103c:  2b 6d a5 c8 a2 e8      move.l -$5a38(a5), -$5d18(a5)
  001042:  58 8f                  addq.l #$4, a7
  001044:  4e 75                  rts 
  001046:  4e ad 00 fa            jsr $fa(a5)
  00104a:  4e ad 00 ea            jsr $ea(a5)
  00104e:  4e ba 00 34            jsr $1084(pc)
  001052:  3f 3c 00 03            move.w #$3, -(a7)
  001056:  4e ba f9 66            jsr $9be(pc)
  00105a:  42 6d f2 28            clr.w -$dd8(a5)
  00105e:  54 8f                  addq.l #$2, a7
  001060:  4e 75                  rts 
  001062:  4e ad 00 fa            jsr $fa(a5)
  001066:  4e ad 00 ea            jsr $ea(a5)
  00106a:  4e ba 00 18            jsr $1084(pc)
  00106e:  3f 3c 00 03            move.w #$3, -(a7)
  001072:  4e ba f9 4a            jsr $9be(pc)
  001076:  3b 7c ff ff a9 0c      move.w #$ffff, -$56f4(a5)
  00107c:  42 2d a5 be            clr.b -$5a42(a5)
  001080:  54 8f                  addq.l #$2, a7
  001082:  4e 75                  rts 
  001084:  2f 07                  move.l d7, -(a7)
  001086:  7e 2c                  moveq #$2c, d7
  001088:  60 0a                  bra.b $1094
  00108a:  3f 07                  move.w d7, -(a7)
  00108c:  4e ad 00 da            jsr $da(a5)
  001090:  54 8f                  addq.l #$2, a7
  001092:  52 47                  addq.w #$1, d7
  001094:  0c 47 00 3a            cmpi.w #$3a, d7
  001098:  6d f0                  blt.b $108a
  00109a:  2e 1f                  move.l (a7)+, d7
  00109c:  4e 75                  rts 
  00109e:  4e ba ff e4            jsr $1084(pc)
  0010a2:  3f 3c 00 03            move.w #$3, -(a7)
  0010a6:  4e ba f9 16            jsr $9be(pc)
  0010aa:  54 8f                  addq.l #$2, a7
  0010ac:  4e 75                  rts 
  0010ae:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  0010b2:  4a 2d a2 0f            tst.b -$5df1(a5)
  0010b6:  67 00 01 20            beq.w $11d8
  0010ba:  20 6d a2 32            movea.l -$5dce(a5), a0
  0010be:  70 08                  moveq #$8, d0
  0010c0:  d0 90                  add.l (a0), d0
  0010c2:  28 40                  movea.l d0, a4
  0010c4:  22 6d a2 58            movea.l -$5da8(a5), a1
  0010c8:  70 08                  moveq #$8, d0
  0010ca:  d0 91                  add.l (a1), d0
  0010cc:  26 40                  movea.l d0, a3
  0010ce:  7e 00                  moveq #$0, d7
  0010d0:  60 00 00 ea            bra.w $11bc
  0010d4:  3f 3c 00 63            move.w #$63, -(a7)
  0010d8:  4e ad 00 72            jsr $72(a5)
  0010dc:  3c 00                  move.w d0, d6
  0010de:  0c 47 00 02            cmpi.w #$2, d7
  0010e2:  54 8f                  addq.l #$2, a7
  0010e4:  6e 00 00 92            bgt.w $1178
  0010e8:  0c 46 00 5c            cmpi.w #$5c, d6
  0010ec:  6c 64                  bge.b $1152
  0010ee:  3f 3c 00 63            move.w #$63, -(a7)
  0010f2:  4e ad 00 72            jsr $72(a5)
  0010f6:  3c 00                  move.w d0, d6
  0010f8:  0c 46 00 0a            cmpi.w #$a, d6
  0010fc:  54 8f                  addq.l #$2, a7
  0010fe:  6c 1a                  bge.b $111a
  001100:  20 4c                  movea.l a4, a0
  001102:  20 07                  move.l d7, d0
  001104:  48 c0                  ext.l d0
  001106:  e7 88                  lsl.l #$3, d0
  001108:  d1 c0                  adda.l d0, a0
  00110a:  21 6c 00 2a 06 22      move.l $2a(a4), $622(a0)
  001110:  31 6c 00 2e 06 26      move.w $2e(a4), $626(a0)
  001116:  60 00 00 a2            bra.w $11ba
  00111a:  0c 46 00 28            cmpi.w #$28, d6
  00111e:  6c 1a                  bge.b $113a
  001120:  20 4c                  movea.l a4, a0
  001122:  20 07                  move.l d7, d0
  001124:  48 c0                  ext.l d0
  001126:  e7 88                  lsl.l #$3, d0
  001128:  d1 c0                  adda.l d0, a0
  00112a:  21 6c 00 32 06 22      move.l $32(a4), $622(a0)
  001130:  31 6c 00 36 06 26      move.w $36(a4), $626(a0)
  001136:  60 00 00 82            bra.w $11ba
  00113a:  20 4c                  movea.l a4, a0
  00113c:  20 07                  move.l d7, d0
  00113e:  48 c0                  ext.l d0
  001140:  e7 88                  lsl.l #$3, d0
  001142:  d1 c0                  adda.l d0, a0
  001144:  21 6c 00 3a 06 22      move.l $3a(a4), $622(a0)
  00114a:  31 6c 00 3e 06 26      move.w $3e(a4), $626(a0)
  001150:  60 68                  bra.b $11ba
  001152:  3f 3c 00 02            move.w #$2, -(a7)
  001156:  4e ad 00 72            jsr $72(a5)
  00115a:  48 c0                  ext.l d0
  00115c:  e7 88                  lsl.l #$3, d0
  00115e:  20 4c                  movea.l a4, a0
  001160:  22 07                  move.l d7, d1
  001162:  48 c1                  ext.l d1
  001164:  e7 89                  lsl.l #$3, d1
  001166:  d1 c1                  adda.l d1, a0
  001168:  21 73 08 02 06 22      move.l $2(a3, d0.l), $622(a0)
  00116e:  31 73 08 06 06 26      move.w $6(a3, d0.l), $626(a0)
  001174:  54 8f                  addq.l #$2, a7
  001176:  60 42                  bra.b $11ba
  001178:  0c 46 00 63            cmpi.w #$63, d6
  00117c:  6c 18                  bge.b $1196
  00117e:  20 4c                  movea.l a4, a0
  001180:  20 07                  move.l d7, d0
  001182:  48 c0                  ext.l d0
  001184:  e7 88                  lsl.l #$3, d0
  001186:  d1 c0                  adda.l d0, a0
  001188:  21 6c 00 12 06 22      move.l $12(a4), $622(a0)
  00118e:  31 6c 00 16 06 26      move.w $16(a4), $626(a0)
  001194:  60 24                  bra.b $11ba
  001196:  3f 3c 00 01            move.w #$1, -(a7)
  00119a:  4e ad 00 72            jsr $72(a5)
  00119e:  48 c0                  ext.l d0
  0011a0:  e7 88                  lsl.l #$3, d0
  0011a2:  20 4c                  movea.l a4, a0
  0011a4:  22 07                  move.l d7, d1
  0011a6:  48 c1                  ext.l d1
  0011a8:  e7 89                  lsl.l #$3, d1
  0011aa:  d1 c1                  adda.l d1, a0
  0011ac:  21 73 08 1a 06 22      move.l $1a(a3, d0.l), $622(a0)
  0011b2:  31 73 08 1e 06 26      move.w $1e(a3, d0.l), $626(a0)
  0011b8:  54 8f                  addq.l #$2, a7
  0011ba:  52 47                  addq.w #$1, d7
  0011bc:  0c 47 00 05            cmpi.w #$5, d7
  0011c0:  6d 00 ff 12            blt.w $10d4
  0011c4:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  0011c8:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  0011cc:  2f 3c 00 c4 00 c4      move.l #$c400c4, -(a7)
  0011d2:  3f 3c 00 05            move.w #$5, -(a7)
  0011d6:  aa 9a                  dc.w $aa9a
  0011d8:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  0011dc:  4e 75                  rts 
  0011de:  4e 56 00 00            link.w a6, #$0
  0011e2:  42 6d ba 86            clr.w -$457a(a5)
  0011e6:  42 6d ba 90            clr.w -$4570(a5)
  0011ea:  42 6d ba 42            clr.w -$45be(a5)
  0011ee:  42 6d ba 32            clr.w -$45ce(a5)
  0011f2:  4a 6d b9 3e            tst.w -$46c2(a5)
  0011f6:  67 06                  beq.b $11fe
  0011f8:  42 6d b9 3e            clr.w -$46c2(a5)
  0011fc:  60 1a                  bra.b $1218
  0011fe:  3b 7c 00 3c ba 8c      move.w #$3c, -$4574(a5)
  001204:  3b 7c 02 cf ba 80      move.w #$2cf, -$4580(a5)
  00120a:  3b 7c 00 03 ba 46      move.w #$3, -$45ba(a5)
  001210:  42 6d 96 d6            clr.w -$692a(a5)
  001214:  42 6d 96 d4            clr.w -$692c(a5)
  001218:  4a 6e 00 08            tst.w $8(a6)
  00121c:  66 06                  bne.b $1224
  00121e:  3b 7c 00 04 ba 46      move.w #$4, -$45ba(a5)
  001224:  42 ad 96 d8            clr.l -$6928(a5)
  001228:  0c 6e 00 01 00 08      cmpi.w #$1, $8(a6)
  00122e:  66 08                  bne.b $1238
  001230:  3b 7c 00 01 ba 98      move.w #$1, -$4568(a5)
  001236:  60 04                  bra.b $123c
  001238:  42 6d ba 98            clr.w -$4568(a5)
  00123c:  4e 5e                  unlk a6
  00123e:  4e 75                  rts 
  001240:  4e 56 00 00            link.w a6, #$0
  001244:  2f 07                  move.l d7, -(a7)
  001246:  3e 2e 00 08            move.w $8(a6), d7
  00124a:  3f 07                  move.w d7, -(a7)
  00124c:  4e ba f0 38            jsr $286(pc)
  001250:  4e ba f1 56            jsr $3a8(pc)
  001254:  4e ba 06 34            jsr $188a(pc)
  001258:  4e ad 03 c2            jsr $3c2(a5)
  00125c:  4e ba 2c f4            jsr $3f52(pc)
  001260:  42 6d ba 2c            clr.w -$45d4(a5)
  001264:  42 6d ba 4c            clr.w -$45b4(a5)
  001268:  42 6d ba 52            clr.w -$45ae(a5)
  00126c:  42 6d ba 50            clr.w -$45b0(a5)
  001270:  42 6d ba 5c            clr.w -$45a4(a5)
  001274:  42 6d ba 5a            clr.w -$45a6(a5)
  001278:  42 6d ba 26            clr.w -$45da(a5)
  00127c:  42 6d ba 54            clr.w -$45ac(a5)
  001280:  42 6d ba 24            clr.w -$45dc(a5)
  001284:  42 6d ba 8e            clr.w -$4572(a5)
  001288:  42 6d ba 1a            clr.w -$45e6(a5)
  00128c:  42 6d ba 3c            clr.w -$45c4(a5)
  001290:  42 6d ba 3a            clr.w -$45c6(a5)
  001294:  42 6d ba 82            clr.w -$457e(a5)
  001298:  42 6d ba 6a            clr.w -$4596(a5)
  00129c:  42 6d bc ea            clr.w -$4316(a5)
  0012a0:  42 6d bc 6c            clr.w -$4394(a5)
  0012a4:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  0012aa:  1b 7c 00 02 b9 87      move.b #$2, -$4679(a5)
  0012b0:  1b 7c 00 56 b9 7f      move.b #$56, -$4681(a5)
  0012b6:  4e ba 00 34            jsr $12ec(pc)
  0012ba:  0c 47 00 01            cmpi.w #$1, d7
  0012be:  54 8f                  addq.l #$2, a7
  0012c0:  67 08                  beq.b $12ca
  0012c2:  3b 7c 00 01 ba 28      move.w #$1, -$45d8(a5)
  0012c8:  60 04                  bra.b $12ce
  0012ca:  42 6d ba 28            clr.w -$45d8(a5)
  0012ce:  0c 47 00 03            cmpi.w #$3, d7
  0012d2:  67 0a                  beq.b $12de
  0012d4:  0c 47 00 0f            cmpi.w #$f, d7
  0012d8:  67 04                  beq.b $12de
  0012da:  42 6d ba 40            clr.w -$45c0(a5)
  0012de:  4e ba 01 58            jsr $1438(pc)
  0012e2:  4e ba 01 9a            jsr $147e(pc)
  0012e6:  2e 1f                  move.l (a7)+, d7
  0012e8:  4e 5e                  unlk a6
  0012ea:  4e 75                  rts 
  0012ec:  0c 6d 00 03 a9 0c      cmpi.w #$3, -$56f4(a5)
  0012f2:  66 36                  bne.b $132a
  0012f4:  4a 6d ba 40            tst.w -$45c0(a5)
  0012f8:  67 30                  beq.b $132a
  0012fa:  1b 7c 00 02 f1 5e      move.b #$2, -$ea2(a5)
  001300:  1b 7c 00 06 f1 5f      move.b #$6, -$ea1(a5)
  001306:  1b 7c 00 ff f1 60      move.b #$ff, -$ea0(a5)
  00130c:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  001312:  3f 3c 00 07            move.w #$7, -(a7)
  001316:  4e ba 1d 60            jsr $3078(pc)
  00131a:  70 00                  moveq #$0, d0
  00131c:  10 2d ba e9            move.b -$4517(a5), d0
  001320:  d0 ad bd 82            add.l -$427e(a5), d0
  001324:  20 40                  movea.l d0, a0
  001326:  42 10                  clr.b (a0)
  001328:  5c 8f                  addq.l #$6, a7
  00132a:  10 2d f1 5e            move.b -$ea2(a5), d0
  00132e:  1b 40 b9 4f            move.b d0, -$46b1(a5)
  001332:  48 80                  ext.w d0
  001334:  3b 40 ba 7c            move.w d0, -$4584(a5)
  001338:  72 00                  moveq #$0, d1
  00133a:  12 2d f1 5f            move.b -$ea1(a5), d1
  00133e:  83 fc 00 0a            divs.w #$a, d1
  001342:  48 41                  swap d1
  001344:  1b 41 b9 4a            move.b d1, -$46b6(a5)
  001348:  72 00                  moveq #$0, d1
  00134a:  12 2d f1 5f            move.b -$ea1(a5), d1
  00134e:  83 fc 00 0a            divs.w #$a, d1
  001352:  1b 41 b9 4b            move.b d1, -$46b5(a5)
  001356:  12 2d b9 4a            move.b -$46b6(a5), d1
  00135a:  48 81                  ext.w d1
  00135c:  20 4d                  movea.l a5, a0
  00135e:  d0 c1                  adda.w d1, a0
  001360:  72 07                  moveq #$7, d1
  001362:  d2 28 b8 7d            add.b -$4783(a0), d1
  001366:  5e 01                  addq.b #$7, d1
  001368:  1b 41 b9 47            move.b d1, -$46b9(a5)
  00136c:  12 2d f1 60            move.b -$ea0(a5), d1
  001370:  46 01                  not.b d1
  001372:  1b 41 b9 49            move.b d1, -$46b7(a5)
  001376:  4a 6d ba 22            tst.w -$45de(a5)
  00137a:  66 0c                  bne.b $1388
  00137c:  30 2d ba 46            move.w -$45ba(a5), d0
  001380:  3b 40 ba 4a            move.w d0, -$45b6(a5)
  001384:  3b 40 ba 48            move.w d0, -$45b8(a5)
  001388:  0c 6d 00 01 a9 0c      cmpi.w #$1, -$56f4(a5)
  00138e:  66 20                  bne.b $13b0
  001390:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  001396:  3f 3c 00 05            move.w #$5, -(a7)
  00139a:  4e ba 1c dc            jsr $3078(pc)
  00139e:  42 97                  clr.l (a7)
  0013a0:  4e ad 04 42            jsr $442(a5)
  0013a4:  3e bc 00 07            move.w #$7, (a7)
  0013a8:  4e ad 05 22            jsr $522(a5)
  0013ac:  5c 8f                  addq.l #$6, a7
  0013ae:  60 1e                  bra.b $13ce
  0013b0:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  0013b6:  66 0c                  bne.b $13c4
  0013b8:  3f 3c 00 54            move.w #$54, -(a7)
  0013bc:  4e ad 05 22            jsr $522(a5)
  0013c0:  54 8f                  addq.l #$2, a7
  0013c2:  60 0a                  bra.b $13ce
  0013c4:  3f 3c 00 05            move.w #$5, -(a7)
  0013c8:  4e ad 05 22            jsr $522(a5)
  0013cc:  54 8f                  addq.l #$2, a7
  0013ce:  4e ba 00 04            jsr $13d4(pc)
  0013d2:  4e 75                  rts 
  0013d4:  42 2d b9 51            clr.b -$46af(a5)
  0013d8:  10 2d b9 4b            move.b -$46b5(a5), d0
  0013dc:  48 80                  ext.w d0
  0013de:  20 4d                  movea.l a5, a0
  0013e0:  d0 c0                  adda.w d0, a0
  0013e2:  d0 c0                  adda.w d0, a0
  0013e4:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  0013ea:  1b 7c 00 ff b9 53      move.b #$ff, -$46ad(a5)
  0013f0:  42 2d b9 52            clr.b -$46ae(a5)
  0013f4:  42 2d b9 4e            clr.b -$46b2(a5)
  0013f8:  42 2d b9 4d            clr.b -$46b3(a5)
  0013fc:  42 6d ba 36            clr.w -$45ca(a5)
  001400:  42 6d ba 34            clr.w -$45cc(a5)
  001404:  42 6d ba 58            clr.w -$45a8(a5)
  001408:  42 6d ba 1c            clr.w -$45e4(a5)
  00140c:  42 6d ba 30            clr.w -$45d0(a5)
  001410:  42 6d ba 2e            clr.w -$45d2(a5)
  001414:  4e ba 1f 3a            jsr $3350(pc)
  001418:  0c 6d 00 07 a9 0c      cmpi.w #$7, -$56f4(a5)
  00141e:  66 12                  bne.b $1432
  001420:  0c 2d 00 11 b9 4f      cmpi.b #$11, -$46b1(a5)
  001426:  66 0a                  bne.b $1432
  001428:  3f 3c 00 03            move.w #$3, -(a7)
  00142c:  4e ba 11 fc            jsr $262a(pc)
  001430:  54 8f                  addq.l #$2, a7
  001432:  4e ba 21 66            jsr $359a(pc)
  001436:  4e 75                  rts 
  001438:  2f 07                  move.l d7, -(a7)
  00143a:  10 2d b9 73            move.b -$468d(a5), d0
  00143e:  48 80                  ext.w d0
  001440:  3f 00                  move.w d0, -(a7)
  001442:  4e ad 04 e2            jsr $4e2(a5)
  001446:  7e 00                  moveq #$0, d7
  001448:  54 8f                  addq.l #$2, a7
  00144a:  60 28                  bra.b $1474
  00144c:  20 6d bd 82            movea.l -$427e(a5), a0
  001450:  70 00                  moveq #$0, d0
  001452:  10 30 70 00            move.b (a0, d7.w), d0
  001456:  02 40 00 1f            andi.w #$1f, d0
  00145a:  0c 40 00 10            cmpi.w #$10, d0
  00145e:  66 12                  bne.b $1472
  001460:  3f 07                  move.w d7, -(a7)
  001462:  10 2d b9 73            move.b -$468d(a5), d0
  001466:  48 80                  ext.w d0
  001468:  3f 00                  move.w d0, -(a7)
  00146a:  4e ad 04 52            jsr $452(a5)
  00146e:  58 8f                  addq.l #$4, a7
  001470:  60 08                  bra.b $147a
  001472:  52 47                  addq.w #$1, d7
  001474:  0c 47 00 1e            cmpi.w #$1e, d7
  001478:  6d d2                  blt.b $144c
  00147a:  2e 1f                  move.l (a7)+, d7
  00147c:  4e 75                  rts 
  00147e:  42 6d ba 32            clr.w -$45ce(a5)
  001482:  10 2d b9 73            move.b -$468d(a5), d0
  001486:  48 80                  ext.w d0
  001488:  3b 40 ba 7c            move.w d0, -$4584(a5)
  00148c:  4e ba f0 6c            jsr $4fa(pc)
  001490:  3f 3c 00 01            move.w #$1, -(a7)
  001494:  4e ba 00 32            jsr $14c8(pc)
  001498:  1e bc 00 01            move.b #$1, (a7)
  00149c:  48 6d a5 d4            pea.l -$5a2c(a5)
  0014a0:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  0014a4:  4e 90                  jsr (a0)
  0014a6:  4e ad 05 0a            jsr $50a(a5)
  0014aa:  3e ad ba 48            move.w -$45b8(a5), (a7)
  0014ae:  3f 2d ba 4a            move.w -$45b6(a5), -(a7)
  0014b2:  4e ba f0 d4            jsr $588(pc)
  0014b6:  3e ad ba 4e            move.w -$45b2(a5), (a7)
  0014ba:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  0014be:  4e ba f1 58            jsr $618(pc)
  0014c2:  4f ef 00 0a            lea.l $a(a7), a7
  0014c6:  4e 75                  rts 
  0014c8:  4e 56 00 00            link.w a6, #$0
  0014cc:  2f 3c 00 01 ff 00      move.l #$1ff00, -(a7)
  0014d2:  4e ad 00 92            jsr $92(a5)
  0014d6:  3b 7c 00 01 a5 5c      move.w #$1, -$5aa4(a5)
  0014dc:  4a 6e 00 08            tst.w $8(a6)
  0014e0:  58 8f                  addq.l #$4, a7
  0014e2:  67 16                  beq.b $14fa
  0014e4:  48 6d a5 c4            pea.l -$5a3c(a5)
  0014e8:  a8 a2                  dc.w $a8a2
  0014ea:  1f 3c 00 02            move.b #$2, -(a7)
  0014ee:  48 6d a5 cc            pea.l -$5a34(a5)
  0014f2:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  0014f6:  4e 90                  jsr (a0)
  0014f8:  5c 8f                  addq.l #$6, a7
  0014fa:  42 6d ba 7e            clr.w -$4582(a5)
  0014fe:  4a 6d ba a8            tst.w -$4558(a5)
  001502:  67 10                  beq.b $1514
  001504:  42 67                  clr.w -(a7)
  001506:  3f 2d ba a6            move.w -$455a(a5), -(a7)
  00150a:  4e ad 00 9a            jsr $9a(a5)
  00150e:  42 6d ba a8            clr.w -$4558(a5)
  001512:  58 8f                  addq.l #$4, a7
  001514:  4a 2d b9 44            tst.b -$46bc(a5)
  001518:  67 04                  beq.b $151e
  00151a:  4e ba f6 56            jsr $b72(pc)
  00151e:  2b 6d a5 cc a2 e4      move.l -$5a34(a5), -$5d1c(a5)
  001524:  2b 6d a5 d0 a2 e8      move.l -$5a30(a5), -$5d18(a5)
  00152a:  42 6d f2 28            clr.w -$dd8(a5)
  00152e:  4e ad 04 8a            jsr $48a(a5)
  001532:  4e ad 01 0a            jsr $10a(a5)
  001536:  3b 7c 00 01 b9 3c      move.w #$1, -$46c4(a5)
  00153c:  4e ad 04 d2            jsr $4d2(a5)
  001540:  42 6d b9 3c            clr.w -$46c4(a5)
  001544:  4e ad 01 0a            jsr $10a(a5)
  001548:  4e ba 04 fa            jsr $1a44(pc)
  00154c:  4e ad 04 c2            jsr $4c2(a5)
  001550:  4e ad 04 d2            jsr $4d2(a5)
  001554:  3b 7c 00 01 f2 28      move.w #$1, -$dd8(a5)
  00155a:  48 6d a2 dc            pea.l -$5d24(a5)
  00155e:  a9 28                  dc.w $a928
  001560:  3b 7c 00 02 ba 84      move.w #$2, -$457c(a5)
  001566:  4e 5e                  unlk a6
  001568:  4e 75                  rts 
  00156a:  42 6d ba 52            clr.w -$45ae(a5)
  00156e:  42 6d ba 50            clr.w -$45b0(a5)
  001572:  4e ba 02 3a            jsr $17ae(pc)
  001576:  4e ba ea e8            jsr $60(pc)
  00157a:  4a 6d 96 d0            tst.w -$6930(a5)
  00157e:  66 6a                  bne.b $15ea
  001580:  4a 6d ba 66            tst.w -$459a(a5)
  001584:  67 0c                  beq.b $1592
  001586:  42 6d ba 66            clr.w -$459a(a5)
  00158a:  42 ad 96 ec            clr.l -$6914(a5)
  00158e:  70 01                  moveq #$1, d0
  001590:  60 5e                  bra.b $15f0
  001592:  30 2d ba 38            move.w -$45c8(a5), d0
  001596:  b0 6d a9 0c            cmp.w -$56f4(a5), d0
  00159a:  67 08                  beq.b $15a4
  00159c:  4e ad 01 02            jsr $102(a5)
  0015a0:  4a 00                  tst.b d0
  0015a2:  67 30                  beq.b $15d4
  0015a4:  4a 6d ba 50            tst.w -$45b0(a5)
  0015a8:  6c 0c                  bge.b $15b6
  0015aa:  3b 7c 00 01 ba 1a      move.w #$1, -$45e6(a5)
  0015b0:  3b 7c 00 09 ba 18      move.w #$9, -$45e8(a5)
  0015b6:  4e ba eb 92            jsr $14a(pc)
  0015ba:  0c 2d 00 02 b9 76      cmpi.b #$2, -$468a(a5)
  0015c0:  66 08                  bne.b $15ca
  0015c2:  70 06                  moveq #$6, d0
  0015c4:  2b 40 96 ec            move.l d0, -$6914(a5)
  0015c8:  60 06                  bra.b $15d0
  0015ca:  70 05                  moveq #$5, d0
  0015cc:  2b 40 96 ec            move.l d0, -$6914(a5)
  0015d0:  70 00                  moveq #$0, d0
  0015d2:  60 1c                  bra.b $15f0
  0015d4:  4e ad 00 fa            jsr $fa(a5)
  0015d8:  3b 6d ba 48 ba 46      move.w -$45b8(a5), -$45ba(a5)
  0015de:  42 6d ba 32            clr.w -$45ce(a5)
  0015e2:  42 ad 96 ec            clr.l -$6914(a5)
  0015e6:  70 02                  moveq #$2, d0
  0015e8:  60 06                  bra.b $15f0
  0015ea:  42 ad 96 ec            clr.l -$6914(a5)
  0015ee:  70 03                  moveq #$3, d0
  0015f0:  4e 75                  rts 
  0015f2:  48 e7 0f 00            movem.l d4-d7, -(a7)
  0015f6:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  0015fc:  6d 28                  blt.b $1626
  0015fe:  4a 2d b9 49            tst.b -$46b7(a5)
  001602:  6d 14                  blt.b $1618
  001604:  52 6d ba c8            addq.w #$1, -$4538(a5)
  001608:  0c 6d 00 0a ba c8      cmpi.w #$a, -$4538(a5)
  00160e:  6d 16                  blt.b $1626
  001610:  3b 7c 00 09 ba c8      move.w #$9, -$4538(a5)
  001616:  60 0e                  bra.b $1626
  001618:  53 6d ba c6            subq.w #$1, -$453a(a5)
  00161c:  4a 6d ba c6            tst.w -$453a(a5)
  001620:  6c 04                  bge.b $1626
  001622:  42 6d ba c6            clr.w -$453a(a5)
  001626:  3e 2d ba ca            move.w -$4536(a5), d7
  00162a:  3c 2d ba c8            move.w -$4538(a5), d6
  00162e:  3a 2d ba c6            move.w -$453a(a5), d5
  001632:  4a 2d b9 51            tst.b -$46af(a5)
  001636:  66 4c                  bne.b $1684
  001638:  30 2d ba ce            move.w -$4532(a5), d0
  00163c:  b0 6d ba ca            cmp.w -$4536(a5), d0
  001640:  6c 04                  bge.b $1646
  001642:  3e 2d ba ce            move.w -$4532(a5), d7
  001646:  30 2d ba d0            move.w -$4530(a5), d0
  00164a:  b0 6d ba c8            cmp.w -$4538(a5), d0
  00164e:  6f 04                  ble.b $1654
  001650:  3c 2d ba d0            move.w -$4530(a5), d6
  001654:  30 2d ba d2            move.w -$452e(a5), d0
  001658:  b0 6d ba c6            cmp.w -$453a(a5), d0
  00165c:  6c 04                  bge.b $1662
  00165e:  3a 2d ba d2            move.w -$452e(a5), d5
  001662:  0c 2d 00 07 b9 4c      cmpi.b #$7, -$46b4(a5)
  001668:  66 02                  bne.b $166c
  00166a:  52 46                  addq.w #$1, d6
  00166c:  4e ba 21 fa            jsr $3868(pc)
  001670:  0c 2d 00 0f ba e8      cmpi.b #$f, -$4518(a5)
  001676:  67 08                  beq.b $1680
  001678:  0c 2d 00 06 ba e8      cmpi.b #$6, -$4518(a5)
  00167e:  66 04                  bne.b $1684
  001680:  4e ad 03 f2            jsr $3f2(a5)
  001684:  38 07                  move.w d7, d4
  001686:  60 1c                  bra.b $16a4
  001688:  3e 05                  move.w d5, d7
  00168a:  60 12                  bra.b $169e
  00168c:  3f 04                  move.w d4, -(a7)
  00168e:  3f 07                  move.w d7, -(a7)
  001690:  4e ba 1a bc            jsr $314e(pc)
  001694:  3e 80                  move.w d0, (a7)
  001696:  4e ad 04 0a            jsr $40a(a5)
  00169a:  58 8f                  addq.l #$4, a7
  00169c:  52 47                  addq.w #$1, d7
  00169e:  bc 47                  cmp.w d7, d6
  0016a0:  6c ea                  bge.b $168c
  0016a2:  52 44                  addq.w #$1, d4
  0016a4:  b8 6d ba cc            cmp.w -$4534(a5), d4
  0016a8:  6f de                  ble.b $1688
  0016aa:  4a 2d b9 51            tst.b -$46af(a5)
  0016ae:  66 12                  bne.b $16c2
  0016b0:  3b 6d ba ca ba ce      move.w -$4536(a5), -$4532(a5)
  0016b6:  3b 6d ba c8 ba d0      move.w -$4538(a5), -$4530(a5)
  0016bc:  3b 6d ba c6 ba d2      move.w -$453a(a5), -$452e(a5)
  0016c2:  4c df 00 f0            movem.l (a7)+, d4-d7
  0016c6:  4e 75                  rts 
  0016c8:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  0016cc:  1e 2d b9 4c            move.b -$46b4(a5), d7
  0016d0:  48 87                  ext.w d7
  0016d2:  7c 00                  moveq #$0, d6
  0016d4:  1c 2d b9 46            move.b -$46ba(a5), d6
  0016d8:  0c 47 00 02            cmpi.w #$2, d7
  0016dc:  66 12                  bne.b $16f0
  0016de:  0c 46 00 4e            cmpi.w #$4e, d6
  0016e2:  6d 0c                  blt.b $16f0
  0016e4:  0c 46 00 50            cmpi.w #$50, d6
  0016e8:  6c 06                  bge.b $16f0
  0016ea:  49 ed 03 fa            lea.l $3fa(a5), a4
  0016ee:  60 40                  bra.b $1730
  0016f0:  0c 46 00 89            cmpi.w #$89, d6
  0016f4:  6d 0c                  blt.b $1702
  0016f6:  0c 46 00 91            cmpi.w #$91, d6
  0016fa:  6c 06                  bge.b $1702
  0016fc:  49 ed 04 02            lea.l $402(a5), a4
  001700:  60 2e                  bra.b $1730
  001702:  0c 47 00 02            cmpi.w #$2, d7
  001706:  67 24                  beq.b $172c
  001708:  0c 47 00 03            cmpi.w #$3, d7
  00170c:  67 1e                  beq.b $172c
  00170e:  0c 47 00 04            cmpi.w #$4, d7
  001712:  67 18                  beq.b $172c
  001714:  0c 47 00 06            cmpi.w #$6, d7
  001718:  67 12                  beq.b $172c
  00171a:  0c 47 00 05            cmpi.w #$5, d7
  00171e:  66 5a                  bne.b $177a
  001720:  0c 46 00 66            cmpi.w #$66, d6
  001724:  6d 54                  blt.b $177a
  001726:  0c 46 00 6a            cmpi.w #$6a, d6
  00172a:  6e 4e                  bgt.b $177a
  00172c:  49 ed 03 fa            lea.l $3fa(a5), a4
  001730:  3b 6d ba c8 ba ec      move.w -$4538(a5), -$4514(a5)
  001736:  60 38                  bra.b $1770
  001738:  0c 47 00 02            cmpi.w #$2, d7
  00173c:  67 12                  beq.b $1750
  00173e:  3f 2d ba cc            move.w -$4534(a5), -(a7)
  001742:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001746:  4e ba 1a 06            jsr $314e(pc)
  00174a:  3e 80                  move.w d0, (a7)
  00174c:  4e 94                  jsr (a4)
  00174e:  58 8f                  addq.l #$4, a7
  001750:  30 2d ba ca            move.w -$4536(a5), d0
  001754:  b0 6d ba cc            cmp.w -$4534(a5), d0
  001758:  67 12                  beq.b $176c
  00175a:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  00175e:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001762:  4e ba 19 ea            jsr $314e(pc)
  001766:  3e 80                  move.w d0, (a7)
  001768:  4e 94                  jsr (a4)
  00176a:  58 8f                  addq.l #$4, a7
  00176c:  53 6d ba ec            subq.w #$1, -$4514(a5)
  001770:  30 2d ba ec            move.w -$4514(a5), d0
  001774:  b0 6d ba c6            cmp.w -$453a(a5), d0
  001778:  6c be                  bge.b $1738
  00177a:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  00177e:  4e 75                  rts 
  001780:  4a 6d ba 1c            tst.w -$45e4(a5)
  001784:  67 26                  beq.b $17ac
  001786:  4a 6d ba 1c            tst.w -$45e4(a5)
  00178a:  5e c0                  sgt.b d0
  00178c:  44 00                  neg.b d0
  00178e:  48 80                  ext.w d0
  001790:  12 2d b9 4b            move.b -$46b5(a5), d1
  001794:  48 81                  ext.w d1
  001796:  92 40                  sub.w d0, d1
  001798:  3f 01                  move.w d1, -(a7)
  00179a:  10 2d b9 4f            move.b -$46b1(a5), d0
  00179e:  48 80                  ext.w d0
  0017a0:  3f 00                  move.w d0, -(a7)
  0017a2:  4e ad 04 6a            jsr $46a(a5)
  0017a6:  42 6d ba 1c            clr.w -$45e4(a5)
  0017aa:  58 8f                  addq.l #$4, a7
  0017ac:  4e 75                  rts 
  0017ae:  4a 6d ba 8e            tst.w -$4572(a5)
  0017b2:  6f 20                  ble.b $17d4
  0017b4:  53 6d ba 8e            subq.w #$1, -$4572(a5)
  0017b8:  0c 6d 00 05 ba 8e      cmpi.w #$5, -$4572(a5)
  0017be:  66 0a                  bne.b $17ca
  0017c0:  3f 3c 00 29            move.w #$29, -(a7)
  0017c4:  4e ba ef ee            jsr $7b4(pc)
  0017c8:  54 8f                  addq.l #$2, a7
  0017ca:  4a 6d ba 8e            tst.w -$4572(a5)
  0017ce:  66 04                  bne.b $17d4
  0017d0:  53 6d ba 8e            subq.w #$1, -$4572(a5)
  0017d4:  4a 6d ba 92            tst.w -$456e(a5)
  0017d8:  6f 04                  ble.b $17de
  0017da:  53 6d ba 92            subq.w #$1, -$456e(a5)
  0017de:  4a 6d ba 30            tst.w -$45d0(a5)
  0017e2:  6f 16                  ble.b $17fa
  0017e4:  53 6d ba 30            subq.w #$1, -$45d0(a5)
  0017e8:  4e ad 01 02            jsr $102(a5)
  0017ec:  4a 00                  tst.b d0
  0017ee:  67 0a                  beq.b $17fa
  0017f0:  4a 6d ba 30            tst.w -$45d0(a5)
  0017f4:  66 04                  bne.b $17fa
  0017f6:  52 6d ba 30            addq.w #$1, -$45d0(a5)
  0017fa:  0c 6d 00 08 a9 0c      cmpi.w #$8, -$56f4(a5)
  001800:  66 1e                  bne.b $1820
  001802:  0c 2d 00 10 b9 4f      cmpi.b #$10, -$46b1(a5)
  001808:  66 16                  bne.b $1820
  00180a:  4a 6d ba 3c            tst.w -$45c4(a5)
  00180e:  67 10                  beq.b $1820
  001810:  52 6d ba 3c            addq.w #$1, -$45c4(a5)
  001814:  0c 6d 00 96 ba 3c      cmpi.w #$96, -$45c4(a5)
  00181a:  66 04                  bne.b $1820
  00181c:  4e ba 02 22            jsr $1a40(pc)
  001820:  4e 75                  rts 
  001822:  4e 75                  rts 
  001824:  4e 75                  rts 
  001826:  4e 75                  rts 
  001828:  2f 07                  move.l d7, -(a7)
  00182a:  0c 6d 00 02 ba 24      cmpi.w #$2, -$45dc(a5)
  001830:  6d 54                  blt.b $1886
  001832:  4a 2d b9 52            tst.b -$46ae(a5)
  001836:  66 4e                  bne.b $1886
  001838:  4a 2d b9 64            tst.b -$469c(a5)
  00183c:  67 48                  beq.b $1886
  00183e:  0c 2d 00 02 b9 5e      cmpi.b #$2, -$46a2(a5)
  001844:  6c 40                  bge.b $1886
  001846:  10 2d b9 49            move.b -$46b7(a5), d0
  00184a:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  00184e:  67 36                  beq.b $1886
  001850:  4e ba 31 6c            jsr $49be(pc)
  001854:  3e 00                  move.w d0, d7
  001856:  0c 47 00 0f            cmpi.w #$f, d7
  00185a:  6e 2a                  bgt.b $1886
  00185c:  0c 47 ff f1            cmpi.w #$fff1, d7
  001860:  6d 24                  blt.b $1886
  001862:  10 2d b9 4b            move.b -$46b5(a5), d0
  001866:  48 80                  ext.w d0
  001868:  20 4d                  movea.l a5, a0
  00186a:  d0 c0                  adda.w d0, a0
  00186c:  d0 c0                  adda.w d0, a0
  00186e:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  001874:  42 2d b9 4e            clr.b -$46b2(a5)
  001878:  3f 3c 00 2f            move.w #$2f, -(a7)
  00187c:  4e ad 05 22            jsr $522(a5)
  001880:  4e ba 1a ce            jsr $3350(pc)
  001884:  54 8f                  addq.l #$2, a7
  001886:  2e 1f                  move.l (a7)+, d7
  001888:  4e 75                  rts 
  00188a:  48 e7 03 00            movem.l d6-d7, -(a7)
  00188e:  7e 00                  moveq #$0, d7
  001890:  60 40                  bra.b $18d2
  001892:  20 4d                  movea.l a5, a0
  001894:  d0 c7                  adda.w d7, a0
  001896:  7c 00                  moveq #$0, d6
  001898:  1c 28 f1 76            move.b -$e8a(a0), d6
  00189c:  0c 46 00 1e            cmpi.w #$1e, d6
  0018a0:  6c 2e                  bge.b $18d0
  0018a2:  20 06                  move.l d6, d0
  0018a4:  48 c0                  ext.l d0
  0018a6:  81 fc 00 0a            divs.w #$a, d0
  0018aa:  48 40                  swap d0
  0018ac:  20 4d                  movea.l a5, a0
  0018ae:  d0 c0                  adda.w d0, a0
  0018b0:  70 07                  moveq #$7, d0
  0018b2:  d0 28 b8 7d            add.b -$4783(a0), d0
  0018b6:  5e 00                  addq.b #$7, d0
  0018b8:  20 4d                  movea.l a5, a0
  0018ba:  d0 c7                  adda.w d7, a0
  0018bc:  11 40 f1 a6            move.b d0, -$e5a(a0)
  0018c0:  20 4d                  movea.l a5, a0
  0018c2:  d0 c7                  adda.w d7, a0
  0018c4:  42 28 f1 ee            clr.b -$e12(a0)
  0018c8:  20 4d                  movea.l a5, a0
  0018ca:  d0 c7                  adda.w d7, a0
  0018cc:  42 28 f1 be            clr.b -$e42(a0)
  0018d0:  52 47                  addq.w #$1, d7
  0018d2:  0c 47 00 18            cmpi.w #$18, d7
  0018d6:  6d ba                  blt.b $1892
  0018d8:  4c df 00 c0            movem.l (a7)+, d6-d7
  0018dc:  4e 75                  rts 
  0018de:  48 e7 07 00            movem.l d5-d7, -(a7)
  0018e2:  7e 00                  moveq #$0, d7
  0018e4:  1e 2d b9 6a            move.b -$4696(a5), d7
  0018e8:  0c 2d 00 18 b9 87      cmpi.b #$18, -$4679(a5)
  0018ee:  67 00 01 24            beq.w $1a14
  0018f2:  0c 2d 00 01 b9 87      cmpi.b #$1, -$4679(a5)
  0018f8:  66 08                  bne.b $1902
  0018fa:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  001900:  66 38                  bne.b $193a
  001902:  4a 47                  tst.w d7
  001904:  67 34                  beq.b $193a
  001906:  0c 47 00 db            cmpi.w #$db, d7
  00190a:  6d 06                  blt.b $1912
  00190c:  0c 47 00 e5            cmpi.w #$e5, d7
  001910:  6d 28                  blt.b $193a
  001912:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  001918:  67 20                  beq.b $193a
  00191a:  4a 2d b9 77            tst.b -$4689(a5)
  00191e:  6c 1a                  bge.b $193a
  001920:  4a 2d b9 89            tst.b -$4677(a5)
  001924:  6c 14                  bge.b $193a
  001926:  10 2d b9 73            move.b -$468d(a5), d0
  00192a:  b0 2d b9 85            cmp.b -$467b(a5), d0
  00192e:  66 0a                  bne.b $193a
  001930:  10 2d b9 6f            move.b -$4691(a5), d0
  001934:  b0 2d b9 81            cmp.b -$467f(a5), d0
  001938:  67 08                  beq.b $1942
  00193a:  42 6d ba 24            clr.w -$45dc(a5)
  00193e:  60 00 00 d4            bra.w $1a14
  001942:  3b 7c 00 02 ba 24      move.w #$2, -$45dc(a5)
  001948:  10 2d b9 6e            move.b -$4692(a5), d0
  00194c:  48 80                  ext.w d0
  00194e:  20 4d                  movea.l a5, a0
  001950:  d0 c0                  adda.w d0, a0
  001952:  7e 00                  moveq #$0, d7
  001954:  1e 28 b8 7d            move.b -$4783(a0), d7
  001958:  5e 47                  addq.w #$7, d7
  00195a:  10 2d b9 80            move.b -$4680(a5), d0
  00195e:  48 80                  ext.w d0
  001960:  20 4d                  movea.l a5, a0
  001962:  d0 c0                  adda.w d0, a0
  001964:  7c 00                  moveq #$0, d6
  001966:  1c 28 b8 7d            move.b -$4783(a0), d6
  00196a:  5e 46                  addq.w #$7, d6
  00196c:  bc 47                  cmp.w d7, d6
  00196e:  6c 06                  bge.b $1976
  001970:  3a 07                  move.w d7, d5
  001972:  3e 06                  move.w d6, d7
  001974:  3c 05                  move.w d5, d6
  001976:  3f 07                  move.w d7, -(a7)
  001978:  4e ba 00 a0            jsr $1a1a(pc)
  00197c:  72 00                  moveq #$0, d1
  00197e:  12 00                  move.b d0, d1
  001980:  0c 41 00 12            cmpi.w #$12, d1
  001984:  54 8f                  addq.l #$2, a7
  001986:  66 04                  bne.b $198c
  001988:  06 47 00 0e            addi.w #$e, d7
  00198c:  3f 06                  move.w d6, -(a7)
  00198e:  4e ba 00 8a            jsr $1a1a(pc)
  001992:  72 00                  moveq #$0, d1
  001994:  12 00                  move.b d0, d1
  001996:  59 41                  subq.w #$4, d1
  001998:  54 8f                  addq.l #$2, a7
  00199a:  66 74                  bne.b $1a10
  00199c:  06 46 ff f2            addi.w #$fff2, d6
  0019a0:  60 6e                  bra.b $1a10
  0019a2:  3f 07                  move.w d7, -(a7)
  0019a4:  4e ba 00 74            jsr $1a1a(pc)
  0019a8:  72 00                  moveq #$0, d1
  0019aa:  12 00                  move.b d0, d1
  0019ac:  0c 41 00 14            cmpi.w #$14, d1
  0019b0:  54 8f                  addq.l #$2, a7
  0019b2:  67 10                  beq.b $19c4
  0019b4:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  0019ba:  67 08                  beq.b $19c4
  0019bc:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  0019c2:  66 06                  bne.b $19ca
  0019c4:  42 6d ba 24            clr.w -$45dc(a5)
  0019c8:  60 4a                  bra.b $1a14
  0019ca:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  0019d0:  67 34                  beq.b $1a06
  0019d2:  0c 2d 00 12 ba e8      cmpi.b #$12, -$4518(a5)
  0019d8:  67 2c                  beq.b $1a06
  0019da:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  0019e0:  66 12                  bne.b $19f4
  0019e2:  70 00                  moveq #$0, d0
  0019e4:  10 2d ba e9            move.b -$4517(a5), d0
  0019e8:  d0 ad bd 86            add.l -$427a(a5), d0
  0019ec:  20 40                  movea.l d0, a0
  0019ee:  0c 10 00 70            cmpi.b #$70, (a0)
  0019f2:  65 12                  bcs.b $1a06
  0019f4:  70 00                  moveq #$0, d0
  0019f6:  10 2d ba e8            move.b -$4518(a5), d0
  0019fa:  3f 00                  move.w d0, -(a7)
  0019fc:  4e ba 1d 5c            jsr $375a(pc)
  001a00:  4a 00                  tst.b d0
  001a02:  54 8f                  addq.l #$2, a7
  001a04:  66 06                  bne.b $1a0c
  001a06:  3b 7c 00 01 ba 24      move.w #$1, -$45dc(a5)
  001a0c:  06 47 00 0e            addi.w #$e, d7
  001a10:  bc 47                  cmp.w d7, d6
  001a12:  6c 8e                  bge.b $19a2
  001a14:  4c df 00 e0            movem.l (a7)+, d5-d7
  001a18:  4e 75                  rts 
  001a1a:  4e 56 00 00            link.w a6, #$0
  001a1e:  10 2d b9 6f            move.b -$4691(a5), d0
  001a22:  48 80                  ext.w d0
  001a24:  3f 00                  move.w d0, -(a7)
  001a26:  3f 2e 00 08            move.w $8(a6), -(a7)
  001a2a:  4e ba 1a b8            jsr $34e4(pc)
  001a2e:  3e 80                  move.w d0, (a7)
  001a30:  10 2d b9 73            move.b -$468d(a5), d0
  001a34:  48 80                  ext.w d0
  001a36:  3f 00                  move.w d0, -(a7)
  001a38:  4e ba 16 3e            jsr $3078(pc)
  001a3c:  4e 5e                  unlk a6
  001a3e:  4e 75                  rts 
  001a40:  4e 75                  rts 
  001a42:  4e 75                  rts 
  001a44:  4e 75                  rts 
  001a46:  42 6d ba a2            clr.w -$455e(a5)
  001a4a:  4e ba 00 10            jsr $1a5c(pc)
  001a4e:  4e ba 00 16            jsr $1a66(pc)
  001a52:  4e ba f6 5a            jsr $10ae(pc)
  001a56:  4e ba ed 88            jsr $7e0(pc)
  001a5a:  4e 75                  rts 
  001a5c:  4e ba 00 0e            jsr $1a6c(pc)
  001a60:  4e ba 00 32            jsr $1a94(pc)
  001a64:  4e 75                  rts 
  001a66:  4e ba 00 4c            jsr $1ab4(pc)
  001a6a:  4e 75                  rts 
  001a6c:  4e ba 1b 18            jsr $3586(pc)
  001a70:  4a 2d b9 46            tst.b -$46ba(a5)
  001a74:  67 14                  beq.b $1a8a
  001a76:  4e ba 18 d8            jsr $3350(pc)
  001a7a:  0c 2d 00 de b9 47      cmpi.b #$de, -$46b9(a5)
  001a80:  65 04                  bcs.b $1a86
  001a82:  42 2d b9 46            clr.b -$46ba(a5)
  001a86:  4e ba 1b 12            jsr $359a(pc)
  001a8a:  4e ba ef 98            jsr $a24(pc)
  001a8e:  1b 40 a5 be            move.b d0, -$5a42(a5)
  001a92:  4e 75                  rts 
  001a94:  4e ba 1b 8c            jsr $3622(pc)
  001a98:  4a 2d b9 46            tst.b -$46ba(a5)
  001a9c:  67 14                  beq.b $1ab2
  001a9e:  4e ba 18 b0            jsr $3350(pc)
  001aa2:  0c 2d 00 de b9 47      cmpi.b #$de, -$46b9(a5)
  001aa8:  65 04                  bcs.b $1aae
  001aaa:  42 2d b9 46            clr.b -$46ba(a5)
  001aae:  4e ba 1b 12            jsr $35c2(pc)
  001ab2:  4e 75                  rts 
  001ab4:  42 6d bd a4            clr.w -$425c(a5)
  001ab8:  42 6d bd a2            clr.w -$425e(a5)
  001abc:  42 6d bd a0            clr.w -$4260(a5)
  001ac0:  42 6d bd 9e            clr.w -$4262(a5)
  001ac4:  42 6d bd 9c            clr.w -$4264(a5)
  001ac8:  41 ed 04 9a            lea.l $49a(a5), a0
  001acc:  2b 48 bd 70            move.l a0, -$4290(a5)
  001ad0:  4e ba 1a b4            jsr $3586(pc)
  001ad4:  4a 2d b9 46            tst.b -$46ba(a5)
  001ad8:  67 12                  beq.b $1aec
  001ada:  4e ad 04 f2            jsr $4f2(a5)
  001ade:  1b 7c 00 1e ba f0      move.b #$1e, -$4510(a5)
  001ae4:  42 27                  clr.b -(a7)
  001ae6:  4e ad 04 ea            jsr $4ea(a5)
  001aea:  54 8f                  addq.l #$2, a7
  001aec:  4e ba 1a c0            jsr $35ae(pc)
  001af0:  4a 2d b9 46            tst.b -$46ba(a5)
  001af4:  67 12                  beq.b $1b08
  001af6:  4e ad 04 f2            jsr $4f2(a5)
  001afa:  1b 7c 00 1e ba f0      move.b #$1e, -$4510(a5)
  001b00:  42 27                  clr.b -(a7)
  001b02:  4e ad 04 ea            jsr $4ea(a5)
  001b06:  54 8f                  addq.l #$2, a7
  001b08:  4e ad 04 ca            jsr $4ca(a5)
  001b0c:  48 78 00 a7            pea.l $a7.w
  001b10:  2f 3c 00 02 00 1e      move.l #$2001e, -(a7)
  001b16:  3f 3c 00 07            move.w #$7, -(a7)
  001b1a:  4e ad 04 aa            jsr $4aa(a5)
  001b1e:  4e ba 05 0c            jsr $202c(pc)
  001b22:  4e ba 05 6e            jsr $2092(pc)
  001b26:  4e ad 04 d2            jsr $4d2(a5)
  001b2a:  4f ef 00 0a            lea.l $a(a7), a7
  001b2e:  4e 75                  rts 
  001b30:  4e 56 00 00            link.w a6, #$0
  001b34:  4e ba 1a 78            jsr $35ae(pc)
  001b38:  3f 2e 00 08            move.w $8(a6), -(a7)
  001b3c:  4e ad 05 22            jsr $522(a5)
  001b40:  4e ba 1a 80            jsr $35c2(pc)
  001b44:  4e 5e                  unlk a6
  001b46:  4e 75                  rts 
  001b48:  4e 56 00 00            link.w a6, #$0
  001b4c:  4e ba 1a 38            jsr $3586(pc)
  001b50:  3f 2e 00 08            move.w $8(a6), -(a7)
  001b54:  4e ad 05 22            jsr $522(a5)
  001b58:  4e ba 1a 40            jsr $359a(pc)
  001b5c:  4e 5e                  unlk a6
  001b5e:  4e 75                  rts 
  001b60:  4e ba 00 18            jsr $1b7a(pc)
  001b64:  1b 7c 00 90 b9 47      move.b #$90, -$46b9(a5)
  001b6a:  3f 3c 00 6a            move.w #$6a, -(a7)
  001b6e:  4e ad 05 22            jsr $522(a5)
  001b72:  4e ba 17 dc            jsr $3350(pc)
  001b76:  54 8f                  addq.l #$2, a7
  001b78:  4e 75                  rts 
  001b7a:  1b 7c 00 18 b9 51      move.b #$18, -$46af(a5)
  001b80:  1b 7c 00 d2 b9 47      move.b #$d2, -$46b9(a5)
  001b86:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001b8c:  4a 2d a2 0a            tst.b -$5df6(a5)
  001b90:  66 04                  bne.b $1b96
  001b92:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001b96:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001b9c:  3f 3c 00 69            move.w #$69, -(a7)
  001ba0:  4e ad 05 22            jsr $522(a5)
  001ba4:  4e ba 17 aa            jsr $3350(pc)
  001ba8:  54 8f                  addq.l #$2, a7
  001baa:  4e 75                  rts 
  001bac:  4e ba 00 d6            jsr $1c84(pc)
  001bb0:  1b 7c 00 83 b9 47      move.b #$83, -$46b9(a5)
  001bb6:  1b 7c 00 a9 b9 48      move.b #$a9, -$46b8(a5)
  001bbc:  4a 2d a2 0a            tst.b -$5df6(a5)
  001bc0:  66 04                  bne.b $1bc6
  001bc2:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001bc6:  3f 3c 00 6e            move.w #$6e, -(a7)
  001bca:  4e ad 05 22            jsr $522(a5)
  001bce:  4e ba 17 80            jsr $3350(pc)
  001bd2:  54 8f                  addq.l #$2, a7
  001bd4:  4e 75                  rts 
  001bd6:  4e ba 00 5e            jsr $1c36(pc)
  001bda:  1b 7c 00 90 b9 47      move.b #$90, -$46b9(a5)
  001be0:  1b 7c 00 a9 b9 48      move.b #$a9, -$46b8(a5)
  001be6:  4a 2d a2 0a            tst.b -$5df6(a5)
  001bea:  66 04                  bne.b $1bf0
  001bec:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001bf0:  3f 3c 00 5e            move.w #$5e, -(a7)
  001bf4:  4e ad 05 22            jsr $522(a5)
  001bf8:  4e ba 17 56            jsr $3350(pc)
  001bfc:  54 8f                  addq.l #$2, a7
  001bfe:  4e 75                  rts 
  001c00:  4e ba 00 82            jsr $1c84(pc)
  001c04:  1b 7c 00 92 b9 47      move.b #$92, -$46b9(a5)
  001c0a:  4e 75                  rts 
  001c0c:  4e ba 00 76            jsr $1c84(pc)
  001c10:  1b 7c 00 5d b9 47      move.b #$5d, -$46b9(a5)
  001c16:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001c1c:  4a 2d a2 0a            tst.b -$5df6(a5)
  001c20:  66 04                  bne.b $1c26
  001c22:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001c26:  3f 3c 00 67            move.w #$67, -(a7)
  001c2a:  4e ad 05 22            jsr $522(a5)
  001c2e:  4e ba 17 20            jsr $3350(pc)
  001c32:  54 8f                  addq.l #$2, a7
  001c34:  4e 75                  rts 
  001c36:  4e ba 00 4c            jsr $1c84(pc)
  001c3a:  42 2d b9 49            clr.b -$46b7(a5)
  001c3e:  4e 75                  rts 
  001c40:  4e ba 00 42            jsr $1c84(pc)
  001c44:  1b 7c 00 76 b9 47      move.b #$76, -$46b9(a5)
  001c4a:  1b 7c 00 a4 b9 48      move.b #$a4, -$46b8(a5)
  001c50:  4a 2d a2 0a            tst.b -$5df6(a5)
  001c54:  66 04                  bne.b $1c5a
  001c56:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001c5a:  3f 3c 00 6d            move.w #$6d, -(a7)
  001c5e:  4e ad 05 22            jsr $522(a5)
  001c62:  4e ba 16 ec            jsr $3350(pc)
  001c66:  54 8f                  addq.l #$2, a7
  001c68:  4e 75                  rts 
  001c6a:  4e ba ff 0e            jsr $1b7a(pc)
  001c6e:  55 2d b9 47            subq.b #$2, -$46b9(a5)
  001c72:  1b 7c 00 a4 b9 48      move.b #$a4, -$46b8(a5)
  001c78:  4a 2d a2 0a            tst.b -$5df6(a5)
  001c7c:  66 04                  bne.b $1c82
  001c7e:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001c82:  4e 75                  rts 
  001c84:  1b 7c 00 05 b9 51      move.b #$5, -$46af(a5)
  001c8a:  1b 7c 00 78 b9 47      move.b #$78, -$46b9(a5)
  001c90:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001c96:  4a 2d a2 0a            tst.b -$5df6(a5)
  001c9a:  66 04                  bne.b $1ca0
  001c9c:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001ca0:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001ca6:  3f 3c 00 5e            move.w #$5e, -(a7)
  001caa:  4e ad 05 22            jsr $522(a5)
  001cae:  4e ba 16 a0            jsr $3350(pc)
  001cb2:  54 8f                  addq.l #$2, a7
  001cb4:  4e 75                  rts 
  001cb6:  1b 7c 00 06 b9 51      move.b #$6, -$46af(a5)
  001cbc:  1b 7c 00 c6 b9 47      move.b #$c6, -$46b9(a5)
  001cc2:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001cc8:  4a 2d a2 0a            tst.b -$5df6(a5)
  001ccc:  66 04                  bne.b $1cd2
  001cce:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001cd2:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001cd8:  3f 3c 00 5f            move.w #$5f, -(a7)
  001cdc:  4e ad 05 22            jsr $522(a5)
  001ce0:  4e ba 16 6e            jsr $3350(pc)
  001ce4:  54 8f                  addq.l #$2, a7
  001ce6:  4e 75                  rts 
  001ce8:  42 2d b9 51            clr.b -$46af(a5)
  001cec:  1b 7c 00 c6 b9 47      move.b #$c6, -$46b9(a5)
  001cf2:  1b 7c 00 a4 b9 48      move.b #$a4, -$46b8(a5)
  001cf8:  4a 2d a2 0a            tst.b -$5df6(a5)
  001cfc:  66 04                  bne.b $1d02
  001cfe:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001d02:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001d08:  3f 3c 00 01            move.w #$1, -(a7)
  001d0c:  4e ad 05 22            jsr $522(a5)
  001d10:  4e ba 16 3e            jsr $3350(pc)
  001d14:  54 8f                  addq.l #$2, a7
  001d16:  4e 75                  rts 
  001d18:  4e 75                  rts 
  001d1a:  4e 75                  rts 
  001d1c:  4e 75                  rts 
  001d1e:  30 2d a5 70            move.w -$5a90(a5), d0
  001d22:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  001d26:  4a 40                  tst.w d0
  001d28:  67 0a                  beq.b $1d34
  001d2a:  6b 4e                  bmi.b $1d7a
  001d2c:  55 40                  subq.w #$2, d0
  001d2e:  67 3c                  beq.b $1d6c
  001d30:  6a 48                  bpl.b $1d7a
  001d32:  60 0c                  bra.b $1d40
  001d34:  3f 3c 00 24            move.w #$24, -(a7)
  001d38:  4e ad 00 d2            jsr $d2(a5)
  001d3c:  54 8f                  addq.l #$2, a7
  001d3e:  60 44                  bra.b $1d84
  001d40:  3b 7c 00 01 ba a4      move.w #$1, -$455c(a5)
  001d46:  3f 3c 00 07            move.w #$7, -(a7)
  001d4a:  4e ba 02 a6            jsr $1ff2(pc)
  001d4e:  3b 7c ff ff ba 9c      move.w #$ffff, -$4564(a5)
  001d54:  3e bc 00 24            move.w #$24, (a7)
  001d58:  4e ba ea 5a            jsr $7b4(pc)
  001d5c:  3b 7c 00 06 a5 5c      move.w #$6, -$5aa4(a5)
  001d62:  3b 7c 00 02 a5 72      move.w #$2, -$5a8e(a5)
  001d68:  54 8f                  addq.l #$2, a7
  001d6a:  60 18                  bra.b $1d84
  001d6c:  3b 7c 00 64 a5 72      move.w #$64, -$5a8e(a5)
  001d72:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  001d78:  60 0a                  bra.b $1d84
  001d7a:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  001d80:  42 6d a5 70            clr.w -$5a90(a5)
  001d84:  4e 75                  rts 
  001d86:  4e 75                  rts 
  001d88:  4e 75                  rts 
  001d8a:  30 2d a5 70            move.w -$5a90(a5), d0
  001d8e:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  001d92:  4a 40                  tst.w d0
  001d94:  67 08                  beq.b $1d9e
  001d96:  6b 42                  bmi.b $1dda
  001d98:  55 40                  subq.w #$2, d0
  001d9a:  6a 3e                  bpl.b $1dda
  001d9c:  60 0c                  bra.b $1daa
  001d9e:  3f 3c 00 1b            move.w #$1b, -(a7)
  001da2:  4e ad 00 d2            jsr $d2(a5)
  001da6:  54 8f                  addq.l #$2, a7
  001da8:  60 3a                  bra.b $1de4
  001daa:  3f 3c 00 1b            move.w #$1b, -(a7)
  001dae:  4e ba ea 04            jsr $7b4(pc)
  001db2:  4e ba 02 50            jsr $2004(pc)
  001db6:  3e 80                  move.w d0, (a7)
  001db8:  4e ba 02 38            jsr $1ff2(pc)
  001dbc:  4e ba fe 78            jsr $1c36(pc)
  001dc0:  4e ba 18 00            jsr $35c2(pc)
  001dc4:  3b 7c 00 06 a5 5c      move.w #$6, -$5aa4(a5)
  001dca:  3b 7c 00 4b a5 72      move.w #$4b, -$5a8e(a5)
  001dd0:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  001dd6:  54 8f                  addq.l #$2, a7
  001dd8:  60 0a                  bra.b $1de4
  001dda:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  001de0:  42 6d a5 70            clr.w -$5a90(a5)
  001de4:  4e 75                  rts 
  001de6:  30 2d a5 70            move.w -$5a90(a5), d0
  001dea:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  001dee:  0c 40 00 13            cmpi.w #$13, d0
  001df2:  62 00 01 ca            bhi.w $1fbe
  001df6:  43 fa 01 d2            lea.l $1fca(pc), a1
  001dfa:  d0 40                  add.w d0, d0
  001dfc:  d2 f1 00 00            adda.w (a1, d0.w), a1
  001e00:  4e d1                  jmp (a1)
  001e02:  3f 3c 00 32            move.w #$32, -(a7)
  001e06:  4e ad 00 d2            jsr $d2(a5)
  001e0a:  3e bc 00 33            move.w #$33, (a7)
  001e0e:  4e ad 00 d2            jsr $d2(a5)
  001e12:  3e bc 00 35            move.w #$35, (a7)
  001e16:  4e ad 00 d2            jsr $d2(a5)
  001e1a:  3e bc 00 38            move.w #$38, (a7)
  001e1e:  4e ad 00 d2            jsr $d2(a5)
  001e22:  54 8f                  addq.l #$2, a7
  001e24:  60 00 01 a2            bra.w $1fc8
  001e28:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  001e2e:  4e ba fe 54            jsr $1c84(pc)
  001e32:  4e ba 17 8e            jsr $35c2(pc)
  001e36:  3b 7c 00 01 a5 72      move.w #$1, -$5a8e(a5)
  001e3c:  60 00 01 8a            bra.w $1fc8
  001e40:  3f 3c 00 32            move.w #$32, -(a7)
  001e44:  4e ba e9 6e            jsr $7b4(pc)
  001e48:  4e ba fe 6c            jsr $1cb6(pc)
  001e4c:  4e ba 17 4c            jsr $359a(pc)
  001e50:  3b 7c 00 02 a5 72      move.w #$2, -$5a8e(a5)
  001e56:  54 8f                  addq.l #$2, a7
  001e58:  60 00 01 6e            bra.w $1fc8
  001e5c:  3b 7c 00 05 a5 72      move.w #$5, -$5a8e(a5)
  001e62:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  001e68:  60 00 01 5e            bra.w $1fc8
  001e6c:  3b 7c 00 05 a5 72      move.w #$5, -$5a8e(a5)
  001e72:  60 00 01 54            bra.w $1fc8
  001e76:  3f 3c 00 33            move.w #$33, -(a7)
  001e7a:  4e ba e9 38            jsr $7b4(pc)
  001e7e:  3b 7c 00 01 a5 72      move.w #$1, -$5a8e(a5)
  001e84:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  001e8a:  54 8f                  addq.l #$2, a7
  001e8c:  60 00 01 3a            bra.w $1fc8
  001e90:  3f 3c 00 35            move.w #$35, -(a7)
  001e94:  4e ba e9 1e            jsr $7b4(pc)
  001e98:  3b 7c 00 03 a5 72      move.w #$3, -$5a8e(a5)
  001e9e:  54 8f                  addq.l #$2, a7
  001ea0:  60 00 01 26            bra.w $1fc8
  001ea4:  3f 3c 00 62            move.w #$62, -(a7)
  001ea8:  4e ba fc 86            jsr $1b30(pc)
  001eac:  3b 7c 00 05 a5 72      move.w #$5, -$5a8e(a5)
  001eb2:  54 8f                  addq.l #$2, a7
  001eb4:  60 00 01 12            bra.w $1fc8
  001eb8:  3f 3c 00 60            move.w #$60, -(a7)
  001ebc:  4e ba fc 8a            jsr $1b48(pc)
  001ec0:  3b 7c 00 06 a5 72      move.w #$6, -$5a8e(a5)
  001ec6:  54 8f                  addq.l #$2, a7
  001ec8:  60 00 00 fe            bra.w $1fc8
  001ecc:  3f 3c 00 61            move.w #$61, -(a7)
  001ed0:  4e ba fc 76            jsr $1b48(pc)
  001ed4:  3b 7c 00 04 a5 72      move.w #$4, -$5a8e(a5)
  001eda:  54 8f                  addq.l #$2, a7
  001edc:  60 00 00 ea            bra.w $1fc8
  001ee0:  3b 7c 00 06 a5 72      move.w #$6, -$5a8e(a5)
  001ee6:  60 00 00 e0            bra.w $1fc8
  001eea:  3f 3c 00 60            move.w #$60, -(a7)
  001eee:  4e ba fc 58            jsr $1b48(pc)
  001ef2:  3b 7c 00 1e a5 72      move.w #$1e, -$5a8e(a5)
  001ef8:  54 8f                  addq.l #$2, a7
  001efa:  60 00 00 cc            bra.w $1fc8
  001efe:  3f 3c 00 61            move.w #$61, -(a7)
  001f02:  4e ba fc 44            jsr $1b48(pc)
  001f06:  3b 7c 00 10 a5 72      move.w #$10, -$5a8e(a5)
  001f0c:  2b 7c 00 00 03 43 a5 6c move.l #$343, -$5a94(a5)
  001f14:  54 8f                  addq.l #$2, a7
  001f16:  60 00 00 b0            bra.w $1fc8
  001f1a:  3f 3c 00 66            move.w #$66, -(a7)
  001f1e:  4e ba fc 28            jsr $1b48(pc)
  001f22:  3b 7c 00 01 a5 72      move.w #$1, -$5a8e(a5)
  001f28:  54 8f                  addq.l #$2, a7
  001f2a:  60 00 00 9c            bra.w $1fc8
  001f2e:  3f 3c 00 63            move.w #$63, -(a7)
  001f32:  4e ba fb fc            jsr $1b30(pc)
  001f36:  3b 7c 00 11 a5 72      move.w #$11, -$5a8e(a5)
  001f3c:  2b 7c 00 00 03 b6 a5 6c move.l #$3b6, -$5a94(a5)
  001f44:  54 8f                  addq.l #$2, a7
  001f46:  60 00 00 80            bra.w $1fc8
  001f4a:  3b 7c 00 01 ba 9e      move.w #$1, -$4562(a5)
  001f50:  3b 7c 00 05 ba 1a      move.w #$5, -$45e6(a5)
  001f56:  3b 7c 00 07 ba 18      move.w #$7, -$45e8(a5)
  001f5c:  3b 7c 00 09 a5 72      move.w #$9, -$5a8e(a5)
  001f62:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  001f68:  60 5e                  bra.b $1fc8
  001f6a:  3f 3c 00 64            move.w #$64, -(a7)
  001f6e:  4e ba fb d8            jsr $1b48(pc)
  001f72:  3e bc 00 38            move.w #$38, (a7)
  001f76:  4e ba e8 3c            jsr $7b4(pc)
  001f7a:  42 6d ba 9c            clr.w -$4564(a5)
  001f7e:  3b 7c 00 06 a5 72      move.w #$6, -$5a8e(a5)
  001f84:  54 8f                  addq.l #$2, a7
  001f86:  60 40                  bra.b $1fc8
  001f88:  3b 7c 00 18 a5 72      move.w #$18, -$5a8e(a5)
  001f8e:  60 38                  bra.b $1fc8
  001f90:  3b 7c 00 02 ba 9e      move.w #$2, -$4562(a5)
  001f96:  3b 7c 00 09 a5 72      move.w #$9, -$5a8e(a5)
  001f9c:  2b 7c 00 00 01 5e a5 6c move.l #$15e, -$5a94(a5)
  001fa4:  60 22                  bra.b $1fc8
  001fa6:  3f 3c 00 71            move.w #$71, -(a7)
  001faa:  4e ba fb 84            jsr $1b30(pc)
  001fae:  3b 7c 00 1c a5 72      move.w #$1c, -$5a8e(a5)
  001fb4:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  001fba:  54 8f                  addq.l #$2, a7
  001fbc:  60 0a                  bra.b $1fc8
  001fbe:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  001fc4:  42 6d a5 70            clr.w -$5a90(a5)
  001fc8:  4e 75                  rts 
  001fca:  fe 38                  dc.w $fe38
  001fcc:  fe 5e                  dc.w $fe5e
  001fce:  fe 76                  dc.w $fe76
  001fd0:  fe 92                  dc.w $fe92
  001fd2:  fe a2                  dc.w $fea2
  001fd4:  fe ac                  dc.w $feac
  001fd6:  fe c6                  dc.w $fec6
  001fd8:  fe da                  dc.w $feda
  001fda:  fe ee                  dc.w $feee
  001fdc:  ff 02                  dc.w $ff02
  001fde:  ff 16                  dc.w $ff16
  001fe0:  ff 20                  dc.w $ff20
  001fe2:  ff 34                  dc.w $ff34
  001fe4:  ff 50                  dc.w $ff50
  001fe6:  ff 64                  dc.w $ff64
  001fe8:  ff 80                  dc.w $ff80
  001fea:  ff a0                  dc.w $ffa0
  001fec:  ff be                  dc.w $ffbe
  001fee:  ff c6                  dc.w $ffc6
  001ff0:  ff dc                  dc.w $ffdc
  001ff2:  4e 56 00 00            link.w a6, #$0
  001ff6:  42 6d ba 9c            clr.w -$4564(a5)
  001ffa:  3b 6e 00 08 ba 9e      move.w $8(a6), -$4562(a5)
  002000:  4e 5e                  unlk a6
  002002:  4e 75                  rts 
  002004:  48 e7 01 08            movem.l d7/a4, -(a7)
  002008:  7e 00                  moveq #$0, d7
  00200a:  49 ed a9 10            lea.l -$56f0(a5), a4
  00200e:  60 0c                  bra.b $201c
  002010:  30 2d ba 8c            move.w -$4574(a5), d0
  002014:  b0 54                  cmp.w (a4), d0
  002016:  6d 0a                  blt.b $2022
  002018:  52 47                  addq.w #$1, d7
  00201a:  54 8c                  addq.l #$2, a4
  00201c:  0c 47 00 04            cmpi.w #$4, d7
  002020:  6d ee                  blt.b $2010
  002022:  70 06                  moveq #$6, d0
  002024:  90 47                  sub.w d7, d0
  002026:  4c df 10 80            movem.l (a7)+, d7/a4
  00202a:  4e 75                  rts 
  00202c:  2f 07                  move.l d7, -(a7)
  00202e:  7e 01                  moveq #$1, d7
  002030:  de 6d a9 20            add.w -$56e0(a5), d7
  002034:  0c 47 00 03            cmpi.w #$3, d7
  002038:  6f 02                  ble.b $203c
  00203a:  7e 01                  moveq #$1, d7
  00203c:  3f 3c 00 79            move.w #$79, -(a7)
  002040:  3f 2d a9 1c            move.w -$56e4(a5), -(a7)
  002044:  3f 2d a9 18            move.w -$56e8(a5), -(a7)
  002048:  70 0c                  moveq #$c, d0
  00204a:  d0 47                  add.w d7, d0
  00204c:  3f 00                  move.w d0, -(a7)
  00204e:  3f 3c 00 07            move.w #$7, -(a7)
  002052:  4e ad 04 9a            jsr $49a(a5)
  002056:  3b 47 a9 20            move.w d7, -$56e0(a5)
  00205a:  7e 01                  moveq #$1, d7
  00205c:  de 6d a9 22            add.w -$56de(a5), d7
  002060:  0c 47 00 03            cmpi.w #$3, d7
  002064:  4f ef 00 0a            lea.l $a(a7), a7
  002068:  6f 02                  ble.b $206c
  00206a:  7e 01                  moveq #$1, d7
  00206c:  3f 3c 00 79            move.w #$79, -(a7)
  002070:  3f 2d a9 1e            move.w -$56e2(a5), -(a7)
  002074:  3f 2d a9 1a            move.w -$56e6(a5), -(a7)
  002078:  70 0c                  moveq #$c, d0
  00207a:  d0 47                  add.w d7, d0
  00207c:  3f 00                  move.w d0, -(a7)
  00207e:  3f 3c 00 07            move.w #$7, -(a7)
  002082:  4e ad 04 9a            jsr $49a(a5)
  002086:  3b 47 a9 22            move.w d7, -$56de(a5)
  00208a:  4f ef 00 0a            lea.l $a(a7), a7
  00208e:  2e 1f                  move.l (a7)+, d7
  002090:  4e 75                  rts 
  002092:  2f 07                  move.l d7, -(a7)
  002094:  4a 6d ba 9c            tst.w -$4564(a5)
  002098:  6d 42                  blt.b $20dc
  00209a:  30 2d ba 9c            move.w -$4564(a5), d0
  00209e:  52 40                  addq.w #$1, d0
  0020a0:  48 c0                  ext.l d0
  0020a2:  81 fc 00 03            divs.w #$3, d0
  0020a6:  48 40                  swap d0
  0020a8:  3b 40 ba 9c            move.w d0, -$4564(a5)
  0020ac:  0c 6d 00 07 ba 9e      cmpi.w #$7, -$4562(a5)
  0020b2:  6c 5a                  bge.b $210e
  0020b4:  3e 3c 00 a4            move.w #$a4, d7
  0020b8:  4a 2d a2 0a            tst.b -$5df6(a5)
  0020bc:  66 02                  bne.b $20c0
  0020be:  57 47                  subq.w #$3, d7
  0020c0:  3f 07                  move.w d7, -(a7)
  0020c2:  2f 3c 00 14 00 00      move.l #$140000, -(a7)
  0020c8:  70 0a                  moveq #$a, d0
  0020ca:  d0 6d ba 9c            add.w -$4564(a5), d0
  0020ce:  3f 00                  move.w d0, -(a7)
  0020d0:  3f 3c 00 07            move.w #$7, -(a7)
  0020d4:  4e ad 04 aa            jsr $4aa(a5)
  0020d8:  4f ef 00 0a            lea.l $a(a7), a7
  0020dc:  4a 6d ba 9e            tst.w -$4562(a5)
  0020e0:  67 2c                  beq.b $210e
  0020e2:  3e 3c 00 a8            move.w #$a8, d7
  0020e6:  4a 2d a2 0a            tst.b -$5df6(a5)
  0020ea:  66 02                  bne.b $20ee
  0020ec:  57 47                  subq.w #$3, d7
  0020ee:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  0020f2:  3f 07                  move.w d7, -(a7)
  0020f4:  2f 3c 00 13 00 00      move.l #$130000, -(a7)
  0020fa:  70 02                  moveq #$2, d0
  0020fc:  d0 6d ba 9e            add.w -$4562(a5), d0
  002100:  3f 00                  move.w d0, -(a7)
  002102:  3f 3c 00 07            move.w #$7, -(a7)
  002106:  4e ad 04 a2            jsr $4a2(a5)
  00210a:  4f ef 00 0a            lea.l $a(a7), a7
  00210e:  2e 1f                  move.l (a7)+, d7
  002110:  4e 75                  rts 
  002112:  4e 75                  rts 
  002114:  30 2d a5 66            move.w -$5a9a(a5), d0
  002118:  52 6d a5 66            addq.w #$1, -$5a9a(a5)
  00211c:  4a 40                  tst.w d0
  00211e:  67 08                  beq.b $2128
  002120:  6b 2e                  bmi.b $2150
  002122:  55 40                  subq.w #$2, d0
  002124:  6a 2a                  bpl.b $2150
  002126:  60 10                  bra.b $2138
  002128:  48 6d 01 fa            pea.l $1fa(a5)
  00212c:  3f 3c 00 01            move.w #$1, -(a7)
  002130:  4e ba 00 2a            jsr $215c(pc)
  002134:  5c 8f                  addq.l #$6, a7
  002136:  60 1c                  bra.b $2154
  002138:  1f 3c 00 02            move.b #$2, -(a7)
  00213c:  48 6d a5 c4            pea.l -$5a3c(a5)
  002140:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  002144:  4e 90                  jsr (a0)
  002146:  3b 7c 00 1e a5 68      move.w #$1e, -$5a98(a5)
  00214c:  5c 8f                  addq.l #$6, a7
  00214e:  60 04                  bra.b $2154
  002150:  42 6d a5 66            clr.w -$5a9a(a5)
  002154:  48 6d a5 c4            pea.l -$5a3c(a5)
  002158:  a9 28                  dc.w $a928
  00215a:  4e 75                  rts 
  00215c:  4e 56 00 00            link.w a6, #$0
  002160:  4e ba ef 00            jsr $1062(pc)
  002164:  2f 3c 00 06 03 b6      move.l #$603b6, -(a7)
  00216a:  4e ba e6 fa            jsr $866(pc)
  00216e:  3b 7c 00 01 f2 28      move.w #$1, -$dd8(a5)
  002174:  2b 6d a5 c4 a2 e4      move.l -$5a3c(a5), -$5d1c(a5)
  00217a:  2b 6d a5 c8 a2 e8      move.l -$5a38(a5), -$5d18(a5)
  002180:  1e bc 00 02            move.b #$2, (a7)
  002184:  48 6d a5 c4            pea.l -$5a3c(a5)
  002188:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  00218c:  4e 90                  jsr (a0)
  00218e:  70 01                  moveq #$1, d0
  002190:  2e 80                  move.l d0, (a7)
  002192:  42 a7                  clr.l -(a7)
  002194:  3f 3c 00 06            move.w #$6, -(a7)
  002198:  4e ad 04 b2            jsr $4b2(a5)
  00219c:  3e bc 00 06            move.w #$6, (a7)
  0021a0:  4e ba e8 42            jsr $9e4(pc)
  0021a4:  2e bc 00 03 03 20      move.l #$30320, (a7)
  0021aa:  4e ba e6 ba            jsr $866(pc)
  0021ae:  30 2e 00 08            move.w $8(a6), d0
  0021b2:  4f ef 00 0e            lea.l $e(a7), a7
  0021b6:  67 02                  beq.b $21ba
  0021b8:  60 0c                  bra.b $21c6
  0021ba:  2f 3c 00 04 03 52      move.l #$40352, -(a7)
  0021c0:  4e ba e6 a4            jsr $866(pc)
  0021c4:  58 8f                  addq.l #$4, a7
  0021c6:  2f 3c 00 07 03 c0      move.l #$703c0, -(a7)
  0021cc:  4e ba e6 98            jsr $866(pc)
  0021d0:  42 6d a5 70            clr.w -$5a90(a5)
  0021d4:  42 6d a5 72            clr.w -$5a8e(a5)
  0021d8:  42 2d a5 6a            clr.b -$5a96(a5)
  0021dc:  2b 6e 00 0a a5 74      move.l $a(a6), -$5a8c(a5)
  0021e2:  20 6d a5 74            movea.l -$5a8c(a5), a0
  0021e6:  4e 90                  jsr (a0)
  0021e8:  1b 7c 00 01 96 e5      move.b #$1, -$691b(a5)
  0021ee:  4e ad 00 e2            jsr $e2(a5)
  0021f2:  42 2d b9 7c            clr.b -$4684(a5)
  0021f6:  42 2d b9 6a            clr.b -$4696(a5)
  0021fa:  70 00                  moveq #$0, d0
  0021fc:  10 3c 00 00            move.b #$0, d0
  002200:  3b 40 ba a4            move.w d0, -$455c(a5)
  002204:  3b 40 ba 9e            move.w d0, -$4562(a5)
  002208:  3b 7c ff ff ba 9c      move.w #$ffff, -$4564(a5)
  00220e:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  002214:  4e ad 04 3a            jsr $43a(a5)
  002218:  20 6d a5 74            movea.l -$5a8c(a5), a0
  00221c:  4e 90                  jsr (a0)
  00221e:  4e ba f8 94            jsr $1ab4(pc)
  002222:  42 2d a5 be            clr.b -$5a42(a5)
  002226:  3b 6d 96 e8 a5 78      move.w -$6918(a5), -$5a88(a5)
  00222c:  3b 7c 00 03 96 e8      move.w #$3, -$6918(a5)
  002232:  48 6d a5 c4            pea.l -$5a3c(a5)
  002236:  a9 28                  dc.w $a928
  002238:  4e 5e                  unlk a6
  00223a:  4e 75                  rts 
  00223c:  70 00                  moveq #$0, d0
  00223e:  4e 75                  rts 
  002240:  4e 75                  rts 
  002242:  4e 75                  rts 
  002244:  4e 56 00 00            link.w a6, #$0
  002248:  48 e7 01 08            movem.l d7/a4, -(a7)
  00224c:  3e 2e 00 0c            move.w $c(a6), d7
  002250:  28 6e 00 08            movea.l $8(a6), a4
  002254:  4c df 10 80            movem.l (a7)+, d7/a4
  002258:  4e 5e                  unlk a6
  00225a:  4e 75                  rts 
  00225c:  48 e7 07 00            movem.l d5-d7, -(a7)
  002260:  42 6d ba 36            clr.w -$45ca(a5)
  002264:  7c ff                  moveq #$ff, d6
  002266:  dc 6d ba 6a            add.w -$4596(a5), d6
  00226a:  20 4d                  movea.l a5, a0
  00226c:  d0 c6                  adda.w d6, a0
  00226e:  7a 00                  moveq #$0, d5
  002270:  1a 28 f1 76            move.b -$e8a(a0), d5
  002274:  0c 45 00 1e            cmpi.w #$1e, d5
  002278:  6c 00 01 6e            bge.w $23e8
  00227c:  1b 6d ba 6b b9 4f      move.b -$4595(a5), -$46b1(a5)
  002282:  20 05                  move.l d5, d0
  002284:  48 c0                  ext.l d0
  002286:  81 fc 00 0a            divs.w #$a, d0
  00228a:  1b 40 b9 4b            move.b d0, -$46b5(a5)
  00228e:  10 2d b9 4b            move.b -$46b5(a5), d0
  002292:  48 80                  ext.w d0
  002294:  20 4d                  movea.l a5, a0
  002296:  d0 c0                  adda.w d0, a0
  002298:  d0 c0                  adda.w d0, a0
  00229a:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  0022a0:  20 4d                  movea.l a5, a0
  0022a2:  d0 c6                  adda.w d6, a0
  0022a4:  1b 68 f1 a6 b9 47      move.b -$e5a(a0), -$46b9(a5)
  0022aa:  70 00                  moveq #$0, d0
  0022ac:  10 2d b9 47            move.b -$46b9(a5), d0
  0022b0:  3f 00                  move.w d0, -(a7)
  0022b2:  4e ba 12 30            jsr $34e4(pc)
  0022b6:  1b 40 b9 4a            move.b d0, -$46b6(a5)
  0022ba:  20 4d                  movea.l a5, a0
  0022bc:  d0 c6                  adda.w d6, a0
  0022be:  1b 68 f1 8e b9 49      move.b -$e72(a0), -$46b7(a5)
  0022c4:  30 2d a9 0c            move.w -$56f4(a5), d0
  0022c8:  20 4d                  movea.l a5, a0
  0022ca:  d0 c0                  adda.w d0, a0
  0022cc:  d0 c0                  adda.w d0, a0
  0022ce:  4a 68 a8 dc            tst.w -$5724(a0)
  0022d2:  54 8f                  addq.l #$2, a7
  0022d4:  66 14                  bne.b $22ea
  0022d6:  20 4d                  movea.l a5, a0
  0022d8:  d0 c6                  adda.w d6, a0
  0022da:  70 00                  moveq #$0, d0
  0022dc:  10 28 f2 06            move.b -$dfa(a0), d0
  0022e0:  3b 40 ba a6            move.w d0, -$455a(a5)
  0022e4:  3b 7c 00 01 ba a8      move.w #$1, -$4558(a5)
  0022ea:  0c 6d 00 03 a9 0c      cmpi.w #$3, -$56f4(a5)
  0022f0:  66 08                  bne.b $22fa
  0022f2:  1b 7c 00 04 b9 51      move.b #$4, -$46af(a5)
  0022f8:  60 06                  bra.b $2300
  0022fa:  1b 7c 00 02 b9 51      move.b #$2, -$46af(a5)
  002300:  20 4d                  movea.l a5, a0
  002302:  d0 c6                  adda.w d6, a0
  002304:  4a 28 f1 ee            tst.b -$e12(a0)
  002308:  66 2a                  bne.b $2334
  00230a:  0c 2d 00 04 b9 51      cmpi.b #$4, -$46af(a5)
  002310:  66 12                  bne.b $2324
  002312:  1b 7c 00 02 b9 52      move.b #$2, -$46ae(a5)
  002318:  3f 3c 00 3f            move.w #$3f, -(a7)
  00231c:  4e ad 05 22            jsr $522(a5)
  002320:  54 8f                  addq.l #$2, a7
  002322:  60 26                  bra.b $234a
  002324:  42 2d b9 52            clr.b -$46ae(a5)
  002328:  3f 3c 00 4d            move.w #$4d, -(a7)
  00232c:  4e ad 05 22            jsr $522(a5)
  002330:  54 8f                  addq.l #$2, a7
  002332:  60 16                  bra.b $234a
  002334:  20 4d                  movea.l a5, a0
  002336:  d0 c6                  adda.w d6, a0
  002338:  70 00                  moveq #$0, d0
  00233a:  10 28 f1 be            move.b -$e42(a0), d0
  00233e:  20 4d                  movea.l a5, a0
  002340:  e5 88                  lsl.l #$2, d0
  002342:  d1 c0                  adda.l d0, a0
  002344:  2b 68 fc e4 b9 54      move.l -$31c(a0), -$46ac(a5)
  00234a:  4e ba 10 04            jsr $3350(pc)
  00234e:  20 4d                  movea.l a5, a0
  002350:  d0 c6                  adda.w d6, a0
  002352:  70 00                  moveq #$0, d0
  002354:  10 28 f1 d6            move.b -$e2a(a0), d0
  002358:  3b 40 ba 20            move.w d0, -$45e0(a5)
  00235c:  0c 40 00 0c            cmpi.w #$c, d0
  002360:  6d 06                  blt.b $2368
  002362:  3b 7c 00 03 ba 20      move.w #$3, -$45e0(a5)
  002368:  30 2d a9 0c            move.w -$56f4(a5), d0
  00236c:  20 4d                  movea.l a5, a0
  00236e:  d0 c0                  adda.w d0, a0
  002370:  72 00                  moveq #$0, d1
  002372:  12 28 a9 78            move.b -$5688(a0), d1
  002376:  34 2d ba 20            move.w -$45e0(a5), d2
  00237a:  20 4d                  movea.l a5, a0
  00237c:  d0 c2                  adda.w d2, a0
  00237e:  70 00                  moveq #$0, d0
  002380:  10 28 a9 6c            move.b -$5694(a0), d0
  002384:  d2 40                  add.w d0, d1
  002386:  3b 41 ba 4e            move.w d1, -$45b2(a5)
  00238a:  7c 00                  moveq #$0, d6
  00238c:  1c 2d b9 46            move.b -$46ba(a5), d6
  002390:  0c 46 00 b9            cmpi.w #$b9, d6
  002394:  67 0c                  beq.b $23a2
  002396:  0c 46 00 b1            cmpi.w #$b1, d6
  00239a:  67 06                  beq.b $23a2
  00239c:  0c 46 00 b2            cmpi.w #$b2, d6
  0023a0:  66 10                  bne.b $23b2
  0023a2:  1b 7c 00 01 b9 53      move.b #$1, -$46ad(a5)
  0023a8:  42 6d ba 4c            clr.w -$45b4(a5)
  0023ac:  42 6d ba 52            clr.w -$45ae(a5)
  0023b0:  60 1e                  bra.b $23d0
  0023b2:  1b 7c 00 ff b9 53      move.b #$ff, -$46ad(a5)
  0023b8:  30 2d ba 4e            move.w -$45b2(a5), d0
  0023bc:  3b 40 ba 4c            move.w d0, -$45b4(a5)
  0023c0:  3b 40 ba 52            move.w d0, -$45ae(a5)
  0023c4:  42 6d ba 2a            clr.w -$45d6(a5)
  0023c8:  42 6d ba 8a            clr.w -$4576(a5)
  0023cc:  42 6d ba 56            clr.w -$45aa(a5)
  0023d0:  42 2d b9 4e            clr.b -$46b2(a5)
  0023d4:  42 2d b9 4d            clr.b -$46b3(a5)
  0023d8:  1b 7c 00 01 b9 4c      move.b #$1, -$46b4(a5)
  0023de:  4e ba 11 e2            jsr $35c2(pc)
  0023e2:  3b 7c 00 01 ba 2c      move.w #$1, -$45d4(a5)
  0023e8:  4c df 00 e0            movem.l (a7)+, d5-d7
  0023ec:  4e 75                  rts 
  0023ee:  2f 07                  move.l d7, -(a7)
  0023f0:  7e 00                  moveq #$0, d7
  0023f2:  1e 2d b9 7e            move.b -$4682(a5), d7
  0023f6:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  0023fc:  67 2e                  beq.b $242c
  0023fe:  0c 47 00 d3            cmpi.w #$d3, d7
  002402:  6d 28                  blt.b $242c
  002404:  4e ba 23 48            jsr $474e(pc)
  002408:  30 2d ba 6a            move.w -$4596(a5), d0
  00240c:  20 4d                  movea.l a5, a0
  00240e:  d0 c0                  adda.w d0, a0
  002410:  11 7c 00 1e f1 75      move.b #$1e, -$e8b(a0)
  002416:  1b 7c 00 56 b9 7f      move.b #$56, -$4681(a5)
  00241c:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  002420:  42 67                  clr.w -(a7)
  002422:  4e ba e1 f4            jsr $618(pc)
  002426:  42 6d ba 4c            clr.w -$45b4(a5)
  00242a:  58 8f                  addq.l #$4, a7
  00242c:  2e 1f                  move.l (a7)+, d7
  00242e:  4e 75                  rts 
  002430:  48 e7 03 00            movem.l d6-d7, -(a7)
  002434:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  00243a:  67 00 00 ca            beq.w $2506
  00243e:  0c 2d 00 01 b9 87      cmpi.b #$1, -$4679(a5)
  002444:  67 00 00 c0            beq.w $2506
  002448:  0c 2d 00 18 b9 87      cmpi.b #$18, -$4679(a5)
  00244e:  67 00 00 b6            beq.w $2506
  002452:  1e 2d b9 85            move.b -$467b(a5), d7
  002456:  48 87                  ext.w d7
  002458:  53 47                  subq.w #$1, d7
  00245a:  10 2d b9 81            move.b -$467f(a5), d0
  00245e:  48 80                  ext.w d0
  002460:  3f 00                  move.w d0, -(a7)
  002462:  42 67                  clr.w -(a7)
  002464:  4e ba 0c e8            jsr $314e(pc)
  002468:  20 4d                  movea.l a5, a0
  00246a:  d0 c7                  adda.w d7, a0
  00246c:  11 40 f1 76            move.b d0, -$e8a(a0)
  002470:  20 4d                  movea.l a5, a0
  002472:  d0 c7                  adda.w d7, a0
  002474:  11 6d ba a7 f2 06      move.b -$4559(a5), -$dfa(a0)
  00247a:  20 4d                  movea.l a5, a0
  00247c:  d0 c7                  adda.w d7, a0
  00247e:  11 6d b9 7d f1 a6      move.b -$4683(a5), -$e5a(a0)
  002484:  20 4d                  movea.l a5, a0
  002486:  d0 c7                  adda.w d7, a0
  002488:  11 6d b9 7f f1 8e      move.b -$4681(a5), -$e72(a0)
  00248e:  20 4d                  movea.l a5, a0
  002490:  d0 c7                  adda.w d7, a0
  002492:  11 6d ba 21 f1 d6      move.b -$45df(a5), -$e2a(a0)
  002498:  7c 00                  moveq #$0, d6
  00249a:  1c 2d b9 7c            move.b -$4684(a5), d6
  00249e:  4a 2d b9 89            tst.b -$4677(a5)
  0024a2:  58 8f                  addq.l #$4, a7
  0024a4:  6c 12                  bge.b $24b8
  0024a6:  20 4d                  movea.l a5, a0
  0024a8:  d0 c7                  adda.w d7, a0
  0024aa:  42 28 f1 ee            clr.b -$e12(a0)
  0024ae:  20 4d                  movea.l a5, a0
  0024b0:  d0 c7                  adda.w d7, a0
  0024b2:  42 28 f1 be            clr.b -$e42(a0)
  0024b6:  60 38                  bra.b $24f0
  0024b8:  20 4d                  movea.l a5, a0
  0024ba:  d0 c7                  adda.w d7, a0
  0024bc:  11 7c 00 01 f1 ee      move.b #$1, -$e12(a0)
  0024c2:  0c 46 00 b1            cmpi.w #$b1, d6
  0024c6:  66 0c                  bne.b $24d4
  0024c8:  20 4d                  movea.l a5, a0
  0024ca:  d0 c7                  adda.w d7, a0
  0024cc:  11 7c 00 84 f1 be      move.b #$84, -$e42(a0)
  0024d2:  60 1c                  bra.b $24f0
  0024d4:  0c 46 00 b2            cmpi.w #$b2, d6
  0024d8:  66 0c                  bne.b $24e6
  0024da:  20 4d                  movea.l a5, a0
  0024dc:  d0 c7                  adda.w d7, a0
  0024de:  11 7c 00 86 f1 be      move.b #$86, -$e42(a0)
  0024e4:  60 0a                  bra.b $24f0
  0024e6:  20 4d                  movea.l a5, a0
  0024e8:  d0 c7                  adda.w d7, a0
  0024ea:  11 7c 00 82 f1 be      move.b #$82, -$e42(a0)
  0024f0:  1b 7c 00 56 b9 7f      move.b #$56, -$4681(a5)
  0024f6:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  0024fa:  42 67                  clr.w -(a7)
  0024fc:  4e ba e1 1a            jsr $618(pc)
  002500:  42 6d ba 4c            clr.w -$45b4(a5)
  002504:  58 8f                  addq.l #$4, a7
  002506:  4c df 00 c0            movem.l (a7)+, d6-d7
  00250a:  4e 75                  rts 
  00250c:  10 2d b9 73            move.b -$468d(a5), d0
  002510:  48 80                  ext.w d0
  002512:  20 4d                  movea.l a5, a0
  002514:  d0 c0                  adda.w d0, a0
  002516:  11 7c 00 1e f1 75      move.b #$1e, -$e8b(a0)
  00251c:  10 2d b9 85            move.b -$467b(a5), d0
  002520:  48 80                  ext.w d0
  002522:  20 4d                  movea.l a5, a0
  002524:  d0 c0                  adda.w d0, a0
  002526:  11 7c 00 1e f1 75      move.b #$1e, -$e8b(a0)
  00252c:  4e ba 10 80            jsr $35ae(pc)
  002530:  3f 2d ba 44            move.w -$45bc(a5), -(a7)
  002534:  4e ba 00 f4            jsr $262a(pc)
  002538:  4e ba 10 88            jsr $35c2(pc)
  00253c:  54 8f                  addq.l #$2, a7
  00253e:  4e 75                  rts 
  002540:  48 e7 03 00            movem.l d6-d7, -(a7)
  002544:  4a 6d ba 84            tst.w -$457c(a5)
  002548:  67 08                  beq.b $2552
  00254a:  53 6d ba 84            subq.w #$1, -$457c(a5)
  00254e:  60 00 00 d4            bra.w $2624
  002552:  4e ba 10 32            jsr $3586(pc)
  002556:  4e ad 04 f2            jsr $4f2(a5)
  00255a:  4e ba 13 2c            jsr $3888(pc)
  00255e:  4e ba 01 64            jsr $26c4(pc)
  002562:  3b 40 ba 44            move.w d0, -$45bc(a5)
  002566:  4a 40                  tst.w d0
  002568:  6d 00 00 ba            blt.w $2624
  00256c:  4e ba 10 2c            jsr $359a(pc)
  002570:  0c 6d 00 63 ba 44      cmpi.w #$63, -$45bc(a5)
  002576:  66 0a                  bne.b $2582
  002578:  3b 7c ff ff ba 44      move.w #$ffff, -$45bc(a5)
  00257e:  60 00 00 a4            bra.w $2624
  002582:  10 2d b9 4f            move.b -$46b1(a5), d0
  002586:  48 80                  ext.w d0
  002588:  3b 40 ba 7c            move.w d0, -$4584(a5)
  00258c:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  002592:  67 00 00 90            beq.w $2624
  002596:  7e 00                  moveq #$0, d7
  002598:  4a 2d b9 89            tst.b -$4677(a5)
  00259c:  6c 08                  bge.b $25a6
  00259e:  0c 2d 00 02 b9 88      cmpi.b #$2, -$4678(a5)
  0025a4:  67 04                  beq.b $25aa
  0025a6:  7e 01                  moveq #$1, d7
  0025a8:  60 6c                  bra.b $2616
  0025aa:  1c 2d b9 73            move.b -$468d(a5), d6
  0025ae:  48 86                  ext.w d6
  0025b0:  53 46                  subq.w #$1, d6
  0025b2:  20 4d                  movea.l a5, a0
  0025b4:  d0 c6                  adda.w d6, a0
  0025b6:  0c 28 00 1e f1 76      cmpi.b #$1e, -$e8a(a0)
  0025bc:  64 0e                  bcc.b $25cc
  0025be:  20 4d                  movea.l a5, a0
  0025c0:  d0 c6                  adda.w d6, a0
  0025c2:  4a 28 f1 ee            tst.b -$e12(a0)
  0025c6:  66 04                  bne.b $25cc
  0025c8:  7e 01                  moveq #$1, d7
  0025ca:  60 4a                  bra.b $2616
  0025cc:  4a 6d ba 44            tst.w -$45bc(a5)
  0025d0:  66 0c                  bne.b $25de
  0025d2:  0c 2d 00 5b b9 7d      cmpi.b #$5b, -$4683(a5)
  0025d8:  65 3c                  bcs.b $2616
  0025da:  7e 01                  moveq #$1, d7
  0025dc:  60 38                  bra.b $2616
  0025de:  0c 6d 00 01 ba 44      cmpi.w #$1, -$45bc(a5)
  0025e4:  66 0c                  bne.b $25f2
  0025e6:  0c 2d 00 a5 b9 7d      cmpi.b #$a5, -$4683(a5)
  0025ec:  64 28                  bcc.b $2616
  0025ee:  7e 01                  moveq #$1, d7
  0025f0:  60 24                  bra.b $2616
  0025f2:  0c 6d 00 02 ba 44      cmpi.w #$2, -$45bc(a5)
  0025f8:  66 0a                  bne.b $2604
  0025fa:  4a 2d b9 81            tst.b -$467f(a5)
  0025fe:  6d 16                  blt.b $2616
  002600:  7e 01                  moveq #$1, d7
  002602:  60 12                  bra.b $2616
  002604:  0c 6d 00 03 ba 44      cmpi.w #$3, -$45bc(a5)
  00260a:  66 0a                  bne.b $2616
  00260c:  0c 2d 00 03 b9 81      cmpi.b #$3, -$467f(a5)
  002612:  6c 02                  bge.b $2616
  002614:  7e 01                  moveq #$1, d7
  002616:  4a 47                  tst.w d7
  002618:  67 06                  beq.b $2620
  00261a:  4e ba fe 14            jsr $2430(pc)
  00261e:  60 04                  bra.b $2624
  002620:  4e ba fe ea            jsr $250c(pc)
  002624:  4c df 00 c0            movem.l (a7)+, d6-d7
  002628:  4e 75                  rts 
  00262a:  4e 56 00 00            link.w a6, #$0
  00262e:  48 e7 03 00            movem.l d6-d7, -(a7)
  002632:  3c 2e 00 08            move.w $8(a6), d6
  002636:  4a 2d b9 4f            tst.b -$46b1(a5)
  00263a:  66 04                  bne.b $2640
  00263c:  70 ff                  moveq #$ff, d0
  00263e:  60 7a                  bra.b $26ba
  002640:  10 2d b9 4f            move.b -$46b1(a5), d0
  002644:  48 80                  ext.w d0
  002646:  48 c0                  ext.l d0
  002648:  e5 88                  lsl.l #$2, d0
  00264a:  41 ed f0 ba            lea.l -$f46(a5), a0
  00264e:  d0 88                  add.l a0, d0
  002650:  30 46                  movea.w d6, a0
  002652:  1b 70 08 00 b9 4f      move.b (a0, d0.l), -$46b1(a5)
  002658:  4a 2d b9 4f            tst.b -$46b1(a5)
  00265c:  66 04                  bne.b $2662
  00265e:  70 ff                  moveq #$ff, d0
  002660:  60 58                  bra.b $26ba
  002662:  4a 46                  tst.w d6
  002664:  66 0a                  bne.b $2670
  002666:  06 2d 00 8c b9 47      addi.b #$8c, -$46b9(a5)
  00266c:  7c 01                  moveq #$1, d6
  00266e:  60 28                  bra.b $2698
  002670:  0c 46 00 01            cmpi.w #$1, d6
  002674:  66 0a                  bne.b $2680
  002676:  04 2d 00 8c b9 47      subi.b #$8c, -$46b9(a5)
  00267c:  7c 00                  moveq #$0, d6
  00267e:  60 18                  bra.b $2698
  002680:  0c 46 00 02            cmpi.w #$2, d6
  002684:  66 0a                  bne.b $2690
  002686:  06 2d 00 bd b9 48      addi.b #$bd, -$46b8(a5)
  00268c:  7c 03                  moveq #$3, d6
  00268e:  60 08                  bra.b $2698
  002690:  04 2d 00 bd b9 48      subi.b #$bd, -$46b8(a5)
  002696:  7c 02                  moveq #$2, d6
  002698:  70 00                  moveq #$0, d0
  00269a:  10 2d b9 47            move.b -$46b9(a5), d0
  00269e:  3f 00                  move.w d0, -(a7)
  0026a0:  4e ba 0e 42            jsr $34e4(pc)
  0026a4:  1b 40 b9 4a            move.b d0, -$46b6(a5)
  0026a8:  70 00                  moveq #$0, d0
  0026aa:  10 2d b9 48            move.b -$46b8(a5), d0
  0026ae:  3e 80                  move.w d0, (a7)
  0026b0:  4e ba 0e b6            jsr $3568(pc)
  0026b4:  1b 40 b9 4b            move.b d0, -$46b5(a5)
  0026b8:  30 06                  move.w d6, d0
  0026ba:  4c ee 00 c0 ff f8      movem.l -$8(a6), d6-d7
  0026c0:  4e 5e                  unlk a6
  0026c2:  4e 75                  rts 
  0026c4:  48 e7 1f 00            movem.l d3-d7, -(a7)
  0026c8:  7c 00                  moveq #$0, d6
  0026ca:  1c 2d b9 48            move.b -$46b8(a5), d6
  0026ce:  3e 06                  move.w d6, d7
  0026d0:  0c 47 00 c0            cmpi.w #$c0, d7
  0026d4:  6d 04                  blt.b $26da
  0026d6:  06 47 ff 00            addi.w #$ff00, d7
  0026da:  1a 2d b9 4c            move.b -$46b4(a5), d5
  0026de:  48 85                  ext.w d5
  0026e0:  78 00                  moveq #$0, d4
  0026e2:  18 2d b9 46            move.b -$46ba(a5), d4
  0026e6:  0c 45 00 05            cmpi.w #$5, d5
  0026ea:  67 1e                  beq.b $270a
  0026ec:  0c 45 00 04            cmpi.w #$4, d5
  0026f0:  67 18                  beq.b $270a
  0026f2:  0c 45 00 03            cmpi.w #$3, d5
  0026f6:  67 12                  beq.b $270a
  0026f8:  0c 47 00 0a            cmpi.w #$a, d7
  0026fc:  6c 0c                  bge.b $270a
  0026fe:  0c 47 ff f0            cmpi.w #$fff0, d7
  002702:  6d 06                  blt.b $270a
  002704:  76 02                  moveq #$2, d3
  002706:  60 00 00 b4            bra.w $27bc
  00270a:  0c 46 00 d3            cmpi.w #$d3, d6
  00270e:  6d 06                  blt.b $2716
  002710:  76 03                  moveq #$3, d3
  002712:  60 00 00 a8            bra.w $27bc
  002716:  0c 44 00 87            cmpi.w #$87, d4
  00271a:  6d 06                  blt.b $2722
  00271c:  0c 44 00 96            cmpi.w #$96, d4
  002720:  6d 2a                  blt.b $274c
  002722:  0c 44 00 6e            cmpi.w #$6e, d4
  002726:  6d 06                  blt.b $272e
  002728:  0c 44 00 78            cmpi.w #$78, d4
  00272c:  6d 1e                  blt.b $274c
  00272e:  0c 44 00 96            cmpi.w #$96, d4
  002732:  6d 06                  blt.b $273a
  002734:  0c 44 00 a3            cmpi.w #$a3, d4
  002738:  6d 12                  blt.b $274c
  00273a:  0c 44 00 a6            cmpi.w #$a6, d4
  00273e:  6d 06                  blt.b $2746
  002740:  0c 44 00 a9            cmpi.w #$a9, d4
  002744:  6d 06                  blt.b $274c
  002746:  0c 45 00 07            cmpi.w #$7, d5
  00274a:  66 06                  bne.b $2752
  00274c:  70 ff                  moveq #$ff, d0
  00274e:  60 00 00 bc            bra.w $280c
  002752:  4a 2d b9 49            tst.b -$46b7(a5)
  002756:  67 1e                  beq.b $2776
  002758:  0c 6d 00 36 ba dc      cmpi.w #$36, -$4524(a5)
  00275e:  6e 04                  bgt.b $2764
  002760:  76 00                  moveq #$0, d3
  002762:  60 58                  bra.b $27bc
  002764:  0c 6d 00 c6 ba dc      cmpi.w #$c6, -$4524(a5)
  00276a:  6d 04                  blt.b $2770
  00276c:  76 01                  moveq #$1, d3
  00276e:  60 4c                  bra.b $27bc
  002770:  70 ff                  moveq #$ff, d0
  002772:  60 00 00 98            bra.w $280c
  002776:  10 2d b9 4b            move.b -$46b5(a5), d0
  00277a:  48 80                  ext.w d0
  00277c:  3f 00                  move.w d0, -(a7)
  00277e:  3f 3c 00 09            move.w #$9, -(a7)
  002782:  10 2d b9 4f            move.b -$46b1(a5), d0
  002786:  48 80                  ext.w d0
  002788:  3f 00                  move.w d0, -(a7)
  00278a:  4e ba 08 ec            jsr $3078(pc)
  00278e:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  002794:  5c 8f                  addq.l #$6, a7
  002796:  67 14                  beq.b $27ac
  002798:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  00279e:  67 0c                  beq.b $27ac
  0027a0:  0c 6d 00 c9 ba de      cmpi.w #$c9, -$4522(a5)
  0027a6:  6d 04                  blt.b $27ac
  0027a8:  76 01                  moveq #$1, d3
  0027aa:  60 10                  bra.b $27bc
  0027ac:  0c 6d 00 39 ba de      cmpi.w #$39, -$4522(a5)
  0027b2:  6e 04                  bgt.b $27b8
  0027b4:  76 00                  moveq #$0, d3
  0027b6:  60 04                  bra.b $27bc
  0027b8:  70 ff                  moveq #$ff, d0
  0027ba:  60 50                  bra.b $280c
  0027bc:  30 03                  move.w d3, d0
  0027be:  67 0e                  beq.b $27ce
  0027c0:  6b 38                  bmi.b $27fa
  0027c2:  57 40                  subq.w #$3, d0
  0027c4:  67 20                  beq.b $27e6
  0027c6:  6a 32                  bpl.b $27fa
  0027c8:  52 40                  addq.w #$1, d0
  0027ca:  6a 2e                  bpl.b $27fa
  0027cc:  60 0e                  bra.b $27dc
  0027ce:  4e ba 00 4a            jsr $281a(pc)
  0027d2:  4e ba 00 40            jsr $2814(pc)
  0027d6:  4e ba 00 3a            jsr $2812(pc)
  0027da:  60 1e                  bra.b $27fa
  0027dc:  4e ba 00 38            jsr $2816(pc)
  0027e0:  4e ba 00 36            jsr $2818(pc)
  0027e4:  60 14                  bra.b $27fa
  0027e6:  0c 6d 00 06 a9 0c      cmpi.w #$6, -$56f4(a5)
  0027ec:  66 0c                  bne.b $27fa
  0027ee:  0c 2d 00 01 b9 4f      cmpi.b #$1, -$46b1(a5)
  0027f4:  66 04                  bne.b $27fa
  0027f6:  70 fe                  moveq #$fe, d0
  0027f8:  60 12                  bra.b $280c
  0027fa:  3f 03                  move.w d3, -(a7)
  0027fc:  4e ba fe 2c            jsr $262a(pc)
  002800:  4a 40                  tst.w d0
  002802:  54 8f                  addq.l #$2, a7
  002804:  6c 04                  bge.b $280a
  002806:  70 63                  moveq #$63, d0
  002808:  60 02                  bra.b $280c
  00280a:  30 03                  move.w d3, d0
  00280c:  4c df 00 f8            movem.l (a7)+, d3-d7
  002810:  4e 75                  rts 
  002812:  4e 75                  rts 
  002814:  4e 75                  rts 
  002816:  4e 75                  rts 
  002818:  4e 75                  rts 
  00281a:  4e 75                  rts 
  00281c:  42 2d ba bb            clr.b -$4545(a5)
  002820:  42 2d ba ba            clr.b -$4546(a5)
  002824:  42 2d ba b9            clr.b -$4547(a5)
  002828:  42 2d ba ae            clr.b -$4552(a5)
  00282c:  42 2d ba ad            clr.b -$4553(a5)
  002830:  42 2d ba ac            clr.b -$4554(a5)
  002834:  42 2d ba ab            clr.b -$4555(a5)
  002838:  42 2d ba aa            clr.b -$4556(a5)
  00283c:  4e 75                  rts 
  00283e:  70 ff                  moveq #$ff, d0
  002840:  1b 40 ba b9            move.b d0, -$4547(a5)
  002844:  1b 40 ba aa            move.b d0, -$4556(a5)
  002848:  4e 75                  rts 
  00284a:  1b 7c 00 ff ba ab      move.b #$ff, -$4555(a5)
  002850:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  002856:  4e 75                  rts 
  002858:  70 ff                  moveq #$ff, d0
  00285a:  1b 40 ba ba            move.b d0, -$4546(a5)
  00285e:  1b 40 ba ac            move.b d0, -$4554(a5)
  002862:  4e 75                  rts 
  002864:  1b 7c 00 ff ba ad      move.b #$ff, -$4553(a5)
  00286a:  1b 7c 00 01 ba ba      move.b #$1, -$4546(a5)
  002870:  4e 75                  rts 
  002872:  70 ff                  moveq #$ff, d0
  002874:  1b 40 ba ab            move.b d0, -$4555(a5)
  002878:  1b 40 ba ac            move.b d0, -$4554(a5)
  00287c:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  002882:  4e 75                  rts 
  002884:  70 ff                  moveq #$ff, d0
  002886:  1b 40 ba ab            move.b d0, -$4555(a5)
  00288a:  1b 40 ba ad            move.b d0, -$4553(a5)
  00288e:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  002894:  4e 75                  rts 
  002896:  70 ff                  moveq #$ff, d0
  002898:  1b 40 ba b9            move.b d0, -$4547(a5)
  00289c:  1b 40 ba aa            move.b d0, -$4556(a5)
  0028a0:  1b 40 ba ad            move.b d0, -$4553(a5)
  0028a4:  4e 75                  rts 
  0028a6:  1b 7c 00 ff ba ad      move.b #$ff, -$4553(a5)
  0028ac:  1b 7c 00 01 ba ba      move.b #$1, -$4546(a5)
  0028b2:  4e 75                  rts 
  0028b4:  70 ff                  moveq #$ff, d0
  0028b6:  1b 40 ba ab            move.b d0, -$4555(a5)
  0028ba:  1b 40 ba ad            move.b d0, -$4553(a5)
  0028be:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  0028c4:  4e 75                  rts 
  0028c6:  1b 7c 00 ff ba ab      move.b #$ff, -$4555(a5)
  0028cc:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  0028d2:  4e 75                  rts 
  0028d4:  70 ff                  moveq #$ff, d0
  0028d6:  1b 40 ba b9            move.b d0, -$4547(a5)
  0028da:  1b 40 ba aa            move.b d0, -$4556(a5)
  0028de:  4e 75                  rts 
  0028e0:  70 ff                  moveq #$ff, d0
  0028e2:  1b 40 ba bb            move.b d0, -$4545(a5)
  0028e6:  1b 40 ba ae            move.b d0, -$4552(a5)
  0028ea:  4e 75                  rts 
  0028ec:  70 ff                  moveq #$ff, d0
  0028ee:  1b 40 ba ba            move.b d0, -$4546(a5)
  0028f2:  1b 40 ba ac            move.b d0, -$4554(a5)
  0028f6:  4e 75                  rts 
  0028f8:  70 ff                  moveq #$ff, d0
  0028fa:  1b 40 ba bb            move.b d0, -$4545(a5)
  0028fe:  1b 40 ba ae            move.b d0, -$4552(a5)
  002902:  4e 75                  rts 
  002904:  42 2d ba bb            clr.b -$4545(a5)
  002908:  4e 75                  rts 
  00290a:  2f 07                  move.l d7, -(a7)
  00290c:  4e ba ff 0e            jsr $281c(pc)
  002910:  1e 2d b9 51            move.b -$46af(a5), d7
  002914:  48 87                  ext.w d7
  002916:  4a 47                  tst.w d7
  002918:  66 06                  bne.b $2920
  00291a:  4e ba 00 64            jsr $2980(pc)
  00291e:  60 54                  bra.b $2974
  002920:  4a 6d ba 2a            tst.w -$45d6(a5)
  002924:  67 04                  beq.b $292a
  002926:  53 6d ba 2a            subq.w #$1, -$45d6(a5)
  00292a:  4a 6d ba 88            tst.w -$4578(a5)
  00292e:  67 04                  beq.b $2934
  002930:  53 6d ba 88            subq.w #$1, -$4578(a5)
  002934:  4a 6d ba 8a            tst.w -$4576(a5)
  002938:  67 04                  beq.b $293e
  00293a:  53 6d ba 8a            subq.w #$1, -$4576(a5)
  00293e:  0c 47 00 18            cmpi.w #$18, d7
  002942:  66 06                  bne.b $294a
  002944:  4e ba 00 32            jsr $2978(pc)
  002948:  60 2a                  bra.b $2974
  00294a:  0c 47 00 04            cmpi.w #$4, d7
  00294e:  66 06                  bne.b $2956
  002950:  4e ba 00 2a            jsr $297c(pc)
  002954:  60 1e                  bra.b $2974
  002956:  0c 47 00 01            cmpi.w #$1, d7
  00295a:  66 06                  bne.b $2962
  00295c:  4e ba 00 1c            jsr $297a(pc)
  002960:  60 12                  bra.b $2974
  002962:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  002968:  66 06                  bne.b $2970
  00296a:  4e ba 00 12            jsr $297e(pc)
  00296e:  60 04                  bra.b $2974
  002970:  4e ba 00 14            jsr $2986(pc)
  002974:  2e 1f                  move.l (a7)+, d7
  002976:  4e 75                  rts 
  002978:  4e 75                  rts 
  00297a:  4e 75                  rts 
  00297c:  4e 75                  rts 
  00297e:  4e 75                  rts 
  002980:  4e ba 00 04            jsr $2986(pc)
  002984:  4e 75                  rts 
  002986:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  00298c:  6c 06                  bge.b $2994
  00298e:  4e ba 00 0a            jsr $299a(pc)
  002992:  60 04                  bra.b $2998
  002994:  4e ba 00 60            jsr $29f6(pc)
  002998:  4e 75                  rts 
  00299a:  2f 07                  move.l d7, -(a7)
  00299c:  4a 2d b9 77            tst.b -$4689(a5)
  0029a0:  6c 50                  bge.b $29f2
  0029a2:  4e ba 20 1a            jsr $49be(pc)
  0029a6:  3e 00                  move.w d0, d7
  0029a8:  10 2d b9 5d            move.b -$46a3(a5), d0
  0029ac:  b0 2d b9 4b            cmp.b -$46b5(a5), d0
  0029b0:  66 0a                  bne.b $29bc
  0029b2:  0c 47 ff f8            cmpi.w #$fff8, d7
  0029b6:  6d 04                  blt.b $29bc
  0029b8:  4a 47                  tst.w d7
  0029ba:  6d 1e                  blt.b $29da
  0029bc:  4a 6d ba 56            tst.w -$45aa(a5)
  0029c0:  67 14                  beq.b $29d6
  0029c2:  42 6d ba 56            clr.w -$45aa(a5)
  0029c6:  4a 47                  tst.w d7
  0029c8:  6c 10                  bge.b $29da
  0029ca:  0c 47 ff fc            cmpi.w #$fffc, d7
  0029ce:  6c 22                  bge.b $29f2
  0029d0:  4e ba fe d4            jsr $28a6(pc)
  0029d4:  60 1c                  bra.b $29f2
  0029d6:  4a 47                  tst.w d7
  0029d8:  6d 18                  blt.b $29f2
  0029da:  4a 6d ba 24            tst.w -$45dc(a5)
  0029de:  67 12                  beq.b $29f2
  0029e0:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  0029e6:  66 06                  bne.b $29ee
  0029e8:  4a 6d ba 92            tst.w -$456e(a5)
  0029ec:  66 04                  bne.b $29f2
  0029ee:  4e ba fe a6            jsr $2896(pc)
  0029f2:  2e 1f                  move.l (a7)+, d7
  0029f4:  4e 75                  rts 
  0029f6:  48 e7 03 00            movem.l d6-d7, -(a7)
  0029fa:  7e 00                  moveq #$0, d7
  0029fc:  1e 2d b9 46            move.b -$46ba(a5), d7
  002a00:  0c 47 00 a6            cmpi.w #$a6, d7
  002a04:  67 00 00 e6            beq.w $2aec
  002a08:  0c 47 00 96            cmpi.w #$96, d7
  002a0c:  6d 00 00 de            blt.w $2aec
  002a10:  0c 6d 00 01 ba 24      cmpi.w #$1, -$45dc(a5)
  002a16:  67 00 00 d4            beq.w $2aec
  002a1a:  4a 6d ba 24            tst.w -$45dc(a5)
  002a1e:  66 20                  bne.b $2a40
  002a20:  4a 6d ba 34            tst.w -$45cc(a5)
  002a24:  67 08                  beq.b $2a2e
  002a26:  4e ba 00 fe            jsr $2b26(pc)
  002a2a:  60 00 00 c0            bra.w $2aec
  002a2e:  0c 2d 00 04 b9 51      cmpi.b #$4, -$46af(a5)
  002a34:  67 00 00 b6            beq.w $2aec
  002a38:  4e ba fe 7a            jsr $28b4(pc)
  002a3c:  60 00 00 ae            bra.w $2aec
  002a40:  7e 00                  moveq #$0, d7
  002a42:  1e 2d b9 58            move.b -$46a8(a5), d7
  002a46:  4e ba 1f 76            jsr $49be(pc)
  002a4a:  3c 00                  move.w d0, d6
  002a4c:  0c 46 00 0c            cmpi.w #$c, d6
  002a50:  6d 16                  blt.b $2a68
  002a52:  0c 47 00 66            cmpi.w #$66, d7
  002a56:  6d 10                  blt.b $2a68
  002a58:  0c 47 00 76            cmpi.w #$76, d7
  002a5c:  6c 0a                  bge.b $2a68
  002a5e:  0c 2d 00 05 b9 5e      cmpi.b #$5, -$46a2(a5)
  002a64:  67 00 00 86            beq.w $2aec
  002a68:  0c 46 00 23            cmpi.w #$23, d6
  002a6c:  6c 34                  bge.b $2aa2
  002a6e:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  002a74:  6c 06                  bge.b $2a7c
  002a76:  0c 46 00 08            cmpi.w #$8, d6
  002a7a:  6d 06                  blt.b $2a82
  002a7c:  0c 46 00 0c            cmpi.w #$c, d6
  002a80:  6c 16                  bge.b $2a98
  002a82:  10 2d b9 49            move.b -$46b7(a5), d0
  002a86:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  002a8a:  66 06                  bne.b $2a92
  002a8c:  4e ba fe 38            jsr $28c6(pc)
  002a90:  60 5a                  bra.b $2aec
  002a92:  4e ba fe 40            jsr $28d4(pc)
  002a96:  60 54                  bra.b $2aec
  002a98:  3f 06                  move.w d6, -(a7)
  002a9a:  4e ba 01 40            jsr $2bdc(pc)
  002a9e:  54 8f                  addq.l #$2, a7
  002aa0:  60 4a                  bra.b $2aec
  002aa2:  4a 6d ba 8a            tst.w -$4576(a5)
  002aa6:  66 44                  bne.b $2aec
  002aa8:  10 2d b9 49            move.b -$46b7(a5), d0
  002aac:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  002ab0:  66 06                  bne.b $2ab8
  002ab2:  4e ba 00 3e            jsr $2af2(pc)
  002ab6:  60 34                  bra.b $2aec
  002ab8:  0c 47 00 07            cmpi.w #$7, d7
  002abc:  6d 12                  blt.b $2ad0
  002abe:  0c 47 00 0f            cmpi.w #$f, d7
  002ac2:  6c 0c                  bge.b $2ad0
  002ac4:  0c 46 00 28            cmpi.w #$28, d6
  002ac8:  6c 22                  bge.b $2aec
  002aca:  4e ba fe 14            jsr $28e0(pc)
  002ace:  60 1c                  bra.b $2aec
  002ad0:  0c 47 00 22            cmpi.w #$22, d7
  002ad4:  6d 12                  blt.b $2ae8
  002ad6:  0c 47 00 2c            cmpi.w #$2c, d7
  002ada:  6c 0c                  bge.b $2ae8
  002adc:  0c 46 00 32            cmpi.w #$32, d6
  002ae0:  6c 0a                  bge.b $2aec
  002ae2:  4e ba fd fc            jsr $28e0(pc)
  002ae6:  60 04                  bra.b $2aec
  002ae8:  4e ba 00 08            jsr $2af2(pc)
  002aec:  4c df 00 c0            movem.l (a7)+, d6-d7
  002af0:  4e 75                  rts 
  002af2:  4e ba 11 30            jsr $3c24(pc)
  002af6:  72 00                  moveq #$0, d1
  002af8:  12 00                  move.b d0, d1
  002afa:  3f 01                  move.w d1, -(a7)
  002afc:  4e ba 0c 5c            jsr $375a(pc)
  002b00:  4a 00                  tst.b d0
  002b02:  54 8f                  addq.l #$2, a7
  002b04:  66 14                  bne.b $2b1a
  002b06:  4e ba 11 4e            jsr $3c56(pc)
  002b0a:  72 00                  moveq #$0, d1
  002b0c:  12 00                  move.b d0, d1
  002b0e:  3f 01                  move.w d1, -(a7)
  002b10:  4e ba 0c 48            jsr $375a(pc)
  002b14:  4a 00                  tst.b d0
  002b16:  54 8f                  addq.l #$2, a7
  002b18:  67 06                  beq.b $2b20
  002b1a:  4e ba fd b8            jsr $28d4(pc)
  002b1e:  60 04                  bra.b $2b24
  002b20:  4e ba fd a4            jsr $28c6(pc)
  002b24:  4e 75                  rts 
  002b26:  2f 07                  move.l d7, -(a7)
  002b28:  1e 2d b9 5e            move.b -$46a2(a5), d7
  002b2c:  48 87                  ext.w d7
  002b2e:  0c 47 00 02            cmpi.w #$2, d7
  002b32:  67 00 00 a4            beq.w $2bd8
  002b36:  0c 47 00 06            cmpi.w #$6, d7
  002b3a:  67 00 00 9c            beq.w $2bd8
  002b3e:  4e ba 10 e4            jsr $3c24(pc)
  002b42:  1f 00                  move.b d0, -(a7)
  002b44:  4e ba 15 54            jsr $409a(pc)
  002b48:  4a 40                  tst.w d0
  002b4a:  54 8f                  addq.l #$2, a7
  002b4c:  67 0c                  beq.b $2b5a
  002b4e:  42 6d ba 34            clr.w -$45cc(a5)
  002b52:  4e ba fd 72            jsr $28c6(pc)
  002b56:  60 00 00 80            bra.w $2bd8
  002b5a:  70 00                  moveq #$0, d0
  002b5c:  10 2d ba e8            move.b -$4518(a5), d0
  002b60:  3f 00                  move.w d0, -(a7)
  002b62:  4e ba 0b f6            jsr $375a(pc)
  002b66:  4a 00                  tst.b d0
  002b68:  54 8f                  addq.l #$2, a7
  002b6a:  67 06                  beq.b $2b72
  002b6c:  4e ba fd 66            jsr $28d4(pc)
  002b70:  60 66                  bra.b $2bd8
  002b72:  52 6d ba ee            addq.w #$1, -$4512(a5)
  002b76:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  002b7a:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  002b7e:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  002b82:  4e ba 04 f4            jsr $3078(pc)
  002b86:  0c 2d 00 02 ba e8      cmpi.b #$2, -$4518(a5)
  002b8c:  5c 8f                  addq.l #$6, a7
  002b8e:  67 3a                  beq.b $2bca
  002b90:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  002b96:  67 32                  beq.b $2bca
  002b98:  1f 2d ba e8            move.b -$4518(a5), -(a7)
  002b9c:  4e ba 14 fc            jsr $409a(pc)
  002ba0:  4a 40                  tst.w d0
  002ba2:  54 8f                  addq.l #$2, a7
  002ba4:  66 24                  bne.b $2bca
  002ba6:  70 00                  moveq #$0, d0
  002ba8:  10 2d ba e8            move.b -$4518(a5), d0
  002bac:  3f 00                  move.w d0, -(a7)
  002bae:  4e ba 0b aa            jsr $375a(pc)
  002bb2:  4a 00                  tst.b d0
  002bb4:  54 8f                  addq.l #$2, a7
  002bb6:  67 12                  beq.b $2bca
  002bb8:  10 2d b9 4b            move.b -$46b5(a5), d0
  002bbc:  48 80                  ext.w d0
  002bbe:  12 2d b9 5d            move.b -$46a3(a5), d1
  002bc2:  48 81                  ext.w d1
  002bc4:  52 40                  addq.w #$1, d0
  002bc6:  b2 40                  cmp.w d0, d1
  002bc8:  67 0a                  beq.b $2bd4
  002bca:  42 6d ba 34            clr.w -$45cc(a5)
  002bce:  4e ba fc f6            jsr $28c6(pc)
  002bd2:  60 04                  bra.b $2bd8
  002bd4:  4e ba fc fe            jsr $28d4(pc)
  002bd8:  2e 1f                  move.l (a7)+, d7
  002bda:  4e 75                  rts 
  002bdc:  4e 56 00 00            link.w a6, #$0
  002be0:  0c 2d 00 02 b9 64      cmpi.b #$2, -$469c(a5)
  002be6:  66 0c                  bne.b $2bf4
  002be8:  3f 2e 00 08            move.w $8(a6), -(a7)
  002bec:  4e ba 00 22            jsr $2c10(pc)
  002bf0:  54 8f                  addq.l #$2, a7
  002bf2:  60 18                  bra.b $2c0c
  002bf4:  4a 6d ba 8a            tst.w -$4576(a5)
  002bf8:  66 12                  bne.b $2c0c
  002bfa:  0c 6e 00 1d 00 08      cmpi.w #$1d, $8(a6)
  002c00:  6c 06                  bge.b $2c08
  002c02:  4e ba fc dc            jsr $28e0(pc)
  002c06:  60 04                  bra.b $2c0c
  002c08:  4e ba fc ca            jsr $28d4(pc)
  002c0c:  4e 5e                  unlk a6
  002c0e:  4e 75                  rts 
  002c10:  4e 56 00 00            link.w a6, #$0
  002c14:  2f 07                  move.l d7, -(a7)
  002c16:  3e 2e 00 08            move.w $8(a6), d7
  002c1a:  0c 47 00 0a            cmpi.w #$a, d7
  002c1e:  6d 06                  blt.b $2c26
  002c20:  0c 47 00 1d            cmpi.w #$1d, d7
  002c24:  6d 06                  blt.b $2c2c
  002c26:  4e ba 00 2a            jsr $2c52(pc)
  002c2a:  60 20                  bra.b $2c4c
  002c2c:  4e ba 00 52            jsr $2c80(pc)
  002c30:  4a 6d ba 8a            tst.w -$4576(a5)
  002c34:  66 16                  bne.b $2c4c
  002c36:  0c 47 00 0c            cmpi.w #$c, d7
  002c3a:  6d 06                  blt.b $2c42
  002c3c:  0c 47 00 1d            cmpi.w #$1d, d7
  002c40:  6d 06                  blt.b $2c48
  002c42:  4e ba 00 0e            jsr $2c52(pc)
  002c46:  60 04                  bra.b $2c4c
  002c48:  4e ba 00 9c            jsr $2ce6(pc)
  002c4c:  2e 1f                  move.l (a7)+, d7
  002c4e:  4e 5e                  unlk a6
  002c50:  4e 75                  rts 
  002c52:  4a 6d ba 20            tst.w -$45e0(a5)
  002c56:  67 06                  beq.b $2c5e
  002c58:  4a 6d ba 88            tst.w -$4578(a5)
  002c5c:  66 20                  bne.b $2c7e
  002c5e:  3f 3c 00 ff            move.w #$ff, -(a7)
  002c62:  4e ad 00 72            jsr $72(a5)
  002c66:  32 2d ba 20            move.w -$45e0(a5), d1
  002c6a:  20 4d                  movea.l a5, a0
  002c6c:  d0 c1                  adda.w d1, a0
  002c6e:  74 00                  moveq #$0, d2
  002c70:  14 28 a9 54            move.b -$56ac(a0), d2
  002c74:  b4 40                  cmp.w d0, d2
  002c76:  54 8f                  addq.l #$2, a7
  002c78:  6f 04                  ble.b $2c7e
  002c7a:  4e ba fc 58            jsr $28d4(pc)
  002c7e:  4e 75                  rts 
  002c80:  2f 07                  move.l d7, -(a7)
  002c82:  7e 00                  moveq #$0, d7
  002c84:  1e 2d b9 58            move.b -$46a8(a5), d7
  002c88:  0c 47 00 98            cmpi.w #$98, d7
  002c8c:  67 0c                  beq.b $2c9a
  002c8e:  0c 47 00 99            cmpi.w #$99, d7
  002c92:  67 06                  beq.b $2c9a
  002c94:  0c 47 00 a2            cmpi.w #$a2, d7
  002c98:  66 48                  bne.b $2ce2
  002c9a:  4a 6d ba 2a            tst.w -$45d6(a5)
  002c9e:  67 22                  beq.b $2cc2
  002ca0:  3f 3c 00 ff            move.w #$ff, -(a7)
  002ca4:  4e ad 00 72            jsr $72(a5)
  002ca8:  32 2d ba 20            move.w -$45e0(a5), d1
  002cac:  20 4d                  movea.l a5, a0
  002cae:  d0 c1                  adda.w d1, a0
  002cb0:  74 00                  moveq #$0, d2
  002cb2:  14 28 a9 48            move.b -$56b8(a0), d2
  002cb6:  b4 40                  cmp.w d0, d2
  002cb8:  54 8f                  addq.l #$2, a7
  002cba:  6f 26                  ble.b $2ce2
  002cbc:  4e ba fc 2e            jsr $28ec(pc)
  002cc0:  60 20                  bra.b $2ce2
  002cc2:  3f 3c 00 ff            move.w #$ff, -(a7)
  002cc6:  4e ad 00 72            jsr $72(a5)
  002cca:  32 2d ba 20            move.w -$45e0(a5), d1
  002cce:  20 4d                  movea.l a5, a0
  002cd0:  d0 c1                  adda.w d1, a0
  002cd2:  74 00                  moveq #$0, d2
  002cd4:  14 28 a9 3c            move.b -$56c4(a0), d2
  002cd8:  b4 40                  cmp.w d0, d2
  002cda:  54 8f                  addq.l #$2, a7
  002cdc:  6f 04                  ble.b $2ce2
  002cde:  4e ba fc 0c            jsr $28ec(pc)
  002ce2:  2e 1f                  move.l (a7)+, d7
  002ce4:  4e 75                  rts 
  002ce6:  2f 07                  move.l d7, -(a7)
  002ce8:  7e 00                  moveq #$0, d7
  002cea:  1e 2d b9 58            move.b -$46a8(a5), d7
  002cee:  0c 47 00 a9            cmpi.w #$a9, d7
  002cf2:  67 5a                  beq.b $2d4e
  002cf4:  0c 47 00 97            cmpi.w #$97, d7
  002cf8:  67 54                  beq.b $2d4e
  002cfa:  7e 00                  moveq #$0, d7
  002cfc:  1e 2d b9 46            move.b -$46ba(a5), d7
  002d00:  0c 47 00 a1            cmpi.w #$a1, d7
  002d04:  67 06                  beq.b $2d0c
  002d06:  0c 47 00 96            cmpi.w #$96, d7
  002d0a:  66 22                  bne.b $2d2e
  002d0c:  3f 3c 00 ff            move.w #$ff, -(a7)
  002d10:  4e ad 00 72            jsr $72(a5)
  002d14:  32 2d ba 20            move.w -$45e0(a5), d1
  002d18:  20 4d                  movea.l a5, a0
  002d1a:  d0 c1                  adda.w d1, a0
  002d1c:  74 00                  moveq #$0, d2
  002d1e:  14 28 a9 30            move.b -$56d0(a0), d2
  002d22:  b4 40                  cmp.w d0, d2
  002d24:  54 8f                  addq.l #$2, a7
  002d26:  6f 26                  ble.b $2d4e
  002d28:  4e ba fb b6            jsr $28e0(pc)
  002d2c:  60 20                  bra.b $2d4e
  002d2e:  3f 3c 00 ff            move.w #$ff, -(a7)
  002d32:  4e ad 00 72            jsr $72(a5)
  002d36:  32 2d ba 20            move.w -$45e0(a5), d1
  002d3a:  20 4d                  movea.l a5, a0
  002d3c:  d0 c1                  adda.w d1, a0
  002d3e:  74 00                  moveq #$0, d2
  002d40:  14 28 a9 24            move.b -$56dc(a0), d2
  002d44:  b4 40                  cmp.w d0, d2
  002d46:  54 8f                  addq.l #$2, a7
  002d48:  6f 04                  ble.b $2d4e
  002d4a:  4e ba fb 94            jsr $28e0(pc)
  002d4e:  2e 1f                  move.l (a7)+, d7
  002d50:  4e 75                  rts 
  002d52:  48 e7 03 00            movem.l d6-d7, -(a7)
  002d56:  4a 2d b9 53            tst.b -$46ad(a5)
  002d5a:  6c 00 01 22            bge.w $2e7e
  002d5e:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  002d64:  67 14                  beq.b $2d7a
  002d66:  3f 3c 00 64            move.w #$64, -(a7)
  002d6a:  4e ba 0a a0            jsr $380c(pc)
  002d6e:  3e bc 00 55            move.w #$55, (a7)
  002d72:  4e ad 05 22            jsr $522(a5)
  002d76:  54 8f                  addq.l #$2, a7
  002d78:  60 3a                  bra.b $2db4
  002d7a:  0c 2d 00 04 b9 51      cmpi.b #$4, -$46af(a5)
  002d80:  67 0e                  beq.b $2d90
  002d82:  3f 3c 00 01            move.w #$1, -(a7)
  002d86:  4e ba 0a 84            jsr $380c(pc)
  002d8a:  4a 40                  tst.w d0
  002d8c:  54 8f                  addq.l #$2, a7
  002d8e:  66 24                  bne.b $2db4
  002d90:  3f 3c 00 4a            move.w #$4a, -(a7)
  002d94:  4e ad 05 22            jsr $522(a5)
  002d98:  10 2d b9 4b            move.b -$46b5(a5), d0
  002d9c:  48 80                  ext.w d0
  002d9e:  20 4d                  movea.l a5, a0
  002da0:  d0 c0                  adda.w d0, a0
  002da2:  d0 c0                  adda.w d0, a0
  002da4:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  002daa:  42 2d b9 4e            clr.b -$46b2(a5)
  002dae:  54 8f                  addq.l #$2, a7
  002db0:  60 00 00 ac            bra.w $2e5e
  002db4:  4e ba 0f 0e            jsr $3cc4(pc)
  002db8:  3e 00                  move.w d0, d7
  002dba:  4e ba 0e d6            jsr $3c92(pc)
  002dbe:  72 00                  moveq #$0, d1
  002dc0:  12 00                  move.b d0, d1
  002dc2:  4a 41                  tst.w d1
  002dc4:  66 06                  bne.b $2dcc
  002dc6:  0c 47 00 04            cmpi.w #$4, d7
  002dca:  6c 72                  bge.b $2e3e
  002dcc:  3f 3c 00 55            move.w #$55, -(a7)
  002dd0:  4e ad 05 22            jsr $522(a5)
  002dd4:  4a 2d b9 51            tst.b -$46af(a5)
  002dd8:  54 8f                  addq.l #$2, a7
  002dda:  67 4a                  beq.b $2e26
  002ddc:  4a 2d b9 49            tst.b -$46b7(a5)
  002de0:  6c 44                  bge.b $2e26
  002de2:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  002de8:  67 0c                  beq.b $2df6
  002dea:  4e ba 0a 7c            jsr $3868(pc)
  002dee:  72 00                  moveq #$0, d1
  002df0:  12 00                  move.b d0, d1
  002df2:  59 41                  subq.w #$4, d1
  002df4:  66 30                  bne.b $2e26
  002df6:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  002dfc:  56 c0                  sne.b d0
  002dfe:  44 00                  neg.b d0
  002e00:  48 80                  ext.w d0
  002e02:  72 05                  moveq #$5, d1
  002e04:  d2 6d ba ec            add.w -$4514(a5), d1
  002e08:  92 40                  sub.w d0, d1
  002e0a:  20 4d                  movea.l a5, a0
  002e0c:  d0 c1                  adda.w d1, a0
  002e0e:  70 07                  moveq #$7, d0
  002e10:  d0 28 b8 78            add.b -$4788(a0), d0
  002e14:  1b 40 b9 47            move.b d0, -$46b9(a5)
  002e18:  3f 3c 00 0a            move.w #$a, -(a7)
  002e1c:  4e ba 04 ea            jsr $3308(pc)
  002e20:  1b 40 b9 47            move.b d0, -$46b9(a5)
  002e24:  54 8f                  addq.l #$2, a7
  002e26:  10 2d b9 4b            move.b -$46b5(a5), d0
  002e2a:  48 80                  ext.w d0
  002e2c:  20 4d                  movea.l a5, a0
  002e2e:  d0 c0                  adda.w d0, a0
  002e30:  d0 c0                  adda.w d0, a0
  002e32:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  002e38:  42 2d b9 4e            clr.b -$46b2(a5)
  002e3c:  60 20                  bra.b $2e5e
  002e3e:  70 ec                  moveq #$ec, d0
  002e40:  d0 47                  add.w d7, d0
  002e42:  3f 00                  move.w d0, -(a7)
  002e44:  4e ba 04 c2            jsr $3308(pc)
  002e48:  1b 40 b9 47            move.b d0, -$46b9(a5)
  002e4c:  4e ba 03 84            jsr $31d2(pc)
  002e50:  4e ba 1b ac            jsr $49fe(pc)
  002e54:  3e bc 00 51            move.w #$51, (a7)
  002e58:  4e ad 05 22            jsr $522(a5)
  002e5c:  54 8f                  addq.l #$2, a7
  002e5e:  4a 2d b9 51            tst.b -$46af(a5)
  002e62:  66 0c                  bne.b $2e70
  002e64:  3f 3c 00 0d            move.w #$d, -(a7)
  002e68:  4e ba d9 4a            jsr $7b4(pc)
  002e6c:  54 8f                  addq.l #$2, a7
  002e6e:  60 0a                  bra.b $2e7a
  002e70:  3f 3c 00 0c            move.w #$c, -(a7)
  002e74:  4e ba d9 3e            jsr $7b4(pc)
  002e78:  54 8f                  addq.l #$2, a7
  002e7a:  4e ba 04 d4            jsr $3350(pc)
  002e7e:  4c df 00 c0            movem.l (a7)+, d6-d7
  002e82:  4e 75                  rts 
  002e84:  0c 2d 00 63 b9 82      cmpi.b #$63, -$467e(a5)
  002e8a:  66 2e                  bne.b $2eba
  002e8c:  0c 2d 00 63 b9 70      cmpi.b #$63, -$4690(a5)
  002e92:  66 06                  bne.b $2e9a
  002e94:  1b 7c 00 01 b9 70      move.b #$1, -$4690(a5)
  002e9a:  4e ba 07 12            jsr $35ae(pc)
  002e9e:  4e ba fe b2            jsr $2d52(pc)
  002ea2:  4e ba 07 1e            jsr $35c2(pc)
  002ea6:  30 2d ba 20            move.w -$45e0(a5), d0
  002eaa:  20 4d                  movea.l a5, a0
  002eac:  d0 c0                  adda.w d0, a0
  002eae:  72 00                  moveq #$0, d1
  002eb0:  12 28 a9 60            move.b -$56a0(a0), d1
  002eb4:  3b 41 ba 8a            move.w d1, -$4576(a5)
  002eb8:  60 14                  bra.b $2ece
  002eba:  0c 2d 00 63 b9 70      cmpi.b #$63, -$4690(a5)
  002ec0:  66 0c                  bne.b $2ece
  002ec2:  4e ba 06 c2            jsr $3586(pc)
  002ec6:  4e ba fe 8a            jsr $2d52(pc)
  002eca:  4e ba 06 ce            jsr $359a(pc)
  002ece:  4e 75                  rts 
  002ed0:  2f 07                  move.l d7, -(a7)
  002ed2:  7e 00                  moveq #$0, d7
  002ed4:  1e 2d b9 6a            move.b -$4696(a5), d7
  002ed8:  4a 47                  tst.w d7
  002eda:  67 24                  beq.b $2f00
  002edc:  0c 47 00 db            cmpi.w #$db, d7
  002ee0:  6d 06                  blt.b $2ee8
  002ee2:  0c 47 00 e5            cmpi.w #$e5, d7
  002ee6:  6d 18                  blt.b $2f00
  002ee8:  4e ba 07 38            jsr $3622(pc)
  002eec:  4e ba 00 16            jsr $2f04(pc)
  002ef0:  4e ba 07 56            jsr $3648(pc)
  002ef4:  4e ba 06 e0            jsr $35d6(pc)
  002ef8:  4e ba 00 0a            jsr $2f04(pc)
  002efc:  4e ba 06 fe            jsr $35fc(pc)
  002f00:  2e 1f                  move.l (a7)+, d7
  002f02:  4e 75                  rts 
  002f04:  48 e7 0f 00            movem.l d4-d7, -(a7)
  002f08:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  002f0e:  66 00 00 aa            bne.w $2fba
  002f12:  10 2d b9 4b            move.b -$46b5(a5), d0
  002f16:  b0 2d b9 5d            cmp.b -$46a3(a5), d0
  002f1a:  66 00 00 9e            bne.w $2fba
  002f1e:  7e 00                  moveq #$0, d7
  002f20:  1e 2d b9 46            move.b -$46ba(a5), d7
  002f24:  0c 47 00 99            cmpi.w #$99, d7
  002f28:  67 08                  beq.b $2f32
  002f2a:  0c 47 00 9a            cmpi.w #$9a, d7
  002f2e:  66 00 00 8a            bne.w $2fba
  002f32:  4e ba 1a 8a            jsr $49be(pc)
  002f36:  3c 00                  move.w d0, d6
  002f38:  7a 00                  moveq #$0, d5
  002f3a:  1a 2d b9 58            move.b -$46a8(a5), d5
  002f3e:  4a 46                  tst.w d6
  002f40:  6d 12                  blt.b $2f54
  002f42:  0c 46 00 1d            cmpi.w #$1d, d6
  002f46:  6c 0c                  bge.b $2f54
  002f48:  0c 45 00 a1            cmpi.w #$a1, d5
  002f4c:  67 2c                  beq.b $2f7a
  002f4e:  0c 45 00 96            cmpi.w #$96, d5
  002f52:  67 26                  beq.b $2f7a
  002f54:  0c 47 00 9a            cmpi.w #$9a, d7
  002f58:  66 42                  bne.b $2f9c
  002f5a:  0c 2d 00 02 b9 64      cmpi.b #$2, -$469c(a5)
  002f60:  6c 04                  bge.b $2f66
  002f62:  78 08                  moveq #$8, d4
  002f64:  60 02                  bra.b $2f68
  002f66:  78 0c                  moveq #$c, d4
  002f68:  b8 46                  cmp.w d6, d4
  002f6a:  6e 30                  bgt.b $2f9c
  002f6c:  0c 46 00 1d            cmpi.w #$1d, d6
  002f70:  6c 2a                  bge.b $2f9c
  002f72:  1b 7c 00 63 b9 5e      move.b #$63, -$46a2(a5)
  002f78:  60 22                  bra.b $2f9c
  002f7a:  3a 3c 00 a1            move.w #$a1, d5
  002f7e:  1b 45 b9 58            move.b d5, -$46a8(a5)
  002f82:  4a 2d b9 51            tst.b -$46af(a5)
  002f86:  67 06                  beq.b $2f8e
  002f88:  3b 7c 00 04 ba 2a      move.w #$4, -$45d6(a5)
  002f8e:  3f 3c 00 45            move.w #$45, -(a7)
  002f92:  4e ad 05 22            jsr $522(a5)
  002f96:  4e ba 03 b8            jsr $3350(pc)
  002f9a:  54 8f                  addq.l #$2, a7
  002f9c:  0c 47 00 9a            cmpi.w #$9a, d7
  002fa0:  66 18                  bne.b $2fba
  002fa2:  0c 45 00 a1            cmpi.w #$a1, d5
  002fa6:  67 12                  beq.b $2fba
  002fa8:  0c 2d 00 63 b9 5e      cmpi.b #$63, -$46a2(a5)
  002fae:  67 0a                  beq.b $2fba
  002fb0:  3f 3c 00 0b            move.w #$b, -(a7)
  002fb4:  4e ba d7 fe            jsr $7b4(pc)
  002fb8:  54 8f                  addq.l #$2, a7
  002fba:  4c df 00 f0            movem.l (a7)+, d4-d7
  002fbe:  4e 75                  rts 
  002fc0:  4e 75                  rts 
  002fc2:  4e 56 00 00            link.w a6, #$0
  002fc6:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  002fca:  28 6e 00 08            movea.l $8(a6), a4
  002fce:  0c 6d 00 fe ba 5a      cmpi.w #$fe, -$45a6(a5)
  002fd4:  6c 00 00 80            bge.w $3056
  002fd8:  52 6d ba 5a            addq.w #$1, -$45a6(a5)
  002fdc:  3e 2d ba 5c            move.w -$45a4(a5), d7
  002fe0:  20 07                  move.l d7, d0
  002fe2:  48 c0                  ext.l d0
  002fe4:  e5 88                  lsl.l #$2, d0
  002fe6:  30 34 08 00            move.w (a4, d0.l), d0
  002fea:  b0 6d ba 5a            cmp.w -$45a6(a5), d0
  002fee:  6e 06                  bgt.b $2ff6
  002ff0:  52 6d ba 5c            addq.w #$1, -$45a4(a5)
  002ff4:  60 02                  bra.b $2ff8
  002ff6:  53 47                  subq.w #$1, d7
  002ff8:  20 07                  move.l d7, d0
  002ffa:  48 c0                  ext.l d0
  002ffc:  e5 88                  lsl.l #$2, d0
  002ffe:  3c 34 08 02            move.w $2(a4, d0.l), d6
  003002:  30 06                  move.w d6, d0
  003004:  52 40                  addq.w #$1, d0
  003006:  0c 40 00 08            cmpi.w #$8, d0
  00300a:  62 4a                  bhi.b $3056
  00300c:  43 fa 00 50            lea.l $305e(pc), a1
  003010:  d0 40                  add.w d0, d0
  003012:  d2 f1 00 00            adda.w (a1, d0.w), a1
  003016:  4e d1                  jmp (a1)
  003018:  4a 6d ba 5e            tst.w -$45a2(a5)
  00301c:  67 38                  beq.b $3056
  00301e:  42 6d ba 5e            clr.w -$45a2(a5)
  003022:  60 32                  bra.b $3056
  003024:  4e ba f7 f6            jsr $281c(pc)
  003028:  60 2c                  bra.b $3056
  00302a:  4e ba f8 12            jsr $283e(pc)
  00302e:  60 26                  bra.b $3056
  003030:  4e ba f8 18            jsr $284a(pc)
  003034:  60 20                  bra.b $3056
  003036:  4e ba f8 20            jsr $2858(pc)
  00303a:  60 1a                  bra.b $3056
  00303c:  4e ba f8 26            jsr $2864(pc)
  003040:  60 14                  bra.b $3056
  003042:  4e ba f8 14            jsr $2858(pc)
  003046:  4e ba f7 f6            jsr $283e(pc)
  00304a:  60 0a                  bra.b $3056
  00304c:  4e ba f8 aa            jsr $28f8(pc)
  003050:  60 04                  bra.b $3056
  003052:  4e ba f8 b0            jsr $2904(pc)
  003056:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  00305a:  4e 5e                  unlk a6
  00305c:  4e 75                  rts 
  00305e:  ff ba                  dc.w $ffba
  003060:  ff c6                  dc.w $ffc6
  003062:  ff cc                  dc.w $ffcc
  003064:  ff d2                  dc.w $ffd2
  003066:  ff d8                  dc.w $ffd8
  003068:  ff de                  dc.w $ffde
  00306a:  ff e4                  dc.w $ffe4
  00306c:  ff ee                  dc.w $ffee
  00306e:  ff f4                  dc.w $fff4
  003070:  4e 75                  rts 
  003072:  4e 75                  rts 
  003074:  4e 75                  rts 
  003076:  4e 75                  rts 
  003078:  4e 56 00 00            link.w a6, #$0
  00307c:  48 e7 1f 00            movem.l d3-d7, -(a7)
  003080:  3c 2e 00 08            move.w $8(a6), d6
  003084:  3e 2e 00 0a            move.w $a(a6), d7
  003088:  3a 2e 00 0c            move.w $c(a6), d5
  00308c:  60 18                  bra.b $30a6
  00308e:  06 47 00 0a            addi.w #$a, d7
  003092:  4a 46                  tst.w d6
  003094:  67 10                  beq.b $30a6
  003096:  20 4d                  movea.l a5, a0
  003098:  20 06                  move.l d6, d0
  00309a:  48 c0                  ext.l d0
  00309c:  e5 88                  lsl.l #$2, d0
  00309e:  d1 c0                  adda.l d0, a0
  0030a0:  7c 00                  moveq #$0, d6
  0030a2:  1c 28 f0 ba            move.b -$f46(a0), d6
  0030a6:  4a 47                  tst.w d7
  0030a8:  6d e4                  blt.b $308e
  0030aa:  60 18                  bra.b $30c4
  0030ac:  06 47 ff f6            addi.w #$fff6, d7
  0030b0:  4a 46                  tst.w d6
  0030b2:  67 10                  beq.b $30c4
  0030b4:  20 4d                  movea.l a5, a0
  0030b6:  20 06                  move.l d6, d0
  0030b8:  48 c0                  ext.l d0
  0030ba:  e5 88                  lsl.l #$2, d0
  0030bc:  d1 c0                  adda.l d0, a0
  0030be:  7c 00                  moveq #$0, d6
  0030c0:  1c 28 f0 bb            move.b -$f45(a0), d6
  0030c4:  0c 47 00 0a            cmpi.w #$a, d7
  0030c8:  6c e2                  bge.b $30ac
  0030ca:  60 16                  bra.b $30e2
  0030cc:  56 45                  addq.w #$3, d5
  0030ce:  4a 46                  tst.w d6
  0030d0:  67 10                  beq.b $30e2
  0030d2:  20 4d                  movea.l a5, a0
  0030d4:  20 06                  move.l d6, d0
  0030d6:  48 c0                  ext.l d0
  0030d8:  e5 88                  lsl.l #$2, d0
  0030da:  d1 c0                  adda.l d0, a0
  0030dc:  7c 00                  moveq #$0, d6
  0030de:  1c 28 f0 bc            move.b -$f44(a0), d6
  0030e2:  4a 45                  tst.w d5
  0030e4:  6d e6                  blt.b $30cc
  0030e6:  60 16                  bra.b $30fe
  0030e8:  57 45                  subq.w #$3, d5
  0030ea:  4a 46                  tst.w d6
  0030ec:  67 10                  beq.b $30fe
  0030ee:  20 4d                  movea.l a5, a0
  0030f0:  20 06                  move.l d6, d0
  0030f2:  48 c0                  ext.l d0
  0030f4:  e5 88                  lsl.l #$2, d0
  0030f6:  d1 c0                  adda.l d0, a0
  0030f8:  7c 00                  moveq #$0, d6
  0030fa:  1c 28 f0 bd            move.b -$f43(a0), d6
  0030fe:  0c 45 00 03            cmpi.w #$3, d5
  003102:  6c e4                  bge.b $30e8
  003104:  4a 46                  tst.w d6
  003106:  67 24                  beq.b $312c
  003108:  3f 06                  move.w d6, -(a7)
  00310a:  4e ad 04 e2            jsr $4e2(a5)
  00310e:  20 4d                  movea.l a5, a0
  003110:  d0 c5                  adda.w d5, a0
  003112:  d0 c5                  adda.w d5, a0
  003114:  38 28 b6 46            move.w -$49ba(a0), d4
  003118:  d8 47                  add.w d7, d4
  00311a:  20 6d bd 82            movea.l -$427e(a5), a0
  00311e:  76 00                  moveq #$0, d3
  003120:  16 30 40 00            move.b (a0, d4.w), d3
  003124:  02 43 00 1f            andi.w #$1f, d3
  003128:  54 8f                  addq.l #$2, a7
  00312a:  60 04                  bra.b $3130
  00312c:  78 00                  moveq #$0, d4
  00312e:  76 14                  moveq #$14, d3
  003130:  3b 46 ba ea            move.w d6, -$4516(a5)
  003134:  3b 47 ba ec            move.w d7, -$4514(a5)
  003138:  3b 45 ba ee            move.w d5, -$4512(a5)
  00313c:  1b 44 ba e9            move.b d4, -$4517(a5)
  003140:  1b 43 ba e8            move.b d3, -$4518(a5)
  003144:  10 03                  move.b d3, d0
  003146:  4c df 00 f8            movem.l (a7)+, d3-d7
  00314a:  4e 5e                  unlk a6
  00314c:  4e 75                  rts 
  00314e:  4e 56 00 00            link.w a6, #$0
  003152:  48 e7 03 00            movem.l d6-d7, -(a7)
  003156:  3e 2e 00 08            move.w $8(a6), d7
  00315a:  3c 2e 00 0a            move.w $a(a6), d6
  00315e:  4a 47                  tst.w d7
  003160:  6d 26                  blt.b $3188
  003162:  0c 47 00 0a            cmpi.w #$a, d7
  003166:  6c 20                  bge.b $3188
  003168:  4a 46                  tst.w d6
  00316a:  6c 08                  bge.b $3174
  00316c:  70 01                  moveq #$1, d0
  00316e:  d0 47                  add.w d7, d0
  003170:  44 40                  neg.w d0
  003172:  60 16                  bra.b $318a
  003174:  0c 46 00 03            cmpi.w #$3, d6
  003178:  6c 0e                  bge.b $3188
  00317a:  20 4d                  movea.l a5, a0
  00317c:  d0 c6                  adda.w d6, a0
  00317e:  d0 c6                  adda.w d6, a0
  003180:  30 28 b6 46            move.w -$49ba(a0), d0
  003184:  d0 47                  add.w d7, d0
  003186:  60 02                  bra.b $318a
  003188:  70 1e                  moveq #$1e, d0
  00318a:  4c df 00 c0            movem.l (a7)+, d6-d7
  00318e:  4e 5e                  unlk a6
  003190:  4e 75                  rts 
  003192:  4e 56 00 00            link.w a6, #$0
  003196:  48 e7 03 00            movem.l d6-d7, -(a7)
  00319a:  3e 2e 00 08            move.w $8(a6), d7
  00319e:  3c 2e 00 0a            move.w $a(a6), d6
  0031a2:  4a 47                  tst.w d7
  0031a4:  6d 22                  blt.b $31c8
  0031a6:  0c 47 00 0a            cmpi.w #$a, d7
  0031aa:  6c 1c                  bge.b $31c8
  0031ac:  4a 46                  tst.w d6
  0031ae:  6c 04                  bge.b $31b4
  0031b0:  70 1e                  moveq #$1e, d0
  0031b2:  60 16                  bra.b $31ca
  0031b4:  0c 46 00 03            cmpi.w #$3, d6
  0031b8:  6c 0e                  bge.b $31c8
  0031ba:  20 4d                  movea.l a5, a0
  0031bc:  d0 c6                  adda.w d6, a0
  0031be:  d0 c6                  adda.w d6, a0
  0031c0:  30 28 b6 46            move.w -$49ba(a0), d0
  0031c4:  d0 47                  add.w d7, d0
  0031c6:  60 02                  bra.b $31ca
  0031c8:  70 1e                  moveq #$1e, d0
  0031ca:  4c df 00 c0            movem.l (a7)+, d6-d7
  0031ce:  4e 5e                  unlk a6
  0031d0:  4e 75                  rts 
  0031d2:  4e ba 00 1a            jsr $31ee(pc)
  0031d6:  4e ba 00 04            jsr $31dc(pc)
  0031da:  4e 75                  rts 
  0031dc:  4e ba 00 f8            jsr $32d6(pc)
  0031e0:  3f 00                  move.w d0, -(a7)
  0031e2:  4e ba 03 00            jsr $34e4(pc)
  0031e6:  1b 40 b9 4a            move.b d0, -$46b6(a5)
  0031ea:  54 8f                  addq.l #$2, a7
  0031ec:  4e 75                  rts 
  0031ee:  2f 07                  move.l d7, -(a7)
  0031f0:  7e 00                  moveq #$0, d7
  0031f2:  1e 2d b9 46            move.b -$46ba(a5), d7
  0031f6:  10 2d b9 51            move.b -$46af(a5), d0
  0031fa:  67 2a                  beq.b $3226
  0031fc:  6b 00 00 d4            bmi.w $32d2
  003200:  59 00                  subq.b #$4, d0
  003202:  67 3a                  beq.b $323e
  003204:  6a 0a                  bpl.b $3210
  003206:  54 00                  addq.b #$2, d0
  003208:  67 34                  beq.b $323e
  00320a:  6a 00 00 c6            bpl.w $32d2
  00320e:  60 70                  bra.b $3280
  003210:  04 00 00 14            subi.b #$14, d0
  003214:  67 10                  beq.b $3226
  003216:  6a 00 00 ba            bpl.w $32d2
  00321a:  04 00 00 ef            subi.b #$ef, d0
  00321e:  6a 00 00 b2            bpl.w $32d2
  003222:  60 00 00 9a            bra.w $32be
  003226:  70 06                  moveq #$6, d0
  003228:  c1 c7                  muls.w d7, d0
  00322a:  20 4d                  movea.l a5, a0
  00322c:  d1 c0                  adda.l d0, a0
  00322e:  2b 68 aa 94 b9 8e      move.l -$556c(a0), -$4672(a5)
  003234:  3b 68 aa 98 b9 92      move.w -$5568(a0), -$466e(a5)
  00323a:  60 00 00 96            bra.w $32d2
  00323e:  0c 47 00 66            cmpi.w #$66, d7
  003242:  6d 20                  blt.b $3264
  003244:  0c 47 00 6b            cmpi.w #$6b, d7
  003248:  6c 1a                  bge.b $3264
  00324a:  70 b1                  moveq #$b1, d0
  00324c:  d0 47                  add.w d7, d0
  00324e:  c1 fc 00 06            muls.w #$6, d0
  003252:  20 4d                  movea.l a5, a0
  003254:  d1 c0                  adda.l d0, a0
  003256:  2b 68 b0 3a b9 8e      move.l -$4fc6(a0), -$4672(a5)
  00325c:  3b 68 b0 3e b9 92      move.w -$4fc2(a0), -$466e(a5)
  003262:  60 6e                  bra.b $32d2
  003264:  30 07                  move.w d7, d0
  003266:  06 40 ff 6b            addi.w #$ff6b, d0
  00326a:  c1 fc 00 06            muls.w #$6, d0
  00326e:  20 4d                  movea.l a5, a0
  003270:  d1 c0                  adda.l d0, a0
  003272:  2b 68 b0 3a b9 8e      move.l -$4fc6(a0), -$4672(a5)
  003278:  3b 68 b0 3e b9 92      move.w -$4fc2(a0), -$466e(a5)
  00327e:  60 52                  bra.b $32d2
  003280:  0c 47 00 96            cmpi.w #$96, d7
  003284:  6d 22                  blt.b $32a8
  003286:  0c 47 00 be            cmpi.w #$be, d7
  00328a:  6c 1c                  bge.b $32a8
  00328c:  30 07                  move.w d7, d0
  00328e:  06 40 ff 6b            addi.w #$ff6b, d0
  003292:  c1 fc 00 06            muls.w #$6, d0
  003296:  20 4d                  movea.l a5, a0
  003298:  d1 c0                  adda.l d0, a0
  00329a:  2b 68 b0 3a b9 8e      move.l -$4fc6(a0), -$4672(a5)
  0032a0:  3b 68 b0 3e b9 92      move.w -$4fc2(a0), -$466e(a5)
  0032a6:  60 2a                  bra.b $32d2
  0032a8:  70 06                  moveq #$6, d0
  0032aa:  c1 c7                  muls.w d7, d0
  0032ac:  20 4d                  movea.l a5, a0
  0032ae:  d1 c0                  adda.l d0, a0
  0032b0:  2b 68 aa 94 b9 8e      move.l -$556c(a0), -$4672(a5)
  0032b6:  3b 68 aa 98 b9 92      move.w -$5568(a0), -$466e(a5)
  0032bc:  60 14                  bra.b $32d2
  0032be:  70 06                  moveq #$6, d0
  0032c0:  c1 c7                  muls.w d7, d0
  0032c2:  20 4d                  movea.l a5, a0
  0032c4:  d1 c0                  adda.l d0, a0
  0032c6:  2b 68 b1 30 b9 8e      move.l -$4ed0(a0), -$4672(a5)
  0032cc:  3b 68 b1 34 b9 92      move.w -$4ecc(a0), -$466e(a5)
  0032d2:  2e 1f                  move.l (a7)+, d7
  0032d4:  4e 75                  rts 
  0032d6:  2f 07                  move.l d7, -(a7)
  0032d8:  10 2d b9 90            move.b -$4670(a5), d0
  0032dc:  48 80                  ext.w d0
  0032de:  1e 2d b9 92            move.b -$466e(a5), d7
  0032e2:  48 87                  ext.w d7
  0032e4:  02 47 00 1f            andi.w #$1f, d7
  0032e8:  44 47                  neg.w d7
  0032ea:  de 40                  add.w d0, d7
  0032ec:  4a 2d b9 49            tst.b -$46b7(a5)
  0032f0:  6c 0a                  bge.b $32fc
  0032f2:  70 00                  moveq #$0, d0
  0032f4:  10 2d b9 47            move.b -$46b9(a5), d0
  0032f8:  90 47                  sub.w d7, d0
  0032fa:  60 08                  bra.b $3304
  0032fc:  70 00                  moveq #$0, d0
  0032fe:  10 2d b9 47            move.b -$46b9(a5), d0
  003302:  d0 47                  add.w d7, d0
  003304:  2e 1f                  move.l (a7)+, d7
  003306:  4e 75                  rts 
  003308:  4e 56 00 00            link.w a6, #$0
  00330c:  4a 2d b9 49            tst.b -$46b7(a5)
  003310:  6c 0c                  bge.b $331e
  003312:  70 00                  moveq #$0, d0
  003314:  10 2d b9 47            move.b -$46b9(a5), d0
  003318:  90 6e 00 08            sub.w $8(a6), d0
  00331c:  60 0a                  bra.b $3328
  00331e:  70 00                  moveq #$0, d0
  003320:  10 2d b9 47            move.b -$46b9(a5), d0
  003324:  d0 6e 00 08            add.w $8(a6), d0
  003328:  4e 5e                  unlk a6
  00332a:  4e 75                  rts 
  00332c:  4e 56 00 00            link.w a6, #$0
  003330:  4a 2d ba f1            tst.b -$450f(a5)
  003334:  6c 0a                  bge.b $3340
  003336:  30 2e 00 08            move.w $8(a6), d0
  00333a:  91 6d ba f6            sub.w d0, -$450a(a5)
  00333e:  60 08                  bra.b $3348
  003340:  30 2e 00 08            move.w $8(a6), d0
  003344:  d1 6d ba f6            add.w d0, -$450a(a5)
  003348:  30 2d ba f6            move.w -$450a(a5), d0
  00334c:  4e 5e                  unlk a6
  00334e:  4e 75                  rts 
  003350:  48 e7 01 08            movem.l d7/a4, -(a7)
  003354:  28 6d b9 54            movea.l -$46ac(a5), a4
  003358:  1e 1c                  move.b (a4)+, d7
  00335a:  10 07                  move.b d7, d0
  00335c:  48 80                  ext.w d0
  00335e:  04 40 ff f1            subi.w #$fff1, d0
  003362:  0c 40 00 0e            cmpi.w #$e, d0
  003366:  62 00 01 50            bhi.w $34b8
  00336a:  43 fa 01 5a            lea.l $34c6(pc), a1
  00336e:  d0 40                  add.w d0, d0
  003370:  d2 f1 00 00            adda.w (a1, d0.w), a1
  003374:  4e d1                  jmp (a1)
  003376:  1e 1c                  move.b (a4)+, d7
  003378:  10 07                  move.b d7, d0
  00337a:  48 80                  ext.w d0
  00337c:  3f 00                  move.w d0, -(a7)
  00337e:  4e ba ff 88            jsr $3308(pc)
  003382:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003386:  54 8f                  addq.l #$2, a7
  003388:  60 ce                  bra.b $3358
  00338a:  1e 1c                  move.b (a4)+, d7
  00338c:  df 2d b9 48            add.b d7, -$46b8(a5)
  003390:  60 c6                  bra.b $3358
  003392:  10 2d b9 49            move.b -$46b7(a5), d0
  003396:  46 00                  not.b d0
  003398:  1b 40 b9 49            move.b d0, -$46b7(a5)
  00339c:  60 ba                  bra.b $3358
  00339e:  1e 1c                  move.b (a4)+, d7
  0033a0:  4a 6d ba 30            tst.w -$45d0(a5)
  0033a4:  67 b2                  beq.b $3358
  0033a6:  70 00                  moveq #$0, d0
  0033a8:  10 07                  move.b d7, d0
  0033aa:  20 4d                  movea.l a5, a0
  0033ac:  e5 88                  lsl.l #$2, d0
  0033ae:  d1 c0                  adda.l d0, a0
  0033b0:  28 68 fc e4            movea.l -$31c(a0), a4
  0033b4:  60 a2                  bra.b $3358
  0033b6:  1e 1c                  move.b (a4)+, d7
  0033b8:  70 00                  moveq #$0, d0
  0033ba:  10 07                  move.b d7, d0
  0033bc:  20 4d                  movea.l a5, a0
  0033be:  e5 88                  lsl.l #$2, d0
  0033c0:  d1 c0                  adda.l d0, a0
  0033c2:  28 68 fc e4            movea.l -$31c(a0), a4
  0033c6:  60 90                  bra.b $3358
  0033c8:  53 2d b9 4b            subq.b #$1, -$46b5(a5)
  0033cc:  4e ad 04 62            jsr $462(a5)
  0033d0:  60 86                  bra.b $3358
  0033d2:  4e ba 16 2a            jsr $49fe(pc)
  0033d6:  4e ad 04 62            jsr $462(a5)
  0033da:  60 00 ff 7c            bra.w $3358
  0033de:  1e 1c                  move.b (a4)+, d7
  0033e0:  1b 47 b9 4c            move.b d7, -$46b4(a5)
  0033e4:  60 00 ff 72            bra.w $3358
  0033e8:  1e 1c                  move.b (a4)+, d7
  0033ea:  1b 47 b9 4d            move.b d7, -$46b3(a5)
  0033ee:  1e 1c                  move.b (a4)+, d7
  0033f0:  1b 47 b9 4e            move.b d7, -$46b2(a5)
  0033f4:  60 00 ff 62            bra.w $3358
  0033f8:  3b 7c 00 01 ba 1c      move.w #$1, -$45e4(a5)
  0033fe:  60 00 ff 58            bra.w $3358
  003402:  3b 7c ff ff ba 1c      move.w #$ffff, -$45e4(a5)
  003408:  60 00 ff 4e            bra.w $3358
  00340c:  1e 1c                  move.b (a4)+, d7
  00340e:  10 07                  move.b d7, d0
  003410:  67 22                  beq.b $3434
  003412:  6b 00 ff 44            bmi.w $3358
  003416:  57 00                  subq.b #$3, d0
  003418:  67 38                  beq.b $3452
  00341a:  6a 06                  bpl.b $3422
  00341c:  52 00                  addq.b #$1, d0
  00341e:  6a 1e                  bpl.b $343e
  003420:  60 08                  bra.b $342a
  003422:  55 00                  subq.b #$2, d0
  003424:  6a 00 ff 32            bpl.w $3358
  003428:  60 36                  bra.b $3460
  00342a:  3f 3c 00 17            move.w #$17, -(a7)
  00342e:  4e ba d3 84            jsr $7b4(pc)
  003432:  54 8f                  addq.l #$2, a7
  003434:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  00343a:  60 00 ff 1c            bra.w $3358
  00343e:  3f 3c 00 08            move.w #$8, -(a7)
  003442:  4e ba d3 70            jsr $7b4(pc)
  003446:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  00344c:  54 8f                  addq.l #$2, a7
  00344e:  60 00 ff 08            bra.w $3358
  003452:  3f 3c 00 12            move.w #$12, -(a7)
  003456:  4e ba d3 5c            jsr $7b4(pc)
  00345a:  54 8f                  addq.l #$2, a7
  00345c:  60 00 fe fa            bra.w $3358
  003460:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  003466:  67 00 fe f0            beq.w $3358
  00346a:  0c 6d 00 04 a9 0c      cmpi.w #$4, -$56f4(a5)
  003470:  66 0e                  bne.b $3480
  003472:  3f 3c 00 20            move.w #$20, -(a7)
  003476:  4e ba d3 3c            jsr $7b4(pc)
  00347a:  54 8f                  addq.l #$2, a7
  00347c:  60 00 fe da            bra.w $3358
  003480:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  003486:  67 00 fe d0            beq.w $3358
  00348a:  3f 3c 00 29            move.w #$29, -(a7)
  00348e:  4e ba d3 24            jsr $7b4(pc)
  003492:  54 8f                  addq.l #$2, a7
  003494:  60 00 fe c2            bra.w $3358
  003498:  70 01                  moveq #$1, d0
  00349a:  d0 6d a9 0c            add.w -$56f4(a5), d0
  00349e:  3b 40 ba 38            move.w d0, -$45c8(a5)
  0034a2:  60 00 fe b4            bra.w $3358
  0034a6:  1e 1c                  move.b (a4)+, d7
  0034a8:  0c 07 00 01            cmpi.b #$1, d7
  0034ac:  66 00 fe aa            bne.w $3358
  0034b0:  4e ba 11 0a            jsr $45bc(pc)
  0034b4:  60 00 fe a2            bra.w $3358
  0034b8:  1b 47 b9 46            move.b d7, -$46ba(a5)
  0034bc:  2b 4c b9 54            move.l a4, -$46ac(a5)
  0034c0:  4c df 10 80            movem.l (a7)+, d7/a4
  0034c4:  4e 75                  rts 
  0034c6:  ff d2                  dc.w $ffd2
  0034c8:  ff 46                  dc.w $ff46
  0034ca:  ff e0                  dc.w $ffe0
  0034cc:  ff 3c                  dc.w $ff3c
  0034ce:  ff 32                  dc.w $ff32
  0034d0:  fe 92                  dc.w $fe92
  0034d2:  fe d8                  dc.w $fed8
  0034d4:  ff 22                  dc.w $ff22
  0034d6:  ff 18                  dc.w $ff18
  0034d8:  fe c4                  dc.w $fec4
  0034da:  fe b0                  dc.w $feb0
  0034dc:  ff 0c                  dc.w $ff0c
  0034de:  ff 02                  dc.w $ff02
  0034e0:  fe cc                  dc.w $fecc
  0034e2:  fe f0                  dc.w $fef0
  0034e4:  4e 56 00 00            link.w a6, #$0
  0034e8:  2f 07                  move.l d7, -(a7)
  0034ea:  3e 2e 00 08            move.w $8(a6), d7
  0034ee:  5f 47                  subq.w #$7, d7
  0034f0:  20 4d                  movea.l a5, a0
  0034f2:  d0 c7                  adda.w d7, a0
  0034f4:  1b 68 b7 78 bd 7e      move.b -$4888(a0), -$4282(a5)
  0034fa:  20 4d                  movea.l a5, a0
  0034fc:  d0 c7                  adda.w d7, a0
  0034fe:  10 28 b6 78            move.b -$4988(a0), d0
  003502:  48 80                  ext.w d0
  003504:  2e 1f                  move.l (a7)+, d7
  003506:  4e 5e                  unlk a6
  003508:  4e 75                  rts 
  00350a:  4e 56 00 00            link.w a6, #$0
  00350e:  2f 07                  move.l d7, -(a7)
  003510:  3e 2e 00 08            move.w $8(a6), d7
  003514:  20 4d                  movea.l a5, a0
  003516:  d0 c7                  adda.w d7, a0
  003518:  1b 68 b7 78 bd 7e      move.b -$4888(a0), -$4282(a5)
  00351e:  20 4d                  movea.l a5, a0
  003520:  d0 c7                  adda.w d7, a0
  003522:  10 28 b6 78            move.b -$4988(a0), d0
  003526:  48 80                  ext.w d0
  003528:  2e 1f                  move.l (a7)+, d7
  00352a:  4e 5e                  unlk a6
  00352c:  4e 75                  rts 
  00352e:  4e 56 00 00            link.w a6, #$0
  003532:  2f 07                  move.l d7, -(a7)
  003534:  3e 2e 00 08            move.w $8(a6), d7
  003538:  be 6d b6 76            cmp.w -$498a(a5), d7
  00353c:  6d 04                  blt.b $3542
  00353e:  70 03                  moveq #$3, d0
  003540:  60 20                  bra.b $3562
  003542:  be 6d b6 74            cmp.w -$498c(a5), d7
  003546:  6d 04                  blt.b $354c
  003548:  70 02                  moveq #$2, d0
  00354a:  60 16                  bra.b $3562
  00354c:  be 6d b6 72            cmp.w -$498e(a5), d7
  003550:  6d 04                  blt.b $3556
  003552:  70 01                  moveq #$1, d0
  003554:  60 0c                  bra.b $3562
  003556:  be 6d b6 70            cmp.w -$4990(a5), d7
  00355a:  6d 04                  blt.b $3560
  00355c:  70 00                  moveq #$0, d0
  00355e:  60 02                  bra.b $3562
  003560:  70 ff                  moveq #$ff, d0
  003562:  2e 1f                  move.l (a7)+, d7
  003564:  4e 5e                  unlk a6
  003566:  4e 75                  rts 
  003568:  4e 56 00 00            link.w a6, #$0
  00356c:  70 3c                  moveq #$3c, d0
  00356e:  d0 6e 00 08            add.w $8(a6), d0
  003572:  48 c0                  ext.l d0
  003574:  81 fc 00 3f            divs.w #$3f, d0
  003578:  48 c0                  ext.l d0
  00357a:  81 fc 00 04            divs.w #$4, d0
  00357e:  48 40                  swap d0
  003580:  53 40                  subq.w #$1, d0
  003582:  4e 5e                  unlk a6
  003584:  4e 75                  rts 
  003586:  41 ed b9 46            lea.l -$46ba(a5), a0
  00358a:  43 ed b9 6a            lea.l -$4696(a5), a1
  00358e:  20 d9                  move.l (a1)+, (a0)+
  003590:  20 d9                  move.l (a1)+, (a0)+
  003592:  20 d9                  move.l (a1)+, (a0)+
  003594:  20 d9                  move.l (a1)+, (a0)+
  003596:  30 d9                  move.w (a1)+, (a0)+
  003598:  4e 75                  rts 
  00359a:  41 ed b9 6a            lea.l -$4696(a5), a0
  00359e:  43 ed b9 46            lea.l -$46ba(a5), a1
  0035a2:  20 d9                  move.l (a1)+, (a0)+
  0035a4:  20 d9                  move.l (a1)+, (a0)+
  0035a6:  20 d9                  move.l (a1)+, (a0)+
  0035a8:  20 d9                  move.l (a1)+, (a0)+
  0035aa:  30 d9                  move.w (a1)+, (a0)+
  0035ac:  4e 75                  rts 
  0035ae:  41 ed b9 46            lea.l -$46ba(a5), a0
  0035b2:  43 ed b9 7c            lea.l -$4684(a5), a1
  0035b6:  20 d9                  move.l (a1)+, (a0)+
  0035b8:  20 d9                  move.l (a1)+, (a0)+
  0035ba:  20 d9                  move.l (a1)+, (a0)+
  0035bc:  20 d9                  move.l (a1)+, (a0)+
  0035be:  30 d9                  move.w (a1)+, (a0)+
  0035c0:  4e 75                  rts 
  0035c2:  41 ed b9 7c            lea.l -$4684(a5), a0
  0035c6:  43 ed b9 46            lea.l -$46ba(a5), a1
  0035ca:  20 d9                  move.l (a1)+, (a0)+
  0035cc:  20 d9                  move.l (a1)+, (a0)+
  0035ce:  20 d9                  move.l (a1)+, (a0)+
  0035d0:  20 d9                  move.l (a1)+, (a0)+
  0035d2:  30 d9                  move.w (a1)+, (a0)+
  0035d4:  4e 75                  rts 
  0035d6:  41 ed b9 46            lea.l -$46ba(a5), a0
  0035da:  43 ed b9 6a            lea.l -$4696(a5), a1
  0035de:  20 d9                  move.l (a1)+, (a0)+
  0035e0:  20 d9                  move.l (a1)+, (a0)+
  0035e2:  20 d9                  move.l (a1)+, (a0)+
  0035e4:  20 d9                  move.l (a1)+, (a0)+
  0035e6:  30 d9                  move.w (a1)+, (a0)+
  0035e8:  41 ed b9 58            lea.l -$46a8(a5), a0
  0035ec:  43 ed b9 7c            lea.l -$4684(a5), a1
  0035f0:  20 d9                  move.l (a1)+, (a0)+
  0035f2:  20 d9                  move.l (a1)+, (a0)+
  0035f4:  20 d9                  move.l (a1)+, (a0)+
  0035f6:  20 d9                  move.l (a1)+, (a0)+
  0035f8:  30 d9                  move.w (a1)+, (a0)+
  0035fa:  4e 75                  rts 
  0035fc:  41 ed b9 6a            lea.l -$4696(a5), a0
  003600:  43 ed b9 46            lea.l -$46ba(a5), a1
  003604:  20 d9                  move.l (a1)+, (a0)+
  003606:  20 d9                  move.l (a1)+, (a0)+
  003608:  20 d9                  move.l (a1)+, (a0)+
  00360a:  20 d9                  move.l (a1)+, (a0)+
  00360c:  30 d9                  move.w (a1)+, (a0)+
  00360e:  41 ed b9 7c            lea.l -$4684(a5), a0
  003612:  43 ed b9 58            lea.l -$46a8(a5), a1
  003616:  20 d9                  move.l (a1)+, (a0)+
  003618:  20 d9                  move.l (a1)+, (a0)+
  00361a:  20 d9                  move.l (a1)+, (a0)+
  00361c:  20 d9                  move.l (a1)+, (a0)+
  00361e:  30 d9                  move.w (a1)+, (a0)+
  003620:  4e 75                  rts 
  003622:  41 ed b9 46            lea.l -$46ba(a5), a0
  003626:  43 ed b9 7c            lea.l -$4684(a5), a1
  00362a:  20 d9                  move.l (a1)+, (a0)+
  00362c:  20 d9                  move.l (a1)+, (a0)+
  00362e:  20 d9                  move.l (a1)+, (a0)+
  003630:  20 d9                  move.l (a1)+, (a0)+
  003632:  30 d9                  move.w (a1)+, (a0)+
  003634:  41 ed b9 58            lea.l -$46a8(a5), a0
  003638:  43 ed b9 6a            lea.l -$4696(a5), a1
  00363c:  20 d9                  move.l (a1)+, (a0)+
  00363e:  20 d9                  move.l (a1)+, (a0)+
  003640:  20 d9                  move.l (a1)+, (a0)+
  003642:  20 d9                  move.l (a1)+, (a0)+
  003644:  30 d9                  move.w (a1)+, (a0)+
  003646:  4e 75                  rts 
  003648:  41 ed b9 7c            lea.l -$4684(a5), a0
  00364c:  43 ed b9 46            lea.l -$46ba(a5), a1
  003650:  20 d9                  move.l (a1)+, (a0)+
  003652:  20 d9                  move.l (a1)+, (a0)+
  003654:  20 d9                  move.l (a1)+, (a0)+
  003656:  20 d9                  move.l (a1)+, (a0)+
  003658:  30 d9                  move.w (a1)+, (a0)+
  00365a:  41 ed b9 6a            lea.l -$4696(a5), a0
  00365e:  43 ed b9 58            lea.l -$46a8(a5), a1
  003662:  20 d9                  move.l (a1)+, (a0)+
  003664:  20 d9                  move.l (a1)+, (a0)+
  003666:  20 d9                  move.l (a1)+, (a0)+
  003668:  20 d9                  move.l (a1)+, (a0)+
  00366a:  30 d9                  move.w (a1)+, (a0)+
  00366c:  4e 75                  rts 
  00366e:  30 2d a5 cc            move.w -$5a34(a5), d0
  003672:  3b 40 ba fe            move.w d0, -$4502(a5)
  003676:  3b 40 bd 76            move.w d0, -$428a(a5)
  00367a:  3b 40 bd 74            move.w d0, -$428c(a5)
  00367e:  3b 6d a5 d0 bb 00      move.w -$5a30(a5), -$4500(a5)
  003684:  3b 6d a5 ce bb 02      move.w -$5a32(a5), -$44fe(a5)
  00368a:  32 2d a5 d2            move.w -$5a2e(a5), d1
  00368e:  3b 41 bb 04            move.w d1, -$44fc(a5)
  003692:  3b 41 bd 78            move.w d1, -$4288(a5)
  003696:  42 2d aa 36            clr.b -$55ca(a5)
  00369a:  42 2d aa 35            clr.b -$55cb(a5)
  00369e:  4e 75                  rts 
  0036a0:  0c 2d 00 04 b9 4c      cmpi.b #$4, -$46b4(a5)
  0036a6:  66 2c                  bne.b $36d4
  0036a8:  4a 6d ba 30            tst.w -$45d0(a5)
  0036ac:  67 14                  beq.b $36c2
  0036ae:  52 2d b9 4e            addq.b #$1, -$46b2(a5)
  0036b2:  0c 2d 00 04 b9 4e      cmpi.b #$4, -$46b2(a5)
  0036b8:  6f 1a                  ble.b $36d4
  0036ba:  1b 7c 00 04 b9 4e      move.b #$4, -$46b2(a5)
  0036c0:  60 12                  bra.b $36d4
  0036c2:  56 2d b9 4e            addq.b #$3, -$46b2(a5)
  0036c6:  0c 2d 00 21 b9 4e      cmpi.b #$21, -$46b2(a5)
  0036cc:  6f 06                  ble.b $36d4
  0036ce:  1b 7c 00 21 b9 4e      move.b #$21, -$46b2(a5)
  0036d4:  4e 75                  rts 
  0036d6:  10 2d b9 4e            move.b -$46b2(a5), d0
  0036da:  d1 2d b9 48            add.b d0, -$46b8(a5)
  0036de:  0c 2d 00 04 b9 4c      cmpi.b #$4, -$46b4(a5)
  0036e4:  66 16                  bne.b $36fc
  0036e6:  10 2d b9 4d            move.b -$46b3(a5), d0
  0036ea:  48 80                  ext.w d0
  0036ec:  3f 00                  move.w d0, -(a7)
  0036ee:  4e ba fc 18            jsr $3308(pc)
  0036f2:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0036f6:  4e ba fa da            jsr $31d2(pc)
  0036fa:  54 8f                  addq.l #$2, a7
  0036fc:  4e 75                  rts 
  0036fe:  48 e7 03 00            movem.l d6-d7, -(a7)
  003702:  1e 2d b9 4c            move.b -$46b4(a5), d7
  003706:  48 87                  ext.w d7
  003708:  7c 00                  moveq #$0, d6
  00370a:  1c 2d b9 46            move.b -$46ba(a5), d6
  00370e:  0c 47 00 06            cmpi.w #$6, d7
  003712:  67 40                  beq.b $3754
  003714:  0c 47 00 05            cmpi.w #$5, d7
  003718:  66 0c                  bne.b $3726
  00371a:  0c 46 00 6d            cmpi.w #$6d, d6
  00371e:  66 34                  bne.b $3754
  003720:  4e ba 02 26            jsr $3948(pc)
  003724:  60 2e                  bra.b $3754
  003726:  0c 47 00 04            cmpi.w #$4, d7
  00372a:  66 06                  bne.b $3732
  00372c:  4e ad 05 2a            jsr $52a(a5)
  003730:  60 22                  bra.b $3754
  003732:  0c 47 00 03            cmpi.w #$3, d7
  003736:  66 12                  bne.b $374a
  003738:  0c 46 00 66            cmpi.w #$66, d6
  00373c:  6d 16                  blt.b $3754
  00373e:  0c 46 00 6a            cmpi.w #$6a, d6
  003742:  6c 10                  bge.b $3754
  003744:  4e ba 03 ea            jsr $3b30(pc)
  003748:  60 0a                  bra.b $3754
  00374a:  0c 47 00 02            cmpi.w #$2, d7
  00374e:  67 04                  beq.b $3754
  003750:  4e ba 01 f6            jsr $3948(pc)
  003754:  4c df 00 c0            movem.l (a7)+, d6-d7
  003758:  4e 75                  rts 
  00375a:  4e 56 00 00            link.w a6, #$0
  00375e:  2f 07                  move.l d7, -(a7)
  003760:  3e 2e 00 08            move.w $8(a6), d7
  003764:  4a 47                  tst.w d7
  003766:  67 2a                  beq.b $3792
  003768:  0c 47 00 09            cmpi.w #$9, d7
  00376c:  67 24                  beq.b $3792
  00376e:  0c 47 00 0c            cmpi.w #$c, d7
  003772:  67 1e                  beq.b $3792
  003774:  0c 47 00 14            cmpi.w #$14, d7
  003778:  67 18                  beq.b $3792
  00377a:  0c 47 00 1a            cmpi.w #$1a, d7
  00377e:  67 12                  beq.b $3792
  003780:  0c 47 00 1b            cmpi.w #$1b, d7
  003784:  67 0c                  beq.b $3792
  003786:  0c 47 00 1c            cmpi.w #$1c, d7
  00378a:  67 06                  beq.b $3792
  00378c:  0c 47 00 1d            cmpi.w #$1d, d7
  003790:  66 04                  bne.b $3796
  003792:  70 00                  moveq #$0, d0
  003794:  60 02                  bra.b $3798
  003796:  70 01                  moveq #$1, d0
  003798:  2e 1f                  move.l (a7)+, d7
  00379a:  4e 5e                  unlk a6
  00379c:  4e 75                  rts 
  00379e:  48 e7 03 00            movem.l d6-d7, -(a7)
  0037a2:  7e 00                  moveq #$0, d7
  0037a4:  1e 2d b9 46            move.b -$46ba(a5), d7
  0037a8:  10 2d b9 4b            move.b -$46b5(a5), d0
  0037ac:  48 80                  ext.w d0
  0037ae:  3f 00                  move.w d0, -(a7)
  0037b0:  10 2d b9 4a            move.b -$46b6(a5), d0
  0037b4:  48 80                  ext.w d0
  0037b6:  3f 00                  move.w d0, -(a7)
  0037b8:  10 2d b9 4f            move.b -$46b1(a5), d0
  0037bc:  48 80                  ext.w d0
  0037be:  3f 00                  move.w d0, -(a7)
  0037c0:  4e ba f8 b6            jsr $3078(pc)
  0037c4:  72 00                  moveq #$0, d1
  0037c6:  12 00                  move.b d0, d1
  0037c8:  55 41                  subq.w #$2, d1
  0037ca:  5c 8f                  addq.l #$6, a7
  0037cc:  66 38                  bne.b $3806
  0037ce:  4e ad 04 82            jsr $482(a5)
  0037d2:  3c 00                  move.w d0, d6
  0037d4:  0c 46 00 02            cmpi.w #$2, d6
  0037d8:  6d 18                  blt.b $37f2
  0037da:  0c 47 00 07            cmpi.w #$7, d7
  0037de:  6d 06                  blt.b $37e6
  0037e0:  0c 47 00 0f            cmpi.w #$f, d7
  0037e4:  6d 1c                  blt.b $3802
  0037e6:  0c 47 00 22            cmpi.w #$22, d7
  0037ea:  6d 06                  blt.b $37f2
  0037ec:  0c 47 00 28            cmpi.w #$28, d7
  0037f0:  6d 10                  blt.b $3802
  0037f2:  0c 47 00 2b            cmpi.w #$2b, d7
  0037f6:  67 06                  beq.b $37fe
  0037f8:  0c 47 00 1a            cmpi.w #$1a, d7
  0037fc:  66 08                  bne.b $3806
  0037fe:  4a 46                  tst.w d6
  003800:  67 04                  beq.b $3806
  003802:  4e ad 05 32            jsr $532(a5)
  003806:  4c df 00 c0            movem.l (a7)+, d6-d7
  00380a:  4e 75                  rts 
  00380c:  4e 56 00 00            link.w a6, #$0
  003810:  2f 07                  move.l d7, -(a7)
  003812:  3e 2e 00 08            move.w $8(a6), d7
  003816:  4a 2d b9 51            tst.b -$46af(a5)
  00381a:  66 24                  bne.b $3840
  00381c:  be 6d ba 4a            cmp.w -$45b6(a5), d7
  003820:  6d 12                  blt.b $3834
  003822:  30 2d ba 4a            move.w -$45b6(a5), d0
  003826:  44 40                  neg.w d0
  003828:  3b 40 ba 50            move.w d0, -$45b0(a5)
  00382c:  52 6d 96 d6            addq.w #$1, -$692a(a5)
  003830:  70 01                  moveq #$1, d0
  003832:  60 2e                  bra.b $3862
  003834:  32 07                  move.w d7, d1
  003836:  44 41                  neg.w d1
  003838:  3b 41 ba 50            move.w d1, -$45b0(a5)
  00383c:  70 00                  moveq #$0, d0
  00383e:  60 22                  bra.b $3862
  003840:  be 6d ba 4c            cmp.w -$45b4(a5), d7
  003844:  6d 12                  blt.b $3858
  003846:  30 2d ba 4c            move.w -$45b4(a5), d0
  00384a:  44 40                  neg.w d0
  00384c:  3b 40 ba 52            move.w d0, -$45ae(a5)
  003850:  52 6d 96 d4            addq.w #$1, -$692c(a5)
  003854:  70 01                  moveq #$1, d0
  003856:  60 0a                  bra.b $3862
  003858:  32 07                  move.w d7, d1
  00385a:  44 41                  neg.w d1
  00385c:  3b 41 ba 52            move.w d1, -$45ae(a5)
  003860:  70 00                  moveq #$0, d0
  003862:  2e 1f                  move.l (a7)+, d7
  003864:  4e 5e                  unlk a6
  003866:  4e 75                  rts 
  003868:  10 2d b9 4b            move.b -$46b5(a5), d0
  00386c:  48 80                  ext.w d0
  00386e:  3f 00                  move.w d0, -(a7)
  003870:  10 2d b9 4a            move.b -$46b6(a5), d0
  003874:  48 80                  ext.w d0
  003876:  3f 00                  move.w d0, -(a7)
  003878:  10 2d b9 4f            move.b -$46b1(a5), d0
  00387c:  48 80                  ext.w d0
  00387e:  3f 00                  move.w d0, -(a7)
  003880:  4e ba f7 f6            jsr $3078(pc)
  003884:  5c 8f                  addq.l #$6, a7
  003886:  4e 75                  rts 
  003888:  3b 6d ba fa ba d6      move.w -$4506(a5), -$452a(a5)
  00388e:  3b 6d ba fc ba d4      move.w -$4504(a5), -$452c(a5)
  003894:  30 2d ba f6            move.w -$450a(a5), d0
  003898:  48 c0                  ext.l d0
  00389a:  81 fc 00 02            divs.w #$2, d0
  00389e:  06 40 00 3a            addi.w #$3a, d0
  0038a2:  3b 40 ba dc            move.w d0, -$4524(a5)
  0038a6:  4a 2d b9 49            tst.b -$46b7(a5)
  0038aa:  6d 08                  blt.b $38b4
  0038ac:  30 2d ba d6            move.w -$452a(a5), d0
  0038b0:  91 6d ba dc            sub.w d0, -$4524(a5)
  0038b4:  3b 6d ba dc ba d8      move.w -$4524(a5), -$4528(a5)
  0038ba:  30 2d ba dc            move.w -$4524(a5), d0
  0038be:  d0 6d ba d6            add.w -$452a(a5), d0
  0038c2:  3b 40 ba de            move.w d0, -$4522(a5)
  0038c6:  3b 40 ba da            move.w d0, -$4526(a5)
  0038ca:  32 2d ba f8            move.w -$4508(a5), d1
  0038ce:  92 6d ba d4            sub.w -$452c(a5), d1
  0038d2:  52 41                  addq.w #$1, d1
  0038d4:  3b 41 ba e0            move.w d1, -$4520(a5)
  0038d8:  0c 41 00 c0            cmpi.w #$c0, d1
  0038dc:  6d 04                  blt.b $38e2
  0038de:  42 6d ba e0            clr.w -$4520(a5)
  0038e2:  3f 2d ba e0            move.w -$4520(a5), -(a7)
  0038e6:  4e ba fc 80            jsr $3568(pc)
  0038ea:  3b 40 ba ca            move.w d0, -$4536(a5)
  0038ee:  3e ad ba f8            move.w -$4508(a5), (a7)
  0038f2:  4e ba fc 74            jsr $3568(pc)
  0038f6:  3b 40 ba cc            move.w d0, -$4534(a5)
  0038fa:  4a 40                  tst.w d0
  0038fc:  54 8f                  addq.l #$2, a7
  0038fe:  6c 06                  bge.b $3906
  003900:  3b 7c 00 03 ba cc      move.w #$3, -$4534(a5)
  003906:  3f 2d ba dc            move.w -$4524(a5), -(a7)
  00390a:  4e ba fb fe            jsr $350a(pc)
  00390e:  3b 40 ba c6            move.w d0, -$453a(a5)
  003912:  4a 40                  tst.w d0
  003914:  54 8f                  addq.l #$2, a7
  003916:  6c 04                  bge.b $391c
  003918:  42 6d ba c6            clr.w -$453a(a5)
  00391c:  3f 2d ba de            move.w -$4522(a5), -(a7)
  003920:  4e ba fb e8            jsr $350a(pc)
  003924:  3b 40 ba c8            move.w d0, -$4538(a5)
  003928:  0c 40 00 0a            cmpi.w #$a, d0
  00392c:  54 8f                  addq.l #$2, a7
  00392e:  6d 06                  blt.b $3936
  003930:  3b 7c 00 09 ba c8      move.w #$9, -$4538(a5)
  003936:  08 2d 00 05 b9 92      btst.b #$5, -$466e(a5)
  00393c:  67 08                  beq.b $3946
  00393e:  58 6d ba d8            addq.w #$4, -$4528(a5)
  003942:  59 6d ba da            subq.w #$4, -$4526(a5)
  003946:  4e 75                  rts 
  003948:  08 2d 00 06 b9 92      btst.b #$6, -$466e(a5)
  00394e:  67 00 00 86            beq.w $39d6
  003952:  4e ba ff 14            jsr $3868(pc)
  003956:  72 00                  moveq #$0, d1
  003958:  12 00                  move.b d0, d1
  00395a:  0c 41 00 14            cmpi.w #$14, d1
  00395e:  66 04                  bne.b $3964
  003960:  4e ba 02 86            jsr $3be8(pc)
  003964:  70 00                  moveq #$0, d0
  003966:  10 2d ba e8            move.b -$4518(a5), d0
  00396a:  3f 00                  move.w d0, -(a7)
  00396c:  4e ba fd ec            jsr $375a(pc)
  003970:  4a 00                  tst.b d0
  003972:  54 8f                  addq.l #$2, a7
  003974:  66 60                  bne.b $39d6
  003976:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  00397c:  66 54                  bne.b $39d2
  00397e:  4a 6d ba 8e            tst.w -$4572(a5)
  003982:  6c 4e                  bge.b $39d2
  003984:  4a 2d b9 4b            tst.b -$46b5(a5)
  003988:  66 48                  bne.b $39d2
  00398a:  0c 2d 00 02 b9 4f      cmpi.b #$2, -$46b1(a5)
  003990:  67 10                  beq.b $39a2
  003992:  0c 2d 00 0d b9 4f      cmpi.b #$d, -$46b1(a5)
  003998:  66 38                  bne.b $39d2
  00399a:  0c 6d 00 06 ba ec      cmpi.w #$6, -$4514(a5)
  0039a0:  6d 30                  blt.b $39d2
  0039a2:  70 00                  moveq #$0, d0
  0039a4:  10 2d ba e9            move.b -$4517(a5), d0
  0039a8:  d0 ad bd 82            add.l -$427e(a5), d0
  0039ac:  20 40                  movea.l d0, a0
  0039ae:  10 bc 00 01            move.b #$1, (a0)
  0039b2:  70 00                  moveq #$0, d0
  0039b4:  10 2d ba e9            move.b -$4517(a5), d0
  0039b8:  3f 00                  move.w d0, -(a7)
  0039ba:  4e ad 04 12            jsr $412(a5)
  0039be:  52 2d ba e9            addq.b #$1, -$4517(a5)
  0039c2:  70 00                  moveq #$0, d0
  0039c4:  10 2d ba e9            move.b -$4517(a5), d0
  0039c8:  3e 80                  move.w d0, (a7)
  0039ca:  4e ad 04 12            jsr $412(a5)
  0039ce:  54 8f                  addq.l #$2, a7
  0039d0:  60 04                  bra.b $39d6
  0039d2:  4e ba 00 04            jsr $39d8(pc)
  0039d6:  4e 75                  rts 
  0039d8:  2f 07                  move.l d7, -(a7)
  0039da:  7e 00                  moveq #$0, d7
  0039dc:  1e 2d b9 46            move.b -$46ba(a5), d7
  0039e0:  42 2d b9 52            clr.b -$46ae(a5)
  0039e4:  4e ba 10 18            jsr $49fe(pc)
  0039e8:  4e ad 04 62            jsr $462(a5)
  0039ec:  1b 47 ba bc            move.b d7, -$4544(a5)
  0039f0:  0c 2d 00 09 ba bc      cmpi.b #$9, -$4544(a5)
  0039f6:  66 06                  bne.b $39fe
  0039f8:  7e 07                  moveq #$7, d7
  0039fa:  60 00 00 cc            bra.w $3ac8
  0039fe:  0c 47 00 0d            cmpi.w #$d, d7
  003a02:  66 06                  bne.b $3a0a
  003a04:  7e 13                  moveq #$13, d7
  003a06:  60 00 00 c0            bra.w $3ac8
  003a0a:  0c 47 00 1a            cmpi.w #$1a, d7
  003a0e:  66 06                  bne.b $3a16
  003a10:  7e 12                  moveq #$12, d7
  003a12:  60 00 00 b4            bra.w $3ac8
  003a16:  0c 47 00 2c            cmpi.w #$2c, d7
  003a1a:  66 06                  bne.b $3a22
  003a1c:  7e 15                  moveq #$15, d7
  003a1e:  60 00 00 a8            bra.w $3ac8
  003a22:  0c 47 00 51            cmpi.w #$51, d7
  003a26:  6d 1e                  blt.b $3a46
  003a28:  0c 47 00 56            cmpi.w #$56, d7
  003a2c:  6c 18                  bge.b $3a46
  003a2e:  7e 13                  moveq #$13, d7
  003a30:  3f 3c 00 05            move.w #$5, -(a7)
  003a34:  4e ba f8 d2            jsr $3308(pc)
  003a38:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003a3c:  4e ba f7 94            jsr $31d2(pc)
  003a40:  54 8f                  addq.l #$2, a7
  003a42:  60 00 00 84            bra.w $3ac8
  003a46:  0c 47 00 96            cmpi.w #$96, d7
  003a4a:  6d 7a                  blt.b $3ac6
  003a4c:  0c 47 00 b4            cmpi.w #$b4, d7
  003a50:  6c 74                  bge.b $3ac6
  003a52:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  003a58:  66 46                  bne.b $3aa0
  003a5a:  0c 2d 00 03 b9 4b      cmpi.b #$3, -$46b5(a5)
  003a60:  66 10                  bne.b $3a72
  003a62:  0c 2d 00 0a b9 4a      cmpi.b #$a, -$46b6(a5)
  003a68:  66 08                  bne.b $3a72
  003a6a:  4e ba 0d 40            jsr $47ac(pc)
  003a6e:  60 00 00 bc            bra.w $3b2c
  003a72:  4a 2d b9 4d            tst.b -$46b3(a5)
  003a76:  6c 20                  bge.b $3a98
  003a78:  7e 52                  moveq #$52, d7
  003a7a:  4a 2d b9 49            tst.b -$46b7(a5)
  003a7e:  6c 48                  bge.b $3ac8
  003a80:  4e ba 02 42            jsr $3cc4(pc)
  003a84:  5f 40                  subq.w #$7, d0
  003a86:  6e 40                  bgt.b $3ac8
  003a88:  3f 3c ff fb            move.w #$fffb, -(a7)
  003a8c:  4e ba f8 7a            jsr $3308(pc)
  003a90:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003a94:  54 8f                  addq.l #$2, a7
  003a96:  60 30                  bra.b $3ac8
  003a98:  42 6d ba 34            clr.w -$45cc(a5)
  003a9c:  7e 53                  moveq #$53, d7
  003a9e:  60 28                  bra.b $3ac8
  003aa0:  3b 7c 00 01 ba 34      move.w #$1, -$45cc(a5)
  003aa6:  4a 2d b9 49            tst.b -$46b7(a5)
  003aaa:  6c 16                  bge.b $3ac2
  003aac:  4e ba 02 16            jsr $3cc4(pc)
  003ab0:  5f 40                  subq.w #$7, d0
  003ab2:  6e 0e                  bgt.b $3ac2
  003ab4:  3f 3c ff fb            move.w #$fffb, -(a7)
  003ab8:  4e ba f8 4e            jsr $3308(pc)
  003abc:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003ac0:  54 8f                  addq.l #$2, a7
  003ac2:  7e 51                  moveq #$51, d7
  003ac4:  60 02                  bra.b $3ac8
  003ac6:  7e 07                  moveq #$7, d7
  003ac8:  3f 07                  move.w d7, -(a7)
  003aca:  4e ad 05 22            jsr $522(a5)
  003ace:  4e ba f8 80            jsr $3350(pc)
  003ad2:  4e ba f6 fe            jsr $31d2(pc)
  003ad6:  4e ba fd 90            jsr $3868(pc)
  003ada:  72 00                  moveq #$0, d1
  003adc:  12 00                  move.b d0, d1
  003ade:  0c 41 00 14            cmpi.w #$14, d1
  003ae2:  54 8f                  addq.l #$2, a7
  003ae4:  66 06                  bne.b $3aec
  003ae6:  4e ba 01 00            jsr $3be8(pc)
  003aea:  60 40                  bra.b $3b2c
  003aec:  4e ba 01 36            jsr $3c24(pc)
  003af0:  72 00                  moveq #$0, d1
  003af2:  12 00                  move.b d0, d1
  003af4:  0c 41 00 14            cmpi.w #$14, d1
  003af8:  66 32                  bne.b $3b2c
  003afa:  0c 2d 00 2c ba bc      cmpi.b #$2c, -$4544(a5)
  003b00:  66 08                  bne.b $3b0a
  003b02:  4e ba 01 c0            jsr $3cc4(pc)
  003b06:  5d 40                  subq.w #$6, d0
  003b08:  6d 10                  blt.b $3b1a
  003b0a:  3f 3c ff ff            move.w #$ffff, -(a7)
  003b0e:  4e ba f7 f8            jsr $3308(pc)
  003b12:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003b16:  54 8f                  addq.l #$2, a7
  003b18:  60 0e                  bra.b $3b28
  003b1a:  3f 3c 00 68            move.w #$68, -(a7)
  003b1e:  4e ad 05 22            jsr $522(a5)
  003b22:  4e ba f8 2c            jsr $3350(pc)
  003b26:  54 8f                  addq.l #$2, a7
  003b28:  4e ba f6 a8            jsr $31d2(pc)
  003b2c:  2e 1f                  move.l (a7)+, d7
  003b2e:  4e 75                  rts 
  003b30:  2f 07                  move.l d7, -(a7)
  003b32:  7e 00                  moveq #$0, d7
  003b34:  1e 2d b9 48            move.b -$46b8(a5), d7
  003b38:  4a 2d ba bb            tst.b -$4545(a5)
  003b3c:  6c 00 00 94            bge.w $3bd2
  003b40:  0c 2d 00 20 b9 4e      cmpi.b #$20, -$46b2(a5)
  003b46:  6c 00 00 8a            bge.w $3bd2
  003b4a:  4a 2d b9 53            tst.b -$46ad(a5)
  003b4e:  6c 00 00 82            bge.w $3bd2
  003b52:  10 2d b9 4b            move.b -$46b5(a5), d0
  003b56:  48 80                  ext.w d0
  003b58:  20 4d                  movea.l a5, a0
  003b5a:  d0 c0                  adda.w d0, a0
  003b5c:  d0 c0                  adda.w d0, a0
  003b5e:  70 19                  moveq #$19, d0
  003b60:  d0 47                  add.w d7, d0
  003b62:  b0 68 b6 70            cmp.w -$4990(a0), d0
  003b66:  6d 6a                  blt.b $3bd2
  003b68:  7e 00                  moveq #$0, d7
  003b6a:  1e 2d b9 47            move.b -$46b9(a5), d7
  003b6e:  3f 3c ff f8            move.w #$fff8, -(a7)
  003b72:  4e ba f7 94            jsr $3308(pc)
  003b76:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003b7a:  4e ba f6 56            jsr $31d2(pc)
  003b7e:  4e ba 00 56            jsr $3bd6(pc)
  003b82:  4a 40                  tst.w d0
  003b84:  54 8f                  addq.l #$2, a7
  003b86:  66 06                  bne.b $3b8e
  003b88:  1b 47 b9 47            move.b d7, -$46b9(a5)
  003b8c:  60 44                  bra.b $3bd2
  003b8e:  4e ba 01 34            jsr $3cc4(pc)
  003b92:  3f 00                  move.w d0, -(a7)
  003b94:  4e ba f7 72            jsr $3308(pc)
  003b98:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003b9c:  10 2d b9 4b            move.b -$46b5(a5), d0
  003ba0:  48 80                  ext.w d0
  003ba2:  20 4d                  movea.l a5, a0
  003ba4:  d0 c0                  adda.w d0, a0
  003ba6:  d0 c0                  adda.w d0, a0
  003ba8:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  003bae:  42 2d b9 4e            clr.b -$46b2(a5)
  003bb2:  3e bc 00 0f            move.w #$f, (a7)
  003bb6:  4e ad 05 22            jsr $522(a5)
  003bba:  4e ba f7 94            jsr $3350(pc)
  003bbe:  3b 7c 00 0c ba 54      move.w #$c, -$45ac(a5)
  003bc4:  3e bc 00 09            move.w #$9, (a7)
  003bc8:  4e ba cb ea            jsr $7b4(pc)
  003bcc:  42 6d ba 58            clr.w -$45a8(a5)
  003bd0:  54 8f                  addq.l #$2, a7
  003bd2:  2e 1f                  move.l (a7)+, d7
  003bd4:  4e 75                  rts 
  003bd6:  4e ba 05 08            jsr $40e0(pc)
  003bda:  1b 40 ba bd            move.b d0, -$4543(a5)
  003bde:  4e ba 05 5e            jsr $413e(pc)
  003be2:  4e ba 04 34            jsr $4018(pc)
  003be6:  4e 75                  rts 
  003be8:  2f 07                  move.l d7, -(a7)
  003bea:  4e ba 00 d8            jsr $3cc4(pc)
  003bee:  3e 00                  move.w d0, d7
  003bf0:  0c 47 00 08            cmpi.w #$8, d7
  003bf4:  6c 0e                  bge.b $3c04
  003bf6:  4e ba 00 2c            jsr $3c24(pc)
  003bfa:  72 00                  moveq #$0, d1
  003bfc:  12 00                  move.b d0, d1
  003bfe:  0c 41 00 14            cmpi.w #$14, d1
  003c02:  66 06                  bne.b $3c0a
  003c04:  5d 47                  subq.w #$6, d7
  003c06:  44 47                  neg.w d7
  003c08:  60 02                  bra.b $3c0c
  003c0a:  58 47                  addq.w #$4, d7
  003c0c:  3f 07                  move.w d7, -(a7)
  003c0e:  4e ba f6 f8            jsr $3308(pc)
  003c12:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003c16:  4e ba f5 ba            jsr $31d2(pc)
  003c1a:  4e ba fc 4c            jsr $3868(pc)
  003c1e:  54 8f                  addq.l #$2, a7
  003c20:  2e 1f                  move.l (a7)+, d7
  003c22:  4e 75                  rts 
  003c24:  10 2d b9 49            move.b -$46b7(a5), d0
  003c28:  48 80                  ext.w d0
  003c2a:  20 4d                  movea.l a5, a0
  003c2c:  d0 c0                  adda.w d0, a0
  003c2e:  10 28 b6 61            move.b -$499f(a0), d0
  003c32:  d0 2d b9 4a            add.b -$46b6(a5), d0
  003c36:  1b 40 ba e4            move.b d0, -$451c(a5)
  003c3a:  12 2d b9 4b            move.b -$46b5(a5), d1
  003c3e:  48 81                  ext.w d1
  003c40:  3f 01                  move.w d1, -(a7)
  003c42:  48 80                  ext.w d0
  003c44:  3f 00                  move.w d0, -(a7)
  003c46:  10 2d b9 4f            move.b -$46b1(a5), d0
  003c4a:  48 80                  ext.w d0
  003c4c:  3f 00                  move.w d0, -(a7)
  003c4e:  4e ba f4 28            jsr $3078(pc)
  003c52:  5c 8f                  addq.l #$6, a7
  003c54:  4e 75                  rts 
  003c56:  2f 07                  move.l d7, -(a7)
  003c58:  10 2d b9 49            move.b -$46b7(a5), d0
  003c5c:  48 80                  ext.w d0
  003c5e:  20 4d                  movea.l a5, a0
  003c60:  d0 c0                  adda.w d0, a0
  003c62:  1e 28 b6 61            move.b -$499f(a0), d7
  003c66:  48 87                  ext.w d7
  003c68:  10 2d b9 4a            move.b -$46b6(a5), d0
  003c6c:  d0 07                  add.b d7, d0
  003c6e:  d0 07                  add.b d7, d0
  003c70:  1b 40 ba e4            move.b d0, -$451c(a5)
  003c74:  12 2d b9 4b            move.b -$46b5(a5), d1
  003c78:  48 81                  ext.w d1
  003c7a:  3f 01                  move.w d1, -(a7)
  003c7c:  48 80                  ext.w d0
  003c7e:  3f 00                  move.w d0, -(a7)
  003c80:  10 2d b9 4f            move.b -$46b1(a5), d0
  003c84:  48 80                  ext.w d0
  003c86:  3f 00                  move.w d0, -(a7)
  003c88:  4e ba f3 ee            jsr $3078(pc)
  003c8c:  5c 8f                  addq.l #$6, a7
  003c8e:  2e 1f                  move.l (a7)+, d7
  003c90:  4e 75                  rts 
  003c92:  10 2d b9 49            move.b -$46b7(a5), d0
  003c96:  48 80                  ext.w d0
  003c98:  20 4d                  movea.l a5, a0
  003c9a:  d0 c0                  adda.w d0, a0
  003c9c:  10 28 b6 63            move.b -$499d(a0), d0
  003ca0:  d0 2d b9 4a            add.b -$46b6(a5), d0
  003ca4:  1b 40 ba e5            move.b d0, -$451b(a5)
  003ca8:  12 2d b9 4b            move.b -$46b5(a5), d1
  003cac:  48 81                  ext.w d1
  003cae:  3f 01                  move.w d1, -(a7)
  003cb0:  48 80                  ext.w d0
  003cb2:  3f 00                  move.w d0, -(a7)
  003cb4:  10 2d b9 4f            move.b -$46b1(a5), d0
  003cb8:  48 80                  ext.w d0
  003cba:  3f 00                  move.w d0, -(a7)
  003cbc:  4e ba f3 ba            jsr $3078(pc)
  003cc0:  5c 8f                  addq.l #$6, a7
  003cc2:  4e 75                  rts 
  003cc4:  4e ba f6 10            jsr $32d6(pc)
  003cc8:  3f 00                  move.w d0, -(a7)
  003cca:  4e ba 00 06            jsr $3cd2(pc)
  003cce:  54 8f                  addq.l #$2, a7
  003cd0:  4e 75                  rts 
  003cd2:  4e 56 00 00            link.w a6, #$0
  003cd6:  3f 2e 00 08            move.w $8(a6), -(a7)
  003cda:  4e ba f8 08            jsr $34e4(pc)
  003cde:  4a 2d b9 49            tst.b -$46b7(a5)
  003ce2:  54 8f                  addq.l #$2, a7
  003ce4:  66 0e                  bne.b $3cf4
  003ce6:  70 00                  moveq #$0, d0
  003ce8:  10 2d bd 7e            move.b -$4282(a5), d0
  003cec:  72 0d                  moveq #$d, d1
  003cee:  92 40                  sub.w d0, d1
  003cf0:  30 01                  move.w d1, d0
  003cf2:  60 06                  bra.b $3cfa
  003cf4:  70 00                  moveq #$0, d0
  003cf6:  10 2d bd 7e            move.b -$4282(a5), d0
  003cfa:  4e 5e                  unlk a6
  003cfc:  4e 75                  rts 
  003cfe:  4a 2d b9 53            tst.b -$46ad(a5)
  003d02:  6c 22                  bge.b $3d26
  003d04:  4a 2d b9 4f            tst.b -$46b1(a5)
  003d08:  66 1c                  bne.b $3d26
  003d0a:  3f 3c 00 64            move.w #$64, -(a7)
  003d0e:  4e ba fa fc            jsr $380c(pc)
  003d12:  42 2d b9 53            clr.b -$46ad(a5)
  003d16:  3e bc 00 01            move.w #$1, (a7)
  003d1a:  4e ad 05 1a            jsr $51a(a5)
  003d1e:  1b 7c 00 b9 b9 46      move.b #$b9, -$46ba(a5)
  003d24:  54 8f                  addq.l #$2, a7
  003d26:  4e 75                  rts 
  003d28:  4e ba ff d4            jsr $3cfe(pc)
  003d2c:  4e ba 00 90            jsr $3dbe(pc)
  003d30:  4a 2d b9 53            tst.b -$46ad(a5)
  003d34:  6d 00 00 86            blt.w $3dbc
  003d38:  4e ba 09 c4            jsr $46fe(pc)
  003d3c:  4a 00                  tst.b d0
  003d3e:  67 7c                  beq.b $3dbc
  003d40:  42 6d ba 42            clr.w -$45be(a5)
  003d44:  4a 2d b9 53            tst.b -$46ad(a5)
  003d48:  6d 0e                  blt.b $3d58
  003d4a:  0c 2d 00 06 b9 53      cmpi.b #$6, -$46ad(a5)
  003d50:  6c 06                  bge.b $3d58
  003d52:  52 2d b9 53            addq.b #$1, -$46ad(a5)
  003d56:  60 64                  bra.b $3dbc
  003d58:  0c 2d 00 06 b9 53      cmpi.b #$6, -$46ad(a5)
  003d5e:  66 18                  bne.b $3d78
  003d60:  4a 6d a9 0c            tst.w -$56f4(a5)
  003d64:  6f 0c                  ble.b $3d72
  003d66:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  003d6c:  67 04                  beq.b $3d72
  003d6e:  4e ba 09 ac            jsr $471c(pc)
  003d72:  52 2d b9 53            addq.b #$1, -$46ad(a5)
  003d76:  60 44                  bra.b $3dbc
  003d78:  0c 2d 00 07 b9 53      cmpi.b #$7, -$46ad(a5)
  003d7e:  66 3c                  bne.b $3dbc
  003d80:  4e ad 01 02            jsr $102(a5)
  003d84:  4a 00                  tst.b d0
  003d86:  66 34                  bne.b $3dbc
  003d88:  4a 6d a9 0c            tst.w -$56f4(a5)
  003d8c:  6f 20                  ble.b $3dae
  003d8e:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  003d94:  67 18                  beq.b $3dae
  003d96:  30 3c 01 b0            move.w #$1b0, d0
  003d9a:  3b 40 ba 90            move.w d0, -$4570(a5)
  003d9e:  3b 40 ba 86            move.w d0, -$457a(a5)
  003da2:  48 6d 97 4e            pea.l -$68b2(a5)
  003da6:  4e ad 05 12            jsr $512(a5)
  003daa:  58 8f                  addq.l #$4, a7
  003dac:  60 0a                  bra.b $3db8
  003dae:  70 24                  moveq #$24, d0
  003db0:  3b 40 ba 90            move.w d0, -$4570(a5)
  003db4:  3b 40 ba 86            move.w d0, -$457a(a5)
  003db8:  52 2d b9 53            addq.b #$1, -$46ad(a5)
  003dbc:  4e 75                  rts 
  003dbe:  4a 2d b9 53            tst.b -$46ad(a5)
  003dc2:  6c 0a                  bge.b $3dce
  003dc4:  4a 6d ba 4a            tst.w -$45b6(a5)
  003dc8:  66 04                  bne.b $3dce
  003dca:  42 2d b9 53            clr.b -$46ad(a5)
  003dce:  4a 6d ba 54            tst.w -$45ac(a5)
  003dd2:  67 04                  beq.b $3dd8
  003dd4:  53 6d ba 54            subq.w #$1, -$45ac(a5)
  003dd8:  4a 6d a9 0c            tst.w -$56f4(a5)
  003ddc:  66 0a                  bne.b $3de8
  003dde:  4e ba 00 22            jsr $3e02(pc)
  003de2:  4e ad 05 3a            jsr $53a(a5)
  003de6:  60 18                  bra.b $3e00
  003de8:  4e ba 01 08            jsr $3ef2(pc)
  003dec:  4e ba cc 36            jsr $a24(pc)
  003df0:  1b 40 a5 be            move.b d0, -$5a42(a5)
  003df4:  4e ba 01 86            jsr $3f7c(pc)
  003df8:  4e ba 00 8c            jsr $3e86(pc)
  003dfc:  4e ba 00 d4            jsr $3ed2(pc)
  003e00:  4e 75                  rts 
  003e02:  4a 6d ba 40            tst.w -$45c0(a5)
  003e06:  67 14                  beq.b $3e1c
  003e08:  4e ba 00 b4            jsr $3ebe(pc)
  003e0c:  1b 40 ba ae            move.b d0, -$4552(a5)
  003e10:  72 ff                  moveq #$ff, d1
  003e12:  1b 41 ba b9            move.b d1, -$4547(a5)
  003e16:  1b 41 ba aa            move.b d1, -$4556(a5)
  003e1a:  60 22                  bra.b $3e3e
  003e1c:  4a 2d b9 52            tst.b -$46ae(a5)
  003e20:  67 12                  beq.b $3e34
  003e22:  3b 7c 00 0a ba 20      move.w #$a, -$45e0(a5)
  003e28:  4e ba ea e0            jsr $290a(pc)
  003e2c:  3b 7c 00 0b ba 20      move.w #$b, -$45e0(a5)
  003e32:  60 0a                  bra.b $3e3e
  003e34:  48 6d a9 c0            pea.l -$5640(a5)
  003e38:  4e ba f1 88            jsr $2fc2(pc)
  003e3c:  58 8f                  addq.l #$4, a7
  003e3e:  4e 75                  rts 
  003e40:  0c 2d 00 18 b9 51      cmpi.b #$18, -$46af(a5)
  003e46:  66 06                  bne.b $3e4e
  003e48:  4e ba ea c0            jsr $290a(pc)
  003e4c:  60 36                  bra.b $3e84
  003e4e:  4a 2d b9 53            tst.b -$46ad(a5)
  003e52:  6d 0e                  blt.b $3e62
  003e54:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  003e5a:  66 20                  bne.b $3e7c
  003e5c:  4e ba 09 4e            jsr $47ac(pc)
  003e60:  60 1a                  bra.b $3e7c
  003e62:  4a 6d ba 4c            tst.w -$45b4(a5)
  003e66:  66 14                  bne.b $3e7c
  003e68:  42 2d b9 53            clr.b -$46ad(a5)
  003e6c:  4e ba 08 e0            jsr $474e(pc)
  003e70:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  003e76:  66 04                  bne.b $3e7c
  003e78:  4e ba 09 32            jsr $47ac(pc)
  003e7c:  4e ba ea 8c            jsr $290a(pc)
  003e80:  4e ad 05 3a            jsr $53a(a5)
  003e84:  4e 75                  rts 
  003e86:  4a 2d b9 49            tst.b -$46b7(a5)
  003e8a:  6d 0e                  blt.b $3e9a
  003e8c:  4e ba 00 12            jsr $3ea0(pc)
  003e90:  4e ad 05 3a            jsr $53a(a5)
  003e94:  4e ba 00 0a            jsr $3ea0(pc)
  003e98:  60 04                  bra.b $3e9e
  003e9a:  4e ad 05 3a            jsr $53a(a5)
  003e9e:  4e 75                  rts 
  003ea0:  2f 07                  move.l d7, -(a7)
  003ea2:  10 2d ba b9            move.b -$4547(a5), d0
  003ea6:  44 00                  neg.b d0
  003ea8:  1b 40 ba b9            move.b d0, -$4547(a5)
  003eac:  1e 2d ba aa            move.b -$4556(a5), d7
  003eb0:  1b 6d ba ab ba aa      move.b -$4555(a5), -$4556(a5)
  003eb6:  1b 47 ba ab            move.b d7, -$4555(a5)
  003eba:  2e 1f                  move.l (a7)+, d7
  003ebc:  4e 75                  rts 
  003ebe:  42 2d ba ad            clr.b -$4553(a5)
  003ec2:  42 2d ba ac            clr.b -$4554(a5)
  003ec6:  42 2d ba aa            clr.b -$4556(a5)
  003eca:  42 2d ba ab            clr.b -$4555(a5)
  003ece:  70 01                  moveq #$1, d0
  003ed0:  4e 75                  rts 
  003ed2:  1b 6d ba aa ba af      move.b -$4556(a5), -$4551(a5)
  003ed8:  1b 6d ba ab ba b0      move.b -$4555(a5), -$4550(a5)
  003ede:  1b 6d ba ac ba b1      move.b -$4554(a5), -$454f(a5)
  003ee4:  1b 6d ba ad ba b2      move.b -$4553(a5), -$454e(a5)
  003eea:  1b 6d ba ae ba b3      move.b -$4552(a5), -$454d(a5)
  003ef0:  4e 75                  rts 
  003ef2:  1b 6d ba af ba aa      move.b -$4551(a5), -$4556(a5)
  003ef8:  1b 6d ba b0 ba ab      move.b -$4550(a5), -$4555(a5)
  003efe:  1b 6d ba b1 ba ac      move.b -$454f(a5), -$4554(a5)
  003f04:  1b 6d ba b2 ba ad      move.b -$454e(a5), -$4553(a5)
  003f0a:  1b 6d ba b3 ba ae      move.b -$454d(a5), -$4552(a5)
  003f10:  4e 75                  rts 
  003f12:  1b 6d ba aa ba b4      move.b -$4556(a5), -$454c(a5)
  003f18:  1b 6d ba ab ba b5      move.b -$4555(a5), -$454b(a5)
  003f1e:  1b 6d ba ac ba b6      move.b -$4554(a5), -$454a(a5)
  003f24:  1b 6d ba ad ba b7      move.b -$4553(a5), -$4549(a5)
  003f2a:  1b 6d ba ae ba b8      move.b -$4552(a5), -$4548(a5)
  003f30:  4e 75                  rts 
  003f32:  1b 6d ba b4 ba aa      move.b -$454c(a5), -$4556(a5)
  003f38:  1b 6d ba b5 ba ab      move.b -$454b(a5), -$4555(a5)
  003f3e:  1b 6d ba b6 ba ac      move.b -$454a(a5), -$4554(a5)
  003f44:  1b 6d ba b7 ba ad      move.b -$4549(a5), -$4553(a5)
  003f4a:  1b 6d ba b8 ba ae      move.b -$4548(a5), -$4552(a5)
  003f50:  4e 75                  rts 
  003f52:  42 2d ba b3            clr.b -$454d(a5)
  003f56:  42 2d ba b2            clr.b -$454e(a5)
  003f5a:  42 2d ba b1            clr.b -$454f(a5)
  003f5e:  42 2d ba b0            clr.b -$4550(a5)
  003f62:  42 2d ba af            clr.b -$4551(a5)
  003f66:  42 2d ba b8            clr.b -$4548(a5)
  003f6a:  42 2d ba b7            clr.b -$4549(a5)
  003f6e:  42 2d ba b6            clr.b -$454a(a5)
  003f72:  42 2d ba b5            clr.b -$454b(a5)
  003f76:  42 2d ba b4            clr.b -$454c(a5)
  003f7a:  4e 75                  rts 
  003f7c:  4a 2d ba aa            tst.b -$4556(a5)
  003f80:  6d 18                  blt.b $3f9a
  003f82:  4a 2d ba b9            tst.b -$4547(a5)
  003f86:  6c 0e                  bge.b $3f96
  003f88:  4a 2d ba aa            tst.b -$4556(a5)
  003f8c:  66 0c                  bne.b $3f9a
  003f8e:  1b 7c 00 ff ba aa      move.b #$ff, -$4556(a5)
  003f94:  60 04                  bra.b $3f9a
  003f96:  42 2d ba aa            clr.b -$4556(a5)
  003f9a:  4a 2d ba ab            tst.b -$4555(a5)
  003f9e:  6d 1a                  blt.b $3fba
  003fa0:  0c 2d 00 01 ba b9      cmpi.b #$1, -$4547(a5)
  003fa6:  66 0e                  bne.b $3fb6
  003fa8:  4a 2d ba ab            tst.b -$4555(a5)
  003fac:  66 0c                  bne.b $3fba
  003fae:  1b 7c 00 ff ba ab      move.b #$ff, -$4555(a5)
  003fb4:  60 04                  bra.b $3fba
  003fb6:  42 2d ba ab            clr.b -$4555(a5)
  003fba:  4a 2d ba ac            tst.b -$4554(a5)
  003fbe:  6d 18                  blt.b $3fd8
  003fc0:  4a 2d ba ba            tst.b -$4546(a5)
  003fc4:  6c 0e                  bge.b $3fd4
  003fc6:  4a 2d ba ac            tst.b -$4554(a5)
  003fca:  66 0c                  bne.b $3fd8
  003fcc:  1b 7c 00 ff ba ac      move.b #$ff, -$4554(a5)
  003fd2:  60 04                  bra.b $3fd8
  003fd4:  42 2d ba ac            clr.b -$4554(a5)
  003fd8:  4a 2d ba ad            tst.b -$4553(a5)
  003fdc:  6d 1a                  blt.b $3ff8
  003fde:  0c 2d 00 01 ba ba      cmpi.b #$1, -$4546(a5)
  003fe4:  66 0e                  bne.b $3ff4
  003fe6:  4a 2d ba ad            tst.b -$4553(a5)
  003fea:  66 0c                  bne.b $3ff8
  003fec:  1b 7c 00 ff ba ad      move.b #$ff, -$4553(a5)
  003ff2:  60 04                  bra.b $3ff8
  003ff4:  42 2d ba ad            clr.b -$4553(a5)
  003ff8:  4a 2d ba ae            tst.b -$4552(a5)
  003ffc:  6d 18                  blt.b $4016
  003ffe:  4a 2d ba bb            tst.b -$4545(a5)
  004002:  6c 0e                  bge.b $4012
  004004:  4a 2d ba ae            tst.b -$4552(a5)
  004008:  66 0c                  bne.b $4016
  00400a:  1b 7c 00 ff ba ae      move.b #$ff, -$4552(a5)
  004010:  60 04                  bra.b $4016
  004012:  42 2d ba ae            clr.b -$4552(a5)
  004016:  4e 75                  rts 
  004018:  2f 07                  move.l d7, -(a7)
  00401a:  70 00                  moveq #$0, d0
  00401c:  10 2d ba e9            move.b -$4517(a5), d0
  004020:  d0 ad bd 86            add.l -$427a(a5), d0
  004024:  20 40                  movea.l d0, a0
  004026:  1e 10                  move.b (a0), d7
  004028:  0c 2d 00 14 ba bd      cmpi.b #$14, -$4543(a5)
  00402e:  66 04                  bne.b $4034
  004030:  70 00                  moveq #$0, d0
  004032:  60 62                  bra.b $4096
  004034:  0c 2d 00 0c ba bd      cmpi.b #$c, -$4543(a5)
  00403a:  66 0a                  bne.b $4046
  00403c:  4a 2d b9 49            tst.b -$46b7(a5)
  004040:  6d 04                  blt.b $4046
  004042:  70 00                  moveq #$0, d0
  004044:  60 50                  bra.b $4096
  004046:  70 00                  moveq #$0, d0
  004048:  10 2d ba bd            move.b -$4543(a5), d0
  00404c:  3f 00                  move.w d0, -(a7)
  00404e:  4e ba f7 0a            jsr $375a(pc)
  004052:  4a 00                  tst.b d0
  004054:  54 8f                  addq.l #$2, a7
  004056:  67 04                  beq.b $405c
  004058:  70 00                  moveq #$0, d0
  00405a:  60 3a                  bra.b $4096
  00405c:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  004062:  66 08                  bne.b $406c
  004064:  4a 07                  tst.b d7
  004066:  67 04                  beq.b $406c
  004068:  70 00                  moveq #$0, d0
  00406a:  60 2a                  bra.b $4096
  00406c:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  004072:  66 0a                  bne.b $407e
  004074:  4a 2d b9 49            tst.b -$46b7(a5)
  004078:  6c 04                  bge.b $407e
  00407a:  70 00                  moveq #$0, d0
  00407c:  60 18                  bra.b $4096
  00407e:  70 00                  moveq #$0, d0
  004080:  10 2d ba e8            move.b -$4518(a5), d0
  004084:  3f 00                  move.w d0, -(a7)
  004086:  4e ba f6 d2            jsr $375a(pc)
  00408a:  4a 00                  tst.b d0
  00408c:  54 8f                  addq.l #$2, a7
  00408e:  66 04                  bne.b $4094
  004090:  70 00                  moveq #$0, d0
  004092:  60 02                  bra.b $4096
  004094:  70 01                  moveq #$1, d0
  004096:  2e 1f                  move.l (a7)+, d7
  004098:  4e 75                  rts 
  00409a:  4e 56 00 00            link.w a6, #$0
  00409e:  2f 07                  move.l d7, -(a7)
  0040a0:  1e 2e 00 08            move.b $8(a6), d7
  0040a4:  0c 07 00 14            cmpi.b #$14, d7
  0040a8:  66 04                  bne.b $40ae
  0040aa:  70 04                  moveq #$4, d0
  0040ac:  60 2c                  bra.b $40da
  0040ae:  0c 07 00 12            cmpi.b #$12, d7
  0040b2:  66 04                  bne.b $40b8
  0040b4:  70 03                  moveq #$3, d0
  0040b6:  60 22                  bra.b $40da
  0040b8:  0c 07 00 04            cmpi.b #$4, d7
  0040bc:  67 0c                  beq.b $40ca
  0040be:  0c 07 00 07            cmpi.b #$7, d7
  0040c2:  67 06                  beq.b $40ca
  0040c4:  0c 07 00 0c            cmpi.b #$c, d7
  0040c8:  66 04                  bne.b $40ce
  0040ca:  70 01                  moveq #$1, d0
  0040cc:  60 0c                  bra.b $40da
  0040ce:  0c 07 00 0d            cmpi.b #$d, d7
  0040d2:  66 04                  bne.b $40d8
  0040d4:  70 02                  moveq #$2, d0
  0040d6:  60 02                  bra.b $40da
  0040d8:  70 00                  moveq #$0, d0
  0040da:  2e 1f                  move.l (a7)+, d7
  0040dc:  4e 5e                  unlk a6
  0040de:  4e 75                  rts 
  0040e0:  70 ff                  moveq #$ff, d0
  0040e2:  d0 2d b9 4b            add.b -$46b5(a5), d0
  0040e6:  1b 40 ba e6            move.b d0, -$451a(a5)
  0040ea:  48 80                  ext.w d0
  0040ec:  3f 00                  move.w d0, -(a7)
  0040ee:  10 2d b9 4a            move.b -$46b6(a5), d0
  0040f2:  48 80                  ext.w d0
  0040f4:  3f 00                  move.w d0, -(a7)
  0040f6:  10 2d b9 4f            move.b -$46b1(a5), d0
  0040fa:  48 80                  ext.w d0
  0040fc:  3f 00                  move.w d0, -(a7)
  0040fe:  4e ba ef 78            jsr $3078(pc)
  004102:  5c 8f                  addq.l #$6, a7
  004104:  4e 75                  rts 
  004106:  10 2d b9 49            move.b -$46b7(a5), d0
  00410a:  48 80                  ext.w d0
  00410c:  20 4d                  movea.l a5, a0
  00410e:  d0 c0                  adda.w d0, a0
  004110:  10 28 b6 63            move.b -$499d(a0), d0
  004114:  d0 2d b9 4a            add.b -$46b6(a5), d0
  004118:  1b 40 ba e5            move.b d0, -$451b(a5)
  00411c:  72 ff                  moveq #$ff, d1
  00411e:  d2 2d b9 4b            add.b -$46b5(a5), d1
  004122:  1b 41 ba e6            move.b d1, -$451a(a5)
  004126:  48 81                  ext.w d1
  004128:  3f 01                  move.w d1, -(a7)
  00412a:  48 80                  ext.w d0
  00412c:  3f 00                  move.w d0, -(a7)
  00412e:  10 2d b9 4f            move.b -$46b1(a5), d0
  004132:  48 80                  ext.w d0
  004134:  3f 00                  move.w d0, -(a7)
  004136:  4e ba ef 40            jsr $3078(pc)
  00413a:  5c 8f                  addq.l #$6, a7
  00413c:  4e 75                  rts 
  00413e:  10 2d b9 49            move.b -$46b7(a5), d0
  004142:  48 80                  ext.w d0
  004144:  20 4d                  movea.l a5, a0
  004146:  d0 c0                  adda.w d0, a0
  004148:  10 28 b6 61            move.b -$499f(a0), d0
  00414c:  d0 2d b9 4a            add.b -$46b6(a5), d0
  004150:  1b 40 ba e4            move.b d0, -$451c(a5)
  004154:  72 ff                  moveq #$ff, d1
  004156:  d2 2d b9 4b            add.b -$46b5(a5), d1
  00415a:  1b 41 ba e6            move.b d1, -$451a(a5)
  00415e:  48 81                  ext.w d1
  004160:  3f 01                  move.w d1, -(a7)
  004162:  48 80                  ext.w d0
  004164:  3f 00                  move.w d0, -(a7)
  004166:  10 2d b9 4f            move.b -$46b1(a5), d0
  00416a:  48 80                  ext.w d0
  00416c:  3f 00                  move.w d0, -(a7)
  00416e:  4e ba ef 08            jsr $3078(pc)
  004172:  5c 8f                  addq.l #$6, a7
  004174:  4e 75                  rts 
  004176:  4e 56 00 00            link.w a6, #$0
  00417a:  4a 2d b9 49            tst.b -$46b7(a5)
  00417e:  6c 06                  bge.b $4186
  004180:  30 2e 00 08            move.w $8(a6), d0
  004184:  60 06                  bra.b $418c
  004186:  30 2e 00 08            move.w $8(a6), d0
  00418a:  44 40                  neg.w d0
  00418c:  4e 5e                  unlk a6
  00418e:  4e 75                  rts 
  004190:  4e 56 00 00            link.w a6, #$0
  004194:  2f 07                  move.l d7, -(a7)
  004196:  3b 6e 00 08 ba c0      move.w $8(a6), -$4540(a5)
  00419c:  3b 6d ba ea ba c2      move.w -$4516(a5), -$453e(a5)
  0041a2:  70 00                  moveq #$0, d0
  0041a4:  10 2d ba e9            move.b -$4517(a5), d0
  0041a8:  3b 40 ba c4            move.w d0, -$453c(a5)
  0041ac:  1b 7c 00 01 ba ae      move.b #$1, -$4552(a5)
  0041b2:  7e 00                  moveq #$0, d7
  0041b4:  1e 2d ba e9            move.b -$4517(a5), d7
  0041b8:  20 6d bd 82            movea.l -$427e(a5), a0
  0041bc:  11 bc 00 01 78 00      move.b #$1, (a0, d7.l)
  0041c2:  20 6d bd 86            movea.l -$427a(a5), a0
  0041c6:  42 30 78 00            clr.b (a0, d7.l)
  0041ca:  3b 7c 00 23 bd 6c      move.w #$23, -$4294(a5)
  0041d0:  70 00                  moveq #$0, d0
  0041d2:  10 2d ba e9            move.b -$4517(a5), d0
  0041d6:  3f 00                  move.w d0, -(a7)
  0041d8:  4e ad 04 12            jsr $412(a5)
  0041dc:  2e 2e ff fc            move.l -$4(a6), d7
  0041e0:  4e 5e                  unlk a6
  0041e2:  4e 75                  rts 
  0041e4:  48 e7 03 00            movem.l d6-d7, -(a7)
  0041e8:  7e 00                  moveq #$0, d7
  0041ea:  1e 2d b9 46            move.b -$46ba(a5), d7
  0041ee:  1c 2d b9 4c            move.b -$46b4(a5), d6
  0041f2:  48 86                  ext.w d6
  0041f4:  0c 47 00 57            cmpi.w #$57, d7
  0041f8:  6d 06                  blt.b $4200
  0041fa:  0c 47 00 64            cmpi.w #$64, d7
  0041fe:  6d 0c                  blt.b $420c
  004200:  0c 47 00 87            cmpi.w #$87, d7
  004204:  6d 0c                  blt.b $4212
  004206:  0c 47 00 8d            cmpi.w #$8d, d7
  00420a:  6c 06                  bge.b $4212
  00420c:  4e ba fe d2            jsr $40e0(pc)
  004210:  60 3e                  bra.b $4250
  004212:  0c 46 00 07            cmpi.w #$7, d6
  004216:  67 0c                  beq.b $4224
  004218:  0c 46 00 05            cmpi.w #$5, d6
  00421c:  67 06                  beq.b $4224
  00421e:  0c 46 00 02            cmpi.w #$2, d6
  004222:  6c 6e                  bge.b $4292
  004224:  0c 47 00 4f            cmpi.w #$4f, d7
  004228:  66 1a                  bne.b $4244
  00422a:  4e ba fe b4            jsr $40e0(pc)
  00422e:  72 00                  moveq #$0, d1
  004230:  12 00                  move.b d0, d1
  004232:  0c 41 00 0b            cmpi.w #$b, d1
  004236:  66 0c                  bne.b $4244
  004238:  1f 3c 00 01            move.b #$1, -(a7)
  00423c:  4e ad 04 5a            jsr $45a(a5)
  004240:  54 8f                  addq.l #$2, a7
  004242:  60 0c                  bra.b $4250
  004244:  08 2d 00 06 b9 92      btst.b #$6, -$466e(a5)
  00424a:  67 46                  beq.b $4292
  00424c:  4e ba f6 1a            jsr $3868(pc)
  004250:  0c 2d 00 0f ba e8      cmpi.b #$f, -$4518(a5)
  004256:  67 08                  beq.b $4260
  004258:  0c 2d 00 06 ba e8      cmpi.b #$6, -$4518(a5)
  00425e:  66 1a                  bne.b $427a
  004260:  4a 2d b9 53            tst.b -$46ad(a5)
  004264:  6c 0e                  bge.b $4274
  004266:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  00426c:  4e ad 04 42            jsr $442(a5)
  004270:  58 8f                  addq.l #$4, a7
  004272:  60 1e                  bra.b $4292
  004274:  4e ad 04 4a            jsr $44a(a5)
  004278:  60 18                  bra.b $4292
  00427a:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  004280:  66 10                  bne.b $4292
  004282:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  004288:  1f 3c 00 01            move.b #$1, -(a7)
  00428c:  4e ad 04 5a            jsr $45a(a5)
  004290:  54 8f                  addq.l #$2, a7
  004292:  4c df 00 c0            movem.l (a7)+, d6-d7
  004296:  4e 75                  rts 
  004298:  48 e7 1f 00            movem.l d3-d7, -(a7)
  00429c:  3f 2d ba de            move.w -$4522(a5), -(a7)
  0042a0:  4e ba f2 42            jsr $34e4(pc)
  0042a4:  3e 00                  move.w d0, d7
  0042a6:  4a 47                  tst.w d7
  0042a8:  54 8f                  addq.l #$2, a7
  0042aa:  6d 76                  blt.b $4322
  0042ac:  1c 2d b9 4b            move.b -$46b5(a5), d6
  0042b0:  48 86                  ext.w d6
  0042b2:  1a 2d b9 4f            move.b -$46b1(a5), d5
  0042b6:  48 85                  ext.w d5
  0042b8:  3f 2d ba dc            move.w -$4524(a5), -(a7)
  0042bc:  4e ba f2 26            jsr $34e4(pc)
  0042c0:  38 00                  move.w d0, d4
  0042c2:  54 8f                  addq.l #$2, a7
  0042c4:  60 58                  bra.b $431e
  0042c6:  1c 2d b9 4b            move.b -$46b5(a5), d6
  0042ca:  48 86                  ext.w d6
  0042cc:  76 00                  moveq #$0, d3
  0042ce:  3f 06                  move.w d6, -(a7)
  0042d0:  3f 04                  move.w d4, -(a7)
  0042d2:  3f 05                  move.w d5, -(a7)
  0042d4:  4e ba ed a2            jsr $3078(pc)
  0042d8:  72 00                  moveq #$0, d1
  0042da:  12 00                  move.b d0, d1
  0042dc:  55 41                  subq.w #$2, d1
  0042de:  5c 8f                  addq.l #$6, a7
  0042e0:  66 14                  bne.b $42f6
  0042e2:  70 00                  moveq #$0, d0
  0042e4:  10 2d ba e9            move.b -$4517(a5), d0
  0042e8:  3f 00                  move.w d0, -(a7)
  0042ea:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  0042ee:  4e ad 04 32            jsr $432(a5)
  0042f2:  58 8f                  addq.l #$4, a7
  0042f4:  60 22                  bra.b $4318
  0042f6:  70 00                  moveq #$0, d0
  0042f8:  10 2d ba e8            move.b -$4518(a5), d0
  0042fc:  3f 00                  move.w d0, -(a7)
  0042fe:  4e ba f4 5a            jsr $375a(pc)
  004302:  4a 00                  tst.b d0
  004304:  54 8f                  addq.l #$2, a7
  004306:  66 10                  bne.b $4318
  004308:  4a 6d ba ea            tst.w -$4516(a5)
  00430c:  67 0a                  beq.b $4318
  00430e:  ba 6d ba ea            cmp.w -$4516(a5), d5
  004312:  66 04                  bne.b $4318
  004314:  52 46                  addq.w #$1, d6
  004316:  76 01                  moveq #$1, d3
  004318:  4a 43                  tst.w d3
  00431a:  66 b0                  bne.b $42cc
  00431c:  52 44                  addq.w #$1, d4
  00431e:  be 44                  cmp.w d4, d7
  004320:  6c a4                  bge.b $42c6
  004322:  4c df 00 f8            movem.l (a7)+, d3-d7
  004326:  4e 75                  rts 
  004328:  48 e7 1f 00            movem.l d3-d7, -(a7)
  00432c:  7e 00                  moveq #$0, d7
  00432e:  1e 2d b9 46            move.b -$46ba(a5), d7
  004332:  1c 2d b9 4c            move.b -$46b4(a5), d6
  004336:  48 86                  ext.w d6
  004338:  1a 2d b9 4f            move.b -$46b1(a5), d5
  00433c:  48 85                  ext.w d5
  00433e:  18 2d b9 4b            move.b -$46b5(a5), d4
  004342:  48 84                  ext.w d4
  004344:  4e ba f3 28            jsr $366e(pc)
  004348:  0c 47 00 e0            cmpi.w #$e0, d7
  00434c:  6d 16                  blt.b $4364
  00434e:  0c 47 00 e5            cmpi.w #$e5, d7
  004352:  6c 10                  bge.b $4364
  004354:  3b 6d bd 98 ba fe      move.w -$4268(a5), -$4502(a5)
  00435a:  3b 6d ba e2 bb 04      move.w -$451e(a5), -$44fc(a5)
  004360:  60 00 01 ca            bra.w $452c
  004364:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  004368:  3f 2d ba c6            move.w -$453a(a5), -(a7)
  00436c:  3f 05                  move.w d5, -(a7)
  00436e:  4e ba ed 08            jsr $3078(pc)
  004372:  72 00                  moveq #$0, d1
  004374:  12 00                  move.b d0, d1
  004376:  0c 41 00 14            cmpi.w #$14, d1
  00437a:  5c 8f                  addq.l #$6, a7
  00437c:  67 12                  beq.b $4390
  00437e:  70 00                  moveq #$0, d0
  004380:  10 2d ba e8            move.b -$4518(a5), d0
  004384:  3f 00                  move.w d0, -(a7)
  004386:  4e ba f3 d2            jsr $375a(pc)
  00438a:  4a 00                  tst.b d0
  00438c:  54 8f                  addq.l #$2, a7
  00438e:  67 7c                  beq.b $440c
  004390:  4a 46                  tst.w d6
  004392:  66 0c                  bne.b $43a0
  004394:  0c 47 00 4f            cmpi.w #$4f, d7
  004398:  67 32                  beq.b $43cc
  00439a:  0c 47 00 51            cmpi.w #$51, d7
  00439e:  67 2c                  beq.b $43cc
  0043a0:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  0043a4:  3f 2d ba c8            move.w -$4538(a5), -(a7)
  0043a8:  3f 05                  move.w d5, -(a7)
  0043aa:  4e ba ec cc            jsr $3078(pc)
  0043ae:  72 00                  moveq #$0, d1
  0043b0:  12 00                  move.b d0, d1
  0043b2:  0c 41 00 14            cmpi.w #$14, d1
  0043b6:  5c 8f                  addq.l #$6, a7
  0043b8:  67 12                  beq.b $43cc
  0043ba:  70 00                  moveq #$0, d0
  0043bc:  10 2d ba e8            move.b -$4518(a5), d0
  0043c0:  3f 00                  move.w d0, -(a7)
  0043c2:  4e ba f3 96            jsr $375a(pc)
  0043c6:  4a 00                  tst.b d0
  0043c8:  54 8f                  addq.l #$2, a7
  0043ca:  67 40                  beq.b $440c
  0043cc:  20 4d                  movea.l a5, a0
  0043ce:  d0 c4                  adda.w d4, a0
  0043d0:  d0 c4                  adda.w d4, a0
  0043d2:  36 28 b6 66            move.w -$499a(a0), d3
  0043d6:  4a 44                  tst.w d4
  0043d8:  6f 10                  ble.b $43ea
  0043da:  b6 6d ba f8            cmp.w -$4508(a5), d3
  0043de:  6c 2c                  bge.b $440c
  0043e0:  70 f1                  moveq #$f1, d0
  0043e2:  d0 43                  add.w d3, d0
  0043e4:  b0 6d ba e0            cmp.w -$4520(a5), d0
  0043e8:  6c 22                  bge.b $440c
  0043ea:  3b 43 ba e0            move.w d3, -$4520(a5)
  0043ee:  4a 6d ba e0            tst.w -$4520(a5)
  0043f2:  6c 08                  bge.b $43fc
  0043f4:  3b 6d 9d 12 ba fe      move.w -$62ee(a5), -$4502(a5)
  0043fa:  60 10                  bra.b $440c
  0043fc:  30 2d ba e0            move.w -$4520(a5), d0
  004400:  20 4d                  movea.l a5, a0
  004402:  d0 c0                  adda.w d0, a0
  004404:  d0 c0                  adda.w d0, a0
  004406:  3b 68 9d 12 ba fe      move.w -$62ee(a0), -$4502(a5)
  00440c:  70 fc                  moveq #$fc, d0
  00440e:  d0 6d ba d8            add.w -$4528(a5), d0
  004412:  3f 00                  move.w d0, -(a7)
  004414:  4e ba f0 f4            jsr $350a(pc)
  004418:  36 00                  move.w d0, d3
  00441a:  3e 84                  move.w d4, (a7)
  00441c:  70 01                  moveq #$1, d0
  00441e:  d0 43                  add.w d3, d0
  004420:  3f 00                  move.w d0, -(a7)
  004422:  3f 05                  move.w d5, -(a7)
  004424:  4e ba ec 52            jsr $3078(pc)
  004428:  72 00                  moveq #$0, d1
  00442a:  12 00                  move.b d0, d1
  00442c:  5f 41                  subq.w #$7, d1
  00442e:  5c 8f                  addq.l #$6, a7
  004430:  67 08                  beq.b $443a
  004432:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  004438:  66 18                  bne.b $4452
  00443a:  70 01                  moveq #$1, d0
  00443c:  d0 6d ba ec            add.w -$4514(a5), d0
  004440:  eb 48                  lsl.w #$5, d0
  004442:  20 4d                  movea.l a5, a0
  004444:  d0 c0                  adda.w d0, a0
  004446:  d0 c0                  adda.w d0, a0
  004448:  3b 68 99 14 bb 04      move.w -$66ec(a0), -$44fc(a5)
  00444e:  60 00 00 dc            bra.w $452c
  004452:  3f 04                  move.w d4, -(a7)
  004454:  3f 03                  move.w d3, -(a7)
  004456:  3f 05                  move.w d5, -(a7)
  004458:  4e ba ec 1e            jsr $3078(pc)
  00445c:  72 00                  moveq #$0, d1
  00445e:  12 00                  move.b d0, d1
  004460:  5f 41                  subq.w #$7, d1
  004462:  5c 8f                  addq.l #$6, a7
  004464:  67 08                  beq.b $446e
  004466:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  00446c:  66 58                  bne.b $44c6
  00446e:  0c 46 00 03            cmpi.w #$3, d6
  004472:  67 52                  beq.b $44c6
  004474:  0c 46 00 04            cmpi.w #$4, d6
  004478:  66 06                  bne.b $4480
  00447a:  0c 47 00 6a            cmpi.w #$6a, d7
  00447e:  67 46                  beq.b $44c6
  004480:  0c 46 00 05            cmpi.w #$5, d6
  004484:  66 06                  bne.b $448c
  004486:  0c 47 00 6b            cmpi.w #$6b, d7
  00448a:  67 3a                  beq.b $44c6
  00448c:  4a 2d b9 49            tst.b -$46b7(a5)
  004490:  6c 1e                  bge.b $44b0
  004492:  0c 46 00 02            cmpi.w #$2, d6
  004496:  67 2e                  beq.b $44c6
  004498:  0c 46 00 06            cmpi.w #$6, d6
  00449c:  67 28                  beq.b $44c6
  00449e:  0c 46 00 01            cmpi.w #$1, d6
  0044a2:  66 0c                  bne.b $44b0
  0044a4:  0c 47 00 89            cmpi.w #$89, d7
  0044a8:  6d 06                  blt.b $44b0
  0044aa:  0c 47 00 8c            cmpi.w #$8c, d7
  0044ae:  6f 16                  ble.b $44c6
  0044b0:  70 01                  moveq #$1, d0
  0044b2:  d0 6d ba ec            add.w -$4514(a5), d0
  0044b6:  eb 48                  lsl.w #$5, d0
  0044b8:  20 4d                  movea.l a5, a0
  0044ba:  d0 c0                  adda.w d0, a0
  0044bc:  d0 c0                  adda.w d0, a0
  0044be:  3b 68 99 14 bb 04      move.w -$66ec(a0), -$44fc(a5)
  0044c4:  60 66                  bra.b $452c
  0044c6:  3f 2d ba da            move.w -$4526(a5), -(a7)
  0044ca:  4e ba f0 3e            jsr $350a(pc)
  0044ce:  36 00                  move.w d0, d3
  0044d0:  3e 84                  move.w d4, (a7)
  0044d2:  3f 03                  move.w d3, -(a7)
  0044d4:  3f 05                  move.w d5, -(a7)
  0044d6:  4e ba eb a0            jsr $3078(pc)
  0044da:  72 00                  moveq #$0, d1
  0044dc:  12 00                  move.b d0, d1
  0044de:  0c 41 00 14            cmpi.w #$14, d1
  0044e2:  5c 8f                  addq.l #$6, a7
  0044e4:  67 0e                  beq.b $44f4
  0044e6:  0c 2d 00 0d ba e8      cmpi.b #$d, -$4518(a5)
  0044ec:  66 3e                  bne.b $452c
  0044ee:  4a 2d b9 49            tst.b -$46b7(a5)
  0044f2:  66 38                  bne.b $452c
  0044f4:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  0044f8:  3f 03                  move.w d3, -(a7)
  0044fa:  3f 05                  move.w d5, -(a7)
  0044fc:  4e ba eb 7a            jsr $3078(pc)
  004500:  72 00                  moveq #$0, d1
  004502:  12 00                  move.b d0, d1
  004504:  0c 41 00 14            cmpi.w #$14, d1
  004508:  5c 8f                  addq.l #$6, a7
  00450a:  67 08                  beq.b $4514
  00450c:  0c 2d 00 0d ba e8      cmpi.b #$d, -$4518(a5)
  004512:  66 18                  bne.b $452c
  004514:  ba 6d ba ea            cmp.w -$4516(a5), d5
  004518:  66 12                  bne.b $452c
  00451a:  30 2d ba ec            move.w -$4514(a5), d0
  00451e:  eb 48                  lsl.w #$5, d0
  004520:  20 4d                  movea.l a5, a0
  004522:  d0 c0                  adda.w d0, a0
  004524:  d0 c0                  adda.w d0, a0
  004526:  3b 68 99 14 bb 04      move.w -$66ec(a0), -$44fc(a5)
  00452c:  4c df 00 f8            movem.l (a7)+, d3-d7
  004530:  4e 75                  rts 
  004532:  4e ba f3 34            jsr $3868(pc)
  004536:  72 00                  moveq #$0, d1
  004538:  12 00                  move.b d0, d1
  00453a:  5b 41                  subq.w #$5, d1
  00453c:  66 04                  bne.b $4542
  00453e:  52 2d b9 48            addq.b #$1, -$46b8(a5)
  004542:  4e 75                  rts 
  004544:  48 e7 03 00            movem.l d6-d7, -(a7)
  004548:  7e 00                  moveq #$0, d7
  00454a:  1e 2d b9 46            move.b -$46ba(a5), d7
  00454e:  1c 2d b9 4c            move.b -$46b4(a5), d6
  004552:  48 86                  ext.w d6
  004554:  0c 46 00 01            cmpi.w #$1, d6
  004558:  66 0e                  bne.b $4568
  00455a:  3b 6d ba cc ba ee      move.w -$4534(a5), -$4512(a5)
  004560:  3b 6d ba c6 ba ec      move.w -$453a(a5), -$4514(a5)
  004566:  60 14                  bra.b $457c
  004568:  10 2d b9 4b            move.b -$46b5(a5), d0
  00456c:  48 80                  ext.w d0
  00456e:  3b 40 ba ee            move.w d0, -$4512(a5)
  004572:  12 2d b9 4a            move.b -$46b6(a5), d1
  004576:  48 81                  ext.w d1
  004578:  3b 41 ba ec            move.w d1, -$4514(a5)
  00457c:  0c 47 00 87            cmpi.w #$87, d7
  004580:  6d 06                  blt.b $4588
  004582:  0c 47 00 95            cmpi.w #$95, d7
  004586:  6d 18                  blt.b $45a0
  004588:  0c 46 00 02            cmpi.w #$2, d6
  00458c:  67 12                  beq.b $45a0
  00458e:  0c 46 00 03            cmpi.w #$3, d6
  004592:  67 0c                  beq.b $45a0
  004594:  0c 46 00 04            cmpi.w #$4, d6
  004598:  67 06                  beq.b $45a0
  00459a:  0c 46 00 06            cmpi.w #$6, d6
  00459e:  66 04                  bne.b $45a4
  0045a0:  53 6d ba ec            subq.w #$1, -$4514(a5)
  0045a4:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  0045a8:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  0045ac:  4e ba eb e4            jsr $3192(pc)
  0045b0:  1b 40 ba f0            move.b d0, -$4510(a5)
  0045b4:  58 8f                  addq.l #$4, a7
  0045b6:  4c df 00 c0            movem.l (a7)+, d6-d7
  0045ba:  4e 75                  rts 
  0045bc:  4a 2d b9 51            tst.b -$46af(a5)
  0045c0:  66 00 00 f8            bne.w $46ba
  0045c4:  4a 6d ba c0            tst.w -$4540(a5)
  0045c8:  67 00 00 f0            beq.w $46ba
  0045cc:  0c 6d ff ff ba c0      cmpi.w #$ffff, -$4540(a5)
  0045d2:  66 20                  bne.b $45f4
  0045d4:  3b 7c ff ff ba 28      move.w #$ffff, -$45d8(a5)
  0045da:  3f 3c 00 25            move.w #$25, -(a7)
  0045de:  4e ba c1 d4            jsr $7b4(pc)
  0045e2:  3b 7c 00 0b ba 18      move.w #$b, -$45e8(a5)
  0045e8:  3b 7c 00 08 ba 1a      move.w #$8, -$45e6(a5)
  0045ee:  54 8f                  addq.l #$2, a7
  0045f0:  60 00 00 c8            bra.w $46ba
  0045f4:  53 6d ba c0            subq.w #$1, -$4540(a5)
  0045f8:  30 2d ba c0            move.w -$4540(a5), d0
  0045fc:  67 1c                  beq.b $461a
  0045fe:  6b 00 00 ba            bmi.w $46ba
  004602:  59 40                  subq.w #$4, d0
  004604:  67 00 00 8a            beq.w $4690
  004608:  6a 08                  bpl.b $4612
  00460a:  54 40                  addq.w #$2, d0
  00460c:  67 5a                  beq.b $4668
  00460e:  6a 5e                  bpl.b $466e
  004610:  60 36                  bra.b $4648
  004612:  55 40                  subq.w #$2, d0
  004614:  6a 00 00 a4            bpl.w $46ba
  004618:  60 5a                  bra.b $4674
  00461a:  30 2d ba 4a            move.w -$45b6(a5), d0
  00461e:  b0 6d ba 48            cmp.w -$45b8(a5), d0
  004622:  67 00 00 96            beq.w $46ba
  004626:  4e ad 00 fa            jsr $fa(a5)
  00462a:  3f 3c 00 21            move.w #$21, -(a7)
  00462e:  4e ba c1 84            jsr $7b4(pc)
  004632:  3b 7c 00 01 ba 50      move.w #$1, -$45b0(a5)
  004638:  3b 7c 00 08 ba 18      move.w #$8, -$45e8(a5)
  00463e:  3b 7c 00 02 ba 1a      move.w #$2, -$45e6(a5)
  004644:  54 8f                  addq.l #$2, a7
  004646:  60 72                  bra.b $46ba
  004648:  4e ad 00 fa            jsr $fa(a5)
  00464c:  3f 3c 00 1e            move.w #$1e, -(a7)
  004650:  4e ba c1 62            jsr $7b4(pc)
  004654:  3b 7c 00 08 ba 18      move.w #$8, -$45e8(a5)
  00465a:  3b 7c 00 04 ba 1a      move.w #$4, -$45e6(a5)
  004660:  4e ba c0 54            jsr $6b6(pc)
  004664:  54 8f                  addq.l #$2, a7
  004666:  60 52                  bra.b $46ba
  004668:  4e ba c4 e6            jsr $b50(pc)
  00466c:  60 4c                  bra.b $46ba
  00466e:  4e ba c4 c6            jsr $b36(pc)
  004672:  60 46                  bra.b $46ba
  004674:  3f 3c 00 01            move.w #$1, -(a7)
  004678:  4e ad 05 1a            jsr $51a(a5)
  00467c:  42 a7                  clr.l -(a7)
  00467e:  3f 3c 00 08            move.w #$8, -(a7)
  004682:  4e ba e9 f4            jsr $3078(pc)
  004686:  42 97                  clr.l (a7)
  004688:  4e ad 04 42            jsr $442(a5)
  00468c:  50 8f                  addq.l #$8, a7
  00468e:  60 2a                  bra.b $46ba
  004690:  4e ad 00 fa            jsr $fa(a5)
  004694:  3f 3c 00 0d            move.w #$d, -(a7)
  004698:  4e ba c1 1a            jsr $7b4(pc)
  00469c:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  0046a2:  54 8f                  addq.l #$2, a7
  0046a4:  66 0e                  bne.b $46b4
  0046a6:  30 2d ba 48            move.w -$45b8(a5), d0
  0046aa:  44 40                  neg.w d0
  0046ac:  52 40                  addq.w #$1, d0
  0046ae:  3b 40 ba 50            move.w d0, -$45b0(a5)
  0046b2:  60 06                  bra.b $46ba
  0046b4:  3b 7c ff ff ba 50      move.w #$ffff, -$45b0(a5)
  0046ba:  4e 75                  rts 
  0046bc:  4e ba 00 40            jsr $46fe(pc)
  0046c0:  4a 00                  tst.b d0
  0046c2:  67 04                  beq.b $46c8
  0046c4:  70 01                  moveq #$1, d0
  0046c6:  60 34                  bra.b $46fc
  0046c8:  10 2d b9 46            move.b -$46ba(a5), d0
  0046cc:  67 28                  beq.b $46f6
  0046ce:  6a 16                  bpl.b $46e6
  0046d0:  04 00 00 ab            subi.b #$ab, d0
  0046d4:  67 20                  beq.b $46f6
  0046d6:  6a 06                  bpl.b $46de
  0046d8:  5a 00                  addq.b #$5, d0
  0046da:  67 1a                  beq.b $46f6
  0046dc:  60 1c                  bra.b $46fa
  0046de:  04 00 00 3a            subi.b #$3a, d0
  0046e2:  67 12                  beq.b $46f6
  0046e4:  60 14                  bra.b $46fa
  0046e6:  04 00 00 6d            subi.b #$6d, d0
  0046ea:  67 0a                  beq.b $46f6
  0046ec:  6a 0c                  bpl.b $46fa
  0046ee:  04 00 00 a2            subi.b #$a2, d0
  0046f2:  67 02                  beq.b $46f6
  0046f4:  60 04                  bra.b $46fa
  0046f6:  70 01                  moveq #$1, d0
  0046f8:  60 02                  bra.b $46fc
  0046fa:  70 00                  moveq #$0, d0
  0046fc:  4e 75                  rts 
  0046fe:  10 2d b9 46            move.b -$46ba(a5), d0
  004702:  6a 14                  bpl.b $4718
  004704:  04 00 00 b9            subi.b #$b9, d0
  004708:  67 0a                  beq.b $4714
  00470a:  6a 0c                  bpl.b $4718
  00470c:  5c 00                  addq.b #$6, d0
  00470e:  6a 08                  bpl.b $4718
  004710:  54 00                  addq.b #$2, d0
  004712:  6b 04                  bmi.b $4718
  004714:  70 01                  moveq #$1, d0
  004716:  60 02                  bra.b $471a
  004718:  70 00                  moveq #$0, d0
  00471a:  4e 75                  rts 
  00471c:  0c 2d 00 01 b9 87      cmpi.b #$1, -$4679(a5)
  004722:  66 0c                  bne.b $4730
  004724:  3f 3c 00 20            move.w #$20, -(a7)
  004728:  4e ba c0 8a            jsr $7b4(pc)
  00472c:  54 8f                  addq.l #$2, a7
  00472e:  60 1c                  bra.b $474c
  004730:  4a 6d ba 26            tst.w -$45da(a5)
  004734:  67 0c                  beq.b $4742
  004736:  3f 3c 00 1c            move.w #$1c, -(a7)
  00473a:  4e ba c0 78            jsr $7b4(pc)
  00473e:  54 8f                  addq.l #$2, a7
  004740:  60 0a                  bra.b $474c
  004742:  3f 3c 00 18            move.w #$18, -(a7)
  004746:  4e ba c0 6c            jsr $7b4(pc)
  00474a:  54 8f                  addq.l #$2, a7
  00474c:  4e 75                  rts 
  00474e:  4a 6d a9 0c            tst.w -$56f4(a5)
  004752:  66 10                  bne.b $4764
  004754:  3b 7c 00 01 ba 40      move.w #$1, -$45c0(a5)
  00475a:  42 6d ba 5a            clr.w -$45a6(a5)
  00475e:  42 6d ba 5c            clr.w -$45a4(a5)
  004762:  60 46                  bra.b $47aa
  004764:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  00476a:  66 2c                  bne.b $4798
  00476c:  3b 7c 00 07 ba 18      move.w #$7, -$45e8(a5)
  004772:  3b 7c 00 12 ba 1a      move.w #$12, -$45e6(a5)
  004778:  3b 7c 00 01 ba 42      move.w #$1, -$45be(a5)
  00477e:  3b 7c 00 02 ba 3c      move.w #$2, -$45c4(a5)
  004784:  3f 3c 00 2b            move.w #$2b, -(a7)
  004788:  4e ba c0 2a            jsr $7b4(pc)
  00478c:  41 ed 96 d8            lea.l -$6928(a5), a0
  004790:  20 b8 02 0c            move.l $20c.w, (a0)
  004794:  54 8f                  addq.l #$2, a7
  004796:  60 12                  bra.b $47aa
  004798:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  00479e:  67 0a                  beq.b $47aa
  0047a0:  3f 3c 00 25            move.w #$25, -(a7)
  0047a4:  4e ba c0 0e            jsr $7b4(pc)
  0047a8:  54 8f                  addq.l #$2, a7
  0047aa:  4e 75                  rts 
  0047ac:  1b 7c 00 56 b9 49      move.b #$56, -$46b7(a5)
  0047b2:  42 2d b9 4c            clr.b -$46b4(a5)
  0047b6:  42 2d b9 53            clr.b -$46ad(a5)
  0047ba:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  0047be:  42 67                  clr.w -(a7)
  0047c0:  4e ba be 56            jsr $618(pc)
  0047c4:  42 6d ba 4c            clr.w -$45b4(a5)
  0047c8:  58 8f                  addq.l #$4, a7
  0047ca:  4e 75                  rts 
  0047cc:  1b 6d ba f0 bb 06      move.b -$4510(a5), -$44fa(a5)
  0047d2:  1b 6d ba f1 bb 07      move.b -$450f(a5), -$44f9(a5)
  0047d8:  3b 6d ba f2 bb 08      move.w -$450e(a5), -$44f8(a5)
  0047de:  3b 6d ba f4 bb 0a      move.w -$450c(a5), -$44f6(a5)
  0047e4:  3b 6d ba f6 bb 0c      move.w -$450a(a5), -$44f4(a5)
  0047ea:  3b 6d ba f8 bb 0e      move.w -$4508(a5), -$44f2(a5)
  0047f0:  3b 6d ba fa bb 10      move.w -$4506(a5), -$44f0(a5)
  0047f6:  3b 6d ba fc bb 12      move.w -$4504(a5), -$44ee(a5)
  0047fc:  3b 6d ba fe bb 14      move.w -$4502(a5), -$44ec(a5)
  004802:  3b 6d bb 00 bb 16      move.w -$4500(a5), -$44ea(a5)
  004808:  3b 6d bb 02 bb 18      move.w -$44fe(a5), -$44e8(a5)
  00480e:  3b 6d bb 04 bb 1a      move.w -$44fc(a5), -$44e6(a5)
  004814:  4e 75                  rts 
  004816:  1b 6d bb 06 ba f0      move.b -$44fa(a5), -$4510(a5)
  00481c:  1b 6d bb 07 ba f1      move.b -$44f9(a5), -$450f(a5)
  004822:  3b 6d bb 08 ba f2      move.w -$44f8(a5), -$450e(a5)
  004828:  3b 6d bb 0a ba f4      move.w -$44f6(a5), -$450c(a5)
  00482e:  3b 6d bb 0c ba f6      move.w -$44f4(a5), -$450a(a5)
  004834:  3b 6d bb 0e ba f8      move.w -$44f2(a5), -$4508(a5)
  00483a:  3b 6d bb 10 ba fa      move.w -$44f0(a5), -$4506(a5)
  004840:  3b 6d bb 12 ba fc      move.w -$44ee(a5), -$4504(a5)
  004846:  3b 6d bb 14 ba fe      move.w -$44ec(a5), -$4502(a5)
  00484c:  3b 6d bb 16 bb 00      move.w -$44ea(a5), -$4500(a5)
  004852:  3b 6d bb 18 bb 02      move.w -$44e8(a5), -$44fe(a5)
  004858:  3b 6d bb 1a bb 04      move.w -$44e6(a5), -$44fc(a5)
  00485e:  4e 75                  rts 
  004860:  48 e7 03 00            movem.l d6-d7, -(a7)
  004864:  7c 00                  moveq #$0, d6
  004866:  1c 2d b9 46            move.b -$46ba(a5), d6
  00486a:  0c 46 00 b2            cmpi.w #$b2, d6
  00486e:  67 00 00 90            beq.w $4900
  004872:  4e ba ff 58            jsr $47cc(pc)
  004876:  1b 7c 00 ff ba f0      move.b #$ff, -$4510(a5)
  00487c:  0c 46 00 b9            cmpi.w #$b9, d6
  004880:  67 0c                  beq.b $488e
  004882:  0c 46 00 6a            cmpi.w #$6a, d6
  004886:  6d 16                  blt.b $489e
  004888:  0c 46 00 6f            cmpi.w #$6f, d6
  00488c:  6c 10                  bge.b $489e
  00488e:  58 6d ba f8            addq.w #$4, -$4508(a5)
  004892:  3f 3c 00 05            move.w #$5, -(a7)
  004896:  4e ba ea 94            jsr $332c(pc)
  00489a:  54 8f                  addq.l #$2, a7
  00489c:  60 30                  bra.b $48ce
  00489e:  0c 46 00 b1            cmpi.w #$b1, d6
  0048a2:  66 0c                  bne.b $48b0
  0048a4:  3f 3c ff fb            move.w #$fffb, -(a7)
  0048a8:  4e ba ea 82            jsr $332c(pc)
  0048ac:  54 8f                  addq.l #$2, a7
  0048ae:  60 1e                  bra.b $48ce
  0048b0:  4a 2d b9 51            tst.b -$46af(a5)
  0048b4:  57 c0                  seq.b d0
  0048b6:  44 00                  neg.b d0
  0048b8:  48 80                  ext.w d0
  0048ba:  e5 48                  lsl.w #$2, d0
  0048bc:  06 40 00 0b            addi.w #$b, d0
  0048c0:  91 6d ba f8            sub.w d0, -$4508(a5)
  0048c4:  3f 3c 00 05            move.w #$5, -(a7)
  0048c8:  4e ba ea 62            jsr $332c(pc)
  0048cc:  54 8f                  addq.l #$2, a7
  0048ce:  4a 2d b9 51            tst.b -$46af(a5)
  0048d2:  66 0e                  bne.b $48e2
  0048d4:  3b 7c 00 02 ba f2      move.w #$2, -$450e(a5)
  0048da:  3b 7c 00 da ba f4      move.w #$da, -$450c(a5)
  0048e0:  60 0c                  bra.b $48ee
  0048e2:  3b 7c 00 05 ba f2      move.w #$5, -$450e(a5)
  0048e8:  3b 7c 00 01 ba f4      move.w #$1, -$450c(a5)
  0048ee:  4e ba ed 7e            jsr $366e(pc)
  0048f2:  1f 3c 00 05            move.b #$5, -(a7)
  0048f6:  4e ad 04 ea            jsr $4ea(a5)
  0048fa:  4e ba ff 1a            jsr $4816(pc)
  0048fe:  54 8f                  addq.l #$2, a7
  004900:  4c df 00 c0            movem.l (a7)+, d6-d7
  004904:  4e 75                  rts 
  004906:  4e 75                  rts 
  004908:  48 e7 01 08            movem.l d7/a4, -(a7)
  00490c:  7e 00                  moveq #$0, d7
  00490e:  1e 2d b9 46            move.b -$46ba(a5), d7
  004912:  0c 47 00 e5            cmpi.w #$e5, d7
  004916:  6d 06                  blt.b $491e
  004918:  0c 47 00 ee            cmpi.w #$ee, d7
  00491c:  6d 14                  blt.b $4932
  00491e:  4a 2d b9 52            tst.b -$46ae(a5)
  004922:  66 0e                  bne.b $4932
  004924:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  00492a:  66 60                  bne.b $498c
  00492c:  4a 2d b9 53            tst.b -$46ad(a5)
  004930:  6c 5a                  bge.b $498c
  004932:  7e 00                  moveq #$0, d7
  004934:  1e 2d b9 8f            move.b -$4671(a5), d7
  004938:  02 47 00 3f            andi.w #$3f, d7
  00493c:  4a 47                  tst.w d7
  00493e:  67 4c                  beq.b $498c
  004940:  20 07                  move.l d7, d0
  004942:  48 c0                  ext.l d0
  004944:  e5 88                  lsl.l #$2, d0
  004946:  49 ed b3 34            lea.l -$4ccc(a5), a4
  00494a:  d0 8c                  add.l a4, d0
  00494c:  28 40                  movea.l d0, a4
  00494e:  70 00                  moveq #$0, d0
  004950:  10 14                  move.b (a4), d0
  004952:  3b 40 ba f4            move.w d0, -$450c(a5)
  004956:  0c 40 00 ff            cmpi.w #$ff, d0
  00495a:  67 30                  beq.b $498c
  00495c:  3f 2d ba f6            move.w -$450a(a5), -(a7)
  004960:  4e ad 04 fa            jsr $4fa(a5)
  004964:  3b 40 ba f6            move.w d0, -$450a(a5)
  004968:  12 2c 00 01            move.b $1(a4), d1
  00496c:  48 81                  ext.w d1
  00496e:  3e 81                  move.w d1, (a7)
  004970:  4e ba e9 ba            jsr $332c(pc)
  004974:  10 2c 00 02            move.b $2(a4), d0
  004978:  48 80                  ext.w d0
  00497a:  d1 6d ba f8            add.w d0, -$4508(a5)
  00497e:  42 6d ba f2            clr.w -$450e(a5)
  004982:  1e bc 00 03            move.b #$3, (a7)
  004986:  4e ad 04 ea            jsr $4ea(a5)
  00498a:  54 8f                  addq.l #$2, a7
  00498c:  4c df 10 80            movem.l (a7)+, d7/a4
  004990:  4e 75                  rts 
  004992:  0c 2d 00 a6 b9 46      cmpi.b #$a6, -$46ba(a5)
  004998:  66 22                  bne.b $49bc
  00499a:  4a 2d ba ad            tst.b -$4553(a5)
  00499e:  6c 1c                  bge.b $49bc
  0049a0:  4a 2d ba aa            tst.b -$4556(a5)
  0049a4:  6c 06                  bge.b $49ac
  0049a6:  4e ad 05 42            jsr $542(a5)
  0049aa:  60 10                  bra.b $49bc
  0049ac:  1b 7c 00 01 ba ad      move.b #$1, -$4553(a5)
  0049b2:  3f 3c 00 50            move.w #$50, -(a7)
  0049b6:  4e ad 05 22            jsr $522(a5)
  0049ba:  54 8f                  addq.l #$2, a7
  0049bc:  4e 75                  rts 
  0049be:  2f 07                  move.l d7, -(a7)
  0049c0:  10 2d b9 4f            move.b -$46b1(a5), d0
  0049c4:  b0 2d b9 61            cmp.b -$469f(a5), d0
  0049c8:  67 06                  beq.b $49d0
  0049ca:  30 3c 03 e7            move.w #$3e7, d0
  0049ce:  60 2a                  bra.b $49fa
  0049d0:  70 00                  moveq #$0, d0
  0049d2:  10 2d b9 47            move.b -$46b9(a5), d0
  0049d6:  7e 00                  moveq #$0, d7
  0049d8:  1e 2d b9 59            move.b -$46a7(a5), d7
  0049dc:  9e 40                  sub.w d0, d7
  0049de:  4a 2d b9 49            tst.b -$46b7(a5)
  0049e2:  6c 02                  bge.b $49e6
  0049e4:  44 47                  neg.w d7
  0049e6:  4a 47                  tst.w d7
  0049e8:  6d 0e                  blt.b $49f8
  0049ea:  10 2d b9 49            move.b -$46b7(a5), d0
  0049ee:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  0049f2:  67 04                  beq.b $49f8
  0049f4:  06 47 00 0d            addi.w #$d, d7
  0049f8:  30 07                  move.w d7, d0
  0049fa:  2e 1f                  move.l (a7)+, d7
  0049fc:  4e 75                  rts 
  0049fe:  52 2d b9 4b            addq.b #$1, -$46b5(a5)
  004a02:  4e 75                  rts 