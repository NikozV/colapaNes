#!/usr/bin/env python3
"""
Saca capturas de cada pantalla a build/shots/ para revisarlas a ojo.

    make shots

Mirá los PNG despues de cualquier cambio grafico (tiles, paletas, HUD,
posiciones de sprites). El emulador no miente; el codigo si.
"""

import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])

from nes_harness import Game, A, B, LEFT, RIGHT, START

g = Game()

g.run(40)
print(g.shot('01_titulo'))

g.press(START)
g.run(30)
print(g.shot('02_largada'))

g.run(400, A)
print(g.shot('03_carrera'))

g.run(200, A | RIGHT)
print(g.shot('04_derecha'))

g.run(400, A | LEFT)
print(g.shot('05_fuera_de_pista'))

# hasta la meta
for _ in range(120):
    g.run(60, A)
    if g.state == 2:
        break
print(g.shot('06_meta'))

print('\nEstado final:', g.vars())
