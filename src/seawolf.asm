; Sea Wolf (1976) - native Intel 8080 game program, written in zmac Z80 assembly syntax
; Version v20261121-0001
; Four original MAME ROMs sw0041.h / sw0042.g / sw0043.f / sw0044.e
; Assembles to one contiguous 4096-byte image at $0000-$0FFF.
; Byte authority: roms/original/seawolf.zip (MAME set 1).
; Disassembly cross-check: Mark Spaeth's seawolf_dz80.asm (2024), which
; includes later edits; mismatched instructions are retained as raw source
; bytes rather than accepting a patched implementation as original.
; The script interpreter is at $045E; vector table begins at $09E8.
; Original algorithmic code is expressed with assembly mnemonics where
; exact bytes match. DB preserves interpreter streams, font bitmaps,
; graphic objects and byte-exact exceptions. These are not all instructions.

PRGPTR EQU $2000
GTIME EQU $2002
CREDIT EQU $2005
PSCORE EQU $202B
INTERPRETER_DISPATCH EQU $045E
SCRIPT_VECTOR_TABLE EQU $09E8
VIDEO_RAM EQU $2400
SHIP_TABLE EQU $0F7E

        ORG $0000

; ROM 1: sw0041.h ($0000-$03FF)

; -----------------------------------------------------------------------------
; RESET_ENTRY ($0000) - Reset entry and 8080 stack setup
; -----------------------------------------------------------------------------
RESET_ENTRY:
        nop                          ; $0000 : 00
        nop                          ; $0001 : 00
        ld sp,$2400                  ; $0002 : 31 00 24 | Stack pointer
        jp $043A                     ; $0005 : C3 3A 04 | Startup jump

; -----------------------------------------------------------------------------
; IRQ_VECTOR_08 ($0008) - Interrupt vector: save registers and enter object update
; -----------------------------------------------------------------------------
IRQ_VECTOR_08:
        push hl                      ; $0008 : E5
        push de                      ; $0009 : D5
        push bc                      ; $000A : C5
        push af                      ; $000B : F5
        jp $007E                     ; $000C : C3 7E 00
        nop                          ; $000F : 00

; -----------------------------------------------------------------------------
; IRQ_VECTOR_10 ($0010) - Interrupt vector: save registers and choose update phase
; -----------------------------------------------------------------------------
IRQ_VECTOR_10:
        push hl                      ; $0010 : E5
        push de                      ; $0011 : D5
        push bc                      ; $0012 : C5
        push af                      ; $0013 : F5
        ld a,($201F)                 ; $0014 : 3A 1F 20
        and a                        ; $0017 : A7
        jp nz,$003E                  ; $0018 : C2 3E 00
        call $03BC                   ; $001B : CD BC 03 | Update wave
        call $012E                   ; $001E : CD 2E 01 | Update a sprite
        ld hl,($2016)                ; $0021 : 2A 16 20 | Sprite pointer
        ld a,(hl)                    ; $0024 : 7E
        and a                        ; $0025 : A7
        jp p,$0036                   ; $0026 : F2 36 00 | Jump if not active
        and $20                      ; $0029 : E6 20
        jp z,$0036                   ; $002B : CA 36 00 | Jump if ??
        call $035B                   ; $002E : CD 5B 03 | Load de, bc from ship data
        dec c                        ; $0031 : 0D
        ex de,hl                     ; $0032 : EB
        call $0A2A                   ; $0033 : CD 2A 0A | Draw b x c block from de at hl
L0036:
        ld a,$FF                     ; $0036 : 3E FF
L0038:
        ld ($201F),a                 ; $0038 : 32 1F 20
        jp $0069                     ; $003B : C3 69 00 | End of interrupt routine
L003E:
        ld hl,($2016)                ; $003E : 2A 16 20 | Sprite pointer
        ld a,(hl)                    ; $0041 : 7E
        and a                        ; $0042 : A7
        jp p,$0062                   ; $0043 : F2 62 00 | Jump if not active
        and $40                      ; $0046 : E6 40
        jp nz,$0050                  ; $0048 : C2 50 00 | Jump if not set to clear
        ld (hl),$00                  ; $004B : 36 00 | Clear sprite
        jp $0062                     ; $004D : C3 62 00
L0050:
        ld a,(hl)                    ; $0050 : 7E | Set bit 5
        or $20                       ; $0051 : F6 20
        ld (hl),a                    ; $0053 : 77
        call $0165                   ; $0054 : CD 65 01 | Update sprite
        ld a,b                       ; $0057 : 78
        push hl                      ; $0058 : E5
        ld hl,($201C)                ; $0059 : 2A 1C 20
        ld b,h                       ; $005C : 44
        ld c,l                       ; $005D : 4D
        pop hl                       ; $005E : E1
        call $0A16                   ; $005F : CD 16 0A
L0062:
        call $0368                   ; $0062 : CD 68 03
        xor a                        ; $0065 : AF
        ld ($201F),a                 ; $0066 : 32 1F 20

; -----------------------------------------------------------------------------
; IRQ_INPUT_AND_RETURN ($0069) - Sample input port and restore interrupt context
; -----------------------------------------------------------------------------
IRQ_INPUT_AND_RETURN:
        in a,($02)                   ; $0069 : DB 02 | IN1
        ld b,a                       ; $006B : 47
        in a,($02)                   ; $006C : DB 02 | IN1
        ld hl,$2007                  ; $006E : 21 07 20 | Last IN1?
        ld de,$09CA                  ; $0071 : 11 CA 09
        cp b                         ; $0074 : B8 | Bits changed?
        call z,$0B05                 ; $0075 : CC 05 0B
        pop af                       ; $0078 : F1
        pop bc                       ; $0079 : C1
        pop de                       ; $007A : D1
        pop hl                       ; $007B : E1
        ei                           ; $007C : FB
        ret                          ; $007D : C9

; -----------------------------------------------------------------------------
; IRQ_OBJECT_UPDATE ($007E) - Update RAM-backed object descriptors during interrupt processing
; -----------------------------------------------------------------------------
IRQ_OBJECT_UPDATE:
        ld a,($201F)                 ; $007E : 3A 1F 20
        and a                        ; $0081 : A7
        jp nz,$0119                  ; $0082 : C2 19 01
        call $03BC                   ; $0085 : CD BC 03 | Update wave
        ld hl,$215F                  ; $0088 : 21 5F 21
        ld b,$44                     ; $008B : 06 44
        xor a                        ; $008D : AF
L008E:
        ld (hl),a                    ; $008E : 77
        inc hl                       ; $008F : 23
        dec b                        ; $0090 : 05
        jp nz,$008E                  ; $0091 : C2 8E 00
        ld hl,($2018)                ; $0094 : 2A 18 20 | Sprite pointer 0
        ld a,$03                     ; $0097 : 3E 03 | Loop counter
L0099:
        push af                      ; $0099 : F5
        ld a,l                       ; $009A : 7D
        cp $58                       ; $009B : FE 58 | hl==$2058?
        jp nz,$00A3                  ; $009D : C2 A3 00
L00A0:
        ld hl,$2031                  ; $00A0 : 21 31 20 | Resets to $2031
L00A3:
        or h                         ; $00A3 : B4
        jp z,$00A0                   ; $00A4 : CA A0 00
        push hl                      ; $00A7 : E5
        call $01DE                   ; $00A8 : CD DE 01
        pop hl                       ; $00AB : E1
        jp nc,$00B2                  ; $00AC : D2 B2 00
        ld ($2018),hl                ; $00AF : 22 18 20 | Sprite pointer 0
L00B2:
        ld de,$000D                  ; $00B2 : 11 0D 00
        add hl,de                    ; $00B5 : 19
        pop af                       ; $00B6 : F1
        dec a                        ; $00B7 : 3D
        jp nz,$0099                  ; $00B8 : C2 99 00 | Loop back
        ld hl,($2018)                ; $00BB : 2A 18 20 | Sprite pointer 0
        call $030C                   ; $00BE : CD 0C 03
        ld hl,($201A)                ; $00C1 : 2A 1A 20 | Sprite pointer 1
        ld a,$03                     ; $00C4 : 3E 03 | Loop counter
L00C6:
        push af                      ; $00C6 : F5
        ld a,l                       ; $00C7 : 7D
        cp $7F                       ; $00C8 : FE 7F | hl==$207F?
        jp nz,$00D0                  ; $00CA : C2 D0 00
L00CD:
        ld hl,$2058                  ; $00CD : 21 58 20 | Reset to $2058
L00D0:
        or h                         ; $00D0 : B4
        jp z,$00CD                   ; $00D1 : CA CD 00
        push hl                      ; $00D4 : E5
        call $01DE                   ; $00D5 : CD DE 01
        pop hl                       ; $00D8 : E1
        jp nc,$00DF                  ; $00D9 : D2 DF 00
        ld ($201A),hl                ; $00DC : 22 1A 20 | Sprite pointer 1
L00DF:
        ld de,$000D                  ; $00DF : 11 0D 00
        add hl,de                    ; $00E2 : 19
        pop af                       ; $00E3 : F1
        dec a                        ; $00E4 : 3D
        jp nz,$00C6                  ; $00E5 : C2 C6 00 | Loop back
        xor a                        ; $00E8 : AF
        ld ($2030),a                 ; $00E9 : 32 30 20 | Clear sprite shift
        ld hl,($2016)                ; $00EC : 2A 16 20 | Pointer?
        ld a,$04                     ; $00EF : 3E 04 | Loop counter
L00F1:
        push af                      ; $00F1 : F5
        ld a,l                       ; $00F2 : 7D
        cp $5F                       ; $00F3 : FE 5F
        jp nz,$00FB                  ; $00F5 : C2 FB 00
L00F8:
        ld hl,$20E7                  ; $00F8 : 21 E7 20 | Reset to $20E7
L00FB:
        or h                         ; $00FB : B4
        jp z,$00F8                   ; $00FC : CA F8 00
        push hl                      ; $00FF : E5
        call $0250                   ; $0100 : CD 50 02
        pop hl                       ; $0103 : E1
        jp nc,$010A                  ; $0104 : D2 0A 01
        ld ($2016),hl                ; $0107 : 22 16 20 | Pointer?
L010A:
        ld de,$001E                  ; $010A : 11 1E 00
        add hl,de                    ; $010D : 19
        pop af                       ; $010E : F1
        dec a                        ; $010F : 3D
        jp nz,$00F1                  ; $0110 : C2 F1 00 | Loop back
        call $0331                   ; $0113 : CD 31 03
        jp $0069                     ; $0116 : C3 69 00 | End of interrupt routine

; -----------------------------------------------------------------------------
; IRQ_OBJECT_DRAW (IRQ_OBJECT_DRAW:19) - Draw active ship objects
; -----------------------------------------------------------------------------
IRQ_OBJECT_DRAW:
        ld hl,($201A)                ; $0119 : 2A 1A 20 | Ship 1 pointer
        call $030C                   ; $011C : CD 0C 03
        ld hl,($201A)                ; $011F : 2A 1A 20 | Ship 1 pointer
        call $013A                   ; $0122 : CD 3A 01
        ld hl,($2018)                ; $0125 : 2A 18 20 | Ship 0 pointer
        call $013A                   ; $0128 : CD 3A 01
        jp $0069                     ; $012B : C3 69 00 | End of interrupt routine

; -----------------------------------------------------------------------------
; UPDATE_SELECTED_OBJECT (UPDATE_SELECTED_OBJECT:2E) - Update the selected active object
; -----------------------------------------------------------------------------
UPDATE_SELECTED_OBJECT:
        ld hl,($2014)                ; $012E : 2A 14 20
        ld a,(hl)                    ; $0131 : 7E
        and a                        ; $0132 : A7
        ret p                        ; $0133 : F0 | No sprite to update?
        call $0165                   ; $0134 : CD 65 01 | Update sprite
        jp $0192                     ; $0137 : C3 92 01

; -----------------------------------------------------------------------------
; UPDATE_SHIP_OBJECT (UPDATE_SHIP_OBJECT:3A) - Process a ship-object state field
; -----------------------------------------------------------------------------
UPDATE_SHIP_OBJECT:
        ld a,(hl)                    ; $013A : 7E
        and a                        ; $013B : A7
        ret p                        ; $013C : F0 | Return if b7 clear
        and $40                      ; $013D : E6 40 | Check bit 6
        jp nz,$0145                  ; $013F : C2 45 01 | Jump if set
        ld (hl),$00                  ; $0142 : 36 00 | Clear entry
        ret                          ; $0144 : C9
L0145:
        ld a,(hl)                    ; $0145 : 7E
        or $20                       ; $0146 : F6 20
        ld (hl),a                    ; $0148 : 77 | Set bit 5
        push af                      ; $0149 : F5
        call $0165                   ; $014A : CD 65 01 | Update sprite
        pop af                       ; $014D : F1
        and $10                      ; $014E : E6 10 | Check bit 4
        jp z,$0192                   ; $0150 : CA 92 01 | Initial sprite draw
        ld a,c                       ; $0153 : 79
        add a,l                      ; $0154 : 85
        ld l,a                       ; $0155 : 6F
        push hl                      ; $0156 : E5
        ld hl,$2030                  ; $0157 : 21 30 20
        ld a,(hl)                    ; $015A : 7E
        cpl                          ; $015B : 2F
        and $07                      ; $015C : E6 07
        ld (hl),a                    ; $015E : 77
        pop hl                       ; $015F : E1
        out ($04),a                  ; $0160 : D3 04 | Update shift count
        jp $01B8                     ; $0162 : C3 B8 01

; -----------------------------------------------------------------------------
; PREPARE_SPRITE_COPY (PREPARE_SPRITE_COPY:65) - Read the object's graphic source and destination parameters
; -----------------------------------------------------------------------------
PREPARE_SPRITE_COPY:
        inc hl                       ; $0165 : 23
        inc hl                       ; $0166 : 23
        ld e,(hl)                    ; $0167 : 5E | LSB of loc + shift
        inc hl                       ; $0168 : 23
        inc hl                       ; $0169 : 23
        inc hl                       ; $016A : 23
        ld d,(hl)                    ; $016B : 56 | MSB of loc
        inc hl                       ; $016C : 23
        inc hl                       ; $016D : 23
        call $0A00                   ; $016E : CD 00 0A | de >> 3, e&3 -> c
        ld a,c                       ; $0171 : 79 | (shift)
        ld ($2030),a                 ; $0172 : 32 30 20
        out ($04),a                  ; $0175 : D3 04 | Shifter count
        push de                      ; $0177 : D5 | Store screen loc
        ld e,(hl)                    ; $0178 : 5E | Read rom loc
        inc hl                       ; $0179 : 23
        ld d,(hl)                    ; $017A : 56
        inc hl                       ; $017B : 23
        ex de,hl                     ; $017C : EB | rom loc -> hl
        ld c,(hl)                    ; $017D : 4E | Read bc (row/cols)
        inc hl                       ; $017E : 23
        ld b,(hl)                    ; $017F : 46
        inc hl                       ; $0180 : 23
        ex (sp),hl                   ; $0181 : E3 | swap screen loc
        ex de,hl                     ; $0182 : EB | Back to ram table
        ld (hl),e                    ; $0183 : 73
        inc hl                       ; $0184 : 23
        ld (hl),d                    ; $0185 : 72
        inc hl                       ; $0186 : 23
        ld (hl),c                    ; $0187 : 71
        inc (hl)                     ; $0188 : 34 | +1 wide for shifting?
        inc hl                       ; $0189 : 23
        ld (hl),b                    ; $018A : 70
        inc hl                       ; $018B : 23
        ld ($201C),hl                ; $018C : 22 1C 20
        ex de,hl                     ; $018F : EB | hl = screen loc
        pop de                       ; $0190 : D1 | de = sprite data in ROM
        ret                          ; $0191 : C9 | bc = bytes wide, pix high

