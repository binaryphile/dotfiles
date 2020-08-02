pushd $HERE/apps >/dev/null

AppList=$(areApps *)
AppList=$(orderByDependencies $AppList)

for App in $AppList; do
  IFS=$' \t\n'
  testAndSource "$App"/init.settings
  IFS=$NL

  testLoginAndSource $App/env.settings
  testAndSource $App/interactive.settings
  testAndSource $App/cmds.settings
done

unset -v AppList App
popd >/dev/null
