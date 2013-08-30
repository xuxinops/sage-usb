#!/bin/bash -xe
# Author: Kun Huang <academicgareth@gmail.com>, DennyZhang <denny@unitedstack.com>
if [ ! -f CentOS-6.4-x86_64-minimal.iso ]; then
    wget http://mirrors.163.com/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-minimal.iso
fi
isodir=iso
testdir=test
rm -rf $isodir
mkdir -p $isodir

# copy the image data
mkdir -p $testdir
umount $testdir || true # defensive code for retry after some exceptions
mount CentOS-6.4-x86_64-minimal.iso $testdir -o loop
rsync -rP $testdir/* $isodir/
rsync -P $testdir/.discinfo $isodir/
rsync -P $testdir/.treeinfo $isodir/
umount $testdir

# copy repo and node.ks
rsync -rP repo $isodir/
rsync -rP node.ks $isodir/

# use custom install.img and initrd.img
mv $isodir/images/install.img $isodir/images/install.img.bak
rm -rf $isodir/images/*.img
rsync -P images/install.img $isodir/images/

rm -rf $isodir/isolinux/initrd.img
rsync -P images/initrd.img $isodir/isolinux/


# modify the isolinux.cfg
cat >./isolinux.cfg<<EOF
default vesamenu.c32
#prompt 1
timeout 60

display boot.msg

menu background splash.jpg
menu title Welcome to uStack OS!
menu color border 0 #ffffffff #00000000
menu color sel 7 #ffffffff #ff000000
menu color title 0 #ffffffff #00000000
menu color tabmsg 0 #ffffffff #00000000
menu color unsel 0 #ffffffff #00000000
menu color hotsel 0 #ff000000 #ffffffff
menu color hotkey 7 #ffffffff #ff000000
menu color scrollbar 0 #ffffffff #00000000

label linux
menu label ^Install uStack OS!
menu default
kernel vmlinuz
append initrd=initrd.img text ks=cdrom:/node.ks
EOF

rsync -P ./isolinux.cfg $isodir/isolinux/isolinux.cfg

# make iso
mkisofs -o uOS.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T -V "UnitedStack uOS 1.0" $isodir/
sync
