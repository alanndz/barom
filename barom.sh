#!/usr/bin/env bash

# Copyright (C) 2019-2023 alanndz <alanmahmud0@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

NAME="Barom"
VERSION="2.3"
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

CONF="$cwd/.baromconfig"
BIN="$HOME/.barom"
RESULT="$cwd/result"
if [[ ! -d "$BIN" ]]; then
    dbg "Creating $BIN folder's"
    mkdir -p $BIN
fi

##### Setup Config #####
Config.name() { git config -f "$CONF" barom.name "$@"; }
Config.lunch() { git config -f "$CONF" barom.lunch "$@"; }
Config.device() { git config -f "$CONF" barom.device "$@"; }
Config.cmd() { git config -f "$CONF" barom.cmd "$@"; }
Config.jobs() { git config -f "$CONF" barom.jobs "$@"; }
Config.tgid() { git config -f "$BIN/baromconfig" telegram.channelid "$@"; }
Config.tgtoken() { git config -f "$BIN/baromconfig" telegram.token "$@"; }
Config.manifest() { git config -f "$CONF" repo.manifest "$@"; }
Config.branch() { git config -f "$CONF" repo.branch "$@"; }
Config.iflags() { git config -f "$CONF" repo.initflags "$@"; }
Config.sfuser() { git config -f "$CONF" sourceforge.user "$@"; }
Config.sfpass() { git config -f "$CONF" sourceforge.pass "$@"; }
Config.sfpath() { git config -f "$CONF" sourceforge.path "$@"; }
Config.ccdir() { git config -f "$CONF" ccache.dir "$@"; }
Config.ccsize() { git config -f "$CONF" ccache.size "$@"; }

##### End Setup Config #####
export PATH="$BIN:/usr/lib/ccache:$PATH"

dnc() { echo "$(openssl enc -base64 -d <<< $@)"; }
enc() { echo "$(openssl enc -base64 <<< $@)"; }

# Pull telegram.sh
[[ ! -f "$BIN/barom-telegram" ]] && curl -L -o "$BIN/barom-telegram" -s https://github.com/alanndz/barom/raw/main/telegram.sh
[[ -f "$BIN/barom-telegram" ]] && source "$BIN/barom-telegram" || err "Error: file "$BIN/barom-telegram" not found, please check internet connection for download first"
[[ ! -f "$BIN/wtclient" ]] && curl -sL https://github.com/aLnProject/barom-binary/raw/main/wtclient.sh | bash -s "$BIN"

TMP_SYNC="sync-rom.log"

repoInit() {
    local flags=$(Config.iflags)
    repo init $flags --no-repo-verify -u $1 -b $2
}

repoSync() {
    local custom="$@"
    local jobs=$(Config.jobs)
    repo sync --no-tags --no-clone-bundle --current-branch -j${jobs:-$(nproc --all)} $custom 2>&1 | tee $TMP_SYNC
    local ret=$?
    return $ret
}

fixErrorSync() {
    local a=$(grep 'Cannot remove project' "$TMP_SYNC" -m 1)
    local b=$(grep "^fatal: remove-project element specifies non-existent project" "$TMP_SYNC" -m 1)
    local c=$(grep 'repo sync has finished' "$TMP_SYNC" -m 1)
    local d=$(grep 'Failing repos:' "$TMP_SYNC" -n -m 1)
    local e=$(grep 'fatal: Unable' "$TMP_SYNC")
    local f=$(grep 'error.GitError' "$TMP_SYNC")
    local g=$(grep 'error: Cannot checkout' "$TMP_SYNC")

    if [[ -n $a ]]
    then
        a=$(echo $a | cut -d ':' -f2 | tr -d ' ')
        rm -rf $a
    fi

    if [[ -n $b ]]
    then 
        exit 1
    fi

    if [[ -n $d ]]
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

    if [[ -n $e ]]
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

    if [[ -n $f ]]
    then
        rm -rf $(grep 'error.GitError' "$TMP_SYNC" | cut -d ' ' -f2)
    fi

    if [[ -n $g ]]
    then
        coerr=$(grep 'error: Cannot checkout' "$TMP_SYNC" | cut -d ' ' -f 4| tr -d ':')
        for i in $coerr
        do
            rm -rf .repo/project-objects/$i.git
        done
    fi
}

