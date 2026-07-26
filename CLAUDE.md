# CLAUDE.md — Gran Premio NES

## Qué es esto

Un juego de carreras top-down para **Nintendo Entertainment System real**, tema
Franco Colapinto / Alpine #43. Escrito en ensamblador 6502 puro, sin librerías,
sin cc65 C runtime. La ROM que sale de acá corre en Mesen, FCEUX y en hardware
original vía flashcart.

No es una simulación ni un "juego estilo NES": es un cartucho NROM válido, con
todas las restricciones que eso implica. Cuando algo no se puede hacer, no se
puede hacer de verdad.

## Estado actual

Jugable y completo de punta a punta:

- Pantalla de título → carrera de 3 vueltas → pantalla de meta con el tiempo
- Acelerador, freno, dirección, penalización por irse al pasto
- 4 rivales con carril y velocidad aleatorios, colisiones con rebote
- Scroll vertical infinito, HUD con vuelta actual y velocidad en km/h
- Motor por canal de ruido atado a la velocidad, blips de vuelta y choque

## Comandos

```bash
make          # compila -> build/colapinto.nes
make test     # corre la ROM en emulador y verifica que el juego funciona
make shots    # capturas de cada pantalla -> build/shots/*.png
make clean
```

Dependencias: `apt install cc65` y `pip install -r requirements.txt`.

## Regla de oro del workflow

**Nada se da por terminado sin verlo correr.** Un bug de 6502 casi nunca se ve
leyendo el código: se ve cuando la pantalla no cambia entre cuadros o cuando el
contador de vueltas se queda clavado.

Después de tocar cualquier cosa:

1. `make test` — verificación funcional automática (vueltas, meta, colisiones,
   scroll, penalización por pasto). Tiene que dar **todo verde**.
2. `make shots` y **mirar los PNG** si tocaste algo visual: tiles, paletas,
   posiciones de sprites, HUD, texto.

`tools/nes_harness.py` permite leer la RAM del juego por nombre de variable
(`g.peek('lapNum')`), lo que convierte el debugging de assembler en algo casi
normal. Las variables visibles son las que están en el bloque `.exportzp` de
`src/main.s` — si necesitás observar una nueva, agregala ahí y recompilá.

## Restricciones del hardware (no negociables)

Estas son las que más se olvidan y las que más bugs generan:

- **NROM mapper 0**: 16 KB de PRG y 8 KB de CHR, fijos. No hay bank switching.
  Si el código no entra, hay que reescribirlo más chico, no agrandar la ROM.
- **VRAM solo con el rendering apagado, o dentro del NMI.** En el NMI entran
  unos 2270 ciclos y ya se van varios en el DMA de sprites. Escribir a `$2007`
  en medio del frame con el rendering prendido corrompe la pantalla.
- **El color 0 de cada paleta de sprite es transparente.** Las cubiertas negras
  del auto van como color 2 (con `$0F` cargado en esa ranura), nunca como 0.
- **8 sprites por scanline, 64 en total.** Si se pasa, parpadean o desaparecen.
  El HUD ya usa 7 en su línea: no agregues más ahí sin sacar algo.
- **Los sprites se dibujan una línea más abajo** que el valor de Y en la OAM;
  por eso el código resta 1.
- La paleta es la del NES: 64 colores fijos, sin RGB libre. `$12` azul Alpine,
  `$16` rojo, `$10` gris plata, `$0F` negro.
- Los atributos de fondo son por bloques de 16x16 px, así que un cambio de
  paleta no puede caer en el medio de un bloque. El piano mide 2 tiles de ancho
  justamente por eso.

## Cómo está armado

### Mapa de memoria

| Rango | Uso |
|---|---|
| `$00`–`$26` | Variables del juego (zeropage, ver `.segment "ZEROPAGE"`) |
| `$0200`–`$02FF` | Buffer de OAM, se manda por DMA en cada NMI |
| `$0300`–`$0317` | Arrays de los 4 rivales (x, y 8.8, velocidad, paleta) |
| `$C000`–`$FFFF` | PRG ROM |

