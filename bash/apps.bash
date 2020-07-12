cd $HERE/apps

for dir in *; do
  ! isDir $HERE/apps/$dir && continue
  ! isCmd $dir && continue
  dir=$HERE/apps/$dir
  { isFile $dir/env.settings && shellIsLogin; } &&
    source $dir/env.settings
  isFile $dir/init.settings && source $dir/init.settings
  isFile $dir/cmds.settings && source $dir/cmds.settings
done

unset -v dir
cd - >/dev/null
