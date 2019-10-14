#!/usr/bin/env bash

sudo yum -y install vim-enhanced
git clone git://github.com/binaryphile/dot_vim $HOME/.vim
pushd $HOME/.vim
git checkout centos65
scripts/setup
popd
