;=============================================================================
;  GRAN PREMIO NES  -  Franco Colapinto / Alpine #43
;  NROM (mapper 0), 16KB PRG + 8KB CHR, NTSC
;=============================================================================

.segment "HEADER"
    .byte "NES", $1A
    .byte 1                 ; 16KB PRG
    .byte 1                 ; 8KB CHR
    .byte $00               ; mirroring horizontal (nametables en vertical)
    .byte $00
    .res 8, 0

;----------------------------------------------------------------- constantes
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014

ST_TITLE  = 0
ST_RACE   = 1
ST_END    = 2

PLAYER_Y  = 168
ROAD_L    = 48          ; borde izquierdo del asfalto (px)
ROAD_R    = 192         ; x maximo del auto para seguir en pista
MAXSPD_HI = 4           ; velocidad maxima (px/frame)
LAP_LEN   = 3000        ; unidades de distancia por vuelta
TOTAL_LAPS = 3

T_GRASS_A = $01
T_GRASS_B = $02
T_ROAD    = $03
T_DASH    = $04
T_CURB_A  = $05
T_CURB_B  = $06
T_EDGE    = $07

.segment "ZEROPAGE"
nmiFlag:    .res 1
frameCnt:   .res 1
pad1:       .res 1
padNew:     .res 1
padOld:     .res 1
gameState:  .res 1
ctrlSh:     .res 1
maskSh:     .res 1
scrollLo:   .res 1
scrollHi:   .res 1
scrollFrac: .res 1
playerX:    .res 1
playerXf:   .res 1
spdLo:      .res 1
spdHi:      .res 1
distLo:     .res 1
distHi:     .res 1
lapNum:     .res 1
crashT:     .res 1
offRoad:    .res 1
seed:       .res 1
oamIdx:     .res 1
ptr:        .res 2
tmp1:       .res 1
tmp2:       .res 1
tmp3:       .res 1
tmp4:       .res 1
dLo:        .res 1
dHi:        .res 1
secTick:    .res 1
secs:       .res 1
mins:       .res 1
numLo:      .res 1
numHi:      .res 1
dig0:       .res 1
dig1:       .res 1
dig2:       .res 1
finished:   .res 1

; Exportadas para que tools/probe.py pueda leerlas por nombre desde el emulador
.exportzp gameState, playerX, spdLo, spdHi, distLo, distHi
.exportzp lapNum, crashT, offRoad, scrollLo, secs, mins, finished

.segment "OAM"
oam:        .res 256

.segment "BSS"
rivalX:     .res 4
rivalYLo:   .res 4
rivalYHi:   .res 4
rivalSLo:   .res 4
rivalSHi:   .res 4
rivalPal:   .res 4

;=============================================================================
.segment "CODE"

reset:
    sei
    cld
    ldx #$40
    stx $4017
    ldx #$FF
    txs
    inx
    stx PPUCTRL
    stx PPUMASK
    stx $4010

:   bit PPUSTATUS
    bpl :-

    ; limpiar RAM
    lda #0
    ldx #0
:   sta $0000,x
    sta $0100,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne :-

    lda #$FF
    ldx #0
:   sta oam,x               ; sprites fuera de pantalla
    inx
    bne :-

:   bit PPUSTATUS
    bpl :-

    jsr LoadPalettes
    jsr InitAPU

    lda #$77
    sta seed

    jsr GoTitle

main:
    jsr WaitFrame
    jsr ReadPad
    lda gameState
    cmp #ST_TITLE
    bne :+
    jsr TitleLogic
    jmp main
:   cmp #ST_RACE
    bne :+
    jsr RaceLogic
    jmp main
:   jsr EndLogic
    jmp main

