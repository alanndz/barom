#!/usr/bin/env bash

if [[ -n "$1" ]]
then
	BRANCH="$1"
else
	BRANCH=main
fi

curl -Lo /tmp/barom https://raw.githubusercontent.com/alanndz/barom/"$BRANCH"/barom.sh # https://git.io/JUjwP
chmod +x /tmp/barom
sudo install /tmp/barom /usr/local/bin/barom