#!/usr/bin/env bash
# Shared UI helpers for scripts
# Usage: source this file, then call ui_init

ui_init() {
  set -Eeuo pipefail
  IFS=$'\n\t'
  SCRIPT_NAME="${SCRIPT_NAME:-$(basename "$0")}"
  START_TIME=$(date +%s)
  LOG_FILE="${LOG_FILE:-/tmp/${SCRIPT_NAME}-$(date +%Y%m%d_%H%M%S).log}"
  NO_COLOR=${NO_COLOR:-0}
  ASSUME_YES=${ASSUME_YES:-false}

  if [[ -t 1 && "$NO_COLOR" -ne 1 ]]; then
    UI_RED='\033[0;31m'; UI_GREEN='\033[0;32m'; UI_YELLOW='\033[0;33m'; UI_BLUE='\033[0;34m'; UI_BOLD='\033[1m'; UI_RESET='\033[0m'
  else
    UI_RED=''; UI_GREEN=''; UI_YELLOW=''; UI_BLUE=''; UI_BOLD=''; UI_RESET=''
  fi
  UI_INFO="ℹ️"; UI_OK="✅"; UI_WARN="⚠️"; UI_ERR="❌"; UI_RUN="🏃"

  trap 'ui_on_error $LINENO "$BASH_COMMAND"' ERR
  trap ui_on_exit EXIT
}

ui_timestamp() { date "+%H:%M:%S"; }
ui_log() { printf "%s %s %s\n" "$(ui_timestamp)" "$1" "$2" | tee -a "$LOG_FILE"; }
ui_info() { ui_log "$UI_INFO" "$*"; }
ui_success() { ui_log "$UI_OK" "$*"; }
ui_warn() { ui_log "$UI_WARN" "$*"; }
ui_error() { ui_log "$UI_ERR" "$*"; }

ui_on_error() {
  local exit_code=$?
  local line=$1 cmd=$2
  printf "%b\n" "${UI_RED}${UI_BOLD}${UI_ERR} Error (exit $exit_code) at line $line while running: $cmd${UI_RESET}" | tee -a "$LOG_FILE" >&2
}

ui_on_exit() {
  local ec=$?
  local end_time=$(date +%s)
  local duration=$(( end_time - START_TIME ))
  if [[ $ec -eq 0 ]]; then
    ui_success "Done in ${duration}s. Log: $LOG_FILE"
  else
    ui_warn "Exited with status $ec after ${duration}s. See log: $LOG_FILE"
  fi
}

ui_require_cmd() { command -v "$1" >/dev/null 2>&1 || { ui_error "Missing dependency: $1"; exit 1; }; }
ui_confirm() { if [[ "$ASSUME_YES" == true ]]; then return 0; fi; read -r -p "Proceed? [y/N] " reply; [[ "$reply" =~ ^[Yy]$ ]]; }
ui_rsync_available() { command -v rsync >/dev/null 2>&1; }
