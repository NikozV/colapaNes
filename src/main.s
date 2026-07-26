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
ST_CLASS  = 3

PLAYER_Y  = 168
ROAD_L    = 48          ; borde izquierdo del asfalto (px)
ROAD_R    = 192         ; x maximo del auto para seguir en pista
MAXSPD_HI = 4           ; velocidad maxima (px/frame)
LAP_LEN   = 3000        ; unidades de distancia por vuelta
TOTAL_LAPS = 3
TRACK_CC  = 16          ; columna del centro del asfalto en la recta
CC_MIN    = 12          ; el circuito no puede correrse mas alla de estos
CC_MAX    = 20          ; limites sin salirse de las 32 columnas

NUM_AI      = 21
NUM_DRIVERS = 22
PLAYER_SLOT = 19        ; indice 0-based de COL en la tabla de 22 pilotos
AIPACE_HI   = 3         ; parte entera del pace de los IA (paceLo da la fraccion)
RANK_X      = 0         ; ventana de posiciones: margen izquierdo, fuera del asfalto
RANK_Y      = 40        ; debajo del HUD (filas 1 y 2 en Y=8/16)
RANK_LINES  = 3         ; el de adelante, vos, el de atras
RANK_SEP    = 16        ; separacion entre lineas (el doble de un tile: se lee mejor)
MAX_CARS    = 6         ; tope de autos dibujados a la vez (presupuesto de OAM)
PLAYER_START = 256      ; distancia inicial del jugador (deja lugar para que
                        ; los de atras arranquen con distancia menor)
GRID_STEP   = 24        ; separacion de la parrilla provisoria, en unidades

T_GRASS_A = $01
T_GRASS_B = $02
T_ROAD    = $03
T_DASH    = $04
T_CURB_A  = $05
T_CURB_B  = $06
T_EDGE    = $07
T_GRAVEL  = $08

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
tmp5:       .res 1
tmp6:       .res 1
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

; --- los 22 pilotos (ver "LOS 22 PILOTOS" mas abajo) ---
plyTotalLo: .res 1          ; distancia total del jugador, nunca se resetea
plyTotalHi: .res 1
playerPos:  .res 1          ; puesto 1-22 del jugador, recalculado cada cuadro

; scratch de BuildRankWindow (ver "SPRITES" mas abajo). Con nombre propio y
; no tmp1-4 porque la rutina llama a PutChar/ToDigits en el medio, que SI
; pisan tmp1-4: esto tiene que sobrevivir a esas llamadas.
rankStart:  .res 1          ; puesto (0-based) de la primera linea
rankLine:   .res 1          ; linea actual (0..4) mientras se arma la ventana
rankDrv:    .res 1          ; indice de piloto de la linea actual
rankX:      .res 1          ; X de pantalla del proximo caracter de esta linea
rankScrY:   .res 1          ; Y de pantalla de esta linea

; pantalla de clasificacion (SELECT)
savedScrollLo: .res 1       ; scroll de la carrera, guardado mientras se ve
savedScrollNT: .res 1

; Exportadas para que tools/probe.py pueda leerlas por nombre desde el emulador
.exportzp gameState, playerX, spdLo, spdHi, distLo, distHi
.exportzp lapNum, crashT, offRoad, scrollLo, secs, mins, finished
.exportzp prgBank, bankVal, topRow, genCC
.exportzp plyTotalLo, plyTotalHi, playerPos, oamIdx, scrollNT

.segment "OAM"
oam:        .res 256

.segment "BSS"
; Autos visibles en pantalla. NO son trafico decorativo: son los rivales
; reales cuya distancia total esta lo bastante cerca de la del jugador como
; para entrar en pantalla. Se rearman de cero cada cuadro (BuildCars).
carDrv:     .res MAX_CARS   ; indice de piloto (0..21)
carX:       .res MAX_CARS   ; X en coordenadas de pista
carY:       .res MAX_CARS   ; Y en pantalla
carPal:     .res MAX_CARS
carCount:   .res 1

.export carCount, carDrv, carY

rowBuf:     .res 32         ; la fila que el NMI va a mandar a la PPU
attrBuf:    .res 8          ; la fila de atributos del bloque
rowCC:      .res 60         ; centro del asfalto de cada fila virtual

; rowCC no es zeropage, asi que va con .export y no con .exportzp. Lo lee
; tools/probe.py para verificar que el circuito curva de verdad.
.export rowCC

; distancia total de cada uno de los 22 (incluye al jugador, sincronizado en
; PLAYER_SLOT por SyncPlayerSlot) y el orden real por distancia
totalLo:    .res NUM_DRIVERS
totalHi:    .res NUM_DRIVERS
paceFrac:   .res NUM_DRIVERS   ; acumulador fraccionario del pace de la IA
orderTable: .res NUM_DRIVERS   ; orderTable[i] = piloto en el puesto i (0-based)
rankOf:     .res NUM_DRIVERS   ; inverso: rankOf[piloto] = puesto (0-based)

.export totalLo, totalHi, orderTable, rankOf

