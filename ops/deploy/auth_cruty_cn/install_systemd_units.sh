#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="${ROSM_SYSTEMD_UNIT_DIR:-/etc/systemd/system}"
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
[[ -f /etc/rosm-passport/runtime.env && -d /etc/rosm-passport/secrets ]] || {
  echo 'Runtime configuration and secrets must be provisioned first.' >&2
  exit 78
}
mkdir -p /var/lib/rosm-passport/sla-observation
chmod 0700 /var/lib/rosm-passport /var/lib/rosm-passport/sla-observation
for unit in "$script_dir"/systemd/rosm-passport-*; do
  install -m 0644 -o root -g root "$unit" "$unit_dir/$(basename "$unit")"
done
systemctl daemon-reload
systemctl enable --now \
  rosm-passport-physical-backup.timer \
  rosm-passport-audit-archive.timer \
  rosm-passport-sla-observation.timer
systemctl list-timers 'rosm-passport-*' --no-pager
