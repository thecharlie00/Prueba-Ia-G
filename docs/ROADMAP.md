# Roadmap · Tablerama

**Objetivo:** convertir el prototipo local en una alternativa a Tabletop Simulator (TTS) **más barata, más fácil de usar y más completa en lo que importa**, con una identidad visual **cartoon** propia.<br>
**Fecha:** 7 de noviembre de 2026 · **Estado:** plan de trabajo, no una lista de funciones ya terminadas. Lo implementado está en [ESTADO.md](ESTADO.md); el diseño de detalle, en el [GDD](GDD-Tablerama.md).

Las fases se ordenan por dependencias, no por fechas. Cada fase tiene un criterio de salida comprobable; no se pasa a la siguiente sin cumplirlo.

---

## 1. Posicionamiento

| | Tabletop Simulator | Tabletop Playground | **Tablerama (objetivo)** |
|---|---|---|---|
| Precio | 19,99 $; rebajas a ~10 $; cada jugador compra su copia | 14,99 $; cada jugador compra su copia | **9,99 €** de lanzamiento en Steam (Windows y Linux), demo gratuita; con el online, pack de 4 y demo que se une a salas |
| Estética | Realista, depende de cada mod | Realista / neutra | **Cartoon coherente**: sombreado plano, contornos, piezas redondeadas, animación con "juice" |
| Reglas | No impide jugadas ilegales salvo scripts del mod | Igual, scripting en JavaScript | **Juegos incluidos con reglas opcionales** (ya hay 7 modos) y reglas no-code en el editor |
| Contenido | Miles de mods gratis; marketplace de mods de pago anunciado en la 2.0 | Unos cientos de juegos | Catálogo propio + **Workshop siempre gratuito** |
| Curva de aprendizaje | Principal queja: controles poco intuitivos | Mejor: muestra los atajos al pasar el cursor | **Menú contextual, atajos visibles y tutorial jugable** |
| Requisitos | Exigente en equipos antiguos, problemas en Steam Deck | Similar | **Ligero por diseño**: el estilo cartoon es barato de renderizar |

**Frase de producto:** *«La mesa de juegos para jugar con tus amigos en 5 minutos, sin pelearte con la cámara ni con las piezas, y con un estilo que se reconoce en una captura».*

**Qué NO vamos a hacer** (para mantenerlo barato y fiable): VR, compatibilidad con mods o scripts Lua de TTS, marketplace de mods de pago, scripting de código arbitrario del usuario, réplicas de juegos comerciales con su arte o nombre.

---

## 2. Lo que piden y critican los usuarios de TTS

Resumen de reseñas de Steam agregadas, hilos de Reddit, el tablero de sugerencias de TTS y comparativas de prensa (fuentes al final). Son observaciones cualitativas, no una encuesta.

