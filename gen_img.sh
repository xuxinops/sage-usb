#!/bin/bash -x
# Author: Kun Huang <academicgareth@gmail.com>

mkdir -p images
cd images
if [ ! -f install.img ];then
    wget http://mirrors.163.com/centos/6.4/os/x86_64/images/install.img
fi
if [ ! -f initrd.img ];then
    wget http://mirrors.163.com/centos/6.4/os/x86_64/isolinux/initrd.img
fi
# TODO: check status
md5sum -c md5.txt
