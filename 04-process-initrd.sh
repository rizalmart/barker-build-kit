#!/bin/sh

	[ ! -d ./puppy-livecd-build ] && mkdir -p ./puppy-livecd-build
    [ ! -d ./tmp-build ] && mkdir -p ./tmp-build

	WKBASE=$(pwd)	

	if [ ! -d ${WKBASE}/livecd-files ]; then
	 echo "livecd-files folder is missing"
	 exit 1
	fi

	echo "Processing initrd..."
	
	cp -f ./livecd-files/initrd.xz ./tmp-build #note $WKGMNTPT may be non-linux fs.
	cd ./tmp-build
	unxz initrd.xz
	mkdir initrd-tree-tmp1
	cd initrd-tree-tmp1
	cat ../initrd | cpio -i -d -m
	sync
	rm -f ../initrd
	cp -a -f $WKBASE/DISTRO_SPECS ./DISTRO_SPECS #see earlier.
	
	find . | cpio -o -H newc | xz --check=crc32 --x86 --lzma2=dict=1MB > $WKBASE/puppy-livecd-build/initrd.xz
	
	cd $WKBASE
	rm -rf ./tmp-build
