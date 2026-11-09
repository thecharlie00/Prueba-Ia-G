# RED-ONLINE · Multijugador con Photon Fusion (piloto: Isla de recursos)

Estado: implementación de piloto. El protocolo y el ciclo de vida de sala
funcionan sin App ID usando sala offline; la partida en red se prueba con la
mesa de la Isla (3 o 4 jugadores).

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
  ciclo de vida de salas, inventario de butacas y señales
  (`room_joined/left`, `player_joined/left`, `start_announced`,
  `room_info_received`). También es receptor de broadcast permanente, para que
  el handshake de sala funcione aunque el anfitrión ya esté en partida.
- **`NetTable`** (`scripts/net/NetTable.gd`): protocolo base. El **master
  client (anfitrión) es autoritativo**: valida, aplica y difunde; los clientes
  solo aplican lo recibido. RPCs: `req_action`, `rule_event`, `sync_request`,
  `sync_state`, `net_chat`. Sync con reintentos (10 × 2 s).
- **`IslandNetTable`** (`scripts/net/IslandNetTable.gd`): validación por fase
  (turno, descarte, víctimas, ofertas…) y replay del registro para sync.
- **`Lobby`** (`scripts/ui/Lobby.gd` + `scenes/Lobby.tscn`): nombre, crear sala
  (solo full edition), entrar por código, butacas, chat y «Empezar» (anfitrión).
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
- Dados remotos: el resultado aparece en el estado; la animación física de
  dados es local.
- Sin re-entrada de butacas durante la partida (late-join solo antes del inicio
  o reconexión por sync).
