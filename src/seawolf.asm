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

TEXT_SPACE EQU $40

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
        LD SP,$2400
        JP STARTUP_INITIALIZE

; Interrupt vector: save registers and enter object update.
IRQ_VECTOR_08:
        PUSH HL
        PUSH DE
        PUSH BC
        PUSH AF
        JP IRQ_OBJECT_UPDATE
        NOP

; Interrupt vector: save registers and choose update phase.
IRQ_VECTOR_10:
        PUSH HL
        PUSH DE
        PUSH BC
        PUSH AF
        LD A,($201F)
        AND A
        JP NZ,IRQ_ERASE_ACTIVE_SPRITE
        CALL UPDATE_WAVE_PATTERN
        CALL $012E
        LD HL,($2016)
        LD A,(HL)
        AND A
        JP P,IRQ_SET_UPDATE_PHASE
        AND $20
        JP Z,IRQ_SET_UPDATE_PHASE
        CALL LOAD_OBJECT_DRAW_PARAMETERS
        DEC C
        EX DE,HL
        CALL COPY_GRAPHIC_BLOCK

; Irq set update phase.
IRQ_SET_UPDATE_PHASE:
        LD A,$FF

; Irq save update phase.
IRQ_SAVE_UPDATE_PHASE:
        LD ($201F),A
        JP IRQ_INPUT_AND_RETURN

; Irq erase active sprite.
IRQ_ERASE_ACTIVE_SPRITE:
        LD HL,($2016)
        LD A,(HL)
        AND A
        JP P,IRQ_FINALIZE_SPRITE_PHASE
        AND $40
        JP NZ,IRQ_DRAW_ACTIVE_SPRITE
        LD (HL),$00
        JP IRQ_FINALIZE_SPRITE_PHASE

; Irq draw active sprite.
IRQ_DRAW_ACTIVE_SPRITE:
        LD A,(HL)
        OR $20
        LD (HL),A
        CALL $0165
        LD A,B
        PUSH HL
        LD HL,($201C)
        LD B,H
        LD C,L
        POP HL
        CALL COPY_OBJECT_BYTES

; Irq finalize sprite phase.
IRQ_FINALIZE_SPRITE_PHASE:
        CALL UPDATE_FRAME_TIMERS
        XOR A
        LD ($201F),A

; Sample input port and restore interrupt context.
IRQ_INPUT_AND_RETURN:
        IN A,($02)
        LD B,A
        IN A,($02)
        LD HL,$2007
        LD DE,$09CA
        CP B
        CALL Z,HANDLE_INPUT_CHANGE
        POP AF
        POP BC
        POP DE
        POP HL
        EI
        RET

; Update RAM-backed object descriptors during interrupt processing.
IRQ_OBJECT_UPDATE:
        LD A,($201F)
        AND A
        JP NZ,$0119
        CALL UPDATE_WAVE_PATTERN
        LD HL,$215F
        LD B,$44
        XOR A

; Irq clear temp buffer loop.
IRQ_CLEAR_TEMP_BUFFER_LOOP:
        LD (HL),A
        INC HL
        DEC B
        JP NZ,IRQ_CLEAR_TEMP_BUFFER_LOOP
        LD HL,($2018)
        LD A,$03

; Irq ship group a loop.
IRQ_SHIP_GROUP_A_LOOP:
        PUSH AF
        LD A,L
        CP $58
        JP NZ,IRQ_SHIP_GROUP_A_TEST

; Irq ship group a wrap.
IRQ_SHIP_GROUP_A_WRAP:
        LD HL,$2031

; Irq ship group a test.
IRQ_SHIP_GROUP_A_TEST:
        OR H
        JP Z,IRQ_SHIP_GROUP_A_WRAP
        PUSH HL
        CALL $01DE
        POP HL
        JP NC,IRQ_SHIP_GROUP_A_NEXT
        LD ($2018),HL

; Irq ship group a next.
IRQ_SHIP_GROUP_A_NEXT:
        LD DE,$000D
        ADD HL,DE
        POP AF
        DEC A
        JP NZ,IRQ_SHIP_GROUP_A_LOOP
        LD HL,($2018)
        CALL CLEAR_ACTIVE_OBJECT
        LD HL,($201A)
        LD A,$03

; Irq ship group b loop.
IRQ_SHIP_GROUP_B_LOOP:
        PUSH AF
        LD A,L
        CP $7F
        JP NZ,IRQ_SHIP_GROUP_B_TEST

; Irq ship group b wrap.
IRQ_SHIP_GROUP_B_WRAP:
        LD HL,$2058

; Irq ship group b test.
IRQ_SHIP_GROUP_B_TEST:
        OR H
        JP Z,IRQ_SHIP_GROUP_B_WRAP
        PUSH HL
        CALL $01DE
        POP HL
        JP NC,IRQ_SHIP_GROUP_B_NEXT
        LD ($201A),HL

; Irq ship group b next.
IRQ_SHIP_GROUP_B_NEXT:
        LD DE,$000D
        ADD HL,DE
        POP AF
        DEC A
        JP NZ,IRQ_SHIP_GROUP_B_LOOP
        XOR A
        LD ($2030),A
        LD HL,($2016)
        LD A,$04

; Irq projectile group loop.
IRQ_PROJECTILE_GROUP_LOOP:
        PUSH AF
        LD A,L
        CP $5F
        JP NZ,IRQ_PROJECTILE_GROUP_TEST

; Irq projectile group wrap.
IRQ_PROJECTILE_GROUP_WRAP:
        LD HL,$20E7

; Irq projectile group test.
IRQ_PROJECTILE_GROUP_TEST:
        OR H
        JP Z,IRQ_PROJECTILE_GROUP_WRAP
        PUSH HL
        CALL UPDATE_PROJECTILE_DESCRIPTOR
        POP HL
        JP NC,IRQ_PROJECTILE_GROUP_NEXT
        LD ($2016),HL

; irq projectile group next; internal branch at IRQ_PROJECTILE_GROUP_NEXT:0A.
IRQ_PROJECTILE_GROUP_NEXT:
        LD DE,$001E
        ADD HL,DE
        POP AF
        DEC A
        JP NZ,IRQ_PROJECTILE_GROUP_LOOP
        CALL ADVANCE_OBJECT_CURSOR
        JP IRQ_INPUT_AND_RETURN

; -----------------------------------------------------------------------------
; IRQ_OBJECT_DRAW (IRQ_OBJECT_DRAW:19) - Draw active ship objects
; -----------------------------------------------------------------------------
IRQ_OBJECT_DRAW:
        LD HL,($201A)
        CALL CLEAR_ACTIVE_OBJECT
        LD HL,($201A)
        CALL $013A
        LD HL,($2018)
        CALL $013A
        JP IRQ_INPUT_AND_RETURN

; -----------------------------------------------------------------------------
; UPDATE_SELECTED_OBJECT (UPDATE_SELECTED_OBJECT:2E) - Update the selected active object
; -----------------------------------------------------------------------------
UPDATE_SELECTED_OBJECT:
        LD HL,($2014)
        LD A,(HL)
        AND A
        RET P
        CALL $0165
        JP $0192

; -----------------------------------------------------------------------------
; UPDATE_SHIP_OBJECT (UPDATE_SHIP_OBJECT:3A) - Process a ship-object state field
; -----------------------------------------------------------------------------
UPDATE_SHIP_OBJECT:
        LD A,(HL)
        AND A
        RET P
        AND $40
        JP NZ,SHIP_OBJECT_DRAW_PENDING
        LD (HL),$00
        RET

; ship object draw pending; internal branch at SHIP_OBJECT_DRAW_PENDING:45.
SHIP_OBJECT_DRAW_PENDING:
        LD A,(HL)
        OR $20
        LD (HL),A
        PUSH AF
        CALL $0165
        POP AF
        AND $10
        JP Z,$0192
        LD A,C
        ADD A,L
        LD L,A
        PUSH HL
        LD HL,$2030
        LD A,(HL)
        CPL
        AND $07
        LD (HL),A
        POP HL
        OUT ($04),A
        JP $01B8

; -----------------------------------------------------------------------------
; PREPARE_SPRITE_COPY (PREPARE_SPRITE_COPY:65) - Read the object's graphic source and destination parameters
; -----------------------------------------------------------------------------
PREPARE_SPRITE_COPY:
        INC HL
        INC HL
        LD E,(HL)
        INC HL
        INC HL
        INC HL
        LD D,(HL)
        INC HL
        INC HL
        CALL BIT_SHIFT_SETUP
        LD A,C
        LD ($2030),A
        OUT ($04),A
        PUSH DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        EX DE,HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        INC HL
        EX (SP),HL
        EX DE,HL
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD (HL),C
        INC (HL)
        INC HL
        LD (HL),B
        INC HL
        LD ($201C),HL
        EX DE,HL
        POP DE
        RET

; -----------------------------------------------------------------------------
; DRAW_SPRITE_NORMAL (DRAW_SPRITE_NORMAL:92) - Copy sprite bytes through the shifter path
; -----------------------------------------------------------------------------
DRAW_SPRITE_NORMAL:
        PUSH BC
        PUSH HL

