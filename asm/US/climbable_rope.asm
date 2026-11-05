; SPDX-License-Identifier: MIT
; Assemble from the project root with nstbayless/asm6f (INCNES and SEEKABS).
; This entry includes better_stair.asm. Assemble this entry once for both.
; Castlevania III (USA), MMC5, Ricoh 2A03.
;
; Hold Up or Down near a rope to grab it from the ground or while descending.
; Up/Down climbs one pixel per frame. A jumps off using native character
; physics. Down+A lets go immediately, with re-grab enabled when Down is
; released. The upper end stops ascent. Down at the lower end lets go.
; Rope graphics belong in the room's background tiles. The coordinate table
; below supplies the climbable segments independently of those graphics.

ROPE_CONTROLS_ENABLED   = 1
STATE_ROPE             = $4A ; Beyond Grant's native state table, intercepted here.
STATE_DUCK             = $0A
ROPE_ATTACH_TOLERANCE   = $06
ROPE_RECORD_SIZE        = 9
ROPE_DROP_LOCK          = $80 ; High phase bit during a manual airborne release.

rope_stage             = $32
rope_block             = $33
rope_room              = $34
rope_sprite            = $0400
rope_animation_timer   = $057C
rope_sprite_offset     = $0593
rope_jump_timer        = $05D8
rope_grant_jump_flag   = $9D
rope_landing_timer     = $B9
rope_tile_collision    = $FCDD ; A = signed X probe, X = signed Y probe.

; Scratch is shared with the stair search and dies before native dispatch.
; The fixed-bank collision reader uses $10-$14 and preserves these bytes.
rope_delta_x           = $08
rope_original_x        = $0A
rope_probe_y           = $0B
rope_record_index      = $0C

INCLUDE "asm/US/better_stair.asm"

; Continue in the same bank-$19 padding, immediately after stair_attach.
FILLVALUE $FF
COMPARE

; C=1 consumes this frame's stair input, including jump/release frames.
; The custom state itself owns attachment. Native damage, death and
; character changes replace that state and immediately end rope control.
rope_controls_update:
    LDA game_state
    CMP #$04
    BNE rope_controls_unavailable
    LDA cinematic_controller
    BNE rope_controls_unavailable
    LDA gameplay_substate
    CMP #$03
    BEQ rope_controls_gameplay
    CMP #$05
    BEQ rope_controls_gameplay
    CMP #$0A
    BEQ rope_controls_gameplay
rope_controls_unavailable:
    LDA player_state
    CMP #STATE_ROPE
    BNE rope_controls_unused
    JMP rope_release
rope_controls_unused:
    CLC
    RTS

rope_controls_gameplay:
    LDA player_state
    CMP #STATE_ROPE
    BNE rope_controls_try_grab
    JMP rope_controls_attached

rope_controls_try_grab:
    ; Native jump/fall handlers use phase zero for ascent and nonzero for
    ; descent. Its high bit holds the manual-release latch while airborne.
    LDA player_state
    CMP #STATE_JUMP
    BEQ rope_controls_check_drop
    CMP #STATE_FALL
    BNE rope_controls_grab_buttons
rope_controls_check_drop:
    LDA player_phase
    BPL rope_controls_grab_buttons
    LDA joy_held
    AND #PAD_DOWN
    BNE rope_controls_unused
    LDA player_phase
    AND #($FF ^ ROPE_DROP_LOCK)
    STA player_phase
rope_controls_grab_buttons:
    ; A held prevents catching the rope during jump preparation.
    LDA joy_held
    AND #(PAD_A | PAD_UP | PAD_DOWN)
    CMP #PAD_UP
    BEQ rope_controls_grab_direction
    CMP #PAD_DOWN
    BNE rope_controls_unused
rope_controls_grab_direction:
    LDA joy_pressed
    AND #PAD_B
    BNE rope_controls_unused
    LDA player_state
    CMP #STATE_IDLE
    BEQ rope_controls_find
    CMP #STATE_WALK
    BEQ rope_controls_find
    CMP #STATE_DUCK
    BEQ rope_controls_find
    CMP #STATE_JUMP
    BEQ rope_controls_descending
    CMP #STATE_FALL
    BNE rope_controls_unused
rope_controls_descending:
    LDA player_phase
    BEQ rope_controls_unused
    LDA player_speed_y
    BMI rope_controls_unused

rope_controls_find:
    JSR stair_get_player_position
    BCC rope_controls_unused
    LDY #$00
