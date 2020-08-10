assertThat envVar PATH contains /home/ted/.local/bin
assertThat envVar EDITOR isEqualTo /usr/bin/nvim
assertThat envVar XDG_CONFIG_HOME isEqualTo $HOME/.config
