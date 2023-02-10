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
prin() { echo -e "$@"; }

# Checking dependencies
#for dep in git env basename mkdir rm mkfifo jq expect ccache wget openssl
#do
#   ! command -v "$dep" &> /dev/null && err "Unable to locate dependency $dep. Exiting."
#done

CONF=".barom"
RESULT="result"
if [[ ! -d $CONF || ! -d $RESULT || ! -d "$RESULT/log" ]]; then
    dbg "Creating $CONF/$RESULT folder's for configs"
    mkdir -p $CONF $RESULT $RESULT/log
fi

##### Setup Config #####
Config.name() { git config -f "$CONF/barom.conf" barom.name "$@"; }
Config.lunch() { git config -f "$CONF/barom.conf" barom.lunch "$@"; }
Config.device() { git config -f "$CONF/barom.conf" barom.device "$@"; }
Config.cmd() { git config -f "$CONF/barom.conf" barom.cmd "$@"; }
# Config.cmd() { echo $@; }
Config.jobs() { git config -f "$CONF/barom.conf" barom.jobs "$@"; }
Config.tgid() { git config -f "$CONF/barom.conf" telegram.channelid "$@"; }
Config.tgtoken() { git config -f "$CONF/barom.conf" telegram.token "$@"; }
Config.manifest() { git config -f "$CONF/barom.conf" repo.manifest "$@"; }
Config.branch() { git config -f "$CONF/barom.conf" repo.branch "$@"; }
Config.sfuser() { git config -f "$CONF/barom.conf" sourceforge.user "$@"; }
Config.sfpass() { git config -f "$CONF/barom.conf" sourceforge.pass "$@"; }
Config.sfpath() { git config -f "$CONF/barom.conf" sourceforge.path "$@"; }

# Create default config if barom.conf empty
if [[ ! -f "$CONF/barom.conf" ]]; then
    Config.name BiancaProject
    Config.lunch vayu-user
    Config.device vayu
    Config.cmd "m dudu"
    Config.jobs $(nproc --all)
fi
##### End Setup Config #####

dnc() { echo "$(openssl enc -base64 -d <<< $@)"; }
enc() { echo "$(openssl enc -base64 <<< $@)"; }

# Pull telegram.sh
[[ ! -f "$CONF/telegram.sh" ]] && curl -L -o "$CONF/telegram.sh" -s https://github.com/alanndz/barom/raw/main/telegram.sh
[[ -f "$CONF/telegram.sh" ]] && source "$CONF/telegram.sh" || err "Error: file "$CONF/telegram.sh" not found, please check internet connection for download first"

TMP_SYNC="sync-rom.log"

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

lun() {
    echo "lun $@"
    return 0
}

lunch_() {
    lun $(Config.lunch) > filunch
    local ret=$?
    if [[ $ret -ne 0 ]]
    then
        err "Error: lunch $(Config.lunch) failed with code $ret"
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
            if [[ -n "$2" && -n "$3" && ${2:1:1} -eq ${2:1:1} ]]; then
                Config.tgid "$(enc $2)"
                Config.tgtoken "$(enc $3)"
                shift 2
            else
                err "Error: Argument for $1 is missing or more/less than 2 argument"
            fi
            ;;
        --send-file)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                send_file "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            exit
            ;;
        --upload-rom-latest)
            prin "TO DO"
            #exit
            ;;
        --upload-rom-file)
            prin "TO DO"
            #exit
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

# Write every changes
if [[ -n $@ ]]
then
    CMD_="$@"
    #CMD=${CMD// /.}
    Config.cmd "${CMD_}"
fi

# RESYNC
if [[ $RESYNC -eq 1 ]]
then
    bot "Sync all repository ..."
    if ! repoSync "$RESYNC_CUSTOM"
    then
        bot "Sync failed, trying to fixing ..."
        fixErrorSync
    fi
fi