;--------------------------------------------------------------------- NMI
nmi:
    pha
    txa
    pha
    tya
    pha

    lda #$00
    sta OAMADDR
    lda #$02
    sta OAMDMA

    bit PPUSTATUS
    lda ctrlSh
    sta PPUCTRL
    lda maskSh
    sta PPUMASK
    lda #$00
    sta PPUSCROLL
    lda scrollLo
    sta PPUSCROLL

    inc frameCnt
    lda #1
    sta nmiFlag

    pla
    tay
    pla
    tax
    pla
irq:
    rti

WaitFrame:
    lda #0
    sta nmiFlag
:   lda nmiFlag
    beq :-
    rts

;--------------------------------------------------------------- controlador
ReadPad:
    lda pad1
    sta padOld
    lda #1
    sta $4016
    lda #0
    sta $4016
    ldx #8
:   lda $4016
    lsr a
    rol pad1
    dex
    bne :-
    lda padOld
    eor #$FF
    and pad1
    sta padNew
    rts

BTN_A     = $80
BTN_B     = $40
BTN_SEL   = $20
BTN_START = $10
BTN_UP    = $08
BTN_DOWN  = $04
BTN_LEFT  = $02
BTN_RIGHT = $01

;------------------------------------------------------------------ paletas
LoadPalettes:
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #0
:   lda palette,x
    sta PPUDATA
    inx
    cpx #32
    bne :-
    rts

palette:
    ; fondo
    .byte $0F,$1A,$2A,$30   ; 0 pasto
    .byte $0F,$00,$10,$30   ; 1 asfalto
    .byte $0F,$16,$30,$00   ; 2 piano
    .byte $0F,$12,$30,$27   ; 3 texto azul
    ; sprites
    .byte $0F,$12,$0F,$30   ; 0 Alpine (azul)
    .byte $0F,$16,$0F,$30   ; 1 rival rojo
    .byte $0F,$10,$0F,$30   ; 2 rival plateado
    .byte $0F,$30,$0F,$27   ; 3 texto HUD

;------------------------------------------------------------------- APU
InitAPU:
    lda #$0F
    sta $4015
    lda #$30
    sta $4000
    sta $4004
    sta $400C
    rts

; ruido de motor segun velocidad
EngineSound:
    lda crashT
    beq @norm
    lda #$3C                ; motor "roto" al chocar
    sta $400C
    lda #$0C
    sta $400E
    lda #$08
    sta $400F
    rts
@norm:
    lda spdHi
    ora spdLo
    bne :+
    lda #$30                ; motor apagado
    sta $400C
    rts
:   lda #$33
    sta $400C
    lda #9
    sec
    sbc spdHi
    and #$0F
    sta $400E
    lda #$08
    sta $400F
    rts

SilenceEngine:
    lda #$30
    sta $400C
    rts

Blip:
    lda #$9F
    sta $4000
    lda #$00
    sta $4001
    lda #$60
    sta $4002
    lda #$08
    sta $4003
    rts

;------------------------------------------------------------------ random
Rand:
    lda seed
    asl a
    bcc :+
    eor #$1D
:   clc
    adc frameCnt
    sta seed
    rts

;------------------------------------------------- utilidades de PPU (render off)
RenderOff:
    lda #0
    sta maskSh
    sta PPUMASK
    sta PPUCTRL
    lda #0
    sta ctrlSh
    rts

RenderOn:
    lda #%10001000          ; NMI on, sprites en pattern table 1
    sta ctrlSh
    sta PPUCTRL             ; imprescindible: reactiva el NMI ya mismo
    lda #%00011110
    sta maskSh
    sta PPUMASK
    rts

; llena una nametable completa con el tile en A
; ptr = direccion base ($2000 o $2800)
FillNT:
    sta tmp1
    bit PPUSTATUS
    lda ptr+1
    sta PPUADDR
    lda ptr+0
    sta PPUADDR
    ldy #4                  ; 4 * 256 = 1024 bytes
    ldx #0
@lp:
    lda tmp1
    sta PPUDATA
    inx
    bne @lp
    dey
    bne @lp
    rts

