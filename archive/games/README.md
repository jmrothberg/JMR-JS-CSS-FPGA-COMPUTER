# Archived game versions

Each game used to ship twice on the card: a plain version and a CB version
(CopyBits damage restore). One version of each stays in `storage/`, the one
that drew a frame in fewer VM cycles. The other is kept here and is not put
on the card.

Measured on the Verilator simulator (SRAM model), the same 240 frames of
scripted play for every game (`play()` in the measurement script: stick
right/left in 90-frame phases, up for 20 frames, fire twice every 45 frames).

| Game | Plain avg cycles/frame | CB avg cycles/frame | Kept | Archived here |
|---|---:|---:|---|---|
| Donkey Kong | 106,761 (DNKF) | 86,675 (CBDNKF) | CBDNKF | DNKF |
| Centipede | 578,913 (CENTIPED) | 422,179 (CBCENTIP) | CBCENTIPED | CENTIPED |
| Bomberman | 834,384 (BOMBFAST) | 1,012,704 (CBBOMBFA) | BOMBFAST | CBBOMBFAST (CBBOMBFA.JSH) |
| Field defense | 822,751 (FLDF) | 393,303 (CBFLDF) | CBFLDF | FLDF |
| MK, two players | 642,260 (MKBA) | 313,305 (CBMKBA) | CBMKBA | MKBA |
| MK, versus CPU | 638,588 (MKCA) | 312,724 (CBMKCA) | CBMKCA | MKCA |
| Mr. Do! | 809,604 (MRDOF) | 377,503 (CBMRDOF) | CBMRDOF | MRDOF |
| Pac-Man | 623,768 (PACFAST) | 497,578 (CBPACFAS) | CBPACFAST | PACFAST |

The kept CB titles keep their CB names: tools and tests refer to the plain
names for the plain art pipeline (`tools/make_artx.py`).

The plain `NAME.ARTJS` files moved here with their titles. The kept CB titles
have their own `storage/CBNAME.ARTJS` (byte-identical, made by
`python3 tools/make_artjs.py CBNAME`). `.ARTJS` is browser-preview art only;
since build 96 it is not put on the card.

To play an archived version, copy its files back into `storage/` and
rebuild the card. Its `.JSH` must be minted again after any Toolbox relink.
