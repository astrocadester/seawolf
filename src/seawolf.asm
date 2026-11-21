;*******************************************************************************
; SEA WOLF (1976)
;*******************************************************************************
; Submarine arcade game for Midway Intel 8080 hardware.
;
; Developer : Dave Nutting Associates (DNA)
; Publisher : Midway Manufacturing
; CPU       : Intel 8080
; Software  : Native game routines and indexed command interpreter
;
; ROM       : sw0041.h / sw0042.g / sw0043.f / sw0044.e
; Build     : bundled zmac v1.3; four original 1 KB ROM devices
; Reference : roms/original/seawolf.zip
;
; Original ROM bytes are authoritative. Indexed command streams, bitmap
; characters, graphic frames and descriptor tables remain ROM data.
;*******************************************************************************

PRGPTR EQU $2000
GTIME EQU $2002
CREDIT EQU $2005
PSCORE EQU $202B
INTERPRETER_DISPATCH EQU $045E
SCRIPT_VECTOR_TABLE EQU $09E8
VIDEO_RAM EQU $2400
SHIP_TABLE EQU $0F7E

        ORG $0000

; ROM device sw0041.h — SHA-1 b538277d3a633dd8a3179cff202f18d322e6fe17

; Reset entry and 8080 stack setup.
RESET_ENTRY:
        NOP
        NOP
        LD sp,$2400
        JP STARTUP_INITIALIZE

; Interrupt vector: save registers and enter object update.
IRQ_VECTOR_08:
        PUSH hl
        PUSH de
        PUSH bc
        PUSH af
        JP IRQ_OBJECT_UPDATE
        NOP

; Interrupt vector: save registers and choose update phase.
IRQ_VECTOR_10:
        PUSH hl
        PUSH de
        PUSH bc
        PUSH af
        LD a,($201F)
        AND a
        JP nz,L003E
        CALL UPDATE_WAVE_PATTERN
        CALL $012E
        LD hl,($2016)
        LD a,(hl)
        AND a
        JP p,L0036
        AND $20
        JP z,L0036
        CALL LOAD_OBJECT_DRAW_PARAMETERS
        DEC c
        EX de,hl
        CALL COPY_GRAPHIC_BLOCK
L0036:
        LD a,$FF
L0038:
        LD ($201F),a
        JP IRQ_INPUT_AND_RETURN
L003E:
        LD hl,($2016)
        LD a,(hl)
        AND a
        JP p,L0062
        AND $40
        JP nz,L0050
        LD (hl),$00
        JP L0062
L0050:
        LD a,(hl)
        OR $20
        LD (hl),a
        CALL $0165
        LD a,b
        PUSH hl
        LD hl,($201C)
        LD b,h
        LD c,l
        POP hl
        CALL COPY_OBJECT_BYTES
L0062:
        CALL UPDATE_FRAME_TIMERS
        XOR a
        LD ($201F),a

; Sample input port and restore interrupt context.
IRQ_INPUT_AND_RETURN:
        IN a,($02)
        LD b,a
        IN a,($02)
        LD hl,$2007
        LD de,$09CA
        CP b
        CALL z,HANDLE_INPUT_CHANGE
        POP af
        POP bc
        POP de
        POP hl
        EI
        RET

; Update RAM-backed object descriptors during interrupt processing.
IRQ_OBJECT_UPDATE:
        LD a,($201F)
        AND a
        JP nz,$0119
        CALL UPDATE_WAVE_PATTERN
        LD hl,$215F
        LD b,$44
        XOR a
L008E:
        LD (hl),a
        INC hl
        DEC b
        JP nz,L008E
        LD hl,($2018)
        LD a,$03
L0099:
        PUSH af
        LD a,l
        CP $58
        JP nz,L00A3
L00A0:
        LD hl,$2031
L00A3:
        OR h
        JP z,L00A0
        PUSH hl
        CALL $01DE
        POP hl
        JP nc,L00B2
        LD ($2018),hl
L00B2:
        LD de,$000D
        ADD hl,de
        POP af
        DEC a
        JP nz,L0099
        LD hl,($2018)
        CALL CLEAR_ACTIVE_OBJECT
        LD hl,($201A)
        LD a,$03
L00C6:
        PUSH af
        LD a,l
        CP $7F
        JP nz,L00D0
L00CD:
        LD hl,$2058
L00D0:
        OR h
        JP z,L00CD
        PUSH hl
        CALL $01DE
        POP hl
        JP nc,L00DF
        LD ($201A),hl
L00DF:
        LD de,$000D
        ADD hl,de
        POP af
        DEC a
        JP nz,L00C6
        XOR a
        LD ($2030),a
        LD hl,($2016)
        LD a,$04
L00F1:
        PUSH af
        LD a,l
        CP $5F
        JP nz,L00FB
L00F8:
        LD hl,$20E7
L00FB:
        OR h
        JP z,L00F8
        PUSH hl
        CALL UPDATE_PROJECTILE_DESCRIPTOR
        POP hl
        JP nc,L010A
        LD ($2016),hl
L010A:
        LD de,$001E
        ADD hl,de
        POP af
        DEC a
        JP nz,L00F1
        CALL ADVANCE_OBJECT_CURSOR
        JP IRQ_INPUT_AND_RETURN

; -----------------------------------------------------------------------------
; IRQ_OBJECT_DRAW (IRQ_OBJECT_DRAW:19) - Draw active ship objects
; -----------------------------------------------------------------------------
IRQ_OBJECT_DRAW:
        LD hl,($201A)
        CALL CLEAR_ACTIVE_OBJECT
        LD hl,($201A)
        CALL $013A
        LD hl,($2018)
        CALL $013A
        JP IRQ_INPUT_AND_RETURN

; -----------------------------------------------------------------------------
; UPDATE_SELECTED_OBJECT (UPDATE_SELECTED_OBJECT:2E) - Update the selected active object
; -----------------------------------------------------------------------------
UPDATE_SELECTED_OBJECT:
        LD hl,($2014)
        LD a,(hl)
        AND a
        RET p
        CALL $0165
        JP $0192

; -----------------------------------------------------------------------------
; UPDATE_SHIP_OBJECT (UPDATE_SHIP_OBJECT:3A) - Process a ship-object state field
; -----------------------------------------------------------------------------
UPDATE_SHIP_OBJECT:
        LD a,(hl)
        AND a
        RET p
        AND $40
        JP nz,L0145
        LD (hl),$00
        RET
L0145:
        LD a,(hl)
        OR $20
        LD (hl),a
        PUSH af
        CALL $0165
        POP af
        AND $10
        JP z,$0192
        LD a,c
        ADD a,l
        LD l,a
        PUSH hl
        LD hl,$2030
        LD a,(hl)
        CPL
        AND $07
        LD (hl),a
        POP hl
        OUT ($04),a
        JP $01B8

