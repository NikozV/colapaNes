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
ST_QUALY  = 4
ST_GRID   = 5
ST_PITMENU = 6
ST_SEMAPHORE = 7

PLAYER_Y  = 168
; GEOMETRIA DEL CIRCUITO
; El circuito mide 16 tiles (2 de piano + 12 de asfalto + 2 de piano) y vive
; en las columnas 0..24. Las columnas 25..30 quedan libres para el panel de
; datos, que asi no tapa nunca la pista: el borde derecho del asfalto llega
; como maximo a x=175 y el panel empieza en x=200.
;
; Antes el asfalto media 160 px, o sea diez autos de ancho: se veia
; desproporcionado y no dejaba lugar para el panel ni, mas adelante, para los
; boxes. Ahora mide 96 px, seis autos.
TRACK_HW  = 8           ; media anchura del circuito, en tiles
ROAD_L    = 48          ; borde izquierdo del asfalto (px, en coords de pista)
ROAD_R    = 128         ; x maximo del auto para seguir entero en el asfalto
MAXSPD_HI = 4           ; velocidad maxima (px/frame)
LAP_LEN   = 3000        ; unidades de distancia por vuelta
; 6 y no el "10 por defecto" de las reglas: deja que las tres gomas se
; sientan distintas (blando ~4 vueltas, duro ~11) sin triplicar el tiempo
; real de cada corrida de test, que corre sobre el emulador de verdad.
TOTAL_LAPS = 6
TRACK_CC  = 12          ; columna del centro del asfalto en la recta
CC_MIN    = 8           ; el circuito no puede correrse mas alla de estos
CC_MAX    = 16          ; limites sin invadir la franja del panel
PLAYER_X0 = 87          ; x inicial del auto: el medio del asfalto
HUD_X     = 200         ; columna donde arranca el panel de datos

NUM_AI      = 21
NUM_DRIVERS = 22
PLAYER_SLOT = 19        ; indice 0-based de COL en la tabla de 22 pilotos
AIPACE_HI   = 3         ; parte entera del pace de los IA (paceLo da la fraccion)
RANK_X      = HUD_X     ; la ventana va en el panel, igual que el resto
RANK_Y      = 48        ; debajo de vuelta, puesto y velocidad
RANK_LINES  = 3         ; el de adelante, vos, el de atras
RANK_SEP    = 8         ; lineas pegadas: forman un panel negro solido
MAX_CARS    = 5         ; tope de autos dibujados a la vez (presupuesto de OAM)
PLAYER_START = 256      ; distancia inicial del jugador (deja lugar para que
                        ; los de atras arranquen con distancia menor)
GRID_STEP   = 24        ; separacion de la parrilla provisoria, en unidades
DEFEND_RANGE = 40       ; a que distancia un rival se pone a defender

; --- qualy ---
; El cronometro de la sesion cuenta CUADROS, no segundos: una vuelta ronda los
; 750-950 cuadros (12-16 s) y las diferencias que deciden la parrilla son de
; decimas. Contar cuadros ademas hace que comparar y ordenar tiempos sea una
; resta de 16 bits, sin conversion; la conversion a SS.CC se hace una sola vez
; al mostrarlos.
;
; tiempo_ia = QTIME_BASE - (ritmo_equipo + habilidad - 159) * QTIME_FACTOR
;             + azar(0..QTIME_RAND)
;
; Calibrado contra lo medido con el piloto automatico (ver teamPaceLoTab): el
; jugador da la vuelta en ~940 cuadros solo apretando A, ~860 siguiendo el
; asfalto, ~785 limpio y 750 perfecto. Con estos numeros la IA va de 780 (VER)
; a 940 (LIN): una vuelta limpia da segunda fila y la pole exige una casi
; perfecta.
QTIME_BASE   = 940
QTIME_FACTOR = 5
QTIME_RAND   = 31       ; medio segundo de azar, la mascara del Rand
QTIME_NULA   = $FFFF    ; vuelta anulada o sin completar: se larga ultimo
; Los tiempos rondan los 780-940 cuadros y no entran en un byte, asi que la
; tabla de ROM guarda (tiempo - QTIME_OFF) y GenAITimes le suma el offset de
; vuelta. Tiene que ser multiplo de 256 para que sumarlo sea tocar solo el
; byte alto.
QTIME_OFF    = 768

; --- gomas (fase 4) ---
; Vida util aproximada de cada compuesto en vueltas (docs/reglas-juego.md
; seccion 5): Blando ~4, Medio ~7, Duro ~11. La tasa de desgaste por vuelta
; sale de 100/vueltas, redondeado, mas un bonus fijo por cada evento de "al
; limite" que haya pasado en la vuelta (ver WearTick).
WEAR_SOFT = 25
WEAR_MED  = 14
WEAR_HARD = 9
WEAR_BONUS_OFFROAD = 6     ; salirse de pista (esto YA incluye el piano, ver
                            ; WearTick: en esta geometria el piano cae fuera
                            ; de ROAD_L..ROAD_R igual que el pasto)
WEAR_BONUS_CRASH   = 10
WEAR_BONUS_BRAKE   = 5
HARDBRAKE_SPD = 3          ; spdHi minimo para que frenar cuente como fuerte

; Agarre en % segun compuesto (base) y banda de desgaste (docs/reglas-juego.md
; seccion 5). La banda 4 (100, pinchado) usa el mismo % que el limite de pit
; lane: pinchado equivale a manejar el resto de la carrera a paso de boxes.
SOFT_GRIP = 100
MED_GRIP  = 94
HARD_GRIP = 88
WBAND_0   = 100             ; desgaste 0-49
WBAND_1   = 95              ; 50-74
WBAND_2   = 88              ; 75-89
WBAND_3   = 75              ; 90-99
PIT_LIMIT_PCT = 60          ; limite de velocidad en el pit lane, ver mas abajo
WBAND_4   = PIT_LIMIT_PCT   ; 100, pinchado: mismo % que el limite de boxes

; --- boxes (fase 4 etapa 2) ---
; El motor separa "distancia" (distLo/Hi, entero, marca las vueltas) de
; "scroll visual" (rowCC/genCC, con fraccion), y no hay una fila fija del
; circuito que corresponda siempre a la linea de largada (ver el plan de la
; fase). Sin eso, el pit lane no se puede clavar en un punto geometrico
; fijo: en cambio se dibuja como una VENTANA DE DISTANCIA alrededor del
; cruce de vuelta, aproximacion valida porque una fila se genera justo
; antes de entrar en pantalla (el desvio entre distancia y scroll es chico
; dentro de una sola vuelta).
PIT_ENTRY_LEN = 300      ; ventana de entrada: ultimas 300 unidades de la vuelta
PIT_EXIT_LEN  = 150      ; ventana de salida: primeras 150 de la vuelta siguiente
; Franja del pit lane: reemplaza el piano Y LA GRAVA del lado DERECHO
; (e=14..17 en BuildRow, cuatro columnas) -- nunca el izquierdo, los boxes
; son de un solo lado. Ancho a proposito: dos tiles (el piano solo) se leian
; como el piano de siempre con otro color; cuatro se leen como un carril
; propio, separado de la pista en vez de parte de ella. En el marco "recto"
; de PlayerShift (el mismo que usa ROAD_L/ROAD_R) esas columnas caen en
; [144,176): mismo calculo que BuildRow, (e+TRACK_CC-TRACK_HW)*8.
PIT_LANE_L = (14+TRACK_CC-TRACK_HW)*8
PIT_LANE_R = (18+TRACK_CC-TRACK_HW)*8
PIT_CAP = MAXSPD_HI*256*PIT_LIMIT_PCT/100   ; tope de velocidad en boxes, 8.8
PIT_PENALTY_SECS = 5     ; por pasarse del limite estando comprometido

; --- boxes (fase 4 etapa 3): menu de parada y pitStopTimer ---
; El menu se abre apenas el auto se compromete (pitCommitted, ver
; UpdatePlayer): no hay que seguir manejando hasta un punto mas -- tocar el
; carril alcanza, como pedirian los boxes de verdad.
WING_STEP = 51            ; ~0.2 px/cuadro en 8.8 por punto de ala (curCapHi/Lo)
PIT_STOP_BASE = 150       ; 2.5s a 60 cuadros/seg
PIT_STOP_SLOW_ADD = 300   ; parada lenta: 300 + azar(0..127), ~5 a 7 segundos

; --- boxes (fase 4 etapa 4): parada abstraida de la IA ---
; La IA no maneja de verdad (es una formula de distancia, desde la fase 2),
; asi que no tiene un modelo de gomas completo: en una vuelta al azar, ni
; las dos primeras ni las dos ultimas (para que no se sienta ni instantanea
; ni al final sin sentido), cada una sufre un unico evento que le resta el
; equivalente a una parada de base de su acumulador de distancia. Sin esto
; la regla de los dos compuestos seria injusta: el jugador pierde ~20s de
; verdad en una parada real y la IA no perderia nada.
PIT_STOP_LAP_COUNT = TOTAL_LAPS-4    ; vueltas validas: 3..TOTAL_LAPS-2
; PIT_STOP_BASE(150 cuadros) * ritmo tipico de la IA (~3.5 unidades/cuadro,
; ver teamPaceLoTab): no vale la pena un multiplicador por piloto para una
; abstraccion que ya de por si no simula la parada real.
AI_PITSTOP_LOSS = 525

; --- ERS (fase 5) ---
; "Estoy en una curva" no existe como evento (genCC se corre continuo, sin
; entrar/salir de curva -- misma falta que ya documento el ala en boxes).
; Se aproxima con la propia tabla rowCC: cuanto se corrio el centro del
; asfalto en el ultimo bloque de atributos (8 filas), la misma tabla que ya
; usa ShiftAtY/offRoad. Mas delta = curva mas cerrada.
ERS_MAX = 100
ERS_CHARGE_CURVE_BASE = 1     ; frenando Y girando (cualquier curvatura)
ERS_CHARGE_STRAIGHT   = 1     ; frenando SIN girar (recta)
ERS_CHARGE_SLIP       = 1     ; rebufo, se suma a lo de arriba si corresponde
; ventana de rebufo: un auto justo adelante (no tan cerca como para chocar,
; ver el radio de 13px de CheckCollisions, pero pegado -- rebufo real, no
; "hay un auto en la pantalla") y bien alineado en X. Angosta a proposito:
; con 5 autos alrededor una ventana ancha entra en carga casi todo el
; tiempo, y las reglas piden "menos carga" para el rebufo, no comparable a
; frenar de verdad.
SLIP_Y_MIN = 14
SLIP_Y_MAX = 26
SLIP_X_TOL = 8
; descarga: tasa fija de consumo y el tope boosteado, +15% aproximado con
; corrimientos (curCap + curCap/8 + curCap/64 = ~1.14x) en vez de una
; multiplicacion o una tabla nueva -- mismo espiritu que el resto del motor.
ERS_DRAIN = 2
ERS_WEAR_THRESHOLD = 75       ; descargar con las gomas mas gastadas que
                               ; esto acelera el desgaste (ver WearTick)
ERS_WEAR_BONUS = 8

; Uso de la IA: version bien abstraida, reusando la deteccion de defensa
; que ya existe (UpdateAI, la rama @pelea/DEFEND_RANGE). No se modela "esta
; en una recta" -- alcanza con que este defendiendo, igual de abstraido que
; el resto de la IA (defBonus tampoco distingue donde esta en la pista).
AI_ERS_RECHARGE = 40    ; por vuelta del JUGADOR (misma simplificacion que
                         ; ApplyLapVariation, que tambien dispara ahi)
AI_ERS_DRAIN    = 2
AI_ERS_BONUS    = 10    ; pace extra mientras defiende con energia, ademas
                         ; de defBonus

