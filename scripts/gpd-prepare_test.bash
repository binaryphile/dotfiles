#!/usr/bin/env bash

# Tests for scripts/gpd-prepare — pangp gpd.service ExecStartPre.
#
# Output-state-based: assertions on the post-run shape of
# $STATE_DIRECTORY (which entries are symlinks, which are writable
# files, content of copies). No mocks; uses tesht.MktempDir for
# isolated fake $PANGP_RO + $STATE_DIRECTORY trees.
#
# NIX_STORE_PREFIX env-var override is the key affordance: tests
# cannot literally create /nix/store/... paths under tmpdir, so
# the script's predicate is parameterized.

# fixture helper: populate $PANGP_RO with a minimal pangp-shaped
# .deb file set. Caller passes the tmpdir.
populatePangpRo() {
  local ro=$1
  mkdir -p $ro $ro/sign
  echo "libwaapi content"   > $ro/libwaapi.so
  echo "cert content"        > $ro/cc.cer
  echo "log prototype"       > $ro/PanGPS.log
  echo "log old prototype"   > $ro/PanGPS.log.old
  echo "hippolicy proto"     > $ro/HipPolicy.dat
  echo "ipt proto"           > $ro/ipt_nat.txt
  echo "sig"                 > $ro/sign/PanGPS.sig
}


## fresh-state-dir classification

test_freshStateDir() {
  local Dir
  tesht.MktempDir Dir || return 128
  local ro=$Dir/src state=$Dir/state nix=$Dir/fake-nix-store
  populatePangpRo $ro

  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  # read-only artifacts → symlinks
  local libwaapi_type cc_type
  [[ -L $state/libwaapi.so ]] && libwaapi_type=symlink || libwaapi_type=not-symlink
  [[ -L $state/cc.cer ]]      && cc_type=symlink      || cc_type=not-symlink

  # runtime-mutable artifacts → writable copies (not symlinks)
  local panlog_type panlog_content
  [[ -L $state/PanGPS.log ]]  && panlog_type=symlink  || panlog_type=writable-copy
  [[ -w $state/PanGPS.log ]] || panlog_type=$panlog_type-not-writable
  panlog_content=$(cat $state/PanGPS.log)

  # sign/ subdir contents → symlinks
  local sign_type
  [[ -L $state/sign/PanGPS.sig ]] && sign_type=symlink || sign_type=not-symlink

  tesht.AssertGot "$libwaapi_type|$cc_type|$panlog_type|$panlog_content|$sign_type" \
                  "symlink|symlink|writable-copy|log prototype|symlink"
}


## broken-symlink replacement (the #34261 defect class)

test_brokenNixStoreSymlinkReplaced() {
  local Dir
  tesht.MktempDir Dir || return 128
  local ro=$Dir/src state=$Dir/state nix=$Dir/fake-nix-store
  populatePangpRo $ro

  # Set up the #34261 defect shape: PanGPS.log symlinked to a
  # readable-but-readonly file under the fake-nix-store path.
  mkdir -p $nix
  echo "old-stale-log" > $nix/PanGPS.log
  chmod 0444 $nix/PanGPS.log
  mkdir -p $state
  ln -s $nix/PanGPS.log $state/PanGPS.log

  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  local result_type result_content
  [[ -L $state/PanGPS.log ]]  && result_type=symlink || result_type=writable-copy
  [[ -w $state/PanGPS.log ]] || result_type=$result_type-not-writable
  result_content=$(cat $state/PanGPS.log)

  # Expected: the broken nix-store symlink got removed; .deb's
  # prototype content is now at PanGPS.log as a writable copy.
  tesht.AssertGot "$result_type|$result_content" "writable-copy|log prototype"
}


## read-only file with nix-store symlink is preserved

test_readOnlyNixStoreSymlinkPreserved() {
  local Dir
  tesht.MktempDir Dir || return 128
  local ro=$Dir/src state=$Dir/state nix=$Dir/fake-nix-store
  populatePangpRo $ro

  # Pre-create libwaapi.so as a nix-store-targeted symlink (e.g.,
  # from a prior gpd-prepare run — read-only files SHOULD remain
  # symlinks under the new classification).
  mkdir -p $nix
  echo "library bytes" > $nix/libwaapi.so
  chmod 0444 $nix/libwaapi.so
  mkdir -p $state
  ln -s $nix/libwaapi.so $state/libwaapi.so

  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  local target
  [[ -L $state/libwaapi.so ]] && target=$(readlink $state/libwaapi.so) || target=not-symlink

  # Expected: existing symlink preserved (case-else branch's
  # [[ -e $name ]] short-circuit fires before any classification).
  tesht.AssertGot "$target" "$nix/libwaapi.so"
}


