# Linux to FreeBSD upgrade script
## linux2free.sh overwrites your Linux with FreeBSD

Time runs fast, MBR evolved to GPT, BIOS to UEFI and I followed the footsteps 
of good old Depenguinator 
([2.0]https://www.daemonology.net/blog/2008-01-29-depenguinator-2.0.html and 
[3.0]https://github.com/allanjude/depenguinator) to bring some Christmas magic
to the end of 2021 year.

This is a very early draft, the script abilities are very limited, there are 
a lot things to implement and many bugs to fix, but it ~~runs fine on my laptop~~ 
successfully installs FreeBSD 13.0 over the default CentOS Linux 8 on 
a VirtualBOX machine.

## NOTES
0. *The script is extremely dangerous, it can easily ruin your OS, data and life.
Do not run it in production or on the system that has any value. You have been warned!*
1. Network connection required: linux2free.sh downloads files from Internet
2. Currently the linux2free.sh script supports UEFI only boot. Sorry for MBR scheme,
perhaps someday I'll add it (or not)
3. The resulted FreeBSD system is very minimalistic. It uses a simple custom 
starup scripts to bring up network interfaces and start sshd, you have to 
configure the system and install additional packages yourself.
4. linux2free created a boot EFI partition and a small ZFS filesystem for FreeBSD 
to start up, but the rest of the space formerly used by Linux has to be 
redistributed manually.

## Installation

`wget https://raw.githubusercontent.com/mezantrop/linux2free/master/linux2free.sh && sudo sh linux2free.sh`

## TODO
[x] Allow root to ssh in remotely
[x] Set default router
[ ] Support more Linux distributions
[ ] Make the code better (Oh, there are plenty things to do! See TODO remarks over the script body)

## History
```
2021.12.25  v0.1    Mikhail Zakharov <zmey20000@yahoo.com>  Initial version
2021.12.26  v0.2    Mikhail Zakharov <zmey20000@yahoo.com>  SSH root login, default route, resolver
```

Don't hesitate to enchance, report bugs or call me, 
Mikhail Zakharov <zmey20000@yahoo.com>