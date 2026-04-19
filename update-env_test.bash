source ./update-env   # defines NL=$'\n'

## functions

# test_each tests that each applies functions to arguments.
# Subtests are run with tesht.Run.
test_each() {
  local -A case1=(
    [name]='capitalize a list of words'

    [command]="each '_() { echo \${1^}; }; _'"
    [inputs]='(foo bar baz)'
    [wants]="(Foo Bar Baz)"
  )

  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(stream "${inputs[@]}" | eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}each: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    local want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_keepIf tests that keepIf filters lines by a pattern.
# Subtests are run with tesht.Run.
test_keepIf() {
  local -A case1=(
    [name]='keep only lines that match the pattern'

    [command]="keepIf '_() { [[ \$1 == a* ]]; }; _'"
    [inputs]='(apple banana apricot)'
    [wants]='(apple apricot)'
  )

  local -A case2=(
    [name]='keep only exact matches'

    [command]="keepIf '_() { [[ \$1 == cat ]]; }; _'"
    [inputs]='(cat catalog bobcat)'
    [wants]='(cat)'
  )

  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(stream "${inputs[@]}" | eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}keepIf: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    local want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}

# test_map tests that map applies a command to each line.
# Subtests are run with tesht.Run.
test_map() {
  local -A case1=(
    [name]='prefix each line with a label'

    [command]="map line 'line: \$line'"
    [inputs]='(alpha beta)'
    [wants]="('line: alpha' 'line: beta')"
  )

  local -A case2=(
    [name]='double each numeric line'

    [command]="map line '\$(( line * 2 ))'"
    [inputs]='(1 2 3)'
    [wants]='(2 4 6)'
  )


  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(stream "${inputs[@]}" | eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}map: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    local want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}


# test_stream tests that stream splits space-separated input into separate lines
# Subtests are run with tesht.Run.
test_stream() {
  local -A case1=(
    [name]='split arguments into separate lines'

    [command]='stream foo bar baz'
    [want]=$'foo\nbar\nbaz'
  )

  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}stream: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}

## credential bootstrap helpers

# test_pubFingerprint tests fingerprint extraction from .pub files.
test_pubFingerprint() {
  local -A case1=(
    [name]='extract fingerprint from valid pub file'
    [wantNonEmpty]=1
  )
  local -A case2=(
    [name]='return empty for missing file'
    [wantNonEmpty]=0
  )
  local -A case3=(
    [name]='return empty for empty file'
    [wantNonEmpty]=0
  )
  local -A case4=(
    [name]='return empty for malformed file'
    [wantNonEmpty]=0
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local dir got
    tesht.MktempDir dir || return 128
    case $casename in
      case1)
        ssh-keygen -t ed25519 -f "$dir/key" -N "" -q
        got=$(pubFingerprint "$dir/key.pub")
        ;;
      case2)
        got=$(pubFingerprint "$dir/nonexistent.pub")
        ;;
      case3)
        touch "$dir/empty.pub"
        got=$(pubFingerprint "$dir/empty.pub")
        ;;
      case4)
        echo "not a key" > "$dir/bad.pub"
        got=$(pubFingerprint "$dir/bad.pub")
        ;;
    esac
    if (( wantNonEmpty )); then
      [[ -n "$got" ]] || { echo "${NL}pubFingerprint: got empty, want non-empty"; return 1; }
    else
      [[ -z "$got" ]] || { echo "${NL}pubFingerprint: got=$got, want empty"; return 1; }
    fi
  }

  tesht.Run ${!case@}
}

# test_installKey tests atomic key pair installation.
test_installKey() {
  local -A case1=([name]='install private key and pub')
  local -A case2=([name]='install private key without pub')
  local -A case3=([name]='fail on missing source')
  local -A case4=([name]='overwrite preserves existing on source-no-pub')
  local -A case5=([name]='removes stale dst.pub when source has no pub')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local dir rc
    tesht.MktempDir dir || return 128
    case $casename in
      case1)
        ssh-keygen -t ed25519 -f "$dir/src" -N "" -q
        installKey "$dir/src" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 ))          || { echo "${NL}installKey failed: rc=$rc"; return 1; }
        [[ -f "$dir/dst" ]]     || { echo "${NL}dst missing"; return 1; }
        [[ -f "$dir/dst.pub" ]] || { echo "${NL}dst.pub missing"; return 1; }
        local privPerms pubPerms
        privPerms=$(stat -c %a "$dir/dst")
        pubPerms=$(stat -c %a "$dir/dst.pub")
        [[ $privPerms == 600 ]] || { echo "${NL}dst perms=$privPerms, want=600"; return 1; }
        [[ $pubPerms == 644 ]]  || { echo "${NL}dst.pub perms=$pubPerms, want=644"; return 1; }
        ;;
      case2)
        ssh-keygen -t ed25519 -f "$dir/src" -N "" -q
        rm -f "$dir/src.pub"
        installKey "$dir/src" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 ))             || { echo "${NL}installKey failed: rc=$rc"; return 1; }
        [[ -f "$dir/dst" ]]       || { echo "${NL}dst missing"; return 1; }
        [[ ! -f "$dir/dst.pub" ]] || { echo "${NL}dst.pub should not exist"; return 1; }
        ;;
      case3)
        installKey "$dir/nonexistent" "$dir/dst" && rc=$? || rc=$?
        (( rc != 0 ))            || { echo "${NL}should fail for missing src"; return 1; }
        [[ ! -f "$dir/dst" ]]    || { echo "${NL}dst should not exist"; return 1; }
        ;;
      case4)
        # Existing dst key should be preserved when overwriting with source that has no .pub
        ssh-keygen -t ed25519 -f "$dir/old" -N "" -q
        installKey "$dir/old" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 )) || { echo "${NL}initial install failed"; return 1; }
        # Now overwrite with a new key that has no .pub
        ssh-keygen -t ed25519 -f "$dir/new" -N "" -q
        rm -f "$dir/new.pub"
        installKey "$dir/new" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 )) || { echo "${NL}overwrite failed"; return 1; }
        [[ -f "$dir/dst" ]] || { echo "${NL}dst missing after overwrite"; return 1; }
        # Stale .pub from old key should be removed
        [[ ! -f "$dir/dst.pub" ]] || { echo "${NL}stale dst.pub should have been removed"; return 1; }
        ;;
      case5)
        # Existing dst.pub should be removed when new source has no .pub
        ssh-keygen -t ed25519 -f "$dir/src" -N "" -q
        installKey "$dir/src" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 )) || return 1
        [[ -f "$dir/dst.pub" ]] || return 1
        # Install again without .pub
        rm -f "$dir/src.pub"
        installKey "$dir/src" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 )) || return 1
        [[ ! -f "$dir/dst.pub" ]] || { echo "${NL}dst.pub should be removed"; return 1; }
        ;;
    esac
  }

  tesht.Run ${!case@}
}

