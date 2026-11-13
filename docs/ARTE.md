# Biblia de arte · Tablerama

**Dirección (noviembre de 2026): «juguete de arcilla».** A medio camino entre *PEAK* (volúmenes blandos y gruesos, tonos cálidos y terrosos, un punto de grano) y *Human Fall Flat* (superficies mates y limpias, luz suave, muñecos sencillos). Materiales sin brillo, luz que envuelve las formas, sombras difuminadas, contorno fino del color de cada pieza (no tinta negra) y una interfaz de botones «de arcilla» sin marcos. Los colores de jugador son el único acento vivo. Debe ir fluido en portátiles con gráficos integrados.

![Antes y después del estilo cartoon](img/fase1-antes-despues.png)

(La imagen es de la fase 1, con el estilo cartoon de contornos de tinta que este sustituye.)

## Paleta

La fuente de verdad es [`scripts/style/Palette.gd`](../scripts/style/Palette.gd). Si cambia un color, se cambia allí y aquí.

| Token | Color | Uso |
| --- | --- | --- |
| `INK` | `#1d1a3a` | Texto sobre fondos claros; ya no se usa para contornos ni marcos |
| `SKY` | `#cfe1ee` | Fondo de todas las escenas |
| `FLOOR` | `#c2a27e` | Suelo de roble claro |
| `WOOD` | `#a67c56` | Madera de la mesa |
| `FELT` | `#4f9c84` | Tapete verde salvia |
| `PANEL` | `#2a2552` | Paneles de interfaz (algo translúcidos) |
| `PAPER` | `#fff8ec` | Texto sobre paneles, campos, botones secundarios |
| `SUN` | `#ffc83d` | Botones principales, pestaña activa, acentos |
| `SUN_LIGHT` | `#ffd96e` | Botón al pasar el ratón |
| `LAVENDER` | `#c9c5ef` | Texto secundario sobre paneles |
| `MUTED` | `#8b87b3` | Controles desactivados |

Habitación (`RoomDecor.gd`): pared crema `#efe5d6`, zócalo `#d9c4a6` y alfombra azul grisáceo `#9fb3c4`, fría para que la mesa cálida destaque. Colores de jugador algo menos saturados que antes (`#ee6f60`, `#5a8ae8`, `#58c08f`, `#f5c549`).

Luz: sol cálido `#fff1d9` (energía 0,52, sombras difuminadas al 42 %) y mucha luz ambiente clara `#ece7f3` (0,56). El lado en sombra conserva su color: nada de negros ni de blancos quemados.

**Reglas de color**
- Nunca transmitir información solo con color: los jugadores y las fichas llevan número o letra (ya se hace en ludo, ajedrez y la isla).
- Los colores de jugador conservan sus nombres (rojo, azul, naranja, blanco…) para que los textos de turno sigan siendo correctos.
- Evitar el negro puro y el blanco puro en superficies grandes.

## Iluminación y sombreado

- Materiales opacos: `DIFFUSE_LAMBERT_WRAP` (la luz envuelve la forma en un degradado suave, sin corte de bandas), sin especular y rugosidad 1: arcilla mate.
- Lo aplica `ToonStyle` a cada malla que entra en el árbol, sin tocar las escenas. Los materiales transparentes o sin iluminación (resaltados, marcas) se dejan como están.
- Encima del 3D y por debajo de la interfaz hay una capa de grano muy suave y viñeta (`shaders/soft_grain.gdshader`). Con «Reducir animaciones» el grano se queda quieto.

## Contornos

- Casco invertido (`shaders/toon_outline.gdshader`), ahora fino (2 % de la pieza, entre 5 y 14 mm) y del **color de la propia pieza oscurecido**: separa las piezas del tapete sin dibujar cómic.
- Las piezas con textura (cartas) llevan un marrón grisáceo neutro. Láminas finas, planos y tapetes no llevan contorno.

## Tipografía

