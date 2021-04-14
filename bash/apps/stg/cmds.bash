Alias stbcf='stg branch --cleanup --force'
Alias stcom='stg commit'
Alias stcal='stg commit --all'
Alias stcn='stg commit -n'
Alias stdel='stg delete'
Alias stedi='stg edit'
Alias stflo='stg float'
Alias stgot='stg goto'
Alias stini='stg init'
Alias stnew='stg new'
Alias stnme='stg new --message'
Alias stnwmw='stg new wip -m wip'
Alias stpic='stg pick'
Alias stpop='stg pop'
Alias stpul='stg pull'
Alias stpus='stg push'
Alias stref='stg refresh'
Alias strefi='stg refresh --index'
Alias stren='stg rename'
Alias strep='stg repair'
Alias stser='stg series'
Alias stsho='stg show'
Alias stsin='stg sink'
Alias stsqu='stg squash'
Alias stunc='stg uncommit'
Alias stuncn='stg uncommit -n'
Alias stund='stg undo'
Alias stundh='stg undo --hard'

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
