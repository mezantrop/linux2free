#!/bin/bash

# ---------------------------------------------------------------------------- #
# linux2free.sh - Linux to FreeBSD upgrade script                                 #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
#         !!!  EXTREMLY DANGEROUS! DO NOT TRY THIS IN PRODUCTION!  !!!         #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# "THE BEER-WARE LICENSE" (Revision 42):                                       #
# <zmey20000@yahoo.com> wrote this file. As long as you retain this notice you #
# can do whatever you want with this stuff. If we meet some day, and you think #
# this stuff is worth it, you can buy me a beer in return.    Mikhail Zakharov #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
script_name="linux2free.sh"; script_version="0.6"

trap "exit 1" TERM
export L2FPID=$$

# -- Useful functions -------------------------------------------------------- #
die() { printf "$@"; kill -s TERM $L2FPID; }
printl() { [ $verbose -eq 1 ] && printf "$@"; }

usage() {
    printf "Usage:\n\t%s [-d /dev/drive] [-R XX.Y] [-hv]\n\n" "$script_name"
    printf "Where:\n"
    printf "\t-d\tDevice filename, e.g: /dev/sda\n"
    printf "\t-R\tFreeBSD release, e.g: 13.0. Be careful with old releases\n" 
    printf "\t\twhich may not boot because of ZFS and/or EFI compatibility!\n"
    printf "\t-h\tPrint this message\n"
    printf "\t-v\tShow the script version\n\n"
    [ $1 ] && exit $1 || exit 0
}

chk_cmd() {
    for c in `printf "%s\n" "$*" | cut -d " " -f 2-100`; do
        cmd=`which "$c" 2> /dev/null`
        printl "%s=\"%s\"\n" "$1" "$cmd"

        [ "$cmd" ] && { eval $1='$cmd'; return 0; }
    done
    return 1
}

chk_os() {
    # Return release family by $2
    [ "$1" -a "$2" ] || die "FATAL: Wrong chk_os() usage\n"
    case "$2" in
        *[cC][eE][nN][tT][oO][sS]*)     eval $1='redhat'   ;;
        *[fF][eE][dD][oO][rR][aA]*)     eval $1="redhat"   ;;
        *[rR][eE][dD]*[hH][aA][tT]*)    eval $1="redhat"   ;;
        *[dD][eE][bB][iI][aA][nN]*)     eval $1="debian"   ;;
        *[uU][bB][uU][nN][tT][uU]*)     eval $1="debian"   ;;
        *)  die "FATAL: Unsupported release name: %s\n" "$2" ;;
    esac
}