; escribe texto (ptr -> string terminado en 0) en la direccion PPU tmp3/tmp4
DrawText:
    bit PPUSTATUS
    lda tmp4
    sta PPUADDR
    lda tmp3
    sta PPUADDR
    ldy #0
@lp:
    lda (ptr),y
    beq @done
    sta PPUDATA
    iny
    bne @lp
@done:
    rts

;=============================================================================
; PANTALLA DE TITULO
;=============================================================================
GoTitle:
    jsr RenderOff
    jsr SilenceEngine

    lda #<$2000
    sta ptr
    lda #>$2000
    sta ptr+1
    lda #$20                ; espacio
    jsr FillNT

    ; atributos: todo paleta 3 (texto azul) -> ya quedan en 0, escribimos $FF
    bit PPUSTATUS
    lda #$23
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #64
    lda #$FF
:   sta PPUDATA
    dex
    bne :-

    ldx #0
@txt:
    lda titleAddrLo,x
    sta tmp3
    lda titleAddrHi,x
    sta tmp4
    lda titlePtrLo,x
    sta ptr
    lda titlePtrHi,x
    sta ptr+1
    txa
    pha
    jsr DrawText
    pla
    tax
    inx
    cpx #7
    bne @txt

    lda #0
    sta scrollLo
    sta scrollHi
    sta scrollFrac
    lda #ST_TITLE
    sta gameState
    jsr RenderOn
    rts

TitleLogic:
    ; parpadeo de "PRESS START" via sprite? -> simple: nada
    lda padNew
    and #BTN_START
    beq :+
    jsr Blip
    jsr StartRace
:   rts

;=============================================================================
; ARRANQUE DE CARRERA
;=============================================================================
StartRace:
    jsr RenderOff
    jsr DrawTrack

    lda #120
    sta playerX
    lda #0
    sta playerXf
    sta spdLo
    sta spdHi
    sta distLo
    sta distHi
    sta crashT
    sta scrollFrac
    sta secTick
    sta secs
    sta mins
    sta finished
    lda #1
    sta lapNum
    lda #0
    sta scrollLo
    sta scrollHi

    ; rivales
    ldx #0
@rv:
    jsr SpawnRival
    lda #200
    sta rivalYHi,x          ; arrancan repartidos adelante
    txa
    asl a
    asl a
    asl a
    asl a
    asl a
    eor #$3F
    sta rivalYHi,x
    inx
    cpx #4
    bne @rv

    lda #ST_RACE
    sta gameState
    jsr RenderOn
    rts

; dibuja el circuito en las dos nametables ($2000 y $2800)
DrawTrack:
    lda #$20
    sta tmp4                ; high byte base
    jsr DrawTrackNT
    lda #$28
    sta tmp4
    jsr DrawTrackNT

    ; atributos para ambas
    lda #$23
    sta tmp4
    jsr DrawTrackAttr
    lda #$2B
    sta tmp4
    jsr DrawTrackAttr
    rts

DrawTrackNT:
    bit PPUSTATUS
    lda tmp4
    sta PPUADDR
    lda #$00
    sta PPUADDR

    lda #0
    sta tmp1                ; fila
@row:
    ldx #0                  ; columna
@col:
    ; grass?
    cpx #4
    bcc @grass
    cpx #28
    bcs @grass
    ; piano izquierdo (4,5) / derecho (26,27)
    cpx #6
    bcc @curb
    cpx #26
    bcs @curb
    ; asfalto
    cpx #15
    bne @road
    lda tmp1
    and #1
    bne @road
    lda #T_DASH
    jmp @put
@road:
    lda #T_ROAD
    jmp @put
@curb:
    lda tmp1
    and #1
    beq :+
    lda #T_CURB_B
    jmp @put
:   lda #T_CURB_A
    jmp @put
@grass:
    txa
    clc
    adc tmp1
    and #3
    bne :+
    lda #T_GRASS_B
    jmp @put
