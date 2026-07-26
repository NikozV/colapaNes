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

- **Fin de semana completo**: título → qualy (vuelta de salida + lanzada) →
  parrilla → carrera de 6 vueltas → meta. Se larga desde el puesto que sacaste
- Acelerador, freno, dirección, penalización por irse al pasto o a la grava
- **Circuito con curvas**, dibujado por filas escritas en el NMI, con grava
  entre el piano y el pasto
- **Los 22 pilotos de la temporada 2026**, simulados por distancia total
  (tabla en `BANK3`, primer uso real del banking de MMC1). Los autos que se
  ven en pantalla **son** los rivales de la clasificación que tenés cerca:
  adelantar en pantalla es adelantar de verdad
- **Panel de datos unificado a la derecha** (`HUD_X`, columnas 25-30): vuelta,
  puesto, velocidad y la ventana de 3 líneas (el de adelante / vos / el de
  atrás), todo junto en una franja fuera de la pista — nunca tapa el asfalto,
  verificado a nivel de píxel. Clasificación completa de los 22 con SELECT
- **Pista de 16 tiles** (antes 24: diez autos de ancho, desproporcionado),
  recentrada para dejarle lugar al panel sin invadirlo en ninguna curva
- **Gomas**: tres compuestos con desgaste y tope de velocidad dinámico por
  tabla (`curCapHi/Lo`, 8.8), regla de los dos compuestos con descalificación
- **Boxes**: carril de boxes ancho (piano + grava del lado derecho, para
  leerse separado de la pista) por ventana de distancia alrededor de cada
  cruce de vuelta, menú de parada (goma + ala) que se abre solo al
  comprometerse, `pitStopTimer` con la IA corriendo mientras el jugador está
  parado, y la parada abstraída de la IA para que la regla de los dos
  compuestos no sea injusta
- Motor por canal de ruido atado a la velocidad, blips de vuelta y choque

No hay todavía ERS. De la qualy quedó afuera lo que depende de boxes
(arrancar en el pit lane y su límite de velocidad) y de las gomas (que
arranquen frías en la vuelta de salida, que depende del ERS — ver
`docs/reglas-juego.md` sección 5).

**El cronómetro de la qualy cuenta cuadros, no segundos.** Las diferencias que
deciden la parrilla son de décimas, y contar cuadros hace que comparar y
ordenar tiempos sea una resta de 16 bits. La conversión a `SS.CC` se hace una
sola vez al mostrar (`FramesToTime`) — ojo que la cuenta de centésimas
(`cuadros * 5 / 3`) **necesita 16 bits**: en 8 se desborda con restos de 52
cuadros para arriba, y el bug no se ve en los datos, solo mirando la pantalla.

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

2. ~~**El panel lateral fijo de 22 pilotos no se puede hacer así.**~~
   **Resuelto (fase 2).** El fondo es una sola capa y hace scroll vertical:
   cualquier cosa dibujada ahí se movería con la pista. Se hizo lo acordado
   en las reglas, sección 8: una ventana móvil de sprites con los cinco
   puestos alrededor del tuyo durante la carrera (`BuildRankWindow`), más la
   tabla completa de 22 en pantalla aparte con SELECT (`EnterClass`), que
   pausa la carrera y reusa las mismas dos nametables del circuito con
   rendering apagado — hay que guardar el scroll y reconstruir el trazado
   real al salir (`RedrawTrack`) porque si no el circuito curvo de la fase 1
   queda roto. El panel lateral fijo se sigue sin poder hacer, por la misma
   razón de siempre.

**El ERS ya tiene dónde cargarse**: las curvas están hechas (fase 1), así que
la dependencia que las ponía temprano en el orden de trabajo está saldada.

## Comandos

```bash
make          # compila -> build/colapinto.nes
make test     # corre la ROM en emulador y verifica que el juego funciona
make shots    # capturas de cada pantalla -> build/shots/*.png
make tools    # que herramientas encontro y con que version
make deps     # instala las dependencias de Python
make clean
```

**Puesta a punto del entorno: [`docs/entorno.md`](docs/entorno.md).** En Linux
alcanza con `sudo apt install cc65 make` y `make deps`; en Windows hay que
correr todo desde Git Bash y bajar cc65 a mano, que es un ZIP de binarios.

