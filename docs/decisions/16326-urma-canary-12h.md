# Tone down urma teams-bridge canary to 12h (dotfiles#16326)

**Date:** 2026-06-09
**Scope:** urma only; per-project drop-ins for `evtctl-forward@urma.service`
and `evtctl-canary-watch@urma.service`.

## Context

The evtctl-forward Teams bridge emits a heartbeat ("canary") card to each
forwarded project's channel on a cadence controlled by `ForwardCanaryIntervalMs`
(default 3600000 ms / 1 h, per `~/projects/era/bin/evtctl` lines 58-59). A
companion `evtctl-canary-watch@<project>` oneshot (invoked every 30 min by a
timer) compares the most recent canary's age to `ForwardCanaryWatchThresholdMs`
(default 5400000 ms / 90 min) and posts to ntfy if the threshold is exceeded.

The hourly cadence is fine for early bring-up of a bridge (frequent
heartbeat = fast detection of breakage) but becomes channel noise once a
bridge has proved stable. The operator asked on 2026-06-09 to tone down
the urma bridge specifically.

## Decision

**Option 1 chosen: interval-only, urma-only.**

Set `ForwardCanaryIntervalMs=43200000` (12 h) on `evtctl-forward@urma.service`
via a systemd drop-in. Set `ForwardCanaryWatchThresholdMs=46800000` (13 h)
on `evtctl-canary-watch@urma.service` via a coupled drop-in to give the
absence watcher 1 h of grace past the new canary cadence -- otherwise the
90-min default would false-fire ntfy alerts every 12 h interval.

Other forwarded projects keep the hourly default (config unchanged in
`~/projects/era/bin/evtctl`).

### Alternatives considered

- **Option 2: business-hours-aware schedule (cron-like).** True
  "twice-a-day at fixed local times" scheduling would require either
  emitting canaries from a separate systemd timer with `OnCalendar=`
  rules, or teaching the daemon's canary loop a calendar-shaped
  schedule. Both are larger surface than the operator's actual ask
  (channel-noise reduction). Flagged as backlog if precision becomes
  necessary.

- **Global cadence change in `era/bin/evtctl`.** Would also satisfy
  the immediate ask but applies to every project's bridge, including
  ones still in bring-up where hourly heartbeat is wanted. Scope
  mismatch.

- **Disable the bridge canary entirely on urma.** Loses
  breakage-detection signal; the canary-watch + ntfy hookup exists
  specifically to catch silent-failure modes of the bridge. Twice-a-day
  preserves the signal at lower volume.

## Mechanism

Drop-in source files live under `evtctl-forward/dropins/` in this repo and
are installed by `update-env` via `task.Install` into
`~/.config/systemd/user/<unit>.d/`. This mirrors how the upstream era
project's unit templates flow through update-env (era ships the templates;
dotfiles ships per-project overrides).

The drop-ins target per-instance unit dirs
(`evtctl-forward@urma.service.d/`, not `evtctl-forward@.service.d/`), so
only the urma instance picks up the override. Other instances continue to
read the in-binary defaults.

### Activation

`update-env` writes the drop-in files but does NOT reload systemd or
restart the services. After the next `update-env` run on calumny (or
wherever the urma bridge runs), the operator activates with:

```
systemctl --user daemon-reload
systemctl --user restart evtctl-forward@urma.service
systemctl --user restart evtctl-canary-watch@urma.service
```

## Verification

After restart, wait 12-24 h then check:

```
era query evtctl-forward.audit.urma 'type="canary"' --limit 2 --desc --json \
  | jq -r '.[].created_at'
```

The two most-recent canary timestamps should be ~12 h apart. The
canary-watch should not have posted to ntfy in the interim.