:   lda #T_GRASS_A
@put:
    sta PPUDATA
    inx
    cpx #32
    bne @col
    inc tmp1
    lda tmp1
    cmp #30
    bne @row
    rts

DrawTrackAttr:
    bit PPUSTATUS
    lda tmp4
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldy #8                  ; 8 filas de atributos
@r:
    ldx #0
@c:
    lda attrRow,x
    sta PPUDATA
    inx
    cpx #8
    bne @c
    dey
    bne @r
    rts

attrRow:
    .byte $00, $66, $55, $55, $55, $55, $99, $00

;=============================================================================
; LOGICA DE CARRERA
;=============================================================================
RaceLogic:
    jsr UpdateTimer
    jsr UpdatePlayer
    jsr UpdateScroll
    jsr UpdateRivals
    jsr CheckCollisions
    jsr UpdateDistance
    jsr EngineSound
    jsr BuildOAM
    rts

UpdateTimer:
    lda finished
    bne @rts
    inc secTick
    lda secTick
    cmp #60
    bne @rts
    lda #0
    sta secTick
    inc secs
    lda secs
    cmp #60
    bne @rts
    lda #0
    sta secs
    inc mins
@rts:
    rts

;----------------------------------------------------------------- jugador
UpdatePlayer:
    lda crashT
    beq @ctrl
    dec crashT
    jmp @move               ; sin control mientras trompea

@ctrl:
    ; acelerador
    lda pad1
    and #BTN_A
    beq @noacc
    ; acelerar
    lda spdLo
    clc
    adc #$0C
    sta spdLo
    lda spdHi
    adc #0
    sta spdHi
    jmp @clamp
@noacc:
    lda pad1
    and #BTN_B
    beq @coast
    ; freno
    lda spdLo
    sec
    sbc #$30
    sta spdLo
    lda spdHi
    sbc #0
    sta spdHi
    bpl @clamp
    lda #0
    sta spdLo
    sta spdHi
    jmp @clamp
@coast:
    lda spdLo
    sec
    sbc #$06
    sta spdLo
    lda spdHi
    sbc #0
    sta spdHi
    bpl @clamp
    lda #0
    sta spdLo
    sta spdHi

@clamp:
    ; limite segun este o no en pista
    lda offRoad
    beq @onroad
    lda spdHi
    cmp #2
    bcc @spdok
    lda #1
    sta spdHi
    lda #$80
    sta spdLo
    jmp @spdok
@onroad:
    lda spdHi
    cmp #MAXSPD_HI
    bcc @spdok
    lda #MAXSPD_HI
    sta spdHi
    lda #0
    sta spdLo
@spdok:

    ; direccion (mas agil a mas velocidad)
    lda pad1
    and #BTN_LEFT
    beq @noleft
    jsr SteerAmount
    sta tmp1
    lda playerX
    sec
    sbc tmp1
    sta playerX
@noleft:
    lda pad1
    and #BTN_RIGHT
    beq @noright
    jsr SteerAmount
    sta tmp1
    lda playerX
    clc
    adc tmp1
    sta playerX
@noright:

@move:
    ; limites de pantalla
    lda playerX
    cmp #24
    bcs :+
    lda #24
    sta playerX
:   lda playerX
    cmp #208
    bcc :+
    lda #208
    sta playerX
:
    ; fuera de pista?
    lda #0
    sta offRoad
    lda playerX
    cmp #ROAD_L
    bcs :+
    lda #1
    sta offRoad
    rts
:   lda playerX
    cmp #ROAD_R+1
    bcc :+
    lda #1
    sta offRoad
:   rts

SteerAmount:
    lda spdHi
    beq @zero
    cmp #2
    bcc @slow
    lda #2
    rts
@slow:
    lda #2
    rts
@zero:
    lda spdLo
    cmp #$40
    bcc :+
    lda #1
    rts
:   lda #0
    rts