; Tabla de los 22 pilotos, copiada una sola vez desde BANK3 al arrancar la
; carrera (ver CopyPilotTable). Todo en Struct-of-Arrays: el 6502 no
; multiplica, asi que indexar por piloto tiene que ser directo (tabla,x),
; sin calcular N*ancho_de_registro.
;
; Va en BSS (RAM normal) y no en XRAM (PRG-RAM, $6000-$7FFF) a proposito:
; nes-py, el emulador que usan los tests, solo expone las 2KB de RAM interna
; de la consola (ver tools/nes_harness.py y RAM_SIZE=$800 del lado de
; nes-py) -- la PRG-RAM del cartucho le es invisible al harness, asi que
; nada que viva ahi se puede verificar con 'make test'. BANK3 se sigue
; usando de verdad (la copia sale de un banco conmutable), solo que el
; destino es RAM normal en vez de PRG-RAM.
pilotCode0: .res NUM_DRIVERS   ; letras del codigo (COL vive en PLAYER_SLOT)
pilotCode1: .res NUM_DRIVERS
pilotCode2: .res NUM_DRIVERS
pilotTeam:  .res NUM_DRIVERS   ; team_id 0..10
teamPaceLo: .res NUM_DRIVERS   ; parte fraccionaria del pace (0 en PLAYER_SLOT)

teamName0:  .res 11            ; abreviatura de equipo, 3 letras
teamName1:  .res 11
teamName2:  .res 11

.export pilotCode0, pilotCode1, pilotCode2, pilotTeam, teamPaceLo

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

; Copia la tabla de 22 pilotos y 11 equipos de BANK3 a XRAM. Se llama UNA vez,
; al arrancar la carrera (ver StartRace). Despues de esto el juego no vuelve a
; tocar el mapper hasta la proxima carrera: BANK3 nunca tiene codigo, solo
; datos, asi que no hay riesgo de ejecutar con el banco equivocado mapeado.
CopyPilotTable:
    lda #3
    jsr SwitchBank
    ldx #0
@drivers:
    lda pilotCode0Tab,x
    sta pilotCode0,x
    lda pilotCode1Tab,x
    sta pilotCode1,x
    lda pilotCode2Tab,x
    sta pilotCode2,x
    lda pilotTeamTab,x
    sta pilotTeam,x
    lda teamPaceLoTab,x
    sta teamPaceLo,x
    inx
    cpx #NUM_DRIVERS
    bne @drivers
    ldx #0
@teams:
    lda teamName0Tab,x
    sta teamName0,x
    lda teamName1Tab,x
    sta teamName1,x
    lda teamName2Tab,x
    sta teamName2,x
    inx
    cpx #11
    bne @teams
    lda #0
    jsr SwitchBank
    rts

;=============================================================================
; Tabla de prueba, en el banco conmutable. Desde $C000 este dato no se ve si
; BANK0 no esta mapeado: es justamente lo que verifica el test.
;=============================================================================
.segment "BANK0"

bank0Tab:
    .byte "COL", 43         ; codigo del piloto y su numero

;=============================================================================
; Tabla de 22 pilotos y 11 equipos (temporada 2026, docs/reglas-juego.md
; seccion 2). Vive en un banco conmutable porque son puros datos de solo
; lectura: CopyPilotTable la copia entera a XRAM una sola vez, al arrancar la
; carrera, y despues de eso el juego no vuelve a tocar el mapper.
;
; Struct-of-Arrays: cada campo es su propio array indexado 0..21 por piloto,
; en el mismo orden que la tabla de las reglas. El 6502 no multiplica, asi
; que indexar por piloto tiene que ser directo (tabla,x), sin calcular
; N*ancho_de_registro como haria un array de estructuras.
;
; PLAYER_SLOT (19) es Colapinto/Alpine. No tiene pace propio (lo maneja el
; humano): el valor de tabla en ese indice es 0 y no se usa (UpdateAI y
; ApplyLapVariation lo saltean a proposito).
;
; El orden de la tabla es el literal de las reglas, no un orden de largada:
; sin qualy todavia (fase 3) todos arrancan en distancia 0 y el orden real
; sale de que los pilotos con mejor ritmo se despegan durante la carrera.
;=============================================================================
.segment "BANK3"

;                          1    2    3    4    5    6    7    8    9   10
;                        NOR  PIA  LEC  HAM  VER  HAD  RUS  ANT  ALB  SAI
;                         11   12   13   14   15   16   17   18   19   20
;                        ALO  STR  LAW  LIN  HUL  BOR  OCO  BEA  GAS  COL
;                         21   22
;                        PER  BOT
pilotCode0Tab: .byte "NPLHVHRAASASLLHBOBGCPB"
pilotCode1Tab: .byte "OIEAEAUNLALTAIUOCEAOEO"
pilotCode2Tab: .byte "RACMRDSTBIORWNLROASLRT"

