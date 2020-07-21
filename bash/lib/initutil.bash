# initutil.bash - useful functions for init.bash

functionList=$(compgen -A function)

# cleanup removes the initutil functions and vars and returns IFS to normal
cleanup () {
  unset -f ${FUNCTIONS[*]}
  unset -v ${VARS[*]}
  IFS=$' \t\n'
}

cmdPath () {
  type -p $1
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

shellIsInteractive () {
  [[ $- == *i* ]]
}

shellIsInteractiveAndLogin () {
  shellIsInteractive && shellIsLogin
}

shellIsLogin () {
  [[ $(shopt login_shell) == *on ]]
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

FUNCTIONS=( $(comm -13 <(echo "$functionList") <(compgen -A function)) )
VARS+=( FUNCTIONS )
unset -v functionList

declare -A LOADED=([initutil]=1)
VARS+=( LOADED )