; --- semaforo de largada ---
; Medido con el emulador: arrancando desde la pole con reaccion PERFECTA
; (acelerar desde el primer cuadro posible), el jugador ya caia a P4 en 2
; segundos de carrera, porque gameState pasaba a ST_RACE (que dispara
; startRamp/launchSpd de la IA, sin depender de ningun boton) en el mismo
; cuadro que START en la parrilla -- sin un "YA" compartido, la IA siempre
; le saca ventaja al tiempo de reaccion humano. El semaforo resuelve esto
; por SECUENCIACION, no tocando la rampa: mientras gameState==ST_SEMAPHORE,
; RaceLogic no corre (nadie llama UpdateAI/UpdatePlayer), asi que
; startRamp queda congelado hasta que se apagan las luces.
SEMAPHORE_LIGHTS = 5
SEMAPHORE_STEP_LEN = 30    ; cuadros entre luz y luz (~0.5s)
SEMAPHORE_WAIT_BASE = 30   ; espera minima con las 5 prendidas antes de
                            ; apagar, para que no se pueda memorizar el
                            ; cuadro exacto (igual que en F1 real)
SEMAPHORE_WAIT_RAND = 63   ; + azar(0..63)
JUMPSTART_PENALTY_SECS = 5 ; adelantarse suma esto a penaltySecs (mismo
                            ; acumulador que ya usa el exceso de velocidad
                            ; en boxes, sumado una vez al final en GoEnd)

T_GRASS_A = $01
T_GRASS_B = $02
T_ROAD    = $03
T_DASH    = $04
T_CURB_A  = $05
T_CURB_B  = $06
T_EDGE    = $07
T_GRAVEL  = $08
T_PIT_A   = $09
T_PIT_B   = $0A

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

; qualy
lapFrameLo: .res 1          ; cronometro de la vuelta lanzada, en cuadros
lapFrameHi: .res 1
lapValid:   .res 1          ; 0 si se salio con las cuatro ruedas
offRoadBad: .res 1          ; salida franca (el CENTRO del auto fuera del asfalto)
qualyLap:   .res 1          ; 1 = vuelta de salida, 2 = vuelta lanzada
startRamp:  .res 1          ; cuadros que le quedan a la largada parada
launchSpd:  .res 1          ; velocidad entera de la IA mientras acelera
launchTick: .res 1          ; para subir launchSpd cada LAUNCH_STEP cuadros

; gomas (fase 4)
tireCompound: .res 1        ; 0=blando 1=medio 2=duro
tireWear:     .res 1        ; 0-100
usedMask:     .res 1        ; bit0/1/2 = compuesto usado alguna vez esta carrera
curCapHi:     .res 1        ; tope dinamico de velocidad, 8.8 (formato de spdHi/Lo)
curCapLo:     .res 1
lapOffRoad:   .res 1        ; se salio de pista en algun cuadro de esta vuelta
lapCrash:     .res 1        ; hubo un choque esta vuelta
lapHardBrake: .res 1        ; freno fuerte a alta velocidad esta vuelta

; boxes (fase 4 etapa 2)
inPit:        .res 1        ; el auto esta AHORA sobre la franja de boxes
pitCommitted: .res 1        ; entro a boxes esta ventana: limite de 60% el resto
pitPenalized: .res 1        ; ya se le sumo la penalidad de esta parada
penaltySecs:  .res 1        ; segundos de penalidad, se suman al tiempo en GoEnd

; boxes (fase 4 etapa 3): menu de parada y pitStopTimer
wingLevel:    .res 1        ; -1/0/+1, ajuste de ala (entra en RecalcCap)
pitMenuShown: .res 1        ; ya se abrio el menu esta parada (no reabrir)
pitCursor:    .res 1        ; 0=GOMA, 1=ALA, fila seleccionada en el menu
menuCompound: .res 1        ; seleccion en curso (se aplica recien al confirmar)
menuWing:     .res 1        ; 0/1/2 = -1/0/+1, idem
pitTimerLo:   .res 1        ; cuadros que le quedan a la parada, 16 bits
pitTimerHi:   .res 1

; ERS (fase 5)
ersEnergy:    .res 1        ; 0-100
ersActive:    .res 1        ; se esta descargando este cuadro
lapErsAbuse:  .res 1        ; descargo con las gomas gastadas esta vuelta

; semaforo de largada
semaphoreTick: .res 1       ; cuadros dentro del paso actual
semaphoreStep: .res 1       ; 0-5, cuantas luces prendidas
semaphoreWait: .res 1       ; espera extra al azar, sorteada al llegar a 5
jumpStart:     .res 1       ; ya se conto un arranque adelantado esta sesion

; Exportadas para que tools/probe.py pueda leerlas por nombre desde el emulador
.exportzp gameState, playerX, spdLo, spdHi, distLo, distHi
.exportzp lapNum, crashT, offRoad, scrollLo, secs, mins, finished
.exportzp prgBank, bankVal, topRow, genCC
.exportzp plyTotalLo, plyTotalHi, playerPos, oamIdx, scrollNT
.exportzp lapFrameLo, lapFrameHi, lapValid, offRoadBad, qualyLap
.exportzp startRamp, launchSpd
.exportzp tireCompound, tireWear, usedMask, curCapHi, curCapLo
.exportzp inPit, pitCommitted, penaltySecs
.exportzp wingLevel, pitMenuShown, pitCursor, menuCompound, menuWing
.exportzp pitTimerLo, pitTimerHi
.exportzp ersEnergy, ersActive, lapErsAbuse
.exportzp semaphoreTick, semaphoreStep, semaphoreWait, jumpStart

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

.export carCount, carDrv, carX, carY

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
qTimeLo:    .res NUM_DRIVERS   ; tiempo de qualy de cada uno, en cuadros
qTimeHi:    .res NUM_DRIVERS

.export qTimeLo, qTimeHi

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
defBonus:   .res NUM_DRIVERS   ; cuanto aprieta cada uno defendiendo
qBase:      .res NUM_DRIVERS   ; tiempo base de qualy, menos QTIME_OFF

teamName0:  .res 11            ; abreviatura de equipo, 3 letras
teamName1:  .res 11
teamName2:  .res 11

.export pilotCode0, pilotCode1, pilotCode2, pilotTeam, teamPaceLo, defBonus

; Tope dinamico de velocidad (ver RecalcCap), copiado una vez desde BANK3
; igual que la tabla de pilotos: 15 entradas, 3 compuestos x 5 bandas de
; desgaste, indexadas como tireCompound*5 + banda.
capTabLo:   .res 15
capTabHi:   .res 15

; Parada abstraida de la IA (fase 4 etapa 4): vuelta (3..TOTAL_LAPS-2) en la
; que cada IA pierde AI_PITSTOP_LOSS de golpe. Se sortea una vez por
; carrera en StartRace; PLAYER_SLOT no se usa.
pitStopLap: .res NUM_DRIVERS

.export pitStopLap

; Energia de ERS de cada IA (fase 5 etapa 3), 0-100. Recarga por vuelta del
; jugador (ApplyLapVariation), se consume defendiendo (UpdateAI). PLAYER_SLOT
; no se usa: la energia del jugador es ersEnergy, en zeropage.
aiErs:      .res NUM_DRIVERS

.export aiErs

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
    lda defBonusTab,x
    sta defBonus,x
    lda qBaseTab,x
    sta qBase,x
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
    ldx #0
@caps:
    lda capTabLoTab,x
    sta capTabLo,x
    lda capTabHiTab,x
    sta capTabHi,x
    inx
    cpx #15
    bne @caps
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

; paceLo = 38 + (ritmo_equipo + habilidad - 159) * 5. Constante de
; ensamblado: la resuelve ca65, no el 6502.
;
; CALIBRADO CONTRA MEDICIONES REALES, no contra una suposicion. Corriendo la
; ROM en el emulador con un piloto automatico, el jugador rinde:
;
;     solo apretando A (se lleva todo por delante)  ~3.19 unidades/cuadro
;     siguiendo el asfalto                          ~3.49
;     ademas esquivando, o sea sin chocar           ~3.82
;     perfecto (nunca choca, nunca se sale)          4.00
;
; El rango de la IA va de 3.148 (LIN) a 3.773 (VER). Ningun rival tiene ritmo
; BASE por encima de un jugador limpio: a cualquiera lo podes alcanzar. Pero
; los cuatro de arriba, DEFENDIENDO (ver defBonusTab), pasan de 3.82, asi que
; para pasarlos hay que estar cerca del 4.00. De ahi que se pueda subir hasta
; el podio manejando limpio, pero ganar exija manejar casi perfecto.
;
; Dos versiones anteriores quedaron cortas: la primera puso la IA entera por
; DEBAJO del jugador (se ganaba siempre pasara lo que pasara), y la segunda
; la dejo por debajo de un jugador que ademas esquiva (se ganaba siempre
; siempre que no chocaras). Las dos se detectaron jugando, no leyendo.
;
; GAS (Alpine) queda en el tercio bajo -> "medio de parrilla", como pide la
; regla de diseno.
teamPaceLoTab:
    .byte 38+(95+95-159)*5   ; NOR
    .byte 38+(95+94-159)*5   ; PIA
    .byte 38+(92+95-159)*5   ; LEC
    .byte 38+(92+93-159)*5   ; HAM
    .byte 38+(92+99-159)*5   ; VER
    .byte 38+(92+85-159)*5   ; HAD
    .byte 38+(90+93-159)*5   ; RUS
    .byte 38+(90+87-159)*5   ; ANT
    .byte 38+(85+88-159)*5   ; ALB
    .byte 38+(85+90-159)*5   ; SAI
    .byte 38+(84+92-159)*5   ; ALO
    .byte 38+(84+78-159)*5   ; STR
    .byte 38+(83+82-159)*5   ; LAW
    .byte 38+(83+76-159)*5   ; LIN
    .byte 38+(82+87-159)*5   ; HUL
    .byte 38+(82+82-159)*5   ; BOR
    .byte 38+(82+85-159)*5   ; OCO
    .byte 38+(82+84-159)*5   ; BEA
    .byte 38+(80+87-159)*5   ; GAS
    .byte 0                     ; COL - jugador, no se usa
    .byte 38+(76+86-159)*5   ; PER
    .byte 38+(76+85-159)*5   ; BOT

; Cuanto aprieta cada piloto cuando lo tenes encima, sale de su HABILIDAD:
; (habilidad - 76) * 2, o sea 0 para el menos habil de la parrilla y 46 para
; Verstappen. Es lo que hace que pasar a un Verstappen o un Hamilton cueste y
; pasar a un colista no: el ritmo base lo pone el auto (ritmo_equipo), pero
; pelear el paso lo pone el piloto.
;
; Con esto, defendiendo, VER llega a 3.74 unidades/cuadro y LIN se queda en su
; 3.15. El jugador manejando bien rinde ~3.49 y perfecto 4.0: los de arriba
; solo se pasan manejando casi perfecto, el fondo de parrilla se pasa
; manejando bien.
defBonusTab:
    .byte (95-76)*2   ; NOR
    .byte (94-76)*2   ; PIA
    .byte (95-76)*2   ; LEC
    .byte (93-76)*2   ; HAM
    .byte (99-76)*2   ; VER
    .byte (85-76)*2   ; HAD
    .byte (93-76)*2   ; RUS
    .byte (87-76)*2   ; ANT
    .byte (88-76)*2   ; ALB
    .byte (90-76)*2   ; SAI
    .byte (92-76)*2   ; ALO
    .byte (78-76)*2   ; STR
    .byte (82-76)*2   ; LAW
    .byte (76-76)*2   ; LIN
    .byte (87-76)*2   ; HUL
    .byte (82-76)*2   ; BOR
    .byte (85-76)*2   ; OCO
    .byte (84-76)*2   ; BEA
    .byte (87-76)*2   ; GAS
    .byte 0           ; COL - jugador
    .byte (86-76)*2   ; PER
    .byte (85-76)*2   ; BOT

