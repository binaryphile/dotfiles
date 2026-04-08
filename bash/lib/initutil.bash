# initutil.bash - useful functions for init.bash

shopt -s expand_aliases

command -v compgen >/dev/null && Compgen=compgen || Compgen=':'

FunctionList=$($Compgen -A function | sort)

# Alias aliases with reveal
Alias () {
  local name=${1%%=*}
  local cmd=${1#*=}

  alias $name="reveal $name; $cmd"
}

Globbing () {
  case $1 in
    on  ) set +o noglob;;
    off ) set -o noglob;;
  esac
}

IsFile () {
  [[ -r $1 ]]
}

ShellIsInteractive () {
  [[ $- == *i* && $PS1 != '' ]]
}

ShellIsInteractiveAndLogin () {
  ShellIsInteractive && ShellIsLogin
}

ShellIsLogin () {
  ! (( ENV_SET ))
}

SplitSpace () {
  case $1 in
    on  ) IFS=$' \t\n';;
    off ) IFS=$'\n'   ;;
  esac
}

alias TestAndSource='{ read -r Candidate; IsFile $Candidate && source $Candidate; unset -v Candidate; } <<<'

TestAndTouch () {
  ! IsFile $1 && touch $1
}

Functions=( $(comm -13 <(echo "$FunctionList") <($Compgen -A function | sort)) )
Vars+=( Vars Functions )
unset -v Compgen FunctionList
