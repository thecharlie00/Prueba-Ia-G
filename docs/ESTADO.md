# Estado de desarrollo · Dice on!!

Este archivo diferencia la implementación actual de los objetivos del [GDD](GDD-Dice-on.md). Los elementos marcados como prototipo requieren pruebas visuales y físicas; no son promesas de lanzamiento.

## Implementado como primer prototipo local

- Mesa 3D con cámara orbital, panorámica y zoom; dado físico, cartas numeradas y mazo mezclable.
- Agarre mediante fuerzas y cuadrícula magnética 4×4 con prueba de ocupación en el destino, sin barrido del trayecto. Reinicio de mesa.
- Ajedrez local de dos personas en el mismo equipo: selección por casilla, destinos legales, turnos y deshacer; enroque, captura al paso, promoción, jaque/mate/ahogado y detección básica de tablas. La reclamación de 50 movimientos o tres repeticiones solo se comprueba tras alcanzar la posición, no con una jugada anunciada. Incluye un guardado local de partida basado en historial validado (un archivo por dispositivo; sobrescribe el anterior), sin guardado de la mesa libre. No hay reloj ni modo de ajedrez libre. La lógica está separada de la vista.
- Pruebas automatizadas para componentes, cuadrícula y reglas de ajedrez, ejecutadas en Godot 4.7 en modo headless; incluyen perft y 206 posiciones de referencia. Falta validar presentación, interacción con ratón y rendimiento gráfico en un Godot con renderizador real.

## Pendiente para completar el GDD

1. Robustecer el ajedrez con pruebas exhaustivas de reglas, casos límite, accesibilidad, relojes, mejoras de guardado y juego libre opcional.
2. Física asistida avanzada: altura adaptativa, apilado, recuperación individual, colocación con barrido y controles accesibles/remapeables.
3. Catálogo: variantes definidas y comprobadas de damas, parchís/ludo, dominó, barajas y roles ocultos.
4. Editor no-code: importación validada de imágenes/modelos, generador de fichas y mazos, zonas, lógica visual acotada y paquetes versionados.
5. Red: servidor autoritativo, bloqueos, reconexión, filtros de información privada y pruebas de latencia. El juego actual no es multijugador de red.
6. Steam: integración de plataforma, invitaciones, Workshop, licencias por copia y moderación; código de sala requiere un servicio compatible. Sin Friend Pass ni suscripción.
7. HUD completo, ajustes y accesibilidad, persistencia, localización, pruebas de rendimiento, seguridad y publicación; evaluación posterior de tablets.

El volumen de trabajo y las dependencias externas hacen que el GDD completo no equivalga a un único cambio ni a una función ya terminada.
