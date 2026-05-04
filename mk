#!/usr/bin/env bash

Prog=$(basename "$0")

read -rd '' Usage_ <<END
Usage:

  $Prog [OPTIONS] [--] COMMAND

  bump-task-bash  update task.bash pin (flake lock + bootstrap rev/hash)

  Options:

    -h | --help     show this message and exit
    -v | --version  show the program version and exit
    -x | --trace    enable debug tracing
END

## commands

cmd.bump-task-bash() {
  mk.Cue nix flake update task-bash-src

  local rev
  rev=$(nix flake metadata --json 2>/dev/null |
    python3 -c "import sys,json; print(json.load(sys.stdin)['locks']['nodes']['task-bash-src']['locked']['rev'])")
  [[ -n $rev ]] || mk.Fatal 'could not read rev from flake.lock'

  local hash
  hash=$(curl -fsSL "https://raw.githubusercontent.com/binaryphile/task.bash/$rev/task.bash" | sha256sum | awk '{print $1}')
  [[ -n $hash ]] || mk.Fatal 'could not hash task.bash'

  sed -i "s/^TaskBashBootstrapRev=.*/TaskBashBootstrapRev=$rev/" update-env
  sed -i "s/^TaskBashBootstrapSha256=.*/TaskBashBootstrapSha256=$hash/" update-env

  echo "Updated bootstrap pin to $rev"
}

## boilerplate

source ~/.local/lib/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 1; }

IFS=$'\n'
set -o noglob

mk.SetProg $Prog
mk.SetUsage "$Usage_"

return 2>/dev/null    # stop if sourced, for interactive debugging
mk.HandleOptions "$@"
mk.Main "${@:$?}"