### Flujo

`reset` → `GoTitle` → bucle `main`, que en cada cuadro espera el NMI, lee el
control y despacha según `gameState` (`ST_TITLE` / `ST_RACE` / `ST_END`).

El NMI hace **solo** trabajo de PPU: DMA de sprites, `PPUCTRL`, `PPUMASK` y el
scroll. Toda la lógica vive en el bucle principal y deja el buffer de OAM listo
para el DMA siguiente.

### El truco del scroll

El scroll vertical es infinito y **no escribe nada en VRAM durante la carrera**.
Las dos nametables se dibujan idénticas al empezar, y el patrón del asfalto se
repite cada 16 px. Como 240 es múltiplo de 16, cuando el PPU cruza de una
nametable a la otra la unión cae siempre en la misma fase del patrón y no se
ve. Por eso `scrollLo` se mantiene en 0..239 y nunca se toca el bit de
nametable de `PPUCTRL`.

Si algún día agregás curvas o cambios de circuito, esto se cae y vas a tener
que escribir filas nuevas en el NMI. Es el cambio más grande que le podés hacer
al motor.

### Punto fijo

Velocidad, scroll y posición Y de los rivales usan 8.8 (byte alto = píxeles,
byte bajo = fracción). Los pares son `spdHi/spdLo`, `rivalYHi/rivalYLo`,
`scrollLo/scrollFrac`. La velocidad máxima es 4 px por cuadro.

## Convenciones de código

- Etiquetas globales en `PascalCase` para rutinas (`UpdatePlayer`), locales con
  `@` (`@loop`), constantes en `MAYUSCULAS`.
- Los parámetros de rutinas van en A/X/Y o en `tmp1`–`tmp4`. `tmp1`–`tmp4` son
  volátiles: cualquier rutina los puede pisar.
- Comentarios en castellano, sin tildes en el fuente (el ensamblador es ASCII).
- Los gráficos **no** se editan en binario: se generan desde `src/makechr.py`,
  donde cada tile es arte ASCII (`.` transparente, `1`/`2`/`3` índices de
  color). El auto está en la constante `CAR`, una grilla de 16x16 caracteres.
- La fuente está mapeada a ASCII, así que un texto se escribe literal:
  `.byte "PRESS START", 0`.

## Parámetros para tunear

Están todos juntos arriba de `src/main.s`:

```asm
MAXSPD_HI  = 4      ; velocidad maxima (px por cuadro)
LAP_LEN    = 3000   ; unidades de distancia por vuelta
TOTAL_LAPS = 3
ROAD_L     = 48     ; borde izquierdo del asfalto
ROAD_R     = 192    ; borde derecho
PLAYER_Y   = 168    ; altura fija del auto en pantalla
```

## Bugs que ya nos pasaron (no repetirlos)

- **Apagar el rendering deja el NMI apagado.** `RenderOff` escribe 0 en
  `PPUCTRL`, lo que también desactiva el NMI. Si después no se reescribe
  `PPUCTRL` a mano, `WaitFrame` se cuelga para siempre esperando un NMI que no
  llega. Por eso `RenderOn` escribe el registro directo y no solo la variable
  sombra.
- **El wrap del scroll pisaba el valor.** Una versión anterior guardaba el
  scroll como 0..479 y le restaba 240 para mostrarlo, destruyendo el valor real
  para el cuadro siguiente. La solución fue la de arriba: mantenerlo en 0..239.

Ninguno de los dos se ve leyendo el código. Los dos aparecieron al mirar que la
pantalla no cambiaba entre cuadros. De ahí la regla de oro.

## Ideas pendientes

Ver `docs/roadmap.md`. En orden de dificultad: música en los canales de pulso,
IA de un rival que pelee la punta, largada con semáforo, curvas con scroll
horizontal.
