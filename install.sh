#!/usr/bin/env bash

set -e pipefail

EXEC_USER=$(logname)
DOTFILES=(.Xresources .aliases .vimrc .xinitrc .zshrc .i3status.conf)

if [ $EUID != 0 ]; then
	sudo "$0" "$@"
	exit $?
fi

echo -e "Running setup script for user \e[94m$EXEC_USER\e[39m"

if [ -f /etc/os-release ]; then
	. /etc/os-release
	OS=$NAME
	VER=$VERSION_ID
	DIST=$ID_LIKE
elif type lsb_release >/dev/null 2>&1; then
	OS=$(lsb_release -si)
	VER=$(lsb_release -sr)
	DIST=debian
elif [ -f /etc/lsb-release ]; then
	. /etc/lsb-release
	OS=$DISTRIB_ID
	VER=$DISTRIB_RELEASE
	DIST=debian
else
	echo -e "\e[41m[Error] Couldn't determine OS Version. Only Arch and Debian based operating systems supported."
	exit 1
fi

echo -e "Found OS \e[94m$OS \e[39mbased on \e[94m$DIST\e[39m."

if [ "$DIST" = "arch" ]; then
	echo -e "Updating \e[94mpacman\e[39m packages."
	pacman -Syu --noconfirm vim i3-wm python python3 nodejs picom feh rofi zsh konsole dolphin curl gcc make
elif [ "$DIST" = "debian" ]; then
	echo -e "Updating \e[94mapt\e[39m packages."
	apt-get update && apt-get -y upgrade
	apt-get install -y vim i3 python python3 nodejs compton feh rofi zsh konsole dolphin curl gcc make
fi


echo -e "Installing \e[94mDocker\e[39m."
echo "Enabling loop devices."
[ ! -f "/etc/modules-load.d/loop.conf" ] && tee /etc/modules-load.d/loop.conf <<< "loop" && modprobe loop
if [ "$DIST" = "arch" ]; then
	pacman -S --noconfirm docker
elif [ "$DIST" = "debian" ]; then
	apt install -y docker.io
fi

systemctl start docker
systemctl enable docker

if [ ! -f "/usr/local/bin/docker-compose" ]; then
	echo -e "Installing \e[94mdocker-compose\e[39m."
	curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
fi

echo -e "Adding user \e[94m$EXEC_USER\e[39m to docker group."
getent group docker || groupadd docker
usermod -aG docker $EXEC_USER

echo "Testing docker installation."
docker run hello-world

echo -e "Copying \e[94mdotfiles\e[39m."

echo "Backing up existing dotfiles to backup"

[ -d "backup" ] && echo -e "\e[91mBackup directory already existing. Attempting to delete existing directory.\e[32m" && rm -r backup/

mkdir backup/

for f in ${DOTFILES[@]}
do
	echo -e "Copying dotfile \e[32m$f\e[39m."
	[ -f "/home/$EXEC_USER/$f" ] && cp /home/$EXEC_USER/$f backup/
       	cp $f /home/$EXEC_USER/
done

[ ! -d "/home/$EXEC_USER/.config/i3/" ] && mkdir -p $(echo "/home/$EXEC_USER/.config/i3/")

if [ "$DIST" = "arch" ]; then
	[ -f "/home/$EXEC_USER/.config/i3/config" ] && cp /home/$EXEC_USER/.config/i3/config backup/i3_config
	cp .config/i3/config_arch /home/$EXEC_USER/.config/i3/config
elif [ "$DIST" = "debian" ]; then
	[ -f "/home/$EXEC_USER/.config/i3/config" ] && cp /home/$EXEC_USER/.config/i3/config backup/i3_config
	cp .config/i3/config_debian /home/$EXEC_USER/.config/i3/config
fi
echo -e "\n\e[32mSetup script completed successfully."
