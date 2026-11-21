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
        JP nz,IRQ_ERASE_ACTIVE_SPRITE
        CALL UPDATE_WAVE_PATTERN
        CALL $012E
        LD hl,($2016)
        LD a,(hl)
        AND a
        JP p,IRQ_SET_UPDATE_PHASE
        AND $20
        JP z,IRQ_SET_UPDATE_PHASE
        CALL LOAD_OBJECT_DRAW_PARAMETERS
        DEC c
        EX de,hl
        CALL COPY_GRAPHIC_BLOCK
; Irq set update phase.
IRQ_SET_UPDATE_PHASE:
        LD a,$FF
; Irq save update phase.
IRQ_SAVE_UPDATE_PHASE:
        LD ($201F),a
        JP IRQ_INPUT_AND_RETURN
; Irq erase active sprite.
IRQ_ERASE_ACTIVE_SPRITE:
        LD hl,($2016)
        LD a,(hl)
        AND a
        JP p,IRQ_FINALIZE_SPRITE_PHASE
        AND $40
        JP nz,IRQ_DRAW_ACTIVE_SPRITE
        LD (hl),$00
        JP IRQ_FINALIZE_SPRITE_PHASE
; Irq draw active sprite.
IRQ_DRAW_ACTIVE_SPRITE:
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
; Irq finalize sprite phase.
IRQ_FINALIZE_SPRITE_PHASE:
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
; Irq clear temp buffer loop.
IRQ_CLEAR_TEMP_BUFFER_LOOP:
        LD (hl),a
        INC hl
        DEC b
        JP nz,IRQ_CLEAR_TEMP_BUFFER_LOOP
        LD hl,($2018)
        LD a,$03
; Irq ship group a loop.
IRQ_SHIP_GROUP_A_LOOP:
        PUSH af
        LD a,l
        CP $58
        JP nz,IRQ_SHIP_GROUP_A_TEST
; Irq ship group a wrap.
IRQ_SHIP_GROUP_A_WRAP:
        LD hl,$2031
; Irq ship group a test.
IRQ_SHIP_GROUP_A_TEST:
        OR h
        JP z,IRQ_SHIP_GROUP_A_WRAP
        PUSH hl
        CALL $01DE
        POP hl
        JP nc,IRQ_SHIP_GROUP_A_NEXT
        LD ($2018),hl
; Irq ship group a next.
IRQ_SHIP_GROUP_A_NEXT:
        LD de,$000D
        ADD hl,de
        POP af
        DEC a
        JP nz,IRQ_SHIP_GROUP_A_LOOP
        LD hl,($2018)
        CALL CLEAR_ACTIVE_OBJECT
        LD hl,($201A)
        LD a,$03
; Irq ship group b loop.
IRQ_SHIP_GROUP_B_LOOP:
        PUSH af
        LD a,l
        CP $7F
        JP nz,IRQ_SHIP_GROUP_B_TEST
; Irq ship group b wrap.
IRQ_SHIP_GROUP_B_WRAP:
        LD hl,$2058
; Irq ship group b test.
IRQ_SHIP_GROUP_B_TEST:
        OR h
        JP z,IRQ_SHIP_GROUP_B_WRAP
        PUSH hl
        CALL $01DE
        POP hl
        JP nc,IRQ_SHIP_GROUP_B_NEXT
        LD ($201A),hl
; Irq ship group b next.
IRQ_SHIP_GROUP_B_NEXT:
        LD de,$000D
        ADD hl,de
        POP af
        DEC a
        JP nz,IRQ_SHIP_GROUP_B_LOOP
        XOR a
        LD ($2030),a
        LD hl,($2016)
        LD a,$04
; Irq projectile group loop.
IRQ_PROJECTILE_GROUP_LOOP:
        PUSH af
        LD a,l
        CP $5F
        JP nz,IRQ_PROJECTILE_GROUP_TEST
; Irq projectile group wrap.
IRQ_PROJECTILE_GROUP_WRAP:
        LD hl,$20E7
