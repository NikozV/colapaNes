# Reglas del juego — Gran Premio NES

Especificación funcional del fin de semana de carrera completo. Esto es **qué**
tiene que pasar, no cómo implementarlo. Todos los números son puntos de partida
para tunear, no verdades reveladas.

Estado: **diseñado, no implementado.** Lo que hay hoy en la ROM es una carrera
suelta de 3 vueltas con 4 rivales genéricos.

---

## 1. El fin de semana

```
TITULO -> QUALY -> PARRILLA -> CARRERA -> RESULTADO
```

Dos sesiones, corridas de una. No hay entrenamientos libres: no aportan nada
jugable y comen ROM.

## 2. La parrilla: 22 pilotos, 11 equipos

Temporada 2026. El jugador es **Colapinto (COL), Alpine, #43**.

| # | Cód | Piloto | Equipo | Ritmo equipo | Habilidad |
|---|---|---|---|---|---|
| 1 | NOR | Lando Norris | McLaren | 95 | 95 |
| 2 | PIA | Oscar Piastri | McLaren | 95 | 94 |
| 3 | LEC | Charles Leclerc | Ferrari | 92 | 95 |
| 4 | HAM | Lewis Hamilton | Ferrari | 92 | 93 |
| 5 | VER | Max Verstappen | Red Bull | 92 | 99 |
| 6 | HAD | Isack Hadjar | Red Bull | 92 | 85 |
| 7 | RUS | George Russell | Mercedes | 90 | 93 |
| 8 | ANT | Kimi Antonelli | Mercedes | 90 | 87 |
| 9 | ALB | Alex Albon | Williams | 85 | 88 |
| 10 | SAI | Carlos Sainz | Williams | 85 | 90 |
| 11 | ALO | Fernando Alonso | Aston Martin | 84 | 92 |
| 12 | STR | Lance Stroll | Aston Martin | 84 | 78 |
| 13 | LAW | Liam Lawson | Racing Bulls | 83 | 82 |
| 14 | LIN | Arvid Lindblad | Racing Bulls | 83 | 76 |
| 15 | HUL | Nico Hülkenberg | Audi | 82 | 87 |
| 16 | BOR | Gabriel Bortoleto | Audi | 82 | 82 |
| 17 | OCO | Esteban Ocon | Haas | 82 | 85 |
| 18 | BEA | Oliver Bearman | Haas | 82 | 84 |
| 19 | GAS | Pierre Gasly | Alpine | 80 | 87 |
| 20 | **COL** | **Franco Colapinto** | **Alpine** | 80 | — (jugador) |
| 21 | PER | Sergio Pérez | Cadillac | 76 | 86 |
| 22 | BOT | Valtteri Bottas | Cadillac | 76 | 85 |

Los ritmos son subjetivos y están para tunear. La regla de diseño es que el
Alpine sea **claramente medio de parrilla**: el jugador tiene que ganar puestos
manejando bien, no porque el auto sea rápido.

Cada equipo tiene un color de paleta NES para su auto. Con 4 paletas de sprite
disponibles y una tomada por el jugador, quedan 3: los rivales en pantalla se
pintan con la paleta más cercana a su equipo, no con el color exacto. El color
exacto sí se usa en las tablas de texto (clasificación, parrilla, resultado),
que son de fondo y tienen sus propias 4 paletas.

## 3. Qualy

Sesión de una sola vuelta lanzada.

1. Arrancás **parado en boxes**. Con START salís al pit lane.
2. **Vuelta de salida**: no cuenta el tiempo. Sirve para calentar gomas y
   cargar energía. Las gomas arrancan frías (agarre reducido) y se calientan a
   lo largo de la vuelta.
3. **Vuelta lanzada**: se cronometra desde que cruzás la línea. Un solo intento.
4. Al terminar, tu tiempo se ordena contra los 21 tiempos de la IA y sale la
   parrilla.

