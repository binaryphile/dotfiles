# truth.bash - assertions for bash

assertThat () {
  local type=$1 actual=$2 matcher=$3 expected=$4

  case $type in
    set|var|alias ) $type.$matcher $actual $expected  || echo "error $type $actual $expected";;
    vars|aliases  ) $type.$actual                     || echo "error $type $actual $expected";;
  esac
}

var.contains () {
  [[ ${!1} == *"$2"* ]]
}

var.isEqualTo () {
  [[ ${!1} == "$2" ]]
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

set.isOn () {
  [[ $(set -o | grep "^$1\W" | cut -f2) == on ]]
}