; -----------------------------------------------------------------------------
; PREPARE_SPRITE_COPY (PREPARE_SPRITE_COPY:65) - Read the object's graphic source and destination parameters
; -----------------------------------------------------------------------------
PREPARE_SPRITE_COPY:
        INC hl
        INC hl
        LD e,(hl)
        INC hl
        INC hl
        INC hl
        LD d,(hl)
        INC hl
        INC hl
        CALL BIT_SHIFT_SETUP
        LD a,c
        LD ($2030),a
        OUT ($04),a
        PUSH de
        LD e,(hl)
        INC hl
        LD d,(hl)
        INC hl
        EX de,hl
        LD c,(hl)
        INC hl
        LD b,(hl)
        INC hl
        EX (sp),hl
        EX de,hl
        LD (hl),e
        INC hl
        LD (hl),d
        INC hl
        LD (hl),c
        INC (hl)
        INC hl
        LD (hl),b
        INC hl
        LD ($201C),hl
        EX de,hl
        POP de
        RET

; -----------------------------------------------------------------------------
; DRAW_SPRITE_NORMAL (DRAW_SPRITE_NORMAL:92) - Copy sprite bytes through the shifter path
; -----------------------------------------------------------------------------
DRAW_SPRITE_NORMAL:
        PUSH bc
        PUSH hl
L0194:
        LD a,(de)
        INC de
        OUT ($03),a
        IN a,($03)
        LD (hl),a
        INC hl
        DEC c
        JP nz,L0194
        XOR a
        OUT ($03),a
        IN a,($03)
        LD (hl),a
        LD bc,$0020
        POP hl
        ADD hl,bc
        POP bc
        LD a,l
        AND $E0
        JP nz,$0192
        LD a,h
        RRA
        JP c,$0192
        RET

; -----------------------------------------------------------------------------
; DRAW_SPRITE_SHIFTED (DRAW_SPRITE_SHIFTED:B8) - Copy sprite bytes through the alternate shifted path
; -----------------------------------------------------------------------------
DRAW_SPRITE_SHIFTED:
        PUSH bc
        PUSH hl
L01BA:
        LD a,(de)
        INC de
        OUT ($03),a
        IN a,($00)
        LD (hl),a
        DEC hl
        DEC c
        JP nz,L01BA
        XOR a
        OUT ($03),a
        IN a,($00)
        LD (hl),a
        LD bc,$0020
        POP hl
        ADD hl,bc
        POP bc
        LD a,l
        AND $E0
        JP nz,$01B8
        LD a,h
        RRA
        JP c,$01B8
        RET

; -----------------------------------------------------------------------------
; UPDATE_SHIP_DESCRIPTOR (UPDATE_SHIP_DESCRIPTOR:DE) - Advance and test ship descriptor
; -----------------------------------------------------------------------------
UPDATE_SHIP_DESCRIPTOR:
        LD a,(hl)
        AND a
        RET p
        PUSH hl
        INC hl
        AND $07
        JP nz,L01ED
        INC hl
        INC hl
        JP L0237
L01ED:
        LD a,(hl)
        LD de,$215F
        AND a
        JP p,L01F8
        LD de,$2181
L01F8:
        LD b,a
        INC hl
        ADD a,(hl)
        LD (hl),a
        LD a,b
        AND a
        LD a,(hl)
        JP p,L0210
        CP $01
        JP nc,L0216
L0207:
        EX (sp),hl
        LD a,(hl)
        AND $BF
        LD (hl),a
        EX (sp),hl
        JP L0216
L0210:
        INC hl
        CP (hl)
        DEC hl
        JP nc,L0207
L0216:
        LD a,(hl)
        RRCA
        RRCA
        RRCA
        AND $1F
        ADD a,e
        LD e,a
        EX (sp),hl
        LD a,(hl)
        EX (sp),hl
        AND $07
        LD b,a
        INC hl
        LD a,(hl)
        CPL
        INC a
        RRCA
        RRCA
        RRCA
        AND $07
        ADD a,$03
        EX de,hl
L0230:
        LD (hl),b
        INC hl
        DEC a
        JP nz,L0230
        EX de,hl
L0237:
        LD de,$202F
        LD a,(de)
        CPL
        LD (de),a
        JP nz,L0247
        INC hl
        LD a,(hl)
        INC hl
        ADD a,(hl)
        LD (hl),a
        INC hl
        CP (hl)
L0247:
        POP hl
        SCF
        RET nz
        LD a,(hl)
        AND $BF
        LD (hl),a
        SCF
        RET

; Advance and test torpedo or mine descriptor.
UPDATE_PROJECTILE_DESCRIPTOR:
        LD a,(hl)
        AND a
        RET p
        PUSH hl
        INC hl
        INC hl
        LD c,(hl)
        INC hl
        INC hl
        LD a,(hl)
        INC hl
        LD b,(hl)
        ADD a,b
        LD (hl),a
        LD a,b
        CP $C0
        JP nc,L0309
        CP $30
        JP nc,L0275
        LD a,($2024)
        AND a
        JP z,L0275
        INC a
        INC a
        LD ($2024),a
L0275:
        LD a,(hl)
        INC hl
        CP (hl)
        JP nc,L029C
        LD a,$C0
        ADD a,(hl)
        LD (hl),a
        DEC hl
        DEC hl
        INC (hl)
        INC (hl)
        LD a,(hl)
        INC hl
        INC hl
        INC hl
        JP z,L0296
        LD (hl),$88
        CP $FC
        JP z,L029C
        LD (hl),$98
        JP L029C
L0296:
        EX (sp),hl
        LD a,(hl)
        AND $BF
        LD (hl),a
        EX (sp),hl
L029C:
        LD de,$2030
        LD a,(de)
        AND a
        JP nz,L0309
        INC a
        LD (de),a
        LD a,b
        AND $10
        JP z,L0309
        LD de,$0007
        ADD hl,de
        LD a,(hl)
        AND a
        JP nz,L02C3
        ADD hl,de
        LD a,b
        ADD a,e
        LD b,a
        AND $10
        JP z,L0309
        LD a,(hl)
        AND a
        JP z,L0309
L02C3:
        EX (sp),hl
        LD a,(hl)
        AND $BF
        LD (hl),a
        EX (sp),hl
        LD a,b
        SUB $40
        LD b,a
        JP c,L02E0
        LD hl,$21A1
L02D3:
        INC hl
        INC hl
        LD a,(hl)
        AND a
        JP nz,L02D3
        LD (hl),b
        INC hl
        LD (hl),c
        JP L0309
L02E0:
        LD hl,$21BE
L02E3:
        INC hl
        INC hl
        INC hl
        LD a,(hl)
        AND a
        JP nz,L02E3
        LD a,b
        ADD a,$20
        LD de,$2160
        JP m,L02F7
        LD de,$2182
L02F7:
        LD a,c
        RRCA
        RRCA
        RRCA
        AND $1F
        ADD a,e
        LD e,a
        LD a,(de)
        AND a
        JP z,L0309
        LD (hl),a
        INC hl
        LD (hl),c
        INC hl
        LD (hl),b
L0309:
        SCF
        POP hl
        RET

; Clear active-object display state.
CLEAR_ACTIVE_OBJECT:
        LD a,(hl)
        AND a
        RET p
        AND $20
        RET z
        CALL LOAD_OBJECT_DRAW_PARAMETERS
        EX de,hl
        LD b,c
