(
  IFS=''
  source $(dirname $(readlink -f $BASH_SOURCE))/validation_functions.bash

  # PATH items
  get_repr <<EOS
    $HOME/.basher/bin
    $HOME/.basher/cellar/packages/binaryphile/kaizen/lib
    $HOME/.basher/cellar/packages/binaryphile/nano/lib
    $HOME/.basher/cellar/packages/binaryphile/sorta/lib
    $HOME/.basher/cellar/packages/binaryphile/y2s/lib
    $HOME/.basher/cellar/packages/binaryphile/concorde/lib
    $HOME/.basher/cellar/bin
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
EOS
  paths=$__

  # Variables used in bashrc which should be unset
  get_repr <<'  EOS'
    nix
    path
    path_ary
    reload
  EOS
  unset_variables=$__

  # Functions
  get_repr <<'  EOS'
    become
    dallas
    europe
    minimak
    pretend
    psaux
    qwerty
    runas
    salt
    shannon
  EOS
  functions=$__

  # Environment variables
  get_repr <<EOS
    BASHER_ROOT=$HOME/.basher
    EDITOR=/usr/bin/nvim
    INPUTRC=$HOME/dotfiles/bash/inputrc
    NIXPKGS_ALLOW_UNFREE=1
    NIX_CONF_DIR=/nix/etc
    NIX_PATH=nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs
    NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
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
    range
    stcal
    stcn
    stcom
    stdel
    stedi
    stflo
    stgot
    stini
    stnew
    stnwmw
    stpic
    stpop
    stpus
    stref
    stren
    strep
    stser
    stsho
    stunc
    stuncn
    stund
    stundh
    suaiy
    suaupd
    suaupdq
  EOS
  aliases=$__

  setting vi on                                           || echo "vi off"
  substr $TERM -256color                                  || echo "TERM: $TERM"
  [[ -z $IFS ]]                                           || printf 'IFS: %q\n' $IFS
  (( $(umask) == 022 ))                                   || echo "umask: $(umask)"
  verify_aliases                $aliases                  || echo $__
  verify_environment_variables  $environment_variables    || echo $__
  verify_functions              $functions                || echo $__
  verify_paths                  $paths                    || echo $__
  verify_unset_variables        $unset_variables          || echo $__
)
