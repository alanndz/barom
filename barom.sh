#!/usr/bin/env bash

# Copyright (C) 2019-2021 alanndz <alanmahmud0@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

NAME="Barom"
VERSION="1.6"

cwd=$(pwd)

dbg() { echo -e "\e[92m[*] $@\e[39m"; }
err() { echo -e "\e[91m[!] $@\e[39m"; exit 1; }
grn() { echo -e "\e[92m$@\e[39m"; }
red() { echo -e "\e[91m$@\e[39m"; }

# Checking dependencies
for dep in git env basename mkdir rm mkfifo jq expect ccache wget
do
	! command -v "$dep" &> /dev/null && err "Unable to locate dependency $dep. Exiting."
done

# Checking root of repo
if [ ! -e "build/envsetup.sh" ]; then
    err "Must run from root of repo"
fi

CONF=".`basename "$0"`-tools"
if [[ ! -d $CONF ]]; then
	dbg "Creating $CONF folder's for configs"
	mkdir -p $CONF
fi

if [[ ! -f "$CONF/telegram.sh" ]]; then
	dbg "Pulling telegram.sh"
	wget -O "$CONF/telegram.sh" https://github.com/alanndz/barom/raw/main/telegram.sh &> /dev/null
fi

##### Setup Environtment #####
Config.name() { git config -f "$CONF/barom.conf" barom.name $1; }
Config.lunch() { git config -f "$CONF/barom.conf" barom.lunch $1; }
Config.device() { git config -f "$CONF/barom.conf" barom.device $1; }
Config.cmd() { git config -f "$CONF/barom.conf" barom.cmd ${1// /.}; }
Config.jobs() { git config -f "$CONF/barom.conf" barom.jobs $1; }
Config.tgid() { git config -f "$CONF/barom.conf" telegram.channelid $1; }
Config.tgtoken() { git config -f "$CONF/barom.conf" telegram.token $1; }
Config.sfuser() { git config -f "$CONF/barom.conf" sourceforge.user $1; }
Config.sfpass() { git config -f "$CONF/barom.conf" sourceforge.pass $1; }
Config.sfpath() { git config -f "$CONF/barom.conf" sourceforge.path $1; }
Config.manifest() { git config -f "$CONF/barom.conf" repo.manifest $1; }
Config.branch() { git config -f "$CONF/barom.conf" repo.branch $1; }

# Create default env if barom.conf empty
if [[ ! -f "$CONF/barom.conf" ]]; then
    Config.name BiancaProject
    Config.lunch vayu-user
    Config.device vayu
    Config.cmd "lemao o"
    Config.jobs $(nproc --all)
fi
##### End Setup Environment #####

repo() {
    echo $@
}

repoInit() {
    repo init -u $1 -b $2
}

repoSync() {
    repo sync --force-sync --no-tags --no-clone-bundle --current-branch -j$(Config.jobs) --prune
}

# Pre-process options to:
# TODO: - expand -xyz into -x -y -z
# - expand --longopt=arg into --longopt arg
ARGV=()
END_OF_OPT=
while [[ $# -gt 0 ]]; do
	arg="$1"; shift
	case "${END_OF_OPT}${arg}" in
		--) ARGV+=("$arg"); END_OF_OPT=1 ;;
		--*=*)ARGV+=("${arg%%=*}" "${arg#*=}") ;;
		--*) ARGV+=("$arg"); END_OF_OPT=1 ;;
#		-*) for i in $(seq 2 ${#arg}); do ARGV+=("-${arg:i-1:1}"); done ;;
		*) ARGV+=("$arg") ;;
	esac
done

# Apply pre-processed options
set -- "${ARGV[@]}"

# Parse options
END_OF_OPT=
POSITIONAL=()
while [[ $# -gt 0 ]]; do
	case "${END_OF_OPT}${1}" in
		-I|--init)
            if [ $# -eq 3 ] && [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                Config.manifest $2
                Config.branch $3
                repoInit $2 $3
                echo $@
                shift 3
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            ;;
        --reinit)
            repoInit $(Config.manifest) $(Config.branch)
            ;;
        -r|--sync)
            RESYNC=1
            ;;
        -l|--lunch)
            shift
            Config.lunch $1
            ;;
        -d|--device)
            shift
            Config.device $1
            ;;
        -n|--name)
            shift
            Config.name $1
            ;;
        -j|--jobs)
            shift
            Config.jobs $1
            ;;
        -b)
            BUILD=1
            ;;
        -c|--clean)
            shift
            CLEAN=$1
            ;;
        -L)
            LUNCH=1
            ;;
        -u|--upload)
            shift
            UPLOAD=$1
            ;;
        -t|--telegram)
            shift
            echo $#
            echo $@
            ;;
		-v|--version)
			echo "$NAME $VERSION"
			exit 0
			;;
		--)
			END_OF_OPT=1 ;;
#		-*)
#			invalid "$1" ;;
		*)
			POSITIONAL+=("$1") ;;
	esac
	shift
done

# Restore positional parameters
set -- "${POSITIONAL[@]}"

#CMD=$(Config.cmd)
#"${CMD//./ }"