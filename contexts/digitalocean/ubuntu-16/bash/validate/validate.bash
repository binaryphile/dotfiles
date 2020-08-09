(
  Here=$(cd $(dirname $BASH_SOURCE); cd -P $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)); pwd)
  ! (( ${Loaded[initutil]} )) && source $Here/../../../../../bash/lib/initutil.bash

  source $Here/lib/truth.bash

  source $Here/env.bash
  source $Here/interactive-login.bash
  source $Here/cmds.bash
  source $Here/bash.bash
  source $Here/interactive.bash

  source $Here/apps.bash
)
