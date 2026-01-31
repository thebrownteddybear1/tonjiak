#!/bin/bash
set -x

#install docker compose
# First install Docker from Docker's official repository
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker with Compose plugin included
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Then use it as:
docker compose version


#disable ufw

systemctl disable ufw
systemctl stop ufw

# permit root login
sudo sed -i '/^PermitRootLogin/d; $ a\PermitRootLogin yes' /etc/ssh/sshd_config
sudo systemctl restart sshd

# clone docker.image
cd /root
git clone git@github.com:thebrownteddybear1/docker.image.git

# install gh 
#
apt install gh

