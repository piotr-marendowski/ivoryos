# IvoryOS - Arch based GNU/Linux distribution
![IvoryOS banner](assets/IvoryOS.png)

## Features
- ~~Sane~~ My defaults
- User input required only for necessary interactions while installing
- TUI installation and customization process with [Whiptail](https://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail)
- Fairly versatile installation and configuration

## Antifeatures/non-standard features
- [EFISTUB](https://wiki.archlinux.org/title/EFISTUB) in place of bootloader (on some motherboards can go wrong and fail)
- [Doas](https://wiki.archlinux.org/title/Doas) in place of [sudo](https://wiki.archlinux.org/title/Sudo)

## System installation

### Stages of installation
- Stage 1 - minimal Arch setup<br>
    User can choose either to partition disk(s):
    - Automatically - Disk partitioning is predefined, meaning that it will look like that:<br>
      **ONLY ONE DISK:**<br>
      Partition 1 = EFI 1 GB,<br>
      Partition 2 = SWAP user-defined (>=2 GB),<br>
      Partition 3 = ROOT rest of the disk space.

    - Manually - `cfdisk` will be run on all disks, then user will be prompted to run one command at time to format and mount created partitions (didn't test this approach much)

    User will be prompted to enter the name and password of the newly created user and root. User will need to choose either to use my [dotfiles with install script](https://github.com/piotr-marendowski/dotfiles) or provide the whole `git clone` command with their dotfiles. On every boot `firstboot.sh` will search in `$HOME/Downloads/dotfiles` for `script.sh`, `install-script.sh` or `install.sh` and will run it. To stop - delete the `/etc/profile.d/firstboot.sh`.

- Stage 2 - Advanced (or not) system configuration (choose programs to install, and configure dotfiles)

## ISO download on [release tag 1.0 on Gitbub](https://github.com/piotr-marendowski/ivoryos/releases/tag/1.0).

## Building
```
# install archiso
sudo pacman -S archiso
# clone this repository
git clone https://github.com/piotr-marendowski/ivoryos.git
# enter it
cd ivoryos
# as root compile new iso (building dir/, iso folder/, archiso profile dir/)
mkarchiso -v -w build/ -o iso/ releng/
# to recompile you need to delete the building directory or provide new
```
You can change link in `airoots/root/.automated_script.sh` to your dotfiles.