setupGdrive() {
    if command -v gdrive &> /dev/null; then
        if [[ -d $HOME/.config/gdrive3 ]]; then
            read -p "Gdrive already installed and gdrive account already configured, Continue [Y/n] " rrr
            case ${rrr,,} in
                n|no)
                    exit
                    ;;
            esac
        fi
    fi

    rm -f /tmp/gdrive_linux-x64.tar.gz
    curl -L -o /tmp/gdrive_linux-x64.tar.gz https://github.com/glotlabs/gdrive/releases/download/3.9.0/gdrive_linux-x64.tar.gz
    [[ -f /tmp/gdrive_linux-x64.tar.gz ]] || err "Gdrive not downloaded. Try again"
    tar -xf /tmp/gdrive_linux-x64.tar.gz -C /tmp/

    if [[ "$1" == "system" ]]; then
        echo $1
        sudo install /tmp/gdrive /usr/local/bin/gdrive
    else
        mv /tmp/gdrive $BIN
    fi

    prin
    read -p "Do you want to add account gdrive? [Y/n] " res
    prin
    case ${res,,} in
        y|ye|yes)
            gdrive account add ;;
        *)
            prin
            ;;
    esac
}

checkUpload() {
    local LIST="wet gof fio trs sf gd"
    local DELIMITER=" "
    local VALUE=$1
    if [[ "$VALUE" == "gd" ]]; then
        if ! command -v gdrive &> /dev/null; then
            err "Gdrive not installed, --setup-gdrive first"
        fi
    fi

    echo $LIST | tr "$DELIMITER" '\n' | grep -F -q -x "$VALUE"
}

