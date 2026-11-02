# Mesa abierta · prototipo tabletop en Godot 4

Base local, modular y ampliable para manipular piezas físicas sobre una mesa 3D. Incluye cámara orbital, selección, agarre por fuerza, dado, carta y mazo. **No incluye multijugador implementado**: al final se describe una arquitectura para incorporarlo sin confundir este prototipo con una solución de red lista para producción.

## Ejecutar

1. Instala Godot **4.4 o posterior** y abre `project.godot` desde el gestor de proyectos.
2. Pulsa **F6** sobre `scenes/Main.tscn` o **F5** para iniciar el proyecto. No necesita complementos ni recursos externos.
3. Pasa el cursor sobre una pieza para seleccionarla y usa:

| Control | Acción |
| --- | --- |
| Clic izquierdo sostenido | Agarrar; soltar para liberar |
| Clic derecho + movimiento | Orbitar |
| Clic central o Mayús + clic derecho | Desplazar el foco horizontalmente |
| Rueda | Zoom suave |
| R | Aplicar impulso de rotación a la pieza bajo el cursor o agarrada |
| T | Lanzar el dado bajo el cursor, sin agarrarlo |
| F | Voltear la carta bajo el cursor, sin agarrarla |
| N | Robar una carta del mazo bajo el cursor, sin agarrarlo |

La selección solo alcanza la primera colisión bajo el cursor; el panel de ayuda no captura el ratón. La cámara mantiene el foco en un plano horizontal. La altura mínima de la órbita y la distancia mínima mantienen la cámara por encima del plano focal de la mesa, pero no hacen detección de colisiones con obstáculos adicionales.

## 1. Estructura y árbol de escenas

```text
project.godot
scenes/
  Main.tscn             # Escena de demostración y composición
  Dice3D.tscn           # Dado y su colisionador
  Card3D.tscn           # Carta de dos caras
  Deck3D.tscn           # Mazo con cantidad limitada
scripts/
  Main.gd               # Conecta señales con la interfaz
  TabletopCamera3D.gd   # Cámara orbital y foco
  PhysicsGrabber3D.gd   # Selección y arrastre
  InteractiveTableObject.gd
  Dice3D.gd
  Card3D.gd
  Deck3D.gd
tests/smoke.gd          # Comprobaciones mínimas sin interfaz
```

```text
Main (Node3D, Main.gd)
├── WorldEnvironment / Sun (DirectionalLight3D)
├── Table (StaticBody3D)
│   ├── Visual (MeshInstance3D) / CollisionShape3D
│   ├── Felt (decoración visual)
│   └── Leg1 … Leg4 (decoración visual)
├── Floor (StaticBody3D + malla y colisionador)
├── Objects (Node3D)
│   ├── Dice (Dice3D : InteractiveTableObject : RigidBody3D)
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
- **`PhysicsGrabber3D.gd`**: proyecta el ratón a través de la cámara. En `_physics_process` consulta `direct_space_state`, resuelve la primera colisión y actualiza el hover. Al agarrar intersecta el rayo con un plano horizontal situado `lift_height` por encima del centro de la pieza, conservando el desplazamiento horizontal inicial. En cada tick aplica un controlador proporcional y de amortiguación de velocidad, con compensación de gravedad y aceleración máxima. No mueve el cuerpo mediante transformaciones directas; al soltar limita la velocidad y deja que la gravedad y colisiones continúen actuando. Al perder foco también suelta. El controlador actúa sobre el centro, por lo que no mantiene la orientación ni alinea la pieza con la cámara.
- **`InteractiveTableObject.gd`**: clase base con nombre, estado de hover/agarre, señales y un `material_overlay` translúcido por instancia sobre el nodo `Visual`. `on_grab`, `on_release` y `rotate_object` son puntos de extensión; la rotación se aplica como impulso, no como teletransporte. Los hijos decorativos del visual no se resaltan automáticamente.
- **`Dice3D.gd`**: aplica impulso y torque aleatorios y espera `sleeping_state_changed` antes de emitir `result_ready`. Compara las normales locales de las seis caras transformadas al mundo con `Vector3.UP` y elige el mayor producto escalar. Las marcas se generan con el mismo mapa de valores, con caras opuestas sumando siete. `top_face()` también permite consultar la orientación directamente; sobre una superficie irregular o con el dado encajado, elige la cara más cercana a arriba, no valida que esté perfectamente plana. Solo informa tras una tirada con T, no después de cada movimiento manual.
- **`Card3D.gd`**: congela temporalmente la carta, interpola su cuaternión 180° en su eje local y vuelve a activar la física. Las caras son colores distintos, no texturas. Es una animación sencilla, no un giro con detección continua de colisiones: usar con espacio libre; para producción conviene barrer la geometría o usar un controlador/joint físico.
- **`Deck3D.gd`**: instancia cartas independientes desde una escena exportada, en una posición desplazada del mazo, y decrementa el contador. No representa cada carta físicamente dentro del mazo ni implementa agrupación, barajado o identidades de carta; el contador evita robar indefinidamente. La posición de aparición debe mantenerse libre para evitar solapamientos.
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
```

El smoke test comprueba la carga de la escena, las caras 1 y 6 del dado, la creación de cartas y la finalización del volteo. Para comprobar la interacción real: orbita, desplaza y acerca la cámara; arrastra cada pieza por la mesa y hacia otra pieza; suelta, lanza el dado con T y espera el resultado; voltea una carta con F; roba hasta agotar el mazo con N. Verifica también la pérdida de foco y que el tablero oculte las piezas situadas debajo. El análisis sintáctico con `gdlint` no sustituye una ejecución y una prueba visual/física en Godot.

## Extensión multijugador (diseño, no implementado)

Usa un servidor autoritativo con IDs estables por pieza y un único simulador físico. Los clientes envían comandos de intención (`request_grab`, objetivo limitado, `release`, `roll`, `flip`, `draw`); el servidor valida identidad, distancia, ritmo de mensajes y estado, concede un bloqueo temporal por pieza y lo libera al soltar, desconectar o expirar. El servidor decide tiradas y contenido del mazo, y replica resultados y snapshots de transformaciones/velocidades con número de secuencia; los clientes interpolan y pueden predecir únicamente su interacción local, reconciliando con el servidor. No sincronices directamente las transformaciones de `RigidBody3D` desde varios peers ni confíes en valores de dado enviados por el cliente. Para cartas ocultas, envía la identidad únicamente a quienes tengan permiso. Añade pruebas con latencia, pérdida de paquetes, reconexión y solicitudes simultáneas antes de considerarlo apto para producción.
