# Mejoras del motor

> Las funcionalidades del juego (qualy, gomas, boxes, ERS, los 22 pilotos)
> **no van aca**: estan en `reglas-juego.md`, con su propio orden de fases.
> Este archivo es para mejoras del motor que no cambian las reglas.

Ordenadas de menos a mas invasivas. Las primeras no tocan el motor; las
ultimas lo reescriben.

## 1. Largada con semaforo

Estado nuevo entre la parrilla y la carrera: tres luces rojas que se apagan,
con blips en el canal de pulso, y recien ahi se habilita el control.
Baratisimo: son cuatro sprites y un contador. Bonus: penalizar la largada
adelantada.

La MECANICA de largada parada ya existe desde la fase 3 (`startRamp` /
`launchSpd` en `UpdateAI`): el jugador arranca detenido y la IA acelera con la
misma curva, asi que la largada es pareja. Lo que falta es solo la parte
visual del semaforo y la penalizacion por adelantarse.

## 2. Musica

Los dos canales de pulso estan libres (solo se usan para blips puntuales) y el
triangulo esta sin tocar. Alcanza con un reproductor chico dirigido por tablas:
una lista de (nota, duracion) por canal y un puntero que avanza en cada cuadro.
Ojo con los ciclos: la rutina corre en el bucle principal, no en el NMI.

## 3. Curvas — HECHA

Se fue por el camino de las **filas nuevas escritas en el NMI**, no por el
scroll horizontal del fondo entero. Cada 8 px de avance entra una fila de 32
tiles armada en el bucle principal, y con eso el circuito puede tener cualquier
forma. Cuesta unos 480 ciclos de los 1727 que quedan libres en el vblank
despues del DMA de sprites, mas 120 cuando ademas toca reescribir atributos.

Lo que quedo pendiente y se puede mejorar:

- Las curvas son **escalonadas de a 16 px**, porque los atributos mandan (ver
  CLAUDE.md). Si alguna vez se quiere una curva mas suave, habria que angostar
  el asfalto o resignar el piano de dos colores.
- Los autos son sprites rigidos de 16x16 sobre una pista que dobla, asi que en
  las curvas mas cerradas pueden pisar el piano unos pixeles. Se puede achicar
  calculando el desplazamiento a la altura del CENTRO del auto y no de su
  borde de arriba.
- El trazado es una tabla de segmentos fija (`segLen` / `segDelta`) que se
  repite. Cuando existan varios circuitos, va a querer vivir en un banco.

## 4. Circuitos y clima

Con las filas dinamicas ya hechas, cambiar la paleta y los tiles por circuito
sale casi gratis: nocturno, mojado con las lineas mas apagadas, etc.

## 5. Los 22 pilotos — HECHA, con trade-offs documentados

Tabla en BANK3, simulacion por distancia total, ventana movil y clasificacion
completa (fase 2). Lo que quedo pendiente:

- **La ventana de posiciones puede parpadear.** Vive en el margen izquierdo
  (fuera del asfalto) pero el limite de 8 sprites por linea de barrido es por
  scanline completa, sin importar la columna: si un auto de trafico
  decorativo cae en la misma altura que una linea de la ventana, algun
  sprite de esa linea se pierde ese cuadro. `BuildOAM` prioriza jugador, HUD
  y ventana antes que los autos decorativos, asi que lo que se pierde
  primero es siempre lo cosmetico -- pero el parpadeo en si no se elimino,
  se acepto como limitacion de hardware (misma categoria que las curvas
  escalonadas del punto 3).
- ~~El trafico visual y el ranking real son sistemas separados~~ **Unificados
  despues de jugarlo.** El plan original los dejaba separados (los 4 autos en
  pantalla eran decorativos), pero al probar la ROM se notaba enseguida que
  pasabas autos que no estaban en la carrera. Ahora `BuildCars` recorre los
  22 por indice (no por puesto: con el peloton compacto, una ventana de
  puestos cercanos se salteaba autos que si estaban en pantalla) y ubica a
  cada uno segun la diferencia de distancia total: adelantar en pantalla es
  adelantar en la tabla. Con mas de `MAX_CARS` en rango a la vez, se quedan
  los que estan mas cerca del centro de la pantalla.
- **El pace de los 21 IA es una constante fija por piloto**, sin variacion
  segun el circuito ni condiciones de carrera (solo un reroll chico por
  vuelta, ver `ApplyLapVariation`). Cuando existan gomas (fase 4) el pace
  real va a depender del desgaste, no solo de la tabla estatica.
- **La IA defiende pero nada mas**: cuando el jugador se le acerca aprieta
  segun su habilidad (defBonusTab), y con eso alcanza para que pasar a un
  Verstappen cueste. Pero no se equivoca nunca, no frena detras de otro auto,
  no pelea entre ellos y no cambia de carril. Los autos se pueden superponer
  entre si en pantalla: solo el jugador colisiona.
- **El carril de cada auto sale de su indice de piloto**, no de una decision
  de carrera: dos rivales que corren juntos siempre van a estar en los mismos
  dos carriles. Alcanza para que no se tapen, pero no hay lucha por la linea.

## 6. Pista angosta y panel unificado — HECHA

La pista pasa de 24 a 16 tiles (`TRACK_HW`, `ROAD_L`/`ROAD_R`,
`TRACK_CC`/`CC_MIN`/`CC_MAX` en `src/main.s`): antes medían 192 px, diez autos
de ancho, desproporcionado. Y todo el HUD (vuelta, puesto, velocidad, ventana
de posiciones) pasa a vivir junto en una franja fija a la derecha (`HUD_X`),
en vez de repartido en dos filas arriba mas la ventana en el margen
izquierdo. Las dos cosas se pidieron juntas porque son la misma resolucion:
angostar la pista es lo que deja lugar para el panel sin que se superpongan
nunca, verificado a nivel de pixel (1500 cuadros con curvas de los dos
lados, cero invasiones).

Efecto colateral que hubo que resolver: con la pista angosta, `PLAYER_X0`
(el centro geometrico) quedaba a 11 px de un carril -- adentro del radio de
choque de 13 px. Ir derecho por el medio de la pista chocaba SIEMPRE contra
cualquiera que estuviera ahi. Los 4 carriles se reacomodaron en dos pares
con un hueco central de 36 px, dejando el centro a 17 px o mas de cualquier
carril.

Pendiente para cuando existan los boxes (fase 4): la franja angosta que
sobra deja lugar de sobra para el pit lane, que era el motivo original del
pedido.
