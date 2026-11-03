# Dice on!! · prototipo tabletop en Godot 4

Base local, modular y ampliable para manipular piezas físicas sobre una mesa 3D. Incluye cámara orbital, selección, agarre por fuerza, cuadrícula magnética opcional, dados, fichas físicas, cartas, barajas y modos locales de ajedrez, damas, dominó e isla de recursos. **No incluye multijugador implementado**: al final se describe una arquitectura para incorporarlo sin confundir este prototipo con una solución de red lista para producción.

## Ejecutar

1. Instala Godot **4.7 o posterior** y abre `project.godot` desde el gestor de proyectos.
2. Pulsa **F5** para abrir el menú principal. También puedes ejecutar **F6** sobre una escena concreta. No necesita complementos ni recursos externos.
3. En el menú elige mesa libre, ajedrez, damas, dominó, isla de recursos o cartas. Cada opción inicia una mesa nueva. En cualquier mesa usa **Menú · Esc** para pausar y volver al menú; antes guarda si quieres conservar el estado. Ajedrez y damas tienen vistas simples, modos físicos con reglas y mesas físicas libres; dominó tiene modo físico libre y con reglas. La mesa de cartas incluye barajas inglesa y española para juego manual. Todos los modos son locales en el mismo equipo; no hay manos privadas ni red.
4. En la mesa libre, pasa el cursor sobre una pieza para seleccionarla y usa:

| Control | Acción |
| --- | --- |
| Clic izquierdo sostenido | Agarrar; soltar para liberar |
| Esc / Menú | Pausar, continuar o volver al menú principal |
| Clic derecho + movimiento | Orbitar |
| Clic central o Mayús + clic derecho | Desplazar el foco horizontalmente |
| Rueda | Zoom suave; mientras se sostiene una pieza ajusta su altura |
| R | Lanzar el dado o mezclar el mazo bajo el cursor, sin agarrarlo |
| T | Lanzar el dado bajo el cursor, sin agarrarlo |
| E / Q | Aplicar un impulso de rotación en sentidos opuestos |
| S | Activar o desactivar el imán de la cuadrícula (desactivado al empezar) |
| H | Recuperar la pieza seleccionada o agarrada sobre un espacio libre de la mesa |
| F | Voltear la carta o aplicar un impulso de volteo a la ficha de dominó bajo el cursor, sin agarrarla |
| N | Robar una carta del mazo bajo el cursor, sin agarrarlo |

La selección solo alcanza la primera colisión bajo el cursor; el panel informativo deja pasar el ratón salvo en sus botones. **Reiniciar mesa** descarta los cambios y restaura las piezas y el mazo. **Guardar mesa** y **Cargar mesa** almacenan/restauran una única mesa libre local en `user://diceon_sandbox.json`; guardar sobrescribe la anterior y cargar sustituye la mesa actual. Se conservan posición, orientación y velocidades de dados, fichas, cartas y mazos; también las cartas robadas, el orden restante del mazo y el estado del imán. Suelta la pieza y espera a que termine cualquier volteo antes de guardar o cargar. La simulación continúa al cargar, por lo que los cuerpos todavía pueden caer, chocar o desplazarse. La cámara no se guarda. El archivo versionado se valida antes de cargar y solo admite tipos conocidos, pero la escritura directa no es atómica; no hay guardado en la nube. No es el guardado de los modos de ajedrez o damas. La cámara mantiene el foco en un plano horizontal. La altura mínima de la órbita y la distancia mínima mantienen la cámara por encima del plano focal de la mesa, pero no hacen detección de colisiones con obstáculos adicionales.

## 1. Estructura y árbol de escenas