# test_sshKeyAction tests the pure decision function for SSH key restore.
# Each test builds a state associative array and asserts the returned action.
# No I/O, no filesystem -- pure decision logic in Khorikov's "valuable" quadrant.
# State inputs: repoHasPub, repoFp, localExists, localFp, cacheExists, cacheFp,
#   hasTty, opReady, opHasItem.
test_sshKeyAction() {
  local -A case1=(
    [name]='local key matches repo -- present'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]='SHA256:abc'
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='present'
  )
  local -A case2=(
    [name]='local key mismatches repo -- collision'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]='SHA256:xyz'
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='collision'
  )
  local -A case3=(
    [name]='unverifiable local + cache available -- backup then cache'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:abc' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='backup_then_cache'
  )
  local -A case4=(
    [name]='unverifiable local + no cache, op available -- backup then op'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=1 [opHasItem]=1
    [want]='backup_then_op'
  )
  local -A case5=(
    [name]='unverifiable local + no cache, no op -- backup then fail'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='backup_then_fail'
  )
  local -A case6=(
    [name]='local key exists, no repo pub -- capture'
    [repoHasPub]=0 [repoFp]=''
    [localExists]=1 [localFp]='SHA256:abc'
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='capture_to_repo'
  )
  local -A case7=(
    [name]='no local, cache matches repo -- restore from cache'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:abc' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='restore_from_cache'
  )
  local -A case8=(
    [name]='no local, stale cache, op available -- restore from op'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:old' [hasTty]=1
    [opReady]=1 [opHasItem]=1
    [want]='restore_from_op'
  )
  local -A case9=(
    [name]='no local, no cache, op available -- restore from op'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=1 [opHasItem]=1
    [want]='restore_from_op'
  )
  local -A case10=(
    [name]='nothing anywhere, has tty -- generate'
    [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='generate'
  )
  local -A case11=(
    [name]='nothing anywhere, no tty -- missing noninteractive'
    [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=0
    [opReady]=0 [opHasItem]=0
    [want]='missing_noninteractive'
  )
  local -A case12=(
    [name]='malformed repo pub -- error'
    [repoHasPub]=1 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='error_malformed_pub'
  )
  local -A case13=(
    [name]='cache valid, no repo pub -- restore from cache'
    [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:abc' [hasTty]=1
    [opReady]=0 [opHasItem]=0
    [want]='restore_from_cache'
  )
  local -A case14=(
    [name]='cache empty fp, op available -- restore from op'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='' [hasTty]=1
    [opReady]=1 [opHasItem]=1
    [want]='restore_from_op'
  )
  local -A case15=(
    [name]='unverifiable local + stale cache, op available -- backup then op'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:old' [hasTty]=1
    [opReady]=1 [opHasItem]=1
    [want]='backup_then_op'
  )
  local -A case16=(
    [name]='op ready but no item, no tty -- missing noninteractive'
    [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=0
    [opReady]=1 [opHasItem]=0
    [want]='missing_noninteractive'
  )
  local -A case17=(
    [name]='op ready but no item, has tty -- generate'
    [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=1 [opHasItem]=0
    [want]='generate'
  )
  local -A case18=(
    [name]='pub exists without local -- no error, fall through to op'
    [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1
    [opReady]=1 [opHasItem]=1
    [want]='restore_from_op'
  )

  subtest() {
    local casename=$1

    local got
    got=$(sshKeyAction "$casename")

    eval "$(tesht.Inherit "$casename")"
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_restoreSecretsTierSelection tests that restoreSecrets skips restore
# when local secrets exist, and prints setup message when nothing is available.
test_restoreSecretsTierSelection() {
  local -A case1=(
    [name]='local secrets exist -- skip restore'
  )
  local -A case2=(
    [name]='nothing available -- print setup message'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local dir
    tesht.MktempDir dir || return 128
    HOME=$dir
    CrostiniDir="$dir/crostini"
    CrostiniDirL="$dir/crostini"
    mkdir -p "$dir/secrets"
    lib.MachineHostname() { echo testhost; }

    local got rc
    case $casename in
      case1)
        echo "token" > "$dir/secrets/stash.key"
        got=$(restoreSecrets 2>&1) && rc=$? || rc=$?
        (( rc == 0 )) || { echo "rc=$rc, want 0"; return 1; }
        [[ "$got" != *"Restoring"* ]] || { echo "should not restore when local exists"; return 1; }
        ;;
      case2)
        got=$(restoreSecrets 2>&1) && rc=$? || rc=$?
        (( rc == 0 )) || { echo "rc=$rc, want 0"; return 1; }
        [[ "$got" == *"No secrets for testhost"* ]] || { echo "should print setup message, got: $got"; return 1; }
        ;;
    esac
  }

  tesht.Run ${!case@}
}

# test_crostiniHostname tests crostiniHostnameSetup: writes hostname to
# $CrostiniDir/hostname, validates input, requires backing storage.
test_crostiniHostname() {
  local -A case1=(
    [name]='writes hostname arg to file'
    [hostname]='calderon'
    [existing]=''
    [backingExists]=1
    [wantRc]=0
    [wantContent]='calderon'
  )
  local -A case2=(
    [name]='preserves existing hostname on re-run without arg'
    [hostname]=''
    [existing]='calliope'
    [backingExists]=1
    [wantRc]=0
    [wantContent]='calliope'
  )
  local -A case3=(
    [name]='rejects invalid hostname'
    [hostname]='INVALID'
    [existing]=''
    [backingExists]=1
    [wantRc]=1
  )
  local -A case4=(
    [name]='fails without backing storage'
    [hostname]='calderon'
    [existing]=''
    [backingExists]=0
    [wantRc]=1
  )
  local -A case5=(
    [name]='first run without hostname is fatal'
    [hostname]=''
    [existing]=''
    [backingExists]=1
    [wantRc]=1
  )
  local -A case6=(
    [name]='creates CrostiniDir when backing exists'
    [hostname]='calderon'
    [existing]=''
    [backingExists]=1
    [wantRc]=0
    [wantDir]=1
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128
    local testBacking=$dir/backing
    local testCrostiniDir=$testBacking/crostini

    if (( backingExists )); then
      mkdir -p "$testBacking"
    fi
    if [[ -n $existing ]]; then
      mkdir -p "$testCrostiniDir"
      echo "$existing" > "$testCrostiniDir/hostname"
    fi

    ## act
    local got rc
    got=$(CrostiniDir=$testCrostiniDir CrostiniBacking=$testBacking Hostname=$hostname crostiniHostnameSetup 2>&1) && rc=$? || rc=$?

    ## assert
    tesht.AssertRC $rc $wantRc || return 1
    if [[ -n ${wantContent:-} ]]; then
      local actual
      actual=$(< "$testCrostiniDir/hostname")
      tesht.AssertGot "$actual" "$wantContent" || return 1
    fi
    if [[ -n ${wantDir:-} ]]; then
      [[ -d $testCrostiniDir ]] || { echo "CrostiniDir not created"; return 1; }
    fi
  }

  tesht.Run ${!case@}
}

# test_withSecret tests the with-secret wrapper.
test_withSecret() {
  local dir
  tesht.MktempDir dir || return 128

  echo "mysecret" > "$dir/secret.txt"

  # with-secret should inject the secret as an env var into the child
  local got
  got=$(~/dotfiles/scripts/with-secret MY_TOKEN "$dir/secret.txt" printenv MY_TOKEN)
  [[ "$got" == "mysecret" ]] || {
    echo "with-secret: got=${got@Q}, want='mysecret'"
    return 1
  }
}

# test_authPreflight tests that authPreflight produces correct diagnostics.
# When the key is not in the agent, it should report that and skip registry
# checks -- not produce misleading "key not registered" messages.
# ssh_add and ssh are inter-system dependencies (external commands), mocked
# per Khorikov via function-name DI.
test_authPreflight() {
  local -A case1=(
    [name]='key not in agent -- reports not in agent, skips registry checks'
  )
  local -A case2=(
    [name]='key in agent, registry rejects -- reports not registered'
  )
  local -A case3=(
    [name]='no key file -- reports no SSH key'
  )
  local -A case4=(
    [name]='wrong key in agent -- reports key not in agent'
  )

  # Mock functions for DI -- assigned to ssh_add, ssh, ip via dynamic scoping
  mockSshAddEmpty() { echo "The agent has no identities."; return 1; }
  mockSshAddLoaded() { echo "256 SHA256:abc $HOME/.ssh/id_ed25519 (ED25519)"; return 0; }
  mockSshAddWrongKey() { echo "256 SHA256:other /home/ted/.ssh/some_other_key (ED25519)"; return 0; }
  mockSshKeygen() { echo "256 SHA256:abc $1 (ED25519)"; }
  mockSshRejected() { echo "Permission denied (publickey)."; return 255; }

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128

    local got rc
    case $casename in
      case1)
        mkdir -p "$dir/.ssh"
        touch "$dir/.ssh/id_ed25519"
        touch "$dir/.ssh/id_ed25519.pub"
        local ssh_add=mockSshAddEmpty
        local ssh=mockSshRejected
        local ip=false

        ## act
        got=$(HOME=$dir authPreflight 2>&1) && rc=$? || rc=$?

        ## assert
        [[ $got == *"key not in agent"* ]] || {
          echo "should report 'key not in agent', got: $got"
          return 1
        }
        [[ $got != *"not registered"* ]] || {
          echo "should not check registries when key not in agent, got: $got"
          return 1
        }
        ;;
      case2)
        mkdir -p "$dir/.ssh"
        touch "$dir/.ssh/id_ed25519"
        touch "$dir/.ssh/id_ed25519.pub"
        local ssh_add=mockSshAddLoaded
        local ssh_keygen=mockSshKeygen
        local ssh=mockSshRejected
        local ip=false

        ## act
        got=$(HOME=$dir authPreflight 2>&1) && rc=$? || rc=$?

        ## assert
        [[ $got == *"not registered"* ]] || {
          echo "should report 'not registered', got: $got"
          return 1
        }
        ;;
      case3)
        mkdir -p "$dir/.ssh"
        local ssh_add=true
        local ssh=true
        local ip=false

        ## act
        got=$(HOME=$dir authPreflight 2>&1) && rc=$? || rc=$?

        ## assert
        [[ $got == *"No SSH key"* ]] || {
          echo "should report 'No SSH key', got: $got"
          return 1
        }
        ;;
      case4)
        # Agent has a key, but not the target key
        mkdir -p "$dir/.ssh"
        touch "$dir/.ssh/id_ed25519"
        touch "$dir/.ssh/id_ed25519.pub"
        local ssh_add=mockSshAddWrongKey
        local ssh=mockSshRejected
        local ip=false
        local ssh_keygen=mockSshKeygen

        ## act
        got=$(HOME=$dir authPreflight 2>&1) && rc=$? || rc=$?

        ## assert
        [[ $got == *"key not in agent"* ]] || {
          echo "wrong key loaded should report 'key not in agent', got: $got"
          return 1
        }
        [[ $got != *"not registered"* ]] || {
          echo "should not check registries with wrong key, got: $got"
          return 1
        }
        ;;
    esac
  }

  tesht.Run ${!case@}
}

