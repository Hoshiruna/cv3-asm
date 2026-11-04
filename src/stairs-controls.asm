; SPDX-License-Identifier: MIT
; Original implementation using the game's room endpoints and state handlers.

; $C800 is the final byte of DPCM sound $75. Leave it intact.
SEEKABS $03C820
BASE $C810

stair_controls_tick:
    PHP
    PHA
    TXA
    PHA
    JSR stair_controls_update
    PLA
    TAX
    PLA
    PLP
    ; Reproduce the displaced LDY, including the flags used by BEQ $8AA2.
    LDY current_character
    RTS

stair_controls_update:
    LDA game_state
    CMP #$04
    BEQ stair_controls_check_cinematic
    RTS
stair_controls_check_cinematic:
    LDA cinematic_controller
    BEQ stair_controls_check_substate
    RTS
stair_controls_check_substate:
    LDA gameplay_substate
    CMP #$03
    BEQ stair_controls_gameplay
    CMP #$05
    BEQ stair_controls_gameplay
    CMP #$0A
    BEQ stair_controls_gameplay
    RTS

stair_controls_gameplay:
    LDA player_state
    CMP #STATE_APPROACH_STAIRS
    BEQ stair_controls_on_stairs
    CMP #STATE_ENTER_STAIRS
    BEQ stair_controls_on_stairs
    CMP #STATE_STAIR_IDLE
    BEQ stair_controls_on_stairs
    CMP #STATE_STAIR_MOVE
    BEQ stair_controls_on_stairs

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
    LDA player_speed_y
    BMI stair_controls_return

stair_controls_find:
    LDA lower_prg_bank
    PHA
    LDA #STAIRS_PRG_BANK
    JSR set_lower_prg_bank
    JSR stair_find_attachment
    ; Restore the caller's bank while retaining the search carry in X.
    PHP
    PLA
    TAX
    PLA
    JSR set_lower_prg_bank
    TXA
    PHA
    PLP
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
    RTS

IF $ > $C900
    ERROR "Stair input hook exceeds the $C810-$C8FF padding"
ENDIF

SEEKABS $03DC28
BASE $DC18

; C=1 means a staircase intersects the player's feet.
; Search slopes independently at staircase crossings.
stair_find_attachment:
    JSR stair_get_player_position
    BCS stair_find_begin
    RTS
stair_find_begin:
    LDA #$00
    STA stair_slope

stair_find_slope:
    LDA #$FF
    STA stair_best_distance
    STA stair_best_distance+1
    LDY #$00

stair_find_endpoint:
    LDA (room_stairs),Y
    CMP #$FF
    BNE stair_find_record
    JMP stair_find_evaluate
stair_find_record:
    STA stair_endpoint_flags
    AND #$40
    CMP stair_slope
    BEQ stair_find_decode
    INY
    INY
    INY
    JMP stair_find_endpoint

stair_find_decode:
    JSR stair_decode_endpoint
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
    BNE stair_find_next
    LDA stair_correction
    CMP #($100 - ATTACH_TOLERANCE)
    BCC stair_find_next
    BCS stair_measure_distance

stair_correction_positive:
    LDA stair_correction
    CMP #(ATTACH_TOLERANCE + 1)
    BCS stair_find_next

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
    LDA stair_distance+1
    CMP stair_best_distance+1
    BCC stair_remember_endpoint
    BNE stair_find_next
    LDA stair_distance
    CMP stair_best_distance
    BCS stair_find_next

stair_remember_endpoint:
    LDA stair_distance
    STA stair_best_distance
    LDA stair_distance+1
    STA stair_best_distance+1
    LDA stair_correction
    STA stair_best_correction
    LDA stair_endpoint_flags
    STA stair_best_flags
    LDA stair_delta_x+1
    STA stair_best_side

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
    LDA stair_best_flags
    ASL A
    EOR stair_best_flags
    EOR stair_best_side
    BMI stair_find_other_slope

stair_find_inside:
    ; Grounded endpoint entry retains the original alignment animation.
    LDA player_state
    CMP #STATE_IDLE
    BEQ stair_find_ground_endpoint
    CMP #STATE_WALK
    BNE stair_find_success

stair_find_ground_endpoint:
    LDA stair_best_distance+1
    BNE stair_find_success
    LDA stair_best_distance
    CMP #$08
    BCC stair_find_other_slope

stair_find_success:
    SEC
    RTS

stair_find_other_slope:
    LDA stair_slope
    BNE stair_find_failure
    LDA #$40
    STA stair_slope
    JMP stair_find_slope

stair_find_failure:
    CLC
    RTS

; Coordinates follow bank0f.s. Vertical room pages are 240 pixels tall.
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
    ; Grant's standing/climbing origin is four pixels above the others.
    CLC
    LDA stair_player_y
    ADC #$04
    STA stair_player_y
    LDA stair_player_y+1
    ADC #$00
    STA stair_player_y+1
stair_player_ready:
    SEC
    RTS

; Decode one 3-byte record. Y leaves pointing at the following record.
; Horizontal layout = flags|Y/16, X low, X page.
; Vertical layout   = flags|Y page, Y within page, X.
stair_decode_endpoint:
    INY
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
    LDA (room_stairs),Y
    STA stair_endpoint_x
    INY
    LDA (room_stairs),Y
    STA stair_endpoint_x+1
    INY
    RTS

stair_decode_vertical:
    LDA stair_endpoint_flags
    AND #$0F
    JSR stair_scale_vertical_page
    CLC
    LDA (room_stairs),Y
    ADC stair_endpoint_y
    STA stair_endpoint_y
    LDA stair_endpoint_y+1
    ADC #$00
    STA stair_endpoint_y+1
    INY
    LDA (room_stairs),Y
    STA stair_endpoint_x
    LDA #$00
    STA stair_endpoint_x+1
    INY
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

; The player bank has been restored before this routine is called.
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
    JMP start_stair_ascent

IF $ > $E000
    ERROR "Stair geometry exceeds the $DC18-$DFFF padding"
ENDIF
