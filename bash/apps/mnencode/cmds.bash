randword () {
  local statement
  local word

  reveal "$FUNCNAME"
  while true; do
    set -- $(openssl rand -hex 8 | mnencode -x 2>/dev/null)
    printf -v statement 'echo "${%s/./}"' "$(($RANDOM % 4 + 1))"
    word=$(eval "$statement")
    declare -f "$word" &>/dev/null || break
  done
  echo "$word"
}
