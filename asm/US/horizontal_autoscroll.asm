; SPDX-License-Identifier: MIT
; Assemble from the project root with nstbayless/asm6f (INCNES and SEEKABS).

INCNES "Castlevania III - Dracula's Curse (USA).nes"
CLEARPATCH

; Castlevania III (USA), MMC5, Ricoh 2A03.
; Uses bank $1E padding, separate from better_stair.asm.

game_state                 = $18
lower_prg_bank             = $21
gameplay_substate          = $2A
cinematic_controller       = $2C
stage_index                = $32
block_index                = $33
room_index                 = $34
scroll_direction           = $65
room_metadata              = $68
scroll_delta               = $6E ; Signed horizontal camera displacement this frame.
boss_active                = $78
player_collision_shape     = $82 ; Character index, +4 crouched, $08 in bat form.
player_x                   = $0438
player_speed_x             = $04F2
player_subspeed_x          = $0509

SCROLL_LEFT                = $00
SCROLL_RIGHT               = $01
SCROLL_DISABLED            = $FF
SCREEN_LEFT                = $18
SCREEN_RIGHT               = $E8

; Unsigned 8.8 pixels per frame, from $0001 through $0100 (one pixel).
; The native column renderer needs several frames to prepare each column.
HORIZONTAL_SCROLL_SPEED    = $0030

IF HORIZONTAL_SCROLL_SPEED < $0001
    ERROR "Horizontal scroll speed must be at least $0001"
ENDIF
IF HORIZONTAL_SCROLL_SPEED > $0100
    ERROR "Horizontal scroll speed must not exceed $0100"
ENDIF

native_player_scroll_check = $8748
native_player_move         = $8762
native_scroll_continue     = $D179
native_player_wall_check   = $915E ; A = signed X probe, carry set when blocked.
native_player_death        = $8398 ; Enter the normal death animation immediately.
set_lower_prg_bank         = $E2E6
native_tile_collision      = $FCDD ; A = signed X offset, X = signed Y offset.
PLAYER_PRG_BANK            = $9C ; MMC5 16 KiB pair $1C/$1D.

horizontal_probe_x         = $00 ; Scratch used by the native wall probes.

; Retain the preceding boss check at $8740. It skips this hook while
; $C000-$DFFF can be mapped to DPCM data instead of game code.
SEEKABS $038754
BASE $8744
COMPARE
FILLVALUE $A5
DB $A5
FILLVALUE $68
DB $68
FILLVALUE $30
DB $30
FILLVALUE $1A
DB $1A
ENDCOMPARE
SKIPREL -4
JMP horizontal_player_camera
NOP

; Wrap the entire camera/column update so its direction-history bytes
; see the forced direction before the native renderer reads them.
SEEKABS $03D185
BASE $D175
COMPARE
FILLVALUE $A5
DB $A5
FILLVALUE $65
DB $65
FILLVALUE $C9
DB $C9
FILLVALUE $02
DB $02
ENDCOMPARE
SKIPREL -4
JMP horizontal_scroll_tick
NOP

FILLVALUE $FF
COMPARE
SEEKABS $03DC28
BASE $DC18

; Player movement must update screen X even when crossing the center.
; The camera tick applies its own displacement after player processing.
horizontal_player_camera:
    LDA room_metadata
    BMI horizontal_player_move
    JSR horizontal_scroll_room
    CMP #SCROLL_DISABLED
    BNE horizontal_player_move
    JMP native_player_scroll_check
horizontal_player_move:
    JMP native_player_move

horizontal_scroll_tick:
    JSR horizontal_scroll_room
    CMP #SCROLL_DISABLED
    BNE horizontal_scroll_forced
    JMP horizontal_scroll_native

horizontal_scroll_forced:
    STA scroll_direction
    TAY
    ; The native camera integrates the player's speed. Lend it the forced
    ; speed for this call, then restore both bytes before entity processing.
    LDA player_speed_x
    PHA
    LDA player_subspeed_x
    PHA
    LDA horizontal_speed_fraction,Y
    STA player_subspeed_x
    LDA horizontal_speed_integer,Y
    STA player_speed_x
    JSR horizontal_scroll_native
    PLA
    STA player_subspeed_x
    PLA
    STA player_speed_x

    ; Use the actual displacement, including room-end clamping and the
    ; fractional accumulator. Other entities already consume scroll_delta.
    LDA scroll_delta
    BEQ horizontal_scroll_done
    BMI horizontal_scroll_camera_left
    SEC
    LDA player_x
    SBC scroll_delta
    BCC horizontal_scroll_clamp_left
    CMP #SCREEN_LEFT
    BCS horizontal_scroll_store_x
horizontal_scroll_clamp_left:
    LDA #SCREEN_LEFT
    STA player_x
    JMP horizontal_scroll_check_crush

