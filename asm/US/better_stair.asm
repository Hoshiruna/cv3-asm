; SPDX-License-Identifier: MIT
; Assemble from the project root with nstbayless/asm6f (INCNES and SEEKABS).

INCNES "Castlevania III - Dracula's Curse (USA).nes"
CLEARPATCH

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
player_speed_x         = $04F2
player_subspeed_x      = $0509
player_speed_y         = $0520
player_subspeed_y      = $0537
current_character      = $054E
player_state           = $0565
player_phase           = $05C1
player_stair_direction = $05EF
player_stair_alignment = $0606
player_stair_step      = $061D

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
STAIR_CODE_PRG_BANK    = $98 ; MMC5 16 KiB pair $18/$19.
ATTACH_TOLERANCE       = $01
STAIR_POSITION_CHECKED = $80 ; Cached only while idle on a staircase.

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
stair_bounds           = $10 ; Bits 0/1 mark lower/upper bounds, bit 7 an outside nearest endpoint.
stair_endpoint_flags   = $11
stair_distance         = $12 ; 16-bit absolute displacement.
stair_correction       = $14
stair_slope            = $15 ; $00 ascends right, $40 ascends left.

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
IFDEF ROPE_CONTROLS_ENABLED
JMP stair_controls_tick
ELSE
JSR stair_controls_tick
ENDIF

; All code regions are padding in the unmodified US ROM.
; COMPARE rejects occupied space when applying to another hack.
FILLVALUE $FF
COMPARE

; This entry shares the player bank with the dispatch hook and stair handler.
; $C000-$DFFF can contain either game code or DPCM data during boss fights.
SEEKABS $03BFBB
BASE $BFAB

stair_controls_tick:
IFDEF ROPE_CONTROLS_ENABLED
    PHP
    PHA
    TXA
    PHA
    JSR stair_call_controls
    BCC stair_rope_dispatch
    JSR start_stair_ascent
stair_rope_dispatch:
    LDA player_state
    CMP #STATE_ROPE
    BEQ stair_rope_move
    PLA
    TAX
    PLA
    PLP
    LDY current_character
    JMP $8A94 ; Original character dispatch, after the displaced LDY.
stair_rope_move:
    PLA
    TAX
    PLA
    PLP
    JSR $8712 ; Native Y movement also requests vertical camera scrolling.
    JMP $8AA5 ; Keep the shared hazards and post-state processing.
ELSE
    PHP
    PHA
    TXA
    PHA
    ; Idle and in-progress stair steps need no repeated room-table search.
    LDA joy_pressed
    AND #PAD_A
    BNE stair_controls_call
    LDA player_state
    CMP #STATE_STAIR_MOVE
    BEQ stair_controls_step
    CMP #STATE_STAIR_IDLE
    BEQ stair_controls_idle
    CMP #STATE_APPROACH_STAIRS
    BEQ stair_controls_restore
    CMP #STATE_ENTER_STAIRS
    BEQ stair_controls_restore
    LDA joy_held
    AND #(PAD_UP | PAD_DOWN)
    CMP #PAD_UP
    BNE stair_controls_restore
    BEQ stair_controls_call
stair_controls_step:
    LDA player_stair_step
    BNE stair_controls_restore
    BEQ stair_controls_call
stair_controls_idle:
    LDA joy_held
    AND #$0F
    BNE stair_controls_call
    LDA player_phase
    BMI stair_controls_restore
stair_controls_call:
    JSR stair_call_controls
    BCC stair_controls_restore
    ; The player bank is mapped again before starting the ascent.
    JSR start_stair_ascent
stair_controls_restore:
    PLA
    TAX
    PLA
    PLP
    ; Reproduce the displaced LDY, including the flags used by BEQ $8AA2.
    LDY current_character
    RTS
ENDIF

IF $ > $C000
    ERROR "Stair entry exceeds the $BFAB-$BFFF player-bank padding"
ENDIF

; Bank switches execute in the permanently mapped final 8 KiB bank.
SEEKABS $03FFDA
BASE $FFCA

