# Estado de desarrollo · Tablerama

Este archivo diferencia la implementación actual de los objetivos del [GDD](GDD-Tablerama.md). Los elementos marcados como prototipo requieren pruebas visuales y físicas; no son promesas de lanzamiento.

## Implementado como primer prototipo local

- **Herramientas de mesa (fase 2, primera parte):** menú radial con clic derecho corto en todas las mesas, señalar con P y rebobinado de la mesa libre con una tira de momentos.
- **Estilo cartoon (fase 1, primera parte):** iluminación por bandas, contornos de tinta, fondo y luz de la paleta, tema de interfaz con fuentes Lilita One y Nunito, y rebote al agarrar y soltar piezas, con opción de reducir animaciones. Se aplica a todas las mesas desde el autoload `ToonStyle`; reglas en [ARTE.md](ARTE.md). Faltan mallas rediseñadas, entorno ilustrado, partículas, sonido y pruebas de lectura con personas.
- Menú principal con catálogo de modos locales y pausa con Esc; advierte de cambios no guardados al volver. Guía de controles F1 adaptada a la mesa y confirmaciones antes de cargar, reiniciar o cambiar de mesa; la cancelación X, la suelta sobre la interfaz y la pérdida de foco evitan confirmar una jugada en curso, pero no deshacen toda la física de la mesa; el destino se fija al soltar, incluso entre pasos físicos. Modelos procedurales diferenciados de las seis piezas de ajedrez, fichas de damas decoradas y cartas con esquinas rotuladas.
- En mesas libres, Ctrl+Z o **Deshacer pieza** intenta devolver la última pieza desplazada al origen del agarre, sin cambiar su orientación ni revertir azar, barajas, otras piezas o reglas. Comprueba ocupación y bloqueos; es un único paso posicional y la física continúa. Se invalida al cargar o recuperar esa pieza con H; no es un historial de escena.
- Mesa manual de cartas con baraja inglesa de 52 y española de 40, mezcla y robo físicos, devolución de cartas al fondo de su baraja, y guardado local de posiciones, movimiento y orden de barajas con copia anterior; sin privacidad, reparto automático ni reglas de cartas.

