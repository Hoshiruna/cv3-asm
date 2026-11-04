; SPDX-License-Identifier: MIT
; Assemble with nstbayless/asm6f (the fork with INCNES and SEEKABS).

INCNES "Castlevania III - Dracula's Curse (USA).nes"
CLEARPATCH

INCLUDE "src/symbols-us.asm"

; The shared dispatch originally loads the current character into Y.
SEEKABS $038AA1
BASE $8A91
COMPARE
FILLVALUE $AC
DB $AC
FILLVALUE $4E
DB $4E
FILLVALUE $05
DB $05
ENDCOMPARE
SKIPREL -3
JSR stair_controls_tick

; Both code regions are padding in the unmodified US ROM.
; COMPARE rejects occupied space when applying to another hack.
FILLVALUE $FF
COMPARE
INCLUDE "src/stairs-controls.asm"
ENDCOMPARE