; sprite normal row loop; internal branch at SPRITE_NORMAL_ROW_LOOP:94.
SPRITE_NORMAL_ROW_LOOP:
        LD A,(DE)
        INC DE
        OUT ($03),A
        IN A,($03)
        LD (HL),A
        INC HL
        DEC C
        JP NZ,SPRITE_NORMAL_ROW_LOOP
        XOR A
        OUT ($03),A
        IN A,($03)
        LD (HL),A
        LD BC,$0020
        POP HL
        ADD HL,BC
        POP BC
        LD A,L
        AND $E0
        JP NZ,$0192
        LD A,H
        RRA
        JP C,$0192
        RET

; -----------------------------------------------------------------------------
; DRAW_SPRITE_SHIFTED (DRAW_SPRITE_SHIFTED:B8) - Copy sprite bytes through the alternate shifted path
; -----------------------------------------------------------------------------
DRAW_SPRITE_SHIFTED:
        PUSH BC
        PUSH HL

; sprite shifted row loop; internal branch at SPRITE_SHIFTED_ROW_LOOP:BA.
SPRITE_SHIFTED_ROW_LOOP:
        LD A,(DE)
        INC DE
        OUT ($03),A
        IN A,($00)
        LD (HL),A
        DEC HL
        DEC C
        JP NZ,SPRITE_SHIFTED_ROW_LOOP
        XOR A
        OUT ($03),A
        IN A,($00)
        LD (HL),A
        LD BC,$0020
        POP HL
        ADD HL,BC
        POP BC
        LD A,L
        AND $E0
        JP NZ,$01B8
        LD A,H
        RRA
        JP C,$01B8
        RET

; -----------------------------------------------------------------------------
; UPDATE_SHIP_DESCRIPTOR (UPDATE_SHIP_DESCRIPTOR:DE) - Advance and test ship descriptor
; -----------------------------------------------------------------------------
UPDATE_SHIP_DESCRIPTOR:
        LD A,(HL)
        AND A
        RET P
        PUSH HL
        INC HL
        AND $07
        JP NZ,SHIP_DESCRIPTOR_STATE_CHECK
        INC HL
        INC HL
        JP SHIP_DESCRIPTOR_TOGGLE_STATE

; ship descriptor state check; internal branch at SHIP_DESCRIPTOR_STATE_CHECK:ED.
SHIP_DESCRIPTOR_STATE_CHECK:
        LD A,(HL)
        LD DE,$215F
        AND A
        JP P,SHIP_DESCRIPTOR_POSITION_UPDATE
        LD DE,$2181

; ship descriptor position update; internal branch at SHIP_DESCRIPTOR_POSITION_UPDATE:F8.
SHIP_DESCRIPTOR_POSITION_UPDATE:
        LD B,A
        INC HL
        ADD A,(HL)
        LD (HL),A
        LD A,B
        AND A
        LD A,(HL)
        JP P,SHIP_DESCRIPTOR_LIMIT_CHECK
        CP $01
        JP NC,SHIP_DESCRIPTOR_ROTATE_SHIFT

; Ship descriptor clear flag.
SHIP_DESCRIPTOR_CLEAR_FLAG:
        EX (SP),HL
        LD A,(HL)
        AND $BF
        LD (HL),A
        EX (SP),HL
        JP SHIP_DESCRIPTOR_ROTATE_SHIFT

; Ship descriptor limit check.
SHIP_DESCRIPTOR_LIMIT_CHECK:
        INC HL
        CP (HL)
        DEC HL
        JP NC,SHIP_DESCRIPTOR_CLEAR_FLAG

; Ship descriptor rotate shift.
SHIP_DESCRIPTOR_ROTATE_SHIFT:
        LD A,(HL)
        RRCA
        RRCA
        RRCA
        AND $1F
        ADD A,E
        LD E,A
        EX (SP),HL
        LD A,(HL)
        EX (SP),HL
        AND $07
        LD B,A
        INC HL
        LD A,(HL)
        CPL
        INC A
        RRCA
        RRCA
        RRCA
        AND $07
        ADD A,$03
        EX DE,HL

; Ship descriptor fill loop.
SHIP_DESCRIPTOR_FILL_LOOP:
        LD (HL),B
        INC HL
        DEC A
        JP NZ,SHIP_DESCRIPTOR_FILL_LOOP
        EX DE,HL

; Ship descriptor toggle state.
SHIP_DESCRIPTOR_TOGGLE_STATE:
        LD DE,$202F
        LD A,(DE)
        CPL
        LD (DE),A
        JP NZ,SHIP_DESCRIPTOR_RETURN_CARRY
        INC HL
        LD A,(HL)
        INC HL
        ADD A,(HL)
        LD (HL),A
        INC HL
        CP (HL)

; Ship descriptor return carry.
SHIP_DESCRIPTOR_RETURN_CARRY:
        POP HL
        SCF
        RET NZ
        LD A,(HL)
        AND $BF
        LD (HL),A
        SCF
        RET

; Advance and test torpedo or mine descriptor.
UPDATE_PROJECTILE_DESCRIPTOR:
        LD A,(HL)
        AND A
        RET P
        PUSH HL
        INC HL
        INC HL
        LD C,(HL)
        INC HL
        INC HL
        LD A,(HL)
        INC HL
        LD B,(HL)
        ADD A,B
        LD (HL),A
        LD A,B
        CP $C0
        JP NC,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        CP $30
        JP NC,PROJECTILE_DESCRIPTOR_LIMIT_CHECK
        LD A,($2024)
        AND A
        JP Z,PROJECTILE_DESCRIPTOR_LIMIT_CHECK
        INC A
        INC A
        LD ($2024),A

; Projectile descriptor limit check.
PROJECTILE_DESCRIPTOR_LIMIT_CHECK:
        LD A,(HL)
        INC HL
        CP (HL)
        JP NC,PROJECTILE_DESCRIPTOR_SHIFT_CHECK
        LD A,$C0
        ADD A,(HL)
        LD (HL),A
        DEC HL
        DEC HL
        INC (HL)
        INC (HL)
        LD A,(HL)
        INC HL
        INC HL
        INC HL
        JP Z,PROJECTILE_DESCRIPTOR_CLEAR_FLAG
        LD (HL),$88
        CP $FC
        JP Z,PROJECTILE_DESCRIPTOR_SHIFT_CHECK
        LD (HL),$98
        JP PROJECTILE_DESCRIPTOR_SHIFT_CHECK

; Projectile descriptor clear flag.
PROJECTILE_DESCRIPTOR_CLEAR_FLAG:
        EX (SP),HL
        LD A,(HL)
        AND $BF
        LD (HL),A
        EX (SP),HL

; Projectile descriptor shift check.
PROJECTILE_DESCRIPTOR_SHIFT_CHECK:
        LD DE,$2030
        LD A,(DE)
        AND A
        JP NZ,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        INC A
        LD (DE),A
        LD A,B
        AND $10
        JP Z,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        LD DE,$0007
        ADD HL,DE
        LD A,(HL)
        AND A
        JP NZ,PROJECTILE_DESCRIPTOR_RESET_FLAG
        ADD HL,DE
        LD A,B
        ADD A,E
        LD B,A
        AND $10
        JP Z,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        LD A,(HL)
        AND A
        JP Z,PROJECTILE_DESCRIPTOR_RETURN_CARRY

; Projectile descriptor reset flag.
PROJECTILE_DESCRIPTOR_RESET_FLAG:
        EX (SP),HL
        LD A,(HL)
        AND $BF
        LD (HL),A
        EX (SP),HL
        LD A,B
        SUB $40
        LD B,A
        JP C,PROJECTILE_DESCRIPTOR_SCAN_RESET
        LD HL,$21A1

; Projectile descriptor scan fields.
PROJECTILE_DESCRIPTOR_SCAN_FIELDS:
        INC HL
        INC HL
        LD A,(HL)
        AND A
        JP NZ,PROJECTILE_DESCRIPTOR_SCAN_FIELDS
        LD (HL),B
        INC HL
        LD (HL),C
        JP PROJECTILE_DESCRIPTOR_RETURN_CARRY

; Projectile descriptor scan reset.
PROJECTILE_DESCRIPTOR_SCAN_RESET:
        LD HL,$21BE

; Projectile descriptor scan next.
PROJECTILE_DESCRIPTOR_SCAN_NEXT:
        INC HL
        INC HL
        INC HL
        LD A,(HL)
        AND A
        JP NZ,PROJECTILE_DESCRIPTOR_SCAN_NEXT
        LD A,B
        ADD A,$20
        LD DE,$2160
        JP M,PROJECTILE_DESCRIPTOR_ROTATE_SHIFT
        LD DE,$2182

; Projectile descriptor rotate shift.
PROJECTILE_DESCRIPTOR_ROTATE_SHIFT:
        LD A,C
        RRCA
        RRCA
        RRCA
        AND $1F
        ADD A,E
        LD E,A
        LD A,(DE)
        AND A
        JP Z,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        LD (HL),A
        INC HL
        LD (HL),C
        INC HL
        LD (HL),B

; Projectile descriptor return carry.
PROJECTILE_DESCRIPTOR_RETURN_CARRY:
        SCF
        POP HL
        RET