```text
project.godot
scenes/
  Menu.tscn             # Catálogo y entrada al juego
  Main.tscn             # Mesa sandbox de demostración y composición
  Dice3D.tscn           # Dado y su colisionador
  Token3D.tscn          # Ficha física apilable
  Domino3D.tscn         # Ficha física de dominó doble seis
  PhysicalDomino.tscn   # Mesa libre con 28 fichas de dominó
  GuidedDomino.tscn     # Dominó físico con reglas locales
  CardTable.tscn        # Barajas inglesa y española, modo manual
  Island.tscn           # Isla de recursos para tres jugadores locales
  IslandFour.tscn       # Variante para cuatro jugadores locales
  IslandPiece3D.tscn    # Camino, pueblo, ciudad y ladrón físicos
  Card3D.tscn           # Carta de dos caras
  Deck3D.tscn           # Mazo con cantidad limitada
  Chess.tscn            # Ajedrez local con reglas y modelos 3D
  PhysicalChess.tscn    # Ajedrez físico libre
  GuidedPhysicalChess.tscn # Ajedrez físico con reglas
  PhysicalChessPiece.tscn # Cuerpo rígido de ajedrez
  Checkers.tscn         # Tablero de damas local con reglas
  PhysicalCheckers.tscn # Tablero físico libre con 24 fichas
  GuidedPhysicalCheckers.tscn # Fichas físicas y reglas de damas
scripts/
  Main.gd               # Conecta señales con la interfaz
  ui/Menu.gd            # Menú de modos locales
  ui/SessionNavigation.gd # Pausa y vuelta al menú
  CardTable.gd          # Barajas físicas manuales
  island/IslandBoard.gd # Topología y generación de la isla
  island/IslandRules.gd # Reglas independientes de la vista
  island/IslandView.gd  # Interfaz, tablero, piezas y dados físicos
  island/IslandPiece3D.gd # Modelos y colisionadores
  TabletopCamera3D.gd   # Cámara orbital y foco
  PhysicsGrabber3D.gd   # Selección y arrastre
  SnapGrid3D.gd         # Cuadrícula opcional, vista previa y ocupación
  chess/ChessRules.gd   # Estado y reglas independientes de la vista
  chess/ChessPieceModel.gd # Siluetas originales de las seis piezas
  chess/PhysicalChess.gd # Mesa de ajedrez físico libre
  chess/GuidedPhysicalChess.gd # Reglas, cuerpos y guardado de ajedrez
  chess/PhysicalChessPiece.gd # Pieza rígida y colisionador
  chess/ChessBoard3D.gd # Tablero 3D e interacción local
  BoardGeometry3D.gd    # Geometría y selección comunes a ambos tableros
  checkers/CheckersRules.gd   # Reglas de damas inglesas adaptadas
  checkers/CheckersBoard3D.gd # Vista y controles de damas
  checkers/PhysicalCheckers.gd # Mesa física libre
  checkers/GuidedPhysicalCheckers.gd # Física, reglas y guardado
  sandbox/SandboxPersistence.gd # Snapshot versionado de la mesa libre
  domino/PhysicalDomino.gd # Mesa de dominó físico libre
  domino/DominoRules.gd   # Reglas locales de doble seis
  domino/GuidedDomino.gd  # Integración de física y reglas
  InteractiveTableObject.gd
  Dice3D.gd
  Token3D.gd
  Domino3D.gd
  Card3D.gd
  Deck3D.gd
tests/smoke.gd          # Comprobaciones mínimas sin interfaz
tests/menu_navigation.gd # Menú, pausa y rutas
tests/island_rules.gd   # Geometría, economía y reglas básicas
tests/island_extended.gd # Puertos, desarrollo, rutas y guardado
tests/island_simulation.gd # Partidas simuladas, conservación y replay
tests/island_view.gd    # Escena, selección, dados y retorno físico
tests/piece_models.gd   # Geometrías y etiquetas
tests/physical_chess.gd # Piezas rígidas de ajedrez y choques
tests/guided_physical_chess.gd # Reglas integradas y jugadas especiales
tests/card_table.gd     # Barajas, mezcla y robo
tests/domino_save.gd    # Guardado de dominó por replay
tests/snap_grid.gd      # Casillas libres, bloqueadas y colocación
tests/physics_interaction.gd # Fuerzas, colisiones, apilado y recuperación
tests/physical_checkers.gd # Tablero de damas con fichas físicas
tests/physical_domino.gd # Conjunto y colisiones de dominó físico
tests/domino_rules.gd   # Reglas y 50 partidas simuladas
tests/guided_domino.gd  # Arrastre, validación y acciones de dominó
tests/domino_chain_physics.gd # Geometría y orientación asistida de la cadena
tests/guided_physical_checkers.gd # Reglas integradas y persistencia
tests/sandbox_persistence.gd # Guardado físico y validación
tests/scene_navigation.gd # Navegación entre modos
tests/chess.gd          # Reglas de ajedrez y escena
tests/checkers.gd       # Reglas de damas, guardado y escena
tests/checkers_reference.gd # Posiciones de referencia de damas
tests/chess_reference.gd # Comparación con posiciones de referencia
```

