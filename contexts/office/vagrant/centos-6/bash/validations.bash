(
  source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/validation_functions.bash

  avwob=$HOME/avwob

  # PATH items
  get_repr <<EOS
    $HOME/.nix-profile/bin
    $HOME/.nix-profile/sbin
    $avwob/.local/bin
    $avwob/opt/torquebox/jruby/bin
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
    GIT_DISCOVERY_ACROSS_FILESYSTEM=1
    INPUTRC=$HOME/dotfiles/bash/inputrc
    XDG_CONFIG_HOME=$HOME/.config
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
    range
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
