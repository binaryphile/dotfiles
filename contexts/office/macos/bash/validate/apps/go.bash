assertThat envVar PATH contains $HOME/.go/current/bin
assertThat envVar PATH contains $HOME/go/bin
assertThat outputOf "go version" isEqualTo "go version go1.15.13 darwin/amd64"