rope_controls_find_record:
    LDA rope_segments,Y
    CMP #$FF
    BEQ rope_controls_unused
    JSR rope_record_matches
    BCC rope_controls_next_record
    STY rope_record_index
    JSR rope_try_snap
    BCS rope_controls_grabbed
    LDY rope_record_index
rope_controls_next_record:
    TYA
    CLC
    ADC #ROPE_RECORD_SIZE
    TAY
    JMP rope_controls_find_record

rope_controls_grabbed:
    LDA #STATE_ROPE
    STA player_state
    LDA rope_record_index
    STA player_phase ; Record byte offset, only while state is STATE_ROPE.
    LDA #$00
    STA player_stair_step ; Animation distance counter while attached.
    STA rope_sprite_offset
    STA rope_animation_timer
    JMP rope_controls_hold

rope_controls_attached:
    JSR stair_get_player_position
    BCC rope_controls_lost
    LDY player_phase
    CPY #(rope_segments_end - rope_segments - 1)
    BCS rope_controls_lost
    JSR rope_record_matches
    BCS rope_controls_input
rope_controls_lost:
    JMP rope_release

rope_controls_input:
    LDA joy_pressed
    AND #PAD_A
    BEQ rope_controls_hold
    LDA joy_held
    AND #PAD_DOWN
    BNE rope_controls_drop
    JSR rope_clear_motion
    LDA #STATE_JUMP_START
    STA player_state
    SEC
    RTS

rope_controls_drop:
    JSR rope_release
    LDA player_phase
    ORA #ROPE_DROP_LOCK
    STA player_phase
    SEC
    RTS

rope_controls_hold:
    JSR rope_clear_motion
    LDA joy_held
    AND #(PAD_UP | PAD_DOWN)
    CMP #PAD_UP
    BEQ rope_controls_up
    CMP #PAD_DOWN
    BEQ rope_controls_down
    JMP rope_controls_pose

rope_controls_up:
    LDY player_phase
    LDA stair_player_y
    CMP rope_segments+5,Y
    BNE rope_controls_up_probe
    LDA stair_player_y+1
    CMP rope_segments+6,Y
    BEQ rope_controls_pose
rope_controls_up_probe:
    LDY current_character
    LDA rope_head_probe,Y
    STA rope_probe_y
    JSR rope_probe_sides
    BCS rope_controls_pose
    LDA #$FF
    STA player_speed_y
    JMP rope_controls_animate

rope_controls_down:
    LDY player_phase
    LDA stair_player_y
    CMP rope_segments+7,Y
    BNE rope_controls_down_probe
    LDA stair_player_y+1
    CMP rope_segments+8,Y
    BEQ rope_controls_lost
rope_controls_down_probe:
    ; Grant's native foot probes are four pixels above the others'.
    LDY current_character
    LDA rope_foot_probe,Y
    STA rope_probe_y
    JSR rope_probe_sides
    BCS rope_controls_lost
    LDA #$01
    STA player_speed_y
rope_controls_animate:
    INC player_stair_step
rope_controls_pose:
    LDY current_character
    LDA player_stair_step
    AND #$08
    BEQ rope_controls_pose_first
    INY
    INY
    INY
    INY
rope_controls_pose_first:
    LDA rope_pose_indices,Y
    STA rope_sprite
    SEC
    RTS

; Y is a record offset and is preserved. C=1 means the room, X tolerance
; and inclusive Y bounds match the normalized player origin.
rope_record_matches:
    LDA rope_segments,Y
    CMP rope_stage
    BNE rope_record_miss
    LDA rope_segments+1,Y
    CMP rope_block
    BNE rope_record_miss
    LDA rope_segments+2,Y
    CMP rope_room
    BNE rope_record_miss
    SEC
    LDA stair_player_x
    SBC rope_segments+3,Y
    STA rope_delta_x
    LDA stair_player_x+1
    SBC rope_segments+4,Y
    BEQ rope_record_right
    CMP #$FF
    BNE rope_record_miss
    LDA rope_delta_x
    CMP #($100 - ROPE_ATTACH_TOLERANCE)
    BCC rope_record_miss
    BCS rope_record_y
rope_record_right:
    LDA rope_delta_x
    CMP #(ROPE_ATTACH_TOLERANCE + 1)
    BCS rope_record_miss
rope_record_y:
    LDA stair_player_y+1
    CMP rope_segments+6,Y
    BCC rope_record_miss
    BNE rope_record_bottom
    LDA stair_player_y
    CMP rope_segments+5,Y
    BCC rope_record_miss
rope_record_bottom:
    LDA rope_segments+8,Y
    CMP stair_player_y+1
    BCC rope_record_miss
    BNE rope_record_hit
    LDA rope_segments+7,Y
    CMP stair_player_y
    BCC rope_record_miss