# test_signingKeyAction tests the pure decision function that maps filesystem
# state to a signing key action. No mocks -- input is state, output is action string.
test_signingKeyAction() {
  local -A case1=(
    [name]='local exists, sidecar matches -- present'
    [localExists]=1 [localFp]=SHA256:abc
    [repoHasPub]=1 [repoFp]=SHA256:abc
    [opReady]=0 [opHasItem]=0
    [want]=present
  )
  local -A case2=(
    [name]='local exists, sidecar missing -- present_no_sidecar'
    [localExists]=1 [localFp]=SHA256:abc
    [repoHasPub]=0 [repoFp]=''
    [opReady]=0 [opHasItem]=0
    [want]=present_no_sidecar
  )
  local -A case3=(
    [name]='local exists, fingerprints differ -- collision'
    [localExists]=1 [localFp]=SHA256:abc
    [repoHasPub]=1 [repoFp]=SHA256:xyz
    [opReady]=0 [opHasItem]=0
    [want]=collision
  )
  local -A case4=(
    [name]='no local, op authenticated, item exists -- restore_from_op'
    [localExists]=0 [localFp]=''
    [repoHasPub]=0 [repoFp]=''
    [opReady]=1 [opHasItem]=1
    [want]=restore_from_op
  )
  local -A case5=(
    [name]='no local, op not available -- generate'
    [localExists]=0 [localFp]=''
    [repoHasPub]=0 [repoFp]=''
    [opReady]=0 [opHasItem]=0
    [want]=generate
  )
  local -A case6=(
    [name]='no local, op authenticated, item missing -- generate'
    [localExists]=0 [localFp]=''
    [repoHasPub]=0 [repoFp]=''
    [opReady]=1 [opHasItem]=0
    [want]=generate
  )

  subtest() {
    local casename=$1

    local got
    got=$(signingKeyAction "$casename")

    eval "$(tesht.Inherit "$casename")"
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_restoreSigningKey tests the controller (dispatcher) for signing key
# restore. Per Khorikov, controller tests are integration tests -- one happy
# path per action, plus edge cases at system boundaries. Decision logic is
# tested purely in test_signingKeyAction above.
# op, ssh_keygen are inter-system dependencies, mocked via DI.
test_restoreSigningKey() {
  local -A case1=(
    [name]='present_no_sidecar -- creates repo sidecar'
  )
  local -A case2=(
    [name]='restore_from_op -- creates local key from 1Password'
  )
  local -A case3=(
    [name]='generate -- creates local key when op unavailable'
  )
  local -A case4=(
    [name]='restore_from_op fails -- returns error'
  )

  mockSshKeygenGenerate() {
    local args_=("$@") path
    for (( i=0; i < ${#args_[@]}; i++ )); do
      [[ ${args_[$i]} == -f ]] && { path=${args_[$((i+1))]}; break; }
    done
    [[ -n ${path:-} ]] || return 1
    echo "-----BEGIN OPENSSH PRIVATE KEY-----" >$path
    echo "fake-signing-key" >>$path
    echo "-----END OPENSSH PRIVATE KEY-----" >>$path
    chmod 600 "$path"
    echo "ssh-ed25519 AAAA-mock-signing ted@test-signing" >"$path.pub"
    chmod 644 "$path.pub"
  }

  mockSshKeygen() {
    case $1 in
      -y ) echo "ssh-ed25519 AAAA-mock-signing ted@test-signing";;
      -lf ) echo "256 SHA256:signingfp $2 (ED25519)";;
      * ) mockSshKeygenGenerate "$@";;
    esac
  }

  mockOpAuthenticated() {
    case $1 in
      whoami ) return 0;;
      item ) return 0;;
      read )
        shift
        local outfile
        while (( $# )); do
          if [[ $1 == --out-file ]]; then
            outfile=$2; shift 2; continue
          fi
          shift
        done
        [[ -n ${outfile:-} ]] || return 1
        echo "-----BEGIN OPENSSH PRIVATE KEY-----" >$outfile
        echo "fake-1password-key" >>$outfile
        echo "-----END OPENSSH PRIVATE KEY-----" >>$outfile
        chmod 600 "$outfile"
        ;;
    esac
  }

  mockOpReadFails() {
    case $1 in
      whoami ) return 0;;
      item ) return 0;;
      read ) return 1;;
    esac
  }

  mockOpNotInstalled() { return 127; }

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128

    mkdir -p "$dir/.ssh"
    mkdir -p "$dir/dotfiles/ssh"
    lib.MachineHostname() { echo testhost; }

    local got rc
    case $casename in
      case1)
        # Local key exists, no repo sidecar -> should create sidecar
        echo "fake-private-key" >"$dir/.ssh/id_ed25519_signing"
        echo "ssh-ed25519 AAAA-mock-signing ted@test-signing" >"$dir/.ssh/id_ed25519_signing.pub"
        local ssh_keygen=mockSshKeygen
        local op=mockOpNotInstalled

        ## act
        got=$(HOME=$dir restoreSigningKey 2>&1) && rc=$? || rc=$?

        ## assert
        (( rc == 0 )) || { echo "rc=$rc, want 0: $got"; return 1; }
        [[ -f $dir/dotfiles/ssh/id_ed25519_signing_testhost.pub ]] || {
          echo "should create repo sidecar"; return 1
        }
        ;;

      case2)
        # No local key, op has it -> should create local key + sidecar
        local op=mockOpAuthenticated
        local ssh_keygen=mockSshKeygen

        ## act
        got=$(HOME=$dir restoreSigningKey 2>&1) && rc=$? || rc=$?

        ## assert
        (( rc == 0 )) || { echo "rc=$rc, want 0: $got"; return 1; }
        [[ -f $dir/.ssh/id_ed25519_signing ]] || {
          echo "should create local signing key"; return 1
        }
        [[ -f $dir/dotfiles/ssh/id_ed25519_signing_testhost.pub ]] || {
          echo "should create repo sidecar"; return 1
        }
        ;;

      case3)
        # No local key, op unavailable -> should generate
        local op=mockOpNotInstalled
        local ssh_keygen=mockSshKeygenGenerate

        ## act
        got=$(HOME=$dir restoreSigningKey 2>&1) && rc=$? || rc=$?

        ## assert
        (( rc == 0 )) || { echo "rc=$rc, want 0: $got"; return 1; }
        [[ -f $dir/.ssh/id_ed25519_signing ]] || {
          echo "should generate local signing key"; return 1
        }
        [[ -f $dir/dotfiles/ssh/id_ed25519_signing_testhost.pub ]] || {
          echo "should create repo sidecar"; return 1
        }
        ;;

      case4)
        # op read fails -> should return error, not generate
        local op=mockOpReadFails
        local ssh_keygen=mockSshKeygen

        ## act
        got=$(HOME=$dir restoreSigningKey 2>&1) && rc=$? || rc=$?

        ## assert
        (( rc != 0 )) || { echo "rc=$rc, want nonzero: $got"; return 1; }
        [[ ! -f $dir/.ssh/id_ed25519_signing ]] || {
          echo "should not create key on op read failure"; return 1
        }
        ;;
    esac
  }

  tesht.Run ${!case@}
}