L0317:
        XOR a
        PUSH hl
L0319:
        LD (hl),a
        INC hl
        DEC c
        JP nz,L0319
        LD de,$0020
        POP hl
        ADD hl,de
        LD c,b
        LD a,l
        AND $E0
        JP nz,L0317
        LD a,h
        RRA
        JP c,L0317
        RET

; Select the next active object descriptor.
ADVANCE_OBJECT_CURSOR:
        LD hl,($2014)
        LD b,$0A
        LD a,l
        OR h
        JP nz,L033E
        LD hl,$2072
L033E:
        LD de,$000D
L0341:
        ADD hl,de
        DEC b
        RET z
        LD a,l
        CP $E7
        JP nz,L034D
        LD hl,$207F
L034D:
        LD a,(hl)
        AND a
        JP p,L0341
        LD ($2014),hl
        INC hl
        LD a,(hl)
        INC hl
        ADD a,(hl)
        LD (hl),a
        RET

; Load drawing parameters from an object record.
LOAD_OBJECT_DRAW_PARAMETERS:
        LD de,$0009
        ADD hl,de
        LD e,(hl)
        INC hl
        LD d,(hl)
        INC hl
        LD c,(hl)
        INC hl
        LD b,(hl)
        INC hl
        RET

; Update frame-related countdown state.
UPDATE_FRAME_TIMERS:
        LD a,($2020)
        AND a
        RET nz
        LD b,a
        LD hl,$2003
        DEC (hl)
        JP nz,L038E
        LD (hl),$1E
        LD hl,$2002
        LD a,(hl)
        AND a
        JP z,L0388
        ADD a,$99
        DAA
        LD (hl),a
        JP nz,L0388
        LD b,$01
L0388:
        LD hl,$2010
        CALL DECREMENT_TIMER_IF_ACTIVE
L038E:
        LD hl,$2011
        CALL DECREMENT_TIMER_IF_ACTIVE
        LD hl,$2021
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC hl
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC hl
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC hl
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC hl
        CALL DECREMENT_TIMER_IF_ACTIVE
        LD ($2020),a
        RET

; Decrement a nonzero countdown byte.
DECREMENT_TIMER_IF_ACTIVE:
        LD a,(hl)
        AND a
        JP z,L03B8
        DEC (hl)
        JP nz,L03B8
        SCF
L03B8:
        LD a,b
        RLA
        LD b,a
        RET

; Update wave/display pattern state.
UPDATE_WAVE_PATTERN:
        LD bc,$2027
        LD a,(bc)
        ADD a,$0A
        CP $1E
        JP nz,L03C8
        XOR a
L03C8:
        LD (bc),a
        INC bc
        LD e,a
        LD d,$00
        LD hl,$0BF3
        ADD hl,de
        EX de,hl
        LD a,(bc)
        INC a
        AND $1F
        LD (bc),a
        LD hl,$27E0
        ADD a,l
        LD l,a
        LD bc,$0020
L03DF:
        LD a,(de)
        INC de
        LD (hl),a
        ADD hl,bc
        LD a,l
        AND $E0
        CP $60
        JP nz,L03DF
        RET

; Convert numeric state for display.
CONVERT_DISPLAY_DIGITS:
        LD hl,$0000
        LD de,$0000
        LD c,$02
L03F4:
        XOR a
L03F5:
        ADD a,(hl)
        INC hl
        LD b,a
        LD a,c
        CP h
        LD a,b
        JP nz,L03F5
        PUSH hl
        LD hl,$0429
        ADD hl,de
        CP (hl)
        LD a,$40
        JP z,L040E
        LD hl,$0432
        ADD hl,de
        LD a,(hl)
L040E:
        LD hl,$21E9
        ADD hl,de
        LD (hl),a
        POP hl
        INC de
        INC c
        INC c
        LD a,$12
        CP c
        JP nz,L03F4
        LD hl,$21E9
        LD de,$3008
        LD a,$08
        CALL RENDER_GAME_TEXT
        HALT

; Startup data/constants adjacent to native initialization.
STARTUP_BYTE_TABLE:
        DB $8D,$79,$00,$1F,$58,$6D,$EA,$C5,$2A,$48,$48,$47
        DB $47,$46,$46,$45,$45
; Initialize hardware and RAM before the game loop.
STARTUP_INITIALIZE:
        CALL INITIALIZE_GAME_STATE
        IN a,($02)
        AND $E0
        CP $E0
        CALL z,CONVERT_DISPLAY_DIGITS
        LD hl,$2002
        LD a,$09
        LD b,$00
L044D:
        LD (hl),b
        INC hl
        DEC a
        JP nz,L044D
        LD hl,$0929
        LD ($2000),hl
        EI
        LD hl,$0459
        PUSH hl

; The 8080 command interpreter reads RAM $2000 and dispatches indexed words.

; Fetch indexed game command; zero uses frame-control path.
GAME_COMMAND_DISPATCH:
        LD hl,($2000)
        LD a,(hl)
        AND a
        JP nz,GAME_COMMAND_INDEX
        CALL CLEAR_OBJECT_RECORD
        CALL L04CE
        CALL L04BF
        LD a,($2002)
        AND a
        RET z
        CALL L074C
        CALL POLL_PLAYER_INPUT
        JP GAME_TIME_SERVICE

; Index the 16-bit native handler-address table.
GAME_COMMAND_INDEX:
        INC hl
        EX de,hl
        LD hl,$09E8
        RLCA
        LD c,a
        LD b,$00
        ADD hl,bc
        LD a,(hl)
        INC hl
        LD h,(hl)
        LD l,a
        JP (hl)

; Game-time service and threshold test.
GAME_TIME_SERVICE:
        LD a,($2003)
        CP $1D
        RET m
        LD bc,$2002
        LD de,$21E9
        CALL L0A82
        EX de,hl
        CALL TEST_OBJECT_FLAGS
        INC hl
        LD (hl),$2C
        INC hl
        EX de,hl
        LD bc,$202B
        CALL L0A82
        EX de,hl
        CALL TEST_OBJECT_FLAGS
        INC hl
        LD (hl),$30
        INC hl
        LD (hl),$30
        LD hl,$21E9
        LD de,$3E2F
        LD a,$06
        JP RENDER_GAME_TEXT
L04BF:
        LD hl,$202A
        LD a,(hl)
        AND a
        RET z
        LD (hl),$00
        LD hl,$09A6
        LD ($2000),hl
        RET
L04CE:
        LD hl,$2020
        LD a,(hl)
        AND a
        RET z
        LD (hl),$00
        RRA
        CALL c,RESET_SOUND_OUTPUTS
        RRA
        CALL c,PROCESS_ACTIVE_GRAPHICS
        RRA
        CALL c,L04F7
        RRA
        CALL c,UPDATE_GAME_SOUND
        RRA
        CALL c,L05E9
        RRA
        CALL c,ADVANCE_GAME_SCRIPT_CURSOR
        RRA
        CALL c,SELECT_FOLLOWUP_GAME_SCRIPT
        RRA
        CALL c,L0511
        RET
