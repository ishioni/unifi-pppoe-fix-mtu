#!/bin/bash

# Source configuration
if [ -f "fix-mtu.conf" ]; then
    source fix-mtu.conf
else
  echo "Config file not found, exiting"
  exit 1
fi

MTUPATH="/sys/class/net/${PPP_INTERFACE}/mtu"

if ! [ -f "$MTUPATH" ]; then
  echo "${PPP_INTERFACE} device not ready"
  exit 0
fi

INTERFACE_MTU=$(cat "$MTUPATH")

if [ "$INTERFACE_MTU" -ne $MTU ]; then
  echo "MTU for ${PPP_INTERFACE} is $INTERFACE_MTU, changing to $MTU"
  sed -i "s/ ${INTERFACE_MTU}/ ${MTU}/g" "/etc/ppp/peers/${PPP_INTERFACE}"
  ip link set dev ${WAN_INTERFACE} mtu $(( MTU + 8 ))
  ip link set dev ${WAN_INTERFACE}.${VLAN_ID} mtu $(( MTU + 8 ))
  # This might not even be needed?
  # ifconfig ${WAN_INTERFACE} down
  # ifconfig ${WAN_INTERFACE} up
  killall pppd
  sleep 1
  killall -HUP dnscrypt-proxy dnsmasq
else
  echo "MTU is OK"
fi