| Rol | Fuente | Dónde |
| --- | --- | --- |
| Titulares | **Lilita One** | Etiquetas de 22 px o más |
| Texto e interfaz | **Nunito** peso 750 | Todo lo demás |

Ambas con licencia SIL Open Font License, incluida en `assets/fonts/`.

## Interfaz

- **Botones «de arcilla»**: sin contorno; un labio inferior del color del botón oscurecido (6 px, 3 px al pulsar) y una sombra corta difusa. Foco: anillo claro.
- **Paneles**: índigo algo translúcido, filo claro de 1 px, esquinas de 20–24 px y sombra difusa hacia abajo (nada de sombras duras desplazadas). El acento de cada juego es una franja superior, no un marco.
- **Titulares**: Lilita One con sombra suave en vez de trazo de tinta.
- **Fondo de los menús** (`MenuBackdrop`): un diorama 3D de la sala —mesa puesta, dos muñecos de arcilla, lámpara— con la cámara girando despacio y un velo oscuro para leer el texto. La portada deja la mesa a la vista a la derecha y pone título y botones a la izquierda; el resto de menús usa el velo entero.
- **Formas orgánicas**: paneles y botones llevan esquinas de «canto rodado» (`MenuStyle.pebble`): cada esquina con un radio algo distinto, como modeladas a mano.
- **Nada de borde a borde**:
  - Los menús tienen un tamaño máximo y se centran (`MenuStyle.limit_page`); sus tarjetas miden lo que su contenido (`MenuStyle.fit_scroll`). La selección de modo es una lista corta a la izquierda, como la portada.
  - En las mesas, el cajón «Partida» es una tarjeta que cuelga de su botón, a la derecha, sin repetir lo que ya dice la barra de turno.
  - Parchís, ludo e isla usan una tarjeta compacta arriba a la izquierda (`HudCard`): lo de cada turno a la vista y lo demás (bots, guardar, reglas, atajos) plegado en «⋯».
- Todo sale de `MenuStyle` (menús), `ToonStyle._build_theme` (tema global) y `GameThemes` (barra de cada mesa).

## Animación ("juice")

- Al agarrar una pieza, su malla se estira hacia arriba (×1,14 en altura) y vuelve con rebote.
- Al soltarla, se aplasta (×0,84) y rebota.
- Solo cambia la malla visual: el colisionador y la física no se deforman.
- **Reducir animaciones** en el menú principal desactiva los rebotes; se guarda en `user://diceon_controls.cfg`.
- La especificación completa de avatares expresivos, abanicos 3D de rivales, *shaders* de borde/flexión, iluminación cálida y punteros/emotes multijugador se detalla en [`docs/GUIA_DIRECCION_ARTE_Y_JUICE_3D.md`](GUIA_DIRECCION_ARTE_Y_JUICE_3D.md).

## Cómo se aplica

`ToonStyle` es un autoload que actúa sobre cada nodo al entrar en el árbol, así que las escenas no necesitan cambios para recibir el estilo. Modifica los materiales en su sitio, sin sustituirlos, para que los scripts que cambian colores sigan funcionando. Si un script cambia la malla de una pieza en tiempo de ejecución, puede llamar a `ToonStyle.restyle(mesh_instance)`.

Para revisar el aspecto sin abrir el editor: `tools/shots.sh <carpeta> [godot]` captura las mesas principales con un renderizador real (en Linux sin pantalla usa `xvfb-run`).

## Piezas

Todas las piezas comparten un kit de formas ([`scripts/style/PieceKit.gd`](../scripts/style/PieceKit.gd)): cajas y losas redondeadas, discos con bisel, perfiles torneados y gotas de tinta. Los colores salen de [`scripts/style/Palette.gd`](../scripts/style/Palette.gd).

