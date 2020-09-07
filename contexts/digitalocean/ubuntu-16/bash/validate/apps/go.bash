assertThat envVar GOPATH isEqualTo $HOME/go
assertThat envVar PATH contains $HOME/go/bin
