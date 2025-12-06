#!/bin/bash

# 0. Install essential build tools
echo ">>> Installing build dependencies"
apt update
apt install -y \
  musl musl-dev musl-tools build-essential curl wget git \
  pkg-config autoconf automake libtool bison flex \
  libssl-dev libudev-dev libblkid-dev uuid-dev libpopt-dev \
  libdevmapper-dev libfuse-dev fuse libncurses-dev \
  zlib1g-dev libbz2-dev libselinux-dev

# Prepare output directory
OUTDIR="$HOME/static-musl-bin"
mkdir -p "$OUTDIR"
JOBS=$(nproc)
export CC="musl-gcc -static"

export FORCE_UNSAFE_CONFIGURE=1

# Download & install terminfo files (xterm, rxvt)
echo ">>> Installing terminfo files"
TERMINFO_DIR="$OUTDIR/terminfo"
mkdir -p "$TERMINFO_DIR"
tic -x -o "$TERMINFO_DIR" <(infocmp xterm)
tic -x -o "$TERMINFO_DIR" <(infocmp rxvt)

# Setup build directory
mkdir -p build && cd build

build_static() {
	
    local name="$1"
    local url="$2"
    local configure_args="$3"

	mkdir -p ./${name}

    # Download
    wget -O "${name}.src" "$url"

    # Extract based on file type
    case "$url" in
        *.tar.gz|*.tgz)   tar -xvzf "${name}.src"; TOPFLD=$(tar -tf "${name}.src" | cut -d/ -f1 | sort -u | head -1);;
        *.tar.xz)         tar -xvJf "${name}.src"; TOPFLD=$(tar -tf "${name}.src" | cut -d/ -f1 | sort -u | head -1);;
        *.tar.bz2)        tar -xvjf "${name}.src"; TOPFLD=$(tar -tf "${name}.src" | cut -d/ -f1 | sort -u | head -1);;
        *.zip)            unzip -o "${name}.src"; TOPFLD=$(unzip -l "${name}.src" | awk '{print $4}' | grep / | cut -d/ -f1 | sort -u | head -1);;
        *) echo "Unknown archive type for $url"; exit 1 ;;
    esac

    # Enter extracted folder
    [ "$TOPFLD" != "" ] && cd ./"$TOPFLD"
    
    [ ! -f ./configure ] && ./autogen.sh

    # Configure & build
    ./configure --prefix=/usr/local --enable-static --disable-shared $configure_args
    make -j$(nproc) CC=musl-gcc
    make DESTDIR="$PWD/../install" install

    [ "$TOPFLD" != "" ] && cd ..
    
}


# 1. busybox
build_static busybox "https://busybox.net/downloads/busybox-1.37.0.tar.bz2" "--static"

# 2. btrfs-progs
build_static btrfs-progs "https://mirrors.edge.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v6.9.tar.xz" ""

# 3. Coreutils 9.5 with advcpmv patch for cp/mv
echo ">>> Building coreutils 9.5 with advcpmv patch"
COREUTILS_VER="9.5"
wget -q "https://ftp.gnu.org/gnu/coreutils/coreutils-$COREUTILS_VER.tar.xz"
tar xf coreutils-$COREUTILS_VER.tar.xz
cd coreutils-$COREUTILS_VER
wget -q "https://raw.githubusercontent.com/jarun/advcpmv/master/advcpmv-0.9-$COREUTILS_VER.patch"
patch -p1 -i "advcpmv-0.9-$COREUTILS_VER.patch"
./configure --enable-static --disable-shared
make -j"$JOBS" src/cp src/mv
cp src/cp "$OUTDIR/advcp"
cp src/mv "$OUTDIR/advmv"
cd ..

# 4. cryptsetup (LUKS1)
build_static cryptsetup "https://www.kernel.org/pub/linux/utils/cryptsetup/v2.8/cryptsetup-2.8.0.tar.xz" "--disable-veritysetup --disable-integritysetup --disable-cryptsetup-reencrypt"

# 5. dialog
build_static dialog "https://invisible-mirror.net/archives/dialog/dialog.tar.gz" ""

# 6. e2fsprogs (e2fsck, resize2fs)
build_static e2fsprogs "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.xz" ""

# 7. exfat-fuse (mount.exfat-fuse)
build_static exfat-utils "https://github.com/relan/exfat/releases/download/v1.4.0/exfat-utils-1.4.0.tar.gz" ""

# 8. fsck.f2fs
build_static fsck.f2fs "https://github.com/tytso/fs-fsun/f2fs-tools/archive/refs/heads/master.tar.gz" ""

# 9. fsck.fat (dosfstools)
build_static dosfstools "https://github.com/dosfstools/dosfstools/archive/refs/heads/master.zip" ""

# 10. grep
build_static grep "https://ftp.gnu.org/gnu/grep/grep-3.11.tar.xz" ""

# 11. losetup-222 from util-linux 2.22
echo ">>> Building losetup-222"
wget -q "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.22/util-linux-2.22.tar.gz"
tar xf util-linux-2.22.tar.gz
cd util-linux-2.22
./configure --disable-all-programs --enable-losetup --enable-static
make -j"$JOBS" losetup
cp losetup "$OUTDIR/losetup-222"
cd ..

# 12. nano
build_static nano "https://www.nano-editor.org/dist/v7/nano-7.2.tar.gz" ""

# 13. ntfs-3g & ntfsfix
echo ">>> Building ntfs-3g & ntfsfix"
wget -q "https://github.com/tuxera/ntfs-3g/archive/refs/heads/edge.zip"
tar xf ntfs-3g_ntfsprogs-2021.8.22.tgz
cd ntfs-3g_ntfsprogs-2021.8.22
./configure --enable-static --disable-shared
make -j"$JOBS"
cp ntfsfix "$OUTDIR/"
cd ..

# 14. vercmp from woof‑CE
echo ">>> Building vercmp"
mkdir vercmp && cd vercmp
wget -qO vercmp.c "https://raw.githubusercontent.com/puppylinux-woof-CE/initrd_progs/refs/heads/master/pkg/w_apps_static/w_apps/vercmp.c"
$CC -o vercmp vercmp.c
cp vercmp "$OUTDIR/"
cd ..

cd ..

echo "✅ Build complete. Static binaries are in: $OUTDIR"
ls -lh "$OUTDIR"