; 0 McLaren  1 Ferrari  2 RedBull  3 Mercedes  4 Williams  5 AstonMartin
; 6 RacingBulls  7 Audi  8 Haas  9 Alpine  10 Cadillac
pilotTeamTab:
    .byte 0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10

; paceLo = 38 + (ritmo_equipo + habilidad - 159) * 13/4. Constante de
; ensamblado: la resuelve ca65, no el 6502.
;
; CALIBRADO CONTRA MEDICIONES REALES, no contra una suposicion. Corriendo la
; ROM en el emulador, el jugador rinde:
;
;     manejando bien (siguiendo el asfalto)   ~3.49 unidades/cuadro
;     solo apretando A (se lleva por delante)  ~3.19
;     perfecto (sin chocar nunca)               4.00
;
; Con AIPACE_HI=3 el rango de la IA queda 3.148 (LIN) a 3.555 (VER), o sea
; montado justo encima del rendimiento del jugador en vez de por debajo:
; manejando bien terminas ~P5, solo apretando A ~P18, y para ganar hay que
; manejar casi perfecto. La version anterior (AIPACE_HI=2, rango 2.375-2.625)
; quedaba entera por DEBAJO del jugador y por eso se ganaba siempre sin
; importar como manejaras.
;
; GAS (Alpine) da 64, en el tercio bajo -> "medio de parrilla", como pide la
; regla de diseno. El spread chico ademas mantiene el peloton junto.
teamPaceLoTab:
    .byte 38+(95+95-159)*13/4   ; NOR
    .byte 38+(95+94-159)*13/4   ; PIA
    .byte 38+(92+95-159)*13/4   ; LEC
    .byte 38+(92+93-159)*13/4   ; HAM
    .byte 38+(92+99-159)*13/4   ; VER
    .byte 38+(92+85-159)*13/4   ; HAD
    .byte 38+(90+93-159)*13/4   ; RUS
    .byte 38+(90+87-159)*13/4   ; ANT
    .byte 38+(85+88-159)*13/4   ; ALB
    .byte 38+(85+90-159)*13/4   ; SAI
    .byte 38+(84+92-159)*13/4   ; ALO
    .byte 38+(84+78-159)*13/4   ; STR
    .byte 38+(83+82-159)*13/4   ; LAW
    .byte 38+(83+76-159)*13/4   ; LIN
    .byte 38+(82+87-159)*13/4   ; HUL
    .byte 38+(82+82-159)*13/4   ; BOR
    .byte 38+(82+85-159)*13/4   ; OCO
    .byte 38+(82+84-159)*13/4   ; BEA
    .byte 38+(80+87-159)*13/4   ; GAS
    .byte 0                     ; COL - jugador, no se usa
    .byte 38+(76+86-159)*13/4   ; PER
    .byte 38+(76+85-159)*13/4   ; BOT

; MCL FER RBR MER WIL AST RCB AUD HAA ALP CAD
teamName0Tab: .byte "MFRMWARAHAC"
teamName1Tab: .byte "CEBEISCUALA"
teamName2Tab: .byte "LRRRLTBDAPD"

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
:   cmp #ST_CLASS
    bne :+
    jsr ClassLogic
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
    .byte $0F,$1A,$2A,$27   ; 0 pasto (el color 3 es la grava del costado)
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
    jsr CopyPilotTable      ; tabla de 22 pilotos: BANK3 -> XRAM, una sola vez
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

    ; --- los 22 pilotos ---
    ; Sin qualy todavia (fase 3) no hay parrilla de verdad, pero tampoco
    ; pueden arrancar todos en la misma distancia: quedarian encimados en el
    ; mismo punto de la pista. Se escalonan GRID_STEP unidades entre si en el
    ; orden de la tabla, con el jugador en PLAYER_START, asi que se larga
    ; desde el medio del peloton. El carril sale del indice de piloto
    ; (laneX en BuildCars), asi que dos autos consecutivos no se pisan.
    lda #0
    sta carCount
    lda #<PLAYER_START
    sta plyTotalLo
    lda #>PLAYER_START
    sta plyTotalHi

    lda #<(PLAYER_START + PLAYER_SLOT * GRID_STEP)
    sta tmp1
    lda #>(PLAYER_START + PLAYER_SLOT * GRID_STEP)
    sta tmp2
    ldx #0
@pl:
    lda tmp1
    sta totalLo,x
    lda tmp2
    sta totalHi,x
    lda #0
    sta paceFrac,x
    txa
    sta orderTable,x        ; orden identidad: orderTable[i] = i
    sta rankOf,x
    lda tmp1                ; el siguiente arranca GRID_STEP mas atras
    sec
    sbc #GRID_STEP
    sta tmp1
    lda tmp2
    sbc #0
    sta tmp2
    inx
    cpx #NUM_DRIVERS
    bne @pl
    lda #PLAYER_SLOT+1      ; puesto nominal hasta el primer UpdatePositions
    sta playerPos

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

