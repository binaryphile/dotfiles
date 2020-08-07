assertThat file $HOME/.hushlogin exists
assertThat envVar INPUTRC isEqualTo $HOME/dotfiles/bash/inputrc
