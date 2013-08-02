#!/bin/bash -x
# Author: Kun Huang <academicgareth@gmail.com>

mkdir -p repo
cd repo
rsync -Pr root@192.168.1.5:/data1/mirrors/sunfire/RPMS/x86_64/* .
cd ..