; Como DrawTrack, pero para reconstruir el circuito curvo REAL en vez de
; dibujar el trazado recto inicial: en vez de generar el centro con
; AdvanceTrack/segLen/segDelta, lo lee directo de rowCC (que sigue teniendo
; el estado correcto en RAM, sin tocar). La usa ExitClass al salir de la
; clasificacion, porque esa pantalla reescribe las mismas dos nametables
; que usa el circuito.
RedrawTrack:
    lda #0
    sta genRow
@lp:
    ldx genRow
    lda rowCC,x
    sta genCC

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
    lda padNew
    and #BTN_SEL
    beq @norm
    jsr EnterClass           ; SELECT: pausa y muestra la clasificacion
    rts
@norm:
    jsr UpdateTimer
    jsr UpdatePlayer
    jsr UpdateScroll
    jsr UpdateTrack
    jsr UpdateDistance
    jsr SyncPlayerSlot
    jsr UpdateAI
    jsr UpdatePositions
    ; BuildCars va DESPUES de UpdatePositions (necesita el orden y las
    ; distancias de este cuadro) y ANTES de CheckCollisions y BuildOAM, que
    ; son las dos que consumen la lista de autos en pantalla.
    jsr BuildCars
    jsr CheckCollisions
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
    cmp #24                 ; e >= 24: se paso del circuito (o quedo negativo,
    bcs @outside            ; que envuelve por arriba). Grava o pasto.
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
; Afuera del circuito. Los dos tiles pegados al piano son grava y el resto
; pasto. La grava comparte la paleta del pasto (usa su color 3, que el pasto
; no toca), asi que no agrega ningun limite de paleta nuevo: los atributos
; siguen siendo los mismos que sin grava.
@outside:
    cmp #26
    bcc @gravel             ; e = 24,25 -> grava del lado derecho
    cmp #254
    bcs @gravel             ; e = 254,255 (o sea -2,-1) -> grava del izquierdo
    jmp @grass
@gravel:
    lda #T_GRAVEL
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

;=============================================================================
; LOS AUTOS EN PANTALLA
;
; No hay trafico decorativo: los autos que se ven SON los rivales reales de
; la clasificacion. Cada cuadro se recorren los puestos vecinos al del
; jugador y, para cada uno, se calcula donde cae en pantalla a partir de la
; diferencia de distancia total contra el jugador:
;
;     y_pantalla = PLAYER_Y - (distancia_rival - distancia_jugador)
;
; Como el jugador avanza ~3.5 unidades de distancia por cuadro y el scroll
; se mueve ~3.5 px por cuadro, una unidad de distancia es aproximadamente un
; pixel: el que te saca 20 unidades aparece 20 px mas arriba. Los que quedan
; fuera de [0,239] simplemente no se dibujan, que es lo que dice la regla de
; "solo los que estan cerca tuyo se dibujan".
;
; Consecuencia: adelantar un auto en pantalla es adelantarlo de verdad en la
; clasificacion. Antes eran sistemas separados y se veian autos que no eran
; de la carrera.
;=============================================================================
laneX:
    .byte 56, 92, 132, 168

BuildCars:
    lda #0
    sta carCount

    ; arrancar unos puestos por delante del jugador y barrer hacia atras
    lda rankOf+PLAYER_SLOT
    sec
    sbc #MAX_CARS/2+1
    bcs :+
    lda #0                   ; el jugador va puntero: barrer desde el primero
:   sta tmp5                  ; tmp5 = puesto que se esta mirando
@lp:
    lda carCount
    cmp #MAX_CARS
    beq @done
    lda tmp5
    cmp #NUM_DRIVERS
    bcs @done

    ldy tmp5
    lda orderTable,y
    sta tmp6                  ; tmp6 = piloto de ese puesto
    cmp #PLAYER_SLOT
    beq @next                 ; al jugador lo dibuja BuildOAM aparte

    ; y = PLAYER_Y - (total[rival] - total[jugador]), en 16 bits
    ldy tmp6
    lda totalLo,y
    sec
    sbc plyTotalLo
    sta tmp1
    lda totalHi,y
    sbc plyTotalHi
    sta tmp2

    lda #PLAYER_Y
    sec
    sbc tmp1
    sta tmp3                  ; y lo
    lda #0
    sbc tmp2
    bne @next                 ; y no entra en un byte -> fuera de pantalla
    lda tmp3
    cmp #240
    bcs @next                 ; abajo del borde inferior

    ldx carCount
    sta carY,x
    lda tmp6
    sta carDrv,x
    and #3
    tay
    lda laneX,y               ; el carril sale del indice de piloto: los que
    sta carX,x                ; corren juntos quedan en carriles distintos
    ldy tmp6
    lda pilotTeam,y
    and #1
    clc
    adc #1                    ; paletas de sprite 1 o 2 (la 0 es del jugador)
    sta carPal,x
    inc carCount
@next:
    inc tmp5
    jmp @lp
@done:
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
    lda carCount
    beq @rts
    ldx #0
@lp:
    ; |playerX - carX| < 13 ?
    lda tmp3
    sec
    sbc carX,x
    bcs :+
    eor #$FF
    clc
    adc #1
