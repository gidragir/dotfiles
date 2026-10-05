---
name: hardware-troubleshooting
description: Troubleshooting guide and diagnostics runbook for Linux audio (PipeWire, WirePlumber 0.5, Bluetooth BlueZ) and RGB lighting (OpenRGB, USB HID descriptors, systemd targets, Noctalia widget). Use when diagnosing audio dropouts, Bluetooth routing issues, or OpenRGB hardware desync.
---

# 🛠 Hardware Troubleshooting: Audio & RGB Runbook

> **Target Environment:** CachyOS Linux (Niri Wayland, PipeWire + WirePlumber 0.5, OpenRGB daemon).  
> **Key Hardware:** AMD/Intel ALSA, NVIDIA Audio, Bluetooth (Redmi Buds 5, AAC/SBC-XQ), ASUS TUF GPU, ASUS PRIME Z790-P ARGB, Kingston Fury DDR5, ASUS ROG Chakram X USB mouse.

---

## 🎧 1. Bluetooth Audio & WirePlumber 0.5

### Common Symptoms
- Bluetooth device is connected and visible in `wpctl status`, but no audio plays or video players hang.
- Audio drops or pauses when an application queries microphone/input permissions (Chromium, Telegram, Discord).
- Audio stream takes 2–5 seconds to start after silence (node suspend timeout).

### Diagnostics Checklist

```bash
# 1. Inspect current default audio sinks and active streams
wpctl status

# 2. Check active profile of the Bluetooth device (A2DP vs HFP/HSP)
# Look for your Bluetooth device ID from `wpctl status` (e.g. 55):
wpctl inspect <ID>

# 3. Check live WirePlumber logs for errors or routing loops
journalctl --user -u wireplumber.service -f --no-pager
```

### Invariants & Configuration Standards
1. **WirePlumber 0.5 SPA-JSON Syntax:**
   - WirePlumber 0.5 **deprecates Lua scripts**. All configs reside in `~/.config/wireplumber/wireplumber.conf.d/*.conf`.
   - Never create or edit `.lua` files in `wireplumber/`.

2. **Disable Headset Auto-Switch:**
   - In `wireplumber/.config/wireplumber/wireplumber.conf.d/10-seamless-routing.conf`:
     ```spa-json
     wireplumber.settings = {
         "bluetooth.autoswitch-to-headset-profile" = false
     }
     ```
   - *Why:* Prevents automatic downgrade to 8kHz/16kHz mono HFP/HSP profile whenever an app requests microphone input.

3. **Prevent Idle Suspend on ALSA and BlueZ:**
   - In `wireplumber/.config/wireplumber/wireplumber.conf.d/30-disable-idle-suspend.conf`:
     ```spa-json
     monitor.alsa.rules = [
       {
         matches = [ { "node.name" = "~alsa_output.*" } ]
         actions = { update-props = { "session.suspend-timeout-seconds" = 0 } }
       }
     ]
     monitor.bluez.rules = [
       {
         matches = [ { "node.name" = "~bluez_output.*" } ]
         actions = { update-props = { "session.suspend-timeout-seconds" = 0 } }
       }
     ]
     ```

---

## 💡 2. OpenRGB, Noctalia Widget & USB HID

### Common Symptoms
- After PC sleep/wake, RAM and GPU change color, but the mouse (ROG Chakram X) does not respond.
- On motherboard (ASUS PRIME Z790-P), only one ARGB header changes color, while others stay off or desynced.
- After reboot, OpenRGB profile does not apply automatically.

### Diagnostics Checklist

```bash
# 1. Check if OpenRGB daemon holds stale/deleted file descriptors (Zombie nodes):
ls -l /proc/$(pgrep -n openrgb)/fd/ | rg -i "hidraw.*deleted"

# 2. Check active hidraw file descriptors of OpenRGB:
lsof -p $(pgrep -n openrgb) | rg hidraw

# 3. List recognized devices in OpenRGB:
openrgb -l

# 4. Check for systemd ordering cycles in user units:
journalctl --user -u openrgb.service -u openrgb-profile.service -b --no-pager | rg -i "cycle|breaking"
```

### Invariants & Configuration Standards

1. **Systemd Targets (`graphical-session.target`):**
   - Both `openrgb.service` and `openrgb-profile.service` must specify:
     ```ini
     PartOf=graphical-session.target
     After=graphical-session.target
     [Install]
     WantedBy=graphical-session.target
     ```
   - Never use `default.target` or `multi-user.target` for these user units to avoid startup ordering cycles.

2. **CLI Argument Isolation (No Zone Leakage):**
   - In OpenRGB CLI (`cli.cpp`), setting `-z <N>` modifies `current_devices[i].zone`.
   - If `-z 3 -sz 60` is passed in a chained command, `zone = 3` carries over, causing OpenRGB to apply colors **only to zone 3** and corrupting zone parsing for following devices.
   - Do **NOT** include `-z` or `-sz` in `devices.conf` color commands:
     ```bash
     # CORRECT:
     "by-name:ASUS PRIME Z790-P WIFI:Static"
     "by-name:Asus ROG Chakram X USB:Static"

     # WRONG (causes zone leakage and configuration rewriting on every click):
     "by-name:ASUS PRIME Z790-P WIFI:Static:-z 1 -sz 60 -z 2 -sz 60 -z 3 -sz 60"
     ```
   - Zone sizes are saved permanently in `~/.config/OpenRGB/Configuration.json`.

3. **Hotplug & Resume Self-Healing:**
   - OpenRGB does not monitor dynamic udev events. When a USB peripheral is unplugged or the root hub resets on resume, `/dev/hidrawX` is deleted and recreated as `/dev/hidrawY`.
   - `devices.sh` implements self-healing:
     ```bash
     _heal_stale_openrgb() {
       local pid
       pid="$(pgrep -n openrgb 2>/dev/null || true)"
       [[ -z "$pid" ]] && return 0
       if ls -l "/proc/$pid/fd" 2>/dev/null | rg -q "hidraw.*deleted"; then
         systemctl --user restart openrgb.service >/dev/null 2>&1 || true
         sleep 0.5
       fi
     }
     ```
   - System sleep hook `/usr/lib/systemd/system-sleep/openrgb-resume` automatically restarts `openrgb.service` upon system wake.

4. **Tool Standard (`rg` / `fd`):**
   - Never use GNU `grep` or `find` in diagnostic scripts. Use `rg` and `fd`.
