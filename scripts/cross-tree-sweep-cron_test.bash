# Naming Policy:
#
# Test file for cross-tree-sweep-cron. Functions: snake-case test_*
# per tesht convention. Locals: camelCase. Variables ending in _
# may contain IFS characters or be empty — quote on expansion.
#
# Khorikov posture (~/projects/jeeves/guides/khorikov-unit-testing-guide.md):
# Integration tests on the controller (the script). Output-based
# assertions via captured stdout/stderr + captured-evtctl-args via
# STUB_EVTCTL_LOG. Mock at inter-system boundary = filesystem
# stubs (cross-repo-dirty-sweep, evtctl) + real fs for plan-dir
# fixtures with controlled mtimes via `touch -d`.

IFS=$'\n'
set -o noglob

ScriptPath=$(dirname $TESHT_TEST_FILE)/cross-tree-sweep-cron

# stageStubs creates `dir/stub-bin/` with stubs for cross-repo-dirty-sweep + evtctl. The sweep stub emits `sweepOut`; the evtctl stub appends invocation args to `dir/evtctl.log`. (A)
stageStubs() {
  local dir=$1 sweepOut=$2
  mkdir -p $dir/stub-bin
  cat >$dir/stub-bin/cross-repo-dirty-sweep <<END
#!/usr/bin/env bash
printf '%s\n' "$sweepOut"
END
  cat >$dir/stub-bin/evtctl <<END
#!/usr/bin/env bash
echo "\$@" >>$dir/evtctl.log
exit 0
END
  chmod +x $dir/stub-bin/cross-repo-dirty-sweep $dir/stub-bin/evtctl
}

# stageStubsWithFailingSweep installs stubs where cross-repo-dirty-sweep exits non-zero with stderr "sweep failed". (A)
stageStubsWithFailingSweep() {
  local dir=$1
  mkdir -p $dir/stub-bin
  cat >$dir/stub-bin/cross-repo-dirty-sweep <<'END'
#!/usr/bin/env bash
echo "sweep failed" >&2
exit 99
END
  cat >$dir/stub-bin/evtctl <<END
#!/usr/bin/env bash
echo "\$@" >>$dir/evtctl.log
exit 0
END
  chmod +x $dir/stub-bin/cross-repo-dirty-sweep $dir/stub-bin/evtctl
}

# stageStubsWithFailingEvtctl installs stubs where cross-repo-dirty-sweep emits clean output but evtctl exits non-zero. (A)
stageStubsWithFailingEvtctl() {
  local dir=$1
  mkdir -p $dir/stub-bin
  cat >$dir/stub-bin/cross-repo-dirty-sweep <<'END'
#!/usr/bin/env bash
echo "repo1: dirty=0 stash_warn=0 unpushed=0"
END
  cat >$dir/stub-bin/evtctl <<'END'
#!/usr/bin/env bash
echo "evtctl failed" >&2
exit 7
END
  chmod +x $dir/stub-bin/cross-repo-dirty-sweep $dir/stub-bin/evtctl
}

# runCron invokes the script under controlled env. Captures stderr to `STDERR_OUT`, exit code to `RC_OUT`. (A)
runCron() {
  local -n STDERR_OUT=$1
  local -n RC_OUT=$2
  local dir=$3 planDir=$4
  STDERR_OUT=$(PATH=$dir/stub-bin:$PATH \
    CROSS_TREE_PLAN_DIR=$planDir \
    CROSS_TREE_AUDIT_APP=test-noop \
    $ScriptPath 2>&1 1>/dev/null) && RC_OUT=0 || RC_OUT=$?
}

# evtctlMessage reads the last `evtctl inbox $app --send <msg>` line from `dir/evtctl.log` and emits the `<msg>` portion (the body argument). (C)
evtctlMessage() {
  local dir=$1
  # The stub logs the full args: `inbox test-noop --send /cleanup-sweep ...`
  # Extract everything after `--send ` on the LAST line.
  tail -1 $dir/evtctl.log 2>/dev/null | sed -E 's/^.*--send //'
}

test_main_allCleanEmitsOkMessage() {
  ## arrange
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=0"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == "/cleanup-sweep OK"* ]] || {
    tesht.Log "expected OK severity; got: $msg"
    return 1
  }
  [[ $msg == *"dirty=0/5(OK)"* ]] || { tesht.Log "expected dirty OK marker; got: $msg"; return 1; }
  [[ $msg == *"stash_warn=0/0(OK)"* ]] || { tesht.Log "expected stash_warn OK; got: $msg"; return 1; }
  [[ $msg == *"unpushed=0/0(OK)"* ]] || { tesht.Log "expected unpushed OK; got: $msg"; return 1; }
}