:   cmp #13
    bcs @next
    ; |PLAYER_Y - carY| < 13 ?
    lda #PLAYER_Y
    sec
    sbc carY,x
    bcs :+
    eor #$FF
    clc
    adc #1
:   cmp #13
    bcs @next
    jmp @crash
@next:
    inx
    cpx carCount
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
    cmp carX,x
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
    ; distancia total del jugador: mismo incremento que distLo/Hi arriba,
    ; pero esta nunca se resetea. La usa SyncPlayerSlot para compararlo
    ; contra los 21 IA sin tener que multiplicar lapNum*LAP_LEN cada vez.
    lda plyTotalLo
    clc
    adc spdHi
    sta plyTotalLo
    lda plyTotalHi
    adc #0
    sta plyTotalHi
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
    jsr ApplyLapVariation
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
; LOS 22 PILOTOS
;
; Los 4 autos de trafico que se ven en pantalla (SpawnRival/UpdateRivals) son
; decorativos y no cambian en esta fase. En paralelo, sin relacion con lo que
; se dibuja, se simulan los 22 pilotos reales (el jugador + 21 IA) solo para
; llevar la cuenta de posiciones: cuanta distancia total lleva cada uno y en
; que orden van.
;=============================================================================

; El jugador tiene su propio acumulador (plyTotalLo/Hi, se llena en
; UpdateDistance); esto lo copia al lugar que le corresponde en la tabla de
; 22, para que UpdatePositions compare a todos con el mismo criterio.
SyncPlayerSlot:
    lda plyTotalLo
    sta totalLo+PLAYER_SLOT
    lda plyTotalHi
    sta totalHi+PLAYER_SLOT
    rts

; Avanza la distancia total de los 21 IA. AIPACE_HI es igual para todos; la
; parte fraccionaria (teamPaceLo) es lo que distingue el ritmo de cada uno,
; igual que rivalSLo/SHi ya distingue la velocidad de los rivales decorativos.
;
; totalLo/Hi tiene que quedar en las MISMAS unidades que plyTotalLo/Hi (un
; contador entero plano, sin fraccion: UpdateDistance solo suma spdHi, nunca
; spdLo). Por eso el pace de punto fijo (teamPaceLo/AIPACE_HI) no se suma
; directo a totalLo/Hi -- eso los dejaria en escalas distintas, con el total
; de la IA miles de unidades mas alto que el del jugador tras unos pocos
; cuadros. paceFrac es el acumulador fraccionario aparte: solo su ACARREO
; (0 o 1 vez cada varios cuadros) entra a totalLo/Hi, igual que scrollFrac
; hace con scrollLo.
UpdateAI:
    ldx #0
@lp:
    cpx #PLAYER_SLOT
    beq @next                ; el jugador se sincroniza aparte, no aca
    lda paceFrac,x
    clc
    adc teamPaceLo,x
    sta paceFrac,x           ; el acarreo de esta suma es lo que se usa abajo
    lda totalLo,x
    adc #AIPACE_HI            ; suma AIPACE_HI + el acarreo de paceFrac
    sta totalLo,x
    lda totalHi,x
    adc #0
    sta totalHi,x
@next:
    inx
    cpx #NUM_DRIVERS
    bne @lp
    rts

; Se dispara cuando el JUGADOR completa una vuelta (no el de cada IA por
; separado: simplificacion valida para "orden coherente", que es lo que pide
; esta fase, no precision de simulacion). Variacion chica y clampeada a
; 64..192 para que no haga un random walk sin limite en carreras largas.
ApplyLapVariation:
    ldx #0
@lp:
    cpx #PLAYER_SLOT
    beq @next
    jsr Rand
    and #7                    ; 0..7
    sec
    sbc #3                    ; -3..+4, tratado como delta con signo
    clc
    adc teamPaceLo,x
    cmp #30                   ; clamp al rango real de la tabla (38..142)
    bcs :+
    lda #30
:   cmp #161
    bcc :+
    lda #160
:   sta teamPaceLo,x
@next:
    inx
    cpx #NUM_DRIVERS
    bne @lp
    rts

; Orden real de los 22 por distancia descendente. Los deltas de pace son
; chicos, asi que orderTable esta siempre CASI ordenada: un pase de burbuja
; (21 comparaciones adyacentes) la deja bien casi siempre, pero cuando dos o
; mas pilotos estan muy cerca uno del otro un pase solo puede tardar varios
; cuadros en asentarse del todo. El presupuesto de ciclos sobra de sobra (esto
; es una fraccion de lo que hay libre en el bucle principal), asi que en vez
; de aflojar la precision se hacen UPD_PASSES pases seguidos: barato, y deja
; la ventana de posiciones fiel de verdad, no solo "eventualmente correcta".
UPD_PASSES = 3

UpdatePositions:
    ldy #UPD_PASSES
@pass:
    sty tmp4                 ; tmp4 = pases que quedan
    ldx #0
