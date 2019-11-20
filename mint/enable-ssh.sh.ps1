apt-get -y install openssh-server
systemctl start sshd
systemctl enable /lib/systemd/system/ssh.service