; Irq projectile group test.
IRQ_PROJECTILE_GROUP_TEST:
        OR h
        JP z,IRQ_PROJECTILE_GROUP_WRAP
        PUSH hl
        CALL UPDATE_PROJECTILE_DESCRIPTOR
        POP hl
        JP nc,IRQ_PROJECTILE_GROUP_NEXT
        LD ($2016),hl
; irq projectile group next; internal branch at IRQ_PROJECTILE_GROUP_NEXT:0A.
IRQ_PROJECTILE_GROUP_NEXT:
        LD de,$001E
        ADD hl,de
        POP af
        DEC a
        JP nz,IRQ_PROJECTILE_GROUP_LOOP
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
        JP nz,SHIP_OBJECT_DRAW_PENDING
        LD (hl),$00
        RET
; ship object draw pending; internal branch at SHIP_OBJECT_DRAW_PENDING:45.
SHIP_OBJECT_DRAW_PENDING:
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
; sprite normal row loop; internal branch at SPRITE_NORMAL_ROW_LOOP:94.
SPRITE_NORMAL_ROW_LOOP:
        LD a,(de)
        INC de
        OUT ($03),a
        IN a,($03)
        LD (hl),a
        INC hl
        DEC c
        JP nz,SPRITE_NORMAL_ROW_LOOP
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
; sprite shifted row loop; internal branch at SPRITE_SHIFTED_ROW_LOOP:BA.
SPRITE_SHIFTED_ROW_LOOP:
        LD a,(de)
        INC de
        OUT ($03),a
        IN a,($00)
        LD (hl),a
        DEC hl
        DEC c
        JP nz,SPRITE_SHIFTED_ROW_LOOP
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
        JP nz,SHIP_DESCRIPTOR_STATE_CHECK
        INC hl
        INC hl
        JP SHIP_DESCRIPTOR_TOGGLE_STATE
; ship descriptor state check; internal branch at SHIP_DESCRIPTOR_STATE_CHECK:ED.
SHIP_DESCRIPTOR_STATE_CHECK:
        LD a,(hl)
        LD de,$215F
        AND a
        JP p,SHIP_DESCRIPTOR_POSITION_UPDATE
        LD de,$2181
; ship descriptor position update; internal branch at SHIP_DESCRIPTOR_POSITION_UPDATE:F8.
SHIP_DESCRIPTOR_POSITION_UPDATE:
        LD b,a
        INC hl
        ADD a,(hl)
        LD (hl),a
        LD a,b
        AND a
        LD a,(hl)
        JP p,SHIP_DESCRIPTOR_LIMIT_CHECK
        CP $01
        JP nc,SHIP_DESCRIPTOR_ROTATE_SHIFT
; Ship descriptor clear flag.
SHIP_DESCRIPTOR_CLEAR_FLAG:
        EX (sp),hl
        LD a,(hl)
        AND $BF
        LD (hl),a
        EX (sp),hl
        JP SHIP_DESCRIPTOR_ROTATE_SHIFT
; Ship descriptor limit check.
SHIP_DESCRIPTOR_LIMIT_CHECK:
        INC hl
        CP (hl)
        DEC hl
        JP nc,SHIP_DESCRIPTOR_CLEAR_FLAG
; Ship descriptor rotate shift.
SHIP_DESCRIPTOR_ROTATE_SHIFT:
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
; Ship descriptor fill loop.
SHIP_DESCRIPTOR_FILL_LOOP:
        LD (hl),b
        INC hl
        DEC a
        JP nz,SHIP_DESCRIPTOR_FILL_LOOP
        EX de,hl
; Ship descriptor toggle state.
SHIP_DESCRIPTOR_TOGGLE_STATE:
        LD de,$202F
        LD a,(de)
        CPL
        LD (de),a
        JP nz,SHIP_DESCRIPTOR_RETURN_CARRY
        INC hl
        LD a,(hl)
        INC hl
        ADD a,(hl)
        LD (hl),a
        INC hl
        CP (hl)
; Ship descriptor return carry.
SHIP_DESCRIPTOR_RETURN_CARRY:
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
        JP nc,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        CP $30
        JP nc,PROJECTILE_DESCRIPTOR_LIMIT_CHECK
        LD a,($2024)
        AND a
        JP z,PROJECTILE_DESCRIPTOR_LIMIT_CHECK
        INC a
        INC a
        LD ($2024),a
