assertThat envVar GOPATH isEqualTo $HOME/go
assertThat envVar PATH contains $HOME/go/bin
assertThat outputOf "go version" isEqualTo "go version go1.15.1 linux/amd64"
