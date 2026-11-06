#!/usr/bin/env bash
# Captura varias escenas con renderizador real (xvfb + OpenGL por software).
# Uso: tools/shots.sh <carpeta_salida> [godot] [escenas...]
set -u
OUT="$1"; GODOT="${2:-godot}"; shift 2 || shift $#
SCENES=("$@"); [ ${#SCENES[@]} -eq 0 ] && SCENES=(Menu Main Chess GuidedPhysicalChess Checkers Ludo4 Island CardTable GuidedDomino)
cd "$(dirname "$0")/.." && mkdir -p "$OUT"
"$GODOT" --headless --editor --path . --quit >/dev/null 2>&1
for sc in "${SCENES[@]}"; do
  xvfb-run -a -s "-screen 0 1280x720x24" timeout 120 "$GODOT" --path . --resolution 1280x720 \
    --rendering-driver opengl3 --script res://tools/screenshot.gd -- "res://scenes/$sc.tscn" "$OUT/$sc.png" 120 >"$OUT/$sc.log" 2>&1
  echo "$sc $?"
done
