#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
OLLAMA_MODELS=(
  "gpt-oss:20b"
  "qwen2.5-coder:7b"
  "qwen2.5-coder:1.5b"
  "qwen3:8b"
  "gemma3:4b"
  "deepseek-r1:latest"
)

LMS_MODELS=(
  "deepseek-r1-distill-llama-8b"
)

# ::: CHECK THIS:::
LMS_MODELS_DIR_DEFAULT="${HOME}/.lmstudio/models"
LMS_MODELS_DIR="${LMS_MODELS_DIR:-$LMS_MODELS_DIR_DEFAULT}"

LLM_SIZE_SCRIPT_DEFAULT="/mnt/data/llm_size.sh"
LLM_SIZE_SCRIPT="${LLM_SIZE_SCRIPT:-$LLM_SIZE_SCRIPT_DEFAULT}"
# ::::::

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; BLU=$'\033[34m'; RST=$'\033[0m'

log()   { printf "%s\n" "$*"; }
info()  { printf "%s[INFO]%s %s\n" "$BLU" "$RST" "$*"; }
ok()    { printf "%s[OK]%s   %s\n" "$GRN" "$RST" "$*"; }
warn()  { printf "%s[WARN]%s %s\n" "$YLW" "$RST" "$*"; }
err()   { printf "%s[ERR]%s  %s\n" "$RED" "$RST" "$*"; }
die() { err "$*"; exit 1; }

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Missing command: $1"
  fi
}

confirm() {
  local prompt="${1:-Proceed?}"
  local reply
  printf "%s [y/N]: " "$prompt"
  read -r reply || true
  [[ "${reply:-}" =~ ^[Yy]$ ]]
}

# ===== Actions =====

list_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    info "Ollama models:"
    ollama list || ollama ls || true
  else
    warn "ollama not found; skipping list"
  fi
}

list_lms() {
  if command -v lms >/dev/null 2>&1; then
    info "LM Studio models:"
    lms ls || true
  else
    warn "lms not found; skipping list"
  fi
}

pull_ollama() {
  need ollama
  local models=("$@")
  info "Starting parallel pulls for Ollama models (${#models[@]})..."
  for m in "${models[@]}"; do
    (
      info "Pulling Ollama model: ${m}"
      if ollama pull "$m"; then
        ok "Pulled ${m}"
      else
        err "Failed to pull ${m}"
      fi
    ) &
  done
  wait
  ok "All Ollama pulls finished"
}

pull_lms() {
  need lms
  local models=("$@")
  info "Starting parallel pulls for LM Studio models (${#models[@]})..."
  for m in "${models[@]}"; do
    (
      info "Downloading LM Studio model: ${m}"
      if lms get "$m"; then
        ok "Downloaded ${m}"
      else
        err "Failed to download ${m}"
      fi
    ) &
  done
  wait
  ok "All LM Studio pulls finished"
}

rm_ollama() {
  need ollama
  local -a targets=("$@")
  info "Planned Ollama removals:"
  printf '  - %s\n' "${targets[@]}"
  if [[ "${ASSUME_YES:-0}" -ne 1 ]] && ! confirm "Remove these Ollama models?"; then
    warn "Cancelled Ollama removal"
    return 0
  fi
  for m in "${targets[@]}"; do
    info "Removing Ollama model: ${m}"
    ollama rm "$m" || warn "Failed to remove ${m}"
  done
  ok "Ollama removal complete"
}

rm_lms() {
  local -a tokens=("$@")
  [[ -d "$LMS_MODELS_DIR" ]] || die "LM Studio models dir not found: ${LMS_MODELS_DIR}"
  info "LM Studio models dir: ${LMS_MODELS_DIR}"
  local -a paths=()
  local t p
  for t in "${tokens[@]}"; do
    mapfile -t p < <(find "$LMS_MODELS_DIR" -maxdepth 3 -type d -iname "*${t}*" 2>/dev/null | sort)
    paths+=("${p[@]}")
  done

  if [[ "${#paths[@]}" -eq 0 ]]; then
    warn "Nothing to remove for LM Studio"
    return 0
  fi

  info "Planned LM Studio removals:"
  printf '  - %s\n' "${paths[@]}"

  if [[ "${ASSUME_YES:-0}" -ne 1 ]] && ! confirm "Recursively delete these directories?"; then
    warn "Cancelled LM Studio removal"
    return 0
  fi

  for path in "${paths[@]}"; do
    if [[ -d "$path" ]]; then
      info "Deleting: $path"
      rm -rf "$path"
    fi
  done
  ok "LM Studio removal complete"
}