Si falta algo, el Makefile lo detecta y dice qué instalar en vez de reventar
con un `command not found`. `make tools` te lo muestra sin compilar nada. Y si
cc65 está instalado pero afuera del PATH, `make CC65_BIN=/ruta/a/cc65/bin`.

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

**Ojo con un artefacto de `nes-py` al escribir checks nuevos**: un `env.step()`
no siempre corresponde a un `WaitFrame` completo del 6502 — ocasionalmente la
lectura de RAM cae a mitad de una subrutina, entre dos escrituras que en la
ROM son secuenciales e incondicionales. Se ve clarísimo comparando dos
variables que se actualizan juntas (por ejemplo `distLo` y `plyTotalLo`, las
dos en `UpdateDistance`): en <1% de los cuadros aparecen momentáneamente
desincronizadas, y se resuelven solas al cuadro siguiente sin excepción —
nunca persiste. Cuanto más larga la subrutina, más ancha esa ventana
(`UpdatePositions`, con sus 3 pasadas, lo pisa bastante más seguido que
`UpdateDistance`). No es un bug del juego: es que el "cuadro" que ve Python no
es exactamente el mismo concepto que el frame de 60 Hz del 6502. Un check que
compara dos lecturas independientes cuadro a cuadro tiene que tolerar una
racha corta de desincronización y fallar solo si crece sin límite — ver
`== Los 22 pilotos ==` en `tools/probe.py` para el patrón.

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
- **El texto de sprites es blanco sobre el tile relleno de negro**, no una
  letra suelta de color. El HUD y la ventana de posiciones se dibujan encima
  de la pista, donde el fondo cambia todo el tiempo (pasto verde, piano rojo,
  piano blanco, asfalto gris, grava): una letra sin fondo, de cualquier color,
  siempre pierde contra alguno de esos. Rellenar el tile hace que cada línea
  forme una barra negra continua **sin gastar un solo sprite de más**, y
  blanco sobre negro es el máximo contraste de luminancia posible — que es lo
  único que sirve si no se distinguen bien los colores (el usuario es
  daltónico). Consecuencia: los caracteres tienen que ir **pegados de a 8 px**,
  porque cualquier hueco en X deja ver la pista en el medio de la barra; para
  separar se usa un espacio de verdad, que ahora es un tile negro sólido. La
  fuente de fondo sigue naranja y transparente porque sus pantallas (título,
  clasificación, meta) ya son sobre negro.
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
| `$6000`–`$7FFF` | PRG-RAM del cartucho (segmento `XRAM`, todavía sin usar — ver nota abajo) |
| `$8000`–`$BFFF` | Banco conmutable (`BANK0`..`BANK6`), se elige con `SwitchBank` |
| `$C000`–`$FFFF` | Banco fijo: `CORE`, `CODE`, `RODATA`, `VECTORS` |

**Por qué `XRAM` sigue sin usarse, aunque la fase 2 tenía datos que
naturalmente irían ahí** (la tabla de 22 pilotos): `nes-py`, el emulador de
`make test`, solo expone las 2 KB de RAM interna de la consola —
`RAM_SIZE=$800` del lado de nes-py — y la PRG-RAM del cartucho le es
invisible. Cualquier variable que viva en `XRAM` no se puede leer con
`g.peek()` y queda fuera del alcance de `make test`. Por eso la tabla de
pilotos (copiada desde `BANK3` con `CopyPilotTable`) aterriza en RAM normal
(`BSS`), no en `XRAM`: `BANK3` se sigue usando de verdad como banco
conmutable, solo cambia el destino de la copia. Si en el futuro hace falta
`XRAM` de verdad (el guardado del campeonato, fase 6, sí necesita PRG-RAM con
pila), esa parte específicamente va a quedar fuera del alcance de `make
test` y va a haber que verificarla a mano en un emulador de escritorio.

### Flujo

`reset` → `GoTitle` → bucle `main`, que en cada cuadro espera el NMI, lee el
control y despacha según `gameState` (`ST_TITLE` / `ST_RACE` / `ST_END`).