L04F7:
        PUSH af
        LD hl,$2026
        LD a,(hl)
        AND a
        JP z,L050F
        DEC (hl)
        LD a,$04
        OUT ($05),a
        LD a,$19
        LD ($2023),a
        LD a,$0F
        LD ($2025),a
L050F:
        POP af
        RET
L0511:
        LD hl,$202E
        LD a,(hl)
        AND a
        JP nz,L053D
        LD (hl),$01
        LD a,($2007)
        RRCA
        AND $70
        JP z,L053D
        ADD a,$09
        LD hl,$202B
        CP (hl)
        JP nc,L053D
        LD a,$20
        LD ($2002),a
        LD hl,$0F33
        LD de,$3C03
        LD a,$0C
        JP RENDER_GAME_TEXT
L053D:
        LD hl,$20C9
        LD bc,$001E
L0543:
        ADD hl,bc
        LD a,l
        CP $5F
        JP z,SELECT_INITIAL_GAME_SCRIPT
        LD a,(hl)
        AND a
        JP p,L0543
        XOR a
        LD ($2021),a
        LD ($202D),a
        LD a,$01
        LD ($2002),a
        RET

; Point the game-program cursor at the initial script.
SELECT_INITIAL_GAME_SCRIPT:
        LD hl,$0929
        LD ($2000),hl
        LD a,($202B)
        LD hl,$2006
        CP (hl)
        RET c
        LD (hl),a
        RET

; Select follow-up interpreted command stream.
SELECT_FOLLOWUP_GAME_SCRIPT:
        LD hl,$0963
        LD ($2000),hl
        RET

; Advance game-program cursor by one byte.
ADVANCE_GAME_SCRIPT_CURSOR:
        LD hl,($2000)
        INC hl
        LD ($2000),hl
        RET
        RET z
        LD a,($2002)
        AND a
        RET z
        LD a,($2021)
        AND a
        RET nz
        LD hl,$202D
        LD a,(hl)
        AND $1F
        RET z
        LD a,(hl)
        AND $0F
        RRA
        LD b,$20
        AND a
        JP z,L0599
        LD b,$10
L0599:
        OR b
        LD (hl),a
        OUT ($02),a
        LD hl,$2021
        LD (hl),$08
        AND $10
        JP nz,L05A9
        LD (hl),$3C
L05A9:
        LD a,$02
        OUT ($05),a
        LD a,$0F
        LD ($2025),a
        LD hl,$20C9
        LD de,$001E
L05B8:
        ADD hl,de
        LD a,(hl)
        AND a
        JP m,L05B8
        LD de,$0008
        ADD hl,de
        LD (hl),$0E
        DEC hl
        LD (hl),$75
        DEC hl
        LD (hl),$9C
        DEC hl
        LD (hl),$E0
        DEC hl
        LD (hl),$FA
        DEC hl
        DEC hl
        LD de,$0F5E
        EX de,hl
        LD a,($2008)
        AND $1F
        LD c,a
        LD b,$00
        ADD hl,bc
        LD a,(hl)
        EX de,hl
        LD (hl),a
        DEC hl
        LD (hl),$00
        DEC hl
        LD (hl),$C0
        RET
L05E9:
        PUSH af
        LD hl,$202D
        LD a,(hl)
        AND $10
        JP nz,L05FF
        LD a,$1F
        OUT ($02),a
        LD (hl),a
        LD a,$08
        OUT ($05),a
        CALL UPDATE_SCORE_DIFFICULTY
L05FF:
        POP af
        RET

; Clear discrete sound output ports.
RESET_SOUND_OUTPUTS:
        PUSH af
        XOR a
        OUT ($05),a
        OUT ($01),a
        LD a,($202D)
        OUT ($02),a
        POP af
        RET

; Scan active graphic records.
PROCESS_ACTIVE_GRAPHICS:
        PUSH af
        LD hl,$21F0
L0612:
        LD a,(hl)
        AND a
        JP z,L0632
        LD (hl),$00
        INC hl
        LD d,a
        LD e,(hl)
        LD (hl),$00
        INC hl
        CP $2C
        LD bc,$0A03
        JP c,L062A
        LD bc,$2005
L062A:
        EX de,hl
        CALL CLEAR_GRAPHIC_BLOCK
        EX de,hl
        JP L0612
L0632:
        POP af
        RET

; Update discrete sound settings.
UPDATE_GAME_SOUND:
        PUSH af
        LD a,($2003)
        AND $0F
        OR $50
        LD ($2022),a
        LD bc,$2029
        LD a,(bc)
        INC a
        CP $07
        JP nz,L064A
        XOR a
L064A:
        LD (bc),a
        LD hl,$0FDE
        ADD a,l
        LD l,a
        LD a,(hl)
        LD b,a
        CP $06
        JP nz,SELECT_OBJECT_RECORD
        LD a,$04
        OUT ($05),a
        LD a,$19
        LD ($2023),a
        LD a,$02
        LD ($2026),a
        LD a,$0F
        LD ($2025),a
        LD a,b

; Select one object record using a fixed stride.
SELECT_OBJECT_RECORD:
        LD hl,$202C
        LD de,$000D
L0671:
        ADD hl,de
        DEC a
        JP nz,L0671
        LD a,b
        EX de,hl
        LD hl,$201E
        LD a,(hl)
        INC (hl)
        LD hl,$0F7E
        RRA
        JP nc,L068B
        LD hl,$0FAE
        LD a,b
        OR $10
        LD b,a
L068B:
        LD a,b
        DEC a
        RLCA
        RLCA
        RLCA
        AND $38
        ADD a,l
        LD l,a
        LD c,$08

; Copy bytes into an object record.
COPY_OBJECT_RECORD:
        LD a,(hl)
        INC hl
        LD (de),a
        DEC de
        DEC c
        JP nz,COPY_OBJECT_RECORD
        LD a,b
        OR $C0
        LD (de),a
        POP af
        RET

; Clear a selected object record.
CLEAR_OBJECT_RECORD:
        LD hl,$21C1
L06A7:
        LD a,(hl)
        AND a
        RET z
        LD (hl),$00
        INC hl
        LD d,(hl)
        PUSH hl
        LD hl,$2024
        LD bc,$000D
L06B5:
        ADD hl,bc
        DEC a
        JP nz,L06B5
        LD bc,$0008
        ADD hl,bc
        LD (hl),$0E
        DEC hl
        LD (hl),$55
        DEC hl
        DEC hl
        DEC hl
        LD (hl),$01
        DEC hl
        DEC hl
        LD (hl),d
        DEC hl
        LD (hl),$00
        DEC hl
        LD b,(hl)
        LD (hl),$E0
        LD a,($2002)
        AND a
        JP nz,L06DB
        POP hl
        RET
L06DB:
        LD a,b
        LD bc,$0F57
        AND $07
        ADD a,c
        LD c,a
        LD de,$21E9
        CALL L0A82
        LD a,$30
        LD (de),a
        INC de
        LD (de),a
        LD a,(bc)
        LD hl,$202B
        ADD a,(hl)
        DAA
        LD (hl),a
        POP hl
        LD c,(hl)
        INC hl
        LD b,(hl)
        INC hl
        PUSH hl
        LD a,b
        ADD a,$20
        LD hl,$09C2
        JP c,L0707
        LD hl,$09BA