install_freebsd() {
    # Create EFI filesystem
    mkfs.fat -s 1 "/dev/$efi_p_nme"
    mkdir "$freebsd_efi" && mount -t msdos "/dev/$efi_p_nme" "$freebsd_efi"
    mkdir -p "$freebsd_efi"/EFI/BOOT

    # Create ZFS
    mkdir "$freebsd_zfs"
    /sbin/modprobe zfs

    mkpool="zpool create -f -o altroot=$freebsd_zfs $zfs_options zroot $zpool_p_nme"
    $mkpool

    zfs set compression=on zroot
    zfs create -o mountpoint=none zroot/ROOT
    zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/default

    zfs mount zroot/ROOT/default

    # Build FreeBSD directory structure
    mkdir -p "$freebsd_zfs"/usr
    mkdir -p "$freebsd_zfs"/usr/home
    mkdir -p "$freebsd_zfs"/usr/src
    mkdir -p "$freebsd_zfs"/usr/obj
    mkdir -p "$freebsd_zfs"/usr/ports
    mkdir -p "$freebsd_zfs"/usr/ports/distfiles
    mkdir -p "$freebsd_zfs"/ports/packages
    mkdir -p "$freebsd_zfs"/var
    mkdir -p "$freebsd_zfs"/var/audit
    mkdir -p "$freebsd_zfs"/var/crash
    mkdir -p "$freebsd_zfs"/var/log
    mkdir -p "$freebsd_zfs"/var/mail
    mkdir -p "$freebsd_zfs"/var/tmp

    ln -s /usr/home "$freebsd_zfs"/home
    chmod 1777 "$freebsd_zfs"/var/tmp
    chmod 1777 "$freebsd_zfs"/tmp

    zpool set bootfs=zroot/ROOT/default zroot
    # Download/unpack FreeBSD base and kernel sets 
    cd "$freebsd_zfs"
    wget -O - "$freebsd_downloads/$freebsd_release-RELEASE/base.txz" | tar Jxvf -
    wget -O - "$freebsd_downloads/$freebsd_release-RELEASE/kernel.txz" | tar Jxvf -

    # Install boot EFI loader and configure basic startup scripts
    cp "$freebsd_zfs"/boot/loader.efi "$freebsd_efi"/EFI/BOOT/BOOTX64.efi

    echo zfs_load="YES" >> "$freebsd_zfs"/boot/loader.conf

    echo hostname="fbsd" >> "$freebsd_zfs"/etc/rc.conf
    echo zfs_enable="YES" >> "$freebsd_zfs"/etc/rc.conf
    echo sshd_enable="YES" >> "$freebsd_zfs"/etc/rc.conf
    echo sendmail_msp_queue_enable="NO" >> "$freebsd_zfs"/etc/rc.conf
    echo sendmail_outbound_enable="NO" >> "$freebsd_zfs"/etc/rc.conf

    echo UseDNS no >> "$freebsd_zfs"/etc/ssh/sshd_config
    echo UsePAM no >> "$freebsd_zfs"/etc/ssh/sshd_config
    echo PermitRootLogin yes >> "$freebsd_zfs"/etc/ssh/sshd_config
    echo PermitEmptyPasswords yes >> "$freebsd_zfs"/etc/ssh/sshd_config
    echo PasswordAuthentication yes >> "$freebsd_zfs"/etc/ssh/sshd_config
    cp /etc/resolv.conf "$freebsd_zfs"/etc
    
    efibootmgr -c -l '\EFI\BOOT\bootx64.efi' -L FreeBSD

    # Configure network interfaces
    # TODO: Add default routing, I forgot about, he-he-he, ouch :( 
    cat << EOF > "$freebsd_zfs"/etc/rc.local
    #!/bin/sh

    iface_mac=$iface_mac
    iface_ipv4=$iface_ipv4
    iface_ipv6=$iface_ipv6

    for i in \`ifconfig -l\`; do
        [ "\$i" != "lo0" ] && 
            ifconfig | grep $iface_mac && {
                ifconfig \$i inet $iface_ipv4
                ifconfig \$i inet6 $iface_ipv6
            }
    done

    route add default $deftrouter
EOF
    chmod 755 "$freebsd_zfs"/etc/rc.local
    touch "$freebsd_zfs"/etc/fstab
}

do_debian() {
    # TODO: Implement someday
    die "Debian linux family is not supported yet"
}

do_redhat() {
    dnf upgrade -y  # We must be sure to have Kernel and ZFS modules in sync!

    # Install ZFS packages
    for m in `seq 10 -1 1`; do
        dnf -y install $zfsonlinux_download$(rpm -E %dist)_$m.noarch.rpm && break
    done
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
    dnf install -y epel-release
    dnf install -y kernel-devel
    dnf install -y zfs

    # Snip network parameters
    iface_name=`ip route show default | awk '/default/ {print $5}'`
    deftrouter=`ip route show default | awk '/default/ {print $3}'`
    iface_ipv4=`ip -4 address show "$iface_name" | awk '$1 == "inet" {print $2}'`
    iface_ipv6=`ip -6 address show "$iface_name" | awk '$1 == "inet6" {print $2; exit 0}'`
    iface_mac=`ip link show "$iface_name" | awk '/ether/ {print $2}'`
# TODO: utilize chk_cmd() to switch between ip/netstat/ifconfig
#    iface_name=`netstat -nr | awk '$1 == "0.0.0.0" || $1 == "Default" {print $8}'`
#    iface_ipv4=`ifconfig $iface_name | awk '$1 == "inet" {print $2}'`
#    iface_ipv6=`ifconfig $iface_name | awk '$1 == "inet6" {print $2; exit 0}'`
#    iface_mac=`cat /sys/class/net/"$iface_name"/address`
#    iface_mac=`ifconfig enp0s3 |awk '$1 == "ether" {print $2}'`

    install_freebsd  
}

# ---------------------------------------------------------------------------- #
verbose=1
freebsd_total_space=512         # 512M for kernel + base
freebsd_efi_space=10            # 10M for EFI loader

freebsd_downloads="https://download.freebsd.org/ftp/releases/amd64"

freebsd_release="13.0"          # Set this to the current release version!
freebsd_efi="/freebsd.efi"
freebsd_zfs="/freebsd.zfs"

zfsonlinux_download="https://zfsonlinux.org/epel/zfs-release"

zfs_options=""                  # Additional ZFS options

[  "$#" -gt 4 ] && usage 1
while getopts "d:R:hv" opt; do
    case "$opt" in
        d)
            sys_d_nme=`basename "$OPTARG"`
            [ "`lsblk -l /dev/$sys_d_nme`" ] || 
                die "FATAL: Unable to install FreeBSD on: /dev/$sys_d_nme\n"
            ;;
        R)
            [ "$OPTARG" != "$freebsd_release" ] && zfs_options=' -o version=28 '
            freebsd_release="$OPTARG" ;;
        v) 
            printf "%s v.%s\n" "$script_name" "$script_version"; exit 0 ;;
        h)
            usage 0 ;;
        *)
            usage 1 ;;
    esac
done

[ `id -u` -ne 0 ] && die "FATAL: You must run the script as root\n"

chk_cmd awk "awk gawk" || die "FATAL: Unable to find awk\n"

# Find a first drive with EFI partition to work on
# BEWARE: There are a lot of silly assumptions. Proceed with caution!
# TODO: Make disk/partitions identification more intelligent (again)
while read KNAME TYPE SIZE FSTYPE MOUNTPOINT PARTLABEL; do
    grep -q -i "EFI" <<< "$PARTLABEL" && {                  # EFI Partition
        efi_p_nme="$KNAME"                                  # Part name
        efi_p_siz="$SIZE"                                   # Part size
        efi_d_nme="${efi_p_nme%[0-9]}"                      # Disk name
        [ "$sys_d_nme" ] || sys_d_nme="$efi_d_nme"          # "Boot" disk name
        efi_p_num="${efi_p_nme#$sys_d_nme}"
        continue
    }
    [ "$MOUNTPOINT" == '/boot' ] && {                       # BOOT
        boot_p_nme="$KNAME"
        boot_p_siz="$SIZE"
        boot_d_nme="${boot_p_nme%[0-9]}"
        [ "$boot_d_nme" != "$sys_d_nme" ] && 
            die "FATAL: Boot: %s is not on the same drive with EFI: %s\n" \
                "$boot_d_nme" "$sys_d_nme"
        boot_p_num="${boot_p_nme#$boot_d_nme}"
        continue
    }
    [ "$FSTYPE" == 'swap' ] && {                            # SWAP
        swap_p_nme="$KNAME"
        swap_p_siz="$SIZE"
        swap_d_nme="${swap_p_nme%[0-9]}"
        [ "$swap_d_nme" != "$sys_d_nme" ] && 
            die "FATAL: Swap: %s is not on the EFI drive: %s\n" \
                "$swap_d_nme" "$sys_d_nme"
        swap_p_num="${swap_p_nme#$swap_d_nme}"
        continue
    }
done < <(( [ "$sys_d_nme" ] &&
    lsblk -b -n -o KNAME,TYPE,SIZE,FSTYPE,MOUNTPOINT,PARTLABEL /dev/"$sys_d_nme" ||
    lsblk -b -n -o KNAME,TYPE,SIZE,FSTYPE,MOUNTPOINT,PARTLABEL) | 
    awk '$2 ~ /part/ && $4 !~ /LVM/')

[ $efi_p_nme ] || die "FATAL: Only systems with EFI/ESP are supported\n"

printl "UEFI partition name: [%s], size: [%s], disk: [%s], number: [%s]\n" \
    "$efi_p_nme" "$efi_p_siz" "$efi_d_nme" "$efi_p_num"
printl "BOOT partition name: [%s], size: [%s], disk: [%s], number: [%s]\n" \
    "$boot_p_nme" "$boot_p_siz" "$boot_d_nme" "$boot_p_num"
printl "SWAP partition name: [%s], size: [%s], disk: [%s], number: [%s]\n" \
    "$swap_p_nme" "$swap_p_siz" "$swap_d_nme" "$swap_p_num"

# Calculate potential free space
dest_space=`expr '(' $efi_p_siz + ${boot_p_siz=0} + ${swap_p_siz=0} ')' '/' 1048576`
[ $dest_space -lt $freebsd_total_space ] && die "FATAL: Not enough disk space\n"

# If exist, umount/swapoff and delete partitions
# TODO: use chk_cmd() to select fdisk/parted/etc 
[ $efi_p_nme ] && umount "/dev/$efi_p_nme"
[ $boot_p_nme ] && umount "/dev/$boot_p_nme"
[ $swap_p_nme ] && swapoff "/dev/$swap_p_nme"
for p in $efi_p_num $boot_p_num $swap_p_num; do
   [ $p ] && printf "d\n$p\nw\n" | fdisk "/dev/$sys_d_nme"
done

# Create new partitions: EFI and ZFS pool
printf "n\n%s\n\n+%sM\nt\n%s\n1\nw\n" "$efi_p_num" "$freebsd_efi_space" "$efi_p_num" |
    fdisk "/dev/$sys_d_nme"
zpool_p_num=`printf "n\n\n\n\nw\n" | fdisk "/dev/$sys_d_nme" | 
    awk '/^Created a new partition/ {print $5}'`
zpool_p_nme="$sys_d_nme""$zpool_p_num"
printf "t\n%s\n36\nw\n" "$zpool_p_num" | fdisk "/dev/$sys_d_nme"

# Identify a Linux distribution we are running on
chk_cmd hostnamectl hostnamectl || die "FATAL: Unable to find hostnamectl\n"
[ ! $release_name ] && 
    release_name=`$hostnamectl | $awk -F ': ' '/Operating System/ {print $2}'`
printl "release_name=%s\n" "$release_name"
[ ! $release_family ] && chk_os release_family "$release_name"
printl "release_family=%s\n" "$release_family"

# Install the stuff
case "$release_family" in
    debian) 
        do_debian ;;
    redhat)
        chk_cmd dnf "dnf yum" || die "FATAL: Unable to find DNF packet manager\n"
        do_redhat ;;
esac

printf "\nPress ENTER to reboot into FreeBSD or hit ^C if you forgot something!\n"
printf "Think twice, this might be your last chance to do it!\n\n"

grep -q -i "version=28" <<< "$zfs_options" && 
    printf "Note, zpool is created with basic options for compatibility.\n"\
"Don\'t forget to run: zpool upgrade -a\n"
read
reboot