; Projectile descriptor limit check.
PROJECTILE_DESCRIPTOR_LIMIT_CHECK:
        LD a,(hl)
        INC hl
        CP (hl)
        JP nc,PROJECTILE_DESCRIPTOR_SHIFT_CHECK
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
        JP z,PROJECTILE_DESCRIPTOR_CLEAR_FLAG
        LD (hl),$88
        CP $FC
        JP z,PROJECTILE_DESCRIPTOR_SHIFT_CHECK
        LD (hl),$98
        JP PROJECTILE_DESCRIPTOR_SHIFT_CHECK
; Projectile descriptor clear flag.
PROJECTILE_DESCRIPTOR_CLEAR_FLAG:
        EX (sp),hl
        LD a,(hl)
        AND $BF
        LD (hl),a
        EX (sp),hl
; Projectile descriptor shift check.
PROJECTILE_DESCRIPTOR_SHIFT_CHECK:
        LD de,$2030
        LD a,(de)
        AND a
        JP nz,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        INC a
        LD (de),a
        LD a,b
        AND $10
        JP z,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        LD de,$0007
        ADD hl,de
        LD a,(hl)
        AND a
        JP nz,PROJECTILE_DESCRIPTOR_RESET_FLAG
        ADD hl,de
        LD a,b
        ADD a,e
        LD b,a
        AND $10
        JP z,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        LD a,(hl)
        AND a
        JP z,PROJECTILE_DESCRIPTOR_RETURN_CARRY
; Projectile descriptor reset flag.
PROJECTILE_DESCRIPTOR_RESET_FLAG:
        EX (sp),hl
        LD a,(hl)
        AND $BF
        LD (hl),a
        EX (sp),hl
        LD a,b
        SUB $40
        LD b,a
        JP c,PROJECTILE_DESCRIPTOR_SCAN_RESET
        LD hl,$21A1
; Projectile descriptor scan fields.
PROJECTILE_DESCRIPTOR_SCAN_FIELDS:
        INC hl
        INC hl
        LD a,(hl)
        AND a
        JP nz,PROJECTILE_DESCRIPTOR_SCAN_FIELDS
        LD (hl),b
        INC hl
        LD (hl),c
        JP PROJECTILE_DESCRIPTOR_RETURN_CARRY
; Projectile descriptor scan reset.
PROJECTILE_DESCRIPTOR_SCAN_RESET:
        LD hl,$21BE
; Projectile descriptor scan next.
PROJECTILE_DESCRIPTOR_SCAN_NEXT:
        INC hl
        INC hl
        INC hl
        LD a,(hl)
        AND a
        JP nz,PROJECTILE_DESCRIPTOR_SCAN_NEXT
        LD a,b
        ADD a,$20
        LD de,$2160
        JP m,PROJECTILE_DESCRIPTOR_ROTATE_SHIFT
        LD de,$2182
; Projectile descriptor rotate shift.
PROJECTILE_DESCRIPTOR_ROTATE_SHIFT:
        LD a,c
        RRCA
        RRCA
        RRCA
        AND $1F
        ADD a,e
        LD e,a
        LD a,(de)
        AND a
        JP z,PROJECTILE_DESCRIPTOR_RETURN_CARRY
        LD (hl),a
        INC hl
        LD (hl),c
        INC hl
        LD (hl),b
; Projectile descriptor return carry.
PROJECTILE_DESCRIPTOR_RETURN_CARRY:
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
; Object clear setup.
OBJECT_CLEAR_SETUP:
        XOR a
        PUSH hl
; Object clear bytes loop.
OBJECT_CLEAR_BYTES_LOOP:
        LD (hl),a
        INC hl
        DEC c
        JP nz,OBJECT_CLEAR_BYTES_LOOP
        LD de,$0020
        POP hl
        ADD hl,de
        LD c,b
        LD a,l
        AND $E0
        JP nz,OBJECT_CLEAR_SETUP
        LD a,h
        RRA
        JP c,OBJECT_CLEAR_SETUP
        RET

