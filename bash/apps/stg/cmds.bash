Ralias stbcf='stg branch --cleanup --force'
Ralias stcom='stg commit'
Ralias stcal='stg commit --all'
Ralias stcn='stg commit -n'
Ralias stdel='stg delete'
Ralias stedi='stg edit'
Ralias stflo='stg float'
Ralias stgot='stg goto'
Ralias stini='stg init'
Ralias stnew='stg new'
Ralias stnme='stg new --message'
Ralias stnwmw='stg new wip -m wip'
Ralias stpic='stg pick'
Ralias stpop='stg pop'
Ralias stpul='stg pull'
Ralias stpus='stg push'
Ralias stref='stg refresh'
Ralias strefi='stg refresh --index'
Ralias stren='stg rename'
Ralias strep='stg repair'
Ralias stser='stg series'
Ralias stsho='stg show'
Ralias stunc='stg uncommit'
Ralias stuncn='stg uncommit -n'
Ralias stund='stg undo'
Ralias stundh='stg undo --hard'

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