**Tiempos de la IA**: no se simulan manejando. Se generan con una fórmula:

```
tiempo = tiempo_base
       - (ritmo_equipo + habilidad_piloto) * factor
       + azar(0, margen)
```

El azar es lo que hace que la qualy valga la pena repetirla: un Cadillac puede
colarse en Q3 y un McLaren puede arruinarla. El margen recomendado es chico
(unas décimas) para que el orden general siga respetando la jerarquía.

**Reglas**:

- Salirse de la pista con las cuatro ruedas **borra la vuelta**. Sin excepción:
  es la regla que le da tensión a la sesión.
- Excederse en el límite de velocidad del pit lane al salir: la vuelta se borra
  también.
- Si no completás la vuelta, largás último.

## 4. Carrera

Largás **desde el puesto que sacaste en la qualy**. Ese es el punto de todo el
sistema: la qualy tiene consecuencia directa.

- Distancia: 10 vueltas por defecto (parámetro `TOTAL_LAPS`).
- Largada parado con semáforo. Adelantarse = penalización de 5 segundos que se
  suma al tiempo final.
- Las posiciones se calculan por **distancia total recorrida** (vuelta actual ×
  largo de vuelta + distancia en la vuelta), ordenando los 22 valores.
- Los autos que no están en pantalla se simulan igual, con su ritmo base más
  una variación chica por vuelta. Solo los que están cerca tuyo se dibujan.

**Puntos**: 25-18-15-12-10-8-6-4-2-1 para los diez primeros.

## 5. Gomas

Tres compuestos. Elegís con cuál largás y cuál ponés en cada parada.

| Compuesto | Agarre | Desgaste | Vueltas útiles |
|---|---|---|---|
| Blando | 100 % | rápido | ~4 |
| Medio | 94 % | medio | ~7 |
| Duro | 88 % | lento | ~11 |

**Desgaste** (`0` nueva, `100` destruida):

- Sube cada vuelta según el compuesto.
- Sube **más rápido** si vas al límite: rozar los pianos, frenadas fuertes,
  salidas de pista.
- Sube más rápido si vas con el auto lleno de energía descargando turbo.

**Efecto del desgaste sobre el agarre**:

```
0-50 %    sin efecto notable
50-75 %   velocidad máxima -5 %, el auto se mueve más despacio de carril
75-90 %   velocidad máxima -12 %, se va de largo si frenás tarde
90-100 %  velocidad máxima -25 %, riesgo de trompo al pisar un piano
100 %     pinchadura: quedás a velocidad de pit lane hasta que pares
```

**Temperatura**: las gomas arrancan frías después de una parada y tardan una
vuelta en llegar a temperatura. Durante ese tiempo, agarre reducido.

**Regla de los dos compuestos**: en carrera hay que usar al menos dos
compuestos distintos. Si terminás sin cumplirla, descalificado. Esto obliga a
parar al menos una vez y es lo que hace que exista la estrategia.

## 6. Boxes

**Entrada**: carril a la derecha, señalizado unos metros antes de la línea.
Hay que meterse antes del punto de entrada o te pasás de largo.

**Límite de velocidad**: 60 % de la velocidad máxima. Pasarse suma una
penalización de 5 segundos. El HUD avisa cuando entrás a la zona limitada.

**El menú de la parada**: cuando entrás al pit lane se abre un menú, con el
juego pausado. Opciones:

```
GOMAS:  BLANDO / MEDIO / DURO
ALA:    -1 / MANTENER / +1
```

El ala delantera es un cambio de compromiso: más ala da más agarre en curva y
menos velocidad en recta, menos ala al revés.

**Tiempo de parada**: 2,5 segundos de base. Los mecánicos pueden fallar: hay
una probabilidad chica de una parada lenta de 5 a 8 segundos. Sumado al pit
lane, una parada cuesta unos 20 segundos.

**Doble parada**: permitida, y a veces es la estrategia correcta si se te
destruyen las gomas.