stair_call_controls:
    LDA lower_prg_bank
    PHA
    LDA #STAIR_CODE_PRG_BANK
    JSR set_lower_prg_bank
    JSR stair_controls_update
    ; The bank setter and PLA preserve the attachment result in carry.
    PLA
    JSR set_lower_prg_bank
    RTS

; Fetch all three endpoint bytes in one visit to the stair-data bank.
stair_read_record:
    LDA #STAIRS_PRG_BANK
    JSR set_lower_prg_bank
    JSR stair_read_record_data
    LDA #STAIR_CODE_PRG_BANK
    JMP set_lower_prg_bank

IF $ > $FFF0
    ERROR "Stair bank calls exceed the $FFCA-$FFEF fixed-bank padding"
ENDIF

; $BFCB terminates the stair table for room $0E/$02/$01.
SEEKABS $01FFDC
BASE $BFCC

; Y advances to the next record. The terminator has no coordinate bytes.
stair_read_record_data:
    LDA (room_stairs),Y
    STA stair_endpoint_flags
    CMP #$FF
    BEQ stair_read_record_done
    INY
    LDA (room_stairs),Y
    STA stair_endpoint_x
    INY
    LDA (room_stairs),Y
    STA stair_endpoint_x+1
    INY
stair_read_record_done:
    RTS

IF $ > $C000
    ERROR "Stair record reader exceeds the $BFCC-$BFFF bank-$0F padding"
ENDIF

SEEKABS $033690
BASE $B680

; C=1 requests ascent after the player bank has been restored.
stair_controls_update:
IFDEF ROPE_CONTROLS_ENABLED
    JSR rope_controls_update
    BCC stair_controls_without_rope
    ; Rope input has been handled. Carry only requests native stair ascent.
    CLC
    RTS
stair_controls_without_rope:
ENDIF
    LDA game_state
    CMP #$04
    BEQ stair_controls_check_cinematic
    CLC
    RTS
stair_controls_check_cinematic:
    LDA cinematic_controller
    BEQ stair_controls_check_substate
    CLC
    RTS
stair_controls_check_substate:
    LDA gameplay_substate
    CMP #$03
    BEQ stair_controls_gameplay
    CMP #$05
    BEQ stair_controls_gameplay
    CMP #$0A
    BEQ stair_controls_gameplay
    CLC
    RTS

stair_controls_gameplay:
    LDA player_state
    CMP #STATE_APPROACH_STAIRS
    BEQ stair_controls_on_stairs
    CMP #STATE_ENTER_STAIRS
    BEQ stair_controls_on_stairs
    CMP #STATE_STAIR_IDLE
    BEQ stair_controls_validate
    CMP #STATE_STAIR_MOVE
    BEQ stair_controls_validate

    ; Keep jump and attack button presses ahead of staircase attachment.
    LDA joy_pressed
    AND #(PAD_A | PAD_B)
    BNE stair_controls_return
    LDA joy_held
    AND #(PAD_UP | PAD_DOWN)
    CMP #PAD_UP
    BNE stair_controls_return
    LDA player_state
    CMP #STATE_IDLE
    BEQ stair_controls_find
    CMP #STATE_WALK
    BEQ stair_controls_find
    CMP #STATE_JUMP
    BEQ stair_controls_airborne
    CMP #STATE_FALL
    BNE stair_controls_return

stair_controls_airborne:
    ; Allow a descending catch. A jump leaving the stairs keeps its ascent.
    ; Phase zero includes the jump's stationary preparation frames.
    LDA player_phase
    BEQ stair_controls_return
    LDA player_speed_y
    BMI stair_controls_return

stair_controls_find:
    JSR stair_find_attachment
    BCC stair_controls_return
    JMP stair_attach

stair_controls_on_stairs:
    LDA joy_pressed
    AND #PAD_A
    BEQ stair_controls_return
    ; The character dispatcher runs its own jump-start handler this frame.
    LDA #STATE_JUMP_START
    STA player_state

stair_controls_return:
    CLC
    RTS

