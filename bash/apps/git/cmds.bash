Alias ga.='git add .'
Alias gad='git add'
Alias gaf='git add -f'
Alias gbD='git branch -D'
Alias gba='git branch --all'
Alias gbd='git branch -d'
Alias gbm='git branch -m'
Alias gbr='git branch'
Alias gc-='git checkout --'
Alias gc.='git checkout -- .'
Alias gca='git commit --amend'
Alias gcb='git checkout -b'
Alias gch='git checkout'
Alias gcl='git clone'
Alias gcm='git commit -m'
Alias gco='git commit'
Alias gdc='git diff --cached'
Alias gdi='git diff'
Alias gfe='git fetch'
Alias gin='git init -b main'
Alias glg='git lg'
Alias glo='git log'
Alias gls='git ls-files'
Alias gme='git merge'
Alias gmv='git mv'
Alias gpf='git push -f'
Alias gps='git push --set-upstream'
Alias gpu='git push'
Alias grb='git rebase'
Alias grc='git rebase --continue'
Alias gre='git remote'
Alias grf='git reflog'
Alias grh='git reset --hard'
Alias grm='git rm'
Alias grs='git reset'
Alias gsa='git stash apply'
Alias gsd='git stash drop'
Alias gsh='git show'
Alias gss='git status -s'
Alias gssh='git stash show'
Alias gst='git stash'

correct () {
  reveal "$FUNCNAME"
  git fetch
  git branch --merged origin/"$1" | grep -v "$1"$ | xargs $([[ $OSTYPE != darwin* ]] && echo -r) git branch -D
}

europe () {
  reveal "$FUNCNAME"
  git add --patch
  git commit -m "${1:-}"
  git push
}

pastel () {
  reveal "$FUNCNAME"
  git checkout -b "$1"
  git push --set-upstream origin "$1"
}

flute () {
  reveal "$FUNCNAME"
  git add .
  git commit --amend
  git push -f
}

venice() {
  local long=$1 short=$2 branch=${3:-develop}
  reveal "$FUNCNAME"
  git fetch
  git checkout --no-track -b "$long" origin/"$branch"
  git push --set-upstream origin "$long"
  git branch -m "$long" "$short"
}

wolf () {
  reveal "$FUNCNAME"
  git add .
  git commit -m "${JIRA:-}${JIRA:+: }$*"
  git push
}
