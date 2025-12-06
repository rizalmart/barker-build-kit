#!/bin/bash

. ./build-settings.cfg
. ./DISTRO_SPECS

WKGBASE=$(pwd)
ISONAME="${DISTRO_NAME}_${DISTRO_VERSION}.iso"

if [ ! -d ${WKGBASE}/puppy-livecd-build ]; then
 echo "puppy-livecd-build folder is missing"
 exit 1
fi

[ -f ${WKGBASE}/${ISONAME} ] && rm -f ${WKGBASE}/${ISONAME}

EFI_BOOT_IMG=""
EFI_IMG_FOUND=""

for uf in efiboot.img efi.img boot/efiboot.img boot/efi.img
do

	if [ -f $WKBASE/puppy-livecd-build/$uf ]; then
		EFI_BOOT_IMG="$uf"
		EFI_IMG_FOUND="true"
		break
	fi

done


BOOTPARM=""

for bload in isolinux.bin grldr boot/isolinux.bin boot/grldr boot/isolinux/isolinux.bin boot/grub/grldr
do
	if [ -f ${WKGBASE}/puppy-livecd-build/$bload ]; then
	  BOOTPARM="-b $bload"
	  break
	fi
done


BOOTCAT=""

for bcat in boot.cat boot.catalog boot/boot.cat boot/boot.catalog
do
	if [ -f ${WKGBASE}/puppy-livecd-build/$bcat ]; then
	  BOOTCAT="-c $bcat"
	  break
	fi
done


[ "${CD_VOLUME_NAME}" != "" ] && VOLI="-V ${CD_VOLUME_NAME}"

cd ${WKGBASE}/puppy-livecd-build/

echo "DEFAULT USER ACCOUNT
username: $USERNAME
password: $USER_PASSWORD

ROOT PASSWORD: $ROOT_PASSWORD
" > ${WKGBASE}/puppy-livecd-build/default-account-credentials.txt


if [ "$EFI_IMG_FOUND" != "" ]; then
	mkisofs -J -D -R ${VOLI} -o ${WKGBASE}/${ISONAME} ${BOOTPARM} ${BOOTCAT} -full-iso9660-filenames -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -eltorito-platform 0xEF -eltorito-boot ${EFI_BOOT_IMG} -no-emul-boot ${WKGBASE}/puppy-livecd-build/
else
	mkisofs -J -D -R ${VOLI} -o ${WKGBASE}/${ISONAME} ${BOOTPARM} ${BOOTCAT} -full-iso9660-filenames -no-emul-boot -boot-load-size 4 -boot-info-table ${WKGBASE}/puppy-livecd-build/  
fi

