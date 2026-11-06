#!/bin/bash
# Post processing rootfs Script with Root Password Setup
# created 20220228
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

cat > ${WKGBASE}/${ROOTFS}/usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF

chmod +x ${WKGBASE}/${ROOTFS}/usr/sbin/policy-rc.d

[ ! -f ${WKGBASE}/${ROOTFS}/etc/localtime ] && chroot ${WKGBASE}/${ROOTFS} ln -s /usr/share/zoneinfo/GMT /etc/localtime

echo
echo "===> Installing Puppy Components!"

cp -arf ${WKGBASE}/puppy-rootfs-template/* ${WKGBASE}/${ROOTFS}/
cp -arf ${WKGBASE}/puppy-rootfs-template/usr/local/puppy/etc/config-template/* ${WKGBASE}/${ROOTFS}/etc/
cp -arf ${WKGBASE}/DISTRO_SPECS ${WKGBASE}/${ROOTFS}/etc/DISTRO_SPECS

chroot ${WKGBASE}/${ROOTFS} ln -s /usr/local/puppy/lib/gtkdialog /usr/lib/gtkdialog
chroot ${WKGBASE}/${ROOTFS} ln -s /usr/local/puppy/etc/core-scripts/functions /etc/rc.d/functions
chroot ${WKGBASE}/${ROOTFS} ln -s /usr/local/puppy/etc/core-scripts/functions_x /etc/rc.d/functions_x

chroot ${WKGBASE}/${ROOTFS} cp -asn /usr/local/puppy/bin/* /usr/local/bin/
chroot ${WKGBASE}/${ROOTFS} cp -asn /usr/local/puppy/sbin/* /usr/local/sbin/

[ -d ${WKGBASE}/chroot-includes ] && cp -arf ${WKGBASE}/chroot-includes/* ${WKGBASE}/${ROOTFS}/
[ -d ${WKGBASE}/includes.chroot ] && cp -arf ${WKGBASE}/includes.chroot/* ${WKGBASE}/${ROOTFS}/

chroot ${WKGBASE}/${ROOTFS} systemctl enable puppy-rc-sysinit puppy-rc-shutdown zramswap dkms-check nvidia-driver-select
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


if [ -f ${WKGBASE}/${ROOTFS}/usr/share/applications/gdebi.desktop ]; then

	if [ "$(grep -m 1 "Exec=gdebi-gtk " ${WKGBASE}/${ROOTFS}/usr/share/applications/gdebi.desktop 2>/dev/null)" != "" ]; then
	  sed -i -e "s#Exec=gdebi-gtk\ #Exec=sudo\ -A\ gdebi-gtk\ #g" ${WKGBASE}/${ROOTFS}/usr/share/applications/gdebi.desktop
	fi

	chmod +x ${WKGBASE}/${ROOTFS}/usr/local/bin/gdebi-fix.sh 2>/dev/null

fi


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

#redirect jack apps to pipewire
if [ -f ${WKGBASE}/${ROOTFS}/usr/lib/puppy/sbin/pipewire-jack-helper.sh ]; then
	chroot ${WKGBASE}/${ROOTFS} /usr/lib/puppy/sbin/pipewire-jack-helper.sh
fi

if [ "$SUDO_GUI" != "" ]; then
   echo "export SUDO_ASKPASS=${SUDO_GUI}" > ${WKGBASE}/${ROOTFS}/etc/profile.d/sudo-askpass.sh
   chmod +x ${WKGBASE}/${ROOTFS}/etc/profile.d/sudo-askpass.sh
fi

[ -f ${WKGBASE}/${ROOTFS}/usr/sbin/policy-rc.d ] && rm -f ${WKGBASE}/${ROOTFS}/usr/sbin/policy-rc.d

#set init system path
[ "$INITEXEC_PATH" != "" ] && echo "INITEXEC=${INITEXEC_PATH}" >  ${WKGBASE}/${ROOTFS}/etc/init-system.conf

[ -f ${WKGBASE}/${ROOTFS}/etc/PUPPY_SPECS ] && sed -i -e 's#HYBRID_DISTRO=.*#HYBRID_DISTRO="no"#g' ${WKGBASE}/${ROOTFS}/etc/PUPPY_SPECS

cp -f ${WKGBASE}/external-tools/update-system-packages ${WKGBASE}/${ROOTFS}/usr/local/bin/update-system-packages

echo "" > ${WKGBASE}/${ROOTFS}/etc/resolv.conf
echo "" > ${WKGBASE}/${ROOTFS}/etc/machine-id

[ -e ${WKGBASE}/${ROOTFS}/etc/os-release ] && rm -f ${WKGBASE}/${ROOTFS}/etc/os-release

. ${WKGBASE}/DISTRO_SPECS

cat > ${WKGBASE}/${ROOTFS}/etc/os-release <<EOF
NAME="${OS_RELEASE_NAME}"
ID=debian
PRETTY_NAME="${OS_RELEASE_PRETTY_NAME}"
VERSION="${DISTRO_VERSION}"
VERSION_ID=${DISTRO_VERSION}
VERSION_CODENAME=${DEBIAN_VERSION_NAME}
ID_LIKE=debian
HOME_URL="https://puppylinux.com"
SUPPORT_URL="https://forum.puppylinux.com"
BUG_REPORT_URL="https://forum.puppylinux.com"
CPE_NAME="cpe:/o:puppy:puppy:${DISTRO_VERSION}"
LOGO=puppy
VARIANT="${DISTRO_NAME} (Debian-based)"
RELEASE_TYPE="rolling"
EOF

echo "" > ${WKGBASE}/${ROOTFS}/etc/xdg/kcm-about-distrorc

[ -f ${WKGBASE}/${ROOTFS}/etc/skel/.face ] && cp -f ${WKGBASE}/${ROOTFS}/etc/skel/.face ${WKGBASE}/${ROOTFS}/root/.face

for issuef in issue issue.net
do
 echo "${OS_RELEASE_PRETTY_NAME}" > ${WKGBASE}/${ROOTFS}/etc/${issuef}
done

chroot ${WKGBASE}/${ROOTFS} update-cache.sh y

echo
echo "===> Cleaning up mounts..."
unmount_system

echo
echo "===> Done.  puppy rootfs is ready!"
