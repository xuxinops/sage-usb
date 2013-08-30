#!/bin/bash -xe
# Author: Kun Huang <academicgareth@gmail.com>, DennyZhang <denny@unitedstack.com>
# Sample: sudo ./update_repo.sh 127.0.0.1 /opt/repo

server=${1:-192.168.1.5}
sunfire_dir=${2:-/data1/mirrors/sunfire/RPMS/x86_64}
storm_dir=${2:-/data1/mirrors/storm/RPMS/x86_64}
ustack_dir=${2:-/data1/mirrors/ustack/RPMS/x86_64}
mkdir -p repo/storm
mkdir -p repo/sunfire
mkdir -p repo/ustack

cd repo
if [ "$server" = "127.0.0.1" ]; then
    rsync -Pr $sunfire_dir/* sunfire/
    rsync -Pr $storm_dir/* storm/
    rsync -Pr $ustack_dir/* ustack/
else
    rsync -Pr root@$server:$sunfire_dir/* sunfire/
    rsync -Pr root@$server:$storm_dir/* storm/
    rsync -Pr root@$server:$ustack_dir/* ustack/
fi;
cd ..
