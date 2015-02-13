#! /bin/sh
# mkcard.sh v0.5
# (c) Copyright 2009 Graeme Gregory <dp@xora.org.uk>
# (c) Copyright 2013 Koen Kooi <koen@dominion.thruhere.net>
# Licensed under terms of GPLv2
#
# Parts of the procudure base on the work of Denys Dmytriyenko
# http://wiki.omap.com/index.php/MMC_Boot_Format

export LC_ALL=C

DRIVE=/dev/loop0

FILENAME=s5-image.img

rm $FILENAME

# Create blank image file of same size as SD card
dd if=/dev/zero of=$FILENAME bs=1024 count=0 seek=3813376

# Loop mount image
losetup $DRIVE $FILENAME

SIZE=`fdisk -l $DRIVE | grep Disk | grep bytes | awk '{print $5}'`

echo DISK SIZE - $SIZE bytes

CYLINDERS=`echo $SIZE/255/63/512 | bc`

echo CYLINDERS - $CYLINDERS

{
echo ,9,0x0C,*
echo 10,9,0x0C,-
echo 19,,,-
} | sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE

sleep 1


if [ -x /sbin/kpartx ]; then
	kpartx -a -v ${DRIVE}
fi

# handle various device names.
# note something like fdisk -l /dev/loop0 | egrep -E '^/dev' | cut -d' ' -f1 
# won't work due to https://bugzilla.redhat.com/show_bug.cgi?id=649572

PARTITION1=${DRIVE}1
if [ ! -b ${PARTITION1} ]; then
	PARTITION1=${DRIVE}p1
fi

DRIVE_NAME=`basename $DRIVE`
DEV_DIR=`dirname $DRIVE`

if [ ! -b ${PARTITION1} ]; then
	PARTITION1=$DEV_DIR/mapper/${DRIVE_NAME}p1
fi

PARTITION2=${DRIVE}2
if [ ! -b ${PARTITION2} ]; then
	PARTITION2=${DRIVE}p2
fi
if [ ! -b ${PARTITION2} ]; then
	PARTITION2=$DEV_DIR/mapper/${DRIVE_NAME}p2
fi

PARTITION3=${DRIVE}3
if [ ! -b ${PARTITION3} ]; then
	PARTITION3=${DRIVE}p3
fi
if [ ! -b ${PARTITION3} ]; then
	PARTITION3=$DEV_DIR/mapper/${DRIVE_NAME}p3
fi

# now make partitions.
if [ -b ${PARTITION1} ]; then
	umount ${PARTITION1}
	echo "mkfs.vfat BtmBoot"
	mkfs.vfat -F 32 -n "BtmBoot" ${PARTITION1}
else
	echo "Cant find BtmBoot partition in /dev"
fi

if [ -b ${PARITION2} ]; then
	umount ${PARTITION2}
	echo "mkfs.vfat BtmBootBak"
	mkfs.vfat -F 32  -n "BtmBootBak" ${PARTITION2} 
else
	echo "Cant find BtmBootBak partition in /dev"
fi

if [ -b ${PARITION3} ]; then
	umount ${PARTITION3}
	echo "mkfs.ext4 Config"
	mkfs.ext4  -L "Config" ${PARTITION3} 
else
	echo "Cant find config partition in /dev"
fi

PARTITION1_MOUNT=/mnt/BtmBoot

mkdir $PARTITION1_MOUNT

mount $PARTITION1 $PARTITION1_MOUNT

cp MLO uEnv.txt u-boot.img am335x-boneblack-bitmainer.dtb uImage.bin initramfs.bin.SD runme.sh $PARTITION1_MOUNT

while mountpoint -q $PARTITION1_MOUNT && ! sudo umount $PARTITION1_MOUNT; do
  sleep 0.1
done

rm -r $PARTITION1_MOUNT

losetup -d $DRIVE

if [ -x /sbin/kpartx ]; then
	kpartx -d -v ${DRIVE}
fi
