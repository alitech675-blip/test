#!/bin/bash

# Color schema

red='\033[01;31m'
blue='\033[01;34m'
green='\033[01;32m'
norm='\033[00m'

# Temporary colors
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
NORMAL="$(tput sgr0)"

# smallLoader colors

CSI="\033["
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CPURPLE="${CSI}1;35m"
CCYAN="${CSI}1;36m"
CBROWN="${CSI}0;33m"

txtgreen=$(tput bold ; tput setaf 2) # GreenBold
txtyellow=$(tput bold ; tput setaf 3) # YellowBold

# Setting for the new UTF-8 terminal support in Lion
locale-gen en_US.UTF-8  >> /dev/null 2>&1
export LANG="en_US.UTF-8" >> /dev/null 2>&1

# Spinner

function _spinner() {

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

    case $1 in
        start)
            let column=$(tput cols)-${#2}-8
            echo -ne ${2}
            printf "%${column}s"

            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${green}${on_success}${nc}"
            else
                echo -en "${red}${on_fail}${nc}"
            fi
            echo -e "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    _spinner "start" "${1}" &
    _sp_pid=$!
    disown
}

function stop_spinner {
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

# smallLoader

smallLoader() {
    echo ""
    echo ""
    echo -ne '[ + + +             ] 3s \r'
    sleep 1
    echo -ne '[ + + + + + +       ] 2s \r'
    sleep 1
    echo -ne '[ + + + + + + + + + ] 1s \r'
    sleep 1
    echo -ne '[ + + + + + + + + + ] Press [Enter] to continue... \r'
    echo -ne '\n'

    read -r
}



VER="v6.3"
PRODUCT="Xtream-Masters Multics Panel 3in1"
supported="    Ubuntu 18 amd64 / Ubuntu 20 / Ubuntu 22 "
architecture="    Required Architecture: x86_64 GNU/Linux "
WEB=$(ip route get 8.8.8.8 | head -1 | awk '{print $7}')
WAN="`wget -q -O - http://icanhazip.com/ | tail`"

skipyesno=0

# Ask a yes or no question
# if $skipyesno is 1, always Y
# if NONINTERACTIVE environment variable is 1, always Y
yesno () {
  # XXX skipyesno is a global set in the calling script
  # shellcheck disable=SC2154
  if [ "$skipyesno" = "1" ]; then
    return 0
  fi
  if [ "$NONINTERACTIVE" = "1" ]; then
    return 0
  fi
  while read -r line; do
    case $line in
      y|Y|Yes|YES|yes|yES|yEs|YeS|yeS) return 0
      ;;
      n|N|No|NO|no|nO) return 1
      ;;
      *)
      printf "\n${YELLOW}Please enter ${CYAN}[y]${YELLOW} or ${CYAN}[n]${YELLOW}:${NORMAL} "
      ;;
    esac
  done
}

install_msg() {
cat <<EOF

  Welcome to the ${YELLOW}$PRODUCT${NORMAL} installer, version ${YELLOW}$VER${NORMAL}
  This script must be run on a freshly installed supported OS. 
  The systems currently supported by installer.sh are:

EOF
echo "${CYAN}$supported${NORMAL}"
echo "${RED}$architecture${NORMAL}"
cat <<EOF

  If your OS/version/arch is not listed, installation ${RED}will fail${NORMAL}. More
  details about the systems supported by the script can be found here:

  ${UNDERLINE}${CYAN}https://xtream-masters.com/trail_license.php${NORMAL}


EOF
echo "";
  printf " Continue installation? (y/n) "
  if ! yesno; then
    exit
  fi
}

if [ "$skipyesno" -ne 1 ] && [ -z "$setup_only" ]; then
  install_msg
fi

pass=`openssl rand -hex 10`;

# Check the architecture
ARCH=$(uname -m)

# Check if the architecture is not x86_64
if [ "$ARCH" != "x86_64" ]; then
	echo ""
    echo "    Unsupported architecture: $ARCH"
    echo "${RED}$architecture${NORMAL}"
    echo ""
    exit 1
fi

rm -rf /var/lib/dpkg/lock-frontend
rm -rf /var/cache/apt/archives/lock
rm -rf /var/lib/dpkg/lock
yes | head -n 5 | dpkg --configure -a
apt-get update > /dev/null 2>&1
apt-get upgrade -y

start_spinner "â—${CYAN} Updating system security and packages ${NORMAL}â—"

sudo apt-get install -y software-properties-common > /dev/null 2>&1
sudo apt-get update > /dev/null 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -yq > /dev/null 2>&1
sudo add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt-get install unzip nano apache2 wget -y > /dev/null 2>&1

stop_spinner $?

start_spinner "â—${CYAN} Installing Necessary services & packets... ${NORMAL}â—"

# Install Necessary services & packets
sudo apt install apache2 libapache2-mod-php7.4 php7.4 php7.4-common php7.4-mysql php7.4-xml php7.4-xmlrpc php7.4-curl php7.4-gd php7.4-imagick php7.4-cli php7.4-dev php7.4-imap php7.4-mbstring php7.4-opcache php7.4-soap php7.4-zip php7.4-intl -y > /dev/null 2>&1
apt-get install unzip -y > /dev/null 2>&1
apt-get install php7.4-dev -y > /dev/null 2>&1
apt-get install gcc make autoconf libc-dev pkg-config -y > /dev/null 2>&1
sudo apt-get -y install libmcrypt-dev > /dev/null 2>&1

stop_spinner $?

# Apache & Nginx config
start_spinner "â—${CYAN} Now Doing Apache & Extentions config... ${NORMAL}â—"

