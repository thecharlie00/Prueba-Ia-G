# El editor de Tablerama frente a Tabletop Simulator

Análisis de cómo se crean mods en Tabletop Simulator (TTS) y qué hace el editor de juegos
de Tablerama para que crear sea más fácil. Fuentes: la base de conocimiento oficial de TTS
(kb.tabletopsimulator.com), su API de Lua (api.tabletopsimulator.com), el blog oficial y
guías y comentarios de la comunidad (noviembre de 2026).

## Cómo se hace un mod en TTS

1. **Imágenes alojadas fuera.** Las piezas personalizadas (mazo, tablero, ficha, modelo)
   piden la URL de una imagen o de un modelo. Hay que subirlas a una web y pegar el enlace;
   si el enlace muere, el mod se rompe para todos los suscriptores. Es la queja más repetida
   de los creadores: mods con miles de enlaces rotos.
2. **Mazos con herramienta aparte.** Un mazo sale de una «hoja» con todas las cartas en
   rejilla. Se monta con plantillas o con el *Deck Builder*, un programa que viene en la
   carpeta de Steam del juego, y luego se pega la URL de la hoja y la del reverso.
3. **Modelos sólo en OBJ** y *asset bundles* que piden Unity.
4. **Herramientas de mesa:** *snap points* (con o sin giro), zonas (mano, oculta, mezclar,
   niebla, disposición), etiquetas, estados de un objeto, contadores, bolsas.
5. **Lógica con Lua**: un script global y uno por objeto, con eventos; cualquier automatismo
   (repartir, puntuar, preparar la mesa) se programa.
6. **Publicación** en Steam Workshop desde el propio juego.

## Qué hace Tablerama (ya hecho)

| Necesidad | Tabletop Simulator | Tablerama |
|---|---|---|
| Imágenes de las piezas | URL en una web externa; enlaces que se rompen | Se importan del disco; el juego exportado las lleva **dentro** de un solo archivo `.tablerama` |
| Mazo de cartas | Plantilla o *Deck Builder* aparte + subir la hoja | **Mazo desde la hoja elegida** (columnas, filas, cuántas) o **una carta por imagen**, dentro del editor |
| Reverso | Otra URL | **Poner reverso** a toda la selección; se ve al voltear |
| Tableros | Imagen propia | Además, **dibujos generados**: ajedrez, casillas, recorrido, cruces de go (2–19 casillas) |
| Texto en piezas | Hay que dibujarlo en la imagen | **Texto en la pieza** y **Numerar** 1, 2, 3… |
| Dados | Plantillas de imagen | Dados con puntos al instante; al probar, el resultado se lee solo |
| *Snap points* | Herramienta aparte, visibles sólo con ella | **Anclajes** como piezas: se mueven, giran, se copian y se deshacen como cualquier otra |
| Zona de mezclar | Al cargar la partida | **Mezclar lo de dentro al probar**, además de **Mezclar** a mano |
| Empezar | Mesa vacía o mods de otros | **Plantillas** (damas, carrera, cartas, dados) listas para cambiar |
| Deshacer | *Rewind* por tiempo | **Ctrl+Z / Ctrl+Y** de cualquier cambio, con la selección |
| Colocar | Gizmo, rejilla | Arrastrar con imán, apilado automático, flechas, rejillas de copias, en fila, apilar, centrar |
| Probar | Es el mismo modo | **Probar la mesa** y volver a editar: todo vuelve a su sitio |
| Idiomas | Inglés en las herramientas | Editor en español, inglés y catalán |

## Lo que TTS tiene y aún falta (siguientes pasos propuestos)

1. **Reglas sin programar** (en lugar de Lua): bloques «cuando… entonces…» (al pulsar un
   botón, al soltar en una zona, al empezar) con acciones (repartir N cartas, mover a una
   zona, sumar a un contador, tirar dados). Ya existe la base en las acciones de botones.
2. **Zonas de mano y ocultas** para el online: piezas que sólo ve su dueño.
3. **Estados de un objeto** (una pieza con varias caras, como una carta de doble cara).
4. **Bolsas** (incluida la infinita) y **contadores** en la mesa.
5. **Modelos 3D** (glTF/OBJ) importados, con la misma idea de llevarlos dentro del archivo.
6. **Publicar y descargar juegos** desde Tablerama (Steam Workshop o lista propia), cuando
   esté el online con Steam.
