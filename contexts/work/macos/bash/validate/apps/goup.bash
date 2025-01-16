assertThat envVar PATH contains $HOME/.go/bin
assertThat outputOf "goup version" isEqualTo "goup version v0.1.6"
