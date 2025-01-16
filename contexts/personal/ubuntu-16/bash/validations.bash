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
    $HOME/.basher/cellar/bin
    /snap/bin
EOS
  paths=$__

  # Variables used in bashrc which should be unset
  get_repr <<'  EOS'
    JAVA_TOOL_OPTIONS
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
    randword
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
    JAVA_OPTS=-Xms1024m -Xmx4098m -Dfile.encoding=UTF-8 -Djava.net.preferIPv6Stack=true -Djboss.modules.system.pkgs=org.jboss.byteman -Djava.awt.headless=true
    JRUBY_OPTS=--dev
    NIXPKGS_ALLOW_UNFREE=1
    NIX_CONF_DIR=/nix/etc
    NIX_PATH=ssh-config-file=/nix/etc/ssh_config:aview-nixpkgs=$HOME/.nix-defexpr/channels/aview-nixpkgs:nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs
    NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    RUBY_VERSION=2.3.3
    XDG_CONFIG_HOME=$HOME/.config
    _bash_profile=1
    _validated=1
EOS
  environment_variables=$__

  # Aliases
  get_repr <<'  EOS'
    boxcr
    forward
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
    unbox
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