```text
Main (Node3D, Main.gd)
├── WorldEnvironment / Sun (DirectionalLight3D)
├── Table (StaticBody3D)
│   ├── Visual (MeshInstance3D) / CollisionShape3D
│   ├── Felt (decoración visual)
│   └── Leg1 … Leg4 (decoración visual)
├── Floor (StaticBody3D + malla y colisionador)
├── SnapGrid3D (Node3D; cuadrícula visual y consulta de colocación)
├── Objects (Node3D)
│   ├── Dice / Dice2 (Dice3D : InteractiveTableObject : RigidBody3D)
│   ├── TokenGold / TokenRed / TokenBlue (Token3D : RigidBody3D)
│   ├── Card (Card3D : InteractiveTableObject : RigidBody3D)
│   └── Deck (Deck3D : InteractiveTableObject : RigidBody3D)
├── TabletopCamera3D (Node3D)
│   └── Camera3D
├── PhysicsGrabber3D (Node; referencia exportada a Camera3D)
└── UI (CanvasLayer)
    └── Margin / Panel / Content / etiquetas
```

Cada pieza tiene un hijo `Visual` de tipo `MeshInstance3D` y un `CollisionShape3D`. El fieltro es visual: la superficie física está a `y = 0.8`. La mesa y el suelo son estáticos; las patas son decorativas. Las luces y el entorno proporcionan iluminación básica. El proyecto utiliza el renderizador Compatibility para facilitar su ejecución; la calidad de las sombras depende del dispositivo.

## 2. Scripts y funcionamiento

Los scripts completos están en `scripts/`, listos para editar y reutilizar:

- **`TabletopCamera3D.gd`**: mantiene yaw, elevación, foco y distancia objetivo. La elevación y el zoom están acotados; el zoom usa interpolación exponencial independiente de los FPS. El pan usa los ejes de la cámara proyectados al plano horizontal. Los parámetros son exportados.
- **`PhysicsGrabber3D.gd`**: proyecta el ratón por la cámara y consulta la física en `_physics_process`. El arrastre usa un resorte amortiguado con compensación de gravedad, sin congelar ni teletransportar el cuerpo mientras está agarrado. Una consulta descendente adapta la altura objetivo a la mesa u otra pieza; la rueda ajusta el margen de elevación. Al soltar se conserva la velocidad, con un límite, y siguen actuando las colisiones y la gravedad. La liberación también se detecta sobre la interfaz o al perder foco. **H** recupera explícitamente la pieza mediante una recolocación en un espacio libre; no es un movimiento físico. El controlador actúa sobre el centro y no alinea automáticamente la orientación.
- **`SnapGrid3D.gd`**: cuadrícula 4×4, desactivada inicialmente; **S** la activa. La vista previa indica si el destino y el trayecto están libres mediante `intersect_shape` y `cast_motion`. Al soltar en un destino válido, el imán recoloca el cuerpo y elimina su velocidad; es una ayuda opcional, no una interacción puramente física. Si está bloqueado o se suelta fuera de la zona, continúa la física libre. Soporta colisionadores caja, cilindro, esfera y cápsula, con una altura conservadora. La comprobación no garantiza ausencia de túneles en todos los casos ni predice el movimiento futuro de otros cuerpos.
- **`InteractiveTableObject.gd`**: clase base con nombre, estado de hover/agarre, señales y un `material_overlay` translúcido por instancia sobre el nodo `Visual`. `on_grab`, `on_release` y `rotate_object` son puntos de extensión; la rotación se aplica como impulso, no como teletransporte. Los hijos decorativos del visual no se resaltan automáticamente.
- **`Domino3D.gd`**: ficha de doble seis con extremos identificables y puntos visuales; usa colisiones y responde a F con un impulso de giro y elevación. Como depende de la física, puede no acabar en la cara deseada. No se congela para voltearla.
- **`Token3D.gd`**: ficha cilíndrica `RigidBody3D`, con masa, fricción, rebote y color configurables; puede chocar, volcarse y apilarse con otras fichas.
- **`Dice3D.gd`**: aplica impulso y torque aleatorios y espera `sleeping_state_changed` antes de emitir `result_ready`. Compara las normales locales de las seis caras transformadas al mundo con `Vector3.UP` y elige el mayor producto escalar. Las marcas se generan con el mismo mapa de valores, con caras opuestas sumando siete. `top_face()` también permite consultar la orientación directamente; sobre una superficie irregular o con el dado encajado, elige la cara más cercana a arriba, no valida que esté perfectamente plana. Solo informa tras una tirada con R o T, no después de cada movimiento manual.
- **`Card3D.gd`**: congela temporalmente la carta, interpola su cuaternión 180° en su eje local y vuelve a activar la física. Las caras son colores distintos con una etiqueta en el anverso, no texturas. Es una animación sencilla, no un giro con detección continua de colisiones: usar con espacio libre; para producción conviene barrer la geometría o usar un controlador/joint físico.
- **`Deck3D.gd`**: mantiene una lista local de cartas numeradas, permite mezclar con R e instancia cartas independientes desde una escena exportada, en una posición desplazada del mazo. No representa cada carta físicamente dentro del mazo ni implementa agrupación, manos privadas o reglas de una baraja estándar; el contador evita robar indefinidamente. La posición de aparición debe mantenerse libre para evitar solapamientos.
- **`Main.gd`**: se limita a conectar señales y actualizar la interfaz, separando presentación y comportamiento de las piezas.

