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

ST_TITLE, ST_RACE, ST_END, ST_CLASS, ST_QUALY, ST_GRID = 0, 1, 2, 3, 4, 5


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
    TRACK_CC = 12               # centro del asfalto en la recta (ver src/main.s)
    PLAYER_ROW = 168 // 8       # fila de tiles donde va el auto
    PLAYER_X0 = 87              # X de pantalla cuando el circuito esta recto
                                 # (ver PLAYER_X0 en src/main.s)

    def track_center(self):
        """X de pantalla del centro del asfalto a la altura del auto."""
        cc = self.peek(self.labels['rowCC']
                       + (self.peek('topRow') + self.PLAYER_ROW) % 60)
        return self.PLAYER_X0 + (cc - self.TRACK_CC) * 8

    def drive(self, frames, extra=0, target=None, until=None):
        """Maneja siguiendo el asfalto, que es lo minimo para que el auto
        avance sin irse a cada curva. `extra` son botones a sostener ademas,
        `target` fuerza una X de destino (para irse afuera a proposito), y
        `until` corta apenas se cumple."""
        for _ in range(frames):
            obj = self.track_center() if target is None else target
            x = self.peek('playerX')
            btn = A | extra
            if x < obj - 3:
                btn |= RIGHT
            elif x > obj + 3:
                btn |= LEFT
            self.run(1, btn)
            if until is not None and until():
                return True
        return False

    def do_qualy(self, target=None):
        """Desde el titulo: entra a la qualy y la corre hasta la parrilla."""
        self.run(30)
        self.press(START)
        self.run(5)
        assert self.state == ST_QUALY, \
            f"No entro a la qualy (gameState={self.state})"
        self.drive(8000, target=target, until=lambda: self.state != ST_QUALY)
        assert self.state == ST_GRID, \
            f"La qualy no termino en la parrilla (gameState={self.state})"
        return self

    def grid(self):
        """La parrilla como lista de indices de piloto, del P1 al P22."""
        base = self.labels['orderTable']
        return [self.peek(base + i) for i in range(22)]

    def start_race(self):
        """Desde el titulo, atraviesa el fin de semana hasta la carrera."""
        self.do_qualy()
        self.press(START)
        self.run(5)
        assert self.state == ST_RACE, \
            f"No entro a la carrera (gameState={self.state})"
        return self
