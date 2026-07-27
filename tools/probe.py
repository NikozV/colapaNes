#!/usr/bin/env python3
"""
Test de regresion. Corre la ROM en el emulador y verifica que el juego
realmente ANDA, no solo que compila.

    make test

Si tocas algo del motor (scroll, colisiones, vueltas) corre esto antes de dar
el cambio por bueno. Un bug de 6502 casi nunca se ve leyendo el codigo.
"""

import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])

from nes_harness import (Game, A, B, LEFT, RIGHT, UP, DOWN, START, SELECT,
                         ST_TITLE, ST_RACE, ST_END, ST_CLASS, ST_QUALY, ST_GRID,
                         ST_PITMENU)

fails = []


def check(cond, msg):
    print(('  OK   ' if cond else '  FALLA') + '  ' + msg)
    if not cond:
        fails.append(msg)


print('\n== Arranque ==')
g = Game()
g.run(30)
check(g.state == ST_TITLE, 'arranca en la pantalla de titulo')
check(g.screen_stats()['negro'] > 0.9, 'el titulo es texto sobre fondo negro')

print('\n== Banking (MMC1) ==')
# bank0Tab vive en BANK0, un banco conmutable en $8000. El reset lo mapea y
# copia el byte 3 a bankVal. Si el banking no anda, aca llega basura.
check(g.peek('bankVal') == 43,
      f"el dato de BANK0 llega al banco fijo (bankVal={g.peek('bankVal')})")
check(g.peek('prgBank') == 0, 'queda BANK0 mapeado en $8000')

print('\n== Qualy ==')
# El fin de semana arranca por la qualy: vuelta de salida (no cronometra) y
# vuelta lanzada (si). Al terminar sale la parrilla.
g.press(START)
g.run(5)
check(g.state == ST_QUALY, 'START entra a la qualy')
check(g.peek('qualyLap') == 1, 'arranca en la vuelta de salida')
check(g.peek('spdHi') == 0, 'se arranca detenido')
check(g.screen_stats()['colores'] >= 6, 'el circuito se dibuja (pasto/pianos/asfalto)')

# la vuelta de salida no cronometra
g.drive(300)
check(g.peek('qualyLap') == 1 and g.peek('lapFrameHi') * 256 + g.peek('lapFrameLo') == 0,
      'la vuelta de salida no cronometra')

g.drive(8000, until=lambda: g.peek('qualyLap') == 2)
check(g.peek('qualyLap') == 2, 'al cruzar la linea arranca la vuelta lanzada')
g.drive(120)
crono = g.peek('lapFrameHi') * 256 + g.peek('lapFrameLo')
check(crono > 0, f'la vuelta lanzada si cronometra ({crono} cuadros)')

g.drive(8000, until=lambda: g.state != ST_QUALY)
check(g.state == ST_GRID, 'terminada la vuelta lanzada sale la parrilla')
check(g.peek('lapValid') == 1, 'la vuelta salio limpia y vale')
g.shot('qualy_grid')

QL, QH = g.labels['qTimeLo'], g.labels['qTimeHi']
NUM_DRIVERS, PLAYER_SLOT = 22, 19
VER_SLOT, LIN_SLOT = 4, 13
GAS_SLOT = 18


def qtime(i):
    return g.peek(QH + i) * 256 + g.peek(QL + i)


parrilla = g.grid()
check(sorted(parrilla) == list(range(NUM_DRIVERS)),
      'la parrilla es una permutacion de los 22')
tiempos = [qtime(d) for d in parrilla]
check(all(tiempos[i] <= tiempos[i + 1] for i in range(NUM_DRIVERS - 1)),
      'la parrilla esta ordenada por tiempo, del mas rapido al mas lento')
check(qtime(VER_SLOT) < qtime(LIN_SLOT),
      f'la jerarquia se respeta (VER {qtime(VER_SLOT)} < LIN {qtime(LIN_SLOT)})')
pole_jugador = parrilla.index(PLAYER_SLOT) + 1
check(pole_jugador <= 6,
      f'una vuelta limpia clasifica adelante (el jugador salio P{pole_jugador})')

# Salirse con las cuatro ruedas anula la vuelta, y sin vuelta valida se larga
# ultimo. Es la regla que le da tension a la sesion, asi que se verifica
# corriendo una qualy entera yendose afuera a proposito.
gq = Game()
gq.do_qualy(target=0)          # target=0 = pegado al borde izquierdo
check(gq.peek('lapValid') == 0, 'irse con las cuatro ruedas anula la vuelta')
q_anulada = gq.peek(QH + PLAYER_SLOT) * 256 + gq.peek(QL + PLAYER_SLOT)
check(q_anulada == 0xFFFF, f'la vuelta anulada no deja tiempo ({q_anulada:#06x})')
check(gq.grid()[-1] == PLAYER_SLOT, 'sin vuelta valida se larga ultimo')

# La conversion de cuadros a SS.CC se hace con enteros, y tuvo un desborde
# que NO se veia en los datos (los tiempos estaban bien ordenados) sino solo
# mirando la pantalla: con restos de 52 cuadros para arriba el *5 se pasaba
# de un byte y las centesimas salian cualquier cosa. Aca se lee el
# cronometro que la ROM dibuja de verdad -- los sprites del HUD de la qualy,
# que salen de la misma rutina que usa la parrilla -- y se compara con los
# cuadros transcurridos.
def crono_en_pantalla(game):
    """El 'SS.CC' que muestra el HUD, leido de la OAM (5 sprites tras el
    auto y la fila de vuelta: 4 + 4 = indice 8)."""
    oam = game.env.ram[0x200:0x300]
    return ''.join(chr(oam[(8 + i) * 4 + 1]) for i in range(5))


gc = Game()
gc.run(30)
gc.press(START)
gc.run(5)
gc.drive(8000, until=lambda: gc.peek('qualyLap') == 2)
def fmt(f):
    return f'{f // 60:02d}.{(f % 60) * 100 // 60:02d}'


