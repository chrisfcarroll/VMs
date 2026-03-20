if [ ! -s $HOME/.zshrc ] ; then
	cp zshrc $HOME/.zshrc
fi
chsh -s $(which zsh) $USER
#sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -) --unattended"
ZSH= sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1 | tail -15

