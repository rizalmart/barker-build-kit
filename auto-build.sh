#!/bin/sh
#build debian-based puppy step-by-step
#written by mistfire

. ./DISTRO_SPECS

unmount_system(){

  WKGBASE=$(pwd)
  ROOTFS=build-rootfs

  SANDBOX_DIR=${WKGBASE}/compiler-sandbox

  OVERLAY_ROOT=${SANDBOX_DIR}/merged-rootfs
  OVERLAY_WKG=${SANDBOX_DIR}/working
  OVERLAY_UPPER=${SANDBOX_DIR}/upper
  OVERLAY_LOWER=${SANDBOX_DIR}/lower
  
  busybox umount -l ${OVERLAY_ROOT} 2>/dev/null
  busybox umount -l ${OVERLAY_LOWER} 2>/dev/null

  busybox umount -l ${WKGBASE}/${ROOTFS}/proc 2>/dev/null
  busybox umount -l ${WKGBASE}/${ROOTFS}/sys 2>/dev/null
  busybox umount -l ${WKGBASE}/${ROOTFS}/dev/shm 2>/dev/null
  busybox umount -l ${WKGBASE}/${ROOTFS}/dev/pts 2>/dev/null
  busybox umount -l ${WKGBASE}/${ROOTFS}/dev 2>/dev/null
		
}

trap unmount_system EXIT
trap unmount_system TERM
trap unmount_system KILL
trap unmount_system SIGKILL
trap unmount_system SIGTERM

clear

echo "This script will automatically build puppy linux using debian packages."

read -p "Do you want to continue? (Y/N): " answer

case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        echo "Starting the puppy building process..."
        sleep 3
        ;;
    [Nn]|[Nn][Oo])
        exit 1
        ;;
    *)
        echo "Invalid input."
        exit 1
        ;;
esac


./01-build-debian-puppy.sh
./02-prepare-livecd.sh

echo "Check now the contents in build-rootfs folder.
If it was all good, please any key to build the main puppy sfs file"

read VAR1

echo ""

./03-pack-sfs.sh

read -p "Do you want to build other puppy modules (such as adrv, bdrv, gdrv, ndrv, xdrv, ydrv)? (Y/N): " answer

case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        echo "Start building some puppy modules..."
        sleep 3
        ./03b-build-drv-modules.sh
        ;;
esac

./04-process-initrd.sh

echo "Obtain puppy linux kernel, its zdrv modules, and fdrv (firmware driver) modules and do the following:"
echo "1. Put the files on puppy-livecd-build folder"
echo "2. Rename the kernel file as vmlinuz"
echo "3. Rename zdrv module as ${DISTRO_ZDRVSFS}"
echo "4. Rename fdrv module as ${DISTRO_FDRVSFS}

If all done, press any key to build the puppy live cd image
"

read VAR1

. ./05-build-livecd.sh

echo "Building the live-cd complete! The iso filename is ${ISONAME}
(Press any key to exit)
"

read VAR1

exit
