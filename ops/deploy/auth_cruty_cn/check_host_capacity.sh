#!/usr/bin/env bash
set -Eeuo pipefail

minimum_cpus="${ROSM_MIN_CPU_COUNT:-2}"
cpu_count="${ROSM_CPU_COUNT_OVERRIDE:-$(getconf _NPROCESSORS_ONLN)}"

for value_name in minimum_cpus cpu_count; do
  value="${!value_name}"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "[host-capacity] $value_name must be a positive integer" >&2
    exit 64
  }
done

if (( cpu_count < minimum_cpus )); then
  echo "[host-capacity] insufficient CPUs: $cpu_count < $minimum_cpus" >&2
  exit 75
fi

echo "[host-capacity] passed: cpus=$cpu_count"
