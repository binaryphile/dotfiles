# initutil.bash - useful functions for init.bash

FunctionList=$(compgen -A function | sort)

areApps () {
  local dir

  for dir; do
    isApp $dir && echo $dir
  done
}

# cleanup removes the initutil functions and vars and returns IFS to normal
cleanup () {
  unset -f ${FUNCTIONS[*]}
  unset -v ${VARS[*]}
  IFS=$' \t\n'
}

cmdPath () {
  type -p $1
}

contains () {
  [[ "$IFS$1$IFS" == *"$IFS$2$IFS" ]]
}

isApp () {
  local dir=$1

  isDir $dir || return

  isFile $dir/detect.bash && {
    source $dir/detect.bash
    return
  }

  isCmd $dir
}

isCmd () {
  type $1 &>/dev/null
}

isDir () {
  [[ -d $1 ]]
}

isFile () {
  [[ -r $1 ]]
}

isFunc () {
  [[ $(type -t $1) == function ]]
}

isPathCmd () {
  type -p $1 &>/dev/null
}

orderByDependencies () {
  local -A satisfied=()

  OrderByDependencies $*
}

OrderByDependencies () {
  local app dep

  for app; do
    (( ${satisfied[$app]} )) && continue

    ! isFile $app/deps && {
      echo $app
      satisfied[$app]=1
      continue
    }

    for dep in $(OrderByDependencies $(<$app/deps)); do
      (( ${satisfied[$dep]} )) && continue
      echo $dep
      satisfied[$dep]=1
    done

    echo $app
    satisfied[$app]=1
  done
}

remove () {
  local -n ary=$1
  local remove=$2
  local result=()

  for item in ${ary[*]}; do
    [[ $item != "$remove" ]] && result+=( $item )
  done
  ary=( ${results[*]} )
}

shellIsInteractive () {
  [[ $- == *i* ]]
}

shellIsInteractiveAndLogin () {
  shellIsInteractive && shellIsLogin
}

shellIsLogin () {
  [[ $(shopt login_shell) == *on || $SHLVL == 1 ]]
}

strContains () {
  [[ $1 == *$2* ]]
}

testAndExportCmd () {
  isPathCmd $2 && export $1=$(cmdPath $2)
}

alias testAndSource='{ read -r Candidate; isFile $Candidate && source $Candidate; unset -v Candidate; } <<<'

alias testLoginAndSource='{ read -r Candidate; { shellIsLogin && isFile $Candidate; } && source $Candidate; unset -v Candidate; } <<<'

testAndTouch () {
  ! isFile $1 && touch $1
}

# trim strips leading and trailing whitespace from a string
trim () {
  local indent result

  indent=${1%%[^[:space:]]*}
  result=${1#$indent}
  indent=${result##*[^[:space:]]}
  echo ${result%$indent}
}

VARS=( VARS )

FUNCTIONS=( $(comm -13 <(echo "$FunctionList") <(compgen -A function | sort)) )
VARS+=( FUNCTIONS )
unset -v FunctionList

declare -A LOADED=([initutil]=1)
VARS+=( LOADED )
