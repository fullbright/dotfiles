#!/usr/bash

CURRENT_USER=$(whoami)

echo "Current user is $CURRENT_USER"

echo "=== Installing base components"
curl -s https://raw.githubusercontent.com/fullbright/historycrawler/master/install_base_tools.sh | sudo sh /dev/stdin $CURRENT_USER

echo "=== Installing dev components"
curl -s https://raw.githubusercontent.com/fullbright/xfce-laptop-config/master/install_dev_tools.sh | sudo sh /dev/stdin $CURRENT_USER

echo "=== Installing baobab for disk analysis and conky"
sudo apt-get install baobab conky conky-all pydf htop -y
sudo -u $CURRENT_USER git clone https://github.com/fullbright/conky.git ~/.conky

echo "=== Pulling configuration from git repo"
cd ~
sudo -u $CURRENT_USER git init
sudo -u $CURRENT_USER git remote add origin https://github.com/fullbright/xfce-laptop-config.git
sudo -u $CURRENT_USER git fetch --all
sudo -u $CURRENT_USER git reset --hard origin/master
#sudo -u $CURRENT_USER git clone https://github.com/fullbright/xfce-laptop-config.git  ~/ --depth 1

echo "=== Installating custom applications: Filezilla, vlc, audacity, Inkscape"
# Undistractme, redshift, Filezilla, vlc, audacity, Inkscape
sudo apt-get install undistract-me redshift redshift-gtk plasma-applet-redshift-control vlc browser-plugin-vlc filezilla audacity inkscape -y

echo "=== Installing diodon"
sudo add-apt-repository ppa:diodon-team/stable -y
sudo apt-get update
sudo apt-get install -y diodon

# Google chrome
echo "=== Installing Google Chrome"
sudo sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo apt-get update
sudo apt-get install google-chrome-stable -y

# Install Grive2 for Google Drive sync
sudo apt-get install git cmake build-essential libgcrypt11-dev libyajl-dev \
    libboost-all-dev libcurl4-openssl-dev libexpat1-dev libcppunit-dev binutils-dev \
    debhelper zlib1g-dev dpkg-dev pkg-config -y
sudo -u $CURRENT_USER git clone https://github.com/vitalif/grive2
cd grive2
mkdir build
cd build
sudo -u $CURRENT_USER cmake ..
sudo -u $CURRENT_USER make -j4
sudo make install

# Arc theme
echo "=== Installing arc theme"
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/Horst3180/xUbuntu_16.04/ /' >> /etc/apt/sources.list.d/arc-theme.list"
wget http://download.opensuse.org/repositories/home:Horst3180/xUbuntu_16.04/Release.key
sudo apt-key add - < Release.key
sudo apt-get update
sudo apt-get install arc-theme -y
rm Release.key

# Recent notifications
echo "=== Installing recent notifications"
sudo add-apt-repository ppa:jconti/recent-notifications
sudo apt-get update
sudo apt install indicator-notifications -y

# Albert
echo "=== Installing albert"
#wget -nv -O Albert_Release.key https://build.opensuse.org/projects/home:manuelschneid3r/public_key
#sudo apt-key add - < Albert_Release.key
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/manuelschneid3r/xUbuntu_18.04/ /' > /etc/apt/sources.list.d/home:manuelschneid3r.list"
sudo apt-get update
sudo apt-get install albert -y

# Configure git credentials typing
echo "=== Configuring git"
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=3600'

echo "Installation finished"

