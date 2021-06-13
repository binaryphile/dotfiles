_direnv_hook() {
  eval "$(direnv export bash)";
};

if [[ $PROMPT_COMMAND != *_direnv_hook* ]]; then
  PROMPT_COMMAND="$PROMPT_COMMAND${PROMPT_COMMAND:+; }_direnv_hook"
fi
