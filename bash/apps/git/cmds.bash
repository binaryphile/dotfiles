Alias ga.='git add .'
Alias gad='git add'
Alias gaf='git add -f'
Alias gbr='git branch'
Alias gca='git commit --amend'
Alias gcb='git checkout -b'
Alias gch='git checkout'
Alias gcl='git clone'
Alias gcm='git commit -m'
Alias gco='git commit'
Alias gdi='git diff'
Alias gfe='git fetch'
Alias gin='git init -b main'
Alias glg='git lg'
Alias glo='git log'
Alias gls='git ls-files'
Alias gme='git merge'
Alias gmv='git mv'
Alias gpf='git push -f'
Alias gpu='git push'
Alias grb='git rebase'
Alias gre='git remote'
Alias grf='git reflog'
Alias grm='git rm'
Alias grs='git reset'
Alias gsh='git show'
Alias gss='git status -s'
Alias gst='git stash'

gcome () {
  reveal "$FUNCNAME"
  git commit --message "$JIRA${JIRA:+: }$*"
}

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

# Personal git overlay for local tools and vault in URMA project
alias urmagit='git --git-dir=/home/ted/repos/urmagit.git --work-tree=/home/ted/projects/urma-next'

# Helper aliases for urmagit following auto-completion pattern
Alias ua.='urmagit add .'
Alias uad='urmagit add'
Alias uaf='urmagit add -f'
Alias ubr='urmagit branch'
Alias uca='urmagit commit --amend'
Alias ucb='urmagit checkout -b'
Alias uch='urmagit checkout'
Alias ucl='urmagit clone'
Alias ucm='urmagit commit -m'
Alias uco='urmagit commit'
Alias udi='urmagit diff'
Alias ufe='urmagit fetch'
Alias uin='urmagit init -b main'
Alias ulg='urmagit lg'
Alias ulo='urmagit log'
Alias uls='urmagit ls-files'
Alias ume='urmagit merge'
Alias umv='urmagit mv'
Alias upf='urmagit push -f'
Alias upu='urmagit push'
Alias urb='urmagit rebase'
Alias ure='urmagit remote'
Alias urf='urmagit reflog'
Alias urm='urmagit rm'
Alias urs='urmagit reset'
Alias ush='urmagit show'
Alias uss='urmagit status -s'
Alias ust='urmagit stash'