L0707:
        LD a,c
        RLCA
        RLCA
        RLCA
        AND $07
        ADD a,l
        LD l,a
        LD a,(hl)
        OUT ($01),a
        LD a,$01
        OUT ($05),a
        LD a,$1E
        LD ($2025),a
        LD a,b
        LD d,$24
        ADD a,$20
        JP m,L0725
        LD d,$28
L0725:
        LD a,c
        RRCA
        RRCA
        RRCA
        AND $1F
        JP z,L072F
        DEC a
L072F:
        CP $1E
        JP nz,L0735
        DEC a
L0735:
        OR $A0
        LD e,a
        CALL SEARCH_ACTIVE_OBJECTS
        LD a,$2D
        LD ($2024),a
        LD hl,$21EA
        LD a,$03
        CALL RENDER_GAME_TEXT
        POP hl
        JP L06A7
L074C:
        LD hl,$21A3
L074F:
        LD a,(hl)
        AND a
        RET z
        INC hl
        ADD a,$10
        RLCA
        RLCA
        RLCA
        AND $07
        LD de,$2067
        LD bc,$000D
        EX de,hl
L0761:
        ADD hl,bc
        ADD hl,bc
        DEC a
        JP nz,L0761
        LD a,(de)
        SUB $08
        SUB (hl)
        CP $EC
        JP nc,L0771
        ADD hl,bc
L0771:
        DEC hl
        DEC hl
        LD (hl),$00
        EX de,hl
        DEC hl
        LD a,(hl)
        ADD a,$30
        AND $F0
        LD d,a
        LD (hl),$00
        INC hl
        LD e,(hl)
        INC hl
        PUSH hl
        CALL BIT_SHIFT_SETUP
        LD a,e
        AND $1F
        JP z,L0796
        DEC a
        JP z,L0796
L0790:
        DEC a
        CP $1C
        JP p,L0790
L0796:
        LD e,a
        CALL SEARCH_ACTIVE_OBJECTS
        LD b,d
        INC b
        INC b
        LD c,e
        INC c
        PUSH bc
        LD a,e
        ADD a,$60
        LD e,a
        PUSH de
        LD b,d
        INC c
        PUSH bc
        LD a,$1E
        LD ($2025),a
        LD a,$0F
        LD ($2024),a
        LD a,$10
        OUT ($05),a
        LD a,e
        AND $02
        LD hl,$0F40
        ADD a,l
        LD l,a
        LD e,(hl)
        INC hl
        LD d,(hl)
        EX de,hl
        POP de
        LD a,(hl)
        INC hl
        CALL RENDER_GAME_TEXT
        POP de
        LD a,(hl)
        INC hl
        CALL RENDER_GAME_TEXT
        POP de
        LD hl,$0EB5
        LD a,$03
        CALL RENDER_GAME_TEXT
        POP hl
        JP L074F

; Find a matching active object.
SEARCH_ACTIVE_OBJECTS:
        LD hl,$21F0
L07DE:
        LD a,(hl)
        INC hl
        OR (hl)
        INC hl
        JP nz,L07DE
        DEC hl
        LD (hl),e
        DEC hl
        LD (hl),d
        RET

; Derive gameplay difficulty from score state.
UPDATE_SCORE_DIFFICULTY:
        LD a,($202B)
        CP $40
        JP c,L07F4
        LD a,$39
L07F4:
        LD ($202C),a
        LD hl,$207F
        LD de,$5050
L07FD:
        LD a,(hl)
        AND a
        JP m,L0835
L0802:
        LD bc,$0008
        ADD hl,bc
        LD (hl),$0E
        DEC hl
        LD (hl),$A3
        DEC hl
        DEC hl
        LD (hl),e
        DEC hl
        LD (hl),b
        DEC hl
        DEC hl
        LD (hl),d
        DEC hl
        LD (hl),$01
        DEC hl
        LD (hl),$80
        LD a,d
        ADD a,$51
        LD d,a
        RRA
        JP c,L082E
        LD a,($202C)
        SUB $10
        RET m
        LD ($202C),a
        LD a,e
        ADD a,$20
        LD e,a
L082E:
        LD bc,$000D
        ADD hl,bc
        JP L07FD
L0835:
        PUSH hl
        PUSH de
        INC hl
        INC hl
        LD e,(hl)
        INC hl
        INC hl
        INC hl
        LD d,(hl)
        CALL BIT_SHIFT_SETUP
        EX de,hl
        LD bc,$1002
        CALL CLEAR_GRAPHIC_BLOCK
        POP de
        POP hl
        JP L0802
        RET z
        XOR a
        LD ($2006),a
        LD a,($2010)
        AND a
        RET z
        LD hl,$21E9
        PUSH hl
        LD bc,$0430
L085E:
        LD (hl),c
        INC hl
        DEC b
        JP nz,L085E
        POP hl
        LD de,$3E25
        LD a,$04
        JP RENDER_GAME_TEXT
        EX de,hl
        LD ($2000),hl
        LD a,($2003)
        AND $07
        CP $07
        JP nz,L087C
        XOR a
L087C:
        LD ($2029),a
        RET

; Reset game state and script pointer.
RESET_GAME_STATE:
        DI
        EX de,hl
        LD ($2000),hl
        XOR a
        OUT ($02),a
        OUT ($05),a
        OUT ($01),a
        POP hl
        LD bc,$0000
        LD de,$0000
        LD a,$10
        LD sp,$4010
L0898:
        PUSH bc
        INC de
        CP d
        JP nz,L0898
        LD sp,$2400
        JP (hl)

; Initialize RAM and launch the main control path.
INITIALIZE_GAME_STATE:
        POP hl
        LD ($2009),hl
        CALL RESET_GAME_STATE
        LD hl,($2009)
        PUSH hl
        LD hl,$0F04
        LD de,$27E0
        LD a,$20
        JP RENDER_GAME_TEXT

; Poll player input port.
POLL_PLAYER_INPUT:
        IN a,($01)
        LD b,a
        IN a,($01)
        LD hl,$2008
        LD de,$09DA
        CP b
        CALL z,HANDLE_INPUT_CHANGE
        RET
        RET z
        LD a,$20
        OUT ($05),a
        LD a,$0F
        LD ($2025),a
        LD a,($2007)
        LD b,a
        LD hl,$2004
        INC (hl)
        AND $04
        JP z,L08E2
        LD a,(hl)
        RRCA
        RET c
L08E2:
        LD (hl),$00
        INC hl
        INC (hl)
        LD a,b
        AND $08
        JP z,L08F4
        INC (hl)
        LD a,b
        AND $04
        JP z,L08F4
        INC (hl)
L08F4:
        LD a,(hl)
        AND $0F
        LD (hl),a
        RET z
        LD a,($2002)
        AND a
        RET nz
        LD hl,$2005
        LD a,(hl)
        AND a
        JP z,CHECK_COIN_INPUT
