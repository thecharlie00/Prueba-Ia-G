# Documento de Diseño de Juego (GDD): Dice on!!

**Estado:** propuesta de diseño y arquitectura; no es una descripción de funcionalidades ya implementadas.<br>
**Versión:** 1.0 · 2 de noviembre de 2026<br>
**Audiencia:** diseño de juego, ingeniería, arte, UX, producción, QA y publicación.<br>
**Motor de referencia:** Godot 4, GDScript para prototipado y herramientas; C# opcional para módulos que justifiquen su coste y sean compatibles con las plataformas de destino.

---

## 1. Resumen ejecutivo (Executive Summary)

### Ficha de producto

| Campo | Definición |
|---|---|
| **Título** | **Dice on!!** |
| **Género** | Simulador sandbox de juegos de mesa 3D, creador no-code y multijugador. |
| **Plataformas** | PC mediante Steam: Windows, macOS y Linux. Futuras aplicaciones para tablets iOS y Android, sujetas a validación de rendimiento, entrada táctil y condiciones de publicación. |
| **Público objetivo** | Jugadores casuales de mesa, grupos de amigos, creadores de contenido y diseñadores indie que quieren prototipar sin programar. |
| **Modelo** | Juego completo de pago único por usuario; sin suscripción ni pases gratuitos para invitados. |
| **Experiencia** | Una mesa compartida donde se puede jugar libremente, activar reglas asistidas o crear un juego a partir de imágenes y componentes. |
| **Motor** | Godot 4. La elección de plugins, versión concreta y lenguaje por módulo se valida antes de cada lanzamiento. |

### Propuesta única de venta (USP)

1. **Zero Frustration Physics.** Física legible y asistida: imantación contextual, apilado automático, altura de agarre adaptable y recuperación de objetos. Las ayudas son configurables y no sustituyen la decisión del jugador.
2. **Creador no-code integrado.** Un flujo guiado importa recursos y define zonas y reglas visuales sin exigir Lua ni conocimientos de programación. Los juegos usan una representación de datos versionada, no código arbitrario del usuario.
3. **Catálogo nativo.** Juegos clásicos basados en reglas de dominio público, con automatizaciones opcionales, explicaciones y modo libre. La situación jurídica de nombres, variantes, ilustraciones y recursos se revisará por territorio; «clásico» no significa que cualquier edición comercial pueda copiarse.

### Promesa al jugador

> Abrir una mesa, invitar a amigos y empezar a jugar o construir una primera versión de tu juego en pocos minutos, sin luchar contra la cámara ni las piezas.

### Objetivos y límites

- **Objetivo:** que el jugador pueda entender qué puede tocar, quién puede verlo y por qué una acción se ha aceptado o rechazado.
- **Objetivo:** mantener compatibles el juego manual, las ayudas físicas y las reglas opcionales sin obligar a activar automatizaciones.
- **Fuera de alcance inicial:** simulación competitiva certificada, IA para todos los juegos, un lenguaje de programación general, economía de compraventa entre usuarios y paridad inmediata entre PC y tablets.
- **Posicionamiento:** alternativa orientada a facilidad de uso y creación rápida, no promesa de compatibilidad total con contenido o scripts de otros simuladores.

---

## 2. Visión general del juego y pilares de diseño

### Concepto principal y bucles

Dice on!! combina una mesa 3D sandbox con automatizaciones inteligentes e importación rápida de componentes. La mesa es el espacio social compartido; el estado de juego, las reglas y la información privada se representan por separado de la apariencia física.

**Bucle de jugador:** elegir juego o mesa → crear o unirse a una sala → revisar las ayudas y reglas → interactuar y conversar → resolver turnos → guardar, reiniciar o compartir la partida.

**Bucle de creador:** importar imágenes → generar componentes → pintar zonas y configurar propiedades → conectar disparadores y acciones → probar con jugadores simulados → publicar una versión → iterar con base en comentarios.

### Pilares

| Pilar | Decisión de diseño | Señal de éxito propuesta |
|---|---|---|
| **Accesibilidad primero** | Cámara predecible, objetivos amplios, ayudas físicas ajustables, deshacer y avisos claros. Nunca depender solo del color. | En pruebas moderadas, al menos 90 % de participantes novatos mueve y suelta una pieza sin ayuda en su primer intento. |
| **Creación en 5 minutos** | Plantillas y valores seguros; generar un mazo a partir de una hoja 2D, una ficha simple y una zona sin scripting. | Medir tiempo hasta el primer prototipo jugable en una tarea acotada; objetivo de mediana ≤ 5 min con recursos preparados. No significa que un juego complejo pueda diseñarse en cinco minutos. |
| **Multijugador sin fricción** | Invitación Steam y código de sala cuando exista un servicio compatible; cada participante necesita su propia copia del juego. | Objetivo de al menos 95 % de intentos de unión exitosos en pruebas controladas con red compatible; registrar causa y tiempo de conexión. |

Los objetivos son hipótesis de producto, no resultados medidos. Se revisan con pruebas de usabilidad y telemetría agregada y consentida.

### Modos y decisiones