show_sizes() {
  if [[ -x "$LLM_SIZE_SCRIPT" ]]; then
    info "Running size report: $LLM_SIZE_SCRIPT"
    "$LLM_SIZE_SCRIPT"
  elif [[ -f "$LLM_SIZE_SCRIPT" ]]; then
    warn "Size script exists but is not executable: $LLM_SIZE_SCRIPT"
  else
    warn "Size script not found at $LLM_SIZE_SCRIPT"
  fi
}

usage() {
  cat <<'EOF'
Usage: manage_llms.sh [FLAGS] [--] [MODEL ...]

Flags:
  --list            List models for Ollama and LM Studio
  --pull            Pull default sets (parallel for Ollama and LM Studio)
  --pull-ollama     Pull only Ollama defaults (parallel)
  --pull-lms        Pull only LM Studio defaults (parallel)
  --rm              Remove models by name for both tools (provide MODEL tokens)
  --rm-ollama       Remove Ollama models (exact tags)
  --rm-lms          Remove LM Studio models (fuzzy match)
  --sizes           Run size report script
  --yes             Do not prompt on destructive actions
  --print-config    Show config values
  --help            Show this help
EOF
}

print_config() {
  cat <<EOF
Config:
  LMS_MODELS_DIR=${LMS_MODELS_DIR}
  LLM_SIZE_SCRIPT=${LLM_SIZE_SCRIPT}
  Default Ollama models: ${OLLAMA_MODELS[*]}
  Default LM Studio models: ${LMS_MODELS[*]}
EOF
}

main() {
  if [[ $# -eq 0 ]]; then usage; exit 0; fi
  local MODE_LIST=0 MODE_PULL=0 MODE_PULL_OLLAMA=0 MODE_PULL_LMS=0
  local MODE_RM=0 MODE_RM_OLLAMA=0 MODE_RM_LMS=0 MODE_SIZES=0
  ASSUME_YES=0
  declare -a ARGS_MODELS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list) MODE_LIST=1; shift ;;
      --pull) MODE_PULL=1; shift ;;
      --pull-ollama) MODE_PULL_OLLAMA=1; shift ;;
      --pull-lms) MODE_PULL_LMS=1; shift ;;
      --rm) MODE_RM=1; shift ;;
      --rm-ollama) MODE_RM_OLLAMA=1; shift ;;
      --rm-lms) MODE_RM_LMS=1; shift ;;
      --sizes) MODE_SIZES=1; shift ;;
      --yes) ASSUME_YES=1; shift ;;
      --print-config) print_config; exit 0 ;;
      --help|-h) usage; exit 0 ;;
      --) shift; ARGS_MODELS+=("$@"); break ;;
      *) ARGS_MODELS+=("$1"); shift ;;
    esac
  done

  [[ $MODE_LIST -eq 1 ]] && { list_ollama; list_lms; }
  [[ $MODE_PULL -eq 1 || $MODE_PULL_OLLAMA -eq 1 ]] && pull_ollama "${OLLAMA_MODELS[@]}"
  [[ $MODE_PULL -eq 1 || $MODE_PULL_LMS -eq 1 ]] && pull_lms "${LMS_MODELS[@]}"
  [[ $MODE_RM -eq 1 || $MODE_RM_OLLAMA -eq 1 ]] && rm_ollama "${ARGS_MODELS[@]}"
  [[ $MODE_RM -eq 1 || $MODE_RM_LMS -eq 1 ]] && rm_lms "${ARGS_MODELS[@]}"
  [[ $MODE_SIZES -eq 1 ]] && show_sizes
}

main "$@"