horizontal_scroll_camera_left:
    SEC
    LDA player_x
    SBC scroll_delta
    BCS horizontal_scroll_clamp_right
    CMP #(SCREEN_RIGHT + 1)
    BCC horizontal_scroll_store_x
horizontal_scroll_clamp_right:
    LDA #SCREEN_RIGHT
    STA player_x
    JMP horizontal_scroll_check_crush
horizontal_scroll_store_x:
    STA player_x
horizontal_scroll_done:
    RTS

; Clamping the trailing edge pushes the player through world space. Check
; the pushed side using the native character-height probes before it can
; enter a wall. Open ground at the screen edge still permits movement.
horizontal_scroll_check_crush:
    LDA lower_prg_bank
    PHA
    LDA #PLAYER_PRG_BANK
    JSR set_lower_prg_bank
    LDA scroll_delta
    BMI horizontal_scroll_probe_left
    LDA #$08
    BNE horizontal_scroll_probe_wall
horizontal_scroll_probe_left:
    LDA #$F8
horizontal_scroll_probe_wall:
    LDY player_collision_shape
    CPY #$08
    BEQ horizontal_scroll_probe_bat
    JSR native_player_wall_check
    BCC horizontal_scroll_restore_bank
horizontal_scroll_crushed:
    JSR native_player_death
horizontal_scroll_restore_bank:
    PLA
    JMP set_lower_prg_bank

; Bat form uses the same +/-6-pixel vertical probes as its native movement.
horizontal_scroll_probe_bat:
    STA horizontal_probe_x
    LDX #$FA
    JSR native_tile_collision
    BNE horizontal_scroll_crushed
    LDA horizontal_probe_x
    LDX #$06
    JSR native_tile_collision
    BNE horizontal_scroll_crushed
    BEQ horizontal_scroll_restore_bank

; Reproduce the displaced instructions and resume at the original BNE.
; JMP preserves the comparison flags used by the native direction history.
horizontal_scroll_native:
    LDA scroll_direction
    CMP #$02
    JMP native_scroll_continue

; A = configured direction or $FF. X and Y are preserved using the stack.
; Gameplay substates $03/$0A use the horizontal camera (ordinary/water rooms).
horizontal_scroll_room:
    LDA game_state
    CMP #$04
    BNE horizontal_scroll_disabled
    LDA cinematic_controller
    ORA boss_active
    BNE horizontal_scroll_disabled
    LDA room_metadata
    BMI horizontal_scroll_disabled
    LDA gameplay_substate
    CMP #$03
    BEQ horizontal_scroll_find
    CMP #$0A
    BNE horizontal_scroll_disabled

horizontal_scroll_find:
    TYA
    PHA
    LDY #$00
horizontal_scroll_find_room:
    LDA horizontal_scroll_rooms,Y
    CMP #$FF
    BEQ horizontal_scroll_not_found
    CMP stage_index
    BNE horizontal_scroll_next_room
    LDA horizontal_scroll_rooms+1,Y
    CMP block_index
    BNE horizontal_scroll_next_room
    LDA horizontal_scroll_rooms+2,Y
    CMP room_index
    BNE horizontal_scroll_next_room
    LDA horizontal_scroll_rooms+3,Y
    CMP #SCROLL_RIGHT
    BEQ horizontal_scroll_found_right
    PLA
    TAY
    LDA #SCROLL_LEFT
    RTS
horizontal_scroll_found_right:
    PLA
    TAY
    LDA #SCROLL_RIGHT
    RTS
horizontal_scroll_next_room:
    INY
    INY
    INY
    INY
    BNE horizontal_scroll_find_room
horizontal_scroll_not_found:
    PLA
    TAY
horizontal_scroll_disabled:
    LDA #SCROLL_DISABLED
    RTS

horizontal_speed_fraction:
    DB ((-HORIZONTAL_SCROLL_SPEED) & $FF), (HORIZONTAL_SCROLL_SPEED & $FF)
horizontal_speed_integer:
    DB (((-HORIZONTAL_SCROLL_SPEED) >> 8) & $FF), (HORIZONTAL_SCROLL_SPEED >> 8)

; Each record is stage ($32), block ($33), room ($34), direction.
; These are internal zero-based IDs. The table is intentionally empty until
; rooms are selected. Insert records before the $FF terminator, for example
;     DB $00, $00, $00, SCROLL_RIGHT
;     DB $00, $00, $01, SCROLL_LEFT
; Leftward scrolling starts from the room's existing camera position.
horizontal_scroll_rooms:
    DB $FF
horizontal_scroll_rooms_end:

IF (horizontal_scroll_rooms_end - horizontal_scroll_rooms) > $FD
    ERROR "Horizontal scroll table supports at most 63 rooms"
ENDIF
IF $ > $E000
    ERROR "Horizontal scroll code exceeds the $DC18-$DFFF bank-$1E padding"
ENDIF
ENDCOMPARE
