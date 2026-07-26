# Ideas pendientes

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

## 3. Rival que pelee la punta

Hoy los rivales van derecho en su carril. Un rival "jefe" que se mantenga cerca
de tu posicion, cambie de carril para bloquearte y acelere si lo pasas cambia
por completo la sensacion del juego. Es maquina de estados pura, sin costo de
PPU.

## 4. Posicion en carrera

Hace falta llevar la distancia recorrida de cada rival (16 bits cada uno) y
ordenarlos contra la tuya. Con eso el HUD muestra "P3/5" y la pantalla de meta
tiene podio. Cuidado con el presupuesto de sprites del HUD: ya hay 7 en esa
linea.

## 5. Curvas

El cambio grande. Rompe el truco actual del scroll (ver CLAUDE.md), porque el
circuito deja de ser vertical y uniforme. Dos caminos:

- **Scroll horizontal del fondo entero**: el circuito se desplaza en X segun la
  curva y el auto pelea contra la fuerza lateral. Barato pero se ve plano.
- **Filas nuevas escritas en el NMI**: el clasico. Cada vez que el scroll
  avanza 8 px hay que escribir una fila de 32 tiles arriba o abajo, y con eso
  el circuito puede tener cualquier forma. Hay que armar un buffer de fila y
  medir bien los ciclos del NMI.

Si se va por el segundo camino, conviene hacerlo antes que cualquier otra cosa
de esta lista: cambia como se dibuja todo.

## 6. Circuitos y clima

Con las filas dinamicas ya hechas, cambiar la paleta y los tiles por circuito
sale casi gratis: nocturno, mojado con las lineas mas apagadas, etc.
