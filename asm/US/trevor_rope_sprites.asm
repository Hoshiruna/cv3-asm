; SPDX-License-Identifier: MIT
; Native 8x16 OAM format and Trevor palette 0 ($0F, $08, $26, $37).
; Seven pairs in page $3B and one in $3D are absent from the ending OAM table.
; The rope handler maps these pages at sprite addresses $0000 and $0400.
TREVOR_ROPE_CHR_0_FILE = $040010 + ROPE_TREVOR_CHR_0 * $0400
TREVOR_ROPE_CHR_1_FILE = $040010 + ROPE_TREVOR_CHR_1 * $0400

SEEKABS TREVOR_ROPE_CHR_0_FILE + $80
INCBIN "sprite/trevor_climb.chr", $0, $20

SEEKABS TREVOR_ROPE_CHR_0_FILE + $A0
INCBIN "sprite/trevor_climb.chr", $20, $20

SEEKABS TREVOR_ROPE_CHR_0_FILE + $C0
INCBIN "sprite/trevor_climb.chr", $40, $20

SEEKABS TREVOR_ROPE_CHR_0_FILE + $E0
INCBIN "sprite/trevor_climb.chr", $60, $20

SEEKABS TREVOR_ROPE_CHR_0_FILE + $340
INCBIN "sprite/trevor_climb.chr", $80, $20

SEEKABS TREVOR_ROPE_CHR_0_FILE + $360
INCBIN "sprite/trevor_climb.chr", $a0, $20

SEEKABS TREVOR_ROPE_CHR_0_FILE + $3E0
INCBIN "sprite/trevor_climb.chr", $c0, $20

SEEKABS TREVOR_ROPE_CHR_1_FILE + $120
INCBIN "sprite/trevor_climb.chr", $e0, $20

; Extend Trevor's pose table in bank $1B padding. Stopwatch shares it.
SEEKABS $037E74
BASE $BE64
trevor_rope_pose_table:
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $03426C, $70
DW trevor_rope_frame_1, trevor_rope_frame_2
trevor_rope_frame_1:
    DB $04, $E0, $08, $00, $F8, $E1, $0A, $00
    DB $01, $0C, $F8, $01, $0E, $00
trevor_rope_frame_2:
    DB $04, $E0, $34, $00, $F8, $E1, $36, $00
    DB $01, $3E, $F8, $01, $52, $00
IF $ > $C000
    ERROR "Trevor rope poses exceed bank $1B padding"
ENDIF

SEEKABS $03424E
DW trevor_rope_pose_table
SEEKABS $034264
DW trevor_rope_pose_table

; The horizontal-room NMI path skips player CHR updates. Apply the queued
; player pages after OAM DMA, then retain the native status-bar setup.
SEEKABS $03E09B
BASE $E08B
COMPARE
FILLVALUE $20
DB $20
FILLVALUE $EC
DB $EC
FILLVALUE $E2
DB $E2
ENDCOMPARE
SKIPREL -3
JSR rope_apply_player_chr_nmi

FILLVALUE $FF
COMPARE
SEEKABS $03FFF7
BASE $FFE7
rope_apply_player_chr_nmi:
    JSR $E352 ; Native updateSprChrBanks_0_400.
    JMP $E2EC ; Native setFrameStartingDefaultChrBanks.
IF $ > $FFF0
    ERROR "Rope CHR update exceeds the $FFE7-$FFEF fixed-bank padding"
ENDIF
ENDCOMPARE
