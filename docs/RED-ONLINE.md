# RED-ONLINE · Multijugador con Photon Fusion (piloto: Isla de recursos)

Estado: implementación de piloto. El protocolo y el ciclo de vida de sala
funcionan sin App ID usando sala offline; la partida en red se prueba con la
mesa de la Isla (2, 3 o 4 jugadores, con soporte de bots en butacas libres).

## Instalación del SDK

El proyecto usa el addon oficial **Photon Fusion para Godot** (Godot 4.6+).
Se descarga de la Asset Store de Godot o de Photon y se copia en `addons/`.
El singleton `Fusion` solo existe si el addon está instalado; sin él, la pantalla
de online muestra un aviso y el juego local sigue funcionando.

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

La demo solo puede **entrar** a salas: el botón «Crear sala» está deshabilitado
y «Empezar» comprueba `Edition.allows(scene)`. Sin App ID, la sala offline no
tiene restricción (testing local).

## Limitaciones del piloto

- **Manos públicas**: la vista online muestra solo la butaca local
  (`_active_hand_player` = `Net.local_seat()`); privacidad de manos es fase
  futura.
- Chat solo en el Lobby (el de mesa `net_chat` está disponible para mesas).
- Dados remotos y de bots: se lanzan físicamente en todas las pantallas y, al
  detenerse, se ajustan a la cara exacta (`Dice3D.set_top_face`).
- Sin re-entrada de butacas durante la partida (late-join solo antes del inicio
  o reconexión por sync).
