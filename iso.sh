#!/bin/bash
# Author: Kun Huang <academicgareth@gmail.com>, DennyZhang <denny@unitedstack.com>, Xin Xu <xuxin@unitedstack.com>

TOP_DIR=$(cd $(dirname "$0") && pwd)
cd $TOP_DIR

source $TOP_DIR/functions

if [[ ! -r $TOP_DIR/sagerc ]]; then
    cfont -n -red "Line: $LINENO missing $TOP_DIR/sagerc - did you grab more than just iso.sh?" -reset -n
    exit 1
fi

source $TOP_DIR/sagerc

GetBaseISO

rm -rf $DEST_DIR
mkdir -p $DEST_DIR

CheckBinPKG rsync
CheckBinPKG mount
CheckBinPKG fuser

# copy the image data
echo $MOUNT_DIR | grep -q "^/.\+" || MOUNT_DIR=${TOP_DIR}/${MOUNT_DIR}
mkdir -p $MOUNT_DIR
UmountDir $MOUNT_DIR

cfont -white "Mount $BASE_ISO on ${MOUNT_DIR}: " -reset
mount $BASE_ISO $MOUNT_DIR -o loop -r && cfont -green "[OK]" -reset -n || {
cfont -red "[FAIL]" -reset -n
exit 1
}

cfont -white "Copy files from $BASE_ISO to ${DEST_DIR}: " -reset
rsync -a --delete ${MOUNT_DIR}/ ${DEST_DIR}/ && cfont -green "[OK]" -reset -n || {
cfont -red "[FAIL]" -reset -n
exit 1
}
UmountDir $MOUNT_DIR

# copy repo and node.ks
rsync -a repo ${DEST_DIR}/
rsync -aP node.ks ${DEST_DIR}/
rsync -aP pxe.ks ${DEST_DIR}/pxeboot/

# use custom install.img and initrd.img
cd $TOP_DIR/sage-images/iso-initrd/
./rebuild.sh

cd $TOP_DIR/sage-images/pxe-initrd/
./rebuild.sh

cd $TOP_DIR/sage-images/stage2/
./rebuild.sh

cd $TOP_DIR
mv ${DEST_DIR}/images/install.img $isodir/images/install.img.bak
rm -rf ${DEST_DIR}/images/*.img
rsync -aP sage-images/stage2/install.img ${DEST_DIR}/images/

rm -rf ${DEST_DIR}/isolinux/initrd.img
rsync -aP sage-images/iso-initrd/initrd.img ${DEST_DIR}/isolinux/

mkdir -p ${DEST_DIR}/pxeboot/
rsync -aP sage-images/pxe-initrd/initrd.img ${DEST_DIR}/pxeboot/

# modify the isolinux.cfg
cat >./isolinux.cfg<<EOF
default vesamenu.c32
#prompt 1
timeout 60

display boot.msg

menu background splash.jpg
menu title Welcome to uStack OS!
menu color border 0 #ffffffff #00000000
menu color sel 7 #ffffffff #ff000000
menu color title 0 #ffffffff #00000000
menu color tabmsg 0 #ffffffff #00000000
menu color unsel 0 #ffffffff #00000000
menu color hotsel 0 #ff000000 #ffffffff
menu color hotkey 7 #ffffffff #ff000000
menu color scrollbar 0 #ffffffff #00000000

label linux
menu label ^Install uStack OS!
menu default
kernel vmlinuz
append initrd=initrd.img text ks=cdrom:/node.ks
EOF

rsync -aP ./isolinux.cfg ${DEST_DIR}/isolinux/isolinux.cfg

CheckBinPKG mkisofs

# make iso
mkisofs -o uOS.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T -V "UnitedStack uOS 1.0" ${DEST_DIR}/
sync

echo 'Wrote '${TOP_DIR}'/uOS.iso'