; Clear active-object display state.
CLEAR_ACTIVE_OBJECT:
        LD A,(HL)
        AND A
        RET P
        AND $20
        RET Z
        CALL LOAD_OBJECT_DRAW_PARAMETERS
        EX DE,HL
        LD B,C

; Object clear setup.
OBJECT_CLEAR_SETUP:
        XOR A
        PUSH HL

; Object clear bytes loop.
OBJECT_CLEAR_BYTES_LOOP:
        LD (HL),A
        INC HL
        DEC C
        JP NZ,OBJECT_CLEAR_BYTES_LOOP
        LD DE,$0020
        POP HL
        ADD HL,DE
        LD C,B
        LD A,L
        AND $E0
        JP NZ,OBJECT_CLEAR_SETUP
        LD A,H
        RRA
        JP C,OBJECT_CLEAR_SETUP
        RET

; Select the next active object descriptor.
ADVANCE_OBJECT_CURSOR:
        LD HL,($2014)
        LD B,$0A
        LD A,L
        OR H
        JP NZ,OBJECT_CURSOR_STRIDE_SETUP
        LD HL,$2072

; Object cursor stride setup.
OBJECT_CURSOR_STRIDE_SETUP:
        LD DE,$000D

; Object cursor next record.
OBJECT_CURSOR_NEXT_RECORD:
        ADD HL,DE
        DEC B
        RET Z
        LD A,L
        CP $E7
        JP NZ,OBJECT_CURSOR_SAVE_ACTIVE
        LD HL,$207F

; Object cursor save active.
OBJECT_CURSOR_SAVE_ACTIVE:
        LD A,(HL)
        AND A
        JP P,OBJECT_CURSOR_NEXT_RECORD
        LD ($2014),HL
        INC HL
        LD A,(HL)
        INC HL
        ADD A,(HL)
        LD (HL),A
        RET

; Load drawing parameters from an object record.
LOAD_OBJECT_DRAW_PARAMETERS:
        LD DE,$0009
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        INC HL
        RET

; Update frame-related countdown state.
UPDATE_FRAME_TIMERS:
        LD A,($2020)
        AND A
        RET NZ
        LD B,A
        LD HL,$2003
        DEC (HL)
        JP NZ,FRAME_DECREMENT_STATE_2011
        LD (HL),$1E
        LD HL,$2002
        LD A,(HL)
        AND A
        JP Z,FRAME_DECREMENT_STATE_2010
        ADD A,$99
        DAA
        LD (HL),A
        JP NZ,FRAME_DECREMENT_STATE_2010
        LD B,$01

; frame decrement state 2010; internal branch at $0388.
FRAME_DECREMENT_STATE_2010:
        LD HL,$2010
        CALL DECREMENT_TIMER_IF_ACTIVE

; frame decrement state 2011; internal branch at $038E.
FRAME_DECREMENT_STATE_2011:
        LD HL,$2011
        CALL DECREMENT_TIMER_IF_ACTIVE
        LD HL,$2021
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC HL
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC HL
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC HL
        CALL DECREMENT_TIMER_IF_ACTIVE
        INC HL
        CALL DECREMENT_TIMER_IF_ACTIVE
        LD ($2020),A
        RET

; Decrement a nonzero countdown byte.
DECREMENT_TIMER_IF_ACTIVE:
        LD A,(HL)
        AND A
        JP Z,FRAME_ACCUMULATE_TIMER_FLAGS
        DEC (HL)
        JP NZ,FRAME_ACCUMULATE_TIMER_FLAGS
        SCF

; Frame accumulate timer flags.
FRAME_ACCUMULATE_TIMER_FLAGS:
        LD A,B
        RLA
        LD B,A
        RET

; Update wave/display pattern state.
UPDATE_WAVE_PATTERN:
        LD BC,$2027
        LD A,(BC)
        ADD A,$0A
        CP $1E
        JP NZ,WAVE_SAVE_POSITION
        XOR A

; Wave save position.
WAVE_SAVE_POSITION:
        LD (BC),A
        INC BC
        LD E,A
        LD D,$00
        LD HL,$0BF3
        ADD HL,DE
        EX DE,HL
        LD A,(BC)
        INC A
        AND $1F
        LD (BC),A
        LD HL,$27E0
        ADD A,L
        LD L,A
        LD BC,$0020

; Wave copy row bytes.
WAVE_COPY_ROW_BYTES:
        LD A,(DE)
        INC DE
        LD (HL),A
        ADD HL,BC
        LD A,L
        AND $E0
        CP $60
        JP NZ,WAVE_COPY_ROW_BYTES
        RET

; Convert numeric state for display.
CONVERT_DISPLAY_DIGITS:
        LD HL,$0000
        LD DE,$0000
        LD C,$02

; Display digit sum reset.
DISPLAY_DIGIT_SUM_RESET:
        XOR A

; Display digit sum loop.
DISPLAY_DIGIT_SUM_LOOP:
        ADD A,(HL)
        INC HL
        LD B,A
        LD A,C
        CP H
        LD A,B
        JP NZ,DISPLAY_DIGIT_SUM_LOOP
        PUSH HL
        LD HL,$0429
        ADD HL,DE
        CP (HL)
        LD A,$40
        JP Z,DISPLAY_STORE_DIGIT
        LD HL,$0432
        ADD HL,DE
        LD A,(HL)

; Display store digit.
DISPLAY_STORE_DIGIT:
        LD HL,$21E9
        ADD HL,DE
        LD (HL),A
        POP HL
        INC DE
        INC C
        INC C
        LD A,$12
        CP C
        JP NZ,DISPLAY_DIGIT_SUM_RESET
        LD HL,$21E9
        LD DE,$3008
        LD A,$08
        CALL RENDER_GAME_TEXT
        HALT

; Startup data/constants adjacent to native initialization.
STARTUP_BYTE_TABLE:
        DB $8D,$79,$00,$1F,$58,$6D,$EA,$C5,$2A,$48,$48,$47
        DB $47,$46,$46,$45,$45

; Initialize hardware and RAM before the game loop.
STARTUP_INITIALIZE:
        CALL INITIALIZE_GAME_STATE
        IN A,($02)
        AND $E0
        CP $E0
        CALL Z,CONVERT_DISPLAY_DIGITS
        LD HL,$2002
        LD A,$09
        LD B,$00

; Startup clear ram loop.
STARTUP_CLEAR_RAM_LOOP:
        LD (HL),B
        INC HL
        DEC A
        JP NZ,STARTUP_CLEAR_RAM_LOOP
        LD HL,$0929
        LD ($2000),HL
        EI
        LD HL,$0459
        PUSH HL

; The 8080 command interpreter reads RAM $2000 and dispatches indexed words.

; Fetch indexed game command; zero uses frame-control path.
GAME_COMMAND_DISPATCH:
        LD HL,($2000)
        LD A,(HL)
        AND A
        JP NZ,GAME_COMMAND_INDEX
        CALL CLEAR_OBJECT_RECORD
        CALL GAME_CHECK_STATE_2020
        CALL GAME_CHECK_STATE_202A
        LD A,($2002)
        AND A
        RET Z
        CALL OBJECT_SEARCH_START
        CALL POLL_PLAYER_INPUT
        JP GAME_TIME_SERVICE

; Index the 16-bit native handler-address table.
GAME_COMMAND_INDEX:
        INC HL
        EX DE,HL
        LD HL,$09E8
        RLCA
        LD C,A
        LD B,$00
        ADD HL,BC
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        JP (HL)

; Game-time service and threshold test.
GAME_TIME_SERVICE:
        LD A,($2003)
        CP $1D
        RET M
        LD BC,$2002
        LD DE,$21E9
        CALL OBJECT_EXTRACT_FIELD_BITS
        EX DE,HL
        CALL TEST_OBJECT_FLAGS
        INC HL
        LD (HL),$2C
        INC HL
        EX DE,HL
        LD BC,$202B
        CALL OBJECT_EXTRACT_FIELD_BITS
        EX DE,HL
        CALL TEST_OBJECT_FLAGS
        INC HL
        LD (HL),$30
        INC HL
        LD (HL),$30
        LD HL,$21E9
        LD DE,$3E2F
        LD A,$06
        JP RENDER_GAME_TEXT

; game check state 202a; internal branch at $04BF.
GAME_CHECK_STATE_202A:
        LD HL,$202A
        LD A,(HL)
        AND A
        RET Z
        LD (HL),$00
        LD HL,$09A6
        LD ($2000),HL
        RET

; game check state 2020; internal branch at $04CE.
GAME_CHECK_STATE_2020:
        LD HL,$2020
        LD A,(HL)
        AND A
        RET Z
        LD (HL),$00
        RRA
        CALL C,RESET_SOUND_OUTPUTS
        RRA
        CALL C,PROCESS_ACTIVE_GRAPHICS
        RRA
        CALL C,GAME_PROCESS_STATE_2026
        RRA
        CALL C,UPDATE_GAME_SOUND
        RRA
        CALL C,GAME_CHECK_STATE_202D
        RRA
        CALL C,ADVANCE_GAME_SCRIPT_CURSOR
        RRA
        CALL C,SELECT_FOLLOWUP_GAME_SCRIPT
        RRA
        CALL C,GAME_CHECK_STATE_202E
        RET

