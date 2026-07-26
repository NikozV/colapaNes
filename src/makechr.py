#!/usr/bin/env python3
"""Genera el CHR (32KB) para el juego de F1 de NES.

MMC1 mapea el CHR en bancos de 8KB. El banco 0 lleva los tiles que usa el
juego hoy; los otros tres van en cero hasta que haya algo que poner.
"""

TILES_BG = {}
TILES_SPR = {}

def tile(rows):
    """rows: 8 strings de 8 chars ('.','1','2','3') -> 16 bytes NES"""
    assert len(rows) == 8, rows
    lo, hi = [], []
    for r in rows:
        assert len(r) == 8, r
        b0 = b1 = 0
        for i, c in enumerate(r):
            v = 0 if c == '.' else int(c)
            b0 |= (v & 1) << (7 - i)
            b1 |= ((v >> 1) & 1) << (7 - i)
        lo.append(b0)
        hi.append(b1)
    return bytes(lo + hi)

# ---------------------------------------------------------------- fuente 5x7
FONT = {
' ': ["     ","     ","     ","     ","     ","     ","     "],
'!': ["  X  ","  X  ","  X  ","  X  ","  X  ","     ","  X  "],
'.': ["     ","     ","     ","     ","     ","     ","  X  "],
'-': ["     ","     ","     "," XXX ","     ","     ","     "],
'+': ["     ","  X  ","  X  "," XXX ","  X  ","  X  ","     "],
'/': ["    X","    X","   X ","  X  "," X   ","X    ","X    "],
':': ["     ","  X  ","     ","     ","     ","  X  ","     "],
'?': [" XXX ","X   X","    X","   X ","  X  ","     ","  X  "],
'0': [" XXX ","X   X","X  XX","X X X","XX  X","X   X"," XXX "],
'1': ["  X  "," XX  ","  X  ","  X  ","  X  ","  X  "," XXX "],
'2': [" XXX ","X   X","    X","   X ","  X  "," X   ","XXXXX"],
'3': ["XXXXX","   X ","  X  ","   X ","    X","X   X"," XXX "],
'4': ["   X ","  XX "," X X ","X  X ","XXXXX","   X ","   X "],
'5': ["XXXXX","X    ","XXXX ","    X","    X","X   X"," XXX "],
'6': ["  XX "," X   ","X    ","XXXX ","X   X","X   X"," XXX "],
'7': ["XXXXX","    X","   X ","  X  "," X   "," X   "," X   "],
'8': [" XXX ","X   X","X   X"," XXX ","X   X","X   X"," XXX "],
'9': [" XXX ","X   X","X   X"," XXXX","    X","   X "," XX  "],
'A': [" XXX ","X   X","X   X","XXXXX","X   X","X   X","X   X"],
'B': ["XXXX ","X   X","X   X","XXXX ","X   X","X   X","XXXX "],
'C': [" XXX ","X   X","X    ","X    ","X    ","X   X"," XXX "],
'D': ["XXXX ","X   X","X   X","X   X","X   X","X   X","XXXX "],
'E': ["XXXXX","X    ","X    ","XXXX ","X    ","X    ","XXXXX"],
'F': ["XXXXX","X    ","X    ","XXXX ","X    ","X    ","X    "],
'G': [" XXX ","X   X","X    ","X  XX","X   X","X   X"," XXX "],
'H': ["X   X","X   X","X   X","XXXXX","X   X","X   X","X   X"],
'I': [" XXX ","  X  ","  X  ","  X  ","  X  ","  X  "," XXX "],
'J': ["    X","    X","    X","    X","X   X","X   X"," XXX "],
'K': ["X   X","X  X ","X X  ","XX   ","X X  ","X  X ","X   X"],
'L': ["X    ","X    ","X    ","X    ","X    ","X    ","XXXXX"],
'M': ["X   X","XX XX","X X X","X X X","X   X","X   X","X   X"],
'N': ["X   X","XX  X","X X X","X  XX","X   X","X   X","X   X"],
'O': [" XXX ","X   X","X   X","X   X","X   X","X   X"," XXX "],
'P': ["XXXX ","X   X","X   X","XXXX ","X    ","X    ","X    "],
'Q': [" XXX ","X   X","X   X","X   X","X X X","X  X "," XX X"],
'R': ["XXXX ","X   X","X   X","XXXX ","X X  ","X  X ","X   X"],
'S': [" XXXX","X    ","X    "," XXX ","    X","    X","XXXX "],
'T': ["XXXXX","  X  ","  X  ","  X  ","  X  ","  X  ","  X  "],
'U': ["X   X","X   X","X   X","X   X","X   X","X   X"," XXX "],
'V': ["X   X","X   X","X   X","X   X","X   X"," X X ","  X  "],
'W': ["X   X","X   X","X   X","X X X","X X X","XX XX","X   X"],
'X': ["X   X","X   X"," X X ","  X  "," X X ","X   X","X   X"],
'Y': ["X   X","X   X"," X X ","  X  ","  X  ","  X  ","  X  "],
'Z': ["XXXXX","    X","   X ","  X  "," X   ","X    ","XXXXX"],
}

