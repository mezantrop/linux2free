# Remote Linux to FreeBSD upgrade script

<a href="https://www.buymeacoffee.com/mezantrop" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

l2f.sh script does the following:
1. Downloads from Internet and installs OpenZFS packages on the Linux machine
2. Finds a space that can be freed and creates a ZFS-pool on the drive
3. Downloads and extracts _base_ and _kernel_ FreeBSD distributions
4. Creates minimalistic custom FreeBSD configuration, sufficient for subsequent SSH connection
5. Installs FreeBSD EFI loader and creates a corresponding UEFI entry
6. Reboots the machine into FreeBSD

**Warning! Do not try l2f.sh on production and on any system that has any value.
This is an early draft of the script. It contains bugs and can make your remote
server unusable, destroy your OS, data and ruin entire life.**

[![l2f.sh in action](https://img.youtube.com/vi/q8GlmyK70VE/0.jpg)](https://www.youtube.com/watch?v=q8GlmyK70VE)

## Features, limitations and notes
* Supports UEFI only machines with recent Redhat and Debian distribution families 
including Centos 8, Debian 11 and Ubuntu 21.10
* l2f.sh can run on console or via SSH. Network connection is required to 
downloads distribution and package files from internet
* l2f.sh creates a boot EFI partition and a small ZFS filesystem for FreeBSD
to start up. The rest of the space, formerly used by Linux, has to be 
redistributed manually. FreeBSD has to be configured, as well as, additional
dist files / packages must be installed manually

## Usage
On Linux machine run:
```
wget https://raw.githubusercontent.com/mezantrop/linux2free/master/l2f.sh && sudo bash l2f.sh
```

## TODO
 - [ ] Import SSH keys as suggested by [PkHolm](https://www.reddit.com/r/freebsd/comments/rpks7e/comment/hq545yh/?utm_source=reddit&utm_medium=web2x&context=3)
 - [ ] Migrate some data from Linux filesystems as [tux2bsd](https://www.reddit.com/user/tux2bsd) suggested

## Similar projects
* Depenguinator [2.0](https://www.daemonology.net/blog/2008-01-29-depenguinator-2.0.html) and [3.0](https://github.com/allanjude/depenguinator)
* [mfsBSD / mfslinux](https://mfsbsd.vx.sk)

Don't hesitate to enhance, report bugs or call me, 
Mikhail Zakharov <zmey20000@yahoo.com>
