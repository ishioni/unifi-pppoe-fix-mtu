#!/bin/bash

# Source configuration
if [ -f "fix-mtu.conf" ]; then
  source fix-mtu.conf
else
  echo "Config file not found, exiting"
  exit 1
fi

attempt=1
MTUPATH="/sys/class/net/${PPP_INTERFACE}/mtu"

while [ ! -f "${MTUPATH}" ];
do
	echo "${PPP_INTERFACE} device not ready - attempt #$attempt"
	(( attempt++ ))
	sleep 15
done

INTERFACE_MTU=$(cat "$MTUPATH")
echo "MTU for ${PPP_INTERFACE} on startup is ${INTERFACE_MTU}"

if [ "${INTERFACE_MTU}" -ne ${MTU} ]; then
	/data/fix-mtu/fix-mtu.sh
else
	ip monitor link | while read -r line; do
	  if [[ "$line" == *"${PPP_INTERFACE}"* && "$line" == *"mtu"* ]]; then
  		echo "MTU change detected on ${PPP_INTERFACE}: $line"
  		/data/fix-mtu/fix-mtu.sh
	  fi
	done
fi
