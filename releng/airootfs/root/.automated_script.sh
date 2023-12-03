#!/usr/bin/env bash

script_cmdline ()
{
    local param
    for param in $(< /proc/cmdline); do
        case "${param}" in
            script=*) echo "${param#*=}" ; return 0 ;;
        esac
    done
}

automated_script ()
{
    local script rt
    script="$(script_cmdline)"
    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
        if [[ "${script}" =~ ^((http|https|ftp)://) ]]; then
            curl "${script}" --location --retry-connrefused --retry 10 -s -o /tmp/startup_script >/dev/null
            rt=$?
        else
            cp "${script}" /tmp/startup_script
            rt=$?
        fi
        if [[ ${rt} -eq 0 ]]; then
            chmod +x /tmp/startup_script
            /tmp/startup_script
        fi
    fi
}

if [[ $(tty) == "/dev/tty1" ]]; then
    automated_script
fi

# THE SCRIPT STARTS HERE

# colors
export NEWT_COLORS="
root=,black
window=black,black
shadow=black,black
border=white,black
title=white,black
textbox=white,black
radiolist=white,black
label=black,white
checkbox=white,black
listbox=white,black
compactbutton=white,black
button=black,white
actbutton=white,black
entry=black,white
actlistbox=black,white
textbox=white,black 
roottext=white,black
emptyscale=white,black
fullscale=white,white
disentry=white,white
actsellistbox=black,white
sellistbox=white,black"

reboot_now() {
    if whiptail --title "Reboot" --yesno "\nDo you want to reboot now?" 9 35; then
        reboot
        clear
    fi
}

# name them because of the progress bar
# start
start() {
    if whiptail --title "Installation" --yesno "Do you want to proceed with installation?" 8 50; then
        # Verify the boot mode - search if 
        if ! ls /sys/firmware/efi/efivars | grep -q "."; then
            whiptail --title "UEFI Mode" --msgbox "Boot into UEFI mode." 8 50
            reboot_now
        fi

        # Connect to the internet
        if ping -q -c 1 -W 1 archlinux.org &>/dev/null; then
            :
        else
            whiptail --title "Internet" --infobox "No internet connection found. Please ensure that you have internet." 8 50
            reboot_now
        fi

        # Partition the disks
        # Get the list of available disks
        DISKS=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac) &> /dev/null

        # Choose way to partition disks
        if whiptail --title "Partition Manager" --yesno "Do you want to partition disk(s) automatically or manually? (Auto highly recommended)" \
        --yes-button="Auto" --no-button="Manually" 8 50; then

            # Ask the user to select a disk
            DISK=$(whiptail --title "Partition Manager" --menu "\nSelect a disk to partition:" 11 40 4 \
            $(echo "$DISKS" | awk '{print $1 " \"" $2 "\""}') 3>&1 1>&2 2>&3) &> /dev/null

            # Get the disk size in gigabytes
            DISK_SIZE=$(parted -s "$DISK" print | awk '/Disk/ {print $3}' | tr -d 'GB') &> /dev/null

            # Enter the swap size in gigabytes
            SWAP_SIZE=$(whiptail --inputbox "\nEnter the swap size in gigabytes (minimum 2): " 11 40 2 --title "Partition Manager" 3>&1 1>&2 2>&3) &> /dev/null
            # Convert the swap size to megabytes
            SWAP_SIZE_MB=$(echo "($SWAP_SIZE + 1) * 1024" | bc) &> /dev/null

            # Create the partitions
            parted -s "$DISK" mklabel gpt &> /dev/null
            parted -s "$DISK" mkpart efi fat32 1MiB 1GiB &> /dev/null
            parted -s "$DISK" set 1 boot on &> /dev/null

            [ "$SWAP_SIZE" -ne 0 ] &&
                parted -s "$DISK" mkpart swap linux-swap 1GiB "${SWAP_SIZE_MB}M" &> /dev/null

            parted -s "$DISK" mkpart root ext4 "${SWAP_SIZE_MB}M 100%" &> /dev/null

            # Check if the DISK variable starts with "nvme"
            if case $DISK in nvme*) ;; *) false;; esac; then
                EFI_PARTITION="${DISK}p1"
                SWAP_PARTITION="${DISK}p2"
                ROOT_PARTITION="${DISK}p3"
            else
                # other
                EFI_PARTITION="${DISK}1"
                SWAP_PARTITION="${DISK}2"
                ROOT_PARTITION="${DISK}3"
            fi

            # Format the partitions
            mkfs.fat -F 32 ${EFI_PARTITION} &> /dev/null
            mkswap ${SWAP_PARTITION} &> /dev/null
            mkfs.ext4 ${ROOT_PARTITION} &> /dev/null

            # Mount the partitions
            mount ${ROOT_PARTITION} /mnt &> /dev/null
            swapon ${SWAP_PARTITION} &> /dev/null
            mkdir /mnt/boot &> /dev/null
            mount ${EFI_PARTITION} /mnt/boot &> /dev/null

            # Calculate the size of the root partition
            ROOT_SIZE=$(lsblk -no SIZE ${ROOT_PARTITION}) &> /dev/null

            # Display the partition information
            whiptail --title "Partition Manager" --msgbox "Partitions created:\n\n${EFI_PARTITION} - EFI partition (1G)\
\n${SWAP_PARTITION} - Swap partition (${SWAP_SIZE}G)\n${ROOT_PARTITION} - Root partition (${ROOT_SIZE})\n\n\
Now script will install base system, and other necessary packages.\n\
This will take some time." 15 45

        else
            # Loop through each disk and run cfdisk on it
            for disk in $DISKS; do
                cfdisk $disk
            done

            whiptail --title "Partition Manager" --msgbox "Now you will need to enter commands to \
format your disk(s)." 9 45

            # Loop until the user exits
            while true; do
                command=$(whiptail --inputbox --title "Command Input" "\nEnter a command to execute:" \
                    --cancel-button="Quit" 9 50 3>&1 1>&2 2>&3)

                if [ $? -ne 0 ]; then
                    break
                fi

                # Execute command
                eval $command
            done

        fi

else
    if whiptail --yesno "Do you want to shutdown now?" 8 35; then
        clear
        shutdown now
    else
        clear
        exit
    fi
fi

}

