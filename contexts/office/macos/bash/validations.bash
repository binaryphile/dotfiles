(
  IFS=''
  source $(cd $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)) && pwd -P)/validation_functions.bash

  # PATH items
  get_repr <<EOS
    $HOME/.local/bin
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
    europe
    minimak
    pretend
    psaux
    qwerty
    runas
    salt
  EOS
  functions=$__

  # Environment variables
  get_repr <<EOS
    EDITOR=/usr/local/bin/nvim
    INPUTRC=$HOME/dotfiles/bash/inputrc
    PAGER=/usr/bin/less
    XDG_CONFIG_HOME=$HOME/.config
    _bash_profile=1
    _validated=1
EOS
  environment_variables=$__

  # Aliases
  get_repr <<'  EOS'
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