Para añadir una pieza, crea una escena con raíz `RigidBody3D`, asigna un script que herede `InteractiveTableObject`, añade `Visual` y un colisionador, configura las capas de abajo e instánciala bajo `Objects`. Evita escala no uniforme en cuerpos o ancestros físicos: cambia las dimensiones de las formas y mallas. Ajusta masas, amortiguación, aceleración máxima y tick físico según el tamaño de la mesa. CCD está activado para reducir el atravesamiento, pero un resorte, CCD y límites de fuerza **no garantizan** evitar túneles en todas las velocidades, formas y frecuencias; prueba con geometría y cargas reales. Para interacciones más robustas considera un cuerpo objetivo cinemático y un joint, límites de velocidad y pruebas de barrido.

## 3. Capas y máscaras físicas

En **Project Settings → Layer Names → 3D Physics**:

| Elemento | Layer (dónde está) | Mask (qué detecta) | Valor entero |
| --- | --- | --- | --- |
| Mesa y suelo `StaticBody3D` | 1: Mesa | 2: Piezas | layer `1`, mask `2` |
| Piezas `RigidBody3D` | 2: Piezas | 1: Mesa + 2: Piezas | layer `2`, mask `3` |
| Consulta de selección | No tiene layer | 1: Mesa + 2: Piezas | mask `3` |

La consulta incluye la mesa para que una pieza oculta debajo no pueda seleccionarse a través de ella; solo se acepta el resultado si es `InteractiveTableObject`. El rayo de selección no es el colisionador de la cámara y no modifica las máscaras de los cuerpos. La luz y las mallas decorativas no tienen colisionadores. Si se añaden obstáculos, inclúyelos en la máscara del rayo y de las piezas. Si existen áreas de UI interactivas, configura su `mouse_filter` para impedir que sus eventos lleguen a `_unhandled_input`.

## Pruebas

Con Godot instalado, desde la raíz:

```sh
godot --headless --editor --path . --quit  # importar recursos y registrar class_name
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/menu_navigation.gd
godot --headless --path . --script res://tests/island_rules.gd
godot --headless --path . --script res://tests/island_extended.gd
godot --headless --path . --script res://tests/island_simulation.gd
godot --headless --path . --script res://tests/island_view.gd
godot --headless --path . --script res://tests/piece_models.gd
godot --headless --path . --script res://tests/physical_chess.gd
godot --headless --path . --script res://tests/guided_physical_chess.gd
godot --headless --path . --script res://tests/card_table.gd
godot --headless --path . --script res://tests/domino_save.gd
godot --headless --path . --script res://tests/snap_grid.gd
godot --headless --path . --script res://tests/physics_interaction.gd
godot --headless --path . --script res://tests/physical_checkers.gd
godot --headless --path . --script res://tests/physical_domino.gd
godot --headless --path . --script res://tests/domino_rules.gd
godot --headless --path . --script res://tests/guided_domino.gd
godot --headless --path . --script res://tests/domino_chain_physics.gd
godot --headless --path . --script res://tests/guided_physical_checkers.gd
godot --headless --path . --script res://tests/sandbox_persistence.gd
godot --headless --path . --script res://tests/scene_navigation.gd
godot --headless --path . --script res://tests/chess.gd
godot --headless --path . --script res://tests/chess_reference.gd
godot --headless --path . --script res://tests/checkers.gd
godot --headless --path . --script res://tests/checkers_reference.gd
```

El test de damas cubre capturas obligatorias y múltiples, coronación, bloqueo, deshacer y guardado. El test de referencia compara 171 posiciones, incluidas continuaciones de captura, con datos generados mediante pydraughts 0.6.7; el generador es opcional. El test de ajedrez cubre movimientos iniciales, jaque mate, ahogado, enroque, captura al paso, promoción, tablas, guardado y deshacer; compara además 8.902 posiciones iniciales de tres medias jugadas y una posición de referencia. El test de referencia compara destinos legales en 206 posiciones generadas con python-chess; los tipos de promoción se prueban por separado. El generador opcional está en `tests/tools/` y no es necesario para ejecutar los tests. El smoke test comprueba la carga de la escena, las caras 1 y 6 del dado, la creación de cartas y la finalización del volteo. El test de cuadrícula comprueba una casilla libre, una ocupada, la desactivación y la colocación. Los tests físicos ejercitan el agarre por fuerza, choques, apilado, barrido del snap, recuperación, altura, las mesas de 24 fichas de damas y 28 de dominó, y la integración de reglas y guardado. La prueba de ajedrez físico cubre arrastre, enroque, captura al paso, promoción, tablas y guardado. La suite de dominó verifica las reglas y 50 partidas simuladas completas, además de probar arrastre, robo y pase en la escena física, geometría de la cadena y estabilización con colisiones. La prueba de persistencia cubre restauración física, orden del mazo y rechazo de archivos inválidos. Para comprobar la interacción real: orbita, desplaza y acerca la cámara; arrastra cada pieza por la mesa y hacia otra pieza; suelta, lanza el dado con T y espera el resultado; voltea una carta con F; roba hasta agotar el mazo con N. Verifica también la pérdida de foco y que el tablero oculte las piezas situadas debajo. El análisis sintáctico con `gdlint` no sustituye una ejecución y una prueba visual/física en Godot.

## Extensión multijugador (diseño, no implementado)

Usa un servidor autoritativo con IDs estables por pieza y un único simulador físico. Los clientes envían comandos de intención (`request_grab`, objetivo limitado, `release`, `roll`, `flip`, `draw`); el servidor valida identidad, distancia, ritmo de mensajes y estado, concede un bloqueo temporal por pieza y lo libera al soltar, desconectar o expirar. El servidor decide tiradas y contenido del mazo, y replica resultados y snapshots de transformaciones/velocidades con número de secuencia; los clientes interpolan y pueden predecir únicamente su interacción local, reconciliando con el servidor. No sincronices directamente las transformaciones de `RigidBody3D` desde varios peers ni confíes en valores de dado enviados por el cliente. Para cartas ocultas, envía la identidad únicamente a quienes tengan permiso. Añade pruebas con latencia, pérdida de paquetes, reconexión y solicitudes simultáneas antes de considerarlo apto para producción.

## Modelo de negocio y siguientes pasos

El diseño de producto contempla **pago único por copia**, sin suscripción ni pase gratuito para invitados; el modelo comercial aún no está implementado ni conectado a Steam. Cada jugador necesitará su copia para el multijugador futuro. Consulta el [GDD](docs/GDD-Dice-on.md) para las fases previstas. El prototipo actual es local: incluye primeros modos asistidos de ajedrez y damas, pero todavía no incluye editor no-code ni multijugador. Consulta el [estado de implementación](docs/ESTADO.md) para sus límites.

