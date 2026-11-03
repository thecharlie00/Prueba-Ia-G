# Preparación de una beta local · Dice on!!

Este documento es una lista de trabajo, no una declaración de que exista ya una beta validada. El objetivo inicial es probar partidas locales básicas en un mismo equipo antes de abordar el multijugador del GDD.

## Contenido disponible en el prototipo

- Menú de acceso y pausa; mesa sandbox física con dados, fichas y cartas, y guardado local.
- Ajedrez en vista simple, físico con reglas y físico libre, con seis siluetas originales por color. Las dos vistas con reglas admiten partida local de dos personas o contra una IA inicial (casual o táctica limitada); no es un motor competitivo. Los modos con reglas comparten guardado lógico, incluido el modo de oponente; la mesa libre no valida jugadas ni guarda su disposición.
- Damas con reglas en vista simple o con fichas físicas asistidas; mesa física libre y guardado lógico de los modos con reglas.
- Dominó físico libre o con reglas de doble seis para dos personas, cadena asistida y guardado por historial.
- Isla de recursos inspirada en Catán para tres o cuatro personas en el mismo equipo, con piezas y dados físicos, las principales reglas del juego base y guardado lógico; sin manos privadas ni red.
- Mesa manual con baraja inglesa de 52 y española de 40 cartas, con mezcla, robo y cuerpos físicos.

## Bloqueos antes de considerar una beta local jugable

- Ejecutar una compilación con renderizador real: inspeccionar las siluetas, lectura de cartas, iluminación, cámara, paneles, foco, pantallas pequeñas y estabilidad gráfica.
- Verificar en cada modo el flujo de pausa y confirmación de salida; las partidas locales que no tienen guardado perderán su estado al volver al menú.
- Probar manualmente con ratón y teclado: agarre, altura, colisiones, recuperación, pausas durante acciones y partidas completas de cada variante. Ajustar masas, fuerzas y objetivos según resultados reales.
- Comprobar comportamiento de guardado ante interrupciones y espacio insuficiente. Los guardados locales implementados escriben primero a un temporal en el mismo directorio y reemplazan mediante renombrado atómico, pero todavía requieren pruebas en sistemas y dispositivos reales. Las mesas de cartas y ajedrez físico libre todavía no se guardan; la isla guarda el estado lógico, no poses físicas.
- Mejorar claridad y recuperación de errores, accesibilidad y opciones de control; verificar que el estado lógico y el físico no confunden al jugador en casos de colisión o piezas desplazadas.
- Preparar exportaciones para los sistemas objetivo y probar instalación, inicio, rendimiento y regresiones en equipos reales.

## Más allá de la beta local básica

Multijugador autoritativo por red, IA para otros juegos, manos privadas, editor no-code, Steam y Workshop, más juegos y variantes, localización, seguridad, accesibilidad ampliada y publicación siguen pendientes. El modelo previsto continúa siendo de pago único por copia, sin suscripción ni Friend Pass.