; -----------------------------------------------------------------------------
; DRAW_SPRITE_NORMAL (DRAW_SPRITE_NORMAL:92) - Copy sprite bytes through the shifter path
; -----------------------------------------------------------------------------
DRAW_SPRITE_NORMAL:
        push bc                      ; $0192 : C5 | bc = bytes wide, pix high
        push hl                      ; $0193 : E5 | hl = screen loc
L0194:
        ld a,(de)                    ; $0194 : 1A | Sprite byte
        inc de                       ; $0195 : 13
        out ($03),a                  ; $0196 : D3 03 | MB12421 data write
        in a,($03)                   ; $0198 : DB 03 | MB12421 data read
        ld (hl),a                    ; $019A : 77 | Write to RAM
        inc hl                       ; $019B : 23
        dec c                        ; $019C : 0D
        jp nz,$0194                  ; $019D : C2 94 01 | Loop for width
        xor a                        ; $01A0 : AF
        out ($03),a                  ; $01A1 : D3 03 | MB12421 data write
        in a,($03)                   ; $01A3 : DB 03 | MB12421 data read
        ld (hl),a                    ; $01A5 : 77 | Final write
        ld bc,$0020                  ; $01A6 : 01 20 00 | Row increment
        pop hl                       ; $01A9 : E1
        add hl,bc                    ; $01AA : 09 | Next row
        pop bc                       ; $01AB : C1
        ld a,l                       ; $01AC : 7D
        and $E0                      ; $01AD : E6 E0
        jp nz,$0192                  ; $01AF : C2 92 01 | Not bottom of screen
        ld a,h                       ; $01B2 : 7C
        rra                          ; $01B3 : 1F
        jp c,$0192                   ; $01B4 : DA 92 01 | Not end of screen
        ret                          ; $01B7 : C9

; -----------------------------------------------------------------------------
; DRAW_SPRITE_SHIFTED (DRAW_SPRITE_SHIFTED:B8) - Copy sprite bytes through the alternate shifted path
; -----------------------------------------------------------------------------
DRAW_SPRITE_SHIFTED:
        push bc                      ; $01B8 : C5
        push hl                      ; $01B9 : E5
L01BA:
        ld a,(de)                    ; $01BA : 1A
        inc de                       ; $01BB : 13
        out ($03),a                  ; $01BC : D3 03 | Shifter input
        in a,($00)                   ; $01BE : DB 00 | Shifter output
        ld (hl),a                    ; $01C0 : 77 | Write to screen
        dec hl                       ; $01C1 : 2B
        dec c                        ; $01C2 : 0D
        jp nz,$01BA                  ; $01C3 : C2 BA 01 | Loop for row
        xor a                        ; $01C6 : AF
        out ($03),a                  ; $01C7 : D3 03 | Shifter input
        in a,($00)                   ; $01C9 : DB 00 | Shifter output
        ld (hl),a                    ; $01CB : 77 | Write to screen
        ld bc,$0020                  ; $01CC : 01 20 00 | Next line
        pop hl                       ; $01CF : E1
        add hl,bc                    ; $01D0 : 09
        pop bc                       ; $01D1 : C1
        ld a,l                       ; $01D2 : 7D
        and $E0                      ; $01D3 : E6 E0
        jp nz,$01B8                  ; $01D5 : C2 B8 01 | Loop
        ld a,h                       ; $01D8 : 7C
        rra                          ; $01D9 : 1F
        jp c,$01B8                   ; $01DA : DA B8 01 | Loop
        ret                          ; $01DD : C9

; -----------------------------------------------------------------------------
; UPDATE_SHIP_DESCRIPTOR (UPDATE_SHIP_DESCRIPTOR:DE) - Advance and test ship descriptor
; -----------------------------------------------------------------------------
UPDATE_SHIP_DESCRIPTOR:
        ld a,(hl)                    ; $01DE : 7E
        and a                        ; $01DF : A7
        ret p                        ; $01E0 : F0 | High bit clear = inactive
        push hl                      ; $01E1 : E5 | hl now delta X
        inc hl                       ; $01E2 : 23
        and $07                      ; $01E3 : E6 07 | Mask low 3 bits
        jp nz,$01ED                  ; $01E5 : C2 ED 01 | (is a ship)
        inc hl                       ; $01E8 : 23
        inc hl                       ; $01E9 : 23
        jp $0237                     ; $01EA : C3 37 02
L01ED:
        ld a,(hl)                    ; $01ED : 7E | Delta X
        ld de,$215F                  ; $01EE : 11 5F 21 | Table for +
        and a                        ; $01F1 : A7
        jp p,$01F8                   ; $01F2 : F2 F8 01
        ld de,$2181                  ; $01F5 : 11 81 21 | Table for -
L01F8:
        ld b,a                       ; $01F8 : 47 | b = delta x
        inc hl                       ; $01F9 : 23 | (hl) = X
        add a,(hl)                   ; $01FA : 86 | a = x + dx
        ld (hl),a                    ; $01FB : 77 | store x
        ld a,b                       ; $01FC : 78 | a = delta X
        and a                        ; $01FD : A7
        ld a,(hl)                    ; $01FE : 7E | a = X
        jp p,$0210                   ; $01FF : F2 10 02 | (left to right)
        cp $01                       ; $0202 : FE 01
        jp nc,$0216                  ; $0204 : D2 16 02
L0207:
        ex (sp),hl                   ; $0207 : E3
        ld a,(hl)                    ; $0208 : 7E
        and $BF                      ; $0209 : E6 BF | Clear bit 5
        ld (hl),a                    ; $020B : 77
        ex (sp),hl                   ; $020C : E3
        jp $0216                     ; $020D : C3 16 02
L0210:
        inc hl                       ; $0210 : 23
        cp (hl)                      ; $0211 : BE | End X
        dec hl                       ; $0212 : 2B
        jp nc,$0207                  ; $0213 : D2 07 02
L0216:
        ld a,(hl)                    ; $0216 : 7E
        rrca                         ; $0217 : 0F
        rrca                         ; $0218 : 0F
        rrca                         ; $0219 : 0F
        and $1F                      ; $021A : E6 1F
        add a,e                      ; $021C : 83
        ld e,a                       ; $021D : 5F
        ex (sp),hl                   ; $021E : E3
        ld a,(hl)                    ; $021F : 7E
        ex (sp),hl                   ; $0220 : E3
        and $07                      ; $0221 : E6 07
        ld b,a                       ; $0223 : 47
        inc hl                       ; $0224 : 23
        ld a,(hl)                    ; $0225 : 7E
        cpl                          ; $0226 : 2F
        inc a                        ; $0227 : 3C
        rrca                         ; $0228 : 0F
        rrca                         ; $0229 : 0F
        rrca                         ; $022A : 0F
        and $07                      ; $022B : E6 07
        add a,$03                    ; $022D : C6 03
        ex de,hl                     ; $022F : EB
L0230:
        ld (hl),b                    ; $0230 : 70
        inc hl                       ; $0231 : 23
        dec a                        ; $0232 : 3D
        jp nz,$0230                  ; $0233 : C2 30 02
        ex de,hl                     ; $0236 : EB
L0237:
        ld de,$202F                  ; $0237 : 11 2F 20
        ld a,(de)                    ; $023A : 1A
        cpl                          ; $023B : 2F
        ld (de),a                    ; $023C : 12
        jp nz,$0247                  ; $023D : C2 47 02
        inc hl                       ; $0240 : 23
        ld a,(hl)                    ; $0241 : 7E
        inc hl                       ; $0242 : 23
        add a,(hl)                   ; $0243 : 86
        ld (hl),a                    ; $0244 : 77
        inc hl                       ; $0245 : 23
        cp (hl)                      ; $0246 : BE
L0247:
        pop hl                       ; $0247 : E1
        scf                          ; $0248 : 37
        ret nz                       ; $0249 : C0
        ld a,(hl)                    ; $024A : 7E
        and $BF                      ; $024B : E6 BF
        ld (hl),a                    ; $024D : 77
        scf                          ; $024E : 37
        ret                          ; $024F : C9

; -----------------------------------------------------------------------------
; UPDATE_PROJECTILE_DESCRIPTOR ($0250) - Advance and test torpedo or mine descriptor
; -----------------------------------------------------------------------------
UPDATE_PROJECTILE_DESCRIPTOR:
        ld a,(hl)                    ; $0250 : 7E
        and a                        ; $0251 : A7
        ret p                        ; $0252 : F0
        push hl                      ; $0253 : E5
        inc hl                       ; $0254 : 23
        inc hl                       ; $0255 : 23
        ld c,(hl)                    ; $0256 : 4E
        inc hl                       ; $0257 : 23
        inc hl                       ; $0258 : 23
        ld a,(hl)                    ; $0259 : 7E
        inc hl                       ; $025A : 23
        ld b,(hl)                    ; $025B : 46
        add a,b                      ; $025C : 80
        ld (hl),a                    ; $025D : 77
        ld a,b                       ; $025E : 78
        cp $C0                       ; $025F : FE C0
        jp nc,$0309                  ; $0261 : D2 09 03
        cp $30                       ; $0264 : FE 30
        jp nc,$0275                  ; $0266 : D2 75 02
        ld a,($2024)                 ; $0269 : 3A 24 20
        and a                        ; $026C : A7
        jp z,$0275                   ; $026D : CA 75 02
        inc a                        ; $0270 : 3C
        inc a                        ; $0271 : 3C
        ld ($2024),a                 ; $0272 : 32 24 20
L0275:
        ld a,(hl)                    ; $0275 : 7E
        inc hl                       ; $0276 : 23
        cp (hl)                      ; $0277 : BE
        jp nc,$029C                  ; $0278 : D2 9C 02
        ld a,$C0                     ; $027B : 3E C0
        add a,(hl)                   ; $027D : 86
        ld (hl),a                    ; $027E : 77
        dec hl                       ; $027F : 2B
        dec hl                       ; $0280 : 2B
        inc (hl)                     ; $0281 : 34
        inc (hl)                     ; $0282 : 34
        ld a,(hl)                    ; $0283 : 7E
        inc hl                       ; $0284 : 23
        inc hl                       ; $0285 : 23
        inc hl                       ; $0286 : 23
        jp z,$0296                   ; $0287 : CA 96 02
        ld (hl),$88                  ; $028A : 36 88
        cp $FC                       ; $028C : FE FC
        jp z,$029C                   ; $028E : CA 9C 02
        ld (hl),$98                  ; $0291 : 36 98
        jp $029C                     ; $0293 : C3 9C 02
L0296:
        ex (sp),hl                   ; $0296 : E3
        ld a,(hl)                    ; $0297 : 7E
        and $BF                      ; $0298 : E6 BF
        ld (hl),a                    ; $029A : 77
        ex (sp),hl                   ; $029B : E3
L029C:
        ld de,$2030                  ; $029C : 11 30 20
        ld a,(de)                    ; $029F : 1A
        and a                        ; $02A0 : A7
        jp nz,$0309                  ; $02A1 : C2 09 03
        inc a                        ; $02A4 : 3C
        ld (de),a                    ; $02A5 : 12
        ld a,b                       ; $02A6 : 78
        and $10                      ; $02A7 : E6 10
        jp z,$0309                   ; $02A9 : CA 09 03
        ld de,$0007                  ; $02AC : 11 07 00
        add hl,de                    ; $02AF : 19
        ld a,(hl)                    ; $02B0 : 7E
        and a                        ; $02B1 : A7
        jp nz,$02C3                  ; $02B2 : C2 C3 02
        add hl,de                    ; $02B5 : 19
        ld a,b                       ; $02B6 : 78
        add a,e                      ; $02B7 : 83
        ld b,a                       ; $02B8 : 47
        and $10                      ; $02B9 : E6 10
        jp z,$0309                   ; $02BB : CA 09 03
        ld a,(hl)                    ; $02BE : 7E
        and a                        ; $02BF : A7
        jp z,$0309                   ; $02C0 : CA 09 03
L02C3:
        ex (sp),hl                   ; $02C3 : E3
        ld a,(hl)                    ; $02C4 : 7E
        and $BF                      ; $02C5 : E6 BF
        ld (hl),a                    ; $02C7 : 77
        ex (sp),hl                   ; $02C8 : E3
        ld a,b                       ; $02C9 : 78
        sub $40                      ; $02CA : D6 40
        ld b,a                       ; $02CC : 47
        jp c,$02E0                   ; $02CD : DA E0 02
        ld hl,$21A1                  ; $02D0 : 21 A1 21
L02D3:
        inc hl                       ; $02D3 : 23
        inc hl                       ; $02D4 : 23
        ld a,(hl)                    ; $02D5 : 7E
        and a                        ; $02D6 : A7
        jp nz,$02D3                  ; $02D7 : C2 D3 02
        ld (hl),b                    ; $02DA : 70
        inc hl                       ; $02DB : 23
        ld (hl),c                    ; $02DC : 71
        jp $0309                     ; $02DD : C3 09 03
L02E0:
        ld hl,$21BE                  ; $02E0 : 21 BE 21
L02E3:
        inc hl                       ; $02E3 : 23
        inc hl                       ; $02E4 : 23
        inc hl                       ; $02E5 : 23
        ld a,(hl)                    ; $02E6 : 7E
        and a                        ; $02E7 : A7
        jp nz,$02E3                  ; $02E8 : C2 E3 02
        ld a,b                       ; $02EB : 78
        add a,$20                    ; $02EC : C6 20
        ld de,$2160                  ; $02EE : 11 60 21
        jp m,$02F7                   ; $02F1 : FA F7 02
        ld de,$2182                  ; $02F4 : 11 82 21
L02F7:
        ld a,c                       ; $02F7 : 79
        rrca                         ; $02F8 : 0F
        rrca                         ; $02F9 : 0F
        rrca                         ; $02FA : 0F
        and $1F                      ; $02FB : E6 1F
        add a,e                      ; $02FD : 83
        ld e,a                       ; $02FE : 5F
        ld a,(de)                    ; $02FF : 1A
        and a                        ; $0300 : A7
        jp z,$0309                   ; $0301 : CA 09 03
        ld (hl),a                    ; $0304 : 77
        inc hl                       ; $0305 : 23
        ld (hl),c                    ; $0306 : 71
        inc hl                       ; $0307 : 23
        ld (hl),b                    ; $0308 : 70
L0309:
        scf                          ; $0309 : 37
        pop hl                       ; $030A : E1
        ret                          ; $030B : C9

; -----------------------------------------------------------------------------
; CLEAR_ACTIVE_OBJECT ($030C) - Clear active-object display state
; -----------------------------------------------------------------------------
CLEAR_ACTIVE_OBJECT:
        ld a,(hl)                    ; $030C : 7E | X flags?
        and a                        ; $030D : A7
        ret p                        ; $030E : F0 | Return if high bit not set
        and $20                      ; $030F : E6 20
        ret z                        ; $0311 : C8 | Bit 5 clear = not active
        call $035B                   ; $0312 : CD 5B 03 | Get de, bc from bytes 9-d
        ex de,hl                     ; $0315 : EB | hl = read de
        ld b,c                       ; $0316 : 41
L0317:
        xor a                        ; $0317 : AF
        push hl                      ; $0318 : E5 | Store loc
