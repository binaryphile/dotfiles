set -o vi

shopt -s histappend
HISTCONTROL=ignorespace:erasedups
HISTIGNORE=ls:ps:bg:fg:history
HISTTIMEFORMAT='%F %T '

INPUTRC=$HOME/dotfiles/bash/inputrc
