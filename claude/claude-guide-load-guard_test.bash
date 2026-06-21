# Naming Policy:
#
# Test file for claude-guide-load-guard. Functions: snake-case
# test_* per tesht convention. Locals: camelCase. Variables ending
# in _ may contain IFS characters or be empty — quote on expansion.
#
# Khorikov posture (~/projects/jeeves/guides/khorikov-unit-testing-guide.md):
# Integration tests on the controller (the hook script). Output-based
# assertions via captured exit code + stderr. Mock at inter-system
# boundary = filesystem (guide fixtures + transcript JSONL). No
# mocking of internal helpers — they're exercised through the public
# interface (PreToolUse JSON stdin → exit code + stderr).

IFS=$'\n'
set -o noglob

ScriptPath=$(dirname $TESHT_TEST_FILE)/claude-guide-load-guard

# stageGuides creates `dir` with bash + fluentfp + khorikov sample guides carrying valid front-matter. (A — touches fs)
stageGuides() {
  local dir=$1
  mkdir -p $dir
  cat >$dir/bash-style-guide.md <<'END'
---
applies-to: ["**/*.bash", "**/*.sh"]
summary: "Bash conventions under IFS/noglob."
---
# Bash Style Guide

Body content.
END
  cat >$dir/fluentfp-guide.md <<'END'
---
applies-to: ["**/*.go"]
package-imports: ["github.com/binaryphile/fluentfp"]
summary: "FluentFP API — chain instead of for-loop."
---
# FluentFP

Body.
END
  cat >$dir/khorikov-unit-testing-guide.md <<'END'
---
applies-to: ["**/*_test.bash", "**/*_test.go"]
summary: "Khorikov classical-school."
---
# Khorikov

Body.
END
  cat >$dir/no-frontmatter.md <<'END'
# Plain Guide

Body without front-matter; the hook should skip it entirely.
END
  cat >$dir/malformed.md <<'END'
---
summary: "missing applies-to is a schema error"
---
# Malformed

Body.
END
}

# stageTranscriptWithReads writes a JSONL transcript at `path` containing one Read tool_use entry per `_`-suffix path in `paths_` (newline-separated). (A — touches fs)
stageTranscriptWithReads() {
  local path=$1 paths_=$2
  : >$path
  local p
  for p in $paths_; do
    [[ -z $p ]] && continue
    printf '{"message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"%s"}}]}}\n' "$p" >>$path
  done
}

# mkInputJson constructs the PreToolUse JSON stdin body with tool, path, transcript and emits it to stdout. (C)
mkInputJson() {
  local tool=$1 filePath=$2 transcriptPath=$3
  jq -nc \
    --arg t $tool \
    --arg p $filePath \
    --arg tr $transcriptPath \
    --arg s sess-test \
    '{tool_name:$t, tool_input:{file_path:$p}, transcript_path:$tr, session_id:$s, cwd:"."}'
}

# runHook invokes the hook with controlled env, given input on stdin, and captures stderr + exit code. Writes stderr to `outVar` named, exit code to `rcVar` named. (A — runs subprocess)
runHook() {
  local -n STDERR_OUT=$1
  local -n RC_OUT=$2
  local guidesDir=$3
  local scope=$4
  local input_=$5
  STDERR_OUT=$(CLAUDE_GUIDE_DIRS=$guidesDir CLAUDE_GUIDE_SCOPE=$scope \
    CLAUDE_GUIDE_AUDIT_APP=test-noop \
    PATH="/tmp/noop-bin:$PATH" \
    $ScriptPath <<<"$input_" 2>&1 1>/dev/null) && RC_OUT=0 || RC_OUT=$?
}

# stageNoopEvtctl installs a fake evtctl on PATH that returns 0 silently — keeps publishAudit from polluting the real era stream during tests. (A)
stageNoopEvtctl() {
  mkdir -p /tmp/noop-bin
  cat >/tmp/noop-bin/evtctl <<'END'
#!/usr/bin/env bash
exit 0
END
  chmod +x /tmp/noop-bin/evtctl
}