rope_record_hit:
    SEC
    RTS
rope_record_miss:
    CLC
    RTS

; Snap only through empty space at the head, torso and feet. The largest
; correction is six pixels, so each side can cross at most one tile edge.
rope_try_snap:
    LDA player_x
    STA rope_original_x
    SEC
    SBC rope_delta_x
    STA player_x
    LDY current_character
    LDA rope_head_probe,Y
    CLC
    ADC #$01 ; Check the current head position before the first upward step.
    STA rope_probe_y
    JSR rope_probe_sides
    BCS rope_snap_blocked
    LDA #$00
    STA rope_probe_y
    JSR rope_probe_sides
    BCS rope_snap_blocked
    LDY current_character
    LDA rope_foot_probe,Y
    SEC
    SBC #$02 ; Leave the supporting floor outside the grab probes.
    STA rope_probe_y
    JSR rope_probe_sides
    BCS rope_snap_blocked
    SEC
    RTS
rope_snap_blocked:
    LDA rope_original_x
    STA player_x
    CLC
    RTS

; C=1 for a nonempty tile at either side of the requested height.
; Collision probes overwrite Y and $10-$14.
rope_probe_sides:
    LDA #$FB
    LDX rope_probe_y
    JSR rope_tile_collision
    BNE rope_probe_blocked
    LDA #$05
    LDX rope_probe_y
    JSR rope_tile_collision
    BNE rope_probe_blocked
    CLC
    RTS
rope_probe_blocked:
    SEC
    RTS

rope_release:
    JSR rope_clear_motion
    LDA #$00
    STA player_stair_direction
    STA player_stair_alignment
    STA rope_grant_jump_flag
    STA rope_landing_timer
    LDA #$01
    STA player_phase
    STA player_stair_step
    LDA #STATE_FALL
    STA player_state
    STA rope_jump_timer
    LDA current_character
    CMP #CHAR_GRANT
    BNE rope_release_ready
    ; Grant indexes a different jump curve. $38 starts its falling half.
    LDA #$38
    STA rope_jump_timer
rope_release_ready:
    LDA #$02
    STA rope_sprite
    SEC
    RTS

rope_clear_motion:
    LDA #$00
    STA player_speed_x
    STA player_subspeed_x
    STA player_speed_y
    STA player_subspeed_y
    STA player_fraction_x
    STA player_fraction_y
    RTS

; Probe one pixel beyond each character's native head/foot collision edge.
; Character order is Trevor, Sypha, Grant, Alucard.
rope_head_probe:
    DB $E7, $E7, $EF, $E7
rope_foot_probe:
    DB $11, $11, $0D, $11

; Two OAM-spec frames per character, eight moved pixels per frame.
; All entries currently reuse the native idle pose ($02). Replace these
; even-numbered indices after installing the climbing sprite definitions.
rope_pose_indices:
    DB $02, $02, $02, $02 ; First frame.
    DB $02, $02, $02, $02 ; Second frame.

; Each record is stage, block, room, followed by 16-bit little-endian X,
; top Y and bottom Y. The three IDs match RAM $32/$33/$34.
; X is the rope center. Y bounds describe the normalized player origin.
; Grant's origin is normalized four pixels upward, as for stairs.
; Horizontal rooms use world X = screen X + $56 + 256*$57, Y = screen Y.
; Vertical rooms use X = screen X, world Y = screen Y - $33 + $56 + 240*$57.
;
; Example for horizontal room 00/00/00, X=$0180, origin Y=$0060..$00B0
;     DB $00, $00, $00
;     DW $0180, $0060, $00B0
;
; Insert records before $FF. Put ropes in open columns with head clearance.
; The room artwork must draw the corresponding rope at these coordinates.
rope_segments:
IFDEF ROPE_ROOM_1_02
    ; Stage 1 block 02, next to the right wall. Keep the player's +/-5
    ; probes inside the shaft. The visual center is one pixel to the right.
    DB $00, $01, $00
    DW $00DA, $0050, $00B0
ENDIF
    DB $FF
rope_segments_end:

IF (rope_segments_end - rope_segments) > $FD
    ERROR "Rope table supports at most 28 segments"
ENDIF
IF ((rope_segments_end - rope_segments - 1) % ROPE_RECORD_SIZE) <> 0
    ERROR "Each rope record must contain exactly nine bytes"
ENDIF
IF $ > $C000
    ERROR "Stair and rope controls exceed the shared bank-$19 padding"
ENDIF
ENDCOMPARE