L0906:
        DEC (hl)
        IN a,($01)
        RLCA
        RLCA
        AND $03
        LD de,$0F54
        ADD a,e
        LD e,a
        LD a,(de)
        LD ($2002),a
        LD ($202A),a
        RET

; Examine coin-input bits.
CHECK_COIN_INPUT:
        LD a,($2007)
        AND $0C
        CP $0C
        RET nz
        DEC hl
        LD a,(hl)
        AND a
        RET z
        JP L0906

; Interpreted game command bytes and inline operands; not native opcodes.
GAME_SCRIPT_STREAMS:
        DB $04,$01,$B8,$0E,$30,$3E,$09,$05,$20,$33,$38,$E6
        DB $0E,$F1,$0E,$04,$1A,$CC,$0E,$02,$3C,$0A,$06,$20
        DB $E9,$21,$25,$3E,$0A,$2B,$20,$E9,$21,$35,$3E,$02
        DB $0F,$04,$09,$C3,$0E,$0B,$2C,$01,$1E,$00,$04,$09
        DB $B8,$0E,$0B,$2C,$01,$1E,$00,$06,$4E,$09,$03,$04
        DB $08,$FC,$0E,$0C,$2C,$04,$0A,$CC,$0E,$02,$3C,$0A
        DB $06,$20,$E9,$21,$25,$3E,$09,$05,$20,$33,$38,$E6
        DB $0E,$F1,$0E,$01,$5A,$00,$08,$09,$60,$20,$EB,$0D
        DB $20,$15,$00,$E0,$00,$01,$C4,$01,$5A,$00,$08,$09
        DB $EF,$20,$75,$0E,$9C,$E0,$FA,$00,$A8,$00,$C0,$01
        DB $B4,$00,$06,$63,$09,$01,$0F,$00,$03,$04,$09,$29
        DB $0F,$0E,$3C,$07,$28,$22,$20,$07,$0A,$21,$20,$0B
        DB $00,$48,$44,$42,$41,$88,$84,$82,$81,$18,$14,$12
        DB $11,$28,$24,$22,$21,$C8,$08,$F8,$08,$C7,$08,$C7
        DB $08,$4D,$08,$C7,$08,$C7,$08,$C7,$08,$C7,$08,$C7
        DB $08,$C7,$08,$C7,$08,$C7,$08,$7B,$05,$C7,$08
; Game script/native handler pointer region begins here.

; Indexed 16-bit native handler addresses, little endian.
GAME_COMMAND_HANDLER_TABLE:
        DB $C7,$08,$7C,$0B,$72,$0B,$A2,$08,$22,$0B,$ED,$0A
        DB $86,$0B,$E1,$0A,$9F,$0A,$BC,$0A,$53,$0A,$6D,$08
; Set up bit-shift operands.
BIT_SHIFT_SETUP:
        LD a,e
        AND $07
        LD c,a
        LD b,$03
L0A06:
        XOR a
        LD a,d
        RRA
        LD d,a
        LD a,e
        RRA
        LD e,a
        DEC b
        JP nz,L0A06
        LD a,d
        ADD a,$24
        LD d,a
        RET

; Copy object data to destination.
COPY_OBJECT_BYTES:
        PUSH af
        LD a,(hl)
        LD (bc),a
        INC bc
        EX de,hl
        OR (hl)
        INC hl
        LD (de),a
        POP af
        PUSH hl
        LD hl,$0020
        ADD hl,de
        POP de
        DEC a
        JP nz,COPY_OBJECT_BYTES
        RET

; Copy rectangular graphics bytes.
COPY_GRAPHIC_BLOCK:
        PUSH bc
        PUSH hl
L0A2C:
        LD a,(de)
        INC de
        LD (hl),a
        INC hl
        DEC c
        JP nz,L0A2C
        POP hl
        LD bc,$0020
        ADD hl,bc
        POP bc
        DEC b
        JP nz,COPY_GRAPHIC_BLOCK
        RET

; Clear rectangular graphics bytes.
CLEAR_GRAPHIC_BLOCK:
        XOR a
L0A40:
        PUSH bc
        PUSH hl
L0A42:
        LD (hl),a
        INC hl
        DEC c
        JP nz,L0A42
        POP hl
        LD bc,$0020
        ADD hl,bc
        POP bc
        DEC b
        JP nz,L0A40
        RET
        EX de,hl
        LD c,(hl)
        INC hl
        LD b,(hl)
        INC hl
        LD e,(hl)
        INC hl
        LD d,(hl)
        DEC hl
        CALL L0A82
        EX de,hl
        CALL TEST_OBJECT_FLAGS
        INC hl
        EX de,hl
        LD a,$30
        LD (de),a
        INC de
        LD (de),a
        CALL L0ADC
        PUSH de
        CALL L0ADC
        LD ($2000),hl
        POP hl
        LD a,$04
        JP RENDER_GAME_TEXT

; Test object flag bits.
TEST_OBJECT_FLAGS:
        DEC hl
        LD a,(hl)
        AND $40
        RET z
        LD (hl),$30
        RET
L0A82:
        LD a,(bc)
        RRA
        RRA
        RRA
        RRA
        AND $0F
        JP nz,CONVERT_SCORE_TO_DIGITS
        LD a,$10

; Convert score digits to display codes.
CONVERT_SCORE_TO_DIGITS:
        ADD a,$30
        LD (de),a
        INC de
        LD a,(bc)
        AND $0F
        JP nz,L0A9A
        LD a,$10
L0A9A:
        ADD a,$30
        LD (de),a
        INC de
        RET
        EX de,hl
        LD b,(hl)
        INC hl
        DEC b
        DEC b
        CALL L0ADC
        LD c,(hl)
        INC hl
        LD a,(hl)
        INC hl
        LD (de),a
        DEC de
        LD a,c
        LD (de),a
        DEC de
L0AB0:
        LD a,(hl)
        INC hl
        LD (de),a
        DEC de
        DEC b
        JP nz,L0AB0
        LD ($2000),hl
        RET
        EX de,hl
        CALL L0ADC
        LD a,(de)
        CALL L0ADC
        PUSH de
        CALL L0ADC
        PUSH de
        CALL L0ADC
        LD ($2000),hl
        EX de,hl
        AND a
        JP z,L0AD5
        EX (sp),hl
L0AD5:
        POP hl
        POP de
        LD a,$0B
        JP RENDER_GAME_TEXT
L0ADC:
        LD e,(hl)
        INC hl
        LD d,(hl)
        INC hl
        RET
        LD a,(de)
        INC de
        EX de,hl
        LD c,(hl)
        INC hl
        LD b,(hl)
        INC hl
        LD ($2000),hl
        LD (bc),a
        RET
        EX de,hl
        LD b,(hl)
        INC hl
        LD c,(hl)
        INC hl
        LD a,(hl)
        INC hl
        CALL L0ADC
        LD ($2000),hl
        EX de,hl
        LD (hl),$DB
        INC hl
        LD (hl),c
        INC hl
        LD (hl),$C9
        DEC hl
        DEC hl
        JP (hl)

