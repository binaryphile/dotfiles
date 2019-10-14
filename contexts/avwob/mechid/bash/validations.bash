(
  source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/validation_functions.bash

  avwob=/opt/app/avwobt4

  # PATH items
  get_repr <<EOS
    $HOME/.local/bin
    $avwob/bin
    $avwob/cellar/packages/binaryphile/kaizen/lib
    $avwob/cellar/packages/binaryphile/nano/lib
    $avwob/cellar/packages/binaryphile/sorta/lib
    $avwob/cellar/packages/binaryphile/y2s/lib
    $avwob/cellar/packages/binaryphile/concorde/lib
    $avwob/bin
    $HOME/.local/bin
    /usr/local/bin
    /bin
    /usr/bin
    /usr/local/sbin
    /usr/sbin
    /sbin
EOS
  paths=$__

  # Variables used in bashrc which should be unset
  get_repr <<'  EOS'
    path
    path_ary
    reload
  EOS
  unset_variables=$__

  # Functions
  get_repr <<'  EOS'
    become
    europe
    psaux
    runas
  EOS
  functions=$__

  # Environment variables
  get_repr <<EOS
    INPUTRC=$HOME/dotfiles/bash/inputrc
    XDG_CONFIG_HOME=$HOME/.config
    _bash_profile=1
    _validated=1
EOS
  environment_variables=$__

  # Aliases
  get_repr <<'  EOS'
    ga.
    gadd
    gafor
    gapat
    gbD
    gball
    gbdel
    gbran
    gbvv
    gch-
    gch-.
    gchb
    gchec
    gclon
    gcoam
    gcome
    gdcac
    gdiff
    gfetc
    ginit
    glg
    glsfi
    gmeab
    gmv
    gpull
    gpusf
    gpush
    gpussu
    gpust
    greba
    grebc
    grebi
    grebs
    grefl
    gremv
    gresH^
    grese
    gresh
    greshH
    grm
    grmfo
    gshop
    gshow
    gstasa
    gstasd
    gstasl
    gstassa
    gstasshp
    gstats
    la
    ll
    ls
    oxtni
  EOS
  aliases=$__

  setting vi on                                           || echo "vi off"
  substr "$TERM" -256color                                || echo "TERM: $TERM"
  (( $(umask) == 2 ))                                     || echo "umask: $(umask)"
  verify_aliases                "$aliases"                || echo "$__"
  verify_environment_variables  "$environment_variables"  || echo "$__"
  verify_functions              "$functions"              || echo "$__"
  verify_paths                  "$paths"                  || echo "$__"
  verify_unset_variables        "$unset_variables"        || echo "$__"
)

# vim: ft=sh
