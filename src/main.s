;=============================================================================
;  GRAN PREMIO NES  -  Franco Colapinto / Alpine #43
;  MMC1 / SxROM (mapper 1), 128KB PRG + 32KB CHR, NTSC
;
;  El PRG queda en modo 3: $8000-$BFFF conmutable (BANK0..BANK6) y
;  $C000-$FFFF fijo en el ultimo banco (CORE, CODE, RODATA, VECTORS).
;=============================================================================

.segment "HEADER"
    .byte "NES", $1A
    .byte 8                 ; 128KB PRG (unidades de 16KB)
    .byte 4                 ; 32KB CHR  (unidades de 8KB)
    .byte $10               ; nibble alto = mapper 1, mirroring horizontal
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
TRACK_CC  = 16          ; columna del centro del asfalto en la recta
CC_MIN    = 12          ; el circuito no puede correrse mas alla de estos
CC_MAX    = 20          ; limites sin salirse de las 32 columnas

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
scrollLo:   .res 1          ; scroll Y dentro de la nametable de arriba (0..239)
scrollNT:   .res 1          ; 0 o 2: cual nametable va arriba (bit 1 de PPUCTRL)
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
prgBank:    .res 1          ; banco mapeado hoy en $8000 (el mapper no se lee)
bankVal:    .res 1          ; prueba de banking: byte leido desde BANK0

; --- circuito dinamico (ver "El circuito en filas" mas abajo) ---
topRow:     .res 1          ; fila virtual (0..59) donde arranca la pantalla
lastTop:    .res 1          ; topRow del cuadro anterior, para detectar el cruce
genRow:     .res 1          ; fila virtual que se esta armando
genCC:      .res 1          ; columna del centro del asfalto en esa fila
rowReady:   .res 1          ; hay una fila armada esperando que el NMI la escriba
rowAddrLo:  .res 1          ; direccion de PPU donde va esa fila
rowAddrHi:  .res 1
attrReady:  .res 1          ; idem para la fila de atributos del bloque
attrAddrLo: .res 1
attrAddrHi: .res 1
trkSeg:     .res 1          ; segmento del circuito en curso
trkLeft:    .res 1          ; bloques que le quedan a ese segmento

; Exportadas para que tools/probe.py pueda leerlas por nombre desde el emulador
.exportzp gameState, playerX, spdLo, spdHi, distLo, distHi
.exportzp lapNum, crashT, offRoad, scrollLo, secs, mins, finished
.exportzp prgBank, bankVal, topRow, genCC

.segment "OAM"
oam:        .res 256

.segment "BSS"
rivalX:     .res 4
rivalYLo:   .res 4
rivalYHi:   .res 4
rivalSLo:   .res 4
rivalSHi:   .res 4
rivalPal:   .res 4

rowBuf:     .res 32         ; la fila que el NMI va a mandar a la PPU
attrBuf:    .res 8          ; la fila de atributos del bloque
rowCC:      .res 60         ; centro del asfalto de cada fila virtual

; rowCC no es zeropage, asi que va con .export y no con .exportzp. Lo lee
; tools/probe.py para verificar que el circuito curva de verdad.
.export rowCC

;=============================================================================
; MMC1
;
; Los registros del mapper son SERIALES: cada uno se carga con cinco
; escrituras seguidas, y de cada escritura solo entra el bit 0. Un 'sta'
; suelto no configura nada.
;
; Y OJO: nunca INC/DEC ni ningun read-modify-write sobre $8000-$FFFF. Esas
; instrucciones escriben dos veces y la segunda le mete basura al mapper.
; Por eso aca se desplaza con 'lsr a', que toca el acumulador y no memoria.
;
; Todo esto vive en CORE, que el linker pone en el banco fijo: la rutina que
; cambia de banco no puede desaparecer justo cuando se la llama.
;=============================================================================
.segment "CORE"

MMC1_CTRL = $8000       ; mirroring + modo de PRG y CHR
MMC1_CHR0 = $A000
MMC1_CHR1 = $C000
MMC1_PRG  = $E000

; mirroring horizontal (nametables apiladas en vertical, que es lo que pide
; el scroll), PRG modo 3 ($C000 fijo) y CHR en un solo banco de 8KB
MMC1_CTRL_VAL = %01111

