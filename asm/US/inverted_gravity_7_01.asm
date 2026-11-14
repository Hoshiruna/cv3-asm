; SPDX-License-Identifier: MIT
; Assemble from the project root with nstbayless/asm6f (INCNES and SEEKABS).

INCNES "Castlevania III - Dracula's Curse (USA).nes"
CLEARPATCH

; Castlevania III (USA), MMC5, Ricoh 2A03.
; Adds one inverted-gravity strip to Stage 07, Block 00, Room 01.

game_state                 = $18
stage_index                = $32
block_index                = $33
room_index                 = $34
scroll_offset              = $56
scroll_screen              = $57
room_metadata              = $68

player_y                   = $041C
player_x                   = $0438
player_fraction_y          = $04DB
player_speed_y             = $0520
player_subspeed_y          = $0537
current_character          = $054E
player_state               = $0565
player_phase               = $05C1
player_jump_timer          = $05D8
player_stair_alignment     = $0606

grant_jump_flag            = $9D
player_landing_timer       = $B9

current_oam_offset         = $04
current_entity_index       = $05
frame_oam_offset           = $20
oam_buffer                 = $0200

GAME_STATE_PLAYING         = $04
CHAR_GRANT                 = $02
STATE_IDLE                 = $02
STATE_WALK                 = $04
STATE_FALL                 = $0C
STATE_DUCK                 = $0A

GRAVITY_STAGE              = $07
GRAVITY_BLOCK              = $00
GRAVITY_ROOM               = $01
GRAVITY_LEFT               = $40
GRAVITY_RIGHT              = $D0
GRAVITY_ACTIVE             = $80

GRAVITY_CODE_PRG_BANK      = $98 ; MMC5 16 KiB pair $18/$19.
PLAYER_PRG_BANK            = $9C ; MMC5 16 KiB pair $1C/$1D.

set_lower_prg_bank         = $E2E6

MACRO gravity_expect value
    FILLVALUE value
    DB value
ENDM

; Run the room check before the native character dispatcher.
SEEKABS $038AA1
BASE $8A91
COMPARE
gravity_expect $AC
gravity_expect $4E
gravity_expect $05
ENDCOMPARE
SKIPREL -3
JMP gravity_player_dispatch

; Replace the horizontal-room vertical integrator. The room-layout check at
; $8712-$8715 still runs before this hook.
SEEKABS $038726
BASE $8716
COMPARE
gravity_expect $AD
gravity_expect $DB
gravity_expect $04
ENDCOMPARE
SKIPREL -3
JMP gravity_move_y

; This collision entry is player-specific. Mirror its signed Y probe while
; the room flag is set, then resume the native horizontal or vertical path.
SEEKABS $03FCED
BASE $FCDD
COMPARE
gravity_expect $48
gravity_expect $A5
gravity_expect $68
ENDCOMPARE
SKIPREL -3
JMP gravity_collision

; The player is the first entity rendered. Process its completed OAM range
; before the renderer advances to the next entity.
SEEKABS $03404D
BASE $803D
COMPARE
gravity_expect $E6
gravity_expect $05
gravity_expect $D0
gravity_expect $DA
ENDCOMPARE
SKIPREL -4
JMP gravity_oam_next
NOP

; The dispatcher hook needs a fixed-bank bridge because the room code lives
; in bank $19. Restoring $9C also restores the native player state handlers.
FILLVALUE $FF
COMPARE
SEEKABS $03FFDA
BASE $FFCA

gravity_player_dispatch:
    PHP
    PHA
    TXA
    PHA
    LDA #GRAVITY_CODE_PRG_BANK
    JSR set_lower_prg_bank
    JSR gravity_player_tick
    LDA #PLAYER_PRG_BANK
    JSR set_lower_prg_bank
    PLA
    TAX
    PLA
    PLP
    LDY current_character
    JMP $8A94

IF $ > $FFF0
    ERROR "Gravity dispatcher exceeds the $FFCA-$FFEF fixed-bank padding"
ENDIF
ENDCOMPARE

; Update the room flag once per player frame. The high bit of the native
; stair-alignment byte is unused in this stairless room.
FILLVALUE $FF
COMPARE
SEEKABS $033685
BASE $B675

gravity_player_tick:
    LDA player_stair_alignment
    BPL gravity_player_check_zone
    JSR gravity_normalize_speed

gravity_player_check_zone:
    JSR gravity_zone_active
    BEQ gravity_player_disable
    LDA player_stair_alignment
    BMI gravity_player_done
    ORA #GRAVITY_ACTIVE
    STA player_stair_alignment
    JSR gravity_begin_fall
gravity_player_done:
    RTS

gravity_player_disable:
    LDA player_stair_alignment
    BPL gravity_player_done
    AND #($FF ^ GRAVITY_ACTIVE)
    STA player_stair_alignment
    JSR gravity_begin_fall
    RTS