| # | Queja o petición de usuarios de TTS | Respuesta de Tablerama | Estado en el repo | Fase |
|---|---|---|---|---|
| 1 | Controles poco intuitivos, atajos escondidos, tutorial que solo cubre lo básico | Ayuda contextual, menú radial con clic derecho, atajos visibles sobre la pieza, tutorial jugable | **Hecho local**: tutorial jugable de 9 pasos, atajos flotando sobre cada pieza, menú radial y guía F1 | 2 |
| 2 | Física "jank": piezas que se pegan, cartas que no caen bien, colocar cuesta varios intentos | Física asistida: snap por defecto en zonas, cartas que se alinean, recuperación | **Parcial**: Jolt Physics con reposo ajustado, agarre por fuerza, imán 4×4, H recupera | 2 |
| 3 | No impide jugadas ilegales | Juegos incluidos con reglas opcionales; reglas no-code en el editor | **Hecho local** en ajedrez, damas, dominó, ludo, isla | 4 |
| 4 | Deshacer pobre: pulsar "atrás" muchas veces con cargas lentas; piden elegir un punto de restauración | **Rebobinado con línea de tiempo** de la mesa | **Hecho local**: rebobinar con línea de tiempo de la mesa + Ctrl+Z de la última pieza | 2 |
| 5 | Manos privadas y zonas ocultas imprescindibles | Manos 2D/3D privadas, zonas ocultas por jugador | **Hecho local**: zonas privadas por asiento en la mesa libre (V cambia de asiento), manos 3D en cartas e isla; falta la privacidad real en red (fase 3) | 2–3 |
| 6 | Errores de conexión P2P/NAT, servidores | Steam Lobbies + relé de Steam Networking, sin abrir puertos | **Pendiente** | 3 |
| 7 | Lag, cuelgues, cargas lentas, actualizaciones que rompen el juego | Presupuestos de rendimiento, caché de assets, rama beta pública antes de cada actualización | **Pendiente** | 1, 3, 5 |
| 8 | Mal soporte de mando y Steam Deck | Steam Deck Verified como objetivo, controles con mando | **Parcial**: mando completo (cursor con stick, A/B clic, gatillos zoom, botones a atajos); falta probar en una Steam Deck y glifos de mando | 2 |
| 9 | Polémica por los mods de pago del marketplace de la 2.0 | Workshop gratuito como compromiso público | **Pendiente** | 4 |
| 10 | Mods de calidad irregular, que se rompen | Paquetes con assets incluidos y validados (no enlaces externos que caducan) | **Pendiente** | 4 |
| 11 | Cada amigo tiene que comprar el juego | Precio bajo (9,99 €); con el online, pack de 4 y demo que se une a salas de quien tiene el juego completo (ver §5) | **Decidido**, pendiente de implementar | 3, 5 |
| 12 | Traducciones automáticas y fuentes sin soporte | Localización revisada por personas, fuentes con cobertura completa | **Parcial**: español, inglés y catalán en menús, interfaz común y herramientas; los mensajes de reglas de cada juego siguen en español | 5 |
| 13 | VR rota | Fuera de alcance | — | — |
| 14 | Moderación y toxicidad en chat (polémicas de moderación) | Silenciar, bloquear, denunciar, permisos del anfitrión y política clara | **Pendiente** | 3 |
| 15 | Difícil ver toda la mesa | Vistas por asiento, vista cenital, vistas guardadas | **Hecho local**: V recorre vista cenital y los 4 asientos; 3 vistas guardables | 2 |
| 16 | Muy valorado: dibujar en la mesa, señalar, voltear la mesa, guardar partidas largas | Pincel, "ping", volteo de mesa animado en clave cartoon, guardado | **Hecho local**: pincel (D), señalar (P), volcar la mesa (Ctrl+F) y guardado; los dibujos aún no se guardan con la partida | 2 |
| 17 | Muy valorado: preparación automática de partidas | Juegos incluidos y plantillas del editor que se preparan solos | **Hecho** en los modos con reglas | 4 |
| 18 | Contadores, bolsas con número de piezas, notas, temporizadores | Componentes utilitarios de mesa | **Hecho local**: contador, bolsa con recuento, nota editable y reloj/cuenta atrás; se guardan y se rebobinan | 2 |
| 19 | Pocos jugadores por sala (TTS 10, TTP 16) | Objetivo 8 en EA, 16 tras perfilado | **Pendiente** | 3, 6 |
| 20 | Chat de voz flojo en TTS; mejor en TTP | Voz por Steam en fase 6; mientras tanto, convivir con Discord | **Pendiente** | 6 |

Resumen (7 de noviembre de 2026): de las 20, **10 están hechas o casi hechas en local** (1, 3, 4, 5, 15, 16, 17, 18 y parcialmente 2, 8, 12). Las que quedan (6, 7, 9, 10, 11, 14, 19, 20) dependen del juego en red, del Workshop o del lanzamiento, y se atacan en las fases 3–6.

---

## 3. Fases

### Fase 0 · Cerrar la beta local (falta la prueba con personas)

Cumplir los bloqueos de [BETA.md](BETA.md) antes de abrir frentes nuevos.

