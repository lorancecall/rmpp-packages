# Developer mode and SSH

The add-ons are installed over SSH, as the Paper Pro's `root` user. reMarkable only allows that in
**developer mode**. Source: reMarkable's
[developer mode guide](https://developer.remarkable.com/documentation/developer-mode).

## 1. Turn on developer mode

> **Turning developer mode on performs a factory reset: everything stored on the Paper Pro is deleted.**
> Sync your notebooks to your reMarkable cloud account first. Developer mode then stays on; turning it off again
> needs reMarkable's recovery application (see the guide's "Recovery Mode" section).

1. Settings > General > Paper Tablet > Software > Advanced > **Developer Mode**, and confirm.
2. After the reset, set the Paper Pro up again (language, Wi-Fi, your reMarkable account) and let your notebooks sync
   back. From now on a developer-mode warning is shown on every start; this is normal.
3. Open Settings > General > Help > About > **Copyrights and Licenses**. Under "General Information" you find the
   SSH user name (`root`) and its password (randomly generated).

## 2. Connect over SSH

The installer and the desktop app connect for you: they only need the Paper Pro's address and the password. This
section is for connecting by hand, or when they cannot connect.

You need an SSH client on the computer: macOS and Linux have one; on Windows 10/11 use the built-in OpenSSH client
(Settings > Apps > Optional features > OpenSSH Client), from PowerShell or Command Prompt.

**By USB cable** (works right away): connect the Paper Pro with its USB-C cable. An ethernet-over-USB network
connection appears on the computer after a few seconds, and the Paper Pro is at `10.11.99.1`:

```sh
ssh root@10.11.99.1
```

The first time, SSH asks whether to trust the Paper Pro's key: type `yes`. Then enter the password from step 1
(nothing is shown while you type). A prompt ending in `#` means you are on the Paper Pro; `exit` leaves.

**By Wi-Fi**: SSH over Wi-Fi is **off by default**. Turn it on once, over the USB connection:

```sh
ssh root@10.11.99.1 rm-ssh-over-wlan on
```

(`rm-ssh-over-wlan off` turns it off again.) The computer and the Paper Pro must be on the same network. Find the
Paper Pro's Wi-Fi address in your router's list of devices, or ask the Paper Pro over USB:

```sh
ssh root@10.11.99.1 ip -4 addr show wlan0
```

then connect to that address, for example `ssh root@192.168.1.23`.

The installer does the password login once and then sets up an SSH key, so later runs (and `ssh`) need no
password.

## If it does not connect

- **Wi-Fi: connection refused or timed out**: turn on SSH over Wi-Fi first (`rm-ssh-over-wlan on`, above). If it
  worked before, wake and unlock the Paper Pro (it may be asleep) and try again, or use the USB cable.
- **A VPN on the computer** (NordVPN, a company VPN, ...) can block the local network: turn it off, or allow
  "local network access" in the VPN app.
- **Permission denied**: check the password again in Copyrights and Licenses (it is case-sensitive).
- **`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED`** after a factory reset: the Paper Pro has a new key. Remove the
  old one with `ssh-keygen -R 10.11.99.1` (or the Wi-Fi address) and connect again.
- **USB: nothing at `10.11.99.1`**: try another cable or port (some USB-C cables only charge) and wait until the
  new network connection appears on the computer.

Careful on the Paper Pro: `systemctl stop xochitl` turns the Paper Pro off, and the root file system is read-only unless
you remount it. The installer and the packages take care of this.
