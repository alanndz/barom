#!/usr/bin/env bash

# Copyright (C) 2019-2021 alanndz <alanmahmud0@gmail.com>
# Copyright (C) 2020 @KryPtoN
# SPDX-License-Identifier: GPL-3.0-or-later

BOT_API_KEY="$(dnc `Config.tgtoken`)"
CHAT_ID="$(dnc `Config.tgid`)"
ROMNAME="$(Config.name)"

[[ -n $BOT_API_KEY && -n $CHAT_ID ]] && BOT=1

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

bot_msg() {
	if [[ $BUILD -eq 1 && $BOT -eq 1 ]]
	then
		tg_send_message --chat_id "$CHAT_ID" --parse_mode "html" --reply_to_message_id "$CI_MESSAGE_ID" --text "$(
			for POST in "${@}"; do
				echo "${POST}"
			done
		)" 2&> /dev/null
	fi
}
bot_doc() {
	if [[ $BUILD -eq 1 && $BOT -eq 1 && -f $@ ]]
	then
		tg_send_document --chat_id "$CHAT_ID" --document "$@" --reply_to_message_id "$CI_MESSAGE_ID" 2&> /dev/null
	fi
}

send_file() {
	tg_send_document --chat_id "$CHAT_ID" --document "$@" 2&> /dev/null
}

bot() {
	if [[ $BUILD -eq 1 && $BOT -eq 1 ]]
	then
		build_message "$@" 2&> /dev/null
	fi
}

build_message() {
	if [ "$CI_MESSAGE_ID" = "" ]; then
CI_MESSAGE_ID=$(tg_send_message --chat_id "$CHAT_ID" --text "<b>========= Building ROM =========</b>

<b>ROM Name:</b> <code>${ROMNAME:-Unknown}</code>
<b>Device:</b> <code>$(Config.device)</code>
<b>Branch:</b> <code>${REPO_BRANCH}</code>
<b>Lunch:</b> <code>$(Config.lunch)</code>
<b>Command:</b> <code>$(Config.cmd)</code>
<b>Upload:</b> ${UPLOAD:-None}<code></code>
<b>Started at</b> <code>$(uname -a)</code>

<b>Status:</b> $1" --parse_mode "html" | jq .result.message_id) #&> /dev/null
	else
tg_edit_message_text --chat_id "$CHAT_ID" --message_id "$CI_MESSAGE_ID" --text "<b>========= Building ROM =========</b>

<b>ROM Name:</b> <code>${ROMNAME:-Unknown}</code>
<b>Device:</b> <code>$(Config.device)</code>
<b>Branch:</b> <code>${REPO_BRANCH}</code>
<b>Lunch:</b> <code>$(Config.lunch)</code>
<b>Command:</b> <code>$(Config.cmd)</code>
<b>Upload:</b> ${UPLOAD:-None}<code></code>
<b>Started at</b> <code>$(uname -a)</code>

<b>Status:</b> $1" --parse_mode "html" #&> /dev/null
	fi
}

# Progress
progress() {
	[[ -z $BOT ]] && return

	local BUILDLOG="$@"
	dbg "BOTLOG: Build tracker process is running..."
	sleep 10

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