; Select the next active object descriptor.
ADVANCE_OBJECT_CURSOR:
        LD hl,($2014)
        LD b,$0A
        LD a,l
        OR h
        JP nz,OBJECT_CURSOR_STRIDE_SETUP
        LD hl,$2072
; Object cursor stride setup.
OBJECT_CURSOR_STRIDE_SETUP:
        LD de,$000D
; Object cursor next record.
OBJECT_CURSOR_NEXT_RECORD:
        ADD hl,de
        DEC b
        RET z
        LD a,l
        CP $E7
        JP nz,OBJECT_CURSOR_SAVE_ACTIVE
        LD hl,$207F
; Object cursor save active.
OBJECT_CURSOR_SAVE_ACTIVE:
        LD a,(hl)
        AND a
        JP p,OBJECT_CURSOR_NEXT_RECORD
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
        JP nz,FRAME_DECREMENT_STATE_2011
        LD (hl),$1E
        LD hl,$2002
        LD a,(hl)
        AND a
        JP z,FRAME_DECREMENT_STATE_2010
        ADD a,$99
        DAA
        LD (hl),a
        JP nz,FRAME_DECREMENT_STATE_2010
        LD b,$01
; frame decrement state 2010; internal branch at $0388.
FRAME_DECREMENT_STATE_2010:
        LD hl,$2010
        CALL DECREMENT_TIMER_IF_ACTIVE
; frame decrement state 2011; internal branch at $038E.
FRAME_DECREMENT_STATE_2011:
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
        JP z,FRAME_ACCUMULATE_TIMER_FLAGS
        DEC (hl)
        JP nz,FRAME_ACCUMULATE_TIMER_FLAGS
        SCF
; Frame accumulate timer flags.
FRAME_ACCUMULATE_TIMER_FLAGS:
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
        JP nz,WAVE_SAVE_POSITION
        XOR a
; Wave save position.
WAVE_SAVE_POSITION:
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
; Wave copy row bytes.
WAVE_COPY_ROW_BYTES:
        LD a,(de)
        INC de
        LD (hl),a
        ADD hl,bc
        LD a,l
        AND $E0
        CP $60
        JP nz,WAVE_COPY_ROW_BYTES
        RET

; Convert numeric state for display.
CONVERT_DISPLAY_DIGITS:
        LD hl,$0000
        LD de,$0000
        LD c,$02
; Display digit sum reset.
DISPLAY_DIGIT_SUM_RESET:
        XOR a
; Display digit sum loop.
DISPLAY_DIGIT_SUM_LOOP:
        ADD a,(hl)
        INC hl
        LD b,a
        LD a,c
        CP h
        LD a,b
        JP nz,DISPLAY_DIGIT_SUM_LOOP
        PUSH hl
        LD hl,$0429
        ADD hl,de
        CP (hl)
        LD a,$40
        JP z,DISPLAY_STORE_DIGIT
        LD hl,$0432
        ADD hl,de
        LD a,(hl)
; Display store digit.
DISPLAY_STORE_DIGIT:
        LD hl,$21E9
        ADD hl,de
        LD (hl),a
        POP hl
        INC de
        INC c
        INC c
        LD a,$12
        CP c
        JP nz,DISPLAY_DIGIT_SUM_RESET
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
; Startup clear ram loop.
STARTUP_CLEAR_RAM_LOOP:
        LD (hl),b
        INC hl
        DEC a
        JP nz,STARTUP_CLEAR_RAM_LOOP
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
        CALL GAME_CHECK_STATE_2020
        CALL GAME_CHECK_STATE_202A
        LD a,($2002)
        AND a
        RET z
        CALL OBJECT_SEARCH_START
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
        CALL OBJECT_EXTRACT_FIELD_BITS
        EX de,hl
        CALL TEST_OBJECT_FLAGS
        INC hl
        LD (hl),$2C
        INC hl
        EX de,hl
        LD bc,$202B
        CALL OBJECT_EXTRACT_FIELD_BITS
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
; game check state 202a; internal branch at $04BF.
GAME_CHECK_STATE_202A:
        LD hl,$202A
        LD a,(hl)
        AND a
        RET z
        LD (hl),$00
        LD hl,$09A6
        LD ($2000),hl
        RET
