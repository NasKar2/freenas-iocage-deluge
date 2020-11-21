# freenas-iocage-deluge

https://github.com/NasKar2/freenas-iocage-deluge.git

Scripts to create an iocage jail on Freenas 11.3U2

Deluge  will be placed in a jail with separate data directory (/mnt/v1/apps/deluge) to allow for easy reinstallation/backup.

Deluge  will be installed with the default user/group (media/media) to match other apps

Deluge will download to the <POOL_PATH>/<TORRENTS_LOCATION>/deluge directory by default in my system "/mnt/v1/torrent/deluge"


## Prerequisites
Edit file deluge-config

- JAIL_IP : The IP address of this jail
- DEFAULT_GW_IP : Default gateway

```
JAIL_IP="192.168.5.86"
DEFAULT_GW_IP="192.168.5.1"
```

### Optional Parameters

- JAIL_NAME : Defaults to "deluge"
- INTERFACE : Defaults to "vnet0"
- VNET : Defaults to "on"
- POOL_PATH : Defaults to your pool in my system it is "/mnt/v1"
- APPS_PATH : Defaults to "apps"
- DELUGE_DATA : Defaults to "deluge" in my system it is "/mnt/v1/apps/deluge"
- MEDIA_LOCATION : Defaults to "media"
- TORRENTS_LOCATION : Defaults to "torrents"

```
JAIL_IP="192.168.5.86"
DEFAULT_GW_IP="192.168.5.1"
JAIL_NAME="deluge"
INTERFACE="vnet0"
VNET="on"
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
DELUGE_DATA="deluge"
MEDIA_LOCATION="media"
TORRENTS_LOCATION="torrents"

```

## OpenVPN setup

If you are going to going to use the vpn, you will need add a preinit task in the webui to run the following command as well as run it once before you setup the jail. This adds a rule to t>
devfs rule -s 4 add path 'tun*' unhide

Firewall kill switch to turn off deluge if the VPN goes down is setup by default in the ipfw_rules file.  Appropriate changes to the file are performed by the script.

Create openvpn.conf and pass.txt files in configs directory. Example files shown, you have to edit the details with info supplied by your VPN provider.
```
client
dev tun
proto udp
remote vpnaddress.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
persist-remote-ip
ca vpn.crt

tls-client
remote-cert-tls server
#auth-user-pass
auth-user-pass /config/pass.txt
comp-lzo
verb 3

auth SHA256
cipher AES-256-CBC

<ca>
-----BEGIN CERTIFICATE-----
MIIESDC...............
-----END CERTIFICATE-----
</ca>

```
pass.txt
```
vpn_username
vpn_password
```


## Install Deluge in a Jail

Run this command to install deluge

```
./delugeinstall.sh
```

# Issues