- **Libre:** todos los movimientos permitidos por los permisos de sala; no se infieren reglas. Ideal para prototipos y variantes.
- **Asistido:** imán, apilado y visualización de jugadas sugeridas; el anfitrión decide si se puede anular una recomendación.
- **Reglas activas:** la autoridad valida acciones y aplica la variante elegida. Los jugadores ven la razón de rechazo y el conjunto de reglas antes de empezar.
- **Seguridad y agencia:** ningún modo desplaza una pieza a otro lugar sin previsualización o indicación; los gestos accidentales deben ser reversibles cuando no revelen información secreta.

### Accesibilidad y ergonomía

Remapeo de teclado y ratón, opciones de tamaño de interfaz y texto, escala de UI, contraste alto, iconos y patrones además de color, etiquetas legibles, reducción de movimiento y alternativas a mantener pulsado (clic para agarrar / clic para soltar). Información crítica también por texto y señal de audio opcional. Las necesidades de lector de pantalla y navegación completa con teclado se validarán con especialistas y pruebas, no se presumen resueltas por la UI 3D. Incluir modo daltónico y ajustes de sensibilidad, imán, volumen y subtítulos para avisos sonoros. Localización inicial y lenguas exactas: decisión de producción.

---

## 3. Módulos de juegos preprogramados (catálogo inicial)

Cada módulo es un paquete de datos y reglas con versión, configuración inicial, componentes, ayuda, variantes y pruebas. El anfitrión selecciona **Libre**, **Asistido** o **Reglas activas** antes de iniciar; cambiar de modo durante la partida requiere acuerdo y queda en el registro. El catálogo utiliza implementaciones originales y recursos con licencia o autoría propia.

| Módulo | Preparación / participantes | Automatizaciones opcionales | Criterios y variantes que deben decidirse |
|---|---|---|---|
| **Ajedrez** | Tablero 8×8, 32 piezas, 2 jugadores. | Resaltar y validar movimientos legales; turno; captura, jaque, jaque mate y ahogado; enroque, captura al paso y promoción. Mostrar resultado y motivo. | Implementar reglas completas de la variante elegida, incluidas tablas por repetición, regla de 50 movimientos y material insuficiente; especificar reclamaciones y relojes. No permitir capturar el rey como fin de partida. |
| **Damas** | Tablero 8×8, 2 jugadores; disposición según variante. | Resaltar movimientos, capturas y coronación; validar turno y detectar victoria o ausencia de jugadas. | Acordar primero la variante: obligatoriedad y secuencias de captura, desplazamiento de damas y casillas utilizadas. No asumir que todas las reglas internacionales son equivalentes. |
| **Parchís / Ludo** | Tablero, dados y fichas por color, 2–4 jugadores según plantilla. | Conteo y ruta de casillas; turnos, salida, capturas y entrada a meta; elección de ficha cuando haya varias legales. | Son familias de variantes distintas. Documentar tiradas para salir, casillas seguras, bloqueos, rebotes, bonificaciones y número de dados para cada plantilla. |
| **Dominó** | Fichas con extremos numerados, pozo y manos privadas; 2–4 por configuración. | Snapping por borde compatible, orientación y continuidad de cadena; bloqueo de jugadas inválidas; robo o paso cuando corresponda. | Definir doble-seis u otro conjunto, apertura, puntuación y final por bloqueo. El host valida el valor y la posición, sin revelar la mano a otros. |
| **Baraja española / inglesa** | Mazos configurables, pilas de descarte y manos privadas. | Mezcla, corte, reparto equitativo, robo y ordenación; cartas visibles solo para titulares o cuando se revelen. | Son componentes genéricos, no reglas completas de todos los juegos. Especificar 40/48 cartas españolas, 52/54 inglesas y reglas de reparto por plantilla. |
| **Roles ocultos: Lobo / Licántropo** | Jugadores, roles y configuración elegida por el anfitrión. | Asignación secreta; fases de noche y día; pantallas opacas individuales, votaciones y avisos solo a destinatarios autorizados. | Definir roles, orden de resolución, empates y condiciones de victoria por variante. Pantalla opaca es presentación; el secreto también debe protegerse en red. No copiar personajes, texto ni arte protegidos de una edición comercial. |

**Contratos comunes:** las reglas presentan `acciones_disponibles`, `validar(comando, estado)` y `aplicar(comando, estado) → eventos`; no dependen de la posición visual exacta de los meshes. El registro visible se filtra por destinatario. Para cada variante se crean fixtures de inicio, jugadas legales e ilegales, final y restauración de partida.

---

## 4. El editor de juegos de mesa (Tabletop Builder «No-Code»)

### Experiencia de creación en tres pasos

#### 1. Wizard de importación de assets

