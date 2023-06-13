export BASHER_SHELL=bash

export BASHER_ROOT=$HOME/.basher

export BASHER_PREFIX=$BASHER_ROOT/cellar

export BASHER_PACKAGES_PATH=$BASHER_PREFIX/packages

[[ :$PATH: != *:"$BASHER_PREFIX"/bin:* ]] && PATH+=:$BASHER_PREFIX/bin