## 7. Turbo / Energía (ERS)

Barra de energía de 0 a 100, al estilo del reglamento 2026.

**Se carga**:

- En las **curvas**, mientras frenás y girás. Cuanto más cerrada la curva, más
  carga.
- En la frenada de una recta larga.
- Yendo en el rebufo de otro auto (menos carga, pero suma).

**Se descarga**: con un botón. Mientras lo mantenés apretado, la velocidad
máxima sube un 15 % y la barra baja. Con la barra en cero, no hay turbo.

**Reglas**:

- No se puede descargar en el pit lane.
- Descargar con las gomas por encima del 75 % de desgaste acelera el desgaste
  todavía más: el turbo tienta y castiga.
- La IA también lo usa, y lo usa para defender: si venís pegado a un rival en
  la recta, lo va a activar.

> **Dependencia importante**: "se carga en las curvas" no se puede implementar
> hasta que el circuito tenga curvas. Ver `docs/roadmap.md` punto 5 y la
> sección de fases más abajo.

## 8. Clasificación en pantalla — HECHA (fase 2)

Lo que pediste — el panel de la izquierda con los 22 pilotos y sus puestos —
choca con una limitación real del hardware, así que se resolvió en dos partes.

**Por qué no se puede tal cual**: el circuito hace scroll vertical, y el fondo
es una sola capa. Un panel dibujado en el fondo **scrollea con la pista**. Para
dejarlo quieto habría que cambiar la dirección de la PPU en el medio de cada
línea de barrido, algo que casi ningún juego de NES hace porque es carísimo en
ciclos. Los paneles laterales fijos son típicos de juegos con scroll
horizontal, no vertical.

**Solución en dos partes**:

1. **Durante la carrera: ventana móvil de sprites** (`BuildRankWindow`). Sobre
   el margen izquierdo, **tres líneas**: el que tenés adelante, vos, y el que
   tenés atrás. Es la información que de verdad sirve manejando — contra quién
   estás peleando — y con tres líneas separadas 16 px se lee mucho mejor que
   con cinco apretadas de a 8 px, que fue el primer intento y resultó ilegible
   al jugarlo. La línea del jugador lleva un `!` adelante en vez de un color
   distinto (las 4 paletas de sprite ya están asignadas: jugador, rival rojo,
   rival plateado, texto). En los extremos la ventana se desliza: de puntero
   muestra P1-P2-P3, de último los dos de adelante y vos.

   ```
   P07 GAS
   !P08 COL   <- vos, resaltado
   P09 OCO
   ```

   El presupuesto de sprites por línea de barrido sigue siendo real: un auto
   de tráfico decorativo puede caer en la misma scanline que una línea de la
   ventana y hacer parpadear algún sprite ese cuadro. Se acepta como
   limitación de hardware documentada (igual que las curvas escalonadas de la
   fase 1): el orden en que se arman los sprites (jugador, HUD, ventana,
   autos al final) asegura que lo primero que se pierde en un desborde es
   siempre tráfico decorativo, nunca información real.

2. **Tabla completa de 22 en pantalla propia** (`EnterClass`, toggle con
   SELECT). Con el juego pausado se apaga el rendering y se escribe la
   pantalla completa sin límites: puesto, código, equipo y diferencia
   respecto al líder (como fracción de vuelta, `+D.D`). Como esta pantalla
   reusa las mismas dos nametables que el circuito curvo de la fase 1, hay
   que guardar el scroll, forzarlo a 0 para dibujar limpio, y reconstruir el
   trazado real (`RedrawTrack`, lee `rowCC` en vez de regenerar el trazado)
   antes de restaurarlo al salir — si no, el circuito queda roto o
   desalineado. La paleta de fondo es una sola para todo el texto (solo hay 4
   disponibles en total, no alcanzan para 11 colores de equipo distintos).
   Misma pantalla se va a reusar para la parrilla después de la qualy y para
   el resultado final.

