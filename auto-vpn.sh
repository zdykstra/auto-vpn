#!/bin/bash

reload_handler() {
  if [ -n "${openvpn_PID}" ]; then
    kill "${openvpn_PID}"
  fi
  source /etc/auto-vpn.conf
  log "Reloaded!"
}
trap reload_handler HUP 

cleanup() {
  if [ -n "${openvpn_PID}" ]; then
    log "Killing ${openvpn_PID}"
    kill "${openvpn_PID}"
  fi
  exit
}
trap cleanup TERM EXIT INT

at_home() {
  local home network

  #shellcheck disable=SC2154
  network="$( iwctl station "${device}" show | awk '/Connected network/{ print $3 }' )"

  #shellcheck disable=SC2154
  for home in "${home_networks[@]}"; do
    if [ "${home}" = "${network}" ]; then
      return 0
    fi
  done

  return 1 
}

log() {
  echo "${1}" | logger -t "${BASH_ARGV0}"
}

source /etc/auto-vpn.conf || exit 1

while true; do
  if ! at_home; then
    #shellcheck disable=SC2154,2034 
    coproc openvpn (
      openvpn --config "${ovpnconf}"
    )
    log "Connected to OpenVPN, client process ID is ${openvpn_PID}"
  fi

  while true; do
    if [ -z "${openvpn_PID}" ]; then
      log "OpenVPN process has died, reconnecting"
      break
    fi

    if at_home; then
      if [ -n "${openvpn_PID}" ]; then
        log "Connected to a network at home, killing OpenVPN process ${openvpn_PID}"
        kill "${openvpn_PID}"
        break
      fi
    fi

    sleep 10
  done
  
  sleep 10
done
