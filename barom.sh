#!/usr/bin/env bash

# Copyright (C) 2019-2020 alanndz <alanmahmud0@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

NAME="Barom (Bakar Rom)"
VERSION="1.2"

dbg() {
	echo -e "\e[92m[*] $@\e[39m"
}

err() {
	echo -e "\e[91m[!] $@\e[39m"
	exit 1
}

grn() {
	echo -e "\e[92m$@\e[39m"
}

red() {
	echo -e "\e[91m$@\e[39m"
}

# Checking dependencies
for dep in env basename mkdir rm mkfifo jq expect ccache wget
do
	! command -v "$dep" &> /dev/null && err "Unable to locate dependency $dep. Exiting."
done

CONF=".`basename "$0"`-tools"
[[ ! -d $CONF ]] && 
	dbg "Creating $CONF folder's for configs" && 
	mkdir -p $CONF

re() {
	local arg="$(cat $CONF/$@ 2> /dev/null)"
	echo "${arg:-}"
}

wr() {
	echo "$2" > "$CONF/$1" 2> /dev/null
}

dnc() {
	local arg="$CONF/$@"

	if [[ -f $arg ]]; then
		local cred=$(cat $arg)
		local ret=$(openssl enc -base64 -d <<< "$cred")
	else
		local ret=""
	fi
	echo "$ret"
}

###### Default Environment ######
setup_env() {
	local a="$(re xcache)"
	local b="$(re lunch)"
	local c="$(re device)"
	local d="$(re type)"
	local e="$(re rom)"
	local f="$(re jobs)"
	local cmd="$(re cmd)"

	XCACHE="${a:-$(pwd)/.ccache}"
	LUNCH="${b:-lineage}"
	DEVICE="${c:-lavender}"
	TYPE="${d:-userdebug}"
	ROM="${e:-lineage}"
	JOBS="${f:-$(nproc --all)}"
	_CMD=("mka" "bacon") # Default COMMAND
	CMD_="${cmd:-${_CMD[@]}}"
	CMD=($CMD_)

	BOT_ID="$(dnc tg_bot_id)"
	BOT_TOKEN="$(dnc tg_bot_token)"

	REPO_LINK="$(re repo_link)"
	REPO_BRANCH="$(re repo_branch)"

	SF_PATH="$(dnc sf_path)"
	SF_USER="$(dnc sf_user)"
	SF_PW="$(dnc sf_pw)"
	O="out/target/product/$DEVICE"
}
############## END ##############
# Reseting all configure
reset() {
	for i in xcache lunch device type rom jobs cmd; do
		rm -rf $CONF/$i 2> /dev/null
	done
	dbg "Done reseting all configure"
	# Re setup env
	setup_env
}
# Setup Env
setup_env

usage() {
	echo -n "Author: alanndz
Usage: $(basename "$0") [OPTIONS] [COMMAND]

Options:
  -l LUNCH_COMMAND	Lunch command (default: `grn $LUNCH`)
  -L			Check lunch command, and exit
  -d DEVICE		Specify a device (default: `grn $DEVICE`)
  -t BUILD_TYPE		Build type (default: `grn $TYPE`)
  -n ROM_NAME		Rom Name (default: `grn $ROM`)
  -j JOBS		Jobs (default: `grn $JOBS`)
  -- COMMAND		Custom command (default: `grn ${CMD[@]}`)
  -b			Let start build
  -c			Cleaning out dir (make clean)
  -i			make installclean
  -R			Reset, it will delete `grn $CONF/` files
  -D			Print debug environment, be carefull, it will pritn your credential's too
  -h			Show usage
  -v			Show version
> Notes:
  `red [!]` Command default is `grn ${CMD[@]}`, if you want to custom command, using `grn -- COMMAND`. Example: `grn bakar -b -- mka nad`

Ccache:
  -C DIRECTORY		Set folder ccache (default: `grn $XCACHE`)
> Notes:
  `red [!]` Ccache `grn enable` by default
  `red [!]` Ccache will be set to `grn 50G` by default

Resync:
  -I MANIFEST BRANCH	Setup repo manifest
  -r			Re syncing all repos

Telegram BotLog:
  -G BOT_ID BOT_TOKEN	Set Bot id and Bot token
  -g			Clear all Bot id and Bot token

Sourceforge Auto Upload:
  -S PATH USER PW	Set Sourceforge path, user and password
  -s			Clear all Sourceforge credentials
  -f			Upload to Sourceforge

Google Drive auto upload:
  -o			Upload to gdrive, before upload you must have gdrive and login in 

`red [!]` All configure will be auto save in `grn $CONF`
"

  if [ -n "$1" ]; then
    exit "$1"
  fi
}

