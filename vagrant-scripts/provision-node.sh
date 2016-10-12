#!/bin/bash
echo node > /var/tmp/role

# SSH
sudo rm -rf /root/.ssh
sudo cp -R  ~vagrant/ssh /root/.ssh
sudo rm -f /root/.ssh/id_rsa*
sudo chown -R root: /root/.ssh

sudo echo $NEW_HOSTNAME > /tmp/new_hostname
sudo echo $NEW_HOSTNAME > /etc/hostname
sudo hostname $NEW_HOSTNAME

sudo mv ~vagrant/network_metadata.yaml /etc/
