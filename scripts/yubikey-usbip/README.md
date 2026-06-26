# YubiKey USB/IP forwarding scripts

Shared shell scripts for forwarding a YubiKey to a remote host over
[USB/IP](https://github.com/torvalds/linux/tree/master/tools/usb/usbip), so the same physical YubiKey can unlock LUKS
during initrd (early boot) **and** sign git commits / run `gpg --card-status` on the booted host — all over SSH.

These scripts are installed as system packages by the [`services.yubikeyUsbip`](../../modules/yubikey-usbip/default.nix)
NixOS module, which also sets up the `usbusers` group and the udev hidraw rule. Both [orion](../../hosts/orion/) and
[p51](../../hosts/p51/) enable it.

## Roles

The usbip **server** runs on the side that has the physical YubiKey (your local client/laptop). The usbip **client**
runs on the side that needs to use the YubiKey (the remote host, during initrd or booted mode).

## Scripts

| Script | Side | Purpose | | ----------------- | -------- |
----------------------------------------------------------------- | | `detect-yubikey` | server | Auto-detect the
YubiKey bus id (`usbip list -l`, vendor `1050`). | | `bind-yubikey` | server | Load `usbip-host`, start `usbipd`, bind
the YubiKey bus id. | | `unbind-yubikey` | server | Release the YubiKey bus id from usbip. | | `attach-yubikey` | client
| Load `vhci_hcd`, attach the remote YubiKey by host + device id. | | `detach-yubikey` | client | Detach the YubiKey by
port (`usbip port`). |

`bind-yubikey` and `unbind-yubikey` call `detect-yubikey` via `PATH` when no bus id is given, so all three server-side
commands must be installed together (the module does this).

## Remote LUKS unlock flow (initrd)

The unlock-from-afar experience, step by step:

1. Make sure the YubiKey is **unbound** on the server side (your laptop).
1. SSH into the host **as root** using the YubiKey-resident SSH key (see client SSH config below).
1. On your laptop (server): `sudo bind-yubikey`
1. On the host over SSH (client): `attach-yubikey <laptop-ip>`
1. On the host over SSH: trigger the unlock (on orion the initrd shell offers an `unlock` command that runs
   `systemd-tty-ask-password-agent`).
1. After entering the PIN and touching the YubiKey, the system continues to stage two and the initrd SSH connection is
   broken.
1. Repeat step 2 — but SSH in as your normal user on the now-booted host.

> Note: only `attach-yubikey` and `detach-yubikey` are injected into the initrd (see a host's
> `boot.initrd.systemd.initrdBin`). `bind`/`unbind`/`detect` run on the server side (your laptop), not in the initrd.

## Booted-mode usage

After boot, the same scripts let you forward the YubiKey for everyday tasks — signing git commits, fetching git changes,
`usbip port`, `gpg --card-status` — without root access. The `usbusers` group and the udev hidraw rule (set up by the
module) ensure members of `usbusers` can reach the forwarded `/dev/hidraw*` device.

Add your user to `usbusers` in the host's `configuration.nix`:

```nix
users.users.${username}.extraGroups = [... "usbusers"];
```

## Client SSH configuration

Template (replace `<host>`, `<ip>` and the identity file with your own):

```
Host <host>-boot
      HostName <ip>
      port 22
      user root
      IdentitiesOnly yes
      IdentityFile ~/.ssh/id_ed25519_sk_rk_github.com
      RequestTTY yes
      ForwardAgent no
      RemoteForward 3240 localhost:3240
Host <host>
      HostName <ip>
      port 22
      user jonatan
      IdentitiesOnly yes
      IdentityFile ~/.ssh/id_ed25519_sk_rk_github.com
      ForwardAgent no
      RemoteForward 3240 localhost:3240
```

`RemoteForward 3240 localhost:3240` is the usbip port forward from the host back to your laptop's usbip daemon.

## Prerequisites

- `usbip` kernel support on both sides (`vhci_hcd` on the client, `usbip-host` on the server).
- A FIDO2-enrolled YubiKey (see the host README for `systemd-cryptenroll` commands).
- The host's LUKS device enrolled with `fido2-device=auto`.

## References

- [USB/IP kernel docs](https://github.com/torvalds/linux/tree/master/tools/usb/usbip)
- [Yubico: Securing SSH with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html)
- Host-specific notes: [orion](../../hosts/orion/README-orion.md), [p51](../../hosts/p51/INSTALL.md)