1. El creador elige plantilla: cartas, tablero, fichas, dados, objeto decorativo o proyecto vacío.
2. Importa PNG/JPEG/WebP para imágenes; el asistente solicita tamaño físico, escala, orientación, pivote y derechos de uso. Muestra coste estimado y límites antes de confirmar.
3. **SpriteSheet de cartas:** indicar filas, columnas, margen, separación, reverso y orden; previsualizar cada recorte y corregir índices. Generar definiciones de carta y mazo con tamaño, grosor y colisionador simples; no duplicar innecesariamente la textura.
4. **Ficha extruida:** partir del contorno alfa 2D, simplificarlo con tolerancia ajustable, generar una malla con profundidad y un colisionador convexo simplificado. Si el contorno tiene huecos, es demasiado complejo o no puede triangularse, ofrecer una caja/cilindro aproximado y avisar; nunca generar colisiones no validadas automáticamente.
5. **Modelos glTF/GLB y OBJ:** glTF/GLB es la ruta prioritaria mediante las APIs de importación disponibles en Godot. OBJ requiere un importador validado o conversión previa a glTF: no asumir soporte de importación runtime nativo. Validar materiales, normales, tamaño, textura, número de polígonos y colisionadores. Rechazar archivos corruptos y referencias externas no permitidas.
6. Visualizar tamaño en mesa y probar agarre antes de crear el recurso. Permitir sustituir el archivo manteniendo el ID del componente cuando su estructura sea compatible.

La importación de usuario nunca ejecuta scripts, shaders o binarios incluidos en archivos. Se aplican límites de tamaño, dimensiones de textura, polígonos y tiempo de procesado; se cargan solo desde rutas permitidas y se almacenan hashes. Los valores exactos se decidirán por pruebas de plataforma. Importación local, sincronización de contenido y publicación son operaciones separadas con consentimiento explícito.

#### 2. Configuración de zonas

El editor ofrece pincel, rectángulo y grid ajustable en plano. Permite pintar, seleccionar y nombrar celdas, conectar rutas y definir orientación y puntos de snap. El inspector incluye:

- **Dropzone:** volúmenes, tipos admitidos, capacidad, prioridad, alineación, visibilidad y permisos de colocación.
- **Casilla:** coordenada lógica, vecinos, ocupación, dueño opcional y reglas de entrada/salida. El tablero visual no es la fuente de verdad de la casilla.
- **Hand:** propietario/rol, capacidad, orden, posición de visualización y permisos de revelado. Una mano 2D y su representación 3D pueden mostrar el mismo conjunto de IDs autorizados.
- **Otras zonas:** mazo, descarte, contador, zona de lanzamiento, inventario y área decorativa. Colores, patrones y etiquetas facilitan distinguirlas.

Las zonas superpuestas se resuelven por prioridad explícita y, en empate, por distancia y un ID estable; el editor avisa si el resultado puede ser ambiguo. Probar zonas incluye simulación de otro jugador y de permisos, sin exponer datos privados reales.

#### 3. Editor de lógica visual (Trigger System)

Flujo tipado **[Disparador] → [Condición] → [Acción]** en tarjetas o nodos conectables. El inspector describe cada puerto y ofrece ejemplos; no se genera ni ejecuta GDScript/Lua arbitrario. Se puede probar un evento paso a paso con historial, mensajes de validación y deshacer cambios de edición.

| Tipo | Ejemplos | Datos disponibles / restricciones |
|---|---|---|
| Disparador | Dado resuelto, clic en zona, pieza colocada, turno iniciado, botón pulsado. | Identidad del actor, objeto, zona, turno y resultado autorizado. El evento se origina en la autoridad. |
| Condición | Es turno del actor, tipo de pieza, dueño, valor de dado, capacidad o fase. | Lectura sobre estado autorizado; debe ser pura y no filtrar datos privados en mensajes. |
| Acción | Mover por ruta, robar, cambiar contador, revelar, cambiar turno, emitir aviso. | El servidor valida permisos y precondiciones y aplica cambios atómicos; los avisos se filtran por destinatario. |

**Ejemplo 1 — Dado y movimiento**

```text
Disparador: dado_resuelto(dado_id, valor, jugador)
→ Condición: fase == "movimiento" Y jugador == jugador_activo
→ Acción: solicitar_elección(ficha_del_jugador)
→ Acción: mover_por_ruta(ficha_elegida, valor)
```

Si no hay destino legal o hay una bifurcación, mostrar alternativas o mensaje según las reglas de la variante; no mover una ficha arbitraria. El valor se acepta después de la resolución autoritativa, no del número comunicado por un cliente.

**Ejemplo 2 — Robar al pulsar una zona**

```text
Disparador: clic_zona("Mazo", jugador)
→ Condición: jugador == jugador_activo Y mazo.cantidad > 0
→ Acción: transferir_carta(mazo, mano_privada[jugador], 1)
```

La transferencia y el decremento se ejecutan como una transacción. El jugador recibe la identidad de la carta; los demás reciben únicamente la nueva cantidad y, si procede, una carta genérica.

**Seguridad y límites:** catálogo de acciones permitido, esquema tipado y versionado, referencias por ID y validación antes de publicar. Detectar ciclos y aplicar presupuestos por evento (número de pasos, profundidad y tiempo); suspender la regla y mostrar diagnóstico al agotarlos. Los cambios encadenados se ordenan de forma estable y se agrupan en transacciones; las reglas no realizan llamadas de red, acceso a archivos ni ejecución de código. El anfitrión autoritativo registra errores y evita que una regla rota bloquee la sala.

