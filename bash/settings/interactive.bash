set -o vi

INPUTRC=$HOME/dotfiles/bash/inputrc

historymerge () {
  nl <"$HOME"/.bash_history |
    sort -k2  |
    tac       |
    uniq -f1  |
    sort -n   |
    cut -f2 >"$HOME"/.bash_history_new
    mv "$HOME"/.bash_history_new "$HOME"/.bash_history
}

trap historymerge EXIT

shopt -s histappend
HISTCONTROL=ignorespace:erasedups
HISTIGNORE=l:l[asl]:ltr:ps:[bf]g:history
HISTTIMEFORMAT='%F %T '
PROMPT_COMMAND=${PROMPT_COMMAND}${PROMPT_COMMAND+; }'history -a; echo $$ $USER "$(history 1)" >>$HOME/.bash_eternal_history'