;------------------------------------------------------------------ scroll
; scroll disminuye => el fondo baja en pantalla => sensacion de avance
; Las dos nametables son identicas y el patron del asfalto se repite cada
; 16px (240 es multiplo de 16), asi que alcanza con mantener scroll en 0..239
; y dejar que el PPU cruce a la nametable de abajo solo: la union no se nota.
UpdateScroll:
    lda scrollFrac
    sec
    sbc spdLo
    sta scrollFrac
    lda scrollLo
    sbc spdHi
    bcs @done               ; sin borrow: sigue en rango
    clc
    adc #240                ; se paso de 0 hacia abajo -> envolver
@done:
    sta scrollLo
    rts

;----------------------------------------------------------------- rivales
SpawnRival:
    txa
    pha
    jsr Rand
    pla
    tax
    lda seed
    and #3
    tay
    lda laneX,y
    sta rivalX,x
    lda seed
    and #1
    sta rivalPal,x
    lda seed
    and #$60
    clc
    adc #$60
    sta rivalSLo,x
    lda seed
    and #1
    clc
    adc #1
    sta rivalSHi,x
    lda #0
    sta rivalYLo,x
    rts

laneX:
    .byte 56, 92, 132, 168

UpdateRivals:
    ldx #0
@lp:
    ; delta = velocidad jugador - velocidad rival
    lda spdLo
    sec
    sbc rivalSLo,x
    sta dLo
    lda spdHi
    sbc rivalSHi,x
    sta dHi
    bmi @neg

    ; delta positivo: el rival baja hacia nosotros
    lda rivalYLo,x
    clc
    adc dLo
    sta rivalYLo,x
    lda rivalYHi,x
    adc dHi
    sta rivalYHi,x
    cmp #240
    bcc @next
    jsr SpawnRival          ; salio por abajo -> reaparece arriba
    lda #0
    sta rivalYHi,x
    jmp @next

@neg:
    ; delta negativo: el rival se aleja hacia arriba
    lda dLo
    eor #$FF
    clc
    adc #1
    sta dLo
    lda dHi
    eor #$FF
    adc #0
    sta dHi
    lda rivalYLo,x
    sec
    sbc dLo
    sta rivalYLo,x
    lda rivalYHi,x
    sbc dHi
    sta rivalYHi,x
    bcs @next
    jsr SpawnRival          ; salio por arriba -> reaparece abajo
    lda #238
    sta rivalYHi,x
@next:
    inx
    cpx #4
    bne @lp
    rts

;--------------------------------------------------------------- colisiones
CheckCollisions:
    lda crashT
    bne @rts
    ldx #0
@lp:
    ; |playerX - rivalX| < 13 ?
    lda playerX
    sec
    sbc rivalX,x
    bcs :+
    eor #$FF
    clc
    adc #1
:   cmp #13
    bcs @next
    ; |PLAYER_Y - rivalY| < 13 ?
    lda #PLAYER_Y
    sec
    sbc rivalYHi,x
    bcs :+
    eor #$FF
    clc
    adc #1
:   cmp #13
    bcs @next
    jmp @crash
@next:
    inx
    cpx #4
    bne @lp
@rts:
    rts

@crash:
    lda #24
    sta crashT
    ; perder la mitad de la velocidad
    lsr spdHi
    ror spdLo
    ; empujar al costado
    lda playerX
    cmp rivalX,x
    bcs :+
    sec
    sbc #8
    sta playerX
    jmp @snd
:   clc
    adc #8
    sta playerX
@snd:
    lda #$1F
    sta $4004
    lda #$8F
    sta $4005
    lda #$40
    sta $4006
    lda #$18
    sta $4007
    rts

;--------------------------------------------------------------- distancia
UpdateDistance:
    lda finished
    bne @rts
    lda distLo
    clc
    adc spdHi
    sta distLo
    lda distHi
    adc #0
    sta distHi
    ; vuelta completa?
    lda distHi
    cmp #>LAP_LEN
    bcc @rts
    bne @lap
    lda distLo
    cmp #<LAP_LEN
    bcc @rts
