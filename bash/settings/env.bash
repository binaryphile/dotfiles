TestContainsAndPrepend PATH ~/.local/lib
TestContainsAndPrepend PATH /usr/local/bin
TestContainsAndPrepend PATH ~/.local/bin

TestCmdAndExport EDITOR nvim vim
TestCmdAndExport PAGER less

TestAndExport CFGDIR ~/.config
TestAndExport SECRETS ~/secrets
TestAndExport XDG_CONFIG_HOME $CFGDIR

export LC_SSH_USER=$USER
