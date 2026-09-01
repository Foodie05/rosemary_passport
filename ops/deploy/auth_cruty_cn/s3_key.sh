#!/usr/bin/env bash

validate_s3_prefix() {
  local prefix="${1:-}" segment
  local -a segments=()
  [[ -z "$prefix" ]] && return 0
  [[ "$prefix" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*[A-Za-z0-9]$ ]] || return 1
  [[ "$prefix" != *//* ]] || return 1
  IFS='/' read -r -a segments <<<"$prefix"
  for segment in "${segments[@]}"; do
    [[ "$segment" != . && "$segment" != .. ]] || return 1
  done
}

s3_key() {
  local prefix="${1:-}" relative_key="${2:?relative S3 key required}"
  validate_s3_prefix "$prefix" || return 64
  [[ "$relative_key" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || return 64
  [[ "$relative_key" != /* && "$relative_key" != *//* ]] || return 64
  if [[ -n "$prefix" ]]; then
    printf '%s/%s' "$prefix" "$relative_key"
  else
    printf '%s' "$relative_key"
  fi
}

s3_relative_key() {
  local prefix="${1:-}" object_key="${2:?S3 object key required}"
  validate_s3_prefix "$prefix" || return 64
  if [[ -n "$prefix" ]]; then
    [[ "$object_key" == "$prefix/"* ]] || return 1
    printf '%s' "${object_key#"$prefix/"}"
  else
    printf '%s' "$object_key"
  fi
}