; Tiempo base de qualy de cada IA, en cuadros, ya resuelto por ca65:
; QTIME_BASE - (ritmo_equipo + habilidad - 159) * QTIME_FACTOR. En tiempo de
; ejecucion GenAITimes le suma el azar. Va en un byte porque todos los valores
; caen entre 780 y 940... que NO entra en un byte: por eso la tabla guarda el
; tiempo menos 512, y GenAITimes reconstruye. Ver el comentario ahi.
qBaseTab:
    .byte QTIME_BASE-(95+95-159)*QTIME_FACTOR-QTIME_OFF   ; NOR
    .byte QTIME_BASE-(95+94-159)*QTIME_FACTOR-QTIME_OFF   ; PIA
    .byte QTIME_BASE-(92+95-159)*QTIME_FACTOR-QTIME_OFF   ; LEC
    .byte QTIME_BASE-(92+93-159)*QTIME_FACTOR-QTIME_OFF   ; HAM
    .byte QTIME_BASE-(92+99-159)*QTIME_FACTOR-QTIME_OFF   ; VER
    .byte QTIME_BASE-(92+85-159)*QTIME_FACTOR-QTIME_OFF   ; HAD
    .byte QTIME_BASE-(90+93-159)*QTIME_FACTOR-QTIME_OFF   ; RUS
    .byte QTIME_BASE-(90+87-159)*QTIME_FACTOR-QTIME_OFF   ; ANT
    .byte QTIME_BASE-(85+88-159)*QTIME_FACTOR-QTIME_OFF   ; ALB
    .byte QTIME_BASE-(85+90-159)*QTIME_FACTOR-QTIME_OFF   ; SAI
    .byte QTIME_BASE-(84+92-159)*QTIME_FACTOR-QTIME_OFF   ; ALO
    .byte QTIME_BASE-(84+78-159)*QTIME_FACTOR-QTIME_OFF   ; STR
    .byte QTIME_BASE-(83+82-159)*QTIME_FACTOR-QTIME_OFF   ; LAW
    .byte QTIME_BASE-(83+76-159)*QTIME_FACTOR-QTIME_OFF   ; LIN
    .byte QTIME_BASE-(82+87-159)*QTIME_FACTOR-QTIME_OFF   ; HUL
    .byte QTIME_BASE-(82+82-159)*QTIME_FACTOR-QTIME_OFF   ; BOR
    .byte QTIME_BASE-(82+85-159)*QTIME_FACTOR-QTIME_OFF   ; OCO
    .byte QTIME_BASE-(82+84-159)*QTIME_FACTOR-QTIME_OFF   ; BEA
    .byte QTIME_BASE-(80+87-159)*QTIME_FACTOR-QTIME_OFF   ; GAS
    .byte 0                                          ; COL - jugador
    .byte QTIME_BASE-(76+86-159)*QTIME_FACTOR-QTIME_OFF   ; PER
    .byte QTIME_BASE-(76+85-159)*QTIME_FACTOR-QTIME_OFF   ; BOT

; MCL FER RBR MER WIL AST RCB AUD HAA ALP CAD
teamName0Tab: .byte "MFRMWARAHAC"
teamName1Tab: .byte "CEBEISCUALA"
teamName2Tab: .byte "LRRRLTBDAPD"

; Tope dinamico de velocidad (curCapHi/Lo, 8.8) segun compuesto y banda de
; desgaste. 15 valores = 3 compuestos x 5 bandas, indexados como
; tireCompound*5 + banda (ver RecalcCap). Formula resuelta en compilacion,
; mismo patron que teamPaceLoTab/qBaseTab: MAXSPD_HI son solo 5 valores
; enteros (0-4), asi que calcular el porcentaje en tiempo real perderia toda
; la resolucion (una reduccion del 12% da 3.52, que redondea a 3 -- un salto
; grosero). En 8.8 en cambio hay 256 pasos por unidad entera.
;
; valor = MAXSPD_HI*256 * grip_compuesto% * grip_banda% / 10000
capTabLoTab:
    .byte <(MAXSPD_HI*256*SOFT_GRIP*WBAND_0/10000)   ; blando, desgaste 0-49
    .byte <(MAXSPD_HI*256*SOFT_GRIP*WBAND_1/10000)   ; blando, 50-74
    .byte <(MAXSPD_HI*256*SOFT_GRIP*WBAND_2/10000)   ; blando, 75-89
    .byte <(MAXSPD_HI*256*SOFT_GRIP*WBAND_3/10000)   ; blando, 90-99
    .byte <(MAXSPD_HI*256*SOFT_GRIP*WBAND_4/10000)   ; blando, pinchado
    .byte <(MAXSPD_HI*256*MED_GRIP*WBAND_0/10000)    ; medio, 0-49
    .byte <(MAXSPD_HI*256*MED_GRIP*WBAND_1/10000)    ; medio, 50-74
    .byte <(MAXSPD_HI*256*MED_GRIP*WBAND_2/10000)    ; medio, 75-89
    .byte <(MAXSPD_HI*256*MED_GRIP*WBAND_3/10000)    ; medio, 90-99
    .byte <(MAXSPD_HI*256*MED_GRIP*WBAND_4/10000)    ; medio, pinchado
    .byte <(MAXSPD_HI*256*HARD_GRIP*WBAND_0/10000)   ; duro, 0-49
    .byte <(MAXSPD_HI*256*HARD_GRIP*WBAND_1/10000)   ; duro, 50-74
    .byte <(MAXSPD_HI*256*HARD_GRIP*WBAND_2/10000)   ; duro, 75-89
    .byte <(MAXSPD_HI*256*HARD_GRIP*WBAND_3/10000)   ; duro, 90-99
    .byte <(MAXSPD_HI*256*HARD_GRIP*WBAND_4/10000)   ; duro, pinchado
capTabHiTab:
    .byte >(MAXSPD_HI*256*SOFT_GRIP*WBAND_0/10000)
    .byte >(MAXSPD_HI*256*SOFT_GRIP*WBAND_1/10000)
    .byte >(MAXSPD_HI*256*SOFT_GRIP*WBAND_2/10000)
    .byte >(MAXSPD_HI*256*SOFT_GRIP*WBAND_3/10000)
    .byte >(MAXSPD_HI*256*SOFT_GRIP*WBAND_4/10000)
    .byte >(MAXSPD_HI*256*MED_GRIP*WBAND_0/10000)
    .byte >(MAXSPD_HI*256*MED_GRIP*WBAND_1/10000)
    .byte >(MAXSPD_HI*256*MED_GRIP*WBAND_2/10000)
    .byte >(MAXSPD_HI*256*MED_GRIP*WBAND_3/10000)
    .byte >(MAXSPD_HI*256*MED_GRIP*WBAND_4/10000)
    .byte >(MAXSPD_HI*256*HARD_GRIP*WBAND_0/10000)
    .byte >(MAXSPD_HI*256*HARD_GRIP*WBAND_1/10000)
    .byte >(MAXSPD_HI*256*HARD_GRIP*WBAND_2/10000)
    .byte >(MAXSPD_HI*256*HARD_GRIP*WBAND_3/10000)
    .byte >(MAXSPD_HI*256*HARD_GRIP*WBAND_4/10000)

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
:   cmp #ST_QUALY
    bne :+
    jsr QualyLogic
    jmp main
:   cmp #ST_GRID
    bne :+
    jsr GridLogic
    jmp main
:   cmp #ST_PITMENU
    bne :+
    jsr PitMenuLogic
    jmp main
:   cmp #ST_SEMAPHORE
    bne :+
    jsr SemaphoreLogic
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
    cpx #8
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
    jsr GoQualy             ; el fin de semana arranca por la qualy
:   rts

;=============================================================================
; QUALY
;
; Una sola vuelta lanzada. Se arranca DETENIDO: la primera vuelta es de
; salida y no cronometra, la segunda si. Salirse con las cuatro ruedas la
; anula, y sin vuelta valida se larga ultimo.
;
; Lo que las reglas piden y todavia no entra: arrancar en boxes, salir por el
; pit lane y su limite de velocidad. Todo eso es geometria de pista que llega
; con los boxes (fase 4), no una simplificacion por comodidad.
;=============================================================================
GoQualy:
    jsr RenderOff
    jsr CopyPilotTable
    lda #0
    sta scrollLo
    sta scrollNT
    sta lastTop
    sta topRow
    sta rowReady
    jsr DrawTrack

    lda #PLAYER_X0
    sta playerX
    lda #0
    sta playerXf
    sta spdLo
    sta spdHi                ; se arranca detenido
    sta distLo
    sta distHi
    sta crashT
    sta scrollFrac
    sta finished
    sta carCount
    sta lapFrameLo
    sta lapFrameHi
    lda #1
    sta lapNum
    sta qualyLap             ; 1 = vuelta de salida
    sta lapValid

    ; en la qualy no hay eleccion de compuesto todavia (llega en StartRace):
    ; se corre con gomas nuevas, tope de velocidad completo.
    lda #0
    sta tireCompound
    sta tireWear
    sta lapOffRoad
    sta lapCrash
    sta lapHardBrake
    sta inPit
    sta pitCommitted
    sta pitPenalized
    sta penaltySecs
    sta wingLevel
    sta pitMenuShown
    sta pitTimerLo
    sta pitTimerHi
    sta ersEnergy
    sta ersActive
    sta lapErsAbuse
    jsr RecalcCap

    lda #ST_QUALY
    sta gameState
    jsr RenderOn
    rts

; Como RaceLogic pero sin rivales en pista: en la qualy se sale solo. Los 21
; tiempos de la IA no se manejan, se generan por formula al terminar.
QualyLogic:
    jsr UpdatePlayer
    jsr UpdateScroll
    jsr UpdateTrack
    jsr QualyDistance
    ; QualyDistance puede haber cerrado la sesion y saltado a la parrilla; en
    ; ese caso no hay que seguir armando sprites de carrera encima, que
    ; volverian a dibujar el auto sobre la pantalla de parrilla.
    lda gameState
    cmp #ST_QUALY
    bne @rts
    jsr EngineSound
    jsr BuildOAMQualy
@rts:
    rts

; Avanza la distancia y el cronometro. La vuelta de salida no cuenta; la
; lanzada si, y termina la sesion al cruzar la linea.
QualyDistance:
    lda distLo
    clc
    adc spdHi
    sta distLo
    lda distHi
    adc #0
    sta distHi

    lda qualyLap             ; el cronometro solo corre en la vuelta lanzada
    cmp #2
    bne @nocrono
    inc lapFrameLo
    bne @nocrono
    inc lapFrameHi
@nocrono:

    ; salirse con las cuatro ruedas anula la vuelta lanzada
    lda offRoadBad
    beq @lineacheck
    lda qualyLap
    cmp #2
    bne @lineacheck
    lda #0
    sta lapValid

@lineacheck:
    lda distHi
    cmp #>LAP_LEN
    bcc @rts
    bne @cruza
    lda distLo
    cmp #<LAP_LEN
    bcc @rts
@cruza:
    lda distLo
    sec
    sbc #<LAP_LEN
    sta distLo
    lda distHi
    sbc #>LAP_LEN
    sta distHi
    jsr Blip

    lda qualyLap
    cmp #2
    beq @finvuelta
    lda #2                   ; se termino la de salida: arranca la lanzada
    sta qualyLap
    lda #2
    sta lapNum
    lda #0
    sta lapFrameLo
    sta lapFrameHi
    rts
@finvuelta:
    jsr FinishQualy
@rts:
    rts

