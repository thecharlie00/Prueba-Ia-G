# Guía de Dirección de Arte, Diseño de Feedback Visual («Juice») y Biblia de Referencias Técnicas

**Proyecto:** *Tablerama*  
**Motor:** Godot 4.7 (`gl_compatibility` + Jolt Physics 3D a 90 Hz)  
**Red:** Photon Fusion (`libfusion` GDExtension, topología anfitrión autoritativo por eventos)  
**Estado:** Implementado e integrado sobre las escenas 3D y las 12 mesas online

---

## Índice

1. [Módulo 1: Análisis de la Base Existente e Integración Estética](#modulo-1)
2. [Módulo 2: Representación 3D de Jugadores y Cartas de Rivales](#modulo-2)
3. [Módulo 3: Diseño de «Juice» Táctil y Manipulación de Objetos](#modulo-3)
4. [Módulo 4: Shaders, Materiales e Iluminación (Godot 4.7)](#modulo-4)
5. [Módulo 5: Feedback Social y Micro-Interacciones Multijugador](#modulo-5)
6. [Módulo 6: Optimización y Checklist Técnico para el Motor](#modulo-6)

---

<a id="modulo-1"></a>
## MÓDULO 1: ANÁLISIS DE LA BASE EXISTENTE E INTEGRACIÓN ESTÉTICA

### 1.1 Mapa de Arquitectura Real y Acoplamiento No Intrusivo

Toda la capa expresiva 3D se acopla sobre la arquitectura existente de *Tablerama* respetando tres invariantes inquebrantables:

1. **Separación estricta entre física (`RigidBody3D`) y malla visual (`$Visual`):** Jolt Physics mantiene todos los `CollisionShape3D` en escala `Vector3.ONE`, mientras que las deformaciones elásticas (*squash & stretch*), la elevación de *hover*, el cabeceo de piezas pesadas y la flexión aerodinámica ocurren exclusivamente en `$Visual` o en el *vertex shader*.
2. **Autoridad de reglas intacta en Photon Fusion (`NetTable`):** El estado determinista (`export_record()` / `snapshot()`) jamás mezcla variables visuales efímeras. Los cursores 3D, pings y emotes viajan por RPCs cosméticos independientes con limitación de frecuencia (*rate-limiting*).
3. **Compatibilidad total con `gl_compatibility`:** Todos los *shaders* espaciales compilan bajo OpenGL 3.3 / GLES3 sin depender de *buffers* exclusivos de *Forward+*, apoyándose en iluminación *toon* de dos bandas, foco cenital sin coste de mapa de sombras adicional y *pools* reutilizables de partículas en CPU.

| Sistema Lógico | Implementación Base en el Proyecto | Capa Visual y Expresiva Integrada |
| :--- | :--- | :--- |
| **Sesión y Salas (`RoomManager`)** | Autoload `Net` (`scripts/net/NetManager.gd`) | Identidad cromática de butaca (`Palette.PLAYER_*`), estado de bots (`room_bots`) y corona de anfitrión. |
| **Protocolo Online (`NetworkBehaviour`)** | `NetTable` y `*NetTable.gd` (`scripts/net/`) | Señal `rule_applied` para impactos visuales + RPCs cosméticos `net_cursor`, `net_emote` y `net_ping`. |
| **Controlador de Asientos (`SeatController`)** | `TableSeats` (`scripts/table/TableSeats.gd`) + `TableHud` | Busto articulado (`HeadPivot`), cejas/pupilas expresivas, manos flotantes (`HandL`/`HandR`), `RivalHandFan3D` y `EmoteBubble3D`. |
| **Piezas Físicas e Interacción** | `InteractiveTableObject`, `Card3D`, `PhysicsGrabber3D` | Borde *Fresnel* multiestado (`RimGlow`), sombra de contacto (`ContactShadow`), flexión `card_flex.gdshader` y `flash_invalid()`. |
| **Mano en Primera Persona** | `Hand3D` (`scripts/cards/Hand3D.gd`) | Apertura viva de cartas vecinas, inclinación magnética 3D al cursor y alabeo inercial al reordenar. |
| **Iluminación y Escenario** | `ToonStyle` + `RoomDecor` (`scripts/style/`) | Juntas de parqué en `MultiMeshInstance3D`, lámpara colgante con foco cálido `TableWarmSpot` y *pool* `TableVfx`. |

### 1.2 Dirección Estética Global: «Juguetería Táctil Ilustrada»

* **Siluetas *Chunky* y Cantos Redondeados:** Piezas construidas con `PieceKit` (`rounded_slab`, `rounded_disc`, `lathe`) con biseles amplios que capturan destellos limpios en modo `SPECULAR_TOON` y contornos `INK (#1d1a3a)` de grosor proporcional (`toon_outline.gdshader`).
* **Jerarquía de Color y Valor (`Palette.gd`):**
  * **Fondo y Arquitectura (Calidez Media, Saturación Contenida):** Madera `WOOD (#8a4f2a)`, pared crema `#e9c9a0` y tapete mate `FELT (#1e7a5f)` actúan como lienzo neutro.
  * **Foco Jugable (Contraste Alto):** Cartas `PAPER (#fff8ec)`, acentos `SUN (#ffc83d)`, confirmación `MINT (#4fd6a0)`, rechazo `CORAL (#ff6b5e)` y colores vivos de jugador.
* **Accesibilidad de Movimiento (`ToonStyle.reduce_motion`):** Cualquier oscilación continua, vibración de cámara (*table trauma*), rebote elástico o arqueo de carta comprueba `reduce_motion` en tiempo real y pasa a estado estático limpio cuando el jugador activa «Reducir animaciones».

### 1.3 Biblia de Referencias (*Moodboard* Técnico)

* **Hearthstone:** Apertura orgánica de cartas vecinas al hacer *hover* en mano, inclinación especular hacia el cursor, impactos con corona de polvo radial y micro-sacudida en jugadas de triunfo o alto valor.
* **MultiVersus / Crash Bandicoot 4:** Sombreado *stylized* limpio con sombras lavanda (`AMBIENT #c7c9ff`) frente a luz solar cálida (`SUNLIGHT #fff1d9`), cabezas expresivas con cejas flotantes y manos desacopladas de silueta inmediata.
* **Demeo / Tabletop Simulator:** Habitación de casa de muñecas de una sola cara (`cull_back`), haz de sol diagonal en ventana, foco cálido concentrado sobre el tapete y manos 3D coloreadas señalando el tablero en multijugador.
* **Pummel Party:** Expresividad social instantánea mediante bocadillos tipo cómic sobre el avatar, miradas compartidas hacia los dados en movimiento y gestos de celebración o sorpresa.

---

<a id="modulo-2"></a>
## MÓDULO 2: REPRESENTACIÓN 3D DE JUGADORES Y CARTAS DE RIVALES

### 2.1 Avatares Cartoon Articulados (`scripts/table/TableSeats.gd`)

Cada asiento `Seat0..SeatN` se sitúa estrictamente fuera de `TableSeats.table_aabb(...).grow(0.42)` (`AVATAR_CLEARANCE = 0.6 m`) para no invadir nunca el área física del tablero, ocultándose automáticamente cuando coincide con el lado de la cámara (`near[i] == true`) y delegando su representación en la placa 2D de `TableHud`.

```text
Seat<i> (Node3D)
 ├── Body (Node3D)                 <-- Respiración suave en espera y bote en turno activo
 │    ├── Shell + Collar + Patch   <-- Torso torneado con cuello claro y emblema frontal
 │    ├── HeadPivot (Node3D)       <-- Look-At suavizado y acotado (±39° yaw, -20°..+15° pitch)
 │    │    ├── HeadMesh            <-- Cabeza cartoon redondeada con contorno INK
 │    │    ├── EyeL/R + PupilL/R   <-- Pupilas que anticipan el giro de cabeza
 │    │    ├── BrowL / BrowR       <-- Cejas flotantes articuladas según emoción/foco
 │    │    ├── Mouth               <-- Arco expresivo adaptable a sonrisa, asombro o risa
 │    │    └── Antena Bot / Corona <-- Indicador visual de IA o anfitrión de sala
 │    ├── HandL (Node3D)           <-- Manopla cartoon izquierda (sostiene abanico rival)
 │    └── HandR (Node3D)           <-- Manopla derecha (piensa en barbilla, aplaude o celebra)
 ├── RivalHandFan (RivalHandFan3D) <-- Abanico 3D de dorsos sincronizado en tiempo real
 ├── EmoteBubble (EmoteBubble3D)   <-- Globo de reacción tipo cómic
 ├── TurnRing (MeshInstance3D)     <-- Aro solar rotatorio del jugador en turno
 └── NameLabel + StatusLabel       <-- Etiquetas billboard con borde de tinta
```

### 2.2 Abanico 3D de Cartas de Rivales (`scripts/table/RivalHandFan3D.gd`)

* **Sincronización Exacta y Privacidad Total:**
  * `RivalHandFan3D` recibe únicamente un entero `card_count` (`TableSeats.set_card_count(seat, count)`), conectado automáticamente a `BriscaView.hud_seat_cards()` e `IslandView._update_seats()` (recursos + cartas de desarrollo ocultas de cada rival).
  * Tanto el anverso como el reverso de cada losa del abanico montan exclusivamente `CardArt.texture("back")`. Aunque el jugador gire la cámara `360°` alrededor de la mesa, **no existe ninguna textura de cara frontal cargada en los nodos del rival**.
* **Disposición Paramétrica y *Pool* Estático:**
  * Pre-aloja `MAX_VISIBLE_CARDS = 10` ranuras sin colisionadores (`PieceKit.rounded_slab`), distribuidas en arco con escalonamiento de profundidad (`0.007 m` por carta) para evitar *Z-fighting*.
  * Cuando el rival acumula más de 3 cartas muestra una insignia flotante `×N` en `Lilita One`, y al robar nuevas cartas las incorpora con una transición ascendente suave.

### 2.3 Micro-Animaciones e *Idle* con Atención Compartida (*Look-At*)

* **Foco de Mirada (`set_focus_target`):** `SocialOverlay3D` alimenta el punto de atención de `TableSeats` priorizando: (1) piezas agarradas por `PhysicsGrabber3D`, (2) dados rodando en el tablero, (3) último `Ping` (`KEY_P`) y (4) miradas periódicas al jugador activo o a su propio abanico de cartas.
* **Matemática Segura sin Errores de Colinealidad:** En lugar de llamar a `Node3D.look_at()` en cada fotograma, `HeadPivot` calcula ángulos acotados con `atan2` en espacio local del asiento, garantizando estabilidad numérica absoluta incluso en modo `--headless`.
* **Reordenación Sutil (*Card Fidgeting*):** Cada `5.2–8.8 s` una carta aleatoria del abanico rival se eleva `4.2 cm` durante `0.42 s`, transmitiendo que el oponente evalúa sus opciones.

---

<a id="modulo-3"></a>
## MÓDULO 3: DISEÑO DE «JUICE» TÁCTIL Y MANIPULACIÓN DE OBJETOS

### 3.1 Interacción Multicapa con Cartas (`Hand3D` y `Card3D`)

1. **En Mano (`Hand3D.gd`):**
   * **Inclinación Magnética 3D:** Al ampliar una carta bajo el ratón, su orientación calcula el desplazamiento local respecto al centro proyectado para aplicar cabeceo y alabeo suaves (`±8.5°` / `±10°`) junto con flotación sinusoidal.
   * **Separación Orgánica:** Las cartas adyacentes se abren lateralmente en proporción inversa a su distancia al índice señalado (`0.11 / |dist|`), facilitando la selección en manos numerosas (*La Isla*).
   * **Inercia de Reordenación:** Al arrastrar una carta de hueco, su ángulo responde dinámicamente a la velocidad horizontal del cursor.
2. **En Mesa (`Card3D.gd` e `InteractiveTableObject.gd`):**
   * **Elevación de *Hover* y Sombra Dinámica (`ContactShadow`):** Pasar el cursor eleva `$Visual` `2.2 cm` y proyecta sobre `y = 0.806` una sombra suave independiente de la rotación del cuerpo físico, cuya escala aumenta con la altura para indicar con precisión milimétrica el punto de caída.
   * **Flexión Aerodinámica (`card_flex.gdshader`):** La malla compartida `QuadMesh` (`8 × 12` subdivisiones) arquea las esquinas de la carta en función del vector local de velocidad durante el arrastre.
   * **Impacto Táctil (`TableVfx` + `TabletopCamera3D.add_trauma`):** Soltar piezas emite un anillo plano expansivo y 6 motas cartoon a ras de fieltro; las jugadas clave (triunfo o carta de valor en Brisca, ladrón en la Isla) añaden estrellas doradas y una micro-vibración amortiguada de cámara sin alterar `focus` ni `distance`.

### 3.2 Peso de Fichas, Piezas y Lenguaje Cromático de Estados

* **Asentamiento con Peso (`trigger_settle_wobble`):** Los trebejos torneados (`PhysicalChessPiece`) ejecutan al posarse una breve oscilación amortiguada en `$Visual.rotation.z`, evocando el contrapeso de madera plomada.
* **Cuatro Estados Visuales Inequívocos:**
  1. **Reposo:** Contorno `Palette.INK` estándar de `ToonStyle`.
  2. **Señalado (`Hovered`):** Borde *Fresnel* `Palette.SUN_LIGHT (#ffd96e)` + elevación visual ligera.
  3. **Agarrado (`Grabbed`):** Borde *Fresnel* `Palette.MINT (#4fd6a0)` + inclinación por velocidad + sombra proyectada.
  4. **Jugada Inválida (`flash_invalid()`):** Conectado a `GuidedPhysicalChess`, `GuidedPhysicalCheckers` y `GuidedDomino`; al soltar en destino ilegal dispara un destello `Palette.CORAL (#ff6b5e)` de `0.34 s` con sacudida horizontal de negación en `$Visual`.

---

<a id="modulo-4"></a>
## MÓDULO 4: SHADERS, MATERIALES E ILUMINACIÓN (GODOT 4.7)

### 4.1 Shaders Espaciales integrados (`shaders/`)

* **`shaders/interactive_rim_overlay.gdshader`:** Aplicado sobre el subnodo `$Visual/RimGlow` (`cast_shadow = OFF`, `toon_style_applied = true`), conservando además el `StandardMaterial3D` transparente en `$Visual.material_overlay` para plena compatibilidad con el pipeline de `ToonStyle`. Calcula `pow(1.0 - abs(dot(NORMAL, VIEW)), rim_power)` con pulso suave configurable.
* **`shaders/card_flex.gdshader`:** Deforma los vértices a lo largo de `NORMAL` según `drag_bend` (con `bend_sign` opuesto en anverso y reverso para mantener grosor constante) y añade un sutil reflejo satinado sin apagar la blancura `PAPER` de `CardArt`.

### 4.2 Iluminación Escénica de Sobremesa (`RoomDecor.gd`)

* **Luz Clave + Ambiente Lavanda (`ToonStyle.gd`):** `DirectionalLight3D` cálida (`#fff1d9`, energía `0.85`, sombras al `55 %`) combinada con ambiente `#c7c9ff` (`0.5`).
* **Lámpara Colgante y Foco Cenital (`TableLamp` / `TableWarmSpot`):** `SpotLight3D` cálido (`#ffe4b5`, energía `0.44`, ángulo `54°`, atenuación `1.45`, `shadow_enabled = false`) suspendido sobre el centro de la mesa junto con un haz solar translúcido en la ventana (`WindowSunbeam`), concentrando la calidez lumínica sobre las cartas, mazos y fichas sin añadir pasadas de sombra extra.

---

<a id="modulo-5"></a>
## MÓDULO 5: FEEDBACK SOCIAL Y MICRO-INTERACCIONES MULTIJUGADOR

### 5.1 Canal Social sobre Photon Fusion (`NetTable.gd` + `SocialOverlay3D.gd`)

Tres RPCs ligeros y sin estado persistente en `NetTable`:
* `net_cursor(sender_id, seat, qx, qy, qz, state)`: coordenadas cuantizadas a centímetros (`int`), enviadas como máximo a **10 Hz** y solo si el cursor se desplazó `> 3.5 cm` o cambió su estado de agarre.
* `net_emote(sender_id, seat, emote_id)`: enfriamiento anti-spam de `800 ms` en red y `1000 ms` en cliente local.
* `net_ping(sender_id, seat, qx, qy, qz)`: enfriamiento de `700 ms`, conectado automáticamente a `PhysicsGrabber3D.pinged` (`KEY_P`) o al plano de mesa en tableros sin agarre físico.

### 5.2 Emotes Tipo Cómic (`EmoteBubble3D.gd`) y Punteros 3D

* **Seis Reacciones Universales (`KEY_G` o botón `☺`):** `★ ¡TOMA!`, `?! ¡¿QUÉ?!`, `XD ¡JAJA!`, `» ¡TU TURNO!`, `♦ ¡BUENA!` y `… ¡UPS!`, traducidas a ES/EN/CA en `UiStrings.gd`.
* **Redirección Inteligente para Asientos en Cámara:** Si el jugador que emite el emote tiene su avatar oculto por estar del lado de la cámara (`seats.near[seat] == true`), `SocialOverlay3D` muestra además una tarjeta cómic 2D (`NearEmoteToast`) sobre la zona de placas de jugador.
* **Manos Puntero Remotas (`RemotePointer0..3`):** Guante cartoon con puño del color oficial de la butaca, sombra suave en el tapete, gesto de pellizco al sujetar pieza e interpolación exponencial a `60+ FPS` con ocultación automática tras `3.5 s` de inactividad.

---

<a id="modulo-6"></a>
## MÓDULO 6: OPTIMIZACIÓN Y CHECKLIST TÉCNICO PARA EL MOTOR

### 6.1 Presupuesto Poligonal y Reducción de *Draw Calls*

| Elemento | Presupuesto por Unidad | Optimización Aplicada en Código |
| :--- | :---: | :--- |
| **Juntas de Parqué (`RoomDecor`)** | `2 tris` / junta | Convertidas de **462 `MeshInstance3D` sueltos a 2 `MultiMeshInstance3D`** (`FloorboardLines` + `FloorboardCuts`), ahorrando ~460 *draw calls* en todas las mesas. |
| **Avatar Articulado (`TableSeats`)** | `~1.150 tris` | Jerarquía rígida de nodos (`HeadPivot`, `HandL/R`) sin coste de `Skeleton3D` ni *skinning* de huesos. |
| **Abanico Rival (`RivalHandFan3D`)** | `~44 tris` / carta | Mallas y materiales estáticos compartidos entre todos los asientos; `set_process(false)` cuando `card_count == 0`. |
| **Carta Física (`Card3D`)** | `~220 tris` | `QuadMesh` subdividido (`8×12`) único compartido estáticamente (`Card3D._shared_quad`). |
| **Piezas en Reposo (`InteractiveTableObject`)** | `120–320 tris` | `set_process(false)` automático al volver al reposo: 90+ piezas dormidas consumen **0.00 ms de script por fotograma**. |
| **Partículas e Impactos (`TableVfx`)** | Pool circular fijo (`8 + 4`) | Pre-alojamiento al abrir escena + `ShaderWarmup` de 3 fotogramas para eliminar picos `>= 50 ms` en `PerfMeter`. |

### 6.2 Checklist de Verificación Técnica

- [x] Colisionadores `CollisionShape3D` y escala de `RigidBody3D` permanecen en `Vector3.ONE`.
- [x] Asientos `TableSeats` se mantienen fuera de `bounds.grow(0.42)` en todos los tableros.
- [x] Resaltado transparente en `$Visual.material_overlay` conserva `StandardMaterial3D` sin `DIFFUSE_TOON` ni `next_pass`.
- [x] `RivalHandFan3D` utiliza exclusivamente enteros públicos y texturas `back` en ambas caras.
- [x] Todos los envíos a `Fusion.rpc` comprueban `Engine.has_singleton("Fusion") and Fusion.is_in_room()`.
- [x] Todas las animaciones secundarias, vibraciones y arqueos respetan `ToonStyle.reduce_motion`.
