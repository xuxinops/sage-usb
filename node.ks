#version=DEVEL
install
lang en_US.UTF-8
keyboard us
network --onboot yes --device eth0 --bootproto static --hostname m1
rootpw  --iscrypted $6$khisXn4dB6eUgWT6$jA/uAPvJP0brDVqhr/BKpx8l7AQ4EJr36e0tHH/J4iPMs9h5oR5B.EzgzB1e8L9ZZkzGnbK9jISQ21YM5zUC40
firewall --disable
authconfig --enableshadow --passalgo=sha512
selinux --disable
timezone --utc America/New_York
zerombr

%include /tmp/part-include
%include /tmp/repo-include

%pre --interpreter /usr/bin/python --log=/tmp/pre0.log
import os
if os.path.exists('/dev/disk/by-label/ustack-usb'):
    line = 'repo --name=uOS --baseurl=file:/tmp/ustack-usb/repo'
else:
    line = 'repo --name=uOS --baseurl=file:/mnt/source/repo'
with open('/tmp/repo-include', 'w') as f:
    f.write(line + '\n')
%end

%pre --log=/tmp/pre1.log
mkdir /tmp/ustack-usb
mount -L ustack-usb /tmp/ustack-usb

adp=`MegaCli -adpCount | grep -i controller | awk '{print $3}'`
if [[ $adp = 0* ]];then
    pylsi raid -d
    pylsi raid -r 9
else
    pymega raid -d
    pymega raid -r 9
fi
%end

%pre --interpreter /usr/bin/python --log=/tmp/pre2.log --erroronfail
import os
path = '/sys/block/'

def disk(sda):
    if sda.startswith('sd'):
        return True
    if sda.startswith('vd'):
        return True
    if sda.startswith('hd'):
        return True

def removable(sda):
    rm = os.path.join(path, sda, 'removable')
    with open(rm) as f:
        ret = f.read().strip()
        if ret == '0':
            return False
        elif ret == '1':
            return True
    raise ValueError('unexcepted value of removable')

def size(sda):
    sz = os.path.join(path, sda, 'size')
    with open(sz) as f:
        ret = f.read().strip()
        if int(ret) >= 83886080:
            return True
        else:
            return False

def number(sda, ptype):
    if ptype in ['raid', 'pv']:
        return ptype[0] + sda
    raise ValueError('only raid/pv are acceptable')

ret = [i for i in os.listdir(path) if disk(i)]
ret = [i for i in ret if not removable(i)]
ret = [i for i in ret if size(i)]
spares = max((len(ret) - 3), 0)

f = open('/tmp/part-include', 'w')
f.write('clearpart --all --initlabel\n')

if len(ret) >= 2:
    # raid on /
    raids = ''
    for sda in ret:
        raid = 'raid.r' + number(sda, 'raid')
        rule = 'part %s --size=2000 --ondisk=%s' % (raid, sda)
        f.write(rule + '\n')
        raids += raid + ' '

    rule = 'raid / --level=1 --device=md0 %s --fstype=ext4 --spares=%d' % (raids, spares)
    f.write(rule + '\n')

    # raid on /boot
    raids = ''
    for sda in ret:
        raid = 'raid.b' + number(sda, 'raid')
        rule = 'part %s --size=500 --ondisk=%s' % (raid, sda)
        f.write(rule + '\n')
        raids += raid + ' '

    rule = 'raid /boot --level=1 --device=md1 %s --fstype=ext4 --spares=%d' % (raids, spares)
    f.write(rule + '\n')
elif len(ret) == 1:
    sda = ret[0]
    rule = 'part / --size=2000 --ondisk=%s --fstype=ext4' % sda
    f.write(rule + '\n')
    rule = 'part /boot --size=500 --ondisk=%s --fstype=ext4' % sda
    f.write(rule + '\n')
elif len(ret) == 0:
    raise ValueError("uOS: you don't have any valid disk")

# lvm for ceph
pvs = ''
for sda in ret:
    pv = 'pv.c' + number(sda, 'pv')
    rule = 'part %s --size=1 --grow --ondisk=%s' % (pv, sda)
    f.write(rule + '\n')
    pvs += pv + ' '
rule = 'volgroup vgceph --pesize=32768 %s' % pvs
f.write(rule + '\n')
rule = 'logvol /data1 --fstype=xfs --name=lvceph --vgname=vgceph --size=1 --grow'
f.write(rule + '\n')
rule = "bootloader --location=mbr --driveorder=%s --append='crashkernel=auto rhgb quiet'" % ret[0]
f.write(rule + '\n')
f.close()
%end

%packages --nobase
@core
rsync
puppet
mod_passenger
sunfire
httpd
nginx
MySQL-server-wsrep
MySQL-client-wsrep
%end

%post --nochroot
mkdir -p /mnt/sysimage/var/sunrise
cp -r /usr/share/sunrise/* /mnt/sysimage/var/sunrise
%end

%post
touch /var/sunrise/install.log
sh -x /var/sunrise/post.sh &> /var/sunrise/install.log
%end

reboot