; HUD de la qualy: vuelta, cronometro y si la vuelta esta anulada.
BuildOAMQualy:
    lda #0
    sta oamIdx

    lda playerX
    sta tmp1
    lda #PLAYER_Y
    sta tmp2
    lda #0
    sta tmp3
    jsr PutCar

    lda #'V'
    ldx #HUD_X
    ldy #8
    jsr PutChar
    lda qualyLap
    clc
    adc #'0'
    ldx #HUD_X+8
    ldy #8
    jsr PutChar
    lda #'/'
    ldx #HUD_X+16
    ldy #8
    jsr PutChar
    lda #'2'
    ldx #HUD_X+24
    ldy #8
    jsr PutChar

    ; cronometro SS.CC, o "-----" si la vuelta ya esta anulada
    lda lapValid
    bne @crono
    ldx #HUD_X
    ldy #16
    lda #'-'
    jsr PutChar
    lda #'-'
    ldx #HUD_X+8
    ldy #16
    jsr PutChar
    lda #'-'
    ldx #HUD_X+16
    ldy #16
    jsr PutChar
    lda #'-'
    ldx #HUD_X+24
    ldy #16
    jsr PutChar
    lda #'-'
    ldx #HUD_X+32
    ldy #16
    jsr PutChar
    jmp @clr
@crono:
    lda lapFrameLo
    sta numLo
    lda lapFrameHi
    sta numHi
    jsr FramesToTime         ; dig2 = decenas de seg, dig1/dig0 = unidad y centesimas
    lda tmp5
    clc
    adc #'0'
    ldx #HUD_X
    ldy #16
    jsr PutChar
    lda tmp6
    clc
    adc #'0'
    ldx #HUD_X+8
    ldy #16
    jsr PutChar
    lda #'.'
    ldx #HUD_X+16
    ldy #16
    jsr PutChar
    lda dig1
    clc
    adc #'0'
    ldx #HUD_X+24
    ldy #16
    jsr PutChar
    lda dig0
    clc
    adc #'0'
    ldx #HUD_X+32
    ldy #16
    jsr PutChar

@clr:
    ldx oamIdx
    lda #$FF
:   sta oam,x
    inx
    bne :-
    rts

; numLo/numHi = cuadros -> tmp5 (decenas de seg), tmp6 (unidades),
; dig1/dig0 (centesimas). A 60 cuadros por segundo.
FramesToTime:
    lda #0
    sta tmp5
    sta tmp6
@seg:
    lda numHi                ; mientras queden 60 cuadros, es un segundo mas
    bne @resta
    lda numLo
    cmp #60
    bcc @cent
@resta:
    lda numLo
    sec
    sbc #60
    sta numLo
    lda numHi
    sbc #0
    sta numHi
    inc tmp6
    lda tmp6
    cmp #10
    bne @seg
    lda #0
    sta tmp6
    inc tmp5
    jmp @seg
@cent:
    ; Lo que sobra son cuadros (0..59) -> centesimas = cuadros * 100 / 60, que
    ; es lo mismo que cuadros * 5 / 3.
    ;
    ; El *5 va en 16 BITS a proposito: 59*5 = 295 no entra en un byte, y
    ; hacerlo en 8 lo envolvia a 39, mostrando ".13" donde iba ".98".
    lda numLo
    sta tmp1
    lda #0
    sta numHi
    lda tmp1
    asl a
    rol numHi
    asl a
    rol numHi                ; *4 en 16 bits
    clc
    adc tmp1
    sta numLo
    lda numHi
    adc #0
    sta numHi                ; *5
    ldx #0
@div3:
    lda numHi                ; mientras el resto sea >= 3, sacarle 3
    bne @resta3
    lda numLo
    cmp #3
    bcc @listo
@resta3:
    lda numLo
    sec
    sbc #3
    sta numLo
    lda numHi
    sbc #0
    sta numHi
    inx
    jmp @div3
@listo:
    stx numLo
    lda #0
    sta numHi
    jsr ToDigits             ; deja dig1 = decenas, dig0 = unidades
    rts

; Cierra la sesion: guarda el tiempo del jugador, genera los 21 de la IA,
; ordena la parrilla y va a la pantalla de grid.
FinishQualy:
    lda lapValid
    beq @anulada
    lda lapFrameLo
    sta qTimeLo+PLAYER_SLOT
    lda lapFrameHi
    sta qTimeHi+PLAYER_SLOT
    jmp @ia
@anulada:
    lda #<QTIME_NULA         ; sin vuelta valida se larga ultimo
    sta qTimeLo+PLAYER_SLOT
    lda #>QTIME_NULA
    sta qTimeHi+PLAYER_SLOT
@ia:
    jsr GenAITimes
    jsr SortByQualy
    jsr GoGrid
    rts

; Los 21 tiempos de la IA no se manejan: salen de la formula de las reglas,
; tiempo_base menos lo que valen equipo y piloto, mas un azar chico. El azar
; es lo que hace que la sesion valga la pena repetirla: da vuelta el orden
; entre pilotos parecidos sin romper la jerarquia general.
; El tiempo final se arma como QTIME_OFF + tabla + azar (ver QTIME_OFF).
GenAITimes:
    ldx #0
@lp:
    cpx #PLAYER_SLOT
    beq @next
    jsr Rand
    lda seed
    and #QTIME_RAND
    clc
    adc qBase,x              ; la copia en RAM, NO qBaseTab: esa vive en BANK3
                             ; y aca esta mapeado BANK0, se leeria basura
    sta qTimeLo,x
    lda #>QTIME_OFF
    adc #0                   ; el acarreo de la suma de arriba
    sta qTimeHi,x
@next:
    inx
    cpx #NUM_DRIVERS
    bne @lp
    rts

; Ordena orderTable por tiempo de qualy ASCENDENTE. SortAllDrivers ya ordena
; por totalLo/Hi descendente, asi que en vez de escribir un segundo sort se
; carga el MERITO ($FFFF - tiempo) y se reusa la que ya esta probada.
SortByQualy:
    ldx #0
@lp:
    lda #$FF
    sec
    sbc qTimeLo,x
    sta totalLo,x
    lda #$FF
    sbc qTimeHi,x
    sta totalHi,x
    txa
    sta orderTable,x
    inx
    cpx #NUM_DRIVERS
    bne @lp
    jsr SortAllDrivers
    rts

;=============================================================================
; PANTALLA DE PARRILLA
;=============================================================================
gridtxt: .byte "PARRILLA", 0

GoGrid:
    jsr RenderOff
    jsr SilenceEngine
    lda #1
    sta tireCompound         ; arranca en MEDIO; LEFT/RIGHT lo cambia (GridLogic)
    ; UpdateTrack corre antes que QualyDistance en el mismo cuadro, asi que
    ; puede haber dejado una fila del circuito esperando: si no se descarta,
    ; el NMI la escribe encima de la parrilla recien dibujada.
    lda #0
    sta rowReady
    sta attrReady

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

    lda #<gridtxt
    sta ptr
    lda #>gridtxt
    sta ptr+1
    lda #$2C
    sta tmp3
    lda #$20
    sta tmp4
    jsr DrawText

    lda #0
    sta rankLine
@row:
    ldx rankLine
    lda orderTable,x
    sta rankDrv

    lda rankLine
    clc
    adc #4
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

    ; tiempo, o "-----" si no hizo vuelta valida
    ldx rankDrv
    lda qTimeHi,x
    cmp #>QTIME_NULA
    bne @contiempo
    lda qTimeLo,x
    cmp #<QTIME_NULA
    bne @contiempo
    ldx #5
    lda #'-'
:   sta PPUDATA
    dex
    bne :-
    jmp @sig
@contiempo:
    lda qTimeLo,x
    sta numLo
    lda qTimeHi,x
    sta numHi
    jsr FramesToTime
    lda tmp5
    clc
    adc #'0'
    sta PPUDATA
    lda tmp6
    clc
    adc #'0'
    sta PPUDATA
    lda #'.'
    sta PPUDATA
    lda dig1
    clc
    adc #'0'
    sta PPUDATA
    lda dig0
    clc
    adc #'0'
    sta PPUDATA
@sig:
    inc rankLine
    lda rankLine
    cmp #NUM_DRIVERS
    beq @fin
    jmp @row
@fin:
    ldx #0
    lda #$FF
:   sta oam,x
    inx
    bne :-

    jsr DrawGomaLine

    lda #0
    sta scrollLo
    sta scrollNT
    lda #ST_GRID
    sta gameState
    jsr RenderOn
    rts

; Redibuja la linea de eleccion de compuesto (fila 27: las 22 de la parrilla
; ocupan la 4-25, asi que queda libre). Necesita el rendering apagado -- se
; llama con RenderOff ya puesto (GoGrid) o lo pone GridLogic antes de
; llamarla, porque escribir a PPUDATA con el rendering prendido corrompe la
; pantalla (ver CLAUDE.md).
gomaBlando: .byte "GOMA: BLANDO", 0
gomaMedio:  .byte "GOMA: MEDIO ", 0
gomaDuro:   .byte "GOMA: DURO  ", 0
gomaPtrLo: .byte <gomaBlando, <gomaMedio, <gomaDuro
gomaPtrHi: .byte >gomaBlando, >gomaMedio, >gomaDuro

DrawGomaLine:
    lda #27
    jsr SetClassAddr
    lda tmp3
    clc
    adc #4
    sta tmp3
    ldx tireCompound
    lda gomaPtrLo,x
    sta ptr
    lda gomaPtrHi,x
    sta ptr+1
    jsr DrawText
    rts

GridLogic:
    lda padNew
    and #BTN_LEFT
    beq @noleft
    lda tireCompound
    bne @dec
    lda #2
    sta tireCompound
    jmp @redrawgoma
@dec:
    dec tireCompound
    jmp @redrawgoma
@noleft:
    lda padNew
    and #BTN_RIGHT
    beq @noright
    lda tireCompound
    cmp #2
    bne @inc
    lda #0
    sta tireCompound
    jmp @redrawgoma
@inc:
    inc tireCompound
@redrawgoma:
    jsr Blip
    jsr RenderOff
    jsr DrawGomaLine
    jsr RenderOn
@noright:
    lda padNew
    and #BTN_START
    beq :+
    jsr Blip
    jsr GoSemaphore
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

    lda #PLAYER_X0
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

    ; gomas: tireCompound ya viene elegido en la parrilla (GridLogic). Marca
    ; ese compuesto como usado (regla de los dos compuestos, ver GoEnd) y
    ; calcula el tope de velocidad inicial.
    lda #0
    sta tireWear
    sta lapOffRoad
    sta lapCrash
    sta lapHardBrake
    lda #1
    ldx tireCompound
    beq @gotbit
@shl:
    asl a
    dex
    bne @shl
@gotbit:
    sta usedMask
    jsr RecalcCap

    ; boxes
    lda #0
    sta inPit
    sta pitCommitted
    sta pitPenalized
    sta penaltySecs
    sta wingLevel
    sta pitMenuShown
    sta pitTimerLo
    sta pitTimerHi
    jsr AssignAIPitLaps

    ; ERS
    lda #0
    sta ersEnergy
    sta ersActive
    sta lapErsAbuse
    ldx #0
:   sta aiErs,x
    inx
    cpx #NUM_DRIVERS
    bne :-

    ; --- la parrilla ---
    ; Se larga desde el puesto que salio de la qualy: orderTable ya viene
    ; ordenada por tiempo (SortByQualy), asi que el que quedo primero arranca
    ; con la mayor distancia y de ahi para abajo, GRID_STEP entre auto y auto.
    ; Es lo que le da consecuencia a la sesion.
    lda #0
    sta carCount
    lda #85                  ; largada parada: ver la rampa en UpdateAI
    sta startRamp
    lda #0
    sta launchSpd
    sta launchTick

    lda #<(PLAYER_START + (NUM_DRIVERS-1) * GRID_STEP)
    sta tmp1
    lda #>(PLAYER_START + (NUM_DRIVERS-1) * GRID_STEP)
    sta tmp2
    ldx #0
