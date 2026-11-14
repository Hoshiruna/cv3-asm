; SPDX-License-Identifier: MIT
; Native 8x16 OAM format and Trevor palette 0 ($0F, $08, $26, $37).
; The climbing frames replace pairs unused by Trevor during normal gameplay.
; Password-screen tiles formerly using $5C/$5E move to free pairs in page $3B.
TREVOR_CHR_1_FILE = $040010 + $0400
PASSWORD_CHR_FILE = $040010 + $3B * $0400

MACRO trevor_rope_expect value
    FILLVALUE value
    DB value
ENDM

SEEKABS PASSWORD_CHR_FILE + $80
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $0405D0, $20

SEEKABS PASSWORD_CHR_FILE + $A0
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $0405F0, $20

SEEKABS TREVOR_CHR_1_FILE + $A0
INCBIN "sprite/trevor_climb.chr", $00, $20

SEEKABS TREVOR_CHR_1_FILE + $1C0
INCBIN "sprite/trevor_climb.chr", $20, $20

SEEKABS TREVOR_CHR_1_FILE + $1E0
INCBIN "sprite/trevor_climb.chr", $40, $20

SEEKABS TREVOR_CHR_1_FILE + $200
INCBIN "sprite/trevor_climb.chr", $60, $20

SEEKABS TREVOR_CHR_1_FILE + $240
INCBIN "sprite/trevor_climb.chr", $80, $20

SEEKABS TREVOR_CHR_1_FILE + $2A0
INCBIN "sprite/trevor_climb.chr", $A0, $20

SEEKABS TREVOR_CHR_1_FILE + $2C0
INCBIN "sprite/trevor_climb.chr", $C0, $20

SEEKABS TREVOR_CHR_1_FILE + $2E0
INCBIN "sprite/trevor_climb.chr", $E0, $20

; The password screen keeps its original square graphics in their new slots.
SEEKABS $006862
COMPARE
trevor_rope_expect $01
ENDCOMPARE
SKIPREL -1
DB $3B

SEEKABS $03753B
COMPARE
trevor_rope_expect $02
trevor_rope_expect $F0
trevor_rope_expect $5C
trevor_rope_expect $00
trevor_rope_expect $F8
trevor_rope_expect $F0
trevor_rope_expect $5C
trevor_rope_expect $40
trevor_rope_expect $00
ENDCOMPARE
SKIPREL -9
DB $02, $F0, $48, $00, $F8, $F0, $48, $40, $00

SEEKABS $037544
COMPARE
trevor_rope_expect $08
trevor_rope_expect $D0
trevor_rope_expect $5E
trevor_rope_expect $00
trevor_rope_expect $F0
trevor_rope_expect $D1
trevor_rope_expect $5E
trevor_rope_expect $F8
trevor_rope_expect $D1
trevor_rope_expect $5E
trevor_rope_expect $00
trevor_rope_expect $D1
trevor_rope_expect $5E
trevor_rope_expect $08
trevor_rope_expect $F1
trevor_rope_expect $5E
trevor_rope_expect $F0
trevor_rope_expect $F1
trevor_rope_expect $5C
trevor_rope_expect $F8
trevor_rope_expect $F1
trevor_rope_expect $5E
trevor_rope_expect $08
trevor_rope_expect $F0
trevor_rope_expect $5C
trevor_rope_expect $40
trevor_rope_expect $00
ENDCOMPARE
SKIPREL -27
DB $08, $D0, $4A, $00, $F0, $D1, $4A, $F8, $D1
DB $4A, $00, $D1, $4A, $08, $F1, $4A, $F0, $F1
DB $48, $F8, $F1, $4A, $08, $F0, $48, $40, $00

; Extend Trevor's pose table in bank $1B padding. Stopwatch shares it.
SEEKABS $037E74
BASE $BE64
trevor_rope_pose_table:
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $03426C, $70
DW trevor_rope_frame_1, trevor_rope_frame_2
trevor_rope_frame_1:
    DB $04, $E0, $4A, $00, $F8, $E1, $5C, $00
    DB $01, $5E, $F8, $01, $60, $00
trevor_rope_frame_2:
    DB $04, $E0, $64, $00, $F8, $E1, $6A, $00
    DB $01, $6C, $F8, $01, $6E, $00
IF $ > $C000
    ERROR "Trevor rope poses exceed bank $1B padding"
ENDIF

SEEKABS $03424E
DW trevor_rope_pose_table
SEEKABS $034264
DW trevor_rope_pose_table
