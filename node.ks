#version=DEVEL
install
#lang en_US.UTF-8
#keyboard us
#network --onboot yes --device eth0 --bootproto static --ip 192.168.10.1 --gateway 192.168.10.2 --netmask 255.255.255.0 --nameserver 114.114.114.114 --noipv6 --hostname m1
#network --onboot yes --device eth0 --bootproto dhcp --noipv6
network --onboot yes --device eth0 --bootproto static --hostname m1
rootpw  --iscrypted $6$khisXn4dB6eUgWT6$jA/uAPvJP0brDVqhr/BKpx8l7AQ4EJr36e0tHH/J4iPMs9h5oR5B.EzgzB1e8L9ZZkzGnbK9jISQ21YM5zUC40
firewall --disable
authconfig --enableshadow --passalgo=sha512
selinux --disable
timezone --utc America/New_York

%include /tmp/part-include
repo --name=uOS --baseurl=file:/tmp/ustack-usb/repo
#repo --name=ustack --baseurl=http://mirrors.ustack.com/sunfire/RPMS/x86_64

%pre
mkdir /tmp/ustack-usb
mount -L ustack-usb /tmp/ustack-usb
for file in /sys/block/sd*; do
    if [ `cat $file/size` -gt 83886080 ]; then
        if [ `cat $file/removable` -eq 0 ]; then
            hd=$(basename $file)
            echo "clearpart --all --drives=$hd" >> /tmp/part-include
            echo "part /boot --size=512 --fstype=ext3 --ondisk=$hd" >> /tmp/part-include
            echo "part / --size=204800 --fstype=ext3 --ondisk=$hd" >> /tmp/part-include
            echo "part /data --size=204800 --fstype=xfs --ondisk=$hd" >> /tmp/part-include
        fi
    fi
done
echo "bootloader --location=mbr --driveorder=$hd --append='crashkernel=auto rhgb quiet'" >> /tmp/part-include
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

#puppet apply /usr/share/sunfire/ustack/example/site.pp --modulepath /usr/share/sunfire &> /tmp/ustack-puppet.log
%end

%packages --nobase --ignoremissing
@core
puppet
mod_passenger
sunfire
httpd
nginx
%end

reboot
