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
  echo "error: away mode already owns supervision; exit afk first (return from /afk, then re-run this script)" >&2
  exit 1
}

mkdir -p "$STATE"
# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh"

if fm_daemon_lock_held_by_live_daemon "$LOCK" "$DAEMON"; then
  _owner=$(fm_daemon_lock_owner "$LOCK" 2>/dev/null || true)
  daemon_pid=$([ -n "$_owner" ] && cat "$_owner/pid" 2>/dev/null || true)
  daemon_identity=$([ -n "$_owner" ] && cat "$_owner/pid-identity" 2>/dev/null || true)
  [ -n "$daemon_pid" ] || { echo "error: daemon vanished between liveness check and pid read" >&2; exit 1; }
  [ ! -e "$STATE/.afk" ] || {
    echo "error: away mode owns supervision; exit afk first (return from /afk, then re-run this script)" >&2
    exit 1
  }
  if [ "$(fm_supervision_owner_get "$STATE" 2>/dev/null || true)" != normal-codex ]; then
    fm_supervision_owner_set "$STATE" normal-codex || {
      echo "error: could not transfer supervision ownership to normal Codex" >&2
      exit 1
    }
  fi
  if [ -e "$STATE/.afk" ]; then
    fm_supervision_owner_set "$STATE" afk 2>/dev/null || true
    echo "error: away mode claimed supervision during adoption; exit afk first (return from /afk, then re-run this script)" >&2
    exit 1
  fi
  final_owner=$(fm_daemon_lock_owner "$LOCK" 2>/dev/null || true)
  final_pid=$([ -n "$final_owner" ] && cat "$final_owner/pid" 2>/dev/null || true)
  final_identity=$([ -n "$final_owner" ] && cat "$final_owner/pid-identity" 2>/dev/null || true)
  if [ -e "$STATE/.afk" ] || \
    [ "$(fm_supervision_owner_get "$STATE" 2>/dev/null || true)" != normal-codex ] || \
    [ "$final_owner" != "$_owner" ] || [ "$final_pid" != "$daemon_pid" ] || \
    [ "$final_identity" != "$daemon_identity" ] || \
    ! fm_daemon_lock_held_by_live_daemon "$LOCK" "$DAEMON"; then
    if [ -e "$STATE/.afk" ]; then
      fm_supervision_owner_set "$STATE" afk 2>/dev/null || true
    elif [ "$(fm_supervision_owner_get "$STATE" 2>/dev/null || true)" = normal-codex ]; then
      fm_supervision_owner_clear "$STATE"
    fi
    echo "error: supervisor ownership changed during normal Codex adoption; retry after away-mode state settles" >&2
    exit 1
  fi
  echo "normal-codex: adopted existing daemon pid=$daemon_pid"
  exit 0
fi

fm_supervision_owner_set "$STATE" normal-codex || {
  echo "error: could not record normal Codex supervision ownership" >&2
  exit 1
}
if [ -e "$STATE/.afk" ]; then
  fm_supervision_owner_set "$STATE" afk 2>/dev/null || true
  echo "error: away mode claimed supervision during startup; exit afk first (return from /afk, then re-run this script)" >&2
  exit 1
fi


exec env FM_SUPERVISION_MODE=normal-codex FM_PRIMARY_HARNESS=codex "$SCRIPT_DIR/fm-supervise-daemon.sh"
