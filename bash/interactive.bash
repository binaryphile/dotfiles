set -o vi

shopt -s histappend
PROMPT_COMMAND="$PROMPT_COMMAND${PROMPT_COMMAND+; }history -a"

INPUTRC=$HOME/dotfiles/bash/inputrc