### Información oculta

La privacidad se define en el modelo de datos, no solo con una malla que tapa la vista. Manos privadas 2D/3D, pantallas virtuales personalizables y cartas boca abajo tienen política de visibilidad por jugador o rol. El cliente no autorizado recibe solo identificadores públicos y metadatos mínimos; nunca recibe anversos, roles, semillas futuras ni eventos secretos. Al revelar, la autoridad envía el dato a los destinatarios adecuados. El creador dispone de vista previa por rol y advertencias cuando una regla o un recurso pueda revelar información.

**Límite de confianza:** un anfitrión que ejecuta el servidor local controla el proceso y potencialmente puede inspeccionar secretos. Si se requiere ocultarlos también al anfitrión, hará falta un servidor dedicado confiable u otra arquitectura; no se promete con host local.

### Formato y ciclo de vida del contenido

Proyecto con manifiesto versionado, ID estable, metadatos, licencias, lista de assets con hashes, definiciones de piezas, zonas, reglas y configuración inicial. Usar un formato de datos inspeccionable, por ejemplo JSON, junto a binarios de assets; validar esquema y referencias antes de cargar. Versionar tanto el esquema como cada paquete; migraciones explícitas y reproducibles, respaldo antes de migrar y error recuperable si una versión es incompatible. Exportación, importación, guardado, previsualización y publicación deben ser reversibles. No incluir credenciales en paquetes o guardados.

---

## 5. Mecánicas de juego y controles (UX/UI)

### Controles de escritorio

| Entrada predeterminada | Acción | Contexto / respuesta |
|---|---|---|
| Clic izquierdo | Seleccionar / arrastrar; soltar para colocar. | Resaltar objeto o zona; alternativa de clic para agarrar y clic para soltar. |
| Clic derecho + arrastrar | Orbitar cámara. | Foco visible opcional; elevación y distancia acotadas. |
| Mayús + clic derecho | Desplazar cámara (pan). | Desplazamiento paralelo a la mesa; clic central como alternativa. |
| Rueda | Zoom suave. | Distancia y altura mínimas; prevención de colisiones de cámara como mejora prevista. |
| F | Voltear la pieza seleccionada. | Solo si el tipo y permisos lo permiten. |
| R | Lanzar dado o mezclar mazo seleccionado. | Acción contextual; el host decide resultado o estado. |
| E / Q | Rotar ±45° alrededor del eje apropiado. | Previsualizar y ajustar según restricciones de zona. |
| G | Agrupar / desagrupar selección compatible. | Mostrar límite y composición; deshabilitar si viola permisos o reglas. |
| Escape | Cancelar agarre, selección o modal según prioridad. | Volver a estado válido y comunicarlo. |

Atajos remapeables y visibles en menús; evitar colisiones con chat y campos de texto. La pulsación no provoca una acción de mesa mientras un control de texto tenga el foco. Para tablets se diseñarán gestos específicos —arrastre de un dedo, órbita/pan/zoom multitáctil y botones accesibles— mediante prototipos; no se presupone equivalencia inmediata con PC.

### Física asistida: Zero Frustration Physics

1. **Agarre:** comprobar permisos y tomar un bloqueo temporal; mostrar propietario del bloqueo. Mantener el offset del clic y elevar gradualmente el objeto a una altura suficiente para su tamaño y la superficie local, con un máximo configurable. No atravesar la mesa intencionalmente.
2. **Previsualización:** calcular zonas candidatas compatibles por tipo, permisos, ocupación, proximidad y reglas; mostrar silueta y orientación antes de soltar.
3. **Snap:** seleccionar candidato usando prioridad de zona, distancia, orientación y desempate estable. Umbrales de entrada/salida con histéresis evitan vibración. Si la zona queda ocupada o la autoridad rechaza, recuperar la última posición válida e informar al jugador.
4. **Apilado:** agrupar únicamente objetos compatibles; calcular altura a partir de dimensiones y límite de pila. Previsualizar orden, permitir separar y bloquear pilas imposibles. Las cartas privadas no se agregan a grupos públicos por accidente.
5. **Liberación:** aplicar la colocación validada por el servidor o devolver al estado válido; el modo libre conserva el comportamiento físico con límites de velocidad. La asistencia no garantiza colisión perfecta: usar CCD, límites de velocidad, barridos cuando proceda y pruebas contra geometrías extremas.
6. **Recuperación:** si un objeto cae fuera del área segura o entra en un estado imposible, ofrecer restauración a su última ubicación válida. La recuperación automática debe registrarse y poder desactivarse donde sea seguro.
7. **Marcadores 3D:** contadores y diales accesibles desde la mesa y mediante controles 2D; cambio manual o por regla, con validación y registro.

La intensidad de magnetismo, elevación, ayudas visuales y apilado es configurable por sala y, cuando no afecte a las reglas, por jugador. Existe una opción de física libre sin snap. Rechazos y recuperación se expresan con texto/icono, no solo color o sonido.

### Estados y resolución de conflictos

