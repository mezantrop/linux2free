#!/bin/sh

# ---------------------------------------------------------------------------- #
# linux2free v0.1 - Linux to FreeBSD upgrade script                            #
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
# 2021.12.25  v0.1    Mikhail Zakharov  Initial version
# 2021.12.26  v0.2    Mikhail Zakharov  SSH root login, default route, resolver
# ---------------------------------------------------------------------------- #

trap "exit 1" TERM
export L2FPID=$$

# -- Useful functions -------------------------------------------------------- #
die() { printf "$@"; kill -s TERM $L2FPID; }
printl() { [ $verbose -eq 1 ] && printf "$@"; }

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
    mkfs.fat -s 1 "/dev/$efi_disk"
    mkdir "$freebsd_efi" && mount -t msdos "/dev/$efi_disk" "$freebsd_efi"
    mkdir -p "$freebsd_efi"/EFI/BOOT

    # Create ZFS
    mkdir "$freebsd_zfs"
    /sbin/modprobe zfs
    zpool create -f -o altroot="$freebsd_zfs" zroot $boot_disk
    
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
    wget -O - https://download.freebsd.org/ftp/releases/amd64/"$freebsd_release"/base.txz | tar Jxvf -
    wget -O - https://download.freebsd.org/ftp/releases/amd64/"$freebsd_release"/kernel.txz | tar Jxvf -

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

    chmod 755 "$freebsd_zfs"/etc/rc.local
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
    touch "$freebsd_zfs"/etc/fstab

}

do_debian() {
    # TODO: Implement someday
    die "Debian linux family is not supported yet"
:
}

do_redhat() {
    # Install ZFS packages
    for m in `seq 10 -1 1`; do
        dnf -y install https://zfsonlinux.org/epel/zfs-release$(rpm -E %dist)_$m.noarch.rpm && break
    done
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
    dnf install -y epel-release
    dnf install -y kernel-devel
    dnf install -y zfs

    # Snip network parameters
    # TODO: utilize chk_cmd() to select either ip or ifconfig in the future 
    iface_name=`ip route show default | awk '/default/ {print $5}'`
    deftrouter=`ip route show default | awk '/default/ {print $3}'`
    iface_ipv4=`ifconfig $iface_name | awk '$1 == "inet" {print $2}'`
    iface_ipv6=`ifconfig $iface_name | awk '$1 == "inet6" {print $2; exit 0}'`
    iface_mac=`cat /sys/class/net/"$iface_name"/address`

    install_freebsd  
}


# ---------------------------------------------------------------------------- #
verbose=1
freebsd_space=536870912                 # 512MB
freebsd_release="13.0-RELEASE"
freebsd_efi="/freebsd.efi"
freebsd_zfs="/freebsd.zfs"

[ `id -u` -ne 0 ] && die "FATAL: You must run the script as root\n"

chk_cmd awk "awk gawk" || die "FATAL: Unable to find awk\n"

# Find a suitable partition on the first disk.
# BEWARE: There are a lot of silly assumptions. Proceed with caution!
# TODO:
# 1. Make disk/partitions identification more intelligent 
# 2. Rewrite the ugly code (mainly the awk blotches) into something more elegant

# Find ONLY the very first disk device name
disk_name=`lsblk -b -n -o KNAME,TYPE | awk '$2 ~ /disk/ {print $1; exit 0}'`
# Partition candidates
part_data=`lsblk -b -n -o KNAME,TYPE,SIZE,FSTYPE,MOUNTPOINT,PARTLABEL | 
    awk '$2 ~ /part/ && $4 !~ /LVM/ {print}'`
# EFI
part_efi=`printf "%s\n" "$part_data" |
    awk 'BEGIN {IGNORECASE=1}; $6 ~ /efi/||/esp/ {print}'`
[ "$part_efi" == "" ] && die "FATAL: Only systems with EFI/ESP supported\n"
efi_disk=`printf "%s\n" "$part_efi" | awk '{print $1}'`
efi_partn=`printf "%s\n" "$efi_disk" | awk -v d="$disk_name" 'BEGIN {FS=d"| "} {print $2}'`
efi_size=`printf "%s\n" "$part_efi" | awk '{print $3}'`
[ ! $efi_size ] && efi_size=0
# BOOT
part_boot=`printf "%s\n" "$part_data" | awk '$5 == "/boot" {print}'`
boot_disk=`printf "%s\n" "$part_boot" | awk '{print $1}'`
boot_partn=`printf "%s\n" "$boot_disk" | awk -v d="$disk_name" 'BEGIN {FS=d"| "} {print $2}'`
boot_size=`printf "%s\n" "$part_boot" | awk '{print $3}'`
[ ! $boot_size ] && boot_size=0
# SWAP
part_swap=`printf "%s\n" "$part_data" | awk '$4 == "swap" {print}'`
swap_disk=`printf "%s\n" "$part_swap" | awk '{print $1}'`
swap_partn=`printf "%s\n" "$swap_disk" | awk -v d="$disk_name" 'BEGIN {FS=d"| "} {print $2}'`
swap_size=`printf "%s\n" "$part_swap" | awk '{print $3}'`
[ ! $swap_size ] && swap_size=0
# Calculate potential free space
target_space=`expr $efi_size + $boot_size + $swap_size`
[ $target_space -lt $freebsd_space ] && die "FATAL: Not enough room for ZFS\n"

# If exist, umount/swapoff and delete partitions
# TODO: use chk_cmd() to select fdisk/parted/etc 
[ $efi_disk ] && umount "/dev/$efi_disk"
[ $boot_disk ] && umount "/dev/$boot_disk"
[ $part_swap ] && swapoff "/dev/$part_swap"
for p in $efi_partn $boot_partn $swap_partn; do
    [ $p ] && printf "d\n$p\nw\n" | fdisk "/dev/$disk_name"
done

# Create new partitions: EFI and FreeBSD ZFS
printf "n\n$efi_partn\n\n+10M\nt\n$efi_partn\n1\nw\n" "$efi_partn" "$efi_partn" |
    fdisk "/dev/$disk_name"
printf "n\n$boot_partn\n\n\nt\n$boot_partn\n36\nw\n" "$boot_partn" "$boot_partn" |
    fdisk "/dev/$disk_name"

# Identify a Linux distribution we are running on
chk_cmd hostnamectl hostnamectl || die "FATAL: Unable to find hostnamectl\n"
[ ! $release_name ] && 
    release_name=`$hostnamectl | $awk -F ': ' '/Operating System/ {print $2}'`
printl "release_name=%s\n" "$release_name"
[ ! $release_family ] && chk_os release_family "$release_name"
printl "release_family=%s\n" "$release_family"

# Install the stuff
case "$release_family" in
    debian) do_debian ;;
    redhat)
        chk_cmd dnf "dnf yum" || die "FATAL: Unable to find DNF packet manager\n"
        do_redhat ;;
esac

printf "\nPress ENTER to reboot into FreeBSD or hit ^C if you forgot something!\n"
printf "Think twice, this might be your last chance to do it!\n"
read
reboot
