#!/bin/sh
#Force update cache files
#written by mistfire

GTKVERLIST='1.0 2.0 3.0 4.0 5.0 6.0'
ARCH=`uname -m`

SKIPDEPMOD="$1"

uLIBs=`echo $LD_LIBRARY_PATH | tr ':' ' '`

if [ "$XDG_DATA_DIRS" != "" ]; then
 SHAREPATH=`echo $XDG_DATA_DIRS | tr ':' ' '`
else
 SHAREPATH="/usr/share /usr/local/share"
fi

echo "Updating gio modules..."

for uLIB in $uLIBs
do
 [ -e $uLIB/gio/modules ] && gio-querymodules $uLIB/gio/modules	
done

echo "Updating gdk pixbuf..."

if [ "$(which update-gdk-pixbuf-loaders)" != "" ]; then
 update-gdk-pixbuf-loaders
else
 gdk-pixbuf-query-loaders --update-cache
fi

echo "Updating pango..."

if [ "$(which update-pango-querymodules)" != "" ]; then
 update-pango-querymodules
elif [ "$(which pango-querymodules)" != "" ]; then
 pango-querymodules --update-cache
fi


echo "Updating gtk im modules..."

for gtkver in $GTKVERLIST
do
 if [ "$(which gtk-query-immodules-$gtkver)" != "" ]; then 
  if [ $(which update-gtk-immodules-$gtkver) != "" ]; then
   update-gtk-immodules-$gtkver
  else
   gtk-query-immodules-$gtkver --update-cache
  fi
 fi
done

for usrdata in $SHAREPATH
do
 
 echo "Updating glib schema on $usrdata/glib-2.0/schemas ..."
 
 [ -e $usrdata/glib-2.0/schemas ] && glib-compile-schemas $usrdata/glib-2.0/schemas 2>/dev/null
 
 echo "Updating mime cache on $usrdata/mime ..."
 [ -e $usrdata/mime ] && update-mime-database $usrdata/mime 2>/dev/null
 
 if [ -e $usrdata/applications ]; then
  echo "Updating desktop icons on $usrdata/applications ..."
  rm -f $usrdata/applications/mimeinfo.cache 2>/dev/null
  update-desktop-database $usrdata/applications 2>/dev/null
 fi
 
 echo "Updating icon cache on $usrdata/icons ..." 
 
 for gtkcmd in gtk gtk4
 do
   if [ -e /usr/bin/${gtkcmd}-update-icon-cache ] && [ -d $usrdata/icons ] ; then 
	find "$usrdata/icons/" -name "icon-theme.cache" -type f -exec rm -f '{}' \;
	find "$usrdata/icons/" -maxdepth 1 -mindepth 1 -type d -exec ${gtkcmd}-update-icon-cache -f -i '{}' \; 2>/dev/null
	break
   fi
 done
	  
done

echo "Updating gconv cache ..." 
iconvconfig

echo "Updating fontconfig ..." 
fc-cache -f

echo "Updating ldconf ..." 
ldconfig

echo "Updating dconf ..." 
dconf update

echo "Updating udev rules ..."
 
[ "$(udevadm --help 2>&1 | grep hwdb)" != "" ] && udevadm hwdb --update

if [ "$(pidof udevd systemd-udevd)" != "" ]; then 
	udevadm control --reload-rules
	udevadm trigger
fi


if [ "$SKIPDEPMOD" == "" ]; then
 echo "Updating kernel modules ..." 
 depmod -a
fi

grpconv
