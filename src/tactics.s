.export SYNC
.export GHOSTX
; ============================================================
; CPU partner tactics layer (v2) - Castlevania Co-op CPU mod
; Lives in bank 8 free space after the v1 AI. Called from AI_MAIN
; in place of "JSR movement / JSR combat".
;   boss mode  : a boss is on screen -> close in, whip, jump-whip
;                flying bosses, spend sub-weapons freely
;   guard mode : an enemy is close to P1 -> get to it and hit it
;   otherwise  : the v1 follow + fight behaviour, unchanged
; ============================================================

BTN_R = $01
BTN_L = $02
BTN_D = $04
BTN_U = $08
BTN_B = $40
BTN_A = $80

OBJTYP = $0434
OBJX   = $038C
OBJY   = $0354
P1X    = $038C
P1Y    = $0354
P1ST   = $046C

P2X    = $6049
P2Y    = $6046
P2ST   = $6052
P2FACE = $604F
P2WHIP = $6076
P2HEART= $6077
P2SUB  = $6079

; v1 AI routines / RAM (bank 8)
MOVEMENT = $8B21
COMBAT   = $8ECD
FACE_DIR = $8FB5          ; A=1 target right -> C=1 facing, else OUT=turn
OUT      = $7E0A
LASTO    = $7E03
SUBCD    = $7E04
TMP0     = $7E10
IGNT     = $7D06
RIDE     = $7D07
REGRP    = $7D08

; v2 RAM ($7D20-$7D2F, unused by game, hack and v1)
TGT    = $7D20            ; chosen target slot
TGDX   = $7D21            ; |target x - P2 x|
TGSD   = $7D22            ; 1 = target is to the right
TGDY   = $7D23            ; target y - P2 y + 96
MODE   = $7D24            ; 0 follow, 1 boss, 2 guard
BEST   = $7D25
JWT    = $7D26            ; jump-whip countdown
REACH  = $7D27
TA     = $7D28
TB     = $7D29
FRM    = $7D2A            ; AI call counter
HOLD   = $7D2B            ; last decision output
SCN    = $7D2C            ; scan counter
CMODE  = $7D2D            ; cached mode from the last scan (0 none, 1 boss, 2 guard)

DYB    = 96               ; bias for TGDY
LEASH  = 96               ; boss mode: max chase distance from P1
GUARDR = 64               ; guard radius around P1
DECMASK = 3               ; decide on every 4th frame
BOSS_LO = $18             ; Death $18, Bat $19, Mummy $1A, Medusa $1B,
BOSS_HI = $1E             ; Frankenstein $1C, Dracula $1D/$1E

; ------------------------------------------------------------
TACTICS:
    INC FRM
    LDA FRM
    AND #DECMASK
    BNE t_hold
    JSR TACT_BODY        ; decision frame
    LDA OUT
    STA HOLD
    RTS
t_hold:                  ; in-between frame: repeat the last d-pad, no buttons
    LDA FRM              ; spare frames do the heavy scans so that no single
    AND #7               ; frame carries all of the work
    CMP #1
    BNE :+
    JSR scan_targets
    JMP th_go
:   CMP #6
    BNE th_go
.ifndef NOITEM
    JSR item_scan
.endif
th_go:
    LDX HOLD
    TXA
    AND #(BTN_A|BTN_B)
    BEQ th_keep
    LDA P2ST
    CMP #4
    BCS th_keep
    TXA
    AND #(BTN_L|BTN_R)
    STA OUT
    JMP $8C31            ; still honour recorded jump take-off points every frame
th_keep:
    TXA
    AND #(BTN_L|BTN_R|BTN_U|BTN_D)
    STA OUT
    LDA P2ST
    BNE th_end
    TXA
    AND #(BTN_L|BTN_R)
    BEQ th_end
    JMP $8C31
th_end:
    RTS

TACT_BODY:
    LDA #0
    STA MODE
    LDA P2ST
    CMP #1
    BEQ t_air            ; mid-jump: finish a jump-whip if one is planned
    LDA #0
    STA JWT
    LDA P2ST
    CMP #4
    BCS t_old            ; stairs, hurt, falling, dead...
    LDA CMODE            ; result of the last scan (done on a spare frame)
    BEQ t_old
    LDX TGT
    LDA OBJTYP,X
    BEQ t_lost
    LDA OBJY,X
    BEQ t_lost
    JSR set_target
    LDA CMODE
    CMP #1
    BEQ t_boss
    BNE t_guard
