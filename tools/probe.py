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

from nes_harness import Game, A, B, LEFT, RIGHT, START, SELECT, ST_TITLE, ST_RACE, ST_END, ST_CLASS

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

print('\n== Entrar a la carrera ==')
g.press(START)
g.run(10)
check(g.state == ST_RACE, 'START entra a la carrera')
check(g.peek('lapNum') == 1, 'empieza en la vuelta 1')
check(g.screen_stats()['colores'] >= 6, 'el circuito se dibuja (pasto/pianos/asfalto)')

print('\n== Acelerar ==')
g.run(180, A)
check(g.peek('spdHi') >= 3, f"acelera hasta el tope (spdHi={g.peek('spdHi')})")
d0 = g.dist
g.run(60, A)
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

    ply = totals[PLAYER_SLOT]
    esperado_pos = 1 + sum(1 for i in range(NUM_DRIVERS) if i != PLAYER_SLOT and totals[i] > ply)
    pos_ok = g.peek('playerPos') == esperado_pos
    pos_streak = 0 if pos_ok else pos_streak + 1
    pos_bad_max_streak = max(pos_bad_max_streak, pos_streak)

    ply_esperado = (g.peek('lapNum') - 1) * 3000 + g.dist
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
TRACK_CC, PLAYER_ROW = 16, 168 // 8


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
perfil_antes = perfil(g)
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
check(g.peek('distLo') == dist_ref, 'la distancia retoma exacto donde estaba')
check(g.peek('scrollLo') == scroll_antes, 'el scroll retoma exacto donde estaba')
check(perfil(g) == perfil_antes, 'el circuito no se rompe al ir y volver de la clasificacion')
g.run(8, 0)

print('\n== Salirse de la pista ==')
# Con el circuito curvo el borde ya no esta en una X fija. El test recalcula
# el borde igual que el juego y verifica que offRoad coincida cuadro a cuadro.
ROAD_L, ROAD_R = 48, 192


def espera_offroad(g, top_antes):
    cc = g.peek(CC_BASE + (top_antes + PLAYER_ROW) % 60)
    x = g.peek('playerX') - (cc - TRACK_CC) * 8
    return 0 if ROAD_L <= x <= ROAD_R else 1


mal, vistos = 0, set()
for i in range(600):
    # UpdatePlayer corre antes que UpdateTrack, asi que usa el topRow anterior
    top_antes = g.peek('topRow')
    g.run(1, A | (LEFT if (i // 75) % 2 == 0 else RIGHT))
    e = espera_offroad(g, top_antes)
    vistos.add(e)
    if g.peek('offRoad') != e:
        mal += 1
check(mal == 0, f'offRoad sigue el borde del asfalto curvado ({mal} cuadros mal de 600)')
check(vistos == {0, 1}, f'el barrido paso por dentro y por fuera de la pista {sorted(vistos)}')

for _ in range(600):                    # llegar al pasto, este donde este
    g.run(1, A | LEFT)
    if g.peek('offRoad') == 1:
        break
check(g.peek('offRoad') == 1, 'se puede llegar al pasto')
g.run(120, A | LEFT)
check(g.peek('spdHi') <= 2, 'fuera de pista la velocidad queda limitada')
for _ in range(600):
    g.run(1, A | RIGHT)
    if g.peek('offRoad') == 0:
        break
check(g.peek('offRoad') == 0, 'volviendo al asfalto se despenaliza')

print('\n== Vueltas y meta ==')
laps_seen = {g.peek('lapNum')}
for _ in range(120):
    g.run(60, A)
    laps_seen.add(g.peek('lapNum'))
    if g.state == ST_END:
        break
check(len(laps_seen) > 1, f'el contador de vueltas avanza (vio {sorted(laps_seen)})')
check(g.state == ST_END, 'la carrera termina despues de 3 vueltas')
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
