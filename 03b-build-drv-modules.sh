#!/bin/sh

WKGBASE=$(pwd)

export WKGBASE

. ${WKGBASE}/build-settings.cfg
. ${WKGBASE}/DISTRO_SPECS 


if [ "$ROOTFS" == "" ]; then
 echo "Specify rootfs folder name first"
 exit
fi

if [ ! -d ${WKGBASE}/${ROOTFS} ]; then
 echo "rootfs folder name missing"
 exit
fi


export OVERLAY_ROOT
export OVERLAY_LOWER

unmount_system(){
	
  [ "$DRV_PREFIX" == "" ] && return
  
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


build_drv_module(){
	
DRV_PREFIX="$1"	
	
PUP_DRV_PREFIX=$(echo "$1" | tr '[:lower:]' '[:upper:]')
	
DRV_INSTALL_FILE="$2"

DRV_SFS_NAME=$(eval "echo \$DISTRO_${PUP_DRV_PREFIX}DRVSFS")

echo "Building ${DRV_PREFIX}drv sandbox..."

SANDBOX_DIR=${WKGBASE}/${DRV_PREFIX}drv-sandbox

OVERLAY_ROOT=${SANDBOX_DIR}/merged-rootfs
OVERLAY_WKG=${SANDBOX_DIR}/working
OVERLAY_UPPER=${SANDBOX_DIR}/upper
OVERLAY_LOWER=${SANDBOX_DIR}/lower

mkdir -p $OVERLAY_ROOT 2>/dev/null
mkdir -p $OVERLAY_WKG 2>/dev/null
mkdir -p $OVERLAY_UPPER 2>/dev/null
mkdir -p $OVERLAY_LOWER 2>/dev/null

mount -o bind ${WKGBASE}/${ROOTFS} ${OVERLAY_LOWER}

mount -t overlay overlay -o lowerdir=${OVERLAY_LOWER},upperdir=${OVERLAY_UPPER},workdir=${OVERLAY_WKG} ${OVERLAY_ROOT}

if [ $? -ne 0 ]; then
 echo "building ${DRV_PREFIX}drv sandbox failed"
 return
fi

cat > ${OVERLAY_ROOT}/etc/dpkg/dpkg.cfg.d/50excldoc <<EOF
path-exclude=/usr/share/doc/*
path-exclude=/usr/doc/*
path-exclude=/usr/share/man/*
path-exclude=/usr/share/common-licenses/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/locale/*
path-exclude=/usr/share/help/*
path-exclude=/usr/share/gtk-doc/*
EOF

INSTALL_PKGS=$(cat $DRV_INSTALL_FILE | tr '\n' ' ')

chroot ${OVERLAY_ROOT} apt install -y $INSTALL_PKGS

retval=$?

unmount_system

if [ $retval -ne 0 ]; then
 echo "creating $DRV_SFS_NAME failed"
 return
fi

rm -rf ${OVERLAY_UPPER}/dev 2>/dev/null
rm -rf ${OVERLAY_UPPER}/var/cache
rm -rf ${OVERLAY_UPPER}/var/log
rm -rf ${OVERLAY_UPPER}/var/lock/*
rm -rf ${OVERLAY_UPPER}/run/*
rm -rf ${OVERLAY_UPPER}/var/log/apt/* 2>/dev/null
rm -f  ${OVERLAY_UPPER}/var/log/*.log 2>/dev/null
rm -f  ${OVERLAY_UPPER}/var/cache/swcatalog/cache/* 2>/dev/null
rm -rf ${OVERLAY_UPPER}/tmp 2>/dev/null
rm -rf ${OVERLAY_UPPER}/var/tmp/* 2>/dev/null
rm -rf ${OVERLAY_UPPER}/var/run/* 2>/dev/null
rm -rf ${OVERLAY_UPPER}/var/lib/apt 2>/dev/null

rm -f ${OVERLAY_UPPER}/var/cache/debconf/templates.dat-old
rm -f ${OVERLAY_UPPER}/var/lib/flatpak/repo/tmp/cache/summaries/*.sub
rm -f ${OVERLAY_UPPER}/var/lib/dpkg/*-old
rm -f ${OVERLAY_UPPER}/etc/dpkg/dpkg.cfg.d/50excldoc
rm -f ${OVERLAY_UPPER}/var/lib/dpkg/status
rm -f ${OVERLAY_UPPER}/var/lib/dpkg/lock*
rm -rf ${OVERLAY_UPPER}/var/lib/dpkg/triggers

for fld2 in etc usr var opt
do
	[ -d ${OVERLAY_UPPER}/$fld2 ] && find ${OVERLAY_UPPER}/$fld2 -type c | xargs -i rm -f '{}'
done


for cachefile in mimeinfo.cache gschemas.compiled gconv-modules.cache immodules.cache loaders.cache hwdb.bin ld.so.cache localtime machine-id fstab mtab
do
	find ${OVERLAY_UPPER}/ -type f -name "$cachefile" | xargs -i rm -f '{}'
	find ${OVERLAY_UPPER}/ -type l -name "$cachefile" | xargs -i rm -f '{}'
done


for ifld in usr/share/icons usr/local/share/icons usr/lib/puppy/share/icons
do
	[ -d ${OVERLAY_UPPER}/$ifld ] && find ${OVERLAY_UPPER}/$ifld -type f -name "icon-theme.cache" | grep "/hicolor/" | xargs -i rm -f '{}'
done


for mfld in usr/share/mime usr/local/share/mime usr/lib/puppy/share/mime
do
	[ -d ${OVERLAY_UPPER}/$mfld ] && find ${OVERLAY_UPPER}/$mfld | grep -v "/packages" | xargs -i rm -rf '{}'
done

[ ! -d ${WKGBASE}/puppy-livecd-build ] && mkdir -p ${WKGBASE}/puppy-livecd-build

echo "Creating ${DRV_SFS_NAME}..."

mksquashfs "${OVERLAY_UPPER}" "${WKGBASE}/puppy-livecd-build/${DRV_SFS_NAME}" -comp xz -Xbcj x86 -b 1M -Xdict-size 100% -no-duplicates

return

}

PROCESS_COUNT=0

DRV_RANGE=$(cat ${WKGBASE}/DISTRO_SPECS | grep 'DRVSFS' | cut -f 1 -d '=' | sed -e 's#DISTRO_##' -e 's#DRVSFS$##' | grep -vE 'P|Z' | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')

for drv_pfx in $DRV_RANGE
do
  if [ -f "${WKGBASE}/${drv_pfx}drv-packages.list" ]; then
     if [ "$(cat "${WKGBASE}/${drv_pfx}drv-packages.list" | sed -e 's#\n##g')" != "" ]; then
        build_drv_module "$drv_pfx" "${WKGBASE}/${drv_pfx}drv-packages.list"
        PROCESS_COUNT=$(expr $PROCESS_COUNT + 1)
     fi  
  fi
done

echo "$PROCESS_COUNT sfs modules processed"
