#!/bin/bash

# gpg --keyserver keyserver.ubuntu.com --recv-keys F9C59A45
# gpg -a --export F9C59A45 | apt-key add -
# apt-get install -y software-properties-common
# add-apt-repository -y -u ppa:cz.nic-labs/bird
# apt-get update -y
docker cp quay.io-coreos-etcd:/usr/local/bin/etcdctl /usr/local/bin/etcdctl

etcdtool import -r -y -f yaml /network_metadata /etc/network_metadata.yaml

echo manual > /etc/init/bird.override
echo manual > /etc/init/bird6.override
apt-get install -y bird
cd /etc/bird
mkdir -p org
mv bird* org/

mv /vagrant/files/virt-router.sh /usr/local/bin/
chmod a+x /usr/local/bin/virt-router.sh

