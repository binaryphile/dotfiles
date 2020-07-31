(
  HERE=$(cd $(dirname $BASH_SOURCE); cd -P $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)); pwd)
  [[ -v LOADED[initutil] ]] || source $HERE/../lib/initutil.bash

  source $HERE/lib/truth.bash

  source $HERE/env.assertions
  source $HERE/interactive-login.assertions
  source $HERE/cmds.assertions
  source $HERE/bash.assertions
  source $HERE/interactive.assertions

  source $HERE/apps.bash
)
