assertThat envVar PATH contains $HOME/.go/current/bin
assertThat envVar PATH contains $HOME/go/bin
assertThat outputOf "go version" isEqualTo "go version go1.17 darwin/amd64"