# test_verifySha256 tests the shared hash verification function.
# Uses real sha256sum -- this is a thin wrapper, not worth mocking.
test_verifySha256() {
  local -A case1=(
    [name]='correct hash -- passes'
  )
  local -A case2=(
    [name]='wrong hash -- fails'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128
    echo "test content" >"$dir/file"
    local correctHash
    correctHash=$(sha256sum "$dir/file" | awk '{print $1}')

    local got rc
    case $casename in
      case1)
        ## act
        got=$(verifySha256 "$correctHash" "$dir/file" 2>&1) && rc=$? || rc=$?
        ## assert
        (( rc == 0 )) || { echo "rc=$rc, want 0: $got"; return 1; }
        ;;
      case2)
        ## act
        got=$(verifySha256 "0000000000000000000000000000000000000000000000000000000000000000" "$dir/file" 2>&1) && rc=$? || rc=$?
        ## assert
        (( rc != 0 )) || { echo "rc=$rc, want nonzero"; return 1; }
        ;;
    esac
  }

  tesht.Run ${!case@}
}

# test_nixInstallerAsset tests the pure decision function that maps OS/arch
# to installer binary name and hash. No mocks -- input is strings, output is
# strings.
test_nixInstallerAsset() {
  local -A case1=(
    [name]='Linux x86_64'
    [os]=Linux
    [arch]=x86_64
    [wantBinary]=nix-installer-x86_64-linux
    [wantRc]=0
  )
  local -A case2=(
    [name]='Linux aarch64'
    [os]=Linux
    [arch]=aarch64
    [wantBinary]=nix-installer-aarch64-linux
    [wantRc]=0
  )
  local -A case3=(
    [name]='Darwin arm64'
    [os]=Darwin
    [arch]=arm64
    [wantBinary]=nix-installer-aarch64-darwin
    [wantRc]=0
  )
  local -A case4=(
    [name]='unsupported platform -- returns error'
    [os]=FreeBSD
    [arch]=x86_64
    [wantBinary]=''
    [wantRc]=1
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local got rc
    got=$(nixInstallerAsset "$os" "$arch" 2>/dev/null) && rc=$? || rc=$?

    (( rc == wantRc )) || { echo "rc=$rc, want $wantRc"; return 1; }
    if (( wantRc == 0 )); then
      local gotBinary
      gotBinary=$(echo "$got" | awk '{print $1}')
      [[ $gotBinary == "$wantBinary" ]] || {
        echo "binary=$gotBinary, want $wantBinary"; return 1
      }
      # hash should be a 64-char hex string
      local gotHash
      gotHash=$(echo "$got" | awk '{print $2}')
      [[ $gotHash =~ ^[0-9a-f]{64}$ ]] || {
        echo "hash format invalid: $gotHash"; return 1
      }
    fi
  }

  tesht.Run ${!case@}
}

