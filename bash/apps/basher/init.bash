source "$BASHER_ROOT"/lib/include.bash

source "$BASHER_ROOT"/completions/basher.bash

shopt -s nullglob

for f in "$BASHER_PREFIX"/completions/bash/*; do
  source "$f"
done

shopt -u nullglob