@pl:
    ldy orderTable,x         ; el piloto que largue en el puesto x
    lda tmp1
    sta totalLo,y
    lda tmp2
    sta totalHi,y
    lda #0
    sta paceFrac,y
    txa
    sta rankOf,y
    cpy #PLAYER_SLOT         ; el jugador lleva su propio acumulador
    bne :+
    lda tmp1
    sta plyTotalLo
    lda tmp2
    sta plyTotalHi
    txa
    clc
    adc #1
    sta playerPos
:   lda tmp1                 ; el siguiente arranca GRID_STEP mas atras
    sec
    sbc #GRID_STEP
    sta tmp1
    lda tmp2
    sbc #0
    sta tmp2
    inx
    cpx #NUM_DRIVERS
    bne @pl
    rts

; Semaforo de largada: arma el estado de la carrera (StartRace hace todo el
; trabajo salvo pasar a ST_RACE) y muestra las luces apagadas + el auto
; quieto en la grilla. SemaphoreLogic las va prendiendo y recien cuando se
; apagan todas pasa a ST_RACE -- ahi arrancan startRamp/launchSpd, en el
; mismo cuadro para el jugador y para la IA.
GoSemaphore:
    jsr StartRace
    lda #0
    sta semaphoreTick
    sta semaphoreStep
    sta semaphoreWait
    sta jumpStart
    jsr BuildSemaphoreOAM
    lda #ST_SEMAPHORE
    sta gameState
    jsr RenderOn
    rts

; Arma el OAM del semaforo: el auto del jugador quieto (mismo PutCar que usa
; BuildOAM) mas las SEMAPHORE_LIGHTS luces, prendidas (paleta 1, roja) hasta
; semaphoreStep y apagadas (paleta 2, plateada) el resto.
; Arriba del auto, centradas sobre la pista (no sobre el panel de datos,
; que arranca en HUD_X): 5 luces separadas 16px, ancho total 80px.
SEMAPHORE_Y = 40
SEMAPHORE_X0 = 60

BuildSemaphoreOAM:
    lda #0
    sta oamIdx

    lda playerX
    sta tmp1
    lda #PLAYER_Y
    sta tmp2
    lda #0
    sta tmp3
    jsr PutCar

    ldx oamIdx
    ldy #0
@lp:
    lda #SEMAPHORE_Y-1
    sta oam,x
    inx
    lda #$84
    sta oam,x
    inx
    cpy semaphoreStep
    bcc @on
    lda #2                   ; apagada: paleta plateada
    bne @put                 ; siempre: 2 != 0
@on:
    lda #1                   ; prendida: paleta roja
@put:
    sta oam,x
    inx
    tya
    asl a
    asl a
    asl a
    asl a                    ; y*16, separacion entre luces
    clc
    adc #SEMAPHORE_X0
    sta oam,x
    inx
    iny
    cpy #SEMAPHORE_LIGHTS
    bne @lp
    stx oamIdx

    ldx oamIdx
    lda #$FF
@clr:
    sta oam,x
    inx
    bne @clr
    rts

SemaphoreLogic:
    ; salida adelantada: apretar A antes de que se apaguen todas suma la
    ; penalidad una sola vez. El auto no se mueve igual (RaceLogic no
    ; corre en este estado), asi que es una intencion detectada por
    ; boton, no un movimiento real evitado.
    lda jumpStart
    bne @nopenalty
    lda padNew
    and #BTN_A
    beq @nopenalty
    lda #1
    sta jumpStart
    lda penaltySecs
    clc
    adc #JUMPSTART_PENALTY_SECS
    sta penaltySecs
@nopenalty:
    inc semaphoreTick
    lda semaphoreStep
    cmp #SEMAPHORE_LIGHTS
    bcs @waiting
    lda semaphoreTick
    cmp #SEMAPHORE_STEP_LEN
    bcc @rts
    lda #0
    sta semaphoreTick
    inc semaphoreStep
    jsr Blip
    lda semaphoreStep
    cmp #SEMAPHORE_LIGHTS
    bne @redraw
    ; se acaba de prender la ultima: sortear la espera extra antes de
    ; apagarlas (que no se pueda memorizar el cuadro exacto)
    jsr Rand
    lda seed
    and #SEMAPHORE_WAIT_RAND
    clc
    adc #SEMAPHORE_WAIT_BASE
    sta semaphoreWait
@redraw:
    jsr BuildSemaphoreOAM
    jmp @rts
@waiting:
    lda semaphoreTick
    cmp semaphoreWait
    bcc @rts
    ; GO: RaceLogic arma el OAM de nuevo desde el proximo cuadro, no hace
    ; falta apagar las luces a mano
    jsr Blip
    lda #ST_RACE
    sta gameState
@rts:
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
    beq @nosel
    jsr EnterClass           ; SELECT: pausa y muestra la clasificacion
    rts
@nosel:
    ; boxes: apenas el auto se compromete (pitCommitted, ver UpdatePlayer)
    ; el menu se abre solo, una vez por parada -- tocar el carril alcanza,
    ; no hace falta seguir manejando hasta un punto mas.
    lda pitCommitted
    beq @norm
    lda pitMenuShown
    bne @norm
    lda #1
    sta pitMenuShown
    jsr EnterPitMenu
    rts
@norm:
    jsr UpdateTimer
    lda pitTimerHi
    ora pitTimerLo
    beq @drive
    ; parado en el box: sin control ni velocidad, pero la IA sigue
    ; corriendo -- por eso duele de verdad perder puesto durante la parada.
    lda #0
    sta spdHi
    sta spdLo
    jsr DecPitTimer
    jmp @aicontinue
@drive:
    jsr UpdatePlayer
@aicontinue:
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
    lda pitTimerHi
    ora pitTimerLo
    bne @nocol                ; parado en el box: no es justo que te choquen
    jsr CheckCollisions
    jsr UpdateERS              ; despues de CheckCollisions: necesita el
                                ; crashT de ESTE cuadro si hubo choque nuevo
@nocol:
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
    ; freno fuerte a alta velocidad: aproxima la frenada real sin agregar un
    ; sensor nuevo (ver WearTick)
    lda spdHi
    cmp #HARDBRAKE_SPD
    bcc @notfuerte
    lda #1
    sta lapHardBrake
@notfuerte:
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
    ; ERS: mantener ARRIBA descarga si hay energia y no se esta en boxes
    ; (prohibido ahi). Se decide antes del clamp de gomas, que necesita
    ; saber si usa el tope normal o el boosteado (ver @onroad mas abajo).
    lda #0
    sta ersActive
    lda pitCommitted
    bne @noers
    lda ersEnergy
    beq @noers
    lda pad1
    and #BTN_UP
    beq @noers
    lda #1
    sta ersActive
    lda ersEnergy
    sec
    sbc #ERS_DRAIN
    bcs :+
    lda #0
:   sta ersEnergy
    ; con las gomas mas gastadas que ERS_WEAR_THRESHOLD, descargar acelera
    ; el desgaste todavia mas (WearTick lo consume al cerrar la vuelta)
    lda tireWear
    cmp #ERS_WEAR_THRESHOLD
    bcc @noers
    lda #1
    sta lapErsAbuse
@noers:
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
    ; Tope efectivo en tmp1(hi)/tmp2(lo): el de gomas (curCapHi/Lo, 8.8,
    ; recalculado por WearTick al cerrar cada vuelta) o, mientras se
    ; descarga ERS, ese mismo tope +15% aproximado con corrimientos
    ; (curCap + curCap/8 + curCap/64 =~ 1.14x) en vez de multiplicar en
    ; tiempo real o armar una tabla nueva -- mismo espiritu que el resto
    ; del motor.
    lda curCapHi
    sta tmp1
    lda curCapLo
    sta tmp2
    lda ersActive
    beq @capdone
    lda curCapHi
    sta tmp3
    lda curCapLo
    sta tmp4
    ldy #3
:   lsr tmp3
    ror tmp4
    dey
    bne :-
    lda tmp2
    clc
    adc tmp4
    sta tmp2
    lda tmp1
    adc tmp3
    sta tmp1
    lda curCapHi
    sta tmp3
    lda curCapLo
    sta tmp4
    ldy #6
:   lsr tmp3
    ror tmp4
    dey
    bne :-
    lda tmp2
    clc
    adc tmp4
    sta tmp2
    lda tmp1
    adc tmp3
    sta tmp1
@capdone:
    lda spdHi
    cmp tmp1
    bcc @spdok
    bne @clampcap
    lda spdLo
    cmp tmp2
    bcc @spdok
@clampcap:
    lda tmp1
    sta spdHi
    lda tmp2
    sta spdLo
@spdok:

    ; boxes: limite de velocidad aparte del de las gomas, se aplica ademas
    ; (el mas restrictivo de los dos gana, porque los dos son clamps sobre
    ; el mismo par spdHi/spdLo). pitCommitted es del cuadro ANTERIOR --
    ; mismo desfasaje de un cuadro que offRoad, que se lee arriba y se
    ; recalcula mas abajo en esta misma rutina.
    lda pitCommitted
    beq @nopitclamp
    lda spdHi
    cmp #>PIT_CAP
    bcc @nopitclamp
    bne @pitclampgo
    lda spdLo
    cmp #<PIT_CAP
    bcc @nopitclamp
@pitclampgo:
    ; se excedio del limite: penalidad, una sola vez por parada
    lda pitPenalized
    bne @noclampsecs
    lda #1
    sta pitPenalized
    lda penaltySecs
    clc
    adc #PIT_PENALTY_SECS
    sta penaltySecs
@noclampsecs:
    lda #>PIT_CAP
    sta spdHi
    lda #<PIT_CAP
    sta spdLo
@nopitclamp:

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
    ; Limites de pantalla. Por la derecha no se llega hasta el borde: el auto
    ; tiene que quedar afuera de la franja del panel de datos (HUD_X).
    lda playerX
    cmp #8
    bcs :+
    lda #8
    sta playerX
:   lda playerX
    cmp #HUD_X-16
    bcc :+
    lda #HUD_X-16
    sta playerX
:
    ; fuera de pista? El circuito se corre, asi que el borde no es fijo: hay
    ; que mirar donde esta el asfalto a la altura del auto.
    lda #0
    sta offRoad
    sta offRoadBad
    jsr PlayerShift
    sta tmp3
    lda playerX
    sec
    sbc tmp3                ; llevar el auto al marco del circuito recto
    sta tmp4                ; X del auto en coordenadas de pista
    cmp #ROAD_L
    bcc @off
    cmp #ROAD_R+1
    bcc @dentro
@off:
    lda #1
    sta offRoad
    sta lapOffRoad          ; se resetea en WearTick, una vez por vuelta

    ; Salida FRANCA, la que anula la vuelta de qualy. offRoad marca "una rueda
    ; afuera" (basta que se pase el borde del auto); la regla habla de las
    ; cuatro ruedas, asi que aca se mira el CENTRO del auto contra el asfalto.
    lda tmp4
    clc
    adc #8                  ; centro del auto, que mide 16 px de ancho
    cmp #ROAD_L
    bcc @bad
    cmp #ROAD_R+16
    bcc @dentro
@bad:
    lda #1
    sta offRoadBad
@dentro:
    ; boxes: franja de pit lane (piano derecho durante la ventana, ver
    ; BuildRow/PitWindowActive), en el mismo marco recto que tmp4. inPit es
    ; del cuadro actual; pitCommitted queda prendido el resto de la ventana
    ; apenas se toca la franja una vez (y se resetea recien cuando la
    ; ventana termina, junto con pitPenalized).
    jsr PitWindowActive
    sta tmp1
    lda #0
    sta inPit
    lda tmp1
    beq @winoff
    lda tmp4
    cmp #PIT_LANE_L
    bcc @rtspit
    cmp #PIT_LANE_R
    bcs @rtspit
    lda #1
    sta inPit
    sta pitCommitted
    lda #0
    sta offRoad              ; el pit lane es un camino legitimo, no cuenta
    sta offRoadBad           ; como salida de pista (ni penaliza ni desgasta)
    jmp @rtspit
