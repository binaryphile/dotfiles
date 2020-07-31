pushd $HERE/apps >/dev/null

for dir in *; do
  isDir $dir || continue

  if isFile $dir/detect.bash; then
    source $dir/detect.bash || continue
  else
    isCmd $dir || continue
  fi

  dir=$HERE/apps/$dir

  IFS=$' \t\n'
  $(testAndSource "$dir"/init.settings)
  IFS=$NL

  $(testLoginAndSource $dir/env.settings)
  $(testAndSource $dir/cmds.settings)
done

unset -v dir
popd >/dev/null
