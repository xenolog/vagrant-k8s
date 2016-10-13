#!/bin/bash
echo master > /var/tmp/role

# SSH keys and config
sudo rm -rf /root/.ssh
sudo cp -R ~vagrant/ssh /root/.ssh
sudo echo -e 'Host 10.*\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null' >> /root/.ssh/config
sudo chown -R root: /root/.ssh

sudo echo $NEW_HOSTNAME > /tmp/new_hostname
sudo echo $NEW_HOSTNAME > /etc/hostname
sudo hostname $NEW_HOSTNAME

sudo mv ~vagrant/network_metadata.yaml /etc/

apt-get install -y docker.io traceroute

mv /vagrant/files/bin/confd-0.11.0-linux-amd64 /usr/local/bin/confd
chmod a+x /usr/local/bin/confd
mkdir -p /etc/confd/{conf.d,templates}

mv /vagrant/files/bin/etcdtool /usr/local/bin/
chmod a+x /usr/local/bin/etcdtool

