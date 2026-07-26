# Gran Premio NES

Juego de carreras top-down para **NES**, tema Franco Colapinto / Alpine #43.
Ensamblador 6502 puro, cartucho NROM (mapper 0), 24.592 bytes.

Corre en Mesen, FCEUX, Nestopia, puNES y en hardware original vía Everdrive.

## Arranque rápido

```bash
sudo apt install cc65
pip install -r requirements.txt

make          # -> build/colapinto.nes
make test     # verifica en emulador que el juego funciona
make shots    # capturas de cada pantalla -> build/shots/
```

## Controles

| Botón | Acción |
|---|---|
| A | Acelerar |
| B | Frenar |
| ← → | Cambiar de carril |
| START | Empezar / volver al título |

Son 3 vueltas. Salirse al pasto limita la velocidad a un tercio; chocar a un
rival te saca la mitad y te tira al costado. Arriba se ve la vuelta actual y la
velocidad en km/h; al terminar, el tiempo total.

## Estructura

```
CLAUDE.md              contexto del proyecto, restricciones y workflow
Makefile               build, test y capturas
requirements.txt       dependencias de Python (solo para los tests)

src/
  main.s               el juego entero, ensamblador 6502
  makechr.py           genera los graficos (tiles como arte ASCII)
  nes.cfg              configuracion del linker (NROM: 16KB PRG + 8KB CHR)

tools/
  nes_harness.py       emulador headless: correr, apretar botones, leer la RAM
  probe.py             test de regresion  -> make test
  shots.py             capturas de pantalla -> make shots

docs/
  nes-cheatsheet.md    registros de PPU, OAM, atributos, paletas, timing
  roadmap.md           ideas pendientes ordenadas por dificultad

build/                 todo lo generado (ignorado por git)
```

## Cómo se prueba

No hay que abrir un emulador a mano para saber si algo anda. `tools/` levanta
la ROM en un emulador NES real compilado en C++, la corre cuadro a cuadro,
aprieta botones y lee la RAM del juego **por nombre de variable**:

```python
from nes_harness import Game, A, START

g = Game()
g.start_race()
g.run(600, A)                 # 10 segundos a fondo
print(g.peek('lapNum'))       # 2
print(g.vars())               # todas las variables observadas
g.shot('prueba')              # build/shots/prueba.png
```

Los nombres salen del bloque `.exportzp` de `src/main.s`, que el linker vuelca
en `build/labels.txt`. Para observar una variable nueva, agregala ahí.

## Editar los gráficos

No hay archivos binarios que tocar. En `src/makechr.py` cada tile es arte
ASCII, donde `.` es transparente y `1`/`2`/`3` son índices de la paleta:

```python
CAR = [
 "................",
 "......1111......",
 ".....111111.....",
 "..333333333333..",
 ".22..111111..22.",
 ...
]
```

Editás la grilla, corrés `make` y ya está. Las paletas están en `src/main.s`,
bajo la etiqueta `palette:`.
