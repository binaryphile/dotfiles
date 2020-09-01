pushd $Root/apps >/dev/null

AppList=$(ListDir . | Filter IsDir | Filter IsApp | OrderByDependencies)

for App in $AppList; do
  { ShellIsLogin || [[ $1 == reload ]]; } && TestAndSource $App/env.bash

  SplitSpace on
  Globbing on

  TestAndSource "$App"/init.bash

  SplitSpace off
  Globbing off

  TestAndSource $App/interactive.bash
  TestAndSource $App/cmds.bash
done

unset -v AppList App
popd >/dev/null
