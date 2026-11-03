"""Genera posiciones para damas inglesas con blancas primero.

Solo para desarrollo: pip install pydraughts==0.6.7
Ejecutar: python tests/tools/generate_checkers_reference.py
Compara los primeros saltos/pasos posibles; el resto de la cadena se prueba aparte.
"""

import json
from pathlib import Path
import random

import draughts

INITIAL = "W:W21,22,23,24,25,26,27,28,29,30,31,32:B1,2,3,4,5,6,7,8,9,10,11,12"


def index(number: int) -> int:
    row, column = divmod(number - 1, 4)
    x = 2 * column + (1 if row % 2 == 0 else 0)
    return row * 8 + x


def main() -> None:
    rng = random.Random(1729)
    vectors = []
    for _ in range(12):
        board = draughts.Board(variant="english", fen=INITIAL)
        for step in range(72):
            moves = board.legal_moves()
            if not moves:
                break
            if step % 4 == 0:
                # El FEN de pydraughts enumera cada ficha como número o K+número.
                fen = board.fen
                parts = fen.split(":")
                pieces = [0] * 64
                for group in parts[1:]:
                    side = 1 if group[0] == "W" else -1
                    for token in group[1:].split(","):
                        if not token:
                            continue
                        king = token.startswith("K")
                        number = int(token[1:] if king else token)
                        pieces[index(number)] = side * (2 if king else 1)
                legal = sorted({f"{index(m.board_move[0][0])}-{index(m.board_move[0][1])}" for m in moves})
                turn = 1 if parts[0] == "W" else -1
                vectors.append({"board": pieces, "turn": turn, "legal": legal, "fen": fen})
                # Una secuencia completa del referente se divide en saltos individuales.
                prefixes = set()
                for move in moves:
                    steps = tuple(tuple(pair) for pair in move.board_move)
                    for length in range(1, len(steps)):
                        prefixes.add(steps[:length])
                for prefix in sorted(prefixes):
                    intermediate = pieces.copy()
                    for source, destination in prefix:
                        a, b = index(source), index(destination)
                        middle = ((a // 8 + b // 8) // 2) * 8 + ((a % 8 + b % 8) // 2)
                        intermediate[b] = intermediate[a]
                        intermediate[a] = 0
                        intermediate[middle] = 0
                    possible = sorted({
                        f"{index(m.board_move[len(prefix)][0])}-{index(m.board_move[len(prefix)][1])}"
                        for m in moves
                        if tuple(tuple(pair) for pair in m.board_move[:len(prefix)]) == prefix
                        and len(m.board_move) > len(prefix)
                    })
                    vectors.append({
                        "board": intermediate, "turn": turn, "forced_from": index(prefix[-1][1]),
                        "legal": possible, "fen": fen + " prefix=" + str(prefix),
                    })
            board.push(rng.choice(moves))
    path = Path(__file__).resolve().parent.parent / "fixtures" / "checkers_reference.json"
    with path.open("w", encoding="utf-8") as file:
        file.write("[\n")
        for i, vector in enumerate(vectors):
            file.write("  " + json.dumps(vector, separators=(",", ":")) + ("," if i < len(vectors) - 1 else "") + "\n")
        file.write("]\n")
    print(f"{len(vectors)} posiciones escritas en {path}")


if __name__ == "__main__":
    main()
