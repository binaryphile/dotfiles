ralias stbcf='stg branch --cleanup --force'
ralias stcom='stg commit'
ralias stcal='stg commit --all'
ralias stcn='stg commit -n'
ralias stdel='stg delete'
ralias stedi='stg edit'
ralias stflo='stg float'
ralias stgot='stg goto'
ralias stini='stg init'
ralias stnew='stg new'
ralias stnme='stg new --message'
ralias stnwmw='stg new wip -m wip'
ralias stpic='stg pick'
ralias stpop='stg pop'
ralias stpul='stg pull'
ralias stpus='stg push'
ralias stref='stg refresh'
ralias strefi='stg refresh --index'
ralias stren='stg rename'
ralias strep='stg repair'
ralias stser='stg series'
ralias stsho='stg show'
ralias stunc='stg uncommit'
ralias stuncn='stg uncommit -n'
ralias stund='stg undo'
ralias stundh='stg undo --hard'

minimak () { (
  reveal "$FUNCNAME"
  cd "$HOME"/dotfiles
  stg pop qwerty
  cd "$HOME"/.vim
  stg pop  qwerty
) }

qwerty () { (
  reveal "$FUNCNAME"
  cd "$HOME"/dotfiles
  stg push qwerty
  cd "$HOME"/.vim
  stg push qwerty
) }

pretend () {
  local target

  reveal "$FUNCNAME"
  target=${2:-$(stg top)}
  stg rename "$target" "$1" || return
  stg edit "$1" -m "$1"
}

salt () {
  local name=$1
  local target=$2
  local dirty
  local top

  reveal $FUNCNAME
  top=$(stg top)
  git diff --quiet
  dirty=$?
  (( dirty )) && git stash save
  [[ -n $target ]] && { stg goto "$target" || return ;}
  stg new "$name" -m "$name"
  (( dirty )) && {
    git stash apply || return
    git stash drop
    stg refresh
  }
  [[ -n $target ]] && stg goto "$top";:
}