def font_tile(ch, color='3'):
    g = FONT[ch]
    rows = []
    for y in range(8):
        src = g[y] if y < 7 else "     "
        line = "".join(color if c == 'X' else '.' for c in src)
        rows.append("." + line + "..")
    return tile(rows)

def add_font(target):
    for ch in FONT:
        target[ord(ch)] = font_tile(ch)

# ---------------------------------------------------------------- fondo
GRASS_A = tile([
 "11111111",
 "12111121",
 "11111111",
 "11211111",
 "11111111",
 "12111211",
 "11111111",
 "11112111",
])
GRASS_B = tile([
 "11121111",
 "11111111",
 "12111112",
 "11111111",
 "11211111",
 "11111111",
 "11111211",
 "12111111",
])
ROAD = tile([
 "11111111",
 "11111111",
 "11111111",
 "11111111",
 "11111111",
 "11111111",
 "11111111",
 "11111111",
])
ROAD_DASH = tile([
 "111133..",
 "111133..",
 "111133..",
 "111133..",
 "111133..",
 "111133..",
 "111133..",
 "111133..",
])
CURB_A = tile(["11111111"] * 8)   # rojo
CURB_B = tile(["22222222"] * 8)   # blanco
ROAD_EDGE_L = tile([
 "22111111",
 "22111111",
 "22111111",
 "22111111",
 "22111111",
 "22111111",
 "22111111",
 "22111111",
])

TILES_BG[0x01] = GRASS_A
TILES_BG[0x02] = GRASS_B
TILES_BG[0x03] = ROAD
TILES_BG[0x04] = ROAD_DASH
TILES_BG[0x05] = CURB_A
TILES_BG[0x06] = CURB_B
TILES_BG[0x07] = ROAD_EDGE_L
add_font(TILES_BG)

# ---------------------------------------------------------------- sprites
CAR = [
 "................",
 "......1111......",
 ".....111111.....",
 "..333333333333..",
 ".22..111111..22.",
 ".22...1111...22.",
 ".22...1111...22.",
 "......1111......",
 ".....111111.....",
 "....11111111....",
 "....11333311....",
 "....11111111....",
 ".22..111111..22.",
 ".22...1111...22.",
 ".22..111111..22.",
 "...3333333333...",
]

def metasprite(art):
    """16x16 -> 4 tiles (TL, TR, BL, BR)"""
    out = []
    for by in (0, 8):
        for bx in (0, 8):
            rows = [art[by + y][bx:bx + 8] for y in range(8)]
            rows = [r.replace('X', '1') for r in rows]
            out.append(tile(rows))
    return out

car_tiles = metasprite(CAR)
for i, t in enumerate(car_tiles):
    TILES_SPR[0x80 + i] = t
add_font(TILES_SPR)

# ---------------------------------------------------------------- armado
def build(d):
    out = bytearray(0x1000)
    for idx, data in d.items():
        out[idx * 16:idx * 16 + 16] = data
    return out

BANK_SIZE = 0x2000      # un banco de CHR del MMC1
CHR_BANKS = 4           # 4 * 8KB = 32KB, lo que declara la cabecera iNES

import sys, os
out = sys.argv[1] if len(sys.argv) > 1 else 'build/game.chr'
bank0 = build(TILES_BG) + build(TILES_SPR)
assert len(bank0) == BANK_SIZE, len(bank0)
chr_data = bank0 + bytes(BANK_SIZE * (CHR_BANKS - 1))
assert len(chr_data) == BANK_SIZE * CHR_BANKS, len(chr_data)
os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
open(out, 'wb').write(chr_data)
print(f"{out} OK ({len(chr_data)} bytes)")
