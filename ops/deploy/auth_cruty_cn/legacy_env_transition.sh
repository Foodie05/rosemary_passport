#!/usr/bin/env bash
set -Eeuo pipefail

action="${1:?action required}"
target_dir="${2:?target directory required}"

die() {
  printf '[legacy-env] %s\n' "$1" >&2
  exit 78
}

[[ "$target_dir" = /* && -d "$target_dir" && ! -L "$target_dir" ]] \
  || die 'target must be an absolute non-symlink directory'
legacy_env="$target_dir/.env"

file_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

file_uid() {
  stat -c '%u' "$1" 2>/dev/null || stat -f '%u' "$1"
}

case "$action" in
  quarantine)
    quarantine_dir="${3:?quarantine directory required}"
    timestamp="${4:?timestamp required}"
    [[ "$quarantine_dir" = /* && ! -L "$quarantine_dir" ]] \
      || die 'quarantine path must be absolute and not a symlink'
    [[ "$timestamp" =~ ^[0-9]{8}-[0-9]{6}$ ]] || die 'timestamp is invalid'
    if [[ ! -e "$legacy_env" ]]; then
      exit 0
    fi
    [[ -f "$legacy_env" && ! -L "$legacy_env" ]] \
      || die 'legacy env must be a regular non-symlink file'
    [[ "$(file_mode "$legacy_env")" == 600 ]] || die 'legacy env mode must be 0600'
    [[ "$(file_uid "$legacy_env")" == "$(id -u)" ]] \
      || die 'legacy env must be owned by the deployment user'
    mkdir -p "$quarantine_dir"
    chmod 0700 "$quarantine_dir"
    [[ "$(file_uid "$quarantine_dir")" == "$(id -u)" ]] \
      || die 'quarantine directory must be owned by the deployment user'
    quarantine_file="$quarantine_dir/legacy-$timestamp.env"
    [[ ! -e "$quarantine_file" ]] || die 'quarantine destination already exists'
    mv "$legacy_env" "$quarantine_file"
    chmod 0600 "$quarantine_file"
    printf '%s\n' "$quarantine_file"
    ;;
  restore)
    quarantine_file="${3:?quarantine file required}"
    [[ "$quarantine_file" = /* && -f "$quarantine_file" && ! -L "$quarantine_file" ]] \
      || die 'quarantine file must be an absolute regular non-symlink file'
    [[ ! -e "$legacy_env" ]] || die 'refusing to overwrite an existing legacy env'
    [[ "$(file_mode "$quarantine_file")" == 600 ]] \
      || die 'quarantine file mode must be 0600'
    [[ "$(file_uid "$quarantine_file")" == "$(id -u)" ]] \
      || die 'quarantine file must be owned by the deployment user'
    mv "$quarantine_file" "$legacy_env"
    chmod 0600 "$legacy_env"
    ;;
  *)
    die 'action must be quarantine or restore'
    ;;
esac