- [x] Ejecución con renderizador real y revisión visual de todos los modos: 16 escenas a 1280×720 y 1024×600 (`tools/review_shots.gd`). Corregidos: avatares tapados por el panel en la isla y cortados en el dominó, y la pista que tapaba nombres (ahora se aparta sola).
- [x] Partidas completas en cada modo con reglas, con física y vistas reales (`tests/playthroughs.gd`, bots e IA por las mismas funciones que el jugador) y pausa/salida en 12 mesas. Encontraron y se corrigieron: piezas comidas atascadas al cruzar el tablero, la cadena del dominó que se enredaba al desplazarse, el ladrón de la isla bloqueado y caminos que empujaban pueblos. Las piezas ahora vuelan por encima de las demás hasta su casa (`HomeSteering`). *Falta la versión con personas (abajo).*
- [x] Exportaciones: Linux arranca y abre las 16 escenas (`-- --prueba-arranque`, comprobado también en CI en cada PR). Windows se exporta pero wine 9 se cierra antes de iniciar Godot, así que falta probarlo en un PC real; macOS solo se exporta.
- [x] Ejecutar la suite completa de tests en CI (GitHub Actions con Godot headless) en cada PR, con exportaciones de Windows, Linux y macOS como artefactos.

- [ ] **Prueba con 3 personas** siguiendo [PRUEBAS.md](PRUEBAS.md) (recorrido, hoja de observación y criterio de bloqueo).

**Salida:** 3 personas ajenas al proyecto completan una partida de cada modo sin bloqueos.

### Fase 1 · Identidad cartoon

Es la diferencia que se ve en una captura de Steam, así que va antes que el online. Se hace sobre el renderizador Compatibility que ya usa el proyecto para que siga funcionando en equipos modestos.

- [x] **Biblia de arte** ([`docs/ARTE.md`](ARTE.md)): paleta, proporciones de piezas, contornos, tipografía, cartas, manos e interfaz. *Falta la variante para daltonismo.*
- [x] **Iluminación toon** con los materiales toon de Godot y una luz y un ambiente de la paleta (en lugar de un shader de rampa propio).
- [x] **Contornos**: casco invertido (`shaders/toon_outline.gdshader`) validado en Compatibility.
- [x] **Rediseño de piezas**: kit de formas común para dados, dominó, cartas, fichas, ajedrez, damas, ludo e isla (casillas 3D con paisaje; pueblo, ciudad y camino con silueta propia).
- [x] **Cartas**: arte vectorial para la baraja inglesa y la española, el reverso y las cartas de la isla; manos de cartas en 3D sujetas delante de la cámara.
- [x] **Mesa y entorno**: suelo de tablones, alfombra y habitación con paredes de una cara, ventana, estantería y planta.
- [x] **"Juice"**: estirar y aplastar al agarrar y soltar, número que salta en el centro de la pantalla al resolverse un dado, con opción de **reducir animaciones**. Volcar la mesa ya hace temblar la cámara.
- [x] **Audio**: efectos generados por código (agarrar, soltar, dados, cartas, botones, turno), con opción para apagarlos. *Falta música ambiental y volúmenes separados.*
- [x] **UI cartoon**: tema común, fuentes Lilita One y Nunito, información en la mesa (jugadores sentados, cartel de turno, barra de acciones, cajón «Partida»). Cada juego tiene su color de acento y su emblema (`GameThemes`). *La isla y el ludo conservan su panel de acciones.*
- [x] Mantener la **legibilidad**: jugadores con número y nombre además del color; números de la isla con puntos de probabilidad; cartas con índice en dos esquinas.

**Salida:** captura comparativa antes/después de cada modo; 60 FPS en un portátil con gráficos integrados de referencia; test de lectura con 5 personas.

**Estado (6 de noviembre de 2026):** todo lo automatizable está hecho y comparado con capturas en [ARTE.md](ARTE.md). Para cerrar la fase faltan la medición de FPS y el test de lectura con personas, más la paleta para daltonismo, la música y pasar las acciones de la isla y el ludo a la barra inferior.

### Fase 2 · Herramientas de mesa que piden los usuarios

Todo en local primero, con el diseño preparado para red.

