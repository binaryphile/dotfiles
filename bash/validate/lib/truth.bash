# truth.bash - assertions for bash

assertThat () {
  local type=$1 actual=$2 matcher=$3 expected=$4

  case $type in
    vars|aliases|functions )
        $type.$actual                     || echo "error $type $actual $expected";;
    * ) $type.$matcher $actual $expected  || echo "error $type $actual $expected";;
  esac
}

alias.exists () {
  alias $1 &>/dev/null
}

aliases.exist () {
  local alias

  while read -r alias; do
    alias.exists $(trim $alias) || return
  done
}

file.exists () {
  isFile $1
}

function.exists () {
  [[ $(type -t $1) == function ]]
}

functions.exist () {
  local function

  while read -r function; do
    function.exists $(trim $function) || return
  done
}

set.isOn () {
  [[ $(set -o | grep "^$1\W" | cut -f2) == on ]]
}

envVar.contains () {
  [[ ${!1} == *"$2"* ]]
}

envVar.isEqualTo () {
  [[ ${!1} == "$2" ]]
}