`idle → hover → solicitud_de_agarre → agarrado → previsualización → solicitud_de_colocación → confirmado / rechazado → idle`. Si otro jugador ya tiene el objeto, mostrar quién lo tiene; si el bloqueo expira o se pierde conexión, liberar y restaurar en servidor. El cliente puede mostrar respuesta inmediata predictiva, pero no confirmar una jugada hasta recibir respuesta. Las acciones simultáneas se ordenan por la autoridad; el usuario ve un motivo comprensible si pierde la carrera.

---

## 6. Arquitectura técnica en Godot 4

### Objetivos y separación de responsabilidades

- **Estado lógico:** objetos, zonas, turnos, reglas y permisos, independiente del render y de los cuerpos físicos. IDs estables, no rutas de nodos, para red y persistencia.
- **Simulación:** servidor autoritativo decide transiciones, dados, barajado y colocaciones. Representación física para interacción y animación, no fuente exclusiva de verdad de una regla.
- **Presentación:** meshes, UI y animaciones suscritas a eventos autorizados; interpolación de snapshots para otros jugadores.
- **Datos de juego:** recursos y manifiestos versionados; el motor de reglas no conoce escenas particulares de ajedrez o dominó.
- **Servicios:** interfaces de transporte, identidad, lobby, almacenamiento y distribución de contenido con implementaciones sustituibles. Composición explícita; evitar convertir toda la lógica en autoloads globales.

### Árbol de proyecto propuesto

```text
App (Node)
├── Services (Node)
│   ├── PlatformService             # identidad, invitaciones y capacidades
│   ├── NetworkService              # conexión, transporte y sesión
│   ├── SaveService                 # persistencia versionada
│   ├── ContentService              # importación, manifiestos y caché
│   └── SettingsService             # accesibilidad, controles y preferencias
├── Main (Node3D)
│   ├── Environment
│   │   ├── WorldEnvironment
│   │   ├── DirectionalLight3D
│   │   ├── Table (StaticBody3D → MeshInstance3D + CollisionShape3D)
│   │   └── Floor (StaticBody3D)
│   ├── CameraRig (Node3D → Camera3D)
│   ├── Managers (Node)
│   │   ├── SessionManager          # ciclo y reconexión
│   │   ├── GameStateManager        # estado autoritativo, IDs y transacciones
│   │   ├── TurnManager             # turno / fases
│   │   ├── RulesEngine             # validación y ejecución no-code
│   │   ├── InteractionManager      # selección, locks, intención de agarre
│   │   ├── SnapManager             # candidatos y previsualización
│   │   └── VisibilityManager       # proyección de estado por destinatario
│   ├── Zones (Node3D)
│   │   ├── BoardZones / DropZones
│   │   └── HandZones               # representación; secreto en modelo filtrado
│   ├── SpawnedObjects (Node3D)
│   │   └── TableObject (RigidBody3D → Visual + CollisionShape3D)
│   │       └── Dice / Card / Deck / Token como escenas especializadas
│   └── HUD (CanvasLayer)
│       ├── TurnBar / UndoButton
│       ├── PrivateHand2D
│       ├── ChatAndEventLog
│       └── ContextActions
└── EditorUI (Control; cargado en modo edición)
    ├── AssetGallery / ImportWizard
    ├── ZoneTools / VisualLogicGraph
    └── PropertiesInspector / TestControls
```

Es una arquitectura objetivo, no la estructura actual del repositorio. Los managers pueden ser nodos o servicios de dominio probables según pruebas; `App` puede sustituirse por una escena raíz equivalente. Mantener escenas de pieza y visualización intercambiables mediante composición o herencia limitada.

### Modelo de datos y reglas

- **GameDefinition:** ID y versión del juego, componentes, zonas, grafo de reglas, reglas de visibilidad y valores iniciales.
- **SessionState:** participantes y roles, turno/fase, objetos y sus ubicaciones lógicas, pilas, contadores, permisos, versión/sequence y estado privado por destinatario.
- **ObjectState:** ID, tipo, propietario, zona, orientación lógica, datos públicos y referencias a datos privados; la transformación visual puede interpolarse y no reemplaza la ubicación lógica.
- **Command:** ID de solicitud, actor autenticado, tipo, versión esperada del estado y parámetros limitados. **Event:** cambio aceptado, secuencia y visibilidad. Identificadores y permisos se verifican del lado servidor, nunca se confía en el actor declarado en un payload.
- **Persistencia:** snapshot de estado más versión y, si es útil, log de eventos. La información privada se guarda únicamente en un almacenamiento de servidor apropiado; las exportaciones y los logs de cliente no deben contener secretos ajenos.

### Física y capas

En Godot 4, separar al menos capas **Mesa/entorno**, **Piezas**, **Zonas** y **Raycast de interacción**, configurando masks por necesidad. Las zonas suelen ser `Area3D`, no paredes físicas; el raycast debe ver obstáculos para no seleccionar a través de la mesa. Mantener la detección y aplicación de fuerzas en el ciclo de física, sin escalar de forma no uniforme los cuerpos. Activar CCD donde sea útil, limitar fuerza y velocidad; para snap validar destino con consulta espacial. Un `PhysicsMaterial` controla fricción y rebote; las reglas de tablero no dependen de diferencias de simulación entre equipos.