- [x] **Menú radial contextual** (clic derecho corto sobre una pieza) con las acciones disponibles y su atajo. El clic derecho mantenido sigue orbitando. Llega a todas las mesas desde el agarre y comparte la lógica de las teclas.
- [x] **Atajos visibles**: bocadillo con los atajos flotando sobre la pieza bajo el ratón.
- [x] **Tutorial jugable** de 9 pasos que se completan haciéndolos (agarrar, orbitar, zoom, tirar, menú radial, vistas, señalar, pincel). Desde «Empieza aquí» y la primera vez en la mesa libre.
- [x] **Rebobinado** de la mesa libre: guarda un momento cada vez que la mesa queda quieta tras una acción (hasta 40) y una tira «hace 12 s · hace 1 min…» permite volver a cualquiera. Usa el mismo formato validado que guardar y cargar. *Pendiente en los modos con reglas.*
- [x] **Zonas privadas** por jugador en la mesa libre: lo que hay dentro solo lo ve su asiento (V cambia de asiento); los demás ven una nubecilla con «?» por pieza. *Faltan las manos 2D con orden y selección múltiple.*
- [ ] **Snap points y zonas editables** en lugar de la cuadrícula 4×4 fija; cartas que caen alineadas en zonas de descarte.
- [x] **Componentes utilitarios**: contador, bolsa con número de piezas, nota de texto, reloj con cuenta atrás y marcador de 4 jugadores; se guardan y se rebobinan.
- [x] **Señalar ("ping")**: tecla P o «Señalar» en el menú; aro amarillo que se expande y flecha que bota. **Pincel** (D) con 5 colores en todas las mesas físicas; en la mesa libre los dibujos se guardan con la partida.
- [x] **Volcar la mesa** como gesto cómico (Ctrl+F): las piezas saltan, la mesa da un respingo y la cámara tiembla; se deshace con Rebobinar.
- [x] **Inspección 3D ampliada**: con Alt, la pieza gira en un pequeño estudio con su propia luz; las cartas solo se balancean para no enseñar la cara oculta.
- [x] **Vistas por asiento** y vista cenital con V (Mayús+V hacia atrás).
- [x] **Mando**: cursor con el stick, A/B como clics, stick derecho orbita, gatillos zoom, botones a los atajos. *Falta probarlo en una Steam Deck, glifos de mando y remapeo de teclas.*
- [x] **Apilado automático**: carta sobre mazo entra arriba, carta sobre carta forma un mazo nuevo y ficha sobre ficha se centra encima (mesa libre y mesa de cartas).

**Estado (7 de noviembre de 2026):** hecho casi todo en local; además, pantalla adaptable con F11, física con Jolt, zoom de cartas en la mano e idiomas español, inglés y catalán. Quedan las manos 2D y los snap points editables, y las pruebas con personas y en Steam Deck. Adelantado de la fase 6: bots para completar mesas.

**Salida:** test de usabilidad: el 90 % de novatos mueve, voltea y roba sin ayuda en su primer intento (objetivo del GDD); partida completa con mando en Steam Deck.

### Fase 3 · Multijugador online

Arquitectura del README y del GDD: servidor autoritativo, IDs estables, comandos de intención.

- [ ] Capa de estado lógico con IDs estables común a todas las mesas (refactor previo).
- [ ] Host local autoritativo con `MultiplayerPeer`; bloqueo de piezas al agarrar con el nombre de quien la tiene.
- [ ] **Steam**: lobbies, invitaciones de amigos y relé de Steam Networking para evitar problemas de NAT; código de sala.
- [ ] Filtrado de información oculta por destinatario: manos, mazos, roles; tests que comprueban que ningún paquete filtra datos.
- [ ] Dados y barajado decididos por el host.
- [ ] Reconexión y recuperación de la partida.
- [ ] **Moderación**: silenciar, bloquear, expulsar, denunciar, permisos del anfitrión (quién puede tocar qué), filtro de chat opcional.
- [ ] Chat de texto y registro de eventos.
- [ ] **Licencias en salas**: solo el juego completo crea y aloja salas; la demo solo puede unirse. El host comprueba la licencia, no el cliente.
- [ ] Enviar a los jugadores de la demo el contenido del Workshop que use la sala, solo para esa sesión (sin guardarlo ni instalarlo).
- [ ] Pruebas con latencia, pérdida de paquetes y 8 jugadores.

**Salida:** 20 sesiones de prueba con amigos en redes domésticas distintas: ≥ 95 % de uniones a la primera, partidas de 1 h sin desincronización ni cuelgues.

### Fase 4 · Editor no-code y Workshop gratuito

