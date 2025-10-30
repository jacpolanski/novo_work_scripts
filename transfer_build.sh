#!/usr/bin/env bash
set -Eeuo pipefail
# Re-exec with bash if run under sh or another shell
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/config/transfer_build.conf"

DRY_RUN=false
ASSUME_YES=${ASSUME_YES:-false}

copy_pair_tar_pv() {
  local src="$1" dest="$2"
  local size_bytes
  size_bytes=$(calc_size_bytes "$src")
  ui_info "${UI_RUN} tar+pv: $src -> $dest"
  if [[ "$DRY_RUN" == true ]]; then
    ui_info "Would stream tar | pv -s $size_bytes bytes to $USER_NAME@$SERVER:$dest"
    return 0
  fi
  # Clean destination contents to emulate rsync --delete behavior
  remote "mkdir -p '$dest' && find '${dest%/}' -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
  # Stream with a progress bar
  # On macOS (bsdtar/libarchive), suppress mac metadata/xattrs to avoid noisy LIBARCHIVE.xattr.* warnings on GNU tar
  if tar --version 2>&1 | grep -qiE 'bsdtar|libarchive'; then
    (cd "$src" && env COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs --no-acls --no-fflags -cf - .) \
      | pv -s "$size_bytes" \
      | ssh "${SSH_ARGS[@]}" -T "$USER_NAME@$SERVER" "tar --no-same-owner -C '$dest' -xf -"
  else
    (cd "$src" && tar -cf - .) \
      | pv -s "$size_bytes" \
      | ssh "${SSH_ARGS[@]}" -T "$USER_NAME@$SERVER" "tar --no-same-owner -C '$dest' -xf -"
  fi
}
NO_COLOR=${NO_COLOR:-0}
VERBOSE=${VERBOSE:-false}

# SSH multiplexing control vars
SSH_CTL_DIR="${SSH_CTL_DIR:-$HOME/.ssh/ctl}"
SSH_CONTROL_PERSIST="${SSH_CONTROL_PERSIST:-10m}"
SSH_CONTROL_PATH="$SSH_CTL_DIR/%r@%h:%p"

