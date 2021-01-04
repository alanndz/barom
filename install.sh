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

wget https://raw.githubusercontent.com/usmanmughalji/gdriveupload/master/gdrive
chmod +x gdrive
sudo install gdrive /usr/local/bin/gdrive 


