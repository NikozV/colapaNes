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

print('\n== Salirse de la pista ==')
g.run(240, A | LEFT)
check(g.peek('offRoad') == 1, 'irse al pasto marca offRoad')
check(g.peek('spdHi') <= 2, 'fuera de pista la velocidad queda limitada')
g.run(60, A | RIGHT)
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
