(
  Here=$(dirname "$BASH_SOURCE")
  There=$Here/../validate

  ! (( ${Loaded[initutil]} )) && {
    source "$Here"/initutil.bash
    SplitSpace off
    Globbing off
  }

  source $Here/truth.bash

  source $There/env.bash
  source $There/login.bash
  source $There/cmds.bash
  source $There/base.bash
  source $There/interactive.bash

  source $Here/validate-apps.bash
)
