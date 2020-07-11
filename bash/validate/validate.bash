(
  source $HERE/lib/truth.bash

  HERE=$(cd $(dirname $BASH_SOURCE); cd -P $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)); pwd)

  source $HERE/environment.bash
  source $HERE/config.bash
  source $HERE/interactive.bash
  source $HERE/apps.bash
)
