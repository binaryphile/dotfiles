assertThat envVar PATH contains $HOME/.go/bin $HOME/.go/current/bin
assertThat outputOf "go version" isEqualTo "go version go1.16.4 linux/amd64"