@winoff:
    lda #0
    sta pitCommitted
    sta pitPenalized
    sta pitMenuShown
@rtspit:
    rts

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

    ; ventana de boxes activa para ESTA fila? (ver PitWindowActive). Se
    ; calcula una sola vez por fila, no por columna.
    jsr PitWindowActive
    sta tmp1

    ldx #0                  ; columna
@col:
    txa
    sec
    sbc genCC
    clc
    adc #TRACK_HW
    cmp #2*TRACK_HW         ; e >= 16: se paso del circuito (o quedo negativo,
    bcs @outside            ; que envuelve por arriba). Grava o pasto.
    cmp #2
    bcc @curb
    cmp #2*TRACK_HW-2
    bcs @curbR
    cmp #TRACK_HW-1         ; la raya del medio
    bne @road
    lda genRow              ; la raya del medio va cortada
    and #1
    bne @road
    lda #T_DASH
    bne @put                ; siempre: T_DASH != 0
@road:
    lda #T_ROAD
    bne @put
; piano DERECHO (e=14,15): durante la ventana de boxes es la franja de pit
; lane en vez de piano normal (sigue en @gravelR mas abajo, e=16,17: las
; cuatro columnas juntas). El izquierdo (e=0,1) nunca lo es: los boxes son
; de un solo lado.
@curbR:
    lda tmp1
    beq @curb
    lda genRow
    and #1
    beq @pitA
    lda #T_PIT_B
    bne @put
@pitA:
    lda #T_PIT_A
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
    cmp #2*TRACK_HW+2
    bcc @gravelR            ; e = 16,17 -> grava del lado derecho (o boxes)
    cmp #254
    bcs @gravel             ; e = 254,255 (o sea -2,-1) -> grava del izquierdo,
    jmp @grass               ; esa nunca es pit lane: los boxes son de un lado
; grava derecha (e=16,17): durante la ventana de boxes tambien es pit lane,
; junto con el piano derecho (@curbR). Las cuatro columnas juntas (14-17) se
; leen como un carril propio y ancho, no como el piano de siempre con otro
; color -- separado de la pista, no parte de ella.
@gravelR:
    lda tmp1
    beq @gravel
    lda genRow
    and #1
    beq @pitgA
    lda #T_PIT_B
    bne @put
@pitgA:
    lda #T_PIT_A
    bne @put
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
; Recorrido del centro, arrancando y terminando en TRACK_CC (12) para que el
; lazo cierre sin salto: 12 -> 16 -> 8 -> 12 -> 8 -> 12.
segLen:   .byte 12,  2,  8,  4,  8,  2, 10,  2,  6,  2
segDelta: .byte  0,  2,  0, $FE, 0,  2,  0, $FE, 0,  2
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
    adc #TRACK_HW           ; e, igual que en BuildRow
    beq @curb               ; e = 0    -> piano izquierdo
    cmp #2*TRACK_HW-2
    beq @curb               ; e = 14   -> piano derecho
    cmp #2*TRACK_HW-3
    bcs @grass              ; e > 13 (o negativo, que envuelve alto)
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
; Cuatro carriles en los 96 px de asfalto (x 48..143 en coordenadas de
; pista), en dos pares separados por un hueco central de 36 px. El auto va
; SIEMPRE derecho por PLAYER_X0 (87, el medio geometrico de la pista) salvo
; que lo corras vos: si un carril quedara a menos de 13 px de ahi (el radio
; del choque), ir derecho por el medio de la pista chocaria SIEMPRE contra
; cualquiera que este en ese carril -- el centro tiene que ser la linea mas
; segura, no un iman. Los cuatro quedan a 17 px o mas de PLAYER_X0.
laneX:
    .byte 52, 68, 104, 120

; Recorre los 21 IA por INDICE, no por puesto: con el peloton compacto (los
; ritmos quedaron a proposito muy juntos, ver teamPaceLoTab) puede haber mas
; de MAX_CARS a la vez dentro de pantalla, y barrer solo una ventana de
; puestos cercanos al del jugador se salteaba autos que si estaban en rango
; -- se vio jugando, con carCount por debajo de lo que de verdad habia en
; pantalla. Ahora se prueban los 22 y, cuando el cupo esta lleno, un
; candidato nuevo desplaza al que este mas lejos del centro (Y=PLAYER_Y) si
; el candidato esta mas cerca. Siempre quedan dibujados los MAX_CARS mas
; cercanos de verdad, sin importar cuantos haya alrededor.
BuildCars:
    lda #0
    sta carCount
    ldx #0
@scan:
    cpx #PLAYER_SLOT
    bne :+
    jmp @next                 ; al jugador lo dibuja BuildOAM aparte
:
    ; y = PLAYER_Y - (total[x] - total[jugador]), en 16 bits
    lda totalLo,x
    sec
    sbc plyTotalLo
    sta tmp1
    lda totalHi,x
    sbc plyTotalHi
    sta tmp2

    lda #PLAYER_Y
    sec
    sbc tmp1
    sta tmp3                  ; candidato: y de pantalla
    lda #0
    sbc tmp2
    beq :+
    jmp @next                 ; y no entra en un byte -> fuera de pantalla
:   lda tmp3
    cmp #240
    bcc :+
    jmp @next                 ; abajo del borde inferior
:

    ; distancia del candidato al centro de la pantalla (a mayor distancia,
    ; mas facil de sacrificar si el cupo esta lleno)
    lda tmp3
    sec
    sbc #PLAYER_Y
    bcs @posdist
    eor #$FF
    clc
    adc #1
@posdist:
    sta tmp4

    lda carCount
    cmp #MAX_CARS
    bcc @append

    ; cupo lleno: buscar el que este MAS LEJOS de los MAX_CARS actuales
    ldy #0
    lda carY,y
    sec
    sbc #PLAYER_Y
    bcs :+
    eor #$FF
    clc
    adc #1
:   sta tmp5                  ; tmp5 = peor distancia vista hasta ahora
    sty tmp6                  ; tmp6 = indice de ese slot
    iny
@worse:
    cpy #MAX_CARS
    beq @gotworst
    lda carY,y
    sec
    sbc #PLAYER_Y
    bcs :+
    eor #$FF
    clc
    adc #1
:   cmp tmp5
    bcc @notworse
    sta tmp5
    sty tmp6
@notworse:
    iny
    jmp @worse
@gotworst:
    lda tmp4
    cmp tmp5
    bcs @next                 ; el candidato no mejora al peor actual: afuera
    ldy tmp6                  ; reemplaza ese slot
    jmp @store

@append:
    ldy carCount
    inc carCount

@store:
    stx tmp5                  ; guardar el indice de piloto: X se va a pisar
    lda tmp3
    sta carY,y
    lda tmp5
    sta carDrv,y
    and #3
    tax
    lda laneX,x
    sta carX,y
    ldx tmp5
    lda pilotTeam,x
    and #1
    clc
    adc #1                    ; paletas de sprite 1 o 2 (la 0 es del jugador)
    sta carPal,y
    ldx tmp5                  ; restaurar X: es el contador del scan principal
@next:
    inx
    cpx #NUM_DRIVERS
    beq @done
    jmp @scan
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
    lda #1
    sta lapCrash             ; se resetea en WearTick, una vez por vuelta
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
;=============================================================================
; GOMAS
;=============================================================================

; tireCompound/tireWear -> curCapHi/Lo. Se llama al arrancar la carrera
; (StartRace) y al cerrar cada vuelta (WearTick): nunca por cuadro, la banda
; de desgaste cambia como mucho una vez por vuelta.
RecalcCap:
    lda tireWear
    cmp #50
    bcc @b0
    lda tireWear
    cmp #75
    bcc @b1
    lda tireWear
    cmp #90
    bcc @b2
    lda tireWear
    cmp #100
    bcc @b3
    lda #4
    jmp @have
@b0:
    lda #0
    jmp @have
@b1:
    lda #1
    jmp @have
@b2:
    lda #2
    jmp @have
@b3:
    lda #3
@have:
    sta tmp1                 ; banda 0-4
    lda tireCompound
    asl a
    asl a                    ; *4
    clc
    adc tireCompound         ; *5
    clc
    adc tmp1                 ; + banda = indice en capTabLo/Hi
    tax
    lda capTabLo,x
    sta curCapLo
    lda capTabHi,x
    sta curCapHi

    ; ajuste de ala (etapa 3, EnterPitMenu): +1 es MAS ala, achica el tope;
    ; -1 es MENOS ala, lo agranda. Simplificacion deliberada -- el motor no
    ; distingue "estoy en una curva" de "estoy en una recta" (genCC se
    ; corre continuo, sin ese evento), asi que el ala no le da mas agarre
    ; SOLO en curva como en las reglas: es un ajuste parejo todo el tiempo.
    lda wingLevel
    beq @rts
    bmi @menosala
    lda curCapLo
    sec
    sbc #<WING_STEP
    sta curCapLo
    lda curCapHi
    sbc #>WING_STEP
    sta curCapHi
    jmp @clampcap
@menosala:
    lda curCapLo
    clc
    adc #<WING_STEP
    sta curCapLo
    lda curCapHi
    adc #>WING_STEP
    sta curCapHi
@clampcap:
    lda curCapHi
    bpl @rts                 ; se fue a negativo (mas ala con desgaste ya
    lda #0                   ; alto): pisar el piso en 0, no envolver
    sta curCapHi
    sta curCapLo
@rts:
    rts

; Una vez por vuelta (UpdateDistance, rama @lap). Sube tireWear segun el
; compuesto (WEAR_SOFT/MED/HARD) mas un bonus fijo por cada evento de "al
; limite" ocurrido en la vuelta que se cierra: salida de pista (lapOffRoad,
; que en esta geometria ya incluye el contacto con el piano -- ver ColPal:
; el piano cae fuera de ROAD_L..ROAD_R igual que el pasto, asi que no hace
; falta un chequeo aparte), un choque (lapCrash) o una frenada fuerte a alta
; velocidad (lapHardBrake). Termina recalculando el tope de velocidad.
WearRateTab: .byte WEAR_SOFT, WEAR_MED, WEAR_HARD

WearTick:
    ldx tireCompound
    lda WearRateTab,x
    sta tmp1
    lda lapOffRoad
    beq :+
    lda tmp1
    clc
    adc #WEAR_BONUS_OFFROAD
    sta tmp1
:   lda lapCrash
    beq :+
    lda tmp1
    clc
    adc #WEAR_BONUS_CRASH
    sta tmp1
:   lda lapHardBrake
    beq :+
    lda tmp1
    clc
    adc #WEAR_BONUS_BRAKE
    sta tmp1
:   lda lapErsAbuse
    beq :+
    lda tmp1
    clc
    adc #ERS_WEAR_BONUS
    sta tmp1
:   lda tireWear
    clc
    adc tmp1
    cmp #100
    bcc :+
    lda #100
:   sta tireWear
    lda #0
    sta lapOffRoad
    sta lapCrash
    sta lapHardBrake
    sta lapErsAbuse
    jmp RecalcCap             ; termina con el rts de RecalcCap

;=============================================================================
; BOXES
;=============================================================================

; A = 1 si distLo/Hi cae en la ventana de boxes (los ultimos PIT_ENTRY_LEN
; del final de la vuelta, o los primeros PIT_EXIT_LEN de la siguiente),
; A = 0 si no. La usan BuildRow (para dibujar la franja) y UpdatePlayer
; (para decidir inPit/pitCommitted): una sola cuenta, no dos copias.
PitWindowActive:
    lda distHi
    cmp #>(LAP_LEN-PIT_ENTRY_LEN)
    bcc @chk2
    bne @yes
    lda distLo
    cmp #<(LAP_LEN-PIT_ENTRY_LEN)
    bcc @chk2
