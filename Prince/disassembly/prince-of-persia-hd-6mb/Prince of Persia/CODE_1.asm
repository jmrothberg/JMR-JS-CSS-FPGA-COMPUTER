; prince-of-persia-hd-6mb: Prince of Persia/Prince of Persia, CODE resource 1 (558 bytes)
; 68000 disassembly (linear sweep). Code starts after the 4-byte segment header.
; Words $Axxx are Mac Toolbox/OS traps; known ones are annotated. Globals are (a5)-relative.

  000004:  00 00 01 c2            ori.b #$c2, d0
  000008:  42 78 0a 4a            clr.w $a4a.w
  00000c:  9d ce                  suba.l a6, a6
  00000e:  4e ba 00 24            jsr $34(pc)
  000012:  42 67                  clr.w -(a7)
  000014:  48 79 00 00 ff ff      pea.l $ffff.l
  00001a:  48 6f 00 04            pea.l $4(a7)
  00001e:  48 57                  pea.l (a7)
  000020:  48 78 00 01            pea.l $1.w
  000024:  22 3a ff de            move.l $4(pc), d1
  000028:  4e b5 10 00            jsr (a5, d1.w)
  00002c:  20 6d 00 6c            movea.l $6c(a5), a0
  000030:  4e 90                  jsr (a0)
  000032:  a9 f4                  dc.w $a9f4   ; _ExitToShell
  000034:  59 8f                  subq.l #$4, a7
  000036:  2f 3c 5a 45 52 4f      move.l #$5a45524f, -(a7)
  00003c:  42 67                  clr.w -(a7)
  00003e:  a9 a0                  dc.w $a9a0
  000040:  24 57                  movea.l (a7), a2
  000042:  59 8f                  subq.l #$4, a7
  000044:  2f 3c 44 41 54 41      move.l #$44415441, -(a7)
  00004a:  42 67                  clr.w -(a7)
  00004c:  a9 a0                  dc.w $a9a0
  00004e:  20 57                  movea.l (a7), a0
  000050:  20 50                  movea.l (a0), a0
  000052:  22 78 09 08            movea.l $908.w, a1
  000056:  24 52                  movea.l (a2), a2
  000058:  60 0e                  bra.b $68
  00005a:  32 d8                  move.w (a0)+, (a1)+
  00005c:  66 0a                  bne.b $68
  00005e:  32 1a                  move.w (a2)+, d1
  000060:  60 02                  bra.b $64
  000062:  42 19                  clr.b (a1)+
  000064:  51 c9 ff fc            dbra d1, $62
  000068:  bb c9                  cmpa.l a1, a5
  00006a:  66 ee                  bne.b $5a
  00006c:  a9 a3                  dc.w $a9a3
  00006e:  a9 a3                  dc.w $a9a3
  000070:  59 8f                  subq.l #$4, a7
  000072:  2f 3c 44 52 45 4c      move.l #$4452454c, -(a7)
  000078:  42 67                  clr.w -(a7)
  00007a:  a9 a0                  dc.w $a9a0
  00007c:  20 57                  movea.l (a7), a0
  00007e:  a0 25                  dc.w $a025
  000080:  20 50                  movea.l (a0), a0
  000082:  e2 40                  asr.w #$1, d0
  000084:  24 0d                  move.l a5, d2
  000086:  60 06                  bra.b $8e
  000088:  32 18                  move.w (a0)+, d1
  00008a:  d5 b5 10 00            add.l d2, (a5, d1.w)
  00008e:  51 c8 ff f8            dbra d0, $88
  000092:  a9 a3                  dc.w $a9a3
  000094:  4e 75                  rts 
  000096:  20 5f                  movea.l (a7)+, a0
  000098:  32 18                  move.w (a0)+, d1
  00009a:  34 18                  move.w (a0)+, d2
  00009c:  b0 58                  cmp.w (a0)+, d0
  00009e:  57 c9 ff fa            dbeq d1, $9a
  0000a2:  4a 42                  tst.w d2
  0000a4:  67 fe                  beq.b $a4
  0000a6:  4e f0 20 fc            jmp -$4(a0, d2.w)
  0000aa:  20 5f                  movea.l (a7)+, a0
  0000ac:  32 18                  move.w (a0)+, d1
  0000ae:  34 18                  move.w (a0)+, d2
  0000b0:  b0 98                  cmp.l (a0)+, d0
  0000b2:  57 c9 ff fa            dbeq d1, $ae
  0000b6:  4a 42                  tst.w d2
  0000b8:  67 fe                  beq.b $b8
  0000ba:  4e f0 20 fa            jmp -$6(a0, d2.w)
  0000be:  20 5f                  movea.l (a7)+, a0
  0000c0:  32 18                  move.w (a0)+, d1
  0000c2:  34 18                  move.w (a0)+, d2
  0000c4:  b0 42                  cmp.w d2, d0
  0000c6:  6e 0a                  bgt.b $d2
  0000c8:  90 41                  sub.w d1, d0
  0000ca:  6d 06                  blt.b $d2
  0000cc:  d0 40                  add.w d0, d0
  0000ce:  41 f0 00 02            lea.l $2(a0, d0.w), a0
  0000d2:  30 10                  move.w (a0), d0
  0000d4:  67 fe                  beq.b $d4
  0000d6:  4e f0 00 00            jmp (a0, d0.w)
  0000da:  20 2f 00 04            move.l $4(a7), d0
  0000de:  2f 41 00 04            move.l d1, $4(a7)
  0000e2:  22 2f 00 08            move.l $8(a7), d1
  0000e6:  2f 5f 00 04            move.l (a7)+, $4(a7)
  0000ea:  48 e7 3c 00            movem.l d2-d5, -(a7)
  0000ee:  24 00                  move.l d0, d2
  0000f0:  26 01                  move.l d1, d3
  0000f2:  48 42                  swap d2
  0000f4:  c4 c3                  mulu.w d3, d2
  0000f6:  28 00                  move.l d0, d4
  0000f8:  2a 01                  move.l d1, d5
  0000fa:  48 45                  swap d5
  0000fc:  c8 c5                  mulu.w d5, d4
  0000fe:  d4 44                  add.w d4, d2
  000100:  48 42                  swap d2
  000102:  42 42                  clr.w d2
  000104:  c0 c1                  mulu.w d1, d0
  000106:  d0 82                  add.l d2, d0
  000108:  4c df 00 3c            movem.l (a7)+, d2-d5
  00010c:  22 1f                  move.l (a7)+, d1
  00010e:  4e 75                  rts 
  000110:  20 2f 00 04            move.l $4(a7), d0
  000114:  2f 41 00 04            move.l d1, $4(a7)
  000118:  22 2f 00 08            move.l $8(a7), d1
  00011c:  2f 5f 00 04            move.l (a7)+, $4(a7)
  000120:  48 e7 31 00            movem.l d2-d3/d7, -(a7)
  000124:  4e ba 00 9c            jsr $1c2(pc)
  000128:  4c df 00 8c            movem.l (a7)+, d2-d3/d7
  00012c:  22 1f                  move.l (a7)+, d1
  00012e:  4e 75                  rts 
  000130:  20 2f 00 04            move.l $4(a7), d0
  000134:  2f 41 00 04            move.l d1, $4(a7)
  000138:  22 2f 00 08            move.l $8(a7), d1
  00013c:  2f 5f 00 04            move.l (a7)+, $4(a7)
  000140:  48 e7 31 00            movem.l d2-d3/d7, -(a7)
  000144:  4e ba 00 7c            jsr $1c2(pc)
  000148:  20 01                  move.l d1, d0
  00014a:  4c df 00 8c            movem.l (a7)+, d2-d3/d7
  00014e:  22 1f                  move.l (a7)+, d1
  000150:  4e 75                  rts 
  000152:  20 2f 00 04            move.l $4(a7), d0
  000156:  2f 41 00 04            move.l d1, $4(a7)
  00015a:  22 2f 00 08            move.l $8(a7), d1
  00015e:  2f 5f 00 04            move.l (a7)+, $4(a7)
  000162:  48 e7 31 00            movem.l d2-d3/d7, -(a7)
  000166:  4e ba 00 2c            jsr $194(pc)
  00016a:  4c df 00 8c            movem.l (a7)+, d2-d3/d7
  00016e:  22 1f                  move.l (a7)+, d1
  000170:  4e 75                  rts 
  000172:  20 2f 00 04            move.l $4(a7), d0
  000176:  2f 41 00 04            move.l d1, $4(a7)
  00017a:  22 2f 00 08            move.l $8(a7), d1
  00017e:  2f 5f 00 04            move.l (a7)+, $4(a7)
  000182:  48 e7 31 00            movem.l d2-d3/d7, -(a7)
  000186:  4e ba 00 0c            jsr $194(pc)
  00018a:  20 01                  move.l d1, d0
  00018c:  4c df 00 8c            movem.l (a7)+, d2-d3/d7
  000190:  22 1f                  move.l (a7)+, d1
  000192:  4e 75                  rts 
  000194:  4a 80                  tst.l d0
  000196:  6a 1c                  bpl.b $1b4
  000198:  4a 81                  tst.l d1
  00019a:  6a 0c                  bpl.b $1a8
  00019c:  44 80                  neg.l d0
  00019e:  44 81                  neg.l d1
  0001a0:  4e ba 00 20            jsr $1c2(pc)
  0001a4:  44 81                  neg.l d1
  0001a6:  4e 75                  rts 
  0001a8:  44 80                  neg.l d0
  0001aa:  4e ba 00 16            jsr $1c2(pc)
  0001ae:  44 80                  neg.l d0
  0001b0:  44 81                  neg.l d1
  0001b2:  4e 75                  rts 
  0001b4:  4a 81                  tst.l d1
  0001b6:  6a 0a                  bpl.b $1c2
  0001b8:  44 81                  neg.l d1
  0001ba:  4e ba 00 06            jsr $1c2(pc)
  0001be:  44 80                  neg.l d0
  0001c0:  4e 75                  rts 
  0001c2:  2e 3c 00 00 ff ff      move.l #$ffff, d7
  0001c8:  b2 80                  cmp.l d0, d1
  0001ca:  63 06                  bls.b $1d2
  0001cc:  22 00                  move.l d0, d1
  0001ce:  70 00                  moveq #$0, d0
  0001d0:  4e 75                  rts 
  0001d2:  b0 87                  cmp.l d7, d0
  0001d4:  62 0c                  bhi.b $1e2
  0001d6:  80 c1                  divu.w d1, d0
  0001d8:  48 40                  swap d0
  0001da:  32 00                  move.w d0, d1
  0001dc:  42 40                  clr.w d0
  0001de:  48 40                  swap d0
  0001e0:  4e 75                  rts 
  0001e2:  b2 87                  cmp.l d7, d1
  0001e4:  62 1a                  bhi.b $200
  0001e6:  2e 00                  move.l d0, d7
  0001e8:  42 40                  clr.w d0
  0001ea:  48 40                  swap d0
  0001ec:  80 c1                  divu.w d1, d0
  0001ee:  48 40                  swap d0
  0001f0:  48 47                  swap d7
  0001f2:  3e 00                  move.w d0, d7
  0001f4:  48 47                  swap d7
  0001f6:  8e c1                  divu.w d1, d7
  0001f8:  30 07                  move.w d7, d0
  0001fa:  48 47                  swap d7
  0001fc:  32 07                  move.w d7, d1
  0001fe:  4e 75                  rts 
  000200:  24 00                  move.l d0, d2
  000202:  26 01                  move.l d1, d3
  000204:  e2 88                  lsr.l #$1, d0
  000206:  e2 89                  lsr.l #$1, d1
  000208:  b2 87                  cmp.l d7, d1
  00020a:  62 f8                  bhi.b $204
  00020c:  80 c1                  divu.w d1, d0
  00020e:  c0 87                  and.l d7, d0
  000210:  32 03                  move.w d3, d1
  000212:  c2 c0                  mulu.w d0, d1
  000214:  2e 03                  move.l d3, d7
  000216:  48 47                  swap d7
  000218:  ce c0                  mulu.w d0, d7
  00021a:  48 47                  swap d7
  00021c:  d2 87                  add.l d7, d1
  00021e:  65 08                  bcs.b $228
  000220:  92 82                  sub.l d2, d1
  000222:  62 04                  bhi.b $228
  000224:  44 81                  neg.l d1
  000226:  4e 75                  rts 
  000228:  53 40                  subq.w #$1, d0
  00022a:  60 e4                  bra.b $210
  00022c:  4e 75                  rts 