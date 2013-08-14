#version=DEVEL
install
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

ret = [i for i in os.listdir(path) if i.startswith('sd')]
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

%post
echo "export PYTHONPATH=$PYTHONDPATH:/usr/local/lib/python2.7/dist-packages/" >> /etc/profile.d/local_python.sh

cat >> /etc/rc.d/rc.local <<EOF
#if [ ! -f /etc/ustack/puppet.conf ]; then
puppet apply /etc/puppet/modules/production/sunfire/example/repo.pp --modulepath /etc/puppet/modules/production &> /tmp/ustack-puppet1.log
service nginx reload
puppet apply /etc/puppet/modules/production/sunfire/example/masternode.pp --modulepath /etc/puppet/modules/production &> /tmp/ustack-puppet2.log
sleep 20
puppet apply /etc/puppet/modules/production/sunfire/example/masternode.pp --modulepath /etc/puppet/modules/production &> /tmp/ustack-puppet3.log
sleep 20
puppet apply /etc/puppet/modules/production/sunfire/example/masternode.pp --modulepath /etc/puppet/modules/production &> /tmp/ustack-puppet4.log
sleep 20
curl http://localhost:3000/api/config_templates/build_pxe_default
#fi
EOF
%end

%post --nochroot
mkdir -p /mnt/sysimage/opt/ustack/
rsync -rP /tmp/ustack-usb/repo /mnt/sysimage/opt/ustack/

mkdir -p /mnt/sysimage/var/lib/tftpboot/boot

mkdir -p /tmp/cs6
mount /tmp/ustack-usb/os/CentOS-6.4-x86_64-minimal.iso /tmp/cs6 -o loop
mkdir -p /mnt/sysimage/opt/ustack/media
rsync -rP /tmp/cs6/* /mnt/sysimage/opt/ustack/media/
rsync -rP /mnt/sysimage/opt/ustack/media/isolinux/initrd.img /mnt/sysimage/var/lib/tftpboot/boot/UnitedStackOS-6.2-x86_64-initrd.img
rsync -rP /mnt/sysimage/opt/ustack/media/isolinux/vmlinuz /mnt/sysimage/var/lib/tftpboot/boot/UnitedStackOS-6.2-x86_64-vmlinuz
%end

%post
domainname class1.ustack.com
hostname m1
echo '127.0.0.1 localhost' > /etc/hosts
echo '127.0.1.1 m1.cluster1.ustack.com m1' >> /etc/hosts

service forman-proxy start
curl -XPOST -H 'Content-Type:application/json' -d '{"mac": "00:0c:29:fd:94:d1","local": "no","param": "ddd"}' http://localhost:9100/v1.0/node
cd /etc/yum.repos.d/
rm -rf *
cd -
yum clean all
cat >> /etc/yum.repos.d/ustack.repo <<EOF
[ustack]
name=ustack
baseurl=http://127.0.0.1/repo
enabled=1
gpgcheck=0
EOF
%end

%packages --nobase
@core
puppet
mod_passenger
sunfire
httpd
nginx
%end

reboot
