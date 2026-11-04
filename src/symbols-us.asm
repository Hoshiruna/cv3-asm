; SPDX-License-Identifier: MIT
; Castlevania III (USA), MMC5, Ricoh 2A03.

game_state             = $18
lower_prg_bank         = $21
joy_pressed            = $26
joy_held               = $28
gameplay_substate      = $2A
cinematic_controller   = $2C
scroll_offset          = $56
scroll_screen          = $57
room_metadata          = $68
room_stairs            = $69 ; Pointer into PRG bank $0F at $A000-$BFFF.

player_y               = $041C
player_x               = $0438
player_fraction_x      = $04C4
player_fraction_y      = $04DB
player_speed_y         = $0520
current_character      = $054E
player_state           = $0565
player_phase           = $05C1
player_stair_direction = $05EF
player_stair_alignment = $0606

PAD_A                  = $80
PAD_B                  = $40
PAD_UP                 = $08
PAD_DOWN               = $04
CHAR_GRANT             = $02
STATE_IDLE             = $02
STATE_WALK             = $04
STATE_JUMP_START       = $06
STATE_JUMP             = $08
STATE_FALL             = $0C
STATE_APPROACH_STAIRS  = $0E
STATE_ENTER_STAIRS     = $10
STATE_STAIR_IDLE       = $12
STATE_STAIR_MOVE       = $14
STAIRS_PRG_BANK        = $8E ; MMC5 16 KiB pair $0E/$0F.
ATTACH_TOLERANCE       = $05

set_lower_prg_bank     = $E2E6
start_stair_ascent     = $9B8E ; Sets animation, facing, X/Y speed and state $14.

; Scratch bytes live only during stair_controls_tick, before state dispatch.
; The original state handlers reuse this same temporary zero-page area.
stair_player_x         = $00 ; 16-bit world coordinates.
stair_player_y         = $02
stair_endpoint_x       = $04
stair_endpoint_y       = $06
stair_delta_x          = $08 ; Signed player X minus endpoint X.
stair_projected_y      = $0A
stair_best_distance    = $0C ; Absolute horizontal distance to nearest endpoint.
stair_best_correction  = $0E ; Signed screen-Y correction, within tolerance.
stair_best_flags       = $0F
stair_best_side        = $10 ; High byte of the selected signed X displacement.
stair_endpoint_flags   = $11
stair_distance         = $12 ; 16-bit absolute displacement.
stair_correction       = $14
stair_slope            = $15 ; $00 ascends right, $40 ascends left.
