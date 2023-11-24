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

    User will be prompted to enter the name and password of the newly created user. [Dotfiles install script](https://github.com/piotr-marendowski/dotfiles) will be run on every boot until it finishes the installation, then it will stop (delete `/etc/profile.d/firstboot.sh` to get rid of this function).

- Stage 2 - Advanced (or not) system configuration (choose programs to install, and configure dotfiles)

## ISO download on [release tag 0.95 on Gitbub](https://github.com/piotr-marendowski/ivoryos/releases/tag/0.95) or [SourceForge](https://sourceforge.net/projects/ivoryos/files/) (old, unstable, requires tinkering in order to work).

## Troubleshooting

If installation is stuck more 10 minutes on one stage with the same percent then start to worry. Reboot machine and run installer again. If this doesn't work then reboot and edit `.automated_script` (in first stage) or `install.sh` (in second stage). Try removing `&> /dev/null` from commands and commenting out whiptail statements to make commands print to your tty.

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
