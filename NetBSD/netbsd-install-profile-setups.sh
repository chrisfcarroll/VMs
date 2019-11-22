if [ -z "$(grep '#Aliases' ~/.profile)" ] ; then 
  echo "#Aliases
alias pinstall='pkgin -y install'
" >> ~/.profile
else 
  echo "#Aliases section already found"
fi

if [ -n "$SU_FROM" -a -z "$(grep '#Aliases' /home/$SU_FROM/.profile)" ] ; then
  echo "#Aliases
pinstall(){
  su - root -c \"pkgin -y install \$*\"
}
[ -z \"\$TMUX\" ] && tmux
" >> /home/$SU_FROM/.profile
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