; Handle a change on an input bit.
HANDLE_INPUT_CHANGE:
        XOR (hl)
        RET z
        LD c,a
        LD b,$01
L0B0A:
        LD a,c
        RRCA
        JP c,L0B18
        LD c,a
        LD a,b
        RLCA
        LD b,a
        INC de
        INC de
        JP L0B0A
L0B18:
        LD a,b
        XOR (hl)
        LD (hl),a
        AND b
        EX de,hl
        LD c,(hl)
        INC hl
        LD h,(hl)
        LD l,c
        JP (hl)
        EX de,hl
        LD a,(hl)
        INC hl
        CALL L0ADC
        PUSH de
        CALL L0ADC
        LD ($2000),hl
        POP hl

; Render an encoded text stream.
RENDER_GAME_TEXT:
        PUSH af
L0B31:
        LD a,(hl)
        INC hl
        SUB $30
        JP p,SELECT_CHARACTER_GLYPH
        LD b,a
L0B39:
        INC e
        LD a,e
        AND $1F
        JP nz,L0B42
        INC d
        INC d
L0B42:
        INC b
        JP nz,L0B39
        JP L0B31

; Locate the character glyph bitmap.
SELECT_CHARACTER_GLYPH:
        PUSH hl
        PUSH de
        LD hl,$0B8F
        JP z,COPY_CHARACTER_GLYPH
        LD bc,$000A
L0B54:
        ADD hl,bc
        DEC a
        JP nz,L0B54

; Copy the character glyph to video RAM.
COPY_CHARACTER_GLYPH:
        EX de,hl
        LD bc,$0020
        LD a,$0A
L0B5F:
        PUSH af
        LD a,(de)
        INC de
        LD (hl),a
        ADD hl,bc
        POP af
        DEC a
        JP nz,L0B5F
        POP de
        POP hl
        INC de
        POP af
        DEC a
        JP nz,RENDER_GAME_TEXT
        RET

; Store next inline script byte at $2010.
SCRIPT_STORE_STATE_2010:
        EX de,hl
        LD a,(hl)
        INC hl
        LD ($2000),hl
        LD ($2010),a
        RET

; Store next inline script byte at $2011.
SCRIPT_STORE_STATE_2011:
        EX de,hl
        LD a,(hl)
        INC hl
        LD ($2000),hl
        LD ($2011),a
        RET

; Load little-endian inline jump target into script pointer.
SCRIPT_JUMP_ABSOLUTE:
        EX de,hl
        LD e,(hl)
        INC hl
        LD d,(hl)
        EX de,hl
        LD ($2000),hl
        RET

; Numeric font: 8x10 characters, ten bytes per glyph.
NUMERIC_GLYPH_BITMAPS:

; 0: 8x10 character bitmap.
FONT_DIGIT_0:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 1: 8x10 character bitmap.
FONT_DIGIT_1:
        DB $18  ; ...##...
        DB $1C  ; ...###..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $3C  ; ..####..

; 2: 8x10 character bitmap.
FONT_DIGIT_2:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $60  ; .##.....
        DB $7C  ; .#####..
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; 3: 8x10 character bitmap.
FONT_DIGIT_3:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $60  ; .##.....
        DB $38  ; ..###...
        DB $78  ; .####...
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 4: 8x10 character bitmap.
FONT_DIGIT_4:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....

; 5: 8x10 character bitmap.
FONT_DIGIT_5:
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 6: 8x10 character bitmap.
FONT_DIGIT_6:
        DB $3C  ; ..####..
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 7: 8x10 character bitmap.
FONT_DIGIT_7:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $70  ; .###....
        DB $30  ; ..##....
        DB $38  ; ..###...
        DB $18  ; ...##...
        DB $1C  ; ...###..
        DB $0C  ; ....##..
        DB $0C  ; ....##..

; 8: 8x10 character bitmap.
FONT_DIGIT_8:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 9: 8x10 character bitmap.
FONT_DIGIT_9:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7C  ; .#####..
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $7C  ; .#####..
        DB $3C  ; ..####..

; Additional numeric font/trailer bytes ($0BF3-$0BFF).
NUMERIC_FONT_TRAILER:
        DB $0C,$93,$60,$00,$00,$00,$00,$00,$00,$00,$60,$99
        DB $06

; ROM device sw0044.e — SHA-1 bd345dd72fed8ce15da76c381782b025f71b006f
; Original graphic header and leading pattern bytes.
GRAPHICS_ASSET_ROM:
        DB $00,$00,$00,$00,$00,$00,$00,$30,$CD,$02,$00,$00
        DB $00,$00,$00,$00,$00,$02,$C0,$78,$E0,$80,$F0,$01
        DB $C0,$F0,$7C,$08,$1C,$3E,$7F,$FF,$FF,$BF,$1F,$02
        DB $40,$02,$80,$78,$1E,$07,$01,$7C,$F8,$0C,$10,$00
        DB $00,$00,$00,$00,$00,$00,$00,$00,$00

; Uppercase font: 8x10 characters, ten bytes per glyph.

; A: 8x10 character bitmap.
FONT_LETTER_A:
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; B: 8x10 character bitmap.
FONT_LETTER_B:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.

; C: 8x10 character bitmap.
FONT_LETTER_C:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; D: 8x10 character bitmap.
FONT_LETTER_D:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.

; E: 8x10 character bitmap.
FONT_LETTER_E:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; F: 8x10 character bitmap.
FONT_LETTER_F:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.

; G: 8x10 character bitmap.
FONT_LETTER_G:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $76  ; .###.##.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; H: 8x10 character bitmap.
FONT_LETTER_H:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; I: 8x10 character bitmap.
FONT_LETTER_I:
        DB $3C  ; ..####..
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $3C  ; ..####..

; J: 8x10 character bitmap.
FONT_LETTER_J:
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; K: 8x10 character bitmap.
FONT_LETTER_K:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $76  ; .###.##.
        DB $3E  ; ..#####.
        DB $1E  ; ...####.
        DB $1E  ; ...####.
        DB $3E  ; ..#####.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; L: 8x10 character bitmap.
FONT_LETTER_L:
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; M: 8x10 character bitmap.
FONT_LETTER_M:
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $FF  ; ########
        DB $FF  ; ########
        DB $DB  ; ##.##.##
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $C3  ; ##....##

; N: 8x10 character bitmap.
FONT_LETTER_N:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $6E  ; .##.###.
        DB $6E  ; .##.###.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $76  ; .###.##.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; O: 8x10 character bitmap.
FONT_LETTER_O:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; P: 8x10 character bitmap.
FONT_LETTER_P:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.

; Q: 8x10 character bitmap.
FONT_LETTER_Q:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $5C  ; .#.###..

; R: 8x10 character bitmap.
FONT_LETTER_R:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; S: 8x10 character bitmap.
FONT_LETTER_S:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7C  ; .#####..
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; T: 8x10 character bitmap.
FONT_LETTER_T:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...

; U: 8x10 character bitmap.
FONT_LETTER_U:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; V: 8x10 character bitmap.
FONT_LETTER_V:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...