t_lost:
    LDA #0
    STA CMODE
    BEQ t_old
t_old:
    JSR p1_absent
    BCC t_old_n          ; P1 is here: follow P1 closely (the original follower)
t_old_s:                 ; P1 is dead/gone: carry on alone
    JSR SOLO             ; own navigation (leads ahead of P1 when P1 is alive)
    LDA #1
    STA SOMODE
    BNE t_old_c
t_old_n:
    LDA #0
    STA SOMODE
    JSR MOVEMENT
t_old_c:
.ifndef NOITEM
    JSR item_override
.endif
    LDA P2ST             ; on stairs: keep climbing, no swings
    CMP #4
    BNE :+
    RTS
:   LDA SOMODE
    BEQ so_fight
    JMP solo_combat
so_fight:
    JMP COMBAT

t_air:
    LDA JWT
    BEQ t_old
    DEC JWT
    BNE t_air_hold
    LDA #BTN_B           ; near the top of the jump: swing
    STA OUT
    RTS
t_air_hold:
    LDA #0
    STA OUT
    RTS

t_boss:
    LDA #0
    STA IGNT             ; never give up on a boss
    LDA #1
    STA MODE
    JMP engage

t_guard:
    LDA #2
    STA MODE
    LDA $49              ; P1 riding a moving platform: v1 handles that
    BNE t_old_g
    LDA RIDE
    BNE t_old_g
    LDA REGRP
    BNE t_old_g
    ; only take over when both players stand on the same floor
    LDA P1ST
    CMP #4
    BCS t_old
    LDA P1Y
    STA TMP0
    LDA P2Y
    JSR absdiff
    CMP #12
    BCS t_old_g
    JMP engage
t_old_g:
    JMP t_old

; Spare-frame scan: boss first, then threats near P1. Sets CMODE and TGT.
scan_targets:
    LDA P2ST
    CMP #4
    BCS sc_ret
    LDA #0
    STA CMODE
.ifndef NOBOSS
    JSR find_boss
    BCC :+
    LDA #1
    STA CMODE
    RTS
:
.endif
.ifndef NOGUARD
    JSR find_threat
    BCC :+
    LDA #2
    STA CMODE
:
.endif
sc_ret:
    RTS

; ------------------------------------------------------------
; nearest boss object to P2 -> C=1 and TGT/TGDX/TGSD/TGDY set
find_boss:
    LDA #$FF
    STA BEST
    STA TGT
    LDX $28              ; only stages 3, 6, 9, 12, 15 and 18 have bosses
    CPX #19
    BCS fb_skip
    LDA boss_stage,X
    BNE :+
fb_skip:
    CLC
    RTS
:   LDX #$16
fb_l:
    LDA OBJTYP,X
    CMP #BOSS_LO
    BCC fb_n
    CMP #BOSS_HI+1
    BCS fb_n
    LDA OBJY,X
    BEQ fb_n
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP BEST
    BCS fb_n
    STA BEST
    STX TGT
fb_n:
    DEX
    CPX #3
    BCS fb_l
    LDX TGT
    CPX #$FF
    BEQ fb_done
    LDA OBJTYP,X
    CMP #$1D             ; Dracula: only his head takes damage
    BNE fb_done
    LDX #$16
fb_h:
    LDA OBJTYP,X
    CMP #$04
    BNE fb_hn
    LDA OBJY,X
    BEQ fb_hn
    STX TGT
    JMP fb_done
fb_hn:
    DEX
    CPX #3
    BCS fb_h
fb_done:
    JMP set_target

boss_stage: .byte 0,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1

; enemy closest to P1 that is inside P1's guard zone
find_threat:
    LDA #$FF
    STA BEST
    STA TGT
    LDA P1Y
    BEQ ft_none
    CMP #$F0
    BCS ft_none
    LDX #$16
