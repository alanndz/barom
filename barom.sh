#!/usr/bin/env bash

# Copyright (C) 2019-2023 alanndz <alanmahmud0@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

NAME="Barom"
VERSION="2.0"

cwd=$(pwd)

dbg() { echo -e "\e[92m[*] $@\e[39m"; }
err() { echo -e "\e[91m[!] $@\e[39m"; exit 1; }
grn() { echo -e "\e[92m$@\e[39m"; }
red() { echo -e "\e[91m$@\e[39m"; }

# Checking dependencies
#for dep in git env basename mkdir rm mkfifo jq expect ccache wget openssl
#do
#   ! command -v "$dep" &> /dev/null && err "Unable to locate dependency $dep. Exiting."
#done

CONF=".barom"
if [[ ! -d $CONF ]]; then
    dbg "Creating $CONF folder's for configs"
    mkdir -p $CONF
fi

##### Setup Config #####
Config.name() { git config -f "$CONF/barom.conf" barom.name $1; }
Config.lunch() { git config -f "$CONF/barom.conf" barom.lunch $1; }
Config.device() { git config -f "$CONF/barom.conf" barom.device $1; }
Config.cmd() { git config -f "$CONF/barom.conf" barom.cmd ${1// /.}; }
Config.jobs() { git config -f "$CONF/barom.conf" barom.jobs $1; }
Config.tgid() { git config -f "$CONF/barom.conf" telegram.channelid $1; }
Config.tgtoken() { git config -f "$CONF/barom.conf" telegram.token $1; }
Config.manifest() { git config -f "$CONF/barom.conf" repo.manifest $1; }
Config.branch() { git config -f "$CONF/barom.conf" repo.branch $1; }
Config.sfuser() { git config -f "$CONF/barom.conf" sourceforge.user $1; }
Config.sfpass() { git config -f "$CONF/barom.conf" sourceforge.pass $1; }
Config.sfpath() { git config -f "$CONF/barom.conf" sourceforge.path $1; }

# Create default config if barom.conf empty
if [[ ! -f "$CONF/barom.conf" ]]; then
    Config.name BiancaProject
    Config.lunch vayu-user
    Config.device vayu
    Config.cmd "m dudu"
    Config.jobs $(nproc --all)
fi
##### End Setup Config #####

# Pull telegram.sh
[[ ! -f "$CONF/telegram.sh" ]] && curl -L -o "$CONF/telegram.sh" -s https://github.com/alanndz/barom/raw/main/telegram.sh

TMP_SYNC="sync-rom.log"

dnc() { echo "$(openssl enc -base64 -d <<< $@)"; }
enc() { echo "$(openssl enc -base64 <<< $@)"; }

repo() {
    echo "repo $@"
    return 88
}

repoInit() {
    repo init -u $1 -b $2
}

repoSync() {
    mkfifo sync
    tee "$TMP_SYNC" < sync &
    repo sync --force-sync --no-tags --no-clone-bundle --current-branch -j$(Config.jobs) --prune "$@" > sync
    local ret=$?
    rm sync
    return $ret
}

fixErrorSync() {
    local a=$(grep 'Cannot remove project' "$TMP_SYNC" -m1 || true)
    local b=$(grep "^fatal: remove-project element specifies non-existent project" "$TMP_SYNC" -m1 || true)
    local c=$(grep 'repo sync has finished' "$TMP_SYNC" -m1 || true)
    local d=$(grep 'Failing repos:' "$TMP_SYNC" -n -m1 || true)
    local e=$(grep 'fatal: Unable' "$TMP_SYNC" || true)
    local f=$(grep 'error.GitError' "$TMP_SYNC" || true)
    local g=$(grep 'error: Cannot checkout' "$TMP_SYNC" || true)
    local h=$(grep "repo" "$TMP_SYNC" || true)

    if [[ $a == *'Cannot remove project'* ]]
    then
        a=$(echo $a | cut -d ':' -f2 | tr -d ' ')
        rm -rf $a
    fi

    if [[ $b == *'remove-project element specifies non-existent'* ]]
    then exit 1
    fi

    if [[ $d == *'Failing repos:'* ]]
    then
        d=$(expr $(grep 'Failing repos:' "$TMP_SYNC" -n -m 1| cut -d ':' -f1) + 1)
        d2=$(expr $(grep 'Try re-running' "$TMP_SYNC" -n -m1 | cut -d ':' -f1) - 1 )
        fail_paths=$(head -n $d2 "$TMP_SYNC" | tail -n +$d)
        for path in $fail_paths
        do
            rm -rf $path
            aa=$(echo $path|awk -F '/' '{print $NF}')
            rm -rf .repo/project-objects/*$aa.git
            rm -rf .repo/projects/$path.git
        done
    fi

    if [[ $e == *'fatal: Unable'* ]]
    then
        fail_paths=$(grep 'fatal: Unable' "$TMP_SYNC" | cut -d ':' -f2 | cut -d "'" -f2)
        for path in $fail_paths
        do
            rm -rf $path
            aa=$(echo $path|awk -F '/' '{print $NF}')
            rm -rf .repo/project-objects/*$aa.git
            rm -rf .repo/project-objects/$path.git
            rm -rf .repo/projects/$path.git
        done
    fi

    if [[ $f == *'error.GitError'* ]]
    then
        rm -rf $(grep 'error.GitError' "$TMP_SYNC" | cut -d ' ' -f2)
    fi

    if [[ $g == *'error: Cannot checkout'* ]]
    then
        coerr=$(grep 'error: Cannot checkout' "$TMP_SYNC" | cut -d ' ' -f 4| tr -d ':')
        for i in $coerr
        do
            rm -rf .repo/project-objects/$i.git
        done
    fi

    if [[ -n $(grep "repo" "$TMP_SYNC" || true) ]]
    then
        echo "Let try fix"
    fi
}

# Parse options
END_OF_OPT=
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "${END_OF_OPT}${1}" in
        -i|--init)
            if [ -n "$2" ] && [ -n "$3" ] && [ ${2:0:1} != "-" ]; then
                Config.manifest "$2"
                Config.branch "$3"
                repoInit "$2" "$3"
                shift 2
            else
                err "Error: Argument for $1 is missing or more/less than 2 argument"
            fi
            ;;
        --reinit)
            repoInit $(Config.manifest) $(Config.branch)
            ;;
        -r|--resync)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                RESYNC_CUSTOM="$2"
                shift
            fi
            RESYNC=1
            ;;
        -l|--lunch)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                Config.lunch "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        -d|--device)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                Config.device "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        -n|--name)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                Config.name "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        -j|--jobs)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                Config.jobs "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        -b)
            BUILD=1
            ;;
        -c|--clean)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                CLEAN="$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        -L)
            LUNCH=1
            ;;
        -u|--upload)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                UPLOAD="$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        -t|--telegram)
            if [ -n "$2" ] && [ -n "$3" ] && [ ${2:1:1} -eq ${2:1:1} ]; then
                Config.tgid "$(enc $2)"
                Config.tgtoken "$(enc $3)"
                shift 2
            else
                err "Error: Argument for $1 is missing or more/less than 2 argument"
            fi
            ;;
        -v|--version)
            echo "$NAME $VERSION"
            exit 0
            ;;
        --)
            END_OF_OPT=1 ;;
        *)
            POSITIONAL+=("$1") ;;
    esac
    shift
done

# Restore positional parameters
set -- "${POSITIONAL[@]}"

# RESYNC
if [[ $RESYNC -eq 1 ]]
then
    if ! repoSync "$RESYNC_CUSTOM"
    then
        fixErrorSync
    fi
fi

# CCACHE
export PATH="/usr/lib/ccache:$PATH"


# CLEAN

[[ $BUILD -ne 1 ]] && exit

source build/envsetup.sh 2> /dev/null
[[ $? -ne 0 ]] && dbg "Error: failed load build/envsetup.sh"

lunch_
[[ $LUNCH -eq 1 ]] && echo $?


echo "Tekan kene"

#CMD=$(Config.cmd)
#"${CMD//./ }"