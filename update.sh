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

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m

#stop service to update system
echo -e "${YELLOW}STOPPING $COIN_NAME SERVICE AND UPDATING SYSTEM...${NC}"
systemctl stop $COIN_NAME.service
apt-get update && apt-get upgrade-y

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

#start daemon service back up
echo -e "${YELLOW}BINARIES HAVE BEEN UPDATED AND NOW STARTING $COIN_NAME SERVICE PLEASE WAIT 30 SEC FOR INFO...${NC}"
echo -e "${YELLOW}YOU WILL NEED TO RESTART YOUR MASTERNODE FROM THE CONTROL WALLET...${NC}"
systemctl start $COIN_NAME.service
sleep 30
echo -e "${YELLOW}GETTING INFO...${NC}"
$COIN_CLI getinfo
sleep 2
