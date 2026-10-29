#!/bin/sh
set -eu

dev=intel_backlight
sysfs="/sys/class/backlight/$dev"

current=$(cat "$sysfs/brightness")
maximum=$(cat "$sysfs/max_brightness")

step=$(( maximum / 20 ))
[ "$step" -ge 1 ] || step=1

case "${1:-}" in
  up) target=$(( current + step )) ;;
  down) target=$(( current - step )) ;;
  *)
    printf 'Usage: brightness-logind.sh {up|down}\n' >&2
    exit 2
    ;;
esac

[ "$target" -ge 1 ] || target=1
[ "$target" -le "$maximum" ] || target=$maximum

sid=$(loginctl show-seat "${XDG_SEAT:-seat0}" \
  --property=ActiveSession --value)

[ -n "$sid" ] || {
  printf 'No active logind session\n' >&2
  exit 1
}

reply=$(busctl --system call \
  org.freedesktop.login1 \
  /org/freedesktop/login1 \
  org.freedesktop.login1.Manager \
  GetSession s "$sid")

session_path=${reply#o \"}
session_path=${session_path%\"}

case "$session_path" in
  /org/freedesktop/login1/session/*) ;;
  *)
    printf 'Invalid session path: %s\n' "$reply" >&2
    exit 1
    ;;
esac

busctl --system call \
  org.freedesktop.login1 \
  "$session_path" \
  org.freedesktop.login1.Session \
  SetBrightness ssu backlight "$dev" "$target"