Mmc1Init:
    ; el bit 7 en cualquier registro resetea el shift register y fuerza modo 3
    lda #$80
    sta MMC1_CTRL

    lda #MMC1_CTRL_VAL      ; control: cinco bits, de a uno
    sta MMC1_CTRL
    lsr a
    sta MMC1_CTRL
    lsr a
    sta MMC1_CTRL
    lsr a
    sta MMC1_CTRL
    lsr a
    sta MMC1_CTRL

    lda #0                  ; CHR banco 0: los tiles del juego viven ahi
    sta MMC1_CHR0
    sta MMC1_CHR0
    sta MMC1_CHR0
    sta MMC1_CHR0
    sta MMC1_CHR0

    lda #0                  ; arrancar con BANK0 mapeado en $8000
    jsr SwitchBank
    rts

; A = numero de banco (0..6) -> queda mapeado en $8000-$BFFF
SwitchBank:
    sta prgBank
    sta MMC1_PRG
    lsr a
    sta MMC1_PRG
    lsr a
    sta MMC1_PRG
    lsr a
    sta MMC1_PRG
    lsr a
    sta MMC1_PRG
    rts

; Prueba de que el banking funciona de verdad: mapea BANK0 y lee un byte de
; una tabla que solo existe ahi. A = indice, devuelve el byte en A.
ReadBank0:
    tay
    lda #0
    jsr SwitchBank
    lda bank0Tab,y
    rts

;=============================================================================
; Tabla de prueba, en el banco conmutable. Desde $C000 este dato no se ve si
; BANK0 no esta mapeado: es justamente lo que verifica el test.
;=============================================================================
.segment "BANK0"

bank0Tab:
    .byte "COL", 43         ; codigo del piloto y su numero

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

    jsr Mmc1Init            ; dejar el mapper en un estado conocido antes de nada

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

    ; el numero de Colapinto sale de una tabla que vive en el banco conmutable
    lda #3
    jsr ReadBank0
    sta bankVal

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

    ; Fila nueva del circuito, si el bucle principal dejo una lista. Va ANTES
    ; del scroll: escribir $2006 pisa el latch, asi que el scroll se setea
    ; ultimo o la pantalla queda corrida.
    lda rowReady
    beq @noRow
    lda #0
    sta rowReady
    bit PPUSTATUS
    lda rowAddrHi
    sta PPUADDR
    lda rowAddrLo
    sta PPUADDR
    ldx #0
@rowLp:
    lda rowBuf,x
    sta PPUDATA
    inx
    cpx #32
    bne @rowLp
@noRow:

    lda attrReady
    beq @noAttr
    lda #0
    sta attrReady
    bit PPUSTATUS
    lda attrAddrHi
    sta PPUADDR
    lda attrAddrLo
    sta PPUADDR
    ldx #0
@attrLp:
    lda attrBuf,x
    sta PPUDATA
    inx
    cpx #8
    bne @attrLp
@noAttr:

    bit PPUSTATUS
    lda ctrlSh
    ora scrollNT            ; que nametable va arriba
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
    sta scrollNT
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
    lda #0                  ; el circuito arranca en la fila virtual 0
    sta scrollLo
    sta scrollNT
    sta lastTop
    sta topRow
    sta rowReady
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
    sta scrollNT

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

; Dibuja el circuito entero: las 60 filas virtuales de las dos nametables.
; Usa el mismo BuildRow que la carrera, asi el dibujo inicial y el dinamico no
; pueden salir distintos. Solo con el rendering apagado.
DrawTrack:
    lda #TRACK_CC
    sta genCC
    lda #0
    sta genRow
    sta trkSeg
    lda segLen              ; el primer segmento es recta: dejarlo entero
    sta trkLeft
@lp:
    ; Aca se genera hacia abajo, asi que el bloque arranca en su fila de
    ; arriba: la 0, 4, ... 24 y la 28.
    ;
    ; El relleno inicial NO llama a AdvanceTrack: se larga en recta y las 60
    ; filas quedan con el mismo centro. Si el trazado avanzara aca, el final
    ; del buffer no engancharia con el principio y la pista arrancaria con un
    ; codo. Las curvas empiezan a entrar cuando la carrera arranca.
    lda genRow
    cmp #30
    bcc :+
    sec
    sbc #30
:   and #3
    bne @row
    jsr BuildAttr
    jsr SetAttrAddr
    jsr WriteAttrNow
