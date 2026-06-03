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

if [ "$INTERFACE_MTU" -eq $MTU ]; then
  echo "MTU is OK"
  exit 0
fi

model=$(ubnt-device-info model 2>/dev/null || :)

case "$model" in
  "UniFi Gateway Fiber" | "UniFi Cloud Gateway Fiber" )
    case "${WAN_INTERFACE,,}" in
      "eth0" | "eth1" | "eth2" | "eth3")
        echo "ERROR: Your $model only supports changing the MTU for ports 5, 6, and 7."
        exit 1 ;;
    esac
esac

echo "MTU for ${PPP_INTERFACE} is $INTERFACE_MTU, changing to $MTU"

sed -i "s/ ${INTERFACE_MTU}/ ${MTU}/g" "/etc/ppp/peers/${PPP_INTERFACE}"
ip link set dev ${WAN_INTERFACE} mtu $(( MTU + 8 ))
if [ -n "$VLAN_ID" ]; then
  ip link set dev ${WAN_INTERFACE}.${VLAN_ID} mtu $(( MTU + 8 ))
fi

killall pppd
sleep 1
killall -q -HUP dnsmasq dnscrypt-proxy || :

exit 0