; A=$80 inside the strip, A=$00 elsewhere. The target is Stage 07,
; Block 00, Room 01. The strip occupies the central $90 pixels of the
; first horizontal page.
gravity_zone_active:
    LDA game_state
    CMP #GAME_STATE_PLAYING
    BNE gravity_zone_inactive
    LDA stage_index
    CMP #GRAVITY_STAGE
    BNE gravity_zone_inactive
    LDA block_index
    CMP #GRAVITY_BLOCK
    BNE gravity_zone_inactive
    LDA room_index
    CMP #GRAVITY_ROOM
    BNE gravity_zone_inactive
    LDA room_metadata
    BMI gravity_zone_inactive
    LDA scroll_screen
    BNE gravity_zone_inactive
    CLC
    LDA player_x
    ADC scroll_offset
    BCS gravity_zone_inactive
    CMP #GRAVITY_LEFT
    BCC gravity_zone_inactive
    CMP #GRAVITY_RIGHT
    BCS gravity_zone_inactive
    LDA #GRAVITY_ACTIVE
    RTS
gravity_zone_inactive:
    LDA #$00
    RTS

; Entering from the floor or leaving from the ceiling starts a clean fall.
; Airborne transitions keep their current jump phase and mirror immediately.
gravity_begin_fall:
    LDA player_state
    CMP #STATE_IDLE
    BEQ gravity_begin_fall_grounded
    CMP #STATE_WALK
    BEQ gravity_begin_fall_grounded
    CMP #STATE_DUCK
    BNE gravity_begin_fall_done
gravity_begin_fall_grounded:
    LDA #$00
    STA player_fraction_y
    STA player_speed_y
    STA player_subspeed_y
    STA grant_jump_flag
    STA player_landing_timer
    LDA #$01
    STA player_phase
    LDA #STATE_FALL
    STA player_state
    STA player_jump_timer
    LDA current_character
    CMP #CHAR_GRANT
    BNE gravity_begin_fall_done
    LDA #$38
    STA player_jump_timer
gravity_begin_fall_done:
    RTS

; The movement hook leaves the stored speed mirrored. Convert it back before
; the next state update so native jump and damage code sees its usual sign.
gravity_normalize_speed:
    SEC
    LDA #$00
    SBC player_subspeed_y
    STA player_subspeed_y
    LDA #$00
    SBC player_speed_y
    STA player_speed_y
    RTS

IF $ > $C000
    ERROR "Gravity room logic exceeds the $B675-$BFFF bank-$19 padding"
ENDIF
ENDCOMPARE

; These routines must stay in the native player pair because the fixed-bank
; collision hook enters them without changing the lower PRG mapping.
FILLVALUE $FF
COMPARE
SEEKABS $03BFBB
BASE $BFAB

gravity_collision:
    PHA
    LDA player_stair_alignment
    BPL gravity_collision_resume
    TXA
    EOR #$FF
    SEC
    LDY current_character
    CPY #CHAR_GRANT
    BEQ gravity_collision_grant
    SBC #$07 ; Mirror around Y=-4: transformed probe = -8 - original.
    JMP gravity_collision_store
gravity_collision_grant:
    SBC #$03 ; Grant is shorter: transformed probe = -4 - original.
gravity_collision_store:
    TAX
gravity_collision_resume:
    LDA room_metadata
    BMI gravity_collision_vertical
    JMP $FCE2
gravity_collision_vertical:
    JMP $FC7F

gravity_move_y:
    LDA player_stair_alignment
    BMI gravity_move_inverted
    LDA player_fraction_y
    JMP $8719

gravity_move_inverted:
    SEC
    LDA #$00
    SBC player_subspeed_y
    STA player_subspeed_y
    LDA #$00
    SBC player_speed_y
    STA player_speed_y
    LDA player_fraction_y
    JMP $8719

IF $ > $C000
    ERROR "Gravity player hooks exceed the $BFAB-$BFFF bank-$1D padding"
ENDIF
ENDCOMPARE

; Flip every visible 8x16 sprite emitted for entity zero around the player's
; collision center. Hidden $F4 entries stay hidden.
FILLVALUE $FF
COMPARE
SEEKABS $037E73
BASE $BE63

gravity_oam_next:
    LDA current_entity_index
    BNE gravity_oam_advance
    LDA game_state
    CMP #GAME_STATE_PLAYING
    BNE gravity_oam_advance
    LDA player_stair_alignment
    BPL gravity_oam_advance
    LDX frame_oam_offset
gravity_oam_loop:
    CPX current_oam_offset
    BEQ gravity_oam_advance
    LDA oam_buffer,X
    CMP #$F4
    BEQ gravity_oam_piece_done
    LDA player_y
    ASL A
    SEC
    SBC oam_buffer,X
    LDY current_character
    CPY #CHAR_GRANT
    BEQ gravity_oam_grant
    SEC
    SBC #$18
    JMP gravity_oam_store_y
gravity_oam_grant:
    SEC
    SBC #$14
gravity_oam_store_y:
    STA oam_buffer,X
    LDA oam_buffer+2,X
    EOR #$80
    STA oam_buffer+2,X
gravity_oam_piece_done:
    TXA
    CLC
    ADC #$C4
    TAX
    JMP gravity_oam_loop

gravity_oam_advance:
    INC current_entity_index
    JMP $801B

IF $ > $C000
    ERROR "Gravity OAM flip exceeds the $BE63-$BFFF bank-$1B padding"
ENDIF
ENDCOMPARE

DEBUG_MENU_APPEND = 1
INCLUDE "asm/US/debug_menu.asm"
