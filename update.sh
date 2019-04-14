#!/bin/bash

COIN_NAME='ANON'

#  This script will stop daemon, remove old binaries, download latest binaries, and start daemon service.

#wallet info
WALLET_DOWNLOAD='https://www.dropbox.com/s/raw/mte67x69thrlow0/anon-linux.zip'
WALLET_DOWNLOAD1='https://assets.anonfork.io/anon-18.04.zip'
WALLET_ZIP='anon-linux.zip'
WALLET_ZIP1='anon-18.04.zip'
COIN_CLI='anon-cli'
COIN_PATH='/usr/local/bin'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

#stop service to update system
echo -e "${YELLOW}STOPPING $COIN_NAME SERVICE AND UPDATING SYSTEM...${NC}"
systemctl stop $COIN_NAME.service
apt-get update && apt-get upgrade -y

#download bins accordingly to ubuntu version
echo -e "${YELLOW}DETECTING UBUNTU VERSION AND DOWNLOADING BINARIES ACCORDINGLY...${NC}"
if [[ $(lsb_release -r) = *18.04* ]]
then
  echo -e "${GREEN}Downloading binaries for Ubuntu 18.04...${NC}"
  wget -U Mozilla/5.0 $WALLET_DOWNLOAD1
  unzip -o $WALLET_ZIP1 -d $COIN_PATH
  chmod 755 /usr/local/bin/anon*
else
  if [[ $(lsb_release -r) = *16.04* ]]
  then
    echo -e "${GREEN}Downloading binaries for Ubuntu 16.04...${NC}"
    wget -U Mozilla/5.0 $WALLET_DOWNLOAD
    unzip -o $WALLET_ZIP -d $COIN_PATH
    chmod 755 /usr/local/bin/anon*
  fi
fi

#reboot and let daemon service start up
echo -e "${YELLOW}BINARIES HAVE BEEN UPDATED AND NOW REBOOTING SYSTEM $COIN_NAME SERVICE WILL AUTO START THE DAEMON...${NC}"
echo -e "${YELLOW}AFTER SYSTEM REBOOTS SSH BACK INTO SERVER WAIT 1 MIN AND ANON-CLI GETINFO TO CHECK PROTOCOL...${NC}"
echo -e "${YELLOW}YOU WILL ALSO NEED TO RESTART YOUR MASTERNODE FROM THE CONTROL WALLET...${NC}"
echo -e "${RED}REBOOTING IN 30 SECONDS...${NC}"
sleep 30
reboot
