#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/config/copy_resources.conf"

# Flags (no directory args; only behavior flags)
DRY_RUN=false
ASSUME_YES=${ASSUME_YES:-false}
NO_COLOR=${NO_COLOR:-0}
VERBOSE=${VERBOSE:-false}

usage() {
  cat <<EOF
copy_resources.sh - copy files using directories from scripts/config/copy_resources.conf

Flags:
  -n, --dry-run     Show actions without copying
  -y, --yes         Assume yes to confirmation
      --no-color    Disable colored output
  -v, --verbose     Verbose output
  -h, --help        Show this help
Edit directories in: $SCRIPT_DIR/config/copy_resources.conf
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) DRY_RUN=true; shift;;
      -y|--yes) ASSUME_YES=true; shift;;
      --no-color) NO_COLOR=1; shift;;
      -v|--verbose) VERBOSE=true; shift;;
      -h|--help) usage; exit 0;;
      *) ui_error "Unknown option: $1"; usage; exit 1;;
    esac
  done
}

get_rsync_progress_flag() {
  if rsync --info=progress2 --version >/dev/null 2>&1; then
    echo "--info=progress2"
  elif rsync --info=progress --version >/dev/null 2>&1; then
    echo "--info=progress"
  else
    echo "--progress"
  fi
}

copy_with_rsync() {
  local dry=""; [[ "$DRY_RUN" == true ]] && dry="--dry-run"
  ui_info "${UI_RUN} Using rsync with progress..."
  local progress_flag; progress_flag="$(get_rsync_progress_flag)"
  rsync -ah $dry "$progress_flag" --delete-after "${SOURCE_DIR%/}/" "${DEST_DIR%/}/"
}

copy_with_cp() {
  if [[ "$DRY_RUN" == true ]]; then
    ui_info "Would run: cp -Rv \"${SOURCE_DIR%/}/\"* \"${DEST_DIR%/}/\""
  else
    ui_info "${UI_RUN} Copying files (cp -Rv)..."
    cp -Rv "${SOURCE_DIR%/}/"* "${DEST_DIR%/}/"
  fi
}

main() {
  ui_init
  parse_args "$@"

  [[ -d "$SOURCE_DIR" ]] || { ui_error "Source does not exist: $SOURCE_DIR"; exit 1; }
  [[ -d "$DEST_DIR" ]] || { ui_info "Creating destination: $DEST_DIR"; [[ "$DRY_RUN" == true ]] || mkdir -p "$DEST_DIR"; }

  ui_info "Source: $SOURCE_DIR"
  ui_info "Destination: $DEST_DIR"
  if ! ui_confirm; then ui_warn "Aborted by user."; exit 130; fi

  if ui_rsync_available && [[ "$USE_RSYNC_DEFAULT" == true ]]; then
    copy_with_rsync
  else
    [[ "$USE_RSYNC_DEFAULT" == true ]] && ui_warn "rsync not found, falling back to cp"
    copy_with_cp
  fi
}

main "$@"
