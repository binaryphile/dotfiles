#!/usr/bin/env bash

Root=$PWD

test_nix_parse() {
  local -A case1=([name]='shared'   [file]="$Root/shared.nix")
  local -A case2=([name]='crostini' [file]="$Root/contexts/crostini/home.nix")
  local -A case3=([name]='linux'    [file]="$Root/contexts/linux/home.nix")
  local -A case4=([name]='macos'    [file]="$Root/contexts/macos/home.nix")

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    local got rc
    got=$(nix-instantiate --parse "$file" 2>&1 >/dev/null) && rc=$? || rc=$?

    tesht.AssertRC $rc 0
  }

  tesht.Run ${!case@}
}

test_symlinks() {
  local -A case1=([name]='context exists'             [link]="$Root/context"       [want]='contexts/')
  local -A case2=([name]='home.nix through context'   [link]="$Root/home.nix"      [want]='context/home.nix')
  local -A case3=([name]='gitconfig through context'  [link]="$Root/gitconfig"     [want]='context/gitconfig')
  local -A case4=([name]='tmux.conf through context'  [link]="$Root/tmux.conf"     [want]='context/tmux.conf')
  local -A case5=([name]='bashrc to init.bash'        [link]="$HOME/.bashrc"       [want]='bash/init.bash')
  local -A case6=([name]='bash_profile to init.bash'  [link]="$HOME/.bash_profile" [want]='bash/init.bash')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    local got
    got=$(readlink "$link")

    [[ $got == *"$want"* ]] || {
      echo "error: readlink '$link' = '$got', want pattern '*$want*'"
      return 1
    }
  }

  tesht.Run ${!case@}
}

test_app_module_files() {
  local -A case1=([name]='direnv'        [app]='direnv')
  local -A case2=([name]='git'           [app]='git')
  local -A case3=([name]='home-manager'  [app]='home-manager')
  local -A case4=([name]='keychain'      [app]='keychain')
  local -A case5=([name]='liquidprompt'  [app]='liquidprompt')
  local -A case6=([name]='mnencode'      [app]='mnencode')
  local -A case7=([name]='pandoc'        [app]='pandoc')
  local -A case8=([name]='stg'          [app]='stg')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    local allowed='cmds.bash deps detect.bash env.bash init.bash interactive.bash'
    local files rc=0
    files=$(ls "$Root/bash/apps/$app" 2>/dev/null)

    local base
    for base in $files; do
      [[ " $allowed " == *" $base "* ]] || {
        echo "error: unexpected file '$base' in bash/apps/$app/"
        rc=1
      }
    done
    return $rc
  }

  tesht.Run ${!case@}
}

test_session_variables() {
  local got
  got=$(env -i HOME="$HOME" USER="$USER" TERM=xterm bash -l -c '
    echo "EDITOR=$EDITOR"
  ' 2>/dev/null)

  [[ $got == *"EDITOR="*"nvim"* ]] || {
    echo "error: EDITOR not set to nvim"
    return 1
  }
}

test_session_path() {
  local got
  got=$(env -i HOME="$HOME" USER="$USER" TERM=xterm bash -l -c 'echo "$PATH"' 2>/dev/null)

  [[ $got == *".local/bin"* ]] || {
    echo "error: .local/bin not in PATH"
    return 1
  }
}

test_shared_packages() {
  local shared=(
    claude-code coreutils diff-so-fancy git highlight htop
    jira-cli-go jq keychain mnemonicode ncdu neovim obsidian pandoc
    ranger rsync scc signal-desktop silver-searcher stgit tmux tree zip
  )

  local contents rc=0
  contents=$(cat "$Root/shared.nix")

  local pkg
  for pkg in "${shared[@]}"; do
    [[ $contents == *"$pkg"* ]] || {
      echo "error: package '$pkg' missing from shared.nix"
      rc=1
    }
  done
  return $rc
}

test_shared_programs() {
  local programs=('programs.direnv' 'programs.bat' 'programs.firefox' 'programs.home-manager')

  local contents rc=0
  contents=$(cat "$Root/shared.nix")

  local prog
  for prog in "${programs[@]}"; do
    [[ $contents == *"$prog"* ]] || {
      echo "error: '$prog' missing from shared.nix"
      rc=1
    }
  done
  return $rc
}
