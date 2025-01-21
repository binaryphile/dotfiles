escape_items () {
  printf -v __ '%q ' "$@"
  __=${__% }
}

get () {
  local space

  get_raw
  space=${__%%[^[:space:]]*}
  printf -v __ %s "${__#$space}"
  printf -v __ %s "${__//$'\n'$space/$'\n'}"
}

get_raw () {
  IFS=$'\n' read -rd '' __ ||:
}

get_repr () {
  local item_ary=()
  local IFS=$IFS

  get
  IFS=$'\n' read -rd '' -a item_ary <<<"$__" ||:
  escape_items "${item_ary[@]}"
}

gsub () {
  printf -v __ '__=${1//%s/%s}' "$2" "$3"
  eval "$__"
}

includes () {
  local target=$2
  eval "set -- $1"
  local item

  for item; do
    [[ $item == "$target" ]] && return
  done
  return 1
}

includes_in_order () {
  eval "local item_ary=( $2 )"
  eval "set -- $1"
  local item

  for item in "${item_ary[@]}"; do
    while (( $# )); do
      [[ $1 == "$item" ]] && { shift; continue 2 ;}
      shift
    done
    (( $# )) || return
  done
}

path_repr () {
  __=${1:-$PATH}
  printf -v __ %q "$__"
  __=${__//:/ }
}

setting () {
  [[ $(set -o | grep "^$1\s") == "$1"*"$2" ]]
}

substr () {
  [[ $1 == *"$2"* ]]
}

verify_aliases () {
  eval "local alias_ary=( $1 )"
  local IFS=$IFS
  local alias
  local messages=()
  local rc=0

  for alias in "${alias_ary[@]}"; do
    alias "$alias" >/dev/null 2>&1 || { rc=$?; messages+=( "$alias not set" ) ;}
  done
  IFS=$'\n'
  __="${messages[*]}"
  return "$rc"
}

verify_environment_variables () {
  eval "local variable_ary=( $1 )"
  local environment_variables=${2:-}
  local IFS=$IFS
  local environment_variable_ary=()
  local messages=()
  local rc=0
  local variable

  [[ -z $environment_variables ]] && {
    IFS=$'\n' read -rd '' -a environment_variable_ary <<<"$(printenv)"
    escape_items "${environment_variable_ary[@]}"
    environment_variables=$__
  }
  for variable in "${variable_ary[@]}"; do
    includes "$environment_variables" "$variable" || { rc=$?; messages+=( "${variable%%=*}=$(printenv "${variable%%=*}")" ) ;}
  done
  IFS=$'\n'
  __="${messages[*]}"
  return "$rc"
}

verify_functions () {
  eval "local function_ary=( $1 )"
  local IFS=$IFS
  local function
  local messages=()
  local rc=0

  for function in "${function_ary[@]}"; do
    declare -f "$function" >/dev/null 2>&1 || { rc=$?; messages+=( "$function not set" ) ;}
  done
  IFS=$'\n'
  __="${messages[*]}"
  return "$rc"
}

verify_paths () {
  path_repr
  includes_in_order "$__" "$1" && return
  printf -v __ 'PATH:\n%s' "${PATH//:/$'\n'}"
  return 1
}

verify_unset_variables () {
  eval "local variable_ary=( $1 )"
  local IFS=$IFS
  local messages=()
  local rc=0
  local variable

  for variable in "${variable_ary[@]}"; do
    ! declare -p "$variable" >/dev/null 2>&1 || { rc=$?; messages+=( "$variable set" ) ;}
  done
  IFS=$'\n'
  __="${messages[*]}"
  return "$rc"
}
