#!/usr/bash

CURRENT_USER=$(whoami)

echo "Current user is $CURRENT_USER"

#echo "=== Installing base components"
#curl -s https://raw.githubusercontent.com/fullbright/historycrawler/master/install_base_tools.sh | sudo sh /dev/stdin $CURRENT_USER

# Dev tools
echo "=== Installing dev tools"
sudo apt-get install -y python-virtualenv

# Docker
echo "=== Installing docker"
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update

sudo apt-get install docker-ce -y

sudo groupadd docker
sudo usermod -aG docker $USER
sudo systemctl enable docker

# Install docker-compose
# Compose releases available here : https://github.com/docker/compose/releases
sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Sublime text
echo "=== Installing Sublime text"
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt-get update
sudo apt-get install sublime-text -y

echo "Installation finished"
