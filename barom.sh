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
prin() { echo -e "$@"; }

# Checking dependencies
for dep in git env basename mkdir rm mkfifo jq ccache openssl curl repo
do
   ! command -v "$dep" &> /dev/null && err "Unable to locate dependency $dep. Exiting."
done

CONF="$cwd/.barom"
BIN="$HOME/.barom"
RESULT="$cwd/result"
if [[ ! -d $CONF || ! -d $RESULT || ! -d "$RESULT/log" || ! -d "$BIN" ]]; then
    dbg "Creating $BIN, $CONF, $RESULT, $RESULT/log folder's for configs"
    mkdir -p $CONF $RESULT $RESULT/log $BIN
fi

##### Setup Config #####
Config.name() { git config -f "$CONF/barom.conf" barom.name "$@"; }
Config.lunch() { git config -f "$CONF/barom.conf" barom.lunch "$@"; }
Config.device() { git config -f "$CONF/barom.conf" barom.device "$@"; }
Config.cmd() { git config -f "$CONF/barom.conf" barom.cmd "$@"; }
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
    Config.lunch vayu-user
    Config.device vayu
    Config.cmd "m dudu"
    Config.jobs $(nproc --all)
fi
##### End Setup Config #####
export PATH="$BIN:/usr/lib/ccache:$PATH"

dnc() { echo "$(openssl enc -base64 -d <<< $@)"; }
enc() { echo "$(openssl enc -base64 <<< $@)"; }

# Pull telegram.sh
[[ ! -f "$BIN/barom-telegram" ]] && curl -L -o "$BIN/barom-telegram" -s https://github.com/alanndz/barom/raw/main/telegram.sh
[[ -f "$BIN/barom-telegram" ]] && source "$BIN/barom-telegram" || err "Error: file "$BIN/barom-telegram" not found, please check internet connection for download first"
[[ ! -f "$BIN/transfer" ]] && curl -sL https://git.io/file-transfer | sh && mv transfer "$BIN"

TMP_SYNC="sync-rom.log"

repoInit() {
    repo init -u $1 -b $2
}

repoSync() {
    mkfifo sync 2&> /dev/null
    tee "$TMP_SYNC" < sync &
    local custom="$@"
    repo sync --force-sync --no-tags --no-clone-bundle --current-branch -j$(Config.jobs) $custom > sync
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

upload() {
    TRS=$(transfer $1 $2)
	link=$(echo "$TRS" | grep "Download" | cut -d" " -f3)
    echo "$link"
}

usage() {
    #prin "$NAME $VERSION"
    #prin "Author: Alanndz"
    #prin ""
    prin "Usage: $(basename $0) [OPTION <ARGUMENT>] [OPTION] -- [BUILD COMMAND]"
    prin 
    prin "Options:"
    prin "  -b, --build                     Start build"
    prin "  -l, --lunch <lunch cmd>         Define lunch command, (ex: vayu-userdebug)"
    prin "  -d, --device <device>           Define device for to build, (ex: vayu)"
    prin "  -c, --clean <option>            Make clean/dirty, description in below"
    prin "  -n, --name <rom name>           Define rom name, it will help to detect name file for upload"
    prin "  -L                              Show lunch command only, dont start  the build"
    prin "  -h, --help                      Show usage"
    prin "  -v, --version                   Show version"
    prin
    prin "Repo:"
    prin "  -i, --init <manifest> <branch>  Define manifest and branch to repo init"
    prin "  --reinit                        Repo init again with already define by -i"
    prin "  -r, --resync                    Repo sync all repository after define using -i"
    prin "  -r, --resync <path>             Repo sync with custom path not all repository"
    prin
    prin "-c, --clean options description:"
    prin "  full            make clobber and make clean"
    prin "  dirty           make installclean"
    prin "  clean           make clean"
    prin "  device          make deviceclean"
    prin
    prin "Telegram:"
    prin "  -t, --telegram <ch id> <tg token>   Define channel id and telegram token, it will tracking proggress and send status to telegram channel"
    prin "  --send-file-tg <path file>          Send file to telegram"
    prin
    prin "Upload:"
    prin "  -u, --upload <wet>               Upload rom after finished build"
    prin "  --upload-rom-latest              Upload latest rom from $RESULT folder"
    prin "  --upload-file <file>             Upload file only and exit"
    prin 
    prin "Notes: [!] For upload, for now just support wetransfer<wet>"
    prin "       [!] Dont use --upload-rom-latest, --upload-file, --send-file-tg with other option/argument"
    prin
    prin "Example: barom -b -d vayu -l vayu-user -c clean -n BiancaProject -u wet -- m dudu"
    prin 

    exit 0
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
        -b|--build)
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
        --send-file-tg)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                [[ -z $BOT ]] && err "Error: Telegram token or channel id not defined!"
                send_file "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            exit
            ;;
        --upload-rom-latest)
            FILEPATH=$(ls -Art $RESULT/*.zip | tail -1)
            dbg "Uploading $FILEPATH"
            upload wet "$FILEPATH"
            exit
            ;;
        --upload-rom-file)
            prin "TO DO"
            exit
            ;;
        --upload-file)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                link=$(upload wet "$2")
                dbg "Uploaded to $link"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            exit
            ;;
        -v|--version)
            prin "$NAME $VERSION"
            exit 0
            ;;
        -h|--help)
            usage
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
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR="$cwd/.ccache"
ccache -M 50G

# Import envsetup.sh
source build/envsetup.sh

# CLEAN
if [[ "$CLEAN" == "full" ]]; then
    dbg "make clobber & make clean"
    bot "make clobber & make clean"
	make clobber
	make clean
elif [[ "$CLEAN" == "clean" ]]; then
    dbg "make clean"
    bot "make clean"
	make clean
elif [[ "$CLEAN" == "dirty" ]]; then
    dbg "make installclean"
    bot "make installclean"
	make installclean
elif [[ "$CLEAN" == "device" ]]; then
    dbg "make deviceclean"
    bot "make deviceclean"
	make deviceclean
fi

[[ -z $BUILD ]] && exit

# LUNCH
bot "lunch $(Config.lunch)"
lunch $(Config.lunch) > filunch
ret=$?
if [[ $ret -ne 0 ]]
then
    bot "lunch $(Config.lunch) failed with exit code $ret"
    bot_doc "$RESULT/log/lunch.log"
    err "Error: lunch $(Config.lunch) failed with exit code $ret"
fi

[[ -n $LUNCH ]] && exit

# Build start
# Tracking progress
bot "Start building . . ."
progress "$LOG_BUILD" &
progress_pid=$!

# Real build started
TIME_START=$(date +%s)
"${@:-${CMD[@]}}" -j"$JOBS" > fibuild
ret=$?
TIME_END=$(date +%s)

# Kill progress &
[[ -n $BOT ]] && kill $progress_pid

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
cp "$LOG_BUILD" "$LOG_OK"
bot_doc "$LOG_OK"

mv "$FILEPATH" "$RESULT"
dbg "ROM moved to $RESULT/$FILENAME"

if [[ -n $UPLOAD ]]
then
    case $UPLOAD in
        wet)
            $link=$(upload wet "$FILEPATH")
            uploader_msg "$FILENAME" "$link" "$FILESUM" "$FILESIZE"
            ;;
        *)
            err "Whops, upload other than wet not supported"
            ;;
    esac
fi

# Cleaning 
rm -f fibuild filunch

exit $ret