; game check state 2020; internal branch at $04CE.
GAME_CHECK_STATE_2020:
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
        CALL c,GAME_PROCESS_STATE_2026
        RRA
        CALL c,UPDATE_GAME_SOUND
        RRA
        CALL c,GAME_CHECK_STATE_202D
        RRA
        CALL c,ADVANCE_GAME_SCRIPT_CURSOR
        RRA
        CALL c,SELECT_FOLLOWUP_GAME_SCRIPT
        RRA
        CALL c,GAME_CHECK_STATE_202E
        RET
; game process state 2026; internal branch at $04F7.
GAME_PROCESS_STATE_2026:
        PUSH af
        LD hl,$2026
        LD a,(hl)
        AND a
        JP z,GAME_STATE_SERVICE_RETURN
        DEC (hl)
        LD a,$04
        OUT ($05),a
        LD a,$19
        LD ($2023),a
        LD a,$0F
        LD ($2025),a
; Game state service return.
GAME_STATE_SERVICE_RETURN:
        POP af
        RET
; game check state 202e; internal branch at $0511.
GAME_CHECK_STATE_202E:
        LD hl,$202E
        LD a,(hl)
        AND a
        JP nz,GAME_SELECT_RECORD_START
        LD (hl),$01
        LD a,($2007)
        RRCA
        AND $70
        JP z,GAME_SELECT_RECORD_START
        ADD a,$09
        LD hl,$202B
        CP (hl)
        JP nc,GAME_SELECT_RECORD_START
        LD a,$20
        LD ($2002),a
        LD hl,$0F33
        LD de,$3C03
        LD a,$0C
        JP RENDER_GAME_TEXT
; Game select record start.
GAME_SELECT_RECORD_START:
        LD hl,$20C9
        LD bc,$001E
; Game select record next.
GAME_SELECT_RECORD_NEXT:
        ADD hl,bc
        LD a,l
        CP $5F
        JP z,SELECT_INITIAL_GAME_SCRIPT
        LD a,(hl)
        AND a
        JP p,GAME_SELECT_RECORD_NEXT
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
        JP z,GAME_UPDATE_OUTPUT_LATCH
        LD b,$10
; Game update output latch.
GAME_UPDATE_OUTPUT_LATCH:
        OR b
        LD (hl),a
        OUT ($02),a
        LD hl,$2021
        LD (hl),$08
        AND $10
        JP nz,GAME_SET_SOUND_TIMER
        LD (hl),$3C
; Game set sound timer.
GAME_SET_SOUND_TIMER:
        LD a,$02
        OUT ($05),a
        LD a,$0F
        LD ($2025),a
        LD hl,$20C9
        LD de,$001E
; Game scan records.
GAME_SCAN_RECORDS:
        ADD hl,de
        LD a,(hl)
        AND a
        JP m,GAME_SCAN_RECORDS
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
; game check state 202d; internal branch at $05E9.
GAME_CHECK_STATE_202D:
        PUSH af
        LD hl,$202D
        LD a,(hl)
        AND $10
        JP nz,GAME_STATE_RESTORE_ACC
        LD a,$1F
        OUT ($02),a
        LD (hl),a
        LD a,$08
        OUT ($05),a
        CALL UPDATE_SCORE_DIFFICULTY
; Game state restore acc.
GAME_STATE_RESTORE_ACC:
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
; Graphics scan active entry.
GRAPHICS_SCAN_ACTIVE_ENTRY:
        LD a,(hl)
        AND a
        JP z,GRAPHICS_SCAN_RETURN
        LD (hl),$00
        INC hl
        LD d,a
        LD e,(hl)
        LD (hl),$00
        INC hl
        CP $2C
        LD bc,$0A03
        JP c,GRAPHICS_SCAN_NEXT_ENTRY
        LD bc,$2005