- [x] Primer paso sin conexión: **barajas propias desde imágenes** (una carpeta por baraja en la carpeta de mazos, una imagen por carta) en la mesa de cartas, con guardado y validación de rutas.
- [ ] Asistente de importación: imágenes, hojas de cartas (filas × columnas), fichas extruidas, glTF/GLB.
- [ ] **Estilo cartoon automático opcional** para lo importado (shader toon y contorno), para que el contenido de la comunidad encaje con el juego.
- [ ] Zonas, rutas y casillas pintadas; reglas de disparador → condición → acción del GDD.
- [ ] Plantillas que se preparan solas (repartir, colocar, mezclar).
- [ ] Paquetes con manifiesto, versión y **assets incluidos** (sin enlaces externos que puedan caducar).
- [ ] **Steam Workshop gratuito**, con licencia declarada, denuncia y retirada.
- [ ] Compromiso público en la página de Steam: *el contenido de la comunidad es y será gratuito*.

**Salida:** una persona sin experiencia crea y publica un juego de cartas sencillo en ≤ 15 min con recursos preparados.

### Fase 5 · Early Access en Steam

- [ ] Catálogo de lanzamiento: ajedrez, damas, dominó, ludo, isla de recursos, cartas y **roles ocultos** (pendiente del GDD).
- [x] Bots para completar mesas en ludo/parchís (cualquier jugador), dominó (jugador 2), damas (oscuras, minimax) y brisca, con **menú «Jugar contra bots»** y **tres dificultades** (fácil, normal y difícil). El ajedrez ya tenía IA.
- [ ] Localización revisada: español, catalán e inglés; después francés, alemán, portugués.
- [ ] Página de Steam con capturas y tráiler cartoon.
- [x] **Demo gratuita** local: mesa libre, brisca y parchís, exportada con la característica `demo` (presets propios en la CI). Pendiente: unión a salas online (ver §5).
- [ ] Precio de 9,99 € y precios regionales (ver §5 y `docs/MODELO-NEGOCIO.md`); pack de 4 cuando llegue el online.
- [ ] Rama beta pública para probar cada actualización antes de publicarla.
- [ ] Objetivo **Steam Deck Verified** y Linux nativo.

**Salida:** rendimiento y estabilidad medidos en 5 configuraciones de hardware; tasa de cuelgues < 1 % de sesiones en la beta pública.

### Fase 6 · Versión 1.0 y después

- [x] **Brisca** para dos (contra el bot o dos personas en el mismo equipo, con la mano tapada al cambiar de turno) y **parchís** con reglas españolas para 2 y 4 (salir con 5, barreras, comer 20, meta 10, el 6 vale 7, castigo del tercer 6). Hecho en noviembre de 2026, antes del online.
- [x] **Manos ordenables**: ordenar por palo o por número y arrastrar cartas a otro hueco del abanico.
- Más juegos y variantes (mus, guiñote, tute, juegos de dados).
- Salas de hasta 16 jugadores tras perfilado.
- Chat de voz integrado.
- Tablets (iOS/Android) con controles táctiles propios.

---

## 4. Riesgos de este roadmap

| Riesgo | Mitigación |
|---|---|
| El estilo cartoon reduce la legibilidad de cartas y tableros | Pruebas de lectura en la fase 1; contornos y tamaños mínimos de texto en la biblia de arte |
| El online consume más tiempo del previsto | Refactor de estado lógico antes de tocar red; empezar con 2–4 jugadores |
| Contenido de la comunidad con derechos ajenos | Licencia declarada, denuncia, retirada; no buscar "clones" de juegos comerciales |
| Un precio bajo no cubre el desarrollo | Coste contenido: Godot, sin servidores dedicados al principio (host local + relé de Steam) |
| La demo no puede unirse a lobbies del juego completo si Steam los trata como apps distintas | Comprobarlo en un spike de Steam al empezar la fase 3; alternativa: app base gratuita y el juego completo como desbloqueo de pago (DLC) |
| Grupos donde solo una persona compra el juego | Es intencionado: baja la barrera de entrada. Medir conversión de demo a compra y ajustar lo que ofrece el juego completo, no restringir la demo |
| TTS 2.0 mejora sus controles y su UI | Competir en precio, estética, reglas incluidas y Workshop gratuito, no solo en controles |

## 5. Modelo de venta (revisado el 7 de noviembre de 2026)

Detalle, cuentas y fuentes en [`docs/MODELO-NEGOCIO.md`](MODELO-NEGOCIO.md). Objetivo: gastar lo mínimo y quedarse el máximo por copia.

