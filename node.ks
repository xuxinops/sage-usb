#version=DEVEL
install
lang en_US.UTF-8
keyboard us
network --onboot yes --device eth0 --bootproto static --hostname us1
rootpw  --iscrypted $6$khisXn4dB6eUgWT6$jA/uAPvJP0brDVqhr/BKpx8l7AQ4EJr36e0tHH/J4iPMs9h5oR5B.EzgzB1e8L9ZZkzGnbK9jISQ21YM5zUC40
firewall --disable
authconfig --enableshadow --passalgo=sha512
selinux --disable
timezone --utc Etc/UTC
zerombr

%include /tmp/part-include
%include /tmp/repo-include

%pre --interpreter /usr/bin/python --log=/tmp/pre0.log
import os
if os.path.exists('/dev/disk/by-label/ustack-usb'):
    lines = 'repo --name=ustack --baseurl=file:/tmp/ustack-usb/repo/ustack\n' \
            'repo --name=sunfire --baseurl=file:/tmp/ustack-usb/repo/sunfire\n' \
            'repo --name=storm --baseurl=file:/tmp/ustack-usb/repo/storm\n'
else:
    lines = 'repo --name=ustack --baseurl=file:/mnt/source/repo/ustack\n' \
            'repo --name=sunfire --baseurl=file:/mnt/source/repo/sunfire\n' \
            'repo --name=storm --baseurl=file:/mnt/source/repo/storm\n'
with open('/tmp/repo-include', 'w') as f:
    f.write(lines + '\n')
%end

%pre --log=/tmp/pre1.log
mkdir /tmp/ustack-usb
mount -L ustack-usb /tmp/ustack-usb

adp=`MegaCli -adpCount | grep -i controller | awk '{print $3}'`
if [[ $adp = 0* ]];then
    pylsi raid -d
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
f.write('part swap --recommended\n')

if len(ret) >= 2:
    # raid on /
    raids = ''
    for sda in ret:
        raid = 'raid.r' + number(sda, 'raid')
        rule = 'part %s --size=8000 --ondisk=%s' % (raid, sda)
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
    rule = 'part / --size=8000 --ondisk=%s --fstype=ext4' % sda
    f.write(rule + '\n')
    rule = 'part /boot --size=500 --ondisk=%s --fstype=ext4' % sda
    f.write(rule + '\n')
elif len(ret) == 0:
    raise ValueError("uOS: you don't have any valid disk")

# lvm for ceph
if 'ceph need' == 'lvm':
    # this is moved to posted
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

%post --nochroot --log=/tmp/ks-sdx3.log --interpreter /usr/bin/python
# do sdX3 formatting, this is temp work for puppet
# TODO: remove it in plan
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

for sda in ret:
    cmd = "parted -s /dev/%s mkpart primary 17.3G 100%%" % sda
    os.system(cmd)
%end

%post --nochroot --log=/tmp/ks-sync.log
usb=/tmp/ustack-usb
iso=/mnt/source
if [ -f $usb/node.ks ]; then
    source=$usb
else
    source=$iso
fi

target=/mnt/sysimage/opt/ustack

mkdir -p $target
rsync -rP $source/repo $target

if [ -f $usb/node.ks ]; then
    mkdir -p /tmp/cs6
    mount $source/os/CentOS-6.4-x86_64-minimal.iso /tmp/cs6 -o loop
    mkdir -p $target/media
    rsync -rP /tmp/cs6/* $target/media/
else
    rsync -rP --exclude=repo $iso/* $target/media/
    mv $target/media/images/install.img.bak $target/media/images/install.img -f
fi

tftpdir=/mnt/sysimage/var/lib/tftpboot/boot
mkdir -p $tftpdir
rsync -rP $target/media/isolinux/initrd.img $tftpdir/UnitedStackOS-6.2-x86_64-initrd.img
rsync -rP $target/media/isolinux/vmlinuz $tftpdir/UnitedStackOS-6.2-x86_64-vmlinuz

# copy unitedstack.cfg file
rsync -P /tmp/unitedstack.cfg /mnt/sysimage/tmp/unitedstack.cfg
%end

%post --log=/tmp/post-install.log

# generate rc.local
cat >> /etc/rc.d/rc.local <<EOF
address_info=$(ifconfig ${nic} | grep -w inet)
if [ x"${address_info}" != "x" ]
then
    ip_address=$(echo ${address_info} | awk '{print $2}' | cut -d ':' -f2)
fi

default_route_info=$(ip route | grep default)
if [ x"${default_route_info}" != "x" ]
then
    gateway_address=$(echo ${default_route_info} | awk '{print $3}')
fi

cat > /tmp/setup_masternode.pp << EOG
class {'sunfire::masternode':
  us_enable_openstack => true,
  us_foreman_url => 'http://127.0.0.1',
  us_puppetmaster_url => 'us1.ustack.in',
}
EOG

puppet apply  /tmp/setup_masternode.pp --modulepath=/etc/puppet/modules/production > /tmp/masternode.log
EOF


# fix domainname and hostname
domainname ustack.in
hostname us1
echo '127.0.0.1 localhost' > /etc/hosts
echo '127.0.1.1 us1.ustack.in us1' >> /etc/hosts

# init ustack.repo and remove others
cd /etc/yum.repos.d/
rm -rf *
cd -
yum clean all

cat >> /etc/yum.repos.d/ustack.repo <<EOF
[sunfire]
name=Packages for Sunfire - $basearch
baseurl=http://127.0.0.1/repo/sunfire
enabled=1
gpgcheck=0
[storm]
name=Packages for Storm - $basearch
baseurl=http://127.0.0.1/repo/storm
enabled=1
gpgcheck=0
[ustack]
name=Packages for uStack - $basearch
baseurl=http://127.0.0.1/repo/ustack
enabled=1
gpgcheck=0
EOF

cat > /tmp/setup_repo.pp << EOF
class {'sunfire::repo':}
EOF
puppet apply /tmp/setup_repo.pp --modulepath=/etc/puppet/modules/production -v > /tmp/repo.log

# change ethN to master
cd /etc/sysconfig/network-scripts/
cfg=`grep USTACK * | awk -F ':' '{print $1}'`
eth=`echo $cfg | awk -F '-' '{print $2}'`

sed -i -e "s/$eth/master/" $cfg

cd /etc/udev/rules.d/
sed -i -e "s/$eth/master/" 70-persistent-net.rules
%end

%packages --nobase
@core
rsync
puppet
mod_passenger
sunfire
storm
httpd
nginx
mysql
mysql-server
%end

reboot --eject
