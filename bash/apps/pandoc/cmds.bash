shannon () {
  reveal "$FUNCNAME"
  pandoc -f markdown -t markdown_github-hard_line_breaks$([[ $OSTYPE == darwin* ]] && echo +smart) --reference-links -o "$1" "$1"
}
