(
  Here=$(dirname "$BASH_SOURCE")

  ! (( ${Loaded[initutil]} )) && {
    source "$(dirname "$Here")"/lib/initutil.bash
    SplitSpace off
  }

  source $Here/lib/truth.bash

  source $Here/env.bash
  source $Here/interactive-login.bash
  source $Here/cmds.bash
  source $Here/bash.bash
  source $Here/interactive.bash

  source $Here/apps.bash
)