L0319:
        ld (hl),a                    ; $0319 : 77
        inc hl                       ; $031A : 23
        dec c                        ; $031B : 0D
        jp nz,$0319                  ; $031C : C2 19 03
        ld de,$0020                  ; $031F : 11 20 00
        pop hl                       ; $0322 : E1 | Get loc
        add hl,de                    ; $0323 : 19 | Next line
        ld c,b                       ; $0324 : 48
        ld a,l                       ; $0325 : 7D
        and $E0                      ; $0326 : E6 E0
        jp nz,$0317                  ; $0328 : C2 17 03 | Loop
        ld a,h                       ; $032B : 7C
        rra                          ; $032C : 1F
        jp c,$0317                   ; $032D : DA 17 03 | Loop
        ret                          ; $0330 : C9

; -----------------------------------------------------------------------------
; ADVANCE_OBJECT_CURSOR ($0331) - Select the next active object descriptor
; -----------------------------------------------------------------------------
ADVANCE_OBJECT_CURSOR:
        ld hl,($2014)                ; $0331 : 2A 14 20
        ld b,$0A                     ; $0334 : 06 0A | Loop counter
        ld a,l                       ; $0336 : 7D
        or h                         ; $0337 : B4
        jp nz,$033E                  ; $0338 : C2 3E 03
        ld hl,$2072                  ; $033B : 21 72 20 | Reset to $2072
L033E:
        ld de,$000D                  ; $033E : 11 0D 00
L0341:
        add hl,de                    ; $0341 : 19
        dec b                        ; $0342 : 05
        ret z                        ; $0343 : C8 | End of loop
        ld a,l                       ; $0344 : 7D
        cp $E7                       ; $0345 : FE E7 | hl == $20E7?
        jp nz,$034D                  ; $0347 : C2 4D 03
        ld hl,$207F                  ; $034A : 21 7F 20 | Reset to $207F
L034D:
        ld a,(hl)                    ; $034D : 7E | X flags
        and a                        ; $034E : A7
        jp p,$0341                   ; $034F : F2 41 03 | MSB clear?
        ld ($2014),hl                ; $0352 : 22 14 20
        inc hl                       ; $0355 : 23
        ld a,(hl)                    ; $0356 : 7E | Delta X
        inc hl                       ; $0357 : 23
        add a,(hl)                   ; $0358 : 86 | Add to X
        ld (hl),a                    ; $0359 : 77 | Store X
        ret                          ; $035A : C9

; -----------------------------------------------------------------------------
; LOAD_OBJECT_DRAW_PARAMETERS ($035B) - Load drawing parameters from an object record
; -----------------------------------------------------------------------------
LOAD_OBJECT_DRAW_PARAMETERS:
        ld de,$0009                  ; $035B : 11 09 00
        add hl,de                    ; $035E : 19
        ld e,(hl)                    ; $035F : 5E
        inc hl                       ; $0360 : 23
        ld d,(hl)                    ; $0361 : 56
        inc hl                       ; $0362 : 23
        ld c,(hl)                    ; $0363 : 4E
        inc hl                       ; $0364 : 23
        ld b,(hl)                    ; $0365 : 46
        inc hl                       ; $0366 : 23
        ret                          ; $0367 : C9

; -----------------------------------------------------------------------------
; UPDATE_FRAME_TIMERS ($0368) - Update frame-related countdown state
; -----------------------------------------------------------------------------
UPDATE_FRAME_TIMERS:
        ld a,($2020)                 ; $0368 : 3A 20 20
        and a                        ; $036B : A7
        ret nz                       ; $036C : C0
        ld b,a                       ; $036D : 47
        ld hl,$2003                  ; $036E : 21 03 20 | Counter address
        dec (hl)                     ; $0371 : 35 | Decrement counter
        jp nz,$038E                  ; $0372 : C2 8E 03
        ld (hl),$1E                  ; $0375 : 36 1E | Reset counter
        ld hl,$2002                  ; $0377 : 21 02 20 | Game timer
        ld a,(hl)                    ; $037A : 7E
        and a                        ; $037B : A7
        jp z,$0388                   ; $037C : CA 88 03 | Game over
        add a,$99                    ; $037F : C6 99
        daa                          ; $0381 : 27
        ld (hl),a                    ; $0382 : 77 | Decrement game timer
        jp nz,$0388                  ; $0383 : C2 88 03
        ld b,$01                     ; $0386 : 06 01 | --> d7
L0388:
        ld hl,$2010                  ; $0388 : 21 10 20
        call $03AE                   ; $038B : CD AE 03 | Handle $2010 timer d6
L038E:
        ld hl,$2011                  ; $038E : 21 11 20
        call $03AE                   ; $0391 : CD AE 03 | Handle $2011 timer d5
        ld hl,$2021                  ; $0394 : 21 21 20
        call $03AE                   ; $0397 : CD AE 03 | Handle $2021 timer d4
        inc hl                       ; $039A : 23
        call $03AE                   ; $039B : CD AE 03 | Handle $2022 timer d3
        inc hl                       ; $039E : 23
        call $03AE                   ; $039F : CD AE 03 | Handle $2023 timer d2
        inc hl                       ; $03A2 : 23
        call $03AE                   ; $03A3 : CD AE 03 | Handle $2024 timer d1
        inc hl                       ; $03A6 : 23
        call $03AE                   ; $03A7 : CD AE 03 | Handle $2025 timer d0
        ld ($2020),a                 ; $03AA : 32 20 20
        ret                          ; $03AD : C9

; -----------------------------------------------------------------------------
; DECREMENT_TIMER_IF_ACTIVE ($03AE) - Decrement a nonzero countdown byte
; -----------------------------------------------------------------------------
DECREMENT_TIMER_IF_ACTIVE:
        ld a,(hl)                    ; $03AE : 7E
        and a                        ; $03AF : A7
        jp z,$03B8                   ; $03B0 : CA B8 03
        dec (hl)                     ; $03B3 : 35
        jp nz,$03B8                  ; $03B4 : C2 B8 03
        scf                          ; $03B7 : 37 | Set carry
L03B8:
        ld a,b                       ; $03B8 : 78
        rla                          ; $03B9 : 17
        ld b,a                       ; $03BA : 47
        ret                          ; $03BB : C9

; -----------------------------------------------------------------------------
; UPDATE_WAVE_PATTERN ($03BC) - Update wave/display pattern state
; -----------------------------------------------------------------------------
UPDATE_WAVE_PATTERN:
        ld bc,$2027                  ; $03BC : 01 27 20
        ld a,(bc)                    ; $03BF : 0A
        add a,$0A                    ; $03C0 : C6 0A | $00 -> $0A -> $14 -> $1E = $00
        cp $1E                       ; $03C2 : FE 1E
        jp nz,$03C8                  ; $03C4 : C2 C8 03
        xor a                        ; $03C7 : AF
L03C8:
        ld (bc),a                    ; $03C8 : 02 | Store state
        inc bc                       ; $03C9 : 03 | $2028
        ld e,a                       ; $03CA : 5F
        ld d,$00                     ; $03CB : 16 00
        ld hl,$0BF3                  ; $03CD : 21 F3 0B | Start of waves
        add hl,de                    ; $03D0 : 19
        ex de,hl                     ; $03D1 : EB | de = wave table entry
        ld a,(bc)                    ; $03D2 : 0A
        inc a                        ; $03D3 : 3C
        and $1F                      ; $03D4 : E6 1F | Loops $00 to $1F
        ld (bc),a                    ; $03D6 : 02
        ld hl,$27E0                  ; $03D7 : 21 E0 27
        add a,l                      ; $03DA : 85
        ld l,a                       ; $03DB : 6F
        ld bc,$0020                  ; $03DC : 01 20 00 | Next char
L03DF:
        ld a,(de)                    ; $03DF : 1A | Get byte
        inc de                       ; $03E0 : 13
        ld (hl),a                    ; $03E1 : 77 | Write byte
        add hl,bc                    ; $03E2 : 09 | Next char
        ld a,l                       ; $03E3 : 7D
        and $E0                      ; $03E4 : E6 E0
        cp $60                       ; $03E6 : FE 60
        jp nz,$03DF                  ; $03E8 : C2 DF 03 | Loop
        ret                          ; $03EB : C9

; -----------------------------------------------------------------------------
; CONVERT_DISPLAY_DIGITS ($03EC) - Convert numeric state for display
; -----------------------------------------------------------------------------
CONVERT_DISPLAY_DIGITS:
        ld hl,$0000                  ; $03EC : 21 00 00 | Start address
        ld de,$0000                  ; $03EF : 11 00 00 | Offset 0
        ld c,$02                     ; $03F2 : 0E 02 | Until $200
L03F4:
        xor a                        ; $03F4 : AF
L03F5:
        add a,(hl)                   ; $03F5 : 86
        inc hl                       ; $03F6 : 23
        ld b,a                       ; $03F7 : 47
        ld a,c                       ; $03F8 : 79
        cp h                         ; $03F9 : BC
        ld a,b                       ; $03FA : 78
        jp nz,$03F5                  ; $03FB : C2 F5 03 | Loop
        push hl                      ; $03FE : E5 | Push address
        ld hl,$0429                  ; $03FF : 21 29 04 | Checksum table
        add hl,de                    ; $0402 : 19
        cp (hl)                      ; $0403 : BE | Compare checksum
        ld a,$40                     ; $0404 : 3E 40 | _
        jp z,$040E                   ; $0406 : CA 0E 04
        ld hl,$0432                  ; $0409 : 21 32 04
        add hl,de                    ; $040C : 19
        ld a,(hl)                    ; $040D : 7E
L040E:
        ld hl,$21E9                  ; $040E : 21 E9 21 | Base screen loc
        add hl,de                    ; $0411 : 19
        ld (hl),a                    ; $0412 : 77 | Store char
        pop hl                       ; $0413 : E1 | Get address back
        inc de                       ; $0414 : 13 | Next rom
        inc c                        ; $0415 : 0C | $2 more pages
        inc c                        ; $0416 : 0C
        ld a,$12                     ; $0417 : 3E 12
        cp c                         ; $0419 : B9
        jp nz,$03F4                  ; $041A : C2 F4 03 | Loop if not done
        ld hl,$21E9                  ; $041D : 21 E9 21
        ld de,$3008                  ; $0420 : 11 08 30
        ld a,$08                     ; $0423 : 3E 08
        call $0B30                   ; $0425 : CD 30 0B | Draw string hl @ de, length a
        halt                         ; $0428 : 76 | Stop!

; -----------------------------------------------------------------------------
; STARTUP_BYTE_TABLE ($0429) - Startup data/constants adjacent to native initialization
; -----------------------------------------------------------------------------
STARTUP_BYTE_TABLE:
        DB $8D,$79,$00,$1F,$58,$6D,$EA,$C5,$2A,$48,$48,$47 ; $0429 raw original bytes | byte-exact exception at code/data boundary
        DB $47,$46,$46,$45,$45 ; $0435 raw original bytes | byte-exact exception at code/data boundary
; -----------------------------------------------------------------------------
; STARTUP_INITIALIZE ($043A) - Initialize hardware and RAM before the game loop
; -----------------------------------------------------------------------------
STARTUP_INITIALIZE:
        call $08A2                   ; $043A : CD A2 08 | (End of game routine)
        in a,($02)                   ; $043D : DB 02 | IN2
        and $E0                      ; $043F : E6 E0 | Test mode bits
        cp $E0                       ; $0441 : FE E0
        call z,$03EC                 ; $0443 : CC EC 03 | Go to test mode
        ld hl,$2002                  ; $0446 : 21 02 20
        ld a,$09                     ; $0449 : 3E 09
        ld b,$00                     ; $044B : 06 00
L044D:
        ld (hl),b                    ; $044D : 70
        inc hl                       ; $044E : 23
        dec a                        ; $044F : 3D
        jp nz,$044D                  ; $0450 : C2 4D 04
        ld hl,$0929                  ; $0453 : 21 29 09
        ld ($2000),hl                ; $0456 : 22 00 20
        ei                           ; $0459 : FB | Enable interrupts
        ld hl,$0459                  ; $045A : 21 59 04 | Return address
        push hl                      ; $045D : E5

; The 8080 command interpreter reads RAM $2000 and dispatches indexed words.

; -----------------------------------------------------------------------------
; GAME_COMMAND_DISPATCH ($045E) - Fetch indexed game command; zero uses frame-control path
; -----------------------------------------------------------------------------
GAME_COMMAND_DISPATCH:
        ld hl,($2000)                ; $045E : 2A 00 20
        ld a,(hl)                    ; $0461 : 7E
        and a                        ; $0462 : A7
        jp nz,$047D                  ; $0463 : C2 7D 04
        call $06A4                   ; $0466 : CD A4 06
        call $04CE                   ; $0469 : CD CE 04
        call $04BF                   ; $046C : CD BF 04
        ld a,($2002)                 ; $046F : 3A 02 20 | Game timer
        and a                        ; $0472 : A7
        ret z                        ; $0473 : C8 | Skip rest if game over
        call $074C                   ; $0474 : CD 4C 07
        call $08B8                   ; $0477 : CD B8 08
        jp $048C                     ; $047A : C3 8C 04

; -----------------------------------------------------------------------------
; GAME_COMMAND_INDEX ($047D) - Index the 16-bit native handler-address table
; -----------------------------------------------------------------------------
GAME_COMMAND_INDEX:
        inc hl                       ; $047D : 23
        ex de,hl                     ; $047E : EB | ($2000+1) --> de
        ld hl,$09E8                  ; $047F : 21 E8 09 | Jump table
        rlca                         ; $0482 : 07 | a = ($2000)<<1
        ld c,a                       ; $0483 : 4F | c = ($2000)<<1
        ld b,$00                     ; $0484 : 06 00
        add hl,bc                    ; $0486 : 09 | hl = $09e8 + ($2000)<<1
        ld a,(hl)                    ; $0487 : 7E
        inc hl                       ; $0488 : 23
        ld h,(hl)                    ; $0489 : 66
        ld l,a                       ; $048A : 6F
        jp (hl)                      ; $048B : E9

; -----------------------------------------------------------------------------
; GAME_TIME_SERVICE ($048C) - Game-time service and threshold test
; -----------------------------------------------------------------------------
GAME_TIME_SERVICE:
        ld a,($2003)                 ; $048C : 3A 03 20
        cp $1D                       ; $048F : FE 1D
        ret m                        ; $0491 : F8
        ld bc,$2002                  ; $0492 : 01 02 20
        ld de,$21E9                  ; $0495 : 11 E9 21
        call $0A82                   ; $0498 : CD 82 0A
        ex de,hl                     ; $049B : EB
        call $0A7A                   ; $049C : CD 7A 0A
        inc hl                       ; $049F : 23
        ld (hl),$2C                  ; $04A0 : 36 2C
        inc hl                       ; $04A2 : 23
        ex de,hl                     ; $04A3 : EB
        ld bc,$202B                  ; $04A4 : 01 2B 20 | Player score
        call $0A82                   ; $04A7 : CD 82 0A | Draw score digits
        ex de,hl                     ; $04AA : EB
        call $0A7A                   ; $04AB : CD 7A 0A
        inc hl                       ; $04AE : 23
        ld (hl),$30                  ; $04AF : 36 30
        inc hl                       ; $04B1 : 23
        ld (hl),$30                  ; $04B2 : 36 30
        ld hl,$21E9                  ; $04B4 : 21 E9 21
        ld de,$3E2F                  ; $04B7 : 11 2F 3E
        ld a,$06                     ; $04BA : 3E 06
        jp $0B30                     ; $04BC : C3 30 0B | Draw string hl @ de, length a
L04BF:
        ld hl,$202A                  ; $04BF : 21 2A 20
        ld a,(hl)                    ; $04C2 : 7E
        and a                        ; $04C3 : A7
        ret z                        ; $04C4 : C8
        ld (hl),$00                  ; $04C5 : 36 00
        ld hl,$09A6                  ; $04C7 : 21 A6 09
        ld ($2000),hl                ; $04CA : 22 00 20
        ret                          ; $04CD : C9
