# CLAUDE.md — Gran Premio NES

## Qué es esto

Un juego de carreras top-down para **Nintendo Entertainment System real**, tema
Franco Colapinto / Alpine #43. Escrito en ensamblador 6502 puro, sin librerías,
sin cc65 C runtime. La ROM que sale de acá corre en Mesen, FCEUX y en hardware
original vía flashcart.

No es una simulación ni un "juego estilo NES": es un cartucho MMC1 válido, con
todas las restricciones que eso implica. Cuando algo no se puede hacer, no se
puede hacer de verdad.

## Adónde va

El objetivo final es un **fin de semana de F1 completo**: qualy con vuelta
lanzada saliendo de boxes, parrilla de 22 pilotos reales de la temporada 2026
con sus equipos, carrera largando desde el puesto que sacaste, desgaste de
gomas con tres compuestos, paradas en boxes con menú, y energía tipo ERS que se
carga en las curvas y se descarga con un botón.

**Las reglas completas están en [`docs/reglas-juego.md`](docs/reglas-juego.md).**
Ese documento manda: si algo del juego contradice esas reglas, el bug está en
el código. Antes de tocar cualquier cosa de la simulación, leelo.

## Estado actual

Lo que hay hoy en la ROM es la **base del motor**, no el juego final:

- Pantalla de título → carrera de 3 vueltas → pantalla de meta con el tiempo
- Acelerador, freno, dirección, penalización por irse al pasto
- 4 rivales genéricos con carril y velocidad aleatorios, colisiones con rebote
- Scroll vertical infinito, HUD con vuelta actual y velocidad en km/h
- Motor por canal de ruido atado a la velocidad, blips de vuelta y choque

No hay todavía: qualy, boxes, gomas, ERS, pilotos reales ni clasificación.

## Dos bloqueantes antes de agregar contenido

Están explicados en detalle en `docs/reglas-juego.md`, sección de fases. El
resumen para no arrancar por el lado equivocado:

1. ~~**NROM no da más.**~~ **Resuelto (fase 0).** El cartucho es MMC1 (mapper
   1): 128 KB de PRG y 32 KB de CHR, con `SwitchBank` para el banco de
   `$8000`. Se eligió MMC1 y no MMC3 porque el emulador de los tests (nes-py)
   solo soporta los mappers 0, 1, 2 y 3: con MMC3 se pierden `make test` y
   `make shots`, que son toda la forma de verificar. El precio es que no hay
   IRQ por línea de barrido, así que el HUD fijo va a tener que salir por
   sprite 0 hit. El detalle está en `src/nes-mmc1.cfg`.

2. **El panel lateral fijo de 22 pilotos no se puede hacer así.** El fondo es
   una sola capa y hace scroll vertical: cualquier cosa dibujada ahí se mueve
   con la pista. La solución acordada es una ventana móvil de sprites con los
   cinco puestos alrededor del tuyo durante la carrera, más la tabla completa de
   22 en una pantalla aparte con SELECT. Está detallado en las reglas, sección
   8. No intentar el panel lateral fijo: se necesitarían escrituras a la PPU en
   el medio de cada línea de barrido.

Además, **el ERS depende de que existan curvas**, porque la energía se carga
girando. Las curvas rompen el truco actual del scroll (ver más abajo), así que
van temprano en el orden de trabajo.

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

- **MMC1 mapper 1**: 128 KB de PRG en 8 bancos de 16 KB y 32 KB de CHR en 4
  bancos de 8 KB. `$8000`–`$BFFF` es conmutable, `$C000`–`$FFFF` es el banco
  fijo. Todo lo que no puede desaparecer nunca —reset, NMI, `SwitchBank`,
  vectores— va en el banco fijo, en el segmento `CORE`.
- **Los registros del MMC1 son seriales**: cinco escrituras seguidas, y de cada
  una entra solo el bit 0. Un `sta` suelto no configura nada.
- **Nunca INC/DEC ni ningún read-modify-write sobre `$8000`–`$FFFF`.** Esas
  instrucciones escriben dos veces y la segunda le manda basura al mapper. Es
  el bug clásico de MMC1 y no se ve leyendo el código. Para desplazar, `lsr a`,
  que toca el acumulador y no memoria.
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
| `$6000`–`$7FFF` | PRG-RAM del cartucho (segmento `XRAM`, todavía sin usar) |
| `$8000`–`$BFFF` | Banco conmutable (`BANK0`..`BANK6`), se elige con `SwitchBank` |
| `$C000`–`$FFFF` | Banco fijo: `CORE`, `CODE`, `RODATA`, `VECTORS` |

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

## Documentos del proyecto

| Archivo | Qué tiene |
|---|---|
| `docs/reglas-juego.md` | **Las reglas del juego.** Qualy, gomas, boxes, ERS, penalizaciones, los 22 pilotos, y las fases de implementación en orden |
| `docs/nes-cheatsheet.md` | Registros de PPU, OAM, atributos, paletas, timing NTSC |
| `docs/roadmap.md` | Mejoras sueltas del motor, ordenadas por cuánto lo rompen |

Cuando cambien las reglas del juego, se actualiza `docs/reglas-juego.md`, no
este archivo. Acá va solo lo que no cambia: cómo está construido, qué no
permite el hardware y cómo se verifica.