; game process state 2026; internal branch at $04F7.
GAME_PROCESS_STATE_2026:
        PUSH AF
        LD HL,$2026
        LD A,(HL)
        AND A
        JP Z,GAME_STATE_SERVICE_RETURN
        DEC (HL)
        LD A,$04
        OUT ($05),A
        LD A,$19
        LD ($2023),A
        LD A,$0F
        LD ($2025),A

; Game state service return.
GAME_STATE_SERVICE_RETURN:
        POP AF
        RET

; game check state 202e; internal branch at $0511.
GAME_CHECK_STATE_202E:
        LD HL,$202E
        LD A,(HL)
        AND A
        JP NZ,GAME_SELECT_RECORD_START
        LD (HL),$01
        LD A,($2007)
        RRCA
        AND $70
        JP Z,GAME_SELECT_RECORD_START
        ADD A,$09
        LD HL,$202B
        CP (HL)
        JP NC,GAME_SELECT_RECORD_START
        LD A,$20
        LD ($2002),A
        LD HL,$0F33
        LD DE,$3C03
        LD A,$0C
        JP RENDER_GAME_TEXT

; Game select record start.
GAME_SELECT_RECORD_START:
        LD HL,$20C9
        LD BC,$001E

; Game select record next.
GAME_SELECT_RECORD_NEXT:
        ADD HL,BC
        LD A,L
        CP $5F
        JP Z,SELECT_INITIAL_GAME_SCRIPT
        LD A,(HL)
        AND A
        JP P,GAME_SELECT_RECORD_NEXT
        XOR A
        LD ($2021),A
        LD ($202D),A
        LD A,$01
        LD ($2002),A
        RET

; Point the game-program cursor at the initial script.
SELECT_INITIAL_GAME_SCRIPT:
        LD HL,$0929
        LD ($2000),HL
        LD A,($202B)
        LD HL,$2006
        CP (HL)
        RET C
        LD (HL),A
        RET

; Select follow-up interpreted command stream.
SELECT_FOLLOWUP_GAME_SCRIPT:
        LD HL,$0963
        LD ($2000),HL
        RET

; Advance game-program cursor by one byte.
ADVANCE_GAME_SCRIPT_CURSOR:
        LD HL,($2000)
        INC HL
        LD ($2000),HL
        RET
        RET Z
        LD A,($2002)
        AND A
        RET Z
        LD A,($2021)
        AND A
        RET NZ
        LD HL,$202D
        LD A,(HL)
        AND $1F
        RET Z
        LD A,(HL)
        AND $0F
        RRA
        LD B,$20
        AND A
        JP Z,GAME_UPDATE_OUTPUT_LATCH
        LD B,$10

; Game update output latch.
GAME_UPDATE_OUTPUT_LATCH:
        OR B
        LD (HL),A
        OUT ($02),A
        LD HL,$2021
        LD (HL),$08
        AND $10
        JP NZ,GAME_SET_SOUND_TIMER
        LD (HL),$3C

; Game set sound timer.
GAME_SET_SOUND_TIMER:
        LD A,$02
        OUT ($05),A
        LD A,$0F
        LD ($2025),A
        LD HL,$20C9
        LD DE,$001E

; Game scan records.
GAME_SCAN_RECORDS:
        ADD HL,DE
        LD A,(HL)
        AND A
        JP M,GAME_SCAN_RECORDS
        LD DE,$0008
        ADD HL,DE
        LD (HL),$0E
        DEC HL
        LD (HL),$75
        DEC HL
        LD (HL),$9C
        DEC HL
        LD (HL),$E0
        DEC HL
        LD (HL),$FA
        DEC HL
        DEC HL
        LD DE,$0F5E
        EX DE,HL
        LD A,($2008)
        AND $1F
        LD C,A
        LD B,$00
        ADD HL,BC
        LD A,(HL)
        EX DE,HL
        LD (HL),A
        DEC HL
        LD (HL),$00
        DEC HL
        LD (HL),$C0
        RET

; game check state 202d; internal branch at $05E9.
GAME_CHECK_STATE_202D:
        PUSH AF
        LD HL,$202D
        LD A,(HL)
        AND $10
        JP NZ,GAME_STATE_RESTORE_ACC
        LD A,$1F
        OUT ($02),A
        LD (HL),A
        LD A,$08
        OUT ($05),A
        CALL UPDATE_SCORE_DIFFICULTY

; Game state restore acc.
GAME_STATE_RESTORE_ACC:
        POP AF
        RET

; Clear discrete sound output ports.
RESET_SOUND_OUTPUTS:
        PUSH AF
        XOR A
        OUT ($05),A
        OUT ($01),A
        LD A,($202D)
        OUT ($02),A
        POP AF
        RET

; Scan active graphic records.
PROCESS_ACTIVE_GRAPHICS:
        PUSH AF
        LD HL,$21F0

; Graphics scan active entry.
GRAPHICS_SCAN_ACTIVE_ENTRY:
        LD A,(HL)
        AND A
        JP Z,GRAPHICS_SCAN_RETURN
        LD (HL),$00
        INC HL
        LD D,A
        LD E,(HL)
        LD (HL),$00
        INC HL
        CP $2C
        LD BC,$0A03
        JP C,GRAPHICS_SCAN_NEXT_ENTRY
        LD BC,$2005

; Graphics scan next entry.
GRAPHICS_SCAN_NEXT_ENTRY:
        EX DE,HL
        CALL CLEAR_GRAPHIC_BLOCK
        EX DE,HL
        JP GRAPHICS_SCAN_ACTIVE_ENTRY

; Graphics scan return.
GRAPHICS_SCAN_RETURN:
        POP AF
        RET

; Update discrete sound settings.
UPDATE_GAME_SOUND:
        PUSH AF
        LD A,($2003)
        AND $0F
        OR $50
        LD ($2022),A
        LD BC,$2029
        LD A,(BC)
        INC A
        CP $07
        JP NZ,SOUND_STORE_RECORD_BYTE
        XOR A

; Sound store record byte.
SOUND_STORE_RECORD_BYTE:
        LD (BC),A
        LD HL,$0FDE
        ADD A,L
        LD L,A
        LD A,(HL)
        LD B,A
        CP $06
        JP NZ,SELECT_OBJECT_RECORD
        LD A,$04
        OUT ($05),A
        LD A,$19
        LD ($2023),A
        LD A,$02
        LD ($2026),A
        LD A,$0F
        LD ($2025),A
        LD A,B

; Select one object record using a fixed stride.
SELECT_OBJECT_RECORD:
        LD HL,$202C
        LD DE,$000D

; Object select next stride.
OBJECT_SELECT_NEXT_STRIDE:
        ADD HL,DE
        DEC A
        JP NZ,OBJECT_SELECT_NEXT_STRIDE
        LD A,B
        EX DE,HL
        LD HL,$201E
        LD A,(HL)
        INC (HL)
        LD HL,$0F7E
        RRA
        JP NC,OBJECT_INDEX_ROTATE
        LD HL,$0FAE
        LD A,B
        OR $10
        LD B,A

; Object index rotate.
OBJECT_INDEX_ROTATE:
        LD A,B
        DEC A
        RLCA
        RLCA
        RLCA
        AND $38
        ADD A,L
        LD L,A
        LD C,$08

; Copy bytes into an object record.
COPY_OBJECT_RECORD:
        LD A,(HL)
        INC HL
        LD (DE),A
        DEC DE
        DEC C
        JP NZ,COPY_OBJECT_RECORD
        LD A,B
        OR $C0
        LD (DE),A
        POP AF
        RET

; Clear a selected object record.
CLEAR_OBJECT_RECORD:
        LD HL,$21C1

; Object clear if active.
OBJECT_CLEAR_IF_ACTIVE:
        LD A,(HL)
        AND A
        RET Z
        LD (HL),$00
        INC HL
        LD D,(HL)
        PUSH HL
        LD HL,$2024
        LD BC,$000D

; Object offset accumulate.
OBJECT_OFFSET_ACCUMULATE:
        ADD HL,BC
        DEC A
        JP NZ,OBJECT_OFFSET_ACCUMULATE
        LD BC,$0008
        ADD HL,BC
        LD (HL),$0E
        DEC HL
        LD (HL),$55
        DEC HL
        DEC HL
        DEC HL
        LD (HL),$01
        DEC HL
        DEC HL
        LD (HL),D
        DEC HL
        LD (HL),$00
        DEC HL
        LD B,(HL)
        LD (HL),$E0
        LD A,($2002)
        AND A
        JP NZ,OBJECT_LOOKUP_INDEX
        POP HL
        RET

; Object lookup index.
OBJECT_LOOKUP_INDEX:
        LD A,B
        LD BC,$0F57
        AND $07
        ADD A,C
        LD C,A
        LD DE,$21E9
        CALL OBJECT_EXTRACT_FIELD_BITS
        LD A,$30
        LD (DE),A
        INC DE
        LD (DE),A
        LD A,(BC)
        LD HL,$202B
        ADD A,(HL)
        DAA
        LD (HL),A
        POP HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        INC HL
        PUSH HL
        LD A,B
        ADD A,$20
        LD HL,$09C2
        JP C,OBJECT_COORDINATE_SHIFT_LEFT
        LD HL,$09BA

