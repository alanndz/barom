#!/usr/bin/env bash

# Copyright (C) 2019-2020 alanndz <alanmahmud0@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

NAME="Barom (Bakar Rom)"
VERSION="1.0"

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

`red [!]` For command `grn -I, -G, -S` must execute one by one. Dont execute with other command or will crash/error
`red [!]` All configure will be auto save in `grn $CONF`
"
}

while getopts ":l:d:C:t:n:j:G:S:I:brcigsfRDhv" opt; do
	case $opt in
		l)
			LUNCH="$OPTARG"
			wr lunch $LUNCH
			;;
		d)
			DEVICE="$OPTARG"
			wr device $DEVICE
			;;
		C)
			XCACHE="$OPTARG"
			wr xcache $XCACHE
			;;
		t)
			TYPE="$OPTARG"
			wr type $TYPE
			;;
		n)
			ROM="$OPTARG"
			wr rom $ROM
			;;
		j)
			JOBS="$OPTARG"
			wr jobs $JOBS
			;;
		G)
			SET_BOT=1
			BOT_ID="$2"
			BOT_TOKEN="$3"
			;;
		S)
			SET_SF=1
			SF_PATH="$2"
			SF_USER="$3"
			SF_PW="$4"
			;;
		I)
			SET_REPO=1
			REPO_LINK="$2"
			REPO_BRANCH="$3"
			;;
		b)
			BUILD=1
			;;
		r)
			RESYNC=1
			;;
		c)
			CLEAN=1
			;;
		i)
			CLEAN=2
			;;
		g)
			[[ ! -f $CONF/tg_bot_id ]] && dbg "Credentials Not Exist" && exit 0
			rm -rf $CONF/tg_bot_*
			dbg "Done delete Credentials"
			exit 0
			;;
		s)
			[[ ! -f $CONF/sf_path ]] && dbg "Credentials Not Exist" && exit 0
			rm -rf $CONF/sf_*
			dbg "Done delete Credentials"
			exit 0
			;;
		f)
			SF_UPLOAD=1
			;;
		R)
			reset
			;;
		D)
			DEBUG=1
			;;
		h)
			usage
			exit 0
			;;
		v)
			echo "$NAME $VERSION"
			exit 0
			;;
		*)
			usage
			exit 0
			;;
	esac
done
shift $((OPTIND - 1))
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
	exit 0
fi
# Setup Telegram BotLog
if [[ $SET_BOT -eq 1 ]]; then
	[[ -z $BOT_ID ]] && err "BOT_ID Not Set. Exiting" && exit 1
	[[ -z $BOT_TOKEN ]] && err "BOT_TOKEN Not Set. Exiting" && exit 1
	wr tg_bot_id "$(openssl enc -base64 <<< $BOT_ID)"
	wr tg_bot_token "$(openssl enc -base64 <<< $BOT_TOKEN)"
	dbg "Setup Telegram BotLog Done"
	exit 0
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
	exit 0
fi

