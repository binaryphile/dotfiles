PATH=$HOME/.local/bin:$PATH

testCmdAndExport EDITOR vim
testCmdAndExport EDITOR nvim
testCmdAndExport PAGER less

testAndExport XDG_CONFIG_HOME $HOME/.config
