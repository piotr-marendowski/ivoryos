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
    if whiptail --title "Reboot" --yesno "\nDo you want to reboot now?" 9 40; then
        reboot
    fi
}

# name them because of the progress bar
# start
one() {
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

        # Update the system clock
        timedatectl &>/dev/null

        # Partition the disks
        # Get the list of available disks
        DISKS=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac) &> /dev/null

        # Ask the user to select a disk
        DISK=$(whiptail --title "Partition Manager" --menu "\nSelect a disk to partition:" 15 40 6 \
        $(echo "$DISKS" | awk '{print $1 " \"" $2 "\""}') 3>&1 1>&2 2>&3) &> /dev/null

        # Get the disk size in gigabytes
        DISK_SIZE=$(parted -s "$DISK" print | awk '/Disk/ {print $3}' | tr -d 'GB') &> /dev/null

        # Enter the swap size in gigabytes
        SWAP_SIZE=$(whiptail --inputbox "\nEnter the swap size in gigabytes: (must be bigger than 1GB)" 11 40 2 --title "Swap Size" 3>&1 1>&2 2>&3) &> /dev/null
        # Convert the swap size to megabytes
        SWAP_SIZE_MB=$(echo "($SWAP_SIZE + 1) * 1024" | bc) &> /dev/null

        # Create the partitions
        parted -s "$DISK" mklabel gpt &> /dev/null
        parted -s "$DISK" mkpart efi fat32 1MiB 1GiB &> /dev/null
        parted -s "$DISK" set 1 boot on &> /dev/null
        parted -s "$DISK" mkpart swap linux-swap 1GiB "${SWAP_SIZE_MB}M" &> /dev/null
        parted -s "$DISK" mkpart root ext4 "${SWAP_SIZE_MB}M 100%" &> /dev/null

        # Check if the DISK variable starts with "nvme"
        if [[ $DISK == nvme* ]]; then
            # NVMe disk
            # Format the partitions
            mkfs.fat -F 32 ${DISK}p1 &> /dev/null
            mkswap ${DISK}p2 &> /dev/null
            mkfs.ext4 ${DISK}p3 &> /dev/null

            # Mount the partitions
            mount ${DISK}p3 /mnt &> /dev/null
            mkdir /mnt/boot &> /dev/null
            mount ${DISK}p1 /mnt/boot &> /dev/null
            swapon ${DISK}p2 &> /dev/null

            # Calculate the size of the root partition
            ROOT_SIZE=$(lsblk -no SIZE ${DISK}p3) &> /dev/null

            # Display the partition information
            whiptail --title "Partition Manager" --msgbox "Partitions created:\n\n${DISK}p1 - EFI partition (1G)\
    \n${DISK}p2 - Swap partition (${SWAP_SIZE}G)\n${DISK}p3 - Root partition (${ROOT_SIZE})\n\n\
    Now script will install system, kernel, bootloader, and other necessary packages.\n\
    This will take some time." 15 45

        else
            # Not NVMe disk
            # Format the partitions
            mkfs.fat -F 32 ${DISK}1 &> /dev/null
            mkswap ${DISK}2 &> /dev/null
            mkfs.ext4 ${DISK}3 &> /dev/null

            # Mount the partitions
            mount ${DISK}3 /mnt &> /dev/null
            mkdir /mnt/boot &> /dev/null
            mount ${DISK}1 /mnt/boot &> /dev/null
            swapon ${DISK}2 &> /dev/null

            # Calculate the size of the root partition
            ROOT_SIZE=$(lsblk -no SIZE ${DISK}3) &> /dev/null

            # Display the partition information
            whiptail --title "Partition Manager" --msgbox "Partitions created:\n\n${DISK}1 - EFI partition (1G)\
\n${DISK}2 - Swap partition (${SWAP_SIZE}G)\n${DISK}3 - Root partition (${ROOT_SIZE})\n\n\
Now script will install system, kernel, bootloader, and other necessary packages.\n\
This will take some time." 15 45

        fi
else
    if whiptail --yesno "Do you want to shutdown now?" 8 35; then
        shutdown now
    else
        exit
    fi
fi

}