@row:
    jsr BuildRow
    jsr SetRowAddr
    jsr WriteRowNow
    inc genRow
    lda genRow
    cmp #60
    bne @lp
    rts

;=============================================================================
; LOGICA DE CARRERA
;=============================================================================
RaceLogic:
    jsr UpdateTimer
    jsr UpdatePlayer
    jsr UpdateScroll
    jsr UpdateTrack
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
    ; fuera de pista? El circuito se corre, asi que el borde no es fijo: hay
    ; que mirar donde esta el asfalto a la altura del auto.
    lda #0
    sta offRoad
    jsr PlayerShift
    sta tmp3
    lda playerX
    sec
    sbc tmp3                ; llevar el auto al marco del circuito recto
    cmp #ROAD_L
    bcc @off
    cmp #ROAD_R+1
    bcc :+
@off:
    lda #1
    sta offRoad
:   rts

; A = Y en pantalla -> A = cuanto esta corrido el circuito a esa altura, en
; pixeles y con signo. Es lo que convierte entre coordenadas de pantalla y
; coordenadas de pista: en pista el asfalto siempre esta en el mismo lugar.
ShiftAtY:
    lsr a
    lsr a
    lsr a                   ; fila de tiles dentro de la pantalla
    clc
    adc topRow
    cmp #60
    bcc :+
    sbc #60
:   tax
    lda rowCC,x
    sec
    sbc #TRACK_CC
    asl a
    asl a
    asl a                   ; (centro - centro recto) * 8 px por columna
    rts

; Lo mismo a la altura del auto, que va siempre fijo en PLAYER_Y
PlayerShift:
    lda #PLAYER_Y
    jmp ShiftAtY

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

;=============================================================================
; EL CIRCUITO EN FILAS
;
; Antes las dos nametables se dibujaban identicas una sola vez y no se tocaba
; la VRAM nunca mas. Eso solo servia para un circuito recto y uniforme: apenas
; el asfalto se corre de lugar, el truco se cae.
;
; Ahora las dos nametables son un buffer circular de 60 filas (2 x 30). El
; scroll recorre las 480 lineas de las dos, y cada vez que la pantalla avanza
; 8 px entra una fila nueva por arriba. Esa fila se arma en el bucle principal
; y la escribe el NMI, que es el unico momento en que se puede tocar la VRAM.
;
; Se genera siempre la fila que quedo JUSTO ARRIBA del borde de la pantalla:
; esta entera fuera de vista, asi que no se ve aparecer. Como 60 es multiplo
; de 4 y de 2, los patrones del pasto (col+fila mod 4), del piano y de la raya
; (fila mod 2) siguen encajando cuando el buffer da la vuelta.
;=============================================================================

; scroll disminuye => el fondo baja en pantalla => sensacion de avance
UpdateScroll:
    lda scrollFrac
    sec
    sbc spdLo
    sta scrollFrac
    lda scrollLo
    sbc spdHi
    bcs @done               ; sin borrow: sigue dentro de la nametable
    clc
    adc #240                ; se paso de 0 -> saltar a la otra nametable
    sta scrollLo
    lda scrollNT
    eor #2
    sta scrollNT
    rts
@done:
    sta scrollLo
    rts

; Si la pantalla cruzo un borde de 8 px, arma la fila que acaba de quedar
; arriba y la deja lista para el NMI.
UpdateTrack:
    lda scrollLo
    lsr a
    lsr a
    lsr a                   ; fila dentro de la nametable (0..29)
    ldx scrollNT
    beq :+
    clc
    adc #30                 ; la de abajo arranca en la fila virtual 30
:   sta topRow
    cmp lastTop
    beq @rts                ; no cambio de fila: nada que hacer
    sta lastTop

    sec
    sbc #1                  ; la de arriba de la pantalla, fuera de vista
    bpl :+
    clc
    adc #60                 ; -1 -> 59
:   sta genRow

    ; Como se genera hacia arriba, la primera fila que se toca de cada bloque
    ; es la de abajo: la 3, 7, ... 27 y la 29. Ahi se mueve el circuito y se
    ; reescriben los atributos; las otras tres filas del bloque heredan el
    ; mismo centro.
    cmp #30
    bcc :+
    sec
    sbc #30
:   cmp #29
    beq @newBlock
    and #3
    cmp #3
    bne @sameBlock
@newBlock:
    jsr AdvanceTrack
    jsr BuildAttr
    jsr SetAttrAddr
    lda #1
    sta attrReady