# test_installNix tests the download-verify-execute pipeline for the
# Determinate Nix installer. Controller test -- mocks curl, sha256sum, and
# uname (inter-system dependencies), asserts observable behavior.
test_installNix() {
  local -A case1=(
    [name]='happy path -- downloads, verifies hash, runs installer with correct argv'
    [mockCurl]=nixCurlOk
    [mockHash]=nixHashOk
    [wantRc]=0
  )
  local -A case2=(
    [name]='download failure -- returns error, does not execute'
    [mockCurl]=nixCurlFail
    [mockHash]=nixHashOk
    [wantRc]=1
  )
  local -A case3=(
    [name]='hash mismatch -- returns error, does not execute'
    [mockCurl]=nixCurlOk
    [mockHash]=nixHashFail
    [wantRc]=1
  )
  local -A case4=(
    [name]='installer nonzero exit -- propagates error'
    [mockCurl]=nixCurlOkFailInstaller
    [mockHash]=nixHashOk
    [wantRc]=42
  )
  local -A case5=(
    [name]='unsupported platform -- returns error without download'
    [mockCurl]=nixCurlOk
    [mockHash]=nixHashOk
    [mockUnameS]=FreeBSD
    [wantRc]=1
  )
  local -A case6=(
    [name]='macOS -- uses default planner, no --init none'
    [mockCurl]=nixCurlOk
    [mockHash]=nixHashOk
    [mockUnameS]=Darwin
    [mockUnameM]=arm64
    [wantRc]=0
  )

  # marker and argvfile are set per-subtest; mocks access them via dynamic scoping
  nixCurlOk() {
    local args_=("$@") outfile
    for (( i=0; i < ${#args_[@]}; i++ )); do
      [[ ${args_[$i]} == -o ]] && { outfile=${args_[$((i+1))]}; break; }
    done
    [[ -n ${outfile:-} ]] || return 1
    printf '#!/bin/bash\necho "$@" > "%s"\ntouch "%s"\n' "$argvfile" "$marker" >"$outfile"
  }

  nixCurlOkFailInstaller() {
    local args_=("$@") outfile
    for (( i=0; i < ${#args_[@]}; i++ )); do
      [[ ${args_[$i]} == -o ]] && { outfile=${args_[$((i+1))]}; break; }
    done
    [[ -n ${outfile:-} ]] || return 1
    printf '#!/bin/bash\nexit 42\n' >"$outfile"
  }

  nixCurlFail() { return 1; }

  nixHashOk() { return 0; }

  nixHashFail() { echo "FAILED"; return 1; }

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128

    local marker="$dir/installer-ran"
    local argvfile="$dir/installer-argv"

    local curl=$mockCurl
    local sha256sum=$mockHash
    local uname_s=${mockUnameS:-Linux}
    local uname_m=${mockUnameM:-x86_64}

    ## act
    local got rc
    got=$(installNix 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == wantRc )) || { echo "rc=$rc, want $wantRc: $got"; return 1; }
    case $casename in
      case1)
        [[ -f $marker ]] || {
          echo "installer should have been executed"; return 1
        }
        local argv
        argv=$(< "$argvfile")
        [[ $argv == *"install linux --no-confirm --init none"* ]] || {
          echo "argv=$argv, want 'install linux --no-confirm --init none'"; return 1
        }
        ;;
      case2|case3|case5)
        [[ ! -f $marker ]] || {
          echo "installer should not have been executed"; return 1
        }
        ;;
      case6)
        [[ -f $marker ]] || {
          echo "installer should have been executed"; return 1
        }
        local argv
        argv=$(< "$argvfile")
        [[ $argv == *"install --no-confirm"* ]] || {
          echo "argv=$argv, want 'install --no-confirm'"; return 1
        }
        [[ $argv != *"--init"* ]] || {
          echo "macOS should not pass --init, got: $argv"; return 1
        }
        [[ $argv != *"linux"* ]] || {
          echo "macOS should not use linux subcommand, got: $argv"; return 1
        }
        ;;
    esac
  }

  tesht.Run ${!case@}
}

# test_verifyNixFlakes tests the post-install verification that nix is runnable
# and flakes are enabled. Mocks nix (inter-system dependency) via DI.
test_verifyNixFlakes() {
  local -A case1=(
    [name]='nix works with flakes -- passes'
    [mock]=mockNixFlakesEnabled
    [wantRc]=0
  )
  local -A case2=(
    [name]='nix not runnable -- fails'
    [mock]=mockNixMissing
    [wantRc]=1
  )
  local -A case3=(
    [name]='flakes not enabled -- fails'
    [mock]=mockNixNoFlakes
    [wantRc]=1
  )

  mockNixFlakesEnabled() {
    case $1 in
      --version ) echo "nix (Determinate Nix) 2.28.3";;
      config ) echo "flakes nix-command";;
    esac
  }

  mockNixMissing() { return 127; }

  mockNixNoFlakes() {
    case $1 in
      --version ) echo "nix 2.28.3";;
      config ) echo "";;
    esac
  }

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    ## arrange
    local nix=$mock

    ## act
    local got rc
    got=$(verifyNixFlakes 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == wantRc )) || { echo "rc=$rc, want $wantRc: $got"; return 1; }
  }

  tesht.Run ${!case@}
}

