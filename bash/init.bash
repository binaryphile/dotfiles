# Here is the location of this script, normalized for symlinks
Here=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo "$BASH_SOURCE")")"; pwd)

source "$Here"/lib/initutil.bash

Nl=$'\n'        # Nl is newline, can be handy and is easier on the eyes
SplitSpace off  # don't require quotes on normal string vars, by setting IFS to newline
Globbing off    # turn off globbing until I need it

Vars+=(    # add to list of variables to cleanup before ending
  Here
  Nl
)

# uncomment and create in case the order below doesn't work for something
# source $Here/pre.bash

# "source ~/.bashrc reload" allows forcing reload of environment and login actions.
# ShellIsLogin defines login as any environment where this script hasn't yet
# run (by testing for ENV_SET), as opposed to bash --login.
{ ShellIsLogin || [[ $1 == reload ]]; } && {
  source $Here/env.bash   # general environment vars

  # one-time login tasks
  ShellIsInteractive && source $Here/interactive-login.bash
}

source $Here/apps.bash    # app-specific environment and commands, see apps/
source $Here/bash.bash    # bash-specific configuration
source $Here/cmds.bash    # general aliases and functions

# interactive settings
ShellIsInteractive && source $Here/interactive.bash

# uncomment and create in case the order above doesn't work for something
# source $Here/post.bash

# configuration validation
{ ShellIsInteractiveAndLogin || [[ $1 == reload ]]; } && source $Here/validate/validate.bash

[[ $1 == reload ]] && echo reloaded

# so we can tell this script has been run
export ENV_SET=1

# cleanup
SplitSpace on
Globbing on
unset -f "${Functions[@]}"
unset -v "${Vars[@]}"
