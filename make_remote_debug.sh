#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/config/make_remote_dev_tools.conf"

DRY_RUN=false
ASSUME_YES=${ASSUME_YES:-false}
NO_COLOR=${NO_COLOR:-0}
REVERT=false

# SSH connection multiplexing to avoid multiple password prompts
SSH_CTL_DIR="${SSH_CTL_DIR:-$HOME/.ssh/ctl}"
SSH_CONTROL_PERSIST="${SSH_CONTROL_PERSIST:-10m}"
SSH_CONTROL_PATH="$SSH_CTL_DIR/%r@%h:%p"
SSH_OPTS=(
  -o ControlMaster=auto
  -o ControlPersist="$SSH_CONTROL_PERSIST"
  -o ControlPath="$SSH_CONTROL_PATH"
  -o StrictHostKeyChecking=no
)

usage() { cat <<EOF
make_remote_debug.sh - configures remote CEF debug based on config/make_remote_dev_tools.conf

Flags:
  -n, --dry-run     Show commands without executing
  -y, --yes         Assume yes to prompts
  -r, --revert      Revert remote debug changes (remove flag and restart service)
      --no-color    Disable colored output
  -h, --help        Show this help
Edit values in: $SCRIPT_DIR/config/make_remote_dev_tools.conf
Notes: Uses SSH connection multiplexing to reuse a single connection for all steps (one SSH password prompt). Also primes remote sudo credentials once.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) DRY_RUN=true; shift;;
      -y|--yes) ASSUME_YES=true; shift;;
      -r|--revert) REVERT=true; shift;;
      --no-color) NO_COLOR=1; shift;;
      -h|--help) usage; exit 0;;
      *) ui_error "Unknown option: $1"; usage; exit 1;;
    esac
  done
}

ssh_run() {
  local cmd="$1"
  if [[ "$DRY_RUN" == true ]]; then
    ui_info "Would run on $REMOTE_TARGET: $cmd"
  else
    ssh -t "${SSH_OPTS[@]}" "$REMOTE_TARGET" "$cmd"
  fi
}

ssh_warmup() {
  mkdir -p "$SSH_CTL_DIR"
  ssh "${SSH_OPTS[@]}" "$REMOTE_TARGET" true || true
}

ssh_close() {
  ssh -O exit "${SSH_OPTS[@]}" "$REMOTE_TARGET" >/dev/null 2>&1 || true
}

main() {
  ui_init; ui_require_cmd ssh
  parse_args "$@"
  [[ -n "$REMOTE_TARGET" ]] || { ui_error "REMOTE_TARGET is empty in config"; exit 1; }
  ui_info "Target: $REMOTE_TARGET"; ui_info "Service file: $SERVICE_FILE"; ui_info "Debug option: $DEBUG_OPTION"; ui_info "GMS service: $GMS_SERVICE"
  if ! ui_confirm; then ui_warn "Aborted by user."; exit 130; fi

  # Warm up a master connection so subsequent commands don't prompt again
  if [[ "$DRY_RUN" != true ]]; then ssh_warmup; fi
  # Prime sudo credential cache so subsequent sudo commands don't re-prompt during this run
  if [[ "$DRY_RUN" != true ]]; then ssh_run "sudo -v"; fi

  if [[ "$REVERT" == true ]]; then
    ui_info "Stopping $GMS_SERVICE"; ssh_run "sudo systemctl stop $GMS_SERVICE"
    ui_info "Reverting remote debug configuration in $SERVICE_FILE"
    # Remove exact flag if present, otherwise remove any --remote-debugging-port=NNNN, otherwise restore from .bak if available
    ssh_run "if grep -q '${DEBUG_OPTION}' '${SERVICE_FILE}'; then echo '🔧 Removing exact debug flag'; sudo sed -i 's/ ${DEBUG_OPTION}//' '${SERVICE_FILE}'; \
             elif grep -Eq -- '--remote-debugging-port=[0-9]+' '${SERVICE_FILE}'; then echo '🔧 Removing generic remote-debug flag'; sudo sed -i -E 's/ --remote-debugging-port=[0-9]+//g' '${SERVICE_FILE}'; \
             elif [ -f '${SERVICE_FILE}.bak' ]; then echo '🗂 Restoring backup ${SERVICE_FILE}.bak'; sudo cp '${SERVICE_FILE}.bak' '${SERVICE_FILE}'; \
             else echo 'ℹ️ No debug flag found and no backup to restore.'; fi"
    ui_info "Reloading systemd"; ssh_run "sudo systemctl daemon-reload"
    ui_info "Starting $GMS_SERVICE"; ssh_run "sudo systemctl start $GMS_SERVICE"
    ui_success "Remote debug changes reverted"
  else
    ui_info "Stopping $GMS_SERVICE"; ssh_run "sudo systemctl stop $GMS_SERVICE"
    ui_info "Patching $SERVICE_FILE with $DEBUG_OPTION if missing"; ssh_run "if grep -q '${DEBUG_OPTION}' '${SERVICE_FILE}'; then echo '✅ Already configured'; else sudo sed -i.bak '/^ExecStart=/ s/$/ ${DEBUG_OPTION}/' '${SERVICE_FILE}'; fi"
    ui_info "Reloading systemd"; ssh_run "sudo systemctl daemon-reload"
    ui_info "Starting $GMS_SERVICE"; ssh_run "sudo systemctl start $GMS_SERVICE"

    ui_success "Remote configuration complete"
    printf "%s\n" "To forward port locally (in a new terminal):"
    printf "%s\n" "  ssh -N -L localhost:${REMOTE_DEBUG_PORT}:localhost:${REMOTE_DEBUG_PORT} $REMOTE_TARGET"
    printf "%s\n" "Then open http://localhost:${REMOTE_DEBUG_PORT} in Chrome"
  fi

  # Close master connection (optional; otherwise persists for SSH_CONTROL_PERSIST duration)
  if [[ "$DRY_RUN" != true ]]; then ssh_close; fi
}

main "$@"
