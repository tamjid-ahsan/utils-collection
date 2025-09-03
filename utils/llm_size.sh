#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
DEBUG=0

show_help() {
  cat <<'EOF'
llm_size.sh - Summarize disk usage of Ollama and LM Studio models.

Usage:
  ./llm_size.sh [OPTIONS]

Options:
  -v, --verbose   Show full `ollama ls` and `lms ls` output after summary.
  -d, --debug     Show internal parsing logs (matched tokens, byte counts).
  -h, --help      Show this help message.

Examples:
  ./llm_size.sh
      Print only a summary of total disk usage.

  ./llm_size.sh --verbose
      Show summary and the raw listings of Ollama and LM Studio models.

  ./llm_size.sh --debug
      Show summary plus detailed parsing debug information.

  ./llm_size.sh -v -d
      Show everything (summary, verbose listings, and debug).
EOF
}

for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    -d|--debug) DEBUG=1 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Run commands if present
OLLAMA_OUT="$({ command -v ollama >/dev/null 2>&1 && ollama ls || true; })"
LMSTUDIO_OUT="$({ command -v lms >/dev/null 2>&1 && lms ls || true; })"

# Humanize helper (uses 1024 base)
humanize() {
  awk -v b="${1:-0}" '
  function fmt(x,u){printf("%.2f %s", x, u); exit}
  BEGIN{
    if (b >= 1024^4) fmt(b/1024^4,"TB");
    else if (b >= 1024^3) fmt(b/1024^3,"GB");
    else if (b >= 1024^2) fmt(b/1024^2,"MB");
    else if (b >= 1024)   fmt(b/1024,"KB");
    else                   fmt(b,"B");
  }'
}

# Parser function
parse_blob() {
  local label="$1" ; shift
  local blob="$1"

  awk -v LABEL="$label" -v DBG="$DEBUG" '
  BEGIN{IGNORECASE=1; total=0; count=0}
  {
    line=$0
    gsub(/You have [0-9]+ models, taking up [0-9]+(\.[0-9]+)? [KMGT]i?B of disk space\./,"", line)
    rest=line
    while (match(rest, /[0-9]+(\.[0-9]+)? *[KMGT]i?B/)) {
      tok = substr(rest, RSTART, RLENGTH)
      num = tok; sub(/[^0-9.].*$/, "", num)
      unit = tok; sub(/^[0-9.]+ */, "", unit)
      if (unit ~ /^[Kk][Ii]?[Bb]$/)      mult = 1024
      else if (unit ~ /^[Mm][Ii]?[Bb]$/) mult = 1024*1024
      else if (unit ~ /^[Gg][Ii]?[Bb]$/) mult = 1024*1024*1024
      else if (unit ~ /^[Tt][Ii]?[Bb]$/) mult = 1024*1024*1024*1024
      else mult = 1
      bytes = num * mult
      total += bytes
      count += 1
      if (DBG) printf("DEBUG[%s]: token=\"%s\" num=%s unit=%s -> %.2f bytes\n", LABEL, tok, num, unit, bytes)
      rest = substr(rest, RSTART + RLENGTH)
    }
  }
  END{printf("PARSE_RESULT %s %d %.0f\n", LABEL, count, total)}
  ' <<< "$blob"
}

# Parse both outputs
OLLAMA_RES="$(parse_blob "Ollama" "$OLLAMA_OUT")"
LMSTUDIO_RES="$(parse_blob "LM-Studio" "$LMSTUDIO_OUT")"

# Extract results
read _ _ O_COUNT O_BYTES <<<"$(echo "$OLLAMA_RES" | awk '{print $1,$2,$3,$4}')"
read _ _ L_COUNT L_BYTES <<<"$(echo "$LMSTUDIO_RES" | awk '{print $1,$2,$3,$4}')"

TOTAL_BYTES=$(( ${O_BYTES:-0} + ${L_BYTES:-0} ))

TOTAL_HR="$(humanize "$TOTAL_BYTES")"
OLLAMA_HR="$(humanize "${O_BYTES:-0}")"
LMSTUDIO_HR="$(humanize "${L_BYTES:-0}")"

# Output summary
printf "Total Disk Space Used:\t%s\n" "$TOTAL_HR"
echo "----------------------------------"
printf "Ollama:\t\t%s models taking up %s of space\n" "${O_COUNT:-0}" "$OLLAMA_HR"
printf "LM-Studio:\t%s models taking up %s of space\n" "${L_COUNT:-0}" "$LMSTUDIO_HR"

# Verbose mode
if [ "$VERBOSE" -eq 1 ]; then
  echo "----------------------------------"
  echo "Ollama models:"
  echo "============"
  [ -n "$OLLAMA_OUT" ] && printf "%s\n\n" "$OLLAMA_OUT" || echo "(no output)"
  echo "LM-Studio models:"
  echo "============"
  [ -n "$LMSTUDIO_OUT" ] && printf "%s\n" "$LMSTUDIO_OUT" || echo "(no output)"
fi