a2enmod rewrite > /dev/null 2>&1
phpenmod mcrypt > /dev/null 2>&1
cd /etc/apache2/sites-enabled/ > /dev/null 2>&1
sudo apt-get install libapache2-mod-php7.4 -y > /dev/null 2>&1
sudo a2enmod rewrite > /dev/null 2>&1
/etc/init.d/apache2 restart > /dev/null 2>&1
echo "pcre.backtrack_limit=10000000000
extension=/etc/mcrypt.so
extension=/etc/xtreammasters.so" >> "/etc/php/7.4/apache2/php.ini";
echo "pcre.backtrack_limit=10000000000
extension=/etc/mcrypt.so
extension=/etc/xtreammasters.so" >> "/etc/php/7.4/cli/php.ini";
phpenmod mcrypt > /dev/null 2>&1
a2enmod remoteip > /dev/null 2>&1
apt-get update > /dev/null 2>&1
stop_spinner $?


start_spinner "â—${CYAN} Installing and Setting MySQL Server ${NORMAL}â—"

echo "mysql-server mysql-server/root_password password $pass" | sudo debconf-set-selections > /dev/null 2>&1
echo "mysql-server mysql-server/root_password_again password $pass" | sudo debconf-set-selections > /dev/null 2>&1

apt-get install mysql-server mysql-client -y > /dev/null 2>&1

sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/my.cnf > /dev/null 2>&1
mysql -uroot -p$pass -e 'USE mysql; UPDATE `user` SET `Host`="%" WHERE `User`="root" AND `Host`="localhost"; DELETE FROM `user` WHERE `Host` != "%" AND `User`="root"; FLUSH PRIVILEGES;' > /dev/null 2>&1

cd /etc/mysql/conf.d/ > /dev/null 2>&1

wget -q -O strict_mode.cnf https://github.com/alitech675-blip/test/raw/main/strict_mode.cnf > /dev/null 2>&1
echo 'sql_mode=""' >> /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null 2>&1
service mysql restart > /dev/null 2>&1



# Downloading and setup panel.
rm -rf /var/www/html/* > /dev/null 2>&1
cd /root/ > /dev/null 2>&1
rm -rf /root/* > /dev/null 2>&1
wget -O "/root/files.zip" "https://github.com/alitech675-blip/test/releases/download/new/3in1_multics_panel_v6.3.zip" > /dev/null 2>&1
unzip files.zip > /dev/null 2>&1
cp /root/xtreammasters_php7.4.zip /etc/ext.zip
rm -rf /var/www/html > /dev/null 2>&1
mkdir /var/www/html > /dev/null 2>&1
cp /root/multics_panel_v6.3.zip /var/www/html/www.zip
cd /etc/
rm -rf mcrypt.so > /dev/null 2>&1
rm -rf xtreammasters.so > /dev/null 2>&1
unzip ext.zip > /dev/null 2>&1
rm -rf ext.zip > /dev/null 2>&1
cd /var/www/html/
unzip www.zip > /dev/null 2>&1
sudo chmod -R 777 /var/www/* > /dev/null 2>&1
rm -rf *.zip > /dev/null 2>&1
cd /root/
rm -rf /root/* > /dev/null 2>&1

# Create Database 
mysql -u root -p$pass -e "DROP DATABASE IF EXISTS multics_dbv4" > /dev/null 2>&1
mysql -u root -p$pass -e "DROP USER user_multics@localhost;" > /dev/null 2>&1
mysql -u root -p$pass -e "CREATE DATABASE multics_dbv4" > /dev/null 2>&1
mysql -u root -p$pass -e "CREATE USER user_multics@localhost IDENTIFIED BY '$pass';" > /dev/null 2>&1
mysql -u root -p$pass -e "GRANT ALL PRIVILEGES ON multics_dbv4.* TO user_multics@localhost;" > /dev/null 2>&1
mysql -u root -p$pass -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$pass'" > /dev/null 2>&1
mysql -u root -p$pass -e "FLUSH PRIVILEGES" > /dev/null 2>&1

# MySQL Settings
echo 'sql_mode=""' >> /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null 2>&1
echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null 2>&1
cd /var/www/html/
/etc/init.d/mysql restart > /dev/null 2>&1
sleep 5

mysql -uroot -p$pass multics_dbv4 < db.sql > /dev/null 2>&1

stop_spinner $?

# Phing :)
#cd /var/www/stalker_portal/deploy
#sudo phing

#Patch support MAG5xx

start_spinner "â—${CYAN} Now Patching ${CEND} ${YELLOW}$PRODUCT $VER ${NORMAL}â—"
cd /root/
sed -i 's/00000000/'$pass'/g' /var/www/html/config.php > /dev/null 2>&1
sed -i 's/user_multics/root/g' /var/www/html/config.php > /dev/null 2>&1
systemctl restart apache2 > /dev/null 2>&1
sleep 2

stop_spinner $?

echo ""
echo -e "${CCYAN}-----------------------------------------------------------------------${CEND}"
echo ""
echo -e "${CCYAN}[ Congratulation Install Complete, Below is default admin login details. ]${CEND}"
echo ""
echo -e "WEB Interface  : ${CGREEN}http://${WEB}${CEND}"
echo -e "Login Link     : ${CGREEN}http://${WEB}/index.php${CEND}"
echo -e "Admin Username : ${CGREEN}Admin${CEND}"
echo -e "Admin Password : ${CGREEN}qwerty${CEND}"
echo -e "MySQL Pass     : ${CGREEN}${pass}${CEND}"
echo -e "Script by      : ${CGREEN}https://xtream-masters.com${CEND}"
echo ""
echo -e "${CCYAN}-----------------------------------------------------------------------${CEND}"
echo ""
