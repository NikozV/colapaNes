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

## 8. Clasificación en pantalla

Lo que pediste — el panel de la izquierda con los 22 pilotos y sus puestos —
choca con una limitación real del hardware, así que se resuelve en dos partes.

**Por qué no se puede tal cual**: el circuito hace scroll vertical, y el fondo
es una sola capa. Un panel dibujado en el fondo **scrollea con la pista**. Para
dejarlo quieto habría que cambiar la dirección de la PPU en el medio de cada
línea de barrido, algo que casi ningún juego de NES hace porque es carísimo en
ciclos. Los paneles laterales fijos son típicos de juegos con scroll
horizontal, no vertical.

**Solución en dos partes**:

1. **Durante la carrera: ventana móvil de sprites.** Sobre el margen izquierdo,
   los puestos cercanos al tuyo: dos arriba, el tuyo, dos abajo. Cinco líneas
   de `P08 COL` a cuatro o cinco sprites por línea. Cada línea cae en scanlines
   distintas, así que no rompe el límite de ocho sprites por línea, y el total
   deja lugar para los autos.

   ```
   P06 SAI
   P07 GAS
   P08 COL   <- vos, resaltado
   P09 OCO
   P10 HUL
   ```

   Es además la información que de verdad te sirve manejando: contra quién
   estás peleando.

2. **Tabla completa de 22 en pantalla propia.** Con SELECT se pausa y se dibuja
   la clasificación entera, con puesto, código, equipo y diferencia. Con el
   juego pausado se puede apagar el rendering y escribir la pantalla completa
   sin límites. Misma pantalla se usa para la parrilla después de la qualy y
   para el resultado final.

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

**Fase 2 — Los 22 pilotos.** Tablas de datos, simulación de los que no están en
pantalla, cálculo de posiciones, ventana móvil de sprites y pantalla de
clasificación completa. Sin gomas ni boxes todavía: solo que la carrera tenga
22 autos y un orden coherente.

**Fase 3 — Qualy y parrilla.** Estado nuevo, salida de boxes, cronómetro,
generación de tiempos de la IA, pantalla de parrilla, y la carrera largando
desde el puesto obtenido.

**Fase 4 — Gomas y boxes.** Desgaste, compuestos, entrada al pit lane, menú de
parada, regla de los dos compuestos, penalizaciones.

**Fase 5 — ERS.** Carga en curvas y frenadas, descarga por botón, uso
defensivo de la IA, interacción con el desgaste.

**Fase 6 — Campeonato.** Varias carreras, puntos acumulados, tabla de
posiciones del campeonato. Necesita guardar partida: PRG-RAM con batería, que
MMC3 soporta.

Cada fase tiene que terminar con `make test` en verde y sus propios checks
agregados a `tools/probe.py`.
