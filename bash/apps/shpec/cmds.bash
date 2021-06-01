IsCmd entr && dallas () {
  reveal "$FUNCNAME"
  find . -path ./.git -prune -o -type f -print | entr bash -c "shpec '$1'"
}
