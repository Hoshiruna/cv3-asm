; SPDX-License-Identifier: MIT
; Assemble from the project root with nstbayless/asm6f (INCNES and SEEKABS).

; Define DEBUG_MENU_APPEND when including after another patch's ROM load.
IFNDEF DEBUG_MENU_APPEND
    INCNES "Castlevania III - Dracula's Curse (USA).nes"
    CLEARPATCH
ENDIF

; Castlevania III (USA), MMC5, Ricoh 2A03.
; 1 opens the native debug menu when starting a new game, 0 disables this patch.
DEBUG_MENU_ENABLED = 1

GAME_STATE_DEBUG   = $07
set_game_state     = $E574 ; Store A in $18 and clear the menu substate at $19.

; Native debug-menu code, already present in the US ROM
;   $E390         State-$07 dispatch-table word, pointing to $E543.
;   $E543-$E54A   Map PRG pair $00/$01, then JMP $8A1C.
;   $8A1C-$8A61   Initialize the menu and draw its four values.
;   $8A62-$8ADD   Start/Select/A/B handling.
;   $8AE0-$8B03   Start the selected room in gameplay state $04.
;   $8B1A-$8B54   Number and cursor drawing shared with other menus.
; Addresses $8xxx above belong to PRG bank $00.
;
; The rows edit stage $32, block $33, room $34 and character $054E.
; Select advances the cursor, A increases, B decreases, Start begins gameplay.

IF DEBUG_MENU_ENABLED = 1
    ; New-game state $03 has completed its RAM, player and level setup here.
    ; Replace JMP $E56D, which normally advances the game state to $04.
    SEEKABS $03E471
    BASE $E461
    COMPARE
    FILLVALUE $4C
    DB $4C
    FILLVALUE $6D
    DB $6D
    FILLVALUE $E5
    DB $E5
    ENDCOMPARE
    SKIPREL -3
    JMP debug_menu_start

    ; $E782 maps PRG pair $00/$01 during new-game initialization.
    ; The following $E68F call restores that pair before reaching the hook.
    FILLVALUE $FF
    COMPARE
    SEEKABS $003EC8
    BASE $BEB8

debug_menu_start:
    LDA #GAME_STATE_DEBUG
    JMP set_game_state

    IF $ > $C000
        ERROR "Debug menu entry exceeds the $BEB8-$BFFF bank-$01 padding"
    ENDIF
    ENDCOMPARE
ENDIF
