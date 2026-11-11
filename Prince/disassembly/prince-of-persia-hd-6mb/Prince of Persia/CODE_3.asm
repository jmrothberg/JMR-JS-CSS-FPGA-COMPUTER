; prince-of-persia-hd-6mb: Prince of Persia/Prince of Persia, CODE resource 3 (22842 bytes)
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
  000042:  4e ad 00 da            jsr $da(a5)
  000046:  54 8f                  addq.l #$2, a7
  000048:  52 47                  addq.w #$1, d7
  00004a:  0c 47 00 2c            cmpi.w #$2c, d7
  00004e:  6d f0                  blt.b $40
  000050:  2e 1f                  move.l (a7)+, d7
  000052:  4e 75                  rts 
  000054:  48 6d a5 c4            pea.l -$5a3c(a5)
  000058:  a8 a2                  dc.w $a8a2
  00005a:  4e ba 0e f6            jsr $f52(pc)
  00005e:  4e 75                  rts 
  000060:  4e ad 04 aa            jsr $4aa(a5)
  000064:  4e ad 04 1a            jsr $41a(a5)
  000068:  4e ba 3b ce            jsr $3c38(pc)
  00006c:  4e ba 18 7a            jsr $18e8(pc)
  000070:  4e ba 03 76            jsr $3e8(pc)
  000074:  4a 40                  tst.w d0
  000076:  66 00 00 94            bne.w $10c
  00007a:  4e ba 04 0e            jsr $48a(pc)
  00007e:  4e ba 3a c8            jsr $3b48(pc)
  000082:  4e ba 3a 78            jsr $3afc(pc)
  000086:  4e ba 07 c2            jsr $84a(pc)
  00008a:  4e ba 06 c2            jsr $74e(pc)
  00008e:  4e ba 2f f8            jsr $3088(pc)
  000092:  4e ba 04 66            jsr $4fa(pc)
  000096:  4e ba 2e 3c            jsr $2ed4(pc)
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
  0000ca:  4e ad 01 02            jsr $102(a5)
  0000ce:  1b 7c 00 ff b9 6c      move.b #$ff, -$4694(a5)
  0000d4:  70 01                  moveq #$1, d0
  0000d6:  d0 6d a9 0c            add.w -$56f4(a5), d0
  0000da:  3b 40 ba 38            move.w d0, -$45c8(a5)
  0000de:  60 2c                  bra.b $10c
  0000e0:  0c 2d 00 17 b9 73      cmpi.b #$17, -$468d(a5)
  0000e6:  66 24                  bne.b $10c
  0000e8:  4e ad 01 02            jsr $102(a5)
  0000ec:  70 01                  moveq #$1, d0
  0000ee:  d0 6d a9 0c            add.w -$56f4(a5), d0
  0000f2:  3b 40 ba 38            move.w d0, -$45c8(a5)
  0000f6:  3b 7c 00 01 ba 22      move.w #$1, -$45de(a5)
  0000fc:  60 0e                  bra.b $10c
  0000fe:  0c 2d 00 05 b9 73      cmpi.b #$5, -$468d(a5)
  000104:  66 06                  bne.b $10c
  000106:  3b 7c 00 01 96 30      move.w #$1, -$69d0(a5)
  00010c:  4e ad 05 32            jsr $532(a5)
  000110:  4a 6d ba 8c            tst.w -$4574(a5)
  000114:  66 14                  bne.b $12a
  000116:  4a 6d ba 86            tst.w -$457a(a5)
  00011a:  66 0e                  bne.b $12a
  00011c:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  000122:  6c 06                  bge.b $12a
  000124:  3b 7c 00 02 96 30      move.w #$2, -$69d0(a5)
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
  000168:  4e ba 12 4e            jsr $13b8(pc)
  00016c:  42 6d b9 40            clr.w -$46c0(a5)
  000170:  54 8f                  addq.l #$2, a7
  000172:  60 08                  bra.b $17c
  000174:  4e ad 04 f2            jsr $4f2(a5)
  000178:  4e ad 05 02            jsr $502(a5)
  00017c:  4e ba 0e 20            jsr $f9e(pc)
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
  0001b8:  4e ad 05 4a            jsr $54a(a5)
  0001bc:  54 8f                  addq.l #$2, a7
  0001be:  60 3a                  bra.b $1fa
  0001c0:  0c 47 00 03            cmpi.w #$3, d7
  0001c4:  66 34                  bne.b $1fa
  0001c6:  48 6d 96 a0            pea.l -$6960(a5)
  0001ca:  4e ad 05 42            jsr $542(a5)
  0001ce:  3e bc 00 26            move.w #$26, (a7)
  0001d2:  4e ad 00 fa            jsr $fa(a5)
  0001d6:  58 8f                  addq.l #$4, a7
  0001d8:  60 20                  bra.b $1fa
  0001da:  0c 6d 00 24 ba 90      cmpi.w #$24, -$4570(a5)
  0001e0:  67 08                  beq.b $1ea
  0001e2:  0c 6d 01 b0 ba 90      cmpi.w #$1b0, -$4570(a5)
  0001e8:  66 06                  bne.b $1f0
  0001ea:  3b 7c 00 03 96 30      move.w #$3, -$69d0(a5)
  0001f0:  3f 3c 00 01            move.w #$1, -(a7)
  0001f4:  4e ad 05 4a            jsr $54a(a5)
  0001f8:  54 8f                  addq.l #$2, a7
  0001fa:  2e 1f                  move.l (a7)+, d7
  0001fc:  4e 75                  rts 
  0001fe:  2f 07                  move.l d7, -(a7)
  000200:  7e 00                  moveq #$0, d7
  000202:  60 4e                  bra.b $252
  000204:  3f 07                  move.w d7, -(a7)
  000206:  4e ad 04 a2            jsr $4a2(a5)
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
  00022e:  4e ad 04 4a            jsr $44a(a5)
  000232:  58 8f                  addq.l #$4, a7
  000234:  60 1a                  bra.b $250
  000236:  3f 07                  move.w d7, -(a7)
  000238:  3f 2d ba 6a            move.w -$4596(a5), -(a7)
  00023c:  4e ad 04 52            jsr $452(a5)
  000240:  58 8f                  addq.l #$4, a7
  000242:  60 0c                  bra.b $250
  000244:  3f 07                  move.w d7, -(a7)
  000246:  3f 2d ba 6a            move.w -$4596(a5), -(a7)
  00024a:  4e ad 04 5a            jsr $45a(a5)
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
  00029a:  4e ba 0c f2            jsr $f8e(pc)
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
  000346:  4e ad 00 da            jsr $da(a5)
  00034a:  54 8f                  addq.l #$2, a7
  00034c:  20 4d                  movea.l a5, a0
  00034e:  d0 c7                  adda.w d7, a0
  000350:  4a 28 a8 6c            tst.b -$5794(a0)
  000354:  67 0a                  beq.b $360
  000356:  3f 3c 00 2d            move.w #$2d, -(a7)
  00035a:  4e ad 00 da            jsr $da(a5)
  00035e:  54 8f                  addq.l #$2, a7
  000360:  20 4d                  movea.l a5, a0
  000362:  d0 c7                  adda.w d7, a0
  000364:  4a 28 a8 9c            tst.b -$5764(a0)
  000368:  67 12                  beq.b $37c
  00036a:  3f 3c 00 2f            move.w #$2f, -(a7)
  00036e:  4e ad 00 da            jsr $da(a5)
  000372:  3e bc 00 2e            move.w #$2e, (a7)
  000376:  4e ad 00 da            jsr $da(a5)
  00037a:  54 8f                  addq.l #$2, a7
  00037c:  20 4d                  movea.l a5, a0
  00037e:  d0 c7                  adda.w d7, a0
  000380:  4a 28 a8 ac            tst.b -$5754(a0)
  000384:  67 12                  beq.b $398
  000386:  3f 3c 00 31            move.w #$31, -(a7)
  00038a:  4e ad 00 da            jsr $da(a5)
  00038e:  3e bc 00 30            move.w #$30, (a7)
  000392:  4e ad 00 da            jsr $da(a5)
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
  0003bc:  4e ad 00 ca            jsr $ca(a5)
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
  0003e0:  4e ad 04 ea            jsr $4ea(a5)
  0003e4:  28 5f                  movea.l (a7)+, a4
  0003e6:  4e 75                  rts 
  0003e8:  4e ba 40 e6            jsr $44d0(pc)
  0003ec:  4e ba 3c de            jsr $40cc(pc)
  0003f0:  4e ba 54 0e            jsr $5800(pc)
  0003f4:  4e ba 48 2c            jsr $4c22(pc)
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
  000428:  4e ad 05 4a            jsr $54a(a5)
  00042c:  4e ad 01 02            jsr $102(a5)
  000430:  3b 7c 00 01 ba 66      move.w #$1, -$459a(a5)
  000436:  70 01                  moveq #$1, d0
  000438:  54 8f                  addq.l #$2, a7
  00043a:  60 4c                  bra.b $488
  00043c:  4a 2d b9 4f            tst.b -$46b1(a5)
  000440:  67 40                  beq.b $482
  000442:  4e ba 3e 06            jsr $424a(pc)
  000446:  4e ba 41 52            jsr $459a(pc)
  00044a:  4e ba 41 84            jsr $45d0(pc)
  00044e:  4e ad 05 22            jsr $522(a5)
  000452:  4e ba 3c 78            jsr $40cc(pc)
  000456:  4e ba 43 2a            jsr $4782(pc)
  00045a:  4e ba 13 d6            jsr $1832(pc)
  00045e:  4e ad 03 e2            jsr $3e2(a5)
  000462:  4e ad 03 ea            jsr $3ea(a5)
  000466:  4e ad 04 02            jsr $402(a5)
  00046a:  4e ba 41 8c            jsr $45f8(pc)
  00046e:  4e ba 4c 6e            jsr $50de(pc)
  000472:  4e ba 4d 1e            jsr $5192(pc)
  000476:  4e ba 42 20            jsr $4698(pc)
  00047a:  4e ad 03 fa            jsr $3fa(a5)
  00047e:  4e ba 11 f0            jsr $1670(pc)
  000482:  4e ba 40 10            jsr $4494(pc)
  000486:  70 00                  moveq #$0, d0
  000488:  4e 75                  rts 
  00048a:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  000490:  67 66                  beq.b $4f8
  000492:  4e ba 40 88            jsr $451c(pc)
  000496:  4e ba 3c 34            jsr $40cc(pc)
  00049a:  4e ba 53 64            jsr $5800(pc)
  00049e:  4e ba 48 9a            jsr $4d3a(pc)
  0004a2:  10 2d b9 4f            move.b -$46b1(a5), d0
  0004a6:  48 80                  ext.w d0
  0004a8:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  0004ac:  66 46                  bne.b $4f4
  0004ae:  4a 6d ba 2c            tst.w -$45d4(a5)
  0004b2:  67 40                  beq.b $4f4
  0004b4:  4e ba 3d 94            jsr $424a(pc)
  0004b8:  0c 2d 00 2c b9 47      cmpi.b #$2c, -$46b9(a5)
  0004be:  65 34                  bcs.b $4f4
  0004c0:  0c 2d 00 d3 b9 47      cmpi.b #$d3, -$46b9(a5)
  0004c6:  64 2c                  bcc.b $4f4
  0004c8:  4e ba 40 d0            jsr $459a(pc)
  0004cc:  4e ba 41 02            jsr $45d0(pc)
  0004d0:  4e ad 05 22            jsr $522(a5)
  0004d4:  4e ba 3b f6            jsr $40cc(pc)
  0004d8:  4e ba 42 a8            jsr $4782(pc)
  0004dc:  4e ad 04 0a            jsr $40a(a5)
  0004e0:  4e ba 41 16            jsr $45f8(pc)
  0004e4:  4e ba 4b f8            jsr $50de(pc)
  0004e8:  4e ba 4c a8            jsr $5192(pc)
  0004ec:  4e ba 41 aa            jsr $4698(pc)
  0004f0:  4e ad 04 12            jsr $412(a5)
  0004f4:  4e ba 3f c6            jsr $44bc(pc)
  0004f8:  4e 75                  rts 
  0004fa:  4a 6d ba 7c            tst.w -$4584(a5)
  0004fe:  67 2e                  beq.b $52e
  000500:  30 2d ba 7c            move.w -$4584(a5), d0
  000504:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  000508:  67 24                  beq.b $52e
  00050a:  3b 6d ba 7c ba 6a      move.w -$4584(a5), -$4596(a5)
  000510:  4e ad 04 c2            jsr $4c2(a5)
  000514:  3b 7c 00 01 ba 7e      move.w #$1, -$4582(a5)
  00051a:  4e ba 3f 64            jsr $4480(pc)
  00051e:  4e ba fc de            jsr $1fe(pc)
  000522:  4e ad 04 92            jsr $492(a5)
  000526:  4e ba 00 08            jsr $530(pc)
  00052a:  4e ba 27 36            jsr $2c62(pc)
  00052e:  4e 75                  rts 
  000530:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  000536:  66 4e                  bne.b $586
  000538:  0c 6d 00 17 ba 6a      cmpi.w #$17, -$4596(a5)
  00053e:  67 08                  beq.b $548
  000540:  0c 6d 00 10 ba 6a      cmpi.w #$10, -$4596(a5)
  000546:  66 3e                  bne.b $586
  000548:  3b 6d ba 70 ba ea      move.w -$4590(a5), -$4516(a5)
  00054e:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  000552:  4e ad 05 12            jsr $512(a5)
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
  000574:  4e ad 04 8a            jsr $48a(a5)
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
  0005b4:  3e 2d 98 6e            move.w -$6792(a5), d7
  0005b8:  3c 2d 98 76            move.w -$678a(a5), d6
  0005bc:  3a 2d 9d f0            move.w -$6210(a5), d5
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
  000664:  3c 2d 9a ce            move.w -$6532(a5), d6
  000668:  3a 2d 98 76            move.w -$678a(a5), d5
  00066c:  38 2d 9d f0            move.w -$6210(a5), d4
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
  0007e6:  4e ad 01 0a            jsr $10a(a5)
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
  00082c:  3b 7c 00 0c 96 56      move.w #$c, -$69aa(a5)
  000832:  3f 2d a9 0e            move.w -$56f2(a5), -(a7)
  000836:  4e ad 00 fa            jsr $fa(a5)
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
  0008ba:  4e ad 00 ca            jsr $ca(a5)
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
  0008ea:  4e ad 00 ca            jsr $ca(a5)
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
  000908:  4e ad 00 d2            jsr $d2(a5)
  00090c:  4a 00                  tst.b d0
  00090e:  58 8f                  addq.l #$4, a7
  000910:  66 00 00 a2            bne.w $9b4
  000914:  42 67                  clr.w -(a7)
  000916:  2f 2d a1 68            move.l -$5e98(a5), -(a7)
  00091a:  3f 2d a0 be            move.w -$5f42(a5), -(a7)
  00091e:  48 6d a1 66            pea.l -$5e9a(a5)
  000922:  4e ad 01 8a            jsr $18a(a5)
  000926:  38 1f                  move.w (a7)+, d4
  000928:  3f 04                  move.w d4, -(a7)
  00092a:  4e ad 00 c2            jsr $c2(a5)
  00092e:  4a 00                  tst.b d0
  000930:  54 8f                  addq.l #$2, a7
  000932:  66 00 00 80            bne.w $9b4
  000936:  42 67                  clr.w -(a7)
  000938:  3f 2d a1 66            move.w -$5e9a(a5), -(a7)
  00093c:  3f 3c 00 01            move.w #$1, -(a7)
  000940:  2f 05                  move.l d5, -(a7)
  000942:  4e ad 01 a2            jsr $1a2(a5)
  000946:  38 1f                  move.w (a7)+, d4
  000948:  3f 04                  move.w d4, -(a7)
  00094a:  4e ad 00 c2            jsr $c2(a5)
  00094e:  4a 00                  tst.b d0
  000950:  54 8f                  addq.l #$2, a7
  000952:  66 60                  bne.b $9b4
  000954:  20 4c                  movea.l a4, a0
  000956:  a0 29                  dc.w $a029
  000958:  42 67                  clr.w -(a7)
  00095a:  3f 2d a1 66            move.w -$5e9a(a5), -(a7)
  00095e:  48 6e ff fc            pea.l -$4(a6)
  000962:  2f 14                  move.l (a4), -(a7)
  000964:  4e ad 01 9a            jsr $19a(a5)
  000968:  38 1f                  move.w (a7)+, d4
  00096a:  3f 04                  move.w d4, -(a7)
  00096c:  4e ad 00 c2            jsr $c2(a5)
  000970:  4a 00                  tst.b d0
  000972:  54 8f                  addq.l #$2, a7
  000974:  66 3e                  bne.b $9b4
  000976:  42 67                  clr.w -(a7)
  000978:  3f 2d a1 66            move.w -$5e9a(a5), -(a7)
  00097c:  4e ad 01 92            jsr $192(a5)
  000980:  20 4c                  movea.l a4, a0
  000982:  a0 2a                  dc.w $a02a
  000984:  20 03                  move.l d3, d0
  000986:  a1 22                  dc.w $a122
  000988:  24 48                  movea.l a0, a2
  00098a:  2f 0a                  move.l a2, -(a7)
  00098c:  4e ad 00 d2            jsr $d2(a5)
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
  0009c4:  4e ad 05 0a            jsr $50a(a5)
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
  000b62:  4e ad 01 02            jsr $102(a5)
  000b66:  3f 3c 00 27            move.w #$27, -(a7)
  000b6a:  4e ba fc 48            jsr $7b4(pc)
  000b6e:  54 8f                  addq.l #$2, a7
  000b70:  4e 75                  rts 
  000b72:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  000b76:  2b 6d 96 22 96 26      move.l -$69de(a5), -$69da(a5)
  000b7c:  30 6d ba 6a            movea.w -$4596(a5), a0
  000b80:  2b 48 96 22            move.l a0, -$69de(a5)
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
  000be6:  2b 6d 96 26 96 22      move.l -$69da(a5), -$69de(a5)
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
  000c0e:  4e ba 02 fc            jsr $f0c(pc)
  000c12:  3f 3c 00 36            move.w #$36, -(a7)
  000c16:  4e ad 00 da            jsr $da(a5)
  000c1a:  3e bc 00 37            move.w #$37, (a7)
  000c1e:  4e ad 00 da            jsr $da(a5)
  000c22:  1b 7c 00 01 96 45      move.b #$1, -$69bb(a5)
  000c28:  4e ad 00 ea            jsr $ea(a5)
  000c2c:  54 8f                  addq.l #$2, a7
  000c2e:  60 00 02 7c            bra.w $eac
  000c32:  3f 3c 00 02            move.w #$2, -(a7)
  000c36:  4e ba 02 9e            jsr $ed6(pc)
  000c3a:  48 78 00 01            pea.l $1.w
  000c3e:  42 a7                  clr.l -(a7)
  000c40:  3f 3c 00 04            move.w #$4, -(a7)
  000c44:  4e ad 04 e2            jsr $4e2(a5)
  000c48:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  000c4e:  4f ef 00 0c            lea.l $c(a7), a7
  000c52:  60 00 02 58            bra.w $eac
  000c56:  3f 3c 00 36            move.w #$36, -(a7)
  000c5a:  4e ad 00 fa            jsr $fa(a5)
  000c5e:  3b 7c 00 05 a5 68      move.w #$5, -$5a98(a5)
  000c64:  2b 7c 00 00 00 f2 a5 6c move.l #$f2, -$5a94(a5)
  000c6c:  54 8f                  addq.l #$2, a7
  000c6e:  60 00 02 3c            bra.w $eac
  000c72:  2f 3c 00 6a 00 01      move.l #$6a0001, -(a7)
  000c78:  2f 3c 00 01 00 5c      move.l #$1005c, -(a7)
  000c7e:  3f 3c 00 04            move.w #$4, -(a7)
  000c82:  4e ad 04 e2            jsr $4e2(a5)
  000c86:  3b 7c 00 11 a5 68      move.w #$11, -$5a98(a5)
  000c8c:  4f ef 00 0a            lea.l $a(a7), a7
  000c90:  60 00 02 1a            bra.w $eac
  000c94:  48 78 00 01            pea.l $1.w
  000c98:  42 a7                  clr.l -(a7)
  000c9a:  3f 3c 00 04            move.w #$4, -(a7)
  000c9e:  4e ad 04 e2            jsr $4e2(a5)
  000ca2:  3b 7c 00 05 a5 68      move.w #$5, -$5a98(a5)
  000ca8:  2b 7c 00 00 01 f3 a5 6c move.l #$1f3, -$5a94(a5)
  000cb0:  4f ef 00 0a            lea.l $a(a7), a7
  000cb4:  60 00 01 f6            bra.w $eac
  000cb8:  2f 3c 00 7a 00 01      move.l #$7a0001, -(a7)
  000cbe:  2f 3c 00 02 00 60      move.l #$20060, -(a7)
  000cc4:  3f 3c 00 04            move.w #$4, -(a7)
  000cc8:  4e ad 04 e2            jsr $4e2(a5)
  000ccc:  3b 7c 00 19 a5 68      move.w #$19, -$5a98(a5)
  000cd2:  4f ef 00 0a            lea.l $a(a7), a7
  000cd6:  60 00 01 d4            bra.w $eac
  000cda:  48 78 00 01            pea.l $1.w
  000cde:  42 a7                  clr.l -(a7)
  000ce0:  3f 3c 00 04            move.w #$4, -(a7)
  000ce4:  4e ad 04 e2            jsr $4e2(a5)
  000ce8:  3b 7c 00 0f a5 68      move.w #$f, -$5a98(a5)
  000cee:  2b 7c 00 00 03 c8 a5 6c move.l #$3c8, -$5a94(a5)
  000cf6:  4f ef 00 0a            lea.l $a(a7), a7
  000cfa:  60 00 01 b0            bra.w $eac
  000cfe:  2f 3c 00 6b 00 01      move.l #$6b0001, -(a7)
  000d04:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  000d0a:  3f 3c 00 04            move.w #$4, -(a7)
  000d0e:  4e ad 04 e2            jsr $4e2(a5)
  000d12:  2e bc 00 b8 00 01      move.l #$b80001, (a7)
  000d18:  2f 3c 00 04 00 28      move.l #$40028, -(a7)
  000d1e:  3f 3c 00 04            move.w #$4, -(a7)
  000d22:  4e ad 04 e2            jsr $4e2(a5)
  000d26:  3b 7c 00 23 a5 68      move.w #$23, -$5a98(a5)
  000d2c:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  000d32:  4f ef 00 10            lea.l $10(a7), a7
  000d36:  60 00 01 74            bra.w $eac
  000d3a:  3f 3c 00 17            move.w #$17, -(a7)
  000d3e:  4e ba 01 96            jsr $ed6(pc)
  000d42:  2f 3c 00 19 00 01      move.l #$190001, -(a7)
  000d48:  2f 3c 00 01 00 18      move.l #$10018, -(a7)
  000d4e:  3f 3c 00 03            move.w #$3, -(a7)
  000d52:  4e ad 04 e2            jsr $4e2(a5)
  000d56:  3b 7c 00 07 a5 5c      move.w #$7, -$5aa4(a5)
  000d5c:  4f ef 00 0c            lea.l $c(a7), a7
  000d60:  60 00 01 4a            bra.w $eac
  000d64:  3f 3c 00 37            move.w #$37, -(a7)
  000d68:  4e ad 00 fa            jsr $fa(a5)
  000d6c:  3b 7c 00 4b a5 68      move.w #$4b, -$5a98(a5)
  000d72:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  000d78:  54 8f                  addq.l #$2, a7
  000d7a:  60 00 01 30            bra.w $eac
  000d7e:  48 6d 02 42            pea.l $242(a5)
  000d82:  42 67                  clr.w -(a7)
  000d84:  4e ba 1a 24            jsr $27aa(pc)
  000d88:  5c 8f                  addq.l #$6, a7
  000d8a:  60 00 01 20            bra.w $eac
  000d8e:  4e ba 01 7c            jsr $f0c(pc)
  000d92:  3f 3c 00 34            move.w #$34, -(a7)
  000d96:  4e ad 00 da            jsr $da(a5)
  000d9a:  1b 7c 00 01 96 45      move.b #$1, -$69bb(a5)
  000da0:  4e ad 00 ea            jsr $ea(a5)
  000da4:  54 8f                  addq.l #$2, a7
  000da6:  60 00 01 04            bra.w $eac
  000daa:  3f 3c 00 17            move.w #$17, -(a7)
  000dae:  4e ba 01 26            jsr $ed6(pc)
  000db2:  2f 3c 00 19 00 01      move.l #$190001, -(a7)
  000db8:  2f 3c 00 02 00 18      move.l #$20018, -(a7)
  000dbe:  3f 3c 00 03            move.w #$3, -(a7)
  000dc2:  4e ad 04 e2            jsr $4e2(a5)
  000dc6:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  000dcc:  4f ef 00 0c            lea.l $c(a7), a7
  000dd0:  60 00 00 da            bra.w $eac
  000dd4:  3f 3c 00 34            move.w #$34, -(a7)
  000dd8:  4e ad 00 fa            jsr $fa(a5)
  000ddc:  3b 7c 00 64 a5 68      move.w #$64, -$5a98(a5)
  000de2:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  000de8:  54 8f                  addq.l #$2, a7
  000dea:  60 00 00 c0            bra.w $eac
  000dee:  48 78 00 01            pea.l $1.w
  000df2:  42 a7                  clr.l -(a7)
  000df4:  3f 3c 00 04            move.w #$4, -(a7)
  000df8:  4e ad 04 e2            jsr $4e2(a5)
  000dfc:  2e bc 00 6b 00 01      move.l #$6b0001, (a7)
  000e02:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  000e08:  3f 3c 00 04            move.w #$4, -(a7)
  000e0c:  4e ad 04 e2            jsr $4e2(a5)
  000e10:  2e bc 00 b8 00 01      move.l #$b80001, (a7)
  000e16:  2f 3c 00 04 00 28      move.l #$40028, -(a7)
  000e1c:  3f 3c 00 04            move.w #$4, -(a7)
  000e20:  4e ad 04 e2            jsr $4e2(a5)
  000e24:  3b 7c 00 02 a5 5c      move.w #$2, -$5aa4(a5)
  000e2a:  3b 7c 00 3c a5 68      move.w #$3c, -$5a98(a5)
  000e30:  4f ef 00 16            lea.l $16(a7), a7
  000e34:  60 76                  bra.b $eac
  000e36:  3f 3c 00 1b            move.w #$1b, -(a7)
  000e3a:  4e ba 00 9a            jsr $ed6(pc)
  000e3e:  2f 3c 00 1a 00 01      move.l #$1a0001, -(a7)
  000e44:  2f 3c 00 04 00 18      move.l #$40018, -(a7)
  000e4a:  3f 3c 00 03            move.w #$3, -(a7)
  000e4e:  4e ad 04 e2            jsr $4e2(a5)
  000e52:  3b 7c 00 09 a5 5c      move.w #$9, -$5aa4(a5)
  000e58:  3b 7c 00 2d a5 68      move.w #$2d, -$5a98(a5)
  000e5e:  4f ef 00 0c            lea.l $c(a7), a7
  000e62:  60 48                  bra.b $eac
  000e64:  4a 6d a5 58            tst.w -$5aa8(a5)
  000e68:  66 42                  bne.b $eac
  000e6a:  52 6d a5 66            addq.w #$1, -$5a9a(a5)
  000e6e:  60 3c                  bra.b $eac
  000e70:  3f 3c 00 1b            move.w #$1b, -(a7)
  000e74:  4e ba 00 60            jsr $ed6(pc)
  000e78:  2f 3c 00 14 00 01      move.l #$140001, -(a7)
  000e7e:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  000e84:  3f 3c 00 04            move.w #$4, -(a7)
  000e88:  4e ad 04 e2            jsr $4e2(a5)
  000e8c:  4e ba 1c 84            jsr $2b12(pc)
  000e90:  3b 7c 00 09 a5 5c      move.w #$9, -$5aa4(a5)
  000e96:  3b 7c 00 32 a5 68      move.w #$32, -$5a98(a5)
  000e9c:  4f ef 00 0c            lea.l $c(a7), a7
  000ea0:  60 0a                  bra.b $eac
  000ea2:  4e ba 00 92            jsr $f36(pc)
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
  000ed4:  4e 75                  rts 
  000ed6:  4e 56 00 00            link.w a6, #$0
  000eda:  48 78 00 01            pea.l $1.w
  000ede:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  000ee4:  3f 3c 00 03            move.w #$3, -(a7)
  000ee8:  4e ad 01 1a            jsr $11a(a5)
  000eec:  1e ae 00 09            move.b $9(a6), (a7)
  000ef0:  48 6d a5 f4            pea.l -$5a0c(a5)
  000ef4:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  000ef8:  4e 90                  jsr (a0)
  000efa:  70 01                  moveq #$1, d0
  000efc:  2e 80                  move.l d0, (a7)
  000efe:  42 a7                  clr.l -(a7)
  000f00:  3f 3c 00 03            move.w #$3, -(a7)
  000f04:  4e ad 04 e2            jsr $4e2(a5)
  000f08:  4e 5e                  unlk a6
  000f0a:  4e 75                  rts 
  000f0c:  2f 3c 00 03 00 28      move.l #$30028, -(a7)
  000f12:  4e ba f9 52            jsr $866(pc)
  000f16:  2e bc 00 04 00 32      move.l #$40032, (a7)
  000f1c:  4e ba f9 48            jsr $866(pc)
  000f20:  3b 7c 00 01 f2 28      move.w #$1, -$dd8(a5)
  000f26:  2b 6d a5 c4 a2 e4      move.l -$5a3c(a5), -$5d1c(a5)
  000f2c:  2b 6d a5 c8 a2 e8      move.l -$5a38(a5), -$5d18(a5)
  000f32:  58 8f                  addq.l #$4, a7
  000f34:  4e 75                  rts 
  000f36:  4e ad 01 02            jsr $102(a5)
  000f3a:  4e ad 00 f2            jsr $f2(a5)
  000f3e:  4e ba 00 34            jsr $f74(pc)
  000f42:  3f 3c 00 03            move.w #$3, -(a7)
  000f46:  4e ba fa 76            jsr $9be(pc)
  000f4a:  42 6d f2 28            clr.w -$dd8(a5)
  000f4e:  54 8f                  addq.l #$2, a7
  000f50:  4e 75                  rts 
  000f52:  4e ad 01 02            jsr $102(a5)
  000f56:  4e ad 00 f2            jsr $f2(a5)
  000f5a:  4e ba 00 18            jsr $f74(pc)
  000f5e:  3f 3c 00 03            move.w #$3, -(a7)
  000f62:  4e ba fa 5a            jsr $9be(pc)
  000f66:  3b 7c ff ff a9 0c      move.w #$ffff, -$56f4(a5)
  000f6c:  42 2d a5 be            clr.b -$5a42(a5)
  000f70:  54 8f                  addq.l #$2, a7
  000f72:  4e 75                  rts 
  000f74:  2f 07                  move.l d7, -(a7)
  000f76:  7e 2c                  moveq #$2c, d7
  000f78:  60 0a                  bra.b $f84
  000f7a:  3f 07                  move.w d7, -(a7)
  000f7c:  4e ad 00 e2            jsr $e2(a5)
  000f80:  54 8f                  addq.l #$2, a7
  000f82:  52 47                  addq.w #$1, d7
  000f84:  0c 47 00 3a            cmpi.w #$3a, d7
  000f88:  6d f0                  blt.b $f7a
  000f8a:  2e 1f                  move.l (a7)+, d7
  000f8c:  4e 75                  rts 
  000f8e:  4e ba ff e4            jsr $f74(pc)
  000f92:  3f 3c 00 03            move.w #$3, -(a7)
  000f96:  4e ba fa 26            jsr $9be(pc)
  000f9a:  54 8f                  addq.l #$2, a7
  000f9c:  4e 75                  rts 
  000f9e:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  000fa2:  4a 2d a2 0f            tst.b -$5df1(a5)
  000fa6:  67 00 01 20            beq.w $10c8
  000faa:  20 6d a2 32            movea.l -$5dce(a5), a0
  000fae:  70 08                  moveq #$8, d0
  000fb0:  d0 90                  add.l (a0), d0
  000fb2:  28 40                  movea.l d0, a4
  000fb4:  22 6d a2 58            movea.l -$5da8(a5), a1
  000fb8:  70 08                  moveq #$8, d0
  000fba:  d0 91                  add.l (a1), d0
  000fbc:  26 40                  movea.l d0, a3
  000fbe:  7e 00                  moveq #$0, d7
  000fc0:  60 00 00 ea            bra.w $10ac
  000fc4:  3f 3c 00 63            move.w #$63, -(a7)
  000fc8:  4e ad 00 72            jsr $72(a5)
  000fcc:  3c 00                  move.w d0, d6
  000fce:  0c 47 00 02            cmpi.w #$2, d7
  000fd2:  54 8f                  addq.l #$2, a7
  000fd4:  6e 00 00 92            bgt.w $1068
  000fd8:  0c 46 00 5c            cmpi.w #$5c, d6
  000fdc:  6c 64                  bge.b $1042
  000fde:  3f 3c 00 63            move.w #$63, -(a7)
  000fe2:  4e ad 00 72            jsr $72(a5)
  000fe6:  3c 00                  move.w d0, d6
  000fe8:  0c 46 00 0a            cmpi.w #$a, d6
  000fec:  54 8f                  addq.l #$2, a7
  000fee:  6c 1a                  bge.b $100a
  000ff0:  20 4c                  movea.l a4, a0
  000ff2:  20 07                  move.l d7, d0
  000ff4:  48 c0                  ext.l d0
  000ff6:  e7 88                  lsl.l #$3, d0
  000ff8:  d1 c0                  adda.l d0, a0
  000ffa:  21 6c 00 2a 06 22      move.l $2a(a4), $622(a0)
  001000:  31 6c 00 2e 06 26      move.w $2e(a4), $626(a0)
  001006:  60 00 00 a2            bra.w $10aa
  00100a:  0c 46 00 28            cmpi.w #$28, d6
  00100e:  6c 1a                  bge.b $102a
  001010:  20 4c                  movea.l a4, a0
  001012:  20 07                  move.l d7, d0
  001014:  48 c0                  ext.l d0
  001016:  e7 88                  lsl.l #$3, d0
  001018:  d1 c0                  adda.l d0, a0
  00101a:  21 6c 00 32 06 22      move.l $32(a4), $622(a0)
  001020:  31 6c 00 36 06 26      move.w $36(a4), $626(a0)
  001026:  60 00 00 82            bra.w $10aa
  00102a:  20 4c                  movea.l a4, a0
  00102c:  20 07                  move.l d7, d0
  00102e:  48 c0                  ext.l d0
  001030:  e7 88                  lsl.l #$3, d0
  001032:  d1 c0                  adda.l d0, a0
  001034:  21 6c 00 3a 06 22      move.l $3a(a4), $622(a0)
  00103a:  31 6c 00 3e 06 26      move.w $3e(a4), $626(a0)
  001040:  60 68                  bra.b $10aa
  001042:  3f 3c 00 02            move.w #$2, -(a7)
  001046:  4e ad 00 72            jsr $72(a5)
  00104a:  48 c0                  ext.l d0
  00104c:  e7 88                  lsl.l #$3, d0
  00104e:  20 4c                  movea.l a4, a0
  001050:  22 07                  move.l d7, d1
  001052:  48 c1                  ext.l d1
  001054:  e7 89                  lsl.l #$3, d1
  001056:  d1 c1                  adda.l d1, a0
  001058:  21 73 08 02 06 22      move.l $2(a3, d0.l), $622(a0)
  00105e:  31 73 08 06 06 26      move.w $6(a3, d0.l), $626(a0)
  001064:  54 8f                  addq.l #$2, a7
  001066:  60 42                  bra.b $10aa
  001068:  0c 46 00 63            cmpi.w #$63, d6
  00106c:  6c 18                  bge.b $1086
  00106e:  20 4c                  movea.l a4, a0
  001070:  20 07                  move.l d7, d0
  001072:  48 c0                  ext.l d0
  001074:  e7 88                  lsl.l #$3, d0
  001076:  d1 c0                  adda.l d0, a0
  001078:  21 6c 00 12 06 22      move.l $12(a4), $622(a0)
  00107e:  31 6c 00 16 06 26      move.w $16(a4), $626(a0)
  001084:  60 24                  bra.b $10aa
  001086:  3f 3c 00 01            move.w #$1, -(a7)
  00108a:  4e ad 00 72            jsr $72(a5)
  00108e:  48 c0                  ext.l d0
  001090:  e7 88                  lsl.l #$3, d0
  001092:  20 4c                  movea.l a4, a0
  001094:  22 07                  move.l d7, d1
  001096:  48 c1                  ext.l d1
  001098:  e7 89                  lsl.l #$3, d1
  00109a:  d1 c1                  adda.l d1, a0
  00109c:  21 73 08 1a 06 22      move.l $1a(a3, d0.l), $622(a0)
  0010a2:  31 73 08 1e 06 26      move.w $1e(a3, d0.l), $626(a0)
  0010a8:  54 8f                  addq.l #$2, a7
  0010aa:  52 47                  addq.w #$1, d7
  0010ac:  0c 47 00 05            cmpi.w #$5, d7
  0010b0:  6d 00 ff 12            blt.w $fc4
  0010b4:  2f 2d a2 12            move.l -$5dee(a5), -(a7)
  0010b8:  2f 2d a2 32            move.l -$5dce(a5), -(a7)
  0010bc:  2f 3c 00 c4 00 c4      move.l #$c400c4, -(a7)
  0010c2:  3f 3c 00 05            move.w #$5, -(a7)
  0010c6:  aa 9a                  dc.w $aa9a
  0010c8:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  0010cc:  4e 75                  rts 
  0010ce:  4e 56 00 00            link.w a6, #$0
  0010d2:  42 6d ba 86            clr.w -$457a(a5)
  0010d6:  42 6d ba 90            clr.w -$4570(a5)
  0010da:  42 6d ba 42            clr.w -$45be(a5)
  0010de:  42 6d ba 32            clr.w -$45ce(a5)
  0010e2:  4a 6d b9 3e            tst.w -$46c2(a5)
  0010e6:  67 06                  beq.b $10ee
  0010e8:  42 6d b9 3e            clr.w -$46c2(a5)
  0010ec:  60 1a                  bra.b $1108
  0010ee:  3b 7c 00 3c ba 8c      move.w #$3c, -$4574(a5)
  0010f4:  3b 7c 02 cf ba 80      move.w #$2cf, -$4580(a5)
  0010fa:  3b 7c 00 03 ba 46      move.w #$3, -$45ba(a5)
  001100:  42 6d 96 36            clr.w -$69ca(a5)
  001104:  42 6d 96 34            clr.w -$69cc(a5)
  001108:  4a 6e 00 08            tst.w $8(a6)
  00110c:  66 06                  bne.b $1114
  00110e:  3b 7c 00 04 ba 46      move.w #$4, -$45ba(a5)
  001114:  42 ad 96 38            clr.l -$69c8(a5)
  001118:  0c 6e 00 01 00 08      cmpi.w #$1, $8(a6)
  00111e:  66 08                  bne.b $1128
  001120:  3b 7c 00 01 ba 98      move.w #$1, -$4568(a5)
  001126:  60 04                  bra.b $112c
  001128:  42 6d ba 98            clr.w -$4568(a5)
  00112c:  4e 5e                  unlk a6
  00112e:  4e 75                  rts 
  001130:  4e 56 00 00            link.w a6, #$0
  001134:  2f 07                  move.l d7, -(a7)
  001136:  3e 2e 00 08            move.w $8(a6), d7
  00113a:  3f 07                  move.w d7, -(a7)
  00113c:  4e ba f1 48            jsr $286(pc)
  001140:  4e ba f2 66            jsr $3a8(pc)
  001144:  4e ba 07 4e            jsr $1894(pc)
  001148:  4e ad 03 f2            jsr $3f2(a5)
  00114c:  4e ba 3c fe            jsr $4e4c(pc)
  001150:  42 6d ba 2c            clr.w -$45d4(a5)
  001154:  42 6d ba 4c            clr.w -$45b4(a5)
  001158:  42 6d ba 52            clr.w -$45ae(a5)
  00115c:  42 6d ba 50            clr.w -$45b0(a5)
  001160:  42 6d ba 5c            clr.w -$45a4(a5)
  001164:  42 6d ba 5a            clr.w -$45a6(a5)
  001168:  42 6d ba 26            clr.w -$45da(a5)
  00116c:  42 6d ba 54            clr.w -$45ac(a5)
  001170:  42 6d ba 24            clr.w -$45dc(a5)
  001174:  42 6d ba 8e            clr.w -$4572(a5)
  001178:  42 6d ba 1a            clr.w -$45e6(a5)
  00117c:  42 6d ba 3c            clr.w -$45c4(a5)
  001180:  42 6d ba 3a            clr.w -$45c6(a5)
  001184:  42 6d ba 82            clr.w -$457e(a5)
  001188:  42 6d ba 6a            clr.w -$4596(a5)
  00118c:  42 6d bc ea            clr.w -$4316(a5)
  001190:  42 6d bc 6c            clr.w -$4394(a5)
  001194:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  00119a:  1b 7c 00 02 b9 87      move.b #$2, -$4679(a5)
  0011a0:  1b 7c 00 56 b9 7f      move.b #$56, -$4681(a5)
  0011a6:  4e ba 00 34            jsr $11dc(pc)
  0011aa:  0c 47 00 01            cmpi.w #$1, d7
  0011ae:  54 8f                  addq.l #$2, a7
  0011b0:  67 08                  beq.b $11ba
  0011b2:  3b 7c 00 01 ba 28      move.w #$1, -$45d8(a5)
  0011b8:  60 04                  bra.b $11be
  0011ba:  42 6d ba 28            clr.w -$45d8(a5)
  0011be:  0c 47 00 03            cmpi.w #$3, d7
  0011c2:  67 0a                  beq.b $11ce
  0011c4:  0c 47 00 0f            cmpi.w #$f, d7
  0011c8:  67 04                  beq.b $11ce
  0011ca:  42 6d ba 40            clr.w -$45c0(a5)
  0011ce:  4e ba 01 58            jsr $1328(pc)
  0011d2:  4e ba 01 9a            jsr $136e(pc)
  0011d6:  2e 1f                  move.l (a7)+, d7
  0011d8:  4e 5e                  unlk a6
  0011da:  4e 75                  rts 
  0011dc:  0c 6d 00 03 a9 0c      cmpi.w #$3, -$56f4(a5)
  0011e2:  66 36                  bne.b $121a
  0011e4:  4a 6d ba 40            tst.w -$45c0(a5)
  0011e8:  67 30                  beq.b $121a
  0011ea:  1b 7c 00 02 f1 5e      move.b #$2, -$ea2(a5)
  0011f0:  1b 7c 00 06 f1 5f      move.b #$6, -$ea1(a5)
  0011f6:  1b 7c 00 ff f1 60      move.b #$ff, -$ea0(a5)
  0011fc:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  001202:  3f 3c 00 07            move.w #$7, -(a7)
  001206:  4e ba 2d 6a            jsr $3f72(pc)
  00120a:  70 00                  moveq #$0, d0
  00120c:  10 2d ba e9            move.b -$4517(a5), d0
  001210:  d0 ad bd 82            add.l -$427e(a5), d0
  001214:  20 40                  movea.l d0, a0
  001216:  42 10                  clr.b (a0)
  001218:  5c 8f                  addq.l #$6, a7
  00121a:  10 2d f1 5e            move.b -$ea2(a5), d0
  00121e:  1b 40 b9 4f            move.b d0, -$46b1(a5)
  001222:  48 80                  ext.w d0
  001224:  3b 40 ba 7c            move.w d0, -$4584(a5)
  001228:  72 00                  moveq #$0, d1
  00122a:  12 2d f1 5f            move.b -$ea1(a5), d1
  00122e:  83 fc 00 0a            divs.w #$a, d1
  001232:  48 41                  swap d1
  001234:  1b 41 b9 4a            move.b d1, -$46b6(a5)
  001238:  72 00                  moveq #$0, d1
  00123a:  12 2d f1 5f            move.b -$ea1(a5), d1
  00123e:  83 fc 00 0a            divs.w #$a, d1
  001242:  1b 41 b9 4b            move.b d1, -$46b5(a5)
  001246:  12 2d b9 4a            move.b -$46b6(a5), d1
  00124a:  48 81                  ext.w d1
  00124c:  20 4d                  movea.l a5, a0
  00124e:  d0 c1                  adda.w d1, a0
  001250:  72 07                  moveq #$7, d1
  001252:  d2 28 b8 7d            add.b -$4783(a0), d1
  001256:  5e 01                  addq.b #$7, d1
  001258:  1b 41 b9 47            move.b d1, -$46b9(a5)
  00125c:  12 2d f1 60            move.b -$ea0(a5), d1
  001260:  46 01                  not.b d1
  001262:  1b 41 b9 49            move.b d1, -$46b7(a5)
  001266:  4a 6d ba 22            tst.w -$45de(a5)
  00126a:  66 0c                  bne.b $1278
  00126c:  30 2d ba 46            move.w -$45ba(a5), d0
  001270:  3b 40 ba 4a            move.w d0, -$45b6(a5)
  001274:  3b 40 ba 48            move.w d0, -$45b8(a5)
  001278:  0c 6d 00 01 a9 0c      cmpi.w #$1, -$56f4(a5)
  00127e:  66 20                  bne.b $12a0
  001280:  2f 3c 00 02 00 00      move.l #$20000, -(a7)
  001286:  3f 3c 00 05            move.w #$5, -(a7)
  00128a:  4e ba 2c e6            jsr $3f72(pc)
  00128e:  42 97                  clr.l (a7)
  001290:  4e ad 04 72            jsr $472(a5)
  001294:  3e bc 00 07            move.w #$7, (a7)
  001298:  4e ad 05 52            jsr $552(a5)
  00129c:  5c 8f                  addq.l #$6, a7
  00129e:  60 1e                  bra.b $12be
  0012a0:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  0012a6:  66 0c                  bne.b $12b4
  0012a8:  3f 3c 00 54            move.w #$54, -(a7)
  0012ac:  4e ad 05 52            jsr $552(a5)
  0012b0:  54 8f                  addq.l #$2, a7
  0012b2:  60 0a                  bra.b $12be
  0012b4:  3f 3c 00 05            move.w #$5, -(a7)
  0012b8:  4e ad 05 52            jsr $552(a5)
  0012bc:  54 8f                  addq.l #$2, a7
  0012be:  4e ba 00 04            jsr $12c4(pc)
  0012c2:  4e 75                  rts 
  0012c4:  42 2d b9 51            clr.b -$46af(a5)
  0012c8:  10 2d b9 4b            move.b -$46b5(a5), d0
  0012cc:  48 80                  ext.w d0
  0012ce:  20 4d                  movea.l a5, a0
  0012d0:  d0 c0                  adda.w d0, a0
  0012d2:  d0 c0                  adda.w d0, a0
  0012d4:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  0012da:  1b 7c 00 ff b9 53      move.b #$ff, -$46ad(a5)
  0012e0:  42 2d b9 52            clr.b -$46ae(a5)
  0012e4:  42 2d b9 4e            clr.b -$46b2(a5)
  0012e8:  42 2d b9 4d            clr.b -$46b3(a5)
  0012ec:  42 6d ba 36            clr.w -$45ca(a5)
  0012f0:  42 6d ba 34            clr.w -$45cc(a5)
  0012f4:  42 6d ba 58            clr.w -$45a8(a5)
  0012f8:  42 6d ba 1c            clr.w -$45e4(a5)
  0012fc:  42 6d ba 30            clr.w -$45d0(a5)
  001300:  42 6d ba 2e            clr.w -$45d2(a5)
  001304:  4e ba 2f 44            jsr $424a(pc)
  001308:  0c 6d 00 07 a9 0c      cmpi.w #$7, -$56f4(a5)
  00130e:  66 12                  bne.b $1322
  001310:  0c 2d 00 11 b9 4f      cmpi.b #$11, -$46b1(a5)
  001316:  66 0a                  bne.b $1322
  001318:  3f 3c 00 03            move.w #$3, -(a7)
  00131c:  4e ba 1e 54            jsr $3172(pc)
  001320:  54 8f                  addq.l #$2, a7
  001322:  4e ba 31 70            jsr $4494(pc)
  001326:  4e 75                  rts 
  001328:  2f 07                  move.l d7, -(a7)
  00132a:  10 2d b9 73            move.b -$468d(a5), d0
  00132e:  48 80                  ext.w d0
  001330:  3f 00                  move.w d0, -(a7)
  001332:  4e ad 05 12            jsr $512(a5)
  001336:  7e 00                  moveq #$0, d7
  001338:  54 8f                  addq.l #$2, a7
  00133a:  60 28                  bra.b $1364
  00133c:  20 6d bd 82            movea.l -$427e(a5), a0
  001340:  70 00                  moveq #$0, d0
  001342:  10 30 70 00            move.b (a0, d7.w), d0
  001346:  02 40 00 1f            andi.w #$1f, d0
  00134a:  0c 40 00 10            cmpi.w #$10, d0
  00134e:  66 12                  bne.b $1362
  001350:  3f 07                  move.w d7, -(a7)
  001352:  10 2d b9 73            move.b -$468d(a5), d0
  001356:  48 80                  ext.w d0
  001358:  3f 00                  move.w d0, -(a7)
  00135a:  4e ad 04 82            jsr $482(a5)
  00135e:  58 8f                  addq.l #$4, a7
  001360:  60 08                  bra.b $136a
  001362:  52 47                  addq.w #$1, d7
  001364:  0c 47 00 1e            cmpi.w #$1e, d7
  001368:  6d d2                  blt.b $133c
  00136a:  2e 1f                  move.l (a7)+, d7
  00136c:  4e 75                  rts 
  00136e:  42 6d ba 32            clr.w -$45ce(a5)
  001372:  10 2d b9 73            move.b -$468d(a5), d0
  001376:  48 80                  ext.w d0
  001378:  3b 40 ba 7c            move.w d0, -$4584(a5)
  00137c:  4e ba f1 7c            jsr $4fa(pc)
  001380:  3f 3c 00 01            move.w #$1, -(a7)
  001384:  4e ba 00 32            jsr $13b8(pc)
  001388:  1e bc 00 01            move.b #$1, (a7)
  00138c:  48 6d a5 d4            pea.l -$5a2c(a5)
  001390:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  001394:  4e 90                  jsr (a0)
  001396:  4e ad 05 3a            jsr $53a(a5)
  00139a:  3e ad ba 48            move.w -$45b8(a5), (a7)
  00139e:  3f 2d ba 4a            move.w -$45b6(a5), -(a7)
  0013a2:  4e ba f1 e4            jsr $588(pc)
  0013a6:  3e ad ba 4e            move.w -$45b2(a5), (a7)
  0013aa:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  0013ae:  4e ba f2 68            jsr $618(pc)
  0013b2:  4f ef 00 0a            lea.l $a(a7), a7
  0013b6:  4e 75                  rts 
  0013b8:  4e 56 00 00            link.w a6, #$0
  0013bc:  2f 3c 00 01 ff 00      move.l #$1ff00, -(a7)
  0013c2:  4e ad 00 92            jsr $92(a5)
  0013c6:  3b 7c 00 01 a5 5c      move.w #$1, -$5aa4(a5)
  0013cc:  4a 6e 00 08            tst.w $8(a6)
  0013d0:  58 8f                  addq.l #$4, a7
  0013d2:  67 16                  beq.b $13ea
  0013d4:  48 6d a5 c4            pea.l -$5a3c(a5)
  0013d8:  a8 a2                  dc.w $a8a2
  0013da:  1f 3c 00 02            move.b #$2, -(a7)
  0013de:  48 6d a5 cc            pea.l -$5a34(a5)
  0013e2:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  0013e6:  4e 90                  jsr (a0)
  0013e8:  5c 8f                  addq.l #$6, a7
  0013ea:  42 6d ba 7e            clr.w -$4582(a5)
  0013ee:  4a 6d ba a8            tst.w -$4558(a5)
  0013f2:  67 10                  beq.b $1404
  0013f4:  42 67                  clr.w -(a7)
  0013f6:  3f 2d ba a6            move.w -$455a(a5), -(a7)
  0013fa:  4e ad 00 9a            jsr $9a(a5)
  0013fe:  42 6d ba a8            clr.w -$4558(a5)
  001402:  58 8f                  addq.l #$4, a7
  001404:  4a 2d b9 44            tst.b -$46bc(a5)
  001408:  67 04                  beq.b $140e
  00140a:  4e ba f7 66            jsr $b72(pc)
  00140e:  2b 6d a5 cc a2 e4      move.l -$5a34(a5), -$5d1c(a5)
  001414:  2b 6d a5 d0 a2 e8      move.l -$5a30(a5), -$5d18(a5)
  00141a:  42 6d f2 28            clr.w -$dd8(a5)
  00141e:  4e ad 04 ba            jsr $4ba(a5)
  001422:  4e ad 01 12            jsr $112(a5)
  001426:  3b 7c 00 01 b9 3c      move.w #$1, -$46c4(a5)
  00142c:  4e ad 05 02            jsr $502(a5)
  001430:  42 6d b9 3c            clr.w -$46c4(a5)
  001434:  4e ad 01 12            jsr $112(a5)
  001438:  4e ba 07 82            jsr $1bbc(pc)
  00143c:  4e ad 04 f2            jsr $4f2(a5)
  001440:  4e ad 05 02            jsr $502(a5)
  001444:  3b 7c 00 01 f2 28      move.w #$1, -$dd8(a5)
  00144a:  48 6d a2 dc            pea.l -$5d24(a5)
  00144e:  a9 28                  dc.w $a928
  001450:  3b 7c 00 02 ba 84      move.w #$2, -$457c(a5)
  001456:  4e 5e                  unlk a6
  001458:  4e 75                  rts 
  00145a:  42 6d ba 52            clr.w -$45ae(a5)
  00145e:  42 6d ba 50            clr.w -$45b0(a5)
  001462:  4e ba 02 3a            jsr $169e(pc)
  001466:  4e ba eb f8            jsr $60(pc)
  00146a:  4a 6d 96 30            tst.w -$69d0(a5)
  00146e:  66 6a                  bne.b $14da
  001470:  4a 6d ba 66            tst.w -$459a(a5)
  001474:  67 0c                  beq.b $1482
  001476:  42 6d ba 66            clr.w -$459a(a5)
  00147a:  42 ad 96 4c            clr.l -$69b4(a5)
  00147e:  70 01                  moveq #$1, d0
  001480:  60 5e                  bra.b $14e0
  001482:  30 2d ba 38            move.w -$45c8(a5), d0
  001486:  b0 6d a9 0c            cmp.w -$56f4(a5), d0
  00148a:  67 08                  beq.b $1494
  00148c:  4e ad 01 0a            jsr $10a(a5)
  001490:  4a 00                  tst.b d0
  001492:  67 30                  beq.b $14c4
  001494:  4a 6d ba 50            tst.w -$45b0(a5)
  001498:  6c 0c                  bge.b $14a6
  00149a:  3b 7c 00 01 ba 1a      move.w #$1, -$45e6(a5)
  0014a0:  3b 7c 00 09 ba 18      move.w #$9, -$45e8(a5)
  0014a6:  4e ba ec a2            jsr $14a(pc)
  0014aa:  0c 2d 00 02 b9 76      cmpi.b #$2, -$468a(a5)
  0014b0:  66 08                  bne.b $14ba
  0014b2:  70 06                  moveq #$6, d0
  0014b4:  2b 40 96 4c            move.l d0, -$69b4(a5)
  0014b8:  60 06                  bra.b $14c0
  0014ba:  70 05                  moveq #$5, d0
  0014bc:  2b 40 96 4c            move.l d0, -$69b4(a5)
  0014c0:  70 00                  moveq #$0, d0
  0014c2:  60 1c                  bra.b $14e0
  0014c4:  4e ad 01 02            jsr $102(a5)
  0014c8:  3b 6d ba 48 ba 46      move.w -$45b8(a5), -$45ba(a5)
  0014ce:  42 6d ba 32            clr.w -$45ce(a5)
  0014d2:  42 ad 96 4c            clr.l -$69b4(a5)
  0014d6:  70 02                  moveq #$2, d0
  0014d8:  60 06                  bra.b $14e0
  0014da:  42 ad 96 4c            clr.l -$69b4(a5)
  0014de:  70 03                  moveq #$3, d0
  0014e0:  4e 75                  rts 
  0014e2:  48 e7 0f 00            movem.l d4-d7, -(a7)
  0014e6:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  0014ec:  6d 28                  blt.b $1516
  0014ee:  4a 2d b9 49            tst.b -$46b7(a5)
  0014f2:  6d 14                  blt.b $1508
  0014f4:  52 6d ba c8            addq.w #$1, -$4538(a5)
  0014f8:  0c 6d 00 0a ba c8      cmpi.w #$a, -$4538(a5)
  0014fe:  6d 16                  blt.b $1516
  001500:  3b 7c 00 09 ba c8      move.w #$9, -$4538(a5)
  001506:  60 0e                  bra.b $1516
  001508:  53 6d ba c6            subq.w #$1, -$453a(a5)
  00150c:  4a 6d ba c6            tst.w -$453a(a5)
  001510:  6c 04                  bge.b $1516
  001512:  42 6d ba c6            clr.w -$453a(a5)
  001516:  3e 2d ba ca            move.w -$4536(a5), d7
  00151a:  3c 2d ba c8            move.w -$4538(a5), d6
  00151e:  3a 2d ba c6            move.w -$453a(a5), d5
  001522:  4a 2d b9 51            tst.b -$46af(a5)
  001526:  66 4c                  bne.b $1574
  001528:  30 2d ba ce            move.w -$4532(a5), d0
  00152c:  b0 6d ba ca            cmp.w -$4536(a5), d0
  001530:  6c 04                  bge.b $1536
  001532:  3e 2d ba ce            move.w -$4532(a5), d7
  001536:  30 2d ba d0            move.w -$4530(a5), d0
  00153a:  b0 6d ba c8            cmp.w -$4538(a5), d0
  00153e:  6f 04                  ble.b $1544
  001540:  3c 2d ba d0            move.w -$4530(a5), d6
  001544:  30 2d ba d2            move.w -$452e(a5), d0
  001548:  b0 6d ba c6            cmp.w -$453a(a5), d0
  00154c:  6c 04                  bge.b $1552
  00154e:  3a 2d ba d2            move.w -$452e(a5), d5
  001552:  0c 2d 00 07 b9 4c      cmpi.b #$7, -$46b4(a5)
  001558:  66 02                  bne.b $155c
  00155a:  52 46                  addq.w #$1, d6
  00155c:  4e ba 32 04            jsr $4762(pc)
  001560:  0c 2d 00 0f ba e8      cmpi.b #$f, -$4518(a5)
  001566:  67 08                  beq.b $1570
  001568:  0c 2d 00 06 ba e8      cmpi.b #$6, -$4518(a5)
  00156e:  66 04                  bne.b $1574
  001570:  4e ad 04 22            jsr $422(a5)
  001574:  38 07                  move.w d7, d4
  001576:  60 1c                  bra.b $1594
  001578:  3e 05                  move.w d5, d7
  00157a:  60 12                  bra.b $158e
  00157c:  3f 04                  move.w d4, -(a7)
  00157e:  3f 07                  move.w d7, -(a7)
  001580:  4e ba 2a c6            jsr $4048(pc)
  001584:  3e 80                  move.w d0, (a7)
  001586:  4e ad 04 3a            jsr $43a(a5)
  00158a:  58 8f                  addq.l #$4, a7
  00158c:  52 47                  addq.w #$1, d7
  00158e:  bc 47                  cmp.w d7, d6
  001590:  6c ea                  bge.b $157c
  001592:  52 44                  addq.w #$1, d4
  001594:  b8 6d ba cc            cmp.w -$4534(a5), d4
  001598:  6f de                  ble.b $1578
  00159a:  4a 2d b9 51            tst.b -$46af(a5)
  00159e:  66 12                  bne.b $15b2
  0015a0:  3b 6d ba ca ba ce      move.w -$4536(a5), -$4532(a5)
  0015a6:  3b 6d ba c8 ba d0      move.w -$4538(a5), -$4530(a5)
  0015ac:  3b 6d ba c6 ba d2      move.w -$453a(a5), -$452e(a5)
  0015b2:  4c df 00 f0            movem.l (a7)+, d4-d7
  0015b6:  4e 75                  rts 
  0015b8:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  0015bc:  1e 2d b9 4c            move.b -$46b4(a5), d7
  0015c0:  48 87                  ext.w d7
  0015c2:  7c 00                  moveq #$0, d6
  0015c4:  1c 2d b9 46            move.b -$46ba(a5), d6
  0015c8:  0c 47 00 02            cmpi.w #$2, d7
  0015cc:  66 12                  bne.b $15e0
  0015ce:  0c 46 00 4e            cmpi.w #$4e, d6
  0015d2:  6d 0c                  blt.b $15e0
  0015d4:  0c 46 00 50            cmpi.w #$50, d6
  0015d8:  6c 06                  bge.b $15e0
  0015da:  49 ed 04 2a            lea.l $42a(a5), a4
  0015de:  60 40                  bra.b $1620
  0015e0:  0c 46 00 89            cmpi.w #$89, d6
  0015e4:  6d 0c                  blt.b $15f2
  0015e6:  0c 46 00 91            cmpi.w #$91, d6
  0015ea:  6c 06                  bge.b $15f2
  0015ec:  49 ed 04 32            lea.l $432(a5), a4
  0015f0:  60 2e                  bra.b $1620
  0015f2:  0c 47 00 02            cmpi.w #$2, d7
  0015f6:  67 24                  beq.b $161c
  0015f8:  0c 47 00 03            cmpi.w #$3, d7
  0015fc:  67 1e                  beq.b $161c
  0015fe:  0c 47 00 04            cmpi.w #$4, d7
  001602:  67 18                  beq.b $161c
  001604:  0c 47 00 06            cmpi.w #$6, d7
  001608:  67 12                  beq.b $161c
  00160a:  0c 47 00 05            cmpi.w #$5, d7
  00160e:  66 5a                  bne.b $166a
  001610:  0c 46 00 66            cmpi.w #$66, d6
  001614:  6d 54                  blt.b $166a
  001616:  0c 46 00 6a            cmpi.w #$6a, d6
  00161a:  6e 4e                  bgt.b $166a
  00161c:  49 ed 04 2a            lea.l $42a(a5), a4
  001620:  3b 6d ba c8 ba ec      move.w -$4538(a5), -$4514(a5)
  001626:  60 38                  bra.b $1660
  001628:  0c 47 00 02            cmpi.w #$2, d7
  00162c:  67 12                  beq.b $1640
  00162e:  3f 2d ba cc            move.w -$4534(a5), -(a7)
  001632:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001636:  4e ba 2a 10            jsr $4048(pc)
  00163a:  3e 80                  move.w d0, (a7)
  00163c:  4e 94                  jsr (a4)
  00163e:  58 8f                  addq.l #$4, a7
  001640:  30 2d ba ca            move.w -$4536(a5), d0
  001644:  b0 6d ba cc            cmp.w -$4534(a5), d0
  001648:  67 12                  beq.b $165c
  00164a:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  00164e:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001652:  4e ba 29 f4            jsr $4048(pc)
  001656:  3e 80                  move.w d0, (a7)
  001658:  4e 94                  jsr (a4)
  00165a:  58 8f                  addq.l #$4, a7
  00165c:  53 6d ba ec            subq.w #$1, -$4514(a5)
  001660:  30 2d ba ec            move.w -$4514(a5), d0
  001664:  b0 6d ba c6            cmp.w -$453a(a5), d0
  001668:  6c be                  bge.b $1628
  00166a:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  00166e:  4e 75                  rts 
  001670:  4a 6d ba 1c            tst.w -$45e4(a5)
  001674:  67 26                  beq.b $169c
  001676:  4a 6d ba 1c            tst.w -$45e4(a5)
  00167a:  5e c0                  sgt.b d0
  00167c:  44 00                  neg.b d0
  00167e:  48 80                  ext.w d0
  001680:  12 2d b9 4b            move.b -$46b5(a5), d1
  001684:  48 81                  ext.w d1
  001686:  92 40                  sub.w d0, d1
  001688:  3f 01                  move.w d1, -(a7)
  00168a:  10 2d b9 4f            move.b -$46b1(a5), d0
  00168e:  48 80                  ext.w d0
  001690:  3f 00                  move.w d0, -(a7)
  001692:  4e ad 04 9a            jsr $49a(a5)
  001696:  42 6d ba 1c            clr.w -$45e4(a5)
  00169a:  58 8f                  addq.l #$4, a7
  00169c:  4e 75                  rts 
  00169e:  4a 6d ba 8e            tst.w -$4572(a5)
  0016a2:  6f 20                  ble.b $16c4
  0016a4:  53 6d ba 8e            subq.w #$1, -$4572(a5)
  0016a8:  0c 6d 00 05 ba 8e      cmpi.w #$5, -$4572(a5)
  0016ae:  66 0a                  bne.b $16ba
  0016b0:  3f 3c 00 29            move.w #$29, -(a7)
  0016b4:  4e ba f0 fe            jsr $7b4(pc)
  0016b8:  54 8f                  addq.l #$2, a7
  0016ba:  4a 6d ba 8e            tst.w -$4572(a5)
  0016be:  66 04                  bne.b $16c4
  0016c0:  53 6d ba 8e            subq.w #$1, -$4572(a5)
  0016c4:  4a 6d ba 92            tst.w -$456e(a5)
  0016c8:  6f 04                  ble.b $16ce
  0016ca:  53 6d ba 92            subq.w #$1, -$456e(a5)
  0016ce:  4a 6d ba 30            tst.w -$45d0(a5)
  0016d2:  6f 16                  ble.b $16ea
  0016d4:  53 6d ba 30            subq.w #$1, -$45d0(a5)
  0016d8:  4e ad 01 0a            jsr $10a(a5)
  0016dc:  4a 00                  tst.b d0
  0016de:  67 0a                  beq.b $16ea
  0016e0:  4a 6d ba 30            tst.w -$45d0(a5)
  0016e4:  66 04                  bne.b $16ea
  0016e6:  52 6d ba 30            addq.w #$1, -$45d0(a5)
  0016ea:  0c 6d 00 08 a9 0c      cmpi.w #$8, -$56f4(a5)
  0016f0:  66 1e                  bne.b $1710
  0016f2:  0c 2d 00 10 b9 4f      cmpi.b #$10, -$46b1(a5)
  0016f8:  66 16                  bne.b $1710
  0016fa:  4a 6d ba 3c            tst.w -$45c4(a5)
  0016fe:  67 10                  beq.b $1710
  001700:  52 6d ba 3c            addq.w #$1, -$45c4(a5)
  001704:  0c 6d 00 96 ba 3c      cmpi.w #$96, -$45c4(a5)
  00170a:  66 04                  bne.b $1710
  00170c:  4e ba 03 3c            jsr $1a4a(pc)
  001710:  4e 75                  rts 
  001712:  2f 07                  move.l d7, -(a7)
  001714:  0c 6d ff ff ba 1e      cmpi.w #$ffff, -$45e2(a5)
  00171a:  66 0c                  bne.b $1728
  00171c:  4e ba 00 76            jsr $1794(pc)
  001720:  3b 7c 00 01 ba 2c      move.w #$1, -$45d4(a5)
  001726:  60 68                  bra.b $1790
  001728:  4e ba 30 38            jsr $4762(pc)
  00172c:  72 00                  moveq #$0, d1
  00172e:  12 00                  move.b d0, d1
  001730:  0c 41 00 0d            cmpi.w #$d, d1
  001734:  66 5a                  bne.b $1790
  001736:  4e ba 2d 48            jsr $4480(pc)
  00173a:  4e ba 29 ac            jsr $40e8(pc)
  00173e:  4e ba 00 a4            jsr $17e4(pc)
  001742:  4a 2d ba 9a            tst.b -$4566(a5)
  001746:  6d 48                  blt.b $1790
  001748:  4e ad 05 22            jsr $522(a5)
  00174c:  4e ba 2e 1a            jsr $4568(pc)
  001750:  10 2d b9 4b            move.b -$46b5(a5), d0
  001754:  48 80                  ext.w d0
  001756:  20 4d                  movea.l a5, a0
  001758:  d0 c0                  adda.w d0, a0
  00175a:  d0 c0                  adda.w d0, a0
  00175c:  3e 28 b6 66            move.w -$499a(a0), d7
  001760:  be 6d ba f8            cmp.w -$4508(a5), d7
  001764:  6c 2a                  bge.b $1790
  001766:  20 4d                  movea.l a5, a0
  001768:  d0 c7                  adda.w d7, a0
  00176a:  d0 c7                  adda.w d7, a0
  00176c:  3b 68 9c 64 ba fe      move.w -$639c(a0), -$4502(a5)
  001772:  10 2d b9 4a            move.b -$46b6(a5), d0
  001776:  48 80                  ext.w d0
  001778:  eb 48                  lsl.w #$5, d0
  00177a:  20 4d                  movea.l a5, a0
  00177c:  d0 c0                  adda.w d0, a0
  00177e:  d0 c0                  adda.w d0, a0
  001780:  3b 68 98 6e bb 02      move.w -$6792(a0), -$44fe(a5)
  001786:  1f 3c 00 04            move.b #$4, -(a7)
  00178a:  4e ad 05 1a            jsr $51a(a5)
  00178e:  54 8f                  addq.l #$2, a7
  001790:  2e 1f                  move.l (a7)+, d7
  001792:  4e 75                  rts 
  001794:  4e ba 2c ea            jsr $4480(pc)
  001798:  4e ba 29 4e            jsr $40e8(pc)
  00179c:  4e ba 00 46            jsr $17e4(pc)
  0017a0:  42 6d ba 1e            clr.w -$45e2(a5)
  0017a4:  1b 7c 00 01 b9 51      move.b #$1, -$46af(a5)
  0017aa:  3f 3c 00 2d            move.w #$2d, -(a7)
  0017ae:  4e ba f0 04            jsr $7b4(pc)
  0017b2:  4e ba 2d 08            jsr $44bc(pc)
  0017b6:  30 2d ba 48            move.w -$45b8(a5), d0
  0017ba:  3b 40 ba 4c            move.w d0, -$45b4(a5)
  0017be:  3b 40 ba 4e            move.w d0, -$45b2(a5)
  0017c2:  3b 7c 00 01 ba 4a      move.w #$1, -$45b6(a5)
  0017c8:  3e ad ba 48            move.w -$45b8(a5), (a7)
  0017cc:  3f 2d ba 4a            move.w -$45b6(a5), -(a7)
  0017d0:  4e ba ed b6            jsr $588(pc)
  0017d4:  3e ad ba 4e            move.w -$45b2(a5), (a7)
  0017d8:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  0017dc:  4e ba ee 3a            jsr $618(pc)
  0017e0:  5c 8f                  addq.l #$6, a7
  0017e2:  4e 75                  rts 
  0017e4:  48 e7 03 00            movem.l d6-d7, -(a7)
  0017e8:  10 2d b9 4a            move.b -$46b6(a5), d0
  0017ec:  48 80                  ext.w d0
  0017ee:  20 4d                  movea.l a5, a0
  0017f0:  d0 c0                  adda.w d0, a0
  0017f2:  7e 00                  moveq #$0, d7
  0017f4:  1e 28 b8 7d            move.b -$4783(a0), d7
  0017f8:  06 47 00 09            addi.w #$9, d7
  0017fc:  4e ba 33 c0            jsr $4bbe(pc)
  001800:  3c 00                  move.w d0, d6
  001802:  4a 2d b9 49            tst.b -$46b7(a5)
  001806:  6d 06                  blt.b $180e
  001808:  70 0e                  moveq #$e, d0
  00180a:  90 46                  sub.w d6, d0
  00180c:  3c 00                  move.w d0, d6
  00180e:  70 fe                  moveq #$fe, d0
  001810:  d0 06                  add.b d6, d0
  001812:  1b 40 ba 9a            move.b d0, -$4566(a5)
  001816:  12 07                  move.b d7, d1
  001818:  d2 07                  add.b d7, d1
  00181a:  92 2d b9 47            sub.b -$46b9(a5), d1
  00181e:  1b 41 b9 47            move.b d1, -$46b9(a5)
  001822:  12 2d b9 49            move.b -$46b7(a5), d1
  001826:  46 01                  not.b d1
  001828:  1b 41 b9 49            move.b d1, -$46b7(a5)
  00182c:  4c df 00 c0            movem.l (a7)+, d6-d7
  001830:  4e 75                  rts 
  001832:  2f 07                  move.l d7, -(a7)
  001834:  0c 6d 00 02 ba 24      cmpi.w #$2, -$45dc(a5)
  00183a:  6d 54                  blt.b $1890
  00183c:  4a 2d b9 52            tst.b -$46ae(a5)
  001840:  66 4e                  bne.b $1890
  001842:  4a 2d b9 64            tst.b -$469c(a5)
  001846:  67 48                  beq.b $1890
  001848:  0c 2d 00 02 b9 5e      cmpi.b #$2, -$46a2(a5)
  00184e:  6c 40                  bge.b $1890
  001850:  10 2d b9 49            move.b -$46b7(a5), d0
  001854:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  001858:  67 36                  beq.b $1890
  00185a:  4e ba 40 98            jsr $58f4(pc)
  00185e:  3e 00                  move.w d0, d7
  001860:  0c 47 00 0f            cmpi.w #$f, d7
  001864:  6e 2a                  bgt.b $1890
  001866:  0c 47 ff f1            cmpi.w #$fff1, d7
  00186a:  6d 24                  blt.b $1890
  00186c:  10 2d b9 4b            move.b -$46b5(a5), d0
  001870:  48 80                  ext.w d0
  001872:  20 4d                  movea.l a5, a0
  001874:  d0 c0                  adda.w d0, a0
  001876:  d0 c0                  adda.w d0, a0
  001878:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  00187e:  42 2d b9 4e            clr.b -$46b2(a5)
  001882:  3f 3c 00 2f            move.w #$2f, -(a7)
  001886:  4e ad 05 52            jsr $552(a5)
  00188a:  4e ba 29 be            jsr $424a(pc)
  00188e:  54 8f                  addq.l #$2, a7
  001890:  2e 1f                  move.l (a7)+, d7
  001892:  4e 75                  rts 
  001894:  48 e7 03 00            movem.l d6-d7, -(a7)
  001898:  7e 00                  moveq #$0, d7
  00189a:  60 40                  bra.b $18dc
  00189c:  20 4d                  movea.l a5, a0
  00189e:  d0 c7                  adda.w d7, a0
  0018a0:  7c 00                  moveq #$0, d6
  0018a2:  1c 28 f1 76            move.b -$e8a(a0), d6
  0018a6:  0c 46 00 1e            cmpi.w #$1e, d6
  0018aa:  6c 2e                  bge.b $18da
  0018ac:  20 06                  move.l d6, d0
  0018ae:  48 c0                  ext.l d0
  0018b0:  81 fc 00 0a            divs.w #$a, d0
  0018b4:  48 40                  swap d0
  0018b6:  20 4d                  movea.l a5, a0
  0018b8:  d0 c0                  adda.w d0, a0
  0018ba:  70 07                  moveq #$7, d0
  0018bc:  d0 28 b8 7d            add.b -$4783(a0), d0
  0018c0:  5e 00                  addq.b #$7, d0
  0018c2:  20 4d                  movea.l a5, a0
  0018c4:  d0 c7                  adda.w d7, a0
  0018c6:  11 40 f1 a6            move.b d0, -$e5a(a0)
  0018ca:  20 4d                  movea.l a5, a0
  0018cc:  d0 c7                  adda.w d7, a0
  0018ce:  42 28 f1 ee            clr.b -$e12(a0)
  0018d2:  20 4d                  movea.l a5, a0
  0018d4:  d0 c7                  adda.w d7, a0
  0018d6:  42 28 f1 be            clr.b -$e42(a0)
  0018da:  52 47                  addq.w #$1, d7
  0018dc:  0c 47 00 18            cmpi.w #$18, d7
  0018e0:  6d ba                  blt.b $189c
  0018e2:  4c df 00 c0            movem.l (a7)+, d6-d7
  0018e6:  4e 75                  rts 
  0018e8:  48 e7 07 00            movem.l d5-d7, -(a7)
  0018ec:  7e 00                  moveq #$0, d7
  0018ee:  1e 2d b9 6a            move.b -$4696(a5), d7
  0018f2:  0c 2d 00 18 b9 87      cmpi.b #$18, -$4679(a5)
  0018f8:  67 00 01 24            beq.w $1a1e
  0018fc:  0c 2d 00 01 b9 87      cmpi.b #$1, -$4679(a5)
  001902:  66 08                  bne.b $190c
  001904:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  00190a:  66 38                  bne.b $1944
  00190c:  4a 47                  tst.w d7
  00190e:  67 34                  beq.b $1944
  001910:  0c 47 00 db            cmpi.w #$db, d7
  001914:  6d 06                  blt.b $191c
  001916:  0c 47 00 e5            cmpi.w #$e5, d7
  00191a:  6d 28                  blt.b $1944
  00191c:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  001922:  67 20                  beq.b $1944
  001924:  4a 2d b9 77            tst.b -$4689(a5)
  001928:  6c 1a                  bge.b $1944
  00192a:  4a 2d b9 89            tst.b -$4677(a5)
  00192e:  6c 14                  bge.b $1944
  001930:  10 2d b9 73            move.b -$468d(a5), d0
  001934:  b0 2d b9 85            cmp.b -$467b(a5), d0
  001938:  66 0a                  bne.b $1944
  00193a:  10 2d b9 6f            move.b -$4691(a5), d0
  00193e:  b0 2d b9 81            cmp.b -$467f(a5), d0
  001942:  67 08                  beq.b $194c
  001944:  42 6d ba 24            clr.w -$45dc(a5)
  001948:  60 00 00 d4            bra.w $1a1e
  00194c:  3b 7c 00 02 ba 24      move.w #$2, -$45dc(a5)
  001952:  10 2d b9 6e            move.b -$4692(a5), d0
  001956:  48 80                  ext.w d0
  001958:  20 4d                  movea.l a5, a0
  00195a:  d0 c0                  adda.w d0, a0
  00195c:  7e 00                  moveq #$0, d7
  00195e:  1e 28 b8 7d            move.b -$4783(a0), d7
  001962:  5e 47                  addq.w #$7, d7
  001964:  10 2d b9 80            move.b -$4680(a5), d0
  001968:  48 80                  ext.w d0
  00196a:  20 4d                  movea.l a5, a0
  00196c:  d0 c0                  adda.w d0, a0
  00196e:  7c 00                  moveq #$0, d6
  001970:  1c 28 b8 7d            move.b -$4783(a0), d6
  001974:  5e 46                  addq.w #$7, d6
  001976:  bc 47                  cmp.w d7, d6
  001978:  6c 06                  bge.b $1980
  00197a:  3a 07                  move.w d7, d5
  00197c:  3e 06                  move.w d6, d7
  00197e:  3c 05                  move.w d5, d6
  001980:  3f 07                  move.w d7, -(a7)
  001982:  4e ba 00 a0            jsr $1a24(pc)
  001986:  72 00                  moveq #$0, d1
  001988:  12 00                  move.b d0, d1
  00198a:  0c 41 00 12            cmpi.w #$12, d1
  00198e:  54 8f                  addq.l #$2, a7
  001990:  66 04                  bne.b $1996
  001992:  06 47 00 0e            addi.w #$e, d7
  001996:  3f 06                  move.w d6, -(a7)
  001998:  4e ba 00 8a            jsr $1a24(pc)
  00199c:  72 00                  moveq #$0, d1
  00199e:  12 00                  move.b d0, d1
  0019a0:  59 41                  subq.w #$4, d1
  0019a2:  54 8f                  addq.l #$2, a7
  0019a4:  66 74                  bne.b $1a1a
  0019a6:  06 46 ff f2            addi.w #$fff2, d6
  0019aa:  60 6e                  bra.b $1a1a
  0019ac:  3f 07                  move.w d7, -(a7)
  0019ae:  4e ba 00 74            jsr $1a24(pc)
  0019b2:  72 00                  moveq #$0, d1
  0019b4:  12 00                  move.b d0, d1
  0019b6:  0c 41 00 14            cmpi.w #$14, d1
  0019ba:  54 8f                  addq.l #$2, a7
  0019bc:  67 10                  beq.b $19ce
  0019be:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  0019c4:  67 08                  beq.b $19ce
  0019c6:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  0019cc:  66 06                  bne.b $19d4
  0019ce:  42 6d ba 24            clr.w -$45dc(a5)
  0019d2:  60 4a                  bra.b $1a1e
  0019d4:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  0019da:  67 34                  beq.b $1a10
  0019dc:  0c 2d 00 12 ba e8      cmpi.b #$12, -$4518(a5)
  0019e2:  67 2c                  beq.b $1a10
  0019e4:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  0019ea:  66 12                  bne.b $19fe
  0019ec:  70 00                  moveq #$0, d0
  0019ee:  10 2d ba e9            move.b -$4517(a5), d0
  0019f2:  d0 ad bd 86            add.l -$427a(a5), d0
  0019f6:  20 40                  movea.l d0, a0
  0019f8:  0c 10 00 70            cmpi.b #$70, (a0)
  0019fc:  65 12                  bcs.b $1a10
  0019fe:  70 00                  moveq #$0, d0
  001a00:  10 2d ba e8            move.b -$4518(a5), d0
  001a04:  3f 00                  move.w d0, -(a7)
  001a06:  4e ba 2c 4c            jsr $4654(pc)
  001a0a:  4a 00                  tst.b d0
  001a0c:  54 8f                  addq.l #$2, a7
  001a0e:  66 06                  bne.b $1a16
  001a10:  3b 7c 00 01 ba 24      move.w #$1, -$45dc(a5)
  001a16:  06 47 00 0e            addi.w #$e, d7
  001a1a:  bc 47                  cmp.w d7, d6
  001a1c:  6c 8e                  bge.b $19ac
  001a1e:  4c df 00 e0            movem.l (a7)+, d5-d7
  001a22:  4e 75                  rts 
  001a24:  4e 56 00 00            link.w a6, #$0
  001a28:  10 2d b9 6f            move.b -$4691(a5), d0
  001a2c:  48 80                  ext.w d0
  001a2e:  3f 00                  move.w d0, -(a7)
  001a30:  3f 2e 00 08            move.w $8(a6), -(a7)
  001a34:  4e ba 29 a8            jsr $43de(pc)
  001a38:  3e 80                  move.w d0, (a7)
  001a3a:  10 2d b9 73            move.b -$468d(a5), d0
  001a3e:  48 80                  ext.w d0
  001a40:  3f 00                  move.w d0, -(a7)
  001a42:  4e ba 25 2e            jsr $3f72(pc)
  001a46:  4e 5e                  unlk a6
  001a48:  4e 75                  rts 
  001a4a:  4e ba 2a 34            jsr $4480(pc)
  001a4e:  1b 7c 00 18 b9 51      move.b #$18, -$46af(a5)
  001a54:  1b 7c 00 c8 b9 47      move.b #$c8, -$46b9(a5)
  001a5a:  42 2d b9 4b            clr.b -$46b5(a5)
  001a5e:  10 2d b9 4b            move.b -$46b5(a5), d0
  001a62:  48 80                  ext.w d0
  001a64:  20 4d                  movea.l a5, a0
  001a66:  d0 c0                  adda.w d0, a0
  001a68:  d0 c0                  adda.w d0, a0
  001a6a:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  001a70:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001a76:  1b 7c 00 ff b9 53      move.b #$ff, -$46ad(a5)
  001a7c:  3b 7c 00 01 ba 4c      move.w #$1, -$45b4(a5)
  001a82:  3f 3c 00 69            move.w #$69, -(a7)
  001a86:  4e ad 05 52            jsr $552(a5)
  001a8a:  4e ba 27 be            jsr $424a(pc)
  001a8e:  4e ba 2a 2c            jsr $44bc(pc)
  001a92:  54 8f                  addq.l #$2, a7
  001a94:  4e 75                  rts 
  001a96:  48 e7 1f 00            movem.l d3-d7, -(a7)
  001a9a:  3f 3c 00 27            move.w #$27, -(a7)
  001a9e:  4e ad 00 72            jsr $72(a5)
  001aa2:  3a 00                  move.w d0, d5
  001aa4:  70 03                  moveq #$3, d0
  001aa6:  c0 05                  and.b d5, d0
  001aa8:  0a 00 00 03            eori.b #$3, d0
  001aac:  78 07                  moveq #$7, d4
  001aae:  c8 05                  and.b d5, d4
  001ab0:  e9 0c                  lsl.b #$4, d4
  001ab2:  d8 00                  add.b d0, d4
  001ab4:  20 4d                  movea.l a5, a0
  001ab6:  d0 c5                  adda.w d5, a0
  001ab8:  16 28 9e 70            move.b -$6190(a0), d3
  001abc:  0a 03 00 55            eori.b #$55, d3
  001ac0:  96 04                  sub.b d4, d3
  001ac2:  10 03                  move.b d3, d0
  001ac4:  48 80                  ext.w d0
  001ac6:  3e 80                  move.w d0, (a7)
  001ac8:  4e ad 00 7a            jsr $7a(a5)
  001acc:  1b 40 97 4c            move.b d0, -$68b4(a5)
  001ad0:  1b 40 97 3b            move.b d0, -$68c5(a5)
  001ad4:  10 03                  move.b d3, d0
  001ad6:  48 80                  ext.w d0
  001ad8:  3e 80                  move.w d0, (a7)
  001ada:  4e ad 00 8a            jsr $8a(a5)
  001ade:  1b 40 97 4d            move.b d0, -$68b3(a5)
  001ae2:  1b 40 97 3c            move.b d0, -$68c4(a5)
  001ae6:  20 4d                  movea.l a5, a0
  001ae8:  d0 c5                  adda.w d5, a0
  001aea:  16 28 9e 98            move.b -$6168(a0), d3
  001aee:  0a 03 00 a3            eori.b #$a3, d3
  001af2:  96 04                  sub.b d4, d3
  001af4:  10 03                  move.b d3, d0
  001af6:  48 80                  ext.w d0
  001af8:  3e 80                  move.w d0, (a7)
  001afa:  4e ad 00 7a            jsr $7a(a5)
  001afe:  1b 40 97 55            move.b d0, -$68ab(a5)
  001b02:  1b 40 97 3f            move.b d0, -$68c1(a5)
  001b06:  10 03                  move.b d3, d0
  001b08:  48 80                  ext.w d0
  001b0a:  3e 80                  move.w d0, (a7)
  001b0c:  4e ad 00 8a            jsr $8a(a5)
  001b10:  1b 40 97 56            move.b d0, -$68aa(a5)
  001b14:  1b 40 97 40            move.b d0, -$68c0(a5)
  001b18:  20 4d                  movea.l a5, a0
  001b1a:  d0 c5                  adda.w d5, a0
  001b1c:  16 28 9e c0            move.b -$6140(a0), d3
  001b20:  0a 03 00 7c            eori.b #$7c, d3
  001b24:  96 04                  sub.b d4, d3
  001b26:  10 03                  move.b d3, d0
  001b28:  48 80                  ext.w d0
  001b2a:  3e 80                  move.w d0, (a7)
  001b2c:  4e ad 00 7a            jsr $7a(a5)
  001b30:  1b 40 97 5e            move.b d0, -$68a2(a5)
  001b34:  1b 40 97 43            move.b d0, -$68bd(a5)
  001b38:  10 03                  move.b d3, d0
  001b3a:  48 80                  ext.w d0
  001b3c:  3e 80                  move.w d0, (a7)
  001b3e:  4e ad 00 8a            jsr $8a(a5)
  001b42:  1b 40 97 5f            move.b d0, -$68a1(a5)
  001b46:  1b 40 97 44            move.b d0, -$68bc(a5)
  001b4a:  20 4d                  movea.l a5, a0
  001b4c:  d0 c5                  adda.w d5, a0
  001b4e:  16 28 9e e8            move.b -$6118(a0), d3
  001b52:  0a 03 00 69            eori.b #$69, d3
  001b56:  96 04                  sub.b d4, d3
  001b58:  7e 00                  moveq #$0, d7
  001b5a:  54 8f                  addq.l #$2, a7
  001b5c:  60 52                  bra.b $1bb0
  001b5e:  be 6d b9 42            cmp.w -$46be(a5), d7
  001b62:  67 3c                  beq.b $1ba0
  001b64:  3f 3c 00 19            move.w #$19, -(a7)
  001b68:  4e ad 00 72            jsr $72(a5)
  001b6c:  18 00                  move.b d0, d4
  001b6e:  54 8f                  addq.l #$2, a7
  001b70:  52 04                  addq.b #$1, d4
  001b72:  0c 04 00 1a            cmpi.b #$1a, d4
  001b76:  6f 02                  ble.b $1b7a
  001b78:  78 01                  moveq #$1, d4
  001b7a:  b6 04                  cmp.b d4, d3
  001b7c:  67 f2                  beq.b $1b70
  001b7e:  7c 00                  moveq #$0, d6
  001b80:  60 18                  bra.b $1b9a
  001b82:  10 04                  move.b d4, d0
  001b84:  48 80                  ext.w d0
  001b86:  20 4d                  movea.l a5, a0
  001b88:  d0 c6                  adda.w d6, a0
  001b8a:  12 28 9e 62            move.b -$619e(a0), d1
  001b8e:  48 81                  ext.w d1
  001b90:  06 41 ff c0            addi.w #$ffc0, d1
  001b94:  b2 40                  cmp.w d0, d1
  001b96:  67 d8                  beq.b $1b70
  001b98:  52 46                  addq.w #$1, d6
  001b9a:  be 46                  cmp.w d6, d7
  001b9c:  6e e4                  bgt.b $1b82
  001b9e:  60 02                  bra.b $1ba2
  001ba0:  18 03                  move.b d3, d4
  001ba2:  70 40                  moveq #$40, d0
  001ba4:  d0 04                  add.b d4, d0
  001ba6:  20 4d                  movea.l a5, a0
  001ba8:  d0 c7                  adda.w d7, a0
  001baa:  11 40 9e 62            move.b d0, -$619e(a0)
  001bae:  52 47                  addq.w #$1, d7
  001bb0:  0c 47 00 0e            cmpi.w #$e, d7
  001bb4:  6d a8                  blt.b $1b5e
  001bb6:  4c df 00 f8            movem.l (a7)+, d3-d7
  001bba:  4e 75                  rts 
  001bbc:  48 e7 0f 00            movem.l d4-d7, -(a7)
  001bc0:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  001bc6:  66 00 00 9c            bne.w $1c64
  001bca:  48 6d a0 b6            pea.l -$5f4a(a5)
  001bce:  a8 74                  dc.w $a874
  001bd0:  48 6d a2 5e            pea.l -$5da2(a5)
  001bd4:  a8 73                  dc.w $a873
  001bd6:  4a 2d a2 09            tst.b -$5df7(a5)
  001bda:  66 06                  bne.b $1be2
  001bdc:  3f 3c 00 10            move.w #$10, -(a7)
  001be0:  a8 88                  dc.w $a888
  001be2:  7e 00                  moveq #$0, d7
  001be4:  60 6e                  bra.b $1c54
  001be6:  20 4d                  movea.l a5, a0
  001be8:  d0 c7                  adda.w d7, a0
  001bea:  70 00                  moveq #$0, d0
  001bec:  10 28 a8 30            move.b -$57d0(a0), d0
  001bf0:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  001bf4:  66 5c                  bne.b $1c52
  001bf6:  20 4d                  movea.l a5, a0
  001bf8:  d0 c7                  adda.w d7, a0
  001bfa:  78 00                  moveq #$0, d4
  001bfc:  18 28 a8 3e            move.b -$57c2(a0), d4
  001c00:  2c 04                  move.l d4, d6
  001c02:  48 c6                  ext.l d6
  001c04:  8d fc 00 0a            divs.w #$a, d6
  001c08:  48 46                  swap d6
  001c0a:  eb 4e                  lsl.w #$5, d6
  001c0c:  2a 04                  move.l d4, d5
  001c0e:  48 c5                  ext.l d5
  001c10:  8b fc 00 0a            divs.w #$a, d5
  001c14:  cb fc 00 3f            muls.w #$3f, d5
  001c18:  4a 2d a2 0a            tst.b -$5df6(a5)
  001c1c:  67 0a                  beq.b $1c28
  001c1e:  06 46 00 1a            addi.w #$1a, d6
  001c22:  06 45 00 1c            addi.w #$1c, d5
  001c26:  60 06                  bra.b $1c2e
  001c28:  5e 46                  addq.w #$7, d6
  001c2a:  06 45 00 2a            addi.w #$2a, d5
  001c2e:  20 4d                  movea.l a5, a0
  001c30:  d0 c6                  adda.w d6, a0
  001c32:  d0 c6                  adda.w d6, a0
  001c34:  3f 28 98 66            move.w -$679a(a0), -(a7)
  001c38:  20 4d                  movea.l a5, a0
  001c3a:  d0 c5                  adda.w d5, a0
  001c3c:  d0 c5                  adda.w d5, a0
  001c3e:  3f 28 9c 64            move.w -$639c(a0), -(a7)
  001c42:  a8 93                  dc.w $a893
  001c44:  20 4d                  movea.l a5, a0
  001c46:  d0 c7                  adda.w d7, a0
  001c48:  10 28 9e 62            move.b -$619e(a0), d0
  001c4c:  48 80                  ext.w d0
  001c4e:  3f 00                  move.w d0, -(a7)
  001c50:  a8 83                  dc.w $a883
  001c52:  52 47                  addq.w #$1, d7
  001c54:  0c 47 00 0e            cmpi.w #$e, d7
  001c58:  6d 8c                  blt.b $1be6
  001c5a:  42 67                  clr.w -(a7)
  001c5c:  a8 88                  dc.w $a888
  001c5e:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  001c62:  a8 73                  dc.w $a873
  001c64:  4c df 00 f0            movem.l (a7)+, d4-d7
  001c68:  4e 75                  rts 
  001c6a:  42 6d ba a2            clr.w -$455e(a5)
  001c6e:  4e ba 00 10            jsr $1c80(pc)
  001c72:  4e ba 00 16            jsr $1c8a(pc)
  001c76:  4e ba f3 26            jsr $f9e(pc)
  001c7a:  4e ba eb 64            jsr $7e0(pc)
  001c7e:  4e 75                  rts 
  001c80:  4e ba 00 0e            jsr $1c90(pc)
  001c84:  4e ba 00 32            jsr $1cb8(pc)
  001c88:  4e 75                  rts 
  001c8a:  4e ba 00 4c            jsr $1cd8(pc)
  001c8e:  4e 75                  rts 
  001c90:  4e ba 27 ee            jsr $4480(pc)
  001c94:  4a 2d b9 46            tst.b -$46ba(a5)
  001c98:  67 14                  beq.b $1cae
  001c9a:  4e ba 25 ae            jsr $424a(pc)
  001c9e:  0c 2d 00 de b9 47      cmpi.b #$de, -$46b9(a5)
  001ca4:  65 04                  bcs.b $1caa
  001ca6:  42 2d b9 46            clr.b -$46ba(a5)
  001caa:  4e ba 27 e8            jsr $4494(pc)
  001cae:  4e ba ed 74            jsr $a24(pc)
  001cb2:  1b 40 a5 be            move.b d0, -$5a42(a5)
  001cb6:  4e 75                  rts 
  001cb8:  4e ba 28 62            jsr $451c(pc)
  001cbc:  4a 2d b9 46            tst.b -$46ba(a5)
  001cc0:  67 14                  beq.b $1cd6
  001cc2:  4e ba 25 86            jsr $424a(pc)
  001cc6:  0c 2d 00 de b9 47      cmpi.b #$de, -$46b9(a5)
  001ccc:  65 04                  bcs.b $1cd2
  001cce:  42 2d b9 46            clr.b -$46ba(a5)
  001cd2:  4e ba 27 e8            jsr $44bc(pc)
  001cd6:  4e 75                  rts 
  001cd8:  42 6d bd a4            clr.w -$425c(a5)
  001cdc:  42 6d bd a2            clr.w -$425e(a5)
  001ce0:  42 6d bd a0            clr.w -$4260(a5)
  001ce4:  42 6d bd 9e            clr.w -$4262(a5)
  001ce8:  42 6d bd 9c            clr.w -$4264(a5)
  001cec:  41 ed 04 ca            lea.l $4ca(a5), a0
  001cf0:  2b 48 bd 70            move.l a0, -$4290(a5)
  001cf4:  4e ba 27 8a            jsr $4480(pc)
  001cf8:  4a 2d b9 46            tst.b -$46ba(a5)
  001cfc:  67 12                  beq.b $1d10
  001cfe:  4e ad 05 22            jsr $522(a5)
  001d02:  1b 7c 00 1e ba f0      move.b #$1e, -$4510(a5)
  001d08:  42 27                  clr.b -(a7)
  001d0a:  4e ad 05 1a            jsr $51a(a5)
  001d0e:  54 8f                  addq.l #$2, a7
  001d10:  4e ba 27 96            jsr $44a8(pc)
  001d14:  4a 2d b9 46            tst.b -$46ba(a5)
  001d18:  67 12                  beq.b $1d2c
  001d1a:  4e ad 05 22            jsr $522(a5)
  001d1e:  1b 7c 00 1e ba f0      move.b #$1e, -$4510(a5)
  001d24:  42 27                  clr.b -(a7)
  001d26:  4e ad 05 1a            jsr $51a(a5)
  001d2a:  54 8f                  addq.l #$2, a7
  001d2c:  4e ad 04 fa            jsr $4fa(a5)
  001d30:  48 78 00 a7            pea.l $a7.w
  001d34:  2f 3c 00 02 00 1e      move.l #$2001e, -(a7)
  001d3a:  3f 3c 00 07            move.w #$7, -(a7)
  001d3e:  4e ad 04 da            jsr $4da(a5)
  001d42:  4e ba 07 ce            jsr $2512(pc)
  001d46:  4e ba 08 30            jsr $2578(pc)
  001d4a:  4e ad 05 02            jsr $502(a5)
  001d4e:  4f ef 00 0a            lea.l $a(a7), a7
  001d52:  4e 75                  rts 
  001d54:  4e 56 00 00            link.w a6, #$0
  001d58:  4e ba 27 4e            jsr $44a8(pc)
  001d5c:  3f 2e 00 08            move.w $8(a6), -(a7)
  001d60:  4e ad 05 52            jsr $552(a5)
  001d64:  4e ba 27 56            jsr $44bc(pc)
  001d68:  4e 5e                  unlk a6
  001d6a:  4e 75                  rts 
  001d6c:  4e 56 00 00            link.w a6, #$0
  001d70:  4e ba 27 0e            jsr $4480(pc)
  001d74:  3f 2e 00 08            move.w $8(a6), -(a7)
  001d78:  4e ad 05 52            jsr $552(a5)
  001d7c:  4e ba 27 16            jsr $4494(pc)
  001d80:  4e 5e                  unlk a6
  001d82:  4e 75                  rts 
  001d84:  4e ba 00 18            jsr $1d9e(pc)
  001d88:  1b 7c 00 90 b9 47      move.b #$90, -$46b9(a5)
  001d8e:  3f 3c 00 6a            move.w #$6a, -(a7)
  001d92:  4e ad 05 52            jsr $552(a5)
  001d96:  4e ba 24 b2            jsr $424a(pc)
  001d9a:  54 8f                  addq.l #$2, a7
  001d9c:  4e 75                  rts 
  001d9e:  1b 7c 00 18 b9 51      move.b #$18, -$46af(a5)
  001da4:  1b 7c 00 d2 b9 47      move.b #$d2, -$46b9(a5)
  001daa:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001db0:  4a 2d a2 0a            tst.b -$5df6(a5)
  001db4:  66 04                  bne.b $1dba
  001db6:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001dba:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001dc0:  3f 3c 00 69            move.w #$69, -(a7)
  001dc4:  4e ad 05 52            jsr $552(a5)
  001dc8:  4e ba 24 80            jsr $424a(pc)
  001dcc:  54 8f                  addq.l #$2, a7
  001dce:  4e 75                  rts 
  001dd0:  4e ba 00 d6            jsr $1ea8(pc)
  001dd4:  1b 7c 00 83 b9 47      move.b #$83, -$46b9(a5)
  001dda:  1b 7c 00 a9 b9 48      move.b #$a9, -$46b8(a5)
  001de0:  4a 2d a2 0a            tst.b -$5df6(a5)
  001de4:  66 04                  bne.b $1dea
  001de6:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001dea:  3f 3c 00 6e            move.w #$6e, -(a7)
  001dee:  4e ad 05 52            jsr $552(a5)
  001df2:  4e ba 24 56            jsr $424a(pc)
  001df6:  54 8f                  addq.l #$2, a7
  001df8:  4e 75                  rts 
  001dfa:  4e ba 00 5e            jsr $1e5a(pc)
  001dfe:  1b 7c 00 90 b9 47      move.b #$90, -$46b9(a5)
  001e04:  1b 7c 00 a9 b9 48      move.b #$a9, -$46b8(a5)
  001e0a:  4a 2d a2 0a            tst.b -$5df6(a5)
  001e0e:  66 04                  bne.b $1e14
  001e10:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001e14:  3f 3c 00 5e            move.w #$5e, -(a7)
  001e18:  4e ad 05 52            jsr $552(a5)
  001e1c:  4e ba 24 2c            jsr $424a(pc)
  001e20:  54 8f                  addq.l #$2, a7
  001e22:  4e 75                  rts 
  001e24:  4e ba 00 82            jsr $1ea8(pc)
  001e28:  1b 7c 00 92 b9 47      move.b #$92, -$46b9(a5)
  001e2e:  4e 75                  rts 
  001e30:  4e ba 00 76            jsr $1ea8(pc)
  001e34:  1b 7c 00 5d b9 47      move.b #$5d, -$46b9(a5)
  001e3a:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001e40:  4a 2d a2 0a            tst.b -$5df6(a5)
  001e44:  66 04                  bne.b $1e4a
  001e46:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001e4a:  3f 3c 00 67            move.w #$67, -(a7)
  001e4e:  4e ad 05 52            jsr $552(a5)
  001e52:  4e ba 23 f6            jsr $424a(pc)
  001e56:  54 8f                  addq.l #$2, a7
  001e58:  4e 75                  rts 
  001e5a:  4e ba 00 4c            jsr $1ea8(pc)
  001e5e:  42 2d b9 49            clr.b -$46b7(a5)
  001e62:  4e 75                  rts 
  001e64:  4e ba 00 42            jsr $1ea8(pc)
  001e68:  1b 7c 00 76 b9 47      move.b #$76, -$46b9(a5)
  001e6e:  1b 7c 00 a4 b9 48      move.b #$a4, -$46b8(a5)
  001e74:  4a 2d a2 0a            tst.b -$5df6(a5)
  001e78:  66 04                  bne.b $1e7e
  001e7a:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001e7e:  3f 3c 00 6d            move.w #$6d, -(a7)
  001e82:  4e ad 05 52            jsr $552(a5)
  001e86:  4e ba 23 c2            jsr $424a(pc)
  001e8a:  54 8f                  addq.l #$2, a7
  001e8c:  4e 75                  rts 
  001e8e:  4e ba ff 0e            jsr $1d9e(pc)
  001e92:  55 2d b9 47            subq.b #$2, -$46b9(a5)
  001e96:  1b 7c 00 a4 b9 48      move.b #$a4, -$46b8(a5)
  001e9c:  4a 2d a2 0a            tst.b -$5df6(a5)
  001ea0:  66 04                  bne.b $1ea6
  001ea2:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001ea6:  4e 75                  rts 
  001ea8:  1b 7c 00 05 b9 51      move.b #$5, -$46af(a5)
  001eae:  1b 7c 00 78 b9 47      move.b #$78, -$46b9(a5)
  001eb4:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001eba:  4a 2d a2 0a            tst.b -$5df6(a5)
  001ebe:  66 04                  bne.b $1ec4
  001ec0:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001ec4:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001eca:  3f 3c 00 5e            move.w #$5e, -(a7)
  001ece:  4e ad 05 52            jsr $552(a5)
  001ed2:  4e ba 23 76            jsr $424a(pc)
  001ed6:  54 8f                  addq.l #$2, a7
  001ed8:  4e 75                  rts 
  001eda:  1b 7c 00 06 b9 51      move.b #$6, -$46af(a5)
  001ee0:  1b 7c 00 c6 b9 47      move.b #$c6, -$46b9(a5)
  001ee6:  1b 7c 00 a6 b9 48      move.b #$a6, -$46b8(a5)
  001eec:  4a 2d a2 0a            tst.b -$5df6(a5)
  001ef0:  66 04                  bne.b $1ef6
  001ef2:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001ef6:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001efc:  3f 3c 00 5f            move.w #$5f, -(a7)
  001f00:  4e ad 05 52            jsr $552(a5)
  001f04:  4e ba 23 44            jsr $424a(pc)
  001f08:  54 8f                  addq.l #$2, a7
  001f0a:  4e 75                  rts 
  001f0c:  42 2d b9 51            clr.b -$46af(a5)
  001f10:  1b 7c 00 c6 b9 47      move.b #$c6, -$46b9(a5)
  001f16:  1b 7c 00 a4 b9 48      move.b #$a4, -$46b8(a5)
  001f1c:  4a 2d a2 0a            tst.b -$5df6(a5)
  001f20:  66 04                  bne.b $1f26
  001f22:  59 2d b9 48            subq.b #$4, -$46b8(a5)
  001f26:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  001f2c:  3f 3c 00 01            move.w #$1, -(a7)
  001f30:  4e ad 05 52            jsr $552(a5)
  001f34:  4e ba 23 14            jsr $424a(pc)
  001f38:  54 8f                  addq.l #$2, a7
  001f3a:  4e 75                  rts 
  001f3c:  30 2d a5 70            move.w -$5a90(a5), d0
  001f40:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  001f44:  4a 40                  tst.w d0
  001f46:  67 14                  beq.b $1f5c
  001f48:  6b 7c                  bmi.b $1fc6
  001f4a:  57 40                  subq.w #$3, d0
  001f4c:  67 5e                  beq.b $1fac
  001f4e:  6a 06                  bpl.b $1f56
  001f50:  52 40                  addq.w #$1, d0
  001f52:  6a 3e                  bpl.b $1f92
  001f54:  60 12                  bra.b $1f68
  001f56:  55 40                  subq.w #$2, d0
  001f58:  6a 6c                  bpl.b $1fc6
  001f5a:  60 62                  bra.b $1fbe
  001f5c:  3f 3c 00 23            move.w #$23, -(a7)
  001f60:  4e ad 00 da            jsr $da(a5)
  001f64:  54 8f                  addq.l #$2, a7
  001f66:  60 68                  bra.b $1fd0
  001f68:  4e ba 05 80            jsr $24ea(pc)
  001f6c:  3f 00                  move.w d0, -(a7)
  001f6e:  4e ba 05 68            jsr $24d8(pc)
  001f72:  4e ba fe 10            jsr $1d84(pc)
  001f76:  4e ba 25 1c            jsr $4494(pc)
  001f7a:  4e ba fe 54            jsr $1dd0(pc)
  001f7e:  4e ba 25 3c            jsr $44bc(pc)
  001f82:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  001f88:  3b 7c 00 14 a5 72      move.w #$14, -$5a8e(a5)
  001f8e:  54 8f                  addq.l #$2, a7
  001f90:  60 3e                  bra.b $1fd0
  001f92:  3f 3c 00 23            move.w #$23, -(a7)
  001f96:  4e ba e8 1c            jsr $7b4(pc)
  001f9a:  3e bc 00 6b            move.w #$6b, (a7)
  001f9e:  4e ba fd cc            jsr $1d6c(pc)
  001fa2:  3b 7c 00 14 a5 72      move.w #$14, -$5a8e(a5)
  001fa8:  54 8f                  addq.l #$2, a7
  001faa:  60 24                  bra.b $1fd0
  001fac:  3f 3c 00 6f            move.w #$6f, -(a7)
  001fb0:  4e ba fd a2            jsr $1d54(pc)
  001fb4:  3b 7c 00 1e a5 72      move.w #$1e, -$5a8e(a5)
  001fba:  54 8f                  addq.l #$2, a7
  001fbc:  60 12                  bra.b $1fd0
  001fbe:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  001fc4:  60 0a                  bra.b $1fd0
  001fc6:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  001fcc:  42 6d a5 70            clr.w -$5a90(a5)
  001fd0:  4e 75                  rts 
  001fd2:  30 2d a5 70            move.w -$5a90(a5), d0
  001fd6:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  001fda:  4a 40                  tst.w d0
  001fdc:  67 16                  beq.b $1ff4
  001fde:  6b 00 00 82            bmi.w $2062
  001fe2:  57 40                  subq.w #$3, d0
  001fe4:  67 52                  beq.b $2038
  001fe6:  6a 06                  bpl.b $1fee
  001fe8:  52 40                  addq.w #$1, d0
  001fea:  6a 3c                  bpl.b $2028
  001fec:  60 12                  bra.b $2000
  001fee:  55 40                  subq.w #$2, d0
  001ff0:  6a 70                  bpl.b $2062
  001ff2:  60 56                  bra.b $204a
  001ff4:  3f 3c 00 23            move.w #$23, -(a7)
  001ff8:  4e ad 00 da            jsr $da(a5)
  001ffc:  54 8f                  addq.l #$2, a7
  001ffe:  60 6c                  bra.b $206c
  002000:  3f 3c 00 23            move.w #$23, -(a7)
  002004:  4e ba e7 ae            jsr $7b4(pc)
  002008:  4e ba 04 e0            jsr $24ea(pc)
  00200c:  3e 80                  move.w d0, (a7)
  00200e:  4e ba 04 c8            jsr $24d8(pc)
  002012:  4e ba fd e6            jsr $1dfa(pc)
  002016:  4e ba 24 a4            jsr $44bc(pc)
  00201a:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  002020:  42 6d a5 72            clr.w -$5a8e(a5)
  002024:  54 8f                  addq.l #$2, a7
  002026:  60 44                  bra.b $206c
  002028:  4e ba fd 74            jsr $1d9e(pc)
  00202c:  4e ba 24 66            jsr $4494(pc)
  002030:  3b 7c 00 05 a5 72      move.w #$5, -$5a8e(a5)
  002036:  60 34                  bra.b $206c
  002038:  3f 3c 00 70            move.w #$70, -(a7)
  00203c:  4e ba fd 16            jsr $1d54(pc)
  002040:  3b 7c 00 09 a5 72      move.w #$9, -$5a8e(a5)
  002046:  54 8f                  addq.l #$2, a7
  002048:  60 22                  bra.b $206c
  00204a:  3f 3c 00 72            move.w #$72, -(a7)
  00204e:  4e ba fd 1c            jsr $1d6c(pc)
  002052:  3b 7c 00 3a a5 72      move.w #$3a, -$5a8e(a5)
  002058:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  00205e:  54 8f                  addq.l #$2, a7
  002060:  60 0a                  bra.b $206c
  002062:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  002068:  42 6d a5 70            clr.w -$5a90(a5)
  00206c:  4e 75                  rts 
  00206e:  30 2d a5 70            move.w -$5a90(a5), d0
  002072:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  002076:  0c 40 00 07            cmpi.w #$7, d0
  00207a:  62 00 00 a4            bhi.w $2120
  00207e:  43 fa 00 ac            lea.l $212c(pc), a1
  002082:  d0 40                  add.w d0, d0
  002084:  d2 f1 00 00            adda.w (a1, d0.w), a1
  002088:  4e d1                  jmp (a1)
  00208a:  3f 3c 00 1a            move.w #$1a, -(a7)
  00208e:  4e ad 00 da            jsr $da(a5)
  002092:  54 8f                  addq.l #$2, a7
  002094:  60 00 00 94            bra.w $212a
  002098:  3b 7c 00 01 ba a4      move.w #$1, -$455c(a5)
  00209e:  3f 3c 00 1a            move.w #$1a, -(a7)
  0020a2:  4e ba e7 10            jsr $7b4(pc)
  0020a6:  4e ba fd bc            jsr $1e64(pc)
  0020aa:  4e ba 24 10            jsr $44bc(pc)
  0020ae:  3b 7c 00 04 a5 72      move.w #$4, -$5a8e(a5)
  0020b4:  54 8f                  addq.l #$2, a7
  0020b6:  60 72                  bra.b $212a
  0020b8:  4e ba fe 52            jsr $1f0c(pc)
  0020bc:  4e ba 23 d6            jsr $4494(pc)
  0020c0:  3b 7c 00 0c a5 72      move.w #$c, -$5a8e(a5)
  0020c6:  60 62                  bra.b $212a
  0020c8:  3f 3c 00 6c            move.w #$6c, -(a7)
  0020cc:  4e ba fc 86            jsr $1d54(pc)
  0020d0:  3b 7c 00 04 a5 72      move.w #$4, -$5a8e(a5)
  0020d6:  54 8f                  addq.l #$2, a7
  0020d8:  60 50                  bra.b $212a
  0020da:  3f 3c 00 0d            move.w #$d, -(a7)
  0020de:  4e ba fc 8c            jsr $1d6c(pc)
  0020e2:  3b 7c 00 01 a5 72      move.w #$1, -$5a8e(a5)
  0020e8:  54 8f                  addq.l #$2, a7
  0020ea:  60 3e                  bra.b $212a
  0020ec:  42 2d b9 6a            clr.b -$4696(a5)
  0020f0:  3b 7c 00 27 a5 72      move.w #$27, -$5a8e(a5)
  0020f6:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  0020fc:  60 2c                  bra.b $212a
  0020fe:  4e ba fd 8e            jsr $1e8e(pc)
  002102:  4e ba 23 90            jsr $4494(pc)
  002106:  3b 7c 00 0e a5 72      move.w #$e, -$5a8e(a5)
  00210c:  60 1c                  bra.b $212a
  00210e:  3f 3c 00 65            move.w #$65, -(a7)
  002112:  4e ba fc 58            jsr $1d6c(pc)
  002116:  3b 7c 00 29 a5 72      move.w #$29, -$5a8e(a5)
  00211c:  54 8f                  addq.l #$2, a7
  00211e:  60 0a                  bra.b $212a
  002120:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  002126:  42 6d a5 70            clr.w -$5a90(a5)
  00212a:  4e 75                  rts 
  00212c:  ff 5e                  dc.w $ff5e
  00212e:  ff 6c                  dc.w $ff6c
  002130:  ff 8c                  dc.w $ff8c
  002132:  ff 9c                  dc.w $ff9c
  002134:  ff ae                  dc.w $ffae
  002136:  ff c0                  dc.w $ffc0
  002138:  ff d2                  dc.w $ffd2
  00213a:  ff e2                  dc.w $ffe2
  00213c:  30 2d a5 70            move.w -$5a90(a5), d0
  002140:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  002144:  4a 40                  tst.w d0
  002146:  67 0a                  beq.b $2152
  002148:  6b 4e                  bmi.b $2198
  00214a:  55 40                  subq.w #$2, d0
  00214c:  67 3c                  beq.b $218a
  00214e:  6a 48                  bpl.b $2198
  002150:  60 0c                  bra.b $215e
  002152:  3f 3c 00 24            move.w #$24, -(a7)
  002156:  4e ad 00 da            jsr $da(a5)
  00215a:  54 8f                  addq.l #$2, a7
  00215c:  60 44                  bra.b $21a2
  00215e:  3b 7c 00 01 ba a4      move.w #$1, -$455c(a5)
  002164:  3f 3c 00 07            move.w #$7, -(a7)
  002168:  4e ba 03 6e            jsr $24d8(pc)
  00216c:  3b 7c ff ff ba 9c      move.w #$ffff, -$4564(a5)
  002172:  3e bc 00 24            move.w #$24, (a7)
  002176:  4e ba e6 3c            jsr $7b4(pc)
  00217a:  3b 7c 00 06 a5 5c      move.w #$6, -$5aa4(a5)
  002180:  3b 7c 00 02 a5 72      move.w #$2, -$5a8e(a5)
  002186:  54 8f                  addq.l #$2, a7
  002188:  60 18                  bra.b $21a2
  00218a:  3b 7c 00 64 a5 72      move.w #$64, -$5a8e(a5)
  002190:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  002196:  60 0a                  bra.b $21a2
  002198:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  00219e:  42 6d a5 70            clr.w -$5a90(a5)
  0021a2:  4e 75                  rts 
  0021a4:  30 2d a5 70            move.w -$5a90(a5), d0
  0021a8:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  0021ac:  4a 40                  tst.w d0
  0021ae:  67 0a                  beq.b $21ba
  0021b0:  6b 56                  bmi.b $2208
  0021b2:  55 40                  subq.w #$2, d0
  0021b4:  67 3a                  beq.b $21f0
  0021b6:  6a 50                  bpl.b $2208
  0021b8:  60 0c                  bra.b $21c6
  0021ba:  3f 3c 00 28            move.w #$28, -(a7)
  0021be:  4e ad 00 da            jsr $da(a5)
  0021c2:  54 8f                  addq.l #$2, a7
  0021c4:  60 4c                  bra.b $2212
  0021c6:  3f 3c 00 28            move.w #$28, -(a7)
  0021ca:  4e ba e5 e8            jsr $7b4(pc)
  0021ce:  4e ba 03 1a            jsr $24ea(pc)
  0021d2:  3e 80                  move.w d0, (a7)
  0021d4:  4e ba 03 02            jsr $24d8(pc)
  0021d8:  4e ba fc 4a            jsr $1e24(pc)
  0021dc:  4e ba 22 de            jsr $44bc(pc)
  0021e0:  3b 7c 00 06 a5 5c      move.w #$6, -$5aa4(a5)
  0021e6:  3b 7c 00 02 a5 72      move.w #$2, -$5a8e(a5)
  0021ec:  54 8f                  addq.l #$2, a7
  0021ee:  60 22                  bra.b $2212
  0021f0:  3f 3c 00 62            move.w #$62, -(a7)
  0021f4:  4e ba fb 5e            jsr $1d54(pc)
  0021f8:  3b 7c 00 18 a5 72      move.w #$18, -$5a8e(a5)
  0021fe:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  002204:  54 8f                  addq.l #$2, a7
  002206:  60 0a                  bra.b $2212
  002208:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  00220e:  42 6d a5 70            clr.w -$5a90(a5)
  002212:  4e 75                  rts 
  002214:  30 2d a5 70            move.w -$5a90(a5), d0
  002218:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  00221c:  4a 40                  tst.w d0
  00221e:  67 08                  beq.b $2228
  002220:  6b 42                  bmi.b $2264
  002222:  55 40                  subq.w #$2, d0
  002224:  6a 3e                  bpl.b $2264
  002226:  60 0c                  bra.b $2234
  002228:  3f 3c 00 1b            move.w #$1b, -(a7)
  00222c:  4e ad 00 da            jsr $da(a5)
  002230:  54 8f                  addq.l #$2, a7
  002232:  60 3a                  bra.b $226e
  002234:  3f 3c 00 1b            move.w #$1b, -(a7)
  002238:  4e ba e5 7a            jsr $7b4(pc)
  00223c:  4e ba 02 ac            jsr $24ea(pc)
  002240:  3e 80                  move.w d0, (a7)
  002242:  4e ba 02 94            jsr $24d8(pc)
  002246:  4e ba fb e8            jsr $1e30(pc)
  00224a:  4e ba 22 70            jsr $44bc(pc)
  00224e:  3b 7c 00 06 a5 5c      move.w #$6, -$5aa4(a5)
  002254:  3b 7c 00 4b a5 72      move.w #$4b, -$5a8e(a5)
  00225a:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  002260:  54 8f                  addq.l #$2, a7
  002262:  60 0a                  bra.b $226e
  002264:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  00226a:  42 6d a5 70            clr.w -$5a90(a5)
  00226e:  4e 75                  rts 
  002270:  30 2d a5 70            move.w -$5a90(a5), d0
  002274:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  002278:  4a 40                  tst.w d0
  00227a:  67 08                  beq.b $2284
  00227c:  6b 42                  bmi.b $22c0
  00227e:  55 40                  subq.w #$2, d0
  002280:  6a 3e                  bpl.b $22c0
  002282:  60 0c                  bra.b $2290
  002284:  3f 3c 00 1b            move.w #$1b, -(a7)
  002288:  4e ad 00 da            jsr $da(a5)
  00228c:  54 8f                  addq.l #$2, a7
  00228e:  60 3a                  bra.b $22ca
  002290:  3f 3c 00 1b            move.w #$1b, -(a7)
  002294:  4e ba e5 1e            jsr $7b4(pc)
  002298:  4e ba 02 50            jsr $24ea(pc)
  00229c:  3e 80                  move.w d0, (a7)
  00229e:  4e ba 02 38            jsr $24d8(pc)
  0022a2:  4e ba fb b6            jsr $1e5a(pc)
  0022a6:  4e ba 22 14            jsr $44bc(pc)
  0022aa:  3b 7c 00 06 a5 5c      move.w #$6, -$5aa4(a5)
  0022b0:  3b 7c 00 4b a5 72      move.w #$4b, -$5a8e(a5)
  0022b6:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  0022bc:  54 8f                  addq.l #$2, a7
  0022be:  60 0a                  bra.b $22ca
  0022c0:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  0022c6:  42 6d a5 70            clr.w -$5a90(a5)
  0022ca:  4e 75                  rts 
  0022cc:  30 2d a5 70            move.w -$5a90(a5), d0
  0022d0:  52 6d a5 70            addq.w #$1, -$5a90(a5)
  0022d4:  0c 40 00 13            cmpi.w #$13, d0
  0022d8:  62 00 01 ca            bhi.w $24a4
  0022dc:  43 fa 01 d2            lea.l $24b0(pc), a1
  0022e0:  d0 40                  add.w d0, d0
  0022e2:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0022e6:  4e d1                  jmp (a1)
  0022e8:  3f 3c 00 32            move.w #$32, -(a7)
  0022ec:  4e ad 00 da            jsr $da(a5)
  0022f0:  3e bc 00 33            move.w #$33, (a7)
  0022f4:  4e ad 00 da            jsr $da(a5)
  0022f8:  3e bc 00 35            move.w #$35, (a7)
  0022fc:  4e ad 00 da            jsr $da(a5)
  002300:  3e bc 00 38            move.w #$38, (a7)
  002304:  4e ad 00 da            jsr $da(a5)
  002308:  54 8f                  addq.l #$2, a7
  00230a:  60 00 01 a2            bra.w $24ae
  00230e:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  002314:  4e ba fb 92            jsr $1ea8(pc)
  002318:  4e ba 21 a2            jsr $44bc(pc)
  00231c:  3b 7c 00 01 a5 72      move.w #$1, -$5a8e(a5)
  002322:  60 00 01 8a            bra.w $24ae
  002326:  3f 3c 00 32            move.w #$32, -(a7)
  00232a:  4e ba e4 88            jsr $7b4(pc)
  00232e:  4e ba fb aa            jsr $1eda(pc)
  002332:  4e ba 21 60            jsr $4494(pc)
  002336:  3b 7c 00 02 a5 72      move.w #$2, -$5a8e(a5)
  00233c:  54 8f                  addq.l #$2, a7
  00233e:  60 00 01 6e            bra.w $24ae
  002342:  3b 7c 00 05 a5 72      move.w #$5, -$5a8e(a5)
  002348:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  00234e:  60 00 01 5e            bra.w $24ae
  002352:  3b 7c 00 05 a5 72      move.w #$5, -$5a8e(a5)
  002358:  60 00 01 54            bra.w $24ae
  00235c:  3f 3c 00 33            move.w #$33, -(a7)
  002360:  4e ba e4 52            jsr $7b4(pc)
  002364:  3b 7c 00 01 a5 72      move.w #$1, -$5a8e(a5)
  00236a:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  002370:  54 8f                  addq.l #$2, a7
  002372:  60 00 01 3a            bra.w $24ae
  002376:  3f 3c 00 35            move.w #$35, -(a7)
  00237a:  4e ba e4 38            jsr $7b4(pc)
  00237e:  3b 7c 00 03 a5 72      move.w #$3, -$5a8e(a5)
  002384:  54 8f                  addq.l #$2, a7
  002386:  60 00 01 26            bra.w $24ae
  00238a:  3f 3c 00 62            move.w #$62, -(a7)
  00238e:  4e ba f9 c4            jsr $1d54(pc)
  002392:  3b 7c 00 05 a5 72      move.w #$5, -$5a8e(a5)
  002398:  54 8f                  addq.l #$2, a7
  00239a:  60 00 01 12            bra.w $24ae
  00239e:  3f 3c 00 60            move.w #$60, -(a7)
  0023a2:  4e ba f9 c8            jsr $1d6c(pc)
  0023a6:  3b 7c 00 06 a5 72      move.w #$6, -$5a8e(a5)
  0023ac:  54 8f                  addq.l #$2, a7
  0023ae:  60 00 00 fe            bra.w $24ae
  0023b2:  3f 3c 00 61            move.w #$61, -(a7)
  0023b6:  4e ba f9 b4            jsr $1d6c(pc)
  0023ba:  3b 7c 00 04 a5 72      move.w #$4, -$5a8e(a5)
  0023c0:  54 8f                  addq.l #$2, a7
  0023c2:  60 00 00 ea            bra.w $24ae
  0023c6:  3b 7c 00 06 a5 72      move.w #$6, -$5a8e(a5)
  0023cc:  60 00 00 e0            bra.w $24ae
  0023d0:  3f 3c 00 60            move.w #$60, -(a7)
  0023d4:  4e ba f9 96            jsr $1d6c(pc)
  0023d8:  3b 7c 00 1e a5 72      move.w #$1e, -$5a8e(a5)
  0023de:  54 8f                  addq.l #$2, a7
  0023e0:  60 00 00 cc            bra.w $24ae
  0023e4:  3f 3c 00 61            move.w #$61, -(a7)
  0023e8:  4e ba f9 82            jsr $1d6c(pc)
  0023ec:  3b 7c 00 10 a5 72      move.w #$10, -$5a8e(a5)
  0023f2:  2b 7c 00 00 03 43 a5 6c move.l #$343, -$5a94(a5)
  0023fa:  54 8f                  addq.l #$2, a7
  0023fc:  60 00 00 b0            bra.w $24ae
  002400:  3f 3c 00 66            move.w #$66, -(a7)
  002404:  4e ba f9 66            jsr $1d6c(pc)
  002408:  3b 7c 00 01 a5 72      move.w #$1, -$5a8e(a5)
  00240e:  54 8f                  addq.l #$2, a7
  002410:  60 00 00 9c            bra.w $24ae
  002414:  3f 3c 00 63            move.w #$63, -(a7)
  002418:  4e ba f9 3a            jsr $1d54(pc)
  00241c:  3b 7c 00 11 a5 72      move.w #$11, -$5a8e(a5)
  002422:  2b 7c 00 00 03 b6 a5 6c move.l #$3b6, -$5a94(a5)
  00242a:  54 8f                  addq.l #$2, a7
  00242c:  60 00 00 80            bra.w $24ae
  002430:  3b 7c 00 01 ba 9e      move.w #$1, -$4562(a5)
  002436:  3b 7c 00 05 ba 1a      move.w #$5, -$45e6(a5)
  00243c:  3b 7c 00 07 ba 18      move.w #$7, -$45e8(a5)
  002442:  3b 7c 00 09 a5 72      move.w #$9, -$5a8e(a5)
  002448:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  00244e:  60 5e                  bra.b $24ae
  002450:  3f 3c 00 64            move.w #$64, -(a7)
  002454:  4e ba f9 16            jsr $1d6c(pc)
  002458:  3e bc 00 38            move.w #$38, (a7)
  00245c:  4e ba e3 56            jsr $7b4(pc)
  002460:  42 6d ba 9c            clr.w -$4564(a5)
  002464:  3b 7c 00 06 a5 72      move.w #$6, -$5a8e(a5)
  00246a:  54 8f                  addq.l #$2, a7
  00246c:  60 40                  bra.b $24ae
  00246e:  3b 7c 00 18 a5 72      move.w #$18, -$5a8e(a5)
  002474:  60 38                  bra.b $24ae
  002476:  3b 7c 00 02 ba 9e      move.w #$2, -$4562(a5)
  00247c:  3b 7c 00 09 a5 72      move.w #$9, -$5a8e(a5)
  002482:  2b 7c 00 00 01 5e a5 6c move.l #$15e, -$5a94(a5)
  00248a:  60 22                  bra.b $24ae
  00248c:  3f 3c 00 71            move.w #$71, -(a7)
  002490:  4e ba f8 c2            jsr $1d54(pc)
  002494:  3b 7c 00 1c a5 72      move.w #$1c, -$5a8e(a5)
  00249a:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  0024a0:  54 8f                  addq.l #$2, a7
  0024a2:  60 0a                  bra.b $24ae
  0024a4:  3b 7c 00 05 a5 5c      move.w #$5, -$5aa4(a5)
  0024aa:  42 6d a5 70            clr.w -$5a90(a5)
  0024ae:  4e 75                  rts 
  0024b0:  fe 38                  dc.w $fe38
  0024b2:  fe 5e                  dc.w $fe5e
  0024b4:  fe 76                  dc.w $fe76
  0024b6:  fe 92                  dc.w $fe92
  0024b8:  fe a2                  dc.w $fea2
  0024ba:  fe ac                  dc.w $feac
  0024bc:  fe c6                  dc.w $fec6
  0024be:  fe da                  dc.w $feda
  0024c0:  fe ee                  dc.w $feee
  0024c2:  ff 02                  dc.w $ff02
  0024c4:  ff 16                  dc.w $ff16
  0024c6:  ff 20                  dc.w $ff20
  0024c8:  ff 34                  dc.w $ff34
  0024ca:  ff 50                  dc.w $ff50
  0024cc:  ff 64                  dc.w $ff64
  0024ce:  ff 80                  dc.w $ff80
  0024d0:  ff a0                  dc.w $ffa0
  0024d2:  ff be                  dc.w $ffbe
  0024d4:  ff c6                  dc.w $ffc6
  0024d6:  ff dc                  dc.w $ffdc
  0024d8:  4e 56 00 00            link.w a6, #$0
  0024dc:  42 6d ba 9c            clr.w -$4564(a5)
  0024e0:  3b 6e 00 08 ba 9e      move.w $8(a6), -$4562(a5)
  0024e6:  4e 5e                  unlk a6
  0024e8:  4e 75                  rts 
  0024ea:  48 e7 01 08            movem.l d7/a4, -(a7)
  0024ee:  7e 00                  moveq #$0, d7
  0024f0:  49 ed a9 10            lea.l -$56f0(a5), a4
  0024f4:  60 0c                  bra.b $2502
  0024f6:  30 2d ba 8c            move.w -$4574(a5), d0
  0024fa:  b0 54                  cmp.w (a4), d0
  0024fc:  6d 0a                  blt.b $2508
  0024fe:  52 47                  addq.w #$1, d7
  002500:  54 8c                  addq.l #$2, a4
  002502:  0c 47 00 04            cmpi.w #$4, d7
  002506:  6d ee                  blt.b $24f6
  002508:  70 06                  moveq #$6, d0
  00250a:  90 47                  sub.w d7, d0
  00250c:  4c df 10 80            movem.l (a7)+, d7/a4
  002510:  4e 75                  rts 
  002512:  2f 07                  move.l d7, -(a7)
  002514:  7e 01                  moveq #$1, d7
  002516:  de 6d a9 20            add.w -$56e0(a5), d7
  00251a:  0c 47 00 03            cmpi.w #$3, d7
  00251e:  6f 02                  ble.b $2522
  002520:  7e 01                  moveq #$1, d7
  002522:  3f 3c 00 79            move.w #$79, -(a7)
  002526:  3f 2d a9 1c            move.w -$56e4(a5), -(a7)
  00252a:  3f 2d a9 18            move.w -$56e8(a5), -(a7)
  00252e:  70 0c                  moveq #$c, d0
  002530:  d0 47                  add.w d7, d0
  002532:  3f 00                  move.w d0, -(a7)
  002534:  3f 3c 00 07            move.w #$7, -(a7)
  002538:  4e ad 04 ca            jsr $4ca(a5)
  00253c:  3b 47 a9 20            move.w d7, -$56e0(a5)
  002540:  7e 01                  moveq #$1, d7
  002542:  de 6d a9 22            add.w -$56de(a5), d7
  002546:  0c 47 00 03            cmpi.w #$3, d7
  00254a:  4f ef 00 0a            lea.l $a(a7), a7
  00254e:  6f 02                  ble.b $2552
  002550:  7e 01                  moveq #$1, d7
  002552:  3f 3c 00 79            move.w #$79, -(a7)
  002556:  3f 2d a9 1e            move.w -$56e2(a5), -(a7)
  00255a:  3f 2d a9 1a            move.w -$56e6(a5), -(a7)
  00255e:  70 0c                  moveq #$c, d0
  002560:  d0 47                  add.w d7, d0
  002562:  3f 00                  move.w d0, -(a7)
  002564:  3f 3c 00 07            move.w #$7, -(a7)
  002568:  4e ad 04 ca            jsr $4ca(a5)
  00256c:  3b 47 a9 22            move.w d7, -$56de(a5)
  002570:  4f ef 00 0a            lea.l $a(a7), a7
  002574:  2e 1f                  move.l (a7)+, d7
  002576:  4e 75                  rts 
  002578:  2f 07                  move.l d7, -(a7)
  00257a:  4a 6d ba 9c            tst.w -$4564(a5)
  00257e:  6d 42                  blt.b $25c2
  002580:  30 2d ba 9c            move.w -$4564(a5), d0
  002584:  52 40                  addq.w #$1, d0
  002586:  48 c0                  ext.l d0
  002588:  81 fc 00 03            divs.w #$3, d0
  00258c:  48 40                  swap d0
  00258e:  3b 40 ba 9c            move.w d0, -$4564(a5)
  002592:  0c 6d 00 07 ba 9e      cmpi.w #$7, -$4562(a5)
  002598:  6c 5a                  bge.b $25f4
  00259a:  3e 3c 00 a4            move.w #$a4, d7
  00259e:  4a 2d a2 0a            tst.b -$5df6(a5)
  0025a2:  66 02                  bne.b $25a6
  0025a4:  57 47                  subq.w #$3, d7
  0025a6:  3f 07                  move.w d7, -(a7)
  0025a8:  2f 3c 00 14 00 00      move.l #$140000, -(a7)
  0025ae:  70 0a                  moveq #$a, d0
  0025b0:  d0 6d ba 9c            add.w -$4564(a5), d0
  0025b4:  3f 00                  move.w d0, -(a7)
  0025b6:  3f 3c 00 07            move.w #$7, -(a7)
  0025ba:  4e ad 04 da            jsr $4da(a5)
  0025be:  4f ef 00 0a            lea.l $a(a7), a7
  0025c2:  4a 6d ba 9e            tst.w -$4562(a5)
  0025c6:  67 2c                  beq.b $25f4
  0025c8:  3e 3c 00 a8            move.w #$a8, d7
  0025cc:  4a 2d a2 0a            tst.b -$5df6(a5)
  0025d0:  66 02                  bne.b $25d4
  0025d2:  57 47                  subq.w #$3, d7
  0025d4:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  0025d8:  3f 07                  move.w d7, -(a7)
  0025da:  2f 3c 00 13 00 00      move.l #$130000, -(a7)
  0025e0:  70 02                  moveq #$2, d0
  0025e2:  d0 6d ba 9e            add.w -$4562(a5), d0
  0025e6:  3f 00                  move.w d0, -(a7)
  0025e8:  3f 3c 00 07            move.w #$7, -(a7)
  0025ec:  4e ad 04 d2            jsr $4d2(a5)
  0025f0:  4f ef 00 0a            lea.l $a(a7), a7
  0025f4:  2e 1f                  move.l (a7)+, d7
  0025f6:  4e 75                  rts 
  0025f8:  30 2d a5 66            move.w -$5a9a(a5), d0
  0025fc:  52 6d a5 66            addq.w #$1, -$5a9a(a5)
  002600:  0c 40 00 08            cmpi.w #$8, d0
  002604:  62 00 01 3e            bhi.w $2744
  002608:  43 fa 01 46            lea.l $2750(pc), a1
  00260c:  d0 40                  add.w d0, d0
  00260e:  d2 f1 00 00            adda.w (a1, d0.w), a1
  002612:  4e d1                  jmp (a1)
  002614:  48 6d 02 1a            pea.l $21a(a5)
  002618:  3f 3c 00 01            move.w #$1, -(a7)
  00261c:  4e ba 01 8c            jsr $27aa(pc)
  002620:  5c 8f                  addq.l #$6, a7
  002622:  60 00 01 24            bra.w $2748
  002626:  4e ba e8 e4            jsr $f0c(pc)
  00262a:  3f 3c 00 39            move.w #$39, -(a7)
  00262e:  4e ad 00 da            jsr $da(a5)
  002632:  1b 7c 00 01 96 45      move.b #$1, -$69bb(a5)
  002638:  4e ad 00 ea            jsr $ea(a5)
  00263c:  3e bc 00 10            move.w #$10, (a7)
  002640:  4e ba e8 94            jsr $ed6(pc)
  002644:  2f 3c 00 19 00 01      move.l #$190001, -(a7)
  00264a:  2f 3c 00 03 00 18      move.l #$30018, -(a7)
  002650:  3f 3c 00 03            move.w #$3, -(a7)
  002654:  4e ad 04 e2            jsr $4e2(a5)
  002658:  3b 7c 00 03 a5 5c      move.w #$3, -$5aa4(a5)
  00265e:  4f ef 00 0c            lea.l $c(a7), a7
  002662:  60 00 00 e4            bra.w $2748
  002666:  3f 3c 00 39            move.w #$39, -(a7)
  00266a:  4e ad 00 fa            jsr $fa(a5)
  00266e:  3b 7c 00 96 a5 68      move.w #$96, -$5a98(a5)
  002674:  2b 7c 00 00 05 78 a5 6c move.l #$578, -$5a94(a5)
  00267c:  54 8f                  addq.l #$2, a7
  00267e:  60 00 00 c8            bra.w $2748
  002682:  4e ba 02 1a            jsr $289e(pc)
  002686:  4a 00                  tst.b d0
  002688:  66 00 00 be            bne.w $2748
  00268c:  56 6d a5 66            addq.w #$3, -$5a9a(a5)
  002690:  60 00 00 b6            bra.w $2748
  002694:  3f 3c 00 10            move.w #$10, -(a7)
  002698:  4e ba e8 3c            jsr $ed6(pc)
  00269c:  2f 3c 00 14 00 01      move.l #$140001, -(a7)
  0026a2:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  0026a8:  3f 3c 00 04            move.w #$4, -(a7)
  0026ac:  4e ad 04 e2            jsr $4e2(a5)
  0026b0:  4e ba 04 60            jsr $2b12(pc)
  0026b4:  3b 7c 00 02 a5 68      move.w #$2, -$5a98(a5)
  0026ba:  4f ef 00 0c            lea.l $c(a7), a7
  0026be:  60 00 00 88            bra.w $2748
  0026c2:  4e ba 02 50            jsr $2914(pc)
  0026c6:  3b 7c 00 01 a5 68      move.w #$1, -$5a98(a5)
  0026cc:  60 7a                  bra.b $2748
  0026ce:  3f 3c 00 10            move.w #$10, -(a7)
  0026d2:  4e ba e8 02            jsr $ed6(pc)
  0026d6:  2f 3c 00 14 00 01      move.l #$140001, -(a7)
  0026dc:  2f 3c 00 03 00 17      move.l #$30017, -(a7)
  0026e2:  3f 3c 00 04            move.w #$4, -(a7)
  0026e6:  4e ad 04 e2            jsr $4e2(a5)
  0026ea:  4e ba 04 26            jsr $2b12(pc)
  0026ee:  3b 7c 00 5a a5 68      move.w #$5a, -$5a98(a5)
  0026f4:  4f ef 00 0c            lea.l $c(a7), a7
  0026f8:  60 4e                  bra.b $2748
  0026fa:  3f 3c 00 02            move.w #$2, -(a7)
  0026fe:  4e ba e7 d6            jsr $ed6(pc)
  002702:  48 78 00 01            pea.l $1.w
  002706:  42 a7                  clr.l -(a7)
  002708:  3f 3c 00 04            move.w #$4, -(a7)
  00270c:  4e ad 04 e2            jsr $4e2(a5)
  002710:  3b 7c 00 3c a5 68      move.w #$3c, -$5a98(a5)
  002716:  1b 7c 00 01 a5 6a      move.b #$1, -$5a96(a5)
  00271c:  4f ef 00 0c            lea.l $c(a7), a7
  002720:  60 26                  bra.b $2748
  002722:  4e ba e8 12            jsr $f36(pc)
  002726:  1f 3c 00 02            move.b #$2, -(a7)
  00272a:  48 6d a5 c4            pea.l -$5a3c(a5)
  00272e:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  002732:  4e 90                  jsr (a0)
  002734:  3b 7c 00 02 a5 5c      move.w #$2, -$5aa4(a5)
  00273a:  3b 7c 00 14 a5 68      move.w #$14, -$5a98(a5)
  002740:  5c 8f                  addq.l #$6, a7
  002742:  60 04                  bra.b $2748
  002744:  42 6d a5 66            clr.w -$5a9a(a5)
  002748:  48 6d a5 c4            pea.l -$5a3c(a5)
  00274c:  a9 28                  dc.w $a928
  00274e:  4e 75                  rts 
  002750:  fe c4                  dc.w $fec4
  002752:  fe d6                  dc.w $fed6
  002754:  ff 16                  dc.w $ff16
  002756:  ff 32                  dc.w $ff32
  002758:  ff 44                  dc.w $ff44
  00275a:  ff 72                  dc.w $ff72
  00275c:  ff 7e                  dc.w $ff7e
  00275e:  ff aa                  dc.w $ffaa
  002760:  ff d2                  dc.w $ffd2
  002762:  30 2d a5 66            move.w -$5a9a(a5), d0
  002766:  52 6d a5 66            addq.w #$1, -$5a9a(a5)
  00276a:  4a 40                  tst.w d0
  00276c:  67 08                  beq.b $2776
  00276e:  6b 2e                  bmi.b $279e
  002770:  55 40                  subq.w #$2, d0
  002772:  6a 2a                  bpl.b $279e
  002774:  60 10                  bra.b $2786
  002776:  48 6d 02 22            pea.l $222(a5)
  00277a:  3f 3c 00 01            move.w #$1, -(a7)
  00277e:  4e ba 00 2a            jsr $27aa(pc)
  002782:  5c 8f                  addq.l #$6, a7
  002784:  60 1c                  bra.b $27a2
  002786:  1f 3c 00 02            move.b #$2, -(a7)
  00278a:  48 6d a5 c4            pea.l -$5a3c(a5)
  00278e:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  002792:  4e 90                  jsr (a0)
  002794:  3b 7c 00 1e a5 68      move.w #$1e, -$5a98(a5)
  00279a:  5c 8f                  addq.l #$6, a7
  00279c:  60 04                  bra.b $27a2
  00279e:  42 6d a5 66            clr.w -$5a9a(a5)
  0027a2:  48 6d a5 c4            pea.l -$5a3c(a5)
  0027a6:  a9 28                  dc.w $a928
  0027a8:  4e 75                  rts 
  0027aa:  4e 56 00 00            link.w a6, #$0
  0027ae:  4e ba e7 a2            jsr $f52(pc)
  0027b2:  2f 3c 00 06 03 b6      move.l #$603b6, -(a7)
  0027b8:  4e ba e0 ac            jsr $866(pc)
  0027bc:  3b 7c 00 01 f2 28      move.w #$1, -$dd8(a5)
  0027c2:  2b 6d a5 c4 a2 e4      move.l -$5a3c(a5), -$5d1c(a5)
  0027c8:  2b 6d a5 c8 a2 e8      move.l -$5a38(a5), -$5d18(a5)
  0027ce:  1e bc 00 02            move.b #$2, (a7)
  0027d2:  48 6d a5 c4            pea.l -$5a3c(a5)
  0027d6:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  0027da:  4e 90                  jsr (a0)
  0027dc:  70 01                  moveq #$1, d0
  0027de:  2e 80                  move.l d0, (a7)
  0027e0:  42 a7                  clr.l -(a7)
  0027e2:  3f 3c 00 06            move.w #$6, -(a7)
  0027e6:  4e ad 04 e2            jsr $4e2(a5)
  0027ea:  3e bc 00 06            move.w #$6, (a7)
  0027ee:  4e ba e1 f4            jsr $9e4(pc)
  0027f2:  2e bc 00 03 03 20      move.l #$30320, (a7)
  0027f8:  4e ba e0 6c            jsr $866(pc)
  0027fc:  30 2e 00 08            move.w $8(a6), d0
  002800:  4f ef 00 0e            lea.l $e(a7), a7
  002804:  67 08                  beq.b $280e
  002806:  6b 20                  bmi.b $2828
  002808:  55 40                  subq.w #$2, d0
  00280a:  6a 1c                  bpl.b $2828
  00280c:  60 0e                  bra.b $281c
  00280e:  2f 3c 00 04 03 52      move.l #$40352, -(a7)
  002814:  4e ba e0 50            jsr $866(pc)
  002818:  58 8f                  addq.l #$4, a7
  00281a:  60 0c                  bra.b $2828
  00281c:  2f 3c 00 04 03 84      move.l #$40384, -(a7)
  002822:  4e ba e0 42            jsr $866(pc)
  002826:  58 8f                  addq.l #$4, a7
  002828:  2f 3c 00 07 03 c0      move.l #$703c0, -(a7)
  00282e:  4e ba e0 36            jsr $866(pc)
  002832:  42 6d a5 70            clr.w -$5a90(a5)
  002836:  42 6d a5 72            clr.w -$5a8e(a5)
  00283a:  42 2d a5 6a            clr.b -$5a96(a5)
  00283e:  2b 6e 00 0a a5 74      move.l $a(a6), -$5a8c(a5)
  002844:  20 6d a5 74            movea.l -$5a8c(a5), a0
  002848:  4e 90                  jsr (a0)
  00284a:  1b 7c 00 01 96 45      move.b #$1, -$69bb(a5)
  002850:  4e ad 00 ea            jsr $ea(a5)
  002854:  42 2d b9 7c            clr.b -$4684(a5)
  002858:  42 2d b9 6a            clr.b -$4696(a5)
  00285c:  70 00                  moveq #$0, d0
  00285e:  10 3c 00 00            move.b #$0, d0
  002862:  3b 40 ba a4            move.w d0, -$455c(a5)
  002866:  3b 40 ba 9e            move.w d0, -$4562(a5)
  00286a:  3b 7c ff ff ba 9c      move.w #$ffff, -$4564(a5)
  002870:  3b 7c ff ff a9 0e      move.w #$ffff, -$56f2(a5)
  002876:  4e ad 04 6a            jsr $46a(a5)
  00287a:  20 6d a5 74            movea.l -$5a8c(a5), a0
  00287e:  4e 90                  jsr (a0)
  002880:  4e ba f4 56            jsr $1cd8(pc)
  002884:  42 2d a5 be            clr.b -$5a42(a5)
  002888:  3b 6d 96 48 a5 78      move.w -$69b8(a5), -$5a88(a5)
  00288e:  3b 7c 00 03 96 48      move.w #$3, -$69b8(a5)
  002894:  48 6d a5 c4            pea.l -$5a3c(a5)
  002898:  a9 28                  dc.w $a928
  00289a:  4e 5e                  unlk a6
  00289c:  4e 75                  rts 
  00289e:  4e 56 ff e0            link.w a6, #$ffe0
  0028a2:  48 e7 07 00            movem.l d5-d7, -(a7)
  0028a6:  4a ad a5 54            tst.l -$5aac(a5)
  0028aa:  67 5e                  beq.b $290a
  0028ac:  4a 6d ba 8c            tst.w -$4574(a5)
  0028b0:  6f 12                  ble.b $28c4
  0028b2:  7e ff                  moveq #$ff, d7
  0028b4:  de 2d ba 8d            add.b -$4573(a5), d7
  0028b8:  3c 2d ba 80            move.w -$4580(a5), d6
  0028bc:  48 c6                  ext.l d6
  0028be:  8d fc 00 0c            divs.w #$c, d6
  0028c2:  60 04                  bra.b $28c8
  0028c4:  7c 00                  moveq #$0, d6
  0028c6:  1e 06                  move.b d6, d7
  0028c8:  7a 00                  moveq #$0, d5
  0028ca:  60 38                  bra.b $2904
  0028cc:  20 6d a5 54            movea.l -$5aac(a5), a0
  0028d0:  20 05                  move.l d5, d0
  0028d2:  48 c0                  ext.l d0
  0028d4:  eb 88                  lsl.l #$5, d0
  0028d6:  d0 90                  add.l (a0), d0
  0028d8:  22 40                  movea.l d0, a1
  0028da:  41 ee ff e0            lea.l -$20(a6), a0
  0028de:  70 07                  moveq #$7, d0
  0028e0:  20 d9                  move.l (a1)+, (a0)+
  0028e2:  51 c8 ff fc            dbra d0, $28e0
  0028e6:  4a 2e ff e0            tst.b -$20(a6)
  0028ea:  67 12                  beq.b $28fe
  0028ec:  be 2e ff f6            cmp.b -$a(a6), d7
  0028f0:  6e 0c                  bgt.b $28fe
  0028f2:  be 2e ff f6            cmp.b -$a(a6), d7
  0028f6:  66 0a                  bne.b $2902
  0028f8:  bc 2e ff f7            cmp.b -$9(a6), d6
  0028fc:  6f 04                  ble.b $2902
  0028fe:  70 01                  moveq #$1, d0
  002900:  60 0a                  bra.b $290c
  002902:  52 45                  addq.w #$1, d5
  002904:  0c 45 00 06            cmpi.w #$6, d5
  002908:  6d c2                  blt.b $28cc
  00290a:  70 00                  moveq #$0, d0
  00290c:  4c df 00 e0            movem.l (a7)+, d5-d7
  002910:  4e 5e                  unlk a6
  002912:  4e 75                  rts 
  002914:  4e 56 ff 70            link.w a6, #$ff70
  002918:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  00291c:  4a ad a5 54            tst.l -$5aac(a5)
  002920:  67 00 01 e8            beq.w $2b0a
  002924:  4a 6d ba 8c            tst.w -$4574(a5)
  002928:  6f 12                  ble.b $293c
  00292a:  7c ff                  moveq #$ff, d6
  00292c:  dc 2d ba 8d            add.b -$4573(a5), d6
  002930:  3a 2d ba 80            move.w -$4580(a5), d5
  002934:  48 c5                  ext.l d5
  002936:  8b fc 00 0c            divs.w #$c, d5
  00293a:  60 04                  bra.b $2940
  00293c:  7a 00                  moveq #$0, d5
  00293e:  1c 05                  move.b d5, d6
  002940:  78 ff                  moveq #$ff, d4
  002942:  7e 00                  moveq #$0, d7
  002944:  60 38                  bra.b $297e
  002946:  20 6d a5 54            movea.l -$5aac(a5), a0
  00294a:  20 07                  move.l d7, d0
  00294c:  48 c0                  ext.l d0
  00294e:  eb 88                  lsl.l #$5, d0
  002950:  d0 90                  add.l (a0), d0
  002952:  22 40                  movea.l d0, a1
  002954:  41 ee ff e0            lea.l -$20(a6), a0
  002958:  70 07                  moveq #$7, d0
  00295a:  20 d9                  move.l (a1)+, (a0)+
  00295c:  51 c8 ff fc            dbra d0, $295a
  002960:  4a 2e ff e0            tst.b -$20(a6)
  002964:  67 12                  beq.b $2978
  002966:  bc 2e ff f6            cmp.b -$a(a6), d6
  00296a:  6e 0c                  bgt.b $2978
  00296c:  bc 2e ff f6            cmp.b -$a(a6), d6
  002970:  66 0a                  bne.b $297c
  002972:  ba 2e ff f7            cmp.b -$9(a6), d5
  002976:  6f 04                  ble.b $297c
  002978:  38 07                  move.w d7, d4
  00297a:  60 08                  bra.b $2984
  00297c:  52 47                  addq.w #$1, d7
  00297e:  0c 47 00 06            cmpi.w #$6, d7
  002982:  6d c2                  blt.b $2946
  002984:  4a 44                  tst.w d4
  002986:  6d 00 01 82            blt.w $2b0a
  00298a:  42 a7                  clr.l -(a7)
  00298c:  3f 3c 03 ea            move.w #$3ea, -(a7)
  002990:  42 a7                  clr.l -(a7)
  002992:  48 78 ff ff            pea.l $ffff.w
  002996:  a9 7c                  dc.w $a97c
  002998:  28 5f                  movea.l (a7)+, a4
  00299a:  20 0c                  move.l a4, d0
  00299c:  67 00 01 6c            beq.w $2b0a
  0029a0:  48 6d 00 b2            pea.l $b2(a5)
  0029a4:  48 6e ff be            pea.l -$42(a6)
  0029a8:  a9 91                  dc.w $a991
  0029aa:  2f 0c                  move.l a4, -(a7)
  0029ac:  3f 3c 00 05            move.w #$5, -(a7)
  0029b0:  48 6e ff bc            pea.l -$44(a6)
  0029b4:  48 6e ff b8            pea.l -$48(a6)
  0029b8:  48 6e ff b0            pea.l -$50(a6)
  0029bc:  a9 8d                  dc.w $a98d
  0029be:  2f 2e ff b8            move.l -$48(a6), -(a7)
  0029c2:  48 6e ff 70            pea.l -$90(a6)
  0029c6:  a9 90                  dc.w $a990
  0029c8:  0c 2e 00 14 ff 70      cmpi.b #$14, -$90(a6)
  0029ce:  6f 16                  ble.b $29e6
  0029d0:  1d 7c 00 14 ff 70      move.b #$14, -$90(a6)
  0029d6:  2f 2e ff b8            move.l -$48(a6), -(a7)
  0029da:  48 6e ff 70            pea.l -$90(a6)
  0029de:  a9 8f                  dc.w $a98f
  0029e0:  3f 3c 00 01            move.w #$1, -(a7)
  0029e4:  a9 c8                  dc.w $a9c8
  0029e6:  0c 6e 00 01 ff be      cmpi.w #$1, -$42(a6)
  0029ec:  67 08                  beq.b $29f6
  0029ee:  0c 6e 00 02 ff be      cmpi.w #$2, -$42(a6)
  0029f4:  66 aa                  bne.b $29a0
  0029f6:  2f 0c                  move.l a4, -(a7)
  0029f8:  a9 83                  dc.w $a983
  0029fa:  4a 2e ff 70            tst.b -$90(a6)
  0029fe:  67 00 01 0a            beq.w $2b0a
  002a02:  0c 6e 00 02 ff be      cmpi.w #$2, -$42(a6)
  002a08:  67 00 01 00            beq.w $2b0a
  002a0c:  7e 00                  moveq #$0, d7
  002a0e:  60 06                  bra.b $2a16
  002a10:  42 36 70 c0            clr.b -$40(a6, d7.w)
  002a14:  52 47                  addq.w #$1, d7
  002a16:  0c 47 00 20            cmpi.w #$20, d7
  002a1a:  65 f4                  bcs.b $2a10
  002a1c:  7e 00                  moveq #$0, d7
  002a1e:  4a 2d 96 18            tst.b -$69e8(a5)
  002a22:  67 04                  beq.b $2a28
  002a24:  00 47 00 80            ori.w #$80, d7
  002a28:  4a 2d 96 19            tst.b -$69e7(a5)
  002a2c:  67 04                  beq.b $2a32
  002a2e:  00 47 00 40            ori.w #$40, d7
  002a32:  4a 2d 96 5c            tst.b -$69a4(a5)
  002a36:  67 04                  beq.b $2a3c
  002a38:  00 47 00 20            ori.w #$20, d7
  002a3c:  4a 2d 96 5a            tst.b -$69a6(a5)
  002a40:  67 04                  beq.b $2a46
  002a42:  00 47 00 10            ori.w #$10, d7
  002a46:  4a 2d a2 08            tst.b -$5df8(a5)
  002a4a:  67 04                  beq.b $2a50
  002a4c:  00 47 00 08            ori.w #$8, d7
  002a50:  4a 2d a2 09            tst.b -$5df7(a5)
  002a54:  67 04                  beq.b $2a5a
  002a56:  00 47 00 04            ori.w #$4, d7
  002a5a:  4a 2d a2 0a            tst.b -$5df6(a5)
  002a5e:  67 04                  beq.b $2a64
  002a60:  00 47 00 02            ori.w #$2, d7
  002a64:  41 ee ff 70            lea.l -$90(a6), a0
  002a68:  43 ee ff c0            lea.l -$40(a6), a1
  002a6c:  10 2e ff 70            move.b -$90(a6), d0
  002a70:  48 80                  ext.w d0
  002a72:  52 40                  addq.w #$1, d0
  002a74:  48 c0                  ext.l d0
  002a76:  a0 2e                  dc.w $a02e
  002a78:  1d 46 ff d6            move.b d6, -$2a(a6)
  002a7c:  1d 45 ff d7            move.b d5, -$29(a6)
  002a80:  1d 47 ff d8            move.b d7, -$28(a6)
  002a84:  1d 6d ba 49 ff d9      move.b -$45b7(a5), -$27(a6)
  002a8a:  1d 6d 96 35 ff da      move.b -$69cb(a5), -$26(a6)
  002a90:  1d 6d 96 37 ff db      move.b -$69c9(a5), -$25(a6)
  002a96:  2d 6d 96 38 ff dc      move.l -$69c8(a5), -$24(a6)
  002a9c:  3e 04                  move.w d4, d7
  002a9e:  60 46                  bra.b $2ae6
  002aa0:  20 6d a5 54            movea.l -$5aac(a5), a0
  002aa4:  20 07                  move.l d7, d0
  002aa6:  48 c0                  ext.l d0
  002aa8:  eb 88                  lsl.l #$5, d0
  002aaa:  d0 90                  add.l (a0), d0
  002aac:  22 40                  movea.l d0, a1
  002aae:  41 ee ff e0            lea.l -$20(a6), a0
  002ab2:  70 07                  moveq #$7, d0
  002ab4:  20 d9                  move.l (a1)+, (a0)+
  002ab6:  51 c8 ff fc            dbra d0, $2ab4
  002aba:  20 6d a5 54            movea.l -$5aac(a5), a0
  002abe:  20 07                  move.l d7, d0
  002ac0:  48 c0                  ext.l d0
  002ac2:  eb 88                  lsl.l #$5, d0
  002ac4:  d0 90                  add.l (a0), d0
  002ac6:  22 40                  movea.l d0, a1
  002ac8:  41 ee ff c0            lea.l -$40(a6), a0
  002acc:  70 07                  moveq #$7, d0
  002ace:  22 d8                  move.l (a0)+, (a1)+
  002ad0:  51 c8 ff fc            dbra d0, $2ace
  002ad4:  41 ee ff c0            lea.l -$40(a6), a0
  002ad8:  43 ee ff e0            lea.l -$20(a6), a1
  002adc:  70 07                  moveq #$7, d0
  002ade:  20 d9                  move.l (a1)+, (a0)+
  002ae0:  51 c8 ff fc            dbra d0, $2ade
  002ae4:  52 47                  addq.w #$1, d7
  002ae6:  0c 47 00 0a            cmpi.w #$a, d7
  002aea:  6d b4                  blt.b $2aa0
  002aec:  52 6d a5 58            addq.w #$1, -$5aa8(a5)
  002af0:  2f 2d a5 54            move.l -$5aac(a5), -(a7)
  002af4:  a9 aa                  dc.w $a9aa
  002af6:  42 67                  clr.w -(a7)
  002af8:  a9 af                  dc.w $a9af
  002afa:  3b 5f a1 6c            move.w (a7)+, -$5e94(a5)
  002afe:  4a 6d a1 6c            tst.w -$5e94(a5)
  002b02:  66 06                  bne.b $2b0a
  002b04:  2f 2d a5 54            move.l -$5aac(a5), -(a7)
  002b08:  a9 b0                  dc.w $a9b0
  002b0a:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  002b0e:  4e 5e                  unlk a6
  002b10:  4e 75                  rts 
  002b12:  4e 56 ff de            link.w a6, #$ffde
  002b16:  48 e7 07 00            movem.l d5-d7, -(a7)
  002b1a:  4a ad a5 54            tst.l -$5aac(a5)
  002b1e:  67 00 00 ca            beq.w $2bea
  002b22:  48 6d a0 b6            pea.l -$5f4a(a5)
  002b26:  a8 74                  dc.w $a874
  002b28:  48 6d a2 5e            pea.l -$5da2(a5)
  002b2c:  a8 73                  dc.w $a873
  002b2e:  3c 2d a6 00            move.w -$5a00(a5), d6
  002b32:  7e 00                  moveq #$0, d7
  002b34:  60 00 00 a6            bra.w $2bdc
  002b38:  20 6d a5 54            movea.l -$5aac(a5), a0
  002b3c:  20 07                  move.l d7, d0
  002b3e:  48 c0                  ext.l d0
  002b40:  eb 88                  lsl.l #$5, d0
  002b42:  d0 90                  add.l (a0), d0
  002b44:  22 40                  movea.l d0, a1
  002b46:  41 ee ff e0            lea.l -$20(a6), a0
  002b4a:  70 07                  moveq #$7, d0
  002b4c:  20 d9                  move.l (a1)+, (a0)+
  002b4e:  51 c8 ff fc            dbra d0, $2b4c
  002b52:  4a 2e ff e0            tst.b -$20(a6)
  002b56:  67 00 00 8c            beq.w $2be4
  002b5a:  48 6e ff e0            pea.l -$20(a6)
  002b5e:  1f 3c 00 01            move.b #$1, -(a7)
  002b62:  4e ad 01 82            jsr $182(a5)
  002b66:  3f 2d a5 fe            move.w -$5a02(a5), -(a7)
  002b6a:  3f 06                  move.w d6, -(a7)
  002b6c:  a8 93                  dc.w $a893
  002b6e:  48 6e ff e0            pea.l -$20(a6)
  002b72:  a8 84                  dc.w $a884
  002b74:  10 2e ff f6            move.b -$a(a6), d0
  002b78:  48 80                  ext.w d0
  002b7a:  3f 00                  move.w d0, -(a7)
  002b7c:  4e ad 00 7a            jsr $7a(a5)
  002b80:  1b 40 97 61            move.b d0, -$689f(a5)
  002b84:  10 2e ff f6            move.b -$a(a6), d0
  002b88:  48 80                  ext.w d0
  002b8a:  3e 80                  move.w d0, (a7)
  002b8c:  4e ad 00 8a            jsr $8a(a5)
  002b90:  1b 40 97 62            move.b d0, -$689e(a5)
  002b94:  10 2e ff f7            move.b -$9(a6), d0
  002b98:  48 80                  ext.w d0
  002b9a:  3e 80                  move.w d0, (a7)
  002b9c:  4e ad 00 82            jsr $82(a5)
  002ba0:  1b 40 97 64            move.b d0, -$689c(a5)
  002ba4:  10 2e ff f7            move.b -$9(a6), d0
  002ba8:  48 80                  ext.w d0
  002baa:  3e 80                  move.w d0, (a7)
  002bac:  4e ad 00 8a            jsr $8a(a5)
  002bb0:  1b 40 97 65            move.b d0, -$689b(a5)
  002bb4:  42 57                  clr.w (a7)
  002bb6:  48 6d 97 60            pea.l -$68a0(a5)
  002bba:  a8 8c                  dc.w $a88c
  002bbc:  3a 1f                  move.w (a7)+, d5
  002bbe:  30 2d a6 02            move.w -$59fe(a5), d0
  002bc2:  90 45                  sub.w d5, d0
  002bc4:  3f 00                  move.w d0, -(a7)
  002bc6:  3f 06                  move.w d6, -(a7)
  002bc8:  a8 93                  dc.w $a893
  002bca:  48 6d 97 60            pea.l -$68a0(a5)
  002bce:  a8 84                  dc.w $a884
  002bd0:  30 2d a6 00            move.w -$5a00(a5), d0
  002bd4:  90 6d a5 fc            sub.w -$5a04(a5), d0
  002bd8:  dc 40                  add.w d0, d6
  002bda:  52 47                  addq.w #$1, d7
  002bdc:  0c 47 00 06            cmpi.w #$6, d7
  002be0:  6d 00 ff 56            blt.w $2b38
  002be4:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  002be8:  a8 73                  dc.w $a873
  002bea:  4c df 00 e0            movem.l (a7)+, d5-d7
  002bee:  4e 5e                  unlk a6
  002bf0:  4e 75                  rts 
  002bf2:  4e 56 00 00            link.w a6, #$0
  002bf6:  48 e7 01 08            movem.l d7/a4, -(a7)
  002bfa:  28 6e 00 08            movea.l $8(a6), a4
  002bfe:  3e 2e 00 0c            move.w $c(a6), d7
  002c02:  1b 54 b9 46            move.b (a4), -$46ba(a5)
  002c06:  1b 6c 00 01 b9 47      move.b $1(a4), -$46b9(a5)
  002c0c:  1b 6c 00 02 b9 48      move.b $2(a4), -$46b8(a5)
  002c12:  1b 6c 00 03 b9 49      move.b $3(a4), -$46b7(a5)
  002c18:  1b 6c 00 04 b9 4a      move.b $4(a4), -$46b6(a5)
  002c1e:  1b 6c 00 05 b9 4b      move.b $5(a4), -$46b5(a5)
  002c24:  1b 6c 00 06 b9 4c      move.b $6(a4), -$46b4(a5)
  002c2a:  3f 07                  move.w d7, -(a7)
  002c2c:  4e ad 05 52            jsr $552(a5)
  002c30:  1b 7c 00 01 b9 51      move.b #$1, -$46af(a5)
  002c36:  42 6d ba 5a            clr.w -$45a6(a5)
  002c3a:  3b 7c 00 03 ba 20      move.w #$3, -$45e0(a5)
  002c40:  70 04                  moveq #$4, d0
  002c42:  3b 40 ba 4e            move.w d0, -$45b2(a5)
  002c46:  3b 40 ba 4c            move.w d0, -$45b4(a5)
  002c4a:  3b 40 ba 52            move.w d0, -$45ae(a5)
  002c4e:  4e ba 18 6c            jsr $44bc(pc)
  002c52:  3b 7c 00 01 ba 2c      move.w #$1, -$45d4(a5)
  002c58:  4c ee 10 80 ff f8      movem.l -$8(a6), d7/a4
  002c5e:  4e 5e                  unlk a6
  002c60:  4e 75                  rts 
  002c62:  48 e7 07 00            movem.l d5-d7, -(a7)
  002c66:  42 6d ba 36            clr.w -$45ca(a5)
  002c6a:  30 2d a9 0c            move.w -$56f4(a5), d0
  002c6e:  6b 00 00 da            bmi.w $2d4a
  002c72:  5d 40                  subq.w #$6, d0
  002c74:  67 50                  beq.b $2cc6
  002c76:  6a 08                  bpl.b $2c80
  002c78:  52 40                  addq.w #$1, d0
  002c7a:  6a 0c                  bpl.b $2c88
  002c7c:  60 00 00 cc            bra.w $2d4a
  002c80:  5d 40                  subq.w #$6, d0
  002c82:  67 7a                  beq.b $2cfe
  002c84:  60 00 00 c4            bra.w $2d4a
  002c88:  1b 6d ba 6b b9 4f      move.b -$4595(a5), -$46b1(a5)
  002c8e:  0c 6d 00 18 ba 6a      cmpi.w #$18, -$4596(a5)
  002c94:  66 00 00 b4            bne.w $2d4a
  002c98:  2f 3c 00 03 00 00      move.l #$30000, -(a7)
  002c9e:  3f 3c 00 18            move.w #$18, -(a7)
  002ca2:  4e ba 12 ce            jsr $3f72(pc)
  002ca6:  72 00                  moveq #$0, d1
  002ca8:  12 00                  move.b d0, d1
  002caa:  0c 41 00 0a            cmpi.w #$a, d1
  002cae:  5c 8f                  addq.l #$6, a7
  002cb0:  66 00 02 1c            bne.w $2ece
  002cb4:  3f 3c 00 02            move.w #$2, -(a7)
  002cb8:  48 6d a9 90            pea.l -$5670(a5)
  002cbc:  4e ba ff 34            jsr $2bf2(pc)
  002cc0:  5c 8f                  addq.l #$6, a7
  002cc2:  60 00 02 0a            bra.w $2ece
  002cc6:  1b 6d ba 6b b9 4f      move.b -$4595(a5), -$46b1(a5)
  002ccc:  0c 6d 00 01 ba 6a      cmpi.w #$1, -$4596(a5)
  002cd2:  66 76                  bne.b $2d4a
  002cd4:  0c 6d 00 4d ba 3c      cmpi.w #$4d, -$45c4(a5)
  002cda:  67 10                  beq.b $2cec
  002cdc:  3f 3c 00 19            move.w #$19, -(a7)
  002ce0:  4e ba da d2            jsr $7b4(pc)
  002ce4:  3b 7c 00 4d ba 3c      move.w #$4d, -$45c4(a5)
  002cea:  54 8f                  addq.l #$2, a7
  002cec:  3f 3c 00 02            move.w #$2, -(a7)
  002cf0:  48 6d a9 88            pea.l -$5678(a5)
  002cf4:  4e ba fe fc            jsr $2bf2(pc)
  002cf8:  5c 8f                  addq.l #$6, a7
  002cfa:  60 00 01 d2            bra.w $2ece
  002cfe:  4a 6d ba 8e            tst.w -$4572(a5)
  002d02:  66 46                  bne.b $2d4a
  002d04:  0c 6d 00 0f ba 6a      cmpi.w #$f, -$4596(a5)
  002d0a:  66 3e                  bne.b $2d4a
  002d0c:  4a 6d ba 2c            tst.w -$45d4(a5)
  002d10:  66 38                  bne.b $2d4a
  002d12:  1b 6d ba 6b b9 4f      move.b -$4595(a5), -$46b1(a5)
  002d18:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  002d1e:  3f 3c 00 0f            move.w #$f, -(a7)
  002d22:  4e ba 12 4e            jsr $3f72(pc)
  002d26:  72 00                  moveq #$0, d1
  002d28:  12 00                  move.b d0, d1
  002d2a:  0c 41 00 16            cmpi.w #$16, d1
  002d2e:  5c 8f                  addq.l #$6, a7
  002d30:  67 00 01 9c            beq.w $2ece
  002d34:  3f 3c 00 07            move.w #$7, -(a7)
  002d38:  48 6d a9 98            pea.l -$5668(a5)
  002d3c:  4e ba fe b4            jsr $2bf2(pc)
  002d40:  42 6d ba 2c            clr.w -$45d4(a5)
  002d44:  5c 8f                  addq.l #$6, a7
  002d46:  60 00 01 86            bra.w $2ece
  002d4a:  7c ff                  moveq #$ff, d6
  002d4c:  dc 6d ba 6a            add.w -$4596(a5), d6
  002d50:  20 4d                  movea.l a5, a0
  002d52:  d0 c6                  adda.w d6, a0
  002d54:  7a 00                  moveq #$0, d5
  002d56:  1a 28 f1 76            move.b -$e8a(a0), d5
  002d5a:  0c 45 00 1e            cmpi.w #$1e, d5
  002d5e:  6c 00 01 6e            bge.w $2ece
  002d62:  1b 6d ba 6b b9 4f      move.b -$4595(a5), -$46b1(a5)
  002d68:  20 05                  move.l d5, d0
  002d6a:  48 c0                  ext.l d0
  002d6c:  81 fc 00 0a            divs.w #$a, d0
  002d70:  1b 40 b9 4b            move.b d0, -$46b5(a5)
  002d74:  10 2d b9 4b            move.b -$46b5(a5), d0
  002d78:  48 80                  ext.w d0
  002d7a:  20 4d                  movea.l a5, a0
  002d7c:  d0 c0                  adda.w d0, a0
  002d7e:  d0 c0                  adda.w d0, a0
  002d80:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  002d86:  20 4d                  movea.l a5, a0
  002d88:  d0 c6                  adda.w d6, a0
  002d8a:  1b 68 f1 a6 b9 47      move.b -$e5a(a0), -$46b9(a5)
  002d90:  70 00                  moveq #$0, d0
  002d92:  10 2d b9 47            move.b -$46b9(a5), d0
  002d96:  3f 00                  move.w d0, -(a7)
  002d98:  4e ba 16 44            jsr $43de(pc)
  002d9c:  1b 40 b9 4a            move.b d0, -$46b6(a5)
  002da0:  20 4d                  movea.l a5, a0
  002da2:  d0 c6                  adda.w d6, a0
  002da4:  1b 68 f1 8e b9 49      move.b -$e72(a0), -$46b7(a5)
  002daa:  30 2d a9 0c            move.w -$56f4(a5), d0
  002dae:  20 4d                  movea.l a5, a0
  002db0:  d0 c0                  adda.w d0, a0
  002db2:  d0 c0                  adda.w d0, a0
  002db4:  4a 68 a8 dc            tst.w -$5724(a0)
  002db8:  54 8f                  addq.l #$2, a7
  002dba:  66 14                  bne.b $2dd0
  002dbc:  20 4d                  movea.l a5, a0
  002dbe:  d0 c6                  adda.w d6, a0
  002dc0:  70 00                  moveq #$0, d0
  002dc2:  10 28 f2 06            move.b -$dfa(a0), d0
  002dc6:  3b 40 ba a6            move.w d0, -$455a(a5)
  002dca:  3b 7c 00 01 ba a8      move.w #$1, -$4558(a5)
  002dd0:  0c 6d 00 03 a9 0c      cmpi.w #$3, -$56f4(a5)
  002dd6:  66 08                  bne.b $2de0
  002dd8:  1b 7c 00 04 b9 51      move.b #$4, -$46af(a5)
  002dde:  60 06                  bra.b $2de6
  002de0:  1b 7c 00 02 b9 51      move.b #$2, -$46af(a5)
  002de6:  20 4d                  movea.l a5, a0
  002de8:  d0 c6                  adda.w d6, a0
  002dea:  4a 28 f1 ee            tst.b -$e12(a0)
  002dee:  66 2a                  bne.b $2e1a
  002df0:  0c 2d 00 04 b9 51      cmpi.b #$4, -$46af(a5)
  002df6:  66 12                  bne.b $2e0a
  002df8:  1b 7c 00 02 b9 52      move.b #$2, -$46ae(a5)
  002dfe:  3f 3c 00 3f            move.w #$3f, -(a7)
  002e02:  4e ad 05 52            jsr $552(a5)
  002e06:  54 8f                  addq.l #$2, a7
  002e08:  60 26                  bra.b $2e30
  002e0a:  42 2d b9 52            clr.b -$46ae(a5)
  002e0e:  3f 3c 00 4d            move.w #$4d, -(a7)
  002e12:  4e ad 05 52            jsr $552(a5)
  002e16:  54 8f                  addq.l #$2, a7
  002e18:  60 16                  bra.b $2e30
  002e1a:  20 4d                  movea.l a5, a0
  002e1c:  d0 c6                  adda.w d6, a0
  002e1e:  70 00                  moveq #$0, d0
  002e20:  10 28 f1 be            move.b -$e42(a0), d0
  002e24:  20 4d                  movea.l a5, a0
  002e26:  e5 88                  lsl.l #$2, d0
  002e28:  d1 c0                  adda.l d0, a0
  002e2a:  2b 68 fc e4 b9 54      move.l -$31c(a0), -$46ac(a5)
  002e30:  4e ba 14 18            jsr $424a(pc)
  002e34:  20 4d                  movea.l a5, a0
  002e36:  d0 c6                  adda.w d6, a0
  002e38:  70 00                  moveq #$0, d0
  002e3a:  10 28 f1 d6            move.b -$e2a(a0), d0
  002e3e:  3b 40 ba 20            move.w d0, -$45e0(a5)
  002e42:  0c 40 00 0c            cmpi.w #$c, d0
  002e46:  6d 06                  blt.b $2e4e
  002e48:  3b 7c 00 03 ba 20      move.w #$3, -$45e0(a5)
  002e4e:  30 2d a9 0c            move.w -$56f4(a5), d0
  002e52:  20 4d                  movea.l a5, a0
  002e54:  d0 c0                  adda.w d0, a0
  002e56:  72 00                  moveq #$0, d1
  002e58:  12 28 a9 78            move.b -$5688(a0), d1
  002e5c:  34 2d ba 20            move.w -$45e0(a5), d2
  002e60:  20 4d                  movea.l a5, a0
  002e62:  d0 c2                  adda.w d2, a0
  002e64:  70 00                  moveq #$0, d0
  002e66:  10 28 a9 6c            move.b -$5694(a0), d0
  002e6a:  d2 40                  add.w d0, d1
  002e6c:  3b 41 ba 4e            move.w d1, -$45b2(a5)
  002e70:  7c 00                  moveq #$0, d6
  002e72:  1c 2d b9 46            move.b -$46ba(a5), d6
  002e76:  0c 46 00 b9            cmpi.w #$b9, d6
  002e7a:  67 0c                  beq.b $2e88
  002e7c:  0c 46 00 b1            cmpi.w #$b1, d6
  002e80:  67 06                  beq.b $2e88
  002e82:  0c 46 00 b2            cmpi.w #$b2, d6
  002e86:  66 10                  bne.b $2e98
  002e88:  1b 7c 00 01 b9 53      move.b #$1, -$46ad(a5)
  002e8e:  42 6d ba 4c            clr.w -$45b4(a5)
  002e92:  42 6d ba 52            clr.w -$45ae(a5)
  002e96:  60 1e                  bra.b $2eb6
  002e98:  1b 7c 00 ff b9 53      move.b #$ff, -$46ad(a5)
  002e9e:  30 2d ba 4e            move.w -$45b2(a5), d0
  002ea2:  3b 40 ba 4c            move.w d0, -$45b4(a5)
  002ea6:  3b 40 ba 52            move.w d0, -$45ae(a5)
  002eaa:  42 6d ba 2a            clr.w -$45d6(a5)
  002eae:  42 6d ba 8a            clr.w -$4576(a5)
  002eb2:  42 6d ba 56            clr.w -$45aa(a5)
  002eb6:  42 2d b9 4e            clr.b -$46b2(a5)
  002eba:  42 2d b9 4d            clr.b -$46b3(a5)
  002ebe:  1b 7c 00 01 b9 4c      move.b #$1, -$46b4(a5)
  002ec4:  4e ba 15 f6            jsr $44bc(pc)
  002ec8:  3b 7c 00 01 ba 2c      move.w #$1, -$45d4(a5)
  002ece:  4c df 00 e0            movem.l (a7)+, d5-d7
  002ed2:  4e 75                  rts 
  002ed4:  2f 07                  move.l d7, -(a7)
  002ed6:  7e 00                  moveq #$0, d7
  002ed8:  1e 2d b9 7e            move.b -$4682(a5), d7
  002edc:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  002ee2:  67 00 00 90            beq.w $2f74
  002ee6:  0c 47 00 d3            cmpi.w #$d3, d7
  002eea:  6d 00 00 88            blt.w $2f74
  002eee:  0c 2d 00 01 b9 87      cmpi.b #$1, -$4679(a5)
  002ef4:  66 16                  bne.b $2f0c
  002ef6:  0c 2d 00 04 b9 82      cmpi.b #$4, -$467e(a5)
  002efc:  66 76                  bne.b $2f74
  002efe:  4e ba 15 a8            jsr $44a8(pc)
  002f02:  4e ba 27 a2            jsr $56a6(pc)
  002f06:  4e ba 15 b4            jsr $44bc(pc)
  002f0a:  60 68                  bra.b $2f74
  002f0c:  0c 2d 00 04 b9 87      cmpi.b #$4, -$4679(a5)
  002f12:  66 38                  bne.b $2f4c
  002f14:  10 2d b9 85            move.b -$467b(a5), d0
  002f18:  48 80                  ext.w d0
  002f1a:  20 4d                  movea.l a5, a0
  002f1c:  48 c0                  ext.l d0
  002f1e:  e5 88                  lsl.l #$2, d0
  002f20:  d1 c0                  adda.l d0, a0
  002f22:  1b 68 f0 bd b9 85      move.b -$f43(a0), -$467b(a5)
  002f28:  0c 2d 00 03 b9 85      cmpi.b #$3, -$467b(a5)
  002f2e:  66 1c                  bne.b $2f4c
  002f30:  1b 7c 00 85 b9 7d      move.b #$85, -$4683(a5)
  002f36:  1b 7c 00 01 b9 81      move.b #$1, -$467f(a5)
  002f3c:  42 2d b9 7f            clr.b -$4681(a5)
  002f40:  1b 7c 00 ff b9 89      move.b #$ff, -$4677(a5)
  002f46:  4e ba 00 30            jsr $2f78(pc)
  002f4a:  60 28                  bra.b $2f74
  002f4c:  4e ba 26 fa            jsr $5648(pc)
  002f50:  30 2d ba 6a            move.w -$4596(a5), d0
  002f54:  20 4d                  movea.l a5, a0
  002f56:  d0 c0                  adda.w d0, a0
  002f58:  11 7c 00 1e f1 75      move.b #$1e, -$e8b(a0)
  002f5e:  1b 7c 00 56 b9 7f      move.b #$56, -$4681(a5)
  002f64:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  002f68:  42 67                  clr.w -(a7)
  002f6a:  4e ba d6 ac            jsr $618(pc)
  002f6e:  42 6d ba 4c            clr.w -$45b4(a5)
  002f72:  58 8f                  addq.l #$4, a7
  002f74:  2e 1f                  move.l (a7)+, d7
  002f76:  4e 75                  rts 
  002f78:  48 e7 03 00            movem.l d6-d7, -(a7)
  002f7c:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  002f82:  67 00 00 ca            beq.w $304e
  002f86:  0c 2d 00 01 b9 87      cmpi.b #$1, -$4679(a5)
  002f8c:  67 00 00 c0            beq.w $304e
  002f90:  0c 2d 00 18 b9 87      cmpi.b #$18, -$4679(a5)
  002f96:  67 00 00 b6            beq.w $304e
  002f9a:  1e 2d b9 85            move.b -$467b(a5), d7
  002f9e:  48 87                  ext.w d7
  002fa0:  53 47                  subq.w #$1, d7
  002fa2:  10 2d b9 81            move.b -$467f(a5), d0
  002fa6:  48 80                  ext.w d0
  002fa8:  3f 00                  move.w d0, -(a7)
  002faa:  42 67                  clr.w -(a7)
  002fac:  4e ba 10 9a            jsr $4048(pc)
  002fb0:  20 4d                  movea.l a5, a0
  002fb2:  d0 c7                  adda.w d7, a0
  002fb4:  11 40 f1 76            move.b d0, -$e8a(a0)
  002fb8:  20 4d                  movea.l a5, a0
  002fba:  d0 c7                  adda.w d7, a0
  002fbc:  11 6d ba a7 f2 06      move.b -$4559(a5), -$dfa(a0)
  002fc2:  20 4d                  movea.l a5, a0
  002fc4:  d0 c7                  adda.w d7, a0
  002fc6:  11 6d b9 7d f1 a6      move.b -$4683(a5), -$e5a(a0)
  002fcc:  20 4d                  movea.l a5, a0
  002fce:  d0 c7                  adda.w d7, a0
  002fd0:  11 6d b9 7f f1 8e      move.b -$4681(a5), -$e72(a0)
  002fd6:  20 4d                  movea.l a5, a0
  002fd8:  d0 c7                  adda.w d7, a0
  002fda:  11 6d ba 21 f1 d6      move.b -$45df(a5), -$e2a(a0)
  002fe0:  7c 00                  moveq #$0, d6
  002fe2:  1c 2d b9 7c            move.b -$4684(a5), d6
  002fe6:  4a 2d b9 89            tst.b -$4677(a5)
  002fea:  58 8f                  addq.l #$4, a7
  002fec:  6c 12                  bge.b $3000
  002fee:  20 4d                  movea.l a5, a0
  002ff0:  d0 c7                  adda.w d7, a0
  002ff2:  42 28 f1 ee            clr.b -$e12(a0)
  002ff6:  20 4d                  movea.l a5, a0
  002ff8:  d0 c7                  adda.w d7, a0
  002ffa:  42 28 f1 be            clr.b -$e42(a0)
  002ffe:  60 38                  bra.b $3038
  003000:  20 4d                  movea.l a5, a0
  003002:  d0 c7                  adda.w d7, a0
  003004:  11 7c 00 01 f1 ee      move.b #$1, -$e12(a0)
  00300a:  0c 46 00 b1            cmpi.w #$b1, d6
  00300e:  66 0c                  bne.b $301c
  003010:  20 4d                  movea.l a5, a0
  003012:  d0 c7                  adda.w d7, a0
  003014:  11 7c 00 84 f1 be      move.b #$84, -$e42(a0)
  00301a:  60 1c                  bra.b $3038
  00301c:  0c 46 00 b2            cmpi.w #$b2, d6
  003020:  66 0c                  bne.b $302e
  003022:  20 4d                  movea.l a5, a0
  003024:  d0 c7                  adda.w d7, a0
  003026:  11 7c 00 86 f1 be      move.b #$86, -$e42(a0)
  00302c:  60 0a                  bra.b $3038
  00302e:  20 4d                  movea.l a5, a0
  003030:  d0 c7                  adda.w d7, a0
  003032:  11 7c 00 82 f1 be      move.b #$82, -$e42(a0)
  003038:  1b 7c 00 56 b9 7f      move.b #$56, -$4681(a5)
  00303e:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  003042:  42 67                  clr.w -(a7)
  003044:  4e ba d5 d2            jsr $618(pc)
  003048:  42 6d ba 4c            clr.w -$45b4(a5)
  00304c:  58 8f                  addq.l #$4, a7
  00304e:  4c df 00 c0            movem.l (a7)+, d6-d7
  003052:  4e 75                  rts 
  003054:  10 2d b9 73            move.b -$468d(a5), d0
  003058:  48 80                  ext.w d0
  00305a:  20 4d                  movea.l a5, a0
  00305c:  d0 c0                  adda.w d0, a0
  00305e:  11 7c 00 1e f1 75      move.b #$1e, -$e8b(a0)
  003064:  10 2d b9 85            move.b -$467b(a5), d0
  003068:  48 80                  ext.w d0
  00306a:  20 4d                  movea.l a5, a0
  00306c:  d0 c0                  adda.w d0, a0
  00306e:  11 7c 00 1e f1 75      move.b #$1e, -$e8b(a0)
  003074:  4e ba 14 32            jsr $44a8(pc)
  003078:  3f 2d ba 44            move.w -$45bc(a5), -(a7)
  00307c:  4e ba 00 f4            jsr $3172(pc)
  003080:  4e ba 14 3a            jsr $44bc(pc)
  003084:  54 8f                  addq.l #$2, a7
  003086:  4e 75                  rts 
  003088:  48 e7 03 00            movem.l d6-d7, -(a7)
  00308c:  4a 6d ba 84            tst.w -$457c(a5)
  003090:  67 08                  beq.b $309a
  003092:  53 6d ba 84            subq.w #$1, -$457c(a5)
  003096:  60 00 00 d4            bra.w $316c
  00309a:  4e ba 13 e4            jsr $4480(pc)
  00309e:  4e ad 05 22            jsr $522(a5)
  0030a2:  4e ba 16 de            jsr $4782(pc)
  0030a6:  4e ba 01 64            jsr $320c(pc)
  0030aa:  3b 40 ba 44            move.w d0, -$45bc(a5)
  0030ae:  4a 40                  tst.w d0
  0030b0:  6d 00 00 ba            blt.w $316c
  0030b4:  4e ba 13 de            jsr $4494(pc)
  0030b8:  0c 6d 00 63 ba 44      cmpi.w #$63, -$45bc(a5)
  0030be:  66 0a                  bne.b $30ca
  0030c0:  3b 7c ff ff ba 44      move.w #$ffff, -$45bc(a5)
  0030c6:  60 00 00 a4            bra.w $316c
  0030ca:  10 2d b9 4f            move.b -$46b1(a5), d0
  0030ce:  48 80                  ext.w d0
  0030d0:  3b 40 ba 7c            move.w d0, -$4584(a5)
  0030d4:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  0030da:  67 00 00 90            beq.w $316c
  0030de:  7e 00                  moveq #$0, d7
  0030e0:  4a 2d b9 89            tst.b -$4677(a5)
  0030e4:  6c 08                  bge.b $30ee
  0030e6:  0c 2d 00 02 b9 88      cmpi.b #$2, -$4678(a5)
  0030ec:  67 04                  beq.b $30f2
  0030ee:  7e 01                  moveq #$1, d7
  0030f0:  60 6c                  bra.b $315e
  0030f2:  1c 2d b9 73            move.b -$468d(a5), d6
  0030f6:  48 86                  ext.w d6
  0030f8:  53 46                  subq.w #$1, d6
  0030fa:  20 4d                  movea.l a5, a0
  0030fc:  d0 c6                  adda.w d6, a0
  0030fe:  0c 28 00 1e f1 76      cmpi.b #$1e, -$e8a(a0)
  003104:  64 0e                  bcc.b $3114
  003106:  20 4d                  movea.l a5, a0
  003108:  d0 c6                  adda.w d6, a0
  00310a:  4a 28 f1 ee            tst.b -$e12(a0)
  00310e:  66 04                  bne.b $3114
  003110:  7e 01                  moveq #$1, d7
  003112:  60 4a                  bra.b $315e
  003114:  4a 6d ba 44            tst.w -$45bc(a5)
  003118:  66 0c                  bne.b $3126
  00311a:  0c 2d 00 5b b9 7d      cmpi.b #$5b, -$4683(a5)
  003120:  65 3c                  bcs.b $315e
  003122:  7e 01                  moveq #$1, d7
  003124:  60 38                  bra.b $315e
  003126:  0c 6d 00 01 ba 44      cmpi.w #$1, -$45bc(a5)
  00312c:  66 0c                  bne.b $313a
  00312e:  0c 2d 00 a5 b9 7d      cmpi.b #$a5, -$4683(a5)
  003134:  64 28                  bcc.b $315e
  003136:  7e 01                  moveq #$1, d7
  003138:  60 24                  bra.b $315e
  00313a:  0c 6d 00 02 ba 44      cmpi.w #$2, -$45bc(a5)
  003140:  66 0a                  bne.b $314c
  003142:  4a 2d b9 81            tst.b -$467f(a5)
  003146:  6d 16                  blt.b $315e
  003148:  7e 01                  moveq #$1, d7
  00314a:  60 12                  bra.b $315e
  00314c:  0c 6d 00 03 ba 44      cmpi.w #$3, -$45bc(a5)
  003152:  66 0a                  bne.b $315e
  003154:  0c 2d 00 03 b9 81      cmpi.b #$3, -$467f(a5)
  00315a:  6c 02                  bge.b $315e
  00315c:  7e 01                  moveq #$1, d7
  00315e:  4a 47                  tst.w d7
  003160:  67 06                  beq.b $3168
  003162:  4e ba fe 14            jsr $2f78(pc)
  003166:  60 04                  bra.b $316c
  003168:  4e ba fe ea            jsr $3054(pc)
  00316c:  4c df 00 c0            movem.l (a7)+, d6-d7
  003170:  4e 75                  rts 
  003172:  4e 56 00 00            link.w a6, #$0
  003176:  48 e7 03 00            movem.l d6-d7, -(a7)
  00317a:  3c 2e 00 08            move.w $8(a6), d6
  00317e:  4a 2d b9 4f            tst.b -$46b1(a5)
  003182:  66 04                  bne.b $3188
  003184:  70 ff                  moveq #$ff, d0
  003186:  60 7a                  bra.b $3202
  003188:  10 2d b9 4f            move.b -$46b1(a5), d0
  00318c:  48 80                  ext.w d0
  00318e:  48 c0                  ext.l d0
  003190:  e5 88                  lsl.l #$2, d0
  003192:  41 ed f0 ba            lea.l -$f46(a5), a0
  003196:  d0 88                  add.l a0, d0
  003198:  30 46                  movea.w d6, a0
  00319a:  1b 70 08 00 b9 4f      move.b (a0, d0.l), -$46b1(a5)
  0031a0:  4a 2d b9 4f            tst.b -$46b1(a5)
  0031a4:  66 04                  bne.b $31aa
  0031a6:  70 ff                  moveq #$ff, d0
  0031a8:  60 58                  bra.b $3202
  0031aa:  4a 46                  tst.w d6
  0031ac:  66 0a                  bne.b $31b8
  0031ae:  06 2d 00 8c b9 47      addi.b #$8c, -$46b9(a5)
  0031b4:  7c 01                  moveq #$1, d6
  0031b6:  60 28                  bra.b $31e0
  0031b8:  0c 46 00 01            cmpi.w #$1, d6
  0031bc:  66 0a                  bne.b $31c8
  0031be:  04 2d 00 8c b9 47      subi.b #$8c, -$46b9(a5)
  0031c4:  7c 00                  moveq #$0, d6
  0031c6:  60 18                  bra.b $31e0
  0031c8:  0c 46 00 02            cmpi.w #$2, d6
  0031cc:  66 0a                  bne.b $31d8
  0031ce:  06 2d 00 bd b9 48      addi.b #$bd, -$46b8(a5)
  0031d4:  7c 03                  moveq #$3, d6
  0031d6:  60 08                  bra.b $31e0
  0031d8:  04 2d 00 bd b9 48      subi.b #$bd, -$46b8(a5)
  0031de:  7c 02                  moveq #$2, d6
  0031e0:  70 00                  moveq #$0, d0
  0031e2:  10 2d b9 47            move.b -$46b9(a5), d0
  0031e6:  3f 00                  move.w d0, -(a7)
  0031e8:  4e ba 11 f4            jsr $43de(pc)
  0031ec:  1b 40 b9 4a            move.b d0, -$46b6(a5)
  0031f0:  70 00                  moveq #$0, d0
  0031f2:  10 2d b9 48            move.b -$46b8(a5), d0
  0031f6:  3e 80                  move.w d0, (a7)
  0031f8:  4e ba 12 68            jsr $4462(pc)
  0031fc:  1b 40 b9 4b            move.b d0, -$46b5(a5)
  003200:  30 06                  move.w d6, d0
  003202:  4c ee 00 c0 ff f8      movem.l -$8(a6), d6-d7
  003208:  4e 5e                  unlk a6
  00320a:  4e 75                  rts 
  00320c:  48 e7 1f 00            movem.l d3-d7, -(a7)
  003210:  7c 00                  moveq #$0, d6
  003212:  1c 2d b9 48            move.b -$46b8(a5), d6
  003216:  3e 06                  move.w d6, d7
  003218:  0c 47 00 c0            cmpi.w #$c0, d7
  00321c:  6d 04                  blt.b $3222
  00321e:  06 47 ff 00            addi.w #$ff00, d7
  003222:  1a 2d b9 4c            move.b -$46b4(a5), d5
  003226:  48 85                  ext.w d5
  003228:  78 00                  moveq #$0, d4
  00322a:  18 2d b9 46            move.b -$46ba(a5), d4
  00322e:  0c 45 00 05            cmpi.w #$5, d5
  003232:  67 1e                  beq.b $3252
  003234:  0c 45 00 04            cmpi.w #$4, d5
  003238:  67 18                  beq.b $3252
  00323a:  0c 45 00 03            cmpi.w #$3, d5
  00323e:  67 12                  beq.b $3252
  003240:  0c 47 00 0a            cmpi.w #$a, d7
  003244:  6c 0c                  bge.b $3252
  003246:  0c 47 ff f0            cmpi.w #$fff0, d7
  00324a:  6d 06                  blt.b $3252
  00324c:  76 02                  moveq #$2, d3
  00324e:  60 00 00 b4            bra.w $3304
  003252:  0c 46 00 d3            cmpi.w #$d3, d6
  003256:  6d 06                  blt.b $325e
  003258:  76 03                  moveq #$3, d3
  00325a:  60 00 00 a8            bra.w $3304
  00325e:  0c 44 00 87            cmpi.w #$87, d4
  003262:  6d 06                  blt.b $326a
  003264:  0c 44 00 96            cmpi.w #$96, d4
  003268:  6d 2a                  blt.b $3294
  00326a:  0c 44 00 6e            cmpi.w #$6e, d4
  00326e:  6d 06                  blt.b $3276
  003270:  0c 44 00 78            cmpi.w #$78, d4
  003274:  6d 1e                  blt.b $3294
  003276:  0c 44 00 96            cmpi.w #$96, d4
  00327a:  6d 06                  blt.b $3282
  00327c:  0c 44 00 a3            cmpi.w #$a3, d4
  003280:  6d 12                  blt.b $3294
  003282:  0c 44 00 a6            cmpi.w #$a6, d4
  003286:  6d 06                  blt.b $328e
  003288:  0c 44 00 a9            cmpi.w #$a9, d4
  00328c:  6d 06                  blt.b $3294
  00328e:  0c 45 00 07            cmpi.w #$7, d5
  003292:  66 06                  bne.b $329a
  003294:  70 ff                  moveq #$ff, d0
  003296:  60 00 00 bc            bra.w $3354
  00329a:  4a 2d b9 49            tst.b -$46b7(a5)
  00329e:  67 1e                  beq.b $32be
  0032a0:  0c 6d 00 36 ba dc      cmpi.w #$36, -$4524(a5)
  0032a6:  6e 04                  bgt.b $32ac
  0032a8:  76 00                  moveq #$0, d3
  0032aa:  60 58                  bra.b $3304
  0032ac:  0c 6d 00 c6 ba dc      cmpi.w #$c6, -$4524(a5)
  0032b2:  6d 04                  blt.b $32b8
  0032b4:  76 01                  moveq #$1, d3
  0032b6:  60 4c                  bra.b $3304
  0032b8:  70 ff                  moveq #$ff, d0
  0032ba:  60 00 00 98            bra.w $3354
  0032be:  10 2d b9 4b            move.b -$46b5(a5), d0
  0032c2:  48 80                  ext.w d0
  0032c4:  3f 00                  move.w d0, -(a7)
  0032c6:  3f 3c 00 09            move.w #$9, -(a7)
  0032ca:  10 2d b9 4f            move.b -$46b1(a5), d0
  0032ce:  48 80                  ext.w d0
  0032d0:  3f 00                  move.w d0, -(a7)
  0032d2:  4e ba 0c 9e            jsr $3f72(pc)
  0032d6:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  0032dc:  5c 8f                  addq.l #$6, a7
  0032de:  67 14                  beq.b $32f4
  0032e0:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  0032e6:  67 0c                  beq.b $32f4
  0032e8:  0c 6d 00 c9 ba de      cmpi.w #$c9, -$4522(a5)
  0032ee:  6d 04                  blt.b $32f4
  0032f0:  76 01                  moveq #$1, d3
  0032f2:  60 10                  bra.b $3304
  0032f4:  0c 6d 00 39 ba de      cmpi.w #$39, -$4522(a5)
  0032fa:  6e 04                  bgt.b $3300
  0032fc:  76 00                  moveq #$0, d3
  0032fe:  60 04                  bra.b $3304
  003300:  70 ff                  moveq #$ff, d0
  003302:  60 50                  bra.b $3354
  003304:  30 03                  move.w d3, d0
  003306:  67 0e                  beq.b $3316
  003308:  6b 38                  bmi.b $3342
  00330a:  57 40                  subq.w #$3, d0
  00330c:  67 20                  beq.b $332e
  00330e:  6a 32                  bpl.b $3342
  003310:  52 40                  addq.w #$1, d0
  003312:  6a 2e                  bpl.b $3342
  003314:  60 0e                  bra.b $3324
  003316:  4e ba 00 d6            jsr $33ee(pc)
  00331a:  4e ba 00 5a            jsr $3376(pc)
  00331e:  4e ba 00 3a            jsr $335a(pc)
  003322:  60 1e                  bra.b $3342
  003324:  4e ba 00 6e            jsr $3394(pc)
  003328:  4e ba 00 9c            jsr $33c6(pc)
  00332c:  60 14                  bra.b $3342
  00332e:  0c 6d 00 06 a9 0c      cmpi.w #$6, -$56f4(a5)
  003334:  66 0c                  bne.b $3342
  003336:  0c 2d 00 01 b9 4f      cmpi.b #$1, -$46b1(a5)
  00333c:  66 04                  bne.b $3342
  00333e:  70 fe                  moveq #$fe, d0
  003340:  60 12                  bra.b $3354
  003342:  3f 03                  move.w d3, -(a7)
  003344:  4e ba fe 2c            jsr $3172(pc)
  003348:  4a 40                  tst.w d0
  00334a:  54 8f                  addq.l #$2, a7
  00334c:  6c 04                  bge.b $3352
  00334e:  70 63                  moveq #$63, d0
  003350:  60 02                  bra.b $3354
  003352:  30 03                  move.w d3, d0
  003354:  4c df 00 f8            movem.l (a7)+, d3-d7
  003358:  4e 75                  rts 
  00335a:  0c 6d 00 02 ba 3c      cmpi.w #$2, -$45c4(a5)
  003360:  66 12                  bne.b $3374
  003362:  42 a7                  clr.l -(a7)
  003364:  3f 3c 00 18            move.w #$18, -(a7)
  003368:  4e ba 0c 08            jsr $3f72(pc)
  00336c:  42 97                  clr.l (a7)
  00336e:  4e ad 04 72            jsr $472(a5)
  003372:  5c 8f                  addq.l #$6, a7
  003374:  4e 75                  rts 
  003376:  0c 6d 00 03 a9 0c      cmpi.w #$3, -$56f4(a5)
  00337c:  66 14                  bne.b $3392
  00337e:  0c 2d 00 07 b9 4f      cmpi.b #$7, -$46b1(a5)
  003384:  66 0c                  bne.b $3392
  003386:  3b 7c 00 01 ba 40      move.w #$1, -$45c0(a5)
  00338c:  3b 6d ba 48 ba 46      move.w -$45b8(a5), -$45ba(a5)
  003392:  4e 75                  rts 
  003394:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  00339a:  66 28                  bne.b $33c4
  00339c:  0c 2d 00 12 b9 4f      cmpi.b #$12, -$46b1(a5)
  0033a2:  66 20                  bne.b $33c4
  0033a4:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  0033aa:  3f 3c 00 0f            move.w #$f, -(a7)
  0033ae:  4e ba 0b c2            jsr $3f72(pc)
  0033b2:  70 00                  moveq #$0, d0
  0033b4:  10 2d ba e9            move.b -$4517(a5), d0
  0033b8:  d0 ad bd 82            add.l -$427e(a5), d0
  0033bc:  20 40                  movea.l d0, a0
  0033be:  10 bc 00 01            move.b #$1, (a0)
  0033c2:  5c 8f                  addq.l #$6, a7
  0033c4:  4e 75                  rts 
  0033c6:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  0033cc:  66 1e                  bne.b $33ec
  0033ce:  4a 6d ba 3c            tst.w -$45c4(a5)
  0033d2:  66 18                  bne.b $33ec
  0033d4:  0c 2d 00 03 b9 4f      cmpi.b #$3, -$46b1(a5)
  0033da:  66 10                  bne.b $33ec
  0033dc:  3f 3c 00 1d            move.w #$1d, -(a7)
  0033e0:  4e ba d3 d2            jsr $7b4(pc)
  0033e4:  3b 7c 00 1c ba 92      move.w #$1c, -$456e(a5)
  0033ea:  54 8f                  addq.l #$2, a7
  0033ec:  4e 75                  rts 
  0033ee:  4a 6d ba 3c            tst.w -$45c4(a5)
  0033f2:  67 2e                  beq.b $3422
  0033f4:  0c 6d 00 4d ba 3c      cmpi.w #$4d, -$45c4(a5)
  0033fa:  67 26                  beq.b $3422
  0033fc:  0c 6d 00 04 a9 0c      cmpi.w #$4, -$56f4(a5)
  003402:  66 1e                  bne.b $3422
  003404:  4a 2d b9 4b            tst.b -$46b5(a5)
  003408:  66 18                  bne.b $3422
  00340a:  0c 2d 00 0b b9 4f      cmpi.b #$b, -$46b1(a5)
  003410:  66 10                  bne.b $3422
  003412:  3f 3c 00 19            move.w #$19, -(a7)
  003416:  4e ba d3 9c            jsr $7b4(pc)
  00341a:  3b 7c 00 4d ba 3c      move.w #$4d, -$45c4(a5)
  003420:  54 8f                  addq.l #$2, a7
  003422:  4e 75                  rts 
  003424:  42 2d ba bb            clr.b -$4545(a5)
  003428:  42 2d ba ba            clr.b -$4546(a5)
  00342c:  42 2d ba b9            clr.b -$4547(a5)
  003430:  42 2d ba ae            clr.b -$4552(a5)
  003434:  42 2d ba ad            clr.b -$4553(a5)
  003438:  42 2d ba ac            clr.b -$4554(a5)
  00343c:  42 2d ba ab            clr.b -$4555(a5)
  003440:  42 2d ba aa            clr.b -$4556(a5)
  003444:  4e 75                  rts 
  003446:  70 ff                  moveq #$ff, d0
  003448:  1b 40 ba b9            move.b d0, -$4547(a5)
  00344c:  1b 40 ba aa            move.b d0, -$4556(a5)
  003450:  4e 75                  rts 
  003452:  1b 7c 00 ff ba ab      move.b #$ff, -$4555(a5)
  003458:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  00345e:  4e 75                  rts 
  003460:  70 ff                  moveq #$ff, d0
  003462:  1b 40 ba ba            move.b d0, -$4546(a5)
  003466:  1b 40 ba ac            move.b d0, -$4554(a5)
  00346a:  4e 75                  rts 
  00346c:  1b 7c 00 ff ba ad      move.b #$ff, -$4553(a5)
  003472:  1b 7c 00 01 ba ba      move.b #$1, -$4546(a5)
  003478:  4e 75                  rts 
  00347a:  70 ff                  moveq #$ff, d0
  00347c:  1b 40 ba ab            move.b d0, -$4555(a5)
  003480:  1b 40 ba ac            move.b d0, -$4554(a5)
  003484:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  00348a:  4e 75                  rts 
  00348c:  70 ff                  moveq #$ff, d0
  00348e:  1b 40 ba ab            move.b d0, -$4555(a5)
  003492:  1b 40 ba ad            move.b d0, -$4553(a5)
  003496:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  00349c:  4e 75                  rts 
  00349e:  70 ff                  moveq #$ff, d0
  0034a0:  1b 40 ba b9            move.b d0, -$4547(a5)
  0034a4:  1b 40 ba aa            move.b d0, -$4556(a5)
  0034a8:  1b 40 ba ad            move.b d0, -$4553(a5)
  0034ac:  4e 75                  rts 
  0034ae:  1b 7c 00 ff ba ad      move.b #$ff, -$4553(a5)
  0034b4:  1b 7c 00 01 ba ba      move.b #$1, -$4546(a5)
  0034ba:  4e 75                  rts 
  0034bc:  70 ff                  moveq #$ff, d0
  0034be:  1b 40 ba ab            move.b d0, -$4555(a5)
  0034c2:  1b 40 ba ad            move.b d0, -$4553(a5)
  0034c6:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  0034cc:  4e 75                  rts 
  0034ce:  1b 7c 00 ff ba ab      move.b #$ff, -$4555(a5)
  0034d4:  1b 7c 00 01 ba b9      move.b #$1, -$4547(a5)
  0034da:  4e 75                  rts 
  0034dc:  70 ff                  moveq #$ff, d0
  0034de:  1b 40 ba b9            move.b d0, -$4547(a5)
  0034e2:  1b 40 ba aa            move.b d0, -$4556(a5)
  0034e6:  4e 75                  rts 
  0034e8:  70 ff                  moveq #$ff, d0
  0034ea:  1b 40 ba bb            move.b d0, -$4545(a5)
  0034ee:  1b 40 ba ae            move.b d0, -$4552(a5)
  0034f2:  4e 75                  rts 
  0034f4:  70 ff                  moveq #$ff, d0
  0034f6:  1b 40 ba ba            move.b d0, -$4546(a5)
  0034fa:  1b 40 ba ac            move.b d0, -$4554(a5)
  0034fe:  4e 75                  rts 
  003500:  70 ff                  moveq #$ff, d0
  003502:  1b 40 ba bb            move.b d0, -$4545(a5)
  003506:  1b 40 ba ae            move.b d0, -$4552(a5)
  00350a:  4e 75                  rts 
  00350c:  42 2d ba bb            clr.b -$4545(a5)
  003510:  4e 75                  rts 
  003512:  2f 07                  move.l d7, -(a7)
  003514:  4e ba ff 0e            jsr $3424(pc)
  003518:  1e 2d b9 51            move.b -$46af(a5), d7
  00351c:  48 87                  ext.w d7
  00351e:  4a 47                  tst.w d7
  003520:  66 06                  bne.b $3528
  003522:  4e ba 00 d4            jsr $35f8(pc)
  003526:  60 54                  bra.b $357c
  003528:  4a 6d ba 2a            tst.w -$45d6(a5)
  00352c:  67 04                  beq.b $3532
  00352e:  53 6d ba 2a            subq.w #$1, -$45d6(a5)
  003532:  4a 6d ba 88            tst.w -$4578(a5)
  003536:  67 04                  beq.b $353c
  003538:  53 6d ba 88            subq.w #$1, -$4578(a5)
  00353c:  4a 6d ba 8a            tst.w -$4576(a5)
  003540:  67 04                  beq.b $3546
  003542:  53 6d ba 8a            subq.w #$1, -$4576(a5)
  003546:  0c 47 00 18            cmpi.w #$18, d7
  00354a:  66 06                  bne.b $3552
  00354c:  4e ba 00 32            jsr $3580(pc)
  003550:  60 2a                  bra.b $357c
  003552:  0c 47 00 04            cmpi.w #$4, d7
  003556:  66 06                  bne.b $355e
  003558:  4e ba 00 8c            jsr $35e6(pc)
  00355c:  60 1e                  bra.b $357c
  00355e:  0c 47 00 01            cmpi.w #$1, d7
  003562:  66 06                  bne.b $356a
  003564:  4e ba 00 4e            jsr $35b4(pc)
  003568:  60 12                  bra.b $357c
  00356a:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  003570:  66 06                  bne.b $3578
  003572:  4e ba 00 7e            jsr $35f2(pc)
  003576:  60 04                  bra.b $357c
  003578:  4e ba 00 84            jsr $35fe(pc)
  00357c:  2e 1f                  move.l (a7)+, d7
  00357e:  4e 75                  rts 
  003580:  0c 2d 00 56 b9 49      cmpi.b #$56, -$46b7(a5)
  003586:  67 2a                  beq.b $35b2
  003588:  4a 2d b9 4c            tst.b -$46b4(a5)
  00358c:  66 0e                  bne.b $359c
  00358e:  0c 2d 00 c8 b9 47      cmpi.b #$c8, -$46b9(a5)
  003594:  65 1c                  bcs.b $35b2
  003596:  4e ba 21 0e            jsr $56a6(pc)
  00359a:  60 16                  bra.b $35b2
  00359c:  0c 2d 00 a6 b9 47      cmpi.b #$a6, -$46b9(a5)
  0035a2:  64 0e                  bcc.b $35b2
  0035a4:  3f 3c 00 6b            move.w #$6b, -(a7)
  0035a8:  4e ad 05 52            jsr $552(a5)
  0035ac:  4e ba 0c 9c            jsr $424a(pc)
  0035b0:  54 8f                  addq.l #$2, a7
  0035b2:  4e 75                  rts 
  0035b4:  30 2d a9 0c            move.w -$56f4(a5), d0
  0035b8:  6b 2a                  bmi.b $35e4
  0035ba:  5d 40                  subq.w #$6, d0
  0035bc:  67 1c                  beq.b $35da
  0035be:  6a 08                  bpl.b $35c8
  0035c0:  54 40                  addq.w #$2, d0
  0035c2:  67 0a                  beq.b $35ce
  0035c4:  6a 0e                  bpl.b $35d4
  0035c6:  60 1c                  bra.b $35e4
  0035c8:  5d 40                  subq.w #$6, d0
  0035ca:  67 14                  beq.b $35e0
  0035cc:  60 16                  bra.b $35e4
  0035ce:  4e ba 08 2e            jsr $3dfe(pc)
  0035d2:  60 10                  bra.b $35e4
  0035d4:  4e ba 08 44            jsr $3e1a(pc)
  0035d8:  60 0a                  bra.b $35e4
  0035da:  4e ba 08 8a            jsr $3e66(pc)
  0035de:  60 04                  bra.b $35e4
  0035e0:  4e ba 08 a6            jsr $3e88(pc)
  0035e4:  4e 75                  rts 
  0035e6:  1b 7c 00 02 b9 52      move.b #$2, -$46ae(a5)
  0035ec:  4e ba 00 10            jsr $35fe(pc)
  0035f0:  4e 75                  rts 
  0035f2:  4e ba 00 0a            jsr $35fe(pc)
  0035f6:  4e 75                  rts 
  0035f8:  4e ba 00 04            jsr $35fe(pc)
  0035fc:  4e 75                  rts 
  0035fe:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  003604:  6c 06                  bge.b $360c
  003606:  4e ba 00 0a            jsr $3612(pc)
  00360a:  60 04                  bra.b $3610
  00360c:  4e ba 00 60            jsr $366e(pc)
  003610:  4e 75                  rts 
  003612:  2f 07                  move.l d7, -(a7)
  003614:  4a 2d b9 77            tst.b -$4689(a5)
  003618:  6c 50                  bge.b $366a
  00361a:  4e ba 22 d8            jsr $58f4(pc)
  00361e:  3e 00                  move.w d0, d7
  003620:  10 2d b9 5d            move.b -$46a3(a5), d0
  003624:  b0 2d b9 4b            cmp.b -$46b5(a5), d0
  003628:  66 0a                  bne.b $3634
  00362a:  0c 47 ff f8            cmpi.w #$fff8, d7
  00362e:  6d 04                  blt.b $3634
  003630:  4a 47                  tst.w d7
  003632:  6d 1e                  blt.b $3652
  003634:  4a 6d ba 56            tst.w -$45aa(a5)
  003638:  67 14                  beq.b $364e
  00363a:  42 6d ba 56            clr.w -$45aa(a5)
  00363e:  4a 47                  tst.w d7
  003640:  6c 10                  bge.b $3652
  003642:  0c 47 ff fc            cmpi.w #$fffc, d7
  003646:  6c 22                  bge.b $366a
  003648:  4e ba fe 64            jsr $34ae(pc)
  00364c:  60 1c                  bra.b $366a
  00364e:  4a 47                  tst.w d7
  003650:  6d 18                  blt.b $366a
  003652:  4a 6d ba 24            tst.w -$45dc(a5)
  003656:  67 12                  beq.b $366a
  003658:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  00365e:  66 06                  bne.b $3666
  003660:  4a 6d ba 92            tst.w -$456e(a5)
  003664:  66 04                  bne.b $366a
  003666:  4e ba fe 36            jsr $349e(pc)
  00366a:  2e 1f                  move.l (a7)+, d7
  00366c:  4e 75                  rts 
  00366e:  48 e7 03 00            movem.l d6-d7, -(a7)
  003672:  7e 00                  moveq #$0, d7
  003674:  1e 2d b9 46            move.b -$46ba(a5), d7
  003678:  0c 47 00 a6            cmpi.w #$a6, d7
  00367c:  67 00 00 e6            beq.w $3764
  003680:  0c 47 00 96            cmpi.w #$96, d7
  003684:  6d 00 00 de            blt.w $3764
  003688:  0c 6d 00 01 ba 24      cmpi.w #$1, -$45dc(a5)
  00368e:  67 00 00 d4            beq.w $3764
  003692:  4a 6d ba 24            tst.w -$45dc(a5)
  003696:  66 20                  bne.b $36b8
  003698:  4a 6d ba 34            tst.w -$45cc(a5)
  00369c:  67 08                  beq.b $36a6
  00369e:  4e ba 00 fe            jsr $379e(pc)
  0036a2:  60 00 00 c0            bra.w $3764
  0036a6:  0c 2d 00 04 b9 51      cmpi.b #$4, -$46af(a5)
  0036ac:  67 00 00 b6            beq.w $3764
  0036b0:  4e ba fe 0a            jsr $34bc(pc)
  0036b4:  60 00 00 ae            bra.w $3764
  0036b8:  7e 00                  moveq #$0, d7
  0036ba:  1e 2d b9 58            move.b -$46a8(a5), d7
  0036be:  4e ba 22 34            jsr $58f4(pc)
  0036c2:  3c 00                  move.w d0, d6
  0036c4:  0c 46 00 0c            cmpi.w #$c, d6
  0036c8:  6d 16                  blt.b $36e0
  0036ca:  0c 47 00 66            cmpi.w #$66, d7
  0036ce:  6d 10                  blt.b $36e0
  0036d0:  0c 47 00 76            cmpi.w #$76, d7
  0036d4:  6c 0a                  bge.b $36e0
  0036d6:  0c 2d 00 05 b9 5e      cmpi.b #$5, -$46a2(a5)
  0036dc:  67 00 00 86            beq.w $3764
  0036e0:  0c 46 00 23            cmpi.w #$23, d6
  0036e4:  6c 34                  bge.b $371a
  0036e6:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  0036ec:  6c 06                  bge.b $36f4
  0036ee:  0c 46 00 08            cmpi.w #$8, d6
  0036f2:  6d 06                  blt.b $36fa
  0036f4:  0c 46 00 0c            cmpi.w #$c, d6
  0036f8:  6c 16                  bge.b $3710
  0036fa:  10 2d b9 49            move.b -$46b7(a5), d0
  0036fe:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  003702:  66 06                  bne.b $370a
  003704:  4e ba fd c8            jsr $34ce(pc)
  003708:  60 5a                  bra.b $3764
  00370a:  4e ba fd d0            jsr $34dc(pc)
  00370e:  60 54                  bra.b $3764
  003710:  3f 06                  move.w d6, -(a7)
  003712:  4e ba 01 40            jsr $3854(pc)
  003716:  54 8f                  addq.l #$2, a7
  003718:  60 4a                  bra.b $3764
  00371a:  4a 6d ba 8a            tst.w -$4576(a5)
  00371e:  66 44                  bne.b $3764
  003720:  10 2d b9 49            move.b -$46b7(a5), d0
  003724:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  003728:  66 06                  bne.b $3730
  00372a:  4e ba 00 3e            jsr $376a(pc)
  00372e:  60 34                  bra.b $3764
  003730:  0c 47 00 07            cmpi.w #$7, d7
  003734:  6d 12                  blt.b $3748
  003736:  0c 47 00 0f            cmpi.w #$f, d7
  00373a:  6c 0c                  bge.b $3748
  00373c:  0c 46 00 28            cmpi.w #$28, d6
  003740:  6c 22                  bge.b $3764
  003742:  4e ba fd a4            jsr $34e8(pc)
  003746:  60 1c                  bra.b $3764
  003748:  0c 47 00 22            cmpi.w #$22, d7
  00374c:  6d 12                  blt.b $3760
  00374e:  0c 47 00 2c            cmpi.w #$2c, d7
  003752:  6c 0c                  bge.b $3760
  003754:  0c 46 00 32            cmpi.w #$32, d6
  003758:  6c 0a                  bge.b $3764
  00375a:  4e ba fd 8c            jsr $34e8(pc)
  00375e:  60 04                  bra.b $3764
  003760:  4e ba 00 08            jsr $376a(pc)
  003764:  4c df 00 c0            movem.l (a7)+, d6-d7
  003768:  4e 75                  rts 
  00376a:  4e ba 13 b2            jsr $4b1e(pc)
  00376e:  72 00                  moveq #$0, d1
  003770:  12 00                  move.b d0, d1
  003772:  3f 01                  move.w d1, -(a7)
  003774:  4e ba 0e de            jsr $4654(pc)
  003778:  4a 00                  tst.b d0
  00377a:  54 8f                  addq.l #$2, a7
  00377c:  66 14                  bne.b $3792
  00377e:  4e ba 13 d0            jsr $4b50(pc)
  003782:  72 00                  moveq #$0, d1
  003784:  12 00                  move.b d0, d1
  003786:  3f 01                  move.w d1, -(a7)
  003788:  4e ba 0e ca            jsr $4654(pc)
  00378c:  4a 00                  tst.b d0
  00378e:  54 8f                  addq.l #$2, a7
  003790:  67 06                  beq.b $3798
  003792:  4e ba fd 48            jsr $34dc(pc)
  003796:  60 04                  bra.b $379c
  003798:  4e ba fd 34            jsr $34ce(pc)
  00379c:  4e 75                  rts 
  00379e:  2f 07                  move.l d7, -(a7)
  0037a0:  1e 2d b9 5e            move.b -$46a2(a5), d7
  0037a4:  48 87                  ext.w d7
  0037a6:  0c 47 00 02            cmpi.w #$2, d7
  0037aa:  67 00 00 a4            beq.w $3850
  0037ae:  0c 47 00 06            cmpi.w #$6, d7
  0037b2:  67 00 00 9c            beq.w $3850
  0037b6:  4e ba 13 66            jsr $4b1e(pc)
  0037ba:  1f 00                  move.b d0, -(a7)
  0037bc:  4e ba 17 d6            jsr $4f94(pc)
  0037c0:  4a 40                  tst.w d0
  0037c2:  54 8f                  addq.l #$2, a7
  0037c4:  67 0c                  beq.b $37d2
  0037c6:  42 6d ba 34            clr.w -$45cc(a5)
  0037ca:  4e ba fd 02            jsr $34ce(pc)
  0037ce:  60 00 00 80            bra.w $3850
  0037d2:  70 00                  moveq #$0, d0
  0037d4:  10 2d ba e8            move.b -$4518(a5), d0
  0037d8:  3f 00                  move.w d0, -(a7)
  0037da:  4e ba 0e 78            jsr $4654(pc)
  0037de:  4a 00                  tst.b d0
  0037e0:  54 8f                  addq.l #$2, a7
  0037e2:  67 06                  beq.b $37ea
  0037e4:  4e ba fc f6            jsr $34dc(pc)
  0037e8:  60 66                  bra.b $3850
  0037ea:  52 6d ba ee            addq.w #$1, -$4512(a5)
  0037ee:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  0037f2:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  0037f6:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  0037fa:  4e ba 07 76            jsr $3f72(pc)
  0037fe:  0c 2d 00 02 ba e8      cmpi.b #$2, -$4518(a5)
  003804:  5c 8f                  addq.l #$6, a7
  003806:  67 3a                  beq.b $3842
  003808:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  00380e:  67 32                  beq.b $3842
  003810:  1f 2d ba e8            move.b -$4518(a5), -(a7)
  003814:  4e ba 17 7e            jsr $4f94(pc)
  003818:  4a 40                  tst.w d0
  00381a:  54 8f                  addq.l #$2, a7
  00381c:  66 24                  bne.b $3842
  00381e:  70 00                  moveq #$0, d0
  003820:  10 2d ba e8            move.b -$4518(a5), d0
  003824:  3f 00                  move.w d0, -(a7)
  003826:  4e ba 0e 2c            jsr $4654(pc)
  00382a:  4a 00                  tst.b d0
  00382c:  54 8f                  addq.l #$2, a7
  00382e:  67 12                  beq.b $3842
  003830:  10 2d b9 4b            move.b -$46b5(a5), d0
  003834:  48 80                  ext.w d0
  003836:  12 2d b9 5d            move.b -$46a3(a5), d1
  00383a:  48 81                  ext.w d1
  00383c:  52 40                  addq.w #$1, d0
  00383e:  b2 40                  cmp.w d0, d1
  003840:  67 0a                  beq.b $384c
  003842:  42 6d ba 34            clr.w -$45cc(a5)
  003846:  4e ba fc 86            jsr $34ce(pc)
  00384a:  60 04                  bra.b $3850
  00384c:  4e ba fc 8e            jsr $34dc(pc)
  003850:  2e 1f                  move.l (a7)+, d7
  003852:  4e 75                  rts 
  003854:  4e 56 00 00            link.w a6, #$0
  003858:  0c 2d 00 02 b9 64      cmpi.b #$2, -$469c(a5)
  00385e:  66 0c                  bne.b $386c
  003860:  3f 2e 00 08            move.w $8(a6), -(a7)
  003864:  4e ba 00 22            jsr $3888(pc)
  003868:  54 8f                  addq.l #$2, a7
  00386a:  60 18                  bra.b $3884
  00386c:  4a 6d ba 8a            tst.w -$4576(a5)
  003870:  66 12                  bne.b $3884
  003872:  0c 6e 00 1d 00 08      cmpi.w #$1d, $8(a6)
  003878:  6c 06                  bge.b $3880
  00387a:  4e ba fc 6c            jsr $34e8(pc)
  00387e:  60 04                  bra.b $3884
  003880:  4e ba fc 5a            jsr $34dc(pc)
  003884:  4e 5e                  unlk a6
  003886:  4e 75                  rts 
  003888:  4e 56 00 00            link.w a6, #$0
  00388c:  2f 07                  move.l d7, -(a7)
  00388e:  3e 2e 00 08            move.w $8(a6), d7
  003892:  0c 47 00 0a            cmpi.w #$a, d7
  003896:  6d 06                  blt.b $389e
  003898:  0c 47 00 1d            cmpi.w #$1d, d7
  00389c:  6d 06                  blt.b $38a4
  00389e:  4e ba 00 2a            jsr $38ca(pc)
  0038a2:  60 20                  bra.b $38c4
  0038a4:  4e ba 00 52            jsr $38f8(pc)
  0038a8:  4a 6d ba 8a            tst.w -$4576(a5)
  0038ac:  66 16                  bne.b $38c4
  0038ae:  0c 47 00 0c            cmpi.w #$c, d7
  0038b2:  6d 06                  blt.b $38ba
  0038b4:  0c 47 00 1d            cmpi.w #$1d, d7
  0038b8:  6d 06                  blt.b $38c0
  0038ba:  4e ba 00 0e            jsr $38ca(pc)
  0038be:  60 04                  bra.b $38c4
  0038c0:  4e ba 00 9c            jsr $395e(pc)
  0038c4:  2e 1f                  move.l (a7)+, d7
  0038c6:  4e 5e                  unlk a6
  0038c8:  4e 75                  rts 
  0038ca:  4a 6d ba 20            tst.w -$45e0(a5)
  0038ce:  67 06                  beq.b $38d6
  0038d0:  4a 6d ba 88            tst.w -$4578(a5)
  0038d4:  66 20                  bne.b $38f6
  0038d6:  3f 3c 00 ff            move.w #$ff, -(a7)
  0038da:  4e ad 00 72            jsr $72(a5)
  0038de:  32 2d ba 20            move.w -$45e0(a5), d1
  0038e2:  20 4d                  movea.l a5, a0
  0038e4:  d0 c1                  adda.w d1, a0
  0038e6:  74 00                  moveq #$0, d2
  0038e8:  14 28 a9 54            move.b -$56ac(a0), d2
  0038ec:  b4 40                  cmp.w d0, d2
  0038ee:  54 8f                  addq.l #$2, a7
  0038f0:  6f 04                  ble.b $38f6
  0038f2:  4e ba fb e8            jsr $34dc(pc)
  0038f6:  4e 75                  rts 
  0038f8:  2f 07                  move.l d7, -(a7)
  0038fa:  7e 00                  moveq #$0, d7
  0038fc:  1e 2d b9 58            move.b -$46a8(a5), d7
  003900:  0c 47 00 98            cmpi.w #$98, d7
  003904:  67 0c                  beq.b $3912
  003906:  0c 47 00 99            cmpi.w #$99, d7
  00390a:  67 06                  beq.b $3912
  00390c:  0c 47 00 a2            cmpi.w #$a2, d7
  003910:  66 48                  bne.b $395a
  003912:  4a 6d ba 2a            tst.w -$45d6(a5)
  003916:  67 22                  beq.b $393a
  003918:  3f 3c 00 ff            move.w #$ff, -(a7)
  00391c:  4e ad 00 72            jsr $72(a5)
  003920:  32 2d ba 20            move.w -$45e0(a5), d1
  003924:  20 4d                  movea.l a5, a0
  003926:  d0 c1                  adda.w d1, a0
  003928:  74 00                  moveq #$0, d2
  00392a:  14 28 a9 48            move.b -$56b8(a0), d2
  00392e:  b4 40                  cmp.w d0, d2
  003930:  54 8f                  addq.l #$2, a7
  003932:  6f 26                  ble.b $395a
  003934:  4e ba fb be            jsr $34f4(pc)
  003938:  60 20                  bra.b $395a
  00393a:  3f 3c 00 ff            move.w #$ff, -(a7)
  00393e:  4e ad 00 72            jsr $72(a5)
  003942:  32 2d ba 20            move.w -$45e0(a5), d1
  003946:  20 4d                  movea.l a5, a0
  003948:  d0 c1                  adda.w d1, a0
  00394a:  74 00                  moveq #$0, d2
  00394c:  14 28 a9 3c            move.b -$56c4(a0), d2
  003950:  b4 40                  cmp.w d0, d2
  003952:  54 8f                  addq.l #$2, a7
  003954:  6f 04                  ble.b $395a
  003956:  4e ba fb 9c            jsr $34f4(pc)
  00395a:  2e 1f                  move.l (a7)+, d7
  00395c:  4e 75                  rts 
  00395e:  2f 07                  move.l d7, -(a7)
  003960:  7e 00                  moveq #$0, d7
  003962:  1e 2d b9 58            move.b -$46a8(a5), d7
  003966:  0c 47 00 a9            cmpi.w #$a9, d7
  00396a:  67 5a                  beq.b $39c6
  00396c:  0c 47 00 97            cmpi.w #$97, d7
  003970:  67 54                  beq.b $39c6
  003972:  7e 00                  moveq #$0, d7
  003974:  1e 2d b9 46            move.b -$46ba(a5), d7
  003978:  0c 47 00 a1            cmpi.w #$a1, d7
  00397c:  67 06                  beq.b $3984
  00397e:  0c 47 00 96            cmpi.w #$96, d7
  003982:  66 22                  bne.b $39a6
  003984:  3f 3c 00 ff            move.w #$ff, -(a7)
  003988:  4e ad 00 72            jsr $72(a5)
  00398c:  32 2d ba 20            move.w -$45e0(a5), d1
  003990:  20 4d                  movea.l a5, a0
  003992:  d0 c1                  adda.w d1, a0
  003994:  74 00                  moveq #$0, d2
  003996:  14 28 a9 30            move.b -$56d0(a0), d2
  00399a:  b4 40                  cmp.w d0, d2
  00399c:  54 8f                  addq.l #$2, a7
  00399e:  6f 26                  ble.b $39c6
  0039a0:  4e ba fb 46            jsr $34e8(pc)
  0039a4:  60 20                  bra.b $39c6
  0039a6:  3f 3c 00 ff            move.w #$ff, -(a7)
  0039aa:  4e ad 00 72            jsr $72(a5)
  0039ae:  32 2d ba 20            move.w -$45e0(a5), d1
  0039b2:  20 4d                  movea.l a5, a0
  0039b4:  d0 c1                  adda.w d1, a0
  0039b6:  74 00                  moveq #$0, d2
  0039b8:  14 28 a9 24            move.b -$56dc(a0), d2
  0039bc:  b4 40                  cmp.w d0, d2
  0039be:  54 8f                  addq.l #$2, a7
  0039c0:  6f 04                  ble.b $39c6
  0039c2:  4e ba fb 24            jsr $34e8(pc)
  0039c6:  2e 1f                  move.l (a7)+, d7
  0039c8:  4e 75                  rts 
  0039ca:  48 e7 03 00            movem.l d6-d7, -(a7)
  0039ce:  4a 2d b9 53            tst.b -$46ad(a5)
  0039d2:  6c 00 01 22            bge.w $3af6
  0039d6:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  0039dc:  67 14                  beq.b $39f2
  0039de:  3f 3c 00 64            move.w #$64, -(a7)
  0039e2:  4e ba 0d 22            jsr $4706(pc)
  0039e6:  3e bc 00 55            move.w #$55, (a7)
  0039ea:  4e ad 05 52            jsr $552(a5)
  0039ee:  54 8f                  addq.l #$2, a7
  0039f0:  60 3a                  bra.b $3a2c
  0039f2:  0c 2d 00 04 b9 51      cmpi.b #$4, -$46af(a5)
  0039f8:  67 0e                  beq.b $3a08
  0039fa:  3f 3c 00 01            move.w #$1, -(a7)
  0039fe:  4e ba 0d 06            jsr $4706(pc)
  003a02:  4a 40                  tst.w d0
  003a04:  54 8f                  addq.l #$2, a7
  003a06:  66 24                  bne.b $3a2c
  003a08:  3f 3c 00 4a            move.w #$4a, -(a7)
  003a0c:  4e ad 05 52            jsr $552(a5)
  003a10:  10 2d b9 4b            move.b -$46b5(a5), d0
  003a14:  48 80                  ext.w d0
  003a16:  20 4d                  movea.l a5, a0
  003a18:  d0 c0                  adda.w d0, a0
  003a1a:  d0 c0                  adda.w d0, a0
  003a1c:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  003a22:  42 2d b9 4e            clr.b -$46b2(a5)
  003a26:  54 8f                  addq.l #$2, a7
  003a28:  60 00 00 ac            bra.w $3ad6
  003a2c:  4e ba 11 90            jsr $4bbe(pc)
  003a30:  3e 00                  move.w d0, d7
  003a32:  4e ba 11 58            jsr $4b8c(pc)
  003a36:  72 00                  moveq #$0, d1
  003a38:  12 00                  move.b d0, d1
  003a3a:  4a 41                  tst.w d1
  003a3c:  66 06                  bne.b $3a44
  003a3e:  0c 47 00 04            cmpi.w #$4, d7
  003a42:  6c 72                  bge.b $3ab6
  003a44:  3f 3c 00 55            move.w #$55, -(a7)
  003a48:  4e ad 05 52            jsr $552(a5)
  003a4c:  4a 2d b9 51            tst.b -$46af(a5)
  003a50:  54 8f                  addq.l #$2, a7
  003a52:  67 4a                  beq.b $3a9e
  003a54:  4a 2d b9 49            tst.b -$46b7(a5)
  003a58:  6c 44                  bge.b $3a9e
  003a5a:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  003a60:  67 0c                  beq.b $3a6e
  003a62:  4e ba 0c fe            jsr $4762(pc)
  003a66:  72 00                  moveq #$0, d1
  003a68:  12 00                  move.b d0, d1
  003a6a:  59 41                  subq.w #$4, d1
  003a6c:  66 30                  bne.b $3a9e
  003a6e:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  003a74:  56 c0                  sne.b d0
  003a76:  44 00                  neg.b d0
  003a78:  48 80                  ext.w d0
  003a7a:  72 05                  moveq #$5, d1
  003a7c:  d2 6d ba ec            add.w -$4514(a5), d1
  003a80:  92 40                  sub.w d0, d1
  003a82:  20 4d                  movea.l a5, a0
  003a84:  d0 c1                  adda.w d1, a0
  003a86:  70 07                  moveq #$7, d0
  003a88:  d0 28 b8 78            add.b -$4788(a0), d0
  003a8c:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003a90:  3f 3c 00 0a            move.w #$a, -(a7)
  003a94:  4e ba 07 6c            jsr $4202(pc)
  003a98:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003a9c:  54 8f                  addq.l #$2, a7
  003a9e:  10 2d b9 4b            move.b -$46b5(a5), d0
  003aa2:  48 80                  ext.w d0
  003aa4:  20 4d                  movea.l a5, a0
  003aa6:  d0 c0                  adda.w d0, a0
  003aa8:  d0 c0                  adda.w d0, a0
  003aaa:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  003ab0:  42 2d b9 4e            clr.b -$46b2(a5)
  003ab4:  60 20                  bra.b $3ad6
  003ab6:  70 ec                  moveq #$ec, d0
  003ab8:  d0 47                  add.w d7, d0
  003aba:  3f 00                  move.w d0, -(a7)
  003abc:  4e ba 07 44            jsr $4202(pc)
  003ac0:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003ac4:  4e ba 06 06            jsr $40cc(pc)
  003ac8:  4e ba 1e 6a            jsr $5934(pc)
  003acc:  3e bc 00 51            move.w #$51, (a7)
  003ad0:  4e ad 05 52            jsr $552(a5)
  003ad4:  54 8f                  addq.l #$2, a7
  003ad6:  4a 2d b9 51            tst.b -$46af(a5)
  003ada:  66 0c                  bne.b $3ae8
  003adc:  3f 3c 00 0d            move.w #$d, -(a7)
  003ae0:  4e ba cc d2            jsr $7b4(pc)
  003ae4:  54 8f                  addq.l #$2, a7
  003ae6:  60 0a                  bra.b $3af2
  003ae8:  3f 3c 00 0c            move.w #$c, -(a7)
  003aec:  4e ba cc c6            jsr $7b4(pc)
  003af0:  54 8f                  addq.l #$2, a7
  003af2:  4e ba 07 56            jsr $424a(pc)
  003af6:  4c df 00 c0            movem.l (a7)+, d6-d7
  003afa:  4e 75                  rts 
  003afc:  0c 2d 00 63 b9 82      cmpi.b #$63, -$467e(a5)
  003b02:  66 2e                  bne.b $3b32
  003b04:  0c 2d 00 63 b9 70      cmpi.b #$63, -$4690(a5)
  003b0a:  66 06                  bne.b $3b12
  003b0c:  1b 7c 00 01 b9 70      move.b #$1, -$4690(a5)
  003b12:  4e ba 09 94            jsr $44a8(pc)
  003b16:  4e ba fe b2            jsr $39ca(pc)
  003b1a:  4e ba 09 a0            jsr $44bc(pc)
  003b1e:  30 2d ba 20            move.w -$45e0(a5), d0
  003b22:  20 4d                  movea.l a5, a0
  003b24:  d0 c0                  adda.w d0, a0
  003b26:  72 00                  moveq #$0, d1
  003b28:  12 28 a9 60            move.b -$56a0(a0), d1
  003b2c:  3b 41 ba 8a            move.w d1, -$4576(a5)
  003b30:  60 14                  bra.b $3b46
  003b32:  0c 2d 00 63 b9 70      cmpi.b #$63, -$4690(a5)
  003b38:  66 0c                  bne.b $3b46
  003b3a:  4e ba 09 44            jsr $4480(pc)
  003b3e:  4e ba fe 8a            jsr $39ca(pc)
  003b42:  4e ba 09 50            jsr $4494(pc)
  003b46:  4e 75                  rts 
  003b48:  2f 07                  move.l d7, -(a7)
  003b4a:  7e 00                  moveq #$0, d7
  003b4c:  1e 2d b9 6a            move.b -$4696(a5), d7
  003b50:  4a 47                  tst.w d7
  003b52:  67 24                  beq.b $3b78
  003b54:  0c 47 00 db            cmpi.w #$db, d7
  003b58:  6d 06                  blt.b $3b60
  003b5a:  0c 47 00 e5            cmpi.w #$e5, d7
  003b5e:  6d 18                  blt.b $3b78
  003b60:  4e ba 09 ba            jsr $451c(pc)
  003b64:  4e ba 00 16            jsr $3b7c(pc)
  003b68:  4e ba 09 d8            jsr $4542(pc)
  003b6c:  4e ba 09 62            jsr $44d0(pc)
  003b70:  4e ba 00 0a            jsr $3b7c(pc)
  003b74:  4e ba 09 80            jsr $44f6(pc)
  003b78:  2e 1f                  move.l (a7)+, d7
  003b7a:  4e 75                  rts 
  003b7c:  48 e7 0f 00            movem.l d4-d7, -(a7)
  003b80:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  003b86:  66 00 00 aa            bne.w $3c32
  003b8a:  10 2d b9 4b            move.b -$46b5(a5), d0
  003b8e:  b0 2d b9 5d            cmp.b -$46a3(a5), d0
  003b92:  66 00 00 9e            bne.w $3c32
  003b96:  7e 00                  moveq #$0, d7
  003b98:  1e 2d b9 46            move.b -$46ba(a5), d7
  003b9c:  0c 47 00 99            cmpi.w #$99, d7
  003ba0:  67 08                  beq.b $3baa
  003ba2:  0c 47 00 9a            cmpi.w #$9a, d7
  003ba6:  66 00 00 8a            bne.w $3c32
  003baa:  4e ba 1d 48            jsr $58f4(pc)
  003bae:  3c 00                  move.w d0, d6
  003bb0:  7a 00                  moveq #$0, d5
  003bb2:  1a 2d b9 58            move.b -$46a8(a5), d5
  003bb6:  4a 46                  tst.w d6
  003bb8:  6d 12                  blt.b $3bcc
  003bba:  0c 46 00 1d            cmpi.w #$1d, d6
  003bbe:  6c 0c                  bge.b $3bcc
  003bc0:  0c 45 00 a1            cmpi.w #$a1, d5
  003bc4:  67 2c                  beq.b $3bf2
  003bc6:  0c 45 00 96            cmpi.w #$96, d5
  003bca:  67 26                  beq.b $3bf2
  003bcc:  0c 47 00 9a            cmpi.w #$9a, d7
  003bd0:  66 42                  bne.b $3c14
  003bd2:  0c 2d 00 02 b9 64      cmpi.b #$2, -$469c(a5)
  003bd8:  6c 04                  bge.b $3bde
  003bda:  78 08                  moveq #$8, d4
  003bdc:  60 02                  bra.b $3be0
  003bde:  78 0c                  moveq #$c, d4
  003be0:  b8 46                  cmp.w d6, d4
  003be2:  6e 30                  bgt.b $3c14
  003be4:  0c 46 00 1d            cmpi.w #$1d, d6
  003be8:  6c 2a                  bge.b $3c14
  003bea:  1b 7c 00 63 b9 5e      move.b #$63, -$46a2(a5)
  003bf0:  60 22                  bra.b $3c14
  003bf2:  3a 3c 00 a1            move.w #$a1, d5
  003bf6:  1b 45 b9 58            move.b d5, -$46a8(a5)
  003bfa:  4a 2d b9 51            tst.b -$46af(a5)
  003bfe:  67 06                  beq.b $3c06
  003c00:  3b 7c 00 04 ba 2a      move.w #$4, -$45d6(a5)
  003c06:  3f 3c 00 45            move.w #$45, -(a7)
  003c0a:  4e ad 05 52            jsr $552(a5)
  003c0e:  4e ba 06 3a            jsr $424a(pc)
  003c12:  54 8f                  addq.l #$2, a7
  003c14:  0c 47 00 9a            cmpi.w #$9a, d7
  003c18:  66 18                  bne.b $3c32
  003c1a:  0c 45 00 a1            cmpi.w #$a1, d5
  003c1e:  67 12                  beq.b $3c32
  003c20:  0c 2d 00 63 b9 5e      cmpi.b #$63, -$46a2(a5)
  003c26:  67 0a                  beq.b $3c32
  003c28:  3f 3c 00 0b            move.w #$b, -(a7)
  003c2c:  4e ba cb 86            jsr $7b4(pc)
  003c30:  54 8f                  addq.l #$2, a7
  003c32:  4c df 00 f0            movem.l (a7)+, d4-d7
  003c36:  4e 75                  rts 
  003c38:  0c 6d 00 03 a9 0c      cmpi.w #$3, -$56f4(a5)
  003c3e:  66 00 01 0e            bne.w $3d4e
  003c42:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  003c48:  66 00 01 04            bne.w $3d4e
  003c4c:  0c 6d 00 01 ba 6a      cmpi.w #$1, -$4596(a5)
  003c52:  66 00 00 fa            bne.w $3d4e
  003c56:  4a 6d ba 3c            tst.w -$45c4(a5)
  003c5a:  67 00 00 f2            beq.w $3d4e
  003c5e:  0c 2d 00 02 b9 6e      cmpi.b #$2, -$4692(a5)
  003c64:  67 0a                  beq.b $3c70
  003c66:  0c 2d 00 03 b9 6e      cmpi.b #$3, -$4692(a5)
  003c6c:  66 00 00 e0            bne.w $3d4e
  003c70:  2f 3c 00 05 00 01      move.l #$50001, -(a7)
  003c76:  3f 2d ba 6a            move.w -$4596(a5), -(a7)
  003c7a:  4e ba 02 f6            jsr $3f72(pc)
  003c7e:  0c 2d 00 15 ba e8      cmpi.b #$15, -$4518(a5)
  003c84:  5c 8f                  addq.l #$6, a7
  003c86:  66 00 00 c6            bne.w $3d4e
  003c8a:  70 00                  moveq #$0, d0
  003c8c:  10 2d ba e9            move.b -$4517(a5), d0
  003c90:  d0 ad bd 82            add.l -$427e(a5), d0
  003c94:  20 40                  movea.l d0, a0
  003c96:  10 bc 00 01            move.b #$1, (a0)
  003c9a:  3b 7c 00 18 bd 6c      move.w #$18, -$4294(a5)
  003ca0:  70 00                  moveq #$0, d0
  003ca2:  10 2d ba e9            move.b -$4517(a5), d0
  003ca6:  3f 00                  move.w d0, -(a7)
  003ca8:  4e ad 04 42            jsr $442(a5)
  003cac:  52 2d ba e9            addq.b #$1, -$4517(a5)
  003cb0:  70 00                  moveq #$0, d0
  003cb2:  10 2d ba e9            move.b -$4517(a5), d0
  003cb6:  3e 80                  move.w d0, (a7)
  003cb8:  4e ad 04 42            jsr $442(a5)
  003cbc:  1b 7c 00 04 b9 51      move.b #$4, -$46af(a5)
  003cc2:  1b 6d ba 6b b9 4f      move.b -$4595(a5), -$46b1(a5)
  003cc8:  1b 7c 00 05 b9 4a      move.b #$5, -$46b6(a5)
  003cce:  10 2d b9 4a            move.b -$46b6(a5), d0
  003cd2:  48 80                  ext.w d0
  003cd4:  20 4d                  movea.l a5, a0
  003cd6:  d0 c0                  adda.w d0, a0
  003cd8:  70 07                  moveq #$7, d0
  003cda:  d0 28 b8 7d            add.b -$4783(a0), d0
  003cde:  5e 00                  addq.b #$7, d0
  003ce0:  1b 40 b9 47            move.b d0, -$46b9(a5)
  003ce4:  1b 7c 00 01 b9 4b      move.b #$1, -$46b5(a5)
  003cea:  10 2d b9 4b            move.b -$46b5(a5), d0
  003cee:  48 80                  ext.w d0
  003cf0:  20 4d                  movea.l a5, a0
  003cf2:  d0 c0                  adda.w d0, a0
  003cf4:  d0 c0                  adda.w d0, a0
  003cf6:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  003cfc:  42 2d b9 4e            clr.b -$46b2(a5)
  003d00:  42 2d b9 4d            clr.b -$46b3(a5)
  003d04:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  003d0a:  1b 7c 00 02 b9 52      move.b #$2, -$46ae(a5)
  003d10:  1b 7c 00 ff b9 53      move.b #$ff, -$46ad(a5)
  003d16:  3e bc 00 58            move.w #$58, (a7)
  003d1a:  4e ad 05 52            jsr $552(a5)
  003d1e:  4e ba 05 2a            jsr $424a(pc)
  003d22:  3e bc 00 2c            move.w #$2c, (a7)
  003d26:  4e ba ca 8c            jsr $7b4(pc)
  003d2a:  3b 7c 00 02 ba 20      move.w #$2, -$45e0(a5)
  003d30:  70 03                  moveq #$3, d0
  003d32:  3b 40 ba 4c            move.w d0, -$45b4(a5)
  003d36:  3b 40 ba 4e            move.w d0, -$45b2(a5)
  003d3a:  42 6d ba 8a            clr.w -$4576(a5)
  003d3e:  42 6d ba 56            clr.w -$45aa(a5)
  003d42:  4e ba 07 78            jsr $44bc(pc)
  003d46:  3b 7c 00 01 ba 2c      move.w #$1, -$45d4(a5)
  003d4c:  54 8f                  addq.l #$2, a7
  003d4e:  4e 75                  rts 
  003d50:  4e 56 00 00            link.w a6, #$0
  003d54:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  003d58:  28 6e 00 08            movea.l $8(a6), a4
  003d5c:  0c 6d 00 fe ba 5a      cmpi.w #$fe, -$45a6(a5)
  003d62:  6c 00 00 80            bge.w $3de4
  003d66:  52 6d ba 5a            addq.w #$1, -$45a6(a5)
  003d6a:  3e 2d ba 5c            move.w -$45a4(a5), d7
  003d6e:  20 07                  move.l d7, d0
  003d70:  48 c0                  ext.l d0
  003d72:  e5 88                  lsl.l #$2, d0
  003d74:  30 34 08 00            move.w (a4, d0.l), d0
  003d78:  b0 6d ba 5a            cmp.w -$45a6(a5), d0
  003d7c:  6e 06                  bgt.b $3d84
  003d7e:  52 6d ba 5c            addq.w #$1, -$45a4(a5)
  003d82:  60 02                  bra.b $3d86
  003d84:  53 47                  subq.w #$1, d7
  003d86:  20 07                  move.l d7, d0
  003d88:  48 c0                  ext.l d0
  003d8a:  e5 88                  lsl.l #$2, d0
  003d8c:  3c 34 08 02            move.w $2(a4, d0.l), d6
  003d90:  30 06                  move.w d6, d0
  003d92:  52 40                  addq.w #$1, d0
  003d94:  0c 40 00 08            cmpi.w #$8, d0
  003d98:  62 4a                  bhi.b $3de4
  003d9a:  43 fa 00 50            lea.l $3dec(pc), a1
  003d9e:  d0 40                  add.w d0, d0
  003da0:  d2 f1 00 00            adda.w (a1, d0.w), a1
  003da4:  4e d1                  jmp (a1)
  003da6:  4a 6d ba 5e            tst.w -$45a2(a5)
  003daa:  67 38                  beq.b $3de4
  003dac:  42 6d ba 5e            clr.w -$45a2(a5)
  003db0:  60 32                  bra.b $3de4
  003db2:  4e ba f6 70            jsr $3424(pc)
  003db6:  60 2c                  bra.b $3de4
  003db8:  4e ba f6 8c            jsr $3446(pc)
  003dbc:  60 26                  bra.b $3de4
  003dbe:  4e ba f6 92            jsr $3452(pc)
  003dc2:  60 20                  bra.b $3de4
  003dc4:  4e ba f6 9a            jsr $3460(pc)
  003dc8:  60 1a                  bra.b $3de4
  003dca:  4e ba f6 a0            jsr $346c(pc)
  003dce:  60 14                  bra.b $3de4
  003dd0:  4e ba f6 8e            jsr $3460(pc)
  003dd4:  4e ba f6 70            jsr $3446(pc)
  003dd8:  60 0a                  bra.b $3de4
  003dda:  4e ba f7 24            jsr $3500(pc)
  003dde:  60 04                  bra.b $3de4
  003de0:  4e ba f7 2a            jsr $350c(pc)
  003de4:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  003de8:  4e 5e                  unlk a6
  003dea:  4e 75                  rts 
  003dec:  ff ba                  dc.w $ffba
  003dee:  ff c6                  dc.w $ffc6
  003df0:  ff cc                  dc.w $ffcc
  003df2:  ff d2                  dc.w $ffd2
  003df4:  ff d8                  dc.w $ffd8
  003df6:  ff de                  dc.w $ffde
  003df8:  ff e4                  dc.w $ffe4
  003dfa:  ff ee                  dc.w $ffee
  003dfc:  ff f4                  dc.w $fff4
  003dfe:  0c 2d 00 04 b9 4f      cmpi.b #$4, -$46b1(a5)
  003e04:  66 12                  bne.b $3e18
  003e06:  0c 2d 00 50 b9 47      cmpi.b #$50, -$46b9(a5)
  003e0c:  64 06                  bcc.b $3e14
  003e0e:  4e ba 18 96            jsr $56a6(pc)
  003e12:  60 04                  bra.b $3e18
  003e14:  4e ba f6 30            jsr $3446(pc)
  003e18:  4e 75                  rts 
  003e1a:  0c 2d 00 18 b9 4f      cmpi.b #$18, -$46b1(a5)
  003e20:  66 42                  bne.b $3e64
  003e22:  4a 6d ba 5a            tst.w -$45a6(a5)
  003e26:  66 26                  bne.b $3e4e
  003e28:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  003e2e:  3f 3c 00 18            move.w #$18, -(a7)
  003e32:  4e ba 01 3e            jsr $3f72(pc)
  003e36:  70 00                  moveq #$0, d0
  003e38:  10 2d ba e9            move.b -$4517(a5), d0
  003e3c:  d0 ad bd 86            add.l -$427a(a5), d0
  003e40:  20 40                  movea.l d0, a0
  003e42:  0c 10 00 5c            cmpi.b #$5c, (a0)
  003e46:  5c 8f                  addq.l #$6, a7
  003e48:  65 1a                  bcs.b $3e64
  003e4a:  42 6d ba 5c            clr.w -$45a4(a5)
  003e4e:  48 6d a9 a0            pea.l -$5660(a5)
  003e52:  4e ba fe fc            jsr $3d50(pc)
  003e56:  0c 2d 00 0f b9 47      cmpi.b #$f, -$46b9(a5)
  003e5c:  58 8f                  addq.l #$4, a7
  003e5e:  64 04                  bcc.b $3e64
  003e60:  4e ba 18 44            jsr $56a6(pc)
  003e64:  4e 75                  rts 
  003e66:  0c 2d 00 01 b9 4f      cmpi.b #$1, -$46b1(a5)
  003e6c:  66 18                  bne.b $3e86
  003e6e:  0c 2d 00 2b b9 6a      cmpi.b #$2b, -$4696(a5)
  003e74:  66 10                  bne.b $3e86
  003e76:  0c 2d 00 80 b9 6b      cmpi.b #$80, -$4695(a5)
  003e7c:  64 08                  bcc.b $3e86
  003e7e:  4e ba f6 80            jsr $3500(pc)
  003e82:  4e ba f5 c2            jsr $3446(pc)
  003e86:  4e 75                  rts 
  003e88:  48 e7 03 00            movem.l d6-d7, -(a7)
  003e8c:  0c 2d 00 0f b9 73      cmpi.b #$f, -$468d(a5)
  003e92:  66 18                  bne.b $3eac
  003e94:  4a 6d ba 2c            tst.w -$45d4(a5)
  003e98:  66 12                  bne.b $3eac
  003e9a:  0c 2d 00 96 b9 6b      cmpi.b #$96, -$4695(a5)
  003ea0:  64 0a                  bcc.b $3eac
  003ea2:  3b 7c 00 01 ba 2c      move.w #$1, -$45d4(a5)
  003ea8:  60 00 00 c2            bra.w $3f6c
  003eac:  7e 00                  moveq #$0, d7
  003eae:  1e 2d b9 58            move.b -$46a8(a5), d7
  003eb2:  4e ba 1a 40            jsr $58f4(pc)
  003eb6:  3c 00                  move.w d0, d6
  003eb8:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  003ebe:  6d 1c                  blt.b $3edc
  003ec0:  4a 6d ba 36            tst.w -$45ca(a5)
  003ec4:  67 06                  beq.b $3ecc
  003ec6:  4a 6d ba 8a            tst.w -$4576(a5)
  003eca:  66 08                  bne.b $3ed4
  003ecc:  4e ba f7 a0            jsr $366e(pc)
  003ed0:  60 00 00 9a            bra.w $3f6c
  003ed4:  4e ba f5 96            jsr $346c(pc)
  003ed8:  60 00 00 92            bra.w $3f6c
  003edc:  0c 2d 00 02 b9 64      cmpi.b #$2, -$469c(a5)
  003ee2:  6c 06                  bge.b $3eea
  003ee4:  4a 6d ba 36            tst.w -$45ca(a5)
  003ee8:  66 26                  bne.b $3f10
  003eea:  0c 6d 00 02 ba 24      cmpi.w #$2, -$45dc(a5)
  003ef0:  6d 06                  blt.b $3ef8
  003ef2:  0c 46 00 5a            cmpi.w #$5a, d6
  003ef6:  6d 0a                  blt.b $3f02
  003ef8:  4a 46                  tst.w d6
  003efa:  6c 70                  bge.b $3f6c
  003efc:  4e ba f5 54            jsr $3452(pc)
  003f00:  60 6a                  bra.b $3f6c
  003f02:  0c 2d 00 0f b9 46      cmpi.b #$f, -$46ba(a5)
  003f08:  66 62                  bne.b $3f6c
  003f0a:  4e ba f5 92            jsr $349e(pc)
  003f0e:  60 5c                  bra.b $3f6c
  003f10:  0c 46 00 0a            cmpi.w #$a, d6
  003f14:  6c 32                  bge.b $3f48
  003f16:  3b 7c 00 07 ba 18      move.w #$7, -$45e8(a5)
  003f1c:  3b 7c 00 12 ba 1a      move.w #$12, -$45e6(a5)
  003f22:  4e ba c7 92            jsr $6b6(pc)
  003f26:  4a 2d a2 09            tst.b -$5df7(a5)
  003f2a:  67 08                  beq.b $3f34
  003f2c:  3b 7c 00 2a ba 8e      move.w #$2a, -$4572(a5)
  003f32:  60 06                  bra.b $3f3a
  003f34:  3b 6d ba 1a ba 8e      move.w -$45e6(a5), -$4572(a5)
  003f3a:  42 2d b9 51            clr.b -$46af(a5)
  003f3e:  4e ba 05 54            jsr $4494(pc)
  003f42:  4e ba 17 62            jsr $56a6(pc)
  003f46:  60 24                  bra.b $3f6c
  003f48:  0c 6d 00 02 ba 24      cmpi.w #$2, -$45dc(a5)
  003f4e:  66 1c                  bne.b $3f6c
  003f50:  0c 47 00 03            cmpi.w #$3, d7
  003f54:  6d 06                  blt.b $3f5c
  003f56:  0c 47 00 0f            cmpi.w #$f, d7
  003f5a:  6d 0c                  blt.b $3f68
  003f5c:  0c 47 00 7f            cmpi.w #$7f, d7
  003f60:  6d 0a                  blt.b $3f6c
  003f62:  0c 47 00 85            cmpi.w #$85, d7
  003f66:  6c 04                  bge.b $3f6c
  003f68:  4e ba f4 dc            jsr $3446(pc)
  003f6c:  4c df 00 c0            movem.l (a7)+, d6-d7
  003f70:  4e 75                  rts 
  003f72:  4e 56 00 00            link.w a6, #$0
  003f76:  48 e7 1f 00            movem.l d3-d7, -(a7)
  003f7a:  3c 2e 00 08            move.w $8(a6), d6
  003f7e:  3e 2e 00 0a            move.w $a(a6), d7
  003f82:  3a 2e 00 0c            move.w $c(a6), d5
  003f86:  60 18                  bra.b $3fa0
  003f88:  06 47 00 0a            addi.w #$a, d7
  003f8c:  4a 46                  tst.w d6
  003f8e:  67 10                  beq.b $3fa0
  003f90:  20 4d                  movea.l a5, a0
  003f92:  20 06                  move.l d6, d0
  003f94:  48 c0                  ext.l d0
  003f96:  e5 88                  lsl.l #$2, d0
  003f98:  d1 c0                  adda.l d0, a0
  003f9a:  7c 00                  moveq #$0, d6
  003f9c:  1c 28 f0 ba            move.b -$f46(a0), d6
  003fa0:  4a 47                  tst.w d7
  003fa2:  6d e4                  blt.b $3f88
  003fa4:  60 18                  bra.b $3fbe
  003fa6:  06 47 ff f6            addi.w #$fff6, d7
  003faa:  4a 46                  tst.w d6
  003fac:  67 10                  beq.b $3fbe
  003fae:  20 4d                  movea.l a5, a0
  003fb0:  20 06                  move.l d6, d0
  003fb2:  48 c0                  ext.l d0
  003fb4:  e5 88                  lsl.l #$2, d0
  003fb6:  d1 c0                  adda.l d0, a0
  003fb8:  7c 00                  moveq #$0, d6
  003fba:  1c 28 f0 bb            move.b -$f45(a0), d6
  003fbe:  0c 47 00 0a            cmpi.w #$a, d7
  003fc2:  6c e2                  bge.b $3fa6
  003fc4:  60 16                  bra.b $3fdc
  003fc6:  56 45                  addq.w #$3, d5
  003fc8:  4a 46                  tst.w d6
  003fca:  67 10                  beq.b $3fdc
  003fcc:  20 4d                  movea.l a5, a0
  003fce:  20 06                  move.l d6, d0
  003fd0:  48 c0                  ext.l d0
  003fd2:  e5 88                  lsl.l #$2, d0
  003fd4:  d1 c0                  adda.l d0, a0
  003fd6:  7c 00                  moveq #$0, d6
  003fd8:  1c 28 f0 bc            move.b -$f44(a0), d6
  003fdc:  4a 45                  tst.w d5
  003fde:  6d e6                  blt.b $3fc6
  003fe0:  60 16                  bra.b $3ff8
  003fe2:  57 45                  subq.w #$3, d5
  003fe4:  4a 46                  tst.w d6
  003fe6:  67 10                  beq.b $3ff8
  003fe8:  20 4d                  movea.l a5, a0
  003fea:  20 06                  move.l d6, d0
  003fec:  48 c0                  ext.l d0
  003fee:  e5 88                  lsl.l #$2, d0
  003ff0:  d1 c0                  adda.l d0, a0
  003ff2:  7c 00                  moveq #$0, d6
  003ff4:  1c 28 f0 bd            move.b -$f43(a0), d6
  003ff8:  0c 45 00 03            cmpi.w #$3, d5
  003ffc:  6c e4                  bge.b $3fe2
  003ffe:  4a 46                  tst.w d6
  004000:  67 24                  beq.b $4026
  004002:  3f 06                  move.w d6, -(a7)
  004004:  4e ad 05 12            jsr $512(a5)
  004008:  20 4d                  movea.l a5, a0
  00400a:  d0 c5                  adda.w d5, a0
  00400c:  d0 c5                  adda.w d5, a0
  00400e:  38 28 b6 46            move.w -$49ba(a0), d4
  004012:  d8 47                  add.w d7, d4
  004014:  20 6d bd 82            movea.l -$427e(a5), a0
  004018:  76 00                  moveq #$0, d3
  00401a:  16 30 40 00            move.b (a0, d4.w), d3
  00401e:  02 43 00 1f            andi.w #$1f, d3
  004022:  54 8f                  addq.l #$2, a7
  004024:  60 04                  bra.b $402a
  004026:  78 00                  moveq #$0, d4
  004028:  76 14                  moveq #$14, d3
  00402a:  3b 46 ba ea            move.w d6, -$4516(a5)
  00402e:  3b 47 ba ec            move.w d7, -$4514(a5)
  004032:  3b 45 ba ee            move.w d5, -$4512(a5)
  004036:  1b 44 ba e9            move.b d4, -$4517(a5)
  00403a:  1b 43 ba e8            move.b d3, -$4518(a5)
  00403e:  10 03                  move.b d3, d0
  004040:  4c df 00 f8            movem.l (a7)+, d3-d7
  004044:  4e 5e                  unlk a6
  004046:  4e 75                  rts 
  004048:  4e 56 00 00            link.w a6, #$0
  00404c:  48 e7 03 00            movem.l d6-d7, -(a7)
  004050:  3e 2e 00 08            move.w $8(a6), d7
  004054:  3c 2e 00 0a            move.w $a(a6), d6
  004058:  4a 47                  tst.w d7
  00405a:  6d 26                  blt.b $4082
  00405c:  0c 47 00 0a            cmpi.w #$a, d7
  004060:  6c 20                  bge.b $4082
  004062:  4a 46                  tst.w d6
  004064:  6c 08                  bge.b $406e
  004066:  70 01                  moveq #$1, d0
  004068:  d0 47                  add.w d7, d0
  00406a:  44 40                  neg.w d0
  00406c:  60 16                  bra.b $4084
  00406e:  0c 46 00 03            cmpi.w #$3, d6
  004072:  6c 0e                  bge.b $4082
  004074:  20 4d                  movea.l a5, a0
  004076:  d0 c6                  adda.w d6, a0
  004078:  d0 c6                  adda.w d6, a0
  00407a:  30 28 b6 46            move.w -$49ba(a0), d0
  00407e:  d0 47                  add.w d7, d0
  004080:  60 02                  bra.b $4084
  004082:  70 1e                  moveq #$1e, d0
  004084:  4c df 00 c0            movem.l (a7)+, d6-d7
  004088:  4e 5e                  unlk a6
  00408a:  4e 75                  rts 
  00408c:  4e 56 00 00            link.w a6, #$0
  004090:  48 e7 03 00            movem.l d6-d7, -(a7)
  004094:  3e 2e 00 08            move.w $8(a6), d7
  004098:  3c 2e 00 0a            move.w $a(a6), d6
  00409c:  4a 47                  tst.w d7
  00409e:  6d 22                  blt.b $40c2
  0040a0:  0c 47 00 0a            cmpi.w #$a, d7
  0040a4:  6c 1c                  bge.b $40c2
  0040a6:  4a 46                  tst.w d6
  0040a8:  6c 04                  bge.b $40ae
  0040aa:  70 1e                  moveq #$1e, d0
  0040ac:  60 16                  bra.b $40c4
  0040ae:  0c 46 00 03            cmpi.w #$3, d6
  0040b2:  6c 0e                  bge.b $40c2
  0040b4:  20 4d                  movea.l a5, a0
  0040b6:  d0 c6                  adda.w d6, a0
  0040b8:  d0 c6                  adda.w d6, a0
  0040ba:  30 28 b6 46            move.w -$49ba(a0), d0
  0040be:  d0 47                  add.w d7, d0
  0040c0:  60 02                  bra.b $40c4
  0040c2:  70 1e                  moveq #$1e, d0
  0040c4:  4c df 00 c0            movem.l (a7)+, d6-d7
  0040c8:  4e 5e                  unlk a6
  0040ca:  4e 75                  rts 
  0040cc:  4e ba 00 1a            jsr $40e8(pc)
  0040d0:  4e ba 00 04            jsr $40d6(pc)
  0040d4:  4e 75                  rts 
  0040d6:  4e ba 00 f8            jsr $41d0(pc)
  0040da:  3f 00                  move.w d0, -(a7)
  0040dc:  4e ba 03 00            jsr $43de(pc)
  0040e0:  1b 40 b9 4a            move.b d0, -$46b6(a5)
  0040e4:  54 8f                  addq.l #$2, a7
  0040e6:  4e 75                  rts 
  0040e8:  2f 07                  move.l d7, -(a7)
  0040ea:  7e 00                  moveq #$0, d7
  0040ec:  1e 2d b9 46            move.b -$46ba(a5), d7
  0040f0:  10 2d b9 51            move.b -$46af(a5), d0
  0040f4:  67 2a                  beq.b $4120
  0040f6:  6b 00 00 d4            bmi.w $41cc
  0040fa:  59 00                  subq.b #$4, d0
  0040fc:  67 3a                  beq.b $4138
  0040fe:  6a 0a                  bpl.b $410a
  004100:  54 00                  addq.b #$2, d0
  004102:  67 34                  beq.b $4138
  004104:  6a 00 00 c6            bpl.w $41cc
  004108:  60 70                  bra.b $417a
  00410a:  04 00 00 14            subi.b #$14, d0
  00410e:  67 10                  beq.b $4120
  004110:  6a 00 00 ba            bpl.w $41cc
  004114:  04 00 00 ef            subi.b #$ef, d0
  004118:  6a 00 00 b2            bpl.w $41cc
  00411c:  60 00 00 9a            bra.w $41b8
  004120:  70 06                  moveq #$6, d0
  004122:  c1 c7                  muls.w d7, d0
  004124:  20 4d                  movea.l a5, a0
  004126:  d1 c0                  adda.l d0, a0
  004128:  2b 68 aa 94 b9 8e      move.l -$556c(a0), -$4672(a5)
  00412e:  3b 68 aa 98 b9 92      move.w -$5568(a0), -$466e(a5)
  004134:  60 00 00 96            bra.w $41cc
  004138:  0c 47 00 66            cmpi.w #$66, d7
  00413c:  6d 20                  blt.b $415e
  00413e:  0c 47 00 6b            cmpi.w #$6b, d7
  004142:  6c 1a                  bge.b $415e
  004144:  70 b1                  moveq #$b1, d0
  004146:  d0 47                  add.w d7, d0
  004148:  c1 fc 00 06            muls.w #$6, d0
  00414c:  20 4d                  movea.l a5, a0
  00414e:  d1 c0                  adda.l d0, a0
  004150:  2b 68 b0 3a b9 8e      move.l -$4fc6(a0), -$4672(a5)
  004156:  3b 68 b0 3e b9 92      move.w -$4fc2(a0), -$466e(a5)
  00415c:  60 6e                  bra.b $41cc
  00415e:  30 07                  move.w d7, d0
  004160:  06 40 ff 6b            addi.w #$ff6b, d0
  004164:  c1 fc 00 06            muls.w #$6, d0
  004168:  20 4d                  movea.l a5, a0
  00416a:  d1 c0                  adda.l d0, a0
  00416c:  2b 68 b0 3a b9 8e      move.l -$4fc6(a0), -$4672(a5)
  004172:  3b 68 b0 3e b9 92      move.w -$4fc2(a0), -$466e(a5)
  004178:  60 52                  bra.b $41cc
  00417a:  0c 47 00 96            cmpi.w #$96, d7
  00417e:  6d 22                  blt.b $41a2
  004180:  0c 47 00 be            cmpi.w #$be, d7
  004184:  6c 1c                  bge.b $41a2
  004186:  30 07                  move.w d7, d0
  004188:  06 40 ff 6b            addi.w #$ff6b, d0
  00418c:  c1 fc 00 06            muls.w #$6, d0
  004190:  20 4d                  movea.l a5, a0
  004192:  d1 c0                  adda.l d0, a0
  004194:  2b 68 b0 3a b9 8e      move.l -$4fc6(a0), -$4672(a5)
  00419a:  3b 68 b0 3e b9 92      move.w -$4fc2(a0), -$466e(a5)
  0041a0:  60 2a                  bra.b $41cc
  0041a2:  70 06                  moveq #$6, d0
  0041a4:  c1 c7                  muls.w d7, d0
  0041a6:  20 4d                  movea.l a5, a0
  0041a8:  d1 c0                  adda.l d0, a0
  0041aa:  2b 68 aa 94 b9 8e      move.l -$556c(a0), -$4672(a5)
  0041b0:  3b 68 aa 98 b9 92      move.w -$5568(a0), -$466e(a5)
  0041b6:  60 14                  bra.b $41cc
  0041b8:  70 06                  moveq #$6, d0
  0041ba:  c1 c7                  muls.w d7, d0
  0041bc:  20 4d                  movea.l a5, a0
  0041be:  d1 c0                  adda.l d0, a0
  0041c0:  2b 68 b1 30 b9 8e      move.l -$4ed0(a0), -$4672(a5)
  0041c6:  3b 68 b1 34 b9 92      move.w -$4ecc(a0), -$466e(a5)
  0041cc:  2e 1f                  move.l (a7)+, d7
  0041ce:  4e 75                  rts 
  0041d0:  2f 07                  move.l d7, -(a7)
  0041d2:  10 2d b9 90            move.b -$4670(a5), d0
  0041d6:  48 80                  ext.w d0
  0041d8:  1e 2d b9 92            move.b -$466e(a5), d7
  0041dc:  48 87                  ext.w d7
  0041de:  02 47 00 1f            andi.w #$1f, d7
  0041e2:  44 47                  neg.w d7
  0041e4:  de 40                  add.w d0, d7
  0041e6:  4a 2d b9 49            tst.b -$46b7(a5)
  0041ea:  6c 0a                  bge.b $41f6
  0041ec:  70 00                  moveq #$0, d0
  0041ee:  10 2d b9 47            move.b -$46b9(a5), d0
  0041f2:  90 47                  sub.w d7, d0
  0041f4:  60 08                  bra.b $41fe
  0041f6:  70 00                  moveq #$0, d0
  0041f8:  10 2d b9 47            move.b -$46b9(a5), d0
  0041fc:  d0 47                  add.w d7, d0
  0041fe:  2e 1f                  move.l (a7)+, d7
  004200:  4e 75                  rts 
  004202:  4e 56 00 00            link.w a6, #$0
  004206:  4a 2d b9 49            tst.b -$46b7(a5)
  00420a:  6c 0c                  bge.b $4218
  00420c:  70 00                  moveq #$0, d0
  00420e:  10 2d b9 47            move.b -$46b9(a5), d0
  004212:  90 6e 00 08            sub.w $8(a6), d0
  004216:  60 0a                  bra.b $4222
  004218:  70 00                  moveq #$0, d0
  00421a:  10 2d b9 47            move.b -$46b9(a5), d0
  00421e:  d0 6e 00 08            add.w $8(a6), d0
  004222:  4e 5e                  unlk a6
  004224:  4e 75                  rts 
  004226:  4e 56 00 00            link.w a6, #$0
  00422a:  4a 2d ba f1            tst.b -$450f(a5)
  00422e:  6c 0a                  bge.b $423a
  004230:  30 2e 00 08            move.w $8(a6), d0
  004234:  91 6d ba f6            sub.w d0, -$450a(a5)
  004238:  60 08                  bra.b $4242
  00423a:  30 2e 00 08            move.w $8(a6), d0
  00423e:  d1 6d ba f6            add.w d0, -$450a(a5)
  004242:  30 2d ba f6            move.w -$450a(a5), d0
  004246:  4e 5e                  unlk a6
  004248:  4e 75                  rts 
  00424a:  48 e7 01 08            movem.l d7/a4, -(a7)
  00424e:  28 6d b9 54            movea.l -$46ac(a5), a4
  004252:  1e 1c                  move.b (a4)+, d7
  004254:  10 07                  move.b d7, d0
  004256:  48 80                  ext.w d0
  004258:  04 40 ff f1            subi.w #$fff1, d0
  00425c:  0c 40 00 0e            cmpi.w #$e, d0
  004260:  62 00 01 50            bhi.w $43b2
  004264:  43 fa 01 5a            lea.l $43c0(pc), a1
  004268:  d0 40                  add.w d0, d0
  00426a:  d2 f1 00 00            adda.w (a1, d0.w), a1
  00426e:  4e d1                  jmp (a1)
  004270:  1e 1c                  move.b (a4)+, d7
  004272:  10 07                  move.b d7, d0
  004274:  48 80                  ext.w d0
  004276:  3f 00                  move.w d0, -(a7)
  004278:  4e ba ff 88            jsr $4202(pc)
  00427c:  1b 40 b9 47            move.b d0, -$46b9(a5)
  004280:  54 8f                  addq.l #$2, a7
  004282:  60 ce                  bra.b $4252
  004284:  1e 1c                  move.b (a4)+, d7
  004286:  df 2d b9 48            add.b d7, -$46b8(a5)
  00428a:  60 c6                  bra.b $4252
  00428c:  10 2d b9 49            move.b -$46b7(a5), d0
  004290:  46 00                  not.b d0
  004292:  1b 40 b9 49            move.b d0, -$46b7(a5)
  004296:  60 ba                  bra.b $4252
  004298:  1e 1c                  move.b (a4)+, d7
  00429a:  4a 6d ba 30            tst.w -$45d0(a5)
  00429e:  67 b2                  beq.b $4252
  0042a0:  70 00                  moveq #$0, d0
  0042a2:  10 07                  move.b d7, d0
  0042a4:  20 4d                  movea.l a5, a0
  0042a6:  e5 88                  lsl.l #$2, d0
  0042a8:  d1 c0                  adda.l d0, a0
  0042aa:  28 68 fc e4            movea.l -$31c(a0), a4
  0042ae:  60 a2                  bra.b $4252
  0042b0:  1e 1c                  move.b (a4)+, d7
  0042b2:  70 00                  moveq #$0, d0
  0042b4:  10 07                  move.b d7, d0
  0042b6:  20 4d                  movea.l a5, a0
  0042b8:  e5 88                  lsl.l #$2, d0
  0042ba:  d1 c0                  adda.l d0, a0
  0042bc:  28 68 fc e4            movea.l -$31c(a0), a4
  0042c0:  60 90                  bra.b $4252
  0042c2:  53 2d b9 4b            subq.b #$1, -$46b5(a5)
  0042c6:  4e ad 04 92            jsr $492(a5)
  0042ca:  60 86                  bra.b $4252
  0042cc:  4e ba 16 66            jsr $5934(pc)
  0042d0:  4e ad 04 92            jsr $492(a5)
  0042d4:  60 00 ff 7c            bra.w $4252
  0042d8:  1e 1c                  move.b (a4)+, d7
  0042da:  1b 47 b9 4c            move.b d7, -$46b4(a5)
  0042de:  60 00 ff 72            bra.w $4252
  0042e2:  1e 1c                  move.b (a4)+, d7
  0042e4:  1b 47 b9 4d            move.b d7, -$46b3(a5)
  0042e8:  1e 1c                  move.b (a4)+, d7
  0042ea:  1b 47 b9 4e            move.b d7, -$46b2(a5)
  0042ee:  60 00 ff 62            bra.w $4252
  0042f2:  3b 7c 00 01 ba 1c      move.w #$1, -$45e4(a5)
  0042f8:  60 00 ff 58            bra.w $4252
  0042fc:  3b 7c ff ff ba 1c      move.w #$ffff, -$45e4(a5)
  004302:  60 00 ff 4e            bra.w $4252
  004306:  1e 1c                  move.b (a4)+, d7
  004308:  10 07                  move.b d7, d0
  00430a:  67 22                  beq.b $432e
  00430c:  6b 00 ff 44            bmi.w $4252
  004310:  57 00                  subq.b #$3, d0
  004312:  67 38                  beq.b $434c
  004314:  6a 06                  bpl.b $431c
  004316:  52 00                  addq.b #$1, d0
  004318:  6a 1e                  bpl.b $4338
  00431a:  60 08                  bra.b $4324
  00431c:  55 00                  subq.b #$2, d0
  00431e:  6a 00 ff 32            bpl.w $4252
  004322:  60 36                  bra.b $435a
  004324:  3f 3c 00 17            move.w #$17, -(a7)
  004328:  4e ba c4 8a            jsr $7b4(pc)
  00432c:  54 8f                  addq.l #$2, a7
  00432e:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  004334:  60 00 ff 1c            bra.w $4252
  004338:  3f 3c 00 08            move.w #$8, -(a7)
  00433c:  4e ba c4 76            jsr $7b4(pc)
  004340:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  004346:  54 8f                  addq.l #$2, a7
  004348:  60 00 ff 08            bra.w $4252
  00434c:  3f 3c 00 12            move.w #$12, -(a7)
  004350:  4e ba c4 62            jsr $7b4(pc)
  004354:  54 8f                  addq.l #$2, a7
  004356:  60 00 fe fa            bra.w $4252
  00435a:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  004360:  67 00 fe f0            beq.w $4252
  004364:  0c 6d 00 04 a9 0c      cmpi.w #$4, -$56f4(a5)
  00436a:  66 0e                  bne.b $437a
  00436c:  3f 3c 00 20            move.w #$20, -(a7)
  004370:  4e ba c4 42            jsr $7b4(pc)
  004374:  54 8f                  addq.l #$2, a7
  004376:  60 00 fe da            bra.w $4252
  00437a:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  004380:  67 00 fe d0            beq.w $4252
  004384:  3f 3c 00 29            move.w #$29, -(a7)
  004388:  4e ba c4 2a            jsr $7b4(pc)
  00438c:  54 8f                  addq.l #$2, a7
  00438e:  60 00 fe c2            bra.w $4252
  004392:  70 01                  moveq #$1, d0
  004394:  d0 6d a9 0c            add.w -$56f4(a5), d0
  004398:  3b 40 ba 38            move.w d0, -$45c8(a5)
  00439c:  60 00 fe b4            bra.w $4252
  0043a0:  1e 1c                  move.b (a4)+, d7
  0043a2:  0c 07 00 01            cmpi.b #$1, d7
  0043a6:  66 00 fe aa            bne.w $4252
  0043aa:  4e ba 11 0a            jsr $54b6(pc)
  0043ae:  60 00 fe a2            bra.w $4252
  0043b2:  1b 47 b9 46            move.b d7, -$46ba(a5)
  0043b6:  2b 4c b9 54            move.l a4, -$46ac(a5)
  0043ba:  4c df 10 80            movem.l (a7)+, d7/a4
  0043be:  4e 75                  rts 
  0043c0:  ff d2                  dc.w $ffd2
  0043c2:  ff 46                  dc.w $ff46
  0043c4:  ff e0                  dc.w $ffe0
  0043c6:  ff 3c                  dc.w $ff3c
  0043c8:  ff 32                  dc.w $ff32
  0043ca:  fe 92                  dc.w $fe92
  0043cc:  fe d8                  dc.w $fed8
  0043ce:  ff 22                  dc.w $ff22
  0043d0:  ff 18                  dc.w $ff18
  0043d2:  fe c4                  dc.w $fec4
  0043d4:  fe b0                  dc.w $feb0
  0043d6:  ff 0c                  dc.w $ff0c
  0043d8:  ff 02                  dc.w $ff02
  0043da:  fe cc                  dc.w $fecc
  0043dc:  fe f0                  dc.w $fef0
  0043de:  4e 56 00 00            link.w a6, #$0
  0043e2:  2f 07                  move.l d7, -(a7)
  0043e4:  3e 2e 00 08            move.w $8(a6), d7
  0043e8:  5f 47                  subq.w #$7, d7
  0043ea:  20 4d                  movea.l a5, a0
  0043ec:  d0 c7                  adda.w d7, a0
  0043ee:  1b 68 b7 78 bd 7e      move.b -$4888(a0), -$4282(a5)
  0043f4:  20 4d                  movea.l a5, a0
  0043f6:  d0 c7                  adda.w d7, a0
  0043f8:  10 28 b6 78            move.b -$4988(a0), d0
  0043fc:  48 80                  ext.w d0
  0043fe:  2e 1f                  move.l (a7)+, d7
  004400:  4e 5e                  unlk a6
  004402:  4e 75                  rts 
  004404:  4e 56 00 00            link.w a6, #$0
  004408:  2f 07                  move.l d7, -(a7)
  00440a:  3e 2e 00 08            move.w $8(a6), d7
  00440e:  20 4d                  movea.l a5, a0
  004410:  d0 c7                  adda.w d7, a0
  004412:  1b 68 b7 78 bd 7e      move.b -$4888(a0), -$4282(a5)
  004418:  20 4d                  movea.l a5, a0
  00441a:  d0 c7                  adda.w d7, a0
  00441c:  10 28 b6 78            move.b -$4988(a0), d0
  004420:  48 80                  ext.w d0
  004422:  2e 1f                  move.l (a7)+, d7
  004424:  4e 5e                  unlk a6
  004426:  4e 75                  rts 
  004428:  4e 56 00 00            link.w a6, #$0
  00442c:  2f 07                  move.l d7, -(a7)
  00442e:  3e 2e 00 08            move.w $8(a6), d7
  004432:  be 6d b6 76            cmp.w -$498a(a5), d7
  004436:  6d 04                  blt.b $443c
  004438:  70 03                  moveq #$3, d0
  00443a:  60 20                  bra.b $445c
  00443c:  be 6d b6 74            cmp.w -$498c(a5), d7
  004440:  6d 04                  blt.b $4446
  004442:  70 02                  moveq #$2, d0
  004444:  60 16                  bra.b $445c
  004446:  be 6d b6 72            cmp.w -$498e(a5), d7
  00444a:  6d 04                  blt.b $4450
  00444c:  70 01                  moveq #$1, d0
  00444e:  60 0c                  bra.b $445c
  004450:  be 6d b6 70            cmp.w -$4990(a5), d7
  004454:  6d 04                  blt.b $445a
  004456:  70 00                  moveq #$0, d0
  004458:  60 02                  bra.b $445c
  00445a:  70 ff                  moveq #$ff, d0
  00445c:  2e 1f                  move.l (a7)+, d7
  00445e:  4e 5e                  unlk a6
  004460:  4e 75                  rts 
  004462:  4e 56 00 00            link.w a6, #$0
  004466:  70 3c                  moveq #$3c, d0
  004468:  d0 6e 00 08            add.w $8(a6), d0
  00446c:  48 c0                  ext.l d0
  00446e:  81 fc 00 3f            divs.w #$3f, d0
  004472:  48 c0                  ext.l d0
  004474:  81 fc 00 04            divs.w #$4, d0
  004478:  48 40                  swap d0
  00447a:  53 40                  subq.w #$1, d0
  00447c:  4e 5e                  unlk a6
  00447e:  4e 75                  rts 
  004480:  41 ed b9 46            lea.l -$46ba(a5), a0
  004484:  43 ed b9 6a            lea.l -$4696(a5), a1
  004488:  20 d9                  move.l (a1)+, (a0)+
  00448a:  20 d9                  move.l (a1)+, (a0)+
  00448c:  20 d9                  move.l (a1)+, (a0)+
  00448e:  20 d9                  move.l (a1)+, (a0)+
  004490:  30 d9                  move.w (a1)+, (a0)+
  004492:  4e 75                  rts 
  004494:  41 ed b9 6a            lea.l -$4696(a5), a0
  004498:  43 ed b9 46            lea.l -$46ba(a5), a1
  00449c:  20 d9                  move.l (a1)+, (a0)+
  00449e:  20 d9                  move.l (a1)+, (a0)+
  0044a0:  20 d9                  move.l (a1)+, (a0)+
  0044a2:  20 d9                  move.l (a1)+, (a0)+
  0044a4:  30 d9                  move.w (a1)+, (a0)+
  0044a6:  4e 75                  rts 
  0044a8:  41 ed b9 46            lea.l -$46ba(a5), a0
  0044ac:  43 ed b9 7c            lea.l -$4684(a5), a1
  0044b0:  20 d9                  move.l (a1)+, (a0)+
  0044b2:  20 d9                  move.l (a1)+, (a0)+
  0044b4:  20 d9                  move.l (a1)+, (a0)+
  0044b6:  20 d9                  move.l (a1)+, (a0)+
  0044b8:  30 d9                  move.w (a1)+, (a0)+
  0044ba:  4e 75                  rts 
  0044bc:  41 ed b9 7c            lea.l -$4684(a5), a0
  0044c0:  43 ed b9 46            lea.l -$46ba(a5), a1
  0044c4:  20 d9                  move.l (a1)+, (a0)+
  0044c6:  20 d9                  move.l (a1)+, (a0)+
  0044c8:  20 d9                  move.l (a1)+, (a0)+
  0044ca:  20 d9                  move.l (a1)+, (a0)+
  0044cc:  30 d9                  move.w (a1)+, (a0)+
  0044ce:  4e 75                  rts 
  0044d0:  41 ed b9 46            lea.l -$46ba(a5), a0
  0044d4:  43 ed b9 6a            lea.l -$4696(a5), a1
  0044d8:  20 d9                  move.l (a1)+, (a0)+
  0044da:  20 d9                  move.l (a1)+, (a0)+
  0044dc:  20 d9                  move.l (a1)+, (a0)+
  0044de:  20 d9                  move.l (a1)+, (a0)+
  0044e0:  30 d9                  move.w (a1)+, (a0)+
  0044e2:  41 ed b9 58            lea.l -$46a8(a5), a0
  0044e6:  43 ed b9 7c            lea.l -$4684(a5), a1
  0044ea:  20 d9                  move.l (a1)+, (a0)+
  0044ec:  20 d9                  move.l (a1)+, (a0)+
  0044ee:  20 d9                  move.l (a1)+, (a0)+
  0044f0:  20 d9                  move.l (a1)+, (a0)+
  0044f2:  30 d9                  move.w (a1)+, (a0)+
  0044f4:  4e 75                  rts 
  0044f6:  41 ed b9 6a            lea.l -$4696(a5), a0
  0044fa:  43 ed b9 46            lea.l -$46ba(a5), a1
  0044fe:  20 d9                  move.l (a1)+, (a0)+
  004500:  20 d9                  move.l (a1)+, (a0)+
  004502:  20 d9                  move.l (a1)+, (a0)+
  004504:  20 d9                  move.l (a1)+, (a0)+
  004506:  30 d9                  move.w (a1)+, (a0)+
  004508:  41 ed b9 7c            lea.l -$4684(a5), a0
  00450c:  43 ed b9 58            lea.l -$46a8(a5), a1
  004510:  20 d9                  move.l (a1)+, (a0)+
  004512:  20 d9                  move.l (a1)+, (a0)+
  004514:  20 d9                  move.l (a1)+, (a0)+
  004516:  20 d9                  move.l (a1)+, (a0)+
  004518:  30 d9                  move.w (a1)+, (a0)+
  00451a:  4e 75                  rts 
  00451c:  41 ed b9 46            lea.l -$46ba(a5), a0
  004520:  43 ed b9 7c            lea.l -$4684(a5), a1
  004524:  20 d9                  move.l (a1)+, (a0)+
  004526:  20 d9                  move.l (a1)+, (a0)+
  004528:  20 d9                  move.l (a1)+, (a0)+
  00452a:  20 d9                  move.l (a1)+, (a0)+
  00452c:  30 d9                  move.w (a1)+, (a0)+
  00452e:  41 ed b9 58            lea.l -$46a8(a5), a0
  004532:  43 ed b9 6a            lea.l -$4696(a5), a1
  004536:  20 d9                  move.l (a1)+, (a0)+
  004538:  20 d9                  move.l (a1)+, (a0)+
  00453a:  20 d9                  move.l (a1)+, (a0)+
  00453c:  20 d9                  move.l (a1)+, (a0)+
  00453e:  30 d9                  move.w (a1)+, (a0)+
  004540:  4e 75                  rts 
  004542:  41 ed b9 7c            lea.l -$4684(a5), a0
  004546:  43 ed b9 46            lea.l -$46ba(a5), a1
  00454a:  20 d9                  move.l (a1)+, (a0)+
  00454c:  20 d9                  move.l (a1)+, (a0)+
  00454e:  20 d9                  move.l (a1)+, (a0)+
  004550:  20 d9                  move.l (a1)+, (a0)+
  004552:  30 d9                  move.w (a1)+, (a0)+
  004554:  41 ed b9 6a            lea.l -$4696(a5), a0
  004558:  43 ed b9 58            lea.l -$46a8(a5), a1
  00455c:  20 d9                  move.l (a1)+, (a0)+
  00455e:  20 d9                  move.l (a1)+, (a0)+
  004560:  20 d9                  move.l (a1)+, (a0)+
  004562:  20 d9                  move.l (a1)+, (a0)+
  004564:  30 d9                  move.w (a1)+, (a0)+
  004566:  4e 75                  rts 
  004568:  30 2d a5 cc            move.w -$5a34(a5), d0
  00456c:  3b 40 ba fe            move.w d0, -$4502(a5)
  004570:  3b 40 bd 76            move.w d0, -$428a(a5)
  004574:  3b 40 bd 74            move.w d0, -$428c(a5)
  004578:  3b 6d a5 d0 bb 00      move.w -$5a30(a5), -$4500(a5)
  00457e:  3b 6d a5 ce bb 02      move.w -$5a32(a5), -$44fe(a5)
  004584:  32 2d a5 d2            move.w -$5a2e(a5), d1
  004588:  3b 41 bb 04            move.w d1, -$44fc(a5)
  00458c:  3b 41 bd 78            move.w d1, -$4288(a5)
  004590:  42 2d aa 36            clr.b -$55ca(a5)
  004594:  42 2d aa 35            clr.b -$55cb(a5)
  004598:  4e 75                  rts 
  00459a:  0c 2d 00 04 b9 4c      cmpi.b #$4, -$46b4(a5)
  0045a0:  66 2c                  bne.b $45ce
  0045a2:  4a 6d ba 30            tst.w -$45d0(a5)
  0045a6:  67 14                  beq.b $45bc
  0045a8:  52 2d b9 4e            addq.b #$1, -$46b2(a5)
  0045ac:  0c 2d 00 04 b9 4e      cmpi.b #$4, -$46b2(a5)
  0045b2:  6f 1a                  ble.b $45ce
  0045b4:  1b 7c 00 04 b9 4e      move.b #$4, -$46b2(a5)
  0045ba:  60 12                  bra.b $45ce
  0045bc:  56 2d b9 4e            addq.b #$3, -$46b2(a5)
  0045c0:  0c 2d 00 21 b9 4e      cmpi.b #$21, -$46b2(a5)
  0045c6:  6f 06                  ble.b $45ce
  0045c8:  1b 7c 00 21 b9 4e      move.b #$21, -$46b2(a5)
  0045ce:  4e 75                  rts 
  0045d0:  10 2d b9 4e            move.b -$46b2(a5), d0
  0045d4:  d1 2d b9 48            add.b d0, -$46b8(a5)
  0045d8:  0c 2d 00 04 b9 4c      cmpi.b #$4, -$46b4(a5)
  0045de:  66 16                  bne.b $45f6
  0045e0:  10 2d b9 4d            move.b -$46b3(a5), d0
  0045e4:  48 80                  ext.w d0
  0045e6:  3f 00                  move.w d0, -(a7)
  0045e8:  4e ba fc 18            jsr $4202(pc)
  0045ec:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0045f0:  4e ba fa da            jsr $40cc(pc)
  0045f4:  54 8f                  addq.l #$2, a7
  0045f6:  4e 75                  rts 
  0045f8:  48 e7 03 00            movem.l d6-d7, -(a7)
  0045fc:  1e 2d b9 4c            move.b -$46b4(a5), d7
  004600:  48 87                  ext.w d7
  004602:  7c 00                  moveq #$0, d6
  004604:  1c 2d b9 46            move.b -$46ba(a5), d6
  004608:  0c 47 00 06            cmpi.w #$6, d7
  00460c:  67 40                  beq.b $464e
  00460e:  0c 47 00 05            cmpi.w #$5, d7
  004612:  66 0c                  bne.b $4620
  004614:  0c 46 00 6d            cmpi.w #$6d, d6
  004618:  66 34                  bne.b $464e
  00461a:  4e ba 02 26            jsr $4842(pc)
  00461e:  60 2e                  bra.b $464e
  004620:  0c 47 00 04            cmpi.w #$4, d7
  004624:  66 06                  bne.b $462c
  004626:  4e ad 05 5a            jsr $55a(a5)
  00462a:  60 22                  bra.b $464e
  00462c:  0c 47 00 03            cmpi.w #$3, d7
  004630:  66 12                  bne.b $4644
  004632:  0c 46 00 66            cmpi.w #$66, d6
  004636:  6d 16                  blt.b $464e
  004638:  0c 46 00 6a            cmpi.w #$6a, d6
  00463c:  6c 10                  bge.b $464e
  00463e:  4e ba 03 ea            jsr $4a2a(pc)
  004642:  60 0a                  bra.b $464e
  004644:  0c 47 00 02            cmpi.w #$2, d7
  004648:  67 04                  beq.b $464e
  00464a:  4e ba 01 f6            jsr $4842(pc)
  00464e:  4c df 00 c0            movem.l (a7)+, d6-d7
  004652:  4e 75                  rts 
  004654:  4e 56 00 00            link.w a6, #$0
  004658:  2f 07                  move.l d7, -(a7)
  00465a:  3e 2e 00 08            move.w $8(a6), d7
  00465e:  4a 47                  tst.w d7
  004660:  67 2a                  beq.b $468c
  004662:  0c 47 00 09            cmpi.w #$9, d7
  004666:  67 24                  beq.b $468c
  004668:  0c 47 00 0c            cmpi.w #$c, d7
  00466c:  67 1e                  beq.b $468c
  00466e:  0c 47 00 14            cmpi.w #$14, d7
  004672:  67 18                  beq.b $468c
  004674:  0c 47 00 1a            cmpi.w #$1a, d7
  004678:  67 12                  beq.b $468c
  00467a:  0c 47 00 1b            cmpi.w #$1b, d7
  00467e:  67 0c                  beq.b $468c
  004680:  0c 47 00 1c            cmpi.w #$1c, d7
  004684:  67 06                  beq.b $468c
  004686:  0c 47 00 1d            cmpi.w #$1d, d7
  00468a:  66 04                  bne.b $4690
  00468c:  70 00                  moveq #$0, d0
  00468e:  60 02                  bra.b $4692
  004690:  70 01                  moveq #$1, d0
  004692:  2e 1f                  move.l (a7)+, d7
  004694:  4e 5e                  unlk a6
  004696:  4e 75                  rts 
  004698:  48 e7 03 00            movem.l d6-d7, -(a7)
  00469c:  7e 00                  moveq #$0, d7
  00469e:  1e 2d b9 46            move.b -$46ba(a5), d7
  0046a2:  10 2d b9 4b            move.b -$46b5(a5), d0
  0046a6:  48 80                  ext.w d0
  0046a8:  3f 00                  move.w d0, -(a7)
  0046aa:  10 2d b9 4a            move.b -$46b6(a5), d0
  0046ae:  48 80                  ext.w d0
  0046b0:  3f 00                  move.w d0, -(a7)
  0046b2:  10 2d b9 4f            move.b -$46b1(a5), d0
  0046b6:  48 80                  ext.w d0
  0046b8:  3f 00                  move.w d0, -(a7)
  0046ba:  4e ba f8 b6            jsr $3f72(pc)
  0046be:  72 00                  moveq #$0, d1
  0046c0:  12 00                  move.b d0, d1
  0046c2:  55 41                  subq.w #$2, d1
  0046c4:  5c 8f                  addq.l #$6, a7
  0046c6:  66 38                  bne.b $4700
  0046c8:  4e ad 04 b2            jsr $4b2(a5)
  0046cc:  3c 00                  move.w d0, d6
  0046ce:  0c 46 00 02            cmpi.w #$2, d6
  0046d2:  6d 18                  blt.b $46ec
  0046d4:  0c 47 00 07            cmpi.w #$7, d7
  0046d8:  6d 06                  blt.b $46e0
  0046da:  0c 47 00 0f            cmpi.w #$f, d7
  0046de:  6d 1c                  blt.b $46fc
  0046e0:  0c 47 00 22            cmpi.w #$22, d7
  0046e4:  6d 06                  blt.b $46ec
  0046e6:  0c 47 00 28            cmpi.w #$28, d7
  0046ea:  6d 10                  blt.b $46fc
  0046ec:  0c 47 00 2b            cmpi.w #$2b, d7
  0046f0:  67 06                  beq.b $46f8
  0046f2:  0c 47 00 1a            cmpi.w #$1a, d7
  0046f6:  66 08                  bne.b $4700
  0046f8:  4a 46                  tst.w d6
  0046fa:  67 04                  beq.b $4700
  0046fc:  4e ad 05 62            jsr $562(a5)
  004700:  4c df 00 c0            movem.l (a7)+, d6-d7
  004704:  4e 75                  rts 
  004706:  4e 56 00 00            link.w a6, #$0
  00470a:  2f 07                  move.l d7, -(a7)
  00470c:  3e 2e 00 08            move.w $8(a6), d7
  004710:  4a 2d b9 51            tst.b -$46af(a5)
  004714:  66 24                  bne.b $473a
  004716:  be 6d ba 4a            cmp.w -$45b6(a5), d7
  00471a:  6d 12                  blt.b $472e
  00471c:  30 2d ba 4a            move.w -$45b6(a5), d0
  004720:  44 40                  neg.w d0
  004722:  3b 40 ba 50            move.w d0, -$45b0(a5)
  004726:  52 6d 96 36            addq.w #$1, -$69ca(a5)
  00472a:  70 01                  moveq #$1, d0
  00472c:  60 2e                  bra.b $475c
  00472e:  32 07                  move.w d7, d1
  004730:  44 41                  neg.w d1
  004732:  3b 41 ba 50            move.w d1, -$45b0(a5)
  004736:  70 00                  moveq #$0, d0
  004738:  60 22                  bra.b $475c
  00473a:  be 6d ba 4c            cmp.w -$45b4(a5), d7
  00473e:  6d 12                  blt.b $4752
  004740:  30 2d ba 4c            move.w -$45b4(a5), d0
  004744:  44 40                  neg.w d0
  004746:  3b 40 ba 52            move.w d0, -$45ae(a5)
  00474a:  52 6d 96 34            addq.w #$1, -$69cc(a5)
  00474e:  70 01                  moveq #$1, d0
  004750:  60 0a                  bra.b $475c
  004752:  32 07                  move.w d7, d1
  004754:  44 41                  neg.w d1
  004756:  3b 41 ba 52            move.w d1, -$45ae(a5)
  00475a:  70 00                  moveq #$0, d0
  00475c:  2e 1f                  move.l (a7)+, d7
  00475e:  4e 5e                  unlk a6
  004760:  4e 75                  rts 
  004762:  10 2d b9 4b            move.b -$46b5(a5), d0
  004766:  48 80                  ext.w d0
  004768:  3f 00                  move.w d0, -(a7)
  00476a:  10 2d b9 4a            move.b -$46b6(a5), d0
  00476e:  48 80                  ext.w d0
  004770:  3f 00                  move.w d0, -(a7)
  004772:  10 2d b9 4f            move.b -$46b1(a5), d0
  004776:  48 80                  ext.w d0
  004778:  3f 00                  move.w d0, -(a7)
  00477a:  4e ba f7 f6            jsr $3f72(pc)
  00477e:  5c 8f                  addq.l #$6, a7
  004780:  4e 75                  rts 
  004782:  3b 6d ba fa ba d6      move.w -$4506(a5), -$452a(a5)
  004788:  3b 6d ba fc ba d4      move.w -$4504(a5), -$452c(a5)
  00478e:  30 2d ba f6            move.w -$450a(a5), d0
  004792:  48 c0                  ext.l d0
  004794:  81 fc 00 02            divs.w #$2, d0
  004798:  06 40 00 3a            addi.w #$3a, d0
  00479c:  3b 40 ba dc            move.w d0, -$4524(a5)
  0047a0:  4a 2d b9 49            tst.b -$46b7(a5)
  0047a4:  6d 08                  blt.b $47ae
  0047a6:  30 2d ba d6            move.w -$452a(a5), d0
  0047aa:  91 6d ba dc            sub.w d0, -$4524(a5)
  0047ae:  3b 6d ba dc ba d8      move.w -$4524(a5), -$4528(a5)
  0047b4:  30 2d ba dc            move.w -$4524(a5), d0
  0047b8:  d0 6d ba d6            add.w -$452a(a5), d0
  0047bc:  3b 40 ba de            move.w d0, -$4522(a5)
  0047c0:  3b 40 ba da            move.w d0, -$4526(a5)
  0047c4:  32 2d ba f8            move.w -$4508(a5), d1
  0047c8:  92 6d ba d4            sub.w -$452c(a5), d1
  0047cc:  52 41                  addq.w #$1, d1
  0047ce:  3b 41 ba e0            move.w d1, -$4520(a5)
  0047d2:  0c 41 00 c0            cmpi.w #$c0, d1
  0047d6:  6d 04                  blt.b $47dc
  0047d8:  42 6d ba e0            clr.w -$4520(a5)
  0047dc:  3f 2d ba e0            move.w -$4520(a5), -(a7)
  0047e0:  4e ba fc 80            jsr $4462(pc)
  0047e4:  3b 40 ba ca            move.w d0, -$4536(a5)
  0047e8:  3e ad ba f8            move.w -$4508(a5), (a7)
  0047ec:  4e ba fc 74            jsr $4462(pc)
  0047f0:  3b 40 ba cc            move.w d0, -$4534(a5)
  0047f4:  4a 40                  tst.w d0
  0047f6:  54 8f                  addq.l #$2, a7
  0047f8:  6c 06                  bge.b $4800
  0047fa:  3b 7c 00 03 ba cc      move.w #$3, -$4534(a5)
  004800:  3f 2d ba dc            move.w -$4524(a5), -(a7)
  004804:  4e ba fb fe            jsr $4404(pc)
  004808:  3b 40 ba c6            move.w d0, -$453a(a5)
  00480c:  4a 40                  tst.w d0
  00480e:  54 8f                  addq.l #$2, a7
  004810:  6c 04                  bge.b $4816
  004812:  42 6d ba c6            clr.w -$453a(a5)
  004816:  3f 2d ba de            move.w -$4522(a5), -(a7)
  00481a:  4e ba fb e8            jsr $4404(pc)
  00481e:  3b 40 ba c8            move.w d0, -$4538(a5)
  004822:  0c 40 00 0a            cmpi.w #$a, d0
  004826:  54 8f                  addq.l #$2, a7
  004828:  6d 06                  blt.b $4830
  00482a:  3b 7c 00 09 ba c8      move.w #$9, -$4538(a5)
  004830:  08 2d 00 05 b9 92      btst.b #$5, -$466e(a5)
  004836:  67 08                  beq.b $4840
  004838:  58 6d ba d8            addq.w #$4, -$4528(a5)
  00483c:  59 6d ba da            subq.w #$4, -$4526(a5)
  004840:  4e 75                  rts 
  004842:  08 2d 00 06 b9 92      btst.b #$6, -$466e(a5)
  004848:  67 00 00 86            beq.w $48d0
  00484c:  4e ba ff 14            jsr $4762(pc)
  004850:  72 00                  moveq #$0, d1
  004852:  12 00                  move.b d0, d1
  004854:  0c 41 00 14            cmpi.w #$14, d1
  004858:  66 04                  bne.b $485e
  00485a:  4e ba 02 86            jsr $4ae2(pc)
  00485e:  70 00                  moveq #$0, d0
  004860:  10 2d ba e8            move.b -$4518(a5), d0
  004864:  3f 00                  move.w d0, -(a7)
  004866:  4e ba fd ec            jsr $4654(pc)
  00486a:  4a 00                  tst.b d0
  00486c:  54 8f                  addq.l #$2, a7
  00486e:  66 60                  bne.b $48d0
  004870:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  004876:  66 54                  bne.b $48cc
  004878:  4a 6d ba 8e            tst.w -$4572(a5)
  00487c:  6c 4e                  bge.b $48cc
  00487e:  4a 2d b9 4b            tst.b -$46b5(a5)
  004882:  66 48                  bne.b $48cc
  004884:  0c 2d 00 02 b9 4f      cmpi.b #$2, -$46b1(a5)
  00488a:  67 10                  beq.b $489c
  00488c:  0c 2d 00 0d b9 4f      cmpi.b #$d, -$46b1(a5)
  004892:  66 38                  bne.b $48cc
  004894:  0c 6d 00 06 ba ec      cmpi.w #$6, -$4514(a5)
  00489a:  6d 30                  blt.b $48cc
  00489c:  70 00                  moveq #$0, d0
  00489e:  10 2d ba e9            move.b -$4517(a5), d0
  0048a2:  d0 ad bd 82            add.l -$427e(a5), d0
  0048a6:  20 40                  movea.l d0, a0
  0048a8:  10 bc 00 01            move.b #$1, (a0)
  0048ac:  70 00                  moveq #$0, d0
  0048ae:  10 2d ba e9            move.b -$4517(a5), d0
  0048b2:  3f 00                  move.w d0, -(a7)
  0048b4:  4e ad 04 42            jsr $442(a5)
  0048b8:  52 2d ba e9            addq.b #$1, -$4517(a5)
  0048bc:  70 00                  moveq #$0, d0
  0048be:  10 2d ba e9            move.b -$4517(a5), d0
  0048c2:  3e 80                  move.w d0, (a7)
  0048c4:  4e ad 04 42            jsr $442(a5)
  0048c8:  54 8f                  addq.l #$2, a7
  0048ca:  60 04                  bra.b $48d0
  0048cc:  4e ba 00 04            jsr $48d2(pc)
  0048d0:  4e 75                  rts 
  0048d2:  2f 07                  move.l d7, -(a7)
  0048d4:  7e 00                  moveq #$0, d7
  0048d6:  1e 2d b9 46            move.b -$46ba(a5), d7
  0048da:  42 2d b9 52            clr.b -$46ae(a5)
  0048de:  4e ba 10 54            jsr $5934(pc)
  0048e2:  4e ad 04 92            jsr $492(a5)
  0048e6:  1b 47 ba bc            move.b d7, -$4544(a5)
  0048ea:  0c 2d 00 09 ba bc      cmpi.b #$9, -$4544(a5)
  0048f0:  66 06                  bne.b $48f8
  0048f2:  7e 07                  moveq #$7, d7
  0048f4:  60 00 00 cc            bra.w $49c2
  0048f8:  0c 47 00 0d            cmpi.w #$d, d7
  0048fc:  66 06                  bne.b $4904
  0048fe:  7e 13                  moveq #$13, d7
  004900:  60 00 00 c0            bra.w $49c2
  004904:  0c 47 00 1a            cmpi.w #$1a, d7
  004908:  66 06                  bne.b $4910
  00490a:  7e 12                  moveq #$12, d7
  00490c:  60 00 00 b4            bra.w $49c2
  004910:  0c 47 00 2c            cmpi.w #$2c, d7
  004914:  66 06                  bne.b $491c
  004916:  7e 15                  moveq #$15, d7
  004918:  60 00 00 a8            bra.w $49c2
  00491c:  0c 47 00 51            cmpi.w #$51, d7
  004920:  6d 1e                  blt.b $4940
  004922:  0c 47 00 56            cmpi.w #$56, d7
  004926:  6c 18                  bge.b $4940
  004928:  7e 13                  moveq #$13, d7
  00492a:  3f 3c 00 05            move.w #$5, -(a7)
  00492e:  4e ba f8 d2            jsr $4202(pc)
  004932:  1b 40 b9 47            move.b d0, -$46b9(a5)
  004936:  4e ba f7 94            jsr $40cc(pc)
  00493a:  54 8f                  addq.l #$2, a7
  00493c:  60 00 00 84            bra.w $49c2
  004940:  0c 47 00 96            cmpi.w #$96, d7
  004944:  6d 7a                  blt.b $49c0
  004946:  0c 47 00 b4            cmpi.w #$b4, d7
  00494a:  6c 74                  bge.b $49c0
  00494c:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  004952:  66 46                  bne.b $499a
  004954:  0c 2d 00 03 b9 4b      cmpi.b #$3, -$46b5(a5)
  00495a:  66 10                  bne.b $496c
  00495c:  0c 2d 00 0a b9 4a      cmpi.b #$a, -$46b6(a5)
  004962:  66 08                  bne.b $496c
  004964:  4e ba 0d 40            jsr $56a6(pc)
  004968:  60 00 00 bc            bra.w $4a26
  00496c:  4a 2d b9 4d            tst.b -$46b3(a5)
  004970:  6c 20                  bge.b $4992
  004972:  7e 52                  moveq #$52, d7
  004974:  4a 2d b9 49            tst.b -$46b7(a5)
  004978:  6c 48                  bge.b $49c2
  00497a:  4e ba 02 42            jsr $4bbe(pc)
  00497e:  5f 40                  subq.w #$7, d0
  004980:  6e 40                  bgt.b $49c2
  004982:  3f 3c ff fb            move.w #$fffb, -(a7)
  004986:  4e ba f8 7a            jsr $4202(pc)
  00498a:  1b 40 b9 47            move.b d0, -$46b9(a5)
  00498e:  54 8f                  addq.l #$2, a7
  004990:  60 30                  bra.b $49c2
  004992:  42 6d ba 34            clr.w -$45cc(a5)
  004996:  7e 53                  moveq #$53, d7
  004998:  60 28                  bra.b $49c2
  00499a:  3b 7c 00 01 ba 34      move.w #$1, -$45cc(a5)
  0049a0:  4a 2d b9 49            tst.b -$46b7(a5)
  0049a4:  6c 16                  bge.b $49bc
  0049a6:  4e ba 02 16            jsr $4bbe(pc)
  0049aa:  5f 40                  subq.w #$7, d0
  0049ac:  6e 0e                  bgt.b $49bc
  0049ae:  3f 3c ff fb            move.w #$fffb, -(a7)
  0049b2:  4e ba f8 4e            jsr $4202(pc)
  0049b6:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0049ba:  54 8f                  addq.l #$2, a7
  0049bc:  7e 51                  moveq #$51, d7
  0049be:  60 02                  bra.b $49c2
  0049c0:  7e 07                  moveq #$7, d7
  0049c2:  3f 07                  move.w d7, -(a7)
  0049c4:  4e ad 05 52            jsr $552(a5)
  0049c8:  4e ba f8 80            jsr $424a(pc)
  0049cc:  4e ba f6 fe            jsr $40cc(pc)
  0049d0:  4e ba fd 90            jsr $4762(pc)
  0049d4:  72 00                  moveq #$0, d1
  0049d6:  12 00                  move.b d0, d1
  0049d8:  0c 41 00 14            cmpi.w #$14, d1
  0049dc:  54 8f                  addq.l #$2, a7
  0049de:  66 06                  bne.b $49e6
  0049e0:  4e ba 01 00            jsr $4ae2(pc)
  0049e4:  60 40                  bra.b $4a26
  0049e6:  4e ba 01 36            jsr $4b1e(pc)
  0049ea:  72 00                  moveq #$0, d1
  0049ec:  12 00                  move.b d0, d1
  0049ee:  0c 41 00 14            cmpi.w #$14, d1
  0049f2:  66 32                  bne.b $4a26
  0049f4:  0c 2d 00 2c ba bc      cmpi.b #$2c, -$4544(a5)
  0049fa:  66 08                  bne.b $4a04
  0049fc:  4e ba 01 c0            jsr $4bbe(pc)
  004a00:  5d 40                  subq.w #$6, d0
  004a02:  6d 10                  blt.b $4a14
  004a04:  3f 3c ff ff            move.w #$ffff, -(a7)
  004a08:  4e ba f7 f8            jsr $4202(pc)
  004a0c:  1b 40 b9 47            move.b d0, -$46b9(a5)
  004a10:  54 8f                  addq.l #$2, a7
  004a12:  60 0e                  bra.b $4a22
  004a14:  3f 3c 00 68            move.w #$68, -(a7)
  004a18:  4e ad 05 52            jsr $552(a5)
  004a1c:  4e ba f8 2c            jsr $424a(pc)
  004a20:  54 8f                  addq.l #$2, a7
  004a22:  4e ba f6 a8            jsr $40cc(pc)
  004a26:  2e 1f                  move.l (a7)+, d7
  004a28:  4e 75                  rts 
  004a2a:  2f 07                  move.l d7, -(a7)
  004a2c:  7e 00                  moveq #$0, d7
  004a2e:  1e 2d b9 48            move.b -$46b8(a5), d7
  004a32:  4a 2d ba bb            tst.b -$4545(a5)
  004a36:  6c 00 00 94            bge.w $4acc
  004a3a:  0c 2d 00 20 b9 4e      cmpi.b #$20, -$46b2(a5)
  004a40:  6c 00 00 8a            bge.w $4acc
  004a44:  4a 2d b9 53            tst.b -$46ad(a5)
  004a48:  6c 00 00 82            bge.w $4acc
  004a4c:  10 2d b9 4b            move.b -$46b5(a5), d0
  004a50:  48 80                  ext.w d0
  004a52:  20 4d                  movea.l a5, a0
  004a54:  d0 c0                  adda.w d0, a0
  004a56:  d0 c0                  adda.w d0, a0
  004a58:  70 19                  moveq #$19, d0
  004a5a:  d0 47                  add.w d7, d0
  004a5c:  b0 68 b6 70            cmp.w -$4990(a0), d0
  004a60:  6d 6a                  blt.b $4acc
  004a62:  7e 00                  moveq #$0, d7
  004a64:  1e 2d b9 47            move.b -$46b9(a5), d7
  004a68:  3f 3c ff f8            move.w #$fff8, -(a7)
  004a6c:  4e ba f7 94            jsr $4202(pc)
  004a70:  1b 40 b9 47            move.b d0, -$46b9(a5)
  004a74:  4e ba f6 56            jsr $40cc(pc)
  004a78:  4e ba 00 56            jsr $4ad0(pc)
  004a7c:  4a 40                  tst.w d0
  004a7e:  54 8f                  addq.l #$2, a7
  004a80:  66 06                  bne.b $4a88
  004a82:  1b 47 b9 47            move.b d7, -$46b9(a5)
  004a86:  60 44                  bra.b $4acc
  004a88:  4e ba 01 34            jsr $4bbe(pc)
  004a8c:  3f 00                  move.w d0, -(a7)
  004a8e:  4e ba f7 72            jsr $4202(pc)
  004a92:  1b 40 b9 47            move.b d0, -$46b9(a5)
  004a96:  10 2d b9 4b            move.b -$46b5(a5), d0
  004a9a:  48 80                  ext.w d0
  004a9c:  20 4d                  movea.l a5, a0
  004a9e:  d0 c0                  adda.w d0, a0
  004aa0:  d0 c0                  adda.w d0, a0
  004aa2:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  004aa8:  42 2d b9 4e            clr.b -$46b2(a5)
  004aac:  3e bc 00 0f            move.w #$f, (a7)
  004ab0:  4e ad 05 52            jsr $552(a5)
  004ab4:  4e ba f7 94            jsr $424a(pc)
  004ab8:  3b 7c 00 0c ba 54      move.w #$c, -$45ac(a5)
  004abe:  3e bc 00 09            move.w #$9, (a7)
  004ac2:  4e ba bc f0            jsr $7b4(pc)
  004ac6:  42 6d ba 58            clr.w -$45a8(a5)
  004aca:  54 8f                  addq.l #$2, a7
  004acc:  2e 1f                  move.l (a7)+, d7
  004ace:  4e 75                  rts 
  004ad0:  4e ba 05 08            jsr $4fda(pc)
  004ad4:  1b 40 ba bd            move.b d0, -$4543(a5)
  004ad8:  4e ba 05 5e            jsr $5038(pc)
  004adc:  4e ba 04 34            jsr $4f12(pc)
  004ae0:  4e 75                  rts 
  004ae2:  2f 07                  move.l d7, -(a7)
  004ae4:  4e ba 00 d8            jsr $4bbe(pc)
  004ae8:  3e 00                  move.w d0, d7
  004aea:  0c 47 00 08            cmpi.w #$8, d7
  004aee:  6c 0e                  bge.b $4afe
  004af0:  4e ba 00 2c            jsr $4b1e(pc)
  004af4:  72 00                  moveq #$0, d1
  004af6:  12 00                  move.b d0, d1
  004af8:  0c 41 00 14            cmpi.w #$14, d1
  004afc:  66 06                  bne.b $4b04
  004afe:  5d 47                  subq.w #$6, d7
  004b00:  44 47                  neg.w d7
  004b02:  60 02                  bra.b $4b06
  004b04:  58 47                  addq.w #$4, d7
  004b06:  3f 07                  move.w d7, -(a7)
  004b08:  4e ba f6 f8            jsr $4202(pc)
  004b0c:  1b 40 b9 47            move.b d0, -$46b9(a5)
  004b10:  4e ba f5 ba            jsr $40cc(pc)
  004b14:  4e ba fc 4c            jsr $4762(pc)
  004b18:  54 8f                  addq.l #$2, a7
  004b1a:  2e 1f                  move.l (a7)+, d7
  004b1c:  4e 75                  rts 
  004b1e:  10 2d b9 49            move.b -$46b7(a5), d0
  004b22:  48 80                  ext.w d0
  004b24:  20 4d                  movea.l a5, a0
  004b26:  d0 c0                  adda.w d0, a0
  004b28:  10 28 b6 61            move.b -$499f(a0), d0
  004b2c:  d0 2d b9 4a            add.b -$46b6(a5), d0
  004b30:  1b 40 ba e4            move.b d0, -$451c(a5)
  004b34:  12 2d b9 4b            move.b -$46b5(a5), d1
  004b38:  48 81                  ext.w d1
  004b3a:  3f 01                  move.w d1, -(a7)
  004b3c:  48 80                  ext.w d0
  004b3e:  3f 00                  move.w d0, -(a7)
  004b40:  10 2d b9 4f            move.b -$46b1(a5), d0
  004b44:  48 80                  ext.w d0
  004b46:  3f 00                  move.w d0, -(a7)
  004b48:  4e ba f4 28            jsr $3f72(pc)
  004b4c:  5c 8f                  addq.l #$6, a7
  004b4e:  4e 75                  rts 
  004b50:  2f 07                  move.l d7, -(a7)
  004b52:  10 2d b9 49            move.b -$46b7(a5), d0
  004b56:  48 80                  ext.w d0
  004b58:  20 4d                  movea.l a5, a0
  004b5a:  d0 c0                  adda.w d0, a0
  004b5c:  1e 28 b6 61            move.b -$499f(a0), d7
  004b60:  48 87                  ext.w d7
  004b62:  10 2d b9 4a            move.b -$46b6(a5), d0
  004b66:  d0 07                  add.b d7, d0
  004b68:  d0 07                  add.b d7, d0
  004b6a:  1b 40 ba e4            move.b d0, -$451c(a5)
  004b6e:  12 2d b9 4b            move.b -$46b5(a5), d1
  004b72:  48 81                  ext.w d1
  004b74:  3f 01                  move.w d1, -(a7)
  004b76:  48 80                  ext.w d0
  004b78:  3f 00                  move.w d0, -(a7)
  004b7a:  10 2d b9 4f            move.b -$46b1(a5), d0
  004b7e:  48 80                  ext.w d0
  004b80:  3f 00                  move.w d0, -(a7)
  004b82:  4e ba f3 ee            jsr $3f72(pc)
  004b86:  5c 8f                  addq.l #$6, a7
  004b88:  2e 1f                  move.l (a7)+, d7
  004b8a:  4e 75                  rts 
  004b8c:  10 2d b9 49            move.b -$46b7(a5), d0
  004b90:  48 80                  ext.w d0
  004b92:  20 4d                  movea.l a5, a0
  004b94:  d0 c0                  adda.w d0, a0
  004b96:  10 28 b6 63            move.b -$499d(a0), d0
  004b9a:  d0 2d b9 4a            add.b -$46b6(a5), d0
  004b9e:  1b 40 ba e5            move.b d0, -$451b(a5)
  004ba2:  12 2d b9 4b            move.b -$46b5(a5), d1
  004ba6:  48 81                  ext.w d1
  004ba8:  3f 01                  move.w d1, -(a7)
  004baa:  48 80                  ext.w d0
  004bac:  3f 00                  move.w d0, -(a7)
  004bae:  10 2d b9 4f            move.b -$46b1(a5), d0
  004bb2:  48 80                  ext.w d0
  004bb4:  3f 00                  move.w d0, -(a7)
  004bb6:  4e ba f3 ba            jsr $3f72(pc)
  004bba:  5c 8f                  addq.l #$6, a7
  004bbc:  4e 75                  rts 
  004bbe:  4e ba f6 10            jsr $41d0(pc)
  004bc2:  3f 00                  move.w d0, -(a7)
  004bc4:  4e ba 00 06            jsr $4bcc(pc)
  004bc8:  54 8f                  addq.l #$2, a7
  004bca:  4e 75                  rts 
  004bcc:  4e 56 00 00            link.w a6, #$0
  004bd0:  3f 2e 00 08            move.w $8(a6), -(a7)
  004bd4:  4e ba f8 08            jsr $43de(pc)
  004bd8:  4a 2d b9 49            tst.b -$46b7(a5)
  004bdc:  54 8f                  addq.l #$2, a7
  004bde:  66 0e                  bne.b $4bee
  004be0:  70 00                  moveq #$0, d0
  004be2:  10 2d bd 7e            move.b -$4282(a5), d0
  004be6:  72 0d                  moveq #$d, d1
  004be8:  92 40                  sub.w d0, d1
  004bea:  30 01                  move.w d1, d0
  004bec:  60 06                  bra.b $4bf4
  004bee:  70 00                  moveq #$0, d0
  004bf0:  10 2d bd 7e            move.b -$4282(a5), d0
  004bf4:  4e 5e                  unlk a6
  004bf6:  4e 75                  rts 
  004bf8:  4a 2d b9 53            tst.b -$46ad(a5)
  004bfc:  6c 22                  bge.b $4c20
  004bfe:  4a 2d b9 4f            tst.b -$46b1(a5)
  004c02:  66 1c                  bne.b $4c20
  004c04:  3f 3c 00 64            move.w #$64, -(a7)
  004c08:  4e ba fa fc            jsr $4706(pc)
  004c0c:  42 2d b9 53            clr.b -$46ad(a5)
  004c10:  3e bc 00 01            move.w #$1, (a7)
  004c14:  4e ad 05 4a            jsr $54a(a5)
  004c18:  1b 7c 00 b9 b9 46      move.b #$b9, -$46ba(a5)
  004c1e:  54 8f                  addq.l #$2, a7
  004c20:  4e 75                  rts 
  004c22:  4e ba ff d4            jsr $4bf8(pc)
  004c26:  4e ba 00 90            jsr $4cb8(pc)
  004c2a:  4a 2d b9 53            tst.b -$46ad(a5)
  004c2e:  6d 00 00 86            blt.w $4cb6
  004c32:  4e ba 09 c4            jsr $55f8(pc)
  004c36:  4a 00                  tst.b d0
  004c38:  67 7c                  beq.b $4cb6
  004c3a:  42 6d ba 42            clr.w -$45be(a5)
  004c3e:  4a 2d b9 53            tst.b -$46ad(a5)
  004c42:  6d 0e                  blt.b $4c52
  004c44:  0c 2d 00 06 b9 53      cmpi.b #$6, -$46ad(a5)
  004c4a:  6c 06                  bge.b $4c52
  004c4c:  52 2d b9 53            addq.b #$1, -$46ad(a5)
  004c50:  60 64                  bra.b $4cb6
  004c52:  0c 2d 00 06 b9 53      cmpi.b #$6, -$46ad(a5)
  004c58:  66 18                  bne.b $4c72
  004c5a:  4a 6d a9 0c            tst.w -$56f4(a5)
  004c5e:  6f 0c                  ble.b $4c6c
  004c60:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  004c66:  67 04                  beq.b $4c6c
  004c68:  4e ba 09 ac            jsr $5616(pc)
  004c6c:  52 2d b9 53            addq.b #$1, -$46ad(a5)
  004c70:  60 44                  bra.b $4cb6
  004c72:  0c 2d 00 07 b9 53      cmpi.b #$7, -$46ad(a5)
  004c78:  66 3c                  bne.b $4cb6
  004c7a:  4e ad 01 0a            jsr $10a(a5)
  004c7e:  4a 00                  tst.b d0
  004c80:  66 34                  bne.b $4cb6
  004c82:  4a 6d a9 0c            tst.w -$56f4(a5)
  004c86:  6f 20                  ble.b $4ca8
  004c88:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  004c8e:  67 18                  beq.b $4ca8
  004c90:  30 3c 01 b0            move.w #$1b0, d0
  004c94:  3b 40 ba 90            move.w d0, -$4570(a5)
  004c98:  3b 40 ba 86            move.w d0, -$457a(a5)
  004c9c:  48 6d 96 a0            pea.l -$6960(a5)
  004ca0:  4e ad 05 42            jsr $542(a5)
  004ca4:  58 8f                  addq.l #$4, a7
  004ca6:  60 0a                  bra.b $4cb2
  004ca8:  70 24                  moveq #$24, d0
  004caa:  3b 40 ba 90            move.w d0, -$4570(a5)
  004cae:  3b 40 ba 86            move.w d0, -$457a(a5)
  004cb2:  52 2d b9 53            addq.b #$1, -$46ad(a5)
  004cb6:  4e 75                  rts 
  004cb8:  4a 2d b9 53            tst.b -$46ad(a5)
  004cbc:  6c 0a                  bge.b $4cc8
  004cbe:  4a 6d ba 4a            tst.w -$45b6(a5)
  004cc2:  66 04                  bne.b $4cc8
  004cc4:  42 2d b9 53            clr.b -$46ad(a5)
  004cc8:  4a 6d ba 54            tst.w -$45ac(a5)
  004ccc:  67 04                  beq.b $4cd2
  004cce:  53 6d ba 54            subq.w #$1, -$45ac(a5)
  004cd2:  4a 6d a9 0c            tst.w -$56f4(a5)
  004cd6:  66 0a                  bne.b $4ce2
  004cd8:  4e ba 00 22            jsr $4cfc(pc)
  004cdc:  4e ad 05 6a            jsr $56a(a5)
  004ce0:  60 18                  bra.b $4cfa
  004ce2:  4e ba 01 08            jsr $4dec(pc)
  004ce6:  4e ba bd 3c            jsr $a24(pc)
  004cea:  1b 40 a5 be            move.b d0, -$5a42(a5)
  004cee:  4e ba 01 86            jsr $4e76(pc)
  004cf2:  4e ba 00 8c            jsr $4d80(pc)
  004cf6:  4e ba 00 d4            jsr $4dcc(pc)
  004cfa:  4e 75                  rts 
  004cfc:  4a 6d ba 40            tst.w -$45c0(a5)
  004d00:  67 14                  beq.b $4d16
  004d02:  4e ba 00 b4            jsr $4db8(pc)
  004d06:  1b 40 ba ae            move.b d0, -$4552(a5)
  004d0a:  72 ff                  moveq #$ff, d1
  004d0c:  1b 41 ba b9            move.b d1, -$4547(a5)
  004d10:  1b 41 ba aa            move.b d1, -$4556(a5)
  004d14:  60 22                  bra.b $4d38
  004d16:  4a 2d b9 52            tst.b -$46ae(a5)
  004d1a:  67 12                  beq.b $4d2e
  004d1c:  3b 7c 00 0a ba 20      move.w #$a, -$45e0(a5)
  004d22:  4e ba e7 ee            jsr $3512(pc)
  004d26:  3b 7c 00 0b ba 20      move.w #$b, -$45e0(a5)
  004d2c:  60 0a                  bra.b $4d38
  004d2e:  48 6d a9 c0            pea.l -$5640(a5)
  004d32:  4e ba f0 1c            jsr $3d50(pc)
  004d36:  58 8f                  addq.l #$4, a7
  004d38:  4e 75                  rts 
  004d3a:  0c 2d 00 18 b9 51      cmpi.b #$18, -$46af(a5)
  004d40:  66 06                  bne.b $4d48
  004d42:  4e ba e7 ce            jsr $3512(pc)
  004d46:  60 36                  bra.b $4d7e
  004d48:  4a 2d b9 53            tst.b -$46ad(a5)
  004d4c:  6d 0e                  blt.b $4d5c
  004d4e:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  004d54:  66 20                  bne.b $4d76
  004d56:  4e ba 09 4e            jsr $56a6(pc)
  004d5a:  60 1a                  bra.b $4d76
  004d5c:  4a 6d ba 4c            tst.w -$45b4(a5)
  004d60:  66 14                  bne.b $4d76
  004d62:  42 2d b9 53            clr.b -$46ad(a5)
  004d66:  4e ba 08 e0            jsr $5648(pc)
  004d6a:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  004d70:  66 04                  bne.b $4d76
  004d72:  4e ba 09 32            jsr $56a6(pc)
  004d76:  4e ba e7 9a            jsr $3512(pc)
  004d7a:  4e ad 05 6a            jsr $56a(a5)
  004d7e:  4e 75                  rts 
  004d80:  4a 2d b9 49            tst.b -$46b7(a5)
  004d84:  6d 0e                  blt.b $4d94
  004d86:  4e ba 00 12            jsr $4d9a(pc)
  004d8a:  4e ad 05 6a            jsr $56a(a5)
  004d8e:  4e ba 00 0a            jsr $4d9a(pc)
  004d92:  60 04                  bra.b $4d98
  004d94:  4e ad 05 6a            jsr $56a(a5)
  004d98:  4e 75                  rts 
  004d9a:  2f 07                  move.l d7, -(a7)
  004d9c:  10 2d ba b9            move.b -$4547(a5), d0
  004da0:  44 00                  neg.b d0
  004da2:  1b 40 ba b9            move.b d0, -$4547(a5)
  004da6:  1e 2d ba aa            move.b -$4556(a5), d7
  004daa:  1b 6d ba ab ba aa      move.b -$4555(a5), -$4556(a5)
  004db0:  1b 47 ba ab            move.b d7, -$4555(a5)
  004db4:  2e 1f                  move.l (a7)+, d7
  004db6:  4e 75                  rts 
  004db8:  42 2d ba ad            clr.b -$4553(a5)
  004dbc:  42 2d ba ac            clr.b -$4554(a5)
  004dc0:  42 2d ba aa            clr.b -$4556(a5)
  004dc4:  42 2d ba ab            clr.b -$4555(a5)
  004dc8:  70 01                  moveq #$1, d0
  004dca:  4e 75                  rts 
  004dcc:  1b 6d ba aa ba af      move.b -$4556(a5), -$4551(a5)
  004dd2:  1b 6d ba ab ba b0      move.b -$4555(a5), -$4550(a5)
  004dd8:  1b 6d ba ac ba b1      move.b -$4554(a5), -$454f(a5)
  004dde:  1b 6d ba ad ba b2      move.b -$4553(a5), -$454e(a5)
  004de4:  1b 6d ba ae ba b3      move.b -$4552(a5), -$454d(a5)
  004dea:  4e 75                  rts 
  004dec:  1b 6d ba af ba aa      move.b -$4551(a5), -$4556(a5)
  004df2:  1b 6d ba b0 ba ab      move.b -$4550(a5), -$4555(a5)
  004df8:  1b 6d ba b1 ba ac      move.b -$454f(a5), -$4554(a5)
  004dfe:  1b 6d ba b2 ba ad      move.b -$454e(a5), -$4553(a5)
  004e04:  1b 6d ba b3 ba ae      move.b -$454d(a5), -$4552(a5)
  004e0a:  4e 75                  rts 
  004e0c:  1b 6d ba aa ba b4      move.b -$4556(a5), -$454c(a5)
  004e12:  1b 6d ba ab ba b5      move.b -$4555(a5), -$454b(a5)
  004e18:  1b 6d ba ac ba b6      move.b -$4554(a5), -$454a(a5)
  004e1e:  1b 6d ba ad ba b7      move.b -$4553(a5), -$4549(a5)
  004e24:  1b 6d ba ae ba b8      move.b -$4552(a5), -$4548(a5)
  004e2a:  4e 75                  rts 
  004e2c:  1b 6d ba b4 ba aa      move.b -$454c(a5), -$4556(a5)
  004e32:  1b 6d ba b5 ba ab      move.b -$454b(a5), -$4555(a5)
  004e38:  1b 6d ba b6 ba ac      move.b -$454a(a5), -$4554(a5)
  004e3e:  1b 6d ba b7 ba ad      move.b -$4549(a5), -$4553(a5)
  004e44:  1b 6d ba b8 ba ae      move.b -$4548(a5), -$4552(a5)
  004e4a:  4e 75                  rts 
  004e4c:  42 2d ba b3            clr.b -$454d(a5)
  004e50:  42 2d ba b2            clr.b -$454e(a5)
  004e54:  42 2d ba b1            clr.b -$454f(a5)
  004e58:  42 2d ba b0            clr.b -$4550(a5)
  004e5c:  42 2d ba af            clr.b -$4551(a5)
  004e60:  42 2d ba b8            clr.b -$4548(a5)
  004e64:  42 2d ba b7            clr.b -$4549(a5)
  004e68:  42 2d ba b6            clr.b -$454a(a5)
  004e6c:  42 2d ba b5            clr.b -$454b(a5)
  004e70:  42 2d ba b4            clr.b -$454c(a5)
  004e74:  4e 75                  rts 
  004e76:  4a 2d ba aa            tst.b -$4556(a5)
  004e7a:  6d 18                  blt.b $4e94
  004e7c:  4a 2d ba b9            tst.b -$4547(a5)
  004e80:  6c 0e                  bge.b $4e90
  004e82:  4a 2d ba aa            tst.b -$4556(a5)
  004e86:  66 0c                  bne.b $4e94
  004e88:  1b 7c 00 ff ba aa      move.b #$ff, -$4556(a5)
  004e8e:  60 04                  bra.b $4e94
  004e90:  42 2d ba aa            clr.b -$4556(a5)
  004e94:  4a 2d ba ab            tst.b -$4555(a5)
  004e98:  6d 1a                  blt.b $4eb4
  004e9a:  0c 2d 00 01 ba b9      cmpi.b #$1, -$4547(a5)
  004ea0:  66 0e                  bne.b $4eb0
  004ea2:  4a 2d ba ab            tst.b -$4555(a5)
  004ea6:  66 0c                  bne.b $4eb4
  004ea8:  1b 7c 00 ff ba ab      move.b #$ff, -$4555(a5)
  004eae:  60 04                  bra.b $4eb4
  004eb0:  42 2d ba ab            clr.b -$4555(a5)
  004eb4:  4a 2d ba ac            tst.b -$4554(a5)
  004eb8:  6d 18                  blt.b $4ed2
  004eba:  4a 2d ba ba            tst.b -$4546(a5)
  004ebe:  6c 0e                  bge.b $4ece
  004ec0:  4a 2d ba ac            tst.b -$4554(a5)
  004ec4:  66 0c                  bne.b $4ed2
  004ec6:  1b 7c 00 ff ba ac      move.b #$ff, -$4554(a5)
  004ecc:  60 04                  bra.b $4ed2
  004ece:  42 2d ba ac            clr.b -$4554(a5)
  004ed2:  4a 2d ba ad            tst.b -$4553(a5)
  004ed6:  6d 1a                  blt.b $4ef2
  004ed8:  0c 2d 00 01 ba ba      cmpi.b #$1, -$4546(a5)
  004ede:  66 0e                  bne.b $4eee
  004ee0:  4a 2d ba ad            tst.b -$4553(a5)
  004ee4:  66 0c                  bne.b $4ef2
  004ee6:  1b 7c 00 ff ba ad      move.b #$ff, -$4553(a5)
  004eec:  60 04                  bra.b $4ef2
  004eee:  42 2d ba ad            clr.b -$4553(a5)
  004ef2:  4a 2d ba ae            tst.b -$4552(a5)
  004ef6:  6d 18                  blt.b $4f10
  004ef8:  4a 2d ba bb            tst.b -$4545(a5)
  004efc:  6c 0e                  bge.b $4f0c
  004efe:  4a 2d ba ae            tst.b -$4552(a5)
  004f02:  66 0c                  bne.b $4f10
  004f04:  1b 7c 00 ff ba ae      move.b #$ff, -$4552(a5)
  004f0a:  60 04                  bra.b $4f10
  004f0c:  42 2d ba ae            clr.b -$4552(a5)
  004f10:  4e 75                  rts 
  004f12:  2f 07                  move.l d7, -(a7)
  004f14:  70 00                  moveq #$0, d0
  004f16:  10 2d ba e9            move.b -$4517(a5), d0
  004f1a:  d0 ad bd 86            add.l -$427a(a5), d0
  004f1e:  20 40                  movea.l d0, a0
  004f20:  1e 10                  move.b (a0), d7
  004f22:  0c 2d 00 14 ba bd      cmpi.b #$14, -$4543(a5)
  004f28:  66 04                  bne.b $4f2e
  004f2a:  70 00                  moveq #$0, d0
  004f2c:  60 62                  bra.b $4f90
  004f2e:  0c 2d 00 0c ba bd      cmpi.b #$c, -$4543(a5)
  004f34:  66 0a                  bne.b $4f40
  004f36:  4a 2d b9 49            tst.b -$46b7(a5)
  004f3a:  6d 04                  blt.b $4f40
  004f3c:  70 00                  moveq #$0, d0
  004f3e:  60 50                  bra.b $4f90
  004f40:  70 00                  moveq #$0, d0
  004f42:  10 2d ba bd            move.b -$4543(a5), d0
  004f46:  3f 00                  move.w d0, -(a7)
  004f48:  4e ba f7 0a            jsr $4654(pc)
  004f4c:  4a 00                  tst.b d0
  004f4e:  54 8f                  addq.l #$2, a7
  004f50:  67 04                  beq.b $4f56
  004f52:  70 00                  moveq #$0, d0
  004f54:  60 3a                  bra.b $4f90
  004f56:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  004f5c:  66 08                  bne.b $4f66
  004f5e:  4a 07                  tst.b d7
  004f60:  67 04                  beq.b $4f66
  004f62:  70 00                  moveq #$0, d0
  004f64:  60 2a                  bra.b $4f90
  004f66:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  004f6c:  66 0a                  bne.b $4f78
  004f6e:  4a 2d b9 49            tst.b -$46b7(a5)
  004f72:  6c 04                  bge.b $4f78
  004f74:  70 00                  moveq #$0, d0
  004f76:  60 18                  bra.b $4f90
  004f78:  70 00                  moveq #$0, d0
  004f7a:  10 2d ba e8            move.b -$4518(a5), d0
  004f7e:  3f 00                  move.w d0, -(a7)
  004f80:  4e ba f6 d2            jsr $4654(pc)
  004f84:  4a 00                  tst.b d0
  004f86:  54 8f                  addq.l #$2, a7
  004f88:  66 04                  bne.b $4f8e
  004f8a:  70 00                  moveq #$0, d0
  004f8c:  60 02                  bra.b $4f90
  004f8e:  70 01                  moveq #$1, d0
  004f90:  2e 1f                  move.l (a7)+, d7
  004f92:  4e 75                  rts 
  004f94:  4e 56 00 00            link.w a6, #$0
  004f98:  2f 07                  move.l d7, -(a7)
  004f9a:  1e 2e 00 08            move.b $8(a6), d7
  004f9e:  0c 07 00 14            cmpi.b #$14, d7
  004fa2:  66 04                  bne.b $4fa8
  004fa4:  70 04                  moveq #$4, d0
  004fa6:  60 2c                  bra.b $4fd4
  004fa8:  0c 07 00 12            cmpi.b #$12, d7
  004fac:  66 04                  bne.b $4fb2
  004fae:  70 03                  moveq #$3, d0
  004fb0:  60 22                  bra.b $4fd4
  004fb2:  0c 07 00 04            cmpi.b #$4, d7
  004fb6:  67 0c                  beq.b $4fc4
  004fb8:  0c 07 00 07            cmpi.b #$7, d7
  004fbc:  67 06                  beq.b $4fc4
  004fbe:  0c 07 00 0c            cmpi.b #$c, d7
  004fc2:  66 04                  bne.b $4fc8
  004fc4:  70 01                  moveq #$1, d0
  004fc6:  60 0c                  bra.b $4fd4
  004fc8:  0c 07 00 0d            cmpi.b #$d, d7
  004fcc:  66 04                  bne.b $4fd2
  004fce:  70 02                  moveq #$2, d0
  004fd0:  60 02                  bra.b $4fd4
  004fd2:  70 00                  moveq #$0, d0
  004fd4:  2e 1f                  move.l (a7)+, d7
  004fd6:  4e 5e                  unlk a6
  004fd8:  4e 75                  rts 
  004fda:  70 ff                  moveq #$ff, d0
  004fdc:  d0 2d b9 4b            add.b -$46b5(a5), d0
  004fe0:  1b 40 ba e6            move.b d0, -$451a(a5)
  004fe4:  48 80                  ext.w d0
  004fe6:  3f 00                  move.w d0, -(a7)
  004fe8:  10 2d b9 4a            move.b -$46b6(a5), d0
  004fec:  48 80                  ext.w d0
  004fee:  3f 00                  move.w d0, -(a7)
  004ff0:  10 2d b9 4f            move.b -$46b1(a5), d0
  004ff4:  48 80                  ext.w d0
  004ff6:  3f 00                  move.w d0, -(a7)
  004ff8:  4e ba ef 78            jsr $3f72(pc)
  004ffc:  5c 8f                  addq.l #$6, a7
  004ffe:  4e 75                  rts 
  005000:  10 2d b9 49            move.b -$46b7(a5), d0
  005004:  48 80                  ext.w d0
  005006:  20 4d                  movea.l a5, a0
  005008:  d0 c0                  adda.w d0, a0
  00500a:  10 28 b6 63            move.b -$499d(a0), d0
  00500e:  d0 2d b9 4a            add.b -$46b6(a5), d0
  005012:  1b 40 ba e5            move.b d0, -$451b(a5)
  005016:  72 ff                  moveq #$ff, d1
  005018:  d2 2d b9 4b            add.b -$46b5(a5), d1
  00501c:  1b 41 ba e6            move.b d1, -$451a(a5)
  005020:  48 81                  ext.w d1
  005022:  3f 01                  move.w d1, -(a7)
  005024:  48 80                  ext.w d0
  005026:  3f 00                  move.w d0, -(a7)
  005028:  10 2d b9 4f            move.b -$46b1(a5), d0
  00502c:  48 80                  ext.w d0
  00502e:  3f 00                  move.w d0, -(a7)
  005030:  4e ba ef 40            jsr $3f72(pc)
  005034:  5c 8f                  addq.l #$6, a7
  005036:  4e 75                  rts 
  005038:  10 2d b9 49            move.b -$46b7(a5), d0
  00503c:  48 80                  ext.w d0
  00503e:  20 4d                  movea.l a5, a0
  005040:  d0 c0                  adda.w d0, a0
  005042:  10 28 b6 61            move.b -$499f(a0), d0
  005046:  d0 2d b9 4a            add.b -$46b6(a5), d0
  00504a:  1b 40 ba e4            move.b d0, -$451c(a5)
  00504e:  72 ff                  moveq #$ff, d1
  005050:  d2 2d b9 4b            add.b -$46b5(a5), d1
  005054:  1b 41 ba e6            move.b d1, -$451a(a5)
  005058:  48 81                  ext.w d1
  00505a:  3f 01                  move.w d1, -(a7)
  00505c:  48 80                  ext.w d0
  00505e:  3f 00                  move.w d0, -(a7)
  005060:  10 2d b9 4f            move.b -$46b1(a5), d0
  005064:  48 80                  ext.w d0
  005066:  3f 00                  move.w d0, -(a7)
  005068:  4e ba ef 08            jsr $3f72(pc)
  00506c:  5c 8f                  addq.l #$6, a7
  00506e:  4e 75                  rts 
  005070:  4e 56 00 00            link.w a6, #$0
  005074:  4a 2d b9 49            tst.b -$46b7(a5)
  005078:  6c 06                  bge.b $5080
  00507a:  30 2e 00 08            move.w $8(a6), d0
  00507e:  60 06                  bra.b $5086
  005080:  30 2e 00 08            move.w $8(a6), d0
  005084:  44 40                  neg.w d0
  005086:  4e 5e                  unlk a6
  005088:  4e 75                  rts 
  00508a:  4e 56 00 00            link.w a6, #$0
  00508e:  2f 07                  move.l d7, -(a7)
  005090:  3b 6e 00 08 ba c0      move.w $8(a6), -$4540(a5)
  005096:  3b 6d ba ea ba c2      move.w -$4516(a5), -$453e(a5)
  00509c:  70 00                  moveq #$0, d0
  00509e:  10 2d ba e9            move.b -$4517(a5), d0
  0050a2:  3b 40 ba c4            move.w d0, -$453c(a5)
  0050a6:  1b 7c 00 01 ba ae      move.b #$1, -$4552(a5)
  0050ac:  7e 00                  moveq #$0, d7
  0050ae:  1e 2d ba e9            move.b -$4517(a5), d7
  0050b2:  20 6d bd 82            movea.l -$427e(a5), a0
  0050b6:  11 bc 00 01 78 00      move.b #$1, (a0, d7.l)
  0050bc:  20 6d bd 86            movea.l -$427a(a5), a0
  0050c0:  42 30 78 00            clr.b (a0, d7.l)
  0050c4:  3b 7c 00 23 bd 6c      move.w #$23, -$4294(a5)
  0050ca:  70 00                  moveq #$0, d0
  0050cc:  10 2d ba e9            move.b -$4517(a5), d0
  0050d0:  3f 00                  move.w d0, -(a7)
  0050d2:  4e ad 04 42            jsr $442(a5)
  0050d6:  2e 2e ff fc            move.l -$4(a6), d7
  0050da:  4e 5e                  unlk a6
  0050dc:  4e 75                  rts 
  0050de:  48 e7 03 00            movem.l d6-d7, -(a7)
  0050e2:  7e 00                  moveq #$0, d7
  0050e4:  1e 2d b9 46            move.b -$46ba(a5), d7
  0050e8:  1c 2d b9 4c            move.b -$46b4(a5), d6
  0050ec:  48 86                  ext.w d6
  0050ee:  0c 47 00 57            cmpi.w #$57, d7
  0050f2:  6d 06                  blt.b $50fa
  0050f4:  0c 47 00 64            cmpi.w #$64, d7
  0050f8:  6d 0c                  blt.b $5106
  0050fa:  0c 47 00 87            cmpi.w #$87, d7
  0050fe:  6d 0c                  blt.b $510c
  005100:  0c 47 00 8d            cmpi.w #$8d, d7
  005104:  6c 06                  bge.b $510c
  005106:  4e ba fe d2            jsr $4fda(pc)
  00510a:  60 3e                  bra.b $514a
  00510c:  0c 46 00 07            cmpi.w #$7, d6
  005110:  67 0c                  beq.b $511e
  005112:  0c 46 00 05            cmpi.w #$5, d6
  005116:  67 06                  beq.b $511e
  005118:  0c 46 00 02            cmpi.w #$2, d6
  00511c:  6c 6e                  bge.b $518c
  00511e:  0c 47 00 4f            cmpi.w #$4f, d7
  005122:  66 1a                  bne.b $513e
  005124:  4e ba fe b4            jsr $4fda(pc)
  005128:  72 00                  moveq #$0, d1
  00512a:  12 00                  move.b d0, d1
  00512c:  0c 41 00 0b            cmpi.w #$b, d1
  005130:  66 0c                  bne.b $513e
  005132:  1f 3c 00 01            move.b #$1, -(a7)
  005136:  4e ad 04 8a            jsr $48a(a5)
  00513a:  54 8f                  addq.l #$2, a7
  00513c:  60 0c                  bra.b $514a
  00513e:  08 2d 00 06 b9 92      btst.b #$6, -$466e(a5)
  005144:  67 46                  beq.b $518c
  005146:  4e ba f6 1a            jsr $4762(pc)
  00514a:  0c 2d 00 0f ba e8      cmpi.b #$f, -$4518(a5)
  005150:  67 08                  beq.b $515a
  005152:  0c 2d 00 06 ba e8      cmpi.b #$6, -$4518(a5)
  005158:  66 1a                  bne.b $5174
  00515a:  4a 2d b9 53            tst.b -$46ad(a5)
  00515e:  6c 0e                  bge.b $516e
  005160:  2f 3c 00 01 00 00      move.l #$10000, -(a7)
  005166:  4e ad 04 72            jsr $472(a5)
  00516a:  58 8f                  addq.l #$4, a7
  00516c:  60 1e                  bra.b $518c
  00516e:  4e ad 04 7a            jsr $47a(a5)
  005172:  60 18                  bra.b $518c
  005174:  0c 2d 00 0b ba e8      cmpi.b #$b, -$4518(a5)
  00517a:  66 10                  bne.b $518c
  00517c:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  005182:  1f 3c 00 01            move.b #$1, -(a7)
  005186:  4e ad 04 8a            jsr $48a(a5)
  00518a:  54 8f                  addq.l #$2, a7
  00518c:  4c df 00 c0            movem.l (a7)+, d6-d7
  005190:  4e 75                  rts 
  005192:  48 e7 1f 00            movem.l d3-d7, -(a7)
  005196:  3f 2d ba de            move.w -$4522(a5), -(a7)
  00519a:  4e ba f2 42            jsr $43de(pc)
  00519e:  3e 00                  move.w d0, d7
  0051a0:  4a 47                  tst.w d7
  0051a2:  54 8f                  addq.l #$2, a7
  0051a4:  6d 76                  blt.b $521c
  0051a6:  1c 2d b9 4b            move.b -$46b5(a5), d6
  0051aa:  48 86                  ext.w d6
  0051ac:  1a 2d b9 4f            move.b -$46b1(a5), d5
  0051b0:  48 85                  ext.w d5
  0051b2:  3f 2d ba dc            move.w -$4524(a5), -(a7)
  0051b6:  4e ba f2 26            jsr $43de(pc)
  0051ba:  38 00                  move.w d0, d4
  0051bc:  54 8f                  addq.l #$2, a7
  0051be:  60 58                  bra.b $5218
  0051c0:  1c 2d b9 4b            move.b -$46b5(a5), d6
  0051c4:  48 86                  ext.w d6
  0051c6:  76 00                  moveq #$0, d3
  0051c8:  3f 06                  move.w d6, -(a7)
  0051ca:  3f 04                  move.w d4, -(a7)
  0051cc:  3f 05                  move.w d5, -(a7)
  0051ce:  4e ba ed a2            jsr $3f72(pc)
  0051d2:  72 00                  moveq #$0, d1
  0051d4:  12 00                  move.b d0, d1
  0051d6:  55 41                  subq.w #$2, d1
  0051d8:  5c 8f                  addq.l #$6, a7
  0051da:  66 14                  bne.b $51f0
  0051dc:  70 00                  moveq #$0, d0
  0051de:  10 2d ba e9            move.b -$4517(a5), d0
  0051e2:  3f 00                  move.w d0, -(a7)
  0051e4:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  0051e8:  4e ad 04 62            jsr $462(a5)
  0051ec:  58 8f                  addq.l #$4, a7
  0051ee:  60 22                  bra.b $5212
  0051f0:  70 00                  moveq #$0, d0
  0051f2:  10 2d ba e8            move.b -$4518(a5), d0
  0051f6:  3f 00                  move.w d0, -(a7)
  0051f8:  4e ba f4 5a            jsr $4654(pc)
  0051fc:  4a 00                  tst.b d0
  0051fe:  54 8f                  addq.l #$2, a7
  005200:  66 10                  bne.b $5212
  005202:  4a 6d ba ea            tst.w -$4516(a5)
  005206:  67 0a                  beq.b $5212
  005208:  ba 6d ba ea            cmp.w -$4516(a5), d5
  00520c:  66 04                  bne.b $5212
  00520e:  52 46                  addq.w #$1, d6
  005210:  76 01                  moveq #$1, d3
  005212:  4a 43                  tst.w d3
  005214:  66 b0                  bne.b $51c6
  005216:  52 44                  addq.w #$1, d4
  005218:  be 44                  cmp.w d4, d7
  00521a:  6c a4                  bge.b $51c0
  00521c:  4c df 00 f8            movem.l (a7)+, d3-d7
  005220:  4e 75                  rts 
  005222:  48 e7 1f 00            movem.l d3-d7, -(a7)
  005226:  7e 00                  moveq #$0, d7
  005228:  1e 2d b9 46            move.b -$46ba(a5), d7
  00522c:  1c 2d b9 4c            move.b -$46b4(a5), d6
  005230:  48 86                  ext.w d6
  005232:  1a 2d b9 4f            move.b -$46b1(a5), d5
  005236:  48 85                  ext.w d5
  005238:  18 2d b9 4b            move.b -$46b5(a5), d4
  00523c:  48 84                  ext.w d4
  00523e:  4e ba f3 28            jsr $4568(pc)
  005242:  0c 47 00 e0            cmpi.w #$e0, d7
  005246:  6d 16                  blt.b $525e
  005248:  0c 47 00 e5            cmpi.w #$e5, d7
  00524c:  6c 10                  bge.b $525e
  00524e:  3b 6d bd 98 ba fe      move.w -$4268(a5), -$4502(a5)
  005254:  3b 6d ba e2 bb 04      move.w -$451e(a5), -$44fc(a5)
  00525a:  60 00 01 ca            bra.w $5426
  00525e:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  005262:  3f 2d ba c6            move.w -$453a(a5), -(a7)
  005266:  3f 05                  move.w d5, -(a7)
  005268:  4e ba ed 08            jsr $3f72(pc)
  00526c:  72 00                  moveq #$0, d1
  00526e:  12 00                  move.b d0, d1
  005270:  0c 41 00 14            cmpi.w #$14, d1
  005274:  5c 8f                  addq.l #$6, a7
  005276:  67 12                  beq.b $528a
  005278:  70 00                  moveq #$0, d0
  00527a:  10 2d ba e8            move.b -$4518(a5), d0
  00527e:  3f 00                  move.w d0, -(a7)
  005280:  4e ba f3 d2            jsr $4654(pc)
  005284:  4a 00                  tst.b d0
  005286:  54 8f                  addq.l #$2, a7
  005288:  67 7c                  beq.b $5306
  00528a:  4a 46                  tst.w d6
  00528c:  66 0c                  bne.b $529a
  00528e:  0c 47 00 4f            cmpi.w #$4f, d7
  005292:  67 32                  beq.b $52c6
  005294:  0c 47 00 51            cmpi.w #$51, d7
  005298:  67 2c                  beq.b $52c6
  00529a:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  00529e:  3f 2d ba c8            move.w -$4538(a5), -(a7)
  0052a2:  3f 05                  move.w d5, -(a7)
  0052a4:  4e ba ec cc            jsr $3f72(pc)
  0052a8:  72 00                  moveq #$0, d1
  0052aa:  12 00                  move.b d0, d1
  0052ac:  0c 41 00 14            cmpi.w #$14, d1
  0052b0:  5c 8f                  addq.l #$6, a7
  0052b2:  67 12                  beq.b $52c6
  0052b4:  70 00                  moveq #$0, d0
  0052b6:  10 2d ba e8            move.b -$4518(a5), d0
  0052ba:  3f 00                  move.w d0, -(a7)
  0052bc:  4e ba f3 96            jsr $4654(pc)
  0052c0:  4a 00                  tst.b d0
  0052c2:  54 8f                  addq.l #$2, a7
  0052c4:  67 40                  beq.b $5306
  0052c6:  20 4d                  movea.l a5, a0
  0052c8:  d0 c4                  adda.w d4, a0
  0052ca:  d0 c4                  adda.w d4, a0
  0052cc:  36 28 b6 66            move.w -$499a(a0), d3
  0052d0:  4a 44                  tst.w d4
  0052d2:  6f 10                  ble.b $52e4
  0052d4:  b6 6d ba f8            cmp.w -$4508(a5), d3
  0052d8:  6c 2c                  bge.b $5306
  0052da:  70 f1                  moveq #$f1, d0
  0052dc:  d0 43                  add.w d3, d0
  0052de:  b0 6d ba e0            cmp.w -$4520(a5), d0
  0052e2:  6c 22                  bge.b $5306
  0052e4:  3b 43 ba e0            move.w d3, -$4520(a5)
  0052e8:  4a 6d ba e0            tst.w -$4520(a5)
  0052ec:  6c 08                  bge.b $52f6
  0052ee:  3b 6d 9c 64 ba fe      move.w -$639c(a5), -$4502(a5)
  0052f4:  60 10                  bra.b $5306
  0052f6:  30 2d ba e0            move.w -$4520(a5), d0
  0052fa:  20 4d                  movea.l a5, a0
  0052fc:  d0 c0                  adda.w d0, a0
  0052fe:  d0 c0                  adda.w d0, a0
  005300:  3b 68 9c 64 ba fe      move.w -$639c(a0), -$4502(a5)
  005306:  70 fc                  moveq #$fc, d0
  005308:  d0 6d ba d8            add.w -$4528(a5), d0
  00530c:  3f 00                  move.w d0, -(a7)
  00530e:  4e ba f0 f4            jsr $4404(pc)
  005312:  36 00                  move.w d0, d3
  005314:  3e 84                  move.w d4, (a7)
  005316:  70 01                  moveq #$1, d0
  005318:  d0 43                  add.w d3, d0
  00531a:  3f 00                  move.w d0, -(a7)
  00531c:  3f 05                  move.w d5, -(a7)
  00531e:  4e ba ec 52            jsr $3f72(pc)
  005322:  72 00                  moveq #$0, d1
  005324:  12 00                  move.b d0, d1
  005326:  5f 41                  subq.w #$7, d1
  005328:  5c 8f                  addq.l #$6, a7
  00532a:  67 08                  beq.b $5334
  00532c:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  005332:  66 18                  bne.b $534c
  005334:  70 01                  moveq #$1, d0
  005336:  d0 6d ba ec            add.w -$4514(a5), d0
  00533a:  eb 48                  lsl.w #$5, d0
  00533c:  20 4d                  movea.l a5, a0
  00533e:  d0 c0                  adda.w d0, a0
  005340:  d0 c0                  adda.w d0, a0
  005342:  3b 68 98 66 bb 04      move.w -$679a(a0), -$44fc(a5)
  005348:  60 00 00 dc            bra.w $5426
  00534c:  3f 04                  move.w d4, -(a7)
  00534e:  3f 03                  move.w d3, -(a7)
  005350:  3f 05                  move.w d5, -(a7)
  005352:  4e ba ec 1e            jsr $3f72(pc)
  005356:  72 00                  moveq #$0, d1
  005358:  12 00                  move.b d0, d1
  00535a:  5f 41                  subq.w #$7, d1
  00535c:  5c 8f                  addq.l #$6, a7
  00535e:  67 08                  beq.b $5368
  005360:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  005366:  66 58                  bne.b $53c0
  005368:  0c 46 00 03            cmpi.w #$3, d6
  00536c:  67 52                  beq.b $53c0
  00536e:  0c 46 00 04            cmpi.w #$4, d6
  005372:  66 06                  bne.b $537a
  005374:  0c 47 00 6a            cmpi.w #$6a, d7
  005378:  67 46                  beq.b $53c0
  00537a:  0c 46 00 05            cmpi.w #$5, d6
  00537e:  66 06                  bne.b $5386
  005380:  0c 47 00 6b            cmpi.w #$6b, d7
  005384:  67 3a                  beq.b $53c0
  005386:  4a 2d b9 49            tst.b -$46b7(a5)
  00538a:  6c 1e                  bge.b $53aa
  00538c:  0c 46 00 02            cmpi.w #$2, d6
  005390:  67 2e                  beq.b $53c0
  005392:  0c 46 00 06            cmpi.w #$6, d6
  005396:  67 28                  beq.b $53c0
  005398:  0c 46 00 01            cmpi.w #$1, d6
  00539c:  66 0c                  bne.b $53aa
  00539e:  0c 47 00 89            cmpi.w #$89, d7
  0053a2:  6d 06                  blt.b $53aa
  0053a4:  0c 47 00 8c            cmpi.w #$8c, d7
  0053a8:  6f 16                  ble.b $53c0
  0053aa:  70 01                  moveq #$1, d0
  0053ac:  d0 6d ba ec            add.w -$4514(a5), d0
  0053b0:  eb 48                  lsl.w #$5, d0
  0053b2:  20 4d                  movea.l a5, a0
  0053b4:  d0 c0                  adda.w d0, a0
  0053b6:  d0 c0                  adda.w d0, a0
  0053b8:  3b 68 98 66 bb 04      move.w -$679a(a0), -$44fc(a5)
  0053be:  60 66                  bra.b $5426
  0053c0:  3f 2d ba da            move.w -$4526(a5), -(a7)
  0053c4:  4e ba f0 3e            jsr $4404(pc)
  0053c8:  36 00                  move.w d0, d3
  0053ca:  3e 84                  move.w d4, (a7)
  0053cc:  3f 03                  move.w d3, -(a7)
  0053ce:  3f 05                  move.w d5, -(a7)
  0053d0:  4e ba eb a0            jsr $3f72(pc)
  0053d4:  72 00                  moveq #$0, d1
  0053d6:  12 00                  move.b d0, d1
  0053d8:  0c 41 00 14            cmpi.w #$14, d1
  0053dc:  5c 8f                  addq.l #$6, a7
  0053de:  67 0e                  beq.b $53ee
  0053e0:  0c 2d 00 0d ba e8      cmpi.b #$d, -$4518(a5)
  0053e6:  66 3e                  bne.b $5426
  0053e8:  4a 2d b9 49            tst.b -$46b7(a5)
  0053ec:  66 38                  bne.b $5426
  0053ee:  3f 2d ba ca            move.w -$4536(a5), -(a7)
  0053f2:  3f 03                  move.w d3, -(a7)
  0053f4:  3f 05                  move.w d5, -(a7)
  0053f6:  4e ba eb 7a            jsr $3f72(pc)
  0053fa:  72 00                  moveq #$0, d1
  0053fc:  12 00                  move.b d0, d1
  0053fe:  0c 41 00 14            cmpi.w #$14, d1
  005402:  5c 8f                  addq.l #$6, a7
  005404:  67 08                  beq.b $540e
  005406:  0c 2d 00 0d ba e8      cmpi.b #$d, -$4518(a5)
  00540c:  66 18                  bne.b $5426
  00540e:  ba 6d ba ea            cmp.w -$4516(a5), d5
  005412:  66 12                  bne.b $5426
  005414:  30 2d ba ec            move.w -$4514(a5), d0
  005418:  eb 48                  lsl.w #$5, d0
  00541a:  20 4d                  movea.l a5, a0
  00541c:  d0 c0                  adda.w d0, a0
  00541e:  d0 c0                  adda.w d0, a0
  005420:  3b 68 98 66 bb 04      move.w -$679a(a0), -$44fc(a5)
  005426:  4c df 00 f8            movem.l (a7)+, d3-d7
  00542a:  4e 75                  rts 
  00542c:  4e ba f3 34            jsr $4762(pc)
  005430:  72 00                  moveq #$0, d1
  005432:  12 00                  move.b d0, d1
  005434:  5b 41                  subq.w #$5, d1
  005436:  66 04                  bne.b $543c
  005438:  52 2d b9 48            addq.b #$1, -$46b8(a5)
  00543c:  4e 75                  rts 
  00543e:  48 e7 03 00            movem.l d6-d7, -(a7)
  005442:  7e 00                  moveq #$0, d7
  005444:  1e 2d b9 46            move.b -$46ba(a5), d7
  005448:  1c 2d b9 4c            move.b -$46b4(a5), d6
  00544c:  48 86                  ext.w d6
  00544e:  0c 46 00 01            cmpi.w #$1, d6
  005452:  66 0e                  bne.b $5462
  005454:  3b 6d ba cc ba ee      move.w -$4534(a5), -$4512(a5)
  00545a:  3b 6d ba c6 ba ec      move.w -$453a(a5), -$4514(a5)
  005460:  60 14                  bra.b $5476
  005462:  10 2d b9 4b            move.b -$46b5(a5), d0
  005466:  48 80                  ext.w d0
  005468:  3b 40 ba ee            move.w d0, -$4512(a5)
  00546c:  12 2d b9 4a            move.b -$46b6(a5), d1
  005470:  48 81                  ext.w d1
  005472:  3b 41 ba ec            move.w d1, -$4514(a5)
  005476:  0c 47 00 87            cmpi.w #$87, d7
  00547a:  6d 06                  blt.b $5482
  00547c:  0c 47 00 95            cmpi.w #$95, d7
  005480:  6d 18                  blt.b $549a
  005482:  0c 46 00 02            cmpi.w #$2, d6
  005486:  67 12                  beq.b $549a
  005488:  0c 46 00 03            cmpi.w #$3, d6
  00548c:  67 0c                  beq.b $549a
  00548e:  0c 46 00 04            cmpi.w #$4, d6
  005492:  67 06                  beq.b $549a
  005494:  0c 46 00 06            cmpi.w #$6, d6
  005498:  66 04                  bne.b $549e
  00549a:  53 6d ba ec            subq.w #$1, -$4514(a5)
  00549e:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  0054a2:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  0054a6:  4e ba eb e4            jsr $408c(pc)
  0054aa:  1b 40 ba f0            move.b d0, -$4510(a5)
  0054ae:  58 8f                  addq.l #$4, a7
  0054b0:  4c df 00 c0            movem.l (a7)+, d6-d7
  0054b4:  4e 75                  rts 
  0054b6:  4a 2d b9 51            tst.b -$46af(a5)
  0054ba:  66 00 00 f8            bne.w $55b4
  0054be:  4a 6d ba c0            tst.w -$4540(a5)
  0054c2:  67 00 00 f0            beq.w $55b4
  0054c6:  0c 6d ff ff ba c0      cmpi.w #$ffff, -$4540(a5)
  0054cc:  66 20                  bne.b $54ee
  0054ce:  3b 7c ff ff ba 28      move.w #$ffff, -$45d8(a5)
  0054d4:  3f 3c 00 25            move.w #$25, -(a7)
  0054d8:  4e ba b2 da            jsr $7b4(pc)
  0054dc:  3b 7c 00 0b ba 18      move.w #$b, -$45e8(a5)
  0054e2:  3b 7c 00 08 ba 1a      move.w #$8, -$45e6(a5)
  0054e8:  54 8f                  addq.l #$2, a7
  0054ea:  60 00 00 c8            bra.w $55b4
  0054ee:  53 6d ba c0            subq.w #$1, -$4540(a5)
  0054f2:  30 2d ba c0            move.w -$4540(a5), d0
  0054f6:  67 1c                  beq.b $5514
  0054f8:  6b 00 00 ba            bmi.w $55b4
  0054fc:  59 40                  subq.w #$4, d0
  0054fe:  67 00 00 8a            beq.w $558a
  005502:  6a 08                  bpl.b $550c
  005504:  54 40                  addq.w #$2, d0
  005506:  67 5a                  beq.b $5562
  005508:  6a 5e                  bpl.b $5568
  00550a:  60 36                  bra.b $5542
  00550c:  55 40                  subq.w #$2, d0
  00550e:  6a 00 00 a4            bpl.w $55b4
  005512:  60 5a                  bra.b $556e
  005514:  30 2d ba 4a            move.w -$45b6(a5), d0
  005518:  b0 6d ba 48            cmp.w -$45b8(a5), d0
  00551c:  67 00 00 96            beq.w $55b4
  005520:  4e ad 01 02            jsr $102(a5)
  005524:  3f 3c 00 21            move.w #$21, -(a7)
  005528:  4e ba b2 8a            jsr $7b4(pc)
  00552c:  3b 7c 00 01 ba 50      move.w #$1, -$45b0(a5)
  005532:  3b 7c 00 08 ba 18      move.w #$8, -$45e8(a5)
  005538:  3b 7c 00 02 ba 1a      move.w #$2, -$45e6(a5)
  00553e:  54 8f                  addq.l #$2, a7
  005540:  60 72                  bra.b $55b4
  005542:  4e ad 01 02            jsr $102(a5)
  005546:  3f 3c 00 1e            move.w #$1e, -(a7)
  00554a:  4e ba b2 68            jsr $7b4(pc)
  00554e:  3b 7c 00 08 ba 18      move.w #$8, -$45e8(a5)
  005554:  3b 7c 00 04 ba 1a      move.w #$4, -$45e6(a5)
  00555a:  4e ba b1 5a            jsr $6b6(pc)
  00555e:  54 8f                  addq.l #$2, a7
  005560:  60 52                  bra.b $55b4
  005562:  4e ba b5 ec            jsr $b50(pc)
  005566:  60 4c                  bra.b $55b4
  005568:  4e ba b5 cc            jsr $b36(pc)
  00556c:  60 46                  bra.b $55b4
  00556e:  3f 3c 00 01            move.w #$1, -(a7)
  005572:  4e ad 05 4a            jsr $54a(a5)
  005576:  42 a7                  clr.l -(a7)
  005578:  3f 3c 00 08            move.w #$8, -(a7)
  00557c:  4e ba e9 f4            jsr $3f72(pc)
  005580:  42 97                  clr.l (a7)
  005582:  4e ad 04 72            jsr $472(a5)
  005586:  50 8f                  addq.l #$8, a7
  005588:  60 2a                  bra.b $55b4
  00558a:  4e ad 01 02            jsr $102(a5)
  00558e:  3f 3c 00 0d            move.w #$d, -(a7)
  005592:  4e ba b2 20            jsr $7b4(pc)
  005596:  0c 6d 00 0f a9 0c      cmpi.w #$f, -$56f4(a5)
  00559c:  54 8f                  addq.l #$2, a7
  00559e:  66 0e                  bne.b $55ae
  0055a0:  30 2d ba 48            move.w -$45b8(a5), d0
  0055a4:  44 40                  neg.w d0
  0055a6:  52 40                  addq.w #$1, d0
  0055a8:  3b 40 ba 50            move.w d0, -$45b0(a5)
  0055ac:  60 06                  bra.b $55b4
  0055ae:  3b 7c ff ff ba 50      move.w #$ffff, -$45b0(a5)
  0055b4:  4e 75                  rts 
  0055b6:  4e ba 00 40            jsr $55f8(pc)
  0055ba:  4a 00                  tst.b d0
  0055bc:  67 04                  beq.b $55c2
  0055be:  70 01                  moveq #$1, d0
  0055c0:  60 34                  bra.b $55f6
  0055c2:  10 2d b9 46            move.b -$46ba(a5), d0
  0055c6:  67 28                  beq.b $55f0
  0055c8:  6a 16                  bpl.b $55e0
  0055ca:  04 00 00 ab            subi.b #$ab, d0
  0055ce:  67 20                  beq.b $55f0
  0055d0:  6a 06                  bpl.b $55d8
  0055d2:  5a 00                  addq.b #$5, d0
  0055d4:  67 1a                  beq.b $55f0
  0055d6:  60 1c                  bra.b $55f4
  0055d8:  04 00 00 3a            subi.b #$3a, d0
  0055dc:  67 12                  beq.b $55f0
  0055de:  60 14                  bra.b $55f4
  0055e0:  04 00 00 6d            subi.b #$6d, d0
  0055e4:  67 0a                  beq.b $55f0
  0055e6:  6a 0c                  bpl.b $55f4
  0055e8:  04 00 00 a2            subi.b #$a2, d0
  0055ec:  67 02                  beq.b $55f0
  0055ee:  60 04                  bra.b $55f4
  0055f0:  70 01                  moveq #$1, d0
  0055f2:  60 02                  bra.b $55f6
  0055f4:  70 00                  moveq #$0, d0
  0055f6:  4e 75                  rts 
  0055f8:  10 2d b9 46            move.b -$46ba(a5), d0
  0055fc:  6a 14                  bpl.b $5612
  0055fe:  04 00 00 b9            subi.b #$b9, d0
  005602:  67 0a                  beq.b $560e
  005604:  6a 0c                  bpl.b $5612
  005606:  5c 00                  addq.b #$6, d0
  005608:  6a 08                  bpl.b $5612
  00560a:  54 00                  addq.b #$2, d0
  00560c:  6b 04                  bmi.b $5612
  00560e:  70 01                  moveq #$1, d0
  005610:  60 02                  bra.b $5614
  005612:  70 00                  moveq #$0, d0
  005614:  4e 75                  rts 
  005616:  0c 2d 00 01 b9 87      cmpi.b #$1, -$4679(a5)
  00561c:  66 0c                  bne.b $562a
  00561e:  3f 3c 00 20            move.w #$20, -(a7)
  005622:  4e ba b1 90            jsr $7b4(pc)
  005626:  54 8f                  addq.l #$2, a7
  005628:  60 1c                  bra.b $5646
  00562a:  4a 6d ba 26            tst.w -$45da(a5)
  00562e:  67 0c                  beq.b $563c
  005630:  3f 3c 00 1c            move.w #$1c, -(a7)
  005634:  4e ba b1 7e            jsr $7b4(pc)
  005638:  54 8f                  addq.l #$2, a7
  00563a:  60 0a                  bra.b $5646
  00563c:  3f 3c 00 18            move.w #$18, -(a7)
  005640:  4e ba b1 72            jsr $7b4(pc)
  005644:  54 8f                  addq.l #$2, a7
  005646:  4e 75                  rts 
  005648:  4a 6d a9 0c            tst.w -$56f4(a5)
  00564c:  66 10                  bne.b $565e
  00564e:  3b 7c 00 01 ba 40      move.w #$1, -$45c0(a5)
  005654:  42 6d ba 5a            clr.w -$45a6(a5)
  005658:  42 6d ba 5c            clr.w -$45a4(a5)
  00565c:  60 46                  bra.b $56a4
  00565e:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  005664:  66 2c                  bne.b $5692
  005666:  3b 7c 00 07 ba 18      move.w #$7, -$45e8(a5)
  00566c:  3b 7c 00 12 ba 1a      move.w #$12, -$45e6(a5)
  005672:  3b 7c 00 01 ba 42      move.w #$1, -$45be(a5)
  005678:  3b 7c 00 02 ba 3c      move.w #$2, -$45c4(a5)
  00567e:  3f 3c 00 2b            move.w #$2b, -(a7)
  005682:  4e ba b1 30            jsr $7b4(pc)
  005686:  41 ed 96 38            lea.l -$69c8(a5), a0
  00568a:  20 b8 02 0c            move.l $20c.w, (a0)
  00568e:  54 8f                  addq.l #$2, a7
  005690:  60 12                  bra.b $56a4
  005692:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  005698:  67 0a                  beq.b $56a4
  00569a:  3f 3c 00 25            move.w #$25, -(a7)
  00569e:  4e ba b1 14            jsr $7b4(pc)
  0056a2:  54 8f                  addq.l #$2, a7
  0056a4:  4e 75                  rts 
  0056a6:  1b 7c 00 56 b9 49      move.b #$56, -$46b7(a5)
  0056ac:  42 2d b9 4c            clr.b -$46b4(a5)
  0056b0:  42 2d b9 53            clr.b -$46ad(a5)
  0056b4:  3f 2d ba 4c            move.w -$45b4(a5), -(a7)
  0056b8:  42 67                  clr.w -(a7)
  0056ba:  4e ba af 5c            jsr $618(pc)
  0056be:  42 6d ba 4c            clr.w -$45b4(a5)
  0056c2:  58 8f                  addq.l #$4, a7
  0056c4:  4e 75                  rts 
  0056c6:  1b 6d ba f0 bb 06      move.b -$4510(a5), -$44fa(a5)
  0056cc:  1b 6d ba f1 bb 07      move.b -$450f(a5), -$44f9(a5)
  0056d2:  3b 6d ba f2 bb 08      move.w -$450e(a5), -$44f8(a5)
  0056d8:  3b 6d ba f4 bb 0a      move.w -$450c(a5), -$44f6(a5)
  0056de:  3b 6d ba f6 bb 0c      move.w -$450a(a5), -$44f4(a5)
  0056e4:  3b 6d ba f8 bb 0e      move.w -$4508(a5), -$44f2(a5)
  0056ea:  3b 6d ba fa bb 10      move.w -$4506(a5), -$44f0(a5)
  0056f0:  3b 6d ba fc bb 12      move.w -$4504(a5), -$44ee(a5)
  0056f6:  3b 6d ba fe bb 14      move.w -$4502(a5), -$44ec(a5)
  0056fc:  3b 6d bb 00 bb 16      move.w -$4500(a5), -$44ea(a5)
  005702:  3b 6d bb 02 bb 18      move.w -$44fe(a5), -$44e8(a5)
  005708:  3b 6d bb 04 bb 1a      move.w -$44fc(a5), -$44e6(a5)
  00570e:  4e 75                  rts 
  005710:  1b 6d bb 06 ba f0      move.b -$44fa(a5), -$4510(a5)
  005716:  1b 6d bb 07 ba f1      move.b -$44f9(a5), -$450f(a5)
  00571c:  3b 6d bb 08 ba f2      move.w -$44f8(a5), -$450e(a5)
  005722:  3b 6d bb 0a ba f4      move.w -$44f6(a5), -$450c(a5)
  005728:  3b 6d bb 0c ba f6      move.w -$44f4(a5), -$450a(a5)
  00572e:  3b 6d bb 0e ba f8      move.w -$44f2(a5), -$4508(a5)
  005734:  3b 6d bb 10 ba fa      move.w -$44f0(a5), -$4506(a5)
  00573a:  3b 6d bb 12 ba fc      move.w -$44ee(a5), -$4504(a5)
  005740:  3b 6d bb 14 ba fe      move.w -$44ec(a5), -$4502(a5)
  005746:  3b 6d bb 16 bb 00      move.w -$44ea(a5), -$4500(a5)
  00574c:  3b 6d bb 18 bb 02      move.w -$44e8(a5), -$44fe(a5)
  005752:  3b 6d bb 1a bb 04      move.w -$44e6(a5), -$44fc(a5)
  005758:  4e 75                  rts 
  00575a:  48 e7 03 00            movem.l d6-d7, -(a7)
  00575e:  7c 00                  moveq #$0, d6
  005760:  1c 2d b9 46            move.b -$46ba(a5), d6
  005764:  0c 46 00 b2            cmpi.w #$b2, d6
  005768:  67 00 00 90            beq.w $57fa
  00576c:  4e ba ff 58            jsr $56c6(pc)
  005770:  1b 7c 00 ff ba f0      move.b #$ff, -$4510(a5)
  005776:  0c 46 00 b9            cmpi.w #$b9, d6
  00577a:  67 0c                  beq.b $5788
  00577c:  0c 46 00 6a            cmpi.w #$6a, d6
  005780:  6d 16                  blt.b $5798
  005782:  0c 46 00 6f            cmpi.w #$6f, d6
  005786:  6c 10                  bge.b $5798
  005788:  58 6d ba f8            addq.w #$4, -$4508(a5)
  00578c:  3f 3c 00 05            move.w #$5, -(a7)
  005790:  4e ba ea 94            jsr $4226(pc)
  005794:  54 8f                  addq.l #$2, a7
  005796:  60 30                  bra.b $57c8
  005798:  0c 46 00 b1            cmpi.w #$b1, d6
  00579c:  66 0c                  bne.b $57aa
  00579e:  3f 3c ff fb            move.w #$fffb, -(a7)
  0057a2:  4e ba ea 82            jsr $4226(pc)
  0057a6:  54 8f                  addq.l #$2, a7
  0057a8:  60 1e                  bra.b $57c8
  0057aa:  4a 2d b9 51            tst.b -$46af(a5)
  0057ae:  57 c0                  seq.b d0
  0057b0:  44 00                  neg.b d0
  0057b2:  48 80                  ext.w d0
  0057b4:  e5 48                  lsl.w #$2, d0
  0057b6:  06 40 00 0b            addi.w #$b, d0
  0057ba:  91 6d ba f8            sub.w d0, -$4508(a5)
  0057be:  3f 3c 00 05            move.w #$5, -(a7)
  0057c2:  4e ba ea 62            jsr $4226(pc)
  0057c6:  54 8f                  addq.l #$2, a7
  0057c8:  4a 2d b9 51            tst.b -$46af(a5)
  0057cc:  66 0e                  bne.b $57dc
  0057ce:  3b 7c 00 02 ba f2      move.w #$2, -$450e(a5)
  0057d4:  3b 7c 00 da ba f4      move.w #$da, -$450c(a5)
  0057da:  60 0c                  bra.b $57e8
  0057dc:  3b 7c 00 05 ba f2      move.w #$5, -$450e(a5)
  0057e2:  3b 7c 00 01 ba f4      move.w #$1, -$450c(a5)
  0057e8:  4e ba ed 7e            jsr $4568(pc)
  0057ec:  1f 3c 00 05            move.b #$5, -(a7)
  0057f0:  4e ad 05 1a            jsr $51a(a5)
  0057f4:  4e ba ff 1a            jsr $5710(pc)
  0057f8:  54 8f                  addq.l #$2, a7
  0057fa:  4c df 00 c0            movem.l (a7)+, d6-d7
  0057fe:  4e 75                  rts 
  005800:  0c 6d 00 0c a9 0c      cmpi.w #$c, -$56f4(a5)
  005806:  66 34                  bne.b $583c
  005808:  10 2d b9 63            move.b -$469d(a5), d0
  00580c:  48 80                  ext.w d0
  00580e:  12 2d b9 51            move.b -$46af(a5), d1
  005812:  48 81                  ext.w d1
  005814:  80 41                  or.w d1, d0
  005816:  53 40                  subq.w #$1, d0
  005818:  66 22                  bne.b $583c
  00581a:  4a 2d b9 53            tst.b -$46ad(a5)
  00581e:  6c 1c                  bge.b $583c
  005820:  4a 2d b9 65            tst.b -$469b(a5)
  005824:  6d 16                  blt.b $583c
  005826:  3b 7c 00 07 ba 18      move.w #$7, -$45e8(a5)
  00582c:  3b 7c 00 05 ba 1a      move.w #$5, -$45e6(a5)
  005832:  3f 3c 00 64            move.w #$64, -(a7)
  005836:  4e ba ee ce            jsr $4706(pc)
  00583a:  54 8f                  addq.l #$2, a7
  00583c:  4e 75                  rts 
  00583e:  48 e7 01 08            movem.l d7/a4, -(a7)
  005842:  7e 00                  moveq #$0, d7
  005844:  1e 2d b9 46            move.b -$46ba(a5), d7
  005848:  0c 47 00 e5            cmpi.w #$e5, d7
  00584c:  6d 06                  blt.b $5854
  00584e:  0c 47 00 ee            cmpi.w #$ee, d7
  005852:  6d 14                  blt.b $5868
  005854:  4a 2d b9 52            tst.b -$46ae(a5)
  005858:  66 0e                  bne.b $5868
  00585a:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  005860:  66 60                  bne.b $58c2
  005862:  4a 2d b9 53            tst.b -$46ad(a5)
  005866:  6c 5a                  bge.b $58c2
  005868:  7e 00                  moveq #$0, d7
  00586a:  1e 2d b9 8f            move.b -$4671(a5), d7
  00586e:  02 47 00 3f            andi.w #$3f, d7
  005872:  4a 47                  tst.w d7
  005874:  67 4c                  beq.b $58c2
  005876:  20 07                  move.l d7, d0
  005878:  48 c0                  ext.l d0
  00587a:  e5 88                  lsl.l #$2, d0
  00587c:  49 ed b3 34            lea.l -$4ccc(a5), a4
  005880:  d0 8c                  add.l a4, d0
  005882:  28 40                  movea.l d0, a4
  005884:  70 00                  moveq #$0, d0
  005886:  10 14                  move.b (a4), d0
  005888:  3b 40 ba f4            move.w d0, -$450c(a5)
  00588c:  0c 40 00 ff            cmpi.w #$ff, d0
  005890:  67 30                  beq.b $58c2
  005892:  3f 2d ba f6            move.w -$450a(a5), -(a7)
  005896:  4e ad 05 2a            jsr $52a(a5)
  00589a:  3b 40 ba f6            move.w d0, -$450a(a5)
  00589e:  12 2c 00 01            move.b $1(a4), d1
  0058a2:  48 81                  ext.w d1
  0058a4:  3e 81                  move.w d1, (a7)
  0058a6:  4e ba e9 7e            jsr $4226(pc)
  0058aa:  10 2c 00 02            move.b $2(a4), d0
  0058ae:  48 80                  ext.w d0
  0058b0:  d1 6d ba f8            add.w d0, -$4508(a5)
  0058b4:  42 6d ba f2            clr.w -$450e(a5)
  0058b8:  1e bc 00 03            move.b #$3, (a7)
  0058bc:  4e ad 05 1a            jsr $51a(a5)
  0058c0:  54 8f                  addq.l #$2, a7
  0058c2:  4c df 10 80            movem.l (a7)+, d7/a4
  0058c6:  4e 75                  rts 
  0058c8:  0c 2d 00 a6 b9 46      cmpi.b #$a6, -$46ba(a5)
  0058ce:  66 22                  bne.b $58f2
  0058d0:  4a 2d ba ad            tst.b -$4553(a5)
  0058d4:  6c 1c                  bge.b $58f2
  0058d6:  4a 2d ba aa            tst.b -$4556(a5)
  0058da:  6c 06                  bge.b $58e2
  0058dc:  4e ad 05 72            jsr $572(a5)
  0058e0:  60 10                  bra.b $58f2
  0058e2:  1b 7c 00 01 ba ad      move.b #$1, -$4553(a5)
  0058e8:  3f 3c 00 50            move.w #$50, -(a7)
  0058ec:  4e ad 05 52            jsr $552(a5)
  0058f0:  54 8f                  addq.l #$2, a7
  0058f2:  4e 75                  rts 
  0058f4:  2f 07                  move.l d7, -(a7)
  0058f6:  10 2d b9 4f            move.b -$46b1(a5), d0
  0058fa:  b0 2d b9 61            cmp.b -$469f(a5), d0
  0058fe:  67 06                  beq.b $5906
  005900:  30 3c 03 e7            move.w #$3e7, d0
  005904:  60 2a                  bra.b $5930
  005906:  70 00                  moveq #$0, d0
  005908:  10 2d b9 47            move.b -$46b9(a5), d0
  00590c:  7e 00                  moveq #$0, d7
  00590e:  1e 2d b9 59            move.b -$46a7(a5), d7
  005912:  9e 40                  sub.w d0, d7
  005914:  4a 2d b9 49            tst.b -$46b7(a5)
  005918:  6c 02                  bge.b $591c
  00591a:  44 47                  neg.w d7
  00591c:  4a 47                  tst.w d7
  00591e:  6d 0e                  blt.b $592e
  005920:  10 2d b9 49            move.b -$46b7(a5), d0
  005924:  b0 2d b9 5b            cmp.b -$46a5(a5), d0
  005928:  67 04                  beq.b $592e
  00592a:  06 47 00 0d            addi.w #$d, d7
  00592e:  30 07                  move.w d7, d0
  005930:  2e 1f                  move.l (a7)+, d7
  005932:  4e 75                  rts 
  005934:  52 2d b9 4b            addq.b #$1, -$46b5(a5)
  005938:  4e 75                  rts 