@yes:
    lda #1
    rts
@chk2:
    lda distHi
    bne @no
    lda distLo
    cmp #PIT_EXIT_LEN
    bcs @no
    lda #1
    rts
@no:
    lda #0
    rts

; Sortea la vuelta de parada de cada IA (3..TOTAL_LAPS-2, ver
; PIT_STOP_LAP_COUNT). Se llama una vez por carrera, desde StartRace.
AssignAIPitLaps:
    ldx #0
@lp:
    cpx #PLAYER_SLOT
    beq @next
    jsr Rand
    lda seed
    and #$1F                 ; achicar el rango antes de la resta repetida
@mod:
    cmp #PIT_STOP_LAP_COUNT
    bcc @done
    sec
    sbc #PIT_STOP_LAP_COUNT
    jmp @mod
@done:
    clc
    adc #3
    sta pitStopLap,x
@next:
    inx
    cpx #NUM_DRIVERS
    bne @lp
    rts

; Se llama en UpdateDistance, rama @lap, justo despues de "inc lapNum": a
; cada IA cuya pitStopLap coincida con la vuelta que recien arranca le resta
; AI_PITSTOP_LOSS de su acumulador de distancia. Como lapNum solo crece y
; pitStopLap es fijo para toda la carrera, cada IA coincide una sola vez.
ApplyAIPitStops:
    ldx #0
@lp:
    cpx #PLAYER_SLOT
    beq @next
    lda pitStopLap,x
    cmp lapNum
    bne @next
    sec
    lda totalLo,x
    sbc #<AI_PITSTOP_LOSS
    sta totalLo,x
    lda totalHi,x
    sbc #>AI_PITSTOP_LOSS
    sta totalHi,x
    bcs @next                ; sin underflow: listo
    lda #0                   ; se fue negativo (poca distancia acumulada
    sta totalLo,x            ; todavia): pisar el piso en 0
    sta totalHi,x
@next:
    inx
    cpx #NUM_DRIVERS
    bne @lp
    rts

;=============================================================================
; ERS
;=============================================================================

; Carga: frenando y girando en curva (mas si esta cerrada), frenando sin
; girar en recta, o rebufo (se suma a lo de arriba, no lo reemplaza). Nada
; carga fuera de pista ni trompeando. Se llama desde RaceLogic DESPUES de
; BuildCars: necesita carX/Y/Drv/Count ya armados para el rebufo.
UpdateERS:
    lda offRoad
    beq :+
    jmp @rts
:   lda crashT
    beq :+
    jmp @rts
:

    ; fila del jugador en el buffer circular de 60 (misma cuenta que
    ; ShiftAtY, pero hace falta el INDICE, no el corrimiento en pixeles)
    lda #(PLAYER_Y>>3)
    clc
    adc topRow
    cmp #60
    bcc :+
    sbc #60
:   sta tmp1

    ; cuanto se corrio el centro contra 8 filas atras (un bloque de
    ; atributos): el absoluto es "lo cerrada" que esta la curva aca, sin
    ; necesitar un evento de "entrando/saliendo de curva" que el motor no
    ; tiene (ver ERS_CHARGE_CURVE_BASE mas arriba)
    lda tmp1
    sec
    sbc #8
    bcs :+
    clc
    adc #60
:   tax
    lda rowCC,x
    sta tmp2
    ldx tmp1
    lda rowCC,x
    sec
    sbc tmp2
    bcs :+
    eor #$FF
    clc
    adc #1
:   sta tmp3                  ; tmp3 = curvatura aca (0 = recta)

    lda #0
    sta tmp4                  ; acumulador de carga este cuadro

    lda pad1
    and #BTN_B
    beq @chkslip               ; no frena: no carga por curva ni por recta
    lda pad1
    and #(BTN_LEFT|BTN_RIGHT)
    beq @straightchg
    lda #ERS_CHARGE_CURVE_BASE ; --- curva: base + lo cerrada que este ---
    clc
    adc tmp3
    sta tmp4
    jmp @chkslip
@straightchg:
    lda #ERS_CHARGE_STRAIGHT
    sta tmp4

@chkslip:
    ; --- rebufo: algun auto de carX/Y adelante y alineado? tmp1/tmp2/tmp3
    ; ya no hacen falta (curvatura ya se uso), quedan libres. Sin velocidad
    ; real no hay rebufo (a velocidad 0 no hay estela que aproveche) -- si
    ; no, con varios autos alrededor la ventana Y/X cae siempre en alguno y
    ; carga aunque el auto este parado en la largada.
    lda spdHi
    bne :+
    jmp @apply
:   lda carCount
    beq @apply
    jsr PlayerShift
    sta tmp1
    lda playerX
    sec
    sbc tmp1
    sta tmp1                  ; jugador en coordenadas de pista
    ldx #0
@slp:
    lda carY,x
    cmp #PLAYER_Y-SLIP_Y_MAX
    bcc @slpnext               ; mas alla del rango de rebufo: no cuenta
    cmp #PLAYER_Y-SLIP_Y_MIN+1
    bcs @slpnext               ; muy cerca (zona de choque) o detras
    lda tmp1
    sec
    sbc carX,x
    bcs :+
    eor #$FF
    clc
    adc #1
:   cmp #SLIP_X_TOL
    bcs @slpnext
    lda tmp4
    clc
    adc #ERS_CHARGE_SLIP
    sta tmp4
    jmp @apply                 ; alcanza con uno: no acumular varios rebufos
@slpnext:
    inx
    cpx carCount
    bne @slp

@apply:
    lda tmp4
    beq @rts
    clc
    adc ersEnergy
    cmp #ERS_MAX+1
    bcc :+
    lda #ERS_MAX
:   sta ersEnergy
@rts:
    rts

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
    jsr WearTick
    jsr ApplyAIPitStops
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
; LARGADA PARADA
;
; El jugador arranca detenido y su distancia crece con spdHi, que es la parte
; ENTERA de la velocidad: durante los primeros 85 cuadros va 0, 1, 2 y 3, o
; sea que acumula 127 unidades donde a fondo acumularia 340. La IA no tiene
; modelo de aceleracion: sin esto saldria a ritmo pleno desde el primer cuadro
; y le sacaria unos 6 puestos al jugador en la largada, borrando justo lo que
; la qualy acababa de decidir.
;
; Asi que durante la rampa la IA usa launchSpd en vez de AIPACE_HI, y
; launchSpd sube de a uno cada LAUNCH_STEP cuadros: exactamente la misma curva
; que sigue el spdHi del jugador. Todos aceleran igual y las diferencias de
; ritmo recien pesan cuando el peloton ya esta lanzado.
LAUNCH_STEP = 21            ; 256/12, los cuadros que tarda spdHi en subir uno

UpdateAI:
    lda startRamp
    beq @full
    dec startRamp
    inc launchTick
    lda launchTick
    cmp #LAUNCH_STEP
    bcc @full
    lda #0
    sta launchTick
    inc launchSpd
@full:
    ldx #0
@lp:
    cpx #PLAYER_SLOT
    beq @next                ; el jugador se sincroniza aparte, no aca
    lda teamPaceLo,x
    sta tmp1                 ; ritmo de este cuadro, antes de defender

    ; Lo tenes encima? Si la diferencia de distancia contra el jugador entra
    ; en +-DEFEND_RANGE, el rival se pone a defender y aprieta segun su
    ; habilidad. Es lo que hace que un Verstappen te pelee el paso y un
    ; colista no. Vale para los dos lados: si lo pasaste, te lo devuelve.
    lda totalLo,x
    sec
    sbc plyTotalLo
    sta tmp2
    lda totalHi,x
    sbc plyTotalHi
    beq @adelante            ; alto 0 -> el rival te saca poco
    cmp #$FF
    bne @sinpelea            ; ni 0 ni -1 -> esta lejos, ni se entera
    lda tmp2                 ; alto $FF -> lo tenes adelante por poco
    cmp #256-DEFEND_RANGE
    bcs @pelea
    bcc @sinpelea
@adelante:
    lda tmp2
    cmp #DEFEND_RANGE
    bcs @sinpelea
@pelea:
    lda tmp1
    clc
    adc defBonus,x
    sta tmp1
    ; ERS: si le queda energia, la usa para defender un poco mas. Version
    ; bien abstraida (ver AI_ERS_BONUS mas arriba): no simula "esta en una
    ; recta", alcanza con que este defendiendo.
    lda aiErs,x
    beq @sinpelea
    sec
    sbc #AI_ERS_DRAIN
    bcs :+
    lda #0
:   sta aiErs,x
    lda tmp1
    clc
    adc #AI_ERS_BONUS
    sta tmp1
@sinpelea:
    ; Mientras dura la largada la IA acelera con launchSpd y NADA MAS: sin su
    ; fraccion de ritmo, igual que el jugador, que en esos cuadros solo suma
    ; la parte entera de su velocidad. Si se le dejara la fraccion, el mejor
    ; rival sacaria ~65 unidades (casi 3 puestos) nada mas que por arrancar.
    lda startRamp
    beq @normal
    lda #0
    sta tmp1                 ; sin fraccion durante la largada
    lda launchSpd
    jmp @sumar
@normal:
    lda #AIPACE_HI
@sumar:
    sta tmp2
    lda paceFrac,x
    clc
    adc tmp1
    sta paceFrac,x           ; el acarreo de esta suma es lo que se usa abajo
    lda totalLo,x
    adc tmp2                 ; parte entera + el acarreo de paceFrac
    sta totalLo,x
    lda totalHi,x
    adc #0
    sta totalHi,x
@next:
    inx
    cpx #NUM_DRIVERS
    bne @lp
@rts:
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
    cmp #30                   ; clamp al rango real de la tabla (38..198)
    bcs :+
    lda #30
:   cmp #211
    bcc :+
    lda #210
:   sta teamPaceLo,x
    ; ERS: recarga fija por vuelta del jugador (misma simplificacion de
    ; arriba: no hay una vuelta real por IA para engancharse)
    lda aiErs,x
    clc
    adc #AI_ERS_RECHARGE
    cmp #101
    bcc :+
    lda #100
:   sta aiErs,x
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

;=============================================================================
; MENU DE PARADA (boxes, fase 4 etapa 3)
;
; Mismo patron que EnterClass/ClassLogic/ExitClass: pausa la carrera,
; reusa las nametables del circuito con el rendering apagado, y al salir
; hay que reconstruir el trazado real (RedrawTrack) porque si no el
; circuito curvo queda roto.
;=============================================================================
pitmenutxt: .byte "BOXES", 0

pmGoma0: .byte "  GOMA: BLANDO", 0
pmGoma1: .byte "  GOMA: MEDIO ", 0
pmGoma2: .byte "  GOMA: DURO  ", 0
pmGomaPtrLo: .byte <pmGoma0, <pmGoma1, <pmGoma2
pmGomaPtrHi: .byte >pmGoma0, >pmGoma1, >pmGoma2

pmAlaM1: .byte "  ALA: -1", 0
pmAla0:  .byte "  ALA:  0", 0
pmAlaP1: .byte "  ALA: +1", 0
pmAlaPtrLo: .byte <pmAlaM1, <pmAla0, <pmAlaP1
pmAlaPtrHi: .byte >pmAlaM1, >pmAla0, >pmAlaP1

pmHint: .byte "SUBE/BAJA ELIGE - START OK", 0

; menuWing (0/1/2) -> wingLevel real (con signo)
WingValTab: .byte $FF, 0, 1