; Graphics scan next entry.
GRAPHICS_SCAN_NEXT_ENTRY:
        EX de,hl
        CALL CLEAR_GRAPHIC_BLOCK
        EX de,hl
        JP GRAPHICS_SCAN_ACTIVE_ENTRY
; Graphics scan return.
GRAPHICS_SCAN_RETURN:
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
        JP nz,SOUND_STORE_RECORD_BYTE
        XOR a
; Sound store record byte.
SOUND_STORE_RECORD_BYTE:
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
; Object select next stride.
OBJECT_SELECT_NEXT_STRIDE:
        ADD hl,de
        DEC a
        JP nz,OBJECT_SELECT_NEXT_STRIDE
        LD a,b
        EX de,hl
        LD hl,$201E
        LD a,(hl)
        INC (hl)
        LD hl,$0F7E
        RRA
        JP nc,OBJECT_INDEX_ROTATE
        LD hl,$0FAE
        LD a,b
        OR $10
        LD b,a
; Object index rotate.
OBJECT_INDEX_ROTATE:
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
; Object clear if active.
OBJECT_CLEAR_IF_ACTIVE:
        LD a,(hl)
        AND a
        RET z
        LD (hl),$00
        INC hl
        LD d,(hl)
        PUSH hl
        LD hl,$2024
        LD bc,$000D
; Object offset accumulate.
OBJECT_OFFSET_ACCUMULATE:
        ADD hl,bc
        DEC a
        JP nz,OBJECT_OFFSET_ACCUMULATE
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
        JP nz,OBJECT_LOOKUP_INDEX
        POP hl
        RET
; Object lookup index.
OBJECT_LOOKUP_INDEX:
        LD a,b
        LD bc,$0F57
        AND $07
        ADD a,c
        LD c,a
        LD de,$21E9
        CALL OBJECT_EXTRACT_FIELD_BITS
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
        JP c,OBJECT_COORDINATE_SHIFT_LEFT
        LD hl,$09BA
; Object coordinate shift left.
OBJECT_COORDINATE_SHIFT_LEFT:
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
        JP m,OBJECT_COORDINATE_SHIFT_RIGHT
        LD d,$28
; Object coordinate shift right.
OBJECT_COORDINATE_SHIFT_RIGHT:
        LD a,c
        RRCA
        RRCA
        RRCA
        AND $1F
        JP z,OBJECT_COORDINATE_LIMIT
        DEC a
; Object coordinate limit.
OBJECT_COORDINATE_LIMIT:
        CP $1E
        JP nz,OBJECT_SET_ACTIVE_COORDINATE
        DEC a
; Object set active coordinate.
OBJECT_SET_ACTIVE_COORDINATE:
        OR $A0
        LD e,a
        CALL SEARCH_ACTIVE_OBJECTS
        LD a,$2D
        LD ($2024),a
        LD hl,$21EA
        LD a,$03
        CALL RENDER_GAME_TEXT
        POP hl
        JP OBJECT_CLEAR_IF_ACTIVE
; Object search start.
OBJECT_SEARCH_START:
        LD hl,$21A3
; Object search next.
OBJECT_SEARCH_NEXT:
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
; Object search advance offset.
OBJECT_SEARCH_ADVANCE_OFFSET:
        ADD hl,bc
        ADD hl,bc
        DEC a
        JP nz,OBJECT_SEARCH_ADVANCE_OFFSET
        LD a,(de)
        SUB $08
        SUB (hl)
        CP $EC
        JP nc,OBJECT_MARK_RECORD_INACTIVE
        ADD hl,bc
; Object mark record inactive.
OBJECT_MARK_RECORD_INACTIVE:
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
        JP z,OBJECT_RESOLVE_SCAN_ENTRY
        DEC a
        JP z,OBJECT_RESOLVE_SCAN_ENTRY
; Object adjust scan index.
OBJECT_ADJUST_SCAN_INDEX:
        DEC a
        CP $1C
        JP p,OBJECT_ADJUST_SCAN_INDEX
; Object resolve scan entry.
OBJECT_RESOLVE_SCAN_ENTRY:
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
        JP OBJECT_SEARCH_NEXT

