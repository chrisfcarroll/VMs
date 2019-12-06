[ -f ~/.vimrc ] || touch ~/.vimrc

if [ -z "$(grep 'colorscheme' ~/.vimrc)" ] ; then 
  echo "
syntax on
colorscheme desert
" >> ~/.vimrc
else 
  echo ".vimrc already found"
fi