L04CE:
        ld hl,$2020                  ; $04CE : 21 20 20
        ld a,(hl)                    ; $04D1 : 7E
        and a                        ; $04D2 : A7
        ret z                        ; $04D3 : C8 | Nothing to do
        ld (hl),$00                  ; $04D4 : 36 00 | Clear all bits
        rra                          ; $04D6 : 1F
        call c,$0601                 ; $04D7 : DC 01 06 | Bit 0 set = Clear explosion lights
        rra                          ; $04DA : 1F
        call c,$060E                 ; $04DB : DC 0E 06 | Bit 1 set = Clear explosion on screen
        rra                          ; $04DE : 1F
        call c,$04F7                 ; $04DF : DC F7 04 | Bit 2 set = Trigger bit 2 sound
        rra                          ; $04E2 : 1F
        call c,$0634                 ; $04E3 : DC 34 06 | Bit 3 set = Launch new ship
        rra                          ; $04E6 : 1F
        call c,$05E9                 ; $04E7 : DC E9 05 | Bit 4 set = Reload torpedos
        rra                          ; $04EA : 1F
        call c,$0573                 ; $04EB : DC 73 05 | Bit 5 set = Increment $2000 counter
        rra                          ; $04EE : 1F
        call c,$056C                 ; $04EF : DC 6C 05 | Bit 6 set = Initialize $2000 counter
        rra                          ; $04F2 : 1F
        call c,$0511                 ; $04F3 : DC 11 05 | Bit 7 set = Game time over
        ret                          ; $04F6 : C9
L04F7:
        push af                      ; $04F7 : F5
        ld hl,$2026                  ; $04F8 : 21 26 20
        ld a,(hl)                    ; $04FB : 7E
        and a                        ; $04FC : A7
        jp z,$050F                   ; $04FD : CA 0F 05 | Do nothing
        dec (hl)                     ; $0500 : 35
        ld a,$04                     ; $0501 : 3E 04
        out ($05),a                  ; $0503 : D3 05 | Audio outputs
        ld a,$19                     ; $0505 : 3E 19
        ld ($2023),a                 ; $0507 : 32 23 20 | Set timer
        ld a,$0F                     ; $050A : 3E 0F
        ld ($2025),a                 ; $050C : 32 25 20 | Set timer
L050F:
        pop af                       ; $050F : F1
        ret                          ; $0510 : C9
L0511:
        ld hl,$202E                  ; $0511 : 21 2E 20
        ld a,(hl)                    ; $0514 : 7E
        and a                        ; $0515 : A7
        jp nz,$053D                  ; $0516 : C2 3D 05 | Jump if already extended time
        ld (hl),$01                  ; $0519 : 36 01 | Only 1 extend
        ld a,($2007)                 ; $051B : 3A 07 20 | Last IN1
        rrca                         ; $051E : 0F
        and $70                      ; $051F : E6 70 | Base score for extended time (00 = none)
        jp z,$053D                   ; $0521 : CA 3D 05 | Jump if no extended time
        add a,$09                    ; $0524 : C6 09 | $20 dip = $19(00) score
        ld hl,$202B                  ; $0526 : 21 2B 20 | Player score
        cp (hl)                      ; $0529 : BE
        jp nc,$053D                  ; $052A : D2 3D 05 | Jump if score lower than metric
        ld a,$20                     ; $052D : 3E 20
        ld ($2002),a                 ; $052F : 32 02 20 | Set game time
        ld hl,$0F33                  ; $0532 : 21 33 0F | EXTENDED_TIME
        ld de,$3C03                  ; $0535 : 11 03 3C
        ld a,$0C                     ; $0538 : 3E 0C
        jp $0B30                     ; $053A : C3 30 0B | Draw string hl @ de, length a
L053D:
        ld hl,$20C9                  ; $053D : 21 C9 20
        ld bc,$001E                  ; $0540 : 01 1E 00
L0543:
        add hl,bc                    ; $0543 : 09
        ld a,l                       ; $0544 : 7D
        cp $5F                       ; $0545 : FE 5F
        jp z,$055C                   ; $0547 : CA 5C 05
        ld a,(hl)                    ; $054A : 7E
        and a                        ; $054B : A7
        jp p,$0543                   ; $054C : F2 43 05
        xor a                        ; $054F : AF
        ld ($2021),a                 ; $0550 : 32 21 20
        ld ($202D),a                 ; $0553 : 32 2D 20 | Torpedo status
        ld a,$01                     ; $0556 : 3E 01
        ld ($2002),a                 ; $0558 : 32 02 20
        ret                          ; $055B : C9

; -----------------------------------------------------------------------------
; SELECT_INITIAL_GAME_SCRIPT ($055C) - Point the game-program cursor at the initial script
; -----------------------------------------------------------------------------
SELECT_INITIAL_GAME_SCRIPT:
        ld hl,$0929                  ; $055C : 21 29 09
        ld ($2000),hl                ; $055F : 22 00 20
        ld a,($202B)                 ; $0562 : 3A 2B 20 | Player score
        ld hl,$2006                  ; $0565 : 21 06 20 | High score
        cp (hl)                      ; $0568 : BE
        ret c                        ; $0569 : D8
        ld (hl),a                    ; $056A : 77 | Write new score
        ret                          ; $056B : C9

; -----------------------------------------------------------------------------
; SELECT_FOLLOWUP_GAME_SCRIPT ($056C) - Select follow-up interpreted command stream
; -----------------------------------------------------------------------------
SELECT_FOLLOWUP_GAME_SCRIPT:
        ld hl,$0963                  ; $056C : 21 63 09
        ld ($2000),hl                ; $056F : 22 00 20
        ret                          ; $0572 : C9

; -----------------------------------------------------------------------------
; ADVANCE_GAME_SCRIPT_CURSOR ($0573) - Advance game-program cursor by one byte
; -----------------------------------------------------------------------------
ADVANCE_GAME_SCRIPT_CURSOR:
        ld hl,($2000)                ; $0573 : 2A 00 20
        inc hl                       ; $0576 : 23
        ld ($2000),hl                ; $0577 : 22 00 20
        ret                          ; $057A : C9
        ret z                        ; $057B : C8 | Not pressed
        ld a,($2002)                 ; $057C : 3A 02 20 | Game timer
        and a                        ; $057F : A7
        ret z                        ; $0580 : C8 | Not in game mode
        ld a,($2021)                 ; $0581 : 3A 21 20
        and a                        ; $0584 : A7
        ret nz                       ; $0585 : C0 | Missile already active?
        ld hl,$202D                  ; $0586 : 21 2D 20 | Torpedo status
        ld a,(hl)                    ; $0589 : 7E
        and $1F                      ; $058A : E6 1F
        ret z                        ; $058C : C8 | ??
        ld a,(hl)                    ; $058D : 7E
        and $0F                      ; $058E : E6 0F | Mask torp bits
        rra                          ; $0590 : 1F
        ld b,$20                     ; $0591 : 06 20 | Bit 5 = Reload
        and a                        ; $0593 : A7
        jp z,$0599                   ; $0594 : CA 99 05
        ld b,$10                     ; $0597 : 06 10 | Bit 4 = Ready
L0599:
        or b                         ; $0599 : B0
        ld (hl),a                    ; $059A : 77
        out ($02),a                  ; $059B : D3 02 | Torpedo display
        ld hl,$2021                  ; $059D : 21 21 20
        ld (hl),$08                  ; $05A0 : 36 08
        and $10                      ; $05A2 : E6 10
        jp nz,$05A9                  ; $05A4 : C2 A9 05
        ld (hl),$3C                  ; $05A7 : 36 3C
L05A9:
        ld a,$02                     ; $05A9 : 3E 02
        out ($05),a                  ; $05AB : D3 05 | Audio outputs
        ld a,$0F                     ; $05AD : 3E 0F
        ld ($2025),a                 ; $05AF : 32 25 20 | Set timer
        ld hl,$20C9                  ; $05B2 : 21 C9 20
        ld de,$001E                  ; $05B5 : 11 1E 00
L05B8:
        add hl,de                    ; $05B8 : 19
        ld a,(hl)                    ; $05B9 : 7E
        and a                        ; $05BA : A7
        jp m,$05B8                   ; $05BB : FA B8 05
        ld de,$0008                  ; $05BE : 11 08 00
        add hl,de                    ; $05C1 : 19
        ld (hl),$0E                  ; $05C2 : 36 0E
        dec hl                       ; $05C4 : 2B
        ld (hl),$75                  ; $05C5 : 36 75
        dec hl                       ; $05C7 : 2B
        ld (hl),$9C                  ; $05C8 : 36 9C
        dec hl                       ; $05CA : 2B
        ld (hl),$E0                  ; $05CB : 36 E0
        dec hl                       ; $05CD : 2B
        ld (hl),$FA                  ; $05CE : 36 FA
        dec hl                       ; $05D0 : 2B
        dec hl                       ; $05D1 : 2B
        ld de,$0F5E                  ; $05D2 : 11 5E 0F | Grey code table?
        ex de,hl                     ; $05D5 : EB
        ld a,($2008)                 ; $05D6 : 3A 08 20
        and $1F                      ; $05D9 : E6 1F
        ld c,a                       ; $05DB : 4F
        ld b,$00                     ; $05DC : 06 00
        add hl,bc                    ; $05DE : 09
        ld a,(hl)                    ; $05DF : 7E
        ex de,hl                     ; $05E0 : EB
        ld (hl),a                    ; $05E1 : 77
        dec hl                       ; $05E2 : 2B
        ld (hl),$00                  ; $05E3 : 36 00
        dec hl                       ; $05E5 : 2B
        ld (hl),$C0                  ; $05E6 : 36 C0
        ret                          ; $05E8 : C9
L05E9:
        push af                      ; $05E9 : F5
        ld hl,$202D                  ; $05EA : 21 2D 20 | Torpedo status
        ld a,(hl)                    ; $05ED : 7E
        and $10                      ; $05EE : E6 10 | Check ready
        jp nz,$05FF                  ; $05F0 : C2 FF 05
        ld a,$1F                     ; $05F3 : 3E 1F | Reset torpedo status
        out ($02),a                  ; $05F5 : D3 02 | Torpedo lamps
        ld (hl),a                    ; $05F7 : 77
        ld a,$08                     ; $05F8 : 3E 08
        out ($05),a                  ; $05FA : D3 05 | Audio outputs
        call $07EA                   ; $05FC : CD EA 07
L05FF:
        pop af                       ; $05FF : F1
        ret                          ; $0600 : C9

; -----------------------------------------------------------------------------
; RESET_SOUND_OUTPUTS ($0601) - Clear discrete sound output ports
; -----------------------------------------------------------------------------
RESET_SOUND_OUTPUTS:
        push af                      ; $0601 : F5
        xor a                        ; $0602 : AF
        out ($05),a                  ; $0603 : D3 05 | Audio outputs
        out ($01),a                  ; $0605 : D3 01 | Explosion lamp
        ld a,($202D)                 ; $0607 : 3A 2D 20 | Torpedo status
        out ($02),a                  ; $060A : D3 02 | Periscope lamp
        pop af                       ; $060C : F1
        ret                          ; $060D : C9

; -----------------------------------------------------------------------------
; PROCESS_ACTIVE_GRAPHICS ($060E) - Scan active graphic records
; -----------------------------------------------------------------------------
PROCESS_ACTIVE_GRAPHICS:
        push af                      ; $060E : F5
        ld hl,$21F0                  ; $060F : 21 F0 21
L0612:
        ld a,(hl)                    ; $0612 : 7E
        and a                        ; $0613 : A7
        jp z,$0632                   ; $0614 : CA 32 06
        ld (hl),$00                  ; $0617 : 36 00
        inc hl                       ; $0619 : 23
        ld d,a                       ; $061A : 57
        ld e,(hl)                    ; $061B : 5E
        ld (hl),$00                  ; $061C : 36 00
        inc hl                       ; $061E : 23
        cp $2C                       ; $061F : FE 2C
        ld bc,$0A03                  ; $0621 : 01 03 0A | 20 x 3 byte area  (after ship hit)
        jp c,$062A                   ; $0624 : DA 2A 06
        ld bc,$2005                  ; $0627 : 01 05 20 | 32 x 5 byte area  (after mine hit)
L062A:
        ex de,hl                     ; $062A : EB
        call $0A3F                   ; $062B : CD 3F 0A | Clear area at hl
        ex de,hl                     ; $062E : EB
        jp $0612                     ; $062F : C3 12 06 | Repeat
L0632:
        pop af                       ; $0632 : F1
        ret                          ; $0633 : C9

; -----------------------------------------------------------------------------
; UPDATE_GAME_SOUND ($0634) - Update discrete sound settings
; -----------------------------------------------------------------------------
UPDATE_GAME_SOUND:
        push af                      ; $0634 : F5
        ld a,($2003)                 ; $0635 : 3A 03 20
        and $0F                      ; $0638 : E6 0F
        or $50                       ; $063A : F6 50
        ld ($2022),a                 ; $063C : 32 22 20 | Set counter
        ld bc,$2029                  ; $063F : 01 29 20 | Ship type loc
        ld a,(bc)                    ; $0642 : 0A | Get ship index
        inc a                        ; $0643 : 3C | Increment
        cp $07                       ; $0644 : FE 07 | Max = 6
        jp nz,$064A                  ; $0646 : C2 4A 06
        xor a                        ; $0649 : AF | Set to 0
L064A:
        ld (bc),a                    ; $064A : 02 | Store ship index
        ld hl,$0FDE                  ; $064B : 21 DE 0F | Ship type table
        add a,l                      ; $064E : 85
        ld l,a                       ; $064F : 6F
        ld a,(hl)                    ; $0650 : 7E | Get ship type
        ld b,a                       ; $0651 : 47 | Stash in b
        cp $06                       ; $0652 : FE 06 | Is small / fast?
        jp nz,$066B                  ; $0654 : C2 6B 06 | No = jump
        ld a,$04                     ; $0657 : 3E 04
        out ($05),a                  ; $0659 : D3 05 | Audio outputs
        ld a,$19                     ; $065B : 3E 19
        ld ($2023),a                 ; $065D : 32 23 20 | Set timer
        ld a,$02                     ; $0660 : 3E 02
        ld ($2026),a                 ; $0662 : 32 26 20 | Set timer
        ld a,$0F                     ; $0665 : 3E 0F
        ld ($2025),a                 ; $0667 : 32 25 20 | Set timer
        ld a,b                       ; $066A : 78

; -----------------------------------------------------------------------------
; SELECT_OBJECT_RECORD ($066B) - Select one object record using a fixed stride
; -----------------------------------------------------------------------------
SELECT_OBJECT_RECORD:
        ld hl,$202C                  ; $066B : 21 2C 20
        ld de,$000D                  ; $066E : 11 0D 00
L0671:
        add hl,de                    ; $0671 : 19
        dec a                        ; $0672 : 3D
        jp nz,$0671                  ; $0673 : C2 71 06
        ld a,b                       ; $0676 : 78
        ex de,hl                     ; $0677 : EB
        ld hl,$201E                  ; $0678 : 21 1E 20 | Current ship move index
        ld a,(hl)                    ; $067B : 7E | Read ship move index
        inc (hl)                     ; $067C : 34 | Increment ship move index
        ld hl,$0F7E                  ; $067D : 21 7E 0F | Even ship move table?
        rra                          ; $0680 : 1F
        jp nc,$068B                  ; $0681 : D2 8B 06
        ld hl,$0FAE                  ; $0684 : 21 AE 0F | Odd ship move table?
        ld a,b                       ; $0687 : 78
        or $10                       ; $0688 : F6 10 | Set direction bit
        ld b,a                       ; $068A : 47
