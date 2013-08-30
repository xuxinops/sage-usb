#!/bin/bash -xe
# Author: Kun Huang <academicgareth@gmail.com>

sda=$1
sda1="$1""1"
mnt_point=/tmp/usb_hk
mkdir -p $mnt_point
umount $sda1 || true

parted -s $sda mklabel msdos
parted -s $sda mkpart primary 1 100%

dd if=/dev/zero of=$sda bs=512 count=1 # clear partition
echo -ne "n\np\n1\n\n\nw\n" | fdisk $sda # format sdX1
mkfs.ext4 $sda1 # use ext4

parted $sda set 1 boot on
# TODO test
if [ ! -f CentOS-6.4-x86_64-netinstall.iso ];then
    wget http://mirrors.163.com/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-netinstall.iso
fi

./livecd-iso-to-disk.sh ./CentOS-6.4-x86_64-netinstall.iso $sda1
dd conv=notrunc bs=440 count=1 if=mbr.bin of=$sda
e2label $sda1 ustack-usb

mount $sda1 $mnt_point

uuid=`sudo blkid -s UUID -o value $sda1`
method=""

cat >./extlinux.conf <<EOF
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
append initrd=initrd.img text stage2=hd:UUID=$uuid:/images/install.img ip=static ks=hd:UUID=$uuid:/node.ks repo=hd:UUID=$uuid:/os
EOF

rsync -P ./extlinux.conf $mnt_point/syslinux/

mkdir $mnt_point/repo
rsync -Pr ./repo/* $mnt_point/repo/

mkdir -p $mnt_point/os
if [ ! -f CentOS-6.4-x86_64-minimal.iso ];then
    wget http://mirrors.163.com/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-minimal.iso
fi
rsync -Pr CentOS-6.4-x86_64-minimal.iso $mnt_point/os/

rm $mnt_point/images/install.img
rsync -P ./images/install.img $mnt_point/images/

rm $mnt_point/syslinux/initrd.img
rsync -P ./images/initrd.img $mnt_point/syslinux/

rsync -P node.ks $mnt_point/node.ks

sync

umount $sda1
