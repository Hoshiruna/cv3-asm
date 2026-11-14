; SPDX-License-Identifier: MIT
; Native 8x16 OAM format and Trevor palette 0 ($0F, $08, $26, $37).
; The climbing frames replace pairs unused by Trevor's main pose table.
; No sprite CHR bank changes are needed while climbing.
TREVOR_CHR_1_FILE = $040010 + $0400
NAME_SCREEN_CHR_FILE = $040010 + $42 * $0400

MACRO trevor_rope_expect value
    FILLVALUE value
    DB value
ENDM

; Name/password screens map CHR bank $42 at sprite page $1800. Preserve
; the four graphics replaced below in its unused final four 8x16 slots.
SEEKABS NAME_SCREEN_CHR_FILE + $380
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $040650, $20
SEEKABS NAME_SCREEN_CHR_FILE + $3A0
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $0406B0, $20
SEEKABS NAME_SCREEN_CHR_FILE + $3C0
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $0406D0, $20
SEEKABS NAME_SCREEN_CHR_FILE + $3E0
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $0406F0, $20

; These OAM specs are dedicated to the name/password screens. Point them
; at the preserved copies without changing any CHR bank mapping.
SEEKABS $03776F
COMPARE
trevor_rope_expect $64
ENDCOMPARE
SKIPREL -1
DB $B9

SEEKABS $036BD2
COMPARE
trevor_rope_expect $6A
ENDCOMPARE
SKIPREL -1
DB $BB

SEEKABS $036BD6
COMPARE
trevor_rope_expect $6C
ENDCOMPARE
SKIPREL -1
DB $BD

SEEKABS $036BDA
COMPARE
trevor_rope_expect $6E
ENDCOMPARE
SKIPREL -1
DB $BF

SEEKABS TREVOR_CHR_1_FILE + $A0
INCBIN "sprite/trevor_climb.chr", $00, $20

SEEKABS TREVOR_CHR_1_FILE + $300
INCBIN "sprite/trevor_climb.chr", $20, $20

SEEKABS TREVOR_CHR_1_FILE + $320
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

; Extend Trevor's pose table in bank $1B padding. Stopwatch shares it.
SEEKABS $037E74
BASE $BE64
trevor_rope_pose_table:
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $03426C, $70
DW trevor_rope_frame_1, trevor_rope_frame_2
trevor_rope_frame_1:
    DB $04, $E0, $4A, $00, $F8, $E1, $70, $00
    DB $01, $72, $F8, $01, $60, $00
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
