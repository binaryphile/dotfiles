# truth.bash - assertions for bash

assertThat () {
  local failed

  case $(tru.typeOf $1) in
    array   ) tru.assertAry $*;;
    hash    ) tru.assertHsh $*;;
    string  ) tru.assertStr $*;;
  esac

  (( failed )) && echo error
}

tru.assertStr () {
  local actual=$1 matcher=$2; shift 2
  local item

  case $matcher in
    contains )
      case $IFS in
        : ) tru.strAry.contains $actual $*          ;;
        * ) tru.str.contains $actual $* || failed=1 ;;
      esac
      ;;
    * ) tru.str.$matcher $actual $1 || failed=1;;
  esac
}

# contains returns whether a string item is found in a list.
# The first argument is an IFS-delimited string of items, usually from
# an "${array[*]}".  The second argument is the desired item.
tru.ary.contains () {
  [[ "$IFS${!1}$IFS" == *"$IFS$2$IFS"* ]]
}

tru.str.contains () {
  [[ ${!1} == *"$2"* ]]
}

tru.str.isEqualTo () {
  [[ ${!1} == "$2" ]]
}

tru.strAry.contains () {
  local actual=$1; shift
  local item

  for item; do
    tru.ary.contains $actual $item || {
      failed=1
      return
    }
  done
}

tru.typeOf () {
  local varName=$1
  local flags

  flags=$(declare -p $varName | cut -d ' ' -f2)
  case $flags in
    *a* ) echo array  ;;
    *A* ) echo hash   ;;
    *   ) echo string ;;
  esac
}