; Object coordinate shift left.
OBJECT_COORDINATE_SHIFT_LEFT:
        LD A,C
        RLCA
        RLCA
        RLCA
        AND $07
        ADD A,L
        LD L,A
        LD A,(HL)
        OUT ($01),A
        LD A,$01
        OUT ($05),A
        LD A,$1E
        LD ($2025),A
        LD A,B
        LD D,$24
        ADD A,$20
        JP M,OBJECT_COORDINATE_SHIFT_RIGHT
        LD D,$28

; Object coordinate shift right.
OBJECT_COORDINATE_SHIFT_RIGHT:
        LD A,C
        RRCA
        RRCA
        RRCA
        AND $1F
        JP Z,OBJECT_COORDINATE_LIMIT
        DEC A

; Object coordinate limit.
OBJECT_COORDINATE_LIMIT:
        CP $1E
        JP NZ,OBJECT_SET_ACTIVE_COORDINATE
        DEC A

; Object set active coordinate.
OBJECT_SET_ACTIVE_COORDINATE:
        OR $A0
        LD E,A
        CALL SEARCH_ACTIVE_OBJECTS
        LD A,$2D
        LD ($2024),A
        LD HL,$21EA
        LD A,$03
        CALL RENDER_GAME_TEXT
        POP HL
        JP OBJECT_CLEAR_IF_ACTIVE

; Object search start.
OBJECT_SEARCH_START:
        LD HL,$21A3

; Object search next.
OBJECT_SEARCH_NEXT:
        LD A,(HL)
        AND A
        RET Z
        INC HL
        ADD A,$10
        RLCA
        RLCA
        RLCA
        AND $07
        LD DE,$2067
        LD BC,$000D
        EX DE,HL

; Object search advance offset.
OBJECT_SEARCH_ADVANCE_OFFSET:
        ADD HL,BC
        ADD HL,BC
        DEC A
        JP NZ,OBJECT_SEARCH_ADVANCE_OFFSET
        LD A,(DE)
        SUB $08
        SUB (HL)
        CP $EC
        JP NC,OBJECT_MARK_RECORD_INACTIVE
        ADD HL,BC

; Object mark record inactive.
OBJECT_MARK_RECORD_INACTIVE:
        DEC HL
        DEC HL
        LD (HL),$00
        EX DE,HL
        DEC HL
        LD A,(HL)
        ADD A,$30
        AND $F0
        LD D,A
        LD (HL),$00
        INC HL
        LD E,(HL)
        INC HL
        PUSH HL
        CALL BIT_SHIFT_SETUP
        LD A,E
        AND $1F
        JP Z,OBJECT_RESOLVE_SCAN_ENTRY
        DEC A
        JP Z,OBJECT_RESOLVE_SCAN_ENTRY

; Object adjust scan index.
OBJECT_ADJUST_SCAN_INDEX:
        DEC A
        CP $1C
        JP P,OBJECT_ADJUST_SCAN_INDEX

; Object resolve scan entry.
OBJECT_RESOLVE_SCAN_ENTRY:
        LD E,A
        CALL SEARCH_ACTIVE_OBJECTS
        LD B,D
        INC B
        INC B
        LD C,E
        INC C
        PUSH BC
        LD A,E
        ADD A,$60
        LD E,A
        PUSH DE
        LD B,D
        INC C
        PUSH BC
        LD A,$1E
        LD ($2025),A
        LD A,$0F
        LD ($2024),A
        LD A,$10
        OUT ($05),A
        LD A,E
        AND $02
        LD HL,$0F40
        ADD A,L
        LD L,A
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        POP DE
        LD A,(HL)
        INC HL
        CALL RENDER_GAME_TEXT
        POP DE
        LD A,(HL)
        INC HL
        CALL RENDER_GAME_TEXT
        POP DE
        LD HL,$0EB5
        LD A,$03
        CALL RENDER_GAME_TEXT
        POP HL
        JP OBJECT_SEARCH_NEXT

; Find a matching active object.
SEARCH_ACTIVE_OBJECTS:
        LD HL,$21F0

; Active object compare fields.
ACTIVE_OBJECT_COMPARE_FIELDS:
        LD A,(HL)
        INC HL
        OR (HL)
        INC HL
        JP NZ,ACTIVE_OBJECT_COMPARE_FIELDS
        DEC HL
        LD (HL),E
        DEC HL
        LD (HL),D
        RET

; Derive gameplay difficulty from score state.
UPDATE_SCORE_DIFFICULTY:
        LD A,($202B)
        CP $40
        JP C,SCORE_OBJECT_SCAN_SETUP
        LD A,$39

; Score object scan setup.
SCORE_OBJECT_SCAN_SETUP:
        LD ($202C),A
        LD HL,$207F
        LD DE,$5050

; Score object scan next.
SCORE_OBJECT_SCAN_NEXT:
        LD A,(HL)
        AND A
        JP M,SCORE_OBJECT_PROCESS_ACTIVE

; Score object update record.
SCORE_OBJECT_UPDATE_RECORD:
        LD BC,$0008
        ADD HL,BC
        LD (HL),$0E
        DEC HL
        LD (HL),$A3
        DEC HL
        DEC HL
        LD (HL),E
        DEC HL
        LD (HL),B
        DEC HL
        DEC HL
        LD (HL),D
        DEC HL
        LD (HL),$01
        DEC HL
        LD (HL),$80
        LD A,D
        ADD A,$51
        LD D,A
        RRA
        JP C,SCORE_OBJECT_NEXT_RECORD
        LD A,($202C)
        SUB $10
        RET M
        LD ($202C),A
        LD A,E
        ADD A,$20
        LD E,A

; Score object next record.
SCORE_OBJECT_NEXT_RECORD:
        LD BC,$000D
        ADD HL,BC
        JP SCORE_OBJECT_SCAN_NEXT

; Score object process active.
SCORE_OBJECT_PROCESS_ACTIVE:
        PUSH HL
        PUSH DE
        INC HL
        INC HL
        LD E,(HL)
        INC HL
        INC HL
        INC HL
        LD D,(HL)
        CALL BIT_SHIFT_SETUP
        EX DE,HL
        LD BC,$1002
        CALL CLEAR_GRAPHIC_BLOCK
        POP DE
        POP HL
        JP SCORE_OBJECT_UPDATE_RECORD
        RET Z
        XOR A
        LD ($2006),A
        LD A,($2010)
        AND A
        RET Z
        LD HL,$21E9
        PUSH HL
        LD BC,$0430

; Score fill bytes loop.
SCORE_FILL_BYTES_LOOP:
        LD (HL),C
        INC HL
        DEC B
        JP NZ,SCORE_FILL_BYTES_LOOP
        POP HL
        LD DE,$3E25
        LD A,$04
        JP RENDER_GAME_TEXT

; Command $0C: advance the script pointer and derive timer phase.
CMD_ADVANCE_AND_SET_TIMER_PHASE:
        EX DE,HL
        LD ($2000),HL
        LD A,($2003)
        AND $07
        CP $07
        JP NZ,SCORE_SAVE_RESULT
        XOR A

; Score save result.
SCORE_SAVE_RESULT:
        LD ($2029),A
        RET

; Reset game state and script pointer.
RESET_GAME_STATE:
        DI
        EX DE,HL
        LD ($2000),HL
        XOR A
        OUT ($02),A
        OUT ($05),A
        OUT ($01),A
        POP HL
        LD BC,$0000
        LD DE,$0000
        LD A,$10
        LD SP,$4010

; Game reset copy loop.
GAME_RESET_COPY_LOOP:
        PUSH BC
        INC DE
        CP D
        JP NZ,GAME_RESET_COPY_LOOP
        LD SP,$2400
        JP (HL)

; Initialize RAM and launch the main control path.
INITIALIZE_GAME_STATE:
        POP HL
        LD ($2009),HL
        CALL RESET_GAME_STATE
        LD HL,($2009)
        PUSH HL
        LD HL,$0F04
        LD DE,$27E0
        LD A,$20
        JP RENDER_GAME_TEXT

; Poll player input port.
POLL_PLAYER_INPUT:
        IN A,($01)
        LD B,A
        IN A,($01)
        LD HL,$2008
        LD DE,$09DA
        CP B
        CALL Z,HANDLE_INPUT_CHANGE

; Command $01: no-op/return. Also referenced by input-service vectors.
CMD_RETURN:
        RET
        RET Z
        LD A,$20
        OUT ($05),A
        LD A,$0F
        LD ($2025),A
        LD A,($2007)
        LD B,A
        LD HL,$2004
        INC (HL)
        AND $04
        JP Z,INPUT_STORE_EDGE_STATE
        LD A,(HL)
        RRCA
        RET C

; Input store edge state.
INPUT_STORE_EDGE_STATE:
        LD (HL),$00
        INC HL
        INC (HL)
        LD A,B
        AND $08
        JP Z,INPUT_MASK_CURRENT_NIBBLE
        INC (HL)
        LD A,B
        AND $04
        JP Z,INPUT_MASK_CURRENT_NIBBLE
        INC (HL)