test_main_dirtyOverBudgetWarnsWithOffenders() {
  ## arrange — 6 dirty repos exceeds budget=5
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  local sweepOut
  sweepOut="repo1: dirty=2 stash_warn=0 unpushed=0
repo2: dirty=1 stash_warn=0 unpushed=0
repo3: dirty=1 stash_warn=0 unpushed=0
repo4: dirty=1 stash_warn=0 unpushed=0
repo5: dirty=1 stash_warn=0 unpushed=0
repo6: dirty=1 stash_warn=0 unpushed=0"
  stageStubs $dir "$sweepOut"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == "/cleanup-sweep WARN"* ]] || { tesht.Log "expected WARN; got: $msg"; return 1; }
  [[ $msg == *"dirty=6/5(BREACH)"* ]] || { tesht.Log "expected dirty BREACH; got: $msg"; return 1; }
  [[ $msg == *"offenders:"* ]] || { tesht.Log "expected offenders trailer; got: $msg"; return 1; }
  [[ $msg == *"repo1=dirty=2"* ]] || { tesht.Log "expected repo1 in offenders; got: $msg"; return 1; }
}

test_main_stashWarnBreaches() {
  ## arrange — policy-breach dim, any non-zero = BREACH
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubs $dir "repo1: dirty=0 stash_warn=2 unpushed=0"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"stash_warn=1/0(BREACH)"* ]] || {
    tesht.Log "expected stash_warn BREACH count=1 (1 repo over budget); got: $msg"
    return 1
  }
}

test_main_unpushedNumericBreaches() {
  ## arrange — unpushed=3 is numeric ahead
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=3"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"unpushed=1/0(BREACH)"* ]] || { tesht.Log "expected unpushed BREACH; got: $msg"; return 1; }
}

test_main_unpushedSkipNoUpstreamIsOk() {
  ## arrange — intentional non-push state
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=skip-no-upstream"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"unpushed=0/0(OK)"* ]] || {
    tesht.Log "expected unpushed=0 OK (skip-no-upstream not counted); got: $msg"
    return 1
  }
}

test_main_unpushedSkipLocalOnlyMarkerIsOk() {
  ## arrange — orch.localOnly intentional marker
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=skip-local-only-marker"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"unpushed=0/0(OK)"* ]] || {
    tesht.Log "expected unpushed=0 OK (skip-local-only-marker not counted); got: $msg"
    return 1
  }
}

test_main_unpushedDivergedOutOfBandBreaches() {
  ## arrange — out-of-band divergence is actionable
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=diverged-out-of-band"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"unpushed=1/0(BREACH)"* ]] || { tesht.Log "expected diverged → BREACH; got: $msg"; return 1; }
}

test_main_planStaleBreaches() {
  ## arrange — drop 60 fake stale plans into plan dir
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  local i
  for (( i = 0; i < 60; i++ )); do
    touch -d "100 days ago" $dir/plans/stale-$i.md
  done
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=0"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"plan_stale=60/50(BREACH)"* ]] || {
    tesht.Log "expected plan_stale BREACH count=60; got: $msg"
    return 1
  }
}

test_main_freshPlansDoNotCountAsStale() {
  ## arrange — R2 P10 non-regression: 100 fresh plans should produce plan_stale=0
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  local i
  for (( i = 0; i < 100; i++ )); do
    touch $dir/plans/fresh-$i.md
  done
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=0"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"plan_stale=0/50(OK)"* ]] || {
    tesht.Log "expected fresh plans NOT counted toward plan_stale; got: $msg"
    return 1
  }
}

test_main_planStraysBreaches() {
  ## arrange — single stray file in plan dir
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  echo "not a markdown plan" >$dir/plans/stray.txt
  stageStubs $dir "repo1: dirty=0 stash_warn=0 unpushed=0"

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert
  tesht.AssertRC $rc 0
  local msg=$(evtctlMessage $dir)
  [[ $msg == *"plan_strays=1/0(BREACH)"* ]] || {
    tesht.Log "expected plan_strays BREACH; got: $msg"
    return 1
  }
}

test_main_eraHelperMissingFailsLoud() {
  ## arrange — stub sweep that exits 99 (non-zero, non-findings)
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubsWithFailingSweep $dir

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert — fail-loud rc=2, no publish
  tesht.AssertRC $rc 2
  [[ -f $dir/evtctl.log ]] && { tesht.Log "evtctl should not have been invoked"; return 1; }
  [[ $got_ == *"failed rc=99"* ]] || { tesht.Log "expected helper-failure stderr; got: $got_"; return 1; }
}

test_main_evtctlPublishFailsLoud() {
  ## arrange — stub evtctl exits non-zero
  local dir
  tesht.MktempDir dir || return 128
  mkdir -p $dir/plans
  stageStubsWithFailingEvtctl $dir

  ## act
  local got_ rc
  runCron got_ rc $dir $dir/plans

  ## assert — fail-loud rc=3, stderr describes the failure
  tesht.AssertRC $rc 3
  [[ $got_ == *"evtctl inbox"* ]] || { tesht.Log "expected publish-failure stderr; got: $got_"; return 1; }
}
