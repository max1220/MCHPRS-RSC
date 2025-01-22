#!/bin/bash
set -euo pipefail

# connect to RSC server
function connect_rsc() {
	exec 99<>"/dev/tcp/${1}/${2}"
}

# utilities for reading/writing binary-encoded numbers to/from stdin/stdout
function print_u8() { printf "\x$(printf %x $1 )"; }
function write_u8() { print_u8 "${1}" >&99; }
function write_u32() {
	a="$(( $1 % 256 ))"
	b="$(( ( $1 / 256 ) % 256 ))"
	c="$(( ( $1 / 65536 ) % 256 ))"
	d="$(( ( $1 / 16777216 ) % 256 ))"
	write_u8 "${a}"
	write_u8 "${b}"
	write_u8 "${c}"
	write_u8 "${d}"
}
function write_i32() {
	if [ "${1}" -lt 0 ]; then
		write_u32 "$(( (0xffffffff + $1) + 1 ))"
	else
		write_u32 "${i}"
	fi
}
function read_u8() { od -N 1 -A n -t u1 <&99; }
function read_u32() { od -N 4 -A n -t u4 <&99; }
function read_i32() { od -N 4 -A n -t d4 <&99; }
function read_strz() {
	while true; do
		local ch="$(read_u8)"
		[ "${ch}" -eq 0 ] && break;
		print_u8 "${ch}"
		#printf "%s" "${ch}"
	done
}

# send commands to RSC connection
function send_get_block() {
	write_u8 0
	write_u32 "${1}"
	write_u32 "${2}"
	write_u32 "${3}"
}
function send_set_block() {
	write_u8 1
	write_u32 "${1}"
	write_u32 "${2}"
	write_u32 "${3}"
	write_u32 "${4}"
}
function send_observe_block() {
	write_u8 2
	write_u32 "${1}"
	write_u32 "${2}"
	write_u32 "${3}"
}
function send_update_block() {
	write_u8 3
	write_u32 "${1}"
	write_u32 "${2}"
	write_u32 "${3}"
}
function send_freeze() {
	write_u8 4
}
function send_unfreeze() {
	write_u8 5
}
function send_step() {
	write_u8 6
}
function send_chat_message() {
	write_u8 10
	echo -n "${1}" >&99;
	write_u8 0
}

# receive a response from the RSC connection
resp=()
function receive_resp() {
	local cmd_id="$(read_u8)"
	if [ "${cmd_id}" -eq 0 ]; then
		resp=("GetBlockResp" "$(read_i32)" "$(read_i32)" "$(read_i32)" "$(read_i32)")
	elif [ "${cmd_id}" -eq 1 ]; then
		resp=("ObserveBlockResp" "$(read_i32)" "$(read_i32)" "$(read_i32)" "$(read_i32)")
	elif [ "${cmd_id}" -eq 3 ]; then
		resp=("ChatMessageResp" "$(read_strz)")
	else
		return 1;
	fi
}