### Red y multijugador

**Topología:** cliente-servidor con host local autoritativo como primera implementación; servidor dedicado como evolución para mayor disponibilidad y para secretos frente al anfitrión. Un host local puede quedar limitado por NAT, conectividad y confianza; presentar errores y alternativas explícitas, nunca prometer conexión directa universal.

**Transportes y salas:** abstracción sobre `MultiplayerPeer`. Un plugin o integración compatible con Steam puede proporcionar Steam Lobbies, invitaciones y Steam Networking Sockets; estas funciones no vienen listas para usar solo por activar Godot. La elección de SDK/plugin, compatibilidad, licencias y pruebas en las tres plataformas de PC son hitos. Un **código de sala directo** necesita un mecanismo de resolución/descubrimiento, autenticación y transporte (p. ej., servicio de rendezvous o capacidad equivalente del proveedor); el código no es una dirección mágica ni garantiza atravesar NAT. No exponer IP, secretos o tokens en el código. Tablets requerirán un backend/identidad/transportes compatibles propios o de un proveedor, con interoperabilidad por validar; no asumir disponibilidad de Steam en iOS/Android.

**`MultiplayerSynchronizer` y RPC:** usar `MultiplayerSynchronizer` únicamente para propiedades públicas apropiadas y entidades con autoridad definida; su visibilidad por peer y ciclo de vida deben configurarse y probarse. No usar un sincronizador global que replique roles o cartas ocultas. Usar RPCs para comandos discretos y respuestas/eventos filtrados; para movimientos frecuentes, enviar actualizaciones acotadas y prescindibles por canal no fiable cuando el transporte lo permita. Acciones críticas (agarre, soltar, robar, tirar, turno) usan mensajes fiables, ID de solicitud e idempotencia.

**Flujo de interacción:**

1. Cliente solicita agarre con ID de objeto y secuencia conocida. Servidor comprueba identidad, permisos, turno, distancia, estado y que no exista bloqueo.
2. Servidor concede bloqueo con expiración; difunde solo datos públicos. El cliente envía objetivos limitados de arrastre; servidor valida frecuencia, distancia y límites y simula o resuelve colocación.
3. Cliente solicita soltar. Servidor valida destino y aplica la transición de forma atómica; difunde evento autorizado y snapshot. Conflictos o estado obsoleto devuelven rechazo y estado válido.
4. En desconexión o timeout se libera el bloqueo y se recupera la pieza. Al reconectar, autenticación y snapshot filtrado reconstruyen el estado; comandos antiguos con ID repetido no se reaplican.

**Estado continuo:** el servidor envía snapshots públicos con secuencia y timestamp; clientes interpolan y pueden predecir su propia interacción, reconciliando contra la autoridad. Evitar simular rigid bodies independientes y esperar determinismo entre dispositivos. Como hipótesis inicial, evaluar física a 60 Hz y snapshots de 10–20 Hz con envío por relevancia; ajustar tras perfilado, pruebas de pérdida de paquetes y de dispositivos, no considerar estos valores compromisos cerrados.

**Dados y barajado:** el servidor es la fuente de aleatoriedad y del estado; al resolver, emite únicamente el resultado y las consecuencias autorizadas. La animación física debe corresponder al resultado, no revelar resultados futuros ni determinar el resultado por un cliente no confiable. Para juego social bastan pruebas y aleatoriedad de calidad apropiada; equidad criptográfica verificable sería otra característica y requiere diseño adicional.

**Amenazas:** validar tamaños y frecuencia de mensajes, permisos, IDs y transiciones; limitar spam, cargas y recursos; no aceptar recursos ejecutables. Filtrar la información antes de serializar por destinatario, incluidos logs, snapshots y reconexión. El cliente puede ser modificado y el host local puede inspeccionar el servidor: no se promete antitrampas absoluto. Para una red pública, cifrado, autenticación, retención de datos y protección de menores requieren revisión de seguridad y privacidad antes de lanzamiento.

### Rendimiento, calidad y pruebas

- Presupuestos iniciales a validar: objetivo 60 FPS en PC de referencia y una latencia de respuesta visual al input inferior a 100 ms en condiciones locales; definir especificaciones de hardware y percentiles con telemetría de pruebas. Perfiles separados para tablets.
- Pruebas unitarias de reglas por variante, importador, esquema, migraciones, permisos y eventos. Pruebas de integración de locks, reconexión, privacidad, orden de eventos y aplicación idempotente.
- Pruebas de red con latencia, jitter, pérdida, duplicación y desconexiones; confirmar que ningún paquete, snapshot o log de un cliente no autorizado contiene cartas o roles secretos.
- Pruebas físicas de colisiones, snap, recuperación, pilas y objetos con tamaños extremos; pruebas visuales y de accesibilidad con cámara, ratón, teclado y futuros gestos.
- Mantener registros estructurados sin secretos y métricas agregadas opt-in. Definir consentimiento, retención y política de privacidad antes de cualquier recogida de datos.

### Relación con el prototipo existente

