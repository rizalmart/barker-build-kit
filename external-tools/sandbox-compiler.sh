#!/bin/sh

WKGBASE=$(pwd)

export WKGBASE

. ${WKGBASE}/build-settings.cfg

if [ "$ROOTFS" == "" ]; then
 echo "Specify rootfs folder name first"
 exit
fi

if [ ! -d ${WKGBASE}/${ROOTFS} ]; then
 echo "rootfs folder name missing"
 exit
fi

SANDBOX_DIR=${WKGBASE}/compiler-sandbox

OVERLAY_ROOT=${SANDBOX_DIR}/merged-rootfs
OVERLAY_WKG=${SANDBOX_DIR}/working
OVERLAY_UPPER=${SANDBOX_DIR}/upper
OVERLAY_LOWER=${SANDBOX_DIR}/lower

mkdir -p $OVERLAY_ROOT 2>/dev/null
mkdir -p $OVERLAY_WKG 2>/dev/null
mkdir -p $OVERLAY_UPPER 2>/dev/null
mkdir -p $OVERLAY_LOWER 2>/dev/null

export OVERLAY_ROOT
export OVERLAY_LOWER

unmount_system(){
  
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

echo "Building compiler sandbox..."

mount -o bind ${WKGBASE}/${ROOTFS} ${OVERLAY_LOWER}

mount -t overlay overlay -o lowerdir=${OVERLAY_LOWER},upperdir=${OVERLAY_UPPER},workdir=${OVERLAY_WKG} ${OVERLAY_ROOT}

if [ $? -ne 0 ]; then
 echo "building compiler sandbox failed"
 exit
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

COMPILER_PKGS='
build-essential
pkg-config
autoconf
automake
libtool
cmake
extra-cmake-modules
ninja-build
meson
git
wget
curl
bison
flex
musl
musl-dev
musl-tools
libgtk-3-dev
libglib2.0-dev
libgdk-pixbuf-2.0-dev
libcairo2-dev
libpango1.0-dev
libatk1.0-dev
libx11-dev
libxext-dev
libxrandr-dev
libxi-dev
libxcursor-dev
libxinerama-dev
libsystemd-dev
systemd-dev
valac
libvala-*-dev
python3-dev
python3-pip
python3-gi
python3-gi-cairo
gir1.2-gtk-3.0
libayatana-appindicator3-dev
libgtk-layer-shell-dev
libgtk2.0-dev
libvte-dev
liblzo2-dev
'

chroot ${OVERLAY_ROOT} apt install -y $(echo $COMPILER_PKGS | tr '\n' ' ')

echo "Compiler sandbox is created. Welcome to sandbox bash shell."
echo "Type \"logout\" to quit sandbox shell"
chroot ${OVERLAY_ROOT} bash
exit 0
