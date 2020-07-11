# initutil.bash - useful functions for init.bash

# cleanup removes the initutil functions and vars and returns IFS to normal
cleanup () {
  local functions=() vars=()

  functions=(
    cleanup
  )

  vars=(
    HERE
    NL
  )

  unset -f ${functions[*]}
  unset -v ${vars[*]}
  IFS=$' \t\n'
}