; W: 8x10 character bitmap.
FONT_LETTER_W:
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $DB  ; ##.##.##
        DB $FF  ; ########
        DB $FF  ; ########
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $C3  ; ##....##
        DB $C3  ; ##....##

; X: 8x10 character bitmap.
FONT_LETTER_X:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; Y: 8x10 character bitmap.
FONT_LETTER_Y:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...

; Z: 8x10 character bitmap.
FONT_LETTER_Z:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $70  ; .###....
        DB $38  ; ..###...
        DB $1C  ; ...###..
        DB $0E  ; ....###.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; Additional graphic and explosion/object bitmap bytes.
OBJECT_GRAPHICS:
        DB $05,$0C,$00,$00,$08,$00,$00,$00,$00,$08,$00,$00
        DB $00,$60,$0E,$00,$00,$00,$E0,$CE,$3F,$00,$00,$E0
        DB $DE,$03,$00,$F8,$F7,$DF,$F7,$0F,$80,$F7,$DF,$F7
        DB $00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$7F,$FF
        DB $FF,$FF,$FF,$3F,$FE,$FF,$FF,$FF,$1F,$FE,$FF,$FF
        DB $FF,$0F,$04,$0C,$00,$00,$03,$00,$00,$36,$03,$00
        DB $00,$36,$03,$00,$02,$B6,$03,$00,$87,$FF,$F3,$07
        DB $E2,$FF,$F7,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$7F
        DB $FF,$FF,$FF,$3F,$FC,$FF,$FF,$1F,$FC,$FF,$FF,$0F
        DB $F8,$FF,$FF,$07,$05,$0C,$00,$00,$40,$00,$00,$00
        DB $00,$F0,$00,$00,$00,$00,$F0,$00,$00,$00,$80,$F0
        DB $1E,$00,$00,$00,$FB,$06,$00,$FF,$FF,$FF,$FF,$FF
        DB $FC,$FF,$FF,$FF,$3F,$FC,$FF,$FF,$FF,$1F,$FC,$FF
        DB $FF,$FF,$0F,$F8,$FF,$FF,$FF,$07,$F8,$FF,$FF,$FF
        DB $03,$F8,$FF,$FF,$FF,$03,$04,$0B,$40,$00,$00,$02
        DB $40,$80,$00,$02,$40,$00,$07,$02,$40,$00,$07,$02
        DB $40,$F0,$07,$02,$FC,$F0,$07,$F8,$FC,$FF,$FF,$7F
        DB $FC,$FF,$FF,$3F,$F8,$FF,$FF,$1F,$F0,$FF,$FF,$0F
        DB $F0,$FF,$FF,$0F,$04,$0B,$80,$00,$00,$00,$00,$00
        DB $00,$01,$A0,$01,$00,$01,$A0,$01,$00,$01,$F0,$01
        DB $00,$01,$F8,$01,$00,$F9,$F8,$FF,$FF,$7F,$F0,$FF
        DB $FF,$3F,$F0,$FF,$FF,$1F,$F0,$FF,$FF,$0F,$E0,$FF
        DB $FF,$0F,$02,$06,$00,$03,$10,$07,$E0,$FF,$FF,$7F
        DB $FF,$3F,$FF,$1F,$02,$0F,$10,$00,$30,$02,$70,$01
        DB $FC,$00,$F8,$11,$F0,$3B,$E0,$7F,$C0,$3F,$80,$1F
        DB $00,$3F,$00,$1E,$00,$04,$00,$48,$00,$F8,$00,$F8
        DB $01,$11,$10,$38,$38,$38,$38,$38,$38,$38,$38,$38
        DB $38,$38,$38,$10,$10,$10,$38,$01,$0E,$18,$18,$18
        DB $18,$18,$18,$18,$18,$18,$18,$18,$18,$00,$18,$01
        DB $09,$10,$10,$10,$10,$10,$10,$10,$10,$10,$01,$10
        DB $10,$BA,$7C,$FE,$7C,$38,$54,$10,$00,$10,$00,$08
        DB $00,$00,$04,$00,$3D,$3E,$3F,$40,$40,$40,$40,$40
        DB $40,$40,$40,$40,$40,$40,$47,$41,$4D,$45,$40,$4F
        DB $56,$45,$52,$48,$49,$47,$48,$40,$53,$43,$4F,$52
        DB $45,$40,$40,$40,$40,$40,$40,$59,$4F,$55,$52,$40
        DB $53,$43,$4F,$52,$45,$49,$4E,$53,$45,$52,$54,$40
        DB $43,$4F,$49,$4E,$50,$55,$53,$48,$40,$42,$55,$54
        DB $54,$4F,$4E,$53,$45,$41,$40,$57,$4F,$4C,$46,$3A
        DB $3B,$3C,$3B,$3C,$3A,$3B,$3C,$3A,$3C,$3B,$3C,$3A
        DB $3B,$3A,$3C,$3B,$3A,$3C,$3A,$3B,$3C,$3A,$3C,$3B
        DB $3C,$3A,$3B,$3C,$3A,$3B,$3C

; DISPLAY_LEGEND_TABLE ($0F24) - Embedded display words and game-status layout data
; -----------------------------------------------------------------------------
DISPLAY_LEGEND_TABLE:
        DB $42,$4F,$4E,$55,$53,$54,$49,$4D,$45,$2D,$53,$43
        DB $4F,$52,$45,$45,$58,$54,$45,$4E,$44,$45,$44,$16
        DB $54,$49,$4D,$45,$44,$0F,$4C,$0F,$01,$41,$04,$3D
        DB $5A,$2F,$50,$3F,$01,$41,$04,$3D,$57,$2F,$4D,$3F

; Lookup data used by object placement and shifting.
BIT_ORDER_LOOKUP:
        DB $61,$71,$81,$91,$03,$03,$03,$01,$01,$07,$00,$08
        DB $18,$10,$38,$30,$20,$28,$78,$70,$60,$68,$40,$48
        DB $58,$50,$F8,$F0,$E0,$E8,$C0,$C8,$D8,$D0,$80,$88
        DB $98,$90,$B8,$B0,$A0,$A8,$0D,$3D,$20,$14,$00,$D8
        DB $00,$02,$0D,$7B,$20,$14,$00,$E0,$00,$02,$0D,$AD
        DB $20,$14,$00,$D8,$00,$02,$0D,$EB,$20,$15,$00,$E0
        DB $00,$01,$0E,$19,$20,$15,$00,$E0,$00,$01,$0E,$47
        DB $20,$1A,$00,$F0,$00,$03,$0D,$3D,$40,$34,$00,$D8
        DB $D8,$FE,$0D,$7B,$40,$34,$00,$E0,$E0,$FE,$0D,$AD
        DB $40,$34,$00,$D8,$D8,$FE,$0D,$EB,$40,$35,$00,$E0
        DB $E0,$FF,$0E,$19,$40,$35,$00,$E0,$E0,$FF,$0E,$47
        DB $40,$3A,$00,$F0,$F0,$FD,$06,$04,$02,$06,$03,$05
        DB $01
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38
        RST $38

        END

; End original ROM image
