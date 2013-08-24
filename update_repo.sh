#!/bin/bash -xe
# Author: Kun Huang <academicgareth@gmail.com>, DennyZhang <denny@unitedstack.com>
# Sample: sudo ./update_repo.sh 127.0.0.1 /opt/repo

server=${1:-192.168.1.5}
repo_dir=${2:-/data1/mirrors/sunfire/RPMS/x86_64/}
mkdir -p repo
cd repo
if [ "$server"="127.0.0.1" ]; then
    rsync -Pr $repo_dir/* .
else
    rsync -Pr root@$server:$repo_dir/* .
fi;
cd ..