; Input mask current nibble.
INPUT_MASK_CURRENT_NIBBLE:
        LD A,(HL)
        AND $0F
        LD (HL),A
        RET Z
        LD A,($2002)
        AND A
        RET NZ
        LD HL,$2005
        LD A,(HL)
        AND A
        JP Z,CHECK_COIN_INPUT

; Input decrement timer.
INPUT_DECREMENT_TIMER:
        DEC (HL)
        IN A,($01)
        RLCA
        RLCA
        AND $03
        LD DE,$0F54
        ADD A,E
        LD E,A
        LD A,(DE)
        LD ($2002),A
        LD ($202A),A
        RET

; Examine coin-input bits.
CHECK_COIN_INPUT:
        LD A,($2007)
        AND $0C
        CP $0C
        RET NZ
        DEC HL
        LD A,(HL)
        AND A
        RET Z
        JP INPUT_DECREMENT_TIMER

; Initial game command stream ($0929).
GAME_SCRIPT_STREAMS:
        DB $04,$01,$B8,$0E,$30,$3E,$09,$05,$20,$33,$38,$E6
        DB $0E,$F1,$0E,$04,$1A,$CC,$0E,$02,$3C,$0A,$06,$20
        DB $E9,$21,$25,$3E,$0A,$2B,$20,$E9,$21,$35,$3E,$02
        DB $0F,$04,$09,$C3,$0E,$0B,$2C,$01,$1E,$00,$04,$09
        DB $B8,$0E,$0B,$2C,$01,$1E,$00,$06,$4E,$09

; Second command stream, selected at $056C ($0963).
GAME_SCRIPT_SECONDARY:
        DB $03,$04,$08,$FC,$0E,$0C,$2C,$04,$0A,$CC,$0E,$02
        DB $3C,$0A,$06,$20,$E9,$21,$25,$3E,$09,$05,$20,$33
        DB $38,$E6,$0E,$F1,$0E,$01,$5A,$00,$08,$09,$60,$20
        DB $EB,$0D,$20,$15,$00,$E0,$00,$01,$C4,$01,$5A,$00
        DB $08,$09,$EF,$20,$75,$0E,$9C,$E0,$FA,$00,$A8,$00
        DB $C0,$01,$B4,$00,$06,$63,$09

; Script and inline operand continuation ($09A6).
GAME_SCRIPT_AUXILIARY:
        DB $01,$0F,$00,$03,$04,$09,$29,$0F,$0E,$3C,$07,$28
        DB $22,$20,$07,$0A,$21,$20,$0B

; Nine original packed input-code values ($09B9).
PLAYER_INPUT_CODES_A:
        DB $00,$48,$44,$42,$41,$88,$84,$82,$81

; Eight additional packed input-code values ($09C2).
PLAYER_INPUT_CODES_B:
        DB $18,$14,$12,$11,$28,$24,$22,$21

; Fifteen little-endian native address entries, $09CA–$09E7.
; This is pointer data, not an input debounce routine.
GAME_SERVICE_VECTOR_TABLE:
        DW $08C8
        DW $08F8
        DW $08C7
        DW $08C7
        DW $084D
        DW $08C7
        DW $08C7
        DW $08C7
GAME_SERVICE_VECTOR_SUBTABLE:
        DW $08C7
        DW $08C7
        DW $08C7
        DW $08C7
        DW $08C7
        DW $057B
        DW $08C7

; Indexed 16-bit native handler addresses, little endian.
; Twelve 16-bit native handler vectors indexed by nonzero commands $01–$0C.
GAME_COMMAND_HANDLER_TABLE:
        DW CMD_RETURN                        ; $01  RET; no operation
        DW SCRIPT_STORE_STATE_2011           ; $02  Store inline byte at RAM $2011
        DW SCRIPT_STORE_STATE_2010           ; $03  Store inline byte at RAM $2010
        DW INITIALIZE_GAME_STATE             ; $04  Reset and draw start screen
        DW CMD_RENDER_TEXT                   ; $05  Render inline text specification
        DW CMD_READ_HARDWARE_PORT            ; $06  Execute generated IN port stub
        DW SCRIPT_JUMP_ABSOLUTE              ; $07  Jump to inline script address
        DW CMD_COPY_POINTED_BYTE             ; $08  Copy pointed byte to RAM
        DW CMD_COPY_INLINE_BYTES_REVERSED    ; $09  Copy inline bytes in reverse order
        DW CMD_SELECT_AND_RENDER_TEXT        ; $0A  Select and render a message
        DW CMD_RENDER_SCORE                  ; $0B  Format and render score
        DW CMD_ADVANCE_AND_SET_TIMER_PHASE   ; $0C  Update timer-phase state

; Set up bit-shift operands.
BIT_SHIFT_SETUP:
        LD A,E
        AND $07
        LD C,A
        LD B,$03

; Shift setup next bit.
SHIFT_SETUP_NEXT_BIT:
        XOR A
        LD A,D
        RRA
        LD D,A
        LD A,E
        RRA
        LD E,A
        DEC B
        JP NZ,SHIFT_SETUP_NEXT_BIT
        LD A,D
        ADD A,$24
        LD D,A
        RET

; Copy object data to destination.
COPY_OBJECT_BYTES:
        PUSH AF
        LD A,(HL)
        LD (BC),A
        INC BC
        EX DE,HL
        OR (HL)
        INC HL
        LD (DE),A
        POP AF
        PUSH HL
        LD HL,$0020
        ADD HL,DE
        POP DE
        DEC A
        JP NZ,COPY_OBJECT_BYTES
        RET

; Copy rectangular graphics bytes.
COPY_GRAPHIC_BLOCK:
        PUSH BC
        PUSH HL

; Graphic copy byte loop.
GRAPHIC_COPY_BYTE_LOOP:
        LD A,(DE)
        INC DE
        LD (HL),A
        INC HL
        DEC C
        JP NZ,GRAPHIC_COPY_BYTE_LOOP
        POP HL
        LD BC,$0020
        ADD HL,BC
        POP BC
        DEC B
        JP NZ,COPY_GRAPHIC_BLOCK
        RET

; Clear rectangular graphics bytes.
CLEAR_GRAPHIC_BLOCK:
        XOR A

; Graphic clear row begin.
GRAPHIC_CLEAR_ROW_BEGIN:
        PUSH BC
        PUSH HL

; Graphic clear byte loop.
GRAPHIC_CLEAR_BYTE_LOOP:
        LD (HL),A
        INC HL
        DEC C
        JP NZ,GRAPHIC_CLEAR_BYTE_LOOP
        POP HL
        LD BC,$0020
        ADD HL,BC
        POP BC
        DEC B
        JP NZ,GRAPHIC_CLEAR_ROW_BEGIN
        RET

; Command $0B: convert a BCD field and render a four-character score.
CMD_RENDER_SCORE:
        EX DE,HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        DEC HL
        CALL OBJECT_EXTRACT_FIELD_BITS
        EX DE,HL
        CALL TEST_OBJECT_FLAGS
        INC HL
        EX DE,HL
        LD A,$30
        LD (DE),A
        INC DE
        LD (DE),A
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH DE
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD ($2000),HL
        POP HL
        LD A,$04
        JP RENDER_GAME_TEXT

; Test object flag bits.
TEST_OBJECT_FLAGS:
        DEC HL
        LD A,(HL)
        AND $40
        RET Z
        LD (HL),$30
        RET

; Object extract field bits.
OBJECT_EXTRACT_FIELD_BITS:
        LD A,(BC)
        RRA
        RRA
        RRA
        RRA
        AND $0F
        JP NZ,CONVERT_SCORE_TO_DIGITS
        LD A,$10

; Convert score digits to display codes.
CONVERT_SCORE_TO_DIGITS:
        ADD A,$30
        LD (DE),A
        INC DE
        LD A,(BC)
        AND $0F
        JP NZ,SCORE_STORE_SECOND_DIGIT
        LD A,$10

; Score store second digit.
SCORE_STORE_SECOND_DIGIT:
        ADD A,$30
        LD (DE),A
        INC DE
        RET

; Command $09: copy a counted inline byte sequence to a destination in reverse order.
CMD_COPY_INLINE_BYTES_REVERSED:
        EX DE,HL
        LD B,(HL)
        INC HL
        DEC B
        DEC B
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD C,(HL)
        INC HL
        LD A,(HL)
        INC HL
        LD (DE),A
        DEC DE
        LD A,C
        LD (DE),A
        DEC DE

; Text copy buffer byte.
TEXT_COPY_BUFFER_BYTE:
        LD A,(HL)
        INC HL
        LD (DE),A
        DEC DE
        DEC B
        JP NZ,TEXT_COPY_BUFFER_BYTE
        LD ($2000),HL
        RET

; Command $0A: select and render one of two encoded message addresses.
CMD_SELECT_AND_RENDER_TEXT:
        EX DE,HL
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD A,(DE)
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH DE
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH DE
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD ($2000),HL
        EX DE,HL
        AND A
        JP Z,TEXT_RETURN_TO_HANDLER
        EX (SP),HL

