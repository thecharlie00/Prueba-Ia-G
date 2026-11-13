# RED-ONLINE · Multijugador con Photon Fusion (piloto: Isla de recursos)

Estado: implementación de piloto. El protocolo y el ciclo de vida de sala
funcionan sin App ID usando sala offline; la partida en red se prueba con la
mesa de la Isla (2, 3 o 4 jugadores, con soporte de bots en butacas libres).

## Instalación del SDK

El proyecto usa el addon oficial **Photon Fusion para Godot** (Godot 4.6+). Es software
propietario de Exit Games, así que **no se versiona**: `addons/fusion/` está en
`.gitignore` y cada máquina lo instala a mano.

1. Descarga el SDK de Photon Fusion para Godot (cuenta de Photon → SDKs, o la Asset Store).
2. Copia la carpeta `fusion/` en `addons/` (debe quedar `addons/fusion/fusion.gdextension`).
3. Abre el proyecto en el editor una vez para que Godot registre la extensión.

Ningún script nombra el singleton `Fusion` directamente: todo pasa por
`scripts/net/FusionBridge.gd` (`FusionBridge.sdk()`, `available()`, `in_room()`,
`room_options()` y las constantes `STATUS_*` / `TARGET_*`). Sin el SDK, `sdk()` devuelve
`FusionStub`, un sustituto inerte con las mismas señales y métodos: el proyecto compila,
los tests pasan y el online muestra el aviso de SDK no instalado.

**Builds.** La CI no tiene el SDK, así que sus exportaciones son solo locales (bots y misma
pantalla), que es justo lo que lleva la demo. Las builds del juego completo con online se
exportan en una máquina con el SDK instalado. Si algún día se quieren en CI, el SDK se
descarga en el job desde un almacén privado (secreto del repositorio), nunca desde el repo.

**Historial.** Las versiones antiguas del repositorio todavía contienen el SDK. Antes de
anunciar el repositorio o hacerlo visible a terceros, conviene confirmar con Exit Games que
eso es aceptable o reescribir el historial (`git filter-repo --path addons/fusion --invert-paths`).

## Configuración (project.godot → `[net]`)

- `app_id`: App ID de la aplicación Photon. **Vacío = modo offline**: al entrar
  en online se crea una sala singleplayer (`create_singleplayer_room`) para
  probar el protocolo sin cuenta de Photon.
- `region`: región de Photon Cloud (p. ej. `eu`).
- `user`: nombre predeterminado del jugador.

## Arquitectura

- **`Net`** (autoload `scripts/net/NetManager.gd`): sesión, conexión a Photon,
  buscador de salas públicas (`room_listings`, `room_list_changed`,
  `LOBBY_PROP_KEYS`), validación de contraseñas con hash SHA-256 + salt,
  ciclo de vida de salas, inventario de butacas/bots/«Listo» y señales
  (`room_joined/left`, `player_joined/left`, `start_announced`,
  `room_info_received`). También es receptor de broadcast permanente, para que
  el handshake de sala funcione aunque el anfitrión ya esté en partida.
- **`NetTable`** (`scripts/net/NetTable.gd`): protocolo base. El **master
  client (anfitrión) es autoritativo**: valida, aplica y difunde; los clientes
  solo aplican lo recibido. RPCs: `req_action`, `rule_event`, `sync_request`,
  `sync_state`, `net_chat`. Sync con reintentos (10 × 2 s).
- **`IslandNetTable`**, **`LudoNetTable`**, **`ChessNetTable`**,
  **`CheckersNetTable`**, **`DominoNetTable`** y **`BriscaNetTable`**
  (`scripts/net/*NetTable.gd`): adaptadores autoritativos para las **12 mesas
  con reglas** del catálogo online:
  - **Isla de recursos** (2, 3 y 4 jugadores), con tirada física sincronizada.
  - **Parchís** (2 y 4 jugadores) y **Ludo** (2, 3 y 4 jugadores), con tirada
    física sincronizada y movimiento de fichas con fuerzas.
  - **Ajedrez** (2 jugadores: blancas vs negras, promoción, enroque, al paso y
    reclamación de tablas).
  - **Damas** (2 jugadores: blancas vs oscuras, capturas múltiples y coronación).
  - **Dominó** (2 jugadores: ocultación visual de los puntos de las fichas del
    rival y del pozo hasta que se juegan o acaba la ronda).
  - **Brisca** (2 jugadores: abanico propio siempre boca arriba por butaca y
    cartas del rival boca abajo).
