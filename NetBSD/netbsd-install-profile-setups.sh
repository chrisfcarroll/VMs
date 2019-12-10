if grep '#Aliases' ~/.profile ; then 
  echo "#Aliases section already found"
else 
  echo "#Aliases
alias pinstall='pkgin -y install'
" >> ~/.profile
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

if grep 'colorscheme' ~/.vimrc ; then 
  echo ".vimrc already found"
else 
  echo "
syntax on
colorscheme desert
" >> ~/.vimrc
fi