two() {
    # Install the base system
    pacstrap /mnt base base-devel linux linux-firmware &> /dev/null
}
three() {
    # Generate disk layout
    genfstab -U /mnt >> /mnt/etc/fstab &> /dev/null
}
# Do necessary stuff in chroot - send every command alone
# Thanks to <https://github.com/shagu> its working!
# CHANGE KEYBOARD LAYOUT FOR YOURSELF
four() {
    arch-chroot /mnt /bin/bash -c "echo "KEYMAP=pl_PL" > /etc/vconsole.conf"  &> /dev/null      # Set keyboard layout
    arch-chroot /mnt /bin/bash -c "pacman-key --init && pacman-key --populate archlinux" &> /dev/null
}
five() {
    arch-chroot /mnt /bin/bash -c "pacman -S networkmanager git neovim grub efibootmgr --noconfirm" &> /dev/null
    arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager" &> /dev/null
}
six() {
    arch-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB" &> /dev/null
    arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg" &> /dev/null
}
seven() {
    arch-chroot /mnt /bin/bash -c "mkinitcpio -P -n" &> /dev/null   # -n => dont display colors
}
eight() {
    arch-chroot /mnt /bin/bash -c "sed -i 's/# %wheel/%wheel/g' /etc/sudoers" &> /dev/null
    arch-chroot /mnt /bin/bash -c "sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers" &> /dev/null
}
nine() {
    arch-chroot /mnt /bin/bash -c 'root_password=$(whiptail --title "Set Root Password" --passwordbox "\nEnter new root password:" 10 40 3>&1 1>&2 2>&3); echo "root:$root_password" | chpasswd' &> /dev/tty1
    mv /etc/profile.d/firstboot.sh /mnt/etc/profile.d/

    choice=$(whiptail --title "Choose Branch" --menu "\nChoose the branch of dotfiles:" 11 60 2 \
        "dwm"       "   Minimal, efficient" \
        "qtile"     "   Feature rich, customizable" 3>&1 1>&2 2>&3)

    # Choose branch to clone aka window manager and type of script (qtile = good looking lots of options,
    # dwm = no options, pure efficiency and my configs)
    if [ "$choice" = "qtile" ]; then
        echo "User chose qtile"
        # This "one-liner" took me literally a fucking month, BUT IT WORKS AS IN 06.07.2023!!!
        # everything all at once because username and password are necessary and their scope is in this command only :)
        arch-chroot /mnt /bin/bash -c 'username=$(whiptail --title "Create User" --inputbox "\nEnter username:" 10 40 3>&1 1>&2 2>&3) && password=$(whiptail --title "Create User" --passwordbox "\nEnter password:" 10 40 3>&1 1>&2 2>&3) && clear && useradd -s /bin/zsh -m $username -G wheel && echo -e "$password\n$password" | passwd "$username" && echo "User created!" && cd /home/$username && git clone --single-branch --branch qtile https://github.com/piotr-marendowski/dotfiles.git && chmod +x /etc/profile.d/firstboot.sh && chown -R /home/$username/dotfiles && chmod -R 755 /home/$username/dotfiles' &> /dev/tty1

    elif [ "$choice" = "dwm" ]; then
        echo "User chose dwm"
        arch-chroot /mnt /bin/bash -c 'username=$(whiptail --title "Create User" --inputbox "\nEnter username:" 10 40 3>&1 1>&2 2>&3) && password=$(whiptail --title "Create User" --passwordbox "\nEnter password:" 10 40 3>&1 1>&2 2>&3) && clear && useradd -s /bin/zsh -m $username -G wheel && echo -e "$password\n$password" | passwd "$username" && echo "User created!" && cd /home/$username && git clone --single-branch --branch dwm https://github.com/piotr-marendowski/dotfiles.git && chmod +x /etc/profile.d/firstboot.sh && chown -R /home/$username/dotfiles && chmod -R 755 /home/$username/dotfiles' &> /dev/tty1

    fi

    whiptail --title "Installation complete!" --msgbox "\nAfter reboot you will have \
options to customize and configure your system." 10 40

    reboot_now
}

# number of functions
functions=("one" "two" "three" "four" "five" "six" "seven" "eight" "nine")

one
# show progress bar and execute functions
whiptail --title "Progress" --gauge "\nInstalling the base system... It'll take a few minutes." 7 60 0 < <(
    # Update the gauge
    gauge=$((100 * (1 + 1) / ${#functions[@]}))
    echo "$gauge"

    two
)
whiptail --title "Progress" --gauge "\nGenerating disk layout..." 7 50 0 < <(
    # Update the gauge
    gauge=$((100 * (2 + 1) / ${#functions[@]}))
    echo "$gauge"

    three
)
whiptail --title "Progress" --gauge "\nGenerating pacman keys..." 7 50 0 < <(
    # Update the gauge
    gauge=$((100 * (3 + 1) / ${#functions[@]}))
    echo "$gauge"

    four
)
whiptail --title "Progress" --gauge "\nInstalling programs in chroot..." 7 50 0 < <(
    # Update the gauge
    gauge=$((100 * (4 + 1) / ${#functions[@]}))
    echo "$gauge"

    five
)
whiptail --title "Progress" --gauge "\nConfiguring GRUB..." 7 50 0 < <(
    # Update the gauge
    gauge=$((100 * (5 + 1) / ${#functions[@]}))
    echo "$gauge"

    six
)
whiptail --title "Progress" --gauge "\nRecreating the initramfs image..." 7 50 0 < <(
    # Update the gauge
    gauge=$((100 * (6 + 1) / ${#functions[@]}))
    echo "$gauge"

    seven
)
whiptail --title "Progress" --gauge "\nConfiguring sudo..." 7 50 0 < <(
    # Update the gauge
    gauge=$((100 * (7 + 1) / ${#functions[@]}))
    echo "$gauge"

    eight
)
nine

exit

