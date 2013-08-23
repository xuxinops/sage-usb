#!/bin/bash -x
# Author: Kun Huang <academicgareth@gmail.com>, DennyZhang <denny@unitedstack.com>

server=${1:-192.168.1.5}
repo_dir=${2:-/data1/mirrors/sunfire/RPMS/x86_64/}
mkdir -p repo
cd repo
rsync -Pr root@$server:$repo_dir/* .
cd ..
