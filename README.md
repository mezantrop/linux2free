# Remote Linux to FreeBSD upgrade script
## linux2free.sh overwrites your Linux with FreeBSD over SSH connection

Time runs fast, MBR evolved to GPT, BIOS to UEFI and I followed the footsteps 
of good old Depenguinator 
[2.0](https://www.daemonology.net/blog/2008-01-29-depenguinator-2.0.html) and 
[3.0](https://github.com/allanjude/depenguinator) to bring some Christmas magic
to the end of 2021 year.

This is a very early draft, the script abilities are very limited, there are 
a lot things to implement and many bugs to fix, but it ~~runs fine on my laptop~~ 
successfully installs FreeBSD 13.0 over the default CentOS Linux 8 on 
a VirtualBOX machine.

[![linux2free.sh in action](https://img.youtube.com/vi/q8GlmyK70VE/0.jpg)](https://www.youtube.com/watch?v=q8GlmyK70VE)

## NOTES
0. **The script is extremely dangerous, it can easily ruin your OS, data and life.
Do not run it in production or on the system that has any value. You have been warned!**
1. The script can be run on console or via SSH, but network connection required 
anyway, because linux2free.sh downloads files from Internet
2. Currently the linux2free.sh script supports UEFI only boot. Sorry for MBR scheme,
perhaps someday I'll add it (or not)
3. Only Redhat based Linux distributions are supported at the moment. Debian 
will come someday (probably)
4. The resulted FreeBSD system is very minimalistic. It uses a simple custom 
starup scripts to bring up network interfaces and start sshd, you have to 
configure the system and install additional packages yourself
5. linux2free created a boot EFI partition and a small ZFS filesystem for FreeBSD 
to start up, but the rest of the space formerly used by Linux has to be 
redistributed manually.

## Installation

On Linux machine run:
```
sudo dnf upgrade -y
reboot
wget https://raw.githubusercontent.com/mezantrop/linux2free/master/linux2free.sh && sudo bash linux2free.sh
```

## TODO
 - [x] Allow root to ssh in remotely
 - [x] Set default router
 - [ ] Support more Linux distributions
 - [ ] Make the code better (Oh, there are plenty things to do! See TODO remarks over the script body)
 - [ ] Write a more serious README
 - [ ] Import SSH keys as suggested by [PkHolm](https://www.reddit.com/r/freebsd/comments/rpks7e/comment/hq545yh/?utm_source=reddit&utm_medium=web2x&context=3)
 - [ ] Migrate some data from Linux filesystems as [tux2bsd](https://www.reddit.com/user/tux2bsd) suggested


## History
```
2021.12.25    v0.1    Mikhail Zakharov <zmey20000@yahoo.com>
  * Initial version

2021.12.26    v0.2    Mikhail Zakharov <zmey20000@yahoo.com>
  * SSH root login, default route, resolver

2021.12.30    v0.3    Mikhail Zakharov <zmey20000@yahoo.com>
  * Unbind ZFS partition from boot. Thanks https://github.com/click0 for
  https://github.com/mezantrop/linux2free/issues/1

2022.01.02    v0.4    Mikhail Zakharov <zmey20000@yahoo.com>
  * A little less shameful partition detection, yet a lot of things to do
  * bash as potentially more "powerful" interpreter

2022.01.05    v0.5    Mikhail Zakharov <zmey20000@yahoo.com>
  * Better partition detection
  * Better network configuration detection
```

Don't hesitate to enchance, report bugs or call me, 
Mikhail Zakharov <zmey20000@yahoo.com>