; ============================================================
; v6: the partner's own navigation (used when you are dead, and while you
; are alive whenever it is its turn to lead).
;
; It walks along the level's route: it jumps walls and gaps, drops down
; short ledges, and takes the staircases that the route needs. Which
; stairs the route needs is stored per stage in mask_tab (found by
; playing every stage in the emulator). The game's own stair table
; (stairs.inc) tells it where the stairs start.
; ============================================================
P2WXL = $7E18
P2WXH = $7E19
P1WXL = $7E1A
P1WXH = $7E1B
SOWX  = $7D3D
SOCNT = $7D3E
SOTRY = $7D3F
SOVERT= $7D40
SAVZP = $7D41            ; 9 bytes
SOLOF = $7D4A
SOT1  = $7D4B
SOT2  = $7D4C
SOT3  = $7D4D
SOLEFT= $7D4E
SOSTAIR=$7D4F
SODIR = $7D50            ; direction of travel: BTN_R / BTN_L
SOSEEK= $7D51            ; 0 follow the route, 1 find stairs UP, 2 find stairs DOWN
SOBD  = $7D52            ; best candidate distance
SOBDIR= $7D53
SOBKEY= $7D54
SOBMOT= $7D55
SOIDX = $7D56
SOSTG = $7D57            ; stage the mask below belongs to
SOMASK= $7D58            ; 3 bytes: which stair entries of this stage the route uses
SODFL = $7D5B            ; per-stage flags: bit0 sub-level 0 travels left, bit1 sub-level 1
SOSGN = $7D5C
SOOVR = $7D94
SOOT  = $7D95
LEADMAX = 48             ; how far ahead of you the partner may walk

p1_absent:               ; C=1 if P1 is not on screen
    LDA P1Y
    BEQ pa_yes
    CMP #$F0
    BCS pa_yes
    CLC
    RTS
pa_yes:
    SEC
    RTS

probe:                   ; X=signed dx, A=screen y -> A=tile type, Z set if empty
    STA $10
    LDA #0
    CPX #$80
    BCC :+
    LDA #$FF
:   STA SOSGN
    TXA
    CLC
    ADC P2WXL
    STA $12
    LDA P2WXH
    ADC SOSGN
    STA $13
    JSR $F9A0
    LDA $14
    RTS

SOLO:
    LDX #8
:   LDA $0F,X
    STA SAVZP,X
    DEX
    BPL :-
    JSR solo_logic
    LDX #8
:   LDA SAVZP,X
    STA $0F,X
    DEX
    BPL :-
    RTS

solo_loadmask:           ; copy this stage's route mask + flags when the stage changes
    LDA $28
    CMP SOSTG
    BEQ :+
    STA SOSTG
    LDA #0               ; new stage: forget any walking-on / turn-round state
    STA SOOT
    STA SOSUP
    STA SOATK
    LDA SOSTG
    CMP #18
    BCS :+
    ASL A
    ASL A
    TAX
    LDA mask_tab,X
    STA SOMASK
    LDA mask_tab+1,X
    STA SOMASK+1
    LDA mask_tab+2,X
    STA SOMASK+2
    LDA mask_tab+3,X
    STA SODFL
:   RTS

solo_logic:
    LDA P2ST
    BEQ so_ground
    CMP #1
    BNE :+
    LDA SODIR            ; in the air: keep going the way we were
    STA OUT
    RTS
:   CMP #4
    BNE so_off
    LDA #0
    STA SOLEFT
    LDA SOSTAIR          ; on stairs: keep going the way the stairs lead
    STA OUT
    AND #(BTN_L|BTN_R)
    BEQ so_st_e
    STA SOOVR            ; and keep walking that way for a while once at the top
    LDA #250
    STA SOOT
so_st_e:
    RTS
so_off:
    LDA #0
    STA OUT
    RTS
so_ground:
    JSR solo_loadmask
    LDA P2WXL
    CMP SOWX
    BEQ so_nop
    STA SOWX
    LDA #0
    STA SOCNT
    STA SOTRY
    STA SOVERT
    BEQ so_go
so_nop:
    INC SOCNT
    LDA SOCNT
    CMP #6
    BCC so_go
    LDA #1
    STA SOLEFT           ; stuck: any staircase nearby will do
so_go:
    JSR solo_goal        ; sets SODIR / SOSEEK; C=1 means "wait here"
    BCC :+
    LDA #0
    STA OUT
    RTS
:   JSR solo_stairs
    BCC :+
    RTS
:   LDA SOCNT
    CMP #6
    BCS so_cycle
so_norm:
    LDA SODIR
    STA OUT
    JSR so_dx            ; X = +-12
    LDA P2Y
    CLC
    ADC #8
    JSR probe            ; wall ahead at body height?
    BEQ so_floor
    JSR so_dx
    LDA P2Y
    SEC
    SBC #24
    JSR probe
    BNE so_tall
