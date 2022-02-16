TestContainsAndPrepend PATH /usr/local/bin
TestContainsAndPrepend PATH $HOME/.local/bin

TestCmdAndExport EDITOR nvim vim
TestCmdAndExport PAGER less

TestAndExport CFGDIR $HOME/.config
TestAndExport XDG_CONFIG_HOME $CFGDIR

export LC_SSH_USER=$USER
