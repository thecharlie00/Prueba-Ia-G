# Referencia de diseño: Tabletop Simulator

Se consultaron la documentación de controles de Tabletop Simulator y conversaciones públicas de jugadores. Son observaciones cualitativas, **no una encuesta representativa ni una clasificación estadística**. No se han reutilizado archivos, gráficos ni código del juego.

## Aspectos destacados

- La [guía oficial de controles](https://kb.tabletopsimulator.com/player-guides/basic-controls/) describe manipulación directa, volteo, inspección ampliada y selección de objetos. En [esta conversación de usuarios](https://www.reddit.com/r/tabletopsimulator/comments/hj121n/i_just_cant_figure_out_how_to_use_tabletop/) se destacan los atajos para girar, voltear, tirar y mezclar, pero también la necesidad de aprenderlos.
- En [esta conversación sobre alternativas a la mesa física](https://www.reddit.com/r/boardgames/comments/xcd5gv/is_tabletop_simulator_a_good_alternative_to/) se valoran el carácter táctil, las configuraciones automatizadas, guardar partidas largas y revertir errores; otros participantes critican controles difíciles y la limitación de visibilidad de la mesa. [Otra conversación](https://www.reddit.com/r/boardgames/comments/1rwlcrl/tabletop_simulator/) destaca la lectura de cartas, la preparación rápida y una interfaz consistente, junto con críticas a lo engorroso de la manipulación.
- Los mismos debates y [esta reseña](https://gnomestew.com/tabletop-simulator-review/) también destacan personalización, contenido de la comunidad y juego compartido. Son objetivos importantes, pero este prototipo **no implementa** todavía Workshop, importación general de contenidos, editor no-code ni multijugador.

## Aplicación en Dice on!!

- Se mantiene la interacción mediante cuerpos rígidos y fuerzas, con atajos para girar, voltear, lanzar y mezclar; la alternativa de dos clics evita mantener el botón pulsado.
- Las mesas libres permiten bloquear piezas con L para evitar desplazarlas accidentalmente. En sandbox y cartas el bloqueo se conserva al guardar; se excluyen los modos con reglas para no bloquear piezas controladas por el motor de juego.
- Mantener Alt sobre una pieza libre muestra una **inspección textual**, no una ampliación 3D. En cartas no muestra el valor si están boca abajo o en pleno volteo. No crea manos privadas y el guardado sigue siendo legible localmente.
- En la mesa manual de cartas, B devuelve la carta señalada al fondo de su baraja. Tres vistas de cámara temporales pueden guardarse y recuperarse con teclado o desde pausa.
- Guardados locales validados conservan una copia anterior y facilitan continuar una mesa; la copia no garantiza durabilidad ante cortes de energía ni concurrencia. Ver límites y controles en el [README](../README.md).

Estas herramientas necesitan aún pruebas manuales con renderizador, distintas resoluciones y personas jugando; no se presentan como equivalentes a todas las funciones de Tabletop Simulator.