# test_credentialStage omitted -- credentialStage is a trivial controller
# (sequence of try-wrapped calls). Per Khorikov, trivial controllers are
# verified by inspection, not mock-heavy Q4 tests. The decision logic
# (platform gating) is tested purely in test_credentialPreflight below.

# test_credentialPreflight tests that credential preflight rejects
# non-crostini platforms with an error.
test_credentialPreflight() {
  local -A case1=(
    [name]='rejects non-crostini platform'
    [platform]=linux
    [wantRc]=2
    [wantMsg]='only supported on Crostini'
  )
  local -A case2=(
    [name]='accepts crostini with all prerequisites'
    [platform]=crostini
    [wantRc]=0
  )
  local -A case3=(
    [name]='rejects crostini without hostname'
    [platform]=crostini
    [wantRc]=2
    [wantMsg]='hostname'
    [skipHostname]=1
  )
  local -A case4=(
    [name]='rejects crostini with empty hostname'
    [platform]=crostini
    [wantRc]=2
    [wantMsg]='hostname'
    [emptyHostname]=1
  )
  local -A case5=(
    [name]='rejects crostini with invalid hostname'
    [platform]=crostini
    [wantRc]=2
    [wantMsg]='invalid'
    [badHostname]=INVALID
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128
    Platform=$platform
    CrostiniDir=$dir/crostini
    CrostiniDirL=$dir/crostini
    mkdir -p "$CrostiniDir"
    if [[ -n ${badHostname:-} ]]; then
      echo "$badHostname" >"$CrostiniDir/hostname"
    elif [[ -n ${emptyHostname:-} ]]; then
      touch "$CrostiniDir/hostname"
    elif [[ -z ${skipHostname:-} ]]; then
      echo testhost >"$CrostiniDir/hostname"
    fi

    ## act
    local got rc
    got=$(credentialPreflight 2>&1) && rc=$? || rc=$?

    ## assert
    (( rc == wantRc )) || { echo "rc=$rc, want $wantRc: $got"; return 1; }
    if [[ -n ${wantMsg:-} ]]; then
      [[ $got == *"$wantMsg"* ]] || {
        echo "should mention '$wantMsg', got: $got"; return 1
      }
    fi
  }

  tesht.Run ${!case@}
}

