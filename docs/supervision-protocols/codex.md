Mode: Codex daemon-backed normal supervision.

Run `bin/fm-codex-supervise-start.sh` in its own tracked terminal session.
It starts the existing singleton supervisor daemon in explicit `normal-codex` mode, which owns the watcher, re-arms it, and injects captain-relevant escalations only into a confirmed-idle Codex composer.
Do not run a foreground checkpoint while this daemon owns supervision.
The daemon preserves queued wakes, the watcher liveness beacon, and its existing busy/composer guards, so it never merges an escalation into typed input.
Do not use shell `&`, `nohup`, or a Codex background task to launch it.
Away mode remains the same daemon under `/afk`.
The `/afk` skill owns the durable `afk` <-> `normal-codex` ownership-transfer and return contract.

Validation on 2026-07-11 used Codex CLI 0.144.1 in a disposable tmux server with a scratch `FM_HOME` and no `state/.afk` flag.
The supervisor was started with `FM_HOME=<scratch> FM_SUPERVISOR_BACKEND=tmux FM_SUPERVISOR_TARGET=codex-normal:0 bin/fm-codex-supervise-start.sh`.
After `printf 'done: normal daemon wake smoke\n' > <scratch>/state/smoke.status`, the idle Codex primary received `Supervisor escalate (1 event(s)): smoke.status: done: normal daemon wake smoke (pre-read; re-arm not needed - watcher daemon-managed)` and replied `Acknowledged: normal daemon wake smoke completed; no re-arm needed.`
The daemon lock and watcher liveness beacon existed before that status write, and no primary input was sent after it.

The legacy checkpoint remains a bounded diagnostic and recovery tool only.
It drains an already-durable queue before taking a watcher lock and forces one heartbeat reconciliation for a terminal status missed in an earlier gap.
It cannot provide continuous normal supervision because Codex does not reopen a fully ended session for a later filesystem write.
Do not run `bin/fm-watch-arm.sh` as Codex's normal supervision command.
The PreToolUse seatbelt in `.codex/hooks.json` denies a backgrounded, piped, or bundled watcher command.