uploadSf() {
    local FILEPATH="$1"
    local FILENAME="$(basename $FILEPATH)"
    local SF_USER="$(dnc `Config.sfuser`)"
    local SF_PW="$(dnc `Config.sfpass`)"
    local SF_PATH="$(Config.sfpath)"

    [[ -z $SF_USER || -z $SF_PW || -z $SF_PATH ]] && dbg "Sourceforge username/password/path empty, set first!" && return 1
    command -v expect &> /dev/null || return 1

{
    /usr/bin/expect << EOF
    set timeout 600
    log_user 0
    spawn scp "$FILEPATH" $SF_USER@frs.sourceforge.net:/home/frs/project/$SF_PATH/
    expect {
        *es/*o {
            send "yes\r"; exp_continue
        }
        Password: {
            send "$SF_PW\r"; exp_continue
        }
        timeout {
            exit 1
        }
        eof {
            exit 0
        }
    }
EOF
}
    local ret=$?
    [[ $ret -ne 0 ]] && return $ret
    echo "https://sourceforge.net/projects/$SF_PATH/files/$FILENAME/download"
}

uploadMain() {
    case "$1" in
        gof)
            local FILE="@$2"
            local SERVER=$(curl -s https://apiv2.gofile.io/getServer | jq  -r '.data|.server')
            local UP=$(curl -F file=${FILE} https://${SERVER}.gofile.io/uploadFile)
            local LINK=$(echo $UP | jq -r '.data|.downloadPage')
            ;;
        trs)
            local FILE="$2"
            local LINK=$(curl --upload-file "$FILE" https://transfer.sh/$(basename "$FILE") | tee /dev/null)
            ;;
        fio)
            local FILE="@$2"
            # Expired 3 weeks, set m/w/y
            local LINK=$(curl -F file=${FILE} https://file.io/\?expires=3w | jq -r '.link')
            ;;
        wet)
            local FILE="$2"
            local LINK=$(wtclient upload "$FILE" | grep "https" | cut -d " " -f 5)
            ;;
        sf)
            local FILE="$2"
            local LINK=$(uploadSf "$FILE")
            ;;
        gd)
            local FILE="$2"
            local LINK=$(gdrive files upload "$FILE" | grep ViewUrl | cut -d " " -f 2)
            ;;
        pd)
            local FILE="$2"
            local LINK=$(curl -T "$FILE" https://pixeldrain.com/api/file/ | cut -d '"' -f 4)
            ;;

    esac
    [[ -z "$LINK" ]] && return 1

    echo "$LINK"
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
    prin "  --timer <..s/m/h>               Define timer to limit time when building (ex: 1m)"
    prin "  -L                              Show lunch command only, dont start  the build"
    prin "  -h, --help                      Show usage"
    prin "  -v, --version                   Show version"
    prin
    prin "Repo:"
    prin "  -i, --init <manifest> <branch>  Define manifest and branch to repo init"
    prin "  --reinit                        Repo init again with already define by -i"
    prin "  -r, --resync                    Repo sync all repository after define using -i"
    prin "  -r, --resync <path>             Repo sync with custom path not all repository"
    prin "  --init-flags, --iflags <flags>  Init flags"
    prin "  --force-sync                    Force sync repos, use it with -r, --resync"
    prin
    prin "-c, --clean options description:"
    prin "  full            make clobber and make clean"
    prin "  dirty           make installclean"
    prin "  clean           make clean"
    prin "  device          make deviceclean"
    prin
    prin "Telegram:"
    prin "  -t, --telegram <ch id> <tg token>   Define channel id and telegram token, it will tracking proggress and send status to telegram channel"
    prin "  --send-file-tg, --sft <path file>   Send file to telegram"
    prin
    prin "Upload:"
    prin "  -u, --upload <host>                         Upload rom after finished build"
    prin "  -s, --sourceforge <user> <password> <path>  Set credential for upload to sourceforge"
    prin "  --upload-rom-latest, --url                  Upload latest rom from $RESULT folder"
    prin "  --upload-file <host> <file>                 Upload file only and exit"
    prin
    prin "Google Drive:"
    prin "  --setup-gdrive                   Install gdrive to local, only use for barom"
    prin "  --setup-gdrive system            Install gdrive to system"
    prin
    prin "CCache:"
    prin "  --ccache-dir <dir path>          Set custom directory for ccache"
    prin "  --ccache-size <..K/M/G>          Set custom size, (default: 50G)"
    prin
    prin "Notes: [!] Host upload supported: wet: wetransfer"
    prin "                                  gof: gofile.io"
    prin "                                  fio: file.io"
    prin "                                  trs: transfer.sh"
    prin "                                  gd: gdrive"
    prin "                                  pd: pixeldrain"
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
                REPOINIT=1
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
        --init-flags|--ifags)
            if [ -n "$2" ]; then
                Config.iflags "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        --force-sync)
            FSYNC=1
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
        --timer)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                TIMER=$2
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
                for i in $UPLOAD
                do
                    checkUpload "$i" || err "Error: Upload to $i not supported"
                done
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        -t|--telegram)
            if [[ -n "$2" && -n "$3" && ${2:1:1} -eq ${2:1:1} ]]; then
                red "[Warning] Using password in command line interface can be insecure."
                Config.tgid "$(enc $2)"
                Config.tgtoken "$(enc $3)"
                shift 2
            else
                read -s -p "Enter telegram id: " tgid
                prin ""
                read -s -p "Enter telegram token: " tgtoken
                prin ""
                [[ -z $tgid || -z $tgtoken ]] && err "Telegram id or telegram token is empty. Aborted!"
                Config.tgid "$(enc $tgid)"
                Config.tgtoken "$(enc $tgtoken)"
            fi
            ;;
        --send-file-tg|--sft)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                [[ -z $BOT ]] && err "Error: Telegram token or channel id not defined!"
                send_file "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            exit
            ;;
        --upload-rom-latest|--url)
            FILEPATH=$(ls -Art $RESULT/*.zip | tail -1)
            link=$(uploadMain wet "$FILEPATH") || link=$(uploadMain gof "$FILEPATH")
            dbg "Rom uploaded to $link"
            exit
            ;;
        --upload-rom-file)
            prin "TO DO"
            exit
            ;;
        --upload-file)
            if [ -n "$2" ] && [ -n "$3" ] && [ ${2:0:1} != "-" ]; then
                checkUpload "$2" || err "Error: Upload to $2 not supported"
                link=$(uploadMain "$2" "$3") || err "Failed upload"
                dbg "Uploaded to $link"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 2 argument"
            fi
            exit
            ;;
        -s|--sourceforge)
            if [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ] && [ ${2:0:1} != "-" ]; then
                Config.sfuser "$(enc $2)"
                Config.sfpass "$(enc $3)"
                Config.sfpath "$4"
                shift 3
            else
                err "Error: Argument for $1 is missing or more/less than 3 argument"
            fi
            ;;
        --ccache-dir)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                dbg "CCache directory set to $2"
                Config.ccdir "$2"
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        --ccache-size)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                dbg "CCache size set to $2"
                Config.ccsize $2
                shift
            else
                err "Error: Argument for $1 is missing or more/less than 1 argument"
            fi
            ;;
        --setup-gdrive)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                [[ "$2" == "system" ]] || err "Must use system or empty"
                setupGdrive system
                exit
            fi
            setupGdrive
            exit
            ;;
        -v|--version)
            prin "$NAME $VERSION by alanndz"
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

# REPOINIT
[[ -n $REPOINIT ]] && repoInit $(Config.manifest) $(Config.branch)

# RESYNC
if [[ $RESYNC -eq 1 ]]
then
    bot "Sync all repository ..."
    [[ -n $FSYNC ]] && RESYNC_CUSTOM="--force-sync ${RESYNC_CUSTOM}"
    if ! repoSync "$RESYNC_CUSTOM"
    then
        bot "Sync failed, trying to fixing ..."
        fixErrorSync
    fi
fi

# Check file build/envsetup.sh, if false exit
[[ -f build/envsetup.sh ]] || exit
[[ -z $BUILD ]] && exit

# Import envsetup.sh
source build/envsetup.sh

# Preparing Env before build
ROM=$(Config.name)
DEVICE=$(Config.device)
[[ -z $ROM ]] && ROM="Build-rom"
[[ ! -d $RESULT ]] && dbg "Creating $RESULT folder's" && mkdir -p $RESULT/log
CMD=$(Config.cmd)
#CMD="${CMD//./ }"
CMD=($CMD)
JOBS=$(Config.jobs)
JOBS=${JOBS:-$(nproc --all)}
DATELOG="$(date "+%H%M-%d%m%Y")"
LOG_LUNCH="$RESULT/log/lunch.log"
LOG_BUILD="$RESULT/log/build.log"
LOG_OK="$RESULT/log/$ROM-$(Config.device)-${DATELOG}.log"
LOG_TRIM="$RESULT/log/$ROM-$(Config.device)-${DATELOG}_error.log"
O="out/target/product/$(Config.device)"
XCACHE=$(Config.ccdir)
XSIZE=$(Config.ccsize)

# Preparing log record
mkfifo filunch fibuild &> /dev/null
tee "$LOG_LUNCH" < filunch &
tee "$LOG_BUILD" < fibuild &

# CCACHE
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR="${XCACHE:-$HOME/.ccache}"
ccache -M ${XSIZE:-50G}

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
"${@:-${CMD[@]}}" -j"$JOBS" > fibuild & build_pid=$!
[[ -n $TIMER ]] && sleep $TIMER && kill $build_pid & sleep_pid=$!
wait $build_pid
ret=$?
TIME_END=$(date +%s)

# Kill sleep
[[ -n $TIMER ]] && kill $sleep_pid &> /dev/null

# Kill progress &
[[ -n $BOT ]] && kill $progress_pid &> /dev/null

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

# Cleaning 
rm -f fibuild filunch

# Build success
bot "Build success"
ROM=$(Config.name)
FILEPATH=$(ls -Art ${O}/${ROM}*${DEVICE}*.zip | tail -1)
[[ -z $ROM ]] && FILEPATH=$(ls -Art ${O}/*.zip | tail -1)

[[ -f $FILEPATH ]] && err "Failed get file rom! Exited!"

FILENAME=$(basename "$FILEPATH")
FILESUM=$(md5sum "$FILEPATH" | cut -f1 -d" ")
FILESIZE=$(ls -lah "$FILEPATH" | cut -d ' ' -f 5)

build_success "$H" "$M" "$S" "$FILENAME" "$FILESUM" "$FILESIZE"
cp "$LOG_BUILD" "$LOG_OK"
bot_doc "$LOG_OK"

if [[ -n $UPLOAD ]]
then
    for i in $UPLOAD
    do
        link=$(uploadMain "$i" "$FILEPATH") || link=$(uploadMain gof "$FILEPATH")
        uploader_msg "$FILENAME" "$link" "$FILESUM" "$FILESIZE"
    done
fi

# Move ROM to $RESULT
mv "$FILEPATH" "$RESULT"
dbg "ROM moved to $RESULT/$FILENAME"

exit $ret
