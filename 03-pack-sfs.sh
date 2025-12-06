#!/bin/bash
. ./build-settings.cfg
. ./DISTRO_SPECS

WKBASE=$(pwd)

[ ! -d ${WKBASE}/puppy-livecd-build ] && mkdir -p ${WKBASE}/puppy-livecd-build

rm -f "${WKBASE}/puppy-livecd-build/${DISTRO_PUPPYSFS}" 2>/dev/null

mksquashfs "${ROOTFS}" "${WKBASE}/puppy-livecd-build/${DISTRO_PUPPYSFS}" -comp xz -Xbcj x86 -b 1M -Xdict-size 100% -no-duplicates
