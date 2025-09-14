---
layout: post
title:  "Boot NixOS with Extlinux"
date:   2025-09-14 18:20:25 +0800
categories: NixOS
---
There are only 8 RAID slots in my dev server. Hence I use external disks on USB for OS. But it is a very old machine (BIOS), which does not support USB HDD, or Grub2. I used to have a USB thumb drive to hold OS and a manually maintained Syslinux configuration to boot.

Recently it was full, due to the huge Nix store. Spending a few days trying to migrate the store to a new USB thumb drive resulting in something broken.

So I got a 3TiB USB HDD and a 8GiB USB thumb drive to install a whole new system.

While I was using the old configuration.nix (installing grub2), I noticed that there is an option, `boot.loader.generic-extlinux-compatible.enable`, which generates a directly usable extlinux.conf. This certainly is much better than I editing and copying those configurations. Therefore I disabled Grub2 and made following steps:

```
mount /dev/disks/by-label/root /mnt -onoatime,nodiratime
mkdir /mnt/boot
mount /dev/disks/by-label/boot /mnt/boot -onoatime,nodiratime
nixos-generate-config --root /mnt
nixos-install
# extlinux.conf appears in /mnt/boot/extlinux/
find /nix/store -name mbr.bin
dd if="${MBR_BIN_PATH}" of=/dev/sda bs=440 count=1
extlinux -i /mnt/boot
(cd /mnt/boot && ln -s extlinux/extlinux.conf .)
```

This should do it. But I failed. It did not boot at all. No matter how I confirmed my process and verified in VirtualBox. At last, I replaced the boot device to another USB thumb drive and it all worked. Seems like the original one hardware is broken.