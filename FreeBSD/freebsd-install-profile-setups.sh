[ -f /usr/local/etc/doas.conf ] \
  && grep "permit nopass $USER" /usr/local/etc/doas.conf \
  || su root -c "echo \"permit nopass $USER\" >> /usr/local/etc/doas.conf"

if [ -z "$(grep '#Aliases' ~/.profile)" ] ; then 
  echo "#Aliases
alias pinstall='env ASSUME_ALWAYS_YES=YES pkg install'
" >> ~/.profile
else 
  echo "#Aliases section already found"
fi

[ -f ~/.vimrc ] || touch ~/.vimrc

if [ -z "$(grep 'colorscheme' ~/.vimrc)" ] ; then 
  echo "
syntax on
colorscheme desert
" >> ~/.vimrc
else 
  echo ".vimrc already found"
fi
