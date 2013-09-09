#!/bin/bash -xe
# Author: Kun Huang <academicgareth@gmail.com>, DennyZhang <denny@unitedstack.com>, Xin Xu <xuxin@unitedstack.com>
# Sample: sudo ./update_repo.sh 127.0.0.1 local /opt/repo
# Sample: sudo ./update_repo.sh 192.168.1.5 remote urepo

server=${1:-192.168.1.5}
sync_src=${3:-urepo}
sync_method=${2:-remote}

repos='sunfire storm ustack'

case $sync_method in
    'remote')
        method="rsync -aP root@${server}::$sync_src/"
        ;;
    'local')
        method="rsync -aP $sync_src/"
        ;;
    *)
        echo 'unknow method, only support remote and local method'
        exit 1;
        ;;
esac

for i in $repos
do
    src_dir=${i}'/RPMS/x86_64'
    tgt_dir='repo/'${i}
    mkdir -p ${tgt_dir}
    ${method}${src_dir}/ ${tgt_dir}/
done

