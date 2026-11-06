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

- Ejecutar una compilación con renderizador real: inspeccionar las siluetas, lectura de cartas, iluminación, cámara, paneles, foco, pantallas pequeñas y estabilidad gráfica.
- Verificar en cada modo el flujo de pausa y confirmación de salida; las partidas locales que no tienen guardado perderán su estado al volver al menú.
- Probar manualmente con ratón y teclado: agarre, altura, colisiones, recuperación, pausas durante acciones y partidas completas de cada variante. Ajustar masas, fuerzas y objetivos según resultados reales.
- Comprobar los temporales y la recuperación del guardado anterior ante cortes reales y espacio insuficiente; no se garantiza atomicidad ni durabilidad en todos los sistemas, ni hay bloqueo entre instancias. La mesa de ajedrez físico libre todavía no se guarda; la isla guarda el estado lógico, no poses físicas.
- Validar los dos modos de agarre, la suelta sobre la interfaz y fuera de ventana, el bloqueo, la inspección, las vistas rápidas, el deshacer de una pieza y la recuperación de piezas en partidas manuales, y ampliar claridad, accesibilidad y opciones de control; verificar que el estado lógico y el físico no confunden al jugador en casos de colisión o piezas desplazadas.
- Preparar exportaciones para los sistemas objetivo y probar instalación, inicio, rendimiento y regresiones en equipos reales.

## Más allá de la beta local básica

Multijugador autoritativo, manos privadas con filtrado por destinatario, editor no-code, Steam y Workshop, más juegos y variantes, localización, seguridad, accesibilidad ampliada y publicación siguen pendientes. El modelo previsto es un juego completo de pago único (también en pack de 4) y una demo gratuita que solo puede unirse a salas, sin suscripción; ver [ROADMAP.md](ROADMAP.md).
