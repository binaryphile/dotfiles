assertThat setting vi isOn
assertThat shellVar INPUTRC isEqualTo $HOME/dotfiles/bash/inputrc

assertThat shellOpt histappend isOn

assertThat shellVar HISTCONTROL containsAll <<'END'
  ignorespace
  erasedups
END

assertThat shellVar HISTIGNORE containsAll <<'END'
  l
  l[asl]
  ltr
  ps
  [bf]g
  history
END

assertThat shellVar HISTTIMEFORMAT isEqualTo '%F %T '
assertThat shellVar PROMPT_COMMAND contains 'echo $$ $USER "$(history 1)" >>$HOME/.bash_eternal_history'