## Ajedrez local

Dos personas juegan en el mismo equipo. El motor y la vista están separados: `ChessRules` genera movimientos legales, impide dejar el rey en jaque, gestiona turnos, capturas, enroque, captura al paso, promoción a dama/torre/alfil/caballo, jaque, mate y ahogado. Permite deshacer, detectar material insuficiente en los casos implementados, reclamar tablas tras alcanzar tres repeticiones o 50 movimientos y aplica tablas tras cinco repeticiones o 75 movimientos. Las tablas reclamables se comprueban sobre la posición actual; no se admite aún anunciar una jugada futura para reclamar. Se puede guardar una partida local en `user://diceon_chess.json` y cargarla mediante repetición validada de hasta 1024 medias jugadas; el archivo no es un guardado en la nube y puede sobrescribirse. Hay tres modalidades: vista simple con selección por clic; **ajedrez físico libre**, con 32 piezas rígidas y reglas manuales; y **ajedrez físico con reglas**, que usa el mismo motor lógico y valida al soltar. En este último, agarra una pieza y espera a que llegue a una casilla iluminada antes de soltar; las piezas desplazadas o capturadas vuelven a sus destinos mediante fuerzas. Enroque y captura al paso también desplazan sus piezas físicas, y la promoción actualiza la silueta y el colisionador. Selecciona el tipo de promoción antes de mover el peón. Deshacer y reclamar tablas requieren soltar primero la pieza.

Las dos vistas con reglas comparten `user://diceon_chess.json`; guardar en una sobrescribe la partida guardada por la otra. Cambiar de modo inicia una partida nueva, por lo que hay que guardar antes y cargar después para transferirla. Se guarda el historial lógico, no las posiciones físicas exactas; al cargar, las piezas vuelven a sus destinos mediante fuerzas. La escritura no es atómica. La mesa física libre no se guarda y una promoción manual requiere acordar una pieza sustituta. La asistencia física no garantiza estabilidad o alineación perfecta. No hay relojes ni juego en red; el motor necesita más pruebas antes de usarse en competición.

## Damas locales

La partida para dos personas en el mismo equipo usa una **variante adaptada de damas inglesas de 8×8**: las blancas comienzan; solo se utilizan las casillas oscuras. Las fichas simples avanzan y capturan en diagonal hacia delante; las coronadas (marcadas con D) se mueven y capturan una casilla o salto en ambos sentidos, sin desplazamiento largo. La captura es obligatoria para todo el bando y los saltos múltiples deben continuarse con la misma pieza; se puede elegir cualquier secuencia de captura, sin obligación de maximizar. Coronar durante una captura termina el turno. Pierde quien no tenga piezas o movimientos legales.

**Deshacer** revierte un paso o salto individual, incluido un salto dentro de una cadena. **Guardar partida** y **Cargar partida** usan `user://diceon_checkers.json`, separado del ajedrez; el guardado sobrescribe la partida anterior y se valida reproduciendo hasta 1024 pasos/saltos. No se implementan tablas, reloj, IA, reglas internacionales, juego en red ni guardado en la nube. Como en el ajedrez, el modelo de reglas está separado de la presentación.

Hay tres modos: la vista simple con piezas visuales y selección por clic; **damas físicas libres**, sin validación de reglas; y **damas físicas con reglas**, con 24 cuerpos rígidos y el mismo modelo de reglas. En este último, suelta sobre un destino legal cuando la ficha haya llegado físicamente; solo entonces se confirma el movimiento. Las colisiones no cambian por sí solas la partida: las fichas desplazadas vuelven a su casilla mediante fuerzas, las capturadas se mueven a los lados y una marca visual indica la coronación. Deshacer, guardar y cargar requieren soltar primero la ficha; al deshacer o cargar, las fichas recuperan sus destinos mediante fuerzas, no de forma instantánea. No se guardan sus posiciones físicas exactas. La recuperación H recoloca explícitamente un cuerpo y cancela la jugada si se estaba agarrando.

