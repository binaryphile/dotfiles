shannon () {
  reveal "$FUNCNAME"
  pandoc -f markdown -t gfm-hard_line_breaks$([[ $OSTYPE == darwin* ]] && echo +smart) --columns 92 --markdown-headings=atx -o "$1" "$1"
}
