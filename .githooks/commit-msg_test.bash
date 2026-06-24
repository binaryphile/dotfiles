# Naming Policy:
#
# Test file for .githooks/commit-msg. Functions: test_* per tesht convention.
# Locals: camelCase. Variables ending in _ may contain IFS characters or be
# empty -- quote on expansion.
#
# Khorikov posture (~/projects/jeeves/guides/khorikov-unit-testing-guide.md):
# Integration tests on the controller (the hook). Output-based assertions via
# captured stderr + rc. Mock at inter-system boundary = isolated git repo per
# test via tesht.MktempDir + real git operations (init, add, commit). No
# mocking of git itself; the real binary is exercised.

IFS=$'\n'
set -o noglob

HookPath=$(dirname $TESHT_TEST_FILE)/commit-msg

# initRepo sets up a fresh git repo in `dir` with `scripts/cross-tree-sweep-cron`
# carrying the canonical 6 budget constants, committed.
initRepo() {
  local dir=$1
  (
    cd $dir
    git init -q -b main
    git config user.email 'test@example.com'
    git config user.name 'Test'
    mkdir -p scripts
    cat >scripts/cross-tree-sweep-cron <<'END'
#!/usr/bin/env bash
declare -gri DirtyRepoBudget=5
declare -gri StashWarnBudget=0
declare -gri UnpushedBudget=0
declare -gri PlanStaleDaysBudget=60
declare -gri PlanStaleCountBudget=50
declare -gri PlanStrayBudget=0
END
    git add scripts/cross-tree-sweep-cron
    git commit -q -m 'initial cron script'
  )
}

# runHook invokes commit-msg with `msgFile` in `dir`. Captures stderr to
# `STDERR_OUT` and rc to `RC_OUT`.
runHook() {
  local -n STDERR_OUT=$1
  local -n RC_OUT=$2
  local dir=$3 msgFile=$4
  STDERR_OUT=$(cd $dir && $HookPath $msgFile 2>&1 >/dev/null) && RC_OUT=0 || RC_OUT=$?
}

# test_tightening_passes -- DirtyRepoBudget=5 -> 3, no rationale, rc=0.
test_tightening_passes() {
  local dir
  tesht.MktempDir dir || return 128
  initRepo $dir
  (cd $dir
   sed -i 's/DirtyRepoBudget=5/DirtyRepoBudget=3/' scripts/cross-tree-sweep-cron
   git add scripts/cross-tree-sweep-cron)
  echo 'tighten DirtyRepoBudget=3' >$dir/msg

  local stderr_ rc
  runHook stderr_ rc $dir $dir/msg

  tesht.AssertRC $rc 0
}

# test_loosening_with_rationale_passes -- DirtyRepoBudget=5 -> 6 with rationale, rc=0.
test_loosening_with_rationale_passes() {
  local dir
  tesht.MktempDir dir || return 128
  initRepo $dir
  (cd $dir
   sed -i 's/DirtyRepoBudget=5/DirtyRepoBudget=6/' scripts/cross-tree-sweep-cron
   git add scripts/cross-tree-sweep-cron)
  cat >$dir/msg <<'END'
loosen DirtyRepoBudget=6

Loosening rationale: dirty=6 sustained 6 weeks; calibrate to operational reality
END

  local stderr_ rc
  runHook stderr_ rc $dir $dir/msg

  tesht.AssertRC $rc 0
}

# test_loosening_without_rationale_fails -- DirtyRepoBudget=5 -> 6 without rationale, rc=1,
# stderr names DirtyRepoBudget.
test_loosening_without_rationale_fails() {
  local dir
  tesht.MktempDir dir || return 128
  initRepo $dir
  (cd $dir
   sed -i 's/DirtyRepoBudget=5/DirtyRepoBudget=6/' scripts/cross-tree-sweep-cron
   git add scripts/cross-tree-sweep-cron)
  echo 'loosen DirtyRepoBudget=6' >$dir/msg

  local stderr_ rc
  runHook stderr_ rc $dir $dir/msg

  tesht.AssertRC $rc 1
  [[ $stderr_ == *DirtyRepoBudget* ]] || {
    echo "stderr did not name DirtyRepoBudget"
    echo "stderr was: $stderr_"
    return 1
  }
}

# test_mixed_with_rationale_passes -- DirtyRepoBudget tightens + PlanStaleCountBudget loosens,
# rationale present, rc=0.
test_mixed_with_rationale_passes() {
  local dir
  tesht.MktempDir dir || return 128
  initRepo $dir
  (cd $dir
   sed -i 's/DirtyRepoBudget=5/DirtyRepoBudget=3/' scripts/cross-tree-sweep-cron
   sed -i 's/PlanStaleCountBudget=50/PlanStaleCountBudget=80/' scripts/cross-tree-sweep-cron
   git add scripts/cross-tree-sweep-cron)
  cat >$dir/msg <<'END'
mixed: dirty=3 (tighten) + plan_stale=80 (loosen)

Loosening rationale: plan_stale=80 reflects 2 new long-running R&D cycles
END

  local stderr_ rc
  runHook stderr_ rc $dir $dir/msg

  tesht.AssertRC $rc 0
}

# test_unrelated_file_passes -- stage edit to a different file, no cross-tree-sweep-cron change,
# rc=0 (gate doesn't fire -- scoping check).
test_unrelated_file_passes() {
  local dir
  tesht.MktempDir dir || return 128
  initRepo $dir
  (cd $dir
   echo hi >other.txt
   git add other.txt)
  echo 'add other.txt' >$dir/msg

  local stderr_ rc
  runHook stderr_ rc $dir $dir/msg

  tesht.AssertRC $rc 0
}

# test_no_budget_change_passes -- edit cross-tree-sweep-cron but don't change a budget constant,
# rc=0 (gate doesn't fire -- regex doesn't match).
test_no_budget_change_passes() {
  local dir
  tesht.MktempDir dir || return 128
  initRepo $dir
  (cd $dir
   sed -i '1a # added comment' scripts/cross-tree-sweep-cron
   git add scripts/cross-tree-sweep-cron)
  echo 'add comment to cron' >$dir/msg

  local stderr_ rc
  runHook stderr_ rc $dir $dir/msg

  tesht.AssertRC $rc 0
}