# Check file build/envsetup.sh, if false exit
[[ -f build/envsetup.sh ]] || exit

# Preparing Env before build
ROM=$(Config.name)
DEVICE=$(Config.device)
[[ -z $ROM ]] && ROM="Build-rom"
CMD=$(Config.cmd)
#CMD="${CMD//./ }"
CMD=($CMD)
JOBS=$(Config.jobs)
DATELOG="$(date "+%H%M-%d%m%Y")"
LOG_LUNCH="$RESULT/log/lunch.log"
LOG_BUILD="$RESULT/log/build.log"
LOG_OK="$RESULT/log/$ROM-$(Config.device)-${DATELOG}.log"
LOG_TRIM="$RESULT/log/$ROM-$(Config.device)-${DATELOG}_error.log"
O="out/target/product/$(Config.device)"

# Preparing log record
mkfifo filunch fibuild 2&> /dev/null
tee "$LOG_LUNCH" < filunch &
tee "$LOG_BUILD" < fibuild &

# CCACHE
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR="$XCACHE"
ccache -M 50G

# Import envsetup.sh
source build/envsetup.sh

# CLEAN
if [[ "$CLEAN" == "full" ]]; then
    bot "make clobber & make clean"
	make clobber
	make clean
elif [[ "$CLEAN" == "clean" ]]; then
    bot "make clean"
	make clean
elif [[ "$CLEAN" == "dirty" ]]; then
    bot "make installclean"
	make installclean
elif [[ "$CLEAN" == "device" ]]; then
    bot "make deviceclean"
	make deviceclean
fi

# LUNCH
bot "lunch $(Config.lunch)"
lun $(Config.lunch) > filunch
ret=$?
if [[ $ret -ne 0 ]]
then
    bot "lunch $(Config.lunch) failed with exit code $ret"
    bot_doc "$RESULT/log/lunch.log"
    err "Error: lunch $(Config.lunch) failed with exit code $ret"
fi

# Build start
[[ -z $BUILD ]] && exit
# Tracking progress
bot "Start building . . ."
progress "$LOG_BUILD" &
progress_pid=$!

# Real build started
TIME_START=$(date +%s)
echo "${@:-${CMD[@]}}" -j"$JOBS" > fibuild
ret=$?
TIME_END=$(date +%s)

# Kill proggres &
kill $progress_pid

# Time elapsed
t_() { echo "$(date -u --date @$(($TIME_END - $TIME_START)) +%H:%M:%S)"; }

# Split time elapsed
H=$(t_ | cut -f1 -d":")
M=$(t_ | cut -f2 -d":")
S=$(t_ | cut -f3 -d":")

if [[ $ret -ne 0 ]]
then
    bot "Build failed"
    build_fail "$H" "$M" "$S"
    cp "$LOG_BUILD" "$LOG_OK"
    bot_doc "$LOG_OK"
    sed -n '/FAILED:/,//p' "$LOG_OK" &> "$LOG_TRIM"
    bot_doc "$LOG_TRIM"
    err "Error: ${CMD[@]} failed with exit code $ret"
fi

# Build success
bot "Build success"
ROM=$(Config.name)
FILEPATH=$(ls -Art ${O}/${ROM}*${DEVICE}*.zip | head -1)
[[ -z $ROM ]] && FILEPATH=$(ls -Art ${O}/*.zip | head -1)
FILENAME=$(echo "$FILEPATH" | cut -f5 -d"/")
FILESUM=$(md5sum "$FILEPATH" | cut -f1 -d" ")
FILESIZE=$(ls -lah "$FILEPATH" | cut -d ' ' -f 5)

build_success "$H" "$M" "$S" "$FILENAME" "$FILESUM" "$FILESIZE"
cp "$LOG_TMP" "$LOG_OK"
bot_doc "$LOG_OK"

case $UPLOAD in
    wet)
        wetUpload "$FILEPATH"
        ;;
esac

# Cleaning 
rm -f fibuild filunch