## 9. HUD en carrera

Arriba, sobre el asfalto, con sprites:

```
V03/10                    GOMAS ▓▓▓▓░░  M
P08                       ERS   ▓▓▓▓▓▓░
```

Vuelta, puesto, barra de desgaste con la letra del compuesto, barra de energía.
Ojo con el presupuesto: máximo ocho sprites por línea de barrido.

## 10. Penalizaciones

| Infracción | Castigo |
|---|---|
| Vuelta de qualy con cuatro ruedas afuera | Vuelta borrada |
| Largada adelantada | +5 s |
| Exceso de velocidad en pit lane | +5 s |
| Terminar con un solo compuesto | Descalificado |
| Cortar la pista ganando ventaja | Devolver el puesto o +5 s |

---

## 11. Fases de implementación

El orden importa: hay dos cambios de infraestructura que tienen que ir primero
porque todo lo demás depende de ellos.

**Fase 0 — Cambio de mapper (bloqueante). HECHA.** Nada de esto entraba en
NROM: 16 KB de PRG ya tenían un juego adentro. El cartucho pasó a **MMC1
(mapper 1)**: 128 KB de PRG en 8 bancos de 16 KB, 32 KB de CHR y 8 KB de
PRG-RAM para el guardado del campeonato.

Se eligió MMC1 y no MMC3 como decía el plan original porque el emulador de los
tests (nes-py) solo soporta los mappers 0, 1, 2 y 3. Con MMC3 la ROM no abre y
se pierden `make test` y `make shots`, que son toda la forma de verificar que
el juego anda. Lo único que se resigna es la **IRQ por línea de barrido**: el
HUD fijo se va a tener que hacer con **sprite 0 hit**, que es lo mismo que usa
el Super Mario Bros para su barra de arriba.

**Fase 1 — Curvas. HECHA.** Rompió el truco del scroll: las dos nametables son
ahora un buffer circular de 60 filas, y cada 8 px de avance entra una fila
nueva escrita en el NMI. El asfalto se corre moviendo la columna del centro, de
a 2 columnas y solo en los bordes de bloque de atributos, que es lo que exige
que las paletas de fondo sean por bloques de 16 × 16 px. El detalle está en
`CLAUDE.md`.

Los rivales pasaron a vivir en coordenadas de pista, así que siguen la curva
solos. **El ERS ya tiene dónde cargarse.**

**Fase 2 — Los 22 pilotos. HECHA.** Tabla de 22 pilotos y 11 equipos en
`BANK3` (primer uso real del banking de MMC1 para algo que no fuera una
prueba), copiada a RAM una sola vez al arrancar la carrera. Cada IA tiene un
ritmo de punto fijo derivado de `ritmo_equipo + habilidad`, con un spread
calibrado para dar gaps del orden de una F1 real (una fracción de vuelta a lo
largo de la carrera), no vueltas enteras — Alpine queda por debajo de la
mediana, como pide la regla de diseño. La posición se recalcula todos los
cuadros comparando la distancia total de los 22 (el jugador incluido);
sección 8 tiene el detalle de la ventana móvil y la clasificación completa.

Sin qualy todavía (fase 3) no hay parrilla real, pero tampoco pueden arrancar
todos en la misma distancia (quedarían encimados): se escalonan `GRID_STEP`
unidades en el orden de la tabla, con el jugador largando desde el medio del
pelotón.

**Los autos que se ven en pantalla son los rivales reales de la
clasificación**, no tráfico decorativo. Cada cuadro se toman los puestos
vecinos al del jugador y se los ubica en pantalla según la diferencia de
distancia total: adelantar un auto en pantalla es adelantarlo de verdad en la
tabla. (El primer intento de esta fase los mantuvo como sistemas separados, y
jugándolo se notaba enseguida: pasabas autos que no estaban en la carrera.)

