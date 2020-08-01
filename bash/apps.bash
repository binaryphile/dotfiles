pushd $HERE/apps >/dev/null

declare -A Deps=()
declare -A Satisfied=()

for Dir in *; do
  isDir $Dir || continue

  if isFile $Dir/detect.bash; then
    source $Dir/detect.bash || continue
  else
    isCmd $Dir || continue
  fi

  isFile $Dir/deps && {
    Deps[$Dir]=$(<$Dir/deps)
    for Dep in ${Deps[$Dir]}; do
      (( ${Satisfied[$Dep]} )) || continue 2
    done
    unset -v Deps[$Dir]
  }

  IFS=$' \t\n'
  testAndSource "$Dir"/init.settings
  IFS=$NL

  testLoginAndSource $Dir/env.settings
  testAndSource $Dir/interactive.settings
  testAndSource $Dir/cmds.settings

  Satisfied[$Dir]=1

  for Key in ${!Deps[*]}; do
    ! contains "${Deps[$Key]}" $Dir && continue
    Ary=( ${Deps[$Key]} )
    remove Ary $Dir
    Deps[$Key]=${Ary[*]}
    ! (( ${#Ary} )) && {
      unset -v Deps[$Key]

      IFS=$' \t\n'
      testAndSource "$Key"/init.settings
      IFS=$NL

      testLoginAndSource $Key/env.settings
      testAndSource $Key/interactive.settings
      testAndSource $Key/cmds.settings
    }
  done
done

unset -v Ary Dep Deps Dir Key Satisfied
popd >/dev/null