- **Dados y dominó:** cuerpo crema redondeado y puntos de tinta.
- **Cartas de mesa:** losa de canto grueso y esquinas muy redondeadas, anverso crema y reverso coral.
- **Ajedrez y damas:** dos bandos, crema y violeta; tablero crema y añil.
- **Isla:** el pueblo es una casita con tejado a dos aguas y puerta. La ciudad es una casa ancha con una torre de tejado en punta, para que se distinga del pueblo por la silueta. El camino es un tablón y el ladrón, una figura oscura con ojos. Los jugadores son naranja, azul, rojo y blanco.
- **Casillas de la isla:** prismas hexagonales en 3D sobre un mar azul, con paisaje en miniatura (árboles, colinas con ladrillos, ovejas, trigo, montañas nevadas y cactus en el desierto) y una ficha de número con puntos de probabilidad (6 y 8 en rojo). El paisaje se coloca lejos de esquinas y lados para no tapar pueblos ni caminos. Ya no se usan fotografías.

## Arte de las cartas

![Muestras del arte de cartas](img/cartas.png)

Simple y legible a cualquier tamaño ([`scripts/cards/CardArt.gd`](../scripts/cards/CardArt.gd)): todas las cartas se dibujan con formas planas y contorno de tinta y se guardan como textura compartida, así que se ven igual en la mano y sobre la mesa.

- **Estilo vectorial:** formas planas con contorno de tinta, sombras planas desplazadas (sin degradados) y un pequeño brillo en los palos redondeados. Se dibujan al doble de resolución para verse nítidas de cerca.
- **Anverso:** crema, con un marco fino del color del palo y el índice (valor y palo) en dos esquinas. Los números del 2 al 10 siguen la distribución clásica de palos; en la baraja francesa los de la mitad inferior van invertidos y en la española no. El as lleva un palo grande sobre un círculo suave.
- **Figuras:** un arco del color del palo con su emblema y una cinta con la letra: corona (K, rey), tiara (Q), gorro con pluma (J, sota) y cabeza de caballo (caballo).
- **Palos dibujados**, sin depender de la fuente: picas y tréboles en tinta, corazones y diamantes en coral; oros (moneda dorada), copas (cáliz coral), espadas (azul) y bastos (garrote de madera).
- **Reverso:** coral, con rombos geométricos en dos tonos, doble marco crema y un medallón con el dado de Tablerama en el centro. Es también la cara de arriba de los mazos.
- **Isla:** las cartas de recurso llevan una escena vectorial en una ventana a dos tonos: bosque con pinos y troncos, muro de ladrillos sobre colinas, oveja en el pasto, gavilla de trigo en el campo y montañas nevadas con gemas. Debajo, el nombre en una cinta y el terreno de origen. Las cartas de desarrollo llevan su emblema sobre rayos suaves y una frase con lo que hacen («Mueve el ladrón y roba una carta»…). Todas tienen una **insignia en la esquina superior izquierda** para reconocerlas en el abanico de la mano aunque solo asome el borde. Las de desarrollo, un emblema sobre un círculo crema: escudo (caballero), estrella (punto), caminos cruzados, destellos (abundancia) y monedas (monopolio).

![Cartas de la isla](img/cartas-isla.png)

`tools/card_sheet.gd` genera una hoja de muestras para revisar el arte.

## Cartas en la mano

![Manos 3D, isla, mesa de cartas, ajedrez y ludo](img/fase1-mesa-y-manos.png)

Las cartas que tiene un jugador se ven **en 3D, en abanico y sujetas delante de la cámara** ([`scripts/cards/Hand3D.gd`](../scripts/cards/Hand3D.gd)). Se dibujan en una capa propia, así que nunca atraviesan la mesa. Al pasar el ratón, la carta se levanta; con un clic se usa.