debug_env() {
	echo -n "
XCACHE=$XCACHE
LUNCH=$LUNCH
DEVICE=$DEVICE
TYPE=$TYPE
ROM=$ROM
JOBS=$JOBS
CMD="${@:-${CMD[@]}}"

BUILD=$BUILD
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
source $CONF/telegram.sh
[[ ! -z $BOT_ID && ! -z $BOT_TOKEN ]] && BOT=1
bot() {
	[[ $BUILD -eq 1 && $BOT -eq 1 ]] && build_message "$@" > /dev/null
}
bot_msg() {
	[[ $BUILD -eq 1 && $BOT -eq 1 ]] &&
		tg_send_message --chat_id "$CHAT_ID" --text "$@" --reply_to_message_id "$CI_MESSAGE_ID" > /dev/null
}
bot_doc() {
	[[ $BUILD -eq 1 && $BOT -eq 1 && -f $@ ]] &&
		tg_send_document --chat_id "$CHAT_ID" --document "$@" --reply_to_message_id "$CI_MESSAGE_ID" > /dev/null
}
########

resync() {
	[[ -z $REPO_LINK ]] && err "MANIFEST Not set. Exiting"
	[[ -z $REPO_BRANCH ]] && err "BRANCH Not Set. Exiting"

	dbg "Initial repo ..."
	[[ $BUILD -eq 1 ]] && bot "Initial repo ..."
	repo init -u "$REPO_LINK" -b "$REPO_BRANCH"

	dbg "Sync All repos ..."
	[[ $BUILD -eq 1 ]] && bot "Syncing all repos ..."
	repo sync -c --force-sync --no-tags --no-clone-bundle --optimized-fetch --prune
	[[ $? -ne 0 ]] &&
		[[ $BUILD -eq 1 ]] && bot "Repo Sync failes!" &&
		err "Repo sync failed. Exiting"
	[[ $BUILD -eq 1 ]] && bot "Repo sync done!"
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
bot "Preparing before build ..."

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
	bot "Cleaning out dir"
	dbg "Cleaning out dir"
	make clean
	#rm -rf out # yes we do it
elif [[ $CLEAN -eq 2 ]]; then
	bot "make installclean"
	dbg "make installclean"
	make installclean
fi

bot "lunch $LUNCH_$DEVICE-$TYPE"

# lunch command
mkfifo pipo 2> /dev/null
tee "out/lunch_error.log" < pipo &

lunch "$LUNCH"_"$DEVICE"-"$TYPE" > pipo
retVal=$?
[[ $retVal -ne 0 ]] &&
	bot "lunch command failed with status code $retVal" &&
	bot_doc "out/lunch_error.log" &&
	err "lunch command failed with status code $retVal . Exiting"

if [[ $BUILD -ne 1 ]]; then
	bot "lunch command done"
	dbg "lunch command done"
	exit 0
fi

# taking log
mkfifo pipe 2> /dev/null
tee "$LOG_TMP" < pipe &

#
bot "Starting build"
dbg "Starting build"

# Tracking progrwss
[[ $BOT -eq 1 ]] && progress "$LOG_TMP" &

# Start Building
TIME_START=`date +%s`
"${@:-${CMD[@]}}" -j"$JOBS" > pipe

# recording exit status
retVal=$?

#
time_elapsed() {
	echo "$(date -u --date @$((`date +%s` - $TIME_START)) +%H:%M:%S)"
}

# build failed
if [[ $retVal -ne 0 ]]; then
	bot "Build Failed ..."
	bot_msg "Build Failed. Elapsed time: $(time_elapsed)"
	cp "$LOG_TMP" "$LOG_OK"
	bot_doc "$LOG_OK"
	sed -n '/FAILED:/,//p' "$LOG_OK" &> "$LOG_TRIM"
	bot_doc "$LOG_TRIM"
	exit $retVal
fi

# build success
bot "Build success!"
bot_msg "Build success. Elapsed time: $(time_elapsed)"
cp "$LOG_TMP" "$LOG_OK"
bot_doc "$LOG_OK"

FILEPATH=$(find "$O" -type f -name "$ROM*$DEVICE*zip" -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

[[ -f $FILEPATH ]] &&
	bot "Build success. File stored in: $FILEPATH" &&
	dbg "Build success. File stored in: $FILEPATH"

if [[ $SF_UPLOAD -eq 1 && -f $FILEPATH && ! -z $SF_PATH && ! -z $SF_USER && ! -z $SF_PW ]]; then
bot "Uploading to sourceforge"
{
	/usr/bin/expect << EOF
	set timeout 300
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
	ret=$?
	[[ $ret -ne 0 ]] && bot "Upload to sourceforge failed!" && exit $ret
	bot "Upload success!"
	dbg "Upload success!"
	sleep 5
	#bot "Build success. File stored in: $FILEPATH"
else
	[[ ! -f $FILEPATH ]] && red "[!] File not found"
	[[ -z $SF_PATH ]] && red "[!] SF_PATH Not Set"
	[[ -z $SF_USER ]] && red "[!] SF_USER Not Set"
	[[ -z $SF_PW ]] && red "[!] SF_PW Not Set"
	exit 1
fi

exit 0
