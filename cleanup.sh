#!/bin/sh

. ./build-settings.cfg

WKGBASE=$(pwd)

if [ "$WKGBASE" == "" ]; then
  echo "Illegal path"
  exit
fi

echo "Removing $ROOTFS folder...."
[ -d ${WKGBASE}/${ROOTFS} ] && rm -rf ${WKGBASE}/${ROOTFS}

echo "Removing puppy-livecd-build folder...."
[ -d ${WKGBASE}/puppy-livecd-build ] && rm -rf ${WKGBASE}/puppy-livecd-build

echo "Removing compiler-sandbox folder...."
[ -d ${WKGBASE}/compiler-sandbox ] && rm -rf ${WKGBASE}/compiler-sandbox

echo "Removing a/b/g/n/x/ydrv-sandbox folder...."
rm -rf ${WKGBASE}/*drv-sandbox 2>/dev/null

echo "Removing debootstrap-local folder...."
[ -d ${WKGBASE}/debootstrap-local ] && rm -rf ${WKGBASE}/debootstrap-local
