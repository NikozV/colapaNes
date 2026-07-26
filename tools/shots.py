#!/usr/bin/env python3
"""
Saca capturas de cada pantalla a build/shots/ para revisarlas a ojo.

    make shots

Mirá los PNG despues de cualquier cambio grafico (tiles, paletas, HUD,
posiciones de sprites, texto). El emulador no miente; el codigo si.

Recorre el fin de semana entero: titulo, qualy, parrilla, carrera y meta.
"""

import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])

from nes_harness import Game, A, LEFT, RIGHT, START, SELECT, ST_QUALY, ST_GRID, ST_END

g = Game()

g.run(40)
print(g.shot('01_titulo'))

g.press(START)
g.run(5)
g.drive(200)
print(g.shot('02_qualy_salida'))

g.drive(8000, until=lambda: g.peek('qualyLap') == 2)
g.drive(200)
print(g.shot('03_qualy_lanzada'))

g.drive(8000, until=lambda: g.state != ST_QUALY)
g.run(10)                       # env.screen viene con un par de cuadros de atraso
print(g.shot('04_parrilla'))

g.press(START)
g.run(5)
g.drive(400)
print(g.shot('05_carrera'))

g.drive(300, extra=RIGHT)
print(g.shot('06_derecha'))

g.drive(400, target=0)          # pegado al borde: pasto y grava
print(g.shot('07_fuera_de_pista'))

g.press(SELECT)
g.run(10)
print(g.shot('08_clasificacion'))
g.press(SELECT)
g.run(10)

# hasta la meta
for _ in range(200):
    g.drive(60)
    if g.state == ST_END:
        break
g.run(10)
print(g.shot('09_meta'))

print('\nEstado final:', g.vars())
