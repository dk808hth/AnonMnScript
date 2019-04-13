#!/bin/bash

COIN_NAME='ANON' #no spaces

#wallet information
WALLET_DOWNLOAD='https://github.com/anonymousbitcoin/anon/releases/download/v2.2.0/Anon-full-node-v.2.2.0-ubuntu-18.tar.gz'
EXTRACT_DIR='' #not always necessary, can be blank if zip/tar file has no subdirectories
CONFIG_FOLDER='/root/.anon'
CONFIG_FILE='anon.conf'
COIN_DAEMON='anond'
COIN_CLI='anon-cli'
COIN_PATH='/usr/bin'
PORT='33130'
RPCPORT='33129'
SSHPORT=22
USERNAME=$LOGNAME

WANIP=$(wget http://ipecho.net/plain -O - -q)

BOOTSTRAP='http://assets.anonfork.io/anon-bootstrap.zip'
BOOTSTRAP_ZIP='anon-bootstrap.zip'

FETCHPARAMS='https://raw.githubusercontent.com/anonymousbitcoin/anon/master/anonutil/fetch-params.sh'

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
echo -e "${YELLOW}Using SSH port:\033[1;32m" $SSHPORT
echo -e "\033[0m"
sleep 2


echo -e "${YELLOW}Using SSH port:${GREEN}" $SSHPORT
echo -e "${NC}"
sleep 2

echo -e "${YELLOW}=================================================================="
echo -e "$COIN_NAME MASTERNODE INSTALLER"
echo -e "==================================================================${NC}"
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
PASSWORD=`pwgen -1 20 -n`
if [ "x$PASSWORD" = "x" ]; then
    PASSWORD=${WANIP}-`date +%s`
fi

function prepare_system() 
{
  clear
  echo -e "Checking if swap space is required."
  local PHYMEM=$(free -g | awk '/^Mem:/{print $2}')
  
  if [ "${PHYMEM}" -lt "2" ]; then
    local SWAP=$(swapon -s get 1 | awk '{print $1}')
    if [ -z "${SWAP}" ]; then
      echo -e "${GREEN}Server is running without a swap file and has less than 2G of RAM, creating a 2G swap file.${NC}"
      dd if=/dev/zero of=/swapfile bs=1024 count=2M
      chmod 600 /swapfile
      mkswap /swapfile
      swapon -a /swapfile
    else
      echo -e "${GREEN}Swap file already exists.${NC}"
    fi
  else
    echo -e "${GREEN}Server running with at least 2G of RAM, no swap file needed.${NC}"
  fi
}

#Downloading bins
wget -c $WALLET_DOWNLOAD -O - | tar -xz -C /usr/local/bin/
cd /usr/local/bin/anon/src/
mv anond anon-cli /usr/local/bin/
cd

function create_initial_config()
{
  echo -e "${YELLOW}CREATING INITIAL CONF FILE${NC}"
  RPCUSER=`pwgen -1 8 -n`
  PASSWORD=`pwgen -1 20 -n`
  touch $CONFIG_FOLDER/$CONFIG_FILE
  cat <<EOF > $CONFIG_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$PASSWORD
rpcallowip=127.0.0.1
port=$PORT
rpcport=$RPCPORT
daemon=1
addnode=explorer.anonfork.io
addnode=explorer.anon.zeltrez.io
maxconnections=256
EOF
}

function download_bootstrap()
{
  echo -e "${YELLOW}DOWNLOADING BOOTSTRAP FOR QUICK SYNCING...${NC}"
  wget -U Mozilla/5.0 $BOOTSTRAP
  mkdir $CONFIG_FOLDER
  unzip $BOOTSTRAP_ZIP -d $CONFIG_FOLDER
  rm -rf $BOOTSTRAP_ZIP
  clear
}

function fetch_params()
{
  echo -e "${YELLOW}DOWNLOADING CHAIN PARAMS${NC}"
  wget $FETCHPARAMS
  bash fetch-params.sh
  clear
}

function install_sentinel()
{
  echo "${YELLOW}INSTALLING SENTINEL${NC}"
  cd
  git clone https://github.com/anonymousbitcoin/sentinel.git
  cd sentinel
  virtualenv ./venv
  venv/bin/pip install -r requirements.txt
  clear
}

#sentinel conf
SENTINEL_CONF=$(cat <<EOF
anon_conf=/home/$USERNAME/.anon/anon.conf
db_name=/home/$USERNAME/sentinel/database/sentinel.db
db_driver=sqlite
network=mainnet
EOF
)

function conf_sentinel()
{
  echo "${YELLOW}CONFIGURING SENTINEL AND CRON JOB...${NC}"
  echo "$SENTINEL_CONF" > ~/sentinel/sentinel.conf
  cd
  crontab -l -echo "* * * * * cd /$USERNAME/sentinel && ./venv/bin/python bin/sentinel.py 2>&1 >> sentinel-cron.log" | crontab 
  clear
}  

function configure_firewall()
{ 
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
}

function create_daemon_service()
{
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
WorkingDirectory=/home/$USERNAME/.anon/
ExecStart=$COIN_PATH/$COIN_DAEMON -datadir=/home/$USERNAME/.anon/ -conf=/home/$USERNAME/.anon/$CONFIG_FILE -daemon
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
  systemctl enable $COIN_NAME.service &> /dev/null

  echo -e "${GREEN}STARTING DAEMON SERVICE FOR ANON${NC}"
  systemctl start $COIN_NAME.service >/dev/null 2>&1
  clear
}

function create_genkey()
{
  echo -e "${YELLOW}MAKING GENKEY...${NC}"
GENKEY=$($COIN_CLI masternode genkey)
clear
}

function finalize_conf()
{
  cat <<EOF > $CONFIG_FOLDER/$CONFIG_FILE
masternode=1
masternodeprivkey=$GENKEY
externalip=$WANIP
bind=$WANIP
logtimestamps=1
server=1
txindex=1
listen=1
maxconnections=256
EOF
}

echo "============================================================================="
echo "COPY THIS TO MASTERNODE CONF FILE AND REPLACE TxID and OUTPUT"
echo "WITH THE DETAILS FROM YOUR COLLATERAL TRANSACTION"
echo -e "${YELLOW}MN1 $WANIP:$PORT $GENKEY TxID OUTPUT${NC}"
echo "Courtesy of AltTank Fam and DK808"
echo
echo "FOLLOWING COMMANDS TO MANAGE $COIN_NAME SERVICE"
echo -e "TO START- ${GREEN}systemctl start $COIN_NAME.service${NC}"
echo -e "TO STOP - ${GREEN}systemctl stop $COIN_NAME.service${NC}"
echo -e "STATUS  - ${GREEN}systemctl stauts $COIN_NAME.service${NC}"
echo "IN THE EVENT SERVER REBOOTS DAEMON SERVICE WILL AUTO START"
echo "============================================================================="
sleep 1
