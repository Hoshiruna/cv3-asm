; SPDX-License-Identifier: MIT
; Assemble from the project root with nstbayless/asm6f.
; Imports the rope and its controls into stage 1, block 02 (RAM 00/01/00).

ROPE_ROOM_1_02 = 1
INCLUDE "asm/US/climbable_rope.asm"

ROOM_ROPE_TILE       = $40
ROOM_ROPE_FIRST_META = $91
ROOM_ROPE_META_END   = $95

MACRO rope_room_expect value
    FILLVALUE value
    DB value
ENDM

; Use the existing background bank $46 for room 00/01/00. Its slots $00
; and $27 are unused by its original clock-tower room. The rope uses slot
; $00 (tile $40). This room's only original bank-$45 tile is $67, copied
; into slot $27 below. Native collision thresholds classify both as air.
; As with stairs, map tiles provide the artwork and rope_segments the bounds.
SEEKABS $000197
BASE $8187
COMPARE
rope_room_expect $45
ENDCOMPARE
SKIPREL -1
DB $46

SEEKABS $051810
BASE $0400
COMPARE
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $41
rope_room_expect $22
rope_room_expect $14
rope_room_expect $08
rope_room_expect $14
rope_room_expect $22
rope_room_expect $41
ENDCOMPARE
SKIPREL -16
INCBIN "sprite/rope.chr"

SEEKABS $051A80
BASE $0670
COMPARE
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $00
rope_room_expect $41
rope_room_expect $22
rope_room_expect $14
rope_room_expect $08
rope_room_expect $14
rope_room_expect $22
rope_room_expect $41
ENDCOMPARE
SKIPREL -16
INCBIN "Castlevania III - Dracula's Curse (USA).nes", $051680, $10

; Cap the rope with one 16x16 brick at X=$D0, Y=$30, against the wall.
SEEKABS $020152
BASE $8142
COMPARE
rope_room_expect $01
ENDCOMPARE
SKIPREL -1
DB (ROOM_ROPE_FIRST_META + 3)

; Replace column 6, rows 1-4. The right wall begins at X=$E0.
; Rows 1 and 4 share the same original cell and the same rope definition.
SEEKABS $02015A
BASE $814A
COMPARE
rope_room_expect $01
ENDCOMPARE
SKIPREL -1
DB ROOM_ROPE_FIRST_META
SEEKABS $020162
BASE $8152
COMPARE
rope_room_expect $17
ENDCOMPARE
SKIPREL -1
DB (ROOM_ROPE_FIRST_META + 1)
SEEKABS $02016A
BASE $815A
COMPARE
rope_room_expect $05
ENDCOMPARE
SKIPREL -1
DB (ROOM_ROPE_FIRST_META + 2)
SEEKABS $020172
BASE $8162
COMPARE
rope_room_expect $01
ENDCOMPARE
SKIPREL -1
DB ROOM_ROPE_FIRST_META

; The right half forms a 16-pixel shaft at X=$D0-$DF, including an opening
; through the platform. The rope tile begins at X=$D8 and uses palette zero.
FILLVALUE $FF
COMPARE
SEEKABS $023FA3
BASE $BF93
rope_room_metatiles:
    DB $3D, $A8, $00, ROOM_ROPE_TILE
    DB $67, $AA, $00, ROOM_ROPE_TILE
    DB $AF, $AA, $00, ROOM_ROPE_TILE
    DB $AA, $A8, $00, ROOM_ROPE_TILE

    DB $BC, $BE, $00, ROOM_ROPE_TILE
    DB $BD, $BF, $00, ROOM_ROPE_TILE
    DB $AA, $A8, $00, ROOM_ROPE_TILE
    DB $AB, $8A, $00, ROOM_ROPE_TILE

    DB $A8, $A8, $00, ROOM_ROPE_TILE
    DB $AA, $AB, $00, ROOM_ROPE_TILE
    DB $AA, $94, $00, ROOM_ROPE_TILE
    DB $A9, $3D, $00, ROOM_ROPE_TILE

    DB $3D, $A8, $A8, $00
    DB $67, $AA, $A8, $00
    DB $AF, $AA, $BC, $BE
    DB $AA, $A8, $BD, $BF