; Find a matching active object.
SEARCH_ACTIVE_OBJECTS:
        LD hl,$21F0
; Active object compare fields.
ACTIVE_OBJECT_COMPARE_FIELDS:
        LD a,(hl)
        INC hl
        OR (hl)
        INC hl
        JP nz,ACTIVE_OBJECT_COMPARE_FIELDS
        DEC hl
        LD (hl),e
        DEC hl
        LD (hl),d
        RET

; Derive gameplay difficulty from score state.
UPDATE_SCORE_DIFFICULTY:
        LD a,($202B)
        CP $40
        JP c,SCORE_OBJECT_SCAN_SETUP
        LD a,$39
; Score object scan setup.
SCORE_OBJECT_SCAN_SETUP:
        LD ($202C),a
        LD hl,$207F
        LD de,$5050
; Score object scan next.
SCORE_OBJECT_SCAN_NEXT:
        LD a,(hl)
        AND a
        JP m,SCORE_OBJECT_PROCESS_ACTIVE
; Score object update record.
SCORE_OBJECT_UPDATE_RECORD:
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
        JP c,SCORE_OBJECT_NEXT_RECORD
        LD a,($202C)
        SUB $10
        RET m
        LD ($202C),a
        LD a,e
        ADD a,$20
        LD e,a
; Score object next record.
SCORE_OBJECT_NEXT_RECORD:
        LD bc,$000D
        ADD hl,bc
        JP SCORE_OBJECT_SCAN_NEXT
; Score object process active.
SCORE_OBJECT_PROCESS_ACTIVE:
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
        JP SCORE_OBJECT_UPDATE_RECORD
        RET z
        XOR a
        LD ($2006),a
        LD a,($2010)
        AND a
        RET z
        LD hl,$21E9
        PUSH hl
        LD bc,$0430
; Score fill bytes loop.
SCORE_FILL_BYTES_LOOP:
        LD (hl),c
        INC hl
        DEC b
        JP nz,SCORE_FILL_BYTES_LOOP
        POP hl
        LD de,$3E25
        LD a,$04
        JP RENDER_GAME_TEXT
        EX de,hl
        LD ($2000),hl
        LD a,($2003)
        AND $07
        CP $07
        JP nz,SCORE_SAVE_RESULT
        XOR a
; Score save result.
SCORE_SAVE_RESULT:
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
; Game reset copy loop.
GAME_RESET_COPY_LOOP:
        PUSH bc
        INC de
        CP d
        JP nz,GAME_RESET_COPY_LOOP
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
        JP z,INPUT_STORE_EDGE_STATE
        LD a,(hl)
        RRCA
        RET c
; Input store edge state.
INPUT_STORE_EDGE_STATE:
        LD (hl),$00
        INC hl
        INC (hl)
        LD a,b
        AND $08
        JP z,INPUT_MASK_CURRENT_NIBBLE
        INC (hl)
        LD a,b
        AND $04
        JP z,INPUT_MASK_CURRENT_NIBBLE
        INC (hl)
; Input mask current nibble.
INPUT_MASK_CURRENT_NIBBLE:
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
; Input decrement timer.
INPUT_DECREMENT_TIMER:
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
        JP INPUT_DECREMENT_TIMER

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
; Shift setup next bit.
SHIFT_SETUP_NEXT_BIT:
        XOR a
        LD a,d
        RRA
        LD d,a
        LD a,e
        RRA
        LD e,a
        DEC b
        JP nz,SHIFT_SETUP_NEXT_BIT
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
; Graphic copy byte loop.
GRAPHIC_COPY_BYTE_LOOP:
        LD a,(de)
        INC de
        LD (hl),a
        INC hl
        DEC c
        JP nz,GRAPHIC_COPY_BYTE_LOOP
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
; Graphic clear row begin.
GRAPHIC_CLEAR_ROW_BEGIN:
        PUSH bc
        PUSH hl
