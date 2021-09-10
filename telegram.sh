#!/usr/bin/env bash

# Copyright (C) 2019-2021 alanndz <alanmahmud0@gmail.com>
# Copyright (C) 2020 @KryPtoN
# SPDX-License-Identifier: GPL-3.0-or-later

BOT_API_KEY="$BOT_TOKEN"
CHAT_ID="$BOT_ID"

telegram_curl() {
	local ACTION=${1}
	shift
	local HTTP_REQUEST=${1}
	shift
	if [ "$HTTP_REQUEST" != "POST_FILE" ]; then
		curl -s -X $HTTP_REQUEST "https://api.telegram.org/bot$BOT_API_KEY/$ACTION" "$@" | jq . #&> /dev/null
	else
		curl -s "https://api.telegram.org/bot$BOT_API_KEY/$ACTION" "$@" | jq . #&> /dev/null
	fi
}

telegram_main() {
	local ACTION=${1}
	local HTTP_REQUEST=${2}
	local CURL_ARGUMENTS=()
	while [ "${#}" -gt 0 ]; do
		case "${1}" in
			--animation | --audio | --document | --photo | --video )
				local CURL_ARGUMENTS+=(-F $(echo "${1}" | sed 's/--//')=@"${2}")
				shift
				;;
			--* )
				if [ "$HTTP_REQUEST" != "POST_FILE" ]; then
					local CURL_ARGUMENTS+=(-d $(echo "${1}" | sed 's/--//')="${2}")
				else
					local CURL_ARGUMENTS+=(-F $(echo "${1}" | sed 's/--//')="${2}")
				fi
				shift
				;;
		esac
		shift
	done
	telegram_curl "$ACTION" "$HTTP_REQUEST" "${CURL_ARGUMENTS[@]}"
}

telegram_curl_get() {
	local ACTION=${1}
	shift
	telegram_main "$ACTION" GET "$@"
}

telegram_curl_post() {
	local ACTION=${1}
	shift
	telegram_main "$ACTION" POST "$@"
}

telegram_curl_post_file() {
	local ACTION=${1}
	shift
	telegram_main "$ACTION" POST_FILE "$@"
}

tg_send_message() {
	telegram_main sendMessage POST "$@"
}

tg_edit_message_text() {
	telegram_main editMessageText POST "$@"
}

tg_send_document() {
	telegram_main sendDocument POST_FILE "$@"
}

check_upload() {
	if [[ $SF_UPLOAD -eq 1 ]]; then
		echo "Sourceforge"
	elif [[ $GD_UPLOAD -eq 1 ]]; then
		echo "Gdrive"
	elif [[ $SF_UPLOAD -eq 1 && $GD_UPLOAD -eq 1 ]]; then
		echo "Gdrive and Sourceforge"
	else
		echo "No upload"
	fi
}

bot_msg() {
	[[ $BUILD -eq 1 && $BOT -eq 1 ]] &&
		tg_send_message --chat_id "$CHAT_ID" --parse_mode "html" --reply_to_message_id "$CI_MESSAGE_ID" --text "$(
			for POST in "${@}"; do
				echo "${POST}"
			done
		)" &> /dev/null
}
bot_doc() {
	[[ $BUILD -eq 1 && $BOT -eq 1 && -f $@ ]] &&
		tg_send_document --chat_id "$CHAT_ID" --document "$@" --reply_to_message_id "$CI_MESSAGE_ID" > /dev/null
}

build_message() {
	if [ "$CI_MESSAGE_ID" = "" ]; then
CI_MESSAGE_ID=$(tg_send_message --chat_id "$CHAT_ID" --text "<b>========= Building ROM =========</b>

<b>ROM Name:</b> <code>${ROM}</code>
<b>Device:</b> <code>${DEVICE}</code>
<b>Branch:</b> <code>${REPO_BRANCH}</code>
<b>Lunch:</b> <code>$LUNCH</code>
<b>Type:</b> <code>$TYPE</code>
<b>Command:</b> <code>$(re cmd)</code>
<b>Upload:</b> <code>$(check_upload)</code>
<b>Started at</b> <code>$(uname -a)</code>

<b>Status:</b> $1" --parse_mode "html" | jq .result.message_id) #&> /dev/null
	else
tg_edit_message_text --chat_id "$CHAT_ID" --message_id "$CI_MESSAGE_ID" --text "<b>========= Building ROM =========</b>

<b>ROM Name:</b> <code>${ROM}</code>
<b>Device:</b> <code>${DEVICE}</code>
<b>Branch:</b> <code>${REPO_BRANCH}</code>
<b>Lunch:</b> <code>$LUNCH</code>
<b>Type:</b> <code>$TYPE</code>
<b>Command:</b> <code>$(re cmd)</code>
<b>Upload:</b> <code>$(check_upload)</code>
<b>Started at</b> <code>$(uname -a)</code>

<b>Status:</b> $1" --parse_mode "html" #&> /dev/null
	fi
}

# Progress
progress() {
	local BUILDLOG="$@"
	dbg "BOTLOG: Build tracker process is running..."
	sleep 10;

	while [ 1 ]; do
		if [[ $? -ne 0 ]]; then
			exit $?
		fi

        # Get latest percentage
		PERCENTAGE=$(cat $BUILDLOG | tail -n 1 | awk '{ print $2 }')
		NUMBER=$(echo ${PERCENTAGE} | sed 's/[^0-9]*//g')

        # Report percentage to the $CHAT_ID
		if [ "${NUMBER}" != "" ]; then
			if [ "${NUMBER}" -le  "99" ]; then
				if [ "${NUMBER}" != "${NUMBER_OLD}" ] && [ "$NUMBER" != "" ] && ! cat $BUILDLOG | tail  -n 1 | grep "glob" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "including" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "soong" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "finishing" > /dev/null; then
					dbg "BOTLOG: Percentage changed to ${NUMBER}%"
					build_message "Building ... ${NUMBER}%"
				fi
				NUMBER_OLD=${NUMBER}
			fi
			if [ "$NUMBER" -eq "99" ] && [ "$NUMBER" != "" ] && ! cat $BUILDLOG | tail  -n 1 | grep "glob" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "including" > /dev/null && ! cat $BUILDLOG | tail  -n 1 | grep "soong" > /dev/null && ! cat $BUILDLOG | tail -n 1 | grep "finishing" > /dev/null; then
				dbg "BOTLOG: Build tracker process ended"
				break
			fi
		fi
		sleep 10
	done
	return 0
}

build_fail() {
	bot_msg \
	"<b>========= Build ROM Failed =========</b>" \
	" " \
	"Total time elapsed:  $1 hours $2 minutes $3 seconds"
}
build_success() {
	bot_msg \
	"<b>========= Build ROM Success =========</b>" \
        " " \
	"<b>Filename:</b> <code>$4</code>" \
        "<b>Size:</b> <code>$6</code>" \
	"<b>md5sum:</b> <code>$5</code>" \
	" " \
	"Total time elapsed:  $1 hours $2 minutes $3 seconds"
}
uploader_msg() {
	bot_msg \
	"<b>============= Uploader =============</b>" \
        " " \
	"<b>Filename:</b> <code>$1</code>" \
        "<b>Size:</b> <code>$4</code>" \
	"<b>md5sum:</b> <code>$3</code>" \
	" " \
	"<b>Link:</b> $2"
}
