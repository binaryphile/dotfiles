set -o vi

INPUTRC=$HOME/dotfiles/bash/inputrc

shopt -s histappend
HISTCONTROL=ignorespace:erasedups
HISTIGNORE=ls:ps:bg:fg:history
HISTTIMEFORMAT='%F %T '
PROMPT_COMMAND=${PROMPT_COMMAND}${PROMPT_COMMAND+; }'echo $$ $USER "$(history 1)" >>$HOME/.bash_eternal_history'