El repositorio actual contiene un menú principal, un sistema de pausa y escenas locales con mesa, cámara, agarre por fuerza, cuadrícula de snap opcional con barrido, dados, fichas físicas, cartas numeradas, mazo mezclable, ajedrez y damas locales asistidos, ajedrez físico libre y con reglas y piezas modeladas, mesas manuales de barajas inglesa y española, una mesa de damas física libre y un modo de damas físicas con reglas, mesas de dominó doble seis físico libre y con reglas locales para dos jugadores, HUD y documentación. También hay una isla de recursos local para tres o cuatro personas, inspirada en las reglas principales de Catán, con puertos, cartas de desarrollo, comercio, ruta y ejército, guardado lógico, piezas y dados físicos. Las cartas se gestionan por interfaz y las manos son visibles; faltan privacidad, red, IA, expansiones y QA visual. No es el juego oficial. El dominó con reglas reparte 7/7, valida extremos, robo y pase, y resuelve por mano vacía o bloqueo; las manos y el pozo son visibles, y la cadena se organiza con fuerzas y torque, con texto como referencia del estado; tiene guardado local por replay, pero no red ni privacidad. En damas físicas con reglas, las jugadas se validan al soltar y los cuerpos vuelven a sus destinos mediante fuerzas; este modo comparte el guardado lógico con la vista simple de damas, sin guardar posiciones físicas exactas. Las damas usan una variante inglesa adaptada con blancas primero; no incluyen tablas ni juego en red. El ajedrez físico con reglas valida al soltar, maneja enroque, captura al paso y promoción, y comparte el guardado lógico con su vista simple. Aún requiere más pruebas y no tiene reloj ni juego en red. La mesa libre tiene un guardado local versionado de sus cuerpos, movimiento, cartas, mazo e imán; no guarda la cámara y ahora reemplaza los archivos de guardado mediante temporal y renombrado atómico. No implementa todavía el sistema general de reglas aquí propuesto, el editor no-code, snap avanzado, Steam, red autoritativa ni privacidad. Los controles actuales pueden diferir de los controles objetivo de este GDD. Reutilizar y refactorizar solo tras validar las escenas y scripts en Godot; las métricas y objetivos de este documento no son funcionalidades ya verificadas.

---

## 7. Interfaz de usuario (UI) y experiencia (UX)