- Mesa 3D con cámara orbital, panorámica, zoom y recentrado con Inicio; dos dados y fichas físicas, cartas numeradas y mazo mezclable. Guardado local versionado de la mesa libre: posiciones, orientaciones, velocidades, cartas, orden del mazo y estado del imán; la física se reanuda al cargar. Valida el archivo antes de sustituir la escena y conserva una copia anterior, pero no garantiza durabilidad ante cortes y no guarda la cámara ni ofrece nube.
- Herramientas en mesas libres: ayuda contextual al señalar o agarrar, L bloquea/desbloquea cuerpos y Alt muestra una inspección textual; las cartas boca abajo no muestran su valor en esa inspección. El bloqueo se conserva en las mesas guardables. Tres vistas de cámara temporales se recuperan con atajos o desde pausa. Falta validación visual y manual; no son manos privadas ni sustituyen las funciones de red o modding de Tabletop Simulator.
- Agarre mediante fuerzas, altura adaptativa y rueda para elevar; mantener pulsado o modo opcional de dos clics persistente. Pausa/pérdida de foco cancelan la jugada; pulsar sobre la interfaz mientras se agarra en modo dos clics cancela sin activar el control. H recupera la pieza agarrada, señalada o la última señalada. Cuadrícula magnética opcional con prueba de destino y barrido. Las fichas pueden chocar y apilarse físicamente; reinicio de mesa.
- Ajedrez local para dos personas o contra IA inicial con negras (casual o táctica limitada), seleccionable en ambas vistas con reglas. Selección por casilla, destinos legales, turnos y deshacer; enroque, captura al paso, promoción, jaque/mate/ahogado y detección básica de tablas. Las reclamaciones de 50 movimientos o tres repeticiones admiten anunciar una jugada legal sin ejecutarla. Incluye un guardado local de partida basado en historial validado (un archivo principal y una copia anterior por dispositivo), independiente del guardado de mesa libre. Hay una vista simple, una mesa física libre sin reglas y un modo físico con reglas que valida al soltar y devuelve las piezas mediante fuerzas; enroque, captura al paso y promoción actualizan cuerpos y modelos. Ambos modos con reglas comparten guardado por historial, sin guardar posiciones físicas exactas. No hay reloj. La lógica está separada de la vista.
- Damas locales con reglas: variante adaptada de damas inglesas, con blancas primero, captura y continuación obligatorias, coronación que termina el turno, deshacer por salto y guardado local por historial. Hay una vista simple de piezas visuales, un modo de 24 fichas físicas libres sin reglas y otro de fichas físicas con reglas: valida al soltar, devuelve piezas mediante fuerzas y desplaza capturadas a un lateral. Ambos modos con reglas comparten un guardado lógico, que se puede cargar explícitamente tras cambiar de modo; no conserva posiciones físicas exactas. No implementa tablas, reloj, IA ni red.
- Ludo local para dos, tres o cuatro personas: variante documentada con salida y turno extra por seis, capturas, casillas seguras, llegada exacta y victoria; sin apilado ni barreras. El **parchís** (2 y 4 jugadores) usa el mismo tablero con las reglas españolas: salida con 5 obligatoria y comiendo en la salida, barreras de dos fichas, seguros compartidos, premios de 20 al comer y 10 al llegar, 6 que vale 7 sin fichas en casa y castigo del tercer 6. Dado físico por teclado, botón o arrastre, fichas dinámicas asistidas, selección por botones o arrastre y guardado lógico por replay; falta QA visual y manual.
- Brisca para dos con la baraja española (BriscaRules, bot y mesa propia), contra el bot o dos personas con la mano tapada al cambiar de turno; guardado por semilla y jugadas.
- Mesa de cartas: barajas propias desde imágenes (carpeta de mazos, PNG/JPG/WebP) y manos ordenables (por palo, por número o arrastrando).
- Dominó físico doble seis: modo libre manual y modo local con reglas para dos personas, reparto 7/7, robo obligado sin jugada, pase con pozo vacío, victoria al vaciar la mano o cierre por puntos. Las 28 fichas son cuerpos rígidos; los destinos se validan al soltar y la asistencia usa fuerzas. La cadena usa una disposición física en zigzag y asistencia angular por torque, con texto como referencia lógica; las colisiones pueden impedir la alineación exacta. El modo con reglas puede guardar y cargar localmente un historial validado; no guarda posiciones físicas exactas. Sin manos privadas, red ni puntuación por rondas.
- Isla de recursos local para tres o cuatro personas, inspirada en las reglas principales del juego base de Catán: producción, construcción, ladrón, puertos, comercio entre jugadores, cartas de desarrollo, ruta más larga, ejército más grande y victoria. Dados y piezas de tablero físicos; dados lanzables con R/T, botón o arrastre manual de ambos cuerpos. Interfaz por fases y pestañas, mano ilustrada y terrenos con arte; cartas gestionadas por interfaz. Guardado local por replay y semilla, sin poses físicas ni garantía de escritura atómica. Ocultación visual opcional al pasar el equipo entre jugadores, con puntuación pública sin puntos de cartas ocultos; no cifra el guardado ni impide mirar la pantalla. Sin red, IA ni expansiones. Falta QA visual y partida manual completa.
- Los modos con guardado conservan la versión anterior validada y recurren a ella si falla el principal; no garantizan durabilidad ante cortes ni soportan escrituras simultáneas de varias instancias. No hay nube.
- Pruebas automatizadas para agarre, colisiones, apilado, menú, modelos, barajas, guardado de mesa, tablero físico, ajedrez físico con reglas, dominó físico, orientación de cadena y reglas (50 partidas simuladas), reglas y guardado físicos, navegación, cuadrícula, ajedrez y damas, ejecutadas en Godot 4.7 en modo headless; incluyen perft, 206 posiciones de ajedrez y 171 de damas contrastadas con referentes independientes. Falta validar presentación, interacción con ratón y rendimiento gráfico en un Godot con renderizador real.

### Quejas de TTS resueltas en local (noviembre de 2026)