@sameBlock:
    jsr BuildRow
    jsr SetRowAddr
    lda #1
    sta rowReady
@rts:
    rts

; Arma en rowBuf la fila virtual genRow con el asfalto centrado en genCC, y
; anota el centro en rowCC para que despues se sepa donde estaba la pista.
;
; La cuenta es e = columna - centro + 12, o sea la distancia al borde
; izquierdo del circuito. Con eso el ancho queda fijo y el circuito se corre
; entero moviendo un solo numero:
;
;     e = 0,1    piano izquierdo      e = 11    raya del medio
;     e = 2..21  asfalto              e = 22,23 piano derecho
;     fuera      pasto
;
; Con genCC = 16 sale exactamente el circuito de siempre: pianos en las
; columnas 4,5 y 26,27, asfalto de la 6 a la 25 y la raya en la 15.
BuildRow:
    ldx genRow
    lda genCC
    sta rowCC,x

    ldx #0                  ; columna
@col:
    txa
    sec
    sbc genCC
    clc
    adc #12
    cmp #24                 ; si se paso (por arriba o por abajo) es pasto
    bcs @grass
    cmp #2
    bcc @curb
    cmp #22
    bcs @curb
    cmp #11
    bne @road
    lda genRow              ; la raya del medio va cortada
    and #1
    bne @road
    lda #T_DASH
    bne @put                ; siempre: T_DASH != 0
@road:
    lda #T_ROAD
    bne @put
@curb:
    lda genRow
    and #1
    beq @curbA
    lda #T_CURB_B
    bne @put
@curbA:
    lda #T_CURB_A
    bne @put
@grass:
    txa
    clc
    adc genRow
    and #3
    bne @grassA
    lda #T_GRASS_B
    bne @put
@grassA:
    lda #T_GRASS_A
@put:
    sta rowBuf,x
    inx
    cpx #32
    bne @col
    rts

; genRow -> rowAddrHi/rowAddrLo. Las filas 0..29 caen en $2000 y las 30..59
; en $2800. Como fila*32 = fila*256/8, el byte alto suma fila/8 y el bajo es
; (fila mod 8)*32: sale sin multiplicar.
SetRowAddr:
    lda genRow
    cmp #30
    bcc @nt0
    sec
    sbc #30
    ldx #$28
    bne @calc               ; siempre: $28 != 0
@nt0:
    ldx #$20
@calc:
    stx rowAddrHi
    sta tmp1
    lsr a
    lsr a
    lsr a
    clc
    adc rowAddrHi
    sta rowAddrHi
    lda tmp1
    and #7
    asl a
    asl a
    asl a
    asl a
    asl a
    sta rowAddrLo
    rts

;-------------------------------------------------------------- las curvas
; POR QUE EL CENTRO SE MUEVE DE A 2 TILES Y SOLO CADA 4 FILAS
;
; Los atributos del fondo son por bloques de 16x16 px, y un byte de atributos
; cubre 4 columnas por 4 filas de tiles. El borde entre el pasto y el piano es
; un cambio de paleta, asi que solo puede caer en un limite de 16 px: por eso
; el piano mide 2 tiles y por eso el centro se corre de a 2 columnas.
;
; Y como el byte cubre 4 filas, el centro tampoco puede cambiar en el medio de
; esas 4: todas comparten atributo. De ahi que el circuito se mueva un escalon
; por bloque. La curva queda escalonada, que es como se ven las curvas en la
; NES de verdad.
;
; Ojo con la ultima fila de atributos de cada nametable: 30 filas de tiles no
; son 8 bloques de 4, son 7 bloques de 4 mas uno de 2 (las filas 28 y 29).

; Circuito: pares (bloques, cuanto se corre el centro por bloque). Arranca y
; termina en TRACK_CC para que el lazo cierre sin salto.
segLen:   .byte 12,  2,  8,  4,  8,  2, 10,  2,  6,  2
segDelta: .byte  0,  2,  0, $FE, 0, $FE, 0,  2,  0,  2
NUM_SEG = 10

; Corre el centro del circuito un escalon. Se llama una vez por bloque.
AdvanceTrack:
    lda trkLeft
    bne @move
    inc trkSeg              ; se acabo el segmento: pasar al siguiente
    lda trkSeg
    cmp #NUM_SEG
    bcc :+
    lda #0
    sta trkSeg