### HUD de partida

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Juego · Sala        TURNO: Ana      Fase: Movimiento    Deshacer ⚙ │
├──────────────────────────────────────────────────────┬──────────────┤
│                                                      │ Chat / Log   │
│                      Mesa 3D                         │              │
│             objeto seleccionado + acciones           │ Ana lanzó 4  │
│                                                      │ Luis: ...    │
├──────────────────────────────────────────────────────┴──────────────┤
│ Mano privada 2D: [carta] [carta] [carta]      Ordenar · Ocultar    │
└─────────────────────────────────────────────────────────────────────┘
```

- **Barra superior:** nombre de partida, jugadores/conexión, turno, fase, estado de reglas, menú de accesibilidad y deshacer cuando sea posible. Si está deshabilitado, explicar por qué.
- **Mano inferior:** vista 2D privada solo con datos autorizados, selección múltiple, orden y acciones contextuales. La ocultación visual puede servir ante espectadores locales, pero no garantiza privacidad física ante alguien que mire la pantalla.
- **Panel lateral:** pestañas de chat y log, minimizable, con marcas temporales, filtros de eventos y notificaciones. El log público nunca revela manos, roles ni resultados secretos; los eventos privados son solo para sus destinatarios.
- **Mesa:** contorno y etiqueta de hover, silueta de snap, identificador de bloqueo de otro jugador, menú contextual y señal de acción confirmada/rechazada. Ofrecer estado textual equivalente.
- **Onboarding:** tutorial corto de cámara/agarre, opción de saltarlo, ayudas contextuales y referencias de controles remapeados. Errores incluyen acción correctiva y no bloquean toda la interfaz.

### Deshacer y seguridad de la información

En modo libre, deshacer acciones propias según política de sala; en reglas activas, solo transacciones reversibles que el servidor pueda validar. Una acción que ha revelado información, mostrado una carta, consumido aleatoriedad o afectado a otro jugador **no puede deshacerse sin más**: deshabilitarla o solicitar una política/acuerdo específico, dejando constancia. Guardar el estado anterior no permite borrar conocimiento ya adquirido. El log y la UI explican el motivo.

### UI del editor

- **Galería:** búsqueda, categorías, previsualizaciones y estado de licencia/importación; arrastrar a mesa o insertar mediante teclado.
- **Inspector:** dimensiones, masa, fricción, snap, propiedad, visibilidad, zonas y etiquetas de reglas. Campos tipados, límites y unidades; valores avanzados progresivamente revelados.
- **Herramientas de zona:** pincel/grid con tamaño y modo de selección, mapa de solapamientos y conexiones de ruta.
- **Grafo de lógica:** biblioteca de nodos, conexiones tipadas, errores localizados, vista paso a paso, búsqueda y alternativas accesibles al arrastre.
- **Modo prueba:** cambiar rol simulado, reiniciar, reproducir eventos, revisar permisos y volver a editar sin publicar. Separar proyecto editable de sesión de prueba para evitar modificar contenido publicado involuntariamente.
- **Publicación:** checklist de título, licencia, validación, tamaño y descripción; vista de lo que otros recibirán, versión y posibilidad de retirar contenido.

---

## 8. Monetización y plan de desarrollo

### Modelo de negocio

- **Pago único:** cada jugador compra una copia completa que permite jugar, alojar, crear y usar el catálogo incluido. No hay suscripción, pases de invitado, microtransacciones ni funciones básicas bloqueadas detrás de pagos adicionales. Precio y territorios pendientes de investigación.
- **Contenido comunitario:** política de licencias, moderación y retirada antes de publicar; no asumir que todas las imágenes compartidas son legales. La distribución comunitaria no cambia el modelo de pago único.

### Roadmap propuesto y puertas de salida

Las fases se definen por resultados y dependencias; fechas, equipo y financiación están pendientes. No se promete una fecha ni que todas las funciones sean compatibles entre plataformas desde el primer día.

| Fase | Alcance | Criterios de salida propuestos | Dependencias / riesgos |
|---|---|---|---|
| **Prototipo Alpha: físicas + ajedrez** | Mesa y cámara, interacción básica con recuperación, prueba de snap y tablero de ajedrez; motor de reglas y validación de movimientos, modo libre; primer host autoritativo de prueba. | Una partida de ajedrez de la variante definida llega a su fin con turnos y jugadas legales validados; pruebas de enroque, al paso, promoción, jaque y finales; usabilidad inicial y pruebas de desconexión. | Complejidad de reglas y determinación de autoridad; no confundir con certificación competitiva. |
| **Beta: editor + snap** | Wizard para imágenes, piezas y mazos; zonas, lógica visual acotada, manos filtradas; snap/apilado y accesibilidad; multijugador de prueba. | Crear y probar una mesa acotada sin código; validación de paquetes; pruebas de permisos, bucles, reconexión y datos privados; objetivos de usabilidad medidos y bloqueos críticos resueltos. | Seguridad de importaciones, límites de contenido, profundidad del editor y coste de probar privacidad. |
| **Early Access: Steam Workshop + 5 juegos** | Integración Steam y distribución comunitaria; cinco módulos iniciales: ajedrez/damas como familia, parchís/ludo como familia, dominó, cartas y roles ocultos. | Instalación y actualización de contenido, controles de moderación, variantes documentadas, pruebas de integridad y seguridad; los cinco módulos pasan suites de reglas y usabilidad; revisión de compatibilidad por sistema operativo. | SDK/plugin Steam, políticas de Workshop, moderación, validación legal de recursos y variantes. La cuenta de cinco agrupa familias; cada variante publicada necesita su propia prueba. |
| **Posterior: tablets y expansión** | Diseño táctil, optimización, distribución e identidad compatibles; nuevos módulos y mejoras solicitadas. | Pruebas en dispositivos reales, accesibilidad táctil, memoria y batería aceptables; compatibilidad de salas y política de compra definidas. | Rendimiento móvil, tiendas, plugins, privacidad y posible transporte diferente. |

### Riesgos prioritarios y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Se filtra información oculta. | Alto: rompe la confianza y las reglas. | Filtrado servidor por destinatario, auditoría de tráfico/logs y pruebas de reconexión; distinguir host local de servidor confiable. |
| Contenido malicioso o con derechos ajenos. | Alto: seguridad y exposición legal. | Sin ejecución de código, validación y límites de archivos, licencias explícitas, reporte y retirada, moderación. |
| Física impredecible o latencia arruina turnos. | Alto: frustración y pérdida de estado. | Estado lógico autoritativo, snap previsualizado, límites y recuperación; prueba con latencia y bajo FPS. |
| Editor demasiado complejo para nuevos creadores. | Alto para la propuesta no-code. | Plantillas, progresión de complejidad, pruebas de cinco minutos, mensajes accionables. |
| Dependencia de Steam / conectividad NAT. | Alto para invitaciones y alcance. | Abstraer servicios, hacer spike de plataforma temprano y presentar alternativa de conexión cuando exista; no prometer código universal. |
| Coste de mantenimiento de variantes y plataformas. | Medio/alto. | Alcance por variante, suites automatizadas, matrizes de soporte y lanzamiento escalonado. |

### Decisiones abiertas antes de producción

1. Variante exacta y condiciones de victoria para cada módulo, y qué constituye una regla «completa» en lanzamiento.
2. Plugin/SDK Steam, transporte y servicio de códigos; licencias por jugador, soporte de servidores dedicados y modelo de confianza.
3. Presupuestos medidos de plataforma, cantidad máxima de participantes, objetos y tamaño de contenido.
4. Esquema final de permisos y moderación, modelo de privacidad y requisitos legales por territorio.
5. Profundidad inicial del grafo de lógica, mecanismos de accesibilidad y lenguas de lanzamiento.
6. Tratamiento de la información privada y de los guardados al reconectar, cambiar de host o terminar una sala.
