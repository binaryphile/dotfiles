NL=$'\n'  # NL is newline
IFS=$NL   # don't require quotes on normal string vars

# HERE is the location of this script, normalized for symlinks
HERE=$(cd $(dirname $BASH_SOURCE); cd -P $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)); pwd)

source $HERE/lib/initutil.bash

VARS+=(    # cleanup vars
  HERE
  NL
)

shellIsLogin || [[ $1 == reload ]] &&
  source $HERE/env.settings   # general environment vars
source $HERE/bash.settings    # bash-specific configuration
source $HERE/cmds.settings    # general aliases and functions
source $HERE/apps.bash        # app-specific environment and commands, see apps/

# interactive only
[[ $- == *i* ]] && {
  source $HERE/interactive.settings       # interactive mode settings
  shellIsLogin &&
    source $HERE/validate/validate.bash   # validate everything
}

[[ $1 == reload ]] && echo reloaded

cleanup