:   tax
    lda segLen,x
    sta trkLeft
@move:
    dec trkLeft
    ldx trkSeg
    lda genCC
    clc
    adc segDelta,x          ; segDelta es con signo ($FE = -2)
    cmp #CC_MIN
    bcs :+
    lda #CC_MIN
:   cmp #CC_MAX+1
    bcc :+
    lda #CC_MAX
:   sta genCC
    rts

; A = columna (par) -> A = paleta de ese grupo de 2 tiles
ColPal:
    sec
    sbc genCC
    clc
    adc #12                 ; e, igual que en BuildRow
    beq @curb               ; e = 0    -> piano izquierdo
    cmp #22
    beq @curb               ; e = 22   -> piano derecho
    cmp #21
    bcs @grass              ; e > 20 (o negativo, que envuelve alto)
    cmp #2
    bcc @grass
    lda #1                  ; asfalto
    rts
@curb:
    lda #2
    rts
@grass:
    lda #0
    rts

; Arma en attrBuf los 8 bytes de atributos del bloque, para el centro genCC.
; Las cuatro filas del bloque comparten centro, asi que la mitad de arriba y
; la de abajo del byte salen iguales.
BuildAttr:
    ldx #0
@lp:
    txa
    asl a
    asl a                   ; primera columna del byte
    jsr ColPal
    sta tmp1
    txa
    asl a
    asl a
    clc
    adc #2                  ; segundo par de columnas
    jsr ColPal
    asl a
    asl a
    ora tmp1                ; nibble bajo = izquierda | derecha<<2
    sta tmp2
    asl a
    asl a
    asl a
    asl a
    ora tmp2                ; el nibble alto repite al bajo
    sta attrBuf,x
    inx
    cpx #8
    bne @lp
    rts

; genRow -> direccion de su fila de atributos ($23C0 / $2BC0 + bloque*8)
SetAttrAddr:
    lda genRow
    ldx #$23
    cmp #30
    bcc :+
    sec
    sbc #30
    ldx #$2B
:   stx attrAddrHi
    lsr a
    lsr a                   ; bloque 0..7
    asl a
    asl a
    asl a                   ; *8 bytes por fila de atributos
    clc
    adc #$C0
    sta attrAddrLo
    rts

; Escribe attrBuf en la PPU ya mismo. Solo con el rendering apagado.
WriteAttrNow:
    bit PPUSTATUS
    lda attrAddrHi
    sta PPUADDR
    lda attrAddrLo
    sta PPUADDR
    ldx #0
:   lda attrBuf,x
    sta PPUDATA
    inx
    cpx #8
    bne :-
    rts

; Escribe rowBuf en la PPU ya mismo. Solo con el rendering apagado.
WriteRowNow:
    bit PPUSTATUS
    lda rowAddrHi
    sta PPUADDR
    lda rowAddrLo
    sta PPUADDR
    ldx #0
:   lda rowBuf,x
    sta PPUDATA
    inx
    cpx #32
    bne :-
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
    ; Los rivales viven en coordenadas de pista, asi que el que se convierte
    ; es el jugador. Comparar su X de pantalla contra la del rival daria
    ; choques fantasma apenas el circuito se corre.
    jsr PlayerShift
    sta tmp4
    lda playerX
    sec
    sbc tmp4
    sta tmp3                ; jugador en coordenadas de pista
    ldx #0
@lp:
    ; |playerX - rivalX| < 13 ?
    lda tmp3
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
    ; Empujar al costado. De que lado quedo se decide en coordenadas de pista
    ; (tmp3), pero el empujon se aplica sobre la X de pantalla.
    lda tmp3
    cmp rivalX,x
    bcs @pushR
    lda playerX
    sec
    sbc #8
    sta playerX
    jmp @snd
@pushR:
    lda playerX
    clc
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
    sta scrollNT
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
    ; sacar todo del rival ANTES de llamar a ShiftAtY, que pisa A y X
    lda rivalX,x
    sta tmp1                ; X en coordenadas de pista
    lda rivalYHi,x
    sta tmp2
    lda rivalPal,x
    clc
    adc #1                  ; paletas 1 o 2
    sta tmp3
    lda tmp2
    jsr ShiftAtY            ; los rivales tambien siguen la curva
    clc
    adc tmp1
    sta tmp1                ; -> coordenadas de pantalla
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