@lp:
    ldy orderTable,x
    lda totalHi,y
    sta tmp1
    lda totalLo,y
    sta tmp2
    ldy orderTable+1,x
    lda tmp1
    cmp totalHi,y
    bne @cmpdone
    lda tmp2
    cmp totalLo,y
@cmpdone:
    bcs @noswap               ; total(orderTable[x]) >= total(orderTable[x+1])
    lda orderTable,x          ; van al reves de como tienen que quedar: swap
    tay
    lda orderTable+1,x
    sta orderTable,x
    tya
    sta orderTable+1,x
@noswap:
    inx
    cpx #NUM_DRIVERS-1
    bne @lp
    ldy tmp4
    dey
    bne @pass

    ; reconstruir rankOf desde orderTable. Mas simple y menos propenso a
    ; bugs que mantenerlo incremental durante los swaps de arriba.
    ldx #0
@rk:
    ldy orderTable,x
    txa
    sta rankOf,y
    inx
    cpx #NUM_DRIVERS
    bne @rk

    lda rankOf+PLAYER_SLOT
    clc
    adc #1
    sta playerPos
    rts

; Insertion sort completo de los 22, por si el pase incremental de
; UpdatePositions quedo momentaneamente desalineado (streaks cortos, ver
; probe.py). Se llama una sola vez, al entrar a la clasificacion: ahi hace
; falta la foto exacta, no la aproximacion barata de cada cuadro.
SortAllDrivers:
    ldx #1
@outer:
    lda orderTable,x
    sta tmp5                  ; piloto a insertar
    ldy tmp5
    lda totalHi,y
    sta tmp1
    lda totalLo,y
    sta tmp2
    stx tmp6                  ; tmp6 = j, la posicion donde se esta insertando
@inner:
    lda tmp6
    beq @insert
    tay
    dey
    lda orderTable,y          ; orderTable[j-1]
    tay
    lda totalHi,y
    cmp tmp1
    bne @cmpd
    lda totalLo,y
    cmp tmp2
@cmpd:
    bcs @insert                ; total(orderTable[j-1]) >= a insertar: ya esta bien
    lda tmp6
    tay
    dey
    lda orderTable,y
    ldy tmp6
    sta orderTable,y           ; orderTable[j] = orderTable[j-1]
    dec tmp6
    jmp @inner
@insert:
    ldy tmp6
    lda tmp5
    sta orderTable,y

    inx
    cpx #NUM_DRIVERS
    beq @done
    jmp @outer
@done:
    ldx #0
@rk:
    ldy orderTable,x
    txa
    sta rankOf,y
    inx
    cpx #NUM_DRIVERS
    bne @rk
    lda rankOf+PLAYER_SLOT
    clc
    adc #1
    sta playerPos
    rts

;=============================================================================
; PANTALLA DE CLASIFICACION (SELECT)
;
; Toggle con SELECT, igual que START ya alterna entre pantallas en este
; juego. Mientras esta activa la carrera queda congelada: no se llama a
; UpdateTrack/UpdatePlayer/UpdateRivals/UpdateTimer desde ClassLogic, asi
; que se retoma exactamente donde estaba al salir.
;
; El circuito curvo (Fase 1) vive en las mismas dos nametables que esta
; pantalla usa para el texto, y el scroll casi nunca esta en 0 a mitad de
; carrera -- por eso se guarda scrollLo/scrollNT y se fuerzan a 0 antes de
; dibujar (como arranca DrawTrack), y RedrawTrack reconstruye el circuito
; real (leyendo rowCC, no reiniciando el trazado) antes de restaurarlos.
;=============================================================================
classtxt: .byte "CLASIFICACION", 0

EnterClass:
    lda scrollLo
    sta savedScrollLo
    lda scrollNT
    sta savedScrollNT
    lda #0
    sta scrollLo
    sta scrollNT

    jsr RenderOff
    jsr SortAllDrivers

    lda #<$2000
    sta ptr
    lda #>$2000
    sta ptr+1
    lda #$20                 ; espacio
    jsr FillNT

    bit PPUSTATUS
    lda #$23
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #64
    lda #$FF                 ; paleta 3 (texto azul) para toda la pantalla
:   sta PPUDATA
    dex
    bne :-

    lda #<classtxt
    sta ptr
    lda #>classtxt
    sta ptr+1
    lda #$29
    sta tmp3
    lda #$20
    sta tmp4
    jsr DrawText

    lda #0
    sta rankLine              ; reusa rankLine como indice de fila (0..21)
