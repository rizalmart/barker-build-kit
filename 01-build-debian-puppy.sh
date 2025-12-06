#!/bin/sh
# Debian testing Desktop Bootstrap Script with Root Password Setup
# created 20250628
# modified by mistfire

#set -e

[ "$(whoami)" != "root" ] && exec sudo -A $0 $@

if [ "$(which busybox)" == "" ]; then
 echo "Install busybox first"
 exit 1
fi

#################################
# CONFIGURATION SECTION
#################################

WKGBASE=$(pwd)

export WKGBASE

. ${WKGBASE}/build-settings.cfg

if [ "$ROOTFS" == "" ]; then
 echo "Specify rootfs folder name first"
 exit
fi

export ROOTFS

if [ ! -d ${WKGBASE}/puppy-rootfs-template ]; then
 echo "puppy-rootfs-template folder is missing"
 exit 1
fi

SANDBOX_DIR=${WKGBASE}/compiler-sandbox

OVERLAY_ROOT=${SANDBOX_DIR}/merged-rootfs
OVERLAY_WKG=${SANDBOX_DIR}/working
OVERLAY_UPPER=${SANDBOX_DIR}/upper
OVERLAY_LOWER=${SANDBOX_DIR}/lower

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

echo
echo "===> Cleaning up any previous mounts..."

[ "$(mount | grep "/${ROOTFS}/")" != "" ] && unmount_system

echo
mkdir -p ${WKGBASE}/debootstrap-local
cd ${WKGBASE}/debootstrap-local

if [ ! -f Packages ];then
 echo "===> Downloading debian package database..."
 wget ${DEBIAN_PKGDB_URL}
 unxz Packages.xz
fi