ft_l:
    LDA OBJTYP,X
    BEQ ft_n
    CMP #$28             ; candles, items, effects: not threats
    BCS ft_n
    LDA OBJY,X
    BEQ ft_n
    SEC
    SBC P1Y
    CLC
    ADC #48
    CMP #68              ; enemy y within -48..+19 of P1
    BCS ft_n
    LDA OBJX,X           ; not at a screen edge (chasing there gets
    CMP #24              ; P2 pinned while the screen scrolls)
    BCC ft_n
    CMP #232
    BCS ft_n
    LDA P2X              ; and reachable from P2
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP #120
    BCS ft_n
    LDA P1X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP #GUARDR          ; within GUARDR px of P1
    BCS ft_n
    CMP BEST
    BCS ft_n
    STA BEST
    STX TGT
ft_n:
    DEX
    CPX #3
    BCS ft_l
    JMP set_target
ft_none:
    CLC
    RTS

; TGT -> TGDX, TGSD, TGDY ; C=1 if TGT valid
set_target:
    LDX TGT
    CPX #$FF
    BEQ st_none
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    STA TGDX
    LDA #0
    ROL
    STA TGSD
    LDA OBJY,X
    SEC
    SBC P2Y
    CLC
    ADC #DYB
    STA TGDY
    SEC
    RTS
st_none:
    CLC
    RTS

; ------------------------------------------------------------
; fight the target (boss or guard mode); P2 is on the ground,
; whipping or crouching (P2ST 0..3)
engage:
    LDA #42              ; whip reach
    LDY P2WHIP
    CPY #2
    BCC :+
    LDA #60
:   STA REACH
    LDA P2ST
    CMP #2
    BNE :+
    RTS                  ; mid-swing: let it finish
:   JSR intercept        ; minion / projectile in reach? hit it first
    BCC :+
    RTS
:
    ; vertical class
    LDA TGDY
    CMP #DYB-24
    BCC en_above_chk
    CMP #DYB+13
    BCC en_level
    JMP en_low           ; far below: just shadow it
en_level:
    ; --- target level with P2: whip range? ---
    LDA REACH
    SEC
    SBC #4
    CMP TGDX
    BCC en_far           ; out of whip reach
    LDA TGDX
    CMP #10
    BCS en_whip
    LDA MODE             ; boss on top of us: step back out of contact
    CMP #1
    BNE en_whip
    LDA TGSD
    EOR #1
    JMP move_dir
en_whip:
    LDA TGSD
    JSR FACE_DIR
    BCC en_ret           ; turning this frame
    LDA #BTN_B
    LDY TGDY
    CPY #DYB+7
    BCC :+
    ORA #BTN_D           ; low target: crouching whip
:   STA OUT
en_ret:
    RTS

en_far:
    JSR try_sub
    BCS en_ret
    LDA TGSD
    JMP move_dir

en_above_chk:
    CMP #DYB-72
    BCC en_high          ; very high: get under it, use sub-weapons
    ; 25..72 px above: jump-whip when in reach
    LDA REACH
    CMP TGDX
    BCC en_high
    LDA TGSD
    JSR FACE_DIR
    BCC en_ret
    LDA LASTO
    AND #BTN_A
    BNE en_ret
    LDA #BTN_A
    STA OUT
    LDA #6               ; swing 6 decisions (12 frames) into the jump
    STA JWT
    RTS

en_high:
    JSR try_sub          ; out of whip reach: sub-weapon if we have one,
    BCS en_ret           ; otherwise stay with P1 (v1 follow + fight)
    JMP t_old

en_low:
    LDA MODE
    CMP #1
    BEQ :+
    JMP t_old
:   LDA TGDX
    CMP #24
    BCC en_ret
    LDA TGSD
    JMP move_dir

; whip the nearest non-boss enemy or projectile already inside whip
; reach (clears sickles, fireballs, Igor, snakes...) -> C=1 if acted
intercept:
    LDA SCN
    AND #1
    BEQ :+
    CLC
    RTS
:   LDA #$FF
    STA TA               ; best |dx|
    STA TB               ; best slot
    LDX #$16
ic_l:
    CPX TGT
    BEQ ic_n
    LDA OBJTYP,X
    BEQ ic_n
    CMP #$28
    BCS ic_n
    CMP #BOSS_LO
    BCC :+
    CMP #BOSS_HI+1
    BCC ic_n
:   LDA OBJY,X
    BEQ ic_n
    SEC
    SBC P2Y
    CLC
    ADC #30
    CMP #43              ; -30..+12 of P2
    BCS ic_n
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP REACH
    BCS ic_n
    CMP TA
    BCS ic_n
    STA TA
    STX TB
ic_n:
    DEX
    CPX #3
    BCS ic_l
    LDX TB
    CPX #$FF
    BEQ ic_no
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    LDA #0
    ROL
    JSR FACE_DIR
    BCC ic_yes           ; turning toward it
    LDX TB
    LDA OBJY,X
    SEC
    SBC P2Y
    BMI :+
    CMP #7
    BCC :+
    LDA #(BTN_B|BTN_D)   ; low: crouching whip
    BNE :++
:   LDA #BTN_B
:   STA OUT
ic_yes:
    SEC
    RTS
ic_no:
    CLC
    RTS

; A = 1 right / 0 left
move_dir:
    BEQ :+
    LDA #BTN_R
    BNE :++
:   LDA #BTN_L
:   STA OUT
    RTS

; throw the sub-weapon at the target if sensible -> C=1 thrown/turning
try_sub:
.ifdef GUARDNOSUB
    LDA MODE
    CMP #1
    BNE ts_no
.endif
    LDA SUBCD
    BNE ts_no
    LDA P2HEART
    BEQ ts_no
    LDA P2SUB
    CMP #$08
    BEQ :+
    CMP #$09
    BEQ :+
    CMP #$0B
    BEQ :+
    CMP #$0D
    BNE ts_no
:   LDA TGDX
    CMP #20
    BCC ts_no
    CMP #200
    BCS ts_no
    LDA MODE             ; outside boss fights keep hearts for real threats
    CMP #1
    BEQ :+
    LDA TGDX
    CMP #120
    BCS ts_no
:   LDA TGSD
    JSR FACE_DIR
    BCC ts_turn
    LDA #(BTN_U|BTN_B)
    STA OUT
    LDA #40
    LDY MODE
    CPY #1
    BEQ :+
    LDA #70
:   STA SUBCD
    SEC
    RTS
ts_turn:
    SEC
    RTS
ts_no:
    CLC
    RTS

; A = a, TMP0 = b  ->  A = |a-b|, C = (a >= b)
absdiff:
    SEC
    SBC TMP0
    BCS :+
    EOR #$FF
    ADC #1
    CLC
    RTS
:   SEC
    RTS


; ============================================================
; v5: solo mode. When P1 is dead/absent the CPU walks right on its own,
; jumping walls and gaps, and keeps fighting through COMBAT.
; ============================================================
.include "nav.inc"

; ============================================================
; v4: item collecting
; ------------------------------------------------------------
ITEMTYPE = $2F
ITEMRANGE = 72            ; max distance from P2 to go for an item
; item_scan (runs on a spare in-between frame) looks for the nearest loose
; item that is on P2's floor and close to both players and stores the
; direction to it in ITEMDIR. item_override (decision frame) just applies it
; when P2 is standing on the ground and nothing is threatening.
item_scan:
    LDA #0
    STA ITEMDIR
    LDA P2ST
    BNE io_no0               ; only from standing/walking on the ground
    JSR p1_absent
    LDA #0
    ROL A
    STA SOLOF                ; 1 = playing alone
    BNE :+
    LDA P1ST
    CMP #4
    BCC :+
io_no0:
    RTS
:   LDA #$FF
    STA IBEST
    STA ITGT
    LDX #$16
io_l:
    LDA OBJTYP,X
    CMP #ITEMTYPE
    BNE io_n
    LDA OBJY,X
    BEQ io_n
    SEC
    SBC P2Y
    CLC
    ADC #14
    CMP #29                  ; item within +-14 px of P2's height
    BCS io_n
    LDA OBJX,X
    CMP #12
    BCC io_n
    CMP #244
    BCS io_n
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    LDY SOLOF
    BNE :+
    CMP #ITEMRANGE
    BCS io_n
:   CMP #110
    BCS io_n
    CMP IBEST
    BCS io_n
    STA ITA                   ; |item - P2|
    LDY SOLOF
    BNE io_ok
    LDA P1X                  ; not wandering off from P1
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP #110
    BCS io_n
io_ok:
    LDA ITA
    STA IBEST
    STX ITGT
io_n:
    DEX
    CPX #3
    BCS io_l
    LDX ITGT
    CPX #$FF
    BEQ io_no
    LDA IBEST
    CMP #3
    BCC io_no                ; close enough: it will be picked up
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff              ; C=1 item is to the right
    LDA #BTN_L
    BCC :+
    LDA #BTN_R
:   STA ITEMDIR
io_no:
    RTS

item_override:
    LDA ITEMDIR
    BEQ io_no1
    LDA P2ST
    BNE io_no1
    LDA CMODE
    BNE io_no1               ; boss / guard fights take priority
    LDA RIDE
    ORA REGRP
    ORA $49
    BNE io_no1
    LDA ITEMDIR
    STA OUT
io_no1:
    RTS

; ============================================================
; v4: shared pickups. Runs every frame from the controller hook.
; Hearts, food (health) and whip upgrades that one player collects are
; also given to the other. Called in place of "LDA $7E01" at $8930, so it
; ends with that load to keep the flags the caller expects.
; ============================================================
PH1 = $7D30
PH2 = $7D31
PW1 = $7D32
PW2 = $7D33
PK1 = $7D34
PK2 = $7D35
PL1 = $7D36
PL2 = $7D37
SYNCNT = $7D38
ITEMDIR = $7D39
IBEST = $7D3A
ITGT = $7D3B
ITA = $7D3C

SYNC:
    LDA SYNCNT               ; hearts heal the collector (every 4th frame is plenty)
    AND #3
    BNE :+
    JSR heal_scan
:
    INC SYNCNT               ; every 8th frame is plenty for pickups
    LDA SYNCNT
    AND #7
    CMP #6
    BEQ :+
    LDA $7E01
    RTS
:   LDA $18
    CMP #5
    BEQ :+
    JMP sy_reset             ; only while playing
:   LDA $6025
    BEQ :+
    JMP sy_reset             ; partner dead / absent
:   LDA $6046
    BNE :+
    JMP sy_reset
:   LDA $2A
    CMP PL1
    BEQ :+
    JMP sy_reset             ; a life was lost or won: just resync
:   LDA $6028
    CMP PL2
    BEQ :+
    JMP sy_reset
:
    ; ---- hearts
    LDA $71
    SEC
    SBC PH1
    BCS :+
    LDA #0
:   STA TA
    LDA $6077
    SEC
    SBC PH2
    BCS :+
    LDA #0
:   STA TB
    LDA $71
    CLC
    ADC TB
    CMP #100
    BCC :+
    LDA #99
:   STA $71
    LDA $6077
    CLC
    ADC TA
    CMP #100
    BCC :+
    LDA #99
:   STA $6077
    ; ---- health (food)
    LDA $45
    SEC
    SBC PK1
    BCC sy_h1z
    CMP #$19
    BCC :+
sy_h1z:
    LDA #0
:   STA TA
    LDA $600C
    SEC
    SBC PK2
    BCC sy_h2z
    CMP #$19
    BCC :+
sy_h2z:
    LDA #0
:   STA TB
    LDA $45
    BEQ sy_hp2
    CLC
    ADC TB
    CMP #$41
    BCC :+
    LDA #$40
:   STA $45
sy_hp2:
    LDA $600C
    BEQ sy_whip
    CLC
    ADC TA
    CMP #$41
    BCC :+
    LDA #$40
:   STA $600C
    ; ---- whip level
sy_whip:
    LDA #0
    STA TA
    STA TB
    LDA $70
    CMP PW1
    BEQ :+
    BCC :+
    INC TA
:   LDA $6076
    CMP PW2
    BEQ :+
    BCC :+
    INC TB
:   LDA TA
    BEQ sy_w2
    LDA $6076
    CMP $70
    BCS sy_w2
    LDA $70
    STA $6076
sy_w2:
    LDA TB
    BEQ sy_reset
    LDA $70
    CMP $6076
    BCS sy_reset
    LDA $6076
    STA $70
sy_reset:
    LDA $71
    STA PH1
    LDA $6077
    STA PH2
    LDA $45
    STA PK1
    LDA $600C
    STA PK2
    LDA $70
    STA PW1
    LDA $6076
    STA PW2
    LDA $2A
    STA PL1
    LDA $6028
    STA PL2
    LDA $7E01
    RTS

; ============================================================
; v6: heart pickups also heal. Small heart = 1 bar (4), big heart = 3 bars (12).
; A heart item that vanishes next to a player was picked up by that player.
; The existing food-sharing code then hands the same healing to the partner.
; ============================================================
SOMODE = $7D90
SOSUP  = $7D91
SOATK  = $7D92
SOAX   = $7D93
HFL   = $7D5D            ; HFL,X for item slots X=3..$16 (heal amount, 0 = none)
HSAMT = $7D74
HYA   = $7D75            ; last seen Y of each item slot (the game clears Y when it removes one)
heal_scan:
    LDA $18
    CMP #5
    BEQ hs_play
    LDA #$FF                 ; not playing: forget everything (and reload the stage data)
    STA SOSTG
    LDX #$16
    LDA #0
:   STA HFL,X
    DEX
    CPX #3
    BCS :-
    RTS
hs_play:
    TXA
    PHA
    LDX #$16
hs_l:
    LDA OBJTYP,X
    CMP #ITEMTYPE
    BEQ hs_item
    LDA HFL,X
    BEQ hs_n
    STA HSAMT
    LDA #0
    STA HFL,X
    LDA OBJTYP,X
    BNE hs_n                 ; turned into something else (timed out): no pickup
    JSR hs_take
    JMP hs_n
hs_item:
    LDA $0584,X
    AND #$0F
    BNE :+
    LDA #4                   ; small heart
    BNE hs_st
:   CMP #4
    BNE hs_z
    LDA #12                  ; big heart
    BNE hs_st
hs_z:
    LDA #0
hs_st:
    STA HFL,X
    LDA OBJY,X
    STA HYA,X
hs_n:
    DEX
    CPX #3
    BCS hs_l
    PLA
    TAX
    RTS

hs_take:                     ; X = slot that vanished
    LDA P1Y
    BEQ hs_p2
    CMP #$F0
    BCS hs_p2
    LDA $45
    BEQ hs_p2
    LDA P1X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP #28
    BCS hs_p2
    LDA P1Y
    STA TMP0
    LDA HYA,X
    JSR absdiff
    CMP #28
    BCS hs_p2
    LDA $45
    CLC
    ADC HSAMT
    CMP #$41
    BCC :+
    LDA #$40
:   STA $45
    RTS
hs_p2:
    LDA $6025
    BNE hs_ret
    LDA $6046
    BEQ hs_ret
    CMP #$F4
    BEQ hs_ret
    LDA $600C
    BEQ hs_ret
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP #28
    BCS hs_ret
    LDA P2Y
    STA TMP0
    LDA HYA,X
    JSR absdiff
    CMP #28
    BCS hs_ret
    LDA $600C
    CLC
    ADC HSAMT
    CMP #$41
    BCC :+
    LDA #$40
:   STA $600C
hs_ret:
    RTS

solo_combat:
    LDA SOSUP            ; walking on its own: if it keeps swinging at something it
    BEQ :+               ; cannot hit (e.g. a candle out of reach), walk on instead
    DEC SOSUP
    RTS
:   LDA P2WXL
    CMP SOAX
    BEQ :+
    STA SOAX
    LDA #0
    STA SOATK
:   JSR COMBAT
    LDA OUT
    AND #BTN_B
    BEQ so_ok
    JSR near_enemy       ; a real enemy next to us: keep fighting
    BCS so_ok
    INC SOATK
    LDA SOATK
    CMP #2
    BCC so_ok
    LDA #0
    STA SOATK
    LDA #70
    STA SOSUP
so_ok:
    RTS

near_enemy:              ; C=1 if a live enemy is within 56 px across and 40 px up/down
    TXA
    PHA
    LDX #$16
ne_l:
    LDA OBJTYP,X
    BEQ ne_n
    CMP #$28
    BCS ne_n
    LDA OBJY,X
    BEQ ne_n
    LDA P2X
    STA TMP0
    LDA OBJX,X
    JSR absdiff
    CMP #56
    BCS ne_n
    LDA P2Y
    STA TMP0
    LDA OBJY,X
    JSR absdiff
    CMP #40
    BCS ne_n
    PLA
    TAX
    SEC
    RTS
ne_n:
    DEX
    CPX #3
    BCS ne_l
    PLA
    TAX
    CLC
    RTS
