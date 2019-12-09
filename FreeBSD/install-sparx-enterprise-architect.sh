echo "
Sparx Enterprise Architecture
as per instructions at https://sparxsystems.com/enterprise_architect_user_guide/14.0/product_information/enterprise_architect_linux.html
"

[ "$(whoami)" = "root" ] && echo "Don't install wine apps as root" && return

[ -z $DISPLAY ] && echo "Can't do Wine installations without a graphical display. To run this over ssh, use ssh -Y to X11 forwarding to your desktop, and have an X11 client (e.g. for macOs, use XQuartz)." && return 


winetricks msxml3
winetricks msxml4
winetricks mdac28

if [ -f easetupfull.msi ] ; then
  wine msiexec /i easetupfull.msi
elif [ -f easetup.msi ] ; then
  wine msiexec /i easetup.msi
else
  echo '
    >>>> Download easetup.msi OR easetupfull.msi 
    from https://sparxsystems.com/products/ea/trial/request.html
    or from your own easetupfull.msi download URL.

    Then run one of :
    wine msiexec /i easetupfull.msi
    wine msiexec /i easetup.msi
  '
fi

