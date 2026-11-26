# El chat juega (Twitch)

El chat de Twitch de un streamer puede ocupar un asiento en todas las mesas con bot. En su turno,
los espectadores votan con `!1`, `!2`… entre las jugadas legales; si nadie vota, juega el bot.

| Mesa | Qué vota el chat |
|---|---|
| Parchís y Ludo | Qué ficha mover (tirar el dado lo hace solo) |
| Brisca | Qué carta jugar |
| Damas | Qué pieza y, si hay varios destinos, adónde (coordenadas del tablero) |
| Dominó | Qué ficha y, si encaja en los dos lados, en cuál; robar y pasar van solos |
| Isla de recursos | Qué hacer (camino, pueblo, ciudad, cambiar con la banca o terminar) y dónde construir; la colocación inicial, el ladrón y los descartes los resuelve el bot |

## Para el streamer

1. **Ajustes › Twitch › Conectar.** El juego abre twitch.tv/activate y enseña un código; se escribe
   allí y se acepta. La conexión queda guardada en este ordenador (`user://twitch.cfg`).
2. **Mesas con bot › «El chat de Twitch juega»** y elegir mesa. El chat ocupa el último asiento.
3. Para probar sin estar en directo: **Ajustes › Twitch › Chat simulado para probar**. Unos
   espectadores de mentira escriben y votan.

**En salas online**, cualquier streamer pulsa «Añadir mi chat de Twitch» en la sala de espera y su
chat ocupa un asiento libre (si luego llega una persona a ese asiento, el chat se cambia a otro).
Solo el ordenador de ese streamer lee su chat y abre la votación; la jugada ganadora viaja al
anfitrión como cualquier otra y él la valida. Si el streamer se va, un bot toma el asiento de su chat.
En las mesas de 2 jugadores solo cabe el chat del anfitrión («el anfitrión contra su chat»).

Solo se pide el permiso `user:read:chat`. Los mensajes borrados y los usuarios baneados o
expulsados por los moderadores pierden su voto.

## Para publicar el juego: Client ID de Twitch

Twitch identifica cada aplicación con un Client ID. Hay que registrar Tablerama una vez:

1. Entrar en https://dev.twitch.tv/console/apps con la cuenta del estudio y pulsar
   **Register Your Application**.
2. Nombre: `Tablerama`. OAuth Redirect URL: `http://localhost` (el flujo de dispositivo no lo usa,
   pero el formulario lo pide). Categoría: Game Integration.
3. **Client Type: Public.** Así no hay secreto que guardar dentro del juego.
4. Copiar el Client ID en `project.godot`, sección `[tablerama]`:

   ```
   twitch/client_id="el_client_id"
   ```

El Client ID no es secreto: puede ir en el repositorio y en las versiones publicadas. Sin él, el
botón Conectar queda desactivado y solo funciona el chat simulado.

## Piezas

| Pieza | Qué hace |
|---|---|
| `scripts/twitch/TwitchLink.gd` (autoload `Twitch`) | Flujo de dispositivo, EventSub por WebSocket (`channel.chat.message` y los borrados), reconexión y chat simulado. Emite `chat_message` y `moderation`. |
| `scripts/twitch/VoteRound.gd` | Una votación: un voto por persona (cuenta el último), empates para el primer voto, tiempo límite y moderación. |
| `scripts/twitch/ChatSeat.gd` | Asiento del chat en una mesa: abre la votación, enseña el panel y los números sobre las piezas, y devuelve la opción ganadora o -1. |
| `TableBots.chat_plays` | Lo marca el menú de mesas con bot; la vista sienta al chat en el último asiento. |

Test: `tests/twitch_chat.gd`. Diseño completo, con las entregas siguientes (resto de juegos, salas
online y bloques del creador), en el artefacto «El chat juega · Tablerama».

## Bloques «Twitch» del creador de juegos

Los juegos de la comunidad tienen una categoría **Twitch** (morada) en el editor de lógica, con
32 bloques. Cuando un juego usa alguno, al probar la mesa se conecta el chat y aparece el
**chat de prueba** (abajo a la izquierda): escribe como cualquier espectador, con su rol, y lanza
bits, subs, follows, raids, canjes, Hype Train o anuncios sin estar en directo.