invalid() {
	echo "ERROR: Unrecognized argument: $1" >&2
	usage 1
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
		-l|--lunch)
			shift
			LUNCH="$1"
			wr lunch $LUNCH
			;;
		-d|--device)
			shift
			DEVICE="$1"
			wr device $DEVICE
			;;
		-C|--ccache)
			shift
			XCACHE="$1"
			wr xcache $XCACHE
			;;
		-t|--type)
			shift
			TYPE="$1"
			wr type $TYPE
			;;
		-n|--name)
			shift
			ROM="$1"
			wr rom $ROM
			;;
		-j|--jobs)
			shift
			JOBS="$1"
			wr jobs $JOBS
			;;
		-G|--setup-bot)
			shift
			SET_BOT=1
			BOT_ID="$1"
			BOT_TOKEN="$2"
			shift
			;;
		-S|--setup-sf)
			shift
			SET_SF=1
			SF_PATH="$1"
			SF_USER="$2"
			SF_PW="$3"
			shift; shift
			;;
		-I|--init|init)
			shift
			SET_REPO=1
			REPO_LINK="$1"
			REPO_BRANCH="$2"
			shift
			;;
		-b|--build)
			BUILD=1
			;;
		-L|--check-lunch)
			LUNCH_CHECK=1
			;;
		-r|--resync)
			RESYNC=1
			;;
		-c|--clean)
			CLEAN=1
			;;
		-i|--install-clean)
			CLEAN=2
			;;
		-g|--reset-bot)
			[[ ! -f $CONF/tg_bot_id ]] && dbg "Credentials Not Exist" && exit 0
			rm -rf $CONF/tg_bot_*
			dbg "Done delete Credentials"
			exit 0
			;;
		-s|--reset-sf)
			[[ ! -f $CONF/sf_path ]] && dbg "Credentials Not Exist" && exit 0
			rm -rf $CONF/sf_*
			dbg "Done delete Credentials"
			exit 0
			;;
		-f|--upload-sf)
			SF_UPLOAD=1
			;;
		-o|--upload-gd)
			GD_UPLOAD=1
			;;
		-R|--reset)
			reset
			;;
		-D|--debug)
			DEBUG=1
			;;
		-h|--help|help)
			usage 0
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

echo "$@"

# writing every $@
if [[ ! -z "$@" && $SET_BOT -ne 1 && $SET_SF -ne 1 && $SET_REPO -ne 1 ]]; then
	echo "$@" > $CONF/cmd
fi

# Setup repo manifest
if [[ $SET_REPO -eq 1 ]]; then
	[[ -z $REPO_LINK ]] && err "MANIFEST Not Set. Exiting" && exit 1
	[[ -z $REPO_BRANCH ]] && err "BRANCH Not Set. Exiting" && exit 1
	wr repo_link $REPO_LINK
	wr repo_branch $REPO_BRANCH
	dbg "Setup repo manifest done"
fi
# Setup Telegram BotLog
if [[ $SET_BOT -eq 1 ]]; then
	[[ -z $BOT_ID ]] && err "BOT_ID Not Set. Exiting" && exit 1
	[[ -z $BOT_TOKEN ]] && err "BOT_TOKEN Not Set. Exiting" && exit 1
	wr tg_bot_id "$(openssl enc -base64 <<< $BOT_ID)"
	wr tg_bot_token "$(openssl enc -base64 <<< $BOT_TOKEN)"
	dbg "Setup Telegram BotLog Done"