**Calibración del ritmo, medida y no supuesta.** Corriendo la ROM con un
piloto automático, el jugador rinde ~3.19 unidades/cuadro solo apretando
acelerador, ~3.49 siguiendo el asfalto, ~3.82 esquivando además los autos, y
4.00 en el caso perfecto. El rango de la IA va de 3.148 a 3.773.

La regla de la calibración: **ningún rival corre más rápido que un jugador
limpio** (a cualquiera lo podés alcanzar), pero los de arriba, cuando los
tenés encima, **defienden** y ahí sí te superan. Los choques pasan a ser lo
que decide la carrera: en la simulación, los 5 choques de un piloto
automático decente equivalen casi exactamente a las 980 unidades con que el
líder le gana.

Hicieron falta tres pasadas, cada una detectada jugando y no leyendo: la
primera dejó la IA entera por debajo del jugador (se ganaba siempre), la
segunda por debajo de un jugador que esquiva (se ganaba siempre que no
chocaras), y recién la tercera obligó a manejar limpio *y* pelear.

**Defensa por piloto** (`defBonusTab`): cuando el jugador entra en
`DEFEND_RANGE`, el rival aprieta según su **habilidad**, no según su auto —
`(habilidad - 76) * 2`. Verstappen aprieta 46, el último de la parrilla 0. Es
lo que hace que pasar a un piloto de jerarquía cueste y pasar a un colista
no: el ritmo base lo pone el equipo, pelear el paso lo pone el piloto. Vale
para los dos lados, así que si lo pasás te lo intenta devolver.

**Fase 3 — Qualy y parrilla. HECHA.** El fin de semana ahora arranca por la
qualy: se sale detenido, la primera vuelta no cronometra (vuelta de salida) y
la segunda sí. El cronómetro cuenta **cuadros**, no segundos, porque las
diferencias que deciden la parrilla son de décimas; la conversión a `SS.CC` se
hace una sola vez al mostrar.

Los 21 tiempos de la IA salen de la fórmula de la sección 3, calibrada contra
lo medido: van de 780 a 940 cuadros, el mismo escalonamiento que sus ritmos de
carrera, así que la parrilla es coherente con lo que después pasa en pista.

Salirse con las cuatro ruedas anula la vuelta (se mira el **centro** del auto,
no su borde, que es lo que ya marcaba `offRoad`), y sin vuelta válida se larga
último. La carrera larga desde el puesto obtenido: es lo que le da
consecuencia a la sesión.

**Lo que quedó afuera por depender de boxes (fase 4)**: arrancar en boxes,
salir por el pit lane y su límite de velocidad, y las gomas frías de la vuelta
de salida. No es una simplificación por comodidad — el pit lane es geometría
de pista que todavía no existe.

**Largada parada.** La qualy destapó un problema que antes no se veía: el
jugador arranca detenido y su distancia crece con la parte *entera* de su
velocidad, así que en los primeros 85 cuadros acumula 127 unidades donde a
fondo acumularía 340. La IA no tenía modelo de aceleración y salía a ritmo
pleno desde el primer cuadro, sacándole unos 6 puestos y borrando justo lo que
la qualy acababa de decidir. Ahora la IA acelera con la misma curva que el
jugador (`launchSpd`, sin su fracción de ritmo): la diferencia en la largada
quedó en un puesto.

**Fase 4 — Gomas y boxes.** Desgaste, compuestos, entrada al pit lane, menú de
parada, regla de los dos compuestos, penalizaciones.

**Fase 5 — ERS.** Carga en curvas y frenadas, descarga por botón, uso
defensivo de la IA, interacción con el desgaste.

**Fase 6 — Campeonato.** Varias carreras, puntos acumulados, tabla de
posiciones del campeonato. Necesita guardar partida: PRG-RAM con batería, que
MMC3 soporta.

Cada fase tiene que terminar con `make test` en verde y sus propios checks
agregados a `tools/probe.py`.
