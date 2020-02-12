(
  source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/validation_functions.bash

  # PATH items
  get_repr <<EOS
    /usr/local/sbin
    /usr/local/bin
    /usr/sbin
    /usr/bin
    /sbin
    /bin
    /usr/games
    /usr/local/games
    /snap/bin
EOS
  paths=$__

  # Variables used in bashrc which should be unset
  get_repr <<'  EOS'
    JAVA_TOOL_OPTIONS
    path
    path_ary
    reload
  EOS
  unset_variables=$__

  # Functions
  get_repr <<'  EOS'
    become
    psaux
    runas
  EOS
  functions=$__

  # Environment variables
  get_repr <<EOS
    EDITOR=/usr/bin/vim
    INPUTRC=$HOME/dotfiles/bash/inputrc
    XDG_CONFIG_HOME=$HOME/.config
    _bash_profile=1
    _validated=1
EOS
  environment_variables=$__

  # Aliases
  get_repr <<'  EOS'
    la
    ll
    ls
    oxtni
    suaiy
    suaupd
    suaupdq
  EOS
  aliases=$__

  setting vi on                                           || echo "vi off"
  substr "$TERM" -256color                                || echo "TERM: $TERM"
  (( $(umask) == 022 ))                                   || echo "umask: $(umask)"
  verify_aliases                "$aliases"                || echo "$__"
  verify_environment_variables  "$environment_variables"  || echo "$__"
  verify_functions              "$functions"              || echo "$__"
  verify_paths                  "$paths"                  || echo "$__"
  verify_unset_variables        "$unset_variables"        || echo "$__"
)

# vim: ft=sh