usage() { cat <<EOF
transfer_build.sh - deploys build artifacts to remote using config from scripts/config/transfer_build.conf

Flags:
  -n, --dry-run     Show actions without copying
  -y, --yes         Assume yes to confirmation
      --no-color    Disable colored output
  -v, --verbose     Verbose output
  -h, --help        Show this help
Edit directories in: $SCRIPT_DIR/config/transfer_build.conf
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

# Determine best rsync progress flag depending on local rsync version
rsync_progress_opt() {
  if rsync --info=progress2 --version >/dev/null 2>&1; then
    printf -- "--info=progress2"
  else
    printf -- "--progress"
  fi
}

# Build SSH/SCP options as arrays to avoid IFS word-splitting issues
SSH_ARGS=(
  -p "$PORT"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password,keyboard-interactive
  -o KbdInteractiveAuthentication=yes
  -o NumberOfPasswordPrompts=1
  -o GSSAPIAuthentication=no
  -o ControlMaster=auto
  -o ControlPersist="$SSH_CONTROL_PERSIST"
  -o ControlPath="$SSH_CONTROL_PATH"
)
SCP_ARGS=(
  -P "$PORT"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password,keyboard-interactive
  -o KbdInteractiveAuthentication=yes
  -o GSSAPIAuthentication=no
  -o ControlMaster=auto
  -o ControlPersist="$SSH_CONTROL_PERSIST"
  -o ControlPath="$SSH_CONTROL_PATH"
)
# For rsync, -e expects a single string, so compose it explicitly
RSYNC_SSH="ssh -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive -o KbdInteractiveAuthentication=yes -o NumberOfPasswordPrompts=1 -o GSSAPIAuthentication=no -o ControlMaster=auto -o ControlPersist=$SSH_CONTROL_PERSIST -o ControlPath=$SSH_CONTROL_PATH"

remote() {
  local cmd="$1"
  if [[ "$DRY_RUN" == true ]]; then
    ui_info "Would run on $USER_NAME@$SERVER: $cmd"
  else
    ssh "${SSH_ARGS[@]}" "$USER_NAME@$SERVER" "$cmd"
  fi
}

# Check if rsync exists on the remote host (uses existing master connection)
remote_rsync_available() {
  ssh "${SSH_ARGS[@]}" "$USER_NAME@$SERVER" 'command -v rsync >/dev/null 2>&1'
}

# Check if tar exists on the remote host
remote_tar_available() {
  ssh "${SSH_ARGS[@]}" "$USER_NAME@$SERVER" 'command -v tar >/dev/null 2>&1'
}

pv_available() { command -v pv >/dev/null 2>&1; }

calc_size_bytes() {
  # du -sk returns size in KiB; multiply by 1024 to bytes
  local p="$1"
  local kib
  kib=$(du -sk "$p" 2>/dev/null | awk '{print $1}') || kib=0
  if [[ -z "$kib" || "$kib" -eq 0 ]]; then
    kib=$(du -s -k "$p" 2>/dev/null | awk '{print $1}') || kib=0
  fi
  echo $(( kib * 1024 ))
}

# Warm up a master SSH connection once
ssh_warmup() {
  mkdir -p "$SSH_CTL_DIR"
  # Force master creation for this session
  sshpass -p "$PASSWORD" ssh -f -N -o ControlMaster=yes -o ControlPath="$SSH_CONTROL_PATH" -o ControlPersist="$SSH_CONTROL_PERSIST" -p "$PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive -o KbdInteractiveAuthentication=yes -o NumberOfPasswordPrompts=1 -o GSSAPIAuthentication=no "$USER_NAME@$SERVER" || true
}

ssh_close() { ssh -O exit -o LogLevel=ERROR -o ControlPath="$SSH_CONTROL_PATH" "$USER_NAME@$SERVER" >/dev/null 2>&1 || true; }

copy_pair_rsync() {
  local src="$1" dest="$2"; local dry=""; [[ "$DRY_RUN" == true ]] && dry="--dry-run"
  ui_info "${UI_RUN} rsync: $src -> $dest"
  sshpass -p "$PASSWORD" rsync -ah $dry $(rsync_progress_opt) --delete -e "$RSYNC_SSH" "${src%/}/" "${USER_NAME}@${SERVER}:${dest%/}/"
}

copy_pair_scp() {
  local src="$1" dest="$2"
  if [[ "$DRY_RUN" == true ]]; then
    ui_info "Would scp -r ${src%/}/* to ${USER_NAME}@${SERVER}:$dest"
  else
    ui_info "${UI_RUN} scp: $src -> $dest"
    sshpass -p "$PASSWORD" scp "${SCP_ARGS[@]}" -r "${src%/}"/* "${USER_NAME}@${SERVER}:${dest%/}"
  fi
}

main() {
  ui_init
  ui_require_cmd sshpass; ui_require_cmd ssh
  parse_args "$@"
  if [[ ${#SOURCE_FOLDERS[@]} -ne ${#DESTINATION_FOLDERS[@]} ]]; then ui_error "Mismatched SOURCE_FOLDERS and DESTINATION_FOLDERS sizes"; exit 1; fi
  for src in "${SOURCE_FOLDERS[@]}"; do [[ -d "$src" ]] || { ui_error "Source not found: $src"; exit 1; }; done

  # Warm up control connection to avoid repeated prompts
  if [[ "$DRY_RUN" != true ]]; then ssh_warmup; fi

  # Decide transfer method
  TRANSFER_METHOD=""
  if pv_available && remote_tar_available; then
    TRANSFER_METHOD="tar_pv"
    ui_info "Using tar+pv progress bar"
  else
    if ui_rsync_available && [[ "$USE_RSYNC_DEFAULT" == true ]] && remote_rsync_available; then
      TRANSFER_METHOD="rsync"
      if rsync --info=progress2 --version >/dev/null 2>&1; then
        ui_info "Using rsync (global progress)"
      else
        ui_info "Using rsync (per-file progress)"
      fi
    else
      TRANSFER_METHOD="scp"
      ui_warn "rsync/pv not available, using scp"
      ui_require_cmd scp
    fi
  fi

  ui_info "Target: $USER_NAME@$SERVER:$PORT"
  if ! ui_confirm; then ui_warn "Aborted by user."; exit 130; fi

  ui_info "Stopping remote service: $REMOTE_SERVICE"; remote "sudo systemctl stop $REMOTE_SERVICE"
  local ok=0 fail=0
  for i in "${!SOURCE_FOLDERS[@]}"; do
    local src="${SOURCE_FOLDERS[$i]}" dest="${DESTINATION_FOLDERS[$i]}"
    remote "mkdir -p '$dest'"
    if [[ "$TRANSFER_METHOD" == "tar_pv" ]]; then
      if copy_pair_tar_pv "$src" "$dest"; then
        (( ok++ ))
      else
        ui_warn "tar+pv failed; falling back to scp for: $src -> $dest"
        if copy_pair_scp "$src" "$dest"; then (( ok++ )); else (( fail++ )); fi
      fi
    elif [[ "$TRANSFER_METHOD" == "rsync" ]]; then
      if copy_pair_rsync "$src" "$dest"; then
        (( ok++ ))
      else
        ui_warn "rsync failed; falling back to scp for: $src -> $dest"
        if copy_pair_scp "$src" "$dest"; then (( ok++ )); else (( fail++ )); fi
      fi
    else
      if copy_pair_scp "$src" "$dest"; then (( ok++ )); else (( fail++ )); fi
    fi
  done
  ui_info "Restarting remote service: $REMOTE_SERVICE"; remote "sudo systemctl restart $REMOTE_SERVICE"
  ui_info "Summary: ok=$ok fail=$fail"
  # Close master connection (optional; otherwise persists until SSH_CONTROL_PERSIST)
  if [[ "$DRY_RUN" != true ]]; then ssh_close; fi
}

main "$@"
