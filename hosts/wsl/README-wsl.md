# NixOS WSL host

> **📝 Abandon strategy**  
> I experienced problems with a corrupt git history and random disk I/O errors,
> almost always triggered by `nix flake update --commit-lock-file` and
> `sudo nixos-rebuild switch --flake ~/nixos-config#wsl`. Maybe I'm doing something wrong,
> but NixOS under WSL seems very unstable. I really tried hard to understand the underlying problem
> without coming to a conclusion. I'm sorry, but I can't recommend this setup.
> It looked good in theory but not in practice.
> 
> I'm here by abandon the experiment of mixing a NixOS development environment with Windows 11 and will start an
> alternative path with a dual boot setup. I will keep the WSL setup for reference and inspiration. Maybe I will come
> back to it if someone comes up with a solution to the problems I experienced.

---

This project is based on [LGUG2Z's nixos-wsl-starter](https://github.com/LGUG2Z/nixos-wsl-starter),
[nix-communit NixOS-WSL](https://github.com/nix-community/NixOS-WSL) and
[ankarhem's nix-config](https://github.com/ankarhem/nix-config/).

The initial purpose of the project is to set up a mixed develop environment in Windows 11 and
Windows Subsystem for Linux, a.k.a WSL2. I am slowly learning about NixOS, so the repository will grow with more hosts.
Candidates in 2025 are my six year old Lenovo P51 (now running Linux Manjaro) and a couple of upcoming virtual machines
on my new home lab. I will probably also change the shell and add support for remote development with Jetbrains Rider.

Regards, [Jonatan Hilmarch](https://github.com/JHilmarch)

## Table of Contents
- [Modules](#modules)
    - [fish](#fish)
        - [win32yank](#win32yank)
    - [startship](#startship)
- [Configuration](#configuration)
    - [YubiKey passthrough](#yubikey-passthrough)
    - [YubiKey SSH](#yubikey-ssh)
- [Setup guide](#setup-guide)
    - [Build your own Linux Kernel](#build-your-own-linux-kernel)
    - [Install NixOS on WSL](#install-nixos-on-wsl)

## Modules

### fish

The module contains the _fish_ shell configurations: Includes git aliases and useful WSL aliases.
`win32yank` is used to ensure perfect bi-directional copying and pasting to
and from Windows GUI applications and LunarVim running in WSL.
Change the win `win32yank` PATH in `interactiveShellInit`.

#### win32yank

There have been some recent changes in WSL2 that make running `win32yank`
within WSL2 very slow. You should install this on Windows by running `scoop install win32yank` or compiling it from source, and then adding it to your `$PATH`:

```nix
{
    programs.fish = {
      interactiveShellInit = ''
        fish_add_path --append /mnt/c/Users/<Your Windows Username>/scoop/apps/win32yank/0.1.1
      '';
    };
}
```

...or by using winget:

```powershell
winget install --id=equalsraf.win32yank  -e
```

```nix
{
    programs.fish = {
      interactiveShellInit = ''
        fish_add_path --append /mnt/c/Users/Jonat/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe/
      '';
    };
}
```

:exclamation: Ensure that the environment variable User => PATH is set in Windows.

### startship

The prompt is [Starship](https://starship.rs/).

## Configuration

Go to [https://search.nixos.org](https://search.nixos.org/packages) to find the
correct package names, though usually they will be what you expect them to be
in other package managers.

`unstable-packages` is for packages that you want to always keep at the latest
released versions, and `stable-packages` is for packages that you want to track
with the current release of NixOS.

If you want to update the versions of the available `unstable-packages`, run
`nix flake update` to pull the latest version of the Nixpkgs repository and
then apply the changes.

Change `time.timeZone`.

- The default editor is [JeezyVim](https://github.com/LGUG2Z/JeezyVim)
- Native `docker` is enabled by default
- The prompt is [Starship](https://starship.rs/)
- [`fzf`](https://github.com/junegunn/fzf),
  [`lsd`](https://github.com/lsd-rs/lsd),
  [`zoxide`](https://github.com/ajeetdsouza/zoxide), and
  [`broot`](https://github.com/Canop/broot) are integrated into `fish` by
  default
    - These can all be disabled easily by setting `enable = false` in
      [home.nix](./hosts/wsl/home.nix), or just removing the lines all together
- [`direnv`](https://github.com/direnv/direnv) is integrated into `fish` by
  default
- `git` config is generated in [home.nix](./hosts/wsl/home.nix) by the [git module](./modules/git/default.nix)
- `gpg` config is generated in [home.nix](./hosts/wsl/home.nix) by the [gpg module](./modules/gpg/default.nix)
- The default shell is `fish`.
  Configuration is generated in [home.nix](./hosts/wsl/home.nix) by the [fish module](./modules/fish/default.nix)
- Identity keys are configured in [ssh.nix](./hosts/wsl/modules/ssh.nix).

### YubiKey passthrough

**Prerequisites:** YubiKey FIDO2 and PGP signing already works in Windows

```powershell
# Check if FIDO2 is enabled
ykman info
```

Read more on how to set up your YubiKey:
- [Dr Duh's YubiKey-Guide](https://github.com/drduh/YubiKey-Guide)

**Bind the YubiKey USB-port to usbip and attach to WSL**
- Install [usbipd](https://github.com/dorssel/usbipd-win) in Windows
- Look up BUSID
- Change `usbip.autoAttach` in [wsl configurations](./hosts/wsl/configuration.nix)
- Bind BUSID
    - The USB will auto-attach to WSL

```powershell
winget install usbipd
usbipd list
usbipd bind --busid=<BUSID>
```

[![Watch the video about smartcards in Windows, usbipd and WSL](https://img.youtube.com/vi/qbKkrArkXkY/hqdefault.jpg)](https://www.youtube.com/watch?v=qbKkrArkXkY)

_Using SSH Smart Card Authentication in WSL_

### YubiKey SSH

In Windows; ensure that you have a SSH key.

```powershell
# Search your FIDO credentials for existing SSH keys
ykman fido credentials list -c | ConvertFrom-Csv | Select-Object credential_id, rp_id, user_name, user_display_name | Format-Table -AutoSize
```

If you don't have an SSH key, you can create a new key-pair with this command:

```powershell
ssh-keygen -t ed25519-sk -O resident -O application=ssh:github.com -O verify-required -C "YubiKey 5C NFC 12345678"
```

In WSL, with the YubiKey connected: Go to your home ssh folder and recreate the SSH keys:

```bash
cd ~/.ssh/
ssh-keygen -K
```

The name on your private keys should correspond to the identity files configured in [ssh.nix](./hosts/wsl/modules/ssh.nix).

If the public key is uploaded to GitHub you can test your connection like this:

```bash
ssh -T git@github.com
```

**Read more**:

- [Yubico: Securing SSH Authentication with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html)
- [Another SSH guide](https://gist.github.com/Kranzes/be4fffba5da3799ee93134dc68a4c67b)

## Setup guide

### Build your own Linux Kernel

Fork the [custom-wsl2-linux-kernel](https://github.com/LGUG2Z/custom-wsl2-linux-kernel), read the documentation, edit what you want and push the changes.
The GitHub build action will create an artifact with the kernel. An alternative is to
[download latest build artifact](https://github.com/JHilmarch/custom-wsl2-linux-kernel/actions/workflows/build.yml) directly from **my fork**.
Remeber to create or update the [.wslconfig](https://github.com/JHilmarch/custom-wsl2-linux-kernel/blob/master/.wslconfig) file in your Windows home directory.

A customized WSL is necessary to make the YubiKey passthrough to work.

### Install NixOS on WSL

- Get the latest [24.11 release of NixOS-WSL](https://github.com/nix-community/NixOS-WSL/releases/tag/2411.6.0)
- Install it (tweak the command to your desired paths):

```powershell
wsl --import NixOS .\NixOS\ .\nixos.wsl --version 2
```

- Enter the distro

```powershell
wsl -d NixOS
```

- Download this repository or your fork and copy it via Windows Explorer to your home directory
`\\wsl.localhost\NixOS\home\nixos`
- Step in to the flake configuration folder and update flake

```bash
cd ~/nixos-config-main
```

- Apply the configuration and shutdown the WSL2 VM

```bash
sudo nixos-rebuild switch --flake ~/nixos-config-main#ws && sudo shutdown -h now
```

- Reconnect to the WSL2 VM

```bash
wsl -d NixOS
```

:information_source: You can optionally set a default wsl: `wsl --set-default NixOS`.

- Delete the nix-config folder

```bash
rm nixos-config-main/ --recursive
```

- Add SSH keys
- Clone the repository in your WSL home directory

```bash
git clone git@github.com:JHilmarch/nixos-config.git
cd /nixos-config
```

:information_source: `rebuild` is an alias for `nix flake update --commit-lock-file`.

- Install `win32yank` with `scoop`/`winget` and add it to your `$PATH` in NixOS
- Apply the configuration and shutdown the WSL2 VM
    - :exclamation: You need to stage your changes (if any) before running `rebuild`
    - Preferable; commit all your changes
    - Optionally; update your flake with the `rebuild` command

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#wsl && sudo shutdown -h now
```

- Reconnect to the WSL2 VM

```bash
wsl -d NixOS
```

At this point you have already tested the fish shell and git with gpg signing. If everything looks good, push your changes.
Otherwise; repeat the steps above and try again.