test_main_nonEditWriteToolAllows() {
  ## arrange
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  : >$dir/transcript.jsonl
  local input
  input=$(mkInputJson Bash $dir/scope/foo.bash $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert
  tesht.AssertRC $rc 0
}

test_main_outOfScopePathAllows() {
  ## arrange
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  : >$dir/transcript.jsonl
  # Path NOT under the configured scope — hook must allow.
  local input
  input=$(mkInputJson Edit /tmp/random.bash $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert
  tesht.AssertRC $rc 0
}

test_main_bashFileNoGuideLoadedBlocks() {
  ## arrange
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  : >$dir/transcript.jsonl
  local input
  input=$(mkInputJson Edit $dir/scope/foo.bash $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert — must block (rc=2) and name bash-style-guide
  tesht.AssertRC $rc 2
  [[ $got_ == *BLOCKED* && $got_ == *bash-style-guide.md* ]] || {
    tesht.Log "expected BLOCKED + bash-style-guide.md in stderr; got: $got_"
    return 1
  }
}

test_main_bashFileGuideLoadedAllows() {
  ## arrange
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  stageTranscriptWithReads $dir/transcript.jsonl "$dir/guides/bash-style-guide.md"
  local input
  input=$(mkInputJson Edit $dir/scope/foo.bash $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert
  tesht.AssertRC $rc 0
}

test_main_bypassEnvAllowsAndAudits() {
  ## arrange
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  : >$dir/transcript.jsonl
  local input
  input=$(mkInputJson Edit $dir/scope/foo.bash $dir/transcript.jsonl)

  ## act — bypass set; would have blocked, but bypass allows
  local got_ rc
  got_=$(CLAUDE_GUIDE_DIRS=$dir/guides CLAUDE_GUIDE_SCOPE=$dir/scope/ \
    CLAUDE_GUIDE_LOAD_SKIP=1 CLAUDE_GUIDE_AUDIT_APP=test-noop \
    PATH="/tmp/noop-bin:$PATH" \
    $ScriptPath <<<"$input" 2>&1 1>/dev/null) && rc=0 || rc=$?

  ## assert — rc=0, stderr surfaces BYPASS notice
  tesht.AssertRC $rc 0
  [[ $got_ == *BYPASS* ]] || {
    tesht.Log "expected BYPASS notice in stderr; got: $got_"
    return 1
  }
}

test_main_fluentfpAndMatchBlocks() {
  ## arrange — go file in a package that imports fluentfp
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  mkdir -p $dir/scope/pkg
  cat >$dir/scope/pkg/sibling.go <<'END'
package pkg

import "github.com/binaryphile/fluentfp/slice"

var _ = slice.Mapper[int]{}
END
  : >$dir/transcript.jsonl
  local input
  input=$(mkInputJson Edit $dir/scope/pkg/new.go $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert — fluentfp guide required (sibling imports), go-development also required (general *.go)
  tesht.AssertRC $rc 2
  [[ $got_ == *fluentfp-guide.md* ]] || {
    tesht.Log "expected fluentfp-guide.md required; got: $got_"
    return 1
  }
}

test_main_fluentfpNoSiblingImportSkipsFluentfp() {
  ## arrange — go file in a package with NO fluentfp import (vacuous AND case)
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  mkdir -p $dir/scope/pkg
  cat >$dir/scope/pkg/sibling.go <<'END'
package pkg

// no fluentfp import here
var _ = 1
END
  # Only go-development-guide should be required (applies-to: *.go, no package-imports).
  # Stage it as read so the hook allows.
  stageTranscriptWithReads $dir/transcript.jsonl "$dir/guides/go-development-guide.md"
  local input
  input=$(mkInputJson Edit $dir/scope/pkg/new.go $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert — should allow (go-dev was Read; fluentfp not required since no sibling has the import)
  # NOTE: the staged guide set doesn't include go-development-guide; sub it in.
  cat >$dir/guides/go-development-guide.md <<'END'
---
applies-to: ["**/*.go"]
summary: "Go practices."
---
END
  runHook got_ rc $dir/guides $dir/scope/ "$input"
  tesht.AssertRC $rc 0
}

test_main_malformedGuideSkipsWithWarning() {
  ## arrange
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  # bash-style-guide is valid; malformed.md has summary but no applies-to.
  stageTranscriptWithReads $dir/transcript.jsonl "$dir/guides/bash-style-guide.md"
  local input
  input=$(mkInputJson Edit $dir/scope/foo.bash $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert — bash file is allowed (its guide was Read), AND the schema-error WARNING surfaces
  tesht.AssertRC $rc 0
  [[ $got_ == *schema-error* && $got_ == *malformed.md* ]] || {
    tesht.Log "expected schema-error WARNING for malformed.md; got: $got_"
    return 1
  }
}

test_main_testFileRequiresKhorikov() {
  ## arrange — *_test.bash file; both bash-style and khorikov apply
  stageNoopEvtctl
  local dir
  tesht.MktempDir dir || return 128
  stageGuides $dir/guides
  : >$dir/transcript.jsonl
  local input
  input=$(mkInputJson Write $dir/scope/foo_test.bash $dir/transcript.jsonl)

  ## act
  local got_ rc
  runHook got_ rc $dir/guides $dir/scope/ "$input"

  ## assert — both guides required
  tesht.AssertRC $rc 2
  [[ $got_ == *bash-style-guide.md* && $got_ == *khorikov-unit-testing-guide.md* ]] || {
    tesht.Log "expected both bash-style + khorikov in stderr; got: $got_"
    return 1
  }
}

test_main_multiScopeAnyPrefixMatches() {
  local -A case1=([name]='first prefix'  [scopeDir]='scope')
  local -A case2=([name]='second prefix' [scopeDir]='altScope')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"
    stageNoopEvtctl
    local dir
    tesht.MktempDir dir || return 128
    stageGuides $dir/guides
    : >$dir/transcript.jsonl
    local input
    input=$(mkInputJson Edit $dir/$scopeDir/foo.bash $dir/transcript.jsonl)
    local got_ rc
    runHook got_ rc $dir/guides "$dir/scope/:$dir/altScope/" "$input"
    tesht.AssertRC $rc 2
    [[ $got_ == *BLOCKED* && $got_ == *bash-style-guide.md* ]] || {
      tesht.Log "expected BLOCKED ($scopeDir); got: $got_"
      return 1
    }
  }

  tesht.Run ${!case@}
}
