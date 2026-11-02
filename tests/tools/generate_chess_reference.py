"""Regenera los fixtures de movimientos con python-chess (dependencia opcional de desarrollo).

Uso: python -m pip install python-chess==1.999
     python tests/tools/generate_chess_reference.py
La salida se fija con la semilla y contiene pares origen/destino, no tipos de promoción.
"""

import json
from pathlib import Path
import random

import chess


def main() -> None:
    rng = random.Random(1532)
    vectors = []
    for _ in range(15):
        board = chess.Board()
        for step in range(70):
            if board.is_game_over():
                break
            if step % 5 == 0:
                pieces = []
                for y in range(8):
                    for x in range(8):
                        piece = board.piece_at(chess.square(x, 7 - y))
                        pieces.append(0 if piece is None else piece.piece_type * (1 if piece.color else -1))

                def index(square: int) -> int:
                    return (7 - chess.square_rank(square)) * 8 + chess.square_file(square)

                legal = sorted({f"{index(move.from_square)}-{index(move.to_square)}" for move in board.legal_moves})
                vectors.append(
                    {
                        "board": pieces,
                        "turn": 1 if board.turn else -1,
                        "castling": {
                            "wk": board.has_kingside_castling_rights(chess.WHITE),
                            "wq": board.has_queenside_castling_rights(chess.WHITE),
                            "bk": board.has_kingside_castling_rights(chess.BLACK),
                            "bq": board.has_queenside_castling_rights(chess.BLACK),
                        },
                        "ep": -1 if board.ep_square is None else index(board.ep_square),
                        "legal": legal,
                        "fen": board.fen(),
                    }
                )
            board.push(rng.choice(list(board.legal_moves)))
    path = Path(__file__).resolve().parent.parent / "fixtures" / "chess_reference.json"
    with path.open("w", encoding="utf-8") as file:
        file.write("[\n")
        for i, vector in enumerate(vectors):
            file.write("  " + json.dumps(vector, separators=(",", ":")) + ("," if i < len(vectors) - 1 else "") + "\n")
        file.write("]\n")
    print(f"{len(vectors)} posiciones escritas en {path}")


if __name__ == "__main__":
    main()
