# Preparación de una beta local · Tablerama

Este documento es una lista de trabajo, no una declaración de que exista ya una beta validada. El objetivo inicial es probar partidas locales básicas en un mismo equipo antes de abordar el multijugador del GDD.

## Contenido disponible en el prototipo

- Menú de acceso y pausa, con modo opcional de dos clics para agarrar y soltar, guía de controles F1, cancelación de agarre X, confirmaciones de acciones destructivas y recentrado y vistas rápidas de cámara; bloqueo, inspección textual y deshacer posicional limitado de una pieza en mesas libres; mesa sandbox física con dados, fichas y cartas, y guardado local.
- Ajedrez en vista simple, físico con reglas y físico libre, con seis siluetas originales por color. Las dos vistas con reglas admiten una IA inicial con negras y comparten guardado lógico; la mesa libre no valida jugadas ni guarda su disposición.
- Damas con reglas en vista simple o con fichas físicas asistidas; mesa física libre y guardado lógico de los modos con reglas.
- Ludo local con una variante documentada para dos a cuatro personas, dado y fichas físicos asistidos y guardado lógico; sin IA ni red.
- Dominó físico libre o con reglas de doble seis para dos personas, cadena asistida y guardado por historial.
- Isla de recursos inspirada en Catán para tres o cuatro personas en el mismo equipo, con interfaz contextual, mano de recursos ilustrada, piezas y dados físicos lanzables con teclado o ratón, las principales reglas del juego base y guardado lógico. Ofrece ocultación visual opcional durante los traspasos locales, sin protección del guardado ni red.
- Mesa manual con baraja inglesa de 52 y española de 40 cartas, con mezcla, robo, devolución de cartas y cuerpos físicos; guardado local.

## Bloqueos antes de considerar una beta local jugable

Estado a 7 de noviembre de 2026. La prueba con personas está descrita en [PRUEBAS.md](PRUEBAS.md).

- [x] **Renderizador real**: revisión visual de las 16 escenas a 1280×720 y 1024×600 con OpenGL por software. Corregidos los avatares tapados o cortados y la pista que tapaba nombres. *Falta una pasada con GPU real.*
- [x] **Pausa y salida**: comprobadas automáticamente en 12 mesas (`tests/playthroughs.gd`).
- [x] **Partidas completas** de cada variante con reglas, con física real: ajedrez, damas, dominó, ludo e isla de recursos terminan y cada pieza física acaba donde dice el estado lógico. Masas y fuerzas ajustadas: las piezas que van lejos vuelan por encima de las demás y los caminos de la isla ya no empujan pueblos.
- [x] **Guardados**: escritura atómica con copia anterior, probada en los tests de cada juego. *No se garantiza durabilidad ante cortes de corriente en todos los sistemas ni hay bloqueo entre instancias.*
- [ ] **Controles con personas**: agarre (dos modos), soltar sobre la interfaz y fuera de la ventana, bloqueo, inspección, vistas y deshacer, con 3 personas ajenas ([PRUEBAS.md](PRUEBAS.md)).
- [x] **Exportaciones**: Linux arranca y abre todas las mesas (también en CI). *Windows y macOS están exportados pero sin probar en equipos reales.*

## Más allá de la beta local básica

Multijugador autoritativo, manos privadas con filtrado por destinatario, editor no-code, Steam y Workshop, más juegos y variantes, localización, seguridad, accesibilidad ampliada y publicación siguen pendientes. El modelo previsto es un juego completo de pago único (también en pack de 4) y una demo gratuita que solo puede unirse a salas, sin suscripción; ver [ROADMAP.md](ROADMAP.md).
