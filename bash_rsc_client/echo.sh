#!/bin/bash
set -euo pipefail
. rsc_lib.sh

connect_rsc 127.0.0.1 25566
while true; do
	receive_resp
	resp_type="${resp[0]}"
	resp_args="${resp[@]:1}"
	echo "Got response: ${resp[@]}"
	if [ "${resp_type}" = "ChatMessageResp" ]; then
		send_chat_message "Echo: ${resp_args[@]}"
	fi
done