stair_controls_validate:
    LDA joy_pressed
    AND #PAD_A
    BNE stair_controls_on_stairs
    JSR stair_find_attachment
    BCC stair_controls_fall
    LDA stair_best_distance
    ORA stair_best_distance+1
    BNE stair_controls_valid
    ; An endpoint permits movement back into the flight, not past its end.
    LDA player_state
    CMP #STATE_STAIR_MOVE
    BEQ stair_controls_moving_direction
    LDA joy_held
    LSR A
    BCS stair_controls_right
    LSR A
    BCS stair_controls_left
    LSR A
    BCS stair_controls_down
    LSR A
    BCC stair_controls_valid
    LDA #$80
    BNE stair_controls_endpoint_direction
stair_controls_right:
    LDA player_stair_direction
    EOR #$01
    BEQ stair_controls_down
    BNE stair_controls_up
stair_controls_left:
    LDA player_stair_direction
    BEQ stair_controls_down
stair_controls_up:
    LDA #$80
    BNE stair_controls_endpoint_direction
stair_controls_down:
    LDA #$00
    BEQ stair_controls_endpoint_direction
stair_controls_moving_direction:
    LDA player_speed_y
stair_controls_endpoint_direction:
    EOR stair_best_flags
    BPL stair_controls_fall
stair_controls_valid:
    LDA player_phase
    ORA #STAIR_POSITION_CHECKED
    STA player_phase
    JMP stair_controls_return

stair_controls_fall:
    LDA #STATE_FALL
    STA player_state
    STA $05D8 ; Original falling-state animation timer.
    LDA #$01
    STA player_phase
    LDA #$00
    STA player_speed_x
    STA player_subspeed_x
    STA player_speed_y
    STA player_subspeed_y
    STA player_fraction_x
    STA player_fraction_y
    JMP stair_controls_return

; C=1 means a staircase intersects the player's feet.
; Search slopes independently at staircase crossings.
stair_find_attachment:
    JSR stair_get_player_position
    BCS stair_find_begin
    RTS
stair_find_begin:
    LDA #$00
    STA stair_slope
    LDA player_state
    CMP #STATE_STAIR_IDLE
    BCC stair_find_slope
    LDA player_stair_direction
    LSR A
    ROR A
    ROR A
    STA stair_slope

stair_find_slope:
    LDA #$FF
    STA stair_best_distance
    STA stair_best_distance+1
    LDA #$00
    STA stair_bounds
    LDY #$00

stair_find_endpoint:
    JSR stair_read_record
    LDA stair_endpoint_flags
    CMP #$FF
    BNE stair_find_record
    JMP stair_find_evaluate
stair_find_record:
    AND #$40
    CMP stair_slope
    BEQ stair_find_decode
    JMP stair_find_endpoint

stair_find_decode:
    JSR stair_decode_endpoint
    JSR stair_normalize_upper_endpoint
    SEC
    LDA stair_player_x
    SBC stair_endpoint_x
    STA stair_delta_x
    LDA stair_player_x+1
    SBC stair_endpoint_x+1
    STA stair_delta_x+1

    ; At the player's X, an ascending-right line has Y = endpoint Y - dx.
    LDA stair_slope
    BNE stair_project_left
    SEC
    LDA stair_endpoint_y
    SBC stair_delta_x
    STA stair_projected_y
    LDA stair_endpoint_y+1
    SBC stair_delta_x+1
    JMP stair_project_compare

stair_project_left:
    CLC
    LDA stair_endpoint_y
    ADC stair_delta_x
    STA stair_projected_y
    LDA stair_endpoint_y+1
    ADC stair_delta_x+1

stair_project_compare:
    STA stair_projected_y+1
    SEC
    LDA stair_projected_y
    SBC stair_player_y
    STA stair_correction
    LDA stair_projected_y+1
    SBC stair_player_y+1
    BEQ stair_correction_positive
    CMP #$FF
    BEQ stair_correction_negative
    JMP stair_find_next