@row:
    ldx rankLine
    lda orderTable,x
    sta rankDrv

    lda rankLine
    clc
    adc #4                    ; deja 4 filas de margen arriba
    jsr SetClassAddr

    bit PPUSTATUS
    lda tmp4
    sta PPUADDR
    lda tmp3
    sta PPUADDR

    lda #' '
    sta PPUDATA
    sta PPUDATA
    lda #'P'
    sta PPUDATA
    lda rankLine
    clc
    adc #1
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
    lda #' '
    sta PPUDATA
    ldx rankDrv
    lda pilotCode0,x
    sta PPUDATA
    lda pilotCode1,x
    sta PPUDATA
    lda pilotCode2,x
    sta PPUDATA
    lda #' '
    sta PPUDATA
    ldx rankDrv
    lda pilotTeam,x
    tax
    lda teamName0,x
    sta PPUDATA
    lda teamName1,x
    sta PPUDATA
    lda teamName2,x
    sta PPUDATA
    lda #' '
    sta PPUDATA

    jsr ClassGap               ; deja dig1 (entero) / dig0 (decimo)
    lda #'+'
    sta PPUDATA
    lda dig1
    clc
    adc #'0'
    sta PPUDATA
    lda #'.'
    sta PPUDATA
    lda dig0
    clc
    adc #'0'
    sta PPUDATA

    inc rankLine
    lda rankLine
    cmp #NUM_DRIVERS
    beq @rowsdone
    jmp @row
@rowsdone:

    ; ocultar sprites: sin esto quedarian los autos/HUD de la ultima
    ; carrera dibujados encima. BuildOAM no corre mientras esta congelado,
    ; asi que con hacerlo una vez alcanza.
    ldx #0
    lda #$FF
:   sta oam,x
    inx
    bne :-

    lda #ST_CLASS
    sta gameState
    jsr RenderOn
    rts

ExitClass:
    jsr RenderOff
    jsr RedrawTrack
    lda savedScrollLo
    sta scrollLo
    lda savedScrollNT
    sta scrollNT
    lda #ST_RACE
    sta gameState
    jsr RenderOn
    rts

ClassLogic:
    lda padNew
    and #BTN_SEL
    beq :+
    jsr ExitClass
:   rts

; A = fila de tiles (0..29) -> tmp3/tmp4 = direccion PPU. Siempre en la
; nametable de arriba: esta pantalla no scrollea.
SetClassAddr:
    sta tmp1
    lsr a
    lsr a
    lsr a
    clc
    adc #$20
    sta tmp4
    lda tmp1
    and #7
    asl a
    asl a
    asl a
    asl a
    asl a
    sta tmp3
    rts

; Diferencia respecto al lider, como fraccion de vuelta: delta*10/LAP_LEN,
; un decimal. Con la calibracion de pace de esta fase los gaps reales quedan
; bien por debajo de una vuelta entera, asi que la parte entera practicamente
; siempre da 0 -- salvo que alguien se quede muy atras, en cuyo caso se
; clampea a "+9.9" en vez de mostrar una fraccion sin sentido.
; rankDrv = piloto de esta fila. Deja dig1 (entero) / dig0 (decimo).
ClassGap:
    ldy orderTable             ; orderTable[0] = el lider
    lda totalLo,y
    sta tmp1
    lda totalHi,y
    sta tmp2
    ldy rankDrv
    lda tmp1
    sec
    sbc totalLo,y
    sta tmp1                   ; delta lo
    lda tmp2
    sbc totalHi,y
    sta tmp2                   ; delta hi

    lda tmp2
    cmp #>LAP_LEN
    bne @cmphi
    lda tmp1
    cmp #<LAP_LEN
@cmphi:
    bcc @small
    lda #9
    sta dig1
    sta dig0
    rts
@small:
    lda #0
    sta numLo
    sta numHi
    ldx #10
@mul10:
    lda numLo
    clc
    adc tmp1
    sta numLo
    lda numHi
    adc tmp2
    sta numHi
    dex
    bne @mul10

    ldx #0
@div:
    lda numHi
    cmp #>LAP_LEN
    bne @divcmp
    lda numLo
    cmp #<LAP_LEN
@divcmp:
    bcc @divdone
    lda numLo
    sec
    sbc #<LAP_LEN
    sta numLo
    lda numHi
    sbc #>LAP_LEN
    sta numHi
    inx
    jmp @div
@divdone:
    stx dig0
    lda #0
    sta dig1
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
;
; Orden de prioridad: en el NES, si una linea de barrido junta mas de 8
; sprites, el hardware muestra los PRIMEROS 8 del buffer OAM y descarta el
; resto -- no hay eleccion de "cual importa mas", solo el orden en que se
; escribieron. Por eso el orden aca no es arbitrario: jugador primero (nunca
; se puede perder), despues el HUD, despues la ventana de posiciones, y los
; autos de trafico decorativo al final -- son lo primero que se sacrifica si
; una linea se llena (puede pasar: la ventana vive en el margen izquierdo y
; un auto puede caer en la misma scanline. Es la misma clase de limitacion
; de hardware que las curvas escalonadas de la Fase 1, documentada y no un
; bug).
;=============================================================================
BuildOAM:
    lda #0
    sta oamIdx

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

    jsr BuildHud1
    jsr BuildHudRow2
    jsr BuildRankWindow

    ; --- rivales reales (los que estan cerca tuyo en la clasificacion).
    ; Van al final: si una linea de barrido se pasa de 8 sprites, lo primero
    ; que se pierde es un auto y no el HUD ni la ventana de posiciones.
    lda carCount
    beq @carsdone
    ldx #0
