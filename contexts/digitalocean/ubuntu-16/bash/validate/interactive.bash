assertThat setting vi isOn
assertThat shellVar INPUTRC isEqualTo $HOME/dotfiles/bash/inputrc

assertThat shellOpt histappend isOn
assertThat shellVar PROMPT_COMMAND contains 'history -a'