fi
# Setup Sorceforge Credentials
if [[ $SET_SF -eq 1 ]]; then
	[[ -z $SF_PATH ]] && err "SF_PATH Not Set. Exiting" && exit 1
	[[ -z $SF_USER ]] && err "SF_USER Not Set. Exiting" && exit 1
	[[ -z $SF_PW ]] && err "SF_PW Not Set. Exiting" && exit 1
	wr sf_path "$(openssl enc -base64 <<< $SF_PATH)"
	wr sf_user "$(openssl enc -base64 <<< $SF_USER)"
	wr sf_pw "$(openssl enc -base64 <<< $SF_PW)"
	dbg "Setup Sourceforge Credential's Done"
fi

debug_env() {
	echo -n "
CCACHE_DIR=$XCACHE
LUNCH=$LUNCH
DEVICE=$DEVICE
TYPE=$TYPE
ROM=$ROM
JOBS=$JOBS
CMD="${@:-${CMD[@]}}"

BUILD=$BUILD
LUNCH_CHECK=$LUNCH_CHECK
RESYNC=$RESYNC
CLEAN=$CLEAN

REPO_LINK=$REPO_LINK
REPO_MANIFEST=$REPO_BRANCH

BOT_ID=$BOT_ID
BOT_TOKEN=$BOT_TOKEN

SF_UPLOAD=$SF_UPLOAD
SF_PATH=$SF_PATH
SF_USER=$SF_USER
SF_PW=$SF_PW
OUT=$O
"
	exit 0
}
[[ $DEBUG -eq 1 ]] && debug_env "$@"

### All Configures Done ###

## Telegram function

if [[ ! -f "$CONF/telegram.sh" ]]; then
	dbg "Pulling telegram.sh"
	wget -O "$CONF/telegram.sh" https://github.com/alanndz/barom/raw/main/telegram.sh &> /dev/null
fi

# import telegram.sh
[[ ! -z $BOT_ID && ! -z $BOT_TOKEN ]] && BOT=1
source $CONF/telegram.sh
bot() {
	[[ $BUILD -eq 1 && $BOT -eq 1 ]] && build_message "$@" > /dev/null
}
dbot() {
	dbg "$@"
	bot "$@"
}
########

resync() {
	[[ -z $REPO_LINK ]] && err "MANIFEST Not set. Exiting"
	[[ -z $REPO_BRANCH ]] && err "BRANCH Not Set. Exiting"

	dbot "Initial repo ..."
	repo init -u "$REPO_LINK" -b "$REPO_BRANCH"
	[[ $? -ne 0 ]] &&
		bot "Repo init failed!" &&
		err "Repo init failed. Exiting"

	dbot "Sync All repos ..."
	repo sync --force-sync --no-tags --no-clone-bundle
	[[ $? -ne 0 ]] &&
		bot "Repo sync failed!" &&
		err "Repo sync failed. Exiting"
	dbot "Repo sync done!"
}
[[ $RESYNC -eq 1 ]] && resync

mkdir -p out
DATELOG="$(date "+%H%M-%d%m%Y")"
DATE=`date`
LOG_TMP="out/log_tmp.log"
LOG_OK="out/$ROM-$DEVICE-${DATELOG}.log"
LOG_TRIM="out/$ROM-$DEVICE-${DATELOG}_trimmed.log"

# let configure env from android source
source build/envsetup.sh
[[ $? -ne 0 ]] && err "source build/envsetup.sh Not found. Exiting"
dbot "Preparing before build ..."

setup_ccache() {
	export CCACHE_EXEC=$(which ccache)
	export USE_CCACHE=1
	export CCACHE_DIR="$XCACHE"
	ccache -M 50G
}
setup_ccache

[[ $ZIP -eq 1 ]] &&
	dbg "Cleaning file zip" &&
	rm -rf "$O/*zip"
if [[ $CLEAN -eq 1 ]]; then
	dbot "Cleaning out dir"
	make clean
	#rm -rf out # yes we do it