so_jump:
    LDA SODIR
    ORA #BTN_A
    STA OUT
    RTS
so_tall:
    LDA #6
    STA SOCNT
so_cycle:
    LDA SOCNT
    CMP #90
    BNE :+               ; stuck for a long time: dead end, turn round
    INC SOCNT
    LDA SODIR
    EOR #(BTN_L|BTN_R)
    STA SOOVR
    STA SODIR
    LDA #250
    STA SOOT
:   LDA SOCNT
    CMP #250
    BCC :+
    LDA #6
    STA SOCNT
:   INC SOTRY
    LDA SOTRY
    CMP #18
    BCC :+
    LDA #0
    STA SOTRY
:   LDA SOTRY
    CMP #6
    BCS :+
    LDA #BTN_U
    BNE so_cv
:   CMP #12
    BCS so_jump
    LDA #BTN_D
so_cv:
    STA SOVERT
    ORA SODIR
    STA OUT
    RTS
so_floor:
    JSR so_dx20            ; floor under the next step?
    LDA P2Y
    CLC
    ADC #16
    JSR probe
    BNE so_done
    LDY #0               ; hole: is there a safe landing within 56 px?
so_dn:
    STY TA
    JSR so_dx20
    LDY TA
    LDA P2Y
    CLC
    ADC dn_off,Y
    JSR probe            ; Z set when empty
    BNE so_done          ; floor found: just walk off
    LDY TA
    INY
    CPY #8               ; step off drops of up to 80 px
    BCC so_dn
so_gap:                  ; bottomless: jump only if there is ground within a jump's reach
    LDX #40
    LDA SODIR
    CMP #BTN_R
    BEQ :+
    LDX #$D8
:   LDA P2Y
    CLC
    ADC #16
    JSR probe
    BNE :+
    LDA SODIR            ; too wide to jump: turn round
    EOR #(BTN_L|BTN_R)
    STA SOOVR
    STA SODIR
    STA OUT
    LDA #250
    STA SOOT
    RTS
:   JMP so_jump
so_done:
    RTS
dn_off: .byte 24,32,40,48,56,64,72,80

so_dx20:                 ; same, 20 px: look further ahead for ledge edges
    LDX #20
    LDA SODIR
    CMP #BTN_R
    BEQ :+
    LDX #$EC
:   RTS

so_dx:                   ; X = +12 when travelling right, -12 (=$F4) when left
    LDX #12
    LDA SODIR
    CMP #BTN_R
    BEQ :+
    LDX #$F4
:   RTS

; ------------------------------------------------------------
; Which way to go. Alone: follow the level's route. With P1 around: stay
; on P1's floor (taking stairs when P1 is on another floor) and walk the
; route ahead of P1, but never further than LEADMAX in front of P1.
; Returns C=1 to wait here.
; ------------------------------------------------------------
solo_goal:
    LDA #0
    STA SOSEEK
    LDX #BTN_R           ; route direction of this stage / sub-level
    LDA SODFL
    LDY $46
    BEQ :+
    LSR A
:   AND #1
    BEQ :+
    LDX #BTN_L
:   LDA SOOT             ; walking on after stairs / after a dead end
    BEQ :+
    DEC SOOT
    LDX SOOVR
:   STX SODIR
    JSR p1_absent
    BCC :+
    CLC                  ; alone: no leash
    RTS
:   LDA P2Y              ; different floor? go and find stairs to P1's floor
    SEC
    SBC P1Y
    CLC
    ADC #20
    CMP #41
    BCC sg_same
    LDA P1Y
    CMP P2Y
    LDX #1
    BCC :+
    LDX #2
:   STX SOSEEK
    LDA P1WXL            ; walk towards P1 while looking for the stairs
    SEC
    SBC P2WXL
    LDA P1WXH
    SBC P2WXH
    LDX #BTN_R
    BPL :+
    LDX #BTN_L
:   STX SODIR
    CLC
    RTS
sg_same:                 ; P1 on the same floor
    LDA P1WXL            ; d = P1 - P2 (signed 16 bit)
    SEC
    SBC P2WXL
    STA SOT1
    LDA P1WXH
    SBC P2WXH
    STA SOT2
    LDA SODIR            ; "ahead" = the route direction
    CMP #BTN_R
    BEQ sg_r
    LDA SOT1             ; going left: ahead = P2 left of P1 -> d > 0 ... flip sign
    EOR #$FF
    CLC
    ADC #1
    STA SOT1
    LDA SOT2
    EOR #$FF
    ADC #0
    STA SOT2
sg_r:                    ; now d>0 means P1 is ahead of P2 along the route
    LDA SOT2
    BMI sg_ahead         ; P2 is ahead of P1 by -d
    CLC                  ; P2 is behind or level with P1: hurry up
    RTS
sg_ahead:
    LDA SOT2
    CMP #$FF
    BNE sg_wait          ; more than 255 ahead
    LDA SOT1
    CMP #(256-LEADMAX)
    BCS sg_ok            ; less than LEADMAX ahead: carry on