L068B:
        ld a,b                       ; $068B : 78
        dec a                        ; $068C : 3D | a = 0-5 / 10-14
        rlca                         ; $068D : 07
        rlca                         ; $068E : 07
        rlca                         ; $068F : 07
        and $38                      ; $0690 : E6 38 | Clear low bits
        add a,l                      ; $0692 : 85
        ld l,a                       ; $0693 : 6F
        ld c,$08                     ; $0694 : 0E 08

; -----------------------------------------------------------------------------
; COPY_OBJECT_RECORD ($0696) - Copy bytes into an object record
; -----------------------------------------------------------------------------
COPY_OBJECT_RECORD:
        ld a,(hl)                    ; $0696 : 7E
        inc hl                       ; $0697 : 23
        ld (de),a                    ; $0698 : 12
        dec de                       ; $0699 : 1B
        dec c                        ; $069A : 0D
        jp nz,$0696                  ; $069B : C2 96 06
        ld a,b                       ; $069E : 78
        or $C0                       ; $069F : F6 C0 | B7 = moving, B6 = don't clear, B5 = ??
        ld (de),a                    ; $06A1 : 12 | Store ship type?
        pop af                       ; $06A2 : F1
        ret                          ; $06A3 : C9

; -----------------------------------------------------------------------------
; CLEAR_OBJECT_RECORD ($06A4) - Clear a selected object record
; -----------------------------------------------------------------------------
CLEAR_OBJECT_RECORD:
        ld hl,$21C1                  ; $06A4 : 21 C1 21
L06A7:
        ld a,(hl)                    ; $06A7 : 7E
        and a                        ; $06A8 : A7
        ret z                        ; $06A9 : C8 | Skip if $21C1 = 00
        ld (hl),$00                  ; $06AA : 36 00 | Clear $21C1
        inc hl                       ; $06AC : 23
        ld d,(hl)                    ; $06AD : 56 | ($21C2) -> d
        push hl                      ; $06AE : E5
        ld hl,$2024                  ; $06AF : 21 24 20
        ld bc,$000D                  ; $06B2 : 01 0D 00
L06B5:
        add hl,bc                    ; $06B5 : 09
        dec a                        ; $06B6 : 3D
        jp nz,$06B5                  ; $06B7 : C2 B5 06
        ld bc,$0008                  ; $06BA : 01 08 00
        add hl,bc                    ; $06BD : 09
        ld (hl),$0E                  ; $06BE : 36 0E
        dec hl                       ; $06C0 : 2B
        ld (hl),$55                  ; $06C1 : 36 55
        dec hl                       ; $06C3 : 2B
        dec hl                       ; $06C4 : 2B
        dec hl                       ; $06C5 : 2B
        ld (hl),$01                  ; $06C6 : 36 01
        dec hl                       ; $06C8 : 2B
        dec hl                       ; $06C9 : 2B
        ld (hl),d                    ; $06CA : 72
        dec hl                       ; $06CB : 2B
        ld (hl),$00                  ; $06CC : 36 00
        dec hl                       ; $06CE : 2B
        ld b,(hl)                    ; $06CF : 46
        ld (hl),$E0                  ; $06D0 : 36 E0
        ld a,($2002)                 ; $06D2 : 3A 02 20 | Ship hit score?
        and a                        ; $06D5 : A7
        jp nz,$06DB                  ; $06D6 : C2 DB 06
        pop hl                       ; $06D9 : E1
        ret                          ; $06DA : C9
L06DB:
        ld a,b                       ; $06DB : 78
        ld bc,$0F57                  ; $06DC : 01 57 0F | Ship hit score table
        and $07                      ; $06DF : E6 07
        add a,c                      ; $06E1 : 81
        ld c,a                       ; $06E2 : 4F | bc = index into table
        ld de,$21E9                  ; $06E3 : 11 E9 21
        call $0A82                   ; $06E6 : CD 82 0A
        ld a,$30                     ; $06E9 : 3E 30
        ld (de),a                    ; $06EB : 12
        inc de                       ; $06EC : 13
        ld (de),a                    ; $06ED : 12
        ld a,(bc)                    ; $06EE : 0A
        ld hl,$202B                  ; $06EF : 21 2B 20 | Player score
        add a,(hl)                   ; $06F2 : 86 | Add a
        daa                          ; $06F3 : 27
        ld (hl),a                    ; $06F4 : 77 | Store
        pop hl                       ; $06F5 : E1
        ld c,(hl)                    ; $06F6 : 4E
        inc hl                       ; $06F7 : 23
        ld b,(hl)                    ; $06F8 : 46
        inc hl                       ; $06F9 : 23
        push hl                      ; $06FA : E5
        ld a,b                       ; $06FB : 78
        add a,$20                    ; $06FC : C6 20
        ld hl,$09C2                  ; $06FE : 21 C2 09 | Explosion lamp 0-7 table
        jp c,$0707                   ; $0701 : DA 07 07
        ld hl,$09BA                  ; $0704 : 21 BA 09 | Explosion lamp 8-F table
L0707:
        ld a,c                       ; $0707 : 79
        rlca                         ; $0708 : 07
        rlca                         ; $0709 : 07
        rlca                         ; $070A : 07
        and $07                      ; $070B : E6 07
        add a,l                      ; $070D : 85
        ld l,a                       ; $070E : 6F
        ld a,(hl)                    ; $070F : 7E
        out ($01),a                  ; $0710 : D3 01 | Explosion lamp
        ld a,$01                     ; $0712 : 3E 01
        out ($05),a                  ; $0714 : D3 05 | Audio write
        ld a,$1E                     ; $0716 : 3E 1E
        ld ($2025),a                 ; $0718 : 32 25 20 | Set timer
        ld a,b                       ; $071B : 78
        ld d,$24                     ; $071C : 16 24
        add a,$20                    ; $071E : C6 20
        jp m,$0725                   ; $0720 : FA 25 07
        ld d,$28                     ; $0723 : 16 28
L0725:
        ld a,c                       ; $0725 : 79
        rrca                         ; $0726 : 0F
        rrca                         ; $0727 : 0F
        rrca                         ; $0728 : 0F
        and $1F                      ; $0729 : E6 1F
        jp z,$072F                   ; $072B : CA 2F 07
        dec a                        ; $072E : 3D
L072F:
        cp $1E                       ; $072F : FE 1E
        jp nz,$0735                  ; $0731 : C2 35 07
        dec a                        ; $0734 : 3D
L0735:
        or $A0                       ; $0735 : F6 A0
        ld e,a                       ; $0737 : 5F
        call $07DB                   ; $0738 : CD DB 07
        ld a,$2D                     ; $073B : 3E 2D
        ld ($2024),a                 ; $073D : 32 24 20
        ld hl,$21EA                  ; $0740 : 21 EA 21
        ld a,$03                     ; $0743 : 3E 03
        call $0B30                   ; $0745 : CD 30 0B | Draw string hl @ de, length a
        pop hl                       ; $0748 : E1
        jp $06A7                     ; $0749 : C3 A7 06
L074C:
        ld hl,$21A3                  ; $074C : 21 A3 21
L074F:
        ld a,(hl)                    ; $074F : 7E
        and a                        ; $0750 : A7
        ret z                        ; $0751 : C8
        inc hl                       ; $0752 : 23
        add a,$10                    ; $0753 : C6 10
        rlca                         ; $0755 : 07
        rlca                         ; $0756 : 07
        rlca                         ; $0757 : 07
        and $07                      ; $0758 : E6 07
        ld de,$2067                  ; $075A : 11 67 20
        ld bc,$000D                  ; $075D : 01 0D 00
        ex de,hl                     ; $0760 : EB
L0761:
        add hl,bc                    ; $0761 : 09
        add hl,bc                    ; $0762 : 09
        dec a                        ; $0763 : 3D
        jp nz,$0761                  ; $0764 : C2 61 07
        ld a,(de)                    ; $0767 : 1A
        sub $08                      ; $0768 : D6 08
        sub (hl)                     ; $076A : 96
        cp $EC                       ; $076B : FE EC
        jp nc,$0771                  ; $076D : D2 71 07
        add hl,bc                    ; $0770 : 09
L0771:
        dec hl                       ; $0771 : 2B
        dec hl                       ; $0772 : 2B
        ld (hl),$00                  ; $0773 : 36 00
        ex de,hl                     ; $0775 : EB
        dec hl                       ; $0776 : 2B
        ld a,(hl)                    ; $0777 : 7E
        add a,$30                    ; $0778 : C6 30
        and $F0                      ; $077A : E6 F0
        ld d,a                       ; $077C : 57
        ld (hl),$00                  ; $077D : 36 00
        inc hl                       ; $077F : 23
        ld e,(hl)                    ; $0780 : 5E
        inc hl                       ; $0781 : 23
        push hl                      ; $0782 : E5
        call $0A00                   ; $0783 : CD 00 0A
        ld a,e                       ; $0786 : 7B
        and $1F                      ; $0787 : E6 1F
        jp z,$0796                   ; $0789 : CA 96 07
        dec a                        ; $078C : 3D
        jp z,$0796                   ; $078D : CA 96 07
L0790:
        dec a                        ; $0790 : 3D
        cp $1C                       ; $0791 : FE 1C
        jp p,$0790                   ; $0793 : F2 90 07
L0796:
        ld e,a                       ; $0796 : 5F
        call $07DB                   ; $0797 : CD DB 07
        ld b,d                       ; $079A : 42
        inc b                        ; $079B : 04
        inc b                        ; $079C : 04
        ld c,e                       ; $079D : 4B
        inc c                        ; $079E : 0C
        push bc                      ; $079F : C5
        ld a,e                       ; $07A0 : 7B
        add a,$60                    ; $07A1 : C6 60
        ld e,a                       ; $07A3 : 5F
        push de                      ; $07A4 : D5
        ld b,d                       ; $07A5 : 42
        inc c                        ; $07A6 : 0C
        push bc                      ; $07A7 : C5
        ld a,$1E                     ; $07A8 : 3E 1E
        ld ($2025),a                 ; $07AA : 32 25 20 | Set timer
        ld a,$0F                     ; $07AD : 3E 0F
        ld ($2024),a                 ; $07AF : 32 24 20
        ld a,$10                     ; $07B2 : 3E 10
        out ($05),a                  ; $07B4 : D3 05 | Sound write
        ld a,e                       ; $07B6 : 7B
        and $02                      ; $07B7 : E6 02 | Mask bit 1
        ld hl,$0F40                  ; $07B9 : 21 40 0F | $0F40 or $0F42
        add a,l                      ; $07BC : 85
        ld l,a                       ; $07BD : 6F | hl = ZAP or WAM
        ld e,(hl)                    ; $07BE : 5E
        inc hl                       ; $07BF : 23
        ld d,(hl)                    ; $07C0 : 56
        ex de,hl                     ; $07C1 : EB | hl = table entry
        pop de                       ; $07C2 : D1
        ld a,(hl)                    ; $07C3 : 7E
        inc hl                       ; $07C4 : 23
        call $0B30                   ; $07C5 : CD 30 0B | Draw string hl @ de, length a
        pop de                       ; $07C8 : D1
        ld a,(hl)                    ; $07C9 : 7E
        inc hl                       ; $07CA : 23
        call $0B30                   ; $07CB : CD 30 0B | Draw string hl @ de, length a
        pop de                       ; $07CE : D1
        ld hl,$0EB5                  ; $07CF : 21 B5 0E
        ld a,$03                     ; $07D2 : 3E 03
        call $0B30                   ; $07D4 : CD 30 0B | Draw string hl @ de, length a
        pop hl                       ; $07D7 : E1
        jp $074F                     ; $07D8 : C3 4F 07

; -----------------------------------------------------------------------------
; SEARCH_ACTIVE_OBJECTS ($07DB) - Find a matching active object
; -----------------------------------------------------------------------------
SEARCH_ACTIVE_OBJECTS:
        ld hl,$21F0                  ; $07DB : 21 F0 21
L07DE:
        ld a,(hl)                    ; $07DE : 7E
        inc hl                       ; $07DF : 23
        or (hl)                      ; $07E0 : B6
        inc hl                       ; $07E1 : 23
        jp nz,$07DE                  ; $07E2 : C2 DE 07
        dec hl                       ; $07E5 : 2B
        ld (hl),e                    ; $07E6 : 73
        dec hl                       ; $07E7 : 2B
        ld (hl),d                    ; $07E8 : 72
        ret                          ; $07E9 : C9

; -----------------------------------------------------------------------------
; UPDATE_SCORE_DIFFICULTY ($07EA) - Derive gameplay difficulty from score state
; -----------------------------------------------------------------------------
UPDATE_SCORE_DIFFICULTY:
        ld a,($202B)                 ; $07EA : 3A 2B 20 | Player score
        cp $40                       ; $07ED : FE 40
        jp c,$07F4                   ; $07EF : DA F4 07
        ld a,$39                     ; $07F2 : 3E 39 | Min of score or $39
L07F4:
        ld ($202C),a                 ; $07F4 : 32 2C 20
        ld hl,$207F                  ; $07F7 : 21 7F 20 | 1st mine sprite
        ld de,$5050                  ; $07FA : 11 50 50
L07FD:
        ld a,(hl)                    ; $07FD : 7E
        and a                        ; $07FE : A7
        jp m,$0835                   ; $07FF : FA 35 08
L0802:
        ld bc,$0008                  ; $0802 : 01 08 00
        add hl,bc                    ; $0805 : 09
        ld (hl),$0E                  ; $0806 : 36 0E | Mine MSB (+8)
        dec hl                       ; $0808 : 2B
        ld (hl),$A3                  ; $0809 : 36 A3 | Mine LSB (+7)
        dec hl                       ; $080B : 2B
        dec hl                       ; $080C : 2B
        ld (hl),e                    ; $080D : 73 | Y Pos (+5)
        dec hl                       ; $080E : 2B
        ld (hl),b                    ; $080F : 70 | Delta Y (+4)
        dec hl                       ; $0810 : 2B
        dec hl                       ; $0811 : 2B
        ld (hl),d                    ; $0812 : 72 | X Pos (+2)
        dec hl                       ; $0813 : 2B
        ld (hl),$01                  ; $0814 : 36 01 | Delta X (+1)
        dec hl                       ; $0816 : 2B
        ld (hl),$80                  ; $0817 : 36 80 | Flags
        ld a,d                       ; $0819 : 7A
        add a,$51                    ; $081A : C6 51
        ld d,a                       ; $081C : 57
        rra                          ; $081D : 1F
        jp c,$082E                   ; $081E : DA 2E 08
        ld a,($202C)                 ; $0821 : 3A 2C 20
        sub $10                      ; $0824 : D6 10
        ret m                        ; $0826 : F8
        ld ($202C),a                 ; $0827 : 32 2C 20
        ld a,e                       ; $082A : 7B
        add a,$20                    ; $082B : C6 20
        ld e,a                       ; $082D : 5F
L082E:
        ld bc,$000D                  ; $082E : 01 0D 00 | Increment
        add hl,bc                    ; $0831 : 09 | Next mine
        jp $07FD                     ; $0832 : C3 FD 07 | More mines!
