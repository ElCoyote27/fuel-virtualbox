#!/bin/bash

#    Copyright 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

#
# This script creates a master node for the product, launches its installation,
# and waits for its completion
#

# Include the handy functions to operate VMs and track ISO installation progress
source ./config.sh
source ./functions/vm.sh
source ./functions/network.sh
source ./functions/product.sh
source ./functions/translate.sh

# Create master node for the product
# Get variables "host_nic_name" for the master node
get_fuel_name_ifaces

name="${vm_name_prefix}master"

# Create master node VM
create_vm $name "${host_nic_name[0]}" $vm_master_cpu_cores $vm_master_memory_mb $vm_master_disk_mb

# Add additional NICs
add_hostonly_adapter_to_vm $name 2 "${host_nic_name[1]}"

# Add NAT adapter for internet access
add_nat_adapter_to_vm $name 3 $vm_master_nat_network

# Mount ISO with installer
mount_iso_to_vm $name $iso_path

#add RDP connection
if [ ${headless} -eq 1 ]; then
  enable_vrde $name ${RDPport}
fi

#add name of ISO file to description
execute VBoxManage modifyvm $name --description "${iso_path##*/}"

if [ "${skipfuelmenu}" = "yes" ]; then
    boot_line="$(translate " vmlinuz $cmdline wait_for_external_config=yes showmenu=no"$'\n')"
else
    boot_line="$(translate " vmlinuz $cmdline wait_for_external_config=yes"$'\n')"
fi

# Start virtual machine with the master node
echo
start_vm $name
echo

# Wait until product VM needs outbound network/internet access
wait_for_product_vm_to_download $vm_master_ip $vm_master_username $vm_master_password "$vm_master_prompt"

# Enable outbound network/internet access for the machine
enable_outbound_network_for_product_vm $vm_master_ip $vm_master_username $vm_master_password "$vm_master_prompt"

# Wait until the machine gets installed and Puppet completes its run
wait_for_product_vm_to_install $vm_master_ip $vm_master_username $vm_master_password "$vm_master_prompt"

#Add public key to authorized_keys
if [ -e "${public_key_file}" ]; then
  public_key=$(cat "${public_key_file}")
  update_authorized_key $vm_master_ip $vm_master_username $vm_master_password "$vm_master_prompt" "$public_key"
fi

# Report success
echo
echo "Master node has been installed."

#Sleep 10s to wait for Cobbler to settle
sleep 10
