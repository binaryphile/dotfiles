source "$BASHER_ROOT"/lib/include.bash
source "$BASHER_ROOT"/completions/basher.bash
shopt -s nullglob
for f in "$BASHER_ROOT"/cellar/completions/bash/*; do source "$f"; done
shopt -u nullglob
unset -v f