- **`Lobby`** (`scripts/ui/Lobby.gd` + `scenes/Lobby.tscn`):
  - **Crear sala** (solo juego completo): modo 2/3/4 jugadores, título
    opcional, casilla «Sala pública» y contraseña opcional (hash SHA-256 + salt).
  - **Unirse por código**: entrada a salas públicas o privadas de 6 caracteres.
  - **Salas públicas disponibles**: lista en tiempo real vía `Fusion.get_room_list()` /
    `room_list_updated`, botón «Actualizar» con enfriamiento y filtros por
    texto (título, anfitrión o código), jugadores, hueco disponible y sin clave.
  - **Sala de espera**: butacas con estado «Listo» por invitado (`ReadyToggle`),
    bots configurables en huecos libres (`SeatBot<N>`), expulsión por el
    anfitrión (`KickSeat<N>`), chat en vivo y botón «Empezar partida» bloqueado
    hasta que todos los invitados estén listos.
- **`IslandView`** (online): `submit_change` envía al anfitrión; `apply_change`
  aplica cambios recibidos por el mismo camino que el replay del guardado
  (`IslandRules._apply_saved_event`), para que todos los clientes coincidan.

## Protocolo de acción

Las acciones usan el mismo diccionario que los eventos del guardado, con una
clave extra `seat` (butaca que actúa):

```text
{"type": "settlement", "id": vertex}   {"type": "city", "id": vertex}
{"type": "road", "id": edge}           {"type": "robber", "id": tile}
{"type": "roll", "a": x, "b": y}       {"type": "discard", "id": resource}
{"type": "steal", "id": victim}        {"type": "bank", "give": g, "take": t}
{"type": "buy"}                        {"type": "play", "id": card}
{"type": "plenty", "id": r}            {"type": "monopoly", "id": r}
{"type": "offer", "other": p, "give": [...], "take": [...]}
{"type": "respond", "player": p, "accept": bool}   {"type": "end"}
```

Flujo por turno:

1. Cliente local: `IslandView.submit_change(action, seat)`.
2. Anfitrión: `NetTable.submit` → `_allows` (fase, turno, butaca) →
   `apply_change` (reglas + efectos visuales) → `rule_event` a todos.
3. Clientes: `rule_event` → `apply_change` (reglas + efectos).
4. Entrada tardía / reconexión: `sync_request` → anfitrión responde con
   `export_record()` → cliente `from_record` + `_rebuild_loaded_board`.

## Desconexión

El anfitrión recibe `player_left` y marca esa butaca como bot
(`IslandView.set_bot(true, player_id - 1)`); el bot juega por el mismo camino
de submit con su butaca.

## Licencias

**La demo no incluye online.** Antes del lanzamiento nadie tiene el juego completo para
crear salas, y una demo que solo puede entrar a salas no tiene a quién encontrar; además,
así la demo no gasta el cupo gratuito de Photon (100 jugadores simultáneos). El modo
«Online» aparece en el selector como «En el juego completo» y el acceso «Salas online» del
menú se oculta. Tras el lanzamiento se puede reabrir: añadir `Lobby.tscn` a
`Edition.DEMO_SCENES`, y el Lobby ya limita la demo a **entrar** a salas (el botón «Crear
sala» está deshabilitado y «Empezar» comprueba `Edition.allows(scene)`).

## Limitaciones del piloto

- **Manos públicas**: la vista online muestra solo la butaca local
  (`_active_hand_player` = `Net.local_seat()`); privacidad de manos es fase
  futura.
- Chat solo en el Lobby (el de mesa `net_chat` está disponible para mesas).
- Dados remotos y de bots: se lanzan físicamente en todas las pantallas y, al
  detenerse, se ajustan a la cara exacta (`Dice3D.set_top_face`).
- Sin re-entrada de butacas durante la partida (late-join solo antes del inicio
  o reconexión por sync).