stair_correction_negative:
    LDA stair_correction
    CMP #($100 - ATTACH_TOLERANCE)
    BCS stair_find_bound
    ; Falling can cross the whole contact band between two frames.
    LDA player_state
    CMP #STATE_JUMP
    BEQ stair_check_crossing
    CMP #STATE_FALL
    BEQ stair_check_crossing
    JMP stair_find_next
stair_check_crossing:
    JSR stair_relative_fall_speed
    LDA stair_distance+1
    BMI stair_crossing_rejected
    BEQ stair_crossing_rejected
    LDA #$00
    SEC
    SBC stair_correction
    CMP stair_distance+1
    BCC stair_find_bound
    BEQ stair_find_bound
stair_crossing_rejected:
    JMP stair_find_next

stair_correction_positive:
    LDA stair_correction
    CMP #(ATTACH_TOLERANCE + 1)
    BCS stair_find_next

stair_find_bound:
    LDA stair_delta_x
    ORA stair_delta_x+1
    BEQ stair_find_bound_inside
    LDA stair_endpoint_flags
    ASL A
    EOR stair_endpoint_flags
    EOR stair_delta_x+1
    BMI stair_measure_distance
stair_find_bound_inside:
    LDA stair_endpoint_flags
    BMI stair_find_upper_bound
    LDA #$01
    BNE stair_find_save_bound
stair_find_upper_bound:
    LDA #$02
stair_find_save_bound:
    ORA stair_bounds
    STA stair_bounds

stair_measure_distance:
    LDA stair_delta_x
    STA stair_distance
    LDA stair_delta_x+1
    STA stair_distance+1
    BPL stair_compare_distance
    SEC
    LDA #$00
    SBC stair_distance
    STA stair_distance
    LDA #$00
    SBC stair_distance+1
    STA stair_distance+1

stair_compare_distance:
    ; Both paths leave the distance high byte in A.
    CMP stair_best_distance+1
    BCC stair_remember_endpoint
    BNE stair_find_next
    LDA stair_distance
    CMP stair_best_distance
    BCC stair_remember_endpoint
    BNE stair_find_next
    ; At a shared landing, prefer the flight enclosing the player when
    ; its endpoint is as close as the adjacent flight's outside endpoint.
    LDA stair_bounds
    BPL stair_find_next
    LDA stair_endpoint_flags
    ASL A
    EOR stair_endpoint_flags
    EOR stair_delta_x+1
    BMI stair_find_next

stair_remember_endpoint:
    LDA stair_distance
    STA stair_best_distance
    LDA stair_distance+1
    STA stair_best_distance+1
    LDA stair_correction
    STA stair_best_correction
    LDA stair_endpoint_flags
    STA stair_best_flags
    LDA stair_endpoint_flags
    ASL A
    EOR stair_endpoint_flags
    EOR stair_delta_x+1
    AND #$80
    STA stair_distance
    LDA stair_bounds
    AND #$03
    ORA stair_distance
    STA stair_bounds

stair_find_next:
    JMP stair_find_endpoint

stair_find_evaluate:
    LDA stair_best_distance+1
    CMP #$FF
    BEQ stair_find_other_slope
    ORA stair_best_distance
    BEQ stair_find_inside
    ; A lower endpoint points into the ascending half-line, an upper one
    ; into the descending half-line. The nearest collinear endpoint bounds
    ; a flight, including gaps between flights on the same diagonal.
    LDA stair_bounds
    BMI stair_find_other_slope

stair_find_inside:
    ; Native room-edge stair transitions can have a single endpoint.
    LDA player_state
    CMP #STATE_STAIR_IDLE
    BCS stair_find_success
    ; Room-edge flights may have only one endpoint. The nearest endpoint's
    ; inward-facing half-line also bounds those flights and rejects gaps.
    ; An upward catch needs room for the first eight-pixel stair step.
    LDA stair_best_flags
    BPL stair_find_check_grounded
    LDA stair_best_distance+1
    BNE stair_find_check_grounded
    LDA stair_best_distance
    CMP #$08
    BCC stair_find_other_slope