# test_signingKeyPreflight tests the signing key registration preflight.
# Pure function: takes a state associative array, returns warnings on stdout.
# No I/O -- checked by the caller (credentialStage or stage1).
test_signingKeyPreflight() {
  local -A case1=(
    [name]='no warnings when sidecar is tracked'
    [localExists]=1 [sidecarTracked]=1 [opReady]=0 [opHasItem]=0
    [wantEmpty]=1
  )
  local -A case2=(
    [name]='warns when sidecar is untracked'
    [localExists]=1 [sidecarTracked]=0 [opReady]=0 [opHasItem]=0
    [wantMsg]='not committed'
  )
  local -A case3=(
    [name]='warns when op available but item missing'
    [localExists]=1 [sidecarTracked]=1 [opReady]=1 [opHasItem]=0
    [wantMsg]='not in 1Password'
  )
  local -A case4=(
    [name]='no warnings when everything is complete'
    [localExists]=1 [sidecarTracked]=1 [opReady]=1 [opHasItem]=1
    [wantEmpty]=1
  )
  local -A case5=(
    [name]='no warnings when no signing key exists'
    [localExists]=0 [sidecarTracked]=0 [opReady]=0 [opHasItem]=0
    [wantEmpty]=1
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    local -A preflight_state=(
      [localExists]=$localExists
      [sidecarTracked]=$sidecarTracked
      [opReady]=$opReady
      [opHasItem]=$opHasItem
    )

    local got
    got=$(signingKeyPreflight preflight_state testhost)

    if [[ -n ${wantEmpty:-} ]]; then
      [[ -z $got ]] || { echo "want empty, got: $got"; return 1; }
    elif [[ -n ${wantMsg:-} ]]; then
      [[ $got == *"$wantMsg"* ]] || { echo "want '$wantMsg', got: $got"; return 1; }
    fi
  }

  tesht.Run ${!case@}
}