El NMI hace **solo** trabajo de PPU: DMA de sprites, `PPUCTRL`, `PPUMASK` y el
scroll. Toda la lógica vive en el bucle principal y deja el buffer de OAM listo
para el DMA siguiente.

### El circuito en filas

Las dos nametables son un **buffer circular de 60 filas** (2 × 30). El scroll
recorre las 480 líneas de las dos: `scrollLo` es la posición dentro de la de
arriba (0..239) y `scrollNT` dice cuál va arriba (0 o 2, que es el bit 1 de
`PPUCTRL`).

Cada vez que la pantalla avanza 8 px entra una fila nueva por arriba.
`UpdateTrack` la arma en el bucle principal con `BuildRow` y la deja en
`rowBuf`; el NMI la escribe en la PPU. Se genera siempre la fila que quedó
**justo arriba del borde de la pantalla**: está entera fuera de vista, así que
no se ve aparecer. Como el buffer tiene 60 filas y solo 30 son visibles, la
costura entre lo más nuevo y lo más viejo cae siempre fuera de pantalla.

Los patrones siguen encajando cuando el buffer da la vuelta porque 60 es
múltiplo de 4 y de 2: el pasto usa `(columna + fila) mod 4`, y el piano y la
raya usan `fila mod 2`.

**En el NMI, la fila va antes que el scroll.** Escribir `$2006` pisa el latch
de scroll, así que si se setea el scroll primero, la pantalla sale corrida.

### Por qué las curvas son escalonadas

El asfalto se corre moviendo un solo número, `genCC`, la columna del centro.
`BuildRow` calcula `e = columna - genCC + 12` y con eso decide pasto, piano,
asfalto o raya.

`genCC` **solo se mueve de a 2 columnas y solo en los bordes de bloque de
atributos**, y eso no es una decisión estética:

- El borde entre pasto y piano es un cambio de paleta, y las paletas de fondo
  son por bloques de 16 × 16 px. Por eso el piano mide 2 tiles y el centro se
  corre de a 2 columnas.
- Un byte de atributos cubre 4 filas de tiles, así que las 4 comparten paleta:
  el centro no puede cambiar en el medio de un bloque.

Ojo con la última fila de atributos de cada nametable: 30 filas no son 8
bloques de 4, son **7 bloques de 4 más uno de 2** (las filas 28 y 29).

Como se genera hacia arriba, la primera fila que se toca de cada bloque es la
de abajo (la 3, 7, ... 27 y la 29): ahí se llama a `AdvanceTrack` y se
reescriben los atributos. El relleno inicial genera hacia abajo y **no** avanza
el trazado, para que la largada sea recta y el final del buffer enganche con el
principio sin un codo.

### Coordenadas de pista y de pantalla

Con el circuito corriéndose, una X en pantalla ya no dice dónde estás respecto
del asfalto. `ShiftAtY` convierte entre los dos sistemas: devuelve cuánto está
corrido el circuito a esa altura, leyendo `rowCC`, que guarda el centro de cada
fila virtual.

Los rivales viven en **coordenadas de pista** (por eso siguen la curva sin
hacer nada), y el jugador en coordenadas de pantalla. Las colisiones convierten
al jugador; el chequeo de fuera de pista también.

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
MAXSPD_HI  = 4      ; velocidad maxima con gomas nuevas (px por cuadro);
                     ; el tope real en carrera es curCapHi/Lo, que baja con
                     ; el desgaste -- ver "Gomas" en docs/reglas-juego.md
LAP_LEN    = 3000   ; unidades de distancia por vuelta
TOTAL_LAPS = 6
ROAD_L     = 48     ; borde izquierdo del asfalto
ROAD_R     = 128    ; borde derecho
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
| `docs/entorno.md` | Cómo dejar la máquina en condiciones de correr `make test` (Linux, macOS y Windows) |
| `docs/nes-cheatsheet.md` | Registros de PPU, OAM, atributos, paletas, timing NTSC |
| `docs/roadmap.md` | Mejoras sueltas del motor, ordenadas por cuánto lo rompen |

Cuando cambien las reglas del juego, se actualiza `docs/reglas-juego.md`, no
este archivo. Acá va solo lo que no cambia: cómo está construido, qué no
permite el hardware y cómo se verifica.
