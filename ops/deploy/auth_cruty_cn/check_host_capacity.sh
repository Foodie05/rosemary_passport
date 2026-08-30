#!/usr/bin/env bash
set -Eeuo pipefail

minimum_cpus="${ROSM_MIN_CPU_COUNT:-2}"
minimum_memory_bytes="${ROSM_MIN_MEMORY_BYTES:-4294967296}"
minimum_headroom_bytes="${ROSM_MIN_MEMORY_HEADROOM_BYTES:-1073741824}"
meminfo_path="${ROSM_MEMINFO_PATH:-/proc/meminfo}"
cpu_count="${ROSM_CPU_COUNT_OVERRIDE:-$(getconf _NPROCESSORS_ONLN)}"

for value_name in minimum_cpus minimum_memory_bytes minimum_headroom_bytes cpu_count; do
  value="${!value_name}"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "[host-capacity] $value_name must be a positive integer" >&2
    exit 64
  }
done
[[ -f "$meminfo_path" && ! -L "$meminfo_path" ]] || {
  echo '[host-capacity] meminfo must be a regular non-symlink file' >&2
  exit 64
}

read_kib() {
  local name="$1" value
  value="$(awk -v key="$name:" '$1 == key {print $2; exit}' "$meminfo_path")"
  [[ "$value" =~ ^[0-9]+$ ]] || {
    echo "[host-capacity] missing or invalid $name in meminfo" >&2
    exit 69
  }
  printf '%s' "$value"
}

mem_total_kib="$(read_kib MemTotal)"
mem_available_kib="$(read_kib MemAvailable)"
swap_free_kib="$(read_kib SwapFree)"
memory_bytes=$(( mem_total_kib * 1024 ))
headroom_bytes=$(( (mem_available_kib + swap_free_kib) * 1024 ))

if (( cpu_count < minimum_cpus )); then
  echo "[host-capacity] insufficient CPUs: $cpu_count < $minimum_cpus" >&2
  exit 75
fi
if (( memory_bytes < minimum_memory_bytes )); then
  echo "[host-capacity] insufficient physical memory: $memory_bytes < $minimum_memory_bytes" >&2
  exit 75
fi
if (( headroom_bytes < minimum_headroom_bytes )); then
  echo "[host-capacity] insufficient memory headroom: $headroom_bytes < $minimum_headroom_bytes" >&2
  exit 75
fi

echo "[host-capacity] passed: cpus=$cpu_count memory_bytes=$memory_bytes headroom_bytes=$headroom_bytes"