if [ ! -f ${WKGBASE}/usr/sbin/debootstrap ];then

 echo "===> Downloading debootstrap..."
 DEBfnd="$(grep '^Filename: pool/main/d/debootstrap/debootstrap_' Packages)"
 DEBfnd="${DEBfnd##*/}" #ex: debootstrap_1.0.141devuan1_all.deb
 wget --no-check-certificate ${DEBOOTSTRAP_URL}${DEBfnd} -O ${DEBfnd}
 echo
 echo "===> Extracting debootstrap without installing..."
 busybox dpkg-deb -x ${DEBfnd} ${WKGBASE}/debootstrap-local
  
 if [ ! -f ${WKGBASE}/debootstrap-local/usr/sbin/debootstrap ];then
   echo "Failed to get debootstrap"
   exit 1
 fi
 
 [ ! -d /usr/share/debootstrap ] && mkdir -p /usr/share/debootstrap
 
 cp -arf ${WKGBASE}/debootstrap-local/usr/share/debootstrap/* /usr/share/debootstrap/

fi


if [ ! -f /usr/share/keyrings/${DEBIAN_KEYRING_FILENAME} ];then

 DEBfnd="$(grep '^Filename: pool/main/d/debian-keyring/debian-keyring_' Packages)"
 DEBfnd="${DEBfnd##*/}" #ex: debian-keyring_2023.10.07_all.deb
 
 wget --no-check-certificate ${DEBIAN_KEYRING_URL}${DEBfnd} -O ${DEBfnd}
 busybox dpkg-deb -x ${DEBfnd} ${WKGBASE}/debootstrap-local
 
 [ ! -d /usr/share/keyrings ] && mkdir -p /usr/share/keyrings
 
 cp -af ${WKGBASE}/debootstrap-local/usr/share/keyrings/* /usr/share/keyrings/
  
fi

cd ..

DEBOOTSTRAP_CMD="${WKGBASE}/debootstrap-local/usr/sbin/debootstrap"

# Verify non-busybox dpkg
DPKG=$(which dpkg)
if [ -L "$DPKG" ]; then
  echo "Error: Busybox dpkg is not sufficient. Install the full 'dpkg' package."
  exit 1
fi


echo
echo "===> Cleaning old rootfs if present..."
[ -d ${WKGBASE}/${ROOTFS} ] && rm -rf ${WKGBASE}/${ROOTFS} && sync
mkdir -p ${WKGBASE}/${ROOTFS}/etc/dpkg/dpkg.cfg.d
mkdir -p ${WKGBASE}/${ROOTFS}/etc/apt/apt.conf.d

# dpkg excludes to keep it minimal
cat >  ${WKGBASE}/${ROOTFS}/etc/dpkg/dpkg.cfg.d/50excldoc <<EOF
path-exclude=/usr/share/doc/*
path-exclude=/usr/doc/*
path-exclude=/usr/include/*
path-exclude=/usr/src/*
path-exclude=/usr/share/man/*
path-exclude=/usr/share/common-licenses/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/locale/*
path-exclude=/usr/share/help/*
path-exclude=/usr/share/gtk-doc/*
EOF

# Avoid installing recommends/suggests
cat >  ${WKGBASE}/${ROOTFS}/etc/apt/apt.conf.d/50norec <<EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF


if [ "$UNATTENDED_MODE" == "1" ]; then


# Avoid installing recommends/suggests
cat >  ${WKGBASE}/${ROOTFS}/etc/apt/apt.conf.d/50noninteractive <<EOF
Dpkg::Options {
  "--force-confdef";
  "--force-confold";
};
APT::Get::Assume-Yes "true";
APT::Get::Assume-No "false";
Dpkg::Progress-Fancy "0";
EOF

fi

echo
echo "===> Bootstrapping Debian ${DEBIAN_VERSION_NAME} base system..."
$DEBOOTSTRAP_CMD --arch=${DEBIAN_ARCH} --variant=minbase --include=locales,dialog,busybox-static,sudo,wget,lsof,curl,ca-certificates ${DEBIAN_VERSION_NAME} ${WKGBASE}/${ROOTFS} ${DEBIAN_SITE}
sync

echo
echo "===> Setting up Debian ${DEBIAN_VERSION_NAME} sources.list..."
cat >  ${WKGBASE}/${ROOTFS}/etc/apt/sources.list <<EOF
deb ${DEBIAN_SITE} ${DEBIAN_VERSION_NAME} main contrib non-free non-free-firmware
EOF

echo
echo "===> Mounting system directories..."
busybox mount --rbind /dev  ${WKGBASE}/${ROOTFS}/dev
busybox mount --bind /sys  ${WKGBASE}/${ROOTFS}/sys
busybox mount --bind /proc  ${WKGBASE}/${ROOTFS}/proc

echo
echo "===> Setting locale..."
chroot  ${WKGBASE}/${ROOTFS} localedef -f UTF-8 -i en_US --no-archive en_US.utf8 || true


grplist="wheel
sudo
adm
staff
uucp
users
tty
sambashare
audio
video
cdrom
floppy
tape
lp
dialout
scanner
tape
"

echo
echo "===> Setting root password..."
echo "root:$ROOT_PASSWORD" | chroot ${WKGBASE}/${ROOTFS} chpasswd

for grp1 in ${grplist}
do
  chroot ${WKGBASE}/${ROOTFS} usermod -a -G ${grp1} root     
done

chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'keyboard-configuration keyboard-configuration/layout select ${KEYBOARD_LAYOUT}' | debconf-set-selections"
chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'keyboard-configuration keyboard-configuration/model select ${KEYBOARD_MODEL}' | debconf-set-selections"
chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'keyboard-configuration keyboard-configuration/xkb-keymap select ${KEYBOARD_MODEL}' | debconf-set-selections"
chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'cups-server-common cups-server-common/admin_root boolean false' | debconf-set-selections"
chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'cups cupsys/raw-print boolean true' | debconf-set-selections"

chroot ${WKGBASE}/${ROOTFS} dpkg-reconfigure --frontend=noninteractive keyboard-configuration cups-server-common

if [ "$UNATTENDED_MODE" == "1" ]; then

cat > ${WKGBASE}/${ROOTFS}/usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF

chmod +x ${WKGBASE}/${ROOTFS}/usr/sbin/policy-rc.d

fi

echo
echo "Basic Debian ${DEBIAN_VERSION_NAME} rootfs created!"
sleep 3

[ ! -f ${WKGBASE}/${ROOTFS}/etc/localtime ] && chroot ${WKGBASE}/${ROOTFS} ln -s /usr/share/zoneinfo/GMT /etc/localtime

chroot ${WKGBASE}/${ROOTFS} apt modernize-sources -y

echo
echo "===> Updating package lists..."
chroot ${WKGBASE}/${ROOTFS} apt update

echo
echo "===> Installing desktop environment and packages..."

# Complete package list
PKGLIST=$(cat ${WKGBASE}/packages.list | tr '\n' ' ')

chroot ${WKGBASE}/${ROOTFS} apt install -y ${PKGLIST}
retval=$?
echo
sync

echo

if [ $retval -ne 0 ]; then
	echo "Something's wrong on installing packages. Press any key to exit"
	[ "$UNATTENDED_MODE" != "1" ] && read TEST1
	exit
else
	echo "===> All packages installed!"
fi

cp -f ${WKGBASE}/external-tools/apt-mark-manual ${WKGBASE}/${ROOTFS}/apt-mark-manual

chroot ${WKGBASE}/${ROOTFS} /apt-mark-manual

rm -f ${WKGBASE}/${ROOTFS}/apt-mark-manual

echo
echo "===> Installing Puppy Components!"

cp -arf ${WKGBASE}/puppy-rootfs-template/* ${WKGBASE}/${ROOTFS}/
cp -arf ${WKGBASE}/puppy-rootfs-template/usr/lib/puppy/etc/config-template/* ${WKGBASE}/${ROOTFS}/etc/
cp -arf ${WKGBASE}/DISTRO_SPECS ${WKGBASE}/${ROOTFS}/etc/DISTRO_SPECS

chroot ${WKGBASE}/${ROOTFS} systemctl enable puppy-rc-sysinit puppy-rc-shutdown
chroot ${WKGBASE}/${ROOTFS} ln -sr /usr/bin/busybox /usr/bin/ash

if [ "$FILEMNT_DEFAULT_FILEMANAGER" != "" ]; then

echo '#!/bin/bash
exec '$FILEMNT_DEFAULT_FILEMANAGER' "$@"
exit
' > ${WKGBASE}/${ROOTFS}/usr/local/bin/defaultfilemanager

chmod +x ${WKGBASE}/${ROOTFS}/usr/local/bin/defaultfilemanager

fi


rm -f ${WKGBASE}/${ROOTFS}/usr/bin/sh
chroot ${WKGBASE}/${ROOTFS} ln -sr /usr/bin/bash /usr/bin/sh

if [ -f ${WKGBASE}/mimeapps.list ]; then
	cp -f ${WKGBASE}/mimeapps.list ${WKGBASE}/${ROOTFS}/usr/local/share/applications/mimeapps.list
fi

chroot ${WKGBASE}/${ROOTFS} apt --fix-broken install

if [ "$PUPPY_CORE_APPS_COMPILE" == "yes" ] && [ -d ${WKGBASE}/puppy-source-builds ]; then

	echo "===> Compiling some puppy core apps!"

	mkdir -p $OVERLAY_ROOT 2>/dev/null
	mkdir -p $OVERLAY_WKG 2>/dev/null
	mkdir -p $OVERLAY_UPPER 2>/dev/null
	mkdir -p $OVERLAY_LOWER 2>/dev/null

	echo "Building compiler sandbox..."

	mount -o bind ${WKGBASE}/${ROOTFS} ${OVERLAY_LOWER}

	mount -t overlay overlay -o lowerdir=${OVERLAY_LOWER},upperdir=${OVERLAY_UPPER},workdir=${OVERLAY_WKG} ${OVERLAY_ROOT}

	touch ${OVERLAY_ROOT}/chrooted.flg
	
	cp -rf ${WKGBASE}/puppy-source-builds ${OVERLAY_ROOT}/
	
	cp -f ${WKGBASE}/external-tools/compile-puppy-core-apps.sh ${OVERLAY_ROOT}/tmp/compile-puppy-core-apps.sh

	echo "Start compiling..."

	chroot ${OVERLAY_ROOT} /tmp/compile-puppy-core-apps.sh
	
	umount -l ${OVERLAY_ROOT}
	umount -l ${OVERLAY_LOWER}
	
	find ${OVERLAY_UPPER}/usr/local/ -type c | xargs -i rm -f '{}'

	cp -rf ${OVERLAY_UPPER}/usr/local/* ${ROOTFS}/usr/local/

	rm -rf ${SANDBOX_DIR}
  
fi

echo

echo "===> Debloating rootfs!"

rm -rf ${WKGBASE}/${ROOTFS}/usr/local/share/qt6/translations/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/local/share/locale/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/local/share/man/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/local/share/doc/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/local/share/info/* 2>/dev/null


rm -f ${WKGBASE}/${ROOTFS}/usr/bin/gdb 2>/dev/null
rm -f ${WKGBASE}/${ROOTFS}/usr/bin/x86_64-linux-gnu-lto-dump* 2>/dev/null
#rm -rf ${WKGBASE}/${ROOTFS}/usr/libexec/gcc/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/share/qt6/translations/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/share/locale/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/share/man/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/share/doc/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/usr/share/info/* 2>/dev/null

rm -rf ${WKGBASE}/${ROOTFS}/var/cache/apt/* 2>/dev/null

mkdir -p ${WKGBASE}/${ROOTFS}/var/cache/apt/archives 2>/dev/null
touch ${WKGBASE}/${ROOTFS}/var/cache/apt/archives/lock 2>/dev/null

rm -rf ${WKGBASE}/${ROOTFS}/var/log/apt/* 2>/dev/null
rm -f ${WKGBASE}/${ROOTFS}/var/log/*.log 2>/dev/null
rm -f ${WKGBASE}/${ROOTFS}/var/cache/swcatalog/cache/* 2>/dev/null
rm -rf ${WKGBASE}/${ROOTFS}/tmp/* 2>/dev/null

rm -f ${WKGBASE}/${ROOTFS}/var/cache/debconf/templates.dat-old
rm -f ${WKGBASE}/${ROOTFS}/var/lib/flatpak/repo/tmp/cache/summaries/*.sub
rm -f ${WKGBASE}/${ROOTFS}/var/lib/dpkg/*-old

rm -f ${WKGBASE}/${ROOTFS}/usr/share/fonts/opentype/unifont/unifont_*.otf
rm -rf ${WKGBASE}/${ROOTFS}/usr/share/unifont

find ${WKGBASE}/${ROOTFS}/usr -type f -name "*.a" | xargs -i rm -f '{}'
find ${WKGBASE}/${ROOTFS}/usr -type f -name "*.la" | xargs -i rm -f '{}'
find ${WKGBASE}/${ROOTFS}/usr -type d | xargs -i ${WKGBASE}/external-tools/fix-duplicates '{}'

if [ -d ${WKGBASE}/${ROOTFS}/var/lib/swcatalog/icons ]; then 
	find ${WKGBASE}/${ROOTFS}/var/lib/swcatalog/icons -type d | xargs -i ${WKGBASE}/external-tools/fix-duplicates '{}'
fi

chroot ${WKGBASE}/${ROOTFS} chmod 775 /var/lib/samba/usershares 2>/dev/null

chroot ${WKGBASE}/${ROOTFS} flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

chroot ${WKGBASE}/${ROOTFS} usermod -a -G sambashare ${USERNAME}
chroot ${WKGBASE}/${ROOTFS} usermod -a -G sambashare root

[ ! -d ${WKGBASE}/${ROOTFS}/etc/sddm.conf.d ] && mkdir -p ${WKGBASE}/${ROOTFS}/etc/sddm.conf.d
[ ! -d ${WKGBASE}/${ROOTFS}/etc/gdm ] && mkdir -p ${WKGBASE}/${ROOTFS}/etc/gdm



echo "[Autologin]
User=${USERNAME}
Session=${USER_SESSION_NAME}
" >> ${WKGBASE}/${ROOTFS}/etc/sddm.conf.d/autologin.conf


echo "[daemon]
AutomaticLoginEnable=True
AutomaticLogin=${USERNAME}" > ${WKGBASE}/${ROOTFS}/etc/gdm/custom.conf


if [ -f ${WKGBASE}/${ROOTFS}/etc/lightdm/lightdm.conf ]; then

	grep -q '^autologin-user='  ${WKGBASE}/${ROOTFS}/etc/lightdm/lightdm.conf && \
	sed -i 's/^autologin-user=.*/autologin-user='${USERNAME}'/'  ${WKGBASE}/${ROOTFS}/etc/lightdm/lightdm.conf || \
	sed -i '/^\[Seat:\*\]/ a autologin-user='${USERNAME}''  ${WKGBASE}/${ROOTFS}/etc/lightdm/lightdm.conf

	grep -q '^autologin-session='  ${WKGBASE}/${ROOTFS}/etc/lightdm/lightdm.conf && \
	sed -i 's/^autologin-session=.*/autologin-session='$(basename $USER_SESSION_NAME .desktop)'/'  ${WKGBASE}/${ROOTFS}/etc/lightdm/lightdm.conf || \
	sed -i '/^\[Seat:\*\]/ a autologin-session='$(basename $USER_SESSION_NAME .desktop)''  ${WKGBASE}/${ROOTFS}/etc/lightdm/lightdm.conf

