# Estado de desarrollo · Dice on!!

Este archivo diferencia la implementación actual de los objetivos del [GDD](GDD-Dice-on.md). Los elementos marcados como prototipo requieren pruebas visuales y físicas; no son promesas de lanzamiento.

## Implementado como primer prototipo local

- Menú principal con catálogo de modos locales y pausa con Esc; advierte de cambios no guardados al volver. Modelos procedurales diferenciados de las seis piezas de ajedrez, fichas de damas decoradas y cartas con esquinas rotuladas.
- Mesa manual de cartas con baraja inglesa de 52 y española de 40, mezcla y robo físicos; sin privacidad, reparto automático, reglas de cartas ni guardado de esta escena.

- Mesa 3D con cámara orbital, panorámica y zoom; dos dados y fichas físicas, cartas numeradas y mazo mezclable. Guardado local versionado de la mesa libre: posiciones, orientaciones, velocidades, cartas, orden del mazo y estado del imán; la física se reanuda al cargar. Valida el archivo antes de sustituir la escena, pero la escritura no es atómica y no guarda la cámara ni ofrece nube.
- Agarre mediante fuerzas, altura adaptativa y rueda para elevar; recuperación individual explícita con H. Cuadrícula magnética opcional con prueba de destino y barrido. Las fichas pueden chocar y apilarse físicamente; reinicio de mesa.
- Ajedrez local de dos personas en el mismo equipo: selección por casilla, destinos legales, turnos y deshacer; enroque, captura al paso, promoción, jaque/mate/ahogado y detección básica de tablas. La reclamación de 50 movimientos o tres repeticiones solo se comprueba tras alcanzar la posición, no con una jugada anunciada. Incluye un guardado local de partida basado en historial validado (un archivo por dispositivo; sobrescribe el anterior), independiente del guardado de mesa libre. Hay una vista simple, una mesa física libre sin reglas y un modo físico con reglas que valida al soltar y devuelve las piezas mediante fuerzas; enroque, captura al paso y promoción actualizan cuerpos y modelos. Ambos modos con reglas comparten guardado por historial, sin guardar posiciones físicas exactas. No hay reloj. La lógica está separada de la vista.
- Damas locales con reglas: variante adaptada de damas inglesas, con blancas primero, captura y continuación obligatorias, coronación que termina el turno, deshacer por salto y guardado local por historial. Hay una vista simple de piezas visuales, un modo de 24 fichas físicas libres sin reglas y otro de fichas físicas con reglas: valida al soltar, devuelve piezas mediante fuerzas y desplaza capturadas a un lateral. Ambos modos con reglas comparten un guardado lógico, que se puede cargar explícitamente tras cambiar de modo; no conserva posiciones físicas exactas. No implementa tablas, reloj, IA ni red.
- Dominó físico doble seis: modo libre manual y modo local con reglas para dos personas, reparto 7/7, robo obligado sin jugada, pase con pozo vacío, victoria al vaciar la mano o cierre por puntos. Las 28 fichas son cuerpos rígidos; los destinos se validan al soltar y la asistencia usa fuerzas. La cadena usa una disposición física en zigzag y asistencia angular por torque, con texto como referencia lógica; las colisiones pueden impedir la alineación exacta. El modo con reglas puede guardar y cargar localmente un historial validado; no guarda posiciones físicas exactas. Sin manos privadas, red ni puntuación por rondas.
- Isla de recursos local para tres o cuatro personas, inspirada en las reglas principales del juego base de Catán: producción, construcción, ladrón, puertos, comercio entre jugadores, cartas de desarrollo, ruta más larga, ejército más grande y victoria. Dados y piezas de tablero físicos; cartas gestionadas por interfaz. Guardado local por replay y semilla, sin poses físicas ni escritura atómica. Las manos son públicas; sin red, IA ni expansiones. Falta QA visual y partida manual completa.
- Pruebas automatizadas para agarre, colisiones, apilado, menú, modelos, barajas, guardado de mesa, tablero físico, ajedrez físico con reglas, dominó físico, orientación de cadena y reglas (50 partidas simuladas), reglas y guardado físicos, navegación, cuadrícula, ajedrez y damas, ejecutadas en Godot 4.7 en modo headless; incluyen perft, 206 posiciones de ajedrez y 171 de damas contrastadas con referentes independientes. Falta validar presentación, interacción con ratón y rendimiento gráfico en un Godot con renderizador real.

## Pendiente para completar el GDD

1. Robustecer el ajedrez con pruebas exhaustivas de reglas, casos límite, accesibilidad, relojes, mejoras de guardado y juego libre opcional.
2. Física asistida avanzada: apilado automático, casos extremos del barrido, recuperación configurable y controles accesibles/remapeables; robustecer la integración de física con reglas y llevarla a otros juegos.
3. Catálogo: ampliar y validar las variantes de damas; desarrollar parchís/ludo, otras variantes y privacidad de dominó, reglas de barajas y roles ocultos.
4. Editor no-code: importación validada de imágenes/modelos, generador de fichas y mazos, zonas, lógica visual acotada y paquetes versionados.
5. Red: servidor autoritativo, bloqueos, reconexión, filtros de información privada y pruebas de latencia. El juego actual no es multijugador de red.
6. Steam: integración de plataforma, invitaciones, Workshop, licencias por copia y moderación; código de sala requiere un servicio compatible. Sin Friend Pass ni suscripción.
7. HUD completo, ajustes y accesibilidad, persistencia, localización, pruebas de rendimiento, seguridad y publicación; evaluación posterior de tablets.

El volumen de trabajo y las dependencias externas hacen que el GDD completo no equivalga a un único cambio ni a una función ya terminada.


Consulta [BETA.md](BETA.md) para los bloqueos de una beta local verificable. La existencia de un menú y pruebas headless no equivale a una beta ya validada con jugadores.