- **Mesa de cartas:** «Mano inglesa» y «Mano española» roban directamente a la mano, **M** sobre una carta de la mesa la recoge y un clic en la mano la juega boca arriba. «Ocultar» pone la mano de espaldas para pasar el equipo. La mano se guarda con la partida.
- **Isla:** cada recurso es una carta suelta (3 maderas = 3 cartas), agrupadas por tipo, seguidas de las cartas de desarrollo. Las recién compradas salen más oscuras y con la marca «nueva». En abundancia y monopolio la mano muestra una carta de cada recurso para elegir.
- Iconos de recurso dibujados con formas planas y contorno de tinta ([`ResourceIcon.gd`](../scripts/island/ResourceIcon.gd)).

## Información en la mesa

El panel lateral se sustituye por información en la propia mesa ([`scripts/ui/TableHud.gd`](../scripts/ui/TableHud.gd)):

- **Jugadores sentados** alrededor de la mesa como personajes de su color ([`TableSeats.gd`](../scripts/table/TableSeats.gd)), con nombre y estado encima: puntos y cartas en la isla, fichas en la meta en el ludo y fichas restantes en el dominó. El jugador con el turno salta y tiene un aro amarillo. Los bots llevan antena y ojos de pantalla.
- Los jugadores **del lado de la cámara** no se dibujan en 3D, porque taparían la mesa. Aparecen como ficha abajo a la izquierda, con «Tu turno» cuando les toca.
- **Cartel de turno** arriba al centro y **pista del momento** justo debajo.
- **Barra de acciones** abajo y **cajón «Partida»** con guardar, cargar, cambiar de modo y ajustes.
- La isla y el ludo conservan su panel de acciones, ya con la paleta, y tienen a los jugadores sentados a la mesa.

## Habitación

La mesa está en una habitación acogedora ([`scripts/style/RoomDecor.gd`](../scripts/style/RoomDecor.gd)), que se añade sola a cada escena con suelo. Tiene suelo de tablones de madera, una alfombra lavanda bajo la mesa, dos paredes con zócalo, una ventana con una nube, una estantería con libros de colores y una planta. Las paredes son de una sola cara: si la cámara gira por detrás, desaparecen en vez de tapar la mesa.

## Sonido

Efectos cortos generados por código ([`scripts/audio/Sfx.gd`](../scripts/audio/Sfx.gd)), sin archivos de audio:

- **Agarrar:** pop ascendente.
- **Soltar:** golpe de madera.
- **Lanzar dados:** tres choques de plástico.
- **Resultado del dado:** pop.
- **Cartas:** soplido de papel.
- **Botones:** clic.
- **Cambio de turno:** dos notas.

Cada reproducción varía un poco el tono para que no suene repetida. «Efectos de sonido» en el menú los apaga y se guarda en el equipo.

## Dados

Al quedarse quieto un dado, su número sale grande en el centro de la pantalla con un rebote, sin partículas. Con «Reducir animaciones» se muestra el número sin salto.

## Pendiente en la fase 1

- Pasar las acciones de la isla y el ludo a la barra inferior y al cajón, como en las demás mesas.
- Variante de paleta para daltonismo.
- Música ambiental tranquila y volúmenes separados.
- Test de lectura con 5 personas y medición de FPS en un portátil con gráficos integrados.

## Identidad de cada juego

La paleta es común a todos, pero cada juego tiene un **color de acento** y un **emblema** (`scripts/style/GameThemes.gd`, `GameEmblem.gd`). El acento se usa en el borde del cartel de turno, en el botón «Partida», en la barra de acciones y en el cajón lateral, de modo que se sabe de un vistazo en qué juego estás.

| Juego | Acento | Emblema |
|---|---|---|
| Mesa libre | amarillo sol `#ffc83d` | dado |
| Mesa de cartas | coral `#e2504a` | carta con corazón |
| Ajedrez | violeta `#8a7fd6` | peón |
| Damas | menta `#3fcf8e` | pila de fichas |
| Dominó | azul `#4d7cfe` | ficha de dominó |
| Ludo | naranja `#ff9a3d` | cuatro fichas de color |
| La isla | verde bosque `#2f8f4e` | hexágono con árbol |
