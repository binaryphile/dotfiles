# init.bash - main script for init

# Root is the location of this script, normalized for symlinks
Root=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo .)")"; pwd)
[[ $1 == reload ]] && Reload=1 || Reload=0

Vars=( Reload Root ) # vars to cleanup

source "$Root"/lib/initutil.bash

SplitSpace off  # don't require quotes on normal string vars, by setting IFS to newline
Globbing off    # turn off globbing until I need it

# "source ~/.bashrc reload" forces reload of everything, including environment
# and login actions.
{ ShellIsLogin || (( Reload )); } && source $Root/settings/env.bash

TestAndSource $Root/context/init.bash  # context-specific initialization, if applicable
source $Root/lib/apps.bash        # app-specific environment and commands, see apps/
source $Root/settings/base.bash   # general configuration, always loaded
source $Root/settings/cmds.bash   # aliases and functions

# interactive settings
ShellIsInteractive && source $Root/settings/interactive.bash

# one-time, interactive-only login tasks and configuration validation
{ ShellIsInteractiveAndLogin || (( Reload )); } && source $Root/settings/login.bash

(( Reload )) && echo reloaded

# so we can tell this script has been run
export ENV_SET=1

# cleanup
SplitSpace on
Globbing on
unset -f "${Functions[@]}"
unset -v "${Vars[@]}"
