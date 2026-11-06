# Biblia de arte · Dice on!!

**Dirección:** cartoon de mesa. Colores saturados, formas redondeadas, contornos de tinta gruesos y animaciones con rebote. El objetivo es que una captura se reconozca a primera vista y que el juego vaya fluido en portátiles con gráficos integrados.

![Antes y después del estilo cartoon](img/fase1-antes-despues.png)

## Paleta

La fuente de verdad son las constantes de [`scripts/style/ToonStyle.gd`](../scripts/style/ToonStyle.gd). Si cambia un color, se cambia allí y aquí.

| Token | Color | Uso |
| --- | --- | --- |
| `INK` | `#1d1a3a` | Contornos, bordes de interfaz, texto sobre fondos claros |
| `SKY` | `#a9c9f2` | Fondo de todas las escenas |
| `FLOOR` | `#7c98cf` | Suelo bajo la mesa |
| `WOOD` | `#8a4f2a` | Madera de la mesa |
| `FELT` | `#1e7a5f` | Tapete |
| `PANEL` | `#2a2552` | Paneles de interfaz |
| `PAPER` | `#fff8ec` | Texto sobre paneles, campos, botones secundarios |
| `SUN` | `#ffc83d` | Botones principales, pestaña activa, acentos |
| `SUN_LIGHT` | `#ffd96e` | Botón al pasar el ratón |
| `LAVENDER` | `#c9c5ef` | Texto secundario sobre paneles |
| `MUTED` | `#8b87b3` | Controles desactivados |

Luz: sol cálido `#fff1d9` (energía 0,85) y luz ambiente lavanda `#c7c9ff` (0,5). La cara en sombra queda en torno a la mitad del color propio: contraste de dibujo animado sin negros.

**Reglas de color**
- Nunca transmitir información solo con color: los jugadores y las fichas llevan número o letra (ya se hace en ludo, ajedrez y la isla).
- Los colores de jugador conservan sus nombres (rojo, azul, naranja, blanco…) para que los textos de turno sigan siendo correctos.
- Evitar el negro puro y el blanco puro en superficies grandes: queman la imagen con la iluminación por bandas.

## Iluminación y sombreado

- Materiales opacos: difuso y especular **toon** de Godot (`DIFFUSE_TOON`, `SPECULAR_TOON`), rugosidad entre 0,45 y 0,8, sin metal.
- Sin tonemapping (`linear`): los colores saturados no se apagan.
- Sombras al 55 % de opacidad y con más sesgo, para evitar rayas de "acné" sobre superficies curvas.
- Materiales transparentes o sin iluminación (resaltados, vistas previas, paredes de cristal, marcas) **no** se tocan.

## Contornos

Casco invertido ([`shaders/toon_outline.gdshader`](../shaders/toon_outline.gdshader)): la malla se dibuja inflada y por detrás en color `INK`. Funciona en el renderizador Compatibility.

- Grosor proporcional al tamaño de la malla: 3,6 % de su mayor dimensión, entre 0,8 y 3 cm. Un dado de 0,5 m lleva unos 1,8 cm.
- Dirección de inflado según la forma: cajas hacia las esquinas, cilindros rectos desde el centro, conos y mallas generadas según la normal (si no, el contorno atraviesa las piezas vecinas).
- Sin contorno: láminas de menos de 1,2 cm (marcas, separadores, casillas del imán), tapetes grandes y finos, planos y el suelo.

## Tipografía

| Rol | Fuente | Dónde |
| --- | --- | --- |
| Titulares | **Lilita One** | Etiquetas de 22 px o más |
| Texto e interfaz | **Nunito** peso 750 | Todo lo demás |

Ambas con licencia SIL Open Font License, incluida en `assets/fonts/`.

## Interfaz

- Paneles `PANEL` con borde `INK` de 3 px, esquinas de 18 px y sombra dura desplazada 5 px.
- Botones principales `SUN` con texto `INK`, borde de 3 px y 6 px abajo para dar volumen; al pulsar, el borde inferior baja a 3 px y el texto se hunde.
- Botones del menú principal en `PAPER`, con el mismo volumen.
- Foco de teclado: anillo `PAPER` de 3 px alrededor del control.

## Animación ("juice")

- Al agarrar una pieza, su malla se estira hacia arriba (×1,14 en altura) y vuelve con rebote.
- Al soltarla, se aplasta (×0,84) y rebota.
- Solo cambia la malla visual: el colisionador y la física no se deforman.
- **Reducir animaciones** en el menú principal desactiva los rebotes; se guarda en `user://diceon_controls.cfg`.

## Cómo se aplica

`ToonStyle` es un autoload que actúa sobre cada nodo al entrar en el árbol, así que las escenas no necesitan cambios para recibir el estilo. Modifica los materiales en su sitio, sin sustituirlos, para que los scripts que cambian colores sigan funcionando. Si un script cambia la malla de una pieza en tiempo de ejecución, puede llamar a `ToonStyle.restyle(mesh_instance)`.

Para revisar el aspecto sin abrir el editor: `tools/shots.sh <carpeta> [godot]` captura las mesas principales con un renderizador real (en Linux sin pantalla usa `xvfb-run`).

## Pendiente en la fase 1

- Rediseñar las mallas de piezas con formas más redondeadas y dados con puntos redondos.
- Mesa y entorno ilustrados (habitación, objetos de fondo).
- Partículas al caer un dado y número que "salta" al resolverse.
- Sonidos con carácter y música ambiental.
- Variante de paleta para daltonismo.
- Test de lectura con 5 personas y medición de FPS en un portátil con gráficos integrados.
