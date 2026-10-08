# Noctalia Virtual Machines

A Noctalia Shell plugin for monitoring running KVM/libvirt virtual machines and opening them with virt-viewer.

## Features

- Show the number of running VMs in the bar.
- List running domains in a Noctalia panel.
- Connect to a selected VM with `virt-viewer`.
- Focus an existing Niri virt-viewer window when possible.
- Provide built-in mock support for tests and development.

## Requirements

- Noctalia Shell 3.9.0 or newer.
- `virsh`, `virt-viewer`, `jq`, `awk`, and `setsid` on `PATH`.
- Optional: `niri` for focusing an existing viewer window.
- Access to the `qemu:///system` libvirt connection.

The plugin is Linux-specific and does not create or modify virtual machines.

## Installation

Clone the repository into the Noctalia plugin directory:

```bash
git clone https://github.com/gidragir/noctalia-virt-manager ~/.config/noctalia/plugins/virt-manager
```

Enable `virt-manager` in `~/.config/noctalia/plugins.json`, add `plugin:virt-manager` to a bar or panel widget, and reload Noctalia Shell:

```bash
qs -c noctalia-shell ipc call noctalia reload
```

## Helper API

```bash
scripts/virt-helper.sh list
scripts/virt-helper.sh launch <domain>
```

The helper returns a JSON array from `list`. Set `MOCK_VIRSH=1` and `MOCK_DOMAINS='vm-one,vm-two'` for a hardware-free smoke test. Set `MOCK_LAUNCH=1` to test the launch path without starting virt-viewer.

## License

MIT. See [LICENSE](LICENSE).
