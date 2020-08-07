(
  HERE=$(cd $(dirname $BASH_SOURCE); cd -P $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)); pwd)
  ! (( ${LOADED[initutil]} )) && source $HERE/../lib/initutil.bash

  source $HERE/lib/truth.bash

  source $HERE/env.bash
  source $HERE/interactive-login.bash
  source $HERE/cmds.bash
  source $HERE/bash.bash
  source $HERE/interactive.bash

  source $HERE/apps.bash
)