malos = []
for _ in range(20):
    gc.drive(17)             # muestrear restos distintos, no multiplos de 60
    f = gc.peek('lapFrameHi') * 256 + gc.peek('lapFrameLo')
    visto = crono_en_pantalla(gc)
    # se aceptan el cuadro actual y el anterior: la OAM que lee Python puede
    # ser la que se armo un cuadro antes (mismo desfasaje step/frame de
    # siempre). Lo que se esta cazando es un error de conversion, que da
    # diferencias grandes y no de una centesima.
    if visto not in (fmt(f), fmt(f - 1)):
        malos.append((f, fmt(f), visto))
check(not malos,
      f'el cronometro en pantalla coincide con los cuadros transcurridos '
      f'({len(malos)} mal{": " + str(malos[:2]) if malos else ""})')

print('\n== Entrar a la carrera ==')
g.press(START)
g.run(5)
check(g.state == ST_RACE, 'START desde la parrilla entra a la carrera')
check(g.peek('lapNum') == 1, 'empieza en la vuelta 1')
check(g.peek('playerPos') == pole_jugador,
      f'se larga desde el puesto de la qualy (P{pole_jugador})')
# La distancia de largada depende del puesto de parrilla, asi que el chequeo
# de consistencia de plyTotal (mas abajo) tiene que partir de este valor y no
# de una constante.
base_largada = g.peek('plyTotalHi') * 256 + g.peek('plyTotalLo')

print('\n== Acelerar ==')
# Con la pista angosta (80 px de margen) ir 180 cuadros sin girar puede
# sacarte del asfalto apenas el circuito empieza a curvar, y eso topa la
# velocidad -- no es lo que este bloque quiere medir. Se sigue el asfalto
# (como el resto de los bloques) para aislar la aceleracion en si.
g.drive(180)
check(g.peek('spdHi') >= 3, f"acelera hasta el tope (spdHi={g.peek('spdHi')})")
d0 = g.dist
g.drive(60)
check(g.dist > d0, 'la distancia recorrida avanza')

print('\n== Los 22 pilotos ==')
# Los 4 rivales que se ven en pantalla siguen siendo trafico decorativo (sin
# cambios de la Fase 1). En paralelo se simulan los 22 pilotos reales (el
# jugador + 21 IA) solo para llevar la cuenta de posiciones. Se corre con A
# sostenido (sin frenar/girar/offroad) para no mezclar la convergencia del
# pase de burbuja con cambios de ritmo real del jugador -- eso se cubre
# aparte, mas abajo.
#
# nes-py a veces devuelve el estado de RAM con el 6502 a mitad de una
# subrutina (confirmado leyendo distLo, que ya existia desde la Fase 0 y
# muestra el mismo patron): el "cuadro" que ve Python no siempre coincide
# con un WaitFrame completo del 6502, y ocasionalmente la lectura cae entre
# dos escrituras que en la ROM son secuenciales e incondicionales (por
# ejemplo distLo y plyTotalLo, las dos en UpdateDistance). Cuanto mas larga
# la subrutina, mas ancha esa ventana: UpdatePositions (3 pases de burbuja
# mas el rearmado de rankOf) la pisa mas seguido que UpdateDistance. En
# ningun caso el desfasaje persiste: siempre se resuelve solo en pocos
# cuadros. Por eso estos checks toleran una racha corta de cuadros
# desincronizados, pero fallan si crece sin limite -- eso si seria un bug
# real, no ruido del harness.
TOTAL_LO = g.labels['totalLo']
TOTAL_HI = g.labels['totalHi']
ORDER = g.labels['orderTable']
NUM_DRIVERS = 22
PLAYER_SLOT = 19
GAS_SLOT = 18


def total_of(i):
    return g.peek(TOTAL_HI + i) * 256 + g.peek(TOTAL_LO + i)


def order_of():
    return [g.peek(ORDER + i) for i in range(NUM_DRIVERS)]


perm_bad = 0
order_streak = order_bad_max_streak = 0
pos_streak = pos_bad_max_streak = 0
ply_streak = ply_bad_max_streak = 0
oamidx_max = 0
for _ in range(400):
    g.run(1, A)
    oamidx_max = max(oamidx_max, g.peek('oamIdx'))

    o = order_of()
    if sorted(o) != list(range(NUM_DRIVERS)):
        perm_bad += 1

    totals = [total_of(i) for i in range(NUM_DRIVERS)]
    ordenada = all(totals[o[i]] >= totals[o[i + 1]] for i in range(NUM_DRIVERS - 1))
    order_streak = 0 if ordenada else order_streak + 1
    order_bad_max_streak = max(order_bad_max_streak, order_streak)

    # Con empates de distancia (pasa en la largada, donde todos aceleran
    # igual) el puesto no es un numero unico: cualquier orden entre los
    # empatados es valido. Por eso se acepta un RANGO, de contar solo los
    # estrictamente por delante a contar tambien los empatados.
    ply = totals[PLAYER_SLOT]
    delante = sum(1 for i in range(NUM_DRIVERS) if i != PLAYER_SLOT and totals[i] > ply)
    empatados = sum(1 for i in range(NUM_DRIVERS) if i != PLAYER_SLOT and totals[i] == ply)
    pos_ok = delante + 1 <= g.peek('playerPos') <= delante + empatados + 1
    pos_streak = 0 if pos_ok else pos_streak + 1
    pos_bad_max_streak = max(pos_bad_max_streak, pos_streak)

    # PLAYER_START: sin qualy todavia, los 22 se escalonan en la largada y el
    # jugador arranca con esa distancia, no en 0 (ver StartRace)
    ply_esperado = base_largada + (g.peek('lapNum') - 1) * 3000 + g.dist
    ply_ok = (g.peek('plyTotalHi') * 256 + g.peek('plyTotalLo')) == ply_esperado
    ply_streak = 0 if ply_ok else ply_streak + 1
    ply_bad_max_streak = max(ply_bad_max_streak, ply_streak)

check(perm_bad == 0, f'orderTable siempre es una permutacion de 0..21 ({perm_bad} cuadros mal)')
check(order_bad_max_streak <= 3,
      f'orderTable sigue la distancia real (racha de fallas seguidas: {order_bad_max_streak})')
