#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 or TrueNAS 12.2 with  deluge
# https://github.com/NasKar2/sepapps-freenas-iocage

print_msg () {
  echo
  echo -e "\e[1;32m"$1"\e[0m"
  echo
}

print_err () {
  echo -e "\e[1;31m"$1"\e[0m"
  echo
}

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults
JAIL_IP=""
DEFAULT_GW_IP=""
INTERFACE=""
VNET=""
POOL_PATH=""
APPS_PATH=""
DELUGE_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""
SEED=""

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/deluge-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check for deluge-config and set configuration
if ! [ -e $SCRIPTPATH/deluge-config ]; then
  print_err "$SCRIPTPATH/deluge-config must exist."
  exit 1
fi

# Check that necessary variables were set by deluge-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  INTERFACE="vnet0"
  print_msg "INTERFACE defaulting to 'vnet0'"                                                        
fi
if [ -z $VNET ]; then
  VNET="on"
  print_msg "VNET defaulting to 'on'"
fi

if [ -z $POOL_PATH ]; then
  POOL_PATH="/mnt/$(iocage get -p)"
  print_msg "POOL_PATH defaulting to "$POOL_PATH
fi
if [ -z $APPS_PATH ]; then
  APPS_PATH="apps"
  print_msg "APPS_PATH defaulting to 'apps'"
fi

if [ -z $JAIL_NAME ]; then
  JAIL_NAME="deluge"
  print_msg "JAIL_NAME defaulting to 'deluge'"
fi
if [ -z $DELUGE_DATA ]; then
  DELUGE_DATA="deluge"
  print_msg "DELUGE_DATA defaulting to 'deluge'"
fi
if [ -z $MEDIA_LOCATION ]; then
  MEDIA_LOCATION="media"
  print_msg "MEDIA_LOCATION defaulting to 'media'"
fi
if [ -z $TORRENTS_LOCATION ]; then
  TORRENTS_LOCATION="torrents"
  print_msg "TORRENTS_LOCATION defaulting to 'torrents'"
fi

#
# Create Jail
#echo '{"pkgs":["nano","mono","mediainfo","sqlite3","ca_root_nss","curl"]}' > /tmp/pkg.json
echo '{"pkgs":["nano","curl","deluge-cli","openvpn","ca_root_nss"]}' > /tmp/pkg.json
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}" allow_raw_sockets="1" allow_tun="1"
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

#
# needed for installing from ports
#mkdir -p ${PORTS_PATH}/ports
#mkdir -p ${PORTS_PATH}/db

print_msg "Creating directories and mount points"
mkdir -p ${POOL_PATH}/${APPS_PATH}/${DELUGE_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}/videos/tvshows
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
#chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${DELUGE_DATA}'"

deluge_config=${POOL_PATH}/${APPS_PATH}/${DELUGE_DATA}

iocage exec ${JAIL_NAME} 'sysrc ifconfig_epair0_name="epair0b"'

# create dir in jail for mount points
iocage exec ${JAIL_NAME} mkdir -p /usr/ports
iocage exec ${JAIL_NAME} mkdir -p /var/db/portsnap
iocage exec ${JAIL_NAME} mkdir -p /config
iocage exec ${JAIL_NAME} mkdir -p /mnt/media
iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents/deluge

#
# mount ports so they can be accessed in the jail
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/ports /usr/ports nullfs rw 0 0
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/db /var/db/portsnap nullfs rw 0 0

iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${deluge_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0
 
iocage restart ${JAIL_NAME}
# add media user
print_msg "Add media user"
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /config -s /usr/bin/nologin"  
# add media group to media user
#iocage exec ${JAIL_NAME} pw groupadd -n media -g 8675309
#iocage exec ${JAIL_NAME} pw groupmod media -m media
#iocage restart ${JAIL_NAME} 

iocage exec ${JAIL_NAME} chown -R media:media /config
iocage exec ${JAIL_NAME} sysrc deluged_enable=YES
iocage exec ${JAIL_NAME} sysrc deluged_user=media
iocage exec ${JAIL_NAME} sysrc deluged_group=media
iocage exec ${JAIL_NAME} sysrc deluged_confdir=/config
iocage exec ${JAIL_NAME} sysrc deluge_web_enable=YES
iocage exec ${JAIL_NAME} sysrc deluge_web_user=media
iocage exec ${JAIL_NAME} sysrc deluge_web_group=media
iocage exec ${JAIL_NAME} sysrc deluge_web_confdir=/config

# copy openvpn files from configs dir
print_msg "Copy OpenVPN files and Create tunnel interface"
iocage exec ${JAIL_NAME} cp -f /mnt/configs/ipfw_rules /config/ipfw_rules
iocage exec ${JAIL_NAME} cp -f /mnt/configs/openvpn.conf /config/openvpn.conf
iocage exec ${JAIL_NAME} cp -f /mnt/configs/pass.privado.txt /config/pass.privado.txt

# check tun mumber
iocage exec ${JAIL_NAME} 'ifconfig tun create'
TUN_NUM=$(iocage exec ${JAIL_NAME} ifconfig | grep tun | cut -d : -f1 | grep tun)
echo "TUN_NUM is ${TUN_NUM}"
SUBNET=$(iocage get ip4_addr ${JAIL_NAME} | cut -d / -f2)
echo "SUBNET is ${SUBNET}"
IP_ID=${DEFAULT_GW_IP%.*}".0/"${SUBNET}
echo "IP_ID is ${IP_ID}"
iocage exec ${JAIL_NAME} sed -i '' "s|mytun|${TUN_NUM}|" /config/ipfw_rules
iocage exec ${JAIL_NAME} sed -i '' "s|IP_ID|${IP_ID}|g" /config/ipfw_rules
iocage exec ${JAIL_NAME} sed -i '' "s|dev\ tun|dev\ ${TUN_NUM}|" /config/openvpn.conf



iocage exec ${JAIL_NAME} "chown 0:0 /config/ipfw_rules"
iocage exec ${JAIL_NAME} "chmod 600 /config/ipfw_rules"
iocage exec ${JAIL_NAME} sysrc "firewall_enable=YES"
iocage exec ${JAIL_NAME} sysrc "firewall_script=/config/ipfw_rules"
iocage exec ${JAIL_NAME} sysrc "openvpn_enable=YES"
iocage exec ${JAIL_NAME} sysrc "openvpn_dir=/config"
iocage exec ${JAIL_NAME} sysrc "openvpn_configfile=/config/openvpn.conf"

iocage exec ${JAIL_NAME} service ipfw start
iocage exec ${JAIL_NAME} service openvpn start

# Change deluged_user in deluged
old_user='deluged_user:="asjklasdfjklasdf"'
new_user='deluged_user:="media"'
iocage exec ${JAIL_NAME} sed -i '' "s|${old_user}|${new_user}|" /usr/local/etc/rc.d/deluged

# Change deluge_web_user in deluge_web
old2_user='deluge_web_user:="asjklasdfjklasdf"'
new2_user='deluge_web_user:="media"'
iocage exec ${JAIL_NAME} sed -i '' "s|${old2_user}|${new2_user}|" /usr/local/etc/rc.d/deluge_web
iocage exec ${JAIL_NAME} chown -R media:media /config
iocage exec ${JAIL_NAME} service deluged start
iocage exec ${JAIL_NAME} service deluge_web start

# Adjust core.conf settings
print_msg "Adjust default settings for deluge"
iocage exec ${JAIL_NAME} service deluged stop
#iocage exec ${JAIL_NAME} service deluge_web stop
iocage exec ${JAIL_NAME} sed -i '' 's|"/Downloads"|"/mnt/torrents/deluge"|g' /config/core.conf
echo "*********************"
if [ $SEED == "NO" ]; then
   iocage exec ${JAIL_NAME} sed -i '' 's|"seed_time_ratio_limit": 7|"seed_time_ratio_limit": 0|' /config/core.conf
   iocage exec ${JAIL_NAME} sed -i '' 's|"seed_time_limit": 180|"seed_time_limit": 0|' /config/core.conf
   iocage exec ${JAIL_NAME} sed -i '' 's|"share_ratio_limit": 2|"share_ratio_limit": 0|' /config/core.conf
   iocage exec ${JAIL_NAME} sed -i '' 's|"stop_seed_ratio": 2|"stop_seed_ratio": 0|' /config/core.conf
   iocage exec ${JAIL_NAME} sed -i '' 's|"stop_seed_at_ratio": false|"stop_seed_at_ratio": true|' /config/core.conf
fi
iocage exec ${JAIL_NAME} service deluged start
#iocage restart ${JAIL_NAME} 
echo "deluge should be available at http://${JAIL_IP}:8112"
