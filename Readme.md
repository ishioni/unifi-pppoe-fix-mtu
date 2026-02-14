# Unifi (Cloud) Gateways PPPoE MTU Fix

This repository contains a set of scripts to enable full RFC4638 support (1500 byte MTU) on Ubiquiti Unifi (Cloud) Gateways running UnifiOS (such as UDM Pro, UDM SE, UDW, UDR, UXG, etc.) when using PPPoE connections.

By default, Unifi OS often limits PPPoE connections to an MTU of 1492. This script forces the correct interface settings to allow a full 1500 byte payload, improving network performance and reducing fragmentation.

## Prerequisites

*   Unifi Gateway running UnifiOS (UDM Pro/SE, UDW, UDR, etc.).
*   SSH access enabled on the device.
*   A PPPoE internet connection (optionally on a VLAN).

## Installation

### Quick Install (Recommended)

Run the following command on your Unifi Gateway to download and install the scripts automatically:

```bash
curl -sL https://raw.githubusercontent.com/ishioni/unifi-pppoe-fix-mtu/main/install.sh | bash
```

**After installation:**
1.  Check the configuration in `/data/fix-mtu/fix-mtu.conf`.
    ```bash
    nano /data/fix-mtu/fix-mtu.conf
    ```
    *   Update `WAN_INTERFACE` (e.g., `eth8` or `eth4`) and `VLAN_ID` (e.g., `35`) if needed.
    *   `PPP_INTERFACE` defaults to `ppp0`.
2.  Restart the service to apply changes:
    ```bash
    systemctl restart fix-mtu
    ```

### Manual Installation

If you prefer to install manually:

1.  **SSH into your Unifi Gateway:**
    ```bash
    ssh root@<your-gateway-ip>
    ```

2.  **Prepare the directory:**
    Create a persistent directory for the scripts.
    ```bash
    mkdir -p /data/fix-mtu
    ```

3.  **Copy files:**
    Upload `fix-mtu.sh`, `monitor-mtu.sh`, and `fix-mtu.service` to `/data/fix-mtu/` on your Gateway. You can use `scp` from your local machine:
    ```bash
    scp *mtu* root@<your-gateway-ip>:/data/fix-mtu/
    ```

4.  **Configure the script:**
    Create a configuration file `/data/fix-mtu/fix-mtu.conf`:
    ```bash
    vi /data/fix-mtu/fix-mtu.conf
    ```
    Content:
    ```bash
    PPP_INTERFACE=ppp0
    WAN_INTERFACE=eth8
    VLAN_ID=35
    VLAN_INTERFACE=${WAN_INTERFACE}.${VLAN_ID}
    MTU=1500
    ```
    Adjust the values to match your setup.

5.  **Make scripts executable:**
    ```bash
    chmod +x /data/fix-mtu/*.sh
    ```

6.  **Install and Enable the Service:**
    Copy the systemd service file and enable it so it runs on boot.
    ```bash
    cp /data/fix-mtu/fix-mtu.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable fix-mtu
    systemctl start fix-mtu
    ```

## Important Configuration

**Disable MSS Clamping:**
For this fix to work correctly, you must disable MSS Clamping in the Unifi Network application.
1.  Go to **Devices** and select your Gateway.
2.  Go to **Settings** (Config) -> **Advanced**.
3.  Ensure **MSS Clamping** is set to **Auto** or **Disabled** (or Custom with a high value, but Disabled is preferred if the MTU fix works). *Note: The original advice suggests disabling it to let the proper MTU negotiation handle packet sizes.*

## Technical Details: Interface MTUs

When dealing with PPPoE over a VLAN, there is often confusion regarding the correct MTU settings for the parent physical interface versus the VLAN interface.

To achieve a full 1500-byte IP payload:
1.  **IP Packet**: 1500 bytes.
2.  **PPPoE Header**: Adds 8 bytes overhead.
3.  **Total Frame Size**: 1500 + 8 = **1508 bytes**.

### Why BOTH interfaces must be 1508

You might encounter configurations suggesting the parent interface should be set to **1512** to account for the 4-byte VLAN tag (1508 + 4). However, in the context of the Linux kernel network stack on these devices, this is incorrect.

*   **VLAN Interface (e.g., `eth8.35`):** Must be set to **1508** to accept the full PPPoE frame.
*   **Parent Interface (e.g., `eth8`):** Must also be set to **1508**, NOT 1512.

The interface MTU setting defines the maximum size of the *payload* the interface executes on. When the VLAN interface passes the 1508-byte payload to the parent interface, the parent interface validates that the packet size does not exceed its own MTU. The 4-byte VLAN tag is added by the hardware offloading or driver logic at a layer that typically does not count towards the logical Interface MTU limit for the payload itself.

Setting the parent to 1512 is unnecessary and can sometimes lead to inconsistencies. Both the physical parent and the VLAN child interface should be aligned at **1508** to cleanly pass the RFC4638 compliant PPPoE frames.

## References

*   [Unifi Community Thread](https://community.ui.com/questions/Feature-Request-UDM-Pro-PPPoE-RFC4638-1500-MTU-MRU-for-PPP/b5c1fcf6-bee5-4fc7-ae00-c8ce2bf2e724)
