#!/usr/bin/env bash

sudo apt update
sudo apt install -y \
	jq \
	expect \
	ccache \
	wget

wget -O /tmp/barom https://git.io/JUjwP
chmod +x /tmp/barom
sudo install /tmp/barom /usr/local/bin/barom

wget https://github.com/AnggaR96s/gdrive/releases/download/2.2.0/gdrive_2.2.0_linux_386.tar.gz
tar xf gdrive_2.2.0_linux_386.tar.gz
chmod +x gdrive
sudo install gdrive /usr/local/bin/gdrive
rm gdrive
rm gdrive_2.2.0_linux_386.tar.gz