Ambas vistas con reglas comparten el mismo archivo de damas; guardar en una sobrescribe la partida guardada por la otra. Cambiar de modo inicia una partida nueva: guarda antes y carga después si quieres trasladarla. El guardado se escribe directamente, no es atómico. La física asistida no garantiza ausencia de solapamientos o estabilidad en todos los casos y necesita pruebas visuales y manuales.


## Dominó físico local

**Dominó físico libre** prepara las 28 fichas únicas del doble seis, inicialmente boca arriba. Puedes agarrarlas, chocarlas, girarlas y colocarlas manualmente; **F** aplica un impulso físico de volteo cuyo resultado depende de la posición y las colisiones. Esta mesa no aplica reglas.

Desde esa mesa, **Dominó físico con reglas** inicia otra partida para dos personas en el mismo equipo. Variante implementada: se reparten siete fichas por jugador, quedan catorce en el pozo y el jugador 1 abre con cualquier ficha. En cada turno se coloca una ficha compatible en cualquiera de los extremos. Si no hay jugada, se roba una ficha cada vez hasta poder jugar o agotar el pozo; con el pozo vacío y sin jugada se pasa. Gana quien vacíe primero su mano; tras dos pases consecutivos con el pozo vacío gana quien tenga menos puntos en la mano, o hay empate si son iguales. No hay puntuación acumulada por rondas ni otras variantes.

Las manos se sitúan a los lados y el pozo en la zona superior del tablero. Agarra una ficha del jugador del turno y llévala a la zona verde **izquierda** o **derecha**; espera a que el cuerpo llegue antes de soltar. El modelo valida el movimiento y las fichas regresan o se reordenan mediante fuerzas. Las fichas jugadas reciben además un resorte angular que intenta orientarlas boca arriba y con los valores en el orden de la cadena, en un recorrido compacto en zigzag; siguen siendo cuerpos dinámicos que chocan. En este modo, al voltear o mover una ficha ya jugada, la asistencia intentará devolverla a su posición y orientación. Las colisiones pueden impedir una alineación perfecta o desplazar fichas: el texto **Cadena** sigue siendo la referencia del orden y los valores. Las colisiones por sí solas no modifican las reglas. La preparación inicial sí recoloca los cuerpos directamente.

Ambos modos son prototipos locales **sin privacidad**: las manos y el pozo están visibles y la selección muestra los valores incluso boca abajo. El modo con reglas permite guardar y cargar una partida local en `user://diceon_domino.json`: guarda el reparto y los eventos, los valida por replay y devuelve las piezas a sus destinos mediante fuerzas; no guarda posiciones físicas exactas. Guardar sobrescribe el archivo anterior y la escritura no es atómica. El modo libre no tiene guardado. No hay red ni reconexión; el guardado de la mesa sandbox no incluye el dominó. Cambiar de modo, reiniciar o salir descarta los cambios no guardados. La física asistida no garantiza estabilidad ante todos los choques, y la presentación y el manejo necesitan pruebas visuales y manuales.


## Mesa de cartas

Desde el menú se puede abrir una mesa manual con una **baraja inglesa de 52 cartas sin comodines** y una **baraja española de 40 cartas**. Las cartas son cuerpos rígidos con valor central y en las esquinas; en la española, O = oros, C = copas, E = espadas y B = bastos. Usa los botones para mezclar o robar, o selecciona un mazo y pulsa R o N. Las cartas aparecen en varios puntos de la mesa, pero no se comprueba que cada punto esté libre: deja espacio para evitar solapamientos. F voltea una carta mediante una animación que la congela temporalmente, no mediante una simulación física completa. No hay reparto automático, manos privadas, reglas de juegos de cartas ni guardado de esta escena.

Para el alcance y las verificaciones que faltan antes de llamar beta a esta base, consulta [la lista de preparación](docs/BETA.md).


## Isla de recursos · modo local inspirado en Catán

