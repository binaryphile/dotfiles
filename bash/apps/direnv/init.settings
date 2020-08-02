_direnv_hook() {
  eval "$(direnv export bash)"
}

! strContains $PROMPT_COMMAND _direnv_hook && PROMPT_COMMAND=$PROMPT_COMMAND${PROMPT_COMMAND:+;}_direnv_hook

# vim: ft=sh
