assertThat envVar PATH contains $HOME/.local/bin
assertThat envVar EDITOR isEqualTo /usr/local/bin/nvim
assertThat envVar XDG_CONFIG_HOME isEqualTo $HOME/.config