EnterPitMenu:
    lda scrollLo
    sta savedScrollLo
    lda scrollNT
    sta savedScrollNT
    lda #0
    sta scrollLo
    sta scrollNT

    jsr RenderOff

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

    lda #<pitmenutxt
    sta ptr
    lda #>pitmenutxt
    sta ptr+1
    lda #$2C
    sta tmp3
    lda #$20
    sta tmp4
    jsr DrawText

    lda #<pmHint
    sta ptr
    lda #>pmHint
    sta ptr+1
    lda #12
    jsr SetClassAddr
    lda tmp3
    clc
    adc #1
    sta tmp3
    jsr DrawText

    ; valores iniciales del menu = los que ya tiene el auto
    lda tireCompound
    sta menuCompound
    lda wingLevel
    beq @widx1
    bmi @widx0
    ldx #2
    jmp @wdone
@widx0:
    ldx #0
    jmp @wdone
@widx1:
    ldx #1
@wdone:
    stx menuWing
    lda #0
    sta pitCursor

    jsr DrawPitMenu

    ldx #0
    lda #$FF
:   sta oam,x
    inx
    bne :-

    lda #ST_PITMENU
    sta gameState
    jsr RenderOn
    rts

; Redibuja las dos filas del menu y su cursor. Necesita el rendering
; apagado -- EnterPitMenu ya lo deja asi, y PitMenuLogic lo apaga/prende a
; mano alrededor de cada llamada (mismo patron que DrawGomaLine/GridLogic
; en la parrilla).
DrawPitMenu:
    lda #6                   ; cursor de GOMA
    jsr SetClassAddr
    lda tmp3
    clc
    adc #5
    sta tmp3
    bit PPUSTATUS
    lda tmp4
    sta PPUADDR
    lda tmp3
    sta PPUADDR
    lda pitCursor
    bne @nogc
    lda #'>'
    bne @putgc
@nogc:
    lda #' '
@putgc:
    sta PPUDATA

    lda #6                   ; texto de GOMA
    jsr SetClassAddr
    lda tmp3
    clc
    adc #6
    sta tmp3
    ldx menuCompound
    lda pmGomaPtrLo,x
    sta ptr
    lda pmGomaPtrHi,x
    sta ptr+1
    jsr DrawText

    lda #8                   ; cursor de ALA
    jsr SetClassAddr
    lda tmp3
    clc
    adc #5
    sta tmp3
    bit PPUSTATUS
    lda tmp4
    sta PPUADDR
    lda tmp3
    sta PPUADDR
    lda pitCursor
    beq @noac
    lda #'>'
    bne @putac
@noac:
    lda #' '
@putac:
    sta PPUDATA

    lda #8                   ; texto de ALA
    jsr SetClassAddr
    lda tmp3
    clc
    adc #6
    sta tmp3
    ldx menuWing
    lda pmAlaPtrLo,x
    sta ptr
    lda pmAlaPtrHi,x
    sta ptr+1
    jsr DrawText
    rts

; Sortea cuanto dura la parada: base PIT_STOP_BASE, con ~1/8 de chance de
; una parada lenta (PIT_STOP_SLOW_ADD + azar(0..127), unos 5 a 7 segundos
; mas). La probabilidad "chica" que piden las reglas.
ApplyPitStop:
    jsr Rand
    lda seed
    and #7
    bne @normal
    jsr Rand
    lda seed
    and #$7F
    clc
    adc #<PIT_STOP_SLOW_ADD
    sta pitTimerLo
    lda #0
    adc #>PIT_STOP_SLOW_ADD
    sta pitTimerHi
    rts
@normal:
    lda #<PIT_STOP_BASE
    sta pitTimerLo
    lda #>PIT_STOP_BASE
    sta pitTimerHi
    rts

; Resta 1 a pitTimerLo/Hi (16 bits). Se llama una vez por cuadro mientras
; la parada dura, nunca lo deja bajar de 0 porque RaceLogic corta el
; llamado apenas llega.
DecPitTimer:
    lda pitTimerLo
    bne @lo
    dec pitTimerHi
@lo:
    dec pitTimerLo
    rts

ExitPitMenu:
    ; aplicar la goma elegida: gomas nuevas, se resetea el desgaste y se
    ; marca el compuesto como usado (regla de los dos compuestos)
    lda menuCompound
    sta tireCompound
    lda #0
    sta tireWear
    lda #1
    ldx tireCompound
    beq @gotbit
@shl:
    asl a
    dex
    bne @shl
@gotbit:
    ora usedMask
    sta usedMask
    ; aplicar el ala
    ldx menuWing
    lda WingValTab,x
    sta wingLevel
    jsr RecalcCap
    jsr ApplyPitStop

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

PitMenuLogic:
    lda padNew
    and #BTN_UP
    beq @nodown
    lda pitCursor
    eor #1
    sta pitCursor
    jmp @redraw
@nodown:
    lda padNew
    and #BTN_DOWN
    beq @noup
    lda pitCursor
    eor #1
    sta pitCursor
    jmp @redraw
@noup:
    lda padNew
    and #BTN_LEFT
    beq @noleft
    lda pitCursor
    bne @alaleft
    lda menuCompound
    bne @gdec
    lda #2
    sta menuCompound
    jmp @redraw
@gdec:
    dec menuCompound
    jmp @redraw
@alaleft:
    lda menuWing
    bne @wdec
    lda #2
    sta menuWing
    jmp @redraw
@wdec:
    dec menuWing
    jmp @redraw
@noleft:
    lda padNew
    and #BTN_RIGHT
    beq @noright
    lda pitCursor
    bne @alaright
    lda menuCompound
    cmp #2
    bne @ginc
    lda #0
    sta menuCompound
    jmp @redraw
@ginc:
    inc menuCompound
    jmp @redraw
@alaright:
    lda menuWing
    cmp #2
    bne @winc
    lda #0
    sta menuWing
    jmp @redraw
@winc:
    inc menuWing
@redraw:
    jsr Blip
    jsr RenderOff
    jsr DrawPitMenu
    jsr RenderOn
@noright:
    lda padNew
    and #BTN_START
    beq :+
    jsr Blip
    jsr ExitPitMenu
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

    ; boxes: sumar las penalidades (exceder el limite del pit lane) antes de
    ; mostrar el tiempo, no despues -- mins/secs tienen que reflejarlas.
    lda penaltySecs
    beq @nopenalty
    lda secs
    clc
    adc penaltySecs
    sta secs
@wrapmin:
    lda secs
    cmp #60
    bcc @nopenalty
    sec
    sbc #60
    sta secs
    inc mins
    jmp @wrapmin
@nopenalty:

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

    ; regla de los dos compuestos (docs/reglas-juego.md seccion 5): si
    ; usedMask tiene un solo bit prendido, no se cumplio.
    lda usedMask
    cmp #1
    beq @dq
    cmp #2
    beq @dq
    cmp #4
    beq @dq
    jmp @nodq
@dq:
    bit PPUSTATUS
    lda #$22
    sta PPUADDR
    lda #$46
    sta PPUADDR
    lda #<dqtxt
    sta ptr
    lda #>dqtxt
    sta ptr+1
    jsr DrawText
@nodq:

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
    jsr BuildHudErs
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
    ldx #HUD_X
    ldy #8
    jsr PutChar
    lda lapNum
    clc
    adc #'0'
    ldx #HUD_X+8
    ldy #8
    jsr PutChar
    lda #'/'
    ldx #HUD_X+16
    ldy #8
    jsr PutChar
    lda #'0'+TOTAL_LAPS
    ldx #HUD_X+24
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
    ldx #HUD_X
    ldy #24
    jsr PutChar
    lda dig1
    clc
    adc #'0'
    ldx #HUD_X+8
    ldy #24
    jsr PutChar
    lda dig0
    clc
    adc #'0'
    ldx #HUD_X+16
    ldy #24
    jsr PutChar
    rts

; --- puesto, "P08". Cada dato en su propia fila del panel: asi ninguna
; scanline junta mas de 6 sprites del HUD y quedan dos libres para el auto
; que pueda caer a esa altura, sin pasarse de los 8 por linea.
BuildHudRow2:
    lda #'P'
    ldx #HUD_X
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
    ldx #HUD_X+8
    ldy #16
    jsr PutChar
    lda dig0
    clc
    adc #'0'
    ldx #HUD_X+16
    ldy #16
    jsr PutChar
    rts

; --- energia de ERS, "E:100" (fase 5). Y=32: libre entre la velocidad
; (Y=24) y la ventana de posiciones (Y=48 en adelante), sin compartir
; scanline con ninguna de las dos.
BuildHudErs:
    lda #'E'
    ldx #HUD_X
    ldy #32
    jsr PutChar
    lda #':'
    ldx #HUD_X+8
    ldy #32
    jsr PutChar
    lda ersEnergy
    sta numLo
    lda #0
    sta numHi
    jsr ToDigits
    lda dig2
    clc
    adc #'0'
    ldx #HUD_X+16
    ldy #32
    jsr PutChar
    lda dig1
    clc
    adc #'0'
    ldx #HUD_X+24
    ldy #32
    jsr PutChar
    lda dig0
    clc
    adc #'0'
    ldx #HUD_X+32
    ldy #32
    jsr PutChar
    rts

rankY: .byte RANK_Y, RANK_Y+RANK_SEP, RANK_Y+2*RANK_SEP

; Ventana movil de 3 lineas: el que tenes adelante, vos, y el que tenes
; atras. Es la informacion que de verdad sirve manejando: contra quien estas
; peleando.
;
; Formato "!07GAS", 6 sprites justos, que es lo que entra en el panel (de
; HUD_X al borde hay 6 columnas ocultando ademas el borde con overscan). El
; "P" de "P07" se fue: el numero solo ya se entiende, y ese sprite era el que
; no dejaba entrar el codigo. La linea del jugador no tiene paleta libre para
; resaltarse con color (las 4 estan asignadas), asi que lleva el '!'.
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

    ; Los tiles de la fuente estan rellenos de negro, asi que los caracteres
    ; van PEGADOS de a 8 px: cualquier hueco dejaria ver la pista en el medio
    ; de la barra. El separador es un espacio de verdad (que ahora es un tile
    ; negro solido), no un salto en X.
    lda #RANK_X
    sta rankX

    lda rankStart            ; marcador del jugador; los demas llevan espacio,
    clc                      ; asi las tres lineas arrancan alineadas
    adc rankLine
    cmp rankOf+PLAYER_SLOT
    bne :+
    lda #'!'
    bne @mark                ; siempre: '!' != 0
:   lda #' '
@mark:
    jsr RankPut

    lda dig1
    clc
    adc #'0'
    jsr RankPut
    lda dig0
    clc
    adc #'0'
    jsr RankPut

    ldx rankDrv
    lda pilotCode0,x
    jsr RankPut
    ldx rankDrv
    lda pilotCode1,x
    jsr RankPut
    ldx rankDrv
    lda pilotCode2,x
    jsr RankPut

    inc rankLine
    lda rankLine
    cmp #RANK_LINES
    beq @done
    jmp @line                ; bne no llega: el cuerpo del loop es largo
@done:
    rts

; A = caracter. Lo dibuja en la posicion actual de la linea y avanza un tile.
RankPut:
    ldx rankX
    ldy rankScrY
    jsr PutChar
    lda rankX
    clc
    adc #8
    sta rankX
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
txt7: .byte "6 VUELTAS", 0
txt8: .byte "ARRIBA PARA EL TURBO", 0

titlePtrLo: .byte <txt1, <txt2, <txt3, <txt7, <txt4, <txt5, <txt6, <txt8
titlePtrHi: .byte >txt1, >txt2, >txt3, >txt7, >txt4, >txt5, >txt6, >txt8
; direcciones PPU (fila*32 + col + $2000)
titleAddrLo: .byte $88, $28, $6B, $0C, $CC, $4A, $89, $AA
titleAddrHi: .byte $20, $21, $21, $22, $22, $23, $23, $23

etxt1: .byte "FIN DE CARRERA", 0
etxt2: .byte "COLAPINTO EN META", 0
etxt3: .byte "TIEMPO", 0
etxt4: .byte "PRESS START", 0
dqtxt: .byte "DESCALIFICADO: 1 GOMA", 0

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
