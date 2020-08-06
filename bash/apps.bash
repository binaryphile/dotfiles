pushd $HERE/apps >/dev/null

AppList=$(areApps *)
AppList=$(orderByDependencies $AppList)

for App in $AppList; do
  shellIsLogin && testAndSource $App/env.settings

  IFS=$' \t\n'
  testAndSource "$App"/init.bash
  IFS=$NL

  testAndSource $App/interactive.settings
  testAndSource $App/cmds.settings
done

unset -v AppList App
popd >/dev/null