@rv:
    txa
    pha
    ; sacar todo del auto ANTES de llamar a ShiftAtY, que pisa A y X
    lda carX,x
    sta tmp1                ; X en coordenadas de pista
    lda carY,x
    sta tmp2
    lda carPal,x
    sta tmp3
    lda tmp2
    jsr ShiftAtY            ; los rivales tambien siguen la curva
    clc
    adc tmp1
    sta tmp1                ; -> coordenadas de pantalla
    jsr PutCar
    pla
    tax
    inx
    cpx carCount
    bne @rv
@carsdone:

    ; apagar el resto de los sprites
    ldx oamIdx
    lda #$FF
@clr:
    sta oam,x
    inx
    bne @clr
    rts

; --- HUD fila 1 (Y=8): V n / 3      y    velocidad
BuildHud1:
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
    rts

; --- HUD fila 2 (Y=16): posicion, "P08". Fila propia y no la de arriba
; porque esa ya usa 7 de los 8 sprites que entran por scanline.
BuildHudRow2:
    lda #'P'
    ldx #16
    ldy #16
    jsr PutChar
    lda playerPos
    sta numLo
    lda #0
    sta numHi
    jsr ToDigits
    lda dig1
    clc
    adc #'0'
    ldx #24
    ldy #16
    jsr PutChar
    lda dig0
    clc
    adc #'0'
    ldx #32
    ldy #16
    jsr PutChar
    rts

rankY: .byte RANK_Y, RANK_Y+RANK_SEP, RANK_Y+2*RANK_SEP

; Ventana movil de 3 lineas: el que tenes adelante, vos, y el que tenes
; atras. Es la informacion que de verdad sirve manejando -- contra quien
; estas peleando -- y con tres lineas separadas 16 px (el doble de un tile)
; se lee mucho mejor que las cinco apretadas de antes.
;
; Formato "P07 GAS": el separador no gasta un sprite, sale de la posicion X.
; La linea del jugador no tiene paleta de sprite libre para resaltarse con
; color (las 4 ya estan asignadas: jugador, rival rojo, rival plateado,
; texto), asi que lleva un '!' adelante.
;
; En los extremos la ventana se desliza en vez de mostrar puestos que no
; existen: de puntero muestra P1-P2-P3 (o sea vos y los dos de atras), y de
; ultimo los dos de adelante y vos.
BuildRankWindow:
    lda rankOf+PLAYER_SLOT
    bne :+
    lda #1                  ; puntero: arrancar en P1 para no salirse por arriba
:   sec
    sbc #1
    cmp #NUM_DRIVERS-RANK_LINES+1
    bcc :+
    lda #NUM_DRIVERS-RANK_LINES
:   sta rankStart

    lda #0
    sta rankLine
@line:
    ldx rankLine
    lda rankY,x
    sta rankScrY

    lda rankLine
    clc
    adc rankStart
    tax                      ; X = puesto (0-based) de esta linea
    lda orderTable,x
    sta rankDrv

    inx                      ; X = puesto (1-based), para mostrar
    stx numLo
    lda #0
    sta numHi
    jsr ToDigits             ; dig1 = decenas, dig0 = unidades

    lda #RANK_X
    sta rankX
    lda rankStart
    clc
    adc rankLine
    cmp rankOf+PLAYER_SLOT
    bne @drawP
    lda #'!'
    ldx rankX
    ldy rankScrY
    jsr PutChar
    lda rankX                ; +8: el ancho real de un tile, no +1
    clc
    adc #8
    sta rankX
@drawP:
    lda #'P'
    ldx rankX
    ldy rankScrY
    jsr PutChar
    lda rankX                ; +8: el ancho real de un tile, no +1
    clc
    adc #8
    sta rankX
    lda dig1
    clc
    adc #'0'
    ldx rankX
    ldy rankScrY
    jsr PutChar
    lda rankX                ; +8: el ancho real de un tile, no +1
    clc
    adc #8
    sta rankX
    lda dig0
    clc
    adc #'0'
    ldx rankX
    ldy rankScrY
    jsr PutChar
    lda rankX                ; +12: deja un hueco antes del codigo, para que
    clc                      ; "P07 GAS" se lea separado sin gastar un sprite
    adc #12
    sta rankX

    ldx rankDrv
    lda pilotCode0,x
    ldx rankX
    ldy rankScrY
    jsr PutChar
    lda rankX                ; +8: el ancho real de un tile, no +1
    clc
    adc #8
    sta rankX
    ldx rankDrv
    lda pilotCode1,x
    ldx rankX
    ldy rankScrY
    jsr PutChar
    lda rankX                ; +8: el ancho real de un tile, no +1
    clc
    adc #8
    sta rankX
    ldx rankDrv
    lda pilotCode2,x
    ldx rankX
    ldy rankScrY
    jsr PutChar

    inc rankLine
    lda rankLine
    cmp #RANK_LINES
    beq @done
    jmp @line                ; bne no llega: el cuerpo del loop es largo
@done:
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
