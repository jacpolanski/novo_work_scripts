# scripts/

Centralized, user-friendly wrappers that read directories/paths from config files (no need to pass directories via terminal).

## Layout

- `scripts/lib/ui.sh` – shared logging, errors, confirmations
- `scripts/config/*.conf` – per-task configurations (edit these)
- Wrapper scripts:
  - `scripts/copy_resources.sh`
  - `scripts/transfer_build.sh`
  - `scripts/set_machine_ip_linux.sh`
  - `scripts/set_machine_ip_macos.sh`
  - `scripts/make_remote_debug.sh`

## Configure
Edit the corresponding file under `scripts/config/` before running. Examples:

- `scripts/config/copy_resources.conf`
- `scripts/config/transfer_build.conf`
- `scripts/config/set_machine_ip_linux.conf`
- `scripts/config/set_machine_ip_macos.conf`
- `scripts/config/make_remote_dev_tools.conf`

## Run

- Copy resources:
  ```bash
  ./scripts/copy_resources.sh -n   # dry-run
  ./scripts/copy_resources.sh -y   # run without prompt
  ```

- Transfer build to remote:
  ```bash
  ./scripts/transfer_build.sh -n
  ./scripts/transfer_build.sh -y
  ```

- Set machine IP:
  ```bash
  ./scripts/set_machine_ip_linux.sh
  ./scripts/set_machine_ip_macos.sh
  ```

- Configure remote debugging:
  ```bash
  ./scripts/make_remote_debug.sh -y
  ```

Flags common to most scripts:
- `-n/--dry-run`, `-y/--yes`, `--no-color`, `-h/--help`

Logs are written to /tmp/<script>-<timestamp>.log by default.
