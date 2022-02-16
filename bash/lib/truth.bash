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
    alias.exists $(Trim $alias) || return
  done
}

envVar.contains () {
  [[ $(printenv $1) == *"$2"* ]]
}

envVar.exists () {
  [[ $(printenv $1) != '' ]]
}

envVar.isEqualTo () {
  [[ $(printenv $1) == "$2" ]]
}

file.exists () {
  IsFile $1
}

function.exists () {
  [[ $(type -t $1) == function ]]
}

functions.exist () {
  local function

  while read -r function; do
    function.exists $(Trim $function) || return
  done
}

outputOf.isEqualTo () {
  string.isEqualTo $(IFS=$' \t\n'; $1) $2
}

setting.isOn () {
  [[ $(shopt -op $1) == *-o* ]]
}

shellOpt.isOn () {
  [[ $(shopt -p $1) == *-s* ]]
}

shellVar.contains () {
  [[ ${!1} == *"$2"* ]]
}

shellVar.containsAll () {
  while read -r item; do
    StrContains :${!1}: :$(Trim $item): || return
  done
}

shellVar.isEqualTo () {
  [[ ${!1} == "$2" ]]
}

string.isEqualTo () {
  [[ $1 == "$2" ]]
}
