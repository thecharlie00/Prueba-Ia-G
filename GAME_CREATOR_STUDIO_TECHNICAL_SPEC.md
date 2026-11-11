# Game Creator Studio — Especificación Técnica de Arquitectura

**Motor:** Godot 4.7 (C# / .NET 6 + GDScript opcional)
**Red multijugador:** Photon Fusion 2 (host-authoritative / shared-mode configurable)
**Ámbito:** Editor universal de juegos de mesa, tablero, cartas, estrategia y arcade ligero (UGC)
**Versión del documento:** 1.0

---

## Índice

1. [Resumen Ejecutivo y Principios de Diseño](#1-resumen-ejecutivo-y-principios-de-diseño)
2. [Módulo 1: Arquitectura General del Editor — Workspace & Viewports](#2-modulo-1-arquitectura-general-del-editor)
3. [Módulo 2: Sistema de Objetos y Componentes Modulares — Prefab & Prop System](#3-modulo-2-sistema-de-objetos-y-componentes-modulares)
4. [Módulo 3: Editor de Cartas y Generador de Majos — Card & Deck Builder Studio](#4-modulo-3-editor-de-cartas-y-generador-de-majos)
5. [Módulo 4: Motor de Lógica Visual y Scripting — Visual Scripting / Rule Engine](#5-modulo-4-motor-de-logica-visual-y-scripting)
6. [Módulo 5: Sistema de Dados y Físicas Probabilísticas — Dice & Randomness Engine](#6-modulo-5-sistema-de-dados-y-fisicas-probabilisticas)
7. [Módulo 6: Gestión de UI/HUD Personalizada para Creadores](#7-modulo-6-gestion-de-uihud-personalizada)
8. [Módulo 7: Workshop, Empaquetado y Distribución — Cloud Sync & ModSharing](#8-modulo-7-workshop-empaquetado-y-distribucion)
9. [Módulo 8: Especificación Técnica de Clases en C# (Godot 4.7)](#9-modulo-8-especificacion-tecnica-de-clases-en-csharp)
10. [Apéndice: Formatos de Archivo, Esquemas de Datos y Flujo de Red](#10-apendice-formatos-de-archivo)

---

## 1. Resumen Ejecutivo y Principios de Diseño

Game Creator Studio (GCS) es un editor de juegos tipo "Tabletop Simulator meets Roblox Studio" integrado nativamente en Godot 4.7. Permite a cualquier usuario crear, configurar, programar visualmente, probar y publicar juegos de mesa sin escribir código, mientras expone una capa profunda en C# para creadores avanzados.

### Principios arquitectónicos

| Principio | Descripción |
|-----------|-------------|
| **Host-Authoritative por defecto** | Photon Fusion gestiona la autoridad del estado; el host valida movimientos, lanzamientos de dados y barajados para evitar trampas. |
| **Composición sobre herencia** | Cada objeto colocable es una `PropEntity` vacía a la que se acoplan `BehaviorComponent`s en tiempo de edición. |
| **Edición y ejecución en el mismo espacio** | Build Mode y Playtest Mode comparten la misma escena; el hot-reload permite probar sin salir del editor. |
| **Serialización declarativa** | Todo el estado editable se serializa a JSON/Resource para guardar, cargar y empaquetar mods (`.gmod`). |
| **UX primero, código opcional** | El creador casual arrastra y configura; el experto hereda de las clases base en C# y extiende el motor de reglas. |
| **Multiplataforma de exportación** | Los mods empaquetados se descargan y montan en clientes remotos mediante Photon Fusion `SessionProperties`. |

---

## 2. Módulo 1: Arquitectura General del Editor — Workspace & Viewports

### 1.1 Diseño de la Interfaz Estilo IDE Modular (Dockable Panels)

El editor se implementa como una única escena raíz `GameCreatorEditor` (Control) con un `ViewportContainer` principal y paneles dockables implementados como `PanelContainer` + `TabContainer`. Cada panel es un nodo autónomo que se puede flotar, acoplar o cerrar.

#### Viewport 3D Principal (`WorkspaceViewport3D`)
- Nodo raíz: `Viewport3D` con `WorldEnvironment` propio (luz ambiental, skybox opcional, rejilla de suelo).
- Cámara de edición: `Camera3D` con modo órbita, pan y zoom; velocidades configurables por el usuario.
- **Gizmos de manipulación:** nodos `MeshInstance3D` con shaders de gizmo (flechas XYZ, planos, cubos de escala) renderizados siempre por encima (canvas-layer equivalente en 3D mediante `SubViewport` o profundidad forzada).
- **Snap a rejilla:** activable/desactivable; tamaño de celda configurable (0.25 m por defecto para tablero, 0.05 m para ajuste fino).
- **Alineación magnética:** raycast contra superficies de objetos existentes para "pegar" entidades al moverlas cerca.
- **Selección múltiple:** caja de selección (lasso 2D proyectada al plano de trabajo) y selección individual con clic.
- **Barra de herramientas inferior:** botones de modo (seleccionar, mover, rotar, escalar, colocar, borrar), botón de playtest y selector de jugador simulado.

#### Inspector de Propiedades (`PropertyInspector`)
- `ScrollContainer` + `VBoxContainer` dinámico.
- Se reconstruye al cambiar la selección usando introspección de C# (`[Export]` properties) y GDScript exportados.
- Secciones colapsables: Transform, Físicas, Contenedor, Interacción, Red, Reglas, Apariencia.
- Campos de entrada contextuales: `SpinBox` para números, `ColorPicker` para colores, `FileDialog` para assets, `OptionButton` para enums, `CheckBox` para booleanos.
- Soporte para edición de listas (arrays de mazos, listas de reglas, arrays de jugadores).

#### Jerarquía de Escena (`SceneTreeEditor`)
- `Tree` que refleja el árbol de nodos de la escena de edición en tiempo real.
- Nodos lógicos (no visibles) marcados con icono distinto (reglas, zonas, controladores de turno).
- Arrastrar y soltar dentro del árbol para reparentar entidades.
- Cambio de nombre, activar/desactivar (`set_visible` / `set_process`), bloquear selección.

#### Asset Browser (`AssetBrowser`)
- `FileSystemDock` personalizado con pestañas: Modelos 3D, Texturas, Sonidos, Barajas, Scripts, Prefabs.
- Vista en grid (miniaturas) y lista.
- Buscar por nombre, etiquetas y tipo de recurso.
- Panel de nube: descarga de mods publicados desde el Workshop (Módulo 7).
- Arrastrar un asset al Viewport 3D instancia automáticamente una `PropEntity` con el componente adecuado.

### 1.2 Modos de Operación (Estados del Editor)

El editor expone un `EditorStateMachine` con dos estados principales:

#### Build Mode (Modo Edición)
- El Viewport 3D es interactivo para colocar, configurar y conectar objetos.
- Se desactiva la simulación de física del juego (los `RigidBody3D` se ponen en `STATIC` o se desactiva `mode`).
- Las reglas del motor lógico no se ejecutan; solo se editan definiciones.
- Se muestra el grid de tablero, los gizmos y los paneles de configuración.

#### Playtest Mode (Modo Prueba)
- Transición instantánea en caliente (Hot-Reload): se duplica la escena actual en un `WorldEnvironment` de prueba o se activa `set_pause(false)` en una copia en tiempo de ejecución.
- **Simulación multijugador local:** se spawnan hasta 4 `LocalPlayerProxy` con cámaras divididas o turnos por asiento; cada uno controla sus propias fichas/cartas mediante input simulado.
- **Depuración de red Photon Fusion:** se inicia un `NetworkRunner` en modo `Host` o `SharedClient` conectando a Fusion Cloud o a un servidor local; se puede forzar latencia artificial y pérdida de paquetes para probar resincronización.
- **Hot-Reload de reglas:** al editar un nodo de reglas en Build Mode y volver a Playtest, el `RuleEngine` recarga la definición sin reiniciar la partida (carga en caliente de JSON de reglas).
- Botón "Volver a Edición" que conserva el estado de la partida para inspección y vuelve a Build Mode.

---

## 3. Módulo 2: Sistema de Objetos y Componentes Modulares — Prefab & Prop System

### 2.1 Arquitectura basada en Componentes (ECS híbrido)

No se usa ECS puro de memoria contigua (Godot no lo expone de forma nativa en C# de alto rendimiento sin wrappers), sino **Composición basada en nodos**: cada objeto colocable hereda de `PropEntity : Node3D` y agrega `BehaviorComponent : RefCounted` o `Node` hijos según la funcionalidad.

```
PropEntity (Node3D)
├── TransformComponent (pos, rot, scale, snap)
├── PhysicsComponent (RigidBody3D/CollisionShape3D wrapper)
├── ContainerComponent (zona lógica: mano, mazo, descarte)
├── InteractiveComponent (clic, arrastre, volteo, inspección)
├── NetworkedPropComponent (vínculo Photon Fusion)
└── VisualComponent (mesh, material, animaciones)
```

Cada `BehaviorComponent` expone `[Export]` propiedades editables desde el Inspector y se serializa automáticamente al guardar el mod.

### 2.2 Componentes comportamentales

| Componente | Clase base | Propiedades clave | Uso típico |
|------------|-----------|-------------------|------------|
| `PhysicsComponent` | `RefCounted` | `mass`, `friction`, `bounce`, `gravity_scale`, `stackable`, `collision_layer`, `collision_mask` | Fichas, dados, cartas, miniaturas |
| `ContainerComponent` | `RefCounted` | `container_type` (Hand, Deck, Discard, Supply), `hidden_faces` (bool), `max_capacity`, `slot_spacing` | Mano del jugador, mazo, pila de descarte |
| `InteractiveComponent` | `RefCounted` | `clickable`, `draggable`, `flippable`, `inspect_on_hover`, `drag_snap_to_grid` | Cualquier objeto manipulable |
| `NetworkedPropComponent` | `RefCounted` | `networked`, `authority_mode` (StateAuthority / InputAuthority), `sync_position`, `sync_rotation`, `sync_custom_state` | Objetos replicados en red |
| `VisualComponent` | `RefCounted` | `mesh_path`, `material_path`, `scale_factor`, `color_tint`, `billboard` | Apariencia 3D |

### 2.3 Prefabs y entidades guardadas

- Un `PropEntity` configurado puede guardarse como **Prefab** (`.tres` / `.tscn` personalizado) en el Asset Browser.
- Al arrastrar un prefab al Viewport, se instancia una copia profunda con un `EntityId` único generado (GUID).
- Los prefabs pueden anidarse (prefab dentro de prefab) para mazos de cartas con dorso y frente preconfigurados.

### 2.4 Físicas de apilamiento y colisión

- `PhysicsComponent.stackable = true` activa filtros de colisión entre objetos del mismo tipo para permitir pilas de cartas o fichas apiladas sin penetración.
- Se usa `CollisionShape3D` de caja o cápsula según la geometría del asset.
- Dados usan `RigidBody3D` en modo `Rigid` con gravedad activada solo durante el lanzamiento (Módulo 5).

---

## 4. Módulo 3: Editor de Cartas y Generador de Majos — Card & Deck Builder Studio

### 3.1 Estructura de datos de una carta

Cada carta es un recurso `CardData : Resource` con:

```csharp
public class CardData : Resource
{
    [Export] public string CardId { get; set; } = Guid.NewGuid().ToString();
    [Export] public string Name { get; set; }
    [Export] public string Description { get; set; }
    [Export] public Texture2D FrontArt { get; set; }
    [Export] public Texture2D BackArt { get; set; } // compartido por el mazo
    [Export] public int Cost { get; set; }
    [Export] public int Attack { get; set; }
    [Export] public int Defense { get; set; }
    [Export] public List<CardIcon> Icons { get; set; } = new();
    [Export] public CardFrame FrameStyle { get; set; } = CardFrame.Classic;
    [Export] public Dictionary<string, Variant> CustomFields { get; set; } = new();
}
```

### 3.2 Generación masiva basada en plantillas

**Importación tabular:**
- Soporta CSV, JSON y Google Sheets exportado a JSON.
- El mapeo de columnas a campos de `CardData` se configura visualmente (arrastrar nombre de columna a campo).
- Vista previa de las primeras N cartas antes de generar.

**Editor de plantillas (Front/Back):**
- Capas de imagen: fondo, marco, ilustración, iconos, texto superpuesto.
- Campos de texto dinámicos vinculados a `Name`, `Description`, `Cost`, etc.
- Iconos condicionales: se muestra el icono de "Ataque" solo si `Attack > 0`.
- Marcos estilizados (Stylized/Cartoon): seleccionables desde paleta de `Palette.gd`-style (adaptado a C#).

### 3.3 Mecánicas de mazo

| Mecánica | Implementación |
|----------|---------------|
| Barajado determinista sincronizado | `Deck.Shuffle(seed)` usando `System.Random` con semilla negociada por el host de Photon Fusion; todos los clientes aplican la misma secuencia. |
| Mazo infinito | `InfiniteDeck` que regenera cartas desde un `CardPool` cuando se agota. |
| Descarte | `DiscardPile` como `ContainerComponent` con `hidden_faces = false`. |
| Robo con animación fluida | `Tween` del `CardEntity` desde mazo a mano; `ContainerComponent` recalcula posiciones de slots. |
| Visibilidad por rol/asiento | `ContainerComponent.hidden_faces` controla si el oponente ve el dorso o el frente; aplicado en el shader/material al renderizar. |

### 3.4 Flujo de creación de baraja

1. Abrir "Nuevo Mazo" en el Asset Browser.
2. Importar CSV o crear carta base y duplicar.
3. Editar plantilla de frente y dorso.
4. Asignar cantidad de copias por carta.
5. Guardar como `DeckDefinition : Resource` (lista de `CardData` + cantidades).
6. Vincular el mazo a un `ContainerComponent` de tipo `Deck` en la escena del tablero.

---

## 5. Módulo 4: Motor de Lógica Visual y Scripting — Visual Scripting / Rule Engine

### 4.1 Diseño de nodos lógicos

El `RuleEngine` interpreta un grafo de nodos serializado en JSON. Cada nodo es un `RuleNode : Resource` con:

- `Guid` único.
- `Ports` de entrada y salida (`ExecutionPort`, `ValuePort`).
- `LogicType`: `Event`, `Condition`, `Action`, `Variable`, `Gate`.

#### Tipos de nodo

**Eventos (Triggers) — punto de entrada del grafo:**
- `OnTurnStarted` — se dispara al inicio del turno de un jugador.
- `OnCardPlayed(card, player)` — cuando una carta se juega desde la mano.
- `OnDiceRolled(diceResult)` — tras lectura del dado físico.
- `OnTokenMoved(token, fromSquare, toSquare)` — al terminar un tránsito de ficha.
- `OnZoneEntered(entity, zone)` — al entrar una entidad en una zona lógica.

**Acciones (Operations):**
- `MoveObjectTo(entity, targetPosition, duration, ease)` — traslada con Tween.
- `FlipCard(cardEntity)` — invierte frente/dorso.
- `ModifyPlayerScore(player, delta)` — ajusta puntuación.
- `SpawnEntity(prefabId, position, rotation)` — instancia un prefab.
- `PlaySoundFX(soundPath, volume)` — reproduce audio.
- `SendNotification(player, message)` — UI flotante.
- `SetVariable(name, value)` — escribe variable global/local.
- `EndTurn()` — avanza al siguiente jugador.

**Condicionales y Variables:**
- `If / Else` — rama de ejecución booleana.
- `Compare` (==, !=, >, <, >=, <=) entre dos valores.
- `And / Or` — lógica booleana.
- `VariableGet / VariableSet` — lectura/escritura de variables globales o por jugador.
- `RandomRange(min, max)` — valor aleatorio controlado por semilla de red.

### 4.2 Ejecución segura

- El motor ejecuta nodos en un hilo de trabajo separado del hilo de renderizado para no bloquear el frame.
- Cada nodo tiene un `maxExecutionTime` (watchdog de 50 ms) para evitar bucles infinitos.
- Las acciones que modifican el estado de red requieren `HasStateAuthority` (host) o se envían como RPC a través de Photon Fusion.

### 4.3 Ejemplo de regla visual

> "Si la ficha del Jugador 1 cae en la casilla X, robar 2 cartas y cambiar el turno"

```
[OnTokenMoved] --> [Compare: token.player == 1 AND square == X]
                                    |
                                    | true
                                    v
                           [SpawnEffect] --> [DrawCard: player=1, count=2]
                                    |
                                    v
                           [EndTurn]
                                    |
                                    | false
                                    v
                           [DoNothing]
```

### 4.4 Scripting avanzado (capa C#)

Los creadores avanzados pueden escribir `RuleNode` personalizados en C# heredando de `RuleActionNode` o `RuleConditionNode`, registrarlos en el `RuleNodeRegistry` y usarlos desde el editor visual sin recompilar el editor entero (hot-reload de assemblies si se configura).

---

## 6. Módulo 5: Sistema de Dados y Físicas Probabilísticas — Dice & Randomness Engine

### 5.1 Creador de dados personalizados

Un `DiceDefinition : Resource` define:

```csharp
public class DiceDefinition : Resource
{
    [Export] public int FaceCount { get; set; } = 6; // D4, D6, D8, D10, D12, D20, D100, N
    [Export] public List<DiceFace> Faces { get; set; } = new();
    [Export] public float Mass { get; set; } = 1.0f;
    [Export] public float Bounciness { get; set; } = 0.4f;
    [Export] public Color TintColor { get; set; } = Colors.White;
}

public class DiceFace : Resource
{
    [Export] public int Value { get; set; }
    [Export] public Texture2D Icon { get; set; }
    [Export] public Color FaceColor { get; set; }
    [Export] public string Text { get; set; }
}
```

Formas soportadas: D4, D6, D8, D10, D12, D20, D100 y dados de N caras personalizados. El modelo 3D se genera proceduralmente (`PieceKit`-style en C#) o se importa como `.glb` / `.obj`.

### 5.2 Lanzamiento físico y autoridad de azar

- **Físicas:** `DiceEntity : RigidBody3D` con `CollisionShape3D` según la geometría (tetraedro, cubo, etc.). Al lanzar, se aplica torque y velocidad inicial calculados.
- **Autoridad de azar:** El host (StateAuthority en Photon Fusion) calcula la semilla y la fuerza inicial del lanzamiento, la envía en el estado de red, y todos los clientes reproducen la misma simulación física determinista (Fusion soporta determinismo limitado; para garantizar consistencia, el host envía el `DiceResult` final como estado de red tras la lectura).
- **Detección de cara:** Raycast vertical desde arriba del dado detenido hacia el centro; la cara cuyo normal está más alineado con el vector hacia arriba se considera resultado. Alternativa: leer la rotación del dado y mapear al ángulo de cara más cercano.
- **Evento:** Se dispara `OnDiceRolled(diceResult, diceEntity)` en el `RuleEngine` (Módulo 4).

### 5.3 Bandeja de dados (`DiceTray`)

- Zona delimitada (`Area3D` o `CollisionShape3D`) donde se spawnan los dados al lanzar.
- Fricción alta y paredes para evitar que salgan del área.
- Opción de "lanzamiento rápido" sin física (resultado inmediato por red) para juegos de ritmo acelerado.

---

## 7. Módulo 6: Gestión de UI/HUD Personalizada para Creadores

### 6.1 Constructor de HUDs In-Game (`HUDEditor`)

- Editor de Canvas 2D (`Control` raíz) con arrastrar y soltar de elementos: `Label`, `ProgressBar`, `TextureRect`, `Button`, `Panel`, `GridContainer`.
- Anclaje y contenedores (`MarginContainer`, `VBoxContainer`, `HBoxContainer`, `AnchorLayout`) para responsividad.
- Cada elemento de UI puede vincularse a una variable del `RuleEngine` (Módulo 4): el texto de un `Label` se actualiza automáticamente cuando cambia `VariableGet("puntos_jugador_1")`.

### 6.2 Vinculación de datos UI ↔ Lógica

| Elemento UI | Variable vinculada | Actualización |
|-------------|-------------------|---------------|
| Marcador de puntos | `global.score_p1` | `OnVariableChanged` → `label.text = value.ToString()` |
| Barra de vida | `local.health_p1` | `progress_bar.value = health / max_health` |
| Contador de ronda | `global.round_number` | cambia al disparar `OnTurnStarted` |
| Cronómetro | `global.time_remaining` | decremento cada frame en `_Process` |
| Inventario | `local.hand_cards_p1` | se reconstruye al añadir/quitar cartas |

### 6.3 Pantallas de juego

- Pantalla principal (HUD durante la partida).
- Pantalla de menú principal del juego creado.
- Pantalla de fin de partida (ganador, puntuaciones, botón de revancha).
- Cada pantalla se guarda como `UIScreen : Resource` y se instancia dinámicamente.

---

## 8. Módulo 7: Workshop, Empaquetado y Distribución — Cloud Sync & ModSharing

### 7.1 Estructura del paquete de mod (`.gmod`)

Un mod es un archivo ZIP comprimido con la siguiente estructura interna:

```
mod.gmod/
├── manifest.json          (ModManifest)
├── scene.tscn             (escena principal del tablero)
├── resources/
│   ├── card_data/
│   ├── deck_definitions/
│   ├── dice_definitions/
│   ├── rule_graph.json    (motor de reglas visual)
│   └── ui_screens/
├── assets/
│   ├── models/
│   ├── textures/
│   └── sounds/
└── checksum.sha256
```

### 7.2 `ModManifest`

```json
{
  "mod_id": "guid-unique",
  "name": "Mi Juego de Mesa",
  "author": "usuario_123",
  "version": "1.0.0",
  "min_players": 2,
  "max_players": 4,
  "tags": ["familia", "estrategia", "cartas"],
  "checksum": "sha256-hex",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 7.3 Flujo de publicación y descarga

1. **Exportar:** El creador hace clic en "Publicar en Workshop"; el `ModBundleExporter` serializa escena, recursos, reglas y assets, calcula checksum y genera `.gmod`.
2. **Validación:** Se verifican checksums, tamaños máximos (ej. 100 MB) y ausencia de scripts peligrosos (sandbox de reglas).
3. **Subida:** Se sube al cloud de Workshop (API REST o integración con Photon Fusion + almacenamiento de archivos).
4. **Matchmaking:** Al crear una sala de Photon Fusion, el host incluye `ModId` en `SessionProperties`.
5. **Descarga transparente:** Al unirse, el `NetworkSceneManager` del cliente lee `SessionProperties["ModId"]`, descarga el `.gmod`, lo descomprime en una carpeta temporal y monta la escena en memoria antes de sincronizar el estado inicial.

### 7.4 Sincronización de estado de mod entre clientes

- El host envía el `ModId` y la versión en `SessionProperties`.
- Si el cliente no tiene el mod, lo descarga antes de unirse.
- Si tiene versión diferente, se solicita actualización o se rechaza la unión con mensaje de error descriptivo.

---

## 9. Módulo 8: Especificación Técnica de Clases en C# (Godot 4.7)

A continuación se detalla la arquitectura de clases base. Todas heredan de nodos/recursos de Godot y usan `[Export]` para exposición al Inspector.

### 9.1 `GameCreatorCore.cs`

Orquestador principal. Gestiona el ciclo de vida del editor (Build ↔ Playtest), el `RuleEngine`, la sesión de Photon Fusion y el cargador de mods.

```csharp
using Godot;
using Photon.Fusion;

public partial class GameCreatorCore : Node
{
    public static GameCreatorCore Instance { get; private set; }

    [Export] public NetworkRunner NetworkRunner { get; set; }
    [Export] public RuleEngine RuleEngine { get; set; }
    [Export] public ModBundleExporter ModExporter { get; set; }

    public EditorState CurrentState { get; private set; } = EditorState.Build;
    public string ActiveModId { get; private set; }

    public override void _Ready()
    {
        Instance = this;
        RuleEngine = GetNode<RuleEngine>("%RuleEngine");
        ModExporter = GetNode<ModBundleExporter>("%ModExporter");
    }

    public void EnterBuildMode()
    {
        CurrentState = EditorState.Build;
        GetTree().Paused = true;
        RuleEngine.Stop();
        // Mostrar gizmos, inspector, asset browser
        EmitSignal(SignalName.StateChanged, EditorState.Build);
    }

    public void EnterPlaytestMode()
    {
        CurrentState = EditorState.Playtest;
        GetTree().Paused = false;
        RuleEngine.Start();
        // Ocultar gizmos, activar input de juego
        EmitSignal(SignalName.StateChanged, EditorState.Playtest);
    }

    public async Task LoadModAsync(string modId)
    {
        ActiveModId = modId;
        var mod = await ModExporter.DownloadAndExtractAsync(modId);
        var scene = ResourceLoader.Load<PackedScene>(mod.ScenePath);
        var instance = scene.Instantiate();
        AddChild(instance);
    }

    [Signal] public delegate void StateChangedEventHandler(EditorState newState);
}

public enum EditorState { Build, Playtest }
```

### 9.2 `PropEntity.cs` (`Node3D`)

Componente base de cualquier objeto colocable. Soporta serialización a JSON y acoplamiento de `BehaviorComponent`s.

```csharp
using Godot;
using System.Collections.Generic;

public partial class PropEntity : Node3D
{
    [Export] public string EntityId { get; set; } = System.Guid.NewGuid().ToString();
    [Export] public string EntityName { get; set; } = "Nueva Entidad";
    [Export] public bool IsLocked { get; set; }
    [Export] public List<BehaviorComponent> Components { get; set; } = new();

    public T GetComponent<T>() where T : BehaviorComponent
    {
        foreach (var c in Components)
            if (c is T t) return t;
        return null;
    }

    public void AddComponent(BehaviorComponent component)
    {
        Components.Add(component);
        AddChild(component as Node);
    }

    public virtual Variant Serialize()
    {
        return new Dictionary<string, Variant>
        {
            { "entity_id", EntityId },
            { "name", EntityName },
            { "position", GlobalPosition },
            { "rotation", GlobalRotation },
            { "scale", GlobalScale },
            { "components", Components.ConvertAll(c => c.Serialize()) }
        };
    }

    public virtual void Deserialize(Variant data)
    {
        var dict = data.AsGodotDictionary();
        EntityId = dict["entity_id"].AsString();
        EntityName = dict["name"].AsString();
        GlobalPosition = dict["position"].AsVector3();
        GlobalRotation = dict["rotation"].AsQuaternion();
        GlobalScale = dict["scale"].AsVector3();
    }
}

public abstract class BehaviorComponent : RefCounted
{
    public abstract Variant Serialize();
    public abstract void Deserialize(Variant data);
}
```

### 9.3 `RuleEngine.cs`

Intérprete del grafo de nodos lógicos visuales.

```csharp
using Godot;
using System.Collections.Generic;

public partial class RuleEngine : Node
{
    [Export] public RuleGraph Graph { get; set; }
    private Dictionary<string, RuleNode> _nodesById = new();
    private Dictionary<string, Variant> _globalVariables = new();
    private Dictionary<int, Dictionary<string, Variant>> _playerVariables = new();

    public bool IsRunning { get; private set; }

    public void Start()
    {
        IsRunning = true;
        _nodesById.Clear();
        if (Graph != null)
            foreach (var node in Graph.Nodes)
                _nodesById[node.Guid] = node;
    }

    public void Stop() => IsRunning = false;

    public void TriggerEvent(string eventName, params Variant[] args)
    {
        if (!IsRunning) return;
        foreach (var node in _nodesById.Values)
        {
            if (node is RuleEventNode evt && evt.EventName == eventName)
                ExecuteNode(evt, args);
        }
    }

    private void ExecuteNode(RuleNode node, Variant[] inputArgs)
    {
        // Watchdog de tiempo de ejecución por nodo para evitar bucles
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        node.Execute(this, inputArgs);
        stopwatch.Stop();
        if (stopwatch.ElapsedMilliseconds > 50)
            GD.PrintErr($"RuleNode {node.Guid} excedió el límite de tiempo");
    }

    public Variant GetGlobalVariable(string name) =>
        _globalVariables.TryGetValue(name, out var v) ? v : Variant.Null;

    public void SetGlobalVariable(string name, Variant value) =>
        _globalVariables[name] = value;

    public Variant GetPlayerVariable(int playerId, string name)
    {
        if (!_playerVariables.ContainsKey(playerId))
            _playerVariables[playerId] = new();
        return _playerVariables[playerId].TryGetValue(name, out var v) ? v : Variant.Null;
    }

    public void SetPlayerVariable(int playerId, string name, Variant value)
    {
        if (!_playerVariables.ContainsKey(playerId))
            _playerVariables[playerId] = new();
        _playerVariables[playerId][name] = value;
    }
}

public abstract class RuleNode : Resource
{
    [Export] public string Guid { get; set; } = System.Guid.NewGuid().ToString();
    public abstract void Execute(RuleEngine engine, Variant[] inputArgs);
}

public abstract class RuleEventNode : RuleNode
{
    [Export] public string EventName { get; set; }
}

public abstract class RuleActionNode : RuleNode { }

public abstract class RuleConditionNode : RuleNode
{
    public abstract bool Evaluate(RuleEngine engine);
}
```

### 9.4 `ModManifest.cs`

Estructura de metadatos para exportación e importación de creaciones.

```csharp
using Godot;
using System;
using System.Collections.Generic;

[Serializable]
public class ModManifest : Resource
{
    [Export] public string ModId { get; set; } = Guid.NewGuid().ToString();
    [Export] public string Name { get; set; }
    [Export] public string Author { get; set; }
    [Export] public string Version { get; set; } = "1.0.0";
    [Export] public int MinPlayers { get; set; } = 2;
    [Export] public int MaxPlayers { get; set; } = 4;
    [Export] public List<string> Tags { get; set; } = new();
    [Export] public string Checksum { get; set; }
    [Export] public string CreatedAt { get; set; }
    [Export] public string UpdatedAt { get; set; }
    [Export] public string ScenePath { get; set; } = "res://scene.tscn";

    public string ComputeJson() => Json.Stringify(this); // helper conceptual
}
```

### 9.5 Clases adicionales recomendadas (esqueleto)

| Clase | Responsabilidad |
|-------|----------------|
| `NetworkSceneManager : NetworkBehaviour` | Gestiona carga/descarga de mods y sincronización de escena en Photon Fusion. |
| `DeckContainer : ContainerComponent` | Lógica de mazo, barajado, robo y descarte. |
| `DiceEntity : RigidBody3D` | Dado físico con detección de cara. |
| `CardEntity : PropEntity` | Carta con frente/dorso y datos de `CardData`. |
| `HUDEditor : Control` | Editor de pantallas UI. |
| `ModBundleExporter : Node` | Serializa/deserializa `.gmod` y gestiona checksums. |
| `AssetBrowser : Control` | Navegador de recursos local/nube. |
| `PropertyInspector : Control` | Inspector dinámico por selección. |

---

## 10. Apéndice: Formatos de Archivo, Esquemas de Datos y Flujo de Red

### 10.1 Formatos de archivo

| Extensión | Tipo | Uso |
|-----------|------|-----|
| `.gmod` | ZIP | Paquete de mod distribuible |
| `.tres` | Godot Resource | Recursos individuales (carta, dado, regla, UI) |
| `.tscn` | Godot Scene | Escenas de tablero y pantallas UI |
| `.json` | Intercambio | Grafos de reglas, manifestos, exportación de datos tabulares |
| `.csv` | Importación | Generación masiva de cartas |
| `.glb` / `.gltf` | Modelo 3D | Miniaturas, tableros, dados, fichas |

### 10.2 Flujo de red con Photon Fusion

1. Host crea sesión con `SessionProperties.Add("ModId", modId)` y `SessionProperties.Add("ModVersion", version)`.
2. Clientes se unen; `NetworkSceneManager` lee propiedades y descarga el mod si es necesario.
3. Todos los clientes instancian la misma escena de tablero.
4. El host tiene `StateAuthority` sobre `PropEntity`s redondeadas; los clientes envían `Input` (clics, arrastres, lanzamientos de dados) y el host aplica y publica el estado.
5. Los eventos del `RuleEngine` se disparan en el host y se replican mediante `OnChanged` de estado de red o RPC (`[Rpc]` en Fusion).

### 10.3 Consideraciones de Godot 4.7 y C#

- Usar `[Export]` en propiedades para edición en el Inspector.
- Evitar `static var` / `const preload` de `Resource` en `class_name` scripts para no fugar recursos al salir (lección del proyecto actual).
- No dejar `Tween`s vivos tras `_exit_tree()`.
- Usar `GetNode<T>("%nodo")` con nombres únicos para referencias seguras.
- Para tipado estricto, evitar `:=` al inferir de `Variant` (`dict.Get`, arrays mixtos, ternarios).

---

## Estado de entrega

Este documento es la especificación técnica de referencia para el desarrollo de **Game Creator Studio**. Puede usarse como base para:

1. Crear el esqueleto del proyecto Godot 4.7 en C#.
2. Implementar los 8 módulos de forma incremental, empezando por el Módulo 1 (workspace) y Módulo 2 (entidades/componentes).
3. Integrar Photon Fusion una vez el núcleo local funcione en Build/Playtest.
4. Publicar la versión alfa del Workshop con soporte para `.gmod`.

## Nota de implementación (GDScript vs C#)

El repositorio `thecharlie00/Prueba-Ia-G` es un proyecto **Godot 4.7 en GDScript** (no C#). Por tanto, las clases del Módulo 8 se han implementado en GDScript con el mismo diseño arquitectónico (singleton autoload `GameCreatorCore`, entidades `PropEntity` + `BehaviorComponent`s, `RuleEngine`, `ModBundleExporter`, etc.) y se registran como Autoload en `project.godot`. Los creadores avanzados pueden extender estas clases en GDScript; si se desea C# en el futuro, bastaría con crear los archivos `.cs` equivalentes heredando de los mismos nodos base de Godot.

El archivo queda en: `GAME_CREATOR_STUDIO_TECHNICAL_SPEC.md` (raíz del repositorio).