Es una adaptación propia de las principales reglas del juego base para **tres o cuatro personas locales**, no el juego oficial. Todas las manos y puntuaciones son visibles; las cartas de desarrollo se representan en el panel, no como cartas físicas. El tablero se genera aleatoriamente y sus componentes visuales son propios. J1 es naranja, J2 azul, J3 rojo y J4 blanco; M/L/O/T/R indican madera, ladrillo, lana, trigo y mineral. Los números rojos son 6 y 8 y no aparecen adyacentes.

- **Preparación:** en orden serpentino (por ejemplo J1, J2, J3, J3, J2, J1 para tres), coloca un pueblo en una marca verde y después un camino adyacente. Se respeta la distancia de un vértice libre entre pueblos. El segundo pueblo recibe un recurso por cada terreno adyacente no desértico.
- **Turno:** pulsa **Lanzar dados** y espera a que ambos cuerpos estén estables: el resultado es la cara superior física. Si quedan encajados, cancela sin cambiar el turno y vuelve a lanzar; si salen de la bandeja, recupéralos con H bajo el cursor y arrástralos de nuevo. Los hexágonos con ese número producen un recurso por pueblo o dos por ciudad, salvo el hexágono con ladrón. Si falta un recurso en el banco, cuando hay varios beneficiarios ninguno lo recibe; si solo hay uno recibe lo disponible.
- **Siete y ladrón:** quien tenga más de siete recursos descarta la mitad redondeada hacia abajo, seleccionando uno cada vez. La persona activa mueve el ladrón a otro hexágono y, si hay víctimas con recursos junto a él, elige una para robarle un recurso al azar. Un caballero también mueve el ladrón, pero sin descarte.
- **Construcción:** elige la acción y pulsa una marca verde; gris indica que no es válida. Un camino cuesta M+L, un pueblo M+L+O+T y una ciudad 2T+3R. Los caminos deben conectar con la red propia y los pueblos con un camino propio; un pueblo rival bloquea la conexión a través de ese vértice. Máximo 15 caminos, 5 pueblos y 4 ciudades por jugador. Mientras se selecciona una construcción se desactiva el agarre; **Cancelar selección** lo recupera.
- **Comercio:** el cambio habitual con el banco es 4:1. Construir en cualquiera de los dos extremos de un puerto habilita la tarifa indicada en la costa: 3:1 genérica o 2:1 para el recurso indicado. Para comerciar con una persona, introduce cantidades por recurso en «ofrezco» y «pido», selecciona destinatario y envía; solo ella puede aceptar o rechazar. Debe haber recursos en ambos sentidos y no puede cambiarse un recurso por sí mismo. El estado compartido es público.
- **Desarrollo:** comprar una carta cuesta O+T+R; hay 14 caballeros, 5 puntos de victoria, 2 de caminos, 2 de abundancia y 2 de monopolio. Las cartas jugables se pueden usar antes o después de tirar, como máximo una por turno y no en el turno de compra. Los puntos de victoria cuentan inmediatamente. Caballero mueve al ladrón; caminos permite construir hasta dos caminos gratis conectados; abundancia toma dos recursos disponibles del banco (pueden coincidir); monopolio recoge de las otras manos el recurso elegido. El panel indica cartas listas y nuevas.
- **Bonificaciones y victoria:** la ruta más larga continua de al menos cinco caminos y el ejército más grande de al menos tres caballeros valen dos puntos cada uno. En caso de empate el titular conserva el título; para arrebatárselo hay que superarlo. Una ruta no repite aristas y los pueblos rivales la interrumpen. Gana quien alcance diez puntos durante su turno, con uno por pueblo y dos por ciudad.

Caminos, pueblos, ciudades y ladrón son cuerpos rígidos con colisiones; fuerzas y torque los ayudan a regresar a su ubicación lógica. Los dados se lanzan físicamente dentro de una bandeja con paredes. El panel es desplazable. **Guardar** sobrescribe `user://diceon_island.json`; **Cargar** reconstruye tablero y cuerpos a partir de acciones validadas y una semilla. Guarda el estado lógico y las tiradas, no las poses físicas, la cámara ni la tirada en curso. La escritura no es atómica y el replay depende del algoritmo aleatorio de la versión; no hay nube. No hay privacidad en la pantalla compartida, IA, expansiones ni red. Falta validar gráficamente y con partidas manuales; las pruebas headless no sustituyen esa revisión.