L0835:
        push hl                      ; $0835 : E5
        push de                      ; $0836 : D5
        inc hl                       ; $0837 : 23
        inc hl                       ; $0838 : 23
        ld e,(hl)                    ; $0839 : 5E
        inc hl                       ; $083A : 23
        inc hl                       ; $083B : 23
        inc hl                       ; $083C : 23
        ld d,(hl)                    ; $083D : 56
        call $0A00                   ; $083E : CD 00 0A
        ex de,hl                     ; $0841 : EB
        ld bc,$1002                  ; $0842 : 01 02 10 | 16 x 2 byte area
        call $0A3F                   ; $0845 : CD 3F 0A | Clear area at hl
        pop de                       ; $0848 : D1
        pop hl                       ; $0849 : E1
        jp $0802                     ; $084A : C3 02 08
        ret z                        ; $084D : C8
        xor a                        ; $084E : AF
        ld ($2006),a                 ; $084F : 32 06 20
        ld a,($2010)                 ; $0852 : 3A 10 20
        and a                        ; $0855 : A7
        ret z                        ; $0856 : C8
        ld hl,$21E9                  ; $0857 : 21 E9 21
        push hl                      ; $085A : E5
        ld bc,$0430                  ; $085B : 01 30 04
L085E:
        ld (hl),c                    ; $085E : 71
        inc hl                       ; $085F : 23
        dec b                        ; $0860 : 05
        jp nz,$085E                  ; $0861 : C2 5E 08
        pop hl                       ; $0864 : E1
        ld de,$3E25                  ; $0865 : 11 25 3E
        ld a,$04                     ; $0868 : 3E 04
        jp $0B30                     ; $086A : C3 30 0B | Draw string hl @ de, length a
        ex de,hl                     ; $086D : EB | Sequence back to hl
        ld ($2000),hl                ; $086E : 22 00 20 | Store
        ld a,($2003)                 ; $0871 : 3A 03 20 | 
        and $07                      ; $0874 : E6 07 | Mask low 3 bits
        cp $07                       ; $0876 : FE 07 | == $07?
        jp nz,$087C                  ; $0878 : C2 7C 08
        xor a                        ; $087B : AF | Clear
L087C:
        ld ($2029),a                 ; $087C : 32 29 20 | Write
        ret                          ; $087F : C9

; -----------------------------------------------------------------------------
; RESET_GAME_STATE ($0880) - Reset game state and script pointer
; -----------------------------------------------------------------------------
RESET_GAME_STATE:
        di                           ; $0880 : F3
        ex de,hl                     ; $0881 : EB | Stash hl in de
        ld ($2000),hl                ; $0882 : 22 00 20
        xor a                        ; $0885 : AF
        out ($02),a                  ; $0886 : D3 02 | Clear periscope lamp
        out ($05),a                  ; $0888 : D3 05 | Clear audio latches
        out ($01),a                  ; $088A : D3 01 | Clear explosion lamp
        pop hl                       ; $088C : E1 | (Return address)
        ld bc,$0000                  ; $088D : 01 00 00
        ld de,$0000                  ; $0890 : 11 00 00
        ld a,$10                     ; $0893 : 3E 10
        ld sp,$4010                  ; $0895 : 31 10 40 | Clear $4010 down to $2011
L0898:
        push bc                      ; $0898 : C5
        inc de                       ; $0899 : 13
        cp d                         ; $089A : BA
        jp nz,$0898                  ; $089B : C2 98 08 | Loop
        ld sp,$2400                  ; $089E : 31 00 24
        jp (hl)                      ; $08A1 : E9

; -----------------------------------------------------------------------------
; INITIALIZE_GAME_STATE ($08A2) - Initialize RAM and launch the main control path
; -----------------------------------------------------------------------------
INITIALIZE_GAME_STATE:
        pop hl                       ; $08A2 : E1
        ld ($2009),hl                ; $08A3 : 22 09 20
        call $0880                   ; $08A6 : CD 80 08
        ld hl,($2009)                ; $08A9 : 2A 09 20
        push hl                      ; $08AC : E5
        ld hl,$0F04                  ; $08AD : 21 04 0F | Water
        ld de,$27E0                  ; $08B0 : 11 E0 27
        ld a,$20                     ; $08B3 : 3E 20
        jp $0B30                     ; $08B5 : C3 30 0B | Draw string hl @ de, length a

; -----------------------------------------------------------------------------
; POLL_PLAYER_INPUT ($08B8) - Poll player input port
; -----------------------------------------------------------------------------
POLL_PLAYER_INPUT:
        in a,($01)                   ; $08B8 : DB 01 | IN0
        ld b,a                       ; $08BA : 47
        in a,($01)                   ; $08BB : DB 01 | IN0
        ld hl,$2008                  ; $08BD : 21 08 20 | Last IN0
        ld de,$09DA                  ; $08C0 : 11 DA 09 | Jump table for IN0
        cp b                         ; $08C3 : B8
        call z,$0B05                 ; $08C4 : CC 05 0B | Handle inputs
        ret                          ; $08C7 : C9 | (reset)
        ret z                        ; $08C8 : C8 | No coin
        ld a,$20                     ; $08C9 : 3E 20
        out ($05),a                  ; $08CB : D3 05
        ld a,$0F                     ; $08CD : 3E 0F
        ld ($2025),a                 ; $08CF : 32 25 20 | Set timer
        ld a,($2007)                 ; $08D2 : 3A 07 20
        ld b,a                       ; $08D5 : 47
        ld hl,$2004                  ; $08D6 : 21 04 20
        inc (hl)                     ; $08D9 : 34
        and $04                      ; $08DA : E6 04
        jp z,$08E2                   ; $08DC : CA E2 08
        ld a,(hl)                    ; $08DF : 7E
        rrca                         ; $08E0 : 0F
        ret c                        ; $08E1 : D8
L08E2:
        ld (hl),$00                  ; $08E2 : 36 00
        inc hl                       ; $08E4 : 23
        inc (hl)                     ; $08E5 : 34
        ld a,b                       ; $08E6 : 78
        and $08                      ; $08E7 : E6 08
        jp z,$08F4                   ; $08E9 : CA F4 08
        inc (hl)                     ; $08EC : 34
        ld a,b                       ; $08ED : 78
        and $04                      ; $08EE : E6 04
        jp z,$08F4                   ; $08F0 : CA F4 08
        inc (hl)                     ; $08F3 : 34
L08F4:
        ld a,(hl)                    ; $08F4 : 7E
        and $0F                      ; $08F5 : E6 0F
        ld (hl),a                    ; $08F7 : 77
        ret z                        ; $08F8 : C8
        ld a,($2002)                 ; $08F9 : 3A 02 20
        and a                        ; $08FC : A7
        ret nz                       ; $08FD : C0
        ld hl,$2005                  ; $08FE : 21 05 20
        ld a,(hl)                    ; $0901 : 7E
        and a                        ; $0902 : A7
        jp z,$091A                   ; $0903 : CA 1A 09
L0906:
        dec (hl)                     ; $0906 : 35
        in a,($01)                   ; $0907 : DB 01 | IN1
        rlca                         ; $0909 : 07
        rlca                         ; $090A : 07
        and $03                      ; $090B : E6 03 | Game time dips
        ld de,$0F54                  ; $090D : 11 54 0F
        add a,e                      ; $0910 : 83
        ld e,a                       ; $0911 : 5F
        ld a,(de)                    ; $0912 : 1A
        ld ($2002),a                 ; $0913 : 32 02 20 | Store time
        ld ($202A),a                 ; $0916 : 32 2A 20 | Store time ?
        ret                          ; $0919 : C9

; -----------------------------------------------------------------------------
; CHECK_COIN_INPUT ($091A) - Examine coin-input bits
; -----------------------------------------------------------------------------
CHECK_COIN_INPUT:
        ld a,($2007)                 ; $091A : 3A 07 20
        and $0C                      ; $091D : E6 0C
        cp $0C                       ; $091F : FE 0C
        ret nz                       ; $0921 : C0
        dec hl                       ; $0922 : 2B
        ld a,(hl)                    ; $0923 : 7E
        and a                        ; $0924 : A7
        ret z                        ; $0925 : C8
        jp $0906                     ; $0926 : C3 06 09

; -----------------------------------------------------------------------------
; GAME_SCRIPT_STREAMS ($0929) - Interpreted game command bytes and inline operands; not native opcodes
; -----------------------------------------------------------------------------
GAME_SCRIPT_STREAMS:
        DB $04,$01,$B8,$0E,$30,$3E,$09,$05,$20,$33,$38,$E6 ; $0929 raw original bytes | interpreted command stream and inline operands
        DB $0E,$F1,$0E,$04,$1A,$CC,$0E,$02,$3C,$0A,$06,$20 ; $0935 raw original bytes | interpreted command stream and inline operands
        DB $E9,$21,$25,$3E,$0A,$2B,$20,$E9,$21,$35,$3E,$02 ; $0941 raw original bytes | interpreted command stream and inline operands
        DB $0F,$04,$09,$C3,$0E,$0B,$2C,$01,$1E,$00,$04,$09 ; $094D raw original bytes | interpreted command stream and inline operands
        DB $B8,$0E,$0B,$2C,$01,$1E,$00,$06,$4E,$09,$03,$04 ; $0959 raw original bytes | interpreted command stream and inline operands
        DB $08,$FC,$0E,$0C,$2C,$04,$0A,$CC,$0E,$02,$3C,$0A ; $0965 raw original bytes | interpreted command stream and inline operands
        DB $06,$20,$E9,$21,$25,$3E,$09,$05,$20,$33,$38,$E6 ; $0971 raw original bytes | interpreted command stream and inline operands
        DB $0E,$F1,$0E,$01,$5A,$00,$08,$09,$60,$20,$EB,$0D ; $097D raw original bytes | interpreted command stream and inline operands
        DB $20,$15,$00,$E0,$00,$01,$C4,$01,$5A,$00,$08,$09 ; $0989 raw original bytes | interpreted command stream and inline operands
        DB $EF,$20,$75,$0E,$9C,$E0,$FA,$00,$A8,$00,$C0,$01 ; $0995 raw original bytes | interpreted command stream and inline operands
        DB $B4,$00,$06,$63,$09,$01,$0F,$00,$03,$04,$09,$29 ; $09A1 raw original bytes | interpreted command stream and inline operands
        DB $0F,$0E,$3C,$07,$28,$22,$20,$07,$0A,$21,$20,$0B ; $09AD raw original bytes | interpreted command stream and inline operands
        DB $00,$48,$44,$42,$41,$88,$84,$82,$81,$18,$14,$12 ; $09B9 raw original bytes | lookup and command dispatch tables
        DB $11,$28,$24,$22,$21,$C8,$08,$F8,$08,$C7,$08,$C7 ; $09C5 raw original bytes | lookup and command dispatch tables
        DB $08,$4D,$08,$C7,$08,$C7,$08,$C7,$08,$C7,$08,$C7 ; $09D1 raw original bytes | lookup and command dispatch tables
        DB $08,$C7,$08,$C7,$08,$C7,$08,$7B,$05,$C7,$08 ; $09DD raw original bytes | lookup and command dispatch tables
; Game script/native handler pointer region begins here.

; -----------------------------------------------------------------------------
; GAME_COMMAND_HANDLER_TABLE ($09E8) - Indexed 16-bit native handler addresses, little endian
; -----------------------------------------------------------------------------
GAME_COMMAND_HANDLER_TABLE:
        DB $C7,$08,$7C,$0B,$72,$0B,$A2,$08,$22,$0B,$ED,$0A ; $09E8 raw original bytes | 16-bit native command handler vectors
        DB $86,$0B,$E1,$0A,$9F,$0A,$BC,$0A,$53,$0A,$6D,$08 ; $09F4 raw original bytes | 16-bit native command handler vectors
; -----------------------------------------------------------------------------
; BIT_SHIFT_SETUP ($0A00) - Set up bit-shift operands
; -----------------------------------------------------------------------------
BIT_SHIFT_SETUP:
        ld a,e                       ; $0A00 : 7B | Mask e
        and $07                      ; $0A01 : E6 07
        ld c,a                       ; $0A03 : 4F | Stash in a
        ld b,$03                     ; $0A04 : 06 03
L0A06:
        xor a                        ; $0A06 : AF | a=0, clc
        ld a,d                       ; $0A07 : 7A
        rra                          ; $0A08 : 1F
        ld d,a                       ; $0A09 : 57
        ld a,e                       ; $0A0A : 7B
        rra                          ; $0A0B : 1F
        ld e,a                       ; $0A0C : 5F
        dec b                        ; $0A0D : 05
        jp nz,$0A06                  ; $0A0E : C2 06 0A
        ld a,d                       ; $0A11 : 7A
        add a,$24                    ; $0A12 : C6 24
        ld d,a                       ; $0A14 : 57
        ret                          ; $0A15 : C9

; -----------------------------------------------------------------------------
; COPY_OBJECT_BYTES ($0A16) - Copy object data to destination
; -----------------------------------------------------------------------------
COPY_OBJECT_BYTES:
        push af                      ; $0A16 : F5 | Store count
        ld a,(hl)                    ; $0A17 : 7E | Get value
        ld (bc),a                    ; $0A18 : 02 | Store value
        inc bc                       ; $0A19 : 03
        ex de,hl                     ; $0A1A : EB
        or (hl)                      ; $0A1B : B6
        inc hl                       ; $0A1C : 23
        ld (de),a                    ; $0A1D : 12
        pop af                       ; $0A1E : F1 | count = a
        push hl                      ; $0A1F : E5
        ld hl,$0020                  ; $0A20 : 21 20 00
        add hl,de                    ; $0A23 : 19 | hl = de+$0020
        pop de                       ; $0A24 : D1 | de = old hl
        dec a                        ; $0A25 : 3D
        jp nz,$0A16                  ; $0A26 : C2 16 0A | loop
        ret                          ; $0A29 : C9

; -----------------------------------------------------------------------------
; COPY_GRAPHIC_BLOCK ($0A2A) - Copy rectangular graphics bytes
; -----------------------------------------------------------------------------
COPY_GRAPHIC_BLOCK:
        push bc                      ; $0A2A : C5
        push hl                      ; $0A2B : E5
L0A2C:
        ld a,(de)                    ; $0A2C : 1A
        inc de                       ; $0A2D : 13
        ld (hl),a                    ; $0A2E : 77
        inc hl                       ; $0A2F : 23
        dec c                        ; $0A30 : 0D
        jp nz,$0A2C                  ; $0A31 : C2 2C 0A
        pop hl                       ; $0A34 : E1
        ld bc,$0020                  ; $0A35 : 01 20 00
        add hl,bc                    ; $0A38 : 09
        pop bc                       ; $0A39 : C1
        dec b                        ; $0A3A : 05
        jp nz,$0A2A                  ; $0A3B : C2 2A 0A
        ret                          ; $0A3E : C9

; -----------------------------------------------------------------------------
; CLEAR_GRAPHIC_BLOCK ($0A3F) - Clear rectangular graphics bytes
; -----------------------------------------------------------------------------
CLEAR_GRAPHIC_BLOCK:
        xor a                        ; $0A3F : AF
L0A40:
        push bc                      ; $0A40 : C5
        push hl                      ; $0A41 : E5
