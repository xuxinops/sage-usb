#!/bin/bash
# Author: Kun Huang <academicgareth@gmail.com>

mkdir -p images
cd images
wget http://mirrors.163.com/centos/6.4/os/x86_64/images/install.img
rm -rf test_iso
mkdir -p test_iso
mount ../CentOS-6.4-x86_64-netinstall.iso test_iso
rsync -P test_iso/isolinux/initrd.img .
umount test_iso
rm -rf test_iso
