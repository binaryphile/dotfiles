shannon () {
  reveal "$FUNCNAME"
  pandoc -f markdown -t markdown_github-hard_line_breaks$([[ $OSTYPE == darwin* ]] && echo +smart) --columns 92 --atx-headers -o "$1" "$1"
}