pacstrap_stage() {
    pacman -S archlinux-keyring --noconfirm && pacman-key --init && pacman-key --populate archlinux &> /dev/null
    # Install the base system (after reflector is base-devel-like stuff)
    pacstrap /mnt base linux linux-firmware opendoas zsh networkmanager git neovim efibootmgr reflector autoconf automake binutils patch pkgconf gzip sed which gawk make gcc fakeroot archlinux-keyring
}
fstab() {
    # Generate disk layout
    genfstab -U /mnt >> /mnt/etc/fstab
}
# Do necessary stuff in chroot - send every command alone
# Thanks to <https://github.com/shagu> its working!
chroot() {
    arch-chroot /mnt /bin/bash -c "sed -i 's/#PACMAN_AUTH=()/PACMAN_AUTH=(doas)/g' /etc/makepkg.conf"
    # arch-chroot /mnt /bin/bash -c "echo "KEYMAP=pl_PL" > /etc/vconsole.conf"
    arch-chroot /mnt /bin/bash -c "sed -i '/^#en_US.UTF-8/s/^#//' /etc/locale.conf"
    arch-chroot /mnt /bin/bash -c "pacman-key --init && pacman-key --populate archlinux"
    arch-chroot /mnt /bin/bash -c "echo "ivory" > /etc/hostname"
    arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"
}
mkinitcpio() {
    # arch-chroot /mnt /bin/bash -c "mkinitcpio -P"
    :
}
efistub() {
    arch-chroot /mnt /bin/bash -c "efibootmgr --create --disk ${DISK} --part 1 --label "IvoryOS" --loader /vmlinuz-linux --unicode 'root=UUID=$(blkid -s UUID -o value ${ROOT_PARTITION}) resume=UUID=$(blkid -s UUID -o value ${SWAP_PARTITION}) rw initrd=\initramfs-linux.img'"
}
lsb_release() {
    arch-chroot /mnt /bin/bash -c 'touch /etc/lsb-release'
    arch-chroot /mnt /bin/bash -c 'touch /etc/ivory-release'
    arch-chroot /mnt /bin/bash -c 'touch /usr/share/libalpm/hooks/lsb-release.hook'
    arch-chroot /mnt /bin/bash -c 'printf "DISTRIB_ID="ivory"\nDISTRIB_RELEASE="rolling"\nDISTRIB_DESCRIPTION="IvoryOS"\n" > /etc/lsb-release'
    arch-chroot /mnt /bin/bash -c 'printf "DISTRIB_ID="ivory"\nDISTRIB_RELEASE="rolling"\nDISTRIB_DESCRIPTION="IvoryOS"\n" > /etc/ivory-release'
    arch-chroot /mnt /bin/bash -c 'printf "DISTRIB_ID="ivory"\nDISTRIB_RELEASE="rolling"\nDISTRIB_DESCRIPTION="IvoryOS"\n" > /etc/ivory-release'

    arch-chroot /mnt /bin/bash -c 'sh -c "cat >>/usr/share/libalpm/hooks/lsb-release.hook" <<-EOF
# IvoryOS lsb-release hook for neofetch logo
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = lsb-release

[Action]
Description = Copy /etc/ivory-release to /etc/lsb-release
When = PostTransaction
Exec = /bin/sh -c "rm /etc/lsb-release && cp /etc/ivory-release /etc/lsb-release"
EOF
'
}
dotfiles() {
    mv /etc/profile.d/firstboot.sh /mnt/etc/profile.d/ &> /dev/null

    arch-chroot /mnt /bin/bash -c 'root_password=$(whiptail --title "Set Root Password" --passwordbox "\nEnter new root password:" 10 40 3>&1 1>&2 2>&3); echo "root:$root_password" | chpasswd'
    clear

    # Create a user
    username=$(whiptail --title "Create User" --inputbox "\nEnter username:" 10 40 3>&1 1>&2 2>&3)
    password=$(whiptail --title "Create User" --passwordbox "\nEnter password:" 10 40 3>&1 1>&2 2>&3)

    choice=$(whiptail --title "Choose Branch" --menu "\nChoose the branch of dotfiles:" 13 40 4 \
        "dwm (xorg)"     "" \
        "dwm (wayland)"  "" \
        "qtile"          "" \
        "other"          "" 3>&1 1>&2 2>&3)

    # Inject variables so it can use it
    arch-chroot /mnt /bin/bash -c '
        useradd -s /usr/bin/zsh -m '"$username"' -G wheel && 
        echo -e "'"$password"'\n'"$password"'" | passwd "'"$username"'" && echo "User created!" && 

        echo "permit nopass '"$username"' as root" > /etc/doas.conf &&
        chown -c root:root /etc/doas.conf &&
        chmod -c 0400 /etc/doas.conf &&
        chmod +x /etc/profile.d/firstboot.sh &&

        mkdir -p /home/'"$username"'/Downloads' &> /dev/null

    echo "User configured!"

    if [ "$choice" = "dwm (xorg)" ]; then
        arch-chroot /mnt /bin/bash -c '
            cd /home/'"$username"'/Downloads &&
            git clone -b dwm https://github.com/piotr-marendowski/dotfiles'

    elif [ "$choice" = "dwm (wayland)" ]; then
        arch-chroot /mnt /bin/bash -c '
            cd /home/'"$username"'/Downloads &&
            git clone -b dwm-wayland https://github.com/piotr-marendowski/dotfiles'

    elif [ "$choice" = "qtile" ]; then
        arch-chroot /mnt /bin/bash -c '
            cd /home/'"$username"'/Downloads &&
            git clone -b qtile https://github.com/piotr-marendowski/dotfiles'

    elif [ "$choice" = "other" ]; then
        other=$(whiptail --inputbox --title "Dotfiles" "\nEnter the WHOLE git clone link to your dotfiles:" \
            --cancel-button="Quit" 9 70 3>&1 1>&2 2>&3)

        arch-chroot /mnt /bin/bash -c '
            cd /home/'"$username"'/Downloads && '"${other}"' '

    fi

    arch-chroot /mnt /bin/bash -c '
        chown -R "'"$username"':'"$username"'" /home/'"$username"'/Downloads &&
        chmod -R 755 /home/'"$username"'/Downloads' &> /dev/null


    whiptail --title "Installation complete!" --msgbox "\nAfter reboot you will have \
options to customize and configure your system." 10 40

    reboot_now
}

start
# show progress bar and execute functions
whiptail --title "Progress" --gauge "\nInstalling the base system... It'll take a few minutes." 7 60 0 < <(
    # Update the gauge
    gauge=$((100 * 1 / 7)) && echo "$gauge"
    pacstrap_stage &> /dev/null
    #######################################
    gauge=$((100 * 2 / 7)) && echo "$gauge"
    fstab &> /dev/null
    #######################################
    gauge=$((100 * 3 / 7)) && echo "$gauge"
    chroot &> /dev/null
    #######################################
    gauge=$((100 * 4 / 7)) && echo "$gauge"
    mkinitcpio &> /dev/null
    #######################################
    gauge=$((100 * 5 / 7)) && echo "$gauge"
    efistub &> /dev/null
    gauge=$((100 * 6 / 7)) && echo "$gauge"
    lsb_release &> /dev/null
)
dotfiles

exit

