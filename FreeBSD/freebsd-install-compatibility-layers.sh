export ASSUME_ALWAYS_YES=YES

#------------------------------------------------------------------
#VirtualBox

if [ "VirtualBox" = "$(dmidecode -s system-product-name)" ] ; then
  echo "running in a VirtualBox VM. Installing VirtualBox Extensions."
  pkg install virtualbox-ose-additions virtualbox-ose-kmod

  grep 'vboxdrv_load' /boot/loader.conf || printf '\nvboxdrv_load="YES"' >> /boot/loader.conf

  sysrc vboxguest_enable="YES" vboxservice_enable="YES"

  for u in $(users) ; do 
    [ $u = gdm -o $u = psql ]  && continue
    pw groupmod vboxusers -m $u
    pw groupmod operator -m $u
    echo "
    Access to clipboard sharing requires users added to group wheel,
    which has not been done automatically.
    "
  done

  grep 'SDL_VIDEODRIVER=vgl' /etc/login.conf \
    || sed -i '.bak' 's!:setenv=!:setenv=SDL_VIDEODRIVER=vgl,!' /etc/login.conf \
    && cap_mkdb /etc/login.conf
  
fi


#--------------------------------------------------------------------
# See https://wiki.winehq.org/FreeBSD for the state of play and the 
# recommendation to use i386-wine

echo "
Installing wine. Using x86 compatibility because lots of Windows still need it.
"
pkg install i386-wine-devel winetricks crosextrafonts-carlito



#--------------------------------------------------------------------
echo "
  Linux compatibility : using linux_base-c7. You might prefer linux-c7 instead, which is bigger.
  "

pkg install linux_base-c7

if grep "linprocfs" /etc/fstab ; then
  echo "linprocfs done"
else
  echo "Adding linprocfs   /compat/linux/proc  linprocfs rw  0 0 to /etc/fstab" 
  printf "\nlinprocfs \t//compat/linux/proc \tlinprocfs \trw \t0 \t0" >> /etc/fstab
fi
if grep "linsysfs" /etc/fstab ; then
  echo "linsysfs done"
else
  echo "Adding linsysfs    /compat/linux/sys linsysfs  rw  0 0 to /etc/fstab" 
  printf "\nlinsysfs \t/compat/linux/sys \tlinsysfs \trw \t0 \t0" >> /etc/fstab
fi
if grep "tmpfs" /etc/fstab ; then
  echo "tmpfs done"
else
  echo "Adding tmpfs    /compat/linux/dev/shm  tmpfs rw,mode=1777  0 0 to /etc/fstab" 
  printf "\ntmpfs \t/compat/linux/dev/shm \ttmpfs \trw,mode=1777 \t0 \t0" >> /etc/fstab
fi

mount /compat/linux/sys
mount /compat/linux/proc
mount /compat/linux/dev/shm

#--------------------------------------------------------------------
echo "
  Java - OpenJDK 13"

pkg install openjdk13

if grep -E "fdesc.+/dev/fd" /etc/fstab ; then
  echo "/etc/fstab done"
else
  echo "doing /etc/fstab" 
  printf "\nfdesc \t/dev/fd \tfdescfs \trw \t0 \t0" >> /etc/fstab
fi

grep 'JDK_HOME=/usr/local/openjdk13' /etc/login.conf \
  || sed -i '.bak' 's!:setenv=!:setenv=JDK_HOME=/usr/local/openjdk13,!' /etc/login.conf \
  && cap_mkdb /etc/login.conf