; Graphic clear byte loop.
GRAPHIC_CLEAR_BYTE_LOOP:
        LD (hl),a
        INC hl
        DEC c
        JP nz,GRAPHIC_CLEAR_BYTE_LOOP
        POP hl
        LD bc,$0020
        ADD hl,bc
        POP bc
        DEC b
        JP nz,GRAPHIC_CLEAR_ROW_BEGIN
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
        CALL OBJECT_EXTRACT_FIELD_BITS
        EX de,hl
        CALL TEST_OBJECT_FLAGS
        INC hl
        EX de,hl
        LD a,$30
        LD (de),a
        INC de
        LD (de),a
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH de
        CALL SCRIPT_READ_INLINE_ADDRESS
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
; Object extract field bits.
OBJECT_EXTRACT_FIELD_BITS:
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
        JP nz,SCORE_STORE_SECOND_DIGIT
        LD a,$10
; Score store second digit.
SCORE_STORE_SECOND_DIGIT:
        ADD a,$30
        LD (de),a
        INC de
        RET
        EX de,hl
        LD b,(hl)
        INC hl
        DEC b
        DEC b
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD c,(hl)
        INC hl
        LD a,(hl)
        INC hl
        LD (de),a
        DEC de
        LD a,c
        LD (de),a
        DEC de
; Text copy buffer byte.
TEXT_COPY_BUFFER_BYTE:
        LD a,(hl)
        INC hl
        LD (de),a
        DEC de
        DEC b
        JP nz,TEXT_COPY_BUFFER_BYTE
        LD ($2000),hl
        RET
        EX de,hl
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD a,(de)
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH de
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH de
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD ($2000),hl
        EX de,hl
        AND a
        JP z,TEXT_RETURN_TO_HANDLER
        EX (sp),hl
; Text return to handler.
TEXT_RETURN_TO_HANDLER:
        POP hl
        POP de
        LD a,$0B
        JP RENDER_GAME_TEXT
; Script read inline address.
SCRIPT_READ_INLINE_ADDRESS:
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
        CALL SCRIPT_READ_INLINE_ADDRESS
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
; Input scan next bit.
INPUT_SCAN_NEXT_BIT:
        LD a,c
        RRCA
        JP c,INPUT_TOGGLE_SELECTED_BIT
        LD c,a
        LD a,b
        RLCA
        LD b,a
        INC de
        INC de
        JP INPUT_SCAN_NEXT_BIT
; Input toggle selected bit.
INPUT_TOGGLE_SELECTED_BIT:
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
        CALL SCRIPT_READ_INLINE_ADDRESS
        PUSH de
        CALL SCRIPT_READ_INLINE_ADDRESS
        LD ($2000),hl
        POP hl

; Render an encoded text stream.
RENDER_GAME_TEXT:
        PUSH af
; Text read encoded character.
TEXT_READ_ENCODED_CHARACTER:
        LD a,(hl)
        INC hl
        SUB $30
        JP p,SELECT_CHARACTER_GLYPH
        LD b,a
; Text advance column.
TEXT_ADVANCE_COLUMN:
        INC e
        LD a,e
        AND $1F
        JP nz,TEXT_ADVANCE_ROW
        INC d
        INC d
; Text advance row.
TEXT_ADVANCE_ROW:
        INC b
        JP nz,TEXT_ADVANCE_COLUMN
        JP TEXT_READ_ENCODED_CHARACTER

; Locate the character glyph bitmap.
SELECT_CHARACTER_GLYPH:
        PUSH hl
        PUSH de
        LD hl,$0B8F
        JP z,COPY_CHARACTER_GLYPH
        LD bc,$000A
; Text find glyph offset.
TEXT_FIND_GLYPH_OFFSET:
        ADD hl,bc
        DEC a
        JP nz,TEXT_FIND_GLYPH_OFFSET

; Copy the character glyph to video RAM.
COPY_CHARACTER_GLYPH:
        EX de,hl
        LD bc,$0020
        LD a,$0A
; Text draw glyph row.
TEXT_DRAW_GLYPH_ROW:
        PUSH af
        LD a,(de)
        INC de
        LD (hl),a
        ADD hl,bc
        POP af
        DEC a
        JP nz,TEXT_DRAW_GLYPH_ROW
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
