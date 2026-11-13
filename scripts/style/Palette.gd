class_name Palette
extends RefCounted
## Paleta común (docs/ARTE.md): tonos de arcilla, cálidos y algo apagados, con los colores de
## jugador como único acento vivo. Cualquier color de juego sale de aquí.

const INK := Color("1d1a3a")
const SKY := Color("cfe1ee")
const AMBIENT := Color("ece7f3")
const SUNLIGHT := Color("fff1d9")
const FLOOR := Color("c2a27e")  # Suelo de madera clara de la habitación.
const WOOD := Color("a67c56")
const FELT := Color("4f9c84")
const PANEL := Color("2a2552")
const PAPER := Color("fff8ec")
const SUN := Color("ffc83d")
const SUN_LIGHT := Color("ffd96e")
const MUTED := Color("8b87b3")
const LAVENDER := Color("c9c5ef")
const CORAL := Color("ff6b5e")
const MINT := Color("4fd6a0")

## Tableros de ajedrez y damas.
const BOARD_LIGHT := Color("fff1d9")
const BOARD_DARK := Color("7584c4")
const SELECTED := SUN
const LEGAL := MINT

## Piezas de dos bandos (ajedrez, damas).
const PIECE_LIGHT := Color("f3e6cc")
const PIECE_DARK := Color("4b4682")

## Colores de jugador, en orden J1..J4 (rojo, azul, naranja, blanco/amarillo según el juego).
const PLAYER_RED := Color("ee6f60")
const PLAYER_BLUE := Color("5a8ae8")
const PLAYER_GREEN := Color("58c08f")
const PLAYER_YELLOW := Color("f5c549")
const PLAYER_ORANGE := Color("f09a50")
const PLAYER_WHITE := Color("f3e6cc")