stair_find_check_grounded:
    ; Grounded endpoint entry retains the original alignment animation.
    ; Only idle, walk, jump and fall states reach this search.
    LDA player_state
    CMP #STATE_JUMP
    BCS stair_find_success

    LDA stair_best_distance+1
    BNE stair_find_success
    LDA stair_best_distance
    CMP #$08
    BCC stair_find_other_slope

stair_find_success:
    SEC
    RTS

stair_find_other_slope:
    LDA player_state
    CMP #STATE_STAIR_IDLE
    BCS stair_find_failure
    LDA stair_slope
    BNE stair_find_failure
    LDA #$40
    STA stair_slope
    JMP stair_find_slope

stair_find_failure:
    CLC
    RTS

; Relative downward travel across the diagonal, rounded up to whole pixels.
; Right-rising stairs use vy + vx, left-rising stairs use vy - vx.
stair_relative_fall_speed:
    LDA stair_slope
    BNE stair_relative_fall_left
    CLC
    LDA player_subspeed_y
    ADC player_subspeed_x
    STA stair_distance
    LDA player_speed_y
    ADC player_speed_x
    JMP stair_relative_fall_round
stair_relative_fall_left:
    SEC
    LDA player_subspeed_y
    SBC player_subspeed_x
    STA stair_distance
    LDA player_speed_y
    SBC player_speed_x
stair_relative_fall_round:
    STA stair_distance+1
    LDA stair_distance
    BEQ stair_relative_fall_done
    INC stair_distance+1
stair_relative_fall_done:
    RTS

; Vertical room pages are 240 pixels tall.
stair_get_player_position:
    LDA player_x
    STA stair_player_x
    LDA player_y
    STA stair_player_y
    LDA #$00
    STA stair_player_x+1
    STA stair_player_y+1
    LDA room_metadata
    BMI stair_player_vertical
    CLC
    LDA player_x
    ADC scroll_offset
    STA stair_player_x
    LDA scroll_screen
    ADC #$00
    STA stair_player_x+1
    JMP stair_player_character_offset

stair_player_vertical:
    LDA player_y
    SEC
    SBC #$33
    BCC stair_find_failure
    CLC
    ADC scroll_offset
    STA stair_player_y
    LDA #$00
    ADC #$00
    STA stair_player_y+1
    LDA scroll_screen
    JSR stair_scale_vertical_page
    CLC
    LDA stair_player_y
    ADC stair_endpoint_y
    STA stair_player_y
    LDA stair_player_y+1
    ADC stair_endpoint_y+1
    STA stair_player_y+1

stair_player_character_offset:
    LDA current_character
    CMP #CHAR_GRANT
    BNE stair_player_ready
    ; Grant's shorter sprite places its origin four pixels below the others.
    SEC
    LDA stair_player_y
    SBC #$04
    STA stair_player_y
    LDA stair_player_y+1
    SBC #$00
    STA stair_player_y+1
stair_player_ready:
    SEC
    RTS

; Decode the record fetched by stair_read_record. Y is preserved.
; Horizontal layout = flags|Y/16, X low, X page.
; Vertical layout   = flags|Y page, Y within page, X.
stair_decode_endpoint:
    LDA room_metadata
    BMI stair_decode_vertical
    LDA stair_endpoint_flags
    ASL A
    ASL A
    ASL A
    ASL A
    STA stair_endpoint_y
    LDA #$00
    STA stair_endpoint_y+1
    RTS

stair_decode_vertical:
    LDA stair_endpoint_flags
    AND #$0F
    JSR stair_scale_vertical_page
    CLC
    LDA stair_endpoint_x
    ADC stair_endpoint_y
    STA stair_endpoint_y
    LDA stair_endpoint_y+1
    ADC #$00
    STA stair_endpoint_y+1
    LDA stair_endpoint_x+1
    STA stair_endpoint_x
    LDA #$00
    STA stair_endpoint_x+1
    RTS

; Some vertical-room upper triggers sit one metatile into a wide platform.
; For a consecutive lower/upper pair, project the lower flight to the upper
; trigger's height. Keep the native table unchanged for walking onto stairs.
; Delta/projected-position scratch is free until stair_find_decode resumes.
stair_normalize_upper_endpoint:
    LDA room_metadata
    BMI stair_normalize_check_upper
    RTS
