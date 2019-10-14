#!/usr/bin/env bash

# sudo apt-get install -y ntpdate
# sudo ntpdate -b ntp.ubuntu.com
# sudo hwclock --systohc

sudo add-apt-repository -y ppa:hugegreenbug/cmt2
sudo apt-get update -qq
sudo apt-get install libevdevc libgestures xf86-input-cmt xinput
sudo apt-get -y purge xserver-xorg-input-synaptics
sudo ln -s /usr/share/xf86-input-cmt/50-touchpad-cmt-peppy.conf /usr/share/X11/xorg.conf.d/50-touchpad-cmt-peppy.conf
sudo apt-get install zram-config