@lap:
    lda distLo
    sec
    sbc #<LAP_LEN
    sta distLo
    lda distHi
    sbc #>LAP_LEN
    sta distHi
    inc lapNum
    jsr Blip
    lda lapNum
    cmp #TOTAL_LAPS+1
    bcc @rts
    lda #1
    sta finished
    jsr GoEnd
@rts:
    rts

;=============================================================================
; PANTALLA FINAL
;=============================================================================
GoEnd:
    jsr RenderOff
    jsr SilenceEngine

    lda #<$2000
    sta ptr
    lda #>$2000
    sta ptr+1
    lda #$20
    jsr FillNT

    bit PPUSTATUS
    lda #$23
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #64
    lda #$FF
:   sta PPUDATA
    dex
    bne :-

    ldx #0
@txt:
    lda endAddrLo,x
    sta tmp3
    lda endAddrHi,x
    sta tmp4
    lda endPtrLo,x
    sta ptr
    lda endPtrHi,x
    sta ptr+1
    txa
    pha
    jsr DrawText
    pla
    tax
    inx
    cpx #4
    bne @txt

    ; tiempo final: M:SS en $21EE
    bit PPUSTATUS
    lda #$21
    sta PPUADDR
    lda #$F1
    sta PPUADDR
    lda mins
    clc
    adc #'0'
    sta PPUDATA
    lda #':'
    sta PPUDATA
    lda secs
    sta numLo
    lda #0
    sta numHi
    jsr ToDigits
    lda dig1
    clc
    adc #'0'
    sta PPUDATA
    lda dig0
    clc
    adc #'0'
    sta PPUDATA

    lda #0
    sta scrollLo
    sta scrollHi
    lda #ST_END
    sta gameState

    ; ocultar sprites
    ldx #0
    lda #$FF
:   sta oam,x
    inx
    bne :-

    jsr RenderOn
    rts

EndLogic:
    lda padNew
    and #BTN_START
    beq :+
    jsr Blip
    jsr GoTitle
:   rts

;=============================================================================
; SPRITES
;=============================================================================
BuildOAM:
    lda #0
    sta oamIdx

    ; --- HUD (arriba): V n / 3      y    velocidad
    lda #'V'
    ldx #16
    ldy #8
    jsr PutChar
    lda lapNum
    clc
    adc #'0'
    ldx #24
    ldy #8
    jsr PutChar
    lda #'/'
    ldx #32
    ldy #8
    jsr PutChar
    lda #'0'+TOTAL_LAPS
    ldx #40
    ldy #8
    jsr PutChar

    ; velocidad en km/h ~ (spd >> 4) * 5
    lda spdHi
    sta numHi
    lda spdLo
    sta numLo
    ldy #4
:   lsr numHi
    ror numLo
    dey
    bne :-
    ; *5
    lda numLo
    sta tmp1
    lda numHi
    sta tmp2
    asl numLo
    rol numHi
    asl numLo
    rol numHi
    lda numLo
    clc
    adc tmp1
    sta numLo
    lda numHi
    adc tmp2
    sta numHi
    jsr ToDigits

    lda dig2
    clc
    adc #'0'
    ldx #192
    ldy #8
    jsr PutChar
    lda dig1
    clc
    adc #'0'
    ldx #200
    ldy #8
    jsr PutChar
    lda dig0
    clc
    adc #'0'
    ldx #208
    ldy #8
    jsr PutChar

    ; --- rivales
    ldx #0
@rv:
    lda rivalYHi,x
    cmp #240
    bcs @rvnext
    cmp #8
    bcc @rvnext
    txa
    pha
    lda rivalX,x
    sta tmp1
    lda rivalYHi,x
    sta tmp2
    lda rivalPal,x
    clc
    adc #1                  ; paletas 1 o 2
    sta tmp3
    jsr PutCar
    pla
    tax