L0A42:
        ld (hl),a                    ; $0A42 : 77
        inc hl                       ; $0A43 : 23
        dec c                        ; $0A44 : 0D
        jp nz,$0A42                  ; $0A45 : C2 42 0A
        pop hl                       ; $0A48 : E1
        ld bc,$0020                  ; $0A49 : 01 20 00
        add hl,bc                    ; $0A4C : 09
        pop bc                       ; $0A4D : C1
        dec b                        ; $0A4E : 05
        jp nz,$0A40                  ; $0A4F : C2 40 0A
        ret                          ; $0A52 : C9
        ex de,hl                     ; $0A53 : EB
        ld c,(hl)                    ; $0A54 : 4E | Read bc
        inc hl                       ; $0A55 : 23
        ld b,(hl)                    ; $0A56 : 46
        inc hl                       ; $0A57 : 23
        ld e,(hl)                    ; $0A58 : 5E | Read de
        inc hl                       ; $0A59 : 23
        ld d,(hl)                    ; $0A5A : 56
        dec hl                       ; $0A5B : 2B | Back up to use again
        call $0A82                   ; $0A5C : CD 82 0A | Draw BCD from bc at de
        ex de,hl                     ; $0A5F : EB | Last address now in hl
        call $0A7A                   ; $0A60 : CD 7A 0A | Replace space with zero
        inc hl                       ; $0A63 : 23
        ex de,hl                     ; $0A64 : EB | Last address now in de
        ld a,$30                     ; $0A65 : 3E 30
        ld (de),a                    ; $0A67 : 12 | Append zero
        inc de                       ; $0A68 : 13
        ld (de),a                    ; $0A69 : 12 | Append zero
        call $0ADC                   ; $0A6A : CD DC 0A | (hl, hl+1) -> de, hl+=2
        push de                      ; $0A6D : D5
        call $0ADC                   ; $0A6E : CD DC 0A | (hl, hl+1) -> de, hl+=2
        ld ($2000),hl                ; $0A71 : 22 00 20 | Next command
        pop hl                       ; $0A74 : E1
        ld a,$04                     ; $0A75 : 3E 04
        jp $0B30                     ; $0A77 : C3 30 0B | Draw string hl @ de, length a

; -----------------------------------------------------------------------------
; TEST_OBJECT_FLAGS ($0A7A) - Test object flag bits
; -----------------------------------------------------------------------------
TEST_OBJECT_FLAGS:
        dec hl                       ; $0A7A : 2B
        ld a,(hl)                    ; $0A7B : 7E
        and $40                      ; $0A7C : E6 40
        ret z                        ; $0A7E : C8
        ld (hl),$30                  ; $0A7F : 36 30
        ret                          ; $0A81 : C9
L0A82:
        ld a,(bc)                    ; $0A82 : 0A
        rra                          ; $0A83 : 1F
        rra                          ; $0A84 : 1F
        rra                          ; $0A85 : 1F
        rra                          ; $0A86 : 1F
        and $0F                      ; $0A87 : E6 0F | Mask high nybble
        jp nz,$0A8E                  ; $0A89 : C2 8E 0A
        ld a,$10                     ; $0A8C : 3E 10 | $40 -> blank

; -----------------------------------------------------------------------------
; CONVERT_SCORE_TO_DIGITS ($0A8E) - Convert score digits to display codes
; -----------------------------------------------------------------------------
CONVERT_SCORE_TO_DIGITS:
        add a,$30                    ; $0A8E : C6 30 | Decimal to ascii
        ld (de),a                    ; $0A90 : 12 | Store digit
        inc de                       ; $0A91 : 13 | Next screen loc
        ld a,(bc)                    ; $0A92 : 0A
        and $0F                      ; $0A93 : E6 0F | Mask low nybble
        jp nz,$0A9A                  ; $0A95 : C2 9A 0A
        ld a,$10                     ; $0A98 : 3E 10 | $40 -> blank
L0A9A:
        add a,$30                    ; $0A9A : C6 30 | Decimal to ascii
        ld (de),a                    ; $0A9C : 12 | Store digit
        inc de                       ; $0A9D : 13 | Next screen loc
        ret                          ; $0A9E : C9
        ex de,hl                     ; $0A9F : EB | Sequence address back to hl
        ld b,(hl)                    ; $0AA0 : 46 | Get count
        inc hl                       ; $0AA1 : 23
        dec b                        ; $0AA2 : 05
        dec b                        ; $0AA3 : 05
        call $0ADC                   ; $0AA4 : CD DC 0A | (hl, hl+1) -> de, hl+=2  (address)
        ld c,(hl)                    ; $0AA7 : 4E | Read first byte
        inc hl                       ; $0AA8 : 23
        ld a,(hl)                    ; $0AA9 : 7E | Read second byte
        inc hl                       ; $0AAA : 23
        ld (de),a                    ; $0AAB : 12 | Write first byte
        dec de                       ; $0AAC : 1B
        ld a,c                       ; $0AAD : 79
        ld (de),a                    ; $0AAE : 12 | Write second byte
        dec de                       ; $0AAF : 1B
L0AB0:
        ld a,(hl)                    ; $0AB0 : 7E | Loop for rest of count
        inc hl                       ; $0AB1 : 23
        ld (de),a                    ; $0AB2 : 12
        dec de                       ; $0AB3 : 1B
        dec b                        ; $0AB4 : 05
        jp nz,$0AB0                  ; $0AB5 : C2 B0 0A
        ld ($2000),hl                ; $0AB8 : 22 00 20 | Next command
        ret                          ; $0ABB : C9
        ex de,hl                     ; $0ABC : EB
        call $0ADC                   ; $0ABD : CD DC 0A | (hl, hl+1) -> de, hl+=2
        ld a,(de)                    ; $0AC0 : 1A
        call $0ADC                   ; $0AC1 : CD DC 0A | (hl, hl+1) -> de, hl+=2
        push de                      ; $0AC4 : D5
        call $0ADC                   ; $0AC5 : CD DC 0A | (hl, hl+1) -> de, hl+=2
        push de                      ; $0AC8 : D5
        call $0ADC                   ; $0AC9 : CD DC 0A | (hl, hl+1) -> de, hl+=2
        ld ($2000),hl                ; $0ACC : 22 00 20 | Next command
        ex de,hl                     ; $0ACF : EB
        and a                        ; $0AD0 : A7
        jp z,$0AD5                   ; $0AD1 : CA D5 0A | Draw first string?
        ex (sp),hl                   ; $0AD4 : E3
L0AD5:
        pop hl                       ; $0AD5 : E1
        pop de                       ; $0AD6 : D1
        ld a,$0B                     ; $0AD7 : 3E 0B | Length
        jp $0B30                     ; $0AD9 : C3 30 0B | Draw string hl @ de, length a
L0ADC:
        ld e,(hl)                    ; $0ADC : 5E
        inc hl                       ; $0ADD : 23
        ld d,(hl)                    ; $0ADE : 56
        inc hl                       ; $0ADF : 23
        ret                          ; $0AE0 : C9
        ld a,(de)                    ; $0AE1 : 1A | Next entry
        inc de                       ; $0AE2 : 13
        ex de,hl                     ; $0AE3 : EB
        ld c,(hl)                    ; $0AE4 : 4E | Next entry
        inc hl                       ; $0AE5 : 23
        ld b,(hl)                    ; $0AE6 : 46 | Next entry
        inc hl                       ; $0AE7 : 23
        ld ($2000),hl                ; $0AE8 : 22 00 20 | Store command
        ld (bc),a                    ; $0AEB : 02 | a -> (bc)
        ret                          ; $0AEC : C9
        ex de,hl                     ; $0AED : EB
        ld b,(hl)                    ; $0AEE : 46
        inc hl                       ; $0AEF : 23
        ld c,(hl)                    ; $0AF0 : 4E
        inc hl                       ; $0AF1 : 23
        ld a,(hl)                    ; $0AF2 : 7E
        inc hl                       ; $0AF3 : 23
        call $0ADC                   ; $0AF4 : CD DC 0A
        ld ($2000),hl                ; $0AF7 : 22 00 20
        ex de,hl                     ; $0AFA : EB
        ld (hl),$DB                  ; $0AFB : 36 DB
        inc hl                       ; $0AFD : 23
        ld (hl),c                    ; $0AFE : 71
        inc hl                       ; $0AFF : 23
        ld (hl),$C9                  ; $0B00 : 36 C9
        dec hl                       ; $0B02 : 2B
        dec hl                       ; $0B03 : 2B
        jp (hl)                      ; $0B04 : E9

; -----------------------------------------------------------------------------
; HANDLE_INPUT_CHANGE ($0B05) - Handle a change on an input bit
; -----------------------------------------------------------------------------
HANDLE_INPUT_CHANGE:
        xor (hl)                     ; $0B05 : AE
        ret z                        ; $0B06 : C8 | No changes
        ld c,a                       ; $0B07 : 4F | Stash IN0
        ld b,$01                     ; $0B08 : 06 01 | Bit being checked
L0B0A:
        ld a,c                       ; $0B0A : 79 | Restore IN0
        rrca                         ; $0B0B : 0F
        jp c,$0B18                   ; $0B0C : DA 18 0B | Bit is high
        ld c,a                       ; $0B0F : 4F | Stash IN0
        ld a,b                       ; $0B10 : 78 | Shift check bit
        rlca                         ; $0B11 : 07
        ld b,a                       ; $0B12 : 47
        inc de                       ; $0B13 : 13 | Advance jump table
        inc de                       ; $0B14 : 13
        jp $0B0A                     ; $0B15 : C3 0A 0B | Loop
L0B18:
        ld a,b                       ; $0B18 : 78 | Bit found to a
        xor (hl)                     ; $0B19 : AE | Clear bit
        ld (hl),a                    ; $0B1A : 77 | Store back
        and b                        ; $0B1B : A0 | Value of changed bit
        ex de,hl                     ; $0B1C : EB
        ld c,(hl)                    ; $0B1D : 4E
        inc hl                       ; $0B1E : 23
        ld h,(hl)                    ; $0B1F : 66
        ld l,c                       ; $0B20 : 69
        jp (hl)                      ; $0B21 : E9 | Handle changed bit
        ex de,hl                     ; $0B22 : EB | ($2000)+1 ->
        ld a,(hl)                    ; $0B23 : 7E
        inc hl                       ; $0B24 : 23
        call $0ADC                   ; $0B25 : CD DC 0A | (hl, hl+1) -> de, hl+=2
        push de                      ; $0B28 : D5
        call $0ADC                   ; $0B29 : CD DC 0A | (hl, hl,1) -> de, hl+=2
        ld ($2000),hl                ; $0B2C : 22 00 20 | Next command
        pop hl                       ; $0B2F : E1 | String src address

; -----------------------------------------------------------------------------
; RENDER_GAME_TEXT ($0B30) - Render an encoded text stream
; -----------------------------------------------------------------------------
RENDER_GAME_TEXT:
        push af                      ; $0B30 : F5
L0B31:
        ld a,(hl)                    ; $0B31 : 7E | Get byte
        inc hl                       ; $0B32 : 23
        sub $30                      ; $0B33 : D6 30 | Ascii -> tbl
        jp p,$0B49                   ; $0B35 : F2 49 0B | Jump if >=$30
        ld b,a                       ; $0B38 : 47
L0B39:
        inc e                        ; $0B39 : 1C
        ld a,e                       ; $0B3A : 7B
        and $1F                      ; $0B3B : E6 1F
        jp nz,$0B42                  ; $0B3D : C2 42 0B | No wrap
        inc d                        ; $0B40 : 14
        inc d                        ; $0B41 : 14
L0B42:
        inc b                        ; $0B42 : 04
        jp nz,$0B39                  ; $0B43 : C2 39 0B | Loop
        jp $0B31                     ; $0B46 : C3 31 0B | Next char

; -----------------------------------------------------------------------------
; SELECT_CHARACTER_GLYPH ($0B49) - Locate the character glyph bitmap
; -----------------------------------------------------------------------------
SELECT_CHARACTER_GLYPH:
        push hl                      ; $0B49 : E5
        push de                      ; $0B4A : D5
        ld hl,$0B8F                  ; $0B4B : 21 8F 0B | Start of char table
        jp z,$0B59                   ; $0B4E : CA 59 0B | (no need to add)
        ld bc,$000A                  ; $0B51 : 01 0A 00 | Add a*$0a
L0B54:
        add hl,bc                    ; $0B54 : 09
        dec a                        ; $0B55 : 3D
        jp nz,$0B54                  ; $0B56 : C2 54 0B

; -----------------------------------------------------------------------------
; COPY_CHARACTER_GLYPH ($0B59) - Copy the character glyph to video RAM
; -----------------------------------------------------------------------------
COPY_CHARACTER_GLYPH:
        ex de,hl                     ; $0B59 : EB
        ld bc,$0020                  ; $0B5A : 01 20 00
        ld a,$0A                     ; $0B5D : 3E 0A | Loop $a times
L0B5F:
        push af                      ; $0B5F : F5
        ld a,(de)                    ; $0B60 : 1A | Load byte
        inc de                       ; $0B61 : 13 | Inc index
        ld (hl),a                    ; $0B62 : 77 | Store to screen
        add hl,bc                    ; $0B63 : 09 | Next screen loc
        pop af                       ; $0B64 : F1
        dec a                        ; $0B65 : 3D
        jp nz,$0B5F                  ; $0B66 : C2 5F 0B | Loop for this char
        pop de                       ; $0B69 : D1
        pop hl                       ; $0B6A : E1
        inc de                       ; $0B6B : 13
        pop af                       ; $0B6C : F1
        dec a                        ; $0B6D : 3D
        jp nz,$0B30                  ; $0B6E : C2 30 0B | Next char
        ret                          ; $0B71 : C9
        ex de,hl                     ; $0B72 : EB
        ld a,(hl)                    ; $0B73 : 7E | Argument
        inc hl                       ; $0B74 : 23
        ld ($2000),hl                ; $0B75 : 22 00 20
        ld ($2010),a                 ; $0B78 : 32 10 20 | Store ??
        ret                          ; $0B7B : C9
        ex de,hl                     ; $0B7C : EB
        ld a,(hl)                    ; $0B7D : 7E | Argument
        inc hl                       ; $0B7E : 23
        ld ($2000),hl                ; $0B7F : 22 00 20
        ld ($2011),a                 ; $0B82 : 32 11 20 | Store ??
        ret                          ; $0B85 : C9
        ex de,hl                     ; $0B86 : EB
        ld e,(hl)                    ; $0B87 : 5E
        inc hl                       ; $0B88 : 23
        ld d,(hl)                    ; $0B89 : 56
        ex de,hl                     ; $0B8A : EB
        ld ($2000),hl                ; $0B8B : 22 00 20
        ret                          ; $0B8E : C9

; -----------------------------------------------------------------------------
; NUMERIC_GLYPH_BITMAPS ($0B8F) - 10-row numeric character patterns; bytes map to pixel rows
; -----------------------------------------------------------------------------
NUMERIC_GLYPH_BITMAPS:
; First glyph ($0B8F-$0B98), one byte per raster row, '#' = set pixel:
;   ..####..
;   .######.
;   .##..##.
;   .##..##.
;   .##..##.
;   .##..##.
;   .##..##.
;   .##..##.
;   .######.
;   ..####..
        DB $3C,$7E,$66,$66,$66,$66,$66,$66,$7E,$3C,$18,$1C ; $0B8F raw original bytes | numeric character glyph bitmap rows
        DB $18,$18,$18,$18,$18,$18,$3C,$3C,$3C,$7E,$66,$60 ; $0B9B raw original bytes | numeric character glyph bitmap rows
        DB $7C,$3E,$06,$06,$7E,$7E,$3C,$7E,$66,$60,$38,$78 ; $0BA7 raw original bytes | numeric character glyph bitmap rows
        DB $60,$66,$7E,$3C,$66,$66,$66,$66,$7E,$7E,$60,$60 ; $0BB3 raw original bytes | numeric character glyph bitmap rows
        DB $60,$60,$3E,$3E,$06,$06,$3E,$7E,$60,$66,$7E,$3C ; $0BBF raw original bytes | numeric character glyph bitmap rows
        DB $3C,$3E,$06,$06,$3E,$7E,$66,$66,$7E,$3C,$7E,$7E ; $0BCB raw original bytes | numeric character glyph bitmap rows
        DB $60,$70,$30,$38,$18,$1C,$0C,$0C,$3C,$7E,$66,$66 ; $0BD7 raw original bytes | numeric character glyph bitmap rows
        DB $3C,$7E,$66,$66,$7E,$3C,$3C,$7E,$66,$66,$7E,$7C ; $0BE3 raw original bytes | numeric character glyph bitmap rows
        DB $60,$60,$7C,$3C,$0C,$93,$60,$00,$00,$00,$00,$00 ; $0BEF raw original bytes | numeric character glyph bitmap rows
        DB $00,$00,$60,$99,$06 ; $0BFB raw original bytes | numeric character glyph bitmap rows
