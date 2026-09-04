# Bluetooth Autoconnect and Audio Health Service v3

A lightweight Linux Bluetooth audio utility for automatically reconnecting trusted devices and maintaining a reliable audio configuration across BlueZ, PipeWire, and WirePlumber.

## Features

* 🔵 Automatically connects trusted Bluetooth devices
* 🎧 Selects the highest-ranked available Bluetooth audio profile
* 🚀 Prefers SBC-XQ when supported
* 🔊 Assigns the connected Bluetooth device as the default audio sink
* 🔉 Restores a consistent default volume level
* 📡 Monitors Bluetooth signal strength and prepares audio failover when a device becomes unstable
* 🔄 Uses per-device retry and timer tracking for reliable synchronization
* 🧹 Safely cleans up removed devices and stale synchronization timers
* 🧩 Handles PipeWire objects that are still populating their properties
* 🛡️ Provides a BlueZ `NoInputNoOutput` agent for unattended connections
* 📝 Provides useful verbose diagnostics for connection and audio-state events

## Requirements

* Python 3
* BlueZ
* D-Bus Python bindings
* GLib / GObject Introspection
* PipeWire
* WirePlumber
* `pw-cli`
* `pw-dump`
* `pw-metadata`
* `wpctl`

## Installation

Install the utility:

```bash
sudo install -m 0755 bluetooth-autoconnect /usr/local/bin/bluetooth-autoconnect
```

Install the user service:

```bash
install -Dm644 bluetooth-autoconnect.service \
  ~/.config/systemd/user/bluetooth-autoconnect.service
```

Reload the user systemd manager:

```bash
systemctl --user daemon-reload
```

Enable and start the service:

```bash
systemctl --user enable --now bluetooth-autoconnect.service
```

## Manual Testing

Run the utility directly with verbose logging:

```bash
/usr/local/bin/bluetooth-autoconnect --verbose
```

Command-line options:

```text
-d, --daemon     Keep the process running after agent release
-v, --verbose    Enable verbose logging
```

## Configuration

The default volume is defined in the utility:

```python
DEFAULT_VOLUME = 0.65
```

Bluetooth signal thresholds are:

```python
RSSI_THRESHOLD = -85
RECOVERY_THRESHOLD = -75
```

Trusted devices are discovered through BlueZ and managed automatically by the service.

## Audio Policy

Bluetooth profiles are evaluated according to a preferred ranking:

1. LDAC
2. aptX HD
3. aptX
4. AAC
5. SBC-XQ
6. SBC
7. mSBC
8. CVSD

The highest-ranked profile actually provided by the Bluetooth device is selected.

## Reliability

The service is designed around the asynchronous nature of Bluetooth and PipeWire startup.

Each Bluetooth device maintains its own synchronization state, including retry count and active timer. Removed devices cancel pending timers so stale callbacks cannot revive obsolete device state.

PipeWire graph objects are recorded as soon as they are discovered. Lookups safely ignore objects whose properties have not populated yet, preventing startup and reconnect races from becoming fatal errors.

Volume is applied through PipeWire's current default sink after profile enforcement, avoiding stale node identifiers when Bluetooth profiles cause the audio node to be recreated.

## Diagnostics

Verbose logging distinguishes expected conditions from actual failures.

Examples:

```text
📡 Device unavailable: BassPULSE
⏳ Connection already in progress: PBT9542
Connected: PBT9542
🔎 Supported profiles for PBT9542: [...]
🎧 Policy Enforced: Set 'a2dp-sink-sbc_xq' on PBT9542
🔊 Volume locked to standard profile: 65%
```

## Version History

### v3.0

* Added per-device retry and timer bookkeeping
* Added safe cleanup for removed Bluetooth devices
* Improved BlueZ connection diagnostics
* Distinguished unavailable devices from unexpected connection failures
* Added PipeWire object lifecycle protection
* Added defensive handling of partially initialized graph objects
* Added Bluetooth profile ranking and policy enforcement
* Added default Bluetooth sink assignment
* Added default volume synchronization
* Added RSSI-based failover and recovery handling
* Consolidated runtime imports
* Retained Python `faulthandler` diagnostics for fatal process errors

## License

Released as part of the Mintian Utilities collection.
