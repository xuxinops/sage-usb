#!/bin/bash -x
# Author: Kun Huang <academicgareth@gmail.com>

mkdir -p images
cd images
pwd
if [ ! -f install.img ];then
    wget http://mirrors.163.com/centos/6.4/os/x86_64/images/install.img
fi
rm -rf test_iso
mkdir -p test_iso
if [ ! -f ../CentOS-6.4-x86_64-netinstall.iso ];then
    wget http://mirrors.163.com/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-netinstall.iso
fi
mount ../CentOS-6.4-x86_64-netinstall.iso test_iso
rsync -P test_iso/isolinux/initrd.img .
umount test_iso
rm -rf test_iso
