# La habitación · menú principal jugable

Desde la 0.2, Tablerama arranca en **la habitación**: la sala de juegos del diorama, por la
que se anda con un peón de arcilla. Cada mueble es una opción del menú. Es la fase 1 de la
propuesta «La habitación y el salón de salas»; el salón (salas online como mesas) llega con
el transporte de Steam.

## Objetos

| Objeto | Qué hace | Escena |
|---|---|---|
| Mesa central con los bots | Jugar contra bots | `BotSelect.tscn` |
| Estantería «Juegos» | Elegir un juego (mesa local) | `Menu.tscn` |
| Pizarra «Cómo se juega» | Tutorial jugable | `Main.tscn` con `Tutorial.requested` |
| Puerta «Salas» | Salas online (bloqueada en la demo) | `Lobby.tscn` |
| Taller | Estudio de creación (bloqueado en la demo) | `GameCreatorEditor.tscn` |
| Espejo | Cambia el color del peón | — |
| Tocadiscos | Sonido sí/no | — |
| Corcho «Ajustes» | Idioma, sonido, pantalla completa, menú clásico, créditos, informar de un fallo, salir | panel |

Juguetes sueltos (dados y fichas con física) que el peón empuja al pasar.

## Controles

- **Andar:** WASD, flechas o stick; o clic en el suelo.
- **Usar:** E, Intro o A al estar cerca (sale la etiqueta); o clic en el objeto: el peón va y lo usa.
- **Tab:** menú clásico (selector de modos). **Esc:** ajustes.
- Al volver de una pantalla, el peón aparece junto al objeto que usó.

## Reglas de diseño

- De abrir el juego a jugar, 10 segundos o menos: el peón empieza al lado de la mesa con «E · Jugar contra bots».
- Siempre hay atajo: Tab, Esc y la opción **«Abrir con el menú clásico»**, que hace que el inicio
  (y la vuelta desde una mesa) sea la portada de siempre (`BotMenu.tscn`). Desde ella, «Ir a la
  habitación» lo deshace.
- «Volver» en Elegir juego, Bots, Salas y Créditos regresa a la habitación si se vino de ella
  (`SessionNavigation.back_target`).
- Cámara fija que sigue a medias al peón; sin cámara libre. «Reducir movimiento» quita el
  balanceo de los bots y la bajada inicial de la cámara.

## Código

- `scripts/home/Home.gd`: escena, objetos, cámara, interfaz y acciones.
- `scripts/home/HomePawn.gd`: el peón (CharacterBody3D) y el empuje de juguetes.
- `scripts/home/Interactable.gd`: objeto usable (id, texto, alcance, punto de llegada, bloqueo).
- `scripts/home/HomeDecor.gd`: piezas de la sala compartidas con el diorama de los menús.
- `scripts/home/HomePrefs.gd`: color del peón y menú clásico (`user://tablerama_home.cfg`).
- Pruebas: `tests/home_room.gd`. Capturas: `tools/home_shots.gd -- carpeta [--demo] [--en]`.
