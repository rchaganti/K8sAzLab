#!/bin/sh
USERNAME=$1
PASSWORD=$2
SHARE=$3

mkdir /mnt/share
if [ ! -d "/etc/smbcredentials" ]; then
    mkdir /etc/smbcredentials
fi
if [ ! -f /etc/smbcredentials/smb.cred ]; then
    bash -c 'echo "username=$USERNAME" >> /etc/smbcredentials/smb.cred'
    bash -c 'echo "password=hxFHfgbmObtVqBt36cNX5pe/jExijCsQ1LF4+VxkqX1tDMQaSaEK3pw2blpI+XVPxSjH4y3ztxnp+AStNFKHSA==" >> /etc/smbcredentials/smb.cred'
fi
chmod 600 /etc/smbcredentials/smb.cred
sudo mount -t cifs $SHARE /mnt/share -o credentials=/etc/smbcredentials/smb.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30