rope_room_attributes:
    DB $11, $10, $11, $15
IF $ > $C000
    ERROR "Rope metatiles exceed bank-$11 padding"
ENDIF
ENDCOMPARE

; Both direct and map-pointer metatile lookups join at $CF72.
SEEKABS $03CF82
BASE $CF72
COMPARE
rope_room_expect $85
rope_room_expect $63
rope_room_expect $0A
ENDCOMPARE
SKIPREL -3
JMP rope_room_get_tiles

; Adapt all five native attribute paths, preserving their displaced stores.
SEEKABS $03CC22
BASE $CC12
COMPARE
rope_room_expect $A4
rope_room_expect $63
rope_room_expect $B1
rope_room_expect $5F
rope_room_expect $9D
rope_room_expect $22
rope_room_expect $03
ENDCOMPARE
SKIPREL -7
JSR rope_room_get_attribute
STA $0322,X
NOP

SEEKABS $03CD3C
BASE $CD2C
COMPARE
rope_room_expect $A4
rope_room_expect $63
rope_room_expect $B1
rope_room_expect $5F
rope_room_expect $9D
rope_room_expect $00
rope_room_expect $03
ENDCOMPARE
SKIPREL -7
JSR rope_room_get_attribute
STA $0300,X
NOP

SEEKABS $03CF0E
BASE $CEFE
COMPARE
rope_room_expect $A4
rope_room_expect $63
rope_room_expect $B1
rope_room_expect $5F
rope_room_expect $A4
rope_room_expect $5C
ENDCOMPARE
SKIPREL -6
JSR rope_room_get_attribute
LDY $5C
NOP

SEEKABS $03D300
BASE $D2F0
COMPARE
rope_room_expect $A4
rope_room_expect $63
rope_room_expect $B1
rope_room_expect $5F
rope_room_expect $85
rope_room_expect $00
ENDCOMPARE
SKIPREL -6
JSR rope_room_get_attribute
STA $00
NOP

SEEKABS $03D550
BASE $D540
COMPARE
rope_room_expect $A4
rope_room_expect $63
rope_room_expect $B1
rope_room_expect $5F
rope_room_expect $9D
rope_room_expect $00
rope_room_expect $03
ENDCOMPARE
SKIPREL -7
JSR rope_room_get_attribute
STA $0300,X
NOP

; The camera bank calls these with the room's map bank already selected.
FILLVALUE $FF
COMPARE
SEEKABS $03C810
BASE $C800
rope_room_get_tiles:
    STA $63
    JSR rope_room_is_target
    BNE rope_room_get_native_tiles
    LDA $63
    CMP #ROOM_ROPE_FIRST_META
    BCC rope_room_get_native_tiles
    CMP #ROOM_ROPE_META_END
    BCS rope_room_get_native_tiles
    SEC
    SBC #ROOM_ROPE_FIRST_META
    ASL A
    ASL A
    ASL A
    ASL A
    CLC
    ADC #<rope_room_metatiles
    STA $02
    LDA #>rope_room_metatiles
    ADC #$00
    STA $03
    RTS
rope_room_get_native_tiles:
    LDA $63
    ASL A
    JMP $CF75

rope_room_get_attribute:
    LDY $63
    JSR rope_room_is_target
    BNE rope_room_get_native_attribute
    CPY #ROOM_ROPE_FIRST_META
    BCC rope_room_get_native_attribute
    CPY #ROOM_ROPE_META_END
    BCS rope_room_get_native_attribute
    LDA rope_room_attributes-ROOM_ROPE_FIRST_META,Y
    RTS
rope_room_get_native_attribute:
    LDA ($5F),Y
    RTS

rope_room_is_target:
    LDA $32
    ORA $34
    BNE rope_room_target_result
    LDA $33
    CMP #$01
rope_room_target_result:
    RTS
IF $ > $C900
    ERROR "Rope map adapters exceed the $C800-$C8FF padding"
ENDIF
ENDCOMPARE

DEBUG_MENU_APPEND = 1
INCLUDE "asm/US/debug_menu.asm"
