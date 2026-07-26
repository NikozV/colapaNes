"""
Harness para probar la ROM sin abrir un emulador grafico.

Usa nes-py (emulador NES real compilado en C++) para correr la ROM cuadro a
cuadro, apretar botones, sacar capturas y leer la RAM del juego por NOMBRE de
variable (los simbolos salen de build/labels.txt, que genera ld65 -Ln).

Uso tipico:

    from nes_harness import Game, A, B, START, LEFT, RIGHT

    g = Game()
    g.run(30)                # 30 cuadros sin apretar nada
    g.press(START)           # arranca la carrera
    g.run(600, A)            # 10 segundos a fondo
    g.shot('carrera')        # -> build/shots/carrera.png
    print(g.vars())          # {'lapNum': 2, 'spdHi': 4, ...}
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM = os.path.join(ROOT, 'build', 'colapinto.nes')
LABELS = os.path.join(ROOT, 'build', 'labels.txt')
SHOTS = os.path.join(ROOT, 'build', 'shots')

# Mapa de botones de nes-py (ojo: NO es el orden del hardware)
RIGHT, LEFT, DOWN, UP, START, SELECT, B, A = (
    0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01)

# Variables que exporta main.s con .exportzp
WATCH = ['gameState', 'playerX', 'spdLo', 'spdHi', 'distLo', 'distHi',
         'lapNum', 'crashT', 'offRoad', 'scrollLo', 'secs', 'mins', 'finished']

ST_TITLE, ST_RACE, ST_END = 0, 1, 2


def load_labels(path=LABELS):
    """Lee build/labels.txt -> {'lapNum': 0x11, ...}"""
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path):
        m = re.match(r'al\s+([0-9A-Fa-f]+)\s+\.?(\w+)', line)
        if m:
            out[m.group(2)] = int(m.group(1), 16)
    return out


class Game:
    def __init__(self, rom=ROM):
        if not os.path.exists(rom):
            sys.exit(f"No existe {rom}. Corre 'make' primero.")
        from nes_py import NESEnv
        self.env = NESEnv(rom)
        self.env.reset()
        self.labels = load_labels()
        self.frame = 0

    # ---------------------------------------------------------------- control
    def run(self, frames, buttons=0):
        """Avanza N cuadros con esos botones apretados."""
        for _ in range(frames):
            self.env.step(buttons)
        self.frame += frames
        return self

    def press(self, button, hold=4, release=8):
        """Aprieta y suelta un boton (hace falta soltarlo: el juego lee flancos)."""
        self.run(hold, button)
        self.run(release, 0)
        return self

    # ------------------------------------------------------------------- RAM
    def peek(self, name_or_addr):
        addr = self.labels.get(name_or_addr, name_or_addr) \
            if isinstance(name_or_addr, str) else name_or_addr
        if isinstance(addr, str):
            raise KeyError(f"No conozco el simbolo '{addr}'. "
                           f"Agregalo a .exportzp en src/main.s y recompila.")
        return int(self.env.ram[addr])

    def vars(self, names=WATCH):
        return {n: self.peek(n) for n in names if n in self.labels}

    @property
    def state(self):
        return self.peek('gameState')

    @property
    def dist(self):
        return self.peek('distHi') * 256 + self.peek('distLo')

    # -------------------------------------------------------------- capturas
    def shot(self, name, scale=2):
        from PIL import Image
        os.makedirs(SHOTS, exist_ok=True)
        im = Image.fromarray(self.env.screen.copy())
        if scale != 1:
            im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        path = os.path.join(SHOTS, f'{name}.png')
        im.save(path)
        return path

    def screen_stats(self):
        """Metricas rapidas para detectar pantallas en negro o congeladas."""
        import numpy as np
        a = self.env.screen
        return {
            'negro': round(float((a.sum(2) < 40).mean()), 3),
            'colores': len(np.unique(a.reshape(-1, 3), axis=0)),
        }

    # ------------------------------------------------------------- atajos
    def start_race(self):
        """Desde el titulo, arranca la carrera y verifica que entro."""
        self.run(30)
        self.press(START)
        self.run(10)
        assert self.state == ST_RACE, \
            f"No entro a la carrera (gameState={self.state})"
        return self
