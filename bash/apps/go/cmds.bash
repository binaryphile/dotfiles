IsCmd entr && airline () {
  reveal $FUNCNAME
  find . -path ./.git -prune -o -type f -print | entr bash -c "go test -v --bench . --benchmem"
}
