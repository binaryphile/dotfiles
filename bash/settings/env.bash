PATH=$HOME/.local/bin:$PATH

TestCmdAndExport EDITOR vim
TestCmdAndExport EDITOR nvim
TestCmdAndExport PAGER less

TestAndExport XDG_CONFIG_HOME $HOME/.config

export LC_SSH_USER=$USER
