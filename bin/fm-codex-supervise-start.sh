#!/usr/bin/env bash
# Start or adopt the singleton supervisor daemon as the normal-mode Codex owner.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
LOCK="$STATE/.supervise-daemon.lock"
DAEMON="$SCRIPT_DIR/fm-supervise-daemon.sh"

[ "$#" -eq 0 ] || { echo "usage: $(basename "$0")" >&2; exit 2; }
[ ! -e "$STATE/.afk" ] || {
  echo "error: away mode already owns supervision; exit afk first (clear state/.afk and update owner), then re-run this script" >&2
  exit 1
}

mkdir -p "$STATE"
# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh"

daemon_lock_owner() {
  local owner
  if [ -L "$LOCK" ]; then
    owner=$(readlink "$LOCK" 2>/dev/null) || return 1
    [ -n "$owner" ] || return 1
    case "$owner" in
      /*) printf '%s\n' "$owner" ;;
      *) printf '%s/%s\n' "$(dirname "$LOCK")" "$owner" ;;
    esac
    return 0
  fi
  [ -d "$LOCK" ] || return 1
  printf '%s\n' "$LOCK"
}

daemon_lock_held_by_live_daemon() {
  local owner pid identity current command
  owner=$(daemon_lock_owner) || return 1
  pid=$(cat "$owner/pid" 2>/dev/null || true)
  fm_pid_alive "$pid" || return 1
  identity=$(cat "$owner/pid-identity" 2>/dev/null || true)
  if [ -n "$identity" ]; then
    current=$(fm_pid_identity "$pid") || return 1
    [ "$current" = "$identity" ]
    return
  fi
  command=$(ps -p "$pid" -o command= 2>/dev/null || true)
  case "$command" in
    *"$DAEMON"*|*"fm-supervise-daemon.sh"*) return 0 ;;
  esac
  return 1
}

if daemon_lock_held_by_live_daemon; then
  daemon_pid=$(cat "$(daemon_lock_owner)/pid")
  fm_supervision_owner_set "$STATE" normal-codex || {
    echo "error: could not transfer supervision ownership to normal Codex" >&2
    exit 1
  }
  if ! daemon_lock_held_by_live_daemon; then
    [ "$(fm_supervision_owner_get "$STATE" 2>/dev/null || true)" != normal-codex ] || fm_supervision_owner_clear "$STATE"
    echo "error: supervisor daemon exited during normal Codex ownership transfer" >&2
    exit 1
  fi
  echo "normal-codex: adopted existing daemon pid=$daemon_pid"
  exit 0
fi

exec env FM_SUPERVISION_MODE=normal-codex FM_PRIMARY_HARNESS=codex "$SCRIPT_DIR/fm-supervise-daemon.sh"
