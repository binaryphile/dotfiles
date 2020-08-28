# initutil.bash - useful functions for init.bash
shopt -s expand_aliases

FunctionList=$(compgen -A function | sort)

# Alias aliases with reveal
Alias () {
  local name=${1%%=*}
  local cmd=${1#*=}

  alias $name="reveal $name; $cmd"
}

CmdPath () {
  type -p $1
}

Contains () {
  [[ "$IFS$1$IFS" == *"$IFS$2$IFS"* ]]
}

Filter () {
  local item

  while read -r item; do
    $1 $item && echo $item
  done
}

Globbing () {
  case $1 in
    on  ) set +o noglob;;
    off ) set -o noglob;;
  esac
}

IsApp () {
  local dir=$1

  IsFile $dir/detect.bash && {
    source $dir/detect.bash
    return
  }

  IsCmd $dir
}

IsCmd () {
  type $1 &>/dev/null
}

IsDir () {
  [[ -d $1 ]]
}

IsFile () {
  [[ -r $1 ]]
}

IsFunc () {
  [[ $(type -t $1) == function ]]
}

IsPathCmd () {
  type -p $1 &>/dev/null
}

ListDir () { (
  local items=()

  cd $1
  Globbing on
  items=( * )
  echo "${items[*]}"
) }

OrderByDependencies () {
  local -A satisfied=()

  ORDER_BY_DEPENDENCIES
}

ORDER_BY_DEPENDENCIES () {
  local app dep

  while read -r app; do
    (( ${satisfied[$app]} )) && continue

    ! IsFile $app/deps && {
      echo $app
      satisfied[$app]=1
      continue
    }

    for dep in $(ORDER_BY_DEPENDENCIES $(<$app/deps)); do
      (( ${satisfied[$dep]} )) && continue
      echo $dep
      satisfied[$dep]=1
    done

    echo $app
    satisfied[$app]=1
  done
}

ShellIsInteractive () {
  [[ $- == *i* ]]
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
    off ) IFS=$'\n'
  esac
}

StrContains () {
  [[ $1 == *"$2"* ]]
}

TestAndExport () {
  export $1=${!1:-$2}
}

TestCmdAndExport () {
  IsPathCmd $2 && export $1=$(CmdPath $2)
}

alias TestAndSource='{ read -r Candidate; IsFile $Candidate && source $Candidate; unset -v Candidate; } <<<'

TestAndTouch () {
  ! IsFile $1 && touch $1
}

# trim strips leading and trailing whitespace from a string
Trim () {
  local indent result

  indent=${1%%[^[:space:]]*}
  result=${1#$indent}
  indent=${result##*[^[:space:]]}
  echo ${result%$indent}
}

Vars=( Vars )

Functions=( $(comm -13 <(echo "$FunctionList") <(compgen -A function | sort)) )
Vars+=( Functions )
unset -v FunctionList

declare -A Loaded=([initutil]=1)
Vars+=( Loaded )