stair_normalize_check_upper:
    LDA stair_endpoint_flags
    BMI stair_normalize_check_record
    RTS
stair_normalize_check_record:
    CPY #$06
    BCS stair_normalize_pair
    RTS
stair_normalize_pair:
    LDA stair_endpoint_x
    STA stair_delta_x
    LDA stair_endpoint_x+1
    STA stair_delta_x+1
    LDA stair_endpoint_y
    STA stair_projected_y
    LDA stair_endpoint_y+1
    STA stair_projected_y+1
    TYA
    PHA
    LDA stair_endpoint_flags
    PHA
    TYA
    SEC
    SBC #$06
    TAY
    JSR stair_read_record
    JSR stair_decode_endpoint
    LDX stair_endpoint_flags
    PLA
    STA stair_endpoint_flags
    TXA
    EOR stair_endpoint_flags
    AND #$C0
    CMP #$80
    BNE stair_normalize_restore
    SEC
    LDA stair_endpoint_y
    SBC stair_projected_y
    STA stair_distance
    LDA stair_endpoint_y+1
    SBC stair_projected_y+1
    BNE stair_normalize_restore
    LDA stair_distance
    BEQ stair_normalize_restore
    LDA stair_endpoint_flags
    AND #$40
    BNE stair_normalize_left
    CLC
    LDA stair_endpoint_x
    ADC stair_distance
    BCS stair_normalize_restore
    JMP stair_normalize_compare
stair_normalize_left:
    SEC
    LDA stair_endpoint_x
    SBC stair_distance
    BCC stair_normalize_restore
stair_normalize_compare:
    STA stair_distance
    SEC
    SBC stair_delta_x
    BCS stair_normalize_distance
    EOR #$FF
    CLC
    ADC #$01
stair_normalize_distance:
    CMP #$20
    BNE stair_normalize_restore
    LDA stair_distance
    STA stair_delta_x
stair_normalize_restore:
    LDA stair_delta_x
    STA stair_endpoint_x
    LDA stair_delta_x+1
    STA stair_endpoint_x+1
    LDA stair_projected_y
    STA stair_endpoint_y
    LDA stair_projected_y+1
    STA stair_endpoint_y+1
    PLA
    TAY
stair_normalize_done:
    RTS

; A = page, endpoint Y = page * 240 = page * 256 - page * 16.
; Page values fit in a nibble. X is temporary, Y is preserved.
stair_scale_vertical_page:
    TAX
    ASL A
    ASL A
    ASL A
    ASL A
    STA stair_endpoint_y
    SEC
    LDA #$00
    SBC stair_endpoint_y
    STA stair_endpoint_y
    TXA
    SBC #$00
    STA stair_endpoint_y+1
    RTS

; Prepare the player, then request ascent in the restored player bank.
stair_attach:
    CLC
    LDA player_y
    ADC stair_best_correction
    STA player_y
    ; Match the eight-pixel step lattice used by the original stair handler.
    ; Move X and Y together to remain on the selected 45-degree flight.
    LDA stair_player_x
    AND #$07
    STA stair_distance
    SEC
    LDA player_x
    SBC stair_distance
    STA player_x
    LDA stair_best_flags
    AND #$40
    BNE stair_attach_left
    CLC
    LDA player_y
    ADC stair_distance
    JMP stair_attach_y

stair_attach_left:
    SEC
    LDA player_y
    SBC stair_distance

stair_attach_y:
    STA player_y
    LDA stair_best_flags
    ASL A
    ASL A
    ROL A
    AND #$01
    STA player_stair_direction
    LDA #$00
    STA player_fraction_x
    STA player_fraction_y
    STA player_stair_alignment
    LDA #$01
    STA player_phase
    SEC
    RTS

IF $ > $C000
    ERROR "Stair controls exceed the $B680-$BFFF bank-$19 padding"
ENDIF
ENDCOMPARE
