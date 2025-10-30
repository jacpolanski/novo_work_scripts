#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/config/set_machine_ip_linux.conf"

DRY_RUN=false
ASSUME_YES=${ASSUME_YES:-false}
NO_COLOR=${NO_COLOR:-0}

usage() { cat <<EOF
set_machine_ip_linux.sh - updates config files using directories from config/set_machine_ip_linux.conf

Flags:
  -n, --dry-run     Show changes without writing
  -y, --yes         Assume yes to prompts
      --no-color    Disable colored output
  -h, --help        Show this help
Edit directories in: $SCRIPT_DIR/config/set_machine_ip_linux.conf
Optionally set NEW_IP in the config to skip interactive selection.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) DRY_RUN=true; shift;;
      -y|--yes) ASSUME_YES=true; shift;;
      --no-color) NO_COLOR=1; shift;;
      -h|--help) usage; exit 0;;
      *) ui_error "Unknown option: $1"; usage; exit 1;;
    esac
  done
}

sed_inplace() { local expr="$1" file="$2"; if sed --version >/dev/null 2>&1; then sed -i "$expr" "$file"; else sed -i '' "$expr" "$file"; fi }

select_ip_interactive() { echo "Select a new machine IP:"; select choice in "${PRESET_VALUES[@]}"; do [[ -n "$choice" ]] && { NEW_IP="$choice"; break; } || echo "Invalid selection"; done; }

main() {
  ui_init; ui_require_cmd jq; ui_require_cmd sed
  parse_args "$@"

  if [[ -z "${NEW_IP:-}" ]]; then select_ip_interactive; else ui_info "Using IP from config: $NEW_IP"; fi
  ui_info "JSON: $JSON_FILE"; ui_info "ATT: $ATT_JS_FILE"; ui_info "HIST: $GH_JS_FILE"
  if ! ui_confirm; then ui_warn "Aborted by user."; exit 130; fi

  if [[ "$DRY_RUN" == true ]]; then ui_info "Would update JSON and JS files"; exit 0; fi

  [[ -f "$JSON_FILE" ]] || { ui_error "Not found: $JSON_FILE"; exit 1; }
  jq --arg ip "$NEW_IP" '.apiUri = "http://"+$ip+":1074" | .hotfireUri = "http://"+$ip+":1090/v1"' "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"

  [[ -f "$ATT_JS_FILE" ]] || { ui_error "Not found: $ATT_JS_FILE"; exit 1; }
  sed_inplace "s|API_URL_DEV: .*|API_URL_DEV: 'http://$NEW_IP:1090/v1',|" "$ATT_JS_FILE"
  sed_inplace "s|GAME_HISTORY_API_URL_DEV: .*|GAME_HISTORY_API_URL_DEV: 'http://$NEW_IP:1097/v1',|" "$ATT_JS_FILE"

  [[ -f "$GH_JS_FILE" ]] || { ui_error "Not found: $GH_JS_FILE"; exit 1; }
  sed_inplace "s|API_URL_DEV: .*|API_URL_DEV: 'http://$NEW_IP:1097/v1',|" "$GH_JS_FILE"

  ui_success "All files updated for $NEW_IP"
}

main "$@"