; Text return to handler.
TEXT_RETURN_TO_HANDLER:
        POP HL
        POP DE
        LD A,$0B
        JP RENDER_GAME_TEXT

; Script read inline address.
SCRIPT_READ_INLINE_ADDRESS:
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        RET

; Command $08: copy the byte at DE to an inline 16-bit RAM destination.
CMD_COPY_POINTED_BYTE:
        LD A,(DE)
        INC DE
        EX DE,HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        INC HL
        LD ($2000),HL
        LD (BC),A
        RET

; Command $06: construct and execute an IN port / RET stub in RAM.
CMD_READ_HARDWARE_PORT:
        EX DE,HL
        LD B,(HL)
        INC HL
        LD C,(HL)
        INC HL
        LD A,(HL)
        INC HL
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD ($2000),HL
        EX DE,HL
        LD (HL),$DB
        INC HL
        LD (HL),C
        INC HL
        LD (HL),$C9
        DEC HL
        DEC HL
        JP (HL)

; Handle a change on an input bit.
HANDLE_INPUT_CHANGE:
        XOR (HL)
        RET Z
        LD C,A
        LD B,$01

; Input scan next bit.
INPUT_SCAN_NEXT_BIT:
        LD A,C
        RRCA
        JP C,INPUT_TOGGLE_SELECTED_BIT
        LD C,A
        LD A,B
        RLCA
        LD B,A
        INC DE
        INC DE
        JP INPUT_SCAN_NEXT_BIT

; Input toggle selected bit.
INPUT_TOGGLE_SELECTED_BIT:
        LD A,B
        XOR (HL)
        LD (HL),A
        AND B
        EX DE,HL
        LD C,(HL)
        INC HL
        LD H,(HL)
        LD L,C
        JP (HL)

; Command $05: read inline text source, screen address and length, then render.
CMD_RENDER_TEXT:
        EX DE,HL
        LD A,(HL)
        INC HL
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH DE
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD ($2000),HL
        POP HL

; Render an encoded text stream.
RENDER_GAME_TEXT:
        PUSH AF

; Text read encoded character.
TEXT_READ_ENCODED_CHARACTER:
        LD A,(HL)
        INC HL
        SUB $30
        JP P,SELECT_CHARACTER_GLYPH
        LD B,A

; Text advance column.
TEXT_ADVANCE_COLUMN:
        INC E
        LD A,E
        AND $1F
        JP NZ,TEXT_ADVANCE_ROW
        INC D
        INC D

; Text advance row.
TEXT_ADVANCE_ROW:
        INC B
        JP NZ,TEXT_ADVANCE_COLUMN
        JP TEXT_READ_ENCODED_CHARACTER

; Locate the character glyph bitmap.
SELECT_CHARACTER_GLYPH:
        PUSH HL
        PUSH DE
        LD HL,$0B8F
        JP Z,COPY_CHARACTER_GLYPH
        LD BC,$000A

; Text find glyph offset.
TEXT_FIND_GLYPH_OFFSET:
        ADD HL,BC
        DEC A
        JP NZ,TEXT_FIND_GLYPH_OFFSET

; Copy the character glyph to video RAM.
COPY_CHARACTER_GLYPH:
        EX DE,HL
        LD BC,$0020
        LD A,$0A

; Text draw glyph row.
TEXT_DRAW_GLYPH_ROW:
        PUSH AF
        LD A,(DE)
        INC DE
        LD (HL),A
        ADD HL,BC
        POP AF
        DEC A
        JP NZ,TEXT_DRAW_GLYPH_ROW
        POP DE
        POP HL
        INC DE
        POP AF
        DEC A
        JP NZ,RENDER_GAME_TEXT
        RET

; Store next inline script byte at $2010.
SCRIPT_STORE_STATE_2010:
        EX DE,HL
        LD A,(HL)
        INC HL
        LD ($2000),HL
        LD ($2010),A
        RET

; Store next inline script byte at $2011.
SCRIPT_STORE_STATE_2011:
        EX DE,HL
        LD A,(HL)
        INC HL
        LD ($2000),HL
        LD ($2011),A
        RET

; Load little-endian inline jump target into script pointer.
SCRIPT_JUMP_ABSOLUTE:
        EX DE,HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        LD ($2000),HL
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

; Thirteen graphic bytes immediately following the ten numeric 8x10 glyphs.
NUMERIC_FONT_TRAILER:
        DB $0C  ; ....##..
        DB $93  ; #..#..##
        DB $60  ; .##.....
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $60  ; .##.....
        DB $99  ; #..##..#
        DB $06  ; .....##.

; ROM device sw0044.e — SHA-1 bd345dd72fed8ce15da76c381782b025f71b006f

; Raster/control bytes preceding uppercase glyph A at $0C39.
GRAPHICS_ASSET_ROM:
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $30  ; ..##....
        DB $CD  ; ##..##.#
        DB $02  ; ......#.
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $02  ; ......#.
        DB $C0  ; ##......
        DB $78  ; .####...
        DB $E0  ; ###.....
        DB $80  ; #.......
        DB $F0  ; ####....
        DB $01  ; .......#
        DB $C0  ; ##......
        DB $F0  ; ####....
        DB $7C  ; .#####..
        DB $08  ; ....#...
        DB $1C  ; ...###..
        DB $3E  ; ..#####.
        DB $7F  ; .#######
        DB $FF  ; ########
        DB $FF  ; ########
        DB $BF  ; #.######
        DB $1F  ; ...#####
        DB $02  ; ......#.
        DB $40  ; .#......
        DB $02  ; ......#.
        DB $80  ; #.......
        DB $78  ; .####...
        DB $1E  ; ...####.
        DB $07  ; .....###
        DB $01  ; .......#
        DB $7C  ; .#####..
        DB $F8  ; #####...
        DB $0C  ; ....##..
        DB $10  ; ...#....
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........

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

; Six ship graphic records selected by $064A-$06A3, followed by smaller graphics.
; Native code feeds these bytes through the MB14241 hardware shifter.
; Screen writes advance by the $20-byte video RAM column stride.
OBJECT_GRAPHICS:

; Five source bytes per strip, twelve strips; hardware shift sets displayed alignment.
SHIP_GRAPHIC_0:
        DB $05,$0C  ; width in bytes, height in rows
        DB $00,$00,$08,$00,$00
        DB $00,$00,$08,$00,$00
        DB $00,$60,$0E,$00,$00
        DB $00,$E0,$CE,$3F,$00
        DB $00,$E0,$DE,$03,$00
        DB $F8,$F7,$DF,$F7,$0F
        DB $80,$F7,$DF,$F7,$00
        DB $FF,$FF,$FF,$FF,$FF
        DB $FF,$FF,$FF,$FF,$7F
        DB $FF,$FF,$FF,$FF,$3F
        DB $FE,$FF,$FF,$FF,$1F
        DB $FE,$FF,$FF,$FF,$0F
; Four source bytes per strip, twelve strips; hardware shift sets displayed alignment.
SHIP_GRAPHIC_1:
        DB $04,$0C  ; width in bytes, height in rows
        DB $00,$00,$03,$00
        DB $00,$36,$03,$00
        DB $00,$36,$03,$00
        DB $02,$B6,$03,$00
        DB $87,$FF,$F3,$07
        DB $E2,$FF,$F7,$00
        DB $FF,$FF,$FF,$FF
        DB $FF,$FF,$FF,$7F
        DB $FF,$FF,$FF,$3F
        DB $FC,$FF,$FF,$1F
        DB $FC,$FF,$FF,$0F
        DB $F8,$FF,$FF,$07
; Five-byte rows, twelve lines. Raw graphics data; rendering polarity and mask semantics unverified.
SHIP_GRAPHIC_2:
        DB $05,$0C  ; width in bytes, height in rows
        DB $00,$00,$40,$00,$00
        DB $00,$00,$F0,$00,$00
        DB $00,$00,$F0,$00,$00
        DB $00,$80,$F0,$1E,$00
        DB $00,$00,$FB,$06,$00
        DB $FF,$FF,$FF,$FF,$FF
        DB $FC,$FF,$FF,$FF,$3F
        DB $FC,$FF,$FF,$FF,$1F
        DB $FC,$FF,$FF,$FF,$0F
        DB $F8,$FF,$FF,$FF,$07
        DB $F8,$FF,$FF,$FF,$03
        DB $F8,$FF,$FF,$FF,$03
; Four source bytes per strip, eleven strips; hardware shift sets displayed alignment.
SHIP_GRAPHIC_3:
        DB $04,$0B  ; width in bytes, height in rows
        DB $40,$00,$00,$02
        DB $40,$80,$00,$02
        DB $40,$00,$07,$02
        DB $40,$00,$07,$02
        DB $40,$F0,$07,$02
        DB $FC,$F0,$07,$F8
        DB $FC,$FF,$FF,$7F
        DB $FC,$FF,$FF,$3F
        DB $F8,$FF,$FF,$1F
        DB $F0,$FF,$FF,$0F
        DB $F0,$FF,$FF,$0F