@rvnext:
    inx
    cpx #4
    bne @rv

    ; --- jugador (parpadea si choco)
    lda crashT
    beq @drawp
    lda frameCnt
    and #2
    bne @hidep
@drawp:
    lda playerX
    sta tmp1
    lda #PLAYER_Y
    sta tmp2
    lda #0
    sta tmp3
    jsr PutCar
@hidep:

    ; apagar el resto de los sprites
    ldx oamIdx
    lda #$FF
@clr:
    sta oam,x
    inx
    bne @clr
    rts

; A = tile/char, X = x, Y = y   (paleta 3)
PutChar:
    sta tmp4
    stx tmp1
    sty tmp2
    ldx oamIdx
    lda tmp2
    sec
    sbc #1
    sta oam,x
    inx
    lda tmp4
    sta oam,x
    inx
    lda #3
    sta oam,x
    inx
    lda tmp1
    sta oam,x
    inx
    stx oamIdx
    rts

; auto 16x16: tmp1 = x, tmp2 = y, tmp3 = paleta
PutCar:
    ldx oamIdx
    ldy #0
@lp:
    lda tmp2
    clc
    adc carDY,y
    sec
    sbc #1
    sta oam,x
    inx
    lda #$80
    clc
    adc carTile,y
    sta oam,x
    inx
    lda tmp3
    sta oam,x
    inx
    lda tmp1
    clc
    adc carDX,y
    sta oam,x
    inx
    iny
    cpy #4
    bne @lp
    stx oamIdx
    rts

carDX:   .byte 0, 8, 0, 8
carDY:   .byte 0, 0, 8, 8
carTile: .byte 0, 1, 2, 3

; numLo/numHi -> dig2 dig1 dig0 (centenas, decenas, unidades)
ToDigits:
    lda #0
    sta dig2
    sta dig1
    sta dig0
@c100:
    lda numHi
    bne @sub100
    lda numLo
    cmp #100
    bcc @c10
@sub100:
    lda numLo
    sec
    sbc #100
    sta numLo
    lda numHi
    sbc #0
    sta numHi
    inc dig2
    jmp @c100
@c10:
    lda numLo
    cmp #10
    bcc @done
    sbc #10
    sta numLo
    inc dig1
    jmp @c10
@done:
    lda numLo
    sta dig0
    rts

;=============================================================================
; TEXTOS
;=============================================================================
txt1: .byte "GRAN PREMIO NES", 0
txt2: .byte "FRANCO COLAPINTO", 0
txt3: .byte "ALPINE  N 43", 0
txt4: .byte "PRESS START", 0
txt5: .byte "A ACELERA   B FRENA", 0
txt6: .byte "IZQ/DER PARA ESQUIVAR", 0
txt7: .byte "3 VUELTAS", 0

titlePtrLo: .byte <txt1, <txt2, <txt3, <txt7, <txt4, <txt5, <txt6
titlePtrHi: .byte >txt1, >txt2, >txt3, >txt7, >txt4, >txt5, >txt6
; direcciones PPU (fila*32 + col + $2000)
titleAddrLo: .byte $88, $28, $6B, $0C, $CC, $4A, $89
titleAddrHi: .byte $20, $21, $21, $22, $22, $23, $23

etxt1: .byte "FIN DE CARRERA", 0
etxt2: .byte "COLAPINTO EN META", 0
etxt3: .byte "TIEMPO", 0
etxt4: .byte "PRESS START", 0

endPtrLo: .byte <etxt1, <etxt2, <etxt3, <etxt4
endPtrHi: .byte >etxt1, >etxt2, >etxt3, >etxt4
endAddrLo: .byte $89, $27, $EA, $8A
endAddrHi: .byte $20, $21, $21, $22

;=============================================================================
.segment "VECTORS"
    .word nmi
    .word reset
    .word irq

.segment "CHARS"
    .incbin "build/game.chr"
