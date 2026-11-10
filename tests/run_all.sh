#!/usr/bin/env bash
# Ejecuta todos los tests headless de tests/*.gd y resume el resultado.
# Uso: tests/run_all.sh [ruta_a_godot]   (por defecto: $GODOT o "godot")
# Sale con código 1 si algún test falla o supera el tiempo límite.
set -u

GODOT="${1:-${GODOT:-godot}}"
TIMEOUT="${TEST_TIMEOUT:-90}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${TEST_LOG_DIR:-$ROOT/.test-logs}"
mkdir -p "$LOG_DIR"

cd "$ROOT" || exit 1

echo "Importando recursos y registrando class_name..."
if ! timeout "$TIMEOUT" "$GODOT" --headless --editor --path . --quit >"$LOG_DIR/import.log" 2>&1; then
  echo "La importación del proyecto ha fallado; ver $LOG_DIR/import.log"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    msg="$(tail -n 10 "$LOG_DIR/import.log" | tr '\n' ' ' | sed 's/%/%25/g')"
    echo "::error title=import::${msg}"
  fi
  exit 1
fi

passed=0
failed=()
for test in tests/*.gd; do
  name="$(basename "$test" .gd)"
  start=$(date +%s)
  timeout "$TIMEOUT" "$GODOT" --headless --path . --script "res://$test" >"$LOG_DIR/$name.log" 2>&1
  code=$?
  secs=$(( $(date +%s) - start ))
  # Un test que no llama a quit(1) pero imprime un error de script también cuenta como fallo.
  if [ "$code" -eq 0 ] && grep -qE '^(SCRIPT ERROR|ERROR):' "$LOG_DIR/$name.log"; then
    code=99
  fi
  if [ "$code" -eq 0 ]; then
    passed=$((passed + 1))
    printf 'ok    %-32s %4ss\n' "$name" "$secs"
  else
    failed+=("$name")
    printf 'FALLO %-32s %4ss (código %s)\n' "$name" "$secs" "$code"
    tail -n 15 "$LOG_DIR/$name.log" | sed 's/^/      /'
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
      msg="$(grep -E '^(SCRIPT ERROR|ERROR|FALLO)|at: ' "$LOG_DIR/$name.log" | head -n 6 | tr '\n' ' ' | sed 's/%/%25/g')"
      if [ -z "$msg" ]; then
        msg="$(tail -n 6 "$LOG_DIR/$name.log" | tr '\n' ' ' | sed 's/%/%25/g')"
      fi
      echo "::error title=FALLO $name (${secs}s, code $code)::${msg}"
    fi
  fi
done

echo
echo "Resultado: $passed correctos, ${#failed[@]} fallidos."
if [ "${#failed[@]}" -gt 0 ]; then
  printf '  - %s\n' "${failed[@]}"
  exit 1
fi
