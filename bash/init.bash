# init.bash - main script for init

# Root is the location of this script, normalized for symlinks
Root=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo "$BASH_SOURCE")")"; pwd)

Vars=( Root ) # vars to cleanup

source "$Root"/lib/initutil.bash

SplitSpace off  # don't require quotes on normal string vars, by setting IFS to newline
Globbing off    # turn off globbing until I need it

# "source ~/.bashrc reload" forces reload of everything, including environment
# and login actions.
{ ShellIsLogin || [[ $1 == reload ]]; } && source $Root/settings/env.bash

source $Root/lib/apps.bash        # app-specific environment and commands, see apps/
source $Root/settings/base.bash   # general configuration, always loaded
source $Root/settings/cmds.bash   # aliases and functions

# interactive settings
ShellIsInteractive && source $Root/settings/interactive.bash

# one-time, interactive-only login tasks and configuration validation
{ ShellIsInteractiveAndLogin || [[ $1 == reload ]]; } && source $Root/settings/login.bash

[[ $1 == reload ]] && echo reloaded

# so we can tell this script has been run
export ENV_SET=1

# cleanup
SplitSpace on
Globbing on
unset -f "${Functions[@]}"
unset -v "${Vars[@]}"
