#!/bin/bash
set -xe

if [ "$1" == "neutron" ] ; then
  CCP_YAML=""
else
  CCP_YAML="-e @ccp.yaml"
fi

BASE_URL="https://artifactory.mcp.mirantis.net/artifactory/projectcalico/mcp-0.1"
LAST_NODE=`curl -s ${BASE_URL}/calico-containers/lastbuild`
LAST_CNI=`curl -s ${BASE_URL}/calico-cni/lastbuild`

git clone https://github.com/adidenko/vagrant-k8s ~/mcp

CALICO_NODE_URL="${CALICO_NODE_URL:-${BASE_URL}/calico-containers/calico-containers-${LAST_NODE}.yaml}"
CALICO_CNI_URL="${CALICO_CNI_URL:-${BASE_URL}/calico-cni/calico-cni-${LAST_CNI}.yaml}"

pushd ~/mcp

# Step 0, prepare some configs

cp mir.yaml tmp.yaml
curl -s $CALICO_NODE_URL >> tmp.yaml
curl -s $CALICO_CNI_URL >> tmp.yaml

# Step 1
bash -x ./bootstrap-master.sh

export INVENTORY=`pwd`/nodes_to_inv.py
export K8S_NODES_FILE=`pwd`/nodes

# Test connectivity
cat nodes
ansible all -m ping -i $INVENTORY

# Deploy cluster
bash -x deploy-k8s.kargo.sh tmp.yaml

# Test network
ansible-playbook -i $INVENTORY playbooks/tests.yaml $CCP_YAML

# Run some extra customizations
ansible-playbook -i $INVENTORY playbooks/design.yaml $CCP_YAML

# Clone ansible CCP installer
git clone https://github.com/adidenko/fuel-ccp-ansible

# Build CCP images
ansible-playbook -i $INVENTORY fuel-ccp-ansible/build.yaml $CCP_YAML

# Deploy CCP
ansible-playbook -i $INVENTORY fuel-ccp-ansible/deploy.yaml $CCP_YAML

popd
