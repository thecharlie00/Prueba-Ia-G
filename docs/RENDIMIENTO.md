# Rendimiento y calidad gráfica

El objetivo es que Tablerama vaya fluido en cualquier equipo, desde un portátil con gráficos
integrados de Intel hasta una GPU dedicada, sin que el estilo visual cambie de carácter.

## Dónde estaba el coste

Medido con `tools/bench.gd` (dibujo) y en modo headless (CPU):

- **CPU**: los scripts tardan 3 ms o menos por fotograma y la física (Jolt a 90 Hz) 0,6 ms o
  menos. No hace falta optimizarlos.
- **GPU**: aquí estaba todo el coste.
  - Las primitivas de Godot (esferas, cilindros, cápsulas y toros) usan 64 segmentos por
    defecto: unos 4.000 triángulos por esfera, aunque sea una ficha de 3 cm.
  - El contorno toon de `ToonStyle` es una segunda pasada (`next_pass`), así que duplica las
    llamadas de dibujo.
  - El sol usaba 4 cascadas PSSM, y cada pieza que proyecta sombra se vuelve a dibujar en cada
    una.
  - Las piezas diminutas (dados, fichas, decoración) también proyectaban sombra.

## Qué se ha hecho

- **Autoload `Graphics`** (`scripts/core/Graphics.gd`): tiene cuatro niveles (Automática, Baja,
  Media y Alta) y se elige en Ajustes, tanto en el menú como en la habitación, con la fila
  «Calidad gráfica».
  - **Automática** elige el nivel según la GPU (`guess_level`). Si el tiempo medio por
    fotograma supera los 24 ms durante 4 segundos, baja un nivel; nunca vuelve a subir.
- **Recorte de mallas** (`budget_mesh`): limita los segmentos de las primitivas según su
  tamaño (entre 12 y 32, multiplicados por el detalle del nivel) y deja los cilindros con un
  solo anillo. `PieceKit` escala con el mismo detalle los segmentos de torno, las cajas
  redondeadas y los perfiles suaves.
- **Contornos conmutables**: `ToonStyle.set_outlines()` quita o devuelve el `next_pass` sin
  rehacer los materiales.
- **Sombras**: Alta usa 2 cascadas; Media y Baja, proyección ortogonal. Por debajo de Alta, las
  piezas de menos de 22 cm no proyectan sombra.
- **Otros ajustes**:
  - En segundo plano, el juego se limita a 12 fps.
  - Las SubViewports respetan el límite de MSAA del nivel.
  - Baja limita el juego a 60 fps y renderiza el 3D al 75 % (la interfaz sigue nítida).

| Nivel | 3D | Sombras | Contornos | MSAA | Detalle | Límite fps |
|---|---|---|---|---|---|---|
| Baja | 75 % | no | no | no | 0,6 | 60 |
| Media | 100 % | ortogonal, piezas grandes | sí | 2× | 0,8 | — |
| Alta | 100 % | 2 cascadas, todas | sí | 4× | 1,0 | — |

En Baja, la luz direccional conserva `shadow_enabled` aunque ninguna pieza proyecte sombra.
En el renderer de compatibilidad, apagarla cambia cómo ilumina y la escena se ve un 25 % más
oscura. Como nada proyecta sombra, esa pasada apenas cuesta: el atlas se reduce a 512 px.

## Resultados

Medido con llvmpipe en xvfb, así que los fps absolutos no son representativos de un equipo
real. Lo que sirve son las llamadas de dibujo, los triángulos y la proporción entre niveles.

| Pantalla | Antes (llamadas / triángulos) | Alta | Media | Baja |
|---|---|---|---|---|
| Habitación | 1758 / 2,6 M | 1523 / 1,06 M | 1005 / 546 k | 464 / 124 k |
| Isla | 4084 / 3,0 M | 2196 / 650 k | 1220 / 278 k | 663 / 91 k |
| Parchís | 2053 / 833 k | 1116 / 358 k | — | 482 / 57 k |
| Ajedrez | 1624 / 1,5 M | 885 / 775 k | — | — |
| Menú | 689 / 855 k | 476 / 335 k | — | — |

En fps relativos, Baja rinde entre 4 y 6 veces más que el estado anterior en la misma máquina.

## Herramientas

```sh
# Medir pantallas en un nivel:
xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/bench.gd -- /tmp/r.json --calidad=bajo habitacion parchis
# Triángulos y llamadas por grupo de mallas de una escena:
godot --path . --script res://tools/mesh_audit.gd -- habitacion
# Capturas por nivel (se guardan con el sufijo _<calidad>):
xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/art_shots.gd -- /tmp/shots habitacion --calidad=medio
```

Test: `tests/graphics_quality.gd`.

## Pantallas de carga

Para cambiar de escena se usa `Scenes.go(ruta)`, y para reiniciar la actual, `Scenes.reload()`.
Nunca se llama directamente a `get_tree().change_scene_to_file()`. El autoload `SceneLoader`
(`scripts/core/SceneLoader.gd`):

- tapa la pantalla con un dado que rueda, una barra de progreso y un consejo traducido;
- carga la escena en un hilo aparte (`ResourceLoader.load_threaded_request`), así que la
  ventana sigue respondiendo y el dado se anima;
- deja de procesar la escena que se va y bloquea el ratón mientras carga;
- mantiene la pantalla 5 fotogramas sobre la escena nueva, para que los estilos diferidos de
  ToonStyle y Graphics y la compilación de sombreadores no se vean como un tirón.

Hay tres excepciones:

- **En una sala online**, la carga va en el hilo principal: así no se procesan mensajes de red
  dirigidos a una mesa que aún no existe.
- **En headless** (tests) y en la **prueba de arranque**, cambia de escena directamente.
- **Al arrancar el juego**, se muestra `assets/splash.png` sobre el color tinta de la paleta.

Lo que sigue en el hilo principal es el `_ready` de cada escena, que construye las piezas, y
la primera compilación de sombreadores. Esos parones ocurren bajo la pantalla de carga.

Test: `tests/scene_loader.gd`.
