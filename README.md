# freenas-iocage-deluge

https://github.com/NasKar2/freenas-iocage-deluge.git

Scripts to create an iocage jail on Freenas 11.3U2

Deluge  will be placed in a jail with separate data directory (/mnt/v1/apps/deluge) to allow for easy reinstallation/backup.

Deluge  will be installed with the default user/group (media/media)


## Prerequisites
Edit file deluge-config

Edit deluge-config file with the name of your jail, your network information and directory data name you want to use and location of your media files and torrents.

DELUGE_DATA= will create a data directory /mnt/v1/apps/deluge to store all the data for that app.


TORRENTS_LOCATION will set the location of your torrent files, in this example /mnt/v1/torrents

```
JAIL_IP="192.168.5.51"
DEFAULT_GW_IP="192.168.5.1"
INTERFACE="vnet0"
VNET="on"
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
JAIL_NAME="deluge"
deluge_DATA="deluge"
TORRENTS_LOCATION="torrents"
```

## Install Deluge in a Jail

Run this command to install deluge

```
./delugeinstall.sh
```

# Issues

Current version of libtorrent is not compatable with deluge-cli
