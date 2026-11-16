# Montar la mesa de tu juego (editor de juegos)

En el editor de juegos (menú → «Crear juegos») la mesa verde es tu juego: pones piezas,
las colocas, las pintas y las pruebas con física de verdad.

![Mesa del editor con un tablero, peones, un mazo, un dado y monedas](img/editor-mesa.png)

## Poner piezas

En la pestaña **Piezas** del panel izquierdo hay ocho formas: **ficha, carta, dado, disco,
peón, bloque, moneda y tablero**. Cada pulsación pone una pieza en un hueco libre cerca del
centro. Si debajo hay otra pieza (un tablero, por ejemplo) la nueva se posa encima.

El **tablero** nace **fijo**: no se arrastra por accidente y al probar no se mueve. Cualquier
pieza puede fijarse o soltarse con la casilla «Fija» del inspector.

## Seleccionar

- **Clic** en una pieza la selecciona; **Ctrl o Mayús + clic** la añade o la quita.
- **Arrastrar en un hueco** dibuja un recuadro y selecciona lo que queda dentro.
- La **lista «Piezas en la mesa»** (arriba a la derecha) también selecciona, una o varias.
  Cada pieza lleva un punto de su color y un candado si está fija.
- **Ctrl+A** selecciona todo; **Esc** suelta la selección (y, sin selección, vuelve al menú).

Lo seleccionado se marca con un aro amarillo en la base y esquinas que se ven a través de
otras piezas; al pasar el ratón por encima de una pieza se marca en blanco.

## Mover, girar y cambiar

| Acción | Cómo |
|---|---|
| Mover | Arrastrar. Con el **imán** (G) cae en una cuadrícula de 10 cm; Mayús lo desactiva mientras arrastras. Las piezas se **apilan solas** al soltarlas encima de otra. |
| Copiar arrastrando | Alt + arrastrar |
| Mover un paso | Flechas (Mayús: 5 pasos), según se ve la mesa |
| Subir / bajar | RePág / AvPág |
| Girar | Q / E de 15 en 15 (Mayús: 5°), o la rueda mientras arrastras |
| Voltear | F (cartas boca abajo, fichas del revés) |
| Tamaño | + / − o el campo «Tamaño» (del 25 % al 400 %) |
| Duplicar | Ctrl+D o el botón «Duplicar» |
| Copiar y pegar | Ctrl+C / Ctrl+V |
| Quitar | Supr o el botón «Quitar» |

El **inspector** (derecha) cambia el nombre, la forma, el color (diez de la paleta u otro
cualquiera), la posición exacta (X, Z, altura), el giro, el tamaño y el peso. Con varias
piezas seleccionadas, los cambios van a todas. «Poner imagen» usa la imagen elegida en la
pestaña **Imágenes**; «Sin imagen» la quita.

Con varias piezas, **Ordenar la selección** ofrece:

- **En fila**: las alinea con un hueco entre ellas.
- **Apilar**: una encima de otra sobre la primera (mazos de cartas, torres de fichas).
- **Centrar**: lleva el grupo al centro de la mesa sin deshacer su forma.

## Deshacer, guardar y cargar

- **Ctrl+Z** deshace y **Ctrl+Y** (o Ctrl+Mayús+Z) rehace cualquier cambio de la mesa,
  también la selección que había. Teclear un número o girar varias veces seguidas se deshace
  de una vez. Los botones ↶ ↷ hacen lo mismo.
- **Guardar / Cargar** (pestaña Piezas, o **Ctrl+S**) conservan la mesa en este equipo.
  Un archivo dañado o con piezas imposibles se rechaza y la mesa actual no se toca.
- **Vaciar** quita todas las piezas; Ctrl+Z las recupera.

## Cámara

- **Botón derecho**: orbitar alrededor de la mesa.
- **Botón central** o **Mayús + derecho**: desplazar.
- **Rueda**: acercar y alejar.
- **C** o **doble clic**: enfocar la selección. **Inicio**: volver a la vista inicial.

**F1** muestra todos estos atajos dentro del editor.

## Probar

«Probar la mesa» aparta los paneles: las piezas caen con física (las fijas se quedan) y la
interfaz diseñada funciona. «Volver a editar» devuelve cada pieza a donde la pusiste.