# test_cliHelp tests that the --help flag produces usage output and exits 0.
# Boundary test: verifies the exact wiring layer that was broken (Usage_
# undefined). Runs the real entrypoint as a subprocess.
test_cliHelp() {
  local got rc
  got=$(~/dotfiles/update-env --help 2>&1) && rc=$? || rc=$?
  (( rc == 0 )) || { echo "rc=$rc, want 0"; return 1; }
  [[ -n $got ]] || { echo "empty output"; return 1; }
  [[ $got == *"-c"* ]] || { echo "missing -c flag in output"; return 1; }
  [[ $got == *"--credential"* ]] || { echo "missing --credential in output"; return 1; }
  [[ $got == *"--help"* ]] || { echo "missing --help in output"; return 1; }
}

# test_cliCredential tests the -c flag at the CLI boundary.
# Runs the real entrypoint as a subprocess. On crostini (where credentials
# are already present), verifies the positive path: exits 0 and prints
# the expected section markers. On non-crostini, verifies rejection.
test_cliCredential() {
  local got rc
  got=$(~/dotfiles/update-env -c 2>&1) && rc=$? || rc=$?
  if [[ $HOSTNAME == penguin ]]; then
    # Positive path: -c runs credential stage, exits 0
    (( rc == 0 )) || { echo "rc=$rc, want 0: $got"; return 1; }
    [[ $got == *"[section credential]"* ]] || {
      echo "should print credential section marker, got: $got"; return 1
    }
    [[ $got == *"[section auth-preflight]"* ]] || {
      echo "should print auth-preflight section marker, got: $got"; return 1
    }
  else
    # Negative path: non-crostini rejection
    (( rc == 2 )) || { echo "rc=$rc, want 2: $got"; return 1; }
    [[ $got == *"only supported on Crostini"* ]] || {
      echo "should mention Crostini, got: $got"; return 1
    }
  fi
}

# test_nixConfContent tests that the declarative nix.conf content enables
# flakes, trusts only cache.nixos.org, and does not include third-party caches.
# Pure output-based test -- no filesystem.
test_nixConfContent() {
  local got
  got=$(nixConfContent)

  # Must enable flakes
  [[ $got == *"flakes"* ]] || { echo "missing flakes"; return 1; }

  # Must not trust third-party caches
  [[ $got != *"cache.lix.systems"* ]] || { echo "contains lix cache"; return 1; }

  # Must have auto-optimise
  [[ $got == *"auto-optimise-store"* ]] || { echo "missing auto-optimise-store"; return 1; }
}

# test_panelHermetic runs the nix-packaged panel binary under a stripped
# PATH (only the wrapper's own deps). Verifies key subcommands exit
# without "command not found" errors, proving the runtime dep closure
# is complete. Does not test correctness of widget output -- only that
# deps are resolvable.
test_panelHermetic() {
  # Find the packaged panel via the tmux wrapper
  local tmuxBin panelBin
  tmuxBin=$(readlink -f ~/.nix-profile/bin/tmux) || { echo "tmux not in profile"; return 1; }
  panelBin=$(grep -oP "'/nix/store/[^']*-panel/bin'" "$tmuxBin" | head -1 | tr -d "'")
  [[ -n $panelBin && -d $panelBin ]] || { echo "panel store path not found in tmux wrapper"; return 1; }

  local -A case1=([name]='hostname exits clean'   [cmd]='hostname')
  local -A case2=([name]='clock exits clean'      [cmd]='clock')
  local -A case3=([name]='healthsep exits clean'  [cmd]='healthsep')
  local -A case4=([name]='load exits clean'       [cmd]='load')
  local -A case5=([name]='cpu exits clean'        [cmd]='cpu')
  local -A case6=([name]='mem exits clean'        [cmd]='mem')
  local -A case7=([name]='disk exits clean'       [cmd]='disk')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    # Run with stripped PATH: only panel's own wrapper PATH
    local got rc
    got=$(env -i PATH="$panelBin" HOME="$HOME" \
      "$panelBin/panel" "$cmd" 2>&1) && rc=$? || rc=$?

    # "command not found" = missing runtime dep
    [[ $got != *"command not found"* ]] || {
      echo "missing dep: $got"; return 1
    }
    # nonzero exit from missing command (rc=127) = missing dep
    (( rc != 127 )) || {
      echo "rc=127 (command not found): $got"; return 1
    }
  }

  tesht.Run ${!case@}
}

# test_withSecretMissingFile tests with-secret fails on missing file.
test_withSecretMissingFile() {
  local rc
  ~/dotfiles/scripts/with-secret MY_TOKEN /nonexistent/file echo hi 2>/dev/null && rc=$? || rc=$?
  (( rc != 0 )) || { echo "should fail on missing file"; return 1; }
}
