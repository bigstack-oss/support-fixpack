#!/bin/bash
set -e

if [ -f "/etc/appliance/state/install_support_ext_pack_done" ]; then
    echo "[INFO] Support ext pack already installed, skipping..."
    exit 1
else
    # 1. 更新 virtio-win driver v285
    echo "[INFO] Mounting ISO to /usr/share/virtio-win..."
    cubectl node -r control exec -p "rm /usr/share/virtio-win/*.iso"
    cp ./virtio-win-0.1.285.iso /usr/share/virtio-win/virtio-win.iso
    cubectl node -r control rsync /usr/share/virtio-win/virtio-win.iso

    # 2. 複製 ext-* 工具
    echo "[INFO] Copying ext-* tools to /usr/local/bin..."
    cp ./ext-* /usr/local/bin/
    git add /usr/local/bin/ext-*
    hex_sdk git_push "Add support-ext-pack"
    
    # 3. update flavors
    echo "[INFO] Update OPSTK flavor"
    openstack flavor delete pgpu.example
    openstack flavor delete vgpu.example
    openstack flavor delete t2.micro
    openstack flavor delete t2.pico
    openstack flavor delete t2.nano
    openstack flavor create --vcpus 8 --ram 8192 --disk 200 --property hw:cpu_cores=8 --public appfw.medium
    openstack flavor create --vcpus 12 --ram 12288 --disk 200 --property hw:cpu_cores=12 --public appfw.large
    openstack flavor create --vcpus 16 --ram 16384 --disk 200 --property hw:cpu_threads=2 --property hw:cpu_cores=8 --public appfw.xlarge
    openstack flavor create --vcpus 1 --ram 1024 --disk 60 --public a1.micro
    openstack flavor create --vcpus 2 --ram 2048 --disk 60 --public a1.small
    openstack flavor create --vcpus 4 --ram 4096 --disk 60 --property hw:cpu_cores=4 --public a1.medium
    openstack flavor create --vcpus 8 --ram 8192 --disk 60 --property hw:cpu_cores=8 --public a1.large
    openstack flavor create --vcpus 16 --ram 16384 --disk 60 --property hw:cpu_threads=2 --property hw:cpu_cores=8 --public a1.xlarge
    openstack flavor create --vcpus 32 --ram 32768 --disk 60 --property hw:cpu_threads=2 --property hw:cpu_cores=16 --public a1.2xlarge
    openstack flavor create --vcpus 1 --ram 1024 --disk 120 --public a2.micro
    openstack flavor create --vcpus 2 --ram 2048 --disk 120 --public a2.small
    openstack flavor create --vcpus 4 --ram 4096 --disk 120 --property hw:cpu_cores=4 --public a2.medium
    openstack flavor create --vcpus 8 --ram 8192 --disk 120 --property hw:cpu_cores=8 --public a2.large
    openstack flavor create --vcpus 16 --ram 16384 --disk 120 --property hw:cpu_threads=2 --property hw:cpu_cores=8 --public a2.xlarge
    openstack flavor create --vcpus 32 --ram 32768 --disk 120 --property hw:cpu_threads=2 --property hw:cpu_cores=16 --public a2.2xlarge
    openstack flavor create --vcpus 4 --ram 4096 --disk 10 --property hw:cpu_cores=4 --public b10.small
    openstack flavor create --vcpus 8 --ram 8192 --disk 10 --property hw:cpu_cores=8 --public b10.medium
    openstack flavor create --vcpus 4 --ram 4096 --disk 20 --property hw:cpu_cores=4 --public b20.small
    openstack flavor create --vcpus 8 --ram 8192 --disk 20 --property hw:cpu_cores=8 --public b20.medium
    openstack flavor create --vcpus 4 --ram 4096 --disk 40 --property hw:cpu_cores=4 --public b40.small
    openstack flavor create --vcpus 8 --ram 8192 --disk 40 --property hw:cpu_cores=8 --public b40.medium
    openstack flavor create --vcpus 4 --ram 4096 --disk 80 --property hw:cpu_cores=4 --public b80.small
    openstack flavor create --vcpus 8 --ram 8192 --disk 80 --property hw:cpu_cores=8 --public b80.medium
    openstack flavor create --vcpus 4 --ram 8192 --disk 80 --property hw:cpu_cores=8 --public k8s.small
    openstack flavor create --vcpus 8 --ram 16384 --disk 80 --property hw:cpu_threads=2 --property hw:cpu_cores=4 --public k8s.medium
    openstack flavor create --vcpus 16 --ram 32768 --disk 80 --property hw:cpu_threads=2 --property hw:cpu_cores=8 --public k8s.large
    openstack flavor create --vcpus 2 --ram 2048 --disk 80 --property hw:cpu_cores=2 --public basic.small
    openstack flavor create --vcpus 4 --ram 4096 --disk 80 --property hw:cpu_cores=4 --public basic.medium
    openstack flavor create --vcpus 8 --ram 8192 --disk 80 --property hw:cpu_cores=8 --public basic.large
    openstack flavor create --vcpus 16 --ram 16384 --disk 80 --property hw:cpu_threads=2 --property hw:cpu_cores=8 --public basic.xlarge
    openstack flavor create --vcpus 32 --ram 32768 --disk 80 --property hw:cpu_threads=2 --property hw:cpu_cores=16 --public basic.2xlarge

    # 4. Override number of enabled pcie ports & enable swtpm for libvirt
    echo "[INFO] Override number of enabled pcie ports & enable swtpm for libvirt"
    mkdir -p /etc/nova/nova.d/
    cp ./override/custom-nova.conf /etc/nova/nova.d/custom.conf
    cubectl node -r compute rsync /etc/nova/nova.d/custom.conf
    cubectl node -r compute exec -p "hex_config restart_nova"

    # 5. update rabbitmq configuration
    mkdir -p /etc/systemd/system/rabbitmq-server.service.d
    cp ./override/rabbitmq-custom.conf /etc/systemd/system/rabbitmq-server.service.d/custom.conf
    cubectl node -r control rsync /etc/systemd/system/rabbitmq-server.service.d/custom.conf
    cubectl node -r control exec -p "systemctl daemon-reload"
    cubectl node -r control exec -p "systemctl restart rabbitmq-server"

    # 6. Create marker file to indicate the installation is done
    echo "[INFO] Marking installation as done..." > /etc/appliance/state/install_support_ext_pack_done
    cubectl node -r control rsync /etc/appliance/state/install_support_ext_pack_done
fi

./hotfix.sh
