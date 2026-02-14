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

if [ "$INTERFACE_MTU" -eq 1492 ]; then
  echo "MTU for ${PPP_INTERFACE} is $INTERFACE_MTU, changing to $MTU"
  sed -i 's/ 1492/ ${MTU}/g' "/etc/ppp/peers/${PPP_INTERFACE}"
  ip link set dev ${WAN_INTERFACE} mtu 1508
  ip link set dev ${VLAN_INTERFACE} mtu 1508
  ifconfig ${WAN_INTERFACE} down
  ifconfig ${WAN_INTERFACE} up
  killall pppd
  sleep 1
  killall -HUP dnscrypt-proxy dnsmasq
else
  echo "MTU is OK"
fi