elif [[ $CLEAN -eq 2 ]]; then
	dbot "make installclean"
	make installclean
fi

[[ $LUNCH_CHECK -eq 1 ]] &&
	lunch "$LUNCH"_"$DEVICE"-"$TYPE" &&
	exit 0

[[ $BUILD -ne 1 ]] &&
	exit 0

dbot "lunch $LUNCH_$DEVICE-$TYPE"
# lunch command
mkfifo pipo 2> /dev/null
tee "out/lunch_error.log" < pipo &

lunch "$LUNCH"_"$DEVICE"-"$TYPE" > pipo

retVal=$?
[[ $retVal -ne 0 ]] &&
	dbot "lunch command failed with status code $retVal" &&
	bot_doc "out/lunch_error.log" &&
	err "lunch command failed with status code $retVal . Exiting"

dbot "lunch command done"

# taking log
mkfifo pipe 2> /dev/null
tee "$LOG_TMP" < pipe &

#
dbot "Starting build"

# Tracking progress
[[ $BOT -eq 1 ]] && progress "$LOG_TMP" &
progress_pid=$!

# Start Building
TIME_START=`date +%s`
"${@:-${CMD[@]}}" -j"$JOBS" > pipe

# recording exit status
retVal=$?

# killing progress background
kill $progress_pid 2> /dev/null
wait $progress_pid 2> /dev/null

# Time elapsed
t_() {
	echo "$(date -u --date @$((`date +%s` - $TIME_START)) +%H:%M:%S)"
}

# Split time elapsed
H=$(t_ | cut -f1 -d":")
M=$(t_ | cut -f2 -d":")
S=$(t_ | cut -f3 -d":")

# build failed
if [[ $retVal -ne 0 ]]; then
	dbot "Build Failed ..."
	bot_msg "Build Failed. Total time elapsed: $H hours $M minutes $S seconds"
	cp "$LOG_TMP" "$LOG_OK"
	bot_doc "$LOG_OK"
	sed -n '/FAILED:/,//p' "$LOG_OK" &> "$LOG_TRIM"
	bot_doc "$LOG_TRIM"
	exit $retVal
fi

# build success
dbot "Build success!"
bot_msg "Build success. Total time elapsed:  $H hours $M minutes $S seconds"
cp "$LOG_TMP" "$LOG_OK"
bot_doc "$LOG_OK"

FILEPATH=$(find "$O" -type f -name "$ROM*$DEVICE*zip" -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
FILENAME=$(echo "$FILEPATH" | cut -f5 -d"/")

[[ -f $FILEPATH ]] &&
	dbot "Build success. File stored in: $FILEPATH"

if [[ $SF_UPLOAD -eq 1 && -f $FILEPATH && ! -z $SF_PATH && ! -z $SF_USER && ! -z $SF_PW ]]; then
	dbot "Uploading to sourceforge"
{
	/usr/bin/expect << EOF
	set timeout 600
	spawn scp "$FILEPATH" $SF_USER@frs.sourceforge.net:/home/frs/project/$SF_PATH/
	expect {
		*es/*o {
			send "yes\r"; exp_continue
		}
		Password: {
			send "$SF_PW\r"; exp_continue
		}
		timeout {
			puts "timeout"; exit 1
		}
		eof {
			puts "eof"; exit 0
		}
	}
EOF
}
	ret=$?
	[[ $ret -ne 0 ]] && dbot "Upload to sourceforge failed!" && exit $ret
	sleep 2
	dbot "Uploaded on : https://sourceforge.net/projects/$SF_PATH/files/$FILENAME/download"
fi

if [[ $GD_UPLOAD -eq 1 && -f $FILEPATH ]]; then
	! command -v "gdrive" &> /dev/null && dbot "Failed upload to gdrive, missing packages gdrive" && err "Unable to locate dependency gdrive. Exiting."
	GD=$(gdrive upload --share $FILEPATH)
	link=$(echo "$GD" | grep "https://" | cut -d" " -f7)
	dbot "Uploaded on : $link"
fi

exit 0
