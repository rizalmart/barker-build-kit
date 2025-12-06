#!/bin/bash
# Script to install build dependencies for GTK+3, Vala, Python, and systemd-based applications

echo "Updating package lists..."

cat > /etc/dpkg/dpkg.cfg.d/50excldoc <<EOF
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
'

apt install -y $(echo $COMPILER_PKGS | tr '\n' ' ')

echo "All required packages for GTK+3, Vala, Python, and systemd application compilation have been installed."

for src1 in $(ls /puppy-source-builds)
do
  /puppy-source-builds/$src1
done