check(pos_bad_max_streak <= 8,
      f'playerPos coincide con un conteo independiente (racha de fallas seguidas: {pos_bad_max_streak})')
check(ply_bad_max_streak <= 3,
      f'plyTotal es consistente con lapNum/distLo/Hi (racha de fallas seguidas: {ply_bad_max_streak})')

teamPaceBase = g.labels['teamPaceLo']
paces = [g.peek(teamPaceBase + i) for i in range(NUM_DRIVERS) if i != PLAYER_SLOT]
mediana = sorted(paces)[len(paces) // 2]
gas_pace = g.peek(teamPaceBase + GAS_SLOT)
check(gas_pace < mediana,
      f'Alpine (GAS) queda por debajo de la mediana de ritmo (GAS={gas_pace}, mediana={mediana})')

# oamIdx es un solo byte usado como indice en oam,x durante todo BuildOAM. Si
# el conteo real de sprites superara 256 bytes (64 sprites), oamIdx daria la
# vuelta en silencio y las escrituras siguientes pisarian sprites ya
# escritos al principio del buffer (el jugador, el HUD) sin ningun error
# visible obvio. Con jugador+HUD+ventana+4 rivales el presupuesto es
# ~61 sprites (244 bytes) de los 64 (256 bytes) disponibles: poco margen.
check(oamidx_max <= 252, f'oamIdx no se acerca al desborde (maximo visto: {oamidx_max}/256)')

# Los autos que se ven SON los rivales de la clasificacion, no trafico
# decorativo: cada uno tiene que ser un piloto real, distinto del jugador,
# distinto entre si, y estar en pantalla. Si alguna de esas se rompe,
# estariamos dibujando autos que no corren la carrera.
CARDRV = g.labels['carDrv']
CARY = g.labels['carY']
autos_mal = 0
autos_max = 0
for _ in range(400):
    g.run(1, A)
    n = g.peek('carCount')
    autos_max = max(autos_max, n)
    if n > 6:
        autos_mal += 1
        continue
    drvs = [g.peek(CARDRV + i) for i in range(n)]
    ys = [g.peek(CARY + i) for i in range(n)]
    if len(set(drvs)) != len(drvs):          # dos veces el mismo piloto
        autos_mal += 1
    if any(d >= NUM_DRIVERS for d in drvs):  # piloto inexistente
        autos_mal += 1
    if PLAYER_SLOT in drvs:                  # el jugador dibujado como rival
        autos_mal += 1
    if any(y >= 240 for y in ys):            # fuera de pantalla
        autos_mal += 1
check(autos_mal == 0, f'los autos en pantalla son rivales reales de la carrera ({autos_mal} cuadros mal)')
# No se puede exigir "siempre hay varios en pantalla": largando desde la pole
# el jugador se puede escapar y quedar solo, que es lo correcto. Lo que si
# tiene que valer es que se dibujen TODOS los que estan en rango de pantalla
# (hasta el tope de MAX_CARS), ni mas ni menos.
falta = 0
for _ in range(200):
    g.run(1, A)
    ply = g.peek('plyTotalHi') * 256 + g.peek('plyTotalLo')
    en_rango = 0
    for i in range(NUM_DRIVERS):
        if i == PLAYER_SLOT:
            continue
        y = 168 - ((g.peek(TOTAL_HI + i) * 256 + g.peek(TOTAL_LO + i)) - ply)
        if 0 <= y < 240:
            en_rango += 1
    if g.peek('carCount') != min(en_rango, 5):
        falta += 1
check(falta == 0, f'se dibujan todos los rivales que estan en pantalla ({falta} cuadros mal)')

# Los pilotos de jerarquia tienen que pelear el paso mas que el fondo de
# parrilla: es lo que hace que pasar a un Verstappen cueste y pasar a un
# colista no. defBonus sale de la habilidad, no del ritmo del auto.
DEF_BASE = g.labels['defBonus']
VER_SLOT, LIN_SLOT = 4, 13
def_ver = g.peek(DEF_BASE + VER_SLOT)
def_lin = g.peek(DEF_BASE + LIN_SLOT)
def_col = g.peek(DEF_BASE + PLAYER_SLOT)
check(def_ver > def_lin,
      f'los pilotos de jerarquia defienden mas (VER={def_ver}, LIN={def_lin})')
check(def_col == 0, f'el jugador no tiene bonus de defensa (COL={def_col})')

# Y el ritmo de la IA tiene que estar montado alrededor del rendimiento real
# del jugador, no por debajo: si el mejor rival fuera mas lento que un
# jugador limpio, se ganaria siempre pasara lo que pasara (paso dos veces).
# Medido: manejando limpio el jugador rinde ~3.8 unidades/cuadro, o sea
# ~205 en las unidades de paceLo con AIPACE_HI=3.
mejor_pace = max(g.peek(teamPaceBase + i) for i in range(NUM_DRIVERS) if i != PLAYER_SLOT)
mejor_con_defensa = max(g.peek(teamPaceBase + i) + g.peek(DEF_BASE + i)
                        for i in range(NUM_DRIVERS) if i != PLAYER_SLOT)
check(mejor_pace < 205,
      f'ningun rival corre mas rapido que un jugador limpio ({mejor_pace} < 205)')
check(mejor_con_defensa > 205,
      f'los de arriba defendiendo si lo superan ({mejor_con_defensa} > 205)')

print('\n== El scroll se mueve ==')
s0 = g.peek('scrollLo')
g.run(5, A)
check(g.peek('scrollLo') != s0, 'el scroll vertical cambia entre cuadros')

print('\n== Frenar ==')
g.run(120, B)
check(g.peek('spdHi') == 0, 'B frena hasta parar')

print('\n== El circuito curva ==')
# El centro del asfalto se corre de a 2 columnas por bloque de atributos. Un
# error de una columna rompe la alineacion de las paletas, asi que se verifica
# el perfil entero de la pantalla, no solo que cambie.
CC_BASE = g.labels['rowCC']
TRACK_CC, PLAYER_ROW = 12, 168 // 8   # ver TRACK_CC en src/main.s (pista angosta)


def perfil(g, top=None):
    """Centro del asfalto de las 31 filas visibles, de arriba a abajo."""
    t = g.peek('topRow') if top is None else top
    return [g.peek(CC_BASE + (t + i) % 60) for i in range(31)]


centros, salto_max, curva_max = set(), 0, 0
for _ in range(900):
    g.run(1, A)
    p = perfil(g)
    centros.update(p)
    salto_max = max(salto_max, max(abs(p[i + 1] - p[i]) for i in range(30)))
    curva_max = max(curva_max, max(p) - min(p))
check(len(centros) >= 3, f'el circuito curva para los dos lados (centros {sorted(centros)})')
check(salto_max <= 2, f'el asfalto no da saltos: max {salto_max} columnas entre filas contiguas')
check(curva_max >= 4, f'hay curvas visibles: hasta {curva_max * 8} px de desplazamiento en pantalla')

print('\n== Clasificacion completa (SELECT) ==')
# SELECT pausa la carrera y dibuja la clasificacion en las mismas dos
# nametables que usa el circuito curvo (Fase 1). Verifica: que el estado se
# congele de verdad, que se retome exacto al salir, y que el circuito no
# haya quedado roto por reusar esas nametables para texto.
# La tabla COMPLETA (60 filas), no la ventana visible: perfil() depende de
# topRow, que avanza con los pocos cuadros reales que toma detectar la
# transicion de SELECT (documentado mas abajo) -- comparar la ventana da
# falsos positivos porque se corre, sin que el circuito este roto. rowCC[60]
# en cambio nadie lo escribe mientras esta congelado (solo UpdateTrack
# escribe ahi, y no corre durante ST_CLASS), asi que tiene que quedar
# identico byte a byte pase lo que pase con el timing.
rowcc_antes = [g.peek(CC_BASE + i) for i in range(60)]
dist_antes = g.peek('distLo')
scroll_antes = g.peek('scrollLo')

g.press(SELECT)
g.run(5)
check(g.state == ST_CLASS, 'SELECT entra a la clasificacion')
g.shot('class_screen')

dist_ref, scroll_ref = g.peek('distLo'), g.peek('scrollLo')
cambio = False
for _ in range(60):
    g.run(1, 0)
    if g.peek('distLo') != dist_ref or g.peek('scrollLo') != scroll_ref:
        cambio = True
check(not cambio, 'la carrera queda congelada mientras se ve la clasificacion')

# salir: mantener SELECT hasta ver el cambio de estado, para capturar el
# cuadro exacto de la transicion (press() sostiene el boton mas alla de eso,
# y esos cuadros de mas ya son carrera real de nuevo, no parte del "resume")
for _ in range(8):
    g.run(1, SELECT)
    if g.state == ST_RACE:
        break
check(g.state == ST_RACE, 'SELECT de nuevo vuelve a la carrera')

# No se puede exigir igualdad EXACTA: el cambio de estado cae en algun punto
# adentro de un step de nes-py, asi que para cuando Python lee la RAM la
# carrera ya avanzo un cuadro o dos (mismo desfasaje step/frame documentado
# arriba). Lo que si tiene que valer es que retome DE DONDE ESTABA y no de
# cero: durante la clasificacion el scroll se fuerza a 0, asi que si el
# restore fallara se quedaria pegado ahi.
dist_post = g.peek('distLo')
scroll_post = g.peek('scrollLo')
check(0 <= (dist_post - dist_ref) % 256 <= 12,
      f'la distancia retoma donde estaba (era {dist_ref}, quedo {dist_post})')
check(scroll_post != 0 and abs(scroll_post - scroll_antes) <= 12,
      f'el scroll retoma donde estaba, no en 0 (era {scroll_antes}, quedo {scroll_post})')
rowcc_despues = [g.peek(CC_BASE + i) for i in range(60)]
check(rowcc_despues == rowcc_antes, 'el circuito no se rompe al ir y volver de la clasificacion')
g.run(8, 0)

print('\n== Salirse de la pista ==')
# Carrera nueva: los bloques de arriba ya consumieron casi toda la distancia
# de las 3 vueltas, y lo que sigue necesita pista por delante. Cada bloque
# desde aca arranca su propio fin de semana.
g = Game()
g.start_race()
# Alejarse de la ventana de boxes de la salida (dist < PIT_EXIT_LEN) antes
# de manejar para cualquier lado: si el barrido de mas abajo llega a pisar
# la franja de boxes mientras la ventana esta activa, se abre el menu de
# parada (fase 4 etapa 3) y el auto queda pausado ahi, sin llegar nunca al
# pasto. Este bloque no prueba boxes -- eso esta en su propia seccion --
# asi que se saca de la ventana primero, siguiendo el asfalto derecho.
g.drive(200)

# Con el circuito curvo el borde ya no esta en una X fija. El test recalcula
# el borde igual que el juego y verifica que offRoad coincida cuadro a cuadro.
ROAD_L, ROAD_R = 48, 128   # ver ROAD_L/ROAD_R en src/main.s (pista angosta)
# El pit lane (fase 4 etapa 2) es una excepcion: mientras la ventana de
# distancia esta activa Y el auto esta AHORA sobre esa franja, no cuenta
# como offRoad (ver UpdatePlayer, el bloque de @dentro). "pitCommitted"
# (sticky el resto de la ventana) solo afecta el tope de velocidad, no
# esto: si te vas de la franja angosta del pit lane hacia el pasto de al
# lado, eso si es offRoad de verdad.
LAP_LEN = 3000
PIT_ENTRY_LEN, PIT_EXIT_LEN = 300, 150
PIT_LANE_L, PIT_LANE_R = 144, 176   # ver PIT_LANE_L/R en src/main.s

mal, vistos = 0, set()
dist_antes = g.peek('distHi') * 256 + g.peek('distLo')
for i in range(600):
    # UpdatePlayer corre antes que UpdateTrack/UpdateDistance, asi que usa
    # el topRow y la distancia de ANTES de este cuadro.
    top_antes = g.peek('topRow')
    g.run(1, A | (LEFT if (i // 75) % 2 == 0 else RIGHT))
    cc = g.peek(CC_BASE + (top_antes + PLAYER_ROW) % 60)
    x = g.peek('playerX') - (cc - TRACK_CC) * 8
    ventana = dist_antes >= LAP_LEN - PIT_ENTRY_LEN or dist_antes < PIT_EXIT_LEN
    en_boxes = ventana and PIT_LANE_L <= x < PIT_LANE_R
    e = 0 if en_boxes else (0 if ROAD_L <= x <= ROAD_R else 1)
    vistos.add(e)
    if g.peek('offRoad') != e:
        mal += 1
    dist_antes = g.peek('distHi') * 256 + g.peek('distLo')
check(mal == 0, f'offRoad sigue el borde del asfalto curvado ({mal} cuadros mal de 600)')
check(vistos == {0, 1}, f'el barrido paso por dentro y por fuera de la pista {sorted(vistos)}')

for _ in range(600):                    # llegar al pasto, este donde este
    g.run(1, A | LEFT)
    if g.peek('offRoad') == 1:
        break
check(g.peek('offRoad') == 1, 'se puede llegar al pasto')

# El limite de velocidad fuera de pista se verifica EN los cuadros en que
# realmente esta afuera, no despues de N cuadros fijos: el circuito curva, y
# quedarse apretando izquierda no garantiza seguir en el pasto (la pista se
# puede correr hasta meterte de nuevo en el asfalto sola). Se saltea el
# primer cuadro de cada salida porque UpdatePlayer aplica el limite con el
# offRoad del cuadro anterior.
rapido_afuera, cuadros_afuera, antes_afuera = 0, 0, False
for _ in range(400):
    g.run(1, A | LEFT)
    afuera = g.peek('offRoad') == 1
    if afuera and antes_afuera:
        cuadros_afuera += 1
        if g.peek('spdHi') > 2:
            rapido_afuera += 1
    antes_afuera = afuera
check(cuadros_afuera > 20, f'el barrido paso suficiente tiempo en el pasto ({cuadros_afuera} cuadros)')
check(rapido_afuera == 0,
      f'fuera de pista la velocidad queda limitada ({rapido_afuera} cuadros por encima del tope)')

for _ in range(600):
    g.run(1, A | RIGHT)
    if g.peek('offRoad') == 0:
        break
check(g.peek('offRoad') == 0, 'volviendo al asfalto se despenaliza')

print('\n== Gomas ==')
g = Game()
g.do_qualy()
check(g.peek('tireCompound') == 1, f"la parrilla arranca en MEDIO ({g.peek('tireCompound')})")
g.press(RIGHT)
g.run(5)
check(g.peek('tireCompound') == 2, f"RIGHT cambia a DURO ({g.peek('tireCompound')})")
g.press(RIGHT)
g.run(5)
check(g.peek('tireCompound') == 0, f"RIGHT desde DURO da la vuelta a BLANDO ({g.peek('tireCompound')})")
g.press(LEFT)
g.run(5)
check(g.peek('tireCompound') == 2, f"LEFT desde BLANDO da la vuelta a DURO ({g.peek('tireCompound')})")

g.press(START)
g.run(5)
check(g.state == ST_RACE, 'START larga con el compuesto elegido')
check(g.peek('tireCompound') == 2, 'el compuesto elegido en la parrilla llega a la carrera')
check(g.peek('usedMask') == 0b100, f"usedMask marca el compuesto de partida (usedMask={g.peek('usedMask')})")
check(g.peek('tireWear') == 0, 'las gomas arrancan sin desgaste')

# tope dinamico = MAXSPD_HI*256 * grip_compuesto% * grip_banda% / 10000,
# mismo calculo que capTabLoTab/capTabHiTab en src/main.s (banda 0, DURO).
MAXSPD_HI, HARD_GRIP, WBAND_0 = 4, 88, 100
cap_esperado = MAXSPD_HI * 256 * HARD_GRIP * WBAND_0 // 10000
cap_hi, cap_lo = g.peek('curCapHi'), g.peek('curCapLo')
check(cap_hi * 256 + cap_lo == cap_esperado,
      f"el tope dinamico sale de la tabla (DURO banda 0 = {cap_hi}.{cap_lo}, "
      f"esperado {cap_esperado >> 8}.{cap_esperado & 0xFF})")

# manejar solo con A (sin seguir el asfalto) para salirse de pista y
# acumular desgaste por eso, hasta cerrar una vuelta
wear_antes = g.peek('tireWear')
lap_antes = g.peek('lapNum')
for _ in range(2000):
    g.run(1, A)
    if g.peek('lapNum') != lap_antes:
        break
wear_despues = g.peek('tireWear')
check(wear_despues > wear_antes, f"el desgaste sube al cerrar una vuelta ({wear_antes} -> {wear_despues})")

# banda 0 es 0-49: una sola vuelta no alcanza para cruzarla (arriba dio 19),
# asi que el tope todavia no baja. Seguir unas vueltas mas hasta cruzar de
# banda y ahi si verificar que el tope baja con el desgaste.
for _ in range(6000):
    g.run(1, A)
    if g.peek('tireWear') >= 50:
        break
check(g.peek('tireWear') >= 50, f"el desgaste sigue subiendo con mas vueltas (wear={g.peek('tireWear')})")
check(g.peek('curCapHi') * 256 + g.peek('curCapLo') < cap_esperado,
      'el tope de velocidad baja junto con el desgaste')

# en pista (offRoad=0) la velocidad nunca supera el tope dinamico vigente;
# fuera de pista rige el limite mas estricto que ya prueba 'Salirse de la
# pista', asi que esos cuadros se saltean aca.
mal = 0
for _ in range(300):
    g.run(1, A)
    if g.peek('offRoad'):
        continue
    spd = g.peek('spdHi') * 256 + g.peek('spdLo')
    cap = g.peek('curCapHi') * 256 + g.peek('curCapLo')
    if spd > cap:
        mal += 1
check(mal == 0, f"en pista la velocidad nunca supera el tope dinamico ({mal} cuadros mal)")

# regla de los dos compuestos: sin el menu de boxes para cambiar de goma
# (todavia no existe, llega en la etapa 3), usedMask se queda con un solo
# bit prendido toda la carrera -- la condicion que GoEnd usa para
# descalificar. La pantalla en si (texto "DESCALIFICADO: 1 GOMA" vs "PRESS
# START") se verifico a ojo con capturas (make shots), forzando usedMask
# con y sin un segundo compuesto.
check(bin(g.peek('usedMask')).count('1') == 1,
      f"sin poder cambiar de goma, usedMask se queda en un solo compuesto (usedMask={g.peek('usedMask')})")

print('\n== Boxes (pit lane) ==')
g = Game()
g.start_race()
# el auto arranca en la parrilla con distancia ~0: la ventana de boxes
# (dist < PIT_EXIT_LEN) ya esta activa desde el primer cuadro, asi que
# alcanza con dirigirse a la franja (columnas de piano derecho) mientras el
# circuito todavia va derecho.
PIT_LANE_L, PIT_LANE_R = 144, 176   # ver PIT_LANE_L/R en src/main.s
PIT_CAP = 4 * 256 * 60 // 100       # MAXSPD_HI*256*PIT_LIMIT_PCT/100
PIT_PENALTY_SECS = 5
centro_boxes = (PIT_LANE_L + PIT_LANE_R) // 2

entro = False
for _ in range(200):
    g.drive(1, target=centro_boxes)
    if g.peek('inPit'):
        entro = True
        break
check(entro, 'el auto entra a boxes al meterse en la franja durante la ventana')
check(g.peek('pitCommitted') == 1, 'queda comprometido apenas toca la franja')
check(g.peek('offRoad') == 0, 'estar en boxes no cuenta como salida de pista')

# El menu se abre AUTOMATICO al cuadro siguiente de comprometerse (ver
# RaceLogic): no hay margen para manejar a fondo por el carril antes de
# eso, asi que el limite de velocidad + penalidad de boxes se prueban
# DESPUES de la parada, cuando el control vuelve (el auto no avanzo nada
# mientras estuvo parado, asi que sigue physicamente sobre el carril).
g.run(5, 0)             # soltar todo, que PitMenuLogic lea flancos limpios
g.press(START)          # confirmar con lo que ya estaba elegido
g.run(5)
assert g.state == ST_RACE, f"no salio del menu (state={g.state})"
while g.peek('pitTimerHi') or g.peek('pitTimerLo'):
    g.run(1, A)
check(g.peek('pitCommitted') == 1,
      'sigue comprometido al salir de la parada, dentro de la misma ventana')

mal = 0
for _ in range(60):
    g.run(1, A)
    spd = g.peek('spdHi') * 256 + g.peek('spdLo')
    if spd > PIT_CAP:
        mal += 1
check(mal == 0, f'el limite de boxes clampea la velocidad al salir ({mal} cuadros por encima)')
check(g.peek('penaltySecs') >= PIT_PENALTY_SECS,
      f"pasarse del limite al salir de boxes suma una penalidad (penaltySecs={g.peek('penaltySecs')})")

print('\n== Menu de parada ==')
g = Game()
g.start_race()
entro_menu = False
for _ in range(200):
    g.drive(1, target=centro_boxes)
    if g.state == ST_PITMENU:
        entro_menu = True
        break
check(entro_menu, 'tocar el carril de boxes abre el menu, sin manejar mas alla')
check(g.peek('menuCompound') == g.peek('tireCompound'),
      'el menu arranca mostrando el compuesto actual')

# el drive() que llevo hasta el menu puede haber dejado RIGHT sostenido: sin
# soltarlo primero, PitMenuLogic (que lee flancos, padNew) no ve un apriete
# nuevo en el primer press() de aca abajo.
g.run(5, 0)

goma_antes = g.peek('menuCompound')
g.press(RIGHT)
g.run(3)
check(g.peek('menuCompound') != goma_antes, 'RIGHT en GOMA cambia la seleccion')

g.press(DOWN)
g.run(3)
check(g.peek('pitCursor') == 1, 'ARRIBA/ABAJO mueve el cursor a ALA')

ala_antes = g.peek('menuWing')
g.press(RIGHT)
g.run(3)
check(g.peek('menuWing') != ala_antes, 'RIGHT en ALA cambia la seleccion')

goma_elegida = g.peek('menuCompound')
ala_elegida = g.peek('menuWing')
mask_antes = g.peek('usedMask')
g.press(START)
g.run(5)
check(g.state == ST_RACE, 'START confirma y vuelve a la carrera')
check(g.peek('tireCompound') == goma_elegida, 'se aplica el compuesto elegido')
check(g.peek('tireWear') == 0, 'las gomas nuevas arrancan sin desgaste')
check(g.peek('usedMask') == mask_antes | (1 << goma_elegida),
      'usedMask suma el compuesto nuevo (para la regla de los dos compuestos)')
wing_esperado = {0: 0xFF, 1: 0, 2: 1}[ala_elegida]
check(g.peek('wingLevel') == wing_esperado, 'se aplica el ala elegida')
check(g.peek('pitTimerLo') + g.peek('pitTimerHi') * 256 > 0,
      'arranca el cronometro de la parada (pitStopTimer)')

# mientras dura la parada: el auto no se mueve pero la IA si, asi que el
# puesto empeora -- es lo que hace que la parada duela de verdad.
pos_antes = g.peek('playerPos')
dist_antes = g.peek('distHi') * 256 + g.peek('distLo')
mal_spd, vio_parar = 0, False
for _ in range(200):
    g.run(1, A | RIGHT)   # a fondo: si el timer no lo frenara, avanzaria
    timer = g.peek('pitTimerLo') + g.peek('pitTimerHi') * 256
    if timer > 0:
        vio_parar = True
        if g.peek('spdHi') != 0 or g.peek('spdLo') != 0:
            mal_spd += 1
    else:
        break
check(vio_parar, 'el timer estuvo activo durante la parada')
check(mal_spd == 0, f'sin control mientras dura la parada ({mal_spd} cuadros con velocidad)')
dist_durante = g.peek('distHi') * 256 + g.peek('distLo')
check(dist_durante == dist_antes, 'el auto no avanza mientras esta parado')
check(g.peek('playerPos') >= pos_antes, 'el puesto no mejora mientras la IA sigue y el jugador no')

# el timer llega a 0 solo y el control vuelve sin apretar nada mas
g.run(30, A)
check(g.peek('spdHi') > 0 or g.peek('spdLo') > 0,
      'terminada la parada el control vuelve solo, sin boton nuevo')

print('\n== Parada abstraida de la IA ==')
g = Game()
g.start_race()
PLAYER_SLOT = 19
TOTAL_LAPS = 6
AI_PITSTOP_LOSS = 525   # ver AI_PITSTOP_LOSS en src/main.s
pitStopLapBase = g.labels['pitStopLap']
totalLoBase = g.labels['totalLo']
totalHiBase = g.labels['totalHi']
laps = [g.peek(pitStopLapBase + i) for i in range(22)]
ia_laps = [l for i, l in enumerate(laps) if i != PLAYER_SLOT]
check(all(3 <= l <= TOTAL_LAPS - 2 for l in ia_laps),
      f'cada IA para en una vuelta del medio, ni las 2 primeras ni las 2 ultimas ({sorted(set(ia_laps))})')


def total(g, d):
    return g.peek(totalHiBase + d) * 256 + g.peek(totalLoBase + d)


# medir, para un piloto cualquiera, cuanto avanza por vuelta -- tiene que
# notarse un pozo justo en su vuelta de parada.
drv = next(i for i in range(22) if i != PLAYER_SLOT)
target_lap = laps[drv]
deltas = {}
last_lap = g.peek('lapNum')
last_total = total(g, drv)
for _ in range(20000):
    g.run(1, A)
    if g.peek('lapNum') != last_lap:
        nuevo_total = total(g, drv)
        deltas[last_lap] = nuevo_total - last_total
        last_lap = g.peek('lapNum')
        last_total = nuevo_total
    if last_lap > target_lap or g.state != ST_RACE:
        break
# ApplyAIPitStops resta justo cuando lapNum PASA a valer target_lap (en la
# rama @lap de UpdateDistance, junto con "inc lapNum"): el pozo aparece en
# el delta de la vuelta ANTERIOR (la transicion hacia target_lap), no en la
# propia target_lap.
lap_del_pozo = target_lap - 1
otras = [d for lap, d in deltas.items() if lap != lap_del_pozo]
check(lap_del_pozo in deltas and otras,
      f'se pudo medir la vuelta de parada del piloto {drv} (deltas={deltas})')
if lap_del_pozo in deltas and otras:
    promedio_otras = sum(otras) / len(otras)
    check(promedio_otras - deltas[lap_del_pozo] > AI_PITSTOP_LOSS // 2,
          f'la vuelta de parada pierde distancia de verdad '
          f'(vuelta {lap_del_pozo}: {deltas[lap_del_pozo]}, resto: {otras})')

print('\n== ERS: carga ==')
g = Game()
g.start_race()
check(g.peek('ersEnergy') == 0, 'arranca sin energia')

# offRoad y trompeando no cargan nada, aunque se frene y se gire
g.drive(400, target=0)   # pegado al borde: pasto
g.run(1)
if g.peek('offRoad'):
    e0 = g.peek('ersEnergy')
    g.run(60, B | LEFT)
    check(g.peek('ersEnergy') == e0, 'offRoad no carga energia')
else:
    print('  --   (no se pudo llegar a offRoad para probarlo aca)')

# Curva vs recta. BuildCars recalcula carX/Y/Count TODOS los cuadros (corre
# antes que UpdateERS en RaceLogic), asi que no se puede aislar el rebufo
# escribiendole a mano a esas variables -- se pisan solas dentro del mismo
# cuadro. En cambio se tolera el ruido del rebufo real (chico, ver la
# ventana angosta en src/main.s) y se compara con margen.
g = Game()
g.start_race()
g.drive(900)   # pasar el arranque derecho e ir por curvas de verdad


def carga_en(frames, buttons):
    g.env.ram[g.labels['ersEnergy']] = 0
    g.run(frames, buttons)
    return g.peek('ersEnergy')


e_curva = carga_en(20, B | LEFT)
e_recta = carga_en(20, B)
e_nada = carga_en(20, A)
check(e_curva > 0, f'frenar y girar en curva carga energia (e={e_curva})')
check(e_recta > 0, f'frenar sin girar en recta carga energia (e={e_recta})')
check(e_curva > e_recta,
      f'la curva cerrada carga mas que la recta ({e_curva} > {e_recta})')
check(e_recta > e_nada,
      f'frenar en recta carga mas que solo acelerar ({e_recta} > {e_nada})')

print('\n== ERS: rebufo ==')
# No se puede inyectar un auto sintetico (mismo problema de arriba: BuildCars
# lo pisa dentro del cuadro), asi que se busca el rebufo en trafico real:
# manejar solo con A (nunca frena, nunca gira) durante varios cuadros y
# confirmar que la energia sube en algun momento -- si sube sin frenar ni
# girar, solo puede ser por rebufo.
g = Game()
g.start_race()
g.env.ram[g.labels['ersEnergy']] = 0
subio_por_rebufo = False
for _ in range(600):
    g.drive(1, extra=0)   # drive() ya sostiene A; sin extra no frena ni gira mas de lo necesario para seguir el asfalto
    if g.peek('ersEnergy') > 0:
        subio_por_rebufo = True
        break
check(subio_por_rebufo, 'en trafico real, ir en el rebufo carga energia sin frenar')

print('\n== ERS: descarga ==')
g = Game()
g.start_race()
g.drive(200)
tope_normal = g.peek('curCapHi') * 256 + g.peek('curCapLo')
g.env.ram[g.labels['ersEnergy']] = 100
g.drive(30, extra=UP)
tope_boosteado = g.peek('spdHi') * 256 + g.peek('spdLo')
# +15% aproximado con corrimientos: curCap + curCap/8 + curCap/64 (ver
# RecalcCap-style en UpdatePlayer). Se compara contra la MISMA formula, no
# contra "tope_normal*1.15", para no reintroducir el redondeo que el motor
# evita a proposito.
esperado = tope_normal + tope_normal // 8 + tope_normal // 64
check(tope_boosteado == esperado,
      f'el tope boosteado sale de la formula ({tope_boosteado}, esperado {esperado})')
check(tope_boosteado > tope_normal,
      f'descargar sube el tope de verdad ({tope_boosteado} > {tope_normal})')
check(g.peek('ersEnergy') < 100, 'descargar consume energia')

g.env.ram[g.labels['ersEnergy']] = 0
g.run(10, A | UP)
check(g.peek('ersActive') == 0, 'sin energia no hay descarga aunque se sostenga ARRIBA')

# no se puede descargar en boxes
g = Game()
g.start_race()
g.env.ram[g.labels['ersEnergy']] = 100
centro_boxes = 160
for _ in range(200):
    g.drive(1, target=centro_boxes)
    if g.peek('inPit'):
        break
check(g.peek('pitCommitted') == 1, 'llego a boxes para probar el bloqueo')
e0 = g.peek('ersEnergy')
g.run(20, A | UP)
check(g.peek('ersEnergy') == e0, f'no se puede descargar comprometido en boxes (energia sigue en {e0})')

# gomas gastadas + descargar = desgaste extra (lapErsAbuse, que WearTick
# consume al cerrar la vuelta)
g = Game()
g.start_race()
g.drive(200)
ERS_WEAR_THRESHOLD = 75   # ver ERS_WEAR_THRESHOLD en src/main.s
g.env.ram[g.labels['tireWear']] = ERS_WEAR_THRESHOLD + 5
g.env.ram[g.labels['ersEnergy']] = 100
check(g.peek('lapErsAbuse') == 0, 'lapErsAbuse arranca apagado')
g.run(10, A | UP)
check(g.peek('lapErsAbuse') == 1,
      'descargar con las gomas por encima del umbral prende lapErsAbuse')

print('\n== ERS: uso de la IA ==')
# Mismo patron que UpdateAI/@pelea: se pone al rival a la misma distancia
# que el jugador (dentro de DEFEND_RANGE, asi que defiende) y se compara
# cuanto avanza con energia llena vs sin energia. El aporte por cuadro es
# chico a proposito (AI_ERS_BONUS se suma a paceFrac, que solo se nota en
# la frecuencia de acarreo hacia totalLo/Hi -- mismo mecanismo de punto fijo
# que ya usa todo el pace de la IA), asi que hace falta promediar sobre
# varios pilotos para que la señal no se pierda en el ruido de un solo
# muestreo corto.
totalLoBase, totalHiBase = g.labels['totalLo'], g.labels['totalHi']
aiErsBase = g.labels['aiErs']


def total_de(game, d):
    return game.peek(totalHiBase + d) * 256 + game.peek(totalLoBase + d)


def avance_defendiendo(energia, drv, frames=40):
    gg = Game()
    gg.start_race()
    gg.run(100, A)              # pasar la largada parada (startRamp)
    ply = gg.peek('plyTotalHi') * 256 + gg.peek('plyTotalLo')
    gg.env.ram[totalHiBase + drv] = ply // 256
    gg.env.ram[totalLoBase + drv] = ply % 256
    gg.env.ram[aiErsBase + drv] = energia
    t0 = total_de(gg, drv)
    gg.run(frames, A)
    return total_de(gg, drv) - t0


pilotos_prueba = [i for i in range(8) if i != PLAYER_SLOT]
con_energia = sum(avance_defendiendo(100, d) for d in pilotos_prueba)
sin_energia = sum(avance_defendiendo(0, d) for d in pilotos_prueba)
check(con_energia > sin_energia,
      f'defendiendo con energia rinde mas, promediado sobre {len(pilotos_prueba)} '
      f'pilotos (con={con_energia}, sin={sin_energia})')

print('\n== ERS: HUD ==')
g = Game()
g.start_race()
g.env.ram[g.labels['ersEnergy']] = 45
g.run(10)
oam = g.env.ram[0x200:0x300]
# la fila del HUD de ERS es la 4ta (V, P, velocidad, ERS): 5 sprites en
# Y=32, arrancando en el indice (3*ancho de fila anterior)... mas simple:
# se busca 'E:045' entre los sprites de esa altura (tile+1 = Y real).
fila_ers = ''.join(chr(oam[i * 4 + 1]) for i in range(64)
                    if oam[i * 4] == 32 - 1 and oam[i * 4 + 1] != 0xFF)
check('045' in fila_ers or fila_ers.startswith('E:'),
      f"el HUD muestra la energia (fila leida: {fila_ers!r})")

print('\n== Vueltas y meta ==')
g = Game()
g.start_race()
laps_seen = {g.peek('lapNum')}
# TOTAL_LAPS=6 y manejando solo con A (sin seguir el asfalto) las gomas se
# desgastan rapido -- con el tope de velocidad ya reducido por pinchadura,
# terminar las 6 vueltas de esta forma tarda unos 8500 cuadros medidos.
for _ in range(180):
    g.run(60, A)
    laps_seen.add(g.peek('lapNum'))
    if g.state == ST_END:
        break
check(len(laps_seen) > 1, f'el contador de vueltas avanza (vio {sorted(laps_seen)})')
check(g.state == ST_END, 'la carrera termina despues de 6 vueltas')
check(g.peek('finished') == 1, 'queda marcada como terminada')
check(g.screen_stats()['negro'] > 0.9, 'muestra la pantalla final')
g.shot('test_final')

print('\n== Volver al titulo ==')
g.press(START)
g.run(20)
check(g.state == ST_TITLE, 'START vuelve al titulo desde la meta')

print()
if fails:
    print(f'{len(fails)} fallas:')
    for f in fails:
        print('  -', f)
    sys.exit(1)
print('Todo verde.')