; Four-byte rows, eleven lines. Raw graphics data; rendering polarity and mask semantics unverified.
SHIP_GRAPHIC_4:
        DB $04,$0B  ; width in bytes, height in rows
        DB $80,$00,$00,$00
        DB $00,$00,$00,$01
        DB $A0,$01,$00,$01
        DB $A0,$01,$00,$01
        DB $F0,$01,$00,$01
        DB $F8,$01,$00,$F9
        DB $F8,$FF,$FF,$7F
        DB $F0,$FF,$FF,$3F
        DB $F0,$FF,$FF,$1F
        DB $F0,$FF,$FF,$0F
        DB $E0,$FF,$FF,$0F
; Two source bytes per strip, six strips; hardware shift sets displayed alignment.
SHIP_GRAPHIC_5:
        DB $02,$06  ; width in bytes, height in rows
        DB $00,$03
        DB $10,$07
        DB $E0,$FF
        DB $FF,$7F
        DB $FF,$3F
        DB $FF,$1F
; 2 bytes per raster row by 15 rows, stored MSB-first per byte.
GRAPHIC_PATTERN_06:
        DB $02,$0F  ; width in bytes, height in rows
        DB $10,$00
        DB $30,$02
        DB $70,$01
        DB $FC,$00
        DB $F8,$11
        DB $F0,$3B
        DB $E0,$7F
        DB $C0,$3F
        DB $80,$1F
        DB $00,$3F
        DB $00,$1E
        DB $00,$04
        DB $00,$48
        DB $00,$F8
        DB $00,$F8
; 1 bytes per raster row by 17 rows, stored MSB-first per byte.
GRAPHIC_PATTERN_07:
        DB $01,$11  ; width in bytes, height in rows
        DB $10  ; ...#....
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $38  ; ..###...
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $38  ; ..###...

; 1 bytes per raster row by 14 rows, stored MSB-first per byte.
GRAPHIC_PATTERN_08:
        DB $01,$0E  ; width in bytes, height in rows
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $00  ; ........
        DB $18  ; ...##...

; 1 bytes per raster row by 9 rows, stored MSB-first per byte.
GRAPHIC_PATTERN_09:
        DB $01,$09  ; width in bytes, height in rows
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....
        DB $10  ; ...#....

; 1 bytes per raster row by 16 rows, stored MSB-first per byte.
GRAPHIC_PATTERN_10:
        DB $01,$10  ; width in bytes, height in rows
        DB $10  ; ...#....
        DB $BA  ; #.###.#.
        DB $7C  ; .#####..
        DB $FE  ; #######.
        DB $7C  ; .#####..
        DB $38  ; ..###...
        DB $54  ; .#.#.#..
        DB $10  ; ...#....
        DB $00  ; ........
        DB $10  ; ...#....
        DB $00  ; ........
        DB $08  ; ....#...
        DB $00  ; ........
        DB $00  ; ........
        DB $04  ; .....#..
        DB $00  ; ........

; Display-control data before encoded text ($0EB5).
DISPLAY_TEXT_PREFIX:
        DB $3D,$3E,$3F,$40,$40,$40,$40,$40,$40,$40,$40,$40
        DB $40,$40

; Encoded display text; $40 is the original game's spacing byte.
DISPLAY_TEXT_MESSAGES:

TEXT_GAME_OVER:
        DB "GAME",TEXT_SPACE,"OVER"

TEXT_HIGH_SCORE:
        DB "HIGH",TEXT_SPACE,"SCORE"

TEXT_SPACER:
        DB TEXT_SPACE,TEXT_SPACE,TEXT_SPACE,TEXT_SPACE,TEXT_SPACE,TEXT_SPACE

TEXT_YOUR_SCORE:
        DB "YOUR",TEXT_SPACE,"SCORE"

TEXT_INSERT_COIN:
        DB "INSERT",TEXT_SPACE,"COIN"

; The S at $0EFC completes BUTTONS and begins SEA WOLF.
TEXT_PUSH_BUTTON:
        DB "PUSH",TEXT_SPACE,"BUTTON"

TEXT_SEA_WOLF:
        DB "SEA",TEXT_SPACE,"WOLF"

; Repeating $3A–$3C display character indexes ($0F04).
DISPLAY_SYMBOL_PATTERN:
        DB $3A,$3B,$3C,$3B,$3C,$3A,$3B,$3C,$3A,$3C,$3B,$3C
        DB $3A,$3B,$3A,$3C,$3B,$3A,$3C,$3A,$3B,$3C,$3A,$3C
        DB $3B,$3C,$3A,$3B,$3C,$3A,$3B,$3C

; DISPLAY_LEGEND_TABLE ($0F24) - Embedded display words and game-status layout data
; -----------------------------------------------------------------------------
; Packed display legend followed by original control byte $16.
DISPLAY_LEGEND_TABLE:
        DB "BONUSTIME-SCOREEXTENDED",$16

; Time and display control values ($0F3C).
DISPLAY_LEGEND_LAYOUT:
        DB $54,$49,$4D,$45,$44,$0F,$4C,$0F,$01,$41,$04,$3D
        DB $5A,$2F,$50,$3F,$01,$41,$04,$3D,$57,$2F,$4D,$3F

; Lookup data used by object placement and shifting.
; Byte lookup from $0F54–$0F77.
BIT_ORDER_LOOKUP:
        DB $61,$71,$81,$91,$03,$03,$03,$01,$01,$07,$00,$08
        DB $18,$10,$38,$30,$20,$28,$78,$70,$60,$68,$40,$48
        DB $58,$50,$F8,$F0,$E0,$E8,$C0,$C8,$D8,$D0,$80,$88

; Six bytes preceding the eight-byte object descriptor array ($0F78-$0F7D).
; Do not interpret these bit patterns as a graphic pointer.
OBJECT_POSITION_LOOKUP_TAIL:
        DB $98,$90,$B8,$B0,$A0,$A8

; Twelve eight-byte object records, $0F7E-$0FDD.
; Each begins with a high-byte-first graphics address followed by six
; preserved descriptor fields. Field-level meanings require caller tracing.
OBJECT_DESCRIPTOR_TABLE:

; Record 1 at $F7E; graphics at $D3D.
OBJECT_RECORD_01:
        DB $0D,$3D  ; graphics pointer, high byte first
        DB $20,$14,$00,$D8,$00,$02  ; descriptor fields

; Record 2 at $F86; graphics at $D7B.
OBJECT_RECORD_02:
        DB $0D,$7B  ; graphics pointer, high byte first
        DB $20,$14,$00,$E0,$00,$02  ; descriptor fields

; Record 3 at $F8E; graphics at $DAD.
OBJECT_RECORD_03:
        DB $0D,$AD  ; graphics pointer, high byte first
        DB $20,$14,$00,$D8,$00,$02  ; descriptor fields

; Record 4 at $F96; graphics at $DEB.
OBJECT_RECORD_04:
        DB $0D,$EB  ; graphics pointer, high byte first
        DB $20,$15,$00,$E0,$00,$01  ; descriptor fields

; Record 5 at $F9E; graphics at $E19.
OBJECT_RECORD_05:
        DB $0E,$19  ; graphics pointer, high byte first
        DB $20,$15,$00,$E0,$00,$01  ; descriptor fields

; Record 6 at $FA6; graphics at $E47.
OBJECT_RECORD_06:
        DB $0E,$47  ; graphics pointer, high byte first
        DB $20,$1A,$00,$F0,$00,$03  ; descriptor fields

; Record 7 at $FAE; graphics at $D3D.
OBJECT_RECORD_07:
        DB $0D,$3D  ; graphics pointer, high byte first
        DB $40,$34,$00,$D8,$D8,$FE  ; descriptor fields

; Record 8 at $FB6; graphics at $D7B.
OBJECT_RECORD_08:
        DB $0D,$7B  ; graphics pointer, high byte first
        DB $40,$34,$00,$E0,$E0,$FE  ; descriptor fields

; Record 9 at $FBE; graphics at $DAD.
OBJECT_RECORD_09:
        DB $0D,$AD  ; graphics pointer, high byte first
        DB $40,$34,$00,$D8,$D8,$FE  ; descriptor fields

; Record 10 at $FC6; graphics at $DEB.
OBJECT_RECORD_10:
        DB $0D,$EB  ; graphics pointer, high byte first
        DB $40,$35,$00,$E0,$E0,$FF  ; descriptor fields

; Record 11 at $FCE; graphics at $E19.
OBJECT_RECORD_11:
        DB $0E,$19  ; graphics pointer, high byte first
        DB $40,$35,$00,$E0,$E0,$FF  ; descriptor fields

; Record 12 at $FD6; graphics at $E47.
OBJECT_RECORD_12:
        DB $0E,$47  ; graphics pointer, high byte first
        DB $40,$3A,$00,$F0,$F0,$FD  ; descriptor fields

; Seven trailing object selector/control bytes ($0FDE-$0FE4).
OBJECT_CONTROL_BYTES:
        DB $06,$04,$02,$06,$03,$05,$01

; Unused end-of-ROM fill, $0FE5–$0FFF (27 bytes of $FF).
ROM_END_FILL:
        DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

        END

; End original ROM image
