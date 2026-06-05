set -o vi

INPUTRC=$HOME/dotfiles/bash/inputrc

# historymerge -- dedupe ~/.bash_history while preserving original order.
# Refuses to clobber the file with empty output. PID-suffixed temp prevents
# cross-shell mv races at concurrent EXIT (e.g. host VM shutdown sending
# SIGHUP to N shells at once -- the failure mode that wiped history once).
historymerge () {
  local hist=${1:-$HOME/.bash_history}
  local tmp=$hist.new.$$
  ( set -o pipefail
    nl <"$hist" | sort -k2 | tac | uniq -f1 | sort -n | cut -f2 >"$tmp"
  ) 2>/dev/null
  if [[ -s $tmp ]]; then
    mv "$tmp" "$hist"
  else
    rm -f "$tmp"
  fi
}

trap historymerge EXIT

shopt -s histappend
HISTCONTROL=ignorespace:erasedups
HISTIGNORE=l:l[asl]:ltr:ps:[bf]g:history
HISTTIMEFORMAT='%F %T '
# history -a: append this shell's new entries to the file.
# history -n: pull in entries other shells have appended -- cross-window Ctrl-R sync.
PROMPT_COMMAND=${PROMPT_COMMAND}${PROMPT_COMMAND+; }'history -a; history -n; echo $$ $USER "$(history 1)" >>$HOME/.bash_eternal_history'
