pushd $HERE/apps >/dev/null

AppList=$(areApps *)
AppList=$(orderByDependencies $AppList)

for App in $AppList; do
  { shellIsLogin || [[ $1 == reload ]]; } && testAndSource $App/env.bash

  IFS=$' \t\n'
  testAndSource "$App"/init.bash
  IFS=$NL

  testAndSource $App/interactive.bash
  testAndSource $App/cmds.bash
done

unset -v AppList App
popd >/dev/null
