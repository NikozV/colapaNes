# Chuleta de NES para este proyecto

## Registros de PPU

| Reg | Que hace |
|---|---|
| `$2000` PPUCTRL | bit7 NMI on, bit4 pattern table del fondo, bit3 pattern de sprites, bits0-1 nametable |
| `$2001` PPUMASK | bit3 mostrar fondo, bit4 mostrar sprites, bits1-2 mostrar en la columna izquierda |
| `$2002` PPUSTATUS | leerlo resetea el latch de direccion. Siempre leer antes de escribir $2005/$2006 |
| `$2003` OAMADDR | poner en 0 antes del DMA |
| `$2005` PPUSCROLL | dos escrituras: X y despues Y |
| `$2006` PPUADDR | dos escrituras: byte alto y despues bajo |
| `$2007` PPUDATA | dato; autoincrementa 1 o 32 segun PPUCTRL bit2 |
| `$4014` OAMDMA | escribir el byte alto de la pagina (aca $02) copia 256 bytes a la OAM |

## Memoria de video

```
$2000  nametable 0   (32x30 tiles)
$23C0  atributos 0   (64 bytes, 1 byte por bloque de 32x32 px)
$2800  nametable 2   (con mirroring horizontal, la de "abajo")
$3F00  paletas de fondo    (4 paletas x 4 colores)
$3F10  paletas de sprites  (4 paletas x 4 colores)
```

Direccion de un tile: `$2000 + fila*32 + columna`.

## Byte de atributos

Un byte cubre 32x32 px = 4 bloques de 16x16:

```
bits 0-1: arriba izquierda    bits 2-3: arriba derecha
bits 4-5: abajo izquierda     bits 6-7: abajo derecha
```

## OAM: 4 bytes por sprite

```
+0  Y (se dibuja una linea mas abajo: restar 1)
+1  numero de tile
+2  atributos: bits0-1 paleta, bit5 detras del fondo, bit6 flip H, bit7 flip V
+3  X
```

Poner Y en $FF (o cualquier valor >= 240) esconde el sprite.

## Colores utiles de la paleta NES

```
$0F negro     $30 blanco    $00 gris      $10 gris claro
$12 azul      $16 rojo      $1A verde     $2A verde claro
$27 naranja   $25 rosa      $21 celeste   $28 amarillo
```

## Timing NTSC

- 60 cuadros por segundo, 29780 ciclos de CPU por cuadro
- El vblank dura unos 2270 ciclos: es TODO el presupuesto para escribir a la PPU
- El DMA de sprites se come 513 ciclos de esos
