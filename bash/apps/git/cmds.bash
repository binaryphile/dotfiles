ralias ga.='git add .'
ralias gadd='git add'
ralias gafor='git add --force'
ralias gapat='git add --patch'
ralias gbD='git branch -D'
ralias gball='git branch --all'
ralias gbdel='git branch --delete'
ralias gbran='git branch'
ralias gbvv='git branch -vv'
ralias gch-.='git checkout -- .'
ralias gch-='git checkout --'
ralias gchb='git checkout -b'
ralias gchec='git checkout'
ralias gclon='git clone'
ralias gcoam='git commit --amend'
ralias gcoane='git commit --amend --no-edit'
ralias gcome='git commit --message'
ralias gdcac='git diff --cached'
ralias gdiff='git diff'
ralias gfetc='git fetch'
ralias ginit='git init'
ralias glg='git lg'
ralias glsfi='git ls-files'
ralias gmerg='git merge'
ralias gmeab='git merge --abort'
ralias gmv='git mv'
ralias gpusf='git push --force'
ralias gpull='git pull'
ralias gpush='git push'
ralias gpussu='git push --set-upstream'
ralias gpust='git push --tags'
ralias greba='git rebase'
ralias grebc='git rebase --continue'
ralias grebi='git rebase --interactive'
ralias grebs='git rebase --skip'
ralias grefl='git reflog'
ralias gremv='git remote --verbose'
ralias gresH^='git reset HEAD^'
ralias grese='git reset'
ralias gresh='git reset --hard'
ralias greshH='git reset --hard HEAD'
ralias grm='git rm'
ralias grmfo='git rm --force'
ralias gshop='git show --patch'
ralias gshow='git show'
ralias gstasa='git stash apply'
ralias gstasd='git stash drop'
ralias gstasl='git stash list'
ralias gstassa='git stash save'
ralias gstasshp='git stash show --patch'
ralias gstats='git status --short'

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