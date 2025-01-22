#!/bin/bash
set -euo pipefail
. rsc_lib.sh


function escape_ansi_as_minecraft() {
	local escaped="${1}"
	shopt -s extglob
	escaped="${escaped//" "/"  "}"
	escaped="${escaped//"&"/"&&"}"
	escaped="${escaped//$'\E[0m'/"&f"}"
	escaped="${escaped//$'\E['*'30m'/"&0"}"
	escaped="${escaped//$'\E['*'31m'/"&4"}"
	escaped="${escaped//$'\E['*'32m'/"&2"}"
	escaped="${escaped//$'\E['*'33m'/"&6"}"
	escaped="${escaped//$'\E['*'34m'/"&1"}"
	escaped="${escaped//$'\E['*'35m'/"&d"}"
	escaped="${escaped//$'\E['*'36m'/"&b"}"
	escaped="${escaped//$'\E['*'37m'/"&f"}"
	#escaped="${escaped//$'\E['?'m'/""}"
	#escaped="${escaped//$'\E['??'m'/""}"
	#escaped="${escaped//$'\E['???'m'/""}"
	#escaped="${escaped//$'\E['????'m'/""}"
	#escaped="${escaped//$'\E['?????'m'/""}"
	#escaped="${escaped//$'\E['??????'m'/""}"
	escaped="${escaped//$'\E[K'/""}"
	echo "${escaped}"
}

connect_rsc 127.0.0.1 25566
while true; do
	receive_resp
	resp_type="${resp[0]}"
	resp_args="${resp[@]:1}"
	if [ "${resp_type}" = "ChatMessageResp" ]; then
		send_chat_message "\$&o${resp_args[@]}"
		(TERM=ansi COLUMNS=40 eval "${resp_args[@]}" 2>&1 && echo -e "\e[32mReturned: $?" || echo -e "\e[31mReturned: $?") | while read -r line; do
			send_chat_message ">$(escape_ansi_as_minecraft "${line}")"
		done
	fi
done