| | Decisión |
|---|---|
| Plataformas | **PC: Windows y Linux** (Steam Deck). Sin macOS ni móvil: la firma de Apple cuesta 99 $ al año |
| Tienda | **Solo Steam** el primer año (alta 100 $, recuperables). itch.io gratis para la demo y pruebas. Epic quizá el segundo año |
| Precio | **9,99 €** (12,99 € tras el primer año), 10–15 % de descuento de lanzamiento, precios regionales |
| Contenido 1.0 | **Todo offline**: mesas, reglas y bots; sin servidores ni gasto mensual |
| Extras | Workshop gratuito (mazos de imágenes) y pack de apoyo opcional de 3,99 € sin ventaja de juego |
| Lanzamiento | Next Fest de junio de 2027 con la demo y salida el 6 de julio de 2027 |

Sin suscripción, anuncios ni microtransacciones.

### Cuando llegue el online (fase 3)

Se mantiene la idea original: basta con que **una persona** tenga el juego completo para que sus amigos se unan con la demo, y vuelve el **pack de 4** para regalar al grupo.

| | **Juego completo** | **Demo gratuita** |
|---|---|---|
| Modos locales | ✓ | Mesa libre y dos juegos |
| Crear y alojar salas online | ✓ | ✗ |
| **Unirse** a salas online | ✓ | ✓, solo a salas de alguien con el juego completo |
| Workshop: descargar, editor y publicar | ✓ | ✗; juega lo que use la sala |

### Decisiones abiertas

1. Si la demo tiene algún límite en salas (por ejemplo, número de jugadores con demo por sala).
2. Número máximo de jugadores en Early Access.
3. Si el volteo de mesa y otros gestos cómicos se pueden desactivar por sala.
4. Momento del alta de autónomo y facturación a Valve (gestor).

## 6. Nombre: Tablerama (elegido el 6 de noviembre de 2026)

**Tablerama** = *tablero* + *-rama* (panorama, cinerama): una mesa donde caben todos los juegos, con un tono alegre que encaja con el estilo cartoon. Sustituye al nombre provisional «Dice-on».

- Descartado **Tabletoons**: ya existe como juego de mesa.
- En una búsqueda web (noviembre de 2026) no apareció ningún videojuego ni juego de mesa llamado Tablerama; solo comercios sin relación (una maderera mexicana y algunos importadores).
- **Pendiente antes de publicar:** búsqueda formal de marca en EUIPO/OEPM (clases 9, 28 y 41) y comprobar que el nombre está libre en Steam, el dominio y las redes.
- Los archivos de guardado internos (`user://diceon_*.cfg`) conservan su nombre para no perder ajustes ni partidas.

---

## Fuentes

- Resumen de reseñas de Steam de TTS: [VaporLens](https://vaporlens.app/app/286160/tabletop_simulator)
- Hilo de r/boardgames sobre TTS como alternativa a la mesa física: [Reddit](https://lr.in.psf.lt/r/boardgames/comments/xcd5gv/is_tabletop_simulator_a_good_alternative_to)
- Petición «better undo» del tablero de sugerencias de TTS: [Nolt](https://tabletopsimulator.nolt.io/402)
- Anuncio de TTS 2.0 y marketplace de mods de pago: [PC Gamer](https://www.pcgamer.com/games/sim/tabletop-simulator-announces-a-free-2-0-update-that-includes-a-ui-overhaul-and-a-marketplace-for-paid-mods), [Steam Deck HQ](https://steamdeckhq.com/news/tabletop-simulator-2-0-steam-deck-improvements/)
- TTS frente a Tabletopia: [Meeple Mountain](https://www.meeplemountain.com/?p=22769)
- Tabletop Playground frente a TTS: [Meeple Mountain](https://www.meeplemountain.com/articles/learn-how-to-use-tabletop-playground); precio actual: [Steambase](https://steambase.io/games/tabletop-playground/price)
- Herramientas de TTS que usan los diseñadores (zonas ocultas, snap points, bloqueo): [Entro Games](https://entrogames.substack.com/p/tabletop-simulator-106-optimizing-for-playing-playtesting)
- Investigación previa del proyecto: [REFERENCIAS-TABLETOP.md](REFERENCIAS-TABLETOP.md)