| Tipo | Bloques |
|---|---|
| Eventos | Al escribir en el chat · Al usar un comando · Al cerrar una votación · Al animar con bits · Al suscribirse · Al seguir el canal · Al llegar una raid · Al canjear una recompensa · Hype Train · Al empezar un anuncio · Al conectarse el chat |
| Acciones | Abrir votación · Cerrar la votación ya · Mostrar el chat (6 estilos) · Ocultar el chat · Mostrar alerta · Barra de meta · Dar monedas · Asignar a un equipo · Dar ficha · Crear recompensa · Escribir en el chat · Si el espectador es… |
| Datos | Monedas de · Equipo de · Monedas del equipo · Ranking · Espectador al azar · Espectadores activos · Votos de una opción · Ficha de · ¿Hay chat? |

**Comandos.** Cada bloque «Al usar un comando» define uno: nombre, alias, argumento con tipo
(número con mínimo y máximo, opción de una lista, casilla tipo `B4`, `@jugador`), quién puede
usarlo y la espera por persona. Lo que no cumple se ignora. `!ayuda` enseña la lista sola.

**Estilos del chat en pantalla:** panel lateral, marquesina, pizarra, cartas que caen (las de
suscriptores, doradas), bocadillos sobre las fichas de cada espectador y solo reacciones. Todos
respetan los mensajes borrados por los moderadores y el filtro de palabras del streamer.

**Límites:** una votación a la vez y 6 por minuto; el juego escribe en el chat como mucho cada
3 s y el streamer puede apagarlo; las recompensas se borran al acabar la partida; los permisos
que faltan (bits, subs, canjes…) se avisan al probar.

Desde un bloque GDScript: `mesa.twitch_conectado()`, `mesa.monedas("ana")`,
`mesa.dar_monedas("ana", 5)`, `mesa.equipo("ana")`, `mesa.espectadores()`, `mesa.ranking(3)`.

## Entrega 4: control del directo y juego de ejemplo

**Plantilla «Dragón del chat»** (también en «Nuevo juego → Para streamers: el chat juega»):
un juego de ejemplo hecho solo con bloques. El chat se une con `!unirme rojo|azul` y recibe un
soldado con su nombre, `!ataque 1-6` suma monedas a su equipo (marcador siempre visible), los
bits llenan la barra «Despertar al dragón» y, al llenarse, el chat vota a quién ataca. Una raid
abre un sorteo con `!participo`; la ganadora gana 50 monedas y su mensaje sale destacado.

**Bloques nuevos (45 en total):** Al borrar un mensaje o banear · Al terminar un sorteo · Al
acabar la cuenta atrás · Activar o desactivar comando · Hacer un sorteo · Marcador de equipos ·
Destacar mensaje · Cuenta atrás visible · Responder al espectador · Completar o devolver canje ·
Límite por minuto · Enfriamiento · ¿Modo de prueba?. La barra de meta puede **sumar** y tiene
la salida **al llenarse**; equipo, etiqueta de ficha y monedas se pueden cablear.

**Opciones del directo** (Ajustes → Twitch → «Opciones del directo…»): tiempo de votación,
quién puede votar (todos, suscriptores, VIP, moderadores), palabras que nunca salen en pantalla,
ocultar nombres («Espectador»), si los juegos de la comunidad reciben bits/subs/raids/canjes y si
pueden escribir en el chat.

Los juegos que usan bloques de Twitch se exportan con la etiqueta `para-streamers`.

## Entrega 5: más espectáculo

**Modo de decisión** (Opciones del directo → «Cómo decide el chat»): *democracia* (gana la jugada
más votada al acabar el tiempo) o *anarquía* (el primer voto válido juega al momento). Solo afecta
al asiento del chat en los juegos de Tablerama; las votaciones de los juegos de la comunidad
siguen su propio tiempo.

**Bloques nuevos (52 en total):**
- *Abrir votación* tiene **peso del voto**: uno por persona, por bits (cada 100 bits dados en la
  partida = un voto más) o por monedas (cada 10 monedas = un voto más).
- **Apuestas:** *Abrir apuestas* (el chat escribe `!apuesta <opción> <monedas>`, una vez por
  persona, y se cobra al momento), *Al cerrar las apuestas* (da el bote) y *Pagar la apuesta*
  (reparte el bote entre los que acertaron según lo apostado; si nadie acierta, se devuelve).
- **Lluvia de emotes:** los emotes del chat caen por la pantalla con su imagen del CDN de
  Twitch (con caché y límite por minuto). El chat de prueba tiene un botón «Emotes» y reconoce
  Kappa, <3, LUL, PogChamp, HeyGuys y BibleThump.
- *Bocadillo sobre una pieza*, *Mostrar los comandos* (la tarjeta de `!ayuda`) y *Pausar
  recompensa* (puntos de canal).
