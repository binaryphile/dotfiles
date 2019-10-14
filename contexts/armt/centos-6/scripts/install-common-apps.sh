#!/usr/bin/env bash

# Requires EPEL repositories to be installed already
sudo yum -y install curl tmux highlight caca-utils htop ctags

# Install ranger
curl -OL http://nongnu.org/ranger/ranger-stable.tar.gz
tar xvzf ranger-stable.tar.gz
cd ranger-1.6.1
sudo make install
cd ..
sudo rm -rf ranger-*

# Install silver searcher
curl -OL http://swiftsignal.com/packages/centos/6/x86_64/the-silver-searcher-0.14-1.el6.x86_64.rpm
sudo yum -y install the-silver-searcher-0.14-1.el6.x86_64.rpm
rm the-silver-searcher-*

# Install fish
sudo yum-config-manager --add-repo http://download.opensuse.org/repositories/shells:/fish:/nightly:/master/RedHat_RHEL-6/shells:fish:nightly:master.repo
sudo yum -y install fish
sudo chsh -s /usr/bin/fish ted
git clone git://github.com/bpinto/oh-my-fish $HOME/.config/oh-my-fish