; ROM 4: sw0044.e ($0C00-$0FFF)

; -----------------------------------------------------------------------------
; GRAPHICS_ASSET_ROM ($0C00) - Graphics and encoded screen assets rather than executable routines
; -----------------------------------------------------------------------------
GRAPHICS_ASSET_ROM:
        DB $00,$00,$00,$00,$00,$00,$00,$30,$CD,$02,$00,$00 ; $0C00 raw original bytes | graphics header and sprite-pattern bytes
        DB $00,$00,$00,$00,$00,$02,$C0,$78,$E0,$80,$F0,$01 ; $0C0C raw original bytes | graphics header and sprite-pattern bytes
        DB $C0,$F0,$7C,$08,$1C,$3E,$7F,$FF,$FF,$BF,$1F,$02 ; $0C18 raw original bytes | graphics header and sprite-pattern bytes
        DB $40,$02,$80,$78,$1E,$07,$01,$7C,$F8,$0C,$10,$00 ; $0C24 raw original bytes | graphics header and sprite-pattern bytes
        DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$3C,$7E ; $0C30 raw original bytes | text character bitmap rows
        DB $66,$66,$66,$7E,$7E,$66,$66,$3E,$7E,$66,$66,$3E ; $0C3C raw original bytes | text character bitmap rows
        DB $7E,$66,$66,$7E,$3E,$3C,$7E,$66,$06,$06,$06,$06 ; $0C48 raw original bytes | text character bitmap rows
        DB $66,$7E,$3C,$3E,$7E,$66,$66,$66,$66,$66,$66,$7E ; $0C54 raw original bytes | text character bitmap rows
        DB $3E,$7E,$7E,$06,$06,$3E,$3E,$06,$06,$7E,$7E,$7E ; $0C60 raw original bytes | text character bitmap rows
        DB $7E,$06,$06,$3E,$3E,$06,$06,$06,$06,$3C,$7E,$66 ; $0C6C raw original bytes | text character bitmap rows
        DB $06,$06,$76,$76,$66,$7E,$3C,$66,$66,$66,$66,$7E ; $0C78 raw original bytes | text character bitmap rows
        DB $7E,$66,$66,$66,$66,$3C,$3C,$18,$18,$18,$18,$18 ; $0C84 raw original bytes | text character bitmap rows
        DB $18,$3C,$3C,$60,$60,$60,$60,$60,$60,$60,$66,$7E ; $0C90 raw original bytes | text character bitmap rows
        DB $3C,$66,$66,$76,$3E,$1E,$1E,$3E,$76,$66,$66,$06 ; $0C9C raw original bytes | text character bitmap rows
        DB $06,$06,$06,$06,$06,$06,$06,$7E,$7E,$C3,$C3,$E7 ; $0CA8 raw original bytes | text character bitmap rows
        DB $E7,$FF,$FF,$DB,$C3,$C3,$C3,$66,$66,$6E,$6E,$7E ; $0CB4 raw original bytes | text character bitmap rows
        DB $7E,$76,$76,$66,$66,$3C,$7E,$66,$66,$66,$66,$66 ; $0CC0 raw original bytes | text character bitmap rows
        DB $66,$7E,$3C,$3E,$7E,$66,$66,$7E,$3E,$06,$06,$06 ; $0CCC raw original bytes | text character bitmap rows
        DB $06,$3C,$7E,$66,$66,$66,$66,$66,$66,$7E,$5C,$3E ; $0CD8 raw original bytes | text character bitmap rows
        DB $7E,$66,$66,$7E,$3E,$76,$66,$66,$66,$3C,$7E,$66 ; $0CE4 raw original bytes | text character bitmap rows
        DB $06,$3E,$7C,$60,$66,$7E,$3C,$7E,$7E,$18,$18,$18 ; $0CF0 raw original bytes | text character bitmap rows
        DB $18,$18,$18,$18,$18,$66,$66,$66,$66,$66,$66,$66 ; $0CFC raw original bytes | text character bitmap rows
        DB $66,$7E,$3C,$66,$66,$66,$66,$66,$7E,$3C,$3C,$18 ; $0D08 raw original bytes | text character bitmap rows
        DB $18,$C3,$C3,$C3,$DB,$FF,$FF,$E7,$E7,$C3,$C3,$66 ; $0D14 raw original bytes | text character bitmap rows
        DB $66,$7E,$3C,$18,$18,$3C,$7E,$66,$66,$66,$66,$7E ; $0D20 raw original bytes | text character bitmap rows
        DB $3C,$18,$18,$18,$18,$18,$18,$7E,$7E,$60,$70,$38 ; $0D2C raw original bytes | text character bitmap rows
        DB $1C,$0E,$06,$7E,$7E,$05,$0C,$00,$00,$08,$00,$00 ; $0D38 raw original bytes | text character bitmap rows
        DB $00,$00,$08,$00,$00,$00,$60,$0E,$00,$00,$00,$E0 ; $0D44 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $CE,$3F,$00,$00,$E0,$DE,$03,$00,$F8,$F7,$DF,$F7 ; $0D50 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $0F,$80,$F7,$DF,$F7,$00,$FF,$FF,$FF,$FF,$FF,$FF ; $0D5C raw original bytes | ship / torpedo / explosion bitmap frames
        DB $FF,$FF,$FF,$7F,$FF,$FF,$FF,$FF,$3F,$FE,$FF,$FF ; $0D68 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $FF,$1F,$FE,$FF,$FF,$FF,$0F,$04,$0C,$00,$00,$03 ; $0D74 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $00,$00,$36,$03,$00,$00,$36,$03,$00,$02,$B6,$03 ; $0D80 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $00,$87,$FF,$F3,$07,$E2,$FF,$F7,$00,$FF,$FF,$FF ; $0D8C raw original bytes | ship / torpedo / explosion bitmap frames
        DB $FF,$FF,$FF,$FF,$7F,$FF,$FF,$FF,$3F,$FC,$FF,$FF ; $0D98 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $1F,$FC,$FF,$FF,$0F,$F8,$FF,$FF,$07,$05,$0C,$00 ; $0DA4 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $00,$40,$00,$00,$00,$00,$F0,$00,$00,$00,$00,$F0 ; $0DB0 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $00,$00,$00,$80,$F0,$1E,$00,$00,$00,$FB,$06,$00 ; $0DBC raw original bytes | ship / torpedo / explosion bitmap frames
        DB $FF,$FF,$FF,$FF,$FF,$FC,$FF,$FF,$FF,$3F,$FC,$FF ; $0DC8 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $FF,$FF,$1F,$FC,$FF,$FF,$FF,$0F,$F8,$FF,$FF,$FF ; $0DD4 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $07,$F8,$FF,$FF,$FF,$03,$F8,$FF,$FF,$FF,$03,$04 ; $0DE0 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $0B,$40,$00,$00,$02,$40,$80,$00,$02,$40,$00,$07 ; $0DEC raw original bytes | ship / torpedo / explosion bitmap frames
        DB $02,$40,$00,$07,$02,$40,$F0,$07,$02,$FC,$F0,$07 ; $0DF8 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $F8,$FC,$FF,$FF,$7F,$FC,$FF,$FF,$3F,$F8,$FF,$FF ; $0E04 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $1F,$F0,$FF,$FF,$0F,$F0,$FF,$FF,$0F,$04,$0B,$80 ; $0E10 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $00,$00,$00,$00,$00,$00,$01,$A0,$01,$00,$01,$A0 ; $0E1C raw original bytes | ship / torpedo / explosion bitmap frames
        DB $01,$00,$01,$F0,$01,$00,$01,$F8,$01,$00,$F9,$F8 ; $0E28 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $FF,$FF,$7F,$F0,$FF,$FF,$3F,$F0,$FF,$FF,$1F,$F0 ; $0E34 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $FF,$FF,$0F,$E0,$FF,$FF,$0F,$02,$06,$00,$03,$10 ; $0E40 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $07,$E0,$FF,$FF,$7F,$FF,$3F,$FF,$1F,$02,$0F,$10 ; $0E4C raw original bytes | ship / torpedo / explosion bitmap frames
        DB $00,$30,$02,$70,$01,$FC,$00,$F8,$11,$F0,$3B,$E0 ; $0E58 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $7F,$C0,$3F,$80,$1F,$00,$3F,$00,$1E,$00,$04,$00 ; $0E64 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $48,$00,$F8,$00,$F8,$01,$11,$10,$38,$38,$38,$38 ; $0E70 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $38,$38,$38,$38,$38,$38,$38,$38,$10,$10,$10,$38 ; $0E7C raw original bytes | ship / torpedo / explosion bitmap frames
        DB $01,$0E,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 ; $0E88 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $18,$18,$00,$18,$01,$09,$10,$10,$10,$10,$10,$10 ; $0E94 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $10,$10,$10,$01,$10,$10,$BA,$7C,$FE,$7C,$38,$54 ; $0EA0 raw original bytes | ship / torpedo / explosion bitmap frames
        DB $10,$00,$10,$00,$08,$00,$00,$04,$00,$3D,$3E,$3F ; $0EAC raw original bytes | ship / torpedo / explosion bitmap frames
        DB $40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$47 ; $0EB8 raw original bytes | display strings and encoded glyph indexes
        DB $41,$4D,$45,$40,$4F,$56,$45,$52,$48,$49,$47,$48 ; $0EC4 raw original bytes | display strings and encoded glyph indexes
        DB $40,$53,$43,$4F,$52,$45,$40,$40,$40,$40,$40,$40 ; $0ED0 raw original bytes | display strings and encoded glyph indexes
        DB $59,$4F,$55,$52,$40,$53,$43,$4F,$52,$45,$49,$4E ; $0EDC raw original bytes | display strings and encoded glyph indexes
        DB $53,$45,$52,$54,$40,$43,$4F,$49,$4E,$50,$55,$53 ; $0EE8 raw original bytes | display strings and encoded glyph indexes
        DB $48,$40,$42,$55,$54,$54,$4F,$4E,$53,$45,$41,$40 ; $0EF4 raw original bytes | display strings and encoded glyph indexes
        DB $57,$4F,$4C,$46,$3A,$3B,$3C,$3B,$3C,$3A,$3B,$3C ; $0F00 raw original bytes | display strings and encoded glyph indexes
        DB $3A,$3C,$3B,$3C,$3A,$3B,$3A,$3C,$3B,$3A,$3C,$3A ; $0F0C raw original bytes | display strings and encoded glyph indexes
        DB $3B,$3C,$3A,$3C,$3B,$3C,$3A,$3B,$3C,$3A,$3B,$3C ; $0F18 raw original bytes | display strings and encoded glyph indexes

; -----------------------------------------------------------------------------
; DISPLAY_LEGEND_TABLE ($0F24) - Embedded display words and game-status layout data
; -----------------------------------------------------------------------------
DISPLAY_LEGEND_TABLE:
        DB $42,$4F,$4E,$55,$53,$54,$49,$4D,$45,$2D,$53,$43 ; $0F24 raw original bytes | encoded display legend and control parameters
        DB $4F,$52,$45,$45,$58,$54,$45,$4E,$44,$45,$44,$16 ; $0F30 raw original bytes | encoded display legend and control parameters
        DB $54,$49,$4D,$45,$44,$0F,$4C,$0F,$01,$41,$04,$3D ; $0F3C raw original bytes | encoded display legend and control parameters
        DB $5A,$2F,$50,$3F,$01,$41,$04,$3D,$57,$2F,$4D,$3F ; $0F48 raw original bytes | encoded display legend and control parameters

; -----------------------------------------------------------------------------
; BIT_ORDER_LOOKUP ($0F54) - Lookup data used by object placement and shifting
; -----------------------------------------------------------------------------
BIT_ORDER_LOOKUP:
        DB $61,$71,$81,$91,$03,$03,$03,$01,$01,$07,$00,$08 ; $0F54 raw original bytes | bit-order / movement lookup
        DB $18,$10,$38,$30,$20,$28,$78,$70,$60,$68,$40,$48 ; $0F60 raw original bytes | bit-order / movement lookup
        DB $58,$50,$F8,$F0,$E0,$E8,$C0,$C8,$D8,$D0,$80,$88 ; $0F6C raw original bytes | bit-order / movement lookup
        DB $98,$90,$B8,$B0,$A0,$A8,$0D,$3D,$20,$14,$00,$D8 ; $0F78 raw original bytes | object and graphic descriptor records
        DB $00,$02,$0D,$7B,$20,$14,$00,$E0,$00,$02,$0D,$AD ; $0F84 raw original bytes | object and graphic descriptor records
        DB $20,$14,$00,$D8,$00,$02,$0D,$EB,$20,$15,$00,$E0 ; $0F90 raw original bytes | object and graphic descriptor records
        DB $00,$01,$0E,$19,$20,$15,$00,$E0,$00,$01,$0E,$47 ; $0F9C raw original bytes | object and graphic descriptor records
        DB $20,$1A,$00,$F0,$00,$03,$0D,$3D,$40,$34,$00,$D8 ; $0FA8 raw original bytes | object and graphic descriptor records
        DB $D8,$FE,$0D,$7B,$40,$34,$00,$E0,$E0,$FE,$0D,$AD ; $0FB4 raw original bytes | object and graphic descriptor records
        DB $40,$34,$00,$D8,$D8,$FE,$0D,$EB,$40,$35,$00,$E0 ; $0FC0 raw original bytes | object and graphic descriptor records
        DB $E0,$FF,$0E,$19,$40,$35,$00,$E0,$E0,$FF,$0E,$47 ; $0FCC raw original bytes | object and graphic descriptor records
        DB $40,$3A,$00,$F0,$F0,$FD,$06,$04,$02,$06,$03,$05 ; $0FD8 raw original bytes | object and graphic descriptor records
        DB $01 ; $0FE4 raw original bytes | object and graphic descriptor records
        rst $38                      ; $0FE5 : FF
        rst $38                      ; $0FE6 : FF
        rst $38                      ; $0FE7 : FF
        rst $38                      ; $0FE8 : FF
        rst $38                      ; $0FE9 : FF
        rst $38                      ; $0FEA : FF
        rst $38                      ; $0FEB : FF
        rst $38                      ; $0FEC : FF
        rst $38                      ; $0FED : FF
        rst $38                      ; $0FEE : FF
        rst $38                      ; $0FEF : FF
        rst $38                      ; $0FF0 : FF
        rst $38                      ; $0FF1 : FF
        rst $38                      ; $0FF2 : FF
        rst $38                      ; $0FF3 : FF
        rst $38                      ; $0FF4 : FF
        rst $38                      ; $0FF5 : FF
        rst $38                      ; $0FF6 : FF
        rst $38                      ; $0FF7 : FF
        rst $38                      ; $0FF8 : FF
        rst $38                      ; $0FF9 : FF
        rst $38                      ; $0FFA : FF
        rst $38                      ; $0FFB : FF
        rst $38                      ; $0FFC : FF
        rst $38                      ; $0FFD : FF
        rst $38                      ; $0FFE : FF
        rst $38                      ; $0FFF : FF

        END

; End original ROM image