- **Herramientas de mesa** (mesa libre, «Partida → Añadir a la mesa»): contador (+/−, R a cero), bolsa (suelta piezas encima, N saca una al azar), nota (Intro para escribir) y reloj (R arranca, +/− cuenta atrás). Se guardan y se rebobinan.
- **Zonas privadas**: mano de J1 y de J2 en la mesa libre; desde otro asiento cada pieza de dentro se ve como una nubecilla con «?» (se sabe cuántas hay, no cuáles) y no se puede agarrar.
- **Vistas**: V recorre vista cenital y los 4 asientos (Mayús+V hacia atrás).
- **Pincel** (D) en todas las mesas con piezas físicas y **volcar la mesa** (Ctrl+F, se deshace con Rebobinar).
- **Mando y Steam Deck**: stick izquierdo mueve el cursor, A agarra, B abre el menú radial, stick derecho orbita, gatillos hacen zoom.
- **Tutorial jugable** de 9 pasos (menú «Empieza aquí» y la primera vez que se abre la mesa libre) y atajos flotando sobre cada pieza.
- **Idiomas**: español, inglés y catalán (selector en el menú principal).

### Más juego sin red (7 de noviembre de 2026)

- **Bots**: en el ludo se marca qué jugadores lleva un bot; en el dominó guiado, el jugador 2; en las damas guiadas, las oscuras (minimax). Piensan un momento antes de cada acción para que se vea lo que hacen; deshacer en damas vuelve hasta tu jugada. El menú «Jugar contra bots» abre mesas en solitario (el humano siempre es J1) con **tres dificultades**: fácil (se equivoca a propósito), normal (sentido común) y difícil (mirada de una jugada más, minimax a 3, riesgo elevado en parchís, bazas de 4 puntos en brisca). La isla aún no tiene bot en la vista.
- **Asientos fuera de la mesa**: los personajes de ludo, parchís e isla se colocan más allá del borde de la mesa física (AABB del colisionador + margen para el cuerpo), así no se clavan en el tablero.
- **Apilado automático**: carta sobre mazo, carta sobre carta (mazo nuevo) y ficha sobre ficha.
- **Inspección 3D** con Alt: la pieza ampliada girando en su propio estudio.
- **Marcador** de 4 jugadores (1–4 elige la fila, + / − puntos).
- **Dibujos guardados** con la mesa libre.
- **Medidor de tirones** (F3) para diagnosticar rendimiento en equipos reales.

### Cierre técnico de la fase 0 (7 de noviembre de 2026)

- `tests/playthroughs.gd`: partidas completas en ajedrez, damas, dominó, ludo e isla con física real, más pausa y salida en 12 mesas.
- `HomeSteering`: las piezas que van lejos (comidas, cadena del dominó, ladrón) vuelan por encima de las demás sin chocar y aterrizan en su casa; el ajedrez se mantiene derecho.
- Bot de la isla de recursos (`TableBots.island_action`).
- `-- --prueba-arranque` y paso de CI que arranca el ejecutable de Linux y abre todas las mesas.
- [PRUEBAS.md](PRUEBAS.md): protocolo para la prueba con 3 personas, lo único que falta para cerrar la fase.

## Pendiente para completar el GDD

1. Robustecer el ajedrez con pruebas exhaustivas de reglas, casos límite, accesibilidad, relojes, una IA más avanzada para distintos niveles y juego libre opcional.
2. Física asistida avanzada: apilado automático, casos extremos del barrido, recuperación configurable y controles accesibles/remapeables; robustecer la integración de física con reglas y llevarla a otros juegos.
3. Catálogo: ampliar y validar las variantes de damas; ampliar las variantes de parchís (por parejas, 6 jugadores) y privacidad de dominó, reglas de barajas y roles ocultos.
4. Editor no-code: importación validada de imágenes/modelos, generador de fichas y mazos, zonas, lógica visual acotada y paquetes versionados.
5. Red: servidor autoritativo, bloqueos, reconexión, filtros de información privada y pruebas de latencia. El juego actual no es multijugador de red.
6. Steam: integración de plataforma, invitaciones, Workshop, licencias (solo el juego completo aloja salas; la demo se une) y moderación; código de sala requiere un servicio compatible. Sin suscripción.
7. HUD completo, ajustes y accesibilidad, persistencia, localización, pruebas de rendimiento, seguridad y publicación; evaluación posterior de tablets.

El volumen de trabajo y las dependencias externas hacen que el GDD completo no equivalga a un único cambio ni a una función ya terminada.


El orden de trabajo previsto está en [ROADMAP.md](ROADMAP.md). Consulta [BETA.md](BETA.md) para los bloqueos de una beta local verificable. Los guardados usan temporal y copia anterior validada, sin garantía de atomicidad o durabilidad en todos los sistemas; falta probar interrupciones y falta de espacio en equipos reales. La existencia de un menú y pruebas headless no equivale a una beta ya validada con jugadores.
