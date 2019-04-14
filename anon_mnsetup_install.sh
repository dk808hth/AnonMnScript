#!/bin/bash

COIN_NAME='ANON' #no spaces

#wallet information
WALLET_DOWNLOAD='https://www.dropbox.com/s/raw/7vn2lr7sqf1vmqf/anon-16.04.zip'
WALLET_DOWNLOAD1='https://www.dropbox.com/s/raw/oft971r5tv4py1e/anon-18.04.zip'
WALLET_ZIP='anon-16.04.zip'
WALLET_ZIP1='anon-18.04.zip'
CONFIG_FOLDER='/root/.anon'
CONFIG_FILE='anon.conf'
COIN_DAEMON='anond'
COIN_CLI='anon-cli'
COIN_PATH='/usr/local/bin'
PORT='33130'
RPCPORT='33129'
SSHPORT=22
USERNAME=$LOGNAME

WANIP=$(wget http://ipecho.net/plain -O - -q)

BOOTSTRAP='https://assets.anonfork.io/anon-bootstrap.tar.gz'
BOOTSTRAP_ZIP='anon-bootstrap.tar.gz'

FETCHPARAMS='https://raw.githubusercontent.com/anonymousbitcoin/anon/master/anonutil/fetch-params.sh'

CYAN='\033[1;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

#end of required details
#
#
#

# set var SSHPORT by user imput if not default this is used for UFW firewall settings
searchString="Port 22"
file="/etc/ssh/sshd_config"
if grep -Fq "$searchString" $file ; then
    echo -e "SSH is currently set to the default port 22."
else
    echo -e "Looks like you have configured a custom SSH port..."
    echo -e
    read -p 'Enter your custom SSH port, or hit [ENTER] for default: ' SSHPORT
	  if [ -z "$SSHPORT" ]; then
      SSHPORT=22
    fi
fi
echo -e "${YELLOW}Using SSH port:${GREEN}" $SSHPORT
echo -e "${NC}"
sleep 2

echo -e "${YELLOW}==============================="
echo -e "$COIN_NAME MASTERNODE INSTALLER"
echo -e "===============================${NC}"
echo -e "${YELLOW}Installing packages and updates...${NC}"
sudo apt-get update -y &> /dev/null
sudo apt-get install software-properties-common -y &> /dev/null
sudo apt-get update -y &> /dev/null
sudo apt-get upgrade -y &> /dev/null
sudo apt-get install nano htop pwgen ufw figlet -y &> /dev/null
echo "....."
sudo apt-get install build-essential libtool pkg-config -y &> /dev/null
echo "...."
sudo apt-get install libc6-dev m4 g++-multilib -y &> /dev/null
echo "..."
sudo apt-get install autoconf ncurses-dev unzip git python python-zmq -y &> /dev/null
echo ".."
sudo apt-get install wget curl bsdmainutils automake -y &> /dev/null
echo "."
sudo apt-get install python-virtualenv virtualenv -y &> /dev/null
echo "Packages complete..."

WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
PASSWORD=$(pwgen -1 20 -n)
if [ "x$PASSWORD" = "x" ]; then
    PASSWORD=${WANIP}-$(date +%s)
fi

#Create swap
echo -e "${YELLOW}CREATING SWAP...${NC}"
total_mem=$(free -m | awk '/^Mem:/{print $2}')
total_swap=$(free -m | awk '/^Swap:/{print $2}')
total_m=$(($total_mem + $total_swap))
if [ $total_m -lt 4000 ]; then
if ! grep -q '/swapfile' /etc/fstab ; then
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
fi

#Downloading bins currently only for Ubuntu 16.04 & 18.04
echo -e "${YELLOW}DETECTING UBUNTU VERSION TO DOWNLOAD CORRECT BINARIES...${NC}"
if [[ $(lsb_release -r) = *18.04* ]]
then
  echo -e "${YELLOW}Downloading binaries for Ubuntu 18.04...${NC}"
  wget -U Mozilla/5.0 $WALLET_DOWNLOAD1
  unzip $WALLET_ZIP1 -d /usr/local/bin/
  chmod 755 /usr/local/bin/anon*
else
  if [[ $(lsb_release -r) = *16.04* ]]
  then
    echo -e "${YELLOW}Downloading binaries for Ubuntu 16.04...${NC}"
    wget -U Mozilla/5.0 $WALLET_DOWNLOAD
    unzip $WALLET_ZIP -d /usr/local/bin/
    chmod 755 /usr/local/bin/anon*
  fi
fi

#Create intitial conf file
echo -e "${YELLOW}CREATING INITIAL CONF FILE...${NC}"
RPCUSER=$COIN_NAME
PASSWORD=$(pwgen -1 20 -n)
mkdir $CONFIG_FOLDER
touch $CONFIG_FOLDER/$CONFIG_FILE
cat <<EOF > $CONFIG_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$PASSWORD
rpcallowip=127.0.0.1
port=$PORT
rpcport=$RPCPORT
daemon=1
txindex=1
addnode=explorer.anonfork.io
addnode=explorer.anon.zeltrez.io
maxconnections=256
EOF

#Bootstrap to sync quick
echo -e "${YELLOW}DOWNLOADING BOOTSTRAP FOR QUICK SYNCING...${NC}"
wget -c $BOOTSTRAP -O - | tar -xz -C /root/.anon/ &> /dev/null
rm -rf $BOOTSTRAP_ZIP

#Download params
echo -e "${YELLOW}DOWNLOADING CHAIN PARAMS...${NC}"
wget $FETCHPARAMS
bash fetch-params.sh

#Install Sentinel
echo "${YELLOW}INSTALLING SENTINEL...${NC}"
cd
git clone https://github.com/anonymousbitcoin/sentinel.git && cd sentinel
virtualenv ./venv
venv/bin/pip install -r requirements.txt

#sentinel conf
SENTINEL_CONF=$(cat <<EOF
anon_conf=/$USERNAME/.anon/anon.conf
db_name=/$USERNAME/sentinel/database/sentinel.db
db_driver=sqlite
network=mainnet
EOF
)

#Configure Sentinel
echo -e "${YELLOW}CONFIGURING SENTINEL AND CRON JOB...${NC}"
echo "$SENTINEL_CONF" > ~/sentinel/sentinel.conf
cd
crontab -l > tempcron
echo "* * * * * cd /$USERNAME/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> tempcron
crontab tempcron
rm tempcron

#Download update script for later use
echo -e "${YELLOW}DOWNLOADING UPDATE SCRIPT FOR LATER USE TO EASILY UPDATE BINARIES...${NC}"
wget https://raw.githubusercontent.com/dk808hth/AnonMnScript/master/update.sh && chmod +x update.sh

#Basic security
echo -e "${YELLOW}CONFIGURING FIREWALL AND ENABLING FAIL2BAN...${NC}"
ufw allow $PORT/tcp
ufw allow $RPCPORT/tcp
ufw allow $SSHPORT/tcp
ufw logging on
ufw default deny incoming
ufw default allow outgoing
echo "y" | ufw enable >/dev/null 2>&1
systemctl enable fail2ban >/dev/null 2>&1
systemctl start fail2ban >/dev/null 2>&1

#Create daemon service
echo -e "${YELLOW}CREATING DAEMON SERVICE FILE...${NC}"
touch /etc/systemd/system/$COIN_NAME.service
cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
Type=forking
User=$USERNAME
Group=$USERNAME
WorkingDirectory=/$USERNAME/.anon/
ExecStart=$COIN_PATH/$COIN_DAEMON -datadir=/$USERNAME/.anon/ -conf=/$USERNAME/.anon/$CONFIG_FILE -daemon
ExecStop=-$COIN_PATH/$COIN_CLI stop
Restart=always
RestartSec=3
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
sleep 3
echo -e "${GREEN}ENABLING SERVICE FOR ANON TO AUTOSTART ON REBOOT...${NC}"
systemctl enable $COIN_NAME.service &> /dev/null

echo -e "${GREEN}STARTING ANON SERVICE PLEASE WAIT PATIENTLY...${NC}"
systemctl start $COIN_NAME.service >/dev/null 2>&1
sleep 120

#Create genkey
echo -e "${YELLOW}MAKING GENKEY AND FINALIZING CONF...${NC}"
GENKEY=$($COIN_CLI masternode genkey)

#Append masternode info to conf
cat <<EOF >> $CONFIG_FOLDER/$CONFIG_FILE
masternode=1
masternodeprivkey=$GENKEY
externalip=$WANIP
bind=$WANIP
logtimestamps=1
server=1
listen=1
EOF
sleep 5

#Get info
$COIN_CLI getinfo
sleep 5

echo -e "${YELLOW}==================================================================================================${NC}"
echo
echo "COPY THIS TO MASTERNODE CONF FILE AND REPLACE TxID and OUTPUT"
echo "WITH THE DETAILS FROM YOUR COLLATERAL TRANSACTION"
echo -e "${YELLOW}MN1 $WANIP:$PORT $GENKEY TxID OUTPUT${NC}"
echo "Courtesy of AltTank Fam and DK808"
echo
echo "FOLLOWING COMMANDS TO MANAGE $COIN_NAME SERVICE"
echo -e "  TO START- ${GREEN}systemctl start $COIN_NAME.service${NC}"
echo -e "  TO STOP - ${GREEN}systemctl stop $COIN_NAME.service${NC}"
echo -e "  STATUS  - ${GREEN}systemctl status $COIN_NAME.service${NC}"
echo -e "IN THE EVENT SERVER ${RED}REBOOTS${NC} DAEMON SERVICE WILL ${GREEN}AUTO START${NC}"
echo 
echo "TO UPDATE RUN FOLLOWING COMMAND. MAKE SURE WITH ADMINS FIRST THAT LINKS ARE UPDATED W/NEW BINS BEFORE RUNNING UPDATE SCRIPT."
echo -e "${YELLOW}./update.sh"${NC}    ${CYAN}<========= THAT IS COMMAND TO UPDATE${NC}
echo
echo -e "${YELLOW}==================================================================================================${NC}"
sleep 1
