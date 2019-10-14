(
  source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/validation_functions.bash

  # PATH items
  get_repr <<EOS
    $HOME/.basher/bin
    $HOME/.basher/cellar/packages/binaryphile/kaizen/lib
    $HOME/.basher/cellar/packages/binaryphile/nano/lib
    $HOME/.basher/cellar/packages/binaryphile/sorta/lib
    $HOME/.basher/cellar/packages/binaryphile/y2s/lib
    $HOME/.basher/cellar/packages/binaryphile/concorde/lib
    $HOME/.nix-profile/bin
    $HOME/.nix-profile/sbin
    $HOME/.local/bin
    /usr/local/sbin
    /usr/local/bin
    /usr/sbin
    /usr/bin
    /sbin
    /bin
    /usr/games
    /usr/local/games
    /snap/bin
    $HOME/.basher/cellar/bin
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
    EDITOR=/usr/bin/vim
    INPUTRC=$HOME/dotfiles/bash/inputrc
    NIXPKGS_ALLOW_UNFREE=1
    NIX_CONF_DIR=/nix/etc
    NIX_PATH=ssh-config-file=/nix/etc/ssh_config:aview-nixpkgs=$HOME/.nix-defexpr/channels/aview-nixpkgs:nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs
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
