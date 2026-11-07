# Prueba con personas · cierre de la fase 0

Condición de salida de la fase 0 ([ROADMAP.md](ROADMAP.md)): **3 personas ajenas al proyecto completan una partida de cada modo sin bloqueos.** Todo lo demás de la fase ya está comprobado automáticamente (ver «Qué está comprobado ya»); esta prueba es lo único que necesita personas.

## Preparación (10 minutos)

1. Descarga la compilación de la última ejecución de CI en verde (artefacto `Tablerama-windows`, `Tablerama-linux` o `Tablerama-macos`) o expórtala con Godot 4.7.1.
2. Antes de empezar, comprueba que arranca: `Tablerama.exe -- --prueba-arranque` (o `./Tablerama.x86_64 -- --prueba-arranque`). Debe terminar con «PRUEBA DE ARRANQUE: correcta».
3. Borra los ajustes anteriores para que la persona vea el tutorial: elimina `diceon_controls.cfg` de la carpeta de datos de Godot del usuario (`%APPDATA%\Godot\app_userdata\Tablerama` en Windows, `~/.local/share/godot/app_userdata/Tablerama` en Linux).
4. Ten a mano una copia de la hoja de observación (abajo) por persona.

## Reglas para quien observa

- No expliques nada antes de empezar. Si la persona pregunta, contesta «¿qué harías tú?» y apúntalo.
- Solo intervienes si lleva **2 minutos atascada**: eso cuenta como **bloqueo**.
- Pide que piense en voz alta.
- F3 abre el medidor de rendimiento: si nota tirones, haz una captura del recuadro.

## Recorrido (unos 60 minutos por persona)

| # | Modo | Qué tiene que hacer | Cuenta como completado |
|---|---|---|---|
| 1 | Tutorial jugable | Seguir los 9 pasos | Llega a «¡Ya sabes jugar!» |
| 2 | Mesa libre | Tirar un dado, robar una carta, voltearla, guardar y cargar la mesa | La mesa cargada es la guardada |
| 3 | Ajedrez físico con reglas | Partida contra la IA casual | Mate, tablas o abandono consciente |
| 4 | Damas físicas con reglas | Partida contra el bot | Gana alguien |
| 5 | Dominó con reglas | Partida contra el bot | Gana alguien o cierre por puntos |
| 6 | Ludo (2 jugadores) | Partida contra un bot | Gana alguien |
| 7 | Isla de recursos (3 jugadores) | 3 rondas completas en el mismo equipo (puede ser con otras dos personas) | Tres vueltas de turno sin bloqueo |
| 8 | Mesa de cartas | Mezclar, robar a la mano, jugar una carta, apilar dos cartas | Se forma un mazo nuevo |
| 9 | Pausa y salida | En cualquier mesa: Esc, «Volver al menú principal», confirmar | Vuelve al menú |

## Hoja de observación (una por persona)

```
Persona: ____  Equipo y sistema: __________________  Ratón / panel / mando: ______

#  Completado (sí/no)  Bloqueos (≥2 min) y dónde      Dudas o comentarios        Tiempo
1
2
3
4
5
6
7
8
9

Tirones (captura F3):
Lo mejor:
Lo peor:
¿Lo recomendarías? (0–10):
```

## Cómo se decide

- **Fase 0 cerrada** si las 3 personas completan los 9 puntos con **0 bloqueos** en total.
- Cada bloqueo se convierte en una incidencia en GitHub con la etiqueta `beta-local` y se repite la prueba de ese modo con una persona nueva tras arreglarlo.
- Las dudas que no llegan a bloqueo van a la lista de mejoras de la fase 2 (tutorial, atajos, textos).

## Qué está comprobado ya (automático)

- **Partidas completas** en cada modo con reglas (`tests/playthroughs.gd`): ajedrez (200 jugadas con capturas y una partida hasta el mate), damas, dominó, ludo e isla de recursos hasta que gana alguien, con la física y las vistas reales. Al final cada pieza está donde dice el estado lógico (desvío máximo 0,15 en el dominó y menos de 0,03 en el resto).
- **Pausa y salida al menú** en 12 mesas.
- **Revisión visual** con renderizador real (OpenGL por software) de las 16 escenas a 1280×720 y 1024×600 (`tools/review_shots.gd`).
- **Exportaciones**: Linux arranca y abre las 16 escenas (`-- --prueba-arranque`, también en CI); Windows exportado y probado con wine; macOS solo se exporta (sin equipo para probarlo).
- **Guardados**: escritura atómica con copia anterior (`tests/atomic_save.gd` y los tests de cada juego).

## Lo que no se puede comprobar sin personas ni equipos reales

- Si los controles se entienden a la primera.
- Rendimiento con tarjetas gráficas reales (60 FPS en gráficos integrados, objetivo de la fase 1) y el tirón del dado que se vio en Windows.
- macOS en un Mac de verdad y la Steam Deck.
