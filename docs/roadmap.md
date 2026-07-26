# Mejoras del motor

> Las funcionalidades del juego (qualy, gomas, boxes, ERS, los 22 pilotos)
> **no van aca**: estan en `reglas-juego.md`, con su propio orden de fases.
> Este archivo es para mejoras del motor que no cambian las reglas.

Ordenadas de menos a mas invasivas. Las primeras no tocan el motor; las
ultimas lo reescriben.

## 1. Largada con semaforo

Estado nuevo entre el titulo y la carrera: tres luces rojas que se apagan, con
blips en el canal de pulso, y recien ahi se habilita el control. Baratisimo:
son cuatro sprites y un contador. Bonus: penalizar la largada adelantada.

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
