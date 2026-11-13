# Diseñar la interfaz de tu juego (editor de juegos)

En el editor de juegos (menú → «Crear juegos») puedes montar la interfaz que verán los
jugadores: marcadores, botones, carteles, paneles e imágenes.

## Cómo se usa

1. En el panel izquierdo, bajo **Interfaz del juego · añadir**, pulsa el tipo de elemento:
   Texto, Botón, Panel, Imagen o Contador. Aparece en el centro de la pantalla del juego
   (el recuadro claro entre los dos paneles).
2. **Arrástralo** a su sitio. Para cambiarlo de tamaño, tira del cuadrado azul de su esquina
   inferior derecha.
3. Con el elemento seleccionado, el panel derecho deja cambiar su **texto**, el **tamaño de
   letra**, el **color del texto** y el **color de fondo** (o sin fondo).
4. Si es un **botón**, elige en «Al pulsarlo» qué hace:
   - sumar 1 o restar 1 a un contador,
   - tirar un dado (deja de 1 a 6 en un contador),
   - mostrar u ocultar otro elemento (por ejemplo, un panel de reglas).
5. Si es una **imagen**, importa primero la imagen, selecciónala en la galería y pulsa «Usar
   imagen seleccionada».
6. Pulsa **Probar la mesa**: los paneles del editor se apartan y la interfaz funciona de
   verdad. «Volver a editar» deja todo como estaba (probar no cambia el diseño).
7. **Guardar** y **Cargar** conservan la interfaz en este equipo.

## Cómo se adapta a cada pantalla

Cada elemento se sujeta solo al borde o esquina que tenga más cerca (el panel derecho lo
dice: «Se sujeta abajo a la derecha de la pantalla»). Así, un marcador puesto en una esquina
sigue en esa esquina en un monitor panorámico o en una Steam Deck, y todo crece o encoge
con la ventana.

## Límites actuales

- Hasta 60 elementos por interfaz.
- Las acciones de los botones son las cuatro de arriba; aún no hay reglas encadenadas ni
  turnos automáticos.
- La interfaz se guarda aparte de las piezas (`user://creador/interfaz.json`); todavía no se
  empaqueta como mod para compartir.

## Para quien toque el código

- `scripts/game_creator/ui/UiLayout.gd`: el modelo (lista de elementos, sujeciones, guardado
  y validación).
- `scripts/game_creator/ui/UiLayoutView.gd`: dibuja el diseño; modo diseño (mover, cambiar de
  tamaño) y modo juego (acciones).
- `tests/ui_designer.gd`: modelo, vista y uso desde el editor.
