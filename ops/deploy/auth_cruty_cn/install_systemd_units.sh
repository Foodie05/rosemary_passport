#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="${ROSM_SYSTEMD_UNIT_DIR:-/etc/systemd/system}"
deploy_root="${ROSM_DEPLOY_ROOT:-$script_dir}"
runtime_env="${ROSM_RUNTIME_ENV_FILE:-/etc/rosm-passport/runtime.env}"
secrets_dir="${ROSM_SECRETS_DIR:-/etc/rosm-passport/secrets}"
[[ "${ROSM_SYSTEMD_INSTALL_CONFIRM:-}" == 'install-sla-timers' ]] || {
  echo 'Set ROSM_SYSTEMD_INSTALL_CONFIRM=install-sla-timers to install timers.' >&2
  exit 64
}
[[ "${EUID:-$(id -u)}" -eq 0 ]] || {
  echo 'Systemd unit installation must run as root.' >&2
  exit 77
}
for command in install mkdir systemctl; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command: $command" >&2
    exit 69
  }
done
[[ -d "$script_dir/systemd" ]] || { echo 'Packaged systemd units are missing.' >&2; exit 66; }
for path in "$unit_dir" "$deploy_root" "$runtime_env" "$secrets_dir"; do
  [[ "$path" =~ ^/[A-Za-z0-9._/-]+$ ]] || {
    echo "Systemd installation path is unsafe: $path" >&2
    exit 78
  }
done
[[ -d "$deploy_root" && ! -L "$deploy_root" ]] || {
  echo 'Deployment root must be a real directory.' >&2
  exit 78
}
[[ -f "$runtime_env" && -d "$secrets_dir" ]] || {
  echo 'Runtime configuration and secrets must be provisioned first.' >&2
  exit 78
}
mkdir -p /var/lib/rosm-passport/sla-observation
chmod 0700 /var/lib/rosm-passport /var/lib/rosm-passport/sla-observation
rendered_dir="$(mktemp -d)"
trap 'rm -rf "$rendered_dir"' EXIT
for unit in "$script_dir"/systemd/rosm-passport-*; do
  rendered_unit="$rendered_dir/$(basename "$unit")"
  sed -e "s#/srv/rosm-passport/current#$deploy_root#g" \
    -e "s#/etc/rosm-passport/runtime.env#$runtime_env#g" \
    -e "s#/etc/rosm-passport/secrets#$secrets_dir#g" \
    "$unit" >"$rendered_unit"
  install -m 0644 -o root -g root "$rendered_unit" "$unit_dir/$(basename "$unit")"
done
systemctl daemon-reload
systemctl enable --now \
  rosm-passport-physical-backup.timer \
  rosm-passport-audit-archive.timer \
  rosm-passport-sla-observation.timer
systemctl list-timers 'rosm-passport-*' --no-pager