## writable file with operator state is preserved

test_writableFilePreserved() {
  local Dir
  tesht.MktempDir Dir || return 128
  local ro=$Dir/src state=$Dir/state nix=$Dir/fake-nix-store
  populatePangpRo $ro

  # Operator has written runtime state to PanGPS.log; gpd-prepare
  # must NOT clobber it.
  mkdir -p $state
  echo "operator log entry" > $state/PanGPS.log

  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  tesht.AssertGot "$(cat $state/PanGPS.log)" "operator log entry"
}


## real-target symlink (non-nix-store) is preserved

test_realTargetSymlinkPreserved() {
  local Dir
  tesht.MktempDir Dir || return 128
  local ro=$Dir/src state=$Dir/state nix=$Dir/fake-nix-store
  populatePangpRo $ro

  # Operator has redirected PanGPS.log to an external collector
  # path (not in nix-store); predicate must NOT replace it.
  local collector=$Dir/external-collector
  mkdir -p $collector
  echo "collector content" > $collector/pangps.log
  mkdir -p $state
  ln -s $collector/pangps.log $state/PanGPS.log

  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  local target
  [[ -L $state/PanGPS.log ]] && target=$(readlink $state/PanGPS.log) || target=not-symlink

  tesht.AssertGot "$target" "$collector/pangps.log"
}


## stale broken symlink to nix-store when $PANGP_RO no longer ships the file

# Regression test for the #34261 v2 architecture revision (post-impl
# /loopback 3a→1c interaction id=34743): the production failure mode
# is a /var/lib/globalprotect/PanGPS.log symlink to an OLD nix-store
# path where the .deb shipped a *.log prototype; the NEW pangp .deb
# extraction doesn't ship *.log prototypes, so the main loop iterating
# $PANGP_RO/* never sees PanGPS.log and never removes the stale
# symlink. The pre-scan in gpd-prepare handles this case.
test_staleSymlinkWithoutSourcePrototype() {
  local Dir
  tesht.MktempDir Dir || return 128
  local ro=$Dir/src state=$Dir/state nix=$Dir/fake-nix-store
  # $PANGP_RO has NO PanGPS.log (mimics new .deb's no-log-prototypes
  # extraction shape).
  mkdir -p $ro $ro/sign
  echo "lib content" > $ro/libwaapi.so

  # Pre-existing stale symlink pointing at fake-nix-store (the file
  # there might or might not exist — broken-symlink edge case).
  mkdir -p $nix $state
  echo "stale log proto" > $nix/PanGPS.log
  chmod 0444 $nix/PanGPS.log
  ln -s $nix/PanGPS.log $state/PanGPS.log

  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  # Expected: pre-scan removed the stale symlink. Since $PANGP_RO
  # has no PanGPS.log, the main loop doesn't recreate the file.
  # Result: $state/PanGPS.log is absent (PanGPS will create at runtime).
  local result
  if [[ -L $state/PanGPS.log ]]; then result=symlink
  elif [[ -e $state/PanGPS.log ]]; then result=file
  else result=absent
  fi
  tesht.AssertGot "$result" "absent"
}


## idempotency: second run is a no-op

test_idempotent() {
  local Dir
  tesht.MktempDir Dir || return 128
  local ro=$Dir/src state=$Dir/state nix=$Dir/fake-nix-store
  populatePangpRo $ro

  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  # Capture state after first run.
  local first_snapshot
  first_snapshot=$(cd $state && find . -maxdepth 2 -printf '%y %p %l\n' 2>/dev/null | sort)

  # Run again.
  PANGP_RO=$ro STATE_DIRECTORY=$state NIX_STORE_PREFIX=$nix \
    "$PWD/scripts/gpd-prepare"

  local second_snapshot
  second_snapshot=$(cd $state && find . -maxdepth 2 -printf '%y %p %l\n' 2>/dev/null | sort)

  tesht.AssertGot "$second_snapshot" "$first_snapshot"
}
