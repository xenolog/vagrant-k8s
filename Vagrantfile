# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

pool = ENV["VAGRANT_MR_POOL"] || "10.250.0.0/16"

ENV["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"
prefix = pool.gsub(/\.\d+\.\d+\/16$/, "")

num_racks = (ENV["VAGRANT_MR_NUM_OF_RACKS"] || "2").to_i
base_as_number = (ENV["VAGRANT_MR_NETWORK_BASE_AS_NUMBER"] || "65000").to_i

vm_memory = 6144
vm_cpus = 2
master_memory = 2048
master_cpus = 1

user = ENV["USER"]

public_subnet_000 = (ENV["VAGRANT_MR_NETWORK_PUBLIC"] || prefix.to_s + ".254.0/24")
public_subnets  = [public_subnet_000]
rack_subnets = ['']
vagrant_cidr = prefix.to_s + ".0.0/24"
nodes_per_rack = [0] # racks numbered from 1

(1..num_racks).each do |rack_no|
  nodes_per_rack << (ENV["VAGRANT_MR_RACK#{rack_no}_NODES"] || "2").to_i
  public_subnets << (ENV["VAGRANT_MR_NETWORK_RACK#{rack_no}_PUBLIC"] || '')
  rack_subnets << (ENV["VAGRANT_MR_NETWORK_RACK#{rack_no}_RACK"] || prefix.to_s + ".#{rack_no}.0/24")
end

node_name_prefix = "#{user}-mr"

# Boxes with libvirt provider support:
box = "adidenko/ubuntu-1604-k8s"

# Create SSH keys for future lab
system "bash vagrant-scripts/ssh-keygen.sh"

# Create nodes list for future kargo deployment
nodes=[]
(1..num_racks).each do |rack_no|
  (1..nodes_per_rack[rack_no]).each do |node_no|
    nodes << rack_subnets[rack_no].split(".")[0..2].join(".")+".#{node_no}"
  end
end
File.open("nodes", "w") do |file|
  file.write(nodes.join("\n"))
  file.write("\n")
end

master_node_name = "%s-000" % [node_name_prefix]
master_node_ipaddr = public_subnets[0].split(".")[0..2].join(".")+".254"

# Create network_metadata for inventory
network_metadata = {
  'racks' => [{}],  # racks numbered from '1'
  'nodes' => {
    master_node_name => {
      'ipaddr' => master_node_ipaddr,
      'node_roles' => ['master']
    },
  },
}
(1..num_racks).each do |rack_no|
  network_metadata['racks'] << {
    'subnet' => rack_subnets[rack_no],
    'as_number' => (ENV["VAGRANT_MR_RACK#{rack_no}_AS_NUMBER"] || base_as_number+rack_no).to_i,
  }
  (1..nodes_per_rack[rack_no]).each do |node_no|
    node_name = "%s-%02d-%03d" % [node_name_prefix, rack_no, node_no]
    subnet_part = rack_subnets[rack_no].split(".")[0..2].join(".")
    network_metadata["nodes"][node_name] = {
      'ipaddr'  => "#{subnet_part}.#{node_no}",
      'gateway' => "#{subnet_part}.254",
      'node_roles' => ['general']
    }
    if 1 == node_no
      network_metadata["nodes"][node_name]['node_roles'] << 'rr'
    end
  end
end
File.open("network_metadata.yaml", "w") do |file|
  file.write(network_metadata.to_yaml)
end

# Create the lab
Vagrant.configure("2") do |config|
  config.ssh.insert_key = false
  config.vm.box = box

  # Global rovisioning
  config.vm.provision "ssh_configs", type: "file", source: "ssh", destination: "~/ssh"
  config.vm.provision "network_metadata", type: "file", source: "network_metadata.yaml", destination: "~/network_metadata.yaml"

  # configure Master&router VM
  config.vm.define "#{master_node_name}", primary: true do |master_node|
    master_node.vm.hostname = "#{master_node_name}"
    # Libvirt provider settings
    master_node.vm.provider(:libvirt) do |domain|
      domain.uri = "qemu+unix:///system"
      domain.memory = master_memory
      domain.cpus = master_cpus
      domain.driver = "kvm"
      domain.host = "localhost"
      domain.connect_via_ssh = false
      domain.username = user
      domain.storage_pool_name = "default"
      domain.nic_model_type = "e1000"
      domain.management_network_name = "#{node_name_prefix}_vagrant"
      domain.management_network_address = "#{vagrant_cidr}"
      domain.nested = true
      domain.cpu_mode = "host-passthrough"
      domain.volume_cache = "unsafe"
      domain.disk_bus = "virtio"
      # DISABLED: switched to new box which has 100G / partition
      #domain.storage :file, :type => "qcow2", :bus => "virtio", :size => "20G", :device => "vdb"
    end
    ### Networks and interfaces
    # "public" network with nat forwarding
    master_node.vm.network(:private_network,
      :ip => master_node_ipaddr,
      :libvirt__host_ip => public_subnets[0].split(".")[0..2].join(".")+".1",
      :model_type => "e1000",
      :libvirt__network_name => "#{node_name_prefix}_public",
      :libvirt__dhcp_enabled => false,
      :libvirt__forward_mode => "nat"
    )
    # "rack" isolated networks per rack
    (1..num_racks).each do |rack_no|
      master_node.vm.network(:private_network,
        :ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".254",
        :libvirt__host_ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".253",
        :model_type => "e1000",
        :libvirt__network_name => "#{node_name_prefix}_rack%02d" % [rack_no],
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "none"
      )
    end
    # Provisioning (per VM)
    master_node.vm.provision "nodes_list", type: "file", source: "nodes", destination: "/var/tmp/nodes"
    master_node.vm.provision "provision-master.sh", type: "shell", path: "vagrant-scripts/provision-master.sh", env: {
      'NEW_HOSTNAME' => "#{master_node_name}",
    }
    master_node.vm.provision "etcd", type: "docker", run: "once" do |d|
      d.pull_images("quay.io/coreos/etcd")
      d.run("quay.io/coreos/etcd",
        daemonize: true,
        args: "-p 4001:4001 -p 2380:2380 -p 2379:2379",
        cmd: "etcd  -name etcd0  -advertise-client-urls http://#{master_node_ipaddr}:2379,http://#{master_node_ipaddr}:4001  -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001  -initial-advertise-peer-urls http://#{master_node_ipaddr}:2380  -listen-peer-urls http://0.0.0.0:2380  -initial-cluster-token etcd-cluster-1  -initial-cluster etcd0=http://#{master_node_ipaddr}:2380  -initial-cluster-state new",
      )
    end
  end

  # configure Racks VMs
  (1..num_racks).each do |rack_no|
    (1..nodes_per_rack[rack_no]).each do |node_no|
      slave_name = "%s-%02d-%03d" % [node_name_prefix, rack_no, node_no]
      config.vm.define "#{slave_name}" do |slave_node|
        slave_node.vm.hostname = "#{slave_name}"
        # Libvirt provider settings
        slave_node.vm.provider :libvirt do |domain|
          domain.uri = "qemu+unix:///system"
          domain.memory = vm_memory
          domain.cpus = vm_cpus
          domain.driver = "kvm"
          domain.host = "localhost"
          domain.connect_via_ssh = false
          domain.username = user
          domain.storage_pool_name = "default"
          domain.nic_model_type = "e1000"
          domain.management_network_name = "#{node_name_prefix}_vagrant"
          domain.management_network_address = "#{vagrant_cidr}"
          domain.nested = true
          domain.cpu_mode = "host-passthrough"
          domain.volume_cache = "unsafe"
          domain.disk_bus = "virtio"
          # DISABLED: switched to new box which has 100G / partition
          #domain.storage :file, :type => "qcow2", :bus => "virtio", :size => "20G", :device => "vdb"
        end

        # "rack" isolated network
        slave_node.vm.network(:private_network,
          :ip => network_metadata["nodes"][slave_name]["ipaddr"],
          :libvirt__host_ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".253",
          :model_type => "e1000",
          :libvirt__network_name => "#{node_name_prefix}_rack%02d" % [rack_no],
          :libvirt__dhcp_enabled => false,
          :libvirt__forward_mode => "none"
        )

        # Provisioning (per VM)
        slave_node.vm.provision "provision-node.sh", type: "shell", path: "vagrant-scripts/provision-node.sh", env: {
          'NEW_HOSTNAME' => "#{slave_name}",
        }
      end
    end
  end
end
