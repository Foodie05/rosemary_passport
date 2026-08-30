#!/bin/sh
set -eu

identity="${1:?usage: gosu-setpriv user[:group] command [args...]}"
shift

user="${identity%%:*}"
if [ "$identity" = "$user" ]; then
  group="$user"
else
  group="${identity#*:}"
fi

uid="$(id -u "$user")"
gid="$(getent group "$group" | cut -d: -f3)"
test -n "$gid"

exec setpriv --reuid "$uid" --regid "$gid" --init-groups "$@"
