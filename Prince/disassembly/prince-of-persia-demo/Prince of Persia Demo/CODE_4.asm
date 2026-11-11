; prince-of-persia-demo: Prince of Persia Demo, CODE resource 4 (23682 bytes)
; 68000 disassembly (linear sweep). Code starts after the 4-byte segment header.
; Words $Axxx are Mac Toolbox/OS traps; known ones are annotated. Globals are (a5)-relative.

  000004:  4e 56 00 00            link.w a6, #$0
  000008:  20 4d                  movea.l a5, a0
  00000a:  d0 ee 00 08            adda.w $8(a6), a0
  00000e:  70 00                  moveq #$0, d0
  000010:  10 28 ff 8c            move.b -$74(a0), d0
  000014:  20 4d                  movea.l a5, a0
  000016:  e5 88                  lsl.l #$2, d0
  000018:  d1 c0                  adda.l d0, a0
  00001a:  2b 68 fc e4 b9 54      move.l -$31c(a0), -$46ac(a5)
  000020:  4e 5e                  unlk a6
  000022:  4e 75                  rts 
  000024:  4e 56 00 00            link.w a6, #$0
  000028:  20 4d                  movea.l a5, a0
  00002a:  d0 ee 00 08            adda.w $8(a6), a0
  00002e:  70 00                  moveq #$0, d0
  000030:  10 28 ff 8c            move.b -$74(a0), d0
  000034:  20 4d                  movea.l a5, a0
  000036:  e5 88                  lsl.l #$2, d0
  000038:  d1 c0                  adda.l d0, a0
  00003a:  2b 68 fc e4 b9 66      move.l -$31c(a0), -$469a(a5)
  000040:  4e 5e                  unlk a6
  000042:  4e 75                  rts 
  000044:  2f 07                  move.l d7, -(a7)
  000046:  7e 00                  moveq #$0, d7
  000048:  1e 2d b9 48            move.b -$46b8(a5), d7
  00004c:  4a 6d ba 58            tst.w -$45a8(a5)
  000050:  66 18                  bne.b $6a
  000052:  0c 2d 00 1f b9 4e      cmpi.b #$1f, -$46b2(a5)
  000058:  6d 10                  blt.b $6a
  00005a:  3f 3c 00 01            move.w #$1, -(a7)
  00005e:  4e ad 03 92            jsr $392(a5)
  000062:  3b 7c 00 01 ba 58      move.w #$1, -$45a8(a5)
  000068:  54 8f                  addq.l #$2, a7
  00006a:  10 2d b9 4b            move.b -$46b5(a5), d0
  00006e:  48 80                  ext.w d0
  000070:  20 4d                  movea.l a5, a0
  000072:  d0 c0                  adda.w d0, a0
  000074:  d0 c0                  adda.w d0, a0
  000076:  be 68 b6 70            cmp.w -$4990(a0), d7
  00007a:  6c 06                  bge.b $82
  00007c:  4e ad 02 ca            jsr $2ca(a5)
  000080:  60 2e                  bra.b $b0
  000082:  4e ad 02 ba            jsr $2ba(a5)
  000086:  72 00                  moveq #$0, d1
  000088:  12 00                  move.b d0, d1
  00008a:  0c 41 00 14            cmpi.w #$14, d1
  00008e:  66 04                  bne.b $94
  000090:  4e ad 02 d2            jsr $2d2(a5)
  000094:  70 00                  moveq #$0, d0
  000096:  10 2d ba e8            move.b -$4518(a5), d0
  00009a:  3f 00                  move.w d0, -(a7)
  00009c:  4e ad 02 aa            jsr $2aa(a5)
  0000a0:  4a 00                  tst.b d0
  0000a2:  54 8f                  addq.l #$2, a7
  0000a4:  67 06                  beq.b $ac
  0000a6:  4e ba 00 0c            jsr $b4(pc)
  0000aa:  60 04                  bra.b $b0
  0000ac:  4e ad 03 72            jsr $372(a5)
  0000b0:  2e 1f                  move.l (a7)+, d7
  0000b2:  4e 75                  rts 
  0000b4:  2f 07                  move.l d7, -(a7)
  0000b6:  42 6d ba 58            clr.w -$45a8(a5)
  0000ba:  10 2d b9 4b            move.b -$46b5(a5), d0
  0000be:  48 80                  ext.w d0
  0000c0:  20 4d                  movea.l a5, a0
  0000c2:  d0 c0                  adda.w d0, a0
  0000c4:  d0 c0                  adda.w d0, a0
  0000c6:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  0000cc:  4e ad 02 ba            jsr $2ba(a5)
  0000d0:  72 00                  moveq #$0, d1
  0000d2:  12 00                  move.b d0, d1
  0000d4:  55 41                  subq.w #$2, d1
  0000d6:  67 58                  beq.b $130
  0000d8:  4e ad 02 da            jsr $2da(a5)
  0000dc:  72 00                  moveq #$0, d1
  0000de:  12 00                  move.b d0, d1
  0000e0:  3f 01                  move.w d1, -(a7)
  0000e2:  4e ad 02 aa            jsr $2aa(a5)
  0000e6:  4a 00                  tst.b d0
  0000e8:  54 8f                  addq.l #$2, a7
  0000ea:  66 16                  bne.b $102
  0000ec:  4e ad 02 ea            jsr $2ea(a5)
  0000f0:  57 40                  subq.w #$3, d0
  0000f2:  6c 0e                  bge.b $102
  0000f4:  3f 3c ff fd            move.w #$fffd, -(a7)
  0000f8:  4e ad 02 62            jsr $262(a5)
  0000fc:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000100:  54 8f                  addq.l #$2, a7
  000102:  4e ba 29 74            jsr $2a78(pc)
  000106:  4a 2d b9 53            tst.b -$46ad(a5)
  00010a:  6c 00 00 aa            bge.w $1b6
  00010e:  4e ad 02 ea            jsr $2ea(a5)
  000112:  0c 40 00 0c            cmpi.w #$c, d0
  000116:  6d 0c                  blt.b $124
  000118:  4e ad 02 e2            jsr $2e2(a5)
  00011c:  72 00                  moveq #$0, d1
  00011e:  12 00                  move.b d0, d1
  000120:  55 41                  subq.w #$2, d1
  000122:  67 0c                  beq.b $130
  000124:  4e ad 02 ba            jsr $2ba(a5)
  000128:  72 00                  moveq #$0, d1
  00012a:  12 00                  move.b d0, d1
  00012c:  55 41                  subq.w #$2, d1
  00012e:  66 10                  bne.b $140
  000130:  4e ba 2f 7c            jsr $30ae(pc)
  000134:  4a 40                  tst.w d0
  000136:  67 08                  beq.b $140
  000138:  4e ba 00 a4            jsr $1de(pc)
  00013c:  60 00 00 9c            bra.w $1da
  000140:  0c 2d 00 16 b9 4e      cmpi.b #$16, -$46b2(a5)
  000146:  6c 34                  bge.b $17c
  000148:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  00014e:  6c 08                  bge.b $158
  000150:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  000156:  66 0a                  bne.b $162
  000158:  1b 7c 00 02 b9 52      move.b #$2, -$46ae(a5)
  00015e:  7e 3f                  moveq #$3f, d7
  000160:  60 02                  bra.b $164
  000162:  7e 11                  moveq #$11, d7
  000164:  4a 2d b9 51            tst.b -$46af(a5)
  000168:  66 60                  bne.b $1ca
  00016a:  3f 3c 00 11            move.w #$11, -(a7)
  00016e:  4e ad 03 92            jsr $392(a5)
  000172:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  000178:  54 8f                  addq.l #$2, a7
  00017a:  60 4e                  bra.b $1ca
  00017c:  0c 2d 00 21 b9 4e      cmpi.b #$21, -$46b2(a5)
  000182:  6c 32                  bge.b $1b6
  000184:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  00018a:  67 bc                  beq.b $148
  00018c:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  000192:  67 22                  beq.b $1b6
  000194:  3f 3c 00 01            move.w #$1, -(a7)
  000198:  4e ad 02 b2            jsr $2b2(a5)
  00019c:  4a 40                  tst.w d0
  00019e:  54 8f                  addq.l #$2, a7
  0001a0:  66 1e                  bne.b $1c0
  0001a2:  3f 3c 00 10            move.w #$10, -(a7)
  0001a6:  4e ad 03 92            jsr $392(a5)
  0001aa:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  0001b0:  7e 14                  moveq #$14, d7
  0001b2:  54 8f                  addq.l #$2, a7
  0001b4:  60 14                  bra.b $1ca
  0001b6:  3f 3c 00 64            move.w #$64, -(a7)
  0001ba:  4e ad 02 b2            jsr $2b2(a5)
  0001be:  54 8f                  addq.l #$2, a7
  0001c0:  42 67                  clr.w -(a7)
  0001c2:  4e ad 03 92            jsr $392(a5)
  0001c6:  7e 16                  moveq #$16, d7
  0001c8:  54 8f                  addq.l #$2, a7
  0001ca:  3f 07                  move.w d7, -(a7)
  0001cc:  4e ba fe 36            jsr $4(pc)
  0001d0:  4e ad 02 6a            jsr $26a(a5)
  0001d4:  42 2d b9 4e            clr.b -$46b2(a5)
  0001d8:  54 8f                  addq.l #$2, a7
  0001da:  2e 1f                  move.l (a7)+, d7
  0001dc:  4e 75                  rts 
  0001de:  70 00                  moveq #$0, d0
  0001e0:  10 2d ba e9            move.b -$4517(a5), d0
  0001e4:  d0 ad bd 86            add.l -$427a(a5), d0
  0001e8:  20 40                  movea.l d0, a0
  0001ea:  10 bc 00 ff            move.b #$ff, (a0)
  0001ee:  10 2d b9 4b            move.b -$46b5(a5), d0
  0001f2:  48 80                  ext.w d0
  0001f4:  20 4d                  movea.l a5, a0
  0001f6:  d0 c0                  adda.w d0, a0
  0001f8:  d0 c0                  adda.w d0, a0
  0001fa:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  000200:  30 2d ba ec            move.w -$4514(a5), d0
  000204:  20 4d                  movea.l a5, a0
  000206:  d0 c0                  adda.w d0, a0
  000208:  72 07                  moveq #$7, d1
  00020a:  d2 28 b8 7d            add.b -$4783(a0), d1
  00020e:  56 01                  addq.b #$3, d1
  000210:  1b 41 b9 47            move.b d1, -$46b9(a5)
  000214:  3f 3c 00 08            move.w #$8, -(a7)
  000218:  4e ad 02 62            jsr $262(a5)
  00021c:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000220:  42 2d b9 4e            clr.b -$46b2(a5)
  000224:  3e bc 00 30            move.w #$30, (a7)
  000228:  4e ad 03 92            jsr $392(a5)
  00022c:  3e bc 00 64            move.w #$64, (a7)
  000230:  4e ad 02 b2            jsr $2b2(a5)
  000234:  3e bc 00 33            move.w #$33, (a7)
  000238:  4e ba fd ca            jsr $4(pc)
  00023c:  4e ad 02 6a            jsr $26a(a5)
  000240:  54 8f                  addq.l #$2, a7
  000242:  4e 75                  rts 
  000244:  48 e7 03 00            movem.l d6-d7, -(a7)
  000248:  7e 00                  moveq #$0, d7
  00024a:  1e 2d b9 46            move.b -$46ba(a5), d7
  00024e:  4a 2d b9 53            tst.b -$46ad(a5)
  000252:  6d 26                  blt.b $27a
  000254:  0c 47 00 0f            cmpi.w #$f, d7
  000258:  67 12                  beq.b $26c
  00025a:  0c 47 00 a6            cmpi.w #$a6, d7
  00025e:  67 0c                  beq.b $26c
  000260:  0c 47 00 9e            cmpi.w #$9e, d7
  000264:  67 06                  beq.b $26c
  000266:  0c 47 00 ab            cmpi.w #$ab, d7
  00026a:  66 0e                  bne.b $27a
  00026c:  3f 3c 00 47            move.w #$47, -(a7)
  000270:  4e ba fd 92            jsr $4(pc)
  000274:  54 8f                  addq.l #$2, a7
  000276:  60 00 00 a2            bra.w $31a
  00027a:  1c 2d b9 4c            move.b -$46b4(a5), d6
  00027e:  48 86                  ext.w d6
  000280:  0c 46 00 05            cmpi.w #$5, d6
  000284:  67 06                  beq.b $28c
  000286:  0c 46 00 04            cmpi.w #$4, d6
  00028a:  66 08                  bne.b $294
  00028c:  4e ad 02 fa            jsr $2fa(a5)
  000290:  60 00 00 88            bra.w $31a
  000294:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  00029a:  66 06                  bne.b $2a2
  00029c:  4e ba 0a 7c            jsr $d1a(pc)
  0002a0:  60 78                  bra.b $31a
  0002a2:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  0002a8:  6d 06                  blt.b $2b0
  0002aa:  4e ad 03 62            jsr $362(a5)
  0002ae:  60 6a                  bra.b $31a
  0002b0:  0c 47 00 0f            cmpi.w #$f, d7
  0002b4:  67 0c                  beq.b $2c2
  0002b6:  0c 47 00 32            cmpi.w #$32, d7
  0002ba:  6d 0c                  blt.b $2c8
  0002bc:  0c 47 00 35            cmpi.w #$35, d7
  0002c0:  6c 06                  bge.b $2c8
  0002c2:  4e ba 00 d0            jsr $394(pc)
  0002c6:  60 52                  bra.b $31a
  0002c8:  0c 47 00 30            cmpi.w #$30, d7
  0002cc:  66 06                  bne.b $2d4
  0002ce:  4e ba 03 3c            jsr $60c(pc)
  0002d2:  60 46                  bra.b $31a
  0002d4:  0c 47 00 04            cmpi.w #$4, d7
  0002d8:  6c 06                  bge.b $2e0
  0002da:  4e ba 05 94            jsr $870(pc)
  0002de:  60 3a                  bra.b $31a
  0002e0:  0c 47 00 43            cmpi.w #$43, d7
  0002e4:  6d 0c                  blt.b $2f2
  0002e6:  0c 47 00 46            cmpi.w #$46, d7
  0002ea:  6c 06                  bge.b $2f2
  0002ec:  4e ba 05 94            jsr $882(pc)
  0002f0:  60 28                  bra.b $31a
  0002f2:  0c 47 00 0f            cmpi.w #$f, d7
  0002f6:  6c 06                  bge.b $2fe
  0002f8:  4e ba 03 c0            jsr $6ba(pc)
  0002fc:  60 1c                  bra.b $31a
  0002fe:  0c 47 00 57            cmpi.w #$57, d7
  000302:  6d 0c                  blt.b $310
  000304:  0c 47 00 64            cmpi.w #$64, d7
  000308:  6c 06                  bge.b $310
  00030a:  4e ba 06 e8            jsr $9f4(pc)
  00030e:  60 0a                  bra.b $31a
  000310:  0c 47 00 6d            cmpi.w #$6d, d7
  000314:  66 04                  bne.b $31a
  000316:  4e ba 00 08            jsr $320(pc)
  00031a:  4c df 00 c0            movem.l (a7)+, d6-d7
  00031e:  4e 75                  rts 
  000320:  4a 6d ba 98            tst.w -$4568(a5)
  000324:  67 30                  beq.b $356
  000326:  0c 6d 00 01 a9 0c      cmpi.w #$1, -$56f4(a5)
  00032c:  66 28                  bne.b $356
  00032e:  4e ad 01 02            jsr $102(a5)
  000332:  4a 00                  tst.b d0
  000334:  66 5c                  bne.b $392
  000336:  0c 6d 00 01 ba 98      cmpi.w #$1, -$4568(a5)
  00033c:  66 12                  bne.b $350
  00033e:  3f 3c 00 19            move.w #$19, -(a7)
  000342:  4e ad 03 92            jsr $392(a5)
  000346:  3b 7c 00 02 ba 98      move.w #$2, -$4568(a5)
  00034c:  54 8f                  addq.l #$2, a7
  00034e:  60 42                  bra.b $392
  000350:  42 6d ba 98            clr.w -$4568(a5)
  000354:  60 3c                  bra.b $392
  000356:  42 6d ba 98            clr.w -$4568(a5)
  00035a:  4a 2d ba ae            tst.b -$4552(a5)
  00035e:  6c 08                  bge.b $368
  000360:  4e ba 04 1c            jsr $77e(pc)
  000364:  4a 40                  tst.w d0
  000366:  66 2a                  bne.b $392
  000368:  0c 2d 00 01 ba ba      cmpi.b #$1, -$4546(a5)
  00036e:  67 0c                  beq.b $37c
  000370:  3f 3c 00 31            move.w #$31, -(a7)
  000374:  4e ba fc 8e            jsr $4(pc)
  000378:  54 8f                  addq.l #$2, a7
  00037a:  60 16                  bra.b $392
  00037c:  4a 2d ba aa            tst.b -$4556(a5)
  000380:  6c 10                  bge.b $392
  000382:  1b 7c 00 01 ba aa      move.b #$1, -$4556(a5)
  000388:  3f 3c 00 4f            move.w #$4f, -(a7)
  00038c:  4e ba fc 76            jsr $4(pc)
  000390:  54 8f                  addq.l #$2, a7
  000392:  4e 75                  rts 
  000394:  2f 07                  move.l d7, -(a7)
  000396:  4a 2d ba ae            tst.b -$4552(a5)
  00039a:  6c 10                  bge.b $3ac
  00039c:  4a 2d ba bb            tst.b -$4545(a5)
  0003a0:  6c 0a                  bge.b $3ac
  0003a2:  4e ba 03 da            jsr $77e(pc)
  0003a6:  4a 40                  tst.w d0
  0003a8:  66 00 01 32            bne.w $4dc
  0003ac:  4a 2d b9 51            tst.b -$46af(a5)
  0003b0:  67 14                  beq.b $3c6
  0003b2:  4a 2d ba ad            tst.b -$4553(a5)
  0003b6:  6c 0e                  bge.b $3c6
  0003b8:  4a 2d ba aa            tst.b -$4556(a5)
  0003bc:  6c 08                  bge.b $3c6
  0003be:  4e ba 09 18            jsr $cd8(pc)
  0003c2:  60 00 01 18            bra.w $4dc
  0003c6:  4a 6d ba 28            tst.w -$45d8(a5)
  0003ca:  67 74                  beq.b $440
  0003cc:  4a 6d ba 36            tst.w -$45ca(a5)
  0003d0:  67 08                  beq.b $3da
  0003d2:  4a 2d ba bb            tst.b -$4545(a5)
  0003d6:  6c 00 00 a6            bge.w $47e
  0003da:  0c 6d 00 02 ba 24      cmpi.w #$2, -$45dc(a5)
  0003e0:  6c 06                  bge.b $3e8
  0003e2:  42 6d ba 36            clr.w -$45ca(a5)
  0003e6:  60 58                  bra.b $440
  0003e8:  4e ad 03 6a            jsr $36a(a5)
  0003ec:  3e 00                  move.w d0, d7
  0003ee:  0c 47 ff f6            cmpi.w #$fff6, d7
  0003f2:  6d 4c                  blt.b $440
  0003f4:  0c 47 00 5a            cmpi.w #$5a, d7
  0003f8:  6c 46                  bge.b $440
  0003fa:  3b 7c 00 01 ba 26      move.w #$1, -$45da(a5)
  000400:  0c 47 ff fa            cmpi.w #$fffa, d7
  000404:  6d 0c                  blt.b $412
  000406:  4a 47                  tst.w d7
  000408:  6c 08                  bge.b $412
  00040a:  4e ba 02 32            jsr $63e(pc)
  00040e:  60 00 00 cc            bra.w $4dc
  000412:  0c 2d 00 01 b9 63      cmpi.b #$1, -$469d(a5)
  000418:  66 1e                  bne.b $438
  00041a:  0c 2d 00 03 b9 5e      cmpi.b #$3, -$46a2(a5)
  000420:  67 10                  beq.b $432
  000422:  0c 2d 00 6b b9 58      cmpi.b #$6b, -$46a8(a5)
  000428:  65 0e                  bcs.b $438
  00042a:  0c 2d 00 76 b9 58      cmpi.b #$76, -$46a8(a5)
  000430:  64 06                  bcc.b $438
  000432:  42 6d ba 36            clr.w -$45ca(a5)
  000436:  60 08                  bra.b $440
  000438:  4e ba 08 9e            jsr $cd8(pc)
  00043c:  60 00 00 9e            bra.w $4dc
  000440:  4a 2d ba bb            tst.b -$4545(a5)
  000444:  6c 38                  bge.b $47e
  000446:  4a 2d ba ab            tst.b -$4555(a5)
  00044a:  6c 08                  bge.b $454
  00044c:  4e ba 01 f0            jsr $63e(pc)
  000450:  60 00 00 8a            bra.w $4dc
  000454:  4a 2d ba ac            tst.b -$4554(a5)
  000458:  6c 06                  bge.b $460
  00045a:  4e ba 00 84            jsr $4e0(pc)
  00045e:  60 7c                  bra.b $4dc
  000460:  4a 2d ba ad            tst.b -$4553(a5)
  000464:  6c 06                  bge.b $46c
  000466:  4e ba 00 cc            jsr $534(pc)
  00046a:  60 70                  bra.b $4dc
  00046c:  4a 2d ba b9            tst.b -$4547(a5)
  000470:  6c 6a                  bge.b $4dc
  000472:  4a 2d ba aa            tst.b -$4556(a5)
  000476:  6c 64                  bge.b $4dc
  000478:  4e ba 02 ae            jsr $728(pc)
  00047c:  60 5e                  bra.b $4dc
  00047e:  4a 2d ba aa            tst.b -$4556(a5)
  000482:  6c 18                  bge.b $49c
  000484:  4a 6d a5 bc            tst.w -$5a44(a5)
  000488:  67 0c                  beq.b $496
  00048a:  4a 2d ba ac            tst.b -$4554(a5)
  00048e:  6c 06                  bge.b $496
  000490:  4e ba 04 02            jsr $894(pc)
  000494:  60 46                  bra.b $4dc
  000496:  4e ba 01 ea            jsr $682(pc)
  00049a:  60 40                  bra.b $4dc
  00049c:  4a 2d ba ab            tst.b -$4555(a5)
  0004a0:  6c 06                  bge.b $4a8
  0004a2:  4e ba 01 9a            jsr $63e(pc)
  0004a6:  60 34                  bra.b $4dc
  0004a8:  4a 2d ba ac            tst.b -$4554(a5)
  0004ac:  6c 18                  bge.b $4c6
  0004ae:  4a 6d a5 bc            tst.w -$5a44(a5)
  0004b2:  67 0c                  beq.b $4c0
  0004b4:  4a 2d ba aa            tst.b -$4556(a5)
  0004b8:  6c 06                  bge.b $4c0
  0004ba:  4e ba 03 d8            jsr $894(pc)
  0004be:  60 1c                  bra.b $4dc
  0004c0:  4e ba 00 1e            jsr $4e0(pc)
  0004c4:  60 16                  bra.b $4dc
  0004c6:  4a 2d ba ad            tst.b -$4553(a5)
  0004ca:  6c 06                  bge.b $4d2
  0004cc:  4e ba 00 66            jsr $534(pc)
  0004d0:  60 0a                  bra.b $4dc
  0004d2:  4a 2d ba b9            tst.b -$4547(a5)
  0004d6:  6c 04                  bge.b $4dc
  0004d8:  4e ba 01 a8            jsr $682(pc)
  0004dc:  2e 1f                  move.l (a7)+, d7
  0004de:  4e 75                  rts 
  0004e0:  4e ad 02 ba            jsr $2ba(a5)
  0004e4:  72 00                  moveq #$0, d1
  0004e6:  12 00                  move.b d0, d1
  0004e8:  0c 41 00 10            cmpi.w #$10, d1
  0004ec:  67 1c                  beq.b $50a
  0004ee:  4e ad 02 e2            jsr $2e2(a5)
  0004f2:  72 00                  moveq #$0, d1
  0004f4:  12 00                  move.b d0, d1
  0004f6:  0c 41 00 10            cmpi.w #$10, d1
  0004fa:  67 0e                  beq.b $50a
  0004fc:  4e ad 02 da            jsr $2da(a5)
  000500:  72 00                  moveq #$0, d1
  000502:  12 00                  move.b d0, d1
  000504:  0c 41 00 10            cmpi.w #$10, d1
  000508:  66 18                  bne.b $522
  00050a:  70 00                  moveq #$0, d0
  00050c:  10 2d f1 5e            move.b -$ea2(a5), d0
  000510:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  000514:  67 0c                  beq.b $522
  000516:  4a 6d ba 3c            tst.w -$45c4(a5)
  00051a:  67 06                  beq.b $522
  00051c:  4e ba 00 ca            jsr $5e8(pc)
  000520:  60 10                  bra.b $532
  000522:  4a 2d ba b9            tst.b -$4547(a5)
  000526:  6c 06                  bge.b $52e
  000528:  4e ba 03 6a            jsr $894(pc)
  00052c:  60 04                  bra.b $532
  00052e:  4e ba 03 7a            jsr $8aa(pc)
  000532:  4e 75                  rts 
  000534:  1b 7c 00 01 ba ad      move.b #$1, -$4553(a5)
  00053a:  4e ad 02 da            jsr $2da(a5)
  00053e:  72 00                  moveq #$0, d1
  000540:  12 00                  move.b d0, d1
  000542:  3f 01                  move.w d1, -(a7)
  000544:  4e ad 02 aa            jsr $2aa(a5)
  000548:  4a 00                  tst.b d0
  00054a:  54 8f                  addq.l #$2, a7
  00054c:  66 1c                  bne.b $56a
  00054e:  4e ad 02 ea            jsr $2ea(a5)
  000552:  57 40                  subq.w #$3, d0
  000554:  6c 14                  bge.b $56a
  000556:  3f 3c 00 05            move.w #$5, -(a7)
  00055a:  4e ad 02 62            jsr $262(a5)
  00055e:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000562:  4e ad 02 42            jsr $242(a5)
  000566:  54 8f                  addq.l #$2, a7
  000568:  60 7c                  bra.b $5e6
  00056a:  4e ad 02 e2            jsr $2e2(a5)
  00056e:  72 00                  moveq #$0, d1
  000570:  12 00                  move.b d0, d1
  000572:  3f 01                  move.w d1, -(a7)
  000574:  4e ad 02 aa            jsr $2aa(a5)
  000578:  4a 00                  tst.b d0
  00057a:  54 8f                  addq.l #$2, a7
  00057c:  66 64                  bne.b $5e2
  00057e:  4e ad 02 ea            jsr $2ea(a5)
  000582:  51 40                  subq.w #$8, d0
  000584:  6d 5c                  blt.b $5e2
  000586:  4e ad 02 e2            jsr $2e2(a5)
  00058a:  1b 40 ba bd            move.b d0, -$4543(a5)
  00058e:  4e ad 02 ba            jsr $2ba(a5)
  000592:  4e ad 03 02            jsr $302(a5)
  000596:  4a 40                  tst.w d0
  000598:  67 48                  beq.b $5e2
  00059a:  4a 2d b9 49            tst.b -$46b7(a5)
  00059e:  6c 24                  bge.b $5c4
  0005a0:  4e ad 02 ba            jsr $2ba(a5)
  0005a4:  72 00                  moveq #$0, d1
  0005a6:  12 00                  move.b d0, d1
  0005a8:  59 41                  subq.w #$4, d1
  0005aa:  66 18                  bne.b $5c4
  0005ac:  70 00                  moveq #$0, d0
  0005ae:  10 2d ba e9            move.b -$4517(a5), d0
  0005b2:  d0 ad bd 86            add.l -$427a(a5), d0
  0005b6:  20 40                  movea.l d0, a0
  0005b8:  70 00                  moveq #$0, d0
  0005ba:  10 10                  move.b (a0), d0
  0005bc:  81 fc 00 04            divs.w #$4, d0
  0005c0:  5d 40                  subq.w #$6, d0
  0005c2:  6d 1e                  blt.b $5e2
  0005c4:  4e ad 02 ea            jsr $2ea(a5)
  0005c8:  06 40 ff f7            addi.w #$fff7, d0
  0005cc:  3f 00                  move.w d0, -(a7)
  0005ce:  4e ad 02 62            jsr $262(a5)
  0005d2:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0005d6:  3e bc 00 44            move.w #$44, (a7)
  0005da:  4e ba fa 28            jsr $4(pc)
  0005de:  54 8f                  addq.l #$2, a7
  0005e0:  60 04                  bra.b $5e6
  0005e2:  4e ba 00 46            jsr $62a(pc)
  0005e6:  4e 75                  rts 
  0005e8:  30 2d ba ec            move.w -$4514(a5), d0
  0005ec:  20 4d                  movea.l a5, a0
  0005ee:  d0 c0                  adda.w d0, a0
  0005f0:  72 0a                  moveq #$a, d1
  0005f2:  d2 28 b8 7d            add.b -$4783(a0), d1
  0005f6:  1b 41 b9 47            move.b d1, -$46b9(a5)
  0005fa:  1b 7c 00 ff b9 49      move.b #$ff, -$46b7(a5)
  000600:  3f 3c 00 46            move.w #$46, -(a7)
  000604:  4e ba f9 fe            jsr $4(pc)
  000608:  54 8f                  addq.l #$2, a7
  00060a:  4e 75                  rts 
  00060c:  4a 2d ba bb            tst.b -$4545(a5)
  000610:  6d 16                  blt.b $628
  000612:  4a 2d ba b9            tst.b -$4547(a5)
  000616:  6c 10                  bge.b $628
  000618:  4a 2d ba ba            tst.b -$4546(a5)
  00061c:  6d 0a                  blt.b $628
  00061e:  3f 3c 00 2b            move.w #$2b, -(a7)
  000622:  4e ba f9 e0            jsr $4(pc)
  000626:  54 8f                  addq.l #$2, a7
  000628:  4e 75                  rts 
  00062a:  3f 3c 00 32            move.w #$32, -(a7)
  00062e:  4e ba f9 d4            jsr $4(pc)
  000632:  4e ad 02 fa            jsr $2fa(a5)
  000636:  1b 40 ba ad            move.b d0, -$4553(a5)
  00063a:  54 8f                  addq.l #$2, a7
  00063c:  4e 75                  rts 
  00063e:  2f 07                  move.l d7, -(a7)
  000640:  4e ad 02 fa            jsr $2fa(a5)
  000644:  1b 40 ba ab            move.b d0, -$4555(a5)
  000648:  4a 6d ba 28            tst.w -$45d8(a5)
  00064c:  67 18                  beq.b $666
  00064e:  0c 6d 00 02 ba 24      cmpi.w #$2, -$45dc(a5)
  000654:  6d 10                  blt.b $666
  000656:  4e ad 03 6a            jsr $36a(a5)
  00065a:  4a 40                  tst.w d0
  00065c:  6e 08                  bgt.b $666
  00065e:  4e ad 02 ea            jsr $2ea(a5)
  000662:  55 40                  subq.w #$2, d0
  000664:  6c 04                  bge.b $66a
  000666:  7e 05                  moveq #$5, d7
  000668:  60 0c                  bra.b $676
  00066a:  1b 7c 00 02 b9 52      move.b #$2, -$46ae(a5)
  000670:  42 6d ba 36            clr.w -$45ca(a5)
  000674:  7e 59                  moveq #$59, d7
  000676:  3f 07                  move.w d7, -(a7)
  000678:  4e ba f9 8a            jsr $4(pc)
  00067c:  54 8f                  addq.l #$2, a7
  00067e:  2e 1f                  move.l (a7)+, d7
  000680:  4e 75                  rts 
  000682:  2f 07                  move.l d7, -(a7)
  000684:  4e ba 0f b6            jsr $163c(pc)
  000688:  3e 00                  move.w d0, d7
  00068a:  0c 2d 00 01 ba e7      cmpi.b #$1, -$4519(a5)
  000690:  66 1a                  bne.b $6ac
  000692:  0c 2d 00 12 ba e8      cmpi.b #$12, -$4518(a5)
  000698:  67 12                  beq.b $6ac
  00069a:  0c 47 00 08            cmpi.w #$8, d7
  00069e:  6c 0c                  bge.b $6ac
  0006a0:  4a 2d ba aa            tst.b -$4556(a5)
  0006a4:  6c 10                  bge.b $6b6
  0006a6:  4e ba 00 80            jsr $728(pc)
  0006aa:  60 0a                  bra.b $6b6
  0006ac:  3f 3c 00 01            move.w #$1, -(a7)
  0006b0:  4e ba f9 52            jsr $4(pc)
  0006b4:  54 8f                  addq.l #$2, a7
  0006b6:  2e 1f                  move.l (a7)+, d7
  0006b8:  4e 75                  rts 
  0006ba:  4a 2d ba b9            tst.b -$4547(a5)
  0006be:  66 24                  bne.b $6e4
  0006c0:  0c 2d 00 07 b9 46      cmpi.b #$7, -$46ba(a5)
  0006c6:  67 08                  beq.b $6d0
  0006c8:  0c 2d 00 0b b9 46      cmpi.b #$b, -$46ba(a5)
  0006ce:  66 14                  bne.b $6e4
  0006d0:  4e ad 02 fa            jsr $2fa(a5)
  0006d4:  1b 40 ba aa            move.b d0, -$4556(a5)
  0006d8:  3f 3c 00 0d            move.w #$d, -(a7)
  0006dc:  4e ba f9 26            jsr $4(pc)
  0006e0:  54 8f                  addq.l #$2, a7
  0006e2:  60 42                  bra.b $726
  0006e4:  4a 2d ba b9            tst.b -$4547(a5)
  0006e8:  6f 14                  ble.b $6fe
  0006ea:  4e ad 02 fa            jsr $2fa(a5)
  0006ee:  1b 40 ba ab            move.b d0, -$4555(a5)
  0006f2:  3f 3c 00 06            move.w #$6, -(a7)
  0006f6:  4e ba f9 0c            jsr $4(pc)
  0006fa:  54 8f                  addq.l #$2, a7
  0006fc:  60 28                  bra.b $726
  0006fe:  4a 2d ba ba            tst.b -$4546(a5)
  000702:  6c 0c                  bge.b $710
  000704:  4a 2d ba ac            tst.b -$4554(a5)
  000708:  6c 1c                  bge.b $726
  00070a:  4e ba 04 a0            jsr $bac(pc)
  00070e:  60 16                  bra.b $726
  000710:  4a 2d ba ad            tst.b -$4553(a5)
  000714:  6c 10                  bge.b $726
  000716:  1b 7c 00 01 ba ad      move.b #$1, -$4553(a5)
  00071c:  3f 3c 00 1a            move.w #$1a, -(a7)
  000720:  4e ba f8 e2            jsr $4(pc)
  000724:  54 8f                  addq.l #$2, a7
  000726:  4e 75                  rts 
  000728:  2f 07                  move.l d7, -(a7)
  00072a:  70 01                  moveq #$1, d0
  00072c:  1b 40 ba ae            move.b d0, -$4552(a5)
  000730:  1b 40 ba aa            move.b d0, -$4556(a5)
  000734:  4e ba 0f 06            jsr $163c(pc)
  000738:  3e 00                  move.w d0, d7
  00073a:  4a 47                  tst.w d7
  00073c:  67 14                  beq.b $752
  00073e:  1b 7c 00 01 b9 50      move.b #$1, -$46b0(a5)
  000744:  70 1c                  moveq #$1c, d0
  000746:  d0 47                  add.w d7, d0
  000748:  3f 00                  move.w d0, -(a7)
  00074a:  4e ba f8 b8            jsr $4(pc)
  00074e:  54 8f                  addq.l #$2, a7
  000750:  60 28                  bra.b $77a
  000752:  0c 2d 00 01 ba e7      cmpi.b #$1, -$4519(a5)
  000758:  67 16                  beq.b $770
  00075a:  4a 2d b9 50            tst.b -$46b0(a5)
  00075e:  67 10                  beq.b $770
  000760:  42 2d b9 50            clr.b -$46b0(a5)
  000764:  3f 3c 00 2c            move.w #$2c, -(a7)
  000768:  4e ba f8 9a            jsr $4(pc)
  00076c:  54 8f                  addq.l #$2, a7
  00076e:  60 0a                  bra.b $77a
  000770:  3f 3c 00 27            move.w #$27, -(a7)
  000774:  4e ba f8 8e            jsr $4(pc)
  000778:  54 8f                  addq.l #$2, a7
  00077a:  2e 1f                  move.l (a7)+, d7
  00077c:  4e 75                  rts 
  00077e:  4e ad 02 ba            jsr $2ba(a5)
  000782:  72 00                  moveq #$0, d1
  000784:  12 00                  move.b d0, d1
  000786:  0c 41 00 0a            cmpi.w #$a, d1
  00078a:  67 08                  beq.b $794
  00078c:  0c 2d 00 16 ba e8      cmpi.b #$16, -$4518(a5)
  000792:  66 2a                  bne.b $7be
  000794:  4e ad 02 e2            jsr $2e2(a5)
  000798:  72 00                  moveq #$0, d1
  00079a:  12 00                  move.b d0, d1
  00079c:  3f 01                  move.w d1, -(a7)
  00079e:  4e ad 02 aa            jsr $2aa(a5)
  0007a2:  4a 00                  tst.b d0
  0007a4:  54 8f                  addq.l #$2, a7
  0007a6:  66 04                  bne.b $7ac
  0007a8:  70 00                  moveq #$0, d0
  0007aa:  60 32                  bra.b $7de
  0007ac:  3f 3c ff f2            move.w #$fff2, -(a7)
  0007b0:  4e ad 02 62            jsr $262(a5)
  0007b4:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0007b8:  4e ad 02 42            jsr $242(a5)
  0007bc:  54 8f                  addq.l #$2, a7
  0007be:  4e ad 02 da            jsr $2da(a5)
  0007c2:  72 00                  moveq #$0, d1
  0007c4:  12 00                  move.b d0, d1
  0007c6:  0c 41 00 0a            cmpi.w #$a, d1
  0007ca:  67 08                  beq.b $7d4
  0007cc:  0c 2d 00 16 ba e8      cmpi.b #$16, -$4518(a5)
  0007d2:  66 08                  bne.b $7dc
  0007d4:  4e ba 00 0a            jsr $7e0(pc)
  0007d8:  70 01                  moveq #$1, d0
  0007da:  60 02                  bra.b $7de
  0007dc:  70 00                  moveq #$0, d0
  0007de:  4e 75                  rts 
  0007e0:  48 e7 03 00            movem.l d6-d7, -(a7)
  0007e4:  0c 2d 00 6d b9 46      cmpi.b #$6d, -$46ba(a5)
  0007ea:  67 40                  beq.b $82c
  0007ec:  4e ba 0e 4e            jsr $163c(pc)
  0007f0:  3c 00                  move.w d0, d6
  0007f2:  0c 2d 00 02 ba e7      cmpi.b #$2, -$4519(a5)
  0007f8:  67 0c                  beq.b $806
  0007fa:  3f 06                  move.w d6, -(a7)
  0007fc:  4e ad 02 62            jsr $262(a5)
  000800:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000804:  54 8f                  addq.l #$2, a7
  000806:  4a 2d b9 49            tst.b -$46b7(a5)
  00080a:  6d 1a                  blt.b $826
  00080c:  0c 2d 00 0a ba e8      cmpi.b #$a, -$4518(a5)
  000812:  57 c0                  seq.b d0
  000814:  44 00                  neg.b d0
  000816:  48 80                  ext.w d0
  000818:  55 40                  subq.w #$2, d0
  00081a:  3f 00                  move.w d0, -(a7)
  00081c:  4e ad 02 62            jsr $262(a5)
  000820:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000824:  54 8f                  addq.l #$2, a7
  000826:  4e ba fe 02            jsr $62a(pc)
  00082a:  60 3e                  bra.b $86a
  00082c:  0c 2d 00 16 ba e8      cmpi.b #$16, -$4518(a5)
  000832:  66 14                  bne.b $848
  000834:  3f 3c ff ff            move.w #$ffff, -(a7)
  000838:  4e ad 03 32            jsr $332(a5)
  00083c:  3e bc 00 5b            move.w #$5b, (a7)
  000840:  4e ba f7 c2            jsr $4(pc)
  000844:  54 8f                  addq.l #$2, a7
  000846:  60 22                  bra.b $86a
  000848:  70 00                  moveq #$0, d0
  00084a:  10 2d ba e9            move.b -$4517(a5), d0
  00084e:  d0 ad bd 86            add.l -$427a(a5), d0
  000852:  20 40                  movea.l d0, a0
  000854:  70 00                  moveq #$0, d0
  000856:  10 10                  move.b (a0), d0
  000858:  ea 40                  asr.w #$5, d0
  00085a:  3f 00                  move.w d0, -(a7)
  00085c:  4e ad 03 32            jsr $332(a5)
  000860:  3e bc 00 4e            move.w #$4e, (a7)
  000864:  4e ba f7 9e            jsr $4(pc)
  000868:  54 8f                  addq.l #$2, a7
  00086a:  4c df 00 c0            movem.l (a7)+, d6-d7
  00086e:  4e 75                  rts 
  000870:  4a 2d ba ba            tst.b -$4546(a5)
  000874:  6c 0a                  bge.b $880
  000876:  4a 2d ba b9            tst.b -$4547(a5)
  00087a:  6c 04                  bge.b $880
  00087c:  4e ba 00 16            jsr $894(pc)
  000880:  4e 75                  rts 
  000882:  4a 2d ba b9            tst.b -$4547(a5)
  000886:  6d 06                  blt.b $88e
  000888:  4a 2d ba aa            tst.b -$4556(a5)
  00088c:  6c 04                  bge.b $892
  00088e:  4e ba 00 04            jsr $894(pc)
  000892:  4e 75                  rts 
  000894:  70 01                  moveq #$1, d0
  000896:  1b 40 ba aa            move.b d0, -$4556(a5)
  00089a:  1b 40 ba ac            move.b d0, -$4554(a5)
  00089e:  3f 3c 00 03            move.w #$3, -(a7)
  0008a2:  4e ba f7 60            jsr $4(pc)
  0008a6:  54 8f                  addq.l #$2, a7
  0008a8:  4e 75                  rts 
  0008aa:  4e ad 02 fa            jsr $2fa(a5)
  0008ae:  1b 40 ba ac            move.b d0, -$4554(a5)
  0008b2:  4e ad 03 12            jsr $312(a5)
  0008b6:  1b 40 ba bd            move.b d0, -$4543(a5)
  0008ba:  4e ad 03 22            jsr $322(a5)
  0008be:  4e ad 03 02            jsr $302(a5)
  0008c2:  4a 40                  tst.w d0
  0008c4:  67 06                  beq.b $8cc
  0008c6:  4e ba 02 94            jsr $b5c(pc)
  0008ca:  60 1e                  bra.b $8ea
  0008cc:  4e ad 03 1a            jsr $31a(a5)
  0008d0:  1b 40 ba bd            move.b d0, -$4543(a5)
  0008d4:  4e ad 03 12            jsr $312(a5)
  0008d8:  4e ad 03 02            jsr $302(a5)
  0008dc:  4a 40                  tst.w d0
  0008de:  67 06                  beq.b $8e6
  0008e0:  4e ba 00 0a            jsr $8ec(pc)
  0008e4:  60 04                  bra.b $8ea
  0008e6:  4e ba 00 70            jsr $958(pc)
  0008ea:  4e 75                  rts 
  0008ec:  2f 07                  move.l d7, -(a7)
  0008ee:  4e ad 02 ea            jsr $2ea(a5)
  0008f2:  3e 00                  move.w d0, d7
  0008f4:  0c 47 00 06            cmpi.w #$6, d7
  0008f8:  6c 06                  bge.b $900
  0008fa:  4e ba 00 5c            jsr $958(pc)
  0008fe:  60 32                  bra.b $932
  000900:  4e ad 02 e2            jsr $2e2(a5)
  000904:  72 00                  moveq #$0, d1
  000906:  12 00                  move.b d0, d1
  000908:  3f 01                  move.w d1, -(a7)
  00090a:  4e ad 02 aa            jsr $2aa(a5)
  00090e:  4a 00                  tst.b d0
  000910:  54 8f                  addq.l #$2, a7
  000912:  66 06                  bne.b $91a
  000914:  4e ba 00 20            jsr $936(pc)
  000918:  60 18                  bra.b $932
  00091a:  70 f2                  moveq #$f2, d0
  00091c:  d0 47                  add.w d7, d0
  00091e:  3f 00                  move.w d0, -(a7)
  000920:  4e ad 02 62            jsr $262(a5)
  000924:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000928:  4e ad 02 42            jsr $242(a5)
  00092c:  4e ba 02 2e            jsr $b5c(pc)
  000930:  54 8f                  addq.l #$2, a7
  000932:  2e 1f                  move.l (a7)+, d7
  000934:  4e 75                  rts 
  000936:  4e ad 03 12            jsr $312(a5)
  00093a:  4e ad 02 ea            jsr $2ea(a5)
  00093e:  06 40 ff f6            addi.w #$fff6, d0
  000942:  3f 00                  move.w d0, -(a7)
  000944:  4e ad 02 62            jsr $262(a5)
  000948:  1b 40 b9 47            move.b d0, -$46b9(a5)
  00094c:  3e bc 00 10            move.w #$10, (a7)
  000950:  4e ba f6 b2            jsr $4(pc)
  000954:  54 8f                  addq.l #$2, a7
  000956:  4e 75                  rts 
  000958:  4e 56 ff fe            link.w a6, #$fffe
  00095c:  2f 07                  move.l d7, -(a7)
  00095e:  4e ad 02 fa            jsr $2fa(a5)
  000962:  1b 40 ba ac            move.b d0, -$4554(a5)
  000966:  4e ba 0c d4            jsr $163c(pc)
  00096a:  3e 00                  move.w d0, d7
  00096c:  0c 47 00 04            cmpi.w #$4, d7
  000970:  6c 18                  bge.b $98a
  000972:  0c 2d 00 01 ba e7      cmpi.b #$1, -$4519(a5)
  000978:  66 10                  bne.b $98a
  00097a:  70 fd                  moveq #$fd, d0
  00097c:  d0 47                  add.w d7, d0
  00097e:  3f 00                  move.w d0, -(a7)
  000980:  4e ad 02 62            jsr $262(a5)
  000984:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000988:  54 8f                  addq.l #$2, a7
  00098a:  10 2d b9 4b            move.b -$46b5(a5), d0
  00098e:  48 80                  ext.w d0
  000990:  53 40                  subq.w #$1, d0
  000992:  3f 00                  move.w d0, -(a7)
  000994:  4e ad 02 5a            jsr $25a(a5)
  000998:  3d 40 ff fe            move.w d0, -$2(a6)
  00099c:  42 67                  clr.w -(a7)
  00099e:  4e ad 03 2a            jsr $32a(a5)
  0009a2:  d0 6e ff fe            add.w -$2(a6), d0
  0009a6:  5d 40                  subq.w #$6, d0
  0009a8:  3e 80                  move.w d0, (a7)
  0009aa:  4e ad 02 7a            jsr $27a(a5)
  0009ae:  3e 80                  move.w d0, (a7)
  0009b0:  10 2d b9 4f            move.b -$46b1(a5), d0
  0009b4:  48 80                  ext.w d0
  0009b6:  3f 00                  move.w d0, -(a7)
  0009b8:  4e ad 02 2a            jsr $22a(a5)
  0009bc:  0c 2d 00 14 ba e8      cmpi.b #$14, -$4518(a5)
  0009c2:  5c 8f                  addq.l #$6, a7
  0009c4:  67 1e                  beq.b $9e4
  0009c6:  70 00                  moveq #$0, d0
  0009c8:  10 2d ba e8            move.b -$4518(a5), d0
  0009cc:  3f 00                  move.w d0, -(a7)
  0009ce:  4e ad 02 aa            jsr $2aa(a5)
  0009d2:  4a 00                  tst.b d0
  0009d4:  54 8f                  addq.l #$2, a7
  0009d6:  66 0c                  bne.b $9e4
  0009d8:  3f 3c 00 1c            move.w #$1c, -(a7)
  0009dc:  4e ba f6 26            jsr $4(pc)
  0009e0:  54 8f                  addq.l #$2, a7
  0009e2:  60 0a                  bra.b $9ee
  0009e4:  3f 3c 00 0e            move.w #$e, -(a7)
  0009e8:  4e ba f6 1a            jsr $4(pc)
  0009ec:  54 8f                  addq.l #$2, a7
  0009ee:  2e 1f                  move.l (a7)+, d7
  0009f0:  4e 5e                  unlk a6
  0009f2:  4e 75                  rts 
  0009f4:  4a 2d b9 53            tst.b -$46ad(a5)
  0009f8:  6d 08                  blt.b $a02
  0009fa:  4e ba 00 e6            jsr $ae2(pc)
  0009fe:  60 00 00 82            bra.w $a82
  000a02:  4a 6d ba 54            tst.w -$45ac(a5)
  000a06:  66 0c                  bne.b $a14
  000a08:  4a 2d ba ba            tst.b -$4546(a5)
  000a0c:  6c 06                  bge.b $a14
  000a0e:  4e ba 00 74            jsr $a84(pc)
  000a12:  60 6e                  bra.b $a82
  000a14:  4a 2d ba bb            tst.b -$4545(a5)
  000a18:  6d 06                  blt.b $a20
  000a1a:  4e ba 00 c6            jsr $ae2(pc)
  000a1e:  60 62                  bra.b $a82
  000a20:  0c 2d 00 06 b9 4c      cmpi.b #$6, -$46b4(a5)
  000a26:  67 42                  beq.b $a6a
  000a28:  4e ad 02 ba            jsr $2ba(a5)
  000a2c:  72 00                  moveq #$0, d1
  000a2e:  12 00                  move.b d0, d1
  000a30:  0c 41 00 14            cmpi.w #$14, d1
  000a34:  67 18                  beq.b $a4e
  000a36:  0c 2d 00 ff b9 49      cmpi.b #$ff, -$46b7(a5)
  000a3c:  66 2c                  bne.b $a6a
  000a3e:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  000a44:  67 08                  beq.b $a4e
  000a46:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  000a4c:  66 1c                  bne.b $a6a
  000a4e:  4a 6d ba 54            tst.w -$45ac(a5)
  000a52:  66 0a                  bne.b $a5e
  000a54:  3f 3c 00 08            move.w #$8, -(a7)
  000a58:  4e ad 03 92            jsr $392(a5)
  000a5c:  54 8f                  addq.l #$2, a7
  000a5e:  3f 3c 00 19            move.w #$19, -(a7)
  000a62:  4e ba f5 a0            jsr $4(pc)
  000a66:  54 8f                  addq.l #$2, a7
  000a68:  60 18                  bra.b $a82
  000a6a:  4e ad 03 12            jsr $312(a5)
  000a6e:  72 00                  moveq #$0, d1
  000a70:  12 00                  move.b d0, d1
  000a72:  3f 01                  move.w d1, -(a7)
  000a74:  4e ad 02 aa            jsr $2aa(a5)
  000a78:  4a 00                  tst.b d0
  000a7a:  54 8f                  addq.l #$2, a7
  000a7c:  66 04                  bne.b $a82
  000a7e:  4e ba 00 62            jsr $ae2(pc)
  000a82:  4e 75                  rts 
  000a84:  2f 07                  move.l d7, -(a7)
  000a86:  7e 0a                  moveq #$a, d7
  000a88:  4e ad 02 fa            jsr $2fa(a5)
  000a8c:  1b 40 ba ae            move.b d0, -$4552(a5)
  000a90:  1b 40 ba ac            move.b d0, -$4554(a5)
  000a94:  4e ad 03 12            jsr $312(a5)
  000a98:  0c 2d 00 0d ba e8      cmpi.b #$d, -$4518(a5)
  000a9e:  67 08                  beq.b $aa8
  000aa0:  0c 2d 00 12 ba e8      cmpi.b #$12, -$4518(a5)
  000aa6:  66 06                  bne.b $aae
  000aa8:  4a 2d b9 49            tst.b -$46b7(a5)
  000aac:  67 26                  beq.b $ad4
  000aae:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  000ab4:  66 20                  bne.b $ad6
  000ab6:  4a 2d b9 49            tst.b -$46b7(a5)
  000aba:  67 1a                  beq.b $ad6
  000abc:  70 00                  moveq #$0, d0
  000abe:  10 2d ba e9            move.b -$4517(a5), d0
  000ac2:  d0 ad bd 86            add.l -$427a(a5), d0
  000ac6:  20 40                  movea.l d0, a0
  000ac8:  70 00                  moveq #$0, d0
  000aca:  10 10                  move.b (a0), d0
  000acc:  81 fc 00 04            divs.w #$4, d0
  000ad0:  5d 40                  subq.w #$6, d0
  000ad2:  6c 02                  bge.b $ad6
  000ad4:  7e 49                  moveq #$49, d7
  000ad6:  3f 07                  move.w d7, -(a7)
  000ad8:  4e ba f5 2a            jsr $4(pc)
  000adc:  54 8f                  addq.l #$2, a7
  000ade:  2e 1f                  move.l (a7)+, d7
  000ae0:  4e 75                  rts 
  000ae2:  4e ad 02 fa            jsr $2fa(a5)
  000ae6:  1b 40 ba ad            move.b d0, -$4553(a5)
  000aea:  4e ad 02 e2            jsr $2e2(a5)
  000aee:  72 00                  moveq #$0, d1
  000af0:  12 00                  move.b d0, d1
  000af2:  3f 01                  move.w d1, -(a7)
  000af4:  4e ad 02 aa            jsr $2aa(a5)
  000af8:  4a 00                  tst.b d0
  000afa:  54 8f                  addq.l #$2, a7
  000afc:  66 20                  bne.b $b1e
  000afe:  4e ad 02 ba            jsr $2ba(a5)
  000b02:  72 00                  moveq #$0, d1
  000b04:  12 00                  move.b d0, d1
  000b06:  3f 01                  move.w d1, -(a7)
  000b08:  4e ad 02 aa            jsr $2aa(a5)
  000b0c:  4a 00                  tst.b d0
  000b0e:  54 8f                  addq.l #$2, a7
  000b10:  66 0c                  bne.b $b1e
  000b12:  3f 3c 00 17            move.w #$17, -(a7)
  000b16:  4e ba f4 ec            jsr $4(pc)
  000b1a:  54 8f                  addq.l #$2, a7
  000b1c:  60 3c                  bra.b $b5a
  000b1e:  4e ad 02 ba            jsr $2ba(a5)
  000b22:  72 00                  moveq #$0, d1
  000b24:  12 00                  move.b d0, d1
  000b26:  0c 41 00 14            cmpi.w #$14, d1
  000b2a:  67 16                  beq.b $b42
  000b2c:  4a 2d b9 49            tst.b -$46b7(a5)
  000b30:  6c 1e                  bge.b $b50
  000b32:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  000b38:  67 08                  beq.b $b42
  000b3a:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  000b40:  66 0e                  bne.b $b50
  000b42:  3f 3c ff f9            move.w #$fff9, -(a7)
  000b46:  4e ad 02 62            jsr $262(a5)
  000b4a:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000b4e:  54 8f                  addq.l #$2, a7
  000b50:  3f 3c 00 0b            move.w #$b, -(a7)
  000b54:  4e ba f4 ae            jsr $4(pc)
  000b58:  54 8f                  addq.l #$2, a7
  000b5a:  4e 75                  rts 
  000b5c:  2f 07                  move.l d7, -(a7)
  000b5e:  4e ad 02 ea            jsr $2ea(a5)
  000b62:  3e 00                  move.w d0, d7
  000b64:  0c 47 00 04            cmpi.w #$4, d7
  000b68:  6c 26                  bge.b $b90
  000b6a:  4e ba 0a d0            jsr $163c(pc)
  000b6e:  59 40                  subq.w #$4, d0
  000b70:  6c 1e                  bge.b $b90
  000b72:  0c 2d 00 01 ba e7      cmpi.b #$1, -$4519(a5)
  000b78:  67 16                  beq.b $b90
  000b7a:  3f 07                  move.w d7, -(a7)
  000b7c:  4e ad 02 62            jsr $262(a5)
  000b80:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000b84:  3e bc 00 08            move.w #$8, (a7)
  000b88:  4e ba f4 7a            jsr $4(pc)
  000b8c:  54 8f                  addq.l #$2, a7
  000b8e:  60 18                  bra.b $ba8
  000b90:  70 fc                  moveq #$fc, d0
  000b92:  d0 47                  add.w d7, d0
  000b94:  3f 00                  move.w d0, -(a7)
  000b96:  4e ad 02 62            jsr $262(a5)
  000b9a:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000b9e:  3e bc 00 18            move.w #$18, (a7)
  000ba2:  4e ba f4 60            jsr $4(pc)
  000ba6:  54 8f                  addq.l #$2, a7
  000ba8:  2e 1f                  move.l (a7)+, d7
  000baa:  4e 75                  rts 
  000bac:  48 e7 0f 00            movem.l d4-d7, -(a7)
  000bb0:  78 00                  moveq #$0, d4
  000bb2:  0c 2d 00 07 b9 46      cmpi.b #$7, -$46ba(a5)
  000bb8:  65 00 00 aa            bcs.w $c64
  000bbc:  3f 3c 00 04            move.w #$4, -(a7)
  000bc0:  4e ad 02 62            jsr $262(a5)
  000bc4:  3c 00                  move.w d0, d6
  000bc6:  3e 86                  move.w d6, (a7)
  000bc8:  4e ad 02 72            jsr $272(a5)
  000bcc:  3a 00                  move.w d0, d5
  000bce:  54 8f                  addq.l #$2, a7
  000bd0:  10 2d b9 49            move.b -$46b7(a5), d0
  000bd4:  48 80                  ext.w d0
  000bd6:  20 4d                  movea.l a5, a0
  000bd8:  d0 c0                  adda.w d0, a0
  000bda:  10 28 b6 61            move.b -$499f(a0), d0
  000bde:  48 80                  ext.w d0
  000be0:  da 40                  add.w d0, d5
  000be2:  10 2d b9 4b            move.b -$46b5(a5), d0
  000be6:  48 80                  ext.w d0
  000be8:  3f 00                  move.w d0, -(a7)
  000bea:  3f 05                  move.w d5, -(a7)
  000bec:  10 2d b9 4f            move.b -$46b1(a5), d0
  000bf0:  48 80                  ext.w d0
  000bf2:  3f 00                  move.w d0, -(a7)
  000bf4:  4e ad 02 2a            jsr $22a(a5)
  000bf8:  0c 2d 00 02 ba e8      cmpi.b #$2, -$4518(a5)
  000bfe:  5c 8f                  addq.l #$6, a7
  000c00:  67 1c                  beq.b $c1e
  000c02:  70 00                  moveq #$0, d0
  000c04:  10 2d ba e8            move.b -$4518(a5), d0
  000c08:  3f 00                  move.w d0, -(a7)
  000c0a:  4e ad 02 aa            jsr $2aa(a5)
  000c0e:  4a 00                  tst.b d0
  000c10:  54 8f                  addq.l #$2, a7
  000c12:  67 0a                  beq.b $c1e
  000c14:  52 44                  addq.w #$1, d4
  000c16:  0c 44 00 02            cmpi.w #$2, d4
  000c1a:  6c 36                  bge.b $c52
  000c1c:  60 b2                  bra.b $bd0
  000c1e:  3f 06                  move.w d6, -(a7)
  000c20:  4e ad 02 f2            jsr $2f2(a5)
  000c24:  72 0e                  moveq #$e, d1
  000c26:  c3 c4                  muls.w d4, d1
  000c28:  d2 40                  add.w d0, d1
  000c2a:  7e f2                  moveq #$f2, d7
  000c2c:  de 41                  add.w d1, d7
  000c2e:  0c 47 ff f8            cmpi.w #$fff8, d7
  000c32:  54 8f                  addq.l #$2, a7
  000c34:  6d 06                  blt.b $c3c
  000c36:  0c 47 00 02            cmpi.w #$2, d7
  000c3a:  6d 06                  blt.b $c42
  000c3c:  4a 47                  tst.w d7
  000c3e:  6c 24                  bge.b $c64
  000c40:  7e fd                  moveq #$fd, d7
  000c42:  70 04                  moveq #$4, d0
  000c44:  d0 47                  add.w d7, d0
  000c46:  3f 00                  move.w d0, -(a7)
  000c48:  4e ad 02 62            jsr $262(a5)
  000c4c:  1b 40 b9 47            move.b d0, -$46b9(a5)
  000c50:  54 8f                  addq.l #$2, a7
  000c52:  4e ad 02 fa            jsr $2fa(a5)
  000c56:  1b 40 ba ac            move.b d0, -$4554(a5)
  000c5a:  3f 3c 00 04            move.w #$4, -(a7)
  000c5e:  4e ba f3 a4            jsr $4(pc)
  000c62:  54 8f                  addq.l #$2, a7
  000c64:  4c df 00 f0            movem.l (a7)+, d4-d7
  000c68:  4e 75                  rts 
  000c6a:  2f 07                  move.l d7, -(a7)
  000c6c:  7e 00                  moveq #$0, d7
  000c6e:  1e 2d b9 46            move.b -$46ba(a5), d7
  000c72:  0c 47 00 9e            cmpi.w #$9e, d7
  000c76:  67 0c                  beq.b $c84
  000c78:  0c 47 00 aa            cmpi.w #$aa, d7
  000c7c:  67 06                  beq.b $c84
  000c7e:  0c 47 00 ab            cmpi.w #$ab, d7
  000c82:  66 10                  bne.b $c94
  000c84:  1b 7c 00 01 ba ab      move.b #$1, -$4555(a5)
  000c8a:  3f 3c 00 39            move.w #$39, -(a7)
  000c8e:  4e ba f3 74            jsr $4(pc)
  000c92:  54 8f                  addq.l #$2, a7
  000c94:  2e 1f                  move.l (a7)+, d7
  000c96:  4e 75                  rts 
  000c98:  2f 07                  move.l d7, -(a7)
  000c9a:  7e 00                  moveq #$0, d7
  000c9c:  1e 2d b9 46            move.b -$46ba(a5), d7
  000ca0:  0c 47 00 9e            cmpi.w #$9e, d7
  000ca4:  67 0c                  beq.b $cb2
  000ca6:  0c 47 00 aa            cmpi.w #$aa, d7
  000caa:  67 06                  beq.b $cb2
  000cac:  0c 47 00 ab            cmpi.w #$ab, d7
  000cb0:  66 22                  bne.b $cd4
  000cb2:  1b 7c 00 01 ba aa      move.b #$1, -$4556(a5)
  000cb8:  4a 2d b9 51            tst.b -$46af(a5)
  000cbc:  67 0c                  beq.b $cca
  000cbe:  3f 3c 00 38            move.w #$38, -(a7)
  000cc2:  4e ba f3 40            jsr $4(pc)
  000cc6:  54 8f                  addq.l #$2, a7
  000cc8:  60 0a                  bra.b $cd4
  000cca:  3f 3c 00 56            move.w #$56, -(a7)
  000cce:  4e ba f3 34            jsr $4(pc)
  000cd2:  54 8f                  addq.l #$2, a7
  000cd4:  2e 1f                  move.l (a7)+, d7
  000cd6:  4e 75                  rts 
  000cd8:  2f 07                  move.l d7, -(a7)
  000cda:  7e 37                  moveq #$37, d7
  000cdc:  4e ad 02 fa            jsr $2fa(a5)
  000ce0:  1b 40 ba ae            move.b d0, -$4552(a5)
  000ce4:  1b 40 ba aa            move.b d0, -$4556(a5)
  000ce8:  4a 2d b9 51            tst.b -$46af(a5)
  000cec:  66 10                  bne.b $cfe
  000cee:  3f 3c 00 13            move.w #$13, -(a7)
  000cf2:  4e ad 03 92            jsr $392(a5)
  000cf6:  42 6d ba 36            clr.w -$45ca(a5)
  000cfa:  54 8f                  addq.l #$2, a7
  000cfc:  60 0a                  bra.b $d08
  000cfe:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  000d04:  67 02                  beq.b $d08
  000d06:  7e 5a                  moveq #$5a, d7
  000d08:  1b 7c 00 02 b9 52      move.b #$2, -$46ae(a5)
  000d0e:  3f 07                  move.w d7, -(a7)
  000d10:  4e ba f2 f2            jsr $4(pc)
  000d14:  54 8f                  addq.l #$2, a7
  000d16:  2e 1f                  move.l (a7)+, d7
  000d18:  4e 75                  rts 
  000d1a:  2f 07                  move.l d7, -(a7)
  000d1c:  0c 2d 00 02 b9 4c      cmpi.b #$2, -$46b4(a5)
  000d22:  6c 6e                  bge.b $d92
  000d24:  4e ad 02 ba            jsr $2ba(a5)
  000d28:  72 00                  moveq #$0, d1
  000d2a:  12 00                  move.b d0, d1
  000d2c:  0c 41 00 0b            cmpi.w #$b, d1
  000d30:  67 08                  beq.b $d3a
  000d32:  0c 6d 00 02 ba 24      cmpi.w #$2, -$45dc(a5)
  000d38:  6d 24                  blt.b $d5e
  000d3a:  4e ad 03 6a            jsr $36a(a5)
  000d3e:  3e 00                  move.w d0, d7
  000d40:  0c 47 00 5a            cmpi.w #$5a, d7
  000d44:  6c 18                  bge.b $d5e
  000d46:  0c 47 ff fc            cmpi.w #$fffc, d7
  000d4a:  6d 06                  blt.b $d52
  000d4c:  4e ba 00 48            jsr $d96(pc)
  000d50:  60 40                  bra.b $d92
  000d52:  3f 3c 00 3c            move.w #$3c, -(a7)
  000d56:  4e ba f2 ac            jsr $4(pc)
  000d5a:  54 8f                  addq.l #$2, a7
  000d5c:  60 34                  bra.b $d92
  000d5e:  4a 2d b9 51            tst.b -$46af(a5)
  000d62:  66 0a                  bne.b $d6e
  000d64:  4a 2d b9 53            tst.b -$46ad(a5)
  000d68:  6c 04                  bge.b $d6e
  000d6a:  42 6d ba 26            clr.w -$45da(a5)
  000d6e:  0c 2d 00 02 b9 51      cmpi.b #$2, -$46af(a5)
  000d74:  6d 06                  blt.b $d7c
  000d76:  4e ba 00 1e            jsr $d96(pc)
  000d7a:  60 16                  bra.b $d92
  000d7c:  0c 2d 00 ab b9 46      cmpi.b #$ab, -$46ba(a5)
  000d82:  66 0e                  bne.b $d92
  000d84:  42 2d b9 52            clr.b -$46ae(a5)
  000d88:  3f 3c 00 5c            move.w #$5c, -(a7)
  000d8c:  4e ba f2 76            jsr $4(pc)
  000d90:  54 8f                  addq.l #$2, a7
  000d92:  2e 1f                  move.l (a7)+, d7
  000d94:  4e 75                  rts 
  000d96:  48 e7 03 00            movem.l d6-d7, -(a7)
  000d9a:  7e 00                  moveq #$0, d7
  000d9c:  1e 2d b9 46            move.b -$46ba(a5), d7
  000da0:  1c 2d b9 51            move.b -$46af(a5), d6
  000da4:  48 86                  ext.w d6
  000da6:  0c 47 00 a1            cmpi.w #$a1, d7
  000daa:  66 14                  bne.b $dc0
  000dac:  4a 2d ba ae            tst.b -$4552(a5)
  000db0:  6d 0e                  blt.b $dc0
  000db2:  3f 3c 00 39            move.w #$39, -(a7)
  000db6:  4e ba f2 4c            jsr $4(pc)
  000dba:  54 8f                  addq.l #$2, a7
  000dbc:  60 00 00 90            bra.w $e4e
  000dc0:  4a 2d ba ae            tst.b -$4552(a5)
  000dc4:  6c 16                  bge.b $ddc
  000dc6:  4a 46                  tst.w d6
  000dc8:  66 06                  bne.b $dd0
  000dca:  3b 7c 00 0f ba 88      move.w #$f, -$4578(a5)
  000dd0:  4e ba 00 82            jsr $e54(pc)
  000dd4:  0c 2d 00 01 ba ae      cmpi.b #$1, -$4552(a5)
  000dda:  67 72                  beq.b $e4e
  000ddc:  4a 2d ba ad            tst.b -$4553(a5)
  000de0:  6c 4a                  bge.b $e2c
  000de2:  0c 47 00 9e            cmpi.w #$9e, d7
  000de6:  67 0c                  beq.b $df4
  000de8:  0c 47 00 aa            cmpi.w #$aa, d7
  000dec:  67 06                  beq.b $df4
  000dee:  0c 47 00 ab            cmpi.w #$ab, d7
  000df2:  66 5a                  bne.b $e4e
  000df4:  1b 7c 00 01 ba ad      move.b #$1, -$4553(a5)
  000dfa:  42 2d b9 52            clr.b -$46ae(a5)
  000dfe:  4a 46                  tst.w d6
  000e00:  66 14                  bne.b $e16
  000e02:  3b 7c 00 01 ba 36      move.w #$1, -$45ca(a5)
  000e08:  3b 7c 00 09 ba 8a      move.w #$9, -$4576(a5)
  000e0e:  42 6d ba 26            clr.w -$45da(a5)
  000e12:  7e 5d                  moveq #$5d, d7
  000e14:  60 0c                  bra.b $e22
  000e16:  0c 46 00 01            cmpi.w #$1, d6
  000e1a:  66 04                  bne.b $e20
  000e1c:  7e 5c                  moveq #$5c, d7
  000e1e:  60 02                  bra.b $e22
  000e20:  7e 57                  moveq #$57, d7
  000e22:  3f 07                  move.w d7, -(a7)
  000e24:  4e ba f1 de            jsr $4(pc)
  000e28:  54 8f                  addq.l #$2, a7
  000e2a:  60 22                  bra.b $e4e
  000e2c:  4a 2d ba ac            tst.b -$4554(a5)
  000e30:  6c 06                  bge.b $e38
  000e32:  4e ba 00 78            jsr $eac(pc)
  000e36:  60 16                  bra.b $e4e
  000e38:  4a 2d ba aa            tst.b -$4556(a5)
  000e3c:  6c 06                  bge.b $e44
  000e3e:  4e ba fe 58            jsr $c98(pc)
  000e42:  60 0a                  bra.b $e4e
  000e44:  4a 2d ba ab            tst.b -$4555(a5)
  000e48:  6c 04                  bge.b $e4e
  000e4a:  4e ba fe 1e            jsr $c6a(pc)
  000e4e:  4c df 00 c0            movem.l (a7)+, d6-d7
  000e52:  4e 75                  rts 
  000e54:  48 e7 03 00            movem.l d6-d7, -(a7)
  000e58:  7e 00                  moveq #$0, d7
  000e5a:  1e 2d b9 46            move.b -$46ba(a5), d7
  000e5e:  0c 47 00 9d            cmpi.w #$9d, d7
  000e62:  67 18                  beq.b $e7c
  000e64:  0c 47 00 9e            cmpi.w #$9e, d7
  000e68:  67 12                  beq.b $e7c
  000e6a:  0c 47 00 aa            cmpi.w #$aa, d7
  000e6e:  67 0c                  beq.b $e7c
  000e70:  0c 47 00 ab            cmpi.w #$ab, d7
  000e74:  67 06                  beq.b $e7c
  000e76:  0c 47 00 a5            cmpi.w #$a5, d7
  000e7a:  66 0e                  bne.b $e8a
  000e7c:  4a 2d b9 51            tst.b -$46af(a5)
  000e80:  66 04                  bne.b $e86
  000e82:  7c 4b                  moveq #$4b, d6
  000e84:  60 12                  bra.b $e98
  000e86:  7c 3a                  moveq #$3a, d6
  000e88:  60 0e                  bra.b $e98
  000e8a:  0c 47 00 96            cmpi.w #$96, d7
  000e8e:  67 06                  beq.b $e96
  000e90:  0c 47 00 a1            cmpi.w #$a1, d7
  000e94:  66 10                  bne.b $ea6
  000e96:  7c 42                  moveq #$42, d6
  000e98:  1b 7c 00 01 ba ae      move.b #$1, -$4552(a5)
  000e9e:  3f 06                  move.w d6, -(a7)
  000ea0:  4e ba f1 62            jsr $4(pc)
  000ea4:  54 8f                  addq.l #$2, a7
  000ea6:  4c df 00 c0            movem.l (a7)+, d6-d7
  000eaa:  4e 75                  rts 
  000eac:  48 e7 1f 00            movem.l d3-d7, -(a7)
  000eb0:  7e 00                  moveq #$0, d7
  000eb2:  1e 2d b9 46            move.b -$46ba(a5), d7
  000eb6:  7c 00                  moveq #$0, d6
  000eb8:  1c 2d b9 58            move.b -$46a8(a5), d6
  000ebc:  1a 2d b9 51            move.b -$46af(a5), d5
  000ec0:  48 85                  ext.w d5
  000ec2:  78 3e                  moveq #$3e, d4
  000ec4:  76 00                  moveq #$0, d3
  000ec6:  0c 47 00 9e            cmpi.w #$9e, d7
  000eca:  67 18                  beq.b $ee4
  000ecc:  0c 47 00 aa            cmpi.w #$aa, d7
  000ed0:  67 12                  beq.b $ee4
  000ed2:  0c 47 00 ab            cmpi.w #$ab, d7
  000ed6:  67 0c                  beq.b $ee4
  000ed8:  0c 47 00 a8            cmpi.w #$a8, d7
  000edc:  67 06                  beq.b $ee4
  000ede:  0c 47 00 a5            cmpi.w #$a5, d7
  000ee2:  66 4c                  bne.b $f30
  000ee4:  4e ad 03 6a            jsr $36a(a5)
  000ee8:  0c 40 00 20            cmpi.w #$20, d0
  000eec:  6d 0a                  blt.b $ef8
  000eee:  4a 45                  tst.w d5
  000ef0:  67 06                  beq.b $ef8
  000ef2:  4e ba fd 76            jsr $c6a(pc)
  000ef6:  60 56                  bra.b $f4e
  000ef8:  4a 45                  tst.w d5
  000efa:  66 2c                  bne.b $f28
  000efc:  0c 46 00 a8            cmpi.w #$a8, d6
  000f00:  67 4c                  beq.b $f4e
  000f02:  0c 46 00 97            cmpi.w #$97, d6
  000f06:  67 30                  beq.b $f38
  000f08:  0c 46 00 98            cmpi.w #$98, d6
  000f0c:  67 2a                  beq.b $f38
  000f0e:  0c 46 00 a2            cmpi.w #$a2, d6
  000f12:  67 24                  beq.b $f38
  000f14:  0c 46 00 99            cmpi.w #$99, d6
  000f18:  66 04                  bne.b $f1e
  000f1a:  76 01                  moveq #$1, d3
  000f1c:  60 1a                  bra.b $f38
  000f1e:  4a 45                  tst.w d5
  000f20:  67 16                  beq.b $f38
  000f22:  4e ba fd 46            jsr $c6a(pc)
  000f26:  60 26                  bra.b $f4e
  000f28:  0c 46 00 98            cmpi.w #$98, d6
  000f2c:  66 20                  bne.b $f4e
  000f2e:  60 08                  bra.b $f38
  000f30:  0c 47 00 a7            cmpi.w #$a7, d7
  000f34:  66 18                  bne.b $f4e
  000f36:  78 3d                  moveq #$3d, d4
  000f38:  1b 7c 00 01 ba ac      move.b #$1, -$4554(a5)
  000f3e:  3f 04                  move.w d4, -(a7)
  000f40:  4e ba f0 c2            jsr $4(pc)
  000f44:  4a 43                  tst.w d3
  000f46:  54 8f                  addq.l #$2, a7
  000f48:  67 04                  beq.b $f4e
  000f4a:  4e ad 02 6a            jsr $26a(a5)
  000f4e:  4c df 00 f8            movem.l (a7)+, d3-d7
  000f52:  4e 75                  rts 
  000f54:  48 e7 0f 00            movem.l d4-d7, -(a7)
  000f58:  70 ff                  moveq #$ff, d0
  000f5a:  1b 40 bb 1d            move.b d0, -$44e3(a5)
  000f5e:  1b 40 bb 1c            move.b d0, -$44e4(a5)
  000f62:  0c 2d 00 07 b9 4c      cmpi.b #$7, -$46b4(a5)
  000f68:  67 00 00 da            beq.w $1044
  000f6c:  1b 6d b9 4b bb 1e      move.b -$46b5(a5), -$44e2(a5)
  000f72:  4e ba 00 d6            jsr $104a(pc)
  000f76:  1b 6d bb 1e bb 1f      move.b -$44e2(a5), -$44e1(a5)
  000f7c:  3f 2d ba da            move.w -$4526(a5), -(a7)
  000f80:  4e ad 02 72            jsr $272(a5)
  000f84:  54 00                  addq.b #$2, d0
  000f86:  1b 40 bb 21            move.b d0, -$44df(a5)
  000f8a:  0c 00 00 0a            cmpi.b #$a, d0
  000f8e:  54 8f                  addq.l #$2, a7
  000f90:  6f 06                  ble.b $f98
  000f92:  1b 7c 00 0b bb 21      move.b #$b, -$44df(a5)
  000f98:  3f 2d ba d8            move.w -$4528(a5), -(a7)
  000f9c:  4e ad 02 72            jsr $272(a5)
  000fa0:  53 00                  subq.b #$1, d0
  000fa2:  1b 40 bb 20            move.b d0, -$44e0(a5)
  000fa6:  48 6d bb 68            pea.l -$4498(a5)
  000faa:  48 6d bb 40            pea.l -$44c0(a5)
  000fae:  12 2d bb 1e            move.b -$44e2(a5), d1
  000fb2:  48 81                  ext.w d1
  000fb4:  53 41                  subq.w #$1, d1
  000fb6:  3f 01                  move.w d1, -(a7)
  000fb8:  4e ba 01 30            jsr $10ea(pc)
  000fbc:  48 6d bb 54            pea.l -$44ac(a5)
  000fc0:  48 6d bb 2c            pea.l -$44d4(a5)
  000fc4:  10 2d bb 1e            move.b -$44e2(a5), d0
  000fc8:  48 80                  ext.w d0
  000fca:  3f 00                  move.w d0, -(a7)
  000fcc:  4e ba 01 1c            jsr $10ea(pc)
  000fd0:  48 6d bb 5e            pea.l -$44a2(a5)
  000fd4:  48 6d bb 36            pea.l -$44ca(a5)
  000fd8:  10 2d bb 1e            move.b -$44e2(a5), d0
  000fdc:  48 80                  ext.w d0
  000fde:  52 40                  addq.w #$1, d0
  000fe0:  3f 00                  move.w d0, -(a7)
  000fe2:  4e ba 01 06            jsr $10ea(pc)
  000fe6:  7e 09                  moveq #$9, d7
  000fe8:  4f ef 00 20            lea.l $20(a7), a7
  000fec:  60 52                  bra.b $1040
  000fee:  20 4d                  movea.l a5, a0
  000ff0:  d0 c7                  adda.w d7, a0
  000ff2:  1c 28 bb 22            move.b -$44de(a0), d6
  000ff6:  20 4d                  movea.l a5, a0
  000ff8:  d0 c7                  adda.w d7, a0
  000ffa:  1a 28 bb 2c            move.b -$44d4(a0), d5
  000ffe:  4a 05                  tst.b d5
  001000:  6d 3c                  blt.b $103e
  001002:  ba 06                  cmp.b d6, d5
  001004:  66 38                  bne.b $103e
  001006:  20 4d                  movea.l a5, a0
  001008:  d0 c7                  adda.w d7, a0
  00100a:  1c 28 bb 4a            move.b -$44b6(a0), d6
  00100e:  20 4d                  movea.l a5, a0
  001010:  d0 c7                  adda.w d7, a0
  001012:  1a 28 bb 54            move.b -$44ac(a0), d5
  001016:  18 06                  move.b d6, d4
  001018:  48 84                  ext.w d4
  00101a:  70 0f                  moveq #$f, d0
  00101c:  c0 44                  and.w d4, d0
  00101e:  66 0a                  bne.b $102a
  001020:  70 0f                  moveq #$f, d0
  001022:  c0 05                  and.b d5, d0
  001024:  67 04                  beq.b $102a
  001026:  1b 47 bb 1c            move.b d7, -$44e4(a5)
  00102a:  30 04                  move.w d4, d0
  00102c:  02 40 00 f0            andi.w #$f0, d0
  001030:  66 0c                  bne.b $103e
  001032:  10 05                  move.b d5, d0
  001034:  02 00 00 f0            andi.b #$f0, d0
  001038:  67 04                  beq.b $103e
  00103a:  1b 47 bb 1d            move.b d7, -$44e3(a5)
  00103e:  53 47                  subq.w #$1, d7
  001040:  4a 47                  tst.w d7
  001042:  6c aa                  bge.b $fee
  001044:  4c df 00 f0            movem.l (a7)+, d4-d7
  001048:  4e 75                  rts 
  00104a:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  00104e:  1e 2d bb 1f            move.b -$44e1(a5), d7
  001052:  1c 2d bb 1e            move.b -$44e2(a5), d6
  001056:  be 06                  cmp.b d6, d7
  001058:  67 1c                  beq.b $1076
  00105a:  10 06                  move.b d6, d0
  00105c:  48 80                  ext.w d0
  00105e:  12 07                  move.b d7, d1
  001060:  48 81                  ext.w d1
  001062:  56 40                  addq.w #$3, d0
  001064:  b2 40                  cmp.w d0, d1
  001066:  67 0e                  beq.b $1076
  001068:  10 06                  move.b d6, d0
  00106a:  48 80                  ext.w d0
  00106c:  12 07                  move.b d7, d1
  00106e:  48 81                  ext.w d1
  001070:  57 40                  subq.w #$3, d0
  001072:  b2 40                  cmp.w d0, d1
  001074:  66 0a                  bne.b $1080
  001076:  49 ed bb 2c            lea.l -$44d4(a5), a4
  00107a:  47 ed bb 54            lea.l -$44ac(a5), a3
  00107e:  60 2a                  bra.b $10aa
  001080:  1a 06                  move.b d6, d5
  001082:  48 85                  ext.w d5
  001084:  1c 07                  move.b d7, d6
  001086:  48 86                  ext.w d6
  001088:  70 01                  moveq #$1, d0
  00108a:  d0 45                  add.w d5, d0
  00108c:  bc 40                  cmp.w d0, d6
  00108e:  67 08                  beq.b $1098
  001090:  70 fe                  moveq #$fe, d0
  001092:  d0 45                  add.w d5, d0
  001094:  bc 40                  cmp.w d0, d6
  001096:  66 0a                  bne.b $10a2
  001098:  49 ed bb 40            lea.l -$44c0(a5), a4
  00109c:  47 ed bb 68            lea.l -$4498(a5), a3
  0010a0:  60 08                  bra.b $10aa
  0010a2:  49 ed bb 36            lea.l -$44ca(a5), a4
  0010a6:  47 ed bb 5e            lea.l -$44a2(a5), a3
  0010aa:  7e 00                  moveq #$0, d7
  0010ac:  60 30                  bra.b $10de
  0010ae:  20 4d                  movea.l a5, a0
  0010b0:  d0 c7                  adda.w d7, a0
  0010b2:  11 74 70 00 bb 22      move.b (a4, d7.w), -$44de(a0)
  0010b8:  20 4d                  movea.l a5, a0
  0010ba:  d0 c7                  adda.w d7, a0
  0010bc:  11 73 70 00 bb 4a      move.b (a3, d7.w), -$44b6(a0)
  0010c2:  20 4d                  movea.l a5, a0
  0010c4:  d0 c7                  adda.w d7, a0
  0010c6:  70 ff                  moveq #$ff, d0
  0010c8:  11 40 bb 36            move.b d0, -$44ca(a0)
  0010cc:  20 4d                  movea.l a5, a0
  0010ce:  d0 c7                  adda.w d7, a0
  0010d0:  11 40 bb 40            move.b d0, -$44c0(a0)
  0010d4:  20 4d                  movea.l a5, a0
  0010d6:  d0 c7                  adda.w d7, a0
  0010d8:  11 40 bb 2c            move.b d0, -$44d4(a0)
  0010dc:  52 47                  addq.w #$1, d7
  0010de:  0c 47 00 0a            cmpi.w #$a, d7
  0010e2:  6d ca                  blt.b $10ae
  0010e4:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  0010e8:  4e 75                  rts 
  0010ea:  4e 56 00 00            link.w a6, #$0
  0010ee:  48 e7 1f 18            movem.l d3-d7/a3-a4, -(a7)
  0010f2:  36 2e 00 08            move.w $8(a6), d3
  0010f6:  26 6e 00 0a            movea.l $a(a6), a3
  0010fa:  28 6e 00 0e            movea.l $e(a6), a4
  0010fe:  1e 2d b9 4f            move.b -$46b1(a5), d7
  001102:  48 87                  ext.w d7
  001104:  1c 2d bb 20            move.b -$44e0(a5), d6
  001108:  48 86                  ext.w d6
  00110a:  20 4d                  movea.l a5, a0
  00110c:  d0 c6                  adda.w d6, a0
  00110e:  70 00                  moveq #$0, d0
  001110:  10 28 b8 7d            move.b -$4783(a0), d0
  001114:  5e 40                  addq.w #$7, d0
  001116:  3b 40 ba be            move.w d0, -$4542(a5)
  00111a:  3a 06                  move.w d6, d5
  00111c:  60 4c                  bra.b $116a
  00111e:  7c 00                  moveq #$0, d6
  001120:  3f 03                  move.w d3, -(a7)
  001122:  3f 05                  move.w d5, -(a7)
  001124:  3f 07                  move.w d7, -(a7)
  001126:  4e ba 00 54            jsr $117c(pc)
  00112a:  38 00                  move.w d0, d4
  00112c:  b8 6d ba da            cmp.w -$4526(a5), d4
  001130:  5c 8f                  addq.l #$6, a7
  001132:  6c 04                  bge.b $1138
  001134:  00 06 00 0f            ori.b #$f, d6
  001138:  3f 03                  move.w d3, -(a7)
  00113a:  3f 05                  move.w d5, -(a7)
  00113c:  3f 07                  move.w d7, -(a7)
  00113e:  4e ba 00 84            jsr $11c4(pc)
  001142:  38 00                  move.w d0, d4
  001144:  b8 6d ba d8            cmp.w -$4528(a5), d4
  001148:  5c 8f                  addq.l #$6, a7
  00114a:  6f 04                  ble.b $1150
  00114c:  00 06 00 f0            ori.b #$f0, d6
  001150:  30 2d ba ec            move.w -$4514(a5), d0
  001154:  19 86 00 00            move.b d6, (a4, d0.w)
  001158:  30 2d ba ec            move.w -$4514(a5), d0
  00115c:  17 ad ba eb 00 00      move.b -$4515(a5), (a3, d0.w)
  001162:  06 6d 00 0e ba be      addi.w #$e, -$4542(a5)
  001168:  52 45                  addq.w #$1, d5
  00116a:  10 2d bb 21            move.b -$44df(a5), d0
  00116e:  48 80                  ext.w d0
  001170:  b0 45                  cmp.w d5, d0
  001172:  6c aa                  bge.b $111e
  001174:  4c df 18 f8            movem.l (a7)+, d3-d7/a3-a4
  001178:  4e 5e                  unlk a6
  00117a:  4e 75                  rts 
  00117c:  4e 56 00 00            link.w a6, #$0
  001180:  48 e7 0f 00            movem.l d4-d7, -(a7)
  001184:  38 2e 00 08            move.w $8(a6), d4
  001188:  3a 2e 00 0a            move.w $a(a6), d5
  00118c:  3c 2e 00 0c            move.w $c(a6), d6
  001190:  3f 06                  move.w d6, -(a7)
  001192:  3f 05                  move.w d5, -(a7)
  001194:  3f 04                  move.w d4, -(a7)
  001196:  4e ad 02 2a            jsr $22a(a5)
  00119a:  1e 80                  move.b d0, (a7)
  00119c:  4e ad 03 0a            jsr $30a(a5)
  0011a0:  3e 00                  move.w d0, d7
  0011a2:  4a 47                  tst.w d7
  0011a4:  5c 8f                  addq.l #$6, a7
  0011a6:  67 10                  beq.b $11b8
  0011a8:  20 4d                  movea.l a5, a0
  0011aa:  d0 c7                  adda.w d7, a0
  0011ac:  10 28 b8 8c            move.b -$4774(a0), d0
  0011b0:  48 80                  ext.w d0
  0011b2:  d0 6d ba be            add.w -$4542(a5), d0
  0011b6:  60 04                  bra.b $11bc
  0011b8:  30 3c 00 ff            move.w #$ff, d0
  0011bc:  4c df 00 f0            movem.l (a7)+, d4-d7
  0011c0:  4e 5e                  unlk a6
  0011c2:  4e 75                  rts 
  0011c4:  4e 56 00 00            link.w a6, #$0
  0011c8:  48 e7 0f 00            movem.l d4-d7, -(a7)
  0011cc:  38 2e 00 08            move.w $8(a6), d4
  0011d0:  3a 2e 00 0a            move.w $a(a6), d5
  0011d4:  3c 2e 00 0c            move.w $c(a6), d6
  0011d8:  3f 06                  move.w d6, -(a7)
  0011da:  3f 05                  move.w d5, -(a7)
  0011dc:  3f 04                  move.w d4, -(a7)
  0011de:  4e ad 02 2a            jsr $22a(a5)
  0011e2:  1e 80                  move.b d0, (a7)
  0011e4:  4e ad 03 0a            jsr $30a(a5)
  0011e8:  3e 00                  move.w d0, d7
  0011ea:  4a 47                  tst.w d7
  0011ec:  5c 8f                  addq.l #$6, a7
  0011ee:  67 16                  beq.b $1206
  0011f0:  20 4d                  movea.l a5, a0
  0011f2:  d0 c7                  adda.w d7, a0
  0011f4:  10 28 b8 92            move.b -$476e(a0), d0
  0011f8:  48 80                  ext.w d0
  0011fa:  72 0d                  moveq #$d, d1
  0011fc:  d2 6d ba be            add.w -$4542(a5), d1
  001200:  92 40                  sub.w d0, d1
  001202:  30 01                  move.w d1, d0
  001204:  60 02                  bra.b $1208
  001206:  70 00                  moveq #$0, d0
  001208:  4c df 00 f0            movem.l (a7)+, d4-d7
  00120c:  4e 5e                  unlk a6
  00120e:  4e 75                  rts 
  001210:  0c 2d 00 02 b9 4c      cmpi.b #$2, -$46b4(a5)
  001216:  67 2e                  beq.b $1246
  001218:  0c 2d 00 06 b9 4c      cmpi.b #$6, -$46b4(a5)
  00121e:  67 26                  beq.b $1246
  001220:  0c 2d 00 87 b9 46      cmpi.b #$87, -$46ba(a5)
  001226:  65 08                  bcs.b $1230
  001228:  0c 2d 00 95 b9 46      cmpi.b #$95, -$46ba(a5)
  00122e:  65 16                  bcs.b $1246
  001230:  4a 2d bb 1c            tst.b -$44e4(a5)
  001234:  6d 06                  blt.b $123c
  001236:  4e ba 00 10            jsr $1248(pc)
  00123a:  60 0a                  bra.b $1246
  00123c:  4a 2d bb 1d            tst.b -$44e3(a5)
  001240:  6d 04                  blt.b $1246
  001242:  4e ba 00 48            jsr $128c(pc)
  001246:  4e 75                  rts 
  001248:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  00124e:  67 06                  beq.b $1256
  001250:  4a 2d b9 49            tst.b -$46b7(a5)
  001254:  66 34                  bne.b $128a
  001256:  10 2d bb 1c            move.b -$44e4(a5), d0
  00125a:  48 80                  ext.w d0
  00125c:  3f 00                  move.w d0, -(a7)
  00125e:  4e ba 00 6e            jsr $12ce(pc)
  001262:  4a 40                  tst.w d0
  001264:  54 8f                  addq.l #$2, a7
  001266:  67 22                  beq.b $128a
  001268:  3f 3c ff ff            move.w #$ffff, -(a7)
  00126c:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  001270:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001274:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  001278:  4e ba ff 02            jsr $117c(pc)
  00127c:  90 6d ba da            sub.w -$4526(a5), d0
  001280:  58 8f                  addq.l #$4, a7
  001282:  3e 80                  move.w d0, (a7)
  001284:  4e ba 01 76            jsr $13fc(pc)
  001288:  58 8f                  addq.l #$4, a7
  00128a:  4e 75                  rts 
  00128c:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  001292:  67 06                  beq.b $129a
  001294:  4a 2d b9 49            tst.b -$46b7(a5)
  001298:  6c 32                  bge.b $12cc
  00129a:  10 2d bb 1d            move.b -$44e3(a5), d0
  00129e:  48 80                  ext.w d0
  0012a0:  3f 00                  move.w d0, -(a7)
  0012a2:  4e ba 00 2a            jsr $12ce(pc)
  0012a6:  4a 40                  tst.w d0
  0012a8:  54 8f                  addq.l #$2, a7
  0012aa:  67 20                  beq.b $12cc
  0012ac:  42 67                  clr.w -(a7)
  0012ae:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  0012b2:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  0012b6:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  0012ba:  4e ba ff 08            jsr $11c4(pc)
  0012be:  90 6d ba d8            sub.w -$4528(a5), d0
  0012c2:  58 8f                  addq.l #$4, a7
  0012c4:  3e 80                  move.w d0, (a7)
  0012c6:  4e ba 01 34            jsr $13fc(pc)
  0012ca:  58 8f                  addq.l #$4, a7
  0012cc:  4e 75                  rts 
  0012ce:  4e 56 00 00            link.w a6, #$0
  0012d2:  48 e7 03 00            movem.l d6-d7, -(a7)
  0012d6:  3c 2e 00 08            move.w $8(a6), d6
  0012da:  1e 2d b9 4b            move.b -$46b5(a5), d7
  0012de:  48 87                  ext.w d7
  0012e0:  4a 47                  tst.w d7
  0012e2:  6c 02                  bge.b $12e6
  0012e4:  56 47                  addq.w #$3, d7
  0012e6:  0c 47 00 03            cmpi.w #$3, d7
  0012ea:  6d 02                  blt.b $12ee
  0012ec:  57 47                  subq.w #$3, d7
  0012ee:  3f 07                  move.w d7, -(a7)
  0012f0:  3f 06                  move.w d6, -(a7)
  0012f2:  20 4d                  movea.l a5, a0
  0012f4:  d0 c6                  adda.w d6, a0
  0012f6:  10 28 bb 2c            move.b -$44d4(a0), d0
  0012fa:  48 80                  ext.w d0
  0012fc:  3f 00                  move.w d0, -(a7)
  0012fe:  4e ad 02 2a            jsr $22a(a5)
  001302:  4e ba 00 0c            jsr $1310(pc)
  001306:  4c ee 00 c0 ff f8      movem.l -$8(a6), d6-d7
  00130c:  4e 5e                  unlk a6
  00130e:  4e 75                  rts 
  001310:  0c 2d 00 0a ba e8      cmpi.b #$a, -$4518(a5)
  001316:  66 06                  bne.b $131e
  001318:  70 00                  moveq #$0, d0
  00131a:  60 00 00 90            bra.w $13ac
  00131e:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  001324:  66 0c                  bne.b $1332
  001326:  4e ba 02 f4            jsr $161c(pc)
  00132a:  4a 00                  tst.b d0
  00132c:  66 60                  bne.b $138e
  00132e:  70 00                  moveq #$0, d0
  001330:  60 7a                  bra.b $13ac
  001332:  0c 2d 00 12 ba e8      cmpi.b #$12, -$4518(a5)
  001338:  66 16                  bne.b $1350
  00133a:  70 00                  moveq #$0, d0
  00133c:  10 2d ba e9            move.b -$4517(a5), d0
  001340:  d0 ad bd 86            add.l -$427a(a5), d0
  001344:  20 40                  movea.l d0, a0
  001346:  0c 10 00 02            cmpi.b #$2, (a0)
  00134a:  67 42                  beq.b $138e
  00134c:  70 00                  moveq #$0, d0
  00134e:  60 5c                  bra.b $13ac
  001350:  0c 2d 00 0d ba e8      cmpi.b #$d, -$4518(a5)
  001356:  66 36                  bne.b $138e
  001358:  4a 2d b9 51            tst.b -$46af(a5)
  00135c:  66 30                  bne.b $138e
  00135e:  0c 2d 00 27 b9 46      cmpi.b #$27, -$46ba(a5)
  001364:  65 28                  bcs.b $138e
  001366:  0c 2d 00 2c b9 46      cmpi.b #$2c, -$46ba(a5)
  00136c:  64 20                  bcc.b $138e
  00136e:  4a 2d b9 49            tst.b -$46b7(a5)
  001372:  6c 1a                  bge.b $138e
  001374:  70 00                  moveq #$0, d0
  001376:  10 2d ba e9            move.b -$4517(a5), d0
  00137a:  d0 ad bd 86            add.l -$427a(a5), d0
  00137e:  20 40                  movea.l d0, a0
  001380:  10 bc 00 56            move.b #$56, (a0)
  001384:  3b 7c ff ff ba 1e      move.w #$ffff, -$45e2(a5)
  00138a:  70 00                  moveq #$0, d0
  00138c:  60 1e                  bra.b $13ac
  00138e:  30 2d ba ec            move.w -$4514(a5), d0
  001392:  20 4d                  movea.l a5, a0
  001394:  d0 c0                  adda.w d0, a0
  001396:  72 00                  moveq #$0, d1
  001398:  12 28 b8 7d            move.b -$4783(a0), d1
  00139c:  3f 01                  move.w d1, -(a7)
  00139e:  4e ba 00 0e            jsr $13ae(pc)
  0013a2:  5e 40                  addq.w #$7, d0
  0013a4:  3b 40 ba be            move.w d0, -$4542(a5)
  0013a8:  70 01                  moveq #$1, d0
  0013aa:  54 8f                  addq.l #$2, a7
  0013ac:  4e 75                  rts 
  0013ae:  4e 56 00 00            link.w a6, #$0
  0013b2:  2f 07                  move.l d7, -(a7)
  0013b4:  3e 2e 00 08            move.w $8(a6), d7
  0013b8:  30 2d ba ea            move.w -$4516(a5), d0
  0013bc:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  0013c0:  67 32                  beq.b $13f4
  0013c2:  30 2d ba ea            move.w -$4516(a5), d0
  0013c6:  b0 6d ba 6c            cmp.w -$4594(a5), d0
  0013ca:  67 0a                  beq.b $13d6
  0013cc:  30 2d ba ea            move.w -$4516(a5), d0
  0013d0:  b0 6d ba 78            cmp.w -$4588(a5), d0
  0013d4:  66 06                  bne.b $13dc
  0013d6:  06 47 ff 74            addi.w #$ff74, d7
  0013da:  60 18                  bra.b $13f4
  0013dc:  30 2d ba ea            move.w -$4516(a5), d0
  0013e0:  b0 6d ba 6e            cmp.w -$4592(a5), d0
  0013e4:  67 0a                  beq.b $13f0
  0013e6:  30 2d ba ea            move.w -$4516(a5), d0
  0013ea:  b0 6d ba 7a            cmp.w -$4586(a5), d0
  0013ee:  66 04                  bne.b $13f4
  0013f0:  06 47 00 8c            addi.w #$8c, d7
  0013f4:  30 07                  move.w d7, d0
  0013f6:  2e 1f                  move.l (a7)+, d7
  0013f8:  4e 5e                  unlk a6
  0013fa:  4e 75                  rts 
  0013fc:  4e 56 00 00            link.w a6, #$0
  001400:  4a 2d b9 53            tst.b -$46ad(a5)
  001404:  6c 00 00 a6            bge.w $14ac
  001408:  0c 2d 00 b1 b9 46      cmpi.b #$b1, -$46ba(a5)
  00140e:  67 00 00 9c            beq.w $14ac
  001412:  10 2e 00 09            move.b $9(a6), d0
  001416:  d1 2d b9 47            add.b d0, -$46b9(a5)
  00141a:  4a 6e 00 0a            tst.w $a(a6)
  00141e:  6c 20                  bge.b $1440
  001420:  0c 2d 00 14 ba e8      cmpi.b #$14, -$4518(a5)
  001426:  66 62                  bne.b $148a
  001428:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  00142c:  53 6d ba ec            subq.w #$1, -$4514(a5)
  001430:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001434:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  001438:  4e ad 02 2a            jsr $22a(a5)
  00143c:  5c 8f                  addq.l #$6, a7
  00143e:  60 4a                  bra.b $148a
  001440:  0c 2d 00 0c ba e8      cmpi.b #$c, -$4518(a5)
  001446:  67 10                  beq.b $1458
  001448:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  00144e:  67 08                  beq.b $1458
  001450:  0c 2d 00 14 ba e8      cmpi.b #$14, -$4518(a5)
  001456:  66 32                  bne.b $148a
  001458:  52 6d ba ec            addq.w #$1, -$4514(a5)
  00145c:  4a 6d ba ea            tst.w -$4516(a5)
  001460:  66 16                  bne.b $1478
  001462:  0c 6d 00 0a ba ec      cmpi.w #$a, -$4514(a5)
  001468:  66 0e                  bne.b $1478
  00146a:  10 2d b9 4f            move.b -$46b1(a5), d0
  00146e:  48 80                  ext.w d0
  001470:  3b 40 ba ea            move.w d0, -$4516(a5)
  001474:  42 6d ba ec            clr.w -$4514(a5)
  001478:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  00147c:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001480:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  001484:  4e ad 02 2a            jsr $22a(a5)
  001488:  5c 8f                  addq.l #$6, a7
  00148a:  70 00                  moveq #$0, d0
  00148c:  10 2d ba e8            move.b -$4518(a5), d0
  001490:  3f 00                  move.w d0, -(a7)
  001492:  4e ad 02 aa            jsr $2aa(a5)
  001496:  4a 00                  tst.b d0
  001498:  54 8f                  addq.l #$2, a7
  00149a:  67 0c                  beq.b $14a8
  00149c:  3f 2e 00 0a            move.w $a(a6), -(a7)
  0014a0:  4e ba 00 46            jsr $14e8(pc)
  0014a4:  54 8f                  addq.l #$2, a7
  0014a6:  60 04                  bra.b $14ac
  0014a8:  4e ba 00 06            jsr $14b0(pc)
  0014ac:  4e 5e                  unlk a6
  0014ae:  4e 75                  rts 
  0014b0:  2f 07                  move.l d7, -(a7)
  0014b2:  1e 2d b9 4c            move.b -$46b4(a5), d7
  0014b6:  48 87                  ext.w d7
  0014b8:  3f 3c ff fc            move.w #$fffc, -(a7)
  0014bc:  4e ad 02 62            jsr $262(a5)
  0014c0:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0014c4:  0c 47 00 04            cmpi.w #$4, d7
  0014c8:  54 8f                  addq.l #$2, a7
  0014ca:  66 06                  bne.b $14d2
  0014cc:  42 2d b9 4d            clr.b -$46b3(a5)
  0014d0:  60 0e                  bra.b $14e0
  0014d2:  3f 3c 00 2d            move.w #$2d, -(a7)
  0014d6:  4e ba eb 2c            jsr $4(pc)
  0014da:  4e ad 02 6a            jsr $26a(a5)
  0014de:  54 8f                  addq.l #$2, a7
  0014e0:  4e ba 00 ee            jsr $15d0(pc)
  0014e4:  2e 1f                  move.l (a7)+, d7
  0014e6:  4e 75                  rts 
  0014e8:  4e 56 00 00            link.w a6, #$0
  0014ec:  48 e7 03 00            movem.l d6-d7, -(a7)
  0014f0:  3c 2e 00 08            move.w $8(a6), d6
  0014f4:  7e 00                  moveq #$0, d7
  0014f6:  1e 2d b9 48            move.b -$46b8(a5), d7
  0014fa:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  001500:  67 20                  beq.b $1522
  001502:  10 2d b9 4b            move.b -$46b5(a5), d0
  001506:  48 80                  ext.w d0
  001508:  20 4d                  movea.l a5, a0
  00150a:  d0 c0                  adda.w d0, a0
  00150c:  d0 c0                  adda.w d0, a0
  00150e:  30 28 b6 70            move.w -$4990(a0), d0
  001512:  90 47                  sub.w d7, d0
  001514:  0c 40 00 0f            cmpi.w #$f, d0
  001518:  6d 08                  blt.b $1522
  00151a:  4e ba ff 94            jsr $14b0(pc)
  00151e:  60 00 00 a6            bra.w $15c6
  001522:  10 2d b9 4b            move.b -$46b5(a5), d0
  001526:  48 80                  ext.w d0
  001528:  20 4d                  movea.l a5, a0
  00152a:  d0 c0                  adda.w d0, a0
  00152c:  d0 c0                  adda.w d0, a0
  00152e:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  001534:  0c 2d 00 16 b9 4e      cmpi.b #$16, -$46b2(a5)
  00153a:  6d 10                  blt.b $154c
  00153c:  3f 3c ff fb            move.w #$fffb, -(a7)
  001540:  4e ad 02 62            jsr $262(a5)
  001544:  1b 40 b9 47            move.b d0, -$46b9(a5)
  001548:  54 8f                  addq.l #$2, a7
  00154a:  60 7a                  bra.b $15c6
  00154c:  42 2d b9 4e            clr.b -$46b2(a5)
  001550:  4a 2d b9 53            tst.b -$46ad(a5)
  001554:  67 70                  beq.b $15c6
  001556:  7e 00                  moveq #$0, d7
  001558:  1e 2d b9 46            move.b -$46ba(a5), d7
  00155c:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  001562:  66 28                  bne.b $158c
  001564:  10 2d b9 49            move.b -$46b7(a5), d0
  001568:  48 80                  ext.w d0
  00156a:  b0 46                  cmp.w d6, d0
  00156c:  66 1a                  bne.b $1588
  00156e:  3f 3c 00 41            move.w #$41, -(a7)
  001572:  4e ba ea 90            jsr $4(pc)
  001576:  4e ad 02 6a            jsr $26a(a5)
  00157a:  3e bc 00 01            move.w #$1, (a7)
  00157e:  4e ad 02 62            jsr $262(a5)
  001582:  1b 40 b9 47            move.b d0, -$46b9(a5)
  001586:  60 3e                  bra.b $15c6
  001588:  7e 40                  moveq #$40, d7
  00158a:  60 2a                  bra.b $15b6
  00158c:  0c 47 00 18            cmpi.w #$18, d7
  001590:  67 1e                  beq.b $15b0
  001592:  0c 47 00 19            cmpi.w #$19, d7
  001596:  67 18                  beq.b $15b0
  001598:  0c 47 00 28            cmpi.w #$28, d7
  00159c:  6d 06                  blt.b $15a4
  00159e:  0c 47 00 2b            cmpi.w #$2b, d7
  0015a2:  6d 0c                  blt.b $15b0
  0015a4:  0c 47 00 66            cmpi.w #$66, d7
  0015a8:  6d 0a                  blt.b $15b4
  0015aa:  0c 47 00 6b            cmpi.w #$6b, d7
  0015ae:  6c 04                  bge.b $15b4
  0015b0:  7e 2e                  moveq #$2e, d7
  0015b2:  60 02                  bra.b $15b6
  0015b4:  7e 2f                  moveq #$2f, d7
  0015b6:  3f 07                  move.w d7, -(a7)
  0015b8:  4e ba ea 4a            jsr $4(pc)
  0015bc:  4e ad 02 6a            jsr $26a(a5)
  0015c0:  4e ba 00 0e            jsr $15d0(pc)
  0015c4:  54 8f                  addq.l #$2, a7
  0015c6:  4c ee 00 c0 ff f8      movem.l -$8(a6), d6-d7
  0015cc:  4e 5e                  unlk a6
  0015ce:  4e 75                  rts 
  0015d0:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  0015d6:  3f 3c 00 08            move.w #$8, -(a7)
  0015da:  4e ad 03 92            jsr $392(a5)
  0015de:  54 8f                  addq.l #$2, a7
  0015e0:  4e 75                  rts 
  0015e2:  2f 07                  move.l d7, -(a7)
  0015e4:  7e 00                  moveq #$0, d7
  0015e6:  60 24                  bra.b $160c
  0015e8:  20 4d                  movea.l a5, a0
  0015ea:  d0 c7                  adda.w d7, a0
  0015ec:  70 ff                  moveq #$ff, d0
  0015ee:  11 40 bb 40            move.b d0, -$44c0(a0)
  0015f2:  20 4d                  movea.l a5, a0
  0015f4:  d0 c7                  adda.w d7, a0
  0015f6:  11 40 bb 36            move.b d0, -$44ca(a0)
  0015fa:  20 4d                  movea.l a5, a0
  0015fc:  d0 c7                  adda.w d7, a0
  0015fe:  11 40 bb 2c            move.b d0, -$44d4(a0)
  001602:  20 4d                  movea.l a5, a0
  001604:  d0 c7                  adda.w d7, a0
  001606:  11 40 bb 22            move.b d0, -$44de(a0)
  00160a:  52 47                  addq.w #$1, d7
  00160c:  0c 47 00 0a            cmpi.w #$a, d7
  001610:  6d d6                  blt.b $15e8
  001612:  1b 7c 00 ff bb 1f      move.b #$ff, -$44e1(a5)
  001618:  2e 1f                  move.l (a7)+, d7
  00161a:  4e 75                  rts 
  00161c:  70 00                  moveq #$0, d0
  00161e:  10 2d ba e9            move.b -$4517(a5), d0
  001622:  d0 ad bd 86            add.l -$427a(a5), d0
  001626:  20 40                  movea.l d0, a0
  001628:  70 00                  moveq #$0, d0
  00162a:  10 10                  move.b (a0), d0
  00162c:  81 fc 00 04            divs.w #$4, d0
  001630:  5e 40                  addq.w #$7, d0
  001632:  b0 6d ba d4            cmp.w -$452c(a5), d0
  001636:  5d c0                  slt.b d0
  001638:  44 00                  neg.b d0
  00163a:  4e 75                  rts 
  00163c:  48 e7 03 00            movem.l d6-d7, -(a7)
  001640:  4e ad 02 4a            jsr $24a(a5)
  001644:  4e ba 42 00            jsr $5846(pc)
  001648:  4e ad 02 c2            jsr $2c2(a5)
  00164c:  4e ad 02 ba            jsr $2ba(a5)
  001650:  1e 00                  move.b d0, d7
  001652:  1f 07                  move.b d7, -(a7)
  001654:  4e ad 03 0a            jsr $30a(a5)
  001658:  4a 40                  tst.w d0
  00165a:  54 8f                  addq.l #$2, a7
  00165c:  67 1a                  beq.b $1678
  00165e:  10 2d b9 4a            move.b -$46b6(a5), d0
  001662:  48 80                  ext.w d0
  001664:  3b 40 ba ec            move.w d0, -$4514(a5)
  001668:  1f 07                  move.b d7, -(a7)
  00166a:  4e ba 03 8c            jsr $19f8(pc)
  00166e:  3c 00                  move.w d0, d6
  001670:  4a 46                  tst.w d6
  001672:  54 8f                  addq.l #$2, a7
  001674:  6c 00 00 86            bge.w $16fc
  001678:  4e ad 02 da            jsr $2da(a5)
  00167c:  1e 00                  move.b d0, d7
  00167e:  0c 07 00 0c            cmpi.b #$c, d7
  001682:  66 06                  bne.b $168a
  001684:  4a 2d b9 49            tst.b -$46b7(a5)
  001688:  6c 66                  bge.b $16f0
  00168a:  1f 07                  move.b d7, -(a7)
  00168c:  4e ad 03 0a            jsr $30a(a5)
  001690:  4a 40                  tst.w d0
  001692:  54 8f                  addq.l #$2, a7
  001694:  67 18                  beq.b $16ae
  001696:  10 2d ba e4            move.b -$451c(a5), d0
  00169a:  48 80                  ext.w d0
  00169c:  3b 40 ba ec            move.w d0, -$4514(a5)
  0016a0:  1f 07                  move.b d7, -(a7)
  0016a2:  4e ba 03 54            jsr $19f8(pc)
  0016a6:  3c 00                  move.w d0, d6
  0016a8:  4a 46                  tst.w d6
  0016aa:  54 8f                  addq.l #$2, a7
  0016ac:  6c 4e                  bge.b $16fc
  0016ae:  0c 07 00 0b            cmpi.b #$b, d7
  0016b2:  67 3c                  beq.b $16f0
  0016b4:  0c 07 00 06            cmpi.b #$6, d7
  0016b8:  67 26                  beq.b $16e0
  0016ba:  0c 07 00 16            cmpi.b #$16, d7
  0016be:  67 20                  beq.b $16e0
  0016c0:  0c 07 00 0a            cmpi.b #$a, d7
  0016c4:  67 1a                  beq.b $16e0
  0016c6:  70 00                  moveq #$0, d0
  0016c8:  10 07                  move.b d7, d0
  0016ca:  3f 00                  move.w d0, -(a7)
  0016cc:  4e ad 02 aa            jsr $2aa(a5)
  0016d0:  4a 00                  tst.b d0
  0016d2:  54 8f                  addq.l #$2, a7
  0016d4:  67 1a                  beq.b $16f0
  0016d6:  1b 7c 00 02 ba e7      move.b #$2, -$4519(a5)
  0016dc:  7c 0b                  moveq #$b, d6
  0016de:  60 28                  bra.b $1708
  0016e0:  4e ad 02 ea            jsr $2ea(a5)
  0016e4:  3c 00                  move.w d0, d6
  0016e6:  4a 46                  tst.w d6
  0016e8:  67 ec                  beq.b $16d6
  0016ea:  42 2d ba e7            clr.b -$4519(a5)
  0016ee:  60 18                  bra.b $1708
  0016f0:  4e ad 02 ea            jsr $2ea(a5)
  0016f4:  3c 00                  move.w d0, d6
  0016f6:  42 2d ba e7            clr.b -$4519(a5)
  0016fa:  60 0c                  bra.b $1708
  0016fc:  0c 46 00 0e            cmpi.w #$e, d6
  001700:  6c d4                  bge.b $16d6
  001702:  1b 7c 00 01 ba e7      move.b #$1, -$4519(a5)
  001708:  1b 47 ba e8            move.b d7, -$4518(a5)
  00170c:  30 06                  move.w d6, d0
  00170e:  4c df 00 c0            movem.l (a7)+, d6-d7
  001712:  4e 75                  rts 
  001714:  48 e7 0f 00            movem.l d4-d7, -(a7)
  001718:  1e 2d b9 4b            move.b -$46b5(a5), d7
  00171c:  48 87                  ext.w d7
  00171e:  7c 00                  moveq #$0, d6
  001720:  60 4c                  bra.b $176e
  001722:  20 4d                  movea.l a5, a0
  001724:  d0 c6                  adda.w d6, a0
  001726:  0c 28 00 ff bb 54      cmpi.b #$ff, -$44ac(a0)
  00172c:  66 3e                  bne.b $176c
  00172e:  3f 07                  move.w d7, -(a7)
  001730:  3f 06                  move.w d6, -(a7)
  001732:  20 4d                  movea.l a5, a0
  001734:  d0 c6                  adda.w d6, a0
  001736:  10 28 bb 2c            move.b -$44d4(a0), d0
  00173a:  48 80                  ext.w d0
  00173c:  3f 00                  move.w d0, -(a7)
  00173e:  4e ad 02 2a            jsr $22a(a5)
  001742:  7a 00                  moveq #$0, d5
  001744:  1a 00                  move.b d0, d5
  001746:  70 00                  moveq #$0, d0
  001748:  10 2d ba e9            move.b -$4517(a5), d0
  00174c:  d0 ad bd 86            add.l -$427a(a5), d0
  001750:  20 40                  movea.l d0, a0
  001752:  78 00                  moveq #$0, d4
  001754:  18 10                  move.b (a0), d4
  001756:  02 44 00 7f            andi.w #$7f, d4
  00175a:  0c 45 00 12            cmpi.w #$12, d5
  00175e:  5c 8f                  addq.l #$6, a7
  001760:  66 0a                  bne.b $176c
  001762:  0c 44 00 02            cmpi.w #$2, d4
  001766:  66 04                  bne.b $176c
  001768:  4e ba 00 10            jsr $177a(pc)
  00176c:  52 46                  addq.w #$1, d6
  00176e:  0c 46 00 0a            cmpi.w #$a, d6
  001772:  6d ae                  blt.b $1722
  001774:  4c df 00 f0            movem.l (a7)+, d4-d7
  001778:  4e 75                  rts 
  00177a:  70 00                  moveq #$0, d0
  00177c:  10 2d ba e9            move.b -$4517(a5), d0
  001780:  d0 ad bd 86            add.l -$427a(a5), d0
  001784:  20 40                  movea.l d0, a0
  001786:  00 10 00 80            ori.b #$80, (a0)
  00178a:  0c 2d 00 b2 b9 46      cmpi.b #$b2, -$46ba(a5)
  001790:  67 74                  beq.b $1806
  001792:  10 2d b9 4f            move.b -$46b1(a5), d0
  001796:  48 80                  ext.w d0
  001798:  b0 6d ba ea            cmp.w -$4516(a5), d0
  00179c:  66 68                  bne.b $1806
  00179e:  30 2d ba ec            move.w -$4514(a5), d0
  0017a2:  20 4d                  movea.l a5, a0
  0017a4:  d0 c0                  adda.w d0, a0
  0017a6:  72 07                  moveq #$7, d1
  0017a8:  d2 28 b8 7d            add.b -$4783(a0), d1
  0017ac:  53 01                  subq.b #$1, d1
  0017ae:  1b 41 b9 47            move.b d1, -$46b9(a5)
  0017b2:  4a 2d b9 51            tst.b -$46af(a5)
  0017b6:  66 10                  bne.b $17c8
  0017b8:  3f 3c 00 06            move.w #$6, -(a7)
  0017bc:  4e ad 02 62            jsr $262(a5)
  0017c0:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0017c4:  54 8f                  addq.l #$2, a7
  0017c6:  60 0e                  bra.b $17d6
  0017c8:  3f 3c 00 07            move.w #$7, -(a7)
  0017cc:  4e ad 02 62            jsr $262(a5)
  0017d0:  1b 40 b9 47            move.b d0, -$46b9(a5)
  0017d4:  54 8f                  addq.l #$2, a7
  0017d6:  10 2d b9 4b            move.b -$46b5(a5), d0
  0017da:  48 80                  ext.w d0
  0017dc:  20 4d                  movea.l a5, a0
  0017de:  d0 c0                  adda.w d0, a0
  0017e0:  d0 c0                  adda.w d0, a0
  0017e2:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  0017e8:  3f 3c 00 64            move.w #$64, -(a7)
  0017ec:  4e ad 02 b2            jsr $2b2(a5)
  0017f0:  3e bc 00 2e            move.w #$2e, (a7)
  0017f4:  4e ad 03 92            jsr $392(a5)
  0017f8:  3e bc 00 36            move.w #$36, (a7)
  0017fc:  4e ba e8 06            jsr $4(pc)
  001800:  4e ad 02 6a            jsr $26a(a5)
  001804:  54 8f                  addq.l #$2, a7
  001806:  4e 75                  rts 
  001808:  2f 07                  move.l d7, -(a7)
  00180a:  7e 00                  moveq #$0, d7
  00180c:  1e 2d b9 46            move.b -$46ba(a5), d7
  001810:  0c 2d 00 07 b9 4c      cmpi.b #$7, -$46b4(a5)
  001816:  67 12                  beq.b $182a
  001818:  0c 47 00 0f            cmpi.w #$f, d7
  00181c:  67 0c                  beq.b $182a
  00181e:  0c 47 00 6c            cmpi.w #$6c, d7
  001822:  6d 70                  blt.b $1894
  001824:  0c 47 00 6f            cmpi.w #$6f, d7
  001828:  6c 6a                  bge.b $1894
  00182a:  4e ad 02 ba            jsr $2ba(a5)
  00182e:  3e 2d ba ec            move.w -$4514(a5), d7
  001832:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  001838:  67 1e                  beq.b $1858
  00183a:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  00183e:  53 6d ba ec            subq.w #$1, -$4514(a5)
  001842:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  001846:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  00184a:  4e ad 02 2a            jsr $22a(a5)
  00184e:  72 00                  moveq #$0, d1
  001850:  12 00                  move.b d0, d1
  001852:  59 41                  subq.w #$4, d1
  001854:  5c 8f                  addq.l #$6, a7
  001856:  66 3c                  bne.b $1894
  001858:  30 2d ba ec            move.w -$4514(a5), d0
  00185c:  20 4d                  movea.l a5, a0
  00185e:  d0 c0                  adda.w d0, a0
  001860:  72 00                  moveq #$0, d1
  001862:  12 28 bb 54            move.b -$44ac(a0), d1
  001866:  20 4d                  movea.l a5, a0
  001868:  d0 c0                  adda.w d0, a0
  00186a:  74 00                  moveq #$0, d2
  00186c:  14 28 bb 4a            move.b -$44b6(a0), d2
  001870:  c2 42                  and.w d2, d1
  001872:  0c 41 00 ff            cmpi.w #$ff, d1
  001876:  66 1c                  bne.b $1894
  001878:  4e ba fd a2            jsr $161c(pc)
  00187c:  4a 00                  tst.b d0
  00187e:  67 14                  beq.b $1894
  001880:  4e ba fd 4e            jsr $15d0(pc)
  001884:  be 6d ba ec            cmp.w -$4514(a5), d7
  001888:  6e 06                  bgt.b $1890
  00188a:  5b 2d b9 47            subq.b #$5, -$46b9(a5)
  00188e:  60 04                  bra.b $1894
  001890:  5a 2d b9 47            addq.b #$5, -$46b9(a5)
  001894:  2e 1f                  move.l (a7)+, d7
  001896:  4e 75                  rts 
  001898:  2f 07                  move.l d7, -(a7)
  00189a:  4a 6d ba 82            tst.w -$457e(a5)
  00189e:  66 00 00 be            bne.w $195e
  0018a2:  0c 2d 00 01 b9 4c      cmpi.b #$1, -$46b4(a5)
  0018a8:  66 00 00 b4            bne.w $195e
  0018ac:  4a 2d b9 53            tst.b -$46ad(a5)
  0018b0:  6c 00 00 ac            bge.w $195e
  0018b4:  0c 2d 00 02 b9 52      cmpi.b #$2, -$46ae(a5)
  0018ba:  6d 00 00 a2            blt.w $195e
  0018be:  4e ad 02 ba            jsr $2ba(a5)
  0018c2:  72 00                  moveq #$0, d1
  0018c4:  12 00                  move.b d0, d1
  0018c6:  0c 41 00 14            cmpi.w #$14, d1
  0018ca:  67 4c                  beq.b $1918
  0018cc:  0c 2d 00 07 ba e8      cmpi.b #$7, -$4518(a5)
  0018d2:  67 44                  beq.b $1918
  0018d4:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  0018da:  66 08                  bne.b $18e4
  0018dc:  4e ba fd 3e            jsr $161c(pc)
  0018e0:  4a 00                  tst.b d0
  0018e2:  66 34                  bne.b $1918
  0018e4:  4a 2d b9 49            tst.b -$46b7(a5)
  0018e8:  6d 74                  blt.b $195e
  0018ea:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  0018ee:  53 6d ba ec            subq.w #$1, -$4514(a5)
  0018f2:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  0018f6:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  0018fa:  4e ad 02 2a            jsr $22a(a5)
  0018fe:  72 00                  moveq #$0, d1
  001900:  12 00                  move.b d0, d1
  001902:  5f 41                  subq.w #$7, d1
  001904:  5c 8f                  addq.l #$6, a7
  001906:  67 10                  beq.b $1918
  001908:  0c 2d 00 04 ba e8      cmpi.b #$4, -$4518(a5)
  00190e:  66 4e                  bne.b $195e
  001910:  4e ba fd 0a            jsr $161c(pc)
  001914:  4a 00                  tst.b d0
  001916:  67 46                  beq.b $195e
  001918:  4e ba 3f 2c            jsr $5846(pc)
  00191c:  4e ad 02 c2            jsr $2c2(a5)
  001920:  4e ba f9 ee            jsr $1310(pc)
  001924:  4a 40                  tst.w d0
  001926:  67 36                  beq.b $195e
  001928:  1f 2d ba e8            move.b -$4518(a5), -(a7)
  00192c:  4e ba 01 48            jsr $1a76(pc)
  001930:  3e 00                  move.w d0, d7
  001932:  4a 47                  tst.w d7
  001934:  54 8f                  addq.l #$2, a7
  001936:  6c 26                  bge.b $195e
  001938:  0c 47 ff f3            cmpi.w #$fff3, d7
  00193c:  6f 20                  ble.b $195e
  00193e:  30 07                  move.w d7, d0
  001940:  44 40                  neg.w d0
  001942:  3f 00                  move.w d0, -(a7)
  001944:  4e ad 02 62            jsr $262(a5)
  001948:  1b 40 b9 47            move.b d0, -$46b9(a5)
  00194c:  3e bc 00 41            move.w #$41, (a7)
  001950:  4e ba e6 b2            jsr $4(pc)
  001954:  4e ad 02 6a            jsr $26a(a5)
  001958:  4e ad 02 42            jsr $242(a5)
  00195c:  54 8f                  addq.l #$2, a7
  00195e:  2e 1f                  move.l (a7)+, d7
  001960:  4e 75                  rts 
  001962:  4e ad 02 ba            jsr $2ba(a5)
  001966:  4e ba 00 22            jsr $198a(pc)
  00196a:  4a 00                  tst.b d0
  00196c:  66 1a                  bne.b $1988
  00196e:  52 6d ba ec            addq.w #$1, -$4514(a5)
  001972:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  001976:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  00197a:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  00197e:  4e ad 02 2a            jsr $22a(a5)
  001982:  4e ba 00 06            jsr $198a(pc)
  001986:  5c 8f                  addq.l #$6, a7
  001988:  4e 75                  rts 
  00198a:  0c 2d 00 12 ba e8      cmpi.b #$12, -$4518(a5)
  001990:  66 62                  bne.b $19f4
  001992:  70 00                  moveq #$0, d0
  001994:  10 2d ba e9            move.b -$4517(a5), d0
  001998:  d0 ad bd 86            add.l -$427a(a5), d0
  00199c:  20 40                  movea.l d0, a0
  00199e:  70 00                  moveq #$0, d0
  0019a0:  10 10                  move.b (a0), d0
  0019a2:  02 40 00 7f            andi.w #$7f, d0
  0019a6:  55 40                  subq.w #$2, d0
  0019a8:  66 4a                  bne.b $19f4
  0019aa:  30 2d ba ec            move.w -$4514(a5), d0
  0019ae:  20 4d                  movea.l a5, a0
  0019b0:  d0 c0                  adda.w d0, a0
  0019b2:  72 00                  moveq #$0, d1
  0019b4:  12 28 b8 7d            move.b -$4783(a0), d1
  0019b8:  5e 41                  addq.w #$7, d1
  0019ba:  3b 41 ba be            move.w d1, -$4542(a5)
  0019be:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  0019c2:  3f 00                  move.w d0, -(a7)
  0019c4:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  0019c8:  4e ba f7 b2            jsr $117c(pc)
  0019cc:  b0 6d ba da            cmp.w -$4526(a5), d0
  0019d0:  5c 8f                  addq.l #$6, a7
  0019d2:  6c 20                  bge.b $19f4
  0019d4:  3f 2d ba ee            move.w -$4512(a5), -(a7)
  0019d8:  3f 2d ba ec            move.w -$4514(a5), -(a7)
  0019dc:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  0019e0:  4e ba f7 e2            jsr $11c4(pc)
  0019e4:  b0 6d ba d8            cmp.w -$4528(a5), d0
  0019e8:  5c 8f                  addq.l #$6, a7
  0019ea:  6f 08                  ble.b $19f4
  0019ec:  4e ba fd 8c            jsr $177a(pc)
  0019f0:  70 01                  moveq #$1, d0
  0019f2:  60 02                  bra.b $19f6
  0019f4:  70 00                  moveq #$0, d0
  0019f6:  4e 75                  rts 
  0019f8:  4e 56 00 00            link.w a6, #$0
  0019fc:  48 e7 03 00            movem.l d6-d7, -(a7)
  001a00:  1e 2e 00 08            move.b $8(a6), d7
  001a04:  0c 07 00 04            cmpi.b #$4, d7
  001a08:  66 0c                  bne.b $1a16
  001a0a:  4e ba fc 10            jsr $161c(pc)
  001a0e:  4a 00                  tst.b d0
  001a10:  66 04                  bne.b $1a16
  001a12:  70 ff                  moveq #$ff, d0
  001a14:  60 58                  bra.b $1a6e
  001a16:  30 2d ba ec            move.w -$4514(a5), d0
  001a1a:  20 4d                  movea.l a5, a0
  001a1c:  d0 c0                  adda.w d0, a0
  001a1e:  72 00                  moveq #$0, d1
  001a20:  12 28 b8 7d            move.b -$4783(a0), d1
  001a24:  5e 41                  addq.w #$7, d1
  001a26:  3b 41 ba be            move.w d1, -$4542(a5)
  001a2a:  1f 07                  move.b d7, -(a7)
  001a2c:  4e ad 03 0a            jsr $30a(a5)
  001a30:  3c 00                  move.w d0, d6
  001a32:  4a 46                  tst.w d6
  001a34:  54 8f                  addq.l #$2, a7
  001a36:  66 04                  bne.b $1a3c
  001a38:  70 ff                  moveq #$ff, d0
  001a3a:  60 32                  bra.b $1a6e
  001a3c:  4a 2d b9 49            tst.b -$46b7(a5)
  001a40:  6c 1a                  bge.b $1a5c
  001a42:  20 4d                  movea.l a5, a0
  001a44:  d0 c6                  adda.w d6, a0
  001a46:  10 28 b8 92            move.b -$476e(a0), d0
  001a4a:  48 80                  ext.w d0
  001a4c:  72 0d                  moveq #$d, d1
  001a4e:  d2 6d ba be            add.w -$4542(a5), d1
  001a52:  92 40                  sub.w d0, d1
  001a54:  30 2d ba d8            move.w -$4528(a5), d0
  001a58:  90 41                  sub.w d1, d0
  001a5a:  60 12                  bra.b $1a6e
  001a5c:  20 4d                  movea.l a5, a0
  001a5e:  d0 c6                  adda.w d6, a0
  001a60:  10 28 b8 8c            move.b -$4774(a0), d0
  001a64:  48 80                  ext.w d0
  001a66:  d0 6d ba be            add.w -$4542(a5), d0
  001a6a:  90 6d ba da            sub.w -$4526(a5), d0
  001a6e:  4c df 00 c0            movem.l (a7)+, d6-d7
  001a72:  4e 5e                  unlk a6
  001a74:  4e 75                  rts 
  001a76:  4e 56 00 00            link.w a6, #$0
  001a7a:  48 e7 07 00            movem.l d5-d7, -(a7)
  001a7e:  1a 2e 00 08            move.b $8(a6), d5
  001a82:  1f 05                  move.b d5, -(a7)
  001a84:  4e ad 03 0a            jsr $30a(a5)
  001a88:  3c 00                  move.w d0, d6
  001a8a:  4a 46                  tst.w d6
  001a8c:  54 8f                  addq.l #$2, a7
  001a8e:  66 04                  bne.b $1a94
  001a90:  70 63                  moveq #$63, d0
  001a92:  60 32                  bra.b $1ac6
  001a94:  4a 2d b9 49            tst.b -$46b7(a5)
  001a98:  6d 1a                  blt.b $1ab4
  001a9a:  20 4d                  movea.l a5, a0
  001a9c:  d0 c6                  adda.w d6, a0
  001a9e:  10 28 b8 9e            move.b -$4762(a0), d0
  001aa2:  48 80                  ext.w d0
  001aa4:  72 0d                  moveq #$d, d1
  001aa6:  d2 6d ba be            add.w -$4542(a5), d1
  001aaa:  92 40                  sub.w d0, d1
  001aac:  30 2d ba d8            move.w -$4528(a5), d0
  001ab0:  90 41                  sub.w d1, d0
  001ab2:  60 12                  bra.b $1ac6
  001ab4:  20 4d                  movea.l a5, a0
  001ab6:  d0 c6                  adda.w d6, a0
  001ab8:  10 28 b8 98            move.b -$4768(a0), d0
  001abc:  48 80                  ext.w d0
  001abe:  d0 6d ba be            add.w -$4542(a5), d0
  001ac2:  90 6d ba da            sub.w -$4526(a5), d0
  001ac6:  4c df 00 e0            movem.l (a7)+, d5-d7
  001aca:  4e 5e                  unlk a6
  001acc:  4e 75                  rts 
  001ace:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  001ad2:  7e 00                  moveq #$0, d7
  001ad4:  7c 00                  moveq #$0, d6
  001ad6:  49 ed bc 6e            lea.l -$4392(a5), a4
  001ada:  60 1a                  bra.b $1af6
  001adc:  2b 54 bc e6            move.l (a4), -$431a(a5)
  001ae0:  4e ba 00 52            jsr $1b34(pc)
  001ae4:  19 6d bc e8 00 02      move.b -$4318(a5), $2(a4)
  001aea:  4a 2c 00 02            tst.b $2(a4)
  001aee:  6c 02                  bge.b $1af2
  001af0:  7e 01                  moveq #$1, d7
  001af2:  52 46                  addq.w #$1, d6
  001af4:  58 8c                  addq.l #$4, a4
  001af6:  bc 6d bc 6c            cmp.w -$4394(a5), d6
  001afa:  6d e0                  blt.b $1adc
  001afc:  4a 47                  tst.w d7
  001afe:  67 2e                  beq.b $1b2e
  001b00:  7e 00                  moveq #$0, d7
  001b02:  7c 00                  moveq #$0, d6
  001b04:  49 ed bc 6e            lea.l -$4392(a5), a4
  001b08:  60 1a                  bra.b $1b24
  001b0a:  4a 2c 00 02            tst.b $2(a4)
  001b0e:  6d 10                  blt.b $1b20
  001b10:  20 4d                  movea.l a5, a0
  001b12:  20 07                  move.l d7, d0
  001b14:  48 c0                  ext.l d0
  001b16:  e5 88                  lsl.l #$2, d0
  001b18:  d1 c0                  adda.l d0, a0
  001b1a:  21 54 bc 6e            move.l (a4), -$4392(a0)
  001b1e:  52 47                  addq.w #$1, d7
  001b20:  52 46                  addq.w #$1, d6
  001b22:  58 8c                  addq.l #$4, a4
  001b24:  bc 6d bc 6c            cmp.w -$4394(a5), d6
  001b28:  6d e0                  blt.b $1b0a
  001b2a:  3b 47 bc 6c            move.w d7, -$4394(a5)
  001b2e:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  001b32:  4e 75                  rts 
  001b34:  70 00                  moveq #$0, d0
  001b36:  10 2d bc e7            move.b -$4319(a5), d0
  001b3a:  3f 00                  move.w d0, -(a7)
  001b3c:  4e ba 36 2c            jsr $516a(pc)
  001b40:  70 00                  moveq #$0, d0
  001b42:  10 2d bc e6            move.b -$431a(a5), d0
  001b46:  3e 80                  move.w d0, (a7)
  001b48:  4e ba 10 7a            jsr $2bc4(pc)
  001b4c:  70 00                  moveq #$0, d0
  001b4e:  10 2d ba 94            move.b -$456c(a5), d0
  001b52:  0c 40 00 1e            cmpi.w #$1e, d0
  001b56:  54 8f                  addq.l #$2, a7
  001b58:  62 48                  bhi.b $1ba2
  001b5a:  43 fa 00 5e            lea.l $1bba(pc), a1
  001b5e:  d0 40                  add.w d0, d0
  001b60:  d2 f1 00 00            adda.w (a1, d0.w), a1
  001b64:  4e d1                  jmp (a1)
  001b66:  4e ba 02 c6            jsr $1e2e(pc)
  001b6a:  60 3c                  bra.b $1ba8
  001b6c:  4e ba 0d 3a            jsr $28a8(pc)
  001b70:  60 36                  bra.b $1ba8
  001b72:  4e ba 03 d0            jsr $1f44(pc)
  001b76:  60 30                  bra.b $1ba8
  001b78:  4e ba 0d 9c            jsr $2916(pc)
  001b7c:  60 2a                  bra.b $1ba8
  001b7e:  4e ba 0d 8a            jsr $290a(pc)
  001b82:  60 24                  bra.b $1ba8
  001b84:  4e ba 03 2c            jsr $1eb2(pc)
  001b88:  60 1e                  bra.b $1ba8
  001b8a:  4e ba 04 0c            jsr $1f98(pc)
  001b8e:  60 18                  bra.b $1ba8
  001b90:  4e ba 05 1a            jsr $20ac(pc)
  001b94:  60 12                  bra.b $1ba8
  001b96:  4e ba 02 b6            jsr $1e4e(pc)
  001b9a:  60 0c                  bra.b $1ba8
  001b9c:  4e ba 02 ea            jsr $1e88(pc)
  001ba0:  60 06                  bra.b $1ba8
  001ba2:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  001ba8:  70 00                  moveq #$0, d0
  001baa:  10 2d bc e6            move.b -$431a(a5), d0
  001bae:  d0 ad bd 86            add.l -$427a(a5), d0
  001bb2:  20 40                  movea.l d0, a0
  001bb4:  10 ad ba 95            move.b -$456b(a5), (a0)
  001bb8:  4e 75                  rts 
  001bba:  ff c4                  dc.w $ffc4
  001bbc:  ff e8                  dc.w $ffe8
  001bbe:  ff b8                  dc.w $ffb8
  001bc0:  ff e8                  dc.w $ffe8
  001bc2:  ff d0                  dc.w $ffd0
  001bc4:  ff e8                  dc.w $ffe8
  001bc6:  ff b2                  dc.w $ffb2
  001bc8:  ff e8                  dc.w $ffe8
  001bca:  ff e8                  dc.w $ffe8
  001bcc:  ff e8                  dc.w $ffe8
  001bce:  ff dc                  dc.w $ffdc
  001bd0:  ff be                  dc.w $ffbe
  001bd2:  ff e8                  dc.w $ffe8
  001bd4:  ff e8                  dc.w $ffe8
  001bd6:  ff e8                  dc.w $ffe8
  001bd8:  ff b2                  dc.w $ffb2
  001bda:  ff d6                  dc.w $ffd6
  001bdc:  ff e8                  dc.w $ffe8
  001bde:  ff ca                  dc.w $ffca
  001be0:  ff ac                  dc.w $ffac
  001be2:  ff e8                  dc.w $ffe8
  001be4:  ff e8                  dc.w $ffe8
  001be6:  ff e2                  dc.w $ffe2
  001be8:  ff e8                  dc.w $ffe8
  001bea:  ff e8                  dc.w $ffe8
  001bec:  ff e8                  dc.w $ffe8
  001bee:  ff e8                  dc.w $ffe8
  001bf0:  ff e8                  dc.w $ffe8
  001bf2:  ff e8                  dc.w $ffe8
  001bf4:  ff e8                  dc.w $ffe8
  001bf6:  ff ac                  dc.w $ffac
  001bf8:  70 00                  moveq #$0, d0
  001bfa:  10 2d bc e7            move.b -$4319(a5), d0
  001bfe:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  001c02:  67 0a                  beq.b $1c0e
  001c04:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  001c0a:  70 00                  moveq #$0, d0
  001c0c:  60 02                  bra.b $1c10
  001c0e:  70 01                  moveq #$1, d0
  001c10:  4e 75                  rts 
  001c12:  4e ba 00 f4            jsr $1d08(pc)
  001c16:  3f 00                  move.w d0, -(a7)
  001c18:  4e ba 05 e6            jsr $2200(pc)
  001c1c:  54 8f                  addq.l #$2, a7
  001c1e:  4e 75                  rts 
  001c20:  4e ba 00 a6            jsr $1cc8(pc)
  001c24:  3f 00                  move.w d0, -(a7)
  001c26:  4e ba 05 d8            jsr $2200(pc)
  001c2a:  54 8f                  addq.l #$2, a7
  001c2c:  4e 75                  rts 
  001c2e:  3b 7c 00 3f bd 6c      move.w #$3f, -$4294(a5)
  001c34:  4e ba 00 92            jsr $1cc8(pc)
  001c38:  3f 00                  move.w d0, -(a7)
  001c3a:  4e ba 07 06            jsr $2342(pc)
  001c3e:  54 8f                  addq.l #$2, a7
  001c40:  4e 75                  rts 
  001c42:  3b 7c 00 21 bd 6c      move.w #$21, -$4294(a5)
  001c48:  4e ba 00 7e            jsr $1cc8(pc)
  001c4c:  3f 00                  move.w d0, -(a7)
  001c4e:  4e ba 06 f2            jsr $2342(pc)
  001c52:  4e ba 00 b4            jsr $1d08(pc)
  001c56:  3e 80                  move.w d0, (a7)
  001c58:  4e ba 06 e8            jsr $2342(pc)
  001c5c:  54 8f                  addq.l #$2, a7
  001c5e:  4e 75                  rts 
  001c60:  3b 7c 00 13 bd 6c      move.w #$13, -$4294(a5)
  001c66:  4e ba 00 60            jsr $1cc8(pc)
  001c6a:  3f 00                  move.w d0, -(a7)
  001c6c:  4e ba 06 d4            jsr $2342(pc)
  001c70:  4e ba 00 96            jsr $1d08(pc)
  001c74:  3e 80                  move.w d0, (a7)
  001c76:  4e ba 06 ca            jsr $2342(pc)
  001c7a:  54 8f                  addq.l #$2, a7
  001c7c:  4e 75                  rts 
  001c7e:  3b 7c 00 20 bd 6c      move.w #$20, -$4294(a5)
  001c84:  4e ba 00 42            jsr $1cc8(pc)
  001c88:  3f 00                  move.w d0, -(a7)
  001c8a:  4e ba 06 b6            jsr $2342(pc)
  001c8e:  4e ba 00 78            jsr $1d08(pc)
  001c92:  3e 80                  move.w d0, (a7)
  001c94:  4e ba 06 ac            jsr $2342(pc)
  001c98:  54 8f                  addq.l #$2, a7
  001c9a:  4e 75                  rts 
  001c9c:  2f 07                  move.l d7, -(a7)
  001c9e:  4e ba 00 68            jsr $1d08(pc)
  001ca2:  3e 00                  move.w d0, d7
  001ca4:  3f 07                  move.w d7, -(a7)
  001ca6:  4e ba 05 58            jsr $2200(pc)
  001caa:  3e 87                  move.w d7, (a7)
  001cac:  4e ba 06 2a            jsr $22d8(pc)
  001cb0:  4e ba 00 e2            jsr $1d94(pc)
  001cb4:  3e 00                  move.w d0, d7
  001cb6:  3e 87                  move.w d7, (a7)
  001cb8:  4e ba 05 46            jsr $2200(pc)
  001cbc:  3e 87                  move.w d7, (a7)
  001cbe:  4e ba 05 e2            jsr $22a2(pc)
  001cc2:  54 8f                  addq.l #$2, a7
  001cc4:  2e 1f                  move.l (a7)+, d7
  001cc6:  4e 75                  rts 
  001cc8:  48 e7 03 00            movem.l d6-d7, -(a7)
  001ccc:  7e 00                  moveq #$0, d7
  001cce:  1e 2d bc e6            move.b -$431a(a5), d7
  001cd2:  7c 00                  moveq #$0, d6
  001cd4:  1c 2d bc e7            move.b -$4319(a5), d6
  001cd8:  bc 6d ba 70            cmp.w -$4590(a5), d6
  001cdc:  66 1a                  bne.b $1cf8
  001cde:  0c 47 00 14            cmpi.w #$14, d7
  001ce2:  6d 10                  blt.b $1cf4
  001ce4:  0c 47 00 1e            cmpi.w #$1e, d7
  001ce8:  6c 0a                  bge.b $1cf4
  001cea:  70 1e                  moveq #$1e, d0
  001cec:  90 47                  sub.w d7, d0
  001cee:  7e f5                  moveq #$f5, d7
  001cf0:  de 40                  add.w d0, d7
  001cf2:  60 0c                  bra.b $1d00
  001cf4:  7e 1e                  moveq #$1e, d7
  001cf6:  60 08                  bra.b $1d00
  001cf8:  bc 6d ba 6a            cmp.w -$4596(a5), d6
  001cfc:  67 02                  beq.b $1d00
  001cfe:  7e 1e                  moveq #$1e, d7
  001d00:  30 07                  move.w d7, d0
  001d02:  4c df 00 c0            movem.l (a7)+, d6-d7
  001d06:  4e 75                  rts 
  001d08:  48 e7 03 00            movem.l d6-d7, -(a7)
  001d0c:  7e 00                  moveq #$0, d7
  001d0e:  1e 2d bc e6            move.b -$431a(a5), d7
  001d12:  7c 00                  moveq #$0, d6
  001d14:  1c 2d bc e7            move.b -$4319(a5), d6
  001d18:  bc 6d ba 6a            cmp.w -$4596(a5), d6
  001d1c:  66 18                  bne.b $1d36
  001d1e:  20 07                  move.l d7, d0
  001d20:  48 c0                  ext.l d0
  001d22:  81 fc 00 0a            divs.w #$a, d0
  001d26:  48 40                  swap d0
  001d28:  0c 40 00 09            cmpi.w #$9, d0
  001d2c:  66 04                  bne.b $1d32
  001d2e:  7e 1e                  moveq #$1e, d7
  001d30:  60 5a                  bra.b $1d8c
  001d32:  52 47                  addq.w #$1, d7
  001d34:  60 56                  bra.b $1d8c
  001d36:  bc 6d ba 6c            cmp.w -$4594(a5), d6
  001d3a:  66 1a                  bne.b $1d56
  001d3c:  20 07                  move.l d7, d0
  001d3e:  48 c0                  ext.l d0
  001d40:  81 fc 00 0a            divs.w #$a, d0
  001d44:  48 40                  swap d0
  001d46:  0c 40 00 09            cmpi.w #$9, d0
  001d4a:  66 06                  bne.b $1d52
  001d4c:  06 47 ff f7            addi.w #$fff7, d7
  001d50:  60 3a                  bra.b $1d8c
  001d52:  7e 1e                  moveq #$1e, d7
  001d54:  60 36                  bra.b $1d8c
  001d56:  bc 6d ba 70            cmp.w -$4590(a5), d6
  001d5a:  66 1a                  bne.b $1d76
  001d5c:  0c 47 00 14            cmpi.w #$14, d7
  001d60:  6d 10                  blt.b $1d72
  001d62:  0c 47 00 1d            cmpi.w #$1d, d7
  001d66:  6c 0a                  bge.b $1d72
  001d68:  70 1e                  moveq #$1e, d0
  001d6a:  90 47                  sub.w d7, d0
  001d6c:  7e f4                  moveq #$f4, d7
  001d6e:  de 40                  add.w d0, d7
  001d70:  60 1a                  bra.b $1d8c
  001d72:  7e 1e                  moveq #$1e, d7
  001d74:  60 16                  bra.b $1d8c
  001d76:  bc 6d ba 74            cmp.w -$458c(a5), d6
  001d7a:  66 0e                  bne.b $1d8a
  001d7c:  0c 47 00 1d            cmpi.w #$1d, d7
  001d80:  66 04                  bne.b $1d86
  001d82:  7e ff                  moveq #$ff, d7
  001d84:  60 06                  bra.b $1d8c
  001d86:  7e 1e                  moveq #$1e, d7
  001d88:  60 02                  bra.b $1d8c
  001d8a:  7e 1e                  moveq #$1e, d7
  001d8c:  30 07                  move.w d7, d0
  001d8e:  4c df 00 c0            movem.l (a7)+, d6-d7
  001d92:  4e 75                  rts 
  001d94:  48 e7 03 00            movem.l d6-d7, -(a7)
  001d98:  7e 00                  moveq #$0, d7
  001d9a:  1e 2d bc e6            move.b -$431a(a5), d7
  001d9e:  7c 00                  moveq #$0, d6
  001da0:  1c 2d bc e7            move.b -$4319(a5), d6
  001da4:  bc 6d ba 6a            cmp.w -$4596(a5), d6
  001da8:  66 26                  bne.b $1dd0
  001daa:  20 07                  move.l d7, d0
  001dac:  48 c0                  ext.l d0
  001dae:  81 fc 00 0a            divs.w #$a, d0
  001db2:  48 40                  swap d0
  001db4:  0c 40 00 09            cmpi.w #$9, d0
  001db8:  66 04                  bne.b $1dbe
  001dba:  7e 1e                  moveq #$1e, d7
  001dbc:  60 68                  bra.b $1e26
  001dbe:  0c 47 00 0a            cmpi.w #$a, d7
  001dc2:  6c 06                  bge.b $1dca
  001dc4:  44 47                  neg.w d7
  001dc6:  54 47                  addq.w #$2, d7
  001dc8:  60 5c                  bra.b $1e26
  001dca:  06 47 ff f7            addi.w #$fff7, d7
  001dce:  60 56                  bra.b $1e26
  001dd0:  bc 6d ba 6c            cmp.w -$4594(a5), d6
  001dd4:  66 24                  bne.b $1dfa
  001dd6:  0c 47 00 09            cmpi.w #$9, d7
  001dda:  66 04                  bne.b $1de0
  001ddc:  7e ff                  moveq #$ff, d7
  001dde:  60 46                  bra.b $1e26
  001de0:  20 07                  move.l d7, d0
  001de2:  48 c0                  ext.l d0
  001de4:  81 fc 00 0a            divs.w #$a, d0
  001de8:  48 40                  swap d0
  001dea:  0c 40 00 09            cmpi.w #$9, d0
  001dee:  66 06                  bne.b $1df6
  001df0:  06 47 ff ed            addi.w #$ffed, d7
  001df4:  60 30                  bra.b $1e26
  001df6:  7e 1e                  moveq #$1e, d7
  001df8:  60 2c                  bra.b $1e26
  001dfa:  bc 6d ba 72            cmp.w -$458e(a5), d6
  001dfe:  66 10                  bne.b $1e10
  001e00:  0c 47 00 09            cmpi.w #$9, d7
  001e04:  6c 06                  bge.b $1e0c
  001e06:  06 47 00 15            addi.w #$15, d7
  001e0a:  60 1a                  bra.b $1e26
  001e0c:  7e 1e                  moveq #$1e, d7
  001e0e:  60 16                  bra.b $1e26
  001e10:  bc 6d ba 78            cmp.w -$4588(a5), d6
  001e14:  66 0e                  bne.b $1e24
  001e16:  0c 47 00 09            cmpi.w #$9, d7
  001e1a:  66 04                  bne.b $1e20
  001e1c:  7e 14                  moveq #$14, d7
  001e1e:  60 06                  bra.b $1e26
  001e20:  7e 1e                  moveq #$1e, d7
  001e22:  60 02                  bra.b $1e26
  001e24:  7e 1e                  moveq #$1e, d7
  001e26:  30 07                  move.w d7, d0
  001e28:  4c df 00 c0            movem.l (a7)+, d6-d7
  001e2c:  4e 75                  rts 
  001e2e:  4e ba fd c8            jsr $1bf8(pc)
  001e32:  4a 00                  tst.b d0
  001e34:  67 16                  beq.b $1e4c
  001e36:  70 00                  moveq #$0, d0
  001e38:  10 2d ba 95            move.b -$456b(a5), d0
  001e3c:  3f 00                  move.w d0, -(a7)
  001e3e:  4e ba 03 88            jsr $21c8(pc)
  001e42:  1b 40 ba 95            move.b d0, -$456b(a5)
  001e46:  4e ba fd ca            jsr $1c12(pc)
  001e4a:  54 8f                  addq.l #$2, a7
  001e4c:  4e 75                  rts 
  001e4e:  2f 07                  move.l d7, -(a7)
  001e50:  4a 2d bc e8            tst.b -$4318(a5)
  001e54:  6d 2e                  blt.b $1e84
  001e56:  4e ba fd a0            jsr $1bf8(pc)
  001e5a:  4a 00                  tst.b d0
  001e5c:  67 26                  beq.b $1e84
  001e5e:  7e 00                  moveq #$0, d7
  001e60:  1e 2d ba 95            move.b -$456b(a5), d7
  001e64:  02 47 00 e0            andi.w #$e0, d7
  001e68:  70 00                  moveq #$0, d0
  001e6a:  10 2d ba 95            move.b -$456b(a5), d0
  001e6e:  02 40 00 0f            andi.w #$f, d0
  001e72:  3f 00                  move.w d0, -(a7)
  001e74:  4e ba 03 20            jsr $2196(pc)
  001e78:  80 07                  or.b d7, d0
  001e7a:  1b 40 ba 95            move.b d0, -$456b(a5)
  001e7e:  4e ba fd a0            jsr $1c20(pc)
  001e82:  54 8f                  addq.l #$2, a7
  001e84:  2e 1f                  move.l (a7)+, d7
  001e86:  4e 75                  rts 
  001e88:  4e ba fd 6e            jsr $1bf8(pc)
  001e8c:  4a 00                  tst.b d0
  001e8e:  67 20                  beq.b $1eb0
  001e90:  53 2d ba 95            subq.b #$1, -$456b(a5)
  001e94:  4a 2d ba 95            tst.b -$456b(a5)
  001e98:  66 12                  bne.b $1eac
  001e9a:  3f 3c 00 3f            move.w #$3f, -(a7)
  001e9e:  4e ad 00 72            jsr $72(a5)
  001ea2:  06 00 00 28            addi.b #$28, d0
  001ea6:  1b 40 ba 95            move.b d0, -$456b(a5)
  001eaa:  54 8f                  addq.l #$2, a7
  001eac:  4e ba fd 72            jsr $1c20(pc)
  001eb0:  4e 75                  rts 
  001eb2:  48 e7 07 00            movem.l d5-d7, -(a7)
  001eb6:  4a 2d bc e8            tst.b -$4318(a5)
  001eba:  6d 70                  blt.b $1f2c
  001ebc:  7a 00                  moveq #$0, d5
  001ebe:  1a 2d ba 95            move.b -$456b(a5), d5
  001ec2:  3e 05                  move.w d5, d7
  001ec4:  02 47 00 80            andi.w #$80, d7
  001ec8:  7c 7f                  moveq #$7f, d6
  001eca:  cc 45                  and.w d5, d6
  001ecc:  52 46                  addq.w #$1, d6
  001ece:  0c 46 00 0f            cmpi.w #$f, d6
  001ed2:  6f 02                  ble.b $1ed6
  001ed4:  7c 01                  moveq #$1, d6
  001ed6:  10 07                  move.b d7, d0
  001ed8:  80 06                  or.b d6, d0
  001eda:  1b 40 ba 95            move.b d0, -$456b(a5)
  001ede:  0c 46 00 02            cmpi.w #$2, d6
  001ee2:  66 0a                  bne.b $1eee
  001ee4:  3f 3c 00 2f            move.w #$2f, -(a7)
  001ee8:  4e ad 03 92            jsr $392(a5)
  001eec:  54 8f                  addq.l #$2, a7
  001eee:  70 00                  moveq #$0, d0
  001ef0:  10 2d bc e7            move.b -$4319(a5), d0
  001ef4:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  001ef8:  66 1e                  bne.b $1f18
  001efa:  70 00                  moveq #$0, d0
  001efc:  10 2d bc e6            move.b -$431a(a5), d0
  001f00:  81 fc 00 0a            divs.w #$a, d0
  001f04:  12 2d b9 6f            move.b -$4691(a5), d1
  001f08:  48 81                  ext.w d1
  001f0a:  b2 40                  cmp.w d0, d1
  001f0c:  66 0a                  bne.b $1f18
  001f0e:  4a 2d b9 77            tst.b -$4689(a5)
  001f12:  6d 18                  blt.b $1f2c
  001f14:  4a 47                  tst.w d7
  001f16:  66 14                  bne.b $1f2c
  001f18:  70 00                  moveq #$0, d0
  001f1a:  10 2d ba 95            move.b -$456b(a5), d0
  001f1e:  02 40 00 7f            andi.w #$7f, d0
  001f22:  5d 40                  subq.w #$6, d0
  001f24:  6d 06                  blt.b $1f2c
  001f26:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  001f2c:  70 00                  moveq #$0, d0
  001f2e:  10 2d ba 95            move.b -$456b(a5), d0
  001f32:  02 40 00 7f            andi.w #$7f, d0
  001f36:  5d 40                  subq.w #$6, d0
  001f38:  6c 04                  bge.b $1f3e
  001f3a:  4e ba fc f2            jsr $1c2e(pc)
  001f3e:  4c df 00 e0            movem.l (a7)+, d5-d7
  001f42:  4e 75                  rts 
  001f44:  4a 2d bc e8            tst.b -$4318(a5)
  001f48:  6d 48                  blt.b $1f92
  001f4a:  0c 2d 00 ff ba 95      cmpi.b #$ff, -$456b(a5)
  001f50:  67 44                  beq.b $1f96
  001f52:  4a 2d ba 95            tst.b -$456b(a5)
  001f56:  6a 14                  bpl.b $1f6c
  001f58:  53 2d ba 95            subq.b #$1, -$456b(a5)
  001f5c:  70 7f                  moveq #$7f, d0
  001f5e:  c0 2d ba 95            and.b -$456b(a5), d0
  001f62:  66 2e                  bne.b $1f92
  001f64:  1b 7c 00 06 ba 95      move.b #$6, -$456b(a5)
  001f6a:  60 26                  bra.b $1f92
  001f6c:  52 2d ba 95            addq.b #$1, -$456b(a5)
  001f70:  0c 2d 00 05 ba 95      cmpi.b #$5, -$456b(a5)
  001f76:  66 08                  bne.b $1f80
  001f78:  1b 7c 00 8f ba 95      move.b #$8f, -$456b(a5)
  001f7e:  60 12                  bra.b $1f92
  001f80:  0c 2d 00 09 ba 95      cmpi.b #$9, -$456b(a5)
  001f86:  66 0a                  bne.b $1f92
  001f88:  42 2d ba 95            clr.b -$456b(a5)
  001f8c:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  001f92:  4e ba fc ae            jsr $1c42(pc)
  001f96:  4e 75                  rts 
  001f98:  48 e7 03 00            movem.l d6-d7, -(a7)
  001f9c:  1e 2d bc e8            move.b -$4318(a5), d7
  001fa0:  4a 07                  tst.b d7
  001fa2:  6d 00 00 ec            blt.w $2090
  001fa6:  0c 07 00 03            cmpi.b #$3, d7
  001faa:  6d 46                  blt.b $1ff2
  001fac:  0c 07 00 08            cmpi.b #$8, d7
  001fb0:  6c 06                  bge.b $1fb8
  001fb2:  52 07                  addq.b #$1, d7
  001fb4:  1b 47 bc e8            move.b d7, -$4318(a5)
  001fb8:  10 07                  move.b d7, d0
  001fba:  48 80                  ext.w d0
  001fbc:  20 4d                  movea.l a5, a0
  001fbe:  d0 c0                  adda.w d0, a0
  001fc0:  1c 28 aa 24            move.b -$55dc(a0), d6
  001fc4:  70 00                  moveq #$0, d0
  001fc6:  10 2d ba 95            move.b -$456b(a5), d0
  001fca:  12 06                  move.b d6, d1
  001fcc:  48 81                  ext.w d1
  001fce:  b2 40                  cmp.w d0, d1
  001fd0:  6e 08                  bgt.b $1fda
  001fd2:  9d 2d ba 95            sub.b d6, -$456b(a5)
  001fd6:  60 00 00 b8            bra.w $2090
  001fda:  42 2d ba 95            clr.b -$456b(a5)
  001fde:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  001fe4:  3f 3c 00 06            move.w #$6, -(a7)
  001fe8:  4e ad 03 92            jsr $392(a5)
  001fec:  54 8f                  addq.l #$2, a7
  001fee:  60 00 00 a0            bra.w $2090
  001ff2:  0c 2d 00 ff ba 95      cmpi.b #$ff, -$456b(a5)
  001ff8:  66 08                  bne.b $2002
  001ffa:  4e ba 00 9e            jsr $209a(pc)
  001ffe:  60 00 00 90            bra.w $2090
  002002:  10 07                  move.b d7, d0
  002004:  48 80                  ext.w d0
  002006:  20 4d                  movea.l a5, a0
  002008:  d0 c0                  adda.w d0, a0
  00200a:  10 28 aa 32            move.b -$55ce(a0), d0
  00200e:  d1 2d ba 95            add.b d0, -$456b(a5)
  002012:  4a 07                  tst.b d7
  002014:  66 30                  bne.b $2046
  002016:  4a 2d ba 95            tst.b -$456b(a5)
  00201a:  62 06                  bhi.b $2022
  00201c:  4e ba 00 7c            jsr $209a(pc)
  002020:  60 6e                  bra.b $2090
  002022:  0c 2d 00 bc ba 95      cmpi.b #$bc, -$456b(a5)
  002028:  64 66                  bcc.b $2090
  00202a:  70 00                  moveq #$0, d0
  00202c:  10 2d ba 95            move.b -$456b(a5), d0
  002030:  81 fc 00 04            divs.w #$4, d0
  002034:  48 40                  swap d0
  002036:  57 40                  subq.w #$3, d0
  002038:  66 56                  bne.b $2090
  00203a:  3f 3c 00 04            move.w #$4, -(a7)
  00203e:  4e ba 11 78            jsr $31b8(pc)
  002042:  54 8f                  addq.l #$2, a7
  002044:  60 4a                  bra.b $2090
  002046:  0c 2d 00 bc ba 95      cmpi.b #$bc, -$456b(a5)
  00204c:  64 1c                  bcc.b $206a
  00204e:  70 00                  moveq #$0, d0
  002050:  10 2d ba 95            move.b -$456b(a5), d0
  002054:  81 fc 00 08            divs.w #$8, d0
  002058:  48 40                  swap d0
  00205a:  4a 40                  tst.w d0
  00205c:  66 32                  bne.b $2090
  00205e:  3f 3c 00 05            move.w #$5, -(a7)
  002062:  4e ad 03 92            jsr $392(a5)
  002066:  54 8f                  addq.l #$2, a7
  002068:  60 26                  bra.b $2090
  00206a:  0c 07 00 02            cmpi.b #$2, d7
  00206e:  6c 16                  bge.b $2086
  002070:  1b 7c 00 ee ba 95      move.b #$ee, -$456b(a5)
  002076:  42 2d bc e8            clr.b -$4318(a5)
  00207a:  3f 3c 00 07            move.w #$7, -(a7)
  00207e:  4e ad 03 92            jsr $392(a5)
  002082:  54 8f                  addq.l #$2, a7
  002084:  60 0a                  bra.b $2090
  002086:  1b 7c 00 ff ba 95      move.b #$ff, -$456b(a5)
  00208c:  4e ba 00 0c            jsr $209a(pc)
  002090:  4e ba fc 0a            jsr $1c9c(pc)
  002094:  4c df 00 c0            movem.l (a7)+, d6-d7
  002098:  4e 75                  rts 
  00209a:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  0020a0:  3f 3c 00 07            move.w #$7, -(a7)
  0020a4:  4e ba 11 12            jsr $31b8(pc)
  0020a8:  54 8f                  addq.l #$2, a7
  0020aa:  4e 75                  rts 
  0020ac:  2f 07                  move.l d7, -(a7)
  0020ae:  1e 2d bc e8            move.b -$4318(a5), d7
  0020b2:  48 87                  ext.w d7
  0020b4:  4a 47                  tst.w d7
  0020b6:  6d 00 00 d6            blt.w $218e
  0020ba:  0c 47 00 03            cmpi.w #$3, d7
  0020be:  6d 62                  blt.b $2122
  0020c0:  52 2d bc e8            addq.b #$1, -$4318(a5)
  0020c4:  10 2d bc e8            move.b -$4318(a5), d0
  0020c8:  48 80                  ext.w d0
  0020ca:  20 4d                  movea.l a5, a0
  0020cc:  d0 c0                  adda.w d0, a0
  0020ce:  1e 28 aa 2a            move.b -$55d6(a0), d7
  0020d2:  70 00                  moveq #$0, d0
  0020d4:  10 2d ba 95            move.b -$456b(a5), d0
  0020d8:  12 07                  move.b d7, d1
  0020da:  48 81                  ext.w d1
  0020dc:  b2 40                  cmp.w d0, d1
  0020de:  6e 06                  bgt.b $20e6
  0020e0:  9f 2d ba 95            sub.b d7, -$456b(a5)
  0020e4:  60 1a                  bra.b $2100
  0020e6:  42 2d ba 95            clr.b -$456b(a5)
  0020ea:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  0020f0:  3f 3c 00 0e            move.w #$e, -(a7)
  0020f4:  4e ad 03 92            jsr $392(a5)
  0020f8:  3b 7c 00 01 ba 3a      move.w #$1, -$45c6(a5)
  0020fe:  54 8f                  addq.l #$2, a7
  002100:  0c 2d 00 04 bc e8      cmpi.b #$4, -$4318(a5)
  002106:  66 00 00 86            bne.w $218e
  00210a:  1b 7c 00 01 b8 c7      move.b #$1, -$4739(a5)
  002110:  1b 7c 00 6e b9 01      move.b #$6e, -$46ff(a5)
  002116:  3f 3c 00 0f            move.w #$f, -(a7)
  00211a:  4e ad 03 92            jsr $392(a5)
  00211e:  54 8f                  addq.l #$2, a7
  002120:  60 6c                  bra.b $218e
  002122:  4a 2d ba 95            tst.b -$456b(a5)
  002126:  66 14                  bne.b $213c
  002128:  42 2d b8 c7            clr.b -$4739(a5)
  00212c:  1b 7c 00 01 b9 01      move.b #$1, -$46ff(a5)
  002132:  3f 3c 00 0f            move.w #$f, -(a7)
  002136:  4e ad 03 92            jsr $392(a5)
  00213a:  54 8f                  addq.l #$2, a7
  00213c:  52 2d ba 95            addq.b #$1, -$456b(a5)
  002140:  0c 2d 00 2b ba 95      cmpi.b #$2b, -$456b(a5)
  002146:  65 46                  bcs.b $218e
  002148:  4a 6d ba 3c            tst.w -$45c4(a5)
  00214c:  67 08                  beq.b $2156
  00214e:  0c 6d 00 02 ba 3c      cmpi.w #$2, -$45c4(a5)
  002154:  66 38                  bne.b $218e
  002156:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  00215c:  4e ad 00 fa            jsr $fa(a5)
  002160:  3b 7c 00 01 ba 3c      move.w #$1, -$45c4(a5)
  002166:  0c 6d 00 04 a9 0c      cmpi.w #$4, -$56f4(a5)
  00216c:  66 20                  bne.b $218e
  00216e:  2f 3c 00 04 00 00      move.l #$40000, -(a7)
  002174:  3f 3c 00 04            move.w #$4, -(a7)
  002178:  4e ad 02 2a            jsr $22a(a5)
  00217c:  70 00                  moveq #$0, d0
  00217e:  10 2d ba e9            move.b -$4517(a5), d0
  002182:  d0 ad bd 82            add.l -$427e(a5), d0
  002186:  20 40                  movea.l d0, a0
  002188:  10 bc 00 0d            move.b #$d, (a0)
  00218c:  5c 8f                  addq.l #$6, a7
  00218e:  4e ba fa 82            jsr $1c12(pc)
  002192:  2e 1f                  move.l (a7)+, d7
  002194:  4e 75                  rts 
  002196:  4e 56 00 00            link.w a6, #$0
  00219a:  2f 07                  move.l d7, -(a7)
  00219c:  4a 6e 00 08            tst.w $8(a6)
  0021a0:  66 10                  bne.b $21b2
  0021a2:  3f 3c 00 01            move.w #$1, -(a7)
  0021a6:  4e ad 00 72            jsr $72(a5)
  0021aa:  52 40                  addq.w #$1, d0
  0021ac:  3e 00                  move.w d0, d7
  0021ae:  54 8f                  addq.l #$2, a7
  0021b0:  60 06                  bra.b $21b8
  0021b2:  7e 01                  moveq #$1, d7
  0021b4:  de 6e 00 08            add.w $8(a6), d7
  0021b8:  0c 47 00 07            cmpi.w #$7, d7
  0021bc:  6d 02                  blt.b $21c0
  0021be:  7e 00                  moveq #$0, d7
  0021c0:  30 07                  move.w d7, d0
  0021c2:  2e 1f                  move.l (a7)+, d7
  0021c4:  4e 5e                  unlk a6
  0021c6:  4e 75                  rts 
  0021c8:  4e 56 00 00            link.w a6, #$0
  0021cc:  2f 07                  move.l d7, -(a7)
  0021ce:  3f 3c 00 ff            move.w #$ff, -(a7)
  0021d2:  4e ad 00 72            jsr $72(a5)
  0021d6:  3e 00                  move.w d0, d7
  0021d8:  be 6e 00 08            cmp.w $8(a6), d7
  0021dc:  54 8f                  addq.l #$2, a7
  0021de:  67 0e                  beq.b $21ee
  0021e0:  0c 47 00 09            cmpi.w #$9, d7
  0021e4:  6c 04                  bge.b $21ea
  0021e6:  30 07                  move.w d7, d0
  0021e8:  60 10                  bra.b $21fa
  0021ea:  3e 2e 00 08            move.w $8(a6), d7
  0021ee:  52 47                  addq.w #$1, d7
  0021f0:  0c 47 00 09            cmpi.w #$9, d7
  0021f4:  6d 02                  blt.b $21f8
  0021f6:  7e 00                  moveq #$0, d7
  0021f8:  30 07                  move.w d7, d0
  0021fa:  2e 1f                  move.l (a7)+, d7
  0021fc:  4e 5e                  unlk a6
  0021fe:  4e 75                  rts 
  002200:  4e 56 00 00            link.w a6, #$0
  002204:  2f 07                  move.l d7, -(a7)
  002206:  3e 2e 00 08            move.w $8(a6), d7
  00220a:  0c 47 00 1e            cmpi.w #$1e, d7
  00220e:  6c 20                  bge.b $2230
  002210:  4a 47                  tst.w d7
  002212:  6c 12                  bge.b $2226
  002214:  70 01                  moveq #$1, d0
  002216:  d0 47                  add.w d7, d0
  002218:  44 40                  neg.w d0
  00221a:  20 4d                  movea.l a5, a0
  00221c:  d0 c0                  adda.w d0, a0
  00221e:  11 7c 00 01 bc 62      move.b #$1, -$439e(a0)
  002224:  60 0a                  bra.b $2230
  002226:  20 4d                  movea.l a5, a0
  002228:  d0 c7                  adda.w d7, a0
  00222a:  11 7c 00 01 bb cc      move.b #$1, -$4434(a0)
  002230:  2e 1f                  move.l (a7)+, d7
  002232:  4e 5e                  unlk a6
  002234:  4e 75                  rts 
  002236:  4e 56 00 00            link.w a6, #$0
  00223a:  2f 07                  move.l d7, -(a7)
  00223c:  3e 2e 00 08            move.w $8(a6), d7
  002240:  0c 47 00 1e            cmpi.w #$1e, d7
  002244:  6c 20                  bge.b $2266
  002246:  4a 47                  tst.w d7
  002248:  6c 12                  bge.b $225c
  00224a:  70 01                  moveq #$1, d0
  00224c:  d0 47                  add.w d7, d0
  00224e:  44 40                  neg.w d0
  002250:  20 4d                  movea.l a5, a0
  002252:  d0 c0                  adda.w d0, a0
  002254:  11 7c 00 01 bc 62      move.b #$1, -$439e(a0)
  00225a:  60 0a                  bra.b $2266
  00225c:  20 4d                  movea.l a5, a0
  00225e:  d0 c7                  adda.w d7, a0
  002260:  11 7c 00 01 bc 08      move.b #$1, -$43f8(a0)
  002266:  2e 1f                  move.l (a7)+, d7
  002268:  4e 5e                  unlk a6
  00226a:  4e 75                  rts 
  00226c:  4e 56 00 00            link.w a6, #$0
  002270:  2f 07                  move.l d7, -(a7)
  002272:  3e 2e 00 08            move.w $8(a6), d7
  002276:  0c 47 00 1e            cmpi.w #$1e, d7
  00227a:  6c 20                  bge.b $229c
  00227c:  4a 47                  tst.w d7
  00227e:  6c 12                  bge.b $2292
  002280:  70 01                  moveq #$1, d0
  002282:  d0 47                  add.w d7, d0
  002284:  44 40                  neg.w d0
  002286:  20 4d                  movea.l a5, a0
  002288:  d0 c0                  adda.w d0, a0
  00228a:  11 7c 00 01 bc 62      move.b #$1, -$439e(a0)
  002290:  60 0a                  bra.b $229c
  002292:  20 4d                  movea.l a5, a0
  002294:  d0 c7                  adda.w d7, a0
  002296:  11 7c 00 01 bc 26      move.b #$1, -$43da(a0)
  00229c:  2e 1f                  move.l (a7)+, d7
  00229e:  4e 5e                  unlk a6
  0022a0:  4e 75                  rts 
  0022a2:  4e 56 00 00            link.w a6, #$0
  0022a6:  2f 07                  move.l d7, -(a7)
  0022a8:  3e 2e 00 08            move.w $8(a6), d7
  0022ac:  0c 47 00 1e            cmpi.w #$1e, d7
  0022b0:  6c 20                  bge.b $22d2
  0022b2:  4a 47                  tst.w d7
  0022b4:  6c 12                  bge.b $22c8
  0022b6:  70 01                  moveq #$1, d0
  0022b8:  d0 47                  add.w d7, d0
  0022ba:  44 40                  neg.w d0
  0022bc:  20 4d                  movea.l a5, a0
  0022be:  d0 c0                  adda.w d0, a0
  0022c0:  11 7c 00 01 bc 62      move.b #$1, -$439e(a0)
  0022c6:  60 0a                  bra.b $22d2
  0022c8:  20 4d                  movea.l a5, a0
  0022ca:  d0 c7                  adda.w d7, a0
  0022cc:  11 7c 00 01 bb 72      move.b #$1, -$448e(a0)
  0022d2:  2e 1f                  move.l (a7)+, d7
  0022d4:  4e 5e                  unlk a6
  0022d6:  4e 75                  rts 
  0022d8:  4e 56 00 00            link.w a6, #$0
  0022dc:  2f 07                  move.l d7, -(a7)
  0022de:  3e 2e 00 08            move.w $8(a6), d7
  0022e2:  0c 47 00 1e            cmpi.w #$1e, d7
  0022e6:  6c 0e                  bge.b $22f6
  0022e8:  4a 47                  tst.w d7
  0022ea:  6d 0a                  blt.b $22f6
  0022ec:  20 4d                  movea.l a5, a0
  0022ee:  d0 c7                  adda.w d7, a0
  0022f0:  11 7c 00 01 bb ea      move.b #$1, -$4416(a0)
  0022f6:  2e 1f                  move.l (a7)+, d7
  0022f8:  4e 5e                  unlk a6
  0022fa:  4e 75                  rts 
  0022fc:  4e 56 00 00            link.w a6, #$0
  002300:  48 e7 01 08            movem.l d7/a4, -(a7)
  002304:  3e 2e 00 08            move.w $8(a6), d7
  002308:  0c 47 00 1e            cmpi.w #$1e, d7
  00230c:  6c 2c                  bge.b $233a
  00230e:  4a 47                  tst.w d7
  002310:  6d 28                  blt.b $233a
  002312:  49 ed bb 90            lea.l -$4470(a5), a4
  002316:  d8 c7                  adda.w d7, a4
  002318:  4a 14                  tst.b (a4)
  00231a:  67 10                  beq.b $232c
  00231c:  20 4d                  movea.l a5, a0
  00231e:  d0 c7                  adda.w d7, a0
  002320:  10 28 bb ae            move.b -$4452(a0), d0
  002324:  48 80                  ext.w d0
  002326:  b0 6d bd 6c            cmp.w -$4294(a5), d0
  00232a:  6c 0a                  bge.b $2336
  00232c:  20 4d                  movea.l a5, a0
  00232e:  d0 c7                  adda.w d7, a0
  002330:  11 6d bd 6d bb ae      move.b -$4293(a5), -$4452(a0)
  002336:  18 bc 00 01            move.b #$1, (a4)
  00233a:  4c df 10 80            movem.l (a7)+, d7/a4
  00233e:  4e 5e                  unlk a6
  002340:  4e 75                  rts 
  002342:  4e 56 00 00            link.w a6, #$0
  002346:  48 e7 01 08            movem.l d7/a4, -(a7)
  00234a:  3e 2e 00 08            move.w $8(a6), d7
  00234e:  0c 47 00 1e            cmpi.w #$1e, d7
  002352:  6c 48                  bge.b $239c
  002354:  4a 47                  tst.w d7
  002356:  6c 12                  bge.b $236a
  002358:  70 01                  moveq #$1, d0
  00235a:  d0 47                  add.w d7, d0
  00235c:  44 40                  neg.w d0
  00235e:  20 4d                  movea.l a5, a0
  002360:  d0 c0                  adda.w d0, a0
  002362:  11 7c 00 01 bc 62      move.b #$1, -$439e(a0)
  002368:  60 32                  bra.b $239c
  00236a:  49 ed bb 90            lea.l -$4470(a5), a4
  00236e:  d8 c7                  adda.w d7, a4
  002370:  4a 14                  tst.b (a4)
  002372:  67 10                  beq.b $2384
  002374:  20 4d                  movea.l a5, a0
  002376:  d0 c7                  adda.w d7, a0
  002378:  10 28 bb ae            move.b -$4452(a0), d0
  00237c:  48 80                  ext.w d0
  00237e:  b0 6d bd 6c            cmp.w -$4294(a5), d0
  002382:  6c 0a                  bge.b $238e
  002384:  20 4d                  movea.l a5, a0
  002386:  d0 c7                  adda.w d7, a0
  002388:  11 6d bd 6d bb ae      move.b -$4293(a5), -$4452(a0)
  00238e:  18 bc 00 01            move.b #$1, (a4)
  002392:  20 4d                  movea.l a5, a0
  002394:  d0 c7                  adda.w d7, a0
  002396:  11 7c 00 01 bb 72      move.b #$1, -$448e(a0)
  00239c:  4c df 10 80            movem.l (a7)+, d7/a4
  0023a0:  4e 5e                  unlk a6
  0023a2:  4e 75                  rts 
  0023a4:  4e 56 00 00            link.w a6, #$0
  0023a8:  2f 07                  move.l d7, -(a7)
  0023aa:  3e 2e 00 08            move.w $8(a6), d7
  0023ae:  0c 47 00 1e            cmpi.w #$1e, d7
  0023b2:  6c 0e                  bge.b $23c2
  0023b4:  4a 47                  tst.w d7
  0023b6:  6d 0a                  blt.b $23c2
  0023b8:  20 4d                  movea.l a5, a0
  0023ba:  d0 c7                  adda.w d7, a0
  0023bc:  11 7c 00 01 bc 44      move.b #$1, -$43bc(a0)
  0023c2:  2e 1f                  move.l (a7)+, d7
  0023c4:  4e 5e                  unlk a6
  0023c6:  4e 75                  rts 
  0023c8:  4e 56 00 00            link.w a6, #$0
  0023cc:  48 e7 03 00            movem.l d6-d7, -(a7)
  0023d0:  3c 2e 00 08            move.w $8(a6), d6
  0023d4:  3e 2e 00 0a            move.w $a(a6), d7
  0023d8:  3f 3c 00 08            move.w #$8, -(a7)
  0023dc:  4e ad 00 72            jsr $72(a5)
  0023e0:  20 6d bd 86            movea.l -$427a(a5), a0
  0023e4:  11 80 70 00            move.b d0, (a0, d7.w)
  0023e8:  3e bc 00 01            move.w #$1, (a7)
  0023ec:  3f 07                  move.w d7, -(a7)
  0023ee:  3f 06                  move.w d6, -(a7)
  0023f0:  4e ba 02 3e            jsr $2630(pc)
  0023f4:  4c ee 00 c0 ff f8      movem.l -$8(a6), d6-d7
  0023fa:  4e 5e                  unlk a6
  0023fc:  4e 75                  rts 
  0023fe:  4e 56 00 00            link.w a6, #$0
  002402:  48 e7 07 08            movem.l d5-d7/a4, -(a7)
  002406:  3a 2e 00 08            move.w $8(a6), d5
  00240a:  3e 2e 00 0a            move.w $a(a6), d7
  00240e:  28 6d bd 86            movea.l -$427a(a5), a4
  002412:  d8 c7                  adda.w d7, a4
  002414:  1c 14                  move.b (a4), d6
  002416:  02 06 00 e0            andi.b #$e0, d6
  00241a:  18 86                  move.b d6, (a4)
  00241c:  3f 3c 00 01            move.w #$1, -(a7)
  002420:  3f 07                  move.w d7, -(a7)
  002422:  3f 05                  move.w d5, -(a7)
  002424:  4e ba 02 0a            jsr $2630(pc)
  002428:  4c ee 10 e0 ff f0      movem.l -$10(a6), d5-d7/a4
  00242e:  4e 5e                  unlk a6
  002430:  4e 75                  rts 
  002432:  4e 56 00 00            link.w a6, #$0
  002436:  48 e7 03 00            movem.l d6-d7, -(a7)
  00243a:  3c 2e 00 08            move.w $8(a6), d6
  00243e:  3e 2e 00 0a            move.w $a(a6), d7
  002442:  3f 3c 00 ff            move.w #$ff, -(a7)
  002446:  4e ad 00 72            jsr $72(a5)
  00244a:  02 00 00 1f            andi.b #$1f, d0
  00244e:  20 6d bd 86            movea.l -$427a(a5), a0
  002452:  11 80 70 00            move.b d0, (a0, d7.w)
  002456:  3e bc 00 01            move.w #$1, (a7)
  00245a:  3f 07                  move.w d7, -(a7)
  00245c:  3f 06                  move.w d6, -(a7)
  00245e:  4e ba 01 d0            jsr $2630(pc)
  002462:  4c ee 00 c0 ff f8      movem.l -$8(a6), d6-d7
  002468:  4e 5e                  unlk a6
  00246a:  4e 75                  rts 
  00246c:  4e 56 00 00            link.w a6, #$0
  002470:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  002474:  38 2e 00 08            move.w $8(a6), d4
  002478:  3e 2e 00 0a            move.w $a(a6), d7
  00247c:  3a 2e 00 0c            move.w $c(a6), d5
  002480:  28 6d bd 86            movea.l -$427a(a5), a4
  002484:  d8 c7                  adda.w d7, a4
  002486:  7c 00                  moveq #$0, d6
  002488:  1c 14                  move.b (a4), d6
  00248a:  4a 46                  tst.w d6
  00248c:  67 06                  beq.b $2494
  00248e:  0c 46 00 06            cmpi.w #$6, d6
  002492:  6d 0e                  blt.b $24a2
  002494:  18 85                  move.b d5, (a4)
  002496:  3f 3c 00 01            move.w #$1, -(a7)
  00249a:  3f 07                  move.w d7, -(a7)
  00249c:  3f 04                  move.w d4, -(a7)
  00249e:  4e ba 01 90            jsr $2630(pc)
  0024a2:  4c ee 10 f0 ff ec      movem.l -$14(a6), d4-d7/a4
  0024a8:  4e 5e                  unlk a6
  0024aa:  4e 75                  rts 
  0024ac:  4e 56 00 00            link.w a6, #$0
  0024b0:  48 e7 07 08            movem.l d5-d7/a4, -(a7)
  0024b4:  3a 2e 00 08            move.w $8(a6), d5
  0024b8:  3e 2e 00 0a            move.w $a(a6), d7
  0024bc:  28 6d bd 86            movea.l -$427a(a5), a4
  0024c0:  d8 c7                  adda.w d7, a4
  0024c2:  1c 14                  move.b (a4), d6
  0024c4:  4a 06                  tst.b d6
  0024c6:  63 06                  bls.b $24ce
  0024c8:  0c 06 00 80            cmpi.b #$80, d6
  0024cc:  65 26                  bcs.b $24f4
  0024ce:  4a 06                  tst.b d6
  0024d0:  66 18                  bne.b $24ea
  0024d2:  3f 3c 00 01            move.w #$1, -(a7)
  0024d6:  3f 07                  move.w d7, -(a7)
  0024d8:  3f 05                  move.w d5, -(a7)
  0024da:  4e ba 01 54            jsr $2630(pc)
  0024de:  3e bc 00 31            move.w #$31, (a7)
  0024e2:  4e ad 03 92            jsr $392(a5)
  0024e6:  5c 8f                  addq.l #$6, a7
  0024e8:  60 0a                  bra.b $24f4
  0024ea:  0c 06 00 ff            cmpi.b #$ff, d6
  0024ee:  67 04                  beq.b $24f4
  0024f0:  18 bc 00 8f            move.b #$8f, (a4)
  0024f4:  4c df 10 e0            movem.l (a7)+, d5-d7/a4
  0024f8:  4e 5e                  unlk a6
  0024fa:  4e 75                  rts 
  0024fc:  4e 56 00 00            link.w a6, #$0
  002500:  48 e7 07 08            movem.l d5-d7/a4, -(a7)
  002504:  3e 2e 00 08            move.w $8(a6), d7
  002508:  3c 2e 00 0a            move.w $a(a6), d6
  00250c:  3a 2e 00 0c            move.w $c(a6), d5
  002510:  28 6d bd 86            movea.l -$427a(a5), a4
  002514:  d8 c6                  adda.w d6, a4
  002516:  1c 14                  move.b (a4), d6
  002518:  0c 45 00 0f            cmpi.w #$f, d5
  00251c:  66 20                  bne.b $253e
  00251e:  0c 06 00 ff            cmpi.b #$ff, d6
  002522:  67 36                  beq.b $255a
  002524:  0c 06 00 bc            cmpi.b #$bc, d6
  002528:  65 06                  bcs.b $2530
  00252a:  18 bc 00 ee            move.b #$ee, (a4)
  00252e:  60 2a                  bra.b $255a
  002530:  70 03                  moveq #$3, d0
  002532:  d0 06                  add.b d6, d0
  002534:  02 00 00 fc            andi.b #$fc, d0
  002538:  18 80                  move.b d0, (a4)
  00253a:  70 01                  moveq #$1, d0
  00253c:  60 1e                  bra.b $255c
  00253e:  0c 45 00 0e            cmpi.w #$e, d5
  002542:  66 0e                  bne.b $2552
  002544:  0c 06 00 bc            cmpi.b #$bc, d6
  002548:  65 04                  bcs.b $254e
  00254a:  18 bc 00 ff            move.b #$ff, (a4)
  00254e:  70 02                  moveq #$2, d0
  002550:  60 0a                  bra.b $255c
  002552:  4a 06                  tst.b d6
  002554:  67 04                  beq.b $255a
  002556:  70 03                  moveq #$3, d0
  002558:  60 02                  bra.b $255c
  00255a:  70 ff                  moveq #$ff, d0
  00255c:  4c df 10 e0            movem.l (a7)+, d5-d7/a4
  002560:  4e 5e                  unlk a6
  002562:  4e 75                  rts 
  002564:  4e 56 00 00            link.w a6, #$0
  002568:  48 e7 1f 00            movem.l d3-d7, -(a7)
  00256c:  3c 2e 00 08            move.w $8(a6), d6
  002570:  36 2e 00 0a            move.w $a(a6), d3
  002574:  38 2e 00 0c            move.w $c(a6), d4
  002578:  3a 2e 00 0e            move.w $e(a6), d5
  00257c:  7e ff                  moveq #$ff, d7
  00257e:  0c 46 00 04            cmpi.w #$4, d6
  002582:  66 10                  bne.b $2594
  002584:  3f 05                  move.w d5, -(a7)
  002586:  3f 04                  move.w d4, -(a7)
  002588:  3f 03                  move.w d3, -(a7)
  00258a:  4e ba ff 70            jsr $24fc(pc)
  00258e:  3e 00                  move.w d0, d7
  002590:  5c 8f                  addq.l #$6, a7
  002592:  60 16                  bra.b $25aa
  002594:  0c 46 00 10            cmpi.w #$10, d6
  002598:  66 10                  bne.b $25aa
  00259a:  20 6d bd 86            movea.l -$427a(a5), a0
  00259e:  4a 30 40 00            tst.b (a0, d4.w)
  0025a2:  67 04                  beq.b $25a8
  0025a4:  7e ff                  moveq #$ff, d7
  0025a6:  60 02                  bra.b $25aa
  0025a8:  7e 01                  moveq #$1, d7
  0025aa:  30 07                  move.w d7, d0
  0025ac:  4c df 00 f8            movem.l (a7)+, d3-d7
  0025b0:  4e 5e                  unlk a6
  0025b2:  4e 75                  rts 
  0025b4:  4e 56 00 00            link.w a6, #$0
  0025b8:  48 e7 1f 00            movem.l d3-d7, -(a7)
  0025bc:  36 2e 00 08            move.w $8(a6), d3
  0025c0:  60 5a                  bra.b $261c
  0025c2:  3f 03                  move.w d3, -(a7)
  0025c4:  4e ba 01 ac            jsr $2772(pc)
  0025c8:  3e 00                  move.w d0, d7
  0025ca:  3e 87                  move.w d7, (a7)
  0025cc:  4e ba 2b 9c            jsr $516a(pc)
  0025d0:  3e 83                  move.w d3, (a7)
  0025d2:  4e ba 01 70            jsr $2744(pc)
  0025d6:  3c 00                  move.w d0, d6
  0025d8:  20 6d bd 82            movea.l -$427e(a5), a0
  0025dc:  7a 1f                  moveq #$1f, d5
  0025de:  ca 30 60 00            and.b (a0, d6.w), d5
  0025e2:  3e ae 00 0a            move.w $a(a6), (a7)
  0025e6:  3f 06                  move.w d6, -(a7)
  0025e8:  3f 07                  move.w d7, -(a7)
  0025ea:  10 05                  move.b d5, d0
  0025ec:  48 80                  ext.w d0
  0025ee:  3f 00                  move.w d0, -(a7)
  0025f0:  4e ba ff 72            jsr $2564(pc)
  0025f4:  18 00                  move.b d0, d4
  0025f6:  4a 04                  tst.b d4
  0025f8:  50 8f                  addq.l #$8, a7
  0025fa:  6d 10                  blt.b $260c
  0025fc:  10 04                  move.b d4, d0
  0025fe:  48 80                  ext.w d0
  002600:  3f 00                  move.w d0, -(a7)
  002602:  3f 06                  move.w d6, -(a7)
  002604:  3f 07                  move.w d7, -(a7)
  002606:  4e ba 00 28            jsr $2630(pc)
  00260a:  5c 8f                  addq.l #$6, a7
  00260c:  30 03                  move.w d3, d0
  00260e:  52 43                  addq.w #$1, d3
  002610:  3f 00                  move.w d0, -(a7)
  002612:  4e ba 01 48            jsr $275c(pc)
  002616:  4a 00                  tst.b d0
  002618:  54 8f                  addq.l #$2, a7
  00261a:  67 0c                  beq.b $2628
  00261c:  20 4d                  movea.l a5, a0
  00261e:  d0 c3                  adda.w d3, a0
  002620:  0c 28 00 ff ee be      cmpi.b #$ff, -$1142(a0)
  002626:  66 9a                  bne.b $25c2
  002628:  4c df 00 f8            movem.l (a7)+, d3-d7
  00262c:  4e 5e                  unlk a6
  00262e:  4e 75                  rts 
  002630:  4e 56 00 00            link.w a6, #$0
  002634:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  002638:  3e 2d bc 6c            move.w -$4394(a5), d7
  00263c:  0c 47 00 1e            cmpi.w #$1e, d7
  002640:  6c 54                  bge.b $2696
  002642:  1b 6e 00 09 bc e7      move.b $9(a6), -$4319(a5)
  002648:  1b 6e 00 0b bc e6      move.b $b(a6), -$431a(a5)
  00264e:  1b 6e 00 0d bc e8      move.b $d(a6), -$4318(a5)
  002654:  7c 00                  moveq #$0, d6
  002656:  49 ed bc 6e            lea.l -$4392(a5), a4
  00265a:  60 22                  bra.b $267e
  00265c:  70 00                  moveq #$0, d0
  00265e:  10 2c 00 01            move.b $1(a4), d0
  002662:  b0 6e 00 08            cmp.w $8(a6), d0
  002666:  66 12                  bne.b $267a
  002668:  70 00                  moveq #$0, d0
  00266a:  10 14                  move.b (a4), d0
  00266c:  b0 6e 00 0a            cmp.w $a(a6), d0
  002670:  66 08                  bne.b $267a
  002672:  19 6e 00 0d 00 02      move.b $d(a6), $2(a4)
  002678:  60 1c                  bra.b $2696
  00267a:  52 46                  addq.w #$1, d6
  00267c:  58 8c                  addq.l #$4, a4
  00267e:  be 46                  cmp.w d6, d7
  002680:  6e da                  bgt.b $265c
  002682:  20 4d                  movea.l a5, a0
  002684:  20 07                  move.l d7, d0
  002686:  48 c0                  ext.l d0
  002688:  e5 88                  lsl.l #$2, d0
  00268a:  d1 c0                  adda.l d0, a0
  00268c:  21 6d bc e6 bc 6e      move.l -$431a(a5), -$4392(a0)
  002692:  52 6d bc 6c            addq.w #$1, -$4394(a5)
  002696:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  00269a:  4e 5e                  unlk a6
  00269c:  4e 75                  rts 
  00269e:  2f 07                  move.l d7, -(a7)
  0026a0:  7e 00                  moveq #$0, d7
  0026a2:  60 42                  bra.b $26e6
  0026a4:  20 4d                  movea.l a5, a0
  0026a6:  d0 c7                  adda.w d7, a0
  0026a8:  42 28 bc 44            clr.b -$43bc(a0)
  0026ac:  20 4d                  movea.l a5, a0
  0026ae:  d0 c7                  adda.w d7, a0
  0026b0:  42 28 bc 26            clr.b -$43da(a0)
  0026b4:  20 4d                  movea.l a5, a0
  0026b6:  d0 c7                  adda.w d7, a0
  0026b8:  42 28 bc 08            clr.b -$43f8(a0)
  0026bc:  20 4d                  movea.l a5, a0
  0026be:  d0 c7                  adda.w d7, a0
  0026c0:  42 28 bb ea            clr.b -$4416(a0)
  0026c4:  20 4d                  movea.l a5, a0
  0026c6:  d0 c7                  adda.w d7, a0
  0026c8:  42 28 bb cc            clr.b -$4434(a0)
  0026cc:  20 4d                  movea.l a5, a0
  0026ce:  d0 c7                  adda.w d7, a0
  0026d0:  42 28 bb ae            clr.b -$4452(a0)
  0026d4:  20 4d                  movea.l a5, a0
  0026d6:  d0 c7                  adda.w d7, a0
  0026d8:  42 28 bb 90            clr.b -$4470(a0)
  0026dc:  20 4d                  movea.l a5, a0
  0026de:  d0 c7                  adda.w d7, a0
  0026e0:  42 28 bb 72            clr.b -$448e(a0)
  0026e4:  52 47                  addq.w #$1, d7
  0026e6:  0c 47 00 1e            cmpi.w #$1e, d7
  0026ea:  6d b8                  blt.b $26a4
  0026ec:  7e 00                  moveq #$0, d7
  0026ee:  60 0a                  bra.b $26fa
  0026f0:  20 4d                  movea.l a5, a0
  0026f2:  d0 c7                  adda.w d7, a0
  0026f4:  42 28 bc 62            clr.b -$439e(a0)
  0026f8:  52 47                  addq.w #$1, d7
  0026fa:  0c 47 00 0a            cmpi.w #$a, d7
  0026fe:  6d f0                  blt.b $26f0
  002700:  2e 1f                  move.l (a7)+, d7
  002702:  4e 75                  rts 
  002704:  4e 56 00 00            link.w a6, #$0
  002708:  20 4d                  movea.l a5, a0
  00270a:  d0 ee 00 08            adda.w $8(a6), a0
  00270e:  70 00                  moveq #$0, d0
  002710:  10 28 ef be            move.b -$1042(a0), d0
  002714:  02 40 00 1f            andi.w #$1f, d0
  002718:  4e 5e                  unlk a6
  00271a:  4e 75                  rts 
  00271c:  4e 56 00 00            link.w a6, #$0
  002720:  48 e7 01 08            movem.l d7/a4, -(a7)
  002724:  49 ed ef be            lea.l -$1042(a5), a4
  002728:  d8 ee 00 08            adda.w $8(a6), a4
  00272c:  1e 14                  move.b (a4), d7
  00272e:  02 07 00 e0            andi.b #$e0, d7
  002732:  70 1f                  moveq #$1f, d0
  002734:  c0 2e 00 0b            and.b $b(a6), d0
  002738:  8e 00                  or.b d0, d7
  00273a:  18 87                  move.b d7, (a4)
  00273c:  4c df 10 80            movem.l (a7)+, d7/a4
  002740:  4e 5e                  unlk a6
  002742:  4e 75                  rts 
  002744:  4e 56 00 00            link.w a6, #$0
  002748:  20 4d                  movea.l a5, a0
  00274a:  d0 ee 00 08            adda.w $8(a6), a0
  00274e:  70 00                  moveq #$0, d0
  002750:  10 28 ee be            move.b -$1142(a0), d0
  002754:  02 40 00 1f            andi.w #$1f, d0
  002758:  4e 5e                  unlk a6
  00275a:  4e 75                  rts 
  00275c:  4e 56 00 00            link.w a6, #$0
  002760:  20 4d                  movea.l a5, a0
  002762:  d0 ee 00 08            adda.w $8(a6), a0
  002766:  4a 28 ee be            tst.b -$1142(a0)
  00276a:  5a c0                  spl.b d0
  00276c:  44 00                  neg.b d0
  00276e:  4e 5e                  unlk a6
  002770:  4e 75                  rts 
  002772:  4e 56 00 00            link.w a6, #$0
  002776:  2f 07                  move.l d7, -(a7)
  002778:  20 4d                  movea.l a5, a0
  00277a:  d0 ee 00 08            adda.w $8(a6), a0
  00277e:  7e 00                  moveq #$0, d7
  002780:  1e 28 ee be            move.b -$1142(a0), d7
  002784:  02 47 00 60            andi.w #$60, d7
  002788:  ea 47                  asr.w #$5, d7
  00278a:  20 4d                  movea.l a5, a0
  00278c:  d0 ee 00 08            adda.w $8(a6), a0
  002790:  70 00                  moveq #$0, d0
  002792:  10 28 ef be            move.b -$1042(a0), d0
  002796:  02 40 00 e0            andi.w #$e0, d0
  00279a:  e6 40                  asr.w #$3, d0
  00279c:  de 40                  add.w d0, d7
  00279e:  30 07                  move.w d7, d0
  0027a0:  2e 1f                  move.l (a7)+, d7
  0027a2:  4e 5e                  unlk a6
  0027a4:  4e 75                  rts 
  0027a6:  4e 56 ff fe            link.w a6, #$fffe
  0027aa:  2f 07                  move.l d7, -(a7)
  0027ac:  70 00                  moveq #$0, d0
  0027ae:  10 2d ba e9            move.b -$4517(a5), d0
  0027b2:  3f 00                  move.w d0, -(a7)
  0027b4:  4e ba 04 0e            jsr $2bc4(pc)
  0027b8:  4a 6e 00 0a            tst.w $a(a6)
  0027bc:  54 8f                  addq.l #$2, a7
  0027be:  66 0a                  bne.b $27ca
  0027c0:  70 00                  moveq #$0, d0
  0027c2:  10 2d ba 94            move.b -$456c(a5), d0
  0027c6:  3d 40 00 0a            move.w d0, $a(a6)
  0027ca:  70 00                  moveq #$0, d0
  0027cc:  10 2d ba 95            move.b -$456b(a5), d0
  0027d0:  3f 00                  move.w d0, -(a7)
  0027d2:  4e ba ff 30            jsr $2704(pc)
  0027d6:  1e 00                  move.b d0, d7
  0027d8:  0c 07 00 1f            cmpi.b #$1f, d7
  0027dc:  54 8f                  addq.l #$2, a7
  0027de:  67 58                  beq.b $2838
  0027e0:  3f 3c 00 05            move.w #$5, -(a7)
  0027e4:  70 00                  moveq #$0, d0
  0027e6:  10 2d ba 95            move.b -$456b(a5), d0
  0027ea:  3f 00                  move.w d0, -(a7)
  0027ec:  4e ba ff 2e            jsr $271c(pc)
  0027f0:  0c 07 00 02            cmpi.b #$2, d7
  0027f4:  58 8f                  addq.l #$4, a7
  0027f6:  6c 30                  bge.b $2828
  0027f8:  3f 3c 00 01            move.w #$1, -(a7)
  0027fc:  70 00                  moveq #$0, d0
  0027fe:  10 2d ba e9            move.b -$4517(a5), d0
  002802:  3f 00                  move.w d0, -(a7)
  002804:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  002808:  4e ba fe 26            jsr $2630(pc)
  00280c:  4e ba f4 52            jsr $1c60(pc)
  002810:  3b 7c 00 01 ba 56      move.w #$1, -$45aa(a5)
  002816:  4a 6e 00 08            tst.w $8(a6)
  00281a:  5c 8f                  addq.l #$6, a7
  00281c:  67 0a                  beq.b $2828
  00281e:  3f 3c 00 03            move.w #$3, -(a7)
  002822:  4e ad 03 92            jsr $392(a5)
  002826:  54 8f                  addq.l #$2, a7
  002828:  3f 2e 00 0a            move.w $a(a6), -(a7)
  00282c:  70 00                  moveq #$0, d0
  00282e:  10 2d ba 95            move.b -$456b(a5), d0
  002832:  3f 00                  move.w d0, -(a7)
  002834:  4e ba fd 7e            jsr $25b4(pc)
  002838:  2e 2e ff fa            move.l -$6(a6), d7
  00283c:  4e 5e                  unlk a6
  00283e:  4e 75                  rts 
  002840:  70 00                  moveq #$0, d0
  002842:  10 2d ba e9            move.b -$4517(a5), d0
  002846:  3f 00                  move.w d0, -(a7)
  002848:  4e ba 03 7a            jsr $2bc4(pc)
  00284c:  0c 2d 00 0f ba 94      cmpi.b #$f, -$456c(a5)
  002852:  54 8f                  addq.l #$2, a7
  002854:  66 1e                  bne.b $2874
  002856:  70 00                  moveq #$0, d0
  002858:  10 2d ba e9            move.b -$4517(a5), d0
  00285c:  d0 ad bd 82            add.l -$427e(a5), d0
  002860:  20 40                  movea.l d0, a0
  002862:  10 bc 00 01            move.b #$1, (a0)
  002866:  2f 3c 00 01 00 0e      move.l #$1000e, -(a7)
  00286c:  4e ba ff 38            jsr $27a6(pc)
  002870:  58 8f                  addq.l #$4, a7
  002872:  60 32                  bra.b $28a6
  002874:  0c 2d 00 06 ba 94      cmpi.b #$6, -$456c(a5)
  00287a:  67 08                  beq.b $2884
  00287c:  0c 2d 00 05 ba 94      cmpi.b #$5, -$456c(a5)
  002882:  66 22                  bne.b $28a6
  002884:  70 00                  moveq #$0, d0
  002886:  10 2d ba e9            move.b -$4517(a5), d0
  00288a:  d0 ad bd 82            add.l -$427e(a5), d0
  00288e:  20 40                  movea.l d0, a0
  002890:  10 bc 00 05            move.b #$5, (a0)
  002894:  70 00                  moveq #$0, d0
  002896:  10 2d ba 94            move.b -$456c(a5), d0
  00289a:  3f 00                  move.w d0, -(a7)
  00289c:  3f 3c 00 01            move.w #$1, -(a7)
  0028a0:  4e ba ff 04            jsr $27a6(pc)
  0028a4:  58 8f                  addq.l #$4, a7
  0028a6:  4e 75                  rts 
  0028a8:  2f 07                  move.l d7, -(a7)
  0028aa:  4a 2d bc e8            tst.b -$4318(a5)
  0028ae:  6d 32                  blt.b $28e2
  0028b0:  70 00                  moveq #$0, d0
  0028b2:  10 2d ba 95            move.b -$456b(a5), d0
  0028b6:  3f 00                  move.w d0, -(a7)
  0028b8:  4e ba fe 4a            jsr $2704(pc)
  0028bc:  3e 00                  move.w d0, d7
  0028be:  70 ff                  moveq #$ff, d0
  0028c0:  d0 47                  add.w d7, d0
  0028c2:  3e 80                  move.w d0, (a7)
  0028c4:  70 00                  moveq #$0, d0
  0028c6:  10 2d ba 95            move.b -$456b(a5), d0
  0028ca:  3f 00                  move.w d0, -(a7)
  0028cc:  4e ba fe 4e            jsr $271c(pc)
  0028d0:  0c 47 00 02            cmpi.w #$2, d7
  0028d4:  58 8f                  addq.l #$4, a7
  0028d6:  6c 0a                  bge.b $28e2
  0028d8:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  0028de:  4e ba f3 80            jsr $1c60(pc)
  0028e2:  2e 1f                  move.l (a7)+, d7
  0028e4:  4e 75                  rts 
  0028e6:  4e 56 00 00            link.w a6, #$0
  0028ea:  30 6e 00 0a            movea.w $a(a6), a0
  0028ee:  d1 ed bd 86            adda.l -$427a(a5), a0
  0028f2:  10 bc 00 2b            move.b #$2b, (a0)
  0028f6:  3f 3c 00 03            move.w #$3, -(a7)
  0028fa:  3f 2e 00 0a            move.w $a(a6), -(a7)
  0028fe:  3f 2e 00 08            move.w $8(a6), -(a7)
  002902:  4e ba fd 2c            jsr $2630(pc)
  002906:  4e 5e                  unlk a6
  002908:  4e 75                  rts 
  00290a:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  002910:  4e ba f3 6c            jsr $1c7e(pc)
  002914:  4e 75                  rts 
  002916:  48 e7 07 00            movem.l d5-d7, -(a7)
  00291a:  4a 2d bc e8            tst.b -$4318(a5)
  00291e:  6d 00 00 b8            blt.w $29d8
  002922:  52 2d ba 95            addq.b #$1, -$456b(a5)
  002926:  7e 00                  moveq #$0, d7
  002928:  1e 2d ba 95            move.b -$456b(a5), d7
  00292c:  4a 07                  tst.b d7
  00292e:  6a 34                  bpl.b $2964
  002930:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  002936:  67 00 00 a4            beq.w $29dc
  00293a:  70 7f                  moveq #$7f, d0
  00293c:  c0 47                  and.w d7, d0
  00293e:  59 40                  subq.w #$4, d0
  002940:  6d 18                  blt.b $295a
  002942:  42 2d ba 95            clr.b -$456b(a5)
  002946:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  00294c:  3f 3c 00 01            move.w #$1, -(a7)
  002950:  4e ba 00 90            jsr $29e2(pc)
  002954:  54 8f                  addq.l #$2, a7
  002956:  60 00 00 80            bra.w $29d8
  00295a:  42 67                  clr.w -(a7)
  00295c:  4e ba 00 84            jsr $29e2(pc)
  002960:  54 8f                  addq.l #$2, a7
  002962:  60 74                  bra.b $29d8
  002964:  0c 2d 00 0b ba 95      cmpi.b #$b, -$456b(a5)
  00296a:  65 64                  bcs.b $29d0
  00296c:  7e 00                  moveq #$0, d7
  00296e:  1e 2d bc e7            move.b -$4319(a5), d7
  002972:  7c 00                  moveq #$0, d6
  002974:  1c 2d bc e6            move.b -$431a(a5), d6
  002978:  20 6d bd 82            movea.l -$427e(a5), a0
  00297c:  42 30 60 00            clr.b (a0, d6.w)
  002980:  20 6d bd 86            movea.l -$427a(a5), a0
  002984:  10 2d b9 44            move.b -$46bc(a5), d0
  002988:  11 80 60 00            move.b d0, (a0, d6.w)
  00298c:  1b 40 ba 95            move.b d0, -$456b(a5)
  002990:  1b 7c 00 ff bc e8      move.b #$ff, -$4318(a5)
  002996:  22 06                  move.l d6, d1
  002998:  48 c1                  ext.l d1
  00299a:  83 fc 00 0a            divs.w #$a, d1
  00299e:  48 41                  swap d1
  0029a0:  e5 09                  lsl.b #$2, d1
  0029a2:  1b 41 bd 66            move.b d1, -$429a(a5)
  0029a6:  2a 06                  move.l d6, d5
  0029a8:  48 c5                  ext.l d5
  0029aa:  8b fc 00 0a            divs.w #$a, d5
  0029ae:  20 4d                  movea.l a5, a0
  0029b0:  d0 c5                  adda.w d5, a0
  0029b2:  d0 c5                  adda.w d5, a0
  0029b4:  1b 68 b6 59 bd 67      move.b -$49a7(a0), -$4299(a5)
  0029ba:  1b 47 bd 68            move.b d7, -$4298(a5)
  0029be:  42 2d bd 69            clr.b -$4297(a5)
  0029c2:  42 2d bd 6a            clr.b -$4296(a5)
  0029c6:  1b 45 bd 6b            move.b d5, -$4295(a5)
  0029ca:  4e ba 01 d0            jsr $2b9c(pc)
  0029ce:  60 08                  bra.b $29d8
  0029d0:  42 67                  clr.w -(a7)
  0029d2:  4e ba 00 0e            jsr $29e2(pc)
  0029d6:  54 8f                  addq.l #$2, a7
  0029d8:  4e ba f2 a4            jsr $1c7e(pc)
  0029dc:  4c df 00 e0            movem.l (a7)+, d5-d7
  0029e0:  4e 75                  rts 
  0029e2:  4e 56 00 00            link.w a6, #$0
  0029e6:  2f 07                  move.l d7, -(a7)
  0029e8:  4a 6e 00 08            tst.w $8(a6)
  0029ec:  66 14                  bne.b $2a02
  0029ee:  70 00                  moveq #$0, d0
  0029f0:  10 2d ba 95            move.b -$456b(a5), d0
  0029f4:  02 40 00 7f            andi.w #$7f, d0
  0029f8:  20 4d                  movea.l a5, a0
  0029fa:  d0 c0                  adda.w d0, a0
  0029fc:  4a 28 b5 98            tst.b -$4a68(a0)
  002a00:  67 26                  beq.b $2a28
  002a02:  3f 3c 00 02            move.w #$2, -(a7)
  002a06:  4e ad 00 72            jsr $72(a5)
  002a0a:  7e 14                  moveq #$14, d7
  002a0c:  de 40                  add.w d0, d7
  002a0e:  be 6d ba 60            cmp.w -$45a0(a5), d7
  002a12:  54 8f                  addq.l #$2, a7
  002a14:  67 ec                  beq.b $2a02
  002a16:  4a 2d 96 fa            tst.b -$6906(a5)
  002a1a:  67 04                  beq.b $2a20
  002a1c:  3b 47 ba 60            move.w d7, -$45a0(a5)
  002a20:  3f 07                  move.w d7, -(a7)
  002a22:  4e ad 03 92            jsr $392(a5)
  002a26:  54 8f                  addq.l #$2, a7
  002a28:  2e 1f                  move.l (a7)+, d7
  002a2a:  4e 5e                  unlk a6
  002a2c:  4e 75                  rts 
  002a2e:  4e 56 00 00            link.w a6, #$0
  002a32:  2f 0c                  move.l a4, -(a7)
  002a34:  70 00                  moveq #$0, d0
  002a36:  10 2d ba e9            move.b -$4517(a5), d0
  002a3a:  d0 ad bd 82            add.l -$427e(a5), d0
  002a3e:  20 40                  movea.l d0, a0
  002a40:  08 10 00 05            btst.b #$5, (a0)
  002a44:  66 2c                  bne.b $2a72
  002a46:  70 00                  moveq #$0, d0
  002a48:  10 2d ba e9            move.b -$4517(a5), d0
  002a4c:  d0 ad bd 86            add.l -$427a(a5), d0
  002a50:  28 40                  movea.l d0, a4
  002a52:  4a 14                  tst.b (a4)
  002a54:  6e 1c                  bgt.b $2a72
  002a56:  18 ae 00 08            move.b $8(a6), (a4)
  002a5a:  42 67                  clr.w -(a7)
  002a5c:  70 00                  moveq #$0, d0
  002a5e:  10 2d ba e9            move.b -$4517(a5), d0
  002a62:  3f 00                  move.w d0, -(a7)
  002a64:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  002a68:  4e ba fb c6            jsr $2630(pc)
  002a6c:  4e ba f2 10            jsr $1c7e(pc)
  002a70:  5c 8f                  addq.l #$6, a7
  002a72:  28 5f                  movea.l (a7)+, a4
  002a74:  4e 5e                  unlk a6
  002a76:  4e 75                  rts 
  002a78:  48 e7 1f 00            movem.l d3-d7, -(a7)
  002a7c:  7c 0f                  moveq #$f, d6
  002a7e:  0c 2d 00 03 b9 4b      cmpi.b #$3, -$46b5(a5)
  002a84:  64 76                  bcc.b $2afc
  002a86:  10 2d b9 4f            move.b -$46b1(a5), d0
  002a8a:  48 80                  ext.w d0
  002a8c:  3f 00                  move.w d0, -(a7)
  002a8e:  4e ba 26 da            jsr $516a(pc)
  002a92:  10 2d b9 4b            move.b -$46b5(a5), d0
  002a96:  48 80                  ext.w d0
  002a98:  20 4d                  movea.l a5, a0
  002a9a:  d0 c0                  adda.w d0, a0
  002a9c:  d0 c0                  adda.w d0, a0
  002a9e:  3a 28 b6 46            move.w -$49ba(a0), d5
  002aa2:  78 00                  moveq #$0, d4
  002aa4:  54 8f                  addq.l #$2, a7
  002aa6:  60 4e                  bra.b $2af6
  002aa8:  3f 05                  move.w d5, -(a7)
  002aaa:  4e ba 01 18            jsr $2bc4(pc)
  002aae:  0c 2d 00 12 ba 94      cmpi.b #$12, -$456c(a5)
  002ab4:  54 8f                  addq.l #$2, a7
  002ab6:  66 3a                  bne.b $2af2
  002ab8:  76 7f                  moveq #$7f, d3
  002aba:  c6 2d ba 95            and.b -$456b(a5), d3
  002abe:  4a 03                  tst.b d3
  002ac0:  67 06                  beq.b $2ac8
  002ac2:  0c 03 00 06            cmpi.b #$6, d3
  002ac6:  65 2a                  bcs.b $2af2
  002ac8:  70 00                  moveq #$0, d0
  002aca:  10 2d ba 95            move.b -$456b(a5), d0
  002ace:  02 40 00 80            andi.w #$80, d0
  002ad2:  72 00                  moveq #$0, d1
  002ad4:  12 06                  move.b d6, d1
  002ad6:  80 41                  or.w d1, d0
  002ad8:  3f 00                  move.w d0, -(a7)
  002ada:  3f 05                  move.w d5, -(a7)
  002adc:  10 2d b9 4f            move.b -$46b1(a5), d0
  002ae0:  48 80                  ext.w d0
  002ae2:  3f 00                  move.w d0, -(a7)
  002ae4:  4e ba f9 86            jsr $246c(pc)
  002ae8:  1e 86                  move.b d6, (a7)
  002aea:  4e ba 00 16            jsr $2b02(pc)
  002aee:  1c 00                  move.b d0, d6
  002af0:  5c 8f                  addq.l #$6, a7
  002af2:  52 45                  addq.w #$1, d5
  002af4:  52 44                  addq.w #$1, d4
  002af6:  0c 44 00 0a            cmpi.w #$a, d4
  002afa:  6d ac                  blt.b $2aa8
  002afc:  4c df 00 f8            movem.l (a7)+, d3-d7
  002b00:  4e 75                  rts 
  002b02:  4e 56 00 00            link.w a6, #$0
  002b06:  2f 07                  move.l d7, -(a7)
  002b08:  1e 2e 00 08            move.b $8(a6), d7
  002b0c:  70 fd                  moveq #$fd, d0
  002b0e:  d0 07                  add.b d7, d0
  002b10:  1e 00                  move.b d0, d7
  002b12:  0c 07 00 06            cmpi.b #$6, d7
  002b16:  64 04                  bcc.b $2b1c
  002b18:  06 07 00 0a            addi.b #$a, d7
  002b1c:  70 00                  moveq #$0, d0
  002b1e:  10 07                  move.b d7, d0
  002b20:  2e 1f                  move.l (a7)+, d7
  002b22:  4e 5e                  unlk a6
  002b24:  4e 75                  rts 
  002b26:  2f 0c                  move.l a4, -(a7)
  002b28:  70 00                  moveq #$0, d0
  002b2a:  10 2d ba e9            move.b -$4517(a5), d0
  002b2e:  d0 ad bd 86            add.l -$427a(a5), d0
  002b32:  28 40                  movea.l d0, a4
  002b34:  4a 14                  tst.b (a4)
  002b36:  66 22                  bne.b $2b5a
  002b38:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  002b3e:  67 1a                  beq.b $2b5a
  002b40:  18 bc 00 80            move.b #$80, (a4)
  002b44:  3f 3c 00 01            move.w #$1, -(a7)
  002b48:  70 00                  moveq #$0, d0
  002b4a:  10 2d ba e9            move.b -$4517(a5), d0
  002b4e:  3f 00                  move.w d0, -(a7)
  002b50:  3f 2d ba ea            move.w -$4516(a5), -(a7)
  002b54:  4e ba fa da            jsr $2630(pc)
  002b58:  5c 8f                  addq.l #$6, a7
  002b5a:  28 5f                  movea.l (a7)+, a4
  002b5c:  4e 75                  rts 
  002b5e:  4e 56 00 00            link.w a6, #$0
  002b62:  48 e7 07 00            movem.l d5-d7, -(a7)
  002b66:  3a 2e 00 08            move.w $8(a6), d5
  002b6a:  3c 2e 00 0a            move.w $a(a6), d6
  002b6e:  7e 00                  moveq #$0, d7
  002b70:  60 1c                  bra.b $2b8e
  002b72:  3f 06                  move.w d6, -(a7)
  002b74:  3f 07                  move.w d7, -(a7)
  002b76:  3f 05                  move.w d5, -(a7)
  002b78:  4e ad 02 2a            jsr $22a(a5)
  002b7c:  72 00                  moveq #$0, d1
  002b7e:  12 00                  move.b d0, d1
  002b80:  0c 41 00 0b            cmpi.w #$b, d1
  002b84:  5c 8f                  addq.l #$6, a7
  002b86:  66 04                  bne.b $2b8c
  002b88:  4e ba ff 9c            jsr $2b26(pc)
  002b8c:  52 47                  addq.w #$1, d7
  002b8e:  0c 47 00 0a            cmpi.w #$a, d7
  002b92:  6d de                  blt.b $2b72
  002b94:  4c df 00 e0            movem.l (a7)+, d5-d7
  002b98:  4e 5e                  unlk a6
  002b9a:  4e 75                  rts 
  002b9c:  2f 07                  move.l d7, -(a7)
  002b9e:  3e 2d bc ea            move.w -$4316(a5), d7
  002ba2:  0c 47 00 14            cmpi.w #$14, d7
  002ba6:  6c 18                  bge.b $2bc0
  002ba8:  70 06                  moveq #$6, d0
  002baa:  c1 c7                  muls.w d7, d0
  002bac:  20 4d                  movea.l a5, a0
  002bae:  d1 c0                  adda.l d0, a0
  002bb0:  21 6d bd 66 bc ee      move.l -$429a(a5), -$4312(a0)
  002bb6:  31 6d bd 6a bc f2      move.w -$4296(a5), -$430e(a0)
  002bbc:  52 6d bc ea            addq.w #$1, -$4316(a5)
  002bc0:  2e 1f                  move.l (a7)+, d7
  002bc2:  4e 75                  rts 
  002bc4:  4e 56 00 00            link.w a6, #$0
  002bc8:  2f 07                  move.l d7, -(a7)
  002bca:  3e 2e 00 08            move.w $8(a6), d7
  002bce:  20 6d bd 86            movea.l -$427a(a5), a0
  002bd2:  1b 70 70 00 ba 95      move.b (a0, d7.w), -$456b(a5)
  002bd8:  22 6d bd 82            movea.l -$427e(a5), a1
  002bdc:  70 1f                  moveq #$1f, d0
  002bde:  c0 31 70 00            and.b (a1, d7.w), d0
  002be2:  1b 40 ba 94            move.b d0, -$456c(a5)
  002be6:  2e 1f                  move.l (a7)+, d7
  002be8:  4e 5e                  unlk a6
  002bea:  4e 75                  rts 
  002bec:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  002bf0:  42 6d bc ec            clr.w -$4314(a5)
  002bf4:  49 ed bc ee            lea.l -$4312(a5), a4
  002bf8:  60 22                  bra.b $2c1c
  002bfa:  2b 54 bd 66            move.l (a4), -$429a(a5)
  002bfe:  3b 6c 00 04 bd 6a      move.w $4(a4), -$4296(a5)
  002c04:  4e ba 00 5a            jsr $2c60(pc)
  002c08:  4e ba 04 da            jsr $30e4(pc)
  002c0c:  28 ad bd 66            move.l -$429a(a5), (a4)
  002c10:  39 6d bd 6a 00 04      move.w -$4296(a5), $4(a4)
  002c16:  52 6d bc ec            addq.w #$1, -$4314(a5)
  002c1a:  5c 8c                  addq.l #$6, a4
  002c1c:  30 2d bc ec            move.w -$4314(a5), d0
  002c20:  b0 6d bc ea            cmp.w -$4316(a5), d0
  002c24:  6d d4                  blt.b $2bfa
  002c26:  7e 00                  moveq #$0, d7
  002c28:  7c 00                  moveq #$0, d6
  002c2a:  49 ed bc ee            lea.l -$4312(a5), a4
  002c2e:  60 20                  bra.b $2c50
  002c30:  0c 2c 00 ff 00 03      cmpi.b #$ff, $3(a4)
  002c36:  67 14                  beq.b $2c4c
  002c38:  70 06                  moveq #$6, d0
  002c3a:  c1 c7                  muls.w d7, d0
  002c3c:  20 4d                  movea.l a5, a0
  002c3e:  d1 c0                  adda.l d0, a0
  002c40:  21 54 bc ee            move.l (a4), -$4312(a0)
  002c44:  31 6c 00 04 bc f2      move.w $4(a4), -$430e(a0)
  002c4a:  52 47                  addq.w #$1, d7
  002c4c:  52 46                  addq.w #$1, d6
  002c4e:  5c 8c                  addq.l #$6, a4
  002c50:  bc 6d bc ea            cmp.w -$4316(a5), d6
  002c54:  6d da                  blt.b $2c30
  002c56:  3b 47 bc ea            move.w d7, -$4316(a5)
  002c5a:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  002c5e:  4e 75                  rts 
  002c60:  4a 2d bd 6a            tst.b -$4296(a5)
  002c64:  66 04                  bne.b $2c6a
  002c66:  4e ba 00 0e            jsr $2c76(pc)
  002c6a:  4a 2d bd 69            tst.b -$4297(a5)
  002c6e:  6e 04                  bgt.b $2c74
  002c70:  52 2d bd 69            addq.b #$1, -$4297(a5)
  002c74:  4e 75                  rts 
  002c76:  4a 2d bd 69            tst.b -$4297(a5)
  002c7a:  6d 00 00 d4            blt.w $2d50
  002c7e:  0c 2d 00 1d bd 69      cmpi.b #$1d, -$4297(a5)
  002c84:  6c 04                  bge.b $2c8a
  002c86:  56 2d bd 69            addq.b #$3, -$4297(a5)
  002c8a:  10 2d bd 69            move.b -$4297(a5), d0
  002c8e:  d1 2d bd 67            add.b d0, -$4299(a5)
  002c92:  4a 2d bd 68            tst.b -$4298(a5)
  002c96:  66 14                  bne.b $2cac
  002c98:  0c 2d 00 d2 bd 67      cmpi.b #$d2, -$4299(a5)
  002c9e:  65 00 00 b0            bcs.w $2d50
  002ca2:  1b 7c 00 fe bd 69      move.b #$fe, -$4297(a5)
  002ca8:  60 00 00 a6            bra.w $2d50
  002cac:  0c 2d 00 e2 bd 67      cmpi.b #$e2, -$4299(a5)
  002cb2:  64 00 00 9c            bcc.w $2d50
  002cb6:  70 00                  moveq #$0, d0
  002cb8:  10 2d bd 67            move.b -$4299(a5), d0
  002cbc:  72 00                  moveq #$0, d1
  002cbe:  12 2d bd 6b            move.b -$4295(a5), d1
  002cc2:  20 4d                  movea.l a5, a0
  002cc4:  d0 c1                  adda.w d1, a0
  002cc6:  d0 c1                  adda.w d1, a0
  002cc8:  b0 68 b6 4e            cmp.w -$49b2(a0), d0
  002ccc:  6d 00 00 82            blt.w $2d50
  002cd0:  70 00                  moveq #$0, d0
  002cd2:  10 2d bd 6b            move.b -$4295(a5), d0
  002cd6:  3f 00                  move.w d0, -(a7)
  002cd8:  70 00                  moveq #$0, d0
  002cda:  10 2d bd 66            move.b -$429a(a5), d0
  002cde:  e4 40                  asr.w #$2, d0
  002ce0:  3f 00                  move.w d0, -(a7)
  002ce2:  70 00                  moveq #$0, d0
  002ce4:  10 2d bd 68            move.b -$4298(a5), d0
  002ce8:  3f 00                  move.w d0, -(a7)
  002cea:  4e ad 02 2a            jsr $22a(a5)
  002cee:  72 00                  moveq #$0, d1
  002cf0:  12 00                  move.b d0, d1
  002cf2:  3b 41 ba 3e            move.w d1, -$45c2(a5)
  002cf6:  0c 41 00 0b            cmpi.w #$b, d1
  002cfa:  5c 8f                  addq.l #$6, a7
  002cfc:  66 04                  bne.b $2d02
  002cfe:  4e ba 01 5e            jsr $2e5e(pc)
  002d02:  4a 6d ba 3e            tst.w -$45c2(a5)
  002d06:  67 08                  beq.b $2d10
  002d08:  0c 6d 00 0b ba 3e      cmpi.w #$b, -$45c2(a5)
  002d0e:  66 06                  bne.b $2d16
  002d10:  4e ba 01 fa            jsr $2f0c(pc)
  002d14:  60 3a                  bra.b $2d50
  002d16:  3f 3c 00 02            move.w #$2, -(a7)
  002d1a:  4e ad 03 92            jsr $392(a5)
  002d1e:  70 00                  moveq #$0, d0
  002d20:  10 2d bd 6b            move.b -$4295(a5), d0
  002d24:  3e 80                  move.w d0, (a7)
  002d26:  70 00                  moveq #$0, d0
  002d28:  10 2d bd 68            move.b -$4298(a5), d0
  002d2c:  3f 00                  move.w d0, -(a7)
  002d2e:  4e ba fe 2e            jsr $2b5e(pc)
  002d32:  70 00                  moveq #$0, d0
  002d34:  10 2d bd 6b            move.b -$4295(a5), d0
  002d38:  20 4d                  movea.l a5, a0
  002d3a:  d0 c0                  adda.w d0, a0
  002d3c:  d0 c0                  adda.w d0, a0
  002d3e:  1b 68 b6 4f bd 67      move.b -$49b1(a0), -$4299(a5)
  002d44:  1b 7c 00 fe bd 69      move.b #$fe, -$4297(a5)
  002d4a:  4e ba 00 06            jsr $2d52(pc)
  002d4e:  58 8f                  addq.l #$4, a7
  002d50:  4e 75                  rts 
  002d52:  48 e7 03 00            movem.l d6-d7, -(a7)
  002d56:  7e 00                  moveq #$0, d7
  002d58:  70 00                  moveq #$0, d0
  002d5a:  10 2d bd 6b            move.b -$4295(a5), d0
  002d5e:  3f 00                  move.w d0, -(a7)
  002d60:  70 00                  moveq #$0, d0
  002d62:  10 2d bd 66            move.b -$429a(a5), d0
  002d66:  e4 40                  asr.w #$2, d0
  002d68:  3f 00                  move.w d0, -(a7)
  002d6a:  70 00                  moveq #$0, d0
  002d6c:  10 2d bd 68            move.b -$4298(a5), d0
  002d70:  3f 00                  move.w d0, -(a7)
  002d72:  4e ad 02 2a            jsr $22a(a5)
  002d76:  7c 00                  moveq #$0, d6
  002d78:  1c 00                  move.b d0, d6
  002d7a:  30 06                  move.w d6, d0
  002d7c:  0c 40 00 1e            cmpi.w #$1e, d0
  002d80:  5c 8f                  addq.l #$6, a7
  002d82:  62 00 00 96            bhi.w $2e1a
  002d86:  43 fa 00 98            lea.l $2e20(pc), a1
  002d8a:  d0 40                  add.w d0, d0
  002d8c:  d2 f1 00 00            adda.w (a1, d0.w), a1
  002d90:  4e d1                  jmp (a1)
  002d92:  70 00                  moveq #$0, d0
  002d94:  10 2d ba e9            move.b -$4517(a5), d0
  002d98:  d0 ad bd 82            add.l -$427e(a5), d0
  002d9c:  20 40                  movea.l d0, a0
  002d9e:  10 bc 00 0e            move.b #$e, (a0)
  002da2:  7e 0e                  moveq #$e, d7
  002da4:  3f 07                  move.w d7, -(a7)
  002da6:  3f 3c 00 01            move.w #$1, -(a7)
  002daa:  4e ba f9 fa            jsr $27a6(pc)
  002dae:  70 00                  moveq #$0, d0
  002db0:  10 2d bd 6b            move.b -$4295(a5), d0
  002db4:  3e 80                  move.w d0, (a7)
  002db6:  70 00                  moveq #$0, d0
  002db8:  10 2d bd 66            move.b -$429a(a5), d0
  002dbc:  e4 40                  asr.w #$2, d0
  002dbe:  3f 00                  move.w d0, -(a7)
  002dc0:  70 00                  moveq #$0, d0
  002dc2:  10 2d bd 68            move.b -$4298(a5), d0
  002dc6:  3f 00                  move.w d0, -(a7)
  002dc8:  4e ad 02 2a            jsr $22a(a5)
  002dcc:  7c 00                  moveq #$0, d6
  002dce:  1c 00                  move.b d0, d6
  002dd0:  50 8f                  addq.l #$8, a7
  002dd2:  0c 46 00 13            cmpi.w #$13, d6
  002dd6:  67 06                  beq.b $2dde
  002dd8:  0c 46 00 1e            cmpi.w #$1e, d6
  002ddc:  66 12                  bne.b $2df0
  002dde:  70 00                  moveq #$0, d0
  002de0:  10 2d ba e9            move.b -$4517(a5), d0
  002de4:  d0 ad bd 82            add.l -$427e(a5), d0
  002de8:  20 40                  movea.l d0, a0
  002dea:  10 bc 00 1e            move.b #$1e, (a0)
  002dee:  60 10                  bra.b $2e00
  002df0:  70 00                  moveq #$0, d0
  002df2:  10 2d ba e9            move.b -$4517(a5), d0
  002df6:  d0 ad bd 82            add.l -$427e(a5), d0
  002dfa:  20 40                  movea.l d0, a0
  002dfc:  10 bc 00 0e            move.b #$e, (a0)
  002e00:  4e ba 00 c2            jsr $2ec4(pc)
  002e04:  4a 6d ba ec            tst.w -$4514(a5)
  002e08:  67 10                  beq.b $2e1a
  002e0a:  70 00                  moveq #$0, d0
  002e0c:  10 2d ba e9            move.b -$4517(a5), d0
  002e10:  53 40                  subq.w #$1, d0
  002e12:  3f 00                  move.w d0, -(a7)
  002e14:  4e ba f4 8c            jsr $22a2(pc)
  002e18:  54 8f                  addq.l #$2, a7
  002e1a:  4c df 00 c0            movem.l (a7)+, d6-d7
  002e1e:  4e 75                  rts 
  002e20:  ff fa                  dc.w $fffa
  002e22:  ff b2                  dc.w $ffb2
  002e24:  ff b2                  dc.w $ffb2
  002e26:  ff fa                  dc.w $fffa
  002e28:  ff fa                  dc.w $fffa
  002e2a:  ff fa                  dc.w $fffa
  002e2c:  ff 84                  dc.w $ff84
  002e2e:  ff fa                  dc.w $fffa
  002e30:  ff fa                  dc.w $fffa
  002e32:  ff fa                  dc.w $fffa
  002e34:  ff b2                  dc.w $ffb2
  002e36:  ff fa                  dc.w $fffa
  002e38:  ff fa                  dc.w $fffa
  002e3a:  ff fa                  dc.w $fffa
  002e3c:  ff fa                  dc.w $fffa
  002e3e:  ff 72                  dc.w $ff72
  002e40:  ff fa                  dc.w $fffa
  002e42:  ff fa                  dc.w $fffa
  002e44:  ff fa                  dc.w $fffa
  002e46:  ff b2                  dc.w $ffb2
  002e48:  ff fa                  dc.w $fffa
  002e4a:  ff fa                  dc.w $fffa
  002e4c:  ff fa                  dc.w $fffa
  002e4e:  ff fa                  dc.w $fffa
  002e50:  ff fa                  dc.w $fffa
  002e52:  ff fa                  dc.w $fffa
  002e54:  ff fa                  dc.w $fffa
  002e56:  ff fa                  dc.w $fffa
  002e58:  ff fa                  dc.w $fffa
  002e5a:  ff fa                  dc.w $fffa
  002e5c:  ff b2                  dc.w $ffb2
  002e5e:  2f 07                  move.l d7, -(a7)
  002e60:  7e 00                  moveq #$0, d7
  002e62:  1e 2d ba e9            move.b -$4517(a5), d7
  002e66:  20 6d bd 82            movea.l -$427e(a5), a0
  002e6a:  42 30 78 00            clr.b (a0, d7.l)
  002e6e:  20 6d bd 86            movea.l -$427a(a5), a0
  002e72:  11 ad b9 44 78 00      move.b -$46bc(a5), (a0, d7.l)
  002e78:  10 2d bd 69            move.b -$4297(a5), d0
  002e7c:  48 80                  ext.w d0
  002e7e:  e2 40                  asr.w #$1, d0
  002e80:  1b 40 bd 69            move.b d0, -$4297(a5)
  002e84:  70 06                  moveq #$6, d0
  002e86:  c1 ed bc ec            muls.w -$4314(a5), d0
  002e8a:  20 4d                  movea.l a5, a0
  002e8c:  d1 c0                  adda.l d0, a0
  002e8e:  21 6d bd 66 bc ee      move.l -$429a(a5), -$4312(a0)
  002e94:  31 6d bd 6a bc f2      move.w -$4296(a5), -$430e(a0)
  002e9a:  5c 2d bd 67            addq.b #$6, -$4299(a5)
  002e9e:  4e ba 00 6c            jsr $2f0c(pc)
  002ea2:  4e ba fc f8            jsr $2b9c(pc)
  002ea6:  70 06                  moveq #$6, d0
  002ea8:  c1 ed bc ec            muls.w -$4314(a5), d0
  002eac:  20 4d                  movea.l a5, a0
  002eae:  d1 c0                  adda.l d0, a0
  002eb0:  2b 68 bc ee bd 66      move.l -$4312(a0), -$429a(a5)
  002eb6:  3b 68 bc f2 bd 6a      move.w -$430e(a0), -$4296(a5)
  002ebc:  4e ba 00 06            jsr $2ec4(pc)
  002ec0:  2e 1f                  move.l (a7)+, d7
  002ec2:  4e 75                  rts 
  002ec4:  70 00                  moveq #$0, d0
  002ec6:  10 2d bd 68            move.b -$4298(a5), d0
  002eca:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  002ece:  66 3a                  bne.b $2f0a
  002ed0:  3b 7c 00 20 bd 6c      move.w #$20, -$4294(a5)
  002ed6:  70 00                  moveq #$0, d0
  002ed8:  10 2d ba e9            move.b -$4517(a5), d0
  002edc:  3f 00                  move.w d0, -(a7)
  002ede:  4e ba f4 62            jsr $2342(pc)
  002ee2:  70 00                  moveq #$0, d0
  002ee4:  10 2d ba e9            move.b -$4517(a5), d0
  002ee8:  52 40                  addq.w #$1, d0
  002eea:  48 c0                  ext.l d0
  002eec:  81 fc 00 0a            divs.w #$a, d0
  002ef0:  48 40                  swap d0
  002ef2:  0c 40 00 0a            cmpi.w #$a, d0
  002ef6:  54 8f                  addq.l #$2, a7
  002ef8:  6c 10                  bge.b $2f0a
  002efa:  70 00                  moveq #$0, d0
  002efc:  10 2d ba e9            move.b -$4517(a5), d0
  002f00:  52 40                  addq.w #$1, d0
  002f02:  3f 00                  move.w d0, -(a7)
  002f04:  4e ba f4 3c            jsr $2342(pc)
  002f08:  54 8f                  addq.l #$2, a7
  002f0a:  4e 75                  rts 
  002f0c:  52 2d bd 6b            addq.b #$1, -$4295(a5)
  002f10:  0c 2d 00 03 bd 6b      cmpi.b #$3, -$4295(a5)
  002f16:  65 1e                  bcs.b $2f36
  002f18:  04 2d 00 c0 bd 67      subi.b #$c0, -$4299(a5)
  002f1e:  42 2d bd 6b            clr.b -$4295(a5)
  002f22:  70 00                  moveq #$0, d0
  002f24:  10 2d bd 68            move.b -$4298(a5), d0
  002f28:  20 4d                  movea.l a5, a0
  002f2a:  48 c0                  ext.l d0
  002f2c:  e5 88                  lsl.l #$2, d0
  002f2e:  d1 c0                  adda.l d0, a0
  002f30:  1b 68 f0 bd bd 68      move.b -$f43(a0), -$4298(a5)
  002f36:  4e 75                  rts 
  002f38:  48 e7 01 08            movem.l d7/a4, -(a7)
  002f3c:  7e 00                  moveq #$0, d7
  002f3e:  49 ed bc ee            lea.l -$4312(a5), a4
  002f42:  60 12                  bra.b $2f56
  002f44:  2b 54 bd 66            move.l (a4), -$429a(a5)
  002f48:  3b 6c 00 04 bd 6a      move.w $4(a4), -$4296(a5)
  002f4e:  4e ba 00 12            jsr $2f62(pc)
  002f52:  52 47                  addq.w #$1, d7
  002f54:  5c 8c                  addq.l #$6, a4
  002f56:  be 6d bc ea            cmp.w -$4316(a5), d7
  002f5a:  6d e8                  blt.b $2f44
  002f5c:  4c df 10 80            movem.l (a7)+, d7/a4
  002f60:  4e 75                  rts 
  002f62:  48 e7 1f 00            movem.l d3-d7, -(a7)
  002f66:  7e 00                  moveq #$0, d7
  002f68:  1e 2d bd 67            move.b -$4299(a5), d7
  002f6c:  3c 07                  move.w d7, d6
  002f6e:  7a 00                  moveq #$0, d5
  002f70:  1a 2d bd 68            move.b -$4298(a5), d5
  002f74:  ba 6d ba 6a            cmp.w -$4596(a5), d5
  002f78:  66 0c                  bne.b $2f86
  002f7a:  0c 2d 00 d2 bd 67      cmpi.b #$d2, -$4299(a5)
  002f80:  64 00 00 a2            bcc.w $3024
  002f84:  60 38                  bra.b $2fbe
  002f86:  ba 6d ba 72            cmp.w -$458e(a5), d5
  002f8a:  66 1e                  bne.b $2faa
  002f8c:  0c 46 00 12            cmpi.w #$12, d6
  002f90:  6c 00 00 92            bge.w $3024
  002f94:  0c 46 ff ee            cmpi.w #$ffee, d6
  002f98:  6f 00 00 8a            ble.w $3024
  002f9c:  06 2d 00 c0 bd 67      addi.b #$c0, -$4299(a5)
  002fa2:  7c 00                  moveq #$0, d6
  002fa4:  1c 2d bd 67            move.b -$4299(a5), d6
  002fa8:  60 14                  bra.b $2fbe
  002faa:  ba 6d ba 70            cmp.w -$4590(a5), d5
  002fae:  66 74                  bne.b $3024
  002fb0:  0c 2d 00 ae bd 67      cmpi.b #$ae, -$4299(a5)
  002fb6:  65 6c                  bcs.b $3024
  002fb8:  3c 07                  move.w d7, d6
  002fba:  06 46 ff 43            addi.w #$ff43, d6
  002fbe:  7e 00                  moveq #$0, d7
  002fc0:  1e 2d bd 66            move.b -$429a(a5), d7
  002fc4:  e4 47                  asr.w #$2, d7
  002fc6:  3f 06                  move.w d6, -(a7)
  002fc8:  4e ad 02 82            jsr $282(a5)
  002fcc:  3a 00                  move.w d0, d5
  002fce:  3e 85                  move.w d5, (a7)
  002fd0:  3f 07                  move.w d7, -(a7)
  002fd2:  4e ad 02 3a            jsr $23a(a5)
  002fd6:  1b 40 ba f0            move.b d0, -$4510(a5)
  002fda:  52 47                  addq.w #$1, d7
  002fdc:  3e 85                  move.w d5, (a7)
  002fde:  3f 07                  move.w d7, -(a7)
  002fe0:  4e ad 02 32            jsr $232(a5)
  002fe4:  38 00                  move.w d0, d4
  002fe6:  3e 84                  move.w d4, (a7)
  002fe8:  4e ba f2 4c            jsr $2236(pc)
  002fec:  3e 84                  move.w d4, (a7)
  002fee:  4e ba f2 e8            jsr $22d8(pc)
  002ff2:  70 ee                  moveq #$ee, d0
  002ff4:  d0 46                  add.w d6, d0
  002ff6:  3e 80                  move.w d0, (a7)
  002ff8:  4e ad 02 82            jsr $282(a5)
  002ffc:  36 00                  move.w d0, d3
  002ffe:  ba 43                  cmp.w d3, d5
  003000:  5c 8f                  addq.l #$6, a7
  003002:  67 18                  beq.b $301c
  003004:  3f 03                  move.w d3, -(a7)
  003006:  3f 07                  move.w d7, -(a7)
  003008:  4e ad 02 32            jsr $232(a5)
  00300c:  38 00                  move.w d0, d4
  00300e:  3e 84                  move.w d4, (a7)
  003010:  4e ba f2 24            jsr $2236(pc)
  003014:  3e 84                  move.w d4, (a7)
  003016:  4e ba f2 c0            jsr $22d8(pc)
  00301a:  58 8f                  addq.l #$4, a7
  00301c:  3f 06                  move.w d6, -(a7)
  00301e:  4e ba 00 0a            jsr $302a(pc)
  003022:  54 8f                  addq.l #$2, a7
  003024:  4c df 00 f8            movem.l (a7)+, d3-d7
  003028:  4e 75                  rts 
  00302a:  4e 56 00 00            link.w a6, #$0
  00302e:  48 e7 01 08            movem.l d7/a4, -(a7)
  003032:  3e 2d bd a4            move.w -$425c(a5), d7
  003036:  0c 47 00 32            cmpi.w #$32, d7
  00303a:  6c 68                  bge.b $30a4
  00303c:  70 14                  moveq #$14, d0
  00303e:  c1 c7                  muls.w d7, d0
  003040:  49 ed e2 c2            lea.l -$1d3e(a5), a4
  003044:  d0 8c                  add.l a4, d0
  003046:  28 40                  movea.l d0, a4
  003048:  38 bc 00 06            move.w #$6, (a4)
  00304c:  39 7c 00 0a 00 02      move.w #$a, $2(a4)
  003052:  19 6d bd 66 00 04      move.b -$429a(a5), $4(a4)
  003058:  42 2c 00 05            clr.b $5(a4)
  00305c:  39 6e 00 08 00 06      move.w $8(a6), $6(a4)
  003062:  42 2c 00 08            clr.b $8(a4)
  003066:  19 7c 00 ff 00 09      move.b #$ff, $9(a4)
  00306c:  70 80                  moveq #$80, d0
  00306e:  80 2d bd 6a            or.b -$4296(a5), d0
  003072:  19 40 00 0a            move.b d0, $a(a4)
  003076:  19 6d ba f0 00 0b      move.b -$4510(a5), $b(a4)
  00307c:  39 6d a5 cc 00 0c      move.w -$5a34(a5), $c(a4)
  003082:  39 6d a5 ce 00 0e      move.w -$5a32(a5), $e(a4)
  003088:  39 6d a5 d0 00 10      move.w -$5a30(a5), $10(a4)
  00308e:  39 6d a5 d2 00 12      move.w -$5a2e(a5), $12(a4)
  003094:  10 2d ba f0            move.b -$4510(a5), d0
  003098:  48 80                  ext.w d0
  00309a:  3f 00                  move.w d0, -(a7)
  00309c:  4e ba f3 06            jsr $23a4(pc)
  0030a0:  52 6d bd a4            addq.w #$1, -$425c(a5)
  0030a4:  4c ee 10 80 ff f8      movem.l -$8(a6), d7/a4
  0030aa:  4e 5e                  unlk a6
  0030ac:  4e 75                  rts 
  0030ae:  2f 07                  move.l d7, -(a7)
  0030b0:  70 00                  moveq #$0, d0
  0030b2:  10 2d ba e9            move.b -$4517(a5), d0
  0030b6:  d0 ad bd 86            add.l -$427a(a5), d0
  0030ba:  20 40                  movea.l d0, a0
  0030bc:  1e 10                  move.b (a0), d7
  0030be:  4a 07                  tst.b d7
  0030c0:  67 06                  beq.b $30c8
  0030c2:  0c 07 00 ff            cmpi.b #$ff, d7
  0030c6:  66 04                  bne.b $30cc
  0030c8:  70 00                  moveq #$0, d0
  0030ca:  60 14                  bra.b $30e0
  0030cc:  4a 07                  tst.b d7
  0030ce:  6c 04                  bge.b $30d4
  0030d0:  70 01                  moveq #$1, d0
  0030d2:  60 0c                  bra.b $30e0
  0030d4:  0c 07 00 05            cmpi.b #$5, d7
  0030d8:  6c 04                  bge.b $30de
  0030da:  70 02                  moveq #$2, d0
  0030dc:  60 02                  bra.b $30e0
  0030de:  70 00                  moveq #$0, d0
  0030e0:  2e 1f                  move.l (a7)+, d7
  0030e2:  4e 75                  rts 
  0030e4:  4e ad 02 8a            jsr $28a(a5)
  0030e8:  70 00                  moveq #$0, d0
  0030ea:  10 2d bd 68            move.b -$4298(a5), d0
  0030ee:  12 2d b9 4f            move.b -$46b1(a5), d1
  0030f2:  48 81                  ext.w d1
  0030f4:  b2 40                  cmp.w d0, d1
  0030f6:  66 38                  bne.b $3130
  0030f8:  70 00                  moveq #$0, d0
  0030fa:  10 2d bd 66            move.b -$429a(a5), d0
  0030fe:  e4 40                  asr.w #$2, d0
  003100:  12 2d b9 4a            move.b -$46b6(a5), d1
  003104:  48 81                  ext.w d1
  003106:  b2 40                  cmp.w d0, d1
  003108:  66 26                  bne.b $3130
  00310a:  10 2d bd 67            move.b -$4299(a5), d0
  00310e:  b0 2d b9 48            cmp.b -$46b8(a5), d0
  003112:  64 1c                  bcc.b $3130
  003114:  70 00                  moveq #$0, d0
  003116:  10 2d bd 67            move.b -$4299(a5), d0
  00311a:  72 00                  moveq #$0, d1
  00311c:  12 2d b9 48            move.b -$46b8(a5), d1
  003120:  06 41 ff e2            addi.w #$ffe2, d1
  003124:  b2 40                  cmp.w d0, d1
  003126:  6c 08                  bge.b $3130
  003128:  4e ba 00 08            jsr $3132(pc)
  00312c:  4e ad 02 92            jsr $292(a5)
  003130:  4e 75                  rts 
  003132:  48 e7 03 00            movem.l d6-d7, -(a7)
  003136:  7e 00                  moveq #$0, d7
  003138:  1e 2d b9 46            move.b -$46ba(a5), d7
  00313c:  1c 2d b9 4c            move.b -$46b4(a5), d6
  003140:  48 86                  ext.w d6
  003142:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  003148:  67 0c                  beq.b $3156
  00314a:  0c 47 00 05            cmpi.w #$5, d7
  00314e:  6d 06                  blt.b $3156
  003150:  0c 47 00 0f            cmpi.w #$f, d7
  003154:  6d 5c                  blt.b $31b2
  003156:  0c 46 00 02            cmpi.w #$2, d6
  00315a:  6d 06                  blt.b $3162
  00315c:  0c 46 00 07            cmpi.w #$7, d6
  003160:  66 50                  bne.b $31b2
  003162:  10 2d b9 4b            move.b -$46b5(a5), d0
  003166:  48 80                  ext.w d0
  003168:  20 4d                  movea.l a5, a0
  00316a:  d0 c0                  adda.w d0, a0
  00316c:  d0 c0                  adda.w d0, a0
  00316e:  1b 68 b6 71 b9 48      move.b -$498f(a0), -$46b8(a5)
  003174:  3f 3c 00 01            move.w #$1, -(a7)
  003178:  4e ad 02 b2            jsr $2b2(a5)
  00317c:  4a 40                  tst.w d0
  00317e:  54 8f                  addq.l #$2, a7
  003180:  67 20                  beq.b $31a2
  003182:  3f 3c 00 16            move.w #$16, -(a7)
  003186:  4e ba ce 7c            jsr $4(pc)
  00318a:  0c 47 00 b1            cmpi.w #$b1, d7
  00318e:  54 8f                  addq.l #$2, a7
  003190:  66 20                  bne.b $31b2
  003192:  3f 3c ff f4            move.w #$fff4, -(a7)
  003196:  4e ad 02 62            jsr $262(a5)
  00319a:  1b 40 b9 47            move.b d0, -$46b9(a5)
  00319e:  54 8f                  addq.l #$2, a7
  0031a0:  60 10                  bra.b $31b2
  0031a2:  0c 47 00 6d            cmpi.w #$6d, d7
  0031a6:  67 0a                  beq.b $31b2
  0031a8:  3f 3c 00 34            move.w #$34, -(a7)
  0031ac:  4e ba ce 56            jsr $4(pc)
  0031b0:  54 8f                  addq.l #$2, a7
  0031b2:  4c df 00 c0            movem.l (a7)+, d6-d7
  0031b6:  4e 75                  rts 
  0031b8:  4e 56 00 00            link.w a6, #$0
  0031bc:  48 e7 07 00            movem.l d5-d7, -(a7)
  0031c0:  7e 00                  moveq #$0, d7
  0031c2:  1e 2d bc e6            move.b -$431a(a5), d7
  0031c6:  7c 00                  moveq #$0, d6
  0031c8:  1c 2d bc e7            move.b -$4319(a5), d6
  0031cc:  7a 00                  moveq #$0, d5
  0031ce:  0c 6d 00 03 a9 0c      cmpi.w #$3, -$56f4(a5)
  0031d4:  66 0a                  bne.b $31e0
  0031d6:  0c 46 00 02            cmpi.w #$2, d6
  0031da:  66 04                  bne.b $31e0
  0031dc:  7a 01                  moveq #$1, d5
  0031de:  60 32                  bra.b $3212
  0031e0:  bc 6d ba 6c            cmp.w -$4594(a5), d6
  0031e4:  66 14                  bne.b $31fa
  0031e6:  20 07                  move.l d7, d0
  0031e8:  48 c0                  ext.l d0
  0031ea:  81 fc 00 0a            divs.w #$a, d0
  0031ee:  48 40                  swap d0
  0031f0:  0c 40 00 09            cmpi.w #$9, d0
  0031f4:  66 1c                  bne.b $3212
  0031f6:  7a 01                  moveq #$1, d5
  0031f8:  60 18                  bra.b $3212
  0031fa:  bc 6d ba 6a            cmp.w -$4596(a5), d6
  0031fe:  66 12                  bne.b $3212
  003200:  20 07                  move.l d7, d0
  003202:  48 c0                  ext.l d0
  003204:  81 fc 00 0a            divs.w #$a, d0
  003208:  48 40                  swap d0
  00320a:  0c 40 00 09            cmpi.w #$9, d0
  00320e:  67 02                  beq.b $3212
  003210:  7a 01                  moveq #$1, d5
  003212:  4a 45                  tst.w d5
  003214:  67 0a                  beq.b $3220
  003216:  3f 2e 00 08            move.w $8(a6), -(a7)
  00321a:  4e ad 03 92            jsr $392(a5)
  00321e:  54 8f                  addq.l #$2, a7
  003220:  4c df 00 e0            movem.l (a7)+, d5-d7
  003224:  4e 5e                  unlk a6
  003226:  4e 75                  rts 
  003228:  42 6d bd a4            clr.w -$425c(a5)
  00322c:  42 6d bd a2            clr.w -$425e(a5)
  003230:  42 6d bd a0            clr.w -$4260(a5)
  003234:  42 6d bd 9e            clr.w -$4262(a5)
  003238:  42 6d bd 9c            clr.w -$4264(a5)
  00323c:  41 ed 04 9a            lea.l $49a(a5), a0
  003240:  2b 48 bd 70            move.l a0, -$4290(a5)
  003244:  4e ba 1e 16            jsr $505c(pc)
  003248:  4e ad 02 a2            jsr $2a2(a5)
  00324c:  4e ba 01 1c            jsr $336a(pc)
  003250:  4e ba f4 4c            jsr $269e(pc)
  003254:  4e 75                  rts 
  003256:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  00325a:  3e 2d ba 6a            move.w -$4596(a5), d7
  00325e:  42 6d ba 7a            clr.w -$4586(a5)
  003262:  42 6d ba 78            clr.w -$4588(a5)
  003266:  42 6d ba 76            clr.w -$458a(a5)
  00326a:  42 6d ba 74            clr.w -$458c(a5)
  00326e:  76 00                  moveq #$0, d3
  003270:  38 03                  move.w d3, d4
  003272:  3a 03                  move.w d3, d5
  003274:  3c 03                  move.w d3, d6
  003276:  4a 47                  tst.w d7
  003278:  67 00 00 da            beq.w $3354
  00327c:  3f 07                  move.w d7, -(a7)
  00327e:  4e ba 1e ea            jsr $516a(pc)
  003282:  20 07                  move.l d7, d0
  003284:  48 c0                  ext.l d0
  003286:  e5 88                  lsl.l #$2, d0
  003288:  49 ed f0 ba            lea.l -$f46(a5), a4
  00328c:  d0 8c                  add.l a4, d0
  00328e:  28 40                  movea.l d0, a4
  003290:  7c 00                  moveq #$0, d6
  003292:  1c 14                  move.b (a4), d6
  003294:  7a 00                  moveq #$0, d5
  003296:  1a 2c 00 01            move.b $1(a4), d5
  00329a:  78 00                  moveq #$0, d4
  00329c:  18 2c 00 02            move.b $2(a4), d4
  0032a0:  76 00                  moveq #$0, d3
  0032a2:  16 2c 00 03            move.b $3(a4), d3
  0032a6:  4a 44                  tst.w d4
  0032a8:  54 8f                  addq.l #$2, a7
  0032aa:  67 22                  beq.b $32ce
  0032ac:  20 04                  move.l d4, d0
  0032ae:  48 c0                  ext.l d0
  0032b0:  e5 88                  lsl.l #$2, d0
  0032b2:  49 ed f0 ba            lea.l -$f46(a5), a4
  0032b6:  d0 8c                  add.l a4, d0
  0032b8:  28 40                  movea.l d0, a4
  0032ba:  70 00                  moveq #$0, d0
  0032bc:  10 14                  move.b (a4), d0
  0032be:  3b 40 ba 74            move.w d0, -$458c(a5)
  0032c2:  72 00                  moveq #$0, d1
  0032c4:  12 2c 00 01            move.b $1(a4), d1
  0032c8:  3b 41 ba 76            move.w d1, -$458a(a5)
  0032cc:  60 30                  bra.b $32fe
  0032ce:  4a 46                  tst.w d6
  0032d0:  67 14                  beq.b $32e6
  0032d2:  20 4d                  movea.l a5, a0
  0032d4:  20 06                  move.l d6, d0
  0032d6:  48 c0                  ext.l d0
  0032d8:  e5 88                  lsl.l #$2, d0
  0032da:  d1 c0                  adda.l d0, a0
  0032dc:  70 00                  moveq #$0, d0
  0032de:  10 28 f0 bc            move.b -$f44(a0), d0
  0032e2:  3b 40 ba 74            move.w d0, -$458c(a5)
  0032e6:  4a 45                  tst.w d5
  0032e8:  67 14                  beq.b $32fe
  0032ea:  20 4d                  movea.l a5, a0
  0032ec:  20 05                  move.l d5, d0
  0032ee:  48 c0                  ext.l d0
  0032f0:  e5 88                  lsl.l #$2, d0
  0032f2:  d1 c0                  adda.l d0, a0
  0032f4:  70 00                  moveq #$0, d0
  0032f6:  10 28 f0 bc            move.b -$f44(a0), d0
  0032fa:  3b 40 ba 76            move.w d0, -$458a(a5)
  0032fe:  4a 43                  tst.w d3
  003300:  67 22                  beq.b $3324
  003302:  20 03                  move.l d3, d0
  003304:  48 c0                  ext.l d0
  003306:  e5 88                  lsl.l #$2, d0
  003308:  49 ed f0 ba            lea.l -$f46(a5), a4
  00330c:  d0 8c                  add.l a4, d0
  00330e:  28 40                  movea.l d0, a4
  003310:  70 00                  moveq #$0, d0
  003312:  10 14                  move.b (a4), d0
  003314:  3b 40 ba 78            move.w d0, -$4588(a5)
  003318:  72 00                  moveq #$0, d1
  00331a:  12 2c 00 01            move.b $1(a4), d1
  00331e:  3b 41 ba 7a            move.w d1, -$4586(a5)
  003322:  60 30                  bra.b $3354
  003324:  4a 46                  tst.w d6
  003326:  67 14                  beq.b $333c
  003328:  20 4d                  movea.l a5, a0
  00332a:  20 06                  move.l d6, d0
  00332c:  48 c0                  ext.l d0
  00332e:  e5 88                  lsl.l #$2, d0
  003330:  d1 c0                  adda.l d0, a0
  003332:  70 00                  moveq #$0, d0
  003334:  10 28 f0 bd            move.b -$f43(a0), d0
  003338:  3b 40 ba 78            move.w d0, -$4588(a5)
  00333c:  4a 45                  tst.w d5
  00333e:  67 14                  beq.b $3354
  003340:  20 4d                  movea.l a5, a0
  003342:  20 05                  move.l d5, d0
  003344:  48 c0                  ext.l d0
  003346:  e5 88                  lsl.l #$2, d0
  003348:  d1 c0                  adda.l d0, a0
  00334a:  70 00                  moveq #$0, d0
  00334c:  10 28 f0 bd            move.b -$f43(a0), d0
  003350:  3b 40 ba 7a            move.w d0, -$4586(a5)
  003354:  3b 46 ba 6c            move.w d6, -$4594(a5)
  003358:  3b 45 ba 6e            move.w d5, -$4592(a5)
  00335c:  3b 44 ba 70            move.w d4, -$4590(a5)
  003360:  3b 43 ba 72            move.w d3, -$458e(a5)
  003364:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  003368:  4e 75                  rts 
  00336a:  48 e7 03 00            movem.l d6-d7, -(a7)
  00336e:  4e ba 03 52            jsr $36c2(pc)
  003372:  3b 7c 00 bc f2 26      move.w #$bc, -$dda(a5)
  003378:  3b 7c 00 bf f2 24      move.w #$bf, -$ddc(a5)
  00337e:  7e 02                  moveq #$2, d7
  003380:  60 2e                  bra.b $33b0
  003382:  3b 47 f2 1e            move.w d7, -$de2(a5)
  003386:  4e ba 03 a0            jsr $3728(pc)
  00338a:  7c 00                  moveq #$0, d6
  00338c:  60 0e                  bra.b $339c
  00338e:  3b 46 f2 20            move.w d6, -$de0(a5)
  003392:  4e ba 02 be            jsr $3652(pc)
  003396:  4e ba 00 5e            jsr $33f6(pc)
  00339a:  52 46                  addq.w #$1, d6
  00339c:  0c 46 00 0a            cmpi.w #$a, d6
  0033a0:  6d ec                  blt.b $338e
  0033a2:  04 6d 00 3f f2 26      subi.w #$3f, -$dda(a5)
  0033a8:  04 6d 00 3f f2 24      subi.w #$3f, -$ddc(a5)
  0033ae:  53 47                  subq.w #$1, d7
  0033b0:  4a 47                  tst.w d7
  0033b2:  6c ce                  bge.b $3382
  0033b4:  3e 2d ba 6a            move.w -$4596(a5), d7
  0033b8:  3b 6d ba 70 ba 6a      move.w -$4590(a5), -$4596(a5)
  0033be:  4e ba fe 96            jsr $3256(pc)
  0033c2:  4e ba 02 fe            jsr $36c2(pc)
  0033c6:  3b 7c 00 02 f2 1e      move.w #$2, -$de2(a5)
  0033cc:  4e ba 03 5a            jsr $3728(pc)
  0033d0:  7c 00                  moveq #$0, d6
  0033d2:  60 0e                  bra.b $33e2
  0033d4:  3b 46 f2 20            move.w d6, -$de0(a5)
  0033d8:  4e ba 02 78            jsr $3652(pc)
  0033dc:  4e ba 00 44            jsr $3422(pc)
  0033e0:  52 46                  addq.w #$1, d6
  0033e2:  0c 46 00 0a            cmpi.w #$a, d6
  0033e6:  6d ec                  blt.b $33d4
  0033e8:  3b 47 ba 6a            move.w d7, -$4596(a5)
  0033ec:  4e ba fe 68            jsr $3256(pc)
  0033f0:  4c df 00 c0            movem.l (a7)+, d6-d7
  0033f4:  4e 75                  rts 
  0033f6:  4e ba 03 e2            jsr $37da(pc)
  0033fa:  4e ba 04 ee            jsr $38ea(pc)
  0033fe:  4e ba 05 c6            jsr $39c6(pc)
  003402:  4e ba 08 06            jsr $3c0a(pc)
  003406:  42 67                  clr.w -(a7)
  003408:  4e ba 09 0a            jsr $3d14(pc)
  00340c:  42 57                  clr.w (a7)
  00340e:  4e ba 09 ae            jsr $3dbe(pc)
  003412:  4e ba 0a 04            jsr $3e18(pc)
  003416:  4e ba 0a 98            jsr $3eb0(pc)
  00341a:  4e ba 0c 2e            jsr $404a(pc)
  00341e:  54 8f                  addq.l #$2, a7
  003420:  4e 75                  rts 
  003422:  4e ba 03 b6            jsr $37da(pc)
  003426:  4e ba 04 c2            jsr $38ea(pc)
  00342a:  4e ba 05 9a            jsr $39c6(pc)
  00342e:  42 67                  clr.w -(a7)
  003430:  4e ba 08 e2            jsr $3d14(pc)
  003434:  42 57                  clr.w (a7)
  003436:  4e ba 09 86            jsr $3dbe(pc)
  00343a:  4e ba 0c 0e            jsr $404a(pc)
  00343e:  54 8f                  addq.l #$2, a7
  003440:  4e 75                  rts 
  003442:  4e 56 00 00            link.w a6, #$0
  003446:  48 e7 03 18            movem.l d6-d7/a3-a4, -(a7)
  00344a:  3e 2e 00 08            move.w $8(a6), d7
  00344e:  49 ed bb 90            lea.l -$4470(a5), a4
  003452:  d8 c7                  adda.w d7, a4
  003454:  4a 14                  tst.b (a4)
  003456:  67 16                  beq.b $346e
  003458:  47 ed bb ae            lea.l -$4452(a5), a3
  00345c:  d6 c7                  adda.w d7, a3
  00345e:  10 13                  move.b (a3), d0
  003460:  48 80                  ext.w d0
  003462:  3f 00                  move.w d0, -(a7)
  003464:  4e ba 1b 38            jsr $4f9e(pc)
  003468:  42 14                  clr.b (a4)
  00346a:  42 13                  clr.b (a3)
  00346c:  54 8f                  addq.l #$2, a7
  00346e:  49 ed bb 72            lea.l -$448e(a5), a4
  003472:  d8 c7                  adda.w d7, a4
  003474:  4a 14                  tst.b (a4)
  003476:  67 08                  beq.b $3480
  003478:  4e ba ff 7c            jsr $33f6(pc)
  00347c:  42 14                  clr.b (a4)
  00347e:  60 18                  bra.b $3498
  003480:  49 ed bb cc            lea.l -$4434(a5), a4
  003484:  d8 c7                  adda.w d7, a4
  003486:  4a 14                  tst.b (a4)
  003488:  67 0e                  beq.b $3498
  00348a:  4e ba 04 5e            jsr $38ea(pc)
  00348e:  4e ba 07 7a            jsr $3c0a(pc)
  003492:  4e ba 0a 1c            jsr $3eb0(pc)
  003496:  42 14                  clr.b (a4)
  003498:  49 ed bc 08            lea.l -$43f8(a5), a4
  00349c:  d8 c7                  adda.w d7, a4
  00349e:  4a 14                  tst.b (a4)
  0034a0:  67 08                  beq.b $34aa
  0034a2:  4e ba 1d c0            jsr $5264(pc)
  0034a6:  42 14                  clr.b (a4)
  0034a8:  60 10                  bra.b $34ba
  0034aa:  49 ed bc 26            lea.l -$43da(a5), a4
  0034ae:  d8 c7                  adda.w d7, a4
  0034b0:  4a 14                  tst.b (a4)
  0034b2:  67 06                  beq.b $34ba
  0034b4:  4e ba 1c f0            jsr $51a6(pc)
  0034b8:  42 14                  clr.b (a4)
  0034ba:  20 4d                  movea.l a5, a0
  0034bc:  d0 c7                  adda.w d7, a0
  0034be:  1c 28 bc 44            move.b -$43bc(a0), d6
  0034c2:  49 ed bc 44            lea.l -$43bc(a5), a4
  0034c6:  d8 c7                  adda.w d7, a4
  0034c8:  4a 06                  tst.b d6
  0034ca:  67 1c                  beq.b $34e8
  0034cc:  0c 06 00 ff            cmpi.b #$ff, d6
  0034d0:  66 0c                  bne.b $34de
  0034d2:  70 ff                  moveq #$ff, d0
  0034d4:  d0 07                  add.b d7, d0
  0034d6:  1f 00                  move.b d0, -(a7)
  0034d8:  4e ba 1e 22            jsr $52fc(pc)
  0034dc:  54 8f                  addq.l #$2, a7
  0034de:  1f 07                  move.b d7, -(a7)
  0034e0:  4e ba 1e 1a            jsr $52fc(pc)
  0034e4:  42 14                  clr.b (a4)
  0034e6:  54 8f                  addq.l #$2, a7
  0034e8:  49 ed bb ea            lea.l -$4416(a5), a4
  0034ec:  d8 c7                  adda.w d7, a4
  0034ee:  4a 14                  tst.b (a4)
  0034f0:  67 06                  beq.b $34f8
  0034f2:  4e ba 0b 56            jsr $404a(pc)
  0034f6:  42 14                  clr.b (a4)
  0034f8:  4c df 18 c0            movem.l (a7)+, d6-d7/a3-a4
  0034fc:  4e 5e                  unlk a6
  0034fe:  4e 75                  rts 
  003500:  4e 56 00 00            link.w a6, #$0
  003504:  48 e7 01 08            movem.l d7/a4, -(a7)
  003508:  3e 2e 00 08            move.w $8(a6), d7
  00350c:  49 ed bc 62            lea.l -$439e(a5), a4
  003510:  d8 c7                  adda.w d7, a4
  003512:  4a 14                  tst.b (a4)
  003514:  67 2c                  beq.b $3542
  003516:  3f 3c 00 03            move.w #$3, -(a7)
  00351a:  4e ba 1a 82            jsr $4f9e(pc)
  00351e:  4e ba 02 ba            jsr $37da(pc)
  003522:  4e ba 03 c6            jsr $38ea(pc)
  003526:  4e ba 04 9e            jsr $39c6(pc)
  00352a:  3e bc 00 01            move.w #$1, (a7)
  00352e:  4e ba 07 e4            jsr $3d14(pc)
  003532:  3e bc 00 01            move.w #$1, (a7)
  003536:  4e ba 08 86            jsr $3dbe(pc)
  00353a:  4e ba 0b 0e            jsr $404a(pc)
  00353e:  42 14                  clr.b (a4)
  003540:  54 8f                  addq.l #$2, a7
  003542:  4c df 10 80            movem.l (a7)+, d7/a4
  003546:  4e 5e                  unlk a6
  003548:  4e 75                  rts 
  00354a:  4e 56 00 00            link.w a6, #$0
  00354e:  48 e7 07 08            movem.l d5-d7/a4, -(a7)
  003552:  3c 2e 00 08            move.w $8(a6), d6
  003556:  3e 2e 00 0a            move.w $a(a6), d7
  00355a:  4a 47                  tst.w d7
  00355c:  6c 10                  bge.b $356e
  00355e:  49 ed e9 04            lea.l -$16fc(a5), a4
  003562:  d8 c6                  adda.w d6, a4
  003564:  d8 c6                  adda.w d6, a4
  003566:  1e 14                  move.b (a4), d7
  003568:  1c 2c 00 01            move.b $1(a4), d6
  00356c:  60 1e                  bra.b $358c
  00356e:  20 4d                  movea.l a5, a0
  003570:  d0 c6                  adda.w d6, a0
  003572:  d0 c6                  adda.w d6, a0
  003574:  3a 28 b6 46            move.w -$49ba(a0), d5
  003578:  da 47                  add.w d7, d5
  00357a:  20 6d bd 82            movea.l -$427e(a5), a0
  00357e:  7e 1f                  moveq #$1f, d7
  003580:  ce 30 50 00            and.b (a0, d5.w), d7
  003584:  22 6d bd 86            movea.l -$427a(a5), a1
  003588:  1c 31 50 00            move.b (a1, d5.w), d6
  00358c:  0c 07 00 06            cmpi.b #$6, d7
  003590:  66 14                  bne.b $35a6
  003592:  70 00                  moveq #$0, d0
  003594:  10 06                  move.b d6, d0
  003596:  3f 00                  move.w d0, -(a7)
  003598:  4e ba f1 6a            jsr $2704(pc)
  00359c:  53 40                  subq.w #$1, d0
  00359e:  54 8f                  addq.l #$2, a7
  0035a0:  6f 1c                  ble.b $35be
  0035a2:  7e 05                  moveq #$5, d7
  0035a4:  60 18                  bra.b $35be
  0035a6:  0c 07 00 0f            cmpi.b #$f, d7
  0035aa:  66 12                  bne.b $35be
  0035ac:  70 00                  moveq #$0, d0
  0035ae:  10 06                  move.b d6, d0
  0035b0:  3f 00                  move.w d0, -(a7)
  0035b2:  4e ba f1 50            jsr $2704(pc)
  0035b6:  53 40                  subq.w #$1, d0
  0035b8:  54 8f                  addq.l #$2, a7
  0035ba:  6f 02                  ble.b $35be
  0035bc:  7e 01                  moveq #$1, d7
  0035be:  10 07                  move.b d7, d0
  0035c0:  4c df 10 e0            movem.l (a7)+, d5-d7/a4
  0035c4:  4e 5e                  unlk a6
  0035c6:  4e 75                  rts 
  0035c8:  4e 56 00 00            link.w a6, #$0
  0035cc:  48 e7 07 38            movem.l d5-d7/a2-a4, -(a7)
  0035d0:  3c 2e 00 08            move.w $8(a6), d6
  0035d4:  3e 2e 00 0a            move.w $a(a6), d7
  0035d8:  28 6e 00 0c            movea.l $c(a6), a4
  0035dc:  26 6e 00 10            movea.l $10(a6), a3
  0035e0:  4a 47                  tst.w d7
  0035e2:  6c 10                  bge.b $35f4
  0035e4:  45 ed e9 04            lea.l -$16fc(a5), a2
  0035e8:  d4 c6                  adda.w d6, a2
  0035ea:  d4 c6                  adda.w d6, a2
  0035ec:  1e 12                  move.b (a2), d7
  0035ee:  1c 2a 00 01            move.b $1(a2), d6
  0035f2:  60 1e                  bra.b $3612
  0035f4:  20 4d                  movea.l a5, a0
  0035f6:  d0 c6                  adda.w d6, a0
  0035f8:  d0 c6                  adda.w d6, a0
  0035fa:  3a 28 b6 46            move.w -$49ba(a0), d5
  0035fe:  da 47                  add.w d7, d5
  003600:  20 6d bd 82            movea.l -$427e(a5), a0
  003604:  7e 1f                  moveq #$1f, d7
  003606:  ce 30 50 00            and.b (a0, d5.w), d7
  00360a:  22 6d bd 86            movea.l -$427a(a5), a1
  00360e:  1c 31 50 00            move.b (a1, d5.w), d6
  003612:  0c 07 00 06            cmpi.b #$6, d7
  003616:  66 14                  bne.b $362c
  003618:  70 00                  moveq #$0, d0
  00361a:  10 06                  move.b d6, d0
  00361c:  3f 00                  move.w d0, -(a7)
  00361e:  4e ba f0 e4            jsr $2704(pc)
  003622:  53 40                  subq.w #$1, d0
  003624:  54 8f                  addq.l #$2, a7
  003626:  6f 1e                  ble.b $3646
  003628:  7e 05                  moveq #$5, d7
  00362a:  60 1a                  bra.b $3646
  00362c:  0c 07 00 0f            cmpi.b #$f, d7
  003630:  66 14                  bne.b $3646
  003632:  70 00                  moveq #$0, d0
  003634:  10 06                  move.b d6, d0
  003636:  3f 00                  move.w d0, -(a7)
  003638:  4e ba f0 ca            jsr $2704(pc)
  00363c:  53 40                  subq.w #$1, d0
  00363e:  54 8f                  addq.l #$2, a7
  003640:  6f 04                  ble.b $3646
  003642:  7e 01                  moveq #$1, d7
  003644:  7c 00                  moveq #$0, d6
  003646:  18 87                  move.b d7, (a4)
  003648:  16 86                  move.b d6, (a3)
  00364a:  4c df 1c e0            movem.l (a7)+, d5-d7/a2-a4
  00364e:  4e 5e                  unlk a6
  003650:  4e 75                  rts 
  003652:  4a 6d ba 6a            tst.w -$4596(a5)
  003656:  67 32                  beq.b $368a
  003658:  48 6d ba 95            pea.l -$456b(a5)
  00365c:  48 6d ba 94            pea.l -$456c(a5)
  003660:  3f 2d f2 20            move.w -$de0(a5), -(a7)
  003664:  3f 2d f2 1e            move.w -$de2(a5), -(a7)
  003668:  4e ba ff 5e            jsr $35c8(pc)
  00366c:  48 6d ba 97            pea.l -$4569(a5)
  003670:  48 6d ba 96            pea.l -$456a(a5)
  003674:  70 ff                  moveq #$ff, d0
  003676:  d0 6d f2 20            add.w -$de0(a5), d0
  00367a:  3f 00                  move.w d0, -(a7)
  00367c:  3f 2d f2 1e            move.w -$de2(a5), -(a7)
  003680:  4e ba ff 46            jsr $35c8(pc)
  003684:  4f ef 00 18            lea.l $18(a7), a7
  003688:  60 26                  bra.b $36b0
  00368a:  0c 6d 00 02 f2 1e      cmpi.w #$2, -$de2(a5)
  003690:  6c 0c                  bge.b $369e
  003692:  70 14                  moveq #$14, d0
  003694:  1b 40 ba 96            move.b d0, -$456a(a5)
  003698:  1b 40 ba 94            move.b d0, -$456c(a5)
  00369c:  60 0a                  bra.b $36a8
  00369e:  70 01                  moveq #$1, d0
  0036a0:  1b 40 ba 96            move.b d0, -$456a(a5)
  0036a4:  1b 40 ba 94            move.b d0, -$456c(a5)
  0036a8:  42 2d ba 97            clr.b -$4569(a5)
  0036ac:  42 2d ba 95            clr.b -$456b(a5)
  0036b0:  30 2d f2 20            move.w -$de0(a5), d0
  0036b4:  20 4d                  movea.l a5, a0
  0036b6:  d0 c0                  adda.w d0, a0
  0036b8:  d0 c0                  adda.w d0, a0
  0036ba:  3b 68 b8 a4 f2 22      move.w -$475c(a0), -$dde(a5)
  0036c0:  4e 75                  rts 
  0036c2:  3f 2d ba 6c            move.w -$4594(a5), -(a7)
  0036c6:  4e ba 1a a2            jsr $516a(pc)
  0036ca:  4a 6d ba 6c            tst.w -$4594(a5)
  0036ce:  54 8f                  addq.l #$2, a7
  0036d0:  67 3a                  beq.b $370c
  0036d2:  48 6d e9 05            pea.l -$16fb(a5)
  0036d6:  48 6d e9 04            pea.l -$16fc(a5)
  0036da:  48 78 00 09            pea.l $9.w
  0036de:  4e ba fe e8            jsr $35c8(pc)
  0036e2:  48 6d e9 07            pea.l -$16f9(a5)
  0036e6:  48 6d e9 06            pea.l -$16fa(a5)
  0036ea:  2f 3c 00 01 00 09      move.l #$10009, -(a7)
  0036f0:  4e ba fe d6            jsr $35c8(pc)
  0036f4:  48 6d e9 09            pea.l -$16f7(a5)
  0036f8:  48 6d e9 08            pea.l -$16f8(a5)
  0036fc:  2f 3c 00 02 00 09      move.l #$20009, -(a7)
  003702:  4e ba fe c4            jsr $35c8(pc)
  003706:  4f ef 00 24            lea.l $24(a7), a7
  00370a:  60 1a                  bra.b $3726
  00370c:  70 14                  moveq #$14, d0
  00370e:  1b 40 e9 08            move.b d0, -$16f8(a5)
  003712:  1b 40 e9 06            move.b d0, -$16fa(a5)
  003716:  1b 40 e9 04            move.b d0, -$16fc(a5)
  00371a:  42 2d e9 09            clr.b -$16f7(a5)
  00371e:  42 2d e9 07            clr.b -$16f9(a5)
  003722:  42 2d e9 05            clr.b -$16fb(a5)
  003726:  4e 75                  rts 
  003728:  48 e7 07 08            movem.l d5-d7/a4, -(a7)
  00372c:  0c 6d 00 02 f2 1e      cmpi.w #$2, -$de2(a5)
  003732:  66 0c                  bne.b $3740
  003734:  3e 2d ba 72            move.w -$458e(a5), d7
  003738:  3c 2d ba 78            move.w -$4588(a5), d6
  00373c:  7a 00                  moveq #$0, d5
  00373e:  60 0e                  bra.b $374e
  003740:  3e 2d ba 6a            move.w -$4596(a5), d7
  003744:  3c 2d ba 6c            move.w -$4594(a5), d6
  003748:  7a 01                  moveq #$1, d5
  00374a:  da 6d f2 1e            add.w -$de2(a5), d5
  00374e:  3f 07                  move.w d7, -(a7)
  003750:  4e ba 1a 18            jsr $516a(pc)
  003754:  4a 47                  tst.w d7
  003756:  54 8f                  addq.l #$2, a7
  003758:  67 2a                  beq.b $3784
  00375a:  7e 01                  moveq #$1, d7
  00375c:  49 ed e9 0c            lea.l -$16f4(a5), a4
  003760:  60 1a                  bra.b $377c
  003762:  48 6c 00 01            pea.l $1(a4)
  003766:  2f 0c                  move.l a4, -(a7)
  003768:  70 ff                  moveq #$ff, d0
  00376a:  d0 47                  add.w d7, d0
  00376c:  3f 00                  move.w d0, -(a7)
  00376e:  3f 05                  move.w d5, -(a7)
  003770:  4e ba fe 56            jsr $35c8(pc)
  003774:  4f ef 00 0c            lea.l $c(a7), a7
  003778:  52 47                  addq.w #$1, d7
  00377a:  54 8c                  addq.l #$2, a4
  00377c:  0c 47 00 0a            cmpi.w #$a, d7
  003780:  6d e0                  blt.b $3762
  003782:  60 18                  bra.b $379c
  003784:  7e 01                  moveq #$1, d7
  003786:  49 ed e9 0c            lea.l -$16f4(a5), a4
  00378a:  60 0a                  bra.b $3796
  00378c:  42 14                  clr.b (a4)
  00378e:  42 2c 00 01            clr.b $1(a4)
  003792:  52 47                  addq.w #$1, d7
  003794:  54 8c                  addq.l #$2, a4
  003796:  0c 47 00 0a            cmpi.w #$a, d7
  00379a:  6d f0                  blt.b $378c
  00379c:  3f 06                  move.w d6, -(a7)
  00379e:  4e ba 19 ca            jsr $516a(pc)
  0037a2:  4a 46                  tst.w d6
  0037a4:  54 8f                  addq.l #$2, a7
  0037a6:  67 18                  beq.b $37c0
  0037a8:  48 6d e9 0b            pea.l -$16f5(a5)
  0037ac:  48 6d e9 0a            pea.l -$16f6(a5)
  0037b0:  3f 3c 00 09            move.w #$9, -(a7)
  0037b4:  3f 05                  move.w d5, -(a7)
  0037b6:  4e ba fe 10            jsr $35c8(pc)
  0037ba:  4f ef 00 0c            lea.l $c(a7), a7
  0037be:  60 0a                  bra.b $37ca
  0037c0:  1b 7c 00 14 e9 0a      move.b #$14, -$16f6(a5)
  0037c6:  42 2d e9 0b            clr.b -$16f5(a5)
  0037ca:  3f 2d ba 6a            move.w -$4596(a5), -(a7)
  0037ce:  4e ba 19 9a            jsr $516a(pc)
  0037d2:  54 8f                  addq.l #$2, a7
  0037d4:  4c df 10 e0            movem.l (a7)+, d5-d7/a4
  0037d8:  4e 75                  rts 
  0037da:  4e ba 00 40            jsr $381c(pc)
  0037de:  4a 00                  tst.b d0
  0037e0:  67 38                  beq.b $381a
  0037e2:  4e ba 00 60            jsr $3844(pc)
  0037e6:  70 00                  moveq #$0, d0
  0037e8:  10 2d ba 96            move.b -$456a(a5), d0
  0037ec:  c1 fc 00 0c            muls.w #$c, d0
  0037f0:  20 4d                  movea.l a5, a0
  0037f2:  d1 c0                  adda.l d0, a0
  0037f4:  4a 28 b4 04            tst.b -$4bfc(a0)
  0037f8:  67 20                  beq.b $381a
  0037fa:  10 2d b4 11            move.b -$4bef(a5), d0
  0037fe:  48 80                  ext.w d0
  003800:  d0 6d f2 26            add.w -$dda(a5), d0
  003804:  3f 00                  move.w d0, -(a7)
  003806:  42 67                  clr.w -(a7)
  003808:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  00380c:  2f 3c 00 06 00 2a      move.l #$6002a, -(a7)
  003812:  4e ba 0b 66            jsr $437a(pc)
  003816:  4f ef 00 0a            lea.l $a(a7), a7
  00381a:  4e 75                  rts 
  00381c:  2f 07                  move.l d7, -(a7)
  00381e:  7e 00                  moveq #$0, d7
  003820:  1e 2d ba 94            move.b -$456c(a5), d7
  003824:  4a 47                  tst.w d7
  003826:  67 12                  beq.b $383a
  003828:  0c 47 00 09            cmpi.w #$9, d7
  00382c:  67 0c                  beq.b $383a
  00382e:  0c 47 00 0c            cmpi.w #$c, d7
  003832:  67 06                  beq.b $383a
  003834:  0c 47 00 1a            cmpi.w #$1a, d7
  003838:  66 04                  bne.b $383e
  00383a:  70 01                  moveq #$1, d0
  00383c:  60 02                  bra.b $3840
  00383e:  70 00                  moveq #$0, d0
  003840:  2e 1f                  move.l (a7)+, d7
  003842:  4e 75                  rts 
  003844:  2f 07                  move.l d7, -(a7)
  003846:  30 2d f2 20            move.w -$de0(a5), d0
  00384a:  20 4d                  movea.l a5, a0
  00384c:  d0 c0                  adda.w d0, a0
  00384e:  d0 c0                  adda.w d0, a0
  003850:  1e 28 e9 0a            move.b -$16f6(a0), d7
  003854:  0c 07 00 07            cmpi.b #$7, d7
  003858:  67 06                  beq.b $3860
  00385a:  0c 07 00 0c            cmpi.b #$c, d7
  00385e:  66 3c                  bne.b $389c
  003860:  4a 2d b9 44            tst.b -$46bc(a5)
  003864:  67 00 00 80            beq.w $38e6
  003868:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  00386c:  42 67                  clr.w -(a7)
  00386e:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003872:  30 2d f2 20            move.w -$de0(a5), d0
  003876:  20 4d                  movea.l a5, a0
  003878:  d0 c0                  adda.w d0, a0
  00387a:  d0 c0                  adda.w d0, a0
  00387c:  72 00                  moveq #$0, d1
  00387e:  12 28 e9 0b            move.b -$16f5(a0), d1
  003882:  20 4d                  movea.l a5, a0
  003884:  d1 c1                  adda.l d1, a0
  003886:  72 00                  moveq #$0, d1
  003888:  12 28 b6 26            move.b -$49da(a0), d1
  00388c:  3f 01                  move.w d1, -(a7)
  00388e:  3f 3c 00 06            move.w #$6, -(a7)
  003892:  4e ba 0a e6            jsr $437a(pc)
  003896:  4f ef 00 0a            lea.l $a(a7), a7
  00389a:  60 4a                  bra.b $38e6
  00389c:  0c 07 00 14            cmpi.b #$14, d7
  0038a0:  66 1a                  bne.b $38bc
  0038a2:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  0038a6:  42 67                  clr.w -(a7)
  0038a8:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  0038ac:  2f 3c 00 07 00 02      move.l #$70002, -(a7)
  0038b2:  4e ba 0a c6            jsr $437a(pc)
  0038b6:  4f ef 00 0a            lea.l $a(a7), a7
  0038ba:  60 2a                  bra.b $38e6
  0038bc:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  0038c0:  42 67                  clr.w -(a7)
  0038c2:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  0038c6:  70 00                  moveq #$0, d0
  0038c8:  10 07                  move.b d7, d0
  0038ca:  c1 fc 00 0c            muls.w #$c, d0
  0038ce:  20 4d                  movea.l a5, a0
  0038d0:  d1 c0                  adda.l d0, a0
  0038d2:  70 00                  moveq #$0, d0
  0038d4:  10 28 b4 07            move.b -$4bf9(a0), d0
  0038d8:  3f 00                  move.w d0, -(a7)
  0038da:  3f 3c 00 06            move.w #$6, -(a7)
  0038de:  4e ba 0a 9a            jsr $437a(pc)
  0038e2:  4f ef 00 0a            lea.l $a(a7), a7
  0038e6:  2e 1f                  move.l (a7)+, d7
  0038e8:  4e 75                  rts 
  0038ea:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  0038ee:  7e 00                  moveq #$0, d7
  0038f0:  1e 2d ba 94            move.b -$456c(a5), d7
  0038f4:  4a 47                  tst.w d7
  0038f6:  67 0e                  beq.b $3906
  0038f8:  0c 47 00 0c            cmpi.w #$c, d7
  0038fc:  67 08                  beq.b $3906
  0038fe:  0c 47 00 09            cmpi.w #$9, d7
  003902:  66 00 00 bc            bne.w $39c0
  003906:  30 2d f2 20            move.w -$de0(a5), d0
  00390a:  49 ed e9 0a            lea.l -$16f6(a5), a4
  00390e:  d8 c0                  adda.w d0, a4
  003910:  d8 c0                  adda.w d0, a4
  003912:  0c 14 00 04            cmpi.b #$4, (a4)
  003916:  66 00 00 a8            bne.w $39c0
  00391a:  7e 00                  moveq #$0, d7
  00391c:  1e 2c 00 01            move.b $1(a4), d7
  003920:  0c 47 00 bc            cmpi.w #$bc, d7
  003924:  6f 04                  ble.b $392a
  003926:  3e 3c 00 bc            move.w #$bc, d7
  00392a:  2c 07                  move.l d7, d6
  00392c:  48 c6                  ext.l d6
  00392e:  8d fc 00 04            divs.w #$4, d6
  003932:  4a 2d a2 0a            tst.b -$5df6(a5)
  003936:  67 42                  beq.b $397a
  003938:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  00393c:  42 67                  clr.w -(a7)
  00393e:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003942:  2f 3c 00 06 00 44      move.l #$60044, -(a7)
  003948:  4e ba 0a 30            jsr $437a(pc)
  00394c:  3e ad f2 24            move.w -$ddc(a5), (a7)
  003950:  42 67                  clr.w -(a7)
  003952:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003956:  20 06                  move.l d6, d0
  003958:  48 c0                  ext.l d0
  00395a:  81 fc 00 08            divs.w #$8, d0
  00395e:  48 40                  swap d0
  003960:  20 4d                  movea.l a5, a0
  003962:  d0 c0                  adda.w d0, a0
  003964:  70 00                  moveq #$0, d0
  003966:  10 28 b5 e2            move.b -$4a1e(a0), d0
  00396a:  3f 00                  move.w d0, -(a7)
  00396c:  3f 3c 00 06            move.w #$6, -(a7)
  003970:  4e ba 0a 08            jsr $437a(pc)
  003974:  4f ef 00 12            lea.l $12(a7), a7
  003978:  60 46                  bra.b $39c0
  00397a:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  00397e:  42 67                  clr.w -(a7)
  003980:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003984:  2f 3c 00 06 00 34      move.l #$60034, -(a7)
  00398a:  4e ba 09 ee            jsr $437a(pc)
  00398e:  0c 46 00 2d            cmpi.w #$2d, d6
  003992:  4f ef 00 0a            lea.l $a(a7), a7
  003996:  6f 02                  ble.b $399a
  003998:  7c 2d                  moveq #$2d, d6
  00399a:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  00399e:  42 67                  clr.w -(a7)
  0039a0:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  0039a4:  20 4d                  movea.l a5, a0
  0039a6:  d0 c6                  adda.w d6, a0
  0039a8:  70 00                  moveq #$0, d0
  0039aa:  10 28 b5 f2            move.b -$4a0e(a0), d0
  0039ae:  06 40 00 35            addi.w #$35, d0
  0039b2:  3f 00                  move.w d0, -(a7)
  0039b4:  3f 3c 00 06            move.w #$6, -(a7)
  0039b8:  4e ba 09 c0            jsr $437a(pc)
  0039bc:  4f ef 00 0a            lea.l $a(a7), a7
  0039c0:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  0039c4:  4e 75                  rts 
  0039c6:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  0039ca:  0c 2d 00 14 ba 94      cmpi.b #$14, -$456c(a5)
  0039d0:  67 00 02 08            beq.w $3bda
  0039d4:  1e 2d ba 96            move.b -$456a(a5), d7
  0039d8:  1c 2d ba 97            move.b -$4569(a5), d6
  0039dc:  70 00                  moveq #$0, d0
  0039de:  10 07                  move.b d7, d0
  0039e0:  c1 fc 00 0c            muls.w #$c, d0
  0039e4:  49 ed b4 00            lea.l -$4c00(a5), a4
  0039e8:  d0 8c                  add.l a4, d0
  0039ea:  28 40                  movea.l d0, a4
  0039ec:  1a 2c 00 03            move.b $3(a4), d5
  0039f0:  18 2c 00 05            move.b $5(a4), d4
  0039f4:  70 00                  moveq #$0, d0
  0039f6:  10 07                  move.b d7, d0
  0039f8:  0c 40 00 14            cmpi.w #$14, d0
  0039fc:  62 00 01 66            bhi.w $3b64
  003a00:  43 fa 01 de            lea.l $3be0(pc), a1
  003a04:  d0 40                  add.w d0, d0
  003a06:  d2 f1 00 00            adda.w (a1, d0.w), a1
  003a0a:  4e d1                  jmp (a1)
  003a0c:  0c 06 00 03            cmpi.b #$3, d6
  003a10:  62 00 01 c8            bhi.w $3bda
  003a14:  7e 00                  moveq #$0, d7
  003a16:  1e 06                  move.b d6, d7
  003a18:  20 4d                  movea.l a5, a0
  003a1a:  d1 c7                  adda.l d7, a0
  003a1c:  10 28 b6 2e            move.b -$49d2(a0), d0
  003a20:  48 80                  ext.w d0
  003a22:  d0 6d f2 26            add.w -$dda(a5), d0
  003a26:  3f 00                  move.w d0, -(a7)
  003a28:  42 67                  clr.w -(a7)
  003a2a:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003a2e:  20 4d                  movea.l a5, a0
  003a30:  d1 c7                  adda.l d7, a0
  003a32:  70 00                  moveq #$0, d0
  003a34:  10 28 b6 2a            move.b -$49d6(a0), d0
  003a38:  3f 00                  move.w d0, -(a7)
  003a3a:  3f 3c 00 06            move.w #$6, -(a7)
  003a3e:  4e ba 09 3a            jsr $437a(pc)
  003a42:  4f ef 00 0a            lea.l $a(a7), a7
  003a46:  60 00 01 92            bra.w $3bda
  003a4a:  10 04                  move.b d4, d0
  003a4c:  48 80                  ext.w d0
  003a4e:  d0 6d f2 26            add.w -$dda(a5), d0
  003a52:  3f 00                  move.w d0, -(a7)
  003a54:  42 67                  clr.w -(a7)
  003a56:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003a5a:  2f 3c 00 06 00 2a      move.l #$6002a, -(a7)
  003a60:  20 6d bd 70            movea.l -$4290(a5), a0
  003a64:  4e 90                  jsr (a0)
  003a66:  0c 06 00 03            cmpi.b #$3, d6
  003a6a:  4f ef 00 0a            lea.l $a(a7), a7
  003a6e:  63 02                  bls.b $3a72
  003a70:  7c 00                  moveq #$0, d6
  003a72:  4a 2d b9 44            tst.b -$46bc(a5)
  003a76:  66 34                  bne.b $3aac
  003a78:  4a 06                  tst.b d6
  003a7a:  67 00 01 5e            beq.w $3bda
  003a7e:  70 ec                  moveq #$ec, d0
  003a80:  d0 6d f2 26            add.w -$dda(a5), d0
  003a84:  3f 00                  move.w d0, -(a7)
  003a86:  42 67                  clr.w -(a7)
  003a88:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003a8c:  70 00                  moveq #$0, d0
  003a8e:  10 06                  move.b d6, d0
  003a90:  20 4d                  movea.l a5, a0
  003a92:  d1 c0                  adda.l d0, a0
  003a94:  70 00                  moveq #$0, d0
  003a96:  10 28 b6 32            move.b -$49ce(a0), d0
  003a9a:  3f 00                  move.w d0, -(a7)
  003a9c:  3f 3c 00 06            move.w #$6, -(a7)
  003aa0:  4e ba 08 d8            jsr $437a(pc)
  003aa4:  4f ef 00 0a            lea.l $a(a7), a7
  003aa8:  60 00 01 30            bra.w $3bda
  003aac:  0c 06 00 01            cmpi.b #$1, d6
  003ab0:  67 00 01 28            beq.w $3bda
  003ab4:  70 02                  moveq #$2, d0
  003ab6:  d0 6d f2 26            add.w -$dda(a5), d0
  003aba:  3f 00                  move.w d0, -(a7)
  003abc:  42 67                  clr.w -(a7)
  003abe:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003ac2:  70 00                  moveq #$0, d0
  003ac4:  10 06                  move.b d6, d0
  003ac6:  20 4d                  movea.l a5, a0
  003ac8:  d1 c0                  adda.l d0, a0
  003aca:  70 00                  moveq #$0, d0
  003acc:  10 28 b6 32            move.b -$49ce(a0), d0
  003ad0:  3f 00                  move.w d0, -(a7)
  003ad2:  3f 3c 00 06            move.w #$6, -(a7)
  003ad6:  4e ba 08 a2            jsr $437a(pc)
  003ada:  4f ef 00 0a            lea.l $a(a7), a7
  003ade:  60 00 00 fa            bra.w $3bda
  003ae2:  4a 2d b9 44            tst.b -$46bc(a5)
  003ae6:  67 00 00 f2            beq.w $3bda
  003aea:  10 04                  move.b d4, d0
  003aec:  48 80                  ext.w d0
  003aee:  d0 6d f2 26            add.w -$dda(a5), d0
  003af2:  3f 00                  move.w d0, -(a7)
  003af4:  42 67                  clr.w -(a7)
  003af6:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003afa:  70 00                  moveq #$0, d0
  003afc:  10 06                  move.b d6, d0
  003afe:  20 4d                  movea.l a5, a0
  003b00:  d1 c0                  adda.l d0, a0
  003b02:  70 00                  moveq #$0, d0
  003b04:  10 28 b6 22            move.b -$49de(a0), d0
  003b08:  3f 00                  move.w d0, -(a7)
  003b0a:  3f 3c 00 06            move.w #$6, -(a7)
  003b0e:  4e ba 08 6a            jsr $437a(pc)
  003b12:  4f ef 00 0a            lea.l $a(a7), a7
  003b16:  60 00 00 c2            bra.w $3bda
  003b1a:  4a 2d b9 44            tst.b -$46bc(a5)
  003b1e:  67 24                  beq.b $3b44
  003b20:  4a 06                  tst.b d6
  003b22:  6b 20                  bmi.b $3b44
  003b24:  70 e5                  moveq #$e5, d0
  003b26:  d0 6d f2 26            add.w -$dda(a5), d0
  003b2a:  3f 00                  move.w d0, -(a7)
  003b2c:  42 67                  clr.w -(a7)
  003b2e:  70 03                  moveq #$3, d0
  003b30:  d0 6d f2 22            add.w -$dde(a5), d0
  003b34:  3f 00                  move.w d0, -(a7)
  003b36:  2f 3c 00 06 00 54      move.l #$60054, -(a7)
  003b3c:  4e ba 08 3c            jsr $437a(pc)
  003b40:  4f ef 00 0a            lea.l $a(a7), a7
  003b44:  10 04                  move.b d4, d0
  003b46:  48 80                  ext.w d0
  003b48:  d0 6d f2 26            add.w -$dda(a5), d0
  003b4c:  3f 00                  move.w d0, -(a7)
  003b4e:  42 67                  clr.w -(a7)
  003b50:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003b54:  2f 3c 00 07 00 01      move.l #$70001, -(a7)
  003b5a:  4e ba 08 1e            jsr $437a(pc)
  003b5e:  4f ef 00 0a            lea.l $a(a7), a7
  003b62:  60 76                  bra.b $3bda
  003b64:  4a 05                  tst.b d5
  003b66:  67 22                  beq.b $3b8a
  003b68:  10 04                  move.b d4, d0
  003b6a:  48 80                  ext.w d0
  003b6c:  d0 6d f2 26            add.w -$dda(a5), d0
  003b70:  3f 00                  move.w d0, -(a7)
  003b72:  42 67                  clr.w -(a7)
  003b74:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003b78:  70 00                  moveq #$0, d0
  003b7a:  10 05                  move.b d5, d0
  003b7c:  3f 00                  move.w d0, -(a7)
  003b7e:  3f 3c 00 06            move.w #$6, -(a7)
  003b82:  4e ba 07 f6            jsr $437a(pc)
  003b86:  4f ef 00 0a            lea.l $a(a7), a7
  003b8a:  4a 2d b9 44            tst.b -$46bc(a5)
  003b8e:  67 22                  beq.b $3bb2
  003b90:  70 e5                  moveq #$e5, d0
  003b92:  d0 6d f2 26            add.w -$dda(a5), d0
  003b96:  3f 00                  move.w d0, -(a7)
  003b98:  42 67                  clr.w -(a7)
  003b9a:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003b9e:  70 00                  moveq #$0, d0
  003ba0:  10 2c 00 06            move.b $6(a4), d0
  003ba4:  3f 00                  move.w d0, -(a7)
  003ba6:  3f 3c 00 06            move.w #$6, -(a7)
  003baa:  4e ba 07 ce            jsr $437a(pc)
  003bae:  4f ef 00 0a            lea.l $a(a7), a7
  003bb2:  0c 07 00 13            cmpi.b #$13, d7
  003bb6:  67 06                  beq.b $3bbe
  003bb8:  0c 07 00 1e            cmpi.b #$1e, d7
  003bbc:  66 1c                  bne.b $3bda
  003bbe:  70 e4                  moveq #$e4, d0
  003bc0:  d0 6d f2 24            add.w -$ddc(a5), d0
  003bc4:  3f 00                  move.w d0, -(a7)
  003bc6:  42 67                  clr.w -(a7)
  003bc8:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003bcc:  2f 3c 00 06 00 92      move.l #$60092, -(a7)
  003bd2:  4e ba 07 a6            jsr $437a(pc)
  003bd6:  4f ef 00 0a            lea.l $a(a7), a7
  003bda:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  003bde:  4e 75                  rts 
  003be0:  fe 2c                  dc.w $fe2c
  003be2:  fe 6a                  dc.w $fe6a
  003be4:  ff 84                  dc.w $ff84
  003be6:  ff 84                  dc.w $ff84
  003be8:  ff 84                  dc.w $ff84
  003bea:  ff 84                  dc.w $ff84
  003bec:  ff 84                  dc.w $ff84
  003bee:  ff 02                  dc.w $ff02
  003bf0:  ff 84                  dc.w $ff84
  003bf2:  ff 84                  dc.w $ff84
  003bf4:  ff 84                  dc.w $ff84
  003bf6:  ff 84                  dc.w $ff84
  003bf8:  ff 02                  dc.w $ff02
  003bfa:  ff 84                  dc.w $ff84
  003bfc:  ff 84                  dc.w $ff84
  003bfe:  ff 84                  dc.w $ff84
  003c00:  ff 84                  dc.w $ff84
  003c02:  ff 84                  dc.w $ff84
  003c04:  ff 84                  dc.w $ff84
  003c06:  ff 84                  dc.w $ff84
  003c08:  ff 3a                  dc.w $ff3a
  003c0a:  48 e7 03 00            movem.l d6-d7, -(a7)
  003c0e:  70 00                  moveq #$0, d0
  003c10:  10 2d ba 96            move.b -$456a(a5), d0
  003c14:  0c 40 00 1e            cmpi.w #$1e, d0
  003c18:  62 00 00 b6            bhi.w $3cd0
  003c1c:  43 fa 00 b8            lea.l $3cd6(pc), a1
  003c20:  d0 40                  add.w d0, d0
  003c22:  d2 f1 00 00            adda.w (a1, d0.w), a1
  003c26:  4e d1                  jmp (a1)
  003c28:  70 f9                  moveq #$f9, d0
  003c2a:  d0 6d f2 26            add.w -$dda(a5), d0
  003c2e:  3f 00                  move.w d0, -(a7)
  003c30:  42 67                  clr.w -(a7)
  003c32:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003c36:  1f 2d ba 97            move.b -$4569(a5), -(a7)
  003c3a:  4e ba 06 9a            jsr $42d6(pc)
  003c3e:  20 4d                  movea.l a5, a0
  003c40:  d0 c0                  adda.w d0, a0
  003c42:  70 00                  moveq #$0, d0
  003c44:  10 28 b5 ce            move.b -$4a32(a0), d0
  003c48:  3e 80                  move.w d0, (a7)
  003c4a:  3f 3c 00 06            move.w #$6, -(a7)
  003c4e:  4e ba 07 2a            jsr $437a(pc)
  003c52:  4f ef 00 0a            lea.l $a(a7), a7
  003c56:  60 78                  bra.b $3cd0
  003c58:  4e ba 0e a4            jsr $4afe(pc)
  003c5c:  60 72                  bra.b $3cd0
  003c5e:  0c 2d 00 09 ba 97      cmpi.b #$9, -$4569(a5)
  003c64:  64 6a                  bcc.b $3cd0
  003c66:  7e 00                  moveq #$0, d7
  003c68:  7c d8                  moveq #$d8, d6
  003c6a:  dc 6d f2 26            add.w -$dda(a5), d6
  003c6e:  4a 2d b9 44            tst.b -$46bc(a5)
  003c72:  67 04                  beq.b $3c78
  003c74:  52 47                  addq.w #$1, d7
  003c76:  55 46                  subq.w #$2, d6
  003c78:  3f 06                  move.w d6, -(a7)
  003c7a:  3f 07                  move.w d7, -(a7)
  003c7c:  70 01                  moveq #$1, d0
  003c7e:  d0 6d f2 22            add.w -$dde(a5), d0
  003c82:  3f 00                  move.w d0, -(a7)
  003c84:  70 00                  moveq #$0, d0
  003c86:  10 2d ba 97            move.b -$4569(a5), d0
  003c8a:  52 40                  addq.w #$1, d0
  003c8c:  3f 00                  move.w d0, -(a7)
  003c8e:  3f 3c 00 01            move.w #$1, -(a7)
  003c92:  4e ba 06 e6            jsr $437a(pc)
  003c96:  4f ef 00 0a            lea.l $a(a7), a7
  003c9a:  60 34                  bra.b $3cd0
  003c9c:  4e ba 13 f8            jsr $5096(pc)
  003ca0:  60 2e                  bra.b $3cd0
  003ca2:  70 ff                  moveq #$ff, d0
  003ca4:  d0 6d f2 24            add.w -$ddc(a5), d0
  003ca8:  3f 00                  move.w d0, -(a7)
  003caa:  42 67                  clr.w -(a7)
  003cac:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003cb0:  1f 2d ba 97            move.b -$4569(a5), -(a7)
  003cb4:  4e ba 05 fa            jsr $42b0(pc)
  003cb8:  20 4d                  movea.l a5, a0
  003cba:  d0 c0                  adda.w d0, a0
  003cbc:  70 00                  moveq #$0, d0
  003cbe:  10 28 b5 80            move.b -$4a80(a0), d0
  003cc2:  3e 80                  move.w d0, (a7)
  003cc4:  3f 3c 00 06            move.w #$6, -(a7)
  003cc8:  4e ba 06 b0            jsr $437a(pc)
  003ccc:  4f ef 00 0a            lea.l $a(a7), a7
  003cd0:  4c df 00 c0            movem.l (a7)+, d6-d7
  003cd4:  4e 75                  rts 
  003cd6:  ff fa                  dc.w $fffa
  003cd8:  ff fa                  dc.w $fffa
  003cda:  ff 52                  dc.w $ff52
  003cdc:  ff fa                  dc.w $fffa
  003cde:  ff 82                  dc.w $ff82
  003ce0:  ff fa                  dc.w $fffa
  003ce2:  ff fa                  dc.w $fffa
  003ce4:  ff fa                  dc.w $fffa
  003ce6:  ff fa                  dc.w $fffa
  003ce8:  ff fa                  dc.w $fffa
  003cea:  ff fa                  dc.w $fffa
  003cec:  ff cc                  dc.w $ffcc
  003cee:  ff fa                  dc.w $fffa
  003cf0:  ff fa                  dc.w $fffa
  003cf2:  ff fa                  dc.w $fffa
  003cf4:  ff fa                  dc.w $fffa
  003cf6:  ff c6                  dc.w $ffc6
  003cf8:  ff fa                  dc.w $fffa
  003cfa:  ff fa                  dc.w $fffa
  003cfc:  ff 88                  dc.w $ff88
  003cfe:  ff fa                  dc.w $fffa
  003d00:  ff fa                  dc.w $fffa
  003d02:  ff fa                  dc.w $fffa
  003d04:  ff fa                  dc.w $fffa
  003d06:  ff fa                  dc.w $fffa
  003d08:  ff fa                  dc.w $fffa
  003d0a:  ff fa                  dc.w $fffa
  003d0c:  ff fa                  dc.w $fffa
  003d0e:  ff fa                  dc.w $fffa
  003d10:  ff fa                  dc.w $fffa
  003d12:  ff 88                  dc.w $ff88
  003d14:  4e 56 00 00            link.w a6, #$0
  003d18:  48 e7 07 00            movem.l d5-d7, -(a7)
  003d1c:  3a 2e 00 08            move.w $8(a6), d5
  003d20:  7e 00                  moveq #$0, d7
  003d22:  7c 06                  moveq #$6, d6
  003d24:  10 2d ba 94            move.b -$456c(a5), d0
  003d28:  6b 30                  bmi.b $3d5a
  003d2a:  04 00 00 14            subi.b #$14, d0
  003d2e:  67 08                  beq.b $3d38
  003d30:  6a 28                  bpl.b $3d5a
  003d32:  50 00                  addq.b #$8, d0
  003d34:  67 24                  beq.b $3d5a
  003d36:  60 22                  bra.b $3d5a
  003d38:  7c 07                  moveq #$7, d6
  003d3a:  4a 2d b9 44            tst.b -$46bc(a5)
  003d3e:  67 04                  beq.b $3d44
  003d40:  7e 03                  moveq #$3, d7
  003d42:  60 2a                  bra.b $3d6e
  003d44:  70 00                  moveq #$0, d0
  003d46:  10 2d ba 95            move.b -$456b(a5), d0
  003d4a:  02 40 00 7f            andi.w #$7f, d0
  003d4e:  20 4d                  movea.l a5, a0
  003d50:  d0 c0                  adda.w d0, a0
  003d52:  7e 00                  moveq #$0, d7
  003d54:  1e 28 b6 36            move.b -$49ca(a0), d7
  003d58:  60 14                  bra.b $3d6e
  003d5a:  70 00                  moveq #$0, d0
  003d5c:  10 2d ba 94            move.b -$456c(a5), d0
  003d60:  c1 fc 00 0c            muls.w #$c, d0
  003d64:  20 4d                  movea.l a5, a0
  003d66:  d1 c0                  adda.l d0, a0
  003d68:  7e 00                  moveq #$0, d7
  003d6a:  1e 28 b4 08            move.b -$4bf8(a0), d7
  003d6e:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  003d72:  42 67                  clr.w -(a7)
  003d74:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003d78:  3f 07                  move.w d7, -(a7)
  003d7a:  3f 06                  move.w d6, -(a7)
  003d7c:  20 6d bd 70            movea.l -$4290(a5), a0
  003d80:  4e 90                  jsr (a0)
  003d82:  4a 45                  tst.w d5
  003d84:  4f ef 00 0a            lea.l $a(a7), a7
  003d88:  67 16                  beq.b $3da0
  003d8a:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  003d8e:  42 67                  clr.w -(a7)
  003d90:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003d94:  3f 07                  move.w d7, -(a7)
  003d96:  3f 06                  move.w d6, -(a7)
  003d98:  4e ba 06 e0            jsr $447a(pc)
  003d9c:  4f ef 00 0a            lea.l $a(a7), a7
  003da0:  0c 46 00 07            cmpi.w #$7, d6
  003da4:  66 10                  bne.b $3db6
  003da6:  4a 2d b9 44            tst.b -$46bc(a5)
  003daa:  67 06                  beq.b $3db2
  003dac:  4e ba 1e d2            jsr $5c80(pc)
  003db0:  60 04                  bra.b $3db6
  003db2:  4e ba 1e 94            jsr $5c48(pc)
  003db6:  4c df 00 e0            movem.l (a7)+, d5-d7
  003dba:  4e 5e                  unlk a6
  003dbc:  4e 75                  rts 
  003dbe:  4e 56 00 00            link.w a6, #$0
  003dc2:  48 e7 03 00            movem.l d6-d7, -(a7)
  003dc6:  3e 2e 00 08            move.w $8(a6), d7
  003dca:  0c 2d 00 0b ba 94      cmpi.b #$b, -$456c(a5)
  003dd0:  66 3e                  bne.b $3e10
  003dd2:  1f 2d ba 95            move.b -$456b(a5), -(a7)
  003dd6:  4e ba 04 d8            jsr $42b0(pc)
  003dda:  20 4d                  movea.l a5, a0
  003ddc:  d0 c0                  adda.w d0, a0
  003dde:  7c 00                  moveq #$0, d6
  003de0:  1c 28 b5 8c            move.b -$4a74(a0), d6
  003de4:  3e ad f2 24            move.w -$ddc(a5), (a7)
  003de8:  42 67                  clr.w -(a7)
  003dea:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003dee:  3f 06                  move.w d6, -(a7)
  003df0:  3f 3c 00 06            move.w #$6, -(a7)
  003df4:  4e ba 05 84            jsr $437a(pc)
  003df8:  3e ad f2 24            move.w -$ddc(a5), (a7)
  003dfc:  42 67                  clr.w -(a7)
  003dfe:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003e02:  3f 06                  move.w d6, -(a7)
  003e04:  3f 3c 00 06            move.w #$6, -(a7)
  003e08:  4e ba 06 70            jsr $447a(pc)
  003e0c:  4f ef 00 12            lea.l $12(a7), a7
  003e10:  4c df 00 c0            movem.l (a7)+, d6-d7
  003e14:  4e 5e                  unlk a6
  003e16:  4e 75                  rts 
  003e18:  48 e7 03 00            movem.l d6-d7, -(a7)
  003e1c:  3e 2d f2 26            move.w -$dda(a5), d7
  003e20:  0c 2d 00 1a ba 96      cmpi.b #$1a, -$456a(a5)
  003e26:  66 0e                  bne.b $3e36
  003e28:  0c 2d 00 0c ba 94      cmpi.b #$c, -$456c(a5)
  003e2e:  66 06                  bne.b $3e36
  003e30:  7c 06                  moveq #$6, d6
  003e32:  56 47                  addq.w #$3, d7
  003e34:  60 46                  bra.b $3e7c
  003e36:  0c 2d 00 0b ba 94      cmpi.b #$b, -$456c(a5)
  003e3c:  66 16                  bne.b $3e54
  003e3e:  1f 2d ba 95            move.b -$456b(a5), -(a7)
  003e42:  4e ba 04 6c            jsr $42b0(pc)
  003e46:  20 4d                  movea.l a5, a0
  003e48:  d0 c0                  adda.w d0, a0
  003e4a:  7c 00                  moveq #$0, d6
  003e4c:  1c 28 b5 74            move.b -$4a8c(a0), d6
  003e50:  54 8f                  addq.l #$2, a7
  003e52:  60 28                  bra.b $3e7c
  003e54:  0c 2d 00 0f ba 94      cmpi.b #$f, -$456c(a5)
  003e5a:  66 0c                  bne.b $3e68
  003e5c:  4a 2d ba 96            tst.b -$456a(a5)
  003e60:  66 06                  bne.b $3e68
  003e62:  3c 3c 00 94            move.w #$94, d6
  003e66:  60 14                  bra.b $3e7c
  003e68:  70 00                  moveq #$0, d0
  003e6a:  10 2d ba 94            move.b -$456c(a5), d0
  003e6e:  c1 fc 00 0c            muls.w #$c, d0
  003e72:  20 4d                  movea.l a5, a0
  003e74:  d1 c0                  adda.l d0, a0
  003e76:  7c 00                  moveq #$0, d6
  003e78:  1c 28 b4 00            move.b -$4c00(a0), d6
  003e7c:  70 00                  moveq #$0, d0
  003e7e:  10 2d ba 94            move.b -$456c(a5), d0
  003e82:  c1 fc 00 0c            muls.w #$c, d0
  003e86:  20 4d                  movea.l a5, a0
  003e88:  d1 c0                  adda.l d0, a0
  003e8a:  10 28 b4 02            move.b -$4bfe(a0), d0
  003e8e:  48 80                  ext.w d0
  003e90:  d0 47                  add.w d7, d0
  003e92:  3f 00                  move.w d0, -(a7)
  003e94:  42 67                  clr.w -(a7)
  003e96:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003e9a:  3f 06                  move.w d6, -(a7)
  003e9c:  3f 3c 00 06            move.w #$6, -(a7)
  003ea0:  20 6d bd 70            movea.l -$4290(a5), a0
  003ea4:  4e 90                  jsr (a0)
  003ea6:  4f ef 00 0a            lea.l $a(a7), a7
  003eaa:  4c df 00 c0            movem.l (a7)+, d6-d7
  003eae:  4e 75                  rts 
  003eb0:  48 e7 03 00            movem.l d6-d7, -(a7)
  003eb4:  70 00                  moveq #$0, d0
  003eb6:  10 2d ba 94            move.b -$456c(a5), d0
  003eba:  0c 40 00 16            cmpi.w #$16, d0
  003ebe:  62 00 01 56            bhi.w $4016
  003ec2:  43 fa 01 58            lea.l $401c(pc), a1
  003ec6:  d0 40                  add.w d0, d0
  003ec8:  d2 f1 00 00            adda.w (a1, d0.w), a1
  003ecc:  4e d1                  jmp (a1)
  003ece:  70 fe                  moveq #$fe, d0
  003ed0:  d0 6d f2 26            add.w -$dda(a5), d0
  003ed4:  3f 00                  move.w d0, -(a7)
  003ed6:  42 67                  clr.w -(a7)
  003ed8:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003edc:  1f 2d ba 95            move.b -$456b(a5), -(a7)
  003ee0:  4e ba 03 f4            jsr $42d6(pc)
  003ee4:  20 4d                  movea.l a5, a0
  003ee6:  d0 c0                  adda.w d0, a0
  003ee8:  70 00                  moveq #$0, d0
  003eea:  10 28 b5 c4            move.b -$4a3c(a0), d0
  003eee:  3e 80                  move.w d0, (a7)
  003ef0:  3f 3c 00 06            move.w #$6, -(a7)
  003ef4:  20 6d bd 70            movea.l -$4290(a5), a0
  003ef8:  4e 90                  jsr (a0)
  003efa:  4f ef 00 0a            lea.l $a(a7), a7
  003efe:  60 00 01 16            bra.w $4016
  003f02:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  003f06:  70 f2                  moveq #$f2, d0
  003f08:  d0 6d f2 26            add.w -$dda(a5), d0
  003f0c:  3f 00                  move.w d0, -(a7)
  003f0e:  3f 3c 00 01            move.w #$1, -(a7)
  003f12:  70 03                  moveq #$3, d0
  003f14:  d0 6d f2 22            add.w -$dde(a5), d0
  003f18:  3f 00                  move.w d0, -(a7)
  003f1a:  1f 2d ba 95            move.b -$456b(a5), -(a7)
  003f1e:  4e ba 03 d8            jsr $42f8(pc)
  003f22:  3e 80                  move.w d0, (a7)
  003f24:  3f 3c 00 01            move.w #$1, -(a7)
  003f28:  4e ba 04 ae            jsr $43d8(pc)
  003f2c:  4f ef 00 0a            lea.l $a(a7), a7
  003f30:  60 00 00 e4            bra.w $4016
  003f34:  0c 2d 00 01 ba 95      cmpi.b #$1, -$456b(a5)
  003f3a:  66 24                  bne.b $3f60
  003f3c:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  003f40:  70 fd                  moveq #$fd, d0
  003f42:  d0 6d f2 26            add.w -$dda(a5), d0
  003f46:  3f 00                  move.w d0, -(a7)
  003f48:  42 67                  clr.w -(a7)
  003f4a:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003f4e:  2f 3c 00 01 00 0b      move.l #$1000b, -(a7)
  003f54:  4e ba 04 82            jsr $43d8(pc)
  003f58:  4f ef 00 0a            lea.l $a(a7), a7
  003f5c:  60 00 00 b8            bra.w $4016
  003f60:  70 fd                  moveq #$fd, d0
  003f62:  d0 6d f2 26            add.w -$dda(a5), d0
  003f66:  3f 00                  move.w d0, -(a7)
  003f68:  42 67                  clr.w -(a7)
  003f6a:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003f6e:  2f 3c 00 01 00 0a      move.l #$1000a, -(a7)
  003f74:  4e ba 04 62            jsr $43d8(pc)
  003f78:  4f ef 00 0a            lea.l $a(a7), a7
  003f7c:  60 00 00 98            bra.w $4016
  003f80:  7e 00                  moveq #$0, d7
  003f82:  1e 2d ba 95            move.b -$456b(a5), d7
  003f86:  02 47 00 7f            andi.w #$7f, d7
  003f8a:  0c 47 00 06            cmpi.w #$6, d7
  003f8e:  6f 02                  ble.b $3f92
  003f90:  7e 06                  moveq #$6, d7
  003f92:  20 4d                  movea.l a5, a0
  003f94:  d0 c7                  adda.w d7, a0
  003f96:  7c 00                  moveq #$0, d6
  003f98:  1c 28 b5 a4            move.b -$4a5c(a0), d6
  003f9c:  3f 2d f2 26            move.w -$dda(a5), -(a7)
  003fa0:  42 67                  clr.w -(a7)
  003fa2:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003fa6:  20 4d                  movea.l a5, a0
  003fa8:  d0 c6                  adda.w d6, a0
  003faa:  70 00                  moveq #$0, d0
  003fac:  10 28 b5 b2            move.b -$4a4e(a0), d0
  003fb0:  3f 00                  move.w d0, -(a7)
  003fb2:  3f 3c 00 06            move.w #$6, -(a7)
  003fb6:  4e ba 03 c2            jsr $437a(pc)
  003fba:  20 4d                  movea.l a5, a0
  003fbc:  d0 c6                  adda.w d6, a0
  003fbe:  10 28 b5 b8            move.b -$4a48(a0), d0
  003fc2:  48 80                  ext.w d0
  003fc4:  32 2d f2 26            move.w -$dda(a5), d1
  003fc8:  92 40                  sub.w d0, d1
  003fca:  3e 81                  move.w d1, (a7)
  003fcc:  42 67                  clr.w -(a7)
  003fce:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  003fd2:  20 4d                  movea.l a5, a0
  003fd4:  d0 c6                  adda.w d6, a0
  003fd6:  70 00                  moveq #$0, d0
  003fd8:  10 28 b5 ac            move.b -$4a54(a0), d0
  003fdc:  3f 00                  move.w d0, -(a7)
  003fde:  3f 3c 00 06            move.w #$6, -(a7)
  003fe2:  4e ba 03 96            jsr $437a(pc)
  003fe6:  4a 2d ba 95            tst.b -$456b(a5)
  003fea:  4f ef 00 12            lea.l $12(a7), a7
  003fee:  6a 26                  bpl.b $4016
  003ff0:  70 fa                  moveq #$fa, d0
  003ff2:  d0 6d f2 26            add.w -$dda(a5), d0
  003ff6:  3f 00                  move.w d0, -(a7)
  003ff8:  3f 3c 00 04            move.w #$4, -(a7)
  003ffc:  70 01                  moveq #$1, d0
  003ffe:  d0 6d f2 22            add.w -$dde(a5), d0
  004002:  3f 00                  move.w d0, -(a7)
  004004:  70 72                  moveq #$72, d0
  004006:  d0 46                  add.w d6, d0
  004008:  3f 00                  move.w d0, -(a7)
  00400a:  3f 3c 00 06            move.w #$6, -(a7)
  00400e:  4e ba 03 6a            jsr $437a(pc)
  004012:  4f ef 00 0a            lea.l $a(a7), a7
  004016:  4c df 00 c0            movem.l (a7)+, d6-d7
  00401a:  4e 75                  rts 
  00401c:  ff fa                  dc.w $fffa
  00401e:  ff fa                  dc.w $fffa
  004020:  fe b2                  dc.w $feb2
  004022:  ff fa                  dc.w $fffa
  004024:  ff fa                  dc.w $fffa
  004026:  ff fa                  dc.w $fffa
  004028:  ff fa                  dc.w $fffa
  00402a:  ff fa                  dc.w $fffa
  00402c:  ff fa                  dc.w $fffa
  00402e:  ff fa                  dc.w $fffa
  004030:  fe e6                  dc.w $fee6
  004032:  ff fa                  dc.w $fffa
  004034:  ff fa                  dc.w $fffa
  004036:  ff fa                  dc.w $fffa
  004038:  ff fa                  dc.w $fffa
  00403a:  ff fa                  dc.w $fffa
  00403c:  ff fa                  dc.w $fffa
  00403e:  ff fa                  dc.w $fffa
  004040:  ff 64                  dc.w $ff64
  004042:  ff fa                  dc.w $fffa
  004044:  ff fa                  dc.w $fffa
  004046:  ff fa                  dc.w $fffa
  004048:  ff 18                  dc.w $ff18
  00404a:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  00404e:  0c 2d 00 04 ba 96      cmpi.b #$4, -$456a(a5)
  004054:  66 2c                  bne.b $4082
  004056:  10 2d b9 6f            move.b -$4691(a5), d0
  00405a:  48 80                  ext.w d0
  00405c:  b0 6d f2 1e            cmp.w -$de2(a5), d0
  004060:  66 20                  bne.b $4082
  004062:  10 2d b9 6e            move.b -$4692(a5), d0
  004066:  48 80                  ext.w d0
  004068:  72 ff                  moveq #$ff, d1
  00406a:  d2 6d f2 20            add.w -$de0(a5), d1
  00406e:  b2 40                  cmp.w d0, d1
  004070:  66 10                  bne.b $4082
  004072:  10 2d b9 73            move.b -$468d(a5), d0
  004076:  48 80                  ext.w d0
  004078:  b0 6d ba 6e            cmp.w -$4592(a5), d0
  00407c:  67 04                  beq.b $4082
  00407e:  4e ba 0b dc            jsr $4c5c(pc)
  004082:  70 00                  moveq #$0, d0
  004084:  10 2d ba 94            move.b -$456c(a5), d0
  004088:  c1 fc 00 0c            muls.w #$c, d0
  00408c:  49 ed b4 00            lea.l -$4c00(a5), a4
  004090:  d0 8c                  add.l a4, d0
  004092:  28 40                  movea.l d0, a4
  004094:  7e 00                  moveq #$0, d7
  004096:  1e 2c 00 09            move.b $9(a4), d7
  00409a:  10 2c 00 0a            move.b $a(a4), d0
  00409e:  48 80                  ext.w d0
  0040a0:  d0 6d f2 22            add.w -$dde(a5), d0
  0040a4:  3c 00                  move.w d0, d6
  0040a6:  10 2c 00 0b            move.b $b(a4), d0
  0040aa:  48 80                  ext.w d0
  0040ac:  d0 6d f2 26            add.w -$dda(a5), d0
  0040b0:  3a 00                  move.w d0, d5
  0040b2:  70 00                  moveq #$0, d0
  0040b4:  10 2d ba 94            move.b -$456c(a5), d0
  0040b8:  0c 40 00 14            cmpi.w #$14, d0
  0040bc:  62 00 01 66            bhi.w $4224
  0040c0:  43 fa 01 80            lea.l $4242(pc), a1
  0040c4:  d0 40                  add.w d0, d0
  0040c6:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0040ca:  4e d1                  jmp (a1)
  0040cc:  78 00                  moveq #$0, d4
  0040ce:  18 2d ba 95            move.b -$456b(a5), d4
  0040d2:  02 44 00 7f            andi.w #$7f, d4
  0040d6:  0c 44 00 06            cmpi.w #$6, d4
  0040da:  6f 02                  ble.b $40de
  0040dc:  78 06                  moveq #$6, d4
  0040de:  20 4d                  movea.l a5, a0
  0040e0:  d0 c4                  adda.w d4, a0
  0040e2:  7e 00                  moveq #$0, d7
  0040e4:  1e 28 b5 a4            move.b -$4a5c(a0), d7
  0040e8:  3f 2d f2 26            move.w -$dda(a5), -(a7)
  0040ec:  42 67                  clr.w -(a7)
  0040ee:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  0040f2:  20 4d                  movea.l a5, a0
  0040f4:  d0 c7                  adda.w d7, a0
  0040f6:  70 00                  moveq #$0, d0
  0040f8:  10 28 b5 be            move.b -$4a42(a0), d0
  0040fc:  3f 00                  move.w d0, -(a7)
  0040fe:  3f 3c 00 06            move.w #$6, -(a7)
  004102:  4e ba 03 76            jsr $447a(pc)
  004106:  4a 2d ba 95            tst.b -$456b(a5)
  00410a:  4f ef 00 0a            lea.l $a(a7), a7
  00410e:  6a 00 01 2c            bpl.w $423c
  004112:  70 fa                  moveq #$fa, d0
  004114:  d0 6d f2 26            add.w -$dda(a5), d0
  004118:  3f 00                  move.w d0, -(a7)
  00411a:  3f 3c 00 04            move.w #$4, -(a7)
  00411e:  70 01                  moveq #$1, d0
  004120:  d0 6d f2 22            add.w -$dde(a5), d0
  004124:  3f 00                  move.w d0, -(a7)
  004126:  70 77                  moveq #$77, d0
  004128:  d0 47                  add.w d7, d0
  00412a:  3f 00                  move.w d0, -(a7)
  00412c:  3f 3c 00 06            move.w #$6, -(a7)
  004130:  4e ba 03 48            jsr $447a(pc)
  004134:  4f ef 00 0a            lea.l $a(a7), a7
  004138:  60 00 01 02            bra.w $423c
  00413c:  4e ba 01 2e            jsr $426c(pc)
  004140:  20 4d                  movea.l a5, a0
  004142:  d0 c0                  adda.w d0, a0
  004144:  d0 c0                  adda.w d0, a0
  004146:  3b 68 99 14 bd 78      move.w -$66ec(a0), -$4288(a5)
  00414c:  70 fe                  moveq #$fe, d0
  00414e:  d0 6d f2 26            add.w -$dda(a5), d0
  004152:  3f 00                  move.w d0, -(a7)
  004154:  42 67                  clr.w -(a7)
  004156:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  00415a:  1f 2d ba 95            move.b -$456b(a5), -(a7)
  00415e:  4e ba 01 76            jsr $42d6(pc)
  004162:  20 4d                  movea.l a5, a0
  004164:  d0 c0                  adda.w d0, a0
  004166:  70 00                  moveq #$0, d0
  004168:  10 28 b5 d8            move.b -$4a28(a0), d0
  00416c:  3e 80                  move.w d0, (a7)
  00416e:  3f 3c 00 06            move.w #$6, -(a7)
  004172:  4e ba 03 06            jsr $447a(pc)
  004176:  4f ef 00 0a            lea.l $a(a7), a7
  00417a:  60 00 00 c0            bra.w $423c
  00417e:  4e ba 00 ec            jsr $426c(pc)
  004182:  20 4d                  movea.l a5, a0
  004184:  d0 c0                  adda.w d0, a0
  004186:  d0 c0                  adda.w d0, a0
  004188:  3b 68 99 14 bd 78      move.w -$66ec(a0), -$4288(a5)
  00418e:  3f 05                  move.w d5, -(a7)
  004190:  42 67                  clr.w -(a7)
  004192:  3f 06                  move.w d6, -(a7)
  004194:  3f 07                  move.w d7, -(a7)
  004196:  3f 3c 00 06            move.w #$6, -(a7)
  00419a:  4e ba 02 de            jsr $447a(pc)
  00419e:  4f ef 00 0a            lea.l $a(a7), a7
  0041a2:  60 00 00 98            bra.w $423c
  0041a6:  4a 2d b9 44            tst.b -$46bc(a5)
  0041aa:  67 08                  beq.b $41b4
  0041ac:  4e ba 1a d0            jsr $5c7e(pc)
  0041b0:  60 00 00 8a            bra.w $423c
  0041b4:  4e ba 1a 64            jsr $5c1a(pc)
  0041b8:  60 00 00 82            bra.w $423c
  0041bc:  78 00                  moveq #$0, d4
  0041be:  18 2d ba 95            move.b -$456b(a5), d4
  0041c2:  02 44 00 e0            andi.w #$e0, d4
  0041c6:  4a 2d b9 44            tst.b -$46bc(a5)
  0041ca:  67 02                  beq.b $41ce
  0041cc:  54 47                  addq.w #$2, d7
  0041ce:  0c 44 00 40            cmpi.w #$40, d4
  0041d2:  66 02                  bne.b $41d6
  0041d4:  52 47                  addq.w #$1, d7
  0041d6:  3f 05                  move.w d5, -(a7)
  0041d8:  3f 3c 00 06            move.w #$6, -(a7)
  0041dc:  3f 06                  move.w d6, -(a7)
  0041de:  3f 07                  move.w d7, -(a7)
  0041e0:  3f 3c 00 01            move.w #$1, -(a7)
  0041e4:  4e ba 02 94            jsr $447a(pc)
  0041e8:  4e ba 00 82            jsr $426c(pc)
  0041ec:  20 4d                  movea.l a5, a0
  0041ee:  d0 c0                  adda.w d0, a0
  0041f0:  d0 c0                  adda.w d0, a0
  0041f2:  3b 68 99 14 bd 78      move.w -$66ec(a0), -$4288(a5)
  0041f8:  70 f2                  moveq #$f2, d0
  0041fa:  d0 6d f2 26            add.w -$dda(a5), d0
  0041fe:  3e 80                  move.w d0, (a7)
  004200:  3f 3c 00 01            move.w #$1, -(a7)
  004204:  70 03                  moveq #$3, d0
  004206:  d0 6d f2 22            add.w -$dde(a5), d0
  00420a:  3f 00                  move.w d0, -(a7)
  00420c:  1f 2d ba 95            move.b -$456b(a5), -(a7)
  004210:  4e ba 00 e6            jsr $42f8(pc)
  004214:  3e 80                  move.w d0, (a7)
  004216:  3f 3c 00 01            move.w #$1, -(a7)
  00421a:  4e ba 02 5e            jsr $447a(pc)
  00421e:  4f ef 00 12            lea.l $12(a7), a7
  004222:  60 18                  bra.b $423c
  004224:  4a 47                  tst.w d7
  004226:  67 14                  beq.b $423c
  004228:  3f 05                  move.w d5, -(a7)
  00422a:  42 67                  clr.w -(a7)
  00422c:  3f 06                  move.w d6, -(a7)
  00422e:  3f 07                  move.w d7, -(a7)
  004230:  3f 3c 00 06            move.w #$6, -(a7)
  004234:  4e ba 02 44            jsr $447a(pc)
  004238:  4f ef 00 0a            lea.l $a(a7), a7
  00423c:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  004240:  4e 75                  rts 
  004242:  ff e2                  dc.w $ffe2
  004244:  ff e2                  dc.w $ffe2
  004246:  fe fa                  dc.w $fefa
  004248:  ff e2                  dc.w $ffe2
  00424a:  ff e2                  dc.w $ffe2
  00424c:  ff e2                  dc.w $ffe2
  00424e:  ff e2                  dc.w $ffe2
  004250:  ff e2                  dc.w $ffe2
  004252:  ff e2                  dc.w $ffe2
  004254:  ff e2                  dc.w $ffe2
  004256:  ff 7a                  dc.w $ff7a
  004258:  ff e2                  dc.w $ffe2
  00425a:  ff e2                  dc.w $ffe2
  00425c:  ff e2                  dc.w $ffe2
  00425e:  ff 3c                  dc.w $ff3c
  004260:  ff e2                  dc.w $ffe2
  004262:  ff e2                  dc.w $ffe2
  004264:  ff e2                  dc.w $ffe2
  004266:  fe 8a                  dc.w $fe8a
  004268:  ff e2                  dc.w $ffe2
  00426a:  ff 64                  dc.w $ff64
  00426c:  48 e7 07 00            movem.l d5-d7, -(a7)
  004270:  7e 01                  moveq #$1, d7
  004272:  de 6d f2 20            add.w -$de0(a5), d7
  004276:  0c 47 00 0a            cmpi.w #$a, d7
  00427a:  6c 2a                  bge.b $42a6
  00427c:  30 2d f2 1e            move.w -$de2(a5), d0
  004280:  20 4d                  movea.l a5, a0
  004282:  d0 c0                  adda.w d0, a0
  004284:  d0 c0                  adda.w d0, a0
  004286:  3c 28 b6 46            move.w -$49ba(a0), d6
  00428a:  dc 47                  add.w d7, d6
  00428c:  20 6d bd 82            movea.l -$427e(a5), a0
  004290:  7a 00                  moveq #$0, d5
  004292:  1a 30 60 00            move.b (a0, d6.w), d5
  004296:  02 45 00 1f            andi.w #$1f, d5
  00429a:  0c 45 00 14            cmpi.w #$14, d5
  00429e:  66 06                  bne.b $42a6
  0042a0:  30 07                  move.w d7, d0
  0042a2:  eb 48                  lsl.w #$5, d0
  0042a4:  60 04                  bra.b $42aa
  0042a6:  30 3c 01 40            move.w #$140, d0
  0042aa:  4c df 00 e0            movem.l (a7)+, d5-d7
  0042ae:  4e 75                  rts 
  0042b0:  4e 56 00 00            link.w a6, #$0
  0042b4:  2f 07                  move.l d7, -(a7)
  0042b6:  1e 2e 00 08            move.b $8(a6), d7
  0042ba:  4a 07                  tst.b d7
  0042bc:  6a 0e                  bpl.b $42cc
  0042be:  02 07 00 7f            andi.b #$7f, d7
  0042c2:  0c 07 00 0a            cmpi.b #$a, d7
  0042c6:  63 04                  bls.b $42cc
  0042c8:  70 01                  moveq #$1, d0
  0042ca:  60 04                  bra.b $42d0
  0042cc:  70 00                  moveq #$0, d0
  0042ce:  10 07                  move.b d7, d0
  0042d0:  2e 1f                  move.l (a7)+, d7
  0042d2:  4e 5e                  unlk a6
  0042d4:  4e 75                  rts 
  0042d6:  4e 56 00 00            link.w a6, #$0
  0042da:  48 e7 03 00            movem.l d6-d7, -(a7)
  0042de:  1e 2e 00 08            move.b $8(a6), d7
  0042e2:  7c 00                  moveq #$0, d6
  0042e4:  1c 07                  move.b d7, d6
  0042e6:  4a 06                  tst.b d6
  0042e8:  6a 04                  bpl.b $42ee
  0042ea:  70 05                  moveq #$5, d0
  0042ec:  60 02                  bra.b $42f0
  0042ee:  30 06                  move.w d6, d0
  0042f0:  4c df 00 c0            movem.l (a7)+, d6-d7
  0042f4:  4e 5e                  unlk a6
  0042f6:  4e 75                  rts 
  0042f8:  4e 56 00 00            link.w a6, #$0
  0042fc:  48 e7 07 00            movem.l d5-d7, -(a7)
  004300:  1e 2e 00 08            move.b $8(a6), d7
  004304:  7a 00                  moveq #$0, d5
  004306:  1a 07                  move.b d7, d5
  004308:  30 05                  move.w d5, d0
  00430a:  02 40 00 e0            andi.w #$e0, d0
  00430e:  67 32                  beq.b $4342
  004310:  6b 3e                  bmi.b $4350
  004312:  04 40 00 80            subi.w #$80, d0
  004316:  67 32                  beq.b $434a
  004318:  6a 18                  bpl.b $4332
  00431a:  04 40 ff c0            subi.w #$ffc0, d0
  00431e:  67 22                  beq.b $4342
  004320:  6a 08                  bpl.b $432a
  004322:  04 40 ff e0            subi.w #$ffe0, d0
  004326:  67 1e                  beq.b $4346
  004328:  60 26                  bra.b $4350
  00432a:  04 40 00 20            subi.w #$20, d0
  00432e:  67 1a                  beq.b $434a
  004330:  60 1e                  bra.b $4350
  004332:  04 40 00 40            subi.w #$40, d0
  004336:  67 16                  beq.b $434e
  004338:  6a 16                  bpl.b $4350
  00433a:  04 40 ff e0            subi.w #$ffe0, d0
  00433e:  67 0e                  beq.b $434e
  004340:  60 0e                  bra.b $4350
  004342:  7c ff                  moveq #$ff, d6
  004344:  60 0a                  bra.b $4350
  004346:  7c 00                  moveq #$0, d6
  004348:  60 06                  bra.b $4350
  00434a:  7c 06                  moveq #$6, d6
  00434c:  60 02                  bra.b $4350
  00434e:  7c 0c                  moveq #$c, d6
  004350:  7e 00                  moveq #$0, d7
  004352:  4a 46                  tst.w d6
  004354:  6d 1a                  blt.b $4370
  004356:  70 0f                  moveq #$f, d0
  004358:  c0 45                  and.w d5, d0
  00435a:  20 4d                  movea.l a5, a0
  00435c:  d0 c0                  adda.w d0, a0
  00435e:  7e 00                  moveq #$0, d7
  004360:  1e 28 b6 3e            move.b -$49c2(a0), d7
  004364:  4a 47                  tst.w d7
  004366:  67 08                  beq.b $4370
  004368:  4a 2d a2 09            tst.b -$5df7(a5)
  00436c:  67 02                  beq.b $4370
  00436e:  de 46                  add.w d6, d7
  004370:  30 07                  move.w d7, d0
  004372:  4c df 00 e0            movem.l (a7)+, d5-d7
  004376:  4e 5e                  unlk a6
  004378:  4e 75                  rts 
  00437a:  4e 56 00 00            link.w a6, #$0
  00437e:  48 e7 01 08            movem.l d7/a4, -(a7)
  004382:  4a 6e 00 0a            tst.w $a(a6)
  004386:  67 42                  beq.b $43ca
  004388:  3e 2d bd 9c            move.w -$4264(a5), d7
  00438c:  0c 47 00 fa            cmpi.w #$fa, d7
  004390:  6c 3e                  bge.b $43d0
  004392:  70 0a                  moveq #$a, d0
  004394:  c1 c7                  muls.w d7, d0
  004396:  49 ed bd a6            lea.l -$425a(a5), a4
  00439a:  d0 8c                  add.l a4, d0
  00439c:  28 40                  movea.l d0, a4
  00439e:  38 ae 00 08            move.w $8(a6), (a4)
  0043a2:  70 ff                  moveq #$ff, d0
  0043a4:  d0 6e 00 0a            add.w $a(a6), d0
  0043a8:  39 40 00 02            move.w d0, $2(a4)
  0043ac:  30 2e 00 0c            move.w $c(a6), d0
  0043b0:  e7 48                  lsl.w #$3, d0
  0043b2:  d0 6e 00 0e            add.w $e(a6), d0
  0043b6:  39 40 00 04            move.w d0, $4(a4)
  0043ba:  39 6e 00 10 00 06      move.w $10(a6), $6(a4)
  0043c0:  39 6d bd 74 00 08      move.w -$428c(a5), $8(a4)
  0043c6:  52 6d bd 9c            addq.w #$1, -$4264(a5)
  0043ca:  3b 6d a5 cc bd 74      move.w -$5a34(a5), -$428c(a5)
  0043d0:  4c df 10 80            movem.l (a7)+, d7/a4
  0043d4:  4e 5e                  unlk a6
  0043d6:  4e 75                  rts 
  0043d8:  4e 56 00 00            link.w a6, #$0
  0043dc:  48 e7 01 08            movem.l d7/a4, -(a7)
  0043e0:  4a 6e 00 0a            tst.w $a(a6)
  0043e4:  67 00 00 84            beq.w $446a
  0043e8:  3e 2d bd a2            move.w -$425e(a5), d7
  0043ec:  0c 47 00 32            cmpi.w #$32, d7
  0043f0:  6c 00 00 80            bge.w $4472
  0043f4:  70 14                  moveq #$14, d0
  0043f6:  c1 c7                  muls.w d7, d0
  0043f8:  49 ed c7 6a            lea.l -$3896(a5), a4
  0043fc:  d0 8c                  add.l a4, d0
  0043fe:  28 40                  movea.l d0, a4
  004400:  38 ae 00 08            move.w $8(a6), (a4)
  004404:  70 ff                  moveq #$ff, d0
  004406:  d0 6e 00 0a            add.w $a(a6), d0
  00440a:  39 40 00 02            move.w d0, $2(a4)
  00440e:  30 2e 00 0c            move.w $c(a6), d0
  004412:  e7 48                  lsl.w #$3, d0
  004414:  d0 6e 00 0e            add.w $e(a6), d0
  004418:  39 40 00 04            move.w d0, $4(a4)
  00441c:  39 6e 00 10 00 06      move.w $10(a6), $6(a4)
  004422:  4a 2d ba f1            tst.b -$450f(a5)
  004426:  66 14                  bne.b $443c
  004428:  20 4d                  movea.l a5, a0
  00442a:  d0 ee 00 08            adda.w $8(a6), a0
  00442e:  4a 28 b9 2c            tst.b -$46d4(a0)
  004432:  67 08                  beq.b $443c
  004434:  39 7c ff ff 00 08      move.w #$ffff, $8(a4)
  00443a:  60 06                  bra.b $4442
  00443c:  39 7c 00 01 00 08      move.w #$1, $8(a4)
  004442:  19 6d aa 35 00 0a      move.b -$55cb(a5), $a(a4)
  004448:  19 6d aa 36 00 0b      move.b -$55ca(a5), $b(a4)
  00444e:  39 6d ba fe 00 0c      move.w -$4502(a5), $c(a4)
  004454:  39 6d bb 02 00 0e      move.w -$44fe(a5), $e(a4)
  00445a:  39 6d bb 00 00 10      move.w -$4500(a5), $10(a4)
  004460:  39 6d bb 04 00 12      move.w -$44fc(a5), $12(a4)
  004466:  52 6d bd a2            addq.w #$1, -$425e(a5)
  00446a:  42 2d aa 35            clr.b -$55cb(a5)
  00446e:  42 2d aa 36            clr.b -$55ca(a5)
  004472:  4c df 10 80            movem.l (a7)+, d7/a4
  004476:  4e 5e                  unlk a6
  004478:  4e 75                  rts 
  00447a:  4e 56 00 00            link.w a6, #$0
  00447e:  48 e7 01 08            movem.l d7/a4, -(a7)
  004482:  4a 6e 00 0a            tst.w $a(a6)
  004486:  67 48                  beq.b $44d0
  004488:  3e 2d bd 9e            move.w -$4262(a5), d7
  00448c:  0c 47 00 fa            cmpi.w #$fa, d7
  004490:  6c 4a                  bge.b $44dc
  004492:  70 0c                  moveq #$c, d0
  004494:  c1 c7                  muls.w d7, d0
  004496:  49 ed cb 52            lea.l -$34ae(a5), a4
  00449a:  d0 8c                  add.l a4, d0
  00449c:  28 40                  movea.l d0, a4
  00449e:  38 ae 00 08            move.w $8(a6), (a4)
  0044a2:  70 ff                  moveq #$ff, d0
  0044a4:  d0 6e 00 0a            add.w $a(a6), d0
  0044a8:  39 40 00 02            move.w d0, $2(a4)
  0044ac:  30 2e 00 0c            move.w $c(a6), d0
  0044b0:  e7 48                  lsl.w #$3, d0
  0044b2:  d0 6e 00 0e            add.w $e(a6), d0
  0044b6:  39 40 00 04            move.w d0, $4(a4)
  0044ba:  39 6e 00 10 00 06      move.w $10(a6), $6(a4)
  0044c0:  39 6d bd 76 00 08      move.w -$428a(a5), $8(a4)
  0044c6:  39 6d bd 78 00 0a      move.w -$4288(a5), $a(a4)
  0044cc:  52 6d bd 9e            addq.w #$1, -$4262(a5)
  0044d0:  3b 6d a5 cc bd 76      move.w -$5a34(a5), -$428a(a5)
  0044d6:  3b 6d a5 d2 bd 78      move.w -$5a2e(a5), -$4288(a5)
  0044dc:  4c df 10 80            movem.l (a7)+, d7/a4
  0044e0:  4e 5e                  unlk a6
  0044e2:  4e 75                  rts 
  0044e4:  4e 56 00 00            link.w a6, #$0
  0044e8:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  0044ec:  3e 2d e6 aa            move.w -$1956(a5), d7
  0044f0:  0c 47 00 32            cmpi.w #$32, d7
  0044f4:  6c 74                  bge.b $456a
  0044f6:  7c 01                  moveq #$1, d6
  0044f8:  dc 6e 00 0a            add.w $a(a6), d6
  0044fc:  20 4d                  movea.l a5, a0
  0044fe:  30 2e 00 0c            move.w $c(a6), d0
  004502:  d0 c0                  adda.w d0, a0
  004504:  d0 c0                  adda.w d0, a0
  004506:  3a 28 99 14            move.w -$66ec(a0), d5
  00450a:  20 4d                  movea.l a5, a0
  00450c:  32 2e 00 0e            move.w $e(a6), d1
  004510:  d0 c1                  adda.w d1, a0
  004512:  d0 c1                  adda.w d1, a0
  004514:  38 28 9d 12            move.w -$62ee(a0), d4
  004518:  3f 2e 00 10            move.w $10(a6), -(a7)
  00451c:  3f 04                  move.w d4, -(a7)
  00451e:  3f 05                  move.w d5, -(a7)
  004520:  3f 06                  move.w d6, -(a7)
  004522:  3f 2e 00 08            move.w $8(a6), -(a7)
  004526:  4e ad 01 12            jsr $112(a5)
  00452a:  42 17                  clr.b (a7)
  00452c:  48 6d a5 f4            pea.l -$5a0c(a5)
  004530:  48 6d a2 e4            pea.l -$5d1c(a5)
  004534:  48 6d a5 f4            pea.l -$5a0c(a5)
  004538:  a8 aa                  dc.w $a8aa
  00453a:  4a 1f                  tst.b (a7)+
  00453c:  50 8f                  addq.l #$8, a7
  00453e:  67 2a                  beq.b $456a
  004540:  70 0c                  moveq #$c, d0
  004542:  c1 c7                  muls.w d7, d0
  004544:  49 ed e6 ac            lea.l -$1954(a5), a4
  004548:  d0 8c                  add.l a4, d0
  00454a:  28 40                  movea.l d0, a4
  00454c:  28 ad a5 f4            move.l -$5a0c(a5), (a4)
  004550:  29 6d a5 f8 00 04      move.l -$5a08(a5), $4(a4)
  004556:  48 6d a5 f4            pea.l -$5a0c(a5)
  00455a:  20 6d a3 e6            movea.l -$5c1a(a5), a0
  00455e:  4e 90                  jsr (a0)
  004560:  29 40 00 08            move.l d0, $8(a4)
  004564:  52 6d e6 aa            addq.w #$1, -$1956(a5)
  004568:  58 8f                  addq.l #$4, a7
  00456a:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  00456e:  4e 5e                  unlk a6
  004570:  4e 75                  rts 
  004572:  4e 56 00 00            link.w a6, #$0
  004576:  48 e7 01 08            movem.l d7/a4, -(a7)
  00457a:  3e 2d bd a0            move.w -$4260(a5), d7
  00457e:  0c 47 01 2c            cmpi.w #$12c, d7
  004582:  6c 3e                  bge.b $45c2
  004584:  70 0a                  moveq #$a, d0
  004586:  c1 c7                  muls.w d7, d0
  004588:  49 ed d7 0a            lea.l -$28f6(a5), a4
  00458c:  d0 8c                  add.l a4, d0
  00458e:  28 40                  movea.l d0, a4
  004590:  18 ae 00 09            move.b $9(a6), (a4)
  004594:  19 6e 00 13 00 01      move.b $13(a6), $1(a4)
  00459a:  30 2e 00 0a            move.w $a(a6), d0
  00459e:  e7 48                  lsl.w #$3, d0
  0045a0:  39 40 00 02            move.w d0, $2(a4)
  0045a4:  70 01                  moveq #$1, d0
  0045a6:  d0 6e 00 0c            add.w $c(a6), d0
  0045aa:  39 40 00 04            move.w d0, $4(a4)
  0045ae:  30 2e 00 10            move.w $10(a6), d0
  0045b2:  e7 48                  lsl.w #$3, d0
  0045b4:  39 40 00 06            move.w d0, $6(a4)
  0045b8:  39 6e 00 0e 00 08      move.w $e(a6), $8(a4)
  0045be:  52 6d bd a0            addq.w #$1, -$4260(a5)
  0045c2:  4c df 10 80            movem.l (a7)+, d7/a4
  0045c6:  4e 5e                  unlk a6
  0045c8:  4e 75                  rts 
  0045ca:  4e 56 00 00            link.w a6, #$0
  0045ce:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  0045d2:  28 6e 00 08            movea.l $8(a6), a4
  0045d6:  3e 14                  move.w (a4), d7
  0045d8:  3c 2c 00 02            move.w $2(a4), d6
  0045dc:  3a 2c 00 04            move.w $4(a4), d5
  0045e0:  38 2c 00 06            move.w $6(a4), d4
  0045e4:  be 6d a2 e8            cmp.w -$5d18(a5), d7
  0045e8:  6c 00 00 b4            bge.w $469e
  0045ec:  bc 6d a2 ea            cmp.w -$5d16(a5), d6
  0045f0:  6c 00 00 ac            bge.w $469e
  0045f4:  ba 6d a2 e4            cmp.w -$5d1c(a5), d5
  0045f8:  6f 00 00 a4            ble.w $469e
  0045fc:  b8 6d a2 e6            cmp.w -$5d1a(a5), d4
  004600:  6f 00 00 9c            ble.w $469e
  004604:  be 6d a2 e4            cmp.w -$5d1c(a5), d7
  004608:  6c 04                  bge.b $460e
  00460a:  3e 2d a2 e4            move.w -$5d1c(a5), d7
  00460e:  bc 6d a2 e6            cmp.w -$5d1a(a5), d6
  004612:  6c 04                  bge.b $4618
  004614:  3c 2d a2 e6            move.w -$5d1a(a5), d6
  004618:  ba 6d a2 e8            cmp.w -$5d18(a5), d5
  00461c:  6f 04                  ble.b $4622
  00461e:  3a 2d a2 e8            move.w -$5d18(a5), d5
  004622:  b8 6d a2 ea            cmp.w -$5d16(a5), d4
  004626:  6f 04                  ble.b $462c
  004628:  38 2d a2 ea            move.w -$5d16(a5), d4
  00462c:  cc 6d a1 b0            and.w -$5e50(a5), d6
  004630:  d8 6d a1 b2            add.w -$5e4e(a5), d4
  004634:  c8 6d a1 b0            and.w -$5e50(a5), d4
  004638:  49 ed f2 2c            lea.l -$dd4(a5), a4
  00463c:  76 00                  moveq #$0, d3
  00463e:  60 40                  bra.b $4680
  004640:  be 6c 00 04            cmp.w $4(a4), d7
  004644:  6e 36                  bgt.b $467c
  004646:  bc 6c 00 06            cmp.w $6(a4), d6
  00464a:  6e 30                  bgt.b $467c
  00464c:  ba 54                  cmp.w (a4), d5
  00464e:  6d 2c                  blt.b $467c
  004650:  b8 6c 00 02            cmp.w $2(a4), d4
  004654:  6d 26                  blt.b $467c
  004656:  be 54                  cmp.w (a4), d7
  004658:  6c 02                  bge.b $465c
  00465a:  38 87                  move.w d7, (a4)
  00465c:  bc 6c 00 02            cmp.w $2(a4), d6
  004660:  6c 04                  bge.b $4666
  004662:  39 46 00 02            move.w d6, $2(a4)
  004666:  ba 6c 00 04            cmp.w $4(a4), d5
  00466a:  6f 04                  ble.b $4670
  00466c:  39 45 00 04            move.w d5, $4(a4)
  004670:  b8 6c 00 06            cmp.w $6(a4), d4
  004674:  6f 28                  ble.b $469e
  004676:  39 44 00 06            move.w d4, $6(a4)
  00467a:  60 22                  bra.b $469e
  00467c:  50 8c                  addq.l #$8, a4
  00467e:  52 43                  addq.w #$1, d3
  004680:  b6 6d f2 2a            cmp.w -$dd6(a5), d3
  004684:  6d ba                  blt.b $4640
  004686:  0c 43 00 1e            cmpi.w #$1e, d3
  00468a:  6c 12                  bge.b $469e
  00468c:  38 87                  move.w d7, (a4)
  00468e:  39 46 00 02            move.w d6, $2(a4)
  004692:  39 45 00 04            move.w d5, $4(a4)
  004696:  39 44 00 06            move.w d4, $6(a4)
  00469a:  52 6d f2 2a            addq.w #$1, -$dd6(a5)
  00469e:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  0046a2:  4e 5e                  unlk a6
  0046a4:  4e 75                  rts 
  0046a6:  48 e7 03 00            movem.l d6-d7, -(a7)
  0046aa:  3e 2d bd 9c            move.w -$4264(a5), d7
  0046ae:  7c 00                  moveq #$0, d6
  0046b0:  60 0a                  bra.b $46bc
  0046b2:  3f 06                  move.w d6, -(a7)
  0046b4:  4e ba 00 88            jsr $473e(pc)
  0046b8:  54 8f                  addq.l #$2, a7
  0046ba:  52 46                  addq.w #$1, d6
  0046bc:  be 46                  cmp.w d6, d7
  0046be:  6e f2                  bgt.b $46b2
  0046c0:  4c df 00 c0            movem.l (a7)+, d6-d7
  0046c4:  4e 75                  rts 
  0046c6:  48 e7 03 00            movem.l d6-d7, -(a7)
  0046ca:  3e 2d bd a2            move.w -$425e(a5), d7
  0046ce:  7c 00                  moveq #$0, d6
  0046d0:  60 0a                  bra.b $46dc
  0046d2:  3f 06                  move.w d6, -(a7)
  0046d4:  4e ba 00 cc            jsr $47a2(pc)
  0046d8:  54 8f                  addq.l #$2, a7
  0046da:  52 46                  addq.w #$1, d6
  0046dc:  be 46                  cmp.w d6, d7
  0046de:  6e f2                  bgt.b $46d2
  0046e0:  4c df 00 c0            movem.l (a7)+, d6-d7
  0046e4:  4e 75                  rts 
  0046e6:  48 e7 03 00            movem.l d6-d7, -(a7)
  0046ea:  3e 2d bd 9e            move.w -$4262(a5), d7
  0046ee:  7c 00                  moveq #$0, d6
  0046f0:  60 0a                  bra.b $46fc
  0046f2:  3f 06                  move.w d6, -(a7)
  0046f4:  4e ba 02 2a            jsr $4920(pc)
  0046f8:  54 8f                  addq.l #$2, a7
  0046fa:  52 46                  addq.w #$1, d6
  0046fc:  be 46                  cmp.w d6, d7
  0046fe:  6e f2                  bgt.b $46f2
  004700:  4c df 00 c0            movem.l (a7)+, d6-d7
  004704:  4e 75                  rts 
  004706:  4e 56 00 00            link.w a6, #$0
  00470a:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  00470e:  3e 2d bd a0            move.w -$4260(a5), d7
  004712:  7c 00                  moveq #$0, d6
  004714:  49 ed d7 0a            lea.l -$28f6(a5), a4
  004718:  60 18                  bra.b $4732
  00471a:  70 00                  moveq #$0, d0
  00471c:  10 14                  move.b (a4), d0
  00471e:  b0 6e 00 08            cmp.w $8(a6), d0
  004722:  66 08                  bne.b $472c
  004724:  3f 06                  move.w d6, -(a7)
  004726:  4e ba 02 d0            jsr $49f8(pc)
  00472a:  54 8f                  addq.l #$2, a7
  00472c:  52 46                  addq.w #$1, d6
  00472e:  49 ec 00 0a            lea.l $a(a4), a4
  004732:  be 46                  cmp.w d6, d7
  004734:  6e e4                  bgt.b $471a
  004736:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  00473a:  4e 5e                  unlk a6
  00473c:  4e 75                  rts 
  00473e:  4e 56 00 00            link.w a6, #$0
  004742:  2f 0c                  move.l a4, -(a7)
  004744:  70 0a                  moveq #$a, d0
  004746:  c1 ee 00 08            muls.w $8(a6), d0
  00474a:  49 ed bd a6            lea.l -$425a(a5), a4
  00474e:  d0 8c                  add.l a4, d0
  004750:  28 40                  movea.l d0, a4
  004752:  2b 6d a2 e4 a2 ec      move.l -$5d1c(a5), -$5d14(a5)
  004758:  2b 6d a2 e8 a2 f0      move.l -$5d18(a5), -$5d10(a5)
  00475e:  4a 6d ba 32            tst.w -$45ce(a5)
  004762:  66 08                  bne.b $476c
  004764:  3b 6c 00 08 a2 e4      move.w $8(a4), -$5d1c(a5)
  00476a:  60 0c                  bra.b $4778
  00476c:  30 2d a5 d0            move.w -$5a30(a5), d0
  004770:  90 6c 00 08            sub.w $8(a4), d0
  004774:  3b 40 a2 e8            move.w d0, -$5d18(a5)
  004778:  3f 3c 00 01            move.w #$1, -(a7)
  00477c:  3f 2c 00 06            move.w $6(a4), -(a7)
  004780:  3f 2c 00 04            move.w $4(a4), -(a7)
  004784:  3f 2c 00 02            move.w $2(a4), -(a7)
  004788:  3f 14                  move.w (a4), -(a7)
  00478a:  4e ba 01 fe            jsr $498a(pc)
  00478e:  2b 6d a2 ec a2 e4      move.l -$5d14(a5), -$5d1c(a5)
  004794:  2b 6d a2 f0 a2 e8      move.l -$5d10(a5), -$5d18(a5)
  00479a:  28 6e ff fc            movea.l -$4(a6), a4
  00479e:  4e 5e                  unlk a6
  0047a0:  4e 75                  rts 
  0047a2:  4e 56 00 00            link.w a6, #$0
  0047a6:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  0047aa:  70 14                  moveq #$14, d0
  0047ac:  c1 ee 00 08            muls.w $8(a6), d0
  0047b0:  49 ed c7 6a            lea.l -$3896(a5), a4
  0047b4:  d0 8c                  add.l a4, d0
  0047b6:  28 40                  movea.l d0, a4
  0047b8:  3e 14                  move.w (a4), d7
  0047ba:  3c 2c 00 02            move.w $2(a4), d6
  0047be:  3a 2c 00 04            move.w $4(a4), d5
  0047c2:  38 2c 00 06            move.w $6(a4), d4
  0047c6:  20 4d                  movea.l a5, a0
  0047c8:  d0 c7                  adda.w d7, a0
  0047ca:  76 00                  moveq #$0, d3
  0047cc:  16 28 b9 2c            move.b -$46d4(a0), d3
  0047d0:  4a 43                  tst.w d3
  0047d2:  67 52                  beq.b $4826
  0047d4:  2b 6d a2 e4 a2 ec      move.l -$5d1c(a5), -$5d14(a5)
  0047da:  2b 6d a2 e8 a2 f0      move.l -$5d18(a5), -$5d10(a5)
  0047e0:  4a 6d ba 32            tst.w -$45ce(a5)
  0047e4:  66 0e                  bne.b $47f4
  0047e6:  3b 6c 00 0c a2 e4      move.w $c(a4), -$5d1c(a5)
  0047ec:  3b 6c 00 10 a2 e8      move.w $10(a4), -$5d18(a5)
  0047f2:  60 18                  bra.b $480c
  0047f4:  30 2d a5 d0            move.w -$5a30(a5), d0
  0047f8:  90 6c 00 10            sub.w $10(a4), d0
  0047fc:  3b 40 a2 e4            move.w d0, -$5d1c(a5)
  004800:  30 2d a5 d0            move.w -$5a30(a5), d0
  004804:  90 6c 00 0c            sub.w $c(a4), d0
  004808:  3b 40 a2 e8            move.w d0, -$5d18(a5)
  00480c:  3b 6c 00 0e a2 e6      move.w $e(a4), -$5d1a(a5)
  004812:  3b 6c 00 12 a2 ea      move.w $12(a4), -$5d16(a5)
  004818:  4a 47                  tst.w d7
  00481a:  67 0a                  beq.b $4826
  00481c:  3f 05                  move.w d5, -(a7)
  00481e:  4e ba 11 4c            jsr $596c(pc)
  004822:  3a 00                  move.w d0, d5
  004824:  54 8f                  addq.l #$2, a7
  004826:  4a 2c 00 0a            tst.b $a(a4)
  00482a:  67 14                  beq.b $4840
  00482c:  3f 2c 00 08            move.w $8(a4), -(a7)
  004830:  3f 04                  move.w d4, -(a7)
  004832:  3f 05                  move.w d5, -(a7)
  004834:  3f 06                  move.w d6, -(a7)
  004836:  3f 07                  move.w d7, -(a7)
  004838:  4e ba fc aa            jsr $44e4(pc)
  00483c:  4f ef 00 0a            lea.l $a(a7), a7
  004840:  4a 2c 00 0b            tst.b $b(a4)
  004844:  67 54                  beq.b $489a
  004846:  4a 2d a2 09            tst.b -$5df7(a5)
  00484a:  67 4e                  beq.b $489a
  00484c:  1b 6d a3 c3 a3 54      move.b -$5c3d(a5), -$5cac(a5)
  004852:  1b 6d a3 c4 a3 55      move.b -$5c3c(a5), -$5cab(a5)
  004858:  1b 6d a3 c5 a3 56      move.b -$5c3b(a5), -$5caa(a5)
  00485e:  1b 6d a3 c6 a3 57      move.b -$5c3a(a5), -$5ca9(a5)
  004864:  1b 6d a3 c7 a3 58      move.b -$5c39(a5), -$5ca8(a5)
  00486a:  1b 6d a3 c8 a3 59      move.b -$5c38(a5), -$5ca7(a5)
  004870:  1b 6d a3 c9 a3 5a      move.b -$5c37(a5), -$5ca6(a5)
  004876:  1b 6d a3 ca a3 5b      move.b -$5c36(a5), -$5ca5(a5)
  00487c:  1b 6d a3 cb a3 5c      move.b -$5c35(a5), -$5ca4(a5)
  004882:  1b 6d a3 cc a3 5d      move.b -$5c34(a5), -$5ca3(a5)
  004888:  1b 6d a3 cd a3 5e      move.b -$5c33(a5), -$5ca2(a5)
  00488e:  1b 6d a3 ce a3 5f      move.b -$5c32(a5), -$5ca1(a5)
  004894:  1b 6d a3 cf a3 60      move.b -$5c31(a5), -$5ca0(a5)
  00489a:  3f 2c 00 08            move.w $8(a4), -(a7)
  00489e:  3f 04                  move.w d4, -(a7)
  0048a0:  3f 05                  move.w d5, -(a7)
  0048a2:  3f 06                  move.w d6, -(a7)
  0048a4:  3f 07                  move.w d7, -(a7)
  0048a6:  4e ba 00 e2            jsr $498a(pc)
  0048aa:  4a 2c 00 0b            tst.b $b(a4)
  0048ae:  4f ef 00 0a            lea.l $a(a7), a7
  0048b2:  67 54                  beq.b $4908
  0048b4:  4a 2d a2 09            tst.b -$5df7(a5)
  0048b8:  67 4e                  beq.b $4908
  0048ba:  1b 6d a3 d0 a3 54      move.b -$5c30(a5), -$5cac(a5)
  0048c0:  1b 6d a3 d1 a3 55      move.b -$5c2f(a5), -$5cab(a5)
  0048c6:  1b 6d a3 d2 a3 56      move.b -$5c2e(a5), -$5caa(a5)
  0048cc:  1b 6d a3 d3 a3 57      move.b -$5c2d(a5), -$5ca9(a5)
  0048d2:  1b 6d a3 d4 a3 58      move.b -$5c2c(a5), -$5ca8(a5)
  0048d8:  1b 6d a3 d5 a3 59      move.b -$5c2b(a5), -$5ca7(a5)
  0048de:  1b 6d a3 d6 a3 5a      move.b -$5c2a(a5), -$5ca6(a5)
  0048e4:  1b 6d a3 d7 a3 5b      move.b -$5c29(a5), -$5ca5(a5)
  0048ea:  1b 6d a3 d8 a3 5c      move.b -$5c28(a5), -$5ca4(a5)
  0048f0:  1b 6d a3 d9 a3 5d      move.b -$5c27(a5), -$5ca3(a5)
  0048f6:  1b 6d a3 da a3 5e      move.b -$5c26(a5), -$5ca2(a5)
  0048fc:  1b 6d a3 db a3 5f      move.b -$5c25(a5), -$5ca1(a5)
  004902:  1b 6d a3 dc a3 60      move.b -$5c24(a5), -$5ca0(a5)
  004908:  4a 43                  tst.w d3
  00490a:  67 0c                  beq.b $4918
  00490c:  2b 6d a2 ec a2 e4      move.l -$5d14(a5), -$5d1c(a5)
  004912:  2b 6d a2 f0 a2 e8      move.l -$5d10(a5), -$5d18(a5)
  004918:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  00491c:  4e 5e                  unlk a6
  00491e:  4e 75                  rts 
  004920:  4e 56 00 00            link.w a6, #$0
  004924:  2f 0c                  move.l a4, -(a7)
  004926:  70 0c                  moveq #$c, d0
  004928:  c1 ee 00 08            muls.w $8(a6), d0
  00492c:  49 ed cb 52            lea.l -$34ae(a5), a4
  004930:  d0 8c                  add.l a4, d0
  004932:  28 40                  movea.l d0, a4
  004934:  2b 6d a2 e4 a2 ec      move.l -$5d1c(a5), -$5d14(a5)
  00493a:  2b 6d a2 e8 a2 f0      move.l -$5d18(a5), -$5d10(a5)
  004940:  4a 6d ba 32            tst.w -$45ce(a5)
  004944:  66 08                  bne.b $494e
  004946:  3b 6c 00 08 a2 e4      move.w $8(a4), -$5d1c(a5)
  00494c:  60 0c                  bra.b $495a
  00494e:  30 2d a5 d0            move.w -$5a30(a5), d0
  004952:  90 6c 00 08            sub.w $8(a4), d0
  004956:  3b 40 a2 e8            move.w d0, -$5d18(a5)
  00495a:  3b 6c 00 0a a2 ea      move.w $a(a4), -$5d16(a5)
  004960:  3f 3c 00 01            move.w #$1, -(a7)
  004964:  3f 2c 00 06            move.w $6(a4), -(a7)
  004968:  3f 2c 00 04            move.w $4(a4), -(a7)
  00496c:  3f 2c 00 02            move.w $2(a4), -(a7)
  004970:  3f 14                  move.w (a4), -(a7)
  004972:  4e ba 00 16            jsr $498a(pc)
  004976:  2b 6d a2 ec a2 e4      move.l -$5d14(a5), -$5d1c(a5)
  00497c:  2b 6d a2 f0 a2 e8      move.l -$5d10(a5), -$5d18(a5)
  004982:  28 6e ff fc            movea.l -$4(a6), a4
  004986:  4e 5e                  unlk a6
  004988:  4e 75                  rts 
  00498a:  4e 56 00 00            link.w a6, #$0
  00498e:  48 e7 07 00            movem.l d5-d7, -(a7)
  004992:  7e 01                  moveq #$1, d7
  004994:  de 6e 00 0a            add.w $a(a6), d7
  004998:  20 4d                  movea.l a5, a0
  00499a:  30 2e 00 0c            move.w $c(a6), d0
  00499e:  d0 c0                  adda.w d0, a0
  0049a0:  d0 c0                  adda.w d0, a0
  0049a2:  3c 28 99 14            move.w -$66ec(a0), d6
  0049a6:  20 4d                  movea.l a5, a0
  0049a8:  32 2e 00 0e            move.w $e(a6), d1
  0049ac:  d0 c1                  adda.w d1, a0
  0049ae:  d0 c1                  adda.w d1, a0
  0049b0:  3a 28 9d 12            move.w -$62ee(a0), d5
  0049b4:  3f 2e 00 10            move.w $10(a6), -(a7)
  0049b8:  3f 05                  move.w d5, -(a7)
  0049ba:  3f 06                  move.w d6, -(a7)
  0049bc:  3f 07                  move.w d7, -(a7)
  0049be:  3f 2e 00 08            move.w $8(a6), -(a7)
  0049c2:  20 6d a3 de            movea.l -$5c22(a5), a0
  0049c6:  4e 90                  jsr (a0)
  0049c8:  4a 6d f2 28            tst.w -$dd8(a5)
  0049cc:  4f ef 00 0a            lea.l $a(a7), a7
  0049d0:  67 1e                  beq.b $49f0
  0049d2:  3f 2e 00 10            move.w $10(a6), -(a7)
  0049d6:  3f 05                  move.w d5, -(a7)
  0049d8:  3f 06                  move.w d6, -(a7)
  0049da:  3f 07                  move.w d7, -(a7)
  0049dc:  3f 2e 00 08            move.w $8(a6), -(a7)
  0049e0:  4e ad 01 12            jsr $112(a5)
  0049e4:  48 6d a5 f4            pea.l -$5a0c(a5)
  0049e8:  4e ba fb e0            jsr $45ca(pc)
  0049ec:  4f ef 00 0e            lea.l $e(a7), a7
  0049f0:  4c df 00 e0            movem.l (a7)+, d5-d7
  0049f4:  4e 5e                  unlk a6
  0049f6:  4e 75                  rts 
  0049f8:  4e 56 00 00            link.w a6, #$0
  0049fc:  48 e7 1f 08            movem.l d3-d7/a4, -(a7)
  004a00:  70 0a                  moveq #$a, d0
  004a02:  c1 ee 00 08            muls.w $8(a6), d0
  004a06:  49 ed d7 0a            lea.l -$28f6(a5), a4
  004a0a:  d0 8c                  add.l a4, d0
  004a0c:  28 40                  movea.l d0, a4
  004a0e:  3e 2c 00 04            move.w $4(a4), d7
  004a12:  30 07                  move.w d7, d0
  004a14:  90 6c 00 08            sub.w $8(a4), d0
  004a18:  20 4d                  movea.l a5, a0
  004a1a:  d0 c0                  adda.w d0, a0
  004a1c:  d0 c0                  adda.w d0, a0
  004a1e:  3c 28 9d 12            move.w -$62ee(a0), d6
  004a22:  36 2c 00 02            move.w $2(a4), d3
  004a26:  20 4d                  movea.l a5, a0
  004a28:  d0 c3                  adda.w d3, a0
  004a2a:  d0 c3                  adda.w d3, a0
  004a2c:  3a 28 99 14            move.w -$66ec(a0), d5
  004a30:  20 4d                  movea.l a5, a0
  004a32:  d0 c7                  adda.w d7, a0
  004a34:  d0 c7                  adda.w d7, a0
  004a36:  38 28 9d 12            move.w -$62ee(a0), d4
  004a3a:  30 6c 00 06            movea.w $6(a4), a0
  004a3e:  d0 c3                  adda.w d3, a0
  004a40:  d1 c8                  adda.l a0, a0
  004a42:  41 e8 99 14            lea.l -$66ec(a0), a0
  004a46:  d1 cd                  adda.l a5, a0
  004a48:  3e 10                  move.w (a0), d7
  004a4a:  4a 6d ba 32            tst.w -$45ce(a5)
  004a4e:  66 0a                  bne.b $4a5a
  004a50:  3b 46 a5 f4            move.w d6, -$5a0c(a5)
  004a54:  3b 44 a5 f8            move.w d4, -$5a08(a5)
  004a58:  60 14                  bra.b $4a6e
  004a5a:  30 2d a5 d0            move.w -$5a30(a5), d0
  004a5e:  90 44                  sub.w d4, d0
  004a60:  3b 40 a5 f4            move.w d0, -$5a0c(a5)
  004a64:  30 2d a5 d0            move.w -$5a30(a5), d0
  004a68:  90 46                  sub.w d6, d0
  004a6a:  3b 40 a5 f8            move.w d0, -$5a08(a5)
  004a6e:  3b 45 a5 f6            move.w d5, -$5a0a(a5)
  004a72:  3b 47 a5 fa            move.w d7, -$5a06(a5)
  004a76:  42 27                  clr.b -(a7)
  004a78:  48 6d a5 f4            pea.l -$5a0c(a5)
  004a7c:  48 6d a2 e4            pea.l -$5d1c(a5)
  004a80:  48 6d a5 f4            pea.l -$5a0c(a5)
  004a84:  a8 aa                  dc.w $a8aa
  004a86:  4a 1f                  tst.b (a7)+
  004a88:  67 20                  beq.b $4aaa
  004a8a:  1f 2c 00 01            move.b $1(a4), -(a7)
  004a8e:  48 6d a5 f4            pea.l -$5a0c(a5)
  004a92:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  004a96:  4e 90                  jsr (a0)
  004a98:  4a 6d f2 28            tst.w -$dd8(a5)
  004a9c:  5c 8f                  addq.l #$6, a7
  004a9e:  67 0a                  beq.b $4aaa
  004aa0:  48 6d a5 f4            pea.l -$5a0c(a5)
  004aa4:  4e ba fb 24            jsr $45ca(pc)
  004aa8:  58 8f                  addq.l #$4, a7
  004aaa:  4c df 10 f8            movem.l (a7)+, d3-d7/a4
  004aae:  4e 5e                  unlk a6
  004ab0:  4e 75                  rts 
  004ab2:  48 e7 03 00            movem.l d6-d7, -(a7)
  004ab6:  70 c2                  moveq #$c2, d0
  004ab8:  d0 6d f2 24            add.w -$ddc(a5), d0
  004abc:  3b 40 bd 92            move.w d0, -$426e(a5)
  004ac0:  7e 00                  moveq #$0, d7
  004ac2:  1e 2d ba 97            move.b -$4569(a5), d7
  004ac6:  0c 47 00 bc            cmpi.w #$bc, d7
  004aca:  6f 04                  ble.b $4ad0
  004acc:  3e 3c 00 bc            move.w #$bc, d7
  004ad0:  2c 07                  move.l d7, d6
  004ad2:  48 c6                  ext.l d6
  004ad4:  8d fc 00 04            divs.w #$4, d6
  004ad8:  4a 2d a2 0a            tst.b -$5df6(a5)
  004adc:  66 08                  bne.b $4ae6
  004ade:  0c 46 00 2d            cmpi.w #$2d, d6
  004ae2:  6f 02                  ble.b $4ae6
  004ae4:  7c 2d                  moveq #$2d, d6
  004ae6:  70 01                  moveq #$1, d0
  004ae8:  d0 46                  add.w d6, d0
  004aea:  3b 40 bd 94            move.w d0, -$426c(a5)
  004aee:  32 2d f2 26            move.w -$dda(a5), d1
  004af2:  92 40                  sub.w d0, d1
  004af4:  3b 41 bd 96            move.w d1, -$426a(a5)
  004af8:  4c df 00 c0            movem.l (a7)+, d6-d7
  004afc:  4e 75                  rts 
  004afe:  48 e7 03 00            movem.l d6-d7, -(a7)
  004b02:  4e ba ff ae            jsr $4ab2(pc)
  004b06:  4a 2d a2 0a            tst.b -$5df6(a5)
  004b0a:  67 00 01 0e            beq.w $4c1a
  004b0e:  2f 3c 00 03 00 02      move.l #$30002, -(a7)
  004b14:  30 2d bd 96            move.w -$426a(a5), d0
  004b18:  90 6d bd 92            sub.w -$426e(a5), d0
  004b1c:  52 40                  addq.w #$1, d0
  004b1e:  3f 00                  move.w d0, -(a7)
  004b20:  3f 2d bd 96            move.w -$426a(a5), -(a7)
  004b24:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004b28:  42 67                  clr.w -(a7)
  004b2a:  4e ba fa 46            jsr $4572(pc)
  004b2e:  70 0c                  moveq #$c, d0
  004b30:  d0 6d bd 96            add.w -$426a(a5), d0
  004b34:  b0 6d f2 26            cmp.w -$dda(a5), d0
  004b38:  4f ef 00 0c            lea.l $c(a7), a7
  004b3c:  6c 1a                  bge.b $4b58
  004b3e:  3f 2d bd 96            move.w -$426a(a5), -(a7)
  004b42:  42 67                  clr.w -(a7)
  004b44:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004b48:  2f 3c 00 06 00 32      move.l #$60032, -(a7)
  004b4e:  4e ba f8 2a            jsr $437a(pc)
  004b52:  4f ef 00 0a            lea.l $a(a7), a7
  004b56:  60 5e                  bra.b $4bb6
  004b58:  10 2d b4 35            move.b -$4bcb(a5), d0
  004b5c:  48 80                  ext.w d0
  004b5e:  d0 6d f2 26            add.w -$dda(a5), d0
  004b62:  3f 00                  move.w d0, -(a7)
  004b64:  42 67                  clr.w -(a7)
  004b66:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004b6a:  70 00                  moveq #$0, d0
  004b6c:  10 2d b4 33            move.b -$4bcd(a5), d0
  004b70:  3f 00                  move.w d0, -(a7)
  004b72:  3f 3c 00 06            move.w #$6, -(a7)
  004b76:  4e ba f8 02            jsr $437a(pc)
  004b7a:  4e ba ec a0            jsr $381c(pc)
  004b7e:  4a 00                  tst.b d0
  004b80:  4f ef 00 0a            lea.l $a(a7), a7
  004b84:  67 04                  beq.b $4b8a
  004b86:  4e ba ec bc            jsr $3844(pc)
  004b8a:  42 67                  clr.w -(a7)
  004b8c:  4e ba f1 86            jsr $3d14(pc)
  004b90:  42 57                  clr.w (a7)
  004b92:  4e ba f2 2a            jsr $3dbe(pc)
  004b96:  4e ba f2 80            jsr $3e18(pc)
  004b9a:  70 fe                  moveq #$fe, d0
  004b9c:  d0 6d bd 96            add.w -$426a(a5), d0
  004ba0:  3e 80                  move.w d0, (a7)
  004ba2:  42 67                  clr.w -(a7)
  004ba4:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004ba8:  2f 3c 00 06 00 33      move.l #$60033, -(a7)
  004bae:  4e ba f7 ca            jsr $437a(pc)
  004bb2:  4f ef 00 0a            lea.l $a(a7), a7
  004bb6:  7e f4                  moveq #$f4, d7
  004bb8:  de 6d bd 96            add.w -$426a(a5), d7
  004bbc:  0c 47 00 c0            cmpi.w #$c0, d7
  004bc0:  6c 00 00 94            bge.w $4c56
  004bc4:  60 18                  bra.b $4bde
  004bc6:  3f 07                  move.w d7, -(a7)
  004bc8:  42 67                  clr.w -(a7)
  004bca:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004bce:  2f 3c 00 06 00 34      move.l #$60034, -(a7)
  004bd4:  4e ba f7 a4            jsr $437a(pc)
  004bd8:  51 47                  subq.w #$8, d7
  004bda:  4f ef 00 0a            lea.l $a(a7), a7
  004bde:  70 f8                  moveq #$f8, d0
  004be0:  d0 47                  add.w d7, d0
  004be2:  b0 6d bd 92            cmp.w -$426e(a5), d0
  004be6:  6c de                  bge.b $4bc6
  004be8:  3c 07                  move.w d7, d6
  004bea:  9c 6d bd 92            sub.w -$426e(a5), d6
  004bee:  4a 46                  tst.w d6
  004bf0:  6d 64                  blt.b $4c56
  004bf2:  0c 46 00 07            cmpi.w #$7, d6
  004bf6:  6e 5e                  bgt.b $4c56
  004bf8:  3f 07                  move.w d7, -(a7)
  004bfa:  42 67                  clr.w -(a7)
  004bfc:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004c00:  20 4d                  movea.l a5, a0
  004c02:  d0 c6                  adda.w d6, a0
  004c04:  70 00                  moveq #$0, d0
  004c06:  10 28 b5 ea            move.b -$4a16(a0), d0
  004c0a:  3f 00                  move.w d0, -(a7)
  004c0c:  3f 3c 00 06            move.w #$6, -(a7)
  004c10:  4e ba f7 68            jsr $437a(pc)
  004c14:  4f ef 00 0a            lea.l $a(a7), a7
  004c18:  60 3c                  bra.b $4c56
  004c1a:  3f 2d f2 26            move.w -$dda(a5), -(a7)
  004c1e:  42 67                  clr.w -(a7)
  004c20:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004c24:  2f 3c 00 06 00 32      move.l #$60032, -(a7)
  004c2a:  4e ba f7 4e            jsr $437a(pc)
  004c2e:  30 2d bd 92            move.w -$426e(a5), d0
  004c32:  20 4d                  movea.l a5, a0
  004c34:  d0 c0                  adda.w d0, a0
  004c36:  d0 c0                  adda.w d0, a0
  004c38:  3b 68 9d 12 bd 74      move.w -$62ee(a0), -$428c(a5)
  004c3e:  3e ad bd 96            move.w -$426a(a5), (a7)
  004c42:  42 67                  clr.w -(a7)
  004c44:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004c48:  2f 3c 00 06 00 33      move.l #$60033, -(a7)
  004c4e:  4e ba f7 2a            jsr $437a(pc)
  004c52:  4f ef 00 12            lea.l $12(a7), a7
  004c56:  4c df 00 c0            movem.l (a7)+, d6-d7
  004c5a:  4e 75                  rts 
  004c5c:  48 e7 03 00            movem.l d6-d7, -(a7)
  004c60:  4e ba fe 50            jsr $4ab2(pc)
  004c64:  4a 2d a2 0a            tst.b -$5df6(a5)
  004c68:  67 00 00 82            beq.w $4cec
  004c6c:  70 fe                  moveq #$fe, d0
  004c6e:  d0 6d bd 96            add.w -$426a(a5), d0
  004c72:  3f 00                  move.w d0, -(a7)
  004c74:  42 67                  clr.w -(a7)
  004c76:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004c7a:  2f 3c 00 06 00 33      move.l #$60033, -(a7)
  004c80:  4e ba f7 f8            jsr $447a(pc)
  004c84:  7e f4                  moveq #$f4, d7
  004c86:  de 6d bd 96            add.w -$426a(a5), d7
  004c8a:  0c 47 00 c0            cmpi.w #$c0, d7
  004c8e:  4f ef 00 0a            lea.l $a(a7), a7
  004c92:  6c 00 00 80            bge.w $4d14
  004c96:  60 18                  bra.b $4cb0
  004c98:  3f 07                  move.w d7, -(a7)
  004c9a:  42 67                  clr.w -(a7)
  004c9c:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004ca0:  2f 3c 00 06 00 34      move.l #$60034, -(a7)
  004ca6:  4e ba f7 d2            jsr $447a(pc)
  004caa:  51 47                  subq.w #$8, d7
  004cac:  4f ef 00 0a            lea.l $a(a7), a7
  004cb0:  70 f8                  moveq #$f8, d0
  004cb2:  d0 47                  add.w d7, d0
  004cb4:  b0 6d bd 92            cmp.w -$426e(a5), d0
  004cb8:  6c de                  bge.b $4c98
  004cba:  3c 07                  move.w d7, d6
  004cbc:  9c 6d bd 92            sub.w -$426e(a5), d6
  004cc0:  4a 46                  tst.w d6
  004cc2:  6d 50                  blt.b $4d14
  004cc4:  0c 46 00 07            cmpi.w #$7, d6
  004cc8:  6e 4a                  bgt.b $4d14
  004cca:  3f 07                  move.w d7, -(a7)
  004ccc:  42 67                  clr.w -(a7)
  004cce:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004cd2:  20 4d                  movea.l a5, a0
  004cd4:  d0 c6                  adda.w d6, a0
  004cd6:  70 00                  moveq #$0, d0
  004cd8:  10 28 b5 ea            move.b -$4a16(a0), d0
  004cdc:  3f 00                  move.w d0, -(a7)
  004cde:  3f 3c 00 06            move.w #$6, -(a7)
  004ce2:  4e ba f7 96            jsr $447a(pc)
  004ce6:  4f ef 00 0a            lea.l $a(a7), a7
  004cea:  60 28                  bra.b $4d14
  004cec:  30 2d bd 92            move.w -$426e(a5), d0
  004cf0:  20 4d                  movea.l a5, a0
  004cf2:  d0 c0                  adda.w d0, a0
  004cf4:  d0 c0                  adda.w d0, a0
  004cf6:  3b 68 9d 12 bd 76      move.w -$62ee(a0), -$428a(a5)
  004cfc:  3f 2d bd 96            move.w -$426a(a5), -(a7)
  004d00:  42 67                  clr.w -(a7)
  004d02:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004d06:  2f 3c 00 06 00 33      move.l #$60033, -(a7)
  004d0c:  4e ba f7 6c            jsr $447a(pc)
  004d10:  4f ef 00 0a            lea.l $a(a7), a7
  004d14:  4c df 00 c0            movem.l (a7)+, d6-d7
  004d18:  4e 75                  rts 
  004d1a:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  004d1e:  7e 01                  moveq #$1, d7
  004d20:  60 3e                  bra.b $4d60
  004d22:  3f 07                  move.w d7, -(a7)
  004d24:  4e ba 04 44            jsr $516a(pc)
  004d28:  20 07                  move.l d7, d0
  004d2a:  48 c0                  ext.l d0
  004d2c:  e5 88                  lsl.l #$2, d0
  004d2e:  49 ed f0 ba            lea.l -$f46(a5), a4
  004d32:  d0 8c                  add.l a4, d0
  004d34:  28 40                  movea.l d0, a4
  004d36:  70 00                  moveq #$0, d0
  004d38:  10 14                  move.b (a4), d0
  004d3a:  3b 40 ba 6c            move.w d0, -$4594(a5)
  004d3e:  72 00                  moveq #$0, d1
  004d40:  12 2c 00 01            move.b $1(a4), d1
  004d44:  3b 41 ba 6e            move.w d1, -$4592(a5)
  004d48:  7c 00                  moveq #$0, d6
  004d4a:  54 8f                  addq.l #$2, a7
  004d4c:  60 0a                  bra.b $4d58
  004d4e:  3f 06                  move.w d6, -(a7)
  004d50:  4e ba 00 1a            jsr $4d6c(pc)
  004d54:  54 8f                  addq.l #$2, a7
  004d56:  52 46                  addq.w #$1, d6
  004d58:  0c 46 00 1e            cmpi.w #$1e, d6
  004d5c:  6d f0                  blt.b $4d4e
  004d5e:  52 47                  addq.w #$1, d7
  004d60:  0c 47 00 18            cmpi.w #$18, d7
  004d64:  6f bc                  ble.b $4d22
  004d66:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  004d6a:  4e 75                  rts 
  004d6c:  4e 56 00 00            link.w a6, #$0
  004d70:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  004d74:  3e 2e 00 08            move.w $8(a6), d7
  004d78:  28 6d bd 86            movea.l -$427a(a5), a4
  004d7c:  d8 c7                  adda.w d7, a4
  004d7e:  20 6d bd 82            movea.l -$427e(a5), a0
  004d82:  7c 00                  moveq #$0, d6
  004d84:  1c 30 70 00            move.b (a0, d7.w), d6
  004d88:  02 46 00 1f            andi.w #$1f, d6
  004d8c:  30 06                  move.w d6, d0
  004d8e:  59 40                  subq.w #$4, d0
  004d90:  0c 40 00 10            cmpi.w #$10, d0
  004d94:  62 00 01 02            bhi.w $4e98
  004d98:  43 fa 01 06            lea.l $4ea0(pc), a1
  004d9c:  d0 40                  add.w d0, d0
  004d9e:  d2 f1 00 00            adda.w (a1, d0.w), a1
  004da2:  4e d1                  jmp (a1)
  004da4:  0c 14 00 01            cmpi.b #$1, (a4)
  004da8:  66 08                  bne.b $4db2
  004daa:  18 bc 00 bc            move.b #$bc, (a4)
  004dae:  60 00 00 e8            bra.w $4e98
  004db2:  42 14                  clr.b (a4)
  004db4:  60 00 00 e2            bra.w $4e98
  004db8:  42 14                  clr.b (a4)
  004dba:  60 00 00 dc            bra.w $4e98
  004dbe:  10 14                  move.b (a4), d0
  004dc0:  eb 08                  lsl.b #$5, d0
  004dc2:  18 80                  move.b d0, (a4)
  004dc4:  60 00 00 d2            bra.w $4e98
  004dc8:  10 14                  move.b (a4), d0
  004dca:  ef 08                  lsl.b #$7, d0
  004dcc:  18 80                  move.b d0, (a4)
  004dce:  7a 01                  moveq #$1, d5
  004dd0:  3c 05                  move.w d5, d6
  004dd2:  28 07                  move.l d7, d4
  004dd4:  48 c4                  ext.l d4
  004dd6:  89 fc 00 0a            divs.w #$a, d4
  004dda:  48 44                  swap d4
  004ddc:  4a 44                  tst.w d4
  004dde:  66 2e                  bne.b $4e0e
  004de0:  4a 6d ba 6c            tst.w -$4594(a5)
  004de4:  67 40                  beq.b $4e26
  004de6:  70 ff                  moveq #$ff, d0
  004de8:  d0 6d ba 6c            add.w -$4594(a5), d0
  004dec:  c1 fc 00 1e            muls.w #$1e, d0
  004df0:  41 ed e9 27            lea.l -$16d9(a5), a0
  004df4:  d0 88                  add.l a0, d0
  004df6:  30 47                  movea.w d7, a0
  004df8:  72 00                  moveq #$0, d1
  004dfa:  12 30 08 00            move.b (a0, d0.l), d1
  004dfe:  02 41 00 1f            andi.w #$1f, d1
  004e02:  0c 41 00 14            cmpi.w #$14, d1
  004e06:  57 c6                  seq.b d6
  004e08:  44 06                  neg.b d6
  004e0a:  48 86                  ext.w d6
  004e0c:  60 18                  bra.b $4e26
  004e0e:  20 6d bd 82            movea.l -$427e(a5), a0
  004e12:  70 00                  moveq #$0, d0
  004e14:  10 30 70 ff            move.b -$1(a0, d7.w), d0
  004e18:  02 40 00 1f            andi.w #$1f, d0
  004e1c:  0c 40 00 14            cmpi.w #$14, d0
  004e20:  57 c6                  seq.b d6
  004e22:  44 06                  neg.b d6
  004e24:  48 86                  ext.w d6
  004e26:  0c 44 00 09            cmpi.w #$9, d4
  004e2a:  66 2e                  bne.b $4e5a
  004e2c:  4a 6d ba 6e            tst.w -$4592(a5)
  004e30:  67 40                  beq.b $4e72
  004e32:  70 ff                  moveq #$ff, d0
  004e34:  d0 6d ba 6e            add.w -$4592(a5), d0
  004e38:  c1 fc 00 1e            muls.w #$1e, d0
  004e3c:  41 ed e9 13            lea.l -$16ed(a5), a0
  004e40:  d0 88                  add.l a0, d0
  004e42:  30 47                  movea.w d7, a0
  004e44:  72 00                  moveq #$0, d1
  004e46:  12 30 08 00            move.b (a0, d0.l), d1
  004e4a:  02 41 00 1f            andi.w #$1f, d1
  004e4e:  0c 41 00 14            cmpi.w #$14, d1
  004e52:  57 c5                  seq.b d5
  004e54:  44 05                  neg.b d5
  004e56:  48 85                  ext.w d5
  004e58:  60 18                  bra.b $4e72
  004e5a:  20 6d bd 82            movea.l -$427e(a5), a0
  004e5e:  70 00                  moveq #$0, d0
  004e60:  10 30 70 01            move.b $1(a0, d7.w), d0
  004e64:  02 40 00 1f            andi.w #$1f, d0
  004e68:  0c 40 00 14            cmpi.w #$14, d0
  004e6c:  57 c5                  seq.b d5
  004e6e:  44 05                  neg.b d5
  004e70:  48 85                  ext.w d5
  004e72:  4a 46                  tst.w d6
  004e74:  67 0a                  beq.b $4e80
  004e76:  4a 45                  tst.w d5
  004e78:  67 06                  beq.b $4e80
  004e7a:  00 14 00 03            ori.b #$3, (a4)
  004e7e:  60 18                  bra.b $4e98
  004e80:  4a 46                  tst.w d6
  004e82:  67 06                  beq.b $4e8a
  004e84:  00 14 00 02            ori.b #$2, (a4)
  004e88:  60 0e                  bra.b $4e98
  004e8a:  4a 45                  tst.w d5
  004e8c:  67 06                  beq.b $4e94
  004e8e:  00 14 00 01            ori.b #$1, (a4)
  004e92:  60 04                  bra.b $4e98
  004e94:  00 14 00 00            ori.b #$0, (a4)
  004e98:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  004e9c:  4e 5e                  unlk a6
  004e9e:  4e 75                  rts 
  004ea0:  ff 04                  dc.w $ff04
  004ea2:  ff f8                  dc.w $fff8
  004ea4:  ff f8                  dc.w $fff8
  004ea6:  ff f8                  dc.w $fff8
  004ea8:  ff f8                  dc.w $fff8
  004eaa:  ff f8                  dc.w $fff8
  004eac:  ff 1e                  dc.w $ff1e
  004eae:  ff 18                  dc.w $ff18
  004eb0:  ff f8                  dc.w $fff8
  004eb2:  ff f8                  dc.w $fff8
  004eb4:  ff f8                  dc.w $fff8
  004eb6:  ff f8                  dc.w $fff8
  004eb8:  ff f8                  dc.w $fff8
  004eba:  ff f8                  dc.w $fff8
  004ebc:  ff f8                  dc.w $fff8
  004ebe:  ff f8                  dc.w $fff8
  004ec0:  ff 28                  dc.w $ff28
  004ec2:  42 6d bd a4            clr.w -$425c(a5)
  004ec6:  42 6d bd a2            clr.w -$425e(a5)
  004eca:  42 6d bd a0            clr.w -$4260(a5)
  004ece:  42 6d bd 9e            clr.w -$4262(a5)
  004ed2:  42 6d bd 9c            clr.w -$4264(a5)
  004ed6:  41 ed 04 9a            lea.l $49a(a5), a0
  004eda:  2b 48 bd 70            move.l a0, -$4290(a5)
  004ede:  4e ba e0 58            jsr $2f38(pc)
  004ee2:  4e ba 07 be            jsr $56a2(pc)
  004ee6:  4e ba 00 04            jsr $4eec(pc)
  004eea:  4e 75                  rts 
  004eec:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  004ef0:  4e ba e7 d0            jsr $36c2(pc)
  004ef4:  1f 3c 00 1e            move.b #$1e, -(a7)
  004ef8:  4e ba 04 02            jsr $52fc(pc)
  004efc:  3b 7c 00 bc f2 26      move.w #$bc, -$dda(a5)
  004f02:  3b 7c 00 bf f2 24      move.w #$bf, -$ddc(a5)
  004f08:  7e 02                  moveq #$2, d7
  004f0a:  49 ed b6 4a            lea.l -$49b6(a5), a4
  004f0e:  54 8f                  addq.l #$2, a7
  004f10:  60 38                  bra.b $4f4a
  004f12:  3b 47 f2 1e            move.w d7, -$de2(a5)
  004f16:  4e ba e8 10            jsr $3728(pc)
  004f1a:  7c 00                  moveq #$0, d6
  004f1c:  60 16                  bra.b $4f34
  004f1e:  3b 46 f2 20            move.w d6, -$de0(a5)
  004f22:  4e ba e7 2e            jsr $3652(pc)
  004f26:  30 14                  move.w (a4), d0
  004f28:  d0 46                  add.w d6, d0
  004f2a:  3f 00                  move.w d0, -(a7)
  004f2c:  4e ba e5 14            jsr $3442(pc)
  004f30:  54 8f                  addq.l #$2, a7
  004f32:  52 46                  addq.w #$1, d6
  004f34:  0c 46 00 0a            cmpi.w #$a, d6
  004f38:  6d e4                  blt.b $4f1e
  004f3a:  04 6d 00 3f f2 26      subi.w #$3f, -$dda(a5)
  004f40:  04 6d 00 3f f2 24      subi.w #$3f, -$ddc(a5)
  004f46:  53 47                  subq.w #$1, d7
  004f48:  55 8c                  subq.l #$2, a4
  004f4a:  4a 47                  tst.w d7
  004f4c:  6c c4                  bge.b $4f12
  004f4e:  3e 2d ba 6a            move.w -$4596(a5), d7
  004f52:  3b 6d ba 70 ba 6a      move.w -$4590(a5), -$4596(a5)
  004f58:  4e ba e2 fc            jsr $3256(pc)
  004f5c:  4e ba e7 64            jsr $36c2(pc)
  004f60:  3b 7c 00 02 f2 1e      move.w #$2, -$de2(a5)
  004f66:  4e ba e7 c0            jsr $3728(pc)
  004f6a:  7c 00                  moveq #$0, d6
  004f6c:  60 12                  bra.b $4f80
  004f6e:  3b 46 f2 20            move.w d6, -$de0(a5)
  004f72:  4e ba e6 de            jsr $3652(pc)
  004f76:  3f 06                  move.w d6, -(a7)
  004f78:  4e ba e5 86            jsr $3500(pc)
  004f7c:  54 8f                  addq.l #$2, a7
  004f7e:  52 46                  addq.w #$1, d6
  004f80:  0c 46 00 0a            cmpi.w #$a, d6
  004f84:  6d e8                  blt.b $4f6e
  004f86:  3b 47 ba 6a            move.w d7, -$4596(a5)
  004f8a:  4e ba e2 ca            jsr $3256(pc)
  004f8e:  1f 3c 00 ff            move.b #$ff, -(a7)
  004f92:  4e ba 03 68            jsr $52fc(pc)
  004f96:  54 8f                  addq.l #$2, a7
  004f98:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  004f9c:  4e 75                  rts 
  004f9e:  4e 56 00 00            link.w a6, #$0
  004fa2:  2f 3c 00 04 00 02      move.l #$40002, -(a7)
  004fa8:  3f 2e 00 08            move.w $8(a6), -(a7)
  004fac:  3f 2d f2 24            move.w -$ddc(a5), -(a7)
  004fb0:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  004fb4:  42 67                  clr.w -(a7)
  004fb6:  4e ba f5 ba            jsr $4572(pc)
  004fba:  4e 5e                  unlk a6
  004fbc:  4e 75                  rts 
  004fbe:  42 6d f2 2a            clr.w -$dd6(a5)
  004fc2:  4a 6d b9 3c            tst.w -$46c4(a5)
  004fc6:  67 10                  beq.b $4fd8
  004fc8:  1f 3c 00 02            move.b #$2, -(a7)
  004fcc:  48 6d a5 cc            pea.l -$5a34(a5)
  004fd0:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  004fd4:  4e 90                  jsr (a0)
  004fd6:  5c 8f                  addq.l #$6, a7
  004fd8:  4e ba 00 20            jsr $4ffa(pc)
  004fdc:  42 67                  clr.w -(a7)
  004fde:  4e ba f7 26            jsr $4706(pc)
  004fe2:  4e ba f6 c2            jsr $46a6(pc)
  004fe6:  4e ba f6 de            jsr $46c6(pc)
  004fea:  3e bc 00 01            move.w #$1, (a7)
  004fee:  4e ba f7 16            jsr $4706(pc)
  004ff2:  4e ba f6 f2            jsr $46e6(pc)
  004ff6:  54 8f                  addq.l #$2, a7
  004ff8:  4e 75                  rts 
  004ffa:  48 e7 01 18            movem.l d7/a3-a4, -(a7)
  004ffe:  3e 2d e6 aa            move.w -$1956(a5), d7
  005002:  70 0c                  moveq #$c, d0
  005004:  c1 c7                  muls.w d7, d0
  005006:  47 ed e6 ac            lea.l -$1954(a5), a3
  00500a:  d0 8b                  add.l a3, d0
  00500c:  26 40                  movea.l d0, a3
  00500e:  60 3e                  bra.b $504e
  005010:  53 47                  subq.w #$1, d7
  005012:  47 eb ff f4            lea.l -$c(a3), a3
  005016:  2b 53 a5 f4            move.l (a3), -$5a0c(a5)
  00501a:  2b 6b 00 04 a5 f8      move.l $4(a3), -$5a08(a5)
  005020:  28 6b 00 08            movea.l $8(a3), a4
  005024:  20 0c                  move.l a4, d0
  005026:  67 22                  beq.b $504a
  005028:  2f 0c                  move.l a4, -(a7)
  00502a:  48 6d a5 f4            pea.l -$5a0c(a5)
  00502e:  20 6d a3 ea            movea.l -$5c16(a5), a0
  005032:  4e 90                  jsr (a0)
  005034:  4a 6d f2 28            tst.w -$dd8(a5)
  005038:  50 8f                  addq.l #$8, a7
  00503a:  67 0a                  beq.b $5046
  00503c:  48 6d a5 f4            pea.l -$5a0c(a5)
  005040:  4e ba f5 88            jsr $45ca(pc)
  005044:  58 8f                  addq.l #$4, a7
  005046:  20 4c                  movea.l a4, a0
  005048:  a0 23                  dc.w $a023
  00504a:  42 ab 00 08            clr.l $8(a3)
  00504e:  4a 47                  tst.w d7
  005050:  66 be                  bne.b $5010
  005052:  42 6d e6 aa            clr.w -$1956(a5)
  005056:  4c df 18 80            movem.l (a7)+, d7/a3-a4
  00505a:  4e 75                  rts 
  00505c:  48 e7 01 38            movem.l d7/a2-a4, -(a7)
  005060:  3e 2d e6 aa            move.w -$1956(a5), d7
  005064:  70 0c                  moveq #$c, d0
  005066:  c1 c7                  muls.w d7, d0
  005068:  45 ed e6 ac            lea.l -$1954(a5), a2
  00506c:  d0 8a                  add.l a2, d0
  00506e:  24 40                  movea.l d0, a2
  005070:  60 16                  bra.b $5088
  005072:  53 47                  subq.w #$1, d7
  005074:  45 ea ff f4            lea.l -$c(a2), a2
  005078:  47 ea 00 08            lea.l $8(a2), a3
  00507c:  28 53                  movea.l (a3), a4
  00507e:  20 0c                  move.l a4, d0
  005080:  67 04                  beq.b $5086
  005082:  20 4c                  movea.l a4, a0
  005084:  a0 23                  dc.w $a023
  005086:  42 93                  clr.l (a3)
  005088:  4a 47                  tst.w d7
  00508a:  66 e6                  bne.b $5072
  00508c:  42 6d e6 aa            clr.w -$1956(a5)
  005090:  4c df 1c 80            movem.l (a7)+, d7/a2-a4
  005094:  4e 75                  rts 
  005096:  48 e7 0f 08            movem.l d4-d7/a4, -(a7)
  00509a:  7e 01                  moveq #$1, d7
  00509c:  de 6d f2 22            add.w -$dde(a5), d7
  0050a0:  7c f3                  moveq #$f3, d6
  0050a2:  dc 6d f2 26            add.w -$dda(a5), d6
  0050a6:  70 00                  moveq #$0, d0
  0050a8:  10 2d ba 97            move.b -$4569(a5), d0
  0050ac:  3a 06                  move.w d6, d5
  0050ae:  9a 40                  sub.w d0, d5
  0050b0:  38 2d ba 32            move.w -$45ce(a5), d4
  0050b4:  42 6d ba 32            clr.w -$45ce(a5)
  0050b8:  20 07                  move.l d7, d0
  0050ba:  e7 48                  lsl.w #$3, d0
  0050bc:  38 40                  movea.w d0, a4
  0050be:  d9 cc                  adda.l a4, a4
  0050c0:  41 ed 99 14            lea.l -$66ec(a5), a0
  0050c4:  d9 c8                  adda.l a0, a4
  0050c6:  3f 3c 00 01            move.w #$1, -(a7)
  0050ca:  20 4d                  movea.l a5, a0
  0050cc:  d0 c6                  adda.w d6, a0
  0050ce:  d0 c6                  adda.w d6, a0
  0050d0:  3f 28 9d 12            move.w -$62ee(a0), -(a7)
  0050d4:  3f 14                  move.w (a4), -(a7)
  0050d6:  2f 3c 00 06 00 63      move.l #$60063, -(a7)
  0050dc:  4e ad 01 12            jsr $112(a5)
  0050e0:  3b 6d a5 f4 bd 9a      move.w -$5a0c(a5), -$4266(a5)
  0050e6:  3b 6d a5 fa ba e2      move.w -$5a06(a5), -$451e(a5)
  0050ec:  3e bc 00 01            move.w #$1, (a7)
  0050f0:  20 4d                  movea.l a5, a0
  0050f2:  d0 c5                  adda.w d5, a0
  0050f4:  d0 c5                  adda.w d5, a0
  0050f6:  3f 28 9d 12            move.w -$62ee(a0), -(a7)
  0050fa:  3f 14                  move.w (a4), -(a7)
  0050fc:  2f 3c 00 06 00 21      move.l #$60021, -(a7)
  005102:  4e ad 01 12            jsr $112(a5)
  005106:  3b 6d a5 f8 bd 98      move.w -$5a08(a5), -$4268(a5)
  00510c:  3b 44 ba 32            move.w d4, -$45ce(a5)
  005110:  3e 86                  move.w d6, (a7)
  005112:  42 67                  clr.w -(a7)
  005114:  3f 07                  move.w d7, -(a7)
  005116:  2f 3c 00 06 00 63      move.l #$60063, -(a7)
  00511c:  4e ba f2 5c            jsr $437a(pc)
  005120:  70 00                  moveq #$0, d0
  005122:  10 2d f1 5e            move.b -$ea2(a5), d0
  005126:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  00512a:  4f ef 00 1a            lea.l $1a(a7), a7
  00512e:  67 1a                  beq.b $514a
  005130:  4a 2d ba 97            tst.b -$4569(a5)
  005134:  67 14                  beq.b $514a
  005136:  3f 06                  move.w d6, -(a7)
  005138:  42 67                  clr.w -(a7)
  00513a:  3f 07                  move.w d7, -(a7)
  00513c:  2f 3c 00 06 00 90      move.l #$60090, -(a7)
  005142:  4e ba f2 36            jsr $437a(pc)
  005146:  4f ef 00 0a            lea.l $a(a7), a7
  00514a:  3b 6d bd 9a bd 74      move.w -$4266(a5), -$428c(a5)
  005150:  3f 05                  move.w d5, -(a7)
  005152:  42 67                  clr.w -(a7)
  005154:  3f 07                  move.w d7, -(a7)
  005156:  2f 3c 00 06 00 21      move.l #$60021, -(a7)
  00515c:  4e ba f2 1c            jsr $437a(pc)
  005160:  4f ef 00 0a            lea.l $a(a7), a7
  005164:  4c df 10 f0            movem.l (a7)+, d4-d7/a4
  005168:  4e 75                  rts 
  00516a:  4e 56 00 00            link.w a6, #$0
  00516e:  48 e7 03 00            movem.l d6-d7, -(a7)
  005172:  3e 2e 00 08            move.w $8(a6), d7
  005176:  4a 47                  tst.w d7
  005178:  67 20                  beq.b $519a
  00517a:  20 4d                  movea.l a5, a0
  00517c:  d0 c7                  adda.w d7, a0
  00517e:  d0 c7                  adda.w d7, a0
  005180:  3c 28 aa 36            move.w -$55ca(a0), d6
  005184:  48 c6                  ext.l d6
  005186:  41 ed e9 1e            lea.l -$16e2(a5), a0
  00518a:  d1 c6                  adda.l d6, a0
  00518c:  2b 48 bd 82            move.l a0, -$427e(a5)
  005190:  43 ed eb ee            lea.l -$1412(a5), a1
  005194:  d3 c6                  adda.l d6, a1
  005196:  2b 49 bd 86            move.l a1, -$427a(a5)
  00519a:  3b 47 bd 80            move.w d7, -$4280(a5)
  00519e:  4c df 00 c0            movem.l (a7)+, d6-d7
  0051a2:  4e 5e                  unlk a6
  0051a4:  4e 75                  rts 
  0051a6:  4a 2d ba 96            tst.b -$456a(a5)
  0051aa:  66 00 00 82            bne.w $522e
  0051ae:  4a 2d b9 6d            tst.b -$4693(a5)
  0051b2:  66 7a                  bne.b $522e
  0051b4:  10 2d b9 6e            move.b -$4692(a5), d0
  0051b8:  48 80                  ext.w d0
  0051ba:  b0 6d f2 20            cmp.w -$de0(a5), d0
  0051be:  66 6e                  bne.b $522e
  0051c0:  41 ed 04 a2            lea.l $4a2(a5), a0
  0051c4:  2b 48 bd 70            move.l a0, -$4290(a5)
  0051c8:  70 00                  moveq #$0, d0
  0051ca:  10 2d ba 94            move.b -$456c(a5), d0
  0051ce:  0c 40 00 19            cmpi.w #$19, d0
  0051d2:  62 4e                  bhi.b $5222
  0051d4:  43 fa 00 5a            lea.l $5230(pc), a1
  0051d8:  d0 40                  add.w d0, d0
  0051da:  d2 f1 00 00            adda.w (a1, d0.w), a1
  0051de:  4e d1                  jmp (a1)
  0051e0:  0c 2d 00 05 ba 94      cmpi.b #$5, -$456c(a5)
  0051e6:  57 c0                  seq.b d0
  0051e8:  44 00                  neg.b d0
  0051ea:  48 80                  ext.w d0
  0051ec:  d0 6d f2 26            add.w -$dda(a5), d0
  0051f0:  3f 00                  move.w d0, -(a7)
  0051f2:  42 67                  clr.w -(a7)
  0051f4:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  0051f8:  70 00                  moveq #$0, d0
  0051fa:  10 2d b9 6a            move.b -$4696(a5), d0
  0051fe:  20 4d                  movea.l a5, a0
  005200:  d0 c0                  adda.w d0, a0
  005202:  d0 c0                  adda.w d0, a0
  005204:  3f 28 a9 72            move.w -$568e(a0), -(a7)
  005208:  3f 3c 00 06            move.w #$6, -(a7)
  00520c:  4e ba f1 ca            jsr $43d8(pc)
  005210:  42 57                  clr.w (a7)
  005212:  4e ba eb 00            jsr $3d14(pc)
  005216:  42 57                  clr.w (a7)
  005218:  4e ba eb a4            jsr $3dbe(pc)
  00521c:  4f ef 00 0a            lea.l $a(a7), a7
  005220:  60 04                  bra.b $5226
  005222:  4e ba 00 b8            jsr $52dc(pc)
  005226:  41 ed 04 9a            lea.l $49a(a5), a0
  00522a:  2b 48 bd 70            move.l a0, -$4290(a5)
  00522e:  4e 75                  rts 
  005230:  ff f2                  dc.w $fff2
  005232:  ff b0                  dc.w $ffb0
  005234:  ff f2                  dc.w $fff2
  005236:  ff b0                  dc.w $ffb0
  005238:  ff b0                  dc.w $ffb0
  00523a:  ff b0                  dc.w $ffb0
  00523c:  ff b0                  dc.w $ffb0
  00523e:  ff b0                  dc.w $ffb0
  005240:  ff b0                  dc.w $ffb0
  005242:  ff f2                  dc.w $fff2
  005244:  ff f2                  dc.w $fff2
  005246:  ff b0                  dc.w $ffb0
  005248:  ff f2                  dc.w $fff2
  00524a:  ff f2                  dc.w $fff2
  00524c:  ff f2                  dc.w $fff2
  00524e:  ff f2                  dc.w $fff2
  005250:  ff b0                  dc.w $ffb0
  005252:  ff f2                  dc.w $fff2
  005254:  ff b0                  dc.w $ffb0
  005256:  ff b0                  dc.w $ffb0
  005258:  ff f2                  dc.w $fff2
  00525a:  ff f2                  dc.w $fff2
  00525c:  ff f2                  dc.w $fff2
  00525e:  ff f2                  dc.w $fff2
  005260:  ff f2                  dc.w $fff2
  005262:  ff b0                  dc.w $ffb0
  005264:  4a 2d ba 96            tst.b -$456a(a5)
  005268:  66 0e                  bne.b $5278
  00526a:  41 ed 04 a2            lea.l $4a2(a5), a0
  00526e:  2b 48 bd 70            move.l a0, -$4290(a5)
  005272:  4e ba 00 68            jsr $52dc(pc)
  005276:  60 5a                  bra.b $52d2
  005278:  4a 2d ba 94            tst.b -$456c(a5)
  00527c:  67 54                  beq.b $52d2
  00527e:  4a 6d f2 20            tst.w -$de0(a5)
  005282:  6f 4e                  ble.b $52d2
  005284:  70 fe                  moveq #$fe, d0
  005286:  d0 6d f2 20            add.w -$de0(a5), d0
  00528a:  3f 00                  move.w d0, -(a7)
  00528c:  3f 2d f2 1e            move.w -$de2(a5), -(a7)
  005290:  4e ba e2 b8            jsr $354a(pc)
  005294:  72 00                  moveq #$0, d1
  005296:  12 00                  move.b d0, d1
  005298:  4a 41                  tst.w d1
  00529a:  58 8f                  addq.l #$4, a7
  00529c:  66 34                  bne.b $52d2
  00529e:  41 ed 04 a2            lea.l $4a2(a5), a0
  0052a2:  2b 48 bd 70            move.l a0, -$4290(a5)
  0052a6:  4e ba 00 34            jsr $52dc(pc)
  0052aa:  41 ed 04 9a            lea.l $49a(a5), a0
  0052ae:  2b 48 bd 70            move.l a0, -$4290(a5)
  0052b2:  4e ba 00 28            jsr $52dc(pc)
  0052b6:  30 2d f2 1e            move.w -$de2(a5), d0
  0052ba:  20 4d                  movea.l a5, a0
  0052bc:  d0 c0                  adda.w d0, a0
  0052be:  d0 c0                  adda.w d0, a0
  0052c0:  32 28 b6 46            move.w -$49ba(a0), d1
  0052c4:  d2 6d f2 20            add.w -$de0(a5), d1
  0052c8:  20 4d                  movea.l a5, a0
  0052ca:  d0 c1                  adda.w d1, a0
  0052cc:  11 7c 00 ff bc 44      move.b #$ff, -$43bc(a0)
  0052d2:  41 ed 04 9a            lea.l $49a(a5), a0
  0052d6:  2b 48 bd 70            move.l a0, -$4290(a5)
  0052da:  4e 75                  rts 
  0052dc:  4e ba e6 e8            jsr $39c6(pc)
  0052e0:  4e ba e9 28            jsr $3c0a(pc)
  0052e4:  4e ba eb 32            jsr $3e18(pc)
  0052e8:  4e ba eb c6            jsr $3eb0(pc)
  0052ec:  42 67                  clr.w -(a7)
  0052ee:  4e ba ea 24            jsr $3d14(pc)
  0052f2:  42 57                  clr.w (a7)
  0052f4:  4e ba ea c8            jsr $3dbe(pc)
  0052f8:  54 8f                  addq.l #$2, a7
  0052fa:  4e 75                  rts 
  0052fc:  4e 56 00 00            link.w a6, #$0
  005300:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  005304:  3e 2d bd a4            move.w -$425c(a5), d7
  005308:  4a 47                  tst.w d7
  00530a:  67 60                  beq.b $536c
  00530c:  42 6d f3 80            clr.w -$c80(a5)
  005310:  7c ff                  moveq #$ff, d6
  005312:  dc 47                  add.w d7, d6
  005314:  70 14                  moveq #$14, d0
  005316:  c1 c6                  muls.w d6, d0
  005318:  49 ed e2 c2            lea.l -$1d3e(a5), a4
  00531c:  d0 8c                  add.l a4, d0
  00531e:  28 40                  movea.l d0, a4
  005320:  60 22                  bra.b $5344
  005322:  10 2c 00 0b            move.b $b(a4), d0
  005326:  b0 2e 00 08            cmp.b $8(a6), d0
  00532a:  66 12                  bne.b $533e
  00532c:  30 2d f3 80            move.w -$c80(a5), d0
  005330:  20 4d                  movea.l a5, a0
  005332:  d0 c0                  adda.w d0, a0
  005334:  d0 c0                  adda.w d0, a0
  005336:  31 46 f3 1c            move.w d6, -$ce4(a0)
  00533a:  52 6d f3 80            addq.w #$1, -$c80(a5)
  00533e:  53 46                  subq.w #$1, d6
  005340:  49 ec ff ec            lea.l -$14(a4), a4
  005344:  4a 46                  tst.w d6
  005346:  6c da                  bge.b $5322
  005348:  4a 6d f3 80            tst.w -$c80(a5)
  00534c:  67 1e                  beq.b $536c
  00534e:  4e ba 00 24            jsr $5374(pc)
  005352:  7c 00                  moveq #$0, d6
  005354:  49 ed f3 1c            lea.l -$ce4(a5), a4
  005358:  60 0c                  bra.b $5366
  00535a:  3f 14                  move.w (a4), -(a7)
  00535c:  4e ba 01 24            jsr $5482(pc)
  005360:  54 8f                  addq.l #$2, a7
  005362:  52 46                  addq.w #$1, d6
  005364:  54 8c                  addq.l #$2, a4
  005366:  bc 6d f3 80            cmp.w -$c80(a5), d6
  00536a:  6d ee                  blt.b $535a
  00536c:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  005370:  4e 5e                  unlk a6
  005372:  4e 75                  rts 
  005374:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  005378:  7e ff                  moveq #$ff, d7
  00537a:  de 6d f3 80            add.w -$c80(a5), d7
  00537e:  7c 00                  moveq #$0, d6
  005380:  7a 00                  moveq #$0, d5
  005382:  49 ed f3 1c            lea.l -$ce4(a5), a4
  005386:  60 26                  bra.b $53ae
  005388:  70 01                  moveq #$1, d0
  00538a:  d0 45                  add.w d5, d0
  00538c:  3f 00                  move.w d0, -(a7)
  00538e:  3f 05                  move.w d5, -(a7)
  005390:  4e ba 00 2a            jsr $53bc(pc)
  005394:  4a 00                  tst.b d0
  005396:  58 8f                  addq.l #$4, a7
  005398:  67 10                  beq.b $53aa
  00539a:  3c 14                  move.w (a4), d6
  00539c:  47 ed f3 1e            lea.l -$ce2(a5), a3
  0053a0:  d6 c5                  adda.w d5, a3
  0053a2:  d6 c5                  adda.w d5, a3
  0053a4:  38 93                  move.w (a3), (a4)
  0053a6:  36 86                  move.w d6, (a3)
  0053a8:  7c 01                  moveq #$1, d6
  0053aa:  52 45                  addq.w #$1, d5
  0053ac:  54 8c                  addq.l #$2, a4
  0053ae:  be 45                  cmp.w d5, d7
  0053b0:  6e d6                  bgt.b $5388
  0053b2:  4a 46                  tst.w d6
  0053b4:  66 c8                  bne.b $537e
  0053b6:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  0053ba:  4e 75                  rts 
  0053bc:  4e 56 00 00            link.w a6, #$0
  0053c0:  48 e7 07 18            movem.l d5-d7/a3-a4, -(a7)
  0053c4:  20 4d                  movea.l a5, a0
  0053c6:  30 2e 00 08            move.w $8(a6), d0
  0053ca:  d0 c0                  adda.w d0, a0
  0053cc:  d0 c0                  adda.w d0, a0
  0053ce:  3e 28 f3 1c            move.w -$ce4(a0), d7
  0053d2:  20 4d                  movea.l a5, a0
  0053d4:  32 2e 00 0a            move.w $a(a6), d1
  0053d8:  d0 c1                  adda.w d1, a0
  0053da:  d0 c1                  adda.w d1, a0
  0053dc:  3c 28 f3 1c            move.w -$ce4(a0), d6
  0053e0:  74 14                  moveq #$14, d2
  0053e2:  c5 c7                  muls.w d7, d2
  0053e4:  49 ed e2 c2            lea.l -$1d3e(a5), a4
  0053e8:  d4 8c                  add.l a4, d2
  0053ea:  28 42                  movea.l d2, a4
  0053ec:  7e 00                  moveq #$0, d7
  0053ee:  1e 2c 00 0a            move.b $a(a4), d7
  0053f2:  74 14                  moveq #$14, d2
  0053f4:  c5 c6                  muls.w d6, d2
  0053f6:  47 ed e2 c2            lea.l -$1d3e(a5), a3
  0053fa:  d4 8b                  add.l a3, d2
  0053fc:  26 42                  movea.l d2, a3
  0053fe:  7c 00                  moveq #$0, d6
  005400:  1c 2b 00 0a            move.b $a(a3), d6
  005404:  0c 47 00 01            cmpi.w #$1, d7
  005408:  66 04                  bne.b $540e
  00540a:  70 01                  moveq #$1, d0
  00540c:  60 6c                  bra.b $547a
  00540e:  0c 46 00 01            cmpi.w #$1, d6
  005412:  66 04                  bne.b $5418
  005414:  70 00                  moveq #$0, d0
  005416:  60 62                  bra.b $547a
  005418:  0c 47 00 02            cmpi.w #$2, d7
  00541c:  66 18                  bne.b $5436
  00541e:  3a 2c 00 02            move.w $2(a4), d5
  005422:  0c 45 00 07            cmpi.w #$7, d5
  005426:  66 04                  bne.b $542c
  005428:  70 00                  moveq #$0, d0
  00542a:  60 4e                  bra.b $547a
  00542c:  0c 45 00 21            cmpi.w #$21, d5
  005430:  66 04                  bne.b $5436
  005432:  70 01                  moveq #$1, d0
  005434:  60 44                  bra.b $547a
  005436:  0c 46 00 02            cmpi.w #$2, d6
  00543a:  66 18                  bne.b $5454
  00543c:  3a 2b 00 02            move.w $2(a3), d5
  005440:  0c 45 00 07            cmpi.w #$7, d5
  005444:  66 04                  bne.b $544a
  005446:  70 01                  moveq #$1, d0
  005448:  60 30                  bra.b $547a
  00544a:  0c 45 00 21            cmpi.w #$21, d5
  00544e:  66 04                  bne.b $5454
  005450:  70 00                  moveq #$0, d0
  005452:  60 26                  bra.b $547a
  005454:  0c 47 00 80            cmpi.w #$80, d7
  005458:  66 14                  bne.b $546e
  00545a:  0c 46 00 80            cmpi.w #$80, d6
  00545e:  66 0e                  bne.b $546e
  005460:  30 2c 00 06            move.w $6(a4), d0
  005464:  b0 6b 00 06            cmp.w $6(a3), d0
  005468:  5d c0                  slt.b d0
  00546a:  44 00                  neg.b d0
  00546c:  60 0c                  bra.b $547a
  00546e:  30 2c 00 06            move.w $6(a4), d0
  005472:  b0 6b 00 06            cmp.w $6(a3), d0
  005476:  5e c0                  sgt.b d0
  005478:  44 00                  neg.b d0
  00547a:  4c df 18 e0            movem.l (a7)+, d5-d7/a3-a4
  00547e:  4e 5e                  unlk a6
  005480:  4e 75                  rts 
  005482:  4e 56 00 00            link.w a6, #$0
  005486:  3f 2e 00 08            move.w $8(a6), -(a7)
  00548a:  4e ba 01 ae            jsr $563a(pc)
  00548e:  4a 40                  tst.w d0
  005490:  54 8f                  addq.l #$2, a7
  005492:  67 28                  beq.b $54bc
  005494:  6b 00 01 a0            bmi.w $5636
  005498:  5b 40                  subq.w #$5, d0
  00549a:  67 00 01 72            beq.w $560e
  00549e:  6a 10                  bpl.b $54b0
  0054a0:  54 40                  addq.w #$2, d0
  0054a2:  67 00 01 40            beq.w $55e4
  0054a6:  6a 14                  bpl.b $54bc
  0054a8:  52 40                  addq.w #$1, d0
  0054aa:  6a 00 01 62            bpl.w $560e
  0054ae:  60 58                  bra.b $5508
  0054b0:  04 40 00 7b            subi.w #$7b, d0
  0054b4:  67 00 00 92            beq.w $5548
  0054b8:  60 00 01 7c            bra.w $5636
  0054bc:  0c 6d 00 ff ba f4      cmpi.w #$ff, -$450c(a5)
  0054c2:  67 00 01 72            beq.w $5636
  0054c6:  4a 6d ba 8e            tst.w -$4572(a5)
  0054ca:  67 10                  beq.b $54dc
  0054cc:  30 2d ba 8e            move.w -$4572(a5), d0
  0054d0:  48 c0                  ext.l d0
  0054d2:  81 fc 00 02            divs.w #$2, d0
  0054d6:  48 40                  swap d0
  0054d8:  4a 40                  tst.w d0
  0054da:  67 2c                  beq.b $5508
  0054dc:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  0054e0:  3f 2d ba f8            move.w -$4508(a5), -(a7)
  0054e4:  70 00                  moveq #$0, d0
  0054e6:  10 2d bd 7e            move.b -$4282(a5), d0
  0054ea:  3f 00                  move.w d0, -(a7)
  0054ec:  3f 2d bd 7a            move.w -$4286(a5), -(a7)
  0054f0:  70 01                  moveq #$1, d0
  0054f2:  d0 6d ba f4            add.w -$450c(a5), d0
  0054f6:  3f 00                  move.w d0, -(a7)
  0054f8:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  0054fc:  4e ba ee da            jsr $43d8(pc)
  005500:  4f ef 00 0a            lea.l $a(a7), a7
  005504:  60 00 01 30            bra.w $5636
  005508:  4a 6d ba 8e            tst.w -$4572(a5)
  00550c:  6c 0a                  bge.b $5518
  00550e:  3f 3c 00 29            move.w #$29, -(a7)
  005512:  4e ad 03 92            jsr $392(a5)
  005516:  54 8f                  addq.l #$2, a7
  005518:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  00551c:  52 2d aa 36            addq.b #$1, -$55ca(a5)
  005520:  3f 2d ba f8            move.w -$4508(a5), -(a7)
  005524:  70 00                  moveq #$0, d0
  005526:  10 2d bd 7e            move.b -$4282(a5), d0
  00552a:  3f 00                  move.w d0, -(a7)
  00552c:  3f 2d bd 7a            move.w -$4286(a5), -(a7)
  005530:  70 01                  moveq #$1, d0
  005532:  d0 6d ba f4            add.w -$450c(a5), d0
  005536:  3f 00                  move.w d0, -(a7)
  005538:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  00553c:  4e ba ee 9a            jsr $43d8(pc)
  005540:  4f ef 00 0a            lea.l $a(a7), a7
  005544:  60 00 00 f0            bra.w $5636
  005548:  1b 7c 00 ff ba f1      move.b #$ff, -$450f(a5)
  00554e:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  005552:  70 fd                  moveq #$fd, d0
  005554:  d0 6d ba f8            add.w -$4508(a5), d0
  005558:  3f 00                  move.w d0, -(a7)
  00555a:  70 00                  moveq #$0, d0
  00555c:  10 2d bd 7e            move.b -$4282(a5), d0
  005560:  3f 00                  move.w d0, -(a7)
  005562:  3f 2d bd 7a            move.w -$4286(a5), -(a7)
  005566:  30 2d ba f4            move.w -$450c(a5), d0
  00556a:  20 4d                  movea.l a5, a0
  00556c:  d0 c0                  adda.w d0, a0
  00556e:  72 00                  moveq #$0, d1
  005570:  12 28 b5 74            move.b -$4a8c(a0), d1
  005574:  3f 01                  move.w d1, -(a7)
  005576:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  00557a:  4e ba ee 5c            jsr $43d8(pc)
  00557e:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  005582:  3e ad ba f8            move.w -$4508(a5), (a7)
  005586:  70 00                  moveq #$0, d0
  005588:  10 2d bd 7e            move.b -$4282(a5), d0
  00558c:  3f 00                  move.w d0, -(a7)
  00558e:  3f 2d bd 7a            move.w -$4286(a5), -(a7)
  005592:  30 2d ba f4            move.w -$450c(a5), d0
  005596:  20 4d                  movea.l a5, a0
  005598:  d0 c0                  adda.w d0, a0
  00559a:  72 00                  moveq #$0, d1
  00559c:  12 28 b5 8c            move.b -$4a74(a0), d1
  0055a0:  3f 01                  move.w d1, -(a7)
  0055a2:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  0055a6:  4e ba ee 30            jsr $43d8(pc)
  0055aa:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  0055ae:  70 ff                  moveq #$ff, d0
  0055b0:  d0 6d ba f8            add.w -$4508(a5), d0
  0055b4:  3e 80                  move.w d0, (a7)
  0055b6:  70 00                  moveq #$0, d0
  0055b8:  10 2d bd 7e            move.b -$4282(a5), d0
  0055bc:  3f 00                  move.w d0, -(a7)
  0055be:  70 04                  moveq #$4, d0
  0055c0:  d0 6d ba f6            add.w -$450a(a5), d0
  0055c4:  3f 00                  move.w d0, -(a7)
  0055c6:  30 2d ba f4            move.w -$450c(a5), d0
  0055ca:  20 4d                  movea.l a5, a0
  0055cc:  d0 c0                  adda.w d0, a0
  0055ce:  72 00                  moveq #$0, d1
  0055d0:  12 28 b5 80            move.b -$4a80(a0), d1
  0055d4:  3f 01                  move.w d1, -(a7)
  0055d6:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  0055da:  4e ba ed fc            jsr $43d8(pc)
  0055de:  4f ef 00 1a            lea.l $1a(a7), a7
  0055e2:  60 52                  bra.b $5636
  0055e4:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  0055e8:  3f 2d ba f8            move.w -$4508(a5), -(a7)
  0055ec:  70 00                  moveq #$0, d0
  0055ee:  10 2d bd 7e            move.b -$4282(a5), d0
  0055f2:  3f 00                  move.w d0, -(a7)
  0055f4:  3f 2d bd 7a            move.w -$4286(a5), -(a7)
  0055f8:  70 01                  moveq #$1, d0
  0055fa:  d0 6d ba f4            add.w -$450c(a5), d0
  0055fe:  3f 00                  move.w d0, -(a7)
  005600:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  005604:  4e ba ed d2            jsr $43d8(pc)
  005608:  4f ef 00 0a            lea.l $a(a7), a7
  00560c:  60 28                  bra.b $5636
  00560e:  52 2d aa 35            addq.b #$1, -$55cb(a5)
  005612:  3f 2d ba f8            move.w -$4508(a5), -(a7)
  005616:  70 00                  moveq #$0, d0
  005618:  10 2d bd 7e            move.b -$4282(a5), d0
  00561c:  3f 00                  move.w d0, -(a7)
  00561e:  3f 2d bd 7a            move.w -$4286(a5), -(a7)
  005622:  70 01                  moveq #$1, d0
  005624:  d0 6d ba f4            add.w -$450c(a5), d0
  005628:  3f 00                  move.w d0, -(a7)
  00562a:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  00562e:  4e ba ed a8            jsr $43d8(pc)
  005632:  4f ef 00 0a            lea.l $a(a7), a7
  005636:  4e 5e                  unlk a6
  005638:  4e 75                  rts 
  00563a:  4e 56 00 00            link.w a6, #$0
  00563e:  2f 0c                  move.l a4, -(a7)
  005640:  70 14                  moveq #$14, d0
  005642:  c1 ee 00 08            muls.w $8(a6), d0
  005646:  49 ed e2 c2            lea.l -$1d3e(a5), a4
  00564a:  d0 8c                  add.l a4, d0
  00564c:  28 40                  movea.l d0, a4
  00564e:  10 2c 00 04            move.b $4(a4), d0
  005652:  48 80                  ext.w d0
  005654:  3b 40 ba f6            move.w d0, -$450a(a5)
  005658:  3b 40 bd 7a            move.w d0, -$4286(a5)
  00565c:  1b 6c 00 05 bd 7e      move.b $5(a4), -$4282(a5)
  005662:  32 2c 00 06            move.w $6(a4), d1
  005666:  3b 41 ba f8            move.w d1, -$4508(a5)
  00566a:  3b 41 bd 7c            move.w d1, -$4284(a5)
  00566e:  3b 54 ba f2            move.w (a4), -$450e(a5)
  005672:  3b 6c 00 02 ba f4      move.w $2(a4), -$450c(a5)
  005678:  1b 6c 00 09 ba f1      move.b $9(a4), -$450f(a5)
  00567e:  3b 6c 00 0c ba fe      move.w $c(a4), -$4502(a5)
  005684:  3b 6c 00 10 bb 00      move.w $10(a4), -$4500(a5)
  00568a:  3b 6c 00 0e bb 02      move.w $e(a4), -$44fe(a5)
  005690:  3b 6c 00 12 bb 04      move.w $12(a4), -$44fc(a5)
  005696:  70 00                  moveq #$0, d0
  005698:  10 2c 00 0a            move.b $a(a4), d0
  00569c:  28 5f                  movea.l (a7)+, a4
  00569e:  4e 5e                  unlk a6
  0056a0:  4e 75                  rts 
  0056a2:  4e ad 01 ea            jsr $1ea(a5)
  0056a6:  4e ba 00 10            jsr $56b8(pc)
  0056aa:  4e ba 00 32            jsr $56de(pc)
  0056ae:  4e ad 02 a2            jsr $2a2(a5)
  0056b2:  4e ad 03 8a            jsr $38a(a5)
  0056b6:  4e 75                  rts 
  0056b8:  4a 2d b9 73            tst.b -$468d(a5)
  0056bc:  67 1e                  beq.b $56dc
  0056be:  10 2d b9 73            move.b -$468d(a5), d0
  0056c2:  48 80                  ext.w d0
  0056c4:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  0056c8:  66 12                  bne.b $56dc
  0056ca:  4e ba 00 3a            jsr $5706(pc)
  0056ce:  4a 6d ba 50            tst.w -$45b0(a5)
  0056d2:  6c 04                  bge.b $56d8
  0056d4:  4e ad 03 52            jsr $352(a5)
  0056d8:  4e ad 03 5a            jsr $35a(a5)
  0056dc:  4e 75                  rts 
  0056de:  0c 2d 00 56 b9 7f      cmpi.b #$56, -$4681(a5)
  0056e4:  67 1e                  beq.b $5704
  0056e6:  10 2d b9 85            move.b -$467b(a5), d0
  0056ea:  48 80                  ext.w d0
  0056ec:  b0 6d ba 6a            cmp.w -$4596(a5), d0
  0056f0:  66 12                  bne.b $5704
  0056f2:  4e ba 00 62            jsr $5756(pc)
  0056f6:  4a 6d ba 52            tst.w -$45ae(a5)
  0056fa:  6c 04                  bge.b $5700
  0056fc:  4e ad 03 52            jsr $352(a5)
  005700:  4e ad 03 5a            jsr $35a(a5)
  005704:  4e 75                  rts 
  005706:  4e ad 02 8a            jsr $28a(a5)
  00570a:  4e ad 02 42            jsr $242(a5)
  00570e:  4e ba 01 36            jsr $5846(pc)
  005712:  4e ad 03 42            jsr $342(a5)
  005716:  4e ad 02 c2            jsr $2c2(a5)
  00571a:  4e ad 03 4a            jsr $34a(a5)
  00571e:  4e ad 01 da            jsr $1da(a5)
  005722:  4e ad 01 e2            jsr $1e2(a5)
  005726:  4e ad 03 3a            jsr $33a(a5)
  00572a:  0c 6d 00 04 a9 0c      cmpi.w #$4, -$56f4(a5)
  005730:  66 1a                  bne.b $574c
  005732:  0c 2d 00 04 b9 4f      cmpi.b #$4, -$46b1(a5)
  005738:  66 12                  bne.b $574c
  00573a:  0c 6d 00 4d ba 3c      cmpi.w #$4d, -$45c4(a5)
  005740:  66 0a                  bne.b $574c
  005742:  3f 3c 00 04            move.w #$4, -(a7)
  005746:  4e ba cb 90            jsr $22d8(pc)
  00574a:  54 8f                  addq.l #$2, a7
  00574c:  42 27                  clr.b -(a7)
  00574e:  4e ba 00 70            jsr $57c0(pc)
  005752:  54 8f                  addq.l #$2, a7
  005754:  4e 75                  rts 
  005756:  2f 07                  move.l d7, -(a7)
  005758:  4e ad 02 9a            jsr $29a(a5)
  00575c:  4e ad 02 42            jsr $242(a5)
  005760:  4e ba 00 e4            jsr $5846(pc)
  005764:  4e ad 03 42            jsr $342(a5)
  005768:  4e ad 02 c2            jsr $2c2(a5)
  00576c:  4e ad 03 4a            jsr $34a(a5)
  005770:  4e ad 01 da            jsr $1da(a5)
  005774:  4e ad 01 e2            jsr $1e2(a5)
  005778:  4e ad 03 3a            jsr $33a(a5)
  00577c:  0c 2d 00 01 b9 51      cmpi.b #$1, -$46af(a5)
  005782:  66 20                  bne.b $57a4
  005784:  0c 6d 00 04 a9 0c      cmpi.w #$4, -$56f4(a5)
  00578a:  66 14                  bne.b $57a0
  00578c:  0c 2d 00 04 b9 4f      cmpi.b #$4, -$46b1(a5)
  005792:  66 0c                  bne.b $57a0
  005794:  3b 6d 9a 24 bb 02      move.w -$65dc(a5), -$44fe(a5)
  00579a:  3b 6d 9b 94 bb 04      move.w -$646c(a5), -$44fc(a5)
  0057a0:  7e 01                  moveq #$1, d7
  0057a2:  60 10                  bra.b $57b4
  0057a4:  0c 2d 00 b9 b9 46      cmpi.b #$b9, -$46ba(a5)
  0057aa:  66 06                  bne.b $57b2
  0057ac:  1b 7c 00 ff ba f0      move.b #$ff, -$4510(a5)
  0057b2:  7e 02                  moveq #$2, d7
  0057b4:  1f 07                  move.b d7, -(a7)
  0057b6:  4e ba 00 08            jsr $57c0(pc)
  0057ba:  54 8f                  addq.l #$2, a7
  0057bc:  2e 1f                  move.l (a7)+, d7
  0057be:  4e 75                  rts 
  0057c0:  4e 56 00 00            link.w a6, #$0
  0057c4:  48 e7 01 08            movem.l d7/a4, -(a7)
  0057c8:  3e 2d bd a4            move.w -$425c(a5), d7
  0057cc:  0c 47 00 32            cmpi.w #$32, d7
  0057d0:  6c 6a                  bge.b $583c
  0057d2:  70 14                  moveq #$14, d0
  0057d4:  c1 c7                  muls.w d7, d0
  0057d6:  49 ed e2 c2            lea.l -$1d3e(a5), a4
  0057da:  d0 8c                  add.l a4, d0
  0057dc:  28 40                  movea.l d0, a4
  0057de:  38 ad ba f2            move.w -$450e(a5), (a4)
  0057e2:  39 6d ba f4 00 02      move.w -$450c(a5), $2(a4)
  0057e8:  48 6c 00 05            pea.l $5(a4)
  0057ec:  48 6c 00 04            pea.l $4(a4)
  0057f0:  3f 2d ba f6            move.w -$450a(a5), -(a7)
  0057f4:  4e ba 01 54            jsr $594a(pc)
  0057f8:  39 6d ba f8 00 06      move.w -$4508(a5), $6(a4)
  0057fe:  42 2c 00 08            clr.b $8(a4)
  005802:  19 6d ba f1 00 09      move.b -$450f(a5), $9(a4)
  005808:  19 6e 00 08 00 0a      move.b $8(a6), $a(a4)
  00580e:  19 6d ba f0 00 0b      move.b -$4510(a5), $b(a4)
  005814:  39 6d ba fe 00 0c      move.w -$4502(a5), $c(a4)
  00581a:  39 6d bb 02 00 0e      move.w -$44fe(a5), $e(a4)
  005820:  39 6d bb 00 00 10      move.w -$4500(a5), $10(a4)
  005826:  39 6d bb 04 00 12      move.w -$44fc(a5), $12(a4)
  00582c:  10 2d ba f0            move.b -$4510(a5), d0
  005830:  48 80                  ext.w d0
  005832:  3e 80                  move.w d0, (a7)
  005834:  4e ba cb 6e            jsr $23a4(pc)
  005838:  52 6d bd a4            addq.w #$1, -$425c(a5)
  00583c:  4c ee 10 80 ff f8      movem.l -$8(a6), d7/a4
  005842:  4e 5e                  unlk a6
  005844:  4e 75                  rts 
  005846:  48 e7 03 08            movem.l d6-d7/a4, -(a7)
  00584a:  4e ad 02 a2            jsr $2a2(a5)
  00584e:  4e ad 02 52            jsr $252(a5)
  005852:  1b 6d b9 49 ba f1      move.b -$46b7(a5), -$450f(a5)
  005858:  0c 2d 00 ff b9 8e      cmpi.b #$ff, -$4672(a5)
  00585e:  66 08                  bne.b $5868
  005860:  3b 7c ff ff ba f4      move.w #$ffff, -$450c(a5)
  005866:  60 0a                  bra.b $5872
  005868:  70 00                  moveq #$0, d0
  00586a:  10 2d b9 8e            move.b -$4672(a5), d0
  00586e:  3b 40 ba f4            move.w d0, -$450c(a5)
  005872:  70 00                  moveq #$0, d0
  005874:  10 2d b9 8f            move.b -$4671(a5), d0
  005878:  ec 40                  asr.w #$6, d0
  00587a:  54 40                  addq.w #$2, d0
  00587c:  3b 40 ba f2            move.w d0, -$450e(a5)
  005880:  12 2d b9 90            move.b -$4670(a5), d1
  005884:  48 81                  ext.w d1
  005886:  3f 01                  move.w d1, -(a7)
  005888:  4e ad 02 62            jsr $262(a5)
  00588c:  d0 40                  add.w d0, d0
  00588e:  06 40 ff 8c            addi.w #$ff8c, d0
  005892:  3b 40 ba f6            move.w d0, -$450a(a5)
  005896:  7e 00                  moveq #$0, d7
  005898:  1e 2d b9 48            move.b -$46b8(a5), d7
  00589c:  12 2d b9 91            move.b -$466f(a5), d1
  0058a0:  48 81                  ext.w d1
  0058a2:  d2 47                  add.w d7, d1
  0058a4:  3b 41 ba f8            move.w d1, -$4508(a5)
  0058a8:  14 2d b9 92            move.b -$466e(a5), d2
  0058ac:  48 82                  ext.w d2
  0058ae:  10 2d ba f1            move.b -$450f(a5), d0
  0058b2:  48 80                  ext.w d0
  0058b4:  b1 42                  eor.w d0, d2
  0058b6:  02 42 00 80            andi.w #$80, d2
  0058ba:  54 8f                  addq.l #$2, a7
  0058bc:  66 04                  bne.b $58c2
  0058be:  52 6d ba f6            addq.w #$1, -$450a(a5)
  0058c2:  4a 2d ba f1            tst.b -$450f(a5)
  0058c6:  6c 04                  bge.b $58cc
  0058c8:  70 01                  moveq #$1, d0
  0058ca:  60 02                  bra.b $58ce
  0058cc:  70 ff                  moveq #$ff, d0
  0058ce:  3f 00                  move.w d0, -(a7)
  0058d0:  30 2d ba f8            move.w -$4508(a5), d0
  0058d4:  20 4d                  movea.l a5, a0
  0058d6:  d0 c0                  adda.w d0, a0
  0058d8:  d0 c0                  adda.w d0, a0
  0058da:  3f 28 9d 12            move.w -$62ee(a0), -(a7)
  0058de:  3f 2d ba f6            move.w -$450a(a5), -(a7)
  0058e2:  4e ba 00 88            jsr $596c(pc)
  0058e6:  20 4d                  movea.l a5, a0
  0058e8:  d0 c0                  adda.w d0, a0
  0058ea:  d0 c0                  adda.w d0, a0
  0058ec:  3e a8 99 14            move.w -$66ec(a0), (a7)
  0058f0:  70 01                  moveq #$1, d0
  0058f2:  d0 6d ba f4            add.w -$450c(a5), d0
  0058f6:  3f 00                  move.w d0, -(a7)
  0058f8:  3f 2d ba f2            move.w -$450e(a5), -(a7)
  0058fc:  4e ad 01 12            jsr $112(a5)
  005900:  3e 2d a5 fa            move.w -$5a06(a5), d7
  005904:  9e 6d a5 f6            sub.w -$5a0a(a5), d7
  005908:  7c 00                  moveq #$0, d6
  00590a:  49 ed 99 14            lea.l -$66ec(a5), a4
  00590e:  4f ef 00 0a            lea.l $a(a7), a7
  005912:  60 04                  bra.b $5918
  005914:  54 8c                  addq.l #$2, a4
  005916:  52 46                  addq.w #$1, d6
  005918:  be 54                  cmp.w (a4), d7
  00591a:  6e f8                  bgt.b $5914
  00591c:  30 06                  move.w d6, d0
  00591e:  e7 48                  lsl.w #$3, d0
  005920:  90 46                  sub.w d6, d0
  005922:  e8 40                  asr.w #$4, d0
  005924:  3b 40 ba fa            move.w d0, -$4506(a5)
  005928:  3e 2d a5 f8            move.w -$5a08(a5), d7
  00592c:  9e 6d a5 f4            sub.w -$5a0c(a5), d7
  005930:  7c 00                  moveq #$0, d6
  005932:  49 ed 9d 12            lea.l -$62ee(a5), a4
  005936:  60 04                  bra.b $593c
  005938:  54 8c                  addq.l #$2, a4
  00593a:  52 46                  addq.w #$1, d6
  00593c:  be 54                  cmp.w (a4), d7
  00593e:  6e f8                  bgt.b $5938
  005940:  3b 46 ba fc            move.w d6, -$4504(a5)
  005944:  4c df 10 c0            movem.l (a7)+, d6-d7/a4
  005948:  4e 75                  rts 
  00594a:  4e 56 00 00            link.w a6, #$0
  00594e:  20 6e 00 0a            movea.l $a(a6), a0
  005952:  30 2e 00 08            move.w $8(a6), d0
  005956:  e6 40                  asr.w #$3, d0
  005958:  10 80                  move.b d0, (a0)
  00595a:  20 6e 00 0e            movea.l $e(a6), a0
  00595e:  30 2e 00 08            move.w $8(a6), d0
  005962:  02 40 00 07            andi.w #$7, d0
  005966:  10 80                  move.b d0, (a0)
  005968:  4e 5e                  unlk a6
  00596a:  4e 75                  rts 
  00596c:  4e 56 00 00            link.w a6, #$0
  005970:  30 2e 00 08            move.w $8(a6), d0
  005974:  48 c0                  ext.l d0
  005976:  e7 80                  asl.l #$3, d0
  005978:  81 fc 00 07            divs.w #$7, d0
  00597c:  4e 5e                  unlk a6
  00597e:  4e 75                  rts 
  005980:  2f 07                  move.l d7, -(a7)
  005982:  0c 6d 00 0f ba 64      cmpi.w #$f, -$459c(a5)
  005988:  67 00 01 1a            beq.w $5aa4
  00598c:  4a 2d b9 77            tst.b -$4689(a5)
  005990:  6c 72                  bge.b $5a04
  005992:  4a 6d ba 8c            tst.w -$4574(a5)
  005996:  67 6c                  beq.b $5a04
  005998:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  00599e:  6e 64                  bgt.b $5a04
  0059a0:  0c 6d 00 0d a9 0c      cmpi.w #$d, -$56f4(a5)
  0059a6:  66 06                  bne.b $59ae
  0059a8:  4a 6d ba 3c            tst.w -$45c4(a5)
  0059ac:  66 56                  bne.b $5a04
  0059ae:  53 6d ba 80            subq.w #$1, -$4580(a5)
  0059b2:  4a 6d ba 80            tst.w -$4580(a5)
  0059b6:  66 2a                  bne.b $59e2
  0059b8:  53 6d ba 8c            subq.w #$1, -$4574(a5)
  0059bc:  3b 7c 02 cf ba 80      move.w #$2cf, -$4580(a5)
  0059c2:  30 2d ba 8c            move.w -$4574(a5), d0
  0059c6:  48 c0                  ext.l d0
  0059c8:  81 fc 00 05            divs.w #$5, d0
  0059cc:  48 40                  swap d0
  0059ce:  4a 40                  tst.w d0
  0059d0:  67 08                  beq.b $59da
  0059d2:  0c 6d 00 05 ba 8c      cmpi.w #$5, -$4574(a5)
  0059d8:  6c 2a                  bge.b $5a04
  0059da:  3b 7c 00 01 ba 42      move.w #$1, -$45be(a5)
  0059e0:  60 22                  bra.b $5a04
  0059e2:  0c 6d 00 01 ba 8c      cmpi.w #$1, -$4574(a5)
  0059e8:  66 1a                  bne.b $5a04
  0059ea:  30 2d ba 80            move.w -$4580(a5), d0
  0059ee:  48 c0                  ext.l d0
  0059f0:  81 fc 00 0c            divs.w #$c, d0
  0059f4:  48 40                  swap d0
  0059f6:  4a 40                  tst.w d0
  0059f8:  66 0a                  bne.b $5a04
  0059fa:  3b 7c 00 01 ba 42      move.w #$1, -$45be(a5)
  005a00:  42 6d ba 86            clr.w -$457a(a5)
  005a04:  4a 6d ba 42            tst.w -$45be(a5)
  005a08:  67 00 00 9a            beq.w $5aa4
  005a0c:  4a 6d ba 86            tst.w -$457a(a5)
  005a10:  66 00 00 92            bne.w $5aa4
  005a14:  70 18                  moveq #$18, d0
  005a16:  3b 40 ba 90            move.w d0, -$4570(a5)
  005a1a:  3b 40 ba 86            move.w d0, -$457a(a5)
  005a1e:  4a 6d ba 8c            tst.w -$4574(a5)
  005a22:  66 0c                  bne.b $5a30
  005a24:  48 6d 97 a2            pea.l -$685e(a5)
  005a28:  4e ba 01 10            jsr $5b3a(pc)
  005a2c:  58 8f                  addq.l #$4, a7
  005a2e:  60 70                  bra.b $5aa0
  005a30:  0c 6d 00 01 ba 8c      cmpi.w #$1, -$4574(a5)
  005a36:  66 46                  bne.b $5a7e
  005a38:  3e 2d ba 80            move.w -$4580(a5), d7
  005a3c:  48 c7                  ext.l d7
  005a3e:  8f fc 00 0c            divs.w #$c, d7
  005a42:  0c 47 00 01            cmpi.w #$1, d7
  005a46:  6e 16                  bgt.b $5a5e
  005a48:  48 6d 97 92            pea.l -$686e(a5)
  005a4c:  4e ba 00 ec            jsr $5b3a(pc)
  005a50:  70 0c                  moveq #$c, d0
  005a52:  3b 40 ba 90            move.w d0, -$4570(a5)
  005a56:  3b 40 ba 86            move.w d0, -$457a(a5)
  005a5a:  58 8f                  addq.l #$4, a7
  005a5c:  60 42                  bra.b $5aa0
  005a5e:  3f 07                  move.w d7, -(a7)
  005a60:  4e ad 00 7a            jsr $7a(a5)
  005a64:  1b 40 97 83            move.b d0, -$687d(a5)
  005a68:  3e 87                  move.w d7, (a7)
  005a6a:  4e ad 00 8a            jsr $8a(a5)
  005a6e:  1b 40 97 84            move.b d0, -$687c(a5)
  005a72:  48 6d 97 82            pea.l -$687e(a5)
  005a76:  4e ba 00 c2            jsr $5b3a(pc)
  005a7a:  5c 8f                  addq.l #$6, a7
  005a7c:  60 22                  bra.b $5aa0
  005a7e:  3f 2d ba 8c            move.w -$4574(a5), -(a7)
  005a82:  4e ad 00 7a            jsr $7a(a5)
  005a86:  1b 40 97 73            move.b d0, -$688d(a5)
  005a8a:  3e ad ba 8c            move.w -$4574(a5), (a7)
  005a8e:  4e ad 00 8a            jsr $8a(a5)
  005a92:  1b 40 97 74            move.b d0, -$688c(a5)
  005a96:  48 6d 97 72            pea.l -$688e(a5)
  005a9a:  4e ba 00 9e            jsr $5b3a(pc)
  005a9e:  5c 8f                  addq.l #$6, a7
  005aa0:  42 6d ba 42            clr.w -$45be(a5)
  005aa4:  2e 1f                  move.l (a7)+, d7
  005aa6:  4e 75                  rts 
  005aa8:  2f 07                  move.l d7, -(a7)
  005aaa:  3e 2d a9 0c            move.w -$56f4(a5), d7
  005aae:  0c 47 00 0f            cmpi.w #$f, d7
  005ab2:  66 1c                  bne.b $5ad0
  005ab4:  30 3c 75 30            move.w #$7530, d0
  005ab8:  3b 40 ba 90            move.w d0, -$4570(a5)
  005abc:  3b 40 ba 86            move.w d0, -$457a(a5)
  005ac0:  48 6d 97 f4            pea.l -$680c(a5)
  005ac4:  4e ba 00 74            jsr $5b3a(pc)
  005ac8:  42 6d ba 42            clr.w -$45be(a5)
  005acc:  58 8f                  addq.l #$4, a7
  005ace:  60 62                  bra.b $5b32
  005ad0:  4a 47                  tst.w d7
  005ad2:  67 5e                  beq.b $5b32
  005ad4:  0c 47 00 0e            cmpi.w #$e, d7
  005ad8:  67 58                  beq.b $5b32
  005ada:  4a 6d ba 22            tst.w -$45de(a5)
  005ade:  66 52                  bne.b $5b32
  005ae0:  0c 47 00 0d            cmpi.w #$d, d7
  005ae4:  66 02                  bne.b $5ae8
  005ae6:  53 47                  subq.w #$1, d7
  005ae8:  70 18                  moveq #$18, d0
  005aea:  3b 40 ba 90            move.w d0, -$4570(a5)
  005aee:  3b 40 ba 86            move.w d0, -$457a(a5)
  005af2:  0c 47 00 0a            cmpi.w #$a, d7
  005af6:  6c 14                  bge.b $5b0c
  005af8:  3f 07                  move.w d7, -(a7)
  005afa:  4e ad 00 8a            jsr $8a(a5)
  005afe:  1b 40 97 6f            move.b d0, -$6891(a5)
  005b02:  1b 7c 00 20 97 70      move.b #$20, -$6890(a5)
  005b08:  54 8f                  addq.l #$2, a7
  005b0a:  60 16                  bra.b $5b22
  005b0c:  3f 07                  move.w d7, -(a7)
  005b0e:  4e ad 00 82            jsr $82(a5)
  005b12:  1b 40 97 6f            move.b d0, -$6891(a5)
  005b16:  3e 87                  move.w d7, (a7)
  005b18:  4e ad 00 8a            jsr $8a(a5)
  005b1c:  1b 40 97 70            move.b d0, -$6890(a5)
  005b20:  54 8f                  addq.l #$2, a7
  005b22:  48 6d 97 68            pea.l -$6898(a5)
  005b26:  4e ba 00 12            jsr $5b3a(pc)
  005b2a:  3b 7c 00 01 ba 42      move.w #$1, -$45be(a5)
  005b30:  58 8f                  addq.l #$4, a7
  005b32:  42 6d ba 22            clr.w -$45de(a5)
  005b36:  2e 1f                  move.l (a7)+, d7
  005b38:  4e 75                  rts 
  005b3a:  4e 56 ff ae            link.w a6, #$ffae
  005b3e:  48 e7 03 00            movem.l d6-d7, -(a7)
  005b42:  1f 3c 00 01            move.b #$1, -(a7)
  005b46:  48 6d a5 e4            pea.l -$5a1c(a5)
  005b4a:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  005b4e:  4e 90                  jsr (a0)
  005b50:  20 6e 00 08            movea.l $8(a6), a0
  005b54:  1e 10                  move.b (a0), d7
  005b56:  48 87                  ext.w d7
  005b58:  0c 47 00 3f            cmpi.w #$3f, d7
  005b5c:  5c 8f                  addq.l #$6, a7
  005b5e:  6f 02                  ble.b $5b62
  005b60:  7e 3f                  moveq #$3f, d7
  005b62:  1d 47 ff c0            move.b d7, -$40(a6)
  005b66:  70 01                  moveq #$1, d0
  005b68:  d0 ae 00 08            add.l $8(a6), d0
  005b6c:  20 40                  movea.l d0, a0
  005b6e:  43 ee ff c1            lea.l -$3f(a6), a1
  005b72:  20 07                  move.l d7, d0
  005b74:  48 c0                  ext.l d0
  005b76:  a0 2e                  dc.w $a02e
  005b78:  48 6e ff c0            pea.l -$40(a6)
  005b7c:  1f 3c 00 01            move.b #$1, -(a7)
  005b80:  4e ad 01 7a            jsr $17a(a5)
  005b84:  48 6d a0 b6            pea.l -$5f4a(a5)
  005b88:  a8 74                  dc.w $a874
  005b8a:  48 6d a2 5e            pea.l -$5da2(a5)
  005b8e:  a8 73                  dc.w $a873
  005b90:  48 6d a5 e4            pea.l -$5a1c(a5)
  005b94:  a8 7b                  dc.w $a87b
  005b96:  2f 3c fc 18 00 00      move.l #$fc180000, -(a7)
  005b9c:  a8 93                  dc.w $a893
  005b9e:  48 6e ff c0            pea.l -$40(a6)
  005ba2:  a8 84                  dc.w $a884
  005ba4:  48 6e ff ae            pea.l -$52(a6)
  005ba8:  a8 98                  dc.w $a898
  005baa:  3e 2e ff b0            move.w -$50(a6), d7
  005bae:  3c 2d a5 ea            move.w -$5a16(a5), d6
  005bb2:  9c 6d a5 e6            sub.w -$5a1a(a5), d6
  005bb6:  9c 47                  sub.w d7, d6
  005bb8:  48 c6                  ext.l d6
  005bba:  8d fc 00 02            divs.w #$2, d6
  005bbe:  30 2d a5 e6            move.w -$5a1a(a5), d0
  005bc2:  d0 46                  add.w d6, d0
  005bc4:  3f 00                  move.w d0, -(a7)
  005bc6:  70 ff                  moveq #$ff, d0
  005bc8:  d0 6d a5 e8            add.w -$5a18(a5), d0
  005bcc:  3f 00                  move.w d0, -(a7)
  005bce:  a8 93                  dc.w $a893
  005bd0:  48 6e ff c0            pea.l -$40(a6)
  005bd4:  a8 84                  dc.w $a884
  005bd6:  48 6d a2 dc            pea.l -$5d24(a5)
  005bda:  a8 7b                  dc.w $a87b
  005bdc:  2f 2d a0 b6            move.l -$5f4a(a5), -(a7)
  005be0:  a8 73                  dc.w $a873
  005be2:  48 6d a5 e4            pea.l -$5a1c(a5)
  005be6:  a9 28                  dc.w $a928
  005be8:  4c df 00 c0            movem.l (a7)+, d6-d7
  005bec:  4e 5e                  unlk a6
  005bee:  4e 75                  rts 
  005bf0:  4e 56 00 00            link.w a6, #$0
  005bf4:  4a 6e 00 08            tst.w $8(a6)
  005bf8:  67 08                  beq.b $5c02
  005bfa:  42 6d ba 90            clr.w -$4570(a5)
  005bfe:  42 6d ba 86            clr.w -$457a(a5)
  005c02:  1f 3c 00 01            move.b #$1, -(a7)
  005c06:  48 6d a5 e4            pea.l -$5a1c(a5)
  005c0a:  20 6d a3 e2            movea.l -$5c1e(a5), a0
  005c0e:  4e 90                  jsr (a0)
  005c10:  48 6d a5 e4            pea.l -$5a1c(a5)
  005c14:  a9 28                  dc.w $a928
  005c16:  4e 5e                  unlk a6
  005c18:  4e 75                  rts 
  005c1a:  3f 2d f2 26            move.w -$dda(a5), -(a7)
  005c1e:  42 67                  clr.w -(a7)
  005c20:  3f 2d f2 22            move.w -$dde(a5), -(a7)
  005c24:  70 00                  moveq #$0, d0
  005c26:  10 2d ba 95            move.b -$456b(a5), d0
  005c2a:  02 40 00 7f            andi.w #$7f, d0
  005c2e:  20 4d                  movea.l a5, a0
  005c30:  d0 c0                  adda.w d0, a0
  005c32:  70 00                  moveq #$0, d0
  005c34:  10 28 b6 3a            move.b -$49c6(a0), d0
  005c38:  3f 00                  move.w d0, -(a7)
  005c3a:  3f 3c 00 07            move.w #$7, -(a7)
  005c3e:  4e ba e8 3a            jsr $447a(pc)
  005c42:  4f ef 00 0a            lea.l $a(a7), a7
  005c46:  4e 75                  rts 
  005c48:  4e 75                  rts 
  005c4a:  4e 56 00 00            link.w a6, #$0
  005c4e:  48 e7 07 00            movem.l d5-d7, -(a7)
  005c52:  3e 2e 00 08            move.w $8(a6), d7
  005c56:  3c 2e 00 0a            move.w $a(a6), d6
  005c5a:  3a 2e 00 0c            move.w $c(a6), d5
  005c5e:  4c df 00 e0            movem.l (a7)+, d5-d7
  005c62:  4e 5e                  unlk a6
  005c64:  4e 75                  rts 
  005c66:  4e 56 00 00            link.w a6, #$0
  005c6a:  48 e7 03 00            movem.l d6-d7, -(a7)
  005c6e:  3e 2e 00 08            move.w $8(a6), d7
  005c72:  3c 2e 00 0a            move.w $a(a6), d6
  005c76:  4c df 00 c0            movem.l (a7)+, d6-d7
  005c7a:  4e 5e                  unlk a6
  005c7c:  4e 75                  rts 
  005c7e:  4e 75                  rts 
  005c80:  4e 75                  rts 