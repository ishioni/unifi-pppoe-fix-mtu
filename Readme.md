# UniFi (Cloud) Gateways PPPoE MTU Fix

> [!IMPORTANT]
> UniFi Network Application `10.5` now includes upstream support for PPPoE `1500 MTU` / RFC4638.
> 
> This repository is **obsolete on UniFi Network `10.5+`**.
> 
> Release notes: https://community.ui.com/releases/UniFi-Network-Application-10-5-54/fdfe1b15-091c-410b-9cb9-3de3acfc1255
> 
> This repository is now in **maintenance mode** and will likely be **archived soon**. If you are already on UniFi Network `10.5+`, remove this workaround and use the native implementation instead.

This repository contains a set of scripts that were created to enable full RFC4638 support (`1500` byte MTU) on Ubiquiti UniFi gateways running UniFi OS (such as UDM Pro, UDM SE, UCG Fiber, UXG, etc.) when using PPPoE connections.

Historically, UniFi often limited PPPoE connections to an MTU of `1492`. This workaround forced the correct interface settings to allow a full `1500` byte payload, improving performance and reducing fragmentation.

## Current status

### If you are on UniFi Network 10.5 or later

You **do not need this repository anymore**.

Recommended path:

1. Upgrade to UniFi Network `10.5+`.
2. Configure/enable the new native PPPoE `1500 MTU` / RFC4638 support in UniFi.
3. Confirm your WAN is stable and your MTU is working as expected.
4. Follow the [Revert and uninstall](#revert-and-uninstall) steps below, or use the one-command `uninstall.sh`, to remove this workaround.

### If you are on an older UniFi Network version

You can continue using this repository as a **legacy workaround** until you upgrade.

## Prerequisites

- UniFi Gateway running UniFi OS (UDM Pro/SE, UCG Fiber, UXG, etc.)
- SSH access enabled on the device
- A PPPoE internet connection (optionally on a VLAN)

## Legacy installation

> [!WARNING]
> Only use these instructions if your UniFi Network version does **not** yet provide the native PPPoE `1500 MTU` feature.

### Quick install (recommended)

Run the following command on your UniFi Gateway to download and install the scripts automatically:

```bash
curl -sL https://raw.githubusercontent.com/ishioni/unifi-pppoe-fix-mtu/master/install.sh | bash
```

**After installation:**

1. Check the configuration in `/data/fix-mtu/fix-mtu.conf`.
   ```bash
   nano /data/fix-mtu/fix-mtu.conf
   ```
   - Update `WAN_INTERFACE` (for example `eth8` or `eth4`) and `VLAN_ID` if needed.
   - `PPP_INTERFACE` defaults to `ppp0`.
2. Restart the service to apply changes:
   ```bash
   systemctl restart fix-mtu
   ```

### Manual installation

If you prefer to install manually:

1. **SSH into your UniFi Gateway**
   ```bash
   ssh root@<your-gateway-ip>
   ```

2. **Prepare the directory**
   ```bash
   mkdir -p /data/fix-mtu
   ```

3. **Copy files**
   Upload `fix-mtu.sh`, `monitor-mtu.sh`, `uninstall.sh`, and `fix-mtu.service` to `/data/fix-mtu/` on your gateway. For example:
   ```bash
   scp *.sh fix-mtu.service root@<your-gateway-ip>:/data/fix-mtu/
   ```

4. **Create the configuration file**
   ```bash
   vi /data/fix-mtu/fix-mtu.conf
   ```

   Example content:

   ```bash
   PPP_INTERFACE=ppp0
   WAN_INTERFACE=eth8
   VLAN_ID=35
   MTU=1500
   ```

   Adjust the values for your setup.

5. **Make scripts executable**
   ```bash
   chmod +x /data/fix-mtu/*.sh
   ```

6. **Install and enable the service**
   ```bash
   cp /data/fix-mtu/fix-mtu.service /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable fix-mtu
   systemctl start fix-mtu
   ```

## Revert and uninstall

If you are moving to UniFi Network `10.5+`, remove this workaround once native support is confirmed working.

### Recommended: one-command uninstall

```bash
curl -sL https://raw.githubusercontent.com/ishioni/unifi-pppoe-fix-mtu/master/uninstall.sh | bash
```

By default, `uninstall.sh` removes the service and files, but does **not** modify `/etc/ppp/peers/*`, since UniFi Network `10.5+` now supports this natively.

If you want to explicitly roll back PPP peer `mtu`/`mru` entries to `1492`, use:

```bash
curl -sL https://raw.githubusercontent.com/ishioni/unifi-pppoe-fix-mtu/master/uninstall.sh | bash -s -- --restore-peer --restore-mtu 1492
```

### Manual steps

#### 1. Stop and disable the service

```bash
systemctl stop fix-mtu.service
systemctl disable fix-mtu.service
```

### 2. Restore PPPoE peer MTU settings if needed

This workaround edits `/etc/ppp/peers/<PPP_INTERFACE>` when it detects a `1492 -> 1500` mismatch.

If you are **not** immediately switching to the new native UniFi implementation, or if you want to fully undo the workaround first, inspect that file and restore the original PPPoE values.

For the default interface:

```bash
vi /etc/ppp/peers/ppp0
```

If you see `1500` values added by this workaround, change them back to your original settings (commonly `1492`) unless UniFi `10.5+` is now managing this natively for you.

### 3. Remove the service and files

```bash
rm -f /etc/systemd/system/fix-mtu.service
systemctl daemon-reload
rm -rf /data/fix-mtu
```

### 4. Reconnect or reboot

To ensure UniFi fully reapplies its managed network configuration, reconnect the WAN or reboot the gateway:

```bash
reboot
```

### Optional immediate interface reset

If you want to immediately undo the runtime MTU changes before a reboot, reset the affected interfaces manually.

Examples:

```bash
ip link set dev <wan-interface> mtu 1500
ip link set dev <wan-interface>.<vlan-id> mtu 1500
```

Only do this if you know your previous values. A reboot is usually the safest way to let UniFi restore its managed state.

## Important configuration note for legacy users

### MSS clamping

For the legacy workaround to behave correctly, MSS Clamping should not fight the MTU fix.

1. Go to **Devices** and select your gateway.
2. Go to **Settings** / **Config** -> **Advanced**.
3. Ensure **MSS Clamping** is set to **Auto** or **Disabled**.

If UniFi `10.5+` handles RFC4638 natively in your environment, prefer the upstream defaults and test before keeping any old manual tuning.

## Technical details: interface MTUs

When dealing with PPPoE over a VLAN, there is often confusion regarding the correct MTU settings for the parent physical interface versus the VLAN interface.

To achieve a full `1500`-byte IP payload:

1. **IP packet**: `1500` bytes
2. **PPPoE header**: adds `8` bytes overhead
3. **Total frame size**: `1500 + 8 = 1508` bytes

### Why both interfaces were set to 1508

You may encounter advice suggesting the parent interface should be set to `1512` to account for the `4`-byte VLAN tag (`1508 + 4`). In practice on these devices, that was not necessary for this workaround.

- **VLAN interface** (for example `eth8.35`): set to `1508`
- **Parent interface** (for example `eth8`): also set to `1508`, not `1512`

The interface MTU defines the maximum payload size handled by the Linux network stack at that layer. The VLAN tag is typically inserted below that logical MTU boundary by the driver or hardware offload path.

That is why this workaround aligned both the physical parent and VLAN child interface to `1508` in order to pass RFC4638-compliant PPPoE frames cleanly.

## References

- [UniFi Community Thread](https://community.ui.com/questions/Feature-Request-UDM-Pro-PPPoE-RFC4638-1500-MTU-MRU-for-PPP/b5c1fcf6-bee5-4fc7-ae00-c8ce2bf2e724)
- [UniFi Network Application 10.5.54 release notes](https://community.ui.com/releases/UniFi-Network-Application-10-5-54/fdfe1b15-091c-410b-9cb9-3de3acfc1255)
