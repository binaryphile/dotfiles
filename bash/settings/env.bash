PATH=$HOME/.local/bin:$PATH

TestCmdAndExport EDITOR nvim vim
TestCmdAndExport PAGER less

TestAndExport XDG_CONFIG_HOME $HOME/.config

export LC_SSH_USER=$USER