fi

# revise dpkg excludes to keep it minimal
cat >  ${WKGBASE}/${ROOTFS}/etc/dpkg/dpkg.cfg.d/50excldoc <<EOF
path-exclude=/usr/share/doc/*
path-exclude=/usr/doc/*
path-exclude=/usr/share/man/*
path-exclude=/usr/share/common-licenses/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/locale/*
path-exclude=/usr/share/help/*
path-exclude=/usr/share/gtk-doc/*
EOF

chroot ${WKGBASE}/${ROOTFS} systemctl disable openvpn smartmontools ldconfig strongswan-starter nvmefc-boot-connections.service nvmf-autoconnect.service smbd nmbd NetworkManager-wait-online
chroot ${WKGBASE}/${ROOTFS} systemctl enable acpid thermald

echo
echo "===> Creating groups and adding user account..."

chroot ${WKGBASE}/${ROOTFS} useradd -m -s /bin/bash -c ${USERNAME} ${USERNAME}

for grp1 in ${grplist}
do
  chroot ${WKGBASE}/${ROOTFS} usermod -a -G ${grp1} ${USERNAME}    
done

echo "${USERNAME}:${USER_PASSWORD}" | chroot ${WKGBASE}/${ROOTFS} chpasswd

for grp1 in sambashare scanner
do
  chroot ${WKGBASE}/${ROOTFS} usermod -a -G ${grp1} ${USERNAME}
  chroot ${WKGBASE}/${ROOTFS} usermod -a -G ${grp1} root     
done

if [ "$SUDO_GUI" != "" ]; then
   echo "export SUDO_ASKPASS=${SUDO_GUI}" > ${WKGBASE}/${ROOTFS}/etc/profile.d/sudo-askpass.sh
   chmod +x ${WKGBASE}/${ROOTFS}/etc/profile.d/sudo-askpass.sh
fi


if [ "$UNATTENDED_MODE" == "1" ]; then

	rm -f ${WKGBASE}/${ROOTFS}/etc/apt/apt.conf.d/50noninteractive
	rm -f ${WKGBASE}/${ROOTFS}/usr/sbin/policy-rc.d

fi

chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'PURGE' | debconf-communicate keyboard-configuration"
chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'PURGE' | debconf-communicate cups-server-common"
chroot ${WKGBASE}/${ROOTFS} /bin/bash -c "echo 'PURGE' | debconf-communicate cupsys"

#set init system path
[ "$INITEXEC_PATH" != "" ] && echo "INITEXEC=${INITEXEC_PATH}" >  ${WKGBASE}/${ROOTFS}/etc/init-system.conf

[ -f ${WKGBASE}/${ROOTFS}/etc/PUPPY_SPECS ] && sed -i -e 's#HYBRID_DISTRO=.*#HYBRID_DISTRO="no"#g' ${WKGBASE}/${ROOTFS}/etc/PUPPY_SPECS

cp -f ${WKGBASE}/external-tools/update-system-packages ${WKGBASE}/${ROOTFS}/usr/local/bin/update-system-packages

chroot ${WKGBASE}/${ROOTFS} update-cache.sh y

echo
echo "===> Cleaning up mounts..."
unmount_system

echo
echo "===> Done. Debian ${DEBIAN_VERSION_NAME} puppy rootfs is ready!"