sg_wait:
    SEC                  ; far enough ahead: wait for P1
    RTS
sg_ok:
    CLC
    RTS

; ------------------------------------------------------------
; Staircases. The game keeps a table of stair endpoints per stage (copied
; into stairs.inc, 2 bytes each: y|sub|type, x). SOSEEK 0: only the ones the
; route uses (mask) - or any when stuck. SOSEEK 1/2: the nearest that goes up
; / down. Walk to the best one and press the key that makes Simon take it.
; ------------------------------------------------------------
solo_stairs:
    JMP ss_start
ss_no:
    CLC
    RTS
ss_start:
    LDA $28
    CMP #18
    BCS ss_no
    ASL A
    TAX
    LDA st_ptr,X
    STA $15
    LDA st_ptr+1,X
    STA $16
    LDA #$FF
    STA SOBD
    LDA #0
    STA SOIDX
    LDY #0
ss_l:
    LDA ($15),Y
    BNE :+
    JMP ss_end
:
    STA TA
    INY
    LDA ($15),Y
    STA TB
    INY
    INC SOIDX
    LDA TA
    LSR A
    LSR A
    AND #1
    CMP $46
    BNE ss_l                ; stair belongs to the other sub-level
    LDA TA
    AND #$F0
    STA SOT1
    LDA P2Y
    SEC
    SBC SOT1
    CLC
    ADC #3
    CMP #6
    BCS ss_l                ; not at that stair's height
    LDA SOSEEK
    BNE ss_seek
    LDA SOLEFT              ; follow the route: only marked stairs (any when stuck)
    BNE ss_pass
    LDX SOIDX
    DEX                     ; entry number 0..
    TXA
    LSR A
    LSR A
    LSR A
    TAX
    LDA SOMASK,X
    STA SOT1
    LDA SOIDX
    SEC
    SBC #1
    AND #7
    TAX
    LDA SOT1
    AND bit_t,X
    BEQ ss_l
    BNE ss_pass
ss_seek:
    LDA TA
    AND #2                  ; 0 = key UP at a stair bottom, 2 = DOWN at a top
    BNE ss_dn
    LDA SOSEEK
    CMP #1
    BEQ ss_pass
    BNE ss_l
ss_dn:
    LDA SOSEEK
    CMP #2
    BNE ss_l
ss_pass:
    LDA TA
    AND #3
    TAX
    LDA TB
    AND #$F8
    CLC
    ADC off_lo,X
    STA SOT2
    LDA TB
    AND #7
    ADC off_hi,X
    STA SOT3
    LDA SOT2
    SEC
    SBC P2WXL
    STA SOT2
    LDA SOT3
    SBC P2WXH
    BEQ ss_pos
    CMP #$FF
    BNE ss_nx
    LDA SOT2
    EOR #$FF
    CLC
    ADC #1
    LDX #BTN_L
    BNE ss_chk
ss_pos:
    LDA SOT2
    LDX #BTN_R
ss_chk:
    CMP #200
    BCS ss_nx
    CMP SOBD
    BCS ss_nx               ; not nearer than the best so far
    STA SOBD
    STX SOBDIR
    LDA TA
    AND #3
    TAX
    LDA rightward,X
    BEQ :+
    LDA #BTN_R
    BNE :++
:   LDA #BTN_L
:   STA SOBMOT
    LDA TA
    AND #2
    BEQ :+
    LDA #BTN_D
    BNE :++
:   LDA #BTN_U
:   STA SOBKEY
ss_nx:
    JMP ss_l
ss_end:
    LDA SOBD
    CMP #$FF
    BNE :+
    CLC
    RTS
:   LDA SOBMOT
    STA SOSTAIR             ; on the stairs hold only left/right (the camera needs that)
    LDA SOBD
    CMP #4
    BCC ss_key
    CMP #14
    BCS ss_far
    LDA SOBDIR
    ORA SOBKEY
    STA OUT
    SEC
    RTS
ss_far:                     ; still far: plain walking keeps the camera scrolling
    LDA SOBDIR
    STA OUT
    STA SODIR
    SEC
    RTS
ss_key:                     ; right on it: just press the key
    LDA SOBKEY
    STA OUT
    SEC
    RTS
bit_t:   .byte 1,2,4,8,16,32,64,128
off_lo:  .byte 0,$FF,5,2
off_hi:  .byte 0,$FF,0,0
rightward: .byte 1,0,0,1
.include "stairs.inc"
.include "masks.inc"

; Called from the hook that parks P1's marker while P1 waits to respawn.
; The camera only follows when that marker is at the screen centre, so cap
; it there: P2 can then scroll the screen again after climbing stairs.
GHOSTX:
    LDA $6049
    CMP #$80
    BCC :+
    LDA #$80
:   STA $038C
    RTS
