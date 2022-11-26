#!/bin/sh
SAACCOUNTNAME=$1
SAKEY=$2
SHARENAME=$3
ROLE=$4

# Mount Azure fileshare
mkdir /mnt/share
if [ ! -d "/etc/smbcredentials" ]; then
    mkdir /etc/smbcredentials
fi
if [ ! -f /etc/smbcredentials/smb.cred ]; then
    bash -c "echo username=${SAACCOUNTNAME} >> /etc/smbcredentials/smb.cred"
    bash -c "echo password=${SAKEY} >> /etc/smbcredentials/smb.cred"
fi
chmod 600 /etc/smbcredentials/smb.cred
sudo mount -t cifs $SHARENAME /mnt/share -o vers=3.0,credentials=/etc/smbcredentials/smb.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30

# Perform final actions based on the role of the VM
case "$ROLE" in
        "cp")
            # Generate a new token
            TOKEN=$(kubeadm token generate)

            # Use the new token to create the join commnad and save it to the file share
            kubeadm token create $TOKEN --print-join-command > /mnt/share/joinCommand.txt
            ;;
        "worker")
            # Get kubeadm join command
            COMMAND=$(cat /mnt/share/joinCommand.txt)

            # Run kubebadm join command
            eval $COMMAND
            ;;
        *)
            echo "Not a valid role"
            exit 1
            ;;
esac