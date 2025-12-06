#!/bin/bash

. ./build-settings.cfg
. ./DISTRO_SPECS

WKBASE=$(pwd)

if [ ! -d ${WKBASE}/livecd-files ]; then
 echo "livecd-files folder is missing"
 exit 1
fi

[ ! -d ${WKBASE}/puppy-livecd-build ] && mkdir -p ${WKBASE}/puppy-livecd-build

cp -arf ${WKBASE}/livecd-files/* ${WKBASE}/puppy-livecd-build/

rm -f ${WKBASE}/puppy-livecd-build/initrd.xz
