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

from nes_harness import Game, A, B, LEFT, RIGHT, START, ST_TITLE, ST_RACE, ST_END

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
